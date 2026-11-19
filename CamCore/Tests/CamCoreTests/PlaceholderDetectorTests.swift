import Foundation
import Testing
@testable import CamCore

struct PlaceholderDetectorTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func loadsBundledReferences() {
        #expect(PlaceholderDetector.standard.references.count >= 4)
    }

    /// Error images from other cameras than the references: different timestamps and, for one,
    /// a different size.
    @Test(arguments: [
        "placeholder-caltrans.jpg",
        "placeholder-caltrans-small.jpg",
        "placeholder-caltrans-icon.jpg",
        "placeholder-nevada.png",
    ])
    func recognizesPlaceholders(name: String) throws {
        #expect(PlaceholderDetector.standard.isPlaceholder(try fixture(name)))
    }

    /// Real frames, including the ones closest to a placeholder in a sweep of every camera:
    /// a featureless sky and a dark, foggy night.
    @Test(arguments: [
        "frame-caltrans-flat-sky.jpg",
        "frame-caltrans-night-fog.jpg",
        "frame-nevada.jpg",
        "frame-nevada-intersection.jpg",
    ])
    func acceptsRealFrames(name: String) throws {
        #expect(!PlaceholderDetector.standard.isPlaceholder(try fixture(name)))
    }

    @Test func ignoresUndecodableData() {
        #expect(!PlaceholderDetector.standard.isPlaceholder(Data("<html>500</html>".utf8)))
    }
}
