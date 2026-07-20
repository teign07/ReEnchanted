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

    func testRelationshipLedgerDerivesContritionFromDurableCorrection() {
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

        XCTAssertEqual(relationship.stance, .contrite)
        XCTAssertEqual(relationship.depth, .acquainted)
        XCTAssertEqual(relationship.softenedReadingCount, 1)
        XCTAssertTrue(relationship.hasBeenTaught)
        XCTAssertTrue(relationship.promptSection.contains("The mornings are slow, not sad."))
        XCTAssertTrue(BookRelationshipVoice.openingLine(for: relationship)?.contains("pencil loose") == true)
    }

    func testQuietReturnIsProtectiveWithoutMakingAbsenceAStory() {
        var inputs = BookSourceInputs.empty
        inputs.days = [day(pageCount: 5)]
        inputs.quietDays = 4

        let relationship = BookRelationshipLedger.snapshot(inputs: inputs, now: now)
        let line = BookRelationshipVoice.openingLine(for: relationship)

        XCTAssertEqual(relationship.stance, .protective)
        XCTAssertTrue(line?.contains("will not make a story out of that") == true)
        XCTAssertFalse(line?.lowercased().contains("missed me") == true)
    }

    func testNoticeDecorationCarriesCorrectionWithoutChangingEvidence() throws {
        let relationship = BookRelationshipSnapshot(
            stance: .contrite,
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

        let decorated = BookRelationshipVoice.decorating(surface, relationship: relationship)

        XCTAssertEqual(decorated.payload.metadata["evidencePageIDs"], "page-a,page-b")
        XCTAssertEqual(decorated.payload.metadata["bookStance"], "contrite")
        XCTAssertTrue(decorated.payload.body.contains("pencil loose"))
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
}
