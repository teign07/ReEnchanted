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
        XCTAssertNil(state.opinion, "Archive volume alone must not manufacture a tasteful opinion.")
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
        for key in [
            "secretHistory", "quirks", "opinion", "opinionHistory", "longGame",
            "autobiography", "acquiredTastes", "privateTraditions",
            "pendingReminiscence", "reminiscenceHistory", "currentWant",
            "wantHistory", "currentTension", "tensionHistory",
            "currentInitiative", "initiativeHistory", "loyalties",
            "currentDesireConflict", "desireConflictHistory", "secretLegacies"
        ] {
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
        XCTAssertEqual(migrated.autobiography, [])
        XCTAssertEqual(migrated.acquiredTastes, [])
        XCTAssertEqual(migrated.privateTraditions, [])
        XCTAssertNil(migrated.pendingReminiscence)
        XCTAssertEqual(migrated.reminiscenceHistory, [])
        XCTAssertNil(migrated.currentWant)
        XCTAssertEqual(migrated.wantHistory, [])
        XCTAssertNil(migrated.currentTension)
        XCTAssertEqual(migrated.tensionHistory, [])
        XCTAssertNil(migrated.currentInitiative)
        XCTAssertEqual(migrated.initiativeHistory, [])
        XCTAssertEqual(migrated.loyalties, [])
        XCTAssertNil(migrated.currentDesireConflict)
        XCTAssertEqual(migrated.desireConflictHistory, [])
        XCTAssertEqual(migrated.secretLegacies, [])
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

    func testForgedOpinionRisksAThesisKeepsItsRivalAndRevisesOnlyWhenEvidenceChanges() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: BookDay.id(for: now),
            date: now,
            pages: (1...4).map { keptPage($0) }
        )]
        inputs.overnightConnectionDrafts = [forgedDraft(
            signature: "packet-one",
            thesis: "I think afternoon light is not decoration here; it keeps giving ordinary objects permission to become events.",
            evidencePageIDs: ["kept-1", "kept-2", "kept-3"],
            confidence: 88
        )]
        var state = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-40 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        let first = try XCTUnwrap(state.opinion)
        XCTAssertEqual(first.strength, .leaning)
        XCTAssertEqual(first.interpretation?.counterReading, "The light may recur simply because the room and camera angle recur.")
        XCTAssertTrue(first.interpretation?.falsifier.hasPrefix("If ") == true)
        XCTAssertTrue(first.interpretation?.whyItMatters.contains("ordinary room") == true)
        inputs.bookInterior = state
        let surface = try XCTUnwrap(BookInteriorSurfaces.candidates(
            for: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            inputs: inputs,
            now: now
        ).first(where: { $0.payload.metadata["bookOpinionID"] == first.id }))
        XCTAssertTrue(surface.payload.body.hasPrefix(first.statement))
        XCTAssertTrue(surface.payload.body.contains("Another Page is tugging at my sleeve"))
        XCTAssertTrue(surface.payload.body.contains("The eraser has one rule"))
        XCTAssertTrue(surface.payload.body.contains("What do you think?"))
        XCTAssertFalse(surface.payload.body.contains("You may disagree"))
        XCTAssertEqual(surface.payload.metadata["bookOpinionOrigin"], "interpretation-forge")
        let answer = try XCTUnwrap(BookInteriorAnswerGrounder.answer(
            to: "What is your opinion?",
            interior: state
        ))
        XCTAssertTrue(answer.contains("Here's why I care"))
        XCTAssertTrue(answer.contains("Another Page is tugging at my sleeve"))
        XCTAssertTrue(answer.contains("The eraser has one rule"))
        XCTAssertTrue(answer.contains("I've got 3 Pages under this"))

        inputs.overnightConnectionDrafts = [forgedDraft(
            signature: "packet-two",
            thesis: "I think afternoon light does more than decorate the room; it keeps turning overlooked objects into small appointments.",
            evidencePageIDs: ["kept-1", "kept-2", "kept-3", "kept-4"],
            confidence: 94
        )]
        state = BookInteriorEngine.reconciled(
            state,
            inputs: inputs,
            now: now.addingTimeInterval(86_400),
            calendar: calendar
        )

        XCTAssertEqual(state.opinion?.strength, .held)
        XCTAssertEqual(state.opinion?.revisions.count, 1)
        XCTAssertEqual(state.opinion?.interpretation?.evidenceSignature, "packet-two")
        XCTAssertTrue(state.opinion?.revisions.last?.reason.contains("materially changed") == true)
        XCTAssertNil(state.opinion?.firstPresentedAt)
    }

    func testRejectedOvernightReadingCannotQuietlyBecomeAnOpinion() {
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: BookDay.id(for: now),
            date: now,
            pages: (1...3).map { keptPage($0) }
        )]
        let draft = forgedDraft()
        inputs.overnightConnectionDrafts = [draft]
        inputs.bookObservations = [BookObservationRecord(
            id: draft.observationKey,
            kind: draft.kind,
            status: .notQuite,
            evidencePageIDs: draft.evidencePageIDs,
            firstPresentedAt: now.addingTimeInterval(-3_600),
            updatedAt: now
        )]

        let state = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-40 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(state.opinion)
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
        if plan.realm == .publicWeb {
            XCTAssertFalse(plan.searchQueries.isEmpty)
            XCTAssertTrue(plan.searchQueries.allSatisfy { !$0.isEmpty })
        } else {
            XCTAssertTrue(plan.searchQueries.isEmpty)
        }
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
        XCTAssertNil(BookFoundGiftEngine.plan(
            for: day,
            interior: interior,
            surfaceHistory: [
                "source:\(BookFoundGiftEngine.jSpaceSourceID)": SurfaceHistoryRecord(
                    lastShownAt: now.addingTimeInterval(-9 * 86_400),
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
        XCTAssertEqual(surface.payload.metadata["bookFoundGiftRealm"], BookFoundGiftRealm.publicWeb.rawValue)
        XCTAssertEqual(surface.payload.metadata["externalSearchPrivacy"], "broad-mission-query-only-no-private-page-text")
        XCTAssertEqual(surface.origin, .imported)
        XCTAssertEqual(surface.privacy, .publicReference)
        XCTAssertTrue(surface.payload.body.contains("No lesson attached"))
    }

    func testJSpaceGiftIsAnHonestLocalArtifactRatherThanAPretendWebFindOrDaytimeGeneration() throws {
        let plan = BookFoundGiftPlan(
            id: "j-space-gift-plan",
            capacity: .personalLanguage,
            directiveID: "hypothesis-language",
            searchQueries: [],
            casualBridge: "put a more exact word within reach",
            realm: .jSpace
        )
        let interior = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-100 * 86_400)),
            inputs: .empty,
            now: now,
            calendar: calendar
        )

        let surface = try XCTUnwrap(BookFoundGiftEngine.jSpaceSurface(
            for: plan,
            interior: interior,
            now: now
        ))

        XCTAssertEqual(surface.prompt, "Here, I found this for you.")
        XCTAssertEqual(surface.sourceID, BookFoundGiftEngine.jSpaceSourceID)
        XCTAssertEqual(surface.origin, .generated)
        XCTAssertEqual(surface.privacy, .privateLocal)
        XCTAssertEqual(surface.payload.metadata["provenance"], "authored-fictional-j-space-catalog")
        XCTAssertEqual(surface.payload.metadata["fictionalSource"], "true")
        XCTAssertEqual(surface.payload.metadata["bookFoundGiftRealm"], BookFoundGiftRealm.jSpace.rawValue)
        XCTAssertEqual(surface.payload.metadata["generationPolicy"], "deterministic-local-no-model")
        XCTAssertNil(surface.payload.metadata["url"])
        XCTAssertNil(surface.payload.metadata["searchQuery"])
        XCTAssertTrue(surface.payload.body.contains("It was not on the public web"))
        XCTAssertTrue(surface.payload.body.contains("No assignment"))
        XCTAssertFalse(SurfaceReadinessState(surface: surface).needsLocalBrainToOpen)

        let fakeWebThing = BookFoundWebThing(
            title: "Not allowed through the wrong door",
            excerpt: "This should not be accepted for a J-space plan even though it has enough text to look valid.",
            sourceName: "Example",
            sourceURL: "https://example.org/wrong-door",
            searchQuery: "wrong door"
        )
        XCTAssertNil(BookFoundGiftEngine.surface(for: plan, thing: fakeWebThing, now: now))
    }

    func testJSpaceHasAnAuthoredGiftForEveryLongGameCapacity() throws {
        let interior = BookInteriorState(awakenedAt: now.addingTimeInterval(-100 * 86_400))

        for capacity in BookLongGameCapacity.allCases {
            let plan = BookFoundGiftPlan(
                id: "j-space-capacity-\(capacity.rawValue)",
                capacity: capacity,
                directiveID: "hypothesis-\(capacity.rawValue)",
                searchQueries: [],
                casualBridge: "leave one strange thing within reach",
                realm: .jSpace
            )
            let surface = try XCTUnwrap(
                BookFoundGiftEngine.jSpaceSurface(for: plan, interior: interior, now: now),
                "J-space should contain an authored artifact for \(capacity.rawValue)."
            )
            XCTAssertEqual(surface.payload.metadata["bookLongGameCapacity"], capacity.rawValue)
            XCTAssertFalse(surface.payload.metadata["jSpaceGiftID", default: ""].isEmpty)
        }
    }

    func testOccasionalGiftPlansVisitBothThePublicWebAndJSpace() {
        let hypothesis = BookLongGameHypothesis(
            id: "gift-realm-rotation",
            capacity: .worldOtherness,
            statement: "The autonomous world needs more room.",
            nextHonestTest: "Bring back one honest surprise.",
            evidenceIDs: [],
            formedAt: now,
            lastRevisedAt: now
        )
        let interior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-100 * 86_400),
            longGame: BookLongGame(
                phase: .estrangeTheFamiliar,
                strategy: "Let the world exceed its use.",
                startedAt: now.addingTimeInterval(-90 * 86_400),
                lastAdvancedAt: now,
                phasePresentedAt: now,
                milestones: [],
                hypotheses: [hypothesis]
            )
        )
        let realms = Set((0..<60).compactMap { offset in
            let date = now.addingTimeInterval(Double(offset) * 86_400)
            return BookFoundGiftEngine.plan(
                for: BookDay(id: BookDay.id(for: date, calendar: calendar), date: date, pages: []),
                interior: interior,
                surfaceHistory: [:],
                keptPageCount: 3,
                now: date
            )?.realm
        })

        XCTAssertEqual(realms, Set(BookFoundGiftRealm.allCases))
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
        XCTAssertEqual(plan.realm, .publicWeb)
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
        XCTAssertEqual(opened.currentProject?.id, "book-project-secret-secret-test")
        XCTAssertTrue(opened.recentSurprise?.line.contains("alter how I handle") == true)
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

    func testBookStartsAnOwnProjectAndPresentsItsWorkWithoutAssigningTheReader() throws {
        let exactWords = BookQuirk(
            id: "book-quirk-exactWords",
            kind: .exactWords,
            title: "Exact-Word Hoarding",
            confession: "I collect exact words.",
            manifestation: "The Book pockets exact phrases.",
            maturity: .familiar,
            bornAt: now.addingTimeInterval(-20 * 86_400),
            revealedAt: now.addingTimeInterval(-10 * 86_400),
            firstPresentedAt: now.addingTimeInterval(-9 * 86_400),
            exerciseCount: 2
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(
            id: "project-seed",
            date: now,
            pages: (1...4).map { keptPage($0) }
        )]
        let state = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-20 * 86_400),
            quirks: [exactWords]
        )

        let evolved = BookInteriorEngine.reconciled(
            state,
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        let project = try XCTUnwrap(evolved.currentProject)
        XCTAssertEqual(project.kind, .exactLanguage)
        XCTAssertEqual(project.status, .investigating)
        XCTAssertFalse(project.entries.isEmpty)
        XCTAssertTrue(project.whyItCares.contains("I want"))
        let projectSurface = try XCTUnwrap(
            BookInteriorSurfaces.candidates(
                for: inputs.days[0],
                inputs: withInterior(inputs, evolved),
                now: now
            ).first { $0.payload.metadata["bookProjectID"] == project.id }
        )
        XCTAssertTrue(projectSurface.payload.body.contains("You have not been assigned anything"))
    }

    func testPendingQuirkActInterferesWithOneOrdinaryPageAndBecomesDurableHistory() throws {
        let quirk = BookQuirk(
            id: "book-quirk-ribbonRivalry",
            kind: .ribbonRivalry,
            title: "The Ribbon Dispute",
            confession: "The ribbon and I disagree.",
            manifestation: "The ribbon moves and denies it.",
            maturity: .familiar,
            bornAt: now.addingTimeInterval(-12 * 86_400),
            revealedAt: now.addingTimeInterval(-10 * 86_400),
            firstPresentedAt: now.addingTimeInterval(-9 * 86_400),
            exerciseCount: 1
        )
        let act = BookBehaviorAct(
            id: "book-behavior-ribbon-test",
            quirkID: quirk.id,
            quirkKind: .ribbonRivalry,
            title: "The Ribbon Interfered",
            marginLine: "The ribbon moved. It has submitted a denial.",
            evidencePageIDs: [],
            targetType: nil,
            createdAt: now,
            enactedAt: nil,
            status: .pending
        )
        let interior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-20 * 86_400),
            quirks: [quirk],
            pendingBehavior: act
        )
        let ordinary = SurfacePage(
            id: "ordinary-page",
            type: .souvenir,
            sourceID: "ordinary",
            intent: .capture,
            renderStyle: .promptCard,
            score: 60,
            reason: "An ordinary Page was already arriving.",
            prompt: "Keep one thing",
            detail: "One literal detail.",
            payload: BookPagePayload(headline: "Ordinary", body: "The ordinary body.")
        )

        let acted = try XCTUnwrap(
            BookPersonalityActuator.enacting(
                in: [ordinary],
                interior: interior,
                day: BookDay(id: "2026-07-20", date: now, pages: [])
            ).first
        )
        XCTAssertEqual(acted.id, ordinary.id)
        XCTAssertEqual(acted.payload.metadata["bookBehaviorID"], act.id)
        XCTAssertEqual(acted.payload.metadata["bookActedMargin"], act.marginLine)

        let recorded = BookInteriorEngine.recordingSurfaceOpened(
            interior,
            behaviorID: acted.payload.metadata["bookBehaviorID"],
            now: now.addingTimeInterval(60)
        )
        XCTAssertNil(recorded.pendingBehavior)
        XCTAssertEqual(recorded.behaviorHistory.last?.status, .enacted)
        XCTAssertEqual(recorded.quirks.first?.exerciseCount, 2)
    }

    func testReaderCorrectionCreatesAVisibleFaultAndRepairInsteadOfVanishing() throws {
        var inputs = BookSourceInputs.empty
        inputs.bookObservations = [BookObservationRecord(
            id: "too-neat-reading",
            kind: "pattern",
            status: .notQuite,
            evidencePageIDs: ["page-a", "page-b"],
            firstPresentedAt: now.addingTimeInterval(-600),
            updatedAt: now
        )]
        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-10 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        let fault = try XCTUnwrap(evolved.currentFault)
        XCTAssertEqual(fault.kind, .prematurePattern)
        XCTAssertEqual(fault.evidencePageIDs, ["page-a", "page-b"])
        XCTAssertNil(fault.presentedAt)
        let answer = try XCTUnwrap(BookInteriorAnswerGrounder.answer(to: "Have you been wrong?", interior: evolved))
        XCTAssertTrue(answer.contains(fault.admission))
        XCTAssertTrue(answer.contains(fault.repair))
    }

    func testRunningBusinessAdvancesItsOwnCallbackInsteadOfRepeatingOneJokeForever() throws {
        let quirk = BookQuirk(
            id: "book-quirk-ribbonRivalry",
            kind: .ribbonRivalry,
            title: "The Ribbon Dispute",
            confession: "The ribbon and I disagree.",
            manifestation: "The ribbon moves and denies it.",
            maturity: .familiar,
            bornAt: now.addingTimeInterval(-20 * 86_400),
            revealedAt: now.addingTimeInterval(-15 * 86_400),
            firstPresentedAt: now.addingTimeInterval(-14 * 86_400),
            exerciseCount: 1
        )
        let state = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-20 * 86_400),
            quirks: [quirk]
        )
        let first = BookInteriorEngine.reconciled(state, inputs: .empty, now: now, calendar: calendar)
        let firstLine = try XCTUnwrap(first.runningBusiness?.latestLine)
        let later = BookInteriorEngine.reconciled(
            first,
            inputs: .empty,
            now: now.addingTimeInterval(10 * 86_400),
            calendar: calendar
        )

        XCTAssertEqual(later.runningBusiness?.callbackCount, 1)
        XCTAssertNotEqual(later.runningBusiness?.latestLine, firstLine)
    }

    func testBookBuildsAnAutobiographyFromThingsThatActuallyHappenedToIt() throws {
        let favorite = BookFavorite(
            id: "favorite-blue-cup",
            pageID: "return-page",
            pageType: .souvenir,
            excerpt: "The blue cup held a crooked piece of afternoon light.",
            reason: "It refused to become a summary.",
            chosenAt: now.addingTimeInterval(-40 * 86_400),
            firstPresentedAt: now.addingTimeInterval(-39 * 86_400)
        )
        let before = BookPage(
            id: "before-quiet",
            type: .diary,
            createdAt: now.addingTimeInterval(-70 * 86_400),
            promptText: "Before",
            userInput: "A page before the long quiet.",
            origin: .userAuthored
        )
        let returned = BookPage(
            id: "return-page",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-35 * 86_400),
            promptText: "Return",
            userInput: "The blue cup held a crooked piece of afternoon light.",
            origin: .userAuthored
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "autobiography", date: now, pages: [before, returned])]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(
                awakenedAt: now.addingTimeInterval(-120 * 86_400),
                favorite: favorite
            ),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(evolved.autobiography.contains { $0.kind == .awakening })
        XCTAssertTrue(evolved.autobiography.contains { $0.kind == .firstFavorite && $0.evidencePageIDs == ["return-page"] })
        let returnMemory = try XCTUnwrap(evolved.autobiography.first { $0.kind == .readerReturned })
        XCTAssertTrue(returnMemory.whatItChanged.contains("absence is not betrayal"))
        let answer = try XCTUnwrap(BookInteriorAnswerGrounder.answer(
            to: "What do you remember about yourself?",
            interior: evolved
        ))
        XCTAssertTrue(answer.contains("things that happened to me"))
    }

    func testAcquiredTasteRequiresRepeatedEvidenceAndThenBendsCuration() throws {
        let thresholdPages = (0..<3).map { index in
            BookPage(
                id: "threshold-taste-\(index)",
                type: .diary,
                createdAt: now.addingTimeInterval(Double(-(index * 3)) * 86_400),
                promptText: "A threshold",
                userInput: "The doorway behaved differently on visit \(index).",
                tags: ["threshold"],
                origin: .userAuthored
            )
        }
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "taste", date: now, pages: thresholdPages)]
        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-100 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        let taste = try XCTUnwrap(evolved.acquiredTastes.first)
        XCTAssertEqual(taste.kind, .thresholds)
        XCTAssertEqual(taste.evidencePageIDs.count, 3)
        let surface = SurfacePage(
            id: "threshold-surface",
            type: .location,
            sourceID: "location",
            intent: .capture,
            renderStyle: .promptCard,
            score: 40,
            reason: "A doorway is behaving oddly.",
            prompt: "Cross differently",
            detail: "Notice the arrival.",
            payload: BookPagePayload(headline: "A Doorway", body: "One crossing.")
        )
        let influenced = BookInteriorVoice.influencing(surface, interior: evolved)
        XCTAssertGreaterThan(influenced.score, surface.score)
        XCTAssertEqual(influenced.payload.metadata["bookTasteID"], taste.id)

        let tasteOnly = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-100 * 86_400),
            acquiredTastes: [taste]
        )
        let admitted = try XCTUnwrap(BookPersonalityActuator.enacting(
            in: [surface],
            interior: tasteOnly,
            day: BookDay(id: "taste-admission", date: now, pages: [])
        ).first)
        XCTAssertEqual(admitted.payload.metadata["bookAcquiredTasteID"], taste.id)
        XCTAssertTrue(admitted.payload.metadata["bookActedMargin"]?.contains("not required") == true)
        let presented = BookInteriorEngine.recordingSurfaceOpened(
            tasteOnly,
            tasteID: taste.id,
            now: now.addingTimeInterval(60)
        )
        XCTAssertNotNil(presented.acquiredTastes.first?.firstPresentedAt)
    }

    func testPrivateTraditionWaitsForHistoryThenReturnsAsAnAct() throws {
        let awakening = BookAutobiographicalMemory(
            id: "book-memory-awakening",
            kind: .awakening,
            title: "The Day I Woke",
            line: "I woke as this Book.",
            whatItChanged: "I became specific.",
            evidencePageIDs: [],
            happenedAt: now.addingTimeInterval(-250 * 86_400),
            firstRecalledAt: now.addingTimeInterval(-220 * 86_400),
            lastRecalledAt: now.addingTimeInterval(-220 * 86_400),
            recallCount: 1
        )
        let memory = BookAutobiographicalMemory(
            id: "book-memory-favorite-old",
            kind: .firstFavorite,
            title: "The First Dog-Ear",
            line: "I chose a first favorite.",
            whatItChanged: "I acquired taste.",
            evidencePageIDs: ["favorite-old"],
            happenedAt: now.addingTimeInterval(-200 * 86_400),
            firstRecalledAt: now.addingTimeInterval(-170 * 86_400),
            lastRecalledAt: now.addingTimeInterval(-170 * 86_400),
            recallCount: 1
        )
        let founded = BookInteriorEngine.reconciled(
            BookInteriorState(
                awakenedAt: now.addingTimeInterval(-250 * 86_400),
                autobiography: [awakening, memory]
            ),
            inputs: .empty,
            now: now,
            calendar: calendar
        )
        let tradition = try XCTUnwrap(founded.privateTraditions.first)
        XCTAssertEqual(tradition.kind, .dogEarDay)
        XCTAssertNil(founded.pendingReminiscence)

        let dueAt = tradition.nextDueAt.addingTimeInterval(1)
        let due = BookInteriorEngine.reconciled(
            founded,
            inputs: .empty,
            now: dueAt,
            calendar: calendar
        )
        let reminiscence = try XCTUnwrap(due.pendingReminiscence)
        XCTAssertEqual(reminiscence.traditionID, tradition.id)
        XCTAssertTrue(reminiscence.line.contains("private holiday"))

        let ordinary = SurfacePage(
            id: "present-page",
            type: .souvenir,
            sourceID: "souvenir",
            intent: .capture,
            renderStyle: .promptCard,
            score: 50,
            reason: "The present was already arriving.",
            prompt: "Keep one thing",
            detail: "One detail.",
            payload: BookPagePayload(headline: "Today", body: "The present Page.")
        )
        let acted = try XCTUnwrap(BookPersonalityActuator.enacting(
            in: [ordinary],
            interior: due,
            day: BookDay(id: "tradition-due", date: dueAt, pages: [])
        ).first)
        XCTAssertEqual(acted.payload.metadata["bookReminiscenceID"], reminiscence.id)

        let observed = BookInteriorEngine.recordingSurfaceOpened(
            due,
            reminiscenceID: reminiscence.id,
            now: dueAt.addingTimeInterval(60)
        )
        XCTAssertNil(observed.pendingReminiscence)
        XCTAssertEqual(observed.reminiscenceHistory.last?.status, .recalled)
        XCTAssertEqual(observed.privateTraditions.first?.observanceCount, 1)
        XCTAssertGreaterThan(observed.privateTraditions.first?.nextDueAt ?? dueAt, dueAt)
    }

    func testBookInitiatedConversationIsOnlyADeterministicButtonGatedTeaser() throws {
        let want = bookWant(.company)
        let initiative = bookInitiative(.idleCompany, mode: .conversation, want: want)
        let interior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-30 * 86_400),
            currentWant: want,
            currentInitiative: initiative
        )
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = interior
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let surface = try XCTUnwrap(BookInteriorSurfaces.candidates(
            for: day,
            inputs: inputs,
            now: now
        ).first(where: { $0.payload.metadata["bookInitiativeID"] == initiative.id }))

        XCTAssertEqual(surface.type, .askTheBook)
        XCTAssertEqual(surface.sourceID, "book-deterministic-initiative")
        XCTAssertEqual(surface.payload.metadata["bookInitiativeGenerationPolicy"], "user-initiated-only")
        XCTAssertEqual(surface.payload.metadata["bookInitiativeOpening"], initiative.openingLine)
        XCTAssertTrue(surface.payload.body.contains("Nothing has been generated"))
        XCTAssertTrue(surface.payload.body.contains("press the chat button"))
        XCTAssertFalse(SurfaceReadinessState(surface: surface).needsLocalBrainToOpen)

        let opened = BookInteriorEngine.recordingSurfaceOpened(
            interior,
            initiativeID: initiative.id,
            now: now.addingTimeInterval(60)
        )
        XCTAssertEqual(opened.currentInitiative?.status, .opened)
        XCTAssertEqual(opened.currentWant?.status, .voiced)
        XCTAssertNil(opened.currentInitiative?.answeredAt)
        XCTAssertNil(opened.currentInitiative?.readerReplyExcerpt)
    }

    func testSayOnlyInitiativeCompletesWithoutRequestingOrWaitingForAReply() throws {
        let want = bookWant(.tellTheReader)
        let initiative = bookInitiative(.unsolicitedThought, mode: .sayOnly, want: want)
        let interior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-30 * 86_400),
            currentWant: want,
            currentInitiative: initiative
        )
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = interior
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let surface = try XCTUnwrap(BookInteriorSurfaces.candidates(
            for: day,
            inputs: inputs,
            now: now
        ).first(where: { $0.payload.metadata["bookInitiativeID"] == initiative.id }))
        XCTAssertEqual(surface.type, .bookNotices)
        XCTAssertEqual(surface.payload.metadata["bookInitiativeInvitation"], "No reply is requested.")
        XCTAssertFalse(SurfaceReadinessState(surface: surface).needsLocalBrainToOpen)

        let said = BookInteriorEngine.recordingSurfaceOpened(
            interior,
            initiativeID: initiative.id,
            now: now.addingTimeInterval(60)
        )
        XCTAssertNil(said.currentInitiative)
        XCTAssertEqual(said.initiativeHistory.last?.status, .said)
        XCTAssertNil(said.currentWant)
        XCTAssertEqual(said.wantHistory.last?.status, .satisfied)
    }

    func testAnsweringABookInitiativeBecomesSharedHistoryWithoutClaimingAgreement() {
        let want = bookWant(.testAnOpinion)
        let tension = BookInnerTension(
            id: "book-tension-test",
            kind: .exactnessVersusWonder,
            firstPole: "Keep the fact exact.",
            secondPole: "Leave the unknown open.",
            presentStance: "Both remain true.",
            evidencePageIDs: ["kept-1"],
            bornAt: now.addingTimeInterval(-20 * 86_400),
            lastShiftedAt: now.addingTimeInterval(-20 * 86_400),
            firstPresentedAt: nil
        )
        var initiative = bookInitiative(.friendlyArgument, mode: .conversation, want: want)
        initiative.tensionID = tension.id
        var interior = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-30 * 86_400),
            currentWant: want,
            currentTension: tension,
            currentInitiative: initiative
        )
        interior = BookInteriorEngine.recordingSurfaceOpened(
            interior,
            initiativeID: initiative.id,
            now: now.addingTimeInterval(60)
        )

        let answered = BookInteriorEngine.recordingInitiativeAnswered(
            interior,
            initiativeID: initiative.id,
            readerLine: "I disagree; the unknown is sometimes just missing information.",
            now: now.addingTimeInterval(120)
        )

        XCTAssertNil(answered.currentInitiative)
        XCTAssertEqual(answered.initiativeHistory.last?.status, .answered)
        XCTAssertTrue(answered.initiativeHistory.last?.readerReplyExcerpt?.contains("I disagree") == true)
        XCTAssertEqual(answered.wantHistory.last?.status, .satisfied)
        XCTAssertTrue(answered.currentTension?.presentStance.contains("without pretending it settled") == true)
        XCTAssertTrue(answered.autobiography.contains {
            $0.kind == .conversationAnswered && $0.title == "The Book Spoke First"
        })
    }

    func testFriendlyArgumentKeepsBothPositionsAndSemanticEvidenceWithoutInferringPolarity() throws {
        let want = bookWant(.testAnOpinion)
        var initiative = bookInitiative(.friendlyArgument, mode: .conversation, want: want)
        initiative.status = .opened
        let opinion = BookOpinion(
            id: "opinion-blue-cup",
            subject: "the blue cup",
            statement: "My present opinion is the blue cup matters because it refuses to become background.",
            strength: .held,
            evidencePageIDs: ["kept-1"],
            formedAt: now.addingTimeInterval(-4 * 86_400),
            lastRevisedAt: now.addingTimeInterval(-4 * 86_400),
            revisions: [],
            firstPresentedAt: now.addingTimeInterval(-3 * 86_400)
        )
        var semanticPage = keptPage(1)
        semanticPage.sensoryFolio = SensoryFolio(vectors: [
            SensoryVector(kind: .languageSemantic, modelID: "test-semantic-v1", values: [1, 0, 0])
        ])
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "argument-day", date: semanticPage.createdAt, pages: [semanticPage])]
        let state = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-40 * 86_400),
            opinion: opinion,
            currentWant: want,
            currentInitiative: initiative
        )

        let answered = BookInteriorEngine.recordingInitiativeAnswered(
            state,
            initiativeID: initiative.id,
            readerLine: "I disagree. That cup is ordinary; you are making the light do all the work.",
            inputs: inputs,
            now: now
        )

        let dispute = try XCTUnwrap(answered.currentDispute)
        XCTAssertEqual(dispute.bookClaim, opinion.statement)
        XCTAssertEqual(dispute.readerStance, .disagrees)
        XCTAssertTrue(dispute.readerLine.contains("making the light do all the work"))
        XCTAssertEqual(dispute.semanticEvidencePageIDs, ["kept-1"])
        XCTAssertEqual(answered.opinion?.strength, .reconsidering)
        XCTAssertTrue(answered.autobiography.contains {
            $0.title == "The Reader Disagreed with the Book"
                && $0.whatItChanged.contains("resemblance alone")
        })
        let recalled = try XCTUnwrap(BookInteriorAnswerGrounder.answer(
            to: "What did we argue about?",
            interior: answered
        ))
        XCTAssertTrue(recalled.contains(opinion.statement))
        XCTAssertTrue(recalled.contains("making the light do all the work"))
    }

    func testNewRelationalEvidenceReturnsToAnOldArgumentWithoutDeclaringAWinner() throws {
        let want = bookWant(.testAnOpinion)
        var initiative = bookInitiative(.friendlyArgument, mode: .conversation, want: want)
        initiative.status = .opened
        let opinion = BookOpinion(
            id: "opinion-souvenir",
            subject: "small souvenirs",
            statement: "I think small souvenirs tell the truth more readily than summaries.",
            strength: .leaning,
            evidencePageIDs: ["argument-pattern-1"],
            formedAt: now.addingTimeInterval(-2 * 86_400),
            lastRevisedAt: now.addingTimeInterval(-2 * 86_400),
            revisions: [],
            firstPresentedAt: now.addingTimeInterval(-86_400)
        )
        let firstPage = BookPage(
            id: "argument-pattern-1",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-8 * 86_400),
            promptText: "",
            userInput: "A blue ticket stub under the lamp.",
            tags: ["genre:slice-of-life"]
        )
        var initialInputs = BookSourceInputs.empty
        initialInputs.days = [BookDay(id: "pattern-day-1", date: firstPage.createdAt, pages: [firstPage])]
        let initial = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-50 * 86_400),
            opinion: opinion,
            currentWant: want,
            currentInitiative: initiative
        )
        let answered = BookInteriorEngine.recordingInitiativeAnswered(
            initial,
            initiativeID: initiative.id,
            readerLine: "I think you're partly right, but summaries can be honest too.",
            inputs: initialInputs,
            now: now
        )
        XCTAssertTrue(try XCTUnwrap(answered.currentDispute).relationalConnectionIDs.isEmpty)

        let patternPages = (1...8).map { index in
            BookPage(
                id: "argument-pattern-\(index)",
                type: index <= 4 ? .souvenir : .plainPage,
                createdAt: now.addingTimeInterval(Double(index) * 86_400),
                promptText: "",
                userInput: index <= 4 ? "A small object from the day \(index)." : "A broad account of day \(index).",
                tags: index <= 4 ? ["genre:slice-of-life"] : ["genre:adventure"]
            )
        }
        var matureInputs = BookSourceInputs.empty
        matureInputs.days = patternPages.map {
            BookDay(id: BookDay.id(for: $0.createdAt, calendar: calendar), date: $0.createdAt, pages: [$0])
        }
        let later = now.addingTimeInterval(10 * 86_400)
        let evolved = BookInteriorEngine.reconciled(answered, inputs: matureInputs, now: later, calendar: calendar)
        let dispute = try XCTUnwrap(evolved.currentDispute)
        XCTAssertEqual(dispute.status, .newEvidence)
        XCTAssertFalse(dispute.relationalConnectionIDs.isEmpty)
        XCTAssertTrue(dispute.evidencePageIDs.contains("argument-pattern-4"))

        matureInputs.bookInterior = evolved
        let surface = try XCTUnwrap(BookInteriorSurfaces.candidates(
            for: BookDay(id: BookDay.id(for: later), date: later, pages: []),
            inputs: matureInputs,
            now: later
        ).first(where: { $0.payload.metadata["bookDisputeID"] == dispute.id }))
        XCTAssertTrue(surface.payload.body.contains(opinion.statement))
        XCTAssertTrue(surface.payload.body.contains("summaries can be honest too"))
        XCTAssertTrue(surface.payload.body.contains("did not vote") || surface.payload.body.contains("not calling resemblance"))

        let opened = BookInteriorEngine.recordingSurfaceOpened(
            evolved,
            disputeID: dispute.id,
            now: later.addingTimeInterval(60)
        )
        XCTAssertEqual(opened.currentDispute?.status, .revisited)
        XCTAssertEqual(opened.currentDispute?.returnCount, 1)

        let stable = BookInteriorEngine.reconciled(
            opened,
            inputs: matureInputs,
            now: later.addingTimeInterval(3_600),
            calendar: calendar
        )
        XCTAssertEqual(stable.opinion?.strength, .reconsidering)
        XCTAssertEqual(stable.opinion?.revisions.count, opened.opinion?.revisions.count)
        XCTAssertEqual(stable.currentDispute?.returnCount, 1)
    }

    func testSilenceReleasesAnOpenedInitiativeWithoutEscalatingOrCallingItRejection() {
        let want = bookWant(.company, bornAt: now.addingTimeInterval(-12 * 86_400))
        var initiative = bookInitiative(
            .idleCompany,
            mode: .conversation,
            want: want,
            createdAt: now.addingTimeInterval(-8 * 86_400)
        )
        initiative.status = .opened
        initiative.presentedAt = now.addingTimeInterval(-8 * 86_400)
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-40 * 86_400),
            currentWant: want,
            currentInitiative: initiative
        )

        let quiet = BookInteriorEngine.reconciled(
            starting,
            inputs: .empty,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(quiet.currentInitiative)
        XCTAssertEqual(quiet.initiativeHistory.last?.status, .released)
        XCTAssertNil(quiet.initiativeHistory.last?.answeredAt)
        XCTAssertNil(quiet.initiativeHistory.last?.readerReplyExcerpt)
        XCTAssertNil(quiet.currentWant)
        XCTAssertEqual(quiet.wantHistory.last?.status, .released)
    }

    func testAnOldUnansweredFavorDoesNotPermanentlyGagTheBook() {
        let want = bookWant(.hearTheReader)
        var oldFavor = favor()
        oldFavor.createdAt = now.addingTimeInterval(-10 * 86_400)
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-40 * 86_400),
            activeFavor: oldFavor,
            currentWant: want
        )

        let evolved = BookInteriorEngine.reconciled(
            starting,
            inputs: .empty,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(evolved.activeFavor?.id, oldFavor.id)
        XCTAssertEqual(evolved.currentInitiative?.kind, .idleCompany)
        XCTAssertEqual(evolved.currentInitiative?.mode, .conversation)
    }

    func testTheBooksCanonicalFavoritesAreSpecificPartialAndComplicated() throws {
        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-40 * 86_400)),
            inputs: .empty,
            now: now,
            calendar: calendar
        )

        let wicker = try XCTUnwrap(evolved.loyalties.first { $0.targetID == "wicker-eddies" })
        let serenity = try XCTUnwrap(evolved.loyalties.first { $0.targetID == "serenity-brown" })
        let penny = try XCTUnwrap(evolved.loyalties.first { $0.targetID == "penny-blackletter" })
        XCTAssertEqual(wicker.strength, .devoted)
        XCTAssertEqual(wicker.stance, .complicated)
        XCTAssertTrue(wicker.reason.contains("interesting"))
        XCTAssertEqual(serenity.stance, .delighted)
        XCTAssertTrue(serenity.reason.contains("kinder"))
        XCTAssertEqual(penny.stance, .protective)
        XCTAssertTrue(penny.reason.contains("love reading what she writes"))
        XCTAssertTrue([wicker, serenity, penny].allSatisfy { !$0.counterweight.isEmpty })

        let answer = try XCTUnwrap(BookInteriorAnswerGrounder.answer(
            to: "Who are your favorite characters?",
            interior: evolved
        ))
        XCTAssertTrue(answer.contains("Wicker Eddies"))
        XCTAssertTrue(answer.contains("Serenity Brown"))
        XCTAssertTrue(answer.contains("Penny Blackletter"))

        let pennySurface = SurfacePage(
            id: "penny-filed-this",
            type: .note,
            sourceID: "student-note",
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 40,
            reason: "Penny filed a note.",
            prompt: "Penny Blackletter slipped you a note.",
            detail: "One honest detail.",
            payload: BookPagePayload(
                headline: "Filed by Penny",
                body: "The catalog card was full.",
                metadata: ["senderID": "penny-blackletter", "senderName": "Penny Blackletter"]
            )
        )
        let influenced = BookInteriorVoice.influencing(pennySurface, interior: evolved)
        XCTAssertGreaterThan(influenced.score, pennySurface.score)
        XCTAssertTrue(influenced.payload.metadata["bookLoyaltyIDs"]?.contains(penny.id) == true)
    }

    func testRepeatedReturnCanEarnTheBookALoyaltyToARealPlace() throws {
        let anchor = AnchorRecord(
            id: "crooked-reading-room",
            name: "The Crooked Reading Room",
            latitude: 44,
            longitude: -69,
            radiusMeters: 80,
            kind: .notice,
            belief: 9,
            created: "2026-01-01",
            weather: "rain",
            moon: "Waxing Moon",
            season: "Summer",
            playerWords: "The chairs never quite face the same direction twice.",
            academyEcho: "",
            outerStacksRoom: "",
            fae: "",
            miniStory: "",
            localRule: "",
            visitCount: 6,
            lastVisited: "2026-07-19"
        )
        var inputs = BookSourceInputs.empty
        inputs.anchors = [anchor]

        let evolved = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-100 * 86_400)),
            inputs: inputs,
            now: now,
            calendar: calendar
        )

        let loyalty = try XCTUnwrap(evolved.loyalties.first { $0.targetID == "anchor:\(anchor.id)" })
        XCTAssertEqual(loyalty.targetKind, .place)
        XCTAssertEqual(loyalty.strength, .devoted)
        XCTAssertTrue(loyalty.reason.contains("returned 6 times"))
        XCTAssertTrue(loyalty.counterweight.contains("business of its own"))
    }

    func testARepeatedTraditionMutatesWithoutErasingItsFormerCeremony() throws {
        let memory = BookAutobiographicalMemory(
            id: "book-memory-tradition-mutation",
            kind: .firstFavorite,
            title: "The First Dog-Ear",
            line: "A Page survived preference.",
            whatItChanged: "The Book became partial.",
            evidencePageIDs: ["kept-1"],
            happenedAt: now.addingTimeInterval(-300 * 86_400),
            firstRecalledAt: now.addingTimeInterval(-200 * 86_400),
            lastRecalledAt: now.addingTimeInterval(-100 * 86_400),
            recallCount: 1
        )
        let tradition = BookPrivateTradition(
            id: "book-tradition-mutation",
            kind: .dogEarDay,
            title: "The Feast of the First Dog-Ear",
            observance: "Return one old favorite.",
            originMemoryID: memory.id,
            evidencePageIDs: ["kept-1"],
            foundedAt: now.addingTimeInterval(-250 * 86_400),
            cadenceDays: 120,
            nextDueAt: now,
            lastObservedAt: now.addingTimeInterval(-120 * 86_400),
            observanceCount: 1
        )
        let reminiscence = BookReminiscence(
            id: "book-reminiscence-mutation",
            memoryID: memory.id,
            traditionID: tradition.id,
            title: tradition.title,
            line: tradition.observance,
            evidencePageIDs: tradition.evidencePageIDs,
            preferredType: .bookRemembered,
            createdAt: now,
            recalledAt: nil,
            status: .pending
        )
        let state = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-400 * 86_400),
            autobiography: [memory],
            privateTraditions: [tradition],
            pendingReminiscence: reminiscence
        )

        let observed = BookInteriorEngine.recordingSurfaceOpened(
            state,
            reminiscenceID: reminiscence.id,
            now: now.addingTimeInterval(60)
        )
        let changed = try XCTUnwrap(observed.privateTraditions.first)
        let mutation = try XCTUnwrap(changed.mutations?.first)
        XCTAssertEqual(changed.observanceCount, 2)
        XCTAssertEqual(changed.title, "The Feast of the Crooked Dog-Ear")
        XCTAssertEqual(mutation.formerTitle, "The Feast of the First Dog-Ear")
        XCTAssertEqual(mutation.formerObservance, "Return one old favorite.")
        XCTAssertTrue(mutation.reason.contains("2 real observances"))
    }

    func testARevealedSecretKeepsProducingVisibleConsequencesAcrossYears() throws {
        let openedAt = now.addingTimeInterval(-200 * 86_400)
        let secret = BookSecret(
            id: "long-secret",
            family: .method,
            tease: "I have a method I do not entirely trust.",
            revelation: "I arrange evidence until it starts arguing back.",
            sealedAt: openedAt.addingTimeInterval(-30 * 86_400),
            status: .revealed,
            revealedAt: openedAt
        )
        var state = BookInteriorEngine.reconciled(
            BookInteriorState(
                awakenedAt: now.addingTimeInterval(-500 * 86_400),
                secretHistory: [secret]
            ),
            inputs: .empty,
            now: now,
            calendar: calendar
        )
        var legacy = try XCTUnwrap(state.secretLegacies.first)
        XCTAssertEqual(legacy.stage, .echo)
        XCTAssertTrue(legacy.hasUnpresentedChange)

        var inputs = BookSourceInputs.empty
        inputs.bookInterior = state
        let surface = try XCTUnwrap(BookInteriorSurfaces.candidates(
            for: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            inputs: inputs,
            now: now
        ).first(where: { $0.payload.metadata["bookSecretLegacyID"] == legacy.id }))
        XCTAssertEqual(surface.type, .bookRemembered)
        state = BookInteriorEngine.recordingSurfaceOpened(
            state,
            secretLegacyID: legacy.id,
            now: now.addingTimeInterval(60)
        )
        XCTAssertFalse(state.secretLegacies[0].hasUnpresentedChange)

        let aYearLater = now.addingTimeInterval(366 * 86_400)
        state = BookInteriorEngine.reconciled(state, inputs: .empty, now: aYearLater, calendar: calendar)
        legacy = try XCTUnwrap(state.secretLegacies.first)
        XCTAssertEqual(legacy.stage, .argument)
        XCTAssertTrue(state.autobiography.contains { $0.kind == .secretConsequence })

        let yearsLater = aYearLater.addingTimeInterval(731 * 86_400)
        state = BookInteriorEngine.reconciled(state, inputs: .empty, now: yearsLater, calendar: calendar)
        XCTAssertEqual(state.secretLegacies.first?.stage, .inheritance)
        XCTAssertTrue(state.secretLegacies.first?.line.contains("kind of Book I became") == true)
    }

    func testRareCharacteristicSurpriseDeliversAValidatedCrossHistoryReframe() throws {
        let memory = BookAutobiographicalMemory(
            id: "book-memory-compound",
            kind: .conversationAnswered,
            title: "The Book Spoke First",
            line: "I asked for company and received an answer about the kitchen light.",
            whatItChanged: "Company became history.",
            evidencePageIDs: ["kept-compound"],
            happenedAt: now.addingTimeInterval(-100 * 86_400),
            firstRecalledAt: nil,
            lastRecalledAt: nil,
            recallCount: 0
        )
        let taste = BookAcquiredTaste(
            id: "book-taste-compound",
            kind: .exactLanguage,
            subject: "exact language",
            statement: "I have become openly fond of the exact phrase instead of its respectable summary.",
            strength: .fond,
            evidencePageIDs: ["kept-compound"],
            acquiredAt: now.addingTimeInterval(-90 * 86_400),
            lastDeepenedAt: now.addingTimeInterval(-20 * 86_400),
            firstPresentedAt: now.addingTimeInterval(-19 * 86_400)
        )
        let project = BookProject(
            id: "book-project-compound",
            kind: .exactLanguage,
            title: "The Exact Words Cabinet",
            question: "Which words belong specifically to this life?",
            whyItCares: "Ready-made language arrives too early.",
            subject: "the kitchen light",
            status: .investigating,
            entries: [BookProjectEntry(
                id: "project-entry-compound",
                line: "The kitchen light was described as tired gold.",
                evidencePageIDs: ["kept-compound"],
                recordedAt: now.addingTimeInterval(-20 * 86_400)
            )],
            startedAt: now.addingTimeInterval(-50 * 86_400),
            lastWorkedAt: now,
            nextEligibleAt: now.addingTimeInterval(30 * 86_400),
            lastPresentedProgress: 1
        )
        let want = bookWant(.tellTheReader)
        var inputs = BookSourceInputs.empty
        let compoundPage = BookPage(
            id: "kept-compound",
            type: .plainPage,
            createdAt: now.addingTimeInterval(-5 * 3_600),
            promptText: "",
            userInput: "The kitchen light looked like tired gold while I wanted company."
        )
        inputs.days = [BookDay(
            id: BookDay.id(for: now),
            date: now,
            pages: [compoundPage]
        )]
        inputs.selfFacts = [SelfFact(
            id: "reader-fact-compound",
            questionID: "favorite-hour",
            question: "Which hour feels most yours?",
            answer: "The blue hour after dinner.",
            bookTranslation: "The reader keeps a private fondness for the blue hour after dinner.",
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: ["time", "delight"],
            createdAt: now.addingTimeInterval(-30 * 86_400),
            updatedAt: now.addingTimeInterval(-10 * 86_400)
        )]
        var surpriseDraft = forgedDraft(
            signature: "surprise-packet-one",
            surpriseHeadline: "The Kitchen Light Was Company",
            surpriseSynthesis: "You asked for company by the kitchen light, but the Exact Words Cabinet later filed that same light as tired gold. Perhaps company was never the subject; perhaps exact language is how this Book learned to sit beside you without filling the room.",
            surpriseWhyUnexpected: "A conversation about company and a later filing about tired gold become the same lesson in how to be present.",
            surpriseIngredientIDs: ["memory:\(memory.id)", "project:\(project.id)"],
            surpriseConfidence: 94
        )
        surpriseDraft.surpriseIngredients = [
            BookInterpretationIngredient(
                id: "memory:\(memory.id)",
                kind: "book-memory",
                line: memory.line,
                evidencePageIDs: memory.evidencePageIDs
            ),
            BookInterpretationIngredient(
                id: "project:\(project.id)",
                kind: "book-project",
                line: project.entries[0].line,
                evidencePageIDs: project.entries[0].evidencePageIDs
            )
        ]
        inputs.overnightConnectionDrafts = [surpriseDraft]
        let starting = BookInteriorState(
            awakenedAt: now.addingTimeInterval(-200 * 86_400),
            currentProject: project,
            autobiography: [memory],
            acquiredTastes: [taste],
            currentWant: want
        )

        let evolved = BookInteriorEngine.reconciled(starting, inputs: inputs, now: now, calendar: calendar)
        let initiative = try XCTUnwrap(evolved.currentInitiative)
        XCTAssertEqual(initiative.kind, .characteristicSurprise)
        XCTAssertEqual(initiative.mode, .sayOnly)
        XCTAssertEqual(initiative.title, "The Kitchen Light Was Company")
        XCTAssertTrue(initiative.openingLine.contains("company was never the subject"))
        XCTAssertTrue(initiative.openingLine.contains("sit beside you without filling the room"))
        XCTAssertTrue(initiative.openingLine.contains("No assignment"))
        XCTAssertEqual(initiative.ingredientReceipts?.count, 3)
        XCTAssertTrue(initiative.ingredientReceipts?.contains("forge-surprise:forged-candidate-light:surprise-packet-one") == true)
        XCTAssertTrue(initiative.ingredientReceipts?.contains("memory:\(memory.id)") == true)
        XCTAssertTrue(initiative.ingredientReceipts?.contains("project:\(project.id)") == true)

        inputs.bookInterior = evolved
        let surface = try XCTUnwrap(BookInteriorSurfaces.candidates(
            for: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            inputs: inputs,
            now: now
        ).first(where: { $0.payload.metadata["bookInitiativeID"] == initiative.id }))
        XCTAssertEqual(surface.type, .bookNotices)
        XCTAssertEqual(surface.payload.metadata["bookInitiativeGenerationPolicy"], "user-initiated-only")
        XCTAssertTrue(surface.payload.metadata["bookInitiativeIngredientReceipts"]?.contains("forge-surprise:") == true)
        XCTAssertEqual(surface.payload.body, initiative.openingLine)
        XCTAssertFalse(surface.payload.body.contains("due an activity"))
        XCTAssertFalse(SurfaceReadinessState(surface: surface).needsLocalBrainToOpen)
    }

    private func withInterior(_ inputs: BookSourceInputs, _ interior: BookInteriorState) -> BookSourceInputs {
        var copy = inputs
        copy.bookInterior = interior
        return copy
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

    private func bookWant(
        _ kind: BookWantKind,
        bornAt: Date? = nil
    ) -> BookWant {
        BookWant(
            id: "book-want-test-\(kind.rawValue)",
            kind: kind,
            line: "The Book wants something of its own.",
            why: "A character may speak for a reason of its own without creating an obligation.",
            evidencePageIDs: ["kept-1"],
            bornAt: bornAt ?? now.addingTimeInterval(-4 * 86_400),
            status: .stirring,
            resolvedAt: nil
        )
    }

    private func bookInitiative(
        _ kind: BookInitiativeKind,
        mode: BookInitiativeMode,
        want: BookWant,
        createdAt: Date? = nil
    ) -> BookInitiative {
        BookInitiative(
            id: "book-initiative-test-\(kind.rawValue)",
            kind: kind,
            mode: mode,
            wantID: want.id,
            tensionID: nil,
            title: mode == .conversation ? "The Book Wanted Company" : "The Book Had a Thought",
            openingLine: "I wanted to say this before you asked me anything.",
            invitationLine: mode == .conversation ? "Answer only if you feel like it." : "No reply is requested.",
            suggestedPrompts: mode == .conversation ? ["Want to just talk?"] : [],
            motive: want.why,
            evidencePageIDs: want.evidencePageIDs,
            createdAt: createdAt ?? now,
            presentedAt: nil,
            answeredAt: nil,
            readerReplyExcerpt: nil,
            status: .pending
        )
    }

    private func forgedDraft(
        signature: String = "forged-packet",
        thesis: String = "I think afternoon light is not decoration here; it keeps giving ordinary objects permission to become events.",
        evidencePageIDs: [String] = ["kept-1", "kept-2", "kept-3"],
        confidence: Int = 88,
        surpriseHeadline: String? = nil,
        surpriseSynthesis: String? = nil,
        surpriseWhyUnexpected: String? = nil,
        surpriseIngredientIDs: [String]? = nil,
        surpriseConfidence: Int? = nil
    ) -> OvernightConnectionDraft {
        OvernightConnectionDraft(
            observationKey: "forged-observation-light",
            candidateID: "forged-candidate-light",
            evidenceSignature: signature,
            kind: "relational",
            headline: "What the Afternoon Light Is Doing",
            interpretation: "Several kept pages place exact ordinary objects inside recurring afternoon light.",
            question: "Is the light changing what earns the dignity of an event?",
            confidence: confidence,
            evidencePageIDs: evidencePageIDs,
            evidenceCards: "Afternoon light · ordinary objects",
            generatedAt: now,
            thesis: thesis,
            counterReading: "The light may recur simply because the room and camera angle recur.",
            falsifier: "If later objects remain equally vivid without the afternoon light, then I should revise this opinion.",
            whyItMatters: "It could make an ordinary room feel less like background and more like a place that keeps appointments.",
            surpriseHeadline: surpriseHeadline,
            surpriseSynthesis: surpriseSynthesis,
            surpriseWhyUnexpected: surpriseWhyUnexpected,
            surpriseIngredientIDs: surpriseIngredientIDs,
            surpriseConfidence: surpriseConfidence
        )
    }
}
