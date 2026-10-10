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

  func testBeatsKeepTheReadersOrderAndShortFragmentsRideAlong() {
    let beats = WonderBraid.beats(
      details: [
        "You wrote three pages and kept half a sentence.",
        "You dropped the last egg and it rolled across the tiles.",
        "Eventually.",
        "You made soup for dinner."
      ],
      dateKey: "2026-10-04", resting: []
    )
    XCTAssertEqual(beats.first?.detail, "You wrote three pages and kept half a sentence.")
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
    XCTAssertEqual(WonderBraid.weatherLine(weather: "rain", place: "Current place", moonPhaseName: "New Moon"), "It was raining, and there was no moon.")
    XCTAssertNil(WonderBraid.weatherLine(weather: "not recorded", place: "Belfast", moonPhaseName: "Full Moon"))
    XCTAssertNil(WonderBraid.weatherLine(weather: nil, place: nil, moonPhaseName: nil))
  }

  func testDayNumbers() {
    XCTAssertEqual(WonderBraid.dayNumber("1970-01-01"), 0)
    XCTAssertEqual(WonderBraid.dayNumber("2000-03-01"), 11_017)
    XCTAssertEqual((WonderBraid.dayNumber("2026-10-04") ?? 0) - (WonderBraid.dayNumber("2026-10-03") ?? 0), 1)
  }

  func testAWeatherTellingCannotChangeTheRecordedMoon() async throws {
    let world = "It was overcast, and the moon was at its first quarter."
    let date = (1...31).map { String(format: "2026-10-%02d", $0) }.first { WonderBraid.weatherMode(dateKey: $0) == .mention }!
    let input = WonderBraid.Input(details: ["You put the kettle on and waited for the click."], dateKey: date, weather: world)
    let good = fakeTeller()
    let teller: WonderBraid.Teller = { system, user, t, p, m in
      if user.contains("The weather tonight:") { return "I read that the window showed dark clouds and no moon shone through." }
      return try await good(system, user, t, p, m)
    }
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: teller))
    XCTAssertTrue(output.prose.contains(world))
    XCTAssertFalse(output.prose.contains("no moon shone"))
  }

  func testWeatherCannotBringUnrecordedPropsIntoTheDay() async throws {
    let world = "It was clear, and the moon was a waning gibbous."
    for mode in [WonderBraid.WeatherMode.mention, .beat] {
      let date = (1...31).map { String(format: "2026-10-%02d", $0) }.first { WonderBraid.weatherMode(dateKey: $0) == mode }!
      let input = WonderBraid.Input(details: ["You put the kettle on and waited for the click."], dateKey: date, weather: world)
      let good = fakeTeller()
      let teller: WonderBraid.Teller = { system, user, t, p, m in
        if user.contains(world) { return world + " A single stone rolled down the slope." }
        return try await good(system, user, t, p, m)
      }
      let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: teller))
      XCTAssertTrue(output.prose.contains(world))
      XCTAssertFalse(output.prose.contains("stone"))
      XCTAssertFalse(output.prose.contains("slope"))
    }
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

  func testAnObjectsActionNeverBecomesTheReadersAction() {
    let heron = WonderBraid.Beat(
      detail: "You watched the heron by the river. It moved its head once and stood still beside the reeds.",
      lines: ["The river kept the reeds waiting."], lineIDs: ["test-river"]
    )
    let changed = "You watched the heron by the river. You moved its head once and stood still beside the reeds. The river kept the reeds waiting."
    XCTAssertTrue(WonderBraid.check(changed, beat: heron, tale: nil).contains(.youVerb("moved")))
    XCTAssertTrue(WonderBraid.tellingProblems(changed, beat: heron, tale: nil).contains(.readerDetailChanged))
    XCTAssertTrue(WonderBraid.tellingProblems(heron.detail + " The river kept the reeds waiting.", beat: heron, tale: nil).isEmpty)
  }

  func testFictionAndOtherPeopleDontGrantReaderActions() {
    let detail = WonderBraid.Beat(detail: "You watched the heron. Your brother baked bread while the heron stood still by the river.", lines: [], lineIDs: [])
    let text = "You watched the heron. You baked bread while the heron stood still by the river. The river waited for the bread to cool."
    XCTAssertTrue(WonderBraid.check(text, beat: detail, tale: "Ambrose baked bread.").contains(.youVerb("baked")))
    XCTAssertTrue(WonderBraid.check(text.replacingOccurrences(of: "You baked", with: "You quietly baked"), beat: detail, tale: nil).contains(.youVerb("baked")))
  }

  func testNewTellingsProtectObjectsAndLimitTheirAddition() {
    let detail = WonderBraid.Beat(detail: "You stopped at the bakery. The man remembered you liked the end piece of bread.", lines: [], lineIDs: [])
    let replaced = detail.detail.replacingOccurrences(of: "end piece of bread", with: "round loaf") + " The bread kept its place."
    XCTAssertTrue(WonderBraid.tellingProblems(replaced, beat: detail, tale: nil).contains(.readerDetailChanged))
    let anotherAction = detail.detail + " You stopped at a second bakery for another loaf."
    XCTAssertTrue(WonderBraid.tellingProblems(anotherAction, beat: detail, tale: nil).contains(.inventedReader), "even an already allowed verb cannot add a new Reader event")
    let sprawl = detail.detail + " The bread woke up. It fetched a spoon. The spoon summoned a map. The map opened a door."
    XCTAssertTrue(WonderBraid.tellingProblems(sprawl, beat: detail, tale: nil).contains(.magicSprawl))
  }

  func testTheMagicCannotBringNewPropsIntoTheReadersMoment() {
    let kettle = WonderBraid.Beat(detail: "The kettle took forever and you let it.",
                                lines: ["The kettle wanted to finish a sentence."], lineIDs: ["test-kettle"])
    XCTAssertTrue(WonderBraid.tellingProblems(kettle.detail + " The kettle wanted to finish a sentence.", beat: kettle, tale: nil).isEmpty)
    for addition in [" A porcelain doll turned into a butterfly.", " The kettle summoned a copper shard."] {
      XCTAssertTrue(WonderBraid.tellingProblems(kettle.detail + addition, beat: kettle, tale: nil).contains(.unrelatedMagic))
    }
    let bakery = WonderBraid.Beat(detail: "The man at the bakery remembered you liked the end piece.", lines: [], lineIDs: [])
    XCTAssertTrue(WonderBraid.tellingProblems(bakery.detail + " It was a small copper shard.", beat: bakery, tale: nil).contains(.unrelatedMagic))
  }

  func testAComparisonDoesntMakeItsObjectReal() {
    let line = WonderBraid.pick(text: "The light in the hall is the colour of weak tea.", dateKey: "2026-10-01", excluding: [])
    XCTAssertFalse(line?.nouns.contains("tea") == true)
    XCTAssertNil(WonderBraid.pick(text: "The light looked like a porcelain doll.", dateKey: "2026-10-01", excluding: []))
  }

  func testAliasesDontSummonObjectsTheReaderNeverMentioned() {
    XCTAssertNil(WonderBraid.pick(text: "You carried the heavy shopping up four flights.", dateKey: "2026-10-09", excluding: []))
    let line = WonderBraid.pick(text: "Low grey sky sitting right on the roofs like a lid.", dateKey: "2026-10-08", excluding: [])
    XCTAssertFalse(line?.text.contains("chimney") == true)
    let dog = WonderBraid.pick(text: "You walked the dog from next door.", dateKey: "2026-10-14", excluding: [])
    XCTAssertFalse(dog?.text.contains("stick") == true)
    let garlic = WonderBraid.pick(text: "You planted garlic in the window box.", dateKey: "2026-10-18", excluding: [])
    XCTAssertFalse(garlic?.text.contains("pan") == true)
    let frost = WonderBraid.pick(text: "Frost on the car roof in the shape of a map.", dateKey: "2026-10-20", excluding: [])
    XCTAssertFalse(frost?.text.contains("windscreen") == true)
  }

  func testTheSameDetailDoesNotGetToldTwice() {
    let beats = WonderBraid.beats(details: ["Shirley said it was typical of you.", "Shirley said it was typical of you."], dateKey: "2026-10-24", resting: [])
    XCTAssertEqual(beats.count, 1)
    XCTAssertEqual(beats[0].detail, "Shirley said it was typical of you.")
  }

  func testADifficultNightKeepsItsDetailWithoutMagicalActivity() async throws {
    var input = WonderBraid.Input(details: ["You sat with Amanda while she waited for news by the river."], dateKey: "2026-10-15", weather: "It was clear.")
    input.isHardNight = true
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: fakeTeller()))
    XCTAssertEqual(output.prose, input.details[0])
    XCTAssertTrue(output.lineIDs.isEmpty)
    XCTAssertEqual(output.weather, .skip)
  }

  func testAFalseTellingFallsBackToTheTrueDetail() async throws {
    let source = "You watched the heron by the river. It moved its head once and stood still beside the reeds."
    let input = WonderBraid.Input(details: [source], dateKey: "2026-10-02")
    let teller: WonderBraid.Teller = { _, _, _, _, _ in
      "You watched the heron by the river. You moved its head once and stood still beside the reeds. The river kept the reeds waiting."
    }
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: teller))
    // A detail with no seed is told as the reader wrote it; the model's version is never used.
    XCTAssertEqual(output.jobsFellBack, 0)
    XCTAssertTrue(output.prose.hasPrefix(source))
    XCTAssertFalse(output.prose.contains("You moved its head"))
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

  func testAThinDayKeepsItsMomentWithoutAnInventedAdventure() async throws {
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(thinDay, tell: fakeTeller()))
    XCTAssertTrue(output.thin)
    XCTAssertEqual(output.paragraphs[1], "I drew this out of the clock. The pins enjoy being handled.", "the Book's kept words follow paragraph one")
    XCTAssertFalse(output.paragraphs.contains { $0.contains("bumped a stack of old maps") }, "few entries do not need an invented adventure")
    XCTAssertEqual(output.paragraphs.last, thinDay.business, "the authored Book thread closes without a made-up hunt result")
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
    input.tale = nil
    input.business = nil
    input.bookLines = []
    let output = try await WonderBraid.write(input, tell: fakeTeller())
    XCTAssertNil(output)
  }

  func testAQuietReaderDayCanCarryFictionWithoutInventingReaderActions() async throws {
    let input = WonderBraid.Input(details: [], dateKey: "2026-10-02", tale: "Soren dropped his chalk.", business: "I've raised the biscuit bet.")
    let output = try await XCTUnwrapAsync(try await WonderBraid.write(input, tell: fakeTeller()))
    XCTAssertEqual(output.paragraphs, ["Soren dropped his chalk.", "I've raised the biscuit bet."])
    XCTAssertFalse(output.prose.contains("You"))
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

final class WonderBraidCastVoiceTests: XCTestCase {
  func testACastNoteIsCreditedToItsWriterNotSaidByTheBook() throws {
    var note = BookPage(type: .gossip, promptText: "A note", userInput: "I did not leave the pen in your bag. Check the other bag.")
    note.metadata = ["castID": "wicker-eddies"]
    let voice = try XCTUnwrap(WonderBraid.castVoice(of: note))
    XCTAssertFalse(voice.isLetter)
    let line = try XCTUnwrap(WonderBraid.attributedLine(name: voice.name, isLetter: false,
                                                        sentences: WonderBraid.sentences(note.userInput)))
    XCTAssertTrue(line.hasPrefix("\(voice.name) left a note: \u{201C}"))
    XCTAssertTrue(line.contains("I did not leave the pen"))
  }

  func testALetterNamesWhoWroteIt() throws {
    var letter = BookPage(type: .letter, promptText: "A letter from Zara Finch",
                          userInput: "I have been meaning to write. What did it say?")
    letter.metadata = ["speakerName": "Zara Finch", "castID": "zara-finch"]
    let voice = try XCTUnwrap(WonderBraid.castVoice(of: letter))
    XCTAssertEqual(voice.name, "Zara Finch")
    XCTAssertTrue(voice.isLetter)
    XCTAssertEqual(WonderBraid.attributedLine(name: voice.name, isLetter: true, sentences: ["I have been meaning to write."]),
                   "A letter came from Zara Finch. \u{201C}I have been meaning to write.\u{201D}")
  }

  func testTheBooksOwnScenesHaveNoCastVoice() {
    let scene = BookPage(type: .narrativeOS, promptText: "A story", userInput: "The kettle had been working up to it for years.")
    XCTAssertNil(WonderBraid.castVoice(of: scene))
  }
}


final class WonderBraidAssemblyTests: XCTestCase {
  func testPlanLabelsAreSaidInTheBooksVoice() {
    let prepared = WonderBraid.prepared([
      "9 days ago: The light in the hall at eight is the colour of weak tea.",
      "From an earlier page: You kept the bus ticket.",
      "Exercise: find something ordinary and make it answer. You chose a doorknob.",
      "Rain on the bus window\nthe market closing its doors\nyour hands, finally warm"
    ])
    XCTAssertTrue(prepared[0].lowercased().contains("nine days ago") && prepared[0].hasSuffix(": The light in the hall at eight is the colour of weak tea."))
    XCTAssertEqual(prepared[1], "Find something ordinary and make it answer. You chose a doorknob.",
                   "An earlier page too short to stand on its own is left out.")
    XCTAssertEqual(prepared[2], "Rain on the bus window, the market closing its doors, your hands, finally warm.")
    XCTAssertEqual(WonderBraid.prepared(["15 days ago: rain by four-fifteen."]), [], "A fragment is never quoted back.")
    XCTAssertTrue(WonderBraid.prepared(["15 days ago: Shirley said it was typical of you."]).first?
                    .hasSuffix(": Shirley said it was typical of you.") ?? false, "A name keeps its capital.")
    XCTAssertEqual(WonderBraid.prepared(["Shirley said it was typical of you.", "15 days ago: Shirley said it was typical of you."]),
                   ["Shirley said it was typical of you."], "A callback never repeats a line the night already tells.")
    XCTAssertTrue(WonderBraid.opensOnPronoun("It moved its head about an inch."))
    XCTAssertEqual(WonderBraid.prepared(["So: you did the washing."]), ["So: you did the washing."],
                   "A reader's own colon is never taken for a form label.")
    XCTAssertEqual(WonderBraid.prepared(["3 days ago: Walked the dog from next door at Amanda's."]), [])
    XCTAssertFalse(prepared.contains { $0.first?.isNumber == true }, "No plan label reaches the page.")
  }

  func testPlainDetailsReadAsParagraphsNotAList() {
    let paragraphs = WonderBraid.paragraphs(of: ["Low grey sky sitting right on the roofs like a lid", "You like it more than you should.", "It makes the street feel like a room."])
    XCTAssertEqual(paragraphs, ["Low grey sky sitting right on the roofs like a lid. You like it more than you should. It makes the street feel like a room."])
  }

  func testALetterIsQuotedInWholeSentences() throws {
    let line = try XCTUnwrap(WonderBraid.attributedLine(name: "Zara Finch", isLetter: true, sentences: [
      "I have been meaning to write, which is a thing people say when they mean they have been avoiding the pen.",
      "The truth is simpler: you were in the corridor on Tuesday, looking at the stair as if it had said something, and I didn't ask what."
    ]))
    XCTAssertFalse(line.contains("…"))
    XCTAssertTrue(line.hasSuffix("avoiding the pen.\u{201D}"))
  }
}
