import XCTest
@testable import InsideCoverCore

/// Phase 2 of the bound-volumes plan: somebody speaks in the margins.
///
/// The renderer has always drawn hand-inked margin notes; they were filled with
/// the Book's own analytic summaries, so nobody was actually talking. These
/// tests pin the rule that makes the feature honest — the Cast is *quoted*,
/// never paraphrased — and the rule that keeps it readable: no one character
/// gets to heckle from every margin.
final class CastMarginaliaTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var start: Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 1)) ?? Date()
    }
    private var end: Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 23)) ?? Date()
    }

    private func act(
        _ id: String,
        actor: String,
        actorName: String,
        _ act: CastAct,
        _ line: String,
        dayOffset: Int
    ) -> CastActRecord {
        CastActRecord(
            id: id,
            actorID: actor,
            actorName: actorName,
            targetID: "wicker-bramblewick",
            targetName: "Wicker",
            act: act,
            line: line,
            occurredAt: calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start,
            tags: []
        )
    }

    private var pippaAndMook: [CastActRecord] {
        [
            act("a1", actor: "pippa-pilcrow", actorName: "Pippa", .defend,
                "I stood in front of it and dared the Registry to file me too.", dayOffset: 2),
            act("a2", actor: "professor-thaddeus-mook", actorName: "Professor Mook", .correctInPublic,
                "I corrected it in front of everyone, which I maintain was a kindness.", dayOffset: 5),
            act("a3", actor: "pippa-pilcrow", actorName: "Pippa", .confide,
                "I told her the thing I had not told anybody, and then hid behind a semicolon.", dayOffset: 9),
            act("a4", actor: "pippa-pilcrow", actorName: "Pippa", .owe,
                "I owe her one, and I intend to pay it back loudly.", dayOffset: 14)
        ]
    }

    // MARK: Attribution

    func testTheCastIsQuotedNotParaphrased() {
        let notes = CastMarginalia.notes(acts: pippaAndMook, start: start, end: end)
        XCTAssertTrue(
            notes.contains { $0.text == "I stood in front of it and dared the Registry to file me too." },
            "The ledger keeps the exact sentence so it can be quoted; a paraphrase would be the Book putting words in a character's mouth."
        )
    }

    func testNotesCarryTheSpeakersOwnInkAndGlyph() {
        let notes = CastMarginalia.notes(acts: pippaAndMook, start: start, end: end)
        guard let pippa = notes.first(where: { $0.speakerSlug == "pippa-pilcrow" }) else {
            return XCTFail("Pippa acted this month and should be in the margins.")
        }
        XCTAssertEqual(pippa.speakerName, "Pippa Pilcrow", "The voice's canonical name wins over the ledger's short form.")
        XCTAssertEqual(pippa.accentHex, "B5382E")
        XCTAssertEqual(pippa.glyph, "\u{203D}", "Pippa signs with an interrobang.")
        XCTAssertTrue(pippa.isSpoken)
    }

    func testAnUnknownActorStillSpeaksUnderTheirLedgerName() {
        let stranger = [act("s1", actor: "nobody-at-all", actorName: "A Stranger", .withhold,
                            "I kept it to myself.", dayOffset: 3)]
        let note = CastMarginalia.notes(acts: stranger, start: start, end: end).first
        XCTAssertEqual(note?.speakerName, "A Stranger")
        XCTAssertNil(note?.accentHex, "No voice card means no invented ink.")
    }

    // MARK: Restraint

    /// A busy character should not end up shouting from every margin in the
    /// volume. Two notes each keeps the month polyphonic.
    func testNoOneCharacterTakesOverTheMargins() {
        let notes = CastMarginalia.notes(acts: pippaAndMook, start: start, end: end)
        let pippaCount = notes.filter { $0.speakerSlug == "pippa-pilcrow" }.count
        XCTAssertEqual(pippaCount, CastMarginalia.notesPerSpeaker)
        XCTAssertLessThan(pippaCount, 3)
    }

    func testActsOutsideTheMonthNeverReachTheVolume() {
        let stale = [act("old", actor: "pippa-pilcrow", actorName: "Pippa", .defend,
                         "This happened last winter.", dayOffset: -60)]
        XCTAssertTrue(CastMarginalia.notes(acts: stale, start: start, end: end).isEmpty)
    }

    func testEmptyLinesAreNeverPrintedAsBlankMargins() {
        let blank = [act("b1", actor: "pippa-pilcrow", actorName: "Pippa", .defend, "   ", dayOffset: 4)]
        XCTAssertTrue(CastMarginalia.notes(acts: blank, start: start, end: end).isEmpty)
    }

    func testTheBookCanStillSpeakUnattributed() {
        let notes = CastMarginalia.unspokenNotes(["The margins kept their own counsel."])
        XCTAssertFalse(notes[0].isSpoken)
        XCTAssertNil(notes[0].glyph)
    }

    // MARK: In the volume

    func testTheVolumeCarriesCastMarginaliaAndAMovement() {
        let day = BookDay(
            id: BookDay.id(for: start, calendar: calendar),
            date: calendar.startOfDay(for: start),
            pages: [
                BookPage(id: "p1", type: .souvenir, createdAt: start,
                         promptText: "One true sentence", userInput: "A gull argued with a chimney."),
                BookPage(id: "p2", type: .souvenir, createdAt: start,
                         promptText: "One true sentence", userInput: "The harbour kept its minutes.")
            ]
        )
        let edition = MonthlyEditionBuilder.edition(
            from: [day],
            readerName: "Reader",
            startDate: start,
            endDate: end,
            generatedAt: end,
            calendar: calendar,
            castActs: pippaAndMook
        )
        XCTAssertFalse(edition.marginalia?.isEmpty ?? true, "A month the Cast acted in should have voices in its margins.")

        guard let cast = edition.sections.first(where: { $0.id == "what-the-cast-did" }) else {
            return XCTFail("The Cast's own month should be a movement.")
        }
        XCTAssertEqual(cast.resolvedPlacement, .movement)
        XCTAssertEqual(cast.items.count, 4, "Every act in the window is reported, even where the margins only quote two.")
        XCTAssertEqual(cast.items.first?.title, "Pippa")
        XCTAssertEqual(cast.items.map(\.date), cast.items.map(\.date).sorted { ($0 ?? .distantPast) < ($1 ?? .distantPast) })
    }

    func testAQuietMonthGetsNoCastMovementAndNoSpokenMargins() {
        let day = BookDay(
            id: BookDay.id(for: start, calendar: calendar),
            date: calendar.startOfDay(for: start),
            pages: [
                BookPage(id: "p1", type: .souvenir, createdAt: start,
                         promptText: "One true sentence", userInput: "A gull argued with a chimney."),
                BookPage(id: "p2", type: .souvenir, createdAt: start,
                         promptText: "One true sentence", userInput: "The harbour kept its minutes.")
            ]
        )
        let edition = MonthlyEditionBuilder.edition(
            from: [day],
            readerName: "Reader",
            startDate: start,
            endDate: end,
            generatedAt: end,
            calendar: calendar
        )
        XCTAssertNil(edition.marginalia)
        XCTAssertNil(edition.sections.first(where: { $0.id == "what-the-cast-did" }))
    }

    // MARK: The divider plate

    func testTheLeadIsWhoeverActedMost() {
        let lead = CastMarginalia.lead(acts: pippaAndMook, start: start, end: end)
        XCTAssertEqual(lead?.slug, "pippa-pilcrow", "Pippa acted three times to Mook's one.")
        XCTAssertEqual(lead?.name, "Pippa Pilcrow")
    }

    /// Pippa's plate is `LabyrinthCharacterPilcrow`, not the mechanical form of
    /// her slug. Her voice card knows; a guess would not.
    func testAVoiceCardBeatsTheMechanicalGuess() {
        XCTAssertEqual(
            CastMarginalia.plateAssetName(forSlug: "pippa-pilcrow"),
            "LabyrinthCharacterPilcrow"
        )
    }

    func testActorsWithoutAVoiceCardStillPascalCase() {
        XCTAssertEqual(
            CastMarginalia.plateAssetName(forSlug: "orion-blackthorn"),
            "LabyrinthCharacterOrionBlackthorn"
        )
        XCTAssertNil(CastMarginalia.plateAssetName(forSlug: ""))
    }

    func testTiesBreakDeterministicallySoAMonthBindsTheSameTwice() {
        let tied = [
            act("t1", actor: "zara-finch", actorName: "Zara", .confide, "One.", dayOffset: 1),
            act("t2", actor: "pippa-pilcrow", actorName: "Pippa", .defend, "Two.", dayOffset: 2)
        ]
        let first = CastMarginalia.lead(acts: tied, start: start, end: end)
        let second = CastMarginalia.lead(acts: tied.reversed(), start: start, end: end)
        XCTAssertEqual(first?.slug, second?.slug)
    }

    func testAQuietMonthHasNoLead() {
        XCTAssertNil(CastMarginalia.lead(acts: [], start: start, end: end))
    }

    // MARK: The weekly issue

    /// The weekly is a narrower window than a month, so it takes fewer voices.
    /// Three is a conversation; ten inside seven days is a crowd.
    func testTheWeeklyIssueTakesFewerVoicesThanAMonth() {
        let weekStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9)) ?? start
        let days = (0..<8).compactMap { offset -> BookDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayID = BookDay.id(for: date, calendar: calendar)
            return BookDay(
                id: dayID,
                date: calendar.startOfDay(for: date),
                pages: [
                    BookPage(id: "p-\(dayID)", type: .souvenir, createdAt: date,
                             promptText: "One true sentence", userInput: "The harbour kept \(dayID).")
                ]
            )
        }
        let busy = (0..<6).map { index in
            act("w\(index)", actor: "pippa-pilcrow", actorName: "Pippa", .defend,
                "Note number \(index).", dayOffset: index)
        }
        let issue = WeeklyIssue.current(
            days: days,
            boundTales: [],
            readerRole: role(withMark: false),
            castActs: busy,
            now: calendar.date(byAdding: .day, value: 8, to: weekStart) ?? weekStart,
            calendar: calendar
        )
        XCTAssertNotNil(issue?.marginalia)
        XCTAssertLessThanOrEqual(issue?.marginalia?.count ?? 99, 3)
        XCTAssertEqual(issue?.marginalia?.first?.speakerName, "Pippa Pilcrow")
        XCTAssertEqual(issue?.readerRole?.fullName, "The Magpie of the Blue Hour")
    }

    private func role(withMark: Bool) -> BoundReaderRole {
        BoundReaderRole(
            fullName: "The Magpie of the Blue Hour",
            signature: "The Magpie of the Blue Hour, with Quiet Hands",
            gloss: "You come alive when something catches the light.",
            compassLine: "Take one bright thing off the street today.",
            markName: withMark ? "Clear-Eyed" : nil,
            markEvidence: withMark ? "You wrote it down." : nil
        )
    }
}
