import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - Search the Stacks
//
// Unified search across everything the living archive holds: kept pages,
// cast, anchors, memories, favors, and the reference library. Understands
// more than keywords: Glow tiers, mood vocabularies, "about <name>", and
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

// MARK: - Chat with the Book memory

/// The different kinds of truth the Book can encounter while consulting its
/// archive. They are deliberately not flattened into one confidence score:
/// something the reader wrote, a piece of Academy canon, and an old generated
/// story can all be relevant without being equally factual.
enum AskTheBookEvidenceAuthority: String, Equatable {
    case readerWords
    case importedEvidence
    case recordedFact
    case computedFinding
    case derivedMemory
    case canon
    case createdPage
    case priorConversation

    var promptLabel: String {
        switch self {
        case .readerWords: return "READER'S OWN WORDS"
        case .importedEvidence: return "IMPORTED REAL-WORLD EVIDENCE"
        case .recordedFact: return "RECORDED BOOK FACT"
        case .computedFinding: return "COMPUTED ARCHIVE FINDING"
        case .derivedMemory: return "DERIVED MEMORY OR EVENT"
        case .canon: return "ACADEMY OR COMPASS CANON"
        case .createdPage: return "CREATED STORY OR INTERPRETIVE PAGE"
        case .priorConversation: return "EARLIER READER MESSAGE"
        }
    }

    var readerLabel: String {
        switch self {
        case .readerWords: return "Your words"
        case .importedEvidence: return "Imported evidence"
        case .recordedFact: return "Recorded in the Book"
        case .computedFinding: return "A Book calculation"
        case .derivedMemory: return "A memory the Book formed"
        case .canon: return "From the shelves"
        case .createdPage: return "A created Page"
        case .priorConversation: return "An earlier conversation"
        }
    }

    var rankingBoost: Int {
        switch self {
        case .readerWords: return 14
        case .importedEvidence: return 12
        case .computedFinding: return 18
        case .recordedFact: return 8
        case .canon: return 6
        case .derivedMemory: return 3
        case .createdPage: return -2
        case .priorConversation: return -5
        }
    }
}

struct AskTheBookEvidence: Identifiable, Equatable {
    var id: String { result.id }
    var result: StacksSearchResult
    var authority: AskTheBookEvidenceAuthority
    var excerpt: String
    var fullText: String
    var mayQuote: Bool
    /// True when a created Page contains one or more separately identified
    /// reader atoms. The containing Page remains Book-authored.
    var hasReaderContributions: Bool = false
}

struct AskTheBookMemoryPacket: Equatable {
    enum InquiryKind: String, Equatable {
        case recall
        case pattern
        case calculation
    }

    var inquiryKind: InquiryKind
    var evidence: [AskTheBookEvidence]
    /// Number of records admitted to this query's permission-filtered search
    /// corpus. Exposed in the chat so a successful search cannot look like a
    /// generic model response.
    var searchedRecordCount: Int
    /// False only for legacy/test callers that did not run archive retrieval.
    /// A completed search with no matches is still a real whole-Book search.
    var searchedWholeBook: Bool

    static let empty = AskTheBookMemoryPacket(
        inquiryKind: .recall,
        evidence: [],
        searchedRecordCount: 0,
        searchedWholeBook: false
    )

    var promptSection: String {
        guard searchedWholeBook else {
            return "WHOLE-BOOK MEMORY:\nThe archive was not searched for this reply."
        }
        guard !evidence.isEmpty else {
            return """
            WHOLE-BOOK MEMORY:
            The Book searched the permitted archive and found no strong matching evidence.
            Say that plainly if the reader asked for a memory. Do not turn absence from the search into proof that something never happened.
            """
        }

        let blocks = evidence.enumerated().map { index, item in
            let quotationRule: String
            if item.authority == .createdPage, item.hasReaderContributions {
                quotationRule = "The Page body is the Book's. Only atoms explicitly labelled as the reader's own words, fiction choice, photograph, or recording belong to the reader. Quote only a labelled reader sentence."
            } else if item.mayQuote {
                quotationRule = "Quoting or closely echoing this source is allowed."
            } else {
                quotationRule = "Use this only as quiet context. Do not quote or expose its exact private wording."
            }
            return """
            EVIDENCE \(index + 1): \(item.authority.promptLabel)
            Title: \(item.result.title)
            Date: \(item.result.dateLabel.isEmpty ? "not dated" : item.result.dateLabel)
            Rule: \(quotationRule)
            \(item.excerpt)
            """
        }.joined(separator: "\n\n")

        let inquiryRule: String
        switch inquiryKind {
        case .recall:
            inquiryRule = "Answer the specific question from the strongest relevant evidence."
        case .pattern:
            inquiryRule = """
            The reader is asking about a pattern or change over time. Treat these as examples, not an exhaustive statistical sample.
            Name the number of distinct Pages or dates you are relying on. If fewer than two independent dates support a connection, call it a possibility, not a pattern.
            """
        case .calculation:
            inquiryRule = """
            The reader asked for a count or calculation. Use the computed archive finding exactly.
            Preserve its distinction between recorded days and all calendar days, including any coverage limitation. Do not replace the calculation with an estimate.
            """
        }

        return """
        WHOLE-BOOK MEMORY:
        \(inquiryRule)

        AUTHORITY RULES:
        - Reader words and imported evidence may support claims about the reader's real life.
        - Recorded facts may support only the fact they actually record.
        - Computed archive findings are deterministic summaries of the dated records supplied here. Keep their sample size, date range, and missing-data caveats attached to the answer.
        - Derived memories are leads and interpretations; do not present them as direct quotations or independent proof.
        - Canon answers questions about the Book's world, not what happened in the reader's physical life.
        - Created Pages are genuine narrative continuity inside the Book. Discuss their characters, choices, relationships, consequences, mysteries, and unfinished threads freely and specifically.
        - Keeping a Created Page does not make its prose the reader's. Inside a Created Page, only explicitly labelled reader words, fiction choices, photographs, and recordings belong to the reader.
        - Created Pages are not proof that their fictional events happened in the reader's physical life.
        - You may connect the reader's real Pages to fictional continuity when the connection is supported. Keep the crossing legible: say that a real Page "reminds you of Wicker" or "rhymes with a Story Page," not that Wicker physically performed the reader's action.
        - Earlier conversation evidence contains only the reader's old messages. Never reconstruct or treat an old Book answer as truth.
        - Never claim certainty beyond the supplied evidence. It is welcome to say "I couldn't find that" or "I don't have enough Pages to know yet."
        - Do not print evidence numbers in the reply. The page will show sources separately.

        \(blocks)
        """
    }
}

/// Retrieval is an app capability, not something Gemma can perform by wishing.
/// This layer makes that boundary enforceable: exact computed answers come from
/// Swift, and a generated answer that ignores required evidence is repaired
/// with a visible, factual archive opening.
enum AskTheBookAnswerGrounder {
    static func deterministicAnswer(
        for memory: AskTheBookMemoryPacket
    ) -> String? {
        guard memory.inquiryKind == .calculation,
              let finding = memory.evidence.first(where: {
                  $0.authority == .computedFinding
              }) else {
            return nil
        }
        return """
        The little brass abacus and I counted twice.

        \(finding.fullText)
        """
    }

    static func finalizeGenerated(
        _ generated: String,
        prompt: String,
        memory: AskTheBookMemoryPacket
    ) -> String {
        let answer = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard memory.searchedWholeBook, requiresArchiveAnswer(prompt, memory: memory) else {
            return answer
        }
        guard !memory.evidence.isEmpty else {
            return """
            I opened every permitted shelf I could search, but I couldn't find a strong matching record for that yet. I don't want to make up a memory just because the empty space looks inviting.
            """
        }

        if let finding = memory.evidence.first(where: {
            $0.authority == .computedFinding
        }) {
            let anchor = safeComputedAnchor(finding)
            if !containsPrimaryNumber(from: anchor, in: answer) {
                return """
                I opened the dated records before answering. \(anchor)

                \(answer)
                """
            }
            return answer
        }

        let strongest = memory.evidence[0]
        guard !visiblyUses(strongest, in: answer) else { return answer }
        let sourceLine: String
        if strongest.mayQuote {
            sourceLine = """
            I opened “\(strongest.result.title)”\(datedSuffix(strongest.result.dateLabel)). \(strongest.result.snippet)
            """
        } else {
            sourceLine = """
            I opened “\(strongest.result.title)”\(datedSuffix(strongest.result.dateLabel)) and held it as quiet context rather than pretending I remembered from nowhere.
            """
        }
        return "\(sourceLine)\n\n\(answer)"
    }

    private static func requiresArchiveAnswer(
        _ prompt: String,
        memory: AskTheBookMemoryPacket
    ) -> Bool {
        if memory.inquiryKind == .pattern || memory.inquiryKind == .calculation {
            return true
        }
        let lower = prompt.lowercased()
        let phrases = [
            "remember", "did i", "have i", "when did", "where did",
            "what happened", "my page", "my pages", "my book", "my logs",
            "since we", "last time", "first time", "ever told", "what do you know about me"
        ]
        return phrases.contains(where: lower.contains)
    }

    private static func safeComputedAnchor(_ evidence: AskTheBookEvidence) -> String {
        let stopPrefixes = [
            "dated pairings:", "matching dates:", "most recent dated entries:",
            "recorded places:"
        ]
        let lines = evidence.excerpt
            .split(separator: "\n")
            .map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        let safe = lines.prefix { line in
            !stopPrefixes.contains(where: line.lowercased().hasPrefix)
        }
        return safe.prefix(3).joined(separator: " ")
    }

    private static func containsPrimaryNumber(
        from anchor: String,
        in answer: String
    ) -> Bool {
        let number = anchor
            .split { !$0.isNumber }
            .map(String.init)
            .first(where: { !$0.isEmpty })
        guard let number else { return visiblyUsesText(anchor, in: answer) }
        return answer.range(
            of: #"(?<!\d)\#(number)(?!\d)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func visiblyUses(
        _ evidence: AskTheBookEvidence,
        in answer: String
    ) -> Bool {
        let sourceText = "\(evidence.result.title) \(evidence.result.snippet)"
        return visiblyUsesText(sourceText, in: answer)
    }

    private static func visiblyUsesText(
        _ sourceText: String,
        in answer: String
    ) -> Bool {
        let ignored: Set<String> = [
            "about", "after", "archive", "book", "created", "dated", "from",
            "memory", "page", "pages", "recorded", "source", "the", "this",
            "what", "when", "with", "your"
        ]
        let sourceTokens = sourceText.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !ignored.contains($0) }
        let lowerAnswer = answer.lowercased()
        return sourceTokens.prefix(12).contains(where: lowerAnswer.contains)
    }

    private static func datedSuffix(_ dateLabel: String) -> String {
        dateLabel.isEmpty ? "" : " from \(dateLabel)"
    }
}

/// Permission-aware retrieval for Chat with the Book. Search the Stacks remains
/// the broad discovery engine; this layer gives its results provenance, removes
/// old generated chat answers from the searchable corpus, and applies the more
/// conservative access rules appropriate to a conversational surface.
enum AskTheBookMemoryRetriever {
    static func retrieve(
        query: String,
        previousTurns: [AskTheBookTurn],
        from sourceDataset: StacksSearchDataset,
        limit: Int = 8,
        semanticScorer: StacksSemanticScoring? = StacksSearchEngine.defaultSemanticScorer()
    ) -> AskTheBookMemoryPacket {
        let inquiryKind = classify(query)
        let dataset = conversationalDataset(from: sourceDataset, query: query)
        let extraTerms = followUpTerms(for: query, previousTurns: previousTurns)
        let signalFindings = AskTheBookSignalAnalyzer.findings(
            for: query,
            // The analyzer reads only coarse weather/place stamps unless the
            // question explicitly opens Fuel or Inner Weather. Using the raw
            // local dataset here preserves weather coverage from a day whose
            // only kept Page was itself sensitive; no sensitive prose enters
            // the finding unless the reader directly asked for that chart.
            in: sourceDataset
        )
        let results = StacksSearchEngine.hybridSearch(
            query,
            in: dataset,
            extraTerms: extraTerms,
            limit: 40,
            semanticScorer: semanticScorer
        )

        var ranked: [(evidence: AskTheBookEvidence, score: Int)] = []
        var seen = Set<String>()
        for evidence in signalFindings {
            seen.insert(evidence.id)
            ranked.append((
                evidence,
                evidence.result.score + evidence.authority.rankingBoost
            ))
        }
        for result in results {
            guard !seen.contains(result.id),
                  let evidence = evidence(for: result, in: dataset) else { continue }
            seen.insert(result.id)
            ranked.append((evidence, result.score + evidence.authority.rankingBoost))
        }
        ranked.sort {
            if $0.score == $1.score { return $0.evidence.id < $1.evidence.id }
            return $0.score > $1.score
        }

        let selected: [AskTheBookEvidence]
        switch inquiryKind {
        case .recall, .calculation:
            selected = Array(ranked.prefix(max(limit, 0)).map(\.evidence))
        case .pattern:
            selected = diversifiedPatternEvidence(
                ranked,
                limit: min(max(limit, 0) + 2, 10)
            )
        }
        return AskTheBookMemoryPacket(
            inquiryKind: inquiryKind,
            evidence: selected,
            searchedRecordCount: searchableRecordCount(in: dataset),
            searchedWholeBook: true
        )
    }

    private static func searchableRecordCount(in dataset: StacksSearchDataset) -> Int {
        dataset.days.reduce(0) { $0 + $1.pages.count }
            + dataset.entities.count
            + dataset.anchors.count
            + dataset.memories.count
            + dataset.electives.count
            + dataset.references.count
            + dataset.selfFacts.count
            + dataset.narrativeEvents.count
            + dataset.facultyEntries.count
            + BookPageSourceRegistry.activeSources.count
    }

    private static func classify(_ query: String) -> AskTheBookMemoryPacket.InquiryKind {
        let lower = query.lowercased()
        if [
            "how many", "what number", "number of", "count of",
            "how often", "times have", "days have been"
        ].contains(where: lower.contains) {
            return .calculation
        }
        let patternPhrases = [
            "pattern", "over time", "keep happening", "keeps happening",
            "usually", "often", "always", "tend to", "changed", "changing",
            "how have i", "when am i", "what makes me", "in common",
            "again and again", "recurring", "connection between",
            "how do i feel", "how did i feel", "on rainy days",
            "on sunny days", "after i", "affect", "depending on"
        ]
        return patternPhrases.contains(where: lower.contains) ? .pattern : .recall
    }

    private static func followUpTerms(for query: String, previousTurns: [AskTheBookTurn]) -> [String] {
        guard let lastPrompt = previousTurns.last?.prompt else { return [] }
        let parsed = StacksQuery.parse(query)
        let lower = " \(query.lowercased()) "
        let refersBack = parsed.terms.count <= 3 || [
            " it ", " that ", " this ", " they ", " them ", " those ",
            " she ", " he ", " her ", " him ", " there "
        ].contains(where: lower.contains)
        return refersBack ? [lastPrompt] : []
    }

    private static func conversationalDataset(
        from source: StacksSearchDataset,
        query: String
    ) -> StacksSearchDataset {
        var dataset = source
        let permitsSupportMaterial = explicitlyRequestsSensitiveSupport(query)
        let permitsLocationMaterial = explicitlyRequestsLocation(query)
        dataset.selfFacts = source.selfFacts.filter {
            $0.usePermission != .doNotUse && $0.usePermission != .storyOnly
        }
        dataset.facultyEntries = permitsSupportMaterial ? source.facultyEntries : []
        dataset.days = source.days.map { day in
            var copy = day
            copy.pages = day.pages.compactMap { page in
                let isSupportPage: Bool = [
                    .mood, .fuel, .body, .rest, .supportGuild,
                    .facultyResearch, .inkrestOfficeHours
                ].contains(page.type)
                if isSupportPage && !permitsSupportMaterial {
                    return nil
                }
                if page.type == .location && !permitsLocationMaterial {
                    return nil
                }
                if page.privacy == .localSensitive
                    && !permitsSupportMaterial
                    && !permitsLocationMaterial {
                    return nil
                }
                var sanitized = page
                if !permitsLocationMaterial {
                    sanitized.tags.removeAll {
                        $0.lowercased().hasPrefix("braid-location:")
                    }
                    if var context = sanitized.context {
                        context.nearbyAnchorID = nil
                        context.locationLabel = nil
                        sanitized.context = context
                    }
                }
                if !permitsSupportMaterial, var context = sanitized.context {
                    context.innerWeatherEntryID = nil
                    context.fuelEntryID = nil
                    sanitized.context = context
                }
                guard sanitized.type == .askTheBook else { return sanitized }
                sanitized.userInput = priorReaderMessages(in: page.userInput)
                sanitized.playerReply = ""
                return sanitized.userInput.isEmpty ? nil : sanitized
            }
            return copy
        }
        return dataset
    }

    private static func explicitlyRequestsLocation(_ query: String) -> Bool {
        let lower = query.lowercased()
        let phrases = [
            "location", "place", "home", "where am i", "where do i",
            "where was i", "where have i", "where did i", "which anchor",
            "at an anchor", "near an anchor", "neighborhood", "neighbourhood"
        ]
        return phrases.contains(where: lower.contains)
    }

    private static func explicitlyRequestsSensitiveSupport(_ query: String) -> Bool {
        let lower = query.lowercased()
        let phrases = [
            "feel", "felt", "feeling", "mood", "inner weather", "emotion",
            "anxious", "anxiety", "sad", "grief", "lonely", "therapy",
            "body", "pain", "health", "sleep", "rest", "tired", "energy",
            "fuel", "food", "eat", "eating", "meal", "hungry", "doctor",
            "office hours", "dr. inkrest", "dr inkrest", "dr. vellum", "dr vellum"
        ]
        return phrases.contains(where: lower.contains)
    }

    private static func priorReaderMessages(in transcript: String) -> String {
        transcript
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { rawLine -> String? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.hasPrefix("Reader:") else { return nil }
                return String(line.dropFirst("Reader:".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty
            }
            .joined(separator: "\n")
    }

    private static func evidence(
        for result: StacksSearchResult,
        in dataset: StacksSearchDataset
    ) -> AskTheBookEvidence? {
        switch result.kind {
        case .keptPage:
            guard let page = dataset.days.lazy.flatMap(\.pages).first(where: { $0.id == result.referenceID }) else {
                return nil
            }
            if page.type == .askTheBook {
                // `conversationalDataset` has already replaced the transcript
                // with reader-only lines. Do not parse it a second time.
                let readerMessages = page.userInput
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !readerMessages.isEmpty else { return nil }
                return makeEvidence(
                    result: result,
                    authority: .priorConversation,
                    text: readerMessages,
                    mayQuote: true
                )
            }
            let text = pageEvidenceText(page, dataset: dataset)
            guard !text.isEmpty else { return nil }
            let authority: AskTheBookEvidenceAuthority
            if page.bookAuthoredText != nil {
                authority = .createdPage
            } else {
                switch page.origin {
                case .userAuthored: authority = .readerWords
                case .imported: authority = .importedEvidence
                case .generated, .simulated: authority = .createdPage
                }
            }
            return makeEvidence(
                result: result,
                authority: authority,
                text: text,
                mayQuote: (authority == .readerWords || authority == .importedEvidence)
                    && page.context?.innerWeatherEntryID == nil
                    && page.context?.fuelEntryID == nil,
                hasReaderContributions: page.hasReaderContribution
            )

        case .castMember:
            guard let entity = dataset.entities.first(where: { $0.id == result.referenceID }) else { return nil }
            let text = ([entity.kind.rawValue] + entity.traits + entity.beliefs + entity.goals + [entity.unwrittenInterest ?? ""])
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            return makeEvidence(result: result, authority: .recordedFact, text: text, mayQuote: true)

        case .anchor:
            guard let anchor = dataset.anchors.first(where: { $0.id == result.referenceID }) else { return nil }
            let text = "\(anchor.kind.title)\nReader's words: \(anchor.playerWords)\nRoom: \(anchor.outerStacksRoom)\nLocal rule: \(anchor.localRule)"
            return makeEvidence(result: result, authority: .recordedFact, text: text, mayQuote: true)

        case .memory:
            if let memory = dataset.memories.first(where: { $0.id == result.referenceID }) {
                return makeEvidence(result: result, authority: .derivedMemory, text: memory.summary, mayQuote: false)
            }
            if let day = dataset.days.first(where: { $0.id == result.referenceID }) {
                let text = day.pages
                    .map { pageEvidenceText($0, dataset: dataset) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")
                return makeEvidence(result: result, authority: .derivedMemory, text: text, mayQuote: false)
            }
            return nil

        case .reference:
            guard let snippet = dataset.references.first(where: { $0.id == result.referenceID }) else { return nil }
            return makeEvidence(result: result, authority: .canon, text: snippet.body, mayQuote: true)

        case .elective:
            guard let elective = dataset.electives.first(where: { $0.id == result.referenceID }) else { return nil }
            let text = "\(elective.characterName)\n\(elective.ask)\n\(elective.practiceShape)"
            return makeEvidence(result: result, authority: .recordedFact, text: text, mayQuote: true)

        case .pageFamily:
            guard let source = BookPageSourceRegistry.activeSources.first(where: { $0.id == result.referenceID }) else { return nil }
            return makeEvidence(result: result, authority: .canon, text: source.note, mayQuote: true)

        case .selfFact:
            guard let fact = dataset.selfFacts.first(where: { $0.id == result.referenceID }) else { return nil }
            let mayQuote = fact.usePermission == .quoteAllowed
            let text = mayQuote ? fact.answer : fact.bookTranslation
            return makeEvidence(result: result, authority: .recordedFact, text: text, mayQuote: mayQuote)

        case .narrativeEvent:
            guard let event = dataset.narrativeEvents.first(where: { $0.id == result.referenceID }) else { return nil }
            return makeEvidence(result: result, authority: .derivedMemory, text: event.summary, mayQuote: false)

        case .facultyEntry:
            guard let entry = dataset.facultyEntries.first(where: { $0.id == result.referenceID }) else { return nil }
            return makeEvidence(result: result, authority: .recordedFact, text: entry.rawText, mayQuote: false)
        }
    }

    private static func pageEvidenceText(
        _ page: BookPage,
        dataset: StacksSearchDataset
    ) -> String {
        var sections: [String] = []
        if let context = page.context {
            if !context.weatherTags.isEmpty {
                sections.append("Recorded outer weather: \(context.weatherTags.joined(separator: ", "))")
            }
            if let locationLabel = context.locationLabel?.nonEmpty {
                sections.append("Recorded place: \(locationLabel)")
            } else if let anchorID = context.nearbyAnchorID?.nonEmpty {
                let anchorName = dataset.anchors.first(where: { $0.id == anchorID })?.name
                sections.append("Recorded place: \(anchorName ?? anchorID)")
            }
            if let entryID = context.innerWeatherEntryID,
               let entry = dataset.facultyEntries.first(where: { $0.id == entryID }) {
                sections.append("Private Inner Weather at keep time: \(entry.rawText)")
            }
            if let entryID = context.fuelEntryID,
               let entry = dataset.facultyEntries.first(where: { $0.id == entryID }) {
                sections.append("Private Fuel context at keep time: \(entry.rawText)")
            }
        }
        if !page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let owner = (page.origin == .generated || page.origin == .simulated)
                ? "Book's Page prompt"
                : "Page prompt"
            sections.append("\(owner): \(page.promptText)")
        }
        if let bookText = page.bookAuthoredText {
            sections.append("Book-created Page text: \(bookText)")
        } else if !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch page.origin {
            case .userAuthored:
                sections.append("Reader's own words: \(page.userInput)")
            case .imported:
                sections.append("Imported text or evidence: \(page.userInput)")
            case .generated, .simulated:
                break
            }
        }
        if page.origin != .userAuthored || page.bookAuthoredText != nil {
            for words in page.readerAuthoredTexts {
                sections.append("Reader's own words inside this Page: \(words)")
            }
            for choice in page.readerFictionChoices {
                sections.append("Reader's fiction choice inside this Page: \(choice)")
            }
        }
        if page.hasReaderPhotograph {
            sections.append("Reader supplied a photograph to this Page.")
        }
        if page.hasReaderAudioRecording {
            sections.append("Reader supplied a voice recording to this Page.")
        }
        return sections.joined(separator: "\n\n")
    }

    private static func makeEvidence(
        result: StacksSearchResult,
        authority: AskTheBookEvidenceAuthority,
        text: String,
        mayQuote: Bool,
        hasReaderContributions: Bool = false
    ) -> AskTheBookEvidence {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return AskTheBookEvidence(
            result: result,
            authority: authority,
            excerpt: clip(normalized, limit: 720),
            fullText: clip(normalized, limit: 5_000),
            mayQuote: mayQuote,
            hasReaderContributions: hasReaderContributions
        )
    }

    private static func diversifiedPatternEvidence(
        _ ranked: [(evidence: AskTheBookEvidence, score: Int)],
        limit: Int
    ) -> [AskTheBookEvidence] {
        var selected: [AskTheBookEvidence] = []
        var dateCounts: [String: Int] = [:]
        var kindCounts: [StacksSearchResult.Kind: Int] = [:]
        for item in ranked {
            let date = item.evidence.result.dateLabel
            let dateKey = date.isEmpty ? item.evidence.id : date
            guard dateCounts[dateKey, default: 0] < 2,
                  kindCounts[item.evidence.result.kind, default: 0] < 5 else {
                continue
            }
            selected.append(item.evidence)
            dateCounts[dateKey, default: 0] += 1
            kindCounts[item.evidence.result.kind, default: 0] += 1
            if selected.count == limit { break }
        }
        return selected
    }

    private static func clip(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

/// Builds deterministic, dated findings for questions that ordinary relevance
/// search cannot answer honestly: counts, cross-log comparisons, and questions
/// about how two recorded signals lined up. It never treats an unrecorded day
/// as evidence and never turns co-occurrence into causation.
enum AskTheBookSignalAnalyzer {
    private struct DaySignals {
        var id: String
        var date: Date
        var weatherTags: Set<String> = []
        var locationLabels: Set<String> = []
        var fuelEntries: [FacultyEntry] = []
        var innerWeatherEntries: [FacultyEntry] = []

        var hasWeather: Bool { !weatherTags.isEmpty }
    }

    private struct WeatherFocus {
        var tag: String
        var label: String
    }

    static func findings(
        for query: String,
        in dataset: StacksSearchDataset,
        calendar: Calendar = .current
    ) -> [AskTheBookEvidence] {
        let lower = query.lowercased()
        let signals = daySignals(from: dataset, calendar: calendar)
        guard !signals.isEmpty else { return [] }

        let asksForCount = containsAny(lower, [
            "how many", "what number", "number of", "count of",
            "how often", "times have", "days have been"
        ])
        let asksAboutMood = containsAny(lower, [
            "inner weather", "mood", "feel", "felt", "feeling",
            "anxious", "anxiety", "sad", "happy", "calm", "heavy"
        ])
        let asksAboutFuel = containsAny(lower, [
            "fuel", "meal", "food", "eat", "ate", "breakfast", "lunch",
            "dinner", "snack", "coffee", "caffeine", "water", "drink"
        ])
        let asksAboutLocation = containsAny(lower, [
            "location", "place", "home",
            "where was i", "where have i", "where did i", "anchor",
            "neighborhood", "neighbourhood"
        ])
        let weatherFocus = weatherFocus(in: lower)
        let asksAboutWeather = weatherFocus != nil || lower.contains("weather")

        var findings: [AskTheBookEvidence] = []
        if asksForCount, let weatherFocus {
            findings.append(weatherCountFinding(
                focus: weatherFocus,
                query: lower,
                signals: signals,
                dataset: dataset,
                calendar: calendar
            ))
        } else if let weatherFocus, asksAboutMood {
            findings.append(weatherMoodFinding(
                focus: weatherFocus,
                signals: signals
            ))
        } else if asksAboutWeather {
            findings.append(weatherOverviewFinding(signals: signals))
        }

        if asksAboutFuel {
            if asksForCount {
                findings.append(logCountFinding(
                    kind: .fuel,
                    signals: signals
                ))
            } else if asksAboutMood && containsAny(lower, ["after", "before", "affect", "connection", "when i"]) {
                findings.append(fuelMoodFinding(
                    query: lower,
                    signals: signals
                ))
            } else {
                findings.append(logOverviewFinding(
                    kind: .fuel,
                    signals: signals
                ))
            }
        } else if asksAboutMood, asksForCount {
            findings.append(logCountFinding(
                kind: .innerWeather,
                signals: signals
            ))
        }

        if asksAboutLocation {
            findings.append(locationFinding(
                asksAboutMood: asksAboutMood,
                signals: signals
            ))
        }

        var seen = Set<String>()
        return findings.filter { seen.insert($0.id).inserted }
    }

    private static func daySignals(
        from dataset: StacksSearchDataset,
        calendar: Calendar
    ) -> [DaySignals] {
        var byID: [String: DaySignals] = [:]
        for day in dataset.days {
            var signal = DaySignals(id: day.id, date: day.date)
            for page in day.pages {
                signal.weatherTags.formUnion(weatherTags(for: page))
                signal.locationLabels.formUnion(locationLabels(
                    for: page,
                    anchors: dataset.anchors
                ))
            }
            byID[day.id] = signal
        }

        for entry in dataset.facultyEntries {
            let key: String
            if byID[entry.dayID] != nil {
                key = entry.dayID
            } else if let matching = byID.values.first(where: {
                calendar.isDate($0.date, inSameDayAs: entry.createdAt)
            }) {
                key = matching.id
            } else {
                key = "faculty-\(dayKey(entry.createdAt, calendar: calendar))"
                byID[key] = DaySignals(id: key, date: entry.createdAt)
            }
            guard var signal = byID[key] else { continue }
            switch entry.kind {
            case .fuel:
                signal.fuelEntries.append(entry)
            case .innerWeather:
                signal.innerWeatherEntries.append(entry)
            }
            byID[key] = signal
        }

        return byID.values
            .map { signal in
                var copy = signal
                copy.fuelEntries.sort { $0.createdAt < $1.createdAt }
                copy.innerWeatherEntries.sort { $0.createdAt < $1.createdAt }
                return copy
            }
            .sorted { $0.date < $1.date }
    }

    private static func weatherTags(for page: BookPage) -> Set<String> {
        var tags = Set(page.context?.weatherTags.map(normalized) ?? [])
        let weatherText = (
            [page.promptText, page.userInput, page.playerReply]
                + page.tags
                    .filter { $0.lowercased().hasPrefix("braid-weather:") }
                    .map { String($0.dropFirst("braid-weather:".count)) }
                + (page.type == .weather ? page.tags : [])
        ).joined(separator: " ").lowercased()
        for focus in allWeatherFocuses where focus.terms.contains(where: weatherText.contains) {
            tags.insert(focus.tag)
        }
        return tags
    }

    private static func locationLabels(
        for page: BookPage,
        anchors: [AnchorRecord]
    ) -> Set<String> {
        var labels = Set<String>()
        if let locationLabel = page.context?.locationLabel?.nonEmpty {
            labels.insert(locationLabel)
        }
        if let anchorID = page.context?.nearbyAnchorID?.nonEmpty {
            labels.insert(
                anchors.first(where: { $0.id == anchorID })?.name.nonEmpty
                    ?? anchorID
            )
        }
        for tag in page.tags where tag.lowercased().hasPrefix("braid-location:") {
            let label = String(tag.dropFirst("braid-location:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty, label.lowercased() != "not recorded" {
                labels.insert(label)
            }
        }
        if page.type == .location,
           let label = page.archivePreviewText?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty {
            labels.insert(String(label.prefix(100)))
        }
        return labels
    }

    private static func weatherCountFinding(
        focus: WeatherFocus,
        query: String,
        signals: [DaySignals],
        dataset: StacksSearchDataset,
        calendar: Calendar
    ) -> AskTheBookEvidence {
        let asksSinceFirstChat = containsAny(query, [
            "since we started talking", "since we began talking",
            "since our first chat", "since we first talked"
        ])
        let firstChat = dataset.days
            .flatMap(\.pages)
            .filter { $0.type == .askTheBook }
            .map(\.createdAt)
            .min()
        let earliestWeather = signals.first(where: \.hasWeather)?.date
        let start = asksSinceFirstChat ? (firstChat ?? earliestWeather) : earliestWeather
        let scoped = start.map { start in
            signals.filter { $0.date >= calendar.startOfDay(for: start) }
        } ?? signals
        let observed = scoped.filter(\.hasWeather)
        let matched = observed.filter { $0.weatherTags.contains(focus.tag) }
        let dates = matched.map { formattedDate($0.date) }
        let startLabel = start.map(formattedDate) ?? "the first recorded day"
        let scopeNote: String
        if asksSinceFirstChat, firstChat == nil {
            scopeNote = "No earlier kept conversation was available, so the count begins with the earliest saved weather observation."
        } else if asksSinceFirstChat {
            scopeNote = "The period begins with the first kept conversation."
        } else {
            scopeNote = "The period begins with the earliest saved weather observation."
        }
        let summary = """
        The archive contains \(matched.count) recorded \(focus.label) day\(matched.count == 1 ? "" : "s") since \(startLabel).
        Weather evidence exists on \(observed.count) distinct day\(observed.count == 1 ? "" : "s") in that period. Unrecorded days are not counted as either \(focus.label) or not \(focus.label).
        \(scopeNote)
        Matching dates: \(dates.isEmpty ? "none" : dates.joined(separator: ", ")).
        """
        return finding(
            id: "weather-count-\(focus.tag)",
            title: "Recorded \(focus.label.capitalized) Days",
            summary: summary,
            dateLabel: dateRange(observed),
            mayQuote: true,
            score: 240
        )
    }

    private static func weatherMoodFinding(
        focus: WeatherFocus,
        signals: [DaySignals]
    ) -> AskTheBookEvidence {
        let weatherDays = signals.filter { $0.weatherTags.contains(focus.tag) }
        let paired = weatherDays.filter { !$0.innerWeatherEntries.isEmpty }
        let lines = paired.flatMap { day in
            day.innerWeatherEntries.map {
                "\(formattedDate(day.date)) · \($0.windowName): \($0.rawText)"
            }
        }
        let summary = """
        The archive has \(weatherDays.count) recorded \(focus.label) day\(weatherDays.count == 1 ? "" : "s").
        Inner Weather was also logged on \(paired.count) of those distinct dates, across \(lines.count) entr\(lines.count == 1 ? "y" : "ies").
        Dated pairings:
        \(lines.isEmpty ? "No dated Inner Weather entry is paired with a recorded \(focus.label) day yet." : lines.joined(separator: "\n"))
        These are co-occurring observations, not evidence that the outer weather caused the feeling.
        """
        return finding(
            id: "weather-mood-\(focus.tag)",
            title: "Inner Weather on \(focus.label.capitalized) Days",
            summary: summary,
            dateLabel: dateRange(weatherDays),
            mayQuote: false,
            score: 250
        )
    }

    private static func weatherOverviewFinding(
        signals: [DaySignals]
    ) -> AskTheBookEvidence {
        let observed = signals.filter(\.hasWeather)
        let counts = Dictionary(
            grouping: observed.flatMap { Array($0.weatherTags) },
            by: { $0 }
        ).mapValues(\.count)
        let breakdown = counts
            .sorted {
                if $0.value == $1.value { return $0.key < $1.key }
                return $0.value > $1.value
            }
            .map { "\($0.key): \($0.value) recorded day\($0.value == 1 ? "" : "s")" }
            .joined(separator: "; ")
        let summary = """
        Weather evidence appears on \(observed.count) distinct archived day\(observed.count == 1 ? "" : "s").
        Coarse recorded tags: \(breakdown.isEmpty ? "none" : breakdown).
        A day can carry more than one tag, and days without a saved weather observation are outside this summary.
        """
        return finding(
            id: "weather-overview",
            title: "Recorded Weather",
            summary: summary,
            dateLabel: dateRange(observed),
            mayQuote: true,
            score: 180
        )
    }

    private static func logCountFinding(
        kind: FacultyEntryKind,
        signals: [DaySignals]
    ) -> AskTheBookEvidence {
        let entries = signals.flatMap {
            kind == .fuel ? $0.fuelEntries : $0.innerWeatherEntries
        }
        let distinctDays = Set(entries.map {
            Calendar.current.startOfDay(for: $0.createdAt)
        }).count
        let title = kind == .fuel ? "Fuel Logs" : "Inner Weather Logs"
        let summary = """
        The archive contains \(entries.count) \(title) entr\(entries.count == 1 ? "y" : "ies") across \(distinctDays) distinct day\(distinctDays == 1 ? "" : "s").
        This counts saved faculty-chart entries, not days when something may have happened but was not logged.
        """
        return finding(
            id: "log-count-\(kind.rawValue)",
            title: "\(title) Count",
            summary: summary,
            dateLabel: entryDateRange(entries),
            mayQuote: true,
            score: 225
        )
    }

    private static func logOverviewFinding(
        kind: FacultyEntryKind,
        signals: [DaySignals]
    ) -> AskTheBookEvidence {
        let entries = signals.flatMap {
            kind == .fuel ? $0.fuelEntries : $0.innerWeatherEntries
        }.sorted { $0.createdAt > $1.createdAt }
        let recent = entries.prefix(10).map {
            "\(formattedDate($0.createdAt)) · \($0.windowName): \($0.rawText)"
        }
        let title = kind == .fuel ? "Fuel Log" : "Inner Weather"
        let summary = """
        The archive has \(entries.count) saved \(title) entr\(entries.count == 1 ? "y" : "ies").
        Most recent dated entries:
        \(recent.isEmpty ? "none" : recent.joined(separator: "\n"))
        """
        return finding(
            id: "log-overview-\(kind.rawValue)",
            title: "\(title) Archive",
            summary: summary,
            dateLabel: entryDateRange(entries),
            mayQuote: false,
            score: 190
        )
    }

    private static func fuelMoodFinding(
        query: String,
        signals: [DaySignals]
    ) -> AskTheBookEvidence {
        let subjectTerms = StacksQuery.parse(query).terms.filter {
            !fuelMoodStopWords.contains($0)
        }
        let allFuel = signals.flatMap(\.fuelEntries)
        let matchedFuel = subjectTerms.isEmpty
            ? allFuel
            : allFuel.filter { entry in
                let text = entry.rawText.lowercased()
                return subjectTerms.contains(where: text.contains)
            }
        var lines: [String] = []
        var pairedDates = Set<String>()
        for fuel in matchedFuel {
            guard let day = signals.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: fuel.createdAt)
            }) else { continue }
            let later = day.innerWeatherEntries.filter {
                $0.createdAt >= fuel.createdAt
                    && $0.createdAt.timeIntervalSince(fuel.createdAt) <= 12 * 3_600
            }
            let moods = later.isEmpty ? day.innerWeatherEntries : later
            for mood in moods {
                pairedDates.insert(dayKey(day.date, calendar: .current))
                let hours = max(0, mood.createdAt.timeIntervalSince(fuel.createdAt) / 3_600)
                let timing = mood.createdAt >= fuel.createdAt
                    ? String(format: "%.1f hours later", hours)
                    : "the same recorded day"
                lines.append(
                    "\(formattedDate(day.date)) · Fuel: \(fuel.rawText) · Inner Weather (\(timing)): \(mood.rawText)"
                )
            }
        }
        let summary = """
        \(matchedFuel.count) Fuel Log entr\(matchedFuel.count == 1 ? "y matches" : "ies match") the question.
        The archive has Fuel/Inner Weather pairings on \(pairedDates.count) distinct date\(pairedDates.count == 1 ? "" : "s"):
        \(lines.isEmpty ? "No timed Inner Weather entry is paired closely enough with those Fuel Logs yet." : lines.prefix(12).joined(separator: "\n"))
        Timing can suggest a question to watch; it does not establish that food or drink caused the later feeling.
        """
        return finding(
            id: "fuel-inner-weather-comparison",
            title: "Fuel and Inner Weather",
            summary: summary,
            dateLabel: entryDateRange(matchedFuel),
            mayQuote: false,
            score: 245
        )
    }

    private static func locationFinding(
        asksAboutMood: Bool,
        signals: [DaySignals]
    ) -> AskTheBookEvidence {
        let located = signals.filter { !$0.locationLabels.isEmpty }
        let placeCounts = Dictionary(
            grouping: located.flatMap { Array($0.locationLabels) },
            by: { $0 }
        ).mapValues(\.count)
        let places = placeCounts
            .sorted {
                if $0.value == $1.value { return $0.key < $1.key }
                return $0.value > $1.value
            }
            .map { "\($0.key): \($0.value) recorded day\($0.value == 1 ? "" : "s")" }
            .joined(separator: "; ")
        let moodLines = asksAboutMood
            ? located.flatMap { day in
                day.innerWeatherEntries.map {
                    "\(formattedDate(day.date)) · \(day.locationLabels.sorted().joined(separator: ", ")): \($0.rawText)"
                }
            }
            : []
        let summary = """
        Saved place or Anchor context appears on \(located.count) distinct archived day\(located.count == 1 ? "" : "s").
        Recorded places: \(places.isEmpty ? "none" : places).
        \(asksAboutMood ? "Dated Inner Weather pairings:\n\(moodLines.isEmpty ? "none yet" : moodLines.prefix(12).joined(separator: "\n"))" : "")
        Location here means reader-named places and nearby saved Anchors. The archive does not expose a coordinate trail.
        \(asksAboutMood ? "These pairings are observations, not proof that a place caused a feeling." : "")
        """
        return finding(
            id: asksAboutMood ? "location-inner-weather" : "location-overview",
            title: asksAboutMood ? "Place and Inner Weather" : "Recorded Places",
            summary: summary,
            dateLabel: dateRange(located),
            mayQuote: !asksAboutMood,
            score: asksAboutMood ? 235 : 185
        )
    }

    private static func finding(
        id: String,
        title: String,
        summary: String,
        dateLabel: String,
        mayQuote: Bool,
        score: Int
    ) -> AskTheBookEvidence {
        let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = StacksSearchResult(
            id: "finding-\(id)",
            kind: .memory,
            title: title,
            snippet: clipped(cleaned, limit: 220),
            dateLabel: dateLabel,
            score: score,
            referenceID: "finding-\(id)"
        )
        return AskTheBookEvidence(
            result: result,
            authority: .computedFinding,
            excerpt: clipped(cleaned, limit: 1_600),
            fullText: clipped(cleaned, limit: 6_000),
            mayQuote: mayQuote
        )
    }

    private static let allWeatherFocuses: [(tag: String, label: String, terms: [String])] = [
        ("storm", "stormy", ["storm", "thunder", "lightning"]),
        ("rain", "rainy", ["rain", "rainy", "drizzle", "shower"]),
        ("snow", "snowy", ["snow", "snowy", "sleet", "icy"]),
        ("fog", "foggy", ["fog", "foggy", "mist", "misty", "haze"]),
        ("wind", "windy", ["wind", "windy", "gust", "breeze"]),
        ("cloud", "cloudy", ["cloud", "cloudy", "overcast"]),
        ("bright", "sunny", ["sun", "sunny", "clear", "bright"]),
        ("hot", "hot", ["hot", "heat", "warm"]),
        ("cold", "cold", ["cold", "chill", "freezing"])
    ]

    private static func weatherFocus(in query: String) -> WeatherFocus? {
        allWeatherFocuses.first(where: {
            $0.terms.contains(where: query.contains)
        }).map { WeatherFocus(tag: $0.tag, label: $0.label) }
    }

    private static let fuelMoodStopWords: Set<String> = [
        "feel", "felt", "feeling", "mood", "inner", "weather", "after",
        "before", "affect", "effect", "connection", "fuel", "food", "meal",
        "days", "usually", "happen", "when"
    ]

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains(where: text.contains)
    }

    private static func clipped(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private static func dateRange(_ signals: [DaySignals]) -> String {
        guard let first = signals.first?.date, let last = signals.last?.date else {
            return "No dated records"
        }
        let start = formattedDate(first)
        let end = formattedDate(last)
        return start == end ? start : "\(start) – \(end)"
    }

    private static func entryDateRange(_ entries: [FacultyEntry]) -> String {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard let first = sorted.first?.createdAt, let last = sorted.last?.createdAt else {
            return "No dated records"
        }
        let start = formattedDate(first)
        let end = formattedDate(last)
        return start == end ? start : "\(start) – \(end)"
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
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

    var semanticText: String {
        let text = searchableText
        guard text.count > 1_800 else { return text }
        return String(text.prefix(1_800))
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
    /// CoreNLP's sentence embedding can share mutable native state even across
    /// separate `NLEmbedding` wrappers. Surface refreshes may overlap, so all
    /// distance calls must cross one process-wide gate. Without it, concurrent
    /// calls can crash inside `CoreNLP::ContextualWordEmbedding`.
    private static let distanceLock = NSLock()

    let language: NLLanguage
    let modelID: String
    private let embedding: NLEmbedding

    init?(language: NLLanguage = .english) {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else { return nil }
        self.language = language
        self.modelID = "NaturalLanguage.sentenceEmbedding.\(language.rawValue)"
        self.embedding = embedding
    }

    func similarity(between query: String, and document: String) -> Double? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDocument = document.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !trimmedDocument.isEmpty else { return nil }
        Self.distanceLock.lock()
        let distance = embedding.distance(between: trimmedQuery, and: trimmedDocument)
        Self.distanceLock.unlock()
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
    static let minimumSemanticQueryLength = 4

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
        results += searchSelfFacts(query, dataset: dataset)
        results += searchNarrativeEvents(query, dataset: dataset)
        results += searchFacultyEntries(query, dataset: dataset)

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
        semanticScorer: StacksSemanticScoring? = defaultSemanticScorer(),
        prebuiltGraph: (documents: [StacksSearchDocument], links: [StacksSearchLink])? = nil
    ) -> [StacksSearchResult] {
        let lexicalResults = search(raw, in: dataset, extraTerms: extraTerms, now: now, limit: limit)
        guard shouldRunSemanticSearch(raw, extraTerms: extraTerms),
              let semanticScorer else { return lexicalResults }

        let graph = prebuiltGraph ?? buildSearchGraph(from: dataset, now: now)
        var resultsByID = Dictionary(uniqueKeysWithValues: lexicalResults.map { ($0.id, $0) })
        let queryText = ([raw] + extraTerms).joined(separator: " ")
        let lexicalIDs = Set(lexicalResults.map(\.id))

        for document in graph.documents {
            // A newer keystroke supersedes this search; the lexical results
            // are still honest, so hand those back instead of finishing the
            // embedding walk.
            if Task.isCancelled { return lexicalResults }
            guard let similarity = semanticScorer.similarity(between: queryText, and: document.semanticText),
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
            let dayBody = day.pages.map {
                "\($0.type.title): \($0.promptText) \($0.userInput) \($0.playerReply) \($0.tags.joined(separator: " ")) \(pageContextSearchText($0, dataset: dataset))"
            }.joined(separator: "\n")
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
                let body = "\(page.promptText)\n\(page.userInput)\n\(page.playerReply)\nTags: \(page.tags.joined(separator: ", "))\nContext: \(pageContextSearchText(page, dataset: dataset))\nSource: \(page.sourceID)"
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
                dateLabel: elective.isReleased ? "Resting" : (elective.isActive ? "Active" : "Completed"),
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

    static func defaultSemanticScorer() -> StacksSemanticScoring? {
        #if canImport(NaturalLanguage)
        return NaturalLanguageStacksEmbeddingScorer()
        #else
        return nil
        #endif
    }

    private static func shouldRunSemanticSearch(_ raw: String, extraTerms: [String]) -> Bool {
        let queryText = ([raw] + extraTerms).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let meaningfulCharacters = queryText.filter { $0.isLetter || $0.isNumber }
        return meaningfulCharacters.count >= minimumSemanticQueryLength
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
                let haystackBody = "\(page.userInput) \(pageContextSearchText(page, dataset: dataset))".lowercased()
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
                let previewText = page.archivePreviewText ?? page.type.title
                if correlated, query.terms.isEmpty {
                    snippet = "Kept on a \(query.moodKey ?? "matching") day. \(previewText.bookPreviewSentenceLimit(1))"
                } else {
                    snippet = snippetAround(matchedTerm, in: previewText)
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

    private static func pageContextSearchText(
        _ page: BookPage,
        dataset: StacksSearchDataset
    ) -> String {
        guard let context = page.context else { return "" }
        var parts: [String] = []
        if !context.weatherTags.isEmpty {
            let tagsAndAliases = context.weatherTags.flatMap { tag in
                [tag] + weatherSearchAliases(for: tag)
            }
            parts.append("weather \(tagsAndAliases.joined(separator: " "))")
        }
        if let anchorID = context.nearbyAnchorID?.nonEmpty {
            let anchorName = dataset.anchors.first(where: { $0.id == anchorID })?.name
            parts.append("place \(anchorName ?? anchorID)")
        } else if let locationLabel = context.locationLabel?.nonEmpty {
            parts.append("place \(locationLabel)")
        }
        if let entryID = context.innerWeatherEntryID,
           let entry = dataset.facultyEntries.first(where: { $0.id == entryID }) {
            parts.append("inner weather \(entry.rawText)")
        }
        if let entryID = context.fuelEntryID,
           let entry = dataset.facultyEntries.first(where: { $0.id == entryID }) {
            parts.append("fuel \(entry.rawText)")
        }
        if let bodyScore = context.bodyScore {
            parts.append("body score \(bodyScore)")
        }
        if let eventCount = context.calendarEventCount {
            parts.append("calendar events \(eventCount)")
        }
        parts.append("day part \(context.dayPart)")
        return parts.joined(separator: " · ")
    }

    private static func weatherSearchAliases(for tag: String) -> [String] {
        switch tag.lowercased() {
        case "bright": return ["sun", "sunny", "clear"]
        case "rain": return ["rainy", "drizzle", "showers"]
        case "storm": return ["stormy", "thunder"]
        case "snow": return ["snowy", "sleet", "icy"]
        case "fog": return ["foggy", "mist", "misty"]
        case "wind": return ["windy", "gust", "breezy"]
        case "cloud": return ["cloudy", "overcast"]
        case "hot": return ["warm", "heat"]
        case "cold": return ["chilly", "freezing"]
        default: return []
        }
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
                snippet: "\(elective.isReleased ? "Resting" : (elective.isActive ? "Active" : "Completed")) · for \(elective.characterName). \(String(elective.ask.prefix(110)))",
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

    private static func searchSelfFacts(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.selfFacts.compactMap { fact in
            guard fact.usePermission != .doNotUse else { return nil }
            let titleText = "\(fact.question) \(fact.tags.joined(separator: " "))"
            let bodyText = "\(fact.answer)\n\(fact.bookTranslation)"
            let match = lexicalMatch(query, title: titleText, body: bodyText)
            guard match.score > 0 else { return nil }
            return StacksSearchResult(
                id: "selfFact-\(fact.id)",
                kind: .selfFact,
                title: fact.question,
                snippet: snippetAround(match.term, in: fact.bookTranslation.nonEmpty ?? fact.answer),
                dateLabel: formattedDate(fact.updatedAt),
                score: match.score,
                referenceID: fact.id
            )
        }
    }

    private static func searchNarrativeEvents(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.narrativeEvents.compactMap { event in
            let title = event.kind.rawValue
                .split(separator: "-")
                .map(String.init)
                .joined(separator: " ")
                .capitalized
            let match = lexicalMatch(
                query,
                title: "\(title) \(event.tags.joined(separator: " "))",
                body: event.summary
            )
            guard match.score > 0 else { return nil }
            return StacksSearchResult(
                id: "event-\(event.id)",
                kind: .narrativeEvent,
                title: title,
                snippet: snippetAround(match.term, in: event.summary),
                dateLabel: formattedDate(event.createdAt),
                score: match.score,
                referenceID: event.id
            )
        }
    }

    private static func searchFacultyEntries(_ query: StacksQuery, dataset: StacksSearchDataset) -> [StacksSearchResult] {
        dataset.facultyEntries.compactMap { entry in
            let match = lexicalMatch(
                query,
                title: "\(entry.windowName) \(entry.kind.chartTitle) \(entry.tags.joined(separator: " "))",
                body: entry.rawText
            )
            guard match.score > 0 else { return nil }
            return StacksSearchResult(
                id: "faculty-\(entry.id)",
                kind: .facultyEntry,
                title: entry.windowName,
                snippet: snippetAround(match.term, in: entry.rawText),
                dateLabel: formattedDate(entry.createdAt),
                score: match.score,
                referenceID: entry.id
            )
        }
    }

    private static func lexicalMatch(
        _ query: StacksQuery,
        title: String,
        body: String
    ) -> (score: Int, term: String?) {
        let titleText = title.lowercased()
        let bodyText = body.lowercased()
        var score = 0
        var matched: String?
        for term in query.terms {
            if titleText.contains(term) {
                score += 7
                matched = matched ?? term
            }
            if bodyText.contains(term) {
                score += 4
                matched = matched ?? term
            }
        }
        return (score, matched)
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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

/// The reading-room clerk behind an open Search the Stacks sheet. One clerk
/// per sheet: it holds one snapshot of the dataset, builds the document graph
/// once, loads the sentence-embedding model once (off the main thread, on
/// first use), and (being an actor) serialises searches so rapid keystrokes
/// never race each other over the shared embedding.
actor StacksSearchService {
    private let dataset: StacksSearchDataset
    private var cachedGraph: (documents: [StacksSearchDocument], links: [StacksSearchLink])?
    private var scorerLoaded = false
    private var cachedScorer: StacksSemanticScoring?

    init(dataset: StacksSearchDataset) {
        self.dataset = dataset
    }

    /// The instant pass: pure lexical matching, cheap enough to run on every
    /// keystroke so results appear while the reader is still typing.
    func lexicalResults(for query: String, extraTerms: [String] = []) -> [StacksSearchResult] {
        StacksSearchEngine.search(query, in: dataset, extraTerms: extraTerms)
    }

    /// The deep pass: lexical plus the sentence-embedding graph walk. Bails
    /// back to lexical partway through if the surrounding task is cancelled.
    func hybridResults(for query: String, extraTerms: [String] = []) -> [StacksSearchResult] {
        if cachedGraph == nil {
            cachedGraph = StacksSearchEngine.buildSearchGraph(from: dataset)
        }
        return StacksSearchEngine.hybridSearch(
            query,
            in: dataset,
            extraTerms: extraTerms,
            semanticScorer: scorer(),
            prebuiltGraph: cachedGraph
        )
    }

    private func scorer() -> StacksSemanticScoring? {
        if !scorerLoaded {
            scorerLoaded = true
            #if canImport(NaturalLanguage)
            cachedScorer = NaturalLanguageStacksEmbeddingScorer()
            #endif
        }
        return cachedScorer
    }
}

/// The recognition note: a just-kept page that rhymes with an older page
/// earns a line naming the shared word and when it first appeared. Fixed,
/// legible rule: a rare-enough word, old enough to feel like memory.
enum KeepEcho {
    struct Echo: Equatable {
        var sourcePageID: String
        var sharedWord: String
        var monthLine: String
        var line: String
    }

    /// A word must be at least this old to echo: recognition, not repetition.
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
        let candidates: [(page: BookPage, text: String)] = days.flatMap(\.capturedPages).compactMap { page in
            guard page.createdAt <= cutoff,
                  !EditionCurator.defaultPrivateTypes.contains(page.type),
                  let text = page.readerAuthoredTextForAnalysis else { return nil }
            return (page, text)
        }
        guard !candidates.isEmpty else { return nil }

        // How widely each input word is spread across the archive.
        var spread: [String: Int] = [:]
        var matches: [(page: BookPage, word: String)] = []
        for candidate in candidates {
            let pageWords = Set(
                candidate.text.lowercased()
                    .split { !$0.isLetter }
                    .map(String.init)
                    .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
            )
            for word in inputWords.intersection(pageWords) {
                spread[word, default: 0] += 1
                matches.append((candidate.page, word))
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
            "You\u{2019}ve written about \u{201C}\(chosen.word)\u{201D} before: \(monthLine). The Book remembers.",
            "This rhymes with a page from \(monthLine): the one about \u{201C}\(chosen.word)\u{201D}.",
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

// MARK: - The Semantic Echo

/// The deeper recognition note: a just-kept page that shares *no* content word
/// with an older page and still carries the same feeling. The inversion of
/// `KeepEcho`: there, a shared rare word is the trigger; here, any shared
/// content word disqualifies, so when this note speaks the connection could
/// not have come from string matching. It rides the same sentence embedding
/// as Search the Stacks and stays deterministic for a fixed scorer.
enum SemanticKeepEcho {
    static let markerTag = "semantic-echo"
    static let sourceTagPrefix = "semantic-echo-source:"
    static let lineTagPrefix = "semantic-echo-line:"

    struct Echo: Equatable {
        var sourcePageID: String
        var excerpt: String
        var monthLine: String
        var similarity: Double
        var line: String
    }

    /// Same age bar as the word echo: recognition, not repetition.
    static let minimumAgeDays = KeepEcho.minimumAgeDays
    /// Far above the Stacks search-relevance floor: the Book claims a felt
    /// connection only when the embedding is nearly certain.
    static let similarityFloor = 0.55
    /// Both sentences need enough body to carry a feeling.
    static let minimumWordCount = 6
    /// Keep-time cost bound, only the strongest archive prose is compared.
    static let maximumCandidates = 120

    /// The one scorer reused across keeps: the sentence-embedding model is not
    /// free to load, and its first touch should happen off the main thread.
    static let keepTimeScorer: StacksSemanticScoring? = {
        #if canImport(NaturalLanguage)
        return NaturalLanguageStacksEmbeddingScorer()
        #else
        return nil
        #endif
    }()

    static func find(
        for input: String,
        pageType: BookPageType,
        pageID: String,
        in days: [BookDay],
        scorer: StacksSemanticScoring?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Echo? {
        guard let scorer else { return nil }
        guard !EditionCurator.defaultPrivateTypes.contains(pageType) else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wordCount(of: trimmed) >= minimumWordCount else { return nil }
        let inputWords = contentWords(in: trimmed)

        let cutoff = now.addingTimeInterval(TimeInterval(-minimumAgeDays) * 86_400)
        let rankedCandidates: [(page: BookPage, text: String)] = days.flatMap(\.capturedPages)
            .compactMap { page in
                guard page.createdAt <= cutoff,
                      page.id != pageID,
                      !EditionCurator.defaultPrivateTypes.contains(page.type),
                      let text = page.readerAuthoredTextForAnalysis,
                      wordCount(of: text) >= minimumWordCount,
                      contentWords(in: text).isDisjoint(with: inputWords) else { return nil }
                return (page, text)
            }
            .sorted { left, right in
                let leftSpark = StorySpark.score(left.text)
                let rightSpark = StorySpark.score(right.text)
                if leftSpark != rightSpark { return leftSpark > rightSpark }
                if left.page.createdAt != right.page.createdAt { return left.page.createdAt > right.page.createdAt }
                return left.page.id < right.page.id
            }
        let candidates = Array(rankedCandidates.prefix(maximumCandidates))
        guard !candidates.isEmpty else { return nil }

        var best: (page: BookPage, text: String, similarity: Double)?
        for candidate in candidates {
            guard let similarity = scorer.similarity(between: trimmed, and: candidate.text),
                  similarity >= similarityFloor else { continue }
            if let current = best {
                if similarity > current.similarity
                    || (similarity == current.similarity && candidate.page.createdAt < current.page.createdAt) {
                    best = (candidate.page, candidate.text, similarity)
                }
            } else {
                best = (candidate.page, candidate.text, similarity)
            }
        }
        guard let best else { return nil }

        let month = best.page.createdAt.formatted(.dateTime.month(.wide))
        let sameYear = calendar.component(.year, from: best.page.createdAt)
            == calendar.component(.year, from: now)
        let year = calendar.component(.year, from: best.page.createdAt)
        let monthLine = sameYear ? "back in \(month)" : "in \(month) \(year)"
        let excerpt = excerpt(of: best.text)

        let seed = KeepMarginalia.seed(for: pageID)
        let lines = [
            "This page and one from \(monthLine): \u{201C}\(excerpt)\u{201D}: are the same feeling wearing different words.",
            "The Book set this beside a page from \(monthLine): \u{201C}\(excerpt)\u{201D}. Different words. Same weather.",
            "Somewhere \(monthLine) you wrote \u{201C}\(excerpt)\u{201D}. Today\u{2019}s page answers it. The Book cannot say how it knows. It knows."
        ]
        return Echo(
            sourcePageID: best.page.id,
            excerpt: excerpt,
            monthLine: monthLine,
            similarity: best.similarity,
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

    static func tags(for echo: Echo) -> [String] {
        [
            markerTag,
            "\(sourceTagPrefix)\(echo.sourcePageID)",
            "\(lineTagPrefix)\(echo.line)"
        ]
    }

    /// The quoted fragment of the old page: its first sentence, clipped on a
    /// word boundary so the toast never carries a wall of text.
    static func excerpt(of text: String, limit: Int = 64) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstSentence = trimmed
            .split(omittingEmptySubsequences: true) { ".!?\n".contains($0) }
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? trimmed
        guard firstSentence.count > limit else { return firstSentence }
        let clipped = firstSentence.prefix(limit)
        let lastSpace = clipped.lastIndex(of: " ") ?? clipped.endIndex
        return String(clipped[..<lastSpace]) + "\u{2026}"
    }

    /// Words that would let string matching take credit for the connection.
    /// Four letters is deliberately stricter than the word echo's five:
    /// "rain" or "dark" shared between the two pages would already explain
    /// the rhyme the ordinary way.
    static func contentWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count >= 4 && !KeepMarginalia.stopWords.contains($0) }
        )
    }

    private static func wordCount(of text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }
}

// MARK: - The Semantic Notice

/// The same word-disjoint "same feeling" recognition as `SemanticKeepEcho`,
/// but surfaced on the Book Notices page instead of at the keep moment. It
/// anchors on the reader's most recent substantial prose page and finds the
/// older page that rhymes with it in feeling while sharing no content word:
/// a connection recurrence-counting could never make, sitting beside the
/// recurrence observations as their stranger cousin.
struct SemanticNoticePairing: Equatable {
    var anchorPageID: String
    var anchorExcerpt: String
    var sourcePageID: String
    var sourceExcerpt: String
    var monthLine: String
    var similarity: Double

    /// How recent the anchor page must be to count as "what you're writing now."
    static let anchorWindowDays = 10

    static func find(
        days: [BookDay],
        scorer: StacksSemanticScoring?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SemanticNoticePairing? {
        guard let scorer else { return nil }
        let anchorCutoff = now.addingTimeInterval(TimeInterval(-anchorWindowDays) * 86_400)
        let anchorCandidate = days.flatMap(\.capturedPages)
            .compactMap { page -> (page: BookPage, text: String)? in
                guard let text = page.readerAuthoredTextForAnalysis,
                      page.createdAt >= anchorCutoff,
                      page.createdAt <= now,
                      !EditionCurator.defaultPrivateTypes.contains(page.type),
                      text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count >= SemanticKeepEcho.minimumWordCount
                else { return nil }
                return (page, text)
            }
            .max { $0.page.createdAt < $1.page.createdAt }
        guard let anchorCandidate else { return nil }
        let anchor = anchorCandidate.page
        let anchorText = anchorCandidate.text

        // Reuse the keep-time engine: the best word-disjoint semantic match at
        // least two weeks older than the anchor.
        guard let echo = SemanticKeepEcho.find(
            for: anchorText,
            pageType: anchor.type,
            pageID: anchor.id,
            in: days,
            scorer: scorer,
            now: now,
            calendar: calendar
        ) else { return nil }

        return SemanticNoticePairing(
            anchorPageID: anchor.id,
            anchorExcerpt: SemanticKeepEcho.excerpt(of: anchorText),
            sourcePageID: echo.sourcePageID,
            sourceExcerpt: echo.excerpt,
            monthLine: echo.monthLine,
            similarity: echo.similarity
        )
    }

    /// The Book's own paragraph for the Notices page: a felt connection it
    /// cannot explain, told plainly and without a scorecard.
    var noticeParagraph: String {
        "And something stranger than recurrence: two pages that share no words but the same weather. Lately you wrote \u{201C}\(anchorExcerpt)\u{201D}, and \(monthLine) you wrote \u{201C}\(sourceExcerpt)\u{201D}. Nothing links them but a feeling. I cannot say how I know they belong together. I only know I set them side by side and did not want to separate them."
    }
}
