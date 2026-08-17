import XCTest
@testable import InsideCoverCore

final class BookPageReaderContributionTests: XCTestCase {
    /// Noon on the day the ledger test names.
    private static let dayDate = Date(timeIntervalSince1970: 1_786_550_400)

    func testVoiceTranscriptIsReaderSpeechAndTheRecordingRemainsEvidence() {
        let page = BookPage(
            type: .plainPage,
            promptText: "Voice Note",
            userInput: "",
            tags: ["voice-note"],
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    id: "voice",
                    kind: .audioFile,
                    reference: "/private/voice.m4a",
                    metadata: [
                        BookPageMediaAsset.voiceTranscriptMetadataKey: "The sparrows were shouting at the drainpipe.",
                        BookPageMediaAsset.voiceTranscriptProvenanceMetadataKey: BookPageMediaAsset.onDeviceSpeechTranscriptProvenance,
                        "durationSeconds": "8",
                        "voiceCadence": "quick"
                    ]
                )
            ]
        )

        XCTAssertTrue(page.hasReaderAudioRecording)
        XCTAssertEqual(page.readerAuthoredTextForAnalysis, "The sparrows were shouting at the drainpipe.")
        XCTAssertEqual(page.reflectiveMaterial, "The sparrows were shouting at the drainpipe.")
        XCTAssertEqual(page.bindingDisplayTitle, "Voice Note")
        XCTAssertEqual(page.bindingBodyText, "The sparrows were shouting at the drainpipe.")
    }

    func testUnprovenAudioCaptionCannotBecomeReaderWords() {
        let page = BookPage(
            type: .plainPage,
            promptText: "Voice Note",
            userInput: "",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .audioFile,
                    reference: "/private/voice.m4a",
                    caption: "A generated caption",
                    metadata: [BookPageMediaAsset.voiceTranscriptMetadataKey: "Words with no provenance"]
                )
            ]
        )

        XCTAssertNil(page.readerAuthoredTextForAnalysis)
        XCTAssertEqual(page.primaryReaderReadableEvidence?.kind, .voiceRecording)
        XCTAssertFalse(page.bindingBodyText.contains("Words with no provenance"))
    }

    func testPhotoObservationIsReadableButNeverReaderAuthoredLanguage() throws {
        let page = BookPage(
            type: .plainPage,
            promptText: "Original Photograph",
            userInput: "",
            tags: ["plain-photo", "unedited-photo"],
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    id: "photo",
                    kind: .renderedImageFile,
                    reference: "/private/original.jpg",
                    metadata: [
                        "attentionSubject": "a red mitten",
                        "attentionScene": "an empty bus seat",
                        "attentionBrightness": "dim"
                    ]
                )
            ]
        )

        XCTAssertTrue(page.hasReaderPhotograph)
        XCTAssertNil(page.readerAuthoredTextForAnalysis)
        XCTAssertNil(page.reflectiveMaterial)
        let evidence = try XCTUnwrap(page.primaryReaderReadableEvidence)
        XCTAssertEqual(evidence.kind, .photograph)
        XCTAssertFalse(evidence.mayQuoteAsReaderWords)
        XCTAssertTrue(evidence.text.contains("red mitten"))
        XCTAssertEqual(page.bindingDisplayTitle, "Photograph")
        XCTAssertTrue(page.bindingBodyText.contains("empty bus seat"))

        let event = try XCTUnwrap(NarrativeEventResolver.events(forKept: page).first)
        XCTAssertEqual(event.kind, .pageAnswered)
        // 1 seeded for any kept Page, +2 for a plain Page the reader made
        // unprompted - the same weight .bookNotices and .bookConnections carry.
        XCTAssertEqual(event.effect.threadWeightDeltas["ordinary-magic"], 3)
        XCTAssertTrue(event.summary.contains("red mitten"))
    }

    func testGeneratedPageKeepsBookProseSeparateFromReaderAtoms() {
        let page = BookPage(
            id: "story",
            type: .narrativeOS,
            promptText: "A door argued with Wicker.",
            userInput: """
            Wicker put the brass key on the table. The key objected.

            Chosen path: Progress Arc

            The door opened into the next scene.

            Margin note: I chose the door because the key looked smug.
            Then I apologized to the door.
            """,
            tags: ["choice:progressarc", "story-path-chosen:progressarc"],
            origin: .generated,
            mediaAssets: [
                BookPageMediaAsset(id: "photo", kind: .photoLibraryAsset, reference: "local-photo"),
                BookPageMediaAsset(id: "voice", kind: .audioFile, reference: "/private/voice.m4a"),
                BookPageMediaAsset(id: "plate", kind: .renderedImageFile, reference: "/private/book-plate.png"),
                BookPageMediaAsset(id: "sprite", kind: .bundledImage, reference: "Wicker")
            ]
        )

        XCTAssertEqual(page.readerAuthoredTexts, ["I chose the door because the key looked smug. Then I apologized to the door."])
        XCTAssertEqual(page.readerFictionChoices, ["Progress Arc"])
        XCTAssertTrue(page.hasReaderPhotograph)
        XCTAssertTrue(page.hasReaderAudioRecording)
        XCTAssertTrue(page.bookAuthoredText?.contains("Wicker put the brass key") == true)
        XCTAssertTrue(page.bookAuthoredText?.contains("The door opened") == true)
        XCTAssertFalse(page.bookAuthoredText?.contains("I chose the door") == true)
        XCTAssertFalse(page.bookAuthoredText?.contains("I apologized") == true)
        XCTAssertFalse(page.bookAuthoredText?.contains("Chosen path") == true)
        XCTAssertFalse(page.readerContributions.contains { $0.mediaAssetID == "plate" })
        XCTAssertFalse(page.readerContributions.contains { $0.mediaAssetID == "sprite" })
    }

    func testKeepingGeneratedProseAloneDoesNotCreateReaderEvidence() {
        let page = BookPage(
            type: .gossip,
            promptText: "Elsewhere in the Academy",
            userInput: "Penny filed a complaint against the west staircase.",
            origin: .simulated,
            mediaAssets: [BookPageMediaAsset(kind: .bundledImage, reference: "Penny")]
        )

        XCTAssertFalse(page.hasReaderContribution)
        XCTAssertNil(page.readerAuthoredTextForAnalysis)
        XCTAssertEqual(page.bookAuthoredText, "Penny filed a complaint against the west staircase.")
    }

    func testBookRenderedPagewrightPlateIsNotAReaderPhotograph() {
        let page = BookPage(
            type: .plainPage,
            promptText: "A loose page",
            userInput: "I arranged the words, but the plate is the Book's rendering.",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: "/private/pagewright.png",
                    sourceID: "pagewright",
                    metadata: ["pagewright": "true", "mediaRole": "scrapbookPreview"]
                )
            ]
        )

        XCTAssertFalse(page.hasReaderPhotograph)
        XCTAssertEqual(page.readerAuthoredTexts, ["I arranged the words, but the plate is the Book's rendering."])
    }

    func testPreparedBookBodyCannotMintLivedProofWithoutAReaderReturn() throws {
        let surface = SurfacePage(
            id: "mission",
            type: .gossip,
            sourceID: BookPageSourceRegistry.source(for: .gossip).id,
            prompt: "The Spoon Has A Theory",
            detail: "Ask it what it saw.",
            payload: BookPagePayload(
                headline: "The Spoon Has A Theory",
                body: "The spoon has been watching the kitchen and has prepared allegations.",
                metadata: [
                    "academyActivityID": "spoon-theory",
                    "academyActivityTitle": "The Spoon Has A Theory",
                    "academyActivityInvitation": "Ask the spoon what it saw.",
                    "souvenirPrompt": "Bring back one sentence."
                ]
            )
        )

        let bodyOnly = try XCTUnwrap(LivedQuestReceipt.from(
            surface: surface,
            readerInput: surface.payload.body,
            mediaAssets: [],
            completedAt: Date()
        ))
        XCTAssertFalse(bodyOnly.hasAnyProof)

        let returned = try XCTUnwrap(LivedQuestReceipt.from(
            surface: surface,
            readerInput: surface.payload.body + "\n\nMargin note: It accused the colander.",
            mediaAssets: [],
            completedAt: Date()
        ))
        XCTAssertTrue(returned.hasWrittenProof)
    }

    func testBraidLedgerLabelsAuthorshipAtTheAtomicBoundary() throws {
        let page = BookPage(
            type: .narrativeOS,
            createdAt: Self.dayDate,
            promptText: "A scene",
            userInput: "The Book wrote the scene.\n\nChosen path: Something Surprising\n\nMargin note: I picked the odd door.",
            tags: ["choice:surprise"],
            origin: .generated
        )
        // Pinned rather than `Date()`: `capturedPages` filters to the day the
        // id names, so a page created "now" silently drops out of the ledger
        // once the calendar moves past it.
        let day = BookDay(id: "2026-08-12", date: Self.dayDate, pages: [page])

        let ledger = try XCTUnwrap(BraidPromptBuilder.evidenceLines(for: day).first)
        XCTAssertTrue(ledger.contains("Book-authored Page text: The Book wrote the scene."))
        XCTAssertTrue(ledger.contains("Reader's own words: I picked the odd door."))
        XCTAssertTrue(ledger.contains("Reader's fiction choice: Something Surprising"))
        XCTAssertFalse(ledger.contains("Kept text:"))
    }

    func testWordEchoIgnoresBookProseButCanUseEmbeddedReaderSentence() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let old = now.addingTimeInterval(-30 * 86_400)
        let bookOnly = BookPage(
            id: "book-only",
            type: .gossip,
            createdAt: old,
            promptText: "Academy business",
            userInput: "The lighthouse complained about Wicker all night.",
            origin: .generated
        )
        let withReaderLine = BookPage(
            id: "with-reader-line",
            type: .gossip,
            createdAt: old,
            promptText: "Academy business",
            userInput: "The telescope complained too.\n\nMargin note: I watched the lighthouse after midnight.",
            origin: .generated
        )

        XCTAssertNil(KeepEcho.find(
            for: "The lighthouse flashed again.",
            pageID: "new",
            in: [BookDay(id: "old", date: old, pages: [bookOnly])],
            now: now
        ))
        XCTAssertEqual(KeepEcho.find(
            for: "The lighthouse flashed again.",
            pageID: "new",
            in: [BookDay(id: "old", date: old, pages: [withReaderLine])],
            now: now
        )?.sourcePageID, "with-reader-line")
    }

    func testReaderMannerMeasuresOnlyTheReaderSentenceInsideAGeneratedPage() {
        let generated = BookPage(
            type: .gossip,
            promptText: "Academy business",
            userInput: "The Book asks perhaps perhaps perhaps perhaps?\n\nMargin note: Brass moths dislike rain!",
            origin: .generated
        )

        let profile = ReaderMannerProfile.measure(pages: [generated])

        XCTAssertEqual(profile.pageCount, 1)
        XCTAssertEqual(profile.hedgeRate, 0)
        XCTAssertEqual(profile.questionRate, 0)
        XCTAssertEqual(profile.exclaimRate, 1)
    }

    func testTaleWitnessTreatsGeneratedProseAsTheBooksAndReaderChoiceAsAChoice() throws {
        let bookOnly = BookPage(
            type: .gossip,
            promptText: "Academy business",
            userInput: "The western staircase held a secret meeting.",
            origin: .generated
        )
        let choice = BookPage(
            type: .narrativeOS,
            promptText: "Academy business",
            userInput: "A door appeared.\n\nChosen path: Something Surprising",
            origin: .generated
        )

        let bookWitness = try XCTUnwrap(TaleGrammar.witness(from: bookOnly))
        let choiceWitness = try XCTUnwrap(TaleGrammar.witness(from: choice))

        XCTAssertFalse(bookWitness.isReaderAuthored)
        XCTAssertFalse(bookWitness.isReaderFictionChoice)
        XCTAssertEqual(bookWitness.evidence, "The western staircase held a secret meeting.")
        XCTAssertFalse(choiceWitness.isReaderAuthored)
        XCTAssertTrue(choiceWitness.isReaderFictionChoice)
        XCTAssertEqual(choiceWitness.evidence, "Something Surprising")
    }
}
