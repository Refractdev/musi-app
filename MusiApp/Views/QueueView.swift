import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: PlaybackEngine

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    ContentUnavailableView("Queue is empty", systemImage: "text.line.first.and.arrowtriangle.forward",
                                           description: Text("Start a track to build your listening queue."))
                } else {
                    List {
                        if let current = player.currentTrack {
                            Section("Now playing") { queueRow(current, current: true) }
                        }
                        Section("Up next") {
                            ForEach(Array(player.queue.dropFirst(min(player.currentIndex + 1, player.queue.count)))) { track in
                                let index = player.queue.firstIndex(where: { $0.id == track.id }) ?? player.currentIndex
                                queueRow(track, current: false) {
                                    player.setQueue(player.queue, startAt: index)
                                }
                            }
                            .onMove(perform: player.moveUpcoming)
                            .onDelete(perform: player.removeUpcoming)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(MusiTheme.background)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { EditButton() }
        }
    }

    private func queueRow(_ track: MusicTrack, current: Bool, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 11) {
            ArtworkView(url: track.artworkURL, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(track.artist).font(.system(size: 12)).foregroundStyle(MusiTheme.secondary).lineLimit(1)
            }
            Spacer()
            if current { Image(systemName: "waveform").foregroundStyle(MusiTheme.accent) }
        }
        .listRowBackground(Color.white.opacity(0.035))
        .contentShape(Rectangle())
        .onTapGesture { action?() }
    }
}
