import XCTest
@testable import InsideCoverCore

/// The Reader's Sheet (the `.frontMatter` Page): the reader's standing in one
/// place, and the Curse's file read off the Knocks.
final class ReaderSheetTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_783_484_800)

    private func context(at date: Date, place: String? = nil, weather: [String] = [],
                         sleep: Double? = nil) -> BookPageContextSnapshot {
        BookPageContextSnapshot(at: date, calendar: calendar, weatherTags: weather, locationLabel: place,
                                sleepHours: sleep)
    }

    /// Ten days of two Knocks: mornings at the library come back "here", and
    /// afternoons in the kitchen in the rain mostly go grey, with words.
    private func foggyAfternoons() -> AttentionProbeLedger {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-12 * 86_400))
        for day in 0..<10 {
            let base = start.addingTimeInterval(Double(day) * 86_400)
            let morning = base.addingTimeInterval(9 * 3600)
            ledger.record(id: "here-\(day)", scheduledAt: morning, answeredAt: morning.addingTimeInterval(60),
                          answer: .here, cycle: 0,
                          context: context(at: morning, place: "the library", weather: ["clear"]))
            let afternoon = base.addingTimeInterval(15 * 3600)
            let isGrey = day % 5 != 0
            ledger.record(id: "pm-\(day)", scheduledAt: afternoon,
                          answeredAt: afternoon.addingTimeInterval(isGrey ? 20 * 60 : 60),
                          answer: isGrey ? .elsewhere : .here, cycle: 0,
                          sentence: isGrey ? "Scrolling the phone in the kitchen again, day \(day)" : nil,
                          context: context(at: afternoon, place: "the kitchen", weather: ["rain"]))
        }
        return ledger
    }

    // MARK: Standing

    func testTheSheetCarriesEveryStatInOnePlace() {
        let standing = ReaderSheetStanding.build(
            belief: 41,
            roleName: "The Lamplighter",
            roleGloss: "You notice what's lit.",
            attention: foggyAfternoons(),
            ribbons: [],
            inkbones: [],
            greyThreats: .empty,
            now: now,
            calendar: calendar
        )
        let ids = standing.rows.map(\.id)
        XCTAssertEqual(ids.first, "belief", "Belief leads the sheet")
        for id in ["belief", "role", "fight", "curse-hour", "ribbons", "inkbones"] {
            XCTAssertTrue(ids.contains(id), "missing \(id)")
        }
        XCTAssertEqual(standing.rows.first?.value, "41")
        XCTAssertEqual(standing.rows.first { $0.id == "role" }?.value, "The Lamplighter")
        XCTAssertEqual(standing.rows.first { $0.id == "ribbons" }?.value, "0 of 3")
        XCTAssertEqual(standing.rows.first { $0.id == "curse-hour" }?.value, "three in the afternoon")
        XCTAssertFalse(standing.rows.contains { $0.id == "grey" }, "no Grey row without a Grey Page")
    }

    func testAnUnnamedReaderIsToldHowToGetANameAndNothingSaysGlow() {
        let standing = ReaderSheetStanding.build(
            belief: 30, roleName: nil, roleGloss: nil,
            attention: .empty, ribbons: [], inkbones: [], greyThreats: .empty,
            now: now, calendar: calendar
        )
        XCTAssertEqual(standing.rows.first { $0.id == "role" }?.value, "Not named yet")
        XCTAssertEqual(standing.rows.first { $0.id == "fight" }?.value, "You 0 · Curse 0")
        let text = standing.rows.map { "\($0.label) \($0.value) \($0.line)" }.joined(separator: " ")
        XCTAssertFalse(text.lowercased().contains("glow"))
        XCTAssertFalse(ReaderSheetStanding.howItWorks.lowercased().contains("glow"))
    }

    func testTheLastThrowIsTheReadersOwn() {
        let log = [
            InkbonesThrowRecord(id: "a", at: now, thrower: .reader, roll: 23, target: 58, subject: "Q", outcome: "favor"),
            InkbonesThrowRecord(id: "b", at: now, thrower: .curse, roll: 91, target: 80, subject: "P", outcome: "took")
        ]
        let row = ReaderSheetStanding.inkbonesRow(log)
        XCTAssertEqual(row.value, "23")
        XCTAssertTrue(row.line.contains("58"))
        XCTAssertTrue(row.line.contains("favoured"))
    }

    // MARK: The Curse's file

    func testTheCursesFileWaitsUntilThereIsSomethingTrueToSay() {
        let empty = CurseDossier.build(.empty, calendar: calendar)
        XCTAssertFalse(empty.isReady)
        XCTAssertTrue(empty.findings.isEmpty)
        XCTAssertTrue(empty.waitingLine.contains("file on the Curse"))
    }

    func testTheCursesFileFindsItsTimeItsPlaceItsWeatherAndItsWords() throws {
        let dossier = CurseDossier.build(foggyAfternoons(), calendar: calendar)
        XCTAssertTrue(dossier.isReady)
        XCTAssertEqual(dossier.answered, 20)
        XCTAssertEqual(dossier.grey, 8)

        func finding(_ id: String) -> CurseDossier.Finding? { dossier.findings.first { $0.id == id } }
        XCTAssertEqual(finding("take")?.value, "40%")
        XCTAssertEqual(finding("day-part")?.value, "Afternoon")
        XCTAssertEqual(finding("place")?.value, "the kitchen")
        XCTAssertEqual(finding("weather")?.value, "Rain")
        let words = try XCTUnwrap(finding("words")?.value)
        XCTAssertTrue(words.contains("kitchen"), words)
        XCTAssertTrue(words.contains("scrolling"), words)
        XCTAssertEqual(finding("speed")?.value, "19 min slower")
        XCTAssertNotNil(finding("last-words"))
        // The library is where it never wins: never named as one of its places.
        XCTAssertFalse(dossier.findings.contains { $0.value == "the library" })
    }

    /// The Curse joined to the rest of the reader's life: after short nights
    /// it wins, after long ones it doesn't.
    func testTheCursesFileConnectsToTheNightBefore() {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-12 * 86_400))
        for day in 0..<10 {
            let at = start.addingTimeInterval(Double(day) * 86_400 + 11 * 3600)
            let shortNight = day.isMultiple(of: 2)
            let grey = shortNight && day != 0
            ledger.record(id: "k\(day)", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: grey ? .elsewhere : .here, cycle: 0,
                          context: context(at: at, sleep: shortNight ? 5 : 8.5))
        }
        let dossier = CurseDossier.build(ledger, calendar: calendar)
        XCTAssertEqual(dossier.findings.first { $0.id == "feeds-on" }?.value, "After a short night")
    }

    func testTheFileIsReadALittleEachDay() {
        let dossier = CurseDossier.build(foggyAfternoons(), calendar: calendar)
        let today = dossier.featured(on: now, count: 2, calendar: calendar)
        let tomorrow = dossier.featured(on: now.addingTimeInterval(86_400), count: 2, calendar: calendar)
        XCTAssertEqual(today.count, 2)
        XCTAssertFalse(today.contains { $0.id == "take" }, "the column prints its own counts")
        XCTAssertEqual(tomorrow.first, today.last, "the file turns one finding a day")
        XCTAssertTrue(today[0].printed.hasPrefix(today[0].label + ": "))
    }

    func testABucketIsOnlyNamedWhenTheCurseBeatsItsOwnAverageThere() {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-10 * 86_400))
        // Grey half the time, everywhere alike: nowhere stands out.
        for index in 0..<8 {
            let at = start.addingTimeInterval(Double(index) * 86_400 + 10 * 3600)
            ledger.record(id: "k\(index)", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: index.isMultiple(of: 2) ? .elsewhere : .here, cycle: 0,
                          context: context(at: at, place: "home"))
        }
        let dossier = CurseDossier.build(ledger, calendar: calendar)
        XCTAssertTrue(dossier.isReady)
        XCTAssertNil(dossier.findings.first { $0.id == "place" })
        XCTAssertNil(dossier.findings.first { $0.id == "day-part" })
    }

    // MARK: The Rut hears the Knocks

    private func knocks(grey: Int, of total: Int) -> AttentionProbeLedger {
        var ledger = AttentionProbeLedger.empty
        for index in 0..<total {
            let at = now.addingTimeInterval(-Double(index + 1) * 20 * 3600)
            ledger.record(id: "r\(index)", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: index < grey ? .elsewhere : .here, cycle: 0)
        }
        return ledger
    }

    func testAGreyFortnightRaisesTheRutAndLetsItBeNamed() {
        var inputs = BookSourceInputs.empty
        inputs.attentionProbes = knocks(grey: 6, of: 10)
        let margins = NothingTide.rutAssessment(inputs: inputs, distressActive: false, now: now)
        XCTAssertEqual(margins.pressure, 2)
        XCTAssertEqual(margins.reportedPressure, 2)
        XCTAssertTrue(margins.mayNameRut)
        XCTAssertTrue(margins.evidence.contains("knock-reported-grey"))

        inputs.attentionProbes = knocks(grey: 8, of: 10)
        XCTAssertEqual(NothingTide.rutAssessment(inputs: inputs, distressActive: false, now: now).reportedPressure, 3)

        inputs.attentionProbes = knocks(grey: 2, of: 10)
        let light = NothingTide.rutAssessment(inputs: inputs, distressActive: false, now: now)
        XCTAssertEqual(light.reportedPressure, 1, "a good fortnight never pulls a reader's own report down, nor adds")
        XCTAssertFalse(light.mayNameRut)

        inputs.attentionProbes = knocks(grey: 4, of: 4)
        XCTAssertNil(NothingTide.knockReportedPressure(inputs.attentionProbes, now: now), "too few answers to say")

        inputs.attentionProbes = knocks(grey: 10, of: 10)
        XCTAssertEqual(NothingTide.rutAssessment(inputs: inputs, distressActive: true, now: now).pressure, 0,
                       "under distress the Rut does not exist")
    }

    // MARK: The rest of the Curse's file

    private func fact(_ questionID: String, answer: String, tags: [String]) -> SelfFact {
        SelfFact(id: questionID, questionID: questionID, question: "Q", answer: answer, bookTranslation: answer,
                 sensitivity: .delight, usePermission: .privateContext, tags: tags, createdAt: now, updatedAt: now)
    }

    private func evidence(facts: [SelfFact] = [], rote: BookFamiliarityRutEngine.Assessment? = nil,
                          signals: InferredReaderSignals = .unwritten, distress: Bool = false) -> [CurseDossier.Finding] {
        CurseEvidence.findings(
            selfFacts: facts,
            rut: NothingTide.RutAssessment(pressure: 2, reportedPressure: 2, mayNameRut: true,
                                           evidence: ["ordinary-life-prior", "knock-reported-grey"]),
            trajectory: .unwritten,
            rote: rote ?? BookFamiliarityRutEngine.Assessment(phase: .clear, flatteningScore: 0, evidence: []),
            handwriting: signals,
            distressActive: distress
        )
    }

    func testNightOneOpensTheFile() throws {
        let findings = evidence(facts: [
            fact("onboarding-routine-memory-proof", answer: "I mostly remember arriving",
                 tags: ["rut-proof", "routine-memory:result"]),
            fact("onboarding-rut-strongest", answer: "My phone eats the edges", tags: ["rut-of-routine"])
        ])
        let night = try XCTUnwrap(findings.first)
        XCTAssertEqual(night.id, "night-one")
        XCTAssertEqual(night.value, "It had taken 2 of 3")
        XCTAssertTrue(night.line.contains("My phone eats the edges"))
        XCTAssertEqual(findings.first { $0.id == "loudness" }?.value, "In the margins")
        XCTAssertTrue(findings.first { $0.id == "loudness" }?.line.contains("your Knocks") ?? false)
    }

    func testHandwritingShowsTheCursesFingerprintsAndYourWins() throws {
        let signals = InferredReaderSignals(
            signals: [
                InferredSignal(measure: .specificity, lean: .rutward, strength: 2, recentSampleCount: 9, priorSampleCount: 9),
                InferredSignal(measure: .sentenceLength, lean: .rutward, strength: 1, recentSampleCount: 9, priorSampleCount: 9),
                InferredSignal(measure: .questionAsking, lean: .aliveward, strength: 1, recentSampleCount: 9, priorSampleCount: 9)
            ],
            computedAt: now,
            isReady: true
        )
        let ink = try XCTUnwrap(evidence(signals: signals).first { $0.id == "handwriting" })
        XCTAssertEqual(ink.value, "Mixed")
        XCTAssertTrue(ink.line.contains("fewer names, places and numbers"))
        XCTAssertTrue(ink.line.contains("more questions"))
    }

    func testTheBookGoingRoteIsShownWithItsSigns() throws {
        let rote = BookFamiliarityRutEngine.Assessment(
            phase: .rote, flatteningScore: 4,
            evidence: ["reader-language-flattened", "knock-latency-became-reflexive"]
        )
        let finding = try XCTUnwrap(evidence(rote: rote).first { $0.id == "rote" })
        XCTAssertEqual(finding.value, "It's got into me")
        XCTAssertTrue(finding.line.hasPrefix("Your souvenirs have gone shorter"))
    }

    func testDistressSilencesTheWholeFileAndEvidenceSurvivesThePage() {
        XCTAssertTrue(evidence(distress: true).isEmpty)
        let findings = evidence()
        XCTAssertEqual(CurseEvidence.decoded(CurseEvidence.encoded(findings)), findings)
        XCTAssertTrue(CurseEvidence.decoded(nil).isEmpty)
    }

    // MARK: The body, the forecast, counter-spells, the camera

    func testLowRecoveryDaysAreMeasuredAgainstTheReadersOwnBody() {
        var ledger = AttentionProbeLedger.empty
        let start = calendar.startOfDay(for: now.addingTimeInterval(-12 * 86_400))
        for day in 0..<10 {
            let at = start.addingTimeInterval(Double(day) * 86_400 + 11 * 3600)
            let low = day < 5
            let grey = low && day != 0
            var snapshot = context(at: at)
            snapshot.heartRateVariability = low ? 30 : 60
            ledger.record(id: "b\(day)", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: grey ? .elsewhere : .here, cycle: 0, context: snapshot)
        }
        let dossier = CurseDossier.build(ledger, calendar: calendar)
        XCTAssertEqual(dossier.findings.first { $0.id == "feeds-on" }?.value, "On a low-recovery day")
    }

    func testTheForecastSaysWhatFeedsItToday() throws {
        let line = try XCTUnwrap(CurseForecast.line(
            ledger: foggyAfternoons(), weatherTags: ["rain"], sleepHours: nil, now: now, calendar: calendar
        ))
        XCTAssertTrue(line.hasPrefix("The Curse's forecast:"))
        XCTAssertTrue(line.contains("Rain feeds it."), line)
        XCTAssertTrue(line.contains("three in the afternoon"), line)
        XCTAssertNil(CurseForecast.line(ledger: .empty, weatherTags: ["rain"], sleepHours: nil, now: now, calendar: calendar))
    }

    func testCounterSpellsTurnWithTheDaysAndAreTested() {
        let today = calendar.startOfDay(for: now)
        let era = calendar.ordinality(of: .day, in: .era, for: today) ?? 0
        let watchDay = today.addingTimeInterval(era % 2 == 0 ? 0 : 86_400)
        let next = watchDay.addingTimeInterval(2 * 86_400)
        XCTAssertNotEqual(CounterSpell.spell(for: watchDay, calendar: calendar),
                          CounterSpell.spell(for: next, calendar: calendar))

        var ledger = AttentionProbeLedger.empty
        for index in 0..<3 {
            let at = watchDay.addingTimeInterval(Double(index) * 2 * 86_400 + 15 * 3600)
            ledger.record(id: "attention-0-day\(index)-15-watch", scheduledAt: at, answeredAt: at.addingTimeInterval(60),
                          answer: index == 0 ? .elsewhere : .here, cycle: 0)
        }
        let finding = CounterSpell.finding(ledger, calendar: calendar)
        XCTAssertEqual(finding?.value, "2 of 3 held")
    }

    func testTheCameraCatchingTheSameThingsIsEvidence() throws {
        func page(_ daysAgo: Double, _ labels: String) -> BookPage {
            BookPage(
                type: .illuminatedPhoto,
                createdAt: now.addingTimeInterval(-daysAgo * 86_400),
                promptText: "A photograph",
                mediaAssets: [BookPageMediaAsset(kind: .renderedImageFile, reference: "/tmp/p.png",
                                                 metadata: ["attentionLabels": labels])]
            )
        }
        let before = [20, 19, 18, 17, 16].map { page(Double($0), ["tree,sky", "dog,park", "bread,table", "river,bridge", "cat,window"][$0 - 16]) }
        let lately = [5, 4, 3, 2, 1].map { page(Double($0), "screen,desk,keyboard") }
        let finding = try XCTUnwrap(PhotoSameness.finding(pages: before + lately, now: now))
        XCTAssertEqual(finding.value, "Seeing the same things")
        XCTAssertTrue(finding.line.hasPrefix("4 of your last 5 photos"), finding.line)
        XCTAssertTrue(finding.line.contains("desk"), finding.line)
    }
}
