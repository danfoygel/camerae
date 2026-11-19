import CamCore
import CoreLocation
import MapKit

/// The driving routes for a trip, each with the camera sites along it in route order.
struct PlannedRoute: Identifiable {
    struct Option: Identifiable {
        let id: Int
        let route: MKRoute
        let sites: [RouteSite]
    }

    let id = UUID()
    let from: String
    let to: String
    /// MapKit's recommended route first, then any alternatives it offered.
    let options: [Option]
    /// The resolved endpoints worth offering again as suggestions (excludes Current Location and Home).
    let places: [RecentPlace]
}

@MainActor
enum RoutePlanner {
    enum PlanError: LocalizedError {
        case placeNotFound
        case noRoute
        case locationDenied

        var errorDescription: String? {
            switch self {
            case .placeNotFound: "Couldn't find that place."
            case .noRoute: "No driving route was found."
            case .locationDenied: "Location access is off. Enter a starting address instead."
            }
        }
    }

    static func plan(from: Endpoint, to: Endpoint, matcher: RouteMatcher) async throws -> PlannedRoute {
        if from == .currentLocation || to == .currentLocation {
            try await LocationPermission.shared.ensureAuthorized()
        }
        let source = try await from.resolve()
        let destination = try await to.resolve()
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        let routes = try await MKDirections(request: request).calculate().routes
        guard !routes.isEmpty else { throw PlanError.noRoute }
        let options = routes.enumerated().map { index, route in
            PlannedRoute.Option(id: index, route: route, sites: matcher.sites(along: geometry(of: route)))
        }
        return PlannedRoute(from: from.title, to: to.title, options: options,
                            places: [(from, source), (to, destination)].compactMap { endpoint, item in
                                guard !endpoint.isShortcut else { return nil }
                                let c = item.coordinate
                                return RecentPlace(title: endpoint.title, latitude: c.latitude, longitude: c.longitude)
                            })
    }

    /// Converts an MKRoute to the matcher's geometry.
    ///
    /// A step's polyline runs from the previous maneuver up to its own maneuver, so the road
    /// driven along a step is the one named by the *previous* step's instruction
    /// ("Merge onto I-80 E" precedes the 200 km step labeled "Take exit 13").
    static func geometry(of route: MKRoute) -> RouteGeometry {
        var previousInstruction = ""
        var steps: [RouteGeometry.Step] = []
        for step in route.steps {
            steps.append(.init(instructions: previousInstruction, coordinates: step.polyline.coordinates))
            previousInstruction = step.instructions
        }
        return RouteGeometry(steps: steps, expectedTravelTime: route.expectedTravelTime)
    }
}

extension MKPolyline {
    var clCoordinates: [CLLocationCoordinate2D] {
        var points = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&points, range: NSRange(location: 0, length: pointCount))
        return points
    }

    var coordinates: [Coordinate] {
        clCoordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
    }
}

/// Requests when-in-use location access once, for "Current Location" starts.
@MainActor
final class LocationPermission: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermission()
    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    func ensureAuthorized() async throws {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { waiters.append($0); manager.requestWhenInUseAuthorization() }
        }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return
        default: throw RoutePlanner.PlanError.locationDenied
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard self.manager.authorizationStatus != .notDetermined else { return }
            waiters.forEach { $0.resume() }
            waiters = []
        }
    }
}
