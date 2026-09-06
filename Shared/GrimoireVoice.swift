import Foundation

/// How the Book says what it has learned.
///
/// The register is the plain one: short sentences, first person, no hedging
/// words. Uncertainty is carried by the *promise* the Book makes about what
/// would prove it wrong, never by softening the sentence into mush. A Book that
/// says "this may perhaps suggest" has not noticed anything.
///
/// Things around the Book have moods — the pencil, the ink, the margin — but
/// one per line at most. Any more and it stops being a Book and starts being a
/// cartoon.
enum GrimoireVoice {

    // MARK: Small helpers

    static func seasonName(_ index: Int) -> String {
        switch index {
        case 1: return "spring"
        case 2: return "summer"
        case 3: return "autumn"
        default: return "winter"
        }
    }

    static func spelled(_ count: Int) -> String {
        switch count {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(count) times"
        }
    }

    /// Small numbers written out, the way somebody writing by hand would.
    static func spelledCount(_ count: Int) -> String {
        switch count {
        case 1: return "One"
        case 2: return "Two"
        case 3: return "Three"
        case 4: return "Four"
        case 5: return "Five"
        case 6: return "Six"
        case 7: return "Seven"
        case 8: return "Eight"
        case 9: return "Nine"
        case 10: return "Ten"
        default: return "\(count)"
        }
    }

    static func counted(_ count: Int, _ singular: String, _ plural: String) -> String {
        count == 1 ? "one \(singular)" : "\(count) \(plural)"
    }

    static func opening(_ clause: String) -> String {
        guard let first = clause.first else { return clause }
        return first.uppercased() + clause.dropFirst()
    }

    private static func seed(_ row: GrimoireCorrespondence) -> UInt64 {
        var value: UInt64 = 5_381
        for byte in row.id.utf8 { value = (value &* 33) &+ UInt64(byte) }
        return value
    }

    // MARK: The claim

    /// The correspondence, stated flat. No "may", no "seems", no "tends to".
    static func claim(
        row: GrimoireCorrespondence,
        stats: GrimoireStats,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        guard let condition = ledger.ref(row.conditionID) else { return "" }
        let outcome = row.outcomeID.flatMap { ledger.ref($0) }
        let salt = UInt64(stats.inHits)

        switch row.shape {
        case .conditional:
            guard let outcome else { return "" }
            return ReflectiveProse.pick([
                "When \(condition.conditionClause), \(outcome.outcomeClause). It keeps going that way.",
                "\(opening(condition.conditionClause)), and \(outcome.outcomeClause). Those two travel together.",
                "I've started expecting this. When \(condition.conditionClause), \(outcome.outcomeClause).",
                "Here is one of your own rules: when \(condition.conditionClause), \(outcome.outcomeClause)."
            ], seed: seed(row), salt: salt)

        case .sequential:
            guard let outcome else { return "" }
            return ReflectiveProse.pick([
                "\(opening(condition.conditionClause)) comes first. Then, inside a few days, \(outcome.outcomeClause).",
                "\(opening(condition.conditionClause)) goes ahead, and \(outcome.outcomeClause) follows a day or three later.",
                "One leads and one follows. First \(condition.conditionClause). Then \(outcome.outcomeClause)."
            ], seed: seed(row), salt: salt)

        case .sibling:
            guard let outcome else { return "" }
            // A comparison is only worth making out loud if it names what lost.
            guard let rival = row.rivalID.flatMap({ ledger.ref($0) }) else {
                return "Of the two, it's \(condition.label) that does it: \(outcome.outcomeClause)."
            }
            return ReflectiveProse.pick([
                "Of the two, it's \(condition.label) that does it: \(outcome.outcomeClause). \(opening(rival.label)) doesn't.",
                "\(opening(condition.label)) does this and \(rival.label) doesn't: \(outcome.outcomeClause).",
                "Not both. \(opening(condition.label)) is the one where \(outcome.outcomeClause). \(opening(rival.label)) leaves it alone."
            ], seed: seed(row), salt: salt)

        case .seasonal:
            let offering = GrimoireLedger.SeasonOffering(universe: ledger.universe)
            let season = row.season.flatMap {
                ledger.seasonalStanding(of: ledger.days(of: condition.id), in: $0, offering: offering)
            } ?? ledger.seasonalStanding(of: ledger.days(of: condition.id), offering: offering)
            let name = seasonName(season?.season ?? 0)
            let kept = season?.present ?? stats.seasonsPresent
            let missed = season?.missed ?? stats.seasonsMissed
            if missed == 1 {
                return "\(opening(condition.label)) belongs to your \(name). Every \(name) but one."
            }
            if missed > 1 {
                return "\(opening(condition.label)) is a \(name) thing for you. \(spelled(kept).capitalized(firstOnly: true)), with \(missed) \(name)s that went quiet."
            }
            return ReflectiveProse.pick([
                "\(opening(condition.label)) is one of your \(name) things. \(kept) \(name)s running.",
                "Every \(name), \(condition.label) comes back to you. \(kept) of them now.",
                "You keep an appointment you never made: \(condition.label), every \(name)."
            ], seed: seed(row), salt: UInt64(kept))

        case .returnInterval:
            let standing = ledger.returnStanding(of: ledger.days(of: condition.id))
            let times = standing?.returns ?? 0
            let months = max(1, (standing?.typicalGap ?? 30) / 30)
            let away = months == 1 ? "about a month" : "about \(spelledCount(months).lowercased()) months"
            return ReflectiveProse.pick([
                "\(opening(condition.label)) goes away and comes back. \(spelledCount(times)) times now, gone \(away) each time.",
                "You put \(condition.label) down for \(away), and then you pick it up again. \(spelledCount(times)) times.",
                "\(opening(condition.label)) isn't finished with you. It leaves for \(away) and returns. \(spelledCount(times)) times so far."
            ], seed: seed(row), salt: UInt64(times))
        }
    }

    // MARK: The receipts

    /// The counts, plainly, with the comparison that makes them mean anything.
    /// The Book shows the other days too — a number without its contrast is
    /// just a number wearing a coat.
    static func evidence(
        row: GrimoireCorrespondence,
        stats: GrimoireStats,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        if row.shape == .seasonal {
            let kept = counted(stats.seasonsPresent, "year", "years")
            guard stats.seasonsMissed > 0 else { return "\(kept.capitalized(firstOnly: true)), no misses." }
            return "\(kept.capitalized(firstOnly: true)). \(counted(stats.seasonsMissed, "year", "years").capitalized(firstOnly: true)) missed."
        }
        let there = "\(stats.inHits) of \(stats.inCount)"
        let elsewhere = "\(stats.outHits) of \(stats.outCount)"
        var line = "\(there) times. On the other days, \(elsewhere)."
        if stats.distinctYears > 1 {
            line += " Across \(counted(stats.distinctYears, "year", "years"))."
        }
        return line
    }

    /// Whether a correspondence has been coming loose, said plainly.
    ///
    /// The Book has always measured this — the early and late halves of the
    /// archive are two more popcounts — but until now it had no way to mention
    /// it, and a rule that is quietly weakening is more interesting than one
    /// that is merely true.
    static func drift(row: GrimoireCorrespondence, stats: GrimoireStats) -> String? {
        guard row.shape != .seasonal else { return nil }
        guard stats.earlyRate > 0 || stats.lateRate > 0 else { return nil }
        guard stats.inHits >= 6 else { return nil }
        if stats.earlyRate - stats.lateRate >= 0.3 {
            return ReflectiveProse.pick([
                "It used to be steadier than this. It has been coming loose.",
                "This held harder in the early Pages. Lately it slips.",
                "I'm watching this one weaken. Not gone. Thinner."
            ], seed: seed(row), salt: UInt64(stats.inHits))
        }
        if stats.lateRate - stats.earlyRate >= 0.3 {
            return ReflectiveProse.pick([
                "This is getting stronger, not weaker.",
                "It was occasional once. Lately it's nearly the rule.",
                "Whatever this is, it has been tightening."
            ], seed: seed(row), salt: UInt64(stats.inHits))
        }
        return nil
    }

    /// What the Book had to see before it would say this at all.
    static func provenance(row: GrimoireCorrespondence, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return "I started counting this in \(formatter.string(from: row.firstObservedAt))."
    }

    // MARK: The promise

    /// The falsifier, said as a dare rather than a hedge. This is what buys the
    /// Book the right to state the claim flatly in the first place.
    static func promise(
        row: GrimoireCorrespondence,
        stats: GrimoireStats,
        ledger: GrimoireLedger
    ) -> String {
        let chances = max(3, min(8, stats.inCount / 2))
        guard let condition = ledger.ref(row.conditionID) else {
            return "Give me \(chances) more chances. If it stops, this gets crossed out."
        }
        if row.shape == .seasonal {
            let season = row.season
                ?? ledger.seasonalStanding(of: ledger.days(of: condition.id))?.season
                ?? 0
            return "If \(seasonName(season)) comes round with no sign of it, this gets crossed out."
        }
        // The outcome is referred to, never embedded. `outcomeClause` is a
        // finished past-tense statement — "you wrote the word lantern" — and
        // dropping it where a noun belongs produces "if you wrote the word
        // lantern stops following". A label can be plural, too, so it never
        // becomes the subject of a verb either. The condition sits in place
        // fine: it is written as a clause on purpose.
        guard row.outcomeID != nil else {
            return "\(chances) more times. If it stops holding, this gets crossed out."
        }
        return ReflectiveProse.pick([
            "\(chances) more turns of \(condition.label). If it mostly stops following, this gets crossed out.",
            "Watch it with me. \(chances) more turns of \(condition.label). If it stops, the pencil comes out and this goes.",
            "\(chances) more chances. If it stops, I was wrong, and I will say so out loud.",
            // The Book knowing its own telling is not evidence.
            "\(chances) more turns of \(condition.label). I won't count the week after I told you — those days heard me. If it stops after that, this gets crossed out."
        ], seed: seed(row), salt: UInt64(chances))
    }

    // MARK: Being wrong

    /// The Book taking a claim back, out loud. This is content, not cleanup: a
    /// grimoire that has never crossed anything out has never been used.
    static func crossingOut(
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        guard let condition = ledger.ref(row.conditionID) else { return "" }
        let reason = row.revisions.last(where: { $0.to == .crossedOut })?.because
        let outcome = row.outcomeID.flatMap { ledger.ref($0) }
        let said: String
        if let outcome {
            said = "I said that when \(condition.conditionClause), \(outcome.outcomeClause)."
        } else {
            said = "I said \(condition.label) belonged to one turn of your year."
        }
        let because = reason.map { " Then \($0)." } ?? ""
        return ReflectiveProse.pick([
            "\(said)\(because) I was wrong. It's crossed out, and the crossing-out stays.",
            "\(said)\(because) The pencil is back out. I'd rather be corrected than tidy.",
            "\(said)\(because) Not true after all. I'm leaving the line where it was so you can see me change my mind."
        ], seed: seed(row), salt: UInt64(row.revisions.count))
    }

    /// What the Book says when the reader answers back. Mirrors the wording the
    /// rest of the Book already uses so a reader never meets two Books.
    static func answer(to status: BookObservationStatus) -> String {
        status.feedbackReactionLine
    }

    // MARK: Whole pages

    /// Claim, receipts, and promise together — the shape a grimoire entry takes
    /// wherever it lands.
    static func entry(
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        guard let stats = ledger.currentStats(for: row, calendar: calendar) else { return "" }
        if row.state == .crossedOut {
            return crossingOut(row: row, ledger: ledger, calendar: calendar)
        }
        let lines = [
            claim(row: row, stats: stats, ledger: ledger, calendar: calendar),
            evidence(row: row, stats: stats, ledger: ledger, calendar: calendar),
            drift(row: row, stats: stats),
            row.falsifier?.line ?? promise(row: row, stats: stats, ledger: ledger)
        ]
        return lines.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// A seasonal correspondence, as something to keep.
    ///
    /// The Book does not invent the observance — the reader has already been
    /// doing it, for years, without either of them calling it anything. All the
    /// Book does is give it a name and start expecting it.
    static func observance(
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> (title: String, line: String)? {
        guard row.shape == .seasonal else { return nil }
        guard let condition = ledger.ref(row.conditionID) else { return nil }
        guard let standing = ledger.seasonalStanding(
            of: ledger.days(of: condition.id), calendar: calendar
        ), standing.present >= 2 else { return nil }
        let season = seasonName(standing.season)
        let years = counted(standing.present, "year", "years")
        return (
            title: "\(opening(condition.label)), Every \(season.capitalized(firstOnly: true))",
            line: "Do it again. You've \(years) of it behind you and I've started expecting it."
        )
    }

    // MARK: While you were gone

    /// The one thing from a tend worth mentioning later, chosen now while the
    /// rows are to hand.
    static func tendingLine(
        found: [String],
        crossedOut: [String],
        in ledger: GrimoireLedger
    ) -> String? {
        // Taking something back outranks finding something. The Book owing a
        // correction is more interesting than the Book pleased with itself.
        if let id = crossedOut.first,
           let row = ledger.row(id),
           let condition = ledger.ref(row.conditionID) {
            // One clause, no full stop: `residue` attaches the timing to it.
            return "The pencil got at the \(condition.label) one and crossed it out"
        }
        if let id = found.first,
           let row = ledger.row(id),
           let condition = ledger.ref(row.conditionID) {
            return "\(opening(condition.label)) kept turning up, so the pencil started a tally"
        }
        return nil
    }

    /// A mark left on the binding-space between two Pages.
    ///
    /// The Book worked while nobody was here — the sweep genuinely runs on
    /// idle — so this is a receipt, not a flourish.
    ///
    /// The absence is the *timing*, never the subject. "While you were out, I
    /// was working" puts the reader's leaving at the front of the sentence and
    /// makes it something to answer for. The pencil does the acting; the reader
    /// simply comes back and finds the room has carried on.
    static func residue(_ mark: GrimoireTendingMark) -> String? {
        guard mark.isWorthMentioning else { return nil }
        if let line = mark.line { return "\(line) while you were out." }
        if mark.crossedOut > 0 {
            return mark.crossedOut == 1
                ? "One got crossed out while you were out."
                : "\(spelledCount(mark.crossedOut)) got crossed out while you were out."
        }
        return mark.found == 1
            ? "The pencil started a tally while you were out."
            : "\(spelledCount(mark.found)) new tallies, started while you were out."
    }

    // MARK: The whole body of it

    /// How many of each kind the folio prints before it starts counting
    /// instead. A page that lists forty laws is a database; a page that lists
    /// three and says there are forty more is a grimoire.
    static let folioStandingShown = 3
    static let folioCrossedShown = 2

    /// The same claim with the framing taken off.
    ///
    /// `claim` varies its opening on purpose so a Notice never reads as a
    /// template. In a *list* that is exactly wrong: three lines each beginning
    /// "Here is one of your own rules:" is a wrapper repeating itself, and the
    /// eye stops reading the part that differs. Down a page the framing should
    /// be identical so the content is the only thing that moves.
    static func plainClaim(
        row: GrimoireCorrespondence,
        stats: GrimoireStats,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        guard let condition = ledger.ref(row.conditionID) else { return "" }
        let outcome = row.outcomeID.flatMap { ledger.ref($0) }
        switch row.shape {
        case .conditional:
            guard let outcome else { return "" }
            return "When \(condition.conditionClause), \(outcome.outcomeClause)."
        case .sequential:
            guard let outcome else { return "" }
            return "\(opening(condition.conditionClause)), and then \(outcome.outcomeClause) within a few days."
        case .sibling:
            guard let outcome else { return "" }
            guard let rival = row.rivalID.flatMap({ ledger.ref($0) }) else {
                return "Of the two, it's \(condition.label) that brings \(outcome.outcomeClause)."
            }
            return "\(opening(condition.label)), not \(rival.label): \(outcome.outcomeClause)."
        case .seasonal:
            let season = ledger.seasonalStanding(of: ledger.days(of: condition.id), calendar: calendar)
            return "\(opening(condition.label)), every \(seasonName(season?.season ?? 0))."
        case .returnInterval:
            return "\(opening(condition.label)) goes quiet, and comes back."
        }
    }

    /// One law, compressed to a line: what it is, what it rests on, when it
    /// started. Long enough to be a claim, short enough to sit in a list.
    static func law(
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current,
        /// A rule the Book is still betting on has not been *sure* of anything.
        /// Saying so on both would make the page contradict itself.
        settled: Bool = true
    ) -> String? {
        guard let stats = ledger.currentStats(for: row, calendar: calendar) else { return nil }
        let claim = plainClaim(row: row, stats: stats, ledger: ledger, calendar: calendar)
        guard !claim.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        let month = formatter.string(from: row.firstObservedAt)
            .split(separator: " ").first.map(String.init) ?? ""
        if row.shape == .seasonal {
            return "\(claim) \(counted(stats.seasonsPresent, "year so far", "years so far").capitalized(firstOnly: true))."
        }
        let held = settled
            ? "I've been sure since \(month)"
            : "I've been counting since \(month)"
        return "\(claim) \(stats.inHits) times out of \(stats.inCount), and \(held)."
    }

    /// Everything the Book has worked out, as one page.
    ///
    /// Deliberately not a list of everything: the standing laws it is surest
    /// of, whatever it is currently betting on, and what it has already had to
    /// cross out — then a count of the rest. The crossings-out are the part
    /// that makes it read as a used book rather than a clever readout, so they
    /// are never the section that gets dropped for space.
    ///
    /// Returns nil while the Book has nothing settled enough to show.
    static func folio(
        ledger: GrimoireLedger,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let alive = ledger.rows.values.filter { $0.isAlive && $0.hasSpoken }
        let standing = alive
            .filter { $0.state == .standing }
            .sorted { $0.strengthPeak > $1.strengthPeak }
        let betting = alive
            .filter { $0.state == .spoken }
            .sorted { ($0.lastSpokenAt ?? .distantPast) > ($1.lastSpokenAt ?? .distantPast) }
        let crossed = ledger.crossedOut
            .sorted { ($0.revisions.last?.at ?? .distantPast) > ($1.revisions.last?.at ?? .distantPast) }
        guard !standing.isEmpty || !betting.isEmpty || !crossed.isEmpty else { return nil }

        var parts: [String] = ["Things I worked out about you. Nobody told me any of it."]
        // Two shapes can find the same pair — a same-day reading and a
        // follows-within-a-few-days reading of the same two things — and each
        // renders differently once its counts are attached. Deduping on the
        // finished sentence therefore misses it, and the page ends up holding
        // a rule in one section and crossing the same rule out in another.
        //
        // A claim's identity is its pair, not its wording, and the sections are
        // tried in order, so what the Book *holds* wins over what it took back.
        var printed = Set<String>()
        func fresh(_ row: GrimoireCorrespondence) -> Bool {
            printed.insert("\(row.conditionID)|\(row.outcomeID ?? "-")").inserted
        }

        let shownStanding = standing
            .filter { fresh($0) }
            .compactMap { law(row: $0, ledger: ledger, calendar: calendar) }
            .prefix(folioStandingShown)
        if !shownStanding.isEmpty {
            var block = ["Sure of these:"] + shownStanding.map { "• \($0)" }
            let rest = max(0, standing.filter { $0.outcomeID != nil }.count - shownStanding.count)
            if rest > 0 {
                block.append(rest == 1
                    ? "One more like that, tucked behind."
                    : "\(spelledCount(rest)) more like those, tucked behind.")
            }
            parts.append(block.joined(separator: "\n"))
        }

        if let bet = betting.first(where: { fresh($0) }),
           let line = law(row: bet, ledger: ledger, calendar: calendar, settled: false) {
            var block = ["Still betting on this one:", "• \(line)"]
            if let promise = bet.falsifier?.line { block.append(promise) }
            parts.append(block.joined(separator: "\n"))
        }

        // What it is chewing on. Until now the Book kept every half-formed
        // thing to itself and only ever showed conclusions, which is why it
        // could seem to arrive at convictions out of nowhere.
        let turning = ledger.rows.values
            .filter { $0.state == .watching && $0.outcomeID != nil }
            .sorted { $0.interestPeak > $1.interestPeak }
        if let chewing = turning.first(where: { fresh($0) }),
           let stats = ledger.currentStats(for: chewing, calendar: calendar) {
            let claim = plainClaim(row: chewing, stats: stats, ledger: ledger, calendar: calendar)
            if !claim.isEmpty {
                // How *often*, not how long. `firstObservedAt` is where the
                // evidence starts, so a day count here reads as "258 days now",
                // which sounds like the Book has been staring at a wall. What
                // makes it read as unfinished is that it has not seen enough.
                let so = stats.inHits == 1 ? "Once so far" : "\(stats.inHits) times so far"
                var block = ["Turning this one over:", "• \(claim) \(so). Not enough for me yet."]
                if turning.count > 1 {
                    block.append(turning.count == 2
                        ? "There's another I'm chewing on as well."
                        : "There are \(spelledCount(turning.count - 1).lowercased()) others I'm chewing on.")
                }
                parts.append(block.joined(separator: "\n"))
            }
        }

        let shownCrossed = crossed.compactMap { row -> String? in
            guard fresh(row) else { return nil }
            guard let condition = ledger.ref(row.conditionID) else { return nil }
            let outcome = row.outcomeID.flatMap { ledger.ref($0) }
            let said = outcome.map { "I said that when \(condition.conditionClause), \($0.outcomeClause)." }
                ?? "I said \(condition.label) belonged to one turn of your year."
            let because = row.revisions.last(where: { $0.to == .crossedOut })?.because
            return because.map { "• \(said) Then \($0)." } ?? "• \(said)"
        }.prefix(folioCrossedShown)
        if !shownCrossed.isEmpty {
            var block = ["Wrong about this one:"] + shownCrossed
            let rest = crossed.count - shownCrossed.count
            if rest > 0 {
                block.append(rest == 1
                    ? "One more I got wrong."
                    : "\(spelledCount(rest)) more I got wrong.")
            }
            parts.append(block.joined(separator: "\n"))
        }

        // Not a moral. The pencil having an opinion is the whole of it.
        parts.append("The crossings-out stay where they are. The pencil is fond of them.")
        return parts.joined(separator: "\n\n")
    }

    /// A short name for the entry, for a margin or a list.
    /// The title on the Notice the reader opens.
    ///
    /// It carries no feature labels at all. The old one joined two of them
    /// together — "evening and clear and “bread”" — which is a filing system
    /// talking, and it also had to guess a frame for shapes that have only one
    /// side, so a thing that goes quiet and comes back got announced as
    /// happening every year. The rule itself is directly underneath, in a
    /// sentence, where the reader can check it. The title is only the Book
    /// saying what kind of knowing this is.
    static func noticeTitle(
        row: GrimoireCorrespondence,
        isReversal: Bool = false,
        isWager: Bool = false
    ) -> String {
        if isReversal || row.state == .crossedOut { return "I Was Wrong About This" }
        if isWager { return "I Am Betting On This One" }
        switch row.shape {
        case .conditional: return "I Caught Two Things Together"
        case .sequential: return "I Know Which One Goes First"
        case .sibling: return "I Know Which One It Is"
        case .seasonal: return "You Keep An Appointment"
        case .returnInterval: return "It Leaves. It Comes Back."
        }
    }

    // MARK: Experiments

    /// What the Book says *before* it finds out.
    ///
    /// Committed word for word at the moment it sets the Working, and never
    /// rewritten. The whole value of an experiment is that the reader can hold
    /// the Book to something it said in advance, so this sentence has to name
    /// the thing it expects plainly enough to be wrong.
    static func prediction(
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        guard let outcome = row.outcomeID.flatMap({ ledger.ref($0) }) else {
            return "I'm going to try something. Let's see what you do."
        }
        // `outcomeClause` is a finished statement in the past tense — "you used
        // the word lantern" — and a prediction points the other way. Rather
        // than teach every projector a future tense, the Book writes the entry
        // before the day happens, which is true to what it's doing anyway and
        // puts the receipt the reader is holding it to on the page.
        return "I'm writing it down before it happens: \(outcome.outcomeClause). Now we find out."
    }

    /// The Book asking for the day it wants.
    static func experimentSummons(
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        guard let stats = ledger.currentStats(for: row, calendar: calendar) else {
            return "I've been counting something. Go on. I'll watch."
        }
        // Short, and in that order on purpose: the count, the hole in it, the
        // ask. The hole is the whole reason the Book is doing this, and it has
        // to fit in a sentence a child would say out loud.
        return "I've counted this \(stats.inHits) times. But you picked every one of those days, "
            + "so I don't know if it's a rule or if it's just you. This one's mine. Go on."
    }

    /// What it says afterwards. It says it either way.
    static func experimentResult(
        _ experiment: GrimoireExperiment,
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> String {
        let outcome = ledger.ref(experiment.outcomeID)
        switch experiment.verdict {
        case .waiting:
            return ""
        case .unanswered:
            return "You didn't go. That's fine. It just means I still don't know. I'll ask again."
        case .held:
            guard let outcome else { return "I said what would happen. It happened." }
            // The title already says "I Knew It", so the body stops at the
            // evidence instead of saying it twice for a flourish.
            return "I made that day happen on purpose. I said \(outcome.outcomeClause). You did."
        case .missed:
            guard let outcome else {
                return "I made that day happen on purpose. I got it wrong."
            }
            let admission = "I made that day happen on purpose. I said \(outcome.outcomeClause). "
                + "You didn't. So I was wrong."
            let learned = row.state == .spoken
                ? " It's not something I'm sure of now. Just something I think."
                : " I'm keeping it, but I'm not sure of it now."
            return admission + learned
        }
    }

    /// The title on the Page that carries a test.
    static func experimentTitle(_ experiment: GrimoireExperiment) -> String {
        switch experiment.verdict {
        case .waiting: return "I'm Trying Something"
        case .held: return "I Knew It"
        case .missed: return "I Got It Wrong"
        case .unanswered: return "You Didn't Go"
        }
    }

    static func editionTitle(row: GrimoireCorrespondence, ledger: GrimoireLedger) -> String {
        guard let condition = ledger.ref(row.conditionID) else { return "A thing I worked out" }
        switch row.shape {
        case .seasonal:
            return "\(opening(condition.label)) kept the appointment"
        case .returnInterval:
            return "\(opening(condition.label)) came back again"
        case .sibling:
            return "\(opening(condition.label)) won this one"
        case .conditional:
            guard let outcome = row.outcomeID.flatMap({ ledger.ref($0) }) else {
                return "\(opening(condition.label)) kept turning up"
            }
            return "\(opening(outcome.label)) kept turning up"
        case .sequential:
            guard let outcome = row.outcomeID.flatMap({ ledger.ref($0) }) else {
                return "\(opening(condition.label)) went first"
            }
            return "\(opening(outcome.label)) came after"
        }
    }
}

private extension String {
    /// Uppercase only the first character, leaving the rest of the sentence
    /// alone. `capitalized` would title-case a whole clause.
    func capitalized(firstOnly: Bool) -> String {
        guard firstOnly, let first = self.first else { return self }
        return first.uppercased() + dropFirst()
    }
}
