using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using AngryIPScanner.Bridge;
using AngryIPScanner.Bridge.Models;

namespace AngryIPScanner.Views.Dialogs;

public partial class SelectFetchersWindow : Window
{
    private readonly IPScanBridge _bridge;
    public ObservableCollection<FetcherSelection> Fetchers { get; } = [];

    public SelectFetchersWindow(IPScanBridge bridge)
    {
        _bridge = bridge;
        InitializeComponent();
        LoadFetchers();
        FetcherList.ItemsSource = Fetchers;
    }

    private void LoadFetchers()
    {
        var config = _bridge.GetConfig();
        var selectedIds = config?.Scanner.SelectedFetcherIDs;

        foreach (var f in _bridge.AvailableFetchers)
        {
            Fetchers.Add(new FetcherSelection
            {
                ID = f.ID,
                Name = f.Name,
                // If no explicit selection, all fetchers are enabled
                IsSelected = selectedIds == null || selectedIds.Count == 0
                    || selectedIds.Contains(f.ID)
            });
        }
    }

    private void SelectAll_Click(object sender, RoutedEventArgs e)
    {
        foreach (var f in Fetchers) f.IsSelected = true;
    }

    private void SelectNone_Click(object sender, RoutedEventArgs e)
    {
        foreach (var f in Fetchers) f.IsSelected = false;
    }

    private void OK_Click(object sender, RoutedEventArgs e)
    {
        var config = _bridge.GetConfig();
        if (config != null)
        {
            var selected = Fetchers.Where(f => f.IsSelected).Select(f => f.ID).ToList();

            // If all are selected, clear the list (Go default = use all)
            config.Scanner.SelectedFetcherIDs =
                selected.Count == Fetchers.Count ? null : selected;

            _bridge.SetConfig(config);
        }

        DialogResult = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}

/// <summary>
/// Wraps a FetcherInfo with a selectable checkbox state.
/// </summary>
public class FetcherSelection : INotifyPropertyChanged
{
    public string ID { get; set; } = "";
    public string Name { get; set; } = "";

    private bool _isSelected = true;
    public bool IsSelected
    {
        get => _isSelected;
        set
        {
            _isSelected = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsSelected)));
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
