import Foundation

/// Mirrors the JSON written by tools/build_catalog.py.
public struct CameraCatalog: Codable, Sendable {
    public struct Source: Codable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var attribution: String
        public var infoURL: URL?
    }

    public var version: Int
    public var generatedAt: String
    public var sources: [Source]
    public var cameras: [Camera]

    public static func decode(from data: Data) throws -> CameraCatalog {
        try JSONDecoder().decode(CameraCatalog.self, from: data)
    }

    public func source(for camera: Camera) -> Source? {
        sources.first { $0.id == camera.source }
    }
}

public struct Camera: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var source: String
    public var name: String
    public var place: String?
    public var lat: Double
    public var lon: Double
    /// Route designation ("I-80") or free-text roadway ("I80 @ East Verdi").
    public var road: String?
    /// Compass direction the source reports, if any: N, S, E or W. Caltrans gives every view on
    /// a pole the same value, so this says which road a camera covers, not which way it looks
    /// (see `viewBearing`).
    public var direction: String?
    public var snapshotURL: URL?
    public var snapshotRefreshSeconds: Int
    public var hlsURL: URL?

    public init(
        id: String, source: String, name: String, place: String? = nil,
        lat: Double, lon: Double, road: String? = nil, direction: String? = nil,
        snapshotURL: URL? = nil, snapshotRefreshSeconds: Int = 60, hlsURL: URL? = nil
    ) {
        self.id = id
        self.source = source
        self.name = name
        self.place = place
        self.lat = lat
        self.lon = lon
        self.road = road
        self.direction = direction
        self.snapshotURL = snapshotURL
        self.snapshotRefreshSeconds = snapshotRefreshSeconds
        self.hlsURL = hlsURL
    }

    public var coordinate: Coordinate { Coordinate(lat: lat, lon: lon) }

    /// The name without the operator codes Caltrans embeds:
    /// "TV316 -- I-80 : 6th Street" → "I-80 · 6th Street", "I-110 : (196) Avenue 26" → "I-110 · Avenue 26".
    public var displayName: String {
        var text = name
        for (pattern, replacement) in Self.nameCleanups {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        text = text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? (road ?? id) : text
    }

    private static let nameCleanups = [
        (#"^[A-Z0-9]+ -- "#, ""),     // "TV316 -- "
        (#"^\d+ - "#, ""),            // "90 - "
        (#"\([A-Z]?\d+\)\s*"#, ""),   // "(196) ", "(C526) "
        (#"\s*:\s*"#, " · "),
        (#"\s{2,}"#, " "),
    ]

    /// Highways this camera sits on or names, from both the road field and the title.
    public var roadRefs: Set<RoadRef> {
        RoadRef.parse(road ?? "").union(RoadRef.parse(name))
    }

    /// Compass bearing the camera looks toward, when its name says ("Looking North").
    public var viewBearing: Double? { ViewDirection.bearing(fromName: name) }

    /// Axis of the road the camera covers, in degrees, when the source gives a direction.
    var roadAxis: Double? {
        switch direction {
        case "N", "S": 0
        case "E", "W": 90
        default: nil
        }
    }
}
