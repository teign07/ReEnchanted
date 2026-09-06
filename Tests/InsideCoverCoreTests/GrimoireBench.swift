import XCTest
@testable import InsideCoverCore

/// Four years of Book, and a clock.
///
/// "Buttery smooth" is not a feeling, it is a number, so these are ceilings the
/// build holds rather than notes in a document. The ceilings are deliberately
/// slack — several times the measured cost — because this runs on whatever
/// machine happens to be free. A regression that matters will blow through them
/// anyway; the printed figures are the real signal.
final class GrimoireBench: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// Deterministic, so a slow run is a real regression and not bad luck.
    private struct Dice {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(max(1, bound)))
        }
    }

    private func feature(
        _ id: String, _ domain: String,
        role: LoomFeatureRole,
        provenance: LoomProvenance = .observedContext
    ) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: id,
            conditionClause: "it was \(id)", outcomeClause: "you \(id)",
            role: role, provenance: provenance
        )
    }

    /// A believable four-year archive: a few very common features, a long tail
    /// of rare ones, and about a dozen dimensions on any given day.
    private func fourYearArchive() -> [LoomObservation] {
        var dice = Dice(state: 0xF00D_BEEF)
        let dayParts = (0..<4).map { feature("hour-\($0)", "hour", role: .conditionOnly) }
        let weather = (0..<8).map { feature("weather-\($0)", "weather", role: .conditionOnly) }
        let places = (0..<12).map { feature("place-\($0)", "place", role: .conditionOnly) }
        let cast = (0..<30).map { feature("cast-\($0)", "cast", role: .either) }
        let kinds = (0..<20).map { feature("kept-\($0)", "pageKind", role: .outcomeOnly, provenance: .readerAuthored) }
        let words = (0..<120).map { feature("word-\($0)", "word", role: .outcomeOnly, provenance: .readerAuthored) }

        var observations: [LoomObservation] = []
        observations.reserveCapacity(1_460)
        for day in 0..<1_460 {
            var features: [LoomFeatureRef] = [dayParts[dice.next(4)], weather[dice.next(8)]]
            if dice.next(3) > 0 { features.append(places[dice.next(12)]) }
            for _ in 0..<dice.next(4) { features.append(cast[dice.next(30)]) }
            for _ in 0...dice.next(3) { features.append(kinds[dice.next(20)]) }
            for _ in 0...dice.next(5) { features.append(words[dice.next(120)]) }
            // One planted truth, so the bench also proves the engine still works
            // at this size: weather-0 brings cast-7.
            if features.contains(where: { $0.id == "weather-0" }), dice.next(10) < 8 {
                features.append(cast[7])
            }
            observations.append(LoomObservation(
                id: "day-\(day)", day: day,
                occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "page-\(day)",
                evidenceLine: "day \(day)"
            ))
        }
        return observations
    }

    private func seconds(_ work: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        return CFAbsoluteTimeGetCurrent() - start
    }

    func testFourYearsOfBookStaysWithinBudget() throws {
        let archive = fourYearArchive()
        var ledger = GrimoireLedger()

        let ingestAll = seconds { ledger.ingest(archive) }

        var sweeps = 0
        var longestChunk = 0.0
        let sweepAll = seconds {
            while true {
                let chunk = CFAbsoluteTimeGetCurrent()
                let report = ledger.sweep(now: GrimoireDay.date(for: 1_461, calendar: self.calendar),
                                          budget: 400, calendar: self.calendar)
                longestChunk = max(longestChunk, CFAbsoluteTimeGetCurrent() - chunk)
                sweeps += 1
                if report.finished || sweeps > 2_000 { break }
            }
        }

        // The hot path: one more day arriving on a mature Book.
        let oneMoreDay = LoomObservation(
            id: "day-1460", day: 1_460,
            occurredAt: GrimoireDay.date(for: 1_460, calendar: calendar),
            features: archive[1_000].features, evidencePageID: "page-1460", evidenceLine: "one more"
        )
        let ingestOne = seconds { ledger.ingest([oneMoreDay]) }

        // The path the desk actually takes: read standing rows, compute nothing.
        var spoken: [GrimoireCorrespondence] = []
        let read = seconds {
            spoken = ledger.speakable(limit: 3, now: GrimoireDay.date(for: 1_462, calendar: self.calendar),
                                      calendar: self.calendar)
        }

        let size = try JSONEncoder().encode(ledger).count
        // Where the bytes actually are, straight off the encoded form.
        if let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(ledger)
        ) as? [String: Any] {
            let breakdown = object.keys.sorted().map { key -> String in
                let bytes = (try? JSONSerialization.data(
                    withJSONObject: [key: object[key]!]
                ).count) ?? 0
                return "\(key) \(bytes / 1024)KB"
            }
            print("  · " + breakdown.joined(separator: " · "))
        }

        print("""

        ── grimoire · four years ──────────────────────────────
          days                 1460
          features             \(ledger.featureCount)
          pairs remembered     \(ledger.pairCount)
          rows                 \(ledger.rows.count)
          ingest whole archive \(String(format: "%.1f", ingestAll * 1000)) ms
          ingest one day       \(String(format: "%.3f", ingestOne * 1000)) ms
          sweep to completion  \(String(format: "%.1f", sweepAll * 1000)) ms over \(sweeps) chunks
          longest chunk        \(String(format: "%.1f", longestChunk * 1000)) ms
          desk read            \(String(format: "%.3f", read * 1000)) ms
          on disk              \(size / 1024) KB
        ───────────────────────────────────────────────────────

        """)

        // The desk must never wait on this. Everything else may take its time
        // on idle, but a read has to be free.
        XCTAssertLessThan(read, 0.020, "the desk waited on the grimoire")
        XCTAssertLessThan(ingestOne, 0.010, "adding one day to a mature Book got expensive")
        XCTAssertLessThan(longestChunk, 0.150, "a sweep chunk outgrew its idle budget")
        XCTAssertLessThan(size, 12 * 1024 * 1024, "the grimoire got too heavy to save")

        // And it still works at this size.
        XCTAssertFalse(spoken.isEmpty, "four years of Book and nothing to say")
        let planted = GrimoireCorrespondence.key(shape: .conditional, condition: "weather-0", outcome: "cast-7")
        XCTAssertNotNil(ledger.row(planted), "lost the planted pattern in the noise")
    }

    /// The same four years, but through the real projectors.
    ///
    /// The synthetic bench above builds observations by hand and so never sees
    /// what the projector set actually costs — including context blends, which
    /// add features and therefore multiply pairs. This is the number that
    /// matters for a real Book.
    func testTheRealProjectorPipelineStaysWithinBudget() throws {
        var dice = Dice(state: 0xBEEFCAFE)
        let weathers = ["rain", "clear", "fog", "bright", "snow"]
        let places = (0..<10).map { "place-\($0)" }
        let words = ["lantern", "harbour", "kettle", "window", "morning", "thistle", "ferry", "orchard"]
        var days: [BookDay] = []
        for index in 0..<1_460 {
            let date = calendar.date(
                byAdding: .hour, value: 9 + dice.next(9),
                to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            var pages: [BookPage] = []
            for slot in 0...dice.next(2) {
                pages.append(BookPage(
                    id: "page-\(index)-\(slot)",
                    type: slot == 0 ? .diary : .souvenir,
                    createdAt: date,
                    promptText: "Prompt",
                    userInput: "The \(words[dice.next(words.count)]) and the long walk home again.",
                    tags: ["entity:wicker", "choice:the-long-way"],
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(
                        at: date, calendar: calendar,
                        weatherTags: [weathers[dice.next(weathers.count)]],
                        nearbyAnchorID: places[dice.next(places.count)]
                    )
                ))
            }
            days.append(BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date),
                pages: pages
            ))
        }

        let slice = GrimoireSlice(days: days, calendar: calendar)
        var observations: [LoomObservation] = []
        let projecting = seconds { observations = GrimoireProjection.observations(from: slice) }

        var ledger = GrimoireLedger()
        let ingesting = seconds { ledger.ingest(observations) }

        var sweeps = 0
        var longestChunk = 0.0
        let sweeping = seconds {
            while true {
                let chunk = CFAbsoluteTimeGetCurrent()
                let report = ledger.sweep(
                    now: GrimoireDay.date(for: 1_461, calendar: self.calendar),
                    budget: GrimoireKeeper.sweepBudget, calendar: self.calendar
                )
                longestChunk = max(longestChunk, CFAbsoluteTimeGetCurrent() - chunk)
                sweeps += 1
                if report.finished || sweeps > 4_000 { break }
            }
        }
        let read = seconds {
            _ = ledger.speakable(
                limit: 3, now: GrimoireDay.date(for: 1_462, calendar: self.calendar),
                calendar: self.calendar
            )
        }
        let blended = ledger.featureIDs.filter { $0.hasPrefix("blend:") }.count
        let size = try JSONEncoder().encode(ledger).count

        print("""

        ── grimoire · four years · real projectors ─────────────
          observations         \(observations.count)
          features             \(ledger.featureCount) (\(blended) blends)
          pairs remembered     \(ledger.pairCount)
          rows                 \(ledger.rows.count)
          project archive      \(String(format: "%.1f", projecting * 1000)) ms
          ingest archive       \(String(format: "%.1f", ingesting * 1000)) ms
          sweep to completion  \(String(format: "%.1f", sweeping * 1000)) ms over \(sweeps) chunks
          longest chunk        \(String(format: "%.1f", longestChunk * 1000)) ms
          desk read            \(String(format: "%.3f", read * 1000)) ms
          on disk              \(size / 1024) KB
        ───────────────────────────────────────────────────────

        """)

        XCTAssertLessThan(read, 0.030, "the desk waited on the grimoire")
        XCTAssertLessThan(longestChunk, 0.150, "a sweep chunk outgrew its idle budget")
        XCTAssertLessThan(size, 12 * 1024 * 1024, "the grimoire got too heavy to save")
        XCTAssertGreaterThan(blended, 0, "context blends never formed")
    }

    func testTheDeskNeverPaysForDiscovery() {
        // A Book with a full sweep pending must still answer instantly: the
        // whole architecture rests on reads never triggering work.
        var ledger = GrimoireLedger()
        ledger.ingest(fourYearArchive())
        XCTAssertGreaterThan(ledger.pendingSweepCount, 0, "expected a backlog to read against")
        let pendingBeforeRead = ledger.pendingSweepCount
        let read = seconds {
            _ = ledger.speakable(limit: 3, now: GrimoireDay.date(for: 1_461, calendar: self.calendar),
                                 calendar: self.calendar)
        }
        XCTAssertEqual(ledger.pendingSweepCount, pendingBeforeRead, "a read mutated the ledger")
        XCTAssertLessThan(read, 0.020, "a read did discovery work")
    }
}
