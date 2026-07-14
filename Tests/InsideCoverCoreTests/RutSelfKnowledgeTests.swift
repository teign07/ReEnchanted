import XCTest
@testable import InsideCoverCore

final class RutSelfKnowledgeTests: XCTestCase {
    func testRutQuestionsAreHighPriorityAndPlainSpoken() throws {
        let signal = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-signal"))
        let depth = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth"))
        let season = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-season"))
        let entry = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "wonder-entry"))
        let home = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "home-place"))

        XCTAssertGreaterThan(signal.priority, home.priority)
        XCTAssertGreaterThan(depth.priority, home.priority)
        XCTAssertGreaterThan(season.priority, home.priority)
        XCTAssertGreaterThan(entry.priority, home.priority)

        XCTAssertTrue(signal.prompt.contains("that's me"))
        XCTAssertTrue(signal.detail.contains("isn't diagnosing"))
        XCTAssertTrue(depth.detail.contains("weather report"))
        XCTAssertTrue(season.detail.contains("teeth"))
        XCTAssertTrue(entry.detail.contains("tired Tuesday"))
    }

    func testRutTranslationsKeepLabelsAsStateNotIdentity() throws {
        let depth = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth"))
        let season = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-season"))
        let entry = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "wonder-entry"))

        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: depth, answer: "4-7: in the rut"),
            "The Book will treat this as a weather report, not a diagnosis: 4-7: in the rut."
        )
        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: season, answer: "The Too-Many-Tabs Era"),
            "The Book will call this season The Too-Many-Tabs Era when it needs to name the gray without making it permanent."
        )
        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: entry, answer: "a snack walk"),
            "The Book will start near a snack walk when wonder needs to feel easy."
        )

        let earned = AboutYouQuestion(
            id: "earned-wonder-label",
            packID: SelfKnowledgePackRegistry.corePackID,
            prompt: "Your First Working Title",
            detail: "",
            placeholder: "",
            sensitivity: .identity,
            defaultUsePermission: .privateContext,
            tags: ["earned-label"],
            priority: 0
        )
        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: earned, answer: "Proofkeeper"),
            "The Book treats this as an earned working title, not a personality box: Proofkeeper."
        )
    }

    func testRutRecognitionSurfacesBeforeGeneralAboutYouQuestions() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let first = try XCTUnwrap(SelfKnowledgePackRegistry.nextQuestion(knownFacts: [], day: day, now: now))
        XCTAssertEqual(first.id, "rut-signal")

        let answeredSignal = selfFact(for: first, answer: "Phone fog", now: now)
        let second = try XCTUnwrap(SelfKnowledgePackRegistry.nextQuestion(knownFacts: [answeredSignal], day: day, now: now))
        XCTAssertEqual(second.id, "rut-depth")
    }

    func testFirstInterestFollowsOnboardingNameWithoutWaitingBehindRutSequence() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let name = SelfFact(
            id: "onboarding:name",
            questionID: "name",
            question: "What should the Book call you?",
            answer: "Avery",
            bookTranslation: "The Book may call you Avery.",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["name", "identity"],
            createdAt: now,
            updatedAt: now
        )

        let next = try XCTUnwrap(
            SelfKnowledgePackRegistry.nextQuestion(knownFacts: [name], day: day, now: now)
        )

        XCTAssertEqual(next.id, "interest-01")

        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [name]
        let pages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now.addingTimeInterval(60)
        )
        let interestPage = try XCTUnwrap(pages.first { $0.payload.metadata["questionID"] == "interest-01" })
        XCTAssertEqual(interestPage.score, 91)
        XCTAssertTrue(interestPage.reason.contains("The Bleed"))
    }

    func testEarnedLabelNeedsRecognitionAndReceipts() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            selfFact(for: try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-signal")), answer: "Phone fog", now: now),
            selfFact(for: try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth")), answer: "4-7: in the rut", now: now)
        ]

        let tooSoon = AboutYouPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        XCTAssertFalse(tooSoon.contains { $0.payload.metadata["earnedLabel"] == "true" })

        let yesterday = now.addingTimeInterval(-86_400)
        inputs.days = [
            BookDay(id: BookDay.id(for: yesterday), date: yesterday, pages: [
                BookPage(type: .souvenir, createdAt: yesterday, promptText: "Catch one real thing.", userInput: "I put the phone down and noticed the window light.", tags: ["souvenir"]),
                BookPage(type: .diary, createdAt: yesterday, promptText: "What happened?", userInput: "The screen kept eating the quiet, but I came back.", tags: ["diary"])
            ])
        ]

        let missingWonderKind = AboutYouPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        XCTAssertFalse(missingWonderKind.contains { $0.payload.metadata["earnedLabel"] == "true" })

        inputs.selfFacts.append(
            selfFact(for: try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "wonder-entry")), answer: "A snack walk", now: now)
        )

        let pages = AboutYouPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        let earned = try XCTUnwrap(pages.first { $0.payload.metadata["earnedLabel"] == "true" })
        XCTAssertEqual(earned.payload.metadata["questionID"], "earned-wonder-label")
        XCTAssertEqual(earned.payload.metadata["earnedLabelName"], "Pocket Adventurer")
        XCTAssertTrue(earned.payload.body.contains("The Book does not give this out at the door."))
        XCTAssertTrue(earned.payload.body.contains("Receipts:"))
        XCTAssertTrue(earned.payload.body.contains("Wonder door:"))
    }

    func testEarnedWonderTitleShapesCompassAndScoring() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var titledInputs = BookSourceInputs.empty
        titledInputs.selfFacts = [earnedTitleFact("Pocket Adventurer", now: now)]

        let compass = WonderCompassPageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: titledInputs,
            now: now
        )
        XCTAssertEqual(compass.payload.metadata["wonderTitleName"], "Pocket Adventurer")
        XCTAssertTrue(compass.detail.contains("Pocket Adventurer"))
        XCTAssertTrue(compass.payload.body.contains("Make it small enough to fit in a pocket."))

        let plainMood = CuratorMood.make(inputs: .empty, now: now)
        let titledMood = CuratorMood.make(inputs: titledInputs, now: now)
        let anchor = SurfacePage(type: .anchor, prompt: "A nearby door", detail: "Try a tiny outing.")
        XCTAssertGreaterThan(
            titledMood.adjustment(for: anchor, now: now),
            plainMood.adjustment(for: anchor, now: now)
        )
    }

    private func selfFact(for question: AboutYouQuestion, answer: String, now: Date) -> SelfFact {
        SelfFact(
            id: "\(question.packID):\(question.id)",
            questionID: question.id,
            question: question.prompt,
            answer: answer,
            bookTranslation: SelfKnowledgePackRegistry.translation(for: question, answer: answer),
            sensitivity: question.sensitivity,
            usePermission: question.defaultUsePermission,
            tags: question.tags,
            createdAt: now,
            updatedAt: now
        )
    }

    private func earnedTitleFact(_ title: String, now: Date) -> SelfFact {
        SelfFact(
            id: "core-self-knowledge:earned-wonder-label",
            questionID: "earned-wonder-label",
            question: "Your First Working Title",
            answer: title,
            bookTranslation: "The Book treats this as an earned working title, not a personality box: \(title).",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["earned-label"],
            createdAt: now,
            updatedAt: now
        )
    }
}
