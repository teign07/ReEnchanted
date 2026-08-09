import XCTest
@testable import InsideCoverCore

/// Phase 2b: reading the Rut and the reader's aliveness off behaviour as well as
/// self-report.
///
/// The tests that matter most here are the ones asserting what this *cannot* do.
/// Inferred evidence may lean the Book's private weighting and may never earn it
/// the standing to speak, and it may never carry the Rut into its top band on
/// its own.
final class InferredSignalsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private func page(_ index: Int, daysAgo: Int, text: String) -> BookPage {
        BookPage(
            id: "p-\(index)-\(daysAgo)",
            type: .diary,
            createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
            promptText: "Prompt",
            userInput: text,
            origin: .userAuthored
        )
    }

    /// `count` pages spread across the given window, all with the same text.
    private func pages(count: Int, from: Int, to: Int, text: String) -> [BookPage] {
        (0..<count).map { index in
            let span = max(1, from - to)
            return page(index, daysAgo: to + (index % span), text: text)
        }
    }

    private func row(daysAgo: Int, types: [String] = [], place: String? = nil) -> DaybookEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        var entry = DaybookEntry(
            dayID: DaybookRecorder.dayID(for: date, calendar: calendar),
            date: date,
            fidelity: .live,
            calendar: calendar,
            writtenAt: date
        )
        entry.keptPageTypes = types
        entry.placeLabel = place
        return entry
    }

    /// A Ledger with enough tenure to be consulted.
    private var readyLedger: StandingLedger {
        var ledger = StandingLedger.unwritten
        ledger.tenureDays = 40
        return ledger
    }

    // MARK: - The two things it must never do

    func testInferredEvidenceNeverGrantsTheStandingToNameTheRut() {
        // Every measure screaming flattening.
        let signals = InferredReaderSignals(
            signals: InferredMeasure.allCases.map {
                InferredSignal(
                    measure: $0,
                    lean: .rutward,
                    strength: 2,
                    recentSampleCount: 20,
                    priorSampleCount: 20
                )
            },
            computedAt: now,
            isReady: true
        )

        // It may lean the private weighting by exactly one step...
        XCTAssertEqual(signals.rutPressureAdjustment, 1)

        // ...and there is no route from here to permission. `mayNameRut` is not
        // a parameter of anything in this file, by construction: the Book may
        // respond to a flattening and may never accuse the reader of one.
        XCTAssertFalse(
            signals.evidenceTags.contains { $0.contains("mayName") }
        )
        XCTAssertTrue(signals.evidenceTags.allSatisfy { $0.hasPrefix("inferred:") })
    }

    func testInferredWeightCannotCarryTheRutIntoItsTopBand() {
        let flattening = InferredReaderSignals(
            signals: InferredMeasure.allCases.map {
                InferredSignal(measure: $0, lean: .rutward, strength: 2, recentSampleCount: 20, priorSampleCount: 20)
            },
            computedAt: now,
            isReady: true
        )

        // From the ordinary-life floor, behaviour can lift pressure to 2 and
        // stops there. The deep water requires the reader to say so.
        XCTAssertEqual(InferredRutApplication.adjustedPressure(base: 1, signals: flattening), 2)
        XCTAssertEqual(InferredRutApplication.adjustedPressure(base: 2, signals: flattening), 2)

        // A reader who has reported their own way to 3 keeps their level; the
        // inferred ceiling never drags a reported pressure down.
        XCTAssertEqual(InferredRutApplication.adjustedPressure(base: 3, signals: flattening), 3)
    }

    func testEasingSignalsNeverPushBelowTheOrdinaryLifeFloor() {
        let quickening = InferredReaderSignals(
            signals: InferredMeasure.allCases.map {
                InferredSignal(measure: $0, lean: .aliveward, strength: 2, recentSampleCount: 20, priorSampleCount: 20)
            },
            computedAt: now,
            isReady: true
        )

        XCTAssertEqual(quickening.rutPressureAdjustment, -1)
        XCTAssertEqual(InferredRutApplication.adjustedPressure(base: 1, signals: quickening), 1)
        XCTAssertEqual(InferredRutApplication.adjustedPressure(base: 3, signals: quickening), 2)
    }

    // MARK: - Flattening, not heaviness

    func testGriefIsNotRut() {
        // Heavy ink, full of particulars: a named person, a place, a time. This
        // is someone in pain and intensely present, and it must not read as a
        // flattening.
        let griefStricken = pages(
            count: 10,
            from: 13,
            to: 0,
            text: "Sat with Dad at Mercy General until 3am. He asked about the Ferguson house again, the porch, the yellow door. I could not stop crying in the parking garage."
        )
        // The prior fortnight: ordinary, cheerful, and completely unparticular.
        let before = pages(
            count: 10,
            from: 27,
            to: 14,
            text: "Work was fine. Felt okay about things. It was a pretty good day overall, nothing much to report."
        )

        let signals = InferredSignalReader.read(
            pages: griefStricken + before,
            rows: [],
            ledger: readyLedger,
            now: now,
            calendar: calendar
        )

        let specificity = signals.signals.first { $0.measure == .specificity }
        // Particularity went *up*, so the specificity measure leans aliveward
        // even though the ink is far heavier than before.
        XCTAssertEqual(specificity?.lean, .aliveward)
        XCTAssertNotEqual(signals.alivenessLean, .rutward)
    }

    func testFlatteningIsReadFromLossOfParticularity() {
        // The mirror image: same pages, opposite order in time.
        let flatNow = pages(
            count: 10,
            from: 13,
            to: 0,
            text: "Work was fine. Felt okay about things. It was a pretty good day overall, nothing much to report."
        )
        let particularBefore = pages(
            count: 10,
            from: 27,
            to: 14,
            text: "Walked to Alki with Marcus and the dog. Coffee at Uptown, 40 degrees, the ferry going out past Duwamish Head."
        )

        let signals = InferredSignalReader.read(
            pages: flatNow + particularBefore,
            rows: [],
            ledger: readyLedger,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(signals.signals.first { $0.measure == .specificity }?.lean, .rutward)
        XCTAssertGreaterThan(signals.rutwardWeight, 0)
    }

    func testDaysBecomingInterchangeableRegisterAsSelfSimilarity() {
        let identical = pages(count: 10, from: 13, to: 0, text: "Went to work then came home then watched television then slept.")
        let varied = [
            "Rain all morning, read Middlemarch on the porch.",
            "Fixed the bicycle chain, greasy hands, listened to records.",
            "Long call with Priya about her thesis defence.",
            "Made bread, badly. The crust went dark.",
            "Swimming at dawn, the lake still cold.",
            "Argued about the lease. Felt small afterwards.",
            "Planted the tomatoes finally, three weeks late.",
            "Found the old photographs in the hall cupboard.",
            "Walked the long way past the observatory.",
            "Wrote letters. Sent none of them."
        ].enumerated().map { page($0.offset, daysAgo: 14 + $0.offset, text: $0.element) }

        let signals = InferredSignalReader.read(
            pages: identical + varied,
            rows: [],
            ledger: readyLedger,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(signals.signals.first { $0.measure == .selfSimilarity }?.lean, .rutward)
    }

    // MARK: - Asymmetries

    func testALengthCollapseLeansRutwardButALengthBurstMeansNothing() {
        XCTAssertEqual(InferredMeasure.sentenceLength.fallingLean, .rutward)
        XCTAssertEqual(InferredMeasure.sentenceLength.risingLean, .neutral)

        // A move in a direction that means nothing carries no weight at all.
        let burst = InferredSignalReader.signal(
            measure: .sentenceLength,
            recent: 100,
            prior: 20,
            recentCount: 10,
            priorCount: 10
        )
        XCTAssertEqual(burst.lean, .neutral)
        XCTAssertEqual(burst.strength, 0)

        let collapse = InferredSignalReader.signal(
            measure: .sentenceLength,
            recent: 5,
            prior: 40,
            recentCount: 10,
            priorCount: 10
        )
        XCTAssertEqual(collapse.lean, .rutward)
        XCTAssertEqual(collapse.strength, 2)
    }

    func testAQuestionAskingRiseLeansAlivewardAndAFallMeansNothing() {
        XCTAssertEqual(InferredMeasure.questionAsking.risingLean, .aliveward)
        XCTAssertEqual(InferredMeasure.questionAsking.fallingLean, .neutral)
    }

    // MARK: - Gates

    func testNothingIsReadFromTooFewPages() {
        let thin = pages(count: 3, from: 13, to: 0, text: "Short.")
            + pages(count: 3, from: 27, to: 14, text: "Also short.")

        let signals = InferredSignalReader.read(
            pages: thin,
            rows: [],
            ledger: readyLedger,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(signals.isReady)
        XCTAssertTrue(signals.signals.isEmpty)
        XCTAssertEqual(signals.rutPressureAdjustment, 0)
    }

    func testNothingIsReadBeforeTheLedgerHasTenure() {
        let plenty = pages(count: 10, from: 13, to: 0, text: "Work was fine, nothing much.")
            + pages(count: 10, from: 27, to: 14, text: "Walked to Alki with Marcus, 40 degrees, coffee at Uptown.")

        let signals = InferredSignalReader.read(
            pages: plenty,
            rows: [],
            ledger: .unwritten,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(signals.isReady)
        // Measures may be computed, but nothing is acted on.
        XCTAssertEqual(signals.rutPressureAdjustment, 0)
        XCTAssertEqual(signals.alivenessLean, .neutral)
    }

    func testASmallMoveIsNotAMove() {
        let barely = InferredSignalReader.signal(
            measure: .specificity,
            recent: 10.5,
            prior: 10.0,
            recentCount: 10,
            priorCount: 10
        )

        XCTAssertEqual(barely.lean, .neutral)
        XCTAssertEqual(barely.strength, 0)
    }

    func testGeneratedPagesAreNotReadAsTheReadersWriting() {
        var generated = pages(count: 20, from: 13, to: 0, text: "The Book's own prose, at length and in detail, from Thornwave.")
        for index in generated.indices {
            generated[index].origin = .generated
        }

        let signals = InferredSignalReader.read(
            pages: generated,
            rows: [],
            ledger: readyLedger,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(signals.isReady)
        XCTAssertTrue(signals.signals.isEmpty)
    }

    // MARK: - Measures in isolation

    func testSpecificityCountsParticularsAndNotSentenceInitialCapitals() {
        // "The" and "Work" open their sentences, so neither is a particular.
        let plain = [page(0, daysAgo: 1, text: "The day was fine. Work was okay.")]
        // Marcus, Alki, and 40 are.
        let particular = [page(1, daysAgo: 1, text: "Walked with Marcus to Alki, 40 degrees.")]

        let plainScore = InferredSignalReader.specificity(of: plain) ?? 0
        let particularScore = InferredSignalReader.specificity(of: particular) ?? 0

        XCTAssertEqual(plainScore, 0)
        XCTAssertGreaterThan(particularScore, 0)
    }

    func testLexicalRangeComparesEqualWordCountsAcrossWindows() {
        // A quiet fortnight with less writing in it must not read as a
        // narrowing vocabulary — that confound is the whole difficulty.
        let long = (0..<10).map {
            page($0, daysAgo: 1, text: "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima")
        }
        let short = (0..<4).map {
            page($0, daysAgo: 20, text: "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima")
        }

        let longRange = InferredSignalReader.lexicalRange(of: long, matching: short)
        let shortRange = InferredSignalReader.lexicalRange(of: short, matching: long)

        // Same vocabulary, different volume: the ratios must agree.
        XCTAssertEqual(longRange ?? 0, shortRange ?? 0, accuracy: 0.001)
    }

    func testNoveltyCountsWhatIsNewAgainstThePriorFortnight() {
        let prior = [row(daysAgo: 20, types: ["diary"], place: "Home")]
        let recent = [
            row(daysAgo: 3, types: ["diary"], place: "Home"),
            row(daysAgo: 2, types: ["mood"], place: "the harbour")
        ]

        let novelty = InferredSignalReader.novelty(recent: recent, prior: prior)

        // "mood" and "the harbour" are both new.
        XCTAssertEqual(novelty?.recent, 3)
        XCTAssertEqual(novelty?.prior, 1)
    }

    // MARK: - Audit

    func testEveryActiveSignalCarriesAnInferredTag() {
        let signals = InferredReaderSignals(
            signals: [
                InferredSignal(measure: .specificity, lean: .rutward, strength: 2, recentSampleCount: 9, priorSampleCount: 9),
                InferredSignal(measure: .lexicalRange, lean: .neutral, strength: 0, recentSampleCount: 9, priorSampleCount: 9)
            ],
            computedAt: now,
            isReady: true
        )

        // Neutral measures are not evidence of anything and are not listed.
        XCTAssertEqual(signals.evidenceTags, ["inferred:specificity"])
    }

    func testSignalsSurviveARoundTrip() throws {
        let signals = InferredReaderSignals(
            signals: [
                InferredSignal(measure: .novelty, lean: .aliveward, strength: 1, recentSampleCount: 12, priorSampleCount: 11)
            ],
            computedAt: now,
            isReady: true
        )

        let data = try JSONEncoder().encode(signals)
        let decoded = try JSONDecoder().decode(InferredReaderSignals.self, from: data)

        XCTAssertEqual(decoded, signals)
    }
}
