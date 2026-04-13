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

            // Fetcher results as a two-column list
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(resultPairs.enumerated()), id: \.offset) { _, pair in
                        HStack(alignment: .top) {
                            Text(pair.label + ":")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                                .frame(width: 120, alignment: .trailing)
                            Text(pair.value)
                                .textSelection(.enabled)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

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
        .frame(width: 500, height: 450)
        .onAppear {
            comment = bridge.getComment(ip: result.ip)
        }
    }

    private var resultPairs: [(label: String, value: String)] {
        let fetchers = bridge.availableFetchers
        var pairs: [(label: String, value: String)] = []
        for i in 0..<max(fetchers.count, result.values.count) {
            let label = i < fetchers.count ? fetchers[i].name : "Column \(i)"
            let value = i < result.values.count ? result.values[i].description : ""
            if !value.isEmpty {
                pairs.append((label: label, value: value))
            }
        }
        return pairs
    }
}
