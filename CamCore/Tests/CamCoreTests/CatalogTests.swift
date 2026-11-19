import Foundation
import Testing
@testable import CamCore

struct CatalogTests {
    @Test(arguments: [
        ("TV316 -- I-80 : 6th Street", "I-80 · 6th Street"),
        ("I-110 : (196) Avenue 26 Off Ramp", "I-110 · Avenue 26 Off Ramp"),
        ("(C526) I-125: SB JNO Blossom Ln - T", "I-125 · SB JNO Blossom Ln - T"),
        ("90 - EB SR-152 Dinosaur Point", "EB SR-152 Dinosaur Point"),
        ("I80 @ East Verdi", "I80 @ East Verdi"),
    ])
    func displayNameDropsOperatorCodes(name: String, expected: String) {
        let camera = Camera(id: "x", source: "test", name: name, lat: 0, lon: 0)
        #expect(camera.displayName == expected)
    }

    @Test func decodesBuilderOutput() throws {
        let json = """
        {"version":1,"generatedAt":"2026-11-18T00:00:00+00:00",
         "sources":[{"id":"nevada","name":"Nevada DOT","attribution":"Courtesy of NDOT","infoURL":"https://www.nvroads.com/"}],
         "cameras":[{"id":"nv-2","source":"nevada","name":"McCarran & Lakeside","place":null,"lat":39.48,"lon":-119.85,
                     "road":"McCarran & Lakeside","direction":null,"snapshotURL":"https://www.nvroads.com/map/Cctv/2",
                     "snapshotRefreshSeconds":60,"hlsURL":null}]}
        """
        let catalog = try CameraCatalog.decode(from: Data(json.utf8))
        #expect(catalog.cameras.count == 1)
        #expect(catalog.source(for: catalog.cameras[0])?.attribution == "Courtesy of NDOT")
        #expect(catalog.cameras[0].hlsURL == nil)
    }

    @Test func rejectsOtherSchemaVersions() {
        let json = #"{"version":2,"builtAt":"2027-01-01T00:00:00+00:00","cameras":[]}"#
        #expect(throws: CameraCatalog.DecodeError.unsupportedVersion(2)) {
            try CameraCatalog.decode(from: Data(json.utf8))
        }
    }

    @Test func comparesBuildTimes() {
        let older = catalog(generatedAt: "2026-11-18T23:00:00+00:00")
        let newer = catalog(generatedAt: "2026-11-19T01:15:07+00:00")
        let unparseable = catalog(generatedAt: "yesterday")
        #expect(newer.isNewer(than: older))
        #expect(!older.isNewer(than: newer))
        #expect(!newer.isNewer(than: newer))
        #expect(older.isNewer(than: unparseable))
        #expect(!unparseable.isNewer(than: older))
    }

    private func catalog(generatedAt: String) -> CameraCatalog {
        CameraCatalog(version: CameraCatalog.schemaVersion, generatedAt: generatedAt, sources: [], cameras: [])
    }
}
