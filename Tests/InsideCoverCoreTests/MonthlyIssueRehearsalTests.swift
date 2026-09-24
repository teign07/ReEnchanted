import XCTest
import CryptoKit
@testable import InsideCoverCore

final class MonthlyIssueRehearsalTests: XCTestCase {
    func testPreparedSimulatorFixtureInstallsThroughNativeDecoder() async throws {
        guard let path = ProcessInfo.processInfo.environment["REENCHANTED_SIMULATOR_FIXTURE_DIR"] else {
            throw XCTSkip("Set REENCHANTED_SIMULATOR_FIXTURE_DIR to the local reader rehearsal input.")
        }
        let input = URL(fileURLWithPath: path)
        let manifest = try MonthlyIssueManifestVerifier.verify(
            envelopeData: Data(contentsOf: input.appendingPathComponent("manifest.envelope.json")),
            publicKeyRawRepresentation: Data(contentsOf: input.appendingPathComponent("public-key.bin")))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let plan = MonthlyIssueDeliveryPlanner.plan(manifest: manifest, now: Date(), hasMonthlyAccess: true,
            manifestHost: "rehearsal.invalid")
        XCTAssertEqual(plan.assets.count, 4)
        let result = try await MonthlyIssueAssetInstaller.install(plan: plan,
            documentsURL: root.appendingPathComponent("Content"), stateURL: root.appendingPathComponent("state.json"),
            fetch: { try Data(contentsOf: input.appendingPathComponent($0.lastPathComponent)) })
        XCTAssertEqual(result.installedAssetIDs.count, 4)
    }

    private var fixtureRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/fixtures/monthly-rehearsal")
    }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2027, month: 11, day: day, hour: hour))!
    }
    private func pack() throws -> WorldEventPack {
        try ContentPackFileLocator.decoder().decode(WorldEventPack.self,
            from: Data(contentsOf: fixtureRoot.appendingPathComponent("school-door.reenchantedevents.json")))
    }
    private func persona(choice: String = "pin") -> MonthlyIssueSimulationPersona {
        MonthlyIssueSimulationPersona(id: choice, subscribedFrom: date(1, 0), firstPresentAt: date(1, 0),
            participatingContentIDs: ["opening", "crossing", "lesson", "assembly", "ending"],
            choicesByNodeID: ["choose": choice], missionReturnNotBefore: ["crossing": date(10)], captionOnlyRadio: true)
    }
    private func run(_ reader: MonthlyIssueSimulationPersona) throws -> MonthlyIssueAuthoringSimulation {
        let fixture = try pack()
        return MonthlyIssueAuthoringSimulator.run(pack: fixture, manifestID: "school-door-2027-11",
            persona: reader, from: date(1, 0), through: date(30, 23), calendar: calendar)
    }

    func testCompleteFixtureDecodesAndPassesNativeReleaseValidation() throws {
        let fixture = try pack()
        let graph = try XCTUnwrap(fixture.authoringManifests?.first)
        let report = MonthlyIssueAuthoringValidator.validate(graph, against: fixture, mode: .release)
        XCTAssertTrue(report.isValid, "\(report)")
        XCTAssertEqual(fixture.minimumRuntimeVersion, 2)
        XCTAssertEqual(fixture.events[0].phases.compactMap(\.role), [.setup, .buildup, .climax, .aftermath])
    }

    func testSignedSchemaTwoCanCarryDirectedMediaWithoutBreakingSchemaOne() throws {
        let original = try Data(contentsOf: fixtureRoot.appendingPathComponent("delivery-manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(MonthlyIssueDeliveryManifest.self, from: original)
        let key = Curve25519.Signing.PrivateKey()
        func verify(_ payload: Data) throws -> MonthlyIssueDeliveryManifest {
            let envelope = MonthlyIssueSignedManifestEnvelope(keyID: "test-only",
                payload: payload.base64EncodedString(),
                signature: try key.signature(for: payload).base64EncodedString())
            return try MonthlyIssueManifestVerifier.verify(envelopeData: JSONEncoder().encode(envelope),
                publicKeyRawRepresentation: key.publicKey.rawRepresentation)
        }
        XCTAssertEqual(try verify(original).schemaVersion, 1)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        manifest.schemaVersion = 2
        XCTAssertEqual(try verify(encoder.encode(manifest)).schemaVersion, 2)
        manifest.schemaVersion = 3
        XCTAssertThrowsError(try verify(encoder.encode(manifest))) {
            XCTAssertEqual($0 as? MonthlyIssueDeliveryError, .unsupportedSchema(3))
        }
    }

    func testSubscriptionCredentialsStayOnExactHTTPSOrigin() throws {
        let origin = try XCTUnwrap(URL(string: "https://issues.example/monthly-issues/manifest"))
        XCTAssertTrue(MonthlyIssueRequestPolicy.sameOrigin(origin, URL(string: "https://issues.example:443/monthly-issues/assets/a")!))
        for target in ["http://issues.example/a", "https://other.example/a", "https://issues.example:8443/a", "https://user:secret@issues.example/a"] {
            XCTAssertFalse(MonthlyIssueRequestPolicy.sameOrigin(origin, URL(string: target)!), target)
        }
    }

    func testAccessDenialAndBadRoutesNeverUseOfflineManifestFallback() {
        for status in [301, 302, 400, 401, 403, 404] {
            XCTAssertFalse(MonthlyIssueRequestPolicy.mayUseCachedEnvelope(afterHTTPStatus: status))
        }
        for status in [408, 429, 500, 503] {
            XCTAssertTrue(MonthlyIssueRequestPolicy.mayUseCachedEnvelope(afterHTTPStatus: status))
        }
    }

    func testEachBranchResumesAndOnlyItsOwnTextIsBraided() throws {
        for choice in ["pin", "thread"] {
            let result = try run(persona(choice: choice))
            XCTAssertEqual(result, try run(persona(choice: choice)), "Synthetic clocks must be reproducible")
            let nodes = result.finalContentLedger.receipts.filter { $0.state == .nodeCompleted }
            XCTAssertEqual(nodes.compactMap(\.nodeID), ["enter", "choose", "\(choice)-home"])
            XCTAssertEqual(nodes.first { $0.nodeID == "choose" }?.choiceID, choice)
            XCTAssertNil(result.finalJumpState.active)
            XCTAssertEqual(result.finalJumpState.returned.count, 1)
            XCTAssertTrue(result.finalJumpState.borrowedRules.isEmpty)
            let prose = result.braidDays.flatMap(\.pages).map(\.userInput).joined(separator: "\n")
            XCTAssertTrue(prose.contains(choice == "pin" ? "chose a brass pin" : "chose blue thread"))
            XCTAssertFalse(prose.contains(choice == "pin" ? "chose blue thread" : "chose a brass pin"))
            let boundIDs = result.frames.flatMap { $0.braidedReceiptIDs ?? [] }
            XCTAssertEqual(boundIDs.count, Set(boundIDs).count)
        }
    }

    func testCrossingAcceptsOnceThenWaitsForLaterEvidence() throws {
        let result = try run(persona())
        let receipts = result.finalContentLedger.receipts.filter { $0.contentID == "crossing" }
        XCTAssertEqual(receipts.filter { $0.state == .accepted }.count, 1)
        let completed = receipts.filter { $0.state == .completed }
        XCTAssertEqual(completed.count, 1)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(completed.first).recordedAt, date(10))
        XCTAssertTrue(result.frames.filter { $0.date < date(10) }.allSatisfy {
            !($0.completedContentIDs ?? []).contains("crossing")
        })
    }

    func testLateReaderGetsPublicHistoryWithoutAFictionalChoice() throws {
        var reader = persona()
        reader.firstPresentAt = date(22)
        let result = try run(reader)
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .reported })
        XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .nodeCompleted })
        XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .completed })
        XCTAssertTrue(result.finalJumpState.returned.isEmpty)
        XCTAssertTrue(result.frames.allSatisfy { !$0.participated })
    }

    func testExitDuringLapseSurvivesRegrantAndDoesNotRestartTheEpisode() throws {
        var reader = persona()
        reader.subscribedUntil = date(8, 12)
        reader.resubscribedAt = date(9)
        reader.exitEpisodeAt = date(8, 18)
        let result = try run(reader)
        XCTAssertEqual(result.finalContentLedger.receipts.filter { $0.state == .nodeCompleted }.compactMap(\.nodeID), ["enter"])
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .dismissed })
        XCTAssertTrue(result.frames.filter { !$0.subscriptionActive }.allSatisfy { $0.deliveredContentIDs.isEmpty })
        XCTAssertNil(result.finalJumpState.active)
        XCTAssertEqual(result.finalJumpState.returned.count, 1)
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .reported })
    }

    func testSavedExitNeedsNoCatalogAndKeepsOtherRunsUntouched() throws {
        let scope = AuthoredContentScope(scopeID: "school-door-2027-11", runID: "school-door:2027", phaseID: "inside-the-page")
        let receipt = AuthoredContentReceipt(contentID: "lesson", occurrenceID: "enter", channel: .storyScene,
            scope: scope, state: .nodeCompleted, recordedAt: date(8), nodeID: "enter")
        let definition = try XCTUnwrap(try pack().storyScenes?.first { $0.id == "lesson" }?.jump)
        let started = try XCTUnwrap(BookJumpEngine.authoredAction(.start, definition: definition,
            state: BookJumpState(), endsAt: date(30), now: date(8), contentReceipt: receipt))
        let reloaded = try JSONDecoder().decode(BookJumpState.self, from: JSONEncoder().encode(started))
        let active = try XCTUnwrap(reloaded.active)
        let ledger = BookJumpEngine.recordingAuthoredExit(active, in: .empty, now: date(8, 18))
        XCTAssertEqual(ledger, BookJumpEngine.recordingAuthoredExit(active, in: ledger, now: date(8, 19)))
        XCTAssertEqual(ledger.receipts.first?.scope, scope)
        XCTAssertEqual(ledger.receipts.first?.recordedAt, date(8, 18))
        XCTAssertFalse(ledger.satisfies(AuthoredContentReceiptQuery(contentID: "lesson", state: .dismissed,
            scopeID: scope.scopeID, runID: "school-door:2028"), now: date(9)))
    }

    func testCaptionAndConclusionHaveDistinctReceipts() throws {
        let result = try run(persona())
        XCTAssertTrue(result.finalContentLedger.receipts.contains { $0.contentID == "radio-hinge" && $0.state == .delivered })
        XCTAssertFalse(result.finalContentLedger.receipts.contains { $0.contentID == "radio-hinge" && $0.state == .played })
        let ended = try XCTUnwrap(result.finalContentLedger.receipts.first { $0.state == .concluded })
        XCTAssertTrue(result.frames.filter { $0.date > ended.recordedAt }.allSatisfy { $0.deliveredContentIDs.isEmpty })
    }

    func testAuthoredPersonasDecodeAndExerciseTrashAndAbsence() throws {
        let readers = try ContentPackFileLocator.decoder().decode([MonthlyIssueSimulationPersona].self,
            from: Data(contentsOf: fixtureRoot.appendingPathComponent("personas.json")))
        XCTAssertEqual(readers.count, 6)
        if let directory = ProcessInfo.processInfo.environment["REENCHANTED_REHEARSAL_REPORT_DIR"] {
            let root = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            for reader in readers {
                try encoder.encode(run(reader)).write(to: root.appendingPathComponent(reader.id + ".json"), options: .atomic)
            }
        }
        let absent = try run(XCTUnwrap(readers.first { $0.id == "absent" }))
        XCTAssertTrue(absent.finalContentLedger.receipts.isEmpty)
        let trashed = try run(XCTUnwrap(readers.first { $0.id == "trash" }))
        XCTAssertTrue(trashed.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .dismissed })
        XCTAssertFalse(trashed.finalContentLedger.receipts.contains { $0.contentID == "lesson" && $0.state == .nodeCompleted })
        XCTAssertTrue(trashed.finalJumpState.returned.isEmpty)
    }

    func testRelaunchUsesPersistedNodeAndDoesNotRepeatEntry() throws {
        let fixture = try pack()
        let reader = persona()
        let before = MonthlyIssueAuthoringSimulator.run(pack: fixture, manifestID: "school-door-2027-11", persona: reader,
            from: date(1), through: date(8), sampleHours: [9], calendar: calendar)
        let receipts = try JSONDecoder().decode(AuthoredContentReceiptLedger.self, from: JSONEncoder().encode(before.finalContentLedger))
        let jump = try JSONDecoder().decode(BookJumpState.self, from: JSONEncoder().encode(before.finalJumpState))
        let after = MonthlyIssueAuthoringSimulator.run(pack: fixture, manifestID: "school-door-2027-11", persona: reader,
            from: date(9), through: date(30), calendar: calendar, initialContentLedger: receipts,
            initialLifecycleLedger: before.finalLifecycleLedger, initialJumpState: jump, initialBraidDays: before.braidDays)
        XCTAssertEqual(after.finalContentLedger.receipts.filter { $0.state == .nodeCompleted }.compactMap(\.nodeID),
            ["enter", "choose", "pin-home"])
        XCTAssertNil(after.finalJumpState.active)
        XCTAssertEqual(after.finalJumpState.returned.count, 1)
    }

    func testSavedBranchDoesNotFollowARewrittenChoiceRoute() throws {
        let fixture = try pack()
        var scene = try XCTUnwrap(fixture.storyScenes?.first { $0.id == "lesson" })
        let scope = AuthoredContentScope(scopeID: "school-door-2027-11", runID: "school-door:2027")
        var ledger = AuthoredContentReceiptLedger.empty
        for (node, choice, next) in [("enter", Optional<String>.none, "choose"), ("choose", "pin", "pin-home")] {
            ledger = ledger.recording(AuthoredContentReceipt(contentID: "lesson", occurrenceID: node, channel: .storyScene,
                scope: scope, state: .nodeCompleted, recordedAt: date(8), choiceID: choice, nodeID: node,
                nextNodeID: next, hasFrozenRoute: true))
        }
        scene.nodes?[1].choices[0].nextNodeID = "thread-home"
        XCTAssertEqual(AuthoredStoryProgress.currentNode(scene: scene, contentID: "lesson", scope: scope, ledger: ledger)?.id, "pin-home")
    }

    func testPublicationPaperRemainsPlannedAfterRuntimeRetires() throws {
        let source = try Data(contentsOf: fixtureRoot.appendingPathComponent("delivery-manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(MonthlyIssueDeliveryManifest.self, from: source)
        manifest.issues[0].assets.append(MonthlyIssueDeliveryAsset(id: "school-door-paper-v1",
            kind: .editionPlayPack, scope: .publication,
            remoteURL: URL(string: "https://rehearsal.invalid/monthly-issues/assets/school-door-paper-v1")!,
            fileName: "school-door.editionplay.json", sha256: String(repeating: "a", count: 64), byteCount: 100))
        let afterResidue = manifest.issues[0].residueEndsAt.addingTimeInterval(1)
        let planned = MonthlyIssueDeliveryPlanner.plan(manifest: manifest, now: afterResidue,
            hasMonthlyAccess: true, manifestHost: "rehearsal.invalid")
        XCTAssertEqual(planned.assets.map(\.asset.id), ["school-door-paper-v1"])
        XCTAssertNil(planned.assets.first?.retiresAt)
    }

    /// A newer publisher's asset kind or scope must not blank the shelf for a
    /// reader who has not updated: it is skipped, and everything else installs.
    func testAnUnknownAssetKindOrScopeIsSkippedNotFatal() throws {
        let original = try Data(contentsOf: fixtureRoot.appendingPathComponent("delivery-manifest.json"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var issues = try XCTUnwrap(json["issues"] as? [[String: Any]])
        var assets = try XCTUnwrap(issues[0]["assets"] as? [[String: Any]])
        var future = assets[0]
        future["id"] = "future-kind"
        future["kind"] = "hologramPack"
        future["fileName"] = "future.hologram.json"
        future["remoteURL"] = "https://rehearsal.invalid/monthly-issues/assets/future-kind"
        var elsewhere = assets[0]
        elsewhere["id"] = "future-scope"
        elsewhere["scope"] = "attic"
        elsewhere["fileName"] = "future-scope.reenchantedevents.json"
        elsewhere["remoteURL"] = "https://rehearsal.invalid/monthly-issues/assets/future-scope"
        assets += [future, elsewhere]
        issues[0]["assets"] = assets
        json["issues"] = issues
        let payload = try JSONSerialization.data(withJSONObject: json)
        let key = Curve25519.Signing.PrivateKey()
        let envelope = MonthlyIssueSignedManifestEnvelope(keyID: "test-only", payload: payload.base64EncodedString(),
            signature: try key.signature(for: payload).base64EncodedString())
        let delivery = try MonthlyIssueManifestVerifier.verify(envelopeData: JSONEncoder().encode(envelope),
            publicKeyRawRepresentation: key.publicKey.rawRepresentation)
        let planned = Set(MonthlyIssueDeliveryPlanner.plan(manifest: delivery, now: date(1), hasMonthlyAccess: true,
                                                           manifestHost: "rehearsal.invalid").assets.map(\.asset.id))
        XCTAssertFalse(planned.contains("future-kind"))
        XCTAssertFalse(planned.contains("future-scope"))
        XCTAssertFalse(planned.isEmpty, "the rest of the shelf still installs")
    }

    func testSignedFixtureInstallsAndRetiresOffline() async throws {
        let payload = try Data(contentsOf: fixtureRoot.appendingPathComponent("delivery-manifest.json"))
        let key = Curve25519.Signing.PrivateKey()
        let envelope = MonthlyIssueSignedManifestEnvelope(keyID: "test-only", payload: payload.base64EncodedString(),
            signature: try key.signature(for: payload).base64EncodedString())
        let delivery = try MonthlyIssueManifestVerifier.verify(envelopeData: JSONEncoder().encode(envelope),
            publicKeyRawRepresentation: key.publicKey.rawRepresentation)
        let plan = MonthlyIssueDeliveryPlanner.plan(manifest: delivery, now: date(1), hasMonthlyAccess: true, manifestHost: "rehearsal.invalid")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let content = root.appendingPathComponent("Content")
        let state = root.appendingPathComponent("state.json")
        let source = try Data(contentsOf: fixtureRoot.appendingPathComponent("school-door.reenchantedevents.json"))
        let installed = try await MonthlyIssueAssetInstaller.install(plan: plan, documentsURL: content, stateURL: state, fetch: { _ in source })
        XCTAssertEqual(installed.installedAssetIDs, ["school-door-runtime-v1"])
        // Reopening an unchanged issue must work without downloading its files
        // again, including when the device has lost its network connection.
        let reused = try await MonthlyIssueAssetInstaller.install(plan: plan, documentsURL: content, stateURL: state,
            fetch: { _ in
                XCTFail("An unchanged installed issue should not fetch any asset bytes")
                throw URLError(.notConnectedToInternet)
            })
        XCTAssertTrue(reused.installedAssetIDs.isEmpty)
        let retired = try MonthlyIssueAssetInstaller.retireExpiredAssets(now: delivery.issues[0].residueEndsAt,
            documentsURL: content, stateURL: state)
        XCTAssertEqual(retired, ["school-door-runtime-v1"])
        XCTAssertTrue(MonthlyIssueDeliveryPlanner.plan(manifest: delivery, now: date(1), hasMonthlyAccess: false,
            manifestHost: "rehearsal.invalid").assets.isEmpty)
    }

    func testDownloadedMarkSurvivesRetirementAndSharesOneKeptCopy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = RehearsalFileManager(support: root)
        defer { try? files.removeItem(at: root) }
        let managed = try XCTUnwrap(MonthlyIssueDeliveryPolicy.managedContentDirectory(fileManager: files))
        try files.createDirectory(at: managed, withIntermediateDirectories: true)
        let source = managed.appendingPathComponent(MonthlyIssueDeliveryPolicy.managedFilePrefix + "test-mark.png")
        let pixels = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jYp0AAAAASUVORK5CYII="))
        try pixels.write(to: source)
        let asset = IlluminationAsset(id: "test-mark", assetName: source.path, kind: .doodle,
            tags: [], supportedTemplates: [], defaultOpacity: 1, canTint: false)
        let kept = try MonthlyIssueRetainedMedia.retaining(asset, fileManager: files)
        XCTAssertEqual(kept, try MonthlyIssueRetainedMedia.retaining(asset, fileManager: files))
        let destination = URL(fileURLWithPath: kept.assetName)
        XCTAssertEqual(try files.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path).count, 1)
        let stateURL = root.appendingPathComponent("state.json")
        let state = MonthlyIssueInstallationState(assets: [MonthlyIssueInstalledAsset(id: "test-mark",
            issueID: "rehearsal", fileName: source.lastPathComponent, sourceSHA256: "unused", scope: .runtime,
            retiresAt: date(30))])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: stateURL)
        XCTAssertEqual(try MonthlyIssueAssetInstaller.retireExpiredAssets(now: date(30),
            documentsURL: managed, stateURL: stateURL, fileManager: files), ["test-mark"])
        XCTAssertFalse(files.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: destination), pixels)
        let restored = try JSONDecoder().decode(IlluminationAsset.self, from: JSONEncoder().encode(kept))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: restored.assetName)), pixels)

        // Keeping a mark cannot copy arbitrary private files into the archive.
        let outside = root.appendingPathComponent("outside.png")
        try pixels.write(to: outside)
        var untrusted = asset
        untrusted.assetName = outside.path
        XCTAssertThrowsError(try MonthlyIssueRetainedMedia.retaining(untrusted, fileManager: files))
    }

    func testMonthlyMediaSurvivesContainerMoveAndRetirement() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        let oldContainer = root.appendingPathComponent("old-container")
        let newContainer = root.appendingPathComponent("new-container")
        let oldSupport = oldContainer.appendingPathComponent("Library/Application Support")
        let newSupport = newContainer.appendingPathComponent("Library/Application Support")
        let oldFiles = RehearsalFileManager(support: oldSupport)
        let managed = try XCTUnwrap(MonthlyIssueDeliveryPolicy.managedContentDirectory(fileManager: oldFiles))
        try files.createDirectory(at: managed, withIntermediateDirectories: true)
        let markURL = managed.appendingPathComponent(MonthlyIssueDeliveryPolicy.managedFilePrefix + "test-mark.png")
        let audioURL = managed.appendingPathComponent(MonthlyIssueDeliveryPolicy.managedFilePrefix + "test-radio.m4a")
        let bytes = Data("relocation rehearsal".utf8)
        try bytes.write(to: markURL)
        try bytes.write(to: audioURL)
        let mark = IlluminationAsset(id: "moved", assetName: markURL.path, kind: .doodle,
            tags: [], supportedTemplates: [], defaultOpacity: 1, canTint: false)
        let kept = try MonthlyIssueRetainedMedia.retaining(mark, fileManager: oldFiles)
        try files.moveItem(at: oldContainer, to: newContainer)
        XCTAssertFalse(files.fileExists(atPath: kept.assetName))
        let newManaged = try XCTUnwrap(MonthlyIssueDeliveryPolicy.managedContentDirectory(
            fileManager: RehearsalFileManager(support: newSupport)))
        let playable = try XCTUnwrap(MonthlyIssueDeliveryPolicy.managedAudioURL(
            forPath: audioURL.path, hasMonthlyAccess: true, directory: newManaged))
        XCTAssertEqual(try Data(contentsOf: playable), bytes)
        XCTAssertNil(MonthlyIssueDeliveryPolicy.managedAudioURL(
            forPath: audioURL.path, hasMonthlyAccess: false, directory: newManaged))
        let movedKeep = MonthlyIssueMediaPath.resolving(kept.assetName, supportDirectory: newSupport)
        try files.removeItem(at: newManaged)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: movedKeep)), bytes)
        XCTAssertNil(MonthlyIssueDeliveryPolicy.managedAudioURL(
            forPath: audioURL.path, hasMonthlyAccess: true, directory: newManaged))

        // Both the decoration tag and the archive/print media record use the
        // same resolution when decoded in the current app container.
        let decodedMark = try JSONDecoder().decode(IlluminationAsset.self, from: JSONEncoder().encode(kept))
        XCTAssertEqual(decodedMark.assetName, MonthlyIssueMediaPath.resolving(kept.assetName))
        let media = BookPageMediaAsset(kind: .renderedImageFile, reference: kept.assetName,
            sourceID: "authored-marginalia")
        let decodedMedia = try JSONDecoder().decode(BookPageMediaAsset.self, from: JSONEncoder().encode(media))
        XCTAssertEqual(decodedMedia.reference, decodedMark.assetName)
    }

    func testMonthlyMediaRelocationDoesNotRedirectOtherFilesOrTraversal() throws {
        let support = URL(fileURLWithPath: "/new/Library/Application Support")
        for path in ["MarginaliaGoblinQuestioning", "/private/reader.png",
                     "/old/Library/Application Support/Unrelated/photo.png",
                     "/old/Library/Application Support/MonthlyIssueKeepsakes/not-a-hash.png",
                     "/old/Library/Application Support/MonthlyIssueDelivery/Content/../secret.m4a",
                     "/old/Library/Application Support/MonthlyIssueDelivery/Content/monthly-issue-sub/secret.m4a"] {
            XCTAssertEqual(MonthlyIssueMediaPath.resolving(path, supportDirectory: support), path)
        }
    }
}

private final class RehearsalFileManager: FileManager, @unchecked Sendable {
    let support: URL
    init(support: URL) { self.support = support; super.init() }
    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        directory == .applicationSupportDirectory ? [support] : super.urls(for: directory, in: domainMask)
    }
}
