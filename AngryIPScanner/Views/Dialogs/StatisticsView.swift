import SwiftUI

struct StatisticsView: View {
    let stats: ScanStats

    var body: some View {
        VStack(spacing: 12) {
            Text("Scan Statistics")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Hosts scanned:")
                        .foregroundStyle(.secondary)
                    Text("\(stats.total)")
                        .fontWeight(.medium)
                }
                GridRow {
                    Text("Alive hosts:")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("\(stats.alive)")
                            .fontWeight(.medium)
                    }
                }
                GridRow {
                    Text("With open ports:")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("\(stats.withPorts)")
                            .fontWeight(.medium)
                    }
                }
                GridRow {
                    Text("Dead hosts:")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("\(stats.total - stats.alive)")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 280)
    }
}
