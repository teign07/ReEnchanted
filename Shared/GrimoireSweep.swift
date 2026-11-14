import Foundation

// MARK: - Deciding what is interesting

/// Ranking a correspondence by strength alone gets you boring true things:
/// *you write more in the evening*. Interest is what stops the grimoire from
/// filling up with the obvious.
///
/// `strength` multiplies rather than adds, so nothing weak can ever become
/// interesting enough to say — the other three terms can only ever spend
/// evidence the counts already earned.
enum GrimoireInterest {

    /// How rarely this reader's Book has connected these two families before.
    ///
    /// This is self-tuning and needs no table of what "ought" to be surprising:
    /// the first time weather reaches writing it is worth everything, and the
    /// tenth time it is worth very little. Variety falls out on its own.
    /// How often the Book has already walked each road between two families.
    ///
    /// Built once per pass. Asking the question row by row meant walking every
    /// row for every row, which is fine at ten correspondences and quadratic by
    /// the time a Book has a few hundred.
    struct Familiarity {
        private var counts: [String: Int] = [:]

        init(_ ledger: GrimoireLedger) {
            for row in ledger.rows.values where row.hasSpoken {
                guard let left = ledger.ref(row.conditionID) else { continue }
                let right = row.outcomeID.flatMap { ledger.ref($0) }
                counts[Familiarity.key(left.domain, right?.domain), default: 0] += 1
            }
        }

        private static func key(_ condition: String, _ outcome: String?) -> String {
            "\(condition)>\(outcome ?? "-")"
        }

        func unexpectedness(condition: LoomFeatureRef, outcome: LoomFeatureRef?) -> Double {
            let seen = counts[Familiarity.key(condition.domain, outcome?.domain)] ?? 0
            return 1.0 / (1.0 + Double(seen) * 0.35)
        }
    }

    static func unexpectedness(
        condition: LoomFeatureRef,
        outcome: LoomFeatureRef?,
        in ledger: GrimoireLedger
    ) -> Double {
        Familiarity(ledger).unexpectedness(condition: condition, outcome: outcome)
    }

    /// A narrow condition says more than a broad one. *Parking lots after
    /// rain* beats *outdoors*.
    static func specificity(_ stats: GrimoireStats, universeCount: Int) -> Double {
        guard universeCount > 0, stats.inCount > 0 else { return 0.2 }
        let share = Double(stats.inCount) / Double(universeCount)
        return min(1.0, max(0.2, 1.0 - share))
    }

    /// Something said recently is worth less than something never said.
    static func novelty(_ row: GrimoireCorrespondence?, now: Date) -> Double {
        guard let spokenAt = row?.lastSpokenAt else { return 1.0 }
        let days = now.timeIntervalSince(spokenAt) / 86_400
        return min(1.0, max(0.1, days / 21.0))
    }

    static func score(
        stats: GrimoireStats,
        condition: LoomFeatureRef,
        outcome: LoomFeatureRef?,
        row: GrimoireCorrespondence?,
        familiarity: Familiarity,
        universeCount: Int,
        now: Date
    ) -> Int {
        let strength = Double(stats.strength) / 100.0
        let value = strength
            * familiarity.unexpectedness(condition: condition, outcome: outcome)
            * specificity(stats, universeCount: universeCount)
            * novelty(row, now: now)
            * reach(condition: condition, outcome: outcome)
        return Int((value * 100).rounded())
    }

    // MARK: Explained away

    /// Things the Book can explain without the reader's life in it at all.
    ///
    /// bj, 2026-11-10: "the most boring shit is being surfaced." A sim Book's
    /// only four spoken rules were *afternoon at home → you used the word
    /// "afternoon"*, *afternoon at home → you were at home*, and the same
    /// condition against a thread read off those very words. Every pair is born
    /// on one Page, so a pair that Page explains by itself is bookkeeping
    /// however perfect its counts look. These never speak, at any strength.
    static func isExplainedAway(
        shape: GrimoireShape,
        condition: LoomFeatureRef,
        outcome: LoomFeatureRef?,
        ref: (String) -> LoomFeatureRef?
    ) -> Bool {
        guard let outcome else { return false }
        // A blend cannot discover one of its own ingredients, nor anything
        // from an ingredient's family: "afternoon at home → you were at home",
        // or "→ you were at work", which is only the blend said backwards.
        if condition.domain == "contextBlend" {
            for member in blendMembers(condition.id) {
                if member == outcome.id { return true }
                if let ingredient = ref(member), ingredient.domain == outcome.domain { return true }
            }
        }
        // An echo: the word names the circumstance it turned up in. Clear
        // weather brings the word "clear"; afternoon brings "afternoon".
        // Only words and threads can echo; skipping the rest keeps this cheap
        // on the desk's read path, which ranks every row.
        let wordy: Set<String> = ["word", "meaning"]
        if wordy.contains(condition.domain) || wordy.contains(outcome.domain),
           !echoTokens(condition, ref: ref).isDisjoint(with: echoTokens(outcome, ref: ref)) {
            return true
        }
        // A Page *about* the circumstance. The Book writes a weather Page when
        // the weather does something, so "clear days → weather Pages" is the
        // Book reporting its own habit back as the reader's.
        if !topicDomains(of: condition).isDisjoint(with: circumstanceDomains(of: outcome, ref: ref))
            || !topicDomains(of: outcome).isDisjoint(with: circumstanceDomains(of: condition, ref: ref)) {
            return true
        }
        // The Page explaining itself. Same-day shapes only: a pair found on one
        // Page is about that Page. Across days (sequential) it is a real reach.
        if shape == .conditional || shape == .sibling,
           derivedTogether(condition.domain, outcome.domain) {
            return true
        }
        // A spell, mission or dare is one thing with its kind, and it sets what
        // gets written on its own Page, who hosts it and which drawer it sits in.
        if shape == .conditional || shape == .sibling,
           (promptedActs.contains(condition.domain) && promptedLeaf.contains(outcome.domain))
            || (promptedActs.contains(outcome.domain) && promptedLeaf.contains(condition.domain))
            || (promptedActs.contains(condition.domain) && promptedActs.contains(outcome.domain)) {
            return true
        }
        return false
    }

    /// Families where one is read off the other on the very same Page.
    ///
    /// A Fuel Page asks what you ate, so "seltzer" arriving with Fuel Pages is
    /// the prompt answered. A thread (`meaning`) is read from the words, so the
    /// words predict it. "Days you wrote" use ink. A photo is captioned short.
    static let derivedPairs: Set<String> = [
        "pageKind|word", "pageKind|ink", "pageKind|meaning", "pageKind|media",
        "pageKind|writing", "pageKind|modality",
        "meaning|word", "writing|word", "writing|ink", "writing|meaning",
        "media|ink", "media|word", "modality|ink", "modality|word",
        // Going into a room of the Book is often how its Page got kept.
        "wander|pageKind", "wander|modality",
        // A rescue answers the mark; the Curse's throw and the reader's can be
        // one exchange.
        "greyPage|greyRescue", "curseThrow|inkbones"
    ]

    /// Things the Book hands over with an ask attached.
    static let promptedActs: Set<String> = ["spell", "spellKind", "mission", "missionMode", "dare"]
    /// What such an ask decides on its own Page.
    static let promptedLeaf: Set<String> = [
        "pageKind", "word", "ink", "meaning", "media", "modality", "writing",
        "compass", "compassPlace", "cast", "subject"
    ]

    static func derivedTogether(_ left: String, _ right: String) -> Bool {
        derivedPairs.contains("\(left)|\(right)") || derivedPairs.contains("\(right)|\(left)")
    }

    /// What a Page kind or a medium is *about*, as the families that would
    /// cause it: a weather Page is about the weather.
    static func topicDomains(of feature: LoomFeatureRef) -> Set<String> {
        guard feature.domain == "pageKind" || feature.domain == "modality",
              let colon = feature.id.firstIndex(of: ":") else { return [] }
        switch feature.id[feature.id.index(after: colon)...] {
        case "weather": return ["weather", "daylight", "season"]
        case "place", "location": return ["place", "placeKind", "travel"]
        case "rest": return ["sleep", "body", "readerState"]
        case "body": return ["body", "sleep", "readerState"]
        default: return []
        }
    }

    /// The families a feature stands for, opening a blend into its ingredients.
    static func circumstanceDomains(of feature: LoomFeatureRef, ref: (String) -> LoomFeatureRef?) -> Set<String> {
        var out: Set<String> = [feature.domain]
        for member in blendMembers(feature.id) {
            if let ingredient = ref(member) { out.insert(ingredient.domain) }
        }
        return out
    }

    static func blendMembers(_ id: String) -> [String] {
        guard id.hasPrefix("blend:") else { return [] }
        return id.dropFirst("blend:".count).split(separator: "+").map(String.init)
    }

    /// The plain words a feature stands for, for spotting an echo. Prefixes
    /// ("word:", "hour:") and the registry's own scaffolding never count.
    static func echoTokens(_ feature: LoomFeatureRef, ref: (String) -> LoomFeatureRef?) -> Set<String> {
        var sources = [feature.id, feature.label]
        for member in blendMembers(feature.id) {
            sources.append(member)
            if let ingredient = ref(member) { sources.append(ingredient.label) }
        }
        var out = Set<String>()
        for source in sources {
            for raw in source.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let token = String(raw)
                guard token.count >= 4, !echoScaffolding.contains(token) else { continue }
                out.insert(token)
                // "rainy" and "rain", "clearer" and "clear".
                if token.count >= 6, token.hasSuffix("y") { out.insert(String(token.dropLast())) }
            }
        }
        return out
    }

    static let echoScaffolding: Set<String> = [
        "word", "blend", "kept", "page", "pages", "pattern", "meaning", "media",
        "hour", "place", "weather", "days", "with", "that", "your", "this", "about",
        "when", "they", "them", "were", "there", "some", "only", "drop", "lots",
        "pocket", "belief", "lifecycle", "manner", "sensory", "absence", "duration"
    ]

    // MARK: Reach

    /// How far apart the two halves live.
    ///
    /// The rich findings cross from one part of a life into another: the moon
    /// into sleep, rain into which door you chose, a crowded calendar into
    /// how much ink you spent. Words are the cheapest feature there is (five a
    /// Page, thousands a year) and on sheer numbers they crowd every ledger,
    /// so a word half has to be stronger to be heard.
    static func reach(condition: LoomFeatureRef, outcome: LoomFeatureRef?) -> Double {
        guard let outcome else { return 1.0 }
        let left = realm(of: condition.domain)
        let right = realm(of: outcome.domain)
        var value = left == right ? 0.75 : 1.0
        if condition.domain == "word" || outcome.domain == "word" { value *= 0.6 }
        if condition.domain == "meaning" || outcome.domain == "meaning" { value *= 0.8 }
        // A Page kind is which drawer the reader opened, not what they did, and
        // a Page's topic is mostly which Page the Book put out that day.
        if outcome.domain == "pageKind" || outcome.domain == "modality" { value *= 0.8 }
        // Writing in words is what nearly every Page is. Saying so is not news.
        if condition.id == "modality:words" || outcome.id == "modality:words" { value *= 0.6 }
        // Neither half is the reader's writing and they come from different
        // parts of a life: the shape bj means by "our connections can be so rich".
        let writing: Set<String> = ["word", "meaning", "ink", "pageKind", "writing"]
        if left != right, !writing.contains(condition.domain), !writing.contains(outcome.domain) {
            value *= 1.2
        }
        return value
    }

    enum Realm { case world, body, life, page, story }

    static func realm(of domain: String) -> Realm {
        switch domain {
        case "weather", "moon", "daylight", "season", "worldEvent", "worldEventPhase",
             "almanac", "observance":
            return .world
        case "body", "sleep", "readerState", "attention":
            return .body
        case "place", "placeKind", "travel", "calendarLoad", "person", "hour", "weekPart",
             "contextBlend", "placeMaking":
            return .life
        case "pageKind", "word", "ink", "media", "modality", "writing", "meaning":
            return .page
        default:
            // Cast, choices, Fae, Workings, the Compass, errands, Pockets,
            // jumps, asides: the reader acting inside the story.
            return .story
        }
    }
}

// MARK: - The sweep

extension GrimoireLedger {

    struct SweepReport: Equatable {
        var pairsExamined = 0
        var rowsCreated: [String] = []
        var rowsPromoted: [String] = []
        var rowsCrossedOut: [String] = []
        var pairsRemaining = 0
        var finished: Bool { pairsRemaining == 0 }
    }

    /// Turn counts into claims, in bounded chunks, off the main thread.
    ///
    /// Only pairs that moved since last time are examined, so this is
    /// proportional to what the reader did today rather than to how long they
    /// have kept the Book.
    mutating func sweep(
        now: Date = Date(),
        budget: Int = 400,
        calendar: Calendar = .current
    ) -> SweepReport {
        var report = SweepReport()
        let universeCount = universe.count
        // Once per sweep, not once per row.
        let familiarity = GrimoireInterest.Familiarity(self)

        let take = min(budget, dirtyPairs.count)
        if take > 0 {
            let batch = dirtyPairs.prefix(take)
            dirtyPairs.removeFirst(take)
            for key in batch {
                report.pairsExamined += 1
                examine(
                    pair: key, universeCount: universeCount, familiarity: familiarity,
                    now: now, calendar: calendar, into: &report
                )
            }
        }

        // Siblings are derived from rows that already cleared the bar, so this
        // costs a walk of the rows rather than another search of the archive.
        examineSiblings(familiarity: familiarity, now: now, calendar: calendar, into: &report)

        // Seasonal shapes are not pairs, and there are few enough candidates
        // (a feature has to span two years even to be asked) that the whole
        // set is cheap to walk each sweep.
        examineSeasons(familiarity: familiarity, now: now, calendar: calendar, into: &report)
        examineReturns(familiarity: familiarity, now: now, calendar: calendar, into: &report)

        // Every promise the Book has made, checked without being asked. This
        // is the part that pays for the plain speaking.
        checkPromises(now: now, calendar: calendar, into: &report)

        report.pairsRemaining = dirtyPairs.count
        lastSweptAt = now
        return report
    }

    private mutating func examine(
        pair key: UInt64,
        universeCount: Int,
        familiarity: GrimoireInterest.Familiarity,
        now: Date,
        calendar: Calendar,
        into report: inout SweepReport
    ) {
        let (leftIndex, rightIndex) = GrimoireLedger.unpack(key)
        guard leftIndex < featureRefs.count, rightIndex < featureRefs.count else { return }
        let condition = featureRefs[leftIndex]
        let outcome = featureRefs[rightIndex]
        let conditionDays = featureDays[leftIndex]
        let outcomeDays = featureDays[rightIndex]

        consider(
            shape: .conditional,
            condition: condition,
            outcome: outcome,
            conditionDays: conditionDays,
            outcomeDays: outcomeDays,
            universeCount: universeCount, familiarity: familiarity,
            now: now, calendar: calendar, into: &report
        )

        // The same two features asked a different question: did one keep
        // *following* the other? Walk backwards from the outcome so the
        // denominator stays "times the condition happened" rather than "days
        // inside a window", which would divide every answer by the window.
        consider(
            shape: .sequential,
            condition: condition,
            outcome: outcome,
            conditionDays: conditionDays,
            outcomeDays: outcomeDays.precedingWindow(from: 1, through: Bars.sequenceWindow)
                .intersection(universe),
            universeCount: universeCount, familiarity: familiarity,
            now: now, calendar: calendar, into: &report
        )
    }

    private mutating func consider(
        shape: GrimoireShape,
        condition: LoomFeatureRef,
        outcome: LoomFeatureRef?,
        conditionDays: DayBitset,
        outcomeDays: DayBitset,
        universeCount: Int,
        familiarity: GrimoireInterest.Familiarity,
        now: Date,
        calendar: Calendar,
        into report: inout SweepReport
    ) {
        let id = GrimoireCorrespondence.key(shape: shape, condition: condition.id, outcome: outcome?.id)
        // A door the reader shut stays shut, whatever the evidence does next.
        if let existing = rows[id], existing.state == .forbidden { return }

        // The Page explains it. Not a claim at all, so it never becomes a row;
        // one already said stays on record but `ranked` will not say it again.
        if GrimoireInterest.isExplainedAway(
            shape: shape, condition: condition, outcome: outcome, ref: { self.ref($0) }
        ) {
            if let existing = rows[id], !existing.hasSpoken { rows.removeValue(forKey: id) }
            return
        }

        // Cheap first. Almost everything dies here, and everything that dies
        // here never pays for a calendar.
        var stats = contrast(conditionDays: conditionDays, outcomeDays: outcomeDays)
        guard GrimoireLedger.clearsBar(stats, universeCount: universeCount) else {
            // It used to clear the bar and no longer does. That is the evidence
            // itself objecting, and it deserves the same visible treatment as a
            // broken promise rather than a silent deletion.
            if var existing = rows[id], existing.hasSpoken, existing.state != .crossedOut {
                cross(out: &existing, now: now, because: "the counts stopped holding it up")
                rows[id] = existing
                report.rowsCrossedOut.append(id)
            } else if let existing = rows[id], !existing.hasSpoken {
                rows.removeValue(forKey: existing.id)
            }
            return
        }

        enrich(&stats, conditionDays: conditionDays, outcomeDays: outcomeDays)
        let interest = GrimoireInterest.score(
            stats: stats, condition: condition, outcome: outcome,
            row: rows[id], familiarity: familiarity, universeCount: universeCount, now: now
        )
        let firstDay = stats.firstDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now
        let lastDay = stats.lastDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now

        if var existing = rows[id] {
            existing.lastObservedAt = lastDay
            existing.strengthPeak = max(existing.strengthPeak, stats.strength)
            existing.interestPeak = max(existing.interestPeak, interest)
            if existing.state == .watching || existing.state == .spoken,
               GrimoireLedger.clearsStandingBar(stats), existing.hasSpoken,
               makeRoomForConviction(strength: stats.strength, now: now) {
                let from = existing.state
                existing.state = .standing
                existing.revisions.append(GrimoireRevision(
                    at: now, from: from, to: .standing,
                    because: "it kept happening: \(stats.inHits) times now"
                ))
                report.rowsPromoted.append(id)
            }
            rows[id] = existing
        } else {
            rows[id] = GrimoireCorrespondence(
                id: id, shape: shape,
                conditionID: condition.id, outcomeID: outcome?.id,
                state: .watching,
                firstObservedAt: firstDay, lastObservedAt: lastDay,
                falsifier: nil, revisions: [], readerStatus: nil,
                lastSpokenAt: nil,
                strengthPeak: stats.strength, interestPeak: interest
            )
            report.rowsCreated.append(id)
        }
    }

    /// Can the Book be sure of one more thing?
    ///
    /// The cabinet holds `maximumHeld`. When it is full, a newcomer only gets
    /// in by being steadier than the weakest thing already in there — and that
    /// one is let go, back to something the Book merely said rather than
    /// something it holds. Letting go is recorded, because the reader should be
    /// able to see the Book change its mind about what it is sure of, not only
    /// about what is true.
    private mutating func makeRoomForConviction(strength: Int, now: Date) -> Bool {
        let held = rows.values.filter { $0.state == .standing }
        guard held.count >= Bars.maximumHeld else { return true }
        guard let weakest = held.min(by: { left, right in
            if left.strengthPeak != right.strengthPeak { return left.strengthPeak < right.strengthPeak }
            return left.id > right.id
        }) else { return true }
        guard strength > weakest.strengthPeak else { return false }
        rows[weakest.id]?.state = .spoken
        rows[weakest.id]?.revisions.append(GrimoireRevision(
            at: now, from: .standing, to: .spoken,
            because: "I made room. Something steadier came along."
        ))
        return true
    }

    // MARK: Siblings

    /// "Of the two, it is *this* one." A comparison inside one family.
    ///
    /// Ordinary pairing deliberately refuses same-family pairs, because "it was
    /// morning, therefore it was morning" is not a finding. But the one
    /// genuinely interesting within-family question is which *member* carries a
    /// result its neighbours do not — Wicker's unnecessary routes bringing
    /// something back where his object hunts do not.
    ///
    /// Built from conditional rows that already earned their place: for each,
    /// the strongest rival in the same family is measured against the same
    /// outcome, and a claim is made only when the winner is clearly ahead.
    private mutating func examineSiblings(
        familiarity: GrimoireInterest.Familiarity,
        now: Date,
        calendar: Calendar,
        into report: inout SweepReport
    ) {
        let universeCount = universe.count
        let previouslyAlive = Set(rows.values.lazy.filter {
            $0.shape == .sibling && $0.isAlive
        }.map(\.id))
        var stillTrue = Set<String>()
        guard universeCount >= Bars.minimumUniverse else {
            retireDerivedRows(
                previouslyAlive,
                now: now,
                because: "there was no longer enough evidence for the comparison",
                into: &report
            )
            return
        }

        var byDomain: [String: [Int]] = [:]
        for (index, ref) in featureRefs.enumerated() {
            byDomain[ref.domain, default: []].append(index)
        }

        // Snapshot: the loop below inserts rows.
        let established = rows.values.filter {
            $0.shape == .conditional && $0.isAlive && $0.outcomeID != nil
        }

        for row in established {
            guard let condition = ref(row.conditionID),
                  let outcomeID = row.outcomeID,
                  let outcome = ref(outcomeID) else { continue }
            guard let siblings = byDomain[condition.domain], siblings.count > 1 else { continue }
            guard !GrimoireInterest.isExplainedAway(
                shape: .sibling, condition: condition, outcome: outcome, ref: { self.ref($0) }
            ) else { continue }
            let conditionDays = days(of: row.conditionID)
            let outcomeDays = days(of: outcomeID)
            let winner = contrast(conditionDays: conditionDays, outcomeDays: outcomeDays)
            guard GrimoireLedger.clearsBar(winner, universeCount: universeCount) else { continue }

            // The rival worth naming is the family member with the most chances
            // that still failed to produce the outcome.
            var best: (ref: LoomFeatureRef, stats: GrimoireStats)?
            for index in siblings {
                let rival = featureRefs[index]
                guard rival.id != condition.id else { continue }
                guard GrimoireLedger.canPair(rival, outcome) else { continue }
                let stats = contrast(conditionDays: featureDays[index], outcomeDays: outcomeDays)
                guard stats.inCount >= Bars.siblingMinimumRivalCount else { continue }
                guard winner.inRate - stats.inRate >= Bars.siblingMinimumRateGap else { continue }
                guard stats.inRate == 0 || winner.inRate / stats.inRate >= Bars.siblingMinimumRatio else { continue }
                let rivalID = GrimoireCorrespondence.key(
                    shape: .sibling,
                    condition: condition.id,
                    outcome: outcome.id,
                    rival: rival.id
                )
                // Keep an already-made comparison alive while it is still
                // true, even if a different rival now has more observations.
                if rows[rivalID] != nil { stillTrue.insert(rivalID) }
                if best == nil || stats.inCount > best!.stats.inCount { best = (rival, stats) }
            }
            guard let rival = best else { continue }

            let id = GrimoireCorrespondence.key(
                shape: .sibling, condition: condition.id, outcome: outcome.id, rival: rival.ref.id
            )
            stillTrue.insert(id)
            if let existing = rows[id], existing.state == .forbidden { continue }

            var stats = winner
            enrich(&stats, conditionDays: conditionDays, outcomeDays: outcomeDays)
            let interest = GrimoireInterest.score(
                stats: stats, condition: condition, outcome: outcome,
                row: rows[id], familiarity: familiarity,
                universeCount: universeCount, now: now
            )
            let first = stats.firstDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now
            let last = stats.lastDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now

            if var existing = rows[id] {
                existing.lastObservedAt = last
                existing.rivalID = rival.ref.id
                existing.strengthPeak = max(existing.strengthPeak, stats.strength)
                existing.interestPeak = max(existing.interestPeak, interest)
                rows[id] = existing
            } else {
                rows[id] = GrimoireCorrespondence(
                    id: id, shape: .sibling,
                    conditionID: condition.id, outcomeID: outcome.id,
                    state: .watching,
                    firstObservedAt: first, lastObservedAt: last,
                        falsifier: nil, revisions: [], readerStatus: nil,
                    lastSpokenAt: nil,
                    strengthPeak: stats.strength, interestPeak: interest,
                    rivalID: rival.ref.id
                )
                report.rowsCreated.append(id)
            }
        }
        retireDerivedRows(
            previouslyAlive.subtracting(stillTrue),
            now: now,
            because: "the comparison stopped holding",
            into: &report
        )
    }

    // MARK: Seasons

    /// Which years the Book was actually open for each turn of the year.
    ///
    /// This depends only on the universe, so it is built once per pass and
    /// handed round. Deriving it inside `seasonalStanding` meant walking every
    /// day the Book has ever been open, once for every seasonal row — which was
    /// the whole of a 32ms desk read.
    struct SeasonOffering {
        private(set) var yearsBySeason: [Int: Set<Int>] = [:]

        init(universe: DayBitset) {
            for day in universe.days {
                let civil = GrimoireDay.civil(of: day)
                yearsBySeason[GrimoireDay.season(of: day), default: []].insert(civil.year)
            }
        }

        func years(inSeason season: Int) -> Int { yearsBySeason[season]?.count ?? 0 }
        var offeredSeasons: [Int] { yearsBySeason.keys.sorted() }
    }

    /// Which turn of the year a thing belongs to, how many years it kept the
    /// appointment, and how many it missed.
    func seasonalStanding(
        of days: DayBitset,
        offering: SeasonOffering
    ) -> (season: Int, present: Int, missed: Int)? {
        guard !universe.isEmpty else { return nil }
        var kept: [Int: Set<Int>] = [:]
        for day in days.days {
            kept[GrimoireDay.season(of: day), default: []].insert(GrimoireDay.civil(of: day).year)
        }
        // Seeing only spring cannot prove that something belongs to spring.
        // There must be another observed turn of the year to contrast it with.
        guard offering.offeredSeasons.count >= 2 else { return nil }
        let ranked = offering.offeredSeasons.map { season -> (season: Int, present: Int, missed: Int, rate: Double) in
            let offered = offering.years(inSeason: season)
            let present = kept[season]?.count ?? 0
            let rate = offered > 0 ? Double(present) / Double(offered) : 0
            return (season, present, max(0, offered - present), rate)
        }.sorted { left, right in
            if left.rate != right.rate { return left.rate > right.rate }
            if left.present != right.present { return left.present > right.present }
            return left.season < right.season
        }
        guard let winner = ranked.first, winner.present >= 2 else { return nil }
        let runnerRate = ranked.dropFirst().first?.rate ?? 0
        guard winner.rate >= Bars.minimumInRate,
              winner.rate - runnerRate >= Bars.minimumRateGap else { return nil }
        return (winner.season, winner.present, winner.missed)
    }

    /// Recount the particular season named by a persisted row. This is
    /// deliberately different from choosing today's winner: old evidence may
    /// defeat a spring claim, but it may not rewrite it as an autumn claim.
    func seasonalStanding(
        of days: DayBitset,
        in season: Int,
        offering: SeasonOffering
    ) -> (season: Int, present: Int, missed: Int)? {
        let offered = offering.years(inSeason: season)
        guard offered > 0 else { return nil }
        var years = Set<Int>()
        for day in days.days where GrimoireDay.season(of: day) == season {
            years.insert(GrimoireDay.civil(of: day).year)
        }
        return (season, years.count, max(0, offered - years.count))
    }

    func seasonalStanding(
        of days: DayBitset,
        calendar: Calendar = .current
    ) -> (season: Int, present: Int, missed: Int)? {
        seasonalStanding(of: days, offering: SeasonOffering(universe: universe))
    }

    private mutating func examineSeasons(
        familiarity: GrimoireInterest.Familiarity,
        now: Date,
        calendar: Calendar,
        into report: inout SweepReport
    ) {
        let previouslyAlive = Set(rows.values.lazy.filter {
            $0.shape == .seasonal && $0.isAlive
        }.map(\.id))
        var stillTrue = Set<String>()
        guard universe.count >= Bars.minimumUniverse else {
            retireDerivedRows(
                previouslyAlive,
                now: now,
                because: "there was no longer enough of the year to support it",
                into: &report
            )
            return
        }
        let offering = SeasonOffering(universe: universe)
        for (index, days) in featureDays.enumerated() {
            guard days.count >= Bars.minimumHits else { continue }
            var years: Set<Int> = []
            for day in days.days { years.insert(GrimoireDay.civil(of: day).year) }
            // A seasonal claim needs more than one year, by definition. This is
            // the shape that stays quiet until the Book is old.
            guard years.count >= 2 else { continue }
            guard let standing = seasonalStanding(of: days, offering: offering) else { continue }
            guard standing.present >= 2 else { continue }

            let feature = featureRefs[index]
            let id = GrimoireCorrespondence.key(
                shape: .seasonal,
                condition: feature.id,
                outcome: nil,
                season: standing.season
            )
            stillTrue.insert(id)
            if let existing = rows[id], existing.state == .forbidden { continue }

            var stats = GrimoireStats()
            stats.inCount = standing.present + standing.missed
            stats.inHits = standing.present
            stats.outCount = max(1, universe.count - days.count)
            stats.outHits = 0
            stats.firstDay = days.firstDay
            stats.lastDay = days.lastDay
            stats.distinctYears = years.count
            stats.seasonsPresent = standing.present
            stats.seasonsMissed = standing.missed

            let interest = GrimoireInterest.score(
                stats: stats, condition: feature, outcome: nil,
                row: rows[id], familiarity: familiarity,
                universeCount: universe.count, now: now
            )
            let first = days.firstDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now
            let last = days.lastDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now

            if var existing = rows[id] {
                existing.lastObservedAt = last
                existing.season = standing.season
                existing.strengthPeak = max(existing.strengthPeak, stats.strength)
                existing.interestPeak = max(existing.interestPeak, interest)
                rows[id] = existing
            } else {
                rows[id] = GrimoireCorrespondence(
                    id: id, shape: .seasonal,
                    conditionID: feature.id, outcomeID: nil,
                    state: .watching,
                    firstObservedAt: first, lastObservedAt: last,
                    falsifier: nil, revisions: [], readerStatus: nil,
                    lastSpokenAt: nil,
                    strengthPeak: stats.strength, interestPeak: interest,
                    season: standing.season
                )
                report.rowsCreated.append(id)
            }
        }
        retireDerivedRows(
            previouslyAlive.subtracting(stillTrue),
            now: now,
            because: "it no longer belonged to that season",
            into: &report
        )
    }

    private mutating func retireDerivedRows(
        _ ids: Set<String>,
        now: Date,
        because reason: String,
        into report: inout SweepReport
    ) {
        for id in ids {
            guard var row = rows[id], row.isAlive else { continue }
            if row.hasSpoken {
                cross(out: &row, now: now, because: reason)
                rows[id] = row
                report.rowsCrossedOut.append(id)
            } else {
                rows.removeValue(forKey: id)
            }
        }
    }

    // MARK: Returns

    /// How a thing goes quiet and comes back.
    ///
    /// Not "how often" — that is what every other shape already measures — but
    /// the *shape of its absences*. A subject that turns up every week has a
    /// rhythm; one that vanishes for a season and then reappears has a habit of
    /// leaving, which is a different and stranger thing to be able to say.
    func returnStanding(
        of days: DayBitset
    ) -> (returns: Int, longestGap: Int, typicalGap: Int)? {
        let all = days.days
        guard all.count >= Bars.minimumHits else { return nil }
        var gaps: [Int] = []
        for index in 1..<all.count {
            let gap = all[index] - all[index - 1]
            if gap >= Bars.returnGapDays { gaps.append(gap) }
        }
        guard gaps.count >= Bars.minimumReturns else { return nil }
        let sorted = gaps.sorted()
        return (gaps.count, sorted.last ?? 0, sorted[sorted.count / 2])
    }

    private mutating func examineReturns(
        familiarity: GrimoireInterest.Familiarity,
        now: Date,
        calendar: Calendar,
        into report: inout SweepReport
    ) {
        guard universe.count >= Bars.minimumUniverse else { return }
        for (index, days) in featureDays.enumerated() {
            guard days.count >= Bars.minimumHits else { continue }
            guard let standing = returnStanding(of: days) else { continue }
            let feature = featureRefs[index]
            // A circumstance cannot "come back" in any sense worth saying: the
            // weather is not choosing to visit. This shape belongs to subjects.
            guard feature.role != .conditionOnly else { continue }

            let id = GrimoireCorrespondence.key(
                shape: .returnInterval, condition: feature.id, outcome: nil
            )
            if let existing = rows[id], existing.state == .forbidden { continue }

            var stats = GrimoireStats()
            stats.inCount = days.count + standing.returns
            stats.inHits = days.count
            stats.outCount = max(1, universe.count - days.count)
            stats.firstDay = days.firstDay
            stats.lastDay = days.lastDay
            enrich(&stats, conditionDays: days, outcomeDays: days)

            let interest = GrimoireInterest.score(
                stats: stats, condition: feature, outcome: nil,
                row: rows[id], familiarity: familiarity,
                universeCount: universe.count, now: now
            )
            let first = days.firstDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now
            let last = days.lastDay.map { GrimoireDay.date(for: $0, calendar: calendar) } ?? now

            if var existing = rows[id] {
                existing.lastObservedAt = last
                existing.strengthPeak = max(existing.strengthPeak, stats.strength)
                existing.interestPeak = max(existing.interestPeak, interest)
                rows[id] = existing
            } else {
                rows[id] = GrimoireCorrespondence(
                    id: id, shape: .returnInterval,
                    conditionID: feature.id, outcomeID: nil,
                    state: .watching,
                    firstObservedAt: first, lastObservedAt: last,
                    falsifier: nil, revisions: [], readerStatus: nil,
                    lastSpokenAt: nil,
                    strengthPeak: stats.strength, interestPeak: interest
                )
                report.rowsCreated.append(id)
            }
        }
    }

    // MARK: Promises

    /// Re-test every claim the Book has actually made. There are few of these —
    /// the Book speaks rarely — so all of them are checked every sweep.
    private mutating func checkPromises(
        now: Date,
        calendar: Calendar,
        into report: inout SweepReport
    ) {
        for (id, row) in rows {
            guard row.state == .spoken || row.state == .standing else { continue }
            guard let falsifier = row.falsifier else { continue }
            // Judged on days the Book kept quiet, not on the ones it spent
            // pointing at this.
            guard let seen = promiseEvidence(for: row, calendar: calendar) else { continue }
            if case .broken(let rate, let chances) = falsifier.verdict(
                chances: seen.chances, held: seen.held
            ) {
                var updated = row
                let held = Int((rate * Double(chances)).rounded())
                cross(
                    out: &updated, now: now,
                    because: "\(chances) more chances came and it only held \(held) of them"
                )
                rows[id] = updated
                report.rowsCrossedOut.append(id)
            }
        }
    }

    /// Counts only — enough to rank a row, with no calendar work at all.
    ///
    /// `windowCache` matters more than it looks: several rows share an outcome,
    /// and rebuilding its shifted window for each of them was most of what the
    /// desk was waiting on.
    func rankingStats(
        for row: GrimoireCorrespondence,
        windowCache: inout [String: DayBitset],
        offering: SeasonOffering? = nil
    ) -> GrimoireStats? {
        let conditionDays = days(of: row.conditionID)
        switch row.shape {
        case .conditional, .sibling:
            guard let outcomeID = row.outcomeID else { return nil }
            return contrast(conditionDays: conditionDays, outcomeDays: days(of: outcomeID))
        case .sequential:
            guard let outcomeID = row.outcomeID else { return nil }
            let window: DayBitset
            if let cached = windowCache[outcomeID] {
                window = cached
            } else {
                window = sequenceOutcomeDays(outcomeID)
                windowCache[outcomeID] = window
            }
            return contrast(conditionDays: conditionDays, outcomeDays: window)
        case .seasonal, .returnInterval:
            return currentStats(for: row, offering: offering)
        }
    }

    func rankingStats(for row: GrimoireCorrespondence) -> GrimoireStats? {
        var cache: [String: DayBitset] = [:]
        return rankingStats(for: row, windowCache: &cache)
    }

    /// Chances and holds since the Book made its promise, on days it kept quiet.
    ///
    /// Counted directly over "after the promise, minus the shadow of its own
    /// telling", so there is no baseline to difference and nothing that can
    /// come out negative.
    func promiseEvidence(
        for row: GrimoireCorrespondence,
        calendar: Calendar = .current
    ) -> (chances: Int, held: Int)? {
        guard let falsifier = row.falsifier else { return nil }
        guard let last = universe.lastDay else { return nil }
        let committed = GrimoireDay.index(for: falsifier.committedAt, calendar: calendar)
        guard last > committed else { return nil }
        let since = universe
            .intersection(DayBitset.filled(from: committed + 1, through: last))
            .subtracting(promptedWindow(for: row))
        guard !since.isEmpty else { return nil }

        let conditionDays = days(of: row.conditionID)
        let outcomeDays: DayBitset
        switch row.shape {
        case .conditional, .sibling:
            guard let outcomeID = row.outcomeID else { return nil }
            outcomeDays = days(of: outcomeID)
        case .sequential:
            guard let outcomeID = row.outcomeID else { return nil }
            outcomeDays = sequenceOutcomeDays(outcomeID)
        case .seasonal, .returnInterval:
            // Neither a season nor a habit of leaving can be judged on a
            // fortnight of fresh evidence.
            return nil
        }
        let chances = conditionDays.intersection(since)
        return (chances.count, chances.intersectionCount(outcomeDays))
    }

    /// The claim's numbers on days the Book was not standing over the reader's
    /// shoulder.
    ///
    /// A falsifier is measured *only* on days after the Book spoke, which is
    /// exactly the window its own telling has coloured — so judged on all of
    /// them, a belief the Book talked the reader into would pass its own
    /// honesty test, which is worse than having no test. The days it raised the
    /// thing, and the week after each, are set aside.
    ///
    /// Returns nil when setting them aside leaves too little to judge on.
    /// Silence is the right answer there; a verdict on four days is not.
    func uncoachedStats(
        for row: GrimoireCorrespondence,
        calendar: Calendar = .current
    ) -> GrimoireStats? {
        let clean = universe.subtracting(promptedWindow(for: row))
        guard clean.count >= Bars.minimumUniverse else { return nil }
        let conditionDays = days(of: row.conditionID)
        switch row.shape {
        case .conditional, .sibling:
            guard let outcomeID = row.outcomeID else { return nil }
            return contrast(
                conditionDays: conditionDays, outcomeDays: days(of: outcomeID), within: clean
            )
        case .sequential:
            guard let outcomeID = row.outcomeID else { return nil }
            return contrast(
                conditionDays: conditionDays,
                outcomeDays: sequenceOutcomeDays(outcomeID),
                within: clean
            )
        case .seasonal, .returnInterval:
            // Neither can be judged on a fortnight, and the shadow of one
            // telling is a rounding error across years. Judged as they stand.
            return currentStats(for: row, calendar: calendar)
        }
    }

    /// Recompute a row's numbers from the day-sets as they stand now.
    func currentStats(
        for row: GrimoireCorrespondence,
        calendar: Calendar = .current,
        offering: SeasonOffering? = nil
    ) -> GrimoireStats? {
        let conditionDays = days(of: row.conditionID)
        switch row.shape {
        case .conditional, .sibling:
            guard let outcomeID = row.outcomeID else { return nil }
            return stats(conditionDays: conditionDays, outcomeDays: days(of: outcomeID), calendar: calendar)
        case .sequential:
            guard let outcomeID = row.outcomeID else { return nil }
            return stats(
                conditionDays: conditionDays,
                outcomeDays: sequenceOutcomeDays(outcomeID),
                calendar: calendar
            )
        case .returnInterval:
            guard let standing = returnStanding(of: conditionDays) else { return nil }
            var stats = GrimoireStats()
            // Chances are the days plus the times it came back: a return is an
            // event too, and the one this shape is actually about.
            stats.inCount = conditionDays.count + standing.returns
            stats.inHits = conditionDays.count
            stats.outCount = max(1, universe.count - conditionDays.count)
            enrich(&stats, conditionDays: conditionDays, outcomeDays: conditionDays)
            return stats
        case .seasonal:
            let table = offering ?? SeasonOffering(universe: universe)
            let standing: (season: Int, present: Int, missed: Int)?
            if let season = row.season {
                standing = seasonalStanding(of: conditionDays, in: season, offering: table)
            } else {
                // Compatibility with a ledger written before seasonal rows
                // carried the exact season they named.
                standing = seasonalStanding(of: conditionDays, offering: table)
            }
            guard let standing else { return nil }
            var stats = GrimoireStats()
            stats.inCount = standing.present + standing.missed
            stats.inHits = standing.present
            stats.outCount = max(1, universe.count - conditionDays.count)
            stats.firstDay = conditionDays.firstDay
            stats.lastDay = conditionDays.lastDay
            stats.seasonsPresent = standing.present
            stats.seasonsMissed = standing.missed
            return stats
        }
    }

    private func cross(out row: inout GrimoireCorrespondence, now: Date, because reason: String) {
        let from = row.state
        row.state = .crossedOut
        row.revisions.append(GrimoireRevision(at: now, from: from, to: .crossedOut, because: reason))
    }

    // MARK: Speaking

    /// Commit the Book to a claim, and to what would take it back.
    mutating func markSpoken(
        _ id: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard var row = rows[id], row.state != .forbidden else { return }
        // A crossed-out row can still be spoken, and must be: announcing the
        // reversal is the last thing the Book says about it, and recording that
        // it was said is the only thing stopping it apologising every day.
        // It gets no new promise, though — a dead claim has nothing to bet.
        guard row.state != .crossedOut else {
            row.lastSpokenAt = now
            rows[id] = row
            return
        }
        row.promptedDays.insert(GrimoireDay.index(for: now, calendar: calendar))
        guard let stats = currentStats(for: row, calendar: calendar) else { return }
        if row.falsifier == nil {
            row.falsifier = GrimoireFalsifier(
                committedAt: now,
                baselineInCount: stats.inCount,
                baselineInHits: stats.inHits,
                // Half the rate it has held so far, never below a quarter: the
                // Book is promising the pattern keeps roughly working, not that
                // it never misses.
                floorRate: max(0.25, stats.inRate * 0.5),
                opportunitiesRequired: max(3, min(8, stats.inCount / 2)),
                line: GrimoireVoice.promise(row: row, stats: stats, ledger: self)
            )
        }
        if row.state == .watching {
            row.state = .spoken
            row.revisions.append(GrimoireRevision(at: now, from: .watching, to: .spoken, because: "said out loud"))
        }
        row.lastSpokenAt = now
        row.promptedDays.insert(GrimoireDay.index(for: now, calendar: calendar))
        rows[id] = row
    }

    /// The reader answering back. `doNotRead` and `forbidden` are permanent.
    mutating func record(_ status: BookObservationStatus, for id: String, now: Date = Date()) {
        guard var row = rows[id] else { return }
        row.readerStatus = status
        switch status {
        case .doNotRead, .forbidden:
            let from = row.state
            row.state = .forbidden
            row.revisions.append(GrimoireRevision(
                at: now, from: from, to: .forbidden, because: "the reader said never"
            ))
        case .notQuite:
            if row.state == .standing {
                row.state = .spoken
                row.revisions.append(GrimoireRevision(
                    at: now, from: .standing, to: .spoken, because: "the reader said it was crooked"
                ))
            }
        case .confirmed, .questioned, .asked:
            break
        }
        rows[id] = row
    }

    // MARK: Choosing what to say

    /// Everything the Book could honestly say right now, ranked.
    ///
    /// Split from the choosing so the same pass can answer two different
    /// questions: what is *strongest*, and what is *least expected*.
    private func ranked(
        now: Date,
        calendar: Calendar,
        allowingSensitive: Bool
    ) -> [(row: GrimoireCorrespondence, interest: Int, unexpected: Double)] {
        var scored: [(row: GrimoireCorrespondence, interest: Int, unexpected: Double)] = []
        let familiarity = GrimoireInterest.Familiarity(self)
        let universeCount = universe.count
        var windowCache: [String: DayBitset] = [:]
        let offering = SeasonOffering(universe: universe)
        for row in rows.values where row.isAlive {
            guard let condition = ref(row.conditionID) else { continue }
            let outcome = row.outcomeID.flatMap { ref($0) }
            // Rows minted before the Book could tell are still in the ledger.
            if GrimoireInterest.isExplainedAway(
                shape: row.shape, condition: condition, outcome: outcome, ref: { self.ref($0) }
            ) { continue }
            if !allowingSensitive {
                if condition.sensitivity != .ordinary { continue }
                if let outcome,
                   outcome.sensitivity != .ordinary && outcome.sensitivity != .readerReported {
                    continue
                }
            }
            // Said recently is said. Novelty alone only *discounts* a strong
            // claim; a fortnight of rest is what actually stops the Book
            // repeating its best fact until the reader stops hearing it.
            if let spokenAt = row.lastSpokenAt,
               now.timeIntervalSince(spokenAt) < Double(Bars.restDays) * 86_400 { continue }
            // Ranking only needs the counts. Nothing here pays for a calendar;
            // the surfaces that actually print a correspondence ask for the
            // full picture themselves.
            guard let stats = rankingStats(
                for: row, windowCache: &windowCache, offering: offering
            ) else { continue }
            let interest = GrimoireInterest.score(
                stats: stats, condition: condition, outcome: outcome,
                row: row, familiarity: familiarity, universeCount: universeCount, now: now
            )
            guard interest > 0 else { continue }
            scored.append((
                row, interest,
                familiarity.unexpectedness(condition: condition, outcome: outcome)
            ))
        }
        scored.sort { left, right in
            if left.interest != right.interest { return left.interest > right.interest }
            return left.row.id < right.row.id
        }
        return scored
    }

    /// The strongest things the Book could say right now, best first.
    func speakable(
        limit: Int = 3,
        now: Date = Date(),
        calendar: Calendar = .current,
        allowingSensitive: Bool = false
    ) -> [GrimoireCorrespondence] {
        Array(
            ranked(now: now, calendar: calendar, allowingSensitive: allowingSensitive)
                .prefix(max(0, limit))
                .map(\.row)
        )
    }

    /// The least expected thing the Book could honestly say.
    ///
    /// This exists so the grimoire does not settle into its own strongest
    /// handful of facts. It used to be appended to the end of `speakable`,
    /// where the one consumer — which takes the first row — could never reach
    /// it, so the reserved slot was quietly dead. Now it is its own question.
    ///
    /// Still has to clear every bar: a wager is a surprising *true* thing, not
    /// a licence to say something thin.
    func wager(
        now: Date = Date(),
        calendar: Calendar = .current,
        allowingSensitive: Bool = false
    ) -> GrimoireCorrespondence? {
        ranked(now: now, calendar: calendar, allowingSensitive: allowingSensitive)
            .max { left, right in
                if left.unexpected != right.unexpected { return left.unexpected < right.unexpected }
                return left.row.id > right.row.id
            }?
            .row
    }

    /// The rules the Book is sure of, written out.
    ///
    /// Only standing ones: a half-formed thing is not something to answer a
    /// reader's question with. Strongest first, because if only a few fit, they
    /// should be the ones the Book would stake most on.
    func standingLawLines(limit: Int = 6, calendar: Calendar = .current) -> [String] {
        rows.values
            .filter { $0.state == .standing }
            .sorted { $0.strengthPeak > $1.strengthPeak }
            .prefix(limit)
            .compactMap { GrimoireVoice.law(row: $0, ledger: self, calendar: calendar) }
    }

    /// Whether a wager is owed. The Book takes one long shot a week; the rest
    /// of the time it leads with what it is surest of.
    func owesAWager(now: Date = Date()) -> Bool {
        guard let last = lastWagerAt else { return true }
        return now.timeIntervalSince(last) >= Double(Bars.wagerIntervalDays) * 86_400
    }
}
