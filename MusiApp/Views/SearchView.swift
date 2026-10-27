import SwiftUI

private struct SearchCategory: Identifiable {
    let title: String
    let term: String
    let color: Color
    var id: String { title }
}

struct SearchView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine
    @State private var showingPlayer = false
    @State private var selectedTrack: MusicTrack?

    private let categories = [
        SearchCategory(title: "Pop", term: "pop", color: Color(red: 0.76, green: 0.08, blue: 0.19)),
        SearchCategory(title: "Hip-Hop", term: "hip hop", color: Color(red: 0.38, green: 0.12, blue: 0.48)),
        SearchCategory(title: "Rock", term: "rock", color: Color(red: 0.12, green: 0.27, blue: 0.49)),
        SearchCategory(title: "R&B", term: "r&b", color: Color(red: 0.69, green: 0.27, blue: 0.10))
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Search")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.62))
                    TextField("Artists, songs, albums", text: $search.query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search)
                    if !search.query.isEmpty {
                        Button { search.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MusiTheme.secondary) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 12)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                if search.query.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Browse Categories")
                            .font(.system(size: 21, weight: .bold))
                            .tracking(-0.3)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                            ForEach(categories) { category in
                                Button { search.query = category.term } label: {
                                    HStack {
                                        Text(category.title).font(.system(size: 16, weight: .bold))
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.78))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, minHeight: 76)
                                    .background {
                                        ZStack(alignment: .trailing) {
                                            LinearGradient(colors: [category.color, category.color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            Image(systemName: "music.note")
                                                .font(.system(size: 50, weight: .ultraLight))
                                                .foregroundStyle(.white.opacity(0.12))
                                                .offset(x: 6, y: 13)
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Searches use the iTunes Store catalog. Preview clips are short promotional audio, not full songs.")
                            .font(.system(size: 12))
                            .foregroundStyle(MusiTheme.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.top, 9)
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
