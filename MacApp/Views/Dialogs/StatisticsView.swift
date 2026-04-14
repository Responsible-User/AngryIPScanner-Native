import SwiftUI

struct StatisticsView: View {
    @Bindable var bridge: IPScanBridge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Scan Statistics")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Hosts scanned:").foregroundStyle(.secondary)
                    Text("\(bridge.stats.total)").fontWeight(.medium)
                }
                GridRow {
                    Text("Alive:").foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("\(bridge.stats.alive)").fontWeight(.medium)
                        Text("(\(percent(bridge.stats.alive, bridge.stats.total))%)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("With open ports:").foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("\(bridge.stats.withPorts)").fontWeight(.medium)
                        Text("(\(percent(bridge.stats.withPorts, bridge.stats.total))%)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("Dead:").foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("\(bridge.stats.total - bridge.stats.alive)").fontWeight(.medium)
                        Text("(\(percent(bridge.stats.total - bridge.stats.alive, bridge.stats.total))%)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private func percent(_ n: Int, _ total: Int) -> String {
        guard total > 0 else { return "0" }
        return String(format: "%.1f", Double(n) / Double(total) * 100)
    }
}
