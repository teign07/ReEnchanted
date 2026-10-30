import XCTest
@testable import InsideCoverCore

final class FaerieMissionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_798_000_000)

    func testOrdinarySupplyIncludesARelationshipWithoutAShadowUnlock() {
        let day = BookDay(id: "ordinary-faerie", date: now, pages: [])
        let offered = PlayfulMissionRegistry.missions(for: day, inputs: .empty, now: now, limit: 5)

        XCTAssertEqual(offered.count, 5)
        XCTAssertTrue(offered.contains { $0.practice != nil })
        XCTAssertFalse(offered.contains { $0.tags.contains("shadow-wonder") })
        XCTAssertEqual(offered.first, PlayfulMissionRegistry.mission(for: day, inputs: .empty, now: now))
    }

    func testPracticeSupplyHonorsRestBeforeReservingAnAlternate() {
        let day = BookDay(id: "rested-practices", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        for mission in PlayfulMissionRegistry.missions where mission.practice != nil {
            inputs.surfaceHistory["playful-mission:\(mission.id)"] = SurfaceHistoryRecord(
                lastShownAt: now, recentShowCount: 1
            )
        }

        let offered = PlayfulMissionRegistry.missions(for: day, inputs: inputs, now: now, limit: 5)
        XCTAssertFalse(offered.contains { $0.practice != nil })
    }

    func testReturnCarriesExactReaderWordsAndIdentifiesTheEarlierEncounter() throws {
        let words = "The blue thermos is Dribble. It leaks down my sleeve."
        let page = receiptPage(words: words)
        let day = BookDay(id: "return-day", date: now, pages: [page])
        var inputs = BookSourceInputs.empty
        // The current day may already be in the archive input. One Page is
        // still one encounter, never two invitations.
        inputs.days = [day]

        let returns = PlayfulMissionRegistry.returnMissions(for: day, inputs: inputs, now: now)
        let mission = try XCTUnwrap(returns.first)
        XCTAssertEqual(returns.count, 1)
        XCTAssertTrue(mission.prompt.contains("“\(words)”"))
        XCTAssertTrue(mission.prompt.contains("a thing you named for what it does"))
        XCTAssertTrue(mission.prompt.contains("If the thing has gone"))
        XCTAssertEqual(mission.practice, .returnVisit)
    }

    func testReturnRequiresReaderProvenanceCompleteWordsAndElapsedTime() {
        var generated = receiptPage(words: "The kettle called itself Your Majesty.")
        generated.origin = .generated
        let photoOnly = receiptPage(words: "")
        let tooLong = receiptPage(words: String(repeating: "the blue thermos ", count: 20))
        let tooSoon = receiptPage(words: "The thermos leaks down my sleeve.", age: 3_600)
        let tooOld = receiptPage(words: "The thermos leaks down my sleeve.", age: 91 * 86_400)
        let future = receiptPage(words: "The thermos leaks down my sleeve.", age: -86_400)

        for page in [generated, photoOnly, tooLong, tooSoon, tooOld, future] {
            let day = BookDay(id: "no-return", date: now, pages: [page])
            XCTAssertTrue(PlayfulMissionRegistry.returnMissions(for: day, inputs: .empty, now: now).isEmpty)
        }
    }

    func testAlreadyShownReturnDoesNotKeepAsking() throws {
        let page = receiptPage(words: "The blue thermos is Dribble. It leaks.")
        let day = BookDay(id: "shown-return", date: now, pages: [page])
        var inputs = BookSourceInputs.empty
        let mission = try XCTUnwrap(PlayfulMissionRegistry.returnMissions(for: day, inputs: inputs, now: now).first)
        inputs.surfaceHistory["playful-mission:\(mission.id)"] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-3_600), recentShowCount: 1
        )

        XCTAssertTrue(PlayfulMissionRegistry.returnMissions(for: day, inputs: inputs, now: now).isEmpty)
    }

    func testScheduledWhispersNeverIncludePrivateReturnQuotations() {
        let words = "The blue thermos is Dribble. It leaks down my sleeve."
        let day = BookDay(id: "private-return", date: now, pages: [receiptPage(words: words)])
        var inputs = BookSourceInputs.empty
        inputs.days = [day]
        let whispers = PromptWhisperRegistry.prompts(for: day, inputs: inputs, now: now, count: 220)

        XCTAssertFalse(whispers.contains { $0.body.contains(words) })
        XCTAssertFalse(whispers.contains { PlayfulMissionPractice.from(tags: $0.tags) == .returnVisit })
    }

    func testPrivateReturnRoundTripKeepsItsContextAndPreventsAnotherReturn() throws {
        let source = receiptPage(words: "The blue thermos is Dribble. It leaks.")
        let day = BookDay(id: "snapshot-return", date: now, pages: [source])
        let mission = try XCTUnwrap(PlayfulMissionRegistry.returnMissions(for: day, inputs: .empty, now: now).first)
        let whisper = PromptWhisperRegistry.promptWhisper(from: mission)
        let snapshot = try JSONDecoder().decode(PromptWhisper.self, from: JSONEncoder().encode(whisper))
        let surface = WonderCompassPageSourceAdapter().promptWhisperSurface(
            for: snapshot, day: day, context: CuratorContext.make(for: day), inputs: .empty, now: now
        )
        XCTAssertEqual(surface.payload.metadata["mission"], mission.prompt)
        XCTAssertEqual(surface.payload.metadata["playfulMissionPractice"], "return-visit")
        let receipt = try XCTUnwrap(LivedQuestReceipt.from(
            surface: surface, readerInput: "Still Dribble. Still leaking.", mediaAssets: [], completedAt: now
        ))
        XCTAssertEqual(PlayfulMissionPractice.from(tags: receipt.sourceTags), .returnVisit)
        let returned = BookPage(
            id: "answered-return", type: .wonderCompass, createdAt: now,
            promptText: mission.title, userInput: "Still Dribble. Still leaking.", livedQuestReceipt: receipt
        )
        let answeredDay = BookDay(id: day.id, date: now, pages: [source, returned])

        XCTAssertTrue(PlayfulMissionRegistry.returnMissions(for: answeredDay, inputs: .empty, now: now).isEmpty)
    }

    func testCustomMissionRejectsIncompleteOrOverlongOutputAsAWhole() {
        XCTAssertNil(custom(prompt: nil))
        XCTAssertNil(custom(proof: nil))
        XCTAssertNil(custom(prompt: String(repeating: "x", count: 321)))
        XCTAssertNil(custom(prompt: String(repeating: "word ", count: 46)))
        XCTAssertNil(custom(prompt: "Do the same thing as last time."))
        XCTAssertNil(custom(proof: "Bring back the thing you named earlier."))
        XCTAssertNil(custom(practice: "return-visit"))
        XCTAssertNil(custom(practice: "unknown-practice"))
    }

    func testCustomMissionPreservesTheWholeInstructionAndPractice() throws {
        let prompt = "Find a drawer that sticks. Ask it to open. Try once without forcing it."
        let mission = try XCTUnwrap(custom(prompt: prompt))
        XCTAssertEqual(mission.prompt, prompt)
        XCTAssertEqual(mission.proofPrompt, "The drawer, and whether it opened.")
        XCTAssertEqual(mission.practice, .courtesy)
        XCTAssertFalse(mission.allowsPhoto)
        XCTAssertFalse(mission.tags.contains { $0.hasPrefix("return-source:") })
        XCTAssertFalse(mission.tags.contains(PlayfulMissionPractice.returnVisit.tag))
    }

    private func custom(prompt: String? = "Ask a sticking drawer to open.",
                        proof: String? = "The drawer, and whether it opened.",
                        practice: String? = "courtesy") -> PlayfulMission? {
        PlayfulMissionAuthoring.mission(
            title: "Ask the Drawer", prompt: prompt, proofPrompt: proof,
            tags: "object,inside,faerie-practice:return-visit,return-source:invented-page",
            allowsPhoto: "false", practice: practice
        )
    }

    private func receiptPage(words: String, age: TimeInterval = 2 * 86_400) -> BookPage {
        let at = now.addingTimeInterval(-age)
        let receipt = LivedQuestReceipt(
            kind: .playfulMission, questID: "faerie-name-earned", title: "A Name It Earned",
            invitation: "Name a thing for what it does.", proofPrompt: "The thing and its name.",
            facets: [.exactAttention], sourceTags: ["mission:faerie-practice:courtesy"],
            hasWrittenProof: !words.isEmpty, hasVisualProof: false,
            completedAt: at, wasPromptedByBook: true
        )
        return BookPage(id: "named-thermos", type: .wonderCompass, createdAt: at,
                        promptText: receipt.title, userInput: words, livedQuestReceipt: receipt)
    }
}
