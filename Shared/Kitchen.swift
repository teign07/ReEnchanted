import Foundation

// MARK: - The Kitchen
//
// Recipes in the Book. Every one is authored against a tested source and set
// down here by hand; nothing in this file writes or adjusts a recipe, and no
// model ever will (docs/kitchen-november-pack.md, house law 5). What the reader
// does with them is read back out of the archive: a recipe was made because a
// kept Page says so, never because a second ledger does.
// Plan: docs/kitchen-recipe-system.md.

/// Which shelf a recipe sits on in the Kitchen.
enum KitchenShelf: String, Codable, CaseIterable, Equatable {
    /// Somebody's own kitchen, set down faithfully: Gayle O'Brien's binder.
    case inherited
    /// *The Middlemost Cookery* and the Academy's own: the story's recipes.
    case cookery
    /// A real custom with a day attached: soul cakes, Stir-up Sunday.
    case custom
    /// The reader's own, rescued from somebody's hands.
    case rescued
}

/// Days a recipe belongs to, in the year's own terms. Month and day, inclusive,
/// and allowed to wrap the year end.
struct KitchenWindow: Codable, Equatable {
    var startMonth: Int
    var startDay: Int
    var endMonth: Int
    var endDay: Int

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return false }
        let value = month * 100 + day
        let start = startMonth * 100 + startDay
        let end = endMonth * 100 + endDay
        return start <= end ? (start...end).contains(value) : (value >= start || value <= end)
    }
}

struct KitchenRecipe: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var shelf: KitchenShelf
    /// Whose it is: "Gayle O'Brien, Mom", "The Middlemost Cookery".
    var credit: String?
    /// One line over the recipe: Ambrose's, or the Book's.
    var line: String
    var makes: String?
    var minutes: Int?
    /// As written. Allergens are named here too, in the words of the line.
    var ingredients: [String]
    /// The house allergen words this recipe carries: milk, egg, wheat, gluten,
    /// nuts, peanuts, soy, fish, shellfish, sesame, mustard, celery, sulphites.
    var allergens: [String]
    var steps: [String]
    /// The source's own note, word for word.
    var cookNote: String? = nil
    var window: KitchenWindow? = nil
    var months: [Int]? = nil
    var weatherTags: [String]? = nil
    /// What the margin asks, when the recipe wants its own question.
    var smellAsk: String? = nil
    var tags: [String] = []

    var marginAsk: String { smellAsk ?? "What did it smell like?" }

    func inSeason(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let months, !months.isEmpty else { return true }
        return months.contains(calendar.component(.month, from: date))
    }

    /// The recipe as one block of text, for a Page body, the printed books, and
    /// any surface that can only show prose.
    var printed: String {
        var parts: [String] = []
        if let credit = credit?.nonEmpty { parts.append("From \(credit).") }
        parts.append(line)
        var need = "You'll need"
        if let makes = makes?.nonEmpty { need += " (makes \(makes))" }
        parts.append(need + ":\n" + ingredients.map { "• \($0)" }.joined(separator: "\n"))
        parts.append("What you do:\n" + steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        if let note = cookNote?.nonEmpty { parts.append(note) }
        if !allergens.isEmpty { parts.append("Has in it: \(allergens.joined(separator: ", ")).") }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - What the reader did

enum KitchenOutcome: String, Codable, CaseIterable, Equatable {
    case made
    case madeBadly
    case notYet

    var tagPrefix: String {
        switch self {
        case .made: return "kitchen-made:"
        case .madeBadly: return "kitchen-badly:"
        case .notYet: return "kitchen-owed:"
        }
    }

    /// The chip on the Page.
    var chip: String {
        switch self {
        case .made: return "Made it"
        case .madeBadly: return "Made it badly"
        case .notYet: return "Not yet"
        }
    }

    var cooked: Bool { self != .notYet }

    func tags(recipeID: String) -> [String] {
        ["kitchen", "kitchen:\(recipeID)", tagPrefix + recipeID]
    }

    static func from(tags: [String], recipeID: String) -> KitchenOutcome? {
        allCases.first { tags.contains($0.tagPrefix + recipeID) }
    }
}

/// One time a recipe met the reader's kitchen: a kept Recipe Page.
struct KitchenWorking: Equatable {
    var recipeID: String
    var pageID: String
    var at: Date
    var outcome: KitchenOutcome
    /// The reader's own margin, word for word.
    var note: String?
    var weatherTags: [String]
}

/// A recipe the reader rescued from somebody's hands.
struct RescuedRecipe: Equatable, Identifiable {
    var id: String { pageID }
    var pageID: String
    var at: Date
    var title: String
    var whose: String?
    /// What they wrote down, as they wrote it.
    var text: String
}

enum KitchenLedger {
    static let rescuedTag = "kitchen-rescued"
    /// Metadata keys a Recipe Page carries, kept with it.
    static let recipeIDKey = "kitchenRecipeID"
    static let rescueTitleKey = "kitchenRescueTitle"
    static let rescueWhoseKey = "kitchenRescueWhose"

    /// Every Recipe Page the reader kept, oldest first.
    static func workings(in days: [BookDay]) -> [KitchenWorking] {
        var found: [KitchenWorking] = []
        for day in days {
            for page in day.pages where page.tags.contains("kitchen") {
                guard let id = page.tags.first(where: { $0.hasPrefix("kitchen:") })
                        .map({ String($0.dropFirst("kitchen:".count)) }),
                      let outcome = KitchenOutcome.from(tags: page.tags, recipeID: id) else { continue }
                found.append(KitchenWorking(
                    recipeID: id, pageID: page.id, at: page.createdAt, outcome: outcome,
                    note: page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
                    weatherTags: page.context?.weatherTags ?? []))
            }
        }
        return found.sorted { $0.at < $1.at }
    }

    static func workings(of recipeID: String, in days: [BookDay]) -> [KitchenWorking] {
        workings(in: days).filter { $0.recipeID == recipeID }
    }

    static func rescued(in days: [BookDay]) -> [RescuedRecipe] {
        var found: [RescuedRecipe] = []
        for day in days {
            for page in day.pages where page.tags.contains(rescuedTag) {
                let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let title = page.metadata?[rescueTitleKey]?.nonEmpty
                    ?? text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "A rescued recipe"
                found.append(RescuedRecipe(pageID: page.id, at: page.createdAt, title: title,
                                           whose: page.metadata?[rescueWhoseKey]?.nonEmpty, text: text))
            }
        }
        return found.sorted { $0.at < $1.at }
    }

    /// "the 3rd", "12 November": how the Book says a day it remembers.
    static func dayWords(_ date: Date, relativeTo now: Date, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: date)
        let sameMonth = calendar.isDate(date, equalTo: now, toGranularity: .month)
        if sameMonth { return "the \(ordinal(day))" }
        let month = monthNames[calendar.component(.month, from: date) - 1]
        return "\(day) \(month)"
    }

    /// The Book's own month names, whatever the device's locale prints.
    static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August",
                             "September", "October", "November", "December"]

    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// "in the rain", "in the cold": what the weather was, when it said.
    static func weatherWords(_ tags: [String]) -> String? {
        for (tag, words) in [("snow", "in the snow"), ("storm", "in a storm"), ("rain", "in the rain"),
                             ("fog", "in the fog"), ("frost", "on a frosty day"), ("wind", "in the wind"),
                             ("cold", "on a cold day")] where tags.contains(tag) {
            return words
        }
        return nil
    }

    /// The reader's earlier margins, printed above the steps the next time:
    /// "Last time: too much pepper. The 3rd, in the rain."
    static func lastTimeLine(for recipeID: String, in days: [BookDay], now: Date, calendar: Calendar = .current) -> String? {
        guard let last = workings(of: recipeID, in: days).last(where: { $0.outcome.cooked }) else { return nil }
        var when = dayWords(last.at, relativeTo: now, calendar: calendar)
        if let weather = weatherWords(last.weatherTags) { when += ", \(weather)" }
        let when1 = when.prefix(1).uppercased() + when.dropFirst()
        if let note = last.note {
            return "Last time: “\(note)” \(when1)."
        }
        return last.outcome == .madeBadly ? "Last time it went wrong. \(when1). Try again." : "You made this \(when)."
    }
}

// MARK: - Which recipe today

enum KitchenOffering {
    enum Reason: Equatable {
        /// Its day: soul cakes on All Souls' Eve.
        case itsDay
        /// Put down again: "I gave you this on the 3rd."
        case reoffer(owedSince: Date)
        /// The weather asked for it.
        case weather
        /// An ordinary day.
        case ordinary
    }

    struct Offer: Equatable {
        var recipe: KitchenRecipe
        var reason: Reason
    }

    /// A recipe made this recently rests.
    static let restAfterMaking: TimeInterval = 5 * 24 * 3_600
    /// The days after a "Not yet" on which Ambrose puts it down again.
    static let reofferDays: Set<Int> = [4, 11, 25]

    /// Today's recipe, or nil on a day without one. Deterministic for the day.
    static func offer(
        on date: Date,
        dayID: String,
        recipes: [KitchenRecipe] = KitchenRecipeRegistry.all,
        workings: [KitchenWorking],
        weatherTags: Set<String> = [],
        kitchenBusy: Bool,
        calendar: Calendar = .current
    ) -> Offer? {
        func lastMade(_ id: String) -> Date? { workings.last { $0.recipeID == id && $0.outcome.cooked }?.at }
        func resting(_ recipe: KitchenRecipe) -> Bool {
            guard let made = lastMade(recipe.id) else { return false }
            let since = date.timeIntervalSince(made)
            return since >= 0 && since < restAfterMaking
        }
        func draw(_ key: String) -> Int { abs("\(dayID)-kitchen-\(key)".stableHash.stableScramble) }
        func seeded(_ pool: [KitchenRecipe]) -> KitchenRecipe? {
            pool.min { draw($0.id) == draw($1.id) ? $0.id < $1.id : draw($0.id) < draw($1.id) }
        }
        let shelf = recipes.filter { $0.shelf != .rescued }

        // 1. Its day. Made already inside this window means it's done for the year.
        let pinned = shelf.filter { recipe in
            guard let window = recipe.window, window.contains(date, calendar: calendar) else { return false }
            guard let made = lastMade(recipe.id) else { return true }
            return date.timeIntervalSince(made) > 20 * 24 * 3_600
        }
        if let recipe = pinned.first { return Offer(recipe: recipe, reason: .itsDay) }

        // 2. Put down again: a "Not yet" that hasn't been made since, on a
        // few days spaced out after it, never every morning. After the last
        // of them Ambrose lets it go; it's still on the shelf.
        var owed: [(KitchenRecipe, Date)] = []
        for recipe in shelf {
            guard let latest = workings.last(where: { $0.recipeID == recipe.id }), latest.outcome == .notYet else { continue }
            let waited = calendar.dateComponents([.day], from: calendar.startOfDay(for: latest.at),
                                                 to: calendar.startOfDay(for: date)).day ?? 0
            guard reofferDays.contains(waited) else { continue }
            owed.append((recipe, latest.at))
        }
        if let (recipe, since) = owed.min(by: { $0.1 < $1.1 }) {
            return Offer(recipe: recipe, reason: .reoffer(owedSince: since))
        }

        // Out of the busy season the Kitchen keeps a quieter table: one day in three.
        if !kitchenBusy, draw("day") % 3 != 0 { return nil }

        let fresh = shelf.filter { $0.window == nil && $0.inSeason(date, calendar: calendar) && !resting($0) }

        // 3. The weather asked.
        let asked = fresh.filter { !Set($0.weatherTags ?? []).isDisjoint(with: weatherTags) }
        if let recipe = seeded(asked), draw("weather") % 2 == 0 {
            return Offer(recipe: recipe, reason: .weather)
        }

        // 4. Gayle's first on ordinary days, then the rest of the shelf. Never
        // the same recipe twice in a row of offered days if there's a choice.
        let inherited = fresh.filter { $0.shelf == .inherited }
        let unmadeInherited = inherited.filter { lastMade($0.id) == nil }
        if let recipe = seeded(unmadeInherited.isEmpty ? inherited : unmadeInherited),
           draw("shelf") % 3 != 0 {
            return Offer(recipe: recipe, reason: .ordinary)
        }
        guard let recipe = seeded(fresh) else { return nil }
        return Offer(recipe: recipe, reason: .ordinary)
    }

    /// Ambrose's line over a recipe he's putting down again. He doesn't nag.
    /// He puts it in front of you.
    static func reofferLine(since: Date, now: Date, calendar: Calendar = .current) -> String {
        "I gave you this on \(KitchenLedger.dayWords(since, relativeTo: now, calendar: calendar)). Here it is again. — A. T."
    }
}

// MARK: - The Cookery's count

/// *The Middlemost Cookery* loses letters while the Guest eats at the Academy's
/// table and gets them back when somebody makes the thing on the page. The
/// figures are Penny's (ContentPacks/the-guest), and the reader's kitchen adds
/// to the second column. It never decides an ending.
enum KitchenTally {
    static let lettersPerMade = 9
    static let lettersPerRescue = 12

    struct Count: Equatable {
        var gone: Int
        var back: Int
        /// The share of `back` that came from the reader's own kitchen.
        var fromReader: Int
        var made: Int
        var rescued: Int

        /// "214 letters gone, 17 back."
        var line: String {
            let goneWords = gone == 1 ? "1 letter gone" : "\(gone) letters gone"
            var line = "The Cookery: \(goneWords), \(back == 0 ? "none back yet" : "\(back) back")."
            if fromReader > 0 { line += " \(fromReader) of them came back from your kitchen." }
            return line
        }
    }

    private static let goneByDay: [(Int, Int)] = [(0, 0), (3, 0), (4, 1), (6, 3), (8, 11), (10, 40), (12, 214), (20, 231), (29, 240)]
    private static let academyBackByDay: [(Int, Int)] = [(0, 0), (13, 0), (14, 1), (17, 8), (20, 17), (25, 30), (29, 41)]

    static func interpolate(_ table: [(Int, Int)], at day: Int) -> Int {
        guard let first = table.first, let last = table.last else { return 0 }
        if day <= first.0 { return first.1 }
        if day >= last.0 { return last.1 }
        for (a, b) in zip(table, table.dropFirst()) where day >= a.0 && day <= b.0 {
            let span = Double(b.0 - a.0)
            let t = span == 0 ? 0 : Double(day - a.0) / span
            return a.1 + Int((Double(b.1 - a.1) * t).rounded(.down))
        }
        return last.1
    }

    /// The count on a live day of the event, with the reader's kitchen counted
    /// from the event's first day.
    static func count(liveDay: Int, eventStart: Date, days: [BookDay]) -> Count {
        let made = KitchenLedger.workings(in: days).filter { $0.outcome.cooked && $0.at >= eventStart }.count
        let rescued = KitchenLedger.rescued(in: days).filter { $0.at >= eventStart }.count
        let gone = interpolate(goneByDay, at: liveDay)
        let academy = interpolate(academyBackByDay, at: liveDay)
        let fromReader = min(made * lettersPerMade + rescued * lettersPerRescue, max(0, gone - academy))
        return Count(gone: gone, back: academy + fromReader, fromReader: fromReader, made: made, rescued: rescued)
    }
}

// MARK: - The Recipe Page

extension KitchenOffering {
    static let sourceID = "kitchen"
    static let rescueKey = "kitchenRescue"

    /// A recipe set out as a Page: whose it is, Ambrose's line, the reader's
    /// last margin over the steps, and the chips.
    static func surface(for recipe: KitchenRecipe, reason: Reason = .ordinary, dayID: String,
                        days: [BookDay], now: Date, score: Int? = nil, calendar: Calendar = .current) -> SurfacePage {
        var lead: [String] = []
        if case .reoffer(let since) = reason { lead.append(reofferLine(since: since, now: now, calendar: calendar)) }
        if let last = KitchenLedger.lastTimeLine(for: recipe.id, in: days, now: now, calendar: calendar) { lead.append(last) }
        let body = (lead + [recipe.printed]).joined(separator: "\n\n")
        var metadata: [String: String] = [
            "source": sourceID,
            KitchenLedger.recipeIDKey: recipe.id,
            "kitchenShelf": recipe.shelf.rawValue,
            "kitchenChips": KitchenOutcome.allCases.map(\.chip).joined(separator: "||"),
            "responseLabel": recipe.marginAsk,
            "placeholder": "What it smelled like, who ate it, what you'd change…",
            "tags": "kitchen,recipe,kitchen-offer:\(recipe.id)"
        ]
        if let credit = recipe.credit { metadata["kitchenCredit"] = credit }
        // Its own day is a single-day promise, like a feast: it gets first
        // claim on the visible desk or nobody ever meets it.
        if reason == .itsDay { metadata["milestone"] = "true" }
        let reasonLine: String
        switch reason {
        case .itsDay: reasonLine = "It's the day for it."
        case .reoffer: reasonLine = "Ambrose put it down again."
        case .weather: reasonLine = "The weather asked for it."
        case .ordinary: reasonLine = recipe.credit.map { "From \($0)." } ?? "From the Kitchen."
        }
        let defaultScore: Int
        switch reason {
        case .itsDay: defaultScore = 82
        case .reoffer: defaultScore = 70
        case .weather: defaultScore = 64
        case .ordinary: defaultScore = 58
        }
        return SurfacePage(
            id: "recipe-\(recipe.id)-\(dayID)",
            type: .recipe,
            sourceID: sourceID,
            intent: .capture,
            renderStyle: .loreLetter,
            score: score ?? defaultScore,
            reason: reasonLine,
            prompt: recipe.title,
            detail: recipe.line,
            payload: BookPagePayload(headline: recipe.title, body: body, metadata: metadata)
        )
    }

    /// The Page for writing somebody's recipe down before it goes missing.
    static func rescueSurface(dayID: String) -> SurfacePage {
        SurfacePage(
            id: "recipe-rescue-\(dayID)",
            type: .recipe,
            sourceID: sourceID,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 60,
            reason: "Somebody's recipe, before it goes missing.",
            prompt: "Rescue a Recipe",
            detail: "Write it down the way they said it.",
            payload: BookPagePayload(
                headline: "Rescue a Recipe",
                body: """
                Somebody near you makes a thing by feel. They've made it a hundred times. If you asked them how much salt, they'd say “enough”, and hold up a pinch of air.

                Those are the ones that go first.

                Write it down here, the way they told you. “Enough” is a real measurement. “Till it looks right” is a real time. Put whose it is at the top. I'll keep it in the Kitchen where it can't go missing.
                """,
                metadata: [
                    "source": sourceID,
                    rescueKey: "true",
                    "responseLabel": "How they make it",
                    "placeholder": "What you need, and what you do, the way they said it…",
                    "tags": "kitchen,recipe,\(KitchenLedger.rescuedTag)"
                ]
            )
        )
    }

    static func isRescue(_ surface: SurfacePage) -> Bool {
        surface.type == .recipe && surface.payload.metadata[rescueKey] == "true"
    }

    /// The tags a kept Recipe Page carries. A recipe kept without a chip is
    /// kept for later: "Not yet".
    static func keepTags(for surface: SurfacePage, outcome: KitchenOutcome?) -> [String] {
        guard surface.type == .recipe, !isRescue(surface),
              let id = surface.payload.metadata[KitchenLedger.recipeIDKey]?.nonEmpty else { return [] }
        return (outcome ?? .notYet).tags(recipeID: id)
    }

    /// Ambrose answers when a Recipe Page is kept. He doesn't make a fuss.
    static func keepNote(for surface: SurfacePage, outcome: KitchenOutcome?, hasReaderContribution: Bool) -> KeepMarginalia.Note? {
        guard surface.type == .recipe else { return nil }
        let lines: [String]
        if isRescue(surface) {
            guard hasReaderContribution else { return nil }
            lines = ["Kept. Safe now. That's one that won't go missing.",
                     "Always write whose it is. You did. Good.",
                     "That's one more page the Cookery didn't have."]
        } else {
            switch outcome ?? .notYet {
            case .made:
                lines = ["Good. Now you know where it lives.",
                         "That's one back on the table.",
                         "Write down what you'd change. Then don't change it for a year."]
            case .madeBadly:
                lines = ["Badly's how everybody starts. Do it again on a day nobody's watching.",
                         "That's the one I'd rather hear about. Again, when you're ready.",
                         "Burnt's a flavour. Not a good one. Next time, lower."]
            case .notYet:
                lines = ["It'll keep. I'll put it down again.",
                         "No hurry. Recipes wait. That's what they're for."]
            }
        }
        let line = lines[abs(surface.id.stableHash) % lines.count]
        return KeepMarginalia.Note(castSlug: "ambrose-trencher", castName: "Ambrose Trencher",
                                   assetName: "LabyrinthCharacterAmbroseTrencher", line: line)
    }
}

/// The Kitchen on the desk: at most one recipe a day.
struct KitchenRecipePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .recipe)

    static let busyEventIDs: Set<String> = ["the-guest"]

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, let offer = offer(for: day, inputs: inputs, now: now) else { return [] }
        return [KitchenOffering.surface(for: offer.recipe, reason: offer.reason, dayID: day.id,
                                        days: inputs.days + [day], now: now)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        if let offer = offer(for: day, inputs: inputs, now: now) {
            return KitchenOffering.surface(for: offer.recipe, reason: offer.reason, dayID: day.id,
                                           days: inputs.days + [day], now: now)
        }
        return KitchenOffering.rescueSurface(dayID: day.id)
    }

    /// The Kitchen opens with the story: All Souls' Eve-eve, when Ambrose starts
    /// the soul cakes. Before that nothing's on the desk, so the first recipe a
    /// reader ever meets is the one the Guest knocks for.
    static let opensOn = DateComponents(year: 2026, month: 10, day: 30)

    static func isOpen(on now: Date, calendar: Calendar = .current) -> Bool {
        guard let opening = calendar.date(from: opensOn) else { return true }
        return now >= calendar.startOfDay(for: opening)
    }

    func offer(for day: BookDay, inputs: BookSourceInputs, now: Date) -> KitchenOffering.Offer? {
        guard Self.isOpen(on: now) else { return nil }
        let busy = Calendar.current.component(.month, from: now) == 11
            || inputs.activeWorldEvents.contains { Self.busyEventIDs.contains($0.id) }
        let weather = RadioPageContext.weatherTags(weather: inputs.weather, enchanted: inputs.enchantedWeather)
        return KitchenOffering.offer(on: now, dayID: day.id,
                                     workings: KitchenLedger.workings(in: inputs.days + [day]),
                                     weatherTags: weather, kitchenBusy: busy)
    }
}

// MARK: - The Kitchen room

struct KitchenShelfEntry: Identifiable, Equatable {
    var id: String
    var title: String
    var credit: String?
    var line: String
    /// "Made 3 times. Last on the 12th, in the rain."
    var madeLine: String
    /// The reader's own margins, newest first.
    var notes: [String]
    var recipe: KitchenRecipe?
    var rescued: RescuedRecipe?
}

struct KitchenShelfSection: Identifiable, Equatable {
    var id: String { shelf.rawValue }
    var shelf: KitchenShelf
    var title: String
    var entries: [KitchenShelfEntry]
}

enum KitchenRoom {
    static let contentsDetail = "Recipes, and every time you made one."

    static func title(for shelf: KitchenShelf) -> String {
        switch shelf {
        case .inherited: return KitchenRecipeRegistry.gayle
        case .cookery: return "The Middlemost Cookery"
        case .custom: return "For the Days"
        case .rescued: return "Rescued"
        }
    }

    static func madeLine(for workings: [KitchenWorking], now: Date, calendar: Calendar = .current) -> String {
        let cooked = workings.filter { $0.outcome.cooked }
        guard let last = cooked.last else {
            if let owed = workings.last { return "Not made yet. You kept it on \(KitchenLedger.dayWords(owed.at, relativeTo: now, calendar: calendar))." }
            return "Not made yet."
        }
        let times = cooked.count == 1 ? "once" : cooked.count == 2 ? "twice" : "\(cooked.count) times"
        var line = "Made \(times). Last on \(KitchenLedger.dayWords(last.at, relativeTo: now, calendar: calendar))"
        if let weather = KitchenLedger.weatherWords(last.weatherTags) { line += ", \(weather)" }
        line += "."
        if last.outcome == .madeBadly { line += " It went wrong." }
        return line
    }

    /// The whole room: Gayle's first, then the days, the Cookery, and what the reader rescued.
    static func sections(days: [BookDay], now: Date, recipes: [KitchenRecipe] = KitchenRecipeRegistry.all,
                         calendar: Calendar = .current) -> [KitchenShelfSection] {
        let workings = KitchenLedger.workings(in: days)
        let order: [KitchenShelf] = [.inherited, .custom, .cookery]
        var sections: [KitchenShelfSection] = order.compactMap { shelf in
            let entries = recipes.filter { $0.shelf == shelf }.map { recipe -> KitchenShelfEntry in
                let mine = workings.filter { $0.recipeID == recipe.id }
                return KitchenShelfEntry(
                    id: recipe.id, title: recipe.title, credit: recipe.credit, line: recipe.line,
                    madeLine: madeLine(for: mine, now: now, calendar: calendar),
                    notes: mine.reversed().compactMap(\.note), recipe: recipe, rescued: nil)
            }
            return entries.isEmpty ? nil : KitchenShelfSection(shelf: shelf, title: title(for: shelf), entries: entries)
        }
        let rescued = KitchenLedger.rescued(in: days).reversed().map { found in
            KitchenShelfEntry(
                id: found.pageID, title: found.title, credit: found.whose, line: found.text,
                madeLine: "Rescued on \(KitchenLedger.dayWords(found.at, relativeTo: now, calendar: calendar)).",
                notes: [], recipe: nil, rescued: found)
        }
        sections.append(KitchenShelfSection(shelf: .rescued, title: title(for: .rescued), entries: Array(rescued)))
        return sections
    }
}

// MARK: - The Kitchen in the paper

extension KitchenTally {
    static let eventID = "the-guest"

    /// The live day of the Guest's month on `date`, or nil when it isn't running.
    static func liveDay(on date: Date, inputs: BookSourceInputs, calendar: Calendar = .current) -> (day: Int, start: Date)? {
        guard let event = inputs.activeWorldEvents.first(where: { $0.id == eventID }), date < event.endsAt else { return nil }
        let day = calendar.dateComponents([.day], from: calendar.startOfDay(for: event.startedAt),
                                          to: calendar.startOfDay(for: date)).day ?? 0
        return day >= 0 ? (day, event.startedAt) : nil
    }

    /// Ambrose chalks the day's menu as one sentence about the weather.
    static func chalkboard(weatherTags: Set<String>, dayID: String) -> String {
        let lines: [(String, [String])] = [
            ("snow", ["Soup. It's snowing. Come in and shut the door.", "Porridge with treacle. Snow doesn't care what you've got on."]),
            ("rain", ["Soup. It's raining; you knew that.", "Something hot under a lid. Wipe your feet."]),
            ("fog", ["Stew. Can't see the end of the yard, so stay in.", "Bread and soup. The fog's eaten the garden."]),
            ("frost", ["Porridge, and wear the other socks.", "Toast and dripping. Mind the step, it's glass."]),
            ("wind", ["Pie. Hold on to your hat.", "Something heavy enough to keep you on the ground."]),
            ("cold", ["Porridge, and wear the other socks.", "Soup, and a heel of bread each. It's cold."]),
            ("bright", ["Sandwiches. Eat them outside while it lasts.", "Bread and cheese. Go and stand in the sun."]),
        ]
        let pick = abs("chalk-\(dayID)".stableHash.stableScramble)
        for (tag, options) in lines where weatherTags.contains(tag) { return options[pick % options.count] }
        let plain = ["Whatever's in the pot. It's a grey sort of day.", "Bread, soup, an apple. An ordinary day.",
                     "Shepherd's pie. Nothing's happening outside worth mentioning."]
        return plain[pick % plain.count]
    }

    /// The Kitchens' two lines for the paper's Academy box, while the Guest is in the house.
    static func bleedLines(on date: Date, inputs: BookSourceInputs, calendar: Calendar = .current) -> [String] {
        guard let live = liveDay(on: date, inputs: inputs, calendar: calendar) else { return [] }
        let weather = RadioPageContext.weatherTags(weather: inputs.weather, enchanted: inputs.enchantedWeather)
        var lines = ["ON THE KITCHENS' BOARD\n\(chalkboard(weatherTags: weather, dayID: BookDay.id(for: date, calendar: calendar)))"]
        let count = count(liveDay: live.day, eventStart: live.start, days: inputs.days)
        if count.gone > 0 { lines.append("THE COOKERY, COUNTED\n\(count.line) Figures: P. Blackletter.") }
        return lines
    }
}
