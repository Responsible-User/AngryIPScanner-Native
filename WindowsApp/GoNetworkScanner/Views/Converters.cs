using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace GoNetworkScanner.Views;

/// <summary>
/// Converts a result type string ("alive", "dead", "with_ports", "unknown")
/// to a status dot color brush.
/// </summary>
public class ResultTypeToColorConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is string type ? type switch
        {
            "alive" => Brushes.LimeGreen,
            "with_ports" => Brushes.DodgerBlue,
            "dead" => Brushes.IndianRed,
            _ => Brushes.Gray
        } : Brushes.Gray;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
