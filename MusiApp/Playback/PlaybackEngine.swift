import AVFoundation
import Combine
import Foundation
import MediaPlayer
import SwiftUI
import UIKit

enum PlaybackState: Equatable {
    case idle
    case loading
    case buffering
    case playing
    case paused
    case failed(String)
}

@MainActor
final class PlaybackEngine: ObservableObject {
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var queue: [MusicTrack] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var progress: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var shuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemObservation: NSKeyValueObservation?
    private var playerObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var remoteCommandsInstalled = false
    private var wasPlayingBeforeInterruption = false
    private var artworkTask: Task<Void, Never>?
    private var nowPlayingArtwork: MPMediaItemArtwork?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        configureAudioSession()
        installObservers()
        installRemoteCommands()
    }

    deinit {
        artworkTask?.cancel()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if remoteCommandsInstalled {
            let center = MPRemoteCommandCenter.shared()
            [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
             center.nextTrackCommand, center.previousTrackCommand].forEach { $0.removeTarget(nil) }
        }
    }

    func play(_ track: MusicTrack, in tracks: [MusicTrack]? = nil) {
        guard track.playableURL != nil else {
            state = .failed("This result is metadata only and has no playable audio.")
            return
        }
        let source = (tracks ?? [track]).filter { $0.playableURL != nil }
        queue = source
        currentIndex = source.firstIndex(where: { $0.id == track.id }) ?? 0
        loadCurrentTrack(autoplay: true)
    }

    func setQueue(_ tracks: [MusicTrack], startAt index: Int = 0) {
        queue = tracks.filter { $0.playableURL != nil }
        guard !queue.isEmpty else { stop(); return }
        currentIndex = min(max(index, 0), queue.count - 1)
        loadCurrentTrack(autoplay: true)
    }

    func restoreQueue(_ tracks: [MusicTrack], startAt index: Int = 0) {
        queue = tracks.filter { $0.playableURL != nil }
        guard !queue.isEmpty else { return }
        currentIndex = min(max(index, 0), queue.count - 1)
        loadCurrentTrack(autoplay: false)
    }

    func togglePlayPause() {
        switch state {
        case .playing, .buffering: player.pause(); state = .paused
        case .paused: player.play(); state = .playing
        case .idle, .loading, .failed: retry()
        }
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        if currentTrack != nil { state = .paused }
        updateNowPlaying()
    }

    func retry() {
        guard currentTrack?.playableURL != nil else { return }
        loadCurrentTrack(autoplay: true)
    }

    func stop() {
        artworkTask?.cancel()
        nowPlayingArtwork = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObservation = nil
        currentTrack = nil
        progress = 0
        duration = 0
        state = .idle
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to fraction: Double) {
        guard duration.isFinite, duration > 0 else { return }
        let seconds = min(max(fraction, 0), 1) * duration
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        if repeatMode == .one { seek(to: 0); player.play(); state = .playing; return }
        if shuffleEnabled, queue.count > 1 {
            var nextIndex = currentIndex
            while nextIndex == currentIndex { nextIndex = Int.random(in: queue.indices) }
            currentIndex = nextIndex
        } else if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else if repeatMode == .all {
            currentIndex = 0
        } else {
            pause(); seek(to: 1); return
        }
        loadCurrentTrack(autoplay: true)
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if progress > 3 { seek(to: 0); return }
        if shuffleEnabled, queue.count > 1 {
            var priorIndex = currentIndex
            while priorIndex == currentIndex { priorIndex = Int.random(in: queue.indices) }
            currentIndex = priorIndex
        } else if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
        } else {
            seek(to: 0); return
        }
        loadCurrentTrack(autoplay: true)
    }

    func moveUpcoming(from source: IndexSet, to destination: Int) {
        var value = QueueState(tracks: queue, currentIndex: currentIndex)
        value.moveUpcoming(from: source, to: destination)
        queue = value.tracks
    }

    func removeUpcoming(at offsets: IndexSet) {
        var value = QueueState(tracks: queue, currentIndex: currentIndex)
        value.removeUpcoming(at: offsets)
        queue = value.tracks
    }

    private func loadCurrentTrack(autoplay: Bool) {
        guard queue.indices.contains(currentIndex) else { stop(); return }
        let track = queue[currentIndex]
        guard let url = track.playableURL else {
            state = .failed("This result has no verified playable audio source.")
            currentTrack = track
            return
        }
        currentTrack = track
        state = .loading
        progress = 0
        duration = track.duration ?? 0
        loadArtwork(for: track)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentTrack?.id == track.id else { return }
                switch item.status {
                case .readyToPlay:
                    let itemDuration = item.duration.seconds
                    if itemDuration.isFinite, itemDuration > 0 { self.duration = itemDuration }
                    if autoplay { self.player.play(); self.state = .playing }
                    else { self.state = .paused }
                    self.updateNowPlaying()
                case .failed:
                    self.state = .failed(item.error?.localizedDescription ?? "Audio could not be played.")
                case .unknown: break
                @unknown default: self.state = .failed("The audio source returned an unknown state.")
                }
            }
        }
        updateNowPlaying()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch { state = .failed("Audio session setup failed: \(error.localizedDescription)") }
    }

    private func installObservers() {
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentTrack != nil else { return }
                switch player.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate: self.state = .buffering
                case .playing: self.state = .playing
                case .paused:
                    if self.state == .playing || self.state == .buffering { self.state = .paused }
                @unknown default: break
                }
                self.updateNowPlaying()
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                                                      queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite { self.progress = seconds }
                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 { self.duration = itemDuration }
                self.updateNowPlaying()
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.next() } }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == .began {
                    self.wasPlayingBeforeInterruption = self.state == .playing
                    self.pause()
                } else if options.contains(.shouldResume), self.wasPlayingBeforeInterruption {
                    self.wasPlayingBeforeInterruption = false
                    try? AVAudioSession.sharedInstance().setActive(true)
                    self.player.play()
                    self.state = .playing
                    self.updateNowPlaying()
                }
            }
        }
    }

    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }; return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }; return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }; return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }; return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }; return .success
        }
        remoteCommandsInstalled = true
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: (state == .playing || state == .buffering) ? 1.0 : 0.0
        ]
        if let album = track.album { info[MPMediaItemPropertyAlbumTitle] = album }
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = nowPlayingArtwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for track: MusicTrack) {
        artworkTask?.cancel()
        nowPlayingArtwork = nil
        guard let url = track.artworkURL else { return }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        artworkTask = Task { [weak self] in
            defer { session.finishTasksAndInvalidate() }
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let image = UIImage(data: data),
                      let self, !Task.isCancelled,
                      self.currentTrack?.id == track.id else { return }
                self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlaying()
            } catch { }
        }
    }
}
