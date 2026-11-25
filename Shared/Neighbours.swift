import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - The Neighbours
//
// Every thing, creature and spot in the reader's real life that has become
// somebody: the tree they told its name, the kettle that keeps turning up, the
// heron by the weir. The fair folk were called the Good Neighbours; these are
// the reader's own.
//
// The register is read out of the archive, the same way the Bestiary and the
// deals are. Confirming a Neighbour writes one small kept Page (its founding
// record); renaming, resting and losing one write further records. There is no
// ledger to drift out of step with the Pages, and a Page the reader throws
// away takes its consequences with it.
//
// The Book proposes. The reader confirms. Nothing here invents what the reader
// did or felt: a Neighbour's history is the reader's own Pages, matched by
// name, and the only sentence of theirs it ever quotes is quoted whole.

enum NeighbourKind: String, Codable, CaseIterable, Equatable {
    /// Something that lives indoors or travels with the reader: a kettle, a
    /// chair, a lost glove.
    case thing
    /// Something alive that moves about on its own: the heron, next door's cat.
    case creature
    /// Something rooted to one spot: a tree, a room, a bench.
    case place
}

enum NeighbourStatus: String, Codable, Equatable {
    case living
    /// The reader asked the Book to stop asking after it. Its Pages are kept.
    case resting
    /// The reader said it's gone. An ending is a real ending.
    case gone
}

/// One Neighbour, as the archive tells it.
struct Neighbour: Identifiable, Equatable {
    /// `neighbour:<slug>`. Stable through renames.
    var id: String { "neighbour:\(slug)" }
    var slug: String
    /// What the reader calls it now, or an epithet ("the tree") until it has
    /// a name.
    var name: String
    var isEpithet: Bool
    /// Every name it has had before this one, oldest first.
    var formerNames: [String]
    var kind: NeighbourKind
    /// What it was proposed from: `page:<id>`, `word:<noun>` or
    /// `creature:<label>`. Never proposed twice.
    var key: String
    /// The reader's Page it came in on.
    var foundingPageID: String
    var foundedAt: Date
    /// The kept record that made it a Neighbour.
    var foundingRecordID: String
    /// The reader's own sentence from the founding Page, whole, or nil when
    /// there isn't a short one to quote.
    var foundingSentence: String?
    /// The working the founding Page came from (`spell:name-a-tree`,
    /// `mission:chair-held`), when there was one.
    var working: String?
    /// Where it lives, when the founding Page knew where it was written.
    var latitude: Double?
    var longitude: Double?
    /// Every Page it appears on, oldest first. Always includes the founding
    /// Page.
    var pageIDs: [String]
    /// When each of those Pages was written, in the same order.
    var pageDates: [Date]
    var lastSeen: Date
    var status: NeighbourStatus
    var statusChangedAt: Date?

    var isLiving: Bool { status == .living }
}

/// The Book's guess that something has become somebody. Shown to the reader,
/// who confirms it with one tap or turns it away for good.
struct NeighbourProposal: Equatable {
    var key: String
    var name: String
    var isEpithet: Bool
    var kind: NeighbourKind
    var foundingPageID: String
    var foundedAt: Date
    var working: String?
    /// The reader's own sentence, whole, when there's a short one.
    var quote: String?
    /// What the reader did, said plainly ("You told a tree its name.").
    var deed: String
    /// What the Book matches later Pages on: `name:<Name>`, `word:<noun>`,
    /// `creature:<label>` or `none`.
    var match: String
    var evidencePageIDs: [String]

    /// The rest tag and observation key share this, so a proposal the reader
    /// turned away is never asked again.
    var restKey: String { "neighbour-propose-\(Neighbours.slug(for: key))" }
    var observationKey: String { "neighbour-propose:\(key)" }
}

enum Neighbours {
    static let sourceID = "the-neighbours"
    static let recordTag = "neighbour-record"

    /// The longest reader sentence the Book will quote back. Longer ones are
    /// left out sooner than clipped.
    static let quoteLimit = 220

    enum Event: String {
        case founded
        case renamed
        case resting
        case awake
        case gone
    }

    // MARK: Slugs and text

    static func slug(for text: String) -> String {
        PeopleOfTheBook.slug(for: text)
    }

    /// "the tree" at the start of a sentence.
    static func capitalized(_ name: String) -> String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }

    static func allPages(in days: [BookDay]) -> [BookPage] {
        var seen: Set<String> = []
        return days.flatMap(\.pages).filter { seen.insert($0.id).inserted }
    }

    static func isRecord(_ page: BookPage) -> Bool {
        page.tags.contains(recordTag)
    }

    /// The reader's own words on a Page, or nil. Records are the Book's.
    static func readerText(_ page: BookPage) -> String? {
        guard !isRecord(page) else { return nil }
        return page.readerAuthoredTextForAnalysis?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    static func quotable(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              text.count <= quoteLimit else { return nil }
        return text
    }

    static func containsWholeWord(_ word: String, in text: String, caseSensitive: Bool) -> Bool {
        guard !word.isEmpty else { return false }
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var start = text.startIndex
        while let range = text.range(of: word, options: options, range: start..<text.endIndex) {
            let beforeOK = range.lowerBound == text.startIndex
                || !text[text.index(before: range.lowerBound)].isLetter
            let afterOK = range.upperBound == text.endIndex
                || !text[range.upperBound].isLetter
            if beforeOK && afterOK { return true }
            start = range.upperBound
        }
        return false
    }

    /// Names the fiction owns, the reader's own name, and the real people the
    /// reader keeps. None of them is ever proposed as a Neighbour.
    static func excludedNames(inputs: BookSourceInputs) -> Set<String> {
        var names = Set(NarrativePackRegistry.entities.map(\.name))
        names.formUnion(inputs.customCastMembers.map(\.name))
        for fact in inputs.selfFacts where fact.questionID == "name" || fact.id == "onboarding:name" {
            names.insert(fact.answer)
        }
        names.formUnion(inputs.people.threads.map(\.name))
        return names
    }

    /// Slugs of real-person names the reader has asked the Book to leave be.
    static func excludedSlugs(inputs: BookSourceInputs) -> Set<String> {
        Set(inputs.people.restingNames)
    }
}

// MARK: - The register

extension Neighbours {
    /// Every Neighbour the archive holds, in the order they were founded.
    ///
    /// Memoised on a cheap signature of the archive: the register is read by
    /// the desk, the deals and the mission seat, and the history match reads
    /// every reader sentence. Whole-archive callers in the app belong off the
    /// main thread.
    static func register(days: [BookDay]) -> [Neighbour] {
        let pages = allPages(in: days)
        guard pages.contains(where: isRecord) else { return [] }
        let key = signature(pages)
        memoLock.lock()
        if let hit = memo[key] {
            memoLock.unlock()
            return hit
        }
        memoLock.unlock()
        let built = buildRegister(pages: pages)
        memoLock.lock()
        if memo.count > 16 { memo.removeAll(keepingCapacity: true) }
        memo[key] = built
        memoLock.unlock()
        return built
    }

    static func neighbour(slug: String, days: [BookDay]) -> Neighbour? {
        register(days: days).first { $0.slug == slug }
    }

    /// The Neighbour a reader's Page founded, if one did.
    static func neighbour(foundedBy pageID: String, days: [BookDay]) -> Neighbour? {
        register(days: days).first { $0.foundingPageID == pageID }
    }

    private static let memoLock = NSLock()
    nonisolated(unsafe) private static var memo: [Int: [Neighbour]] = [:]

    private static func signature(_ pages: [BookPage]) -> Int {
        var hasher = Hasher()
        hasher.combine(pages.count)
        for page in pages {
            hasher.combine(page.id)
            hasher.combine(page.createdAt.timeIntervalSinceReferenceDate)
            hasher.combine(page.tags.count)
            hasher.combine(page.userInput.count)
            hasher.combine(page.playerReply.count)
            hasher.combine(page.creatureSightings?.count ?? -1)
            // Where it was written decides where a Neighbour sits on the map.
            hasher.combine(page.context?.latitude)
            hasher.combine(page.context?.longitude)
        }
        return hasher.finalize()
    }

    private struct Founding {
        var record: BookPage
        var slug: String
        var key: String
        var name: String
        var isEpithet: Bool
        var kind: NeighbourKind
        var sourceID: String
        var match: String
        var working: String?
    }

    private static func tagValue(_ prefix: String, in tags: [String]) -> String? {
        tags.first(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) }?.nonEmpty
    }

    private static func buildRegister(pages: [BookPage]) -> [Neighbour] {
        let byID = Dictionary(pages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let records = pages.filter(isRecord).sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
        let lives = pages.filter { !isRecord($0) }

        var foundings: [Founding] = []
        var seenSlugs: Set<String> = []
        var seenKeys: Set<String> = []
        for record in records where tagValue("neighbour-event:", in: record.tags) == Event.founded.rawValue {
            let metadata = record.metadata ?? [:]
            guard let slug = tagValue("neighbour:", in: record.tags),
                  let key = tagValue("neighbour-key:", in: record.tags),
                  let source = tagValue("neighbour-source:", in: record.tags),
                  let name = metadata["neighbourName"]?.nonEmpty,
                  seenSlugs.insert(slug).inserted,
                  seenKeys.insert(key).inserted else { continue }
            foundings.append(Founding(
                record: record, slug: slug, key: key, name: name,
                isEpithet: metadata["neighbourEpithet"] == "true",
                kind: tagValue("neighbour-kind:", in: record.tags).flatMap(NeighbourKind.init(rawValue:)) ?? .thing,
                sourceID: source,
                match: metadata["neighbourMatch"] ?? "none",
                working: metadata["neighbourWorking"]?.nonEmpty
            ))
        }

        var register: [Neighbour] = []
        for founding in foundings {
            // Later records for this Neighbour, in order.
            let events = records.filter {
                $0.id != founding.record.id
                    && tagValue("neighbour:", in: $0.tags) == founding.slug
                    && ($0.createdAt > founding.record.createdAt
                        || ($0.createdAt == founding.record.createdAt && $0.id > founding.record.id))
            }
            var name = founding.name
            var isEpithet = founding.isEpithet
            var former: [String] = []
            var status = NeighbourStatus.living
            var changedAt: Date?
            for event in events {
                switch tagValue("neighbour-event:", in: event.tags).flatMap(Event.init(rawValue:)) {
                case .renamed:
                    guard status != .gone,
                          let newName = event.metadata?["neighbourName"]?.nonEmpty, newName != name else { continue }
                    former.append(name)
                    name = newName
                    isEpithet = false
                case .resting:
                    guard status == .living else { continue }
                    status = .resting
                    changedAt = event.createdAt
                case .awake:
                    guard status == .resting else { continue }
                    status = .living
                    changedAt = event.createdAt
                case .gone:
                    guard status != .gone else { continue }
                    status = .gone
                    changedAt = event.createdAt
                case .founded, .none:
                    continue
                }
            }

            // What later Pages are matched on: every real name it has had,
            // and the word or creature it was first noticed as.
            var names = [name] + former
            if isEpithet { names.removeAll { $0 == name } }
            if founding.isEpithet { names.removeAll { $0 == founding.name } }
            var word: String?
            var creature: String?
            if founding.match.hasPrefix("word:") { word = String(founding.match.dropFirst(5)) }
            if founding.match.hasPrefix("creature:") { creature = String(founding.match.dropFirst(9)) }

            let ofTag = "neighbour-of:\(founding.slug)"
            func appears(on page: BookPage) -> Bool {
                // A visit, a name-day: Pages made for this Neighbour are its
                // Pages, whatever the reader wrote on them.
                if page.tags.contains(ofTag) || page.tags.contains("mission:" + ofTag)
                    || page.attributableLivedQuestReceipt?.sourceTags.contains(where: { $0 == ofTag || $0 == "mission:" + ofTag }) == true {
                    return true
                }
                if let creature, page.creatureSightings?.contains(where: { $0.creature == creature }) == true {
                    return true
                }
                guard let text = readerText(page) else { return false }
                if names.contains(where: { containsWholeWord($0, in: text, caseSensitive: true) }) { return true }
                if let word, containsWholeWord(word, in: text, caseSensitive: false)
                    || containsWholeWord(word + "s", in: text, caseSensitive: false) { return true }
                if let creature, containsWholeWord(creature, in: text, caseSensitive: false) { return true }
                return false
            }

            var history = lives.filter { $0.id == founding.sourceID || appears(on: $0) }
                .sorted { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }

            // The founding Page is the reader's own act. A Neighbour named on a
            // Page the reader threw away goes with it. One that was noticed
            // coming back keeps coming back on whatever Pages are left.
            var source = byID[founding.sourceID]
            if source == nil || isRecord(source!) {
                guard founding.key.hasPrefix("word:") || founding.key.hasPrefix("creature:"),
                      let earliest = history.first else { continue }
                source = earliest
            }
            guard let foundingPage = source else { continue }
            if !history.contains(where: { $0.id == foundingPage.id }) {
                history.insert(foundingPage, at: 0)
            }

            register.append(Neighbour(
                slug: founding.slug,
                name: name,
                isEpithet: isEpithet,
                formerNames: former,
                kind: founding.kind,
                key: founding.key,
                foundingPageID: foundingPage.id,
                foundedAt: foundingPage.createdAt,
                foundingRecordID: founding.record.id,
                foundingSentence: quotable(readerText(foundingPage)),
                working: founding.working,
                latitude: foundingPage.context?.latitude,
                longitude: foundingPage.context?.longitude,
                pageIDs: history.map(\.id),
                pageDates: history.map(\.createdAt),
                lastSeen: history.map(\.createdAt).max() ?? foundingPage.createdAt,
                status: status,
                statusChangedAt: changedAt
            ))
        }
        return register
    }
}

// MARK: - Records

extension Neighbours {
    private static func record(
        slug: String, event: Event, title: String, body: String,
        now: Date, extraTags: [String] = [], metadata: [String: String]
    ) -> BookPage {
        var meta = metadata
        meta["source"] = sourceID
        meta["neighbourSlug"] = slug
        meta["neighbourEvent"] = event.rawValue
        return BookPage(
            id: "neighbour-\(event.rawValue)-\(slug)-\(Int(now.timeIntervalSince1970))",
            type: .neighbours,
            createdAt: now,
            promptText: title,
            userInput: body,
            tags: [recordTag, "neighbour:\(slug)", "neighbour-event:\(event.rawValue)"] + extraTags,
            sourceID: sourceID,
            origin: .generated,
            metadata: meta
        )
    }

    /// The kept Page that makes a proposal a Neighbour. `name` is the
    /// reader's correction, given in the same step; nil keeps the Book's
    /// guess. Nil when this one is already in the register, so confirming
    /// twice makes one Neighbour.
    static func foundingRecord(
        for proposal: NeighbourProposal, name correction: String? = nil,
        days: [BookDay], now: Date
    ) -> BookPage? {
        let existing = register(days: days)
        guard !existing.contains(where: { $0.key == proposal.key || $0.foundingPageID == proposal.foundingPageID })
        else { return nil }
        let corrected = correction?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let name = corrected ?? proposal.name
        let isEpithet = corrected == nil && proposal.isEpithet
        let base = slug(for: name).nonEmpty ?? slug(for: proposal.key)
        var slug = base
        var suffix = 2
        let taken = Set(existing.map(\.slug))
        while taken.contains(slug) {
            slug = "\(base)-\(suffix)"
            suffix += 1
        }
        var metadata: [String: String] = [
            "neighbourName": name,
            "neighbourKind": proposal.kind.rawValue,
            "neighbourMatch": corrected.map { _ in proposal.match.hasPrefix("name:") ? "none" : proposal.match } ?? proposal.match,
            "neighbourKey": proposal.key,
            "neighbourSource": proposal.foundingPageID
        ]
        if isEpithet { metadata["neighbourEpithet"] = "true" }
        if let working = proposal.working { metadata["neighbourWorking"] = working }
        let spoken = isEpithet ? capitalized(name) : name
        return record(
            slug: slug, event: .founded,
            title: spoken,
            body: "\(spoken) lives in here now. Every Page it turns up on, I'll know.",
            now: now,
            extraTags: ["neighbour-kind:\(proposal.kind.rawValue)",
                        "neighbour-key:\(proposal.key)",
                        "neighbour-source:\(proposal.foundingPageID)"],
            metadata: metadata
        )
    }

    static func renameRecord(_ neighbour: Neighbour, to newName: String, now: Date) -> BookPage? {
        guard neighbour.status != .gone,
              let name = newName.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              name != neighbour.name else { return nil }
        return record(
            slug: neighbour.slug, event: .renamed,
            title: name,
            body: "\(capitalized(neighbour.name))'s called \(name) now. I've kept the old name too.",
            now: now,
            metadata: ["neighbourName": name, "neighbourFormerName": neighbour.name]
        )
    }

    static func restRecord(_ neighbour: Neighbour, now: Date) -> BookPage? {
        guard neighbour.status == .living else { return nil }
        let spoken = capitalized(neighbour.name)
        return record(
            slug: neighbour.slug, event: .resting, title: spoken,
            body: "\(spoken)'s resting. I won't ask after it. Its Pages stay where they are.",
            now: now, metadata: ["neighbourName": neighbour.name]
        )
    }

    static func wakeRecord(_ neighbour: Neighbour, now: Date) -> BookPage? {
        guard neighbour.status == .resting else { return nil }
        let spoken = capitalized(neighbour.name)
        return record(
            slug: neighbour.slug, event: .awake, title: spoken,
            body: "\(spoken)'s awake again.",
            now: now, metadata: ["neighbourName": neighbour.name]
        )
    }

    /// "It's gone." The Neighbour stays in the register, and on the map, as
    /// gone, with its dates. The Book doesn't console. It writes it down.
    static func goneRecord(_ neighbour: Neighbour, now: Date, calendar: Calendar = .current) -> BookPage? {
        guard neighbour.status != .gone else { return nil }
        let spoken = capitalized(neighbour.name)
        let from = monthYear(neighbour.foundedAt, calendar: calendar)
        let to = monthYear(now, calendar: calendar)
        let span = from == to ? "It came in \(from)." : "It was in here from \(from) to \(to)."
        return record(
            slug: neighbour.slug, event: .gone, title: spoken,
            body: "\(spoken)'s gone. \(span) That's written down now.",
            now: now, metadata: ["neighbourName": neighbour.name]
        )
    }

    static func monthYear(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func month(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Proposals

extension Neighbours {
    /// What a naming working proposes when the reader's words hold no name.
    struct NamingWorking {
        var deed: String
        /// "the tree". Nil when the working's subject isn't something the
        /// Book can call it by; then it borrows a noun from the reader's
        /// sentence, or proposes nothing.
        var epithet: String?
        var kind: NeighbourKind
    }

    /// The workings that ask the reader to name something, or treat it as
    /// somebody. Keyed `spell:<id>`, `mission:<id>`, `dare:<id>`.
    static let namingWorkings: [String: NamingWorking] = [
        "spell:name-a-tree": NamingWorking(deed: "You told a tree its name.", epithet: "the tree", kind: .place),
        "mission:faerie-name-earned": NamingWorking(deed: "You gave something a name for what it does.", epithet: nil, kind: .thing),
        "mission:tiny-kindness": NamingWorking(deed: "You gave a lost thing a name.", epithet: "the lost thing", kind: .thing),
        "mission:chair-held": NamingWorking(deed: "You asked a chair what it thinks of you.", epithet: "the chair", kind: .thing),
        "mission:faerie-door-courtesy": NamingWorking(deed: "You asked a drawer to open.", epithet: "the drawer", kind: .thing),
        "mission:object-drawer-greeting": NamingWorking(deed: "You said hello to something in a drawer.", epithet: nil, kind: .thing),
        "dare:room-renaming": NamingWorking(deed: "You gave a room a new name.", epithet: "the room", kind: .place)
    ]

    /// The working a kept Page answered, as a `namingWorkings` key.
    static func working(of page: BookPage) -> String? {
        if page.type == .spell, let spell = tagValue("spell:", in: page.tags) {
            return "spell:\(spell)"
        }
        guard let receipt = page.attributableLivedQuestReceipt else { return nil }
        switch receipt.kind {
        case .playfulMission: return "mission:\(receipt.questID)"
        case .wickerDare: return "dare:\(receipt.questID)"
        default: return nil
        }
    }

    /// Nouns a reader writes about all the time without any of them being
    /// somebody: weather, meals, the furniture of a day.
    static let notSomebody: Set<String> = [
        "rain", "sun", "snow", "wind", "cloud", "sky", "weather", "fog", "storm", "cold", "heat",
        "coffee", "tea", "food", "lunch", "dinner", "breakfast", "supper", "water", "drink",
        "meal", "snack", "walk", "run", "trip", "drive", "commute", "shower", "bath", "bed",
        "phone", "email", "text", "call", "meeting", "class", "school", "office", "shop",
        "family", "friend", "kid", "child", "mum", "mom", "dad", "partner", "wife", "husband",
        "baby", "brother", "sister", "boss", "colleague", "neighbour", "neighbor", "light",
        "music", "song", "show", "film", "movie", "game", "news", "money", "house", "room",
        "kitchen", "garden", "street", "road", "town", "city", "car", "bus", "train",
        "outside", "inside", "air", "ground", "floor", "wall", "window", "door", "table"
    ]

    /// Nouns that are rooted to one spot.
    static let placeNouns: Set<String> = [
        "tree", "oak", "ash", "elm", "birch", "willow", "yew", "beech", "pine", "hedge",
        "bench", "bridge", "gate", "wall", "stone", "rock", "pond", "puddle", "stream",
        "lamppost", "postbox", "corner", "stile", "fence", "well", "hill", "path", "lane"
    ]

    private static let openers: Set<String> = [
        "the", "this", "that", "these", "those", "it", "its", "it's", "my", "our", "your",
        "their", "his", "her", "she", "he", "we", "they", "you", "there", "here", "then",
        "when", "what", "which", "who", "why", "how", "today", "yesterday", "tonight",
        "called", "named", "just", "also", "and", "but", "so", "yes", "no", "not", "maybe",
        "well", "oh", "finally", "now", "after", "before", "because", "said", "told", "gave",
        "went", "found", "nothing", "something", "everything", "one", "first", "last",
        "a", "an", "if", "i", "i'm", "i've", "i'd", "i'll", "sat", "asked", "opened"
    ]

    private static let namingCues: Set<String> = [
        "called", "named", "name", "is", "it's", "christened", "dubbed", "call", "renamed", "was"
    ]

    private static let runConnectors: Set<String> = ["of", "the", "and"]

    private static func tokens(in sentence: String) -> [String] {
        sentence.split(whereSeparator: { !($0.isLetter || $0 == "'" || $0 == "\u{2019}") })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func isNameShaped(_ word: String) -> Bool {
        guard word.count >= 3, let first = word.first, first.isUppercase else { return false }
        let body = word.dropFirst().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        guard !body.isEmpty else { return false }
        return body.allSatisfy { $0.isLetter && $0.isLowercase }
    }

    private static func sentences(in text: String) -> [String] {
        text.split(whereSeparator: { ".!?\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// How often each word appears lowercased in the reader's own writing,
    /// across the archive. A word written lowercase as often as it's written
    /// with a capital is a common noun, not a name.
    ///
    /// Capitalised uses are counted under the lowercased word with a leading
    /// "^", so one dictionary carries both sides of the comparison.
    static func lowercaseCounts(pages: [BookPage]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for page in pages {
            guard let text = readerText(page) else { continue }
            for sentence in sentences(in: text) {
                for (index, word) in tokens(in: sentence).enumerated() {
                    if word == word.lowercased() {
                        counts[word, default: 0] += 1
                    } else if index > 0 {
                        counts["^" + word.lowercased(), default: 0] += 1
                    }
                }
            }
        }
        return counts
    }

    /// A name in a line of the reader's: capitalised mid-sentence, not a word
    /// the reader also writes lowercase, not anybody the Book already knows.
    /// A reply that is only a name ("Gerald." or "Gerald, the big ash.") may
    /// open the sentence.
    static func nameCandidate(
        in text: String, excluded: Set<String>, lowercaseCounts: [String: Int]
    ) -> String? {
        let excludedLower = Set(excluded.flatMap { name -> [String] in
            [name.lowercased()] + name.split(separator: " ").map { $0.lowercased() }
        }).union(PeopleOfTheBook.commonCapitalizedWords)

        func usable(_ word: String) -> Bool {
            isNameShaped(word) && !excludedLower.contains(word.lowercased())
                && lowercaseCounts[word.lowercased(), default: 0] < max(1, lowercaseCounts["^" + word.lowercased(), default: 0])
        }

        var cued: String?
        var first: String?
        for sentence in sentences(in: text) {
            let words = tokens(in: sentence)
            var index = 1
            while index < words.count {
                guard usable(words[index]) else { index += 1; continue }
                var run = [words[index]]
                var cursor = index + 1
                while cursor < words.count, run.count < 5 {
                    if isNameShaped(words[cursor]) && !excludedLower.contains(words[cursor].lowercased()) {
                        run.append(words[cursor]); cursor += 1
                    } else if runConnectors.contains(words[cursor]), cursor + 1 < words.count, isNameShaped(words[cursor + 1]) {
                        run.append(words[cursor]); cursor += 1
                    } else {
                        break
                    }
                }
                let name = run.joined(separator: " ")
                if first == nil { first = name }
                if cued == nil, namingCues.contains(words[index - 1].lowercased()) { cued = name }
                index = cursor
            }
        }
        if let found = cued ?? first { return found }

        // A reply that is only a name.
        guard let opening = sentences(in: text).first else { return nil }
        let segment = opening.split(whereSeparator: { ",:;\u{2014}\u{2013}-".contains($0) }).first.map(String.init) ?? opening
        let words = tokens(in: segment)
        guard (1...2).contains(words.count),
              words.allSatisfy({ usable($0) && !openers.contains($0.lowercased()) && !TaleSubjects.stopwords.contains($0.lowercased()) })
        else { return nil }
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = segment
        let (tag, _) = tagger.tag(at: segment.startIndex, unit: .word, scheme: .lexicalClass)
        if let tag, [.verb, .adverb, .pronoun, .determiner, .preposition, .conjunction, .interjection, .adjective].contains(tag) {
            return nil
        }
        #endif
        return words.joined(separator: " ")
    }

    /// The noun that comes first in a line of the reader's, for a naming
    /// working whose subject the Book has no word for.
    static func firstThing(in text: String, cacheKey: String) -> String? {
        let things = TaleSubjects.things(in: text, cacheKey: cacheKey)
            .filter { !notSomebody.contains($0) }
        let lowered = text.lowercased()
        return things.compactMap { word -> (String, String.Index)? in
            lowered.range(of: word).map { (word, $0.lowerBound) }
        }.min { $0.1 < $1.1 }?.0
    }

    /// Everything the Book would like to ask about, best first.
    ///
    /// Naming workings come first and newest first: the reader just told
    /// something its name. Then things that keep coming back: a noun on three
    /// Pages on three days, written "the kettle" or "my kettle" at least twice,
    /// and a creature photographed on two days.
    static func proposals(
        days: [BookDay],
        excludedNames: Set<String> = [],
        excludedSlugs: Set<String> = [],
        declinedKeys: Set<String> = [],
        calendar: Calendar = .current
    ) -> [NeighbourProposal] {
        let pages = allPages(in: days)
        let existing = register(days: days)
        let foundedKeys = Set(existing.map(\.key))
        let foundedSources = Set(existing.map(\.foundingPageID))
        // Any founding record, even one whose Neighbour has since lost its
        // Page, means the reader already answered this proposal.
        let recordedKeys = Set(pages.filter(isRecord).compactMap { tagValue("neighbour-key:", in: $0.tags) })
        let knownNames = Set(existing.flatMap { [$0.name] + $0.formerNames }.map { $0.lowercased() })
        let counts = lowercaseCounts(pages: pages)
        let excludedLower = Set(excludedNames.map { $0.lowercased() })

        func open(_ key: String, name: String, source: String) -> Bool {
            !foundedKeys.contains(key) && !recordedKeys.contains(key) && !foundedSources.contains(source)
                && !declinedKeys.contains("neighbour-propose:\(key)")
                && !knownNames.contains(name.lowercased())
                && !excludedLower.contains(name.lowercased())
                && !excludedSlugs.contains(slug(for: name))
        }

        var results: [NeighbourProposal] = []

        // 1. By naming.
        let named = pages.filter { !isRecord($0) }
            .sorted { $0.createdAt == $1.createdAt ? $0.id > $1.id : $0.createdAt > $1.createdAt }
        for page in named {
            guard let working = working(of: page), let terms = namingWorkings[working],
                  let text = readerText(page) else { continue }
            let key = "page:\(page.id)"
            var name: String
            var isEpithet = false
            var match: String
            if let found = nameCandidate(in: text, excluded: excludedNames, lowercaseCounts: counts) {
                name = found
                match = "name:\(found)"
            } else if let epithet = terms.epithet {
                name = epithet
                isEpithet = true
                match = "none"
            } else if let noun = firstThing(in: text, cacheKey: page.id) {
                name = "the \(noun)"
                isEpithet = true
                match = "none"
            } else {
                continue
            }
            guard open(key, name: name, source: page.id) else { continue }
            results.append(NeighbourProposal(
                key: key, name: name, isEpithet: isEpithet, kind: terms.kind,
                foundingPageID: page.id, foundedAt: page.createdAt, working: working,
                quote: quotable(text), deed: terms.deed, match: match, evidencePageIDs: [page.id]
            ))
        }

        // 2. By coming back: a thing in the reader's own words.
        let authored = pages.filter { readerText($0) != nil }
        let matchedWords = Set(existing.compactMap { $0.key.hasPrefix("word:") ? String($0.key.dropFirst(5)) : nil })
        var byNoun: [String: [BookPage]] = [:]
        for page in authored {
            guard let text = readerText(page) else { continue }
            for noun in Set(TaleSubjects.things(in: text, cacheKey: page.id)) {
                byNoun[noun, default: []].append(page)
            }
        }
        var recurring: [(noun: String, pages: [BookPage])] = []
        for (noun, found) in byNoun {
            guard !notSomebody.contains(noun), !matchedWords.contains(noun) else { continue }
            let dayCount = Set(found.map { calendar.startOfDay(for: $0.createdAt) }).count
            guard found.count >= 3, dayCount >= 3 else { continue }
            // Furniture: a word in nearly every Page isn't a happening.
            if authored.count >= 10, Double(found.count) / Double(authored.count) > 0.4 { continue }
            // A particular one: "the kettle", "my kettle", not "kettles".
            let particular = found.filter { page in
                let text = (readerText(page) ?? "").lowercased()
                return ["the", "my", "our", "his", "her", "their"].contains { text.contains("\($0) \(noun)") }
            }
            guard particular.count >= 2 else { continue }
            recurring.append((noun, found.sorted { $0.createdAt < $1.createdAt }))
        }
        recurring.sort { $0.pages.count != $1.pages.count ? $0.pages.count > $1.pages.count : $0.noun < $1.noun }
        for (noun, found) in recurring {
            let key = "word:\(noun)"
            let name = "the \(noun)"
            guard let first = found.first, open(key, name: name, source: first.id) else { continue }
            let kind: NeighbourKind = Bestiary.creatureLabels.contains(noun) ? .creature
                : placeNouns.contains(noun) ? .place : .thing
            let quote = found.reversed().lazy.compactMap { quotable(readerText($0)) }.first
            results.append(NeighbourProposal(
                key: key, name: name, isEpithet: true, kind: kind,
                foundingPageID: first.id, foundedAt: first.createdAt, working: nil,
                quote: quote,
                deed: "\(capitalized(name)) keeps turning up in your Pages, on different days, in your own words.",
                match: key, evidencePageIDs: found.suffix(6).map(\.id)
            ))
        }

        // 3. By coming back: a creature in the reader's photographs.
        let matchedCreatures = Set(existing.compactMap { $0.key.hasPrefix("creature:") ? String($0.key.dropFirst(9)) : nil })
        var byCreature: [String: [BookPage]] = [:]
        for page in pages where !isRecord(page) {
            for creature in Set((page.creatureSightings ?? []).map(\.creature)) {
                byCreature[creature, default: []].append(page)
            }
        }
        for (creature, found) in byCreature.sorted(by: { $0.key < $1.key }) {
            guard !matchedCreatures.contains(creature), !matchedWords.contains(creature) else { continue }
            let sorted = found.sorted { $0.createdAt < $1.createdAt }
            guard Set(sorted.map { calendar.startOfDay(for: $0.createdAt) }).count >= 2,
                  let first = sorted.first else { continue }
            let key = "creature:\(creature)"
            let name = "the \(creature)"
            guard open(key, name: name, source: first.id) else { continue }
            results.append(NeighbourProposal(
                key: key, name: name, isEpithet: true, kind: .creature,
                foundingPageID: first.id, foundedAt: first.createdAt, working: nil,
                quote: nil,
                deed: "\(capitalized(name)) keeps turning up in your photographs, on different days. I think it's the same one.",
                match: key, evidencePageIDs: sorted.suffix(6).map(\.id)
            ))
        }
        return results
    }

    /// The proposal a notice carried, read back off its metadata when the
    /// reader taps to confirm it.
    static func proposal(fromMetadata metadata: [String: String]) -> NeighbourProposal? {
        guard let key = metadata["neighbourKey"]?.nonEmpty,
              let name = metadata["neighbourName"]?.nonEmpty,
              let source = metadata["neighbourSource"]?.nonEmpty else { return nil }
        return NeighbourProposal(
            key: key, name: name,
            isEpithet: metadata["neighbourEpithet"] == "true",
            kind: metadata["neighbourKind"].flatMap(NeighbourKind.init(rawValue:)) ?? .thing,
            foundingPageID: source,
            foundedAt: metadata["neighbourFoundedAt"].flatMap(Double.init).map(Date.init(timeIntervalSince1970:)) ?? Date(),
            working: metadata["neighbourWorking"]?.nonEmpty,
            quote: nil,
            deed: "",
            match: metadata["neighbourMatch"] ?? "none",
            evidencePageIDs: (metadata["evidencePageIDs"] ?? "").split(separator: ",").map(String.init)
        )
    }

    static func metadata(for proposal: NeighbourProposal) -> [String: String] {
        var metadata: [String: String] = [
            "neighbourKey": proposal.key,
            "neighbourName": proposal.name,
            "neighbourKind": proposal.kind.rawValue,
            "neighbourSource": proposal.foundingPageID,
            "neighbourFoundedAt": "\(proposal.foundedAt.timeIntervalSince1970)",
            "neighbourMatch": proposal.match
        ]
        if proposal.isEpithet { metadata["neighbourEpithet"] = "true" }
        if let working = proposal.working { metadata["neighbourWorking"] = working }
        if !proposal.evidencePageIDs.isEmpty {
            metadata["evidencePageIDs"] = proposal.evidencePageIDs.joined(separator: ",")
        }
        return metadata
    }
}

// MARK: - Addressed workings

extension Neighbours {
    /// "the kettle" in a title: "the Kettle". A real name stays as written.
    static func titled(_ name: String) -> String {
        guard name.hasPrefix("the "), name.count > 4 else { return name }
        let rest = name.dropFirst(4)
        return "the " + rest.prefix(1).uppercased() + rest.dropFirst()
    }

    struct VisitTemplate {
        var title: (_ name: String) -> String
        var action: (_ name: String, _ spoken: String) -> String
        var proof: (_ name: String) -> String
    }

    /// Errands that take a Neighbour by name, chosen by kind. Each one
    /// believes something about it and asks for one sentence back.
    static let visitTemplates: [NeighbourKind: [VisitTemplate]] = [
        .thing: [
            VisitTemplate(
                title: { "News for \(titled($0))" },
                action: { name, _ in "Go and tell \(name) the news. One piece of it, out loud, close enough that it hears." },
                proof: { "One sentence about what you told \($0)." }),
            VisitTemplate(
                title: { "What \(titled($0))'s Keeping" },
                action: { name, _ in "Ask \(name) what it's been keeping from you. Wait for the answer. Things are slow." },
                proof: { "One sentence. What's \($0) been keeping from you?" }),
            VisitTemplate(
                title: { _ in "A Night Somewhere Else" },
                action: { name, _ in "Move \(name) somewhere new for one night. In the morning, ask it where it'd rather live." },
                proof: { "One sentence about where \($0) wants to live." })
        ],
        .creature: [
            VisitTemplate(
                title: { "Good Morning, \(titled($0))" },
                action: { name, _ in "Next time you see \(name), say good morning before it sees you. Then watch what it does." },
                proof: { "One sentence about what \($0) did." }),
            VisitTemplate(
                title: { "\(titled($0))'s Job" },
                action: { _, spoken in "\(spoken) has a job. Everything alive has one. Watch it until you know what the job is." },
                proof: { "One sentence. What's \($0)'s job?" }),
            VisitTemplate(
                title: { "News for \(titled($0))" },
                action: { name, _ in "Tell \(name) one thing that happened to you this week. Out loud. It'll pass it on." },
                proof: { "One sentence about what you told \($0)." })
        ],
        .place: [
            VisitTemplate(
                title: { "Who's Been to See \(titled($0))" },
                action: { name, _ in "Go and see \(name). Ask it who else has been by. Look for what they left." },
                proof: { "One sentence. Who's been to see \($0)?" }),
            VisitTemplate(
                title: { "News for \(titled($0))" },
                action: { name, _ in "Go past \(name) and tell it the news. One piece of it, out loud." },
                proof: { "One sentence about what you told \($0)." }),
            VisitTemplate(
                title: { _ in "Something's Different" },
                action: { name, _ in "Go and see \(name). Something there has changed since you were last there. Find it." },
                proof: { _ in "One sentence about what's changed." })
        ]
    ]

    /// The first visit comes this many days after a Neighbour is founded,
    /// and then every `visitCycleDays`, open for `visitWindowDays`.
    static let firstVisitDays = 10
    static let visitCycleDays = 28
    static let visitWindowDays = 3

    /// Which visit, if any, a Neighbour of this age is due today.
    static func visitStage(ageInDays age: Int) -> Int? {
        guard age >= firstVisitDays, (age - firstVisitDays) % visitCycleDays < visitWindowDays else { return nil }
        return (age - firstVisitDays) / visitCycleDays
    }

    /// The reader's latest short sentence about this Neighbour, whole.
    static func latestSentence(about neighbour: Neighbour, days: [BookDay]) -> String? {
        let byID = Dictionary(allPages(in: days).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in neighbour.pageIDs.reversed() {
            if let page = byID[id], let quote = quotable(readerText(page)) { return quote }
        }
        return nil
    }

    /// Errands for the Neighbours whose visit has come due and gone
    /// unanswered. They ride the same due-date tier as the deals, so they take
    /// every other turn and a reader who lets one lie still has an ordinary
    /// errand to pick up.
    static func visitMissions(
        days: [BookDay], selfFacts: [SelfFact], now: Date, calendar: Calendar = .current
    ) -> [PlayfulMission] {
        let register = register(days: days).filter(\.isLiving)
        guard !register.isEmpty else { return [] }
        let indoors = ReaderDeclaredCurationProfile.make(from: selfFacts).leavingHome == "keep wonder indoors"
        let answered = Set(allPages(in: days).compactMap(\.attributableLivedQuestReceipt)
            .flatMap(\.sourceTags)
            .filter { $0.hasPrefix("mission:neighbour-visit:") }
            .map { String($0.dropFirst("mission:neighbour-visit:".count)) })
        var missions: [PlayfulMission] = []
        for neighbour in register {
            if indoors, neighbour.kind == .place { continue }
            if NeighbourNotices.nameDayYears(for: neighbour, on: now, calendar: calendar) != nil { continue }
            guard let age = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: neighbour.foundedAt), to: calendar.startOfDay(for: now)
            ).day, let stage = visitStage(ageInDays: age),
                  !answered.contains("\(neighbour.slug):v\(stage)"),
                  let templates = visitTemplates[neighbour.kind], !templates.isEmpty else { continue }
            let template = templates[(stage + abs(neighbour.slug.stableHash)) % templates.count]
            let name = neighbour.name
            let spoken = capitalized(name)
            let lead = latestSentence(about: neighbour, days: days)
                .map { "You wrote this about \(name): \u{201C}\($0)\u{201D}\n\n" } ?? ""
            missions.append(PlayfulMission(
                id: "neighbour-visit-\(neighbour.slug)-v\(stage)",
                title: template.title(name),
                prompt: lead + template.action(name, spoken),
                proofPrompt: template.proof(name),
                tags: ["neighbour", neighbour.kind == .place ? "outward" : "inside", "low-energy",
                       PlayfulMissionPractice.returnVisit.tag,
                       "neighbour-of:\(neighbour.slug)", "neighbour-visit:\(neighbour.slug):v\(stage)"],
                allowsPhoto: false
            ))
        }
        return missions
    }
}

// MARK: - The Book's one line

extension Neighbours {
    /// How a Neighbour is doing, in one line, from facts only: when it was
    /// last in the reader's Pages, whether there's a deal with it, and what
    /// month it is. Nothing here is a guess about the reader.
    static func line(for neighbour: Neighbour, days: [BookDay], now: Date, calendar: Calendar = .current) -> String {
        let spoken = capitalized(neighbour.name)
        switch neighbour.status {
        case .gone:
            let from = monthYear(neighbour.foundedAt, calendar: calendar)
            let to = monthYear(neighbour.statusChangedAt ?? now, calendar: calendar)
            return from == to ? "\(spoken)'s gone. It came in \(from)." : "\(spoken)'s gone. It was in here from \(from) to \(to)."
        case .resting:
            return "\(spoken)'s resting. The last Page it was on was in \(monthYear(neighbour.lastSeen, calendar: calendar))."
        case .living:
            break
        }
        let quiet = NeighbourNotices.dayCount(from: neighbour.lastSeen, to: now, calendar: calendar)
        let seen: String
        switch quiet {
        case ..<1: seen = "\(spoken) was in your Pages today."
        case 1: seen = "\(spoken) was in your Pages yesterday."
        case 2...6: seen = "\(spoken) was in your Pages this week."
        case 7...13: seen = "\(spoken) was in your Pages last week."
        default: seen = "\(spoken) hasn't been in your Pages since \(month(neighbour.lastSeen, calendar: calendar))."
        }

        // A deal set on the founding Page.
        let pages = allPages(in: days)
        if let founding = pages.first(where: { $0.id == neighbour.foundingPageID }),
           founding.type == .spell,
           let spellID = tagValue("spell:", in: founding.tags),
           let terms = PlayfulMissionRegistry.promiseTerms[spellID], terms.standing {
            let answers = pages.compactMap(\.attributableLivedQuestReceipt)
                .filter { $0.sourceTags.contains { $0.hasPrefix("mission:promise-call:\(founding.id):") } }
                .map(\.completedAt)
            if let last = answers.max() {
                return "\(seen) You last told me about your deal with it in \(month(last, calendar: calendar))."
            }
            return "\(seen) There's a deal with it, and you haven't told me how it's going."
        }

        let age = NeighbourNotices.dayCount(from: neighbour.foundedAt, to: now, calendar: calendar)
        if age < 365, calendar.component(.month, from: neighbour.foundedAt) != calendar.component(.month, from: now) {
            return "\(seen) It's \(neighbour.name)'s first \(month(now, calendar: calendar)) in here."
        }
        return seen
    }
}

// MARK: - The reply when a deal or a visit comes back

/// When the reader answers a deal's call-in, a Neighbour's visit or its
/// name-day, the Book answers back at keep time. It records the answer. It
/// never judges the reader's sentence and never says whether they kept their
/// side: it doesn't know, and that's theirs.
enum DealReplyMarginalia {
    static let bookSlug = "the-book"
    static let bookName = "The Book"
    static let bookAsset = "LabyrinthFaeBookSprite"

    /// "a week on", "a month on", "a year on".
    static func stageWords(_ stage: String) -> String {
        switch stage {
        case "d7": return "a week on"
        case "d30": return "a month on"
        case "d90": return "three months on"
        default:
            guard stage.hasPrefix("y"), let years = Int(stage.dropFirst()), years >= 1 else { return "later on" }
            let words = ["a year", "two years", "three years", "four years", "five years",
                         "six years", "seven years", "eight years", "nine years", "ten years"]
            return (years <= words.count ? words[years - 1] : "years") + " on"
        }
    }

    static func tags(of surface: SurfacePage) -> [String] {
        (surface.payload.metadata["tags"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("mission:") ? String($0.dropFirst(8)) : $0 }
    }

    static func note(for surface: SurfacePage, readerInput: String, priorDays: [BookDay]) -> KeepMarginalia.Note? {
        guard readerInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil else { return nil }
        let tags = tags(of: surface)
        let seed = KeepMarginalia.seed(for: "deal-reply|\(surface.id)|\(readerInput)")
        func pick(_ lines: [String]) -> KeepMarginalia.Note {
            KeepMarginalia.Note(castSlug: bookSlug, castName: bookName, assetName: bookAsset,
                                line: lines[Int(seed % UInt64(lines.count))])
        }

        if let call = tags.first(where: { $0.hasPrefix("promise-call:") }) {
            let parts = call.dropFirst("promise-call:".count).split(separator: ":").map(String.init)
            guard parts.count >= 2 else { return nil }
            let pageID = parts.dropLast().joined(separator: ":")
            let on = stageWords(parts.last ?? "")
            if let neighbour = Neighbours.neighbour(foundedBy: pageID, days: priorDays), !neighbour.isEpithet {
                let name = neighbour.name
                return pick([
                    "\(name)'s deal, \(on). I've put your sentence on \(name)'s page, next to the day you made it.",
                    "Written down. That's \(name)'s deal \(on), in your words. I'll come back for it again."
                ])
            }
            return pick([
                "Written down, \(on), next to the day you made the deal. I'll come back for it again.",
                "That's the deal \(on), in your own words. I've put it with the first Page."
            ])
        }

        let slug = tags.first(where: { $0.hasPrefix("neighbour-of:") }).map { String($0.dropFirst("neighbour-of:".count)) }
        if let slug, let neighbour = Neighbours.neighbour(slug: slug, days: priorDays) {
            let spoken = Neighbours.capitalized(neighbour.name)
            if tags.contains("nameday") {
                return pick([
                    "That's \(neighbour.name)'s name-day kept. I've written down what you gave it.",
                    "\(spoken) had a name-day and you were there for it. It's on its page now."
                ])
            }
            return pick([
                "I've put that on \(neighbour.name)'s page.",
                "\(spoken)'s got another Page now. This one."
            ])
        }
        return nil
    }
}

extension Neighbours {
    /// A return visit to a Page that founded a Neighbour is that Neighbour's
    /// business now: its own visits ask after it, by name, so the older,
    /// nameless return steps aside.
    static func supersedingVisits(_ returns: [PlayfulMission], days: [BookDay]) -> [PlayfulMission] {
        let founded = Set(register(days: days).map(\.foundingPageID))
        guard !founded.isEmpty else { return returns }
        return returns.filter { mission in
            !mission.tags.contains { tag in
                tag.hasPrefix("return-source:") && founded.contains(String(tag.dropFirst("return-source:".count)))
            }
        }
    }
}

// MARK: - Gemma's two small jobs (core half)
//
// Phase 7. Two thinking jobs about Neighbours, each a small prompt with facts
// in it and a verdict or one line out of it. A 2B model renders well and
// invents badly, so it is handed facts and asked to join them, and whatever it
// says is checked before it's shown. The deterministic line is always the
// fallback. Tested with a fake teller; not yet wired into the writing desk.

enum NeighbourThinking {
    typealias Teller = (_ prompt: String, _ instructions: String) -> String?

    // MARK: How are they?

    static func howAreTheyPrompt(for neighbour: Neighbour, days: [BookDay], now: Date, calendar: Calendar = .current) -> (prompt: String, instructions: String) {
        var facts = ["Name: \(neighbour.name)", "Kind: \(neighbour.kind.rawValue)",
                     "First page: \(Neighbours.monthYear(neighbour.foundedAt, calendar: calendar))",
                     "Last page: \(Neighbours.monthYear(neighbour.lastSeen, calendar: calendar))",
                     "Today: \(Neighbours.monthYear(now, calendar: calendar))"]
        if let sentence = neighbour.foundingSentence { facts.append("The reader once wrote: \(sentence)") }
        let prompt = """
        Facts about something in a reader's life that has become somebody:
        \(facts.map { "- \($0)" }.joined(separator: "\n"))

        Write one short sentence about how \(neighbour.name) is doing, as if \(neighbour.name) is alive and has its own life.
        Say \(neighbour.name) in it. Say nothing about what the reader did, felt or thought. Don't copy the reader's words.
        """
        let instructions = "You are a feral child who believes everything is alive. You answer with one plain sentence and nothing else."
        return (prompt, instructions)
    }

    /// The reader's own words any line is checked against.
    static func readerTexts(for neighbour: Neighbour, days: [BookDay]) -> [String] {
        let byID = Dictionary(Neighbours.allPages(in: days).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return neighbour.pageIDs.compactMap { byID[$0].flatMap(Neighbours.readerText) }
    }

    /// Phrases that put an act or a feeling in the reader's mouth.
    static let readerClaims = [
        "you felt", "you feel", "you were", "you went", "you did", "you said", "you thought",
        "you loved", "you love", "you miss", "you missed", "you forgot", "you remember",
        "you wanted", "you want", "you're", "you've", "your heart", "you visited", "you saw"
    ]

    /// One line, or nil when it fails any check: one sentence, the
    /// Neighbour named, no reader act or feeling, no five-word run copied
    /// from the reader, no name the facts don't hold, the Book's punctuation.
    static func checked(_ response: String?, neighbour: Neighbour, readerTexts: [String]) -> String? {
        guard var line = response?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else { return nil }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
        let terminators = line.filter { ".!?".contains($0) }.count
        guard line.count <= 160, terminators <= 1, !line.contains("\n"),
              line.contains(neighbour.name) || line.contains(Neighbours.capitalized(neighbour.name)) else { return nil }
        let lowered = line.lowercased()
        guard !readerClaims.contains(where: { lowered.contains($0) }),
              !line.contains(";"), !line.contains("\u{2014}"), !line.contains("\u{2013}"),
              !lowered.contains("the book") else { return nil }
        // No five-word run lifted from the reader's own sentences.
        let words = lowered.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        if words.count >= 5 {
            let theirs = readerTexts.map { $0.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).joined(separator: " ") }
            for start in 0...(words.count - 5) {
                let run = words[start..<(start + 5)].joined(separator: " ")
                if theirs.contains(where: { $0.contains(run) }) { return nil }
            }
        }
        // No new names: every capitalised word after the first must be the
        // Neighbour's own name or "I".
        let months = ["January", "February", "March", "April", "May", "June", "July", "August",
                      "September", "October", "November", "December"]
        let allowed = Set(neighbour.name.split(separator: " ").map(String.init) + ["I"] + months)
        let tokens = line.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "\u{2019}" }).map(String.init)
        for token in tokens.dropFirst() where token.first?.isUppercase == true {
            var bare = token
            for suffix in ["'s", "\u{2019}s"] where bare.hasSuffix(suffix) { bare = String(bare.dropLast(2)) }
            if !allowed.contains(bare) && !token.hasPrefix("I'") && !token.hasPrefix("I\u{2019}") { return nil }
        }
        return line.hasSuffix(".") || line.hasSuffix("!") || line.hasSuffix("?") ? line : line + "."
    }

    /// Gemma's line when it passes, the Book's deterministic line otherwise.
    static func howAreThey(
        _ neighbour: Neighbour, days: [BookDay], now: Date, calendar: Calendar = .current, teller: Teller?
    ) -> String {
        let fallback = Neighbours.line(for: neighbour, days: days, now: now, calendar: calendar)
        guard neighbour.isLiving, let teller else { return fallback }
        let ask = howAreTheyPrompt(for: neighbour, days: days, now: now, calendar: calendar)
        return checked(teller(ask.prompt, ask.instructions), neighbour: neighbour,
                       readerTexts: readerTexts(for: neighbour, days: days)) ?? fallback
    }

    // MARK: Who is this?

    static func whoIsThisPrompt(sentence: String) -> (prompt: String, instructions: String) {
        let prompt = """
        A reader wrote this sentence:
        "\(sentence)"

        Does the reader give a name to a thing, an animal or a place in it? If yes, answer NAME: and the name exactly as the reader wrote it. If no, answer NONE.
        """
        return (prompt, "You answer with exactly one line: NAME: <name> or NONE.")
    }

    /// The name, only if it is written in the reader's sentence exactly and
    /// isn't somebody the Book already knows. A proposal, never a record.
    static func parsedName(_ response: String?, sentence: String, excluded: Set<String>) -> String? {
        guard let line = response?.split(whereSeparator: \.isNewline).first.map(String.init),
              let range = line.range(of: "NAME:", options: .caseInsensitive) else { return nil }
        let name = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".\"\u{201C}\u{201D}"))
        guard !name.isEmpty, name.count <= 40, name.split(separator: " ").count <= 4,
              Neighbours.containsWholeWord(name, in: sentence, caseSensitive: true),
              !excluded.contains(where: { $0.lowercased() == name.lowercased() }) else { return nil }
        return name
    }

    /// Two references, one Neighbour? Only a yes the reader then confirms.
    static func sameOnePrompt(_ first: String, _ second: String) -> (prompt: String, instructions: String) {
        let prompt = """
        A reader wrote these two sentences on different days:
        1. "\(first)"
        2. "\(second)"

        Are they about the same particular thing, animal or place? Answer SAME or DIFFERENT and nothing else.
        """
        return (prompt, "You answer with exactly one word.")
    }

    static func parsedSame(_ response: String?) -> Bool? {
        let word = response?.uppercased() ?? ""
        if word.contains("DIFFERENT") { return false }
        if word.contains("SAME") { return true }
        return nil
    }
}

// MARK: - On the map

/// Every Neighbour that knows where it lives, at the spot its founding Page
/// was written. A Neighbour whose founding Page had no coordinates (most
/// things indoors) isn't drawn rather than guessed at.
enum NeighboursAtlasLayer: AtlasLayerSource {
    static let layer = AtlasLayerID("neighbours")
    static let title = "The Neighbours"
    static let note = "Everything out there that turned into somebody, where you first found it."
    static let glyph = "house.and.flag"
    static let isOnByDefault = true

    static func glyph(for neighbour: Neighbour) -> String {
        switch neighbour.status {
        case .gone: return "circle.dotted"
        case .resting: return "moon.zzz.fill"
        case .living: break
        }
        switch neighbour.kind {
        case .place: return "signpost.right.fill"
        case .creature: return "pawprint.fill"
        case .thing: return "sparkle"
        }
    }

    static func marks(from sources: AtlasSources) -> [AtlasMark] {
        Neighbours.register(days: sources.days).compactMap { neighbour in
            guard let latitude = neighbour.latitude, let longitude = neighbour.longitude else { return nil }
            var detail = [Neighbours.line(for: neighbour, days: sources.days, now: sources.now, calendar: sources.calendar)]
            if let sentence = neighbour.foundingSentence {
                detail.append("\u{201C}\(sentence)\u{201D}")
            }
            let weight: Int
            switch neighbour.status {
            case .living: weight = 60 + min(neighbour.pageIDs.count, 30)
            case .resting: weight = 40
            case .gone: weight = 20
            }
            return AtlasMark(
                id: "neighbours:\(neighbour.slug)",
                layer: layer,
                latitude: latitude,
                longitude: longitude,
                title: Neighbours.capitalized(neighbour.name),
                subtitle: neighbour.status == .gone ? "Gone" : (neighbour.status == .resting ? "Resting" : nil),
                glyph: glyph(for: neighbour),
                detail: detail,
                weight: weight
            )
        }
    }
}

// MARK: - Who lives here (the printed roll)

/// One line of the roll: a Neighbour as it stood at the end of a printed
/// period. Facts only, each from a Page.
struct NeighbourRollEntry: Codable, Equatable {
    var slug: String
    var name: String
    var lines: [String]
    var status: NeighbourStatus
    var foundedAt: Date
}

extension Neighbours {
    /// Everyone who lived here by `end`: the living, the resting, and the
    /// ones who went in the period. Neighbours gone before `start` were
    /// already said goodbye to in an earlier book.
    static func roll(days: [BookDay], start: Date, end: Date, calendar: Calendar = .current) -> [NeighbourRollEntry] {
        let pages = allPages(in: days)
        let dates = Dictionary(pages.map { ($0.id, $0.createdAt) }, uniquingKeysWith: { first, _ in first })
        var standing: [Neighbour] = []
        for neighbour in register(days: days) where neighbour.foundedAt <= end {
            // A book bound late still tells the period as it was: a change
            // after `end` hadn't happened yet.
            var asItWas = neighbour
            if let changed = neighbour.statusChangedAt, changed > end {
                asItWas.status = .living
                asItWas.statusChangedAt = nil
            }
            if asItWas.status == .gone, let gone = asItWas.statusChangedAt, gone < start { continue }
            standing.append(asItWas)
        }
        standing.sort { $0.foundedAt == $1.foundedAt ? $0.slug < $1.slug : $0.foundedAt < $1.foundedAt }
        return standing
            .map { (neighbour: Neighbour) -> NeighbourRollEntry in
                var lines: [String] = []
                let came = "Came in \(monthYear(neighbour.foundedAt, calendar: calendar))."
                if let working = neighbour.working, let deed = namingWorkings[working]?.deed {
                    lines.append("\(came) \(deed)")
                } else {
                    lines.append(came)
                }
                let onPages = neighbour.pageIDs.filter { (dates[$0] ?? .distantFuture) <= end }
                if onPages.count > 1 {
                    let last = onPages.compactMap { dates[$0] }.max() ?? neighbour.lastSeen
                    lines.append("On \(onPages.count <= 20 ? DeedChronicle.number(onPages.count) : String(onPages.count)) of your Pages. The last was in \(month(last, calendar: calendar)).")
                }
                if !neighbour.formerNames.isEmpty {
                    lines.append("Called \(neighbour.formerNames.joined(separator: ", then ")) before.")
                }
                switch neighbour.status {
                case .gone:
                    lines.append("Gone in \(monthYear(neighbour.statusChangedAt ?? end, calendar: calendar)).")
                case .resting:
                    lines.append("Resting since \(monthYear(neighbour.statusChangedAt ?? end, calendar: calendar)).")
                case .living:
                    break
                }
                if let sentence = neighbour.foundingSentence {
                    lines.append("You wrote: \u{201C}\(sentence)\u{201D}")
                }
                return NeighbourRollEntry(slug: neighbour.slug, name: capitalized(neighbour.name),
                                          lines: lines, status: neighbour.status, foundedAt: neighbour.foundedAt)
            }
    }
}
