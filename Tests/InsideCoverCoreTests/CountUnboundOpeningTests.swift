import XCTest
@testable import InsideCoverCore

final class CountUnboundOpeningTests: XCTestCase {
    private let jumpID = "count-unbound.scene.sunday-jump"
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c
    }
    private func date(_ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 9))! }
    private func pack() throws -> WorldEventPack {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
    }
    func testOpeningDecodesAndValidationAcceptsCompletedContent() throws {
        let p = try pack()
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        let report = MonthlyIssueAuthoringValidator.validate(manifest, against: p, mode: .working)
        XCTAssertTrue(report.errors.isEmpty, "\(report)")
        XCTAssertTrue(report.warnings.isEmpty, "\(report)")
        let release = MonthlyIssueAuthoringValidator.validate(manifest, against: p, mode: .release)
        XCTAssertTrue(release.isValid, "\(release)")
        XCTAssertEqual(manifest.phasePlans.map(\.role), WorldEventPhaseRole.allCases)
        let event = try XCTUnwrap(p.events.first)
        XCTAssertTrue(event.phases.allSatisfy { $0.scene?.contains("Use only encountered authored scenes") == false })
        XCTAssertFalse(event.packet.logline.contains("leaves something unaccounted for"))
        XCTAssertEqual(p.storyScenes?.count, 22)
        XCTAssertEqual(p.bleedArticles?.count, 4)
        XCTAssertEqual(event.beats?.filter { $0.pageType == .letter }.count, 2)
        XCTAssertEqual(event.beats?.filter { $0.pageType == .academyClass }.count, 4)
        XCTAssertEqual(event.beats?.filter { $0.resolvedLifecycleStage == .residue }.count, 2)

        var missingOpening = p
        missingOpening.storyScenes?.removeAll { $0.id == "count-unbound.scene.wrong-castle" }
        let broken = MonthlyIssueAuthoringValidator.validate(manifest, against: missingOpening, mode: .release)
        XCTAssertTrue(broken.errors.contains { $0.code == .missingPhaseBeat && $0.subjectID == "climax" })
    }

    func testNovemberOccasionCarriesOnlySerenitysOctoberSuggestion() throws {
        let scene = try XCTUnwrap(try pack().storyScenes?.first {
            $0.id == "count-unbound.relationship.november-occasion"
        })
        XCTAssertTrue(AuthoredStoryProgress.diagnostics(for: scene).isEmpty)
        let scope = AuthoredContentScope(scopeID: "count-unbound-october-2026", runID: "count-unbound:2026")
        for route in ["soren-roof", "wicker-conversation", "own-evening"] {
            let october = AuthoredContentReceipt(contentID: "count-unbound.relationship.after-lesson",
                occurrenceID: "october-choice", channel: .storyScene, scope: scope,
                state: .nodeCompleted, recordedAt: date(31), choiceID: route,
                nodeID: "count-unbound.relationship.after-lesson.suggestion")
            let ledger = AuthoredContentReceiptLedger.empty.recording(october)
            let entry = try XCTUnwrap(AuthoredStoryProgress.currentNode(scene: scene,
                contentID: scene.id, scope: scope, ledger: ledger))
            XCTAssertEqual(entry.choices.map(\.id), [route])
        }
        var unsafe = try pack()
        let manifestIndex = try XCTUnwrap(unsafe.authoringManifests?.firstIndex {
            $0.id == "count-unbound-october-2026"
        })
        let atomIndex = try XCTUnwrap(unsafe.authoringManifests?[manifestIndex].content.firstIndex {
            $0.id == "count-unbound.relationship.november-occasion"
        })
        unsafe.authoringManifests![manifestIndex].content[atomIndex].dependencies = []
        let report = MonthlyIssueAuthoringValidator.validate(unsafe.authoringManifests![manifestIndex],
            against: unsafe, mode: .working)
        XCTAssertTrue(report.errors.contains { $0.code == .unsafeNonliveContent })
    }

    func testReturnRelicNeedsEncounteredMethodAndAnEarlierLivedFinding() throws {
        let p = try pack()
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        let scope = AuthoredContentScope(scopeID: manifest.id, runID: "count-unbound:2026")
        let event = AuthoredContentWorldEventContext(eventID: "count-unbound", packID: p.id,
            runID: scope.runID, phaseID: "nightbound", phaseTitle: "Nightbound", phaseRole: .aftermath,
            lifecycleStage: .live, activationMode: nil, liveDay: 29, touchCount: 1)
        let completed = AuthoredContentReceipt(contentID: "count-unbound.scene.future-tense",
            occurrenceID: "ending", channel: .storyScene, scope: scope,
            state: .completed, recordedAt: date(29))
        let route = AuthoredContentReceipt(contentID: "count-unbound.scene.future-tense",
            occurrenceID: "route", channel: .storyScene, scope: scope, state: .nodeCompleted,
            recordedAt: date(29), choiceID: "rule", nodeID: "count-unbound.scene.future-tense.choose")
        let finding = AuthoredContentReceipt(contentID: "count-unbound.mission.other-side",
            occurrenceID: "return", channel: .storyScene, scope: scope, state: .completed,
            recordedAt: date(20), evidencePageIDs: ["kept-finding"])
        let atoms = manifest.content.filter { $0.id.hasPrefix("count-unbound.relic.") }
        XCTAssertEqual(atoms.count, 3)
        func offered(_ ledger: AuthoredContentReceiptLedger) -> [String] {
            let context = AuthoredContentGateContext(now: date(30), worldEvents: [event],
                receiptLedger: ledger, contentScope: scope)
            return atoms.filter { $0.gate.allows(in: context, contentID: $0.id)
                && $0.dependencies.allSatisfy { $0.isSatisfied(in: ledger, currentScope: scope, now: date(30)) }
                }.map(\.id)
        }
        let ending = AuthoredContentReceiptLedger.empty.recording(completed).recording(route)
        XCTAssertTrue(offered(ending).isEmpty)
        XCTAssertEqual(offered(ending.recording(finding)), ["count-unbound.relic.two-sided-bookmark"])
        XCTAssertTrue(offered(AuthoredContentReceiptLedger.empty.recording(route).recording(finding)).isEmpty)
    }

    func testSmallMediaUsesNativePagesAndTruthfulWindows() throws {
        let p = try pack()
        let event = try XCTUnwrap(p.events.first)
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        let setup = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: p.id, event: event, now: date(4), calendar: calendar))
        let roster = try XCTUnwrap(event.beats?.first { $0.id == "count-unbound.class.book-jumping-roster" })
        let page = WorldEventPageSourceAdapter.beatSurface(
            event: event, beat: roster, snapshot: setup,
            day: BookDay(id: BookDay.id(for: date(4), calendar: calendar), date: date(4), pages: []))
        XCTAssertEqual(page.type, .academyClass)
        XCTAssertEqual(page.payload.metadata["worldEventBeatIDs"], roster.id)
        XCTAssertTrue(page.payload.body.contains("Penny checks"))
        XCTAssertFalse(page.isStoryPlayablePage, "The class folio must show the authored vignette instead of a generated lesson")

        let letter = try XCTUnwrap(event.beats?.first { $0.id == "count-unbound.letter.permancer" })
        XCTAssertEqual(letter.pageType, .letter)
        XCTAssertTrue(letter.body.contains("—Permancer"))
        let publicReport = try XCTUnwrap(p.bleedArticles?.first { $0.id == "count-unbound.bleed.jump-complete" })
        XCTAssertTrue(publicReport.body.contains("Every registered entrant"))
        XCTAssertFalse(publicReport.body.contains("you returned"))

        for id in ["count-unbound.bleed.jump-complete", "count-unbound.bleed.east-stacks",
                   "count-unbound.bleed.several-places", "count-unbound.bleed.count-returned"] {
            let atom = try XCTUnwrap(manifest.content.first { $0.id == id })
            XCTAssertEqual(atom.channel, .bleedArticle)
            XCTAssertEqual(atom.voice, .publicReport)
            XCTAssertEqual(atom.productionStatus, .ready)
        }
        for id in ["count-unbound.residue.protocol-amendment", "count-unbound.residue.route-receipt"] {
            let atom = try XCTUnwrap(manifest.content.first { $0.id == id })
            XCTAssertEqual(atom.placement.lifecycleStage, .residue)
            XCTAssertEqual(atom.voice, .publicReport)
            XCTAssertEqual(atom.interaction, .none)
        }
    }

    func testOtherSideFindingAppearsOnceInEachPreparationWithoutInventedEvidence() throws {
        let p = try pack()
        let strategy = try XCTUnwrap(p.storyScenes?.first { $0.id == "count-unbound.strategy" })
        let afters = try XCTUnwrap(strategy.nodes).filter { $0.id.hasSuffix(".after") }
        XCTAssertEqual(afters.count, 3)
        let scope = AuthoredContentScope(scopeID: "count-unbound-october-2026",
                                         runID: "count-unbound-2026", phaseID: "uninvited")
        let page = BookPage(id: "other-side-finding", type: .narrativeOS,
                            promptText: "Look again", userInput: "The Book asked me.",
                            playerReply: "The blue cup has a chip on the back.", origin: .generated)
        let receipt = AuthoredContentReceipt(contentID: "count-unbound.mission.other-side",
            occurrenceID: "other-side-return", channel: .storyScene, scope: scope,
            state: .completed, recordedAt: date(19), evidencePageIDs: [page.id])
        let ledger = AuthoredContentReceiptLedger(receipts: [receipt])
        for node in afters {
            let insertion = try XCTUnwrap(node.findingInsertion)
            XCTAssertEqual(node.body.components(separatedBy: insertion.marker).count, 2, node.id)
            XCTAssertTrue(insertion.render(scope: scope, ledger: ledger, pages: [page])
                .contains("The blue cup has a chip on the back."), node.id)
            XCTAssertFalse(insertion.render(scope: scope, ledger: .empty, pages: [page])
                .contains("The blue cup"), node.id)
            XCTAssertTrue(insertion.fallback.contains("Penny turns a catalogue card over"), node.id)
        }
    }

    func testBleedLettersClassesAndResidueFollowTheirCalendar() throws {
        let p = try pack()
        let event = try XCTUnwrap(p.events.first)
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        func IDs(_ date: Date, channel: AuthoredContentChannel,
                 kind: MonthlyIssueContentReferenceKind) throws -> Set<String> {
            let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
                packID: p.id, event: event, now: date, calendar: calendar))
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest]
            let day = BookDay(id: BookDay.id(for: date, calendar: calendar), date: date, pages: [])
            return Set(MonthlyIssueContentResolver.eligible(
                channel: channel, referenceKind: kind, day: day, inputs: inputs,
                now: date, lifecycleOverride: [snapshot]).map { $0.atom.id })
        }
        XCTAssertTrue(try IDs(date(4), channel: .page, kind: .worldEventBeat)
            .contains("count-unbound.class.book-jumping-roster"))
        XCTAssertFalse(try IDs(date(8), channel: .page, kind: .worldEventBeat)
            .contains("count-unbound.class.book-jumping-roster"))
        XCTAssertTrue(try IDs(date(16), channel: .page, kind: .worldEventBeat)
            .contains("count-unbound.letter.permancer"))
        XCTAssertFalse(try IDs(date(4), channel: .bleedArticle, kind: .bleedArticle)
            .contains("count-unbound.bleed.jump-complete"))
        XCTAssertTrue(try IDs(date(5), channel: .bleedArticle, kind: .bleedArticle)
            .contains("count-unbound.bleed.jump-complete"))
        XCTAssertFalse(try IDs(date(22), channel: .bleedArticle, kind: .bleedArticle)
            .contains("count-unbound.bleed.several-places"))
        XCTAssertTrue(try IDs(date(23), channel: .bleedArticle, kind: .bleedArticle)
            .contains("count-unbound.bleed.several-places"))
        let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9))!
        XCTAssertTrue(try IDs(november, channel: .page, kind: .worldEventBeat)
            .contains("count-unbound.residue.protocol-amendment"))
        let residueSnapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: p.id, event: event, now: november, calendar: calendar))
        XCTAssertNil(WorldEventResolver.reportBundle(for: event, snapshot: residueSnapshot,
                                                    ledger: .empty))
        let sealed = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 9))!
        XCTAssertFalse(try IDs(sealed, channel: .page, kind: .worldEventBeat)
            .contains("count-unbound.residue.protocol-amendment"))
        let casebookDay = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 9))!
        XCTAssertEqual(WorldEventResolver.lifecycleSnapshot(packID: p.id, event: event,
            now: casebookDay, calendar: calendar)?.stage, .casebookAvailable)
    }

    func testPublicCasebookKeepsAuthoredHistoryBesidePrivateReceipt() throws {
        let p = try pack()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let publicRecord = try ContentPackFileLocator.decoder().decode(WorldEventCasebook.self,
            from: Data(contentsOf: root.appendingPathComponent(
                "ContentPacks/count-unbound/public-record.reenchantedcasebook.json")))
        XCTAssertEqual(publicRecord.runID, "count-unbound:2026")
        XCTAssertEqual(publicRecord.entries.count, 6)
        XCTAssertFalse(publicRecord.isPersonalized)
        XCTAssertTrue(publicRecord.evidencePageIDs.isEmpty)
        let when = calendar.date(from: DateComponents(year: 2026, month: 12, day: 2, hour: 9))!
        var local = publicRecord
        local.id = "casebook:count-unbound:2026"
        local.subtitle = "The public record, with this Book's receipt tucked inside."
        local.historySentence = "A sparse local fallback."
        local.entries = []
        local.residueVoice = .receipt
        local.evidencePageIDs = ["reader-page"]
        local.isPersonalized = true
        let merged = try XCTUnwrap(WorldEventCasebookRegistry.available(
            local: [local], downloaded: [publicRecord], now: when,
            hasMonthlyAccess: true).first)
        XCTAssertEqual(merged.entries, publicRecord.entries)
        XCTAssertEqual(merged.historySentence, publicRecord.historySentence)
        XCTAssertEqual(merged.evidencePageIDs, ["reader-page"])
        XCTAssertEqual(merged.residueVoice, .receipt)
        XCTAssertTrue(merged.isPersonalized)

        local.isPersonalized = false
        local.evidencePageIDs = []
        XCTAssertEqual(WorldEventCasebookRegistry.available(local: [local],
            downloaded: [publicRecord], now: when, hasMonthlyAccess: true).first?.entries,
            publicRecord.entries)
        let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(
            packID: p.id, event: try XCTUnwrap(p.events.first), now: when, calendar: calendar))
        let frozen = WorldEventCasebookBuilder.build(packID: p.id,
            event: try XCTUnwrap(p.events.first), snapshot: snapshot,
            ledger: .empty, outcome: nil)
        XCTAssertFalse(frozen.isPersonalized)
        XCTAssertTrue(frozen.entries.isEmpty)
        XCTAssertFalse(frozen.historySentence.isEmpty)
    }

    func testOctoberMarginaliaAndRadioProductionHandoff() throws {
        let p = try pack()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/count-unbound")
        let margins = try ContentPackFileLocator.decoder().decode(PageArchetypePack.self,
            from: Data(contentsOf: root.appendingPathComponent("margins.reenchantedpack.json")))
        let assets = try XCTUnwrap(margins.marginaliaPack)
        let marks = try XCTUnwrap(p.marginalia)
        let radios = try XCTUnwrap(p.radioBanters)
        let atoms = try XCTUnwrap(p.authoringManifests?.first?.content)
        XCTAssertEqual(marks.count, 8)
        XCTAssertEqual(radios.count, 5)
        // Eight directed marks for the story, plus twenty seasonal October doodles.
        XCTAssertEqual(assets.doodles.count, 28)
        XCTAssertEqual(assets.doodles.filter(\.directedOnly).count, 8)
        XCTAssertNil(IlluminationAssetResolver().resolveAsset(kind: .doodle,
            tags: ["count-unbound"], template: nil, installedPacks: [assets]))
        for mark in marks {
            let asset = try XCTUnwrap(assets.doodles.first { $0.id == mark.assetID })
            XCTAssertEqual(mark.assetPackID, assets.id)
            XCTAssertTrue(asset.directedOnly)
            XCTAssertTrue(asset.assetName.hasPrefix("{{asset-path:count-unbound.mark."))
            XCTAssertFalse(mark.text.isEmpty)
            let suffix = String(mark.id.dropFirst("count-unbound.margin.".count))
            let image = try Data(contentsOf: root.appendingPathComponent("marginalia/\(suffix).png"))
            XCTAssertTrue(image.starts(with: [137, 80, 78, 71]))
            XCTAssertEqual(atoms.first { $0.id == mark.id }?.productionStatus, .ready)
        }
        XCTAssertEqual(atoms.first { $0.id == "count-unbound.margin.invitation-furniture" }?.placement.phaseID, nil)
        for radio in radios {
            XCTAssertEqual(radio.banter.id, radio.id)
            XCTAssertTrue(radio.banter.assetName?.hasPrefix("{{asset-path:count-unbound.audio.") == true)
            XCTAssertGreaterThan(radio.banter.caption.count, 60)
            XCTAssertEqual(atoms.first { $0.id == radio.id }?.productionStatus, .ready)
            XCTAssertNotNil(RadioStationRegistry.station(id: radio.stationID))
        }
        XCTAssertEqual(p.storyScenes?.first { $0.id == jumpID }?.reportAfterLiveDay, 3)
        XCTAssertEqual(p.storyScenes?.first { $0.id == "count-unbound.scene.wrong-castle" }?.reportAfterLiveDay, 21)
        let jumpBanter = try XCTUnwrap(radios.first { $0.id == "count-unbound.radio.four-came-home" })
        XCTAssertEqual(jumpBanter.stationID, "mothlight-beats")
        XCTAssertEqual(RadioStationRegistry.station(id: jumpBanter.stationID)?.hostEntityID,
            "professor-eleanor-euphony")
        XCTAssertEqual(jumpBanter.banter.caption,
            "The listed names are home. The ribbons are tied. The source is shut. Hold on.")
    }

    func testDirectedMarksRespectStoryWindowAndOneIdentityAcrossPhases() throws {
        let p = try pack()
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        let event = try XCTUnwrap(p.events.first)
        func eligible(_ dayNumber: Int, ledger: AuthoredContentReceiptLedger) throws -> Set<String> {
            let now = date(dayNumber)
            let snapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: p.id,
                event: event, now: now, calendar: calendar))
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest]
            inputs.authoredContentReceipts = ledger
            let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: now, pages: [])
            return Set(MonthlyIssueContentResolver.eligible(channel: .marginalia,
                referenceKind: .marginalia, day: day, inputs: inputs, now: now,
                lifecycleOverride: [snapshot]).map { $0.atom.id })
        }
        let setup = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: p.id,
            event: event, now: date(4), calendar: calendar))
        let scope = AuthoredContentScope(scopeID: manifest.id, runID: setup.runID, phaseID: setup.phaseID)
        let jump = AuthoredContentReceipt(contentID: jumpID, occurrenceID: "jump-return",
            channel: .storyScene, scope: scope, state: .completed, recordedAt: date(4))
        let afterJump = AuthoredContentReceiptLedger.empty.recording(jump)
        XCTAssertTrue(try eligible(4, ledger: afterJump).contains("count-unbound.margin.count-shadows"))
        XCTAssertFalse(try eligible(8, ledger: afterJump).contains("count-unbound.margin.count-shadows"))

        let invitationID = "count-unbound.margin.invitation-furniture"
        let invitation = AuthoredContentReceipt(contentID: "count-unbound.mission.invitation-without-words",
            occurrenceID: "invitation", channel: .storyScene, scope: scope,
            state: .delivered, recordedAt: date(8))
        let known = AuthoredContentReceiptLedger.empty.recording(invitation)
        XCTAssertTrue(try eligible(14, ledger: known).contains(invitationID))
        XCTAssertTrue(try eligible(22, ledger: known).contains(invitationID))
        let seen = AuthoredContentReceipt(contentID: invitationID, occurrenceID: "margin-october",
            channel: .marginalia, scope: scope, state: .delivered, recordedAt: date(14))
        XCTAssertFalse(try eligible(22, ledger: known.recording(seen)).contains(invitationID))
        XCTAssertFalse(try eligible(28, ledger: known).contains(invitationID))
    }
    func testLateReaderGetsHistoryWithoutInventedAttendanceOrRomance() throws {
        let p = try pack()
        let morning = "count-unbound.scene.first-nightbound-morning"
        let person = MonthlyIssueSimulationPersona(id: "late", subscribedFrom: date(29), firstPresentAt: date(29),
            participatingContentIDs: [morning])
        let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(29), through: date(31), calendar: calendar)
        let receipts = result.finalContentLedger.receipts
        XCTAssertTrue(receipts.contains { $0.contentID == morning && $0.state == .completed })
        XCTAssertTrue(receipts.contains { $0.contentID == "count-unbound.scene.future-tense" && $0.state == .reported })
        XCTAssertFalse(receipts.contains { $0.contentID == "count-unbound.scene.future-tense" && $0.state == .nodeCompleted })
        XCTAssertFalse(receipts.contains { $0.contentID == "count-unbound.relationship.after-lesson" && $0.choiceID != nil })
    }

    func testOpenedEndingResumesItsChosenRouteInAftermathWithoutSpoilingNaming() throws {
        let p = try pack()
        let manifest = try XCTUnwrap(p.authoringManifests?.first)
        let event = try XCTUnwrap(p.events.first)
        let sceneID = "count-unbound.scene.future-tense"
        let endingAtom = try XCTUnwrap(manifest.content.first { $0.id == sceneID })
        let morning = try XCTUnwrap(manifest.content.first { $0.id == "count-unbound.scene.first-nightbound-morning" })
        let dependency = try XCTUnwrap(morning.dependencies.first)
        let openingTime = date(28)
        let openingSnapshot = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: p.id,
            event: event, now: openingTime, calendar: calendar))
        let scope = AuthoredContentScope(scopeID: manifest.id, runID: openingSnapshot.runID, phaseID: openingSnapshot.phaseID)
        let opening = AuthoredContentReceipt(contentID: sceneID, occurrenceID: "opened-ending",
            channel: .storyScene, scope: scope, state: .opened, recordedAt: openingTime)
        var ledger = AuthoredContentReceiptLedger.empty.recording(opening)
        let nextMorning = date(29)
        let aftermath = try XCTUnwrap(WorldEventResolver.lifecycleSnapshot(packID: p.id,
            event: event, now: nextMorning, calendar: calendar))
        XCTAssertEqual(endingAtom.resolvingFollowUp(scope: scope, ledger: ledger, now: nextMorning).placement.phaseID, nil)
        XCTAssertNil(MonthlyIssueCatchUp.report(for: dependency, manifest: manifest, scenes: p.storyScenes ?? [],
            snapshot: aftermath, ledger: ledger, now: nextMorning))

        func preparedScenes(at now: Date, ledger: AuthoredContentReceiptLedger) -> [SurfacePage] {
            var inputs = BookSourceInputs.empty
            inputs.monthlyIssueAuthoringManifests = [manifest]
            inputs.authoredStoryScenes = p.storyScenes ?? []
            inputs.authoredContentReceipts = ledger
            let day = BookDay(id: BookDay.id(for: now, calendar: calendar), date: now, pages: [])
            let snapshot = WorldEventResolver.lifecycleSnapshot(packID: p.id, event: event, now: now, calendar: calendar)
            let candidates = AuthoredStoryScenePageAdapter.candidates(for: day, inputs: inputs, now: now,
                lifecycleOverride: snapshot.map { [$0] })
            return MonthlyIssuePageCuration.preparing(candidates, manifests: [manifest], day: day,
                inputs: inputs, now: now, lifecycleOverride: snapshot.map { [$0] })
        }
        func preparedEnding(at now: Date, ledger: AuthoredContentReceiptLedger) -> SurfacePage? {
            preparedScenes(at: now, ledger: ledger)
                .first { $0.payload.metadata[MonthlyIssuePageMetadata.contentID] == sceneID }
        }

        let entry = try XCTUnwrap(preparedEnding(at: nextMorning, ledger: ledger))
        XCTAssertEqual(entry.payload.metadata["authoredStoryNodeID"], sceneID + ".choose")
        XCTAssertFalse(preparedScenes(at: nextMorning, ledger: ledger).contains {
            $0.payload.metadata[MonthlyIssuePageMetadata.contentID] == morning.id
        })
        let runtime = MonthlyIssueRuntimeCatalog(packs: [p])
        var accessInputs = BookSourceInputs.empty
        accessInputs.authoredContentReceipts = ledger
        let day = BookDay(id: BookDay.id(for: nextMorning, calendar: calendar), date: nextMorning, pages: [])
        XCTAssertTrue(runtime.allows(contentID: sceneID, scope: scope, occurrenceID: opening.occurrenceID,
            day: day, inputs: accessInputs, now: nextMorning, hasAccess: true))
        XCTAssertFalse(runtime.allows(contentID: sceneID, scope: scope, occurrenceID: opening.occurrenceID,
            day: day, inputs: accessInputs, now: nextMorning, hasAccess: false))
        let route = try XCTUnwrap(runtime.nodeCommit(for: entry, choiceID: "terms", ledger: ledger,
            now: nextMorning, calendar: calendar))
        ledger = ledger.recording(route.receipt)
        let interruptedLedger = ledger
        let chosen = try XCTUnwrap(preparedEnding(at: date(30), ledger: ledger))
        XCTAssertEqual(chosen.payload.metadata["authoredStoryNodeID"], sceneID + ".terms")
        XCTAssertNil(MonthlyIssueCatchUp.report(for: dependency, manifest: manifest, scenes: p.storyScenes ?? [],
            snapshot: aftermath, ledger: ledger, now: date(30)))
        let terms = try XCTUnwrap(runtime.nodeCommit(for: chosen, choiceID: nil, ledger: ledger,
            now: date(30), calendar: calendar))
        XCTAssertFalse(terms.isFinal)
        ledger = ledger.recording(terms.receipt)
        let closing = try XCTUnwrap(preparedEnding(at: date(31), ledger: ledger))
        XCTAssertEqual(closing.payload.metadata["authoredStoryNodeID"], sceneID + ".terms.withdrawal")
        let finalNode = try XCTUnwrap(runtime.nodeCommit(for: closing, choiceID: nil, ledger: ledger,
            now: date(31), calendar: calendar))
        XCTAssertTrue(finalNode.isFinal)
        ledger = ledger.recording(finalNode.receipt)
        let completion = try XCTUnwrap(closing.authoredContentReceipts(state: .completed, at: date(31)).first)
        ledger = ledger.recording(completion)
        XCTAssertNil(preparedEnding(at: date(31), ledger: ledger))
        let resumedMorning = try XCTUnwrap(preparedScenes(at: date(31), ledger: ledger).first {
            $0.payload.metadata[MonthlyIssuePageMetadata.contentID] == morning.id
        })
        XCTAssertNil(resumedMorning.payload.metadata[MonthlyIssueCatchUp.metadataKey])
        let november = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date(31)))
        XCTAssertNil(preparedEnding(at: november, ledger: interruptedLedger))

        let neverOpened = endingAtom.resolvingFollowUp(scope: scope, ledger: .empty, now: nextMorning)
        XCTAssertEqual(neverOpened.placement.phaseID, "reciprocal")
        XCTAssertNil(preparedEnding(at: nextMorning, ledger: .empty))
        XCTAssertTrue(preparedScenes(at: nextMorning, ledger: .empty).contains {
            $0.payload.metadata[MonthlyIssuePageMetadata.contentID] == morning.id
        })
        accessInputs.authoredContentReceipts = .empty
        XCTAssertFalse(runtime.allows(contentID: sceneID, scope: scope, occurrenceID: "new-offer",
            day: day, inputs: accessInputs, now: nextMorning, hasAccess: true))
        XCTAssertNotNil(MonthlyIssueCatchUp.report(for: dependency, manifest: manifest, scenes: p.storyScenes ?? [],
            snapshot: aftermath, ledger: .empty, now: nextMorning))

        let dismissed = interruptedLedger.recording(AuthoredContentReceipt(contentID: sceneID,
            occurrenceID: opening.occurrenceID, channel: .storyScene, scope: scope,
            state: .dismissed, recordedAt: date(30)))
        XCTAssertNil(preparedEnding(at: date(30), ledger: dismissed))
        XCTAssertNotNil(MonthlyIssueCatchUp.report(for: dependency, manifest: manifest, scenes: p.storyScenes ?? [],
            snapshot: aftermath, ledger: dismissed, now: date(30)))

        var unsupported = p
        unsupported.minimumRuntimeVersion = 6
        let versionReport = MonthlyIssueAuthoringValidator.validate(manifest, against: unsupported, mode: .working)
        XCTAssertTrue(versionReport.errors.contains { $0.code == .invalidOccurrence && $0.subjectID == sceneID })
    }

    func testAllEndingRoutesReachNamingAndKeepRomanticSuggestionDistinct() throws {
        let p = try pack()
        for (route, social) in [("terms", "soren-roof"), ("rule", "wicker-conversation"), ("ruse", "own-evening")] {
            let person = MonthlyIssueSimulationPersona(id: route, subscribedFrom: date(1), firstPresentAt: date(8),
                participatingContentIDs: Set(p.storyScenes!.map(\.id)),
                choicesByNodeID: ["count-unbound.scene.east-stacks.choice": "move-map",
                    "count-unbound.scene.man-reading-himself.question": "why-her",
                    "count-unbound.strategy.choose": route == "terms" ? "terms" : (route == "rule" ? "hunt" : "gambit"),
                    "count-unbound.strategy.terms": "admit", "count-unbound.strategy.hunt": "map", "count-unbound.strategy.gambit": "light",
                    "count-unbound.scene.wrong-castle.room": "nursery",
                    "count-unbound.scene.future-tense.choose": route,
                    "count-unbound.relationship.after-lesson.suggestion": social])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
                persona: person, from: date(8), through: date(31), calendar: calendar)
            let receipts = result.finalContentLedger.receipts
            for id in ["count-unbound.scene.future-tense", "count-unbound.scene.first-nightbound-morning", "count-unbound.relationship.after-lesson"] {
                XCTAssertTrue(receipts.contains { $0.contentID == id && $0.state == .completed }, id)
            }
            let conclusion = try XCTUnwrap(receipts.first { $0.contentID == "issue-conclusion" && $0.state == .concluded })
            let manifest = try XCTUnwrap(p.authoringManifests?.first)
            let earlier = try XCTUnwrap(manifest.content.first { $0.id == "count-unbound.scene.east-stacks" })
            XCTAssertTrue(earlier.isClosed(scope: conclusion.scope, ledger: result.finalContentLedger, now: date(29)))
            for id in ["count-unbound.scene.first-nightbound-morning", "count-unbound.relationship.after-lesson", "count-unbound.mission.go-back-once"] {
                let survivor = try XCTUnwrap(manifest.content.first { $0.id == id })
                XCTAssertFalse(survivor.isClosed(scope: conclusion.scope, ledger: result.finalContentLedger, now: date(29)), id)
            }
            let ending = receipts.filter { $0.contentID == "count-unbound.scene.future-tense" && $0.state == .nodeCompleted }
            XCTAssertEqual(ending.count, 3)
            XCTAssertTrue(ending.contains { $0.nodeID == "count-unbound.scene.future-tense." + route })
            XCTAssertTrue(receipts.contains { $0.nodeID == "count-unbound.relationship.after-lesson.suggestion" && $0.choiceID == social })
        }
    }

    func testStrategySelectionOnlyVisitsChosenPreparation() throws {
        let p = try pack()
        let id = "count-unbound.strategy"
        for (route, choice) in [("terms", "admit"), ("hunt", "map"), ("gambit", "light")] {
            let person = MonthlyIssueSimulationPersona(id: route, subscribedFrom: date(1), firstPresentAt: date(8),
                participatingContentIDs: Set(p.storyScenes!.map(\.id)),
                choicesByNodeID: ["count-unbound.scene.east-stacks.choice": "move-map",
                    "count-unbound.scene.man-reading-himself.question": "why-her", id + ".choose": route,
                    id + "." + route: choice])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
                persona: person, from: date(8), through: date(22), calendar: calendar)
            let nodes = result.finalContentLedger.receipts.filter { $0.contentID == id && $0.state == .nodeCompleted }.compactMap(\.nodeID)
            XCTAssertEqual(Set(nodes), Set([id + ".choose", id + "." + route, id + "." + route + ".after"]))
            XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == id && $0.state == .completed })
        }
    }

    func testFourthCrossingCanFinishInAftermathWithoutStoryAttendance() throws {
        let p = try pack()
        let mission = "count-unbound.mission.go-back-once"
        let person = MonthlyIssueSimulationPersona(id: "fourth-crossing", subscribedFrom: date(22), firstPresentAt: date(22),
            participatingContentIDs: [mission], missionReturnNotBefore: [mission: date(31)])
        let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(22), through: date(31), calendar: calendar)
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .accepted })
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .completed && $0.recordedAt >= date(31) })
        XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID.contains(".scene.") && $0.state == .completed })
        let late = MonthlyIssueSimulationPersona(id: "missed-offer", subscribedFrom: date(29), firstPresentAt: date(29),
            participatingContentIDs: [mission])
        let missed = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: late, from: date(29), through: date(31), calendar: calendar)
        XCTAssertFalse(missed.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .accepted })
    }

    func testObservationSelectionSurvivesNewEntriesButRejectsMissingOrNonReaderSource() {
        let original = BookPage(id: "original", type: .narrativeOS, promptText: "Notice", userInput: "Book prose",
            playerReply: "A moth on the window.", origin: .generated)
        let selected = AuthoredReaderAnchor.candidates(in: [original]).first!
        let newer = (0..<33).map { index in
            BookPage(id: "new-\(index)", type: .narrativeOS, promptText: "Notice", userInput: "Book prose",
                playerReply: "Another observation.", origin: .generated)
        }
        XCTAssertFalse(AuthoredReaderAnchor.candidates(in: newer + [original]).contains { $0.id == selected.id })
        XCTAssertEqual(AuthoredReaderAnchor.resolve(id: selected.id, pages: newer + [original]), selected)
        XCTAssertNil(AuthoredReaderAnchor.resolve(id: selected.id, pages: newer))
        var changed = original
        changed.privacy = .localSensitive
        XCTAssertNil(AuthoredReaderAnchor.resolve(id: selected.id, pages: [changed]))
        XCTAssertNil(AuthoredReaderAnchor.resolve(id: "original:-1", pages: [original]))
        let bookOnly = BookPage(id: "original", type: .bookOfYou, promptText: "Tonight", userInput: "Invented observation", origin: .generated)
        XCTAssertNil(AuthoredReaderAnchor.resolve(id: selected.id, pages: [bookOnly]))
    }

    func testOlderObservationSearchFindsPrivateReaderWordsBeyondRecentWindow() {
        let recent = (0..<40).map { index in
            BookPage(id: "recent-\(index)", type: .narrativeOS, promptText: "Notice", userInput: "The Book's question",
                playerReply: "A stone by the gate number \(index).", origin: .generated)
        }
        let older = BookPage(id: "older", type: .narrativeOS, promptText: "Notice", userInput: "The Book's question",
            playerReply: "Café moth beside the copper door.", origin: .generated)
        var sensitive = BookPage(id: "sensitive", type: .narrativeOS, promptText: "Notice", userInput: "The Book's question",
            playerReply: "Secret copper door.", origin: .generated)
        sensitive.privacy = .localSensitive
        let bookOnly = BookPage(id: "book", type: .bookOfYou, promptText: "Tonight", userInput: "Invented copper door.", origin: .generated)
        let pages = recent + [older, sensitive, bookOnly]

        XCTAssertEqual(AuthoredReaderAnchor.candidates(in: pages).count, 32)
        let all = AuthoredReaderAnchor.candidates(in: pages, limit: Int.max)
        XCTAssertEqual(all.count, 41)
        XCTAssertEqual(AuthoredReaderAnchor.matching(all, query: "CAFE copper").map(\.pageID), ["older"])
        XCTAssertEqual(AuthoredReaderAnchor.matching(all, query: "door moth").map(\.pageID), ["older"])
        XCTAssertEqual(AuthoredReaderAnchor.matching(all, query: "stone", limit: 8).count, 8)
        XCTAssertTrue(AuthoredReaderAnchor.matching(all, query: "secret").isEmpty)
        XCTAssertTrue(AuthoredReaderAnchor.matching(all, query: "invented").isEmpty)
    }

    func testThirdCrossingDoesNotRequirePreviousStoryAttendance() throws {
        let p = try pack()
        let mission = "count-unbound.mission.other-side"
        let person = MonthlyIssueSimulationPersona(id: "late-finding", subscribedFrom: date(15), firstPresentAt: date(15),
            participatingContentIDs: [mission], missionReturnNotBefore: [mission: date(25)])
        let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(15), through: date(27), calendar: calendar)
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .accepted })
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .completed })
        XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID.contains(".scene.") && $0.state == .completed })
    }

    func testWrongCastleRoutesRejoinWithoutRequiringARealWorldFinding() throws {
        let p = try pack()
        let sceneID = "count-unbound.scene.wrong-castle"
        for room in ["ballroom", "nursery", "red-chair"] {
            let person = MonthlyIssueSimulationPersona(id: room, subscribedFrom: date(1), firstPresentAt: date(8),
                participatingContentIDs: Set(p.storyScenes!.map(\.id).filter { !$0.contains(".mission.") }),
                choicesByNodeID: ["count-unbound.scene.east-stacks.choice": "move-map",
                    "count-unbound.scene.man-reading-himself.question": "why-her", sceneID + ".room": room])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
                persona: person, from: date(8), through: date(27), calendar: calendar)
            let receipts = result.finalContentLedger.receipts
            XCTAssertTrue(receipts.contains { $0.contentID == sceneID && $0.state == .completed })
            let selected = receipts.filter { $0.nodeID == sceneID + ".room" && $0.state == .nodeCompleted }
            XCTAssertEqual(selected.count, 1)
            XCTAssertEqual(selected.first?.choiceID, room)
            XCTAssertTrue(selected.allSatisfy { $0.recordedAt >= date(22) && $0.recordedAt < date(28) })
        }
    }

    func testSecondCrossingCanReturnAfterOfferWindowButNotAfterOctober27() throws {
        let p = try pack()
        let mission = "count-unbound.mission.invitation-without-words"
        for returnDay in [20, 28] {
            let person = MonthlyIssueSimulationPersona(id: "invitation-\(returnDay)", subscribedFrom: date(1), firstPresentAt: date(8),
                participatingContentIDs: Set(p.storyScenes!.map(\.id)),
                choicesByNodeID: ["count-unbound.scene.east-stacks.choice": "move-map"],
                missionReturnNotBefore: [mission: date(returnDay)])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
                persona: person, from: date(8), through: date(29), calendar: calendar)
            XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .accepted })
            XCTAssertEqual(result.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .completed }, returnDay == 20)
        }
    }

    func testSubmittedFindingIsAvailableWithoutAdditionalPermission() throws {
        let page = SurfacePage(id: "finding", type: .narrativeOS, sourceID: "monthly", prompt: "", detail: "").withMetadata([
            "authoredFindingUseOffer": "true",
            MonthlyIssuePageMetadata.interaction: "readerEvidence",
            MonthlyIssuePageMetadata.issueID: "issue", MonthlyIssuePageMetadata.runID: "run",
            MonthlyIssuePageMetadata.contentID: "invitation", "authoredFindingMayQuote": "true",
            "authoredFindingShape": "light"
        ])
        let privateFinding = try XCTUnwrap(AuthoredFindingPermission.from(page))
        XCTAssertTrue(privateFinding.mayUse)
        XCTAssertTrue(privateFinding.mayQuote)
        XCTAssertEqual(privateFinding.shape, "light")
        let allowed = try XCTUnwrap(AuthoredFindingPermission.from(page.withMetadata(["authoredFindingMayUse": "true"])))
        XCTAssertTrue(allowed.mayQuote)
        XCTAssertEqual(allowed.shape, "light")
        let encoded = try XCTUnwrap(allowed.retainedTag?.split(separator: ":").last)
        XCTAssertEqual(try JSONDecoder().decode(AuthoredFindingPermission.self, from: XCTUnwrap(Data(base64Encoded: String(encoded)))), allowed)
        XCTAssertNil(AuthoredFindingPermission.from(page.withMetadata([MonthlyIssuePageMetadata.interaction: "none"])))
    }

    func testDraculaQuestionsFreezeOnlyTheSelectedAnswer() throws {
        let p = try pack()
        let sceneID = "count-unbound.scene.man-reading-himself"
        let scene = try XCTUnwrap(p.storyScenes?.first { $0.id == sceneID })
        let choices = try XCTUnwrap(scene.nodes?.first?.choices)
        XCTAssertEqual(choices.count, 3)
        for chosen in choices {
            let person = MonthlyIssueSimulationPersona(id: chosen.id, subscribedFrom: date(1), firstPresentAt: date(8),
                participatingContentIDs: Set(p.storyScenes!.map(\.id)),
                choicesByNodeID: ["count-unbound.scene.east-stacks.choice": "move-map", sceneID + ".question": chosen.id])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
                persona: person, from: date(8), through: date(18), calendar: calendar)
            let receipts = result.finalContentLedger.receipts
            XCTAssertTrue(receipts.contains { $0.contentID == sceneID && $0.state == .completed })
            let questions = receipts.filter { $0.nodeID == sceneID + ".question" && $0.state == .nodeCompleted }
            XCTAssertEqual(questions.count, 1)
            XCTAssertEqual(questions.first?.choiceID, chosen.id)
            XCTAssertEqual(questions.first?.storyText, chosen.braidText)
        }
    }

    func testSundayVisitBranchesReturnAndNeverOfferAfterWednesday() throws {
        let p = try pack()
        for action in ["cross-out", "call-permancer", "watch-dracula"] {
            let person = MonthlyIssueSimulationPersona(id: action, subscribedFrom: date(1), firstPresentAt: date(4),
                participatingContentIDs: Set(p.storyScenes!.map(\.id)),
                choicesByNodeID: ["academy.school.ribbon-lesson": "enter", jumpID + ".checks": "check-list", jumpID + ".disturbance": action,
                                  "count-unbound.scene.east-stacks.choice": "move-map"])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id, persona: person, from: date(1), through: date(14), calendar: calendar)
            XCTAssertNil(result.finalJumpState.active)
            let receipts = result.finalContentLedger.receipts
            XCTAssertTrue(receipts.contains { $0.nodeID == jumpID + ".disturbance" && $0.choiceID == action })
            let interventions = try XCTUnwrap(p.storyScenes?.first { $0.id == jumpID }?.nodes?.first { $0.id == jumpID + ".disturbance" }?.choices)
            let prose = result.braidDays.flatMap(\.pages).map(\.userInput).joined(separator: "\n")
            for intervention in interventions {
                let text = try XCTUnwrap(intervention.braidText)
                XCTAssertEqual(prose.contains(text), intervention.id == action)
            }

            XCTAssertTrue(receipts.contains { $0.contentID == jumpID && $0.state == .completed })
            XCTAssertFalse(result.frames.filter { $0.date < date(4) || $0.date >= date(8) }.contains { $0.eligibleStorySceneIDs.contains(jumpID) })
        }
    }
    func testLateReaderGetsReportWithoutJumpAttendance() throws {
        let p = try pack()
        let person = MonthlyIssueSimulationPersona(id: "late", subscribedFrom: date(1), firstPresentAt: date(8), participatingContentIDs: ["count-unbound.scene.east-stacks"])
        let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id, persona: person, from: date(1), through: date(14), calendar: calendar)
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == jumpID && $0.state == .reported })
        XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID == jumpID && $0.state == .completed })
        XCTAssertNil(result.finalJumpState.active)
    }
    func testLateReaderCanReachMapRoomThroughPublicIncidentReport() throws {
        let p = try pack()
        let incident = "count-unbound.scene.east-stacks"
        let mapRoom = "count-unbound.school.map-room"
        let person = MonthlyIssueSimulationPersona(id: "reported-incident", subscribedFrom: date(1),
            firstPresentAt: date(10), participatingContentIDs: [mapRoom])
        let result = MonthlyIssueAuthoringSimulator.run(pack: p,
            manifestID: p.authoringManifests![0].id, persona: person,
            from: date(1), through: date(14), calendar: calendar)
        let receipts = result.finalContentLedger.receipts
        XCTAssertTrue(receipts.contains { $0.contentID == incident && $0.state == .reported })
        XCTAssertFalse(receipts.contains { $0.contentID == incident && $0.state == .completed })
        XCTAssertTrue(receipts.contains { $0.contentID == mapRoom && $0.state == .completed })
    }
    func testStayingOutsideNeverEntersTheJump() throws {
        let p = try pack()
        let person = MonthlyIssueSimulationPersona(id: "outside", subscribedFrom: date(1), firstPresentAt: date(1),
            participatingContentIDs: Set(p.storyScenes!.map(\.id)),
            choicesByNodeID: ["academy.school.ribbon-lesson": "stay"])
        let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(1), through: date(14), calendar: calendar)
        XCTAssertFalse(result.frames.contains { $0.activeEpisodeID != nil })
        let receipts = result.finalContentLedger.receipts
        XCTAssertTrue(receipts.contains { $0.nodeID == jumpID + ".outside" })
        XCTAssertFalse(receipts.contains { $0.nodeID == jumpID + ".checks" || $0.nodeID == jumpID + ".disturbance" })
        XCTAssertTrue(receipts.contains { $0.contentID == "count-unbound.scene.east-stacks" && $0.state == .completed })
    }

    func testUnfinishedVisitExpiresBeforeEastStacks() throws {
        let p = try pack()
        let person = MonthlyIssueSimulationPersona(id: "unfinished", subscribedFrom: date(1), firstPresentAt: date(1),
            participatingContentIDs: Set(p.storyScenes!.map(\.id)), dismissedContentIDs: ["count-unbound.mission.hold-place"])
        let first = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(1), through: date(4), calendar: calendar)
        let active = try XCTUnwrap(first.finalJumpState.active)
        XCTAssertEqual(active.authoredEndsAt, calendar.startOfDay(for: date(8)))
        let absent = MonthlyIssueSimulationPersona(id: "unfinished", subscribedFrom: date(1), firstPresentAt: date(20))
        let later = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: absent, from: date(5), through: date(8), calendar: calendar,
            initialContentLedger: first.finalContentLedger, initialLifecycleLedger: first.finalLifecycleLedger,
            initialJumpState: first.finalJumpState, initialBraidDays: first.braidDays)
        XCTAssertNil(later.finalJumpState.active)
    }

    func testDismissalRetiresInvitationButUnresolvedInvitationRemainsEligible() throws {
        let p = try pack()
        let school: Set<String> = ["academy.school.chair-first", "academy.school.sentence-coat", "academy.school.wrong-way"]
        for dismiss in [false, true] {
            let person = MonthlyIssueSimulationPersona(id: "invitation", subscribedFrom: date(1), firstPresentAt: date(1),
                participatingContentIDs: school, dismissedContentIDs: dismiss ? [jumpID, "count-unbound.mission.hold-place"] : ["count-unbound.mission.hold-place"])
            let result = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
                persona: person, from: date(1), through: date(7), calendar: calendar)
            let later = result.frames.filter { $0.date >= date(5) }
            XCTAssertEqual(later.contains { $0.eligibleStorySceneIDs.contains(jumpID) }, !dismiss)
            XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID == jumpID && $0.state == .completed })
            XCTAssertNil(result.finalJumpState.active)
        }
    }

    func testVisitDeadlineRequiresCompatibleRuntimeAndValidDay() throws {
        var p = try pack()
        p.minimumRuntimeVersion = 2
        var report = MonthlyIssueAuthoringValidator.validate(p.authoringManifests![0], against: p, mode: .working)
        XCTAssertTrue(report.diagnostics.contains { $0.code == .invalidContentReference && $0.message.contains("runtime version 3") })
        p.minimumRuntimeVersion = 3
        let index = try XCTUnwrap(p.storyScenes?.firstIndex { $0.id == jumpID })
        p.storyScenes![index].jump!.lastLiveDay = 31
        report = MonthlyIssueAuthoringValidator.validate(p.authoringManifests![0], against: p, mode: .working)
        XCTAssertTrue(report.diagnostics.contains { $0.code == .invalidContentReference && $0.message.contains("deadline must fall inside") })
    }

    func testCrossingAcceptanceIsNotFindingAndLateReturnStillGetsResponse() throws {
        let p = try pack()
        let mission = "count-unbound.mission.hold-place"
        let person = MonthlyIssueSimulationPersona(id: "late-finding", subscribedFrom: date(1), firstPresentAt: date(1),
            participatingContentIDs: Set(p.storyScenes!.map(\.id)), missionReturnNotBefore: [mission: date(19)])
        let before = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(1), through: date(7), calendar: calendar)
        XCTAssertTrue(before.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .accepted })
        XCTAssertFalse(before.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .completed })
        let braid = try XCTUnwrap(p.storyScenes?.first { $0.id == mission }?.braidText)
        XCTAssertFalse(before.braidDays.flatMap(\.pages).contains { $0.userInput.contains(braid) })
        let after = MonthlyIssueAuthoringSimulator.run(pack: p, manifestID: p.authoringManifests![0].id,
            persona: person, from: date(8), through: date(31), calendar: calendar,
            initialContentLedger: before.finalContentLedger, initialLifecycleLedger: before.finalLifecycleLedger,
            initialJumpState: before.finalJumpState, initialBraidDays: before.braidDays)
        XCTAssertTrue(after.finalContentLedger.receipts.contains { $0.contentID == mission && $0.state == .completed && $0.recordedAt >= date(19) })

        XCTAssertTrue(after.braidDays.flatMap(\.pages).contains { $0.userInput.contains(braid) })
    }

    func testAuthoredFindingAcknowledgementRequiresActualReturn() throws {
        let p = try pack()
        let reply = try XCTUnwrap(p.storyScenes?.first { $0.id == "count-unbound.mission.hold-place" }?.missionKeptResponse)
        let surface = SurfacePage(id: "finding", type: .narrativeOS, sourceID: "test", intent: .simulate,
            renderStyle: .graphEvent, score: 82, reason: "test", prompt: "One sentence", detail: "",
            payload: BookPagePayload(headline: "Leave me something to hold", body: "One sentence", metadata: [
                MonthlyIssuePageMetadata.authoredStoryScene: "true", "authoredMissionOffer": "false",
                MonthlyIssuePageMetadata.interaction: MonthlyIssueInteractionKind.readerEvidence.rawValue,
                "authoredMissionKeptResponse": reply]))
        XCTAssertEqual(AuthoredMissionAcknowledgement.note(for: surface, hasReaderContribution: true)?.line, reply)
        XCTAssertNil(AuthoredMissionAcknowledgement.note(for: surface, hasReaderContribution: false))
        XCTAssertNil(AuthoredMissionAcknowledgement.note(for: surface.withMetadata(["authoredMissionOffer": "true"]), hasReaderContribution: true))
        XCTAssertNil(AuthoredMissionAcknowledgement.note(for: surface.withMetadata([
            MonthlyIssuePageMetadata.interaction: MonthlyIssueInteractionKind.choice.rawValue]), hasReaderContribution: true))
    }

    func testAnchorSelectionSeparatesReaderWordsFromBookProseAndSensitivePages() {
        let reader = BookPage(id: "finding", type: .narrativeOS, promptText: "Notice", userInput: "BOOK PROSE",
            playerReply: "The cup has one blue chip.", origin: .generated)
        var sensitive = reader
        sensitive.id = "sensitive"
        sensitive.privacy = .localSensitive
        let generated = BookPage(type: .bookOfYou, promptText: "Tonight", userInput: "GENERATED", origin: .generated)
        let candidates = AuthoredReaderAnchor.candidates(in: [sensitive, generated, reader])
        XCTAssertEqual(candidates.map(\.text), ["The cup has one blue chip."])
        XCTAssertEqual(AuthoredReaderAnchor.resolve(id: candidates.first?.id, pages: [reader]), candidates.first)
        XCTAssertNil(AuthoredReaderAnchor.resolve(id: candidates.first?.id, pages: []))
    }

    func testAnchorQuoteConsentIsVisitScopedAndSurvivesResume() throws {
        let p = try pack()
        let definition = try XCTUnwrap(p.storyScenes?.first { $0.id == jumpID }?.jump)
        let selected = AuthoredReaderAnchor(pageID: "finding", contributionIndex: 0, text: "The cup has one blue chip.")
        for quote in [false, true] {
            let state = try XCTUnwrap(BookJumpEngine.authoredAction(.start, definition: definition,
                state: BookJumpState(), endsAt: date(8), now: date(4), readerAnchor: selected, mayQuoteAnchor: quote))
            XCTAssertEqual(state.active?.anchor, quote ? selected.text : "the detail you gave me")
            XCTAssertEqual(state.active?.authoredAnchorSourceID, selected.id)
            let data = try JSONEncoder().encode(state)
            if !quote { XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(selected.text)) }
            let restored = try JSONDecoder().decode(BookJumpState.self, from: data)
            XCTAssertEqual(restored.active?.anchor, state.active?.anchor)
            let changed = BookJumpEngine.authoredAction(.advance, definition: definition, state: restored,
                endsAt: date(8), now: date(5), readerAnchor: selected, mayQuoteAnchor: !quote)
            XCTAssertEqual(changed?.active?.anchor, state.active?.anchor)
        }
        let fallback = BookJumpEngine.authoredAction(.start, definition: definition, state: BookJumpState(),
            endsAt: date(8), now: date(4))
        XCTAssertEqual(fallback?.active?.anchor, definition.anchor)
        XCTAssertNil(fallback?.active?.authoredAnchorSourceID)
    }

    func testReturnRecognitionMatchesVisitAndNeverExportsAnchorQuotation() throws {
        let definition = try XCTUnwrap(try pack().storyScenes?.first { $0.id == jumpID }?.jump)
        let selected = AuthoredReaderAnchor(pageID: "finding", contributionIndex: 0, text: "PRIVATE EXACT WORDS")
        for quote in [false, true] {
            let state = try XCTUnwrap(BookJumpEngine.authoredAction(.start, definition: definition,
                state: BookJumpState(), endsAt: date(8), now: date(4), readerAnchor: selected, mayQuoteAnchor: quote))
            let line = try XCTUnwrap(AuthoredJumpReturnRecognition.line(definition: definition, active: state.active))
            XCTAssertTrue(line.contains("the detail you gave me"))
            XCTAssertFalse(line.contains(selected.text))
            var other = definition
            other.episodeID = "another-visit"
            XCTAssertNil(AuthoredJumpReturnRecognition.line(definition: other, active: state.active))
        }
        let ribbon = BookJumpEngine.authoredAction(.start, definition: definition, state: BookJumpState(), endsAt: date(8), now: date(4))
        XCTAssertTrue(AuthoredJumpReturnRecognition.line(definition: definition, active: ribbon?.active)?.contains("class ribbon") == true)
        XCTAssertNil(AuthoredJumpReturnRecognition.line(definition: definition, active: nil))
    }

}
