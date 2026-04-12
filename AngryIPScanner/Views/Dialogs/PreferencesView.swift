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
                Text("Enter ports separated by commas, or ranges with dashes (e.g. 80,443,8080-8090):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $config.scanner.portString)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))
                Toggle("Add requested ports from file feeder", isOn: $config.scanner.useRequestedPorts)
            }
        }
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
