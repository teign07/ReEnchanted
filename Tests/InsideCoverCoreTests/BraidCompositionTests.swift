import XCTest

@testable import InsideCoverCore

/// The provenance map is the contract that makes it safe to let a language
/// model rewrite the Book's page. These tests guard the two halves of it: that
/// every sentence is accounted for, and that the reader's life is never filed
/// as the Book's opinion.
final class BraidCompositionTests: XCTestCase {
  // MARK: - Sentence splitting

  func testQuotedReaderWordsAreNotSplitAtTheirOwnFullStop() {
    let split = DeterministicBraidwright.splitSentences(
      "I copied this much and changed none of its words: «My sister called about the funeral. She sounded tired.» My pencil stayed still."
    )

    guard split.count == 2 else { return XCTFail("Expected 2 sentences, got \(split)") }
    XCTAssertTrue(split[0].hasSuffix("»"), split[0])
    XCTAssertTrue(split[0].contains("She sounded tired."), split[0])
    XCTAssertEqual(split[1], "My pencil stayed still.")
  }

  func testCastTitlesDoNotEndASentence() {
    let split = DeterministicBraidwright.splitSentences(
      "You sat with Dr. Inkrest for an hour. The lamp stayed on."
    )

    XCTAssertEqual(split, ["You sat with Dr. Inkrest for an hour.", "The lamp stayed on."])
  }

  func testOrdinaryProseSplitsOnEverySentence() {
    let split = DeterministicBraidwright.splitSentences(
      "I wanted the screw. I put my thumb on the line. Mine now!"
    )

    XCTAssertEqual(split.count, 3, "\(split)")
  }

  func testSplittingNeverLosesText() {
    let source =
      "Wicker refused the fox's shortcut. You said, «I would rather walk.» I approved. Loudly."
    let split = DeterministicBraidwright.splitSentences(source)

    XCTAssertEqual(split.joined(separator: " "), source)
  }

  // MARK: - Provenance

  func testCompositionTextMatchesTheRenderedPage() {
    let composition = DeterministicBraidwright.composition(
      for: fixtureDay(), context: fixtureContext())

    XCTAssertEqual(composition.text, composition.page.userInput)
    XCTAssertFalse(composition.sentences.isEmpty)
  }

  func testEveryLivedSentenceIsFiledUnderTheReceiptItCameFrom() {
    let composition = DeterministicBraidwright.composition(
      for: fixtureDay(), context: fixtureContext())

    // Matched by provenance and content, not by word order: a prose transform
    // may legitimately recast "you tightened the loose screw" as a cleft, and
    // the strict licence promises the content words survive, not the syntax.
    let chairSentence = composition.sentences.first {
      $0.provenance == .receipt(pageID: "lived-blue-chair")
        && $0.text.lowercased().contains("screw")
    }
    XCTAssertNotNil(chairSentence)
    XCTAssertEqual(chairSentence?.license, .strict)
    for word in ["screw", "blue", "kitchen", "chair", "tighten"] {
      XCTAssertTrue(
        chairSentence?.text.lowercased().contains(word) == true,
        "the strict receipt sentence dropped the content word \(word)")
    }
  }

  func testTheBooksOwnVoiceIsFreeAndTheColophonIsLocked() {
    let composition = DeterministicBraidwright.composition(
      for: fixtureDay(), context: fixtureContext())

    let colophon = composition.sentences.last
    XCTAssertEqual(colophon?.provenance, .colophon)
    XCTAssertEqual(colophon?.license, .locked)
    XCTAssertTrue(colophon?.text.hasPrefix("The Book kept the page:") == true)

    let authored = composition.sentences.filter { $0.provenance == .authored }
    XCTAssertFalse(authored.isEmpty, "The Book said nothing in its own voice.")
    XCTAssertTrue(authored.allSatisfy { $0.license == .free })
  }

  /// The register audit strips guillemets before judging voice, so a quoted
  /// sentence is the reader talking. Nothing may touch it.
  func testQuotedReaderWordsAreLockedAgainstRevision() {
    let bread = BookPage(
      id: "bread", type: .diary, createdAt: date("2026-08-05T08:00:00Z"),
      promptText: "?", userInput: "I walked to the corner shop for bread.",
      origin: .userAuthored)
    let grief = BookPage(
      id: "grief", type: .plainPage, createdAt: date("2026-08-05T18:00:00Z"),
      promptText: "?", userInput: "My sister called about the funeral arrangements.",
      origin: .userAuthored)
    let day = BookDay(
      id: "2026-08-05", date: date("2026-08-05T21:00:00Z"), pages: [bread, grief])

    let composition = DeterministicBraidwright.composition(for: day, context: .empty)
    let quoted = composition.sentences.filter { $0.text.contains("«") }

    XCTAssertFalse(quoted.isEmpty, composition.text)
    for sentence in quoted {
      XCTAssertEqual(sentence.license, .locked, sentence.text)
      XCTAssertNotNil(sentence.pageID, sentence.text)
    }
  }

  func testNoSentenceIsLeftWithoutAProvenance() {
    // Reconstructing the page from the map must lose nothing, or some sentence
    // is travelling without papers.
    for scenario in [fixtureDay(), thinDay()] {
      let composition = DeterministicBraidwright.composition(for: scenario, context: .empty)
      let rebuilt =
        ([composition.title]
          + composition.paragraphs.map { $0.map(\.text).joined(separator: " ") })
        .joined(separator: "\n\n")
      XCTAssertEqual(rebuilt, composition.text)
    }
  }

  // MARK: - Fixtures

  private func fixtureDay() -> BookDay {
    let chair = BookPage(
      id: "lived-blue-chair", type: .diary, createdAt: date("2026-08-03T08:00:00Z"),
      promptText: "What did your hands alter?",
      userInput: "I tightened the loose screw on the blue kitchen chair. Then I called Sam.",
      origin: .userAuthored)
    let soup = BookPage(
      id: "lived-soup-for-sam", type: .souvenir, createdAt: date("2026-08-03T12:00:00Z"),
      promptText: "One true thing",
      userInput: "I carried tomato soup to Sam and forgot the silver spoon.",
      origin: .userAuthored)
    let fiction = BookPage(
      id: "fiction-wicker-refusal", type: .narrativeOS, createdAt: date("2026-08-03T13:00:00Z"),
      promptText: "The fox offered a shorter road.",
      userInput: "Wicker refused the fox's shortcut and crossed the root bridge.",
      tags: ["choice:refuse-the-shortcut"], sourceID: "narrative-os", origin: .generated)
    return BookDay(
      id: "2026-08-03", date: date("2026-08-03T21:00:00Z"), pages: [chair, soup, fiction])
  }

  private func thinDay() -> BookDay {
    let only = BookPage(
      id: "only", type: .souvenir, createdAt: date("2026-08-09T09:00:00Z"),
      promptText: "One true thing", userInput: "I put the chipped yellow bowl back on the shelf.",
      origin: .userAuthored)
    return BookDay(id: "2026-08-09", date: date("2026-08-09T21:00:00Z"), pages: [only])
  }

  private func fixtureContext() -> BraidPromptBuilder.Context {
    let day = fixtureDay()
    let chair = day.pages[0]
    let soup = day.pages[1]
    let fiction = day.pages[2]
    let reading = BraidPromptBuilder.TaleReading(
      scale: .small, motion: .repair, pressure: .rule, anchorPageID: chair.id,
      anchor: chair.userInput, turn: soup.userInput, visibleSupportingLogs: false,
      storyForm: .mosaic, rutInfluence: .notInThisTelling, narrativeRegister: .wry,
      rutEvidencePageIDs: [])
    var context = BraidPromptBuilder.Context()
    context.taleReading = reading
    context.storyScore = BraidPromptBuilder.NightlyStoryScore(
      livedBeats: [
        .init(
          pageID: chair.id, pageType: chair.type, occurredAt: chair.createdAt,
          excerpt: chair.userInput, role: "spine"),
        .init(
          pageID: soup.id, pageType: soup.type, occurredAt: soup.createdAt,
          excerpt: soup.userInput, role: "kindness"),
      ],
      fictionBeat: .init(
        pageID: fiction.id, occurredAt: fiction.createdAt, choice: fiction.userInput,
        role: .mirror),
      relationalLens: nil, arc: nil, taleReading: reading,
      magicLicense: "one law", endingDuty: "return to the screw", forbiddenClaims: [])
    return context
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// The verifier is the load-bearing safety property of the cooperative design:
/// a language model may change the music of the Book's page, and may not change
/// what happened to the reader. Most of these tests are attempts to smuggle
/// something past it.
final class BraidRevisionVerifierTests: XCTestCase {
  // MARK: - Word rules

  func testInflectionIsMusicButADifferentWordIsADifferentClaim() {
    XCTAssertTrue(BraidRevisionVerifier.matches("tightened", "tighten"))
    XCTAssertTrue(BraidRevisionVerifier.matches("screw", "screws"))
    XCTAssertTrue(BraidRevisionVerifier.matches("carries", "carry"))
    XCTAssertTrue(BraidRevisionVerifier.matches("fox's", "fox"))
    XCTAssertFalse(BraidRevisionVerifier.matches("chair", "table"))
    XCTAssertFalse(BraidRevisionVerifier.matches("sister", "mother"))
    XCTAssertFalse(BraidRevisionVerifier.matches("soup", "stew"))
  }

  func testGrammarIsNotContent() {
    let words = BraidRevisionVerifier.contentWords(
      in: "I tightened the loose screw on the blue kitchen chair.")

    XCTAssertTrue(words.contains("tightened"))
    XCTAssertTrue(words.contains("screw"))
    XCTAssertTrue(words.contains("chair"))
    XCTAssertFalse(words.contains("the"))
    XCTAssertFalse(words.contains("on"))
    XCTAssertFalse(words.contains("i"))
  }

  func testTheReadersNounsAreTheAnchors() {
    let anchors = BraidRevisionVerifier.anchorWords(
      in: "You tightened the loose screw on the blue kitchen chair.")

    XCTAssertTrue(anchors.contains("screw"), "\(anchors)")
    XCTAssertTrue(anchors.contains("chair"), "\(anchors)")
  }

  // MARK: - Smuggling attempts

  func testAModelMayNotInventADetailInARetoldReceipt() {
    let original = composition()
    let result = BraidRevisionVerifier.verify(
      revision: revision(
        of: original, replacing: 0,
        with: "On the blue kitchen chair you tightened a loose screw, grieving."),
      of: original, day: day(), context: .empty)

    let invention = result.decisions.first { $0.rejection == .addedContentWord }
    XCTAssertNotNil(invention, "The verifier accepted an invented detail. \(result.rejections)")
    XCTAssertEqual(invention?.offendingWords, ["grieving"])
    XCTAssertFalse(result.composition.text.contains("grieving"))
    XCTAssertFalse(result.adopted)
  }

  func testAModelMayNotDropTheEvidenceOutOfARetoldReceipt() {
    let original = composition()
    let result = BraidRevisionVerifier.verify(
      revision: revision(of: original, replacing: 0, with: "You tightened it."),
      of: original, day: day(), context: .empty)

    let dropped = result.decisions.first { $0.rejection == .droppedAnchorWord }
    XCTAssertNotNil(dropped, "\(result.rejections)")
    XCTAssertTrue(dropped?.offendingWords.contains("screw") == true, "\(dropped?.offendingWords ?? [])")
    XCTAssertTrue(result.composition.text.contains("the loose screw on the blue kitchen chair"))
  }

  func testAModelMayNotRewriteTheReadersQuotedWords() {
    let original = quotedComposition()
    guard let index = original.sentences.firstIndex(where: { $0.text.contains("«") }) else {
      return XCTFail("no quoted sentence in \(original.text)")
    }
    let result = BraidRevisionVerifier.verify(
      revision: revision(
        of: original, replacing: index,
        with: "I copied this much and changed none of its words: «My sister rang about it.»"),
      of: original, day: quotedDay(), context: .empty)

    XCTAssertTrue(
      result.decisions.contains { $0.rejection == .changedLockedSentence }, "\(result.rejections)")
    XCTAssertTrue(result.composition.text.contains("called about the funeral arrangements"))
  }

  func testAModelMayNotRewriteTheRitualLine() {
    let original = composition()
    guard let index = original.sentences.firstIndex(where: { $0.provenance == .colophon }) else {
      return XCTFail("no colophon")
    }
    let result = BraidRevisionVerifier.verify(
      revision: revision(
        of: original, replacing: index, with: "In the end, the lesson was to keep going."),
      of: original, day: day(), context: .empty)

    XCTAssertTrue(
      result.decisions.contains { $0.rejection == .changedLockedSentence }, "\(result.rejections)")
    XCTAssertTrue(result.composition.text.contains("The Book kept the page:"))
    XCTAssertFalse(result.composition.text.contains("the lesson was"))
  }

  func testAReshapedPageIsNotGuessedAt() {
    let original = composition()
    let result = BraidRevisionVerifier.verify(
      revision: """
        \(original.title)

        You tightened the loose screw. And then something else entirely happened here.

        The Book kept the page: the screw kept watch over what happened.
        """,
      of: original, day: day(), context: .empty)

    XCTAssertTrue(
      result.decisions.contains { $0.rejection == .unalignedParagraph }, "\(result.rejections)")
    XCTAssertFalse(result.adopted)
    XCTAssertEqual(result.composition.text, original.text)
  }

  func testEmptyRevisionsAreRefused() {
    let original = composition()
    let result = BraidRevisionVerifier.verify(
      revision: "", of: original, day: day(), context: .empty)

    XCTAssertFalse(result.adopted)
    XCTAssertEqual(result.composition.text, original.text)
  }

  // MARK: - What it must allow

  func testTheBooksOwnVoiceMayBeRewrittenFreely() {
    let original = composition()
    guard let index = original.sentences.firstIndex(where: { $0.provenance == .authored }) else {
      return XCTFail("no authored sentence")
    }
    let replacement = "I bit the sentence in half and kept the louder end."
    let result = BraidRevisionVerifier.verify(
      revision: revision(of: original, replacing: index, with: replacement),
      of: original, day: day(), context: .empty)

    let decision = result.decisions[index]
    XCTAssertTrue(decision.accepted, "\(String(describing: decision.rejection))")
    XCTAssertEqual(decision.revised, replacement)
    XCTAssertTrue(decision.changed)
  }

  func testARetoldReceiptMayBeRearrangedWithoutLosingItsFacts() {
    let original = composition()
    let result = BraidRevisionVerifier.verify(
      revision: revision(
        of: original, replacing: 0,
        with: "On the blue kitchen chair, a loose screw: you tightened it."),
      of: original, day: day(), context: .empty)

    XCTAssertTrue(result.decisions[0].accepted, "\(result.rejections)")
    XCTAssertTrue(result.decisions[0].changed)
  }

  /// A page that merely paraphrases into competence must not displace the
  /// house cut. Only a revision that tastes better earns the reader's evening.
  func testABlandRevisionDoesNotDisplaceTheHouseCut() {
    let original = composition()
    let result = BraidRevisionVerifier.verify(
      revision: original.text, of: original, day: day(), context: .empty)

    XCTAssertFalse(result.adopted)
    XCTAssertEqual(result.composition.text, original.text)
    XCTAssertFalse(result.composition.tags.contains("braid-model-revised"))
  }

  func testAWorseRevisionIsRefusedEvenWhenEverySentencePasses() {
    let original = composition()
    guard let index = original.sentences.firstIndex(where: { $0.provenance == .authored }) else {
      return XCTFail("no authored sentence")
    }
    // Legal by every word rule, and duller. The tasting room is the last gate.
    let result = BraidRevisionVerifier.verify(
      revision: revision(of: original, replacing: index, with: "It was fine."),
      of: original, day: day(), context: .empty)

    XCTAssertTrue(result.decisions[index].accepted)
    XCTAssertLessThanOrEqual(result.revisedScore, result.originalScore)
    XCTAssertFalse(result.adopted)
    XCTAssertEqual(result.composition.text, original.text)
  }

  // MARK: - Fixtures

  /// Build a revision by replacing exactly one sentence of a real composition,
  /// so the test exercises the rule under scrutiny rather than the alignment.
  private func revision(
    of composition: BraidComposition, replacing index: Int, with text: String
  ) -> String {
    var paragraphs = composition.paragraphs
    var seen = 0
    for paragraph in paragraphs.indices {
      for sentence in paragraphs[paragraph].indices {
        if seen == index { paragraphs[paragraph][sentence].text = text }
        seen += 1
      }
    }
    return ([composition.title] + paragraphs.map { $0.map(\.text).joined(separator: " ") })
      .joined(separator: "\n\n")
  }

  private func day() -> BookDay {
    let chair = BookPage(
      id: "lived-blue-chair", type: .diary, createdAt: date("2026-08-03T08:00:00Z"),
      promptText: "What did your hands alter?",
      userInput: "I tightened the loose screw on the blue kitchen chair. Then I called Sam.",
      origin: .userAuthored)
    return BookDay(id: "2026-08-03", date: date("2026-08-03T21:00:00Z"), pages: [chair])
  }

  private func composition() -> BraidComposition {
    DeterministicBraidwright.composition(for: day(), context: .empty)
  }

  private func quotedDay() -> BookDay {
    let bread = BookPage(
      id: "bread", type: .diary, createdAt: date("2026-08-05T08:00:00Z"),
      promptText: "?", userInput: "I walked to the corner shop for bread.",
      origin: .userAuthored)
    let grief = BookPage(
      id: "grief", type: .plainPage, createdAt: date("2026-08-05T18:00:00Z"),
      promptText: "?", userInput: "My sister called about the funeral arrangements.",
      origin: .userAuthored)
    return BookDay(
      id: "2026-08-05", date: date("2026-08-05T21:00:00Z"), pages: [bread, grief])
  }

  private func quotedComposition() -> BraidComposition {
    DeterministicBraidwright.composition(for: quotedDay(), context: .empty)
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// The prompt is not trusted (the verifier checks everything that comes back)
/// but it still has to describe the page accurately, or most sentences will be
/// refused and the model will have burned a generation for nothing.
final class BraidVoiceRevisionPromptTests: XCTestCase {
  func testEverySentenceReachesTheModelWithItsLicence() {
    let composition = DeterministicBraidwright.composition(for: day(), context: .empty)
    let prompt = BraidPromptBuilder.voiceRevisionPrompt(
      for: day(), context: .empty, composition: composition)

    for sentence in composition.sentences {
      XCTAssertTrue(prompt.contains(sentence.text), "missing from prompt: \(sentence.text)")
    }
    XCTAssertTrue(prompt.contains(composition.title))

    // Count only the numbered sentence lines; the rules preamble names every
    // marker too.
    let listed = prompt.components(separatedBy: "\n").filter {
      $0.hasPrefix("  ") && $0.contains(". [")
    }
    XCTAssertEqual(listed.count, composition.sentences.count)
    XCTAssertEqual(
      listed.filter { $0.contains("DO NOT TOUCH") }.count,
      composition.sentences.filter { $0.license == .locked }.count)
    XCTAssertEqual(
      listed.filter { $0.contains("FACTS LOCKED") }.count,
      composition.sentences.filter { $0.license == .strict }.count)
    XCTAssertEqual(
      listed.filter { $0.contains("[FREE") }.count,
      composition.sentences.filter { $0.license == .free }.count)
  }

  func testTheColophonIsHandedOverAsUntouchable() {
    let composition = DeterministicBraidwright.composition(for: day(), context: .empty)
    let prompt = BraidPromptBuilder.voiceRevisionPrompt(
      for: day(), context: .empty, composition: composition)

    guard let colophon = composition.sentences.last else { return XCTFail("no colophon") }
    guard let line = prompt.components(separatedBy: "\n").first(where: {
      $0.contains(colophon.text)
    }) else { return XCTFail("colophon missing from prompt") }
    XCTAssertTrue(line.contains("DO NOT TOUCH"), line)
  }

  func testTheModelIsToldTheShapeItMustReturn() {
    let composition = DeterministicBraidwright.composition(for: day(), context: .empty)
    let prompt = BraidPromptBuilder.voiceRevisionPrompt(
      for: day(), context: .empty, composition: composition)

    XCTAssertTrue(prompt.contains("One sentence in, one sentence out."))
    XCTAssertEqual(
      prompt.components(separatedBy: "Paragraph ").count - 1, composition.paragraphs.count)
  }

  private func day() -> BookDay {
    let chair = BookPage(
      id: "lived-blue-chair", type: .diary, createdAt: date("2026-08-03T08:00:00Z"),
      promptText: "What did your hands alter?",
      userInput: "I tightened the loose screw on the blue kitchen chair. Then I called Sam.",
      origin: .userAuthored)
    return BookDay(id: "2026-08-03", date: date("2026-08-03T21:00:00Z"), pages: [chair])
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// Transforms rearrange the reader's words and bring none of their own. The
/// interesting tests are the ones where a transform must *decline*: confident
/// nonsense is worse than a plain sentence.
final class BraidProseTransformTests: XCTestCase {
  // MARK: - What it should do

  func testATrailingPlaceMovesToTheFront() {
    let result = BraidProseTransform.frontedPhrase.apply(
      to: "You tightened the loose screw on the blue kitchen chair.")

    XCTAssertEqual(result, "On the blue kitchen chair, you tightened the loose screw.")
  }

  func testACleftPutsTheObjectFirst() {
    let result = BraidProseTransform.cleft.apply(to: "You tightened the loose screw.")

    XCTAssertEqual(result, "It was the loose screw that you tightened.")
  }

  func testAClauseSplitsAtItsConjunction() {
    let result = BraidProseTransform.splitAtConjunction.apply(
      to: "You carried tomato soup to Sam and forgot the silver spoon.")

    XCTAssertEqual(result, "You carried tomato soup to Sam. And forgot the silver spoon.")
  }

  // MARK: - What it must refuse

  /// "Of the car" belongs to the seat, not to the sentence. Hoisting it makes a
  /// grammatical sentence that says something the reader never wrote.
  func testAPhraseBelongingToItsNounIsNotHoisted() {
    let result = BraidProseTransform.frontedPhrase.apply(
      to: "You found the spare keys under the seat of the car.")

    XCTAssertNotEqual(result, "Of the car, you found the spare keys under the seat.")
    if let result { XCTAssertFalse(result.hasPrefix("Of the car"), result) }
  }

  func testAnArgumentOfTheVerbIsNotHoisted() {
    let result = BraidProseTransform.frontedPhrase.apply(
      to: "You finally posted the letter to the bank.")

    if let result { XCTAssertFalse(result.hasPrefix("To the bank"), result) }
  }

  /// A clock modifies the action, not the thing. The coda has to stay with the
  /// verb it timed.
  func testACleftDoesNotSwallowTheClock() {
    let result = BraidProseTransform.cleft.apply(to: "You painted the blue door before breakfast.")

    XCTAssertEqual(result, "It was the blue door that you painted before breakfast.")
  }

  func testASentenceWithNoRoomToMoveIsLeftAlone() {
    for stubborn in [
      "You rested.",
      "Cold tea.",
      "You walked to the corner shop for bread and it started raining.",
    ] {
      let rearranged = BraidProseTransform.rearranged(stubborn, variant: 0)
      XCTAssertTrue(
        rearranged == stubborn
          || BraidRevisionVerifier.preservesFacts(rearranged, of: stubborn),
        "\(stubborn) -> \(rearranged)")
    }
  }

  // MARK: - The standing guarantee

  func testNoTransformEverAddsOrLosesAFact() {
    let sentences = [
      "You tightened the loose screw on the blue kitchen chair.",
      "You carried tomato soup to Sam and forgot the silver spoon.",
      "You found the spare keys under the seat of the car.",
      "You painted the blue door before breakfast.",
      "You swam in the lido and stayed in past the cold.",
      "You read forty pages standing up because you forgot to sit.",
      "You put the chipped yellow bowl back on the shelf.",
      "You bought plums and a bunch of coriander at the market.",
      "Cold tea. Again.",
      "went to the river with dad and we didnt talk much",
      "My mother said \"you never call on a Tuesday\" and then laughed about it.",
    ]
    for sentence in sentences {
      for variant in 0..<BraidProseTransform.allCases.count {
        let rearranged = BraidProseTransform.rearranged(sentence, variant: variant)
        XCTAssertTrue(
          BraidRevisionVerifier.preservesFacts(rearranged, of: sentence),
          "variant \(variant): \(sentence) -> \(rearranged)")
      }
    }
  }

  func testRearrangingIsDeterministic() {
    let sentence = "You tightened the loose screw on the blue kitchen chair."
    for variant in 0..<6 {
      XCTAssertEqual(
        BraidProseTransform.rearranged(sentence, variant: variant),
        BraidProseTransform.rearranged(sentence, variant: variant))
    }
  }

  /// The reader's quoted words are never rearranged, whatever the variant.
  func testQuotedReceiptsAreNeverTransformed() {
    let day = BookDay(
      id: "2026-08-05",
      date: ISO8601DateFormatter().date(from: "2026-08-05T21:00:00Z")!,
      pages: [
        BookPage(
          id: "bread", type: .diary,
          createdAt: ISO8601DateFormatter().date(from: "2026-08-05T08:00:00Z")!,
          promptText: "?", userInput: "I walked to the corner shop for bread.",
          origin: .userAuthored),
        BookPage(
          id: "grief", type: .plainPage,
          createdAt: ISO8601DateFormatter().date(from: "2026-08-05T18:00:00Z")!,
          promptText: "?", userInput: "My sister called about the funeral arrangements.",
          origin: .userAuthored),
      ])

    for composition in DeterministicBraidwright.compositions(for: day, context: .empty) {
      XCTAssertTrue(
        composition.text.contains("«My sister called about the funeral arrangements.»"),
        composition.text)
    }
  }
}

/// Rhythm is most of what reads as authorship. These guard the two failures
/// that carry: every sentence starting the same way, and every sentence the
/// same length.
final class BraidProsodyTests: XCTestCase {
  func testAdjacentRepeatedOpeningsAreCounted() {
    let composition = BraidComposition(
      title: "T",
      paragraphs: [[
        BraidSentence(text: "I kept the screw.", provenance: .authored),
        BraidSentence(text: "I moved the screw.", provenance: .authored),
        BraidSentence(text: "Then the screw moved me.", provenance: .authored),
      ]],
      tags: [], promptText: "x")

    XCTAssertEqual(composition.prosody.repeatedOpenings, 1)
  }

  func testSettlingBeatsDoNotStackTheSameOpening() {
    for night in BraidBench.corpus() {
      let composition = DeterministicBraidwright.composition(
        for: night.day, context: night.context)
      let openings = composition.sentences.map { BraidComposition.openingWord(of: $0.text) }
      guard openings.count > 2 else { continue }
      for index in 2..<openings.count {
        XCTAssertFalse(
          openings[index] == openings[index - 1] && openings[index] == openings[index - 2],
          "\(night.name): three sentences in a row open on '\(openings[index])'")
      }
    }
  }

  /// The crossing is the page's one impossible relation and its most important
  /// paragraph. Its two halves must not both open on the same word.
  func testTheCrossingDoesNotEchoItsOwnOpening() {
    let lived = BookPage(
      id: "lamp", type: .diary, createdAt: date("2026-08-13T08:00:00Z"),
      promptText: "?", userInput: "I rewired the brass lamp in the hallway.",
      origin: .userAuthored)
    let fiction = BookPage(
      id: "fox", type: .narrativeOS, createdAt: date("2026-08-13T19:00:00Z"),
      promptText: "?", userInput: "The fox offered a shorter road through the root bridge.",
      tags: ["choice:refuse-the-shortcut"], sourceID: "narrative-os", origin: .generated)
    let day = BookDay(
      id: "2026-08-13", date: date("2026-08-13T21:00:00Z"), pages: [lived, fiction])

    let composition = DeterministicBraidwright.composition(for: day, context: .empty)
    XCTAssertEqual(composition.prosody.repeatedOpenings, 0, composition.text)
  }

  func testProsodyBreaksTiesWithoutBreakingDeterminism() {
    for night in BraidBench.corpus() {
      let first = DeterministicBraidwright.composition(for: night.day, context: night.context)
      let second = DeterministicBraidwright.composition(for: night.day, context: night.context)
      XCTAssertEqual(first.prosody, second.prosody, night.name)
    }
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// The compiler used to read four of the twenty-five fields on its own context
/// and forfeit three tasting components by construction. These are the ones it
/// now spends.
final class BraidContextSpendingTests: XCTestCase {
  /// A One-Sentence Souvenir is the reader stopping to choose one true line.
  /// It should own the page even when it was kept last.
  func testASouvenirTakesTheSpineFromAnEarlierPage() {
    let errand = BookPage(
      id: "errand", type: .diary, createdAt: date("2026-08-29T09:00:00Z"),
      promptText: "?", userInput: "I dropped the parcel at the post office.",
      origin: .userAuthored)
    let souvenir = BookPage(
      id: "souvenir", type: .souvenir, createdAt: date("2026-08-29T20:00:00Z"),
      promptText: "One true thing",
      userInput: "I stood in the doorway and listened to the whole song before coming in.",
      origin: .userAuthored)
    let day = BookDay(
      id: "2026-08-29", date: date("2026-08-29T21:00:00Z"), pages: [errand, souvenir])

    var context = BraidPromptBuilder.Context()
    context.souvenirAnchor = BraidPromptBuilder.SouvenirAnchor(
      pageID: "souvenir", pageTitle: "One true thing", keptText: souvenir.userInput,
      keptAt: souvenir.createdAt, reason: "chosen", score: 90)

    let anchored = DeterministicBraidwright.composition(for: day, context: context)
    let unanchored = DeterministicBraidwright.composition(for: day, context: .empty)

    XCTAssertTrue(anchored.title.lowercased().contains("doorway"), anchored.title)
    XCTAssertTrue(
      anchored.sentences.last?.text.lowercased().contains("doorway") == true,
      anchored.sentences.last?.text ?? "")
    XCTAssertNotEqual(anchored.text, unanchored.text)
  }

  func testTheBookUsesTheNameItGaveTheReader() {
    guard let role = ReaderRoleRegistry.all.first else { return XCTFail("no roles") }
    var context = BraidPromptBuilder.Context()
    context.readerRole = ComposedRole(role: role, epithet: nil, hands: nil, mark: nil)

    let candidates = DeterministicBraidwright.compositions(for: plainDay(), context: context)
    XCTAssertTrue(
      candidates.contains { $0.text.contains(role.name) },
      "The Book named this reader and then never said the name.")
  }

  func testAStandingTaleLawReachesThePage() {
    var context = BraidPromptBuilder.Context()
    context.standingTaleLaws = ["Anything left open has to be closed by the one who opened it."]

    let candidates = DeterministicBraidwright.compositions(for: plainDay(), context: context)
    XCTAssertTrue(
      candidates.contains { $0.text.contains("has to be closed by the one who opened it") })
  }

  func testAThemeMotifReachesThePageWithoutNamingTheTheme() {
    var context = BraidPromptBuilder.Context()
    context.theme = BookTheme(
      id: "t", monthKey: "2026-08", name: "Thresholds", motifs: ["doorways"],
      line: "You keep stopping at the edge of rooms.", strength: 8,
      evidencePageIDs: [], excerptLines: [], discoveredAt: date("2026-08-30T21:00:00Z"),
      stability: .stable, observedDayCount: 12, settledAt: nil)

    let candidates = DeterministicBraidwright.compositions(for: plainDay(), context: context)
    XCTAssertTrue(candidates.contains { $0.text.lowercased().contains("doorways") })
    // Naming the theme out loud is penalised by the tasting room, and rightly:
    // a watermark announced is no longer a watermark.
    XCTAssertFalse(candidates.contains { $0.text.contains("Thresholds") })
  }

  /// On a night carrying uncleared shadow the page stays plain. The Book does
  /// not choose that moment to show how much it has been noticing.
  func testTheBookStaysQuietAboutItselfOnAShadowNight() {
    let bread = BookPage(
      id: "bread", type: .diary, createdAt: date("2026-08-05T08:00:00Z"),
      promptText: "?", userInput: "I walked to the corner shop for bread.",
      origin: .userAuthored)
    let grief = BookPage(
      id: "grief", type: .plainPage, createdAt: date("2026-08-05T18:00:00Z"),
      promptText: "?", userInput: "My sister called about the funeral arrangements.",
      origin: .userAuthored)
    let day = BookDay(
      id: "2026-08-05", date: date("2026-08-05T21:00:00Z"), pages: [bread, grief])

    var context = BraidPromptBuilder.Context()
    context.standingTaleLaws = ["Anything left open has to be closed by the one who opened it."]
    context.theme = BookTheme(
      id: "t", monthKey: "2026-08", name: "Thresholds", motifs: ["doorways"],
      line: "x", strength: 8, evidencePageIDs: [], excerptLines: [],
      discoveredAt: day.date, stability: .stable, observedDayCount: 12, settledAt: nil)

    for composition in DeterministicBraidwright.compositions(for: day, context: context) {
      XCTAssertFalse(composition.text.contains("The old law still holds"), composition.text)
      XCTAssertFalse(composition.text.lowercased().contains("doorways"), composition.text)
    }
  }

  private func plainDay() -> BookDay {
    let window = BookPage(
      id: "window", type: .diary, createdAt: date("2026-08-30T08:00:00Z"),
      promptText: "?", userInput: "I opened every window in the flat before the heat came.",
      origin: .userAuthored)
    return BookDay(id: "2026-08-30", date: date("2026-08-30T21:00:00Z"), pages: [window])
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// The archive callback is the one sentence a context-limited model cannot
/// write. It is also the easiest place to manufacture significance, so most of
/// these tests are about when it must stay quiet.
final class BraidArchiveEchoTests: XCTestCase {
  func testASubjectKeptForMonthsEarnsItsCallback() {
    let context = historyContext(occasions: 4, firstSeenDaysAgo: 90)
    let composition = DeterministicBraidwright.composition(for: today(), context: context)

    XCTAssertTrue(composition.text.contains("I have kept the doorway"), composition.text)
    XCTAssertTrue(composition.text.contains("The first was in"), composition.text)
  }

  /// Two mentions is a coincidence. The Book does not get to call it a pattern.
  func testASubjectSeenTwiceStaysQuiet() {
    let context = historyContext(occasions: 2, firstSeenDaysAgo: 90)
    let composition = DeterministicBraidwright.composition(for: today(), context: context)

    XCTAssertFalse(composition.text.contains("I have kept the doorway"), composition.text)
  }

  /// A subject that only turned up this week needs no announcing.
  func testARecentSubjectStaysQuiet() {
    let context = historyContext(occasions: 5, firstSeenDaysAgo: 4)
    let composition = DeterministicBraidwright.composition(for: today(), context: context)

    XCTAssertFalse(composition.text.contains("I have kept the doorway"), composition.text)
  }

  func testTheCallbackNeverFiresOnAShadowNight() {
    let grief = BookPage(
      id: "grief", type: .plainPage, createdAt: date("2026-08-30T18:00:00Z"),
      promptText: "?", userInput: "My sister called about the funeral arrangements.",
      origin: .userAuthored)
    let doorway = BookPage(
      id: "doorway", type: .diary, createdAt: date("2026-08-30T08:00:00Z"),
      promptText: "?", userInput: "I stood in the doorway again.", origin: .userAuthored)
    let day = BookDay(
      id: "2026-08-30", date: date("2026-08-30T21:00:00Z"), pages: [doorway, grief])

    var context = historyContext(occasions: 6, firstSeenDaysAgo: 120)
    for composition in DeterministicBraidwright.compositions(for: day, context: context) {
      XCTAssertFalse(composition.text.contains("I have kept"), composition.text)
    }
    context = .empty
  }

  /// Counting mentions rather than days would let one talkative evening look
  /// like six months of caring.
  func testHistoryCountsDaysNotMentions() {
    let chatty = BookDay(
      id: "2026-06-01",
      date: date("2026-06-01T21:00:00Z"),
      pages: (1...5).map { index in
        BookPage(
          id: "chatty-\(index)", type: .diary,
          createdAt: date("2026-06-01T0\(index):00:00Z"),
          promptText: "?", userInput: "I stood in the doorway again.", origin: .userAuthored)
      })

    let history = BraidPromptBuilder.subjectHistory(before: today(), in: [chatty])
    XCTAssertEqual(history["doorway"]?.occasions, 1, "\(history["doorway"] as Any)")
  }

  func testGrammarWordsNeverBecomeSubjects() {
    let day = BookDay(
      id: "2026-06-02", date: date("2026-06-02T21:00:00Z"),
      pages: [
        BookPage(
          id: "p", type: .diary, createdAt: date("2026-06-02T09:00:00Z"),
          promptText: "?", userInput: "I would have gone but there was something else.",
          origin: .userAuthored)
      ])
    let history = BraidPromptBuilder.subjectHistory(before: today(), in: [day])

    for grammar in ["would", "there", "something", "that", "with"] {
      XCTAssertNil(history[grammar], grammar)
    }
  }

  // MARK: - Fixtures

  private func today() -> BookDay {
    let doorway = BookPage(
      id: "doorway", type: .diary, createdAt: date("2026-08-30T08:00:00Z"),
      promptText: "?", userInput: "I stood in the doorway and listened.",
      origin: .userAuthored)
    return BookDay(id: "2026-08-30", date: date("2026-08-30T21:00:00Z"), pages: [doorway])
  }

  private func historyContext(occasions: Int, firstSeenDaysAgo: Int) -> BraidPromptBuilder.Context {
    let now = date("2026-08-30T21:00:00Z")
    var context = BraidPromptBuilder.Context()
    context.subjectHistory = [
      "doorway": BraidPromptBuilder.SubjectHistory(
        occasions: occasions,
        firstSeen: now.addingTimeInterval(-Double(firstSeenDaysAgo) * 86_400),
        lastSeen: now.addingTimeInterval(-7 * 86_400))
    ]
    return context
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// A heavy day fires the supporting move once per beat. Two beats landing the
/// same authored sentence is the most template-like thing the page can do, and
/// the fix was to reach the fourteen form and motion phrasings that a fixed
/// form and motion had made unreachable.
final class BraidSupportingMoveTests: XCTestCase {
  func testNoAuthoredRelationIsUsedTwiceOnOnePage() {
    for night in BraidBench.corpus() {
      for composition in DeterministicBraidwright.compositions(
        for: night.day, context: night.context)
      {
        let authored = composition.sentences
          .filter { $0.provenance == .authored }
          .map(\.text)
        XCTAssertEqual(
          authored.count, Set(authored).count,
          "\(night.name) said the same thing twice:\n\(composition.text)")
      }
    }
  }

  func testAHeavyDayCarriesEveryKeptPage() {
    guard let heavy = BraidBench.corpus().first(where: { $0.name == "full-braid" }) else {
      return XCTFail("missing fixture")
    }
    let composition = DeterministicBraidwright.composition(
      for: heavy.day, context: heavy.context)

    // Five lived receipts were kept. A braid is not a list, but neither may it
    // silently drop two of them because of a cap written for a thin night.
    for fragment in ["plums", "landlord", "lido", "cinnamon", "forty pages"] {
      XCTAssertTrue(composition.text.contains(fragment), "\(fragment) never reached the page")
    }
    XCTAssertGreaterThanOrEqual(
      composition.bodyWordCount,
      BraidPromptBuilder.BraidScale.full.targetWordBand.lowerBound,
      composition.text)
  }

  func testABeatAllowanceScalesWithTheNight() {
    XCTAssertLessThan(
      BraidPromptBuilder.BraidScale.glimpse.livedBeatAllowance,
      BraidPromptBuilder.BraidScale.full.livedBeatAllowance)
  }
}

/// The Book should not say the same closing line twice in a week. The ledger
/// rides on the kept pages themselves, so a page the reader removed stops
/// constraining tonight, which is the behaviour any parallel table would have
/// had to remember to implement.
final class BraidRestLedgerTests: XCTestCase {
  func testAPageRecordsTheSentencesItSpent() {
    let composition = DeterministicBraidwright.composition(for: day("2026-09-01"), context: .empty)
    let moves = composition.tags.filter { $0.hasPrefix("braid-move:") }

    XCTAssertFalse(moves.isEmpty, "\(composition.tags)")
    XCTAssertTrue(moves.contains { $0.contains("colophon:") }, "\(moves)")
  }

  func testARecentlySpentColophonRests() {
    let first = DeterministicBraidwright.composition(for: day("2026-09-01"), context: .empty)
    guard
      let spent = first.tags.first(where: { $0.contains("braid-move:colophon:") })?
        .replacingOccurrences(of: "braid-move:", with: "")
    else { return XCTFail("no colophon key") }

    var context = BraidPromptBuilder.Context()
    context.recentMoveAges = [spent: 0]
    let second = DeterministicBraidwright.composition(for: day("2026-09-01"), context: context)

    XCTAssertNotEqual(
      first.sentences.last?.text, second.sentences.last?.text,
      "The Book repeated a closing line it used this week.")
  }

  func testTheLedgerReadsBackOffKeptBraids()  {
    let braid = BookPage(
      id: "braid-1", type: .bookOfYou, createdAt: date("2026-08-28T21:00:00Z"),
      promptText: "x", userInput: "y",
      tags: ["braid", "braid-move:keeping:2", "braid-move:colophon:rule:0"],
      origin: .generated)
    let yesterday = BookDay(
      id: "2026-08-28", date: date("2026-08-28T21:00:00Z"), pages: [braid])

    let ages = BraidPromptBuilder.recentMoveAges(
      before: day("2026-09-01"), in: [yesterday])

    XCTAssertEqual(Set(ages.keys), ["keeping:2", "colophon:rule:0"])
    XCTAssertEqual(ages["keeping:2"], 0, "last night is age zero")
  }

  /// Ten nights of rest, not forever. A ledger that never forgets would empty
  /// the pools and force the Book into its least apt phrasing.
  func testTheLedgerForgetsBeyondTheRestWindow() {
    let braid = BookPage(
      id: "old-braid", type: .bookOfYou, createdAt: date("2026-07-01T21:00:00Z"),
      promptText: "x", userInput: "y", tags: ["braid-move:keeping:2"], origin: .generated)
    let longAgo = BookDay(
      id: "2026-07-01", date: date("2026-07-01T21:00:00Z"), pages: [braid])
    let filler = (1...12).map { offset in
      BookDay(
        id: "2026-08-\(offset)",
        date: date("2026-08-\(offset < 10 ? "0" : "")\(offset)T21:00:00Z"),
        pages: [])
    }

    let ages = BraidPromptBuilder.recentMoveAges(
      before: day("2026-09-01"), in: [longAgo] + filler)

    XCTAssertTrue(ages.isEmpty, "\(ages)")
  }

  private func day(_ id: String) -> BookDay {
    let page = BookPage(
      id: "p-\(id)", type: .diary, createdAt: date("\(id)T08:00:00Z"),
      promptText: "?", userInput: "I repainted the garden gate and left it open.",
      origin: .userAuthored)
    return BookDay(id: id, date: date("\(id)T21:00:00Z"), pages: [page])
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// The acceptance test for cross-night memory: run a month of evenings, feeding
/// each night's kept braid back into the next night's context, and check that
/// the Book does not fall into a loop.
final class BraidThirtyNightsTests: XCTestCase {
  func testAMonthOfEveningsNeverRepeatsAClosingLineInsideItsRestWindow() {
    var archive: [BookDay] = []
    var colophons: [String] = []
    var colophonKeys: [String] = []

    for offset in 0..<30 {
      let day = simulatedDay(offset: offset)
      var context = BraidPromptBuilder.Context()
      context.recentMoveAges = BraidPromptBuilder.recentMoveAges(before: day, in: archive)

      let composition = DeterministicBraidwright.composition(for: day, context: context)
      guard let colophon = composition.sentences.last else { return XCTFail("no colophon") }
      colophons.append(colophon.text)
      colophonKeys.append(
        composition.tags.first { $0.contains("braid-move:colophon:") } ?? "none")

      var kept = composition.page
      kept.createdAt = day.date
      archive.append(BookDay(id: day.id, date: day.date, pages: day.pages + [kept]))
    }

    // The guarantee the ledger can actually make: never the same closing line
    // two nights running, even on a month of near-identical days where the
    // pressure never changes and the pool is only as deep as that pressure.
    for index in 1..<colophonKeys.count {
      XCTAssertNotEqual(
        colophonKeys[index], colophonKeys[index - 1],
        "nights \(index - 1) and \(index) closed the same way")
    }

    // And the month should not read as one sentence with the nouns swapped.
    XCTAssertGreaterThanOrEqual(
      Set(colophons).count, 6,
      "30 nights produced only \(Set(colophons).count) distinct closing lines")
  }

  /// A month of near-identical days is the hardest case: the material barely
  /// changes, so anything that varies has to come from the Book.
  private func simulatedDay(offset: Int) -> BookDay {
    let subjects = ["gate", "kettle", "hallway", "bicycle", "ledger", "window"]
    let subject = subjects[offset % subjects.count]
    let start = ISO8601DateFormatter().date(from: "2026-09-01T21:00:00Z")!
    let date = start.addingTimeInterval(Double(offset) * 86_400)
    let id = BookDay.id(for: date)
    let page = BookPage(
      id: "kept-\(offset)", type: .diary,
      createdAt: date.addingTimeInterval(-8 * 3600),
      promptText: "?",
      userInput: "I mended the \(subject) in the back room and left the door open.",
      origin: .userAuthored)
    return BookDay(id: id, date: date, pages: [page])
  }
}

/// Regression: a real reader's braid opened "The Day Answered The" and closed
/// "the day kept the choice; The never got a vote."
///
/// The illustration catalog plates rooms and talismans as well as people:
/// "The Ember Seal", "The Great Hall", so building Cast name tokens from it
/// wholesale put **the** in the set. Almost every Labyrinth sentence opens with
/// "The", so the Book started calling its visitor "The".
///
/// The core package excludes the bundled roster, so the tests saw nine fallback
/// names where the app saw eighty-three and could not have caught this. Hence
/// the filter is tested directly, on the names the app actually loads.
final class BraidCastNamingTests: XCTestCase {
  func testRoomsAndTalismansNeverContributeTheirArticle() {
    let tokens = DeterministicBraidwright.castNameTokens(from: [
      "The Ember Seal", "The Great Hall", "The Stacks", "The Quillquarium",
      "Gimble of the Errata Registry", "Wicker Eddies", "Professor Thaddeus Mook",
    ])

    XCTAssertFalse(tokens.contains("the"), "\(tokens.sorted())")
    XCTAssertFalse(tokens.contains("of"))
    XCTAssertFalse(tokens.contains("professor"))
    XCTAssertFalse(tokens.contains("hall"))
    XCTAssertFalse(tokens.contains("stacks"))
    // The people still come through.
    XCTAssertTrue(tokens.contains("wicker"))
    XCTAssertTrue(tokens.contains("eddies"))
    XCTAssertTrue(tokens.contains("gimble"))
    XCTAssertTrue(tokens.contains("thaddeus"))
    XCTAssertTrue(tokens.contains("mook"))
  }

  func testNoSubjectIsEverAFunctionWord() {
    let lived = BookPage(
      id: "lived", type: .diary, createdAt: date("2026-09-10T08:00:00Z"),
      promptText: "?", userInput: "I moved the whole desk under the window.",
      origin: .userAuthored)
    // No noun shared with the lived receipt, so the subject has to come from
    // storySubject: the path that produced "The".
    let labyrinth = BookPage(
      id: "labyrinth", type: .narrativeOS, createdAt: date("2026-09-10T19:00:00Z"),
      promptText: "?",
      userInput: "The Ember Seal refused the errand and closed its own case.",
      tags: ["labyrinth-receipt"], origin: .generated)
    let day = BookDay(
      id: "2026-09-10", date: date("2026-09-10T21:00:00Z"), pages: [lived, labyrinth])

    for composition in DeterministicBraidwright.compositions(for: day, context: .empty) {
      XCTAssertFalse(composition.title.hasSuffix(" The"), composition.title)
      XCTAssertFalse(composition.text.contains(" The never "), composition.text)
      XCTAssertFalse(composition.text.contains("Answered The"), composition.text)
      XCTAssertFalse(composition.text.contains(" the The"), composition.text)
      for stray in [" The.", " The,", " The;"] {
        XCTAssertFalse(composition.text.contains(stray), composition.text)
      }
    }
  }

  /// The whole corpus, checked for any subject that is really a function word
  /// wearing a sentence-initial capital.
  func testNoNightNamesAnArticleAsAnAgent() {
    for night in BraidBench.corpus() {
      for composition in DeterministicBraidwright.compositions(
        for: night.day, context: night.context)
      {
        for article in ["The", "And", "Of", "With", "From"] {
          XCTAssertFalse(
            composition.text.contains(" \(article) never ")
              || composition.text.contains("Answered \(article)")
              || composition.title.hasSuffix(" \(article)"),
            "\(night.name): \(composition.title)")
        }
      }
    }
  }

  /// A Cast member still has to be recognised mid-sentence, or the fix has
  /// traded one bug for the "the wicker" bug it replaced.
  func testACastMemberIsStillAPerson() {
    let lived = BookPage(
      id: "lived", type: .diary, createdAt: date("2026-09-11T08:00:00Z"),
      promptText: "?", userInput: "I baked bread for the first time since spring.",
      origin: .userAuthored)
    let labyrinth = BookPage(
      id: "labyrinth", type: .narrativeOS, createdAt: date("2026-09-11T19:00:00Z"),
      promptText: "?", userInput: "Wicker refused the shortcut and crossed the root bridge.",
      tags: ["labyrinth-receipt"], origin: .generated)
    let day = BookDay(
      id: "2026-09-11", date: date("2026-09-11T21:00:00Z"), pages: [lived, labyrinth])

    let composition = DeterministicBraidwright.composition(for: day, context: .empty)
    XCTAssertTrue(composition.text.contains("Wicker"), composition.text)
    XCTAssertFalse(composition.text.lowercased().contains("the wicker"), composition.text)
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

/// The blind spot that let "The Day Answered The" ship: the core package
/// excludes `BookReferenceLibrary.json`, so every test ran against nine
/// fallback names while the app loaded eighty-three. This reads the real file
/// off disk so the roster the reader actually gets is the one under test.
final class BraidRealRosterTests: XCTestCase {
  private static let rosterPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // InsideCoverCoreTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // repo root
    .appendingPathComponent("Shared/BookReferenceLibrary.json")

  private struct Roster: Decodable {
    struct Profile: Decodable { var characterName: String }
    var characterIllustrations: [Profile]
  }

  func testTheShippedRosterNeverContributesAFunctionWord() throws {
    guard let data = try? Data(contentsOf: Self.rosterPath) else {
      throw XCTSkip("Bundled roster not present at \(Self.rosterPath.path)")
    }
    let roster = try JSONDecoder().decode(Roster.self, from: data)
    let names = roster.characterIllustrations.map(\.characterName)
    XCTAssertGreaterThan(names.count, 20, "roster looks truncated")

    let tokens = DeterministicBraidwright.castNameTokens(from: names)
    for forbidden in ["the", "and", "of", "a", "an", "for", "with", "book"] {
      XCTAssertFalse(
        tokens.contains(forbidden),
        "'\(forbidden)' became a Cast name token from the shipped roster")
    }
    // And it still yields real names, so the filter has not eaten the Cast.
    XCTAssertTrue(tokens.count > 30, "\(tokens.count) tokens survived the filter")
  }
}
