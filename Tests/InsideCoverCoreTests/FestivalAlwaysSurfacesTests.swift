import XCTest
@testable import InsideCoverCore

/// A feast day reaches the reader on the day it happens.
///
/// The world feast calendar is one of the largest things in this app — every
/// tradition computed through ICU calendars rather than a table, ranked, with
/// grief valves, one-tap permanent rest and five celebration mechanics — and it
/// was reaching nobody at all. Measured before the fix on seven major feasts:
/// the adapter produced a good candidate scoring 83–85 every time, the
/// candidate reached the pool every time, and it was seated **zero** times, at
/// every desk size from three to twelve.
///
/// Three separate things were taking it, which is why it looked like one
/// stubborn bug:
///
/// 1. `IntroductionCurriculum` held `.festival` at stage 2 — six kept pages.
///    For a family that recurs, a staged debut delays it. For one that happens
///    on a fixed date, it deletes it: a new reader doesn't get Samhain late,
///    they get it next year.
/// 2. The loop floor took its chair, because a feast is `deskJob == .play` and
///    play is what the floor displaces first.
/// 3. Injections took it back afterwards, protecting only milestones and the
///    braid.
///
/// The rule that came out of it: **a Page whose candidate window is a single
/// day cannot be rationed by anything designed to ration a family.** Every
/// other floor on this desk defers its debt to tomorrow. A full moon has no
/// tomorrow.
final class FestivalAlwaysSurfacesTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 19) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: 0
        )) ?? Date()
    }

    private func desk(on when: Date, limit: Int = 3) -> [SurfacePage] {
        let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
        return BookCurator.surfacedPages(
            for: day, context: .make(for: day), inputs: .empty, now: when, limit: limit
        )
    }

    private func candidate(on when: Date) -> SurfacePage? {
        let day = BookDay(id: BookDay.id(for: when), date: when, pages: [])
        return FestivalPageSourceAdapter().candidates(
            for: day, context: .make(for: day), inputs: .empty, now: when
        ).first
    }

    /// The whole promise, swept across a year: **if the Book has a feast for
    /// today, the reader sees it today.** Not ranked well. Seen.
    func testEveryDayWithAFeastPutsItOnTheDesk() {
        var checked = 0
        var missed: [String] = []
        for month in 1...12 {
            let days = calendar.range(of: .day, in: .month, for: date(2026, month, 1))?.count ?? 28
            for day in 1...days {
                let when = date(2026, month, day)
                guard let feast = candidate(on: when) else { continue }
                checked += 1
                if !desk(on: when).contains(where: { $0.type == .festival }) {
                    missed.append("\(BookDay.id(for: when)) \(feast.id)")
                }
            }
        }
        XCTAssertGreaterThan(checked, 40, "a year should hold more feasts than this")
        XCTAssertTrue(missed.isEmpty, "feasts the reader never saw: \(missed)")
    }

    /// The kinds named explicitly. An esbat is the most perishable page in the
    /// app — the moon is full for one night and does not come back for a month.
    func testTheMoonsAndTheMeteorsAreCoveredToo() {
        var kinds: Set<String> = []
        for month in 1...12 {
            let days = calendar.range(of: .day, in: .month, for: date(2026, month, 1))?.count ?? 28
            for day in 1...days {
                let when = date(2026, month, day)
                guard let feast = candidate(on: when),
                      let kind = feast.payload.metadata["celebrationKind"]
                else { continue }
                XCTAssertTrue(
                    desk(on: when).contains { $0.type == .festival },
                    "\(kind) on \(BookDay.id(for: when)) never reached the desk"
                )
                kinds.insert(kind)
            }
        }
        XCTAssertTrue(kinds.contains("esbat"), "the year produced no moons at all: \(kinds)")
        XCTAssertGreaterThanOrEqual(kinds.count, 2, "only one kind of feast in a whole year: \(kinds)")
    }

    /// The curriculum gate, specifically. A reader on their first day, with
    /// nothing kept, still gets the solstice.
    func testAReaderWithNothingKeptStillGetsTheFeast() {
        XCTAssertFalse(
            IntroductionCurriculum.locks(.festival, keptPageCount: 0, surfaceHistory: [:]),
            "the introduction curriculum is holding the feast back again"
        )
        XCTAssertTrue(desk(on: date(2026, 10, 31)).contains { $0.type == .festival })
    }

    /// The floor promotes what the adapters made. It never conjures a feast on
    /// a day that has none — a Book that invents an occasion is worse than one
    /// that misses it.
    func testNoFeastMeansNoFestivalPage() {
        let when = date(2026, 2, 4)
        XCTAssertNil(candidate(on: when), "fixture drift: this day is supposed to be ordinary")
        XCTAssertFalse(desk(on: when).contains { $0.type == .festival })
    }

    /// A feast holds its chair against the things that were taking it. Both the
    /// loop floor and the injections ask `holdsItsChair` now.
    func testTheFeastHoldsItsChair() {
        let feast = candidate(on: date(2026, 10, 31))!
        XCTAssertTrue(BookCurator.holdsItsChair(feast))
        XCTAssertFalse(
            BookCurator.holdsItsChair(
                SurfacePage(id: "x", type: .diary, sourceID: "diary-page", prompt: "", detail: "")
            ),
            "the protection is for the pages that cannot wait, not for everything"
        )
    }
}
