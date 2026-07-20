import XCTest
@testable import InsideCoverCore

final class StudentNotesTests: XCTestCase {
    private let sender = NarrativeWorldEntity(
        id: "penny-blackletter",
        packID: "core",
        name: "Penny Blackletter",
        kind: .character,
        belief: 42,
        narrativeWeight: 28,
        traits: ["observant", "archival"],
        beliefs: ["honest details matter"],
        tags: ["records", "margins"]
    )

    func testDraftIsASealedPreviewUntilGenerated() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let day = BookDay(id: "note-day", date: now, pages: [])
        let surface = StudentNotePageGenerator.draftCandidate(
            for: sender,
            source: BookPageSourceRegistry.source(for: .note),
            day: day,
            inputs: .empty,
            now: now
        )

        XCTAssertEqual(surface.type, BookPageType.note)
        XCTAssertEqual(surface.sourceID, "student-notes")
        XCTAssertEqual(surface.prompt, "Penny Blackletter just slipped you a note.")
        XCTAssertEqual(surface.payload.metadata["placeholder"], "Penny Blackletter just slipped you a note.")
        XCTAssertNil(surface.payload.metadata["noteProse"])
        XCTAssertTrue(surface.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Penny Blackletter") == true)
        XCTAssertTrue(surface.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("honest details matter") == true)
        XCTAssertTrue(SurfaceReadinessState(surface: surface).needsLocalBrainToOpen)
    }

    func testNoteReadinessTurnsOffWhenProseExists() {
        XCTAssertTrue(SurfaceReadinessState(type: .note).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(type: .note, metadata: ["noteProse": ""]).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(
            type: .note,
            metadata: ["noteProse": "You saw the noticeboard twitch too, right?"]
        ).needsLocalBrainToOpen)
    }

    func testPriorNoteReplyIsFedIntoFutureDraftPacket() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var inputs = BookSourceInputs.empty
        let prior = BookPage(
            type: .note,
            createdAt: now.addingTimeInterval(-3_600),
            promptText: "Penny Blackletter just slipped you a note.",
            userInput: "I saw the noticeboard twitch too.",
            playerReply: "Meet me after class by the lamp.",
            tags: ["note", "student-note", "sender:penny-blackletter"]
        )
        inputs.days = [
            BookDay(id: "prior-note-day", date: now.addingTimeInterval(-86_400), pages: [prior])
        ]

        let surface = StudentNotePageGenerator.draftCandidate(
            for: sender,
            source: BookPageSourceRegistry.source(for: .note),
            day: BookDay(id: "note-day", date: now, pages: []),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(surface.payload.body.contains("Meet me after class by the lamp."))
        XCTAssertTrue(surface.payload.body.contains("Prior note reply"))
    }

    func testReplyMemorySummaryNamesSenderAndExcerpt() {
        let summary = StudentNotePageGenerator.noteReplyMemorySummary(
            senderName: "Penny Blackletter",
            reply: "I folded the map twice and left it under the blue book."
        )

        XCTAssertTrue(summary.contains("Penny Blackletter"))
        XCTAssertTrue(summary.contains("note passed back"))
        XCTAssertTrue(summary.contains("blue book"))
    }

    func testDraftBindsWholeCharacterPacketToKeptPageInterpretation() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let particularSender = NarrativeWorldEntity(
            id: "particular-sender",
            packID: "core",
            name: "Particular Sender",
            kind: .character,
            belief: 40,
            narrativeWeight: 30,
            chapter: "Margins",
            unwrittenInterest: "misfiled promises",
            traits: ["observant"],
            quirks: ["counts doors before answering"],
            faults: ["mistakes caution for certainty"],
            beliefs: ["promises alter rooms"],
            goals: ["recover the missing oath"],
            tags: ["records"]
        )
        let kept = BookPage(
            id: "kept-oath",
            type: .plainPage,
            createdAt: now.addingTimeInterval(-60),
            promptText: "Plain Page",
            userInput: "I left the brass key beside the blue cup because I promised I would come back.",
            origin: .userAuthored
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [kept])
        let surface = StudentNotePageGenerator.draftCandidate(
            for: particularSender,
            source: BookPageSourceRegistry.source(for: .note),
            day: day,
            inputs: .empty,
            now: now
        )
        let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""

        XCTAssertTrue(canon.contains("counts doors before answering"))
        XCTAssertTrue(canon.contains("mistakes caution for certainty"))
        XCTAssertTrue(canon.contains("promises alter rooms"))
        XCTAssertTrue(canon.contains("recover the missing oath"))
        XCTAssertTrue(canon.contains("misfiled promises"))
        XCTAssertTrue(canon.contains("The kept subject this character is responding to now"))
        XCTAssertTrue(surface.payload.body.contains("whole binding character packet"))
    }
}
