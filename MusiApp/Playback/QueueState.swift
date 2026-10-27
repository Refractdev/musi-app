import Foundation

struct QueueState: Equatable, Sendable {
    var tracks: [MusicTrack]
    var currentIndex: Int

    var upcoming: [MusicTrack] {
        guard !tracks.isEmpty else { return [] }
        return Array(tracks.dropFirst(min(currentIndex + 1, tracks.count)))
    }

    mutating func moveUpcoming(from offsets: IndexSet, to destination: Int) {
        guard !offsets.isEmpty else { return }
        let boundary = min(max(currentIndex + 1, 0), tracks.count)
        var future = Array(tracks.dropFirst(boundary))
        guard offsets.allSatisfy({ future.indices.contains($0) }) else { return }
        let moving = offsets.sorted().map { future[$0] }
        for index in offsets.sorted(by: >) { future.remove(at: index) }
        let insertion = min(max(destination - offsets.filter { $0 < destination }.count, 0), future.count)
        future.insert(contentsOf: moving, at: insertion)
        tracks = Array(tracks.prefix(boundary)) + future
    }

    mutating func removeUpcoming(at offsets: IndexSet) {
        let boundary = min(max(currentIndex + 1, 0), tracks.count)
        for offset in offsets.sorted(by: >) {
            let index = boundary + offset
            if tracks.indices.contains(index) { tracks.remove(at: index) }
        }
    }
}
