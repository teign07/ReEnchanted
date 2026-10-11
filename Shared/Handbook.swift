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
    /// Where this month's lesson sits in the room's year, and how many the year holds.
    var number: Int? = nil
    var lessonCount: Int? = nil
    /// How the lesson teaches ("A real experiment"), the leader's words at the board,
    /// a two-minute version for an empty seat, and the course reading.
    var mode: String? = nil
    var lecture: String? = nil
    var twoMinutes: String? = nil
    var reading: String? = nil

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
    /// The scenes the reader read with them in, this month, by title.
    var scenesThisMonth: [String] = []
    /// What they actually said this month, dated: their notes, letters, lines.
    var saidThisMonth: [String] = []
    /// The month's name, for the page's own heading.
    var monthName: String? = nil
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
    /// What the month gives back: pixels, a found poem, a passport, cut-outs, questions, eight words, a
    /// time capsule. Made of the reader's own days; monthly only. Optional so older books decode.
    var keepsakes: HandbookKeepsakes? = nil
    /// The rooms that met this month without the reader: this month's lesson, small enough to try
    /// in two minutes, a few to a leaf. Optional so older books decode.
    var openSeats: [HandbookLesson]? = nil
    /// Rooms the reader sat beyond the three written up in full: named on the contents leaf with a
    /// line of what they brought back, so a busy month doesn't turn into a textbook.
    var alsoSat: [HandbookLesson]? = nil

    var isEmpty: Bool {
        lessons.isEmpty && (openSeats ?? []).isEmpty && (alsoSat ?? []).isEmpty && lore.isEmpty && compass.isEmpty && dossiers.isEmpty && bestiary.isEmpty
    }

    /// The fewest rooms a printed handbook keeps while anything else is being given up.
    static let minimumLessons = 3

    var classes: [HandbookLesson] { lessons.filter { !$0.isClub } }
    var societies: [HandbookLesson] { lessons.filter(\.isClub) }
    var attendedCount: Int { lessons.filter(\.attended).count }
    /// Every room the book mentions, written up or kept open.
    var rooms: [HandbookLesson] { lessons + (alsoSat ?? []) + (openSeats ?? []) }

    /// One step thinner, or nil when only the reader's own entries remain.
    /// Order: the Book's own lore, then dossiers, then lessons the reader never sat.
    func trimmedOnce() -> Handbook? {
        var copy = self
        if copy.compass.count > 0 { copy.compass.removeLast(); return copy }
        // A spell the reader never cast is a line of the catalogue, not of their month.
        if copy.spells.contains(where: { $0.timesCast == 0 }) {
            copy.spells.removeAll { $0.timesCast == 0 }
            return copy
        }
        // The generic part goes first: a room the reader never sat costs two leaves and is the same for
        // everyone, while a puzzle is a fraction of a leaf made of this reader's own days.
        if copy.lessons.count > Handbook.minimumLessons,
           let index = copy.lessons.lastIndex(where: { !$0.attended }) {
            copy.lessons.remove(at: index)
            return copy
        }
        for kind in [HandbookWorkbook.PuzzleKind.oddOne, .anagrams, .vowels, .cloze, .sudoku] where copy.workbook?.has(kind) == true {
            copy.workbook?.remove(kind)
            return copy
        }
        if copy.workbook?.matching != nil { copy.workbook?.matching = nil; return copy }
        if copy.workbook?.ordering != nil { copy.workbook?.ordering = nil; return copy }
        if copy.workbook?.cipher != nil { copy.workbook?.cipher = nil; return copy }
        // Ruin pages are the book's invitation to be handled: thin them, but keep one.
        if (copy.ruinCount ?? 0) > 1 { copy.ruinCount = (copy.ruinCount ?? 0) - 1; return copy }
        if copy.lore.count > 2 { copy.lore.removeLast(min(2, copy.lore.count - 2)); return copy }
        if copy.dossiers.count > 1 { copy.dossiers.removeLast(); return copy }
        if !(copy.openSeats ?? []).isEmpty { copy.openSeats = nil; return copy }
        if let index = copy.lessons.lastIndex(where: { !$0.attended }) {
            copy.lessons.remove(at: index)
            return copy
        }
        if copy.lore.count > 0 { copy.lore.removeAll(); return copy }
        if copy.bestiary.count > 0 { copy.bestiary.removeAll(); return copy }
        // The extras go with the generic part; the month at a glance outlasts even the days (see
        // `MonthlyEdition.trimmedForPrint`).
        if var keepsakes = copy.keepsakes, keepsakes.removeExtra() {
            copy.keepsakes = keepsakes.isEmpty ? nil : keepsakes
            return copy
        }
        // Last of the evergreen layer: the remaining Cast files, the spellbook,
        // and any room the reader sat but wrote nothing in.
        if !copy.dossiers.isEmpty { copy.dossiers.removeAll(); return copy }
        if !copy.spells.isEmpty { copy.spells.removeAll(); return copy }
        if let index = copy.lessons.lastIndex(where: { ($0.readerEntry ?? "").isEmpty }) {
            let room = copy.lessons.remove(at: index)
            // A room the reader sat stays on the contents leaf as a line, even when its pages go.
            if room.attended { copy.alsoSat = (copy.alsoSat ?? []) + [room] }
            return copy
        }
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
        term: Date? = nil,
        loreLimit: Int = 10,
        compassLimit: Int = 5,
        dossierLimit: Int = 5,
        ruinLeaves: Int? = nil,
        calendar: Calendar = .current
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
        // The month the rooms taught in: what the book is of, or failing that the first kept day.
        let month = term ?? dayBook?.days.first?.date ?? pages.map(\.createdAt).min()
        let coursework = chosenLessons(lessons(from: pages, term: month, calendar: calendar), seed: seed)
        return Handbook(
            lessons: coursework.full,
            lore: lore,
            compass: compass,
            dossiers: dossiers(from: castPresence, limit: dossierLimit, dayBook: dayBook, calendar: calendar),
            bestiary: bestiary(from: pages),
            spells: spells(from: pages),
            workbook: HandbookWorkbookBuilder.make(
                pages: pages, dayBook: dayBook, terms: terms, seed: seed, dayCount: dayCount
            ),
            ruinCount: {
                let count = ruinLeaves ?? PrintFeatureFlags.ruinLeaves(dayCount: dayCount)
                return count > 0 ? count : nil
            }(),
            keepsakes: dayCount > 10
                ? HandbookKeepsakesBuilder.make(days: dayBook?.days ?? [], pages: pages, seed: seed, calendar: calendar, chart: dayBook?.chart)
                : nil,
            openSeats: coursework.open.isEmpty ? nil : coursework.open,
            alsoSat: coursework.also.isEmpty ? nil : coursework.also
        )
    }

    // MARK: Coursework

    /// The most rooms an open-seats leaf carries.
    static let openSeatLimit = 2
    /// The most rooms the reader sat that are written up in full.
    static let fullLessonLimit = 3

    /// The rooms this month's book prints. Up to three rooms the reader sat are written up in full,
    /// with their own hand on the worksheet: the ones they wrote in first, then the ones they went
    /// back to most. Any other room they sat gets a line on the contents leaf, with what they
    /// brought back. A reader who sat none still gets one room, the Book's own notes from an empty
    /// seat. A few rooms they never sat come as open seats: the month's lesson and a two-minute
    /// way in, the same for every reader.
    static func chosenLessons(_ all: [HandbookLesson], seed: String)
        -> (full: [HandbookLesson], also: [HandbookLesson], open: [HandbookLesson]) {
        let order = { (lesson: HandbookLesson) in stableHash(seed + "|lesson|" + lesson.id) }
        let fullest = { (lesson: HandbookLesson) in
            ((lesson.readerEntry ?? "").isEmpty ? 1 : 0, -lesson.attendedCount, order(lesson))
        }
        let sat = all.filter(\.attended).sorted { fullest($0) < fullest($1) }
        var full = Array(sat.prefix(fullLessonLimit))
        let also = Array(sat.dropFirst(fullLessonLimit))
        if full.isEmpty {
            // A room with a whole course teaches more than one with a standing lesson.
            let pick = all.filter { ($0.lessonCount ?? 1) > 1 }.min { order($0) < order($1) }
                ?? all.min { order($0) < order($1) }
            full = pick.map { [$0] } ?? []
        }
        let taken = Set((full + also).map(\.id))
        // A course before a standing lesson, classes before societies, then the month's rotation.
        let rank = { (lesson: HandbookLesson) in
            ((lesson.lessonCount ?? 1) > 1 ? 0 : 1, lesson.isClub ? 1 : 0, order(lesson))
        }
        let open = Set(all.filter { !taken.contains($0.id) }.sorted { rank($0) < rank($1) }.prefix(openSeatLimit).map(\.id))
        let fullIDs = Set(full.map(\.id)), alsoIDs = Set(also.map(\.id))
        return (all.filter { fullIDs.contains($0.id) }, all.filter { alsoIDs.contains($0.id) }, all.filter { open.contains($0.id) })
    }

    /// Every room, as this month taught it. A room the reader sat prints the lesson they sat (the
    /// page remembers it); the rest print the month's lesson from `AcademyCurriculum`.
    static func lessons(from pages: [BookPage], term: Date? = nil, calendar: Calendar = .current) -> [HandbookLesson] {
        var attendance: [String: Int] = [:]
        var entries: [String: (date: Date, text: String)] = [:]
        var sat: [String: (date: Date, lessonID: String)] = [:]
        for page in pages where [.academyClass, .elective, .supportGuild, .bookJump].contains(page.type) {
            guard let sessionID = page.metadata?["sessionID"], !sessionID.isEmpty else { continue }
            attendance[sessionID, default: 0] += 1
            if let lessonID = page.metadata?["lessonModuleID"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !lessonID.isEmpty, sat[sessionID].map({ page.createdAt > $0.date }) ?? true {
                sat[sessionID] = (page.createdAt, lessonID)
            }
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
            let module = sat[session.id].flatMap { AcademyCurriculum.lesson(id: $0.lessonID) }
                ?? term.flatMap { AcademyCurriculum.lesson(for: session.id, on: $0, calendar: calendar) }
                ?? AcademyScheduleRegistry.lessonModules[session.id]
            guard let module else { return nil }
            let activity = AcademyActivityRegistry.activity(for: session.id, lessonID: module.id)
            let count = AcademyCurriculum.lessonCount(for: session.id)
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
                attendedCount: attendance[session.id] ?? 0,
                number: count > 1 ? module.number : nil,
                lessonCount: count,
                mode: module.mode,
                lecture: module.lecture,
                twoMinutes: module.twoMinutes,
                reading: module.reading
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

    /// A Cast member's file for this month: the scenes the reader shared with
    /// them, what they said, and one facet of the Book's standing file on them,
    /// turned each month, so the file reads as this month's and not a reprint.
    static func dossiers(from presence: [BoundCastPresence], limit: Int, dayBook: BoundDayBook? = nil,
                         calendar: Calendar = .current) -> [HandbookDossier] {
        let firstDay = dayBook?.days.first?.date
        let month = firstDay.map { calendar.component(.month, from: $0) } ?? 0
        let monthFormatter = DateFormatter(); monthFormatter.calendar = calendar; monthFormatter.dateFormat = "MMMM"
        let dayFormatter = DateFormatter(); dayFormatter.calendar = calendar; dayFormatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return presence
            .filter { CastDossier.bio(forSlug: $0.slug) != nil }
            .prefix(limit)
            .compactMap { person in
                guard let bio = CastDossier.bio(forSlug: person.slug) else { return nil }
                let all = bio
                    .components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let days = dayBook?.days ?? []
                // Each scene once, by the title it opened with, never its later parts.
                var titles: [String] = []
                var seenScenes = Set<String>()
                for scene in days.flatMap(\.scenes) where !scene.isReport && seenScenes.insert(scene.contentID).inserted {
                    let parts = days.flatMap(\.scenes).filter { $0.contentID == scene.contentID }
                    if parts.contains(where: { $0.castIDs.contains(person.slug) }) { titles.append(scene.title) }
                }
                if titles.count > 5 { titles = Array(titles.prefix(5)) + ["\(titles.count - 5) more"] }
                var said: [String] = []
                for day in days {
                    let when = dayFormatter.string(from: day.date)
                    for line in day.castLines where line.speakerID == person.slug {
                        said.append("\(when): \u{201C}\(line.line)\u{201D}")
                    }
                    for keep in day.keeps where keep.speakerName == person.name && [.castNote, .letter].contains(keep.kind) {
                        let first = keep.body.components(separatedBy: CharacterSet(charactersIn: ".!?")).first?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? keep.body
                        guard !first.isEmpty else { continue }
                        said.append("\(when): \u{201C}\(first).\u{201D}")
                    }
                }
                // With a month to tell, one facet of the file; without one, the whole file.
                let hasMonth = !titles.isEmpty || !said.isEmpty
                let facet = all.isEmpty ? [] : [all[(month + abs(person.slug.count)) % all.count]]
                return HandbookDossier(
                    slug: person.slug,
                    name: person.name,
                    plateAssetName: person.plateAssetName,
                    paragraphs: hasMonth ? facet : all,
                    // Never more days than the span holds.
                    daysPresent: min(person.daysPresent, firstDay.flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? person.daysPresent),
                    sceneCount: person.sceneCount,
                    scenesThisMonth: titles,
                    saidThisMonth: Array(said.prefix(3)),
                    monthName: firstDay.map { monthFormatter.string(from: $0) }
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
        // A week is a keepsake already; the month's keepsakes belong to the month.
        copy.keepsakes = nil
        if var workbook = copy.workbook {
            if level < 2 {
                for kind in HandbookWorkbook.PuzzleKind.allCases { workbook.remove(kind) }
                workbook.exam = nil; workbook.reportCard = nil
            }
            // A week carries three of the eight kinds, a different three each issue; a thin week
            // may only draw on the light ones.
            workbook.rotate(seed: "week-\(issueNumber)", keep: 3, allowed: { level >= 5 || !$0.needsFullWeek })
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
        case .monthly: return [128, 160]
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
            case 97...128: return "Full"
            default: return "Grand"
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
