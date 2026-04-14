import SwiftUI

struct ResultTableView: View {
    @Bindable var bridge: IPScanBridge
    @State private var selectedResults: Set<ScanResult.ID> = []
    @State private var sortOrder: [KeyPathComparator<ScanResult>] = [
        .init(\.ip, order: .forward)
    ]
    @State private var detailResult: ScanResult?

    var body: some View {
        Table(of: ScanResult.self, selection: $selectedResults, sortOrder: $sortOrder) {
            TableColumn("IP", value: \.ip) { result in
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(for: result.type))
                        .frame(width: 8, height: 8)
                    Text(result.ip)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .width(min: 120, ideal: 140)

            TableColumn("Ping", value: \.pingSort) { result in
                Text(valueAt(index: 1, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 50, ideal: 70)

            TableColumn("TTL", value: \.ttlSort) { result in
                Text(valueAt(index: 2, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 35, ideal: 50)

            TableColumn("Hostname", value: \.hostnameSort) { result in
                Text(valueAt(index: 3, in: result))
            }
            .width(min: 100, ideal: 180)

            TableColumn("Ports", value: \.portsSort) { result in
                let ports = valueAt(index: 4, in: result)
                Text(ports)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(ports.isEmpty ? "Open TCP ports" : ports)
            }
            .width(min: 80, ideal: 220)

            TableColumn("Filtered", value: \.filteredPortsSort) { result in
                let ports = valueAt(index: 5, in: result)
                Text(ports)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(ports.isEmpty
                          ? "Ports that timed out — likely firewalled or a slow service. Raise port timeout in Preferences if a known-open port keeps appearing here."
                          : "Timed out (firewalled or slow): \(ports)")
            }
            .width(min: 80, ideal: 140)

            TableColumn("MAC Address", value: \.macSort) { result in
                Text(valueAt(index: 6, in: result))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 100, ideal: 140)

            TableColumn("MAC Vendor", value: \.vendorSort) { result in
                Text(valueAt(index: 7, in: result))
            }
            .width(min: 80, ideal: 120)

            TableColumn("Web detect", value: \.webSort) { result in
                Text(valueAt(index: 8, in: result))
            }
            .width(min: 80, ideal: 120)
        } rows: {
            ForEach(sortedResults) { result in
                TableRow(result)
                    .contextMenu {
                        Button("Show Details...") {
                            detailResult = result
                        }

                        Divider()

                        Button("Copy IP") {
                            copyToClipboard(result.ip)
                        }
                        Button("Copy All Columns") {
                            let text = result.values.map(\.description).joined(separator: "\t")
                            copyToClipboard(text)
                        }

                        Divider()

                        Menu("Open") {
                            Button("Web Browser") { bridge.openInBrowser(ip: result.ip) }
                            Button("SSH") { bridge.openSSH(ip: result.ip) }
                            Button("Ping") { bridge.openPing(ip: result.ip) }
                            Button("Traceroute") { bridge.openTraceroute(ip: result.ip) }
                        }

                        Divider()

                        Button("Rescan") {
                            bridge.startScan(startIP: result.ip, endIP: result.ip)
                        }

                        Button("Delete", role: .destructive) {
                            bridge.deleteResult(ip: result.ip)
                        }
                    }
            }
        }
        .sheet(item: $detailResult) { result in
            DetailsView(result: result, bridge: bridge)
        }
        .background {
            // Install a double-click handler on the underlying NSTableView
            NSTableViewDoubleClickInstaller {
                openSelectedDetails()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyIP)) { _ in
            copySelectedIPs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyAll)) { _ in
            copySelectedAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToNextAlive)) { _ in
            goToAlive(forward: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToPrevAlive)) { _ in
            goToAlive(forward: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { notification in
            if let text = notification.userInfo?["text"] as? String {
                findInResults(text: text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectAlive)) { _ in
            selectedResults = Set(sortedResults.filter { $0.type == .alive || $0.type == .withPorts }.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectDead)) { _ in
            selectedResults = Set(sortedResults.filter { $0.type == .dead }.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectWithPorts)) { _ in
            selectedResults = Set(sortedResults.filter { $0.type == .withPorts }.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectInvert)) { _ in
            let allIDs = Set(sortedResults.map(\.id))
            selectedResults = allIDs.subtracting(selectedResults)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportSelection)) { _ in
            exportSelectedRows()
        }
    }

    private func exportSelectedRows() {
        guard !selectedResults.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export Selected Rows"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "scan_selection.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let rows = bridge.filteredResults
                .filter { selectedResults.contains($0.id) }
                .map { r in
                    ([r.ip] + r.values.map(\.description))
                        .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                        .joined(separator: ",")
                }
                .joined(separator: "\n")
            try? rows.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func openSelectedDetails() {
        if let selectedID = selectedResults.first,
           let result = sortedResults.first(where: { $0.id == selectedID }) {
            detailResult = result
        }
    }

    private var sortedResults: [ScanResult] {
        bridge.filteredResults.sorted(using: sortOrder)
    }

    private func valueAt(index: Int, in result: ScanResult) -> String {
        guard index < result.values.count else { return "" }
        return result.values[index].description
    }

    private func statusColor(for type: ScanResult.ResultType) -> Color {
        switch type {
        case .alive: return .green
        case .withPorts: return .blue
        case .dead: return .red
        case .unknown: return .gray
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copySelectedIPs() {
        let ips = bridge.filteredResults
            .filter { selectedResults.contains($0.id) }
            .map(\.ip)
            .joined(separator: "\n")
        if !ips.isEmpty { copyToClipboard(ips) }
    }

    private func copySelectedAll() {
        let lines = bridge.filteredResults
            .filter { selectedResults.contains($0.id) }
            .map { $0.values.map(\.description).joined(separator: "\t") }
            .joined(separator: "\n")
        if !lines.isEmpty { copyToClipboard(lines) }
    }

    private func goToAlive(forward: Bool) {
        let results = sortedResults
        guard !results.isEmpty else { return }

        // Find current position
        let currentIndex: Int
        if let selectedID = selectedResults.first,
           let idx = results.firstIndex(where: { $0.id == selectedID }) {
            currentIndex = idx
        } else {
            currentIndex = forward ? -1 : results.count
        }

        // Search for next/previous alive
        var targetIndex: Int?
        if forward {
            for i in (currentIndex + 1)..<results.count {
                if results[i].type == .alive || results[i].type == .withPorts {
                    targetIndex = i; break
                }
            }
            if targetIndex == nil {
                for i in 0..<min(currentIndex + 1, results.count) {
                    if results[i].type == .alive || results[i].type == .withPorts {
                        targetIndex = i; break
                    }
                }
            }
        } else {
            for i in stride(from: currentIndex - 1, through: 0, by: -1) {
                if results[i].type == .alive || results[i].type == .withPorts {
                    targetIndex = i; break
                }
            }
            if targetIndex == nil {
                for i in stride(from: results.count - 1, through: max(currentIndex, 0), by: -1) {
                    if results[i].type == .alive || results[i].type == .withPorts {
                        targetIndex = i; break
                    }
                }
            }
        }

        if let idx = targetIndex {
            selectedResults = [results[idx].id]
            scrollNSTableView(to: idx)
        }
    }

    /// Finds the underlying NSTableView in the view hierarchy and scrolls to the given row.
    private func scrollNSTableView(to row: Int) {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow else { return }
            if let tableView = Self.findNSTableView(in: window.contentView) {
                tableView.scrollRowToVisible(row)
            }
        }
    }

    static func findNSTableView(in view: NSView?) -> NSTableView? {
        guard let view else { return nil }
        if let table = view as? NSTableView {
            return table
        }
        for subview in view.subviews {
            if let found = findNSTableView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func findInResults(text: String) {
        let results = sortedResults
        let search = text.lowercased()
        guard !search.isEmpty, !results.isEmpty else { return }

        // Start from current selection or beginning
        let startIdx: Int
        if let selectedID = selectedResults.first,
           let idx = results.firstIndex(where: { $0.id == selectedID }) {
            startIdx = idx + 1
        } else {
            startIdx = 0
        }

        // Search forward with wrap
        for offset in 0..<results.count {
            let i = (startIdx + offset) % results.count
            let row = results[i]
            let matches = row.values.contains { $0.description.lowercased().contains(search) }
                || row.ip.lowercased().contains(search)
            if matches {
                selectedResults = [row.id]
                scrollNSTableView(to: i)
                return
            }
        }
    }
}

// MARK: - Sortable key paths for all columns

extension ScanResult {
    var pingSort: String { valueAt(1) }
    var ttlSort: String { valueAt(2) }
    var hostnameSort: String { valueAt(3) }
    var portsSort: String { valueAt(4) }
    var filteredPortsSort: String { valueAt(5) }
    var macSort: String { valueAt(6) }
    var vendorSort: String { valueAt(7) }
    var webSort: String { valueAt(8) }

    private func valueAt(_ index: Int) -> String {
        guard index < values.count else { return "" }
        return values[index].description
    }
}

// MARK: - NSTableView double-click installer

/// Invisible NSView that finds the parent NSTableView and installs a double-click action.
struct NSTableViewDoubleClickInstaller: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let tableView = ResultTableView.findNSTableView(in: view.window?.contentView) else { return }
            tableView.target = context.coordinator
            tableView.doubleAction = #selector(Coordinator.onDoubleClick)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }

        @objc func onDoubleClick() {
            action()
        }
    }
}
