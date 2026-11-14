import Foundation

// MARK: - The Book running an experiment

/// A prediction the Book made in advance, about a day it arranged itself.
///
/// Everything else in the grimoire is watching. The Book counts what a life
/// already does and commits to a promise about what would take a rule back. It
/// never touches anything. That is careful, and it is also slow, and it leaves
/// one question permanently open: the reader chose every one of those days, so
/// a rule may only ever have been a description of when the reader felt like
/// doing the thing.
///
/// An experiment closes that. The Book picks a rule whose condition it can
/// actually cause, says out loud what it expects, sets the Working, and then
/// reads the answer. The day it arranged is already barred from judging the
/// passive promise — `bookAskedDays` saw to that before this existed — so the
/// two kinds of evidence never contaminate each other. This is the only place
/// the Book gets to find out whether it was describing a life or predicting it.
struct GrimoireExperiment: Codable, Equatable, Identifiable {

    /// How it ended.
    enum Verdict: String, Codable, Equatable, CaseIterable {
        /// Set, and not yet answered.
        case waiting
        /// The reader went, and the thing the Book expected followed.
        case held
        /// The reader went, and it did not.
        case missed
        /// The reader never went. The Book learns nothing, and says so.
        ///
        /// This is deliberately not a miss. A reader who ignores an errand has
        /// told the Book about their week, not about its rule — and counting
        /// it against the rule would quietly turn the grimoire into something
        /// that punishes you for not obeying it.
        case unanswered
    }

    var id: String
    /// The correspondence under test.
    var rowID: String
    /// The condition, as a Working the Book can actually set.
    var recipeID: String
    /// What the Book expects to follow.
    var outcomeID: String
    var predictedAt: Date
    var workingID: String?
    /// The day the reader actually did it. Absent until they do.
    var openedOn: Int?
    var windowDays: Int
    var verdict: Verdict
    var settledAt: Date?
    /// The Book's own words, fixed at the moment it committed. Never rewritten
    /// afterwards: a prediction you are allowed to edit is not a prediction.
    var prediction: String
    /// When the reader was actually told how it went.
    var reportedAt: Date? = nil
    /// The condition the Book arranged, as a feature id: a spell, a kind of
    /// mission, one of Wicker's dares. Absent on tests set with a Working,
    /// which predate it and name their cause through `recipeID`.
    var causeID: String? = nil

    var isRunning: Bool { verdict == .waiting }
    /// What the Book arranged, whatever kind of thing it was.
    var cause: String { causeID ?? "working:\(recipeID)" }
    var wasReported: Bool { reportedAt != nil }
}

extension GrimoireLedger {

    enum ExperimentBars {
        /// Days the outcome has to appear in, after the reader goes.
        static let window = 3
        /// Between one Working test and the next. A Working spends the house
        /// keys the reader lent (a calendar opening, a whisper), so it rests long.
        static let restDays = 21
        /// A spell, mission or dare is on the desk every day anyway; a test only
        /// picks which. So no rest between tests, only this much between two
        /// tests of the same rule, so the Book can't keep hammering a favourite.
        static let playRuleRestDays = 14
        /// A result the reader hasn't been shown holds the next play test back,
        /// so "I'm Trying Something" never piles up on "I Knew It". Past this
        /// long unshown, it stops holding: the desk may simply not have had room.
        static let unshownResultHoldDays = 7
        /// A Working the reader never took up expires as unanswered.
        static let patienceDays = 14
        /// A rule needs this much of its own evidence before a test is worth
        /// spending an errand on. Below it, the Book should just keep counting.
        static let minimumHits = 6
    }

    // MARK: Choosing what to test

    /// The rule most worth arranging a day for.
    ///
    /// Only rules the Book has already committed to out loud, whose condition
    /// is a Working it can set, and which it is not already sure of beyond
    /// doubt. A `standing` rule is the *best* candidate, not the worst: being
    /// sure of something you have only ever watched is exactly the position an
    /// experiment exists to check.
    func experimentCandidate(
        arrangeableRecipeIDs: [String],
        now: Date,
        calendar: Calendar = .current
    ) -> (row: GrimoireCorrespondence, recipeID: String, outcomeID: String)? {
        guard !arrangeableRecipeIDs.isEmpty else { return nil }
        let arrangeable = Set(arrangeableRecipeIDs)
        let candidates = rows.values.filter { row in
            guard row.isAlive, row.hasSpoken else { return false }
            guard row.state == .standing || row.state == .spoken else { return false }
            guard row.shape == .conditional || row.shape == .sequential else { return false }
            guard let outcomeID = row.outcomeID, ref(outcomeID) != nil else { return false }
            guard let recipe = GrimoireLedger.arrangeableRecipe(of: row.conditionID),
                  arrangeable.contains(recipe) else { return false }
            guard let stats = currentStats(for: row, calendar: calendar),
                  stats.inHits >= ExperimentBars.minimumHits else { return false }
            return true
        }
        // The one it is surest of, then the strongest. Testing a conviction is
        // worth more than testing a guess, because a conviction is the thing
        // the reader is being asked to believe.
        let best = candidates.sorted { left, right in
            if (left.state == .standing) != (right.state == .standing) {
                return left.state == .standing
            }
            if left.strengthPeak != right.strengthPeak { return left.strengthPeak > right.strengthPeak }
            return left.id < right.id
        }.first
        guard let best,
              let outcomeID = best.outcomeID,
              let recipeID = GrimoireLedger.arrangeableRecipe(of: best.conditionID) else { return nil }
        return (best, recipeID, outcomeID)
    }

    /// The Working id hiding inside a condition the Book can arrange.
    ///
    /// A single mapping, on purpose: whenever another thing the Book can cause
    /// grows a projector, it becomes testable by adding one line here.
    static func arrangeableRecipe(of conditionID: String) -> String? {
        let prefix = "working:"
        guard conditionID.hasPrefix(prefix) else { return nil }
        return String(conditionID.dropFirst(prefix.count)).nonEmpty
    }

    /// Whether the Book is free to start a Working test.
    ///
    /// The rest counts from the last *Working* test only. Spell, mission and
    /// dare tests run far more often, and counting them here would mean a
    /// Working was never tested again.
    func mayRunAnExperiment(now: Date) -> Bool {
        guard experiments.first(where: { $0.isRunning }) == nil else { return false }
        guard let last = experiments.filter({ $0.causeID == nil }).compactMap(\.settledAt).max() else { return true }
        return now.timeIntervalSince(last) >= Double(ExperimentBars.restDays) * 86_400
    }

    /// Whether the Book is free to start a spell, mission or dare test: nothing
    /// running, and the last result already shown (or given up on).
    func mayRunAPlayExperiment(now: Date) -> Bool {
        guard experiments.first(where: { $0.isRunning }) == nil else { return false }
        let hold = Double(ExperimentBars.unshownResultHoldDays) * 86_400
        return !unreportedExperiments().contains { experiment in
            guard let settledAt = experiment.settledAt else { return false }
            return now.timeIntervalSince(settledAt) < hold
        }
    }

    /// A rule tested recently rests, whatever the result was.
    func testedRecently(_ rowID: String, now: Date) -> Bool {
        let rest = Double(ExperimentBars.playRuleRestDays) * 86_400
        return experiments.contains { $0.rowID == rowID && now.timeIntervalSince($0.predictedAt) < rest }
    }

    var runningExperiment: GrimoireExperiment? {
        experiments.first { $0.isRunning }
    }

    /// The rule most worth testing with something the Book can put on the
    /// desk: a spell, a mission, a dare. Same bars as a Working test.
    func experimentCandidate(
        arrangeableCauses: Set<String>,
        now: Date,
        calendar: Calendar = .current
    ) -> (row: GrimoireCorrespondence, causeID: String, outcomeID: String)? {
        guard !arrangeableCauses.isEmpty else { return nil }
        let candidates = rows.values.filter { row in
            guard row.isAlive, row.hasSpoken else { return false }
            guard row.state == .standing || row.state == .spoken else { return false }
            guard row.shape == .conditional || row.shape == .sequential else { return false }
            guard arrangeableCauses.contains(row.conditionID) else { return false }
            guard !testedRecently(row.id, now: now) else { return false }
            guard let outcomeID = row.outcomeID, ref(outcomeID) != nil else { return false }
            guard let stats = currentStats(for: row, calendar: calendar),
                  stats.inHits >= ExperimentBars.minimumHits else { return false }
            return true
        }
        let best = candidates.sorted { left, right in
            if (left.state == .standing) != (right.state == .standing) {
                return left.state == .standing
            }
            if left.strengthPeak != right.strengthPeak { return left.strengthPeak > right.strengthPeak }
            return left.id < right.id
        }.first
        guard let best, let outcomeID = best.outcomeID else { return nil }
        return (best, best.conditionID, outcomeID)
    }

    // MARK: Committing

    /// Write the prediction down before a spell, mission or dare goes out.
    mutating func beginExperiment(
        row: GrimoireCorrespondence,
        causeID: String,
        outcomeID: String,
        now: Date,
        calendar: Calendar = .current
    ) {
        guard mayRunAPlayExperiment(now: now) else { return }
        commitExperiment(
            row: row, recipeID: causeID, outcomeID: outcomeID,
            workingID: nil, causeID: causeID, now: now, calendar: calendar
        )
    }

    /// Write the prediction down before anything happens.
    mutating func beginExperiment(
        row: GrimoireCorrespondence,
        recipeID: String,
        outcomeID: String,
        workingID: String?,
        now: Date,
        calendar: Calendar = .current
    ) {
        guard mayRunAnExperiment(now: now) else { return }
        commitExperiment(
            row: row, recipeID: recipeID, outcomeID: outcomeID,
            workingID: workingID, causeID: nil, now: now, calendar: calendar
        )
    }

    private mutating func commitExperiment(
        row: GrimoireCorrespondence,
        recipeID: String,
        outcomeID: String,
        workingID: String?,
        causeID: String?,
        now: Date,
        calendar: Calendar
    ) {
        let experiment = GrimoireExperiment(
            id: "experiment-\(row.id)-\(Int(now.timeIntervalSince1970))",
            rowID: row.id,
            recipeID: recipeID,
            outcomeID: outcomeID,
            predictedAt: now,
            workingID: workingID,
            openedOn: nil,
            windowDays: ExperimentBars.window,
            verdict: .waiting,
            prediction: GrimoireVoice.prediction(row: row, ledger: self, calendar: calendar),
            causeID: causeID
        )
        experiments.append(experiment)
        rows[row.id]?.revisions.append(GrimoireRevision(
            at: now, from: row.state, to: row.state,
            because: "I set something up to find out if this is true."
        ))
        // Saying it is still saying it. The rest window starts here, exactly as
        // it would if this had come up on the desk on its own.
        markSpoken(row.id, now: now, calendar: calendar)
    }

    // MARK: Reading the answer

    /// Settle whatever is running against the archive as it now stands.
    ///
    /// `wentOn` is the day the reader actually did the Working, if they did.
    mutating func settleExperiment(
        wentOn: Int?,
        abandoned: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> GrimoireExperiment? {
        guard let index = experiments.firstIndex(where: { $0.isRunning }) else { return nil }
        var experiment = experiments[index]

        if abandoned {
            experiment.verdict = .unanswered
            experiment.settledAt = now
            experiment.reportedAt = nil
            experiments[index] = experiment
            record(experiment)
            return experiment
        }

        guard let wentOn else {
            // Still out there. Give up on it only once patience runs out, so a
            // reader who takes a fortnight is not called a refusal.
            let waited = now.timeIntervalSince(experiment.predictedAt)
            guard waited >= Double(ExperimentBars.patienceDays) * 86_400 else { return nil }
            experiment.verdict = .unanswered
            experiment.settledAt = now
            experiment.reportedAt = nil
            experiments[index] = experiment
            record(experiment)
            return experiment
        }

        experiment.openedOn = wentOn
        // The outcome has the day itself and the window after it. Anything
        // outside that is a different day's business.
        let window = DayBitset.filled(from: wentOn, through: wentOn + experiment.windowDays)
        let followed = !days(of: experiment.outcomeID).intersection(window).isEmpty
        experiment.verdict = followed ? .held : .missed
        experiment.settledAt = now
        // Having shown the reader that a test was set does not count as having
        // shown them how it went.
        experiment.reportedAt = nil
        experiments[index] = experiment
        record(experiment)
        return experiment
    }

    /// Settle a test whose cause is a spell, mission or dare by reading the
    /// archive itself: the first day on or after the prediction that the reader
    /// did the arranged thing. Nothing else has to report back.
    ///
    /// A miss is called only once the whole window has passed, so a reader who
    /// does the mission today is not marked wrong before tomorrow arrives.
    mutating func settleArrangedExperiment(
        now: Date,
        calendar: Calendar = .current
    ) -> GrimoireExperiment? {
        guard let index = experiments.firstIndex(where: { $0.isRunning }),
              let cause = experiments[index].causeID else { return nil }
        var experiment = experiments[index]
        let predictedDay = GrimoireDay.index(for: experiment.predictedAt, calendar: calendar)
        let today = GrimoireDay.index(for: now, calendar: calendar)
        guard let wentOn = days(of: cause).days.first(where: { $0 >= predictedDay }) else {
            return settleExperiment(wentOn: nil, abandoned: false, now: now, calendar: calendar)
        }
        // Whatever happens next, this day was the Book's doing.
        markBookAsked(day: wentOn)
        experiment.openedOn = wentOn
        experiments[index] = experiment
        let window = DayBitset.filled(from: wentOn, through: wentOn + experiment.windowDays)
        let followed = !days(of: experiment.outcomeID).intersection(window).isEmpty
        guard followed || today > wentOn + experiment.windowDays else { return nil }
        return settleExperiment(wentOn: wentOn, abandoned: false, now: now, calendar: calendar)
    }

    /// What a settled experiment does to the rule it tested.
    private mutating func record(_ experiment: GrimoireExperiment) {
        guard var row = rows[experiment.rowID] else { return }
        let at = experiment.settledAt ?? Date()
        switch experiment.verdict {
        case .waiting:
            return
        case .unanswered:
            row.revisions.append(GrimoireRevision(
                at: at, from: row.state, to: row.state,
                because: "I set it up and you did not go. I still do not know."
            ))
        case .held:
            row.revisions.append(GrimoireRevision(
                at: at, from: row.state, to: row.state,
                because: "I made the day happen on purpose and it went the way I said."
            ))
        case .missed:
            // The Book stops being sure. Not crossed out — one arranged day is
            // not proof of a negative, and the passive promise still owns the
            // crossing-out. But a rule that failed the one test the Book ran
            // itself has no business being called settled.
            let from = row.state
            if from == .standing {
                row.state = .spoken
                row.revisions.append(GrimoireRevision(
                    at: at, from: from, to: .spoken,
                    because: "I made the day happen on purpose and it did not go my way. I am not sure any more."
                ))
            } else {
                row.revisions.append(GrimoireRevision(
                    at: at, from: from, to: from,
                    because: "I made the day happen on purpose and it did not go my way."
                ))
            }
        }
        rows[experiment.rowID] = row
    }

    /// Experiments the reader has not been shown the result of yet.
    func unreportedExperiments() -> [GrimoireExperiment] {
        experiments.filter { $0.verdict != .waiting && $0.settledAt != nil && !$0.wasReported }
    }

    mutating func markExperimentReported(_ id: String, now: Date) {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return }
        experiments[index].reportedAt = now
    }
}


// MARK: - Arranging a spell, mission or dare

/// What the Book can put on the desk on purpose, and how the desk honours it.
///
/// A spell is arrangeable only if nothing in the world has to cooperate: a fog
/// spell has no business on a clear day, so triggered spells are left out.
enum GrimoireArrangement {
    static let playPrefixes = ["spell:", "spell-kind:", "mission:", "mission-mode:", "dare:"]

    static func isPlayCause(_ featureID: String) -> Bool {
        playPrefixes.contains { featureID.hasPrefix($0) }
    }

    /// Every cause the desk can produce on demand.
    static func playCauses() -> Set<String> {
        var out = Set<String>()
        for spell in SpellRegistry.all where spell.trigger == nil {
            out.insert("spell:\(spell.id)")
            out.insert("spell-kind:\(spell.mechanic.rawValue)")
        }
        for mission in PlayfulMissionRegistry.missions {
            out.insert("mission:\(mission.id)")
            out.insert("mission-mode:\(mission.playMode.rawValue)")
        }
        for dare in WickerDareRegistry.immediate { out.insert("dare:\(dare.id)") }
        out.insert("dare:any")
        return out
    }

    /// The cause of the test running now, if it is one the desk arranges.
    static func arrangedCause(_ grimoire: GrimoireLedger) -> String? {
        guard let cause = grimoire.runningExperiment?.causeID, isPlayCause(cause) else { return nil }
        return cause
    }

    static func arrangedSpell(_ inputs: BookSourceInputs, dayID: String) -> SpellDef? {
        guard let cause = arrangedCause(inputs.grimoire) else { return nil }
        let open = SpellRegistry.all.filter { $0.trigger == nil && !inputs.restedSpellIDs.contains($0.id) }
        if cause.hasPrefix("spell-kind:") {
            let mechanic = String(cause.dropFirst("spell-kind:".count))
            let pool = open.filter { $0.mechanic.rawValue == mechanic }
            guard !pool.isEmpty else { return nil }
            return pool[abs("\(dayID)-\(cause)".stableHash) % pool.count]
        }
        guard cause.hasPrefix("spell:") else { return nil }
        let id = String(cause.dropFirst("spell:".count))
        return open.first { $0.id == id }
    }

    static func arrangedMission(_ inputs: BookSourceInputs, dayID: String) -> PlayfulMission? {
        guard let cause = arrangedCause(inputs.grimoire) else { return nil }
        if cause.hasPrefix("mission-mode:") {
            let mode = String(cause.dropFirst("mission-mode:".count))
            let pool = PlayfulMissionRegistry.missions.filter { $0.playMode.rawValue == mode }
            guard !pool.isEmpty else { return nil }
            return pool[abs("\(dayID)-\(cause)".stableHash) % pool.count]
        }
        guard cause.hasPrefix("mission:") else { return nil }
        let id = String(cause.dropFirst("mission:".count))
        return PlayfulMissionRegistry.missions.first { $0.id == id }
    }

    static func arrangedDare(_ inputs: BookSourceInputs) -> WickerDare? {
        guard let cause = arrangedCause(inputs.grimoire), cause.hasPrefix("dare:"), cause != "dare:any" else { return nil }
        let id = String(cause.dropFirst("dare:".count))
        return WickerDareRegistry.immediate.first { $0.id == id }
    }

    /// Tag the Page that carries the arranged thing and lift it to the desk.
    /// `causeIDs` are every cause this Page would satisfy: its own id and kind.
    static func marking(_ surface: SurfacePage, causeIDs: [String], inputs: BookSourceInputs) -> SurfacePage {
        guard let experiment = inputs.grimoire.runningExperiment,
              let cause = experiment.causeID, causeIDs.contains(cause) else { return surface }
        var metadata = surface.payload.metadata
        metadata["grimoireExperimentID"] = experiment.id
        return SurfacePage(
            id: surface.id, type: surface.type, sourceID: surface.sourceID,
            intent: surface.intent, renderStyle: surface.renderStyle,
            score: max(surface.score, 90),
            reason: surface.reason, prompt: surface.prompt, detail: surface.detail,
            payload: BookPagePayload(headline: surface.payload.headline, body: surface.payload.body, metadata: metadata)
        )
    }
}
