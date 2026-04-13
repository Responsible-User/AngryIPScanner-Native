import SwiftUI

struct ResultTableView: View {
    @Bindable var bridge: IPScanBridge
    @State private var selectedResults: Set<ScanResult.ID> = []
    @State private var sortOrder: [KeyPathComparator<ScanResult>] = [
        .init(\.ip, order: .forward)
    ]
    @State private var detailResult: ScanResult?
    @State private var scrollTarget: ScanResult.ID?

    var body: some View {
        Table(of: ScanResult.self, selection: $selectedResults, sortOrder: $sortOrder) {
            TableColumn("IP", value: \.ip) { result in
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(for: result.type))
                        .frame(width: 8, height: 8)
                    Text(result.ip)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .width(min: 120, ideal: 140)

            TableColumn("Ping", value: \.pingSort) { result in
                Text(valueAt(index: 1, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 50, ideal: 70)

            TableColumn("TTL", value: \.ttlSort) { result in
                Text(valueAt(index: 2, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 35, ideal: 50)

            TableColumn("Hostname", value: \.hostnameSort) { result in
                Text(valueAt(index: 3, in: result))
            }
            .width(min: 100, ideal: 180)

            TableColumn("Ports", value: \.portsSort) { result in
                Text(valueAt(index: 4, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 60, ideal: 100)

            TableColumn("MAC Address", value: \.macSort) { result in
                Text(valueAt(index: 6, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 100, ideal: 140)

            TableColumn("MAC Vendor", value: \.vendorSort) { result in
                Text(valueAt(index: 7, in: result))
            }
            .width(min: 80, ideal: 120)

            TableColumn("Web detect", value: \.webSort) { result in
                Text(valueAt(index: 8, in: result))
            }
            .width(min: 80, ideal: 120)
        } rows: {
            ForEach(sortedResults) { result in
                TableRow(result)
                    .contextMenu {
                        Button("Show Details...") {
                            detailResult = result
                        }

                        Divider()

                        Button("Copy IP") {
                            copyToClipboard(result.ip)
                        }
                        Button("Copy All Columns") {
                            let text = result.values.map(\.description).joined(separator: "\t")
                            copyToClipboard(text)
                        }

                        Divider()

                        Menu("Open") {
                            Button("Web Browser") { bridge.openInBrowser(ip: result.ip) }
                            Button("SSH") { bridge.openSSH(ip: result.ip) }
                            Button("Ping") { bridge.openPing(ip: result.ip) }
                            Button("Traceroute") { bridge.openTraceroute(ip: result.ip) }
                        }

                        Divider()

                        Button("Rescan") {
                            bridge.startScan(startIP: result.ip, endIP: result.ip)
                        }

                        Button("Delete", role: .destructive) {
                            bridge.deleteResult(ip: result.ip)
                        }
                    }
            }
        }
        .scrollPosition(id: $scrollTarget)
        .sheet(item: $detailResult) { result in
            DetailsView(result: result, bridge: bridge)
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyIP)) { _ in
            copySelectedIPs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyAll)) { _ in
            copySelectedAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToNextAlive)) { _ in
            goToAlive(forward: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToPrevAlive)) { _ in
            goToAlive(forward: false)
        }
    }

    private var sortedResults: [ScanResult] {
        bridge.filteredResults.sorted(using: sortOrder)
    }

    private func valueAt(index: Int, in result: ScanResult) -> String {
        guard index < result.values.count else { return "" }
        return result.values[index].description
    }

    private func statusColor(for type: ScanResult.ResultType) -> Color {
        switch type {
        case .alive: return .green
        case .withPorts: return .blue
        case .dead: return .red
        case .unknown: return .gray
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copySelectedIPs() {
        let ips = bridge.filteredResults
            .filter { selectedResults.contains($0.id) }
            .map(\.ip)
            .joined(separator: "\n")
        if !ips.isEmpty { copyToClipboard(ips) }
    }

    private func copySelectedAll() {
        let lines = bridge.filteredResults
            .filter { selectedResults.contains($0.id) }
            .map { $0.values.map(\.description).joined(separator: "\t") }
            .joined(separator: "\n")
        if !lines.isEmpty { copyToClipboard(lines) }
    }

    private func goToAlive(forward: Bool) {
        let results = sortedResults
        guard !results.isEmpty else { return }

        // Find current position
        let currentIndex: Int
        if let selectedID = selectedResults.first,
           let idx = results.firstIndex(where: { $0.id == selectedID }) {
            currentIndex = idx
        } else {
            currentIndex = forward ? -1 : results.count
        }

        // Search for next/previous alive
        if forward {
            for i in (currentIndex + 1)..<results.count {
                if results[i].type == .alive || results[i].type == .withPorts {
                    selectedResults = [results[i].id]
                    scrollTarget = results[i].id
                    return
                }
            }
            // Wrap around
            for i in 0...currentIndex where i < results.count {
                if results[i].type == .alive || results[i].type == .withPorts {
                    selectedResults = [results[i].id]
                    scrollTarget = results[i].id
                    return
                }
            }
        } else {
            for i in stride(from: currentIndex - 1, through: 0, by: -1) {
                if results[i].type == .alive || results[i].type == .withPorts {
                    selectedResults = [results[i].id]
                    scrollTarget = results[i].id
                    return
                }
            }
            // Wrap around
            for i in stride(from: results.count - 1, through: currentIndex, by: -1) {
                if results[i].type == .alive || results[i].type == .withPorts {
                    selectedResults = [results[i].id]
                    scrollTarget = results[i].id
                    return
                }
            }
        }
    }
}

// MARK: - Sortable key paths for all columns

extension ScanResult {
    var pingSort: String { valueAt(1) }
    var ttlSort: String { valueAt(2) }
    var hostnameSort: String { valueAt(3) }
    var portsSort: String { valueAt(4) }
    var macSort: String { valueAt(6) }
    var vendorSort: String { valueAt(7) }
    var webSort: String { valueAt(8) }

    private func valueAt(_ index: Int) -> String {
        guard index < values.count else { return "" }
        return values[index].description
    }
}
