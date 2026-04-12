import SwiftUI

struct FeederAreaView: View {
    @Bindable var bridge: IPScanBridge
    @Binding var startIP: String
    @Binding var endIP: String

    var body: some View {
        HStack(spacing: 12) {
            // IP Range inputs
            VStack(alignment: .leading, spacing: 4) {
                Text("IP Range:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Start IP", text: $startIP)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onSubmit { startScan() }

                    Text("to")
                        .foregroundStyle(.secondary)

                    TextField("End IP", text: $endIP)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onSubmit { startScan() }
                }
            }

            Spacer()

            // Start/Stop button
            Button(action: {
                if bridge.scanState == "scanning" || bridge.scanState == "starting" {
                    bridge.stopScan()
                } else {
                    startScan()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: buttonIcon)
                    Text(buttonLabel)
                }
                .frame(width: 80)
            }
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(startIP.isEmpty || endIP.isEmpty)
        }
    }

    private var buttonLabel: String {
        switch bridge.scanState {
        case "scanning", "starting": return "Stop"
        case "stopping": return "Kill"
        default: return "Start"
        }
    }

    private var buttonIcon: String {
        switch bridge.scanState {
        case "scanning", "starting": return "stop.fill"
        case "stopping": return "xmark.circle.fill"
        default: return "play.fill"
        }
    }

    private func startScan() {
        guard bridge.scanState == "idle" || bridge.scanState == "unknown" else { return }
        bridge.startScan(startIP: startIP, endIP: endIP)
    }
}
