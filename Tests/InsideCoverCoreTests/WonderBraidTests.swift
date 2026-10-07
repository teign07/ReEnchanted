import XCTest
@testable import InsideCoverCore

final class WonderBraidTests: XCTestCase {
  // MARK: - The library

  func testTheLibraryKeepsItsPromises() throws {
    let lines = WonderBraid.lines
    XCTAssertGreaterThanOrEqual(lines.count, 300)
    XCTAssertEqual(Set(lines.map(\.id)).count, lines.count, "ids are unique")
    for line in lines {
      XCTAssertFalse(line.nouns.isEmpty, line.id)
      XCTAssertTrue(line.text.hasSuffix(".") || line.text.hasSuffix("!"), "\(line.id) ends like a sentence")
      XCTAssertLessThanOrEqual(line.text.split(separator: " ").count, 32, line.id)
      let lowered = line.text.lowercased()
      for banned in ["hinge", "ritual"] { XCTAssertFalse(lowered.contains(banned), "\(line.id) says \(banned)") }
    }
  }

  func testTheSwiftLibraryMirrorsTheLabFile() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("scripts/braid_wonder/lines.json"))
    let lab = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    XCTAssertEqual(lab.compactMap { $0["id"] as? String }, WonderBraid.lines.map(\.id))
    XCTAssertEqual(lab.compactMap { $0["line"] as? String }, WonderBraid.lines.map(\.text))
  }

  // MARK: - Matching

  func testALineWrittenForThisSituationBeatsAGeneralOne() {
    let line = WonderBraid.pick(
      text: "You stopped at the window to watch the neighbour's dog try to carry a stick twice as wide as the gate.",
      dateKey: "2026-10-02", excluding: []
    )
    XCTAssertEqual(line?.text, "The dog had promised the stick it would fit, and the stick had believed him.")
  }

  func testFeltLighterIsNotALighter() {
    XCTAssertNil(WonderBraid.pick(text: "You rang the number on the card and left a message and felt lighter.", dateKey: "2026-10-20", excluding: []))
  }

  func testSettingNounsOnlySpeakWhenNothingActs() throws {
    let line = try XCTUnwrap(WonderBraid.pick(
      text: "You sat on the sofa while the kettle clicked off in the next room.", dateKey: "2026-10-04", excluding: []
    ))
    XCTAssertTrue(line.nouns.contains("kettle"), "the kettle acts; the sofa is only where you sat")
  }

  func testALineThatRestsIsNotChosenAgain() throws {
    let text = "You put the kettle on."
    let first = try XCTUnwrap(WonderBraid.pick(text: text, dateKey: "2026-10-04", excluding: []))
    let second = try XCTUnwrap(WonderBraid.pick(text: text, dateKey: "2026-10-04", excluding: [first.id]))
    XCTAssertNotEqual(first.id, second.id)
  }

  func testBeatsLeadWithLinesAndShortFragmentsRideAlong() {
    let beats = WonderBraid.beats(
      details: [
        "You wrote three pages and kept half a sentence.",
        "You dropped the last egg and it rolled across the tiles.",
        "Eventually.",
        "You made soup for dinner."
      ],
      dateKey: "2026-10-04", resting: []
    )
    XCTAssertEqual(beats.first?.lineIDs.count, 1, "a beat with a line leads")
    XCTAssertTrue(beats.contains { $0.detail.hasSuffix("Eventually.") }, "a fragment rides with the sentence before it")
    XCTAssertLessThanOrEqual(beats.count, 4)
  }

  // MARK: - Monthly updates

  func testAMonthsDeliveredLinesJoinTheLibraryAndOldOnesCanLeave() throws {
    let delivered = [
      WonderBraid.Delivered(id: "oct26-001", nouns: ["pumpkin"], needs: nil, line: "The pumpkin had been practising its face for a week."),
      WonderBraid.Delivered(id: "w000a", nouns: ["kettle"], needs: nil, line: "The kettle finished its sentence, at last, and was embarrassed."),
      WonderBraid.Delivered(id: "bad-1", nouns: ["moon"], needs: nil, line: "The moon was a ritual of the night."),
      WonderBraid.Delivered(id: "bad-2", nouns: [], needs: nil, line: "A line about nothing at all."),
      WonderBraid.Delivered(id: "bad-3", nouns: ["tree"], needs: nil, line: "I felt the tree lean toward me."),
    ]
    let merged = WonderBraid.library(delivered: delivered, retiring: ["w000b"])
    XCTAssertTrue(merged.contains { $0.id == "oct26-001" })
    XCTAssertEqual(merged.first { $0.id == "w000a" }?.text, "The kettle finished its sentence, at last, and was embarrassed.", "same id replaces")
    XCTAssertFalse(merged.contains { $0.id == "w000b" }, "retired lines leave")
    for bad in ["bad-1", "bad-2", "bad-3"] { XCTAssertFalse(merged.contains { $0.id == bad }, "\(bad) breaks a promise and is dropped, not fatal") }
    let picked = WonderBraid.pick(text: "You carved the pumpkin on the step.", dateKey: "2026-10-30", excluding: [], library: merged)
    XCTAssertEqual(picked?.id, "oct26-001")
  }

  func testAPackWithWonderLinesStillDecodesAndAnOldOneToo() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    var object = try XCTUnwrap(JSONSerialization.jsonObject(
      with: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json"))
    ) as? [String: Any])
    let old = try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(old.wonderLines)
    object["wonderLines"] = [["id": "oct26-001", "nouns": ["pumpkin"], "line": "The pumpkin had been practising its face."]]
    object["retiredWonderLineIDs"] = ["w000b"]
    let new = try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertEqual(new.wonderLines?.first?.id, "oct26-001")
    XCTAssertEqual(new.retiredWonderLineIDs, ["w000b"])
  }

  // MARK: - Weather

  func testWeatherComesRoundButNotEveryNight() {
    var modes: [WonderBraid.WeatherMode] = []
    for day in 1...31 { modes.append(WonderBraid.weatherMode(dateKey: String(format: "2026-10-%02d", day))) }
    let weatherNights = modes.filter { $0 != .skip }.count
    XCTAssertTrue((8...16).contains(weatherNights), "regular, not constant: \(weatherNights) of 31")
    XCTAssertTrue(zip(modes, modes.dropFirst()).allSatisfy { $0 == .skip || $1 == .skip }, "never two nights running")
    var dry = 0
    for mode in modes {
      dry = mode == .skip ? dry + 1 : 0
      XCTAssertLessThanOrEqual(dry, 3, "never more than three nights without")
    }
    XCTAssertEqual(modes, (1...31).map { WonderBraid.weatherMode(dateKey: String(format: "2026-10-%02d", $0)) }, "stateless")
    XCTAssertEqual(WonderBraid.weatherMode(dateKey: "2026-08-01"), .skip)
  }

  func testWeatherIsSaidPlainlyFromTheRealTags() {
    XCTAssertEqual(
      WonderBraid.weatherLine(weather: "overcast", place: "Belfast", moonPhaseName: "Last Quarter"),
      "It was overcast over Belfast, and the moon was at its last quarter."
    )
    XCTAssertEqual(WonderBraid.weatherLine(weather: "rain", place: "Current place", moonPhaseName: "New Moon"), "It was rain, and there was no moon.")
    XCTAssertNil(WonderBraid.weatherLine(weather: "not recorded", place: "Belfast", moonPhaseName: "Full Moon"))
    XCTAssertNil(WonderBraid.weatherLine(weather: nil, place: nil, moonPhaseName: nil))
  }

  func testDayNumbers() {
    XCTAssertEqual(WonderBraid.dayNumber("1970-01-01"), 0)
    XCTAssertEqual(WonderBraid.dayNumber("2000-03-01"), 11_017)
    XCTAssertEqual((WonderBraid.dayNumber("2026-10-04") ?? 0) - (WonderBraid.dayNumber("2026-10-03") ?? 0), 1)
  }

  // MARK: - Checks

  private let beat = WonderBraid.Beat(
    detail: "You dropped the last egg and it rolled across the tiles in a perfect half circle and stopped, unbroken, against the bin.",
    lines: ["The egg had been eyeing the bin all week."], lineIDs: ["x"]
  )

  func testACleanParagraphPasses() {
    let text = "You dropped the last egg. It rolled across the tiles in a perfect half circle and stopped, unbroken, against the bin. "
      + "The egg had been eyeing the bin all week, and now it had its way."
    XCTAssertEqual(WonderBraid.check(text, beat: beat, tale: nil), [])
  }

  func testTheChecksAreTheDoctrine() {
    let base = "You dropped the last egg. It rolled across the tiles in a perfect half circle and stopped, unbroken, against the bin. "
    XCTAssertTrue(WonderBraid.check(base + "I watched it go and I wrote nothing down about the bin at all.", beat: beat, tale: nil).contains(.firstPerson))
    XCTAssertTrue(WonderBraid.check(base + "Suddenly the bin was a different bin altogether in the hall.", beat: beat, tale: nil).contains(.stock))
    XCTAssertTrue(WonderBraid.check(base + "You felt something shift in the bin and you did not move for a while.", beat: beat, tale: nil).contains(.inventedReader))
    let invented = WonderBraid.check(base + "You baked a small cake in the bin and ate it standing up in the hall.", beat: beat, tale: nil)
    XCTAssertTrue(invented.contains(.youVerb("baked")), "what the reader did comes from the reader's page only")
    XCTAssertTrue(WonderBraid.check(base + "It rolled across the tiles in a perfect half circle and stopped, unbroken, against the bin. " + base, beat: beat, tale: nil).contains(.repeatedSentence))
    XCTAssertTrue(WonderBraid.check("Nothing at all of the kind.", beat: beat, tale: nil).contains(where: {
      if case .length = $0 { return true } else { return false }
    }))
  }

  func testPerceptionVerbsAreHarmless() {
    let text = "You watched the last egg roll across the tiles in a perfect half circle and stop, unbroken, against the bin. "
      + "The egg had been eyeing the bin all week, and it looked pleased."
    XCTAssertEqual(WonderBraid.check(text, beat: beat, tale: nil), [])
  }

  func testRepairDropsTheClicheAndKeepsTheLine() {
    let line = "The egg had been eyeing the bin all week."
    let text = "You dropped the last egg. Suddenly the whole kitchen seemed to hold its breath. \(line)"
    XCTAssertEqual(WonderBraid.repaired(text, keeping: [line]), "You dropped the last egg. \(line)")
    XCTAssertNil(WonderBraid.repaired("You dropped the last egg. \(line)", keeping: [line]), "nothing to repair")
  }

  // MARK: - The Book's own words from kept Pages

  func testScreenFurnitureIsNotStory() {
    let kept = WonderBraid.bookLines(from: [
      "I drew this out of the clock, and what you bring to each part of it.",
      "16 crossings.",
      "Open the map.",
      "Tap a name to see its lines.",
      "The pins enjoy being handled."
    ])
    XCTAssertEqual(kept, ["I drew this out of the clock, and what you bring to each part of it. 16 crossings. The pins enjoy being handled."])
    XCTAssertEqual(WonderBraid.bookLines(from: ["Open the map.", "Pinch it."]), [])
  }

  // MARK: - The whole telling, with a fake model

  /// Answers every job from its own prompt, the way a well-behaved model would.
  private func fakeTeller(throwing: Bool = false) -> WonderBraid.Teller {
    return { system, user, _, _, _ in
      if throwing { throw NSError(domain: "fake", code: 1) }
      if user.contains("what happened NEXT") {
        return "The bowl rolled off the table and bumped a stack of old maps onto the floor, and the maps spread out across the tiles like a slow grey tide. A pantry door wedged shut behind it with a muffled clank, and Ambrose, who was busy counting chairs in the next room, never heard the noise at all."
      }
      if user.contains("Begin with this sentence exactly:") {
        let opening = user.components(separatedBy: "\"")[1]
        return opening + " A loose thread turned up near the skirting board. It was not the answer."
      }
      if user.contains("The weather tonight:") {
        return "The overcast sky hung low over Belfast and the window gave up one drop."
      }
      let detail = user.components(separatedBy: "\n").first { $0.hasPrefix("Something true") }?
        .replacingOccurrences(of: "Something true from the reader's day: ", with: "") ?? ""
      let seed = user.components(separatedBy: "\n").first { $0.hasPrefix("A seed") }
        .flatMap { $0.components(separatedBy: "\"").dropFirst().first } ?? ""
      return detail + " " + seed
    }
  }

  private var thinDay: WonderBraid.Input {
    WonderBraid.Input(
      details: ["You watched the sky turn the color of a tropical sea over the roofs this afternoon, and stood there for a while."],
      dateKey: "2026-10-03",
      tale: "Ambrose put out a bowl for every chair in the kitchen, and one more for the chair nobody sat in.",
      business: "I'm hunting for the smallest door in the building.",
      weather: "It was overcast over Belfast, and the moon was at its last quarter.",
      bookLines: ["I drew this out of the clock. The pins enjoy being handled."]
    )
  }

  func testAThinDayGetsRoomToPlayAndNeverTheTemplateClosing() async throws {
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(thinDay, tell: fakeTeller()))
    XCTAssertTrue(output.thin)
    XCTAssertEqual(output.paragraphs[1], "I drew this out of the clock. The pins enjoy being handled.", "the Book's kept words follow paragraph one")
    XCTAssertTrue(output.paragraphs.contains { $0.contains("bumped a stack of old maps") }, "the play paragraph carries the Tale on")
    XCTAssertTrue(output.paragraphs.last?.hasPrefix("I'm hunting for the smallest door in the building.") == true, "the Book's business closes")
    XCTAssertFalse(output.prose.contains("The Book kept the page"))
    XCTAssertEqual(output.jobsFellBack, 0)
  }

  func testAFullDayIsNotThin() async throws {
    var input = thinDay
    input.details = [
      "You stopped at the window to watch the neighbour's dog try to carry a stick twice as wide as the gate.",
      "You put the kettle on and it kept ticking for a full minute after it was switched off.",
      "You dropped the last egg and it rolled across the tiles in a perfect half circle and stopped.",
      "You made soup for dinner and the bread was stale so you toasted it."
    ]
    input.bookLines = []
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: fakeTeller()))
    XCTAssertFalse(output.thin)
    XCTAssertFalse(output.paragraphs.contains { $0.contains("bumped a stack of old maps") })
    XCTAssertEqual(output.lineIDs.count, Set(output.lineIDs).count, "no line twice in one night")
  }

  /// A re-braid right after a keep meets a model that is still busy with the keep's
  /// margin reply. Those jobs wait; they do not assemble the night without Gemma.
  func testABusyModelIsWaitedForNotAssembledAround() async throws {
    var input = thinDay
    input.patience = WonderBraid.Patience(pauseSeconds: 0, waits: 5, optionalWaits: 2)
    let calls = Counter()
    let teller = fakeTeller()
    let busyThenFree: WonderBraid.Teller = { system, user, t, p, m in
      if calls.next() <= 3 { throw NSError(domain: "busy", code: 1) }
      return try await teller(system, user, t, p, m)
    }
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: busyThenFree))
    XCTAssertEqual(output.jobsFellBack, 0, "the first paragraph was told by the model once it was free")
  }

  func testAModelThatNeverAnswersEndsTheTellingInsteadOfPublishingAPlainOne() async {
    var input = thinDay
    input.patience = WonderBraid.Patience(pauseSeconds: 0, waits: 3, optionalWaits: 1)
    do {
      _ = try await WonderBraid.write(input, tell: fakeTeller(throwing: true))
      XCTFail("a telling assembled without the model must not be returned")
    } catch let unavailable as WonderBraid.ModelUnavailable {
      XCTAssertEqual((unavailable.underlying as NSError).domain, "fake")
    } catch {
      XCTFail("expected ModelUnavailable, got \(error)")
    }
  }

  func testNothingToBraidIsNotForThisPath() async throws {
    var input = thinDay
    input.details = []
    let output = try await WonderBraid.write(input, tell: fakeTeller())
    XCTAssertNil(output)
  }

  // MARK: - The "what kept pages made this braid" receipts

  /// A real plan for a real-shaped day, told by the fake model.
  private func plannedDay(pageCount: Int) throws -> (plan: BraidScenePlan, pages: [BookPage]) {
    let texts = [
      "Coffee went cold again because I stopped at the window to watch the neighbour's dog try to carry a stick twice as wide as the gate.",
      "The kettle keeps ticking for a full minute after it's switched off, like it's still thinking about what it said.",
      "Dropped the last egg. It rolled across the tiles in a perfect half circle and stopped, unbroken, against the bin.",
      "Soup for dinner. The bread was stale so I toasted it and nobody could tell.",
      "There's a woman at the library who stamps every book like she's signing a treaty.",
      "Early night. The pillow was cold on both sides, which is rare."
    ]
    let formatter = ISO8601DateFormatter()
    let pages = (0..<pageCount).map { index in
      BookPage(
        id: "real-\(index)", type: .diary,
        createdAt: formatter.date(from: String(format: "2026-10-02T%02d:10:00Z", 8 + index * 2))!,
        promptText: "One true thing", userInput: texts[index], origin: .userAuthored
      )
    }
    let day = BookDay(id: "2026-10-02", date: formatter.date(from: "2026-10-02T21:00:00Z")!, pages: pages)
    let prepared = DeterministicBraidwright.preparedContext(for: day, context: .empty)
    return (BraidScenePlanBuilder.plan(for: day, context: prepared), pages)
  }

  func testEveryPageTheBraidUsedStillGetsItsReceipt() async throws {
    for count in [3, 6] {
      let (plan, pages) = try plannedDay(pageCount: count)
      let details = plan.readerDayNarration
      XCTAssertFalse(details.isEmpty)
      let input = WonderBraid.Input(details: details, dateKey: "2026-10-02", business: "I'm hunting for the smallest door in the building.")
      let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: fakeTeller()))
      // The receipts come from the plan, and every placed Page is in the telling's material.
      let credited = Set(BraidContributionReceipt.pageIDs(in: plan.contributionTags))
      let placed = Set(plan.placements.compactMap { plan.evidence(for: $0.evidenceID)?.pageID })
      XCTAssertEqual(credited, placed, "\(count) pages")
      XCTAssertTrue(placed.isSubset(of: Set(pages.map(\.id))))
      let told = WonderBraid.contentWords(output.prose)
      for detail in details {
        let key = WonderBraid.contentWords(detail)
        XCTAssertGreaterThanOrEqual(Double(key.intersection(told).count) / Double(max(1, key.count)), 0.4, "the telling carries: \(detail)")
      }
      // And the claims that mark which lived material left words in the prose are still found.
      let claims = plan.provenanceClaimsCarried(in: output.prose)
      XCTAssertGreaterThanOrEqual(claims.filter { $0.realm == .lived }.count, min(details.count, 2), "\(count) pages")
    }
  }

  func testMoreMomentsThanParagraphsAreMergedNotDropped() {
    let details = (1...7).map { "You did the thing number \($0) with the old blue teapot in the hall." }
    let beats = WonderBraid.beats(details: details, dateKey: "2026-10-02", resting: [])
    XCTAssertEqual(beats.count, 4)
    XCTAssertTrue(beats.last?.detail.contains("number 7") == true)
    for detail in details { XCTAssertTrue(beats.contains { $0.detail.contains(detail) }, detail) }
  }

  // MARK: - History

  func testLinesUsedLatelyRest() {
    let now = ISO8601DateFormatter().date(from: "2026-10-20T20:00:00Z")!
    func braid(daysAgo: Int, tags: [String]) -> BookDay {
      let at = now.addingTimeInterval(-Double(daysAgo) * 86_400)
      let page = BookPage(type: .bookOfYou, promptText: "p", userInput: "text", tags: tags, usedInBookOfYou: true)
      return BookDay(id: "d\(daysAgo)", date: at, pages: [page])
    }
    let resting = WonderBraidHistory.resting(
      in: [braid(daysAgo: 3, tags: ["wonder-line:w001a"]), braid(daysAgo: 30, tags: ["wonder-line:w002a"])],
      before: now
    )
    XCTAssertEqual(resting, ["w001a"])
    XCTAssertEqual(WonderBraidHistory.dateKey(for: BookDay(id: "2026-10-03", date: now, pages: [])), "2026-10-03")
  }
}

private func XCTUnwrapAsync<T>(_ value: @autoclosure () async throws -> T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
  let resolved = try await value()
  return try XCTUnwrap(resolved, file: file, line: line)
}


private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}
