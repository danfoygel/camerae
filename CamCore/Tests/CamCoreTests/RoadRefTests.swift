import Testing
@testable import CamCore

struct RoadRefTests {
    @Test(arguments: [
        ("I-80", [RoadRef(.interstate, 80)]),
        ("I80 WINNEMUCCA MM180 HU17", [RoadRef(.interstate, 80)]),
        ("US50 @ Warrior Way", [RoadRef(.us, 50)]),
        ("I-11 SB & I-15", [RoadRef(.interstate, 11), RoadRef(.interstate, 15)]),
        ("Hwy 50 at Sunrise Blvd EO WB 3", [RoadRef(.unknown, 50)]),
        ("215 WB Decatur Off", [RoadRef(.unknown, 215)]),
        ("Merge onto CA-99 N", [RoadRef(.state, 99)]),
        ("Keep left to stay on US-395 S", [RoadRef(.us, 395)]),
        ("SR-28", [RoadRef(.state, 28)]),
        ("McCarran & Lakeside", []),
        ("I-110 : (196) Avenue 26 Off Ramp", [RoadRef(.interstate, 110)]),
    ])
    func parsesFeedAndInstructionSpellings(text: String, expected: [RoadRef]) {
        #expect(RoadRef.parse(text) == Set(expected))
    }

    @Test func dropsDestinationRoads() {
        #expect(RoadRef.parseTraveledRoads(fromInstruction: "Merge onto I-580 E toward I-80") == [RoadRef(.interstate, 580)])
        #expect(RoadRef.parseTraveledRoads(fromInstruction: "Keep left on Hollywood Fwy toward I-10 East, I-5 South").isEmpty)
    }

    @Test func unknownKindMatchesAnyHighwayWithSameNumber() {
        #expect(RoadRef(.unknown, 50).matches(RoadRef(.us, 50)))
        #expect(!RoadRef(.interstate, 50).matches(RoadRef(.us, 50)))
        #expect(!RoadRef(.unknown, 50).matches(RoadRef(.us, 51)))
    }
}
