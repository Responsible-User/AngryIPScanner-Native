import SwiftUI

@main
struct GoNetworkScannerApp: App {
    @State private var showAbout = false

    init() {
        // Force the tab bar to always be visible, even with only one window
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    var body: some Scene {
        WindowGroup {
            IndependentScanWindow()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("OK") { showAbout = false }
                            }
                        }
                }
                .background(WindowTabConfigurator())
        }
        .defaultSize(width: 900, height: 500)
        .commands {
            // File menu: export
            CommandGroup(after: .newItem) {
                Button("Export Results...") {
                    NotificationCenter.default.post(name: .exportResults, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            // About (app menu)
            CommandGroup(replacing: .appInfo) {
                Button("About Go Network Scanner") {
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

                Button("Show All Hosts") {
                    NotificationCenter.default.post(name: .setFilterAll, object: nil)
                }
                Button("Show Alive Only") {
                    NotificationCenter.default.post(name: .setFilterAlive, object: nil)
                }
                Button("Show With Ports Only") {
                    NotificationCenter.default.post(name: .setFilterWithPorts, object: nil)
                }
            }

            // Scan menu
            CommandMenu("Scan") {
                Button("Show Statistics...") {
                    NotificationCenter.default.post(name: .showStatistics, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Menu("Select") {
                    Button("Select Alive") {
                        NotificationCenter.default.post(name: .selectAlive, object: nil)
                    }
                    Button("Select Dead") {
                        NotificationCenter.default.post(name: .selectDead, object: nil)
                    }
                    Button("Select With Ports") {
                        NotificationCenter.default.post(name: .selectWithPorts, object: nil)
                    }
                    Divider()
                    Button("Invert Selection") {
                        NotificationCenter.default.post(name: .selectInvert, object: nil)
                    }
                    .keyboardShortcut("i", modifiers: .command)
                }

                Button("Export Selection...") {
                    NotificationCenter.default.post(name: .exportSelection, object: nil)
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
            PreferencesView(bridge: IPScanBridge())
        }
    }
}

/// Each window gets its own independent IPScanBridge instance.
struct IndependentScanWindow: View {
    @State private var bridge = IPScanBridge()

    var body: some View {
        MainWindowView(bridge: bridge)
            .onReceive(NotificationCenter.default.publisher(for: .setFilterAll)) { _ in
                bridge.displayFilter = .all
            }
            .onReceive(NotificationCenter.default.publisher(for: .setFilterAlive)) { _ in
                bridge.displayFilter = .alive
            }
            .onReceive(NotificationCenter.default.publisher(for: .setFilterWithPorts)) { _ in
                bridge.displayFilter = .withPorts
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
    static let setFilterAll = Notification.Name("setFilterAll")
    static let setFilterAlive = Notification.Name("setFilterAlive")
    static let setFilterWithPorts = Notification.Name("setFilterWithPorts")
    static let showStatistics = Notification.Name("showStatistics")
    static let selectAlive = Notification.Name("selectAlive")
    static let selectDead = Notification.Name("selectDead")
    static let selectWithPorts = Notification.Name("selectWithPorts")
    static let selectInvert = Notification.Name("selectInvert")
    static let exportSelection = Notification.Name("exportSelection")
}

/// Forces the NSWindow tab bar to always be visible.
struct WindowTabConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.tabbingMode = .preferred
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
