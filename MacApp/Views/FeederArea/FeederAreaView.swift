import SwiftUI

enum FeederMode: String, CaseIterable {
    case range = "IP Range"
    case cidr = "CIDR"
    case file = "File"
}

struct FeederAreaView: View {
    @Bindable var bridge: IPScanBridge
    @Binding var startIP: String
    @Binding var endIP: String

    @State private var mode: FeederMode = .range
    @State private var cidrIP: String = ""
    @State private var cidrPrefix: Int = 24
    @State private var didAutoFillCIDR = false
    @State private var filePath: String = ""
    @State private var selectedPinger: String = "pinger.combined"

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
            .onChange(of: mode) { _, newMode in
                if newMode == .cidr && cidrIP.isEmpty {
                    autoFillCIDR()
                }
            }

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

            case .file:
                HStack(spacing: 8) {
                    TextField("File path", text: $filePath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                        .help("Any text file. IPv4, IPv6, hostnames (example.com), and IP:port (192.168.1.1:8080) are extracted automatically.")
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes = [.plainText, .data]
                        panel.message = "Select a text file containing IPs, hostnames, or IP:port entries (one per line, or any format — addresses are extracted by regex)."
                        if panel.runModal() == .OK, let url = panel.url {
                            filePath = url.path
                        }
                    }
                }
            }

            Spacer()

            // Scan type (pinger) dropdown
            Picker("", selection: $selectedPinger) {
                Text("Combined").tag("pinger.combined")
                Text("ICMP").tag("pinger.icmp")
                Text("TCP").tag("pinger.tcp")
                Text("UDP").tag("pinger.udp")
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            .help("Scan type — how hosts are probed for reachability")
            .onChange(of: selectedPinger) { _, newValue in
                if var cfg = bridge.getConfig() {
                    cfg.scanner.selectedPinger = newValue
                    bridge.setConfig(cfg)
                }
            }

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
            .alert("Start New Scan?", isPresented: $showConfirmation) {
                Button("Discard & Scan") {
                    doStartScan()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Previous scan results will be discarded.")
            }
        }
        .onAppear {
            if let cfg = bridge.getConfig() {
                selectedPinger = cfg.scanner.selectedPinger
            }
        }
    }

    private var isScanning: Bool {
        bridge.scanState == "scanning" || bridge.scanState == "starting" || bridge.scanState == "stopping"
    }

    private var canStart: Bool {
        switch mode {
        case .range, .cidr:
            return !startIP.isEmpty && !endIP.isEmpty
        case .file:
            return !filePath.isEmpty
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

    @State private var showConfirmation = false

    private func startScan() {
        guard !isScanning && canStart else { return }
        if !bridge.results.isEmpty {
            showConfirmation = true
        } else {
            doStartScan()
        }
    }

    private func doStartScan() {
        if mode == .cidr { applyCIDR() }
        if mode == .file {
            bridge.startFileScan(filePath: filePath)
        } else {
            bridge.startScan(startIP: startIP, endIP: endIP)
        }
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

    private func autoFillCIDR() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return }
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

            cidrIP = ipStr

            // Get prefix length from netmask
            if let netmask = ptr.pointee.ifa_netmask {
                let maskAddr = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let maskInt = UInt32(bigEndian: maskAddr.sin_addr.s_addr)
                cidrPrefix = maskInt.nonzeroBitCount
            }

            applyCIDR()
            return
        }
    }
}
