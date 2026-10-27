import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlaybackEngine
    @EnvironmentObject private var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingQueue = false

    var body: some View {
        NavigationStack {
            Group {
                if let track = player.currentTrack {
                    playerContent(track)
                } else {
                    ContentUnavailableView("Nothing playing", systemImage: "waveform",
                                           description: Text("Choose a playable track from Search or your Library."))
                }
            }
            .background(LinearGradient(colors: [MusiTheme.accent.opacity(0.24), MusiTheme.background, MusiTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button { showingQueue = true } label: { Image(systemName: "text.line.first.and.arrowtriangle.forward") }.accessibilityLabel("Open queue") }
            }
        }
        .sheet(isPresented: $showingQueue) { QueueView().environmentObject(player).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
    }

    private func playerContent(_ track: MusicTrack) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 3)
            ArtworkView(url: track.artworkURL, size: 300)
                .shadow(color: .black.opacity(0.38), radius: 32, y: 18)
                .frame(maxWidth: .infinity)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title).font(.system(size: 23, weight: .bold, design: .rounded)).lineLimit(2)
                    Text(track.artist).font(.system(size: 16)).foregroundStyle(MusiTheme.secondary).lineLimit(1)
                }
                Spacer()
                Button { library.toggleFavorite(track) } label: {
                    Image(systemName: library.isFavorite(track) ? "heart.fill" : "heart")
                        .font(.system(size: 23)).foregroundStyle(library.isFavorite(track) ? MusiTheme.accent : .white)
                }.accessibilityLabel(library.isFavorite(track) ? "Remove from favorites" : "Add to favorites")
            }

            VStack(spacing: 7) {
                Slider(value: Binding(get: {
                    player.duration > 0 ? player.progress / player.duration : 0
                }, set: { player.seek(to: $0) }), in: 0...1)
                HStack {
                    Text(time(player.progress))
                    Spacer()
                    Text(time(player.duration))
                }.font(.system(size: 11, design: .monospaced)).foregroundStyle(MusiTheme.secondary)
            }

            HStack(spacing: 36) {
                Button { player.shuffleEnabled.toggle() } label: { Image(systemName: "shuffle").font(.system(size: 18, weight: .semibold)).foregroundStyle(player.shuffleEnabled ? MusiTheme.accent : MusiTheme.secondary) }
                    .accessibilityLabel(player.shuffleEnabled ? "Turn shuffle off" : "Turn shuffle on")
                Button { player.previous() } label: { Image(systemName: "backward.end.fill").font(.system(size: 23)) }.accessibilityLabel("Previous")
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold)).foregroundStyle(MusiTheme.background)
                        .frame(width: 68, height: 68).background(MusiTheme.accent, in: Circle())
                }.accessibilityLabel(player.state == .playing ? "Pause" : "Play")
                Button { player.next() } label: { Image(systemName: "forward.end.fill").font(.system(size: 23)) }.accessibilityLabel("Next")
                Button { cycleRepeat() } label: {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(player.repeatMode == .off ? MusiTheme.secondary : MusiTheme.accent)
                }.accessibilityLabel("Repeat \(player.repeatMode.rawValue)")
            }
            .buttonStyle(.plain)

            if case .failed(let message) = player.state {
                HStack {
                    Text(message).font(.system(size: 12)).foregroundStyle(.red.opacity(0.9))
                    Spacer()
                    Button("Retry") { player.retry() }.font(.system(size: 12, weight: .bold))
                }
            } else if player.state == .loading || player.state == .buffering {
                ProgressView(player.state == .loading ? "Loading audio…" : "Buffering…")
                    .font(.system(size: 12)).tint(MusiTheme.accent)
            }

            if track.availability == .previewOnly, let storeURL = track.storeURL {
                VStack(spacing: 9) {
                    Text("Preview provided courtesy of iTunes")
                        .font(.system(size: 11)).foregroundStyle(MusiTheme.secondary)
                    Link(destination: storeURL) {
                        Image("ListenOnAppleMusic")
                            .resizable().scaledToFit().frame(width: 180, height: 60)
                    }.accessibilityLabel("Listen on Apple Music")
                }
            } else if track.availability == .localFile {
                Label("Imported audio · available offline", systemImage: "iphone.and.arrow.forward")
                    .font(.system(size: 11)).foregroundStyle(MusiTheme.secondary)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 25).padding(.bottom, 20)
    }

    private func time(_ value: TimeInterval) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(value) / 60, Int(value) % 60)
    }

    private func cycleRepeat() {
        switch player.repeatMode {
        case .off: player.repeatMode = .all
        case .all: player.repeatMode = .one
        case .one: player.repeatMode = .off
        }
    }
}
