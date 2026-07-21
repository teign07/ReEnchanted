import XCTest
@testable import InsideCoverCore

final class MagicMomentTests: XCTestCase {
    func testGovernorWarmsOnlyFromDistinctMeaningfulActions() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var state = MagicMomentState()

        state = MagicMomentGovernor.recordingMeaningfulAction(state, key: "keep:a", now: start)
        XCTAssertEqual(state.sessionsSinceMoment, 1)
        XCTAssertFalse(state.isArmed)

        // Lifecycle retries and repeated delivery of the same keep do nothing.
        state = MagicMomentGovernor.recordingMeaningfulAction(
            state,
            key: "keep:a",
            now: start.addingTimeInterval(60)
        )
        XCTAssertEqual(state.sessionsSinceMoment, 1)

        state = MagicMomentGovernor.recordingMeaningfulAction(
            state,
            key: "keep:b",
            now: start.addingTimeInterval(1_300)
        )
        XCTAssertEqual(state.sessionsSinceMoment, 2)
        XCTAssertFalse(state.isArmed)

        state = MagicMomentGovernor.recordingMeaningfulAction(
            state,
            key: "compass:c",
            now: start.addingTimeInterval(2_600)
        )
        XCTAssertEqual(state.sessionsSinceMoment, 3)
        XCTAssertTrue(state.isArmed)
    }

    func testGovernorPersistsUntilConsumedAndThenNeedsFreshAttention() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var state = MagicMomentState()
        for action in 0..<3 {
            state = MagicMomentGovernor.recordingMeaningfulAction(
                state,
                key: "keep:\(action)",
                now: start.addingTimeInterval(TimeInterval(action * 1_300))
            )
        }

        XCTAssertTrue(state.isArmed)
        XCTAssertEqual(state.sessionsSinceMoment, 3)

        state = MagicMomentGovernor.consuming(state, key: "semantic:harbor", now: start.addingTimeInterval(6_600))
        XCTAssertFalse(state.isArmed)
        XCTAssertEqual(state.sessionsSinceMoment, 0)
        XCTAssertEqual(state.lastMomentKey, "semantic:harbor")

        state = MagicMomentGovernor.recordingMeaningfulAction(
            state,
            key: "keep:fresh",
            now: start.addingTimeInterval(7_000)
        )
        XCTAssertEqual(state.sessionsSinceMoment, 1)
        XCTAssertFalse(state.isArmed)
    }

    func testWhisperCadenceMapsToOneMorningPromptAndOneEveningReturn() {
        XCTAssertEqual(
            BookWhisperCadence.resolved(bookWhispersEnabled: false, promptWhispersEnabled: true),
            .morning
        )
        XCTAssertEqual(
            BookWhisperCadence.resolved(bookWhispersEnabled: true, promptWhispersEnabled: false),
            .evening
        )
        XCTAssertEqual(
            BookWhisperCadence.resolved(bookWhispersEnabled: true, promptWhispersEnabled: true),
            .both
        )
        XCTAssertEqual(
            BookWhisperCadence.resolved(bookWhispersEnabled: false, promptWhispersEnabled: false),
            .inside
        )
        XCTAssertTrue(BookWhisperCadence.morning.enablesPromptWhispers)
        XCTAssertFalse(BookWhisperCadence.morning.enablesBookWhispers)
        XCTAssertTrue(BookWhisperCadence.evening.enablesBookWhispers)
        XCTAssertFalse(BookWhisperCadence.evening.enablesPromptWhispers)
    }

    func testObservationLedgerMakesExactNoReadBoundaryHard() {
        let page = SurfacePage(
            id: "notice-rain",
            type: .bookNotices,
            sourceID: "book-notices",
            prompt: "I have been wondering…",
            detail: "Rain keeps returning in your photographs.",
            payload: BookPagePayload(
                headline: "I have been wondering…",
                body: "Rain keeps returning in your photographs.",
                metadata: ["observationKey": "context:rain-photos"]
            )
        )
        let boundary = BookReadingBoundary(id: "context:rain-photos", createdAt: Date())
        var inputs = BookSourceInputs()
        inputs.bookReadingBoundaries = [boundary]

        XCTAssertFalse(BookObservationLedger.allows(
            page,
            observations: inputs.bookObservations,
            boundaries: inputs.bookReadingBoundaries
        ))

        inputs.bookReadingBoundaries = []
        XCTAssertTrue(BookObservationLedger.allows(
            page,
            observations: inputs.bookObservations,
            boundaries: inputs.bookReadingBoundaries
        ))
        inputs.bookObservations = BookObservationLedger.recording(
            surface: page,
            status: .asked,
            in: []
        )
        XCTAssertFalse(BookObservationLedger.allows(
            page,
            observations: inputs.bookObservations,
            boundaries: inputs.bookReadingBoundaries
        ))
    }

    func testAttentionFingerprintFindsPatternsAcrossPhotoVoiceAndContext() {
        let page = BookPage(
            id: "photo-voice-page",
            type: .souvenir,
            promptText: "After the rain",
            userInput: "I kept thinking about the harbor light.",
            sourceID: "reader",
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: "/tmp/rain.jpg",
                    caption: "A reflected lighthouse",
                    sourceID: "reader",
                    metadata: ["scene": "water harbor", "motifs": "reflection lighthouse"]
                ),
                BookPageMediaAsset(
                    kind: .audioFile,
                    reference: "/tmp/note.m4a",
                    caption: "A quiet voice note",
                    sourceID: "reader",
                    metadata: ["durationSeconds": "18"]
                )
            ],
            context: BookPageContextSnapshot(
                at: Date(timeIntervalSince1970: 1_800_000_000),
                weatherTags: ["rain"],
                bodyScore: 82,
                calendarEventCount: 0,
                nearbyAnchorID: "harbor"
            )
        )

        let fingerprint = page.resolvedAttentionFingerprint

        XCTAssertTrue(fingerprint.subjectTokens.contains("harbor"))
        XCTAssertTrue(fingerprint.visualTokens.contains("reflection"))
        XCTAssertTrue(fingerprint.visualTokens.contains("lighthouse"))
        XCTAssertTrue(fingerprint.voiceTokens.contains("quiet"))
        XCTAssertTrue(fingerprint.contextTokens.contains("weather-rain"))
        XCTAssertEqual(Set(fingerprint.modalities), Set(["words", "photo", "voice"]))
    }

    func testSensoryFolioKeepsTypedReceiptsAndSeparateSemanticLanes() throws {
        let page = BookPage(
            id: "sensory-page",
            type: .souvenir,
            promptText: "",
            userInput: "The harbor waited behind the rain-dark glass.",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: "/tmp/window.jpg",
                    caption: "Rain on a harbor window",
                    metadata: [
                        "attentionLabels": "window, harbor, water",
                        "attentionColorMood": "blue",
                        "attentionBrightness": "low light",
                        "attentionComposition": "landscape, people-0"
                    ]
                )
            ],
            context: BookPageContextSnapshot(weatherTags: ["rain"])
        )
        let folio = SensoryFolioProjector.make(from: page, encoder: TestSensoryEncoder())

        XCTAssertEqual(folio.schemaVersion, SensoryFolio.currentSchemaVersion)
        XCTAssertTrue(folio.modalities.contains("photo"))
        XCTAssertTrue(folio.values(for: .subject).contains("window"))
        XCTAssertTrue(folio.values(for: .palette).contains("blue"))
        XCTAssertNotNil(folio.vector(.languageSemantic))
        XCTAssertNotNil(folio.vector(.visualSemantic))
        XCTAssertNotNil(folio.vector(.contextSemantic))

        let encoded = try JSONEncoder().encode(folio)
        XCTAssertEqual(try JSONDecoder().decode(SensoryFolio.self, from: encoded), folio)
    }

    func testSensoryLoomFindsPhotographToInkThreadOnlyWhenItBeatsArchiveBaseline() throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let photo = sensoryPage(
            id: "photo-window",
            date: base.addingTimeInterval(-8 * 86_400),
            text: "",
            modality: "photo",
            subject: "window",
            vectorKind: .visualSemantic,
            vector: [1, 0]
        )
        let near = [
            sensoryPage(id: "ink-a", date: base.addingTimeInterval(-6 * 86_400), text: "I waited beside the rain until the room changed shape.", vector: [0.99, 0.03]),
            sensoryPage(id: "ink-b", date: base.addingTimeInterval(-4 * 86_400), text: "The glass held one world apart from another for me.", vector: [0.97, -0.04]),
            sensoryPage(id: "ink-c", date: base.addingTimeInterval(-2 * 86_400), text: "Something beyond the room kept asking to be noticed.", vector: [0.96, 0.08])
        ]
        let far = (0..<5).map { index in
            sensoryPage(
                id: "other-\(index)",
                date: base.addingTimeInterval(TimeInterval(-20 - index) * 86_400),
                text: "Bread apples errands and an ordinary crowded table today.",
                vector: [0.02, 0.99]
            )
        }

        let connection = try XCTUnwrap(SensoryLoom.connections(pages: [photo] + near + far).first)

        XCTAssertEqual(connection.motifID, "sensory-window")
        XCTAssertEqual(connection.photographPageIDs, [photo.id])
        XCTAssertGreaterThanOrEqual(connection.prosePageIDs.count, 2)
        XCTAssertGreaterThan(connection.contrastGap, SensoryLoom.minimumContrastGap)
        XCTAssertEqual(connection.signal.kind, .sensory)
        XCTAssertEqual(Set(connection.signal.evidencePageIDs), Set(connection.evidencePageIDs))
    }

    func testOvernightConnectionReviewAcceptsOnlyFrozenCandidateEvidence() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let candidate = overnightCandidate()
        let response = """
        {
          "connections": [
            {
              "candidateID": "semantic-harbor-rain",
              "confidence": 86,
              "headline": "The Harbor After Rain",
              "interpretation": "Both pages place the harbor beside a changed sky, but one watches it arrive and the other watches it clear.",
              "question": "Does the harbor become a threshold for you when the weather changes?"
            }
          ]
        }
        """

        let draft = try XCTUnwrap(OvernightConnectionReview.drafts(
            from: response,
            candidates: [candidate],
            now: now
        ).first)

        XCTAssertEqual(draft.observationKey, candidate.observationKey)
        XCTAssertEqual(draft.evidencePageIDs, candidate.evidencePageIDs)
        XCTAssertEqual(draft.evidenceCards, candidate.evidenceCards)
        XCTAssertEqual(draft.confidence, 86)
        XCTAssertTrue(draft.question.hasSuffix("?"))
    }

    func testOvernightConnectionReviewRejectsInventedLowConfidenceAndClinicalClaims() {
        let candidate = overnightCandidate()
        let response = """
        {"connections":[
          {"candidateID":"invented-page-pair","confidence":99,"headline":"Invented","interpretation":"This is unsupported but long enough to pass a length check.","question":"Could this be true?"},
          {"candidateID":"semantic-harbor-rain","confidence":52,"headline":"Weak","interpretation":"The pages might share a little weather without changing one another.","question":"Are these together?"},
          {"candidateID":"semantic-harbor-rain","confidence":91,"headline":"Clinical","interpretation":"This means you are anxious and reveals an attachment style rooted in trauma.","question":"Is this your diagnosis?"}
        ]}
        """

        XCTAssertTrue(OvernightConnectionReview.drafts(
            from: response,
            candidates: [candidate]
        ).isEmpty)
    }

    func testOvernightConnectionSurfaceRequiresItsFrozenPagesAndKeepsBoundaryKey() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let candidate = overnightCandidate()
        let draft = OvernightConnectionDraft(
            observationKey: candidate.observationKey,
            candidateID: candidate.id,
            evidenceSignature: OvernightConnectionReview.evidenceSignature(for: [candidate]),
            kind: candidate.kind,
            headline: "The Harbor After Rain",
            interpretation: "The two pages seem to use the harbor as a threshold around changing weather.",
            question: "Do these pages belong together?",
            confidence: 88,
            evidencePageIDs: candidate.evidencePageIDs,
            evidenceCards: candidate.evidenceCards,
            generatedAt: now
        )
        let first = BookPage(
            id: "page-rain",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-8 * 86_400),
            promptText: "",
            userInput: "The harbor light doubled itself in the rain."
        )
        let second = BookPage(
            id: "page-clear",
            type: .souvenir,
            createdAt: now.addingTimeInterval(-2 * 86_400),
            promptText: "",
            userInput: "The harbor looked newly unlatched after the storm."
        )
        let firstDay = BookDay(
            id: BookDay.id(for: first.createdAt),
            date: first.createdAt,
            pages: [first]
        )
        let secondDay = BookDay(
            id: BookDay.id(for: second.createdAt),
            date: second.createdAt,
            pages: [second]
        )
        let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs()
        inputs.days = [firstDay, secondDay]
        inputs.overnightConnectionDrafts = [draft]

        let surface = try XCTUnwrap(OvernightConnectionReview.surfaces(
            for: today,
            inputs: inputs,
            now: now
        ).first)

        XCTAssertEqual(surface.payload.metadata["observationKey"], candidate.observationKey)
        XCTAssertEqual(surface.payload.metadata["overnightConnection"], "true")
        XCTAssertEqual(surface.payload.metadata["magicMomentEligible"], "true")
        XCTAssertEqual(surface.payload.metadata["evidencePageIDs"], candidate.evidencePageIDs.joined(separator: ","))

        inputs.bookReadingBoundaries = [BookReadingBoundary(id: candidate.observationKey, createdAt: now)]
        XCTAssertFalse(BookObservationLedger.allows(
            surface,
            observations: inputs.bookObservations,
            boundaries: inputs.bookReadingBoundaries
        ))

        inputs.days = []
        XCTAssertTrue(OvernightConnectionReview.surfaces(
            for: today,
            inputs: inputs,
            now: now
        ).isEmpty)
    }

    func testOvernightEvidenceSignatureChangesOnlyWhenEvidenceChanges() {
        let original = overnightCandidate()
        var changed = original
        changed.evidencePageIDs.append("page-third")

        XCTAssertEqual(
            OvernightConnectionReview.evidenceSignature(for: [original]),
            OvernightConnectionReview.evidenceSignature(for: [original])
        )
        XCTAssertNotEqual(
            OvernightConnectionReview.evidenceSignature(for: [original]),
            OvernightConnectionReview.evidenceSignature(for: [changed])
        )
    }

    private func overnightCandidate() -> OvernightConnectionCandidate {
        OvernightConnectionCandidate(
            id: "semantic-harbor-rain",
            observationKey: "connection:semantic-harbor-rain",
            kind: "semantic",
            deterministicFinding: "Two harbor pages changed meaning when set side by side.",
            evidencePageIDs: ["page-rain", "page-clear"],
            evidenceCards: "June 1\u{1F}The harbor light doubled itself in the rain.\u{1F}book.closed\nJune 7\u{1F}The harbor looked newly unlatched after the storm.\u{1F}book.pages"
        )
    }

    private func sensoryPage(
        id: String,
        date: Date,
        text: String,
        modality: String = "words",
        subject: String? = nil,
        vectorKind: SensoryVector.Kind = .languageSemantic,
        vector: [Float]
    ) -> BookPage {
        var observations = [SensoryObservation(
            dimension: .modality,
            value: modality,
            confidence: 1,
            extractorID: "test"
        )]
        if let subject {
            observations.append(SensoryObservation(
                dimension: .subject,
                value: subject,
                confidence: 1,
                extractorID: "test"
            ))
        }
        return BookPage(
            id: id,
            type: .souvenir,
            createdAt: date,
            promptText: "",
            userInput: text,
            origin: .userAuthored,
            sensoryFolio: SensoryFolio(
                observations: observations,
                vectors: [SensoryVector(kind: vectorKind, modelID: "test-shared-space", values: vector)]
            )
        )
    }
}

private struct TestSensoryEncoder: SensoryVectorEncoding {
    let modelID = "test-sensory"

    func vector(for text: String) -> [Float]? {
        let lowered = text.lowercased()
        return [
            lowered.contains("harbor") || lowered.contains("window") ? 1 : 0.2,
            lowered.contains("rain") ? 0.7 : 0.1,
            lowered.contains("blue") ? 0.5 : 0.05
        ]
    }
}
