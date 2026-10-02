import XCTest
@testable import InsideCoverCore

final class RuinPromptsTests: XCTestCase {
    func testLibraryIsLargeUniqueAndCoversEveryKind() {
        let all = RuinLibrary.prompts
        XCTAssertGreaterThanOrEqual(all.count, 40)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ids are unique")
        XCTAssertEqual(Set(all.map(\.kind)), Set(RuinKind.allCases), "every kind has a prompt")
        XCTAssertTrue(RuinLibrary.gentle.allSatisfy { $0.kind.isGentle })
        XCTAssertTrue(RuinLibrary.rough.allSatisfy { !$0.kind.isGentle })
    }

    /// The guards: no fire, nothing that soaks a binding, nothing for children.
    func testCorePromptsPassTheGuards() {
        for prompt in RuinLibrary.prompts {
            XCTAssertEqual(RuinGuards.violations(in: prompt), [], prompt.id)
        }
    }

    func testPacksCannotSmuggleInAnythingTheGuardsRefuse() {
        let ok = RuinPrompt(id: "pack-ok", kind: .write, title: "A good one", instruction: "Write the name of your street backwards.")
        let fire = RuinPrompt(id: "pack-fire", kind: .tearOut, title: "Hot", instruction: "Burn this page in a bowl.")
        let long = RuinPrompt(id: "pack-long", kind: .draw, title: "Long", instruction: String(repeating: "word ", count: 80))
        let shadow = RuinPrompt(id: RuinLibrary.prompts[0].id, kind: .write, title: "Copy", instruction: "Write something.")
        let pack = RuinPromptPack(id: "p", version: 1, prompts: [ok, fire, long, shadow])
        XCTAssertEqual(pack.usablePrompts.map(\.id), ["pack-ok"])
    }

    func testPacksOnlyAppearInTheirMonths() {
        let prompt = RuinPrompt(id: "october-only", kind: .stain, title: "Rust", instruction: "Rub a rusty key over this page and see what it says.")
        let pack = RuinPromptPack(id: "oct", version: 1, prompts: [prompt], months: [10])
        XCTAssertTrue(RuinLibrary.available(month: 10, packs: [pack]).contains { $0.id == "october-only" })
        XCTAssertFalse(RuinLibrary.available(month: 3, packs: [pack]).contains { $0.id == "october-only" })
        XCTAssertEqual(RuinLibrary.available(month: 3, packs: []).count, RuinLibrary.prompts.count)
    }

    func testPlanDrawsFromPackPrompts() {
        let themed = (0..<8).map { RuinPrompt(id: "themed-\($0)", kind: [.stain, .fold, .tape, .rubbing][$0 % 4], title: "T\($0)", instruction: "Do thing number \($0) to this page.") }
        let pool = RuinLibrary.gentle + themed
        let leaves = RuinPlan.leaves(count: 4, seed: "s", from: pool)
        XCTAssertEqual(leaves.count, 4)
        XCTAssertTrue(leaves.allSatisfy { $0.front.id.hasPrefix("themed-") })
    }

    func testARegistryKeepsTheWholePromptItAskedFor() throws {
        let prompt = RuinLibrary.rough[0]
        let registry = BoundVolumeRegistry(seed: "s", editionID: "e", title: "T", boundAt: Date(), pageCount: 40,
                                           pageMap: ["21": prompt])
        let round = try JSONDecoder().decode(BoundVolumeRegistry.self, from: try JSONEncoder().encode(registry))
        XCTAssertEqual(round.ruinPrompt(onPage: 21), prompt)
        XCTAssertNil(round.ruinPrompt(onPage: 22))
    }

    /// The Book's voice: contractions, plain words, no X-not-Y, no appositive asides.
    func testPromptsSpeakInTheBooksVoice() {
        let uncontracted = ["do not", "does not", "is not", "are not", "it is ", "that is ", "i am ", "you are ", "you will ",
                            "you have ", "i will ", "would not", "cannot", "will not", "has not", "have not"]
        let adultWords = ["quarrel", "indefensible", "incompatible", "contribution", "revelation", "ritual", "practice"]
        for prompt in RuinLibrary.prompts {
            let text = prompt.instruction.lowercased()
            for phrase in uncontracted { XCTAssertFalse(text.contains(phrase), "\(prompt.id): \"\(phrase)\"") }
            for word in adultWords { XCTAssertFalse(text.contains(word), "\(prompt.id): \"\(word)\"") }
            XCTAssertFalse(text.contains(", not "), "\(prompt.id) has the X-not-Y shape")
            XCTAssertFalse(text.contains(", which"), "\(prompt.id) has an appositive aside")
            XCTAssertLessThanOrEqual(prompt.instruction.count, 240, prompt.id)
            XCTAssertTrue(prompt.instruction.hasSuffix(".") || prompt.instruction.hasSuffix("?"), prompt.id)
        }
    }

    func testPlanIsDeterministicAndSeedDependent() {
        let a = RuinPlan.leaves(count: 5, seed: "binding-1")
        XCTAssertEqual(a, RuinPlan.leaves(count: 5, seed: "binding-1"))
        XCTAssertNotEqual(a.map(\.id), RuinPlan.leaves(count: 5, seed: "binding-2").map(\.id))
        XCTAssertEqual(a.count, 5)
    }

    func testNoTwoNeighboursShareAKindAndNothingRepeats() {
        for seed in ["a", "b", "c", "d", "e", "f", "g", "h"] {
            let leaves = RuinPlan.leaves(count: 8, seed: seed)
            XCTAssertEqual(leaves.count, 8)
            for (x, y) in zip(leaves, leaves.dropFirst()) { XCTAssertNotEqual(x.front.kind, y.front.kind, seed) }
            let ids = leaves.flatMap { [$0.front.id, $0.back.id] }
            XCTAssertEqual(Set(ids).count, ids.count, "no prompt appears twice in a book")
        }
    }

    func testTheBackOfASheetIsAlwaysGentle() {
        for seed in (0..<30).map(String.init) {
            for leaf in RuinPlan.leaves(count: 8, seed: seed) {
                XCTAssertFalse(leaf.front.kind.isGentle)
                XCTAssertTrue(leaf.back.kind.isGentle, "\(leaf.back.id) rides on the back of \(leaf.front.id)")
            }
        }
    }

    func testAskingForNothingGivesNothing() {
        XCTAssertTrue(RuinPlan.leaves(count: 0, seed: "x").isEmpty)
    }

    // MARK: Recognition

    private func volume() -> BoundVolumeRegistry {
        BoundVolumeRegistry(seed: "s", editionID: "2026-10", title: "Count Unbound: October 2026", boundAt: Date(), pageCount: 120,
                            pageMap: ["109": RuinLibrary.rough[0]])
    }

    func testTheBookSaysWhichPageItIsAndNothingItCannotKnow() {
        let ruin = RuinRecognition.line(volume: volume(), page: 109)
        XCTAssertTrue(ruin.contains("Page 109"))
        XCTAssertTrue(ruin.contains(RuinLibrary.rough[0].title))
        let plain = RuinRecognition.line(volume: volume(), page: 12)
        XCTAssertTrue(plain.contains("Page 12"))
        XCTAssertFalse(plain.contains("\u{201C}\(RuinLibrary.rough[0].title)"))
        for line in [ruin, plain] {
            for phrase in ["do not", "it is ", "i am ", "you are ", "you will "] { XCTAssertFalse(line.lowercased().contains(phrase), line) }
            XCTAssertFalse(line.lowercased().contains("you tore") || line.lowercased().contains("you did"), "it cannot see what was done")
        }
    }

    func testMetadataCarriesTheWholePromptAndRoundTrips() {
        let meta = RuinRecognition.metadata(volume: volume(), page: 109)
        XCTAssertEqual(meta["printedPageNumber"], "109")
        XCTAssertEqual(RuinRecognition.prompt(fromMetadata: meta), RuinLibrary.rough[0])
        let plain = RuinRecognition.metadata(volume: volume(), page: 12)
        XCTAssertEqual(plain["printedPage"], "true")
        XCTAssertNil(plain["ruin"])
        XCTAssertNil(RuinRecognition.prompt(fromMetadata: plain))
    }
}
