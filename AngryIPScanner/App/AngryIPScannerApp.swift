import SwiftUI

@main
struct AngryIPScannerApp: App {
    @State private var bridge = IPScanBridge()
    @State private var showAbout = false
    @State private var showStatistics = false
    @State private var showSelectFetchers = false
    @State private var showExportPanel = false

    var body: some Scene {
        WindowGroup {
            MainWindowView(bridge: bridge)
                .sheet(isPresented: $showAbout) { AboutView() }
                .sheet(isPresented: $showStatistics) { StatisticsView(stats: bridge.stats) }
                .sheet(isPresented: $showSelectFetchers) { SelectFetchersView(bridge: bridge) }
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
