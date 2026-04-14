import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            } else {
                Image(systemName: "network")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.green)
            }

            Text("Go Network Scanner")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0-beta1")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Fast native network scanner")
                .font(.body)

            Divider()

            Text("Go core + SwiftUI native app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("MIT Licensed — inspired by Angry IP Scanner")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("github.com/Responsible-User/GoNetworkScanner", destination: URL(string: "https://github.com/Responsible-User/GoNetworkScanner")!)
                .font(.caption)
        }
        .padding(24)
        .frame(width: 320)
    }
}
