import SwiftUI

struct StatusBarView: View {
    @Bindable var bridge: IPScanBridge

    var body: some View {
        HStack(spacing: 12) {
            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            // Display filter picker
            Picker("", selection: $bridge.displayFilter) {
                ForEach(IPScanBridge.DisplayFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Thread count
            if bridge.scanState == "scanning", let p = bridge.progress {
                Text("Threads: \(p.activeThreads)")
                    .font(.caption)
                    .foregroundStyle(p.activeThreads > 80 ? .red : .secondary)
            }

            // Progress bar (during scan)
            if bridge.scanState == "scanning" || bridge.scanState == "stopping" {
                ProgressView(value: progressValue, total: 100)
                    .frame(width: 120)
            }

            // Stats
            HStack(spacing: 8) {
                Label("\(bridge.stats.alive)", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Label("\(bridge.stats.total - bridge.stats.alive)", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusText: String {
        switch bridge.scanState {
        case "scanning":
            if let p = bridge.progress, !p.currentIP.isEmpty {
                return "Scanning \(p.currentIP)..."
            }
            return "Scanning..."
        case "stopping":
            return "Stopping..."
        case "starting":
            return "Starting..."
        default:
            if bridge.stats.total > 0 {
                return "Scan complete: \(bridge.stats.total) hosts, \(bridge.stats.alive) alive"
            }
            return "Ready"
        }
    }

    private var progressValue: Double {
        bridge.progress?.percent ?? 0
    }
}
