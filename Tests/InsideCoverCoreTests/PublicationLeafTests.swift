import Foundation
import XCTest

@testable import InsideCoverCore

/// The seam between one night and the books it will be bound into.
///
/// `BookOfYouResidue` is what the weekly issue, the monthly edition and the
/// annual volume read instead of the page's prose. It was being filled by
/// *re-reading the finished page* - the spine was whichever sentence came
/// first, and what the night left open was found by hunting for a question
/// mark - while the scene plan held every one of those answers before a word
/// was written.
final class PublicationLeafTests: XCTestCase {
    private func date(_ v: String) -> Date { ISO8601DateFormatter().date(from: v)! }

    private func plannedNight(shadow: Bool = false) -> (BraidScenePlan, [BraidClaim]) {
        var market = BookPage(
            id: "market", type: .diary, createdAt: date("2026-10-05T09:00:00Z"),
            promptText: "?",
            userInput: "I bought plums at the market before work.",
            origin: .userAuthored)
        let evening = BookPage(
            id: "evening", type: .diary, createdAt: date("2026-10-05T20:00:00Z"),
            promptText: "?",
            userInput: "Cooked the plums down with far too much sugar.",
            origin: .userAuthored)
        if shadow { market.tags = [ReaderShelf.shadowTag] }
        let day = BookDay(
            id: "2026-10-05", date: date("2026-10-05T21:30:00Z"), pages: [market, evening])
        let plan = BraidScenePlanBuilder.plan(for: day)
        return (plan, BraidSceneWriter.write(plan))
    }

    /// The anchor is a decision. The first sentence is an accident of rendering.
    ///
    /// The house floor happens to render the anchor first, so it cannot tell the
    /// difference - this is written against a *model* page, where the order of
    /// sentences is Gemma's and the anchor can land anywhere.
    func testTheSpineIsTheAnchorAndNotWhateverCameFirst() throws {
        let (plan, claims) = plannedNight()
        let anchorID = try XCTUnwrap(plan.anchorEvidenceID)
        let anchor = try XCTUnwrap(plan.evidence(for: anchorID))

        // A page whose opening sentence is deliberately not the anchor.
        let page = BookPage(
            id: "braid", type: .bookOfYou, createdAt: date("2026-10-05T21:30:00Z"),
            promptText: "Book of You",
            userInput: """
                A Kitchen Full of Sugar

                The kitchen went dark before either of us noticed the hour.
                \(anchor.text)

                The Book kept the page: the plums outlasted the argument.
                """,
            tags: plan.residueTags(surviving: claims),
            origin: .generated)

        let residue = BookOfYouResidue.extract(from: page)
        XCTAssertTrue(
            residue.spineLine.lowercased().contains("plums"),
            "spine was \(residue.spineLine) - the binding took the first sentence, not the anchor")
        XCTAssertFalse(
            residue.spineLine.lowercased().contains("kitchen went dark"),
            "spine was \(residue.spineLine)")
    }

    /// What a night refused to resolve is the one thread a later issue may pick
    /// up - and it travels as an **evidence id, never as text**.
    ///
    /// Tags outlive the night and are copied with every page. A binding that
    /// wants the thread resolves the id against the reader's own archive, where
    /// their words already live under their own privacy, rather than carrying a
    /// quotable piece of somebody's worst week around in a tag.
    func testWhatTheNightLeftOpenTravelsAsAnIDAndNeverAsWords() throws {
        // Distinctive vocabulary, so a leak cannot be confused with two pages
        // that merely share a word.
        var hard = BookPage(
            id: "hard", type: .diary, createdAt: date("2026-10-05T20:00:00Z"),
            promptText: "?",
            userInput: "My sister called about the funeral arrangements.",
            origin: .userAuthored)
        hard.tags = [ReaderShelf.shadowTag]
        let ordinary = BookPage(
            id: "market", type: .diary, createdAt: date("2026-10-05T09:00:00Z"),
            promptText: "?",
            userInput: "I bought plums at the market before work.",
            origin: .userAuthored)
        let day = BookDay(
            id: "2026-10-05", date: date("2026-10-05T21:30:00Z"), pages: [ordinary, hard])
        let plan = BraidScenePlanBuilder.plan(for: day)
        try XCTSkipIf(plan.mustRemainUnresolved.isEmpty, "this fixture stopped holding anything open")
        let anchorID = try XCTUnwrap(plan.anchorEvidenceID)

        let tags = plan.residueTags(surviving: [
            BraidClaim(realm: .lived, sourceIDs: [anchorID], text: "You bought plums at the market."),
            BraidClaim(realm: .colophon, sourceIDs: [], text: "The Book kept the page: it held.")
        ])
        XCTAssertTrue(
            tags.contains { $0.hasPrefix("braid-plan-open-id:") },
            "the night held something open and told the books nothing: \(tags)")
        for id in plan.mustRemainUnresolved {
            let atom = try XCTUnwrap(plan.evidence(for: id))
            let words = atom.text.lowercased().split { !$0.isLetter }
                .map(String.init).filter { $0.count > 4 }
            for word in words {
                XCTAssertFalse(
                    tags.joined(separator: " ").lowercased().contains(word),
                    "held-open material leaked into a tag: \(word)")
            }
        }
    }

    /// A night whose page dropped the anchor proved nothing, so it leaves
    /// nothing for the week to bind.
    func testANightThatProvedNothingLeavesNoLeaf() throws {
        let (plan, _) = plannedNight()
        let tags = plan.residueTags(surviving: [
            BraidClaim(realm: .colophon, sourceIDs: [], text: "The Book kept the page: it held.")
        ])
        XCTAssertTrue(
            tags.filter { $0.hasPrefix("braid-plan-") }.isEmpty, "\(tags)")
    }

    /// A binding should be able to reach the reader's own material, not a
    /// summary of it. These are the receipts that actually survived onto the
    /// page, so the chain from a printed sentence back to a kept page holds.
    func testTheLeafNamesTheReceiptsThatSurvived() throws {
        let (plan, claims) = plannedNight()
        let evidence = plan.residueTags(surviving: claims)
            .filter { $0.hasPrefix("braid-plan-evidence:") }
            .map { String($0.dropFirst("braid-plan-evidence:".count)) }

        XCTAssertFalse(evidence.isEmpty, "no receipt reached the leaf")
        XCTAssertTrue(evidence.allSatisfy { ["market", "evening"].contains($0) }, "\(evidence)")
        XCTAssertEqual(Set(evidence).count, evidence.count, "a receipt was named twice")
    }

    /// Tags are persisted with every page, so a leaf is an index entry rather
    /// than a paragraph.
    func testALeafStaysSmallEnoughToPersist() throws {
        let (plan, claims) = plannedNight()
        for tag in plan.residueTags(surviving: claims) where tag.hasPrefix("braid-plan-") {
            XCTAssertLessThanOrEqual(tag.count, 200, tag)
        }
    }
}
