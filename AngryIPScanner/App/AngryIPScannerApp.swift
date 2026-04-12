import SwiftUI

@main
struct AngryIPScannerApp: App {
    @State private var bridge = IPScanBridge()

    var body: some Scene {
        WindowGroup {
            MainWindowView(bridge: bridge)
        }
        .defaultSize(width: 800, height: 500)
        .commands {
            ScanCommands(bridge: bridge)
        }
    }
}

struct ScanCommands: Commands {
    let bridge: IPScanBridge

    var body: some Commands {
        CommandMenu("Scan") {
            Button(bridge.scanState == "scanning" ? "Stop" : "Start") {
                if bridge.scanState == "scanning" {
                    bridge.stopScan()
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}
