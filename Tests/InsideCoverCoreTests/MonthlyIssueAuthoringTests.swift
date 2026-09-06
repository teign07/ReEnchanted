import XCTest
@testable import InsideCoverCore

final class MonthlyIssueAuthoringTests: XCTestCase {
    func testCompleteManifestPassesReleaseValidationAndCodableRoundTrip() throws {
        let fixture = makeFixture()
        let report = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )

        XCTAssertTrue(report.isValid, report.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(report.warnings.isEmpty)

        let data = try JSONEncoder().encode(fixture.manifest)
        let decoded = try JSONDecoder().decode(MonthlyIssueAuthoringManifest.self, from: data)
        XCTAssertEqual(decoded, fixture.manifest)
        XCTAssertEqual(decoded.releaseContent.count, 4)

        var embeddedPack = fixture.pack
        embeddedPack.authoringManifests = [fixture.manifest]
        let packData = try JSONEncoder().encode(embeddedPack)
        let decodedPack = try JSONDecoder().decode(WorldEventPack.self, from: packData)
        XCTAssertEqual(decodedPack.authoringManifests, [fixture.manifest])
    }

    func testWorkingManifestWarnsButReleaseManifestRejectsUnfinishedRequiredContent() {
        var fixture = makeFixture()
        fixture.manifest.content[0].productionStatus = .draft

        let working = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .working
        )
        XCTAssertTrue(working.isValid)
        XCTAssertTrue(working.contains(.incompleteRequiredContent))
        XCTAssertTrue(working.contains(.coverageBelowMinimum))

        let release = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertFalse(release.isValid)
        XCTAssertTrue(release.contains(.incompleteRequiredContent))
        XCTAssertTrue(release.contains(.missingPhaseOpening))
        XCTAssertTrue(release.contains(.coverageBelowMinimum))
    }

    func testDuplicateNativePayloadIDsAreRejectedBeforeRuntimeIndexing() {
        var fixture = makeFixture()
        let scene = AuthoredStoryScene(
            id: "same-scene",
            packID: fixture.pack.id,
            eventID: fixture.manifest.eventID,
            title: "The Same Door Twice",
            opening: "The door has copied itself.",
            prompt: "Look at both hinges.",
            detail: "They have the same scratches. That will not do."
        )
        fixture.pack.storyScenes = [scene, scene]

        let report = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.contains(.duplicateNativeContentID))
    }

    func testResidueCannotPretendAnUnreceiptedEndingOrAcceptParticipation() {
        var fixture = makeFixture()
        fixture.manifest.content.append(MonthlyIssueContentAtom(
            id: "residue-amendment",
            title: "An Amendment in Wet Ink",
            reference: MonthlyIssueContentReference(kind: .marginalia, id: "residue-amendment"),
            channel: .marginalia,
            placement: MonthlyIssueContentPlacement(lifecycleStage: .residue),
            audience: .everyone,
            voice: .immediate,
            interaction: .choice,
            priority: .ambient,
            productionStatus: .ready
        ))

        let unsafe = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertTrue(unsafe.contains(.unsafeNonliveContent))
        XCTAssertTrue(unsafe.contains(.unsafeAudienceVoice))

        fixture.manifest.content[4].voice = .publicReport
        fixture.manifest.content[4].interaction = .none
        fixture.pack.marginalia = [AuthoredMarginaliaMark(
            id: "residue-amendment",
            packID: fixture.pack.id,
            eventID: fixture.manifest.eventID,
            assetPackID: CoreMarginsPack.id,
            assetID: "marginalia_goblin_sealed_note"
        )]
        let safe = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertTrue(safe.isValid, safe.diagnostics.map(\.message).joined(separator: "\n"))
    }

    func testDependenciesMustBeDeclaredAcyclicAndNotComeFromTheFuture() {
        var fixture = makeFixture()
        fixture.manifest.content[0].dependencies = [
            AuthoredContentDependency(contentID: "ordinary-page")
        ]
        let missing = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertTrue(missing.contains(.missingDependency))

        fixture.manifest.externalContentIDs = ["ordinary-page"]
        let declared = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertTrue(declared.isValid, declared.diagnostics.map(\.message).joined(separator: "\n"))

        fixture.manifest.content[0].dependencies = [
            AuthoredContentDependency(contentID: fixture.manifest.content[1].id)
        ]
        fixture.manifest.content[1].dependencies = [
            AuthoredContentDependency(contentID: fixture.manifest.content[0].id)
        ]
        let cyclic = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertTrue(cyclic.contains(.futureDependency))
        XCTAssertTrue(cyclic.contains(.dependencyCycle))
    }

    func testCoverageRowsEnforceTheDeclaredBudgetAndForeshadowStaysThin() {
        var fixture = makeFixture()
        fixture.manifest.coverageRequirements.append(MonthlyIssueCoverageRequirement(
            id: "fieldwork",
            label: "Field invitations",
            channel: .page,
            lifecycleStage: .live,
            interactions: [.fieldMission],
            tagsAll: ["fieldwork"],
            minimumReady: 1,
            maximumReady: 1
        ))
        for index in 1...3 {
            fixture.manifest.content.append(MonthlyIssueContentAtom(
                id: "foreshadow-\(index)",
                title: "Foreshadow Hint \(index)",
                reference: MonthlyIssueContentReference(kind: .marginalia, id: "foreshadow-\(index)"),
                channel: .marginalia,
                placement: MonthlyIssueContentPlacement(lifecycleStage: .foreshadow),
                priority: .ambient,
                productionStatus: .ready
            ))
        }

        let report = MonthlyIssueAuthoringValidator.validate(
            fixture.manifest,
            against: fixture.pack,
            mode: .release
        )
        XCTAssertTrue(report.contains(.coverageBelowMinimum))
        XCTAssertTrue(report.contains(.tooManyForeshadowHints))
    }

    func testOrphanedIssueOfferIsWithheldWhenManifestDisappears() throws {
        let fixture = makeFixture()
        let now = date(year: 2027, month: 9, day: 10, hour: 10)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: fixture.pack.id, event: fixture.pack.events[0], now: now))
        let beat = try XCTUnwrap(fixture.pack.events[0].beats?.first)
        let ordinary = WorldEventPageSourceAdapter.beatSurface(
            event: fixture.pack.events[0], beat: beat, snapshot: snapshot, day: day)
        let issue = ordinary.withMetadata([MonthlyIssuePageMetadata.issueID: "retired-issue"])
        XCTAssertNil(MonthlyIssuePageCuration.preparing(issue, manifests: [],
            day: day, inputs: .empty, now: now))
        XCTAssertNotNil(MonthlyIssuePageCuration.preparing(ordinary, manifests: [],
            day: day, inputs: .empty, now: now))
        XCTAssertEqual(MonthlyIssuePageCuration.preparing([ordinary, issue], manifests: [],
            day: day, inputs: .empty, now: now).map(\.id), [ordinary.id])
    }

    func testReadyPageAtomWaitsForDependencyThenRetiresFromItsDeliveryReceipt() throws {
        let savedOwned = PackEntitlements.ownedPackIDs
        PackEntitlements.ownedPackIDs.insert("dictionary-rebellion")
        defer { PackEntitlements.ownedPackIDs = savedOwned }

        var fixture = makeFixture()
        let contentIndex = try XCTUnwrap(fixture.manifest.content.firstIndex {
            $0.reference.id == "first-negotiation"
        })
        fixture.manifest.content[contentIndex].channel = .page
        fixture.manifest.content[contentIndex].dependencies = [
            AuthoredContentDependency(contentID: "setup-receipt")
        ]
        let now = date(year: 2027, month: 9, day: 10, hour: 10)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: fixture.pack.id,
            event: fixture.pack.events[0],
            now: now
        ))
        let beat = try XCTUnwrap(fixture.pack.events[0].beats?.first {
            $0.id == "first-negotiation"
        })
        let surface = WorldEventPageSourceAdapter.beatSurface(
            event: fixture.pack.events[0],
            beat: beat,
            snapshot: snapshot,
            day: day
        )
        var inputs = BookSourceInputs.empty
        inputs.monthlyIssueAuthoringManifests = [fixture.manifest]

        XCTAssertNil(MonthlyIssuePageCuration.preparing(
            surface,
            manifests: inputs.monthlyIssueAuthoringManifests,
            day: day,
            inputs: inputs,
            now: now
        ))

        inputs.authoredContentReceipts = inputs.authoredContentReceipts.recording(
            AuthoredContentReceipt(
                contentID: "setup-receipt",
                occurrenceID: "setup-once",
                channel: .page,
                scope: AuthoredContentScope(
                    scopeID: fixture.manifest.id,
                    runID: snapshot.runID,
                    phaseID: snapshot.phaseID
                ),
                state: .delivered,
                recordedAt: now.addingTimeInterval(-60)
            )
        )
        let prepared = try XCTUnwrap(MonthlyIssuePageCuration.preparing(
            surface,
            manifests: inputs.monthlyIssueAuthoringManifests,
            day: day,
            inputs: inputs,
            now: now
        ))
        XCTAssertEqual(prepared.payload.metadata[MonthlyIssuePageMetadata.contentID], "opening-outbreak")
        XCTAssertEqual(prepared.authoredIssuePriority, .spine)
        XCTAssertTrue(prepared.mayReserveAuthoredIssueSlot)
        XCTAssertEqual(prepared.score, surface.score + MonthlyIssueContentPriority.spine.curatorScoreLift)

        let delivered = try XCTUnwrap(prepared.authoredContentDeliveryReceipt(servedAt: now))
        inputs.authoredContentReceipts = inputs.authoredContentReceipts.recording(delivered)
        XCTAssertNil(MonthlyIssuePageCuration.preparing(
            surface,
            manifests: inputs.monthlyIssueAuthoringManifests,
            day: day,
            inputs: inputs,
            now: now.addingTimeInterval(60)
        ))
    }

    func testLiveSpineMayClaimOneOrdinaryChairButNotTheReadersProtectedDesk() throws {
        let savedOwned = PackEntitlements.ownedPackIDs
        PackEntitlements.ownedPackIDs.insert("dictionary-rebellion")
        defer { PackEntitlements.ownedPackIDs = savedOwned }

        var fixture = makeFixture()
        let contentIndex = try XCTUnwrap(fixture.manifest.content.firstIndex {
            $0.reference.id == "first-negotiation"
        })
        fixture.manifest.content[contentIndex].channel = .page
        let now = date(year: 2027, month: 9, day: 10, hour: 10)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: fixture.pack.id,
            event: fixture.pack.events[0],
            now: now
        ))
        let beat = try XCTUnwrap(fixture.pack.events[0].beats?.first {
            $0.id == "first-negotiation"
        })
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.monthlyIssueAuthoringManifests = [fixture.manifest]
        let claim = try XCTUnwrap(MonthlyIssuePageCuration.preparing(
            WorldEventPageSourceAdapter.beatSurface(
                event: fixture.pack.events[0],
                beat: beat,
                snapshot: snapshot,
                day: day
            ),
            manifests: inputs.monthlyIssueAuthoringManifests,
            day: day,
            inputs: inputs,
            now: now
        ))
        let context = CuratorContext.make(for: day)
        let ordinary = [
            deskPage("ordinary-weather", type: .weather),
            deskPage("ordinary-fuel", type: .fuel),
            deskPage("ordinary-lore", type: .lore)
        ]
        let claimed = BookCurator.reservingAuthoredIssuePageIfOwed(
            in: ordinary,
            candidates: [claim],
            day: day,
            inputs: inputs,
            context: context,
            preferences: .none,
            mood: CuratorMood.make(inputs: inputs, now: now),
            now: now,
            limit: 3
        )
        XCTAssertTrue(claimed.prefix(3).contains { $0.id == claim.id })
        XCTAssertEqual(claimed.filter(\.belongsToAuthoredIssue).count, 1)

        let protected = [
            deskPage("reader-braid", type: .bookOfYou),
            deskPage("earned-milestone", type: .lore).withMetadata(["milestone": "true"]),
            deskPage("only-way-out", type: .wonderCompass).withMetadata([
                "deskJob": DeskJob.errand.rawValue
            ])
        ]
        let unchanged = BookCurator.reservingAuthoredIssuePageIfOwed(
            in: protected,
            candidates: [claim],
            day: day,
            inputs: inputs,
            context: context,
            preferences: .none,
            mood: CuratorMood.make(inputs: inputs, now: now),
            now: now,
            limit: 3
        )
        XCTAssertEqual(unchanged.map(\.id), protected.map(\.id))

        let claimKey = try XCTUnwrap(
            claim.payload.metadata[MonthlyIssuePageMetadata.claimHistoryKey]
        )
        inputs.surfaceHistory[claimKey] = SurfaceHistoryRecord(
            lastShownAt: now,
            recentShowCount: 1
        )
        let rested = BookCurator.reservingAuthoredIssuePageIfOwed(
            in: ordinary,
            candidates: [claim],
            day: day,
            inputs: inputs,
            context: context,
            preferences: .none,
            mood: CuratorMood.make(inputs: inputs, now: now),
            now: now,
            limit: 3
        )
        XCTAssertFalse(rested.contains { $0.id == claim.id })
    }

    func testRankedPublishedBlockContainsAtMostOneMonthlyIssuePage() {
        let issueMetadata = [MonthlyIssuePageMetadata.issueID: "issue-one"]
        let pages = [
            deskPage("issue-weather", type: .weather, score: 100).withMetadata(issueMetadata),
            deskPage("issue-body", type: .body, score: 99).withMetadata(issueMetadata),
            deskPage("ordinary-fuel", type: .fuel, score: 98),
            deskPage("ordinary-mood", type: .mood, score: 97),
            deskPage("ordinary-calendar", type: .calendar, score: 96)
        ]
        let ranked = BookCurator.rankedPages(
            from: pages,
            limit: 3,
            preferences: .none,
            mood: .neutral,
            now: date(year: 2026, month: 8, day: 24, hour: 10)
        ).map(\.page)

        XCTAssertEqual(ranked.count, 3)
        XCTAssertLessThanOrEqual(ranked.filter(\.belongsToAuthoredIssue).count, 1)
    }

    func testManifestPriorityReachesTheRealCuratorCandidatePoolAndVisibleDesk() throws {
        let savedOwned = PackEntitlements.ownedPackIDs
        PackEntitlements.ownedPackIDs.insert("dictionary-rebellion")
        defer { PackEntitlements.ownedPackIDs = savedOwned }

        var fixture = makeFixture()
        let contentIndex = try XCTUnwrap(fixture.manifest.content.firstIndex {
            $0.reference.id == "first-negotiation"
        })
        fixture.manifest.content[contentIndex].channel = .page
        let now = date(year: 2027, month: 9, day: 10, hour: 10)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.monthlyIssueAuthoringManifests = [fixture.manifest]

        let pool = BookCurator.candidatePool(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let authored = try XCTUnwrap(pool.first {
            $0.payload.metadata[MonthlyIssuePageMetadata.contentID] == "opening-outbreak"
        })
        XCTAssertTrue(authored.mayReserveAuthoredIssueSlot)

        let desk = BookCurator.surfacedPages(
            for: day,
            inputs: inputs,
            now: now,
            limit: 9
        )
        XCTAssertTrue(desk.prefix(3).contains { $0.id == authored.id }, desk.map(\.id).description)
        XCTAssertLessThanOrEqual(desk.filter(\.belongsToAuthoredIssue).count, 1)
    }

    private func deskPage(
        _ id: String,
        type: BookPageType,
        score: Int = 60
    ) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: "source-\(id)",
            score: score,
            prompt: id,
            detail: "A Page on the desk."
        )
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func makeFixture() -> (manifest: MonthlyIssueAuthoringManifest, pack: WorldEventPack) {
        let event = WorldEventRegistry.dictionaryRebellion
        let pack = WorldEventPack(
            id: "dictionary-rebellion",
            displayName: "The Dictionary Rebellion",
            version: 1,
            author: "The Book",
            availability: .bundledFree,
            events: [event]
        )
        let phaseTriples: [(WorldEventPhaseRole, String, String)] = [
            (.setup, "omen", "roll-call-slips"),
            (.buildup, "outbreak", "first-negotiation"),
            (.climax, "assembly", "thesaurus-assembly"),
            (.aftermath, "afterimage", "new-definitions-dry")
        ]
        let content = phaseTriples.map { role, phaseID, beatID in
            MonthlyIssueContentAtom(
                id: "opening-\(phaseID)",
                title: "Opening: \(phaseID)",
                reference: MonthlyIssueContentReference(kind: .worldEventBeat, id: beatID),
                channel: .storyScene,
                placement: MonthlyIssueContentPlacement(
                    lifecycleStage: .live,
                    phaseID: phaseID,
                    phaseRole: role
                ),
                priority: .spine,
                productionStatus: .ready,
                tags: ["phase-opening"]
            )
        }
        let plans = phaseTriples.map { role, phaseID, _ in
            MonthlyIssuePhasePlan(
                phaseID: phaseID,
                role: role,
                openingContentID: "opening-\(phaseID)",
                directionPacketID: "direction-\(phaseID)",
                directionStatus: .ready
            )
        }
        let manifest = MonthlyIssueAuthoringManifest(
            id: "dictionary-rebellion-public",
            issueNumber: 1,
            publicationKind: .publicIssue,
            title: "The Dictionary Rebellion",
            eventPackID: pack.id,
            eventID: event.id,
            phasePlans: plans,
            content: content,
            coverageRequirements: [
                MonthlyIssueCoverageRequirement(
                    id: "phase-openings",
                    label: "Shared phase openings",
                    channel: .storyScene,
                    lifecycleStage: .live,
                    priorities: [.spine, .milestone],
                    tagsAll: ["phase-opening"],
                    minimumReady: 4,
                    maximumReady: 4
                )
            ]
        )
        return (manifest, pack)
    }
}
