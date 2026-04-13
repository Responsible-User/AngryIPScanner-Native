import Foundation

/// Progress update from the Go scan engine.
struct ScanProgress: Codable {
    let currentIP: String
    let percent: Double
    let activeThreads: Int32
    let state: String

    private enum CodingKeys: String, CodingKey {
        case currentIP = "current_ip"
        case percent
        case activeThreads = "active_threads"
        case state
    }
}

/// Statistics from the Go scan engine.
struct ScanStats: Codable {
    let total: Int
    let alive: Int
    let withPorts: Int
}
