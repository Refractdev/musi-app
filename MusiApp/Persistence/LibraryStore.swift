import Foundation

actor LibraryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MusiApp", isDirectory: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("library.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load() -> LibrarySnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let value = try? decoder.decode(LibrarySnapshot.self, from: data) else { return LibrarySnapshot() }
        return value
    }

    func save(_ snapshot: LibrarySnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func importAudioFile(_ url: URL) throws -> MusicTrack {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MusiApp/Imported", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destination)
        return MusicTrack.localFile(title: url.deletingPathExtension().lastPathComponent, url: destination)
    }

    func loadPreferences() -> AppPreferences {
        guard let data = try? Data(contentsOf: fileURL.deletingLastPathComponent().appendingPathComponent("preferences.json")),
              let value = try? decoder.decode(AppPreferences.self, from: data) else { return AppPreferences() }
        return value
    }

    func savePreferences(_ preferences: AppPreferences) throws {
        let url = fileURL.deletingLastPathComponent().appendingPathComponent("preferences.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(preferences).write(to: url, options: .atomic)
    }
}
