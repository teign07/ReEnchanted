import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - The Days

/// A month told day by day, the way a field journal is kept.
///
/// Each date is a facing spread: the **world's day** on the verso (the sky, the
/// scene of the month's story the reader actually read, who was in the room, a
/// clipping from the Bleed) and **your day** on the recto (the braid, the
/// photographs kept, what fed the night, your own words). Nothing here is
/// invented to fill a leaf: a day with neither side earns no leaf, and a day
/// with one side earns one.
struct BoundDayAlmanac: Codable, Equatable {
    var moonName: String
    var moonIlluminated: Double
    var moonAgeDays: Double
    /// Pooled from the sky tags on the day's own kept Pages. Never filled in
    /// from memory: a day with no sky reading says nothing.
    var skyWords: [String]
    /// The sky's calendar or the bookish days, never a personal occasion.
    var feast: String?
}

/// One scene of the month's authored story as this reader met it, frozen from
/// the receipt written when the leaf was shown. `body` is what they were shown,
/// including any sentence of their own set into it.
struct BoundDayScene: Codable, Equatable, Identifiable {
    var id: String
    var contentID: String
    var title: String
    var body: String
    var choiceLabel: String?
    var roomID: String?
    var roomName: String?
    var castIDs: [String]
    var readAt: Date
    /// True when the reader was shown the public report of this scene rather
    /// than the scene: history the Academy recorded, never something they did.
    var isReport: Bool = false
}

/// Something the reader kept, given the leaf its own kind deserves instead of
/// a line in a list: a letter is set as a letter, a class as a timetable card.
struct BoundDayKeep: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, Equatable {
        case letter, castNote, enchantment, story, classSession, club, plate, lore, quotation

        /// How a kept page is dressed, or nil when it stays a specimen.
        static func of(_ page: BookPage) -> Kind? {
            switch page.type {
            case .letter: return .letter
            case .gossip, .castBond, .bookAside, .bookNotices, .facultyResearch, .inkrestOfficeHours,
                 .wickerDare, .pactDispatch, .pactVerdict, .pactErrand, .faeBargain, .bookFae:
                return .castNote
            case .enchantment, .spell: return .enchantment
            case .narrativeOS:
                // The month's authored scenes are printed from their receipts.
                return page.tags.contains("authored-story-scene") ? nil : .story
            case .taleBound: return .story
            case .academyClass, .elective: return .classSession
            case .supportGuild, .bookJump: return .club
            case .illuminatedPhoto, .illustration: return .plate
            case .lore, .wonderCompass, .marginsAtlas: return .lore
            case .quotes, .affirmations: return .quotation
            default: return nil
            }
        }
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String
    var clock: String?
    var speakerName: String?
    var accentHex: String?
    var glyph: String?
    var room: String?
    var professor: String?
    var mediaAssets: [BookPageMediaAsset] = []
    /// What the reader wrote back on this Page, in full. A letter is printed
    /// with its answer; a class with what they made of it.
    var readerReply: String? = nil
}

/// A page the reader composed in the Pagewright, kept that day.
struct BoundScrapbookPage: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    /// What the reader wrote on it, when they wrote something; never the
    /// Pagewright's own list of the scraps it used.
    var note: String?
    var clock: String?
    /// The page as they made it: a full-page picture, and its PDF when kept.
    var image: BookPageMediaAsset?
    var pdf: BookPageMediaAsset?
    /// How much went into it: photographs, marks, pinned notes, scraps, and a
    /// note of the reader's own. The most made-over pages print full size.
    var effort: Int = 0
    /// Full size on its day, or a smaller print on the scrapbook gallery leaf.
    var fullPage: Bool = true

    /// How many scrapbook pages print full size: two in a week, six in a month.
    static func fullPageLimit(days: Int) -> Int { days <= 8 ? 2 : 6 }

    static func from(_ page: BookPage, clock: String?) -> BoundScrapbookPage? {
        let visual = page.mediaAssets.filter { $0.kind == .renderedImageFile }
        let pdf = visual.first { $0.metadata["export"] == "pdf" || $0.reference.lowercased().hasSuffix(".pdf") }
        let image = visual.first { $0.metadata["mediaRole"] == "scrapbookPreview" }
            ?? visual.first { asset in ["png", "jpg", "jpeg", "heic"].contains { asset.reference.lowercased().hasSuffix($0) } }
        guard pdf != nil || image != nil else { return nil }
        let text = page.userInput.components(separatedBy: "\n\nScraps bound here:").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Without a note the Pagewright stores only its scrap summary: no note then.
        let note = page.userInput.contains("\n\nScraps bound here:") || page.origin == .userAuthored ? text?.nonEmpty : nil
        let isSummaryOnly = !page.userInput.contains("\n\nScraps bound here:") && page.userInput.contains(": ")
            && page.userInput.split(separator: "\n").allSatisfy { $0.contains(": ") }
        func count(_ key: String) -> Int {
            page.tags.first { $0.hasPrefix("\(key):") }.flatMap { Int($0.dropFirst(key.count + 1)) } ?? 0
        }
        let finalNote = isSummaryOnly ? nil : note
        let effort = count("photo-count") * 3 + count("mark-count") * 2 + count("note-count") * 2 + count("source-count")
            + (finalNote.map { min(6, $0.split(separator: " ").count / 6 + 2) } ?? 0)
        return BoundScrapbookPage(
            id: page.id,
            title: page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "A scrapbook page",
            note: finalNote,
            clock: clock,
            image: image,
            pdf: pdf,
            effort: effort
        )
    }
}

/// Something the reader wrote that day, whole, with what it was answering.
/// Nothing is shortened: a field journal keeps the entry as it was written.
struct BoundDayEntry: Codable, Equatable, Identifiable {
    var id: String
    var pageID: String
    /// The kind of Page it was written on ("Souvenir", "Weather").
    var label: String
    /// The question the Page asked, when it asked one.
    var asked: String?
    var text: String
    var clock: String?

    var wordCount: Int { text.split(whereSeparator: { $0.isWhitespace }).count }
}

/// A line from the dial that played that day, frozen when it played.
struct BoundDayRadioLine: Codable, Equatable, Identifiable {
    var id: String
    var station: String
    var line: String
}

struct BoundDaySpecimen: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    /// "7:52", local to the keeper.
    var clock: String?
}

struct BoundDayCastLine: Codable, Equatable, Identifiable {
    var id: String
    var speakerID: String
    var speakerName: String
    var line: String
}

struct BoundDay: Codable, Equatable, Identifiable {
    var id: String
    var date: Date
    var almanac: BoundDayAlmanac
    var scenes: [BoundDayScene]
    var clippings: [MonthlyEditionItem]
    var castLines: [BoundDayCastLine]
    var braids: [MonthlyEditionItem]
    var photos: [MonthlyEditionItem]
    /// Every sentence the reader wrote that day, for the things built from
    /// their words (puzzles, the index, the found poem). `entries` is the same
    /// writing with its context, and is what the day prints.
    var words: [String]
    var entries: [BoundDayEntry] = []
    /// Scrapbook pages the reader made in the Pagewright that day: their own
    /// layout, printed whole as a page of the book.
    var scrapbook: [BoundScrapbookPage] = []
    /// The reader's typed keeps: letters, Cast notes, enchantments, stories,
    /// classes, clubs, illuminated plates.
    var keeps: [BoundDayKeep] = []
    /// What the dial played.
    var radio: [BoundDayRadioLine] = []
    /// Drawings the reader kept on that day's Pages, tucked in beside their words.
    var marks: [BookPageMediaAsset] = []
    /// The Pages whose sentences are printed as this day's words, so the
    /// archive at the back does not print them a second time.
    var wordSourceIDs: [String] = []
    var specimens: [BoundDaySpecimen]

    /// A day whose own side holds only a sentence and a few specimens: it is
    /// gathered with its neighbours rather than given a leaf to itself.
    var isThinYourSide: Bool {
        // A quotation, a Cast note or a line from the library is a small thing:
        // on a day with no night and no photograph it is gathered, not given a leaf.
        // A day the reader wrote a real entry on is never thin.
        let small: Set<BoundDayKeep.Kind> = [.quotation, .castNote, .lore]
        return hasYourSide && braids.isEmpty && photos.isEmpty && scrapbook.isEmpty && readerWordCount < 40
            && keeps.allSatisfy { small.contains($0.kind) }
    }

    /// Every Page this day prints, by id.
    var printedPageIDs: [String] {
        braids.map(\.id) + photos.map(\.id) + clippings.map(\.id) + keeps.map(\.id) + wordSourceIDs + scrapbook.map(\.id)
    }

    var hasWorldSide: Bool { !scenes.isEmpty || !clippings.isEmpty || !castLines.isEmpty || !radio.isEmpty }
    var hasYourSide: Bool { !braids.isEmpty || !photos.isEmpty || !keeps.isEmpty || !words.isEmpty || !entries.isEmpty || !scrapbook.isEmpty || specimens.count >= 2 }
    /// How many of the reader's own words this day prints.
    var readerWordCount: Int {
        entries.reduce(0) { $0 + $1.wordCount }
            + keeps.reduce(0) { $0 + ($1.readerReply?.split(whereSeparator: { $0.isWhitespace }).count ?? 0) }
    }
    var isSpread: Bool { hasWorldSide && hasYourSide }
}

/// A seven-day gathering inside the span. A weekly issue is exactly one of
/// these; a monthly volume opens each with a single leaf.
struct BoundWeek: Codable, Equatable, Identifiable {
    var id: Int { index }
    var index: Int
    var start: Date
    var end: Date
    var nightCount: Int
    var sceneTitles: [String]
    /// The strongest braid of the week by the same measure the Book uses to
    /// choose a Weekly Issue's lead.
    var strongestNight: String?
}

struct BoundRoomTally: Codable, Equatable {
    var roomID: String
    var count: Int
}

struct BoundCastPresence: Codable, Equatable, Identifiable {
    var id: String { slug }
    var slug: String
    var name: String
    var plateAssetName: String?
    var daysPresent: Int
    var sceneCount: Int
    var actCount: Int
    var rooms: [BoundRoomTally]
}

/// Where the story, and the Academy's own timetable, put people this month.
/// `timetableOnly` is true when no scene was read: the chart then says so
/// rather than implying the story went anywhere.
struct LabyrinthMonthChart: Codable, Equatable {
    var roomVisits: [String: Int]
    var route: [String]
    var cast: [BoundCastPresence]
    var timetableOnly: Bool

    /// Rooms the page draws solid. Every other room stays blank parchment.
    var drawnRoomIDs: Set<String> {
        var ids = Set(roomVisits.keys)
        for person in cast { for room in person.rooms.prefix(3) { ids.insert(room.roomID) } }
        ids.remove(AcademyGeography.dormID)
        return ids
    }
}

struct BoundDayBook: Codable, Equatable {
    var days: [BoundDay]
    var weeks: [BoundWeek]
    var chart: LabyrinthMonthChart
    /// Dates in the span with nothing to set: shown in the almanac as open.
    var quietDates: [Date]

    var scenes: [BoundDayScene] { days.flatMap(\.scenes) }
    var braidCount: Int { days.reduce(0) { $0 + $1.braids.count } }

    func day(on date: Date, calendar: Calendar = .current) -> BoundDay? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Builder

enum BoundDayBookBuilder {
    /// Hours at which the Academy's whereabouts are read for each day.
    static let sampleHours = [9, 13, 18, 21]
    static let maximumCastShown = 6
    static let maximumSpecimens = 6

    private static let readStates: Set<AuthoredContentReceiptState> = [
        .opened, .acted, .kept, .completed, .nodeCompleted, .reported, .accepted
    ]

    static func make(
        pages: [BookPage],
        keepablePages: [BookPage]? = nil,
        receipts: AuthoredContentReceiptLedger,
        castActs: [CastActRecord],
        startDate: Date,
        endDate: Date,
        includesPrivateBody: Bool = false,
        calendar: Calendar = .current
    ) -> BoundDayBook? {
        let first = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: endDate)
        guard first <= last else { return nil }

        let scenes = readScenes(receipts: receipts, start: startDate, end: endDate, calendar: calendar)
        let scenesByDay = Dictionary(grouping: scenes) { calendar.startOfDay(for: $0.readAt) }
        let radioByDay = radioLines(receipts: receipts, start: startDate, end: endDate, calendar: calendar)
        // The curator samples the small logs; it must not set aside the things
        // that now have a leaf of their own. A short Cast note, a class, a
        // quotation: each is kept from the whole month, not from the sample.
        var seenKeeps = Set<String>()
        var seenBodies = Set<String>()
        var pagesForDays = pages
        let known = Set(pages.map(\.id))
        for page in (keepablePages ?? []).sorted(by: { $0.createdAt < $1.createdAt })
        where !known.contains(page.id) && BoundDayKeep.Kind.of(page) != nil
            && page.createdAt >= startDate && page.createdAt <= endDate {
            guard seenKeeps.insert(page.id).inserted else { continue }
            let body = normalised(page.userInput + page.promptText)
            guard seenBodies.insert("\(page.type.rawValue)|\(body)").inserted else { continue }
            pagesForDays.append(page)
        }
        let pagesByDay = Dictionary(grouping: pagesForDays) { calendar.startOfDay(for: $0.createdAt) }
        // The reader's own writing comes from the whole month too. The curator's
        // sample decides which small logs are listed, never which of their
        // sentences survive.
        var writingSeen = Set(pagesForDays.map(\.id))
        var writingPages = pagesForDays
        for page in keepablePages ?? [] where page.createdAt >= startDate && page.createdAt <= endDate
            && (!page.readerAuthoredTexts.isEmpty || EditionCurator.isScrapbookPage(page)) && writingSeen.insert(page.id).inserted {
            writingPages.append(page)
        }
        let writingByDay = Dictionary(grouping: writingPages) { calendar.startOfDay(for: $0.createdAt) }
        let actsByDay = Dictionary(grouping: castActs.filter {
            $0.occurredAt >= startDate && $0.occurredAt <= endDate && !$0.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { calendar.startOfDay(for: $0.occurredAt) }

        var days: [BoundDay] = []
        var quiet: [Date] = []
        var cursor = first
        var guardCount = 0
        while cursor <= last, guardCount < 400 {
            defer {
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? last.addingTimeInterval(86_400)
                guardCount += 1
            }
            let dayPages = (pagesByDay[cursor] ?? []).sorted { $0.createdAt < $1.createdAt }
            let day = makeDay(
                date: cursor,
                pages: dayPages,
                writingPages: (writingByDay[cursor] ?? []).sorted { $0.createdAt < $1.createdAt },
                scenes: scenesByDay[cursor] ?? [],
                acts: actsByDay[cursor] ?? [],
                radio: radioByDay[cursor] ?? [],
                includesPrivateBody: includesPrivateBody,
                calendar: calendar
            )
            if day.hasWorldSide || day.hasYourSide { days.append(day) } else { quiet.append(cursor) }
        }
        guard !days.isEmpty else { return nil }
        // The most made-over scrapbook pages print full size; the rest go small
        // onto the gallery leaf. Ties go to the earlier page.
        let spanDays = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
        let ranked = days.flatMap(\.scrapbook).enumerated()
            .sorted { ($0.element.effort, -$0.offset) > ($1.element.effort, -$1.offset) }
            .map(\.element.id)
        let fullSize = Set(ranked.prefix(BoundScrapbookPage.fullPageLimit(days: spanDays)))
        for index in days.indices {
            for page in days[index].scrapbook.indices {
                days[index].scrapbook[page].fullPage = fullSize.contains(days[index].scrapbook[page].id)
            }
        }

        return BoundDayBook(
            days: days,
            weeks: weeks(of: days, start: first, calendar: calendar),
            chart: chart(
                scenes: scenes,
                acts: castActs.filter { $0.occurredAt >= startDate && $0.occurredAt <= endDate },
                first: first,
                last: last,
                calendar: calendar
            ),
            quietDates: quiet
        )
    }

    // MARK: Scenes the reader read

    static func readScenes(
        receipts: AuthoredContentReceiptLedger,
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> [BoundDayScene] {
        let relevant = receipts.receipts.filter {
            $0.channel == .storyScene
                && readStates.contains($0.state)
                && ($0.printedBody?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                && $0.recordedAt >= start && $0.recordedAt <= end
        }
        // One surface leaves several receipts (opened, acted, completed).
        // Group by the occurrence, then by body, because the same scene shown
        // in two different hours is still one scene read.
        let byOccurrence = Dictionary(grouping: relevant) { "\($0.contentID)|\($0.occurrenceID)" }
        var byBody: [String: BoundDayScene] = [:]
        for (_, group) in byOccurrence {
            let ordered = group.sorted { $0.recordedAt < $1.recordedAt }
            guard let head = ordered.first, let body = head.printedBody else { continue }
            let key = "\(head.contentID)|\(normalised(body))"
            let label = ordered.reversed().compactMap { $0.printedChoiceLabel?.nonEmpty }.first
            let candidate = BoundDayScene(
                id: "scene-\(head.contentID)-\(abs(key.stableHash))",
                contentID: head.contentID,
                title: head.printedTitle?.nonEmpty ?? "From the month's story",
                body: body,
                choiceLabel: label,
                roomID: head.roomID?.nonEmpty,
                roomName: head.roomID.flatMap { AcademyGeography.room(id: $0)?.name },
                castIDs: head.castIDs ?? [],
                readAt: head.recordedAt,
                isReport: group.allSatisfy { $0.state == .reported }
            )
            if let existing = byBody[key] {
                var merged = existing.readAt <= candidate.readAt ? existing : candidate
                merged.choiceLabel = existing.choiceLabel ?? candidate.choiceLabel
                merged.isReport = existing.isReport && candidate.isReport
                byBody[key] = merged
            } else {
                byBody[key] = candidate
            }
        }
        return byBody.values.sorted { ($0.readAt, $0.id) < ($1.readAt, $1.id) }
    }

    /// What the dial played, by the day it played, from receipts frozen then.
    static func radioLines(receipts: AuthoredContentReceiptLedger, start: Date, end: Date, calendar: Calendar) -> [Date: [BoundDayRadioLine]] {
        var seen = Set<String>()
        var byDay: [Date: [BoundDayRadioLine]] = [:]
        for receipt in receipts.receipts.sorted(by: { $0.recordedAt < $1.recordedAt })
        where receipt.channel == .radioBanter
            && receipt.recordedAt >= start && receipt.recordedAt <= end {
            guard let line = receipt.printedBody?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else { continue }
            let day = calendar.startOfDay(for: receipt.recordedAt)
            guard seen.insert("\(day.timeIntervalSince1970)|\(normalised(line))").inserted else { continue }
            byDay[day, default: []].append(BoundDayRadioLine(
                id: receipt.id,
                station: receipt.printedTitle?.nonEmpty ?? "The dial",
                line: line
            ))
        }
        return byDay
    }

    private static func normalised(_ text: String) -> String {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    // MARK: One day

    private static func makeDay(
        date: Date,
        pages: [BookPage],
        writingPages: [BookPage],
        scenes: [BoundDayScene],
        acts: [CastActRecord],
        radio: [BoundDayRadioLine],
        includesPrivateBody: Bool,
        calendar: Calendar
    ) -> BoundDay {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let moon = MoonPhaseCalendar.phase(on: noon)
        let sky = skyWords(in: pages)
        let feast = FeastdayComposer.celebrations(on: noon, context: .empty, calendar: calendar)
            .filter { !$0.commonName.localizedCaseInsensitiveContains("moon") }
            .first?.commonName

        let braids = pages.filter { $0.type == .bookOfYou }
        let clippings = pages.filter { $0.type == .theBleed }
        let photoPages = pages.filter { page in
            page.type != .bookOfYou && page.type != .theBleed
                && BoundDayKeep.Kind.of(page) == nil
                && !EditionCurator.isScrapbookPage(page)
                && page.mediaAssets.contains { $0.kind != .audioFile && $0.sourceID != "authored-marginalia" }
        }
        // Body, fuel and rest Pages are the reader's own health and stay out
        // of a printed day unless they opened that drawer for binding.
        let privateBody: Set<BookPageType> = [.body, .fuel, .rest]
        let rest = pages.filter { page in
            page.type != .bookOfYou && page.type != .theBleed
                && !EditionCurator.isScrapbookPage(page)
                && BoundDayKeep.Kind.of(page) == nil
                && (includesPrivateBody || !privateBody.contains(page.type))
        }
        let keeps = pages.compactMap { keep(from: $0, calendar: calendar) }
        // Everything the reader wrote that day, whole. A reply on a kept letter
        // or class prints with that keep; everything else is the day's entries.
        var entries: [BoundDayEntry] = []
        var seenTexts = Set<String>()
        var scrapbook: [BoundScrapbookPage] = []
        for page in writingPages where EditionCurator.isScrapbookPage(page) && !scrapbook.contains(where: { $0.id == page.id }) {
            if let made = BoundScrapbookPage.from(page, clock: clock(page.createdAt, calendar: calendar)) { scrapbook.append(made) }
        }
        for page in writingPages where page.type != .bookOfYou && page.type != .theBleed
            && !EditionCurator.isScrapbookPage(page)
            && BoundDayKeep.Kind.of(page) == nil
            && (includesPrivateBody || !privateBody.contains(page.type)) {
            for (index, raw) in page.readerAuthoredTexts.enumerated() {
                let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.count >= 3, seenTexts.insert(normalised(text)).inserted else { continue }
                entries.append(BoundDayEntry(
                    id: "\(page.id)#\(index)",
                    pageID: page.id,
                    label: page.bindingDisplayTitle,
                    asked: askedQuestion(on: page, answer: text),
                    text: text,
                    clock: clock(page.createdAt, calendar: calendar)
                ))
            }
        }
        let words = entries.map(\.text) + keeps.compactMap(\.readerReply)
        var wordSources: [String] = []
        for entry in entries where !wordSources.contains(entry.pageID) { wordSources.append(entry.pageID) }
        var seenTitles = Set<String>()
        // A Page whose writing is printed whole above is not listed again as a specimen.
        let written = Set(entries.map(\.pageID))
        let specimens: [BoundDaySpecimen] = rest.filter { !written.contains($0.id) }.compactMap { page in
            let title = page.bindingDisplayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seenTitles.insert(title.lowercased()).inserted else { return nil }
            return BoundDaySpecimen(id: page.id, title: title, clock: clock(page.createdAt, calendar: calendar))
        }.prefix(maximumSpecimens).map { $0 }

        let lines = acts.sorted { $0.occurredAt < $1.occurredAt }.prefix(2).map { act in
            BoundDayCastLine(
                id: act.id,
                speakerID: act.actorID,
                speakerName: KeepMarginalia.voice(forSlug: act.actorID)?.name ?? act.actorName,
                line: act.line.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return BoundDay(
            id: BookDay.id(for: date, calendar: calendar),
            date: date,
            almanac: BoundDayAlmanac(
                moonName: moon.name,
                moonIlluminated: moon.illuminatedFraction,
                moonAgeDays: moon.ageDays,
                skyWords: sky,
                feast: feast
            ),
            scenes: scenes,
            clippings: clippings.map(MonthlyEditionBuilder.pageItem),
            castLines: Array(lines),
            braids: braids.map(MonthlyEditionBuilder.pageItem),
            photos: photoPages.map { page in
                var item = MonthlyEditionBuilder.pageItem(page)
                item.kind = .image
                return item
            },
            words: words,
            entries: entries,
            scrapbook: scrapbook,
            keeps: keeps,
            radio: radio,
            marks: Array(pages.flatMap(\.mediaAssets).filter { $0.sourceID == "authored-marginalia" }.prefix(2)),
            wordSourceIDs: wordSources,
            specimens: specimens
        )
    }

    /// A kept page dressed for its own leaf, or nil when it stays a specimen.
    static func keep(from page: BookPage, calendar: Calendar) -> BoundDayKeep? {
        guard let kind = BoundDayKeep.Kind.of(page) else { return nil }
        let item = MonthlyEditionBuilder.pageItem(page)
        let meta = page.metadata ?? [:]
        func first(_ keys: [String]) -> String? { keys.compactMap { meta[$0]?.nonEmpty }.first }

        var title = first(["sessionName", "headline", "title"])
            ?? page.promptText.split(separator: "\n").first.map { String($0).trimmingCharacters(in: .whitespaces) }
            ?? item.title
        if title.count > 70 || title.lowercased() == "prompt" { title = item.title }
        var body = item.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { body = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !body.isEmpty || kind == .plate else { return nil }
        // A quotation arrives already dressed ("“…” — Author", sometimes twice).
        // Keep the bare words and the attribution apart; the page sets the marks once.
        var quotedBy: String? = nil
        if kind == .quotation {
            (body, quotedBy) = bareQuotation(body)
            guard !body.isEmpty else { return nil }
        }

        let slug = first(["castID", "speakerSlug", "speakerID"])
            ?? first(["academyCastIDs"])?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }
        let voice = slug.flatMap { KeepMarginalia.voice(forSlug: $0) }
        let visual = page.mediaAssets.filter { $0.kind != .audioFile && $0.sourceID != "authored-marginalia" }
        return BoundDayKeep(
            id: page.id,
            kind: kind,
            title: title,
            body: body,
            clock: clock(page.createdAt, calendar: calendar),
            speakerName: quotedBy ?? first(["speakerName", "castName", "fromName", "authorName"]) ?? voice?.name,
            accentHex: voice?.accentHex,
            glyph: voice?.glyph,
            room: first(["sessionRoom"]),
            professor: first(["sessionProfessor", "sessionTeacher", "professorName"]),
            mediaAssets: kind == .plate || kind == .enchantment ? visual : [],
            readerReply: reply(on: page, besides: body)
        )
    }

    /// The reader's writing on a kept Page, whole, or nil when they wrote none.
    private static func reply(on page: BookPage, besides body: String) -> String? {
        let bodyKey = normalised(body)
        var seen = Set<String>()
        let texts = page.readerAuthoredTexts.compactMap { raw -> String? in
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalised(text)
            guard text.count >= 3, key != bodyKey, seen.insert(key).inserted else { return nil }
            return text
        }
        return texts.isEmpty ? nil : texts.joined(separator: "\n\n")
    }

    /// The question a Page put to the reader, when it put one and it is short
    /// enough to print above their answer. Never their own words back.
    static func askedQuestion(on page: BookPage, answer: String) -> String? {
        let candidates = [page.metadata?["placeholder"], page.promptText.components(separatedBy: "\n").first]
        for candidate in candidates {
            guard let line = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty,
                  line.hasSuffix("?"), line.count <= 120,
                  normalised(line) != normalised(answer) else { continue }
            return line
        }
        return nil
    }

    /// "“\"Hope is the thing…\" — Emily Dickinson”" → ("Hope is the thing…", "Emily Dickinson").
    static func bareQuotation(_ raw: String) -> (text: String, attribution: String?) {
        let marks = CharacterSet(charactersIn: "\"“”„‟'‘’«»").union(.whitespacesAndNewlines)
        var text = raw.trimmingCharacters(in: marks)
        var attribution: String? = nil
        for dash in [" — ", " – ", " -- ", "\n— ", "\n—"] {
            if let range = text.range(of: dash, options: .backwards) {
                let who = text[range.upperBound...].trimmingCharacters(in: marks)
                // An attribution is a name, not the rest of a sentence.
                if !who.isEmpty, who.count <= 60, !who.contains(".") || who.split(separator: " ").count <= 4 {
                    attribution = who
                    text = String(text[..<range.lowerBound])
                }
                break
            }
        }
        return (text.trimmingCharacters(in: marks), attribution)
    }

    private static func skyWords(in pages: [BookPage]) -> [String] {
        var seen = Set<String>()
        var words: [String] = []
        for page in pages {
            for tag in page.context?.weatherTags ?? [] {
                let word = tag.lowercased()
                    .replacingOccurrences(of: "weather-", with: "")
                    .replacingOccurrences(of: "weather:", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty, seen.insert(word).inserted else { continue }
                words.append(word)
            }
        }
        return Array(words.prefix(3))
    }

    private static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelve, parts.minute ?? 0, hour < 12 ? "a.m." : "p.m.")
    }

    // MARK: Weeks

    private static func weeks(of days: [BoundDay], start: Date, calendar: Calendar) -> [BoundWeek] {
        let grouped = Dictionary(grouping: days) { day -> Int in
            let offset = calendar.dateComponents([.day], from: start, to: day.date).day ?? 0
            return max(0, offset) / 7
        }
        return grouped.keys.sorted().compactMap { index in
            guard let members = grouped[index]?.sorted(by: { $0.date < $1.date }),
                  let first = members.first, let last = members.last else { return nil }
            let braids = members.flatMap(\.braids)
            let strongest = braids.max { StorySpark.score($0.body) < StorySpark.score($1.body) }?.title
            var seen = Set<String>()
            let titles = members.flatMap(\.scenes).map(\.title).filter { seen.insert($0).inserted }
            return BoundWeek(
                index: index,
                start: first.date,
                end: last.date,
                nightCount: braids.count,
                sceneTitles: Array(titles.prefix(4)),
                strongestNight: strongest
            )
        }
    }

    // MARK: The Labyrinth, this month

    private static func chart(
        scenes: [BoundDayScene],
        acts: [CastActRecord],
        first: Date,
        last: Date,
        calendar: Calendar
    ) -> LabyrinthMonthChart {
        var roomVisits: [String: Int] = [:]
        var route: [String] = []
        for scene in scenes {
            guard let room = scene.roomID, AcademyGeography.room(id: room) != nil else { continue }
            roomVisits[room, default: 0] += 1
            if route.last != room { route.append(room) }
        }
        let academyScenes = scenes.compactMap { scene -> AcademyScene? in
            guard let room = scene.roomID, !scene.castIDs.isEmpty else { return nil }
            return AcademyScene(roomID: room, castIDs: scene.castIDs, at: scene.readAt)
        }

        var tally: [String: [String: Int]] = [:]
        var daysSeen: [String: Set<Int>] = [:]
        var names: [String: String] = [:]
        var dayIndex = 0
        var day = first
        while day <= last, dayIndex < 400 {
            for hour in sampleHours {
                guard let moment = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
                for person in AcademyWhereabouts.everyone(at: moment, calendar: calendar, scenes: academyScenes) {
                    guard !person.isVisitor, person.roomID != AcademyGeography.dormID else { continue }
                    tally[person.characterID, default: [:]][person.roomID, default: 0] += 1
                    daysSeen[person.characterID, default: []].insert(dayIndex)
                    names[person.characterID] = person.name
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? last.addingTimeInterval(86_400)
            dayIndex += 1
        }

        var sceneCounts: [String: Int] = [:]
        for scene in scenes { for id in scene.castIDs { sceneCounts[id, default: 0] += 1 } }
        var actCounts: [String: Int] = [:]
        for act in acts { actCounts[act.actorID, default: 0] += 1 }

        let ids = Set(tally.keys).union(sceneCounts.keys).union(actCounts.keys)
        let ranked = ids.map { id -> (score: Int, presence: BoundCastPresence) in
            let rooms = (tally[id] ?? [:])
                .map { BoundRoomTally(roomID: $0.key, count: $0.value) }
                .sorted { ($1.count, $0.roomID) < ($0.count, $1.roomID) }
            let displayName = KeepMarginalia.voice(forSlug: id)?.name ?? names[id] ?? prettified(id)
            let presence = BoundCastPresence(
                slug: id,
                name: displayName,
                plateAssetName: CastMarginalia.plateAssetName(forSlug: id),
                daysPresent: daysSeen[id]?.count ?? 0,
                sceneCount: sceneCounts[id] ?? 0,
                actCount: actCounts[id] ?? 0,
                rooms: Array(rooms.prefix(6))
            )
            let score = (sceneCounts[id] ?? 0) * 4 + (actCounts[id] ?? 0) * 2 + min(10, daysSeen[id]?.count ?? 0)
            return (score, presence)
        }
        .filter { $0.score > 0 }
        .sorted { ($1.score, $0.presence.slug) < ($0.score, $1.presence.slug) }
        .prefix(maximumCastShown)
        .map(\.presence)

        return LabyrinthMonthChart(
            roomVisits: roomVisits,
            route: route,
            cast: Array(ranked),
            timetableOnly: scenes.isEmpty
        )
    }

    private static func prettified(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

// MARK: - Fitting a day book to its page cap

extension BoundDayBook {
    /// One step smaller, or nil when nothing more may be given up. The order is
    /// the order of what the book can best spare: a second photograph and the
    /// long specimen lists first, then the days that held only a sentence, then
    /// the clippings and the Cast's lines, and last the world's side of days
    /// the reader kept nothing on. The nights and the scenes go last of all.
    func trimmedForPrint(sparingNights: Bool = false) -> BoundDayBook? {
        var copy = self
        // 1. A second photograph, and long specimen lists.
        var changed = false
        for index in copy.days.indices {
            if copy.days[index].photos.count > 1 { copy.days[index].photos = Array(copy.days[index].photos.prefix(1)); changed = true }
            if copy.days[index].specimens.count > 3 { copy.days[index].specimens = Array(copy.days[index].specimens.prefix(3)); changed = true }
        }
        if changed { return copy }
        // 2. Days that held only a sentence and a few specimens give up the
        //    specimens and the small keeps; what the reader wrote stays.
        if copy.days.contains(where: { $0.isThinYourSide && (!$0.specimens.isEmpty || $0.keeps.contains { $0.readerReply == nil }) }) {
            for index in copy.days.indices where copy.days[index].isThinYourSide {
                copy.days[index].specimens = []
                copy.days[index].keeps = copy.days[index].keeps.filter { $0.readerReply != nil }
            }
            copy.days.removeAll { !$0.hasWorldSide && !$0.hasYourSide }
            copy.weeks = BoundDayBook.rebuiltWeeks(copy.weeks, days: copy.days)
            // A day that stays thin on its keeps would match again forever.
            if copy != self { return copy }
        }
        // 3. The clippings and the Cast's lines.
        if copy.days.contains(where: { !$0.clippings.isEmpty || !$0.castLines.isEmpty }) {
            for index in copy.days.indices {
                copy.days[index].clippings = []
                copy.days[index].castLines = []
            }
            copy.days.removeAll { !$0.hasWorldSide && !$0.hasYourSide }
            return copy
        }
        // 3½. A long book prints fewer scrapbook pages full size (the least
        //     made-over first); they stay in the book, small, on the gallery leaf.
        let fullPages = copy.days.flatMap(\.scrapbook).filter(\.fullPage)
        if fullPages.count > 1, let least = fullPages.min(by: { $0.effort < $1.effort }) {
            for index in copy.days.indices {
                for page in copy.days[index].scrapbook.indices where copy.days[index].scrapbook[page].id == least.id {
                    copy.days[index].scrapbook[page].fullPage = false
                }
            }
            return copy
        }
        // 4. Days with a night and no scene lose nothing but their sentence;
        //    then half the nights that held no scene, evenly spaced. A caller
        //    with anything else left to give asks for the nights to be spared.
        if sparingNights { return nil }
        let sceneless = copy.days.indices.filter { copy.days[$0].scenes.isEmpty && !copy.days[$0].braids.isEmpty }
        if sceneless.count > 4 {
            let keep = Set(EditionPrintFitting.evenlySpaced(sceneless, keeping: sceneless.count / 2))
            for index in sceneless where !keep.contains(index) {
                // The night goes; the reader's own entries and replies stay.
                copy.days[index].braids = []
                copy.days[index].specimens = []
                copy.days[index].photos = []
            }
            copy.days.removeAll { !$0.hasWorldSide && !$0.hasYourSide }
            copy.weeks = BoundDayBook.rebuiltWeeks(copy.weeks, days: copy.days)
            return copy
        }
        return nil
    }

    /// How much a day holds: what a thin book would least miss scores lowest.
    static func weight(_ day: BoundDay) -> Int {
        day.scenes.count * 3 + day.braids.count * 3 + day.keeps.count * 2 + day.photos.count * 2 + day.scrapbook.count * 4
            + day.clippings.count + day.castLines.count + day.radio.count + min(day.readerWordCount / 20, 6)
    }

    /// The last resort of a thin book the reader chose: let go of the single
    /// lightest day. Never below `floor` days, and the edition says it did.
    func droppingLightestDay(floor: Int = 8) -> BoundDayBook? {
        guard days.count > floor,
              let index = days.indices.min(by: { BoundDayBook.weight(days[$0]) < BoundDayBook.weight(days[$1]) })
        else { return nil }
        var copy = self
        copy.days.remove(at: index)
        copy.weeks = BoundDayBook.rebuiltWeeks(copy.weeks, days: copy.days)
        return copy
    }

    fileprivate static func rebuiltWeeks(_ weeks: [BoundWeek], days: [BoundDay]) -> [BoundWeek] {
        weeks.compactMap { week in
            let members = days.filter { $0.date >= week.start && $0.date <= week.end }
            guard !members.isEmpty else { return nil }
            var updated = week
            updated.nightCount = members.reduce(0) { $0 + $1.braids.count }
            return updated
        }
    }
}

// MARK: - The Ledger of Nights

/// One line for one night: the date, the title, and what the night's closing
/// said it kept. A year printed at 256 pages cannot hold three hundred braids
/// in full; this holds every one of them, and the full text stays where it is.
struct BoundNightLine: Codable, Equatable, Identifiable {
    var id: String
    var date: Date
    var title: String
    var line: String

    static func ledger(from chapters: [MonthlyEdition]) -> [BoundNightLine] {
        chapters.flatMap { chapter -> [BoundNightLine] in
            let items = chapter.sections.first(where: { $0.id == "daily-braids" })?.items ?? []
            return items.compactMap { item -> BoundNightLine? in
                guard item.pageType == .bookOfYou, let date = item.date else { return nil }
                return BoundNightLine(id: item.id, date: date, title: item.title, line: keptLine(from: item.body))
            }
        }
        .sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    /// The closing line of a night, without its stock opening.
    static func keptLine(from body: String) -> String {
        let paragraphs = body.replacingOccurrences(of: "*", with: "")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard var last = paragraphs.last else { return "" }
        for prefix in ["The Book kept the page:", "The Book kept the page —", "Kept:"] where last.hasPrefix(prefix) {
            last = String(last.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        if last.count > 110 {
            last = String(last.prefix(107)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return last
    }
}

// MARK: - The Month's Tale

/// One chapter of the month's story as the reader read it: every receipt of
/// one scene, in reading order. The Days point to it by number.
struct BoundTaleChapter: Equatable, Identifiable {
    var id: String { contentID }
    var number: Int
    var contentID: String
    var title: String
    var readAt: Date
    var roomName: String?
    var castIDs: [String]
    /// The scene's parts, in the order they were read.
    var parts: [BoundDayScene]
    /// True when every part was the Academy's record rather than the scene.
    var isReport: Bool { parts.allSatisfy(\.isReport) }
}

extension BoundDayBook {
    /// The month's scenes bound as one story: a chapter per scene, numbered
    /// in the order the reader first met it.
    var taleChapters: [BoundTaleChapter] {
        var chapters: [BoundTaleChapter] = []
        var index: [String: Int] = [:]
        for scene in days.flatMap(\.scenes).sorted(by: { ($0.readAt, $0.id) < ($1.readAt, $1.id) }) {
            if let at = index[scene.contentID] {
                chapters[at].parts.append(scene)
                for slug in scene.castIDs where !chapters[at].castIDs.contains(slug) { chapters[at].castIDs.append(slug) }
                continue
            }
            index[scene.contentID] = chapters.count
            chapters.append(BoundTaleChapter(
                number: chapters.count + 1,
                contentID: scene.contentID,
                title: scene.title,
                readAt: scene.readAt,
                roomName: scene.roomName,
                castIDs: scene.castIDs,
                parts: [scene]
            ))
        }
        return chapters
    }

    /// Every sentence the reader wrote this month, for marking the places the
    /// story quotes them.
    var readerSentences: [String] {
        days.flatMap { day in day.entries.map(\.text) + day.keeps.compactMap(\.readerReply) }
            .flatMap { text in text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { $0.count >= 16 }
    }

    /// The opening of a scene for its day: the first paragraph, cut at a
    /// sentence near `words` words. The whole scene is in the Tale.
    static func opening(of body: String, words limit: Int = 60) -> String {
        let cleaned = body.replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\\{[A-Za-z0-9_.\\-]+\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "*", with: "")
        // Paragraphs in order until there is enough to set the scene: a
        // one-line opening ("A book lands in the soup.") wants its next breath.
        var gathered: [String] = []
        var count = 0
        for line in cleaned.components(separatedBy: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) where !line.isEmpty {
            gathered.append(line)
            count += line.split(separator: " ").count
            if count >= 40 { break }
        }
        let paragraph = gathered.isEmpty ? cleaned.trimmingCharacters(in: .whitespacesAndNewlines) : gathered.joined(separator: " ")
        let words = paragraph.split(separator: " ")
        guard words.count > limit else { return paragraph }
        var cut = words.prefix(limit).joined(separator: " ")
        // Back to the last full sentence when there is one in reach.
        if let end = cut.lastIndex(where: { ".!?”".contains($0) }), cut.distance(from: cut.startIndex, to: end) > cut.count / 3 {
            cut = String(cut[...end])
        } else {
            cut += "…"
        }
        return cut
    }
}

enum RomanNumeral {
    static func of(_ value: Int) -> String {
        guard value > 0, value < 4000 else { return "\(value)" }
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = value
        var out = ""
        for (amount, glyph) in table { while n >= amount { out += glyph; n -= amount } }
        return out
    }
}

// MARK: - The Tale of Your Week

/// One day of a weekly issue told as a chapter of a storybook. Everything in
/// it is what the week actually held: the night's telling, the reader's own
/// entries, the scene they read, a Cast line. Only the joins are the Book's.
struct WeeklyTaleChapter: Equatable, Identifiable {
    var id: String { day.id }
    var number: Int
    var day: BoundDay
    /// "In which the kettle got its whole speech."
    var heading: String
    /// The storybook first line: "Once upon a Thursday, under a waning crescent."
    var opener: String
    /// The night's braid, without its closing colophon line.
    var telling: String?
    var tellingTitle: String?
    /// The braid's colophon, set at the chapter's foot.
    var keptLine: String?
    /// A thing actually written about on two different days, never a connection
    /// inferred from the Book's magic or an authored scene.
    var returnNote: String? = nil
}

enum WeeklyTaleBuilder {
    static let colophonStem = "The Book kept the page:"

    static func chapters(of book: BoundDayBook, from start: Date, to end: Date, calendar: Calendar) -> [WeeklyTaleChapter] {
        let first = calendar.startOfDay(for: start)
        let days = book.days.filter { $0.date >= first && $0.date <= end && ($0.hasYourSide || $0.hasWorldSide) }
        var chapters: [WeeklyTaleChapter] = []
        var used = Set<String>()
        let moments = days.flatMap { day in
            day.entries.map { WeeklyTaleReading.Moment(pageID: $0.pageID, date: day.date, text: $0.text) }
        }
        let returns = WeeklyTaleReading.returns(in: moments, calendar: calendar)
        var notedReturns = Set<String>()
        for (index, day) in days.enumerated() {
            let braid = day.braids.first
            let (telling, kept) = braid.map { split(braid: $0.body) } ?? (nil, nil)
            // A week never names two chapters alike: the next honest heading instead.
            let candidates = headings(for: day, telling: telling, kept: kept, tags: braid?.tags ?? [])
            let heading = candidates.first { !used.contains($0.lowercased()) }
                ?? "\(candidates.first ?? fallbackHeading) · \(dayName(day.date, calendar: calendar))"
            used.insert(heading.lowercased())
            let returning = returns.first { entry in
                !notedReturns.contains(entry.word)
                    && entry.moments.dropFirst().contains { calendar.isDate($0.date, inSameDayAs: day.date) }
            }
            let returnNote = returning.map { entry -> String in
                notedReturns.insert(entry.word)
                let earlier = dayName(entry.moments[0].date, calendar: calendar)
                return "I remember “\(entry.word)” from \(earlier)'s page. Here it is again."
            }
            chapters.append(WeeklyTaleChapter(
                number: index + 1,
                day: day,
                heading: heading,
                opener: opener(for: day, index: index, count: days.count, calendar: calendar),
                telling: telling,
                tellingTitle: braid?.title,
                keptLine: kept,
                returnNote: returnNote
            ))
        }
        return chapters
    }

    /// A braid's body without the colophon, and the colophon on its own.
    static func split(braid body: String) -> (String?, String?) {
        var kept: String?
        var paragraphs: [String] = []
        for raw in body.components(separatedBy: "\n") {
            let paragraph = raw.trimmingCharacters(in: .whitespaces)
            guard !paragraph.isEmpty else { continue }
            if paragraph.hasPrefix(colophonStem) { kept = paragraph } else { paragraphs.append(paragraph) }
        }
        let telling = paragraphs.joined(separator: "\n\n")
        return (telling.isEmpty ? nil : telling, kept)
    }

    static let fallbackHeading = "In which a few small things were kept"

    /// "In which …" for one day: the first of `headings`.
    static func heading(for day: BoundDay, kept: String?, telling: String? = nil, tags: [String] = []) -> String {
        headings(for: day, telling: telling, kept: kept, tags: tags).first ?? fallbackHeading
    }

    /// Every honest "In which …" for a day, best first. The reader's raw
    /// sentence is never the title; a detail of theirs may be retold, in the
    /// Book's storybook voice, the way a chapter of a tale is named.
    ///
    /// 1. The night's colophon, when the Book chose it for this night alone:
    ///    "In which the card came home from Portugal with your name still on it".
    /// 2. A detail the reader wrote, retold: "Found a moth asleep inside the
    ///    lampshade" becomes "In which you found a moth asleep inside the
    ///    lampshade" (`readerDetailHeading`: past tense and a real thing in it),
    ///    then a thing their fragment names ("In which there was a low grey sky").
    /// 3. A page they made in the Pagewright that day.
    /// 4. The authored library line the night's telling carried.
    /// 5. A stock colophon (the planner's seven, written once each), then what
    ///    the day held: the room, a letter, a Cast note, a photograph.
    static func headings(for day: BoundDay, telling: String?, kept: String?, tags: [String]) -> [String] {
        var found: [String] = []
        func add(_ heading: String?) {
            guard let heading, !found.contains(heading) else { return }
            found.append(heading)
        }
        // What the Book kept that night, when it chose it for this night alone:
        // "In which the card came home from Portugal with your name still on it".
        if let kept, !isStockColophon(kept) { add(colophonHeading(kept, readerWords: day.words + day.entries.map(\.text))) }
        // Then a real detail of the day, retold in the Book's voice. A roof, a
        // heron, a worn brass plate: the days have names already. The reader's
        // sentence itself is never the title; it is printed whole beneath.
        for entry in day.entries {
            add(readerDetailHeading(entry.text))
        }
        // A day written in fragments ("Grey all day, then a thin pink stripe at
        // five") still names a thing: "In which there was a thin pink stripe".
        for entry in day.entries {
            add(readerThingHeading(entry.text))
        }
        // A page they made by hand names its day: "In which you made a page of ticket stubs".
        if let made = day.scrapbook.max(by: { $0.effort < $1.effort }), made.title != "A scrapbook page" {
            add("In which you made a page of \(lowercasedFirst(lowercasedArticle(made.title)))")
        }
        if let telling {
            for line in carriedLines(tags: tags, telling: telling) { add("In which " + clause(of: line)) }
        }
        if let kept, isStockColophon(kept) { add(colophonHeading(kept, readerWords: day.words + day.entries.map(\.text))) }
        if let scene = day.scenes.first(where: { !$0.isReport }) {
            add("In which you went into \(scene.roomName.map(lowercasedArticle) ?? "the Labyrinth")")
        } else if !day.scenes.isEmpty {
            add("In which the Academy wrote something down")
        }
        if let letter = day.keeps.first(where: { $0.kind == .letter }), let from = letter.speakerName {
            add("In which a letter came from \(from)")
        }
        if let note = day.castLines.first {
            add("In which \(note.speakerName) left you a note")
        } else if let note = day.keeps.first(where: { $0.kind == .castNote }), let from = note.speakerName {
            add("In which \(from) left you a note")
        }
        if !day.photos.isEmpty { add(day.photos.count == 1 ? "In which you kept a photograph" : "In which you kept \(day.photos.count) photographs") }
        if let keep = day.keeps.first(where: { $0.kind == .enchantment }) { add("In which \(keep.title) was cast") }
        if day.readerWordCount >= 40 { add("In which you wrote it all down") }
        add(fallbackHeading)
        return found
    }

    /// The first concrete thing a reader's fragment names, as a heading.
    static func readerThingHeading(_ text: String) -> String? {
        var fragment = BraidScenePlan.fragment(of: text, fromEnd: false)
        // "a low grey sky sitting": a thing, not the start of what it did.
        while let last = fragment.split(separator: " ").last, fragment.split(separator: " ").count > 2,
              last.lowercased().hasSuffix("ing") || isPastVerb(String(last)) {
            fragment = fragment.split(separator: " ").dropLast().joined(separator: " ")
        }
        let words = fragment.split(separator: " ")
        guard fragment != "A Quiet Night", (2...6).contains(words.count), hasConcreteNoun(fragment),
              BraidSceneWriter.secondPerson(text).lowercased().contains(fragment.lowercased()) else { return nil }
        let thing = lowercasedFirst(fragment)
        let article = ["the ", "a ", "an ", "your ", "some ", "two ", "three "].contains { thing.lowercased().hasPrefix($0) } ? "" : "a "
        let noun = article.isEmpty ? thing : (thing.first.map { "aeiou".contains($0.lowercased()) } == true ? "an " : "a ") + thing
        return "In which there was " + noun
    }

    /// True for the planner's seven stock colophons, which every month repeats.
    static func isStockColophon(_ kept: String) -> Bool {
        let thing = String(kept.dropFirst(colophonStem.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces))
        return stockColophonHeadings[thing.lowercased()] != nil
    }

    /// A detail the reader wrote, told back the way the Book tells a chapter:
    /// "Found a moth asleep inside the lampshade. Left it there." becomes
    /// "In which you found a moth asleep inside the lampshade". One clause,
    /// with a subject and a verb, or nil: a fragment ("Clear and sharp") or
    /// a list is never made into a title.
    static func readerDetailHeading(_ text: String) -> String? {
        for sentence in WonderBraid.sentences(text) {
            var clause = BraidSceneWriter.secondPerson(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            while let last = clause.last, ".!?;:,".contains(last) { clause.removeLast() }
            // One clause: cut at its first turn.
            let turns = [" because ", ", and ", ", but ", "; ", " \u{2014} ", " - ", ", so ", " so that ", ", which"]
            let cuts = turns.compactMap { turn -> String.Index? in
                guard let range = clause.range(of: turn) else { return nil }
                return clause[..<range.lowerBound].split(separator: " ").count >= 3 ? range.lowerBound : nil
            }
            if let cut = cuts.min() { clause = String(clause[..<cut]) }
            let words = clause.split(separator: " ").map(String.init)
            guard (3...12).contains(words.count), clause.count <= 72, let first = words.first else { continue }
            // A title names a thing that happened: past tense, and a real noun
            // in it. "You like it more than you should" has neither.
            guard hasConcreteNoun(clause) else { continue }
            let lead = first.lowercased()
            if lead == "you" || lead == "we" {
                guard words.count > 1, isPastVerb(words[1]) else { continue }
                return "In which " + (lead == "we" ? "you " + words.dropFirst().joined(separator: " ") : lowercasedFirst(clause))
            }
            if ["the", "a", "an", "your", "my", "our", "his", "her", "their"].contains(lead) {
                // A thing that did something: "The heron stood by the canal".
                guard words.dropFirst().contains(where: isPastVerb) else { continue }
                return "In which " + lowercasedFirst(clause)
            }
            if isPastVerb(first) {
                // A diary's subjectless line: "Scraped the windshield…" is something you did.
                return "In which you " + lowercasedFirst(clause)
            }
        }
        return nil
    }

    /// A noun that is a thing, not "it", "this" or "something".
    private static func hasConcreteNoun(_ text: String) -> Bool {
        let vague: Set<String> = ["it", "this", "that", "thing", "things", "something", "anything", "nothing", "everything", "stuff", "lot", "bit", "way", "day", "time"]
        // Without the tagger's assets (a simulator, a fresh install) every tag
        // comes back nil; a book must not lose its titles to a missing download.
        let plain = text.split(separator: " ").map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        let heuristic = plain.contains { $0.count >= 4 && !vague.contains($0) && !isPastVerb($0) && !["your", "with", "from", "into", "then", "there", "were", "what", "when", "they", "them"].contains($0) }
        #if canImport(NaturalLanguage)
        var found = false
        var tagged = false
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag != nil, tag != .otherWord { tagged = true }
            if tag == .noun, !vague.contains(text[range].lowercased()) { found = true; return false }
            return true
        }
        return tagged ? found : heuristic
        #else
        return heuristic
        #endif
    }

    private static let irregularPast: Set<String> = [
        "found", "made", "went", "came", "saw", "took", "gave", "got", "left", "kept", "held", "ran", "sat", "stood",
        "ate", "drank", "wrote", "read", "told", "said", "heard", "felt", "fell", "slept", "woke", "brought", "bought",
        "caught", "thought", "taught", "met", "lost", "won", "sang", "swam", "spent", "lent", "sent", "built", "hung",
        "put", "set", "cut", "let", "shut", "hit", "rode", "drove", "began", "broke", "chose", "forgot", "knew", "grew",
        "threw", "blew", "flew", "drew", "wore", "tore", "swore", "shook", "stuck", "spun", "dug", "lit", "fed", "led", "was", "were", "had", "did"
    ]

    private static func isPastVerb(_ word: String) -> Bool {
        let w = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard w.count >= 3 else { return false }
        if irregularPast.contains(w) { return true }
        return w.hasSuffix("ed") && !["red", "bed", "shed", "seed", "need", "speed", "feed", "hundred", "sacred", "naked", "wicked", "tired"].contains(w)
    }

    private static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        // "I" and a name keep their capital; everything else is mid-sentence now.
        let firstWord = text.split(separator: " ").first.map(String.init) ?? ""
        if firstWord == "I" || (firstWord.count > 1 && firstWord.dropFirst().contains(where: \.isUppercase)) { return text }
        return String(first).lowercased() + text.dropFirst()
    }

    /// The library lines a wonder braid used, in telling order, that the
    /// telling actually kept: most of the line's own words are in it.
    static func carriedLines(tags: [String], telling: String) -> [String] {
        let prefix = WonderBraidHistory.tagPrefix
        let ids = tags.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        guard !ids.isEmpty else { return [] }
        let told = Set(WonderBraid.contentWords(telling).map(WonderBraid.stem))
        return ids.compactMap { id in
            guard let line = WonderBraid.lines.first(where: { $0.id == id })?.text else { return nil }
            let own = Set(WonderBraid.contentWords(line).map(WonderBraid.stem))
            guard own.count >= 3 else { return nil }
            return Double(own.intersection(told).count) / Double(own.count) >= 0.75 ? line : nil
        }
    }

    /// A line as a heading's clause: the first sentence, without its full
    /// stop, and cut at its first turn when it runs long. "The kettle was in
    /// the middle of a sentence, and nobody had told it how the sentence
    /// ended." → "the kettle was in the middle of a sentence".
    static func clause(of line: String) -> String {
        var text = (WonderBraid.sentences(line).first ?? line).trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = text.last, ".!?;:,".contains(last) { text.removeLast() }
        if text.count > 78 {
            let turns = [", which", ", and ", ", but ", "; ", " \u{2014} ", ", as if", " as if ", " as though ", " like ", ", so "]
            let cuts = turns.compactMap { turn -> String.Index? in
                guard let range = text.range(of: turn) else { return nil }
                return text[..<range.lowerBound].split(separator: " ").count >= 4 ? range.lowerBound : nil
            }
            if let cut = cuts.min() { text = String(text[..<cut]) }
        }
        return lowercasedArticle(text)
    }

    /// "The East Stacks" mid-sentence is "the East Stacks".
    static func lowercasedArticle(_ text: String) -> String {
        for article in ["The ", "A ", "An ", "Every ", "Some ", "Its ", "Your ", "My "] where text.hasPrefix(article) {
            return article.lowercased() + text.dropFirst(article.count)
        }
        return text
    }

    /// The planner's own colophons (`BraidSceneWriter.keeperColophon`), the same
    /// seven all month, each with a heading of its own.
    static let stockColophonHeadings: [String: String] = [
        "the words stayed in the order they came": "In which the words stayed in the order they came",
        "two things, side by side, and i am not explaining them": "In which two things sat side by side",
        "i knew it when i saw it": "In which I knew it when I saw it",
        "nothing got fixed, and i kept it anyway": "In which nothing got fixed",
        "it came back, but not the same": "In which something came back, but not the same",
        "the no held": "In which the no held",
        "it happened, and i wrote it down": "In which it happened, and I wrote it down"
    ]

    /// "In which …" from what the Book kept, or nil when the colophon is empty
    /// or only says back a sentence the reader wrote.
    static func colophonHeading(_ kept: String, readerWords: [String]) -> String? {
        var thing = String(kept.dropFirst(colophonStem.count)).trimmingCharacters(in: .whitespaces)
        thing = thing.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard !thing.isEmpty else { return nil }
        if let stock = stockColophonHeadings[thing.lowercased()] { return stock }
        if WeeklyCuration.repeats(thing, of: readerWords) { return nil }
        // "the kettle got its whole speech" reads as a heading already;
        // a bare noun ("the cat on the long way") is given a verb.
        let words = thing.split(separator: " ").map(String.init)
        let hasVerb = words.contains(where: isPastVerb)
            || ["you", "i", "we", "they", "he", "she"].contains(words.first?.lowercased() ?? "")
        return "In which " + (hasVerb ? thing : "there was \(thing)")
    }

    /// The storybook first line of a chapter: the weekday and the sky, nothing invented.
    static func opener(for day: BoundDay, index: Int, count: Int, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        let weekday = formatter.string(from: day.date)
        let rawMoon = day.almanac.moonName.lowercased()
        let moon = rawMoon.contains("moon") ? rawMoon : rawMoon + " moon"
        let skyWord = day.almanac.skyWords.lazy.compactMap { skyAdjective[$0.lowercased()] }.first
        let sky = skyWord.map { " and the sky was \($0)" } ?? ""
        if index == 0 { return "Once upon a \(weekday), under a \(moon)\(sky), this is what happened." }
        if index == count - 1 { return "And then it was \(weekday)\(sky). This is the last page I have from that week." }
        switch index % 3 {
        case 1: return "Then it was \(weekday)\(sky)."
        case 2: return "On \(weekday) there was a \(moon)\(sky)."
        default: return "\(weekday) came next\(sky)."
        }
    }

    private static func dayName(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private static let skyAdjective: [String: String] = [
        "clear": "clear", "sun": "bright", "sunny": "bright", "rain": "raining", "drizzle": "drizzling",
        "cloud": "grey", "cloudy": "grey", "overcast": "grey", "wind": "windy", "windy": "windy",
        "fog": "foggy", "mist": "misty", "snow": "snowing", "storm": "stormy", "frost": "frosty"
    ]

    static func ordinal(_ n: Int) -> String {
        let words = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
        return n >= 1 && n <= words.count ? "the \(words[n - 1])" : "\(n)"
    }
}

// MARK: - Before I bind this

/// What the reader writes at the press, before a monthly is bound: a few
/// answers about the month, printed in their hand at the front, and a line
/// for days the book holds nothing of theirs, printed on those days. All of it
/// is optional, and none of it is invented if they leave it blank.
struct BindingAccount: Codable, Equatable {
    var answers: [String: String] = [:]
    /// Keyed by `BoundDay.id`.
    var dayLines: [String: String] = [:]

    static func questions(monthName: String) -> [String] {
        [
            "What happened this month that you'd tell someone first?",
            "What did you notice that nobody else did?",
            "What's one thing you want to remember about how it felt?",
            "If \(monthName) were a door, what colour was it, and did you go through?",
            "What do you want next month to bring?"
        ]
    }

    static let ask = "Before I bind this, I've got a few questions. Answer any of them, or none. Whatever you write goes in the front, in your own hand."
    static let quietAsk = "I've got nothing from you on these days. One line each, if you remember anything."

    var isEmpty: Bool {
        answers.values.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && dayLines.values.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The answered questions, in the order they were asked.
    func answered(monthName: String) -> [(question: String, answer: String)] {
        Self.questions(monthName: monthName).compactMap { question in
            guard let answer = answers[question]?.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else { return nil }
            return (question, answer)
        }
    }

    /// Days the reader wrote nothing on but the book still prints: the ones a
    /// line would complete. Fullest first, at most `limit`.
    static func quietDays(in book: BoundDayBook, limit: Int = 6) -> [BoundDay] {
        book.days.filter { $0.readerWordCount == 0 && ($0.hasWorldSide || !$0.braids.isEmpty || !$0.photos.isEmpty) }
            .sorted { BoundDayBook.weight($0) > BoundDayBook.weight($1) }
            .prefix(limit)
            .sorted { $0.date < $1.date }
    }

    // A draft survives the sheet closing: it is the reader's writing.
    private static func key(_ editionKey: String) -> String { "bindingAccount.\(editionKey)" }

    static func draft(for editionKey: String) -> BindingAccount {
        guard let data = UserDefaults.standard.data(forKey: key(editionKey)),
              let account = try? JSONDecoder().decode(BindingAccount.self, from: data) else { return BindingAccount() }
        return account
    }

    func saveDraft(for editionKey: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key(editionKey))
    }
}

extension MonthlyEdition {
    /// The edition with the reader's account bound in: the answers for the
    /// front, and each day's line as an entry on that day.
    func applying(_ account: BindingAccount) -> MonthlyEdition {
        guard !account.isEmpty else { return self }
        var copy = self
        copy.bindingAccount = account
        if var book = copy.dayBook {
            for index in book.days.indices {
                guard let line = account.dayLines[book.days[index].id]?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else { continue }
                book.days[index].entries.append(BoundDayEntry(
                    id: "binding-\(book.days[index].id)", pageID: "binding-\(book.days[index].id)",
                    label: "Written before binding", asked: nil, text: line, clock: nil
                ))
                book.days[index].words.append(line)
            }
            copy.dayBook = book
        }
        return copy
    }
}
