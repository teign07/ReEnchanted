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
    /// The month's closing, in the Book's voice. The builder always fills this
    /// with the deterministic `BookForewordWriter.closing(...)`; the app may
    /// overwrite it with a Gemma-written conclusion before binding. Optional so
    /// older saved editions still decode.
    var closing: String?

    /// "The Book of You - bj - Chapter 3 - June"
    var chapterHeading: String {
        "The Book of You - \(readerName) - Chapter \(chapterNumber) - \(monthName)"
    }

    var isEmpty: Bool {
        pageCount == 0 && sections.allSatisfy(\.items.isEmpty)
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

    var isEmpty: Bool { chapters.isEmpty }

    /// The named threads carried across the whole year, for the back matter.
    var namedConstellations: [Constellation] {
        ConstellationKeeper.namedConstellations(constellations)
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
        calendar: Calendar = .current
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
            calendar: calendar
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
                calendar: calendar
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
            continuity: yearContinuity
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
        calendar: Calendar = .current
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

        let title = "Book of You: \(monthTitle(for: startDate, calendar: calendar))"
        let subtitle = theme?.name ?? "\(dateLine(startDate, calendar: calendar)) - \(dateLine(endDate, calendar: calendar))"
        let sections = [
            themeSection(theme, pages: boundPages),
            worldEventSection(from: boundPages),
            openingSection(from: boundPages, continuity: continuity, setAsideLine: curated.setAsideLine),
            pageSection(
                id: "daily-braids",
                title: "Daily Braids",
                note: "The Book of You pages that gathered the month into nightly thread.",
                pages: boundPages.filter { $0.type == .bookOfYou },
                limit: 31
            ),
            pageSection(
                id: "souvenirs",
                title: "One-Sentence Souvenirs",
                note: "Small bright fragments, preserved before the month could blur them.",
                pages: boundPages.filter { $0.type == .souvenir },
                limit: 40
            ),
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
                    ![.bookOfYou, .souvenir, .letter, .narrativeOS, .bookConnections, .gossip, .facultyResearch, .supportGuild, .bookNotices, .illuminatedPhoto, .illustration, .enchantment].contains(page.type)
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
                body: theme.line,
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["theme"] + theme.motifs
            )
        ]
        for (index, excerpt) in theme.excerptLines.enumerated() {
            items.append(MonthlyEditionItem(
                id: "\(theme.id)-excerpt-\(index)",
                kind: .continuity,
                title: "From the pages",
                body: "\u{201C}\(excerpt)\u{201D}",
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
            note: "One current the Book found running under the month, named and held up to the light.",
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
        for signal in continuity.strongestSignals.prefix(8) {
            items.append(MonthlyEditionItem(
                id: signal.id,
                kind: .continuity,
                title: signal.subjectName,
                body: signal.line,
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
            page.type == .illuminatedPhoto || page.type == .illustration || page.type == .enchantment || !page.mediaAssets.isEmpty
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

    private static func pageItem(_ page: BookPage) -> MonthlyEditionItem {
        MonthlyEditionItem(
            id: page.id,
            kind: page.mediaAssets.isEmpty ? .page : .image,
            title: page.type.title,
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
        if !userInput.isEmpty { return userInput }
        return page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        paragraphs.append("This is what \(monthTitle) left in my keeping: \(pageLine) across \(dayLine), each one kept on purpose. I do not bind months to flatter them. I bind them so they cannot quietly unhappen.")

        let signals = continuity.strongestSignals.prefix(3)
        if !signals.isEmpty {
            let lines = signals.map { signal in
                signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
            }
            paragraphs.append("Reading it back, I noticed things I did not notice at the time. \(lines.joined(separator: ". ")). None of this is a verdict; it is the shape attention left behind.")
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
            paragraphs.append("Some threads have been with us long enough that I have given them names: \(nameLine). A named constellation is a promise that I will keep watching, which is the only kind of promise a book can make.")
        }

        let opened = wagers.filter { !$0.isSealed }
        let sealed = wagers.filter(\.isSealed)
        if !opened.isEmpty {
            let right = opened.filter { $0.status == .right }.count
            let wrong = opened.count - right
            let scoreLine: String
            if wrong == 0 {
                scoreLine = "Every wager I opened this month came true, which I will try not to let go to my spine."
            } else if right == 0 {
                scoreLine = "Every wager I opened this month was wrong. I have written each one down anyway. Being wrong in writing is how a book learns."
            } else {
                scoreLine = "Of the wagers I opened this month, \(right) came true and \(wrong) did not. I record both with the same ink."
            }
            paragraphs.append(scoreLine)
        }
        if !sealed.isEmpty {
            paragraphs.append(sealed.count == 1
                ? "One wager is still sealed in the margins. We will both find out."
                : "\(sealed.count) wagers are still sealed in the margins. We will both find out.")
        }

        paragraphs.append("Whatever else this month was, it was read. - The Book")

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
        paragraphs.append("So \(monthTitle) closes. I have read \(pageLine) back to you and to myself, and what could be kept has been kept. A month does not end so much as settle — the loud parts quiet, and what was true underneath stays where I can find it again.")

        let strongest = continuity.strongestSignals.first
        if let strongest {
            let line = strongest.line.hasSuffix(".") ? String(strongest.line.dropLast()) : strongest.line
            paragraphs.append("If this chapter leaves one thing in your hands, let it be this: \(line). I will be watching to see whether it holds, or turns, or asks for a different name.")
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if let firstNamed = named.first {
            paragraphs.append("\(firstNamed.displayName) is still alight in the margins, and I have left it burning on purpose. A thread I have named does not get blown out at the end of a month; it carries into the next one, waiting for you to write it forward.")
        }

        if let theme {
            paragraphs.append("The theme this month was \u{201C}\(theme.name)\u{201D}, and it had the last word as often as the first. Whether you chose it or it chose you, it is bound here now, and cannot be unsaid.")
        }

        paragraphs.append("Nothing in these pages can quietly unhappen now. Turn back to them whenever you like — the month will be exactly where you left it, and the next page is blank on purpose. - The Book")

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
        paragraphs.append("This is the year \(year), bound: \(pageLine) kept across \(dayLine), gathered into \(chapterLine). A year is too large to hold in the hand all at once, so I have folded it into chapters. Open any of them and the month is still there, waiting where you left it.")

        // The shape of the year, told through its themes.
        let themed = chapters.compactMap { chapter -> String? in
            guard let name = chapter.theme?.name else { return nil }
            return "\(chapter.monthName.split(separator: " ").first.map(String.init) ?? chapter.monthName), \(name)"
        }
        if !themed.isEmpty {
            paragraphs.append("The year moved the way years do — not in a straight line, but in seasons of attention. \(themed.prefix(12).joined(separator: "; ")). Read in order, they make a sentence only a whole year could say.")
        }

        let signals = continuity.strongestSignals.prefix(4)
        if !signals.isEmpty {
            let lines = signals.map { signal in
                signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
            }
            paragraphs.append("Across all twelve windows, some things kept returning until I could no longer call them coincidence. \(lines.joined(separator: ". ")). That is what a year is, finally: the patterns that survived it.")
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
            paragraphs.append("Some threads ran long enough through the year that I gave them names and a place in the sky: \(nameLine). They are charted at the back of this volume, so you can find them again from any month.")
        }

        let resolved = wagers.filter { $0.isSealed == false }
        if !resolved.isEmpty {
            let right = resolved.filter { $0.status == .right }.count
            let wrong = resolved.count - right
            let scoreLine: String
            if wrong == 0 {
                scoreLine = "Every wager I opened and resolved this year came true. I am keeping the record anyway; a book that only remembers being right is not to be trusted."
            } else if right == 0 {
                scoreLine = "Every resolved wager this year went against me. I have bound each one in full. Being wrong, written down, is how I learned to read you better."
            } else {
                scoreLine = "Of the wagers resolved this year, \(right) came true and \(wrong) did not. Both are set in the same ink, because both were honest."
            }
            paragraphs.append(scoreLine)
        }

        paragraphs.append("Whatever else \(year) was, it was read — all the way to the end, and then once more, slowly, to make this. - The Book")
        return paragraphs.joined(separator: "\n\n")
    }

    /// A short closing for the annual's back matter.
    static func annualClosing(year: Int, chapters: [MonthlyEdition]) -> String {
        let count = chapters.count
        let span = count <= 1 ? "this chapter" : "these \(count) chapters"
        return "Here \(year) ends and is kept. Nothing in \(span) can quietly unhappen now; it has been written, named, and bound. Turn back whenever you like — the year will be exactly where you left it, and so, in some way, will you. The next page is always blank on purpose. - The Book"
    }
}
