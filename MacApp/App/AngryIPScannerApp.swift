import SwiftUI

@main
struct AngryIPScannerApp: App {
    @State private var bridge = IPScanBridge()
    @State private var showAbout = false

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
        }
        .defaultSize(width: 900, height: 500)
        .commands {
            // File menu: export
            CommandGroup(after: .newItem) {
                Button("Export Results...") {
                    NotificationCenter.default.post(name: .exportResults, object: nil)
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

            // Edit menu: copy + find
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

                Divider()

                Button("Find...") {
                    NotificationCenter.default.post(name: .showFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Add to existing View menu
            CommandGroup(after: .toolbar) {
                Divider()

                Button("Select Fetchers...") {
                    NotificationCenter.default.post(name: .showSelectFetchers, object: nil)
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
                    NotificationCenter.default.post(name: .showSaveFavorite, object: nil)
                }
                Button("Manage Favorites...") {
                    NotificationCenter.default.post(name: .showManageFavorites, object: nil)
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
            }
        }

        Settings {
            PreferencesView(bridge: bridge)
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let copyIP = Notification.Name("copyIP")
    static let copyAll = Notification.Name("copyAll")
    static let goToNextAlive = Notification.Name("goToNextAlive")
    static let goToPrevAlive = Notification.Name("goToPrevAlive")
    static let showFind = Notification.Name("showFind")
    static let loadFavorite = Notification.Name("loadFavorite")
    static let showSaveFavorite = Notification.Name("showSaveFavorite")
    static let showManageFavorites = Notification.Name("showManageFavorites")
    static let showSelectFetchers = Notification.Name("showSelectFetchers")
    static let exportResults = Notification.Name("exportResults")
}
