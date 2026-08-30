import XCTest
@testable import InsideCoverCore

final class MonthlyIssueNativeContentTests: XCTestCase {
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
