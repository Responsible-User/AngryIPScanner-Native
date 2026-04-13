import SwiftUI

/// Shows all fetcher results for a selected IP with editable comment.
struct DetailsView: View {
    let result: ScanResult
    @Bindable var bridge: IPScanBridge
    @State private var comment: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details for \(result.ip)")
                .font(.title2)
                .fontWeight(.semibold)

            // Fetcher results grid
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ForEach(Array(zip(bridge.availableFetchers, result.values).enumerated()), id: \.offset) { _, pair in
                        GridRow {
                            Text(pair.0.name + ":")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                            Text(pair.1.description)
                                .textSelection(.enabled)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider()

            // Editable comment
            VStack(alignment: .leading, spacing: 4) {
                Text("Comment:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Add a comment for this IP...", text: $comment)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: comment) { _, newValue in
                        bridge.setComment(ip: result.ip, comment: newValue)
                    }
            }

            HStack {
                Spacer()
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 450, height: 400)
        .onAppear {
            comment = bridge.getComment(ip: result.ip)
        }
    }
}
