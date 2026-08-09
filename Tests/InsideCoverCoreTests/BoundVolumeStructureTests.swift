import XCTest
@testable import InsideCoverCore

/// Phase 1 of the bound-volumes plan: the edition reads as a book rather than a
/// filing cabinet. These tests pin the architecture — what opens, what closes,
/// and the promise that the archive keeps everything.
final class BoundVolumeStructureTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var binding: Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 28, hour: 20)) ?? Date()
    }

    private func page(_ id: String, _ type: BookPageType, _ at: Date, _ text: String) -> BookPage {
        BookPage(id: id, type: type, createdAt: at, promptText: "Prompt", userInput: text)
    }

    /// A month with a bit of everything: nights, souvenirs, and a pile of the
    /// ordinary margins that used to fall off the end of the catch-all.
    private func edition(otherPages: Int = 4) -> MonthlyEdition {
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9)) ?? binding
        var days: [BookDay] = []
        for offset in 0..<26 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let dayID = BookDay.id(for: date, calendar: calendar)
            var pages: [BookPage] = [
                page("braid-\(dayID)", .bookOfYou, date, "The night gathered itself on \(dayID)."),
                page("souv-\(dayID)", .souvenir, date, "A gull argued with a chimney on \(dayID).")
            ]
            for index in 0..<otherPages {
                pages.append(
                    page("anchor-\(dayID)-\(index)", .anchor, date, "An ordinary margin \(index) on \(dayID).")
                )
            }
            days.append(BookDay(id: dayID, date: calendar.startOfDay(for: date), pages: pages))
        }
        return MonthlyEditionBuilder.edition(
            from: days,
            readerName: "Reader",
            startDate: start,
            endDate: binding,
            generatedAt: binding,
            calendar: calendar
        )
    }

    // MARK: Architecture

    func testDedicationKeepsTheReadersExactTrimmedWords() throws {
        let dedication = try XCTUnwrap(BoundDedication(text: "  For the week we found the sea.  "))
        XCTAssertEqual(dedication.text, "For the week we found the sea.")
    }

    func testDedicationRefusesAnEmptyOrOverlongLeaf() {
        XCTAssertNil(BoundDedication(text: "   "))
        XCTAssertNil(BoundDedication(text: String(repeating: "x", count: BoundDedication.characterLimit + 1)))
    }

    func testTheVolumeOpensOnFrontMatterAndClosesOnTheArchive() {
        let sections = edition().sections
        XCTAssertEqual(
            sections.first?.resolvedPlacement, .frontMatter,
            "A volume opens by naming the month, not with a page dump."
        )
        XCTAssertEqual(
            sections.last?.id, "other-kept-pages",
            "The archive is the appendix and always sits last."
        )
        XCTAssertEqual(sections.last?.resolvedPlacement, .backMatter)
    }

    func testPlacementsRunFrontToBackWithNoInterleaving() {
        let order: [MonthlyEditionSection.Placement] = [.frontMatter, .movement, .backMatter]
        let ranks = edition().sections.map { order.firstIndex(of: $0.resolvedPlacement) ?? 1 }
        XCTAssertEqual(ranks, ranks.sorted(), "Front matter, then movements, then back matter — never mixed.")
    }

    /// The braids are the month's spine, and the user asked for them to stand
    /// alone: read end to end they are a story the reader lived without
    /// stopping to call it one.
    func testTheNightlyBraidsAreTheirOwnMovement() {
        let braids = edition().sections.first { $0.id == "daily-braids" }
        XCTAssertNotNil(braids)
        XCTAssertEqual(braids?.resolvedPlacement, .movement)
        XCTAssertEqual(braids?.title, "The Nightly Braids")
        XCTAssertGreaterThan(braids?.items.count ?? 0, 1)
    }

    func testABraidHeavyMonthKeepsItsNightsInOrder() {
        let braids = edition().sections.first { $0.id == "daily-braids" }
        let dates = braids?.items.compactMap(\.date) ?? []
        XCTAssertGreaterThan(dates.count, 1)
        XCTAssertEqual(dates, dates.sorted(), "The month's spine has to run forwards.")
    }

    /// A book should not open with its endings.
    func testTalesResolveAfterTheBraidsRatherThanLeading() {
        let sections = edition().sections
        guard let tales = sections.firstIndex(where: { $0.id == "tales-finished" }) else {
            return  // no tales closed in this fixture; nothing to order
        }
        guard let braids = sections.firstIndex(where: { $0.id == "daily-braids" }) else {
            return XCTFail("The braids movement should exist.")
        }
        XCTAssertGreaterThan(tales, braids)
    }

    // MARK: The promise

    /// The catch-all used to cap at 48 and silently drop the overflow out of a
    /// heavy month. "Nothing you kept is ever lost" has to be true or it is not
    /// a promise.
    func testTheArchiveIsNeverTruncated() {
        let heavy = edition(otherPages: 4)
        guard let archive = heavy.sections.first(where: { $0.id == "other-kept-pages" }) else {
            return XCTFail("A month of ordinary margins should still open the archive.")
        }
        XCTAssertGreaterThan(
            archive.items.count, 48,
            "A heavy month must bind past the old 48-item ceiling."
        )
    }

    func testEveryBoundSectionActuallyHasContent() {
        XCTAssertTrue(
            edition().sections.allSatisfy { !$0.items.isEmpty },
            "An empty section is a blank page with a heading on it."
        )
    }

    // MARK: Compatibility

    func testASectionBoundBeforeTheRestructureStillDecodesAsAMovement() throws {
        let legacy = #"{"id":"letters","title":"Letters","note":"","items":[]}"#
        let decoded = try JSONDecoder().decode(
            MonthlyEditionSection.self,
            from: Data(legacy.utf8)
        )
        XCTAssertNil(decoded.placement)
        XCTAssertEqual(decoded.resolvedPlacement, .movement)
    }
}
