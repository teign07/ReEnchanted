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
}
