import XCTest
@testable import InsideCoverCore

final class LivedQuestReceiptTests: XCTestCase {
    func testPlayfulMissionBecomesTypedLivedReceipt() {
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let surface = SurfacePage(
            id: "mission-surface",
            type: .souvenir,
            sourceID: "playful-mission",
            intent: .capture,
            renderStyle: .promptCard,
            score: 70,
            reason: "A mission is awake.",
            prompt: "The Long Way",
            detail: "Take the long way.",
            payload: BookPagePayload(
                headline: "The Long Way",
                body: "Take the long way and notice what the shortcut hid.",
                metadata: [
                    "playfulMissionID": "motion-long-way",
                    "playfulMissionTitle": "The Long Way",
                    "missionPrompt": "Take the long way and notice what the shortcut hid.",
                    "souvenirPrompt": "Write what the shortcut was hiding.",
                    "tags": "movement,route,detour,public"
                ]
            )
        )

        let receipt = LivedQuestReceipt.from(
            surface: surface,
            readerInput: "A blue door with a brass fox.",
            mediaAssets: [],
            completedAt: completedAt
        )

        XCTAssertEqual(receipt?.kind, .playfulMission)
        XCTAssertEqual(receipt?.questID, "motion-long-way")
        XCTAssertEqual(receipt?.title, "The Long Way")
        XCTAssertEqual(receipt?.proofPrompt, "Write what the shortcut was hiding.")
        XCTAssertEqual(receipt?.hasWrittenProof, true)
        XCTAssertEqual(receipt?.hasVisualProof, false)
        XCTAssertEqual(receipt?.completedAt, completedAt)
        XCTAssertTrue(receipt?.facets.contains(.exactAttention) == true)
        XCTAssertTrue(receipt?.facets.contains(.selfAuthorship) == true)
    }

    func testVisualWickerProofKeepsItsLifeFacingFacets() {
        let surface = SurfacePage(
            id: "wicker-surface",
            type: .wickerDare,
            sourceID: "wicker-dare",
            intent: .capture,
            renderStyle: .promptCard,
            score: 70,
            reason: "Wicker objected.",
            prompt: "Visible Mending",
            detail: "Repair one small thing.",
            payload: BookPagePayload(
                headline: "Visible Mending",
                body: "Mend one thing somebody else will meet.",
                metadata: [
                    "wickerDareID": "visible-mending",
                    "wickerDareTitle": "Visible Mending",
                    "wickerDarePrompt": "Mend one thing somebody else will meet.",
                    "proofPrompt": "Keep a photograph of the mend.",
                    "tags": "repair,making,kindness,person"
                ]
            )
        )
        // The reader's own photograph of the mend. A bare rendered image file
        // is a Book-made plate and is deliberately not visual proof.
        let photo = BookPageMediaAsset(
            kind: .photoLibraryAsset,
            reference: "/tmp/mend.jpg"
        )

        let receipt = LivedQuestReceipt.from(
            surface: surface,
            readerInput: "",
            mediaAssets: [photo],
            completedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        XCTAssertEqual(receipt?.kind, .wickerDare)
        XCTAssertEqual(receipt?.hasWrittenProof, false)
        XCTAssertEqual(receipt?.hasVisualProof, true)
        XCTAssertTrue(receipt?.facets.contains(.selfAuthorship) == true)
        XCTAssertTrue(receipt?.facets.contains(.livingConnection) == true)
    }

    func testPactErrandRecognizesCanonicalErrandMetadata() throws {
        let completedAt = Date(timeIntervalSince1970: 1_800_000_200)
        let surface = SurfacePage(
            id: "pact-errand-page",
            type: .pactErrand,
            sourceID: "pact-errand",
            intent: .capture,
            renderStyle: .loreLetter,
            score: 77,
            reason: "A talisman sent the reader into the real day.",
            prompt: "A Talisman's Errand",
            detail: "Leave a kind note where somebody will find it.",
            payload: BookPagePayload(
                headline: "A Talisman's Errand",
                body: "Bring back a true field report.",
                metadata: [
                    "errandID": "pact-errand-kindness",
                    "terms": "Leave a kind note where somebody will find it.",
                    "tags": "pact-errand,pact-war,kindness,person"
                ]
            )
        )

        let receipt = try XCTUnwrap(
            LivedQuestReceipt.from(
                surface: surface,
                readerInput: "I left one beneath the blue mug in the break room.",
                mediaAssets: [],
                completedAt: completedAt
            )
        )

        XCTAssertEqual(receipt.kind, .pactErrand)
        XCTAssertEqual(receipt.questID, "pact-errand-kindness")
        XCTAssertEqual(receipt.invitation, "Leave a kind note where somebody will find it.")
        XCTAssertEqual(receipt.proofPrompt, "Leave a kind note where somebody will find it.")
        XCTAssertTrue(receipt.facets.contains(.livingConnection))
        XCTAssertTrue(receipt.hasWrittenProof)
    }

    func testOrdinaryKeepDoesNotBecomeQuestReceipt() {
        let surface = SurfacePage(
            id: "plain",
            type: .plainPage,
            sourceID: "plain-page",
            intent: .capture,
            renderStyle: .promptCard,
            score: 60,
            reason: "A blank page.",
            prompt: "Plain Page",
            detail: "",
            payload: BookPagePayload(headline: "Plain Page", body: "")
        )

        XCTAssertNil(LivedQuestReceipt.from(
            surface: surface,
            readerInput: "Unassigned noticing.",
            mediaAssets: [],
            completedAt: Date()
        ))
    }

    func testElectiveReceiptInfersFacetsFromTheActualQuest() {
        let completedAt = Date(timeIntervalSince1970: 1_800_000_300)
        let elective = UnwrittenElective(
            id: "elective-pass-the-glint",
            characterID: "penny",
            characterName: "Penny",
            title: "Pass the Glint",
            ask: "Make one tiny wonderful thing and share it with another person.",
            whyItMatters: "Wonder becomes less private without becoming a performance.",
            practiceShape: "Photograph what you made and write what you passed along.",
            createdAt: completedAt.addingTimeInterval(-86_400),
            completedAt: completedAt,
            proof: "I made a paper moth and left it for my neighbor.",
            proofPhotoURL: "file:///tmp/paper-moth.jpg"
        )

        let receipt = LivedQuestReceipt.from(
            elective: elective,
            completedAt: completedAt
        )

        XCTAssertEqual(receipt.kind, .elective)
        XCTAssertEqual(receipt.questID, elective.id)
        XCTAssertTrue(receipt.facets.contains(.selfAuthorship))
        XCTAssertTrue(receipt.facets.contains(.livingConnection))
        XCTAssertTrue(receipt.hasWrittenProof)
        XCTAssertTrue(receipt.hasVisualProof)
        XCTAssertEqual(receipt.completedAt, completedAt)
    }

    func testLegacyBookPageDecodesWithoutReceipt() throws {
        let page = BookPage(
            id: "legacy",
            type: .souvenir,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            promptText: "Keep one thing.",
            userInput: "A red leaf.",
            sourceID: "souvenir"
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(page)) as? [String: Any]
        )
        object.removeValue(forKey: "livedQuestReceipt")

        let decoded = try JSONDecoder().decode(
            BookPage.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.livedQuestReceipt)
        XCTAssertEqual(decoded.userInput, "A red leaf.")
    }

    func testLivedReceiptFeedsLongGameAsPromptedPractice() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let receipt = LivedQuestReceipt(
            kind: .playfulMission,
            questID: "motion-long-way",
            title: "The Long Way",
            invitation: "Take the long way.",
            proofPrompt: "Write what the shortcut hid.",
            facets: [.exactAttention, .selfAuthorship],
            sourceTags: ["detour", "movement"],
            hasWrittenProof: true,
            hasVisualProof: false,
            completedAt: start.addingTimeInterval(86_400),
            wasPromptedByBook: true
        )
        let page = BookPage(
            id: "mission-proof",
            type: .souvenir,
            createdAt: receipt.completedAt,
            promptText: receipt.title,
            userInput: "The shortcut hid a blue door with a brass fox.",
            tags: ["playful-mission"],
            sourceID: "playful-mission",
            livedQuestReceipt: receipt
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [
            BookDay(
                id: BookDay.id(for: receipt.completedAt),
                date: receipt.completedAt,
                pages: [page]
            )
        ]

        let updated = BookInteriorEngine.reconciled(
            BookInteriorState(awakenedAt: start),
            inputs: inputs,
            now: start.addingTimeInterval(2 * 86_400)
        )
        let evidence = try XCTUnwrap(updated.longGame?.evidence)
        let questEvidence = evidence.filter { $0.id.contains("long-game-lived-quest") }

        XCTAssertEqual(Set(questEvidence.map(\.capacity)), [.spontaneousAttention, .selfAuthoredAction])
        XCTAssertTrue(questEvidence.allSatisfy(\.wasPromptedByBook))
        XCTAssertTrue(questEvidence.allSatisfy { $0.kind == .completedExperiment })
        XCTAssertTrue(questEvidence.allSatisfy { $0.evidencePageIDs == ["mission-proof"] })
    }

    func testLivedReceiptEarnsSpecificLaterBookRememberedReturn() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let completedAt = now.addingTimeInterval(-4 * 86_400)
        let receipt = LivedQuestReceipt(
            kind: .playfulMission,
            questID: "motion-long-way",
            title: "The Long Way",
            invitation: "Take the long way.",
            proofPrompt: "Write what the shortcut hid.",
            facets: [.exactAttention, .selfAuthorship],
            sourceTags: ["detour", "movement"],
            hasWrittenProof: true,
            hasVisualProof: false,
            completedAt: completedAt,
            wasPromptedByBook: true
        )
        let page = BookPage(
            id: "mission-proof-return",
            type: .souvenir,
            createdAt: completedAt,
            promptText: receipt.title,
            userInput: "The shortcut hid a blue door with a brass fox.",
            tags: ["playful-mission"],
            sourceID: "playful-mission",
            livedQuestReceipt: receipt
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [
            BookDay(id: BookDay.id(for: completedAt), date: completedAt, pages: [page])
        ]
        let today = BookDay.day(containing: now)

        let visitation = try XCTUnwrap(BookRememberedEngine.visitation(
            from: [page],
            day: today,
            inputs: inputs,
            now: now
        ))
        let surface = visitation.surface(
            source: BookPageSourceRegistry.source(for: .bookRemembered),
            day: today,
            now: now
        )

        XCTAssertEqual(visitation.page.id, page.id)
        XCTAssertTrue(visitation.reason.contains("A checkmark is too small for that"))
        XCTAssertTrue(visitation.action.contains("No rerun"))
        XCTAssertEqual(surface.payload.metadata["livedQuestReturn"], "true")
        XCTAssertEqual(surface.payload.metadata["livedQuestID"], "motion-long-way")
        XCTAssertTrue(surface.payload.body.contains("You did this in real life"))
        XCTAssertTrue(surface.payload.body.contains("I kept these parts too"))
    }
}
