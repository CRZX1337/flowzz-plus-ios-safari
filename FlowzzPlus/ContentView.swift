import SwiftUI

/// Minimal host application for the Safari web extension.
///
/// The host app contains no product logic. It exists because iOS can only
/// deliver a Safari web extension inside an application, and it explains how
/// to switch the extension on in Safari.
struct ContentView: View {
    private let steps: [String] = [
        "Open Settings on your iPhone or iPad.",
        "Go to Safari, then Extensions.",
        "Select flowzz+ and turn it on."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enable the extension")
                            .font(.headline)

                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.footnote.monospacedDigit().weight(.semibold))
                                    .frame(width: 22, height: 22)
                                    .background(Color.accentColor.opacity(0.15), in: Circle())

                                Text(step)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    Text("This build ships a placeholder extension. Replace the contents of the extension's Resources folder with the flowzz+ web extension files before shipping.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("flowzz+")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safari web extension")
                .font(.title2.weight(.semibold))

            Text("A native iOS Safari web extension scaffold for the flowzz+ port.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
