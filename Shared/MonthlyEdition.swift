import Foundation

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
    /// Gemma's chronological re-reading of the nightly Book of You pages: the
    /// month's daily bindings sewn into a larger "binding of bindings" whose
    /// architecture may be continuous, mosaic, portrait, vigil, or return.
    /// Optional so deterministic/offline bindings and older archives still
    /// decode without it.
    var bindingStory: String? = nil
    /// The month's closing, in the Book's voice. The builder always fills this
    /// with the deterministic `BookForewordWriter.closing(...)`; the app may
    /// overwrite it with a Gemma-written conclusion before binding. Optional so
    /// older saved editions still decode.
    var closing: String?
    /// A small, diverse set of reader-authored passages selected from anywhere
    /// inside the month's eligible keeps. Optional for older saved editions.
    var passageCompass: [MeaningfulPassageSelector.Selection]? = nil

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
    /// Tales the reader finished this month, bound whole rather than
    /// summarised. This is the difference the whole Tale Grammar exists for:
    /// an edition that recognises "that happened to me" instead of reporting
    /// how many pages were kept.
    static func taleSection(from tales: [LivingTale]) -> MonthlyEditionSection {
        guard !tales.isEmpty else {
            return MonthlyEditionSection(id: "tales-finished", title: "Tales", note: "", items: [])
        }
        let items = tales.map { tale -> MonthlyEditionItem in
            MonthlyEditionItem(
                id: "tale-\(tale.id)",
                kind: .page,
                title: tale.title.isEmpty ? tale.shape.commonName : tale.title,
                body: TaleBinding.body(for: tale),
                date: tale.closedAt,
                pageType: .taleBound,
                sourceID: "tale-bound",
                mediaAssets: [],
                tags: ["tale-bound", "tale-shape:\(tale.shape.rawValue)"]
            )
        }
        return MonthlyEditionSection(
            id: "tales-finished",
            title: tales.count == 1 ? "The Tale You Were Inside" : "The Tales You Were Inside",
            note: tales.count == 1
                ? "One finished this month. I did not see the shape of it until it was over, which is usually how this goes."
                : "\(tales.count) finished this month. I only ever recognise them on the way out.",
            items: items
        )
    }

    static func previousMonth(
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        readerName: String = "friend",
        now: Date = Date(),
        calendar: Calendar = .current,
        includePrivateWeatherSummary: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = []
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
            storyConsequences: storyConsequences,
            readerName: readerName,
            startDate: start,
            endDate: end,
            generatedAt: now,
            calendar: calendar,
            includePrivateWeatherSummary: includePrivateWeatherSummary,
            academySeason: academySeason,
            boundTales: boundTales
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
        storyConsequences: [StoryConsequenceReceipt] = [],
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
                storyConsequences: storyConsequences,
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
        storyConsequences: [StoryConsequenceReceipt] = [],
        readerName: String = "friend",
        startDate: Date,
        endDate: Date,
        generatedAt: Date = Date(),
        calendar: Calendar = .current,
        includePrivateWeatherSummary: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = []
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
        // Read over every page the month kept, not just the bound ones: a
        // finding may well rest on the mundane logs the curator set aside, and
        // those are exactly the days the reader cannot recall unaided.
        let revelations = BindingRevelations.find(
            pages: pages,
            now: generatedAt,
            calendar: calendar,
            limit: 6
        )
        var passageInputs = BookSourceInputs.empty
        passageInputs.days = monthDays
        passageInputs.continuity = continuity
        passageInputs.themes = theme.map { [$0] } ?? []
        let passageCompass = MeaningfulPassageSelector.rankedSelections(
            pages: boundPages,
            query: MeaningfulPassageSelector.periodQuery(
                pages: boundPages,
                framing: [theme?.name ?? "", theme?.line ?? "", continuity.strongestSignals.prefix(5).map(\.line).joined(separator: " ")]
            ),
            inputs: passageInputs,
            scorer: nil,
            limit: 6,
            maximumAge: 45 * 86_400,
            minimumScore: 14,
            honorPriorUse: false,
            diversifyPageTypes: true,
            now: generatedAt
        )
        let privateWeatherSection = includePrivateWeatherSummary
            ? fuelAndInnerWeatherSection(from: pages, calendar: calendar)
            : MonthlyEditionSection(id: "fuel-and-inner-weather", title: "Fuel & Inner Weather", note: "", items: [])

        let title = "Book of You: \(monthTitle(for: startDate, calendar: calendar))"
        let subtitle = theme?.name ?? "\(dateLine(startDate, calendar: calendar)) - \(dateLine(endDate, calendar: calendar))"
        let tales = boundTales.filter { tale in
            guard let closedAt = tale.closedAt else { return false }
            return closedAt >= startDate && closedAt <= endDate
        }
        let sections = [
            taleSection(from: tales),
            themeSection(theme, pages: boundPages),
            worldEventSection(from: boundPages),
            memorySpineSection(from: monthDays, generatedAt: generatedAt),
            fictionalConsequenceSection(
                from: storyConsequences.filter {
                    $0.createdAt >= startDate && $0.createdAt <= endDate
                }
            ),
            openingSection(from: boundPages, continuity: continuity, setAsideLine: curated.setAsideLine),
            revelationsSection(from: revelations),
            pageSection(
                id: "daily-braids",
                title: "Daily Braids",
                note: "The Book of You pages that gathered the month into nightly thread.",
                pages: boundPages.filter { $0.type == .bookOfYou },
                // Every braid the month produced, whole. A reader who wrote
                // twice in one night should not lose one to an off-by-a-day cap.
                limit: 62
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
            // The Academy's own history, bound beside the reader's. Absent
            // entirely when the world had a quiet month.
            + [
                AcademySeasonEdition.section(
                    for: academySeason,
                    start: startDate,
                    end: endDate,
                    now: generatedAt
                )
            ].compactMap { $0 }

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
                revelations: revelations,
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
                revelations: revelations,
                calendar: calendar
            ),
            passageCompass: passageCompass
        )
    }

    private static func fictionalConsequenceSection(
        from receipts: [StoryConsequenceReceipt]
    ) -> MonthlyEditionSection {
        let meaningful = receipts
            .filter { !$0.editionLines.isEmpty }
            .sorted { left, right in
                if left.significance == right.significance {
                    return left.createdAt > right.createdAt
                }
                return left.significance > right.significance
            }
            .prefix(12)
            .sorted { $0.createdAt < $1.createdAt }
        guard !meaningful.isEmpty else {
            return MonthlyEditionSection(
                id: "fictional-consequences",
                title: "What The Story Changed",
                note: "",
                items: []
            )
        }
        let entityNames = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.entities.map { ($0.id, $0.name) })
        let items = meaningful.map { receipt in
            let names = receipt.characterIDs.prefix(3).map { entityNames[$0] ?? $0 }
            let title: String
            if receipt.significance == .rupture {
                title = names.isEmpty ? "A Road Closed" : "\(names.joined(separator: " & ")): A Road Closed"
            } else if receipt.isRepair {
                title = names.isEmpty ? "A Relationship Turned" : "\(names.joined(separator: " & ")): A Relationship Turned"
            } else {
                title = names.isEmpty ? "The Story Changed" : names.joined(separator: " & ")
            }
            return MonthlyEditionItem(
                id: "edition-\(receipt.id)",
                kind: .continuity,
                title: title,
                body: receipt.editionLines.joined(separator: "\n"),
                date: receipt.createdAt,
                pageType: receipt.sourcePageType,
                sourceID: "fictional-consequence-compiler",
                mediaAssets: [],
                tags: ["monthly-edition", "fictional-consequence"] + receipt.eventTags
            )
        }
        return MonthlyEditionSection(
            id: "fictional-consequences",
            title: "What The Story Changed",
            note: "Consequences that survived their original scene and became part of my history.",
            items: items
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
                ? "One current I found running under the month, named and held up to the light."
                : "One early current I found running under the month, still marked provisional.",
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
            title: "What I Noticed",
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
        return "Certain words kept finding their way back: \(motifLine). I treat them as motifs and atmosphere, not as a scorecard.\(recentLine)"
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
        case .sensory:
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
                body: "With permission, I looked at \(naturalList(counts)) across \(days). I keep this as pattern-weather, not diagnosis: clues about how the month moved through appetite, energy, body, and mood.",
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
                ? "On one day, fuel and inner weather were both kept. I treat that as a useful place to be gentle and curious, not as proof of cause."
                : "On \(pairedDays) days, fuel and inner weather were both kept. I treat those overlaps as useful places to be gentle and curious, not as proof of cause."
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
        return "These notes gathered most often around \(naturalList(Array(parts))). The timing may be ordinary logistics; I only mark where attention kept landing."
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
        return "A few words kept weight in the private weather: \(naturalList(Array(motifs))). I'd read them as invitations to notice conditions, not verdicts about you."
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
            note: "The weeks when my rules changed and the pages learned to behave differently.",
            items: [item] + eventPages.prefix(10).map(pageItem)
        )
    }

    /// What the Book noticed that the reader could not. Bound near the front,
    /// before the pages themselves — the findings are the argument, and the
    /// pages that follow are the evidence for it.
    private static func revelationsSection(
        from revelations: [BindingRevelations.Revelation]
    ) -> MonthlyEditionSection {
        guard !revelations.isEmpty else {
            return MonthlyEditionSection(id: "what-i-noticed", title: "What I Noticed", note: "", items: [])
        }
        return MonthlyEditionSection(
            id: "what-i-noticed",
            title: "What I Noticed",
            note: "Connections that only show up when a whole month is held still at once.",
            items: revelations.map { revelation in
                var body = revelation.body
                if !revelation.evidence.isEmpty {
                    let quoted = revelation.evidence
                        .map { item in
                            let day = item.date.formatted(.dateTime.month(.abbreviated).day())
                            return "\(day) \u{2014} \u{201C}\(item.excerpt)\u{201D}"
                        }
                        .joined(separator: "\n")
                    body += "\n\n\(quoted)"
                }
                return MonthlyEditionItem(
                    id: "revelation-\(revelation.id)",
                    kind: .continuity,
                    title: revelation.title,
                    body: body,
                    date: revelation.evidence.first?.date,
                    pageType: nil,
                    sourceID: "binding-revelations",
                    mediaAssets: [],
                    tags: ["revelation", revelation.kind.rawValue]
                )
            }
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
        // The nightly braid is the spine of the whole book — the reader's own
        // month, in their own words. An edition that excerpts it is showing them
        // a summary of a summary. Every braid binds whole, however long it ran.
        guard !bindsUnabridged(pageType) else { return text }
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

    /// Page kinds bound in full, never excerpted.
    private static func bindsUnabridged(_ pageType: BookPageType) -> Bool {
        pageType == .bookOfYou
    }

    private static func monthlyExcerptLimit(for pageType: BookPageType) -> Int {
        switch pageType {
        case .bookOfYou, .letter, .narrativeOS, .bookConnections, .gossip, .bookAside:
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
/// Sentence-cases a phrase assembled lowercase ("all 47 pages" → "All 47
/// pages") without disturbing the rest of it.
private extension String {
    var sentenceCased: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

enum BookForewordWriter {

    /// One month's stable voice-seed. The same month always reads the same way;
    /// two different months never open with the same sentence. Derived from the
    /// month's own shape rather than a counter, so re-binding is idempotent but
    /// January and February cannot collide.
    static func voiceSeed(monthTitle: String, pages: Int, dayCount: Int) -> UInt64 {
        UInt64(bitPattern: Int64("\(monthTitle)|\(pages)|\(dayCount)".stableHash))
    }

    /// A separately-mixed seed for one beat of the piece.
    ///
    /// `ReflectiveProse.pick` reduces `seed &+ salt &* 7_919` modulo the pool
    /// size, so two pools of equal length pick the *same* index for a given
    /// seed — a month that opened on variant 2 would then take variant 2 of its
    /// reason and variant 2 of its sign-off, and three months in six read
    /// identically end to end. Scrambling per beat decorrelates the pools.
    static func beatSeed(_ seed: UInt64, _ beat: Int) -> UInt64 {
        UInt64(bitPattern: Int64((Int(bitPattern: UInt(truncatingIfNeeded: seed)) ^ (beat &* 0x27d4eb2f)).stableScramble))
    }

    static func foreword(
        monthTitle: String,
        pages: [BookPage],
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        wagers: [BookWager],
        revelations: [BindingRevelations.Revelation] = [],
        calendar: Calendar = .current
    ) -> String {
        let seed = voiceSeed(monthTitle: monthTitle, pages: pages.count, dayCount: dayCount)
        let pageLine = pages.count == 1 ? "one page" : "\(pages.count) pages"
        let dayLine = dayCount == 1 ? "a single day" : "\(dayCount) days"

        var paragraphs: [String] = []

        // 1. The arrival. A thin month is a different book from a full one, and
        //    should not be greeted with the same sentence.
        if dayCount > 0 && dayCount < 7 {
            paragraphs.append(ReflectiveProse.pick([
                "This is a first binding from \(monthTitle): \(pageLine) across \(dayLine). Not enough month to name the whole weather, but enough to keep what already refused to disappear.",
                "\(monthTitle) is barely a month yet \u{2014} \(pageLine) across \(dayLine). I'm binding it early because small things go missing fastest, and these have already proved they'd rather not.",
                "A short chapter: \(pageLine), \(dayLine). I'd rather bind a thin month than let it round down to nothing."
            ], seed: beatSeed(seed, 11), salt: 0))
        } else {
            paragraphs.append(ReflectiveProse.pick([
                "This is what \(monthTitle) left in my keeping: \(pageLine) across \(dayLine), each one kept on purpose.",
                "\(monthTitle), bound: \(pageLine) across \(dayLine). None of it arrived here by accident \u{2014} you chose every one.",
                "Here is \(monthTitle) with its shoes off. \(pageLine.sentenceCased) across \(dayLine), and not one of them kept itself.",
                "\(pageLine.sentenceCased). \(dayLine.sentenceCased). That's what \(monthTitle) handed me, and I haven't thrown any of it away."
            ], seed: beatSeed(seed, 11), salt: 0))
        }

        // 2. Why the Book binds at all. Said differently every month, because a
        //    reason repeated verbatim stops being a reason.
        paragraphs.append(ReflectiveProse.pick([
            "I don't bind months to flatter them. I bind them because loose pages get lonely, and I don't want any of this to quietly unhappen.",
            "A month that isn't written down doesn't politely wait to be remembered. It goes. That's the entire reason for the thread and the glue.",
            "This isn't a trophy. It's a container. Unbound days leak, and I've watched too many of them do it.",
            "Binding is the least mystical thing I do. It's just refusing to let a month become a rumour."
        ], seed: beatSeed(seed, 17), salt: 0))

        // 3. The strongest thing the Book actually found. A revelation outranks
        //    a continuity signal here: it is the reading the reader could not
        //    have performed on themselves.
        if let sharpest = revelations.first {
            paragraphs.append(ReflectiveProse.pick([
                "Reading it back, I found something you were not in a position to see. \(sharpest.title). \(sharpest.body)",
                "One thing surfaced that I don't think you noticed while you were living it. \(sharpest.title). \(sharpest.body)",
                "Here is what thirty days held still long enough to show me. \(sharpest.title). \(sharpest.body)"
            ], seed: beatSeed(seed, 23), salt: 0))
        } else {
            let signals = continuity.strongestSignals.prefix(3)
            if !signals.isEmpty {
                let lines = signals.map { signal in
                    signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
                }
                let opener = ReflectiveProse.pick([
                    "Reading it back, I noticed things I didn't notice at the time.",
                    "Some of this only became visible once it stopped moving.",
                    "A few shapes showed up in the re-reading that were invisible in the living."
                ], seed: beatSeed(seed, 23), salt: 0)
                let caveat = ReflectiveProse.pick([
                    "None of this is a verdict. It's the shape attention left behind, with its elbows on the table.",
                    "I'm not ruling on any of it. I'm only reporting where the ink pooled.",
                    "It's weather, not a verdict. Argue with it if you like."
                ], seed: beatSeed(seed, 29), salt: 0)
                paragraphs.append("\(opener) \(lines.joined(separator: ". ")). \(caveat)")
            }
        }

        // 4. Named threads.
        let named = ConstellationKeeper.namedConstellations(constellations)
        if !named.isEmpty {
            let nameLine = list(named.prefix(3).map(\.displayName))
            paragraphs.append(ReflectiveProse.pick([
                "Some threads have been with us long enough that I've given them names: \(nameLine). A named constellation is a promise with a little lamp inside it.",
                "\(nameLine) have earned names now. I don't hand those out early \u{2014} a thread has to keep showing up when nobody is asking it to.",
                "The margins are keeping \(nameLine) lit. Naming a thing is how I admit I expect it back."
            ], seed: beatSeed(seed, 31), salt: 0))
        }

        // 5. The wager ledger — the Book's own accuracy, reported against itself.
        let opened = wagers.filter { !$0.isSealed }
        let sealed = wagers.filter(\.isSealed)
        if !opened.isEmpty {
            let right = opened.filter { $0.status == .right }.count
            let wrong = opened.count - right
            if wrong == 0 {
                paragraphs.append(ReflectiveProse.pick([
                    "Every wager I opened this month came true, which made my spine sit up straighter than was dignified.",
                    "I guessed \(right == 1 ? "once" : "\(right) times") this month and was right every time. I'm trying not to make it my whole personality."
                ], seed: beatSeed(seed, 37), salt: 0))
            } else if right == 0 {
                paragraphs.append(ReflectiveProse.pick([
                    "Every wager I opened this month was wrong. I've written each one down anyway. Being wrong in writing is how a book learns without pretending its ink is royal.",
                    "I got all of them wrong. They stay in the ledger. A book that only records its hits is a book you can't trust about anything."
                ], seed: beatSeed(seed, 37), salt: 0))
            } else {
                paragraphs.append(ReflectiveProse.pick([
                    "Of the wagers I opened this month, \(right) came true and \(wrong) did not. I record both with the same ink, because the ink doesn't like favorites.",
                    "\(right) right, \(wrong) wrong. Both halves stay. You should know how often I miss."
                ], seed: beatSeed(seed, 37), salt: 0))
            }
        }
        if !sealed.isEmpty {
            paragraphs.append(sealed.count == 1
                ? "One wager is still sealed in the margins. It's trying very hard not to peek. We will both find out."
                : "\(sealed.count) wagers are still sealed in the margins. They are trying very hard not to peek. We will both find out.")
        }

        // 6. The sign-off.
        paragraphs.append(ReflectiveProse.pick([
            "Whatever else this month was, it got read. I put a hand flat on it and told it to stay. It stayed. - The Book",
            "It was a month and I caught it. That's the whole of my claim, and I'm pleased with it. - The Book",
            "I've read every page of this twice. Once as it arrived, once just now. - The Book",
            "None of it is going anywhere. I've checked the thread myself. - The Book"
        ], seed: beatSeed(seed, 41), salt: 0))

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
        revelations: [BindingRevelations.Revelation] = [],
        calendar: Calendar = .current
    ) -> String {
        // Deliberately offset from the foreword's seed: the same month should
        // not open and close on the same rhetorical move.
        let seed = voiceSeed(monthTitle: monthTitle, pages: pages.count, dayCount: dayCount) &+ 7
        var paragraphs: [String] = []

        let pageLine = pages.count == 1 ? "the single page" : "all \(pages.count) pages"
        paragraphs.append(ReflectiveProse.pick([
            "So \(monthTitle) closes. I've read \(pageLine) back to you and to myself, and what could be kept has been kept. A month doesn't end so much as settle.",
            "That's \(monthTitle). \(pageLine.sentenceCased) read back, nothing left loose. The loud parts take off their shoes and what was true underneath stays where I can find it.",
            "\(monthTitle) is finished, which isn't the same as over. I've read \(pageLine) and put them somewhere they can't be argued out of."
        ], seed: beatSeed(seed, 13), salt: 0))

        // The closing takes the *second* revelation where it can, so the book
        // does not end on the note it opened with.
        let closingFinding = revelations.dropFirst().first ?? revelations.first
        if let closingFinding, revelations.count > 1 {
            paragraphs.append(ReflectiveProse.pick([
                "One more thing before I shut the cover. \(closingFinding.title). \(closingFinding.body)",
                "I held this one back for the end. \(closingFinding.title). \(closingFinding.body)",
                "And this, which I only saw once every page was lying flat. \(closingFinding.title). \(closingFinding.body)"
            ], seed: beatSeed(seed, 19), salt: 0))
        } else if let strongest = continuity.strongestSignals.first {
            let line = strongest.line.hasSuffix(".") ? String(strongest.line.dropLast()) : strongest.line
            paragraphs.append(ReflectiveProse.pick([
                "If this chapter leaves one thing in your hands, let it be this: \(line). I will be watching to see whether it holds, or turns, or asks for a different name.",
                "Carry this one out with you: \(line). I like when a true thing knocks twice.",
                "The line I'd keep, if I could only keep one: \(line). We will see whether it survives next month."
            ], seed: beatSeed(seed, 19), salt: 0))
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if let firstNamed = named.first {
            paragraphs.append(ReflectiveProse.pick([
                "\(firstNamed.displayName) is still alight in the margins, and I've left it burning on purpose. A thread I've named doesn't get blown out at the end of a month.",
                "I'm leaving \(firstNamed.displayName) lit. It carries into next month, holding its little breath.",
                "\(firstNamed.displayName) doesn't close with the chapter. Named threads keep their own hours."
            ], seed: beatSeed(seed, 23), salt: 0))
        }

        if let theme, !theme.isStable || (dayCount > 0 && dayCount < 7) {
            paragraphs.append(ReflectiveProse.pick([
                "The early thread this month was \u{201C}\(theme.name)\u{201D}. I'm not calling it the whole sky yet; I'm only saying these words kept tapping the glass, and the glass looked back.",
                "\u{201C}\(theme.name)\u{201D} kept surfacing. Too early to call it the weather. Early enough to write it down."
            ], seed: beatSeed(seed, 29), salt: 0))
        } else if let theme {
            paragraphs.append(ReflectiveProse.pick([
                "The theme this month was \u{201C}\(theme.name)\u{201D}, and it had the last word as often as the first. Whether you chose it or it chose you, it is bound here now, sitting very still so it can't be unsaid.",
                "\u{201C}\(theme.name)\u{201D} ran through the whole month. I've stopped asking whether you picked it."
            ], seed: beatSeed(seed, 29), salt: 0))
        } else if dayCount > 0 && dayCount < 7 {
            paragraphs.append("I'm not calling this the whole sky yet. I'm only saying these first pages kept tapping the glass, and I heard them.")
        }

        paragraphs.append(ReflectiveProse.pick([
            "Nothing in these pages can quietly unhappen now. Turn back whenever you like. The month will be exactly where you left it, the bookmark will pretend it wasn't waiting, and the next page is blank on purpose. - The Book",
            "It's all fixed here now, which is the only permanence I can offer. Come back to it. I don't move things while you're gone. - The Book",
            "Shut it, or don't. The month keeps either way now \u{2014} that was the entire point of the thread. - The Book"
        ], seed: beatSeed(seed, 31), salt: 0))

        return paragraphs.joined(separator: "\n\n")
    }

    /// "a, b, and c" — used wherever the Book reads a short list aloud.
    private static func list(_ items: some Collection<String>) -> String {
        let items = Array(items)
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }

    /// The grand foreword for an annual: a year read back from its month-scale
    /// bindings without forcing twelve different lives into one arc. This is
    /// the deterministic fallback when the local writer cannot bind the year.
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

        let monthlyBindings = chapters.compactMap { chapter -> String? in
            guard let binding = chapter.bindingStory?.nonEmpty else { return nil }
            let flattened = binding.replacingOccurrences(of: "\n", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            let excerpt = flattened.count <= 180
                ? flattened
                : String(flattened.prefix(180)) + "…"
            return "\(chapter.monthName): \(excerpt)"
        }
        if !monthlyBindings.isEmpty {
            paragraphs.append("The months refused to become one obedient plot. I kept their larger bindings where they disagreed as well as where they answered one another. \(monthlyBindings.prefix(4).joined(separator: " "))")
        }

        let signals = continuity.strongestSignals.prefix(4)
        if !signals.isEmpty {
            let lines = signals.map { signal in
                signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
            }
            paragraphs.append("Across all twelve windows, some things kept returning until I could no longer call them coincidence. \(lines.joined(separator: ". ")). That's what a year is, finally: the patterns that survived it and came back with damp shoes.")
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
                scoreLine = "Every wager I opened and resolved this year came true. I'm keeping the record anyway; a book that only remembers being right isn't to be trusted, and my spine knows it."
            } else if right == 0 {
                scoreLine = "Every resolved wager this year went against me. I've bound each one in full. Being wrong, written down, is how I learned to read you better, even when the ink made a face."
            } else {
                scoreLine = "Of the wagers resolved this year, \(right) came true and \(wrong) did not. Both are set in the same ink, because both were honest and the ink can carry two baskets."
            }
            paragraphs.append(scoreLine)
        }

        paragraphs.append("Whatever else \(year) was, it was read — all the way to the end, and then once more, slowly, to make this. I wasn't always certain I understood it. I kept turning the pages anyway. - The Book")
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
    /// Reader-authored passages selected from anywhere inside the week's
    /// eligible keeps, used to focus highlights and the binding story.
    var passageCompass: [MeaningfulPassageSelector.Selection]? = nil
    /// What the Book noticed across the week that the reader could not see
    /// from inside it. Empty on thin weeks — a finding needs archive behind it.
    var revelations: [BindingRevelations.Revelation] = []
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
            && semanticallyEqual(lhs.passageCompass, rhs.passageCompass)
            && lhs.revelations == rhs.revelations
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

    private static func semanticallyEqual(
        _ lhs: [MeaningfulPassageSelector.Selection]?,
        _ rhs: [MeaningfulPassageSelector.Selection]?
    ) -> Bool {
        let lhs = lhs ?? []
        let rhs = rhs ?? []
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.pageType == right.pageType
                && left.excerpt == right.excerpt
                && left.score == right.score
                && left.semanticSimilarity == right.semanticSimilarity
                && left.reason == right.reason
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
        let dailyBraids = allDays
            .flatMap(\.pages)
            .filter { $0.type == .bookOfYou && $0.createdAt >= start && $0.createdAt < end }
        let issuePages = Dictionary(
            (curated.pages + dailyBraids).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted { left, right in
            if left.createdAt == right.createdAt { return left.id < right.id }
            return left.createdAt < right.createdAt
        }
        let passageCompass = MeaningfulPassageSelector.rankedSelections(
            pages: issuePages,
            query: MeaningfulPassageSelector.periodQuery(
                pages: curated.pages,
                framing: ["week \(number)", rangeString(start: start, end: lastDay, calendar: calendar)]
            ),
            inputs: .empty,
            scorer: nil,
            limit: 4,
            maximumAge: 14 * 86_400,
            minimumScore: 14,
            honorPriorUse: false,
            diversifyPageTypes: true,
            now: now
        )

        return WeeklyIssue(
            number: number,
            startDate: start,
            endDate: end,
            dateRange: rangeString(start: start, end: lastDay, calendar: calendar),
            keptCount: weekPages.count,
            highlights: passageCompass.isEmpty ? highlights(from: curated.pages) : passageCompass.prefix(maximumHighlights).map(\.excerpt),
            setAsideLine: curated.setAsideLine,
            pages: issuePages,
            passageCompass: passageCompass,
            // A week is a small sample; ask for fewer findings so the issue
            // never pads itself with the weakest one it could scrape together.
            revelations: BindingRevelations.find(
                pages: weekPages,
                now: now,
                calendar: calendar,
                limit: 2
            ),
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
/// pages into one larger literary architecture. It never passes raw support
/// logs or unrelated pages into the model.
enum BindingStoryPromptBuilder {
    static func weekly(for issue: WeeklyIssue, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        let braids = issue.pages.filter { $0.type == .bookOfYou }.sorted { $0.createdAt < $1.createdAt }
        guard !braids.isEmpty else { return nil }
        let leaves = braids.map { page in
            bindingLeaf(
                date: page.createdAt,
                title: bindingTitle(page.userInput, fallback: page.promptText),
                body: page.userInput,
                tags: page.tags,
                calendar: calendar,
                limit: 900
            )
        }.joined(separator: "\n\n")
        return BindingStoryPromptSpec(
            sourceID: "weekly-binding-story",
            prompt: prompt(frame: "week", leaves: leaves, passageCompass: issue.passageCompass ?? []),
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
            bindingLeaf(
                date: item.date ?? edition.startDate,
                title: item.title,
                body: item.body,
                tags: item.tags,
                calendar: calendar,
                limit: 230
            )
        }.joined(separator: "\n\n")
        return BindingStoryPromptSpec(
            sourceID: "monthly-binding-story",
            prompt: prompt(frame: "month", leaves: leaves, passageCompass: edition.passageCompass ?? []),
            maxTokens: 1_100
        )
    }

    /// The annual is a binding of the month-scale bindings, not a fresh skim of
    /// twelve metadata cards. Each month contributes its actual synthesized
    /// prose plus the form/Rut/register mixture carried by its daily Braids.
    static func annual(for annual: AnnualEdition, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        let leaves = annual.chapters
            .sorted { ($0.startDate, $0.monthName) < ($1.startDate, $1.monthName) }
            .compactMap { chapter -> String? in
                let dailyItems = chapter.sections
                    .first(where: { $0.id == "daily-braids" })?
                    .items
                    .filter { $0.pageType == .bookOfYou } ?? []
                let prose = chapter.bindingStory?.nonEmpty
                    ?? ([chapter.foreword] + chapter.memorySpinePromptLines)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: " ")
                        .nonEmpty
                guard let prose else { return nil }
                let flattened = prose.replacingOccurrences(of: "\n", with: " ")
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
                let clipped = flattened.count <= 850
                    ? flattened
                    : String(flattened.prefix(850)) + "…"
                let sourceLabel = chapter.bindingStory?.nonEmpty == nil
                    ? "deterministic month fallback"
                    : "monthly binding"
                return """
                [\(chapter.monthName)] \(sourceLabel)
                \(axisSummary(for: dailyItems.flatMap(\.tags)))
                \(clipped)
                """
            }
            .joined(separator: "\n\n")
        guard !leaves.isEmpty else { return nil }

        let prompt = """
        You are the private local writer inside the reader's Book. Read the following monthly bindings as the leaves of one annual binding.

        Requirements:
        - preserve the months' real sequence, contradictions, unresolved threads, and exact particulars;
        - choose the truest architecture the year earned: chronicle, mosaic, portrait, narrative drama, vigil, comedy, or return;
        - do not force the year into one continuous plot or a single redemptive arc;
        - synthesize the monthly bindings themselves. Do not replace them with a month-by-month recap;
        - treat each month's Story-form mix, Rut-influence mix, and Register mix as separate evidence;
        - hardship without explicit Rut influence is not a Rut battle;
        - never claim that the Rut was permanently cured, and never turn unanswered or missing evidence into a verdict;
        - do not invent events, feelings, motives, diagnoses, or facts;
        - write in the Book's intimate first-person voice to the reader, using contractions;
        - end with an opening rather than a moral.

        MONTHLY BINDINGS, IN CHRONOLOGICAL ORDER:
        \(leaves)
        """
        return BindingStoryPromptSpec(
            sourceID: "annual-binding-story",
            prompt: prompt,
            maxTokens: 760
        )
    }

    private static func prompt(
        frame: String,
        leaves: String,
        passageCompass: [MeaningfulPassageSelector.Selection]
    ) -> String {
        let compassSection: String
        if passageCompass.isEmpty {
            compassSection = ""
        } else {
            let lines = passageCompass.prefix(frame == "week" ? 4 : 6).enumerated().map { index, passage in
                let excerpt = passage.excerpt.count <= 190 ? passage.excerpt : String(passage.excerpt.prefix(190)) + "…"
                return "\(index + 1). \(passage.pageType.shortTitle): “\(excerpt)”"
            }.joined(separator: "\n")
            compassSection = """


            READER-AUTHORED PASSAGE COMPASS:
            \(lines)

            COMPASS RULE:
            - These passages were selected from meaningful parts of eligible keeps across the whole \(frame), not merely from page openings.
            - Let at least one passage become a hinge, image, or consequence in the chosen architecture. Use the others only when they genuinely connect.
            - The chronological daily bindings still govern sequence and fact. The compass chooses emphasis; it does not authorize invention or require every passage.
            - Quote at most one short phrase. Never mention selection, scoring, embeddings, or an archive.
            """
        }
        return """
        You are the private local writer inside the reader's Book. Write a binding of bindings from the following daily Book of You pages.

        Requirements:
        - preserve the real sequence and the reader's exact meaningful details;
        - do not produce a day-by-day recap;
        - choose the truest architecture for this span: chronicle, mosaic, portrait, narrative drama, vigil, comedy, or return;
        - do not force the \(frame) into one continuous plot when juxtaposition, recurrence, or an unresolved vigil is truer;
        - find movement, recurrence, contrast, and consequence across the whole span;
        - Do not invent events, feelings, motives, diagnoses, or facts not present in the source bindings;
        - treat each leaf's Story form, Rut influence, and Register as separate evidence. Hardship without explicit Rut influence is not a Rut battle;
        - the Rut may shape the larger binding only where leaves explicitly name it. Keep mixed outcomes mixed and never claim a permanent cure;
        - write in intimate literary prose, grounded and specific, without explaining the method;
        - end with an opening rather than a moral.\(compassSection)

        DAILY BINDINGS, IN CHRONOLOGICAL ORDER:
        \(leaves)
        """
    }

    private static func bindingLeaf(
        date: Date,
        title: String,
        body: String,
        tags: [String],
        calendar: Calendar,
        limit: Int
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dateText = formatter.string(from: date)
        let flattened = body.replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let clipped = flattened.count <= limit ? flattened : String(flattened.prefix(limit)) + "…"
        return "[\(dateText)] \(title)\n\(bindingAxes(in: tags))\n\(clipped)"
    }

    private static func bindingAxes(in tags: [String]) -> String {
        func value(_ prefix: String) -> String {
            tags.first(where: { $0.hasPrefix(prefix) })
                .map { String($0.dropFirst(prefix.count)) }
                ?? "unspecified"
        }
        return "Story form: \(value(BookOfYouResidue.storyFormPrefix)); Rut influence: \(value(BookOfYouResidue.rutInfluencePrefix)); Register: \(value(BookOfYouResidue.narrativeRegisterPrefix))"
    }

    private static func axisSummary(for tags: [String]) -> String {
        func counts(_ prefix: String) -> String {
            let values = tags.compactMap { tag -> String? in
                guard tag.hasPrefix(prefix) else { return nil }
                return String(tag.dropFirst(prefix.count))
            }
            let grouped = Dictionary(grouping: values, by: { $0 })
            guard !grouped.isEmpty else { return "unspecified" }
            let tallies: [(value: String, total: Int)] = grouped.map { entry in
                (value: entry.key, total: entry.value.count)
            }
            let ordered = tallies.sorted { left, right in
                left.total == right.total
                    ? left.value < right.value
                    : left.total > right.total
            }
            return ordered.map { entry in
                entry.value + " " + String(entry.total)
            }.joined(separator: ", ")
        }
        return "Story-form mix: \(counts(BookOfYouResidue.storyFormPrefix)); Rut-influence mix: \(counts(BookOfYouResidue.rutInfluencePrefix)); Register mix: \(counts(BookOfYouResidue.narrativeRegisterPrefix))"
    }

    private static func bindingTitle(_ body: String, fallback: String) -> String {
        body.split(separator: "\n").map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ?? fallback
    }
}

/// The reader's name, made into something they can show somebody.
///
/// Deliberately carries only the Book's own language — the role, its gloss, the
/// patron. None of the reader's kept words or the receipts the Book read them
/// from appear here. The card leaves the phone; their material should not.
struct ReaderRoleShareCard: Codable, Equatable {
    var fullName: String
    var handsName: String?
    var gloss: String
    var patronLine: String
    var epithetCost: String?
    var closingLine: String

    static func make(_ role: ComposedRole) -> ReaderRoleShareCard {
        ReaderRoleShareCard(
            fullName: role.fullName,
            handsName: role.hands?.name,
            gloss: role.role.gloss,
            patronLine: "\(role.role.patronName) keeps an eye on this one",
            epithetCost: role.epithet?.cost,
            closingLine: "The Book named me on the first night."
        )
    }
}

struct WeeklyIssueShareCard: Codable, Equatable {
    var issueNumber: Int
    var dateRange: String
    var keptCount: Int
    var title: String
    var subtitle: String
    var motifLine: String
    var stats: [String]
    var closingLine: String
    var titleName: String?
    /// The richer cut, unlocked by passing the Book on to one person. Honour
    /// system by design: there is no server to verify an invite against, and
    /// the reward is a nicer picture of the reader's own week — a thing that
    /// costs nothing if somebody claims it without sending anything.
    var isDeluxe: Bool = false
    /// Deluxe only: every stat rather than the three that fit the plain plate.
    var fullStats: [String] = []
    /// Deluxe only: what the Book called this reader, as a banner.
    var roleBanner: String?
    /// One line for the issue's back page: what the Book is watching for next
    /// week. Deterministic per issue, so a rebind teases the same thing.
    var nextIssueTease: String = ""

    static func make(issue: WeeklyIssue, selfFacts: [SelfFact] = [], isDeluxe: Bool = false) -> WeeklyIssueShareCard {
        let readerRole = ReaderRoleRegistry.currentRole(from: selfFacts)
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
        if let readerRole {
            // Bare name here: "The Lookout Week" reads as a typo.
            title = "\(readerRole.role.bareName) Week"
            subtitle = readerRole.role.compassLine
        } else if issue.isFirstIssue {
            title = "First Issue Week"
            subtitle = "Seven days in, I found enough proof to bind."
        } else {
            title = "A Week Worth Keeping"
            subtitle = "I gathered the small true things before they could blur."
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
            titleName: readerRole?.role.bareName,
            isDeluxe: isDeluxe,
            fullStats: isDeluxe ? stats : [],
            roleBanner: isDeluxe ? readerRole?.fullName : nil,
            nextIssueTease: nextIssueTease(issueNumber: issue.number, motifs: motifs)
        )
    }

    /// The back-page tease: turns the issue's ending into anticipation for the
    /// next one. Leans on the week's refrain when there is one, so the tease
    /// feels watched rather than generic.
    private static func nextIssueTease(issueNumber: Int, motifs: [String]) -> String {
        if let motif = motifs.first {
            let watched = [
                "Next week: whether \(motif) returns.",
                "Issue No. \(issueNumber + 1) is already listening for \(motif).",
                "A ribbon was left at \(motif), in case next week picks it back up."
            ]
            return watched[ConstellationKeeper.stableIndex(for: "weekly-tease-\(issueNumber)", count: watched.count)]
        }
        let open = [
            "Issue No. \(issueNumber + 1) is already gathering.",
            "Next week has not been written on yet.",
            "The next seven pages are still uncut."
        ]
        return open[ConstellationKeeper.stableIndex(for: "weekly-tease-\(issueNumber)", count: open.count)]
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

/// The durable form of a weekly binding. The issue's prose and layout inputs
/// stay with its archive page while the rendered files live in Application
/// Support, so a kept issue can be reopened after launch or after its brief
/// home-screen freshness window has passed.
struct KeptWeeklyIssueArtifact: Codable, Equatable {
    var issue: WeeklyIssue
    var card: WeeklyIssueShareCard
    var readerName: String
    var editorialNote: String?
    var closingNote: String?
    var cardPath: String
    var pdfPath: String
    var keptAt: Date
}

/// The durable form of a monthly binding. The whole edition stays with its
/// archive page so the reader can reopen it after launch, and the rendered PDF
/// lives in Application Support; if iOS clears that file the stored edition is
/// enough to press it again without rebuilding the month. `monthKey` ("yyyy-MM")
/// gives each bound month a stable identity so re-binding replaces its card
/// rather than stacking duplicates on the Book of You shelf.
struct KeptMonthlyEditionArtifact: Codable, Equatable {
    var edition: MonthlyEdition
    var monthKey: String
    var pdfPath: String
    var keptAt: Date

    /// "June 2026" — the month name the edition carries, stamped with the year
    /// its start date falls in so cards and readers can tell chapters apart.
    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return "\(edition.monthName) \(formatter.string(from: edition.startDate))"
    }
}
