import SwiftUI

struct MainWindowView: View {
    @Bindable var bridge: IPScanBridge
    @State private var startIP: String = ""
    @State private var endIP: String = ""
    @State private var showSaveFavorite = false
    @State private var showManageFavorites = false
    @State private var showSelectFetchers = false
    @State private var showFind = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (shown when Cmd+F is pressed)
            if showFind {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search results...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            NotificationCenter.default.post(name: .findNext, object: nil, userInfo: ["text": searchText])
                        }
                    Button("Done") {
                        showFind = false
                        searchText = ""
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            }

            // Feeder area + controls
            FeederAreaView(
                bridge: bridge,
                startIP: $startIP,
                endIP: $endIP
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Results table
            ResultTableView(bridge: bridge)

            Divider()

            // Status bar
            StatusBarView(bridge: bridge)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            autoDetectLocalRange()
        }
        // Menu notification handlers
        .onReceive(NotificationCenter.default.publisher(for: .loadFavorite)) { notification in
            if let info = notification.userInfo,
               let start = info["startIP"] as? String,
               let end = info["endIP"] as? String {
                startIP = start
                endIP = end
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSaveFavorite)) { _ in
            showSaveFavorite = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showManageFavorites)) { _ in
            showManageFavorites = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSelectFetchers)) { _ in
            showSelectFetchers = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFind)) { _ in
            showFind = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportResults)) { _ in
            exportResults()
        }
        .sheet(isPresented: $showSaveFavorite) {
            SaveFavoriteView(bridge: bridge, startIP: startIP, endIP: endIP)
        }
        .sheet(isPresented: $showManageFavorites) {
            ManageFavoritesView(bridge: bridge) { start, end in
                startIP = start
                endIP = end
            }
        }
        .sheet(isPresented: $showSelectFetchers) {
            SelectFetchersView(bridge: bridge)
        }
        .navigationTitle(windowTitle)
    }

    private var windowTitle: String {
        if bridge.scanState == "scanning", let p = bridge.progress {
            return String(format: "%.0f%% - Angry IP Scanner", p.percent)
        }
        return "Angry IP Scanner"
    }

    // MARK: - Export

    private func exportResults() {
        let panel = NSSavePanel()
        panel.title = "Export Scan Results"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsOtherFileTypes = true
        panel.nameFieldStringValue = "scan_results.csv"

        // Format picker accessory view
        let formatCodes = ["csv", "txt", "xml", "iplist", "sql"]
        let formatLabels = ["CSV (.csv)", "Text (.txt)", "XML (.xml)", "IP List (.lst)", "SQL (.sql)"]
        let extensions = ["csv", "txt", "xml", "lst", "sql"]

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24), pullsDown: false)
        popup.addItems(withTitles: formatLabels)

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 4, width: 55, height: 24)
        popup.frame = NSRect(x: 58, y: 2, width: 220, height: 24)
        accessory.addSubview(label)
        accessory.addSubview(popup)
        panel.accessoryView = accessory

        panel.begin { response in
            guard response == .OK, var url = panel.url else { return }

            // Get format from popup selection
            let idx = popup.indexOfSelectedItem
            let format = formatCodes[idx]
            let expectedExt = extensions[idx]

            // Ensure the file has the correct extension
            if url.pathExtension.lowercased() != expectedExt {
                url = url.deletingPathExtension().appendingPathExtension(expectedExt)
            }

            // Use filtered export matching current display filter
            let filter: String
            switch bridge.displayFilter {
            case .all: filter = "all"
            case .alive: filter = "alive"
            case .withPorts: filter = "with_ports"
            }

            let success = bridge.exportFiltered(format: format, to: url, filter: filter)
            if !success {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not export results to \(url.lastPathComponent)"
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    // MARK: - Network detection

    private func autoDetectLocalRange() {
        guard startIP.isEmpty else { return }

        guard let info = getLocalInterfaceInfo() else {
            startIP = "192.168.1.1"
            endIP = "192.168.1.255"
            return
        }

        let ip = info.ip
        let prefix = info.prefixLen

        let mask: UInt32 = prefix == 0 ? 0 : ~((1 << (32 - prefix)) - 1)
        let ipNum = ipToUInt32(ip)
        let networkStart = ipNum & mask
        let networkEnd = networkStart | ~mask

        startIP = uint32ToIP(networkStart + 1)
        endIP = uint32ToIP(networkEnd - 1)
    }

    private struct InterfaceInfo {
        let ip: [UInt8]
        let prefixLen: Int
    }

    private func getLocalInterfaceInfo() -> InterfaceInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len),
                             &hostname, socklen_t(hostname.count),
                             nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ipStr = String(cString: hostname)
            if ipStr.hasPrefix("127.") { continue }

            let parts = ipStr.split(separator: ".")
            guard parts.count == 4 else { continue }
            let bytes = parts.compactMap { UInt8($0) }
            guard bytes.count == 4 else { continue }

            if let netmask = ptr.pointee.ifa_netmask {
                let maskAddr = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let maskInt = UInt32(bigEndian: maskAddr.sin_addr.s_addr)
                let prefix = maskInt.nonzeroBitCount
                return InterfaceInfo(ip: bytes, prefixLen: prefix)
            }

            return InterfaceInfo(ip: bytes, prefixLen: 24)
        }
        return nil
    }

    private func ipToUInt32(_ bytes: [UInt8]) -> UInt32 {
        UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    private func uint32ToIP(_ n: UInt32) -> String {
        "\(n >> 24 & 0xFF).\(n >> 16 & 0xFF).\(n >> 8 & 0xFF).\(n & 0xFF)"
    }
}

extension Notification.Name {
    static let findNext = Notification.Name("findNext")
}
