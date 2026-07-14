import XCTest
@testable import InsideCoverCore

/// The People of the Book — the register for real people. The Book witnesses
/// by default (notices, quotes the reader, marks absences and returns); the
/// reader may write a person into the story, which links a custom cast
/// member to the thread — the crossing is always the reader's act. These
/// tests cover the evidence standards (two-sided, spanning real days), the
/// rituals, and the missions that aim the lens at company.
final class PeopleOfTheBookTests: XCTestCase {

    // A Monday, so daysAgo arithmetic lands on predictable weekdays.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 12))!

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func page(
        _ text: String,
        at date: Date,
        id: String = UUID().uuidString,
        type: BookPageType = .diary
    ) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: date,
            promptText: "Prompt",
            userInput: text,
            origin: .userAuthored
        )
    }

    /// A BookDay whose id matches its pages' calendar day — `capturedPages`
    /// windows on the parsed id, so a mislabeled day hides its pages.
    private func day(pages: [BookPage]) -> BookDay {
        let anchor = pages.first?.createdAt ?? now
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: anchor)
        let id = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
        return BookDay(id: id, date: Calendar.current.startOfDay(for: anchor), pages: pages)
    }

    private func days(from pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .values
            .map { day(pages: $0.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.id < $1.id }
    }

    private func suggestions(
        _ pages: [BookPage],
        ledger: PeopleLedger = PeopleLedger(),
        excluded: Set<String> = []
    ) -> [PeopleOfTheBook.PersonSuggestion] {
        PeopleOfTheBook.suggestions(days: days(from: pages), ledger: ledger, excludedNames: excluded, now: now)
    }

    /// Five mid-sentence mentions across five days and a two-week span.
    private var samPages: [BookPage] {
        [
            page("Walked with Sam by the water today", at: daysAgo(15)),
            page("Lunch with Sam went long and neither of us minded", at: daysAgo(11)),
            page("Told Sam about the kettle and the fog", at: daysAgo(7)),
            page("The bakery line was long but Sam waited with me", at: daysAgo(3)),
            page("Coffee with Sam before the rain came in", at: daysAgo(1))
        ]
    }

    // MARK: Suggestions

    func testRecurringNameIsSuggested() throws {
        let result = suggestions(samPages)
        XCTAssertEqual(result.count, 1)
        let sam = try XCTUnwrap(result.first)
        XCTAssertEqual(sam.name, "Sam")
        XCTAssertEqual(sam.slug, "sam")
        XCTAssertEqual(sam.mentionPageCount, 5)
        XCTAssertEqual(sam.distinctDayCount, 5)
        XCTAssertTrue(sam.sampleQuote.contains("Sam"))
        XCTAssertFalse(sam.evidencePageIDs.isEmpty)
    }

    func testSentenceInitialCapitalsAreNotEvidence() {
        let pages = [
            page("Sam came by. Sam left early.", at: daysAgo(15)),
            page("Sam again today.", at: daysAgo(11)),
            page("Sam called twice.", at: daysAgo(7)),
            page("Sam waited outside.", at: daysAgo(3)),
            page("Sam brought bread.", at: daysAgo(1))
        ]
        XCTAssertTrue(suggestions(pages).isEmpty)
    }

    func testCommonNounWearingACapitalIsSkipped() {
        // "Harbor" arrives mid-sentence capitalized, but the reader writes
        // "harbor" lowercased just as often — a place-word, not a person.
        let pages = [
            page("We walked to Harbor for the light. I love the harbor", at: daysAgo(15)),
            page("Back at Harbor again, the harbor was loud", at: daysAgo(11)),
            page("Met nobody at Harbor, the harbor kept its own company", at: daysAgo(6)),
            page("Skipped Harbor today, missed the harbor anyway", at: daysAgo(1))
        ]
        XCTAssertTrue(suggestions(pages).isEmpty)
    }

    func testCastCalendarAndAppWordsAreNeverSuggested() {
        let pages = [
            page("Talked with Zara about Tuesday and the Book", at: daysAgo(15)),
            page("Saw Zara before Tuesday came around, the Book noticed", at: daysAgo(11)),
            page("Asked Zara about next Tuesday and the Book agreed", at: daysAgo(6)),
            page("Waved at Zara on Tuesday while the Book slept", at: daysAgo(1))
        ]
        XCTAssertTrue(suggestions(pages, excluded: ["Zara Finch"]).isEmpty)
    }

    func testYoungEvidenceStaysSilent() {
        // Enough pages but a burst inside one week: span too short.
        let burst = [
            page("Walked with Ana by the pond", at: daysAgo(6)),
            page("Lunch with Ana downtown", at: daysAgo(4, hour: 9)),
            page("Told Ana about the fog", at: daysAgo(2)),
            page("Coffee with Ana again", at: daysAgo(1))
        ]
        XCTAssertTrue(suggestions(burst).isEmpty)

        // Enough span but too few pages.
        let sparse = [
            page("Walked with Ana by the pond", at: daysAgo(20)),
            page("Lunch with Ana downtown", at: daysAgo(10)),
            page("Coffee with Ana again", at: daysAgo(1))
        ]
        XCTAssertTrue(suggestions(sparse).isEmpty)
    }

    func testKnownAndRestingNamesAreQuiet() {
        var ledger = PeopleLedger()
        ledger.threads = [
            PersonThread(
                id: "person:sam",
                name: "Sam",
                introducedDay: "2026-06-01",
                readerWords: "",
                firstMentionDay: "2026-05-01",
                lastMentionDay: "2026-07-01",
                mentionPageCount: 5
            )
        ]
        XCTAssertTrue(suggestions(samPages, ledger: ledger).isEmpty)

        var resting = PeopleLedger()
        resting.restingNames = ["sam"]
        XCTAssertTrue(suggestions(samPages, ledger: resting).isEmpty)
    }

    func testSuggestionsAreDeterministic() {
        let pages = samPages
        let first = suggestions(pages)
        let second = suggestions(pages)
        XCTAssertEqual(first, second)
    }

    // MARK: Quiet and return

    private func confirmedSam() -> PersonThread {
        PersonThread(
            id: "person:Sam",
            name: "Sam",
            introducedDay: "2026-05-01",
            readerWords: "My oldest friend",
            firstMentionDay: "2026-04-01",
            lastMentionDay: "2026-05-20",
            mentionPageCount: 5
        )
    }

    func testConfirmedThreadGoneQuiet() throws {
        let pages = [
            page("Walked with Sam by the water", at: daysAgo(70)),
            page("Sam brought bread over", at: daysAgo(60)),
            page("Long talk with Sam about nothing", at: daysAgo(50)),
            page("Sam and the dog and the rain", at: daysAgo(40))
        ]
        var ledger = PeopleLedger()
        ledger.threads = [confirmedSam()]
        let signals = PeopleOfTheBook.quietSignals(ledger: ledger, days: days(from: pages), now: now)
        XCTAssertEqual(signals.count, 1)
        let signal = try XCTUnwrap(signals.first)
        XCTAssertEqual(signal.kind, .goneQuiet)
        XCTAssertEqual(signal.quietDays, 40)
    }

    func testThreadReturnAfterLongQuiet() throws {
        let pages = [
            page("Walked with Sam by the water", at: daysAgo(90)),
            page("Sam brought bread over", at: daysAgo(80)),
            page("Long talk with Sam about nothing", at: daysAgo(70)),
            page("Sam again, finally, after all this time", at: daysAgo(2))
        ]
        var ledger = PeopleLedger()
        ledger.threads = [confirmedSam()]
        let signals = PeopleOfTheBook.quietSignals(ledger: ledger, days: days(from: pages), now: now)
        XCTAssertEqual(signals.count, 1)
        let signal = try XCTUnwrap(signals.first)
        XCTAssertEqual(signal.kind, .returned)
        XCTAssertEqual(signal.quietDays, 68)
    }

    func testRestingThreadNeverSignals() {
        let pages = [
            page("Walked with Sam by the water", at: daysAgo(70)),
            page("Sam brought bread over", at: daysAgo(60)),
            page("Long talk with Sam about nothing", at: daysAgo(50)),
            page("Sam and the dog and the rain", at: daysAgo(40))
        ]
        var ledger = PeopleLedger()
        ledger.threads = [PeopleOfTheBook.rested(confirmedSam(), onDay: "2026-06-30")]
        XCTAssertTrue(PeopleOfTheBook.quietSignals(ledger: ledger, days: days(from: pages), now: now).isEmpty)
    }

    func testThreadWithThinHistoryStaysQuiet() {
        // Two mentions is a memory, not a rhythm — no absence remark.
        let pages = [
            page("Walked with Sam by the water", at: daysAgo(70)),
            page("Sam brought bread over", at: daysAgo(60))
        ]
        var ledger = PeopleLedger()
        ledger.threads = [confirmedSam()]
        XCTAssertTrue(PeopleOfTheBook.quietSignals(ledger: ledger, days: days(from: pages), now: now).isEmpty)
    }

    func testVeryOldSilenceBelongsToTheReader() {
        // Past the ceiling the Book stops remarking on the quiet.
        let pages = [
            page("Walked with Sam by the water", at: daysAgo(300)),
            page("Sam brought bread over", at: daysAgo(290)),
            page("Long talk with Sam about nothing", at: daysAgo(280)),
            page("Sam and the dog and the rain", at: daysAgo(270))
        ]
        var ledger = PeopleLedger()
        ledger.threads = [confirmedSam()]
        XCTAssertTrue(PeopleOfTheBook.quietSignals(ledger: ledger, days: days(from: pages), now: now).isEmpty)
    }

    // MARK: Rituals

    func testRestRitualMarksThread() {
        let rested = PeopleOfTheBook.rested(confirmedSam(), onDay: "2026-07-06")
        XCTAssertTrue(rested.resting)
        XCTAssertEqual(rested.restDay, "2026-07-06")
    }

    func testStoryCrossingLinksCastMemberAndKeepsWitnessThread() {
        let invited = PeopleOfTheBook.invitedIntoStory(confirmedSam(), castMemberID: "user-cast-sam-abc123", onDay: "2026-07-06")
        XCTAssertEqual(invited.castMemberID, "user-cast-sam-abc123")
        XCTAssertEqual(invited.invitedDay, "2026-07-06")
        // The witness side of the thread is untouched by the crossing.
        XCTAssertFalse(invited.resting)
        XCTAssertEqual(invited.name, "Sam")
        XCTAssertEqual(invited.mentionPageCount, confirmedSam().mentionPageCount)
    }

    func testInvitedThreadStillGetsQuietSignals() {
        // Writing someone into the story does not silence the witness: the
        // real-pages thread still notices absence.
        let pages = [
            page("Walked with Sam by the water", at: daysAgo(70)),
            page("Sam brought bread over", at: daysAgo(60)),
            page("Long talk with Sam about nothing", at: daysAgo(50)),
            page("Sam and the dog and the rain", at: daysAgo(40))
        ]
        var ledger = PeopleLedger()
        ledger.threads = [PeopleOfTheBook.invitedIntoStory(confirmedSam(), castMemberID: "user-cast-sam-abc123", onDay: "2026-06-01")]
        let signals = PeopleOfTheBook.quietSignals(ledger: ledger, days: days(from: pages), now: now)
        XCTAssertEqual(signals.map(\.kind), [.goneQuiet])
    }

    func testConfirmedSuggestionBecomesThread() throws {
        let suggestion = try XCTUnwrap(suggestions(samPages).first)
        let thread = PeopleOfTheBook.confirmed(suggestion, onDay: "2026-07-06", readerWords: "My neighbor")
        XCTAssertEqual(thread.id, "person:sam")
        XCTAssertEqual(thread.name, "Sam")
        XCTAssertEqual(thread.introducedDay, "2026-07-06")
        XCTAssertEqual(thread.readerWords, "My neighbor")
        XCTAssertEqual(thread.mentionPageCount, 5)
    }

    // MARK: The ledger survives the save file

    func testPeopleLedgerRoundTripsThroughVaultCoding() throws {
        var vault = PlayerVaultData()
        var ledger = PeopleLedger()
        ledger.threads = [
            PeopleOfTheBook.invitedIntoStory(confirmedSam(), castMemberID: "user-cast-sam-abc123", onDay: "2026-07-01")
        ]
        ledger.restingNames = ["harbor"]
        vault.people = ledger
        let data = try JSONEncoder().encode(vault)
        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: data)
        XCTAssertEqual(decoded.people, ledger)
    }

    // MARK: Pre-meeting charges

    private func event(_ title: String, id: String = "event-1", inHours hours: Double, allDay: Bool = false) -> CalendarEventSignal {
        CalendarEventSignal(
            id: id,
            title: title,
            startsAt: now.addingTimeInterval(hours * 3600),
            isAllDay: allDay
        )
    }

    func testChargeArmsForConfirmedThreadInEventTitle() throws {
        var ledger = PeopleLedger()
        ledger.threads = [confirmedSam()]
        let charges = PeopleOfTheBook.preMeetingCharges(
            ledger: ledger,
            events: [event("Coffee with Sam", inHours: 3)],
            now: now
        )
        XCTAssertEqual(charges.count, 1)
        let charge = try XCTUnwrap(charges.first)
        XCTAssertEqual(charge.personName, "Sam")
        XCTAssertEqual(charge.personSlug, "sam")
        // Fires one hour before a 15:00 meeting.
        XCTAssertEqual(charge.fireAt, now.addingTimeInterval(2 * 3600))
        XCTAssertEqual(charge.title, "You see Sam at 3")
        XCTAssertTrue(charge.body.hasPrefix("A mission, if you want it: "))
        XCTAssertTrue(charge.tags.contains("person-charge"))
        XCTAssertTrue(charge.tags.contains("person:sam"))
    }

    func testChargeIgnoresUnknownRestingAllDayAndImminentEvents() {
        var ledger = PeopleLedger()
        ledger.threads = [PeopleOfTheBook.rested(confirmedSam(), onDay: "2026-07-01")]
        // Resting thread: silent.
        XCTAssertTrue(PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: [event("Coffee with Sam", inHours: 3)], now: now).isEmpty)

        ledger.threads = [confirmedSam()]
        // No thread named in the title, and whole-word matching holds:
        // "Samples review" is not Sam.
        XCTAssertTrue(PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: [event("Samples review", inHours: 3)], now: now).isEmpty)
        // All-day events carry no meeting hour.
        XCTAssertTrue(PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: [event("Sam birthday", inHours: 3, allDay: true)], now: now).isEmpty)
        // Too imminent to interrupt for.
        XCTAssertTrue(PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: [event("Coffee with Sam", inHours: 0.25)], now: now).isEmpty)
        // Beyond the arming horizon.
        XCTAssertTrue(PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: [event("Coffee with Sam", inHours: 48)], now: now).isEmpty)
    }

    func testChargesCapAtTwoAndStayDeterministic() {
        var ledger = PeopleLedger()
        ledger.threads = [confirmedSam()]
        let events = [
            event("Coffee with Sam", id: "e1", inHours: 2),
            event("Lunch with Sam", id: "e2", inHours: 5),
            event("Dinner with Sam", id: "e3", inHours: 9)
        ]
        let first = PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: events, now: now)
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(first.map(\.eventID), ["e1", "e2"])
        XCTAssertEqual(first, PeopleOfTheBook.preMeetingCharges(ledger: ledger, events: events, now: now))
    }

    func testTimeLabelReadsLikeSpeech() {
        let three = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: now)!
        XCTAssertEqual(PeopleOfTheBook.timeLabel(for: three), "3")
        let threeThirty = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: now)!
        XCTAssertEqual(PeopleOfTheBook.timeLabel(for: threeThirty), "3:30")
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        XCTAssertEqual(PeopleOfTheBook.timeLabel(for: noon), "12")
    }

    // MARK: People missions

    func testPeopleMissionsJoinThePool() {
        XCTAssertEqual(PlayfulMissionRegistry.peopleMissions.count, 8)
        for mission in PlayfulMissionRegistry.peopleMissions {
            XCTAssertTrue(mission.tags.contains("people"), "\(mission.id) should carry the people tag")
            XCTAssertTrue(mission.tags.contains("connection"), "\(mission.id) should carry the connection tag")
            XCTAssertFalse(mission.allowsPhoto, "people missions keep proof in words, not photos")
        }
        let poolIDs = PlayfulMissionRegistry.missions.map(\.id)
        XCTAssertEqual(poolIDs.count, Set(poolIDs).count, "mission ids must stay unique")
        for mission in PlayfulMissionRegistry.peopleMissions {
            XCTAssertTrue(poolIDs.contains(mission.id))
        }
    }
}
