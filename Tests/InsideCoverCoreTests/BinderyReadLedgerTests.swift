import XCTest
@testable import InsideCoverCore

/// The Bindery shelf marks a finished book the Reader hasn't opened.
final class BinderyReadLedgerTests: XCTestCase {
    private func period(_ start: String, _ end: String) -> PublicationPeriodID {
        PublicationPeriodID(recipe: .calendarMonth, startDayID: start, endDayID: end)
    }

    func testAFinishedBookIsNewUntilOpened() {
        var ledger = BinderyReadLedger()
        let october = period("2026-10-01", "2026-11-01")
        XCTAssertTrue(ledger.isNew(october))
        ledger.markOpened(october)
        XCTAssertFalse(ledger.isNew(october))
        XCTAssertFalse(ledger.isNew(nil), "A book still being written is never new.")
    }

    func testBooksBoundBeforeTheLedgerCountAsRead() {
        var ledger = BinderyReadLedger()
        let september = period("2026-09-01", "2026-10-01")
        let october = period("2026-10-01", "2026-11-01")
        ledger.seed(alreadyBound: [september])
        XCTAssertFalse(ledger.isNew(september))
        XCTAssertTrue(ledger.isNew(october))
        // Seeding happens once; later binds are recorded by opening them.
        ledger.seed(alreadyBound: [october])
        XCTAssertTrue(ledger.isNew(october))
    }

    func testLedgerStaysBounded() {
        var ledger = BinderyReadLedger()
        for day in 0..<(BinderyReadLedger.capacity + 10) {
            ledger.markOpened(period("d\(day)", "e\(day)"))
        }
        XCTAssertEqual(ledger.opened.count, BinderyReadLedger.capacity)
        XCTAssertTrue(ledger.isNew(period("d0", "e0")), "The oldest entries fall away first.")
    }
}
