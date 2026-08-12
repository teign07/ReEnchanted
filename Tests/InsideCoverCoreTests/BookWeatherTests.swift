import XCTest
@testable import InsideCoverCore

/// Program F — the Book's weather.
///
/// The stance system shipped as plumbing: it prepended one of three fixed
/// strings for three stances and did nothing at all for `curious` and `intent`.
/// The single contract covering it asserted only that the detail *differed*,
/// which a glued-on prefix satisfies. These tests are written so that a prefix
/// cannot pass them.
final class BookWeatherTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    /// A four-paragraph reflective Page with a finding, some evidence, and a
    /// closing question — the ordinary shape the Loom and Notices produce.
    private func reflectivePage(_ id: String = "notice-1") -> SurfacePage {
        SurfacePage(
            id: id,
            type: .bookNotices,
            sourceID: "book-notices",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 80,
            reason: "Three roads reached the same door.",
            prompt: "Several distant corners of me touched at once.",
            detail: "The corners are restless. They have been for a week.",
            payload: BookPagePayload(
                headline: "What Keeps Finding What",
                body: """
                I have been holding this since the cover shut.

                Rain and the long walk keep arriving together, and I do not think that is the weather's idea.

                The leaves that did it are the wet Tuesday and the one about the bus.

                Do they belong together?
                """
            )
        )
    }

    // MARK: - The gate: a mood must change the telling, not the first three words

    /// The test that would have caught the stub. Across the whole matrix, the
    /// tellings must differ in *shape* — length, order, and what happens to the
    /// evidence — not merely in their opening.
    func testEveryStanceAndSizeTellsTheSameFindingDifferently() {
        let page = reflectivePage()
        var shapes = Set<String>()
        var bodies = Set<String>()

        for stance in BookStance.allCases {
            for intensity in 1...5 {
                let telling = BookTelling(stance: stance, intensity: intensity)
                let voiced = BookCharacterStanceEditor.voicing(page, telling: telling)
                let paragraphs = voiced.payload.body.components(separatedBy: "\n\n")
                let shape = [
                    "\(paragraphs.count)",
                    voiced.payload.metadata["bookEvidencePosture"] ?? "-",
                    paragraphs.first?.hasPrefix("I have been holding") == true ? "throat-first" : "finding-first",
                    paragraphs.last?.hasSuffix("?") == true ? "asks" : "silent"
                ].joined(separator: "|")
                shapes.insert(shape)
                bodies.insert(voiced.payload.body)
            }
        }

        // A prefix-only implementation produces exactly ONE shape. Anything
        // that genuinely re-tells produces many.
        XCTAssertGreaterThanOrEqual(
            shapes.count, 6,
            "A mood must change the shape of the telling, not just its opening."
        )
        XCTAssertGreaterThanOrEqual(bodies.count, 6)
    }

    /// The two stances the old editor left as no-ops.
    func testCuriousAndIntentAreNoLongerSilentNoOps() {
        let page = reflectivePage()
        for stance in [BookStance.curious, .intent] {
            let low = BookCharacterStanceEditor.voicing(page, telling: BookTelling(stance: stance, intensity: 1))
            let high = BookCharacterStanceEditor.voicing(page, telling: BookTelling(stance: stance, intensity: 5))
            XCTAssertNotEqual(
                low.payload.body, high.payload.body,
                "\(stance.rawValue) must tell a Page differently at different sizes."
            )
        }
    }

    /// Intensity amplifies the stance's own direction: an expansive Book says
    /// more, a guarded one says less. This is the hinge of the model.
    func testIntensityOpensAnExpansiveBookAndClosesAGuardedOne() {
        let page = reflectivePage()
        func paragraphs(_ stance: BookStance, _ intensity: Int) -> Int {
            BookCharacterStanceEditor
                .voicing(page, telling: BookTelling(stance: stance, intensity: intensity))
                .payload.body.components(separatedBy: "\n\n").count
        }
        XCTAssertGreaterThan(paragraphs(.pleased, 5), paragraphs(.pleased, 1))
        XCTAssertLessThan(paragraphs(.protective, 5), paragraphs(.protective, 1))
    }

    func testAColdBookDoesNotHandOverItsEvidence() {
        let hot = BookTelling(stance: .pleased, intensity: 5)
        let cold = BookTelling(stance: .contrite, intensity: 5)
        XCTAssertEqual(hot.evidencePosture, .volunteered)
        XCTAssertEqual(cold.evidencePosture, .leftToFind)
        XCTAssertFalse(cold.asks)
    }

    /// The voice law asks the Book to interrupt itself. The old editor never
    /// did; when it does, the break must land *inside* the paragraph.
    func testFullTiltInterruptsItsOwnSentenceRatherThanWearingAPrefix() {
        let page = reflectivePage()
        let voiced = BookCharacterStanceEditor.voicing(
            page, telling: BookTelling(stance: .mischievous, intensity: 5)
        )
        let first = voiced.payload.body.components(separatedBy: "\n\n")[0]
        XCTAssertTrue(first.contains(" — "), "The interruption must be mid-paragraph.")
        XCTAssertFalse(first.hasPrefix("—"), "An interruption is not a prefix.")
    }

    func testPagesOutsideTheBooksOwnFamiliesAreLeftAlone() {
        let diary = SurfacePage(
            id: "diary-1", type: .diary, sourceID: "diary", intent: .capture,
            renderStyle: .loreLetter, score: 50, reason: "r", prompt: "p", detail: "d",
            payload: BookPagePayload(headline: "h", body: "one\n\ntwo\n\nthree\n\nfour?")
        )
        let voiced = BookCharacterStanceEditor.voicing(
            diary, telling: BookTelling(stance: .protective, intensity: 5)
        )
        XCTAssertEqual(voiced.payload.body, diary.payload.body)
    }

    // MARK: - Weather: causes, duration, decay

    func testAMoodFadesInsteadOfBeingRecomputed() {
        let mood = BookMood(
            stance: .contrite, intensity: 4, cause: .correction,
            arrivedAt: now, halfLife: BookMoodEngine.halfLife(for: .correction)
        )
        XCTAssertEqual(mood.intensity(at: now), 4)
        XCTAssertEqual(mood.intensity(at: now.addingTimeInterval(24 * 3600)), 2)
        XCTAssertTrue(mood.isSpent(at: now.addingTimeInterval(10 * 86_400)))
    }

    /// The afternoon runs into the evening. A smaller new feeling does not
    /// overwrite a larger one that is still going.
    func testABiggerStandingMoodIsNotDisplacedByASmallerArrival() {
        let sore = BookMood(
            stance: .contrite, intensity: 5, cause: .correction,
            arrivedAt: now, halfLife: BookMoodEngine.halfLife(for: .correction)
        )
        let small = BookMood(
            stance: .pleased, intensity: 2, cause: .keeping,
            arrivedAt: now.addingTimeInterval(3600),
            halfLife: BookMoodEngine.halfLife(for: .keeping)
        )
        let resolved = BookMoodEngine.resolving(
            standing: sore, candidate: small, baseline: .curious,
            now: now.addingTimeInterval(3600)
        )
        XCTAssertEqual(resolved.stance, .contrite)
    }

    func testASpentMoodReturnsTheBookToItsOwnTemperamentNotToADefault() {
        let spent = BookMood(
            stance: .pleased, intensity: 1, cause: .keeping,
            arrivedAt: now, halfLife: BookMoodEngine.halfLife(for: .keeping)
        )
        let resolved = BookMoodEngine.resolving(
            standing: spent, candidate: nil, baseline: .mischievous,
            now: now.addingTimeInterval(30 * 3600)
        )
        XCTAssertEqual(resolved.stance, .mischievous)
        XCTAssertEqual(resolved.cause, .baseline)
    }

    /// Two Books are different creatures from the first day, and each one's
    /// resting mood is stable across restarts.
    func testBaselineTemperamentIsStablePerBookAndVariesBetweenBooks() {
        let first = BookTemperament.baseline(awakenedAt: now)
        XCTAssertEqual(first, BookTemperament.baseline(awakenedAt: now))

        var seen = Set<BookStance>()
        for day in 0..<60 {
            seen.insert(BookTemperament.baseline(awakenedAt: now.addingTimeInterval(Double(day) * 86_400)))
        }
        XCTAssertGreaterThan(seen.count, 1, "Every Book must not rest in the same mood.")
        XCTAssertTrue(seen.isSubset(of: Set(BookTemperament.resting)))
        XCTAssertFalse(seen.contains(.hushed), "Night is not a temperament.")
        XCTAssertFalse(seen.contains(.pleased), "A reaction is not a temperament.")
    }

    // MARK: - Night is a modifier, not a mood

    func testNightQuietensTheStandingMoodWithoutReplacingIt() {
        let page = reflectivePage()
        let day = BookTelling(stance: .mischievous, intensity: 4, night: false)
        let night = BookTelling(stance: .mischievous, intensity: 4, night: true)

        XCTAssertEqual(night.stance, .mischievous, "Night must not overwrite the mood.")
        XCTAssertLessThan(night.paragraphBudget, day.paragraphBudget)
        XCTAssertFalse(night.asks)
        XCTAssertFalse(night.interrupts)

        let voicedNight = BookCharacterStanceEditor.voicing(page, telling: night)
        XCTAssertEqual(voicedNight.payload.metadata["bookCharacterNight"], "true")
        XCTAssertEqual(
            voicedNight.payload.metadata["bookCharacterStance"],
            BookStance.mischievous.rawValue
        )
    }

    func testTheHourNoLongerDecidesWhichBookYouGet() {
        var night = DateComponents()
        night.year = 2026; night.month = 6; night.day = 1; night.hour = 23
        let midnightish = Calendar.current.date(from: night)!

        let snapshot = BookRelationshipLedger.snapshot(
            days: [], observations: [], readingBoundaries: [], learnedBraidNotes: [],
            readerLearning: ReaderLearningModel(), constellations: [], wagers: [],
            quietDays: 0, readerBeliefScore: 0,
            standingMood: nil, baselineStance: .mischievous, now: midnightish
        )
        XCTAssertEqual(snapshot.stance, .mischievous, "The clock must not pick the mood.")
        XCTAssertTrue(snapshot.night, "Night is carried as a modifier instead.")
    }

    // MARK: - The reader's effect, and the line it must not cross

    /// A correction makes the Book cold for a day. That is a sulk, and it is
    /// allowed. It never says why and it lifts on its own.
    func testBeingToldItIsWrongMakesTheBookColdRatherThanApologetic() {
        let mood = BookInteriorEngine.moodAfterReply(
            .wrong, subjectKey: "opinion:stairs", standing: nil, now: now
        )
        let telling = BookTelling(mood: try! XCTUnwrap(mood), at: now)
        XCTAssertEqual(telling.evidencePosture, .leftToFind)
        XCTAssertFalse(telling.asks)
        XCTAssertFalse(telling.expansive)

        // And it lifts without being repaired.
        XCTAssertTrue(try! XCTUnwrap(mood).isSpent(at: now.addingTimeInterval(14 * 86_400)))
    }

    func testABoundaryIsNotAnInjury() {
        let standing = BookMood(
            stance: .curious, intensity: 3, cause: .ownBusiness,
            arrivedAt: now, halfLife: BookMoodEngine.halfLife(for: .ownBusiness)
        )
        let after = BookInteriorEngine.moodAfterReply(
            .notNow, subjectKey: "opinion:stairs", standing: standing, now: now
        )
        XCTAssertEqual(after, standing, "'Not now' must cost the Book nothing.")
    }

    /// Absence never becomes a charge. Returning after a long silence must meet
    /// a small, fast-fading gentleness — never a large mood.
    func testAbsenceProducesGentlenessAndNeverAGrievance() {
        let snapshot = BookRelationshipLedger.snapshot(
            days: [], observations: [], readingBoundaries: [], learnedBraidNotes: [],
            readerLearning: ReaderLearningModel(), constellations: [], wagers: [],
            quietDays: 40, readerBeliefScore: 0,
            standingMood: nil, baselineStance: .curious, now: now
        )
        XCTAssertEqual(snapshot.stance, .protective)
        let mood = try! XCTUnwrap(snapshot.mood)
        XCTAssertLessThanOrEqual(mood.intensity, 2, "Absence must never make a large mood.")
        XCTAssertNotEqual(mood.cause, .correction)
    }

    // MARK: - The weather is wired to the reader, not just modelled

    /// The reply path must actually move the interior weather, or the sulk is
    /// a function nobody calls.
    func testAnsweringAnInterjectionMovesTheDurableWeather() throws {
        let page = SurfacePage(
            id: "notice-9", type: .bookNotices, sourceID: "s", intent: .reflect,
            renderStyle: .loreLetter, score: 60, reason: "r", prompt: "p", detail: "d",
            payload: BookPagePayload(
                headline: "h", body: "b",
                metadata: [
                    "bookInterjectionID": "interjection-9",
                    "bookInterjectionSubjectKey": "opinion:stairs",
                    "bookInterjectionThoughtKey": "opinion:stairs:opinion"
                ]
            )
        )
        let interior = BookInteriorState(awakenedAt: now.addingTimeInterval(-90 * 86_400))

        let sore = BookInterjectionEditor.applying(.wrong, to: page, interior: interior, at: now)
        let mood = try XCTUnwrap(sore.mood)
        XCTAssertEqual(mood.stance, .contrite)
        XCTAssertEqual(mood.subjectKey, "opinion:stairs")
        XCTAssertEqual(mood.cause, .correction)

        let warmed = BookInterjectionEditor.applying(.goOn, to: page, interior: interior, at: now)
        XCTAssertEqual(try XCTUnwrap(warmed.mood).stance, .pleased)

        let untouched = BookInterjectionEditor.applying(.notNow, to: page, interior: interior, at: now)
        XCTAssertNil(untouched.mood, "A boundary must not create a mood.")
    }

    /// A mood has an object, and the object shows in what the Book circles
    /// back to — never in anything it says about its own feelings.
    func testWarmWeatherReturnsToItsSubjectAndColdWeatherWalksAroundIt() {
        func snapshot(_ mood: BookMood?) -> BookRelationshipSnapshot {
            BookRelationshipSnapshot(
                stance: mood?.stance ?? .curious, mood: mood, night: false,
                depth: .companion, keptPageCount: 40, confirmedReadingCount: 2,
                softenedReadingCount: 0, protectedBoundaryCount: 0, returnedPageCount: 4,
                taughtRules: [], cherishedThreadName: nil, latestWager: nil,
                recentReadingStatus: nil
            )
        }
        func subject(with mood: BookMood?) -> String? {
            let desk = (0..<3).map { reflectivePage("page-\($0)") }
            return BookInterjectionEditor.decoratingDesk(
                desk,
                interior: BookInteriorState(
                    awakenedAt: now.addingTimeInterval(-200 * 86_400),
                    sharedJoke: "The ribbon claims stairs are only shelves standing up.",
                    baselineStance: .curious
                ),
                days: [], selfFacts: [], relationship: snapshot(mood), receipts: [],
                appetite: .unruly, distressActive: false, rutward: false, now: now
            )
            .compactMap { $0.payload.metadata["bookInterjectionSubjectKey"] }
            .first
        }

        guard let neutral = subject(with: nil) else {
            return XCTFail("The Book should have had something on its mind.")
        }
        let cold = BookMood(
            stance: .contrite, intensity: 4, subjectKey: neutral,
            cause: .correction, arrivedAt: now,
            halfLife: BookMoodEngine.halfLife(for: .correction)
        )
        XCTAssertNotEqual(
            subject(with: cold), neutral,
            "A Book sore about a subject should not lead with it."
        )
    }

    // MARK: - The lint line: difficult, never guilt-tripping

    func testLintCatchesTheThreeWaysAMoodBecomesManipulation() {
        func findings(_ body: String) -> [String] {
            let page = SurfacePage(
                id: "x", type: .bookNotices, sourceID: "s", intent: .reflect,
                renderStyle: .loreLetter, score: 10, reason: "r", prompt: "p", detail: "d",
                payload: BookPagePayload(headline: "h", body: body)
            )
            return BookCharacterLint.inspect(page).map(\.rule)
        }
        XCTAssertTrue(findings("I'm feeling low about the stairs.").contains("mood-declared"))
        XCTAssertTrue(findings("I've missed you these past weeks.").contains("absence-attributed"))
        XCTAssertTrue(findings("You could cheer me up, if you wanted.").contains("repair-solicited"))
    }

    /// The other half of the same law: being difficult must stay legal.
    func testASulkingBookIsNotALintFailure() {
        let page = SurfacePage(
            id: "sulk", type: .bookNotices, sourceID: "s", intent: .reflect,
            renderStyle: .loreLetter, score: 10,
            reason: "I am not in the mood to explain this one.",
            prompt: "Take it or leave it.",
            detail: "The ribbon is sulking and I am letting it.",
            payload: BookPagePayload(
                headline: "I Object",
                body: "You were wrong about the stairs. I am not going to argue about it twice."
            )
        )
        XCTAssertTrue(
            BookCharacterLint.inspect(page).filter { $0.severity == .error }.isEmpty,
            "The Book must be allowed to be short with the reader."
        )
    }
}
