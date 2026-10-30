import SwiftUI

// MARK: - The writing session
//
// docs/noticing-and-writing-sessions-plan.md §3. The reader said yes to "I want
// to write, please?". The Book writes a short batch while the app is open,
// saves each piece the moment it is finished, and stops cleanly if the reader
// leaves. Nothing here runs in the background: the GPU is only ours while the
// Book is on screen.

extension ContentView {
    /// Yes starts a session now; Later costs nothing. Either way the Book
    /// doesn't ask again today.
    @MainActor
    func answerWritingAsk(yes: Bool) {
        vault.mutate { data in
            var desk = data.writingDesk ?? WritingDesk()
            desk.lastAnsweredAt = Date()
            data.writingDesk = desk
        }
        vault.save()
        selectedSurface = nil
        guard yes else { return }
        Task { await runWritingSession() }
    }

    @MainActor
    func runWritingSession() async {
        let started = Date()
        guard !localBrainTelemetry.isWorking, !WritingSessionForeground.isLeaving else {
            statusMessage = "I'm already writing something. Ask me again in a bit."
            return
        }
        // Edition leaves are only worked out here, not on every desk build:
        // finding a month's edition reads the archive.
        var desk = WritingDeskPlanner.refreshed(vault.data.writingDesk ?? WritingDesk(), days: days, now: started)
        if let period = editionLeavesDuePeriod(now: started),
           !(desk.finishedSubjects ?? []).contains(period.rawValue),
           !desk.wants.contains(where: { $0.subject == period.rawValue }) {
            desk.wants.append(WritingDeskPlanner.editionLeavesWant(monthID: period.rawValue, now: started))
        }
        // The loom's strongest unsaid finding, to be judged and retold. Worked
        // out here because it needs the whole source packet, not just days.
        if let connection = strongestUntoldConnection(desk: desk),
           !desk.wants.contains(where: { $0.subject == connection.id }) {
            desk.wants.append(WritingWant(
                id: RetoldConnections.wantPrefix + connection.id, kind: .retellConnection, sourcePageIDs: [],
                speakerID: "", createdAt: started, expiresAt: started.addingTimeInterval(3 * 86_400),
                subject: connection.id
            ))
        }
        let jobs = Array(desk.wants.sorted { $0.kind.priority < $1.kind.priority }.prefix(WritingDeskPlanner.jobsPerSession))
        guard !jobs.isEmpty else { return }

        WritingSessionForeground.hold()
        WritingSessionSecrecy.isActive = true
        defer {
            WritingSessionSecrecy.isActive = false
            WritingSessionForeground.release()
        }
        // A minute or two, as promised. Whatever isn't done by then waits.
        let deadline = started.addingTimeInterval(150)
        var finished = 0
        // What the journal is written from. Plain facts, and never what a
        // held piece is about, so the journal can't spoil it.
        var log: [String] = []

        for want in jobs {
            guard Date() < deadline, !WritingSessionForeground.isLeaving else { break }
            // The long job only starts with real time left.
            if want.kind == .editionLeaves, deadline.timeIntervalSinceNow < 90 { continue }
            let line: String?
            switch want.kind {
            case .castThought: line = await writeCastThought(want)
            case .noticingVerdict: line = await judgeNoticing(want)
            case .reread: line = await rereadHeld(want)
            case .joinNoticings: line = await joinNoticings(want)
            case .dream: line = await dream(want)
            case .wondering: line = await wonder(want)
            case .retellConnection: line = await retell(want)
            case .editionLeaves: line = await writeEditionLeaves(want)
            }
            if let line {
                finished += 1
                log.append(line)
            }
        }

        if !log.isEmpty, deadline.timeIntervalSinceNow > 10, !WritingSessionForeground.isLeaving {
            await writeJournal(log)
        }

        statusMessage = finished == 0
            ? "Nothing came out right, so I kept nothing. I'll ask another day."
            : "Done. I'm keeping it folded for now."
    }

    /// Saved the moment each job finishes: an interrupted session keeps
    /// everything it already did, and a retry can't do it twice.
    @MainActor
    private func saveDesk(_ change: (inout WritingDesk) -> Void) {
        let archive = days
        vault.mutate { data in
            var desk = WritingDeskPlanner.refreshed(data.writingDesk ?? WritingDesk(), days: archive, now: Date())
            change(&desk)
            data.writingDesk = desk
        }
        vault.save()
    }

    @MainActor
    private func writeCastThought(_ want: WritingWant) async -> String? {
        guard let speaker = NarrativePackRegistry.entities.first(where: { $0.id == want.speakerID }),
              let souvenir = days.lazy.flatMap(\.pages).first(where: { $0.id == want.sourcePageIDs.first }) else {
            return nil
        }
        let draft = StudentNotePageGenerator.draftCandidate(
            for: speaker,
            source: BookPageSourceRegistry.source(for: .note),
            day: today,
            inputs: sourceInputs,
            now: Date(),
            subjectPage: souvenir
        )
        guard let prose = await StudentNoteWriter().writeHeld(surface: draft) else { return nil }
        let held = WritingDeskPlanner.held(
            want: want,
            speakerName: speaker.name,
            surface: draft.preparedNoteCopy(prose: prose, slotID: "held-\(want.id)"),
            days: days,
            now: Date()
        )
        saveDesk { desk in
            desk.drawer.removeAll { $0.id == held.id }
            desk.drawer.append(held)
            desk.wants.removeAll { $0.id == want.id }
        }
        return "Wrote a note for one of the Cast to give the reader later, and folded it."
    }

    @MainActor
    private func judgeNoticing(_ want: WritingWant) async -> String? {
        guard let id = want.subject,
              let noticing = NoticingCrossings.noticings(days: days, now: Date()).first(where: { $0.id == id }) else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        let ask = WritingDeskPlanner.verdictPrompt(for: noticing)
        guard let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 16,
            sourceID: "noticing-verdict", tags: ["writing-session", "noticing-verdict"],
            temperature: 0.2, topP: 0.8
        ), let verdict = WritingDeskPlanner.parseVerdict(response, now: Date()) else { return nil }
        saveDesk { desk in desk = WritingDeskPlanner.withVerdict(desk, noticingID: id, verdict: verdict, now: Date()) }
        // A kept noticing is worth a bet about the next days it covers, in the
        // same margin as every other sealed wager.
        var sealed = false
        if verdict.keep,
           let wager = CrossingWagers.wager(from: noticing, existing: vault.data.wagers ?? [], now: Date()) {
            vault.mutate { $0.wagers = ($0.wagers ?? []) + [wager] }
            vault.save()
            sealed = true
        }
        return verdict.keep
            ? "Decided this was worth telling the reader: \(noticing.line)\(sealed ? " Sealed a wager about the next ones." : "")"
            : "Decided not to tell the reader this, because it was \(verdict.reason): \(noticing.line)"
    }

    @MainActor
    private func rereadHeld(_ want: WritingWant) async -> String? {
        guard let id = want.subject,
              let piece = (vault.data.writingDesk?.drawer ?? []).first(where: { $0.id == id && $0.disposition == .held }) else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        let souvenir = days.lazy.flatMap(\.pages).first { $0.id == piece.sourcePageIDs.first }
        guard let text = souvenir?.readerAuthoredTextForAnalysis else { return nil }
        let ask = WritingDeskPlanner.rereadPrompt(for: piece, souvenirText: text)
        guard let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 20,
            sourceID: "held-reread", tags: ["writing-session", "held-reread"],
            temperature: 0.2, topP: 0.8
        ), let crossedOut = WritingDeskPlanner.parseReread(response) else { return nil }
        saveDesk { desk in desk = WritingDeskPlanner.withReread(desk, pieceID: id, crossedOut: crossedOut, now: Date()) }
        return crossedOut.map { "Reread something folded for the reader and crossed it out: \($0)." }
            ?? "Reread something folded for the reader. It still fits. Left it folded."
    }

    @MainActor
    private func joinNoticings(_ want: WritingWant) async -> String? {
        let ids = (want.subject ?? "").split(separator: ",").map(String.init)
        let all = NoticingCrossings.noticings(days: days, now: Date())
        let parts = ids.compactMap { id in all.first { $0.id == id } }
        guard parts.count >= 2, let key = parts.first?.test?.conditionKey else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        let ask = JoinedFindings.prompt(for: parts)
        guard let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 150,
            sourceID: "noticing-join", tags: ["writing-session", "noticing-join"]
        ), let text = JoinedFindings.accept(response, evidence: parts) else { return nil }
        let surface = JoinedFindings.surface(text: text, noticings: parts, key: key)
        let held = HeldWriting(
            id: want.id, kind: .joinNoticings, speakerID: "book", speakerName: "I",
            surface: surface, sourcePageIDs: [],
            evidenceSignature: "", writtenAt: Date(),
            releaseAfter: Date().addingTimeInterval(WritingDeskPlanner.holdFor), disposition: .held
        )
        saveDesk { desk in
            desk.drawer.removeAll { $0.id == held.id }
            desk.drawer.append(held)
            desk.wants.removeAll { $0.id == want.id }
            desk.finishedSubjects = Array(((desk.finishedSubjects ?? []) + [want.id]).suffix(60))
        }
        return "Put \(NoticingCrossings.spelled(parts.count)) things I'd noticed together into one thought, and kept it for tomorrow."
    }

    /// Keeps a piece of the Book's own thinking in the drawer, to give later.
    @MainActor
    private func holdOwnThought(_ want: WritingWant, kind: WritingWant.Kind, surface: SurfacePage) {
        let held = HeldWriting(
            id: want.id, kind: kind, speakerID: "book", speakerName: "I",
            surface: surface, sourcePageIDs: [], evidenceSignature: "", writtenAt: Date(),
            releaseAfter: Date().addingTimeInterval(WritingDeskPlanner.holdFor), disposition: .held
        )
        saveDesk { desk in
            desk.drawer.removeAll { $0.id == held.id }
            desk.drawer.append(held)
            desk.wants.removeAll { $0.id == want.id }
        }
    }

    @MainActor
    private func dream(_ want: WritingWant) async -> String? {
        let material = ThinkingMaterials.recent(days: days, now: Date())
        guard material.count >= 2 else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        let ask = BookDreams.prompt(material)
        guard let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 170,
            sourceID: "book-dream", tags: ["writing-session", "book-dream"],
            temperature: 0.92, topP: 0.95
        ), let text = BookDreams.accept(response, material: material) else { return nil }
        holdOwnThought(want, kind: .dream, surface: BookDreams.surface(text, material: material))
        return "Had a dream made of the reader's pages. I'll tell them in the morning."
    }

    @MainActor
    private func wonder(_ want: WritingWant) async -> String? {
        let material = ThinkingMaterials.recent(days: days, now: Date())
        guard !material.isEmpty else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        let ask = BookWonderings.prompt(material)
        guard let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 50,
            sourceID: "book-wondering", tags: ["writing-session", "book-wondering"],
            temperature: 0.8, topP: 0.92
        ), let accepted = BookWonderings.accept(response, material: material) else { return nil }
        holdOwnThought(want, kind: .wondering, surface: BookWonderings.surface(question: accepted.question, about: accepted.about))
        return "Found something in the reader's pages I want to ask about. Saving the question."
    }

    @MainActor
    private func loomConnections() -> [RelationalLoomConnection] {
        let inputs = sourceInputs
        return RelationalLoom.connections(
            days: inputs.days + [today],
            readerLearning: inputs.readerLearning,
            facultyEntries: inputs.facultyEntries,
            people: inputs.people,
            continuity: inputs.continuity,
            daybookRows: inputs.daybookRows,
            standingLedger: inputs.standingLedger
        )
        // Keeping a Page is the Book's furniture, not the reader's day.
        .filter { $0.outcome.family != .pageKind && !$0.outcome.id.hasPrefix("activity:kept:") }
    }

    @MainActor
    private func strongestUntoldConnection(desk: WritingDesk) -> RelationalLoomConnection? {
        let spoken = Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix(RetoldConnections.spokeTagPrefix) ? String(tag.dropFirst(RetoldConnections.spokeTagPrefix.count)) : nil
        })
        let done = Set(desk.finishedSubjects ?? [])
        return loomConnections().first { !spoken.contains($0.id) && !done.contains(RetoldConnections.wantPrefix + $0.id) }
    }

    @MainActor
    private func retell(_ want: WritingWant) async -> String? {
        guard let id = want.subject, let connection = loomConnections().first(where: { $0.id == id }) else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        let ask = RetoldConnections.prompt(connection)
        let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 110,
            sourceID: "connection-retell", tags: ["writing-session", "connection-retell"],
            temperature: 0.5, topP: 0.85
        )
        guard let response else { return nil }
        // Judged either way: a drop is finished too, and never asked again.
        let text = RetoldConnections.accept(response, connection: connection)
        if let text {
            holdOwnThought(want, kind: .retellConnection, surface: RetoldConnections.surface(text, connection: connection))
        }
        saveDesk { desk in
            desk.wants.removeAll { $0.id == want.id }
            desk.finishedSubjects = Array(((desk.finishedSubjects ?? []) + [want.id]).suffix(60))
        }
        return text == nil
            ? "Found something that keeps happening and decided it wasn't worth saying."
            : "Found something that keeps happening and wrote it down in plain words for tomorrow."
    }

    @MainActor
    private func writeJournal(_ log: [String]) async {
        let ask = BookJournal.prompt(session: log)
        guard let response = await LocalBrainProse.write(
            prompt: ask.prompt, instructions: ask.instructions, maxTokens: 100,
            sourceID: "book-journal", tags: ["writing-session", "book-journal"]
        ), let text = BookJournal.accept(response, session: log) else { return }
        let entry = BookJournalEntry(id: UUID().uuidString, writtenAt: Date(), text: text)
        saveDesk { desk in
            desk.journal = Array(((desk.journal ?? []) + [entry]).suffix(BookJournal.keep))
        }
    }

    @MainActor
    private func writeEditionLeaves(_ want: WritingWant) async -> String? {
        guard let subject = want.subject,
              let period = editionLeavesDuePeriod(), period.rawValue == subject else {
            saveDesk { desk in desk.wants.removeAll { $0.id == want.id } }
            return nil
        }
        // The leaves land in the binding checkpoint itself; the desk only
        // remembers that the month is done.
        guard await writeEditionLeavesAhead(periodID: period) else { return nil }
        saveDesk { desk in
            desk.wants.removeAll { $0.id == want.id }
            desk.finishedSubjects = Array(((desk.finishedSubjects ?? []) + [subject]).suffix(60))
        }
        return "Wrote the first and last leaves for last month's book, so it's ready to bind."
    }
}

/// The local brain's foreground guard exists only where the local brain does.
/// Elsewhere (the simulator) there is no model, so the Book never asks.
private enum WritingSessionForeground {
    static var isLeaving: Bool {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
        return LocalBrainForeground.shared.isLeaving
        #else
        return false
        #endif
    }

    @MainActor
    static func hold() {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
        LocalBrainForeground.shared.holdScreenAwake()
        #endif
    }

    @MainActor
    static func release() {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
        LocalBrainForeground.shared.releaseScreen()
        #endif
    }
}

/// Unlike every other generation, a writing session never shows what is being
/// thought or written: no subject, no kind of job, no live ink. Every writing
/// card reads this and shows the sealed one instead.
@MainActor
enum WritingSessionSecrecy {
    nonisolated static let label = "writing-session-secret"
    static var isActive = false
}
