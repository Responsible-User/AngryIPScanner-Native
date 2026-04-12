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

            TableColumn("Ping") { result in
                Text(valueAt(index: 1, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 50, ideal: 70)

            TableColumn("TTL") { result in
                Text(valueAt(index: 2, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 35, ideal: 50)

            TableColumn("Hostname") { result in
                Text(valueAt(index: 3, in: result))
            }
            .width(min: 100, ideal: 180)

            TableColumn("Ports") { result in
                Text(valueAt(index: 4, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 60, ideal: 100)

            TableColumn("MAC Address") { result in
                Text(valueAt(index: 6, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 100, ideal: 140)

            TableColumn("MAC Vendor") { result in
                Text(valueAt(index: 7, in: result))
            }
            .width(min: 80, ideal: 120)

            TableColumn("Web detect") { result in
                Text(valueAt(index: 8, in: result))
            }
            .width(min: 80, ideal: 120)
        } rows: {
            ForEach(sortedResults) { result in
                TableRow(result)
                    .contextMenu {
                        Button("Copy IP") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.ip, forType: .string)
                        }
                        Button("Copy All") {
                            let text = result.values.map(\.description).joined(separator: "\t")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                    }
            }
        }
        .onChange(of: sortOrder) { _, _ in }
    }

    private var sortedResults: [ScanResult] {
        bridge.results.sorted(using: sortOrder)
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
}
