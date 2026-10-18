import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// One shared player. The phone UI, the mini player and the external display all render this same AVPlayer.
@MainActor
final class PlayerModel: ObservableObject {
    static let shared = PlayerModel()

    let player = AVPlayer()

    @Published private(set) var current: Channel?
    @Published private(set) var isPlaying = false
    @Published var showFullPlayer = false
    @Published var externalDisplayConnected = false
    @Published var errorMessage: String?

    private var queue: [Channel] = []
    private var queueIndex = 0
    private var cancellables = Set<AnyCancellable>()
    private var itemObservation: AnyCancellable?
    private var timeObserver: Any?

    var canGoNext: Bool { queueIndex + 1 < queue.count }
    var canGoPrevious: Bool { queueIndex > 0 }
    var hasQueue: Bool { queue.count > 1 }

    private init() {
        // AirPlay sends the video stream itself. The wired external display is handled by
        // ExternalSceneDelegate, so the automatic wired mode is switched off.
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = false

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status != .paused
                UIApplication.shared.isIdleTimerDisabled = status != .paused
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] note in
                guard let self,
                      let item = note.object as? AVPlayerItem,
                      item === self.player.currentItem,
                      let current = self.current
                else { return }
                LibraryStore.shared.setResume(nil, for: current.key)
            }
            .store(in: &cancellables)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.saveProgress(at: time) }
        }

        setupRemoteCommands()
    }

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Playback

    /// Starts a channel or video and opens the full player.
    func open(_ channel: Channel, in list: [Channel]) {
        play(channel, in: list)
        showFullPlayer = true
    }

    func play(_ channel: Channel, in list: [Channel] = []) {
        queue = list.isEmpty ? [channel] : list
        queueIndex = queue.firstIndex { $0.id == channel.id } ?? 0
        start(channel)
    }

    func next() {
        guard canGoNext else { return }
        queueIndex += 1
        start(queue[queueIndex])
    }

    func previous() {
        guard canGoPrevious else { return }
        queueIndex -= 1
        start(queue[queueIndex])
    }

    func togglePlayPause() {
        if player.timeControlStatus == .paused {
            player.play()
        } else {
            player.pause()
        }
    }

    func seek(by seconds: Double) {
        let target = max(0, player.currentTime().seconds + seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObservation = nil
        current = nil
        queue = []
        queueIndex = 0
        showFullPlayer = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func start(_ channel: Channel) {
        errorMessage = nil
        current = channel

        let item = AVPlayerItem(url: channel.url)
        itemObservation = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.itemStatusChanged(status, item: item)
            }
        player.replaceCurrentItem(with: item)
        player.play()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: channel.name]
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = canGoNext
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = canGoPrevious
    }

    private func itemStatusChanged(_ status: AVPlayerItem.Status, item: AVPlayerItem) {
        guard item === player.currentItem else { return }
        switch status {
        case .readyToPlay:
            // Pick up where the viewer left off (films and episodes only, never live streams).
            if let current,
               let saved = LibraryStore.shared.resumeTime(for: current.key),
               item.duration.seconds.isFinite {
                item.seek(to: CMTime(seconds: saved, preferredTimescale: 600), completionHandler: nil)
            }
        case .failed:
            let reason = item.error?.localizedDescription ?? "Unknown error"
            errorMessage = "Couldn't play this. The stream may be offline, or the format may not be supported (MKV isn't supported yet).\n\n\(reason)"
        default:
            break
        }
    }

    private func saveProgress(at time: CMTime) {
        guard let current, let item = player.currentItem else { return }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 120 else { return }   // skip live streams and short clips

        let seconds = time.seconds
        if seconds > duration - 30 {
            LibraryStore.shared.setResume(nil, for: current.key)
        } else if seconds > 15 {
            LibraryStore.shared.setResume(seconds, for: current.key)
        }
    }

    // MARK: - Lock screen controls

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.pause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
    }
}
