import Observation

/// Cameras whose latest snapshot was a DOT "camera unavailable" image rather than a frame.
/// Shared so a camera's badge, its collapsed thumbnail and its expanded view agree.
@MainActor @Observable
final class FeedHealth {
    private var offline: Set<String> = []

    func isOffline(_ cameraID: String) -> Bool {
        offline.contains(cameraID)
    }

    func record(_ cameraID: String, offline isOffline: Bool) {
        if isOffline {
            offline.insert(cameraID)
        } else {
            offline.remove(cameraID)
        }
    }
}
