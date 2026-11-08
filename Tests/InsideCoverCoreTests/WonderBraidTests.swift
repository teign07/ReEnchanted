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
    XCTAssertEqual(WonderBraid.bookLines(from: MarginsAtlasPageSourceAdapter.handlingLine.components(separatedBy: ". ")), [],
                   "how to handle a map is not story")
  }

  /// Three long sentences of a kept scene used to come to more than sixty
  /// words, and the whole scene was dropped from the night it was kept on.
  func testALongSceneCarriesTheSentencesThatFit() {
    let long = "The corridor outside the map room had decided overnight that it was two corridors, and it was not taking questions about which."
    let longer = "Wicker stood at the fork with a lantern and a list, reading the doors their own names back to them until one of them blushed."
    let last = "Nobody has seen the third door since, though several people have heard it apologising."
    let kept = WonderBraid.bookLines(from: [long, longer, last])
    XCTAssertEqual(kept, ["\(long) \(longer)"])
    XCTAssertTrue(kept[0].split(separator: " ").count <= 60)
  }

  // MARK: - Pages kept in silence

  func testAKeptQuotationIsCreditedAndQuotedWhole() throws {
    let line = try XCTUnwrap(WonderBraid.keptLine(
      ["\u{201C}Hope is the thing with feathers that perches in the soul.\u{201D}", "\u{2014} Emily Dickinson"]))
    XCTAssertTrue(line.contains("Emily Dickinson's"), line)
    XCTAssertTrue(line.hasSuffix("\u{201C}Hope is the thing with feathers that perches in the soul.\u{201D}"), line)
    XCTAssertFalse(line.contains("the Book"), line)

    let proverb = try XCTUnwrap(WonderBraid.keptLine(
      ["\u{201C}Keep a green bough in your heart and the singing bird will come.\u{201D}", "\u{2014} Chinese proverb"]))
    XCTAssertFalse(proverb.contains("proverb's"), "a proverb is not somebody to credit")
    XCTAssertFalse(proverb.contains("\u{2014}"), proverb)
  }

  /// A kept quotation is somebody else's words: the scrub neither contracts
  /// them nor drops them for naming "your heart".
  func testTheScrubLeavesAKeptQuotationAlone() throws {
    let line = try XCTUnwrap(WonderBraid.keptLine(
      ["\u{201C}Keep a green bough in your heart and I will come.\u{201D}"]))
    let prose = "You did not finish the washing.\n\n\(line)"
    let scrub = BraidTellingScrub.scrubbed(prose, readerMaterial: "You did not finish the washing.",
                                           isHardNight: false, verbatim: [line])
    XCTAssertTrue(scrub.text.contains(line), scrub.text)
    XCTAssertTrue(scrub.text.contains("didn't finish"), "the Book's own sentences are still contracted")
  }

  func testAPageKeptInSilenceReachesTheTelling() async throws {
    let line = try XCTUnwrap(WonderBraid.keptLine(["\u{201C}Attention is the rarest and purest form of generosity.\u{201D}", "\u{2014} Simone Weil"]))
    var input = WonderBraid.Input(details: [], dateKey: "2026-10-03")
    input.keptLines = [line]
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    let output = try await WonderBraid.write(input, tell: fakeTeller())
    XCTAssertEqual(output?.prose, line, "a night of one kept quotation is that quotation, not an empty page")
  }

  // MARK: - Forms

  func testEachFormHasAShape() {
    XCTAssertEqual(WonderBraid.Shape(form: "sliceOfLife"), .ordered)
    XCTAssertEqual(WonderBraid.Shape(form: "comedy"), .ordered)
    XCTAssertEqual(WonderBraid.Shape(form: "mosaic"), .mosaic)
    XCTAssertEqual(WonderBraid.Shape(form: "portrait"), .led)
    XCTAssertEqual(WonderBraid.Shape(form: "drama"), .led)
    XCTAssertEqual(WonderBraid.Shape(form: "returnForm"), .returning)
    XCTAssertEqual(WonderBraid.Shape(form: "vigil"), .watching)
    XCTAssertEqual(WonderBraid.Shape(form: "something new"), .ordered)
  }

  /// A shape changes the order, never the material.
  func testAShapeMovesDetailsAndKeepsEveryOne() {
    let details = ["You walked the long way home.", "You chose to give Wicker the key.", "9 days ago: You lost the same key on the stairs."]
    let led = WonderBraid.arranged(details, shape: .led, lead: details[1])
    XCTAssertEqual(led.first, details[1])
    XCTAssertEqual(Set(led), Set(details))
    let returning = WonderBraid.arranged(details, shape: .returning, lead: nil)
    XCTAssertEqual(returning.first, details[2], "then, and now")
    XCTAssertEqual(Set(returning), Set(details))
    XCTAssertEqual(WonderBraid.arranged(details, shape: .ordered, lead: details[1]), details)
  }

  /// The strands braid: a kept scene sits beside the moment of the day it
  /// shares a thing with, instead of always after the first paragraph.
  func testAKeptSceneSitsBesideTheMomentItShares() {
    let paragraphs = ["You bought bread on the way back.", "You fixed the gate latch after lunch.", "You read until late."]
    let scene = "The gate to the east garden has refused every latch the groundskeeper offered it."
    let woven = WonderBraid.interleaved([scene], into: paragraphs)
    XCTAssertEqual(woven, [paragraphs[0], paragraphs[1], scene, paragraphs[2]])
    let unrelated = WonderBraid.interleaved(["The Index climbed out of its alphabet."], into: paragraphs)
    XCTAssertEqual(unrelated[1], "The Index climbed out of its alphabet.", "with nothing shared it sits where kept words always sat")
  }

  func testAMosaicKeepsEachMomentApart() async throws {
    var input = WonderBraid.Input(
      details: ["You found a red button in the coat pocket.", "You heard the radiator knock twice before dawn.", "You wrote the grocery list on an envelope."],
      dateKey: "2026-10-16")
    input.delivered = []
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    var ordered = input
    input.form = "mosaic"
    let mosaicWritten = try await WonderBraid.write(input, tell: fakeTeller())
    let mosaic = try XCTUnwrap(mosaicWritten)
    let plainWritten = try await WonderBraid.write(ordered, tell: fakeTeller())
    let plain = try XCTUnwrap(plainWritten)
    XCTAssertGreaterThanOrEqual(mosaic.paragraphs.count, plain.paragraphs.count)
    for detail in input.details { XCTAssertTrue(mosaic.prose.contains(detail.dropLast()), detail) }
    ordered.form = "vigil"
    let vigilWritten = try await WonderBraid.write(ordered, tell: fakeTeller())
    let vigil = try XCTUnwrap(vigilWritten)
    XCTAssertLessThanOrEqual(vigil.lineIDs.count, 1, "a vigil keeps one small odd thing at most")
  }

  // MARK: - Old-tale turns

  /// `turn` reads only the plan's form, its hard-night state and its fiction
  /// choices; the details are handed over as the writer receives them.
  private func plan(details: [String], form: String = "sliceOfLife", hard: Bool = false) -> BraidScenePlan {
    var plan = BraidScenePlanBuilder.plan(for: BookDay(id: "2026-10-09", date: Date(timeIntervalSince1970: 1_791_500_000), pages: []))
    plan.form = form
    plan.mustRemainUnresolved = hard ? ["held"] : []
    return plan
  }

  /// Three kept Pages, one moment each, as the planner sees them.
  private func threePageNight(_ moments: [String]) -> (plan: BraidScenePlan, details: [String]) {
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 8))!
    let pages = moments.enumerated().map { index, text in
      BookPage(id: "page-\(index)", type: .diary, createdAt: start.addingTimeInterval(Double(index + 1) * 3600),
               promptText: "What happened?", userInput: text, origin: .userAuthored)
    }
    let plan = BraidScenePlanBuilder.plan(for: BookDay(id: "2026-10-09", date: start, pages: pages))
    return (plan, plan.readerDayNarration)
  }

  func testATurnComesFromTheNightsOwnMaterial() {
    let kind = ["You carried the neighbour's shopping up four flights.", "You read until late."]
    XCTAssertEqual(WonderBraid.turn(plan: plan(details: kind), details: kind, dateKey: "2026-10-09", resting: [])?.shape, .owed)
    let lost = ["You lost the good scissors again.", "You read until late."]
    XCTAssertEqual(WonderBraid.turn(plan: plan(details: lost), details: lost, dateKey: "2026-10-09", resting: [])?.shape, .lostThing)
    let back = ["You read until late.", "9 days ago: You lost the same key on the stairs."]
    XCTAssertEqual(WonderBraid.turn(plan: plan(details: back), details: back, dateKey: "2026-10-09", resting: [])?.shape, .cameBack)
    let three = ["You read until late.", "You watered the fern.", "You found a button in the coat."]
    XCTAssertEqual(WonderBraid.turn(plan: plan(details: three), details: three, dateKey: "2026-10-09", resting: [])?.shape, .lostThing,
                   "a found thing outranks plain counting")
    let night = threePageNight(["I read until late with the radio on low and the cat asleep on the good chair.",
                                "I watered the fern on the landing and moved it nearer the window for the light.",
                                "I walked the long way home past the bakery because the main road was loud."])
    let threes = WonderBraid.turn(plan: night.plan, details: night.details, dateKey: "2026-10-09", resting: [])
    XCTAssertEqual(threes?.shape, .threeTimes)
    XCTAssertEqual(threes?.after, night.details.last)
    XCTAssertEqual(threes?.before, true, "the line lands before the third")
    let oneEntry = ["Long walk.", "You took the path by the water.", "It moved its head about an inch."]
    XCTAssertNotEqual(WonderBraid.turn(plan: plan(details: oneEntry), details: oneEntry, dateKey: "2026-10-09", resting: [])?.shape, .threeTimes,
                      "three sentences of one entry are one moment")
    XCTAssertNil(WonderBraid.turn(plan: plan(details: ["You read until late."]), details: ["You read until late."], dateKey: "2026-10-09", resting: []),
                 "most nights are just nights")
  }

  func testNoTurnOnAHardNightOrAVigil() {
    let kind = ["You carried the neighbour's shopping up four flights."]
    XCTAssertNil(WonderBraid.turn(plan: plan(details: kind, hard: true), details: kind, dateKey: "2026-10-09", resting: []))
    XCTAssertNil(WonderBraid.turn(plan: plan(details: kind, form: "vigil"), details: kind, dateKey: "2026-10-09", resting: []))
  }

  func testATurnLineRestsAfterItIsSaid() {
    let kind = ["You carried the neighbour's shopping up four flights."]
    let all = Set((WonderBraid.turnLines[.owed] ?? []).map(\.id))
    XCTAssertNil(WonderBraid.turn(plan: plan(details: kind), details: kind, dateKey: "2026-10-09", resting: all))
    let one = try? XCTUnwrap(WonderBraid.turn(plan: plan(details: kind), details: kind, dateKey: "2026-10-09", resting: []))
    XCTAssertNotNil(one)
    XCTAssertFalse(all.subtracting([one!.lineID]).contains(one!.lineID))
  }

  /// The lines are the Book's own say: never the Book by name (it narrates),
  /// never the reader's feelings, no teeth or door sayings. And no invented
  /// keeper: "the building" owed the reader things in a first draft, a
  /// character nobody had met (bj, 2026-11-06). "In here" was wrong too, on a
  /// night the lost thing was lost at the library.
  func testTurnLinesKeepTheVoice() {
    for (shape, lines) in WonderBraid.turnLines {
      XCTAssertGreaterThanOrEqual(lines.count, 3, shape.rawValue)
      for line in lines {
        let lower = line.text.lowercased()
        XCTAssertFalse(lower.contains("the book"), line.text)
        XCTAssertFalse(lower.contains("teeth"), line.text)
        XCTAssertFalse(lower.range(of: #"\byou (felt|feel|were|wanted|meant)\b"#, options: .regularExpression) != nil, line.text)
        XCTAssertFalse(lower.contains("lesson") || lower.contains("really about"), line.text)
        XCTAssertFalse(lower.contains("building") || lower.contains("in here"), line.text)
      }
    }
    XCTAssertEqual(Set(WonderBraid.turnLines.keys), Set(WonderBraid.TurnShape.allCases))
  }

  func testThreeTimesSavesTheOddThingForTheThird() async throws {
    let night = threePageNight(["I read until late with the radio on low and the cat asleep on the good chair.",
                                "I watered the fern on the landing and moved it nearer the window for the light.",
                                "I walked the long way home past the bakery because the main road was loud."])
    var input = WonderBraid.Input(details: night.details, dateKey: "2026-10-09")
    input.turn = WonderBraid.turn(plan: night.plan, details: night.details, dateKey: "2026-10-09", resting: [])
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    let written = try await WonderBraid.write(input, tell: fakeTeller())
    let output = try XCTUnwrap(written)
    let turnText = try XCTUnwrap(input.turn?.text)
    let at = try XCTUnwrap(output.paragraphs.firstIndex(of: turnText))
    XCTAssertTrue(output.paragraphs[at - 1].contains("fern"), output.prose)
    XCTAssertTrue(output.paragraphs[at + 1].contains("long way home"), output.prose)
    XCTAssertEqual(output.paragraphs.filter { $0.contains("fern") || $0.contains("radio") }.count, 2, "two ordinary moments, each its own")
    XCTAssertTrue(output.lineIDs.contains(input.turn!.lineID), "the line rests for the next weeks")
  }

  func testSettingMomentsApartKeepsAPronounWithItsThing() async throws {
    let details = ["You read until late.", "You watched a heron in the shallows by the bridge.", "It moved its head about an inch.", "You walked the long way home."]
    var input = WonderBraid.Input(details: details, dateKey: "2026-10-04")
    input.turn = WonderBraid.turn(plan: plan(details: details), details: details, dateKey: "2026-10-04", resting: [])
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    let written = try await WonderBraid.write(input, tell: fakeTeller())
    let output = try XCTUnwrap(written)
    XCTAssertTrue(output.paragraphs.contains { $0.contains("heron") && $0.contains("It moved its head") }, output.prose)
  }

  func testATurnSitsRightAfterItsMomentEvenWithAKeptLetter() async throws {
    let details = ["You gave the plant by the window a new pot.", "You read until late."]
    var input = WonderBraid.Input(details: details, dateKey: "2026-10-19")
    input.bookLines = ["A letter came from Ambrose Trencher. \u{201C}The soup has opinions.\u{201D}"]
    input.turn = WonderBraid.turn(plan: plan(details: details), details: details, dateKey: "2026-10-19", resting: [])
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    let written = try await WonderBraid.write(input, tell: fakeTeller())
    let output = try XCTUnwrap(written)
    let turn = try XCTUnwrap(input.turn)
    XCTAssertEqual(turn.shape, .owed)
    let at = try XCTUnwrap(output.paragraphs.firstIndex(of: turn.text))
    XCTAssertTrue(output.paragraphs[at - 1].contains("new pot"), output.prose)
  }

  // MARK: - A thread from night to night

  private func beat(_ kind: BraidPromptBuilder.ContinuityKind, prior: String? = nil, now: String = "the pen") -> BraidPromptBuilder.ContinuityBeat {
    BraidPromptBuilder.ContinuityBeat(kind: kind, threadID: "moth", sourceBraidPageID: prior == nil ? nil : "braid-1",
      sourceTitle: nil, priorAnchor: prior, currentAnchor: now, priorLine: nil, elapsedDays: prior == nil ? nil : 1,
      evidencePageIDs: [], reason: nil)
  }

  func testAThreadOpensContinuesAndEndsInTheHousesOwnWords() throws {
    let opening = try XCTUnwrap(WonderBraid.continuity(for: beat(.fictionOpening)))
    XCTAssertTrue(opening.opening.contains("paper moth"), opening.opening)
    let going = try XCTUnwrap(WonderBraid.continuity(for: beat(.fictionContinuation, prior: "the bakery")))
    XCTAssertEqual(going.opening, "The business of the paper moth and the bakery isn't finished.")
    let ending = try XCTUnwrap(WonderBraid.continuity(for: beat(.fictionResolution, prior: "the bakery")))
    XCTAssertTrue(ending.ending)
    XCTAssertNil(WonderBraid.continuity(for: beat(.fictionOpening, now: "the month")), "a month is not a thing to carry")
    XCTAssertNil(WonderBraid.continuity(for: beat(.evidenceRhyme)), "a rhyme in the reader's life is the callback's job")
    XCTAssertNil(WonderBraid.continuity(for: nil))
  }

  /// Only a telling that holds the thread records it for tomorrow, so the
  /// plain fallback must hold it too.
  func testAThreadTheModelFumblesIsStillCarried() async throws {
    for kind in [BraidPromptBuilder.ContinuityKind.fictionOpening, .fictionContinuation, .fictionResolution] {
      let carried = beat(kind, prior: kind == .fictionOpening ? nil : "the bakery")
      var input = WonderBraid.Input(details: ["You left the pen on the windowsill overnight."], dateKey: "2026-10-12")
      input.continuity = WonderBraid.continuity(for: carried)
      input.tale = "A bell has been ringing under the floor of the reading room."
      input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
      // The fake model's tail names no pen, so every attempt is refused.
      let outputWritten = try await WonderBraid.write(input, tell: fakeTeller())
      let output = try XCTUnwrap(outputWritten)
      XCTAssertTrue(output.carriedContinuity)
      XCTAssertFalse(output.prose.contains("bell"), "the thread stands in for the house's news")
      XCTAssertTrue(BraidOutputAudit.carriesContinuity(carried, in: output.prose), "\(kind): \(output.prose)")
      XCTAssertFalse(output.prose.contains(" is mixed up"), "no \"the flowers is\"")
    }
  }

  /// The reader's own "Frost on the car roof" holds the roof runner's words.
  /// On a night the thread's paragraph never ran, that must not record a
  /// thread for tomorrow to continue.
  func testAThreadIsRecordedOnlyWhenItsParagraphRan() {
    var context = BraidPromptBuilder.Context.empty
    context.continuityBeat = BraidPromptBuilder.ContinuityBeat(kind: .fictionOpening, threadID: "roof", sourceBraidPageID: nil,
      sourceTitle: nil, priorAnchor: nil, currentAnchor: "the frost", priorLine: nil, elapsedDays: nil, evidencePageIDs: [], reason: nil)
    let prose = "The car roof\n\nFrost on the car roof in the shape of a map of somewhere that doesn't exist."
    let told = BookPage(type: .bookOfYou, promptText: "", userInput: prose, tags: ["braid", "braid-wonder"])
    XCTAssertEqual(BookOfYouResidue.extract(from: told, context: context).fictionThreadID, "roof", "the plain braid's words still count")
    var untold = told
    untold.tags.append(BookOfYouResidue.continuityUntoldTag)
    XCTAssertNil(BookOfYouResidue.extract(from: untold, context: context).fictionThreadID)
  }

  func testTheMonthsNewsIsNeverDisplacedByAThread() async throws {
    var input = WonderBraid.Input(details: ["You left the pen on the windowsill overnight."], dateKey: "2026-10-12")
    input.continuity = WonderBraid.continuity(for: beat(.fictionOpening))
    input.tale = "The East Stacks are shut and the Count is somewhere in them."
    input.taleIsHouseCanon = false
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    let outputWritten = try await WonderBraid.write(input, tell: fakeTeller())
    let output = try XCTUnwrap(outputWritten)
    XCTAssertFalse(output.carriedContinuity)
    XCTAssertTrue(output.prose.contains("East Stacks"))
  }

  func testAGoodThreadSentenceIsKept() async throws {
    var input = WonderBraid.Input(details: ["You left the pen on the windowsill overnight."], dateKey: "2026-10-12")
    let carried = beat(.fictionOpening)
    input.continuity = WonderBraid.continuity(for: carried)
    input.patience = .init(pauseSeconds: 0, waits: 0, optionalWaits: 0)
    let opening = try XCTUnwrap(input.continuity?.opening)
    let teller: WonderBraid.Teller = { system, user, a, b, c in
      if user.contains(opening) { return opening + " It chewed a careful hole in the pen and left the important parts." }
      return try await self.fakeTeller()(system, user, a, b, c)
    }
    let outputWritten = try await WonderBraid.write(input, tell: teller)
    let output = try XCTUnwrap(outputWritten)
    XCTAssertTrue(output.prose.contains("careful hole in the pen"), output.prose)
    XCTAssertTrue(BraidOutputAudit.carriesContinuity(carried, in: output.prose))
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
    XCTAssertFalse(output.prose.contains("I kept the page"))
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

  func testATerminalModelRefusalDoesNotRetryItsAllocation() async {
    var input = thinDay
    input.patience = WonderBraid.Patience(pauseSeconds: 0, waits: 30, optionalWaits: 3)
    let calls = Counter()
    let unavailable: WonderBraid.Teller = { _, _, _, _, _ in
      _ = calls.next()
      throw WonderBraid.ModelUnavailable(underlying: NSError(domain: "memory-pressure", code: 1))
    }
    do {
      _ = try await WonderBraid.write(input, tell: unavailable)
      XCTFail("A pressure-stopped braid must remain pending")
    } catch let error as WonderBraid.ModelUnavailable {
      XCTAssertEqual((error.underlying as NSError).domain, "memory-pressure")
    } catch {
      XCTFail("Expected the original terminal refusal, got \(error)")
    }
    XCTAssertEqual(calls.next(), 2, "Exactly one model request, then this counter read")
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

  // MARK: - The share card's quote

  private let sharedNight = """
    Cold Coffee on the Sill

    You made coffee before the meeting and left it on the windowsill. The coffee went cold on purpose, out of tact, because it could see you were busy. It was raining over Leeds, and the moon was a waxing gibbous.

    Nothing comes free. I'd like that written down.

    You kept a line of Emily Dickinson's: \u{201C}Hope is the thing with feathers that perches in the soul.\u{201D}
    """

  func testTheShareCardQuotesTheInventedLineNotTheDaysData() {
    let tags = ["braid", "braid-wonder", "wonder-line:w004b", "wonder-line:turn-price-a"]
    XCTAssertEqual(
      BraidShareQuote.invented(body: sharedNight, tags: tags),
      "The coffee went cold on purpose, out of tact, because it could see you were busy."
    )
  }

  func testTheShareCardFallsBackToTheTurnWhenNoObjectSpoke() {
    let tags = ["braid-wonder", "wonder-line:turn-price-a"]
    XCTAssertEqual(BraidShareQuote.invented(body: sharedNight, tags: tags), "Nothing comes free. I'd like that written down.")
  }

  func testTheShareCardNeverTakesTheReadersOwnDetailForTheSeed() {
    // The reader's sentence shares "coffee", "went" and "cold" with the seed,
    // but it is theirs, handed back; it must not stand in for the Book's line.
    let body = "You made coffee and it went cold on the sill.\n\nIt was cloudy over Leeds."
    XCTAssertNil(BraidShareQuote.invented(body: body, tags: ["braid-wonder", "wonder-line:w004b"]))
  }

  func testAPlainBraidKeepsItsOwnClosingForTheCard() {
    XCTAssertNil(BraidShareQuote.invented(body: sharedNight, tags: ["braid", "wonder-line:w004b"]))
    XCTAssertNil(BraidShareQuote.invented(body: sharedNight, tags: ["braid-wonder"]))
  }

  func testTheSkyLineAndKeptCreditsAreReportsNotTelling() {
    XCTAssertTrue(BraidShareQuote.isReport("It was raining over Leeds, and the moon was full."))
    XCTAssertTrue(BraidShareQuote.isReport("You kept a line of Emily Dickinson's: \u{201C}Hope.\u{201D}"))
    XCTAssertFalse(BraidShareQuote.isReport("The kettle was in the middle of a sentence."))
    XCTAssertTrue(BraidShareQuote.opensOnReader("You made coffee."))
    XCTAssertFalse(BraidShareQuote.opensOnReader("Your kettle had opinions."))
  }
}
