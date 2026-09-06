import XCTest
@testable import InsideCoverCore

/// The private laws, bound into a physical volume.
///
/// Every other surface the grimoire reaches can be corrected later. A printed
/// month cannot, which is the point: the volumes are a dated record of the
/// Book being sure, and sometimes of the Book being wrong.
final class GrimoireEditionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func days() -> [BookDay] {
        (0..<61).map { index -> BookDay in
            let date = calendar.date(
                byAdding: .hour, value: 20, to: GrimoireDay.date(for: index, calendar: calendar)
            )!
            let rainy = index % 3 == 0
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return BookDay(
                id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
                date: calendar.startOfDay(for: date),
                pages: [BookPage(
                    id: "page-\(index)", type: .diary, createdAt: date, promptText: "p",
                    userInput: rainy
                        ? "The lantern outside was swinging in the wet."
                        : "Bread, errands, the usual list.",
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(
                        at: date, calendar: calendar, weatherTags: rainy ? ["rain"] : ["clear"]
                    )
                )]
            )
        }
    }

    private func worked() -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(
            from: GrimoireSlice(days: days(), calendar: calendar)
        ))
        let now = GrimoireDay.date(for: 62, calendar: calendar)
        var passes = 0
        while !ledger.sweep(now: now, budget: 2_000, calendar: calendar).finished, passes < 200 {
            passes += 1
        }
        for row in ledger.rows.values where row.isAlive {
            ledger.markSpoken(row.id, now: now, calendar: calendar)
            ledger.rows[row.id]?.state = .standing
        }
        return ledger
    }

    private func edition(with grimoire: GrimoireLedger) -> MonthlyEdition {
        let all = days()
        return MonthlyEditionBuilder.edition(
            from: all,
            startDate: all.first!.date,
            endDate: all.last!.date,
            generatedAt: GrimoireDay.date(for: 62, calendar: calendar),
            calendar: calendar,
            grimoire: grimoire
        )
    }

    /// A bound law has room for its claim underneath. Its title should catch
    /// the thing moving, not squeeze two registry labels together again.
    func testBoundTitlesSpeakInsteadOfJoiningLabels() throws {
        let ledger = worked()
        let section = try XCTUnwrap(edition(with: ledger).sections.first { $0.id == "grimoire" })
        let boundLaws = section.items.filter { !$0.tags.contains("grimoire-crossed-out") }
        XCTAssertFalse(boundLaws.isEmpty, "no standing law reached the title test")
        for item in boundLaws {
            let row = try XCTUnwrap(
                ledger.rows.values.first { "grimoire-\($0.id.stableHash)" == item.id },
                "bound item lost the law it came from: \(item.id)"
            )
            // The defect this guards: a title built by joining the condition
            // label to the outcome label. One side may appear; both may not.
            if let condition = ledger.ref(row.conditionID),
               let outcome = row.outcomeID.flatMap({ ledger.ref($0) }) {
                XCTAssertFalse(
                    item.title.contains(condition.label) && item.title.contains(outcome.label),
                    "the edition went back to joining labels: \(item.title)"
                )
            }
            let spokenEnding: String
            switch row.shape {
            case .conditional: spokenEnding = "kept turning up"
            case .sequential: spokenEnding = "came after"
            case .seasonal: spokenEnding = "kept the appointment"
            case .sibling: spokenEnding = "won this one"
            case .returnInterval: spokenEnding = "came back again"
            }
            XCTAssertTrue(
                item.title.hasSuffix(spokenEnding),
                "the title stopped sounding like the Book: \(item.title)"
            )
        }
    }

    func testAVolumeWithoutAGrimoireIsUnchanged() {
        XCTAssertNil(edition(with: GrimoireLedger()).sections.first { $0.id == "grimoire" })
    }

    func testTheLawsAreBoundIntoTheVolume() throws {
        let section = try XCTUnwrap(
            edition(with: worked()).sections.first { $0.id == "grimoire" },
            "the Book knew things and bound none of them"
        )
        XCTAssertFalse(section.items.isEmpty)
        XCTAssertEqual(section.resolvedPlacement, .movement)
        // Each entry is a claim plus its arithmetic, not a bare label.
        for item in section.items {
            XCTAssertFalse(item.title.isEmpty, "an untitled law")
            XCTAssertTrue(item.body.contains("times out of ") || item.body.contains("I was wrong"), item.body)
            XCTAssertTrue(item.tags.contains("grimoire"))
        }
    }

    /// A rule the Book only half-believes has no business in print.
    func testOnlyCommittedRulesArePrinted() {
        var ledger = worked()
        for row in ledger.rows.values { ledger.rows[row.id]?.state = .watching }
        XCTAssertNil(edition(with: ledger).sections.first { $0.id == "grimoire" })
    }

    /// Being wrong in public is the feature, not an embarrassment to hide.
    func testCrossingsOutAreBoundToo() throws {
        var ledger = worked()
        let ids = ledger.rows.keys.sorted()
        for id in ids.prefix(1) { ledger.rows[id]?.state = .crossedOut }
        let section = try XCTUnwrap(edition(with: ledger).sections.first { $0.id == "grimoire" })
        let crossedOut = section.items.filter { $0.tags.contains("grimoire-crossed-out") }
        XCTAssertEqual(crossedOut.count, 1)
        XCTAssertTrue(crossedOut[0].body.contains("I was wrong"), crossedOut[0].body)
        // And it is printed last: a volume does not open with its retractions.
        XCTAssertEqual(section.items.last?.id, crossedOut[0].id)
    }

    /// A reader who wrote every day for years must not get a volume that is
    /// mostly appendix of rules.
    func testThePrintedLawsAreCapped() {
        var ledger = worked()
        let template = ledger.rows.values.first!
        for index in 0..<60 {
            var row = template
            row.id = "filler-\(index)"
            row.state = index.isMultiple(of: 2) ? .standing : .crossedOut
            ledger.rows[row.id] = row
        }
        guard let section = edition(with: ledger).sections.first(where: { $0.id == "grimoire" }) else {
            return XCTFail("no laws bound")
        }
        XCTAssertLessThanOrEqual(section.items.count, 16)
    }
}
