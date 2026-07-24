import XCTest
@testable import InsideCoverCore

final class NightGardenerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_000_000)

    func testValidatorAcceptsOneGroundedAdversarialStrategy() throws {
        let packet = packet()
        let result = BookReenchantmentStrategyValidator.validate(
            packet: packet,
            naturalist: naturalist(),
            heretic: heretic(),
            gardener: gardener(),
            aliveness: .unwritten,
            now: now
        )
        let strategy = try result.get()
        XCTAssertEqual(strategy.capacity, .worldOtherness)
        XCTAssertEqual(strategy.tactic, .alterRoute)
        XCTAssertEqual(strategy.status, .proposed)
        XCTAssertEqual(strategy.packetSignature, packet.evidenceSignature)
        XCTAssertEqual(strategy.expiresAt, now.addingTimeInterval(7 * 86_400))
    }

    func testValidatorRejectsInventedEvidence() {
        var naturalist = naturalist()
        naturalist.candidates[0].evidenceIDs.append("invented")
        let result = BookReenchantmentStrategyValidator.validate(
            packet: packet(),
            naturalist: naturalist,
            heretic: heretic(),
            gardener: gardener(),
            aliveness: .unwritten,
            now: now
        )
        XCTAssertEqual(result.failure, .inventedEvidence)
    }

    func testValidatorRejectsPulseOnlyTheoryEvenAcrossThreeDays() {
        var packet = packet()
        packet.evidence = (0..<3).map { offset in
            ReenchantmentStrategyEvidence(
                id: "pulse-\(offset)",
                stream: offset == 0 ? .statePulse : .delayedOutcome,
                occurredAt: now.addingTimeInterval(Double(-offset) * 86_400),
                polarity: 1,
                isLivedProof: true,
                wasPromptedByBook: true,
                line: "A pulse answered.",
                pageIDs: []
            )
        }
        var naturalist = naturalist()
        naturalist.candidates[0].evidenceIDs = packet.evidence.map(\.id)
        let result = BookReenchantmentStrategyValidator.validate(
            packet: packet,
            naturalist: naturalist,
            heretic: heretic(),
            gardener: gardener(),
            aliveness: .unwritten,
            now: now
        )
        XCTAssertEqual(result.failure, .pulseOnlyEvidence)
    }

    func testHereticCanKillAFlatteringTheory() {
        var heretic = heretic()
        heretic.assessments[0].verdict = .reject
        let result = BookReenchantmentStrategyValidator.validate(
            packet: packet(),
            naturalist: naturalist(),
            heretic: heretic,
            gardener: gardener(),
            aliveness: .unwritten,
            now: now
        )
        XCTAssertEqual(result.failure, .rejectedByHeretic)
    }

    func testValidatorCapsPressureAtReaderPermission() throws {
        var packet = packet()
        packet.permission = .gentle
        var gardener = gardener()
        gardener.pressure = .confront
        let strategy = try BookReenchantmentStrategyValidator.validate(
            packet: packet,
            naturalist: naturalist(),
            heretic: heretic(),
            gardener: gardener,
            aliveness: .unwritten,
            now: now
        ).get()
        XCTAssertEqual(strategy.pressureCap, .invite)
    }

    func testStrategyAdoptionRequiresFreshMatchingEvidenceAndOnlyOneActiveTheory() throws {
        let packet = packet()
        let strategy = try validatedStrategy(packet: packet)
        var game = longGame()
        XCTAssertTrue(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &game,
            currentPacketSignature: packet.evidenceSignature,
            now: now
        ))
        XCTAssertEqual(game.activeStrategy?.status, .active)
        XCTAssertFalse(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &game,
            currentPacketSignature: packet.evidenceSignature,
            now: now
        ))

        var staleGame = longGame()
        XCTAssertFalse(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &staleGame,
            currentPacketSignature: "different-evidence",
            now: now
        ))
    }

    func testDirectorUsesValidatedStrategyWithoutCreatingASecondCampaignSlot() throws {
        let packet = packet()
        var game = longGame(startedAt: now.addingTimeInterval(-20 * 86_400))
        let strategy = try validatedStrategy(packet: packet)
        XCTAssertTrue(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &game,
            currentPacketSignature: packet.evidenceSignature,
            now: now
        ))

        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: BookDay.id(for: now),
            date: Calendar.current.startOfDay(for: now),
            pages: (0..<3).map { offset in
                BookPage(
                    id: "kept-\(offset)",
                    type: .plainPage,
                    createdAt: now.addingTimeInterval(Double(-offset) * 3_600),
                    promptText: "A kept page",
                    userInput: "A true fragment \(offset)",
                    origin: .userAuthored
                )
            }
        )]
        inputs.bookInterior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-20 * 86_400),
            longGame: game
        )
        inputs.selfFacts = []

        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)
        XCTAssertEqual(game.currentCampaign?.strategyID, strategy.id)
        XCTAssertEqual(game.currentCampaign?.tactic, .alterRoute)
        XCTAssertEqual(game.currentCampaign?.pressure, .invite)

        let originalCampaignID = game.currentCampaign?.id
        BookReenchantmentDirector.reconcile(
            &game,
            inputs: inputs,
            now: now.addingTimeInterval(3_600)
        )
        XCTAssertEqual(game.currentCampaign?.id, originalCampaignID)
    }

    func testRejectedStrategyIsArchivedWhenCampaignFinishes() throws {
        let packet = packet()
        var game = longGame()
        let strategy = try validatedStrategy(packet: packet)
        XCTAssertTrue(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &game,
            currentPacketSignature: packet.evidenceSignature,
            now: now
        ))
        let campaign = campaign(strategyID: strategy.id, rejectionCount: 1)
        BookReenchantmentStrategyLifecycle.markRejected(&game, campaign: campaign)
        BookReenchantmentStrategyLifecycle.finish(&game, campaign: campaign)
        XCTAssertNil(game.activeStrategy)
        XCTAssertEqual(game.strategyHistory.last?.status, .rejected)
    }

    func testLegacyLongGameDecodesWithoutInventingStrategyHistory() throws {
        let json = """
        {
          "phase":"wakeTheSenses",
          "strategy":"notice",
          "startedAt":0,
          "lastAdvancedAt":0,
          "milestones":[],
          "evidence":[],
          "hypotheses":[],
          "campaignHistory":[]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BookLongGame.self, from: json)
        XCTAssertNil(decoded.activeStrategy)
        XCTAssertTrue(decoded.strategyHistory.isEmpty)
    }

    func testReviewGateWaitsForEvidenceAndDoesNotReviewAnActiveStrategy() throws {
        var thin = packet()
        thin.livedProofCount = 1
        XCTAssertFalse(NightGardenerReviewGate.shouldReview(
            packet: thin,
            activeStrategy: nil,
            strategyHistory: [],
            now: now
        ))

        let strategy = try validatedStrategy(packet: packet())
        var active = strategy
        active.status = .active
        XCTAssertFalse(NightGardenerReviewGate.shouldReview(
            packet: packet(),
            activeStrategy: active,
            strategyHistory: [],
            now: now
        ))
    }

    func testDeterministicUnderstudyProducesAValidatedStrategyWithoutModelOutput() {
        var packet = packet()
        packet.currentHypothesis = ReenchantmentHypothesisBrief(
            id: "missing-world",
            capacity: .worldOtherness,
            statement: "The archive still needs literal otherness.",
            nextHonestTest: "Meet something on its own terms.",
            evidenceIDs: []
        )
        let strategy = DeterministicNightGardenerUnderstudy.propose(
            packet: packet,
            aliveness: .unwritten,
            now: now
        )
        XCTAssertEqual(strategy?.capacity, .worldOtherness)
        XCTAssertEqual(strategy?.status, .proposed)
        XCTAssertEqual(strategy?.packetSignature, packet.evidenceSignature)
        XCTAssertTrue(strategy?.id.hasPrefix("deterministic-night-gardener-strategy-") == true)
        XCTAssertEqual(Set(strategy?.evidenceIDs ?? []), Set(packet.evidence.map(\.id)))
    }

    func testDeterministicUnderstudyAvoidsRestingAndRecentlyUsedTactics() {
        var packet = packet()
        packet.currentHypothesis = ReenchantmentHypothesisBrief(
            id: "missing-world",
            capacity: .worldOtherness,
            statement: "The archive still needs literal otherness.",
            nextHonestTest: "Meet something on its own terms.",
            evidenceIDs: []
        )
        packet.restingTactics = [.alterRoute, .changeScale]
        packet.recentCampaigns = [
            ReenchantmentCampaignBrief(
                id: "recent",
                capacity: .worldOtherness,
                tactic: .alterRoute,
                pressure: .invite,
                status: .completed,
                outcomeEvidenceCount: 0,
                rejectionCount: 1,
                startedAt: now.addingTimeInterval(-10 * 86_400),
                lastChangedAt: now.addingTimeInterval(-8 * 86_400)
            )
        ]
        let strategy = DeterministicNightGardenerUnderstudy.propose(
            packet: packet,
            aliveness: .unwritten,
            now: now
        )
        XCTAssertEqual(strategy?.tactic, .meetNonhumanBusiness)
    }

    func testDeterministicUnderstudyRemainsSilentWithoutThreeLivedDays() {
        var thin = packet()
        thin.evidence = Array(thin.evidence.prefix(2))
        XCTAssertNil(DeterministicNightGardenerUnderstudy.propose(
            packet: thin,
            aliveness: .unwritten,
            now: now
        ))
    }

    func testCouncilJSONParserIgnoresFencesButRequiresACompleteObject() {
        let response = """
        ```json
        {"candidates":[{"id":"h1","capacity":"worldOtherness","thesis":"Literal encounters may wake the day when routine is dense.","counterReading":"The route itself may be incidental to having spare time.","evidenceIDs":["lived-1","long-1"],"confidence":78}]}
        ```
        """
        XCTAssertEqual(
            NightGardenerJSON.decode(NightGardenerNaturalistResponse.self, from: response)?
                .candidates.first?.id,
            "h1"
        )
        XCTAssertNil(NightGardenerJSON.decode(
            NightGardenerNaturalistResponse.self,
            from: "{\"candidates\":"
        ))
    }

    func testUnpresentedStrategyIsArchivedAsUntriedRatherThanWeakened() throws {
        let packet = packet()
        var game = longGame(startedAt: now.addingTimeInterval(-30 * 86_400))
        let strategy = try validatedStrategy(packet: packet)
        XCTAssertTrue(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &game,
            currentPacketSignature: packet.evidenceSignature,
            now: now
        ))
        var inputs = eligibleInputs(game: game)

        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)
        XCTAssertNotNil(game.currentCampaign)
        inputs.bookInterior.longGame = game
        BookReenchantmentDirector.reconcile(
            &game,
            inputs: inputs,
            now: now.addingTimeInterval(8 * 86_400)
        )

        XCTAssertNil(game.currentCampaign)
        XCTAssertEqual(game.campaignHistory.last?.status, .untried)
        XCTAssertEqual(game.strategyHistory.last?.status, .untried)
        XCTAssertNil(game.activeStrategy)
    }

    func testYearOfSilenceRetiresUntriedCampaignsWithoutParallelismOrEscalation() throws {
        let packet = packet()
        var game = longGame(startedAt: now.addingTimeInterval(-30 * 86_400))
        let strategy = try validatedStrategy(packet: packet)
        XCTAssertTrue(BookReenchantmentStrategyLifecycle.adopt(
            strategy,
            into: &game,
            currentPacketSignature: packet.evidenceSignature,
            now: now
        ))

        var inputs = eligibleInputs(game: game)

        var campaignIDs = Set<String>()
        for day in 0..<365 {
            let date = now.addingTimeInterval(Double(day) * 86_400)
            inputs.bookInterior.longGame = game
            BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: date)
            if let campaign = game.currentCampaign {
                campaignIDs.insert(campaign.id)
                XCTAssertLessThanOrEqual(campaign.pressure.rank, BookCampaignPressure.nudge.rank)
            }
            XCTAssertLessThanOrEqual(game.campaignHistory.count, 24)
        }

        XCTAssertGreaterThan(campaignIDs.count, 1)
        XCTAssertTrue(game.campaignHistory.allSatisfy { $0.status == .untried })
        XCTAssertEqual(game.strategyHistory.first?.status, .untried)
    }

    func testRepeatedUnenactedStrategiesExpireIntoBoundedHistory() throws {
        var game = longGame()

        for week in 0..<52 {
            let formedAt = now.addingTimeInterval(Double(week * 7) * 86_400)
            var weeklyPacket = packet()
            weeklyPacket.builtAt = formedAt
            weeklyPacket.evidenceSignature = "signature-\(week)"
            var strategy = try validatedStrategy(packet: weeklyPacket)
            strategy.id = "weekly-strategy-\(week)"
            strategy.formedAt = formedAt
            strategy.expiresAt = formedAt.addingTimeInterval(3 * 86_400)

            XCTAssertTrue(BookReenchantmentStrategyLifecycle.adopt(
                strategy,
                into: &game,
                currentPacketSignature: weeklyPacket.evidenceSignature,
                now: formedAt
            ))
            XCTAssertNil(game.currentCampaign)
            BookReenchantmentStrategyLifecycle.expireIfNeeded(
                &game,
                now: formedAt.addingTimeInterval(4 * 86_400)
            )
            XCTAssertNil(game.activeStrategy)
        }

        XCTAssertEqual(game.strategyHistory.count, 32)
        XCTAssertTrue(game.strategyHistory.allSatisfy { $0.status == .expired })
        XCTAssertEqual(game.strategyHistory.first?.id, "weekly-strategy-20")
        XCTAssertEqual(game.strategyHistory.last?.id, "weekly-strategy-51")
    }

    private func packet() -> ReenchantmentStrategyPacket {
        let evidence = [
            ReenchantmentStrategyEvidence(
                id: "lived-1",
                stream: .alivenessReceipt,
                occurredAt: now.addingTimeInterval(-5 * 86_400),
                polarity: 1,
                isLivedProof: true,
                wasPromptedByBook: false,
                line: "The unfamiliar route produced a keepsake.",
                pageIDs: ["page-1"]
            ),
            ReenchantmentStrategyEvidence(
                id: "long-1",
                stream: .longGame,
                occurredAt: now.addingTimeInterval(-3 * 86_400),
                polarity: 1,
                isLivedProof: true,
                wasPromptedByBook: true,
                line: "The reader returned with an exact field note.",
                pageIDs: ["page-2"]
            ),
            ReenchantmentStrategyEvidence(
                id: "reader-1",
                stream: .readerAuthored,
                occurredAt: now.addingTimeInterval(-86_400),
                polarity: 0,
                isLivedProof: false,
                wasPromptedByBook: false,
                line: "The detour made the familiar street look inhabited again.",
                pageIDs: ["page-3"]
            )
        ]
        return ReenchantmentStrategyPacket(
            id: "packet",
            version: 1,
            builtAt: now,
            evidenceSignature: "signature",
            direction: .holding,
            confidence: 80,
            currentScore: 7,
            sevenDayAverage: 7,
            previousSevenDayAverage: 6,
            thirtyDayChange: 0.8,
            distinctMeasuredDays: 8,
            livedProofCount: 3,
            counterSignalCount: 0,
            evidenceStreamCount: 3,
            spontaneousShare: 0.66,
            currentState: ReenchantmentCurrentStateBrief(
                aliveness: 7,
                wonder: 6,
                hiddenMagic: 7,
                capacity: 7,
                freshestAnswerAt: now
            ),
            capacities: [],
            evidence: evidence,
            patterns: [],
            causalEffects: [],
            currentHypothesis: nil,
            recentCampaigns: [],
            permission: .nudge,
            boundaryIDs: [],
            restingTactics: [],
            evidenceGaps: []
        )
    }

    private func naturalist() -> NightGardenerNaturalistResponse {
        NightGardenerNaturalistResponse(candidates: [
            NightGardenerNaturalistCandidate(
                id: "h1",
                capacity: .worldOtherness,
                thesis: "Safe alterations of familiar routes may let the world recover its autonomy.",
                counterReading: "The apparent effect may instead come from spare time on those particular days.",
                evidenceIDs: ["lived-1", "long-1", "reader-1"],
                confidence: 82
            )
        ])
    }

    private func heretic() -> NightGardenerHereticResponse {
        NightGardenerHereticResponse(assessments: [
            NightGardenerHereticAssessment(
                candidateID: "h1",
                verdict: .preserve,
                strongestAlternative: "Available time, rather than novelty, may have caused the lived result.",
                missingEvidence: "A comparable open period without a route change.",
                manipulationRisk: "The Book could confuse compliance with an encounter.",
                confidenceAdjustment: -5
            )
        ])
    }

    private func gardener() -> NightGardenerProposal {
        NightGardenerProposal(
            candidateID: "h1",
            movement: .livingWorld,
            tactic: .alterRoute,
            contextFacets: ["time:afternoon", "day-load:open"],
            predictedOutcome: "The reader returns with an unprompted exact detail from a safe altered route.",
            expectedEvidenceKinds: [.explicitFieldNote, .spontaneousPattern],
            measurementWindowDays: 7,
            falsifier: "If two comparable altered routes leave no lived trace, weaken the theory.",
            stopCondition: "Stop immediately after refusal, distress, or unsafe conditions.",
            pressure: .nudge,
            confidence: 78
        )
    }

    private func validatedStrategy(
        packet: ReenchantmentStrategyPacket
    ) throws -> BookReenchantmentStrategy {
        try BookReenchantmentStrategyValidator.validate(
            packet: packet,
            naturalist: naturalist(),
            heretic: heretic(),
            gardener: gardener(),
            aliveness: .unwritten,
            now: now
        ).get()
    }

    private func longGame(startedAt: Date? = nil) -> BookLongGame {
        BookLongGame(
            phase: .wakeTheSenses,
            strategy: "Notice what answers.",
            startedAt: startedAt ?? now.addingTimeInterval(-20 * 86_400),
            lastAdvancedAt: startedAt ?? now.addingTimeInterval(-20 * 86_400),
            phasePresentedAt: nil,
            milestones: [],
            hypotheses: [BookLongGameHypothesis(
                id: "deterministic",
                capacity: .spontaneousAttention,
                statement: "The archive still needs unprompted attention.",
                nextHonestTest: "Leave room.",
                evidenceIDs: [],
                formedAt: now.addingTimeInterval(-10 * 86_400),
                lastRevisedAt: now
            )]
        )
    }

    private func eligibleInputs(game: BookLongGame) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: BookDay.id(for: now),
            date: Calendar.current.startOfDay(for: now),
            pages: (0..<3).map { offset in
                BookPage(
                    id: "silent-kept-\(offset)",
                    type: .plainPage,
                    createdAt: now.addingTimeInterval(Double(-offset) * 3_600),
                    promptText: "A kept page",
                    userInput: "A lived fragment \(offset)",
                    origin: .userAuthored
                )
            }
        )]
        inputs.bookInterior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-30 * 86_400),
            longGame: game
        )
        return inputs
    }

    private func campaign(
        strategyID: String,
        rejectionCount: Int
    ) -> BookReenchantmentCampaign {
        BookReenchantmentCampaign(
            id: "campaign",
            hypothesisID: "strategy-hypothesis",
            capacity: .worldOtherness,
            tactic: .alterRoute,
            pressure: .nudge,
            permission: .nudge,
            beat: .release,
            status: .resting,
            presentation: .silence,
            intendedRealWorldEffect: "A lived encounter.",
            readerNamedEdge: nil,
            edgeEvidencePageIDs: [],
            startingEvidenceIDs: [],
            outcomeEvidenceIDs: [],
            outcomeEvidencePageIDs: [],
            startedAt: now,
            lastChangedAt: now,
            nextEligibleAt: now,
            rejectionCount: rejectionCount,
            strategyID: strategyID
        )
    }
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
