import XCTest
@testable import InsideCoverCore

final class BookInteriorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private lazy var now = calendar.date(
        from: DateComponents(year: 2026, month: 7, day: 19, hour: 15)
    )!

    private func keptPage(_ index: Int, type: BookPageType = .souvenir) -> BookPage {
        BookPage(
            id: "kept-\(index)",
            type: type,
            createdAt: now.addingTimeInterval(Double(-index) * 3_600),
            promptText: "Keep one exact thing.",
            userInput: "The blue cup held a crooked piece of afternoon light number \(index).",
            tags: ["souvenir", index.isMultiple(of: 2) ? "threshold" : "light"]
        )
    }

    private func spontaneousPage(
        _ index: Int,
        daysAgo: Int,
        tags: [String] = []
    ) -> BookPage {
        BookPage(
            id: "spontaneous-\(index)",
            type: .plainPage,
            createdAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            promptText: "",
            userInput: "Something from the unassigned world, kept on day \(daysAgo).",
            tags: ["plain", "private"] + tags,
            sourceID: "plain-page",
            origin: .userAuthored
        )
    }

    private func favor(status: BookFavorStatus = .offered) -> BookFavor {
        BookFavor(
            id: "favor-test-notice",
            facet: .notice,
            title: "Three Things the Room Forgot",
            ask: "Find one color, one sound, and one small movement.",
            whyItMayHelp: "It gives an ordinary minute more texture.",
            practiceShape: "Keep the three details in one sentence.",
            createdAt: now,
            status: status,
            acceptedAt: nil,
            completedAt: nil,
            evidencePageIDs: []
        )
    }

    private func completedFavor(_ index: Int, daysAgo: Int = 20) -> BookFavor {
        BookFavor(
            id: "completed-favor-\(index)",
            facet: BookWonderFacet.allCases[index % BookWonderFacet.allCases.count],
            family: BookFavorFamily.allCases[index % BookFavorFamily.allCases.count],
            title: "Completed Favor \(index)",
            ask: "Notice one true thing.",
            whyItMayHelp: "Attention changes what can be remembered.",
            practiceShape: "Keep one sentence.",
            reflectionQuestion: "What changed?",
            completionReply: "The ordinary world answered favor \(index).",
            createdAt: now.addingTimeInterval(Double(-(daysAgo + 1)) * 86_400),
            status: .completed,
            acceptedAt: now.addingTimeInterval(Double(-(daysAgo + 1)) * 86_400),
            completedAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            evidencePageIDs: ["favor-proof-\(index)"]
        )
    }

    func testReconciliationGivesTheBookAnEvidenceBoundInnerLife() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...10).map { keptPage($0) })]

        let state = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-30 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(state.isAwake)
        XCTAssertNotNil(state.fascination)
        XCTAssertFalse(state.fascination?.evidencePageIDs.isEmpty ?? true)
        XCTAssertNotNil(state.favorite)
        XCTAssertNotNil(state.activeFavor)
        XCTAssertEqual(state.activeFavor?.status, .offered)
        XCTAssertEqual(state.secret?.status, .sealed)
        XCTAssertFalse(state.quirks.isEmpty)
        XCTAssertNotNil(state.opinion)
        XCTAssertNotNil(state.longGame)
        XCTAssertTrue(BookObsession.vow.contains("notice it, discover it, play with it"))
    }

    func testVersionOneInteriorMigratesWithoutLosingEarlierMemories() throws {
        let original = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-30 * 86_400),
            secret: BookSecret(
                id: "old-secret",
                tease: "An older sealed leaf.",
                revelation: "The old Book remembered this.",
                sealedAt: now.addingTimeInterval(-8 * 86_400),
                status: .sealed,
                revealedAt: nil
            ),
            activeFavor: favor()
        )
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["version"] = 1
        for key in ["secretHistory", "quirks", "opinion", "opinionHistory", "longGame"] {
            object.removeValue(forKey: key)
        }
        if var secret = object["secret"] as? [String: Any] {
            secret.removeValue(forKey: "family")
            object["secret"] = secret
        }
        if var activeFavor = object["activeFavor"] as? [String: Any] {
            activeFavor.removeValue(forKey: "family")
            activeFavor.removeValue(forKey: "cultivates")
            activeFavor.removeValue(forKey: "reflectionQuestion")
            activeFavor.removeValue(forKey: "completionReply")
            object["activeFavor"] = activeFavor
        }
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let migrated = try JSONDecoder().decode(BookInteriorState.self, from: legacyData)

        XCTAssertEqual(migrated.version, BookInteriorState.currentVersion)
        XCTAssertEqual(migrated.secret?.id, "old-secret")
        XCTAssertEqual(migrated.secret?.family, .method)
        XCTAssertEqual(migrated.activeFavor?.id, "favor-test-notice")
        XCTAssertEqual(migrated.activeFavor?.cultivates, .spontaneousAttention)
        XCTAssertFalse(migrated.activeFavor?.reflectionQuestion.isEmpty ?? true)
        XCTAssertEqual(migrated.quirks, [])
        XCTAssertNil(migrated.longGame)
    }

    func testQuirksMatureGraduallyAndRemainTheSameBook() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...32).map { keptPage($0) })]
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-45 * 86_400),
            favorHistory: [completedFavor(1), completedFavor(2)]
        )

        let first = BookInteriorEngine.reconciled(starting, inputs: inputs, now: now, calendar: calendar)
        let second = BookInteriorEngine.reconciled(first, inputs: inputs, now: now.addingTimeInterval(3600), calendar: calendar)

        XCTAssertEqual(first.quirks.map(\.id), second.quirks.map(\.id))
        XCTAssertEqual(first.quirks.count, 5)
        XCTAssertTrue(first.quirks.contains { $0.maturity == .beloved })
        XCTAssertTrue(first.quirks.contains { $0.revealedAt != nil })
    }

    func testSecretFamiliesRotateInsteadOfRepeatingOneConfession() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...12).map { keptPage($0) })]
        let revealed = BookSecret(
            id: "revealed-method",
            family: .method,
            tease: "A method.",
            revelation: "An old method.",
            sealedAt: now.addingTimeInterval(-20 * 86_400),
            status: .revealed,
            revealedAt: now.addingTimeInterval(-10 * 86_400)
        )
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-60 * 86_400),
            secret: revealed,
            secretHistory: [revealed]
        )

        let evolved = BookInteriorEngine.reconciled(starting, inputs: inputs, now: now, calendar: calendar)

        XCTAssertNotEqual(evolved.secret?.id, revealed.id)
        XCTAssertNotEqual(evolved.secret?.family, .method)
        XCTAssertTrue(evolved.secretHistory.contains { $0.id == revealed.id })
    }

    func testOpinionStrengthensWithEvidenceAndKeepsItsRevision() {
        let fascination = BookFascination(
            id: "fascination-light",
            facet: .notice,
            subject: "afternoon light",
            line: "Light keeps entering through ordinary objects.",
            evidencePageIDs: ["kept-1"],
            bornAt: now.addingTimeInterval(-20 * 86_400),
            lastDeepenedAt: now
        )
        let inputs = BookSourceInputs.empty
        var state = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-40 * 86_400), fascination: fascination),
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(state.opinion?.strength, .wondering)

        state.fascination?.evidencePageIDs = ["kept-1", "kept-2", "kept-3", "kept-4"]
        state = BookInteriorEngine.reconciled(
            state,
            inputs: inputs,
            now: now.addingTimeInterval(86_400),
            calendar: calendar
        )

        XCTAssertEqual(state.opinion?.strength, .held)
        XCTAssertEqual(state.opinion?.revisions.count, 1)
        XCTAssertEqual(state.opinion?.revisions.last?.reason, "More Pages joined the evidence.")
        XCTAssertNil(state.opinion?.firstPresentedAt)
    }

    func testWrongWagerForcesAVisibleChangeOfMind() {
        let earlierOpinion = BookOpinion(
            id: "opinion-old",
            subject: "returning doors",
            statement: "I think the returning door will open again this week.",
            strength: .leaning,
            evidencePageIDs: ["kept-1", "kept-2"],
            formedAt: now.addingTimeInterval(-20 * 86_400),
            lastRevisedAt: now.addingTimeInterval(-10 * 86_400),
            revisions: [],
            firstPresentedAt: now.addingTimeInterval(-9 * 86_400)
        )
        var inputs = BookSourceInputs.empty
        inputs.wagers = [BookWager(
            id: "wrong-door-wager",
            subjectID: "doors",
            subjectName: "returning doors",
            kind: .pattern,
            prediction: "A returning door will appear this week.",
            sealedAt: now.addingTimeInterval(-8 * 86_400),
            opensAt: now.addingTimeInterval(-86_400),
            status: .wrong,
            resolvedAt: now.addingTimeInterval(-3_600),
            resolutionLine: "No returning door appeared.",
            basisSignalID: "signal-doors",
            basisLine: "Two earlier doors had returned."
        )]
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-60 * 86_400),
            opinion: earlierOpinion
        )

        let evolved = BookInteriorEngine.reconciled(starting, inputs: inputs, now: now, calendar: calendar)
        let answer = BookInteriorAnswerGrounder.answer(to: "What have you changed your mind about?", interior: evolved)

        XCTAssertEqual(evolved.opinion?.strength, .reconsidering)
        XCTAssertTrue(evolved.opinionHistory.contains { $0.id == earlierOpinion.id })
        XCTAssertTrue(answer?.contains("No returning door appeared") == true)
        XCTAssertNil(evolved.opinion?.firstPresentedAt)
    }

    func testPageVolumeAndAppActivityDoNotMasqueradeAsTransformation() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...100).map { keptPage($0) })]
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-400 * 86_400)
        )

        let evolved = BookInteriorEngine.reconciled(starting, inputs: inputs, now: now, calendar: calendar)
        let answer = BookInteriorAnswerGrounder.answer(to: "What is your long-term goal?", interior: evolved)

        XCTAssertEqual(evolved.longGame?.phase, .wakeTheSenses)
        XCTAssertTrue(evolved.longGame?.evidence.isEmpty == true)
        XCTAssertTrue(evolved.longGame?.milestones.isEmpty == false)
        XCTAssertTrue(answer?.contains("Holy shit, what a trip") == true)
        XCTAssertTrue(answer?.contains("will not be cunning about your consent") == true)
    }

    func testUnpromptedPlainPagesEstrangeTheFamiliarAcrossLivedDays() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "2026-07-19",
            date: now,
            pages: [spontaneousPage(1, daysAgo: 4), spontaneousPage(2, daysAgo: 0)]
        )]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-20 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.longGame?.phase, .estrangeTheFamiliar)
        XCTAssertEqual(evolved.longGame?.evidence.filter { !$0.wasPromptedByBook }.count, 2)
        XCTAssertEqual(evolved.longGame?.hypotheses.first?.capacity, .worldOtherness)
    }

    func testAliennessEncounterAndReaderAuthorshipAdvanceTheLongGame() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "2026-07-19",
            date: now,
            pages: [
                spontaneousPage(1, daysAgo: 12),
                spontaneousPage(2, daysAgo: 2, tags: ["world-otherness"]),
                spontaneousPage(3, daysAgo: 0, tags: ["reader-invented"])
            ]
        )]
        inputs.readerLexicon = ReaderLexicon(entries: [LexiconEntry(
            word: "dayglint",
            originalSense: "not in the inherited lexicon",
            newSense: "the second life of an ordinary thing when attention returns",
            ruling: .adopted,
            category: .theme,
            origin: .rebellion,
            ledAt: now.addingTimeInterval(-86_400),
            sourcePageID: "spontaneous-3"
        )])

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-40 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.longGame?.phase, .authorTheMagic)
        XCTAssertTrue(evolved.longGame?.evidence.contains { $0.capacity == .worldOtherness } == true)
        XCTAssertTrue(evolved.longGame?.evidence.contains { $0.kind == .readerDefinition } == true)
    }

    func testInheritanceRequiresConnectionReturnAndLivedTime() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "2026-07-19",
            date: now,
            pages: [
                spontaneousPage(1, daysAgo: 55),
                spontaneousPage(2, daysAgo: 45, tags: ["world-otherness"]),
                spontaneousPage(3, daysAgo: 35, tags: ["reader-invented"]),
                spontaneousPage(4, daysAgo: 20, tags: ["shared-wonder"]),
                spontaneousPage(5, daysAgo: 0, tags: ["reader-returned"])
            ]
        )]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-100 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.longGame?.phase, .buildTheInheritance)
    }

    func testFinalPhaseRequiresTheReadersExplicitDeclaration() {
        let foundational = (0..<8).map { index in
            spontaneousPage(
                index,
                daysAgo: 420 - (index * 60),
                tags: [
                    index == 1 ? "world-otherness" : "plain",
                    index == 2 ? "reader-invented" : "plain",
                    index == 3 ? "shared-wonder" : "plain",
                    index == 4 ? "reader-returned" : "plain",
                    index == 5 ? "personal-language" : "plain"
                ]
            )
        }
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: foundational)]
        let starting = BookInteriorState(awakenedAt: now.addingTimeInterval(-500 * 86_400))

        let beforeDeclaration = BookInteriorEngine.reconciled(
            starting,
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(beforeDeclaration.longGame?.phase, .buildTheInheritance)

        inputs.days[0].pages.append(spontaneousPage(
            99,
            daysAgo: 0,
            tags: ["reader-declared-aliveness", "holy-shit-what-a-trip"]
        ))
        let afterDeclaration = BookInteriorEngine.reconciled(
            beforeDeclaration,
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(afterDeclaration.longGame?.phase, .holyShitWhatATrip)
        XCTAssertTrue(afterDeclaration.longGame?.evidence.contains { $0.kind == .readerDeclaration } == true)
    }

    func testLegacyActivityBasedPhaseIsCorrectedRatherThanFlattered() throws {
        let legacy = BookLongGame(
            phase: .buildTheInheritance,
            strategy: "Count activity.",
            startedAt: now.addingTimeInterval(-200 * 86_400),
            lastAdvancedAt: now.addingTimeInterval(-10 * 86_400),
            phasePresentedAt: now.addingTimeInterval(-9 * 86_400),
            milestones: []
        )
        let encoded = try JSONEncoder().encode(legacy)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["evidenceModelVersion", "evidence", "hypotheses"] { object.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(
            BookLongGame.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...100).map { keptPage($0) })]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(
                awakenedAt: now.addingTimeInterval(-200 * 86_400),
                longGame: decoded
            ),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.longGame?.phase, .wakeTheSenses)
        XCTAssertTrue(evolved.longGame?.milestones.last?.line.contains("counting use as transformation") == true)
        XCTAssertNil(evolved.longGame?.phasePresentedAt)
    }

    func testLongGameHypothesisSelectsAnAliennessFavor() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "2026-07-19",
            date: now,
            pages: (1...3).map { spontaneousPage($0, daysAgo: 0) }
        )]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-10 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.longGame?.hypotheses.first?.capacity, .worldOtherness)
        XCTAssertEqual(evolved.activeFavor?.family, .encounter)
        XCTAssertEqual(evolved.activeFavor?.cultivates, .worldOtherness)
        XCTAssertTrue([
            "Evidence the World Wasn't Waiting",
            "Refuse the Symbol",
            "A Place Before and After You",
            "The Unanswered Object",
            "Another Creature's Errand",
            "The World Without Witness"
        ].contains(evolved.activeFavor?.title ?? ""))
    }

    func testLongGameMovesFromAliennessToCulturalDehabituation() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "2026-07-19",
            date: now,
            pages: [
                spontaneousPage(1, daysAgo: 4),
                spontaneousPage(2, daysAgo: 2),
                spontaneousPage(3, daysAgo: 0, tags: ["world-otherness"])
            ]
        )]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-20 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.longGame?.hypotheses.first?.capacity, .scriptFreedom)
        XCTAssertEqual(evolved.activeFavor?.family, .dehabituation)
        XCTAssertEqual(evolved.activeFavor?.cultivates, .scriptFreedom)
    }

    func testLongGameHypothesisChangesCurationWeight() {
        let hypothesis = BookLongGameHypothesis(
            id: "long-game-hypothesis-worldOtherness",
            capacity: .worldOtherness,
            statement: "The archive has not shown the autonomous world.",
            nextHonestTest: "Preserve one unknown.",
            evidenceIDs: [],
            formedAt: now,
            lastRevisedAt: now
        )
        let game = BookLongGame(
            phase: .estrangeTheFamiliar,
            strategy: "Let the world exceed the reader's scene.",
            startedAt: now.addingTimeInterval(-10 * 86_400),
            lastAdvancedAt: now,
            phasePresentedAt: now,
            milestones: [],
            hypotheses: [hypothesis]
        )
        let interior = BookInteriorState(awakenedAt: now, longGame: game)
        let surface = SurfacePage(
            id: "autonomous-world",
            type: .wonderCompass,
            sourceID: "wonder",
            intent: .capture,
            renderStyle: .promptCard,
            score: 40,
            reason: "A nearby place keeps an unknown history.",
            prompt: "Meet the place before you interpret it",
            detail: "Keep one literal fact and one unknown.",
            payload: BookPagePayload(headline: "The Place Continues", body: "Field notes from a world with its own business.")
        )

        let influenced = BookInteriorVoice.influencing(surface, interior: interior)

        XCTAssertGreaterThan(influenced.score, surface.score)
        XCTAssertEqual(influenced.payload.metadata["bookLongGameHypothesisID"], hypothesis.id)
        XCTAssertEqual(
            influenced.payload.metadata["bookCurationDirectiveID"],
            BookCurationDirective.make(from: hypothesis).id
        )
        XCTAssertEqual(influenced.payload.metadata["bookLongGameCapacity"], BookLongGameCapacity.worldOtherness.rawValue)
        XCTAssertTrue(influenced.payload.metadata["tags"]?.contains("long-game:worldOtherness") == true)
    }

    func testLongGameDirectiveClaimsOneOrdinaryDeskSlot() {
        let hypothesis = BookLongGameHypothesis(
            id: "long-game-hypothesis-worldOtherness",
            capacity: .worldOtherness,
            statement: "The archive has not shown the autonomous world.",
            nextHonestTest: "Preserve one unknown.",
            evidenceIDs: [],
            formedAt: now,
            lastRevisedAt: now
        )
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-10 * 86_400),
            longGame: BookLongGame(
                phase: .estrangeTheFamiliar,
                strategy: "Let the world exceed the reader's scene.",
                startedAt: now.addingTimeInterval(-10 * 86_400),
                lastAdvancedAt: now,
                phasePresentedAt: now,
                milestones: [],
                hypotheses: [hypothesis]
            )
        )
        let day = BookDay(id: "2026-07-19", date: now, pages: [])

        let surfaced = BookCurator.surfacedPages(
            for: day,
            context: .make(for: day),
            inputs: inputs,
            now: now,
            limit: 3
        )

        XCTAssertTrue(surfaced.contains {
            $0.payload.metadata["bookCurationDirectiveID"]
                == BookCurationDirective.make(from: hypothesis).id
        })
    }

    func testRejectedLongGameTacticRestsBeforeTryingAgain() {
        let hypothesis = BookLongGameHypothesis(
            id: "long-game-hypothesis-worldOtherness",
            capacity: .worldOtherness,
            statement: "The archive has not shown the autonomous world.",
            nextHonestTest: "Preserve one unknown.",
            evidenceIDs: [],
            formedAt: now,
            lastRevisedAt: now
        )
        var learning = ReaderLearningModel()
        learning.record(ReaderLearningEvent(
            dayID: "2026-07-19",
            occurredAt: now.addingTimeInterval(-86_400),
            action: .dismissed,
            surfaceID: "world-page",
            sourceID: "wonder-compass",
            type: .wonderCompass,
            varietyKey: "world-page",
            hour: 14,
            tags: ["long-game:worldOtherness"]
        ))

        XCTAssertFalse(BookCurator.longGameDirectiveMayPress(hypothesis, learning: learning, now: now))
        XCTAssertTrue(BookCurator.longGameDirectiveMayPress(
            hypothesis,
            learning: learning,
            now: now.addingTimeInterval(4 * 86_400)
        ))
    }

    func testBookAnswersWhetherChangeIsHappeningWithoutClaimingAnInnerDiagnosis() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: [spontaneousPage(1, daysAgo: 0)])]
        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-10 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        let answer = BookInteriorAnswerGrounder.answer(
            to: "Is this actually changing me?",
            interior: evolved
        )

        XCTAssertTrue(answer?.contains("evidence of practices, not proof") == true)
        XCTAssertTrue(answer?.contains("without my asking") == true)
        XCTAssertTrue(answer?.contains("not a diagnosis") == true)
    }

    func testFoundGiftPlanIsOccasionalAndUsesOnlyMissionLanguage() throws {
        let privatePhrase = "BJ's private sentence about the blue medicine"
        let hypothesis = BookLongGameHypothesis(
            id: "long-game-hypothesis-worldOtherness",
            capacity: .worldOtherness,
            statement: privatePhrase,
            nextHonestTest: "Meet an autonomous world.",
            evidenceIDs: [],
            formedAt: now,
            lastRevisedAt: now
        )
        let game = BookLongGame(
            phase: .estrangeTheFamiliar,
            strategy: "Court the living world.",
            startedAt: now.addingTimeInterval(-20 * 86_400),
            lastAdvancedAt: now,
            phasePresentedAt: now,
            milestones: [],
            hypotheses: [hypothesis]
        )
        let interior = BookInteriorState(awakenedAt: now.addingTimeInterval(-20 * 86_400), longGame: game)
        let day = BookDay(id: "2026-07-19", date: now, pages: [])

        let plan = try XCTUnwrap(BookFoundGiftEngine.plan(
            for: day,
            interior: interior,
            surfaceHistory: [:],
            keptPageCount: 3,
            now: now
        ))

        XCTAssertEqual(plan.capacity, .worldOtherness)
        XCTAssertFalse(plan.searchQueries.joined(separator: " ").contains(privatePhrase))
        XCTAssertTrue(plan.searchQueries.allSatisfy { !$0.isEmpty })
        XCTAssertNil(BookFoundGiftEngine.plan(
            for: day,
            interior: interior,
            surfaceHistory: [
                "source:\(BookFoundGiftEngine.sourceID)": SurfaceHistoryRecord(
                    lastShownAt: now.addingTimeInterval(-86_400),
                    recentShowCount: 1
                )
            ],
            keptPageCount: 3,
            now: now
        ))
    }

    func testFoundGiftSurfaceCarriesARealPublicReceipt() throws {
        let plan = BookFoundGiftPlan(
            id: "gift-plan",
            capacity: .scriptFreedom,
            directiveID: "hypothesis-script",
            searchQueries: ["history of ordinary conventions"],
            casualBridge: "make one inherited rule look less inevitable"
        )
        let thing = BookFoundWebThing(
            title: "The Strange History of the Weekend",
            excerpt: "The two-day weekend was negotiated into ordinary life; it was not waiting in nature as an inevitable unit of time.",
            sourceName: "Example History Review",
            sourceURL: "https://example.org/weekend-history",
            searchQuery: "history of ordinary conventions"
        )

        let surface = try XCTUnwrap(BookFoundGiftEngine.surface(for: plan, thing: thing, now: now))

        XCTAssertEqual(surface.prompt, "Here, I found this for you.")
        XCTAssertEqual(surface.payload.metadata["url"], thing.sourceURL)
        XCTAssertEqual(surface.payload.metadata["provenance"], "live-public-web-search")
        XCTAssertEqual(surface.payload.metadata["externalSearchPrivacy"], "broad-mission-query-only-no-private-page-text")
        XCTAssertEqual(surface.origin, .imported)
        XCTAssertEqual(surface.privacy, .publicReference)
        XCTAssertTrue(surface.payload.body.contains("No lesson attached"))
    }

    func testFoundGiftCanBeCuratedForAConfirmedRelationshipWithoutSearchingThePersonsName() throws {
        let hypothesis = BookLongGameHypothesis(
            id: "living-connection",
            capacity: .livingConnection,
            statement: "Shared attention may make the world less flat.",
            nextHonestTest: "Offer one sourced door for two people.",
            evidenceIDs: [],
            formedAt: now,
            lastRevisedAt: now
        )
        let game = BookLongGame(
            phase: .courtTheWorld,
            strategy: "Put shared attention into motion.",
            startedAt: now,
            lastAdvancedAt: now,
            phasePresentedAt: now,
            milestones: [],
            hypotheses: [hypothesis]
        )
        let interior = BookInteriorState(awakenedAt: now.addingTimeInterval(-20 * 86_400), longGame: game)
        let profile = PersonRelationshipProfile(
            roles: ["coworker"],
            settings: [.work],
            channels: [.together],
            sharedInterests: ["artificial intelligence"],
            ordinaryRituals: [],
            boundaries: [],
            season: "",
            invitationPermission: .playful
        )
        let thread = PersonThread(
            id: "person:sam",
            name: "Sam",
            introducedDay: "2026-07-01",
            readerWords: "A coworker I talk with about AI.",
            firstMentionDay: "2026-06-01",
            lastMentionDay: "2026-07-18",
            mentionPageCount: 5,
            relationship: profile
        )
        let plan = try XCTUnwrap(BookFoundGiftEngine.plan(
            for: BookDay(id: "2026-07-19", date: now, pages: []),
            interior: interior,
            surfaceHistory: [:],
            keptPageCount: 8,
            people: PeopleLedger(threads: [thread]),
            now: now
        ))

        XCTAssertEqual(plan.capacity, .livingConnection)
        XCTAssertEqual(plan.relationshipTarget?.personName, "Sam")
        XCTAssertTrue(plan.searchQueries.allSatisfy { !$0.localizedCaseInsensitiveContains("Sam") })
        XCTAssertTrue(plan.searchQueries.allSatisfy { $0.localizedCaseInsensitiveContains("artificial intelligence") })

        let thing = BookFoundWebThing(
            title: "A peculiar AI experiment",
            excerpt: "A public experiment invited two people to compare what the same model noticed in different questions.",
            sourceName: "Example Lab",
            sourceURL: "https://example.org/two-minds",
            searchQuery: plan.searchQueries[0]
        )
        let surface = try XCTUnwrap(BookFoundGiftEngine.surface(for: plan, thing: thing, now: now))
        XCTAssertEqual(surface.prompt, "Here, I found this for you and Sam.")
        XCTAssertEqual(surface.payload.metadata["personID"], "person:sam")
        XCTAssertEqual(surface.payload.metadata["externalSearchPrivacy"], "confirmed-shared-interest-only-no-name-no-private-page-text")
        XCTAssertTrue(surface.payload.metadata["tags"]?.contains("person:sam") == true)
        XCTAssertTrue(surface.payload.body.contains("I did not send their name"))
    }

    func testRelationalFoundGiftKeepsTypedSourceAndAftermathReceipts() throws {
        let target = BookFoundGiftRelationshipTarget(
            personID: "person:sam",
            personName: "Sam",
            personSlug: "sam",
            sharedInterest: "urban moths",
            relationshipMode: "sharedInterest",
            outcomePrompt: "keep what happened"
        )
        let plan = BookFoundGiftPlan(
            id: "gift-plan-sam",
            capacity: .livingConnection,
            directiveID: "living-connection",
            searchQueries: ["urban moths strange project"],
            casualBridge: "open a side door",
            relationshipTarget: target
        )
        let thing = BookFoundWebThing(
            title: "The moth streetlight census",
            excerpt: "Neighbors compared which moths visited different streetlights.",
            sourceName: "Field Notes",
            sourceURL: "https://example.org/moths",
            searchQuery: plan.searchQueries[0]
        )
        let surface = try XCTUnwrap(BookFoundGiftEngine.surface(for: plan, thing: thing, now: now))
        let input = surface.payload.body + "\n\nMargin note: Sam laughed at the atlas moth and sent me a photograph of one outside work."
        let reference = try XCTUnwrap(BookPageExternalReference.from(surface: surface))
        let receipt = try XCTUnwrap(RelationshipPageReceipt.from(surface: surface, readerInput: input))
        let page = BookPage(
            type: .bookNotices,
            createdAt: now,
            promptText: surface.prompt,
            userInput: input,
            sourceID: surface.sourceID,
            origin: surface.origin,
            privacy: surface.privacy,
            externalReference: reference,
            relationshipReceipt: receipt
        )
        let decoded = try JSONDecoder().decode(BookPage.self, from: JSONEncoder().encode(page))

        XCTAssertEqual(decoded.externalReference?.url, thing.sourceURL)
        XCTAssertEqual(decoded.relationshipReceipt?.kind, .foundGift)
        XCTAssertEqual(decoded.relationshipReceipt?.readerAftermath, "Sam laughed at the atlas moth and sent me a photograph of one outside work.")
        XCTAssertEqual(decoded.relationshipReceipt?.evidenceAuthority, "reader-authored-aftermath")
    }

    func testFavorRepertoireAvoidsTheMostRecentAsk() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...8).map { keptPage($0) })]
        var state = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-30 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        let firstTitle = state.activeFavor?.title
        state = BookInteriorEngine.recordingFavorReleased(state, favorID: state.activeFavor?.id ?? "", now: now)
        state = BookInteriorEngine.reconciled(
            state,
            inputs: inputs,
            now: now.addingTimeInterval(5 * 86_400),
            calendar: calendar
        )

        XCTAssertNotNil(firstTitle)
        XCTAssertNotNil(state.activeFavor)
        XCTAssertNotEqual(state.activeFavor?.title, firstTitle)
        XCTAssertFalse(state.activeFavor?.reflectionQuestion.isEmpty ?? true)
        XCTAssertFalse(state.activeFavor?.completionReply.isEmpty ?? true)
    }

    func testFavorAcceptanceCreatesPromiseAndCompletionChangesTheBook() {
        let secret = BookSecret(
            id: "secret-test",
            tease: "The ribbon knows something.",
            revelation: "The ribbon exaggerates.",
            sealedAt: now,
            status: .sealed,
            revealedAt: nil
        )
        var state = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-10 * 86_400),
            secret: secret,
            activeFavor: favor()
        )

        state = BookInteriorEngine.recordingFavorAccepted(state, favorID: "favor-test-notice", now: now)
        XCTAssertEqual(state.activeFavor?.status, .accepted)
        XCTAssertEqual(state.promise?.status, .keeping)

        state = BookInteriorEngine.recordingFavorCompleted(
            state,
            favorID: "favor-test-notice",
            evidencePageID: "proof-page",
            now: now.addingTimeInterval(300)
        )

        XCTAssertEqual(state.activeFavor?.status, .completed)
        XCTAssertEqual(state.promise?.status, .fulfilled)
        XCTAssertEqual(state.promise?.evidencePageIDs, ["proof-page"])
        XCTAssertEqual(state.secret?.status, .ready)
        XCTAssertNotNil(state.recentSurprise)
        XCTAssertTrue(state.sharedJoke?.contains("ribbon") == true)
    }

    func testFavorOfferDoesNotMasqueradeAsCompletion() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-18", date: now.addingTimeInterval(-86_400), pages: (1...4).map { keptPage($0) })]
        inputs.bookInterior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-5 * 86_400),
            activeFavor: favor()
        )
        let today = BookDay(id: "2026-07-19", date: now, pages: [])

        let surfaces = ElectivePageSourceAdapter().candidates(
            for: today,
            context: .make(for: today),
            inputs: inputs,
            now: now
        )
        let offer = surfaces.first { $0.payload.metadata["bookFavorID"] == "favor-test-notice" }

        XCTAssertNotNil(offer)
        XCTAssertEqual(offer?.payload.metadata["electivePrepared"], "true")
        XCTAssertEqual(offer?.payload.metadata["bookFavorCultivates"], BookLongGameCapacity.spontaneousAttention.rawValue)
        XCTAssertTrue(offer?.payload.metadata["tags"]?.contains("book-favor-offer:favor-test-notice") == true)
        XCTAssertFalse(offer?.payload.metadata["tags"]?.contains("book-favor-completed") == true)

        let whisper = PromptWhisperRegistry.promptWhisper(from: favor())
        XCTAssertTrue(whisper.tags.contains("book-favor-completed:favor-test-notice"))
    }

    func testFascinationChangesCurationWeightInsteadOfOnlyCopy() {
        let fascination = BookFascination(
            id: "fascination-threshold",
            facet: .explore,
            subject: "thresholds and returning doors",
            line: "Small crossings are answering one another.",
            evidencePageIDs: ["kept-1"],
            bornAt: now,
            lastDeepenedAt: now
        )
        let interior = BookInteriorState(awakenedAt: now, fascination: fascination)
        let surface = SurfacePage(
            id: "threshold-page",
            type: .wonderCompass,
            sourceID: "wonder",
            intent: .capture,
            renderStyle: .promptCard,
            score: 50,
            reason: "A nearby door is unfamiliar again.",
            prompt: "Explore a threshold",
            detail: "Take another doorway.",
            payload: BookPagePayload(
                headline: "The Other Door",
                body: "Find the threshold the usual route ignores.",
                metadata: ["tags": "threshold,explore"]
            )
        )

        let influenced = BookInteriorVoice.influencing(surface, interior: interior)

        XCTAssertGreaterThan(influenced.score, surface.score)
        XCTAssertEqual(influenced.payload.metadata["bookFascinationID"], fascination.id)
        XCTAssertNotNil(influenced.payload.metadata["bookInterestBoost"])
    }

    func testDirectQuestionsCannotInventAConvenientInnerLife() {
        let favorite = BookFavorite(
            id: "favorite-kept-1",
            pageID: "kept-1",
            pageType: .souvenir,
            excerpt: "The blue cup held afternoon light.",
            reason: "It saved what a summary would miss.",
            chosenAt: now,
            firstPresentedAt: nil
        )
        let secret = BookSecret(
            id: "secret-test",
            tease: "The Index and I disagree.",
            revelation: "I have favorites.",
            sealedAt: now,
            status: .sealed,
            revealedAt: nil
        )
        let interior = BookInteriorState(awakenedAt: now, favorite: favorite, secret: secret)

        XCTAssertTrue(BookInteriorAnswerGrounder.answer(
            to: "Which Page is your favorite?",
            interior: interior
        )?.contains("blue cup") == true)
        XCTAssertTrue(BookInteriorAnswerGrounder.answer(
            to: "Tell me your secret",
            interior: interior
        )?.contains("not ready") == true)
    }

    func testSecretAndFavoriteSurfacesHaveReceiptsAndAreConsumedByOpening() {
        let favorite = BookFavorite(
            id: "favorite-kept-1",
            pageID: "kept-1",
            pageType: .souvenir,
            excerpt: "The blue cup held afternoon light.",
            reason: "It saved what a summary would miss.",
            chosenAt: now,
            firstPresentedAt: nil
        )
        let secret = BookSecret(
            id: "secret-test",
            tease: "The Index and I disagree.",
            revelation: "I have favorites.",
            sealedAt: now,
            status: .ready,
            revealedAt: nil
        )
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: now, favorite: favorite, secret: secret)

        let surfaces = BookInteriorSurfaces.candidates(
            for: BookDay(id: "2026-07-19", date: now, pages: []),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(surfaces.count, 2)
        XCTAssertTrue(surfaces.contains { $0.payload.metadata["evidencePageIDs"] == "kept-1" })
        XCTAssertTrue(surfaces.contains { $0.payload.metadata["bookSecretID"] == "secret-test" })

        let opened = BookInteriorEngine.recordingSurfaceOpened(
            inputs.bookInterior,
            secretID: "secret-test",
            favoriteID: "favorite-kept-1",
            now: now
        )
        XCTAssertEqual(opened.secret?.status, .revealed)
        XCTAssertEqual(opened.favorite?.firstPresentedAt, now)
    }

    func testQuirkOpinionAndLongGamePagesAreOneShotReceipts() {
        let quirk = BookQuirk(
            id: "book-quirk-exactWords",
            kind: .exactWords,
            title: "Exact-Word Hoarding",
            confession: "I collect exact words.",
            manifestation: "Vague words make the margins itch.",
            maturity: .glimpsed,
            bornAt: now.addingTimeInterval(-10 * 86_400),
            revealedAt: now,
            firstPresentedAt: nil,
            exerciseCount: 0
        )
        let opinion = BookOpinion(
            id: "opinion-light",
            subject: "afternoon light",
            statement: "I think afternoon light keeps refusing to become background.",
            strength: .leaning,
            evidencePageIDs: ["kept-1", "kept-2"],
            formedAt: now,
            lastRevisedAt: now,
            revisions: [],
            firstPresentedAt: nil
        )
        let game = BookLongGame(
            phase: .estrangeTheFamiliar,
            strategy: "Change the angle until the familiar becomes a world again.",
            startedAt: now.addingTimeInterval(-30 * 86_400),
            lastAdvancedAt: now,
            phasePresentedAt: nil,
            milestones: [BookLongGameMilestone(
                id: "milestone-estrange",
                title: "Estrange the Familiar",
                line: "The familiar moved.",
                evidencePageIDs: ["kept-1"],
                reachedAt: now
            )]
        )
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-30 * 86_400),
            quirks: [quirk],
            opinion: opinion,
            longGame: game
        )

        let surfaces = BookInteriorSurfaces.candidates(
            for: BookDay(id: "2026-07-19", date: now, pages: []),
            inputs: inputs,
            now: now
        )
        XCTAssertNotNil(surfaces.first { $0.payload.metadata["bookQuirkID"] == quirk.id })
        XCTAssertNotNil(surfaces.first { $0.payload.metadata["bookOpinionID"] == opinion.id })
        XCTAssertNotNil(surfaces.first { $0.payload.metadata["bookLongGamePhase"] == game.phase.rawValue })

        let opened = BookInteriorEngine.recordingSurfaceOpened(
            inputs.bookInterior,
            quirkID: quirk.id,
            opinionID: opinion.id,
            longGamePhase: game.phase.rawValue,
            now: now
        )
        XCTAssertEqual(opened.quirks.first?.firstPresentedAt, now)
        XCTAssertEqual(opened.opinion?.firstPresentedAt, now)
        XCTAssertEqual(opened.longGame?.phasePresentedAt, now)
    }

    func testDirectorUsesTheReadersPermissionAsAHardPressureCeiling() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) })]
        inputs.selfFacts = [SelfFact(
            id: "comfort-gentle",
            questionID: "onboarding-comfort-boundary",
            question: "How sharp should the Book get?",
            answer: "gentle",
            bookTranslation: "Invite me.",
            sensitivity: .comfort,
            usePermission: .privateContext,
            tags: ["onboarding"],
            createdAt: now,
            updatedAt: now
        )]
        var game = campaignGame()

        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)

        let campaign = try XCTUnwrap(game.currentCampaign)
        XCTAssertEqual(campaign.permission, .gentle)
        XCTAssertLessThanOrEqual(campaign.pressure.rank, BookCampaignPressure.invite.rank)
        XCTAssertNil(campaign.readerNamedEdge, "One ordinary Page must not be promoted into a dream.")
    }

    func testDirectorEarnsLivedTimeBeforeBeginningAChallengeCampaign() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) })]
        var game = campaignGame()
        game.startedAt = now.addingTimeInterval(-2 * 86_400)

        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)

        XCTAssertNil(game.currentCampaign)
    }

    func testDirectorOnlyPursuesAReaderNamedDreamAfterItRecurs() throws {
        var first = keptPage(1)
        first.userInput = "I want to make a tiny neighborhood bakery someday."
        var second = keptPage(2)
        second.userInput = "My dream is still that little neighborhood bakery."
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: [first, second, keptPage(3)])]
        inputs.selfFacts = [SelfFact(
            id: "comfort-strange",
            questionID: "onboarding-comfort-boundary",
            question: "How sharp should the Book get?",
            answer: "strange",
            bookTranslation: "Call me on my nonsense.",
            sensitivity: .comfort,
            usePermission: .privateContext,
            tags: ["onboarding"],
            createdAt: now,
            updatedAt: now
        )]
        var game = campaignGame()

        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)

        let campaign = try XCTUnwrap(game.currentCampaign)
        XCTAssertEqual(campaign.tactic, .testReaderNamedDesire)
        XCTAssertEqual(campaign.capacity, .selfAuthoredAction)
        XCTAssertEqual(campaign.pressure, .provoke)
        XCTAssertTrue(campaign.readerNamedEdge?.lowercased().contains("bakery") == true)
        XCTAssertEqual(Set(campaign.edgeEvidencePageIDs), Set([first.id, second.id]))
    }

    func testCampaignRefusalProducesRestInsteadOfEscalation() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) })]
        var game = campaignGame()
        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)
        let original = try XCTUnwrap(game.currentCampaign)
        inputs.readerLearning.record(ReaderLearningEvent(
            dayID: "2026-07-19",
            occurredAt: now.addingTimeInterval(60),
            action: .dismissed,
            surfaceID: "book-campaign-\(original.id)-seed",
            sourceID: "book-reenchantment-director",
            type: .bookNotices,
            varietyKey: original.id,
            hour: 15,
            tags: [original.receiptTag]
        ))

        BookReenchantmentDirector.reconcile(
            &game,
            inputs: inputs,
            now: now.addingTimeInterval(120)
        )

        let resting = try XCTUnwrap(game.currentCampaign)
        XCTAssertEqual(resting.status, .resting)
        XCTAssertEqual(resting.beat, .release)
        XCTAssertEqual(resting.rejectionCount, 1)
        XCTAssertFalse(resting.mayClaimDeskSlot)
        XCTAssertNil(BookReenchantmentDirector.surface(
            for: resting,
            day: inputs.days[0],
            inputs: inputs
        ))
    }

    func testUnseenCampaignDoesNotAdvanceOnElapsedTimeAlone() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) })]
        var game = campaignGame()
        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)

        BookReenchantmentDirector.reconcile(
            &game,
            inputs: inputs,
            now: now.addingTimeInterval(20 * 86_400)
        )

        XCTAssertEqual(game.currentCampaign?.beat, .seed)
    }

    func testSeenCampaignAdvancesThenWithdrawsWithoutTreatingSilenceAsDefiance() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) })]
        var game = campaignGame()
        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)
        let campaign = try XCTUnwrap(game.currentCampaign)
        inputs.readerLearning.record(ReaderLearningEvent(
            dayID: "2026-07-19",
            occurredAt: now,
            action: .surfaced,
            surfaceID: "book-campaign-\(campaign.id)-seed",
            sourceID: "book-reenchantment-director",
            type: .bookNotices,
            varietyKey: campaign.id,
            hour: 15,
            tags: [campaign.receiptTag]
        ))
        let interruptAt = now.addingTimeInterval(2 * 86_400 + 1)
        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: interruptAt)
        XCTAssertEqual(game.currentCampaign?.beat, .interrupt)

        inputs.readerLearning.record(ReaderLearningEvent(
            dayID: BookDay.id(for: interruptAt),
            occurredAt: interruptAt,
            action: .surfaced,
            surfaceID: "book-campaign-\(campaign.id)-interrupt",
            sourceID: "book-reenchantment-director",
            type: .plainPage,
            varietyKey: campaign.id,
            hour: 15,
            tags: [campaign.receiptTag]
        ))
        BookReenchantmentDirector.reconcile(
            &game,
            inputs: inputs,
            now: interruptAt.addingTimeInterval(3 * 86_400 + 1)
        )

        XCTAssertEqual(game.currentCampaign?.beat, .release)
        XCTAssertEqual(game.currentCampaign?.presentation, .silence)
        XCTAssertEqual(game.currentCampaign?.rejectionCount, 0)
    }

    func testHardDaySuppressesCampaignPressure() throws {
        var inputs = BookSourceInputs.empty
        let hardPage = BookPage(
            id: "hard-day",
            type: .mood,
            createdAt: now,
            promptText: "How are you?",
            userInput: "overwhelmed and panicking",
            tags: ["distress", "overwhelmed"]
        )
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [hardPage, keptPage(1), keptPage(2)])
        inputs.days = [day]
        var game = campaignGame()
        game.currentCampaign = nil
        BookReenchantmentDirector.reconcile(&game, inputs: inputs, now: now)
        XCTAssertNil(game.currentCampaign)

        game.currentCampaign = try campaignForSurface(inputs: inputs)
        inputs.bookInterior = BookInteriorState(awakenedAt: now, longGame: game)
        let surfaces = BookInteriorSurfaces.candidates(for: day, inputs: inputs, now: now)
        XCTAssertFalse(surfaces.contains { $0.payload.metadata["bookCampaignID"] != nil })
    }

    func testCampaignReceiptCountsAsPromptedPracticeAndCreatesAReturn() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) })]
        let starting = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-10 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        let campaign = try XCTUnwrap(starting.longGame?.currentCampaign)
        let outcomeTag = try XCTUnwrap(
            BookReenchantmentDirector.surface(for: campaign, day: inputs.days[0], inputs: inputs)?
                .payload.metadata["bookCampaignOutcomeTag"]
        )
        let receipt = BookPage(
            id: "campaign-receipt",
            type: .plainPage,
            createdAt: now.addingTimeInterval(600),
            promptText: "A small experiment",
            userInput: "I changed the route and found a rust-red seed pod.",
            tags: [campaign.receiptTag, "book-campaign-outcome:\(outcomeTag)"],
            sourceID: "book-reenchantment-director",
            origin: .generated
        )
        inputs.days = [BookDay(id: "2026-07-19", date: now, pages: (1...3).map { keptPage($0) } + [receipt])]

        let evolved = BookInteriorEngine.reconciled(
            starting,
            inputs: inputs,
            now: now.addingTimeInterval(900),
            calendar: calendar
        )

        let evidence = try XCTUnwrap(evolved.longGame?.evidence.first {
            $0.evidencePageIDs.contains(receipt.id)
        })
        XCTAssertTrue(evidence.wasPromptedByBook)
        XCTAssertEqual(evidence.kind, .completedExperiment)
        XCTAssertEqual(evolved.longGame?.currentCampaign?.beat, .return)
        XCTAssertEqual(evolved.longGame?.currentCampaign?.status, .answered)
        XCTAssertTrue(evolved.longGame?.currentCampaign?.outcomeEvidencePageIDs.contains(receipt.id) == true)
    }

    private func campaignGame() -> BookLongGame {
        BookLongGame(
            phase: .wakeTheSenses,
            strategy: "Interrupt automatic seeing with one honest experiment.",
            startedAt: now.addingTimeInterval(-10 * 86_400),
            lastAdvancedAt: now,
            phasePresentedAt: now,
            milestones: [],
            hypotheses: [BookLongGameHypothesis(
                id: "campaign-hypothesis",
                capacity: .worldOtherness,
                statement: "The autonomous world has not been given enough room.",
                nextHonestTest: "Keep one purpose that is not about the reader.",
                evidenceIDs: [],
                formedAt: now,
                lastRevisedAt: now
            )]
        )
    }

    private func campaignForSurface(inputs: BookSourceInputs) throws -> BookReenchantmentCampaign {
        var safeInputs = inputs
        safeInputs.days = [BookDay(id: "safe", date: now.addingTimeInterval(-86_400), pages: (1...3).map { keptPage($0) })]
        var game = campaignGame()
        BookReenchantmentDirector.reconcile(&game, inputs: safeInputs, now: now)
        return try XCTUnwrap(game.currentCampaign)
    }
}
