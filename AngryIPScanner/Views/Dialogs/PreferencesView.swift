import SwiftUI

struct PreferencesView: View {
    @Bindable var bridge: IPScanBridge
    @State private var config: ScanConfig?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let config = Binding($config) {
                TabView(selection: $selectedTab) {
                    ScanningPrefsTab(config: config)
                        .tabItem { Label("Scanning", systemImage: "antenna.radiowaves.left.and.right") }
                        .tag(0)
                    PortsPrefsTab(config: config)
                        .tabItem { Label("Ports", systemImage: "network") }
                        .tag(1)
                    DisplayPrefsTab(config: config)
                        .tabItem { Label("Display", systemImage: "eye") }
                        .tag(2)
                }
                .padding()
                .frame(width: 480, height: 380)
                .onDisappear {
                    if let cfg = self.config {
                        bridge.setConfig(cfg)
                    }
                }
            } else {
                ProgressView("Loading...")
                    .frame(width: 480, height: 380)
            }
        }
        .onAppear {
            config = bridge.getConfig()
        }
    }
}

// MARK: - Scanning Tab

struct ScanningPrefsTab: View {
    @Binding var config: ScanConfig

    var body: some View {
        Form {
            Section("Threads") {
                HStack {
                    Text("Max threads:")
                    TextField("", value: $config.scanner.maxThreads, format: .number)
                        .frame(width: 80)
                }
                HStack {
                    Text("Thread delay (ms):")
                    TextField("", value: $config.scanner.threadDelay, format: .number)
                        .frame(width: 80)
                }
            }

            Section("Pinging") {
                Picker("Method:", selection: $config.scanner.selectedPinger) {
                    Text("Combined UDP+TCP").tag("pinger.combined")
                    Text("ICMP").tag("pinger.icmp")
                    Text("TCP").tag("pinger.tcp")
                    Text("UDP").tag("pinger.udp")
                }
                .frame(width: 260)

                HStack {
                    Text("Ping count:")
                    TextField("", value: $config.scanner.pingCount, format: .number)
                        .frame(width: 80)
                }
                HStack {
                    Text("Ping timeout (ms):")
                    TextField("", value: $config.scanner.pingTimeout, format: .number)
                        .frame(width: 80)
                }
                Toggle("Scan dead hosts", isOn: $config.scanner.scanDeadHosts)
            }

            Section("Skipping") {
                Toggle("Skip broadcast addresses", isOn: $config.scanner.skipBroadcastAddresses)
            }
        }
    }
}

// MARK: - Ports Tab

private let commonPortSets: [(name: String, ports: String)] = [
    ("Web (80, 443, 8080, 8443)", "80,443,8080,8443"),
    ("Remote Access (22, 23, 3389, 5900)", "22,23,3389,5900"),
    ("Mail (25, 110, 143, 993, 995)", "25,110,143,993,995"),
    ("Database (3306, 5432, 6379, 27017)", "3306,5432,6379,27017"),
    ("File Sharing (21, 445, 139, 548)", "21,445,139,548"),
    ("DNS + DHCP (53, 67, 68)", "53,67,68"),
]

struct PortsPrefsTab: View {
    @Binding var config: ScanConfig

    var body: some View {
        Form {
            Section("Timing") {
                HStack {
                    Text("Port timeout (ms):")
                    TextField("", value: $config.scanner.portTimeout, format: .number)
                        .frame(width: 80)
                }
                Toggle("Adapt port timeout", isOn: $config.scanner.adaptPortTimeout)
                if config.scanner.adaptPortTimeout {
                    HStack {
                        Text("Min timeout (ms):")
                        TextField("", value: $config.scanner.minPortTimeout, format: .number)
                            .frame(width: 80)
                    }
                }
            }

            Section("Port Selection") {
                Text("Ports to scan (comma-separated, ranges with dashes):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $config.scanner.portString)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))

                HStack {
                    Menu("Add Common Ports") {
                        ForEach(commonPortSets, id: \.name) { preset in
                            Button(preset.name) {
                                addPorts(preset.ports)
                            }
                        }
                        Divider()
                        Button("All Common Ports") {
                            for preset in commonPortSets {
                                addPorts(preset.ports)
                            }
                        }
                    }

                    Button("Reset to Default") {
                        config.scanner.portString = "22,80,443"
                    }
                }

                Toggle("Add requested ports from file feeder", isOn: $config.scanner.useRequestedPorts)
            }
        }
    }

    private func addPorts(_ ports: String) {
        let existing = config.scanner.portString.trimmingCharacters(in: .whitespaces)
        if existing.isEmpty {
            config.scanner.portString = ports
        } else {
            // Merge without duplicates
            var current = parsePortSet(existing)
            let new = parsePortSet(ports)
            current.formUnion(new)
            config.scanner.portString = current.sorted().map(String.init).joined(separator: ",")
        }
    }

    private func parsePortSet(_ s: String) -> Set<Int> {
        var result = Set<Int>()
        for part in s.split(whereSeparator: { ",; \t\n\r".contains($0) }) {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if let dash = trimmed.firstIndex(of: "-"), dash != trimmed.startIndex {
                if let a = Int(trimmed[..<dash]), let b = Int(trimmed[trimmed.index(after: dash)...]),
                   a > 0, b > 0 {
                    for p in a...b { result.insert(p) }
                }
            } else if let p = Int(trimmed), p > 0 {
                result.insert(p)
            }
        }
        return result
    }
}

// MARK: - Display Tab

struct DisplayPrefsTab: View {
    @Binding var config: ScanConfig

    var body: some View {
        Form {
            Section("Labels") {
                HStack {
                    Text("Not available:")
                    TextField("", text: $config.scanner.notAvailableText)
                        .frame(width: 100)
                }
                HStack {
                    Text("Not scanned:")
                    TextField("", text: $config.scanner.notScannedText)
                        .frame(width: 100)
                }
            }
        }
    }
}
