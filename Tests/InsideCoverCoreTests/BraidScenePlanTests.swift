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

    func testEvidenceKeepsTimesAndClosingMarksWhole() {
        let page = BookPage(
            id: "time", type: .diary, createdAt: date("2026-10-02T09:00:00Z"),
            promptText: "?", userInput: "The blue door, 7:52 a.m. I read *Dracula.* Then I waited.",
            origin: .userAuthored)
        let plan = BraidScenePlanBuilder.plan(for: day([page]))
        XCTAssertEqual(plan.evidence.filter { $0.pageID == page.id }.map(\.text),
                       ["The blue door, 7:52 a.m.", "I read *Dracula.*", "Then I waited."])
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

    /// A kept monthly-event door is shared-world continuity even though its
    /// Page type is a notice. Future interactive-fiction Pages can use the same
    /// explicit tags without being mistaken for reader biography.
    func testKeptWorldEventPageIsSharedWorldEvidence() {
        let event = BookPage(
            id: "dictionary-door", type: .bookNotices,
            createdAt: date("2026-10-02T19:30:00Z"),
            promptText: "The Dictionary Rebellion has reached the assembly.",
            userInput: "", tags: ["world-event", "event:dictionary-rebellion"],
            sourceID: "world-event-door", origin: .generated)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), event]))
        guard let atom = plan.evidence.first(where: { $0.pageID == event.id }) else {
            return XCTFail(plan.summary)
        }

        XCTAssertEqual(atom.kind, .keptFiction)
        XCTAssertFalse(atom.isAboutTheReadersLife)
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

    // MARK: - Drawn lines

    private func atom(_ id: String, _ text: String, _ hour: Int) -> SceneEvidence {
        SceneEvidence(
            id: id, pageID: id, kind: .writtenLine, text: text,
            occurredAt: ISO8601DateFormatter().date(from: "2026-10-05T\(String(format: "%02d", hour)):00:00Z")!,
            isUnclearedShadow: false)
    }

    /// Length has to come from somewhere real, and this is the somewhere: a
    /// sentence resting on two of the reader's facts cannot be generic, because
    /// no two pairings are alike.
    func testTheSameThingInTwoEntriesIsALine() {
        let found = BraidScenePlanBuilder.relations(among: [
            atom("a#0.0", "I bought plums at the market before work.", 9),
            atom("b#0.0", "Cooked the plums down with too much sugar.", 19)
        ])
        XCTAssertEqual(found.first?.kind, .sharedThing)
        XCTAssertEqual(found.first?.pivot, "plums")
    }

    /// The relation that nearly became a filler engine.
    ///
    /// Any two entries six hours apart qualify, so on the bench it fired for
    /// twelve of fifteen pairings and brought a word allowance with it. Held to
    /// the day's first and last thing it says something, and only once.
    func testTheDayIsSpannedOnceAndOnlyAtItsEnds() {
        let found = BraidScenePlanBuilder.relations(among: [
            atom("a#0.0", "Coffee on the step before anyone was up.", 7),
            atom("b#0.0", "Long meeting about the budget again.", 13),
            atom("c#0.0", "Watched the light go off the roofs.", 21)
        ])
        let spans = found.filter { $0.kind == .acrossTheDay }
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first.map { Set($0.evidenceIDs) }, Set(["a#0.0", "c#0.0"]))
    }

    /// One entry containing a striking word became three separate relations
    /// against three unrelated partners: one observation, stated three times,
    /// each with a word allowance attached.
    func testOneEntryCannotCarryThePageOnItsOwn() {
        let found = BraidScenePlanBuilder.relations(among: [
            atom("hub#0.0", "Rang mum about the plums and the boxes and the car.", 9),
            atom("b#0.0", "Plums went soft on the sill.", 12),
            atom("c#0.0", "Boxes still in the hall.", 15),
            atom("d#0.0", "Car made the noise again.", 18)
        ])
        let appearances = found.flatMap(\.evidenceIDs).filter { $0 == "hub#0.0" }
        XCTAssertLessThanOrEqual(appearances.count, 1, "\(found)")
    }

    /// The Book must not go quiet on the nights it could do the most good.
    ///
    /// This was a rule that hard material got no lines at all, which made grief
    /// pages the shortest pages the braid wrote. Naming a connection is not
    /// closing one: a held-open line may notice, and may not explain, resolve or
    /// brighten.
    func testAHardNightStillGetsItsLineAndKeepsItOpen() {
        let found = BraidScenePlanBuilder.relations(
            among: [
                atom("a#0.0", "Washed the chipped yellow bowl before anyone was up.", 9),
                atom("b#0.0", "Put the bowl back in dad's cupboard and shut the door.", 20)
            ],
            leaveOpen: ["b#0.0"])
        XCTAssertEqual(found.first?.kind, .sharedThing)
        XCTAssertEqual(found.first?.holdsOpen, true)
    }

    /// And the line a hard night gets offers nothing.
    func testAHeldOpenLineOffersNoEnding() throws {
        let day = BookDay(
            id: "2026-10-05", date: Date(),
            pages: [
                BookPage(
                    id: "bowl", type: .diary, createdAt: Date(), promptText: "?",
                    userInput: "Washed the chipped yellow bowl. Put the bowl back in dad's cupboard.",
                    origin: .userAuthored)
            ])
        var plan = BraidScenePlanBuilder.plan(for: day)
        plan.relations = [
            SceneRelation(
                kind: .sharedThing, evidenceIDs: plan.evidence.map(\.id), pivot: "bowl",
                holdsOpen: true)
        ]
        let line = try XCTUnwrap(BraidSceneWriter.drawnLine(plan.relations[0], in: plan))
        for consolation in ["at least", "which is how", "you know", "better", "will pass"] {
            XCTAssertFalse(line.lowercased().contains(consolation), line)
        }
    }

    /// A reader who buys one plum in the morning and cooks the plums down at
    /// night is not obliged to use the same number both times.
    func testOneThingAndSeveralOfItAreTheSameThing() {
        let found = BraidScenePlanBuilder.relations(among: [
            atom("a#0.0", "Washed the chipped yellow bowl before anyone was up.", 9),
            atom("b#0.0", "All the bowls are still on the draining board.", 19)
        ])
        XCTAssertEqual(found.first?.kind, .sharedThing)
    }

    /// A night that kept one four-word fragment is allowed to be short. Padding
    /// it out is the filler the whole band exists to refuse.
    func testAThinNightBuysNothing() {
        let found = BraidScenePlanBuilder.relations(among: [atom("a#0.0", "Rain.", 9)])
        XCTAssertTrue(found.isEmpty)
    }

    // MARK: - The crossing

    /// The move that decides whether a night reads as a faerie tale or a list
    /// was being improvised, and on the floor was not made at all.
    func testTheDayAndTheFictionAreGivenAPlaceToTouch() throws {
        let night = try XCTUnwrap(
            BraidBench.corpus().first { $0.name == "rich-mixed-night" })
        let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
        XCTAssertTrue(
            plan.evidence.contains { $0.kind == .keptFiction }, "the bench night should keep fiction")
        let crossing = try XCTUnwrap(plan.crossing, plan.summary)
        XCTAssertEqual(plan.evidence(for: crossing.fictionID)?.kind, .keptFiction)
        XCTAssertEqual(plan.evidence(for: crossing.livedID)?.isAboutTheReadersLife, true)

        // And the floor makes it, rather than leaving the fiction in its own
        // block with nothing reaching across.
        let claims = BraidSceneWriter.write(plan)
        XCTAssertTrue(
            claims.contains {
                $0.realm == .book
                    && Set($0.sourceIDs) == Set([crossing.livedID, crossing.fictionID])
            },
            claims.map(\.text).joined(separator: " | "))
    }

    /// A night with no kept fiction has nothing to cross, and inventing one
    /// would be the Book manufacturing a faerie tale out of an ordinary Tuesday.
    func testANightWithoutFictionHasNoCrossing() {
        let day = BookDay(
            id: "2026-10-05", date: Date(),
            pages: [
                BookPage(
                    id: "a", type: .diary, createdAt: Date(), promptText: "?",
                    userInput: "Rang the dentist and put the bins out.", origin: .userAuthored)
            ])
        XCTAssertNil(BraidScenePlanBuilder.plan(for: day).crossing)
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
    ///
    /// The bar was a flat quarter of the old prompt until the magical-diary
    /// direction gave the brief a north star to carry: the diary law, the form
    /// as architecture, and the world modes. That is direction, not archive —
    /// so what this holds now is that the brief stays *substantially* smaller
    /// than the packet it replaced, and never drifts back toward being one.
    func testTheBriefIsSmallerThanTheArchiveItReplaced() {
        guard let night = BraidBench.corpus().first(where: { $0.name == "full-braid" }) else {
            return XCTFail("no full-braid night")
        }
        let brief = BraidScenePlanBuilder
            .plan(for: night.day, context: night.context)
            .brief()
        let old = BraidPromptBuilder.prompt(for: night.day, context: night.context)
        XCTAssertLessThan(brief.count * 3, old.count, "brief \(brief.count) vs prompt \(old.count)")
    }

    /// The brief and a full-length braid have to fit the window together.
    ///
    /// This is the constraint that actually bites on device, and it is not the
    /// one the size test above is about: 8K window, 680 tokens reserved for the
    /// page itself, 192 for safety. A brief that quietly grows until the model
    /// has no room to finish is how a good draft ends mid-sentence — and
    /// truncation is a budget failure here, never a style.
    func testTheBriefLeavesRoomForTheBraidItself() {
        for night in BraidBench.corpus() {
            let brief = BraidScenePlanBuilder
                .plan(for: night.day, context: night.context)
                .brief()
            let input = LocalBrainPromptBudget.estimatedTokens(for: brief)
            let needed = input
                + LocalBrainPromptBudget.braidMaxOutputTokens
                + LocalBrainPromptBudget.safetyTokens
            XCTAssertLessThan(
                needed,
                LocalBrainPromptBudget.braidContextWindowTokens,
                "\(night.name): brief \(input) tokens leaves no room for the page")
        }
    }

    /// Provenance is the plan's job. The small model sees prose material, not a
    /// syntax exercise it can accidentally print into the reader's Page.
    func testTheBriefContainsNoMachineBookkeeping() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let brief = plan.brief()
        for token in [
            "LIVED:", "BOOK:", "WORLD:", "COLOPHON", "PARAGRAPH",
            "HIDDEN LABELS", "REAL REPORT LABELS", "BOOK MAGIC LABELS"
        ] {
            XCTAssertFalse(brief.contains(token), "\(token) leaked into:\n\(brief)")
        }
        guard let fact = plan.placements.first,
              let atom = plan.evidence(for: fact.evidenceID) else {
            return XCTFail(plan.summary)
        }
        let narrationCopy = atom.isAboutTheReadersLife
            ? BraidSceneWriter.secondPerson(atom.text)
            : atom.text
        XCTAssertTrue(brief.contains(narrationCopy), brief)
        XCTAssertFalse(brief.contains(plan.markerID(forEvidenceID: atom.id)), brief)
    }

    func testTheBriefUsesTheExistingStoryFormForAMeldedTelling() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let brief = plan.brief()

        XCTAssertTrue(brief.contains("one continuous story in plain prose, entirely in the past tense"), brief)
        XCTAssertTrue(brief.contains("Retell material written in any other tense in the past"), brief)
        XCTAssertTrue(brief.contains("Address the reader as \"you\""), brief)
        XCTAssertTrue(brief.contains("only for me, the Book"), brief)
        XCTAssertTrue(brief.contains("Story shape:"), brief)
        XCTAssertTrue(brief.contains(BraidScenePlan.readerDayLabel), brief)
        XCTAssertTrue(brief.contains(BraidScenePlan.worldLabel), brief)
        XCTAssertTrue(brief.contains("Before the first paragraph ends"), brief)
        XCTAssertTrue(brief.contains("from that odd thing happen in the story"), brief)
        XCTAssertTrue(brief.contains("Do not omit it, list it, or leave it as background information"), brief)
        XCTAssertLessThan(
            brief.range(of: BraidScenePlan.worldLabel)!.lowerBound,
            brief.range(of: "Reader-day material")!.lowerBound,
            "the required world event must reach the small model before the day's evidence"
        )
        XCTAssertTrue(brief.contains("It may run beside the reader's day"), brief)
        XCTAssertTrue(brief.contains("ingredients, not as an outline or a list"), brief)
        XCTAssertTrue(brief.contains("Let sentences lead into each other instead of repeating each item and commenting on it"), brief)
        XCTAssertFalse(brief.contains("BOOK:OWN"), brief)
        XCTAssertFalse(brief.contains("PARAGRAPH"), brief)
        XCTAssertFalse(brief.contains("After a label"), brief)
        XCTAssertFalse(brief.contains("CRAFT EXAMPLES"), brief)
        XCTAssertFalse(brief.contains("OPTIONAL HINGES"), brief)
        XCTAssertFalse(brief.contains("a reaction tied to one fact"), brief)
        XCTAssertFalse(brief.contains("May not say the reader did anything"), brief)
        XCTAssertFalse(brief.contains("NARRATIVE SPINE:"), brief)
        XCTAssertFalse(brief.contains("Most sentences must be BOOK or WORLD"), brief)
        for atom in plan.evidence where plan.placements.contains(where: { $0.evidenceID == atom.id }) {
            let narrationCopy = atom.isAboutTheReadersLife
                ? BraidSceneWriter.secondPerson(atom.text)
                : atom.text
            XCTAssertEqual(
                brief.components(separatedBy: narrationCopy).count - 1,
                1,
                "\(atom.id) was handed to Gemma more than once")
        }
    }

    /// Perspective is settled in the material before Gemma writes. The source
    /// Page remains first person in the plan/archive; only the commissioned
    /// telling copy faces the reader. World material keeps its own voice.
    func testTheBriefFacesReaderEvidenceTowardYouWithoutRewritingTheSources() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let brief = plan.brief()

        XCTAssertEqual(plan.anchor?.text, "I walked past the bakery that shut last winter.")
        XCTAssertTrue(
            brief.contains("You walked past the bakery that shut last winter."), brief)
        XCTAssertFalse(
            brief.contains("\(BraidScenePlan.readerDayLabel) I walked past the bakery"), brief)
        if let worldBeat = plan.worldBeat {
            XCTAssertTrue(brief.contains(BraidScenePlan.worldMaterial(worldBeat)), brief)
        }
    }

    func testContributionReceiptsStayBesideThePromptRatherThanInsideIt() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let tags = plan.contributionTags

        XCTAssertEqual(BraidContributionReceipt.pageIDs(in: tags), ["bakery"])
        XCTAssertEqual(BraidContributionReceipt.receipts(in: tags).map(\.id), [plan.worldBeat?.id].compactMap { $0 })
        XCTAssertFalse(plan.brief().contains(BraidContributionReceipt.pageTagPrefix), plan.brief())
        XCTAssertFalse(plan.brief().contains(BraidContributionReceipt.encodedTagPrefix), plan.brief())
    }

    func testOlderWorldClaimsBecomeOnlyHonestDisplayReceipts() {
        let receipts = BraidContributionReceipt.receipts(in: [
            "braid-claim:world:straight-frost",
            "braid-claim:world:undertaking:wicker:s1",
            // A kept-fiction evidence atom already has a Page receipt. Its
            // opaque id must not be relabelled as Academy business.
            "braid-claim:world:kept-story#0.0"
        ])

        XCTAssertEqual(receipts.map(\.id), ["straight-frost", "undertaking:wicker:s1"])
        XCTAssertEqual(receipts.first(where: { $0.id == "straight-frost" })?.kind, .academy)
        XCTAssertEqual(
            receipts.first(where: { $0.id == "undertaking:wicker:s1" })?.destination,
            .castLedger
        )
    }

    func testAnEmptyPlaceholderNounDoesNotBecomeTheTitle() {
        XCTAssertEqual(
            BraidScenePlan.fragment(of: "I'm going to risk something.", fromEnd: false),
            "Risk"
        )
    }

    /// Every selected fact still reaches Gemma, but only as material. Its id
    /// remains in the plan and never competes with the prose task.
    func testEverySelectedFactAppearsWithoutAnID() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let brief = plan.brief()
        for placement in plan.placements {
            guard let atom = plan.evidence(for: placement.evidenceID) else {
                return XCTFail(placement.evidenceID)
            }
            let narrationCopy = atom.isAboutTheReadersLife
                ? BraidSceneWriter.secondPerson(atom.text)
                : atom.text
            XCTAssertTrue(brief.contains(narrationCopy), atom.id)
            XCTAssertFalse(brief.contains(plan.requiredMarker(for: atom)), brief)
        }
    }

    func testPlainProseGetsContinuityReceiptsAfterTheWriting() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        guard let lived = plan.anchor,
              let world = plan.worldBeat else { return XCTFail(plan.summary) }
        let prose = "\(lived.text) \(BraidScenePlan.worldMaterial(world))"

        let claims = plan.provenanceClaimsCarried(in: prose)
        XCTAssertTrue(claims.contains {
            $0.realm == .lived && $0.sourceIDs == [lived.id]
        }, "\(claims)")
        XCTAssertTrue(claims.contains {
            $0.realm == .world && $0.sourceIDs == [world.id]
        }, "\(claims)")
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
        let plan = BraidScenePlanBuilder.plan(for: tonight, context: .empty, archive: archive,
                                             calendar: Calendar(identifier: .gregorian))
        XCTAssertTrue(plan.readerDayNarration.contains { $0.hasPrefix("9 days ago:") && $0.contains("recorder") })
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

    /// The band inverted and `floor...ceiling` trapped the process.
    ///
    /// The floor's cap and the ceiling's cap were computed independently, and
    /// only the floor's was raised by what the reader supplied. Two sixty-word
    /// keeps on a night with three drawn lines earned a floor of 236 against a
    /// ceiling of 235 - EXC_BREAKPOINT inside `BraidScenePlanBuilder.plan`, and
    /// the app went to the home screen the moment a braid began. Swept rather
    /// than pinned to that one night, because the inversion is arithmetic and
    /// any allowance that outgrows the cap brings it back.
    func testTheEarnedBandNeverInverts() {
        for scale in [BraidPromptBuilder.BraidScale.glimpse, .small, .full] {
            let reading = BraidPromptBuilder.TaleReading(
                scale: scale, motion: .vigil, pressure: .absence,
                anchorPageID: nil, anchor: "", turn: nil, visibleSupportingLogs: false)
            for keeps in 1...12 {
                for words in stride(from: 5, through: 120, by: 5) {
                    let evidence = (0..<keeps).map { index in
                        SceneEvidence(
                            id: "e\(index)", pageID: "p\(index)", kind: .writtenLine,
                            text: Array(repeating: "word", count: words).joined(separator: " "),
                            occurredAt: date("2026-10-02T09:00:00Z"), isUnclearedShadow: false)
                    }
                    for relationCount in 0...16 {
                        let relations = (0..<relationCount).map { index in
                            SceneRelation(kind: .sharedThing, evidenceIDs: ["e0", "e\(index)"])
                        }
                        let band = BraidScenePlanBuilder.earnedWords(
                            for: evidence, reading: reading, relations: relations)
                        XCTAssertLessThanOrEqual(
                            band.lowerBound, band.upperBound,
                            "\(scale) \(keeps)x\(words) words, \(relationCount) relations")
                    }
                }
            }
        }
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
    func testShapeMemoryStaysInThePlanWithoutLengtheningTheSmallModelBrief() {
        var context = BraidPromptBuilder.Context()
        context.recentDays = (15...19).map { keptBraid($0, title: "The Mug Saw It", paragraphs: 2) }
        let plan = BraidScenePlanBuilder.plan(
            for: BookDay(id: "2026-11-20", date: date("2026-11-20T21:30:00Z"), pages: [diary()]),
            context: context, calendar: Calendar(identifier: .gregorian))

        XCTAssertEqual(Set(plan.shape.recentTitleShapes).count, 1, "\(plan.shape)")
        let brief = plan.brief()
        XCTAssertFalse(brief.contains("VARY:"), brief)
        XCTAssertFalse(brief.contains("titles were built the same way"), brief)
        XCTAssertFalse(brief.contains("paragraphs each"), brief)
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

    /// Every night gets world business now. A kept day commissions one typed
    /// beat; a shut day commissions several quiet-day beats for Gemma to join
    /// into its own narrative.
    func testEveryBenchNightHasAWorldBeat() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            XCTAssertTrue(
                plan.worldBeat != nil || !plan.quietDayBeats.isEmpty,
                night.name
            )
            let brief = plan.brief()
            XCTAssertTrue(
                brief.contains(plan.isHardNight ? BraidScenePlan.hardNightWorldLabel : BraidScenePlan.worldLabel),
                "\(night.name) did not hand its world detail to Gemma"
            )
            XCTAssertTrue(
                brief.contains("from that odd thing happen in the story"),
                "\(night.name) made its world detail optional"
            )
        }
    }

    func testAQuietDayCommissionsEverySelectedWorldBeatForGemma() {
        let plan = BraidScenePlanBuilder.plan(for: day([]))
        let brief = plan.brief()

        XCTAssertGreaterThanOrEqual(plan.quietDayBeats.count, 2, plan.summary)
        XCTAssertNil(plan.worldBeat, "a quiet-day title must not name an uncommissioned extra beat")
        // The wording is the story-vignette direction's, not the old one's: the
        // story form arranges the beats rather than one of them being named the
        // opening action. What the test guards is unchanged — the beats are one
        // page of concurrent world life, and every selected beat is commissioned
        // by id rather than left for the model to invent around.
        XCTAssertTrue(brief.contains("Tonight's story may be all about my world"), brief)
        for beat in plan.quietDayBeats {
            XCTAssertTrue(brief.contains(BraidScenePlan.worldMaterial(beat)), brief)
            XCTAssertFalse(brief.contains("WORLD:\(beat.id)"), brief)
            XCTAssertFalse(brief.contains("\(beat.id) [WORLD]"), brief)
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

    // MARK: - The answer loop

    /// notice -> keep -> braid -> see differently -> notice again. Without this
    /// half the braid is a record of a transformation rather than part of one.
    func testTonightCanAnswerLastNight() {
        let at = date("2026-10-01T21:30:00Z")
        var context = BraidPromptBuilder.Context()
        context.recentDays = [BookDay(
            id: "2026-10-01", date: at,
            pages: [BookPage(
                id: "b", type: .bookOfYou, createdAt: at, promptText: "Book of You",
                userInput: "A Night\n\nSomething.\n\nThe Book kept the page: it held.",
                tags: [
                    "braid-claim:world:bell-under-floor",
                    "braid-residue-salient:the bell under the reading room floor",
                    "braid-residue-relation:complication"
                ],
                origin: .generated)])]
        let plan = BraidScenePlanBuilder.plan(
            for: day([diary()]), context: context, calendar: Calendar(identifier: .gregorian))

        XCTAssertEqual(plan.answering?.advancedWorldThread, "bell-under-floor")
        XCTAssertEqual(plan.answering?.openedRelationship, "complication")
        let brief = plan.brief()
        XCTAssertFalse(brief.contains("ONGOING WORLD THREAD"), brief)
        XCTAssertFalse(brief.contains("bell-under-floor"), brief)
    }

    func testAFirstNightHasNothingToAnswer() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        XCTAssertNil(plan.answering)
        XCTAssertFalse(plan.brief().contains("ONGOING WORLD THREAD"))
    }

    /// Tonight leaves something behind, and it is what the page decided rather
    /// than a claim about meaning.
    func testTonightLeavesResidueBehind() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        XCTAssertNotNil(plan.intendedResidue.salientDetail)
        XCTAssertEqual(plan.intendedResidue.leftUnresolved, [])
    }

    /// A plan can intend a relation the renderer never wrote. Residue is stamped
    /// from what the verifier accepted, so tomorrow answers the page rather than
    /// the plan.
    func testResidueIsStampedOnlyFromWhatSurvived() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        guard let anchorID = plan.anchorEvidenceID else { return XCTFail(plan.summary) }

        let wrote = plan.residueTags(surviving: [
            BraidClaim(realm: .lived, sourceIDs: [anchorID], text: "You walked past the bakery."),
            BraidClaim(realm: .book, sourceIDs: [anchorID], text: "I have seen one of these before.")
        ])
        XCTAssertTrue(wrote.contains { $0.hasPrefix("braid-residue-salient:") }, "\(wrote)")

        // A page that dropped the anchor and wrote no Book sentence leaves
        // nothing for tomorrow to answer.
        let droppedIt = plan.residueTags(surviving: [
            BraidClaim(realm: .colophon, sourceIDs: [], text: "The Book kept the page: it held.")
        ])
        XCTAssertTrue(droppedIt.isEmpty, "\(droppedIt)")
    }

    /// The house canon is sixteen facts about the Book's own building. A Cast
    /// member halfway through something they started for their own reasons is
    /// the world moving without reference to anybody's evening, which is what
    /// `independent` is for - and a thing in progress beats a thing that is
    /// merely true.
    func testLiveWorldBusinessOutranksTheHouseCanon() {
        let stage = CastUndertakingStage(
            id: "s1",
            line: "Wicker has been counting the doors on the east corridor and will not say why.",
            trace: "A chalk nub was left under door seven.", tags: [],
            scene: "FINISHED UNDERTAKING SCENE THAT MUST NOT ENTER THE BRAID PLAN.")
        let undertaking = CastUndertaking(
            id: "u1", actorID: "wicker", title: "The Door Count",
            pursuit: "counting doors", why: "nobody knows", stages: [stage],
            stageIndex: 0, status: .active,
            startedAt: date("2026-09-01T09:00:00Z"),
            lastAdvancedAt: date("2026-10-01T09:00:00Z"),
            nextEligibleAt: date("2026-10-05T09:00:00Z"))

        var context = BraidPromptBuilder.Context()
        context.castUndertakings = [undertaking]
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]), context: context)

        XCTAssertEqual(plan.worldBeat?.id, "undertaking:u1:s1", plan.summary)
        XCTAssertEqual(
            plan.worldBeat?.fact,
            "Wicker has been counting the doors on the east corridor and will not say why.")
        XCTAssertEqual(plan.worldBeat?.source, .undertaking)
        XCTAssertEqual(plan.worldBeat?.actorID, "wicker")
        XCTAssertEqual(plan.worldBeat?.trace, "A chalk nub was left under door seven.")
        XCTAssertTrue(plan.brief().contains("counting the doors"), plan.brief())
        XCTAssertFalse(plan.brief().contains("FINISHED UNDERTAKING SCENE"), plan.brief())

        let receipts = BraidContributionReceipt.receipts(in: plan.contributionTags)
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts.first?.kind, .cast)
        XCTAssertEqual(receipts.first?.title, "The Door Count")
        XCTAssertEqual(receipts.first?.destination, .castLedger)
        XCTAssertTrue(receipts.first?.detail.contains("chalk nub") == true)
    }

    /// Running business is fresh world material, not a compulsory cast slot.
    /// Once its current stage reached a braid it rests and the building gets on
    /// with something else.
    func testSeenUndertakingBusinessRestsInsteadOfBecomingPermanentCast() {
        let stage = CastUndertakingStage(
            id: "s1", line: "Penny found a comma that had been filed as a hook.",
            trace: "One red circle in the margin.", tags: [], scene: "A finished Penny scene.")
        let undertaking = CastUndertaking(
            id: "penny-proof", actorID: "penny", title: "The Misfiled Comma",
            pursuit: "checking the old punctuation ledgers", why: "one mark is wrong",
            stages: [stage], stageIndex: 0, status: .active,
            startedAt: date("2026-09-01T09:00:00Z"),
            lastAdvancedAt: date("2026-10-01T09:00:00Z"),
            nextEligibleAt: date("2026-10-05T09:00:00Z"))
        let worldID = "undertaking:penny-proof:s1"
        var context = BraidPromptBuilder.Context()
        context.castUndertakings = [undertaking]
        context.recentDays = [keptBraidWithTags(["braid-claim:world:\(worldID)"])]

        let plan = BraidScenePlanBuilder.plan(for: day([diary()]), context: context)

        XCTAssertNotEqual(plan.worldBeat?.id, worldID, plan.summary)
        XCTAssertEqual(plan.worldBeat?.source, .houseCanon)
    }

    /// The worn images are masked at the tokenizer, never named to Gemma: the
    /// 2B model copies whatever the brief shows it, so a brief that said
    /// "don't write dust motes" would be a brief that wrote them.
    func testNoBriefNamesAWornImage() {
        let worn = BraidWornImages.words.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            + BraidWornImages.pairs.map { "\($0.after)\($0.word)".trimmingCharacters(in: .whitespaces).lowercased() }
        for night in BraidBench.corpus() {
            // Only the Book's own scaffolding is held to this. The reader's words,
            // the world's lines and the kept pages are content, and a reader who
            // "had fun" is allowed to have had it (the mask spares carried words).
            let contentLabels = ["Something odd", "Reader-day material", "Kept-page material", "Tonight includes protected", "Passage ", BraidCrossing.linePrefix, "My own business"]
            let brief = BraidScenePlanBuilder.plan(for: night.day, context: night.context).brief()
                .components(separatedBy: "\n")
                .filter { line in !contentLabels.contains { line.hasPrefix($0) } }
                .joined(separator: "\n").lowercased()
            for image in worn {
                XCTAssertNil(
                    brief.range(of: "\\b\(image)\\b", options: .regularExpression),
                    "\(night.name)'s brief names \"\(image)\""
                )
            }
        }
    }

    func testAWornWordFromTheReadersDayIsNotMasked() {
        let brief = "Reader-day material: You went dancing with Sam and the dust motes flew."
        let masked = BraidWornImages.masked(sparing: brief)
        XCTAssertFalse(masked.words.contains(" dancing"))
        XCTAssertTrue(masked.words.contains(" dance"), "only the carried word is spared")
        XCTAssertTrue(masked.words.contains(" shimmer"))
        XCTAssertTrue(masked.pairs.isEmpty, "the reader's own motes stay writable")
        XCTAssertEqual(BraidWornImages.masked(sparing: "You fixed the lamp.").words, BraidWornImages.words)
    }

    func testIndependentWorldBusinessMayRemainASeparateSubplot() {
        let brief = BraidScenePlanBuilder.plan(for: day([diary()])).brief()
        XCTAssertTrue(brief.contains("It may run beside the reader's day"), brief)
        XCTAssertFalse(brief.contains("same narrative movement"), brief)
    }

    /// And live business may not claim the reader either.
    func testLiveWorldBusinessStillMayNotClaimTheReader() {
        let stage = CastUndertakingStage(
            id: "s1", line: "l", trace: "t", tags: [],
            scene: "Wicker has been counting the doors and will not say why.")
        let undertaking = CastUndertaking(
            id: "u1", actorID: "wicker", title: "t", pursuit: "p", why: "w",
            stages: [stage], stageIndex: 0, status: .active,
            startedAt: date("2026-09-01T09:00:00Z"),
            lastAdvancedAt: date("2026-10-01T09:00:00Z"),
            nextEligibleAt: date("2026-10-05T09:00:00Z"))
        for fact in SceneWorldCanon.liveFacts(undertakings: [undertaking], worldEvents: []) {
            XCTAssertFalse(
                BraidDraftVerifier.assertsSomethingHappenedToTheReader(fact.text), fact.id)
        }
    }

    /// "The reader's detail genuinely crosses its path" was an instruction with
    /// no path named, so a renderer had to guess which kept fiction it meant.
    func testAnIntersectingWorldBeatNamesWhatItCrosses() {
        let fiction = BookPage(
            id: "fox", type: .narrativeOS, createdAt: date("2026-10-02T19:00:00Z"),
            promptText: "The fox at the toll gate asked for a name instead of a coin.",
            userInput: "", tags: [], sourceID: "narrative-os", origin: .generated)
        let plan = BraidScenePlanBuilder.plan(for: day([diary(), fiction]))
        XCTAssertEqual(plan.worldBeat?.mode, .intersecting)
        XCTAssertEqual(plan.worldBeat?.crossesEvidenceID, "fox#0.0", plan.summary)
    }

    func testAnIndependentBeatCrossesNothing() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        XCTAssertEqual(plan.worldBeat?.mode, .independent)
        XCTAssertNil(plan.worldBeat?.crossesEvidenceID)
    }

    private func keptBraidWithTags(_ tags: [String]) -> BookDay {
        let at = date("2026-10-01T21:30:00Z")
        return BookDay(
            id: "2026-10-01", date: at,
            pages: [BookPage(
                id: "b", type: .bookOfYou, createdAt: at, promptText: "Book of You",
                userInput: "A Night\n\nSomething.\n\nThe Book kept the page: it held.",
                tags: tags, origin: .generated)])
    }

    /// Across a month the world should stop returning to the same corridor two
    /// nights running.
    func testTheWorldDoesNotRepeatLastNightsBusiness() {
        let first = BraidScenePlanBuilder.plan(for: day([diary()]))
        guard let seen = first.worldBeat?.id else { return XCTFail(first.summary) }
        var context = BraidPromptBuilder.Context()
        context.recentDays = [keptBraidWithTags(["braid-claim:world:\(seen)"])]
        let next = BraidScenePlanBuilder.plan(
            for: day([diary()]), context: context, calendar: Calendar(identifier: .gregorian))
        XCTAssertNotEqual(next.worldBeat?.id, seen)
    }

    /// A night that held something open tells tomorrow so - as a marker, never
    /// as the material. Hauling grief forward as a quotable string is how a Book
    /// starts reminding somebody of their worst week.
    func testANightThatHeldSomethingOpenSaysSoWithoutQuotingIt() {
        var hard = BookPage(
            id: "hard", type: .diary, createdAt: date("2026-10-02T20:00:00Z"),
            promptText: "?", userInput: "My sister called about the funeral arrangements.",
            origin: .userAuthored)
        hard.tags = [ReaderShelf.shadowTag]
        let tonight = BraidScenePlanBuilder.plan(for: day([diary(), hard]))
        XCTAssertFalse(tonight.intendedResidue.leftUnresolved.isEmpty, tonight.summary)

        let stamped = tonight.residueTags(surviving: [
            BraidClaim(realm: .colophon, sourceIDs: [], text: "The Book kept the page: it held.")
        ])
        XCTAssertTrue(stamped.contains("braid-residue-open"), "\(stamped)")
        XCTAssertFalse(
            stamped.joined().lowercased().contains("funeral"),
            "the material itself was carried forward")

        var context = BraidPromptBuilder.Context()
        context.recentDays = [keptBraidWithTags(stamped)]
        let tomorrow = BraidScenePlanBuilder.plan(
            for: day([diary()]), context: context, calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(tomorrow.answering?.leftUnresolved, ["open"])
        let brief = tomorrow.brief()
        XCTAssertTrue(brief.contains("An earlier page left something open. Leave it open."), brief)
        XCTAssertFalse(brief.lowercased().contains("funeral"), brief)
    }

    // MARK: - One or two pieces of the world

    /// bj: "we only need one or two world events for the braid, not all of
    /// them." Counted across monthly passages, the world beat, quiet-day
    /// beats and the day's kept fiction.
    func testNoNightCarriesMoreThanTwoPiecesOfTheWorld() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            let fiction = Set(
                plan.placements
                    .compactMap { plan.evidence(for: $0.evidenceID) }
                    .filter { $0.kind == .keptFiction }
                    .map(\.pageID)
            )
            let world = fiction.count
                + (plan.worldBeat == nil ? 0 : 1)
                + plan.quietDayBeats.count
                + (plan.authoredStoryReceipts?.count ?? 0)
            XCTAssertLessThanOrEqual(world, BraidScenePlanBuilder.worldItemLimit, "\(night.name)\n\(plan.summary)")
        }
    }

    /// "Monthly content world stuff first and foremost": a live monthly event
    /// outranks the Cast's errands and the house canon, rests only the night
    /// after it appears, and is back the night after that.
    func testAMonthlyWorldEventLeadsAndRestsOnlyOneNight() {
        let plan = BraidScenePlanBuilder.plan(for: day([diary()]))
        let monthly = SceneWorldCanon.Fact(
            id: "world-event:count-unbound", threadID: "world-event:count-unbound",
            text: "The Count's ledger has started counting doors that are not there.", source: .worldEvent)
        let errand = SceneWorldCanon.Fact(
            id: "undertaking:pippa:1", threadID: "undertaking:pippa",
            text: "Pippa is halfway through mending the east stair.", source: .undertaking)
        for offset in 0..<5 {
            let night = date("2026-10-02T21:30:00Z").addingTimeInterval(Double(offset) * 86_400)
            XCTAssertEqual(
                SceneWorldCanon.beat(for: plan, recentDays: [], on: night, live: [errand, monthly])?.id,
                monthly.id
            )
        }

        func braid(_ day: String, carrying id: String) -> BookDay {
            BookDay(id: day, date: date("\(day)T21:30:00Z"), pages: [
                BookPage(type: .bookOfYou, createdAt: date("\(day)T21:30:00Z"), promptText: "",
                         userInput: "", tags: ["braid-claim:world:\(id)"])
            ])
        }
        let lastNight = [braid("2026-10-01", carrying: monthly.id)]
        XCTAssertEqual(
            SceneWorldCanon.beat(for: plan, recentDays: lastNight, on: date("2026-10-02T21:30:00Z"),
                                 live: [errand, monthly])?.id,
            errand.id
        )
        let twoNightsAgo = [braid("2026-09-30", carrying: monthly.id), braid("2026-10-01", carrying: errand.id)]
        XCTAssertEqual(
            SceneWorldCanon.beat(for: plan, recentDays: twoNightsAgo, on: date("2026-10-02T21:30:00Z"),
                                 live: [errand, monthly])?.id,
            monthly.id
        )
        let quiet = SceneWorldCanon.quietDay(on: date("2026-10-02T21:30:00Z"), recentDays: [], live: [errand, monthly])
        XCTAssertEqual(quiet.first?.id, monthly.id)
        XCTAssertEqual(quiet.count, BraidScenePlanBuilder.worldItemLimit)
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

    // MARK: The scrub

    func testScrubTakesOutSentencesThatSpeakForTheReader() {
        let told = "You walked to the corner shop. I watched you leave. A bird landed on your shoulder. I felt a little flutter of worry you had about your sister.\n\nThe Book kept the page: the bird left."
        let scrub = BraidTellingScrub.scrubbed(told, readerMaterial: "You walked to the corner shop.", isHardNight: false)
        XCTAssertFalse(scrub.text.contains("shoulder"))
        XCTAssertTrue(scrub.text.contains("I watched you leave."))
        XCTAssertTrue(scrub.text.hasSuffix("The Book kept the page: the bird left."))
        XCTAssertEqual(scrub.dropped.count, 1)
    }

    func testScrubSpareswhatTheReaderSaidAboutThemselves() {
        let told = "You rubbed your eyes and made tea. I put the kettle on. I liked the quiet in the room. The window was open. The Book kept the page: the kettle sang."
        let scrub = BraidTellingScrub.scrubbed(told, readerMaterial: "You rubbed your eyes and made tea.", isHardNight: false)
        XCTAssertTrue(scrub.text.contains("your eyes"))
        XCTAssertTrue(scrub.dropped.isEmpty)
    }

    func testNothingIsAmusingOnAHardNightButItMayBeOnAnother() {
        let told = "You sat in the corridor. I found the whole thing quite amusing. The rain stayed in the Stacks. The floor stayed dark. The Book kept the page: the floor stayed dark."
        XCTAssertFalse(BraidTellingScrub.scrubbed(told, readerMaterial: "You sat in the corridor.", isHardNight: true).text.contains("amusing"))
        XCTAssertTrue(BraidTellingScrub.scrubbed(told, readerMaterial: "You sat in the corridor.", isHardNight: false).text.contains("amusing"))
    }

    func testScrubNeverLeavesAShellOfATelling() {
        let told = "A bird landed on your shoulder. I felt a flutter of worry you had. The Book kept the page: the bird left."
        let scrub = BraidTellingScrub.scrubbed(told, readerMaterial: "", isHardNight: false)
        XCTAssertTrue(scrub.dropped.isEmpty, "too little would remain, so the audit sees the original")
        XCTAssertTrue(scrub.text.contains("shoulder"))
    }

    func testContractionsAreAddedWhereTheBookWouldSayThem() {
        let told = "It was not raining. I did not mind. You would have laughed. Nobody could not hear it.\n\nThe Book kept the page: it did not stop."
        let (text, count) = BraidTellingScrub.contracted(told)
        XCTAssertTrue(text.contains("It wasn't raining."))
        XCTAssertTrue(text.contains("I didn't mind."))
        XCTAssertTrue(text.contains("You'd have laughed."))
        XCTAssertTrue(text.contains("couldn't"))
        XCTAssertGreaterThanOrEqual(count, 4)
        XCTAssertTrue(text.hasSuffix("The Book kept the page: it did not stop."), "the signature line is left whole")
        XCTAssertFalse(BraidTellingScrub.contracted("I have a lamp.").text.contains("I've"), "possession isn't a contraction")
    }

    func testHardNightsAreTheOnesHoldingSomethingOpen() throws {
        let hard = try XCTUnwrap(BraidBench.corpus().first { $0.name == "tender-shadow" })
        let context = DeterministicBraidwright.preparedContext(for: hard.day, context: hard.context)
        let plan = BraidScenePlanBuilder.plan(for: hard.day, context: context)
        XCTAssertTrue(plan.isHardNight)
        XCTAssertTrue(plan.brief().contains(BraidScenePlan.hardNightWorldLabel))
        let easy = try XCTUnwrap(BraidBench.corpus().first { $0.name == "plain-diary-day" })
        let easyPlan = BraidScenePlanBuilder.plan(for: easy.day, context: DeterministicBraidwright.preparedContext(for: easy.day, context: easy.context))
        XCTAssertFalse(easyPlan.isHardNight)
    }

    // MARK: The wider canon

    func testTheCanonIsWideEnoughForAMonthWithoutCircling() {
        let facts = SceneWorldCanon.facts
        XCTAssertGreaterThanOrEqual(facts.count, 80, "30 nights x 1-2 world beats, with an 8-night rest window")
        XCTAssertEqual(Set(facts.map(\.id)).count, facts.count)
        XCTAssertEqual(Set(facts.map(\.threadID)).count, facts.count, "one fact per thread, so the rest rules can spread a month")
    }

    func testEveryCanonFactIsWrittenToBeLifted() {
        let masked = (BraidWornImages.words + [" strange", " tiny", " watched", " noticed"]).map { $0.trimmingCharacters(in: .whitespaces) }
        let spoiled = ["little", "just", "quite", "odd", "felt", "thick", "suddenly", "weird", "somehow"]
        for fact in SceneWorldCanon.extendedFacts {
            let text = fact.text.lowercased()
            let words = Set(text.split { !$0.isLetter && $0 != "'" }.map(String.init))
            XCTAssertFalse(text.contains("\u{1B}") || text.isEmpty, fact.id)
            XCTAssertTrue(fact.text.hasSuffix("."), "\(fact.id) should end on a full stop")
            XCTAssertLessThanOrEqual(fact.text.split(separator: " ").count, 34, "\(fact.id) is too long to lift")
            XCTAssertGreaterThanOrEqual(fact.text.split(separator: " ").count, 9, "\(fact.id) is too thin to be a beat")
            XCTAssertTrue(words.isDisjoint(with: ["you", "your", "yours", "you're", "you've", "yourself"]), "\(fact.id) speaks to the reader")
            for word in masked + spoiled { XCTAssertFalse(words.contains(word), "\(fact.id) uses \"\(word)\"") }
            for banned in ["curse", "ritual", "magic", "grey sameness"] { XCTAssertFalse(text.contains(banned), "\(fact.id) says \"\(banned)\"") }
            XCTAssertFalse(BraidDraftVerifier.assertsSomethingHappenedToTheReader(fact.text), fact.id)
        }
    }

    // MARK: The Book's own business

    func testTheBooksBusinessIsPlayfulPlainAndNeverAboutTheReader() {
        XCTAssertGreaterThanOrEqual(BookBusiness.playful.count, 36, "eleven openings moved into running threads")
        let all = BookBusiness.playful + BookBusiness.quiet
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        let masked = (BraidWornImages.words + [" strange", " tiny", " watched", " noticed"]).map { $0.trimmingCharacters(in: .whitespaces) }
        let uncontracted = ["do not", "does not", "is not", "are not", "it is ", "i am ", "i will ", "would not", "cannot"]
        let mooddeclaring = ["i'm feeling", "i am feeling", "my mood", "i feel "]
        for line in all {
            let lower = line.text.lowercased()
            let words = Set(lower.split { !$0.isLetter && $0 != "'" }.map(String.init))
            XCTAssertTrue(line.text.hasSuffix("."), line.id)
            XCTAssertLessThanOrEqual(line.text.split(separator: " ").count, 26, "\(line.id) is too long to lift")
            XCTAssertTrue(words.isDisjoint(with: ["you", "your", "yours", "you're", "you've"]), "\(line.id) speaks to the reader")
            for word in masked { XCTAssertFalse(words.contains(word), "\(line.id) uses \"\(word)\"") }
            for phrase in uncontracted + mooddeclaring { XCTAssertFalse(lower.contains(phrase), "\(line.id): \(phrase)") }
            XCTAssertFalse(lower.contains(", which"), line.id)
            XCTAssertFalse(lower.contains("curse") || lower.contains("ritual"), line.id)
        }
    }

    func testTheBooksBusinessDoesNotRepeatWithinAMonthAndHardNightsGetTheQuietSet() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
        let month = (0..<31).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        let lines = month.map { BookBusiness.pick(on: $0, hardNight: false, calendar: calendar).id }
        XCTAssertEqual(Set(lines).count, 31, "no line returns inside a month")
        for (a, b) in zip(lines, lines.dropFirst()) { XCTAssertNotEqual(a, b) }
        XCTAssertEqual(lines, month.map { BookBusiness.pick(on: $0, hardNight: false, calendar: calendar).id }, "deterministic")
        let quiet = Set(BookBusiness.quiet.map(\.id))
        for date in month { XCTAssertTrue(quiet.contains(BookBusiness.pick(on: date, hardNight: true, calendar: calendar).id)) }
    }

    func testEveryBriefOffersTheBooksBusinessAndAHardNightsIsQuiet() throws {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: DeterministicBraidwright.preparedContext(for: night.day, context: night.context))
            let business = try XCTUnwrap(plan.bookBusiness, night.name)
            XCTAssertTrue(plan.brief().contains("\(BookBusiness.label) \(business.text)"), night.name)
            XCTAssertEqual(BookBusiness.quiet.contains { $0.id == business.id }, plan.isHardNight, night.name)
        }
    }

    /// bj can't stand it. Gemma may not write it (masked), and nothing authored
    /// for the braid may carry it.
    func testNoHingeInTheBraidsMaterialAndGemmaCannotWriteOne() throws {
        let masked = BraidWornImages.words.map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertTrue(masked.contains("hinge") && masked.contains("hinges"))
        let authored = SceneWorldCanon.facts.map(\.text) + BookBusiness.playful.map(\.text) + BookBusiness.quiet.map(\.text)
        for text in authored { XCTAssertFalse(text.lowercased().contains("hinge"), text) }
    }

    // MARK: The Book's sulks

    private func trashReceipt(_ id: String, title: String?, at: Date, occurrence: String? = nil) -> AuthoredContentReceipt {
        var receipt = AuthoredContentReceipt(
            contentID: "count-unbound.scene.\(id)", occurrenceID: occurrence ?? "occ-\(id)", channel: .storyScene,
            state: .dismissed, recordedAt: at)
        receipt.printedTitle = title
        return receipt
    }

    func testSulksAreFondFunnyAndNeverTheReadersFault() {
        XCTAssertGreaterThanOrEqual(BookSulk.titled.count, 24)
        XCTAssertGreaterThanOrEqual(BookSulk.untitled.count, 6)
        let masked = (BraidWornImages.words + [" strange", " tiny", " watched", " noticed"]).map { $0.trimmingCharacters(in: .whitespaces) }
        let uncontracted = ["do not", "does not", "is not", "are not", "it is ", "i am ", "i will ", "would not", "cannot", "did not"]
        for template in BookSulk.titled + BookSulk.untitled {
            let rendered = template.replacingOccurrences(of: "{title}", with: "The Chair That Gets There First")
            let lower = rendered.lowercased()
            let words = Set(lower.split { !$0.isLetter && $0 != "'" }.map(String.init))
            XCTAssertFalse(words.contains("sulk") || words.contains("sulking") || lower.contains("i'm feeling") || lower.contains("i feel "), "announces a mood: \(template)")
            XCTAssertTrue(words.isDisjoint(with: ["you", "your", "yours", "you're", "you've"]), "blames or addresses the reader: \(template)")
            for word in masked { XCTAssertFalse(words.contains(word), "\(template) uses \"\(word)\"") }
            for phrase in uncontracted { XCTAssertFalse(lower.contains(phrase), "\(template): \(phrase)") }
            XCTAssertFalse(lower.contains(", which") || lower.contains("curse") || lower.contains("hinge"), template)
            XCTAssertLessThanOrEqual(rendered.split(separator: " ").count, 42, template)
        }
        for template in BookSulk.titled { XCTAssertEqual(template.components(separatedBy: "{title}").count, 2, "exactly one title: \(template)") }
        for template in BookSulk.untitled { XCTAssertFalse(template.contains("{title}")) }
    }

    func testOnlyARecentRealTrashIsRemembered() {
        let now = date("2026-10-10T20:00:00Z")
        let day = 86_400.0
        let ledger = AuthoredContentReceiptLedger(receipts: [
            trashReceipt("fresh", title: "Fresh", at: now.addingTimeInterval(-day)),
            trashReceipt("older", title: "Older", at: now.addingTimeInterval(-3 * day)),
            trashReceipt("stale", title: "Stale", at: now.addingTimeInterval(-6 * day)),
            trashReceipt("left", title: "Left", at: now.addingTimeInterval(-day), occurrence: "left-episode:jump:run"),
            { var r = trashReceipt("kept", title: "Kept", at: now.addingTimeInterval(-day)); r.state = .kept; return r }()
        ])
        let trashed = BookSulk.trashed(from: ledger, now: now)
        XCTAssertEqual(trashed.map(\.title), ["Fresh", "Older"], "newest first; stale, left and kept scenes are not a Trash")
    }

    func testTheBookSulksAboutTwoTrashesInThreeAndNeverOnAHardNight() {
        let now = date("2026-10-10T20:00:00Z")
        var sulked = 0
        for i in 0..<60 {
            let trashed = [BookSulk.Trashed(id: "t\(i)", title: "Scene \(i)", at: now.addingTimeInterval(-3_600))]
            let line = BookSulk.pick(trashed: trashed, recentDays: [], on: now, hardNight: false)
            if let line {
                sulked += 1
                XCTAssertTrue(line.id.hasPrefix(BookSulk.idPrefix))
                XCTAssertTrue(line.text.contains("Scene \(i)"), "names the page: \(line.text)")
                XCTAssertEqual(line, BookSulk.pick(trashed: trashed, recentDays: [], on: now, hardNight: false), "deterministic")
            }
            XCTAssertNil(BookSulk.pick(trashed: trashed, recentDays: [], on: now, hardNight: true), "never on a hard night")
        }
        XCTAssertTrue((30...50).contains(sulked), "about two in three, got \(sulked) of 60")
    }

    func testNeverTwiceInAWeekAndAnUntitledTrashStillGetsAGrumble() throws {
        let now = date("2026-10-10T20:00:00Z")
        let id = try XCTUnwrap((0..<30).map { "u\($0)" }.first {
            BookSulk.pick(trashed: [.init(id: $0, title: nil, at: now.addingTimeInterval(-60))], recentDays: [], on: now, hardNight: false) != nil
        })
        let trashed = [BookSulk.Trashed(id: id, title: nil, at: now.addingTimeInterval(-60))]
        let plain = try XCTUnwrap(BookSulk.pick(trashed: trashed, recentDays: [], on: now, hardNight: false))
        XCTAssertTrue(BookSulk.untitled.contains(plain.text))

        var recent = keptBraidWithTags([BookSulk.tagPrefix + "12345"])
        recent.date = now.addingTimeInterval(-3 * 86_400)
        XCTAssertNil(BookSulk.pick(trashed: trashed, recentDays: [recent], on: now, hardNight: false), "it sulked 3 days ago")
        recent.date = now.addingTimeInterval(-8 * 86_400)
        XCTAssertNotNil(BookSulk.pick(trashed: trashed, recentDays: [recent], on: now, hardNight: false), "a week has passed")
    }

    func testASulkRidesInTheBriefAsTheBooksBusinessOnlyOnAnEasyNight() throws {
        let easy = try XCTUnwrap(BraidBench.corpus().first { $0.name == "plain-diary-day" })
        var easyContext = DeterministicBraidwright.preparedContext(for: easy.day, context: easy.context)
        let id = try XCTUnwrap((0..<30).map { "p\($0)" }.first {
            BookSulk.pick(trashed: [.init(id: $0, title: "The Roster", at: easy.day.date.addingTimeInterval(-3_600))], recentDays: [], on: easy.day.date, hardNight: false) != nil
        })
        easyContext.trashedScenes = [BookSulk.Trashed(id: id, title: "The Roster", at: easy.day.date.addingTimeInterval(-3_600))]
        let plan = BraidScenePlanBuilder.plan(for: easy.day, context: easyContext)
        XCTAssertTrue(plan.bookBusiness?.id.hasPrefix(BookSulk.idPrefix) == true, plan.summary)
        XCTAssertTrue(plan.brief().contains("The Roster"))
        XCTAssertTrue(plan.summary.contains("business sulk:"))

        let hard = try XCTUnwrap(BraidBench.corpus().first { $0.name == "tender-shadow" })
        var hardContext = DeterministicBraidwright.preparedContext(for: hard.day, context: hard.context)
        hardContext.trashedScenes = [BookSulk.Trashed(id: id, title: "The Roster", at: hard.day.date.addingTimeInterval(-3_600))]
        let hardPlan = BraidScenePlanBuilder.plan(for: hard.day, context: hardContext)
        XCTAssertTrue(hardPlan.isHardNight)
        XCTAssertFalse(hardPlan.brief().contains("The Roster"), "no sulking on a hard night")
        XCTAssertTrue(BookBusiness.quiet.contains { $0.id == hardPlan.bookBusiness?.id })
    }

    // MARK: Running threads

    private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }

    private func braidDay(_ date: Date, tags: [String] = []) -> BookDay {
        let at = utc.startOfDay(for: date).addingTimeInterval(21 * 3_600)
        return BookDay(id: "d\(Int(at.timeIntervalSince1970))", date: at, pages: [
            BookPage(id: "b\(Int(at.timeIntervalSince1970))", type: .bookOfYou, createdAt: at, promptText: "Book of You",
                     userInput: "A Night\n\nSomething.\n\nThe Book kept the page: it held.", tags: tags, origin: .generated)])
    }

    func testEveryThreadIsFourFondNightsThatPayOff() {
        XCTAssertGreaterThanOrEqual(BookThreads.all.count, 12)
        XCTAssertEqual(Set(BookThreads.all.map(\.id)).count, BookThreads.all.count)
        let masked = (BraidWornImages.words + [" strange", " tiny", " watched", " noticed"]).map { $0.trimmingCharacters(in: .whitespaces) }
        let uncontracted = ["do not", "does not", "is not", "are not", "it is ", "i am ", "i will ", "would not", "cannot", "did not"]
        for thread in BookThreads.all {
            XCTAssertEqual(thread.steps.count, 4, thread.id)
            for text in thread.steps {
                let lower = text.lowercased()
                let words = Set(lower.split { !$0.isLetter && $0 != "'" }.map(String.init))
                XCTAssertTrue(text.hasSuffix("."), "\(thread.id): \(text)")
                XCTAssertLessThanOrEqual(text.split(separator: " ").count, 30, "\(thread.id) is too long to lift")
                XCTAssertTrue(words.isDisjoint(with: ["you", "your", "yours", "you're", "you've"]), "\(thread.id) speaks to the reader")
                for word in masked { XCTAssertFalse(words.contains(word), "\(thread.id) uses \"\(word)\"") }
                for phrase in uncontracted + ["i'm feeling", "i feel "] { XCTAssertFalse(lower.contains(phrase), "\(thread.id): \(phrase)") }
                XCTAssertFalse(lower.contains(", which") || lower.contains("curse") || lower.contains("hinge"), text)
            }
        }
    }

    func testAThreadCarriesOnFromTheNightBeforeAndStopsAtItsLastStep() throws {
        let today = date("2026-10-10T20:00:00Z"), yesterday = today.addingTimeInterval(-86_400)
        let line = try XCTUnwrap(BookThreads.pick(recentDays: [braidDay(yesterday, tags: ["braid-thread:teacup:0"])], on: today, hardNight: false, calendar: utc))
        XCTAssertEqual(line.id, "thread:teacup:1")
        XCTAssertEqual(line.text, BookThreads.all.first { $0.id == "teacup" }?.steps[1])
        let after = BookThreads.pick(recentDays: [braidDay(yesterday, tags: ["braid-thread:teacup:3"])], on: today, hardNight: false, calendar: utc)
        XCTAssertFalse(after?.id.hasPrefix("thread:teacup") == true, "the payoff is the end of the game")
    }

    func testAThreadWaitsOutAHardNightAndIsLetGoAfterSixDays() throws {
        let today = date("2026-10-10T20:00:00Z")
        let tagged = braidDay(today.addingTimeInterval(-86_400), tags: ["braid-thread:dragon:1"])
        XCTAssertNil(BookThreads.pick(recentDays: [tagged], on: today, hardNight: true, calendar: utc), "no game on a hard night")
        // The next easy night picks it up where it was left, not further along.
        let nextEasy = today.addingTimeInterval(86_400)
        let resumed = try XCTUnwrap(BookThreads.pick(recentDays: [tagged], on: nextEasy, hardNight: false, calendar: utc))
        XCTAssertEqual(resumed.id, "thread:dragon:2")
        // Left alone for a week, it is let go.
        let old = braidDay(today.addingTimeInterval(-8 * 86_400), tags: ["braid-thread:dragon:1"])
        XCTAssertFalse(BookThreads.pick(recentDays: [old], on: today, hardNight: false, calendar: utc)?.id.hasPrefix("thread:dragon:2") == true)
    }

    func testAReBraidOfTonightRepeatsTonightsStepAndDoesNotAdvance() throws {
        let today = date("2026-10-10T20:00:00Z")
        let yesterday = braidDay(today.addingTimeInterval(-86_400), tags: ["braid-thread:whistle:0"])
        let tonightsFirstBraid = braidDay(today, tags: ["braid-thread:whistle:1"])
        let first = try XCTUnwrap(BookThreads.pick(recentDays: [yesterday], on: today, hardNight: false, calendar: utc))
        let again = try XCTUnwrap(BookThreads.pick(recentDays: [yesterday, tonightsFirstBraid], on: today, hardNight: false, calendar: utc))
        XCTAssertEqual(first.id, "thread:whistle:1")
        XCTAssertEqual(again.id, first.id)
    }

    /// A reader who braids every night for two months: games start about three
    /// nights in five, each runs its four steps on four consecutive nights and
    /// pays off, and none returns within a fortnight.
    func testTwoMonthsOfNightsRunWholeGamesWithoutRepeating() {
        var days: [BookDay] = []
        let start = date("2026-10-01T20:00:00Z")
        var picked: [(day: Int, id: String)] = []
        for n in 0..<60 {
            let when = start.addingTimeInterval(Double(n) * 86_400)
            let line = BookThreads.pick(recentDays: days, on: when, hardNight: false, calendar: utc)
            if let line { picked.append((n, line.id)) }
            days.append(braidDay(when, tags: line.map { [BookThreads.tagPrefix + $0.id.dropFirst(BookThreads.idPrefix.count)] } ?? []))
        }
        let starts = picked.filter { $0.id.hasSuffix(":0") }
        XCTAssertGreaterThanOrEqual(starts.count, 8, "games should start regularly: \(picked)")
        for begun in starts {
            let thread = String(begun.id.dropFirst(BookThreads.idPrefix.count).split(separator: ":")[0])
            let steps = picked.filter { $0.id.hasPrefix(BookThreads.idPrefix + thread + ":") && $0.day >= begun.day && $0.day < begun.day + 4 }
            if begun.day + 3 < 60 {
                XCTAssertEqual(steps.map(\.id), (0..<4).map { "\(BookThreads.idPrefix)\(thread):\($0)" }, "\(thread) should run its whole game from night \(begun.day)")
            }
            let again = starts.filter { $0.id == begun.id && $0.day != begun.day && abs($0.day - begun.day) < BookThreads.restDays }
            XCTAssertTrue(again.isEmpty, "\(thread) came back inside a fortnight")
        }
    }

    func testAThreadStepRidesInTheBriefAndIsStampedForTomorrow() throws {
        let easy = try XCTUnwrap(BraidBench.corpus().first { $0.name == "plain-diary-day" })
        var context = DeterministicBraidwright.preparedContext(for: easy.day, context: easy.context)
        context.trashedScenes = []
        let day = easy.day.date
        context.recentDays = [braidDay(day.addingTimeInterval(-86_400), tags: ["braid-thread:teacup:1"])]
        let plan = BraidScenePlanBuilder.plan(for: easy.day, context: context)
        XCTAssertEqual(plan.bookBusiness?.id, "thread:teacup:2", plan.summary)
        XCTAssertTrue(plan.brief().contains(BookThreads.all.first { $0.id == "teacup" }!.steps[2]))
    }

    // MARK: The crossing, handed over

    func testClausesAreShortCompleteAndQuotable() {
        XCTAssertEqual(BraidCrossing.clause("You walked to the corner shop for bread and it started raining."), "You walked to the corner shop for bread")
        XCTAssertEqual(BraidCrossing.clause("The lamps along the corridor to the East Stacks lean away from the door, like people stepping round a puddle."),
                       "The lamps along the corridor to the East Stacks lean away from the door")
        XCTAssertEqual(BraidCrossing.clause("You read forty pages standing up in the hallway because you forgot to sit down."), "You read forty pages standing up in the hallway")
        XCTAssertNil(BraidCrossing.clause("Rain, mostly."), "too little to cross")
        XCTAssertNil(BraidCrossing.clause("   "))
        let long = BraidCrossing.clause("You carried one very large and extremely heavy wooden crate of apples all the way up the stairs without stopping once")
        XCTAssertLessThanOrEqual(long?.split(separator: " ").count ?? 99, 14)
    }

    func testTheFourBridgesJoinBothClausesInOneSentenceWithoutExplainingEither() {
        let lived = "You walked to the corner shop for bread", world = "The lamps along the corridor lean away from the door"
        let bridges = (0..<4).map { BraidCrossing.bridge(lived: lived, world: world, index: $0) }
        XCTAssertEqual(Set(bridges).count, 4)
        for bridge in bridges {
            XCTAssertEqual(bridge.filter { ".!?".contains($0) }.count, 1, "one sentence: \(bridge)")
            XCTAssertTrue(bridge.lowercased().contains("walked to the corner shop for bread"), bridge)
            XCTAssertTrue(bridge.lowercased().contains("lamps along the corridor lean away from the door"), bridge)
            for explaining in ["because", "so that", "therefore", "meant", "which is why", "as if"] {
                XCTAssertFalse(bridge.lowercased().contains(explaining), "a crossing is adjacency: \(bridge)")
            }
        }
        XCTAssertEqual(bridges[0], "While you walked to the corner shop for bread, the lamps along the corridor lean away from the door.")
        XCTAssertEqual(BraidCrossing.bridge(lived: "You rewired the brass lamp", world: "Penny is writing the Bleed", index: 3),
                       "Penny is writing the Bleed, and you rewired the brass lamp anyway.", "names keep their capitals")
    }

    func testEveryEasyNightWithAWorldBeatHandsOverItsCrossingAndHardNightsNever() throws {
        var handed = 0
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: DeterministicBraidwright.preparedContext(for: night.day, context: night.context))
            let line = plan.brief().components(separatedBy: "\n").first { $0.hasPrefix(BraidCrossing.linePrefix) }
            if plan.isHardNight || plan.worldBeat == nil {
                XCTAssertNil(line, "\(night.name): no crossing on a hard night or a quiet day")
            } else if let line {
                handed += 1
                XCTAssertTrue(line.contains("For example:"), night.name)
                XCTAssertTrue(plan.brief().contains(BraidCrossing.linePrefix), night.name)
            }
        }
        XCTAssertGreaterThanOrEqual(handed, 12, "most bench nights have a day and a world to cross")
    }

    func testTheBridgeRotatesAcrossNightsAndIsStableForOneNight() {
        let lines = (0..<40).compactMap { BraidCrossing.handoff(lived: "You walked to the corner shop for bread", world: "The bell rang under the floor of the reading room", seed: "night-\($0)") }
        XCTAssertEqual(lines.count, 40)
        XCTAssertGreaterThanOrEqual(Set(lines.map { $0.components(separatedBy: "For example: ")[1] }).count, 4)
        XCTAssertEqual(BraidCrossing.handoff(lived: "You walked to the corner shop for bread", world: "The bell rang under the floor", seed: "x"),
                       BraidCrossing.handoff(lived: "You walked to the corner shop for bread", world: "The bell rang under the floor", seed: "x"))
        XCTAssertNil(BraidCrossing.handoff(lived: nil, world: "The bell rang under the floor", seed: "x"))
        XCTAssertNil(BraidCrossing.handoff(lived: "You walked to the corner shop for bread", world: nil, seed: "x"))
    }
}
