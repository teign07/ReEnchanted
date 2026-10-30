import XCTest
@testable import InsideCoverCore

/// A scorer that answers from a fixed table keyed by document text.
private struct FixedNoticeScorer: StacksSemanticScoring {
    let modelID = "test.notice"
    var scores: [String: Double]
    func similarity(between query: String, and document: String) -> Double? { scores[document] }
}

/// The de-repetition laws for the reflective surfaces: Book Notices remembers
/// what it already said (spoken signals rest, returns are continuations, and
/// silence beats a rerun), and both Notices and Book Remembered vary their
/// scaffolding prose deterministically instead of rereading one template.
final class ReflectiveVarietyTests: XCTestCase {
    private let noticesAdapter = BookNoticesPageSourceAdapter()
    private let rememberedAdapter = BookRememberedPageSourceAdapter()

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 11))!

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    /// A BookDay whose id matches its pages' calendar day: `capturedPages`
    /// windows on the parsed id, so a mislabeled day hides its pages.
    private func day(pages: [BookPage]) -> BookDay {
        let anchor = pages.first?.createdAt ?? now
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: anchor)
        let id = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
        return BookDay(id: id, date: Calendar.current.startOfDay(for: anchor), pages: pages)
    }

    private func filler() -> [BookPage] {
        (0..<4).map { index in
            BookPage(
                id: "filler-\(index)", type: .souvenir, createdAt: daysAgo(10, hour: 8 + index),
                promptText: "Souvenir", userInput: "A steady kept line number \(index)."
            )
        }
    }

    private func signal(id: String, subject: String) -> LiteraryContinuitySignal {
        LiteraryContinuitySignal(
            id: id,
            kind: .pattern,
            subjectID: subject,
            subjectName: subject,
            line: "\(subject.capitalized) kept returning in the pages.",
            evidencePageIDs: ["evidence-1"],
            relatedEntityIDs: [],
            tags: [subject],
            firstSeenAt: daysAgo(30),
            lastSeenAt: daysAgo(2),
            strength: 70
        )
    }

    private func spokenNotice(ids: [String], at date: Date) -> BookPage {
        BookPage(
            id: "kept-notice-\(ids.joined(separator: "-"))", type: .bookNotices, createdAt: date,
            promptText: "The Book Notices", userInput: "",
            tags: ["book-notices"] + ids.map { "spoke:\($0)" }
        )
    }

    private func noticeInputs(signals: [LiteraryContinuitySignal], extraPages: [BookPage] = []) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pages: filler())] + extraPages.map { day(pages: [$0]) }
        inputs.continuity = LiteraryContinuityDigest(signals: signals, beliefLifecycles: [])
        return inputs
    }

    func testSemanticNoticePairingFindsWordDisjointFeelingMatch() throws {
        let scorer = FixedNoticeScorer(scores: ["The kettle sang twice and nobody came.": 0.8])
        let old = BookPage(
            id: "old", type: .souvenir, createdAt: now.addingTimeInterval(-40 * 86_400),
            promptText: "Souvenir", userInput: "The kettle sang twice and nobody came."
        )
        let anchor = BookPage(
            id: "anchor", type: .diary, createdAt: now.addingTimeInterval(-2 * 86_400),
            promptText: "Diary", userInput: "Something small waited all evening for my attention."
        )
        let pairing = try XCTUnwrap(SemanticNoticePairing.find(
            days: [day(pages: [old]), day(pages: [anchor])],
            scorer: scorer, now: now
        ))
        XCTAssertEqual(pairing.anchorPageID, "anchor")
        XCTAssertEqual(pairing.sourcePageID, "old")
        XCTAssertTrue(pairing.noticeParagraph.contains("without sharing one important word"), pairing.noticeParagraph)
    }

    func testConnectionNarrativeRejectsPromptTextAndGeneratedPagesAsPersonalEvidence() {
        let pages = [
            BookPage(
                id: "real-one", type: .souvenir, createdAt: daysAgo(30),
                promptText: "Harbor", userInput: "I watched the last boat settle against the harbor wall."
            ),
            BookPage(
                id: "generated-two", type: .narrativeOS, createdAt: daysAgo(16),
                promptText: "Harbor", userInput: "The harbor master folded the moon into a chart.", origin: .generated
            ),
            BookPage(
                id: "blank-three", type: .note, createdAt: daysAgo(2),
                promptText: "Write about the harbor", userInput: ""
            )
        ]
        let thread = LiteraryContinuitySignal(
            id: "pattern-harbor", kind: .pattern, subjectID: "harbor", subjectName: "Harbor",
            line: "Harbor kept returning through the kept pages.",
            evidencePageIDs: pages.map(\.id), relatedEntityIDs: [], tags: ["harbor"],
            firstSeenAt: pages[0].createdAt, lastSeenAt: pages[2].createdAt, strength: 80
        )
        var inputs = BookSourceInputs.empty
        inputs.days = pages.map { day(pages: [$0]) } + [day(pages: filler())]
        inputs.continuity = LiteraryContinuityDigest(signals: [thread], beliefLifecycles: [])
        let today = BookDay(id: "today", date: now, pages: [])

        let surfaces = noticesAdapter.candidates(
            for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now
        )
        XCTAssertFalse(surfaces.contains { $0.payload.metadata["connectionNarrative"] == "true" })
    }

    func testSemanticConnectionBecomesItsOwnNarrativeWithBothSourcePages() throws {
        let older = BookPage(
            id: "older-weather", type: .souvenir, createdAt: daysAgo(40),
            promptText: "Souvenir", userInput: "The ferry horn crossed the dark water and found no answer."
        )
        let newer = BookPage(
            id: "newer-weather", type: .diary, createdAt: daysAgo(2),
            promptText: "Diary", userInput: "A blue cup waited beside the cold window until morning."
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pages: [older]), day(pages: [newer]), day(pages: filler())]
        inputs.continuity = LiteraryContinuityDigest(
            signals: [signal(id: "sig-harbor", subject: "harbor"), signal(id: "sig-kettle", subject: "kettle")],
            beliefLifecycles: []
        )
        inputs.semanticNoticePairing = SemanticNoticePairing(
            anchorPageID: newer.id,
            anchorExcerpt: newer.userInput,
            sourcePageID: older.id,
            sourceExcerpt: older.userInput,
            monthLine: "back in June",
            similarity: 0.81
        )
        let today = BookDay(id: "today", date: now, pages: [])

        let surfaces = noticesAdapter.candidates(
            for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now
        )
        let connection = try XCTUnwrap(surfaces.first { $0.payload.metadata["connectionKind"] == "semantic" })

        XCTAssertEqual(connection.payload.headline, "The Thread Between")
        XCTAssertEqual(connection.payload.metadata["evidencePageIDs"], "older-weather,newer-weather")
        XCTAssertTrue(connection.payload.body.contains(older.userInput))
        XCTAssertTrue(connection.payload.body.contains(newer.userInput))
        XCTAssertTrue(connection.payload.body.contains("different words"), connection.payload.body)
        XCTAssertTrue(connection.payload.body.contains("saying something to each other"), connection.payload.body)
        XCTAssertTrue(
            (connection.payload.body.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last(where: { !$0.isEmpty }) ?? "").hasSuffix("?"),
            "A connection is offered as a question, never a verdict: \(connection.payload.body)"
        )
    }

    // MARK: - Returned From the Stacks is a daily ritual

    func testReturnedStacksBuildsThreeDistinctDailyRolesFromTheWholeArchive() throws {
        let oldPages = [
            BookPage(
                id: "lantern-old", type: .souvenir, createdAt: daysAgo(40),
                promptText: "Souvenir", userInput: "A paper lantern trembled over the wet pavement."
            ),
            BookPage(
                id: "long-memory", type: .plainPage, createdAt: daysAgo(300),
                promptText: "Plain Page", userInput: "The blue stair kept one square of winter light."
            ),
            BookPage(
                id: "letter-old", type: .letter, createdAt: daysAgo(90),
                promptText: "A letter", userInput: "Keep the difficult page without making it smaller."
            ),
            BookPage(
                id: "compass-old", type: .wonderCompass, createdAt: daysAgo(70),
                promptText: "Wonder Compass", userInput: "Turn east at the bakery and notice the red awning."
            )
        ]
        let todayPage = BookPage(
            id: "today-lantern", type: .diary, createdAt: now.addingTimeInterval(-900),
            promptText: "Journal", userInput: "A lantern in the window made the whole block feel briefly inhabited."
        )
        let archive = oldPages.map { day(pages: [$0]) } + [day(pages: [todayPage])]

        let first = ReturnedStacksRitual.cards(from: archive, history: [], now: now)
        let reread = ReturnedStacksRitual.cards(from: archive, history: [], now: now)

        XCTAssertEqual(first.map(\.role), [.rhyme, .longMemory, .wildCard])
        XCTAssertEqual(Set(first.map(\.page.id)).count, 3)
        XCTAssertEqual(first.first?.page.id, "lantern-old")
        XCTAssertTrue(first.first?.reason.lowercased().contains("lantern") == true)
        XCTAssertEqual(first, reread, "The same day's three returns must not reshuffle when the fold opens.")
    }

    func testReturnedStacksRestsPagesThatRecentlySatOnTheShelf() {
        let pages = (0..<6).map { index in
            BookPage(
                id: "archive-\(index)",
                type: index.isMultiple(of: 2) ? .souvenir : .diary,
                createdAt: daysAgo(30 + index * 10),
                promptText: "Kept page",
                userInput: "A distinct archive sentence number \(index) waited beside the window."
            )
        }
        let recentlyReturned = BookArchiveResurfacing(
            id: "recent",
            pageID: "archive-5",
            surfacedAt: daysAgo(1),
            reason: "Recent return",
            surface: ReturnedStacksRitual.surfaceName(role: .longMemory, index: 1),
            wasUsed: false
        )

        let cards = ReturnedStacksRitual.cards(
            from: pages.map { day(pages: [$0]) },
            history: [recentlyReturned],
            now: now
        )

        XCTAssertEqual(cards.count, 3)
        XCTAssertFalse(cards.contains { $0.page.id == "archive-5" })
    }

    // MARK: - Book Remembered rests returned pages

    func testRememberedPageIDsRecoverFromKeptTags() {
        let visitation = BookPage(
            id: "kept-visit", type: .bookRemembered, createdAt: daysAgo(5),
            promptText: "The Book Remembered", userInput: "",
            tags: ["book-remembered", "remembered-page:old-page"]
        )
        let archive = [day(pages: [visitation])]
        XCTAssertEqual(
            BookRememberedPageSourceAdapter.rememberedPageIDs(days: archive, within: 45, now: now),
            ["old-page"]
        )
        XCTAssertTrue(
            BookRememberedPageSourceAdapter.rememberedPageIDs(days: archive, within: 3, now: now).isEmpty,
            "A five-day-old visitation is outside a three-day window."
        )
    }

    func testRememberedAdapterRestsRecentlyReturnedPages() throws {
        // An old souvenir that rhymes with now: same month, neighboring hour.
        let oldPage = BookPage(
            id: "old-page", type: .souvenir, createdAt: daysAgo(15, hour: 10),
            promptText: "Souvenir", userInput: "The lighthouse blinked all night over the water."
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pages: filler())]
        inputs.resurfacingCandidates = [oldPage]
        let today = BookDay(id: "today", date: now, pages: [])

        let fresh = rememberedAdapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
        XCTAssertEqual(fresh.count, 1, "The page rhymes with today and should return.")
        XCTAssertTrue(fresh.first?.payload.metadata["tags"]?.contains("remembered-page:old-page") == true)

        // Once it has returned recently, it rests.
        let visitation = BookPage(
            id: "kept-visit", type: .bookRemembered, createdAt: daysAgo(5),
            promptText: "The Book Remembered", userInput: "",
            tags: ["book-remembered", "remembered-page:old-page"]
        )
        inputs.days = [day(pages: filler()), day(pages: [visitation])]
        // A kept visitation today would also trip didRememberToday, so it sits
        // in the archive days instead.
        let rested = rememberedAdapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
        XCTAssertTrue(rested.isEmpty, "A page that just returned must rest, not become a rerun.")
    }

    func testRememberedProseIsDeterministicPerDayAndPage() throws {
        let oldPage = BookPage(
            id: "old-page", type: .souvenir, createdAt: daysAgo(15, hour: 10),
            promptText: "Souvenir", userInput: "The lighthouse blinked all night over the water."
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pages: filler())]
        inputs.resurfacingCandidates = [oldPage]
        let today = BookDay(id: "today", date: now, pages: [])

        let first = rememberedAdapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now).first
        let second = rememberedAdapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now).first
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.payload.body, second?.payload.body)
        XCTAssertTrue(first?.payload.body.contains("lighthouse") == true)
    }
}
