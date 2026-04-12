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
        guard startIP.isEmpty else { return }

        guard let info = getLocalInterfaceInfo() else {
            startIP = "192.168.1.1"
            endIP = "192.168.1.255"
            return
        }

        let ip = info.ip
        let prefix = info.prefixLen

        // Calculate CIDR range
        let mask: UInt32 = prefix == 0 ? 0 : ~((1 << (32 - prefix)) - 1)
        let ipNum = ipToUInt32(ip)
        let networkStart = ipNum & mask
        let networkEnd = networkStart | ~mask

        startIP = uint32ToIP(networkStart + 1) // skip network address
        endIP = uint32ToIP(networkEnd - 1)     // skip broadcast
    }

    private struct InterfaceInfo {
        let ip: [UInt8]
        let prefixLen: Int
    }

    private func getLocalInterfaceInfo() -> InterfaceInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            // Get IP
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len),
                             &hostname, socklen_t(hostname.count),
                             nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ipStr = String(cString: hostname)
            if ipStr.hasPrefix("127.") { continue }

            let parts = ipStr.split(separator: ".")
            guard parts.count == 4 else { continue }
            let bytes = parts.compactMap { UInt8($0) }
            guard bytes.count == 4 else { continue }

            // Get netmask to determine prefix length
            if let netmask = ptr.pointee.ifa_netmask {
                let maskAddr = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                let maskInt = UInt32(bigEndian: maskAddr.sin_addr.s_addr)
                let prefix = maskInt.nonzeroBitCount

                return InterfaceInfo(ip: bytes, prefixLen: prefix)
            }

            return InterfaceInfo(ip: bytes, prefixLen: 24)
        }
        return nil
    }

    private func ipToUInt32(_ bytes: [UInt8]) -> UInt32 {
        UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    private func uint32ToIP(_ n: UInt32) -> String {
        "\(n >> 24 & 0xFF).\(n >> 16 & 0xFF).\(n >> 8 & 0xFF).\(n & 0xFF)"
    }
}
