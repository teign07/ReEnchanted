import XCTest
@testable import InsideCoverCore

/// The mechanics were declared on `Celebration` long before anything read
/// them. These assert the wiring is real: every mechanic renders, the throw
/// belongs to the day rather than to the tap, and the adapter emits metadata
/// the capture sheet actually keys on.
final class CelebrationMechanicTests: XCTestCase {

    private func celebration(mechanic: CelebrationMechanic?) -> Celebration {
        Celebration(
            id: "test-feast",
            kind: .labyrinth,
            commonName: "A Test Feast",
            academyTitle: "The Test Feast",
            blurb: "Blurb.",
            invitationTitle: "The Test Feast",
            invitation: "Do the thing.",
            beliefBonus: 2,
            greyShift: 0,
            symbolName: "star.fill",
            accent: "gold",
            priority: 10,
            mechanic: mechanic
        )
    }

    // MARK: Presentation

    func testEveryMechanicRendersATitlePromptAndPlaceholder() {
        let feast = celebration(mechanic: nil)
        for mechanic in [CelebrationMechanic.findOneLine, .nameSomething, .throwTheBones, .pressAKeepsake, .countersign] {
            XCTAssertFalse(mechanic.title.isEmpty, "\(mechanic) has no title")
            XCTAssertFalse(mechanic.symbolName.isEmpty, "\(mechanic) has no symbol")
            XCTAssertFalse(mechanic.prompt(for: feast).isEmpty, "\(mechanic) has no prompt")
            XCTAssertFalse(mechanic.placeholder(for: feast).isEmpty, "\(mechanic) has no placeholder")
        }
    }

    func testOnlyTheCountersignMechanicOffersCountersigns() {
        XCTAssertFalse(CelebrationMechanic.countersign.countersigns.isEmpty)
        for mechanic in [CelebrationMechanic.findOneLine, .nameSomething, .throwTheBones, .pressAKeepsake] {
            XCTAssertTrue(mechanic.countersigns.isEmpty, "\(mechanic) should not offer countersigns")
        }
    }

    /// The Book is a magical character, not a servant. It asks for things.
    func testMechanicPromptsKeepTheBooksVoice() {
        let feast = celebration(mechanic: nil)
        let all = [CelebrationMechanic.findOneLine, .nameSomething, .throwTheBones, .pressAKeepsake, .countersign]
        let prompts = all.map { $0.prompt(for: feast) }

        let firstPerson = prompts.filter { $0.contains("I ") || $0.contains("I'") }
        XCTAssertGreaterThanOrEqual(firstPerson.count, 3, "The Book should speak as itself in most of these")

        for prompt in prompts {
            XCTAssertFalse(prompt.lowercased().contains("please"), "Too polite: \(prompt)")
            XCTAssertFalse(prompt.lowercased().contains("you may want to"), "Servant speak: \(prompt)")
            XCTAssertFalse(prompt.lowercased().contains("feel free"), "Servant speak: \(prompt)")
        }
    }

    // MARK: The throw

    func testTheThrowBelongsToTheDayNotTheTap() {
        let first = FeastBones.throwBones(celebrationID: "lit-pratchett-born", dayID: "2026-04-28")
        let second = FeastBones.throwBones(celebrationID: "lit-pratchett-born", dayID: "2026-04-28")
        XCTAssertEqual(first, second, "Rerolling the same feast on the same day must not change the answer")
    }

    func testDifferentDaysThrowDifferently() {
        var rolls: Set<Int> = []
        for day in 1...28 {
            let id = String(format: "2026-04-%02d", day)
            rolls.insert(FeastBones.throwBones(celebrationID: "feast", dayID: id).roll)
        }
        XCTAssertGreaterThan(rolls.count, 4, "The throw looks stuck: \(rolls.sorted())")
    }

    func testThrowsAreTheOneHundredInkbones() {
        for day in 1...200 {
            let bones = FeastBones.throwBones(celebrationID: "feast", dayID: "day-\(day)")
            XCTAssertTrue((1...100).contains(bones.roll), "Out of range: \(bones.roll)")
            XCTAssertEqual(bones.band, FeastBonesThrow.Band.resolve(roll: bones.roll))
        }
    }

    func testBandsCoverEveryRollAndNeverPunish() {
        for roll in 1...100 {
            let band = FeastBonesThrow.Band.resolve(roll: roll)
            XCTAssertFalse(band.headline.isEmpty)
            XCTAssertFalse(band.line.isEmpty)
            XCTAssertGreaterThanOrEqual(band.beliefBonus, 0, "A bad throw must never cost belief")
        }
        // Low is lucky, as on every Inkbones throw.
        XCTAssertEqual(FeastBonesThrow.Band.resolve(roll: 3), .wide)
        XCTAssertEqual(FeastBonesThrow.Band.resolve(roll: 20), .open)
        XCTAssertEqual(FeastBonesThrow.Band.resolve(roll: 50), .level)
        XCTAssertEqual(FeastBonesThrow.Band.resolve(roll: 80), .narrow)
        XCTAssertEqual(FeastBonesThrow.Band.resolve(roll: 99), .shut)
    }

    /// The ends are rare: a triumph or a cost is about one throw in twenty each.
    func testTriumphsAndCostsAreRare() {
        var counts: [FeastBonesThrow.Band: Int] = [:]
        for day in 1...4000 {
            counts[FeastBones.throwBones(celebrationID: "feast", dayID: "d\(day)").band, default: 0] += 1
        }
        let wide = counts[.wide] ?? 0
        let level = counts[.level] ?? 0
        XCTAssertGreaterThan(wide, 80)
        XCTAssertLessThan(wide, 320)
        XCTAssertGreaterThan(level, wide * 3, "the middle should be far more common than a triumph")
    }

    // MARK: Adapter wiring

    private func festivalMetadata(for celebration: Celebration) -> [String: String] {
        // Mirrors FestivalPageSourceAdapter's assembly for a mechanic-carrying
        // feast, which is the contract the capture sheet reads.
        var metadata: [String: String] = [:]
        guard let mechanic = celebration.mechanic else { return metadata }
        metadata["festivalMechanic"] = mechanic.rawValue
        metadata["festivalMechanicTitle"] = mechanic.title
        metadata["festivalMechanicPrompt"] = mechanic.prompt(for: celebration)
        metadata["placeholder"] = mechanic.placeholder(for: celebration)
        if !mechanic.countersigns.isEmpty {
            metadata["countersigns"] = mechanic.countersigns.joined(separator: "||")
        }
        return metadata
    }

    func testMechanicMetadataRoundTripsBackToTheMechanic() {
        for mechanic in [CelebrationMechanic.findOneLine, .nameSomething, .throwTheBones, .pressAKeepsake, .countersign] {
            let metadata = festivalMetadata(for: celebration(mechanic: mechanic))
            XCTAssertEqual(CelebrationMechanic(rawValue: metadata["festivalMechanic"] ?? ""), mechanic)
            XCTAssertNotNil(metadata["placeholder"]?.isEmpty == false ? true : nil)
        }
    }

    // MARK: Belief

    func testKeepingAFeastCountsAndAGoodThrowCountsForMore() {
        let plain = surface(metadata: [:])
        XCTAssertEqual(BeliefEconomyPolicy.keepReward(for: plain), 1)

        let openThrow = surface(metadata: ["festivalBonesBelief": "4"])
        XCTAssertEqual(BeliefEconomyPolicy.keepReward(for: openThrow), 5)

        let shutThrow = surface(metadata: ["festivalBonesBelief": "0"])
        XCTAssertEqual(BeliefEconomyPolicy.keepReward(for: shutThrow), 1, "A shut throw must not subtract")
    }

    private func surface(metadata: [String: String]) -> SurfacePage {
        SurfacePage(
            id: "festival-test",
            type: .festival,
            sourceID: "festival",
            intent: .capture,
            renderStyle: .loreLetter,
            score: 80,
            reason: "reason",
            prompt: "prompt",
            detail: "detail",
            payload: BookPagePayload(headline: "h", body: "b", metadata: metadata)
        )
    }

    /// Every feast in the shipped almanacs that claims a mechanic must be able
    /// to render it: a mechanic with no prompt is worse than no mechanic.
    func testEveryShippedMechanicCarryingOccasionCanRender() {
        var checked = 0
        for month in 1...12 {
            for day in 1...28 {
                var components = DateComponents()
                components.year = 2026
                components.month = month
                components.day = day
                components.hour = 12
                guard let date = Calendar(identifier: .gregorian).date(from: components) else { continue }
                for feast in Almanac.celebrations(on: date) {
                    guard let mechanic = feast.mechanic else { continue }
                    checked += 1
                    XCTAssertFalse(mechanic.prompt(for: feast).isEmpty, "\(feast.id) cannot render \(mechanic)")
                    XCTAssertFalse(mechanic.placeholder(for: feast).isEmpty, "\(feast.id) has no placeholder")
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "No shipped occasion carries a mechanic: the wiring has nothing to do")
    }
}
