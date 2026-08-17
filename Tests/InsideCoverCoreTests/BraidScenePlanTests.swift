import Foundation
import XCTest

@testable import InsideCoverCore

/// The plan is the artifact the bench should argue about.
///
/// Golden-testing prose means every improvement to a sentence rewrites the
/// golden and nobody reads the diff. Golden-testing the *decision* means the
/// diff says "this night stopped being about the mug", which is a sentence a
/// person can disagree with.
final class BraidScenePlanTests: XCTestCase {
    private static let goldenPath = "Tests/InsideCoverCoreTests/Golden/scene-plans.txt"

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Contract

    /// Evidence is atomic. A page holding two facts yields two atoms, because
    /// "I did not call Sam, but I did water the plants" is one page whose
    /// recombination into a single claim invents the evening.
    func testEvidenceIsAtomicRatherThanPerPage() {
        let page = BookPage(
            id: "two-facts", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
            promptText: "?",
            userInput: "I did not call Sam. I watered the plants instead.",
            origin: .userAuthored)
        let plan = BraidScenePlanBuilder.plan(for: day([page]))
        XCTAssertGreaterThan(plan.evidence.count, 1, plan.summary)
        XCTAssertTrue(plan.evidence.allSatisfy { $0.id.hasPrefix("two-facts#") })
    }

    /// Atom ids have to mean the same thing every time, or a claim cannot be
    /// checked against one.
    func testEvidenceIdsAreStable() {
        let subject = day([
            BookPage(id: "p", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
                     promptText: "?", userInput: "I mended the gate. I left the door open.",
                     origin: .userAuthored)
        ])
        XCTAssertEqual(
            BraidScenePlanBuilder.plan(for: subject).evidence.map(\.id),
            BraidScenePlanBuilder.plan(for: subject).evidence.map(\.id))
    }

    /// A kept photograph is evidence, and it is evidence *about the reader's
    /// life* — so a claim made from it is checkable rather than free.
    func testAPhotographIsAtomicEvidenceAboutTheReadersLife() {
        var photo = BookPage(
            id: "heron", type: .illuminatedPhoto, createdAt: date("2026-10-02T12:00:00Z"),
            promptText: "?", userInput: "", origin: .userAuthored)
        photo.mediaAssets = [BookPageMediaAsset(
            id: "m", kind: .photoLibraryAsset, reference: "r",
            caption: "A heron on the roof of the car park.")]
        let plan = BraidScenePlanBuilder.plan(for: day([photo]))
        guard let atom = plan.evidence.first else { return XCTFail(plan.summary) }
        XCTAssertEqual(atom.kind, .photograph)
        XCTAssertTrue(atom.isAboutTheReadersLife)
        XCTAssertTrue(atom.text.contains("heron"))
    }

    /// Kept fiction is evidence of the shared world and never of the reader's
    /// biography. The renderer's freedom depends on that line.
    func testKeptFictionIsNotEvidenceAboutTheReadersLife() {
        let fiction = BookPage(
            id: "fox", type: .narrativeOS, createdAt: date("2026-10-02T19:00:00Z"),
            promptText: "The fox at the toll gate asked for a name instead of a coin.",
            userInput: "", tags: [], sourceID: "narrative-os", origin: .generated)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), fiction]))
        guard let atom = plan.evidence.first(where: { $0.pageID == "fox" }) else {
            return XCTFail(plan.summary)
        }
        XCTAssertEqual(atom.kind, .keptFiction)
        XCTAssertFalse(atom.isAboutTheReadersLife)
        XCTAssertFalse(plan.livedEvidence.contains(atom))
    }

    /// Kept fiction is what enters from the Book's world, by construction.
    func testKeptFictionIsTheDisturbance() {
        let fiction = BookPage(
            id: "fox", type: .narrativeOS, createdAt: date("2026-10-02T19:00:00Z"),
            promptText: "The fox at the toll gate asked for a name instead of a coin.",
            userInput: "", tags: [], sourceID: "narrative-os", origin: .generated)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), fiction]))
        XCTAssertEqual(plan.placement(of: "fox#0.0"), .disturbance, plan.summary)
    }

    /// The anchor is an atom, not a word pulled out of a sentence. That is what
    /// makes "the beers" and "the standing" structurally impossible.
    func testTheAnchorIsAnAtom() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        guard let anchorID = plan.anchorEvidenceID else { return XCTFail(plan.summary) }
        XCTAssertNotNil(plan.evidence(for: anchorID))
        XCTAssertEqual(plan.placement(of: anchorID), .anchor)
    }

    /// A souvenir is the reader stopping to choose one true line out of a whole
    /// day. If they chose one, it owns the page.
    func testASouvenirOwnsThePage() {
        let souvenir = BookPage(
            id: "mug", type: .souvenir, createdAt: date("2026-10-02T20:00:00Z"),
            promptText: "One true thing", userInput: "The mug is sulking about being empty.",
            origin: .userAuthored)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), souvenir]))
        XCTAssertEqual(plan.anchorEvidenceID, "mug#0.0", plan.summary)
    }

    /// Hard material is witnessed, never given a dramatic job.
    func testUnclearedShadowIsWitnessedAndMustRemainUnresolved() {
        var hard = BookPage(
            id: "hard", type: .diary, createdAt: date("2026-10-02T21:00:00Z"),
            promptText: "?", userInput: "My sister called about the funeral arrangements.",
            origin: .userAuthored)
        hard.tags = [ReaderShelf.shadowTag]
        let plan = BraidScenePlanBuilder.plan(for: day([hard]))
        guard let atom = plan.evidence.first else { return XCTFail(plan.summary) }
        if plan.placements.contains(where: { $0.evidenceID == atom.id }) {
            XCTAssertEqual(plan.placement(of: atom.id), .witness, plan.summary)
        }
        XCTAssertTrue(atom.isUnclearedShadow)
    }

    /// A watching night is not a transforming one, and saying otherwise gives a
    /// quiet day a plot it did not have.
    func testAVigilTransformsNothing() {
        for motion in [BraidPromptBuilder.NarrativeMotion.vigil] {
            XCTAssertEqual(motion.rawValue, "vigil")
        }
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        XCTAssertTrue(SceneTransformation.allCases.contains(plan.transformation))
    }

    /// The plan may carry evidence. It may never carry a rendered sentence.
    func testThePlanCarriesNoAuthoredProse() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let bookVoice = ["I kept", "I put", "The Book kept the page", "the company arrived"]
        for atom in plan.evidence {
            for phrase in bookVoice {
                XCTAssertFalse(atom.text.contains(phrase), "\(atom.id): \(atom.text)")
            }
        }
    }

    // MARK: - Golden

    /// Every bench night's decision, in one reviewable file.
    func testScenePlanGoldenIsUnchanged() throws {
        let rendered = BraidBench.corpus()
            .map { night -> String in
                let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
                return "===== \(night.name) =====\n\(plan.summary)"
            }
            .joined(separator: "\n\n")

        let url = repoRoot().appendingPathComponent(Self.goldenPath)
        if ProcessInfo.processInfo.environment["SCENE_PLAN_RECORD"] == "1" {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try rendered.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
            return XCTFail("no scene-plan golden; record with SCENE_PLAN_RECORD=1")
        }
        XCTAssertEqual(
            rendered, expected,
            "The braid decides differently than the golden file. Read the diff: it is decisions, not sentences.")
    }

    // MARK: - Helpers

    private func diary() -> BookPage {
        BookPage(id: "bakery", type: .diary, createdAt: date("2026-10-02T08:00:00Z"),
                 promptText: "?", userInput: "I walked past the bakery that shut last winter.",
                 origin: .userAuthored)
    }

    private func day(_ pages: [BookPage]) -> BookDay {
        BookDay(id: "2026-10-02", date: date("2026-10-02T21:30:00Z"), pages: pages)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
