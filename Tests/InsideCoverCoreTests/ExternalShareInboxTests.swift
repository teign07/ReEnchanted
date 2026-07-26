import XCTest
@testable import InsideCoverCore

final class ExternalShareInboxTests: XCTestCase {
    private func temporaryInbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("external-share-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    func testReceiptRoundTripsInChronologicalOrderAndCanBeAcknowledged() throws {
        let baseURL = try temporaryInbox()
        let later = ExternalShareCapture(
            id: "later",
            capturedAt: Date(timeIntervalSince1970: 200),
            kind: .link,
            title: "Later",
            url: "https://example.com/later",
            sourceName: "example.com"
        )
        let earlier = ExternalShareCapture(
            id: "earlier",
            capturedAt: Date(timeIntervalSince1970: 100),
            kind: .text,
            text: "A strange sentence"
        )

        try ExternalShareInbox.enqueue(later, at: baseURL)
        try ExternalShareInbox.enqueue(earlier, at: baseURL)
        XCTAssertEqual(try ExternalShareInbox.pending(at: baseURL).map(\.id), ["earlier", "later"])

        try ExternalShareInbox.acknowledge(earlier, at: baseURL)
        XCTAssertEqual(try ExternalShareInbox.pending(at: baseURL).map(\.id), ["later"])
    }

    func testAttachmentResolutionCannotEscapeTheInbox() throws {
        let baseURL = try temporaryInbox()
        let safe = ExternalShareCapture.Attachment(
            kind: .image,
            relativePath: "Assets/capture/image.png",
            typeIdentifier: "public.png"
        )
        let escaping = ExternalShareCapture.Attachment(
            kind: .file,
            relativePath: "../outside.pdf",
            typeIdentifier: "com.adobe.pdf"
        )

        XCTAssertNotNil(ExternalShareInbox.resolvedAttachmentURL(safe, at: baseURL))
        XCTAssertNil(ExternalShareInbox.resolvedAttachmentURL(escaping, at: baseURL))
    }

    func testUnpromptedCaptureSeedsInspectibleCurationTags() {
        let capture = ExternalShareCapture(
            kind: .text,
            title: "A weird old trail beside the river",
            text: "Why did someone build this forgotten place?",
            sourceName: "reddit.com"
        )
        let tags = ExternalShareCurationPolicy.tags(for: capture)

        XCTAssertTrue(tags.contains("reader-brought"))
        XCTAssertTrue(tags.contains("unprompted-capture"))
        XCTAssertTrue(tags.contains("external-theme:place"))
        XCTAssertTrue(tags.contains("external-theme:nature"))
        XCTAssertTrue(tags.contains("external-theme:mystery"))
        XCTAssertTrue(tags.contains("external-theme:question"))
    }

    func testPromptedExternalCaptureCountsLikeAKeepNotIndependentDiscovery() {
        let date = Date(timeIntervalSince1970: 1_000)
        var affinity = ReaderLearningAffinity()
        affinity.record(ReaderLearningEvent(
            id: "prompted",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: .broughtFromElsewhere,
            surfaceID: "page",
            sourceID: "external-share:example.com",
            type: .plainPage,
            varietyKey: "example.com",
            hour: 12,
            tags: ["prompted-capture"]
        ))

        XCTAssertEqual(affinity.kept, 1)
        XCTAssertEqual(affinity.broughtFromElsewhere, 0)
        XCTAssertEqual(affinity.rawScore, 3)
    }

    func testLearningRefusalIsEnforcedByTheModelsNotOnlyTheInterface() {
        let date = Date(timeIntervalSince1970: 2_000)
        let forbidden = ReaderLearningEvent(
            id: "forbidden",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: .keepsakeEarned,
            surfaceID: "private-scrap",
            sourceID: "external-share:example.com",
            type: .plainPage,
            varietyKey: "example.com",
            hour: 12,
            tags: [
                ReaderLearningEvent.curationLearningForbiddenTag,
                "book-session-movement:freshSight"
            ]
        )

        var learning = ReaderLearningModel()
        learning.record(forbidden)
        XCTAssertEqual(learning.events.map(\.id), ["forbidden"], "the Page may still function")
        XCTAssertNil(learning.sourceAffinities[forbidden.sourceID])
        XCTAssertEqual(learning.metrics().meaningfulEventCount, 0)
        XCTAssertEqual(learning.momentumMetrics().keepsakesEarned, 0)

        var aliveness = ReaderAlivenessModel.unwritten
        aliveness.ingest(forbidden)
        XCTAssertTrue(aliveness.observations.isEmpty)
        XCTAssertNil(aliveness.causalLedger)
    }

    func testRevokingLearningRemovesAlreadyIngestedAlivenessAndCausalEvidence() {
        let date = Date(timeIntervalSince1970: 3_000)
        let receipt = CausalCurationReceipt(
            id: "page-opportunity",
            policyVersion: CausalCurationReceipt.currentPolicyVersion,
            sessionID: "session",
            movement: .freshSight,
            role: .door,
            chosenSourceID: "external-share:example.com",
            chosenArmID: "private-scrap",
            contextKey: "morning",
            propensity: 0.5,
            candidates: [
                CausalCurationCandidate(
                    sourceID: "external-share:example.com",
                    armID: "private-scrap",
                    weight: 1
                )
            ],
            pressureCost: 0,
            selectedAt: date
        )
        let event = ReaderLearningEvent(
            id: "allowed-then-revoked",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: .keepsakeEarned,
            surfaceID: "private-scrap",
            sourceID: "external-share:example.com",
            type: .plainPage,
            varietyKey: "example.com",
            hour: 12,
            tags: ["book-session-movement:freshSight"],
            causalReceipt: receipt
        )
        var aliveness = ReaderAlivenessModel.unwritten
        aliveness.ingest(event)
        XCTAssertFalse(aliveness.observations.isEmpty)
        XCTAssertEqual(aliveness.causalLedger?.opportunities.count, 1)
        XCTAssertEqual(aliveness.causalLedger?.outcomes.count, 1)

        aliveness.removeLearningEvidence(from: [event])

        XCTAssertTrue(aliveness.observations.isEmpty)
        XCTAssertNil(aliveness.causalLedger)
    }

    func testPromptClockExpiresAndDoesNotAcceptFutureSurfaces() throws {
        let suite = "external-share-prompt-clock-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let surfacedAt = Date(timeIntervalSince1970: 10_000)
        ExternalSharePromptClock.markBookSurface(at: surfacedAt, defaults: defaults)

        XCTAssertTrue(ExternalSharePromptClock.wasRecentlyPrompted(
            at: surfacedAt.addingTimeInterval(3_599),
            defaults: defaults
        ))
        XCTAssertFalse(ExternalSharePromptClock.wasRecentlyPrompted(
            at: surfacedAt.addingTimeInterval(3_601),
            defaults: defaults
        ))
        XCTAssertFalse(ExternalSharePromptClock.wasRecentlyPrompted(
            at: surfacedAt.addingTimeInterval(-1),
            defaults: defaults
        ))
    }

    func testWeavingBoundaryExcludesOnlyTheForbiddenPage() {
        let allowed = BookPage(
            id: "allowed",
            type: .plainPage,
            promptText: "Allowed",
            externalReference: BookPageExternalReference(
                title: "Allowed",
                sourceName: "elsewhere",
                url: "",
                fetchedAt: nil,
                provenance: "reader-initiated-external-share",
                captureID: "a",
                wasPromptedByBook: false,
                learningAllowed: true,
                weavingAllowed: true,
                attachments: nil
            )
        )
        var forbidden = allowed
        forbidden.id = "forbidden"
        forbidden.externalReference?.captureID = "b"
        forbidden.externalReference?.weavingAllowed = false
        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 25, hour: 12)
        )!
        var datedAllowed = allowed
        datedAllowed.createdAt = date
        forbidden.createdAt = date
        let day = BookDay(
            id: BookDay.id(for: date),
            date: Calendar.current.startOfDay(for: date),
            pages: [datedAllowed, forbidden]
        )

        XCTAssertEqual(BraidPromptBuilder.braidEligiblePages(in: day).map(\.id), ["allowed"])
    }

    func testEveryOutsideSparkHasFiveDistinctOutwardDoors() {
        XCTAssertEqual(Set(ExternalSparkContinuation.allCases.map(\.rawValue)).count, 5)
        XCTAssertTrue(ExternalSparkContinuation.allCases.allSatisfy {
            !$0.invitation.isEmpty
        })
        XCTAssertEqual(ExternalSparkContinuation.ask.movementRawValue, "humanOtherness")
        XCTAssertEqual(ExternalSparkContinuation.go.movementRawValue, "livingWorld")
        XCTAssertEqual(ExternalSparkContinuation.notice.movementRawValue, "freshSight")
    }

    func testTrustedWitnessMessageCarriesTheSourceWithoutCreatingAFeed() {
        let message = ExternalSparkContinuation.ask.witnessText(
            title: "A tiny observatory",
            url: "https://reddit.com/r/example"
        )
        XCTAssertTrue(message.contains("A tiny observatory"))
        XCTAssertTrue(message.contains("What does it make you wonder?"))
        XCTAssertTrue(message.contains("https://reddit.com/r/example"))
    }
}
