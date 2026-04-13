import Foundation

/// Mirrors the Go AppConfig for JSON serialization across the FFI boundary.
struct ScanConfig: Codable {
    var scanner: ScannerConfig

    struct ScannerConfig: Codable {
        var maxThreads: Int
        var threadDelay: Int
        var scanDeadHosts: Bool
        var selectedPinger: String
        var pingTimeout: Int
        var pingCount: Int
        var skipBroadcastAddresses: Bool
        var portTimeout: Int
        var adaptPortTimeout: Bool
        var minPortTimeout: Int
        var portString: String
        var useRequestedPorts: Bool
        var notAvailableText: String
        var notScannedText: String
        var selectedFetchers: [String]?
    }
}

/// Feeder configuration sent to Go to start a scan.
struct FeederConfig: Codable {
    let type: String
    let startIP: String?
    let endIP: String?
    var filePath: String? = nil
}

/// Fetcher info returned from Go.
struct FetcherInfo: Codable, Identifiable {
    let id: String
    let name: String
}
