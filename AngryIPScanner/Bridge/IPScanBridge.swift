import Foundation

// MARK: - Free C callback functions (must be at file scope, completely nonisolated)

private func resultCallbackFunc(_ jsonPtr: UnsafePointer<CChar>?, _ ctx: UnsafeMutableRawPointer?) {
    guard let jsonPtr else { return }
    let json = String(cString: jsonPtr)
    let idValue = Int(bitPattern: ctx)
    DispatchQueue.main.async {
        CallbackRouter.shared.handleResult(bridgeID: idValue, json: json)
    }
}

private func progressCallbackFunc(_ jsonPtr: UnsafePointer<CChar>?, _ ctx: UnsafeMutableRawPointer?) {
    guard let jsonPtr else { return }
    let json = String(cString: jsonPtr)
    let idValue = Int(bitPattern: ctx)
    DispatchQueue.main.async {
        CallbackRouter.shared.handleProgress(bridgeID: idValue, json: json)
    }
}

// MARK: - IPScanBridge

/// Swift wrapper around the libipscan C API.
/// All Go interactions go through this class.
@MainActor
@Observable
final class IPScanBridge {
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

        // Register in callback router and set up callbacks
        CallbackRouter.shared.register(self)
        let bridgeID = CallbackRouter.shared.id(for: self)
        let ctxPtr = UnsafeMutableRawPointer(bitPattern: bridgeID)

        ipscan_set_result_callback(handle, resultCallbackFunc, ctxPtr)
        ipscan_set_progress_callback(handle, progressCallbackFunc, ctxPtr)

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

    // MARK: - Internal callback handlers (called on main thread by CallbackRouter)

    fileprivate func handleResult(json: String) {
        guard let result = try? decoder.decode(ScanResult.self, from: Data(json.utf8)) else {
            return
        }
        results.append(result)
        refreshStats()
    }

    fileprivate func handleProgress(json: String) {
        guard let p = try? decoder.decode(ScanProgress.self, from: Data(json.utf8)) else {
            return
        }
        progress = p
        scanState = p.state

        if p.state == "idle" {
            refreshStats()
            CallbackRouter.shared.unregister(self)
        }
    }
}

// MARK: - Callback Router

/// Routes C callbacks from Go goroutines to the correct IPScanBridge instance
/// on the main thread, avoiding Swift concurrency isolation issues.
final class CallbackRouter: @unchecked Sendable {
    static let shared = CallbackRouter()

    private var bridges: [Int: IPScanBridge] = [:]
    private var nextID = 1
    private let lock = NSLock()

    func register(_ bridge: IPScanBridge) {
        lock.lock()
        bridges = bridges.filter { $0.value !== bridge }
        bridges[nextID] = bridge
        nextID += 1
        lock.unlock()
    }

    func unregister(_ bridge: IPScanBridge) {
        lock.lock()
        bridges = bridges.filter { $0.value !== bridge }
        lock.unlock()
    }

    func id(for bridge: IPScanBridge) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return bridges.first(where: { $0.value === bridge })?.key ?? 0
    }

    func handleResult(bridgeID: Int, json: String) {
        lock.lock()
        let bridge = bridges[bridgeID]
        lock.unlock()
        guard let bridge else { return }
        MainActor.assumeIsolated {
            bridge.handleResult(json: json)
        }
    }

    func handleProgress(bridgeID: Int, json: String) {
        lock.lock()
        let bridge = bridges[bridgeID]
        lock.unlock()
        guard let bridge else { return }
        MainActor.assumeIsolated {
            bridge.handleProgress(json: json)
        }
    }
}
