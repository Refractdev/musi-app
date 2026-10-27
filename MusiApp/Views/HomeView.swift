import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR MUSIC, YOUR WAY").font(.system(size: 10, weight: .bold)).tracking(2.1).foregroundStyle(MusiTheme.accent)
                        Text("Good listening").font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "waveform.circle.fill").font(.system(size: 38)).foregroundStyle(MusiTheme.accent)
                }
                .padding(.top, 14)

                if !library.snapshot.recentlyPlayed.isEmpty {
                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(title: "Recently played")
                        LazyVStack(spacing: 4) {
                            ForEach(library.snapshot.recentlyPlayed) { track in
                                TrackRow(track: track, isFavorite: library.isFavorite(track),
                                         play: { play(track, list: library.snapshot.recentlyPlayed) },
                                         toggleFavorite: { library.toggleFavorite(track) })
                            }
                        }
                    }
                }

                if !library.snapshot.favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(title: "Your favorites")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(library.snapshot.favorites.prefix(12)) { track in
                                    Button { play(track, list: library.snapshot.favorites) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ArtworkView(url: track.artworkURL, size: 142)
                                            Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                            Text(track.artist).font(.system(size: 11)).foregroundStyle(MusiTheme.secondary).lineLimit(1)
                                        }.frame(width: 142, alignment: .leading)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if !library.snapshot.playlists.isEmpty {
                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(title: "Playlists")
                        ForEach(library.snapshot.playlists) { playlist in
                            Button {
                                guard !playlist.tracks.isEmpty else { return }
                                player.setQueue(playlist.tracks)
                            } label: {
                                HStack(spacing: 13) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.07))
                                        Image(systemName: "music.note.list").font(.system(size: 22)).foregroundStyle(MusiTheme.accent)
                                    }.frame(width: 56, height: 56)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.name).font(.system(size: 15, weight: .semibold))
                                        Text("\(playlist.tracks.count) songs").font(.system(size: 12)).foregroundStyle(MusiTheme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill").font(.system(size: 25)).foregroundStyle(MusiTheme.accent)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }

                if library.snapshot.recentlyPlayed.isEmpty && library.snapshot.favorites.isEmpty && library.snapshot.playlists.isEmpty {
                    ContentUnavailableView("Your listening starts here", systemImage: "music.note.list",
                                           description: Text("Search for music, import audio, or create a playlist. No recommendations are fabricated."))
                        .padding(.top, 28)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.15), MusiTheme.background, MusiTheme.background], startPoint: .top, endPoint: .center).ignoresSafeArea())
    }

    private func play(_ track: MusicTrack, list: [MusicTrack]) { player.play(track, in: list) }
}
