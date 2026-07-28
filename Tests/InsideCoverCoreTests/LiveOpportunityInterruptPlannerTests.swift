import XCTest
@testable import InsideCoverCore

final class LiveOpportunityInterruptPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_785_139_200)

    func testBoundedContextCapturesWeatherCategoriesWithoutRawWeatherCopy() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Hot cloud cover is moving in",
            source: "test",
            forecast: "Wind after sunset"
        )

        let captured = BookLiveOpportunityContext.capture(
            inputs: inputs,
            distressActive: false,
            now: now
        )

        XCTAssertTrue(Set(captured.salientWeatherTags).isSuperset(of: ["cloud", "hot", "wind"]))
        XCTAssertFalse(captured.contextKey.contains("Hot cloud cover"))
    }

    func testNearbyAnchorArrivalNominatesTheExactLiveAnchorPage() throws {
        let anchor = page(
            "anchor",
            type: .anchor,
            capability: PageCapabilityContract(
                supportedMovements: [.livingWorld, .freshSight],
                emotionalFunctions: [.wonder, .notice],
                effort: .small,
                reach: .nearbyWorld,
                estimatedMinutes: 5,
                asksReader: true,
                pressureCost: 0.28,
                proofModes: [.place],
                requirements: [.nearbyAnchor]
            )
        )
        let ordinary = page("ordinary", type: .radio)
        var mood = CuratorMood.neutral
        mood.hasNearbyAnchor = true

        let directive = try XCTUnwrap(BookLiveOpportunityPlanner.directive(
            from: context(key: "before"),
            to: context(key: "after", anchorID: "lamp-door"),
            activeIntention: intention(origin: context(key: "before")),
            candidates: [ordinary, anchor],
            preferences: .none,
            mood: mood,
            readerAliveness: .unwritten,
            now: now
        ))

        XCTAssertEqual(directive.kind, .nearbyAnchorArrived)
        XCTAssertTrue(directive.matches(anchor))
        XCTAssertEqual(directive.movement, .livingWorld)
        XCTAssertLessThanOrEqual(directive.expiresAt.timeIntervalSince(now), 45 * 60)
    }

    func testUnchangedWeatherCannotManufactureAnInterrupt() {
        let weather = page(
            "rain",
            type: .weather,
            capability: PageCapabilityContract(
                emotionalFunctions: [.notice, .wonder],
                effort: .glance,
                requirements: [.weatherContext]
            )
        )
        var mood = CuratorMood.neutral
        mood.hasWeatherContext = true

        XCTAssertNil(BookLiveOpportunityPlanner.directive(
            from: context(key: "before", weather: ["rain"]),
            to: context(key: "after", weather: ["rain"]),
            activeIntention: intention(origin: context(key: "before", weather: ["rain"])),
            candidates: [weather],
            preferences: .none,
            mood: mood,
            readerAliveness: .unwritten,
            now: now
        ))
    }

    func testWeatherTransitionDoesNotDependOnAnUnrelatedContextKeyChanging() throws {
        let weather = page(
            "storm-page",
            type: .weather,
            capability: PageCapabilityContract(
                supportedMovements: [.livingWorld, .freshSight],
                emotionalFunctions: [.notice, .wonder],
                effort: .glance,
                requirements: [.weatherContext]
            )
        )
        var mood = CuratorMood.neutral
        mood.hasWeatherContext = true

        let directive = try XCTUnwrap(BookLiveOpportunityPlanner.directive(
            from: context(key: "same", weather: ["clear"]),
            to: context(key: "same", weather: ["clear", "storm"]),
            activeIntention: intention(origin: context(key: "same", weather: ["clear"])),
            candidates: [weather],
            preferences: .none,
            mood: mood,
            readerAliveness: .unwritten,
            now: now
        ))

        XCTAssertEqual(directive.kind, .weatherTurned)
        XCTAssertTrue(directive.matches(weather))
    }

    func testStrategicInterventionAndRevelationRemainSovereign() {
        let anchor = page(
            "anchor",
            type: .anchor,
            capability: PageCapabilityContract(
                emotionalFunctions: [.wonder],
                effort: .small,
                reach: .nearbyWorld,
                requirements: [.nearbyAnchor]
            )
        )
        var mood = CuratorMood.neutral
        mood.hasNearbyAnchor = true
        var intervention = intention(origin: context(key: "before"))
        intervention.ambition = .intervention
        var revelation = intention(origin: context(key: "before"))
        revelation.ambition = .revelation

        for protected in [intervention, revelation] {
            XCTAssertNil(BookLiveOpportunityPlanner.directive(
                from: context(key: "before"),
                to: context(key: "after", anchorID: "lamp-door"),
                activeIntention: protected,
                candidates: [anchor],
                preferences: .none,
                mood: mood,
                readerAliveness: .unwritten,
                now: now
            ))
        }
    }

    func testHardCapabilityGateOutranksVeryHighBelief() throws {
        let belovedButImpossible = page(
            "beloved-impossible",
            type: .anchor,
            sourceID: "beloved-anchor",
            capability: PageCapabilityContract(
                emotionalFunctions: [.wonder],
                effort: .small,
                reach: .nearbyWorld,
                requirements: [.nearbyAnchor, .wideCapacity]
            )
        )
        let lowBeliefButPossible = page(
            "possible",
            type: .anchor,
            sourceID: "quiet-anchor",
            capability: PageCapabilityContract(
                emotionalFunctions: [.wonder, .notice],
                effort: .small,
                reach: .nearbyWorld,
                requirements: [.nearbyAnchor]
            )
        )
        var mood = CuratorMood.neutral
        mood.hasNearbyAnchor = true
        mood.readerCurrentState = ReaderCurrentState(capacity: 5)
        let preferences = CuratorSurfacePreferences(
            pageBeliefProfiles: [
                belovedButImpossible.sourceID: belief(for: belovedButImpossible, amount: 100),
                lowBeliefButPossible.sourceID: belief(for: lowBeliefButPossible, amount: 0)
            ]
        )

        let directive = try XCTUnwrap(BookLiveOpportunityPlanner.directive(
            from: context(key: "before", capacity: .some),
            to: context(key: "after", anchorID: "lamp-door", capacity: .some),
            activeIntention: intention(origin: context(key: "before", capacity: .some)),
            candidates: [belovedButImpossible, lowBeliefButPossible],
            preferences: preferences,
            mood: mood,
            readerAliveness: .unwritten,
            now: now
        ))

        XCTAssertTrue(directive.matches(lowBeliefButPossible))
        XCTAssertFalse(directive.matches(belovedButImpossible))
    }

    func testNewCalendarWindowChoosesAnUndertakingThatActuallyFits() throws {
        let tooLong = page(
            "too-long",
            type: .wonderCompass,
            capability: PageCapabilityContract(
                supportedMovements: [.chosenDetour],
                emotionalFunctions: [.act, .wonder],
                effort: .involved,
                reach: .plannedWorld,
                estimatedMinutes: 120,
                asksReader: true,
                pressureCost: 0.70
            )
        )
        let fitting = page(
            "fitting",
            type: .wonderCompass,
            sourceID: "fitting-compass",
            capability: PageCapabilityContract(
                supportedMovements: [.chosenDetour],
                emotionalFunctions: [.act, .wonder],
                effort: .involved,
                reach: .plannedWorld,
                estimatedMinutes: 25,
                asksReader: true,
                pressureCost: 0.55,
                proofModes: [.observation]
            )
        )
        var mood = CuratorMood.neutral
        mood.minutesToNextCalendarEvent = 90

        let directive = try XCTUnwrap(BookLiveOpportunityPlanner.directive(
            from: context(key: "busy", occupied: true, nextEventMinutes: 5),
            to: context(key: "open", occupied: false, nextEventMinutes: 90),
            activeIntention: intention(origin: context(key: "busy", occupied: true, nextEventMinutes: 5)),
            candidates: [tooLong, fitting],
            preferences: .none,
            mood: mood,
            readerAliveness: .unwritten,
            now: now
        ))

        XCTAssertEqual(directive.kind, .calendarWindowOpened)
        XCTAssertTrue(directive.matches(fitting))
        XCTAssertFalse(directive.matches(tooLong))
    }

    func testCapacityDropYieldsToLowPressureShelter() throws {
        let shelter = page(
            "shelter",
            type: .rest,
            capability: PageCapabilityContract(
                supportedMovements: [.shelter],
                emotionalFunctions: [.soothe],
                effort: .glance,
                pressureCost: 0.03
            )
        )
        let expedition = page(
            "expedition",
            type: .wonderCompass,
            capability: PageCapabilityContract(
                supportedMovements: [.chosenDetour],
                emotionalFunctions: [.act, .wonder],
                effort: .involved,
                reach: .plannedWorld,
                asksReader: true,
                pressureCost: 0.78
            )
        )
        var mood = CuratorMood.neutral
        mood.readerCurrentState = ReaderCurrentState(capacity: 2)

        let directive = try XCTUnwrap(BookLiveOpportunityPlanner.directive(
            from: context(key: "wide", capacity: .wide),
            to: context(key: "little", capacity: .little),
            activeIntention: intention(origin: context(key: "wide", capacity: .wide)),
            candidates: [expedition, shelter],
            preferences: .none,
            mood: mood,
            readerAliveness: .unwritten,
            now: now
        ))

        XCTAssertEqual(directive.kind, .shelterNeeded)
        XCTAssertTrue(directive.matches(shelter))
        XCTAssertEqual(directive.movement, .shelter)
    }

    func testDirectorReplacesActiveScoreAndTargetRoundTripsThroughPageMetadata() throws {
        let origin = context(key: "before")
        let anchorPage = page(
            "anchor",
            type: .anchor,
            capability: PageCapabilityContract(
                supportedMovements: [.livingWorld],
                emotionalFunctions: [.wonder],
                effort: .small,
                reach: .nearbyWorld,
                requirements: [.nearbyAnchor]
            )
        )
        var inputs = BookSourceInputs.empty
        inputs.activeBookSessionIntention = intention(origin: origin)
        inputs.nearbyAnchor = AnchorProximity(anchor: anchorRecord(), distanceMeters: 12)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let replacement = BookSessionDirector.intention(
            for: day,
            inputs: inputs,
            candidates: [anchorPage],
            preferences: .none,
            distressActive: false,
            now: now
        )
        let directive = try XCTUnwrap(replacement.liveOpportunity)
        let surfaced = replacement.applying(to: anchorPage, role: .door)
        let decoded = try XCTUnwrap(BookSessionIntention.read(from: surfaced))

        XCTAssertNotEqual(replacement.id, inputs.activeBookSessionIntention?.id)
        XCTAssertEqual(directive.kind, .nearbyAnchorArrived)
        XCTAssertTrue(surfaced.isLiveOpportunityInterruptTarget)
        XCTAssertEqual(decoded.liveOpportunity, directive)
        XCTAssertEqual(decoded.originContext, replacement.originContext)
    }

    func testUntouchedDeskInsertionProtectsMilestoneAndDoesNotStackAsks() {
        let milestone = page("milestone", metadata: ["milestone": "true"])
        let oldAsk = page(
            "old-ask",
            type: .diary,
            capability: PageCapabilityContract(
                emotionalFunctions: [.express],
                asksReader: true,
                pressureCost: 0.30,
                proofModes: [.response]
            )
        )
        let calm = page("calm", type: .radio)
        let opportunity = page(
            "opportunity",
            type: .anchor,
            metadata: ["curatorActionCommission": "true"],
            capability: PageCapabilityContract(
                supportedMovements: [.livingWorld],
                emotionalFunctions: [.wonder, .act],
                effort: .small,
                reach: .nearbyWorld,
                asksReader: true,
                pressureCost: 0.40,
                proofModes: [.place]
            )
        )
        let directive = BookLiveOpportunityDirective(
            kind: .nearbyAnchorArrived,
            signature: "live-opportunity-test",
            targetSurfaceID: opportunity.id,
            targetSourceID: opportunity.sourceID,
            targetType: opportunity.type,
            targetContentKey: opportunity.curatorContentNoveltyKey,
            movement: .livingWorld,
            priority: 120,
            reason: "A nearby Anchor arrived.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(1800)
        )
        var liveIntention = intention(origin: context(key: "after", anchorID: "lamp-door"))
        liveIntention.liveOpportunity = directive
        let targeted = liveIntention.applying(to: opportunity, role: .door)

        let result = BookCurator.insertingLiveOpportunityIntoUntouchedDesk(
            previous: [milestone, oldAsk, calm],
            rebuilt: [targeted, calm],
            limit: 3
        )

        XCTAssertEqual(result.first?.id, targeted.id)
        XCTAssertTrue(result.contains(where: { $0.id == milestone.id }))
        XCTAssertFalse(result.contains(where: { $0.id == oldAsk.id }))
        XCTAssertEqual(result.filter(\.spendsCuratorAskBudget).count, 1)
        XCTAssertEqual(result.filter(\.spendsCuratorActionBudget).count, 1)
    }

    func testDeterministicOpportunityInsertionCannotPretendToBeARandomizedExperiment() throws {
        let ordinary = page("ordinary", type: .weather)
        let receipt = CausalCurationReceipt(
            id: "causal-test",
            policyVersion: CausalCurationReceipt.currentPolicyVersion,
            sessionID: "session-test",
            movement: .freshSight,
            role: .door,
            chosenSourceID: ordinary.sourceID,
            chosenArmID: "arm-test",
            contextKey: "weather-test",
            propensity: 0.4,
            candidates: [
                CausalCurationCandidate(
                    sourceID: ordinary.sourceID,
                    armID: "arm-test",
                    weight: 0.4
                )
            ],
            pressureCost: 0.03,
            selectedAt: now,
            chosenType: .weather,
            typePropensity: 0.8,
            pagePropensityWithinType: 0.5,
            pageCandidateCountWithinType: 2
        )
        let received = receipt.applying(to: ordinary)
        let stripped = CausalCurationReceipt.removing(from: received)

        XCTAssertNotNil(CausalCurationReceipt.read(from: received))
        XCTAssertNil(CausalCurationReceipt.read(from: stripped))
        XCTAssertNil(stripped.payload.metadata["causalExperimentID"])
        XCTAssertFalse((stripped.payload.metadata["tags"] ?? "").contains("causal-experiment"))
    }

    private func context(
        key: String,
        anchorID: String? = nil,
        hasNearbyPlaces: Bool = false,
        place: String? = nil,
        weather: [String] = [],
        occupied: Bool = false,
        nextEventMinutes: Int? = nil,
        capacity: BookLiveOpportunityCapacityBand = .unknown,
        distress: Bool = false
    ) -> BookLiveOpportunityContext {
        BookLiveOpportunityContext(
            contextKey: key,
            capturedAt: now,
            nearbyAnchorID: anchorID,
            hasNearbyPlaces: hasNearbyPlaces,
            placeContext: place,
            salientWeatherTags: weather,
            calendarIsOccupied: occupied,
            minutesToNextCalendarEvent: nextEventMinutes,
            capacityBand: capacity,
            distressActive: distress
        )
    }

    private func intention(origin: BookLiveOpportunityContext) -> BookSessionIntention {
        BookSessionIntention(
            id: "active-intention",
            dayID: BookDay.id(for: now),
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: [],
            evidenceReason: "An ordinary active score.",
            createdAt: now.addingTimeInterval(-600),
            expiresAt: now.addingTimeInterval(3600),
            seed: "active-intention",
            originContext: origin
        )
    }

    private func page(
        _ id: String,
        type: BookPageType = .quotes,
        sourceID: String? = nil,
        metadata: [String: String] = [:],
        capability: PageCapabilityContract = PageCapabilityContract(
            emotionalFunctions: [.notice],
            effort: .glance,
            pressureCost: 0.03
        )
    ) -> SurfacePage {
        var metadata = metadata
        metadata["noveltyKey"] = id
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID ?? "live-\(id)",
            intent: type == .rest ? .rest : .reflect,
            renderStyle: .promptCard,
            score: 64,
            prompt: "Page \(id)",
            detail: "A readable exact Page.",
            payload: BookPagePayload(
                headline: "Page \(id)",
                body: "A readable body for \(id).",
                metadata: metadata
            )
        ).withPageCapabilities(capability)
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

    private func anchorRecord() -> AnchorRecord {
        AnchorRecord(
            id: "lamp-door",
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
            playerWords: "A patient light.",
            academyEcho: "A shelf is listening.",
            outerStacksRoom: "A room behind the shelf.",
            fae: "A ticket-stub Fae",
            miniStory: "A map moved.",
            localRule: "Notice before speaking.",
            visitCount: 1,
            lastVisited: "2026-07-20"
        )
    }
}
