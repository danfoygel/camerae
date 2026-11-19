import CoreGraphics
import Foundation
import ImageIO

/// A camera image shrunk to a few hundred RGB values. At this size the parts of an error image
/// that change between downloads (Caltrans stamps the current time on every image, JPEG noise)
/// mostly average away, while its overall layout survives.
public struct ImageFingerprint: Sendable {
    static let width = 16
    static let height = 12

    let rgb: [UInt8]

    public init?(imageData: Data) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              // A decoder-side thumbnail is much cheaper than decoding the full frame and,
              // for JPEG, already averages blocks.
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 64,
              ] as CFDictionary)
        else { return nil }
        self.init(image: thumbnail)
    }

    init?(image: CGImage) {
        let w = Self.width, h = Self.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            // Stretch to a fixed grid so the same error page matches at any size.
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        rgb = rgba.enumerated().filter { $0.offset % 4 != 3 }.map(\.element)
    }

    /// Mean absolute difference per channel, 0 (identical) to 255.
    public func distance(to other: ImageFingerprint) -> Double {
        let total = zip(rgb, other.rgb).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(total) / Double(rgb.count)
    }
}

/// Recognizes the stock "camera unavailable" images DOTs serve in place of a frame, which
/// arrive as ordinary 200 OK images. Add a new one by dropping a sample into Resources/Placeholders.
public struct PlaceholderDetector: Sendable {
    /// In a sweep of every California and Nevada camera (Nov 2026), error images measured at most
    /// 6.3 from a reference and the closest real frame, a featureless sky, 33.7.
    public static let threshold = 12.0

    public static let standard = PlaceholderDetector(
        references: (Bundle.module.urls(forResourcesWithExtension: nil, subdirectory: "Placeholders") ?? [])
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap(ImageFingerprint.init(imageData:))
    )

    let references: [ImageFingerprint]

    public init(references: [ImageFingerprint]) {
        self.references = references
    }

    public func isPlaceholder(_ imageData: Data) -> Bool {
        guard let fingerprint = ImageFingerprint(imageData: imageData) else { return false }
        return isPlaceholder(fingerprint)
    }

    public func isPlaceholder(_ fingerprint: ImageFingerprint) -> Bool {
        references.contains { fingerprint.distance(to: $0) < Self.threshold }
    }
}
