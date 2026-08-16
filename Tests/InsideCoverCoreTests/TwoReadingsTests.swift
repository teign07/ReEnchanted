import XCTest
@testable import InsideCoverCore

final class TwoReadingsTests: XCTestCase {
    func testClassProfessorsAreInCastAndRelationshipLoom() {
        let professorIDs = Set([
            "lydia-boggle",
            "professor-kyle-momort",
            "professor-eleanor-euphony",
            "professor-vivian-villanelle",
            "professor-cedric-stonebrook",
            "professor-luna-wispwood",
            "professor-permancer"
        ])
        let castIDs = Set(NarrativePackRegistry.entities.map(\.id))
        XCTAssertTrue(professorIDs.isSubset(of: castIDs))

        let graph = NarrativeGraphData.loom(
            entities: NarrativePackRegistry.entities,
            relationships: NarrativePackRegistry.relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: [:]
        )
        let graphNodeIDs = Set(graph.nodes.map(\.id))
        let graphEdgeIDs = Set(graph.edges.flatMap { [$0.sourceID, $0.targetID] })

        XCTAssertTrue(professorIDs.isSubset(of: graphNodeIDs))
        XCTAssertTrue(professorIDs.isSubset(of: graphEdgeIDs))
    }

    func testStudentCastPackIsInCastAndRelationshipLoom() throws {
        let studentIDs = Set([
            "serenity-brown",
            "finn-bridges",
            "lysander-mosswood",
            "damien-nights",
            "melisande-blackwood",
            "min-seo-kim"
        ])
        let cast = NarrativePackRegistry.entities
        let castIDs = Set(cast.map(\.id))
        XCTAssertTrue(studentIDs.isSubset(of: castIDs))

        let serenity = try XCTUnwrap(cast.first { $0.id == "serenity-brown" })
        XCTAssertLessThanOrEqual(serenity.belief, 20, "Serenity should start at normal active-student Belief, not prior Bond-tier investment.")
        for id in studentIDs {
            let student = try XCTUnwrap(cast.first { $0.id == id })
            XCTAssertEqual(student.kind, .character)
            XCTAssertNotNil(student.chapter)
            XCTAssertFalse(student.unwrittenInterest?.isEmpty ?? true)
            XCTAssertFalse(student.traits.isEmpty)
            XCTAssertFalse(student.quirks.isEmpty)
            XCTAssertFalse(student.faults.isEmpty)
            XCTAssertFalse(student.beliefs.isEmpty)
            XCTAssertFalse(student.goals.isEmpty)
            XCTAssertTrue(student.tags.contains("student"))
            XCTAssertTrue(student.tags.contains("active-cast"))
        }

        let threadIDs = Set(NarrativePackRegistry.threads.map(\.id))
        XCTAssertTrue(Set([
            "tidecrest-finds-its-laugh",
            "honorable-rivalry",
            "wickers-crew-organizes",
            "mossbloom-walks-gently"
        ]).isSubset(of: threadIDs))

        let graph = NarrativeGraphData.loom(
            entities: cast,
            relationships: NarrativePackRegistry.relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: [:]
        )
        let graphNodeIDs = Set(graph.nodes.map(\.id))
        let graphEdgeIDs = Set(graph.edges.flatMap { [$0.sourceID, $0.targetID] })

        XCTAssertTrue(studentIDs.isSubset(of: graphNodeIDs))
        XCTAssertTrue(studentIDs.isSubset(of: graphEdgeIDs))
    }

    func testSelectsAPairFromTheBundledCast() {
        let pair = DisagreementEngine.select(
            entities: NarrativePackRegistry.entities,
            relationships: NarrativePackRegistry.relationships,
            evidenceText: "tired, heavy, rest, sleep: the body is asking for something"
        )
        let unwrapped = try? XCTUnwrap(pair)
        XCTAssertNotNil(unwrapped)
        XCTAssertNotEqual(pair?.aID, pair?.bID, "two distinct characters")
        XCTAssertFalse(pair?.aName.isEmpty ?? true)
    }

    func testPairIsDynamicNotHardcoded() {
        // Different evidence can surface different pairs (the choice responds to
        // what's actually going on), and the pairKey is order-independent.
        let bodyPair = DisagreementEngine.select(
            entities: NarrativePackRegistry.entities,
            relationships: NarrativePackRegistry.relationships,
            evidenceText: "tired body ache sleep rest fuel heavy weather"
        )
        let patternPair = DisagreementEngine.select(
            entities: NarrativePackRegistry.entities,
            relationships: NarrativePackRegistry.relationships,
            evidenceText: "pattern notice theme constellation again always proof evidence record"
        )
        XCTAssertNotNil(bodyPair)
        XCTAssertNotNil(patternPair)
        if let bodyPair {
            XCTAssertEqual(bodyPair.pairKey, "\(min(bodyPair.aID, bodyPair.bID))-\(max(bodyPair.aID, bodyPair.bID))")
        }
    }

    func testRecentlySeenPairStepsBack() {
        let entities = NarrativePackRegistry.entities
        let evidence = "tired body rest sleep heavy"
        let first = DisagreementEngine.select(entities: entities, relationships: NarrativePackRegistry.relationships, evidenceText: evidence)
        guard let first else { return XCTFail("no pair") }
        let history: [String: SurfaceHistoryRecord] = [
            "tworeadings:\(first.pairKey)": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        ]
        let second = DisagreementEngine.select(
            entities: entities, relationships: NarrativePackRegistry.relationships,
            evidenceText: evidence, surfaceHistory: history
        )
        XCTAssertNotEqual(second?.pairKey, first.pairKey, "a freshly-seen pair yields to another")
    }

    func testAdapterSurfacesWithEnoughEvidence() {
        let adapter = TwoReadingsPageSourceAdapter()
        let now = Date()
        let inputs = BookSourceInputs.empty.withMatureLibrary(now: now)
        let pages = [
            BookPage(type: .mood, promptText: "weather", userInput: "Tired and heavy today", tags: ["tired"]),
            BookPage(type: .diary, promptText: "now", userInput: "Did not sleep well", tags: ["sleep"]),
            BookPage(type: .souvenir, promptText: "one line", userInput: "The kettle again", tags: ["kettle"])
        ]
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: pages)
        let surfaced = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertEqual(surfaced.first?.type, .twoReadings)
        XCTAssertFalse(surfaced.first?.payload.metadata["entityAID"]?.isEmpty ?? true)
        XCTAssertFalse(surfaced.first?.payload.metadata["entityAProfile"]?.isEmpty ?? true)
        XCTAssertTrue(surfaced.first?.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Beliefs:") == true)
        XCTAssertTrue(surfaced.first?.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Blind spots and faults:") == true)
        XCTAssertEqual(surfaced.first?.varietyKey, "tworeadings:\(surfaced.first!.payload.metadata["pairID"]!)")
    }

    func testAdapterLetsCastArgueAboutReaderPhotoWithoutCallingLabelsReaderWords() throws {
        let adapter = TwoReadingsPageSourceAdapter()
        let now = Date()
        let inputs = BookSourceInputs.empty.withMatureLibrary(now: now)
        let photo = BookPage(
            id: "reader-photo",
            type: .plainPage,
            createdAt: now,
            promptText: "Original Photograph",
            userInput: "",
            tags: ["plain-photo", "unedited-photo"],
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    id: "photo",
                    kind: .renderedImageFile,
                    reference: "/private/mitten.jpg",
                    metadata: [
                        "attentionSubject": "a red mitten",
                        "attentionScene": "an empty bus seat"
                    ]
                )
            ]
        )
        let day = BookDay(
            id: BookDay.id(for: now),
            date: Calendar.current.startOfDay(for: now),
            pages: [photo]
        )

        let surface = try XCTUnwrap(adapter.candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        ).first)

        XCTAssertEqual(surface.payload.metadata["anchorPageID"], "reader-photo")
        XCTAssertEqual(surface.payload.metadata["anchorPageEvidenceKind"], "photograph")
        XCTAssertEqual(surface.payload.metadata["anchorPageMayQuote"], "0")
        XCTAssertEqual(surface.payload.metadata["anchorPageAuthored"], "0")
        XCTAssertTrue(surface.payload.metadata["anchorPageText"]?.contains("red mitten") == true)
    }

    func testAdapterRestsAfterSourceRecentlySurfaced() {
        let adapter = TwoReadingsPageSourceAdapter()
        let now = Date()
        let pages = [
            BookPage(type: .mood, promptText: "weather", userInput: "Tired and heavy today", tags: ["tired"]),
            BookPage(type: .diary, promptText: "now", userInput: "Did not sleep well", tags: ["sleep"]),
            BookPage(type: .souvenir, promptText: "one line", userInput: "The kettle again", tags: ["kettle"])
        ]
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: pages)
        var inputs = BookSourceInputs.empty
        inputs.surfaceHistory = [
            "source:two-readings": SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-60), recentShowCount: 1)
        ]

        let surfaced = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertTrue(surfaced.isEmpty, "swiping or serving one Two Readings page should rest the whole source")
    }

    func testPreferencesCanDismissTwoReadingsBySource() {
        let page = SurfacePage(
            id: "two-readings-alpha-beta-today",
            type: .twoReadings,
            sourceID: "two-readings",
            intent: .reflect,
            renderStyle: .promptCard,
            score: 76,
            reason: "test",
            prompt: "The Two Readings",
            detail: "test",
            payload: BookPagePayload(
                headline: "The Two Readings",
                body: "test",
                metadata: ["pairID": "alpha-beta"]
            )
        )
        let preferences = CuratorSurfacePreferences(dismissedSurfaceIDs: ["source:two-readings"])
        XCTAssertFalse(preferences.allows(page))
    }

    private func character(_ id: String, belief: Int = 30) -> NarrativeWorldEntity {
        NarrativeWorldEntity(id: id, packID: "test", name: id, kind: .character, belief: belief, narrativeWeight: 20)
    }

    func testFieldWeaveGrowsTiesAmongAllPairs() {
        var field: [String: RelationshipTie] = [:]
        RelationshipFieldEngine.weave(into: &field, entityIDs: ["a", "b", "c"], warmth: 1, familiarity: 1)
        XCTAssertEqual(field.count, 3, "every pair among the three is woven")
        let ab = field[NarrativeGraphData.relationshipPairKey("a", "b")]
        XCTAssertEqual(ab?.warmth, 1)
        XCTAssertEqual(ab?.familiarity, 1)
        // Weaving again accumulates.
        RelationshipFieldEngine.weave(into: &field, entityIDs: ["a", "b"], warmth: 1, familiarity: 1)
        XCTAssertEqual(field[NarrativeGraphData.relationshipPairKey("a", "b")]?.warmth, 2)
    }

    func testFieldSynthesizesAThreadWhereThereWasNone() {
        // Two characters with no authored edge get a thread once the field connects them.
        let entities = [character("alpha"), character("beta")]
        var field: [String: RelationshipTie] = [:]
        RelationshipFieldEngine.weave(into: &field, entityIDs: ["alpha", "beta"], tension: 6, familiarity: 1)
        let loom = NarrativeGraphData.loom(
            entities: entities, relationships: [], beliefOffsets: [:], relationshipField: field
        )
        let edge = loom.edges.first { Set([$0.sourceID, $0.targetID]) == Set(["alpha", "beta"]) }
        XCTAssertNotNil(edge, "an emergent thread is drawn between the two")
        XCTAssertLessThan(edge?.warmth ?? 1, 0, "a tense pair reads as tension")
        XCTAssertEqual(loom.nodes.count, 2, "both appear even with no authored edge")
    }

    func testFieldCoolsAnExistingThread() {
        let entities = NarrativePackRegistry.entities
        let relationships = NarrativePackRegistry.relationships
        func vellumInkrest(_ graph: NarrativeGraphData) -> GraphEdge? {
            graph.edges.first { Set([$0.sourceID, $0.targetID]) == Set(["dr-vellum", "dr-inkrest"]) }
        }
        guard let plain = vellumInkrest(NarrativeGraphData.loom(
            entities: entities,
            relationships: relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: [:]
        )) else {
            return
        }
        var field: [String: RelationshipTie] = [:]
        RelationshipFieldEngine.weave(into: &field, entityIDs: ["dr-vellum", "dr-inkrest"], tension: 6)
        let judged = vellumInkrest(NarrativeGraphData.loom(
            entities: entities,
            relationships: relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: [:],
            relationshipField: field
        ))
        XCTAssertNotNil(judged)
        XCTAssertLessThan(judged!.warmth, plain.warmth, "tension cools the existing thread")
        XCTAssertGreaterThanOrEqual(judged!.strength, plain.strength, "and thickens it")
    }

    func testAdapterStaysQuietWithoutEvidence() {
        let adapter = TwoReadingsPageSourceAdapter()
        let inputs = BookSourceInputs.empty
        let day = BookDay.today()
        XCTAssertTrue(adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date()).isEmpty)
    }

    func testCastBondAdapterSurfacesAllianceWhenWarmthCrossesMilestone() {
        let adapter = CastBondPageSourceAdapter()
        var inputs = BookSourceInputs.empty.withMatureLibrary()
        inputs.relationshipField = [
            NarrativeGraphData.relationshipPairKey("dr-vellum", "dr-inkrest"): RelationshipTie(warmth: CastBondEngine.milestone, tension: 0, familiarity: 3)
        ]
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())

        XCTAssertEqual(pages.first?.type, .castBond)
        XCTAssertEqual(pages.first?.payload.metadata["bondKind"], CastBondKind.alliance.rawValue)
        XCTAssertTrue(pages.first?.payload.metadata["tags"]?.contains("cast-bond:") ?? false)
        XCTAssertTrue(pages.first?.payload.metadata["tags"]?.contains("entity:dr-vellum") ?? false)
        XCTAssertTrue(pages.first?.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Dr. Elowen Vellum") == true)
        XCTAssertTrue(pages.first?.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Dr. Selene Inkrest") == true)
    }

    func testCastBondAdapterSurfacesRivalryWhenTensionCrossesMilestone() {
        let adapter = CastBondPageSourceAdapter()
        var inputs = BookSourceInputs.empty.withMatureLibrary()
        inputs.relationshipField = [
            NarrativeGraphData.relationshipPairKey("dr-vellum", "dr-inkrest"): RelationshipTie(warmth: 1, tension: CastBondEngine.milestone + 1, familiarity: 3)
        ]
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())

        XCTAssertEqual(pages.first?.payload.metadata["bondKind"], CastBondKind.rivalry.rawValue)
        XCTAssertEqual(pages.first?.payload.headline, "A Rivalry Erupts")
    }

    func testCastBondAdapterDoesNotRepeatKeptMilestone() {
        let adapter = CastBondPageSourceAdapter()
        let pairKey = NarrativeGraphData.relationshipPairKey("dr-vellum", "dr-inkrest")
        let firedKey = "\(pairKey):\(CastBondKind.alliance.rawValue):1"
        let kept = BookPage(
            type: .castBond,
            promptText: "An Alliance Forms",
            userInput: "The web changed.",
            tags: ["cast-bond", "cast-bond:\(firedKey)", "entity:dr-vellum", "entity:dr-inkrest"]
        )
        let day = BookDay(id: BookDay.id(for: Date()), date: Calendar.current.startOfDay(for: Date()), pages: [kept])
        var inputs = BookSourceInputs.empty
        inputs.days = [day]
        inputs.relationshipField = [
            pairKey: RelationshipTie(warmth: CastBondEngine.milestone, tension: 0, familiarity: 3)
        ]

        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())
        XCTAssertTrue(pages.isEmpty)
    }
}
