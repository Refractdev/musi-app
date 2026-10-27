import Foundation
import XCTest
@testable import MusiApp

final class MusicProviderTests: XCTestCase {
    func testITunesResponseDecodesAndNormalizesPreviewTrack() throws {
        let data = Data(#"{"resultCount":1,"results":[{"wrapperType":"track","kind":"song","trackId":123,"collectionId":45,"trackName":"Test Song","artistName":"Test Artist","collectionName":"Test Album","artworkUrl100":"https://example.com/art.jpg","previewUrl":"https://example.com/preview.m4a","trackViewUrl":"https://music.apple.com/song/123","trackTimeMillis":200000,"isStreamable":true}]}"#.utf8)
        let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        let track = try XCTUnwrap(response.results.first?.normalized())
        XCTAssertEqual(response.resultCount, 1)
        XCTAssertEqual(track.provider, .itunes)
        XCTAssertEqual(track.providerTrackID, "123")
        XCTAssertEqual(track.providerCollectionID, "45")
        XCTAssertEqual(track.title, "Test Song")
        XCTAssertEqual(track.duration, 200)
        XCTAssertEqual(track.availability, .previewOnly)
        XCTAssertEqual(track.previewURL?.absoluteString, "https://example.com/preview.m4a")
        XCTAssertNil(track.sourceURL)
    }

    func testITunesTrackWithoutPreviewIsMetadataOnly() throws {
        let json = #"{"wrapperType":"track","kind":"song","trackId":7,"trackName":"Unstreamable","artistName":"Artist"}"#
        let result = try JSONDecoder().decode(ITunesTrack.self, from: Data(json.utf8)).normalized()
        XCTAssertEqual(result?.availability, .metadataOnly)
        XCTAssertNil(result?.playableURL)
    }

    func testMalformedITunesPayloadThrows() {
        XCTAssertThrowsError(try JSONDecoder().decode(ITunesSearchResponse.self, from: Data("{".utf8)))
    }

    func testDeduplicatorUsesProviderIdentifiersNotTitles() {
        let first = MusicTrack(provider: .itunes, providerTrackID: "1", title: "Same", artist: "Artist", album: nil, artworkURL: nil, duration: nil, previewURL: nil, storeURL: nil, sourceURL: nil, availability: .metadataOnly, localFileURL: nil)
        let duplicate = first
        let otherProvider = MusicTrack(provider: .bhariyaMusic, providerTrackID: "2", title: "Same", artist: "Artist", album: nil, artworkURL: nil, duration: nil, previewURL: nil, storeURL: nil, sourceURL: nil, availability: .metadataOnly, localFileURL: nil)
        XCTAssertEqual(TrackDeduplicator.merge([first, duplicate, otherProvider]).map(\.id), [first.id, otherProvider.id])
    }

    func testConcurrentSearchKeepsSuccessfulResultsWhenProviderFails() async {
        let availableTrack = MusicTrack(provider: .itunes, providerTrackID: "8", title: "Available", artist: "Artist", album: nil, artworkURL: nil, duration: nil, previewURL: nil, storeURL: nil, sourceURL: nil, availability: .metadataOnly, localFileURL: nil)
        let coordinator = MusicSearchCoordinator(providers: [
            StubProvider(id: .itunes, tracks: [availableTrack]),
            StubProvider(id: .bhariyaMusic, tracks: [], fails: true)
        ])
        let result = await coordinator.search("song", countryCode: "US")
        XCTAssertEqual(result.tracks.map(\.id), [availableTrack.id])
        XCTAssertNotNil(result.failures[.bhariyaMusic])
        XCTAssertNil(result.failures[.itunes])
    }

    func testEmptySearchDoesNotCallProviders() async {
        let coordinator = MusicSearchCoordinator(providers: [StubProvider(id: .itunes, tracks: [], fails: true)])
        let result = await coordinator.search("  ", countryCode: "US")
        XCTAssertTrue(result.tracks.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testITunesRequestUsesEscapedQueryParametersAndDecodesResponse() async throws {
        let provider = makeITunesProvider { request in
            let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "term" })?.value, "Daft Punk & Friends")
            XCTAssertEqual(query?.first(where: { $0.name == "country" })?.value, "PT")
            XCTAssertEqual(query?.first(where: { $0.name == "entity" })?.value, "song")
            return (try self.httpResponse(for: request, status: 200), Data(#"{"resultCount":0,"results":[]}"#.utf8))
        }
        let tracks = try await provider.search("Daft Punk & Friends", countryCode: "pt")
        XCTAssertTrue(tracks.isEmpty)
    }

    func testITunesHTTPErrorIsReported() async {
        let provider = makeITunesProvider { request in
            (try self.httpResponse(for: request, status: 503), Data())
        }
        do {
            _ = try await provider.search("song", countryCode: "US")
            XCTFail("Expected HTTP error")
        } catch let error as ProviderError {
            guard case .httpStatus(503) = error else { return XCTFail("Expected HTTP 503, received \(error)") }
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testITunesMalformedResponseIsReported() async {
        let provider = makeITunesProvider { request in
            (try self.httpResponse(for: request, status: 200), Data("not json".utf8))
        }
        do {
            _ = try await provider.search("song", countryCode: "US")
            XCTFail("Expected decoding error")
        } catch let error as ProviderError {
            guard case .decoding = error else { return XCTFail("Expected decoding error") }
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testBhariyaJSONResponseIsNotMappedToUnverifiedTrackFields() async {
        StubURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.hasSuffix("/prepare/hello") == true)
            return (try self.httpResponse(for: request, status: 200), Data(#"{"id":"unknown-schema"}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let provider = BhariyaMusicProvider(session: URLSession(configuration: configuration))
        do {
            _ = try await provider.search("hello", countryCode: "US")
            XCTFail("An unknown response schema must remain unavailable")
        } catch let error as ProviderError {
            guard case .unavailable(let reason) = error else { return XCTFail("Expected unavailable error") }
            XCTAssertTrue(reason.contains("schema"))
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testITunesOfflineAndTimeoutErrorsAreReported() async {
        for failure in [URLError(.notConnectedToInternet), URLError(.timedOut)] {
            let provider = makeITunesProvider { _ in throw failure }
            do {
                _ = try await provider.search("song", countryCode: "US")
                XCTFail("Expected network failure")
            } catch let error as ProviderError {
                guard case .unavailable = error else { return XCTFail("Expected unavailable error") }
            } catch { XCTFail("Unexpected error: \(error)") }
        }
    }

    private func makeITunesProvider(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> ITunesSearchProvider {
        StubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ITunesSearchProvider(session: session,
                                    rateLimiter: ITunesRequestRateLimiter(),
                                    cache: ITunesSearchCache())
    }

    private func httpResponse(for request: URLRequest, status: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status,
                                      httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]))
    }
}

private struct StubProvider: MusicProvider {
    let id: MusicProviderID
    let tracks: [MusicTrack]
    var fails = false
    var displayName: String { id.rawValue }
    func search(_ query: String, countryCode: String) async throws -> [MusicTrack] {
        if fails { throw ProviderError.unavailable("stub failure") }
        return tracks
    }
}

final class PersistenceAndQueueTests: XCTestCase {
    func testLibrarySnapshotPersistsAndRemovesPreviewURL() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
        let store = LibraryStore(fileURL: file)
        let preview = MusicTrack(provider: .itunes, providerTrackID: "42", title: "Preview", artist: "Artist", album: nil, artworkURL: nil, duration: nil, previewURL: URL(string: "https://example.com/audio.m4a"), storeURL: URL(string: "https://music.apple.com/item"), sourceURL: nil, availability: .previewOnly, localFileURL: nil)
        try await store.save(LibrarySnapshot(favorites: [preview.librarySafeCopy()]))
        let loaded = await store.load()
        XCTAssertEqual(loaded.favorites.first?.availability, .metadataOnly)
        XCTAssertNil(loaded.favorites.first?.previewURL)
    }

    func testQueueReorderingAndRemovalPreserveCurrentTrack() {
        let tracks = (1...4).map { index in
            MusicTrack(provider: .local, providerTrackID: "\(index)", title: "\(index)", artist: "Artist", album: nil, artworkURL: nil, duration: nil, previewURL: nil, storeURL: nil, sourceURL: nil, availability: .metadataOnly, localFileURL: nil)
        }
        var queue = QueueState(tracks: tracks, currentIndex: 0)
        queue.moveUpcoming(from: IndexSet(integer: 2), to: 1)
        XCTAssertEqual(queue.tracks.map(\.title), ["1", "2", "4", "3"])
        XCTAssertEqual(queue.currentIndex, 0)
        queue.removeUpcoming(at: IndexSet(integer: 1))
        XCTAssertEqual(queue.tracks.map(\.title), ["1", "2", "3"])
        XCTAssertEqual(queue.upcoming.map(\.title), ["2", "3"])
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
