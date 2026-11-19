import Foundation

/// The free trial of live video. It starts the first time a video plays and lasts 72 hours;
/// after that, live video needs a subscription.
public struct VideoTrial: Equatable, Sendable {
    public static let standardLength: TimeInterval = 72 * 60 * 60
    /// A clock this far behind the trial's start was set back, not corrected for drift.
    static let clockTolerance: TimeInterval = 60 * 60

    public enum Phase: Equatable, Sendable {
        case notStarted
        case active(endsAt: Date)
        case ended

        public var isActive: Bool {
            if case .active = self { true } else { false }
        }
    }

    public var startedAt: Date?
    public var length: TimeInterval

    public init(startedAt: Date?, length: TimeInterval = Self.standardLength) {
        self.startedAt = startedAt
        self.length = length
    }

    public func phase(at now: Date) -> Phase {
        guard let startedAt else { return .notStarted }
        let end = startedAt.addingTimeInterval(length)
        // Setting the clock back to before the start doesn't buy more time.
        guard now >= startedAt.addingTimeInterval(-Self.clockTolerance), now < end else { return .ended }
        return .active(endsAt: end)
    }
}
