import XCTest
@testable import InsideCoverCore

/// A Page with something to do should say what, in its own verb. "Open the page"
/// is a filing verb; the Book asking you to cast a spell is the Book.
final class LeafInvitationTests: XCTestCase {
    private func page(_ type: BookPageType) -> SurfacePage {
        SurfacePage(
            id: "probe-\(type.rawValue)",
            type: type,
            sourceID: "probe",
            score: 10,
            prompt: "probe",
            detail: "probe",
            payload: BookPagePayload(headline: "probe", body: "probe")
        )
    }

    func testPagesWithSomethingToDoSayWhat() {
        XCTAssertEqual(page(.enchantment).leafInvitation?.title, "Choose a photo and cast")
        XCTAssertEqual(page(.wonderCompass).leafInvitation?.title, "Begin the Compass Run")
        XCTAssertEqual(page(.tarot).leafInvitation?.title, "Turn the cards")
    }

    /// nil is a real answer, not a gap. A Page that cannot honour a verb should
    /// fall back to the plain invitation rather than promise something.
    func testReadingPagesHaveNoVerbOfTheirOwn() {
        for type in [BookPageType.diary, .quotes, .letter, .bookNotices] {
            XCTAssertNil(page(type).leafInvitation, "\(type) should not claim a verb")
        }
    }

    /// Every verb needs a symbol to print beside it on the leaf.
    func testEveryVerbCarriesASymbol() {
        for type in BookPageType.allCases {
            guard let invitation = page(type).leafInvitation else { continue }
            XCTAssertFalse(invitation.title.isEmpty, "\(type)")
            XCTAssertFalse(invitation.symbol.isEmpty, "\(type) has a verb but nothing to print with it")
        }
    }
}
