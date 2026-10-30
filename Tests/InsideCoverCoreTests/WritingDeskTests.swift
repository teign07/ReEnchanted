import XCTest
@testable import InsideCoverCore

/// Phase 3 of docs/noticing-and-writing-sessions-plan.md: "I want to write,
/// please?". The model itself only runs on a device; everything around it
/// (what the Book wants, when it asks, what it holds, when it lets go) is
/// plain logic and lives here.
final class WritingDeskTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_900_000)

    private func souvenir(_ id: String, hoursAgo: Double, text: String = "The bakery window had a cat asleep on the bread again.") -> BookPage {
        BookPage(id: id, type: .souvenir, createdAt: now.addingTimeInterval(-hoursAgo * 3_600),
                 promptText: "", userInput: text, origin: .userAuthored)
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { Calendar.current.startOfDay(for: $0.createdAt) }
            .map { BookDay(id: BookDay.id(for: $0.key), date: $0.key, pages: $0.value) }
    }

    private func preparedNote(prose: String) -> SurfacePage {
        SurfacePage(
            id: "note-draft", type: .note, sourceID: "student-notes", intent: .reflect, renderStyle: .loreLetter,
            score: 60, reason: "", prompt: "", detail: "",
            payload: BookPagePayload(headline: "Note from Penny Blackletter", body: prose,
                                     metadata: ["noteProse": prose, "senderName": "Penny Blackletter", "tags": "note"])
        )
    }

    func testARecentSouvenirBecomesAWantWithAVoicedSpeaker() throws {
        let archive = days([
            souvenir("fresh", hoursAgo: 5),
            souvenir("thin", hoursAgo: 4, text: "Rain."),
            souvenir("old", hoursAgo: 100)
        ])
        let desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now)

        XCTAssertEqual(desk.wants.map(\.id), ["cast-thought:fresh"])
        let want = try XCTUnwrap(desk.wants.first)
        XCTAssertTrue(CharacterVoiceCatalog.priorityCharacterIDs.contains(want.speakerID))
        // Same page, same speaker, every time.
        XCTAssertEqual(WritingDeskPlanner.speaker(for: "fresh", avoiding: [])?.id,
                       WritingDeskPlanner.speaker(for: "fresh", avoiding: [])?.id)
        // Refreshing again doesn't add it twice.
        XCTAssertEqual(WritingDeskPlanner.refreshed(desk, days: archive, now: now).wants.count, 1)
    }

    func testTheBookAsksOnceADayAndOnlyWhenItCanWrite() {
        let archive = days([souvenir("fresh", hoursAgo: 5)])
        var desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now)

        XCTAssertFalse(WritingDeskPlanner.shouldAsk(desk, localBrainReady: false, now: now))
        XCTAssertTrue(WritingDeskPlanner.shouldAsk(desk, localBrainReady: true, now: now))
        desk.lastAnsweredAt = now.addingTimeInterval(-60)
        XCTAssertFalse(WritingDeskPlanner.shouldAsk(desk, localBrainReady: true, now: now), "Later means not again today")
        XCTAssertFalse(WritingDeskPlanner.shouldAsk(WritingDesk(), localBrainReady: true, now: now), "nothing to write, no ask")
    }

    func testTheAskSaysWhatItWantsAndNotWhat() {
        let archive = days([souvenir("fresh", hoursAgo: 5)])
        let desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now)
        let ask = WritingDeskPlanner.askSurface(desk, day: archive[0], now: now)

        XCTAssertEqual(ask.payload.headline, "I Want to Write")
        XCTAssertTrue(ask.payload.body.hasPrefix("I want to write something. Please?"))
        XCTAssertFalse(ask.payload.body.localizedCaseInsensitiveContains("Penny"), "the subject stays hidden")
        XCTAssertFalse(ask.payload.body.localizedCaseInsensitiveContains("souvenir"))
        XCTAssertEqual(ask.payload.metadata[WritingDeskPlanner.askMetadataKey], "true")
    }

    func testHeldWritingWaitsThenRevealsExactlyAsWritten() throws {
        let page = souvenir("fresh", hoursAgo: 5)
        let archive = days([page])
        var desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now)
        let want = try XCTUnwrap(desk.wants.first)
        let prose = "The cat on the bread is filed under Exhibit A. I'm not saying it's a crime."
        desk.drawer.append(WritingDeskPlanner.held(
            want: want, speakerName: "Penny Blackletter", surface: preparedNote(prose: prose), days: archive, now: now
        ))

        XCTAssertTrue(WritingDeskPlanner.release(desk, days: archive, now: now.addingTimeInterval(3_600)).ready.isEmpty,
                      "written today, given later")
        let later = now.addingTimeInterval(WritingDeskPlanner.holdFor + 60)
        let ready = try XCTUnwrap(WritingDeskPlanner.release(desk, days: archive, now: later).ready.first)
        let revealed = WritingDeskPlanner.revealSurface(ready, now: later)

        XCTAssertEqual(revealed.payload.metadata["noteProse"], prose, "revealed, never rewritten")
        XCTAssertFalse(SurfaceReadinessState(surface: revealed).needsLocalBrainToOpen)
        XCTAssertEqual(revealed.prompt, "Penny Blackletter left you something.")
        XCTAssertTrue(revealed.payload.metadata["tags"]?.contains("held-writing:cast-thought:fresh") == true)
    }

    func testAnEditedSouvenirWithdrawsWhatWasWrittenAboutIt() throws {
        let page = souvenir("fresh", hoursAgo: 5)
        var desk = WritingDeskPlanner.refreshed(WritingDesk(), days: days([page]), now: now)
        let want = try XCTUnwrap(desk.wants.first)
        desk.drawer.append(WritingDeskPlanner.held(
            want: want, speakerName: "Penny Blackletter", surface: preparedNote(prose: "About the cat."),
            days: days([page]), now: now
        ))
        var edited = page
        edited.userInput = "Actually it was a dog, and it was awake."
        let later = now.addingTimeInterval(WritingDeskPlanner.holdFor + 60)

        let release = WritingDeskPlanner.release(desk, days: days([edited]), now: later)
        XCTAssertTrue(release.ready.isEmpty)
        XCTAssertEqual(release.withdrawn, ["cast-thought:fresh"])
        let settled = WritingDeskPlanner.settled(desk, days: days([edited]), now: later)
        XCTAssertEqual(settled.drawer.first?.disposition, .withdrawn)
        XCTAssertEqual(settled.heldCount, 0, "a withdrawn piece doesn't hold up the next ask")
    }

    func testAKeptPieceBecomesTheReadersAndIsNeverWrittenAgain() throws {
        let page = souvenir("fresh", hoursAgo: 5)
        var desk = WritingDeskPlanner.refreshed(WritingDesk(), days: days([page]), now: now)
        let want = try XCTUnwrap(desk.wants.first)
        desk.drawer.append(WritingDeskPlanner.held(
            want: want, speakerName: "Penny Blackletter", surface: preparedNote(prose: "About the cat."),
            days: days([page]), now: now
        ))
        desk.wants.removeAll()
        var kept = BookPage(id: "kept-note", type: .note, createdAt: now.addingTimeInterval(16 * 3_600), promptText: "")
        kept.tags = ["note", "held-writing", "held-writing:cast-thought:fresh"]
        let archive = days([page, kept])

        let settled = WritingDeskPlanner.refreshed(desk, days: archive, now: now.addingTimeInterval(17 * 3_600))
        XCTAssertEqual(settled.drawer.first?.disposition, .revealed)
        XCTAssertTrue(settled.wants.isEmpty, "the Souvenir already has its note")
        XCTAssertTrue(WritingDeskPlanner.release(settled, days: archive, now: now.addingTimeInterval(17 * 3_600)).ready.isEmpty)
    }

    func testTheDeskAdapterAsksAndHandsBackOneADay() throws {
        let page = souvenir("fresh", hoursAgo: 30)
        let archive = days([page])
        var inputs = BookSourceInputs()
        inputs.days = archive
        inputs.localBrainIsReady = true
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let asking = WritingDeskPageSourceAdapter().candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
        XCTAssertTrue(asking.contains { $0.payload.metadata[WritingDeskPlanner.askMetadataKey] == "true" })

        var desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now.addingTimeInterval(-20 * 3_600))
        let want = try XCTUnwrap(desk.wants.first)
        desk.drawer.append(WritingDeskPlanner.held(
            want: want, speakerName: "Penny Blackletter", surface: preparedNote(prose: "About the cat."),
            days: archive, now: now.addingTimeInterval(-20 * 3_600)
        ))
        desk.lastAnsweredAt = now.addingTimeInterval(-60)
        inputs.writingDesk = desk
        let giving = WritingDeskPageSourceAdapter().candidates(for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now)
        XCTAssertEqual(giving.map(\.id), ["held-cast-thought:fresh"], "answered today: no ask, just the held note")
    }

    // MARK: Thinking jobs

    func testVerdictsParseStrictly() {
        XCTAssertEqual(WritingDeskPlanner.parseVerdict("KEEP: ok", now: now)?.keep, true)
        let obvious = WritingDeskPlanner.parseVerdict("DROP: obvious", now: now)
        XCTAssertEqual(obvious?.keep, false)
        XCTAssertEqual(obvious?.reason, "obvious")
        XCTAssertEqual(WritingDeskPlanner.parseVerdict("KEEP: boring", now: now)?.keep, false,
                       "a reason that says drop wins over the word keep")
        XCTAssertNil(WritingDeskPlanner.parseVerdict("I think this is lovely!", now: now))
    }

    func testRereadsParseStrictly() {
        XCTAssertEqual(WritingDeskPlanner.parseReread("KEEP"), .some(nil))
        XCTAssertEqual(WritingDeskPlanner.parseReread("CROSS OUT: it invents a dog"), .some("it invents a dog"))
        XCTAssertNil(WritingDeskPlanner.parseReread("Hmm, maybe."))
    }

    /// Rain days and a slower heart: one strong crossing to judge.
    private func rainHeartArchive() -> [BookDay] {
        days((1...60).map { ago -> BookPage in
            let rainy = ago % 4 == 0
            let at = now.addingTimeInterval(-Double(ago) * 86_400 + Double(ago % 8) * 3_600)
            return BookPage(
                id: "rh\(ago)", type: .diary, createdAt: at, promptText: "",
                userInput: "The gulls were loud about something again, number \(ago).", origin: .userAuthored,
                context: BookPageContextSnapshot(at: at, weatherTags: rainy ? ["rain"] : ["bright"],
                                                 restingHeartRate: (rainy ? 56 : 66) + ago % 3)
            )
        })
    }

    func testTheStrongestNoticingWaitsForAVerdictAndADropKeepsItOffTheDesk() throws {
        let archive = rainHeartArchive()
        let desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now)
        let verdictWant = try XCTUnwrap(desk.wants.first { $0.kind == .noticingVerdict })
        XCTAssertEqual(desk.wants.first?.kind, .noticingVerdict, "short judgments come first")
        let noticingID = try XCTUnwrap(verdictWant.subject)

        var inputs = BookSourceInputs()
        inputs.days = archive
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let before = BookNoticesPageSourceAdapter().crossingSurfaces(for: today, inputs: inputs, now: now)
        XCTAssertTrue(before.contains { $0.payload.metadata["crossingID"] == noticingID })

        inputs.writingDesk = WritingDeskPlanner.withVerdict(
            desk, noticingID: noticingID,
            verdict: NoticingVerdict(keep: false, reason: "obvious", judgedAt: now), now: now
        )
        XCTAssertFalse(inputs.writingDesk.wants.contains { $0.id == verdictWant.id })
        let after = BookNoticesPageSourceAdapter().crossingSurfaces(for: today, inputs: inputs, now: now)
        XCTAssertFalse(after.contains { $0.payload.metadata["crossingID"] == noticingID })
        XCTAssertFalse(WritingDeskPlanner.refreshed(inputs.writingDesk, days: archive, now: now)
            .wants.contains { $0.subject == noticingID }, "judged once is enough")
    }

    func testHeldWritingIsRereadAndCanBeCrossedOut() throws {
        let page = souvenir("fresh", hoursAgo: 20)
        let archive = days([page])
        var desk = WritingDeskPlanner.refreshed(WritingDesk(), days: archive, now: now.addingTimeInterval(-10 * 3_600))
        let want = try XCTUnwrap(desk.wants.first { $0.kind == .castThought })
        desk.drawer.append(WritingDeskPlanner.held(
            want: want, speakerName: "Penny Blackletter", surface: preparedNote(prose: "About the dog."),
            days: archive, now: now.addingTimeInterval(-10 * 3_600)
        ))
        desk.wants.removeAll { $0.id == want.id }

        let refreshed = WritingDeskPlanner.refreshed(desk, days: archive, now: now)
        let reread = try XCTUnwrap(refreshed.wants.first { $0.kind == .reread })
        XCTAssertEqual(reread.subject, want.id)

        let crossed = WritingDeskPlanner.withReread(refreshed, pieceID: want.id, crossedOut: "it invents a dog", now: now)
        XCTAssertEqual(crossed.drawer.first?.disposition, .withdrawn)
        XCTAssertEqual(crossed.drawer.first?.crossedOutReason, "it invents a dog")
        XCTAssertTrue(WritingDeskPlanner.release(crossed, days: archive, now: now.addingTimeInterval(86_400)).ready.isEmpty)

        let kept = WritingDeskPlanner.withReread(refreshed, pieceID: want.id, crossedOut: nil, now: now)
        XCTAssertEqual(kept.drawer.first?.disposition, .held)
        XCTAssertFalse(WritingDeskPlanner.refreshed(kept, days: archive, now: now).wants.contains { $0.kind == .reread },
                       "reread once")
    }

    func testADeskSavedBeforeThinkingJobsStillOpens() throws {
        let older = #"{"wants":[],"drawer":[]}"#
        let desk = try JSONDecoder().decode(WritingDesk.self, from: Data(older.utf8))
        XCTAssertNil(desk.verdicts)
        XCTAssertNil(desk.finishedSubjects)
    }

    func testAnOlderVaultOpensWithAnEmptyDesk() throws {
        let blank = try JSONEncoder().encode(PlayerVaultData())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: blank) as? [String: Any])
        object.removeValue(forKey: "writingDesk")
        let older = try JSONDecoder().decode(PlayerVaultData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(older.writingDesk)

        var data = PlayerVaultData()
        data.writingDesk = WritingDesk(wants: [], drawer: [], lastAnsweredAt: now)
        let roundTrip = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(roundTrip.writingDesk, data.writingDesk)
    }
}
