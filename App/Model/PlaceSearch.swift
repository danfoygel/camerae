import MapKit

/// A start or end point the user picked.
enum Endpoint: Equatable {
    case currentLocation
    case completion(MKLocalSearchCompletion)
    case query(String)
    case recent(RecentPlace)
    case home(RecentPlace)

    var title: String {
        switch self {
        case .currentLocation: "Current Location"
        case .completion(let c): c.subtitle.isEmpty ? c.title : "\(c.title), \(c.subtitle)"
        case .query(let q): q
        case .recent(let place): place.title
        case .home: "Home"
        }
    }

    /// Current Location and Home are shown by name rather than address, and aren't added to recents.
    var isShortcut: Bool {
        switch self {
        case .currentLocation, .home: true
        case .completion, .query, .recent: false
        }
    }

    @MainActor func resolve() async throws -> MKMapItem {
        switch self {
        case .currentLocation:
            return MKMapItem.forCurrentLocation()
        case .completion(let completion):
            return try await Self.first(MKLocalSearch.Request(completion: completion))
        case .query(let query):
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            return try await Self.first(request)
        case .recent(let place):
            return MKMapItem.at(place.coordinate, name: place.title)
        case .home(let place):
            return MKMapItem.at(place.coordinate, name: "Home")
        }
    }

    @MainActor private static func first(_ request: MKLocalSearch.Request) async throws -> MKMapItem {
        request.resultTypes = [.address, .pointOfInterest]
        guard let item = try await MKLocalSearch(request: request).start().mapItems.first else {
            throw RoutePlanner.PlanError.placeNotFound
        }
        return item
    }
}

extension MKMapItem {
    @MainActor static func at(_ coordinate: CLLocationCoordinate2D, name: String) -> MKMapItem {
        let item: MKMapItem
        if #available(iOS 26, *) {
            item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                             address: nil)
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
        item.name = name
        return item
    }

    var coordinate: CLLocationCoordinate2D {
        if #available(iOS 26, *) { location.coordinate } else { placemark.coordinate }
    }
}

/// Address autocomplete backed by MKLocalSearchCompleter.
@MainActor @Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(_ fragment: String) {
        if fragment.trimmingCharacters(in: .whitespaces).isEmpty {
            completer.cancel()
            results = []
        } else {
            completer.queryFragment = fragment
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated { results = Array(self.completer.results.prefix(8)) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { results = [] }
    }
}
