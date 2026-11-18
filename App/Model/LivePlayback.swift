import AVFoundation
import CamCore
import os

private let log = Logger(subsystem: "com.camerae.app", category: "playback")

/// The app's single live-video player. Phones run out of hardware decoders after a handful
/// of players, so one AVPlayer moves to whichever camera is selected.
@MainActor @Observable
final class LivePlayback {
    enum Status: Equatable {
        case idle
        case loading
        case playing
        case failed
    }

    /// Give up and fall back to snapshots if a stream hasn't started by then. Caltrans
    /// segments are 10 s long, so a healthy stream can take a while to start.
    static let startTimeout: Duration = .seconds(25)

    let player = AVPlayer()
    private(set) var cameraID: String?
    private(set) var status: Status = .idle
    private var observations: [NSKeyValueObservation] = []
    private var timeout: Task<Void, Never>?

    init() {
        player.isMuted = true
    }

    func play(_ camera: Camera) {
        guard let url = camera.hlsURL else { return stop() }
        guard camera.id != cameraID else { return }
        reset()
        let id = camera.id
        cameraID = id
        status = .loading

        // No forward-buffer cap: Caltrans serves 10 s segments, and a cap below one segment
        // keeps AVPlayer waiting to minimize stalling forever.
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()

        // Read values off the observed object: KVO's change.newValue arrives nil for these
        // Objective-C enum properties.
        observations = [
            item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status == .failed else { return }
                Task { @MainActor in self?.update(.failed, for: id) }
            },
            player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                guard player.timeControlStatus == .playing else { return }
                Task { @MainActor in self?.update(.playing, for: id) }
            },
        ]
        timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.startTimeout)
            guard !Task.isCancelled, self?.status == .loading else { return }
            self?.update(.failed, for: id)
        }
    }

    func stop() {
        reset()
        cameraID = nil
        status = .idle
    }

    private func update(_ newStatus: Status, for id: String) {
        // Ignore late callbacks from a camera the user has already moved away from.
        guard cameraID == id, status != .failed else { return }
        status = newStatus
        if newStatus == .failed {
            log.notice("live video failed for \(id, privacy: .public); showing snapshots")
            player.replaceCurrentItem(with: nil)
        }
    }

    private func reset() {
        observations.forEach { $0.invalidate() }
        observations = []
        timeout?.cancel()
        timeout = nil
        player.replaceCurrentItem(with: nil)
    }
}
