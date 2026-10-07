import XCTest

@testable import InsideCoverCore

/// The bench as a test: it asserts the invariants that must hold on every night
/// in the corpus, and keeps a golden copy of the prose so a change in how the
/// Book writes arrives as a diff someone has to read.
final class BraidBenchTests: XCTestCase {
  private static let goldenPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Golden/braid-bench.txt")

  // MARK: - Golden

  func testGoldenProseIsUnchanged() throws {
    let produced = BraidBench.goldenText(BraidBench.reports())

    if ProcessInfo.processInfo.environment["BRAID_BENCH_RECORD"] == "1" {
      try FileManager.default.createDirectory(
        at: Self.goldenPath.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      try produced.write(to: Self.goldenPath, atomically: true, encoding: .utf8)
      print("Recorded \(Self.goldenPath.path)")
      return
    }

    guard let expected = try? String(contentsOf: Self.goldenPath, encoding: .utf8) else {
      return XCTFail(
        "No golden file. Record one with BRAID_BENCH_RECORD=1 swift test --filter BraidBenchTests")
    }
    guard produced != expected else { return }

    let producedLines = produced.components(separatedBy: "\n")
    let expectedLines = expected.components(separatedBy: "\n")
    let firstDifference = zip(producedLines, expectedLines).enumerated()
      .first { $0.element.0 != $0.element.1 }
    XCTFail(
      """
      The Book writes differently than the golden file.
      First difference at line \(firstDifference?.offset ?? min(producedLines.count, expectedLines.count)):
        golden: \(firstDifference?.element.1 ?? "<end of file>")
        now:    \(firstDifference?.element.0 ?? "<end of file>")
      Read the new prose, then re-record with BRAID_BENCH_RECORD=1.
      """)
  }

  // MARK: - Invariants that must hold on every night

  func testEveryNightProducesAPage() {
    for report in BraidBench.reports() {
      XCTAssertFalse(report.text.isEmpty, report.name)
      XCTAssertFalse(report.title.isEmpty, report.name)
      XCTAssertTrue(
        report.text.contains("The Book kept the page:"),
        "\(report.name) lost its ritual line")
    }
  }

  func testNoNightBreaksTheRegisterAudit() {
    for report in BraidBench.reports() {
      let failures = report.issues.filter { raw in
        BraidOutputAudit.Issue(rawValue: raw)?.isRegisterFailure == true
      }
      XCTAssertTrue(failures.isEmpty, "\(report.name) shipped register failures: \(failures)")
    }
  }

  func testEveryNightIsDeterministic() {
    for night in BraidBench.corpus() {
      let first = DeterministicBraidwright.composition(for: night.day, context: night.context)
      let second = DeterministicBraidwright.composition(for: night.day, context: night.context)
      XCTAssertEqual(first.text, second.text, night.name)
      XCTAssertEqual(first.tags, second.tags, night.name)
    }
  }

  func testNoCandidatePoolContainsClones() {
    for night in BraidBench.corpus() {
      let compositions = DeterministicBraidwright.compositions(
        for: night.day, context: night.context)
      XCTAssertEqual(
        compositions.count, Set(compositions.map(\.text)).count,
        "\(night.name) offered the tasting room duplicate pages")
    }
  }

  /// Every sentence must be filed under an authority, and the reader's own
  /// words must always be filed under the page they came from.
  func testEverySentenceCarriesItsPapers() {
    for night in BraidBench.corpus() {
      let composition = DeterministicBraidwright.composition(
        for: night.day, context: night.context)
      for sentence in composition.sentences {
        switch sentence.provenance {
        case .receipt(let pageID), .quotedReceipt(let pageID):
          XCTAssertFalse(pageID.isEmpty, "\(night.name): receipt with no page")
        case .authored, .colophon:
          break
        }
        XCTAssertFalse(
          sentence.text.trimmingCharacters(in: .whitespaces).isEmpty,
          "\(night.name): empty sentence")
      }
      XCTAssertEqual(
        composition.sentences.last?.provenance, .colophon,
        "\(night.name) does not end on the ritual line")
    }
  }

  /// The compiler's own output must survive its own verifier untouched. If a
  /// house sentence cannot pass the rules we hold the model to, the rules are
  /// wrong.
  func testTheHouseWriterPassesItsOwnVerifier() {
    for night in BraidBench.corpus() {
      let composition = DeterministicBraidwright.composition(
        for: night.day, context: night.context)
      let result = BraidRevisionVerifier.verify(
        revision: composition.text, of: composition, day: night.day, context: night.context)
      let rejections = result.decisions.compactMap(\.rejection)
      XCTAssertTrue(
        rejections.isEmpty,
        "\(night.name) cannot pass its own verifier: \(rejections.map(\.rawValue))")
    }
  }

  func testNoPageOverflowsItsBand() {
    for report in BraidBench.reports() {
      XCTAssertLessThanOrEqual(
        report.wordCount, report.band.upperBound,
        "\(report.name) ran long: \(report.wordCount) words")
    }
  }

  func testConsecutiveNightsRestTheGoldenCorpusMachine() {
    let isolated = BraidBench.reports()
    let consecutive = BraidBench.sequentialReports()
    let tidying = "wanted a tidier version. It is not getting one"

    XCTAssertLessThan(
      occurrences(of: tidying, in: consecutive),
      occurrences(of: tidying, in: isolated),
      "The Index performed the same objection across different nouns.")
    XCTAssertLessThan(
      BraidBench.recurrenceStanding(consecutive).pressure,
      BraidBench.recurrenceStanding(isolated).pressure,
      "Rolling memory did not reduce exact, shaped, opening, ending, and transition recurrence."
    )
  }

  // MARK: - The standing gap

  /// Not a pass/fail: a printed record of how far the house writer still is
  /// from the length it is aiming at, so the number cannot quietly rot.
  func testReportTheStandingShortfall() {
    let reports = BraidBench.reports()
    print("\n" + BraidBench.summaryTable(reports) + "\n")
    let short = reports.filter { $0.shortfall > 0 }
    let worst = short.map(\.shortfall).max() ?? 0
    print(
      "\(short.count) of \(reports.count) nights fall short of their band; worst gap \(worst) words."
    )
    let isolated = BraidBench.recurrenceStanding(reports)
    let consecutive = BraidBench.recurrenceStanding(BraidBench.sequentialReports())
    print(
      "Cross-night recurrence pressure: \(isolated.pressure) isolated baseline; "
        + "\(consecutive.pressure) with archive memory."
    )
  }

  private func occurrences(of phrase: String, in reports: [BraidBench.Report]) -> Int {
    reports.reduce(0) { count, report in
      count + report.text.components(separatedBy: phrase).count - 1
    }
  }
}

// MARK: - The phone's commissions, for the braid lab

extension BraidBenchTests {
  /// Writes the brief each bench night would hand Rabbit's Gemma, exactly as
  /// the device builds it (prepared context, iPhone 15-class band), so prompt
  /// changes can be measured against the real model before they ship:
  ///
  ///     BRAID_BRIEFS_OUT=/tmp/briefs.json swift test --filter testWriteTheDeviceBriefs
  ///
  /// The output feeds `BraidProofHarness` on the phone and the Mac lab that
  /// renders the same chat template. Without the variable it does nothing.
  func testWriteTheDeviceBriefsWhenAsked() throws {
    guard let path = ProcessInfo.processInfo.environment["BRAID_BRIEFS_OUT"] else { return }
    // BRAID_EVENT_DAY=n runs every night with October's Count Unbound live on
    // its n-th day, so the lab shows what a reader of the month would be told.
    var liveEvent: ResolvedWorldEvent?
    if let dayText = ProcessInfo.processInfo.environment["BRAID_EVENT_DAY"], let day = Int(dayText) {
      let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      let pack = try ContentPackFileLocator.decoder().decode(
        WorldEventPack.self,
        from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
      let event = try XCTUnwrap(pack.events.first)
      let progress = Double(day - 1) / Double(event.calendar.durationDays)
      let phase = try XCTUnwrap(event.phases.last { $0.startsAtProgress <= progress })
      let start = Date(timeIntervalSince1970: 1_790_000_000)
      liveEvent = ResolvedWorldEvent(
        id: event.id, packID: pack.id, title: event.title, subtitle: event.subtitle, phase: phase,
        startedAt: start, endsAt: start.addingTimeInterval(31 * 86_400), progress: progress, playerTouchCount: 0,
        playerTouchCounts: nil, outcome: nil, effects: [], packet: event.packet)
    }
    let briefs = BraidBench.corpus().map { night -> [String: String] in
      var night = night
      if let liveEvent { night.context.activeWorldEvents = [liveEvent] }
      // BRAID_THREAD_TAG="teacup:2" runs every night as if last night's braid had
      // carried that step of the Book's running game, so tonight is its next.
      if let tag = ProcessInfo.processInfo.environment["BRAID_THREAD_TAG"] {
        let at = night.day.date.addingTimeInterval(-86_400)
        let page = BookPage(id: "lab-thread", type: .bookOfYou, createdAt: at, promptText: "Book of You",
                            userInput: "A Night\n\nSomething.", tags: [BookThreads.tagPrefix + tag], origin: .generated)
        night.context.recentDays = [BookDay(id: "lab-prev", date: at, pages: [page])]
      }
      // BRAID_TRASHED="The Roster" runs every night as if that scene had just
      // been put in the Trash, so the lab shows how Gemma carries a sulk.
      if let title = ProcessInfo.processInfo.environment["BRAID_TRASHED"] {
        let at = night.day.date.addingTimeInterval(-3_600)
        let id = (0..<60).map { "lab-\($0)" }.first {
          BookSulk.pick(trashed: [.init(id: $0, title: title, at: at)], recentDays: [], on: night.day.date, hardNight: false) != nil
        } ?? "lab-0"
        night.context.trashedScenes = [BookSulk.Trashed(id: id, title: title, at: at)]
      }
      let context = DeterministicBraidwright.preparedContext(for: night.day, context: night.context)
      var plan = BraidScenePlanBuilder.plan(for: night.day, context: context)
      plan.earnedWords = BraidScenePlan.deviceHonestBand(plan.earnedWords)
      let brief = plan.brief()
      // The worn images the phone masks for this brief, so the Mac lab can
      // mask exactly the same tokens.
      let masked = BraidWornImages.masked(sparing: brief)
      return [
        "name": night.name,
        "brief": brief,
        "maskWords": masked.words.joined(separator: "|"),
        "maskPairs": masked.pairs.map { "\($0.after)\u{1}\($0.word)" }.joined(separator: "|"),
        "readerMaterial": ([plan.title()] + plan.readerDayNarration).joined(separator: " "),
        "hardNight": plan.isHardNight ? "true" : "false"
      ]
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(briefs).write(to: URL(fileURLWithPath: path))
    print("Wrote \(briefs.count) device briefs to \(path)")
  }

  /// Applies the real scrub to tellings the Mac lab wrote, so the lab's numbers
  /// describe what a reader would see. Without the variables it does nothing.
  ///
  ///     BRAID_BRIEFS_IN=/tmp/briefs.json BRAID_TELLINGS_IN=/tmp/tellings.json \
  ///     BRAID_SCRUBBED_OUT=/tmp/scrubbed.json swift test --filter testScrubTheLabTellingsWhenAsked
  func testScrubTheLabTellingsWhenAsked() throws {
    let env = ProcessInfo.processInfo.environment
    guard let briefsPath = env["BRAID_BRIEFS_IN"], let tellingsPath = env["BRAID_TELLINGS_IN"],
          let outPath = env["BRAID_SCRUBBED_OUT"] else { return }
    let briefs = try JSONDecoder().decode([[String: String]].self, from: Data(contentsOf: URL(fileURLWithPath: briefsPath)))
    var byName: [String: [String: String]] = [:]
    for brief in briefs { if let name = brief["name"] { byName[name] = brief } }
    var tellings = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: tellingsPath))) as? [[String: Any]])
    var totalDropped = 0
    for index in tellings.indices {
      guard let name = tellings[index]["night"] as? String, let text = tellings[index]["text"] as? String,
            let brief = byName[name] else { continue }
      let scrub = BraidTellingScrub.scrubbed(text, readerMaterial: brief["readerMaterial"] ?? "", isHardNight: brief["hardNight"] == "true")
      tellings[index]["text"] = scrub.text
      tellings[index]["dropped"] = scrub.dropped
      tellings[index]["contractionsAdded"] = scrub.contractions
      totalDropped += scrub.dropped.count
    }
    try JSONSerialization.data(withJSONObject: tellings, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: outPath))
    print("Scrubbed \(tellings.count) tellings, dropped \(totalDropped) sentences")
  }

  /// Writes the device brief for one real day, so the Mac Gemma can braid it.
  /// The file is JSON: {"date":"2026-10-02","pages":[{"time":"08:07","type":"diary","text":"..."}]}
  /// where "type" is a BookPageType raw value (diary, souvenir, plainPage, mood...).
  /// The Count Unbound is live on that date, as it would have been for the reader.
  ///
  ///     BRAID_REAL_DAY=/path/day.json BRAID_BRIEFS_OUT=/tmp/real-briefs.json \
  ///     swift test --filter testWriteTheBriefForARealDayWhenAsked
  func testWriteTheBriefForARealDayWhenAsked() throws {
    let env = ProcessInfo.processInfo.environment
    guard let dayPath = env["BRAID_REAL_DAY"], let outPath = env["BRAID_BRIEFS_OUT"] else { return }
    struct RealPage: Decodable { var time: String; var type: String; var text: String; var origin: String? }
    struct RealScene: Decodable { var id: String; var time: String; var text: String }
    struct RealDay: Decodable { var date: String; var pages: [RealPage]; var scenes: [RealScene]? }
    let raw = try Data(contentsOf: URL(fileURLWithPath: dayPath))
    let realDays: [RealDay]
    if let many = try? JSONDecoder().decode([RealDay].self, from: raw) {
      realDays = many
    } else {
      realDays = [try JSONDecoder().decode(RealDay.self, from: raw)]
    }
    let formatter = ISO8601DateFormatter()
    var nights: [[String: String]] = []
    for real in realDays {
    let pages = try real.pages.enumerated().map { index, page -> BookPage in
      let type = try XCTUnwrap(BookPageType(rawValue: page.type), "unknown page type \(page.type)")
      let at = try XCTUnwrap(formatter.date(from: "\(real.date)T\(page.time):00Z"))
      return BookPage(id: "real-\(index)", type: type, createdAt: at, promptText: "One true thing",
                      userInput: page.text, origin: page.origin == "generated" ? .generated : .userAuthored)
    }
    let dayDate = try XCTUnwrap(formatter.date(from: "\(real.date)T21:00:00Z"))
    let day = BookDay(id: real.date, date: dayDate, pages: pages)

    // The month's Tale on that date, if the date falls inside The Count Unbound.
    var context = BraidPromptBuilder.Context.empty
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let pack = try ContentPackFileLocator.decoder().decode(
      WorldEventPack.self,
      from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
    let event = try XCTUnwrap(pack.events.first)
    var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
    let liveDay = utc.component(.day, from: dayDate) - 1
    if utc.component(.month, from: dayDate) == 10, (0..<event.calendar.durationDays).contains(liveDay) {
      let progress = Double(liveDay) / Double(event.calendar.durationDays)
      let phase = try XCTUnwrap(event.phases.last { $0.startsAtProgress <= progress })
      context.activeWorldEvents = [ResolvedWorldEvent(
        id: event.id, packID: pack.id, title: event.title, subtitle: event.subtitle, phase: phase,
        startedAt: dayDate.addingTimeInterval(-Double(liveDay) * 86_400),
        endsAt: dayDate.addingTimeInterval(Double(event.calendar.durationDays - liveDay) * 86_400),
        progress: progress, playerTouchCount: 0, playerTouchCounts: nil, outcome: nil, effects: [], packet: event.packet)]
    }
    // Monthly scenes the reader finished that day: their authored braid lines,
    // exactly as the app would hand them to the planner.
    for scene in real.scenes ?? [] {
      let at = try XCTUnwrap(formatter.date(from: "\(real.date)T\(scene.time):00Z"))
      context.authoredStoryReceipts.append(AuthoredContentReceipt(
        contentID: scene.id, occurrenceID: "real-day", channel: .storyScene, state: .completed,
        recordedAt: at, storyText: scene.text))
    }
    let prepared = DeterministicBraidwright.preparedContext(for: day, context: context)
    var plan = BraidScenePlanBuilder.plan(for: day, context: prepared)
    plan.earnedWords = BraidScenePlan.deviceHonestBand(plan.earnedWords)
    let brief = plan.brief()
    let masked = BraidWornImages.masked(sparing: brief)
    let passages = MonthlyIssueBraidMatter.ordered(plan.authoredStoryReceipts ?? [])
      .compactMap(\.storyText).joined(separator: "\n\n")
    let night: [String: String] = [
      "name": "day-\(real.date)", "brief": brief, "passages": passages,
      "tale": plan.worldBeat?.fact ?? "",
      "maskWords": masked.words.joined(separator: "|"),
      "maskPairs": masked.pairs.map { "\($0.after)\u{1}\($0.word)" }.joined(separator: "|"),
      "readerMaterial": ([plan.title()] + plan.readerDayNarration).joined(separator: " "),
      "hardNight": plan.isHardNight ? "true" : "false"
    ]
    nights.append(night)
    print("Wrote the brief for \(real.date): \(pages.count) pages, hard night: \(plan.isHardNight), business: \(plan.bookBusiness?.id ?? "none")")
    }
    try JSONEncoder().encode(nights).write(to: URL(fileURLWithPath: outPath))
  }
}
