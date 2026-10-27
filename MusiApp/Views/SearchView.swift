import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine
    @State private var showingPlayer = false
    @State private var selectedTrack: MusicTrack?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FIND YOUR NEXT FAVORITE").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(MusiTheme.accent)
                    Text("Search").font(.system(size: 34, weight: .bold, design: .rounded))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(MusiTheme.secondary)
                    TextField("Songs, artists, albums", text: $search.query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search)
                    if !search.query.isEmpty {
                        Button { search.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MusiTheme.secondary) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(15).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))

                if search.query.isEmpty {
                    ContentUnavailableView("Search music", systemImage: "waveform", description: Text("Search the iTunes Store catalog. Results show whether playback is a preview, a local file, or unavailable."))
                        .padding(.top, 26)
                } else if search.isSearching && search.tracks.isEmpty {
                    ProgressView("Searching music…").frame(maxWidth: .infinity).padding(.top, 32)
                } else if !search.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 11) {
                        SectionHeading(title: "Results", trailing: "iTunes Store")
                        Text("Apple previews are short promotional clips. They are not full tracks.")
                            .font(.system(size: 12)).foregroundStyle(MusiTheme.secondary)
                        LazyVStack(spacing: 5) {
                            ForEach(search.tracks) { track in
                                TrackRow(track: track, isFavorite: library.isFavorite(track),
                                         play: { player.play(track, in: search.tracks); showingPlayer = true },
                                         toggleFavorite: { library.toggleFavorite(track) },
                                         addToPlaylist: { selectedTrack = track })
                            }
                        }
                    }
                } else if !search.isSearching {
                    ContentUnavailableView("No matches", systemImage: "music.note", description: Text("Try another song or artist."))
                        .padding(.top, 25)
                }

                ForEach(MusicProviderID.allCases.filter { search.failures[$0] != nil }, id: \.self) { provider in
                    if let error = search.failures[provider] {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(provider == .bhariyaMusic ? "BhariyaMusic" : provider.rawValue) unavailable")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(error).font(.system(size: 11)).foregroundStyle(MusiTheme.secondary)
                            }
                            Spacer()
                        }
                        .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 22)
        }
        .background(MusiTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showingPlayer) { NowPlayingView().presentationDetents([.large]).presentationDragIndicator(.visible) }
        .confirmationDialog("Add to playlist", isPresented: Binding(get: { selectedTrack != nil }, set: { if !$0 { selectedTrack = nil } }), titleVisibility: .visible) {
            ForEach(library.snapshot.playlists) { playlist in
                Button(playlist.name) { if let selectedTrack { library.add(selectedTrack, to: playlist.id) }; selectedTrack = nil }
            }
            if library.snapshot.playlists.isEmpty { Button("Create a playlist in Library", role: .cancel) { selectedTrack = nil } }
        }
    }
}
