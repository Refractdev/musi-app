import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var player: PlaybackEngine
    @EnvironmentObject private var discovery: HomeDiscoveryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header

                if !library.snapshot.recentlyPlayed.isEmpty {
                    recentSection
                }

                discoverySection

                if !library.snapshot.favorites.isEmpty {
                    favoritesSection
                }

                if !library.snapshot.playlists.isEmpty {
                    playlistsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .background(MusiTheme.background.ignoresSafeArea())
        .task { discovery.load() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Listen Now")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.7)
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white.opacity(0.88))
                .accessibilityHidden(true)
        }
        .padding(.top, 8)
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let featured = discovery.shelves.first?.tracks.first {
                featuredCard(featured, tracks: discovery.shelves.first?.tracks ?? [])
            } else if discovery.isLoading {
                loadingCard
            } else if let error = discovery.errorMessage {
                errorCard(error)
            } else {
                welcomeCard
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Browse the catalog")
                        .font(.system(size: 23, weight: .bold))
                        .tracking(-0.4)
                    Spacer()
                    Text("iTunes Store")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MusiTheme.secondary)
                }

                ForEach(discovery.shelves) { shelf in
                    if !shelf.tracks.isEmpty {
                        shelfView(shelf)
                    }
                }

                if discovery.isLoading && discovery.shelves.allSatisfy({ $0.tracks.isEmpty }) {
                    HStack(spacing: 10) {
                        ProgressView().tint(MusiTheme.accent)
                        Text("Loading songs from the iTunes catalog…")
                            .font(.system(size: 13))
                            .foregroundStyle(MusiTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }

                if !discovery.isLoading,
                   discovery.errorMessage != nil,
                   discovery.shelves.allSatisfy({ $0.tracks.isEmpty }) {
                    errorCard(discovery.errorMessage ?? "Music catalog is unavailable.")
                }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MUSIC DISCOVERY")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.75))
            Text("Find something\nyou love.")
                .font(.system(size: 31, weight: .bold))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text("Real songs from the iTunes Store catalog.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .padding(22)
        .background {
            ZStack(alignment: .trailing) {
                LinearGradient(colors: [Color(red: 0.74, green: 0.06, blue: 0.18), Color(red: 0.30, green: 0.02, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note.list")
                    .font(.system(size: 115, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.10))
                    .offset(x: 10, y: 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var loadingCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.04, blue: 0.13), MusiTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 10) {
                Text("MUSIC DISCOVERY").font(.system(size: 10, weight: .bold)).tracking(1.7)
                ProgressView("Loading music…").tint(.white).font(.system(size: 13))
            }
            .foregroundStyle(.white)
            .padding(22)
        }
        .frame(height: 180)
    }

    private func featuredCard(_ track: MusicTrack, tracks: [MusicTrack]) -> some View {
        Button {
            guard track.playableURL != nil else { return }
            player.play(track, in: tracks)
        } label: {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { proxy in
                    ArtworkView(url: track.artworkURL, size: proxy.size.width)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                LinearGradient(colors: [.clear, .black.opacity(0.30), .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 7) {
                    Text("FROM THE ITUNES CATALOG")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.3)
                    Text(track.title)
                        .font(.system(size: 25, weight: .bold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                    HStack(spacing: 7) {
                        Image(systemName: track.playableURL == nil ? "arrow.up.right" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(track.playableURL == nil ? "View in iTunes Store" : "Play preview")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 3)
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if track.availability == .previewOnly {
                    Text("PREVIEW")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(14)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(track.playableURL == nil)
        .accessibilityLabel("Play preview of \(track.title) by \(track.artist)")
    }

    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Music isn’t available right now", systemImage: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(MusiTheme.secondary)
                .lineLimit(3)
            Button("Try again") { discovery.load(force: true) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MusiTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(MusiTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func shelfView(_ shelf: MusicShelf) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(shelf.title)
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(shelf.tracks) { track in
                        Button {
                            guard track.playableURL != nil else { return }
                            player.play(track, in: shelf.tracks)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                ZStack(alignment: .bottomTrailing) {
                                    ArtworkView(url: track.artworkURL, size: 154)
                                    if track.availability == .previewOnly {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(.black.opacity(0.65), in: Circle())
                                            .padding(8)
                                    }
                                }
                                Text(track.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                Text(track.artist)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .foregroundStyle(MusiTheme.secondary)
                            }
                            .frame(width: 154, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(track.playableURL == nil)
                        .accessibilityLabel(track.playableURL == nil ? "\(track.title), not playable" : "Play preview: \(track.title), \(track.artist)")
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Recently Played")
            LazyVStack(spacing: 3) {
                ForEach(library.snapshot.recentlyPlayed) { track in
                    TrackRow(track: track, isFavorite: library.isFavorite(track),
                             play: { player.play(track, in: library.snapshot.recentlyPlayed) },
                             toggleFavorite: { library.toggleFavorite(track) })
                }
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Favorites")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(library.snapshot.favorites.prefix(12)) { track in
                        Button { player.play(track, in: library.snapshot.favorites) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                ArtworkView(url: track.artworkURL, size: 154)
                                Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                Text(track.artist).font(.system(size: 11)).foregroundStyle(MusiTheme.secondary).lineLimit(1)
                            }.frame(width: 154, alignment: .leading)
                        }.buttonStyle(.plain).disabled(track.playableURL == nil)
                    }
                }
            }
        }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Playlists")
            ForEach(library.snapshot.playlists) { playlist in
                Button {
                    guard !playlist.tracks.isEmpty else { return }
                    player.setQueue(playlist.tracks)
                } label: {
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MusiTheme.surface)
                            .overlay(Image(systemName: "music.note.list").foregroundStyle(MusiTheme.accent))
                            .frame(width: 54, height: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.name).font(.system(size: 15, weight: .semibold))
                            Text("\(playlist.tracks.count) songs").font(.system(size: 12)).foregroundStyle(MusiTheme.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 13)).foregroundStyle(MusiTheme.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
