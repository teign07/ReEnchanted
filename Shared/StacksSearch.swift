import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

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
        case selfFact
        case narrativeEvent
        case facultyEntry

        var title: String {
            switch self {
            case .keptPage: return "Kept Pages"
            case .castMember: return "The Cast"
            case .anchor: return "Anchored Places"
            case .memory: return "What They Remember"
            case .reference: return "From the Library"
            case .elective: return "Favors"
            case .pageFamily: return "Page Families"
            case .selfFact: return "About You"
            case .narrativeEvent: return "Story Threads"
            case .facultyEntry: return "Faculty Notes"
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
            case .selfFact: return "person.text.rectangle"
            case .narrativeEvent: return "sparkles.rectangle.stack"
            case .facultyEntry: return "doc.text.magnifyingglass"
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
    var selfFacts: [SelfFact] = []
    var narrativeEvents: [NarrativeEvent] = []
    var facultyEntries: [FacultyEntry] = []
}

struct StacksSearchDocument: Identifiable, Equatable {
    var id: String
    var kind: StacksSearchResult.Kind
    var title: String
    var body: String
    var dateLabel: String
    var referenceID: String
    var relatedIDs: Set<String> = []

    var searchableText: String {
        [kind.title, title, body].joined(separator: "\n")
    }
}

struct StacksSearchLink: Equatable {
    enum Kind: String {
        case sameDay
        case sourcePage
        case sourceFamily
        case entity
        case tag
        case source
    }

    var fromID: String
    var toID: String
    var kind: Kind
    var weight: Int
}

protocol StacksSemanticScoring {
    var modelID: String { get }
    func similarity(between query: String, and document: String) -> Double?
}

#if canImport(NaturalLanguage)
struct NaturalLanguageStacksEmbeddingScorer: StacksSemanticScoring {
    let language: NLLanguage
    let modelID: String

    init?(language: NLLanguage = .english) {
        guard NLEmbedding.sentenceEmbedding(for: language) != nil else { return nil }
        self.language = language
        self.modelID = "NaturalLanguage.sentenceEmbedding.\(language.rawValue)"
    }

    func similarity(between query: String, and document: String) -> Double? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else { return nil }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDocument = document.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !trimmedDocument.isEmpty else { return nil }
        let distance = embedding.distance(between: trimmedQuery, and: trimmedDocument)
        guard distance.isFinite else { return nil }
        return max(0, min(1, 1 - distance))
    }
}
#endif

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
    static let semanticScoreThreshold = 0.24

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

    static func hybridSearch(
        _ raw: String,
        in dataset: StacksSearchDataset,
        extraTerms: [String] = [],
        now: Date = Date(),
        limit: Int = 40,
        semanticScorer: StacksSemanticScoring? = defaultSemanticScorer()
    ) -> [StacksSearchResult] {
        let lexicalResults = search(raw, in: dataset, extraTerms: extraTerms, now: now, limit: limit)
        guard let semanticScorer else { return lexicalResults }

        let graph = buildSearchGraph(from: dataset, now: now)
        var resultsByID = Dictionary(uniqueKeysWithValues: lexicalResults.map { ($0.id, $0) })
        let queryText = ([raw] + extraTerms).joined(separator: " ")
        let lexicalIDs = Set(lexicalResults.map(\.id))

        for document in graph.documents {
            guard let similarity = semanticScorer.similarity(between: queryText, and: document.searchableText),
                  similarity >= semanticScoreThreshold else { continue }
            let semanticScore = Int((similarity * 34).rounded())
            let connectionBoost = connectionBoost(for: document.id, links: graph.links, alreadyMatched: lexicalIDs)
            let score = semanticScore + connectionBoost
            guard score > 0 else { continue }

            if var existing = resultsByID[document.id] {
                existing.score += score
                resultsByID[document.id] = existing
            } else {
                resultsByID[document.id] = StacksSearchResult(
                    id: document.id,
                    kind: document.kind,
                    title: document.title,
                    snippet: semanticSnippet(for: raw, document: document, similarity: similarity),
                    dateLabel: document.dateLabel,
                    score: score,
                    referenceID: document.referenceID
                )
            }
        }

        return Array(
            resultsByID.values
                .filter { $0.score > 0 }
                .sorted { left, right in
                    if left.score == right.score { return left.id < right.id }
                    return left.score > right.score
                }
                .prefix(limit)
        )
    }

    static func buildSearchGraph(from dataset: StacksSearchDataset, now: Date = Date()) -> (documents: [StacksSearchDocument], links: [StacksSearchLink]) {
        var documents: [StacksSearchDocument] = []
        var links: [StacksSearchLink] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        for day in dataset.days {
            let dayDocumentID = "day-\(day.id)"
            let dayBody = day.pages.map { "\($0.type.title): \($0.promptText) \($0.userInput) \($0.playerReply) \($0.tags.joined(separator: " "))" }.joined(separator: "\n")
            documents.append(StacksSearchDocument(
                id: dayDocumentID,
                kind: .memory,
                title: "Day \(day.id)",
                body: dayBody,
                dateLabel: formatter.string(from: day.date),
                referenceID: day.id
            ))
            for page in day.pages {
                let title = page.type == .bookOfYou ? BraidPageDetails.details(for: page).title : page.type.title
                let pageDocumentID = "page-\(page.id)"
                let body = "\(page.promptText)\n\(page.userInput)\n\(page.playerReply)\nTags: \(page.tags.joined(separator: ", "))\nSource: \(page.sourceID)"
                documents.append(StacksSearchDocument(
                    id: pageDocumentID,
                    kind: .keptPage,
                    title: title,
                    body: body,
                    dateLabel: formatter.string(from: page.createdAt),
                    referenceID: page.id,
                    relatedIDs: Set([dayDocumentID, "source-\(page.sourceID)"] + page.tags.map { "tag-\($0.lowercased())" })
                ))
                links.append(StacksSearchLink(fromID: pageDocumentID, toID: dayDocumentID, kind: .sameDay, weight: 4))
                links.append(StacksSearchLink(fromID: pageDocumentID, toID: "source-\(page.sourceID)", kind: .sourceFamily, weight: 3))
                for tag in page.tags {
                    links.append(StacksSearchLink(fromID: pageDocumentID, toID: "tag-\(tag.lowercased())", kind: .tag, weight: 2))
                }
            }
        }

        for entity in dataset.entities {
            let adjusted = max(0, min(100, entity.belief + (dataset.entityBeliefOffsets[entity.id] ?? 0)))
            documents.append(StacksSearchDocument(
                id: "entity-\(entity.id)",
                kind: .castMember,
                title: entity.name,
                body: ([BeliefLexicon.glowName(for: adjusted), entity.kind.rawValue, entity.chapter ?? ""] + entity.traits + entity.tags + entity.beliefs + entity.goals + [entity.unwrittenInterest ?? ""]).joined(separator: "\n"),
                dateLabel: "",
                referenceID: entity.id,
                relatedIDs: ["entity-\(entity.id)"]
            ))
        }

        for anchor in dataset.anchors {
            documents.append(StacksSearchDocument(
                id: "anchor-\(anchor.id)",
                kind: .anchor,
                title: anchor.name,
                body: "\(anchor.kind.title)\n\(anchor.playerWords)\n\(anchor.outerStacksRoom)\n\(anchor.fae)\n\(anchor.localRule)",
                dateLabel: anchor.lastVisited == "none" ? "never visited" : "last \(anchor.lastVisited)",
                referenceID: anchor.id
            ))
        }

        for memory in dataset.memories {
            let documentID = "memory-\(memory.id)"
            documents.append(StacksSearchDocument(
                id: documentID,
                kind: .memory,
                title: titleFromSlug(memory.entityID),
                body: "\(memory.summary)\nTags: \(memory.tags.joined(separator: ", "))",
                dateLabel: formatter.string(from: memory.createdAt),
                referenceID: memory.id,
                relatedIDs: Set(["entity-\(memory.entityID)"] + [memory.sourcePageID].compactMap { $0 }.map { "page-\($0)" })
            ))
            links.append(StacksSearchLink(fromID: documentID, toID: "entity-\(memory.entityID)", kind: .entity, weight: 5))
            if let sourcePageID = memory.sourcePageID {
                links.append(StacksSearchLink(fromID: documentID, toID: "page-\(sourcePageID)", kind: .sourcePage, weight: 7))
            }
        }

        for event in dataset.narrativeEvents {
            let documentID = "event-\(event.id)"
            documents.append(StacksSearchDocument(
                id: documentID,
                kind: .narrativeEvent,
                title: event.kind.rawValue.split(separator: "-").map(String.init).joined(separator: " ").capitalized,
                body: "\(event.summary)\nTags: \(event.tags.joined(separator: ", "))",
                dateLabel: formatter.string(from: event.createdAt),
                referenceID: event.id,
                relatedIDs: Set([event.sourcePageID].compactMap { $0 }.map { "page-\($0)" })
            ))
            if let sourcePageID = event.sourcePageID {
                links.append(StacksSearchLink(fromID: documentID, toID: "page-\(sourcePageID)", kind: .sourcePage, weight: 6))
            }
        }

        for fact in dataset.selfFacts where fact.usePermission != .doNotUse {
            documents.append(StacksSearchDocument(
                id: "selfFact-\(fact.id)",
                kind: .selfFact,
                title: fact.question,
                body: "\(fact.answer)\n\(fact.bookTranslation)\nTags: \(fact.tags.joined(separator: ", "))",
                dateLabel: formatter.string(from: fact.createdAt),
                referenceID: fact.id
            ))
        }

        for entry in dataset.facultyEntries {
            let documentID = "faculty-\(entry.id)"
            documents.append(StacksSearchDocument(
                id: documentID,
                kind: .facultyEntry,
                title: entry.windowName,
                body: "\(entry.kind.chartTitle)\n\(entry.rawText)\nTags: \(entry.tags.joined(separator: ", "))",
                dateLabel: formatter.string(from: entry.createdAt),
                referenceID: entry.id,
                relatedIDs: Set([entry.sourcePageID].compactMap { $0 }.map { "page-\($0)" })
            ))
            if let sourcePageID = entry.sourcePageID {
                links.append(StacksSearchLink(fromID: documentID, toID: "page-\(sourcePageID)", kind: .sourcePage, weight: 5))
            }
        }

        for elective in dataset.electives {
            documents.append(StacksSearchDocument(
                id: "elective-\(elective.id)",
                kind: .elective,
                title: elective.title,
                body: "\(elective.characterName)\n\(elective.ask)\n\(elective.practiceShape)",
                dateLabel: elective.isActive ? "Active" : "Completed",
                referenceID: elective.id
            ))
        }

        for snippet in dataset.references {
            documents.append(StacksSearchDocument(
                id: "reference-\(snippet.id)",
                kind: .reference,
                title: snippet.title,
                body: "\(snippet.body)\nTags: \(snippet.tags.joined(separator: ", "))",
                dateLabel: snippet.sourceID == "wonder-compass" ? "Wonder Compass" : "Lore",
                referenceID: snippet.id
            ))
        }

        for source in BookPageSourceRegistry.activeSources {
            documents.append(StacksSearchDocument(
                id: "family-\(source.id)",
                kind: .pageFamily,
                title: source.title,
                body: "\(source.note)\n\(source.type.title)\n\(source.id)",
                dateLabel: "",
                referenceID: source.id,
                relatedIDs: ["source-\(source.id)"]
            ))
        }

        return (documents, links)
    }

    private static func semanticSnippet(for raw: String, document: StacksSearchDocument, similarity: Double) -> String {
        let query = StacksQuery.parse(raw)
        let matched = query.terms.first { document.body.lowercased().contains($0) }
        let base = snippetAround(matched, in: document.body)
        let percent = Int((similarity * 100).rounded())
        return "Semantic match \(percent)%. \(base)"
    }

    private static func titleFromSlug(_ slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func connectionBoost(for documentID: String, links: [StacksSearchLink], alreadyMatched: Set<String>) -> Int {
        links.reduce(0) { boost, link in
            guard link.fromID == documentID || link.toID == documentID else { return boost }
            let otherID = link.fromID == documentID ? link.toID : link.fromID
            return alreadyMatched.contains(otherID) ? boost + link.weight : boost
        }
    }

    private static func defaultSemanticScorer() -> StacksSemanticScoring? {
        #if canImport(NaturalLanguage)
        return NaturalLanguageStacksEmbeddingScorer()
        #else
        return nil
        #endif
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

/// The recognition note: a just-kept page that rhymes with an older page
/// earns a line naming the shared word and when it first appeared. Fixed,
/// legible rule — a rare-enough word, old enough to feel like memory.
enum KeepEcho {
    struct Echo: Equatable {
        var sourcePageID: String
        var sharedWord: String
        var monthLine: String
        var line: String
    }

    /// A word must be at least this old to echo — recognition, not repetition.
    static let minimumAgeDays = 14
    /// A word appearing in more archive pages than this is too common to feel
    /// specific ("coffee" echoes nobody).
    static let maximumWordSpread = 4

    static func find(
        for input: String,
        pageID: String,
        in days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Echo? {
        let inputWords = Set(
            input.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
        )
        guard !inputWords.isEmpty else { return nil }

        let cutoff = now.addingTimeInterval(TimeInterval(-minimumAgeDays) * 86_400)
        let candidates = days.flatMap(\.capturedPages).filter { page in
            page.createdAt <= cutoff
                && !EditionCurator.defaultPrivateTypes.contains(page.type)
                && !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !candidates.isEmpty else { return nil }

        // How widely each input word is spread across the archive.
        var spread: [String: Int] = [:]
        var matches: [(page: BookPage, word: String)] = []
        for page in candidates {
            let pageWords = Set(
                page.userInput.lowercased()
                    .split { !$0.isLetter }
                    .map(String.init)
                    .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
            )
            for word in inputWords.intersection(pageWords) {
                spread[word, default: 0] += 1
                matches.append((page, word))
            }
        }

        let rare = matches.filter { spread[$0.word] ?? 0 <= maximumWordSpread }
        guard !rare.isEmpty else { return nil }

        // Longest shared word first (most specific), then oldest page.
        let ranked = rare.sorted {
            if $0.word.count != $1.word.count { return $0.word.count > $1.word.count }
            return $0.page.createdAt < $1.page.createdAt
        }
        let top = Array(ranked.prefix(3))
        let seed = KeepMarginalia.seed(for: pageID)
        let chosen = top[Int(seed % UInt64(top.count))]

        let month = chosen.page.createdAt.formatted(.dateTime.month(.wide))
        let sameYear = calendar.component(.year, from: chosen.page.createdAt)
            == calendar.component(.year, from: now)
        let year = calendar.component(.year, from: chosen.page.createdAt)
        let monthLine = sameYear ? "back in \(month)" : "in \(month) \(year)"

        let lines = [
            "You\u{2019}ve written about \u{201C}\(chosen.word)\u{201D} before — \(monthLine). The Book remembers.",
            "This rhymes with a page from \(monthLine) — the one about \u{201C}\(chosen.word)\u{201D}.",
            "The Stacks stirred: \u{201C}\(chosen.word)\u{201D} again, first pressed \(monthLine)."
        ]
        return Echo(
            sourcePageID: chosen.page.id,
            sharedWord: chosen.word,
            monthLine: monthLine,
            line: lines[Int((seed >> 16) % UInt64(lines.count))]
        )
    }

    static func note(from echo: Echo) -> KeepMarginalia.Note {
        KeepMarginalia.Note(
            castSlug: "the-book",
            castName: "The Book",
            assetName: "LabyrinthFaeBookSprite",
            line: echo.line
        )
    }
}
