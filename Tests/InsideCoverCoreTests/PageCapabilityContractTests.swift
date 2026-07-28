import XCTest
@testable import InsideCoverCore

final class PageCapabilityContractTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(
        year: 2026,
        month: 7,
        day: 27,
        hour: 14
    ))!

    func testLegacyPagesReceiveConservativeInferredCapabilities() {
        let rest = page(id: "legacy-rest", type: .rest)
        let action = page(
            id: "legacy-action",
            type: .wonderCompass,
            metadata: ["curatorActionCommission": "true"]
        )

        XCTAssertEqual(rest.pageCapabilities.authorship, .inferred)
        XCTAssertEqual(rest.pageCapabilities.effort, .glance)
        XCTAssertEqual(rest.pageCapabilities.reach, .insideBook)
        XCTAssertTrue(rest.pageCapabilities.emotionalFunctions.contains(.soothe))
        XCTAssertEqual(rest.pageCapabilities.pressureCost, 0.08, accuracy: 0.000_001)

        XCTAssertEqual(action.pageCapabilities.authorship, .inferred)
        XCTAssertEqual(action.pageCapabilities.effort, .involved)
        XCTAssertEqual(action.pageCapabilities.reach, .nearbyWorld)
        XCTAssertTrue(action.pageCapabilities.proofModes.contains(.observation))
        XCTAssertEqual(action.pageCapabilities.pressureCost, 1, accuracy: 0.000_001)
    }

    func testAuthoredContractRoundTripsThroughSurfaceMetadata() throws {
        let contract = PageCapabilityContract(
            supportedMovements: [.freshSight, .livingWorld],
            supportedRoles: [.door, .horizon],
            emotionalFunctions: [.notice, .wonder],
            effort: .small,
            reach: .nearbyWorld,
            mobility: .shortDistance,
            cost: .free,
            estimatedMinutes: 7,
            asksReader: true,
            pressureCost: 0.42,
            proofModes: [.observation, .photograph],
            requirements: [.locationContext, .openCalendarWindow]
        )
        let decorated = page(id: "authored").withPageCapabilities(contract)

        XCTAssertEqual(decorated.pageCapabilities, contract)
        XCTAssertEqual(decorated.payload.metadata["pageCapabilitySignature"], contract.signature)
        XCTAssertEqual(decorated.payload.metadata["pageCapabilityAuthorship"], "authored")
        XCTAssertNotNil(decorated.payload.metadata[PageCapabilityContract.metadataKey])
    }

    func testMalformedOrFutureContractFallsBackToLegacyInference() {
        let malformed = page(
            id: "malformed",
            type: .rest,
            metadata: [PageCapabilityContract.metadataKey: "not-base-64"]
        )
        let future = page(id: "future", type: .rest).withPageCapabilities(
            PageCapabilityContract(version: PageCapabilityContract.currentVersion + 1)
        )

        XCTAssertEqual(malformed.pageCapabilities.authorship, .inferred)
        XCTAssertEqual(malformed.pageCapabilities.effort, .glance)
        XCTAssertEqual(future.pageCapabilities.authorship, .inferred)
        XCTAssertEqual(future.pageCapabilities.effort, .glance)
    }

    func testTrueCapabilityRequirementIsAHardGateEvenWithHighBelief() {
        let weatherRequired = page(id: "needs-weather", type: .weather)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.notice, .wonder],
                effort: .glance,
                requirements: [.weatherContext]
            ))
        let fallback = page(id: "available-lore", type: .lore)
        let preferences = CuratorSurfacePreferences(pageBeliefProfiles: [
            weatherRequired.curatorContentNoveltyKey: belief(for: weatherRequired, amount: 100),
            fallback.curatorContentNoveltyKey: belief(for: fallback, amount: 0)
        ])

        let selected = BookCurator.rankedPages(
            from: [weatherRequired, fallback],
            limit: 1,
            preferences: preferences,
            mood: .neutral,
            now: now,
            intention: intention(seed: "weather-gate"),
            selectionSeed: "weather-gate"
        ).first?.page
        let trace = BookCurator.candidateTrace(
            from: [weatherRequired, fallback],
            preferences: preferences,
            mood: .neutral,
            now: now,
            intention: intention(seed: "weather-gate")
        )

        XCTAssertEqual(selected?.id, fallback.id)
        XCTAssertEqual(trace.first(where: { $0.surfaceID == weatherRequired.id })?.rejection, "capability-requirements-unmet")
        XCTAssertEqual(trace.first(where: { $0.surfaceID == weatherRequired.id })?.capabilityAllowed, false)
    }

    func testLowCapacitySteersExactPageTowardGlanceWithoutVetoingInvolvedPage() {
        let glance = page(id: "one-breath", type: .weather)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.notice],
                effort: .glance,
                estimatedMinutes: 1
            ))
        let involved = page(id: "weather-expedition", type: .weather)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.notice, .wonder],
                effort: .involved,
                reach: .nearbyWorld,
                mobility: .shortDistance,
                estimatedMinutes: 25,
                asksReader: true,
                pressureCost: 0.60,
                proofModes: [.observation]
            ))
        var mood = CuratorMood.neutral
        mood.readerCurrentState = ReaderCurrentState(
            aliveness: nil,
            wonder: nil,
            hiddenMagic: nil,
            capacity: 2,
            freshestAnswerAt: now
        )
        var glanceCount = 0
        var involvedCount = 0

        for offset in 0..<600 {
            let seed = "capacity-exact-page-\(offset)"
            let selected = BookCurator.rankedPages(
                from: [glance, involved],
                limit: 1,
                mood: mood,
                now: now,
                intention: intention(seed: seed),
                selectionSeed: seed
            ).first?.page
            if selected?.id == glance.id { glanceCount += 1 }
            if selected?.id == involved.id { involvedCount += 1 }
        }

        XCTAssertGreaterThan(glanceCount, involvedCount)
        XCTAssertGreaterThan(involvedCount, 0, "Soft context fit must steer probability, not erase an eligible Page.")
    }

    func testSelectedExactCapabilityAndPressureEnterPrivateReceipt() throws {
        let first = page(id: "receipt-a", type: .weather)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.notice],
                effort: .glance,
                pressureCost: 0.19
            ))
        let second = page(id: "receipt-b", type: .weather)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.wonder],
                effort: .small,
                pressureCost: 0.47
            ))
        let selected = try XCTUnwrap(BookCurator.rankedPages(
            from: [first, second],
            limit: 1,
            mood: .neutral,
            now: now,
            intention: intention(seed: "capability-receipt"),
            selectionSeed: "capability-receipt"
        ).first?.page)
        let receipt = try XCTUnwrap(CausalCurationReceipt.read(from: selected))

        XCTAssertEqual(receipt.pressureCost, selected.pageCapabilities.pressureCost, accuracy: 0.000_001)
        XCTAssertEqual(selected.payload.metadata["pageCapabilitySignature"], selected.pageCapabilities.signature)
        XCTAssertEqual(selected.payload.metadata["pageCapabilityAuthorship"], "authored")
    }

    func testWonderCompassAuthorsDifferentContractsForDifferentExactExperiences() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let pages = WonderCompassPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )
        let passage = try XCTUnwrap(pages.first {
            $0.payload.metadata["snippetID"] != nil
                && $0.payload.metadata["pennySentenceLesson"] == nil
        })
        let run = try XCTUnwrap(pages.first { $0.payload.metadata["compassStep"] == "run" })
        let mission = try XCTUnwrap(pages.first { $0.payload.metadata["playfulMissionID"] != nil })

        XCTAssertTrue(pages.allSatisfy { $0.pageCapabilities.authorship == .authored })
        XCTAssertEqual(passage.pageCapabilities.effort, .glance)
        XCTAssertEqual(passage.pageCapabilities.reach, .insideBook)
        XCTAssertEqual(run.pageCapabilities.effort, .involved)
        XCTAssertEqual(run.pageCapabilities.reach, .plannedWorld)
        XCTAssertEqual(mission.pageCapabilities.reach, .nearbyWorld)
        XCTAssertTrue(mission.pageCapabilities.proofModes.contains(.observation))
        XCTAssertGreaterThan(mission.pageCapabilities.pressureCost, passage.pageCapabilities.pressureCost)
    }

    func testStoryDiaryAndRadioFamiliesPublishAuthoredExactPageContracts() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let diary = DiaryPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: .empty,
            now: now
        )
        let stories = NarrativeOSPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: .empty,
            now: now
        )
        let radio = RadioPageSourceAdapter().manualSurface(
            for: day,
            context: context,
            inputs: .empty,
            now: now
        )

        XCTAssertFalse(diary.isEmpty)
        XCTAssertTrue(diary.allSatisfy { $0.pageCapabilities.authorship == .authored })
        XCTAssertTrue(diary.allSatisfy { $0.pageCapabilities.proofModes == [.response] })
        XCTAssertTrue(diary.allSatisfy { $0.pageCapabilities.asksReader })

        XCTAssertFalse(stories.isEmpty)
        XCTAssertTrue(stories.allSatisfy { $0.pageCapabilities.authorship == .authored })
        XCTAssertTrue(stories.allSatisfy { $0.pageCapabilities.reach == .insideBook })
        XCTAssertTrue(stories.allSatisfy { $0.pageCapabilities.emotionalFunctions.contains(.play) })

        XCTAssertEqual(radio.pageCapabilities.authorship, .authored)
        XCTAssertEqual(radio.pageCapabilities.effort, .glance)
        XCTAssertLessThan(radio.pageCapabilities.pressureCost, 0.15)
    }

    func testRealWorldDoorFamiliesPublishPressureReachAndProofHonestly() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let wicker = WickerDarePageSourceAdapter().manualSurface(
            for: day,
            context: context,
            inputs: .empty,
            now: now
        )
        let enchantment = try XCTUnwrap(EnchantmentPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: .empty,
            now: now
        ).first)
        let jump = BookJumpPageSourceAdapter().manualSurface(
            for: day,
            context: context,
            inputs: .empty,
            now: now
        )
        let flyleaf = ElectivePageSourceAdapter().flyleafSurface(
            for: day,
            inputs: .empty,
            now: now
        )

        XCTAssertEqual(wicker.pageCapabilities.authorship, .authored)
        XCTAssertEqual(wicker.pageCapabilities.reach, .nearbyWorld)
        XCTAssertTrue(wicker.spendsCuratorActionBudget)
        XCTAssertTrue(wicker.pageCapabilities.proofModes.contains(.observation))

        XCTAssertEqual(enchantment.pageCapabilities.reach, .nearbyWorld)
        XCTAssertTrue(enchantment.pageCapabilities.proofModes.contains(.photograph))
        XCTAssertEqual(jump.pageCapabilities.reach, .insideBook)
        XCTAssertTrue(jump.pageCapabilities.emotionalFunctions.contains(.play))
        XCTAssertEqual(flyleaf.pageCapabilities.effort, .glance)
        XCTAssertFalse(flyleaf.pageCapabilities.asksReader)
    }

    func testLiveAnchorAndPactErrandCarryRealWorldPrerequisiteAndPressure() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let anchor = AnchorRecord(
            id: "capability-anchor",
            name: "The Lamp Door",
            latitude: 40,
            longitude: -75,
            radiusMeters: 200,
            kind: .notice,
            belief: 20,
            created: "2026-07-01",
            weather: "clear",
            moon: "Full Moon",
            season: "Summer",
            playerWords: "The place with the patient light.",
            academyEcho: "A shelf is listening.",
            outerStacksRoom: "A narrow room behind the travel shelf.",
            fae: "A ticket-stub Fae",
            miniStory: "A map moved when no one touched it.",
            localRule: "Notice one title before speaking.",
            visitCount: 1,
            lastVisited: "2026-07-20"
        )
        var inputs = BookSourceInputs.empty
        inputs.nearbyAnchor = AnchorProximity(anchor: anchor, distanceMeters: 12)
        var pact = PactWarState()
        pact.errands = [PactErrand(
            id: "capability-errand",
            talismanID: "ember-seal",
            territoryID: "shelf-story",
            openingLine: "The border moved.",
            terms: "Bring back one true change in a familiar place.",
            offeredAt: now.addingTimeInterval(-600),
            deadline: now.addingTimeInterval(7_200),
            status: .owed,
            fieldReport: nil,
            talismanResponse: nil,
            deliveredAt: nil
        )]
        inputs.pactWar = pact

        let anchorPage = OuterStacksAnchorPageSourceAdapter().manualSurface(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
        let errand = try XCTUnwrap(PactErrandPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        ).first)
        var nearMood = CuratorMood.neutral
        nearMood.hasNearbyAnchor = true

        XCTAssertEqual(anchorPage.pageCapabilities.requirements, [.nearbyAnchor])
        XCTAssertFalse(anchorPage.pageCapabilities.isEligible(in: .neutral))
        XCTAssertTrue(anchorPage.pageCapabilities.isEligible(in: nearMood))
        XCTAssertTrue(anchorPage.pageCapabilities.proofModes.contains(.place))

        XCTAssertEqual(errand.pageCapabilities.authorship, .authored)
        XCTAssertEqual(errand.pageCapabilities.reach, .nearbyWorld)
        XCTAssertTrue(errand.spendsCuratorActionBudget)
        XCTAssertGreaterThanOrEqual(errand.pageCapabilities.pressureCost, 0.75)
    }

    private func page(
        id: String,
        type: BookPageType = .weather,
        metadata: [String: String] = [:]
    ) -> SurfacePage {
        var metadata = metadata
        metadata["noveltyKey"] = id
        return SurfacePage(
            id: id,
            type: type,
            sourceID: "capability-\(type.rawValue)",
            intent: type == .rest ? .rest : .capture,
            renderStyle: .promptCard,
            score: 60,
            prompt: "Page \(id)",
            detail: "Readable detail for \(id).",
            payload: BookPagePayload(
                headline: "Page \(id)",
                body: "Readable body for \(id).",
                metadata: metadata
            )
        )
    }

    private func intention(seed: String) -> BookSessionIntention {
        BookSessionIntention(
            id: "capability-\(seed)",
            dayID: BookDay.id(for: now),
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: [],
            evidenceReason: "A deterministic capability test supplies the opening.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(6 * 3600),
            seed: seed
        )
    }

    private func belief(for page: SurfacePage, amount: Int) -> PageBeliefProfile {
        PageBeliefProfile(
            sourceID: page.sourceID,
            type: page.type,
            title: page.payload.headline,
            belief: amount,
            narrativeWeight: 20,
            cadence: "test",
            note: "test"
        )
    }
}
