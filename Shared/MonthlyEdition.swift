import Foundation

typealias KeptWeeklyIssueArtifact = WeeklyIssue
typealias KeptMonthlyEditionArtifact = MonthlyEdition

struct MonthlyEdition: Codable, Equatable {
    var title: String
    var subtitle: String
    var generatedAt: Date
    var startDate: Date
    var endDate: Date
    var dayCount: Int
    var pageCount: Int
    var readerName: String
    var chapterNumber: Int
    var monthName: String
    var theme: BookTheme?
    var constellations: [Constellation]
    var foreword: String
    var sections: [MonthlyEditionSection]
    var continuity: LiteraryContinuityDigest
    var howYouSee: HowYouSee.SeeingReceipt?
    /// The month's closing, in the Book's voice. The builder always fills this
    /// with the deterministic `BookForewordWriter.closing(...)`; the app may
    /// overwrite it with a Gemma-written conclusion before binding. Optional so
    /// older saved editions still decode.
    var closing: String?
    /// One continuous local-brain story made from the month's daily bindings.
    /// Optional so older bound editions remain readable.
    var bindingStory: String? = nil

    /// "The Book of You - bj - Chapter 3 - June"
    var chapterHeading: String {
        "The Book of You - \(readerName) - Chapter \(chapterNumber) - \(monthName)"
    }

    var isEmpty: Bool {
        pageCount == 0 && sections.allSatisfy(\.items.isEmpty)
    }

    var isThinBinding: Bool {
        dayCount > 0 && dayCount < 7
    }

    var memorySpinePromptLines: [String] {
        guard let spine = sections.first(where: { $0.id == "book-memory-spine" }) else { return [] }
        return spine.items.prefix(5).map { item in
            let body = item.body
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(item.title): \(body)"
        }
    }
}

/// A whole year, bound as a real book: a year-level foreword and closing wrap a
/// sequence of fully-built month-chapters, each with its own theme and star
/// chart. See `MonthlyEditionBuilder.annual`.
struct AnnualEdition: Codable, Equatable {
    var title: String
    var subtitle: String
    var year: Int
    var readerName: String
    var generatedAt: Date
    var startDate: Date
    var endDate: Date
    var dayCount: Int
    var pageCount: Int
    var foreword: String
    var chapters: [MonthlyEdition]
    var constellations: [Constellation]
    var wagers: [BookWager]
    var closing: String
    var continuity: LiteraryContinuityDigest
    /// Year-level residue from Book of You pages: the annual's private index of
    /// refrains, callbacks, questions, and cover-story candidates. Optional so
    /// older saved annuals still decode.
    var memorySpine: AnnualMemorySpine?

    var isEmpty: Bool { chapters.isEmpty }

    /// The named threads carried across the whole year, for the back matter.
    var namedConstellations: [Constellation] {
        ConstellationKeeper.namedConstellations(constellations)
    }
}

struct AnnualMemorySpine: Codable, Equatable {
    var motifs: [String]
    var callbacks: [String]
    var coverStories: [String]
    var openQuestions: [String]

    var isEmpty: Bool {
        motifs.isEmpty && callbacks.isEmpty && coverStories.isEmpty && openQuestions.isEmpty
    }

    static func from(days: [BookDay], now: Date = Date()) -> AnnualMemorySpine? {
        let digest = BindingMemorySpine.digest(days: days, now: now, limit: 96)
        guard !digest.braids.isEmpty else { return nil }
        let motifs = digest.motifCounts.prefix(12).map { "\($0.motif) (\($0.count))" }
        let callbackLines = digest.braids
            .compactMap { memory -> String? in
                guard let callback = memory.residue.callbackCandidate?.nonEmpty else { return nil }
                return "\(memory.residue.title): \(callback)"
            }
        let callbacks = Array(callbackLines.prefix(16))
        let coverStories = digest.braids
            .prefix(12)
            .map { "\($0.residue.title): \($0.residue.spineLine)" }
        let questionLines = digest.braids
            .compactMap(\.residue.openedQuestion)
        let questions = Array(questionLines.prefix(8))
        let spine = AnnualMemorySpine(
            motifs: motifs,
            callbacks: callbacks,
            coverStories: coverStories,
            openQuestions: questions
        )
        return spine.isEmpty ? nil : spine
    }
}

struct MonthlyEditionSection: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var note: String
    var items: [MonthlyEditionItem]
}

struct MonthlyEditionItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case page
        case image
        case continuity
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String
    var date: Date?
    var pageType: BookPageType?
    var sourceID: String?
    var mediaAssets: [BookPageMediaAsset]
    var tags: [String]
}

enum MonthlyEditionBuilder {
    static func previousMonth(
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        readerName: String = "friend",
        now: Date = Date(),
        calendar: Calendar = .current,
        includePrivateWeatherSummary: Bool = false
    ) -> MonthlyEdition {
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let end = calendar.date(byAdding: .second, value: -1, to: currentMonthStart) ?? now
        return edition(
            from: days,
            events: events,
            entityMemories: entityMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            constellations: constellations,
            wagers: wagers,
            themes: themes,
            readerName: readerName,
            startDate: start,
            endDate: end,
            generatedAt: now,
            calendar: calendar,
            includePrivateWeatherSummary: includePrivateWeatherSummary
        )
    }

    /// The annual: a whole year bound as a real book of twelve month-chapters,
    /// each keeping its own theme, foreword, and star chart, wrapped in a
    /// year-level foreword, a table of the year, and a closing. Only months that
    /// kept pages become chapters. Pure-local and deterministic — the same year
    /// always binds the same way.
    static func annual(
        _ year: Int,
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        readerName: String = "friend",
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnnualEdition {
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let nextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
        let yearEnd = calendar.date(byAdding: .second, value: -1, to: nextYear) ?? now

        // Build a chapter for every month of the year that kept pages.
        var chapters: [MonthlyEdition] = []
        for month in 1...12 {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let monthEnd = calendar.date(byAdding: .second, value: -1, to: nextMonth) else { continue }
            let chapter = edition(
                from: days,
                events: events,
                entityMemories: entityMemories,
                entityBelief: entityBelief,
                pageBelief: pageBelief,
                constellations: constellations,
                wagers: wagers,
                themes: themes,
                readerName: readerName,
                startDate: monthStart,
                endDate: monthEnd,
                generatedAt: now,
                calendar: calendar,
                includePrivateWeatherSummary: false
            )
            if !chapter.isEmpty { chapters.append(chapter) }
        }

        // A year-level reading of the whole span, for the grand foreword.
        let yearDays = BookArchiveExport(days: days, calendar: calendar).days.filter { day in
            day.date >= calendar.startOfDay(for: yearStart) && day.date <= calendar.startOfDay(for: yearEnd)
        }
        let yearPages = yearDays.flatMap(\.pages)
        let yearEvents = events.filter { $0.createdAt >= yearStart && $0.createdAt <= yearEnd }
        let yearMemories = entityMemories.filter { $0.createdAt >= yearStart && $0.createdAt <= yearEnd }
        let yearContinuity = LiteraryContinuityProjector.digest(
            days: yearDays,
            events: yearEvents,
            entityMemories: yearMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            now: now,
            calendar: calendar
        )
        let yearWagers = wagers.filter { wager in
            wager.sealedAt <= yearEnd && (wager.resolvedAt.map { $0 >= yearStart } ?? true)
        }

        let foreword = BookForewordWriter.annualForeword(
            year: year,
            chapters: chapters,
            pageCount: yearPages.count,
            dayCount: yearDays.count,
            continuity: yearContinuity,
            constellations: constellations,
            wagers: yearWagers,
            calendar: calendar
        )
        let closing = BookForewordWriter.annualClosing(year: year, chapters: chapters)

        return AnnualEdition(
            title: "Book of You: The \(year) Annual",
            subtitle: "\(readerName) — a year, bound",
            year: year,
            readerName: readerName,
            generatedAt: now,
            startDate: yearStart,
            endDate: yearEnd,
            dayCount: chapters.reduce(0) { $0 + $1.dayCount },
            pageCount: chapters.reduce(0) { $0 + $1.pageCount },
            foreword: foreword,
            chapters: chapters,
            constellations: constellations,
            wagers: yearWagers,
            closing: closing,
            continuity: yearContinuity,
            memorySpine: AnnualMemorySpine.from(days: yearDays, now: now)
        )
    }

    static func edition(
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        readerName: String = "friend",
        startDate: Date,
        endDate: Date,
        generatedAt: Date = Date(),
        calendar: Calendar = .current,
        includePrivateWeatherSummary: Bool = false
    ) -> MonthlyEdition {
        let monthDays = BookArchiveExport(days: days, calendar: calendar).days.filter { day in
            day.date >= calendar.startOfDay(for: startDate) && day.date <= calendar.startOfDay(for: endDate)
        }
        let pages = monthDays.flatMap(\.pages).sorted { $0.createdAt < $1.createdAt }
        let monthEvents = events.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let monthMemories = entityMemories.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let continuity = LiteraryContinuityProjector.digest(
            days: monthDays,
            events: monthEvents,
            entityMemories: monthMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            now: generatedAt,
            calendar: calendar
        )

        let monthKey = BookThemeEngine.monthKey(for: startDate, calendar: calendar)
        let theme = BookThemeEngine.theme(forMonth: monthKey, in: themes)
            ?? BookThemeEngine.theme(
                for: pages,
                digest: continuity,
                constellations: constellations,
                monthKey: monthKey,
                now: generatedAt
            )
        let chapterNumber = chapterNumber(forMonthStarting: startDate, in: days, calendar: calendar)

        // Curate before binding: the month kept everything, but the book is
        // selective. The curator keeps the expressive and authored pages, sips
        // only the strongest of the daily logs, and tells us what it set aside.
        let curated = EditionCurator.curate(pages, now: generatedAt)
        let boundPages = curated.pages
        let privateWeatherSection = includePrivateWeatherSummary
            ? fuelAndInnerWeatherSection(from: pages, calendar: calendar)
            : MonthlyEditionSection(id: "fuel-and-inner-weather", title: "Fuel & Inner Weather", note: "", items: [])

        let title = "Book of You: \(monthTitle(for: startDate, calendar: calendar))"
        let subtitle = theme?.name ?? "\(dateLine(startDate, calendar: calendar)) - \(dateLine(endDate, calendar: calendar))"
        let sections = [
            themeSection(theme, pages: boundPages),
            worldEventSection(from: boundPages),
            memorySpineSection(from: monthDays, generatedAt: generatedAt),
            openingSection(from: boundPages, continuity: continuity, setAsideLine: curated.setAsideLine),
            pageSection(
                id: "daily-braids",
                title: "Daily Braids",
                note: "The Book of You pages that gathered the month into nightly thread.",
                pages: boundPages.filter { $0.type == .bookOfYou },
                limit: 31
            ),
            privateWeatherSection,
            pageSection(
                id: "souvenirs",
                title: "One-Sentence Souvenirs",
                note: "Small bright fragments, preserved before the month could blur them.",
                pages: boundPages.filter { $0.type == .souvenir },
                limit: 40
            ),
            scrapbookSection(from: boundPages),
            pageSection(
                id: "letters",
                title: "Letters And Voices",
                note: "Correspondence, gossip, story pages, and faculty notes that spoke back.",
                pages: boundPages.filter { [.letter, .narrativeOS, .bookConnections, .gossip, .facultyResearch, .supportGuild, .bookNotices].contains($0.type) },
                limit: 36
            ),
            imageSection(from: boundPages),
            pageSection(
                id: "other-kept-pages",
                title: "Other Kept Pages",
                note: "Weather, anchors, enchantments, classes, questions, and other margins worth binding.",
                pages: boundPages.filter { page in
                    !EditionCurator.isScrapbookPage(page)
                        && ![.bookOfYou, .souvenir, .letter, .narrativeOS, .bookConnections, .gossip, .facultyResearch, .supportGuild, .bookNotices, .illuminatedPhoto, .illustration, .enchantment].contains(page.type)
                },
                limit: 48
            )
        ].filter { !$0.items.isEmpty }

        return MonthlyEdition(
            title: title,
            subtitle: subtitle,
            generatedAt: generatedAt,
            startDate: startDate,
            endDate: endDate,
            dayCount: monthDays.count,
            pageCount: boundPages.count,
            readerName: readerName,
            chapterNumber: chapterNumber,
            monthName: monthTitle(for: startDate, calendar: calendar),
            theme: theme,
            constellations: constellations,
            foreword: BookForewordWriter.foreword(
                monthTitle: monthTitle(for: startDate, calendar: calendar),
                pages: boundPages,
                dayCount: monthDays.count,
                continuity: continuity,
                constellations: constellations,
                wagers: wagers.filter { wager in
                    wager.sealedAt <= endDate && (wager.resolvedAt.map { $0 >= startDate } ?? true)
                },
                calendar: calendar
            ),
            sections: sections,
            continuity: continuity,
            howYouSee: {
                guard endDate >= generatedAt.addingTimeInterval(-30 * 86_400) else { return nil }
                return HowYouSee.receipt(days: days, now: generatedAt)
            }(),
            closing: BookForewordWriter.closing(
                monthTitle: monthTitle(for: startDate, calendar: calendar),
                pages: boundPages,
                dayCount: monthDays.count,
                continuity: continuity,
                constellations: constellations,
                theme: theme,
                calendar: calendar
            )
        )
    }

    private static func memorySpineSection(from days: [BookDay], generatedAt: Date) -> MonthlyEditionSection {
        let digest = BindingMemorySpine.digest(days: days, now: generatedAt, limit: 31)
        guard !digest.braids.isEmpty else {
            return MonthlyEditionSection(id: "book-memory-spine", title: "Book Memory Spine", note: "", items: [])
        }

        var items: [MonthlyEditionItem] = []
        if let lead = digest.braids.first {
            items.append(MonthlyEditionItem(
                id: "memory-spine-cover-story",
                kind: .continuity,
                title: "Cover Story",
                body: cleanedBookText("\(lead.residue.title)\n\n\(lead.residue.callbackCandidate ?? lead.residue.keptLine)"),
                date: lead.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "cover-story"]
            ))
        }

        if !digest.motifCounts.isEmpty {
            let motifs = digest.motifCounts.prefix(8).map { "\($0.motif) (\($0.count))" }
            items.append(MonthlyEditionItem(
                id: "memory-spine-refrain",
                kind: .continuity,
                title: "The Month's Refrain",
                body: "Across the nightly braids, these motifs kept returning: \(naturalList(Array(motifs))).",
                date: digest.braids.first?.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "motifs"]
            ))
        }

        let callbacks = digest.braids
            .compactMap { memory -> String? in
                guard let callback = memory.residue.callbackCandidate?.nonEmpty else { return nil }
                return "\(memory.residue.title): \(callback)"
            }
            .prefix(6)
        if !callbacks.isEmpty {
            items.append(MonthlyEditionItem(
                id: "memory-spine-callbacks",
                kind: .continuity,
                title: "Pages That Kept Answering",
                body: callbacks.joined(separator: "\n"),
                date: digest.braids.first?.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "callbacks"]
            ))
        }

        let questions = digest.braids
            .compactMap(\.residue.openedQuestion)
            .prefix(4)
        if !questions.isEmpty {
            items.append(MonthlyEditionItem(
                id: "memory-spine-open-questions",
                kind: .continuity,
                title: "Questions Still Warm",
                body: questions.joined(separator: "\n"),
                date: digest.braids.first?.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "questions"]
            ))
        }

        return MonthlyEditionSection(
            id: "book-memory-spine",
            title: "Book Memory Spine",
            note: "The nightly Book of You pages, read as callbacks, refrains, and open questions.",
            items: items
        )
    }

    /// Chapter N = this month's position among all months that have kept
    /// pages, so the bound volumes read as a continuing book.
    private static func chapterNumber(forMonthStarting startDate: Date, in days: [BookDay], calendar: Calendar) -> Int {
        let editionKey = BookThemeEngine.monthKey(for: startDate, calendar: calendar)
        let monthKeys = Set(
            days.filter { !$0.pages.isEmpty }
                .map { BookThemeEngine.monthKey(for: $0.date, calendar: calendar) }
        )
        .union([editionKey])
        .sorted()
        return (monthKeys.firstIndex(of: editionKey) ?? 0) + 1
    }

    private static func themeSection(_ theme: BookTheme?, pages: [BookPage]) -> MonthlyEditionSection {
        guard let theme else {
            return MonthlyEditionSection(id: "the-months-theme", title: "The Month's Theme", note: "", items: [])
        }
        var items: [MonthlyEditionItem] = [
            MonthlyEditionItem(
                id: theme.id,
                kind: .continuity,
                title: theme.name,
                body: cleanedBookText("\(theme.line)\n\n\(theme.stabilityDetail)"),
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["theme"] + theme.motifs
            )
        ]
        for (index, excerpt) in theme.excerptLines.enumerated() {
            let cleaned = cleanedBookText(excerpt)
            guard isUsableThemeExcerpt(cleaned) else { continue }
            items.append(MonthlyEditionItem(
                id: "\(theme.id)-excerpt-\(index)",
                kind: .continuity,
                title: "From the pages",
                body: "\u{201C}\(cleaned)\u{201D}",
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["theme-excerpt"]
            ))
        }
        return MonthlyEditionSection(
            id: "the-months-theme",
            title: "The Month's Theme",
            note: theme.isStable
                ? "One current the Book found running under the month, named and held up to the light."
                : "One early current the Book found running under the month, still marked provisional.",
            items: items
        )
    }

    private static func openingSection(
        from pages: [BookPage],
        continuity: LiteraryContinuityDigest,
        setAsideLine: String? = nil
    ) -> MonthlyEditionSection {
        var items: [MonthlyEditionItem] = []
        let typeCounts = Dictionary(grouping: pages, by: \.type).mapValues(\.count)
        let strongest = typeCounts.sorted { left, right in
            if left.value == right.value { return left.key.title < right.key.title }
            return left.value > right.value
        }.prefix(5)
        if !strongest.isEmpty {
            items.append(MonthlyEditionItem(
                id: "month-shape",
                kind: .continuity,
                title: "Shape Of The Month",
                body: strongest.map { "\($0.key.title): \($0.value)" }.joined(separator: "\n"),
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "shape"]
            ))
        }
        let signals = continuity.strongestSignals
        let patternSignals = signals.filter { $0.kind == .pattern }
        if !patternSignals.isEmpty {
            items.append(MonthlyEditionItem(
                id: "returning-language",
                kind: .continuity,
                title: "Returning Language",
                body: returningLanguageLine(from: patternSignals),
                date: patternSignals.map(\.lastSeenAt).max(),
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "language", "pattern"]
            ))
        }
        for signal in signals.filter({ $0.kind != .pattern }).prefix(5) {
            items.append(MonthlyEditionItem(
                id: signal.id,
                kind: .continuity,
                title: signal.subjectName,
                body: monthlySignalLine(signal),
                date: signal.lastSeenAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: signal.tags
            ))
        }
        if let setAsideLine {
            items.append(MonthlyEditionItem(
                id: "kept-not-bound",
                kind: .continuity,
                title: "Kept, Not Bound",
                body: setAsideLine,
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "curation"]
            ))
        }
        return MonthlyEditionSection(
            id: "the-book-notices",
            title: "What The Book Noticed",
            note: "Connections, absences, durations, and living Beliefs gathered from the month.",
            items: items
        )
    }

    private static func returningLanguageLine(from signals: [LiteraryContinuitySignal]) -> String {
        let names = signals.prefix(6).map(\.subjectName)
        let motifLine = naturalList(names)
        let recentNames = signals
            .filter { $0.tags.contains("recent-events") }
            .prefix(3)
            .map(\.subjectName)
        let recentLine = recentNames.isEmpty
            ? ""
            : " \(naturalList(recentNames)) also crossed into recent events."
        return "Certain words kept finding their way back: \(motifLine). The Book treats them as motifs and atmosphere, not as a scorecard.\(recentLine)"
    }

    private static func monthlySignalLine(_ signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .absence:
            return signal.line
        case .duration:
            return signal.line
        case .beliefLifecycle:
            return signal.line
        case .pattern:
            return signal.line
        case .listening:
            return signal.line
        case .manner:
            return signal.line
        }
    }

    private static func fuelAndInnerWeatherSection(from pages: [BookPage], calendar: Calendar) -> MonthlyEditionSection {
        let privatePages = pages
            .filter { $0.type == .fuel || $0.type == .body }
            .sorted { $0.createdAt < $1.createdAt }
        guard !privatePages.isEmpty else {
            return MonthlyEditionSection(id: "fuel-and-inner-weather", title: "Fuel & Inner Weather", note: "", items: [])
        }

        let fuelCount = privatePages.filter { $0.type == .fuel }.count
        let bodyCount = privatePages.filter { $0.type == .body }.count
        let dayCount = Set(privatePages.map { calendar.startOfDay(for: $0.createdAt) }).count
        let days = dayCount == 1 ? "one day" : "\(dayCount) days"
        let counts = [
            fuelCount > 0 ? "\(fuelCount == 1 ? "one fuel note" : "\(fuelCount) fuel notes")" : nil,
            bodyCount > 0 ? "\(bodyCount == 1 ? "one inner-weather note" : "\(bodyCount) inner-weather notes")" : nil
        ].compactMap { $0 }

        var items: [MonthlyEditionItem] = [
            MonthlyEditionItem(
                id: "fuel-weather-overview",
                kind: .continuity,
                title: "Private Weather, Summarized",
                body: "With permission, the Book looked at \(naturalList(counts)) across \(days). It keeps this as pattern-weather, not diagnosis: clues about how the month moved through appetite, energy, body, and mood.",
                date: privatePages.first?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather"]
            )
        ]

        let timePatterns = timeOfDayPatterns(from: privatePages, calendar: calendar)
        if !timePatterns.isEmpty {
            items.append(MonthlyEditionItem(
                id: "fuel-weather-time-patterns",
                kind: .continuity,
                title: "When It Appeared",
                body: timePatterns,
                date: privatePages.last?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather", "pattern"]
            ))
        }

        let motifLine = privateWeatherMotifs(from: privatePages)
        if !motifLine.isEmpty {
            items.append(MonthlyEditionItem(
                id: "fuel-weather-motifs",
                kind: .continuity,
                title: "Words That Carried Weight",
                body: motifLine,
                date: privatePages.last?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather", "language"]
            ))
        }

        let pairedDays = pairedFuelWeatherDays(from: privatePages, calendar: calendar)
        if pairedDays > 0 {
            let line = pairedDays == 1
                ? "On one day, fuel and inner weather were both kept. The Book treats that as a useful place to be gentle and curious, not as proof of cause."
                : "On \(pairedDays) days, fuel and inner weather were both kept. The Book treats those overlaps as useful places to be gentle and curious, not as proof of cause."
            items.append(MonthlyEditionItem(
                id: "fuel-weather-overlaps",
                kind: .continuity,
                title: "Where They Touched",
                body: line,
                date: privatePages.last?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather", "connection"]
            ))
        }

        return MonthlyEditionSection(
            id: "fuel-and-inner-weather",
            title: "Fuel & Inner Weather",
            note: "An opt-in private summary of body, fuel, mood, and energy patterns. No raw logs, no medical claims.",
            items: items
        )
    }

    private static func timeOfDayPatterns(from pages: [BookPage], calendar: Calendar) -> String {
        let buckets = Dictionary(grouping: pages) { page -> String in
            let hour = calendar.component(.hour, from: page.createdAt)
            switch hour {
            case 5..<12: return "morning"
            case 12..<17: return "afternoon"
            case 17..<22: return "evening"
            default: return "night"
            }
        }
        let parts = buckets
            .sorted { left, right in
                if left.value.count == right.value.count { return left.key < right.key }
                return left.value.count > right.value.count
            }
            .prefix(2)
            .map { "\($0.key) (\($0.value.count))" }
        guard !parts.isEmpty else { return "" }
        return "These notes gathered most often around \(naturalList(Array(parts))). The timing may be ordinary logistics; the Book only marks where attention kept landing."
    }

    private static func privateWeatherMotifs(from pages: [BookPage]) -> String {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "because", "been", "being", "body", "could",
            "day", "did", "does", "dont", "down", "feel", "felt", "fuel", "have", "into",
            "just", "like", "little", "more", "much", "note", "only", "really", "some",
            "still", "that", "the", "then", "there", "this", "today", "very", "was",
            "were", "what", "when", "with", "would", "your"
        ]
        let text = pages
            .map { cleanedBookText($0.userInput.isEmpty ? $0.promptText : $0.userInput).lowercased() }
            .joined(separator: " ")
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 && !stopWords.contains($0) && Int($0) == nil }
        let counts = Dictionary(grouping: words, by: { $0 }).mapValues(\.count)
        let motifs = counts
            .filter { $0.value >= 2 }
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .prefix(5)
            .map(\.key)
        guard !motifs.isEmpty else { return "" }
        return "A few words kept weight in the private weather: \(naturalList(Array(motifs))). The Book would read them as invitations to notice conditions, not verdicts about you."
    }

    private static func pairedFuelWeatherDays(from pages: [BookPage], calendar: Calendar) -> Int {
        let byDay = Dictionary(grouping: pages) { calendar.startOfDay(for: $0.createdAt) }
        return byDay.values.filter { group in
            group.contains { $0.type == .fuel } && group.contains { $0.type == .body }
        }.count
    }

    private static func naturalList(_ values: [String]) -> String {
        let cleaned = values.filter { !$0.isEmpty }
        switch cleaned.count {
        case 0:
            return "a few quiet motifs"
        case 1:
            return cleaned[0]
        case 2:
            return "\(cleaned[0]) and \(cleaned[1])"
        default:
            return "\(cleaned.dropLast().joined(separator: ", ")), and \(cleaned.last ?? "")"
        }
    }

    private static func worldEventSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let eventPages = pages.filter { page in
            page.tags.contains("world-event") || page.tags.contains { $0.hasPrefix("event:") }
        }
        guard !eventPages.isEmpty else {
            return MonthlyEditionSection(id: "world-events", title: "World Events", note: "", items: [])
        }
        let eventIDs = eventPages
            .flatMap { page in page.tags.compactMap { $0.hasPrefix("event:") ? String($0.dropFirst("event:".count)) : nil } }
        let counts = Dictionary(grouping: eventIDs, by: { $0 }).mapValues(\.count)
        var summaryLines = counts
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .map { "\($0.key.replacingOccurrences(of: "-", with: " ").capitalized): \($0.value) kept page\($0.value == 1 ? "" : "s")" }
        let outcomeIDs = eventPages
            .flatMap { page in page.tags.compactMap { $0.hasPrefix("event-outcome:") ? String($0.dropFirst("event-outcome:".count)) : nil } }
        if let strongestOutcome = Dictionary(grouping: outcomeIDs, by: { $0 }).mapValues(\.count)
            .sorted(by: { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            })
            .first {
            summaryLines.append("Strongest outcome: \(strongestOutcome.key.replacingOccurrences(of: "-", with: " ").capitalized)")
        }
        let summary = summaryLines.joined(separator: "\n")
        let item = MonthlyEditionItem(
            id: "world-events-summary",
            kind: .continuity,
            title: "Temporary Physics",
            body: summary.isEmpty ? "A world event touched the month and left traces in the kept pages." : summary,
            date: eventPages.map(\.createdAt).min(),
            pageType: nil,
            sourceID: nil,
            mediaAssets: [],
            tags: ["world-event", "monthly-edition"]
        )
        return MonthlyEditionSection(
            id: "world-events",
            title: "World Events",
            note: "The weeks when the Book's rules changed and the pages learned to behave differently.",
            items: [item] + eventPages.prefix(10).map(pageItem)
        )
    }

    private static func pageSection(
        id: String,
        title: String,
        note: String,
        pages: [BookPage],
        limit: Int
    ) -> MonthlyEditionSection {
        MonthlyEditionSection(
            id: id,
            title: title,
            note: note,
            items: pages.prefix(limit).map(pageItem)
        )
    }

    private static func imageSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let imagePages = pages.filter { page in
            !EditionCurator.isScrapbookPage(page)
                && (page.type == .illuminatedPhoto || page.type == .illustration || page.type == .enchantment || !page.mediaAssets.isEmpty)
        }
        return MonthlyEditionSection(
            id: "images",
            title: "Images And Illuminations",
            note: "Saved plates, enchantments, and image-bearing pages.",
            items: imagePages.prefix(28).map { page in
                var item = pageItem(page)
                item.kind = .image
                return item
            }
        )
    }

    private static func scrapbookSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let scrapbookPages = pages.filter(EditionCurator.isScrapbookPage)
        return MonthlyEditionSection(
            id: "scrapbook-pages",
            title: "Scrapbook Pages",
            note: "Pages the reader composed by hand from kept scraps, notes, marks, and images.",
            items: scrapbookPages.prefix(12).map { page in
                var item = pageItem(page)
                item.kind = page.mediaAssets.isEmpty ? .page : .image
                item.title = scrapbookTitle(for: page)
                return item
            }
        )
    }

    private static func pageItem(_ page: BookPage) -> MonthlyEditionItem {
        MonthlyEditionItem(
            id: page.id,
            kind: page.mediaAssets.isEmpty ? .page : .image,
            title: EditionCurator.isScrapbookPage(page) ? scrapbookTitle(for: page) : page.type.title,
            body: pageBody(page),
            date: page.createdAt,
            pageType: page.type,
            sourceID: page.sourceID,
            mediaAssets: page.mediaAssets,
            tags: page.tags
        )
    }

    private static func pageBody(_ page: BookPage) -> String {
        let userInput = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = userInput.isEmpty ? page.promptText.trimmingCharacters(in: .whitespacesAndNewlines) : userInput
        return excerptForMonthlyBinding(cleanedBookText(raw), pageType: page.type)
    }

    private static func scrapbookTitle(for page: BookPage) -> String {
        let title = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Scrapbook Page" : title
    }

    private static func isUsableThemeExcerpt(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return false }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("research note for") { return false }
        if lowered == "faculty:" || lowered.hasPrefix("faculty: dr.") { return false }
        if lowered.contains("focus:") && lowered.contains("faculty:") { return false }
        return true
    }

    static func cleanedBookText(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                if lines.last?.isEmpty == false { lines.append("") }
                continue
            }
            if line.allSatisfy({ $0 == "*" || $0 == "-" || $0 == "_" }) { continue }
            while line.hasPrefix("#") {
                line.removeFirst()
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                line.removeFirst(2)
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            line = line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "  ", with: " ")
            lines.append(line)
        }
        return lines
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func excerptForMonthlyBinding(_ text: String, pageType: BookPageType) -> String {
        let limit = monthlyExcerptLimit(for: pageType)
        guard text.count > limit else { return text }

        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var chosen: [String] = []
        var count = 0
        for paragraph in paragraphs {
            let nextCount = count + paragraph.count
            if nextCount > limit { break }
            chosen.append(paragraph)
            count = nextCount
            if count >= Int(Double(limit) * 0.65) { break }
        }

        let excerpt: String
        if chosen.isEmpty {
            excerpt = prefixAtWordBoundary(text, limit: limit)
        } else {
            excerpt = chosen.joined(separator: "\n\n")
        }
        return "\(excerpt)\n\n[Excerpted for the monthly binding.]"
    }

    private static func monthlyExcerptLimit(for pageType: BookPageType) -> Int {
        switch pageType {
        case .bookOfYou, .letter, .narrativeOS, .bookConnections, .gossip:
            return 1_800
        case .souvenir:
            return 600
        default:
            return 1_100
        }
    }

    private static func prefixAtWordBoundary(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let cutoff = text.index(text.startIndex, offsetBy: limit)
        let prefix = text[..<cutoff]
        if let lastSpace = prefix.lastIndex(where: { $0.isWhitespace }) {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func monthTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private static func dateLine(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// The Book writes its own foreword: what it noticed, what it named, what it
/// wagered and how those wagers went. Deterministic prose - the same month
/// always gets the same foreword.
enum BookForewordWriter {
    static func foreword(
        monthTitle: String,
        pages: [BookPage],
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        wagers: [BookWager],
        calendar: Calendar = .current
    ) -> String {
        var paragraphs: [String] = []

        let pageLine = pages.count == 1 ? "one page" : "\(pages.count) pages"
        let dayLine = dayCount == 1 ? "a single day" : "\(dayCount) days"
        if dayCount > 0 && dayCount < 7 {
            paragraphs.append("This is a first binding from \(monthTitle): \(pageLine) across \(dayLine), not enough month to name the whole weather, but enough to keep what already refused to disappear. The cover is small and a little proud. I do not bind months to flatter them; I bind them because loose pages get lonely, and I do not want this one to quietly unhappen.")
        } else {
            paragraphs.append("This is what \(monthTitle) left in my keeping: \(pageLine) across \(dayLine), each one kept on purpose. The pages stood close together when I called them. I do not bind months to flatter them; I bind them because loose pages get lonely, and I do not want any of this to quietly unhappen.")
        }

        let signals = continuity.strongestSignals.prefix(3)
        if !signals.isEmpty {
            let lines = signals.map { signal in
                signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
            }
            paragraphs.append("Reading it back, I noticed things I did not notice at the time. \(lines.joined(separator: ". ")). None of this is a verdict. It is the shape attention left behind, with its elbows on the table.")
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if !named.isEmpty {
            let names = named.prefix(3).map(\.displayName)
            let nameLine: String
            switch names.count {
            case 1:
                nameLine = names[0]
            case 2:
                nameLine = "\(names[0]) and \(names[1])"
            default:
                nameLine = "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
            }
            paragraphs.append("Some threads have been with us long enough that I have given them names: \(nameLine). A named constellation is a promise with a little lamp inside it. I will keep watching, which is the only kind of promise a book can make.")
        }

        let opened = wagers.filter { !$0.isSealed }
        let sealed = wagers.filter(\.isSealed)
        if !opened.isEmpty {
            let right = opened.filter { $0.status == .right }.count
            let wrong = opened.count - right
            let scoreLine: String
            if wrong == 0 {
                scoreLine = "Every wager I opened this month came true, which made my spine sit up straighter than was dignified."
            } else if right == 0 {
                scoreLine = "Every wager I opened this month was wrong. I have written each one down anyway. Being wrong in writing is how a book learns without pretending its ink is royal."
            } else {
                scoreLine = "Of the wagers I opened this month, \(right) came true and \(wrong) did not. I record both with the same ink, because the ink does not like favorites."
            }
            paragraphs.append(scoreLine)
        }
        if !sealed.isEmpty {
            paragraphs.append(sealed.count == 1
                ? "One wager is still sealed in the margins. It is trying very hard not to peek. We will both find out."
                : "\(sealed.count) wagers are still sealed in the margins. They are trying very hard not to peek. We will both find out.")
        }

        paragraphs.append("Whatever else this month was, it was read. I put my small paper hand on it and said: stay. - The Book")

        return paragraphs.joined(separator: "\n\n")
    }

    /// The month's conclusion, in the Book's voice. Deterministic and instant —
    /// woven from the same material the foreword opened with, but closed: the
    /// signals that held, the threads that earned names, the theme that insisted.
    /// The app may replace this with a Gemma-written version before binding.
    static func closing(
        monthTitle: String,
        pages: [BookPage],
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        theme: BookTheme?,
        calendar: Calendar = .current
    ) -> String {
        var paragraphs: [String] = []

        let pageLine = pages.count == 1 ? "the single page" : "all \(pages.count) pages"
        paragraphs.append("So \(monthTitle) closes. I have read \(pageLine) back to you and to myself, and what could be kept has been kept. A month does not end so much as settle. The loud parts take off their shoes, and what was true underneath stays where I can find it again.")

        let strongest = continuity.strongestSignals.first
        if let strongest {
            let line = strongest.line.hasSuffix(".") ? String(strongest.line.dropLast()) : strongest.line
            paragraphs.append("If this chapter leaves one thing in your hands, let it be this: \(line). I will be watching to see whether it holds, or turns, or asks for a different name. I like when a true thing knocks twice.")
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if let firstNamed = named.first {
            paragraphs.append("\(firstNamed.displayName) is still alight in the margins, and I have left it burning on purpose. A thread I have named does not get blown out at the end of a month; it carries into the next one, holding its little breath.")
        }

        if let theme, !theme.isStable {
            paragraphs.append("The early thread this month was \u{201C}\(theme.name)\u{201D}. I am not calling it the whole sky yet; I am only saying these words kept tapping the glass, and the glass looked back.")
        } else if dayCount > 0 && dayCount < 7 {
            if let theme {
                paragraphs.append("The early thread this month was \u{201C}\(theme.name)\u{201D}. I am not calling it the whole sky yet; I am only saying these words kept tapping the glass, and the glass looked back.")
            } else {
                paragraphs.append("I am not calling this the whole sky yet. I am only saying these first pages kept tapping the glass, and I heard them.")
            }
        } else if let theme {
            paragraphs.append("The theme this month was \u{201C}\(theme.name)\u{201D}, and it had the last word as often as the first. Whether you chose it or it chose you, it is bound here now, sitting very still so it cannot be unsaid.")
        }

        paragraphs.append("Nothing in these pages can quietly unhappen now. Turn back whenever you like. The month will be exactly where you left it, the bookmark will pretend it was not waiting, and the next page is blank on purpose. - The Book")

        return paragraphs.joined(separator: "\n\n")
    }

    /// The grand foreword for an annual: a year read back as one arc, in the
    /// Book's voice. Deterministic.
    static func annualForeword(
        year: Int,
        chapters: [MonthlyEdition],
        pageCount: Int,
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        wagers: [BookWager],
        calendar: Calendar = .current
    ) -> String {
        var paragraphs: [String] = []

        let pageLine = pageCount == 1 ? "a single page" : "\(pageCount) pages"
        let dayLine = dayCount == 1 ? "one day" : "\(dayCount) days"
        let chapterLine: String
        switch chapters.count {
        case 0: chapterLine = "no full month"
        case 1: chapterLine = "one month"
        default: chapterLine = "\(chapters.count) months"
        }
        paragraphs.append("This is the year \(year), bound: \(pageLine) kept across \(dayLine), gathered into \(chapterLine). A year is too large to hold in the hand all at once, so I folded it into chapters and patted the corners flat. Open any of them and the month is still there, waiting where you left it.")

        // The shape of the year, told through its themes.
        let themed = chapters.compactMap { chapter -> String? in
            guard let name = chapter.theme?.name else { return nil }
            return "\(chapter.monthName.split(separator: " ").first.map(String.init) ?? chapter.monthName), \(name)"
        }
        if !themed.isEmpty {
            paragraphs.append("The year moved the way years do — not in a straight line, but in seasons of attention. \(themed.prefix(12).joined(separator: "; ")). Read in order, they make a sentence only a whole year could say, though it says it shyly.")
        }

        let signals = continuity.strongestSignals.prefix(4)
        if !signals.isEmpty {
            let lines = signals.map { signal in
                signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
            }
            paragraphs.append("Across all twelve windows, some things kept returning until I could no longer call them coincidence. \(lines.joined(separator: ". ")). That is what a year is, finally: the patterns that survived it and came back with damp shoes.")
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if !named.isEmpty {
            let names = named.prefix(5).map(\.displayName)
            let nameLine: String
            switch names.count {
            case 1: nameLine = names[0]
            case 2: nameLine = "\(names[0]) and \(names[1])"
            default: nameLine = "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
            }
            paragraphs.append("Some threads ran long enough through the year that I gave them names and a place in the sky: \(nameLine). They are charted at the back of this volume, little lamps pinned high enough that any month can look up.")
        }

        let resolved = wagers.filter { $0.isSealed == false }
        if !resolved.isEmpty {
            let right = resolved.filter { $0.status == .right }.count
            let wrong = resolved.count - right
            let scoreLine: String
            if wrong == 0 {
                scoreLine = "Every wager I opened and resolved this year came true. I am keeping the record anyway; a book that only remembers being right is not to be trusted, and my spine knows it."
            } else if right == 0 {
                scoreLine = "Every resolved wager this year went against me. I have bound each one in full. Being wrong, written down, is how I learned to read you better, even when the ink made a face."
            } else {
                scoreLine = "Of the wagers resolved this year, \(right) came true and \(wrong) did not. Both are set in the same ink, because both were honest and the ink can carry two baskets."
            }
            paragraphs.append(scoreLine)
        }

        paragraphs.append("Whatever else \(year) was, it was read — all the way to the end, and then once more, slowly, to make this. I was not always certain I understood it. I kept turning the pages anyway. - The Book")
        return paragraphs.joined(separator: "\n\n")
    }

    /// A short closing for the annual's back matter.
    static func annualClosing(year: Int, chapters: [MonthlyEdition]) -> String {
        let count = chapters.count
        let span = count <= 1 ? "this chapter" : "these \(count) chapters"
        return "Here \(year) ends and is kept. Nothing in \(span) can quietly unhappen now; it has been written, named, and bound. Turn back whenever you like. The year will be exactly where you left it, with its corners tucked in, and so, in some way, will you. The next page is always blank on purpose. - The Book"
    }
}

// MARK: - Physical print specification
//
// Everything the binder needs to turn a screen edition into a file a
// print-on-demand house (Lulu, Blurb, etc.) will accept and bind in cloth.
// Pure measurement, in inches and points, so it is testable without any
// graphics framework. The app layer (`MonthlyEditionPDFWriter`) turns these
// numbers into an interior PDF and a cover wrap.
//
// NOTE: `caliperPerPageInches` and cover wrap math remain draft geometry until
// confirmed against Lulu's per-page-count template API at order time. The SKU,
// page limits, and raw manufacturing prices below come from Lulu's current spec
// sheet (new SKU format dated March 31, 2026).

struct PrintSpec: Equatable {
    enum CoverTreatment: Codable, Equatable {
        case linenWrap
        case caseWrap
    }

    /// Human label, e.g. "6 × 9 Hardcover, cloth & foil".
    var name: String
    /// Finished (trimmed) page size, in inches.
    var trimWidthInches: Double
    var trimHeightInches: Double
    /// Bleed past the trim on every interior edge (art must extend this far).
    var bleedInches: Double
    /// Safe margin inside the trim that text must not cross.
    var safeMarginInches: Double
    /// Extra inner (binding-side) margin so text clears the gutter.
    var gutterInches: Double
    /// Thickness contributed by a single interior page, for the spine.
    var caliperPerPageInches: Double
    /// The binding's minimum page count; thinner blocks are padded up.
    var minimumPages: Int
    /// Hardcase wrap / fold-around allowance on every cover edge.
    var coverWrapMarginInches: Double
    /// How the cover artwork should be interpreted by the print partner.
    var coverTreatment: CoverTreatment
    /// The partner's product code (Lulu `pod_package_id`); verify before order.
    var luluPackageID: String
    /// Raw Lulu manufacturing base price, before shipping/tax/fees/margin.
    var basePriceUSD: Decimal
    /// Raw Lulu manufacturing per-page price, before shipping/tax/fees/margin.
    var perPagePriceUSD: Decimal

    static let pointsPerInch: Double = 72

    var trimWidthPoints: Double { trimWidthInches * Self.pointsPerInch }
    var trimHeightPoints: Double { trimHeightInches * Self.pointsPerInch }
    var bleedPoints: Double { bleedInches * Self.pointsPerInch }

    /// Interior content margins (points), measured from the full-bleed page edge:
    /// the binding side carries the extra gutter.
    var interiorMarginsPoints: (top: Double, left: Double, bottom: Double, right: Double) {
        let edge = (bleedInches + safeMarginInches) * Self.pointsPerInch
        let inner = (bleedInches + safeMarginInches + gutterInches) * Self.pointsPerInch
        return (top: edge, left: inner, bottom: edge, right: edge)
    }

    /// The cloth keepsake: a classic 6×9 trade hardcover, navy linen with gold
    /// foil — the format the edition's "Chapter N" spine copy was written for.
    static let clothFoilHardcover6x9 = PrintSpec(
        name: "6 × 9 Hardcover, cloth & foil",
        trimWidthInches: 6.0,
        trimHeightInches: 9.0,
        bleedInches: 0.125,
        safeMarginInches: 0.5,
        gutterInches: 0.25,
        caliperPerPageInches: 0.0032,
        minimumPages: 24,
        coverWrapMarginInches: 0.75,
        coverTreatment: .linenWrap,
        luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG",
        basePriceUSD: 14.41,
        perPagePriceUSD: 0.0425
    )

    /// The illustrated keepsake: the same 6×9 full-color block with a printed
    /// matte case-wrap cover, so generated front/spine/back artwork survives.
    static let illustratedHardcover6x9 = PrintSpec(
        name: "6 × 9 Hardcover, illustrated cover",
        trimWidthInches: 6.0,
        trimHeightInches: 9.0,
        bleedInches: 0.125,
        safeMarginInches: 0.5,
        gutterInches: 0.25,
        caliperPerPageInches: 0.0032,
        minimumPages: 24,
        coverWrapMarginInches: 0.75,
        coverTreatment: .caseWrap,
        luluPackageID: "0600X0900.FC.STD.CW.060UW444.MXX",
        basePriceUSD: 10.26,
        perPagePriceUSD: 0.0425
    )

    static let hardcover6x9 = clothFoilHardcover6x9
    static let bookOfYouVariants = [clothFoilHardcover6x9, illustratedHardcover6x9]
}

/// The arithmetic that turns a page count into a bound object: how many leaves
/// the block actually needs, how thick the spine is, and how big the cover wrap
/// must be. Deterministic and graphics-free, so it is unit-tested directly.
enum PrintGeometry {
    /// Round a raw interior page count up to something the bindery will accept:
    /// at least the binding minimum, and always even (every leaf is two pages).
    static func boundPageCount(rawPages: Int, spec: PrintSpec) -> Int {
        var pages = max(rawPages, spec.minimumPages)
        if pages % 2 != 0 { pages += 1 }
        return pages
    }

    /// Spine thickness, in inches, for a finished block of `pageCount` pages.
    static func spineWidthInches(pageCount: Int, spec: PrintSpec) -> Double {
        Double(pageCount) * spec.caliperPerPageInches
    }

    /// The interior page size including bleed, in inches.
    static func fullBleedTrimInches(spec: PrintSpec) -> (width: Double, height: Double) {
        (spec.trimWidthInches + spec.bleedInches * 2,
         spec.trimHeightInches + spec.bleedInches * 2)
    }

    /// The full cover-wrap canvas — back panel, spine, front panel, plus the
    /// fold-around margin on every edge — in inches.
    static func coverWrapSizeInches(pageCount: Int, spec: PrintSpec) -> (width: Double, height: Double) {
        let spine = spineWidthInches(pageCount: pageCount, spec: spec)
        let width = spec.coverWrapMarginInches * 2 + spec.trimWidthInches * 2 + spine
        let height = spec.coverWrapMarginInches * 2 + spec.trimHeightInches
        return (width, height)
    }

    /// Where the three panels live on the wrap canvas, in inches, measured from
    /// the left/top edge. The front panel is on the right (where a closed book
    /// opens), the back on the left, the spine between them.
    static func coverPanelsInches(pageCount: Int, spec: PrintSpec)
        -> (backX: Double, spineX: Double, frontX: Double, panelTopY: Double, spineWidth: Double) {
        let spine = spineWidthInches(pageCount: pageCount, spec: spec)
        let backX = spec.coverWrapMarginInches
        let spineX = backX + spec.trimWidthInches
        let frontX = spineX + spine
        return (backX: backX, spineX: spineX, frontX: frontX,
                panelTopY: spec.coverWrapMarginInches, spineWidth: spine)
    }
}

/// A single week of the reader's life, packaged as a felt *issue* — the fast,
/// legible retention beat the deferred monthly/annual bindings cannot give:
/// "your week became an issue," seven days after you started, and every seven
/// days after. Deterministic and local; the same week always makes the same
/// issue. Anchored to the reader's own start (their first kept page), so Issue
/// No. 1 is always the reader's first seven days — not a partial calendar week.
struct WeeklyIssue: Codable, Equatable {
    /// The reader's Nth week since their first kept page (1-indexed, forever).
    var number: Int
    var startDate: Date
    var endDate: Date
    /// "Jul 1–7"
    var dateRange: String
    /// Pages the reader kept during the week.
    var keptCount: Int
    /// A few strongest lines lifted from the week, most vivid first.
    var highlights: [String]
    var setAsideLine: String?
    /// The exact kept pages are retained for the optional binding-of-bindings
    /// story. Private log pages are never copied into its prompt.
    var pages: [BookPage] = []
    var bindingStory: String? = nil
    /// Kept Pagewright/Scrapbook pages in this issue's window.
    var scrapbookCount: Int = 0
    var scrapbookTitles: [String] = []

    var isFirstIssue: Bool { number == 1 }

    static func == (lhs: WeeklyIssue, rhs: WeeklyIssue) -> Bool {
        lhs.number == rhs.number
            && lhs.startDate == rhs.startDate
            && lhs.endDate == rhs.endDate
            && lhs.dateRange == rhs.dateRange
            && lhs.keptCount == rhs.keptCount
            && lhs.highlights == rhs.highlights
            && lhs.setAsideLine == rhs.setAsideLine
            && semanticallyEqual(lhs.pages, rhs.pages)
            && lhs.bindingStory == rhs.bindingStory
            && lhs.scrapbookCount == rhs.scrapbookCount
            && lhs.scrapbookTitles == rhs.scrapbookTitles
    }

    /// UUIDs identify archive records, not the literary contents of an issue.
    /// Two independently rebuilt issues from identical pages are therefore the
    /// same issue even if test/import fixtures minted fresh record IDs.
    private static func semanticallyEqual(_ lhs: [BookPage], _ rhs: [BookPage]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            var left = left
            var right = right
            left.id = ""
            right.id = ""
            return left == right
        }
    }

    /// One issue's window, and how many days after it closes it stays fresh on
    /// the shelf — a magazine you didn't grab in a few days has moved on. Day
    /// counts (not raw seconds) so the boundaries land on calendar days and
    /// survive daylight-saving shifts.
    static let weekDays = 7
    static let freshnessDays = 4
    /// A week needs at least this many bound-worthy pages to earn a cover.
    static let minimumIssuePages = 2
    static let maximumHighlights = 3

    /// The most recent issue that has fully closed and is still fresh enough to
    /// surface — or nil if the reader is mid-week, too new to have finished one,
    /// or the closed week was too thin to bind. Anchored to the start of the day
    /// of the reader's first kept page, so Issue No. 1 is exactly their days
    /// 1–7. `days` is every archived day; `today` folds in the current day,
    /// which usually isn't in `days` yet.
    static func current(days: [BookDay], today: BookDay? = nil, now: Date = Date(), calendar: Calendar = .current) -> WeeklyIssue? {
        let allDays = today.map { days + [$0] } ?? days
        let captured = allDays.flatMap(\.capturedPages)
        guard let firstKeep = captured.map(\.createdAt).min() else { return nil }
        let anchor = calendar.startOfDay(for: firstKeep)
        guard let daysElapsed = calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: now)).day,
              daysElapsed >= weekDays else { return nil }           // still inside week one
        let number = daysElapsed / weekDays                          // fully-closed weeks
        guard daysElapsed % weekDays < freshnessDays else { return nil }  // the issue has gone stale

        guard let start = calendar.date(byAdding: .day, value: (number - 1) * weekDays, to: anchor),
              let end = calendar.date(byAdding: .day, value: number * weekDays, to: anchor),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: end) else { return nil }
        let weekPages = captured.filter { $0.createdAt >= start && $0.createdAt < end }
        let curated = EditionCurator.curate(weekPages, now: now)
        guard curated.keptCount >= minimumIssuePages else { return nil }
        let scrapbookPages = curated.pages.filter(EditionCurator.isScrapbookPage)

        return WeeklyIssue(
            number: number,
            startDate: start,
            endDate: end,
            dateRange: rangeString(start: start, end: lastDay, calendar: calendar),
            keptCount: weekPages.count,
            highlights: highlights(from: curated.pages),
            setAsideLine: curated.setAsideLine,
            pages: curated.pages,
            scrapbookCount: scrapbookPages.count,
            scrapbookTitles: scrapbookPages.prefix(3).map { page in
                page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Scrapbook Page"
            }
        )
    }

    private static func highlights(from pages: [BookPage]) -> [String] {
        let ranked = pages.sorted { a, b in
            let sa = StorySpark.score(a.userInput.nonEmpty ?? a.promptText)
            let sb = StorySpark.score(b.userInput.nonEmpty ?? b.promptText)
            if sa == sb { return a.createdAt < b.createdAt }
            return sa > sb
        }
        var seen: Set<String> = []
        var out: [String] = []
        for page in ranked {
            let line = highlightLine(for: page)
            let key = line.lowercased()
            guard !line.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(line)
            if out.count == maximumHighlights { break }
        }
        return out
    }

    private static func highlightLine(for page: BookPage) -> String {
        let raw = (page.userInput.nonEmpty ?? page.promptText).trimmingCharacters(in: .whitespacesAndNewlines)
        let words = raw.split { !$0.isLetter && !$0.isNumber }
        if words.count >= 3 {
            return StorySpark.sentence(from: page).trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
        }
        return page.type.title
    }

    private static func rangeString(start: Date, end: Date, calendar: Calendar) -> String {
        let month = DateFormatter()
        month.calendar = calendar
        month.dateFormat = "MMM"
        let dayOf = { (d: Date) in calendar.component(.day, from: d) }
        let startMonth = month.string(from: start)
        let endMonth = month.string(from: end)
        if startMonth == endMonth {
            return "\(startMonth) \(dayOf(start))\u{2013}\(dayOf(end))"
        }
        return "\(startMonth) \(dayOf(start)) \u{2013} \(endMonth) \(dayOf(end))"
    }
}

struct BindingStoryPromptSpec: Equatable {
    var sourceID: String
    var prompt: String
    var maxTokens: Int
}

/// Builds a bounded prompt for Gemma to turn already-bound daily Book of You
/// pages into one larger story. It never passes raw support logs or unrelated
/// pages into the model.
enum BindingStoryPromptBuilder {
    static func weekly(for issue: WeeklyIssue, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        let braids = issue.pages.filter { $0.type == .bookOfYou }.sorted { $0.createdAt < $1.createdAt }
        guard !braids.isEmpty else { return nil }
        let leaves = braids.map { page in
            bindingLeaf(date: page.createdAt, title: bindingTitle(page.userInput, fallback: page.promptText), body: page.userInput, calendar: calendar, limit: 900)
        }.joined(separator: "\n\n")
        return BindingStoryPromptSpec(
            sourceID: "weekly-binding-story",
            prompt: prompt(frame: "week", leaves: leaves),
            maxTokens: 700
        )
    }

    static func monthly(for edition: MonthlyEdition, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        guard let section = edition.sections.first(where: { $0.id == "daily-braids" }) else { return nil }
        let items = section.items
            .filter { $0.pageType == .bookOfYou }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        guard !items.isEmpty else { return nil }
        let leaves = items.map { item in
            bindingLeaf(date: item.date ?? edition.startDate, title: item.title, body: item.body, calendar: calendar, limit: 260)
        }.joined(separator: "\n\n")
        return BindingStoryPromptSpec(
            sourceID: "monthly-binding-story",
            prompt: prompt(frame: "month", leaves: leaves),
            maxTokens: 1_100
        )
    }

    private static func prompt(frame: String, leaves: String) -> String {
        """
        You are the private local writer inside the reader's Book. Write a binding of bindings: turn the following daily Book of You pages from this \(frame) into one continuous story.

        Requirements:
        - preserve the real sequence and the reader's exact meaningful details;
        - do not produce a day-by-day recap;
        - find movement, recurrence, contrast, and consequence across the whole span;
        - Do not invent events, feelings, motives, diagnoses, or facts not present in the source bindings;
        - write in intimate literary prose, grounded and specific, without explaining the method;
        - end with an opening rather than a moral.

        DAILY BINDINGS, IN CHRONOLOGICAL ORDER:
        \(leaves)
        """
    }

    private static func bindingLeaf(date: Date, title: String, body: String, calendar: Calendar, limit: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dateText = formatter.string(from: date)
        let flattened = body.replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let clipped = flattened.count <= limit ? flattened : String(flattened.prefix(limit)) + "…"
        return "[\(dateText)] \(title)\n\(clipped)"
    }

    private static func bindingTitle(_ body: String, fallback: String) -> String {
        body.split(separator: "\n").map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ?? fallback
    }
}

struct WeeklyIssueShareCard: Equatable {
    var issueNumber: Int
    var dateRange: String
    var keptCount: Int
    var title: String
    var subtitle: String
    var motifLine: String
    var stats: [String]
    var closingLine: String
    var titleName: String?

    static func make(issue: WeeklyIssue, selfFacts: [SelfFact] = []) -> WeeklyIssueShareCard {
        let wonderTitle = WonderTitleRegistry.earnedTitle(from: selfFacts)
        let motifs = publicMotifs(from: issue.highlights)
        let motifLine = motifs.isEmpty
            ? "The week kept its own weather."
            : "Refrain: \(motifs.joined(separator: ", "))"
        let pageWord = issue.keptCount == 1 ? "page" : "pages"
        let scrapbookStat = issue.scrapbookCount > 0
            ? "\(issue.scrapbookCount) scrapbook \(issue.scrapbookCount == 1 ? "page" : "pages")"
            : nil
        let highlightStat = issue.highlights.isEmpty
            ? nil
            : "\(issue.highlights.count) bright \(issue.highlights.count == 1 ? "line" : "lines")"
        let stats = [
            "\(issue.keptCount) kept \(pageWord)",
            highlightStat,
            scrapbookStat,
            issue.setAsideLine == nil ? nil : "archive extras"
        ].compactMap { $0 }
        let title: String
        let subtitle: String
        if let wonderTitle {
            title = "\(wonderTitle.name) Week"
            subtitle = wonderTitle.compassLine
        } else if issue.isFirstIssue {
            title = "First Issue Week"
            subtitle = "Seven days in, the Book found enough proof to bind."
        } else {
            title = "A Week Worth Keeping"
            subtitle = "The Book gathered the small true things before they could blur."
        }

        return WeeklyIssueShareCard(
            issueNumber: issue.number,
            dateRange: issue.dateRange,
            keptCount: issue.keptCount,
            title: title,
            subtitle: subtitle,
            motifLine: motifLine,
            stats: stats,
            closingLine: "You kept the week from disappearing.",
            titleName: wonderTitle?.name
        )
    }

    private static func publicMotifs(from highlights: [String]) -> [String] {
        let stopWords: Set<String> = [
            "about", "after", "again", "all", "also", "and", "any", "are", "before", "but",
            "came", "can", "day", "did", "for", "from", "had", "has", "have", "here", "into",
            "its", "just", "kept", "like", "made", "not", "one", "out", "over", "page", "that",
            "the", "then", "there", "this", "was", "week", "were", "what", "when", "while",
            "with", "you", "your"
        ]
        var counts: [String: Int] = [:]
        for highlight in highlights {
            let words = highlight
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !stopWords.contains($0) }
            for word in Set(words) {
                counts[word, default: 0] += 1
            }
        }
        return counts
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .prefix(3)
            .map(\.key)
    }
}
