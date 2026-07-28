import XCTest
@testable import InsideCoverCore

final class LivedEncounterContractTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_100_000)

    func testEveryResolvedExactPageCarriesCapabilityAndEncounterContracts() throws {
        let page = surface(id: "contained-story", type: .narrativeOS)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.play, .wonder],
                effort: .small,
                reach: .insideBook,
                asksReader: true,
                proofModes: [.response]
            ))
            .withResolvedPageCapabilities()

        XCTAssertNotNil(page.payload.metadata[PageCapabilityContract.metadataKey])
        XCTAssertNotNil(page.payload.metadata[LivedEncounterContract.metadataKey])
        XCTAssertEqual(page.livedEncounterContract.mode, .contained)
        XCTAssertFalse(page.livedEncounterContract.mayMintLivedReceipt)
    }

    func testAuthoredEncounterContractRoundTripsThroughStringMetadata() {
        let contract = LivedEncounterContract(
            mode: .invitation,
            encounterID: "lamp-walk",
            invitation: "Walk to the patient lamp and notice what shares its light.",
            returnPrompt: "Bring back one exact companion to the light.",
            acceptedProofModes: [.observation, .photograph],
            facets: [.exactAttention, .worldOtherness],
            earliestFollowUpHours: 36,
            sourceCapabilitySignature: "capability-123"
        )
        let page = surface(id: "authored-encounter")
            .withLivedEncounterContract(contract)

        XCTAssertEqual(page.livedEncounterContract, contract)
        XCTAssertEqual(page.payload.metadata["livedEncounterMode"], "invitation")
        XCTAssertEqual(page.payload.metadata["livedEncounterSignature"], contract.signature)
    }

    func testGenericOutwardPageCanMintReceiptOnlyAfterAllowedEvidenceReturns() throws {
        let page = outwardPage(
            id: "lamp-walk",
            proofModes: [.observation, .photograph]
        )
        let contract = page.livedEncounterContract

        XCTAssertEqual(contract.mode, .invitation)
        XCTAssertTrue(contract.mayMintLivedReceipt)
        XCTAssertNil(LivedQuestReceipt.from(
            surface: page,
            readerInput: "",
            mediaAssets: [],
            completedAt: now
        ), "Opening or keeping an invitation is not lived evidence.")

        let receipt = try XCTUnwrap(LivedQuestReceipt.from(
            surface: page,
            readerInput: "Three moths kept crossing the yellow circle.",
            mediaAssets: [],
            completedAt: now
        ))

        XCTAssertEqual(receipt.kind, .livedEncounter)
        XCTAssertEqual(receipt.questID, contract.encounterID)
        XCTAssertEqual(receipt.evidenceModes, [.observation])
        XCTAssertEqual(receipt.encounterContractSignature, contract.signature)
        XCTAssertEqual(receipt.followUpDueAt, now.addingTimeInterval(48 * 3_600))
        XCTAssertTrue(receipt.hasAnyProof)
        XCTAssertTrue(receipt.facets.contains(.exactAttention))
    }

    func testInBookResponseCannotLaunderItselfIntoLivedEvidence() {
        let page = surface(id: "story-choice", type: .narrativeOS)
            .withPageCapabilities(PageCapabilityContract(
                emotionalFunctions: [.play],
                effort: .small,
                reach: .insideBook,
                asksReader: true,
                proofModes: [.response]
            ))

        XCTAssertEqual(page.livedEncounterContract.mode, .contained)
        XCTAssertNil(LivedQuestReceipt.from(
            surface: page,
            readerInput: "I chose the red door.",
            mediaAssets: [],
            completedAt: now
        ))
    }

    func testResponseOnlyOutwardContractCannotClaimLivedProof() {
        let page = outwardPage(id: "bad-proof-shape", proofModes: [.response])

        XCTAssertEqual(page.livedEncounterContract.acceptedProofModes, [])
        XCTAssertFalse(page.livedEncounterContract.mayMintLivedReceipt)
        XCTAssertNil(LivedQuestReceipt.from(
            surface: page,
            readerInput: "I tapped an answer.",
            mediaAssets: [],
            completedAt: now
        ))
    }

    func testPhotographCanSatisfyPhotoSpecificOutwardContract() throws {
        let page = outwardPage(id: "window-light", proofModes: [.photograph])
        let photo = BookPageMediaAsset(
            kind: .photoLibraryAsset,
            reference: "local-photo-reference",
            metadata: ["proofPhoto": "true"]
        )

        let receipt = try XCTUnwrap(LivedQuestReceipt.from(
            surface: page,
            readerInput: "",
            mediaAssets: [photo],
            completedAt: now
        ))

        XCTAssertEqual(receipt.kind, .livedEncounter)
        XCTAssertEqual(receipt.evidenceModes, [.photograph])
        XCTAssertTrue(receipt.hasVisualProof)
        XCTAssertTrue(receipt.hasAnyProof)
    }

    func testDecorativePageImageCannotSatisfyPhotographProof() {
        let page = outwardPage(id: "illustrated-invitation", proofModes: [.photograph])
        let decorativeImage = BookPageMediaAsset(
            kind: .bundledImage,
            reference: "LampIllustration"
        )

        XCTAssertNil(LivedQuestReceipt.from(
            surface: page,
            readerInput: "",
            mediaAssets: [decorativeImage],
            completedAt: now
        ))
    }

    func testLegacyReceiptDecodesWithoutUniversalContractFields() throws {
        let receipt = LivedQuestReceipt(
            kind: .playfulMission,
            questID: "legacy-mission",
            title: "The Old Walk",
            invitation: "Go outside.",
            proofPrompt: "What happened?",
            facets: [.exactAttention],
            sourceTags: ["walk"],
            hasWrittenProof: true,
            hasVisualProof: false,
            completedAt: now,
            wasPromptedByBook: true
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any]
        )
        object.removeValue(forKey: "evidenceModes")
        object.removeValue(forKey: "encounterContractSignature")
        object.removeValue(forKey: "followUpDueAt")

        let decoded = try JSONDecoder().decode(
            LivedQuestReceipt.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.evidenceModes)
        XCTAssertNil(decoded.encounterContractSignature)
        XCTAssertNil(decoded.followUpDueAt)
        XCTAssertTrue(decoded.hasAnyProof)
        XCTAssertEqual(decoded.resolvedEvidenceModes, [.observation])
    }

    func testUniversalReceiptFeedsExistingLongGameEvidenceBridge() throws {
        let pageSurface = outwardPage(
            id: "ordinary-light",
            proofModes: [.observation]
        )
        let receipt = try XCTUnwrap(LivedQuestReceipt.from(
            surface: pageSurface,
            readerInput: "The rain had made every fire escape sound different.",
            mediaAssets: [],
            completedAt: now
        ))
        let keptPage = BookPage(
            id: "ordinary-light-proof",
            type: .location,
            createdAt: now,
            promptText: receipt.title,
            userInput: "The rain had made every fire escape sound different.",
            sourceID: "ordinary-light",
            livedQuestReceipt: receipt
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [
            BookDay(id: BookDay.id(for: now), date: now, pages: [keptPage])
        ]

        let updated = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: now.addingTimeInterval(-86_400)),
            inputs: inputs,
            now: now.addingTimeInterval(86_400)
        )
        let evidence = try XCTUnwrap(updated.longGame?.evidence)
            .filter { $0.id.contains("long-game-lived-quest-livedEncounter") }

        XCTAssertFalse(evidence.isEmpty)
        XCTAssertTrue(evidence.allSatisfy(\.wasPromptedByBook))
        XCTAssertTrue(evidence.allSatisfy { $0.kind == .completedExperiment })
        XCTAssertTrue(evidence.allSatisfy { $0.evidencePageIDs == [keptPage.id] })
    }

    private func outwardPage(
        id: String,
        proofModes: [PageCapabilityProofMode]
    ) -> SurfacePage {
        surface(id: id, type: .location)
            .withPageCapabilities(PageCapabilityContract(
                supportedMovements: [.freshSight, .livingWorld],
                emotionalFunctions: [.notice, .wonder],
                effort: .small,
                reach: .nearbyWorld,
                mobility: .shortDistance,
                estimatedMinutes: 8,
                asksReader: true,
                pressureCost: 0.40,
                proofModes: proofModes
            ))
    }

    private func surface(
        id: String,
        type: BookPageType = .location
    ) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: "encounter-tests",
            intent: .capture,
            renderStyle: .promptCard,
            score: 60,
            reason: "An exact encounter is possible.",
            prompt: "Follow the patient light.",
            detail: "Step outside and notice what shares the nearest pool of light.",
            payload: BookPagePayload(
                headline: "The Patient Light",
                body: "Step outside and notice what shares the nearest pool of light.",
                metadata: ["noveltyKey": id]
            )
        )
    }
}
