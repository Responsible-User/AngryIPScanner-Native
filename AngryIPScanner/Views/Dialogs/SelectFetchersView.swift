import SwiftUI

struct SelectFetchersView: View {
    @Bindable var bridge: IPScanBridge
    @State private var selectedIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Select Fetchers")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose which columns to display in scan results:")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(bridge.availableFetchers, selection: $selectedIDs) { fetcher in
                Toggle(fetcher.name, isOn: Binding(
                    get: { selectedIDs.contains(fetcher.id) },
                    set: { isOn in
                        if isOn {
                            selectedIDs.insert(fetcher.id)
                        } else {
                            selectedIDs.remove(fetcher.id)
                        }
                    }
                ))
            }
            .frame(height: 250)

            HStack {
                Button("Select All") {
                    selectedIDs = Set(bridge.availableFetchers.map(\.id))
                }
                Button("Select None") {
                    selectedIDs.removeAll()
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("OK") {
                    // Update config with selected fetchers
                    if var config = bridge.getConfig() {
                        config.scanner.selectedFetchers = bridge.availableFetchers
                            .filter { selectedIDs.contains($0.id) }
                            .map(\.id)
                        bridge.setConfig(config)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 350)
        .onAppear {
            // Default: all fetchers selected
            if let config = bridge.getConfig(), let ids = config.scanner.selectedFetchers, !ids.isEmpty {
                selectedIDs = Set(ids)
            } else {
                selectedIDs = Set(bridge.availableFetchers.map(\.id))
            }
        }
    }
}
