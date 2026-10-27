import SwiftUI

enum MusiTheme {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.065)
    static let surface = Color(red: 0.085, green: 0.10, blue: 0.13)
    static let accent = Color(red: 0.70, green: 0.92, blue: 0.66)
    static let secondary = Color.white.opacity(0.58)
}

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 100 ? 24 : 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [MusiTheme.surface, MusiTheme.accent.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "waveform").font(.system(size: size * 0.32, weight: .medium)).foregroundStyle(MusiTheme.accent)
        }
    }
}

struct SectionHeading: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
            Spacer()
            if let trailing { Text(trailing).font(.caption.weight(.semibold)).foregroundStyle(MusiTheme.secondary) }
        }
    }
}

struct AvailabilityBadge: View {
    let availability: PlaybackAvailability
    var label: String {
        switch availability {
        case .fullTrack: "Full track"
        case .previewOnly: "Preview"
        case .localFile: "Imported"
        case .metadataOnly: "Info only"
        }
    }
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(availability == .metadataOnly ? MusiTheme.secondary : MusiTheme.accent)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.white.opacity(0.07), in: Capsule())
    }
}

struct TrackRow: View {
    let track: MusicTrack
    var isFavorite: Bool
    var play: () -> Void
    var toggleFavorite: () -> Void
    var addToPlaylist: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 13) {
            Button(action: play) { ArtworkView(url: track.artworkURL) }
                .buttonStyle(.plain).disabled(track.playableURL == nil)
                .accessibilityLabel(track.playableURL == nil ? "No playable audio for \(track.title)" : "Play \(track.title)")
            Button(action: play) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.system(size: 15, weight: .semibold)).lineLimit(1).foregroundStyle(.white)
                    Text("\(track.artist) · \(track.album ?? track.provider.rawValue.capitalized)")
                        .font(.system(size: 12)).lineLimit(1).foregroundStyle(MusiTheme.secondary)
                    AvailabilityBadge(availability: track.availability)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).disabled(track.playableURL == nil)
            if let store = track.storeURL, track.provider == .itunes {
                Link(destination: store) {
                    Image(systemName: "arrow.up.right.square").font(.system(size: 16, weight: .medium))
                        .foregroundStyle(MusiTheme.secondary)
                }.accessibilityLabel("Open \(track.title) in the iTunes Store")
            }
            Menu {
                Button(isFavorite ? "Remove Favorite" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart", action: toggleFavorite)
                if let addToPlaylist { Button("Add to Playlist", systemImage: "text.badge.plus", action: addToPlaylist) }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "ellipsis")
                    .foregroundStyle(isFavorite ? MusiTheme.accent : MusiTheme.secondary)
                    .frame(width: 34, height: 40)
            }
            .accessibilityLabel(isFavorite ? "Favorite options" : "Track options")
        }
        .padding(.vertical, 5)
    }
}
