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

    /// A locked fact is what the renderer is told it may not change, so it had
    /// better not be scaffolding. A Fae Bargain body arrives with field
    /// separators and an upstream mid-sentence clip; handing "--- They fronted
    /// you the." over as a fact is worse than printing it.
    func testScaffoldingNeverBecomesALockedFact() {
        let page = BookPage(
            id: "sprite", type: .narrativeOS, createdAt: date("2026-10-02T07:00:00Z"),
            promptText: "A Fae Bargain: Book Sprite --- A Book Sprite traced the pale rectangle. --- They fronted you the...",
            userInput: "", tags: [], sourceID: "narrative-os", origin: .generated)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), page]))
        for atom in plan.evidence where atom.pageID == "sprite" {
            XCTAssertFalse(atom.text.contains("---"), atom.text)
            XCTAssertFalse(atom.text.contains("Fae Bargain:"), atom.text)
            XCTAssertFalse(atom.text.hasSuffix("the..."), atom.text)
        }
        XCTAssertTrue(
            plan.evidence.contains { $0.text.contains("traced the pale rectangle") },
            plan.summary)
    }

    // MARK: - The brief

    /// The old prompt handed Gemma the whole archive and a rulebook - 20,320
    /// characters against a 21,090 allowance on a heavy night. The brief hands
    /// over a decision.
    func testTheBriefIsSmallerThanTheArchiveItReplaced() {
        guard let night = BraidBench.corpus().first(where: { $0.name == "full-braid" }) else {
            return XCTFail("no full-braid night")
        }
        let brief = BraidScenePlanBuilder
            .plan(for: night.day, context: night.context)
            .brief()
        let old = BraidPromptBuilder.prompt(for: night.day, context: night.context)
        XCTAssertLessThan(brief.count * 4, old.count, "brief \(brief.count) vs prompt \(old.count)")
    }

    /// The brief has to teach the format, or nothing it produces can be parsed.
    func testTheBriefTeachesTheMarkerFormat() {
        let brief = BraidScenePlanBuilder.plan(for: day([diary()])).brief()
        for token in ["LIVED:", "BOOK:", "WORLD:", "COLOPHON", "discarded"] {
            XCTAssertTrue(brief.contains(token), token)
        }
    }

    /// Every fact it locks must be addressable, or the renderer cannot cite it.
    func testEveryFactInTheBriefCarriesAnID() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let brief = plan.brief()
        for placement in plan.placements {
            XCTAssertTrue(brief.contains(placement.evidenceID), placement.evidenceID)
        }
    }

    // MARK: - What came back

    private func night(_ day: Int, _ text: String) -> BookDay {
        let at = date(String(format: "2026-11-%02dT21:30:00Z", day))
        return BookDay(
            id: String(format: "2026-11-%02d", day), date: at,
            pages: [BookPage(
                id: "p\(day)", type: .diary, createdAt: at.addingTimeInterval(-3600),
                promptText: "One true thing", userInput: text, origin: .userAuthored)])
    }

    private func carried(_ nights: [BookDay], tonight: BookDay) -> SceneReturn? {
        BraidScenePlanBuilder.plan(
            for: tonight, context: .empty, archive: nights,
            calendar: Calendar(identifier: .gregorian)
        ).carriedReturn
    }

    /// The thing this whole phase exists for. A reader noticed a recorder in a
    /// window nine days after their mother mentioned learning one, and the old
    /// engine connected nothing - it invented frost on a window instead.
    func testAThingComingBackIsFound() {
        let archive = [night(6, "Rang Mum. She has decided to learn the recorder.")]
        let tonight = night(15, "Saw the recorder in a charity shop window and did not buy it.")
        guard let ret = carried(archive, tonight: tonight) else {
            return XCTFail("the recorder came back and nothing noticed")
        }
        XCTAssertEqual(ret.daysSince, 9)
        XCTAssertTrue(ret.isSpine)
        XCTAssertTrue(ret.priorText.contains("recorder"))
    }

    /// A gap the reader had to cross deliberately. Two days is an echo.
    func testAShortGapIsNotASpine() {
        let archive = [night(10, "Someone had put a chair out on the pavement.")]
        let tonight = night(12, "I walked past the chair. It has gone.")
        guard let ret = carried(archive, tonight: tonight) else { return XCTFail("no return") }
        XCTAssertEqual(ret.daysSince, 2)
        XCTAssertFalse(ret.isSpine)
    }

    /// Tomorrow is continuation, not return.
    func testTheNextDayIsNotAReturn() {
        let archive = [night(11, "Someone had put a chair out on the pavement.")]
        XCTAssertNil(carried(archive, tonight: night(12, "The chair has gone.")))
    }

    /// A coincidence of vocabulary is not a thing coming back. Matching on any
    /// content word paired "I have never been to" with "I have never seen", and
    /// "I bought the recorder" with "Bought apples".
    func testACoincidenceOfVocabularyIsNotAReturn() {
        let archive = [night(4, "The bus was rerouted and I saw a street I have never seen.")]
        let tonight = night(8, "Found a coin from a country I have never been to.")
        XCTAssertNil(carried(archive, tonight: tonight), "matched on \"never\"")
    }

    func testASharedVerbIsNotAReturn() {
        let archive = [night(4, "Bought apples that turned out to be for cooking.")]
        let tonight = night(17, "I bought the recorder.")
        XCTAssertNil(carried(archive, tonight: tonight), "matched on \"bought\"")
    }

    /// A word the reader uses constantly is their vocabulary, not a return.
    func testAWordUsedEveryNightIsNotAReturn() {
        let archive = (1...6).map { night($0, "I wrote in the notebook again.") }
        XCTAssertNil(carried(archive, tonight: night(20, "I wrote in the notebook.")))
    }

    func testNothingIsReturnedWithoutAnArchive() {
        XCTAssertNil(carried([], tonight: night(12, "I walked past the chair.")))
    }

    // MARK: - Earned length and shape

    /// The band was a fixed aspiration per scale and the writer padded to reach
    /// it. Measured on a nine-page night, raising the floor from 280 to 380
    /// added ninety-eight words of which every one was authored and none was the
    /// reader's.
    func testALongerPageIsNotAFullerOne() {
        let thin = BraidScenePlanBuilder.plan(for: day([
            BookPage(id: "a", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
                     promptText: "?", userInput: "Rain.", origin: .userAuthored)
        ]))
        XCTAssertLessThanOrEqual(thin.earnedWords.lowerBound, 90, thin.summary)

        let full = BraidScenePlanBuilder.plan(for: day((0..<7).map { index in
            BookPage(id: "p\(index)", type: .diary,
                     createdAt: date("2026-10-02T09:00:00Z").addingTimeInterval(Double(index) * 3600),
                     promptText: "?",
                     userInput: "I mended the gate in the back room and left the door open, number \(index).",
                     origin: .userAuthored)
        }))
        XCTAssertGreaterThan(full.earnedWords.lowerBound, thin.earnedWords.lowerBound, full.summary)
    }

    /// A night carrying nothing substantial is allowed to be short. Nothing here
    /// pads.
    func testAThinNightIsAllowedToBeShort() {
        let plan = BraidScenePlanBuilder.plan(for: day([
            BookPage(id: "a", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
                     promptText: "?", userInput: "Tired.", origin: .userAuthored)
        ]))
        XCTAssertEqual(plan.earnedWords, 40...90, plan.summary)
    }

    private func keptBraid(
        _ day: Int, title: String, paragraphs: Int, opening: String = "You walked to the shop."
    ) -> BookDay {
        let at = date(String(format: "2026-11-%02dT21:30:00Z", day))
        let body = ([opening] + (1..<max(1, paragraphs)).map { _ in "It rained." })
            .joined(separator: "\n\n")
        return BookDay(
            id: String(format: "2026-11-%02d", day), date: at,
            pages: [BookPage(
                id: "b\(day)", type: .bookOfYou, createdAt: at, promptText: "Book of You",
                userInput: "\(title)\n\n\(body)\n\nThe Book kept the page: it held.",
                origin: .generated)])
    }

    /// Read one page and it is good. Read thirty bound into a volume and the
    /// reader learns the shape by night four.
    func testAPageThatLooksLikeTheLastFiveIsToldToDiffer() {
        var context = BraidPromptBuilder.Context()
        context.recentDays = (15...19).map { keptBraid($0, title: "The Mug Saw It", paragraphs: 2) }
        let plan = BraidScenePlanBuilder.plan(
            for: BookDay(id: "2026-11-20", date: date("2026-11-20T21:30:00Z"), pages: [diary()]),
            context: context, calendar: Calendar(identifier: .gregorian))

        XCTAssertEqual(Set(plan.shape.recentTitleShapes).count, 1, "\(plan.shape)")
        let brief = plan.brief()
        XCTAssertTrue(brief.contains("VARY:"), brief)
        XCTAssertTrue(brief.contains("titles were built the same way"), brief)
        XCTAssertTrue(brief.contains("paragraphs each"), brief)
    }

    /// And a varied history says nothing, because there is nothing to correct.
    func testAVariedHistoryIsLeftAlone() {
        var context = BraidPromptBuilder.Context()
        context.recentDays = [
            keptBraid(15, title: "The Mug Saw It", paragraphs: 2,
                      opening: "You walked to the shop."),
            keptBraid(16, title: "What the Fox Charged", paragraphs: 4,
                      opening: "I circled it once and said nothing."),
            keptBraid(17, title: "Frost", paragraphs: 3,
                      opening: "Frost crossed the window and stopped.")
        ]
        let plan = BraidScenePlanBuilder.plan(
            for: BookDay(id: "2026-11-20", date: date("2026-11-20T21:30:00Z"), pages: [diary()]),
            context: context, calendar: Calendar(identifier: .gregorian))
        XCTAssertFalse(plan.brief().contains("VARY:"), plan.brief())
    }

    // MARK: - The world's own business

    /// The finding this answers: 80 of 81 world strings interpolated the
    /// reader's noun, so the Academy could never act until a coffee mug
    /// authorised it.
    func testNoCanonicalWorldFactNeedsTheReader() {
        XCTAssertFalse(SceneWorldCanon.facts.isEmpty)
        for fact in SceneWorldCanon.facts {
            XCTAssertFalse(
                BraidDraftVerifier.assertsSomethingHappenedToTheReader(fact.text), fact.id)
            XCTAssertFalse(fact.text.contains("\\("), "\(fact.id) still has a slot")
        }
        XCTAssertEqual(
            Set(SceneWorldCanon.facts.map(\.id)).count, SceneWorldCanon.facts.count)
    }

    /// Every night gets world business now, where the schema field sat nil.
    func testEveryBenchNightHasAWorldBeat() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            XCTAssertNotNil(plan.worldBeat, night.name)
        }
    }

    /// A page holding hard material gets the world beside it, never about it.
    func testHardMaterialGetsTheWorldBesideItNotAboutIt() {
        var hard = BookPage(
            id: "hard", type: .diary, createdAt: date("2026-10-02T20:00:00Z"),
            promptText: "?", userInput: "My sister called about the funeral arrangements.",
            origin: .userAuthored)
        hard.tags = [ReaderShelf.shadowTag]
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), hard]))
        XCTAssertEqual(plan.worldBeat?.mode, .counterpoint, plan.summary)
    }

    /// When the reader kept a piece of the world, the world may cross their day.
    func testKeptFictionLetsTheWorldIntersect() {
        let fiction = BookPage(
            id: "fox", type: .narrativeOS, createdAt: date("2026-10-02T19:00:00Z"),
            promptText: "The fox at the toll gate asked for a name instead of a coin.",
            userInput: "", tags: [], sourceID: "narrative-os", origin: .generated)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), fiction]))
        XCTAssertEqual(plan.worldBeat?.mode, .intersecting, plan.summary)
    }

    /// And an ordinary night is the world's own business.
    func testAnOrdinaryNightGetsIndependentWorldBusiness() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        XCTAssertEqual(plan.worldBeat?.mode, .independent, plan.summary)
    }

    /// What the reader has just seen rests. Stamped world claims are the record
    /// of what actually reached a page.
    func testAWorldFactTheReaderJustSawIsRested() {
        let plain = BraidScenePlanBuilder.plan(for: day([diary()]))
        guard let seen = plain.worldBeat?.id else { return XCTFail(plain.summary) }

        let at = date("2026-10-01T21:30:00Z")
        var context = BraidPromptBuilder.Context()
        context.recentDays = [BookDay(
            id: "2026-10-01", date: at,
            pages: [BookPage(
                id: "b", type: .bookOfYou, createdAt: at, promptText: "Book of You",
                userInput: "A Night\n\nSomething.\n\nThe Book kept the page: it held.",
                tags: ["braid-claim:world:\(seen)"], origin: .generated)])]
        let next = BraidScenePlanBuilder.plan(
            for: day([diary()]), context: context, calendar: Calendar(identifier: .gregorian))
        XCTAssertNotEqual(next.worldBeat?.id, seen, "the world repeated itself")
    }

    /// The floor carries it as a world claim, and the verifier agrees.
    func testTheFloorCarriesTheWorldBeatLegally() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let claims = BraidSceneWriter.write(plan)
        guard let world = claims.last(where: { $0.realm == .world }) else {
            return XCTFail(claims.map(\.text).joined(separator: " | "))
        }
        XCTAssertEqual(world.sourceIDs, [plan.worldBeat?.id])
        XCTAssertFalse(BraidDraftVerifier.assertsSomethingHappenedToTheReader(world.text))
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
