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

    var isRunning: Bool { verdict == .waiting }
    var wasReported: Bool { reportedAt != nil }
}

extension GrimoireLedger {

    enum ExperimentBars {
        /// Days the outcome has to appear in, after the reader goes.
        static let window = 3
        /// Between one test and the next. The Book is curious, not a nuisance.
        static let restDays = 21
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

    /// Whether the Book is free to start a test at all.
    func mayRunAnExperiment(now: Date) -> Bool {
        guard experiments.first(where: { $0.isRunning }) == nil else { return false }
        guard let last = experiments.compactMap(\.settledAt).max() else { return true }
        return now.timeIntervalSince(last) >= Double(ExperimentBars.restDays) * 86_400
    }

    var runningExperiment: GrimoireExperiment? {
        experiments.first { $0.isRunning }
    }

    // MARK: Committing

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
            prediction: GrimoireVoice.prediction(row: row, ledger: self, calendar: calendar)
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
