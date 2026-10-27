import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine
    @State private var showingImporter = false
    @State private var showingPlaylistPrompt = false
    @State private var playlistName = ""
    @State private var selectedPlaylist: MusicPlaylist?
    @State private var importError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COLLECTED BY YOU").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(MusiTheme.accent)
                    Text("Your Library").font(.system(size: 34, weight: .bold, design: .rounded))
                }.padding(.top, 14)

                HStack(spacing: 11) {
                    LibraryAction(title: "New playlist", symbol: "plus", action: { showingPlaylistPrompt = true })
                    LibraryAction(title: "Import audio", symbol: "square.and.arrow.down", action: { showingImporter = true })
                }

                if !library.snapshot.importedTracks.isEmpty {
                    section("Imported audio", tracks: library.snapshot.importedTracks)
                }
                if !library.snapshot.favorites.isEmpty {
                    section("Favorites", tracks: library.snapshot.favorites)
                }
                if !library.snapshot.recentlyPlayed.isEmpty {
                    section("Recently played", tracks: library.snapshot.recentlyPlayed)
                }
                if !library.snapshot.playlists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Playlists", trailing: "\(library.snapshot.playlists.count)")
                        ForEach(library.snapshot.playlists) { playlist in
                            Button {
                                selectedPlaylist = playlist
                            } label: {
                                HStack(spacing: 13) {
                                    RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.07))
                                        .overlay(Image(systemName: "music.note.list").foregroundStyle(MusiTheme.accent))
                                        .frame(width: 52, height: 52)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.name).font(.system(size: 15, weight: .semibold))
                                        Text("\(playlist.tracks.count) songs").font(.system(size: 12)).foregroundStyle(MusiTheme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.fill").foregroundStyle(MusiTheme.accent)
                                }
                            }.buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", systemImage: "trash", role: .destructive) { library.removePlaylist(playlist.id) }
                                }
                        }
                    }
                }

                if library.snapshot.favorites.isEmpty && library.snapshot.importedTracks.isEmpty && library.snapshot.recentlyPlayed.isEmpty && library.snapshot.playlists.isEmpty {
                    ContentUnavailableView("Your library is ready", systemImage: "square.stack",
                                           description: Text("Save favorites, make playlists, or import audio files for offline listening."))
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 22)
        }
        .background(MusiTheme.background.ignoresSafeArea())
        .alert("New playlist", isPresented: $showingPlaylistPrompt) {
            TextField("Playlist name", text: $playlistName)
            Button("Create") { library.createPlaylist(name: playlistName); playlistName = "" }
            Button("Cancel", role: .cancel) { playlistName = "" }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    Task {
                        do { try await library.addImportedFile(url) }
                        catch { importError = error.localizedDescription }
                    }
                }
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .alert("Couldn’t import audio", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "Please try another audio file.") }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailView(playlistID: playlist.id)
                .environmentObject(library).environmentObject(player)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    private func section(_ title: String, tracks: [MusicTrack]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: title)
            ForEach(tracks) { track in
                TrackRow(track: track, isFavorite: library.isFavorite(track),
                         play: { player.play(track, in: tracks) },
                         toggleFavorite: { library.toggleFavorite(track) })
            }
        }
    }
}

private struct PlaylistDetailView: View {
    let playlistID: UUID
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine
    @Environment(\.dismiss) private var dismiss

    private var playlist: MusicPlaylist? { library.snapshot.playlists.first { $0.id == playlistID } }

    var body: some View {
        NavigationStack {
            Group {
                if let playlist, !playlist.tracks.isEmpty {
                    List {
                        ForEach(playlist.tracks) { track in
                            TrackRow(track: track, isFavorite: library.isFavorite(track),
                                     play: { player.play(track, in: playlist.tracks) },
                                     toggleFavorite: { library.toggleFavorite(track) })
                                .swipeActions(edge: .trailing) {
                                    Button("Remove", systemImage: "minus.circle", role: .destructive) {
                                        library.remove(track, from: playlistID)
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.035))
                        }
                    }.scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView("No songs yet", systemImage: "music.note.list",
                                           description: Text("Add songs to this playlist from Search."))
                }
            }
            .background(MusiTheme.background)
            .navigationTitle(playlist?.name ?? "Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct LibraryAction: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
}
