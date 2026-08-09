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
    let suspicion = "We have only just met, and I am already suspicious"
    let tidying = "The Index wanted a tidier version. It is not getting one"

    XCTAssertLessThan(
      occurrences(of: suspicion, in: consecutive),
      occurrences(of: suspicion, in: isolated),
      "The first-pages suspicion became a house refrain.")
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
