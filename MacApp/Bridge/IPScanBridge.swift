import Foundation
import AppKit

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

    enum DisplayFilter: String, CaseIterable {
        case all = "All"
        case alive = "Alive"
        case withPorts = "With Ports"
    }

    // Observable state
    var results: [ScanResult] = []
    var progress: ScanProgress?
    var scanState: String = "idle"
    var stats: ScanStats = ScanStats(total: 0, alive: 0, withPorts: 0)
    var availableFetchers: [FetcherInfo] = []
    var displayFilter: DisplayFilter = .all

    /// Results filtered by the current display mode.
    var filteredResults: [ScanResult] {
        switch displayFilter {
        case .all:
            return results
        case .alive:
            return results.filter { $0.type == .alive || $0.type == .withPorts }
        case .withPorts:
            return results.filter { $0.type == .withPorts }
        }
    }

    private let decoder = JSONDecoder()

    init() {
        // Tell Go where to store config — uses Apple's recommended directory,
        // which resolves to the sandbox container if sandboxed.
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let configDir = appSupport.appendingPathComponent("AngryIPScanner").path
            let dirStr = strdup(configDir)
            ipscan_set_config_dir(dirStr)
            free(dirStr)
        }

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

    // MARK: - Comments

    func setComment(ip: String, comment: String) {
        let ipStr = strdup(ip)
        let commentStr = strdup(comment)
        ipscan_set_comment(handle, ipStr, commentStr)
        free(ipStr)
        free(commentStr)
    }

    func getComment(ip: String) -> String {
        let ipStr = strdup(ip)
        guard let ptr = ipscan_get_comment(handle, ipStr) else {
            free(ipStr)
            return ""
        }
        free(ipStr)
        defer { ipscan_free_string(ptr) }
        return String(cString: ptr)
    }

    // MARK: - Result Operations

    func deleteResult(ip: String) {
        let ipStr = strdup(ip)
        ipscan_delete_result(handle, ipStr)
        free(ipStr)
        results.removeAll { $0.ip == ip }
        refreshStats()
    }

    // MARK: - Favorites

    func saveFavorite(name: String, startIP: String, endIP: String) {
        let nameStr = strdup(name)
        let args = strdup("\(startIP) - \(endIP)")
        ipscan_save_favorite(handle, nameStr, args)
        free(nameStr)
        free(args)
    }

    func getFavorites() -> [FavoriteEntry] {
        guard let ptr = ipscan_get_favorites(handle) else { return [] }
        defer { ipscan_free_string(ptr) }
        let json = String(cString: ptr)
        return (try? decoder.decode([FavoriteEntry].self, from: Data(json.utf8))) ?? []
    }

    func deleteFavorite(index: Int) {
        ipscan_delete_favorite(handle, Int32(index))
    }

    // MARK: - Export (filtered)

    func exportFiltered(format: String, to url: URL, filter: String) -> Bool {
        let formatStr = strdup(format)
        let pathStr = strdup(url.path)
        let filterStr = strdup(filter)
        let result = ipscan_export_filtered(handle, formatStr, pathStr, filterStr)
        free(formatStr)
        free(pathStr)
        free(filterStr)
        return result == 0
    }

    // MARK: - Openers

    func openInBrowser(ip: String) {
        if let url = URL(string: "http://\(ip)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openSSH(ip: String) {
        let script = "tell application \"Terminal\" to do script \"ssh \(ip)\""
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }

    func openPing(ip: String) {
        let script = "tell application \"Terminal\" to do script \"ping \(ip)\""
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }

    func openTraceroute(ip: String) {
        let script = "tell application \"Terminal\" to do script \"traceroute \(ip)\""
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
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

    // MARK: - Export

    func exportResults(format: String, to url: URL) -> Bool {
        let formatStr = strdup(format)
        let pathStr = strdup(url.path)
        let result = ipscan_export(handle, formatStr, pathStr)
        free(formatStr)
        free(pathStr)
        return result == 0
    }

    // MARK: - Internal callback handlers (called on main thread by CallbackRouter)

    fileprivate func handleResult(json: String) {
        guard let result = try? decoder.decode(ScanResult.self, from: Data(json.utf8)) else {
            return
        }

        if result.complete {
            // Update existing row in-place
            if let idx = results.firstIndex(where: { $0.ip == result.ip }) {
                results[idx].type = result.type
                results[idx].values = result.values
                results[idx].mac = result.mac
                results[idx].complete = true
            } else {
                // Shouldn't happen, but append as fallback
                results.append(result)
            }
            refreshStats()
        } else {
            // First callback — add the row immediately (unknown/scanning)
            results.append(result)
        }
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
