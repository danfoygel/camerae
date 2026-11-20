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

    @Test func extendingAddsToTheCurrentEnd() {
        var trial = VideoTrial(startedAt: start)
        trial.extend(at: start.addingTimeInterval(10 * hour))
        trial.extend(at: start.addingTimeInterval(11 * hour))
        #expect(trial.phase(at: start.addingTimeInterval(215 * hour)) == .active(endsAt: start.addingTimeInterval(216 * hour)))
        #expect(trial.phase(at: start.addingTimeInterval(216 * hour)) == .ended)
    }

    @Test func extendingAfterTheEndCountsFromNow() {
        var trial = VideoTrial(startedAt: start)
        let now = start.addingTimeInterval(30 * 24 * hour)
        trial.extend(at: now)
        #expect(trial.phase(at: now) == .active(endsAt: now.addingTimeInterval(72 * hour)))
        #expect(trial.startedAt == start)
    }

    @Test func extendingBeforeTheStartStartsTheTrial() {
        var trial = VideoTrial(startedAt: nil)
        trial.extend(at: start)
        #expect(trial.phase(at: start) == .active(endsAt: start.addingTimeInterval(144 * hour)))
    }

    @Test func extendingDoesNotDefeatTheClockCheck() {
        var trial = VideoTrial(startedAt: start)
        trial.extend(at: start)
        #expect(trial.phase(at: start.addingTimeInterval(-24 * hour)) == .ended)
    }

    @Test func endsWhenClockIsSetBack() {
        let trial = VideoTrial(startedAt: start)
        #expect(trial.phase(at: start.addingTimeInterval(-24 * hour)) == .ended)
    }
}
