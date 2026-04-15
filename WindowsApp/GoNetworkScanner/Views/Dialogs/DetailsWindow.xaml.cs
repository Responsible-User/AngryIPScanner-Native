using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using GoNetworkScanner.Bridge;
using GoNetworkScanner.Bridge.Models;

namespace GoNetworkScanner.Views.Dialogs;

public partial class DetailsWindow : Window
{
    private readonly IPScanBridge _bridge;
    private readonly string _ip;
    private bool _loading = true;

    public DetailsWindow(IPScanBridge bridge, ScanResult result)
    {
        _bridge = bridge;
        _ip = result.IP;
        InitializeComponent();

        HeaderText.Text = $"Details for {result.IP}";

        // Build the label/value pairs from available fetchers
        var items = new List<DetailItem>();
        var fetchers = bridge.AvailableFetchers;
        int count = System.Math.Max(fetchers.Count, result.Values.Count);
        for (int i = 0; i < count; i++)
        {
            string label = i < fetchers.Count ? fetchers[i].Name : $"Column {i}";
            string value = result.GetValue(i);
            if (!string.IsNullOrEmpty(value))
                items.Add(new DetailItem(label, value));
        }
        DetailsList.ItemsSource = items;

        // Load existing comment
        CommentBox.Text = bridge.GetComment(_ip);
        _loading = false;
    }

    private void Comment_Changed(object sender, TextChangedEventArgs e)
    {
        if (_loading) return;
        _bridge.SetComment(_ip, CommentBox.Text);
    }

    private void OK_Click(object sender, RoutedEventArgs e) => Close();

    private record DetailItem(string Label, string Value);
}
