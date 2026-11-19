import Testing
@testable import CamCore

struct ViewDirectionTests {
    @Test(arguments: [
        ("SR-20 : West Of US-101 - Looking West (C007)", 270.0),
        ("US-101: Scotia (Looking North)ward", 0),
        ("SR-255-8.465: H St, Looking NW", 315),
        ("TA31E -- SR-84 : AT VALLECITOS RD EAST VIEW", 90),
        ("T256S -- I-80 : Buchanan Street Offramp South View", 180),
        ("T029N -- SR-82 : Page Mill Road / Oregon Expressway", 0),
        ("T093W -- US-101 : N101 Broadway On Off Ramp Westview", 270),
        ("SR-299: Lord Ellis - East", 90),
        ("US-101: Eureka / McCullen (PTZ) - North", 0),
        ("US-101: Hilfiker (S)", 180),
    ] as [(String, Double)])
    func readsViewFromName(name: String, bearing: Double) {
        #expect(ViewDirection.bearing(fromName: name) == bearing)
    }

    @Test(arguments: [
        "TV709 -- SR-238 : South of Ashland Avenue",   // a location, not a view
        "SR-1 : (827) SB PCH at Sea Cliff/3rd Ave",    // travel lanes, not a view
        "I-10 : (101) Mcclure West",
        "I-5 : Valley View",
        "Hwy 99 at Skyway 1",
        "I-80 : (C001) Truckee",
    ])
    func ignoresNamesWithoutAView(name: String) {
        #expect(ViewDirection.bearing(fromName: name) == nil)
    }
}
