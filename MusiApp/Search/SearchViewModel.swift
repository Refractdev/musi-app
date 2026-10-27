import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var tracks: [MusicTrack] = []
    @Published private(set) var failures: [MusicProviderID: String] = [:]
    @Published private(set) var isSearching = false
    private let coordinator: MusicSearchCoordinator
    private let countryCode: () -> String
    private var searchTask: Task<Void, Never>?

    init(coordinator: MusicSearchCoordinator, countryCode: @escaping () -> String) {
        self.coordinator = coordinator
        self.countryCode = countryCode
    }

    func retry() { scheduleSearch(immediate: true) }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            tracks = []; failures = [:]; isSearching = false
            return
        }
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                do { try await Task.sleep(for: .milliseconds(350)) }
                catch { return }
            }
            isSearching = true
            let result = await coordinator.search(term, countryCode: countryCode())
            guard !Task.isCancelled else { return }
            tracks = result.tracks
            failures = result.failures
            isSearching = false
        }
    }
}
