import SwiftUI

enum FeederMode: String, CaseIterable {
    case range = "IP Range"
    case cidr = "CIDR"
}

struct FeederAreaView: View {
    @Bindable var bridge: IPScanBridge
    @Binding var startIP: String
    @Binding var endIP: String

    @State private var mode: FeederMode = .range
    @State private var cidrIP: String = ""
    @State private var cidrPrefix: Int = 24

    var body: some View {
        HStack(spacing: 12) {
            // Mode picker
            Picker("", selection: $mode) {
                ForEach(FeederMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            // Input fields
            switch mode {
            case .range:
                HStack(spacing: 8) {
                    TextField("Start IP", text: $startIP)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit { startScan() }

                    Text("to")
                        .foregroundStyle(.secondary)

                    TextField("End IP", text: $endIP)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit { startScan() }
                }

            case .cidr:
                HStack(spacing: 8) {
                    TextField("IP Address", text: $cidrIP)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit { applyCIDR(); startScan() }

                    Text("/")
                        .foregroundStyle(.secondary)

                    Picker("", selection: $cidrPrefix) {
                        ForEach([8, 16, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32], id: \.self) { bits in
                            Text("/\(bits)").tag(bits)
                        }
                    }
                    .frame(width: 70)
                    .onChange(of: cidrPrefix) { _, _ in applyCIDR() }
                }
            }

            Spacer()

            // Start/Stop button
            Button(action: {
                if bridge.scanState == "scanning" || bridge.scanState == "starting" {
                    bridge.stopScan()
                } else {
                    if mode == .cidr { applyCIDR() }
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
            .disabled(!canStart && !isScanning)
        }
    }

    private var isScanning: Bool {
        bridge.scanState == "scanning" || bridge.scanState == "starting" || bridge.scanState == "stopping"
    }

    private var canStart: Bool {
        !startIP.isEmpty && !endIP.isEmpty
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
        guard !isScanning && canStart else { return }
        bridge.startScan(startIP: startIP, endIP: endIP)
    }

    private func applyCIDR() {
        guard let ip = parseIPv4(cidrIP) else { return }

        // Calculate start and end from CIDR
        let maskBits = UInt32(cidrPrefix)
        let mask: UInt32 = maskBits == 0 ? 0 : ~((1 << (32 - maskBits)) - 1)
        let ipNum = ipToUInt32(ip)

        let networkStart = ipNum & mask
        let networkEnd = networkStart | ~mask

        // Use .1 as start (skip network address) and .254-style as end (skip broadcast)
        let usableStart = networkStart + 1
        let usableEnd = networkEnd - 1

        startIP = uint32ToIP(usableStart > networkEnd ? networkStart : usableStart)
        endIP = uint32ToIP(usableEnd < networkStart ? networkEnd : usableEnd)
    }

    private func parseIPv4(_ s: String) -> [UInt8]? {
        let parts = s.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var bytes = [UInt8]()
        for p in parts {
            guard let b = UInt8(p) else { return nil }
            bytes.append(b)
        }
        return bytes
    }

    private func ipToUInt32(_ bytes: [UInt8]) -> UInt32 {
        UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    private func uint32ToIP(_ n: UInt32) -> String {
        "\(n >> 24 & 0xFF).\(n >> 16 & 0xFF).\(n >> 8 & 0xFF).\(n & 0xFF)"
    }
}
