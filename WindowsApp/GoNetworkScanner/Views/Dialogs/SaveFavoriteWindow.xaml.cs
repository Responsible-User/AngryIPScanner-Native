using System.Windows;
using System.Windows.Controls;
using GoNetworkScanner.Bridge;

namespace GoNetworkScanner.Views.Dialogs;

public partial class SaveFavoriteWindow : Window
{
    private readonly IPScanBridge _bridge;
    private readonly string _startIP;
    private readonly string _endIP;

    public SaveFavoriteWindow(IPScanBridge bridge, string startIP, string endIP)
    {
        _bridge = bridge;
        _startIP = startIP;
        _endIP = endIP;
        InitializeComponent();
        RangeText.Text = $"Range: {startIP} – {endIP}";
        NameBox.Focus();
    }

    private void Name_Changed(object sender, TextChangedEventArgs e)
    {
        SaveButton.IsEnabled = !string.IsNullOrWhiteSpace(NameBox.Text);
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var name = NameBox.Text.Trim();
        if (string.IsNullOrEmpty(name)) return;
        _bridge.SaveFavorite(name, _startIP, _endIP);
        DialogResult = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => Close();
}
