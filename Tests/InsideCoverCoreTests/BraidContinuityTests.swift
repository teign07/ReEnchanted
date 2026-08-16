import Foundation
import XCTest

@testable import InsideCoverCore

final class BraidContinuityTests: XCTestCase {
    func testYesterdayOpeningContinuesWithItsOriginalAnchor() {
        let prior = braidMemory(
            date: date("2026-09-01T21:00:00Z"),
            state: .opened,
            anchor: "the screw"
        )
        var context = BraidPromptBuilder.Context()
        context.memoryDigest = digest(prior)

        let beat = BraidPromptBuilder.continuityBeat(
            for: day("2026-09-02", subject: "kettle"),
            context: context,
            currentAnchor: "the kettle",
            now: date("2026-09-02T21:00:00Z"),
            calendar: utcCalendar
        )

        XCTAssertEqual(beat?.kind, .fictionContinuation)
        XCTAssertEqual(beat?.threadID, "door")
        XCTAssertEqual(beat?.priorAnchor, "the screw")
        XCTAssertEqual(beat?.currentAnchor, "the kettle")
        XCTAssertEqual(beat?.elapsedDays, 1)
    }

    func testAContinuedThreadLandsOnItsThirdBeat() {
        let prior = braidMemory(
            date: date("2026-09-02T21:00:00Z"),
            state: .continued,
            anchor: "the screw",
            lastAnchor: "the kettle"
        )
        var context = BraidPromptBuilder.Context()
        context.memoryDigest = digest(prior)

        let beat = BraidPromptBuilder.continuityBeat(
            for: day("2026-09-03", subject: "kettle"),
            context: context,
            currentAnchor: "the kettle",
            now: date("2026-09-03T21:00:00Z"),
            calendar: utcCalendar
        )

        XCTAssertEqual(beat?.kind, .fictionResolution)
        XCTAssertEqual(beat?.priorAnchor, "the screw")
        XCTAssertEqual(beat?.previousAnchor, "the kettle")
    }

    func testAThreeWeekAbsenceCannotSayStill() {
        let prior = braidMemory(
            date: date("2026-09-01T21:00:00Z"),
            state: .opened,
            anchor: "the screw"
        )
        var context = BraidPromptBuilder.Context()
        context.memoryDigest = digest(prior)

        let beat = BraidPromptBuilder.continuityBeat(
            for: day("2026-09-22", subject: "kettle"),
            context: context,
            currentAnchor: "the kettle",
            now: date("2026-09-22T21:00:00Z"),
            calendar: utcCalendar
        )

        XCTAssertEqual(beat?.kind, .fictionOpening)
        XCTAssertNil(beat?.sourceBraidPageID)
        XCTAssertNil(beat?.priorAnchor)
    }

    func testHouseContinuationNamesYesterdayObjectNotTodays() {
        let today = day("2026-09-02", subject: "kettle")
        var context = BraidPromptBuilder.Context()
        context.continuityBeat = BraidPromptBuilder.ContinuityBeat(
            kind: .fictionContinuation,
            threadID: "door",
            sourceBraidPageID: "prior-braid",
            sourceTitle: "The Screw at the Door",
            priorAnchor: "the screw",
            currentAnchor: "the kettle",
            priorLine: "A door started keeping the screw in mind.",
            elapsedDays: 1,
            evidencePageIDs: [],
            reason: nil
        )

        let composition = DeterministicBraidwright.composition(for: today, context: context)
        // The house continuation must name yesterday's object, not tonight's.
        // The phrase moved when the door thread was rewritten; the contract
        // did not.
        let phrase = "twice more since the screw"

        XCTAssertTrue(composition.text.contains(phrase), composition.text)
        XCTAssertEqual(composition.text.components(separatedBy: phrase).count - 1, 1)
        XCTAssertFalse(composition.text.contains("twice more since the kettle"), composition.text)
    }

    func testGemmaWinnerReceivesTheSamePersistedThreadState() {
        var context = BraidPromptBuilder.Context()
        context.continuityBeat = BraidPromptBuilder.ContinuityBeat(
            kind: .fictionOpening,
            threadID: "registry",
            sourceBraidPageID: nil,
            sourceTitle: nil,
            priorAnchor: nil,
            currentAnchor: "the kettle",
            priorLine: nil,
            elapsedDays: nil,
            evidencePageIDs: [],
            reason: nil
        )
        let freeFormWinner = BookPage(
            id: "gemma-winner",
            type: .bookOfYou,
            createdAt: date("2026-09-02T21:00:00Z"),
            promptText: "The local Book brain braided today.",
            userInput: "The Kettle Column\n\nThe Registry grew a new column.\n\nThe Book kept the page: the kettle stayed.",
            tags: ["braid", "local-model", "gemma"],
            origin: .generated
        )

        let annotated = BraidPageDetails.annotated(freeFormWinner, context: context)
        let residue = BookOfYouResidue.fromTags(in: annotated)

        XCTAssertEqual(residue?.continuityKind, .fictionOpening)
        XCTAssertEqual(residue?.fictionThreadID, "registry")
        XCTAssertEqual(residue?.fictionThreadState, .opened)
        XCTAssertEqual(residue?.fictionThreadAnchor, "the kettle")
        XCTAssertEqual(residue?.fictionThreadLastAnchor, "the kettle")
    }

    func testIgnoredContinuityIsNotPersistedAsThoughItHappened() {
        var context = BraidPromptBuilder.Context()
        context.continuityBeat = BraidPromptBuilder.ContinuityBeat(
            kind: .fictionContinuation,
            threadID: "door",
            sourceBraidPageID: "prior-braid",
            sourceTitle: "The Screw at the Door",
            priorAnchor: "the screw",
            currentAnchor: "the kettle",
            priorLine: "A door started keeping the screw in mind.",
            elapsedDays: 1,
            evidencePageIDs: [],
            reason: nil
        )
        let ignored = BookPage(
            id: "gemma-missed-continuity",
            type: .bookOfYou,
            createdAt: date("2026-09-02T21:00:00Z"),
            promptText: "The local Book brain braided today.",
            userInput: "The Kettle\n\nYou polished the kettle.\n\nThe Book kept the page: the kettle stayed.",
            tags: ["braid", "local-model", "gemma"],
            origin: .generated
        )

        let annotated = BraidPageDetails.annotated(ignored, context: context)
        let residue = BookOfYouResidue.fromTags(in: annotated)

        XCTAssertNil(residue?.continuityKind)
        XCTAssertNil(residue?.fictionThreadID)
        XCTAssertTrue(
            BraidOutputAudit.issues(
                in: ignored.userInput,
                for: day("2026-09-02", subject: "kettle"),
                context: context
            ).contains(.missingContinuityBeat)
        )
    }

    func testCompactGemmaPromptReceivesTheChosenContinuation() {
        let today = day("2026-09-02", subject: "kettle")
        var context = BraidPromptBuilder.Context()
        context.continuityBeat = BraidPromptBuilder.ContinuityBeat(
            kind: .fictionContinuation,
            threadID: "door",
            sourceBraidPageID: "prior-braid",
            sourceTitle: "The Screw at the Door",
            priorAnchor: "the screw",
            currentAnchor: "the kettle",
            priorLine: "A door started keeping the screw in mind.",
            elapsedDays: 1,
            evidencePageIDs: [],
            reason: nil
        )
        context = DeterministicBraidwright.preparedContext(for: today, context: context)

        let prompt = BraidPromptBuilder.prompt(for: today, context: context)

        XCTAssertTrue(prompt.contains("BRAID CONTINUITY: CONTINUE, DO NOT REINTRODUCE"), prompt)
        XCTAssertTrue(prompt.contains("Earlier fictional anchor: the screw"), prompt)
        XCTAssertTrue(prompt.contains("Tonight's supplied anchor: the kettle"), prompt)
    }

    func testEvidenceRhymeNamesARealPriorBraidAndThenRests() {
        let today = day("2026-10-02", subject: "kettle")
        let prior = braidMemory(
            date: date("2026-09-12T21:00:00Z"),
            state: nil,
            anchor: nil,
            arcID: "semantic:old-kettle",
            semanticEchoIDs: ["old-kettle"]
        )
        var context = DeterministicBraidwright.preparedContext(for: today, context: .empty)
        guard var score = context.storyScore else { return XCTFail("missing story score") }
        score.arc = BraidPromptBuilder.NightlyStoryScore.ArcBeat(
            id: "semantic:old-kettle",
            movement: .returned,
            priorState: "the earlier Page kept the blue cup",
            tonightDelta: "the kettle returned beside the cup",
            evidencePageIDs: [today.pages[0].id],
            fictionChoicePageIDs: [],
            relationalConnectionIDs: []
        )
        context.storyScore = score
        context.memoryDigest = digest(prior)
        context.semanticEchoSourceIDs = ["old-kettle"]

        let earned = BraidPromptBuilder.continuityBeat(
            for: today,
            context: context,
            currentAnchor: "the kettle",
            now: date("2026-10-02T21:00:00Z"),
            calendar: utcCalendar
        )
        XCTAssertEqual(earned?.kind, .evidenceRhyme)
        XCTAssertEqual(earned?.sourceBraidPageID, "prior-braid")
        XCTAssertEqual(earned?.evidencePageIDs, [today.pages[0].id])

        context.lastEvidenceRhymeAt = date("2026-09-20T21:00:00Z")
        let resting = BraidPromptBuilder.continuityBeat(
            for: today,
            context: context,
            currentAnchor: "the kettle",
            now: date("2026-10-02T21:00:00Z"),
            calendar: utcCalendar
        )
        XCTAssertEqual(resting?.kind, .fictionOpening)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ id: String, subject: String) -> BookDay {
        let kept = BookPage(
            id: "kept-\(id)",
            type: .diary,
            createdAt: date("\(id)T08:00:00Z"),
            promptText: "What happened?",
            userInput: "I polished the \(subject) in the kitchen and left it by the window.",
            origin: .userAuthored
        )
        return BookDay(id: id, date: date("\(id)T21:00:00Z"), pages: [kept])
    }

    private func braidMemory(
        date: Date,
        state: BraidPromptBuilder.FictionThreadState?,
        anchor: String?,
        lastAnchor: String? = nil,
        arcID: String? = nil,
        semanticEchoIDs: [String] = []
    ) -> BindingMemoryDigest.BraidMemory {
        let residue = BookOfYouResidue(
            title: "The Screw at the Door",
            spineLine: "A door started keeping the screw in mind.",
            keptLine: "The Book kept the page: the screw stayed by the door.",
            motifs: ["screw", "door"],
            semanticEchoIDs: semanticEchoIDs,
            openedQuestion: nil,
            callbackCandidate: "the screw stayed by the door",
            arcID: arcID,
            continuityKind: state.map { $0 == .opened ? .fictionOpening : .fictionContinuation },
            fictionThreadID: state == nil ? nil : "door",
            fictionThreadState: state,
            fictionThreadAnchor: anchor,
            fictionThreadLastAnchor: lastAnchor ?? anchor
        )
        return BindingMemoryDigest.BraidMemory(
            pageID: "prior-braid",
            date: date,
            residue: residue
        )
    }

    private func digest(_ memory: BindingMemoryDigest.BraidMemory) -> BindingMemoryDigest {
        BindingMemoryDigest(
            braids: [memory],
            motifCounts: [],
            strongestCallback: memory.residue.callbackCandidate
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
