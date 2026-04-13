using System.ComponentModel;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using Microsoft.Win32;
using AngryIPScanner.Bridge;
using AngryIPScanner.Bridge.Models;
using AngryIPScanner.Helpers;
using AngryIPScanner.Views.Dialogs;

namespace AngryIPScanner.Views;

public partial class MainWindow : Window
{
    private readonly IPScanBridge _bridge;
    private ICollectionView? _resultsView;

    public MainWindow()
    {
        _bridge = new IPScanBridge(Dispatcher);
        InitializeComponent();

        // Set up collection view with filter
        _resultsView = CollectionViewSource.GetDefaultView(_bridge.Results);
        _resultsView.Filter = ResultFilter;
        ResultsGrid.ItemsSource = _resultsView;

        // Populate CIDR prefix dropdown
        foreach (var bits in new[] { 8, 16, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32 })
            CidrPrefixCombo.Items.Add(new ComboBoxItem { Content = $"/{bits}", Tag = bits });
        CidrPrefixCombo.SelectedIndex = 7; // /24

        // React to bridge state changes
        _bridge.PropertyChanged += Bridge_PropertyChanged;

        // Keyboard shortcuts
        InputBindings.Add(new KeyBinding(
            new RelayCommand(CopySelectedIPs),
            new KeyGesture(Key.C, ModifierKeys.Control | ModifierKeys.Shift)));
        InputBindings.Add(new KeyBinding(
            new RelayCommand(CopySelectedAll),
            new KeyGesture(Key.C, ModifierKeys.Control | ModifierKeys.Alt)));

        // Auto-detect local network
        AutoDetectLocalRange();
    }

    // ── Bridge property changes → UI updates ─────────────────

    private void Bridge_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(IPScanBridge.ScanState):
                StartButton.Content = _bridge.StartButtonText;
                ProgressBar.Visibility = _bridge.IsScanning ? Visibility.Visible : Visibility.Collapsed;
                ThreadsText.Visibility = _bridge.ScanState == "scanning" ? Visibility.Visible : Visibility.Collapsed;
                UpdateTitle();
                break;

            case nameof(IPScanBridge.Progress):
                if (_bridge.Progress != null)
                {
                    ProgressBar.Value = _bridge.Progress.Percent;
                    ThreadsText.Text = $"Threads: {_bridge.Progress.ActiveThreads}";
                    ThreadsText.Foreground = _bridge.Progress.ActiveThreads > 80
                        ? System.Windows.Media.Brushes.Red
                        : System.Windows.Media.Brushes.Gray;
                }
                UpdateTitle();
                break;

            case nameof(IPScanBridge.Stats):
                AliveCount.Text = _bridge.Stats.Alive.ToString();
                WithPortsCount.Text = _bridge.Stats.WithPorts.ToString();
                DeadCount.Text = (_bridge.Stats.Total - _bridge.Stats.Alive).ToString();
                break;

            case nameof(IPScanBridge.StatusText):
                StatusText.Text = _bridge.StatusText;
                break;
        }
    }

    private void UpdateTitle()
    {
        Title = _bridge.ScanState == "scanning" && _bridge.Progress != null
            ? $"{_bridge.Progress.Percent:F0}% - Angry IP Scanner"
            : "Angry IP Scanner";
    }

    // ── Auto-detect local network ────────────────────────────

    private void AutoDetectLocalRange()
    {
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up) continue;
                if (ni.NetworkInterfaceType is NetworkInterfaceType.Loopback
                    or NetworkInterfaceType.Tunnel) continue;

                foreach (var addr in ni.GetIPProperties().UnicastAddresses)
                {
                    if (addr.Address.AddressFamily != AddressFamily.InterNetwork) continue;

                    byte[] ip = addr.Address.GetAddressBytes();
                    byte[]? mask = addr.IPv4Mask?.GetAddressBytes();
                    if (mask == null) continue;

                    byte[] start = new byte[4], end = new byte[4];
                    for (int i = 0; i < 4; i++)
                    {
                        start[i] = (byte)(ip[i] & mask[i]);
                        end[i] = (byte)(ip[i] | ~mask[i]);
                    }

                    Increment(start); // skip network address
                    Decrement(end);   // skip broadcast

                    StartIPBox.Text = FormatIP(start);
                    EndIPBox.Text = FormatIP(end);
                    CidrIPBox.Text = FormatIP(ip);
                    return;
                }
            }
        }
        catch { /* use fallback */ }

        StartIPBox.Text = "192.168.1.1";
        EndIPBox.Text = "192.168.1.255";
    }

    // ── Feeder mode switching ────────────────────────────────

    private void Mode_Changed(object sender, SelectionChangedEventArgs e)
    {
        if (RangePanel == null || CidrPanel == null) return; // not initialized yet

        if (ModeCombo.SelectedIndex == 0)
        {
            RangePanel.Visibility = Visibility.Visible;
            CidrPanel.Visibility = Visibility.Collapsed;
        }
        else
        {
            RangePanel.Visibility = Visibility.Collapsed;
            CidrPanel.Visibility = Visibility.Visible;
            ApplyCIDR();
        }
    }

    private void CidrPrefix_Changed(object sender, SelectionChangedEventArgs e) => ApplyCIDR();

    private void ApplyCIDR()
    {
        if (string.IsNullOrWhiteSpace(CidrIPBox?.Text)) return;
        if (CidrPrefixCombo?.SelectedItem is not ComboBoxItem item) return;

        var parts = CidrIPBox.Text.Trim().Split('.');
        if (parts.Length != 4) return;

        byte[] ip = new byte[4];
        for (int i = 0; i < 4; i++)
            if (!byte.TryParse(parts[i], out ip[i])) return;

        int prefix = (int)item.Tag;
        uint mask = prefix == 0 ? 0 : ~((1u << (32 - prefix)) - 1);
        uint ipNum = ((uint)ip[0] << 24) | ((uint)ip[1] << 16) | ((uint)ip[2] << 8) | ip[3];
        uint netStart = ipNum & mask;
        uint netEnd = netStart | ~mask;
        uint usableStart = netStart + 1;
        uint usableEnd = netEnd - 1;
        if (usableStart > netEnd) usableStart = netStart;
        if (usableEnd < netStart) usableEnd = netEnd;

        StartIPBox.Text = UintToIP(usableStart);
        EndIPBox.Text = UintToIP(usableEnd);
    }

    // ── Start / Stop / Kill ──────────────────────────────────

    private void StartStop_Click(object sender, RoutedEventArgs e)
    {
        if (_bridge.IsScanning)
            _bridge.StopScan();
        else
            StartScan();
    }

    private void IPBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Return)
        {
            StartScan();
            e.Handled = true;
        }
    }

    private void StartScan()
    {
        if (_bridge.IsScanning) return;
        if (ModeCombo.SelectedIndex == 1) ApplyCIDR();

        string start = StartIPBox.Text.Trim();
        string end = EndIPBox.Text.Trim();
        if (string.IsNullOrEmpty(start) || string.IsNullOrEmpty(end)) return;

        _bridge.StartScan(start, end);
    }

    // ── Display filter ───────────────────────────────────────

    private void FilterAll_Click(object sender, RoutedEventArgs e) => ApplyFilter(IPScanBridge.DisplayFilter.All);
    private void FilterAlive_Click(object sender, RoutedEventArgs e) => ApplyFilter(IPScanBridge.DisplayFilter.Alive);
    private void FilterWithPorts_Click(object sender, RoutedEventArgs e) => ApplyFilter(IPScanBridge.DisplayFilter.WithPorts);

    private void ApplyFilter(IPScanBridge.DisplayFilter filter)
    {
        _bridge.CurrentFilter = filter;
        _resultsView?.Refresh();
    }

    private bool ResultFilter(object item)
    {
        if (item is not ScanResult r) return false;
        return _bridge.CurrentFilter switch
        {
            IPScanBridge.DisplayFilter.Alive => r.TypeString is "alive" or "with_ports",
            IPScanBridge.DisplayFilter.WithPorts => r.TypeString == "with_ports",
            _ => true
        };
    }

    // ── Export ────────────────────────────────────────────────

    private void ExportCsv_Click(object sender, RoutedEventArgs e) => ExportAs("csv", "CSV Files|*.csv");
    private void ExportTxt_Click(object sender, RoutedEventArgs e) => ExportAs("txt", "Text Files|*.txt");
    private void ExportXml_Click(object sender, RoutedEventArgs e) => ExportAs("xml", "XML Files|*.xml");
    private void ExportIpList_Click(object sender, RoutedEventArgs e) => ExportAs("iplist", "IP List|*.txt");
    private void ExportSql_Click(object sender, RoutedEventArgs e) => ExportAs("sql", "SQL Files|*.sql");

    private void ExportAs(string format, string filter)
    {
        var dlg = new SaveFileDialog { Filter = filter };
        if (dlg.ShowDialog() == true)
        {
            if (!_bridge.ExportResults(format, dlg.FileName))
                MessageBox.Show("Failed to export results.", "Error",
                    MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    // ── Copy ─────────────────────────────────────────────────

    private void CopyIP_Click(object sender, RoutedEventArgs e) => CopySelectedIPs();
    private void CopyAll_Click(object sender, RoutedEventArgs e) => CopySelectedAll();

    private void CopySelectedIPs()
    {
        var ips = ResultsGrid.SelectedItems.Cast<ScanResult>()
            .Select(r => r.IP);
        var text = string.Join(Environment.NewLine, ips);
        if (!string.IsNullOrEmpty(text))
            Clipboard.SetText(text);
    }

    private void CopySelectedAll()
    {
        var lines = ResultsGrid.SelectedItems.Cast<ScanResult>()
            .Select(r => string.Join("\t", r.Values.Select(v =>
                v.ValueKind is System.Text.Json.JsonValueKind.Null ? "" :
                v.ValueKind is System.Text.Json.JsonValueKind.String ? v.GetString() ?? "" :
                v.ToString())));
        var text = string.Join(Environment.NewLine, lines);
        if (!string.IsNullOrEmpty(text))
            Clipboard.SetText(text);
    }

    // ── Dialogs ──────────────────────────────────────────────

    private void Preferences_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new PreferencesWindow(_bridge) { Owner = this };
        dlg.ShowDialog();
    }

    private void SelectFetchers_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new SelectFetchersWindow(_bridge) { Owner = this };
        dlg.ShowDialog();
    }

    private void About_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new AboutWindow { Owner = this };
        dlg.ShowDialog();
    }

    private void Exit_Click(object sender, RoutedEventArgs e) => Close();

    // ── Cleanup ──────────────────────────────────────────────

    private void Window_Closing(object sender, CancelEventArgs e)
    {
        _bridge.Dispose();
    }

    // ── IP helpers ───────────────────────────────────────────

    private static string FormatIP(byte[] b) => $"{b[0]}.{b[1]}.{b[2]}.{b[3]}";

    private static string UintToIP(uint n) =>
        $"{(n >> 24) & 0xFF}.{(n >> 16) & 0xFF}.{(n >> 8) & 0xFF}.{n & 0xFF}";

    private static void Increment(byte[] b)
    {
        for (int i = 3; i >= 0; i--)
            if (++b[i] != 0) break;
    }

    private static void Decrement(byte[] b)
    {
        for (int i = 3; i >= 0; i--)
            if (b[i]-- != 0) break;
    }
}
