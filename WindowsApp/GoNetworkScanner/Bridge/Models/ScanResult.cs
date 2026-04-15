using System.Text.Json;
using System.Text.Json.Serialization;

namespace GoNetworkScanner.Bridge.Models;

public enum ResultType { Unknown, Dead, Alive, WithPorts }

public class ScanResult
{
    [JsonPropertyName("ip")]
    public string IP { get; set; } = "";

    [JsonPropertyName("type")]
    public string TypeString { get; set; } = "unknown";

    [JsonPropertyName("values")]
    public List<JsonElement> Values { get; set; } = [];

    [JsonPropertyName("mac")]
    public string? MAC { get; set; }

    [JsonPropertyName("complete")]
    public bool Complete { get; set; }

    [JsonIgnore]
    public ResultType Type => TypeString switch
    {
        "alive" => ResultType.Alive,
        "dead" => ResultType.Dead,
        "with_ports" => ResultType.WithPorts,
        _ => ResultType.Unknown
    };

    // Computed display properties for DataGrid column binding.
    // Indices match the fetcher order from libipscan.
    [JsonIgnore] public string Ping => GetValue(1);
    [JsonIgnore] public string TTL => GetValue(2);
    [JsonIgnore] public string Hostname => GetValue(3);
    [JsonIgnore] public string Ports => GetValue(4);
    [JsonIgnore] public string FilteredPorts => GetValue(5);
    [JsonIgnore] public string MACAddress => GetValue(6);
    [JsonIgnore] public string MACVendor => GetValue(7);
    [JsonIgnore] public string WebDetect => GetValue(8);
    [JsonIgnore] public string NetBIOS => GetValue(9);
    [JsonIgnore] public string PacketLoss => GetValue(10);
    [JsonIgnore] public string Comment => GetValue(11);

    /// <summary>
    /// Zero-padded IP for correct numeric sorting in the DataGrid.
    /// </summary>
    [JsonIgnore]
    public string SortableIP =>
        string.Join(".", IP.Split('.').Select(p => p.PadLeft(3, '0')));

    public string GetValue(int index)
    {
        if (index >= Values.Count) return "";
        var val = Values[index];
        return val.ValueKind switch
        {
            JsonValueKind.Null or JsonValueKind.Undefined => "",
            JsonValueKind.String => val.GetString() ?? "",
            _ => val.ToString()
        };
    }
}
