import XCTest
@testable import InsideCoverCore

final class BookDeskRoundTests: XCTestCase {
    private func page(_ source: String, _ type: BookPageType = .diary, id: String? = nil) -> SurfacePage {
        SurfacePage(id: id ?? source, type: type, sourceID: source, prompt: "p", detail: "d")
    }

    func testCapacityAndUniqueLogicalSlots() {
        var round = BookDeskRound()
        let pages = (0..<12).map { page("p-\($0)") }
        round.begin(with: [page("a"), page("a", .diary, id: "rotated")] + pages)
        XCTAssertEqual(round.resolutions.count, BookDeskRound.reserveCapacity)
    }

    func testOpenIsIdempotentAndOutranksPass() {
        var round = BookDeskRound(); let item = page("a")
        round.begin(with: [item]); round.pass(item); round.open(item); round.pass(item)
        XCTAssertEqual(round.resolutions[item.deskSlotKey], .opened)
    }

    func testPassUndoAndRotatedID() {
        var round = BookDeskRound(); let original = page("a", id: "old")
        round.begin(with: [original]); round.pass(original)
        round.undoPass(page("a", id: "new"))
        XCTAssertEqual(round.resolutions[original.deskSlotKey], .waiting)
    }

    func testEveryPassedSlotCanBeReplacedWithoutEndingTheDesk() {
        var round = BookDeskRound()
        var pages = (0..<BookDeskRound.reserveCapacity).map { page("p-\($0)") }
        round.begin(with: pages)
        round.open(page("outside"))
        for index in pages.indices {
            let outgoing = pages[index]
            let replacement = page("reserve-\(index)")
            round.pass(outgoing)
            pages[index] = replacement
            round.reconcilePublished(with: pages)
            XCTAssertEqual(round.resolutions[replacement.deskSlotKey], .waiting)
            XCTAssertEqual(round.resolutions.count, BookDeskRound.reserveCapacity)
        }
    }

    func testOpeningKeepsTheWholeReserveAvailable() {
        var round = BookDeskRound()
        let pages = (0..<BookDeskRound.reserveCapacity).map { page("p-\($0)") }
        round.begin(with: pages)
        round.openKeepingReserve(pages[1])

        XCTAssertEqual(round.slotKeys, Set(pages.map(\.deskSlotKey)))
        XCTAssertEqual(round.resolutions[pages[1].deskSlotKey], .opened)
        XCTAssertEqual(round.resolutions[pages.last!.deskSlotKey], .waiting)
    }

    func testUntouchedEnrichmentRekeysRoundToVisiblePages() {
        var round = BookDeskRound()
        round.begin(with: [page("a"), page("b"), page("c")])
        let enriched = [page("magic"), page("a"), page("b")]
        round.reconcileUntouched(with: enriched)
        XCTAssertEqual(round.slotKeys, Set(enriched.map(\.deskSlotKey)))
    }

    func testTouchedRoundCannotBeRewrittenByEnrichment() {
        var round = BookDeskRound()
        let pages = [page("a"), page("b"), page("c")]
        round.begin(with: pages)
        round.open(pages[0])
        round.reconcileUntouched(with: [page("magic"), page("b"), page("c")])
        XCTAssertEqual(round.slotKeys, Set(pages.map(\.deskSlotKey)))
        XCTAssertEqual(round.resolutions[pages[0].deskSlotKey], .opened)
    }

    func testFallbackPublicationPreservesAnswersAndTracksReplacement() {
        var round = BookDeskRound()
        let original = [page("a"), page("b"), page("c")]
        round.begin(with: original)
        round.pass(original[0])
        round.open(original[1])

        let replacement = page("replacement")
        round.reconcilePublished(with: [replacement, original[1], original[2]])

        XCTAssertEqual(round.resolutions[replacement.deskSlotKey], .waiting)
        XCTAssertEqual(round.resolutions[original[1].deskSlotKey], .opened)
        XCTAssertNil(round.resolutions[original[0].deskSlotKey])
    }

    func testShortPublicationCanDropOutgoingSlotWithoutLeavingItTracked() {
        var round = BookDeskRound()
        let pages = (0..<BookDeskRound.reserveCapacity).map { page("p-\($0)") }
        round.begin(with: pages)
        round.pass(pages[0])

        let survivors = Array(pages.dropFirst())
        round.reconcilePublished(with: survivors)

        XCTAssertFalse(round.isTracking(pages[0]))
        XCTAssertEqual(round.slotKeys, Set(survivors.map(\.deskSlotKey)))
        XCTAssertEqual(round.resolutions.count, BookDeskRound.reserveCapacity - 1)
    }

    func testEvergreenPlayReserveCanFillEveryTrackedSlot() {
        let pages = BookEvergreenPlayReserve.pages(
            now: Date(timeIntervalSince1970: 1_750_000_000)
        )

        XCTAssertGreaterThan(pages.count, BookDeskRound.reserveCapacity)
        XCTAssertEqual(Set(pages.map(\.deskSlotKey)).count, pages.count)
        XCTAssertTrue(pages.allSatisfy { $0.payload.metadata["evergreenPlayReserve"] == "true" })
        XCTAssertTrue(pages.allSatisfy { $0.payload.metadata["curationLearning"] == "forbidden" })
        XCTAssertTrue(pages.allSatisfy { CausalCurationReceipt.read(from: $0) == nil })
        XCTAssertFalse(pages.contains(where: \.isReaderActionCommission))
    }

    func testEvergreenPlayReserveMintsAnotherLocalOccurrenceWhenTheLedgerAdvances() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let first = BookEvergreenPlayReserve.pages(now: now, generation: 4)
        let next = BookEvergreenPlayReserve.pages(now: now, generation: 5)

        XCTAssertEqual(first.map(\.type), next.map(\.type))
        XCTAssertTrue(Set(first.map(\.id)).isDisjoint(with: Set(next.map(\.id))))
        XCTAssertTrue(Set(first.map(\.curatorContentNoveltyKey)).isDisjoint(
            with: Set(next.map(\.curatorContentNoveltyKey))
        ))
    }

    func testEvergreenPlayReserveCanReplaceAFullReserveSlot() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let previous = Array(
            BookEvergreenPlayReserve.pages(now: now, generation: 4)
                .prefix(BookDeskRound.reserveCapacity)
        )
        let outgoing = previous[0]
        let resolution = BookCurator.resolvingRetiredDeskSlots(
            previous: previous,
            retiringIDs: [outgoing.id],
            rebuilt: BookEvergreenPlayReserve.pages(now: now, generation: 5),
            additionallyBlockedKeys: outgoing.curatorDeskExclusionKeys,
            limit: BookDeskRound.reserveCapacity
        )

        XCTAssertTrue(resolution.replacesAll([outgoing.id]))
        XCTAssertEqual(resolution.pages.count, BookDeskRound.reserveCapacity)
        XCTAssertFalse(resolution.pages.contains(where: { $0.id == outgoing.id }))
    }

    func testSwipeRestKeysDoNotDisableAWholeTypeOrSource() {
        let surface = page("journal-source", .diary, id: "one-journal-question")

        XCTAssertTrue(surface.curatorDismissalRestKeys.contains(surface.id))
        XCTAssertFalse(surface.curatorDismissalRestKeys.contains("source:\(surface.sourceID)"))
        XCTAssertFalse(surface.curatorDismissalRestKeys.contains(CuratorVarietyGovernor.typeKey(for: surface.type)))
    }
}
