import Foundation

// MARK: - The Handbook
//
// The reader's printed volume is a Student's Handbook & Workbook. The day book
// carries what *happened*; this carries what the Academy *teaches* — the
// coursework, the lore that matched this reader's own words, the Cast's
// dossiers, the creatures they filed — everything the app already owns that
// only had a screen to live on. All of it is deterministic: same archive, same
// Handbook, so a reprint never changes a book the reader already holds.

/// One class or club as the Handbook sets it: the lesson, the worksheet, and —
/// when the reader went — their own hand on the worksheet.
struct HandbookLesson: Codable, Equatable, Identifiable {
    var id: String
    var kind: String
    var name: String
    var leader: String
    var leaderSlug: String?
    var room: String
    var title: String
    var realSubject: String
    var concept: String
    var beats: [String]
    var demonstration: String
    var interaction: String
    var realWorldPractice: String
    var practiceTitle: String
    var invitation: String
    var fields: [HandbookField]
    /// The reader's own entry, when they brought one back from the room.
    var readerEntry: String?
    var attendedCount: Int

    var attended: Bool { attendedCount > 0 }
    var isClub: Bool { kind == AcademySession.Kind.club.rawValue }
}

struct HandbookField: Codable, Equatable {
    var label: String
    var placeholder: String
}

struct HandbookLoreEntry: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var practice: String?
    /// Why this one is in *this* reader's book, in plain words. Nil for the
    /// Book's own picks, which say so rather than pretend to a reason.
    var why: String?
}

struct HandbookDossier: Codable, Equatable, Identifiable {
    var id: String { slug }
    var slug: String
    var name: String
    var plateAssetName: String?
    var paragraphs: [String]
    var daysPresent: Int
    var sceneCount: Int
}

struct HandbookCreature: Codable, Equatable, Identifiable {
    var id: String { creature }
    var creature: String
    var sense: String
    var lore: String
    var tradition: String
    var timesFiled: Int
}

struct HandbookSpell: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var timesCast: Int
}

struct Handbook: Codable, Equatable {
    var lessons: [HandbookLesson]
    var lore: [HandbookLoreEntry]
    var compass: [HandbookLoreEntry]
    var dossiers: [HandbookDossier]
    var bestiary: [HandbookCreature]
    var spells: [HandbookSpell]
    /// Puzzles, the Examination and the Report Card. Optional so Handbooks
    /// written before the Workbook existed decode.
    var workbook: HandbookWorkbook? = nil
    /// How many leaves of ruin pages the book carries (two faces each). The
    /// leaves themselves are chosen at print time from the binding's id, so a
    /// reprint of the same month asks the reader for something new.
    var ruinCount: Int? = nil

    var isEmpty: Bool {
        lessons.isEmpty && lore.isEmpty && compass.isEmpty && dossiers.isEmpty && bestiary.isEmpty
    }

    var classes: [HandbookLesson] { lessons.filter { !$0.isClub } }
    var societies: [HandbookLesson] { lessons.filter(\.isClub) }
    var attendedCount: Int { lessons.filter(\.attended).count }

    /// One step thinner, or nil when only the reader's own entries remain.
    /// Order: the Book's own lore, then dossiers, then lessons the reader never sat.
    func trimmedOnce() -> Handbook? {
        var copy = self
        if copy.compass.count > 0 { copy.compass.removeLast(); return copy }
        if copy.workbook?.matching != nil { copy.workbook?.matching = nil; return copy }
        if copy.workbook?.ordering != nil { copy.workbook?.ordering = nil; return copy }
        if copy.workbook?.cipher != nil { copy.workbook?.cipher = nil; return copy }
        // Ruin pages are the book's invitation to be handled: thin them, but keep one.
        if (copy.ruinCount ?? 0) > 1 { copy.ruinCount = (copy.ruinCount ?? 0) - 1; return copy }
        if copy.lore.count > 2 { copy.lore.removeLast(min(2, copy.lore.count - 2)); return copy }
        if copy.dossiers.count > 1 { copy.dossiers.removeLast(); return copy }
        if let index = copy.lessons.lastIndex(where: { !$0.attended }) {
            copy.lessons.remove(at: index)
            return copy
        }
        if copy.lore.count > 0 { copy.lore.removeAll(); return copy }
        if copy.bestiary.count > 0 { copy.bestiary.removeAll(); return copy }
        return nil
    }

    /// Drops what a thinner book cannot afford, cheapest-to-lose first. The
    /// reader's own entries are never what goes.
    func trimmed(toLessons lessonLimit: Int, lore loreLimit: Int, dossiers dossierLimit: Int) -> Handbook {
        var copy = self
        if copy.lessons.count > lessonLimit {
            // Keep every lesson the reader sat, then the rest in registry order.
            let sat = copy.lessons.filter(\.attended)
            let rest = copy.lessons.filter { !$0.attended }
            copy.lessons = Array((sat + rest).prefix(max(lessonLimit, sat.count)))
                .sorted { $0.name < $1.name }
        }
        copy.lore = Array(copy.lore.prefix(loreLimit))
        copy.compass = Array(copy.compass.prefix(max(0, loreLimit / 2)))
        copy.dossiers = Array(copy.dossiers.prefix(dossierLimit))
        return copy
    }
}

// MARK: - Builder

enum HandbookBuilder {
    /// - Parameters:
    ///   - pages: the volume's kept pages (class entries and creature
    ///     sightings are read from these).
    ///   - castPresence: the day book's chart cast, most present first.
    ///   - terms: the reader's own motif words; lore is chosen by overlap.
    ///   - seed: the volume's stable key (month key), so ties never wander.
    static func make(
        pages: [BookPage],
        castPresence: [BoundCastPresence],
        terms: [String],
        seed: String,
        dayBook: BoundDayBook? = nil,
        dayCount: Int = 30,
        loreLimit: Int = 10,
        compassLimit: Int = 5,
        dossierLimit: Int = 5,
        ruinLeaves: Int? = nil
    ) -> Handbook {
        let searchTerms = normalizedTerms(terms)
        let lore = chooseLore(
            from: BookReferenceCatalog.enchantifyLore,
            terms: searchTerms, seed: seed + "|lore", limit: loreLimit, excerptLimit: 760
        )
        let compass = chooseLore(
            from: BookReferenceCatalog.wonderCompass,
            terms: searchTerms, seed: seed + "|compass", limit: compassLimit, excerptLimit: 620
        )
        return Handbook(
            lessons: lessons(from: pages),
            lore: lore,
            compass: compass,
            dossiers: dossiers(from: castPresence, limit: dossierLimit),
            bestiary: bestiary(from: pages),
            spells: spells(from: pages),
            workbook: HandbookWorkbookBuilder.make(
                pages: pages, dayBook: dayBook, terms: terms, seed: seed, dayCount: dayCount
            ),
            ruinCount: {
                let count = ruinLeaves ?? PrintFeatureFlags.ruinLeaves(dayCount: dayCount)
                return count > 0 ? count : nil
            }()
        )
    }

    // MARK: Coursework

    static func lessons(from pages: [BookPage]) -> [HandbookLesson] {
        var attendance: [String: Int] = [:]
        var entries: [String: (date: Date, text: String)] = [:]
        for page in pages where [.academyClass, .elective, .supportGuild, .bookJump].contains(page.type) {
            guard let sessionID = page.metadata?["sessionID"], !sessionID.isEmpty else { continue }
            attendance[sessionID, default: 0] += 1
            if let outcome = page.metadata?["academyActivityOutcome"]?
                .trimmingCharacters(in: .whitespacesAndNewlines), !outcome.isEmpty {
                if entries[sessionID].map({ page.createdAt > $0.date }) ?? true {
                    entries[sessionID] = (page.createdAt, outcome)
                }
            }
        }

        let sessions = (Array(AcademyScheduleRegistry.classes.values) + Array(AcademyScheduleRegistry.clubs.values))
            .sorted { ($0.kind.rawValue, $0.name) < ($1.kind.rawValue, $1.name) }
        return sessions.compactMap { session in
            guard let module = AcademyScheduleRegistry.lessonModules[session.id] else { return nil }
            let activity = AcademyActivityRegistry.activity(for: session.id)
            return HandbookLesson(
                id: session.id,
                kind: session.kind.rawValue,
                name: session.name,
                leader: session.leader,
                leaderSlug: session.leaderEntityID,
                room: session.room,
                title: module.title,
                realSubject: module.realSubject,
                concept: module.concept,
                beats: module.lectureBeats,
                demonstration: module.demonstration,
                interaction: module.interactionPrompt,
                realWorldPractice: module.realWorldPractice,
                practiceTitle: activity?.title ?? "The practice",
                invitation: activity?.invitation ?? module.realWorldPractice,
                fields: (activity?.fields ?? []).map { HandbookField(label: $0.label, placeholder: $0.placeholder) },
                readerEntry: entries[session.id]?.text,
                attendedCount: attendance[session.id] ?? 0
            )
        }
    }

    // MARK: Lore

    private static let stopWords: Set<String> = [
        "that", "this", "with", "from", "have", "were", "they", "their", "there", "about",
        "would", "could", "which", "while", "into", "just", "what", "when", "then", "than",
        "your", "been", "some", "will", "very", "also", "more", "most", "over", "each"
    ]

    static func normalizedTerms(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for phrase in raw {
            for word in phrase.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let term = String(word)
                guard term.count >= 4, !stopWords.contains(term), seen.insert(term).inserted else { continue }
                out.append(term)
            }
        }
        return out
    }

    static func chooseLore(
        from snippets: [ReferenceSnippet],
        terms: [String],
        seed: String,
        limit: Int,
        excerptLimit: Int
    ) -> [HandbookLoreEntry] {
        guard limit > 0 else { return [] }
        let scored = snippets.map { snippet -> (snippet: ReferenceSnippet, score: Int, hit: String?, tie: UInt64) in
            let haystack = (snippet.title + " " + snippet.tags.joined(separator: " ") + " " + snippet.body).lowercased()
            let hits = terms.filter { haystack.range(of: $0, options: .literal) != nil }
            return (snippet, hits.count, hits.first, stableHash(seed + snippet.id))
        }
        .filter { !$0.snippet.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isReadable($0.snippet) }
        .sorted { ($1.score, $0.tie) < ($0.score, $1.tie) }

        // Matches first, then the Book's own picks — and say which is which.
        var chosen: [HandbookLoreEntry] = []
        for item in scored.prefix(limit) {
            let why = item.score > 0 ? item.hit.map { "Set here because “\($0)” runs through your month." } : nil
            chosen.append(HandbookLoreEntry(
                id: item.snippet.id,
                title: item.snippet.title,
                body: excerpt(item.snippet, limit: excerptLimit),
                practice: item.snippet.practice?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue,
                why: why
            ))
        }
        return chosen
    }

    /// Bibliography and back matter are in the library for the Book to search,
    /// not for a reader to be handed as a page.
    static func isReadable(_ snippet: ReferenceSnippet) -> Bool {
        let title = snippet.title.lowercased()
        let blocked = ["notes & references", "references", "acknowledg", "bibliography", "index", "about the author", "copyright"]
        if blocked.contains(where: { title.contains($0) }) { return false }
        return snippet.body.filter(\.isLetter).count >= 120
    }

    /// The first whole sentences that fit, never a clipped one.
    static func excerpt(_ snippet: ReferenceSnippet, limit: Int) -> String {
        var source = snippet.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.lowercased().hasPrefix(snippet.title.lowercased()) {
            source = String(source.dropFirst(snippet.title.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard source.count > limit else { return source }
        var out = ""
        var sentence = ""
        for character in source {
            sentence.append(character)
            if ".!?".contains(character) {
                if (out + sentence).count > limit { break }
                out += sentence
                sentence = ""
            }
        }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(source.prefix(limit)) : trimmed
    }

    // MARK: Dossiers, creatures, spells

    static func dossiers(from presence: [BoundCastPresence], limit: Int) -> [HandbookDossier] {
        presence
            .filter { CastDossier.bio(forSlug: $0.slug) != nil }
            .prefix(limit)
            .compactMap { person in
                guard let bio = CastDossier.bio(forSlug: person.slug) else { return nil }
                let paragraphs = bio
                    .components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return HandbookDossier(
                    slug: person.slug,
                    name: person.name,
                    plateAssetName: person.plateAssetName,
                    paragraphs: paragraphs,
                    daysPresent: person.daysPresent,
                    sceneCount: person.sceneCount
                )
            }
    }

    static func bestiary(from pages: [BookPage]) -> [HandbookCreature] {
        var counts: [String: Int] = [:]
        for page in pages {
            for sighting in page.creatureSightings ?? [] where sighting.certainty >= Bestiary.filingCertainty {
                counts[VisualFact.normalized(sighting.creature), default: 0] += 1
            }
        }
        return counts.keys.sorted().compactMap { name in
            guard let lore = CreatureLore.lore(for: name) else { return nil }
            return HandbookCreature(
                creature: name,
                sense: lore.sense,
                lore: lore.lore,
                tradition: lore.tradition,
                timesFiled: counts[name] ?? 1
            )
        }
    }

    static func spells(from pages: [BookPage]) -> [HandbookSpell] {
        let casts = pages.filter { $0.type == .enchantment || $0.type == .spell }
        return StoryEnchantmentCatalog.spells.map { spell in
            let count = casts.filter {
                $0.metadata?["spellID"] == spell.id || $0.tags.contains(spell.id)
            }.count
            return HandbookSpell(id: spell.id, title: spell.title, detail: spell.detail, timesCast: count)
        }
    }

    // MARK: Stable hash

    /// FNV-1a: the same on every launch and every device, unlike `hashValue`.
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}



// MARK: - Titles

/// An edition is named by the reader if they named it; otherwise it is titled
/// from the month's story, made personal by the name the Book gave them, and it
/// prints the reason, so the title is a claim the reader can check.
enum EditionTitler {
    struct Title: Equatable {
        var line: String
        var reason: String?
    }

    static let limit = 44

    static func monthly(
        readerNamed: String?,
        packTitle: String?,
        role: BoundReaderRole?,
        theme: BookTheme?,
        monthTitle: String
    ) -> Title {
        if let named = readerNamed?.trimmingCharacters(in: .whitespacesAndNewlines), !named.isEmpty,
           named.count <= MonthlyEdition.coverTitleCharacterLimitValue {
            return Title(line: named, reason: "Named by you.")
        }
        let pack = packTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue
        if let pack, let role, let noun = roleNoun(role) {
            let line = "\(noun)\u{2019}s \(pack)"
            if line.count <= limit {
                return Title(line: line, reason: "Titled for the month\u{2019}s story, \(pack), and for the name the Book gave you, \(role.fullName).")
            }
        }
        if let pack {
            let line = "\(pack): \(monthTitle)"
            if line.count <= limit + 8 {
                return Title(line: line, reason: "Titled for the month\u{2019}s story, \(pack).")
            }
            return Title(line: pack, reason: "Titled for the month\u{2019}s story.")
        }
        if let name = theme?.name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue, name.count <= limit {
            return Title(line: name, reason: "Titled for the theme the Book found in your month.")
        }
        return Title(line: monthTitle, reason: nil)
    }

    /// "The Magpie of the Blue Hour" becomes "The Magpie".
    static func roleNoun(_ role: BoundReaderRole) -> String? {
        let head = role.fullName.components(separatedBy: " of ").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return head.isEmpty || head.count > 24 ? nil : head
    }
}

private extension String {
    var nonEmptyValue: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}


// MARK: - The weekly Handbook

extension Handbook {
    static let weeklyLevelRange = 0...9

    /// Which level a requested thickness starts at. A week is a week of term:
    /// the days are the issue, and the Handbook rises with the page count.
    static func weeklyStartLevel(forPages pages: Int) -> Int {
        switch pages {
        case ..<28: return 1
        case 28..<36: return 4
        case 36..<44: return 6
        default: return 9
        }
    }

    /// The week's slice of the term. The same issue always gets the same
    /// lessons: the ones the reader sat first, then a rotation by issue number.
    func weeklySlice(issueNumber: Int, level: Int) -> Handbook {
        let level = min(max(level, Handbook.weeklyLevelRange.lowerBound), Handbook.weeklyLevelRange.upperBound)
        var copy = self
        let sat = lessons.filter(\.attended)
        let unsat = lessons.filter { !$0.attended }
        let rotation = unsat.isEmpty ? [] : (0..<unsat.count).map { unsat[($0 + issueNumber) % unsat.count] }
        let wanted = min(lessons.count, 1 + level / 2 + (level >= 8 ? 1 : 0))
        copy.lessons = Array((sat + rotation).prefix(max(wanted, min(sat.count, wanted))))
        copy.lore = Array(lore.prefix(1 + level / 2))
        copy.compass = level >= 6 ? Array(compass.prefix(1 + (level - 6) / 2)) : []
        copy.dossiers = Array(dossiers.prefix(min(3, level / 3)))
        if level < 3 { copy.bestiary = [] }
        // A week's one ruin leaf comes in once the magazine has room for it.
        copy.ruinCount = level >= 5 ? min(ruinCount ?? 0, 1) : 0
        if level < 8 { copy.spells = [] }
        if var workbook = copy.workbook {
            if level < 2 {
                workbook.cipher = nil; workbook.matching = nil; workbook.ordering = nil
                workbook.exam = nil; workbook.reportCard = nil
            }
            if level < 5 { workbook.matching = nil; workbook.ordering = nil }
            copy.workbook = workbook
        }
        return copy
    }
}


// MARK: - Thickness

/// How thick a book the reader may ask for. A tier is a promise about pages,
/// so only tiers the reader's own month can honestly fill are offered: a
/// thicker book than the content would be padding, and there is none.
enum PrintThickness {
    static func tiers(for kind: PublicationEditionKind) -> [Int] {
        switch kind {
        case .weekly: return WeeklyPublicationMatter.pageTiers
        case .monthly: return [64, 96, 128]
        case .seasonal: return [128, 176]
        case .annual, .special: return [192, 256]
        }
    }

    static func name(forTier tier: Int, kind: PublicationEditionKind) -> String {
        switch kind {
        case .monthly:
            switch tier {
            case ...64: return "Slim"
            case 65...96: return "Standard"
            default: return "Full"
            }
        case .weekly:
            switch tier {
            case ...24: return "Pocket"
            case 25...32: return "Magazine"
            case 33...40: return "Long"
            default: return "Double"
            }
        default: return "\(tier) pages"
        }
    }

    /// The tiers this reader's content can fill, given how many pages it
    /// naturally comes to. The thinnest tier is always open.
    static func available(for kind: PublicationEditionKind, naturalPages: Int, slack: Int = 8) -> [Int] {
        let all = tiers(for: kind)
        let open = all.filter { $0 <= naturalPages + slack }
        return open.isEmpty ? Array(all.prefix(1)) : open
    }
}


// MARK: - Print features

/// Things a printed book may carry that are switched on deliberately, not by
/// default. Ruin pages stay off until a physical proof says the paper takes
/// the pens, and readers have said they want them.
enum PrintFeatureFlags {
    static let ruinPagesKey = "printRuinPages"

    static var ruinPagesEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: ruinPagesKey) }
        set { UserDefaults.standard.set(newValue, forKey: ruinPagesKey) }
    }

    /// How many ruin leaves a book of `dayCount` days carries: none unless
    /// the feature is on, then one in a weekly and four in a monthly.
    static func ruinLeaves(dayCount: Int) -> Int {
        guard ruinPagesEnabled else { return 0 }
        return dayCount <= 7 ? 1 : 4
    }
}
