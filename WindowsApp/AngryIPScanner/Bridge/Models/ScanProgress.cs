using System.Text.Json.Serialization;

namespace AngryIPScanner.Bridge.Models;

public class ScanProgress
{
    [JsonPropertyName("currentIP")]
    public string CurrentIP { get; set; } = "";

    [JsonPropertyName("percent")]
    public double Percent { get; set; }

    [JsonPropertyName("activeThreads")]
    public int ActiveThreads { get; set; }

    [JsonPropertyName("state")]
    public string State { get; set; } = "";
}

public class ScanStats
{
    [JsonPropertyName("total")]
    public int Total { get; set; }

    [JsonPropertyName("alive")]
    public int Alive { get; set; }

    [JsonPropertyName("withPorts")]
    public int WithPorts { get; set; }
}
