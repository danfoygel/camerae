import Foundation
import Testing
@testable import CamCore

struct VideoTrialTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let hour: TimeInterval = 60 * 60

    @Test func notStartedUntilFirstPlay() {
        #expect(VideoTrial(startedAt: nil).phase(at: start) == .notStarted)
    }

    @Test func activeForSeventyTwoHours() {
        let trial = VideoTrial(startedAt: start)
        let end = start.addingTimeInterval(72 * hour)
        #expect(trial.phase(at: start) == .active(endsAt: end))
        #expect(trial.phase(at: start.addingTimeInterval(71 * hour)) == .active(endsAt: end))
        #expect(trial.phase(at: end) == .ended)
        #expect(trial.phase(at: end.addingTimeInterval(30 * 24 * hour)) == .ended)
    }

    @Test func toleratesSmallClockCorrections() {
        let trial = VideoTrial(startedAt: start)
        #expect(trial.phase(at: start.addingTimeInterval(-5 * 60)).isActive)
    }

    @Test func endsWhenClockIsSetBack() {
        let trial = VideoTrial(startedAt: start)
        #expect(trial.phase(at: start.addingTimeInterval(-24 * hour)) == .ended)
    }
}
