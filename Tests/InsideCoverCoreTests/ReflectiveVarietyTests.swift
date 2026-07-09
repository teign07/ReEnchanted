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

    /// A BookDay whose id matches its pages' calendar day — `capturedPages`
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

    private func noticeSurface(inputs: BookSourceInputs, dayID: String = "today") -> SurfacePage? {
        let today = BookDay(id: dayID, date: now, pages: [])
        return noticesAdapter.candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
            .first { $0.payload.metadata["continuitySignals"] != nil }
    }

    // MARK: - Notices remember what they said

    func testFreshSignalsSurfaceAndTagThemselvesAsSpoken() throws {
        let inputs = noticeInputs(signals: [signal(id: "sig-harbor", subject: "harbor"), signal(id: "sig-kettle", subject: "kettle")])
        let surface = try XCTUnwrap(noticeSurface(inputs: inputs))
        let tags = surface.payload.metadata["tags"] ?? ""
        XCTAssertTrue(tags.contains("spoke:sig-harbor"))
        XCTAssertTrue(tags.contains("spoke:sig-kettle"))
        XCTAssertTrue(surface.payload.body.contains("harbor"))
    }

    func testBookStaysQuietWhenEverythingWasRecentlySaid() {
        let spoken = spokenNotice(ids: ["sig-harbor", "sig-kettle"], at: daysAgo(3))
        let inputs = noticeInputs(
            signals: [signal(id: "sig-harbor", subject: "harbor"), signal(id: "sig-kettle", subject: "kettle")],
            extraPages: [spoken]
        )
        XCTAssertNil(noticeSurface(inputs: inputs), "Silence reads better than a rerun.")
    }

    func testRestingSignalStepsBackWhileFreshOnesSpeak() throws {
        let spoken = spokenNotice(ids: ["sig-harbor"], at: daysAgo(3))
        let inputs = noticeInputs(
            signals: [
                signal(id: "sig-harbor", subject: "harbor"),
                signal(id: "sig-kettle", subject: "kettle"),
                signal(id: "sig-lantern", subject: "lantern")
            ],
            extraPages: [spoken]
        )
        let surface = try XCTUnwrap(noticeSurface(inputs: inputs))
        let tags = surface.payload.metadata["tags"] ?? ""
        XCTAssertFalse(tags.contains("spoke:sig-harbor"), "A resting signal is not spoken again.")
        XCTAssertTrue(tags.contains("spoke:sig-kettle"))
        XCTAssertFalse(surface.payload.body.contains("Harbor kept returning"))
    }

    func testReturnAfterRestReadsAsContinuationNotDiscovery() throws {
        let spokenLongAgo = spokenNotice(ids: ["sig-harbor"], at: daysAgo(30))
        let inputs = noticeInputs(
            signals: [signal(id: "sig-harbor", subject: "harbor"), signal(id: "sig-kettle", subject: "kettle")],
            extraPages: [spokenLongAgo]
        )
        let surface = try XCTUnwrap(noticeSurface(inputs: inputs))
        let continuationMarkers = ["I have said this before", "repeating on purpose", "Still true, still gathering"]
        XCTAssertTrue(
            continuationMarkers.contains { surface.payload.body.contains($0) },
            "A respoken signal must own that it was said before: \(surface.payload.body)"
        )
    }

    func testBodyNamesSubjectsWithoutRestatingTheCardLines() throws {
        // The observation detail (signal.line) belongs to the "What keeps
        // returning" cards. The body names the subjects but must not restate
        // the same sentence a second time.
        let inputs = noticeInputs(signals: [
            signal(id: "sig-harbor", subject: "harbor"),
            signal(id: "sig-kettle", subject: "kettle")
        ])
        let surface = try XCTUnwrap(noticeSurface(inputs: inputs))
        XCTAssertTrue(surface.payload.body.contains("harbor"), "The body names the subject.")
        XCTAssertTrue(surface.payload.body.contains("kettle"))
        XCTAssertFalse(
            surface.payload.body.contains("kept returning in the pages"),
            "The signal line must appear once, in the card — not restated in the body."
        )
        // The card still carries the full observation.
        XCTAssertTrue(surface.payload.metadata["tinyPatternCards"]?.contains("kept returning in the pages") == true)
    }

    func testSemanticPairingRidesInTheBodyOnlyWhenPresent() throws {
        let signals = [signal(id: "sig-harbor", subject: "harbor"), signal(id: "sig-kettle", subject: "kettle")]

        var without = noticeInputs(signals: signals)
        without.semanticNoticePairing = nil
        let plain = try XCTUnwrap(noticeSurface(inputs: without))
        XCTAssertFalse(plain.payload.body.contains("share no words but the same weather"))
        XCTAssertFalse((plain.payload.metadata["tags"] ?? "").contains("semantic-notice"))

        var withPairing = noticeInputs(signals: signals)
        withPairing.semanticNoticePairing = SemanticNoticePairing(
            anchorPageID: "anchor",
            anchorExcerpt: "the ferry horn at midnight",
            sourcePageID: "source",
            sourceExcerpt: "the smell of brine on the stairs",
            monthLine: "back in March",
            similarity: 0.82
        )
        let enriched = try XCTUnwrap(noticeSurface(inputs: withPairing))
        XCTAssertTrue(enriched.payload.body.contains("share no words but the same weather"))
        XCTAssertTrue(enriched.payload.body.contains("the ferry horn at midnight"))
        XCTAssertTrue(enriched.payload.body.contains("the smell of brine on the stairs"))
        XCTAssertTrue((enriched.payload.metadata["tags"] ?? "").contains("semantic-notice"))
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
        XCTAssertTrue(pairing.noticeParagraph.contains("the same weather"))
    }

    func testNoticeScaffoldingVariesAcrossDaysButRereadsIdentically() throws {
        let signals = [signal(id: "sig-harbor", subject: "harbor"), signal(id: "sig-kettle", subject: "kettle")]
        let bodies = try ["day-a", "day-b", "day-c", "day-d"].map { dayID -> String in
            try XCTUnwrap(noticeSurface(inputs: noticeInputs(signals: signals), dayID: dayID)).payload.body
        }
        XCTAssertGreaterThan(Set(bodies).count, 1, "Different days should not reread one template.")

        let again = try XCTUnwrap(noticeSurface(inputs: noticeInputs(signals: signals), dayID: "day-a")).payload.body
        XCTAssertEqual(again, bodies[0], "The same day rereads identically.")
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
