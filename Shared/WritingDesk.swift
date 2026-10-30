import Foundation

// MARK: - "I want to write, please?"
//
// docs/noticing-and-writing-sessions-plan.md §2–3, Phase 3. The Book keeps a
// short list of things it wants to write, asks for a little time, writes them
// while the app is open, and holds what it wrote until later. Opening a held
// piece reveals the saved text; nothing is written again on opening.
//
// The first and only job kind so far: a Cast member's thought about a Souvenir
// the reader kept. It stays private until it is revealed, as that member's own
// note. Until then it is never something the reader was told, and it is never
// evidence about the reader's life.

/// Something the Book wants to write but hasn't yet.
struct WritingWant: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        /// A Cast member's thought about a kept Souvenir, held and revealed.
        case castThought
        /// The court's verdict on a noticing before it may be said.
        case noticingVerdict
        /// Rereading held writing against the archive as it is now.
        case reread
        /// A finished month's cover leaves, so binding it is instant.
        case editionLeaves
        /// Two or more kept noticings about one condition, made one thought.
        case joinNoticings
        /// A dream made of the reader's recent pages, told in the morning.
        case dream
        /// One real question about one detail, asked later.
        case wondering
        /// A loom connection judged and retold in plain words.
        case retellConnection

        /// Short judgments first (a verdict is a few words); then the second
        /// look at held writing; then what the Book wants to make; and the
        /// long edition leaves last, only when the session has time to spare.
        var priority: Int {
            switch self {
            case .noticingVerdict: return 0
            case .reread: return 1
            case .retellConnection: return 2
            case .joinNoticings: return 2
            case .wondering: return 3
            case .dream: return 4
            case .castThought: return 5
            case .editionLeaves: return 6
            }
        }
    }

    /// Stable per subject, so the same Souvenir never becomes two wants.
    var id: String
    var kind: Kind
    var sourcePageIDs: [String]
    var speakerID: String
    var createdAt: Date
    var expiresAt: Date
    /// What a non-Page job is about: a noticing id, a held piece, a month.
    var subject: String? = nil
}

/// The model's word on one noticing. A dropped noticing never reaches the desk.
struct NoticingVerdict: Codable, Equatable {
    var keep: Bool
    /// `same-fact`, `obvious`, `boring`, `unfounded`, or `ok`.
    var reason: String
    var judgedAt: Date
}

/// Finished writing, frozen, waiting for its moment.
struct HeldWriting: Codable, Equatable, Identifiable {
    enum Disposition: String, Codable {
        case held
        /// Shown and kept: it is the reader's now.
        case revealed
        /// Its sources changed or vanished, or its moment passed, before it was
        /// shown. Never shown.
        case withdrawn
    }

    var id: String
    var kind: WritingWant.Kind
    var speakerID: String
    var speakerName: String
    /// The whole prepared Page, prose included. Revealing it is a lookup.
    var surface: SurfacePage
    var sourcePageIDs: [String]
    var evidenceSignature: String
    var writtenAt: Date
    var releaseAfter: Date
    var disposition: Disposition
    /// When the Book reread it against the archive, and why it crossed it out
    /// if it did. Optional so pieces held before rereading existed still open.
    var rereadAt: Date? = nil
    var crossedOutReason: String? = nil
}

struct WritingDesk: Codable, Equatable {
    var wants: [WritingWant] = []
    var drawer: [HeldWriting] = []
    /// When the reader last answered the ask, either way. One ask a day.
    var lastAnsweredAt: Date? = nil
    /// Verdicts by noticing id. Optional so older desks still decode.
    var verdicts: [String: NoticingVerdict]? = nil
    /// Jobs that leave nothing in the drawer but must not be redone (a month's
    /// edition leaves). Optional for the same reason.
    var finishedSubjects: [String]? = nil
    /// What the Book wrote down about its sessions.
    var journal: [BookJournalEntry]? = nil

    var heldCount: Int { drawer.filter { $0.disposition == .held }.count }
}

enum WritingDeskPlanner {
    static let heldTag = "held-writing"
    static let heldTagPrefix = "held-writing:"
    static let wantLifetime: TimeInterval = 3 * 86_400
    /// Written today, given tomorrow at the earliest: the point is that it was kept.
    static let holdFor: TimeInterval = 14 * 3_600
    /// After this the moment has passed, and the piece is withdrawn unshown.
    static let staleAfter: TimeInterval = 10 * 86_400
    static let maxWants = 8
    /// Don't hoard: with this many waiting, write nothing new.
    static let maxHeld = 3
    /// A session's work, so the reader isn't kept waiting.
    static let jobsPerSession = 5

    // MARK: Wants

    /// Souvenirs kept in the last three days with enough of the reader's own
    /// words to react to, each assigned one speaker.
    static func refreshed(_ desk: WritingDesk, days: [BookDay], now: Date) -> WritingDesk {
        var desk = settled(desk, days: days, now: now)
        let pages = days.flatMap(\.pages)
        let pageIDs = Set(pages.map(\.id))
        let written = Set(desk.drawer.map(\.id))
        desk.wants.removeAll { want in
            want.expiresAt <= now
                || written.contains(want.id)
                || !want.sourcePageIDs.allSatisfy(pageIDs.contains)
        }
        let wanted = Set(desk.wants.map(\.id))
        let recentSpeakers = desk.drawer.suffix(3).map(\.speakerID) + desk.wants.map(\.speakerID)
        let souvenirs = pages
            .filter { page in
                page.type == .souvenir
                    && now.timeIntervalSince(page.createdAt) < wantLifetime
                    && page.createdAt <= now
                    && (page.readerAuthoredTextForAnalysis?.split(whereSeparator: \.isWhitespace).count ?? 0) >= 6
            }
            .sorted { $0.createdAt > $1.createdAt }
        for page in souvenirs {
            let id = "cast-thought:\(page.id)"
            guard !wanted.contains(id), !written.contains(id),
                  let speaker = speaker(for: page.id, avoiding: recentSpeakers) else { continue }
            desk.wants.append(WritingWant(
                id: id,
                kind: .castThought,
                sourcePageIDs: [page.id],
                speakerID: speaker.id,
                createdAt: now,
                expiresAt: page.createdAt.addingTimeInterval(wantLifetime)
            ))
        }
        desk = withVerdictWants(desk, days: days, now: now)
        desk = withRereadWants(desk, now: now)
        desk = withJoinWants(desk, days: days, now: now)
        desk = withDreamAndWonderWants(desk, days: days, now: now)
        desk.wants = Array(desk.wants.sorted { left, right in
            left.kind.priority == right.kind.priority ? left.createdAt > right.createdAt : left.kind.priority < right.kind.priority
        }.prefix(maxWants))
        return desk
    }

    // MARK: Verdicts

    static let verdictsPerArchive = 3
    static let verdictLifetime: TimeInterval = 21 * 86_400

    /// The strongest crossings and trends that haven't been said or judged.
    /// The rest wait: three verdicts at a time is plenty for one desk.
    static func withVerdictWants(_ desk: WritingDesk, days: [BookDay], now: Date) -> WritingDesk {
        var desk = desk
        let judged = desk.verdicts ?? [:]
        let spoken = Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix(BookNoticesPageSourceAdapter.crossingSpokeTagPrefix)
                ? String(tag.dropFirst(BookNoticesPageSourceAdapter.crossingSpokeTagPrefix.count)) : nil
        })
        let open = NoticingCrossings.noticings(days: days, now: now)
            .filter { ($0.kind == .crossing || $0.kind == .trend) && !spoken.contains($0.id) && judged[$0.id] == nil }
            .prefix(verdictsPerArchive)
        let wanted = Set(desk.wants.map(\.id))
        for noticing in open where !wanted.contains("verdict:\(noticing.id)") {
            desk.wants.append(WritingWant(
                id: "verdict:\(noticing.id)", kind: .noticingVerdict, sourcePageIDs: [],
                speakerID: "", createdAt: now, expiresAt: now.addingTimeInterval(7 * 86_400),
                subject: noticing.id
            ))
        }
        return desk
    }

    static func verdictPrompt(for noticing: Noticing) -> (prompt: String, instructions: String) {
        let receipts = noticing.receipts.prefix(3).map { "- \($0.text)" }.joined(separator: "\n")
        let prompt = """
        A diary app wants to tell its reader this about their own life:
        "\(noticing.line)"
        What it counted: \(noticing.counted ?? "nothing beyond the sentence")
        Pages behind it:
        \(receipts.isEmpty ? "- none quoted" : receipts)

        Judge it. Answer with exactly one line: KEEP or DROP, a colon, and one reason word.
        Reason words: same-fact (the two things are one fact seen twice), obvious (anyone would expect it), boring (true but nobody would care), unfounded (the evidence doesn't show it), ok (worth saying).
        """
        let instructions = "You are a strict, plain-spoken editor. You only answer in the requested one-line format."
        return (prompt, instructions)
    }

    /// "KEEP: ok", "DROP: obvious". Anything else is no verdict at all.
    static func parseVerdict(_ response: String, now: Date) -> NoticingVerdict? {
        let line = response.uppercased().split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let keep: Bool
        if line.contains("KEEP") { keep = true } else if line.contains("DROP") { keep = false } else { return nil }
        let reasons = ["same-fact", "obvious", "boring", "unfounded", "ok"]
        let lowered = response.lowercased()
        let reason = reasons.first { lowered.contains($0) } ?? (keep ? "ok" : "boring")
        // "KEEP: boring" is a contradiction; trust the reason, which is the judgment.
        return NoticingVerdict(keep: keep && reason == "ok", reason: reason, judgedAt: now)
    }

    static func withVerdict(_ desk: WritingDesk, noticingID: String, verdict: NoticingVerdict, now: Date) -> WritingDesk {
        var desk = desk
        var verdicts = (desk.verdicts ?? [:]).filter { now.timeIntervalSince($0.value.judgedAt) < verdictLifetime }
        verdicts[noticingID] = verdict
        desk.verdicts = verdicts
        desk.wants.removeAll { $0.id == "verdict:\(noticingID)" }
        return desk
    }

    // MARK: Joining

    static func spokenNoticingIDs(_ days: [BookDay]) -> Set<String> {
        Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix(BookNoticesPageSourceAdapter.crossingSpokeTagPrefix)
                ? String(tag.dropFirst(BookNoticesPageSourceAdapter.crossingSpokeTagPrefix.count)) : nil
        })
    }

    /// Kept noticings that share a condition become one thought to write.
    static func withJoinWants(_ desk: WritingDesk, days: [BookDay], now: Date) -> WritingDesk {
        var desk = desk
        let finished = Set(desk.finishedSubjects ?? [])
        let held = Set(desk.drawer.map(\.id))
        let wanted = Set(desk.wants.map(\.id))
        let groups = JoinedFindings.groups(
            NoticingCrossings.noticings(days: days, now: now),
            verdicts: desk.verdicts ?? [:],
            spoken: spokenNoticingIDs(days)
        )
        for group in groups.prefix(1) {
            let id = JoinedFindings.wantPrefix + group.key
            guard !finished.contains(id), !held.contains(id), !wanted.contains(id) else { continue }
            desk.wants.append(WritingWant(
                id: id, kind: .joinNoticings, sourcePageIDs: [], speakerID: "",
                createdAt: now, expiresAt: now.addingTimeInterval(7 * 86_400),
                subject: group.noticings.map(\.id).joined(separator: ",")
            ))
        }
        return desk
    }

    // MARK: Dreams and wonderings

    /// A dream every couple of days and a question every few, each only when
    /// there are enough new pages of the reader's own to make it from.
    static func withDreamAndWonderWants(_ desk: WritingDesk, days: [BookDay], now: Date) -> WritingDesk {
        var desk = desk
        func last(_ kind: WritingWant.Kind) -> Date? {
            (desk.drawer.filter { $0.kind == kind }.map(\.writtenAt) + desk.wants.filter { $0.kind == kind }.map(\.createdAt)).max()
        }
        func want(_ kind: WritingWant.Kind, prefix: String, rest: Double, needs: Int) {
            if let previous = last(kind), now.timeIntervalSince(previous) < rest * 86_400 { return }
            let material = ThinkingMaterials.recent(days: days, now: now)
            let fresh = material.filter { page in last(kind).map { page.date > $0 } ?? true }
            guard fresh.count >= needs else { return }
            desk.wants.append(WritingWant(
                id: prefix + BookDay.id(for: now), kind: kind, sourcePageIDs: material.map(\.pageID), speakerID: "",
                createdAt: now, expiresAt: now.addingTimeInterval(2 * 86_400)
            ))
        }
        want(.dream, prefix: BookDreams.wantPrefix, rest: BookDreams.restDays, needs: BookDreams.needsPages)
        want(.wondering, prefix: BookWonderings.wantPrefix, rest: BookWonderings.restDays, needs: BookWonderings.needsPages)
        return desk
    }

    // MARK: Rereading

    /// Held at least six hours and not yet reread: worth a second look before
    /// anyone sees it.
    static func withRereadWants(_ desk: WritingDesk, now: Date) -> WritingDesk {
        var desk = desk
        let wanted = Set(desk.wants.map(\.id))
        for piece in desk.drawer where piece.disposition == .held && piece.rereadAt == nil
            && now.timeIntervalSince(piece.writtenAt) >= 6 * 3_600 && !wanted.contains("reread:\(piece.id)") {
            desk.wants.append(WritingWant(
                id: "reread:\(piece.id)", kind: .reread, sourcePageIDs: piece.sourcePageIDs,
                speakerID: piece.speakerID, createdAt: now, expiresAt: piece.releaseAfter.addingTimeInterval(staleAfter),
                subject: piece.id
            ))
        }
        return desk
    }

    static func rereadPrompt(for piece: HeldWriting, souvenirText: String) -> (prompt: String, instructions: String) {
        let note = piece.surface.payload.metadata["noteProse"] ?? piece.surface.payload.body
        let prompt = """
        \(piece.speakerName) wrote this note about something the reader kept:
        "\(note)"

        What the reader kept, as it stands now:
        "\(souvenirText)"

        Reread the note. Does it still fit what the reader kept, and does it stay true to it without inventing anything?
        Answer with exactly one line: KEEP, or CROSS OUT followed by a colon and five words or fewer saying why.
        """
        return (prompt, "You are rereading your own writing before anyone sees it. Answer only in the requested one-line format.")
    }

    /// nil means keep; a string is why it was crossed out. Unreadable answers keep it.
    static func parseReread(_ response: String) -> String?? {
        let line = response.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let upper = line.uppercased()
        if upper.hasPrefix("KEEP") { return .some(nil) }
        guard upper.contains("CROSS OUT") else { return nil }
        let reason = line.split(separator: ":", maxSplits: 1).dropFirst().first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }?.nonEmpty ?? "it didn't fit"
        return .some(String(reason.prefix(80)))
    }

    static func withReread(_ desk: WritingDesk, pieceID: String, crossedOut: String?, now: Date) -> WritingDesk {
        var desk = desk
        if let index = desk.drawer.firstIndex(where: { $0.id == pieceID }) {
            desk.drawer[index].rereadAt = now
            if let crossedOut {
                desk.drawer[index].crossedOutReason = crossedOut
                desk.drawer[index].disposition = .withdrawn
            }
        }
        desk.wants.removeAll { $0.id == "reread:\(pieceID)" }
        return desk
    }

    // MARK: Edition leaves

    static func editionLeavesWant(monthID: String, now: Date) -> WritingWant {
        WritingWant(
            id: "edition-leaves:\(monthID)", kind: .editionLeaves, sourcePageIDs: [], speakerID: "",
            createdAt: now, expiresAt: now.addingTimeInterval(14 * 86_400), subject: monthID
        )
    }

    /// One of the Cast with a written voice, picked from the Souvenir itself so
    /// the same page always goes to the same person.
    static func speaker(for pageID: String, avoiding recent: [String]) -> NarrativeWorldEntity? {
        let voiced = Set(CharacterVoiceCatalog.priorityCharacterIDs)
        let cast = NarrativePackRegistry.entities
            .filter { $0.kind == .character && voiced.contains($0.id) }
            .sorted { $0.id < $1.id }
        let fresh = cast.filter { !recent.contains($0.id) }
        let pool = fresh.isEmpty ? cast : fresh
        guard !pool.isEmpty else { return nil }
        return pool[Int(fnv1a(pageID) % UInt64(pool.count))]
    }

    /// Kept pieces become the reader's; ones whose sources changed or whose
    /// moment passed are withdrawn. The drawer keeps a short history so a
    /// Souvenir is never written about twice.
    static func settled(_ desk: WritingDesk, days: [BookDay], now: Date) -> WritingDesk {
        var desk = desk
        let keptTags = Set(days.flatMap(\.pages).flatMap(\.tags))
        let withdrawn = release(desk, days: days, now: now).withdrawn
        for index in desk.drawer.indices where desk.drawer[index].disposition == .held {
            if keptTags.contains(heldTagPrefix + desk.drawer[index].id) {
                desk.drawer[index].disposition = .revealed
            } else if withdrawn.contains(desk.drawer[index].id) {
                desk.drawer[index].disposition = .withdrawn
            }
        }
        let held = desk.drawer.filter { $0.disposition == .held }
        let history = desk.drawer.filter { $0.disposition != .held }.suffix(30)
        desk.drawer = (Array(history) + held).sorted { $0.writtenAt < $1.writtenAt }
        return desk
    }

    // MARK: The ask

    static func shouldAsk(_ desk: WritingDesk, localBrainReady: Bool, now: Date, calendar: Calendar = .current) -> Bool {
        guard localBrainReady, !desk.wants.isEmpty, desk.heldCount < maxHeld else { return false }
        if let answered = desk.lastAnsweredAt, calendar.isDate(answered, inSameDayAs: now) { return false }
        return true
    }

    static let askMetadataKey = "writingAsk"

    /// The Book asks plainly and doesn't say what. Later costs nothing.
    static func askSurface(_ desk: WritingDesk, day: BookDay, now: Date) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .bookNotices)
        let hunger = desk.wants.count >= 3
            ? "\n\nI've got \(NoticingCrossings.spelled(desk.wants.count)) things I want to write."
            : ""
        let body = """
        I want to write something. Please?\(hunger)

        I won't tell you what. You'll find out when it's ready.

        It takes a minute or two, and you have to hold me open while I do it. If you close me, I stop and keep what I've got.
        """
        return SurfacePage(
            id: "\(source.id)-writing-ask-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 74,
            reason: "I want to write something.",
            prompt: "Please?",
            detail: "I want to write something. Please?",
            payload: BookPagePayload(
                headline: "I Want to Write",
                body: body,
                metadata: [
                    "source": source.id,
                    askMetadataKey: "true",
                    "writingWantCount": "\(desk.wants.count)",
                    "tags": "writing-ask"
                ]
            )
        )
    }

    // MARK: Holding

    /// Identity and length of the sources, enough to notice an edit or a
    /// deletion without reading anything twice.
    static func evidenceSignature(_ pageIDs: [String], days: [BookDay]) -> String {
        let pages = days.flatMap(\.pages)
        return pageIDs.map { id in
            guard let page = pages.first(where: { $0.id == id }) else { return "\(id):gone" }
            return "\(id):\(page.userInput.utf8.count):\(page.playerReply.utf8.count)"
        }.joined(separator: "|")
    }

    static func held(
        want: WritingWant,
        speakerName: String,
        surface: SurfacePage,
        days: [BookDay],
        now: Date
    ) -> HeldWriting {
        HeldWriting(
            id: want.id,
            kind: want.kind,
            speakerID: want.speakerID,
            speakerName: speakerName,
            surface: surface,
            sourcePageIDs: want.sourcePageIDs,
            evidenceSignature: evidenceSignature(want.sourcePageIDs, days: days),
            writtenAt: now,
            releaseAfter: now.addingTimeInterval(holdFor),
            disposition: .held
        )
    }

    // MARK: Release

    /// What may be shown now, and what has to be withdrawn because its sources
    /// changed, vanished, or the moment passed. A withdrawn piece is never shown.
    static func release(_ desk: WritingDesk, days: [BookDay], now: Date) -> (ready: [HeldWriting], withdrawn: Set<String>) {
        let keptTags = Set(days.flatMap(\.pages).flatMap(\.tags))
        var ready: [HeldWriting] = []
        var withdrawn = Set<String>()
        for piece in desk.drawer where piece.disposition == .held {
            if keptTags.contains(heldTagPrefix + piece.id) { continue }
            guard piece.releaseAfter <= now else { continue }
            if now.timeIntervalSince(piece.releaseAfter) > staleAfter
                || evidenceSignature(piece.sourcePageIDs, days: days) != piece.evidenceSignature {
                withdrawn.insert(piece.id)
                continue
            }
            ready.append(piece)
        }
        return (ready.sorted { $0.writtenAt < $1.writtenAt }, withdrawn)
    }

    /// The held Page as it was written, marked so keeping it retires it.
    static func revealSurface(_ piece: HeldWriting, now: Date, calendar: Calendar = .current) -> SurfacePage {
        guard piece.kind == .castThought else { return revealOwnThought(piece) }
        var surface = piece.surface
        var metadata = surface.payload.metadata
        let existingTags = (metadata["tags"] ?? "").split(separator: ",").map(String.init)
        metadata["tags"] = (existingTags + [heldTag, heldTagPrefix + piece.id]).joined(separator: ",")
        metadata["heldWritingID"] = piece.id
        metadata["heldWrittenAt"] = ISO8601DateFormatter().string(from: piece.writtenAt)
        let written = calendar.isDateInYesterday(piece.writtenAt) ? "yesterday"
            : "on \(NoticingCrossings.weekdayNames[calendar.component(.weekday, from: piece.writtenAt) - 1])"
        surface = SurfacePage(
            id: "held-\(piece.id)",
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: max(surface.score, 80),
            reason: "\(piece.speakerName) wrote this \(written) and kept it folded until now.",
            prompt: "\(piece.speakerName) left you something.",
            detail: "Folded \(written). Kept until now.",
            payload: BookPagePayload(headline: surface.payload.headline, body: surface.payload.body, metadata: metadata)
        )
        return surface
    }

    /// The Book's own held thought keeps its own words and prompt; it only
    /// gains the tag that retires it once kept.
    static func revealOwnThought(_ piece: HeldWriting) -> SurfacePage {
        var metadata = piece.surface.payload.metadata
        let existingTags = (metadata["tags"] ?? "").split(separator: ",").map(String.init)
        metadata["tags"] = (existingTags + [heldTag, heldTagPrefix + piece.id]).joined(separator: ",")
        metadata["heldWritingID"] = piece.id
        metadata["heldWrittenAt"] = ISO8601DateFormatter().string(from: piece.writtenAt)
        let surface = piece.surface
        return SurfacePage(
            id: "held-\(piece.id)", type: surface.type, sourceID: surface.sourceID, intent: surface.intent,
            renderStyle: surface.renderStyle, score: surface.score, reason: surface.reason, prompt: surface.prompt,
            detail: surface.detail,
            payload: BookPagePayload(headline: surface.payload.headline, body: surface.payload.body, metadata: metadata)
        )
    }

    /// Stable across launches, unlike `Hasher`.
    static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
    }
}

// MARK: - On the desk

/// Asks to write, and hands back what was written once its time comes.
struct WritingDeskPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .note)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        var pages: [SurfacePage] = []
        // One held piece a day, so a drawer emptying doesn't flood the desk.
        let revealedToday = day.pages.contains { $0.tags.contains(WritingDeskPlanner.heldTag) }
        if !revealedToday, let next = WritingDeskPlanner.release(inputs.writingDesk, days: allDays, now: now).ready.first {
            pages.append(WritingDeskPlanner.revealSurface(next, now: now))
        }
        let desk = WritingDeskPlanner.refreshed(inputs.writingDesk, days: allDays, now: now)
        if !context.distress.isActive,
           WritingDeskPlanner.shouldAsk(desk, localBrainReady: inputs.localBrainIsReady, now: now) {
            pages.append(WritingDeskPlanner.askSurface(desk, day: day, now: now))
        }
        if let journal = BookJournal.surface(desk.journal ?? [], days: allDays, now: now) {
            pages.append(journal)
        }
        return pages
    }
}
