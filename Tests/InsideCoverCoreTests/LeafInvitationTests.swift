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

    private func page(_ type: BookPageType, _ metadata: [String: String]) -> SurfacePage {
        SurfacePage(
            id: "probe-\(type.rawValue)",
            type: type,
            sourceID: "probe",
            score: 10,
            prompt: "probe",
            detail: "probe",
            payload: BookPagePayload(headline: "probe", body: "probe", metadata: metadata)
        )
    }

    func testPagesWithSomethingToDoSayWhat() {
        XCTAssertEqual(page(.enchantment).leafInvitation?.title, "Choose a photo and cast")
        XCTAssertEqual(page(.wonderCompass).leafInvitation?.title, "Begin the Compass Run")
        XCTAssertEqual(page(.tarot).leafInvitation?.title, "Turn the cards")
        XCTAssertEqual(page(.twoReadings).leafInvitation?.title, "Take a side")
        XCTAssertEqual(page(.gamePage).leafInvitation?.title, "Play")
        XCTAssertEqual(page(.rest).leafInvitation?.title, "Mark the rest")
    }

    /// A plate that has already been illuminated is reading matter. Asking the
    /// reader to illuminate it again would be asking for work already done.
    func testAnIlluminatedPlateStopsAsking() {
        XCTAssertNotNil(page(.illuminatedPhoto, [:]).leafInvitation)
        XCTAssertNil(
            page(.illuminatedPhoto, ["renderedPreviewPath": "/tmp/plate.jpg"]).leafInvitation
        )
    }

    /// A bargain on the desk is only ever *offered*. Naming the debt would front
    /// a cost the reader has not agreed to, and letting it go is meant to be free.
    func testABargainIsOnlyEverOffered() {
        let title = page(.faeBargain).leafInvitation?.title ?? ""
        XCTAssertEqual(title, "Hear the bargain")
        for owed in ["pay", "owe", "debt"] {
            XCTAssertFalse(title.lowercased().contains(owed), "a desk bargain must not name a debt")
        }
    }

    /// Letters and notes reach the reader through the generation path, which
    /// offers "Let me write" when there is writing to do. A verb here would ask
    /// again for one already written.
    func testWritingPagesAreLeftToTheGenerationPath() {
        XCTAssertNil(page(.letter).leafInvitation)
        XCTAssertNil(page(.note).leafInvitation)
    }

    /// nil is a real answer, not a gap. A Page that cannot honour a verb should
    /// fall back to the plain invitation rather than promise something.
    func testReadingPagesHaveNoVerbOfTheirOwn() {
        // bookNotices is deliberately not in this list: a Notice asks whether
        // the Book has it right (onBookNoticeFeedback, onBookOpinionContested),
        // so it is one of the asking Pages, not reading matter.
        for type in [BookPageType.diary, .quotes, .affirmations, .lore, .quip] {
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
