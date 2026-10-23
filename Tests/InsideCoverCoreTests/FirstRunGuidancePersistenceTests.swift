import XCTest
@testable import InsideCoverCore

final class FirstRunGuidancePersistenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_315_200) // June 2026

    private func requested(_ introduction: FirstRunPageSequence.Introduction, inputs: BookSourceInputs = .empty) -> SurfacePage {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        return FirstRunPageSequence.requestedIntroduction(
            introduction, for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
    }

    func testEveryExtendedIntroductionRestsAfterOneAppearanceAcrossRelaunchAndHistoryExpiry() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.calendarIntegrationEnabled = false
        inputs.localBrainIsReady = true
        inputs.firstRunEngagedKeys = [
            "source:labyrinth-welcome", "source:local-brain-awake",
            "source:\(StorySoFarPageSourceAdapter.onboardingSourceID)"
        ]
        var seen = Set<String>()

        // Persist and reload after each appearance, without ever opening or
        // dismissing a card. No ordinary surface history survives the reload.
        for _ in 0..<12 {
            guard let rider = FirstRunPageSequence.guidedRider(
                for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
            ) else { break }
            XCTAssertTrue(seen.insert(rider.sourceID).inserted, "Repeated \(rider.sourceID)")
            var vault = PlayerVaultData()
            vault.firstRunEngaged = FirstRunPageSequence.recordingShownGuidance(
                in: Array(inputs.firstRunEngagedKeys), history: [:], pages: [rider]
            )
            let restored = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(vault))
            inputs.firstRunEngagedKeys = Set(restored.firstRunEngaged ?? [])
            inputs.surfaceHistory = [:]
        }

        XCTAssertTrue(seen.isSuperset(of: [
            FirstRunPageSequence.firstMissionSourceID,
            FirstRunPageSequence.pagewrightIntroSourceID,
            FirstRunPageSequence.enchantmentIntroSourceID,
            BookPageSourceRegistry.source(for: .calendar).id,
            FirstRunPageSequence.compassIntroductionSourceID,
            FirstRunPageSequence.compassRunIntroSourceID
        ]))
        XCTAssertNil(FirstRunPageSequence.guidedRider(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now.addingTimeInterval(200 * 86_400)
        ))
    }

    func testUpdatePromotesOldServedHistoryEvenWithAnExistingProgressLedger() {
        let compassKey = "source:\(FirstRunPageSequence.compassIntroductionSourceID)"
        let welcomeKey = "source:\(BookPageSourceRegistry.source(for: .welcome).id)"
        let history = [compassKey, "first-door-origin", "first-door-apprenticeship:2", welcomeKey, "source:local-brain-awake", "source:ordinary"]
            .reduce(into: [String: SurfaceHistoryRecord]()) { $0[$1] = SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1) }
        let progress = FirstRunPageSequence.recordingShownGuidance(in: ["existing-interaction"], history: history)

        XCTAssertEqual(Set(progress), ["existing-interaction", compassKey, "first-door-origin", "first-door-apprenticeship:2", "source:local-brain-awake"])
        XCTAssertEqual(FirstRunPageSequence.recordingShownGuidance(in: progress, history: history), progress)
    }

    func testRecordingExtendedGuidanceDoesNotAdvanceTheOpeningWelcome() {
        let welcome = requested(.localBrain)
        let progress = FirstRunPageSequence.recordingShownGuidance(in: [], history: [:], pages: [welcome])
        XCTAssertTrue(progress.isEmpty)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        XCTAssertNotNil(FirstRunPageSequence.surfaces(
            for: day, context: CuratorContext.make(for: day), inputs: .empty, now: now
        ))
    }

    func testFolioKeepEngagementRetiresTheWholeDeskWelcomeAcrossReload() throws {
        let welcome = requested(.localBrain)
        var vault = PlayerVaultData()
        vault.firstRunEngaged = FirstRunPageSequence.recordingEngagement(in: [], page: welcome)
        let restored = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(vault))
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = Set(restored.firstRunEngaged ?? [])
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ))
        XCTAssertTrue(LabyrinthWelcomePageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ).isEmpty)
    }

    func testLegacyKeptWelcomeRepairsMissingProgressWithoutServedHistory() {
        let welcome = requested(.localBrain)
        let page = BookPage(type: .welcome, createdAt: now, promptText: welcome.prompt,
                            userInput: welcome.payload.body, tags: [], sourceID: welcome.sourceID)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [page])
        let recovered = FirstRunPageSequence.recordingResolvedGuidance(in: [], days: [day], events: [])
        XCTAssertTrue(recovered.contains("source:\(welcome.sourceID)"))
        XCTAssertEqual(FirstRunPageSequence.recordingResolvedGuidance(
            in: recovered, days: [day], events: []
        ), recovered)
    }

    func testLegacyRipRepairsWelcomeButHiddenServedWelcomeDoesNot() {
        let welcome = requested(.localBrain)
        func event(_ action: ReaderLearningAction) -> ReaderLearningEvent {
            ReaderLearningEvent(dayID: BookDay.id(for: now), occurredAt: now, action: action,
                                surfaceID: welcome.id, sourceID: welcome.sourceID, type: welcome.type,
                                varietyKey: welcome.varietyKey, hour: 12)
        }
        XCTAssertTrue(FirstRunPageSequence.recordingResolvedGuidance(
            in: [], days: [], events: [event(.surfaced)]
        ).isEmpty)
        XCTAssertTrue(FirstRunPageSequence.recordingResolvedGuidance(
            in: [], days: [], events: [event(.dismissed)]
        ).contains("source:\(welcome.sourceID)"))
    }

    func testOriginAndFirstWeekRespectPermanentProgressAndRemainManuallyReadable() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [SelfFact(
            id: "onboarding-name", questionID: "onboarding-name", question: "Name?", answer: "Beej",
            bookTranslation: "Beej", sensitivity: .delight, usePermission: .privateContext,
            tags: ["name", "onboarding"], createdAt: now, updatedAt: now
        )]
        let origin = InscriptionOriginPageSourceAdapter()
        let practice = InscriptionApprenticeshipPageSourceAdapter()
        XCTAssertFalse(origin.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).isEmpty)
        XCTAssertFalse(practice.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).isEmpty)
        inputs.firstRunEngagedKeys = ["first-door-origin", "first-door-apprenticeship:0"]
        XCTAssertTrue(origin.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).isEmpty)
        XCTAssertTrue(practice.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).isEmpty)
        XCTAssertFalse(requested(.origin, inputs: inputs).payload.body.isEmpty)
        XCTAssertFalse(requested(.firstWeek, inputs: inputs).payload.body.isEmpty)
    }

    func testIntroductionProgressOutlivesTheVarietyHistoryRetentionWindow() throws {
        let surface = requested(.compass)
        let oldHistory = CuratorVarietyGovernor.recordingServed(keys: surface.curatorServedHistoryKeys, into: [:], now: now)
        var vault = PlayerVaultData()
        vault.firstRunEngaged = FirstRunPageSequence.recordingShownGuidance(in: [], history: oldHistory)
        vault.surfaceHistory = CuratorVarietyGovernor.recordingServed(
            keys: ["source:ordinary"], into: oldHistory, now: now.addingTimeInterval(200 * 86_400)
        )
        let restored = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(vault))
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = Set(restored.firstRunEngaged ?? [])
        inputs.surfaceHistory = restored.surfaceHistory ?? [:]
        let key = "source:\(FirstRunPageSequence.compassIntroductionSourceID)"
        XCTAssertNil(inputs.surfaceHistory[key])
        XCTAssertTrue(FirstRunPageSequence.hasSeenGuidance(key, inputs: inputs))
    }

    func testWelcomeAndBrainAnnouncementsDoNotReturnThroughOrdinaryCurationAfterHistoryExpires() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.localBrainIsReady = true
        inputs.firstRunEngagedKeys = ["source:labyrinth-welcome", "source:local-brain-awake"]
        XCTAssertTrue(LabyrinthWelcomePageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ).isEmpty)
        XCTAssertTrue(LocalBrainAwakePageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ).isEmpty)
    }

    func testExplicitRequestsStayAvailableWithoutResettingAutomaticProgress() {
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = FirstRunPageSequence.automaticGuidanceKeys
        let progress = inputs.firstRunEngagedKeys
        for introduction in FirstRunPageSequence.Introduction.allCases {
            XCTAssertFalse(requested(introduction, inputs: inputs).payload.body.isEmpty, introduction.title)
        }
        XCTAssertEqual(inputs.firstRunEngagedKeys, progress)
    }
}
