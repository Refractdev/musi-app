import Foundation

enum MusicProviderID: String, Codable, CaseIterable, Sendable {
    case itunes
    case bhariyaMusic
    case local
}

enum PlaybackAvailability: String, Codable, Sendable {
    case fullTrack
    case previewOnly
    case localFile
    case metadataOnly
}

struct MusicTrack: Identifiable, Codable, Hashable, Sendable {
    var id: String { "\(provider.rawValue):\(providerTrackID)" }

    let provider: MusicProviderID
    let providerTrackID: String
    var providerCollectionID: String? = nil
    let title: String
    let artist: String
    let album: String?
    let artworkURL: URL?
    let duration: TimeInterval?
    let previewURL: URL?
    let storeURL: URL?
    let sourceURL: URL?
    let availability: PlaybackAvailability
    let localFileURL: URL?

    static func localFile(title: String, url: URL) -> MusicTrack {
        MusicTrack(provider: .local, providerTrackID: url.lastPathComponent,
                   title: title, artist: "Imported audio", album: nil,
                   artworkURL: nil, duration: nil, previewURL: nil,
                   storeURL: nil, sourceURL: url, availability: .localFile,
                   localFileURL: url)
    }

    /// Apple preview audio URLs must never be persisted with a saved item.
    func librarySafeCopy() -> MusicTrack {
        guard provider == .itunes else { return self }
        return MusicTrack(provider: provider, providerTrackID: providerTrackID,
                          providerCollectionID: providerCollectionID,
                          title: title, artist: artist, album: album,
                          artworkURL: artworkURL, duration: duration,
                          previewURL: nil, storeURL: storeURL, sourceURL: storeURL,
                          availability: .metadataOnly, localFileURL: nil)
    }

    var playableURL: URL? {
        switch availability {
        case .fullTrack: sourceURL
        case .previewOnly: previewURL
        case .localFile: localFileURL
        case .metadataOnly: nil
        }
    }
}

struct MusicPlaylist: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var tracks: [MusicTrack]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, tracks: [MusicTrack] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdAt = createdAt
    }
}

struct LibrarySnapshot: Codable, Sendable {
    var favorites: [MusicTrack] = []
    var playlists: [MusicPlaylist] = []
    var recentlyPlayed: [MusicTrack] = []
    var importedTracks: [MusicTrack] = []
    var queue: [MusicTrack] = []
    var queueCurrentIndex = 0
    var queueCurrentTrackID: String?
}

struct AppPreferences: Codable, Sendable {
    static var defaultCountryCode: String {
        let value = Locale.current.region?.identifier.uppercased() ?? ""
        return value.count == 2 ? value : "US"
    }
    var countryCode = AppPreferences.defaultCountryCode
    var shuffleEnabled = false
    var repeatMode: RepeatMode = .off
}

enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off, all, one
}
