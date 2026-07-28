import XCTest
@testable import InsideCoverCore

/// Distribution contracts for intention-led curation. These tests vary stable
/// session seeds rather than using runtime randomness, so failures reproduce.
final class BookSessionCurationSimulationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_050_000_000)

    func testBeliefFrequencyIsMonotonicWhileEveryEligiblePageStillAppears() {
        let beliefs = [0, 25, 50, 75, 100]
        let types: [BookPageType] = [.weather, .souvenir, .wonderCompass, .body, .quip]
        let pages = zip(beliefs, types).map { belief, type in
            SurfacePage(
                id: "belief-\(belief)",
                type: type,
                sourceID: "belief-\(belief)",
                intent: .capture,
                score: 60,
                prompt: type.title,
                detail: "An equally suitable fresh-sight candidate."
            )
        }
        let profiles = Dictionary(uniqueKeysWithValues: zip(beliefs, types).map { belief, type in
            let sourceID = "belief-\(belief)"
            return (sourceID, PageBeliefProfile(
                sourceID: sourceID,
                type: type,
                title: type.title,
                belief: belief,
                narrativeWeight: 20,
                cadence: "simulation",
                note: "simulation"
            ))
        })
        let preferences = CuratorSurfacePreferences(pageBeliefProfiles: profiles)
        var mood = CuratorMood.neutral
        mood.keptPageCount = 100
        XCTAssertEqual(CuratorNoveltyPolicy.belief(for: pages[4], preferences: preferences), 100)
        XCTAssertNil(BookCurator.candidateTrace(from: pages, preferences: preferences, mood: mood, now: now)[4].rejection)
        var counts = Dictionary(uniqueKeysWithValues: beliefs.map { ($0, 0) })

        for index in 0..<2_000 {
            let seed = "belief-session-\(index)"
            let intention = sessionIntention(movement: .freshSight, seed: seed)
            let selected = BookCurator.rankedPages(
                from: pages,
                limit: 1,
                preferences: preferences,
                mood: mood,
                now: now,
                intention: intention,
                selectionSeed: seed
            ).first?.page.id
            if let selected,
               let belief = Int(selected.replacingOccurrences(of: "belief-", with: "")) {
                counts[belief, default: 0] += 1
            }
        }

        for belief in beliefs {
            XCTAssertGreaterThan(counts[belief, default: 0], 0, "Belief \(belief) was accidentally vetoed.")
        }
        for (lower, higher) in zip(beliefs, beliefs.dropFirst()) {
            XCTAssertLessThan(
                counts[lower, default: 0],
                counts[higher, default: 0],
                "Higher Belief should increase long-run surfacing frequency."
            )
        }
        XCTAssertLessThan(counts[100, default: 0], 2_000, "Maximum Belief became certainty.")
    }

    func testEveryMovementCanComposeAReadableThreeRoleDesk() {
        let candidates = [
            page(.weather, intent: .capture),
            page(.wonderCompass, intent: .capture, action: true),
            page(.bookRemembered, intent: .resurface),
            page(.bookNotices, intent: .reflect),
            page(.letter, intent: .reflect),
            page(.narrativeOS, intent: .simulate),
            page(.lore, intent: .importReference),
            page(.wordNegotiation, intent: .reflect),
            page(.rest, intent: .rest),
            page(.quotes, intent: .importReference)
        ]
        var mood = CuratorMood.neutral
        mood.keptPageCount = 100

        for movement in BookReenchantmentMovement.allCases {
            let seed = "movement-\(movement.rawValue)"
            let intention = sessionIntention(movement: movement, seed: seed)
            let desk = BookCurator.rankedPages(
                from: candidates,
                limit: 3,
                mood: mood,
                now: now,
                intention: intention,
                selectionSeed: seed
            ).map(\.page)
            let roles = Set(desk.compactMap { $0.payload.metadata[BookSessionIntention.metadataRole] })

            XCTAssertEqual(desk.count, 3, "\(movement) produced an incomplete desk.")
            XCTAssertEqual(roles, Set(BookSessionRole.allCases.map(\.rawValue)))
            XCTAssertLessThanOrEqual(desk.filter(\.isReaderActionCommission).count, 1)
        }
    }

    func testDeepBenchIsComposedAsConditionalThreeRoleActsWithDormantReceipts() {
        let candidates = [
            page(.weather, intent: .capture),
            page(.wonderCompass, intent: .capture),
            page(.bookRemembered, intent: .resurface),
            page(.bookNotices, intent: .reflect),
            page(.letter, intent: .reflect),
            page(.narrativeOS, intent: .simulate),
            page(.lore, intent: .importReference),
            page(.wordNegotiation, intent: .reflect),
            page(.rest, intent: .rest),
            page(.quotes, intent: .importReference),
            page(.body, intent: .capture),
            page(.quip, intent: .importReference),
            page(.location, intent: .capture),
            page(.note, intent: .reflect),
            page(.gossip, intent: .reflect)
        ]
        var mood = CuratorMood.neutral
        mood.keptPageCount = 100
        let intention = sessionIntention(movement: .freshSight, seed: "prepared-score")
        let score = BookCurator.rankedPages(
            from: candidates,
            limit: 12,
            mood: mood,
            now: now,
            intention: intention,
            selectionSeed: intention.seed,
            alivenessFacets: ["time:evening", "weather:rain"]
        ).map(\.page)

        XCTAssertGreaterThanOrEqual(score.count, 9)
        XCTAssertEqual(Set(score.prefix(3).compactMap(\.preparedExperimentRole)), Set(BookSessionRole.allCases))
        XCTAssertEqual(Set(score.dropFirst(3).prefix(3).compactMap(\.preparedExperimentRole)), Set(BookSessionRole.allCases))
        XCTAssertEqual(Set(score.dropFirst(6).prefix(3).compactMap(\.preparedExperimentRole)), Set(BookSessionRole.allCases))
        XCTAssertTrue(score.prefix(3).allSatisfy { $0.preparedExperimentBranch == .current })
        XCTAssertTrue(score.dropFirst(3).prefix(3).allSatisfy { $0.preparedExperimentBranch == .afterKeep })
        XCTAssertTrue(score.dropFirst(6).prefix(3).allSatisfy { $0.preparedExperimentBranch == .afterDismissal })
        XCTAssertTrue(score.allSatisfy { $0.preparedExperimentIntentionID == intention.id })
        XCTAssertGreaterThanOrEqual(
            score.dropFirst(3).filter { CausalCurationReceipt.read(from: $0) != nil }.count,
            4,
            "Prepared randomized choices should carry dormant receipts; a deterministic last slot must not invent one."
        )
    }

    func testPreparedReplacementAnswersKeepAndDismissalWithDifferentBranches() {
        let intention = sessionIntention(movement: .freshSight, seed: "branch-order")
        let contextKey = "ctx-branch"
        let departing = BookPreparedExperimentScore.preparing(
            intention.applying(to: page(.weather, intent: .capture), role: .door),
            intention: intention,
            role: .door,
            actIndex: 0,
            contextKey: contextKey,
            now: now
        )
        let afterKeep = BookPreparedExperimentScore.preparing(
            intention.applying(to: page(.souvenir, intent: .capture), role: .door),
            intention: intention,
            role: .door,
            actIndex: 1,
            contextKey: contextKey,
            now: now
        )
        let afterDismissal = BookPreparedExperimentScore.preparing(
            intention.applying(to: page(.rest, intent: .rest), role: .door),
            intention: intention,
            role: .door,
            actIndex: 2,
            contextKey: contextKey,
            now: now
        )
        let candidates = [afterDismissal, afterKeep]

        XCTAssertEqual(BookCurator.preparedReplacementOrder(
            candidates: candidates,
            departing: departing,
            outcome: .kept,
            contextKey: contextKey,
            now: now,
            sleepsExperiment: false
        ).first?.id, afterKeep.id)
        XCTAssertEqual(BookCurator.preparedReplacementOrder(
            candidates: candidates,
            departing: departing,
            outcome: .dismissed,
            contextKey: contextKey,
            now: now,
            sleepsExperiment: false
        ).first?.id, afterDismissal.id)
    }

    func testFirstDoorDismissalBranchesButSecondDistinctDoorSleepsTheScore() {
        let intention = sessionIntention(movement: .freshSight, seed: "door-sleep")
        let firstDoor = intention.applying(
            to: page(.weather, intent: .capture, sourceID: "first-door"),
            role: .door
        )
        let secondDoor = intention.applying(
            to: page(.rest, intent: .rest, sourceID: "second-door"),
            role: .door
        )
        var learning = ReaderLearningModel()

        XCTAssertFalse(BookPreparedExperimentDismissalPolicy.sleepsExperiment(
            afterDismissing: firstDoor,
            learning: learning
        ))
        learning.record(ReaderLearningEvent(
            id: "first-door-pass",
            dayID: intention.dayID,
            occurredAt: now,
            action: .dismissed,
            surfaceID: firstDoor.id,
            sourceID: firstDoor.sourceID,
            type: firstDoor.type,
            varietyKey: firstDoor.varietyKey,
            hour: 18,
            tags: firstDoor.readerLearningTags + [ReaderLearningEvent.curationLearningForbiddenTag]
        ))

        XCTAssertFalse(BookPreparedExperimentDismissalPolicy.sleepsExperiment(
            afterDismissing: firstDoor,
            learning: learning
        ), "Undoing and passing the same Door again is not a second distinct refusal.")
        XCTAssertTrue(BookPreparedExperimentDismissalPolicy.sleepsExperiment(
            afterDismissing: secondDoor,
            learning: learning
        ))
        XCTAssertTrue(learning.sourceAffinities.isEmpty)
        XCTAssertTrue(learning.typeAffinities.isEmpty)
    }

    func testSleepingScoreMakesDirectorChooseAnotherMovementInTheSameTimeBand() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let candidates = [
            page(.weather, intent: .capture),
            page(.wonderCompass, intent: .capture),
            page(.bookRemembered, intent: .resurface),
            page(.letter, intent: .reflect),
            page(.narrativeOS, intent: .simulate),
            page(.lore, intent: .importReference)
        ]
        let first = BookSessionDirector.intention(
            for: day,
            inputs: .empty,
            candidates: candidates,
            preferences: .none,
            distressActive: false,
            now: now
        )
        let second = BookSessionDirector.intention(
            for: day,
            inputs: .empty,
            candidates: candidates,
            preferences: CuratorSurfacePreferences(dismissedSurfaceIDs: [first.restKey]),
            distressActive: false,
            now: now
        )

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertNotEqual(second.movement, first.movement)
    }

    func testExhaustingEveryDirectedMovementFallsBackToShelterNotARepeatedScore() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let candidates = [
            page(.weather, intent: .capture),
            page(.wonderCompass, intent: .capture),
            page(.bookRemembered, intent: .resurface),
            page(.letter, intent: .reflect),
            page(.narrativeOS, intent: .simulate),
            page(.lore, intent: .importReference)
        ]
        var sleepingKeys = Set<String>()
        var directedIDs = Set<String>()
        var finalMovement: BookReenchantmentMovement?

        for _ in 0...BookReenchantmentMovement.allCases.count {
            let intention = BookSessionDirector.intention(
                for: day,
                inputs: .empty,
                candidates: candidates,
                preferences: CuratorSurfacePreferences(dismissedSurfaceIDs: sleepingKeys),
                distressActive: false,
                now: now
            )
            finalMovement = intention.movement
            if intention.movement == .shelter { break }
            XCTAssertTrue(directedIDs.insert(intention.id).inserted)
            sleepingKeys.insert(intention.restKey)
        }

        XCTAssertEqual(finalMovement, .shelter)
    }

    func testSleepingScoreCannotResurrectFromItsPreparedReserve() {
        let rejected = sessionIntention(movement: .freshSight, seed: "sleeping")
        let next = sessionIntention(movement: .livingWorld, seed: "next")
        let contextKey = "ctx-new-door"
        let departing = BookPreparedExperimentScore.preparing(
            rejected.applying(to: page(.weather, intent: .capture), role: .door),
            intention: rejected,
            role: .door,
            actIndex: 0,
            contextKey: contextKey,
            now: now
        )
        let staleOldDoor = BookPreparedExperimentScore.preparing(
            rejected.applying(to: page(.souvenir, intent: .capture), role: .door),
            intention: rejected,
            role: .door,
            actIndex: 2,
            contextKey: contextKey,
            now: now
        )
        let newDoor = BookPreparedExperimentScore.preparing(
            next.applying(to: page(.location, intent: .capture), role: .door),
            intention: next,
            role: .door,
            actIndex: 0,
            contextKey: contextKey,
            now: now
        )
        let ordered = BookCurator.preparedReplacementOrder(
            candidates: [staleOldDoor, newDoor],
            departing: departing,
            outcome: .dismissed,
            contextKey: contextKey,
            now: now,
            sleepsExperiment: true
        )

        XCTAssertEqual(ordered.map(\.id), [newDoor.id])
    }

    func testDisabledAndDismissedSourcesRemainAbsoluteAcrossSeeds() {
        let forbidden = page(.weather, intent: .capture, sourceID: "forbidden-weather")
        let allowed = page(.souvenir, intent: .capture, sourceID: "allowed-souvenir")
        let preferences = CuratorSurfacePreferences(
            dismissedSurfaceIDs: forbidden.curatorDeskExclusionKeys,
            disabledSourceIDs: [forbidden.sourceID]
        )

        for index in 0..<200 {
            let seed = "boundary-session-\(index)"
            let intention = sessionIntention(movement: .freshSight, seed: seed)
            let selected = BookCurator.rankedPages(
                from: [forbidden, allowed],
                limit: 1,
                preferences: preferences,
                mood: .neutral,
                now: now,
                intention: intention,
                selectionSeed: seed
            ).first?.page

            XCTAssertEqual(selected?.id, allowed.id)
        }
    }

    func testChoosingPagesAloneCannotBecomeAClaimAboutChangedLife() {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<6 {
            model.ingest(alivenessEvent(
                id: "keep-\(offset)",
                dayOffset: offset,
                action: .kept,
                sourceID: "rain-walk"
            ))
        }

        XCTAssertTrue(model.patterns(now: now).isEmpty)
        XCTAssertTrue(model.observations.allSatisfy { $0.kind == .chosen })
    }

    func testLivedEvidenceTurnsRepeatedContextIntoAnIntimateRevisablePattern() {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<3 {
            model.ingest(alivenessEvent(
                id: "choice-\(offset)",
                dayOffset: offset,
                action: .acted,
                sourceID: "rain-walk"
            ))
        }
        let evidenceDate = now.addingTimeInterval(3 * 86_400)
        let evidencePage = BookPage(
            id: "lived-page",
            type: .wonderCompass,
            createdAt: evidenceDate,
            promptText: "Take the long wet way home.",
            userInput: "I took the long way in the rain and noticed the city had gone silver.",
            tags: ["book-session-id:rain-session", "book-session-role:door"],
            sourceID: "rain-walk",
            context: alivenessContext()
        )
        let evidence = BookLongGameEvidence(
            id: "lived-rain-walk",
            capacity: .spontaneousAttention,
            kind: .completedExperiment,
            line: "The reader took the long way in the rain and brought back the silver city.",
            evidencePageIDs: [evidencePage.id],
            happenedAt: evidenceDate,
            wasPromptedByBook: true
        )
        let game = BookLongGame(
            phase: .wakeTheSenses,
            strategy: "Find the conditions in which attention escapes the Book.",
            startedAt: now,
            lastAdvancedAt: evidenceDate,
            phasePresentedAt: now,
            milestones: [],
            evidence: [evidence]
        )

        model.reconcile(
            longGame: game,
            days: [BookDay(id: BookDay.id(for: evidenceDate), date: evidenceDate, pages: [evidencePage])],
            now: evidenceDate
        )
        let patterns = model.patterns(now: evidenceDate)

        XCTAssertFalse(patterns.isEmpty)
        XCTAssertTrue(patterns.contains { $0.facets.contains("weather:rain") })
        XCTAssertTrue(patterns.contains { $0.facets.contains("time:evening") })
        XCTAssertTrue(patterns.allSatisfy { !$0.falsifier.isEmpty && !$0.counterReading.isEmpty })
        XCTAssertTrue(model.observations.contains { $0.kind == .livedEvidence && $0.pageID == evidencePage.id })
    }

    func testReaderCanForbidAnIntimatePatternAndItDisappears() throws {
        var model = intimateModel()
        let pattern = try XCTUnwrap(model.patterns(now: now.addingTimeInterval(4 * 86_400)).first)
        model.ingest(ReaderLearningEvent(
            id: "forbid-pattern",
            dayID: BookDay.id(for: now.addingTimeInterval(5 * 86_400)),
            occurredAt: now.addingTimeInterval(5 * 86_400),
            action: .dismissed,
            surfaceID: "pattern-surface",
            sourceID: "book-notices",
            type: .bookNotices,
            varietyKey: "pattern",
            hour: 19,
            tags: ["aliveness-pattern:\(pattern.id)"],
            evidence: "Do not read me this way."
        ))

        XCTAssertFalse(model.patterns(now: now.addingTimeInterval(5 * 86_400)).contains { $0.id == pattern.id })
        XCTAssertEqual(model.patternFeedback[pattern.id]?.forbidden, true)
    }

    func testChoosingALaterReturnCreditsTheOriginalMovement() {
        var model = ReaderAlivenessModel.unwritten
        model.ingest(ReaderLearningEvent(
            id: "kept-return",
            dayID: BookDay.id(for: now),
            occurredAt: now,
            action: .kept,
            surfaceID: "remembered-surface",
            sourceID: "book-remembered",
            type: .bookRemembered,
            varietyKey: "remembered",
            hour: 19,
            tags: [
                "archive-return",
                "remembered-page:old-silver-city",
                "original-book-session-id:old-session",
                "original-book-session-movement:freshSight",
                "original-book-session-source:rain-walk"
            ],
            evidence: "It is still silver when the rain comes back.",
            context: alivenessContext()
        ))

        let returned = model.observations.first { $0.id == "return:kept-return" }
        XCTAssertEqual(returned?.kind, .followed)
        XCTAssertEqual(returned?.movement, .freshSight)
        XCTAssertEqual(returned?.sourceID, "rain-walk")
        XCTAssertEqual(returned?.pageID, "old-silver-city")
        XCTAssertEqual(returned?.impact, 58)
    }

    func testLaterReturnCreditsTheOriginalCausalOpportunity() {
        var model = ReaderAlivenessModel.unwritten
        let original = causalReceipt(
            id: "original-causal-door",
            selectedSourceID: "rain-door",
            selectedAt: now.addingTimeInterval(-20 * 86_400)
        )
        model.ingest(causalEvent(id: "original-surface", action: .surfaced, receipt: original))
        model.ingest(ReaderLearningEvent(
            id: "returned-original-page",
            dayID: BookDay.id(for: now),
            occurredAt: now,
            action: .kept,
            surfaceID: "book-remembered-return",
            sourceID: "book-remembered",
            type: .bookRemembered,
            varietyKey: "remembered",
            hour: 19,
            tags: [
                "archive-return",
                "remembered-page:old-silver-city",
                "original-book-session-id:old-session",
                "original-book-session-movement:freshSight",
                "original-book-session-source:rain-door",
                "original-causal-experiment:\(original.id)"
            ],
            evidence: "The silver city returned with the rain.",
            context: alivenessContext()
        ))

        let outcome = model.causalLedger?.outcomes.first {
            $0.opportunityID == original.id && $0.kind == .livedEvidence
        }
        XCTAssertEqual(outcome?.value, 0.68)
    }

    func testBookRememberedCarriesOriginalCausalReceiptForward() {
        let originalPage = BookPage(
            id: "original-causal-page",
            type: .wonderCompass,
            createdAt: now.addingTimeInterval(-60 * 86_400),
            promptText: "Look twice.",
            userInput: "The wet street went silver.",
            tags: [
                "book-session-id:old-session",
                "book-session-movement:freshSight",
                "causal-experiment:old-causal-experiment"
            ],
            sourceID: "rain-door"
        )
        let visitation = BookRememberedVisitation(
            page: originalPage,
            score: 80,
            reason: "Rain returned to the same street.",
            todayConnections: ["The weather rhymed."],
            action: "Look once more."
        )
        let surface = visitation.surface(
            source: BookPageSourceRegistry.source(for: .bookRemembered),
            day: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            now: now
        )

        XCTAssertTrue(surface.readerLearningTags.contains("original-causal-experiment:old-causal-experiment"))
    }

    func testLearnedAlivenessRaisesFrequencyWithoutEndingExploration() {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<5 {
            model.ingest(alivenessEvent(
                id: "true-\(offset)",
                dayOffset: offset,
                action: .loved,
                sourceID: "known-rain-door"
            ))
        }
        let known = page(.weather, intent: .capture, sourceID: "known-rain-door")
        let unknown = page(.souvenir, intent: .capture, sourceID: "untried-door")
        var knownCount = 0
        var unknownCount = 0

        for offset in 0..<1_000 {
            let seed = "intimate-selection-\(offset)"
            let intention = sessionIntention(movement: .freshSight, seed: seed)
            let selected = BookCurator.rankedPages(
                from: [known, unknown],
                limit: 1,
                mood: .neutral,
                now: now.addingTimeInterval(10 * 86_400),
                intention: intention,
                selectionSeed: seed,
                readerAliveness: model,
                alivenessFacets: ["time:evening", "weather:rain"]
            ).first?.page.sourceID
            if selected == known.sourceID { knownCount += 1 }
            if selected == unknown.sourceID { unknownCount += 1 }
        }

        XCTAssertGreaterThan(knownCount, unknownCount)
        XCTAssertGreaterThan(unknownCount, 0, "Earned intimacy became a filter instead of influence.")
    }

    func testSuccessfulMovementRestsWhileUntestedMovementAndStalenessReopenTheField() {
        var recent = ReaderAlivenessModel.unwritten
        recent.ingest(alivenessEvent(
            id: "recent-success",
            dayOffset: 0,
            action: .loved,
            sourceID: "known-rain-door"
        ))

        XCTAssertEqual(recent.movementExplorationMultiplier(.freshSight, now: now), 0.74)
        XCTAssertEqual(recent.movementExplorationMultiplier(.humanOtherness, now: now), 1.35)

        let onceIntimate = intimateModel()
        let muchLater = now.addingTimeInterval(200 * 86_400)
        XCTAssertFalse(onceIntimate.patterns(now: now).isEmpty)
        XCTAssertTrue(onceIntimate.patterns(now: muchLater).isEmpty)
    }

    func testOrdinaryWeightedPagesCarryACompleteCausalOpportunityReceipt() throws {
        let pages = [
            page(.weather, intent: .capture, sourceID: "rain-door"),
            page(.souvenir, intent: .capture, sourceID: "souvenir-door"),
            page(.bookNotices, intent: .reflect, sourceID: "notice-echo"),
            page(.bookRemembered, intent: .resurface, sourceID: "remembered-echo"),
            page(.lore, intent: .importReference, sourceID: "lore-horizon"),
            page(.quotes, intent: .importReference, sourceID: "quote-horizon")
        ]
        let profiles = Dictionary(uniqueKeysWithValues: pages.map { candidate in
            (candidate.sourceID, PageBeliefProfile(
                sourceID: candidate.sourceID,
                type: candidate.type,
                title: candidate.type.title,
                belief: 50,
                narrativeWeight: 20,
                cadence: "causal-test",
                note: "causal-test"
            ))
        })
        let selected = BookCurator.rankedPages(
            from: pages,
            limit: 3,
            preferences: CuratorSurfacePreferences(pageBeliefProfiles: profiles),
            mood: .neutral,
            now: now,
            intention: sessionIntention(movement: .freshSight, seed: "causal-receipts"),
            selectionSeed: "causal-receipts",
            alivenessFacets: ["time:evening", "weather:rain"]
        ).map(\.page)
        let receipts = selected.compactMap(CausalCurationReceipt.read(from:))

        XCTAssertFalse(receipts.isEmpty)
        let receipt = try XCTUnwrap(receipts.first)
        XCTAssertGreaterThanOrEqual(receipt.candidates.count, 2)
        XCTAssertGreaterThan(receipt.propensity, 0)
        XCTAssertLessThanOrEqual(receipt.propensity, 1)
        XCTAssertTrue(receipt.candidates.contains { $0.sourceID == receipt.chosenSourceID })
        XCTAssertEqual(receipt.policyVersion, CausalCurationReceipt.currentPolicyVersion)
        XCTAssertTrue(selected.contains { $0.readerLearningTags.contains("causal-experiment:\(receipt.id)".readerLearningNormalizedTag) })
    }

    func testOrdinarySessionCarriesAnExactMovementOpportunityReceipt() throws {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let candidates = [
            page(.weather, intent: .capture),
            page(.wonderCompass, intent: .capture, action: true),
            page(.bookRemembered, intent: .resurface),
            page(.wordNegotiation, intent: .reflect),
            page(.letter, intent: .reflect),
            page(.lore, intent: .importReference)
        ]
        let intention = BookSessionDirector.intention(
            for: day,
            inputs: .empty,
            candidates: candidates,
            preferences: .none,
            distressActive: false,
            now: now
        )
        let receipt = try XCTUnwrap(intention.causalMovementReceipt)
        let totalWeight = receipt.candidates.reduce(0) { $0 + $1.weight }
        let selectedWeight = try XCTUnwrap(
            receipt.candidates.first(where: { $0.movement == receipt.chosenMovement })?.weight
        )

        XCTAssertEqual(receipt.sessionID, intention.id)
        XCTAssertGreaterThanOrEqual(receipt.candidates.count, 2)
        XCTAssertEqual(receipt.propensity, selectedWeight / totalWeight, accuracy: 0.000_000_1)
        XCTAssertGreaterThan(receipt.propensity, 0)
        XCTAssertLessThan(receipt.propensity, 1)
    }

    func testShelterAndProtectedCeremoniesAreNotMovementExperiments() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let intention = BookSessionDirector.intention(
            for: day,
            inputs: .empty,
            candidates: [page(.rest, intent: .rest), page(.weather, intent: .capture)],
            preferences: .none,
            distressActive: true,
            now: now
        )

        XCTAssertEqual(intention.movement, .shelter)
        XCTAssertNil(intention.causalMovementReceipt)
    }

    func testShelterIsCareRatherThanAnExperiment() {
        let shelter = BookCurator.rankedPages(
            from: [
                page(.rest, intent: .rest, sourceID: "rest"),
                page(.weather, intent: .capture, sourceID: "weather"),
                page(.quotes, intent: .importReference, sourceID: "quotes")
            ],
            limit: 3,
            mood: .neutral,
            now: now,
            intention: sessionIntention(movement: .shelter, seed: "shelter"),
            selectionSeed: "shelter"
        ).map(\.page)

        XCTAssertFalse(shelter.isEmpty)
        XCTAssertTrue(shelter.allSatisfy { CausalCurationReceipt.read(from: $0) == nil })
    }

    func testImmediateKeepsCannotManufactureCausalUplift() {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<4 {
            let treatment = causalReceipt(
                id: "keep-treatment-\(offset)",
                selectedSourceID: "rain-door",
                selectedAt: now.addingTimeInterval(Double(offset) * 300)
            )
            let control = causalReceipt(
                id: "keep-control-\(offset)",
                selectedSourceID: "other-door",
                selectedAt: now.addingTimeInterval(Double(offset) * 300 + 120)
            )
            model.ingest(causalEvent(id: "surface-t-\(offset)", action: .surfaced, receipt: treatment))
            model.ingest(causalEvent(id: "keep-t-\(offset)", action: .kept, receipt: treatment))
            model.ingest(causalEvent(id: "surface-c-\(offset)", action: .surfaced, receipt: control))
            model.ingest(causalEvent(id: "keep-c-\(offset)", action: .kept, receipt: control))
        }
        let estimate = model.causalLedger?.estimate(
            movement: .freshSight,
            role: .door,
            sourceID: "rain-door",
            contextKey: causalContextKey,
            now: now.addingTimeInterval(3600)
        )

        XCTAssertEqual(estimate?.treatmentCount, 0)
        XCTAssertEqual(model.causalUpliftMultiplier(
            movement: .freshSight,
            role: .door,
            sourceID: "rain-door",
            contextKey: causalContextKey,
            now: now.addingTimeInterval(3600)
        ), 1)
    }

    func testQualifiedOutcomesLearnConservativeIncrementalLiftAgainstEligibleControls() throws {
        let model = causalUpliftModel()
        let estimate = try XCTUnwrap(model.causalLedger?.estimate(
            movement: .freshSight,
            role: .door,
            sourceID: "rain-door",
            contextKey: causalContextKey,
            now: now.addingTimeInterval(86_400)
        ))

        XCTAssertEqual(estimate.treatmentCount, 8)
        XCTAssertEqual(estimate.controlCount, 8)
        XCTAssertGreaterThan(estimate.treatmentMean, estimate.controlMean)
        XCTAssertGreaterThan(estimate.conservativeLowerBound, 0)
        XCTAssertTrue(estimate.usedExactContext)
        XCTAssertGreaterThan(model.causalUpliftMultiplier(
            movement: .freshSight,
            role: .door,
            sourceID: "rain-door",
            contextKey: causalContextKey,
            now: now.addingTimeInterval(86_400)
        ), 1)
    }

    func testQualifiedOutcomesLearnMovementLiftAgainstEligibleControls() throws {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<8 {
            let treatment = causalMovementReceipt(
                id: "movement-treatment-\(offset)",
                selectedMovement: .freshSight,
                selectedAt: now.addingTimeInterval(Double(offset) * 600)
            )
            let competingMovement: BookReenchantmentMovement = offset.isMultiple(of: 2)
                ? .livingWorld
                : .exactLanguage
            let control = causalMovementReceipt(
                id: "movement-control-\(offset)",
                selectedMovement: competingMovement,
                selectedAt: now.addingTimeInterval(Double(offset) * 600 + 300)
            )
            model.ingest(causalMovementEvent(
                id: "movement-surface-t-\(offset)",
                action: .surfaced,
                receipt: treatment
            ))
            model.ingest(causalMovementEvent(
                id: "movement-lived-t-\(offset)",
                action: .keepsakeEarned,
                receipt: treatment
            ))
            model.ingest(causalMovementEvent(
                id: "movement-surface-c-\(offset)",
                action: .surfaced,
                receipt: control
            ))
            model.ingest(causalMovementEvent(
                id: "movement-no-c-\(offset)",
                action: .dismissed,
                receipt: control
            ))
        }
        let estimate = try XCTUnwrap(model.causalLedger?.movementEstimate(
            movement: .freshSight,
            contextKey: causalContextKey,
            now: now.addingTimeInterval(86_400)
        ))

        XCTAssertEqual(estimate.treatmentCount, 8)
        XCTAssertEqual(estimate.controlCount, 8)
        XCTAssertGreaterThan(estimate.conservativeLowerBound, 0)
        XCTAssertGreaterThan(model.causalMovementUpliftMultiplier(
            movement: .freshSight,
            contextKey: causalContextKey,
            now: now.addingTimeInterval(86_400)
        ), 1)
    }

    func testOneLivedEventCreditsBothMovementAndPageOpportunities() {
        let movement = causalMovementReceipt(
            id: "joined-movement",
            selectedMovement: .freshSight,
            selectedAt: now
        )
        var page = causalReceipt(
            id: "joined-page",
            selectedSourceID: "rain-door",
            selectedAt: now
        )
        page.movementReceipt = movement
        var model = ReaderAlivenessModel.unwritten

        model.ingest(causalEvent(id: "joined-surface", action: .surfaced, receipt: page))
        model.ingest(causalEvent(id: "joined-lived", action: .keepsakeEarned, receipt: page))

        let credited = Set(model.causalLedger?.outcomes.map(\.opportunityID) ?? [])
        XCTAssertTrue(credited.contains(page.id))
        XCTAssertTrue(credited.contains(movement.id))
    }

    func testLegacyAlivenessModelDecodesWithoutInventingACausalHistory() throws {
        let legacy = Data(#"{"version":1,"observations":[],"patternFeedback":{},"lastUpdatedAt":null}"#.utf8)
        let decoded = try JSONDecoder().decode(ReaderAlivenessModel.self, from: legacy)

        XCTAssertNil(decoded.causalLedger)
        XCTAssertEqual(decoded.causalMovementUpliftMultiplier(
            movement: .freshSight,
            contextKey: causalContextKey,
            now: now
        ), 1)
    }

    func testPressureBudgetClosesAfterTwoUnansweredAsksAndReopensForLivedSignal() {
        var model = ReaderAlivenessModel.unwritten
        let first = causalReceipt(id: "pressure-one", selectedSourceID: "mission", selectedAt: now, pressureCost: 1)
        let second = causalReceipt(
            id: "pressure-two",
            selectedSourceID: "mission",
            selectedAt: now.addingTimeInterval(3600),
            pressureCost: 1
        )
        model.ingest(causalEvent(id: "pressure-surface-one", action: .surfaced, receipt: first))
        model.ingest(causalEvent(id: "pressure-surface-two", action: .surfaced, receipt: second))

        XCTAssertFalse(model.allowsHighPressureCausalAttempt(now: now.addingTimeInterval(7200)))

        model.ingest(causalEvent(id: "pressure-return", action: .followedThread, receipt: first))
        XCTAssertTrue(model.allowsHighPressureCausalAttempt(now: now.addingTimeInterval(7200)))
    }

    func testCausalLiftRaisesFrequencyButCannotEndExploration() {
        let model = causalUpliftModel()
        let known = page(.weather, intent: .capture, sourceID: "rain-door")
        let control = page(.souvenir, intent: .capture, sourceID: "other-door")
        var knownCount = 0
        var controlCount = 0

        for offset in 0..<1_000 {
            let seed = "causal-frequency-\(offset)"
            let selected = BookCurator.rankedPages(
                from: [known, control],
                limit: 1,
                mood: .neutral,
                now: now.addingTimeInterval(86_400),
                intention: sessionIntention(movement: .freshSight, seed: seed),
                selectionSeed: seed,
                readerAliveness: model,
                alivenessFacets: ["time:evening", "weather:rain"]
            ).first?.page.sourceID
            if selected == known.sourceID { knownCount += 1 }
            if selected == control.sourceID { controlCount += 1 }
        }

        XCTAssertGreaterThan(knownCount, controlCount)
        XCTAssertGreaterThan(controlCount, 0, "Causal uplift became a deterministic recommendation.")
    }

    func testMatureIntimatePatternCanBecomeACorrectableBookNotice() {
        let model = intimateModel()
        var inputs = BookSourceInputs.empty
        inputs.readerAliveness = model
        inputs.days = (0..<4).map { offset in
            let date = now.addingTimeInterval(Double(offset - 8) * 86_400)
            return BookDay(
                id: BookDay.id(for: date),
                date: date,
                pages: [BookPage(
                    id: "archive-\(offset)",
                    type: .souvenir,
                    createdAt: date,
                    promptText: "Keep one thing.",
                    userInput: "Rain on the long evening street, silver again.",
                    sourceID: "souvenir"
                )]
            )
        }
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let surface = BookNoticesPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        ).first { $0.payload.metadata["readerAlivenessReading"] == "true" }

        XCTAssertNotNil(surface)
        XCTAssertEqual(surface?.payload.metadata["feedbackPrompt"], "Did the Book truly find you here?")
        XCTAssertNotNil(surface?.payload.metadata["alivenessPatternID"])
        XCTAssertTrue(surface?.payload.body.contains("My pencil test:") == true)
    }

    private func sessionIntention(
        movement: BookReenchantmentMovement,
        seed: String
    ) -> BookSessionIntention {
        BookSessionIntention(
            id: "simulation-\(seed)",
            dayID: BookDay.id(for: now),
            movement: movement,
            ambition: movement == .livingContinuity ? .return : .glint,
            evidencePageIDs: [],
            evidenceReason: "A deterministic simulation supplied an honest opening.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(6 * 3600),
            seed: seed
        )
    }

    private func intimateModel() -> ReaderAlivenessModel {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<5 {
            model.ingest(alivenessEvent(
                id: "intimate-\(offset)",
                dayOffset: offset - 6,
                action: .loved,
                sourceID: "rain-walk"
            ))
        }
        return model
    }

    private var causalContextKey: String {
        ReaderAlivenessCurationContext.contextKey(["time:evening", "weather:rain"])
    }

    private func causalUpliftModel() -> ReaderAlivenessModel {
        var model = ReaderAlivenessModel.unwritten
        for offset in 0..<8 {
            let treatment = causalReceipt(
                id: "uplift-treatment-\(offset)",
                selectedSourceID: "rain-door",
                selectedAt: now.addingTimeInterval(Double(offset) * 600)
            )
            let control = causalReceipt(
                id: "uplift-control-\(offset)",
                selectedSourceID: "other-door",
                selectedAt: now.addingTimeInterval(Double(offset) * 600 + 300)
            )
            model.ingest(causalEvent(id: "uplift-surface-t-\(offset)", action: .surfaced, receipt: treatment))
            model.ingest(causalEvent(id: "uplift-return-t-\(offset)", action: .keepsakeEarned, receipt: treatment))
            model.ingest(causalEvent(id: "uplift-surface-c-\(offset)", action: .surfaced, receipt: control))
            model.ingest(causalEvent(id: "uplift-no-c-\(offset)", action: .dismissed, receipt: control))
        }
        return model
    }

    private func causalReceipt(
        id: String,
        selectedSourceID: String,
        selectedAt: Date,
        pressureCost: Double = 0.08
    ) -> CausalCurationReceipt {
        let sources = ["rain-door", "other-door"]
        let candidates = sources.map { source in
            CausalCurationCandidate(
                sourceID: source,
                armID: "freshsight-door-\(source)-\(causalContextKey)",
                weight: 1
            )
        }
        return CausalCurationReceipt(
            id: id,
            policyVersion: CausalCurationReceipt.currentPolicyVersion,
            sessionID: "session-\(id)",
            movement: .freshSight,
            role: .door,
            chosenSourceID: selectedSourceID,
            chosenArmID: "freshsight-door-\(selectedSourceID)-\(causalContextKey)",
            contextKey: causalContextKey,
            propensity: 0.5,
            candidates: candidates,
            pressureCost: pressureCost,
            selectedAt: selectedAt
        )
    }

    private func causalEvent(
        id: String,
        action: ReaderLearningAction,
        receipt: CausalCurationReceipt
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: id,
            dayID: BookDay.id(for: receipt.selectedAt),
            occurredAt: receipt.selectedAt.addingTimeInterval(60),
            action: action,
            surfaceID: "surface-\(receipt.id)",
            sourceID: receipt.chosenSourceID,
            type: .wonderCompass,
            varietyKey: "causal-test",
            hour: 19,
            tags: [
                "book-session:freshSight",
                "book-session-id:\(receipt.sessionID)",
                "book-session-role:door"
            ],
            evidence: action == .keepsakeEarned ? "The silver city came back outside the Book." : nil,
            context: alivenessContext(),
            causalReceipt: receipt
        )
    }

    private func causalMovementReceipt(
        id: String,
        selectedMovement: BookReenchantmentMovement,
        selectedAt: Date
    ) -> CausalMovementReceipt {
        let candidates = [
            CausalMovementCandidate(movement: .freshSight, weight: 2),
            CausalMovementCandidate(movement: .livingWorld, weight: 3),
            CausalMovementCandidate(movement: .exactLanguage, weight: 5)
        ]
        let total = candidates.reduce(0) { $0 + $1.weight }
        let selected = candidates.first(where: { $0.movement == selectedMovement })?.weight ?? 0
        return CausalMovementReceipt(
            id: id,
            policyVersion: CausalMovementReceipt.currentPolicyVersion,
            sessionID: "session-\(id)",
            chosenMovement: selectedMovement,
            contextKey: causalContextKey,
            propensity: selected / total,
            candidates: candidates,
            selectedAt: selectedAt
        )
    }

    private func causalMovementEvent(
        id: String,
        action: ReaderLearningAction,
        receipt: CausalMovementReceipt
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: id,
            dayID: BookDay.id(for: receipt.selectedAt),
            occurredAt: receipt.selectedAt.addingTimeInterval(60),
            action: action,
            surfaceID: "surface-\(receipt.id)",
            sourceID: "movement-test",
            type: .wonderCompass,
            varietyKey: "movement-causal-test",
            hour: 19,
            tags: [
                "book-session:\(receipt.chosenMovement.rawValue)",
                "book-session-id:\(receipt.sessionID)",
                "book-session-role:door"
            ],
            evidence: action == .keepsakeEarned ? "The silver city came back outside the Book." : nil,
            context: alivenessContext(),
            causalMovementReceipt: receipt
        )
    }

    private func alivenessEvent(
        id: String,
        dayOffset: Int,
        action: ReaderLearningAction,
        sourceID: String
    ) -> ReaderLearningEvent {
        let date = now.addingTimeInterval(Double(dayOffset) * 86_400)
        return ReaderLearningEvent(
            id: id,
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: action,
            surfaceID: "surface-\(id)",
            sourceID: sourceID,
            type: .wonderCompass,
            varietyKey: "rain-evening-walk",
            hour: 19,
            tags: [
                "book-session:freshSight",
                "book-session-id:session-\(dayOffset)",
                "book-session-role:door"
            ],
            evidence: "The rain made the long evening street look silver.",
            context: alivenessContext()
        )
    }

    private func alivenessContext() -> BookPageContextSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let evening = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2034,
            month: 12,
            day: 18,
            hour: 19
        ))!
        return BookPageContextSnapshot(
            at: evening,
            calendar: calendar,
            weatherTags: ["rain"],
            calendarEventCount: 0,
            locationLabel: "Old streets"
        )
    }

    private func page(
        _ type: BookPageType,
        intent: BookPageIntent,
        sourceID: String? = nil,
        action: Bool = false
    ) -> SurfacePage {
        SurfacePage(
            id: "simulation-\(sourceID ?? type.rawValue)",
            type: type,
            sourceID: sourceID ?? "simulation-\(type.rawValue)",
            intent: intent,
            score: 60,
            prompt: type.title,
            detail: "A simulation candidate.",
            payload: BookPagePayload(
                headline: type.title,
                body: "A simulation candidate.",
                metadata: action ? ["curatorActionCommission": "true"] : [:]
            )
        )
    }
}
