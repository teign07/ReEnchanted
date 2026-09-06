import XCTest
@testable import InsideCoverCore

/// Forgetting, and the thing that makes it dangerous.
///
/// `knownPairs` is packed out of feature *indices*, so dropping a feature moves
/// every index after it. A remap that is off by one does not crash — it quietly
/// re-points thousands of pairs at the wrong features, and the Book starts
/// making confident claims about relationships that were never observed. These
/// tests exist for that failure and not much else.
final class GrimoirePruneTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func feature(_ id: String, _ domain: String, role: LoomFeatureRole) -> LoomFeatureRef {
        LoomFeatureRef(
            id: id, domain: domain, label: id,
            conditionClause: "it was \(id)", outcomeClause: "you \(id)",
            role: role, provenance: .readerAuthored
        )
    }

    private func observation(day: Int, _ features: [LoomFeatureRef]) -> LoomObservation {
        LoomObservation(
            id: "day-\(day)", day: day,
            occurredAt: GrimoireDay.date(for: day, calendar: calendar),
            features: features, evidencePageID: "page-\(day)", evidenceLine: ""
        )
    }

    /// A real archive shape: a few durable features, and a long tail of words
    /// written once and never again.
    private func ledgerWithALongTail() -> GrimoireLedger {
        let rain = feature("weather:rain", "weather", role: .conditionOnly)
        let night = feature("hour:night", "hour", role: .conditionOnly)
        let lantern = feature("word:lantern", "word", role: .outcomeOnly)
        var ledger = GrimoireLedger()
        var observations: [LoomObservation] = []
        for day in 0..<200 {
            var features: [LoomFeatureRef] = [night]
            if day % 5 == 0 {
                features.append(rain)
                if day != 25 { features.append(lantern) }
            }
            // One throwaway word per day, never repeated.
            features.append(feature("word:once-\(day)", "word", role: .outcomeOnly))
            observations.append(observation(day: day, features))
        }
        ledger.ingest(observations)
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 400, calendar: calendar),
                                      budget: 1_200, calendar: calendar)
            passes += 1
            if report.finished || passes > 120 { break }
        }
        return ledger
    }

    func testTheLongTailIsForgottenAndTheClaimsAreNot() throws {
        var ledger = ledgerWithALongTail()
        let before = ledger.featureCount
        let rowsBefore = ledger.rows.count
        XCTAssertGreaterThan(before, 150, "expected a long tail to prune")

        let dropped = ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)
        XCTAssertGreaterThan(dropped, 100)
        XCTAssertEqual(ledger.featureCount, before - dropped)
        XCTAssertEqual(ledger.rows.count, rowsBefore, "pruning must not lose a single claim")
        // The features the claims rest on are still there and still correct.
        XCTAssertEqual(ledger.days(of: "weather:rain").count, 40)
        XCTAssertNotNil(ledger.ref("word:lantern"))
    }

    func testEveryRemainingPairStillPointsAtTheSameTwoFeatures() throws {
        var ledger = ledgerWithALongTail()
        // Record what each surviving pair meant, by *name*, before the indices move.
        var before = Set<String>()
        for key in ledger.knownPairs {
            let (condition, outcome) = GrimoireLedger.unpack(key)
            guard condition < ledger.featureCount, outcome < ledger.featureCount else { continue }
            before.insert("\(ledger.featureIDs[condition])->\(ledger.featureIDs[outcome])")
        }

        ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)

        var after = Set<String>()
        for key in ledger.knownPairs {
            let (condition, outcome) = GrimoireLedger.unpack(key)
            XCTAssertLessThan(condition, ledger.featureCount, "a pair points past the end of the table")
            XCTAssertLessThan(outcome, ledger.featureCount, "a pair points past the end of the table")
            after.insert("\(ledger.featureIDs[condition])->\(ledger.featureIDs[outcome])")
        }
        // Pairs may be dropped with their features; none may be rewritten.
        XCTAssertTrue(after.isSubset(of: before), "pruning re-pointed a pair at the wrong features")
        XCTAssertFalse(after.isEmpty)
    }

    func testTheSameClaimsSurviveWithTheSameNumbers() throws {
        var ledger = ledgerWithALongTail()
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "word:lantern")
        let before = try XCTUnwrap(ledger.currentStats(for: try XCTUnwrap(ledger.row(id)), calendar: calendar))

        ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)

        let after = try XCTUnwrap(ledger.currentStats(for: try XCTUnwrap(ledger.row(id)), calendar: calendar))
        XCTAssertEqual(after.inCount, before.inCount)
        XCTAssertEqual(after.inHits, before.inHits)
        XCTAssertEqual(after.outCount, before.outCount)
        XCTAssertEqual(after.outHits, before.outHits)
    }

    func testAFeatureAClaimRestsOnIsNeverForgotten() {
        var ledger = ledgerWithALongTail()
        let referenced = Set(ledger.rows.values.flatMap { row in
            [row.conditionID, row.outcomeID, row.rivalID].compactMap { $0 }
        })
        ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)
        for id in referenced {
            XCTAssertNotNil(ledger.ref(id), "\(id) was pruned out from under a claim")
        }
    }

    func testARecentOneOffIsGivenTimeToGrow() {
        var ledger = ledgerWithALongTail()
        let fresh = feature("word:newborn", "word", role: .outcomeOnly)
        ledger.ingest([observation(day: 399, [feature("hour:night", "hour", role: .conditionOnly), fresh])])
        ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)
        XCTAssertNotNil(ledger.ref("word:newborn"), "yesterday's word has not had its chance yet")
    }

    func testPruningIsSafeToRepeatAndStableWhenThereIsNothingToDo() {
        var ledger = ledgerWithALongTail()
        let now = GrimoireDay.date(for: 400, calendar: calendar)
        XCTAssertGreaterThan(ledger.prune(now: now, calendar: calendar), 0)
        let settled = ledger.featureCount
        XCTAssertEqual(ledger.prune(now: now, calendar: calendar), 0)
        XCTAssertEqual(ledger.featureCount, settled)
        XCTAssertNotNil(ledger.lastPrunedAt)
    }

    func testAPrunedLedgerStillSavesAndOpens() throws {
        var ledger = ledgerWithALongTail()
        ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)
        let data = try JSONEncoder().encode(ledger)
        let restored = try JSONDecoder().decode(GrimoireLedger.self, from: data)
        XCTAssertEqual(restored.featureCount, ledger.featureCount)
        XCTAssertEqual(restored.pairCount, ledger.pairCount)
        let id = GrimoireCorrespondence.key(shape: .conditional, condition: "weather:rain", outcome: "word:lantern")
        XCTAssertEqual(
            restored.currentStats(for: try XCTUnwrap(restored.row(id)), calendar: calendar)?.inHits,
            ledger.currentStats(for: try XCTUnwrap(ledger.row(id)), calendar: calendar)?.inHits
        )
    }

    func testPruningShrinksWhatGetsSaved() throws {
        var ledger = ledgerWithALongTail()
        let before = try JSONEncoder().encode(ledger).count
        ledger.prune(now: GrimoireDay.date(for: 400, calendar: calendar), calendar: calendar)
        let after = try JSONEncoder().encode(ledger).count
        XCTAssertLessThan(after, before)
        print("grimoire prune: \(before / 1024) KB -> \(after / 1024) KB")
    }
}
