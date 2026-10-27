import Foundation

struct ITunesSearchResponse: Decodable, Sendable {
    let resultCount: Int
    let results: [ITunesTrack]
}

struct ITunesTrack: Decodable, Sendable {
    let wrapperType: String?
    let kind: String?
    let trackId: Int?
    let collectionId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: URL?
    let previewUrl: URL?
    let trackViewUrl: URL?
    let collectionViewUrl: URL?
    let trackTimeMillis: Int?
    let isStreamable: Bool?

    func normalized() -> MusicTrack? {
        guard let trackId, let trackName, !trackName.isEmpty, let artistName, !artistName.isEmpty,
              wrapperType == "track", kind == "song" else { return nil }
        let candidateStore = trackViewUrl ?? collectionViewUrl
        let store = candidateStore?.scheme?.lowercased() == "https" ? candidateStore : nil
        let candidatePreview = previewUrl?.scheme?.lowercased() == "https" ? previewUrl : nil
        let preview = store == nil ? nil : candidatePreview
        return MusicTrack(provider: .itunes, providerTrackID: String(trackId),
                          providerCollectionID: collectionId.map { String($0) },
                          title: trackName, artist: artistName,
                          album: collectionName, artworkURL: artworkUrl100,
                          duration: trackTimeMillis.map { Double($0) / 1_000 },
                          previewURL: preview,
                          storeURL: store,
                          sourceURL: nil,
                          availability: preview == nil ? .metadataOnly : .previewOnly,
                          localFileURL: nil)
    }
}

struct ITunesSearchProvider: MusicProvider {
    let id: MusicProviderID = .itunes
    let displayName = "iTunes Store"
    private let session: URLSession
    private let rateLimiter: ITunesRequestRateLimiter
    private let cache: ITunesSearchCache

    init(session: URLSession = .shared,
         rateLimiter: ITunesRequestRateLimiter = ITunesRequestRateLimiter(),
         cache: ITunesSearchCache = ITunesSearchCache()) {
        self.session = session
        self.rateLimiter = rateLimiter
        self.cache = cache
    }

    func search(_ query: String, countryCode: String) async throws -> [MusicTrack] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCountry = countryCode.uppercased()
        let cacheKey = "\(normalizedCountry)|\(cleanQuery.lowercased())"
        if let cached = await cache.value(for: cacheKey) { return cached }
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: cleanQuery),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "country", value: normalizedCountry)
        ]
        guard let url = components.url else { throw ProviderError.invalidResponse }
        try await rateLimiter.wait()
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw ProviderError.unavailable(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ProviderError.httpStatus(http.statusCode) }
        do {
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            let tracks = decoded.results.compactMap { $0.normalized() }
            await cache.store(tracks, for: cacheKey)
            return tracks
        } catch { throw ProviderError.decoding }
    }
}

actor ITunesRequestRateLimiter {
    private var nextRequestAt = Date.distantPast

    func wait() async throws {
        let now = Date()
        let slot = max(now, nextRequestAt)
        nextRequestAt = slot.addingTimeInterval(3.2)
        let delay = slot.timeIntervalSince(now)
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        else { try Task.checkCancellation() }
    }
}

actor ITunesSearchCache {
    private struct Entry {
        let tracks: [MusicTrack]
        let expiresAt: Date
    }
    private var entries: [String: Entry] = [:]
    private let lifetime: TimeInterval = 300

    func value(for key: String) -> [MusicTrack]? {
        guard let entry = entries[key] else { return nil }
        guard entry.expiresAt > Date() else { entries.removeValue(forKey: key); return nil }
        return entry.tracks
    }

    func store(_ tracks: [MusicTrack], for key: String) {
        if entries[key] == nil, entries.count >= 100,
           let oldest = entries.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
            entries.removeValue(forKey: oldest)
        }
        entries[key] = Entry(tracks: tracks, expiresAt: Date().addingTimeInterval(lifetime))
    }
}
