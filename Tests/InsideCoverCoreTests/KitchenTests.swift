import XCTest
@testable import InsideCoverCore

/// The Kitchen: recipes in the Book (docs/kitchen-recipe-system.md).
final class KitchenTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func kept(_ recipeID: String, _ outcome: KitchenOutcome, on day: Date, note: String = "") -> BookPage {
        BookPage(type: .note, createdAt: day, promptText: recipeID, userInput: note,
                 tags: outcome.tags(recipeID: recipeID))
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        pages.enumerated().map { BookDay(id: "d\($0.offset)", date: $0.element.createdAt, pages: [$0.element]) }
    }

    private func offer(on day: Date, workings: [KitchenWorking] = [], weather: Set<String> = [],
                       busy: Bool = true) -> KitchenOffering.Offer? {
        KitchenOffering.offer(on: day, dayID: "\(calendar.component(.month, from: day))-\(calendar.component(.day, from: day))",
                              workings: workings, weatherTags: weather, kitchenBusy: busy, calendar: calendar)
    }

    // MARK: The recipes

    func testEveryRecipeIsWholeAndNamesWhatsInIt() {
        let recipes = KitchenRecipeRegistry.bundled
        XCTAssertEqual(Set(recipes.map(\.id)).count, recipes.count, "duplicate recipe ids")
        let houseAllergens: Set<String> = ["milk", "egg", "wheat", "gluten", "oats", "nuts", "peanuts", "soy", "fish",
                                           "shellfish", "sesame", "mustard", "celery", "sulphites"]
        for recipe in recipes {
            XCTAssertFalse(recipe.ingredients.isEmpty, recipe.id)
            XCTAssertGreaterThanOrEqual(recipe.steps.count, 2, recipe.id)
            XCTAssertNotNil(recipe.credit?.nonEmpty, "\(recipe.id) has to say whose it is")
            let ingredientText = recipe.ingredients.joined(separator: " ").lowercased()
            for allergen in recipe.allergens {
                XCTAssertTrue(houseAllergens.contains(allergen), "\(recipe.id): \(allergen) isn't a house allergen word")
                XCTAssertTrue(ingredientText.contains("(\(allergen)") || ingredientText.contains("\(allergen))")
                              || ingredientText.contains(allergen),
                              "\(recipe.id): \(allergen) isn't named in the ingredient line")
            }
            let text = ([recipe.title, recipe.line, recipe.cookNote ?? ""] + recipe.steps).joined(separator: " ").lowercased()
            for banned in ["hinge", "ritual", "forgive", "pressure can", "open-kettle", "paraffin"] {
                XCTAssertFalse(text.contains(banned), "\(recipe.id): \(banned)")
            }
        }
    }

    func testThePrintedRecipeCarriesItsCreditAndAllergens() {
        let soup = KitchenRecipeRegistry.recipe(id: "leek-and-potato-soup")!
        XCTAssertTrue(soup.printed.hasPrefix("From The Middlemost Cookery."))
        XCTAssertTrue(soup.printed.contains("1. Melt the butter"))
        XCTAssertTrue(soup.printed.contains("Has in it: milk, celery."))
    }

    // MARK: Which recipe today

    func testTheStorysDaysBringTheirOwnRecipe() {
        XCTAssertEqual(offer(on: date(10, 31))?.recipe.id, "soul-cakes")
        XCTAssertEqual(offer(on: date(11, 2))?.recipe.id, "soul-cakes", "soul cakes hold their window first")
        XCTAssertEqual(offer(on: date(11, 3))?.recipe.id, "parkin", "parkin comes early: it wants three days")
        XCTAssertEqual(offer(on: date(11, 5))?.recipe.id, "bonfire-toffee")
        XCTAssertEqual(offer(on: date(11, 22))?.recipe.id, "christmas-pudding")
        XCTAssertEqual(offer(on: date(11, 30))?.recipe.id, "the-hobs-bowl")
        XCTAssertEqual(offer(on: date(11, 30))?.reason, .itsDay)
    }

    func testARecipeOnItsOwnDayClaimsTheDesk() {
        let cakes = KitchenRecipeRegistry.recipe(id: "soul-cakes")!
        let day = KitchenOffering.surface(for: cakes, reason: .itsDay, dayID: "2026-10-31", days: [], now: date(10, 31))
        XCTAssertTrue(day.isDeskMilestone)
        XCTAssertTrue(BookCurator.holdsItsChair(day))
        let ordinary = KitchenOffering.surface(for: cakes, dayID: "2026-12-03", days: [], now: date(12, 3))
        XCTAssertFalse(ordinary.isDeskMilestone)
        XCTAssertEqual(day.type, .recipe)
        XCTAssertEqual(KitchenOffering.keepTags(for: day, outcome: nil), ["kitchen", "kitchen:soul-cakes", "kitchen-owed:soul-cakes"])
        XCTAssertEqual(KitchenOffering.keepTags(for: KitchenOffering.rescueSurface(dayID: "x"), outcome: .made), [])
    }

    func testTheKitchenOpensWithTheStory() {
        let adapter = KitchenRecipePageSourceAdapter()
        func offered(_ month: Int, _ day: Int) -> KitchenOffering.Offer? {
            let now = date(month, day, hour: 10)
            return adapter.offer(for: BookDay(id: BookDay.id(for: now), date: now, pages: []), inputs: .empty, now: now)
        }
        for day in 1...29 { XCTAssertNil(offered(10, day), "a recipe on 10/\(day), before the Kitchen opens") }
        XCTAssertEqual(offered(10, 30)?.recipe.id, "soul-cakes", "the first recipe anyone meets is the soul cakes")
    }

    func testAMadeRecipeIsDoneForItsWindow() {
        let made = KitchenLedger.workings(in: days([kept("soul-cakes", .made, on: date(10, 31))]))
        XCTAssertNotEqual(offer(on: date(11, 1), workings: made)?.recipe.id, "soul-cakes")
    }

    func testNotYetIsPutDownAgainNotNaggedAbout() {
        let owed = KitchenLedger.workings(in: days([kept("stone-soup", .notYet, on: date(11, 7))]))
        let reoffered = (8...30).filter { offer(on: date(11, $0), workings: owed)?.reason == .reoffer(owedSince: date(11, 7)) }
        XCTAssertEqual(reoffered, [11, 18], "put down again a few times, spaced out, never every morning")
        XCTAssertEqual(offer(on: date(11, 11), workings: owed)?.recipe.id, "stone-soup")
        XCTAssertEqual(KitchenOffering.reofferLine(since: date(11, 7), now: date(11, 11), calendar: calendar),
                       "I gave you this on the 7th. Here it is again. — A. T.")
        let madeSince = KitchenLedger.workings(in: days([kept("stone-soup", .notYet, on: date(11, 7)),
                                                         kept("stone-soup", .made, on: date(11, 9))]))
        XCTAssertNotEqual(offer(on: date(11, 11), workings: madeSince)?.reason, .reoffer(owedSince: date(11, 7)))
    }

    func testAMadeRecipeRests() {
        let made = KitchenLedger.workings(in: days([kept("leek-and-potato-soup", .made, on: date(11, 13))]))
        for day in 14...16 {
            XCTAssertNotEqual(offer(on: date(11, day), workings: made, weather: ["cold", "rain"])?.recipe.id,
                              "leek-and-potato-soup", "day \(day)")
        }
    }

    func testOrdinaryDaysPassAroundTheShelf() {
        let offered = Set((6...28).compactMap { offer(on: date(11, $0))?.recipe.id })
        XCTAssertGreaterThanOrEqual(offered.count, 4, "\(offered)")
        XCTAssertEqual(KitchenLedger.dayWords(date(10, 31), relativeTo: date(11, 20), calendar: calendar), "31 October")
    }

    func testOrdinaryDaysAreDeterministicAndQuieterOutOfSeason() {
        XCTAssertEqual(offer(on: date(11, 14)), offer(on: date(11, 14)))
        let busy = (1...28).compactMap { offer(on: date(2, $0), busy: true) }.count
        let quiet = (1...28).compactMap { offer(on: date(2, $0), busy: false) }.count
        XCTAssertLessThan(quiet, busy)
        XCTAssertGreaterThan(quiet, 0)
    }

    // MARK: The archive is the ledger

    func testWorkingsAndLastTimeComeFromKeptPages() {
        let archive = days([kept("soda-bread", .madeBadly, on: date(11, 13)),
                            kept("soda-bread", .made, on: date(11, 20), note: "Flat, but we ate all of it.")])
        let workings = KitchenLedger.workings(of: "soda-bread", in: archive)
        XCTAssertEqual(workings.map(\.outcome), [.madeBadly, .made])
        XCTAssertEqual(KitchenLedger.lastTimeLine(for: "soda-bread", in: archive, now: date(11, 25), calendar: calendar),
                       "Last time: “Flat, but we ate all of it.” The 20th.")
        let badly = days([kept("parkin", .madeBadly, on: date(11, 2))])
        XCTAssertEqual(KitchenLedger.lastTimeLine(for: "parkin", in: badly, now: date(11, 25), calendar: calendar),
                       "Last time it went wrong. The 2nd. Try again.")
        XCTAssertNil(KitchenLedger.lastTimeLine(for: "colcannon", in: badly, now: date(11, 25), calendar: calendar))
    }

    func testARescuedRecipeKeepsWhoseItIs() {
        var page = BookPage(type: .note, createdAt: date(11, 15), promptText: "Rescue a Recipe",
                            userInput: "Grandad's chilli\nEnough beans. Cook it till it looks right.",
                            tags: [KitchenLedger.rescuedTag])
        page.metadata = [KitchenLedger.rescueWhoseKey: "Grandad"]
        let rescued = KitchenLedger.rescued(in: days([page]))
        XCTAssertEqual(rescued.count, 1)
        XCTAssertEqual(rescued[0].title, "Grandad's chilli")
        XCTAssertEqual(rescued[0].whose, "Grandad")
    }

    // MARK: The Cookery's count

    func testTheCookeryCountFollowsPennysFigures() {
        let start = date(11, 1, hour: 0)
        XCTAssertEqual(KitchenTally.count(liveDay: 4, eventStart: start, days: []).gone, 1)
        XCTAssertEqual(KitchenTally.count(liveDay: 12, eventStart: start, days: []).gone, 214)
        let twenty = KitchenTally.count(liveDay: 20, eventStart: start, days: [])
        XCTAssertEqual(twenty.gone, 231)
        XCTAssertEqual(twenty.back, 17)
        XCTAssertEqual(twenty.line, "The Cookery: 231 letters gone, 17 back.")
    }

    func testTheReadersKitchenAddsToTheSecondColumnAndNeverPastTheFirst() {
        let start = date(11, 1, hour: 0)
        var rescue = BookPage(type: .note, createdAt: date(11, 15), promptText: "Rescue", userInput: "Soup",
                              tags: [KitchenLedger.rescuedTag])
        rescue.metadata = [:]
        let archive = days([kept("soda-bread", .made, on: date(11, 13)),
                            kept("parkin", .madeBadly, on: date(11, 2)),
                            kept("stone-soup", .notYet, on: date(11, 9)),
                            kept("soul-cakes", .made, on: date(10, 20)),
                            rescue])
        let count = KitchenTally.count(liveDay: 20, eventStart: start, days: archive)
        XCTAssertEqual(count.made, 2, "not-yet doesn't count, and nothing from before the month")
        XCTAssertEqual(count.rescued, 1)
        XCTAssertEqual(count.fromReader, 2 * KitchenTally.lettersPerMade + KitchenTally.lettersPerRescue)
        XCTAssertTrue(count.line.hasSuffix("30 of them came back from your kitchen."))
        let early = KitchenTally.count(liveDay: 4, eventStart: start, days: archive)
        XCTAssertLessThanOrEqual(early.back, early.gone)
    }

    // MARK: The paper and Book Today

    private func guestLive() throws -> ResolvedWorldEvent {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let pack = try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/the-guest/november.reenchantedevents.json")))
        let event = try XCTUnwrap(pack.events.first)
        return ResolvedWorldEvent(id: event.id, packID: pack.id, title: event.title, subtitle: event.subtitle,
                                  phase: try XCTUnwrap(event.phases.dropFirst().first),
                                  startedAt: date(11, 1, hour: 0), endsAt: date(12, 1, hour: 0), progress: 0.4,
                                  playerTouchCount: 0, playerTouchCounts: nil, outcome: nil, effects: [], packet: event.packet)
    }

    func testTheKitchensWriteInThePaperOnlyWhileTheGuestIsHere() throws {
        var inputs = BookSourceInputs.empty
        XCTAssertEqual(KitchenTally.bleedLines(on: date(11, 13), inputs: inputs, calendar: calendar), [])
        inputs.activeWorldEvents = [try guestLive()]
        inputs.days = days([kept("soda-bread", .made, on: date(11, 9))])
        let lines = KitchenTally.bleedLines(on: date(11, 13), inputs: inputs, calendar: calendar)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("ON THE KITCHENS' BOARD\n"))
        XCTAssertTrue(lines[1].contains("9 of them came back from your kitchen"), lines[1])
        XCTAssertEqual(KitchenTally.chalkboard(weatherTags: ["rain"], dayID: "x").isEmpty, false)
        XCTAssertNotEqual(KitchenTally.chalkboard(weatherTags: ["bright"], dayID: "2026-11-13"),
                          KitchenTally.chalkboard(weatherTags: ["snow"], dayID: "2026-11-13"))
        let early = KitchenTally.count(liveDay: 6, eventStart: date(11, 1, hour: 0), days: [])
        XCTAssertEqual(early.line, "The Cookery: 3 letters gone, none back yet.")
    }
}
