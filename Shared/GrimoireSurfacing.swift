import Foundation

// MARK: - Keeping the ledger

/// When the grimoire does its thinking.
///
/// The one rule the whole design rests on: **the desk never computes a
/// correspondence.** It reads standing rows. Everything here runs off the main
/// thread, on idle, in bounded chunks, and hands back a new ledger to save.
enum GrimoireKeeper {

    /// How long before the ledger folds new days in again. Discovery is not
    /// urgent; a correspondence that waits six hours is still true.
    static let ingestInterval: TimeInterval = 6 * 3_600
    /// Pairs examined per tend. Sized from the bench against the *real*
    /// projector pipeline, where a richer feature table makes each pair dearer
    /// than the synthetic bench suggested.
    static let sweepBudget = 250
    /// Forgetting is a weekly chore, not a daily one.
    static let pruneInterval: TimeInterval = 7 * 24 * 3_600

    struct Tending: Equatable {
        var ledger: GrimoireLedger
        var report: GrimoireLedger.SweepReport
        var ingested: Bool
        var changed: Bool
    }


    /// Is there anything worth waking up for?
    static func hasWork(_ ledger: GrimoireLedger, now: Date = Date()) -> Bool {
        if ledger.pendingSweepCount > 0 { return true }
        guard let last = ledger.lastIngestedAt else { return true }
        return now.timeIntervalSince(last) >= ingestInterval
    }

    /// Tend repeatedly until the backlog is gone or the time is spent.
    ///
    /// A first run on a mature archive has thousands of pairs waiting; one
    /// chunk would take weeks of launches to drain it. This keeps chunking
    /// inside a wall-clock budget so the work finishes without any single
    /// stretch being long enough to matter.
    static func drained(
        _ ledger: GrimoireLedger,
        slice: GrimoireSlice,
        now: Date = Date(),
        chunkBudget: Int = sweepBudget,
        maximumSeconds: Double = 1.5
    ) -> Tending {
        let deadline = Date().addingTimeInterval(maximumSeconds)
        var result = tended(ledger, slice: slice, now: now, budget: chunkBudget)
        var changed = result.changed
        while !result.report.finished, Date() < deadline {
            // Only the first pass ingests; the rest are pure sweeping.
            result = tended(result.ledger, slice: slice, now: now, budget: chunkBudget, force: false)
            changed = changed || result.changed
        }
        result.changed = changed
        return result
    }

    /// Fold in the archive if it is time, then sweep one chunk.
    ///
    /// Pure: it takes a ledger and returns a ledger. Nothing here touches the
    /// vault, the desk, or the main thread, which is what makes it safe to run
    /// from a detached task.
    static func tended(
        _ ledger: GrimoireLedger,
        slice: GrimoireSlice,
        now: Date = Date(),
        budget: Int = sweepBudget,
        force: Bool = false
    ) -> Tending {
        var working = ledger
        var ingested = false
        let due = force
            || working.lastIngestedAt.map { now.timeIntervalSince($0) >= ingestInterval } ?? true
        if due {
            working.reconcile(GrimoireProjection.observations(from: slice), now: now)
            ingested = true
        }
        let report = working.sweep(now: now, budget: budget, calendar: slice.calendar)
        // Only once the sweep has caught up: pruning renumbers every pair, and
        // doing that with a backlog outstanding would throw away work in flight.
        var forgot = 0
        if report.finished {
            let due = working.lastPrunedAt.map { now.timeIntervalSince($0) >= pruneInterval } ?? true
            if due { forgot = working.prune(now: now, calendar: slice.calendar) }
        }
        // A receipt of what this tend achieved, for the quiet leaf. Only real
        // outcomes count: pairs merely examined are not news.
        if !report.rowsCreated.isEmpty || !report.rowsCrossedOut.isEmpty {
            let carried = working.lastTending
            let fresh = carried?.isWorthMentioning == true ? carried : nil
            working.lastTending = GrimoireTendingMark(
                at: now,
                found: (fresh?.found ?? 0) + report.rowsCreated.count,
                crossedOut: (fresh?.crossedOut ?? 0) + report.rowsCrossedOut.count,
                line: GrimoireVoice.tendingLine(
                    found: report.rowsCreated, crossedOut: report.rowsCrossedOut, in: working
                ) ?? fresh?.line,
                shownAt: nil
            )
        }
        let changed = ingested
            || forgot > 0
            || report.pairsExamined > 0
            || !report.rowsCreated.isEmpty
            || !report.rowsPromoted.isEmpty
            || !report.rowsCrossedOut.isEmpty
        return Tending(ledger: working, report: report, ingested: ingested, changed: changed)
    }
}

// MARK: - Putting one on the desk

/// The grimoire's one Page.
///
/// It shares the Book Notices type — the reader already knows that shape, and
/// it already carries the correction machinery — but it is its own source, so
/// its cadence, rest and evidence belong to it. Precedent: the Weekly Issue
/// sits inside the Bindery type the same way.
struct GrimoirePageSourceAdapter: BookPageSourceAdapter {
    static let sourceID = "the-grimoire"

    let source = BookPageSourceRegistry.source(
        id: GrimoirePageSourceAdapter.sourceID,
        fallbackType: .bookNotices
    )

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let ledger = inputs.grimoire
        guard !ledger.rows.isEmpty else { return [] }
        // One correspondence at a time. The grimoire is a slow thing.
        guard !day.pages.contains(where: { $0.sourceID == source.id }) else { return [] }

        let forbidden = Set(inputs.bookReadingBoundaries.map(\.id))

        // An answer to a test the Book ran itself outranks everything. It
        // committed to this in advance and the reader is owed the result,
        // including — especially — when it was wrong.
        if let settled = ledger.unreportedExperiments()
            .first(where: { !forbidden.contains($0.rowID) }),
           let row = ledger.row(settled.rowID) {
            return [experimentSurface(settled, row: row, ledger: ledger, day: day, now: now)]
        }
        // A test the Book has just set up, explaining itself before the errand.
        if let running = ledger.runningExperiment,
           !running.wasReported,
           !forbidden.contains(running.rowID),
           let row = ledger.row(running.rowID) {
            return [experimentSurface(running, row: row, ledger: ledger, day: day, now: now)]
        }

        // A correction the Book owes outranks anything new it has to say.
        if let reversal = ledger.rows.values
            .filter({ $0.state == .crossedOut && !forbidden.contains($0.id) })
            .filter({ row in
                guard let crossedAt = row.revisions.last(where: { $0.to == .crossedOut })?.at else { return false }
                guard let spokenAt = row.lastSpokenAt else { return false }
                return spokenAt < crossedAt
            })
            .sorted(by: { ($0.revisions.last?.at ?? .distantPast) > ($1.revisions.last?.at ?? .distantPast) })
            .first {
            return [surface(for: reversal, ledger: ledger, day: day, now: now, isReversal: true)]
        }

        // Once a week the Book leads with its least expected reading instead of
        // its surest one. Anything else and the grimoire settles into repeating
        // its own strongest handful of facts.
        if ledger.owesAWager(now: now),
           let wager = ledger.wager(now: now, calendar: .current),
           !forbidden.contains(wager.id) {
            return [surface(for: wager, ledger: ledger, day: day, now: now, isReversal: false, isWager: true)]
        }
        guard let row = ledger
            .speakable(limit: 3, now: now, calendar: .current)
            .first(where: { !forbidden.contains($0.id) })
        else { return [] }
        return [surface(for: row, ledger: ledger, day: day, now: now, isReversal: false)]
    }

    func manualSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        let ledger = inputs.grimoire
        if let row = ledger.speakable(limit: 1, now: now, calendar: .current).first {
            return surface(for: row, ledger: ledger, day: day, now: now, isReversal: false)
        }
        return SurfacePage.handOpened(
            source: source, day: day, now: now,
            intent: .reflect, renderStyle: .loreLetter, score: 40,
            metadata: ["grimoireEmpty": "true"],
            tags: ["grimoire"]
        )
    }

    // MARK: Building the Page

    /// The Page that carries a test: the one the Book sets, and the one it
    /// settles. Both carry the prediction it committed to, so the reader is
    /// always reading the Book's own words back to it.
    private func experimentSurface(
        _ experiment: GrimoireExperiment,
        row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        day: BookDay,
        now: Date
    ) -> SurfacePage {
        let running = experiment.isRunning
        let body = running
            ? "\(GrimoireVoice.experimentSummons(row: row, ledger: ledger)) \(experiment.prediction)"
            : "\(experiment.prediction) \(GrimoireVoice.experimentResult(experiment, row: row, ledger: ledger))"
        var metadata: [String: String] = [
            "source": source.id,
            "observationKey": row.id,
            "grimoireExperimentID": experiment.id,
            "grimoireExperimentVerdict": experiment.verdict.rawValue,
            "grimoireShape": row.shape.rawValue,
            "tags": (["grimoire", "experiment", "experiment-\(experiment.verdict.rawValue)"])
                .joined(separator: ","),
            // No confirm/correct chips while a test is out: the reader
            // answering it in words would be the Book asking for its own
            // result. They can still shut the reading from anywhere else.
            "adaptiveActions": running ? "" : "confirmReading,correctReading"
        ]
        let evidence = ledger.evidencePageIDs(for: row)
        if !evidence.isEmpty { metadata["evidencePageIDs"] = evidence.joined(separator: ",") }
        return SurfacePage(
            id: "\(source.id)-\(experiment.id)-\(running ? "set" : "settled")",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            // Being wrong on purpose is the loudest thing the grimoire does.
            score: running ? 80 : 88,
            reason: running
                ? "I'm testing one of my own rules on you."
                : "I said what would happen before it happened.",
            prompt: running ? "I set this one up myself." : "Here is how my test went.",
            detail: experiment.prediction,
            payload: BookPagePayload(
                headline: GrimoireVoice.experimentTitle(experiment),
                body: body,
                metadata: metadata
            )
        )
    }

    private func surface(
        for row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        day: BookDay,
        now: Date,
        isReversal: Bool,
        isWager: Bool = false
    ) -> SurfacePage {
        let evidence = ledger.evidencePageIDs(for: row)
        let stats = ledger.currentStats(for: row)
        let body = GrimoireVoice.entry(row: row, ledger: ledger)
        let headline = GrimoireVoice.noticeTitle(
            row: row, isReversal: isReversal, isWager: isWager
        )
        // The card's callout says the rule itself, once, plainly. The title
        // above it has no labels in it and the body below says it again with
        // its counts, so this is the only line on the card that names the
        // thing — it has to be a sentence, not a pair of registry labels.
        let detail = stats.map {
            GrimoireVoice.plainClaim(row: row, stats: $0, ledger: ledger)
        }?.nonEmpty ?? headline

        var metadata: [String: String] = [
            "source": source.id,
            // The existing correction machinery keys off this, so a
            // correspondence can be confirmed, corrected, or shut without any
            // new plumbing — and a shut one never comes back.
            "observationKey": row.id,
            "grimoireCorrespondenceID": row.id,
            "grimoireShape": row.shape.rawValue,
            "grimoireState": row.state.rawValue,
            "tags": (["grimoire", "correspondence", row.shape.rawValue]
                     + (isReversal ? ["crossed-out"] : [])).joined(separator: ","),
            "adaptiveActions": "confirmReading,correctReading"
        ]
        if !evidence.isEmpty {
            metadata["evidencePageIDs"] = evidence.joined(separator: ",")
        }
        if let stats {
            metadata["grimoireHits"] = "\(stats.inHits)"
            metadata["grimoireChances"] = "\(stats.inCount)"
            if stats.distinctYears > 1 { metadata["grimoireYears"] = "\(stats.distinctYears)" }
        }
        if isReversal { metadata["grimoireReversal"] = "true" }
        // Read back by `speaking` so the Book knows when it last took a swing.
        if isWager { metadata["grimoireWager"] = "true" }

        return SurfacePage(
            id: "\(source.id)-\(row.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: isReversal ? 78 : min(84, 58 + row.interestPeak / 4),
            reason: isReversal
                ? "I made a claim about you and it stopped being true."
                : reason(for: row, stats: stats),
            prompt: isReversal ? "I have to take something back." : "One of your own rules.",
            detail: detail,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: metadata
            )
        )
    }

    private func reason(for row: GrimoireCorrespondence, stats: GrimoireStats?) -> String {
        guard let stats else { return "Something in your life keeps arriving with something else." }
        switch row.shape {
        case .seasonal:
            return "This has kept the same appointment \(stats.seasonsPresent) years running."
        case .sequential:
            return "One thing keeps following another, \(stats.inHits) times now."
        case .returnInterval:
            // One thing, leaving and coming back. There is no second half to
            // have arrived alongside it.
            return "This one goes quiet and comes back, \(stats.inHits) times now."
        case .conditional, .sibling:
            return "These two have arrived together \(stats.inHits) times."
        }
    }
}

// MARK: - The quiet leaf

extension GrimoireLedger {
    /// A small mark of what the Book got up to while the reader was away, for
    /// the binding-space between Pages.
    ///
    /// Never a Page and never a demand: the reader turns past it or does not.
    /// It is offered once and then let go, because a residue that repeats stops
    /// being evidence that anything happened.
    var quietLeafResidue: String? {
        guard let mark = lastTending, mark.isWorthMentioning else { return nil }
        return GrimoireVoice.residue(mark)
    }

    /// Let the mark go once it has been left somewhere.
    mutating func markResidueShown(now: Date = Date()) {
        guard lastTending?.isWorthMentioning == true else { return }
        lastTending?.shownAt = now
    }
}

// MARK: - Answering back

extension GrimoireLedger {
    /// Fold the reader's answer to a surfaced Page back into the grimoire.
    ///
    /// Returns nil when the Page was not a correspondence, so callers can wire
    /// this into the general Notices feedback path without checking first.
    static func recording(
        _ status: BookObservationStatus,
        for surface: SurfacePage,
        in ledger: GrimoireLedger,
        now: Date = Date()
    ) -> GrimoireLedger? {
        guard let id = surface.payload.metadata["grimoireCorrespondenceID"]?.nonEmpty else { return nil }
        guard ledger.row(id) != nil else { return nil }
        var updated = ledger
        updated.record(status, for: id, now: now)
        return updated
    }

    /// Mark that a Page carrying this correspondence actually reached the desk.
    static func speaking(
        _ surface: SurfacePage,
        in ledger: GrimoireLedger,
        now: Date = Date()
    ) -> GrimoireLedger? {
        var updated = ledger
        var changed = false
        // A test the reader has now seen — set, or answered — does not come
        // round again.
        if let id = surface.payload.metadata["grimoireExperimentID"]?.nonEmpty,
           ledger.experiments.contains(where: { $0.id == id }) {
            updated.markExperimentReported(id, now: now)
            changed = true
        }
        if let id = surface.payload.metadata["grimoireCorrespondenceID"]?.nonEmpty,
           ledger.row(id) != nil {
            updated.markSpoken(id, now: now)
            if surface.payload.metadata["grimoireWager"] == "true" {
                updated.lastWagerAt = now
            }
            changed = true
        }
        return changed ? updated : nil
    }
}
