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
}
