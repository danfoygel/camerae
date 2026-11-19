import CoreLocation
import Foundation

/// A place the user previously routed from or to, with its resolved coordinate.
struct RecentPlace: Codable, Hashable {
    let title: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

/// Most-recently-used places, persisted in UserDefaults.
@MainActor @Observable
final class RecentPlaces {
    private static let key = "recentPlaces"
    private static let limit = 10

    private(set) var places: [RecentPlace]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        places = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([RecentPlace].self, from: $0) } ?? []
    }

    /// Recents whose title contains `text`, or all of them when `text` is empty.
    func matching(_ text: String) -> [RecentPlace] {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return places }
        return places.filter { $0.title.localizedCaseInsensitiveContains(text) }
    }

    func add(_ place: RecentPlace) {
        places.removeAll { $0.title.caseInsensitiveCompare(place.title) == .orderedSame }
        places.insert(place, at: 0)
        places = Array(places.prefix(Self.limit))
        save()
    }

    func remove(_ place: RecentPlace) {
        places.removeAll { $0 == place }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(places), forKey: Self.key)
    }
}
