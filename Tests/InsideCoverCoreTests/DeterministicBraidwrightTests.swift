import XCTest

@testable import InsideCoverCore

final class DeterministicBraidwrightTests: XCTestCase {
  func testBraidwrightUsesContextSelectedFictionInsteadOfChronologicalFallback() {
    let fixture = makeFixture()
    let wickerContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )
    let eddiesContext = context(
      for: fixture,
      fictionPageID: fixture.eddiesFiction.id,
      fictionChoice: fixture.eddiesFiction.userInput
    )

    let wickerPage = DeterministicBraidwright.page(for: fixture.day, context: wickerContext)
    let eddiesPage = DeterministicBraidwright.page(for: fixture.day, context: eddiesContext)
    let wickerText = wickerPage.userInput.lowercased()
    let eddiesText = eddiesPage.userInput.lowercased()

    XCTAssertTrue(wickerText.contains("wicker"))
    XCTAssertFalse(wickerText.contains("eddies"))
    XCTAssertTrue(eddiesText.contains("eddies"))
    XCTAssertFalse(eddiesText.contains("wicker"))
    XCTAssertNotEqual(wickerPage.userInput, eddiesPage.userInput)
    XCTAssertTrue(wickerPage.tags.contains("deterministic-braidwright"))
    XCTAssertTrue(eddiesPage.tags.contains("deterministic-braidwright"))
  }

  func testBraidwrightChoosesTheScoredThreadInsteadOfRecitingEveryPage() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )

    let page = DeterministicBraidwright.page(for: fixture.day, context: braidContext)
    let details = BraidPageDetails.details(for: page)
    let text = details.body.lowercased()

    XCTAssertTrue(text.contains("blue") && text.contains("chair"))
    XCTAssertTrue(text.contains("soup") && text.contains("sam"))
    XCTAssertTrue(details.body.contains("Sam"))
    XCTAssertFalse(details.body.contains("i tightened"))
    XCTAssertTrue(details.body.contains("Then you called Sam"))
    XCTAssertFalse(details.body.contains("Then I called Sam"))
    XCTAssertFalse(text.contains("bronze umbrella"))
    XCTAssertFalse(text.contains("radiator"))
    XCTAssertFalse(text.contains("weather log"))
    XCTAssertFalse(text.contains("diary page"))
    XCTAssertFalse(text.contains("story fragment"))
    XCTAssertFalse(text.contains("supporting log"))
    XCTAssertFalse(text.contains("waited for them to admit they belonged"))
    XCTAssertFalse(text.contains("held together long enough to be remembered"))
    XCTAssertFalse(
      BraidOutputAudit.issues(in: details.body, for: fixture.day, context: braidContext)
        .contains(.storyScoreDrift)
    )
    XCTAssertNotEqual(details.title, "Book of You")
  }

  func testBraidwrightLetsFictionCrossIntoRealityWithoutExplainingTheSeam() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )

    let page = DeterministicBraidwright.page(for: fixture.day, context: braidContext)
    let text = BraidPageDetails.details(for: page).body.lowercased()
    let paragraphs = text.components(separatedBy: "\n\n")

    XCTAssertTrue(text.contains("chair"))
    XCTAssertTrue(text.contains("wicker"))
    XCTAssertTrue(["fox", "shortcut", "root bridge"].contains(where: { text.contains($0) }))
    XCTAssertTrue(
      paragraphs.contains { paragraph in
        paragraph.contains("wicker")
          && ["tightened", "blue", "kitchen", "chair", "screw", "tomato", "soup", "spoon", "sam"]
            .contains(where: { paragraph.contains($0) })
      },
      "The fiction should touch a lived detail, not sit in a labeled neighboring compartment."
    )
    XCTAssertFalse(text.contains("fiction"))
    XCTAssertFalse(text.contains("lived"))
    XCTAssertFalse(text.contains("in real life"))
    XCTAssertFalse(text.contains("in the lived room"))
    XCTAssertFalse(text.contains("not the lived room"))
    XCTAssertFalse(text.contains("shelf"))
    XCTAssertFalse(text.contains("archive"))
    XCTAssertFalse(text.contains("in the margins"))
    XCTAssertFalse(text.contains("reader-made fictional choice"))
    XCTAssertFalse(text.contains("fiction bridge"))
  }

  func testBraidwrightBlursTheShelvesWithoutInventingASecondLifeForTheReader() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )

    let page = DeterministicBraidwright.page(for: fixture.day, context: braidContext)
    let text = BraidPageDetails.details(for: page).body.lowercased()

    XCTAssertTrue(text.contains("sam"))
    XCTAssertTrue(text.contains("wicker"))
    XCTAssertFalse(text.contains("you refused the fox"))
    XCTAssertFalse(text.contains("you crossed the root bridge"))
    XCTAssertFalse(text.contains("you met wicker"))
    XCTAssertFalse(text.contains("you spoke to wicker"))
    XCTAssertFalse(text.contains("you told wicker"))

    for unsupportedDecoration in [
      "moth", "moonlight", "lantern", "starlight", "spell", "fairy dust", "enchanted forest",
    ] {
      XCTAssertFalse(
        text.contains(unsupportedDecoration),
        "The braid invented stock decoration: \(unsupportedDecoration)"
      )
    }
  }

  func testBraidOutputAuditRejectsAnExposedRealitySeamButAcceptsAnUnlabeledCrossing() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )
    let labeled = """
      You tightened the loose screw on the blue kitchen chair.

      In fiction, Wicker refused the fox's shortcut. The chair heard him and made the refusal its own rule.

      The Book kept the page: the blue chair held while Wicker crossed the root bridge.
      """
    let unlabeled = """
      You tightened the loose screw on the blue kitchen chair.

      Wicker refused the fox's shortcut. The chair heard him and made the refusal its own rule.

      The Book kept the page: the blue chair held while Wicker crossed the root bridge.
      """

    let labeledIssues = BraidOutputAudit.issues(
      in: labeled,
      for: fixture.day,
      context: braidContext
    )
    let unlabeledIssues = BraidOutputAudit.issues(
      in: unlabeled,
      for: fixture.day,
      context: braidContext
    )

    XCTAssertTrue(labeledIssues.contains(.exposedRealitySeam))
    XCTAssertFalse(unlabeledIssues.contains(.exposedRealitySeam))
  }

  func testBraidOutputAuditAllowsTheRitualColophonButRejectsOutsideBookNarration() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )
    let outsideNarrations = [
      "The Book wanted the blue kitchen chair and its loose screw.",
      "the book wanted the blue kitchen chair and its loose screw.",
      "THE BOOK wanted the blue kitchen chair and its loose screw.",
    ]
    let firstPersonWithColophon = """
      I wanted the blue kitchen chair and its loose screw.

      Wicker refused the fox's shortcut. The chair took his side.

      The Book kept the page: the chair held while Wicker crossed the root bridge.
      """

    let firstPersonIssues = BraidOutputAudit.issues(
      in: firstPersonWithColophon,
      for: fixture.day,
      context: braidContext
    )

    for outsideNarration in outsideNarrations {
      let page = """
        \(outsideNarration)

        Wicker refused the fox's shortcut. The chair took his side.

        The Book kept the page: the chair held while Wicker crossed the root bridge.
        """
      XCTAssertTrue(
        BraidOutputAudit.issues(in: page, for: fixture.day, context: braidContext)
          .contains(.bookSpokeFromOutside)
      )
    }
    XCTAssertFalse(firstPersonIssues.contains(.bookSpokeFromOutside))
  }

  func testRealitySeamAndOutsideBookVoiceAreHardRegisterFailures() {
    XCTAssertTrue(BraidOutputAudit.Issue.exposedRealitySeam.isRegisterFailure)
    XCTAssertTrue(BraidOutputAudit.Issue.bookSpokeFromOutside.isRegisterFailure)
    XCTAssertTrue(BraidOutputAudit.Issue.servantVoice.isRegisterFailure)
  }

  func testServantVoiceAuditDoesNotPunishAnAttributedReaderQuotation() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )
    let servant = """
      Blue Chair

      You tightened the blue chair. It's okay; you did your best.

      The Book kept the page: the chair kept Wicker's rule.
      """
    let attributed = """
      Blue Chair

      I caught this much of your sentence: «It's okay; you did your best.» I kept the blue chair.

      The Book kept the page: the chair kept Wicker's rule.
      """
    var sourcedDay = fixture.day
    sourcedDay.pages.append(
      BookPage(
        id: "reader-servant-quotation",
        type: .diary,
        createdAt: date("2026-08-03T17:00:00Z"),
        promptText: "What was said?",
        userInput: "It's okay; you did your best.",
        origin: .userAuthored
      ))

    let servantIssues = BraidOutputAudit.issues(
      in: servant,
      for: fixture.day,
      context: braidContext
    )
    let attributedIssues = BraidOutputAudit.issues(
      in: attributed,
      for: sourcedDay,
      context: braidContext
    )

    XCTAssertTrue(servantIssues.contains(.servantVoice))
    XCTAssertFalse(attributedIssues.contains(.servantVoice))
  }

  func testServantVoiceAuditRejectsPoliteDisclaimersThatDrainTheBookOfCharacter() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )
    let disclaimers = [
      "You don't have to answer when you're ready.",
      "Nothing is required. No pressure.",
      "Take this at your own pace whenever you like."
    ]

    for disclaimer in disclaimers {
      let page = """
        Blue Chair

        \(disclaimer)

        The Book kept the page: the chair kept Wicker's rule.
        """
      XCTAssertTrue(
        BraidOutputAudit.issues(in: page, for: fixture.day, context: braidContext)
          .contains(.servantVoice),
        disclaimer
      )
    }
  }

  func testBraidwrightAttributesQuotedFirstPersonProseWithoutCorruptingTheInnerQuote() {
    let source = #"I told Mara, "Leave my blue cup where it is." Then I shut the window."#
    let lived = BookPage(
      id: "quoted-lived-receipt",
      type: .diary,
      createdAt: date("2026-08-05T09:00:00Z"),
      promptText: "What happened?",
      userInput: source,
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-05",
      date: date("2026-08-05T21:00:00Z"),
      pages: [lived]
    )

    let page = DeterministicBraidwright.page(for: day, context: .empty)
    let body = BraidPageDetails.details(for: page).body

    XCTAssertTrue(body.contains("I caught this much of your sentence"))
    XCTAssertTrue(body.contains("«\(source)»"))
    XCTAssertTrue(body.contains(#""Leave my blue cup where it is.""#))
    XCTAssertFalse(body.contains(#""Leave your blue cup where it is.""#))
    XCTAssertFalse(body.contains("You told Mara"))
  }

  func testBraidwrightTurnsMidSentenceReaderPronounsWithoutMakingTheBookTheActor() {
    let lived = BookPage(
      id: "mid-sentence-first-person",
      type: .diary,
      createdAt: date("2026-08-05T10:00:00Z"),
      promptText: "What happened?",
      userInput: "Yesterday I called Mara and put my blue cup by the sink.",
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-05-mid-sentence",
      date: date("2026-08-05T21:00:00Z"),
      pages: [lived]
    )

    let body = BraidPageDetails.details(
      for: DeterministicBraidwright.page(for: day, context: .empty)
    ).body

    // The sentence may be rearranged: that is the house writer's own prose
    // work, but every turned pronoun must land on the reader, and the Book
    // must not have taken over the doing.
    XCTAssertTrue(body.contains("you called Mara"), body)
    XCTAssertTrue(body.contains("your blue cup"), body)
    XCTAssertTrue(body.contains("Yesterday"), body)
    XCTAssertFalse(body.contains("I called Mara"), body)
    XCTAssertFalse(body.contains("my blue cup"), body)
  }

  func testFreshShadowStaysPlainAndDoesNotLicenseALabyrinthTrespass() {
    let shadow = BookPage(
      id: "fresh-shadow-receipt",
      type: .diary,
      createdAt: date("2026-08-06T09:00:00Z"),
      promptText: "What happened?",
      userInput: "My brother died this morning. I folded his blue sweater and put it on the chair.",
      tags: [ReaderShelf.shadowTag],
      origin: .userAuthored
    )
    let labyrinth = BookPage(
      id: "withheld-labyrinth-receipt",
      type: .gossip,
      createdAt: date("2026-08-06T10:00:00Z"),
      promptText: "A rumor crossed the Academy.",
      userInput: "Wicker stole the fox's black key and showed its teeth to the Registry.",
      tags: ["labyrinth-receipt"],
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-06",
      date: date("2026-08-06T21:00:00Z"),
      pages: [shadow, labyrinth]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertEqual(BraidPromptBuilder.Context.empty.readerStory.shadowPermission, .onlyWhenOld)
    XCTAssertFalse(candidates.isEmpty)
    XCTAssertTrue(candidates.allSatisfy { $0.tags.contains("braid-shadow-plain") })
    XCTAssertTrue(candidates.allSatisfy { !$0.tags.contains("braid-licensed-crossing") })
    for candidate in candidates {
      let text = candidate.userInput.lowercased()
      XCTAssertFalse(text.contains("wicker"))
      XCTAssertFalse(text.contains("fox"))
      XCTAssertFalse(text.contains("black key"))
      XCTAssertFalse(text.contains("registry"))
      XCTAssertFalse(text.contains("crossed into"))
      XCTAssertFalse(text.contains("made one rule"))
      XCTAssertFalse(text.contains("laid down a law"))
      for jauntyWord in ["mine", "stole", "teeth", "manners"] {
        XCTAssertFalse(
          text.contains(jauntyWord), "Fresh shadow used jaunty language: \(jauntyWord)")
      }
    }
  }

  func testLabyrinthSceneAndShortPlayerReplyBothSurviveTheBraid() {
    let scene = "Penny hid the brass bell before the Registry woke."
    let reply = "Leave it ringing."
    let labyrinth = BookPage(
      id: "labyrinth-scene-and-answer",
      type: .gossip,
      createdAt: date("2026-08-07T10:00:00Z"),
      promptText: "The Registry came looking for its bell.",
      userInput: scene,
      playerReply: reply,
      tags: ["labyrinth-receipt"],
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-07",
      date: date("2026-08-07T21:00:00Z"),
      pages: [labyrinth]
    )

    let page = DeterministicBraidwright.page(for: day, context: .empty)
    let body = BraidPageDetails.details(for: page).body

    XCTAssertTrue(body.contains(scene))
    XCTAssertTrue(body.contains("You said, «\(reply)»"))
    XCTAssertTrue(body.contains("Penny"))
    XCTAssertTrue(body.contains(reply))
  }

  func testStaleScoreCannotResurfaceASealedOrRemovedReceipt() {
    let safe = BookPage(
      id: "safe-green-mug",
      type: .diary,
      createdAt: date("2026-08-08T09:00:00Z"),
      promptText: "What happened?",
      userInput: "I washed the chipped green mug and left it beside the sink.",
      origin: .userAuthored
    )
    let sealed = BookPage(
      id: "sealed-obsidian-banjo",
      type: .diary,
      createdAt: date("2026-08-08T10:00:00Z"),
      promptText: "What must stay shut?",
      userInput: "The obsidian banjo waited beneath the cellar stairs.",
      tags: [ReaderShelf.sealedTag],
      origin: .userAuthored
    )
    let removedID = "removed-vermilion-submarine"
    let removedText = "The vermilion submarine surfaced inside the greenhouse."
    let day = BookDay(
      id: "2026-08-08",
      date: date("2026-08-08T21:00:00Z"),
      pages: [safe, sealed]
    )
    let reading = BraidPromptBuilder.TaleReading(
      scale: .glimpse,
      motion: .encounter,
      pressure: .witness,
      anchorPageID: removedID,
      anchor: removedText,
      turn: nil,
      visibleSupportingLogs: false,
      storyForm: .sliceOfLife,
      rutInfluence: .notInThisTelling,
      narrativeRegister: .plain,
      rutEvidencePageIDs: []
    )
    let score = BraidPromptBuilder.NightlyStoryScore(
      livedBeats: [
        BraidPromptBuilder.NightlyStoryScore.LivedBeat(
          pageID: removedID,
          pageType: .diary,
          occurredAt: date("2026-08-08T08:00:00Z"),
          excerpt: removedText,
          role: "stale removed anchor"
        ),
        BraidPromptBuilder.NightlyStoryScore.LivedBeat(
          pageID: sealed.id,
          pageType: sealed.type,
          occurredAt: sealed.createdAt,
          excerpt: sealed.userInput,
          role: "stale sealed anchor"
        ),
        BraidPromptBuilder.NightlyStoryScore.LivedBeat(
          pageID: safe.id,
          pageType: safe.type,
          occurredAt: safe.createdAt,
          excerpt: safe.userInput,
          role: "still eligible receipt"
        ),
      ],
      fictionBeat: nil,
      relationalLens: nil,
      arc: nil,
      taleReading: reading,
      magicLicense: "Witness the eligible receipt only.",
      endingDuty: "Return to the green mug.",
      forbiddenClaims: ["Never restore a sealed or removed receipt from stale score text."]
    )
    var context = BraidPromptBuilder.Context()
    context.taleReading = reading
    context.storyScore = score

    let candidates = DeterministicBraidwright.candidates(for: day, context: context)

    XCTAssertFalse(candidates.isEmpty)
    XCTAssertTrue(
      candidates.allSatisfy { $0.userInput.localizedCaseInsensitiveContains("green mug") })
    XCTAssertTrue(
      candidates.allSatisfy { !$0.userInput.localizedCaseInsensitiveContains("obsidian banjo") })
    XCTAssertTrue(
      candidates.allSatisfy {
        !$0.userInput.localizedCaseInsensitiveContains("vermilion submarine")
      })
    XCTAssertTrue(candidates.allSatisfy { $0.tags.contains("braid-receipt:\(safe.id)") })
    XCTAssertTrue(candidates.allSatisfy { !$0.tags.contains("braid-receipt:\(sealed.id)") })
    XCTAssertTrue(candidates.allSatisfy { !$0.tags.contains("braid-receipt:\(removedID)") })
  }

  func testSealedPageStaysOutsideTheWeavableDayAndUsedReceiptLedger() throws {
    let safe = BookPage(
      id: "safe-copper-kettle",
      type: .diary,
      createdAt: date("2026-08-08T09:00:00Z"),
      promptText: "What happened?",
      userInput: "I rinsed the copper kettle.",
      origin: .userAuthored
    )
    let sealed = BookPage(
      id: "sealed-private-letter",
      type: .letter,
      createdAt: date("2026-08-08T10:00:00Z"),
      promptText: "Keep shut",
      userInput: "The private letter remained under the pillow.",
      tags: [ReaderShelf.sealedTag],
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-08-seal",
      date: date("2026-08-08T21:00:00Z"),
      pages: [safe, sealed]
    )
    var story = ReaderStory.empty
    story.shadowPermission = .mayUse

    let narrowed = BraidPromptBuilder.weavableDay(day, readerStory: story)
    let braid = DeterministicBraidwright.page(for: narrowed, context: .empty)
    let updated = BraidRecoveryState.dayByMarkingCapturedPagesUsed(
      day,
      braid: braid,
      usedPageIDs: Set(narrowed.capturedPages.map(\.id))
    )

    XCTAssertEqual(narrowed.capturedPages.map(\.id), [safe.id])
    XCTAssertTrue(try XCTUnwrap(updated.pages.first { $0.id == safe.id }).usedInBookOfYou)
    XCTAssertFalse(try XCTUnwrap(updated.pages.first { $0.id == sealed.id }).usedInBookOfYou)
  }

  func testSealedPriorBraidAlsoLeavesTheWeavableArchive() {
    let sealedBraid = BookPage(
      id: "sealed-prior-braid",
      type: .bookOfYou,
      createdAt: date("2026-08-08T11:00:00Z"),
      promptText: "A prior braid",
      userInput: "The obsidian banjo crawled into the old colophon.",
      tags: [ReaderShelf.sealedTag],
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-08",
      date: date("2026-08-08T21:00:00Z"),
      pages: [sealedBraid]
    )

    let narrowed = BraidPromptBuilder.weavableDay(day, readerStory: .empty)

    XCTAssertFalse(narrowed.pages.contains { $0.id == sealedBraid.id })
  }

  func testHistoricalSealedPageCannotBecomeARelationalLens() {
    func choicePage(_ id: String, _ timestamp: String, _ choice: String, sealed: Bool = false)
      -> BookPage
    {
      let keptAt = date(timestamp)
      return BookPage(
        id: id,
        type: .narrativeOS,
        createdAt: keptAt,
        promptText: "A Story Page",
        userInput: "Chosen path: \(choice.replacingOccurrences(of: "-", with: " "))",
        tags: ["choice:\(choice)"] + (sealed ? [ReaderShelf.sealedTag] : []),
        sourceID: "narrative-os",
        origin: .simulated,
        context: BookPageContextSnapshot(at: keptAt)
      )
    }

    func archiveDay(_ page: BookPage) -> BookDay {
      BookDay(
        id: BookDay.id(for: page.createdAt),
        date: page.createdAt,
        pages: [page]
      )
    }

    let todayPage = choicePage(
      "today-night-slice",
      "2026-08-12T23:00:00Z",
      "slice-of-life"
    )
    let sealedNight = choicePage(
      "sealed-night-slice",
      "2026-08-10T23:00:00Z",
      "slice-of-life",
      sealed: true
    )
    let daylight = [
      choicePage("day-progress-a", "2026-08-11T11:00:00Z", "progress-arc"),
      choicePage("day-progress-b", "2026-08-09T11:00:00Z", "progress-arc"),
      choicePage("day-progress-c", "2026-08-08T11:00:00Z", "progress-arc"),
    ]
    let today = archiveDay(todayPage)
    let history = ([sealedNight] + daylight).map(archiveDay)

    let unfilteredConnections = RelationalLoom.connections(
      days: history + [today],
      readerLearning: ReaderLearningModel(),
      facultyEntries: [],
      people: PeopleLedger()
    )
    XCTAssertTrue(
      unfilteredConnections.contains {
        $0.condition.id.hasPrefix("day-part:") && $0.outcome.id == "choice:slice-of-life"
      },
      "The fixture must prove the forbidden historical receipt could create the lens."
    )

    let braidContext = BraidPromptBuilder.context(
      for: today,
      days: history,
      readerStory: .empty,
      now: today.date
    )

    XCTAssertNil(braidContext.storyScore?.relationalLens)
  }

  func testHistoricalSealedWordsCannotTeachTheBooksPatina() {
    func page(_ id: String, _ timestamp: String, _ text: String, sealed: Bool) -> BookPage {
      BookPage(
        id: id,
        type: .diary,
        createdAt: date(timestamp),
        promptText: "Keep one detail.",
        userInput: text,
        tags: sealed ? [ReaderShelf.sealedTag] : [],
        origin: .userAuthored
      )
    }

    func archiveDay(_ page: BookPage) -> BookDay {
      BookDay(
        id: BookDay.id(for: page.createdAt),
        date: page.createdAt,
        pages: [page]
      )
    }

    let safePages = [
      page(
        "safe-patina-a", "2026-08-16T09:00:00Z",
        "The copper kettle waited beside the clean window.", sealed: false),
      page(
        "safe-patina-b", "2026-08-15T09:00:00Z",
        "The copper kettle clicked beside the open window.", sealed: false),
      page(
        "safe-patina-c", "2026-08-14T09:00:00Z",
        "The copper kettle cooled beside the bright window.", sealed: false),
      page(
        "safe-patina-d", "2026-08-13T09:00:00Z",
        "The copper kettle rested beside the narrow window.", sealed: false),
    ]
    let sealedPages = [
      page(
        "sealed-patina-a", "2026-08-12T09:00:00Z",
        "The obsidian banjo waited beneath seven cellar stairs.", sealed: true),
      page(
        "sealed-patina-b", "2026-08-11T09:00:00Z",
        "The obsidian banjo rattled beneath seven cellar stairs.", sealed: true),
      page(
        "sealed-patina-c", "2026-08-10T09:00:00Z",
        "The obsidian banjo slept beneath seven cellar stairs.", sealed: true),
      page(
        "sealed-patina-d", "2026-08-09T09:00:00Z",
        "The obsidian banjo sulked beneath seven cellar stairs.", sealed: true),
    ]
    let today = archiveDay(safePages[0])
    let history = (Array(safePages.dropFirst()) + sealedPages).map(archiveDay)
    var readerLearning = ReaderLearningModel()
    for index in 0..<2 {
      readerLearning.record(
        ReaderLearningEvent(
          id: "sealed-learning-\(index)",
          dayID: BookDay.id(for: sealedPages[0].createdAt),
          occurredAt: sealedPages[0].createdAt.addingTimeInterval(Double(index)),
          action: .loved,
          surfaceID: "pre-keep-surface-\(index)",
          sourceID: "pre-keep-source",
          type: .diary,
          varietyKey: "forbidden-banjo",
          hour: 9,
          tags: ["forbidden-banjo"]
        ))
    }

    let braidContext = BraidPromptBuilder.context(
      for: today,
      days: history,
      readerLearning: readerLearning,
      readerStory: .empty,
      now: today.date
    )
    let patinaWords = Set(
      (braidContext.bookVoicePatina.enduring?.attentionWords ?? [])
        + (braidContext.bookVoicePatina.season?.attentionWords ?? [])
    )

    XCTAssertTrue(braidContext.bookVoicePatina.isFormed)
    XCTAssertTrue(patinaWords.contains("copper") || patinaWords.contains("kettle"))
    XCTAssertFalse(patinaWords.contains("obsidian"))
    XCTAssertFalse(patinaWords.contains("banjo"))
    XCTAssertFalse(braidContext.bookVoicePatina.promptSection.contains("obsidian"))
    XCTAssertFalse(braidContext.bookVoicePatina.promptSection.contains("forbidden banjo"))
    XCTAssertFalse(braidContext.readerLearningPromptLines.joined().contains("forbidden banjo"))
    XCTAssertTrue(
      Set(braidContext.bookVoicePatina.evidencePageIDs).isDisjoint(
        with: Set(sealedPages.map(\.id)))
    )
  }

  func testOneReceiptGlimpseHasTwoOrThreeBodyParagraphs() {
    let lived = BookPage(
      id: "one-glimpse-receipt",
      type: .souvenir,
      createdAt: date("2026-08-09T09:00:00Z"),
      promptText: "One true thing",
      userInput: "I put the chipped yellow bowl back on the shelf.",
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-09",
      date: date("2026-08-09T21:00:00Z"),
      pages: [lived]
    )

    let reading = BraidPromptBuilder.taleReading(for: day)
    let page = DeterministicBraidwright.page(for: day, context: .empty)
    let body = BraidPageDetails.details(for: page).body
    let paragraphs =
      body
      .replacingOccurrences(of: "\r\n", with: "\n")
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    XCTAssertEqual(reading.scale, .glimpse)
    XCTAssertTrue(
      (2...3).contains(paragraphs.count), "A Glimpse returned \(paragraphs.count) body paragraphs.")
  }

  func testPluralAnchorDoesNotFallBackToSingularPronouns() {
    let lived = BookPage(
      id: "plural-brass-keys",
      type: .souvenir,
      createdAt: date("2026-08-10T09:00:00Z"),
      promptText: "One true thing",
      userInput: "I gathered keys beside the kettle.",
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-10",
      date: date("2026-08-10T21:00:00Z"),
      pages: [lived]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let text = candidate.userInput.lowercased()
      XCTAssertFalse(text.contains("keys. it"))
      XCTAssertFalse(text.contains("keys has"))
      XCTAssertFalse(text.contains("keys was"))
      XCTAssertFalse(text.contains("keys under its"))
    }
  }

  func testHumanPluralNounsNeverBecomeTheMagicFurniture() {
    let lived = BookPage(
      id: "plural-human-receipt",
      type: .diary,
      createdAt: date("2026-08-10T10:00:00Z"),
      promptText: "Who was there?",
      userInput: "I sat beside friends, doctors, therapists, and patients.",
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-10",
      date: date("2026-08-10T21:00:00Z"),
      pages: [lived]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let details = BraidPageDetails.details(for: candidate)
      let text = details.body.lowercased()
      XCTAssertTrue(details.title.contains("Day"))
      for human in ["friends", "doctors", "therapists", "patients"] {
        XCTAssertFalse(text.contains("the \(human) chose"))
        XCTAssertFalse(text.contains("the \(human) laid down"))
        XCTAssertFalse(text.contains("the \(human) kept watch"))
      }
    }
  }

  func testLaterSafeNounCannotStealTheFirstReceiptsMagicAnchor() {
    let first = BookPage(
      id: "first-human-anchor",
      type: .diary,
      createdAt: date("2026-08-11T08:00:00Z"),
      promptText: "What happened first?",
      userInput: "I sat beside my cousin and the patient while both waited.",
      origin: .userAuthored
    )
    let later = BookPage(
      id: "later-mug",
      type: .souvenir,
      createdAt: date("2026-08-11T09:00:00Z"),
      promptText: "What happened later?",
      userInput: "I washed the blue mug.",
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-11",
      date: date("2026-08-11T21:00:00Z"),
      pages: [first, later]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let details = BraidPageDetails.details(for: candidate)
      let text = details.body.lowercased()
      XCTAssertTrue(details.title.contains("Day"))
      XCTAssertFalse(text.contains("the mug laid down a law"))
      XCTAssertFalse(text.contains("the mug chose my side"))
      // The colophon does not always lead with the subject, but the anchor it
      // closes on must still be the first receipt's and not the later mug's.
      guard let colophon = text.components(separatedBy: "the book kept the page:").last else {
        return XCTFail("no colophon in \(details.body)")
      }
      XCTAssertTrue(colophon.contains("the day"), colophon)
      XCTAssertFalse(colophon.contains("mug"), colophon)
    }
  }

  func testLabyrinthOnlyNightNeverPairsAThingWithItself() {
    let labyrinth = BookPage(
      id: "labyrinth-only-door",
      type: .narrativeOS,
      createdAt: date("2026-08-12T10:00:00Z"),
      promptText: "The Registry reached the stair.",
      userInput: "The brass door refused the Registry and swallowed its own latch.",
      tags: ["labyrinth-receipt"],
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-12",
      date: date("2026-08-12T21:00:00Z"),
      pages: [labyrinth]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let text = candidate.userInput.lowercased()
      XCTAssertFalse(text.contains("door answered door"))
      XCTAssertFalse(text.contains("door shut the way after the door"))
      XCTAssertFalse(text.contains("door kept watch over the door"))
    }
  }

  func testRepeatedLivedSubjectDoesNotAnswerItself() {
    let first = BookPage(
      id: "coffee-first",
      type: .diary,
      createdAt: date("2026-08-13T08:00:00Z"),
      promptText: "What happened first?",
      userInput: "I spilled coffee beside the sink.",
      origin: .userAuthored
    )
    let second = BookPage(
      id: "coffee-second",
      type: .souvenir,
      createdAt: date("2026-08-13T09:00:00Z"),
      promptText: "What happened later?",
      userInput: "I carried coffee to the window.",
      origin: .userAuthored
    )
    let day = BookDay(
      id: "2026-08-13",
      date: date("2026-08-13T21:00:00Z"),
      pages: [first, second]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let text = candidate.userInput.lowercased()
      XCTAssertFalse(text.contains("the coffee beside the coffee"))
      XCTAssertFalse(text.contains("the coffee and the coffee"))
      XCTAssertFalse(text.contains("coffee answered coffee"))
    }
  }

  func testMatchingLivedAndLabyrinthSubjectsBecomeTwoDoors() {
    let lived = BookPage(
      id: "lived-blue-door",
      type: .diary,
      createdAt: date("2026-08-14T08:00:00Z"),
      promptText: "What changed?",
      userInput: "I painted the blue door before breakfast.",
      origin: .userAuthored
    )
    let labyrinth = BookPage(
      id: "labyrinth-brass-door",
      type: .narrativeOS,
      createdAt: date("2026-08-14T09:00:00Z"),
      promptText: "The Registry knocked.",
      userInput: "The brass door refused the Registry and swallowed its latch.",
      tags: ["labyrinth-receipt"],
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-14",
      date: date("2026-08-14T21:00:00Z"),
      pages: [lived, labyrinth]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let text = candidate.userInput.lowercased()
      // Both receipts supplied a modifier, so the crossing keeps two named
      // identities rather than the weaker "the other door" label.
      XCTAssertTrue(text.contains("blue door"), candidate.userInput)
      XCTAssertTrue(text.contains("brass door"), candidate.userInput)
      XCTAssertFalse(text.contains("door answered door"))
      XCTAssertFalse(text.contains("door recognized the door"))
      XCTAssertFalse(text.contains("door kept watch over the door"))
    }
  }

  /// When only one side can name itself, the label is still the right answer.
  func testUnmodifiedMatchingSubjectsFallBackToATellingLabel() {
    let lived = BookPage(
      id: "lived-door",
      type: .diary,
      createdAt: date("2026-08-14T08:00:00Z"),
      promptText: "What changed?",
      userInput: "I painted a door before breakfast.",
      origin: .userAuthored
    )
    let labyrinth = BookPage(
      id: "labyrinth-door",
      type: .narrativeOS,
      createdAt: date("2026-08-14T09:00:00Z"),
      promptText: "The Registry knocked.",
      userInput: "A door refused the Registry and swallowed its latch.",
      tags: ["labyrinth-receipt"],
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-14",
      date: date("2026-08-14T21:00:00Z"),
      pages: [lived, labyrinth]
    )

    let candidates = DeterministicBraidwright.candidates(for: day, context: .empty)

    XCTAssertFalse(candidates.isEmpty)
    for candidate in candidates {
      let text = candidate.userInput.lowercased()
      XCTAssertTrue(text.contains("the other door"), candidate.userInput)
      XCTAssertFalse(text.contains("door answered door"))
      XCTAssertFalse(text.contains("door recognized the door"))
      XCTAssertFalse(text.contains("door kept watch over the door"))
    }
  }

  func testBraidwrightSpeaksAsAFeralFirstPersonBook() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )

    let page = DeterministicBraidwright.page(for: fixture.day, context: braidContext)
    let body = BraidPageDetails.details(for: page).body
    let spokenBody = body.components(separatedBy: "The Book kept the page:").first ?? body
    let lowered = spokenBody.lowercased()

    XCTAssertNotNil(
      spokenBody.range(
        of: #"(?i)\b(i|i'm|i've|i'll|i'd|me|my|mine)\b"#,
        options: .regularExpression
      ))
    XCTAssertTrue(
      [
        "i want", "i wanted", "i like", "i liked", "i took", "i chose", "i kept",
        "i don't", "i won't", "mine", "i stole", "i bit", "i eyed", "i underlined",
        "i counted", "i refused", "i hate", "i love", "i circled", "i set", "i drew",
        "i marked", "i gave", "i found", "i put", "i ignored", "i approved", "i obeyed",
      ].contains(where: { lowered.contains($0) }),
      "The Book should have a first-person appetite, opinion, or act of interference."
    )
    XCTAssertFalse(spokenBody.contains("The Book"))

    for servantPhrase in [
      "thank you for sharing", "i'm here to help", "i am here to help", "gentle reminder",
      "your journey", "it seems that", "this teaches us", "you should", "it's okay",
    ] {
      XCTAssertFalse(lowered.contains(servantPhrase))
    }
  }

  func testBraidwrightIsStableForTheSameDayAndContext() {
    let fixture = makeFixture()
    let braidContext = context(
      for: fixture,
      fictionPageID: fixture.wickerFiction.id,
      fictionChoice: fixture.wickerFiction.userInput
    )

    let firstPage = DeterministicBraidwright.page(for: fixture.day, context: braidContext)
    let secondPage = DeterministicBraidwright.page(for: fixture.day, context: braidContext)
    let firstCandidates = DeterministicBraidwright.candidates(
      for: fixture.day, context: braidContext)
    let secondCandidates = DeterministicBraidwright.candidates(
      for: fixture.day, context: braidContext)

    XCTAssertEqual(firstPage.promptText, secondPage.promptText)
    XCTAssertEqual(firstPage.userInput, secondPage.userInput)
    XCTAssertEqual(firstPage.tags, secondPage.tags)
    XCTAssertFalse(firstCandidates.isEmpty)
    XCTAssertEqual(firstCandidates.map(\.promptText), secondCandidates.map(\.promptText))
    XCTAssertEqual(firstCandidates.map(\.userInput), secondCandidates.map(\.userInput))
    XCTAssertEqual(firstCandidates.map(\.tags), secondCandidates.map(\.tags))
    XCTAssertTrue(firstCandidates.allSatisfy { $0.tags.contains("deterministic-braidwright") })
  }

  func testNightlyScoreCanChooseAKeptLabyrinthReceiptWithoutATextReply() {
    let lived = BookPage(
      id: "lived-window",
      type: .diary,
      createdAt: date("2026-08-04T09:00:00Z"),
      promptText: "What happened?",
      userInput: "I repaired the cracked latch on the kitchen window.",
      origin: .userAuthored
    )
    let labyrinth = BookPage(
      id: "labyrinth-penny",
      type: .gossip,
      createdAt: date("2026-08-04T10:00:00Z"),
      promptText: "A rumor crossed the Academy.",
      userInput: "Penny hid the brass bell before the Registry woke.",
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-04",
      date: date("2026-08-04T21:00:00Z"),
      pages: [lived, labyrinth]
    )

    let score = BraidPromptBuilder.nightlyStoryScore(
      for: day,
      context: .empty,
      connections: [],
      constellations: [],
      now: day.date
    )

    XCTAssertEqual(score.fictionBeat?.pageID, labyrinth.id)
    XCTAssertTrue(score.fictionBeat?.choice.contains("Penny") == true)
  }

  private struct Fixture {
    var day: BookDay
    var chair: BookPage
    var soup: BookPage
    var wickerFiction: BookPage
    var eddiesFiction: BookPage
  }

  private func makeFixture() -> Fixture {
    let chair = BookPage(
      id: "lived-blue-chair",
      type: .diary,
      createdAt: date("2026-08-03T08:00:00Z"),
      promptText: "What did your hands alter?",
      userInput: "I tightened the loose screw on the blue kitchen chair. Then I called Sam.",
      origin: .userAuthored
    )
    let soup = BookPage(
      id: "lived-soup-for-sam",
      type: .souvenir,
      createdAt: date("2026-08-03T12:00:00Z"),
      promptText: "One true thing",
      userInput: "I carried tomato soup to Sam and forgot the silver spoon.",
      origin: .userAuthored
    )
    let wickerFiction = BookPage(
      id: "fiction-wicker-refusal",
      type: .narrativeOS,
      createdAt: date("2026-08-03T13:00:00Z"),
      promptText: "The fox offered a shorter road.",
      userInput: "Wicker refused the fox's shortcut and crossed the root bridge.",
      tags: ["choice:refuse-the-shortcut"],
      sourceID: "narrative-os",
      origin: .generated
    )
    let eddiesFiction = BookPage(
      id: "fiction-eddies-bargain",
      type: .narrativeOS,
      createdAt: date("2026-08-03T14:00:00Z"),
      promptText: "The crow named its price.",
      userInput: "Eddies traded the paper crown for the crow's red thread.",
      tags: ["choice:trade-the-crown"],
      sourceID: "narrative-os",
      origin: .generated
    )
    let distractor = BookPage(
      id: "unselected-bronze-umbrella",
      type: .plainPage,
      createdAt: date("2026-08-03T15:00:00Z"),
      promptText: "",
      userInput: "I catalogued the bronze umbrella while the radiator knocked.",
      origin: .userAuthored
    )
    let weather = BookPage(
      id: "supporting-weather",
      type: .weather,
      createdAt: date("2026-08-03T16:00:00Z"),
      promptText: "Weather log",
      userInput: "Twenty degrees with a light west wind.",
      origin: .generated
    )
    let day = BookDay(
      id: "2026-08-03",
      date: date("2026-08-03T21:00:00Z"),
      pages: [chair, soup, wickerFiction, eddiesFiction, distractor, weather]
    )
    return Fixture(
      day: day,
      chair: chair,
      soup: soup,
      wickerFiction: wickerFiction,
      eddiesFiction: eddiesFiction
    )
  }

  private func context(
    for fixture: Fixture,
    fictionPageID: String,
    fictionChoice: String
  ) -> BraidPromptBuilder.Context {
    let reading = BraidPromptBuilder.TaleReading(
      scale: .small,
      motion: .repair,
      pressure: .rule,
      anchorPageID: fixture.chair.id,
      anchor: fixture.chair.userInput,
      turn: fixture.soup.userInput,
      visibleSupportingLogs: false,
      storyForm: .mosaic,
      rutInfluence: .notInThisTelling,
      narrativeRegister: .wry,
      rutEvidencePageIDs: []
    )
    let fictionName = fictionChoice.localizedCaseInsensitiveContains("Eddies") ? "Eddies" : "Wicker"
    let fictionOccurredAt =
      fixture.day.pages.first(where: { $0.id == fictionPageID })?.createdAt
      ?? fixture.day.date
    let score = BraidPromptBuilder.NightlyStoryScore(
      livedBeats: [
        BraidPromptBuilder.NightlyStoryScore.LivedBeat(
          pageID: fixture.chair.id,
          pageType: fixture.chair.type,
          occurredAt: fixture.chair.createdAt,
          excerpt: fixture.chair.userInput,
          role: "the exact repair that owns the spine"
        ),
        BraidPromptBuilder.NightlyStoryScore.LivedBeat(
          pageID: fixture.soup.id,
          pageType: fixture.soup.type,
          occurredAt: fixture.soup.createdAt,
          excerpt: fixture.soup.userInput,
          role: "a carried kindness with one useful thing absent"
        ),
      ],
      fictionBeat: BraidPromptBuilder.NightlyStoryScore.FictionBeat(
        pageID: fictionPageID,
        occurredAt: fictionOccurredAt,
        choice: fictionChoice,
        role: .mirror
      ),
      relationalLens: nil,
      arc: nil,
      taleReading: reading,
      magicLicense:
        "The supplied blue chair may make one petty rule that \(fictionName) must obey too.",
      endingDuty: "Return to the screw, the absent spoon, or both without resolving the absence.",
      forbiddenClaims: [
        "Do not invent what the reader felt.",
        "Do not turn Wicker or Eddies into an externally lived encounter.",
      ]
    )
    var result = BraidPromptBuilder.Context()
    result.taleReading = reading
    result.storyScore = score
    return result
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
