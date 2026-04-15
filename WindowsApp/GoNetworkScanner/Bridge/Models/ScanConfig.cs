using System.Text.Json.Serialization;

namespace GoNetworkScanner.Bridge.Models;

public class ScanConfig
{
    [JsonPropertyName("scanner")]
    public ScannerConfig Scanner { get; set; } = new();
}

public class ScannerConfig
{
    [JsonPropertyName("maxThreads")]
    public int MaxThreads { get; set; } = 100;

    [JsonPropertyName("threadDelay")]
    public int ThreadDelay { get; set; } = 20;

    [JsonPropertyName("scanDeadHosts")]
    public bool ScanDeadHosts { get; set; }

    [JsonPropertyName("selectedPinger")]
    public string SelectedPinger { get; set; } = "pinger.combined";

    [JsonPropertyName("pingTimeout")]
    public int PingTimeout { get; set; } = 2000;

    [JsonPropertyName("pingCount")]
    public int PingCount { get; set; } = 5;

    [JsonPropertyName("skipBroadcastAddresses")]
    public bool SkipBroadcastAddresses { get; set; } = true;

    [JsonPropertyName("portString")]
    public string PortString { get; set; } = "22,80,443";

    [JsonPropertyName("portTimeout")]
    public int PortTimeout { get; set; } = 2000;

    [JsonPropertyName("adaptPortTimeout")]
    public bool AdaptPortTimeout { get; set; }

    [JsonPropertyName("minPortTimeout")]
    public int MinPortTimeout { get; set; } = 500;

    [JsonPropertyName("useRequestedPorts")]
    public bool UseRequestedPorts { get; set; } = true;

    // JSON key must match the Go struct tag `json:"selectedFetchers,omitempty"`;
    // prior "selectedFetcherIDs" silently dropped every selection round-trip.
    [JsonPropertyName("selectedFetchers")]
    public List<string>? SelectedFetcherIDs { get; set; }

    [JsonPropertyName("notAvailableText")]
    public string NotAvailableText { get; set; } = "[n/a]";

    [JsonPropertyName("notScannedText")]
    public string NotScannedText { get; set; } = "[n/s]";
}

public class FeederConfig
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "range";

    [JsonPropertyName("startIP")]
    public string? StartIP { get; set; }

    [JsonPropertyName("endIP")]
    public string? EndIP { get; set; }

    [JsonPropertyName("filePath")]
    public string? FilePath { get; set; }
}

public class FetcherInfo
{
    [JsonPropertyName("id")]
    public string ID { get; set; } = "";

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";
}

/// <summary>
/// A saved scan target. `FeederArgs` encodes the range ("192.168.1.1 - 192.168.1.255").
/// </summary>
public class FavoriteEntry
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("feederArgs")]
    public string FeederArgs { get; set; } = "";
}
