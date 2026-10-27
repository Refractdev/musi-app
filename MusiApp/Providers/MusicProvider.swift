import Foundation

protocol MusicProvider: Sendable {
    var id: MusicProviderID { get }
    var displayName: String { get }
    func search(_ query: String, countryCode: String) async throws -> [MusicTrack]
}

enum ProviderError: Error, LocalizedError, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case unavailable(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The music service returned an invalid response."
        case .httpStatus(let status): "The music service returned HTTP \(status)."
        case .unavailable(let reason): reason
        case .decoding: "The music service response could not be read."
        }
    }
}

struct ProviderSearchResult: Sendable {
    let tracks: [MusicTrack]
    let failures: [MusicProviderID: String]
}

private enum ProviderSearchOutcome: Sendable {
    case tracks([MusicTrack])
    case failure(String)
}

enum TrackDeduplicator {
    /// Deduplicates only when provider identity and provider track ID match.
    static func merge(_ tracks: [MusicTrack]) -> [MusicTrack] {
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }
}

struct MusicSearchCoordinator: Sendable {
    let providers: [any MusicProvider]

    func search(_ query: String, countryCode: String) async -> ProviderSearchResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ProviderSearchResult(tracks: [], failures: [:])
        }
        return await withTaskGroup(of: (MusicProviderID, ProviderSearchOutcome).self) { group in
            for provider in providers {
                group.addTask {
                    do { return (provider.id, .tracks(try await provider.search(query, countryCode: countryCode))) }
                    catch { return (provider.id, .failure(error.localizedDescription)) }
                }
            }
            var tracks: [MusicTrack] = []
            var failures: [MusicProviderID: String] = [:]
            for await (providerID, result) in group {
                switch result {
                case .tracks(let items): tracks.append(contentsOf: items)
                case .failure(let message): failures[providerID] = message
                }
            }
            return ProviderSearchResult(tracks: TrackDeduplicator.merge(tracks), failures: failures)
        }
    }
}
