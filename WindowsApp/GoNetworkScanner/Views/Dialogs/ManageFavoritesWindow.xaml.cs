using System;
using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using GoNetworkScanner.Bridge;
using GoNetworkScanner.Bridge.Models;

namespace GoNetworkScanner.Views.Dialogs;

public partial class ManageFavoritesWindow : Window
{
    private readonly IPScanBridge _bridge;
    private readonly ObservableCollection<FavoriteEntry> _items = [];

    /// <summary>
    /// Called with (startIP, endIP) parsed from the favorite's feederArgs
    /// when the user clicks Load. Null if user just closes the window.
    /// </summary>
    public Action<string, string>? OnLoad { get; set; }

    public ManageFavoritesWindow(IPScanBridge bridge)
    {
        _bridge = bridge;
        InitializeComponent();
        FavoritesList.ItemsSource = _items;
        Refresh();
    }

    private void Refresh()
    {
        _items.Clear();
        foreach (var f in _bridge.GetFavorites()) _items.Add(f);
        EmptyText.Visibility = _items.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        FavoritesList.Visibility = _items.Count == 0 ? Visibility.Collapsed : Visibility.Visible;
    }

    private void Load_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button b || b.Tag is not FavoriteEntry fav) return;

        // feederArgs is "startIP - endIP"
        var parts = fav.FeederArgs.Split('-', 2, StringSplitOptions.TrimEntries);
        if (parts.Length == 2)
        {
            OnLoad?.Invoke(parts[0], parts[1]);
        }
        DialogResult = true;
        Close();
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button b || b.Tag is not FavoriteEntry fav) return;
        int idx = _items.IndexOf(fav);
        if (idx < 0) return;
        _bridge.DeleteFavorite(idx);
        Refresh();
    }

    private void Done_Click(object sender, RoutedEventArgs e) => Close();
}
