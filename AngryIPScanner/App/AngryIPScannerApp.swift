import SwiftUI

@main
struct AngryIPScannerApp: App {
    @State private var bridge = IPScanBridge()
    @State private var showAbout = false
    @State private var showStatistics = false
    @State private var showSelectFetchers = false

    var body: some Scene {
        WindowGroup {
            MainWindowView(bridge: bridge)
                .sheet(isPresented: $showAbout) { AboutView() }
                .sheet(isPresented: $showStatistics) { StatisticsView(stats: bridge.stats) }
                .sheet(isPresented: $showSelectFetchers) { SelectFetchersView(bridge: bridge) }
        }
        .defaultSize(width: 900, height: 500)
        .commands {
            // Replace the default About menu item
            CommandGroup(replacing: .appInfo) {
                Button("About Angry IP Scanner") {
                    showAbout = true
                }
            }

            // Scan menu
            CommandMenu("Scan") {
                Button(bridge.scanState == "scanning" ? "Stop Scanning" : "Start Scanning") {
                    if bridge.scanState == "scanning" || bridge.scanState == "starting" {
                        bridge.stopScan()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(bridge.scanState == "idle")

                Divider()

                Button("Show Statistics") {
                    showStatistics = true
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(bridge.stats.total == 0)
            }

            // Go To menu
            CommandMenu("Go To") {
                Button("Next Alive Host") {
                    // TODO: implement navigation
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Button("Previous Alive Host") {
                    // TODO: implement navigation
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Divider()

                Button("Find...") {
                    // TODO: implement find
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Commands menu
            CommandMenu("Commands") {
                Button("Copy IP") {
                    // TODO: implement from selection
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Copy Details") {
                    // TODO: implement
                }
            }

            // Tools menu
            CommandMenu("Tools") {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Select Fetchers...") {
                    showSelectFetchers = true
                }
            }
        }

        Settings {
            PreferencesView(bridge: bridge)
        }
    }
}
