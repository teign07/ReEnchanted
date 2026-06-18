import Foundation

// MARK: - Search the Stacks
//
// Unified search across everything the living archive holds: kept pages,
// cast, anchors, memories, favors, and the reference library. Understands
// more than keywords — Glow tiers, mood vocabularies, "about <name>", and
// day-correlation ("what did I keep when I was tired?").

struct StacksSearchResult: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case keptPage
        case castMember
        case anchor
        case memory
        case reference
        case elective
        case pageFamily

        var title: String {
            switch self {
            case .keptPage: return "Kept Pages"
            case .castMember: return "The Cast"
            case .anchor: return "Anchored Places"
            case .memory: return "What They Remember"
            case .reference: return "From the Library"
            case .elective: return "Favors"
            case .pageFamily: return "Page Families"
            }
        }

        var symbolName: String {
            switch self {
            case .keptPage: return "book.pages"
            case .castMember: return "person.crop.square"
            case .anchor: return "mappin.and.ellipse"
            case .memory: return "brain.head.profile"
            case .reference: return "books.vertical"
            case .elective: return "envelope.badge"
            case .pageFamily: return "square.stack"
            }
        }
    }

    var id: String
    var kind: Kind
    var title: String
    var snippet: String
    var dateLabel: String
    var score: Int
    var referenceID: String
}

struct StacksSearchDataset {
    var days: [BookDay] = []
    var entities: [NarrativeWorldEntity] = []
    var entityBeliefOffsets: [String: Int] = [:]
    var pageBeliefOffsets: [String: Int] = [:]
    var anchors: [AnchorRecord] = []
    var memories: [NarrativeEntityMemory] = []
    var electives: [UnwrittenElective] = []
    var references: [ReferenceSnippet] = []
}

struct StacksQuery: Equatable {
    var raw: String
    var terms: [String]
    var glowName: String?
    var moodKey: String?
    var wantsKeptCorrelation: Bool
    var pageTypeFilters: Set<BookPageType>
    var kindFilters: Set<StacksSearchResult.Kind>

    static let glowNames: [String] = [
        "glow barely there", "meager glow", "faint glow", "small glow",
        "warming glow", "steady glow", "clear glow", "bright glow",
        "radiant glow", "glow too full"
    ]

    static let moodLexicon: [String: [String]] = [
        "tired": ["tired", "exhausted", "drained", "weary", "sleepy", "depleted", "fatigued", "low energy", "worn out", "heavy-limbed"],
        "bright": ["happy", "bright", "joyful", "glad", "sunny", "delighted", "cheerful"],
        "heavy": ["sad", "heavy", "down", "blue", "grieving", "lonely"],
        "restless": ["anxious", "restless", "nervous", "worried", "stormy", "uneasy", "stressed"],
        "calm": ["calm", "quiet", "peaceful", "still", "soft", "settled"],
        "rainy": ["rain", "rainy", "storm", "drizzle", "fog", "overcast"]
    ]

    static let stopWords: Set<String> = [
        "show", "me", "my", "find", "what", "did", "i", "was", "when", "the",
        "a", "an", "about", "everything", "with", "things", "page", "pages",
        "of", "for", "that", "search", "all", "any", "some", "and", "in", "on"
    ]

    static func parse(_ raw: String) -> StacksQuery {
        var lowered = raw.lowercased()
            .replacingOccurrences(of: "[?!.,;:\"']", with: " ", options: .regularExpression)

        var glowName: String?
        for name in glowNames where lowered.contains(name) {
            glowName = name
            lowered = lowered.replacingOccurrences(of: name, with: " ")
            break
        }

        var moodKey: String?
        outer: for (key, synonyms) in moodLexicon.sorted(by: { $0.key < $1.key }) {
            for synonym in synonyms where lowered.contains(synonym) {
                moodKey = key
                break outer
            }
        }

        let wantsKept = lowered.contains("keep") || lowered.contains("kept")
        let wantsKeptCorrelation = wantsKept && moodKey != nil

        var pageTypes: Set<BookPageType> = []
        var kinds: Set<StacksSearchResult.Kind> = []
        let typeWords: [(String, Set<BookPageType>)] = [
            ("photo", [.illuminatedPhoto, .enchantment]),
            ("picture", [.illuminatedPhoto, .enchantment]),
            ("mission", [.wonderCompass]),
            ("souvenir", [.souvenir]),
            ("braid", [.bookOfYou]),
            ("book of you", [.bookOfYou]),
            ("letter", [.letter]),
            ("story", [.narrativeOS, .bookConnections]),
            ("gossip", [.gossip]),
            ("diary", [.diary])
        ]
        for (word, types) in typeWords where lowered.contains(word) {
            pageTypes.formUnion(types)
        }
        if lowered.contains("place") || lowered.contains("anchor") || lowered.contains("room") {
            kinds.insert(.anchor)
        }
        if lowered.contains("cast") || lowered.contains("character") {
            kinds.insert(.castMember)
        }

        let terms = lowered
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !stopWords.contains($0) }

        return StacksQuery(
            raw: raw,
            terms: Array(Set(terms)).sorted(),
            glowName: glowName,
            moodKey: moodKey,
            wantsKeptCorrelation: wantsKeptCorrelation,
            pageTypeFilters: pageTypes,
            kindFilters: kinds
        )
    }
}

enum StacksSearchEngine {
    static func search(
        _ raw: String,
        in dataset: StacksSearchDataset,
        extraTerms: [String] = [],
        now: Date = Date(),
        limit: Int = 40
    ) -> [StacksSearchResult] {
        var query = StacksQuery.parse(raw)
        query.terms = Array(Set(query.terms + extraTerms.map { $0.lowercased() })).sorted()
        guard !query.terms.isEmpty || query.glowName != nil || query.moodKey != nil || !query.pageTypeFilters.isEmpty || !query.kindFilters.isEmpty else {
            return []
        }

        var results: [StacksSearchResult] = []
        results += searchKeptPages(query, dataset: dataset, now: now)
        results += searchEntities(query, dataset: dataset)
        results += searchAnchors(query, dataset: dataset)
        results += searchMemories(query, dataset: dataset)
        results += searchElectives(query, dataset: dataset)
        results += searchReferences(query, dataset: dataset)
        results += searchPageFamilies(query, dataset: dataset)

        return Array(
            results
                .filter { $0.score > 0 }
                .sorted { left, right in
                    if left.score == right.score {
                        return left.id < right.id
                    }
                    return left.score > right.score
                }
                .prefix(limit)
        )
    }

    // MARK: Kept pages (with mood day-correlation)

    private static func searchKeptPages(_ query: StacksQuery, dataset: StacksSearchDataset, now: Date) -> [StacksSearchResult] {
        let moodSynonyms = query.moodKey.flatMap { StacksQuery.moodLexicon[$0] } ?? []
        var moodDayIDs: Set<String> = []
        if query.wantsKeptCorrelation {
            for day in dataset.days {
                let stateText = day.pages
                    .filter { [.mood, .body, .fuel, .rest, .diary].contains($0.type) }
                    .map { "\($0.promptText) \($0.userInput) \($0.tags.joined(separator: " "))" }
                    .joined(separator: " ")
                    .lowercased()
                if moodSynonyms.contains(where: { stateText.contains($0) }) {
                    moodDayIDs.insert(day.id)
                }
            }
        }

        var results: [StacksSearchResult] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        for day in dataset.days {
            for page in day.pages {
                if !query.pageTypeFilters.isEmpty, !query.pageTypeFilters.contains(page.type) {
                    continue
                }
                let haystackTitle = "\(page.type.title) \(page.promptText) \(page.tags.joined(separator: " "))".lowercased()
                let haystackBody = page.userInput.lowercased()
                var score = 0
                var matchedTerm: String?
                for term in query.terms {
                    if haystackTitle.contains(term) {
                        score += 6
                        matchedTerm = matchedTerm ?? term
                    }
                    if haystackBody.contains(term) {
                        score += 4
                        matchedTerm = matchedTerm ?? term
                    }
                }
                if !query.wantsKeptCorrelation {
                    for synonym in moodSynonyms where haystackTitle.contains(synonym) || haystackBody.contains(synonym) {
                        score += 4
                        matchedTerm = matchedTerm ?? synonym
                    }
                }
                var correlated = false
                if query.wantsKeptCorrelation, moodDayIDs.contains(day.id) {
                    score += 10
                    correlated = true
                }
                if query.terms.isEmpty, !query.pageTypeFilters.isEmpty,
                   query.pageTypeFilters.contains(page.type) {
                    score += 5
                }
                guard score > 0 else { continue }

                let age = now.timeIntervalSince(page.createdAt)
                if age < 2 * 86_400 { score += 6 } else if age < 7 * 86_400 { score += 3 } else if age < 30 * 86_400 { score += 1 }

                let snippet: String
                if correlated, query.terms.isEmpty {
                    snippet = "Kept on a \(query.moodKey ?? "matching") day. \(page.userInput.bookPreviewSentenceLimit(1))"
                } else {
                    snippet = snippetAround(matchedTerm, in: page.userInput.isEmpty ? page.promptText : page.userInput)
                }
                let title = page.type == .bookOfYou
                    ? BraidPageDetails.details(for: page).title
                    : page.type.title
                results.append(StacksSearchResult(
                    id: "page-\(page.id)",
                    kind: .keptPage,
                    title: title,
                    snippet: snippet,
                    dateLabel: formatter.string(from: page.createdAt),
                    score: score,
                    referenceID: page.id
                ))
            }
        }
        return results
    }

    // MARK: Cast (with Glow tiers)

    private static func searchEntities(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.entities.compactMap { entity in
            let adjusted = max(0, min(100, entity.belief + (dataset.entityBeliefOffsets[entity.id] ?? 0)))
            let glow = BeliefLexicon.glowName(for: adjusted)
            var score = 0
            let name = entity.name.lowercased()
            let texture = (entity.traits + entity.tags + entity.beliefs + entity.goals + [entity.chapter ?? ""]).joined(separator: " ").lowercased()
            for term in query.terms {
                if name.contains(term) { score += 12 }
                if texture.contains(term) { score += 4 }
            }
            if let glowName = query.glowName, glow.lowercased() == glowName {
                score += 20
            }
            if query.kindFilters.contains(.castMember), score == 0, query.terms.isEmpty {
                score += 4
            }
            guard score > 0 else { return nil }
            let chapterNote = entity.chapter.map { " · Chapter \($0)" } ?? ""
            return StacksSearchResult(
                id: "entity-\(entity.id)",
                kind: .castMember,
                title: entity.name,
                snippet: "\(glow)\(chapterNote). \(entity.beliefs.first ?? entity.goals.first ?? entity.kind.rawValue)",
                dateLabel: "",
                score: score,
                referenceID: entity.id
            )
        }
    }

    private static func searchAnchors(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.anchors.compactMap { anchor in
            let haystack = "\(anchor.name) \(anchor.playerWords) \(anchor.outerStacksRoom) \(anchor.fae) \(anchor.localRule)".lowercased()
            var score = 0
            for term in query.terms where haystack.contains(term) {
                score += anchor.name.lowercased().contains(term) ? 10 : 5
            }
            if query.kindFilters.contains(.anchor), query.terms.isEmpty {
                score += 6
            }
            guard score > 0 else { return nil }
            return StacksSearchResult(
                id: "anchor-\(anchor.id)",
                kind: .anchor,
                title: anchor.name,
                snippet: "\(anchor.kind.title) Anchor · \(anchor.visitCount) visit\(anchor.visitCount == 1 ? "" : "s"). \(String(anchor.playerWords.prefix(110)))",
                dateLabel: anchor.lastVisited == "none" ? "never visited" : "last \(anchor.lastVisited)",
                score: score,
                referenceID: anchor.id
            )
        }
    }

    private static func searchMemories(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return dataset.memories.compactMap { memory in
            let haystack = memory.summary.lowercased()
            var score = 0
            var matched: String?
            for term in query.terms where haystack.contains(term) {
                score += 5
                matched = matched ?? term
            }
            guard score > 0 else { return nil }
            return StacksSearchResult(
                id: "memory-\(memory.id)",
                kind: .memory,
                title: memory.entityID.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " "),
                snippet: snippetAround(matched, in: memory.summary),
                dateLabel: formatter.string(from: memory.createdAt),
                score: score,
                referenceID: memory.id
            )
        }
    }

    private static func searchElectives(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.electives.compactMap { elective in
            let haystack = "\(elective.title) \(elective.ask) \(elective.characterName)".lowercased()
            var score = 0
            for term in query.terms where haystack.contains(term) {
                score += 6
            }
            guard score > 0 else { return nil }
            return StacksSearchResult(
                id: "elective-\(elective.id)",
                kind: .elective,
                title: elective.title,
                snippet: "\(elective.isActive ? "Active" : "Completed") · for \(elective.characterName). \(String(elective.ask.prefix(110)))",
                dateLabel: "",
                score: score,
                referenceID: elective.id
            )
        }
    }

    private static func searchReferences(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.references.compactMap { snippet in
            let titleText = "\(snippet.title) \(snippet.tags.joined(separator: " "))".lowercased()
            let bodyText = snippet.body.lowercased()
            var score = 0
            var matched: String?
            for term in query.terms {
                if titleText.contains(term) {
                    score += 7
                    matched = matched ?? term
                }
                if bodyText.contains(term) {
                    score += 3
                    matched = matched ?? term
                }
            }
            guard score > 0 else { return nil }
            return StacksSearchResult(
                id: "reference-\(snippet.id)",
                kind: .reference,
                title: snippet.title,
                snippet: snippetAround(matched, in: snippet.body),
                dateLabel: snippet.sourceID == "wonder-compass" ? "Wonder Compass" : "Lore",
                score: score,
                referenceID: snippet.id
            )
        }
    }

    private static func searchPageFamilies(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        guard let glowName = query.glowName else { return [] }
        return BookPageSourceRegistry.activeSources.compactMap { source in
            let base = BookPageSourceRegistry.defaultBelief(for: source)
            let adjusted = max(0, min(100, base + (dataset.pageBeliefOffsets[source.id] ?? 0)))
            guard BeliefLexicon.glowName(for: adjusted).lowercased() == glowName else { return nil }
            return StacksSearchResult(
                id: "family-\(source.id)",
                kind: .pageFamily,
                title: source.title,
                snippet: "\(BeliefLexicon.glowName(for: adjusted)) · \(source.note)",
                dateLabel: "",
                score: 14,
                referenceID: source.id
            )
        }
    }

    private static func snippetAround(_ term: String?, in text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        guard let term,
              let range = normalized.lowercased().range(of: term) else {
            return String(normalized.prefix(130))
        }
        let start = normalized.index(range.lowerBound, offsetBy: -55, limitedBy: normalized.startIndex) ?? normalized.startIndex
        let end = normalized.index(range.upperBound, offsetBy: 75, limitedBy: normalized.endIndex) ?? normalized.endIndex
        let prefix = start == normalized.startIndex ? "" : "…"
        let suffix = end == normalized.endIndex ? "" : "…"
        return prefix + normalized[start..<end].trimmingCharacters(in: .whitespaces) + suffix
    }
}
