import Foundation

/// Selects which kept pages are worthy of *binding* into an edition - the
/// edition's answer to `BookCurator`, which selects what *surfaces* on the
/// homescreen.
///
/// Without it, the monthly binder pours nearly every kept page into the book, so
/// a four-day month can swell to fifty pages - mostly repeated daily logs
/// (Inner Weather, Fuel Log, mood, body). The curator scores each page for
/// binding-worthiness, keeps the expressive and reader-authored pages whole,
/// sips only the strongest one or two of each mundane log, collapses exact
/// duplicates, and reports what it set aside so the edition can still account
/// for it in a single honest line.
///
/// Pure and deterministic: the same month always curates the same way.
enum EditionCurator {

    /// How much an edition cares about a kind of page.
    enum Tier: Int {
        /// The spine of the book - braids, souvenirs, letters, art, lore. Bound
        /// whenever they carry any content.
        case centerpiece = 60
        /// Cast, gossip, faculty, classes, festivals - bound when they carry
        /// enough weight to earn the page.
        case notable = 30
        /// Weather, fuel, mood, body, location - sampled, never bound wholesale.
        case mundane = 5
    }

    struct CuratedMonth: Equatable {
        /// The pages chosen for binding, in their original chronological order.
        var pages: [BookPage]
        /// Per-type tally of pages kept by the archive but left out of the book.
        var setAside: [BookPageType: Int]

        var keptCount: Int { pages.count }
        var setAsideTotal: Int { setAside.values.reduce(0, +) }

        /// A reader-facing accounting of what stayed in the drawer:
        /// "The month also held 9 weather notes, 6 fuel logs, and 4 moods,
        /// kept but not bound."
        var setAsideLine: String? {
            guard setAsideTotal > 0 else { return nil }
            let parts = setAside
                .sorted { left, right in
                    if left.value == right.value { return left.key.title < right.key.title }
                    return left.value > right.value
                }
                .prefix(5)
                .map { type, count in
                    EditionCurator.countPhrase(type: type, count: count)
                }
            let joined: String
            switch parts.count {
            case 0: return nil
            case 1: joined = parts[0]
            case 2: joined = "\(parts[0]) and \(parts[1])"
            default: joined = "\(parts.dropLast().joined(separator: ", ")), and \(parts.last ?? "")"
            }
            return "The month also held \(joined) - kept in the archive, but not bound here."
        }
    }

    static func countPhrase(type: BookPageType, count: Int) -> String {
        var title = type.title.lowercased()
        if title.hasPrefix("a ") {
            title.removeFirst(2)
        } else if title.hasPrefix("an ") {
            title.removeFirst(3)
        }
        let number = count == 1 ? "one" : "\(count)"
        return "\(number) \(title)\(count == 1 ? "" : "s")"
    }

    // MARK: Tunables

    /// At most this many of each mundane log type reach the book.
    static let mundaneSamplePerType = 2
    /// A notable page must clear this score (base + substance/media) to be bound.
    static let notableKeepThreshold = 34
    /// A sampled mundane page still has to carry this much above its floor.
    static let mundaneSubstanceFloor = 10
    /// Intimate logs stay in the private archive unless a future export option
    /// explicitly asks to bind them.
    static let defaultPrivateTypes: Set<BookPageType> = [.body, .fuel]

    static func isScrapbookPage(_ page: BookPage) -> Bool {
        page.sourceID == "pagewright"
            || page.tags.contains("pagewright")
            || page.tags.contains("scrapbook")
    }

    // MARK: Scoring

    static func tier(for type: BookPageType) -> Tier {
        switch type {
        case .bookOfYou, .souvenir, .letter, .aboutYou, .diary, .lore,
             .illustration, .illuminatedPhoto, .enchantment, .narrativeOS,
             .theBleed, .marginsAtlas, .bookRemembered, .twoReadings,
             .wonderCompass, .askTheBook:
            return .centerpiece
        case .mood, .body, .fuel, .weather, .rest, .location,
             .calendar, .inventory, .helpTips, .welcome, .bookJump, .todaysSky:
            return .mundane
        default:
            // Cast, gossip, faculty, classes, festivals, anchors, the rest.
            return .notable
        }
    }

    /// How much a single page earns its place between the covers.
    static func bindingScore(_ page: BookPage) -> Int {
        var score = tier(for: page.type).rawValue
        let body = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if isScrapbookPage(page) { score += 35 }                      // composed pages should bind as pages
        if page.usedInBookOfYou { score += 40 }                       // it earned a night's braid
        if page.origin == .userAuthored && !body.isEmpty { score += 20 } // the reader wrote it
        score += min(30, body.count / 20)                             // substance, capped
        if !page.mediaAssets.isEmpty { score += 25 }                  // it carries a plate
        if page.tags.contains("world-event") ||
            page.tags.contains(where: { $0.hasPrefix("event:") }) {
            score += 15                                               // a world event touched it
        }
        return score
    }

    /// A weekend accounting of what the Bindery sewed into this month's edition
    /// over the past seven days. Nil until at least two pages made the cut —
    /// a signature is a gathering of sheets, not a single leaf.
    static func weeklySignatureLine(monthPages: [BookPage], now: Date = Date()) -> String? {
        guard !monthPages.isEmpty else { return nil }
        let curated = curate(monthPages, now: now)
        let weekStart = now.addingTimeInterval(-7 * 86_400)
        let sewn = curated.pages.filter { $0.createdAt >= weekStart && $0.createdAt <= now }
        guard sewn.count >= 2 else { return nil }
        let parts = Dictionary(grouping: sewn, by: \.type)
            .mapValues(\.count)
            .sorted { left, right in
                if left.value == right.value { return left.key.title < right.key.title }
                return left.value > right.value
            }
            .prefix(3)
            .map { countPhrase(type: $0.key, count: $0.value) }
        let joined: String
        switch parts.count {
        case 1: joined = parts[0]
        case 2: joined = "\(parts[0]) and \(parts[1])"
        default: joined = "\(parts[0]), \(parts[1]), and \(parts[2])"
        }
        let month = now.formatted(.dateTime.month(.wide))
        return "This week the Bindery sewed \(sewn.count) pages into \(month)\u{2019}s edition: \(joined)."
    }

    // MARK: Curation

    /// Curate a month's pages. `pages` is expected in chronological order; the
    /// kept set preserves that order.
    static func curate(_ pages: [BookPage], now: Date = Date()) -> CuratedMonth {
        // First decide which mundane logs survive the sampling - keep only the
        // strongest one or two of each type, and only if they carry substance.
        var mundaneKeepIDs: Set<String> = []
        let mundaneByType = Dictionary(grouping: pages.filter { tier(for: $0.type) == .mundane }, by: \.type)
        for (_, group) in mundaneByType {
            let ranked = group.sorted { bindingScore($0) > bindingScore($1) }
            for page in ranked.prefix(mundaneSamplePerType)
            where bindingScore(page) >= Tier.mundane.rawValue + mundaneSubstanceFloor {
                mundaneKeepIDs.insert(page.id)
            }
        }

        var kept: [BookPage] = []
        var setAside: [BookPageType: Int] = [:]
        var seenBodies: Set<String> = []

        for page in pages {
            let body = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasContent = !body.isEmpty || !page.mediaAssets.isEmpty || page.usedInBookOfYou
            if defaultPrivateTypes.contains(page.type) {
                if hasContent { setAside[page.type, default: 0] += 1 }
                continue
            }

            let keep: Bool
            switch tier(for: page.type) {
            case .centerpiece:
                keep = hasContent
            case .notable:
                keep = hasContent && bindingScore(page) >= notableKeepThreshold
            case .mundane:
                keep = mundaneKeepIDs.contains(page.id)
            }

            guard keep else {
                setAside[page.type, default: 0] += 1
                continue
            }

            // Collapse the same text bound twice (templated duplicates).
            if !body.isEmpty, !seenBodies.insert("\(page.type.rawValue)|\(body)").inserted {
                setAside[page.type, default: 0] += 1
                continue
            }

            kept.append(page)
        }

        return CuratedMonth(pages: kept, setAside: setAside)
    }
}
