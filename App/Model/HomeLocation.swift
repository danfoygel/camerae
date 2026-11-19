import Foundation

/// The user's saved Home, persisted in UserDefaults.
@MainActor @Observable
final class HomeLocation {
    private static let key = "homePlace"

    private(set) var place: RecentPlace?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        place = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(RecentPlace.self, from: $0) }
    }

    /// Saves `place` as Home, or clears Home when it's nil.
    func set(_ place: RecentPlace?) {
        self.place = place
        if let place {
            defaults.set(try? JSONEncoder().encode(place), forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}
