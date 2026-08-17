import Foundation
import XCTest

@testable import InsideCoverCore

/// The week, held to the same laws as the night.
///
/// The nightly braid is checked sentence by sentence against the reader's own
/// receipts. Nothing above it was checked at all - the weekly, monthly and
/// annual binding stories were free-form model prose over clipped summaries -
/// and those are the artifacts that get printed and sold. Every test here is an
/// attempt to get an invention about somebody's week into a book they paid for.
final class WeeklyBindingPlanTests: XCTestCase {
    private func date(_ v: String) -> Date { ISO8601DateFormatter().date(from: v)! }

    private func night(
        _ id: String,
        _ day: String,
        spine: String,
        form: String = "sliceOfLife",
        returnedAfter: Int? = nil,
        open: [String] = [],
        receipts: [String] = []
    ) -> BookPage {
        var tags = [
            "braid",
            "\(WeeklyBindingPlanner.spinePrefix)\(spine)",
            "\(WeeklyBindingPlanner.formPrefix)\(form)"
        ]
        if let returnedAfter {
            tags.append("\(WeeklyBindingPlanner.returnPrefix)\(returnedAfter)|\(spine)")
        }
        tags += open.map { "\(WeeklyBindingPlanner.openPrefix)\($0)" }
        tags += receipts.map { "\(WeeklyBindingPlanner.evidencePrefix)\($0)" }
        return BookPage(
            id: id, type: .bookOfYou, createdAt: date("\(day)T21:00:00Z"),
            promptText: "Book of You",
            userInput: "A Night\n\n\(spine)\n\nThe Book kept the page: it held.",
            tags: tags,
            origin: .generated)
    }

    private func issue(_ pages: [BookPage]) -> WeeklyIssue {
        WeeklyIssue(
            number: 12,
            startDate: date("2026-10-05T00:00:00Z"),
            endDate: date("2026-10-11T23:59:59Z"),
            dateRange: "Oct 5–11",
            keptCount: pages.count,
            highlights: [],
            setAsideLine: nil,
            pages: pages)
    }

    private func week() -> WeeklyBindingPlan {
        WeeklyBindingPlanner.plan(
            for: issue([
                night("mon", "2026-10-05", spine: "I bought plums at the market before work.",
                      receipts: ["market"]),
                night("wed", "2026-10-07", spine: "The kitchen smelled of plums all evening.",
                      receipts: ["kitchen"]),
                night("fri", "2026-10-09", spine: "I walked the long way home past the bakery.",
                      returnedAfter: 6, receipts: ["walk", "bakery"])
            ]),
            calendar: Calendar(identifier: .gregorian))
    }

    // MARK: - What the week decides

    /// The week inherits decisions rather than re-reading prose.
    func testTheWeekReadsTheLeafEachNightLeft() {
        let plan = week()
        XCTAssertEqual(plan.nights.count, 3)
        XCTAssertTrue(plan.nights.allSatisfy(\.carriesLeaf), plan.summary)
        XCTAssertEqual(plan.night("fri")?.returnedAfterDays, 6)
        XCTAssertEqual(plan.night("mon")?.receiptPageIDs, ["market"])
    }

    /// A week is not a list of days. Its cover is a judgement, and the strongest
    /// evidence a week had a shape is a thing that came back.
    func testTheIssueLeadsWithTheNightThatCarriedAReturn() {
        XCTAssertEqual(week().coverNightID, "fri")
    }

    /// Detected, never inferred - the same rule the night works under. "The
    /// plums are in both" is checkable; "these both feel like endings" is a
    /// horoscope.
    func testAThreadThePickedUpTwiceIsFound() throws {
        let plan = week()
        let found = try XCTUnwrap(plan.returns.first, plan.summary)
        XCTAssertEqual(found.pivot, "plums")
        XCTAssertEqual(Set(found.nightIDs), Set(["mon", "wed"]))
        XCTAssertEqual(found.daysApart, 2)
    }

    /// Length comes from what the week holds, never from a target the writer has
    /// to pad out to.
    func testAThinWeekIsAllowedToBeShort() {
        let thin = WeeklyBindingPlanner.plan(for: issue([]), calendar: .init(identifier: .gregorian))
        XCTAssertEqual(thin.earnedWords, 120...200)
        XCTAssertLessThan(thin.earnedWords.upperBound, week().earnedWords.upperBound)
    }

    // MARK: - The gate

    private func salvage(_ draft: String) -> Result<WeeklyBindingVerifier.Salvage, WeeklyBindingRejection> {
        WeeklyBindingVerifier.salvage(draft, against: week())
    }

    func testAnHonestIssueIsAccepted() throws {
        let draft = """
        NIGHT:fri You walked the long way home past the bakery.
        NIGHT:mon You bought plums at the market before work.
        WEEK:mon,wed The plums are in both halves of this issue.
        COLOPHON The Book bound the week: the same things kept arriving.
        """
        guard case .success(let salvage) = salvage(draft) else {
            return XCTFail("an honest issue was refused")
        }
        XCTAssertTrue(salvage.dropped.isEmpty, "\(salvage.dropped)")
        XCTAssertEqual(salvage.verified.claims.count, 4)
    }

    /// The failure that matters most: a printed sentence about a week that
    /// never happened.
    func testAnInventedNightIsRefused() throws {
        let draft = """
        NIGHT:fri You walked the long way home past the bakery.
        NIGHT:fri You walked past the bakery and then called your father.
        COLOPHON The Book bound the week: it held.
        """
        guard case .success(let salvage) = salvage(draft) else {
            return XCTFail("the issue should survive with the invention removed")
        }
        XCTAssertEqual(salvage.dropped, [.inventedContent])
        XCTAssertFalse(salvage.verified.text.contains("father"))
    }

    func testAReversedNegationIsRefused() {
        let plan = WeeklyBindingPlanner.plan(
            for: issue([
                night("mon", "2026-10-05", spine: "I did not call the surgery back."),
                night("wed", "2026-10-07", spine: "Rain all afternoon.")
            ]),
            calendar: Calendar(identifier: .gregorian))
        let draft = """
        NIGHT:mon You called the surgery back.
        NIGHT:wed Rain all afternoon.
        COLOPHON The Book bound the week: it held.
        """
        guard case .success(let salvage) = WeeklyBindingVerifier.salvage(draft, against: plan) else {
            return XCTFail("the honest half should have survived")
        }
        XCTAssertTrue(salvage.dropped.contains(.changedPolarity), "\(salvage.dropped)")
        XCTAssertFalse(salvage.verified.text.contains("You called the surgery back"))
    }

    /// A week sentence may name what two nights share. It may not put the reader
    /// in the past tense, and it may not rule on what their week meant.
    func testAWeekSentenceMayNotClaimTheReadersLife() {
        let draft = """
        NIGHT:fri You walked the long way home past the bakery.
        WEEK:mon,wed You spent the week grieving quietly.
        COLOPHON The Book bound the week: it held.
        """
        guard case .success(let salvage) = salvage(draft) else { return XCTFail("refused whole") }
        XCTAssertTrue(salvage.dropped.contains(.claimedTheReadersLife), "\(salvage.dropped)")
    }

    func testAWeekSentenceMayNotHandBackAVerdict() {
        let draft = """
        NIGHT:fri You walked the long way home past the bakery.
        WEEK:mon,wed The plums and the bakery are really about the same hunger.
        COLOPHON The Book bound the week: it held.
        """
        guard case .success(let salvage) = salvage(draft) else { return XCTFail("refused whole") }
        XCTAssertTrue(salvage.dropped.contains(.declaredMeaning), "\(salvage.dropped)")
    }

    /// One sentence, one night. Two nights in one `NIGHT:` claim is how
    /// Tuesday's walk and Friday's phone call become one afternoon.
    func testANightSentenceMayOnlyRestOnOneNight() {
        let draft = """
        NIGHT:mon,wed You bought plums and cooked them the same evening.
        NIGHT:fri You walked the long way home past the bakery.
        COLOPHON The Book bound the week: it held.
        """
        guard case .success(let salvage) = salvage(draft) else { return XCTFail("refused whole") }
        XCTAssertTrue(salvage.dropped.contains(.malformedMarker), "\(salvage.dropped)")
    }

    /// An issue that lost the night it was built around is not the issue.
    func testAnIssueThatLosesItsCoverIsRefusedWhole() {
        let draft = """
        NIGHT:mon You bought plums at the market before work.
        COLOPHON The Book bound the week: it held.
        """
        guard case .failure(let why) = salvage(draft) else {
            return XCTFail("an issue without its cover night is not the issue")
        }
        XCTAssertEqual(why, .lostTheCover)
    }

    func testAnIssueWithNoClosingLineIsRefusedWhole() {
        let draft = "NIGHT:fri You walked the long way home past the bakery."
        guard case .failure(let why) = salvage(draft) else { return XCTFail("expected refusal") }
        XCTAssertEqual(why, .missingColophon)
    }

    // MARK: - The floor

    /// The floor ships whenever the model's issue cannot be salvaged, and the
    /// reader may have paid to have it printed.
    func testTheFloorBindsARealIssue() throws {
        let plan = week()
        let prose = try XCTUnwrap(WeeklyBindingWriter.issue(for: plan))
        XCTAssertTrue(prose.contains("bakery"), prose)
        XCTAssertTrue(prose.lowercased().contains("plums"), prose)
        XCTAssertTrue(prose.contains("The Book bound the week:"), prose)
        // It leads with the night the plan chose, not with Monday.
        XCTAssertTrue(prose.hasPrefix("You walked the long way"), prose)
        // And the issue's own framing is the issue's, not the night's.
        XCTAssertTrue(prose.contains("It had been 6 days"), prose)
    }

    /// And the floor obeys the same laws it enforces on the model.
    func testTheFloorsOwnIssuePassesItsOwnVerifier() throws {
        let plan = week()
        let marked = WeeklyBindingWriter.write(plan)
            .map { claim -> String in
                switch claim.realm {
                case .colophon: return "COLOPHON \(claim.text)"
                case .editor: return "EDITOR \(claim.text)"
                default:
                    return "\(claim.realm.rawValue.uppercased()):\(claim.nightIDs.joined(separator: ",")) \(claim.text)"
                }
            }
            .joined(separator: "\n")
        guard case .success(let salvage) = WeeklyBindingVerifier.salvage(marked, against: plan) else {
            return XCTFail("the house issue could not pass the gate it enforces")
        }
        XCTAssertTrue(salvage.dropped.isEmpty, "\(salvage.dropped)")
    }
}
