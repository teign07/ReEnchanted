import Foundation
import XCTest

@testable import InsideCoverCore

/// The floor, held to the ceiling's laws.
///
/// The old writer could be trusted because it assembled the page itself, and
/// could not be *checked* because nothing downstream knew which sentence was a
/// fact and which was invention. This one emits the same marked claims a model
/// must emit, so the same verifier reads both.
final class BraidSceneWriterTests: XCTestCase {
    private func date(_ v: String) -> Date { ISO8601DateFormatter().date(from: v)! }

    private func marked(_ claims: [BraidClaim]) -> String {
        claims.map { claim in
            switch claim.realm {
            case .colophon: return "COLOPHON \(claim.text)"
            default:
                let ids = claim.sourceIDs.joined(separator: ",")
                return "\(claim.realm.rawValue.uppercased()):\(ids) \(claim.text)"
            }
        }.joined(separator: "\n")
    }

    /// The whole corpus, written by the floor and read by the verifier. If the
    /// house writer cannot satisfy the laws, no model will.
    func testTheFloorPassesItsOwnVerifierOnEveryBenchNight() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            guard !plan.placements.isEmpty else { continue }
            let claims = BraidSceneWriter.write(plan)
            switch BraidDraftVerifier.verify(marked(claims), against: plan) {
            case .success:
                continue
            case .failure(let why):
                XCTFail("\(night.name): the floor was refused as \(why.rawValue)")
            }
        }
    }

    /// Only pronouns move, so a lived claim still says exactly what its atom
    /// says — which is what lets it pass `preservesFacts` against itself.
    func testTurningASentenceToFaceTheReaderChangesNoFacts() {
        let cases = [
            ("I bought plums at the market.", "You bought plums at the market."),
            ("I rang my brother back.", "You rang your brother back."),
            ("I did not call Sam.", "You did not call Sam."),
            ("My mother said I never write.", "Your mother said you never write.")
        ]
        for (original, expected) in cases {
            let turned = BraidSceneWriter.secondPerson(original)
            XCTAssertEqual(turned, expected)
            XCTAssertTrue(
                BraidRevisionVerifier.preservesFacts(turned, of: original), turned)
            XCTAssertTrue(
                BraidRevisionVerifier.preservesPolarity(turned, of: original), turned)
        }
    }

    /// The Book comments on the page, never on a noun. A sentence that
    /// interpolates the night's subject is how the world ended up orbiting a
    /// coffee mug: 80 of 81 world strings took the anchor as an argument.
    func testTheBookNeverInterpolatesTheNightsNoun() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            guard let anchor = plan.anchor else { continue }
            let anchorWords = Set(
                anchor.text.lowercased()
                    .split { !$0.isLetter }
                    .map(String.init)
                    .filter { $0.count > 4 })
            for claim in BraidSceneWriter.write(plan) where claim.realm == .book {
                let words = Set(
                    claim.text.lowercased().split { !$0.isLetter }.map(String.init))
                XCTAssertTrue(
                    words.isDisjoint(with: anchorWords),
                    "\(night.name): the Book's own sentence reached for the anchor: \(claim.text)")
            }
        }
    }

    /// Hard material is witnessed. It gets no commentary and no relation.
    func testHardMaterialGetsNoCommentary() {
        var hard = BookPage(
            id: "hard", type: .diary, createdAt: date("2026-10-02T20:00:00Z"),
            promptText: "?", userInput: "My sister called about the funeral arrangements.",
            origin: .userAuthored)
        hard.tags = [ReaderShelf.shadowTag]
        let plain = BookPage(
            id: "bread", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
            promptText: "?", userInput: "I walked to the corner shop for bread.",
            origin: .userAuthored)
        let day = BookDay(
            id: "2026-10-02", date: date("2026-10-02T21:30:00Z"), pages: [plain, hard])
        let plan = BraidScenePlanBuilder.plan(for: day)
        let claims = BraidSceneWriter.write(plan)
        XCTAssertFalse(
            claims.contains { $0.realm == .book },
            claims.map(\.text).joined(separator: " | "))
        XCTAssertTrue(
            claims.contains { $0.text.contains("stayed in the order they came") })
    }

    /// A world beat is carried, and carried as a world claim rather than
    /// smuggled in as something that happened to the reader.
    func testAWorldBeatIsCarriedAsAWorldClaim() {
        let page = BookPage(
            id: "bread", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
            promptText: "?", userInput: "I walked to the corner shop for bread.",
            origin: .userAuthored)
        var plan = BraidScenePlanBuilder.plan(
            for: BookDay(id: "2026-10-02", date: date("2026-10-02T21:30:00Z"), pages: [page]))
        plan.worldBeat = SceneWorldBeat(
            id: "academy-toll-strike", mode: .independent,
            fact: "The eastern stair has refused every toll since dusk.", threadID: "stair")
        let claims = BraidSceneWriter.write(plan)
        guard let world = claims.first(where: { $0.realm == .world }) else {
            return XCTFail(claims.map(\.text).joined(separator: " | "))
        }
        XCTAssertEqual(world.sourceIDs, ["academy-toll-strike"])
        XCTAssertFalse(BraidDraftVerifier.assertsSomethingHappenedToTheReader(world.text))
    }

    func testEveryPageStillEndsOnTheRitualLine() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            guard !plan.placements.isEmpty else { continue }
            let claims = BraidSceneWriter.write(plan)
            XCTAssertEqual(claims.last?.realm, .colophon, night.name)
            XCTAssertTrue(
                claims.last?.text.hasPrefix("The Book kept the page:") ?? false, night.name)
        }
    }
}
