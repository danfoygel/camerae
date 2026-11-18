import CamCore
import CoreLocation
import MapKit

/// A computed route and the cameras along it, in route order.
struct PlannedRoute: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let route: MKRoute
    let cameras: [RouteCamera]
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
        let request = MKDirections.Request()
        request.source = try await from.resolve()
        request.destination = try await to.resolve()
        request.transportType = .automobile
        guard let route = try await MKDirections(request: request).calculate().routes.first else {
            throw PlanError.noRoute
        }
        return PlannedRoute(from: from.title, to: to.title, route: route,
                            cameras: matcher.match(geometry(of: route)))
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
    var coordinates: [Coordinate] {
        var points = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&points, range: NSRange(location: 0, length: pointCount))
        return points.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
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
