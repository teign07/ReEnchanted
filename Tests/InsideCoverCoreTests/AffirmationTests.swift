import XCTest
@testable import InsideCoverCore

final class AffirmationTests: XCTestCase {
    func testOnlyRichBelievingsAdapterServesAffirmations() {
        let adapters = BookPageSourceAdapters.active.filter {
            $0.servedSourceIDs.contains("affirmations-page")
        }

        XCTAssertEqual(adapters.count, 1)
        XCTAssertTrue(adapters[0] is AffirmationsPageSourceAdapter)
    }

    func testBelievingsContainGiftsAndHonestlyHedgeablePacts() {
        let entries = AffirmationLibraryRegistry.allAffirmations
        let gifts = entries.filter { !$0.isPact }
        let pacts = entries.filter(\.isPact)

        XCTAssertFalse(gifts.isEmpty)
        XCTAssertFalse(pacts.isEmpty)
        XCTAssertTrue(entries.allSatisfy { !$0.countersigns.isEmpty })
        XCTAssertTrue(pacts.allSatisfy { pact in
            pact.countersigns.contains { countersign in
                let normalized = countersign.lowercased()
                return normalized.contains("might")
                    || normalized.contains("try")
                    || normalized.contains("maybe")
                    || normalized.contains("we'll see")
                    || normalized.contains("not today")
                    || normalized.contains("if i")
            }
        })
    }

    func testHardDayAlwaysReceivesGiftRatherThanPact() {
        let day = BookDay(
            id: "hard-day",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            pages: []
        )

        for offset in 0..<24 {
            let entry = AffirmationLibraryRegistry.affirmation(
                for: day,
                now: day.date.addingTimeInterval(Double(offset) * 3_600),
                tags: ["hard-day", "rest", "gentle"]
            )
            XCTAssertFalse(entry.isPact, "\(entry.id) turned a hard day into homework")
        }
    }

    func testManualBelievingCarriesKeepableResponseMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let surface = try XCTUnwrap(BookPageSourceAdapters.manualSurface(
            for: .affirmations,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: BookSourceInputs(),
            now: now
        ))

        XCTAssertEqual(surface.type, .affirmations)
        XCTAssertEqual(surface.renderStyle, .promptCard)
        XCTAssertNotNil(surface.payload.metadata["affirmationID"])
        XCTAssertNotNil(surface.payload.metadata["affirmationKind"])
        XCTAssertFalse(surface.payload.metadata["countersigns", default: ""].isEmpty)
        XCTAssertFalse(surface.payload.metadata["placeholder", default: ""].isEmpty)
    }
}

extension AffirmationTests {
    /// The Book contracts everything it says. A believing is the Book's own
    /// sentence, so an uncontracted "you are" or "I will" is a voice bug.
    func testEveryBelievingIsContractedAndFreeOfTheOldAiShapes() {
        let uncontracted = [
            "you are ", "you have ", "i am ", "i will ", "it is ", "it does not", "does not ",
            "do not ", "is not ", "are not ", "i have ", "that is ", "there is "
        ]
        let banned = ["hinge", "ritual", "not a ", "rather than", "journey", "sacred"]
        for entry in AffirmationLibraryRegistry.allAffirmations {
            let lines = [entry.text, entry.aside]
            for line in lines {
                let lowered = " " + line.lowercased() + " "
                for phrase in uncontracted where lowered.contains(phrase) {
                    XCTFail("\(entry.id): uncontracted “\(phrase.trimmingCharacters(in: .whitespaces))” in \(line)")
                }
                for phrase in banned where lowered.contains(phrase) {
                    XCTFail("\(entry.id): \(phrase) in \(line)")
                }
            }
        }
    }

    func testTheHiddenMagicShelfExistsAndSurvivesAHardDay() {
        let hidden = AffirmationLibraryRegistry.allAffirmations.filter { $0.theme == "Hidden Things" }
        XCTAssertGreaterThanOrEqual(hidden.count, 8)
        XCTAssertTrue(hidden.allSatisfy { !$0.isPact }, "Hidden Things are gifts: nothing owed")
    }
}

/// The shelf is the Book's beliefs told with childlike honesty: no smoothing,
/// no wit performed at an adult, no claim it can't back.
extension AffirmationTests {
    private var shelfLines: [(id: String, line: String)] {
        AffirmationLibraryRegistry.allAffirmations.flatMap { entry in
            [entry.text, entry.aside, entry.callIn].compactMap { $0 }.map { (entry.id, $0) }
        }
    }

    func testTheShelfDoesNoSocialWork() {
        let banned = [
            "—", ", which", "(", " like a ", "seems to", "teeth", "heavy lifting", "credit for",
            "deserve", "be gentle", "it's okay", "that's okay", "permission", "you're enough",
            "self-care", "proud of you", "you've got this"
        ]
        for (id, line) in shelfLines {
            let lowered = " " + line.lowercased() + " "
            for phrase in banned where lowered.contains(phrase) {
                XCTFail("\(id): “\(phrase)” in \(line)")
            }
        }
    }

    /// A believing that turns up everywhere stops being believed.
    func testNoTicRepeatsAcrossTheShelf() {
        let limits = ["i checked": 1, "up to something": 1, "this bet": 1, "never lose": 1, "pencil": 2]
        for (phrase, limit) in limits {
            let count = shelfLines.filter { $0.line.lowercased().contains(phrase) }.count
            XCTAssertLessThanOrEqual(count, limit, "“\(phrase)” is on \(count) lines")
        }
    }

    func testCallInsAreContracted() {
        let uncontracted = ["you are ", "you have ", "i am ", "i will ", "it is ", "does not ", "do not ", "is not ", "i have ", "that is ", "there is ", "did not "]
        for entry in AffirmationLibraryRegistry.allAffirmations {
            guard let line = entry.callIn else { continue }
            let lowered = " " + line.lowercased() + " "
            for phrase in uncontracted where lowered.contains(phrase) {
                XCTFail("\(entry.id): uncontracted “\(phrase)” in \(line)")
            }
        }
    }

    func testEveryPactCarriesTheBooksHalfAndComesBack() {
        for entry in AffirmationLibraryRegistry.allAffirmations {
            if entry.isPact {
                XCTAssertTrue(entry.aside.hasPrefix("And I'll"), "\(entry.id): the Book's half should read as its side of the pact")
                XCTAssertFalse(entry.callIn?.isEmpty ?? true, "\(entry.id) promised a half and never comes back")
                XCTAssertTrue(entry.callIn?.contains("?") ?? false, "\(entry.id): a call-in asks after the reader's half")
            } else {
                XCTAssertNil(entry.callIn, "\(entry.id) is a gift: nothing comes back for it")
            }
        }
    }
}

// MARK: - Called-in pacts

extension AffirmationTests {
    private func keptPact(
        _ id: String = "green-thing",
        signed signature: String = "I'll find it.",
        keptAt: Date,
        promisedHalf: Bool = true
    ) -> BookPage {
        let entry = AffirmationLibraryRegistry.affirmation(id: id)!
        var metadata = ["affirmationID": id, "affirmationKind": "pact"]
        if promisedHalf { metadata[PactCallIn.bookHalfKey] = entry.aside }
        return BookPage(
            id: "kept-\(id)",
            type: .affirmations,
            createdAt: keptAt,
            promptText: entry.text,
            userInput: signature,
            playerReply: signature,
            metadata: metadata
        )
    }

    private func day(holding pages: [BookPage], on date: Date) -> BookDay {
        BookDay(id: BookDay.id(for: date), date: date, pages: pages)
    }

    private func believings(now: Date, days: [BookDay], history: [String: SurfaceHistoryRecord] = [:], today: BookDay? = nil) -> [SurfacePage] {
        var inputs = BookSourceInputs()
        inputs.days = days
        inputs.surfaceHistory = history
        let today = today ?? day(holding: [], on: now)
        return AffirmationsPageSourceAdapter().candidates(
            for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now
        )
    }

    private var keptAt: Date { Date(timeIntervalSince1970: 1_790_000_000) }

    func testASignedPactIsCalledInWithTheReadersWords() throws {
        let pact = keptPact(keptAt: keptAt)
        let surfaces = believings(now: keptAt.addingTimeInterval(3 * 86_400), days: [day(holding: [pact], on: keptAt)])
        let callIn = try XCTUnwrap(surfaces.first)
        let entry = AffirmationLibraryRegistry.affirmation(id: "green-thing")!

        XCTAssertEqual(callIn.payload.metadata[PactCallIn.pageIDKey], pact.id)
        XCTAssertEqual(callIn.payload.metadata["affirmationKind"], "callIn")
        XCTAssertEqual(callIn.prompt, entry.callIn)
        XCTAssertEqual(callIn.detail, "In my margin you wrote “I'll find it.”")
        XCTAssertEqual(callIn.payload.metadata["countersigns"], PactCallIn.answers.joined(separator: "||"))
        XCTAssertTrue(callIn.curatorServedHistoryKeys.contains(PactCallIn.historyKey(for: pact.id)))
        XCTAssertGreaterThan(callIn.score, surfaces.dropFirst().map(\.score).max() ?? 0)
    }

    func testAPactWaitsTwoDaysAndGoesStaleAfterAFortnight() {
        let days = [day(holding: [keptPact(keptAt: keptAt)], on: keptAt)]
        let tooSoon = believings(now: keptAt.addingTimeInterval(86_400), days: days)
        let tooLate = believings(now: keptAt.addingTimeInterval(15 * 86_400), days: days)
        XCTAssertFalse(tooSoon.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil })
        XCTAssertFalse(tooLate.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil })
    }

    func testRefusedUnsignedAndOldPactsStayDown() {
        let now = keptAt.addingTimeInterval(3 * 86_400)
        for pact in [
            keptPact("one-inch", signed: "Not today.", keptAt: keptAt),
            keptPact(signed: "  ", keptAt: keptAt),
            keptPact(keptAt: keptAt, promisedHalf: false)
        ] {
            let surfaces = believings(now: now, days: [day(holding: [pact], on: keptAt)])
            XCTAssertFalse(surfaces.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil }, "\(pact.playerReply) was called in")
        }
    }

    func testAnAnsweredOrTwiceAskedPactIsLetGo() {
        let pact = keptPact(keptAt: keptAt)
        let now = keptAt.addingTimeInterval(4 * 86_400)
        let answer = BookPage(
            id: "answer", type: .affirmations, createdAt: keptAt.addingTimeInterval(3 * 86_400),
            promptText: "", playerReply: "I did.", metadata: [PactCallIn.pageIDKey: pact.id]
        )
        let answered = believings(now: now, days: [day(holding: [pact], on: keptAt), day(holding: [answer], on: answer.createdAt)])
        XCTAssertFalse(answered.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil })

        let asked = [PactCallIn.historyKey(for: pact.id): SurfaceHistoryRecord(lastShownAt: keptAt, recentShowCount: 2)]
        let twice = believings(now: now, days: [day(holding: [pact], on: keptAt)], history: asked)
        XCTAssertFalse(twice.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil })

        let restingKey = [PactCallIn.historyKey(for: pact.id): SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3_600), recentShowCount: 1)]
        let resting = believings(now: now, days: [day(holding: [pact], on: keptAt)], history: restingKey)
        XCTAssertFalse(resting.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil })
    }

    func testAHeavyDayIsNeverAskedAboutItsPact() {
        let now = keptAt.addingTimeInterval(3 * 86_400)
        let hard = BookPage(type: .diary, createdAt: now.addingTimeInterval(-600), promptText: "", userInput: "a hard one", tags: ["distress"])
        let today = day(holding: [hard], on: now)
        let surfaces = believings(now: now, days: [day(holding: [keptPact(keptAt: keptAt)], on: keptAt)], today: today)
        XCTAssertFalse(surfaces.contains { $0.payload.metadata[PactCallIn.pageIDKey] != nil })
    }

    func testAKeptPactCarriesTheBooksHalf() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let surfaces = AffirmationsPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: BookSourceInputs(), now: now
        )
        for surface in surfaces {
            let isPact = surface.payload.metadata["affirmationKind"] == "pact"
            XCTAssertEqual(surface.payload.metadata[PactCallIn.bookHalfKey] != nil, isPact)
        }
    }
}

extension AffirmationTests {
    /// Gifts come with no strings. A gift whose line or aside reads as an
    /// instruction spends the desk's ask budget and isn't a gift.
    func testNoGiftAsksTheReaderForAnything() {
        for entry in AffirmationLibraryRegistry.allAffirmations where !entry.isPact {
            let surface = SurfacePage(
                id: entry.id, type: .affirmations, sourceID: "affirmations-page", intent: .reflect,
                renderStyle: .promptCard, score: 60, reason: "", prompt: entry.text, detail: entry.aside,
                payload: BookPagePayload(headline: entry.theme, body: entry.text, metadata: ["affirmationID": entry.id, "affirmationKind": "gift"])
            )
            XCTAssertFalse(surface.isReaderFacingAsk, "\(entry.id) reads as an ask: \(entry.text) / \(entry.aside)")
        }
    }
}
