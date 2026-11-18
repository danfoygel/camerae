import MapKit

/// A start or end point the user picked.
enum Endpoint: Equatable {
    case currentLocation
    case completion(MKLocalSearchCompletion)
    case query(String)

    var title: String {
        switch self {
        case .currentLocation: "Current Location"
        case .completion(let c): c.subtitle.isEmpty ? c.title : "\(c.title), \(c.subtitle)"
        case .query(let q): q
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
