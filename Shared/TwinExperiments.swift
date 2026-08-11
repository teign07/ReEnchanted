import Foundation

// MARK: - Experiments
//
// The point of everything before this. Until now the twin has been read-only:
// it shapes what surfaces and never reaches for anything. With a persisted
// history and lagged findings, it can do the thing a fairy godmother does:
// hold a belief about when someone is most alive, notice the conditions
// arriving, and put something in their way on purpose.
//
//   hypothesis → watch for the conditions → arrange a page → check
//
// The check is what makes it an experiment rather than a hunch, and it is
// deliberately not a check the Book can mark for itself: the delayed-outcome
// pulse is reader-answered, and reader-answered is the only thing allowed to
// say whether an arrangement worked. Inferred signals inform; they never score.
//
// CONSENT. Arranging conditions for someone is a real step past observing them,
// so this runs only under `BookWorkingAuthority`: the reader's existing,
// explicit, sealed-by-default grant, whose own doc comment says it exists
// "because the result can cause an unexpected real-world act". That is exactly
// this. Nothing here fires for a reader who has not opened that door, and it
// stops the moment they pause it.

struct TwinExperiment: Codable, Equatable, Identifiable {
    enum Standing: String, Codable, Equatable {
        /// Believed but never yet arranged for.
        case proposed
        /// The conditions arrived and a page was arranged. Awaiting a verdict.
        case arranged
        /// The reader answered afterwards and the answer was good.
        case borneOut
        /// The reader answered afterwards and the answer was not.
        case contradicted
        /// Enough attempts have failed that the belief is retired.
        case abandoned
    }

    var id: String
    /// The loom feature id whose arrival is the cue, e.g. `after:sleep:long`.
    var conditionFeatureID: String
    /// A short internal description of the belief. Never rendered.
    var beliefKey: String
    var standing: Standing
    var proposedAt: Date
    var lastArrangedAt: Date?
    /// Sessions arranged under this belief, awaiting or having received a verdict.
    var attempts: Int
    var borneOutCount: Int
    var contradictedCount: Int

    /// Retired after enough contradiction that continuing would be stubbornness.
    var isSpent: Bool {
        contradictedCount >= TwinExperimentGate.abandonAfterContradictions
    }

    /// The belief has earned the right to be relied on rather than tested.
    var isEstablished: Bool {
        borneOutCount >= TwinExperimentGate.establishAfterConfirmations
            && borneOutCount > contradictedCount
    }
}

enum TwinExperimentGate {
    /// Days between arrangements under the same belief. An experiment that runs
    /// every day is not an experiment, it is a habit the reader did not choose.
    static let restDays = 6
    /// Beliefs held at once. More than this and the Book is not arranging a
    /// day, it is running a schedule.
    static let maximumLive = 2
    static let abandonAfterContradictions = 3
    static let establishAfterConfirmations = 3
    /// A delayed-outcome pulse scoring at or above this counts as borne out.
    /// Relative to the reader's own baseline where one exists: an absolute bar
    /// would call a usually-low reader a failure and a usually-high one a win.
    static let absoluteSuccessScore = 6
}

struct TwinExperimentLedger: Codable, Equatable {
    var experiments: [TwinExperiment] = []
    var lastArrangedAt: Date?

    static let empty = TwinExperimentLedger()

    var live: [TwinExperiment] {
        experiments.filter { $0.standing == .proposed || $0.standing == .arranged }
    }

    mutating func upsert(_ experiment: TwinExperiment) {
        experiments.removeAll { $0.id == experiment.id }
        experiments.append(experiment)
    }

    func experiment(id: String) -> TwinExperiment? {
        experiments.first { $0.id == id }
    }
}

// MARK: - Running them

enum TwinExperimenter {
    /// Beliefs worth holding, drawn from lagged findings that already survived
    /// their holdout. Nothing is proposed from a same-day connection: those say
    /// what goes together, not what follows what, and only the second is
    /// something the Book can arrange for.
    static func propose(
        from confirmed: [RelationalLoomConnection],
        existing: TwinExperimentLedger,
        now: Date = Date()
    ) -> [TwinExperiment] {
        let alreadyHeld = Set(existing.experiments.map(\.conditionFeatureID))
        let room = max(0, TwinExperimentGate.maximumLive - existing.live.count)
        guard room > 0 else { return [] }

        return confirmed
            .filter { $0.condition.id.hasPrefix(LaggedDaybookLoom.conditionPrefix) }
            .filter { !alreadyHeld.contains($0.condition.id) }
            .sorted { $0.strength > $1.strength }
            .prefix(room)
            .map { connection in
                TwinExperiment(
                    id: "twin-experiment:\(connection.condition.id)->\(connection.outcome.id)",
                    conditionFeatureID: connection.condition.id,
                    beliefKey: "\(connection.condition.id)->\(connection.outcome.id)",
                    standing: .proposed,
                    proposedAt: now,
                    lastArrangedAt: nil,
                    attempts: 0,
                    borneOutCount: 0,
                    contradictedCount: 0
                )
            }
    }

    /// The experiment to act on today, if any.
    ///
    /// Returns nil (quietly and by design) whenever the reader has not opened
    /// the workings door, has paused it, is under distress, or simply is not
    /// standing in the conditions today.
    static func arrangeable(
        ledger: TwinExperimentLedger,
        yesterday: DaybookEntry?,
        standing: StandingLedger,
        authority: BookWorkingAuthority,
        distressActive: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TwinExperiment? {
        // The reader's own door, and the Book's oldest rule.
        guard authority.isActive(at: now), !distressActive, standing.isReady else { return nil }

        // Today's cue comes from yesterday's conditions: that is what "lagged"
        // means, and it is why the Book can see this coming at all.
        guard let yesterday,
              let observation = yesterday.loomObservation(ledger: standing, calendar: calendar) else {
            return nil
        }
        let arrivedIDs = Set(
            observation.features
                .filter { $0.family != .writing }
                .map { LaggedDaybookLoom.conditionPrefix + $0.id }
        )

        return ledger.live
            .filter { !$0.isSpent && !$0.isEstablished }
            .filter { arrivedIDs.contains($0.conditionFeatureID) }
            .filter { experiment in
                guard let last = experiment.lastArrangedAt else { return true }
                let days = calendar.dateComponents([.day], from: last, to: now).day ?? 0
                return days >= TwinExperimentGate.restDays
            }
            .min { $0.attempts < $1.attempts }
    }

    /// How much a page is lifted when it is the kind of page a live belief is
    /// betting on. Deliberately modest: an arrangement should tilt a desk, not
    /// replace it, and the reader must still be choosing from their own day.
    static let arrangementBoost = 14

    /// Marks a surface as having been put there on purpose, under a named
    /// belief. The tag is what lets a later delayed-outcome answer be attributed
    /// to this arrangement rather than to the day in general.
    static let arrangementTagPrefix = "twin-arrangement:"

    /// Whether this page is the kind of thing the belief is betting on.
    ///
    /// Every belief here predicts *writing*, so the arrangement is an invitation
    /// to write. It never manufactures a new page: it lifts one the desk was
    /// already offering, which keeps the reader choosing from their own day.
    static func isArrangeableSurface(_ page: SurfacePage) -> Bool {
        page.intent == .capture
    }

    /// Record that a page was arranged under a belief.
    static func markArranged(
        _ experiment: TwinExperiment,
        in ledger: inout TwinExperimentLedger,
        now: Date = Date()
    ) {
        var updated = experiment
        updated.standing = .arranged
        updated.lastArrangedAt = now
        updated.attempts += 1
        ledger.upsert(updated)
        ledger.lastArrangedAt = now
    }

    /// The reader's verdict, arriving as a delayed-outcome pulse.
    ///
    /// `baseline` is their own median delayed-outcome score where the Ledger has
    /// one. Judging against it rather than against a fixed bar is the difference
    /// between measuring a good page and measuring a good week: a reader whose
    /// usual is 4 answering 5 has improved, and one whose usual is 8 answering 6
    /// has not, and an absolute threshold reads both backwards.
    static func recordOutcome(
        experimentID: String,
        score: Int,
        baseline: Double?,
        in ledger: inout TwinExperimentLedger
    ) {
        guard var experiment = ledger.experiment(id: experimentID) else { return }

        let borneOut: Bool
        if let baseline {
            borneOut = Double(score) > baseline
        } else {
            borneOut = score >= TwinExperimentGate.absoluteSuccessScore
        }

        if borneOut {
            experiment.borneOutCount += 1
            experiment.standing = .borneOut
        } else {
            experiment.contradictedCount += 1
            experiment.standing = .contradicted
        }
        if experiment.isSpent {
            experiment.standing = .abandoned
        }
        ledger.upsert(experiment)
    }
}
