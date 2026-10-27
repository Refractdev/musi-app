import Combine
import Foundation

struct MusicShelf: Identifiable, Sendable {
    let title: String
    let searchTerm: String
    var tracks: [MusicTrack] = []

    var id: String { searchTerm }
}

@MainActor
final class HomeDiscoveryViewModel: ObservableObject {
    @Published private(set) var shelves = [
        MusicShelf(title: "Pop", searchTerm: "pop"),
        MusicShelf(title: "Hip-Hop", searchTerm: "hip hop"),
        MusicShelf(title: "Rock", searchTerm: "rock")
    ]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let provider: any MusicProvider
    private let countryCode: () -> String
    private var requestTask: Task<Void, Never>?

    init(provider: any MusicProvider, countryCode: @escaping () -> String) {
        self.provider = provider
        self.countryCode = countryCode
    }

    func load(force: Bool = false) {
        guard !isLoading else { return }
        if force {
            shelves = shelves.map { MusicShelf(title: $0.title, searchTerm: $0.searchTerm) }
        } else if shelves.contains(where: { !$0.tracks.isEmpty }) {
            return
        }

        errorMessage = nil
        isLoading = true
        let provider = self.provider
        let country = countryCode()
        let requests = shelves.map { (title: $0.title, term: $0.searchTerm) }

        requestTask = Task { [weak self] in
            await withTaskGroup(of: (String, [MusicTrack], String?).self) { group in
                for request in requests {
                    group.addTask {
                        do {
                            let tracks = try await provider.search(request.term, countryCode: country)
                            return (request.term, Array(tracks.prefix(12)), nil)
                        } catch is CancellationError {
                            return (request.term, [], nil)
                        } catch {
                            return (request.term, [], error.localizedDescription)
                        }
                    }
                }

                for await (term, tracks, error) in group {
                    guard let self, !Task.isCancelled else { continue }
                    if let index = self.shelves.firstIndex(where: { $0.searchTerm == term }) {
                        self.shelves[index].tracks = tracks
                    }
                    if let error, self.errorMessage == nil { self.errorMessage = error }
                }
            }

            guard let self else { return }
            if self.shelves.allSatisfy({ $0.tracks.isEmpty }) && self.errorMessage == nil {
                self.errorMessage = "The iTunes catalog returned no songs for these categories. Try Search instead."
            }
            self.isLoading = false
        }
    }

    deinit { requestTask?.cancel() }
}
