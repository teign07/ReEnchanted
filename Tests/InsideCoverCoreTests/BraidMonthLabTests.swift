import XCTest

@testable import InsideCoverCore

/// A month of real braids, made on the Mac with the phone's code and the
/// phone's Gemma, for proofing the printed editions with what a reader's
/// nights actually look like.
///
/// Every step is the app's own: the planner, the wonder braid first, the plain
/// braid (with its colophon) when the wonder braid declines or fails, the point
/// of view repair, the scrub and the trust audit. Only the model turn goes out,
/// to `scripts/braid_lab_server.py`, which runs the same weights with the same
/// sampling and worn-image mask. Earlier nights' braids sit in the archive for
/// later ones, so library lines rest across the month as they do on the phone.
///
///     ~/ReEnchanted-models/venv/bin/python scripts/braid_lab_server.py --port 8765 &
///     BRAID_MONTH_DAYS=/path/october-days.json BRAID_MONTH_OUT=docs/fixtures/real-braids-october-2026.json \
///     swift test --filter testBraidAMonthWhenAsked
///
/// The days file is the edition proof harness's `braid-days` step (the heavy
/// October without its fixture braids).
final class BraidMonthLabTests: XCTestCase {
  /// The heavy October's scenes, by day: the proof harness's `FieldBookFixture.sceneDays`.
  private static let sceneDays: [(String, Int)] = [
    ("academy.school.chair-first", 1), ("academy.school.sentence-coat", 2), ("academy.school.wrong-way", 3),
    ("count-unbound.scene.sunday-jump", 4), ("count-unbound.scene.east-stacks", 8), ("count-unbound.school.map-room", 10),
    ("count-unbound.scene.man-reading-himself", 15), ("count-unbound.strategy", 18),
    ("count-unbound.scene.wrong-castle", 22), ("count-unbound.scene.future-tense", 28),
    ("count-unbound.scene.first-nightbound-morning", 29), ("count-unbound.protocols.threshold", 30)
  ]

  struct Night: Codable {
    var day: String
    var path: String
    var title: String
    var body: String
    var tags: [String]
    var words: Int
    var findings: [String]
    var attempts: Int
  }

  func testBraidAMonthWhenAsked() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let daysPath = env["BRAID_MONTH_DAYS"], let outPath = env["BRAID_MONTH_OUT"] else { return }
    let server = URL(string: env["BRAID_LAB_URL"] ?? "http://127.0.0.1:8765/")!
    let only = Set((env["BRAID_MONTH_ONLY"] ?? "").split(separator: ",").map(String.init))
    var days = try JSONDecoder().decode([BookDay].self, from: Data(contentsOf: URL(fileURLWithPath: daysPath)))
      .sorted { $0.date < $1.date }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let pack = try ContentPackFileLocator.decoder().decode(
      WorldEventPack.self,
      from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")))
    let event = try XCTUnwrap(pack.events.first)

    // The scenes the reader read, as the app records them: the braid lines of
    // the nodes they passed through, on the day they read them.
    var receipts: [AuthoredContentReceipt] = []
    for (index, entry) in Self.sceneDays.enumerated() {
      guard let scene = pack.storyScenes?.first(where: { $0.id == entry.0 }), let nodes = scene.nodes, var node = nodes.first else { continue }
      var at = calendar.date(from: DateComponents(year: 2026, month: 10, day: entry.1, hour: 9 + index % 7))!
      var visited = Set<String>()
      while visited.insert(node.id).inserted, visited.count <= 6 {
        let choice = node.choices.first
        receipts.append(AuthoredContentReceipt(
          contentID: scene.id, occurrenceID: "fixture-\(scene.id)-\(node.id)", channel: .storyScene, state: .completed,
          recordedAt: at, choiceID: choice?.title, storyText: choice?.braidText ?? node.braidText,
          printedTitle: node.title, printedBody: node.body, roomID: scene.roomID, castIDs: scene.castIDs))
        at = at.addingTimeInterval(240)
        guard let nextID = choice?.nextNodeID ?? node.nextNodeID, let next = nodes.first(where: { $0.id == nextID }) else { break }
        node = next
      }
    }

    struct Reply: Decodable { var text: String; var finish: String? }
    func tell(_ system: String, _ user: String, _ temperature: Float, _ topP: Float, _ maxTokens: Int) async throws -> (String, Bool) {
      let masked = BraidWornImages.masked(sparing: user)
      var request = URLRequest(url: server)
      request.httpMethod = "POST"
      request.timeoutInterval = 600
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "system": system, "user": user, "temperature": temperature, "topP": topP, "maxTokens": maxTokens,
        "maskWords": masked.words, "maskPairs": masked.pairs.map { [$0.after, $0.word] }
      ] as [String: Any])
      let (data, _) = try await URLSession.shared.data(for: request)
      let reply = try JSONDecoder().decode(Reply.self, from: data)
      return (reply.text, reply.finish == "length")
    }

    var nights: [Night] = []
    if FileManager.default.fileExists(atPath: outPath), !only.isEmpty {
      nights = (try? JSONDecoder().decode([Night].self, from: Data(contentsOf: URL(fileURLWithPath: outPath)))) ?? []
      // Earlier nights already braided go back in the archive.
      for night in nights {
        guard let index = days.firstIndex(where: { $0.id == night.day }) else { continue }
        days[index].pages.append(BookPage(type: .bookOfYou, createdAt: days[index].date.addingTimeInterval(22 * 3600),
                                          promptText: "The local Book brain braided today.", userInput: night.body,
                                          tags: night.tags, usedInBookOfYou: true, origin: .generated))
      }
    }

    for index in days.indices {
      let day = days[index]
      if !only.isEmpty, !only.contains(day.id) { continue }
      nights.removeAll { $0.day == day.id }
      days[index].pages.removeAll { $0.type == .bookOfYou }
      let dayStart = calendar.startOfDay(for: day.date)
      let dayEnd = dayStart.addingTimeInterval(86_399)

      var context = BraidPromptBuilder.Context.empty
      // As on the phone, which hands the planner the reader's whole archive.
      context.recentDays = Array(days[..<index])
      context.authoredStoryReceipts = MonthlyIssueBraidMatter.ordered(
        receipts.filter { $0.recordedAt >= dayStart && $0.recordedAt <= dayEnd })
      let liveDay = calendar.component(.day, from: day.date) - 1
      if (0..<event.calendar.durationDays).contains(liveDay) {
        let progress = Double(liveDay) / Double(event.calendar.durationDays)
        let phase = try XCTUnwrap(event.phases.last { $0.startsAtProgress <= progress })
        context.activeWorldEvents = [ResolvedWorldEvent(
          id: event.id, packID: pack.id, title: event.title, subtitle: event.subtitle, phase: phase,
          startedAt: dayStart.addingTimeInterval(-Double(liveDay) * 86_400),
          endsAt: dayStart.addingTimeInterval(Double(event.calendar.durationDays - liveDay) * 86_400),
          progress: progress, playerTouchCount: 0, playerTouchCounts: nil, outcome: nil, effects: [], packet: event.packet)]
      }

      var made: Night?
      var lastFailure = ""
      for attempt in 1...3 where made == nil {
        do {
          made = try await braid(day: day, context: context, tell: tell)
          made?.attempts = attempt
        } catch {
          lastFailure = "\(error)"
          print("\(day.id) attempt \(attempt): \(error)")
        }
      }
      guard let night = made else {
        print("\(day.id): no braid (\(lastFailure))")
        continue
      }
      nights.append(night)
      days[index].pages.append(BookPage(type: .bookOfYou, createdAt: dayStart.addingTimeInterval(22 * 3600),
                                        promptText: "The local Book brain braided today.", userInput: night.body,
                                        tags: night.tags, usedInBookOfYou: true, origin: .generated))
      print("\(day.id): \(night.path), \(night.words) words, findings \(night.findings)")
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(nights.sorted { $0.day < $1.day }).write(to: URL(fileURLWithPath: outPath))
    }
  }

  private struct Refused: Error, CustomStringConvertible { var description: String }

  /// `BraidInstructions.nightlyBookOfYou`, read from the app's source as the Mac lab does.
  private static func nightlyInstructions() throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("InsideCoverApp/LocalBrainServices.swift"), encoding: .utf8)
    guard let start = source.range(of: "static let nightlyBookOfYou = \"\"\"\n"),
          let end = source.range(of: "\n    \"\"\"", range: start.upperBound..<source.endIndex) else {
      throw Refused(description: "nightlyBookOfYou not found")
    }
    return source[start.upperBound..<end.lowerBound].split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.hasPrefix("    ") ? String($0.dropFirst(4)) : String($0) }.joined(separator: "\n")
  }

  /// `MLXBookBraider.braid(day:context:)` and `wonderTelling`, line for line,
  /// with the model turn handed to the lab server.
  private func braid(
    day: BookDay, context incoming: BraidPromptBuilder.Context,
    tell: @escaping (String, String, Float, Float, Int) async throws -> (String, Bool)
  ) async throws -> Night? {
    let context = DeterministicBraidwright.preparedContext(for: day, context: incoming)
    var scenePlan = BraidScenePlanBuilder.plan(for: day, context: context)
    scenePlan.earnedWords = BraidScenePlan.deviceHonestBand(scenePlan.earnedWords)
    let judgedContext = scenePlan.judging(context)
    guard !scenePlan.placements.isEmpty || !scenePlan.quietDayBeats.isEmpty
            || scenePlan.authoredStoryReceipts?.isEmpty == false else { return nil }

    // The wonder braid first (BRAID_MONTH_PATH=plain skips it, to compare).
    var wonder: WonderBraid.Output?
    if ProcessInfo.processInfo.environment["BRAID_MONTH_PATH"] != "plain" { do {
      let weatherWord = day.capturedPages.sorted { $0.createdAt > $1.createdAt }
        .compactMap(\.context).flatMap(\.weatherTags).first
      let input = WonderBraid.Input(
        details: scenePlan.readerDayNarration,
        dateKey: WonderBraidHistory.dateKey(for: day),
        tale: scenePlan.worldBeat?.fact,
        business: scenePlan.bookBusiness?.text,
        weather: WonderBraid.weatherLine(weather: weatherWord, place: nil,
                                         moonPhaseName: MoonPhaseCalendar.phase(on: day.date).name),
        bookLines: WonderBraid.bookLines(plan: scenePlan, day: day),
        resting: WonderBraidHistory.resting(in: context.recentDays, before: day.date),
        isHardNight: scenePlan.isHardNight)
      if let output = try await WonderBraid.write(input, tell: { system, user, temperature, topP, maxTokens in
        try await tell(system, user, temperature, topP, maxTokens).0
      }), !output.prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let trust = BraidOutputAudit.issues(in: "\(scenePlan.title())\n\n\(output.prose)", for: day, context: judgedContext)
          .filter(\.isReaderTrustFailure)
        if trust.isEmpty { wonder = output } else { print("  wonder failed trust: \(trust)") }
      }
    } }

    let prose: String
    var scrubbed = false
    if let wonder {
      let scrub = BraidTellingScrub.scrubbed(
        wonder.prose, readerMaterial: ([scenePlan.title()] + scenePlan.readerDayNarration).joined(separator: " "),
        isHardNight: scenePlan.isHardNight)
      scrubbed = !scrub.dropped.isEmpty
      prose = scrub.text
    } else {
      let told = try await tell(try Self.nightlyInstructions(), scenePlan.brief(), 0.70, 0.90, 420)
      let finished = BraidNarrativeOutput.finished(
        told.0, reachedCeiling: told.1, keeperColophon: BraidSceneWriter.keeperColophon(for: scenePlan))
      guard !finished.isEmpty else { throw Refused(description: "empty draft") }
      let pov = BraidPointOfView.returningTheReadersActions(in: finished, readerDay: scenePlan.readerDayNarration)
      let scrub = BraidTellingScrub.scrubbed(
        pov.text, readerMaterial: ([scenePlan.title()] + scenePlan.readerDayNarration).joined(separator: " "),
        isHardNight: scenePlan.isHardNight)
      scrubbed = !scrub.dropped.isEmpty
      prose = scrub.text
    }
    let tellingText = "\(scenePlan.title())\n\n\(prose)"
    let issues = BraidOutputAudit.issues(in: tellingText, for: day, context: judgedContext)
      .filter { wonder == nil || $0 != .missingRitualEnding }
    let trust = issues.filter(\.isReaderTrustFailure)
    guard trust.isEmpty else { throw Refused(description: "reader trust: \(trust.map(\.rawValue))") }

    var tags = ["braid", "local-model", "mlx", "gemma", "braid-plan-guided", "braid-gemma-plain-prose", "braid-gemma-single-telling"]
    if scenePlan.authoredStoryReceipts?.isEmpty == false { tags.append(MonthlyIssueBraidMatter.interludeTag) }
    if let wonder {
      tags.append("braid-wonder")
      tags += wonder.lineIDs.map { WonderBraidHistory.tagPrefix + $0 }
      if wonder.jobsFellBack > 0 { tags.append("braid-wonder-fallback") }
    }
    let claims = scenePlan.provenanceClaimsCarried(in: prose)
    tags += claims.flatMap { claim in claim.sourceIDs.map { "braid-claim:\(claim.realm.rawValue):\($0)" } }
    tags += scenePlan.contributionTags
    tags += scenePlan.residueTags(surviving: claims)
    if !issues.isEmpty { tags.append("braid-audit-best-effort") }
    if scrubbed { tags.append("braid-scrubbed") }
    if let business = scenePlan.bookBusiness, business.id.hasPrefix(BookThreads.idPrefix) {
      tags.append(BookThreads.tagPrefix + business.id.dropFirst(BookThreads.idPrefix.count))
    }
    if let business = scenePlan.bookBusiness, business.id.hasPrefix(BookSulk.idPrefix) {
      tags.append(BookSulk.tagPrefix + business.id.dropFirst(BookSulk.idPrefix.count))
    }
    var seen = Set<String>()
    tags = tags.filter { seen.insert($0).inserted }
    // As on the phone: the month's story passages the reader read are bound
    // into the night after its first paragraph.
    var bound = BookPage(type: .bookOfYou, createdAt: day.date, promptText: "", userInput: tellingText, tags: tags)
    bound = MonthlyIssueBraidMatter.binding(scenePlan.authoredStoryReceipts ?? [], into: bound)
    return Night(day: day.id, path: wonder == nil ? (scenePlan.isHardNight ? "plain-hard" : "plain") : "wonder",
                 title: scenePlan.title(), body: bound.userInput, tags: bound.tags,
                 words: prose.split(whereSeparator: \.isWhitespace).count,
                 findings: issues.map(\.rawValue), attempts: 1)
  }
}
