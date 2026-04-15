using System.ComponentModel;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using Microsoft.Win32;
using GoNetworkScanner.Bridge;
using GoNetworkScanner.Bridge.Models;
using GoNetworkScanner.Helpers;
using GoNetworkScanner.Views.Dialogs;

namespace GoNetworkScanner.Views;

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
        AddShortcut(Key.C, ModifierKeys.Control | ModifierKeys.Shift, CopySelectedIPs);
        AddShortcut(Key.C, ModifierKeys.Control | ModifierKeys.Alt,   CopySelectedAll);
        AddShortcut(Key.F, ModifierKeys.Control,                      ShowFindBar);
        AddShortcut(Key.S, ModifierKeys.Control,                      ExportResults);
        AddShortcut(Key.T, ModifierKeys.Control,                      ShowStatistics);
        AddShortcut(Key.I, ModifierKeys.Control,                      InvertSelection);
        AddShortcut(Key.N, ModifierKeys.Control,                      OpenNewWindow);
        AddShortcut(Key.O, ModifierKeys.Control,                      OpenFileFeeder);
        AddShortcut(Key.Down, ModifierKeys.Control | ModifierKeys.Alt, () => GoToAlive(forward: true));
        AddShortcut(Key.Up,   ModifierKeys.Control | ModifierKeys.Alt, () => GoToAlive(forward: false));

        // Auto-detect local network
        AutoDetectLocalRange();

        // Reflect the persisted pinger choice in the dropdown
        LoadPingerSelection();
    }

    private void AddShortcut(Key key, ModifierKeys mods, Action action)
    {
        InputBindings.Add(new KeyBinding(new RelayCommand(action), new KeyGesture(key, mods)));
    }

    private void LoadPingerSelection()
    {
        var cfg = _bridge.GetConfig();
        if (cfg?.Scanner?.SelectedPinger is not { } id) return;
        foreach (ComboBoxItem item in PingerCombo.Items)
        {
            if ((string?)item.Tag == id)
            {
                PingerCombo.SelectedItem = item;
                return;
            }
        }
    }

    private void Pinger_Changed(object sender, SelectionChangedEventArgs e)
    {
        if (PingerCombo?.SelectedItem is not ComboBoxItem item) return;
        if (item.Tag is not string pingerId) return;
        var cfg = _bridge.GetConfig();
        if (cfg == null) return;
        if (cfg.Scanner.SelectedPinger == pingerId) return;
        cfg.Scanner.SelectedPinger = pingerId;
        _bridge.SetConfig(cfg);
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
        string start = StartIPBox?.Text?.Trim() ?? "";
        string end = EndIPBox?.Text?.Trim() ?? "";
        string rangeSuffix = (!string.IsNullOrEmpty(start) && !string.IsNullOrEmpty(end))
            ? $" — {start} - {end}"
            : "";

        if (_bridge.ScanState == "scanning" && _bridge.Progress != null)
            Title = $"{_bridge.Progress.Percent:F0}%{rangeSuffix}";
        else if (_bridge.Stats.Total > 0)
            Title = $"Done{rangeSuffix}";
        else
            Title = $"Go Network Scanner{rangeSuffix}";
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
        if (RangePanel == null || CidrPanel == null) return;

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
        UpdateTitle();
    }

    // ── Display filter ───────────────────────────────────────

    private void FilterAll_Click(object sender, RoutedEventArgs e)       { FilterAll.IsChecked = true;       ApplyFilter(IPScanBridge.DisplayFilter.All); }
    private void FilterAlive_Click(object sender, RoutedEventArgs e)     { FilterAlive.IsChecked = true;     ApplyFilter(IPScanBridge.DisplayFilter.Alive); }
    private void FilterWithPorts_Click(object sender, RoutedEventArgs e) { FilterWithPorts.IsChecked = true; ApplyFilter(IPScanBridge.DisplayFilter.WithPorts); }

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

    private void Export_Click(object sender, RoutedEventArgs e) => ExportResults();

    private void ExportResults()
    {
        var dlg = new SaveFileDialog
        {
            Title = "Export Scan Results",
            Filter = "CSV (*.csv)|*.csv|Text (*.txt)|*.txt|XML (*.xml)|*.xml|IP List (*.lst)|*.lst|SQL (*.sql)|*.sql",
            FileName = "scan_results.csv",
            AddExtension = true,
            DefaultExt = "csv",
        };

        if (dlg.ShowDialog() != true) return;

        // Filter index is 1-based: 1=csv, 2=txt, 3=xml, 4=iplist, 5=sql
        string format = dlg.FilterIndex switch
        {
            2 => "txt",
            3 => "xml",
            4 => "iplist",
            5 => "sql",
            _ => "csv",
        };

        // Use filtered export so the file matches the current display filter
        string filter = _bridge.CurrentFilter switch
        {
            IPScanBridge.DisplayFilter.Alive => "alive",
            IPScanBridge.DisplayFilter.WithPorts => "with_ports",
            _ => "all",
        };

        if (!_bridge.ExportFiltered(format, dlg.FileName, filter))
            MessageBox.Show("Failed to export results.", "Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
    }

    private void ExportSelection_Click(object sender, RoutedEventArgs e)
    {
        var selected = ResultsGrid.SelectedItems.Cast<ScanResult>().ToList();
        if (selected.Count == 0) return;

        var dlg = new SaveFileDialog
        {
            Title = "Export Selected Rows",
            Filter = "CSV (*.csv)|*.csv",
            FileName = "scan_selection.csv",
            AddExtension = true,
            DefaultExt = "csv",
        };
        if (dlg.ShowDialog() != true) return;

        var lines = selected.Select(r =>
            string.Join(",", (new[] { r.IP }).Concat(r.Values.Select(v =>
                v.ValueKind is System.Text.Json.JsonValueKind.Null ? "" :
                v.ValueKind is System.Text.Json.JsonValueKind.String ? (v.GetString() ?? "") :
                v.ToString()))
            .Select(CsvEscape)));

        try
        {
            System.IO.File.WriteAllLines(dlg.FileName, lines);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to export: {ex.Message}", "Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private static string CsvEscape(string s)
    {
        if (s.Contains('"') || s.Contains(',') || s.Contains('\n'))
            return "\"" + s.Replace("\"", "\"\"") + "\"";
        return s;
    }

    // ── Copy ─────────────────────────────────────────────────

    private void CopyIP_Click(object sender, RoutedEventArgs e) => CopySelectedIPs();
    private void CopyAll_Click(object sender, RoutedEventArgs e) => CopySelectedAll();

    private void CopySelectedIPs()
    {
        var ips = ResultsGrid.SelectedItems.Cast<ScanResult>().Select(r => r.IP);
        var text = string.Join(Environment.NewLine, ips);
        if (!string.IsNullOrEmpty(text)) Clipboard.SetText(text);
    }

    private void CopySelectedAll()
    {
        var lines = ResultsGrid.SelectedItems.Cast<ScanResult>()
            .Select(r => string.Join("\t", r.Values.Select(v =>
                v.ValueKind is System.Text.Json.JsonValueKind.Null ? "" :
                v.ValueKind is System.Text.Json.JsonValueKind.String ? v.GetString() ?? "" :
                v.ToString())));
        var text = string.Join(Environment.NewLine, lines);
        if (!string.IsNullOrEmpty(text)) Clipboard.SetText(text);
    }

    // ── Details (double-click or context menu) ───────────────

    private void ResultsGrid_DoubleClick(object sender, MouseButtonEventArgs e) => ShowSelectedDetails();
    private void ShowDetails_Click(object sender, RoutedEventArgs e) => ShowSelectedDetails();

    private void ShowSelectedDetails()
    {
        if (ResultsGrid.SelectedItem is not ScanResult r) return;
        var dlg = new DetailsWindow(_bridge, r) { Owner = this };
        dlg.ShowDialog();
    }

    // ── Context menu: Openers ────────────────────────────────

    private ScanResult? SelectedResult => ResultsGrid.SelectedItem as ScanResult;

    private void OpenBrowser_Click(object sender, RoutedEventArgs e) { if (SelectedResult is { } r) _bridge.OpenInBrowser(r.IP); }
    private void OpenSSH_Click(object sender, RoutedEventArgs e)     { if (SelectedResult is { } r) _bridge.OpenSSH(r.IP); }
    private void OpenPing_Click(object sender, RoutedEventArgs e)    { if (SelectedResult is { } r) _bridge.OpenPing(r.IP); }
    private void OpenTracert_Click(object sender, RoutedEventArgs e) { if (SelectedResult is { } r) _bridge.OpenTraceroute(r.IP); }

    // ── Context menu: Rescan / Delete ────────────────────────

    private void RescanSelected_Click(object sender, RoutedEventArgs e)
    {
        if (SelectedResult is not { } r) return;
        _bridge.StartScan(r.IP, r.IP);
    }

    private void DeleteSelected_Click(object sender, RoutedEventArgs e)
    {
        foreach (var r in ResultsGrid.SelectedItems.Cast<ScanResult>().ToList())
            _bridge.DeleteResult(r.IP);
    }

    // ── Select operations ────────────────────────────────────

    private void SelectAlive_Click(object sender, RoutedEventArgs e)
        => SelectMatching(r => r.TypeString is "alive" or "with_ports");

    private void SelectDead_Click(object sender, RoutedEventArgs e)
        => SelectMatching(r => r.TypeString == "dead");

    private void SelectWithPorts_Click(object sender, RoutedEventArgs e)
        => SelectMatching(r => r.TypeString == "with_ports");

    private void SelectInvert_Click(object sender, RoutedEventArgs e) => InvertSelection();

    private void SelectMatching(Func<ScanResult, bool> predicate)
    {
        ResultsGrid.SelectedItems.Clear();
        foreach (var item in VisibleResults())
            if (predicate(item)) ResultsGrid.SelectedItems.Add(item);
    }

    private void InvertSelection()
    {
        var currentlySelected = new HashSet<ScanResult>(
            ResultsGrid.SelectedItems.Cast<ScanResult>());
        ResultsGrid.SelectedItems.Clear();
        foreach (var item in VisibleResults())
            if (!currentlySelected.Contains(item))
                ResultsGrid.SelectedItems.Add(item);
    }

    private IEnumerable<ScanResult> VisibleResults()
    {
        if (_resultsView == null) return [];
        return _resultsView.Cast<ScanResult>();
    }

    // ── Go To navigation ─────────────────────────────────────

    private void NextAlive_Click(object sender, RoutedEventArgs e) => GoToAlive(forward: true);
    private void PrevAlive_Click(object sender, RoutedEventArgs e) => GoToAlive(forward: false);

    private void GoToAlive(bool forward)
    {
        var list = VisibleResults().ToList();
        if (list.Count == 0) return;

        int currentIdx = SelectedResult is { } r ? list.IndexOf(r) : (forward ? -1 : list.Count);

        int? target = null;
        if (forward)
        {
            for (int i = currentIdx + 1; i < list.Count; i++)
                if (IsAlive(list[i])) { target = i; break; }
            if (target == null)
                for (int i = 0; i <= Math.Min(currentIdx, list.Count - 1); i++)
                    if (IsAlive(list[i])) { target = i; break; }
        }
        else
        {
            for (int i = currentIdx - 1; i >= 0; i--)
                if (IsAlive(list[i])) { target = i; break; }
            if (target == null)
                for (int i = list.Count - 1; i >= Math.Max(currentIdx, 0); i--)
                    if (IsAlive(list[i])) { target = i; break; }
        }

        if (target is int t)
        {
            var row = list[t];
            ResultsGrid.SelectedItem = row;
            ResultsGrid.ScrollIntoView(row);
        }
    }

    private static bool IsAlive(ScanResult r) => r.TypeString is "alive" or "with_ports";

    // ── Find bar (Ctrl+F) ────────────────────────────────────

    private void Find_Click(object sender, RoutedEventArgs e) => ShowFindBar();

    private void ShowFindBar()
    {
        FindBar.Visibility = Visibility.Visible;
        FindBox.Focus();
        FindBox.SelectAll();
    }

    private void FindBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Return)
        {
            FindNext();
            e.Handled = true;
        }
        else if (e.Key == Key.Escape)
        {
            FindBar.Visibility = Visibility.Collapsed;
            e.Handled = true;
        }
    }

    private void FindNext_Click(object sender, RoutedEventArgs e) => FindNext();
    private void FindClose_Click(object sender, RoutedEventArgs e) => FindBar.Visibility = Visibility.Collapsed;

    private void FindNext()
    {
        var text = FindBox.Text?.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(text)) return;

        var list = VisibleResults().ToList();
        if (list.Count == 0) return;

        int start = SelectedResult is { } r ? list.IndexOf(r) + 1 : 0;
        for (int offset = 0; offset < list.Count; offset++)
        {
            int i = (start + offset) % list.Count;
            var row = list[i];
            if (row.IP.Contains(text, StringComparison.OrdinalIgnoreCase) ||
                row.Values.Any(v => v.ToString().Contains(text, StringComparison.OrdinalIgnoreCase)))
            {
                ResultsGrid.SelectedItem = row;
                ResultsGrid.ScrollIntoView(row);
                return;
            }
        }
    }

    // ── File feeder (File > Open IP List) ────────────────────

    private void OpenFile_Click(object sender, RoutedEventArgs e) => OpenFileFeeder();

    private void OpenFileFeeder()
    {
        if (_bridge.IsScanning) return;
        var dlg = new OpenFileDialog
        {
            Title = "Open IP List",
            Filter = "Text files (*.txt;*.lst;*.log)|*.txt;*.lst;*.log|All files (*.*)|*.*",
        };
        if (dlg.ShowDialog() != true) return;
        _bridge.StartFileScan(dlg.FileName);
    }

    // ── New Window (Ctrl+N) ──────────────────────────────────

    private void NewWindow_Click(object sender, RoutedEventArgs e) => OpenNewWindow();

    private void OpenNewWindow()
    {
        var w = new MainWindow();
        w.Show();
    }

    // ── Statistics ───────────────────────────────────────────

    private void Statistics_Click(object sender, RoutedEventArgs e) => ShowStatistics();

    private void ShowStatistics()
    {
        var dlg = new StatisticsWindow(_bridge) { Owner = this };
        dlg.ShowDialog();
    }

    // ── Favorites ────────────────────────────────────────────

    private void SaveFavorite_Click(object sender, RoutedEventArgs e)
    {
        var start = StartIPBox.Text.Trim();
        var end = EndIPBox.Text.Trim();
        if (string.IsNullOrEmpty(start) || string.IsNullOrEmpty(end)) return;
        var dlg = new SaveFavoriteWindow(_bridge, start, end) { Owner = this };
        dlg.ShowDialog();
    }

    private void ManageFavorites_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new ManageFavoritesWindow(_bridge)
        {
            Owner = this,
            OnLoad = (s, t) =>
            {
                StartIPBox.Text = s;
                EndIPBox.Text = t;
                ModeCombo.SelectedIndex = 0; // switch back to Range
                UpdateTitle();
            },
        };
        dlg.ShowDialog();
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
