import XCTest
@testable import InsideCoverCore

/// Cast who live inside a locked folio must not turn up in the free game.
///
/// `NarrativePackRegistry.entities` is entitlement-gated, so an unbought
/// character is genuinely absent from the world: no relationships, no portrait
/// in the Cast, no business of their own. Anything that introduces them anyway
/// is showing the reader a trailer for a friend rather than a friend — and the
/// margins on a reader's first keeps are the worst possible place to do it,
/// because that beat is the game's whole first-friend promise.
final class CastEntitlementTests: XCTestCase {
    private let folioID = "dictionary-rebellion"

    override func setUp() {
        super.setUp()
        PackEntitlements.ownedPackIDs = []
    }

    override func tearDown() {
        PackEntitlements.ownedPackIDs = []
        super.tearDown()
    }

    private func owningTheFolio(_ body: () -> Void) {
        PackEntitlements.ownedPackIDs = [folioID]
        body()
        PackEntitlements.ownedPackIDs = []
    }

    // MARK: - Who is actually locked

    func testTheRebellionCastIsAbsentUntilBought() {
        XCTAssertTrue(KeepMarginalia.lockedSlugs.contains("pippa-pilcrow"))
        XCTAssertTrue(KeepMarginalia.lockedSlugs.contains("professor-thaddeus-mook"))

        owningTheFolio {
            XCTAssertFalse(KeepMarginalia.lockedSlugs.contains("pippa-pilcrow"))
            XCTAssertFalse(KeepMarginalia.lockedSlugs.contains("professor-thaddeus-mook"))
        }
    }

    func testTheFreeCastIsNeverLocked() {
        for slug in ["penny-blackletter", "zara-finch", "serenity-brown", "wicker-eddies"] {
            XCTAssertFalse(KeepMarginalia.lockedSlugs.contains(slug), "\(slug) should be free")
        }
    }

    // MARK: - The margin pool

    func testALockedCharacterCannotWriteInTheMargins() {
        let slugs = Set(KeepMarginalia.availableVoices.map(\.slug))
        XCTAssertFalse(slugs.contains("pippa-pilcrow"))
        XCTAssertFalse(slugs.contains("professor-thaddeus-mook"))
        XCTAssertFalse(slugs.isEmpty, "The margins must not fall silent")

        owningTheFolio {
            XCTAssertTrue(Set(KeepMarginalia.availableVoices.map(\.slug)).contains("pippa-pilcrow"))
        }
    }

    func testTheGreeterClampResolvesAgainstWhatTheReaderOwns() {
        // Two of the four greeters live in the folio. The clamp must narrow to
        // the two that are free rather than to nobody.
        let greeters = KeepMarginalia.availableGreeterSlugs
        XCTAssertFalse(greeters.contains("pippa-pilcrow"))
        XCTAssertFalse(greeters.contains("professor-thaddeus-mook"))
        XCTAssertTrue(greeters.contains("penny-blackletter"))
        XCTAssertTrue(greeters.contains("zara-finch"))

        owningTheFolio {
            XCTAssertEqual(KeepMarginalia.availableGreeterSlugs, KeepMarginalia.greeterSlugs)
        }
    }

    func testTheGreeterClampNeverEmptiesThePool() {
        // A clamp that filtered everybody out would silence the margins on
        // exactly the keeps that matter most.
        XCTAssertFalse(KeepMarginalia.greeterPool(from: KeepMarginalia.availableVoices).isEmpty)
        // Even handed a pool containing no greeter at all, it yields something.
        let noGreeters = KeepMarginalia.availableVoices.filter {
            !KeepMarginalia.greeterSlugs.contains($0.slug)
        }
        XCTAssertFalse(KeepMarginalia.greeterPool(from: noGreeters).isEmpty)
    }

    // MARK: - The first two keeps

    func testTheFirstFriendIsSomebodyTheReaderActuallyHas() {
        let opening = KeepMarginalia.openingKeepNote
        XCTAssertFalse(KeepMarginalia.lockedSlugs.contains(opening.castSlug))
        XCTAssertEqual(opening.castSlug, "zara-finch")
        XCTAssertFalse(opening.line.isEmpty)

        // Pippa is the better first friend and keeps the part once she exists.
        owningTheFolio {
            XCTAssertEqual(KeepMarginalia.openingKeepNote.castSlug, "pippa-pilcrow")
        }
    }

    func testTheSecondKeepDoesNotPrintANameTheReaderCannotMeet() {
        let second = KeepMarginalia.secondKeepNote
        XCTAssertFalse(KeepMarginalia.lockedSlugs.contains(second.castSlug))
        XCTAssertNil(second.rejoinderName, "The duet's other half is behind the paywall")
        XCTAssertNil(second.rejoinderLine)

        owningTheFolio {
            let duet = KeepMarginalia.secondKeepNote
            XCTAssertEqual(duet.castSlug, "professor-thaddeus-mook")
            XCTAssertEqual(duet.rejoinderName, "Pippa Pilcrow")
        }
    }

    func testTheOpeningKeepsAreStillDistinctFromEachOther() {
        // Falling back must not collapse the first-friend beat and the
        // second-keep beat into the same voice saying the same thing.
        XCTAssertNotEqual(
            KeepMarginalia.openingKeepNote.castSlug,
            KeepMarginalia.secondKeepNote.castSlug
        )
        XCTAssertNotEqual(
            KeepMarginalia.openingKeepNote.line,
            KeepMarginalia.secondKeepNote.line
        )
    }

    // MARK: - The archive keeps what it was given

    func testANoteKeptWhileOwnedKeepsItsFaceForever() {
        // Display must not be filtered. A reader who bought the folio, kept a
        // page, and later lapsed should still find that margin note intact and
        // attributed — the page happened, and the archive does not revise it.
        let pippa = KeepMarginalia.voice(forSlug: "pippa-pilcrow")
        XCTAssertNotNil(pippa, "A lapsed reader's kept pages must not lose their author")
        XCTAssertEqual(pippa?.name, "Pippa Pilcrow")
        XCTAssertFalse(pippa?.asset.isEmpty ?? true)
    }

    // MARK: - Business of their own

    func testLockedCastBringNoUndertakingIntoTheFreeGame() {
        // The staircase ladder ships inside the folio that creates Mook, so the
        // gate that hides him hides his business too.
        let free = Set(NarrativePackRegistry.entities.map(\.id))
        for ladder in CastUndertakingRegistry.coreLadders {
            XCTAssertTrue(
                free.contains(ladder.actorID),
                "\(ladder.id) is owned by a character behind an entitlement"
            )
        }
    }
}
