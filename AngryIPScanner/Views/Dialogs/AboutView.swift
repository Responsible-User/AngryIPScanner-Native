import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Angry IP Scanner")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 4.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Fast and friendly network scanner")
                .font(.body)

            Divider()

            Text("Go core + SwiftUI native app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Licensed under GPLv2")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("angryip.org", destination: URL(string: "https://angryip.org")!)
                .font(.caption)
        }
        .padding(24)
        .frame(width: 320)
    }
}
