import Foundation

/// A numbered highway, e.g. I-80, US-50, SR-99. Free-text sources ("Hwy 50", "215 WB Decatur")
/// produce `.unknown`, which matches any highway with the same number.
public struct RoadRef: Hashable, Sendable, CustomStringConvertible {
    public enum Kind: String, Sendable {
        case interstate = "I"
        case us = "US"
        case state = "SR"
        case unknown = "?"
    }

    public var kind: Kind
    public var number: Int

    public init(_ kind: Kind, _ number: Int) {
        self.kind = kind
        self.number = number
    }

    public var description: String { "\(kind.rawValue)-\(number)" }

    public func matches(_ other: RoadRef) -> Bool {
        number == other.number && (kind == other.kind || kind == .unknown || other.kind == .unknown)
    }

    /// Extracts every highway reference in a piece of text.
    ///
    /// Handles feed spellings ("I-80", "I80", "US50", "SR-28", "Hwy 50", "215 WB ...") and
    /// MapKit instruction spellings ("I-80 E", "CA-99 N", "NV-28", "US-395 S").
    public static func parse(_ text: String) -> Set<RoadRef> {
        var refs = Set<RoadRef>()
        let ns = text as NSString
        for match in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let number = Int(ns.substring(with: match.range(at: 2))) else { continue }
            let prefix = ns.substring(with: match.range(at: 1)).uppercased()
                .replacingOccurrences(of: ".", with: "")
            refs.insert(RoadRef(kind(forPrefix: prefix), number))
        }
        // A bare leading number followed by a travel direction ("215 WB Decatur Off").
        let full = NSRange(location: 0, length: ns.length)
        if let m = bareLeading.firstMatch(in: text, range: full), let n = Int(ns.substring(with: m.range(at: 1))) {
            refs.insert(RoadRef(.unknown, n))
        }
        return refs
    }

    /// Like `parse`, but ignores destinations: "Merge onto I-580 E toward I-80" → {I-580}.
    public static func parseTraveledRoads(fromInstruction text: String) -> Set<RoadRef> {
        if let r = text.range(of: #"\b(toward|towards|for)\b"#, options: [.regularExpression, .caseInsensitive]) {
            return parse(String(text[..<r.lowerBound]))
        }
        return parse(text)
    }

    private static func kind(forPrefix prefix: String) -> Kind {
        switch prefix {
        case "I", "INTERSTATE": return .interstate
        case "US", "US HWY", "US HIGHWAY", "US ROUTE": return .us
        case "SR", "CA", "NV", "STATE ROUTE", "STATE HWY", "STATE HIGHWAY", "CA SR", "NV SR": return .state
        default: return .unknown
        }
    }

    private static let pattern = try! NSRegularExpression(
        pattern: #"\b(INTERSTATE|I|US HIGHWAY|US HWY|US ROUTE|U\.S\.|US|STATE ROUTE|STATE HWY|STATE HIGHWAY|SR|CA|NV|HWY|HIGHWAY|ROUTE|RTE)[ -]?(\d{1,3})(?![\d.])"#,
        options: [.caseInsensitive]
    )

    private static let bareLeading = try! NSRegularExpression(
        pattern: #"^\s*(\d{1,3})\s+(NB|SB|EB|WB|N/B|S/B|E/B|W/B)\b"#,
        options: [.caseInsensitive]
    )
}

extension Set where Element == RoadRef {
    func intersectsLoosely(_ other: Set<RoadRef>) -> Bool {
        contains { a in other.contains { a.matches($0) } }
    }
}
