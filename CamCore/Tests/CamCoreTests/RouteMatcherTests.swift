import Foundation
import Testing
@testable import CamCore

/// Synthetic geometry around Sacramento: a route heading due east along latitude 38.6.
struct RouteMatcherTests {
    static let lat = 38.6
    static let metersPerLon = Geo.metersPerDegreeLon(atLat: lat)
    static let metersPerLat = Geo.metersPerDegreeLat

    /// A point `east` meters along the route and `north` meters off it.
    static func at(east: Double, north: Double = 0) -> Coordinate {
        Coordinate(lat: lat + north / metersPerLat, lon: -121.5 + east / metersPerLon)
    }

    static func camera(_ id: String, east: Double, north: Double, road: String? = nil, name: String = "", direction: String? = nil) -> Camera {
        let p = at(east: east, north: north)
        return Camera(id: id, source: "test", name: name, lat: p.lat, lon: p.lon, road: road, direction: direction)
    }

    static let eastbound = RouteGeometry(
        steps: [
            .init(instructions: "Turn right onto J St", coordinates: [at(east: 0), at(east: 2_000)]),
            .init(instructions: "Merge onto I-80 E toward Reno", coordinates: [at(east: 2_000), at(east: 20_000)]),
        ],
        expectedTravelTime: 1_000
    )

    @Test func ordersCamerasByDistanceAlongRoute() {
        let matcher = RouteMatcher(cameras: [
            Self.camera("far", east: 15_000, north: 30, road: "I-80"),
            Self.camera("near", east: 5_000, north: -40, road: "I-80"),
        ])
        let result = matcher.match(Self.eastbound)
        #expect(result.map(\.id) == ["near", "far"])
        #expect(abs(result[0].distanceAlong - 5_000) < 5)
        #expect(abs(result[0].offset - 40) < 1)
        #expect(abs(result[0].eta - 250) < 1)
        #expect(result[0].travelCompass == "E")
        #expect(result[0].reason == .sameRoad)
    }

    @Test func rejectsCamerasOutsideCorridor() {
        let matcher = RouteMatcher(cameras: [Self.camera("parallel", east: 8_000, north: 400, road: "I-80")])
        #expect(matcher.match(Self.eastbound).isEmpty)
    }

    @Test func rejectsCameraOnCrossingHighway() {
        // An SR-99 camera 20 m from the line where the route is on I-80: an overpass.
        let matcher = RouteMatcher(cameras: [Self.camera("overpass", east: 9_000, north: 20, road: "SR-99")])
        #expect(matcher.match(Self.eastbound).isEmpty)
    }

    @Test func rejectsHighwayCameraBesideSurfaceStreet() {
        // The route passes under SR-85 on J St; the SR-85 camera is not on the route.
        let matcher = RouteMatcher(cameras: [Self.camera("sr85", east: 1_000, north: 10, road: "SR-85", name: "SR-85 : J Street")])
        #expect(matcher.match(Self.eastbound).isEmpty)
        // An unnumbered freeway step still allows close highway cameras.
        let hollywood = RouteGeometry(
            coordinates: [Self.at(east: 0), Self.at(east: 3_000)],
            instructions: "Take exit 153B to merge onto Hollywood Fwy",
            expectedTravelTime: 200
        )
        #expect(matcher.match(hollywood).map(\.reason) == [.proximity])
    }

    /// Fortuna → Arcata as MapKit describes it (instructions already shifted onto the polyline
    /// they cover, as RoutePlanner does): US-101 is named only as a destination, then as
    /// Eureka's W Fifth St, which carries US-101 through town and on to Arcata.
    static let fortunaToArcata = RouteGeometry(
        steps: [
            .init(instructions: "Keep right onto Main St", coordinates: [at(east: 0), at(east: 1_000)]),
            .init(instructions: "Continue toward US-101 North", coordinates: [at(east: 1_000), at(east: 27_000)]),
            .init(instructions: "Turn right onto W Fifth St", coordinates: [at(east: 27_000), at(east: 39_000)]),
            .init(instructions: "Take the exit onto CA-255, Samoa Blvd toward Arcata", coordinates: [at(east: 39_000), at(east: 39_300)]),
        ],
        expectedTravelTime: 2_400
    )

    @Test func matchesHighwayCamerasWhereStepsNameNoHighway() {
        let matcher = RouteMatcher(cameras: [
            Self.camera("spruce", east: 18_000, north: 51, road: "US-101", name: "US-101 : Eureka / Spruce Point - Looking North (C023)"),
            Self.camera("fernbridge", east: 6_000, north: 131, road: "SR-211", name: "SR-211: Fernbridge (Looking South)"),
            Self.camera("5thV", east: 27_400, north: 8, road: "US-101", name: "US-101: Eureka / 5th & V - Looking South"),
            Self.camera("5thL", east: 28_600, north: 9, road: "US-101", name: "US-101: Eureka / 5th&L - Looking North"),
            Self.camera("4thH", east: 28_900, north: 105, road: "US-101", name: "US-101: Eureka / 4th & H - Looking North (CXXX)"),
            Self.camera("airport", east: 35_000, north: 13, road: "US-101", name: "US-101: Jacobs/Airport"),
        ])
        let result = matcher.match(Self.fortunaToArcata)
        #expect(result.map(\.id) == ["spruce", "5thV", "5thL", "4thH", "airport"])
        #expect(result.allSatisfy { $0.reason == .sameRoad })
    }

    @Test func streetStepNeedsSpreadOutCloseHighwayCameras() {
        let street = RouteGeometry(
            coordinates: [Self.at(east: 0), Self.at(east: 5_000)],
            instructions: "Turn left onto Oak St",
            expectedTravelTime: 400
        )
        // Both directions of one overpass: a single spot, so still an overpass view.
        let overpass = RouteMatcher(cameras: [
            Self.camera("n", east: 2_000, north: 5, road: "SR-85", name: "SR-85 : Oak Street - Looking North"),
            Self.camera("s", east: 2_010, north: 5, road: "SR-85", name: "SR-85 : Oak Street - Looking South"),
        ])
        #expect(overpass.match(street).isEmpty)
        // A freeway alongside a frontage road: spread out, but not right beside the street.
        let parallel = RouteMatcher(cameras: [
            Self.camera("a", east: 1_000, north: 40, road: "I-5"),
            Self.camera("b", east: 3_000, north: 40, road: "I-5"),
        ])
        #expect(parallel.match(street).isEmpty)
    }

    @Test func acceptsInterchangeCameraThatNamesRouteHighway() {
        let matcher = RouteMatcher(cameras: [
            Self.camera("interchange", east: 9_000, north: 60, road: "SR-99", name: "SR-99 : at I-80 Interchange"),
        ])
        #expect(matcher.match(Self.eastbound).map(\.id) == ["interchange"])
    }

    @Test func streetCameraMatchesByName() {
        let matcher = RouteMatcher(cameras: [
            Self.camera("jst", east: 1_000, north: 80, road: "J Street & 5th", name: "J Street & 5th"),
            Self.camera("other", east: 1_200, north: 80, road: "Folsom & 5th", name: "Folsom & 5th"),
        ])
        // "J St" has no 4+ letter token, so the J Street camera falls back to proximity
        // and is too far off; neither should match.
        #expect(matcher.match(Self.eastbound).isEmpty)

        let mccarran = RouteGeometry(
            coordinates: [Self.at(east: 0), Self.at(east: 3_000)],
            instructions: "Turn left onto N McCarran Blvd",
            expectedTravelTime: 200
        )
        let nv = RouteMatcher(cameras: [Self.camera("mc", east: 1_500, north: 70, road: "McCarran & Lakeside")])
        #expect(nv.match(mccarran).map(\.reason) == [.sameStreetName])
    }

    @Test func freewayNameInheritsHighwayNumber() {
        let instructions = [
            "Take exit 1D on the left onto San Bernardino Fwy, I-10 East toward San Bernardino",
            "Continue onto San Bernardino Fwy",
            "Turn right onto Main St",
        ]
        let refs = RouteMatcher.resolveStepRefs(instructions, tokens: instructions.map(RouteMatcher.tokens))
        #expect(refs == [[RoadRef(.interstate, 10)], [RoadRef(.interstate, 10)], []])
    }

    @Test func proximityUsesRoadAxisWhenKnown() {
        // No highway named anywhere on the first step; cameras close to the line.
        let matcher = RouteMatcher(cameras: [
            Self.camera("aligned", east: 500, north: 20, direction: "E"),
            Self.camera("crossing", east: 700, north: 20, direction: "N"),
            Self.camera("unknown", east: 900, north: 20),
        ])
        #expect(matcher.match(Self.eastbound).map(\.id) == ["aligned", "unknown"])
    }

    @Test func handlesLongRouteQuickly() {
        // ~1,000 km of route with 5,000 cameras scattered around it.
        var coordinates: [Coordinate] = []
        for i in 0...10_000 { coordinates.append(Self.at(east: Double(i) * 100, north: sin(Double(i) / 50) * 500)) }
        var cameras: [Camera] = []
        for i in 0..<5_000 {
            cameras.append(Self.camera("c\(i)", east: Double(i) * 200, north: Double(i % 7) * 300 - 900, road: "I-80"))
        }
        let route = RouteGeometry(coordinates: coordinates, instructions: "Merge onto I-80 E", expectedTravelTime: 36_000)
        let matcher = RouteMatcher(cameras: cameras)
        let start = Date()
        let result = matcher.match(route)
        #expect(Date().timeIntervalSince(start) < 2)
        #expect(!result.isEmpty)
        #expect(result.map(\.distanceAlong) == result.map(\.distanceAlong).sorted())
    }
}
