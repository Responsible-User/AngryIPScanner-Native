import Foundation

/// Swift wrapper around the libipscan C API.
/// All Go interactions go through this class.
@MainActor
@Observable
final class IPScanBridge {
    /// The handle is nonisolated(unsafe) so deinit can access it.
    /// It's only mutated during init (main actor) and read in deinit.
    nonisolated(unsafe) private var handle: Int32 = 0

    // Observable state
    var results: [ScanResult] = []
    var progress: ScanProgress?
    var scanState: String = "idle"
    var stats: ScanStats = ScanStats(total: 0, alive: 0, withPorts: 0)
    var availableFetchers: [FetcherInfo] = []

    private let decoder = JSONDecoder()

    init() {
        handle = ipscan_new(nil)
        loadAvailableFetchers()
    }

    deinit {
        if handle != 0 {
            ipscan_free(handle)
        }
    }

    // MARK: - Scanning

    func startScan(startIP: String, endIP: String) {
        results.removeAll()
        stats = ScanStats(total: 0, alive: 0, withPorts: 0)

        let feederConfig = FeederConfig(type: "range", startIP: startIP, endIP: endIP)
        guard let json = try? JSONEncoder().encode(feederConfig),
              let jsonStr = String(data: json, encoding: .utf8) else {
            return
        }

        // Set up callbacks before starting
        setupCallbacks()

        let mutableStr = strdup(jsonStr)
        let result = ipscan_start_scan(handle, mutableStr)
        free(mutableStr)
        if result != 0 {
            print("Failed to start scan: error \(result)")
        }

        scanState = "scanning"
    }

    func stopScan() {
        ipscan_stop_scan(handle)
        scanState = "stopping"
    }

    // MARK: - Config

    func getConfig() -> ScanConfig? {
        guard let ptr = ipscan_get_config(handle) else { return nil }
        defer { ipscan_free_string(ptr) }
        let json = String(cString: ptr)
        return try? decoder.decode(ScanConfig.self, from: Data(json.utf8))
    }

    func setConfig(_ config: ScanConfig) {
        guard let data = try? JSONEncoder().encode(config),
              let json = String(data: data, encoding: .utf8) else { return }
        let mutable = strdup(json)
        ipscan_set_config(handle, mutable)
        free(mutable)
    }

    // MARK: - Results

    func refreshStats() {
        guard let ptr = ipscan_get_stats(handle) else { return }
        defer { ipscan_free_string(ptr) }
        let json = String(cString: ptr)
        if let s = try? decoder.decode(ScanStats.self, from: Data(json.utf8)) {
            stats = s
        }
    }

    // MARK: - State

    func refreshState() {
        guard let ptr = ipscan_get_state(handle) else { return }
        defer { ipscan_free_string(ptr) }
        let json = String(cString: ptr)
        if let dict = try? JSONDecoder().decode([String: String].self, from: Data(json.utf8)),
           let state = dict["state"] {
            scanState = state
        }
    }

    // MARK: - Fetchers

    private func loadAvailableFetchers() {
        guard let ptr = ipscan_get_available_fetchers(handle) else { return }
        defer { ipscan_free_string(ptr) }
        let json = String(cString: ptr)
        if let fetchers = try? decoder.decode([FetcherInfo].self, from: Data(json.utf8)) {
            availableFetchers = fetchers
        }
    }

    // MARK: - Callbacks

    /// Prevent ARC from invalidating self while C callbacks are active.
    nonisolated(unsafe) private static var activeBridges: Set<ObjectIdentifier> = []
    nonisolated(unsafe) private static var bridgeMap: [ObjectIdentifier: IPScanBridge] = [:]

    private func setupCallbacks() {
        let id = ObjectIdentifier(self)
        IPScanBridge.activeBridges.insert(id)
        IPScanBridge.bridgeMap[id] = self

        let opaque = Unmanaged.passUnretained(self).toOpaque()

        ipscan_set_result_callback(handle, { jsonPtr, ctx in
            guard let jsonPtr, let ctx else { return }
            let json = String(cString: jsonPtr)
            let bridge = Unmanaged<IPScanBridge>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                bridge.handleResult(json: json)
            }
        }, opaque)

        ipscan_set_progress_callback(handle, { jsonPtr, ctx in
            guard let jsonPtr, let ctx else { return }
            let json = String(cString: jsonPtr)
            let bridge = Unmanaged<IPScanBridge>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                bridge.handleProgress(json: json)
            }
        }, opaque)
    }

    private func handleResult(json: String) {
        guard let result = try? decoder.decode(ScanResult.self, from: Data(json.utf8)) else {
            return
        }
        results.append(result)
        refreshStats()
    }

    private func handleProgress(json: String) {
        guard let p = try? decoder.decode(ScanProgress.self, from: Data(json.utf8)) else {
            return
        }
        progress = p
        scanState = p.state

        if p.state == "idle" {
            refreshStats()
            let id = ObjectIdentifier(self)
            IPScanBridge.activeBridges.remove(id)
            IPScanBridge.bridgeMap.removeValue(forKey: id)
        }
    }
}
