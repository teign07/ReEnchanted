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

    /// Hard material is witnessed - and witnessing is not silence.
    ///
    /// This test used to demand that a hard night produce no Book sentence at
    /// all, which made grief pages the shortest pages the braid wrote: the Book
    /// went quietest exactly where it could do the most good. What a hard page
    /// must never do is explain, resolve, or brighten. It may notice.
    func testHardMaterialIsNoticedAndNeverConsoled() {
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
        for claim in claims where claim.realm == .book {
            for consolation in [
                "at least", "which is how", "better", "will pass", "silver lining",
                "you know", "everything happens", "stronger"
            ] {
                XCTAssertFalse(claim.text.lowercased().contains(consolation), claim.text)
            }
        }
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

    // MARK: - The floor as a candidate

    /// It has to be a real page: audited, tasted, and beaten on merit or not at
    /// all.
    func testTheFloorProducesAPageTheAuditWillAccept() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            guard !plan.placements.isEmpty,
                  let page = BraidSceneWriter.page(for: plan, title: "A Night") else { continue }

            var context = DeterministicBraidwright.preparedContext(
                for: night.day, context: night.context)
            context.earnedWordBand = plan.earnedWords
            let failures = BraidOutputAudit
                .issues(in: page.userInput, for: night.day, context: context)
                .filter(\.isRegisterFailure)
            XCTAssertTrue(failures.isEmpty, "\(night.name): \(failures.map(\.rawValue))")
            XCTAssertTrue(page.userInput.contains("The Book kept the page:"), night.name)
        }
    }

    /// Provenance travels with it, so the residue phase reads what shipped.
    func testTheFloorsPageCarriesItsProvenance() {
        guard let night = BraidBench.corpus().first(where: { $0.name == "rich-mixed-night" }) else {
            return XCTFail("no rich night")
        }
        let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
        guard let page = BraidSceneWriter.page(for: plan, title: "A Night") else {
            return XCTFail(plan.summary)
        }
        XCTAssertTrue(page.tags.contains("braid-plan-floor"))
        XCTAssertTrue(page.tags.contains { $0.hasPrefix("braid-claim:lived:") }, "\(page.tags)")
        XCTAssertTrue(page.tags.contains { $0.hasPrefix("braid-claim:world:") }, "\(page.tags)")
    }

    private func pastNight(_ day: Int, _ text: String) -> BookDay {
        let at = date(String(format: "2026-10-%02dT21:30:00Z", day))
        return BookDay(
            id: String(format: "2026-10-%02d", day), date: at,
            pages: [BookPage(
                id: "p\(day)", type: .diary, createdAt: at.addingTimeInterval(-3600),
                promptText: "One true thing", userInput: text, origin: .userAuthored)])
    }

    private func quietPage(_ day: Int, archive: [BookDay]) -> BookPage? {
        var context = BraidPromptBuilder.Context()
        context.recentDays = archive
        let at = date(String(format: "2026-11-%02dT21:30:00Z", day))
        let plan = BraidScenePlanBuilder.plan(
            for: BookDay(id: String(format: "2026-11-%02d", day), date: at, pages: []),
            context: context, calendar: Calendar(identifier: .gregorian))
        return BraidSceneWriter.page(for: plan, title: plan.title())
    }

    /// A reader should be able to flip back to a week they never opened the app
    /// and find the Book had a week anyway.
    func testAClosedDayIsAFullPage() {
        let archive = [
            pastNight(2, "I walked past the bakery that shut last winter and found a plant in the window."),
            pastNight(3, "Found the library card I lost in March pressed inside the atlas.")
        ]
        guard let page = quietPage(6, archive: archive) else {
            return XCTFail("a closed day produced nothing")
        }
        let words = page.userInput.split(whereSeparator: \.isWhitespace).count
        XCTAssertGreaterThan(words, 60, page.userInput)
        // The Book's own voice, the reader's own past, and the world's business.
        XCTAssertTrue(page.tags.contains { $0.hasPrefix("braid-claim:world:") }, "\(page.tags)")
        XCTAssertTrue(page.userInput.contains("The Book kept the page:"), page.userInput)
    }

    /// With nothing new to read, the Book rereads - and because the old line
    /// joins the evidence properly, the claim about it is checked like any other.
    func testAClosedDayRereadsTheReader() {
        let archive = [
            pastNight(2, "I walked past the bakery that shut last winter and found a plant in the window.")
        ]
        guard let page = quietPage(6, archive: archive) else { return XCTFail("no page") }
        XCTAssertTrue(page.userInput.contains("bakery"), page.userInput)
        XCTAssertTrue(page.tags.contains { $0.hasPrefix("braid-claim:lived:") }, "\(page.tags)")
    }

    /// Never a reproach and never a tally. A Book that keeps score is one
    /// somebody eventually stops opening.
    func testAClosedDayNeverReproachesTheReader() {
        let archive = [pastNight(2, "I walked past the bakery and found a plant in the window.")]
        for day in 3...9 {
            guard let page = quietPage(day, archive: archive) else { continue }
            let lowered = page.userInput.lowercased()
            for scold in [
                "you did not", "you didn't", "you have not", "you haven't",
                "missed", "forgot to", "should have", "days since", "streak"
            ] {
                XCTAssertFalse(lowered.contains(scold), "\(day): \(scold) — \(page.userInput)")
            }
        }
    }

    /// A week off should read as a week, not one day with the order shuffled.
    /// Stepping the rotation by one meant consecutive closed days shared two of
    /// their three facts.
    func testAWeekOfClosedDaysAreAllDifferentPages() {
        let archive = [pastNight(2, "I walked past the bakery and found a plant in the window.")]
        var pages: [String] = []
        for day in 3...9 {
            guard let page = quietPage(day, archive: archive) else { continue }
            pages.append(page.userInput)
        }
        XCTAssertEqual(pages.count, 7)
        XCTAssertEqual(Set(pages).count, 7, "closed days repeated")
    }

    /// A night the reader wrote nothing on becomes the world's own business, and
    /// a different piece of it each time.
    ///
    /// The old writer gave every blank day the same page - "The Page That Bit
    /// Back", five times in one simulated month, byte for byte. In a printed
    /// volume that is five identical pages. Here the world is doing something
    /// whether or not the reader looked, and which something rotates by day.
    func testBlankNightsBecomeTheWorldsBusinessAndDoNotRepeat() {
        var pages: [String] = []
        for day in [2, 7, 11, 16, 21] {
            let empty = BookDay(
                id: String(format: "2026-10-%02d", day),
                date: date(String(format: "2026-10-%02dT21:30:00Z", day)),
                pages: [])
            let plan = BraidScenePlanBuilder.plan(for: empty)
            guard let page = BraidSceneWriter.page(for: plan, title: "A Night") else {
                return XCTFail("a blank night said nothing at all")
            }
            XCTAssertTrue(page.tags.contains { $0.hasPrefix("braid-claim:world:") }, "\(page.tags)")
            XCTAssertFalse(
                BraidDraftVerifier.assertsSomethingHappenedToTheReader(page.userInput),
                page.userInput)
            pages.append(page.userInput)
        }
        XCTAssertEqual(
            Set(pages).count, pages.count,
            "blank nights repeated themselves:\n" + pages.joined(separator: "\n---\n"))
    }

    /// The floor is the page that ships when no model page wins.
    func testTheFloorIsTheDefault() {
        XCTAssertEqual(BraidFloor.preferred, .scenePlan)
    }

    /// A night is named in the reader's own words, by whichever renderer wrote
    /// it. A slice gave fragments and a noun-phrase search gave single words;
    /// their clause cut at a phrase end gives a title.
    func testEveryNightIsTitledInTheReadersOwnWords() {
        for night in BraidBench.corpus() {
            let plan = BraidScenePlanBuilder.plan(for: night.day, context: night.context)
            let title = plan.title()
            XCTAssertFalse(title.isEmpty, night.name)
            XCTAssertFalse(title.hasSuffix(" the"), "\(night.name): \(title)")
            XCTAssertFalse(title.hasSuffix(" a"), "\(night.name): \(title)")
            XCTAssertFalse(
                ["and", "but", "so", "then"].contains(
                    title.split(separator: " ").first?.lowercased() ?? ""),
                "\(night.name): \(title)")
        }
    }
}
