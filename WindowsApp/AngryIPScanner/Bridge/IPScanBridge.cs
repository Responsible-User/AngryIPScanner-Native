using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;
using System.Windows.Threading;
using AngryIPScanner.Bridge.Models;

namespace AngryIPScanner.Bridge;

/// <summary>
/// C# wrapper around the libipscan C API, mirroring the Swift IPScanBridge.
/// All Go interactions go through this class. Must be created on the UI thread.
/// </summary>
public sealed class IPScanBridge : INotifyPropertyChanged, IDisposable
{
    private readonly int _handle;
    private readonly Dispatcher _dispatcher;

    // prevent GC of unmanaged callback delegates
    private NativeMethods.ResultCallbackDelegate? _resultCbDelegate;
    private NativeMethods.ProgressCallbackDelegate? _progressCbDelegate;

    // callback routing: Go goroutine → static method → Dispatcher → instance
    private static readonly Dictionary<int, WeakReference<IPScanBridge>> Instances = new();
    private static int _nextId = 1;
    private readonly int _instanceId;

    public ObservableCollection<ScanResult> Results { get; } = [];

    private ScanProgress? _progress;
    public ScanProgress? Progress
    {
        get => _progress;
        private set { _progress = value; Notify(); Notify(nameof(StatusText)); }
    }

    private string _scanState = "idle";
    public string ScanState
    {
        get => _scanState;
        private set
        {
            _scanState = value;
            Notify();
            Notify(nameof(IsScanning));
            Notify(nameof(StartButtonText));
            Notify(nameof(StatusText));
        }
    }

    private ScanStats _stats = new();
    public ScanStats Stats
    {
        get => _stats;
        private set { _stats = value; Notify(); Notify(nameof(StatusText)); }
    }

    private List<FetcherInfo> _availableFetchers = [];
    public List<FetcherInfo> AvailableFetchers
    {
        get => _availableFetchers;
        private set { _availableFetchers = value; Notify(); }
    }

    public enum DisplayFilter { All, Alive, WithPorts }

    private DisplayFilter _displayFilter = DisplayFilter.All;
    public DisplayFilter CurrentFilter
    {
        get => _displayFilter;
        set { _displayFilter = value; Notify(); }
    }

    // Computed properties

    public bool IsScanning =>
        ScanState is "scanning" or "stopping" or "starting";

    public string StartButtonText => ScanState switch
    {
        "scanning" or "starting" => "Stop",
        "stopping" => "Kill",
        _ => "Start"
    };

    public string StatusText => ScanState switch
    {
        "scanning" when Progress is { CurrentIP.Length: > 0 } =>
            $"Scanning {Progress.CurrentIP}...",
        "scanning" => "Scanning...",
        "stopping" => "Stopping...",
        "starting" => "Starting...",
        _ when Stats.Total > 0 =>
            $"Done: {Stats.Total} scanned, {Stats.Alive} alive, {Stats.WithPorts} with ports",
        _ => "Ready"
    };

    // JSON options matching Go's camelCase keys

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public IPScanBridge(Dispatcher dispatcher)
    {
        _dispatcher = dispatcher;
        _handle = NativeMethods.ipscan_new(null);

        _instanceId = _nextId++;
        Instances[_instanceId] = new WeakReference<IPScanBridge>(this);

        LoadAvailableFetchers();
    }

    // ── Scanning ──────────────────────────────────────────────

    public void StartScan(string startIP, string endIP)
    {
        Results.Clear();
        Stats = new ScanStats();
        Progress = null;

        var feederJson = JsonSerializer.Serialize(
            new FeederConfig { Type = "range", StartIP = startIP, EndIP = endIP },
            JsonOpts);

        // Wire up callbacks (prevent GC by storing delegates)
        _resultCbDelegate = OnResultCallback;
        _progressCbDelegate = OnProgressCallback;
        NativeMethods.ipscan_set_result_callback(_handle, _resultCbDelegate, (IntPtr)_instanceId);
        NativeMethods.ipscan_set_progress_callback(_handle, _progressCbDelegate, (IntPtr)_instanceId);

        int rc = NativeMethods.ipscan_start_scan(_handle, feederJson);
        if (rc != 0)
        {
            MessageBox.Show($"Failed to start scan (error {rc})", "Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        ScanState = "scanning";
    }

    public void StopScan()
    {
        NativeMethods.ipscan_stop_scan(_handle);
        if (ScanState == "scanning")
            ScanState = "stopping";
    }

    // ── Configuration ─────────────────────────────────────────

    public ScanConfig? GetConfig()
    {
        var json = NativeMethods.ReadAndFree(NativeMethods.ipscan_get_config(_handle));
        return json != null ? JsonSerializer.Deserialize<ScanConfig>(json, JsonOpts) : null;
    }

    public void SetConfig(ScanConfig config)
    {
        var json = JsonSerializer.Serialize(config, JsonOpts);
        NativeMethods.ipscan_set_config(_handle, json);
    }

    // ── Fetchers ──────────────────────────────────────────────

    private void LoadAvailableFetchers()
    {
        var json = NativeMethods.ReadAndFree(
            NativeMethods.ipscan_get_available_fetchers(_handle));
        if (json == null) return;
        var list = JsonSerializer.Deserialize<List<FetcherInfo>>(json, JsonOpts);
        if (list != null) AvailableFetchers = list;
    }

    // ── Export ─────────────────────────────────────────────────

    public bool ExportResults(string format, string path)
        => NativeMethods.ipscan_export(_handle, format, path) == 0;

    // ── Callbacks (called from Go goroutines, marshalled to UI) ──

    private static void OnResultCallback(IntPtr jsonPtr, IntPtr ctx)
    {
        var json = Marshal.PtrToStringAnsi(jsonPtr);
        if (json == null) return;

        int id = ctx.ToInt32();
        if (!Instances.TryGetValue(id, out var wref) || !wref.TryGetTarget(out var bridge))
            return;

        bridge._dispatcher.BeginInvoke(() => bridge.HandleResult(json));
    }

    private static void OnProgressCallback(IntPtr jsonPtr, IntPtr ctx)
    {
        var json = Marshal.PtrToStringAnsi(jsonPtr);
        if (json == null) return;

        int id = ctx.ToInt32();
        if (!Instances.TryGetValue(id, out var wref) || !wref.TryGetTarget(out var bridge))
            return;

        bridge._dispatcher.BeginInvoke(() => bridge.HandleProgress(json));
    }

    private void HandleResult(string json)
    {
        var result = JsonSerializer.Deserialize<ScanResult>(json, JsonOpts);
        if (result == null) return;

        if (result.Complete)
        {
            // Update existing row in-place (replace triggers DataGrid refresh)
            for (int i = 0; i < Results.Count; i++)
            {
                if (Results[i].IP == result.IP)
                {
                    Results[i] = result;
                    break;
                }
            }
            RefreshStats();
        }
        else
        {
            // First callback — add placeholder row immediately
            Results.Add(result);
        }
    }

    private void HandleProgress(string json)
    {
        var p = JsonSerializer.Deserialize<ScanProgress>(json, JsonOpts);
        if (p == null) return;

        Progress = p;
        ScanState = p.State;

        if (p.State == "idle")
            RefreshStats();
    }

    private void RefreshStats()
    {
        var json = NativeMethods.ReadAndFree(NativeMethods.ipscan_get_stats(_handle));
        if (json == null) return;
        var s = JsonSerializer.Deserialize<ScanStats>(json, JsonOpts);
        if (s != null) Stats = s;
    }

    // ── INotifyPropertyChanged ────────────────────────────────

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Notify([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    // ── IDisposable ───────────────────────────────────────────

    public void Dispose()
    {
        Instances.Remove(_instanceId);
        NativeMethods.ipscan_free(_handle);
    }
}
