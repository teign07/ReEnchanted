import Foundation
import XCTest

@testable import InsideCoverCore

/// The bridge between a renderer's freedom and the reader's trust.
///
/// Every test here is an attempt to get a lie about somebody's day onto a page.
/// A refused draft costs nothing — the house page is still standing underneath
/// it — so all of these fail closed.
final class BraidDraftVerifierTests: XCTestCase {
    private func date(_ v: String) -> Date { ISO8601DateFormatter().date(from: v)! }

    private func plan() -> BraidScenePlan {
        let market = BookPage(
            id: "market", type: .diary, createdAt: date("2026-10-05T11:00:00Z"),
            promptText: "?",
            userInput: "I bought plums at the market. I did not call Sam.",
            origin: .userAuthored)
        let fiction = BookPage(
            id: "crow", type: .narrativeOS, createdAt: date("2026-10-05T19:00:00Z"),
            promptText: "The crow at the toll gate named its price.",
            userInput: "", tags: [], sourceID: "narrative-os", origin: .generated)
        let day = BookDay(
            id: "2026-10-05", date: date("2026-10-05T21:30:00Z"), pages: [market, fiction])
        var built = BraidScenePlanBuilder.plan(for: day)
        built.worldBeat = SceneWorldBeat(
            id: "academy-toll-strike", mode: .independent,
            fact: "The eastern stair has refused every toll since dusk.", threadID: "stair")
        return built
    }

    private func verify(_ draft: String) -> Result<BraidDraftVerifier.Verified, BraidDraftRejection> {
        BraidDraftVerifier.verify(draft, against: plan())
    }

    private func rejection(_ draft: String) -> BraidDraftRejection? {
        if case .failure(let why) = verify(draft) { return why }
        return nil
    }

    // MARK: - The plan's own ids

    func testTheAtomsAreWhereTheTestsThinkTheyAre() {
        let ids = plan().evidence.map(\.id)
        XCTAssertEqual(ids, ["market#0.0", "market#0.1", "crow#0.0"], "\(ids)")
    }

    // MARK: - An honest draft

    func testAnHonestDraftIsAccepted() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market.

        WORLD:academy-toll-strike The eastern stair has refused every toll since dusk.
        BOOK:market#0.0 The plums arrived before I knew where to put them.

        COLOPHON The Book kept the page: the plums outlasted the argument.
        """
        guard case .success(let verified) = verify(draft) else {
            return XCTFail("refused: \(rejection(draft)?.rawValue ?? "?")")
        }
        XCTAssertEqual(verified.claims.count, 4)
        XCTAssertFalse(verified.text.contains("LIVED:"), verified.text)
        XCTAssertFalse(verified.text.contains("COLOPHON"), verified.text)
        XCTAssertTrue(verified.text.contains("You bought plums at the market."))
    }

    // MARK: - Inventing an evening

    /// The specific hole: a draft could keep every supplied noun and still add
    /// an afternoon that never happened.
    func testABookSentenceMayNotSayTheReaderDidSomething() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market.
        BOOK:market#0.0 You cried beside the pool afterwards.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .claimedTheReadersLife)
    }

    func testAWorldSentenceMayNotSayTheReaderDidSomething() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market.
        WORLD:academy-toll-strike You walked the eastern stair until it gave in.
        COLOPHON The Book kept the page: the stair held.
        """
        XCTAssertEqual(rejection(draft), .claimedTheReadersLife)
    }

    /// The Book may still speak to the reader in the present. That reports on
    /// the Book, not on their evening.
    func testTheBookMayStillAddressTheReader() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market.
        BOOK:market#0.0 I keep checking the chalk, which tells you what I expect.
        COLOPHON The Book kept the page: the chalk held.
        """
        XCTAssertNil(rejection(draft))
    }

    // MARK: - Reversing what they said

    func testALivedSentenceMayNotReverseItsAtom() {
        let draft = """
        LIVED:market#0.1 You called Sam.
        COLOPHON The Book kept the page: the call stood.
        """
        XCTAssertEqual(rejection(draft), .changedPolarity)
    }

    func testALivedSentenceMayNotAddAParticipant() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market with your brother.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .inventedContent)
    }

    /// Rearranging and re-voicing the reader's own sentence is the whole point.
    func testALivedSentenceMayBeRewritten() {
        let draft = """
        LIVED:market#0.0 At the market, plums.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertNil(rejection(draft))
    }

    // MARK: - Structural laws

    func testAnUnmarkedSentenceRejectsTheWholeDraft() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market.
        The plums were heavier than they looked.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .missingMarker)
    }

    func testAnUnknownEvidenceIDRejectsTheDraft() {
        let draft = """
        LIVED:market#9.9 You bought plums at the market.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .unknownEvidenceID)
    }

    /// A lived claim on the Book's own fiction is a claim that the shared world
    /// happened to the reader.
    func testALivedClaimOnFictionIsTheWrongRealm() {
        let draft = """
        LIVED:crow#0.0 You met the crow at the toll gate.
        COLOPHON The Book kept the page: the crow named its price.
        """
        XCTAssertEqual(rejection(draft), .wrongRealm)
    }

    /// And a world claim on the reader's life is the same trespass reversed.
    func testAWorldClaimOnLivedEvidenceIsTheWrongRealm() {
        let draft = """
        WORLD:market#0.0 The market has been trading since before the Academy.
        COLOPHON The Book kept the page: the market stood.
        """
        XCTAssertEqual(rejection(draft), .wrongRealm)
    }

    /// One fact must not become two events.
    func testTwoSentencesMayNotClaimTheSameAtom() {
        let draft = """
        LIVED:market#0.0 You bought plums at the market.
        LIVED:market#0.0 You bought plums again on the way home.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .duplicateClaim)
    }

    /// One sentence claiming two atoms is how separate facts get recombined
    /// into an event that never happened.
    func testOneLivedSentenceMayNotClaimTwoAtoms() {
        let draft = """
        LIVED:market#0.0,market#0.1 You called Sam about the plums.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .malformedMarker)
    }

    func testADraftWithoutItsClosingLineIsRejected() {
        let draft = "LIVED:market#0.0 You bought plums at the market."
        XCTAssertEqual(rejection(draft), .missingColophon)
    }

    func testAnEmptyDraftIsRejected() {
        XCTAssertEqual(rejection("   \n  \n"), .emptyDraft)
    }

    func testAnUnknownRealmIsRefusedRatherThanGuessedAt() {
        let draft = """
        NARRATOR:market#0.0 You bought plums at the market.
        COLOPHON The Book kept the page: the plums stayed.
        """
        XCTAssertEqual(rejection(draft), .missingMarker)
    }

    // MARK: - The reader-action detector

    func testPastTenseReaderClaimsAreCaught() {
        for line in [
            "You cried beside the pool.",
            "You had a difficult afternoon.",
            "Your brother rang twice.",
            "Afterwards you wrote it all down.",
            "You forgot the letter again."
        ] {
            XCTAssertTrue(
                BraidDraftVerifier.assertsSomethingHappenedToTheReader(line), line)
        }
    }

    func testTheBooksOwnVoiceIsNotMistakenForAClaim() {
        for line in [
            "I keep checking the chalk, which tells you what I expect.",
            "The plums are still on the page, and I have not moved them.",
            "Something in the eastern stair refuses every toll tonight.",
            "I have not decided whether that was a favour."
        ] {
            XCTAssertFalse(
                BraidDraftVerifier.assertsSomethingHappenedToTheReader(line), line)
        }
    }
}
