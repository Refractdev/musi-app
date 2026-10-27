import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine
    @State private var showingQueue = false

    var body: some View {
        Form {
            Section {
                Picker("Storefront", selection: Binding(get: { library.preferences.countryCode }, set: { value in
                    library.updatePreferences { $0.countryCode = value }
                })) {
                    if !["US", "PT", "GB", "CA", "AU"].contains(library.preferences.countryCode) {
                        Text("System region (\(library.preferences.countryCode))").tag(library.preferences.countryCode)
                    }
                    Text("United States").tag("US")
                    Text("Portugal").tag("PT")
                    Text("United Kingdom").tag("GB")
                    Text("Canada").tag("CA")
                    Text("Australia").tag("AU")
                }
                Toggle("Shuffle", isOn: $player.shuffleEnabled)
                Picker("Repeat", selection: $player.repeatMode) {
                    Text("Off").tag(RepeatMode.off)
                    Text("All tracks").tag(RepeatMode.all)
                    Text("One track").tag(RepeatMode.one)
                }
            } header: { Text("Playback") }

            Section {
                providerRow("iTunes Search API", detail: "Connected · search and promotional previews", symbol: "checkmark.circle.fill", tint: MusiTheme.accent)
                providerRow("BhariyaMusic", detail: "Unavailable · host DNS and audio rights unverified", symbol: "exclamationmark.triangle.fill", tint: .yellow)
            } header: { Text("Music sources") } footer: {
                Text("iTunes previews are short promotional clips, not full tracks. BhariyaMusic audio stays disabled until the endpoint and playback rights can be verified.")
            }

            Section("Your data") {
                if let error = library.persistenceError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                LabeledContent("Favorites", value: "\(library.snapshot.favorites.count)")
                LabeledContent("Playlists", value: "\(library.snapshot.playlists.count)")
                LabeledContent("Imported audio", value: "\(library.snapshot.importedTracks.count)")
                Button { showingQueue = true } label: { Label("View queue", systemImage: "text.line.first.and.arrowtriangle.forward") }
            }

            Section {
                Text("Musi App uses local persistence for your library. Remote music is not downloaded. Imported files are copied into app storage for offline playback.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("About") }
        }
        .scrollContentBackground(.hidden)
        .background(MusiTheme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingQueue) { QueueView().environmentObject(player).presentationDetents([.medium, .large]) }
    }

    private func providerRow(_ title: String, detail: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 3)
    }
}
