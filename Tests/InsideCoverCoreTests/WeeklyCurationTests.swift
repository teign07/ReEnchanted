import XCTest
@testable import InsideCoverCore

/// Every case here is a thing Issue 6 (Sep 23-29, nine kept pages) printed.
final class WeeklyCurationTests: XCTestCase {
  private let at = ISO8601DateFormatter().date(from: "2026-09-25T21:43:00Z")!

  private func page(
    _ type: BookPageType, _ text: String, prompt: String = "One true thing", hoursAfter: Double = 0,
    tags: [String] = [], origin: BookPageOrigin? = nil
  ) -> BookPage {
    BookPage(
      id: "p-\(abs((text + prompt).hashValue) % 100_000)-\(Int(hoursAfter))", type: type,
      createdAt: at.addingTimeInterval(hoursAfter * 3_600), promptText: prompt, userInput: text,
      tags: tags, origin: origin
    )
  }

  // MARK: - Sentences, not cut-offs

  func testAnExcerptEndsWhereASentenceEnds() {
    let text = "The book costs him ninety pence and it is not really a book anymore, more a brick that used to be one. "
      + "\"It's ruined,\" the woman says. \"It's all ruined. It was under the window.\" "
      + "Trencher is not listening. He has it open at a page in the middle and he is holding it up to the window."
    let clamped = WeeklyCuration.sentenceClamp(text, limit: 200)
    XCTAssertTrue(clamped.hasSuffix(".") || clamped.hasSuffix("\""), clamped)
    XCTAssertFalse(clamped.hasSuffix("\u{2026}"), "a sentence boundary was available")
    XCTAssertLessThanOrEqual(clamped.count, 200)
    XCTAssertTrue(text.hasPrefix(clamped))
  }

  func testTheTalesLineBreaksSurvive() {
    let tale = "The coffee kept turning up in your pages. I kept count.\n\nOnce upon a time, there was a coffee.\nOn August 23 you wrote: \"3 coffees\"\n\nThen the coffee came back.\nOn August 27 you wrote: \"2 Bud Lights, Greek chicken salad, coffee, lemon seltzer\"\n\nIn the end, the coffee was still there."
    let clamped = WeeklyCuration.sentenceClamp(tale, limit: 160)
    XCTAssertTrue(clamped.contains("\n"), clamped)
    XCTAssertFalse(clamped.hasSuffix("\u{2026}"))
  }

  func testOneSentenceTooLongIsCutAtAClauseNotMidWord() {
    let long = "The corner of that page is so thumbed that the light pours through it, a thin pale stream slicing across the table and the cup and the hand that was holding both of them up"
    let clamped = WeeklyCuration.sentenceClamp(long, limit: 110)
    XCTAssertTrue(clamped.hasSuffix("\u{2026}"))
    XCTAssertTrue(long.hasPrefix(String(clamped.dropLast())), "cut inside the sentence, never altered")
    XCTAssertFalse(clamped.dropLast().hasSuffix("tha"), clamped)
  }

  // MARK: - System text is not content

  func testTheTagsHeaderNeverReachesTheBinding() {
    let braid = page(
      .bookOfYou,
      "The plastic lemon seltzer bottle\n\nTags: Time 9:43 PM · Location Current place · Weather not recorded · Moon Full Moon · Fuel not logged · Inner weather not logged\n\nThe seltzer bottle sat on the sill and the evening went on around it.",
      origin: .generated
    )
    XCTAssertFalse(braid.bindingBodyText.contains("Tags:"), braid.bindingBodyText)
    XCTAssertTrue(braid.bindingBodyText.contains("seltzer bottle sat on the sill"))
    XCTAssertFalse(WeeklyCuration.cleaned("Tags: Time 9:50 PM\n\nAmazing").contains("Tags:"))
  }

  func testAQuoteKeepsItsQuote() {
    let quote = page(.quotes, "Rumi", prompt: "The wound is the place where the Light enters you.")
    XCTAssertTrue(quote.bindingBodyText.contains("The wound is the place"), quote.bindingBodyText)
    XCTAssertTrue(quote.bindingBodyText.contains("Rumi"))
  }

  func testAOneWordTitleIsATitleNotTheFirstLineOfTheStory() {
    let braid = page(.bookOfYou, "Amanda\n\nTags: Time 8:58 PM · Location Belfast\n\nYou were about to go to work, and Amanda hadn't woken up yet.", origin: .generated)
    XCTAssertEqual(BraidPageDetails.details(for: braid).title, "Amanda")
    XCTAssertEqual(braid.bindingDisplayTitle, "Amanda")
    XCTAssertFalse(braid.bindingBodyText.hasPrefix("Amanda"), braid.bindingBodyText)
    XCTAssertFalse(braid.bindingBodyText.contains("Tags:"))
  }

  func testTheSystemsOwnPromptIsNeverABraidsTitle() {
    let braid = BookPage(
      type: .bookOfYou, createdAt: at, promptText: "The local Book brain braided today.",
      userInput: "No title here. Just a sentence that goes on for a while and is not a title at all, you see.", usedInBookOfYou: true
    )
    XCTAssertEqual(braid.bindingDisplayTitle, "The Night's Braid")
  }

  // MARK: - The refrain

  func testARefrainIsAWordThatCameBackNotAPageTypeName() {
    let pages = [
      page(.souvenir, "The plastic lemon seltzer bottle is regal right now; and bubbly.", hoursAfter: 0),
      page(.diary, "Seltzer again, the lemon one, on the porch with a photograph of the dog.", hoursAfter: 5),
      page(.plainPage, "A photograph of the lemon seltzer on the sill before work.", hoursAfter: 30)
    ]
    let refrain = WeeklyCuration.refrain(from: pages)
    XCTAssertTrue(refrain.contains("seltzer"), "\(refrain)")
    XCTAssertFalse(refrain.contains("photograph"), "a label, not a word that came back: \(refrain)")
    XCTAssertFalse(refrain.contains("reader"))
  }

  func testAWordOnOnePageIsNotARefrain() {
    XCTAssertEqual(WeeklyCuration.refrain(from: [page(.diary, "Marmalade marmalade marmalade on the toast, again and again.")]), [])
  }

  func testANameIsKeptAsANameInTheRefrain() {
    let pages = [
      page(.diary, "Went to work early while Amanda slept in.", hoursAfter: 0),
      page(.diary, "Amanda made the coffee and we talked about nothing.", hoursAfter: 24)
    ]
    XCTAssertEqual(WeeklyCuration.refrain(from: pages), ["Amanda"])
  }

  // MARK: - The Labyrinth

  func testTheLabyrinthThisWeekIsWhatTheBraidsWereTold() {
    func braid(_ day: Int, beat: String, id: String) -> BookPage {
      let world = SceneWorldBeat(id: id, mode: .independent, fact: beat, source: .worldEvent, subject: "The Dictionary Rebellion")
      let tag = BraidContributionReceipt(beat: world).encodedTag
      return BookPage(
        type: .bookOfYou, createdAt: at.addingTimeInterval(Double(day) * 86_400), promptText: "p",
        userInput: "Title\n\nBody.", tags: [tag].compactMap { $0 }, usedInBookOfYou: true
      )
    }
    let notes = WeeklyCuration.labyrinthNotes(from: [
      braid(0, beat: "Every coat in the Great Hall is wet on one side only.", id: "w:1"),
      braid(1, beat: "Ambrose has put out a bowl for every chair, and one more.", id: "w:2"),
      braid(2, beat: "Every coat in the Great Hall is wet on one side only.", id: "w:1")
    ])
    XCTAssertEqual(notes.count, 2, "the same beat is not told twice")
    XCTAssertEqual(notes.first?.title, "The Dictionary Rebellion")
    XCTAssertTrue(notes.first?.text.contains("wet on one side") == true)
  }

  // MARK: - No sentence twice

  func testASentenceTheIssueAlreadySaidIsDropped() {
    let said = ["The plastic lemon seltzer bottle is regal right now; and bubbly."]
    let note = "The plastic lemon seltzer bottle is regal right now and bubbly. Friday's braid left a door half open."
    XCTAssertEqual(WeeklyCuration.removingRepeats(from: note, of: said), "Friday's braid left a door half open.")
    XCTAssertEqual(WeeklyCuration.removingRepeats(from: "Friday's braid left a door half open.", of: said), "Friday's braid left a door half open.")
    let onlyRepeat = "The plastic lemon seltzer bottle is regal right now; and bubbly."
    XCTAssertEqual(WeeklyCuration.removingRepeats(from: onlyRepeat, of: said), onlyRepeat, "a note is never emptied")
    XCTAssertTrue(WeeklyCuration.repeats("Seltzer bottle regal and bubbly right now", of: said))
    XCTAssertFalse(WeeklyCuration.repeats("Amanda is off today", of: said))
  }

  // MARK: - The floor says each thing once

  func testALightWeeksFloorDoesNotStutter() throws {
    let spine = "The plastic lemon seltzer bottle is regal right now and bubbly."
    func night(_ id: String, day: Int, spine: String?, body: String) -> WeekNight {
      WeekNight(id: id, date: at.addingTimeInterval(Double(day) * 86_400), title: "Night \(id)", body: body,
                spine: spine, form: nil, returnedAfterDays: nil, returnedText: nil, crossing: nil, openIDs: [], receiptPageIDs: [])
    }
    let plan = WeeklyBindingPlan(
      issueNumber: 6, dateRange: "Sep 23–29",
      nights: [
        night("fri", day: 2, spine: spine, body: "The bottle sat on the sill and the lemon light came through it in the evening."),
        night("tue", day: 6, spine: spine, body: "You were about to go to work and Amanda had not woken up yet and the house was quiet.")
      ],
      coverNightID: "fri", returns: [], stillOpenIDs: [], shape: "unshaped", earnedWords: 150...260
    )
    let claims = WeeklyBindingWriter.write(plan)
    let texts = claims.filter { $0.realm != .colophon }.map(\.text)
    for (index, text) in texts.enumerated() {
      XCTAssertFalse(WeeklyCuration.repeats(text, of: Array(texts[..<index])), "said twice: \(text)")
    }
    let prose = try XCTUnwrap(WeeklyBindingWriter.issue(for: plan))
    XCTAssertFalse(prose.contains("built around that one"), "filler that said nothing")
    XCTAssertGreaterThanOrEqual(texts.count, 3, "the nights' own sentences fill a thin week")
    XCTAssertEqual(prose.components(separatedBy: "regal right now").count - 1, 1, prose)
  }

  func testAnOlderNightWithNoSpineIsBoundFromItsOwnSentenceNotACutOffClip() throws {
    let body = "Amanda\n\nTags: Time 8:58 PM\n\nThe plastic lemon seltzer bottle was cool in the hand and the evening went on around it quietly. A second sentence follows."
    let night = WeekNight(id: "n", date: at, title: "Amanda", body: WeeklyCuration.cleaned(body), spine: nil, form: nil,
                          returnedAfterDays: nil, returnedText: nil, crossing: nil, openIDs: [], receiptPageIDs: [])
    let plan = WeeklyBindingPlan(issueNumber: 3, dateRange: "x", nights: [night], coverNightID: "n", returns: [], stillOpenIDs: [],
                                 shape: "unshaped", earnedWords: 150...260)
    let prose = try XCTUnwrap(WeeklyBindingWriter.issue(for: plan))
    XCTAssertFalse(prose.contains("Tags:"), prose)
    XCTAssertTrue(prose.contains("evening went on around it quietly."), prose)
    XCTAssertFalse(prose.contains(" ha "), "no mid-word cut")
  }

  // MARK: - A quiet week

  func testAThinWeekIsNamedBeforeItIsPrintedAndAFullOneIsNot() throws {
    let few = try XCTUnwrap(WeeklyThinness.assess(keptPages: 3, keptDays: 2))
    XCTAssertTrue(few.message.contains("3 pages on 2 days"), few.message)
    XCTAssertTrue(few.message.contains("for free"), "the free preview is always offered")
    XCTAssertTrue(few.message.contains("print it yourself"))
    XCTAssertTrue(few.message.contains("Order it anyway"), "it is a warning, not a refusal")
    XCTAssertNotNil(WeeklyThinness.assess(keptPages: 12, keptDays: 2), "plenty of pages on two days is still a thin week")
    XCTAssertNotNil(WeeklyThinness.assess(keptPages: 5, keptDays: nil))
    XCTAssertNil(WeeklyThinness.assess(keptPages: 9, keptDays: 4), "Issue 6's shape: a modest week, not a thin one")
    XCTAssertNil(WeeklyThinness.assess(keptPages: 20, keptDays: nil))
    XCTAssertTrue(try XCTUnwrap(WeeklyThinness.assess(keptPages: 1, keptDays: 1)).message.contains("1 page on 1 day"))
  }
}
