import SwiftUI

struct FavoriteEntry: Codable, Identifiable {
    var id: String { name }
    let name: String
    let feederArgs: String
}

struct SaveFavoriteView: View {
    @Bindable var bridge: IPScanBridge
    let startIP: String
    let endIP: String
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Favorite")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            Text("Range: \(startIP) - \(endIP)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    bridge.saveFavorite(name: name, startIP: startIP, endIP: endIP)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

struct ManageFavoritesView: View {
    @Bindable var bridge: IPScanBridge
    var onLoad: (String, String) -> Void
    @State private var favorites: [FavoriteEntry] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Favorites")
                .font(.title2)
                .fontWeight(.semibold)

            if favorites.isEmpty {
                Text("No saved favorites")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(Array(favorites.enumerated()), id: \.offset) { index, fav in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(fav.name)
                                    .fontWeight(.medium)
                                Text(fav.feederArgs)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Load") {
                                let parts = fav.feederArgs.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                                if parts.count == 2 {
                                    onLoad(parts[0], parts[1])
                                }
                                dismiss()
                            }
                            .buttonStyle(.borderless)
                            Button(role: .destructive) {
                                bridge.deleteFavorite(index: index)
                                favorites = bridge.getFavorites()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(height: 200)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            favorites = bridge.getFavorites()
        }
    }
}
