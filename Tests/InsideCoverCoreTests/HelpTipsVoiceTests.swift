import XCTest
@testable import InsideCoverCore

/// My Habits and Small Magic are the Book explaining itself, so they have to
/// be true to the app as it is now and said in the Book's own voice.
final class HelpTipsVoiceTests: XCTestCase {
    private func allSurfaces() -> [SurfacePage] {
        let day = BookDay.today()
        var inputs = BookSourceInputs.empty
        inputs.deckRound = 1
        return HelpTipsPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date(timeIntervalSinceReferenceDate: 987_654)
        )
    }

    func testEveryTipPassesTheBookCharacterLint() {
        let surfaces = allSurfaces()
        XCTAssertEqual(surfaces.count, HelpTipsCatalog.entries.count)
        let errors = BookCharacterLint.inspect(surfaces).filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, BookCharacterLint.report(surfaces))
    }

    func testTipsKeepToTheVoiceRules() throws {
        let banned = [
            "ritual", "gemma", "curator", "loom", "jurisdiction", "claws", "bite",
            "teeth", "rather than", ", not ", "not a performance", "page pressure",
            "rising page", "sources screen", "use sources", "warm a ", "cool a ",
            "gently", "do not ", "does not ", "it is ", "i am ", "you are ", "cannot "
        ]
        let door = try NSRegularExpression(pattern: #"\bdoors?\b"#, options: [.caseInsensitive])
        for entry in HelpTipsCatalog.entries {
            let text = [entry.title, entry.prompt, entry.body].joined(separator: " ")
            let lower = text.lowercased()
            for phrase in banned {
                XCTAssertFalse(lower.contains(phrase), "\(entry.id) says \"\(phrase)\"")
            }
            let range = NSRange(text.startIndex..., in: text)
            XCTAssertNil(door.firstMatch(in: text, range: range), "\(entry.id) uses a door")
            XCTAssertFalse(entry.tags.contains("ritual"), entry.id)
        }
    }

    func testSmallMagicWearsItsOwnLabelAndHelpKeepsMyHabits() {
        for surface in allSurfaces() {
            let isEnchantment = surface.payload.metadata["tags"]?.contains("everyday-enchantment") == true
            if isEnchantment {
                XCTAssertEqual(surface.payload.metadata["surfaceLabel"], "Small Magic", surface.id)
            } else {
                XCTAssertNil(surface.payload.metadata["surfaceLabel"], surface.id)
                XCTAssertEqual(surface.type.shortTitle, "My Habits")
            }
            XCTAssertFalse(surface.reason.lowercased().contains("the book"), surface.id)
        }
    }

    func testCompassHelpMatchesTheFiveDirections() throws {
        let compass = try XCTUnwrap(HelpTipsCatalog.systemEntries.first { $0.id == "wonder-compass" })
        for pair in ["North is Notice", "East is Embark", "South is Sense", "West is Write", "Center is Rest"] {
            XCTAssertTrue(compass.body.contains(pair), pair)
        }
    }
}
