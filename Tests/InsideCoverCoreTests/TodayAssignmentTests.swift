import XCTest
@testable import InsideCoverCore

final class TodayAssignmentTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/New_York")!
        return result
    }

    private func date(_ day: Int, _ hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func day(_ number: Int) -> BookDay {
        BookDay(id: BookDay.id(for: date(number), calendar: calendar), date: calendar.startOfDay(for: date(number)), pages: [])
    }

    private var places: [LocalPlaceSignal] {
        [LocalPlaceSignal(id: "bakery", name: "Morning Crumb", category: "bakery", distanceLabel: "1 km", locality: "Riverside"),
         LocalPlaceSignal(id: "library", name: "River Library", category: "library", distanceLabel: "2 km", locality: "Riverside")]
    }

    private func record(page: SurfacePage, day: BookDay) -> BleedPrintRecord {
        .init(slotID: "bleed-\(day.id)-morning", printedAt: day.date, items: [
            .init(storyID: "assignment:\(BleedDayDesk.assignmentDetails(page).id):\(day.id)",
                  revision: "one", title: "Your Assignment", body: "Printed", sourcePageIDs: [], assignmentPage: page)
        ])
    }

    func testAllThreeFamiliesReachTodayAndThePaper() throws {
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = places
        var families = Set<String>()
        for number in 10...18 {
            let today = day(number)
            let assignment = try XCTUnwrap(BookTodayDoorstep.assignment(day: today, inputs: inputs, now: date(number), calendar: calendar))
            let page = try XCTUnwrap(assignment.page)
            let brief = try XCTUnwrap(BleedDayDesk.assignment(kind: .morning, day: today, inputs: inputs, now: date(number), calendar: calendar))
            XCTAssertEqual(brief.assignmentPage, page)
            XCTAssertEqual(assignment.challenge, BleedDayDesk.assignmentDetails(page).challenge)
            if page.type == .elective {
                families.insert("elective")
                XCTAssertEqual(page.payload.metadata["electivePrepared"], "true")
                XCTAssertFalse(SurfaceReadinessState(surface: page).needsLocalBrainToOpen)
                XCTAssertTrue(places.contains { assignment.challenge.contains($0.name) })
            } else if page.payload.metadata["playfulMissionID"] != nil {
                families.insert("mission")
            } else if page.type == .wickerDare {
                families.insert("dare")
            }
        }
        XCTAssertEqual(families, ["dare", "mission", "elective"])
    }

    func testUnprintedAssignmentIsAvailableAndStableInTheAfternoon() throws {
        let today = day(16)
        let morning = try XCTUnwrap(BookTodayDoorstep.assignment(day: today, inputs: .empty, now: date(16), calendar: calendar))
        let afternoon = try XCTUnwrap(BookTodayDoorstep.assignment(day: today, inputs: .empty, now: date(16, 16), calendar: calendar))
        XCTAssertEqual(morning.page, afternoon.page)
        XCTAssertEqual(morning.challenge, afternoon.challenge)
    }

    func testPrintedPageSurvivesChangedPlacesAndPrintRecordRoundTrip() throws {
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = places
        let today = day(16)
        let page = try XCTUnwrap(ElectivePageSourceAdapter().assignmentSurface(for: today, inputs: inputs, now: date(16)))
        let remembered = try XCTUnwrap(BleedPrintRecord.decode(record(page: page, day: today).encoded))
        inputs.bleedPrintHistory = [remembered.pressMemory]
        inputs.nearbyPlaces = []
        let projected = try XCTUnwrap(BookTodayDoorstep.assignment(day: today, inputs: inputs, now: date(16, 18), calendar: calendar))
        XCTAssertEqual(projected.page, page)
        XCTAssertEqual(projected.challenge, page.payload.metadata["electiveAsk"])
    }

    func testOldPrintedWickerAssignmentStillOpens() throws {
        let today = day(16)
        let dare = try XCTUnwrap(WickerDareRegistry.immediate.first)
        var inputs = BookSourceInputs.empty
        inputs.bleedPrintHistory = [.init(slotID: "old-paper", printedAt: date(16), items: [
            .init(storyID: "assignment:\(dare.id):\(today.id)", revision: "old", title: "Your Assignment", body: dare.challenge, sourcePageIDs: [])
        ])]
        let page = BleedDayDesk.dailyAssignmentPage(day: today, inputs: inputs, now: date(16, 16), calendar: calendar)
        XCTAssertEqual(page.payload.metadata["wickerDareID"], dare.id)
    }

    func testPendingBookFavorDoesNotExcludeLocalCastOffers() throws {
        let today = day(16)
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = places
        inputs.bookInterior = BookInteriorState(awakenedAt: date(15), activeFavor: BookFavor(
            id: "book-favor", facet: .notice, title: "Three Things", ask: "Find three things.",
            whyItMayHelp: "A small experiment.", practiceShape: "Three details.", createdAt: date(15),
            status: .offered, acceptedAt: nil, completedAt: nil, evidencePageIDs: []))
        let pages = ElectivePageSourceAdapter().candidates(for: today, context: .make(for: today), inputs: inputs, now: date(16, 12))
        XCTAssertTrue(pages.contains { $0.payload.metadata["bookFavorOffer"] == "true" })
        let cast = try XCTUnwrap(pages.first { $0.payload.metadata["electiveOffer"] == "true" && $0.payload.metadata["bookFavorOffer"] != "true" })
        XCTAssertFalse(SurfaceReadinessState(surface: cast).needsLocalBrainToOpen)
        XCTAssertTrue(places.contains { cast.payload.metadata["electiveAsk"]?.contains($0.name) == true })
    }

    func testAcceptedNoteOpensTheFlyleafForProof() throws {
        let today = day(16)
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = places
        let offer = try XCTUnwrap(ElectivePageSourceAdapter().assignmentSurface(for: today, inputs: inputs, now: date(16)))
        inputs.electives = [.init(id: "accepted", characterID: offer.payload.metadata["senderID"]!,
            characterName: offer.payload.metadata["senderName"]!, title: offer.payload.metadata["electiveTitle"]!,
            ask: offer.payload.metadata["electiveAsk"]!, whyItMatters: "A study.", practiceShape: "One photo.",
            createdAt: date(16), completedAt: nil, proof: nil)]
        let opened = BleedDayDesk.openingAssignmentPage(offer, day: today, inputs: inputs, now: date(16, 16))
        XCTAssertEqual(opened.payload.metadata["electiveFlyleaf"], "true")
        XCTAssertNil(opened.payload.metadata["electiveOffer"])
        XCTAssertTrue(opened.payload.body.contains(inputs.electives[0].ask))
    }

    func testOrdinaryCastNotesRetainTheCharacterWriterWhenReady() throws {
        let today = day(16)
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = places
        inputs.localBrainIsReady = true
        let pages = ElectivePageSourceAdapter().candidates(for: today, context: .make(for: today), inputs: inputs, now: date(16, 12))
        let cast = try XCTUnwrap(pages.first { $0.payload.metadata["electiveOffer"] == "true" })
        XCTAssertNil(cast.payload.metadata["electivePrepared"])
        XCTAssertTrue(SurfaceReadinessState(surface: cast).needsLocalBrainToOpen)
        XCTAssertTrue(cast.payload.metadata["nearbyPlaces"]?.contains("Morning Crumb") == true)
    }

    func testEachFamilyCanFileProofAndReachTheEveningPaper() throws {
        for kind in [LivedQuestKind.wickerDare, .playfulMission, .elective] {
            var today = day(16)
            var page = BookPage(id: "proof", type: kind == .elective ? .elective : kind == .wickerDare ? .wickerDare : .wonderCompass,
                               createdAt: date(16, 15), promptText: "A visit", userInput: "A robin sat on the library sign.")
            page.livedQuestReceipt = .init(kind: kind, questID: "visit", title: "The Library Visit", invitation: "Visit the library.",
                proofPrompt: "One detail.", facets: [], sourceTags: [], hasWrittenProof: true, hasVisualProof: false,
                completedAt: date(16, 15), wasPromptedByBook: true)
            today.pages = [page]
            let assignment = try XCTUnwrap(BookTodayDoorstep.assignment(day: today, inputs: .empty, now: date(16, 16), calendar: calendar))
            XCTAssertTrue(assignment.filed)
            XCTAssertEqual(assignment.title, "The Library Visit")
            let front = try XCTUnwrap(BleedDayDesk.frontPage(kind: .evening, day: today, inputs: .empty, now: date(16, 18), calendar: calendar))
            XCTAssertEqual(front.title, "Assignment Complete: The Library Visit")
        }
    }

    func testOfflineLocalStudyFollowsTheSendersInterest() {
        func offer(_ interest: String) -> ElectiveOfferDraft {
            ElectiveOfferFallback.offer(surface: SurfacePage(id: "offer", type: .elective, sourceID: "unwritten-elective",
                intent: .capture, renderStyle: .loreLetter, score: 70, reason: "", prompt: "", detail: "",
                payload: .init(headline: "Quest", body: "", metadata: ["senderName": "A friend", "senderInterest": interest,
                    "nearbyPlaces": places.map(\.promptLine).joined(separator: "\n")])))
        }
        let food = offer("Flavours he has only ever read about, recipes, and food.")
        let words = offer("Zines, hand-lettered shop signs, and stories.")
        XCTAssertTrue(food.ask.contains("Morning Crumb"))
        XCTAssertTrue(food.ask.contains("smell"))
        XCTAssertTrue(words.ask.contains("River Library"))
        XCTAssertTrue(words.ask.contains("lettering"))
        XCTAssertNotEqual(food.ask, words.ask)
    }

    func testUnrelatedProofDoesNotFileThePrintedAssignment() throws {
        var today = day(16)
        let assignment = BleedDayDesk.dailyAssignmentPage(day: today, inputs: .empty, now: date(16), calendar: calendar)
        var inputs = BookSourceInputs.empty
        inputs.bleedPrintHistory = [record(page: assignment, day: today)]
        var unrelated = BookPage(id: "other-proof", type: .wickerDare, createdAt: date(16, 15),
                                 promptText: "Another dare", userInput: "The pigeon blinked first.")
        unrelated.livedQuestReceipt = .init(kind: .wickerDare, questID: "unrelated-to-the-paper", title: "Another Dare",
            invitation: "Another invitation.", proofPrompt: "One detail.", facets: [], sourceTags: [],
            hasWrittenProof: true, hasVisualProof: false, completedAt: date(16, 15), wasPromptedByBook: true)
        today.pages = [unrelated]
        let projected = try XCTUnwrap(BookTodayDoorstep.assignment(day: today, inputs: inputs, now: date(16, 16), calendar: calendar))
        XCTAssertFalse(projected.filed)
        XCTAssertEqual(projected.page, assignment)
    }

    func testHardDayStillSuppressesEveryAssignmentFamily() {
        var today = day(16)
        today.pages = [BookPage(id: "hard", type: .souvenir, createdAt: date(16), promptText: "Today",
                               userInput: "I can't do this any more. The kitchen is a mess and so am I.")]
        XCTAssertTrue(DistressSignals.evaluate(day: today).isActive)
        XCTAssertNil(BookTodayDoorstep.assignment(day: today, inputs: .empty, now: date(16, 12), calendar: calendar))
        XCTAssertNil(BleedDayDesk.assignment(kind: .morning, day: today, inputs: .empty, now: date(16), calendar: calendar))
    }

    func testFullFlyleafReturnsAcceptedWorkInsteadOfAnotherOffer() throws {
        let today = day(16)
        var inputs = BookSourceInputs.empty
        inputs.electives = (0..<UnwrittenElective.maxActive).map { index in
            UnwrittenElective(id: "quest-\(index)", characterID: "sender-\(index)", characterName: "A friend",
                title: "Accepted \(index)", ask: "Bring one real detail.", whyItMatters: "A study.",
                practiceShape: "One sentence.", createdAt: date(15), completedAt: nil, proof: nil)
        }
        let page = try XCTUnwrap(ElectivePageSourceAdapter().assignmentSurface(for: today, inputs: inputs, now: date(16)))
        XCTAssertEqual(page.payload.metadata["electiveFlyleaf"], "true")
        XCTAssertNil(page.payload.metadata["electiveOffer"])
        XCTAssertNotNil(page.payload.metadata["electiveID"])
    }
}
