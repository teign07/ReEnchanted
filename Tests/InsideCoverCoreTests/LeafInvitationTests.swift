import XCTest
@testable import InsideCoverCore

/// A Page with something to do should say what, in its own verb. "Open the page"
/// is a filing verb; the Book asking you to cast a spell is the Book.
final class LeafInvitationTests: XCTestCase {
    private func page(_ type: BookPageType) -> SurfacePage {
        SurfacePage(
            id: "probe-\(type.rawValue)",
            type: type,
            sourceID: "probe",
            score: 10,
            prompt: "probe",
            detail: "probe",
            payload: BookPagePayload(headline: "probe", body: "probe")
        )
    }

    private func page(_ type: BookPageType, _ metadata: [String: String]) -> SurfacePage {
        SurfacePage(
            id: "probe-\(type.rawValue)",
            type: type,
            sourceID: "probe",
            score: 10,
            prompt: "probe",
            detail: "probe",
            payload: BookPagePayload(headline: "probe", body: "probe", metadata: metadata)
        )
    }

    func testPagesWithSomethingToDoSayWhat() {
        XCTAssertEqual(page(.enchantment).leafInvitation?.title, "Choose a photo and cast")
        XCTAssertEqual(page(.wonderCompass).leafInvitation?.title, "Begin the Compass Run")
        XCTAssertEqual(page(.tarot).leafInvitation?.title, "Turn the cards")
        XCTAssertEqual(page(.twoReadings).leafInvitation?.title, "Take a side")
        XCTAssertEqual(page(.gamePage).leafInvitation?.title, "Play")
        XCTAssertEqual(page(.rest).leafInvitation?.title, "Mark the rest")
    }

    /// A plate that has already been illuminated is reading matter. Asking the
    /// reader to illuminate it again would be asking for work already done.
    func testAnIlluminatedPlateStopsAsking() {
        XCTAssertNotNil(page(.illuminatedPhoto, [:]).leafInvitation)
        XCTAssertNil(
            page(.illuminatedPhoto, ["renderedPreviewPath": "/tmp/plate.jpg"]).leafInvitation
        )
    }

    /// A bargain on the desk is only ever *offered*. Naming the debt would front
    /// a cost the reader has not agreed to, and letting it go is meant to be free.
    func testABargainIsOnlyEverOffered() {
        let title = page(.faeBargain).leafInvitation?.title ?? ""
        XCTAssertEqual(title, "Hear the bargain")
        for owed in ["pay", "owe", "debt"] {
            XCTAssertFalse(title.lowercased().contains(owed), "a desk bargain must not name a debt")
        }
    }

    /// Letters and notes reach the reader through the generation path, which
    /// offers "Let me write" when there is writing to do. A verb here would ask
    /// again for one already written.
    func testWritingPagesAreLeftToTheGenerationPath() {
        XCTAssertNil(page(.letter).leafInvitation)
        XCTAssertNil(page(.note).leafInvitation)
    }

    /// nil is a real answer, not a gap. A Page that cannot honour a verb should
    /// fall back to the plain invitation rather than promise something.
    func testReadingPagesHaveNoVerbOfTheirOwn() {
        // bookNotices is deliberately not in this list: a Notice asks whether
        // the Book has it right (onBookNoticeFeedback, onBookOpinionContested),
        // so it is one of the asking Pages, not reading matter.
        for type in [BookPageType.diary, .quotes, .affirmations, .lore, .quip] {
            XCTAssertNil(page(type).leafInvitation, "\(type) should not claim a verb")
        }
    }

    /// Every verb needs a symbol to print beside it on the leaf.
    func testEveryVerbCarriesASymbol() {
        for type in BookPageType.allCases {
            guard let invitation = page(type).leafInvitation else { continue }
            XCTAssertFalse(invitation.title.isEmpty, "\(type)")
            XCTAssertFalse(invitation.symbol.isEmpty, "\(type) has a verb but nothing to print with it")
        }
    }

    func testCompassExplanationOffersAStartDoorAndTheRunKeepsItsOwnControls() {
        let day = BookDay.today()
        let context = CuratorContext.make(for: day)
        let explanation = FirstRunPageSequence.requestedIntroduction(
            .compass, for: day, context: context, inputs: .empty, now: Date()
        )
        XCTAssertTrue(explanation.offersCompassRunStart)
        XCTAssertTrue(explanation.payload.body.contains("Turn the page. I'll show you one."))

        let run = FirstRunPageSequence.requestedIntroduction(
            .compassRun, for: day, context: context, inputs: .empty, now: Date()
        )
        XCTAssertFalse(run.offersCompassRunStart)
        XCTAssertEqual(run.payload.metadata["compassStep"], "run")
        XCTAssertEqual(run.leafInvitation?.title, "Begin the Compass Run")
    }

    func testOtherCompassExplainersOfferTheSameDoor() {
        for source in [
            FirstRunPageSequence.compassWhatSourceID,
            FirstRunPageSequence.compassGiftSourceID,
            FirstRunPageSequence.compassWhySourceID
        ] {
            XCTAssertTrue(page(.helpTips, ["source": source]).offersCompassRunStart)
        }
        XCTAssertTrue(page(.helpTips, ["tipID": "wonder-compass"]).offersCompassRunStart)
        XCTAssertTrue(page(.wonderCompass, ["readingPage": "true"]).offersCompassRunStart)
        XCTAssertTrue(page(.wonderCompass, ["compassBookPreview": "true"]).offersCompassRunStart)
        XCTAssertTrue(page(.lore, ["snippetID": "labyrinth-system-compass-runs"]).offersCompassRunStart)
    }

    func testCompassStartDoorDoesNotInterruptMissionsStepsOrUnrelatedPages() {
        XCTAssertFalse(page(.wonderCompass).offersCompassRunStart)
        for step in ["run", "notice", "embark", "sense", "write", "rest"] {
            XCTAssertFalse(page(.wonderCompass, [
                "compassStep": step,
                "readingPage": "true"
            ]).offersCompassRunStart)
        }
        XCTAssertFalse(page(.helpTips, ["tipID": "glow-menu"]).offersCompassRunStart)
        XCTAssertFalse(page(.lore, ["tags": "wonder-compass"]).offersCompassRunStart)
        XCTAssertFalse(page(.letter, ["snippetID": "labyrinth-system-compass-runs"]).offersCompassRunStart)
    }
}

/// Leaf purpose stays the same across devices, content lengths and Page states.
final class LeafPresentationContractTests: XCTestCase {
    private func page(_ type: BookPageType, body: String = "A small beginning.", metadata: [String: String] = [:]) -> SurfacePage {
        SurfacePage(id: "leaf-contract", type: type, sourceID: "probe", score: 10,
            prompt: "A question", detail: "A little context",
            payload: BookPagePayload(headline: "A Page", body: body, metadata: metadata))
    }

    func testShortAnswersStayOnTheLeafWithoutAnActivityGate() {
        for type in [BookPageType.diary, .souvenir, .mood, .body, .fuel, .location, .plainPage] {
            let short = page(type)
            let long = page(type, body: String(repeating: "A longer prompt. ", count: 100))
            XCTAssertEqual(short.leafPresentation, .shortAnswer)
            XCTAssertEqual(long.leafPresentation, short.leafPresentation)
            XCTAssertFalse(short.leafRequiresUnfoldingToKeep)
        }
    }

    func testActivitiesAlwaysUnfoldEvenWhenTheirTextWouldFit() {
        for type in [BookPageType.narrativeOS, .academyClass, .twoReadings, .tarot, .radio,
                     .marginsAtlas, .inventory, .gamePage, .pactVerdict, .wordNegotiation, .packPage] {
            let activity = page(type)
            XCTAssertEqual(activity.leafPresentation, .activityPreview, "\(type)")
            XCTAssertTrue(activity.leafRequiresUnfoldingToKeep, "\(type) cannot be completed by keeping its teaser")
        }
    }

    func testPreviewNeverReplacesTheAuthoritativeStoryOrItsChoices() {
        let body = (1...240).map { "word\($0)" }.joined(separator: " ")
        let story = page(.narrativeOS, body: body, metadata: ["storyChoiceSliceOfLifeTitle": "Stay and listen"])
        let preview = story.leafActivityPreview(from: story.payload.body)
        XCTAssertLessThan(preview.split(whereSeparator: \.isWhitespace).count, 75)
        XCTAssertTrue(preview.contains("Unfold to read the story and choose what happens."))
        XCTAssertEqual(story.payload.body, body)
        let opened = story.unfoldingFromLeaf()
        XCTAssertEqual(opened.payload.body, body)
        XCTAssertEqual(opened.payload.metadata["storyChoiceSliceOfLifeTitle"], "Stay and listen")
        XCTAssertEqual(opened.payload.metadata["leafReadingComplete"], "false")
    }

    func testReadPagesResumeAtOptionsAndShortAnswersCarryTheirDraft() {
        let article = page(.theBleed, body: "The complete printed issue.")
        XCTAssertEqual(article.leafPresentation, .readingWithActivity)
        XCTAssertFalse(article.leafRequiresUnfoldingToKeep)
        let opened = article.unfoldingFromLeaf()
        XCTAssertEqual(opened.payload.metadata["leafReadingComplete"], "true")
        XCTAssertEqual(opened.payload.body, article.payload.body)
        XCTAssertNil(article.payload.metadata["leafReadingComplete"])
        let journal = page(.diary).unfoldingFromLeaf(draft: "My own answer.")
        XCTAssertEqual(journal.payload.metadata["pagesRisingLeafDraft"], "My own answer.")
    }

    func testAuthoredChoicesAlwaysPreviewAndNarrativeOnlyScenesReadWhole() {
        for count in [20, 800] {
            let body = String(repeating: "A word. ", count: count)
            let metadata = [
                MonthlyIssuePageMetadata.authoredStoryScene: "true",
                MonthlyIssuePageMetadata.interaction: MonthlyIssueInteractionKind.choice.rawValue
            ]
            let scene = page(.narrativeOS, body: body, metadata: metadata)
            XCTAssertEqual(scene.leafPresentation, .activityPreview)
            XCTAssertEqual(scene.leafInvitation?.title, "Read and choose")
            XCTAssertEqual(scene.unfoldingFromLeaf().payload.body, body)
            let narrative = page(.narrativeOS, body: body, metadata: [
                MonthlyIssuePageMetadata.authoredStoryScene: "true",
                MonthlyIssuePageMetadata.interaction: MonthlyIssueInteractionKind.none.rawValue
            ])
            XCTAssertEqual(narrative.leafPresentation, .reading)
            XCTAssertFalse(narrative.leafRequiresUnfoldingToKeep)
        }
    }

    func testCompassExplanationsResumeAtTheStartOptionAcrossPageTypes() {
        for (type, metadata) in [
            (BookPageType.helpTips, ["tipID": "wonder-compass"]),
            (.lore, ["snippetID": "labyrinth-system-compass-runs"]),
            (.wonderCompass, ["readingPage": "true"])
        ] {
            let explanation = page(type, metadata: metadata)
            XCTAssertEqual(explanation.leafPresentation, .readingWithActivity)
            XCTAssertEqual(explanation.unfoldingFromLeaf().payload.metadata["leafReadingComplete"], "true")
        }
        XCTAssertEqual(page(.wonderCompass, metadata: ["compassStep": "run"]).leafInvitation?.title, "Begin the Compass Run")
        XCTAssertEqual(page(.wonderCompass, metadata: ["compassStep": "write"]).leafInvitation?.title, "Continue the Compass Run")
    }

    func testFinishedStoriesAndKeptPagesRemainReadable() {
        let finished = page(.narrativeOS, metadata: ["storyResultLeaf": "true"])
        XCTAssertEqual(finished.leafPresentation, .reading)
        let kept = page(.academyClass, metadata: ["keptPageID": "original-page"])
        XCTAssertEqual(kept.leafPresentation, .reading)
        XCTAssertFalse(kept.leafRequiresUnfoldingToKeep)
        let binding = page(.aboutYou, metadata: ["chapterBinding": "true"])
        XCTAssertTrue(binding.leafRequiresUnfoldingToKeep)
    }
}
