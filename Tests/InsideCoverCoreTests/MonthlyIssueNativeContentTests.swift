import XCTest
@testable import InsideCoverCore

final class MonthlyIssueNativeContentTests: XCTestCase {
    func testFindingChoiceRequiresACompletedKeptSentenceInTheSameRun() throws {
        let scope = AuthoredContentScope(scopeID: "october", runID: "2026")
        let page = BookPage(id: "finding", type: .narrativeOS, promptText: "Notice",
            userInput: "BOOK WORDS", playerReply: "The door holds a little light.", origin: .generated)
        let receipt = AuthoredContentReceipt(contentID: "invitation", occurrenceID: "returned",
            channel: .storyScene, scope: scope, state: .completed, recordedAt: Date(),
            evidencePageIDs: [page.id])
        let ledger = AuthoredContentReceiptLedger.empty.recording(receipt)
        XCTAssertEqual(AuthoredFindingInsertion.usableSentence(contentID: "invitation", scope: scope,
            ledger: ledger, pages: [page]), "The door holds a little light.")
        XCTAssertNil(AuthoredFindingInsertion.usableSentence(contentID: "invitation",
            scope: AuthoredContentScope(scopeID: "october", runID: "2027"), ledger: ledger, pages: [page]))
        XCTAssertNil(AuthoredFindingInsertion.usableSentence(contentID: "invitation", scope: scope,
            ledger: ledger, pages: []))
        var sensitive = page
        sensitive.privacy = .localSensitive
        XCTAssertNil(AuthoredFindingInsertion.usableSentence(contentID: "invitation", scope: scope,
            ledger: ledger, pages: [sensitive]))
    }

    func testTwoLooksInsertionUsesOnlyTheActualReturnedPair() throws {
        let scope = AuthoredContentScope(scopeID: "october", runID: "2026")
        let first = AuthoredReaderAnchor(pageID: "first", contributionIndex: 0,
            text: "The cup had a blue chip.")
        var returned = BookPage(id: "returned", type: .narrativeOS, promptText: "Go back once",
            userInput: "BOOK ACKNOWLEDGEMENT", playerReply: "The chip was still blue.", origin: .generated)
        returned.tags.append(AuthoredObservationPair.tagPrefix
            + (try JSONEncoder().encode(first)).base64EncodedString())
        let insertion = AuthoredObservationPairInsertion(contentID: "go-back", marker: "{pair}",
            quotationTemplate: "First: {first}\nThen: {second}")
        let receipt = AuthoredContentReceipt(contentID: "go-back", occurrenceID: "returned",
            channel: .storyScene, scope: scope, state: .completed, recordedAt: Date(),
            evidencePageIDs: [returned.id])
        let ledger = AuthoredContentReceiptLedger.empty.recording(receipt)
        XCTAssertEqual(insertion.render(scope: scope, ledger: ledger, pages: [returned]),
            "First: The cup had a blue chip.\nThen: The chip was still blue.")
        XCTAssertNil(insertion.render(scope: scope, ledger: .empty, pages: [returned]))
        returned.privacy = .localSensitive
        XCTAssertNil(insertion.render(scope: scope, ledger: ledger, pages: [returned]))
    }

    func testNodeProgressResumesChosenBranchWithoutRepeatingCommittedNode() throws {
        var scene = storyScene()
        scene.nodes = [
            AuthoredStoryNode(id: "entry", title: "Entry", body: "A door.", prompt: "Choose.",
                choices: [AuthoredStorySceneChoice(id: "left", title: "Left", prompt: "Left", result: "Opened.", nextNodeID: "end")]),
            AuthoredStoryNode(id: "end", title: "End", body: "Home.", prompt: "Keep.")
        ]
        let scope = AuthoredContentScope(scopeID: "issue", runID: "2027")
        XCTAssertTrue(AuthoredStoryProgress.diagnostics(for: scene).isEmpty)
        XCTAssertEqual(AuthoredStoryProgress.currentNode(scene: scene, contentID: "scene", scope: scope, ledger: .empty)?.id, "entry")
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "entry", channel: .storyScene,
            scope: scope, state: .nodeCompleted, recordedAt: Date(), choiceID: "left", nodeID: "entry", storyText: "The door opened.")
        let ledger = AuthoredContentReceiptLedger.empty.recording(receipt).recording(receipt)
        XCTAssertEqual(ledger.receipts.count, 1)
        XCTAssertEqual(AuthoredStoryProgress.currentNode(scene: scene, contentID: "scene", scope: scope, ledger: ledger)?.id, "end")
        let restored = try JSONDecoder().decode(AuthoredContentReceiptLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored, ledger)
        scene.nodes?[1].nextNodeID = "entry"
        XCTAssertFalse(AuthoredStoryProgress.diagnostics(for: scene).isEmpty)
    }

    func testAcceptedMissionUsesReturnPlacementWhileFreshReaderKeepsOfferPlacement() {
        var atom = contentAtom(id: "mission", referenceKind: .storyScene, referenceID: "mission-scene",
            channel: .storyScene, interaction: .fieldMission)
        atom.occurrence = AuthoredContentOccurrencePolicy(kind: .untilResolved)
        atom.missionReturn = MonthlyIssueMissionReturn(placement: MonthlyIssueContentPlacement(
            lifecycleStage: .live, phaseID: "assembly", phaseRole: .climax))
        let scope = AuthoredContentScope(scopeID: "issue", runID: "2027")
        let now = date(2027, 9, 22, 12)
        let accepted = AuthoredContentReceipt(contentID: "mission", occurrenceID: "invitation", channel: .storyScene,
            scope: scope, state: .accepted, recordedAt: now)
        XCTAssertEqual(atom.resolvingMissionReturn(scope: scope, ledger: .empty, now: now).placement.phaseID, "omen")
        let resolved = atom.resolvingMissionReturn(scope: scope, ledger: .empty.recording(accepted), now: now)
        XCTAssertEqual(resolved.placement.phaseID, "assembly")
        XCTAssertEqual(resolved.interaction, .readerEvidence)
        XCTAssertFalse(AuthoredContentDependency(contentID: "mission", requiredState: .completed)
            .isSatisfied(in: .empty.recording(accepted), currentScope: scope, now: now))
    }

    func testRuntimeRejectsRevocationExpiryAndTrashButAllowsOriginalDeliveredOffer() throws {
        let now = date(2027, 9, 2, 12)
        let day = BookDay(id: "2027-09-02", date: now, pages: [])
        let atom = contentAtom(id: "scene", referenceKind: .storyScene, referenceID: "under-the-stairs", channel: .storyScene)
        let graph = manifest(content: [atom])
        let pack = WorldEventPack(id: "dictionary-rebellion", displayName: "Fixture", version: 1, author: "Tests",
            availability: .bundledFree, events: [WorldEventRegistry.dictionaryRebellion], authoringManifests: [graph])
        let catalog = MonthlyIssueRuntimeCatalog(packs: [pack])
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: pack.id, event: pack.events[0], now: now))
        let scope = AuthoredContentScope(scopeID: graph.id, runID: snapshot.runID, phaseID: snapshot.phaseID)
        var inputs = BookSourceInputs.empty
        let delivered = AuthoredContentReceipt(contentID: "scene", occurrenceID: "offer", channel: .storyScene,
            scope: scope, state: .delivered, recordedAt: now)
        inputs.authoredContentReceipts = .empty.recording(delivered)
        XCTAssertTrue(catalog.allows(contentID: "scene", scope: scope, occurrenceID: "offer", day: day, inputs: inputs, now: now, hasAccess: true))
        XCTAssertFalse(catalog.allows(contentID: "scene", scope: scope, occurrenceID: "new-offer", day: day, inputs: inputs, now: now, hasAccess: true))
        XCTAssertFalse(catalog.allows(contentID: "scene", scope: scope, occurrenceID: "offer", day: day, inputs: inputs, now: now, hasAccess: false))
        XCTAssertFalse(catalog.allows(contentID: "scene", scope: scope, occurrenceID: "offer", day: day, inputs: inputs, now: date(2027, 9, 22, 12), hasAccess: true))
        inputs.authoredContentReceipts = inputs.authoredContentReceipts.recording(AuthoredContentReceipt(
            contentID: "scene", occurrenceID: "offer", channel: .storyScene, scope: scope, state: .dismissed, recordedAt: now))
        XCTAssertFalse(catalog.allows(contentID: "scene", scope: scope, occurrenceID: "offer", day: day, inputs: inputs, now: now, hasAccess: true))
    }

    func testBraidCoverageIsCarriedBySavedArtifactAndRewriteUsesOriginalReceipts() {
        let now = date(2027, 9, 2, 22)
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "node", channel: .storyScene,
            state: .nodeCompleted, recordedAt: now, nodeID: "end", storyText: "The fictional stair opened its eye.")
        let ledger = AuthoredContentReceiptLedger.empty.recording(receipt)
        XCTAssertEqual(MonthlyIssueBraidMatter.pending(ledger: ledger, days: [], replacing: nil, now: now).count, 1)
        let braid = MonthlyIssueBraidMatter.binding([receipt], into: BookPage(type: .bookOfYou,
            createdAt: now, promptText: "Tonight", userInput: "A real sentence stayed.", tags: ["braid"], usedInBookOfYou: true))
        let day = BookDay(id: "2027-09-02", date: now, pages: [braid])
        XCTAssertTrue(MonthlyIssueBraidMatter.pending(ledger: ledger, days: [day], replacing: nil, now: now).isEmpty)
        XCTAssertEqual(MonthlyIssueBraidMatter.pending(ledger: ledger, days: [day], replacing: braid, now: now).map(\.id), [receipt.id])
        XCTAssertTrue(braid.userInput.contains("fictional stair"))
    }

    func testMonthlyInterludePreservesExactCanonBetweenOpeningAndContinuation() {
        let now = date(2027, 9, 2, 22)
        let first = AuthoredContentReceipt(contentID: "scene", occurrenceID: "start", channel: .storyScene,
            state: .nodeCompleted, recordedAt: now, storyText: "Wicker took the pin.\n\nThe hinge stopped biting.")
        let second = AuthoredContentReceipt(contentID: "scene", occurrenceID: "end", channel: .storyScene,
            state: .nodeCompleted, recordedAt: now.addingTimeInterval(1), storyText: "Serenity shut the schoolroom door.")
        let page = BookPage(type: .bookOfYou, promptText: "Tonight",
            userInput: "A Quiet Hinge\n\nYou noticed a red thread on the fence.\n\nI worried at the loose end.\n\nThe Book kept the page: one red thread.",
            tags: [MonthlyIssueBraidMatter.interludeTag], usedInBookOfYou: true)
        let bound = MonthlyIssueBraidMatter.binding([second, first, first], into: page)
        XCTAssertEqual(bound.userInput, "A Quiet Hinge\n\nYou noticed a red thread on the fence.\n\nWicker took the pin.\n\nThe hinge stopped biting.\n\nSerenity shut the schoolroom door.\n\nI worried at the loose end.\n\nThe Book kept the page: one red thread.")
        XCTAssertEqual(MonthlyIssueBraidMatter.receiptIDs(in: bound), Set([first.id, second.id]))
        XCTAssertEqual(MonthlyIssueBraidMatter.binding([first, second], into: bound), bound)
    }

    func testMonthlyInterludeFallsBackBeforeClosingWithoutRequiringModelFormat() {
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "end", channel: .storyScene,
            state: .completed, recordedAt: date(2027, 9, 2, 22), storyText: "The stair opened its eye.")
        for tags in [[], [MonthlyIssueBraidMatter.interludeTag]] as [[String]] {
            let page = BookPage(type: .bookOfYou, promptText: "Tonight",
                userInput: "You found a feather. The Book kept the page: the feather.", tags: tags)
            XCTAssertEqual(MonthlyIssueBraidMatter.binding([receipt], into: page).userInput,
                "You found a feather.\n\nThe stair opened its eye.\n\nThe Book kept the page: the feather.")
        }
        let empty = BookPage(type: .bookOfYou, promptText: "Tonight", userInput: "")
        XCTAssertEqual(MonthlyIssueBraidMatter.binding([receipt], into: empty).userInput, receipt.storyText)
    }

    func testMonthlyPromptSeparatesPublicReportAndCommittedFictionAndBoundsContext() {
        let now = date(2027, 9, 2, 22)
        let report = AuthoredContentReceipt(contentID: "report", occurrenceID: "news", channel: .storyScene,
            state: .reported, recordedAt: now, storyText: "The assembly had ended.")
        let scene = AuthoredContentReceipt(contentID: "scene", occurrenceID: "choice", channel: .storyScene,
            state: .nodeCompleted, recordedAt: now, storyText: String(repeating: "Pin. ", count: 500))
        let preview = AuthoredContentReceipt(contentID: "unreached", occurrenceID: "preview", channel: .storyScene,
            state: .opened, recordedAt: now, storyText: "UNCOMMITTED OUTCOME")
        let prompt = MonthlyIssueBraidMatter.promptSection([report, scene, preview])
        XCTAssertTrue(prompt.contains("no attendance or choice is implied"))
        XCTAssertTrue(prompt.contains("participation belongs to the fiction"))
        XCTAssertTrue(prompt.contains("Context excerpt"))
        XCTAssertFalse(prompt.contains("UNCOMMITTED OUTCOME"))
        XCTAssertLessThan(prompt.count, 4_000)
        let bound = MonthlyIssueBraidMatter.binding([scene, preview], into:
            BookPage(type: .bookOfYou, promptText: "Tonight", userInput: ""))
        XCTAssertEqual(bound.userInput, scene.storyText)
        XCTAssertEqual(MonthlyIssueBraidMatter.receiptIDs(in: bound), [scene.id])
    }

    func testMonthlyScenePlanKeepsReaderSentenceAndSuppressesDuplicateFiction() throws {
        let now = date(2027, 9, 2, 22)
        let page = BookPage(id: "monthly-page", type: .narrativeOS, createdAt: now,
            promptText: "A schoolroom door.", userInput: "UNUSED RAW SCENE BODY",
            playerReply: "I saw a red thread on the fence.",
            tags: ["authored-story-scene", "choice:pin"], origin: .generated)
        let receipt = AuthoredContentReceipt(contentID: "scene", occurrenceID: "choice", channel: .storyScene,
            state: .nodeCompleted, recordedAt: now, storyText: "Wicker took the pin.")
        var context = BraidPromptBuilder.Context.empty
        context.authoredStoryReceipts = [receipt]
        let plan = BraidScenePlanBuilder.plan(for: BookDay(id: "2027-09-02", date: now, pages: [page]), context: context)
        XCTAssertEqual(plan.evidence.map(\.text), ["I saw a red thread on the fence."])
        XCTAssertEqual(plan.evidence.first?.kind, .writtenLine)
        XCTAssertFalse(plan.isQuietDay)
        XCTAssertNil(plan.worldBeat)
        XCTAssertTrue(plan.quietDayBeats.isEmpty)
        XCTAssertEqual(plan.authoredStoryReceipts, [receipt])
        XCTAssertTrue(plan.brief().contains("Wicker took the pin."))
        XCTAssertFalse(plan.brief().contains("UNUSED RAW SCENE BODY"))
        let restored = try JSONDecoder().decode(BraidScenePlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(restored.authoredStoryReceipts, [receipt])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        legacy.removeValue(forKey: "authoredStoryReceipts")
        let legacyPlan = try JSONDecoder().decode(BraidScenePlan.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(legacyPlan.authoredStoryReceipts)
    }

    func testAuthoredOnlyPlanDoesNotInventReaderEvidenceOrAnotherWorldEvent() {
        let now = date(2027, 9, 2, 22)
        let page = BookPage(type: .narrativeOS, createdAt: now, promptText: "A door.",
            userInput: "The door opened.", tags: ["authored-story-scene", "choice:pin"], origin: .generated)
        var context = BraidPromptBuilder.Context.empty
        context.authoredStoryReceipts = [AuthoredContentReceipt(contentID: "scene", occurrenceID: "end", channel: .storyScene,
            state: .nodeCompleted, recordedAt: now, storyText: "Wicker took the pin.")]
        let plan = BraidScenePlanBuilder.plan(for: BookDay(id: "2027-09-02", date: now, pages: [page]), context: context)
        XCTAssertTrue(plan.evidence.isEmpty)
        XCTAssertTrue(plan.placements.isEmpty)
        XCTAssertNil(plan.worldBeat)
        XCTAssertTrue(plan.quietDayBeats.isEmpty)
        XCTAssertFalse(plan.brief().contains(BraidScenePlan.readerDayLabel))
    }

    func testMonthlyPendingUsesOnlyCommittedPastReceiptsAndLeavesOverflowForAnotherNight() {
        let now = date(2027, 9, 2, 22)
        let committed = (0..<8).map { index in
            AuthoredContentReceipt(contentID: "scene", occurrenceID: "node-\(index)", channel: .storyScene,
                state: .nodeCompleted, recordedAt: now.addingTimeInterval(Double(index - 8)), storyText: "Passage \(index).")
        }
        let future = AuthoredContentReceipt(contentID: "scene", occurrenceID: "future", channel: .storyScene,
            state: .completed, recordedAt: now.addingTimeInterval(1), storyText: "FUTURE")
        let offered = AuthoredContentReceipt(contentID: "scene", occurrenceID: "offered", channel: .storyScene,
            state: .accepted, recordedAt: now, storyText: "INVITATION")
        let ledger = (Array(committed.reversed()) + [future, offered]).reduce(AuthoredContentReceiptLedger.empty) { $0.recording($1) }
        // One or two pieces of the world per braid; the rest wait their turn.
        let perNight = MonthlyIssueBraidMatter.passagesPerNight
        XCTAssertEqual(perNight, 2)
        let first = MonthlyIssueBraidMatter.pending(ledger: ledger, days: [], replacing: nil, now: now)
        XCTAssertEqual(first.map(\.id), Array(committed.prefix(perNight)).map(\.id))
        let bound = MonthlyIssueBraidMatter.binding(first, into: BookPage(type: .bookOfYou, promptText: "Tonight", userInput: ""))
        let days = [BookDay(id: "2027-09-02", date: now, pages: [bound])]
        XCTAssertEqual(MonthlyIssueBraidMatter.pending(ledger: ledger, days: days, replacing: nil, now: now).map(\.id),
            Array(committed.dropFirst(perNight).prefix(perNight)).map(\.id))
    }

    func testSupervisedJumpPreservesExistingJumpAndReturnsWithoutBorrowedRule() throws {
        let now = date(2027, 9, 2, 12)
        let work = BookJumpEngine.publicDomainShelf[0]
        let definition = AuthoredJumpDefinition(episodeID: "episode", work: work, guide: "The Book", anchor: "A fictional ribbon")
        let started = try XCTUnwrap(BookJumpEngine.authoredAction(.start, definition: definition, state: BookJumpState(), endsAt: now.addingTimeInterval(60), now: now))
        XCTAssertEqual(started.active?.authoredEpisodeID, "episode")
        XCTAssertNil(BookJumpEngine.authoredAction(.start, definition: definition, state: started, endsAt: now.addingTimeInterval(60), now: now))
        let ended = BookJumpEngine.dailyDecay(started, now: now.addingTimeInterval(60)).state
        XCTAssertNil(ended.active)
        XCTAssertEqual(ended.returned.count, 1)
        XCTAssertTrue(ended.borrowedRules.isEmpty)
    }

    func testRepeatableContentRetiresOnlyTheResolvedOccurrence() throws {
        let now = date(2027, 9, 2, 12)
        var atom = contentAtom(id: "mark", referenceKind: .marginalia, referenceID: "mark-object", channel: .marginalia)
        atom.occurrence = AuthoredContentOccurrencePolicy(kind: .repeatable, cooldownHours: 1)
        let graph = manifest(content: [atom])
        let pack = WorldEventPack(id: "dictionary-rebellion", displayName: "Fixture", version: 1, author: "Tests",
            availability: .bundledFree, events: [WorldEventRegistry.dictionaryRebellion], authoringManifests: [graph])
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: pack.id, event: pack.events[0], now: now))
        let scope = AuthoredContentScope(scopeID: graph.id, runID: snapshot.runID, phaseID: snapshot.phaseID)
        let catalog = MonthlyIssueRuntimeCatalog(packs: [pack])
        let day = BookDay(id: "2027-09-02", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        for state in [AuthoredContentReceiptState.delivered, .kept] {
            inputs.authoredContentReceipts = inputs.authoredContentReceipts.recording(AuthoredContentReceipt(
                contentID: atom.id, occurrenceID: "old", channel: .marginalia, scope: scope,
                state: state, recordedAt: now.addingTimeInterval(-7_200)))
        }
        XCTAssertFalse(catalog.allows(contentID: atom.id, scope: scope, occurrenceID: "old", day: day, inputs: inputs, now: now, hasAccess: true))
        XCTAssertTrue(catalog.allows(contentID: atom.id, scope: scope, occurrenceID: "new", day: day, inputs: inputs, now: now, hasAccess: true))
    }

    func testCatchUpCannotReportAFutureSceneOrInventParticipation() throws {
        var scene = storyScene()
        scene.report = "The stair opened during assembly."
        let atom = contentAtom(id: "past-scene", referenceKind: .storyScene, referenceID: scene.id, channel: .storyScene)
        let graph = manifest(content: [atom])
        let dependency = AuthoredContentDependency(contentID: atom.id, requiredState: .completed, failurePolicy: .reportThenContinue)
        let early = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: "dictionary-rebellion",
            event: WorldEventRegistry.dictionaryRebellion, now: date(2027, 9, 2, 12)))
        XCTAssertNil(MonthlyIssueCatchUp.report(for: dependency, manifest: graph, scenes: [scene],
            snapshot: early, ledger: .empty, now: date(2027, 9, 2, 12)))
        scene.reportAfterLiveDay = 0
        XCTAssertEqual(MonthlyIssueCatchUp.report(for: dependency, manifest: graph, scenes: [scene],
            snapshot: early, ledger: .empty, now: date(2027, 9, 2, 12)), scene.report)
        let report = AuthoredContentReceipt(contentID: atom.id, occurrenceID: "report", channel: .storyScene,
            state: .reported, recordedAt: date(2027, 9, 2, 12), storyText: scene.report)
        XCTAssertFalse(AuthoredContentReceiptLedger.empty.recording(report).satisfies(
            AuthoredContentReceiptQuery(contentID: atom.id, state: .completed), now: date(2027, 9, 2, 12)))
    }

    func testEverySupervisedBranchMustReturnAndOrdinaryJumpCannotAdvanceIt() throws {
        var scene = storyScene()
        scene.jump = AuthoredJumpDefinition(episodeID: "lesson", work: BookJumpEngine.publicDomainShelf[0], guide: "The Book", anchor: "A ribbon")
        scene.nodes = [
            AuthoredStoryNode(id: "enter", title: "Enter", body: "A door.", prompt: "Keep.", nextNodeID: "leave", jumpAction: .start),
            AuthoredStoryNode(id: "leave", title: "Leave", body: "Home.", prompt: "Keep.")
        ]
        XCTAssertTrue(AuthoredStoryProgress.diagnostics(for: scene).contains { $0.hasPrefix("unclosed-jump:") })
        scene.nodes?[1].jumpAction = .return
        XCTAssertTrue(AuthoredStoryProgress.diagnostics(for: scene).isEmpty)
        let now = date(2027, 9, 2, 12)
        let started = try XCTUnwrap(BookJumpEngine.authoredAction(.start, definition: try XCTUnwrap(scene.jump),
            state: BookJumpState(), endsAt: now.addingTimeInterval(60), now: now))
        XCTAssertEqual(BookJumpEngine.advance(started, line: "Unscripted", now: now), started)
        XCTAssertEqual(BookJumpEngine.collapse(started, now: now).lostBelief, 0)
    }

    func testPackDecoderAcceptsBothPublishedAndLegacyDates() throws {
        struct Dates: Codable { var at: Date }
        let published = try ContentPackFileLocator.decoder().decode(Dates.self,
            from: Data(#"{"at":"2027-09-02T12:00:00Z"}"#.utf8))
        let legacy = try ContentPackFileLocator.decoder().decode(Dates.self,
            from: JSONEncoder().encode(published))
        XCTAssertEqual(published.at, legacy.at)
    }

    func testAuthoredStorySceneUsesNativePageAndArbitraryPrewrittenChoices() throws {
        try withDictionaryEntitlement {
            let now = date(2027, 9, 2, 20)
            let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: [])
            let scene = storyScene()
            let atom = contentAtom(
                id: "scene-atom",
                referenceKind: .storyScene,
                referenceID: scene.id,
                channel: .storyScene,
                interaction: .choice
            )
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest(content: [atom])]
            inputs.authoredStoryScenes = [scene]

            let raw = try XCTUnwrap(AuthoredStoryScenePageAdapter.candidates(
                for: day, inputs: inputs, now: now
            ).first)
            let prepared = try XCTUnwrap(MonthlyIssuePageCuration.preparing(
                raw,
                manifests: inputs.monthlyIssueAuthoringManifests,
                day: day,
                inputs: inputs,
                now: now
            ))

            XCTAssertEqual(prepared.payload.metadata[MonthlyIssuePageMetadata.contentID], atom.id)
            XCTAssertEqual(prepared.payload.metadata[MonthlyIssuePageMetadata.interaction], "choice")
            XCTAssertTrue(prepared.isStoryPlayablePage)
            XCTAssertTrue(prepared.pageCapabilities.asksReader)
            let decoded = try JSONDecoder().decode(
                [AuthoredStorySceneChoice].self,
                from: try XCTUnwrap(
                    prepared.payload.metadata[AuthoredStoryScenePageAdapter.choicesMetadataKey]?.data(using: .utf8)
                )
            )
            XCTAssertEqual(decoded.map(\.id), ["knock", "listen", "leave-a-pin"])
            XCTAssertEqual(decoded[1].result, "Something underneath knocks back once, very politely.")

            let delivered = prepared.authoredContentReceipts(state: .delivered, at: now)
            let acted = prepared.authoredContentReceipts(
                state: .acted,
                at: now,
                choiceID: "listen"
            )
            XCTAssertEqual(delivered.first?.contentID, atom.id)
            XCTAssertEqual(acted.first?.choiceID, "listen")
            XCTAssertNotEqual(delivered.first?.id, acted.first?.id)
        }
    }

    func testNarrativeOnlyAuthoredSceneDoesNotPretendItNeedsAChoice() throws {
        try withDictionaryEntitlement {
            let now = date(2027, 9, 2, 12)
            let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: [])
            let scene = storyScene()
            let atom = contentAtom(
                id: "plain-scene",
                referenceKind: .storyScene,
                referenceID: scene.id,
                channel: .storyScene,
                interaction: .none
            )
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest(content: [atom])]
            inputs.authoredStoryScenes = [scene]
            let raw = try XCTUnwrap(AuthoredStoryScenePageAdapter.candidates(for: day, inputs: inputs, now: now).first)
            let prepared = try XCTUnwrap(MonthlyIssuePageCuration.preparing(
                raw, manifests: inputs.monthlyIssueAuthoringManifests,
                day: day, inputs: inputs, now: now
            ))

            XCTAssertFalse(prepared.isStoryPlayablePage)
            XCTAssertFalse(prepared.pageCapabilities.asksReader)
            XCTAssertTrue(prepared.isAuthoredNarrativeOnlyPage)
            XCTAssertFalse(prepared.isReaderFacingAsk)
            XCTAssertEqual(prepared.leafInvitation?.title, "Unfold the Page")
        }
    }

    func testBleedFreezesAuthoredArticleAndCarriesItsDeliveryReceipt() throws {
        try withDictionaryEntitlement {
            let now = date(2027, 9, 2, 9)
            let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: [])
            let article = AuthoredBleedArticle(
                id: "corridor-ledger",
                packID: "dictionary-rebellion",
                eventID: "dictionary-rebellion",
                title: "Three Verbs Leave Class",
                byline: "Penny Blackletter",
                body: "Three verbs left before attendance. One returned wearing somebody else's tense."
            )
            let atom = contentAtom(
                id: "bleed-atom",
                referenceKind: .bleedArticle,
                referenceID: article.id,
                channel: .bleedArticle
            )
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest(content: [atom])]
            inputs.authoredBleedArticles = [article]

            let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
                for: day,
                inputs: inputs,
                now: now,
                calendar: calendar,
                settingTheType: false
            ))
            XCTAssertTrue(TheBleedEditionBuilder.decodedBriefs(
                announcement.payload.metadata[TheBleedEditionBuilder.authoredBriefsMetadataKey] ?? ""
            ).contains { $0.composedBody == article.body })
            let receipt = try XCTUnwrap(
                announcement.authoredContentReceipts(state: .delivered, at: now)
                    .first(where: { $0.contentID == atom.id })
            )

            inputs.authoredContentReceipts = inputs.authoredContentReceipts.recording(receipt)
            let openedBriefs = TheBleedEditionBuilder.settingTheType(
                for: announcement,
                day: day,
                inputs: inputs,
                now: now,
                calendar: calendar
            )
            XCTAssertTrue(openedBriefs.contains { $0.composedBody == article.body })
        }
    }

    func testRadioAndMarginaliaResolveThroughTheSameOccurrenceLedger() throws {
        try withDictionaryEntitlement {
            let now = date(2027, 9, 2, 20)
            let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: calendar.startOfDay(for: now), pages: [])
            let banter = AuthoredRadioBanter(
                id: "rebellion-break",
                packID: "dictionary-rebellion",
                eventID: "dictionary-rebellion",
                stationID: "fae-fi",
                banter: RadioBanter(
                    id: "rebellion-break",
                    category: .news,
                    assetName: nil,
                    caption: "Two nouns are sitting in the stairwell and refusing all assigned objects.",
                    conditions: nil,
                    weight: 100
                )
            )
            let mark = AuthoredMarginaliaMark(
                id: "stairwell-note",
                packID: "dictionary-rebellion",
                eventID: "dictionary-rebellion",
                assetPackID: CoreMarginsPack.id,
                assetID: "academy_tip_bells",
                tags: ["academy", "schedule"],
                targetPageTypes: [.plainPage]
            )
            let radioAtom = contentAtom(
                id: "radio-atom",
                referenceKind: .radioBanter,
                referenceID: banter.id,
                channel: .radioBanter
            )
            let markAtom = contentAtom(
                id: "mark-atom",
                referenceKind: .marginalia,
                referenceID: mark.id,
                channel: .marginalia
            )
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest(content: [radioAtom, markAtom])]
            inputs.authoredRadioBanters = [banter]
            inputs.authoredMarginaliaMarks = [mark]

            let resolvedRadio = try XCTUnwrap(AuthoredRadioBanterResolver.eligible(
                for: day, inputs: inputs, now: now
            ).first)
            XCTAssertEqual(resolvedRadio.authored.banter.caption, banter.banter.caption)
            let played = resolvedRadio.content.receipt(
                occurrenceID: resolvedRadio.occurrenceID,
                state: .played,
                at: now
            )
            inputs.authoredContentReceipts = inputs.authoredContentReceipts.recording(played)
            XCTAssertTrue(AuthoredRadioBanterResolver.eligible(for: day, inputs: inputs, now: now).isEmpty)

            let plain = surface(id: "ordinary-leaf", type: .plainPage)
            let dressed = MonthlyIssueMarginaliaDresser.dressing(
                [plain], day: day, inputs: inputs, now: now, distressActive: false
            )
            XCTAssertEqual(dressed[0].payload.metadata["authoredMarginaliaAssetID"], mark.assetID)
            let recipe = LeafDecorationLibrary.recipe(
                pageType: .plainPage,
                metadata: dressed[0].payload.metadata,
                semanticText: "The Academy bell rang.",
                documentID: "test-leaf",
                leafIndex: 0
            )
            XCTAssertEqual(recipe.primaryAsset?.id, mark.assetID)
            XCTAssertTrue(dressed[0].authoredContentReceipts(state: .delivered, at: now)
                .contains { $0.contentID == markAtom.id })
        }
    }

    func testSyntheticClockCoversActiveLateAbsentAndLapsedReadersDeterministically() throws {
        let fixture = simulationFixture()
        let start = date(2027, 8, 25, 0)
        let end = date(2027, 10, 8, 0)
        let active = MonthlyIssueSimulationPersona(
            id: "active",
            subscribedFrom: start,
            firstPresentAt: start,
            participatingContentIDs: ["setup-choice"]
        )
        let late = MonthlyIssueSimulationPersona(
            id: "late",
            subscribedFrom: start,
            firstPresentAt: date(2027, 9, 12, 0)
        )
        let absent = MonthlyIssueSimulationPersona(
            id: "absent",
            subscribedFrom: start,
            firstPresentAt: date(2027, 10, 20, 0)
        )
        let lapsed = MonthlyIssueSimulationPersona(
            id: "lapsed",
            subscribedFrom: start,
            subscribedUntil: date(2027, 9, 15, 0),
            firstPresentAt: start
        )

        let activeRun = MonthlyIssueAuthoringSimulator.run(
            pack: fixture.pack, manifestID: fixture.manifest.id,
            persona: active, from: start, through: end,
            sampleHours: [9], calendar: calendar
        )
        let repeatedRun = MonthlyIssueAuthoringSimulator.run(
            pack: fixture.pack, manifestID: fixture.manifest.id,
            persona: active, from: start, through: end,
            sampleHours: [9], calendar: calendar
        )
        XCTAssertEqual(activeRun, repeatedRun)
        XCTAssertTrue(activeRun.finalLifecycleLedger.participated(in: "dictionary-rebellion:2027"))
        XCTAssertTrue(activeRun.frames.contains {
            $0.lifecycleStage == .residue && $0.residueVoice == .receipt
                && $0.eligibleMarginaliaIDs.contains("participant-residue")
        })

        let lateRun = MonthlyIssueAuthoringSimulator.run(
            pack: fixture.pack, manifestID: fixture.manifest.id,
            persona: late, from: start, through: end,
            sampleHours: [9], calendar: calendar
        )
        XCTAssertFalse(lateRun.finalLifecycleLedger.participated(in: "dictionary-rebellion:2027"))
        XCTAssertTrue(lateRun.frames.contains { $0.deliveredContentIDs.contains("buildup-radio") })
        XCTAssertTrue(lateRun.frames.contains {
            $0.lifecycleStage == .residue && $0.residueVoice == .rumor
                && $0.eligibleMarginaliaIDs.contains("rumor-residue")
        })

        let absentRun = MonthlyIssueAuthoringSimulator.run(
            pack: fixture.pack, manifestID: fixture.manifest.id,
            persona: absent, from: start, through: end,
            sampleHours: [9], calendar: calendar
        )
        XCTAssertTrue(absentRun.finalContentLedger.receipts.isEmpty)

        let lapsedRun = MonthlyIssueAuthoringSimulator.run(
            pack: fixture.pack, manifestID: fixture.manifest.id,
            persona: lapsed, from: start, through: end,
            sampleHours: [9], calendar: calendar
        )
        XCTAssertTrue(lapsedRun.frames
            .filter { !$0.subscriptionActive }
            .allSatisfy { $0.deliveredContentIDs.isEmpty })
        XCTAssertFalse(lapsedRun.frames.contains { $0.deliveredContentIDs.contains("climax-article") })
    }

    // MARK: Fixtures

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func withDictionaryEntitlement(_ body: () throws -> Void) throws {
        let saved = PackEntitlements.ownedPackIDs
        PackEntitlements.ownedPackIDs.insert("dictionary-rebellion")
        defer { PackEntitlements.ownedPackIDs = saved }
        try body()
    }

    private func storyScene() -> AuthoredStoryScene {
        AuthoredStoryScene(
            id: "under-the-stairs",
            packID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            title: "The Stair Has An Opinion",
            opening: "The third stair has lifted its lip. It is listening through the floorboards.",
            prompt: "The stair waits. What do you do?",
            detail: "A whole authored scene, with no local scribe required.",
            choices: [
                AuthoredStorySceneChoice(
                    id: "knock", title: "Knock First", prompt: "Use one knuckle.",
                    result: "The stair opens one wooden eye.", consequenceTags: ["stair:trusted"]
                ),
                AuthoredStorySceneChoice(
                    id: "listen", title: "Put Down An Ear", prompt: "Listen before asking.",
                    result: "Something underneath knocks back once, very politely."
                ),
                AuthoredStorySceneChoice(
                    id: "leave-a-pin", title: "Leave A Pin", prompt: "Mark the place and go.",
                    result: "By dusk the pin has become a tiny brass doorknob."
                )
            ],
            entities: ["The third stair"],
            tags: ["stairs", "academy"]
        )
    }

    private func contentAtom(
        id: String,
        referenceKind: MonthlyIssueContentReferenceKind,
        referenceID: String,
        channel: AuthoredContentChannel,
        interaction: MonthlyIssueInteractionKind = .none
    ) -> MonthlyIssueContentAtom {
        MonthlyIssueContentAtom(
            id: id,
            title: id,
            reference: MonthlyIssueContentReference(kind: referenceKind, id: referenceID),
            channel: channel,
            placement: MonthlyIssueContentPlacement(
                lifecycleStage: .live,
                phaseID: "omen",
                phaseRole: .setup
            ),
            interaction: interaction,
            priority: .featured,
            productionStatus: .ready
        )
    }

    private func manifest(content: [MonthlyIssueContentAtom]) -> MonthlyIssueAuthoringManifest {
        MonthlyIssueAuthoringManifest(
            id: "native-content-fixture",
            issueNumber: 0,
            publicationKind: .rehearsal,
            title: "Native Content Fixture",
            eventPackID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            phasePlans: [],
            content: content,
            coverageRequirements: []
        )
    }

    private func surface(id: String, type: BookPageType) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: type)
        return SurfacePage(
            id: id,
            type: type,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: 60,
            reason: "",
            prompt: "An ordinary leaf",
            detail: "",
            payload: BookPagePayload(
                headline: "Ordinary Leaf",
                body: "The leaf is minding its own business.",
                metadata: ["source": source.id, "tags": "academy,class"]
            )
        )
    }

    private func simulationFixture() -> (pack: WorldEventPack, manifest: MonthlyIssueAuthoringManifest) {
        let setupScene = storyScene()
        let radio = AuthoredRadioBanter(
            id: "buildup-radio-object",
            packID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            stationID: "fae-fi",
            banter: RadioBanter(
                id: "buildup-radio-object", category: .news, assetName: nil,
                caption: "The verbs have reached the landing.", conditions: nil, weight: 1
            )
        )
        let article = AuthoredBleedArticle(
            id: "climax-article-object",
            packID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            title: "Assembly Calls Itself To Order",
            byline: "Penny Blackletter",
            body: "Order objected to the wording and left."
        )
        let participantMark = AuthoredMarginaliaMark(
            id: "participant-mark-object",
            packID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            assetPackID: CoreMarginsPack.id,
            assetID: "marginalia_goblin_sealed_note"
        )
        let rumorMark = AuthoredMarginaliaMark(
            id: "rumor-mark-object",
            packID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            assetPackID: CoreMarginsPack.id,
            assetID: "marginalia_goblin_questioning"
        )
        let content = [
            MonthlyIssueContentAtom(
                id: "setup-choice", title: "Setup choice",
                reference: MonthlyIssueContentReference(kind: .storyScene, id: setupScene.id),
                channel: .storyScene,
                placement: MonthlyIssueContentPlacement(lifecycleStage: .live, phaseID: "omen", phaseRole: .setup),
                interaction: .choice,
                priority: .spine,
                productionStatus: .ready
            ),
            MonthlyIssueContentAtom(
                id: "buildup-radio", title: "Buildup radio",
                reference: MonthlyIssueContentReference(kind: .radioBanter, id: radio.id),
                channel: .radioBanter,
                placement: MonthlyIssueContentPlacement(lifecycleStage: .live, phaseID: "outbreak", phaseRole: .buildup),
                priority: .featured,
                productionStatus: .ready
            ),
            MonthlyIssueContentAtom(
                id: "climax-article", title: "Climax article",
                reference: MonthlyIssueContentReference(kind: .bleedArticle, id: article.id),
                channel: .bleedArticle,
                placement: MonthlyIssueContentPlacement(lifecycleStage: .live, phaseID: "assembly", phaseRole: .climax),
                priority: .featured,
                productionStatus: .ready
            ),
            MonthlyIssueContentAtom(
                id: "participant-residue", title: "Participant residue",
                reference: MonthlyIssueContentReference(kind: .marginalia, id: participantMark.id),
                channel: .marginalia,
                placement: MonthlyIssueContentPlacement(lifecycleStage: .residue),
                audience: .participants,
                voice: .participantReceipt,
                productionStatus: .ready
            ),
            MonthlyIssueContentAtom(
                id: "rumor-residue", title: "Rumor residue",
                reference: MonthlyIssueContentReference(kind: .marginalia, id: rumorMark.id),
                channel: .marginalia,
                placement: MonthlyIssueContentPlacement(lifecycleStage: .residue),
                audience: .nonparticipants,
                voice: .nonparticipantRumor,
                productionStatus: .ready
            )
        ]
        let manifest = MonthlyIssueAuthoringManifest(
            id: "simulation-fixture",
            issueNumber: 0,
            publicationKind: .rehearsal,
            title: "Simulation Fixture",
            eventPackID: "dictionary-rebellion",
            eventID: "dictionary-rebellion",
            phasePlans: [],
            content: content,
            coverageRequirements: []
        )
        let pack = WorldEventPack(
            id: "dictionary-rebellion",
            displayName: "Simulation Fixture",
            version: 1,
            author: "Tests",
            availability: .bundledFree,
            events: [WorldEventRegistry.dictionaryRebellion],
            authoringManifests: [manifest],
            storyScenes: [setupScene],
            radioBanters: [radio],
            bleedArticles: [article],
            marginalia: [participantMark, rumorMark]
        )
        return (pack, manifest)
    }
}
