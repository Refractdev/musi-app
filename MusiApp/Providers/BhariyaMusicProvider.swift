import Foundation

/// Isolated adapter for the documented service. No playback contract is enabled until
/// the host, response schema, and rights to the returned audio can be verified.
struct BhariyaMusicProvider: MusicProvider {
    let id: MusicProviderID = .bhariyaMusic
    let displayName = "BhariyaMusic"
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func search(_ query: String, countryCode: String) async throws -> [MusicTrack] {
        var pathCharacters = CharacterSet.urlPathAllowed
        pathCharacters.remove(charactersIn: "/?#%")
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: pathCharacters),
              let url = URL(string: "https://bhindi1.ddns.net/music/api/prepare/\(encodedQuery)") else {
            throw ProviderError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw ProviderError.unavailable("BhariyaMusic could not be reached: \(error.localizedDescription)") }
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ProviderError.httpStatus(http.statusCode) }
        do { _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) }
        catch { throw ProviderError.decoding }
        throw ProviderError.unavailable(
            "BhariyaMusic responded, but its prepare response schema and authorized audio contract have not been verified. Results remain disabled."
        )
    }
}
