import Foundation

/// The standing pact under which the Book may arrange small pieces of ordinary
/// life. Consent is granted here, upstream; individual Workings remain
/// surprising. Every doorway is independently revocable.
struct BookWorkingAuthority: Codable, Equatable {
    var isEnabled = false
    var appetite: BookWorkingAppetite = .alive
    var allowsCalendarOpenings = true
    var allowsNotificationSummons = true
    var earliestHour = 17
    var latestHour = 22
    var grantedAt: Date?
    var pausedUntil: Date?

    static let sealed = BookWorkingAuthority()

    func isActive(at date: Date) -> Bool {
        isEnabled && (pausedUntil.map { $0 <= date } ?? true)
    }

    var hasAnOutsideDoorway: Bool {
        allowsCalendarOpenings || allowsNotificationSummons
    }
}

enum BookWorkingAppetite: String, Codable, CaseIterable, Equatable, Identifiable {
    case quiet
    case alive
    case unruly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: return "Quiet"
        case .alive: return "Alive"
        case .unruly: return "Unruly"
        }
    }

    var detail: String {
        switch self {
        case .quiet: return "About once a week."
        case .alive: return "Up to three times a week."
        case .unruly: return "Up to five times a week."
        }
    }

    var rollingWeekLimit: Int {
        switch self {
        case .quiet: return 1
        case .alive: return 3
        case .unruly: return 5
        }
    }

    var minimumGap: TimeInterval {
        switch self {
        case .quiet: return 5 * 86_400
        case .alive: return 36 * 3_600
        case .unruly: return 18 * 3_600
        }
    }
}

enum BookWorkingInitiatorKind: String, Codable, Equatable {
    case book
    case character
}

enum BookWorkingEffectKind: String, Codable, CaseIterable, Equatable {
    case calendarOpening
    case notificationSummons
    case widgetMark
}

enum BookWorkingEffectStatus: String, Codable, Equatable {
    case planned
    case executed
    case failed
    case cancelled
}

struct BookWorkingEffect: Codable, Equatable, Identifiable {
    var id: String
    var kind: BookWorkingEffectKind
    var status: BookWorkingEffectStatus = .planned
    var attemptedAt: Date?
    var detail: String?
}

enum BookWorkingStatus: String, Codable, Equatable {
    case prepared
    case arranged
    case elapsed
    case returned
    case cancelled
}

/// One causal chain from fictional motive to an attributable real-world mark.
struct BookWorking: Codable, Equatable, Identifiable {
    var id: String
    var recipeID: String
    var initiatorKind: BookWorkingInitiatorKind
    var initiatorID: String
    var initiatorName: String
    var title: String
    var summons: String
    var invitation: String
    var returnPrompt: String
    var createdAt: Date
    var startsAt: Date
    var endsAt: Date
    var status: BookWorkingStatus = .prepared
    var effects: [BookWorkingEffect]
    /// When a character initiated this from business already underway, keep
    /// the causal thread instead of making the attribution decorative.
    var sourceUndertakingID: String? = nil
    var returnedAt: Date?

    var didReachOutside: Bool {
        effects.contains { effect in
            effect.kind != .widgetMark && effect.status == .executed
        }
    }
}

struct BookWorkingLedger: Codable, Equatable {
    var authority: BookWorkingAuthority = .sealed
    var current: BookWorking?
    var history: [BookWorking] = []

    static let empty = BookWorkingLedger()

    mutating func advance(to now: Date) {
        guard var working = current, working.endsAt <= now else { return }
        if working.status != .cancelled {
            working.status = .elapsed
        }
        history.append(working)
        history = Array(history.sorted { $0.createdAt < $1.createdAt }.suffix(48))
        current = nil
    }

    mutating func recordEffect(
        workingID: String,
        kind: BookWorkingEffectKind,
        succeeded: Bool,
        detail: String? = nil,
        at date: Date
    ) {
        guard var working = current, working.id == workingID,
              let index = working.effects.firstIndex(where: { $0.kind == kind }) else { return }
        working.effects[index].status = succeeded ? .executed : .failed
        working.effects[index].attemptedAt = date
        working.effects[index].detail = detail
        if working.effects.contains(where: { $0.status == .executed }) {
            working.status = .arranged
        }
        current = working
    }

    mutating func recordReturn(workingID: String, at date: Date) {
        guard let index = history.firstIndex(where: { $0.id == workingID }) else { return }
        history[index].status = .returned
        history[index].returnedAt = date
    }

    mutating func cancelCurrent(at date: Date) -> BookWorking? {
        guard var working = current else { return nil }
        working.status = .cancelled
        working.effects = working.effects.map { effect in
            var copy = effect
            if copy.status == .planned || copy.status == .executed {
                copy.status = .cancelled
                copy.attemptedAt = date
            }
            return copy
        }
        history.append(working)
        history = Array(history.sorted { $0.createdAt < $1.createdAt }.suffix(48))
        current = nil
        return working
    }
}

struct BookWorkingContext: Equatable {
    var now: Date
    var calendarEvents: [CalendarEventSignal]
    var distressActive: Bool
    var activeUndertakings: [CastUndertaking] = []
}

struct BookWorkingPlan: Equatable {
    var ledger: BookWorkingLedger
    var newlyPrepared: BookWorking?
}

/// Pure policy for cadence, authorship, and open-time selection. Platform
/// effects are executed separately so a Working can never pretend a doorway
/// opened when EventKit or notifications actually refused it.
enum BookWorkingEngine {
    private struct Recipe {
        var id: String
        var initiatorKind: BookWorkingInitiatorKind
        var initiatorID: String
        var initiatorName: String
        var title: String
        var summons: String
        var invitation: String
        var returnPrompt: String
        var durationMinutes: Int
    }

    private static let recipes: [Recipe] = [
        Recipe(
            id: "book-stolen-opening",
            initiatorKind: .book,
            initiatorID: "the-book",
            initiatorName: "The Book",
            title: "An Opening the Book Stole",
            summons: "The Book has made a small opening in the day. It refuses to explain it in advance.",
            invitation: "Let the next ordinary thing choose the plot for forty minutes.",
            returnPrompt: "What happened in the opening the Book made? Bring back one exact detail.",
            durationMinutes: 40
        ),
        Recipe(
            id: "wicker-case-against-routine",
            initiatorKind: .character,
            initiatorID: "wicker-eddies",
            initiatorName: "Wicker Eddies",
            title: "Wicker Filed an Objection",
            summons: "Wicker has objected to the next forty minutes on grounds of predictability.",
            invitation: "Do one harmless thing the usual script would not have selected.",
            returnPrompt: "Was Wicker right about the script? Enter one piece of evidence.",
            durationMinutes: 40
        ),
        Recipe(
            id: "serenity-small-detour",
            initiatorKind: .character,
            initiatorID: "serenity-brown",
            initiatorName: "Serenity Brown",
            title: "Serenity Drew a Detour",
            summons: "Serenity has drawn a route too short to call a journey and too crooked to call efficient.",
            invitation: "Take a small detour and let it be enough of a reason by itself.",
            returnPrompt: "What did the detour contain that the direct route would have missed?",
            durationMinutes: 45
        ),
        Recipe(
            id: "trencher-table-kept-open",
            initiatorKind: .character,
            initiatorID: "ambrose-trencher",
            initiatorName: "Ambrose Trencher",
            title: "Trencher Kept a Table Open",
            summons: "Trencher has kept a little time aside. He says arriving hungry counts in more than one sense.",
            invitation: "Find something sustaining and give it your full attention, without making it productive.",
            returnPrompt: "What did Trencher's open table restore, even slightly?",
            durationMinutes: 40
        )
    ]

    static func reconcile(
        ledger original: BookWorkingLedger,
        context: BookWorkingContext,
        calendar: Calendar = .current
    ) -> BookWorkingPlan {
        var ledger = original
        ledger.advance(to: context.now)
        guard ledger.current == nil,
              ledger.authority.isActive(at: context.now),
              ledger.authority.hasAnOutsideDoorway,
              !context.distressActive else {
            return BookWorkingPlan(ledger: ledger, newlyPrepared: nil)
        }

        let cutoff = context.now.addingTimeInterval(-7 * 86_400)
        let recent = ledger.history.filter { $0.createdAt >= cutoff && $0.status != .cancelled }
        guard recent.count < ledger.authority.appetite.rollingWeekLimit else {
            return BookWorkingPlan(ledger: ledger, newlyPrepared: nil)
        }
        if let last = (ledger.history + [ledger.current].compactMap { $0 })
            .filter({ $0.status != .cancelled })
            .max(by: { $0.createdAt < $1.createdAt }),
           context.now.timeIntervalSince(last.createdAt) < ledger.authority.appetite.minimumGap {
            return BookWorkingPlan(ledger: ledger, newlyPrepared: nil)
        }

        let recipeSeed = stableNumber("\(calendar.component(.weekOfYear, from: context.now))-\(recent.count)-\(ledger.history.count)")
        let running = context.activeUndertakings.filter(\.isRunning)
        let characterRecipes = recipes.filter { recipe in
            running.contains(where: { $0.actorID == recipe.initiatorID })
        }
        // The Book keeps the house keys and occasionally signs its own name;
        // otherwise live character business gets first claim on authorship.
        let bookRecipe = recipes.first(where: { $0.initiatorKind == .book }) ?? recipes[0]
        let recipe: Recipe
        if !characterRecipes.isEmpty {
            recipe = recipeSeed % 4 == 0
                ? bookRecipe
                : characterRecipes[recipeSeed % characterRecipes.count]
        } else {
            recipe = recipes[recipeSeed % recipes.count]
        }
        guard let start = openStart(
            authority: ledger.authority,
            durationMinutes: recipe.durationMinutes,
            events: context.calendarEvents,
            now: context.now,
            seed: recipeSeed,
            calendar: calendar
        ) else {
            return BookWorkingPlan(ledger: ledger, newlyPrepared: nil)
        }
        let end = start.addingTimeInterval(TimeInterval(recipe.durationMinutes * 60))
        let id = "working-\(Int(context.now.timeIntervalSince1970))-\(recipe.id)"
        var effects: [BookWorkingEffect] = []
        if ledger.authority.allowsCalendarOpenings {
            effects.append(BookWorkingEffect(id: "\(id)-calendar", kind: .calendarOpening))
        }
        if ledger.authority.allowsNotificationSummons {
            effects.append(BookWorkingEffect(id: "\(id)-summons", kind: .notificationSummons))
        }
        effects.append(BookWorkingEffect(id: "\(id)-widget", kind: .widgetMark))
        let working = BookWorking(
            id: id,
            recipeID: recipe.id,
            initiatorKind: recipe.initiatorKind,
            initiatorID: recipe.initiatorID,
            initiatorName: recipe.initiatorName,
            title: recipe.title,
            summons: recipe.summons,
            invitation: recipe.invitation,
            returnPrompt: recipe.returnPrompt,
            createdAt: context.now,
            startsAt: start,
            endsAt: end,
            effects: effects,
            sourceUndertakingID: running.first(where: { $0.actorID == recipe.initiatorID })?.id
        )
        ledger.current = working
        return BookWorkingPlan(ledger: ledger, newlyPrepared: working)
    }

    private static func openStart(
        authority: BookWorkingAuthority,
        durationMinutes: Int,
        events: [CalendarEventSignal],
        now: Date,
        seed: Int,
        calendar: Calendar
    ) -> Date? {
        let earliest = now.addingTimeInterval(3 * 3_600)
        let horizon = now.addingTimeInterval(4 * 86_400)
        var candidates: [Date] = []
        for offset in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            for hour in authority.earliestHour..<authority.latestHour {
                for minute in stride(from: 0, through: 30, by: 30) {
                    var components = calendar.dateComponents([.year, .month, .day], from: day)
                    components.hour = hour
                    components.minute = minute
                    guard let start = calendar.date(from: components), start >= earliest, start < horizon else { continue }
                    let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
                    var close = calendar.dateComponents([.year, .month, .day], from: day)
                    close.hour = authority.latestHour
                    close.minute = 0
                    guard let closing = calendar.date(from: close), end <= closing else { continue }
                    let collides = events.contains { event in
                        guard !event.isAllDay else { return false }
                        let eventEnd = event.endsAt ?? event.startsAt.addingTimeInterval(3_600)
                        return start < eventEnd.addingTimeInterval(15 * 60)
                            && end > event.startsAt.addingTimeInterval(-15 * 60)
                    }
                    if !collides { candidates.append(start) }
                }
            }
        }
        guard !candidates.isEmpty else { return nil }
        // Vary among the first several genuinely open windows without hiding a
        // Working days away merely for pseudo-randomness.
        let near = Array(candidates.prefix(8))
        return near[seed % near.count]
    }

    private static func stableNumber(_ value: String) -> Int {
        let hash = value.utf8.reduce(2_166_136_261) { partial, byte in
            (partial ^ Int(byte)) &* 16_777_619
        }
        return hash & Int.max
    }
}
