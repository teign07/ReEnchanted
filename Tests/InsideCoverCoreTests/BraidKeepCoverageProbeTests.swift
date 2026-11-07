import XCTest

@testable import InsideCoverCore

/// Every Page the scene plan seats reaches the wonder braid's input, on each
/// night of the simulated October. Pages kept without writing used to be
/// planned and then dropped: the wonder path read only the reader's own lines
/// and the Book's kept scenes, so 17 of 83 seated Pages never reached a telling.
///
/// `BRAID_KEEP_PROBE=1 swift test --filter BraidKeepCoverageProbeTests` prints
/// the table and the kept lines.
final class BraidKeepCoverageProbeTests: XCTestCase {
  func testEverySeatedPageReachesTheWonderTelling() throws {
    let printing = ProcessInfo.processInfo.environment["BRAID_KEEP_PROBE"] != nil
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let days = try JSONDecoder().decode(
      [BookDay].self, from: Data(contentsOf: root.appendingPathComponent("docs/fixtures/october-simulation-kept-pages.json"))
    ).sorted { $0.date < $1.date }
    var totals = (kept: 0, seated: 0, reached: 0)
    for (index, day) in days.enumerated() {
      var incoming = BraidPromptBuilder.Context.empty
      incoming.recentDays = Array(days[..<index])
      let context = DeterministicBraidwright.preparedContext(for: day, context: incoming)
      let plan = BraidScenePlanBuilder.plan(for: day, context: context)
      let eligible = BraidPromptBuilder.braidEligiblePages(in: day)
      let placed = plan.placements.compactMap { plan.evidence(for: $0.evidenceID) }
      let seated = Set(placed.map(\.pageID))
      let details = plan.readerDayNarration
      let bookLines = WonderBraid.bookLines(plan: plan, day: day)
      let keptLines = WonderBraid.keptThingLines(plan: plan, day: day)
      // A Page reaches the telling when one of its atoms opens the same way in the input.
      let input = (details + bookLines + keptLines).joined(separator: " ").lowercased()
      func opening(_ text: String) -> String { text.lowercased().split(separator: " ").prefix(4).joined(separator: " ") }
      let reached = seated.filter { pageID in
        placed.filter { $0.pageID == pageID }.contains { atom in
          input.contains(opening(atom.text)) || input.contains(opening(BraidSceneWriter.secondPerson(atom.text)))
        }
      }
      XCTAssertEqual(reached, seated, "\(day.id): a seated Page never reached the telling")

      // The night's old-tale line goes through the same scrub and audit.
      let turn = WonderBraid.turn(plan: plan, details: details, dateKey: day.id, resting: [])
      let draft = (details + keptLines + bookLines + [turn?.text].compactMap { $0 }).joined(separator: "\n\n")
      let scrub = BraidTellingScrub.scrubbed(
        draft, readerMaterial: ([plan.title()] + details).joined(separator: " "),
        isHardNight: plan.isHardNight, verbatim: keptLines)
      for line in keptLines {
        XCTAssertTrue(scrub.text.contains(line), "\(day.id): the scrub altered a kept line: \(line)")
      }
      let trust = BraidOutputAudit.issues(in: "\(plan.title())\n\n\(scrub.text)", for: day, context: plan.judging(context))
        .filter(\.isReaderTrustFailure)
      XCTAssertTrue(trust.isEmpty, "\(day.id): \(trust)")

      totals.kept += eligible.count
      totals.seated += seated.count
      totals.reached += reached.count
      guard printing else { continue }
      let fictionKept = Set(plan.evidence.filter { $0.kind == .keptFiction }.map(\.pageID)).count
      let unseated = eligible.filter { !seated.contains($0.id) }.map(\.type.rawValue)
      print("\(day.id) scale=\(plan.scale) kept=\(eligible.count) seated=\(seated.count) reached=\(reached.count)"
        + " fictionKept=\(fictionKept) unseated=\(unseated)")
      for line in keptLines { print("  KEPT \(line)") }
      if let turn { print("  TURN \(turn.shape) after: \(turn.after.prefix(60)) -> \(turn.text)") }
    }
    if printing { print("TOTAL kept=\(totals.kept) seated=\(totals.seated) reached=\(totals.reached)") }
  }
}
