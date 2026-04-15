using System.Windows;
using GoNetworkScanner.Bridge;

namespace GoNetworkScanner.Views.Dialogs;

public partial class StatisticsWindow : Window
{
    public StatisticsWindow(IPScanBridge bridge)
    {
        InitializeComponent();
        var s = bridge.Stats;
        int dead = s.Total - s.Alive;
        TotalText.Text  = s.Total.ToString();
        AliveText.Text  = s.Alive.ToString();
        PortsText.Text  = s.WithPorts.ToString();
        DeadText.Text   = dead.ToString();
        AlivePctText.Text = $"({Percent(s.Alive, s.Total)}%)";
        PortsPctText.Text = $"({Percent(s.WithPorts, s.Total)}%)";
        DeadPctText.Text  = $"({Percent(dead, s.Total)}%)";
    }

    private static string Percent(int n, int total)
    {
        if (total <= 0) return "0";
        return (100.0 * n / total).ToString("0.0");
    }

    private void OK_Click(object sender, RoutedEventArgs e) => Close();
}