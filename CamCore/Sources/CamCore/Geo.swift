import Foundation

public struct Coordinate: Hashable, Sendable, Codable {
    public var lat: Double
    public var lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

enum Geo {
    static let earthRadius = 6_371_008.8
    static let metersPerDegreeLat = earthRadius * .pi / 180

    static func metersPerDegreeLon(atLat lat: Double) -> Double {
        metersPerDegreeLat * cos(lat * .pi / 180)
    }

    /// Great-circle distance in meters.
    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Initial bearing from a to b, degrees clockwise from north in [0, 360).
    static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.lat * .pi / 180, lat2 = b.lat * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Smallest angle between two undirected axes (0...90), e.g. a road's N–S axis vs a bearing.
    static func axisDifference(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 180)
        return min(d, 180 - d)
    }

    /// Projects p onto segment a→b using a local flat approximation, which is accurate
    /// to well under a meter for the segment lengths a route polyline contains.
    /// Returns the fraction along the segment (0...1) and the perpendicular offset in meters.
    static func project(_ p: Coordinate, ontoSegment a: Coordinate, _ b: Coordinate) -> (t: Double, offset: Double) {
        let kx = metersPerDegreeLon(atLat: a.lat)
        let ky = metersPerDegreeLat
        let bx = (b.lon - a.lon) * kx, by = (b.lat - a.lat) * ky
        let px = (p.lon - a.lon) * kx, py = (p.lat - a.lat) * ky
        let len2 = bx * bx + by * by
        let t = len2 > 0 ? max(0, min(1, (px * bx + py * by) / len2)) : 0
        let dx = px - t * bx, dy = py - t * by
        return (t, (dx * dx + dy * dy).squareRoot())
    }

    static func compassLabel(_ bearing: Double) -> String {
        let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return labels[Int((bearing + 22.5) / 45) % 8]
    }
}
