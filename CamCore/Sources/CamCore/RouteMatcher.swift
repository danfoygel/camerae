import Foundation

/// A driving route as a polyline, with each segment tagged by the maneuver step it belongs to.
public struct RouteGeometry: Sendable {
    public struct Step: Sendable {
        public var instructions: String
        public var coordinates: [Coordinate]

        public init(instructions: String, coordinates: [Coordinate]) {
            self.instructions = instructions
            self.coordinates = coordinates
        }
    }

    public private(set) var coordinates: [Coordinate] = []
    /// Step index for each segment (coordinates[i] → coordinates[i + 1]).
    public private(set) var segmentStep: [Int] = []
    public private(set) var stepInstructions: [String] = []
    public var expectedTravelTime: TimeInterval

    public init(steps: [Step], expectedTravelTime: TimeInterval) {
        self.expectedTravelTime = expectedTravelTime
        for (index, step) in steps.enumerated() {
            stepInstructions.append(step.instructions)
            for point in step.coordinates {
                if let last = coordinates.last, last == point { continue }
                if !coordinates.isEmpty { segmentStep.append(index) }
                coordinates.append(point)
            }
        }
    }

    public init(coordinates: [Coordinate], instructions: String = "", expectedTravelTime: TimeInterval) {
        self.init(steps: [Step(instructions: instructions, coordinates: coordinates)], expectedTravelTime: expectedTravelTime)
    }
}

public struct RouteCamera: Identifiable, Sendable, Hashable {
    public enum Reason: String, Sendable {
        /// The camera's highway matches the highway the route is on at that point.
        case sameRoad
        /// No highway number, but the camera's street name appears in the route step.
        case sameStreetName
        /// Neither side names a road; accepted on proximity (and axis, when known).
        case proximity
    }

    public var camera: Camera
    public var id: String { camera.id }
    /// Meters from the route start to the camera's projection on the route.
    public var distanceAlong: Double
    /// Perpendicular distance from the route, in meters.
    public var offset: Double
    /// Estimated seconds from departure, interpolated from the route's total travel time.
    public var eta: TimeInterval
    /// Direction of travel at the camera, degrees from north.
    public var travelBearing: Double
    /// Direction the camera looks, degrees from north, when its name says.
    public var viewBearing: Double?
    public var reason: Reason

    public var travelCompass: String { Geo.compassLabel(travelBearing) }
    public var viewCompass: String? { viewBearing.map(Geo.compassLabel) }

    public enum Facing: Sendable {
        /// Looking the way the route travels: the road ahead.
        case ahead
        /// Looking back toward where the route came from.
        case behind
        /// Looking across the route, e.g. down a cross street.
        case side
    }

    /// How the view lines up with the direction of travel, when the view direction is known.
    public var facing: Facing? {
        guard let viewBearing else { return nil }
        return switch Geo.angleDifference(viewBearing, travelBearing) {
        case ..<60: .ahead
        case 120...: .behind
        default: .side
        }
    }

    /// Angle off the direction of travel, 0 (ahead) to 180 (behind); 90 when unknown, so an
    /// unlabeled view ranks below one known to look ahead and above one known to look back.
    var viewScore: Double {
        viewBearing.map { Geo.angleDifference($0, travelBearing) } ?? 90
    }
}

/// Cameras at one spot on the route, best view first.
///
/// Caltrans often mounts several cameras on one pole, each looking a different way. They
/// become one stop on the route, led by the view looking the way the route travels.
public struct RouteSite: Identifiable, Sendable, Hashable {
    /// The best view's id, kept when `filter` drops views so selection survives filtering.
    public let id: String
    /// Never empty.
    public private(set) var views: [RouteCamera]

    public var primary: RouteCamera { views[0] }

    init(views: [RouteCamera]) {
        self.views = views.sorted { ($0.viewScore, $0.offset) < ($1.viewScore, $1.offset) }
        id = self.views[0].id
    }

    /// The site with only the views that pass `isIncluded`, or nil when none do.
    public func filter(_ isIncluded: (RouteCamera) -> Bool) -> RouteSite? {
        var site = self
        site.views = views.filter(isIncluded)
        return site.views.isEmpty ? nil : site
    }

    /// Groups cameras into sites: each camera joins the first earlier camera within `radius`
    /// meters that leads a site. Measuring from the leader keeps a row of closely spaced
    /// cameras along a corridor from chaining into one long site.
    static func group(_ cameras: [RouteCamera], radius: Double) -> [RouteSite] {
        // Nearby cameras project close together, so only recent sites can hold a match.
        let window = max(radius * 10, 500)
        var groups: [[RouteCamera]] = []
        for camera in cameras.sorted(by: { $0.distanceAlong < $1.distanceAlong }) {
            let target = groups.indices.reversed()
                .prefix { camera.distanceAlong - groups[$0][0].distanceAlong <= window }
                .first { Geo.distance(groups[$0][0].camera.coordinate, camera.camera.coordinate) <= radius }
            if let target {
                groups[target].append(camera)
            } else {
                groups.append([camera])
            }
        }
        return groups.map(RouteSite.init).sorted { $0.primary.distanceAlong < $1.primary.distanceAlong }
    }
}

/// Finds the cameras along a route and orders them by distance from the start.
///
/// 1. Candidate search: cameras within `corridor` meters of any route segment, via a grid index.
/// 2. Linear referencing: each candidate is projected onto the route for distance-along and offset.
/// 3. Filtering against the road the route is on at that point: a camera naming a different
///    highway is rejected (cross streets, overpasses, parallel freeways); cameras with no road
///    information must sit closer to the line and, when the source gives a direction, line up
///    with the direction of travel.
public struct RouteMatcher: Sendable {
    public struct Options: Sendable {
        /// Search radius around the route for cameras on the same highway.
        public var corridor: Double = 150
        /// Max offset for a camera whose street name matches the step text.
        public var streetNameMaxOffset: Double = 100
        /// Max offset when there is no road information to compare.
        public var proximityMaxOffset: Double = 50
        /// Max angle between the camera's road axis and the route's direction of travel.
        public var axisTolerance: Double = 50
        /// Cameras this close together are one site with several views. Caltrans puts the
        /// views of one intersection up to about 65 m apart, on different poles.
        public var siteRadius: Double = 70

        public init() {}
    }

    private struct Cell: Hashable { var x: Int; var y: Int }
    private static let cellDegrees = 0.01

    public let cameras: [Camera]
    public var options: Options
    private let grid: [Cell: [Int]]
    private let refs: [Set<RoadRef>]
    private let nameTokens: [Set<String>]
    private let viewBearings: [Double?]

    public init(cameras: [Camera], options: Options = Options()) {
        self.cameras = cameras
        self.options = options
        var grid: [Cell: [Int]] = [:]
        for (i, camera) in cameras.enumerated() {
            grid[Self.cell(lat: camera.lat, lon: camera.lon), default: []].append(i)
        }
        self.grid = grid
        refs = cameras.map(\.roadRefs)
        nameTokens = cameras.map { Self.tokens(($0.road ?? "") + " " + $0.name) }
        viewBearings = cameras.map(\.viewBearing)
    }

    /// The cameras along the route grouped into sites, in route order.
    public func sites(along route: RouteGeometry) -> [RouteSite] {
        RouteSite.group(match(route), radius: options.siteRadius)
    }

    public func match(_ route: RouteGeometry) -> [RouteCamera] {
        let points = route.coordinates
        guard points.count >= 2 else { return [] }

        let stepTokens = route.stepInstructions.map(Self.tokens)
        let stepRefs = Self.resolveStepRefs(route.stepInstructions, tokens: stepTokens)
        let stepIsSurfaceStreet = route.stepInstructions.map(Self.namesSurfaceStreet)

        var cumulative = [0.0]
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + Geo.distance(points[i - 1], points[i]))
        }
        let total = cumulative[points.count - 1]

        var best: [Int: RouteCamera] = [:]
        for s in 0..<(points.count - 1) {
            let a = points[s], b = points[s + 1]
            let step = route.segmentStep[s]
            let bearing = Geo.bearing(a, b)
            for i in candidates(near: a, b) {
                let camera = cameras[i]
                let (t, offset) = Geo.project(camera.coordinate, ontoSegment: a, b)
                guard offset <= options.corridor,
                      let reason = accept(camera: i, offset: offset, bearing: bearing,
                                          stepRefs: stepRefs[step], stepTokens: stepTokens[step],
                                          surfaceStreet: stepIsSurfaceStreet[step])
                else { continue }
                if let existing = best[i], existing.offset <= offset { continue }
                let along = cumulative[s] + t * (cumulative[s + 1] - cumulative[s])
                best[i] = RouteCamera(
                    camera: camera,
                    distanceAlong: along,
                    offset: offset,
                    eta: total > 0 ? route.expectedTravelTime * along / total : 0,
                    travelBearing: bearing,
                    viewBearing: viewBearings[i],
                    reason: reason
                )
            }
        }
        return best.values.sorted { $0.distanceAlong < $1.distanceAlong }
    }

    private func accept(camera i: Int, offset: Double, bearing: Double,
                        stepRefs: Set<RoadRef>, stepTokens: Set<String>,
                        surfaceStreet: Bool) -> RouteCamera.Reason? {
        let cameraRefs = refs[i]
        if !cameraRefs.isEmpty && !stepRefs.isEmpty {
            // Both sides name highways: they must agree.
            return cameraRefs.intersectsLoosely(stepRefs) ? .sameRoad : nil
        }
        // A highway camera next to a plain street is an overpass or ramp view.
        if !cameraRefs.isEmpty && surfaceStreet { return nil }
        if cameraRefs.isEmpty && !nameTokens[i].isDisjoint(with: stepTokens) && offset <= options.streetNameMaxOffset {
            return .sameStreetName
        }
        guard offset <= options.proximityMaxOffset else { return nil }
        if let axis = cameras[i].roadAxis, Geo.axisDifference(axis, bearing) > options.axisTolerance {
            return nil
        }
        return .proximity
    }

    /// Highways traveled in each step. Steps that only name a freeway ("Continue onto
    /// San Bernardino Fwy") inherit the number another step tied to that name
    /// ("... onto San Bernardino Fwy, I-10 East").
    static func resolveStepRefs(_ instructions: [String], tokens: [Set<String>]) -> [Set<RoadRef>] {
        var refs = instructions.map(RoadRef.parseTraveledRoads(fromInstruction:))
        var refsByName: [String: Set<RoadRef>] = [:]
        for (i, stepRefs) in refs.enumerated() where !stepRefs.isEmpty {
            for token in tokens[i] { refsByName[token, default: []].formUnion(stepRefs) }
        }
        for i in refs.indices where refs[i].isEmpty {
            for token in tokens[i] {
                if let named = refsByName[token] { refs[i].formUnion(named) }
            }
        }
        return refs
    }

    /// True when an instruction names a road that is neither a numbered highway nor a named
    /// freeway ("Turn left onto S De Anza Blvd"). Blank instructions say nothing, so false.
    static func namesSurfaceStreet(_ instruction: String) -> Bool {
        !instruction.trimmingCharacters(in: .whitespaces).isEmpty
            && RoadRef.parseTraveledRoads(fromInstruction: instruction).isEmpty
            && instruction.range(of: freewayWords, options: [.regularExpression, .caseInsensitive]) == nil
    }

    private static let freewayWords =
        #"\b(fwy|freeway|hwy|highway|expy|expressway|interstate|tollway|turnpike|beltway|skyway|bypass)\b"#

    private func candidates(near a: Coordinate, _ b: Coordinate) -> [Int] {
        let padLat = options.corridor / Geo.metersPerDegreeLat
        let padLon = options.corridor / Geo.metersPerDegreeLon(atLat: max(abs(a.lat), abs(b.lat)))
        let lo = Self.cell(lat: min(a.lat, b.lat) - padLat, lon: min(a.lon, b.lon) - padLon)
        let hi = Self.cell(lat: max(a.lat, b.lat) + padLat, lon: max(a.lon, b.lon) + padLon)
        var result: [Int] = []
        for x in lo.x...hi.x {
            for y in lo.y...hi.y {
                if let ids = grid[Cell(x: x, y: y)] { result.append(contentsOf: ids) }
            }
        }
        return result
    }

    private static func cell(lat: Double, lon: Double) -> Cell {
        Cell(x: Int((lon / cellDegrees).rounded(.down)), y: Int((lat / cellDegrees).rounded(.down)))
    }

    private static let genericWords: Set<String> = [
        "north", "south", "east", "west", "road", "street", "avenue", "blvd", "boulevard", "drive",
        "lane", "parkway", "pkwy", "highway", "freeway", "expressway", "exit", "ramp", "offramp",
        "onramp", "interchange", "bridge", "near", "from", "onto", "toward", "continue", "turn",
        "left", "right", "merge", "keep", "take", "stay", "slight", "sharp", "destination",
        "your", "the", "and", "with", "camera", "view",
    ]

    static func tokens(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 4 && !genericWords.contains($0) })
    }
}
