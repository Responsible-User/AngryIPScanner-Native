import SwiftUI

struct MainWindowView: View {
    @Bindable var bridge: IPScanBridge
    @State private var startIP: String = ""
    @State private var endIP: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Feeder area + controls
            FeederAreaView(
                bridge: bridge,
                startIP: $startIP,
                endIP: $endIP
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Results table
            ResultTableView(bridge: bridge)

            Divider()

            // Status bar
            StatusBarView(bridge: bridge)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            autoDetectLocalRange()
        }
        .navigationTitle(windowTitle)
    }

    private var windowTitle: String {
        if bridge.scanState == "scanning", let p = bridge.progress {
            return String(format: "%.0f%% - Angry IP Scanner", p.percent)
        }
        return "Angry IP Scanner"
    }

    private func autoDetectLocalRange() {
        // Try to detect the local network range
        // For now, use a sensible default
        if startIP.isEmpty {
            startIP = "192.168.1.1"
            endIP = "192.168.1.255"

            // Try to get actual local interface
            if let iface = getLocalIPv4() {
                let parts = iface.split(separator: ".")
                if parts.count == 4 {
                    startIP = "\(parts[0]).\(parts[1]).\(parts[2]).1"
                    endIP = "\(parts[0]).\(parts[1]).\(parts[2]).255"
                }
            }
        }
    }

    private func getLocalIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len),
                          &hostname, socklen_t(hostname.count),
                          nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                if !ip.hasPrefix("127.") {
                    return ip
                }
            }
        }
        return nil
    }
}
