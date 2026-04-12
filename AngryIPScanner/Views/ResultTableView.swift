import SwiftUI

struct ResultTableView: View {
    @Bindable var bridge: IPScanBridge
    @State private var selectedResults: Set<ScanResult.ID> = []
    @State private var sortOrder: [KeyPathComparator<ScanResult>] = [
        .init(\.ip, order: .forward)
    ]

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
                        Button("Copy IP") {
                            copyToClipboard(result.ip)
                        }
                        Button("Copy All Columns") {
                            let text = result.values.map(\.description).joined(separator: "\t")
                            copyToClipboard(text)
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyIP)) { _ in
            copySelectedIPs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyAll)) { _ in
            copySelectedAll()
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
