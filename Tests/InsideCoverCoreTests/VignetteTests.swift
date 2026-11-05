import XCTest
@testable import InsideCoverCore

/// The vignette skeleton: every bundled recipe brings its own room, things that
/// can happen there and three decisions, and the plan Gemma is handed says
/// what happens without handing it anything it would paste into the story.
final class VignetteTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 806_000_000)

    private var bundledRecipes: [StoryRecipe] {
        StoryFormRegistry.bundledPacks.flatMap(\.recipes)
    }

    func testEveryBundledRecipeHasItsOwnPlaceAndHappenings() {
        XCTAssertFalse(bundledRecipes.isEmpty)
        for recipe in bundledRecipes {
            let parts = VignettePlanBuilder.parts(for: recipe)
            XCTAssertNotNil(parts, "\(recipe.id) has no vignette parts")
            XCTAssertFalse(parts?.place.isEmpty ?? true, "\(recipe.id) has no place")
            XCTAssertGreaterThanOrEqual(parts?.happenings.count ?? 0, 4, "\(recipe.id) needs four happenings to deal from")
        }
    }

    func testTheCatalogueNamesOnlyRealRecipes() {
        let ids = Set(bundledRecipes.map(\.id))
        for id in VignettePlanBuilder.catalogue.keys {
            XCTAssertTrue(ids.contains(id), "catalogue entry \(id) belongs to no recipe")
        }
    }

    func testEveryBundledRecipeEndsAtThreeDecisions() {
        for recipe in bundledRecipes {
            let decisions = recipe.decisions ?? VignettePlanBuilder.parts(for: recipe)?.decisions
            XCTAssertEqual(decisions?.count, 3, "\(recipe.id) has no three decisions")
            XCTAssertEqual(Set(decisions?.map(\.role) ?? []), Set(StoryChoiceRole.allCases), recipe.id)
        }
    }

    /// The 2B model copies what it can quote, so the authored parts must never
    /// carry template scaffolding or a word the house has banned.
    func testTheCatalogueCarriesNoScaffoldingOrWornWords() {
        let tokens = StoryFormRegistry.recipeTemplateTokens
        for (id, parts) in VignettePlanBuilder.catalogue {
            let text = ([parts.place, parts.premise ?? ""] + parts.happenings
                + (parts.decisions ?? []).flatMap { [$0.actionTemplate, $0.gainTemplate, $0.costTemplate] })
                .joined(separator: " ")
            let lower = text.lowercased()
            for phrase in ["one familiar detail", "the remembered page", "{{thread}}", "{{grounding}}", "hinge", "tapestry", "the reader"] {
                XCTAssertFalse(lower.contains(phrase), "\(id) carries \"\(phrase)\"")
            }
            let used = text.components(separatedBy: "{{").dropFirst().compactMap { $0.components(separatedBy: "}}").first }
            for token in used {
                XCTAssertTrue(tokens.contains(token) && ["lead", "companion", "thing"].contains(token), "\(id) uses {{\(token)}}")
            }
        }
    }

    func testAPlanCarriesTheRecipesHappeningsAndNoUnfilledTemplates() throws {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now)
        let blueprint = try XCTUnwrap(packet.blueprint)
        let plan = try XCTUnwrap(blueprint.vignette, "\(blueprint.recipeID) built no plan")
        let recipe = try XCTUnwrap(bundledRecipes.first { $0.id == blueprint.recipeID })
        let pool = try XCTUnwrap(VignettePlanBuilder.parts(for: recipe)).happenings

        XCTAssertEqual(plan.happenings.count, 2)
        XCTAssertNotEqual(plan.happenings[0], plan.happenings[1])
        XCTAssertEqual(plan.beats.count, 4, "three beats and the stand")
        let brief = VignetteBrief.prompt(for: plan)
        XCTAssertFalse(brief.contains("{{"), brief)
        XCTAssertFalse(brief.contains("the reader"), brief)
        for happening in plan.happenings {
            XCTAssertTrue(brief.contains(happening))
            XCTAssertTrue(pool.contains { VignetteTellingCheck.landed($0, in: happening) }, happening)
        }
    }

    func testThePlanIsStableForTheSameSlot() {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let first = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now).blueprint?.vignette
        let second = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now).blueprint?.vignette
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    /// The brief names only the cast, so Gemma has nobody else to bring in. The
    /// old brief listed three full character sheets for a two-person scene.
    func testTheBriefNamesOnlyItsCast() throws {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let blueprint = try XCTUnwrap(StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now).blueprint)
        let plan = try XCTUnwrap(blueprint.vignette)
        let brief = VignetteBrief.prompt(for: plan)
        let cast = Set([plan.lead.name, plan.companion?.name].compactMap { $0 })
        for entity in NarrativePackRegistry.entities where entity.kind == .character {
            let name = VignettePlanBuilder.pageName(entity)
            guard !cast.contains(name), name.split(separator: " ").count > 1 || name.count > 4 else { continue }
            XCTAssertFalse(brief.contains(name), "\(name) is not in this scene but is in its brief")
        }
        XCTAssertFalse(brief.contains("Cadence examples"))
    }

    func testTitledStaffAreNamedBySurname() {
        let entity = NarrativeWorldEntity(id: "professor-cedric-stonebrook", packID: "core", name: "Professor Cedric Stonebrook", kind: .character, belief: 0, narrativeWeight: 0)
        XCTAssertEqual(VignettePlanBuilder.pageName(entity), "Professor Stonebrook")
        let student = NarrativeWorldEntity(id: "finn-bridges", packID: "core", name: "Finn Bridges", kind: .character, belief: 0, narrativeWeight: 0)
        XCTAssertEqual(VignettePlanBuilder.pageName(student), "Finn")
    }

    // MARK: Grounding fixes found by the lab

    func testTheHourReadsAsEnglish() {
        let october = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 22))!
        let day = BookDay(id: BookDay.id(for: october), date: Calendar.current.startOfDay(for: october), pages: [])
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: october)
        let text = packet.blueprint?.grounding.text ?? ""
        XCTAssertFalse(text.contains("a autumn"), text)
    }

    /// `.groundedSource` was declared on a dozen recipes and never checked, so
    /// on a day with nothing kept their premises read "A small item tied to one
    /// familiar detail arrives in the wrong place".
    func testGroundedRecipesWaitForSomethingToStandOn() {
        let grounded = Set(bundledRecipes.filter { $0.requirements.contains(.groundedSource) }.map(\.id))
        XCTAssertFalse(grounded.isEmpty)
        for hour in stride(from: 0, to: 24 * 6, by: 5) {
            let time = now.addingTimeInterval(Double(hour) * 3_600)
            let day = BookDay(id: BookDay.id(for: time), date: Calendar.current.startOfDay(for: time), pages: [])
            for variant in 0..<4 {
                let packet = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: time, recipeVariantIndex: variant)
                guard let blueprint = packet.blueprint else { continue }
                XCTAssertFalse(grounded.contains(blueprint.recipeID), "\(blueprint.recipeID) fired with nothing kept")
                XCTAssertFalse(blueprint.premise.contains("one familiar detail"), blueprint.premise)
            }
        }
    }

    func testTheTalismanLeanIsNeverGrounding() {
        XCTAssertTrue(TalismanAscendancy.isLean("The Duskthorn talisman The Dusk Thorn holds the most Belief right now. Lean toward friction."))
        XCTAssertFalse(TalismanAscendancy.isLean("Weather: rain"))
    }

    func testTheThingIsANounFromTheReadersPage() {
        let recipe = bundledRecipes.first { $0.id == "misdelivered-object" }!
        let grounding = StoryGrounding(kind: .keptPage, sourceID: "p", text: "A kept Journal page offers this passage: “The kettle clicked off and nobody came for it.”")
        let thing = StoryScenePacketBuilder.vignetteThing(for: grounding, recipe: recipe)
        XCTAssertTrue(thing.contains("kettle"), thing)
        XCTAssertFalse(thing.contains("familiar detail"))
    }

    // MARK: The telling check

    private func plan(happenings: [String]) -> VignettePlan {
        VignettePlan(
            recipeID: "r", shapeID: "s", place: "the corridor",
            lead: VignetteSpeaker(name: "Serenity", pronoun: nil, register: "bright", habit: ""),
            companion: VignetteSpeaker(name: "Wicker", pronoun: nil, register: "dry", habit: ""),
            hour: nil, mood: "", keptWords: nil, beats: [], happenings: happenings
        )
    }

    func testALeftoverSpeechSlotIsAFailureAndIsCleanedAway() {
        let scene = "Serenity opens the note. Wicker says, \"<their words>.\" The door waits.\n\nSerenity asks you, \"…?\""
        XCTAssertTrue(VignetteTellingCheck.hasUnfilledSlot(scene))
        XCTAssertTrue(VignetteTellingCheck.failures(in: scene, plan: plan(happenings: [])).contains { $0.contains("<...>") })
        let cleaned = VignetteTellingCheck.cleaned(scene)
        XCTAssertFalse(VignetteTellingCheck.hasUnfilledSlot(cleaned), cleaned)
        XCTAssertTrue(cleaned.contains("Serenity opens the note."))
        XCTAssertTrue(cleaned.contains("The door waits."))
    }

    func testAHappeningLandsWhenItsWordsDoEvenRetold() {
        let happening = "A note slides out under the door in very neat handwriting. It says NOT YET."
        XCTAssertTrue(VignetteTellingCheck.landed(happening, in: "Then a folded note slides out from under the door. The handwriting is neat. It says NOT YET."))
        XCTAssertFalse(VignetteTellingCheck.landed(happening, in: "The corridor is quiet and the lamps are low."))
    }

    func testTheCheckAsksForTheCastAndTheLength() {
        let failures = VignetteTellingCheck.failures(in: "Serenity looks at the door.", plan: plan(happenings: []))
        XCTAssertTrue(failures.contains { $0.contains("Wicker") })
        XCTAssertTrue(failures.contains { $0.contains("whole scene") })
    }
}

extension VignetteTests {
    /// The consequence is a beat sheet too: the choice, its gain, its cost, a
    /// named answer, and the landing, with nothing pasted from canon.
    func testTheConsequenceCarriesTheChoiceGainCostAndLanding() throws {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let blueprint = try XCTUnwrap(StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now).blueprint)
        let plan = try XCTUnwrap(blueprint.vignette)
        let brief = VignetteBrief.consequence(
            for: plan, scene: "The scene so far.", choice: "Open the drawer",
            gain: "the table tells what it knows", cost: "the reader may not like it",
            reactor: "Professor Cedric Stonebrook", landing: "The drawer stays open."
        )
        XCTAssertTrue(brief.contains("You choose: Open the drawer."))
        XCTAssertTrue(brief.contains("It works: the table tells what it knows."))
        XCTAssertTrue(brief.contains("But you may not like it."))
        XCTAssertTrue(brief.contains("Professor Stonebrook says"))
        XCTAssertTrue(brief.contains("The drawer stays open."))
        XCTAssertFalse(brief.contains("CHARACTER CANON"))
    }
}

extension VignetteTests {
    func testTheSceneStopsOnItsOwnThreeDecisions() throws {
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let blueprint = try XCTUnwrap(StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now).blueprint)
        let stand = try XCTUnwrap(blueprint.vignette?.beats.last)
        for decision in try XCTUnwrap(blueprint.decisions) {
            let words = decision.actionTemplate.lowercased().split(separator: " ").suffix(2).joined(separator: " ")
            XCTAssertTrue(stand.lowercased().contains(words), "\(stand) lacks \(decision.actionTemplate)")
        }
        XCTAssertFalse(stand.contains("<"))
    }

    func testAnInventedReaderActIsCleanedAway() {
        let scene = "The door knocks once. You sit still, observing. Serenity says, \"Well?\""
        let cleaned = VignetteTellingCheck.cleaned(scene)
        XCTAssertFalse(cleaned.contains("You sit"))
        XCTAssertTrue(cleaned.contains("The door knocks once."))
        XCTAssertEqual(VignetteTellingCheck.cleaned("You come round the corner with Serenity."), "You come round the corner with Serenity.")
    }
}

extension VignetteTests {
    func testTheSceneEndsOnItsQuestion() {
        let scene = "The bell rings.\n\nFinn asks you, \"Sit with it, or follow the rope?\" The question hangs in the air, demanding an answer."
        XCTAssertEqual(VignetteTellingCheck.cleaned(scene), "The bell rings.\n\nFinn asks you, \"Sit with it, or follow the rope?\"")
    }

    /// Kept words are something on the page, never a line a speaker says.
    func testKeptWordsArriveInTheReadersOwnHand() throws {
        let page = BookPage(id: "kept", type: .diary, createdAt: now.addingTimeInterval(-3_600), promptText: "Keep what mattered.",
                            userInput: "Mara didn't text back. I kept checking the stairwell for the sound of her keys.", origin: .userAuthored)
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [page])
        for variant in 0..<4 {
            let blueprint = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now, recipeVariantIndex: variant).blueprint
            guard let plan = blueprint?.vignette, let kept = plan.keptWords else { continue }
            let brief = VignetteBrief.prompt(for: plan)
            XCTAssertTrue(brief.contains("in your own handwriting: “\(kept)”"), brief)
            XCTAssertFalse(brief.contains("says, “\(kept)"), brief)
            return
        }
        throw XCTSkip("no remembered recipe seated on this day")
    }
}
