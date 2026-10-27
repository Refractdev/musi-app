import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var snapshot = LibrarySnapshot()
    @Published private(set) var isLoaded = false
    @Published private(set) var persistenceError: String?
    @Published var preferences = AppPreferences()
    private let store: LibraryStore
    private var snapshotSaveTask: Task<Void, Never>?
    private var preferencesSaveTask: Task<Void, Never>?

    init(store: LibraryStore = LibraryStore()) {
        self.store = store
        Task {
            self.snapshot = await store.load()
            self.preferences = await store.loadPreferences()
            self.isLoaded = true
        }
    }

    func isFavorite(_ track: MusicTrack) -> Bool {
        snapshot.favorites.contains { $0.id == track.id }
    }

    func toggleFavorite(_ track: MusicTrack) {
        if isFavorite(track) { snapshot.favorites.removeAll { $0.id == track.id } }
        else { snapshot.favorites.insert(track.librarySafeCopy(), at: 0) }
        persist()
    }

    func createPlaylist(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        snapshot.playlists.insert(MusicPlaylist(name: clean), at: 0)
        persist()
    }

    func removePlaylist(_ playlistID: UUID) {
        snapshot.playlists.removeAll { $0.id == playlistID }
        persist()
    }

    func add(_ track: MusicTrack, to playlistID: UUID) {
        guard let index = snapshot.playlists.firstIndex(where: { $0.id == playlistID }),
              !snapshot.playlists[index].tracks.contains(where: { $0.id == track.id }) else { return }
        snapshot.playlists[index].tracks.append(track.librarySafeCopy())
        persist()
    }

    func remove(_ track: MusicTrack, from playlistID: UUID) {
        guard let index = snapshot.playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        snapshot.playlists[index].tracks.removeAll { $0.id == track.id }
        persist()
    }

    func addImportedFile(_ url: URL) async throws {
        let track = try await store.importAudioFile(url)
        if !snapshot.importedTracks.contains(where: { $0.id == track.id }) {
            snapshot.importedTracks.insert(track, at: 0)
            persist()
        }
    }

    func recordPlayed(_ track: MusicTrack) {
        guard snapshot.recentlyPlayed.first?.id != track.id else { return }
        snapshot.recentlyPlayed.removeAll { $0.id == track.id }
        snapshot.recentlyPlayed.insert(track.librarySafeCopy(), at: 0)
        snapshot.recentlyPlayed = Array(snapshot.recentlyPlayed.prefix(50))
        persist()
    }

    func saveQueue(_ tracks: [MusicTrack], currentIndex: Int = 0, currentTrackID: String? = nil) {
        snapshot.queue = tracks.map { $0.librarySafeCopy() }
        snapshot.queueCurrentIndex = currentIndex
        snapshot.queueCurrentTrackID = currentTrackID
        persist()
    }

    func updatePreferences(_ edit: (inout AppPreferences) -> Void) {
        edit(&preferences)
        let value = preferences
        preferencesSaveTask?.cancel()
        preferencesSaveTask = Task { [weak self, store] in
            guard !Task.isCancelled else { return }
            do { try await store.savePreferences(value) }
            catch { self?.persistenceError = error.localizedDescription }
        }
    }

    private func persist() {
        let value = snapshot
        snapshotSaveTask?.cancel()
        snapshotSaveTask = Task { [weak self, store] in
            guard !Task.isCancelled else { return }
            do { try await store.save(value) }
            catch { self?.persistenceError = error.localizedDescription }
        }
    }
}
