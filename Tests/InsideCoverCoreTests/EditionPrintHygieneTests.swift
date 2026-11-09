import XCTest
@testable import InsideCoverCore

/// What October 2026's bound month printed that it never should have.
final class EditionPrintHygieneTests: XCTestCase {
    private let compassRun = """
    Wonder Compass Run
    Location: home
    Place Kind: Home
    Time Limit: 1-10 minutes
    Energy: 35% low
    Who is with me: solo unless the user says otherwise
    Budget: Use what is already available.
    Special Needs/Considerations: indoors only, quiet

    NORTH (NOTICE)
    I wonder where my tired energy can find its first steady spark?

    EAST (EMBARK)
    Destination: the window over the sink
    Delight: the light on the tap
    Definition: a destination is somewhere small

    SOUTH (SENSE)
    Touch the cold glass for five seconds.

    WEST (WRITE)
    What did the glass feel like?

    CENTER (REST)
    Sit down after.
    """

    func testMachineTextIsRecognised() {
        XCTAssertTrue(PrintHygiene.isMachineText("Tags: Time 7:31 PM · Location Belfast · Weather overcast · Moon Last Quarter"))
        XCTAssertTrue(PrintHygiene.isMachineText(compassRun))
        XCTAssertTrue(PrintHygiene.isMachineText("Enchantment: Everything's a Haiku\nSubject: Weather"))
        XCTAssertTrue(PrintHygiene.isMachineText("The Labyrinth keeps pulling you toward: penny-blackletter|user-cast-quill-ombra-505."))
        XCTAssertFalse(PrintHygiene.isMachineText("My Stella with lemon is going to make the next hour kinder."))
        XCTAssertFalse(PrintHygiene.isMachineText("Subject to change, like everything on a Tuesday, the sky went pink and then it didn't."))
    }

    func testCompassRunPrintsItsDirectionsNotItsForm() throws {
        let card = try XCTUnwrap(PrintHygiene.compassRunCard(compassRun))
        XCTAssertTrue(card.hasPrefix("North · I wonder where my tired energy can find its first steady spark?"))
        XCTAssertTrue(card.contains("East · the window over the sink · the light on the tap"))
        XCTAssertFalse(card.contains("Energy"))
        XCTAssertFalse(card.contains("35%"))
        XCTAssertFalse(card.contains("user says otherwise"))
        XCTAssertFalse(card.contains("Definition"))
        XCTAssertNil(PrintHygiene.compassRunCard("I went for a walk."))
    }

    func testScrubbedProseDropsLabelsAndAppDirectionsButKeepsTheRest() {
        let braid = """
        Somebody is playing a slow tune on a harpsichord in a room that isn't on the map.

        Subject: Blue Bottle Everything's Connected The blue bottle is framed centrally under soft light. Trace the threads tied to this container: 1.

        The pocket in my back cover is getting heavy. It was 3:15.
        """
        let scrubbed = PrintHygiene.scrubbedProse(braid)
        XCTAssertFalse(scrubbed.contains("Subject:"))
        XCTAssertFalse(scrubbed.contains("container: 1."))
        XCTAssertTrue(scrubbed.contains("harpsichord"))
        XCTAssertTrue(scrubbed.contains("It was 3:15."))

        let scene = "Give me one sentence from this visit.\n\nNo first sentence yet? Keep one through Capture. Go back to its thing later. I'll wait here."
        let set = PrintHygiene.scrubbedProse(scene)
        XCTAssertFalse(set.contains("Capture"))
        XCTAssertTrue(set.contains("I'll wait here."))

        let haiku = "Gray sky drips its tears,\nCold air finds the skin,\nSunlight fades from the clouds."
        XCTAssertEqual(PrintHygiene.scrubbedProse(haiku), haiku)
    }

    func testStoryTurnMarkerNeverReachesPaper() {
        let leaf = "Turn 1\n\nThe air tasted of bruised lavender and old parchment.\n\nChosen path: Supper with a Finished Man"
        let set = PrintHygiene.scrubbedProse(leaf)
        XCTAssertFalse(set.contains("Turn 1"))
        XCTAssertTrue(set.hasPrefix("The air tasted"))
        XCTAssertTrue(set.contains("Chosen path: Supper with a Finished Man"))
        XCTAssertTrue(PrintHygiene.isTurnMarker("“Turn 12"))
        // A sentence that only starts with the word stays.
        XCTAssertFalse(PrintHygiene.isTurnMarker("Turn 1 corner and you're there."))
        XCTAssertEqual(PrintHygiene.scrubbedProse("Turn left at the boot."), "Turn left at the boot.")
    }

    func testStoryScaffoldIsRecognised() {
        XCTAssertTrue(PrintHygiene.isStoryScaffold("The corrected delivery moves Misdelivered Object one visible step."))
        XCTAssertFalse(PrintHygiene.isStoryScaffold("The door is left unopened tonight, and approves of the restraint."))
    }

    func testBondsAreNamedNotPrintedAsIDs() {
        let name = ReadersSheet.bondName("penny-blackletter|user-cast-quill-ombra-505")
        XCTAssertFalse(name.contains("|"))
        XCTAssertFalse(name.contains("-"))
        XCTAssertTrue(name.hasSuffix("and Ombra"))
    }

    func testRepeatedKeepsFoldOntoTheirFirstDay() {
        let letter = "Reader—\n\nI went back to the Vault before breakfast."
        let bet = { (date: String, days: Int) in
            "I'm risking a guess. Adaptive used to appear often; it has been quiet for \(days) days.\n\nI sealed this in the margin on \(date):"
        }
        var days = [
            day("2026-10-15", keeps: [keep("l1", .letter, "A Letter from Permancer", letter), keep("b1", .castNote, "I Notice", bet("October 3, 2026", 32))]),
            day("2026-10-18", keeps: [keep("l2", .letter, "A Letter from Permancer", letter)]),
            day("2026-10-22", keeps: [keep("b2", .castNote, "I Notice", bet("October 22, 2026", 51))])
        ]
        BoundDayBookBuilder.foldRepeatedKeeps(in: &days)
        XCTAssertEqual(days[0].keeps.map(\.id), ["l1", "b1"])
        XCTAssertTrue(days[1].keeps.isEmpty)
        XCTAssertTrue(days[2].keeps.isEmpty)
        // Folded copies still count as printed, so the archive doesn't set them again.
        XCTAssertTrue(days[1].printedPageIDs.contains("l2"))
        XCTAssertTrue(days[2].printedPageIDs.contains("b2"))
    }

    func testALaterSceneDoesNotOpenOnTheReportItFollows() {
        let report = "Penny recorded the meeting in the old reading room. The Count wanted a future beyond his written ending."
        let scenes = [
            scene("a", body: report, isReport: true),
            scene("b", body: report + "\n\nThe East Stacks grow a tower overnight."),
            scene("c", body: "Morning finds Serenity in the Kitchens.")
        ]
        let stripped = BoundDayBookBuilder.strippingReportPrefaces(scenes)
        XCTAssertEqual(stripped[0].body, report)
        XCTAssertEqual(stripped[1].body, "The East Stacks grow a tower overnight.")
        XCTAssertEqual(stripped[2].body, "Morning finds Serenity in the Kitchens.")
    }

    // MARK: Fixtures

    private func keep(_ id: String, _ kind: BoundDayKeep.Kind, _ title: String, _ body: String) -> BoundDayKeep {
        BoundDayKeep(id: id, kind: kind, title: title, body: body)
    }

    private func scene(_ id: String, body: String, isReport: Bool = false) -> BoundDayScene {
        BoundDayScene(id: id, contentID: id, title: id, body: body, choiceLabel: nil, roomID: nil, roomName: nil,
                      castIDs: [], readAt: Date(timeIntervalSince1970: 0), isReport: isReport)
    }

    private func day(_ id: String, keeps: [BoundDayKeep]) -> BoundDay {
        BoundDay(
            id: id,
            date: Date(timeIntervalSince1970: 0),
            almanac: BoundDayAlmanac(moonName: "Full Moon", moonIlluminated: 1, moonAgeDays: 14, skyWords: [], feast: nil),
            scenes: [], clippings: [], castLines: [], braids: [], photos: [], words: [],
            keeps: keeps,
            specimens: []
        )
    }
}

final class EditionProseGateTests: XCTestCase {
    private let material = ["My Stella with lemon is going to make the next hour kinder.", "Hanging with Amanda on a Saturday morning, it's nice.", "Bright"]

    func testOctobersForewordAndClosingAreRefused() {
        let foreword = "October 2026 opens now. Sixteen pages for you. It's a long stretch. We're going deep into the Hour and Weather. I found the threads again. Dr. Vellum is just a thread now. Dr. Inkrest keeps surfacing. I ain't counting the times anymore."
        XCTAssertFalse(EditionProseGate.accepts(foreword, minimumWords: 40, material: material))
        let closing = "October 2026 closes now. The air feels thick, like the moment just before a storm breaks. I see the way the light catches the dust motes dancing in the afternoon sun."
        XCTAssertFalse(EditionProseGate.accepts(closing, minimumWords: 40, material: material))
    }

    func testAGroundedLeafIsKept() {
        let leaf = Array(repeating: "You wrote that your Stella with lemon would make the next hour kinder, and on a Saturday morning with Amanda it did.", count: 4).joined(separator: " ")
        XCTAssertTrue(EditionProseGate.accepts(leaf, minimumWords: 40, material: material))
        XCTAssertFalse(EditionProseGate.accepts(nil, minimumWords: 1, material: material))
    }
}

final class FacultyFictionTests: XCTestCase {
    func testTheDoctorsSayTheyreMadeUpWhereTheyReadHealthNotes() {
        XCTAssertTrue(FacultyFiction.applies(to: .inkrestOfficeHours, text: ""))
        XCTAssertTrue(FacultyFiction.applies(to: .supportGuild, text: ""))
        XCTAssertTrue(FacultyFiction.applies(to: .facultyResearch, text: "Dr. Vellum read your sleep notes."))
        XCTAssertFalse(FacultyFiction.applies(to: .facultyResearch, text: "Professor Permancer read your library notes."))
        XCTAssertFalse(FacultyFiction.applies(to: .souvenir, text: "Vellum"))
        XCTAssertTrue(FacultyFiction.short.contains("medical advice"))
        XCTAssertFalse(FacultyFiction.colophon.contains("the Book"))
    }
}
