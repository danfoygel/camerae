import Foundation

/// Which way a camera looks, read from its name.
///
/// Caltrans often puts several cameras on one pole and names each view ("US-101 : Hilfiker (N)",
/// "SR-20 : West Of US-101 - Looking West", "T256E -- I-80 : Buchanan Street East View"). Its
/// `direction` field is shared by every view on the pole, so it can't tell them apart.
enum ViewDirection {
    /// Compass bearing the camera looks toward, or nil when the name doesn't say.
    static func bearing(fromName name: String) -> Double? {
        let ns = name as NSString
        let range = NSRange(location: 0, length: ns.length)
        for pattern in patterns {
            guard let match = pattern.firstMatch(in: name, range: range) else { continue }
            if let bearing = bearings[ns.substring(with: match.range(at: 1)).lowercased()] {
                return bearing
            }
        }
        return nil
    }

    private static let word = #"(north(?:east|west)?|south(?:east|west)?|east|west|[ns][ew]?|[ew])"#

    private static let patterns: [NSRegularExpression] = [
        // "Looking North", "(Looking South)", "Looking NW"
        try! NSRegularExpression(pattern: #"\blooking\s+"# + word + #"\b"#, options: .caseInsensitive),
        // "EAST VIEW", "South View"; one-word "Westview" is too often a street name.
        try! NSRegularExpression(pattern: #"\b(north|south|east|west)\s+view\b"#, options: .caseInsensitive),
        // District 4 camera codes end in the view: "T252W -- ", "TA31S -- "
        try! NSRegularExpression(pattern: #"^T[A-Z]?\d{2,3}([NSEW]) --"#),
        // A trailing direction after a dash: "Lord Ellis - East", "(PTZ) - North (C019)"
        try! NSRegularExpression(pattern: #"[-–]\s*(north|south|east|west)\s*(?:\(|$)"#, options: .caseInsensitive),
        // "Hilfiker (N)", "McCullen (S)"
        try! NSRegularExpression(pattern: #"\(([nsew])\)"#, options: .caseInsensitive),
    ]

    private static let bearings: [String: Double] = [
        "n": 0, "ne": 45, "e": 90, "se": 135, "s": 180, "sw": 225, "w": 270, "nw": 315,
        "north": 0, "northeast": 45, "east": 90, "southeast": 135,
        "south": 180, "southwest": 225, "west": 270, "northwest": 315,
    ]
}
