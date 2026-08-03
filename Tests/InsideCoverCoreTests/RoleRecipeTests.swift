import XCTest
@testable import InsideCoverCore

/// Phase 3 of the role plan, which was never started: the payoff of naming the
/// reader on night one is that they get handed scenes only their kind of person
/// would be handed. These check the gate is real and the scarcity holds.
final class RoleRecipeTests: XCTestCase {

    private var roleRecipes: [StoryRecipe] {
        StoryFormRegistry.coreRecipes.filter { $0.requirements.contains(.readerRole) }
    }

    func testEveryRoleHasExactlyOneSignatureScene() {
        let roleIDs = Set(ReaderRoleRegistry.all.map(\.id))
        var covered: [String: Int] = [:]
        for recipe in roleRecipes {
            XCTAssertFalse(recipe.requiredRoleIDs.isEmpty, "\(recipe.id) gates on a role but names none")
            for id in recipe.requiredRoleIDs {
                XCTAssertTrue(roleIDs.contains(id), "\(recipe.id) names a role that does not exist: \(id)")
                covered[id, default: 0] += 1
            }
        }
        for id in roleIDs {
            XCTAssertEqual(covered[id], 1, "\(id) has \(covered[id] ?? 0) signature scenes, expected 1")
        }
    }

    /// A role scene that turns up weekly is a genre; one that turns up twice a
    /// season is a name being honoured.
    func testRoleScenesAreScarce() {
        for recipe in roleRecipes {
            XCTAssertGreaterThanOrEqual(
                recipe.cooldownHours, 14 * 24,
                "\(recipe.id) can recur every \(recipe.cooldownHours / 24) days"
            )
        }
    }

    func testARoleSceneNeverReachesTheWrongReader() {
        let maker = roleRecipes.first { $0.requiredRoleIDs.contains("maker") }
        XCTAssertNotNil(maker)
        XCTAssertFalse(maker?.requiredRoleIDs.contains("lookout") ?? true)
    }

    func testTheGateNeedsARoleAtAll() {
        // No role fact means no role recipe, whatever else is true.
        let inputs = BookSourceInputs.empty
        XCTAssertNil(ReaderRoleRegistry.currentRole(from: inputs.selfFacts))
    }

    /// The scenes have to be as concrete as the rest of the catalogue.
    func testRoleScenesKeepTheHouseStandard() {
        let vague = ["journey", "tapestry", "echoes of", "quiet magic", "profound", "hidden meaning"]
        for recipe in roleRecipes {
            let text = [recipe.premiseTemplate, recipe.groundingDirective,
                        recipe.toneDirective, recipe.continuationDirective]
                .joined(separator: " ")
                .lowercased()
            for word in vague {
                XCTAssertFalse(text.contains(word), "\(recipe.id) reached for \"\(word)\"")
            }
            XCTAssertFalse(recipe.beats.isEmpty, "\(recipe.id) has no beats")
            XCTAssertFalse(recipe.turns.isEmpty, "\(recipe.id) has no turn")
            XCTAssertTrue(recipe.preferredTags.contains("role"), "\(recipe.id) is not findable as a role scene")
        }
        XCTAssertEqual(roleRecipes.count, 8)
    }
}

/// The tenure was a type nobody persisted, which meant the Book could never
/// reconsider a name it had given. These cover the check that could not run.
final class RoleTenureTests: XCTestCase {

    private var calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func page(_ offset: Int, type: BookPageType) -> BookPage {
        BookPage(
            id: "p-\(offset)-\(type.rawValue)",
            type: type,
            createdAt: calendar.date(byAdding: .day, value: offset, to: start)!,
            promptText: "p",
            userInput: "something kept",
            origin: .userAuthored
        )
    }

    func testATenureKnowsWhetherItIsCurrent() {
        var tenure = RoleTenure(roleID: "lookout", namedAt: start)
        XCTAssertTrue(tenure.isCurrent)
        tenure.supersededAt = start.addingTimeInterval(86_400)
        XCTAssertFalse(tenure.isCurrent)
    }

    func testTheBookWillNotRenameOnThinEvidence() {
        guard let lookout = ReaderRoleRegistry.role(id: "lookout") else { return XCTFail("no role") }
        // Plenty of days, not enough pages.
        let sparse = (0..<10).map { page($0 * 3, type: .enchantment) }
        XCTAssertNil(
            ReaderRoleRegistry.outgrownRole(
                current: lookout, keptPages: sparse, namedAt: start,
                now: calendar.date(byAdding: .day, value: 40, to: start)!
            ),
            "Ten pages is not enough to take somebody's name away"
        )
    }

    func testTheBookWillNotRenameTooSoon() {
        guard let lookout = ReaderRoleRegistry.role(id: "lookout") else { return XCTFail("no role") }
        // Plenty of pages, all in one week.
        let burst = (0..<40).map { page($0 % 7, type: .enchantment) }
        XCTAssertNil(
            ReaderRoleRegistry.outgrownRole(
                current: lookout, keptPages: burst, namedAt: start,
                now: calendar.date(byAdding: .day, value: 7, to: start)!
            ),
            "One intense week should not rename anybody"
        )
    }

    func testPagesKeptBeforeTheNamingDoNotCount() {
        guard let lookout = ReaderRoleRegistry.role(id: "lookout") else { return XCTFail("no role") }
        let namedAt = calendar.date(byAdding: .day, value: 60, to: start)!
        let before = (0..<50).map { page($0, type: .enchantment) }
        XCTAssertNil(
            ReaderRoleRegistry.outgrownRole(
                current: lookout, keptPages: before, namedAt: namedAt,
                now: calendar.date(byAdding: .day, value: 90, to: start)!
            ),
            "Evidence from before the naming was never evidence about this name"
        )
    }

    func testTheFloorsAreEvidenceDenominated() {
        XCTAssertGreaterThanOrEqual(ReaderRoleRegistry.outgrowMinimumKeptPages, 20)
        XCTAssertGreaterThanOrEqual(ReaderRoleRegistry.outgrowMinimumDays, 14)
        XCTAssertGreaterThan(ReaderRoleRegistry.outgrowMarginPercent, 0)
    }
}
