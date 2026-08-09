import XCTest
@testable import InsideCoverCore

final class GreyPageThreatTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func pages(count: Int = 8) -> [BookPage] {
        (0..<count).map { index in
            BookPage(
                id: "page-\(index)",
                type: .souvenir,
                createdAt: now.addingTimeInterval(-Double(index + 3) * 86_400),
                promptText: "Kept Page \(index)",
                userInput: "A true detail from day \(index)."
            )
        }
    }

    func testGreyRequiresEvidencedRutAndEnoughPages() {
        var ledger = GreyPageThreatLedger.empty
        XCTAssertTrue(GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(),
            mayThreaten: false,
            distressActive: false,
            now: now
        ).isEmpty)
        XCTAssertNil(ledger.activeThreat)

        XCTAssertTrue(GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(count: 7),
            mayThreaten: true,
            distressActive: false,
            now: now
        ).isEmpty)
        XCTAssertNil(ledger.activeThreat)
    }

    func testDistressAndLongMemoryProtectionStopAClaim() {
        var ledger = GreyPageThreatLedger.empty
        XCTAssertTrue(GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(),
            mayThreaten: true,
            distressActive: true,
            now: now
        ).isEmpty)

        var protectedLedger = GreyPageThreatLedger.empty
        let allPages = pages()
        GreyPageThreatEngine.reconcile(
            ledger: &protectedLedger,
            pages: allPages,
            mayThreaten: true,
            distressActive: false,
            protectedPageIDs: Set(allPages.map(\.id)),
            now: now
        )
        XCTAssertNil(protectedLedger.activeThreat)
    }

    func testMarkHasNoClockUntilOpenedThenGetsSeventyTwoHours() throws {
        var ledger = GreyPageThreatLedger.empty
        GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(),
            mayThreaten: true,
            distressActive: false,
            now: now
        )
        let marked = try XCTUnwrap(ledger.activeThreat)
        XCTAssertEqual(marked.status, .marked)
        XCTAssertNil(marked.deadline)

        let activated = try XCTUnwrap(GreyPageThreatEngine.activate(
            threatID: marked.id,
            in: &ledger,
            now: now
        ))
        XCTAssertEqual(activated.status, .fading)
        let deadline = try XCTUnwrap(activated.deadline)
        XCTAssertEqual(
            deadline.timeIntervalSince(now),
            GreyPageThreatEngine.rescueWindow,
            accuracy: 1
        )
    }

    func testExpiredThreatLeavesRawPageButErasesLivingMemoryID() throws {
        let archivePages = pages()
        var ledger = GreyPageThreatLedger.empty
        GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: archivePages,
            mayThreaten: true,
            distressActive: false,
            now: now
        )
        let threat = try XCTUnwrap(ledger.activeThreat)
        GreyPageThreatEngine.activate(threatID: threat.id, in: &ledger, now: now)
        GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: archivePages,
            mayThreaten: true,
            distressActive: false,
            now: now.addingTimeInterval(GreyPageThreatEngine.rescueWindow + 1)
        )

        XCTAssertTrue(ledger.erasedPageIDs.contains(threat.pageID))
        XCTAssertTrue(archivePages.contains { $0.id == threat.pageID }, "the raw archive is not mutated")
    }

    func testNewTrueDetailRescuesThePage() throws {
        var ledger = GreyPageThreatLedger.empty
        GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(),
            mayThreaten: true,
            distressActive: false,
            now: now
        )
        let threat = try XCTUnwrap(ledger.activeThreat)
        GreyPageThreatEngine.activate(threatID: threat.id, in: &ledger, now: now)
        let resolved = try XCTUnwrap(GreyPageThreatEngine.resolve(
            threatID: threat.id,
            rescued: true,
            line: "The chipped blue edge was repaired yesterday.",
            in: &ledger,
            now: now
        ))

        XCTAssertEqual(resolved.status, .rescued)
        XCTAssertFalse(ledger.erasedPageIDs.contains(threat.pageID))
        XCTAssertEqual(resolved.rescueLine, "The chipped blue edge was repaired yesterday.")
    }

    func testAdapterMakesTheClockAndArchiveBoundaryExplicit() throws {
        var ledger = GreyPageThreatLedger.empty
        GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(),
            mayThreaten: true,
            distressActive: false,
            now: now
        )
        let threat = try XCTUnwrap(ledger.activeThreat)
        let warning = GreyPageThreatSourceAdapter.surface(for: threat, now: now)
        XCTAssertTrue(warning.payload.body.contains("The clock has not started"))
        XCTAssertTrue(warning.payload.body.contains("Open this and it bites"))
        XCTAssertTrue(warning.payload.body.contains("raw Page"))
        XCTAssertTrue(warning.payload.body.contains("I became furniture too"))
        XCTAssertEqual(warning.payload.metadata["bookRupturePhase"], "broken-pattern")

        let activated = try XCTUnwrap(GreyPageThreatEngine.activate(
            threatID: threat.id,
            in: &ledger,
            now: now
        ))
        let fading = GreyPageThreatSourceAdapter.surface(for: activated, now: now)
        XCTAssertEqual(fading.payload.metadata["greyThreatStatus"], "fading")
        XCTAssertNotNil(fading.payload.metadata["deadline"])
        XCTAssertTrue(fading.payload.body.contains("Stacks"))
    }

    func testRescueReopensTheBookAsWellAsThePage() throws {
        var ledger = GreyPageThreatLedger.empty
        GreyPageThreatEngine.reconcile(
            ledger: &ledger,
            pages: pages(),
            mayThreaten: true,
            distressActive: false,
            now: now
        )
        let threat = try XCTUnwrap(ledger.activeThreat)
        let rescued = try XCTUnwrap(GreyPageThreatEngine.resolve(
            threatID: threat.id,
            rescued: true,
            line: "The handle is colder than the old Page remembered.",
            in: &ledger,
            now: now
        ))
        let surface = GreyPageThreatSourceAdapter.surface(for: rescued, now: now)

        XCTAssertTrue(surface.payload.body.contains("So did I"))
        XCTAssertTrue(surface.payload.body.contains("another door"))
        XCTAssertEqual(surface.payload.metadata["bookRupturePhase"], "reopened")
    }
}
