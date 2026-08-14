import XCTest
@testable import InsideCoverCore

/// Every Page ends in a writing box. These contracts keep that box from going
/// back to saying the same vague thing on all sixty-odd Page types, and keep
/// the wording in the Book's own register rather than an oracle's.
final class PageMarginAskTests: XCTestCase {
    func testEveryPageTypeNamesWhatToWrite() {
        for type in BookPageType.allCases {
            let ask = type.marginAsk
            XCTAssertFalse(
                ask.label.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(type.rawValue) has no label over its writing box"
            )
            XCTAssertFalse(
                ask.placeholder.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(type.rawValue) has no invitation in its writing box"
            )
            // Long enough to be an instruction rather than a shrug.
            XCTAssertGreaterThan(
                ask.placeholder.count, 24,
                "\(type.rawValue)'s invitation is too short to tell anyone what to do"
            )
        }
    }

    /// The old failure mode: one generic line ("Add one true thing I should
    /// keep") standing in for every Page. A handful of shared labels is fine
    /// ("Your margin note"), but the actual invitation must be page-specific.
    func testInvitationsAreNotOneRecycledSentence() {
        let placeholders = BookPageType.allCases.map(\.marginAsk.placeholder)
        let distinct = Set(placeholders)
        XCTAssertEqual(
            distinct.count, placeholders.count,
            "two Page types are asking for the same thing in the same words"
        )
    }

    /// The register the Book is not allowed to slip back into: servant
    /// phrasing, and the oracle's habit of describing a Page instead of asking
    /// the reader for something.
    func testInvitationsAvoidServantAndSeerRegister() {
        let banned = [
            "no pressure", "when you're ready", "feel free to", "at your own pace",
            "if one arrives", "the shape of the day", "without asking it",
            "one true thing i should keep"
        ]
        for type in BookPageType.allCases {
            let ask = type.marginAsk
            let lower = "\(ask.label)\n\(ask.placeholder)".lowercased()
            for phrase in banned {
                XCTAssertFalse(
                    lower.contains(phrase),
                    "\(type.rawValue)'s writing box says “\(phrase)”"
                )
            }
        }
    }

    /// The evergreen cupboard is what a brand-new or heavily-disabled Book puts
    /// on the desk, so it is the first writing anyone sees. It must point at the
    /// box rather than admire itself.
    func testEvergreenReserveTellsTheReaderWhatToDo() {
        let pages = BookEvergreenPlayReserve.pages(now: Date(), keptPageCount: 99)
        XCTAssertFalse(pages.isEmpty)
        for page in pages {
            XCTAssertFalse(
                page.detail.lowercased().contains("if one arrives"),
                "\(page.type.rawValue) evergreen seed slipped back into the oracle register"
            )
            XCTAssertTrue(
                BookCharacterLint.inspect(page).filter { $0.severity == .error }.isEmpty,
                "\(page.type.rawValue) evergreen seed: \(BookCharacterLint.report([page]))"
            )
        }
    }
}
