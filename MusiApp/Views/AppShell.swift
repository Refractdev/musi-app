import SwiftUI

private enum AppTab: String, CaseIterable {
    case home = "Listen Now"
    case search = "Search"
    case library = "Library"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .home: "play.circle.fill"
        case .search: "magnifyingglass"
        case .library: "square.stack.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct AppShell: View {
    @EnvironmentObject private var player: PlaybackEngine
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selectedTab: AppTab = .home
    @State private var showingNowPlaying = false

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .home: HomeView()
                case .search: SearchView()
                case .library: LibraryView()
                case .settings: SettingsView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let track = player.currentTrack {
                    MiniPlayer(track: track, action: { showingNowPlaying = true })
                        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 5)
                }
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Button { selectedTab = tab } label: {
                            VStack(spacing: 5) {
                                Image(systemName: tab.symbol).font(.system(size: 18, weight: .semibold))
                                Text(tab.rawValue).font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(selectedTab == tab ? MusiTheme.accent : MusiTheme.secondary)
                            .frame(maxWidth: .infinity).contentShape(Rectangle()).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 3)
            }
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5) }
        }
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: player.queue) { _, value in library.saveQueue(value, currentIndex: player.currentIndex, currentTrackID: player.currentTrack?.id) }
        .onChange(of: player.currentIndex) { _, value in library.saveQueue(player.queue, currentIndex: value, currentTrackID: player.currentTrack?.id) }
        .onChange(of: player.currentTrack) { _, value in
            library.saveQueue(player.queue, currentIndex: player.currentIndex, currentTrackID: value?.id)
        }
        .onChange(of: player.state) { _, value in
            if value == .playing, let track = player.currentTrack { library.recordPlayed(track) }
        }
        .task {
            while !library.isLoaded {
                do { try await Task.sleep(for: .milliseconds(40)) }
                catch { return }
            }
            if player.queue.isEmpty {
                let saved = library.snapshot.queue.filter { $0.playableURL != nil }
                let savedIndex = saved.firstIndex(where: { $0.id == library.snapshot.queueCurrentTrackID }) ?? library.snapshot.queueCurrentIndex
                player.restoreQueue(saved, startAt: savedIndex)
            }
            player.shuffleEnabled = library.preferences.shuffleEnabled
            player.repeatMode = library.preferences.repeatMode
        }
        .onChange(of: player.shuffleEnabled) { _, value in library.updatePreferences { $0.shuffleEnabled = value } }
        .onChange(of: player.repeatMode) { _, value in library.updatePreferences { $0.repeatMode = value } }
        .preferredColorScheme(.dark)
    }
}

private struct MiniPlayer: View {
    @EnvironmentObject private var player: PlaybackEngine
    let track: MusicTrack
    let action: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: action) {
                HStack(spacing: 11) {
                    ArtworkView(url: track.artworkURL, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(track.provider == .itunes ? "iTunes preview" : track.artist)
                            .font(.system(size: 11)).foregroundStyle(MusiTheme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }
            }.buttonStyle(.plain)
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous track")
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.state == .playing || player.state == .buffering ? "pause.fill" : "play.fill")
                    .font(.system(size: 19, weight: .semibold)).frame(width: 38, height: 38)
            }.accessibilityLabel(player.state == .playing || player.state == .buffering ? "Pause" : "Play")
            Button { player.next() } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next track")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            if #available(iOS 26.0, *) {
                shape.fill(.clear).glassEffect(.regular, in: shape)
            } else {
                shape.fill(.regularMaterial)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}
