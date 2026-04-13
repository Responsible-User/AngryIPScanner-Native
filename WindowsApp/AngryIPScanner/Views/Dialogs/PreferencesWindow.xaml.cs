using System.Windows;
using System.Windows.Controls;
using AngryIPScanner.Bridge;
using AngryIPScanner.Bridge.Models;

namespace AngryIPScanner.Views.Dialogs;

public partial class PreferencesWindow : Window
{
    private readonly IPScanBridge _bridge;
    private ScanConfig? _config;

    public PreferencesWindow(IPScanBridge bridge)
    {
        _bridge = bridge;
        InitializeComponent();
        LoadConfig();
    }

    private void LoadConfig()
    {
        _config = _bridge.GetConfig();
        if (_config == null) return;

        var s = _config.Scanner;

        // Scanning tab
        MaxThreadsBox.Text = s.MaxThreads.ToString();
        ThreadDelayBox.Text = s.ThreadDelay.ToString();
        SelectPinger(s.SelectedPinger);
        PingCountBox.Text = s.PingCount.ToString();
        PingTimeoutBox.Text = s.PingTimeout.ToString();
        ScanDeadHostsCheck.IsChecked = s.ScanDeadHosts;
        SkipBroadcastCheck.IsChecked = s.SkipBroadcastAddresses;

        // Ports tab
        PortTimeoutBox.Text = s.PortTimeout.ToString();
        AdaptTimeoutCheck.IsChecked = s.AdaptPortTimeout;
        MinPortTimeoutBox.Text = s.MinPortTimeout.ToString();
        MinTimeoutPanel.Visibility = s.AdaptPortTimeout ? Visibility.Visible : Visibility.Collapsed;
        PortStringBox.Text = s.PortString;
        UseRequestedPortsCheck.IsChecked = s.UseRequestedPorts;

        // Display tab
        NotAvailableBox.Text = s.NotAvailableText;
        NotScannedBox.Text = s.NotScannedText;
    }

    private void SelectPinger(string id)
    {
        for (int i = 0; i < PingerCombo.Items.Count; i++)
        {
            if (PingerCombo.Items[i] is ComboBoxItem item && (string)item.Tag == id)
            {
                PingerCombo.SelectedIndex = i;
                return;
            }
        }
        PingerCombo.SelectedIndex = 0;
    }

    private void SaveConfig()
    {
        if (_config == null) return;

        var s = _config.Scanner;

        if (int.TryParse(MaxThreadsBox.Text, out int mt)) s.MaxThreads = mt;
        if (int.TryParse(ThreadDelayBox.Text, out int td)) s.ThreadDelay = td;

        if (PingerCombo.SelectedItem is ComboBoxItem pi)
            s.SelectedPinger = (string)pi.Tag;

        if (int.TryParse(PingCountBox.Text, out int pc)) s.PingCount = pc;
        if (int.TryParse(PingTimeoutBox.Text, out int pt)) s.PingTimeout = pt;
        s.ScanDeadHosts = ScanDeadHostsCheck.IsChecked == true;
        s.SkipBroadcastAddresses = SkipBroadcastCheck.IsChecked == true;

        if (int.TryParse(PortTimeoutBox.Text, out int pot)) s.PortTimeout = pot;
        s.AdaptPortTimeout = AdaptTimeoutCheck.IsChecked == true;
        if (int.TryParse(MinPortTimeoutBox.Text, out int mpt)) s.MinPortTimeout = mpt;
        s.PortString = PortStringBox.Text;
        s.UseRequestedPorts = UseRequestedPortsCheck.IsChecked == true;

        s.NotAvailableText = NotAvailableBox.Text;
        s.NotScannedText = NotScannedBox.Text;

        _bridge.SetConfig(_config);
    }

    private void AdaptTimeout_Click(object sender, RoutedEventArgs e)
    {
        MinTimeoutPanel.Visibility = AdaptTimeoutCheck.IsChecked == true
            ? Visibility.Visible : Visibility.Collapsed;
    }

    private void AddCommonPorts_Click(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu();
        var presets = new (string Name, string Ports)[]
        {
            ("Web (80, 443, 8080, 8443)", "80,443,8080,8443"),
            ("Remote Access (22, 23, 3389, 5900)", "22,23,3389,5900"),
            ("Mail (25, 110, 143, 993, 995)", "25,110,143,993,995"),
            ("Database (3306, 5432, 6379, 27017)", "3306,5432,6379,27017"),
            ("File Sharing (21, 445, 139, 548)", "21,445,139,548"),
            ("DNS + DHCP (53, 67, 68)", "53,67,68"),
        };

        foreach (var (name, ports) in presets)
        {
            var item = new MenuItem { Header = name };
            string p = ports; // capture
            item.Click += (_, _) => MergePorts(p);
            menu.Items.Add(item);
        }

        menu.Items.Add(new Separator());
        var allItem = new MenuItem { Header = "All Common Ports" };
        allItem.Click += (_, _) =>
        {
            foreach (var (_, ports) in presets) MergePorts(ports);
        };
        menu.Items.Add(allItem);

        menu.IsOpen = true;
    }

    private void MergePorts(string newPorts)
    {
        var existing = ParsePortSet(PortStringBox.Text);
        var adding = ParsePortSet(newPorts);
        existing.UnionWith(adding);
        PortStringBox.Text = string.Join(",", existing.Order());
    }

    private static HashSet<int> ParsePortSet(string s)
    {
        var result = new HashSet<int>();
        foreach (var part in s.Split([',', ';', ' ', '\t', '\n', '\r'],
                     StringSplitOptions.RemoveEmptyEntries))
        {
            var trimmed = part.Trim();
            int dash = trimmed.IndexOf('-');
            if (dash > 0 && int.TryParse(trimmed[..dash], out int a)
                         && int.TryParse(trimmed[(dash + 1)..], out int b)
                         && a > 0 && b > 0)
            {
                for (int p = a; p <= b; p++) result.Add(p);
            }
            else if (int.TryParse(trimmed, out int port) && port > 0)
            {
                result.Add(port);
            }
        }
        return result;
    }

    private void ResetPorts_Click(object sender, RoutedEventArgs e)
    {
        PortStringBox.Text = "22,80,443";
    }

    private void OK_Click(object sender, RoutedEventArgs e)
    {
        SaveConfig();
        DialogResult = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
