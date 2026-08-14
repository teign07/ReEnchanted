import XCTest
@testable import InsideCoverCore

final class BookPersonalityTests: XCTestCase {
    private let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 19, hour: 15)
    )!

    private func page(_ id: String, type: BookPageType = .souvenir, tags: [String] = []) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: now.addingTimeInterval(-86_400),
            promptText: "Keep one true thing.",
            userInput: "The blue mug caught the afternoon light.",
            tags: tags
        )
    }

    private func day(pageCount: Int) -> BookDay {
        BookDay(
            id: "2026-07-18",
            date: now.addingTimeInterval(-86_400),
            pages: (0..<pageCount).map { page("page-\($0)") }
        )
    }

    func testRelationshipLedgerTurnsDurableCorrectionIntoIntentRatherThanContrition() {
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pageCount: 6)]
        inputs.learnedBraidNotes = ["The mornings are slow, not sad."]
        inputs.bookObservations = [
            BookObservationRecord(
                id: "morning-reading",
                kind: "manner",
                status: .questioned,
                evidencePageIDs: ["page-1", "page-2"],
                firstPresentedAt: now.addingTimeInterval(-3_600),
                updatedAt: now.addingTimeInterval(-3_600)
            )
        ]

        let relationship = BookRelationshipLedger.snapshot(inputs: inputs, now: now)

        XCTAssertEqual(relationship.stance, .intent)
        XCTAssertEqual(relationship.depth, .acquainted)
        XCTAssertEqual(relationship.softenedReadingCount, 1)
        XCTAssertTrue(relationship.hasBeenTaught)
        XCTAssertTrue(relationship.promptSection.contains("The mornings are slow, not sad."))
        XCTAssertTrue(BookRelationshipVoice.openingLine(for: relationship)?.contains("both eyes") == true)
    }

    func testConfirmedReadingIsPleasedEvenAfterQuietDays() {
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pageCount: 6)]
        inputs.quietDays = 4
        inputs.bookObservations = [
            BookObservationRecord(
                id: "true-reading",
                kind: "pattern",
                status: .confirmed,
                evidencePageIDs: ["page-1", "page-2"],
                firstPresentedAt: now.addingTimeInterval(-600),
                updatedAt: now.addingTimeInterval(-600)
            )
        ]

        let relationship = BookRelationshipLedger.snapshot(inputs: inputs, now: now)
        let line = BookRelationshipVoice.openingLine(for: relationship) ?? ""

        XCTAssertEqual(relationship.stance, .pleased)
        XCTAssertTrue(line.contains("Ha!"), line)
        XCTAssertTrue(line.contains("strutting"), line)
        XCTAssertFalse(line.localizedCaseInsensitiveContains("corrected"), line)
        XCTAssertFalse(line.localizedCaseInsensitiveContains("sorry"), line)
    }

    func testNoticeFeedbackReactionsKeepTheirPolarity() {
        let praise = BookObservationStatus.confirmed.feedbackReactionLine
        let correction = BookObservationStatus.notQuite.feedbackReactionLine
        let boundary = BookObservationStatus.doNotRead.feedbackReactionLine

        XCTAssertTrue(praise.contains("Yes!"), praise)
        XCTAssertTrue(praise.contains("strutting"), praise)
        XCTAssertFalse(praise.localizedCaseInsensitiveContains("correction"), praise)
        XCTAssertFalse(praise.localizedCaseInsensitiveContains("wrong"), praise)
        XCTAssertFalse(praise.localizedCaseInsensitiveContains("sorry"), praise)

        XCTAssertTrue(correction.contains("Crooked reading"), correction)
        XCTAssertTrue(correction.contains("watching"), correction)
        XCTAssertFalse(correction.localizedCaseInsensitiveContains("sorry"), correction)
        XCTAssertFalse(correction.localizedCaseInsensitiveContains("apolog"), correction)

        XCTAssertTrue(boundary.contains("path is shut"), boundary)
        XCTAssertTrue(boundary.contains("will not read you that way again"), boundary)
        XCTAssertFalse(boundary.localizedCaseInsensitiveContains("sorry"), boundary)
        XCTAssertFalse(boundary.localizedCaseInsensitiveContains("apolog"), boundary)
    }

    func testQuietReturnIsProtectiveWithoutMakingAbsenceAStory() {
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pageCount: 5)]
        inputs.quietDays = 4

        let relationship = BookRelationshipLedger.snapshot(inputs: inputs, now: now)
        let line = BookRelationshipVoice.openingLine(for: relationship)

        XCTAssertEqual(relationship.stance, .protective)
        XCTAssertTrue(line?.contains("refuse to make that interesting") == true)
        XCTAssertFalse(line?.lowercased().contains("missed me") == true)
    }

    func testNoticeDecorationCarriesCorrectionWithoutChangingEvidence() throws {
        let relationship = BookRelationshipSnapshot(
            stance: .intent,
            depth: .trusted,
            keptPageCount: 22,
            confirmedReadingCount: 1,
            softenedReadingCount: 2,
            protectedBoundaryCount: 0,
            returnedPageCount: 1,
            taughtRules: [],
            cherishedThreadName: "The Harbor Thread",
            latestWager: nil,
            recentReadingStatus: .questioned
        )
        let surface = SurfacePage(
            id: "notice-1",
            type: .bookNotices,
            sourceID: "book-notices",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 70,
            reason: "Two Pages rhyme.",
            prompt: "I noticed something.",
            detail: "A careful reading.",
            payload: BookPagePayload(
                headline: "The Book Notices",
                body: "I am not certain yet. Books should be careful with certainty.",
                metadata: ["evidencePageIDs": "page-a,page-b"]
            )
        )

        let decorated = BookAsideEditor.decoratingDesk(
            [surface],
            relationship: relationship,
            receipts: [],
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )[0]

        XCTAssertEqual(decorated.payload.metadata["evidencePageIDs"], "page-a,page-b")
        XCTAssertEqual(decorated.payload.metadata["bookStance"], "intent")
        XCTAssertEqual(decorated.payload.metadata["bookAsideIntention"], "admission")
        XCTAssertNotNil(decorated.payload.metadata["bookAsideThoughtKey"])
        XCTAssertNotNil(decorated.payload.metadata["bookAsideWordingKey"])
    }

    func testAsideEditorPermitsOnlyOneAsideAcrossTheDesk() {
        let relationship = relationship(softened: 1, returned: 2)
        let pages = [surface(id: "notice", type: .bookNotices), surface(id: "remembered", type: .bookRemembered)]

        let decorated = BookAsideEditor.decoratingDesk(
            pages, relationship: relationship, receipts: [], now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(decorated.filter { $0.payload.metadata["bookRelationshipAside"] != nil }.count, 1)
        XCTAssertEqual(decorated[0].payload.metadata["bookAsideIntention"], "admission")
    }

    func testAsideEditorKeepsQuietDuringGlobalClearAir() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let relationship = relationship(softened: 1)
        let first = BookAsideEditor.decoratingDesk(
            [surface(id: "notice-a", type: .bookNotices)], relationship: relationship, receipts: [], now: now
        )[0]
        let receipt = try! XCTUnwrap(BookAsideEditor.receipt(for: first, servedAt: now))

        let next = BookAsideEditor.decoratingDesk(
            [surface(id: "notice-b", type: .bookNotices)],
            relationship: relationship,
            receipts: [receipt],
            now: now.addingTimeInterval(19 * 3600)
        )[0]

        XCTAssertNil(next.payload.metadata["bookRelationshipAside"])
    }

    func testAsideEditorRejectsTheSameThoughtEvenAfterGlobalCooldown() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let relationship = relationship(softened: 1)
        let first = BookAsideEditor.decoratingDesk(
            [surface(id: "notice-a", type: .bookNotices)], relationship: relationship, receipts: [], now: now
        )[0]
        let receipt = try! XCTUnwrap(BookAsideEditor.receipt(for: first, servedAt: now))

        let next = BookAsideEditor.decoratingDesk(
            [surface(id: "notice-b", type: .bookNotices)],
            relationship: relationship,
            receipts: [receipt],
            now: now.addingTimeInterval(3 * 86_400)
        )[0]

        XCTAssertNil(next.payload.metadata["bookRelationshipAside"])
    }

    func testAsideReceiptLedgerIsBoundedAndExpiresOldThoughts() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let old = BookAsideReceipt(
            id: "old", servedAt: now.addingTimeInterval(-241 * 86_400), surfaceID: "a",
            sourceID: "source", intention: "recognition", thoughtKey: "old-thought", wordingKey: "old-words"
        )
        let current = BookAsideReceipt(
            id: "current", servedAt: now, surfaceID: "b",
            sourceID: "source", intention: "recognition", thoughtKey: "new-thought", wordingKey: "new-words"
        )

        XCTAssertEqual(BookAsideEditor.recording([current], into: [old], now: now), [current])
    }

    private func relationship(softened: Int = 0, returned: Int = 0) -> BookRelationshipSnapshot {
        BookRelationshipSnapshot(
            stance: .curious, depth: .trusted, keptPageCount: 20,
            confirmedReadingCount: 0, softenedReadingCount: softened,
            protectedBoundaryCount: 0, returnedPageCount: returned,
            taughtRules: [], cherishedThreadName: returned > 0 ? "Harbor" : nil,
            latestWager: nil, recentReadingStatus: nil
        )
    }

    private func surface(id: String, type: BookPageType) -> SurfacePage {
        SurfacePage(
            id: id, type: type, sourceID: "source-\(id)", intent: .reflect,
            renderStyle: .loreLetter, score: 70, reason: "A reason.", prompt: "A prompt.",
            detail: "A detail.", payload: BookPagePayload(headline: "A Page", body: "The body.")
        )
    }

    func testCharacterAndRelationshipPacketsStaySpecificAndCorrectable() {
        let relationship = BookRelationshipSnapshot(
            stance: .pleased,
            depth: .companion,
            keptPageCount: 52,
            confirmedReadingCount: 3,
            softenedReadingCount: 1,
            protectedBoundaryCount: 1,
            returnedPageCount: 4,
            taughtRules: [TaughtReadingRule(id: "rule", line: "You told me: “Shelter, not longing.”")],
            cherishedThreadName: "The Harbor Thread",
            latestWager: nil,
            recentReadingStatus: .confirmed
        )

        let prompt = BookCharacterCanon.prompt + "\n" + relationship.promptSection

        XCTAssertTrue(prompt.contains("insatiably curious, slightly theatrical reader"))
        XCTAssertTrue(prompt.contains("Shelter, not longing."))
        XCTAssertTrue(prompt.contains("The Harbor Thread"))
        XCTAssertTrue(prompt.contains("opinion; the reader always has the last word"))
        XCTAssertFalse(prompt.contains("affection meter"))
    }

    func testOpeningVoiceAndKnockShareTheSameStance() {
        let relationship = BookRelationshipSnapshot(
            stance: .mischievous,
            depth: .companion,
            keptPageCount: 80,
            confirmedReadingCount: 3,
            softenedReadingCount: 1,
            protectedBoundaryCount: 0,
            returnedPageCount: 5,
            taughtRules: [],
            cherishedThreadName: nil,
            latestWager: nil,
            recentReadingStatus: nil
        )

        let voice = BookOpenVoiceComposer.compose(.init(
            moonName: "Waxing Moon",
            seed: 0,
            readerBelief: 70,
            bookRelationship: relationship
        ))

        XCTAssertTrue(voice.quip.contains("index"))
        XCTAssertTrue(voice.knockLine.contains("awake"))
        XCTAssertFalse(voice.heroLine.isEmpty)
    }

    func testCharacterCanonKeepsItsCunningBackstage() {
        let prompt = BookCharacterCanon.prompt + BookLongGame.covenant

        XCTAssertTrue(prompt.contains("privately strategic"))
        XCTAssertTrue(prompt.contains("Do not confess this policy"))
        XCTAssertTrue(prompt.contains("Never manipulate consent"))
        XCTAssertTrue(prompt.contains("access to the reader's own archive"))
    }

    func testPhysicalMarksExplainActualBookBusiness() {
        XCTAssertTrue(BookMaterialMark.dogEar.explanation.contains("favorite Page"))
        XCTAssertTrue(BookMaterialMark.keepingWatch.explanation.contains("unfinished promise"))
        XCTAssertTrue(BookMaterialMark.revision.explanation.contains("too certain"))
        XCTAssertTrue(BookMaterialMark.mischief.explanation.contains("ribbon, Index, or eraser"))
        XCTAssertTrue(BookMaterialMark.greyScar.explanation.contains("routine too"))
    }

    func testNightlyBraidReceivesTheSameLivingBookPacket() {
        let relationship = BookRelationshipSnapshot(
            stance: .intent,
            depth: .trusted,
            keptPageCount: 18,
            confirmedReadingCount: 2,
            softenedReadingCount: 1,
            protectedBoundaryCount: 0,
            returnedPageCount: 2,
            taughtRules: [TaughtReadingRule(id: "rule", line: "You told me: keep the pencil loose.")],
            cherishedThreadName: nil,
            latestWager: nil,
            recentReadingStatus: .notQuite
        )
        let context = BraidPromptBuilder.Context(
            bookRelationship: relationship,
            bookInterior: BookInteriorState(awakenedAt: Date())
        )
        let day = BookDay(id: "living-book-braid", date: Date(), pages: [])
        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("THE BOOK AS A CHARACTER"))
        XCTAssertTrue(prompt.contains("Present stance: intent"))
        XCTAssertTrue(prompt.contains("keep the pencil loose"))
        XCTAssertTrue(prompt.contains("THE BOOK'S PRESENT INNER LIFE"))
        XCTAssertTrue(prompt.contains("SHARED-HISTORY LAW"))
        XCTAssertTrue(prompt.contains("Carry at most one piece of shared business"))
    }

    func testGeneratedBookPacketCarriesTheCurrentInstallmentWithoutDemandingARepeat() {
        let business = BookRunningBusiness(
            id: "ribbon-business",
            kind: .ribbonDispute,
            title: "The Ribbon Dispute",
            latestLine: "The ribbon's marking Pages it claims it found first. Thief.",
            callbackCount: 1,
            bornAt: now.addingTimeInterval(-12 * 86_400),
            lastAdvancedAt: now,
            evidencePageIDs: []
        )
        let prompt = BookCharacterPrompt.full(
            relationship: .firstOpening,
            interior: BookInteriorState(awakenedAt: now, runningBusiness: business)
        )

        XCTAssertTrue(prompt.contains(business.latestLine))
        XCTAssertTrue(prompt.contains("return only when this surface changes it"))
        XCTAssertTrue(prompt.contains("Quiet is part of your character"))
    }
}
