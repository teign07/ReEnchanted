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

    func testCapitalizedPlaceBeforeDesignatorIsNotSuggestedAsAPerson() {
        let pages = [
            page("The green cart at Harbor Market squealed in the rain", at: daysAgo(18)),
            page("A gull landed inside Harbor Market before lunch", at: daysAgo(14)),
            page("Receipt paper crossed Harbor Market under the lights", at: daysAgo(8)),
            page("The copper bell at Harbor Market rang once", at: daysAgo(2))
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

    // MARK: Relationship ecology

    func testExistingPersonThreadDecodesWithoutInventingRelationshipContext() throws {
        let json = """
        {
          "id":"person:river",
          "name":"River",
          "introducedDay":"2026-01-02",
          "readerWords":"An old friend",
          "firstMentionDay":"2025-12-01",
          "lastMentionDay":"2026-01-01",
          "mentionPageCount":4,
          "resting":false
        }
        """
        let decoded = try JSONDecoder().decode(PersonThread.self, from: Data(json.utf8))
        XCTAssertNil(decoded.relationship)
        XCTAssertEqual(decoded.name, "River")
    }

    func testReaderConfirmedProfileCleansAndAttributesFacts() {
        let proposed = PersonRelationshipProfile(
            roles: [" Coworker ", "coworker", "friend"],
            settings: [.work, .work],
            channels: [.together],
            sharedInterests: ["AI", " ai "],
            ordinaryRituals: ["Tuesday lunch"],
            boundaries: ["Work stays work"],
            season: "  building something  ",
            invitationPermission: .playful,
            contactIdentifier: "local-contact-1",
            evidence: []
        )
        let profile = PeopleOfTheBook.readerConfirmedProfile(proposed, onDay: "2026-07-19")
        XCTAssertEqual(profile.roles, ["Coworker", "friend"])
        XCTAssertEqual(profile.settings, [.work])
        XCTAssertEqual(profile.sharedInterests, ["AI"])
        XCTAssertEqual(profile.season, "building something")
        XCTAssertEqual(profile.contactIdentifier, "local-contact-1")
        XCTAssertEqual(profile.evidence.count, 8)
        XCTAssertTrue(profile.evidence.allSatisfy { $0.source == .readerConfirmed && $0.recordedDay == "2026-07-19" })
    }

    func testInvitationFamilyFitsHowRelationshipActuallyLives() throws {
        var home = confirmedSam()
        home.relationship = PersonRelationshipProfile(settings: [.sharedHome])
        XCTAssertEqual(
            PeopleOfTheBook.relationshipInvitation(for: home, onDay: "2026-07-19")?.family,
            .sharedHome
        )

        var text = confirmedSam()
        text.name = "Juniper"
        text.id = "person:juniper"
        text.relationship = PersonRelationshipProfile(settings: [.family], channels: [.text])
        XCTAssertEqual(
            PeopleOfTheBook.relationshipInvitation(for: text, onDay: "2026-07-19")?.family,
            .asynchronous
        )

        var work = confirmedSam()
        work.name = "Marisol"
        work.id = "person:marisol"
        work.relationship = PersonRelationshipProfile(settings: [.work], sharedInterests: ["robotics"])
        let invitation = try XCTUnwrap(PeopleOfTheBook.relationshipInvitation(for: work, onDay: "2026-07-19"))
        XCTAssertEqual(invitation.family, .workAndInterest)
        XCTAssertTrue(invitation.title.contains("Marisol") || invitation.body.contains("Marisol"))
        XCTAssertTrue(invitation.body.contains("robotics"))
        XCTAssertTrue(invitation.tags.contains("person:marisol"))
    }

    func testWitnessOnlyIsAHardInvitationBoundary() {
        var thread = confirmedSam()
        thread.relationship = PersonRelationshipProfile(
            settings: [.family],
            invitationPermission: .witnessOnly
        )
        XCTAssertNil(PeopleOfTheBook.relationshipInvitation(for: thread, onDay: "2026-07-19"))
    }

    func testRelationshipHypothesesAskFromExplicitEvidenceWithoutPersistingAGuess() throws {
        var thread = confirmedSam()
        thread.id = "person:rowan"
        thread.name = "Rowan"
        let evidence = days(from: [
            page("I live with Rowan, and the kitchen has become our weather station", at: daysAgo(4), id: "home-proof"),
            page("Texted Rowan about the thunder", at: daysAgo(3), id: "text-proof-1"),
            page("Rowan texted back a photograph", at: daysAgo(2), id: "text-proof-2"),
            page("Rowan and I talk about urban birds.", at: daysAgo(1), id: "interest-proof")
        ])

        let hypotheses = PeopleOfTheBook.relationshipHypotheses(for: thread, days: evidence)
        let home = try XCTUnwrap(hypotheses.first { $0.kind == .setting && $0.value == PersonRelationshipSetting.sharedHome.rawValue })
        XCTAssertEqual(home.evidencePageIDs, ["home-proof"])
        XCTAssertTrue(home.question.contains("share a home"))
        XCTAssertTrue(hypotheses.contains { $0.kind == .channel && $0.value == PersonContactChannel.text.rawValue })
        XCTAssertTrue(hypotheses.contains { $0.kind == .sharedInterest && $0.value == "urban birds" })
        XCTAssertNil(thread.relationship, "A hypothesis is only a question until the reader confirms it.")

        thread.relationship = PersonRelationshipProfile(settings: [.sharedHome], channels: [.text], sharedInterests: ["urban birds"])
        let alreadyKnown = PeopleOfTheBook.relationshipHypotheses(for: thread, days: evidence)
        XCTAssertFalse(alreadyKnown.contains { $0.kind == .setting && $0.value == PersonRelationshipSetting.sharedHome.rawValue })
        XCTAssertFalse(alreadyKnown.contains { $0.kind == .channel && $0.value == PersonContactChannel.text.rawValue })
        XCTAssertFalse(alreadyKnown.contains { $0.kind == .sharedInterest })
    }

    func testLifeKnowledgeGraphConnectsPeopleThroughSharedInterestsWithoutFictionalizingThem() throws {
        var first = confirmedSam()
        first.id = "person:marisol"
        first.name = "Marisol"
        first.relationship = PeopleOfTheBook.readerConfirmedProfile(
            PersonRelationshipProfile(roles: ["coworker"], settings: [.work], sharedInterests: ["AI"]),
            onDay: "2026-07-19"
        )
        var second = confirmedSam()
        second.id = "person:dev"
        second.name = "Dev"
        second.relationship = PeopleOfTheBook.readerConfirmedProfile(
            PersonRelationshipProfile(roles: ["friend"], settings: [.online], sharedInterests: ["AI"]),
            onDay: "2026-07-19"
        )
        var ledger = PeopleLedger()
        ledger.threads = [first, second]
        let sharedPage = page("Marisol and Dev argued cheerfully about AI", at: daysAgo(1), id: "shared-ai-page")

        let graph = PeopleOfTheBook.knowledgeGraph(ledger: ledger, days: days(from: [sharedPage]))
        let interest = try XCTUnwrap(graph.nodes.first { $0.kind == .interest && $0.label == "AI" })
        let peopleTouchingAI = Set(graph.edges.filter { $0.targetID == interest.id }.map(\.sourceID))
        XCTAssertEqual(peopleTouchingAI, Set(["person:marisol", "person:dev"]))
        let pageNode = try XCTUnwrap(graph.nodes.first { $0.kind == .page && $0.id == "life:page:shared-ai-page" })
        let peopleOnSharedPage = Set(graph.edges.filter { $0.targetID == pageNode.id }.map(\.sourceID))
        XCTAssertEqual(peopleOnSharedPage, Set(["person:marisol", "person:dev"]))
        XCTAssertTrue(graph.edges.filter { $0.targetID == pageNode.id }.allSatisfy { $0.provenance == .readerAuthored })
        XCTAssertFalse(graph.nodes.contains { $0.id.hasPrefix("user-cast-") })
        XCTAssertTrue(graph.edges.contains { $0.provenance == .readerConfirmed })

        let atlas = graph.atlasGraph
        XCTAssertEqual(atlas.nodes.count, graph.nodes.count)
        XCTAssertEqual(atlas.edges.count, graph.edges.count)
    }

    func testRelationshipPlaySurfacesBeforeTheArchiveIsMature() throws {
        var thread = confirmedSam()
        thread.relationship = PersonRelationshipProfile(settings: [.work], sharedInterests: ["astronomy"])
        var inputs = BookSourceInputs.empty
        inputs.people.threads = [thread]
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let pages = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        let favor = try XCTUnwrap(pages.first { $0.payload.metadata["personID"] == thread.id })
        XCTAssertEqual(favor.type, .wonderCompass)
        XCTAssertEqual(favor.payload.metadata["relationshipMode"], PeopleOfTheBook.InvitationFamily.workAndInterest.rawValue)
        XCTAssertEqual(favor.payload.metadata["compassMode"], "standalone")
        XCTAssertEqual(favor.payload.metadata["proofKind"], "sentence")
        XCTAssertTrue(favor.payload.metadata["tags"]?.contains("spoke:person-play-sam") == true)
    }

    func testBookAsksBeforeBelievingRelationshipContext() throws {
        var thread = confirmedSam()
        thread.id = "person:rowan"
        thread.name = "Rowan"
        var inputs = BookSourceInputs.empty
        inputs.people.threads = [thread]
        inputs.days = days(from: [
            page("I live with Rowan above the noisy bakery", at: daysAgo(2), id: "relationship-evidence")
        ])
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let pages = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        let question = try XCTUnwrap(pages.first { $0.payload.metadata["personContextHypothesisID"] != nil })
        XCTAssertEqual(question.type, .bookNotices)
        XCTAssertTrue(question.payload.body.contains("I won't write it into their chapter until you say yes"))
        XCTAssertEqual(question.payload.metadata["personContextKind"], PeopleOfTheBook.RelationshipHypothesis.Kind.setting.rawValue)
        XCTAssertEqual(question.payload.metadata["personContextValue"], PersonRelationshipSetting.sharedHome.rawValue)
        XCTAssertTrue(question.payload.metadata["adaptiveActions"]?.contains("confirmPersonContext") == true)
        XCTAssertTrue(question.payload.metadata["adaptiveActions"]?.contains("openPeopleOfTheBook") == true)
        XCTAssertFalse(pages.contains { $0.payload.metadata["playfulMissionID"] != nil }, "The Book asks what is true before tailoring play from it.")
    }

    func testCompanyGraphUsesExistingMarginsAtlasRendererAsASeparateRealm() throws {
        var thread = confirmedSam()
        thread.relationship = PeopleOfTheBook.readerConfirmedProfile(
            PersonRelationshipProfile(roles: ["friend"], sharedInterests: ["night walks"]),
            onDay: "2026-07-19"
        )
        var inputs = BookSourceInputs.empty
        inputs.people.threads = [thread]
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let pages = MarginsAtlasPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        let company = try XCTUnwrap(pages.first { $0.payload.metadata["graphVariant"] == MarginsAtlasVariant.company.rawValue })
        XCTAssertEqual(company.payload.headline, "The Company You Keep")
        XCTAssertTrue(company.payload.metadata["tags"]?.contains("life-knowledge") == true)
        XCTAssertTrue(company.payload.metadata["graphNodes"]?.contains("Sam") == true)
        XCTAssertFalse(company.payload.metadata["tags"]?.contains("loom") == true)
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

    // MARK: The Company You Kept

    func testCompanyYouKeptBindsReaderWordsOffersAndAttributedAftermathWithoutRankingPeople() throws {
        var sam = confirmedSam()
        sam.relationship = PersonRelationshipProfile(
            roles: ["friend"],
            sharedInterests: ["moths"],
            ordinaryRituals: ["Friday photographs"]
        )
        let authored = page(
            "Sam stopped under the pharmacy light to show me a moth with windows in its wings.",
            at: daysAgo(8),
            id: "sam-authored"
        )
        let reference = BookPageExternalReference(
            title: "A moth census",
            sourceName: "Field Notes",
            url: "https://example.org/moths",
            fetchedAt: daysAgo(3),
            provenance: "live-public-web-search"
        )
        let receipt = RelationshipPageReceipt(
            personID: sam.id,
            personName: sam.name,
            kind: .foundGift,
            bookOffer: "Here, I found this for you and Sam.",
            readerAftermath: "We argued about whether the moth looked like stained glass and both changed our minds.",
            sharedInterest: "moths",
            relationshipMode: "sharedInterest",
            evidenceAuthority: "reader-authored-aftermath"
        )
        let found = BookPage(
            id: "sam-found",
            type: .bookNotices,
            createdAt: daysAgo(3),
            promptText: receipt.bookOffer,
            userInput: receipt.readerAftermath ?? "",
            tags: ["people-of-the-book", "person:sam", "relationship-found-gift"],
            sourceID: BookFoundGiftEngine.sourceID,
            origin: .imported,
            privacy: .publicReference,
            externalReference: reference,
            relationshipReceipt: receipt
        )
        let volume = PeopleOfTheBook.companyYouKept(
            ledger: PeopleLedger(threads: [sam]),
            days: days(from: [authored, found]),
            now: now
        )

        XCTAssertEqual(volume.title, "The Company You Kept")
        XCTAssertEqual(volume.chapters.count, 1)
        let chapter = try XCTUnwrap(volume.chapters.first)
        XCTAssertEqual(chapter.name, "Sam")
        XCTAssertEqual(chapter.entries.count, 2)
        XCTAssertEqual(chapter.readerWrittenCount, 2)
        XCTAssertTrue(chapter.entries.contains { $0.authority == .readerWords && $0.pageID == authored.id })
        let aftermath = try XCTUnwrap(chapter.entries.first { $0.authority == .readerAftermath })
        XCTAssertEqual(aftermath.externalReference?.url, reference.url)
        XCTAssertTrue(volume.foreword.contains("not a ranking"))
        XCTAssertFalse(volume.shareText.lowercased().contains("closeness score"))
    }

    func testCompanyYouKeptKeepsUnansweredBookOfferAsOfferNotMemory() throws {
        let sam = confirmedSam()
        let receipt = RelationshipPageReceipt(
            personID: sam.id,
            personName: sam.name,
            kind: .favor,
            bookOffer: "Borrow Sam's eyes",
            readerAftermath: nil,
            sharedInterest: nil,
            relationshipMode: "general",
            evidenceAuthority: "book-offer-only"
        )
        let offer = BookPage(
            id: "offer-only",
            type: .wonderCompass,
            createdAt: daysAgo(2),
            promptText: receipt.bookOffer,
            userInput: "",
            tags: ["person:sam"],
            relationshipReceipt: receipt
        )
        let volume = PeopleOfTheBook.companyYouKept(
            ledger: PeopleLedger(threads: [sam]),
            days: days(from: [offer]),
            now: now
        )
        let entry = try XCTUnwrap(volume.chapters.first?.entries.first)
        XCTAssertEqual(entry.authority, .bookOffer)
        XCTAssertEqual(volume.readerWrittenCount, 0)
        XCTAssertTrue(entry.text.contains("made no claim"))
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
