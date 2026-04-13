import SwiftUI

@main
struct AngryIPScannerApp: App {
    @State private var bridge = IPScanBridge()
    @State private var showAbout = false
    @State private var showSelectFetchers = false
    @State private var showSaveFavorite = false
    @State private var showManageFavorites = false

    var body: some Scene {
        WindowGroup {
            MainWindowView(bridge: bridge)
                .sheet(isPresented: $showAbout) {
                    AboutView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("OK") { showAbout = false }
                            }
                        }
                }
                .sheet(isPresented: $showSelectFetchers) { SelectFetchersView(bridge: bridge) }
                .sheet(isPresented: $showSaveFavorite) {
                    SaveFavoriteView(bridge: bridge, startIP: "", endIP: "")
                }
                .sheet(isPresented: $showManageFavorites) {
                    ManageFavoritesView(bridge: bridge) { start, end in
                        NotificationCenter.default.post(name: .loadFavorite, object: nil, userInfo: ["startIP": start, "endIP": end])
                    }
                }
        }
        .defaultSize(width: 900, height: 500)
        .commands {
            // File menu: export
            CommandGroup(after: .newItem) {
                Button("Export Results...") {
                    exportResults()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(bridge.stats.total == 0)
            }

            // About (app menu)
            CommandGroup(replacing: .appInfo) {
                Button("About Angry IP Scanner") {
                    showAbout = true
                }
            }

            // Edit menu: copy actions
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy IP") {
                    NotificationCenter.default.post(name: .copyIP, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Copy All Columns") {
                    NotificationCenter.default.post(name: .copyAll, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }

            // View menu
            CommandMenu("View") {
                Button("Select Fetchers...") {
                    showSelectFetchers = true
                }

                Divider()

                Button {
                    bridge.displayFilter = .all
                } label: {
                    if bridge.displayFilter == .all {
                        Label("Show All Hosts", systemImage: "checkmark")
                    } else {
                        Text("Show All Hosts")
                    }
                }

                Button {
                    bridge.displayFilter = .alive
                } label: {
                    if bridge.displayFilter == .alive {
                        Label("Show Alive Only", systemImage: "checkmark")
                    } else {
                        Text("Show Alive Only")
                    }
                }

                Button {
                    bridge.displayFilter = .withPorts
                } label: {
                    if bridge.displayFilter == .withPorts {
                        Label("Show With Ports Only", systemImage: "checkmark")
                    } else {
                        Text("Show With Ports Only")
                    }
                }
            }

            // Favorites menu
            CommandMenu("Favorites") {
                Button("Save Current Scan...") {
                    showSaveFavorite = true
                }
                Button("Manage Favorites...") {
                    showManageFavorites = true
                }
            }

            // Go To menu
            CommandMenu("Go To") {
                Button("Next Alive Host") {
                    NotificationCenter.default.post(name: .goToNextAlive, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Button("Previous Alive Host") {
                    NotificationCenter.default.post(name: .goToPrevAlive, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Divider()

                Button("Find...") {
                    NotificationCenter.default.post(name: .showFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            PreferencesView(bridge: bridge)
        }
    }

    private func exportResults() {
        let panel = NSSavePanel()
        panel.title = "Export Scan Results"
        panel.allowedContentTypes = [
            .commaSeparatedText,
            .plainText,
            .xml,
        ]
        panel.allowsOtherFileTypes = true
        panel.nameFieldStringValue = "scan_results.csv"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let ext = url.pathExtension.lowercased()
            let format: String
            switch ext {
            case "csv": format = "csv"
            case "txt": format = "txt"
            case "xml": format = "xml"
            case "lst": format = "iplist"
            case "sql": format = "sql"
            default: format = "csv"
            }

            let success = bridge.exportResults(format: format, to: url)
            if !success {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not export results to \(url.lastPathComponent)"
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}

// MARK: - Notification names for menu -> view communication

extension Notification.Name {
    static let copyIP = Notification.Name("copyIP")
    static let copyAll = Notification.Name("copyAll")
    static let goToNextAlive = Notification.Name("goToNextAlive")
    static let goToPrevAlive = Notification.Name("goToPrevAlive")
    static let showFind = Notification.Name("showFind")
    static let loadFavorite = Notification.Name("loadFavorite")
}
