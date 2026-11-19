import Foundation

enum Format {
    static func distance(_ meters: Double) -> String {
        let miles = meters / 1_609.344
        return miles < 10 ? String(format: "%.1f mi", miles) : "\(Int(miles.rounded())) mi"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// Time left on the free trial, rounded up: "72 h", "1 h", "12 min".
    static func remaining(_ seconds: TimeInterval) -> String {
        seconds > 60 * 60 ? "\(Int((seconds / 3_600).rounded(.up))) h" : "\(max(Int((seconds / 60).rounded(.up)), 1)) min"
    }
}
