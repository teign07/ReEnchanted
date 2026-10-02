import Foundation

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
    var words: [String]
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
        let small: Set<BoundDayKeep.Kind> = [.quotation, .castNote, .lore]
        return hasYourSide && braids.isEmpty && photos.isEmpty && keeps.allSatisfy { small.contains($0.kind) }
    }

    /// Every Page this day prints, by id.
    var printedPageIDs: [String] {
        braids.map(\.id) + photos.map(\.id) + clippings.map(\.id) + keeps.map(\.id) + wordSourceIDs
    }

    var hasWorldSide: Bool { !scenes.isEmpty || !clippings.isEmpty || !castLines.isEmpty || !radio.isEmpty }
    var hasYourSide: Bool { !braids.isEmpty || !photos.isEmpty || !keeps.isEmpty || !words.isEmpty || specimens.count >= 2 }
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
    static let maximumWords = 2

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
                scenes: scenesByDay[cursor] ?? [],
                acts: actsByDay[cursor] ?? [],
                radio: radioByDay[cursor] ?? [],
                includesPrivateBody: includesPrivateBody,
                calendar: calendar
            )
            if day.hasWorldSide || day.hasYourSide { days.append(day) } else { quiet.append(cursor) }
        }
        guard !days.isEmpty else { return nil }

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
                && BoundDayKeep.Kind.of(page) == nil
                && (includesPrivateBody || !privateBody.contains(page.type))
        }
        let keeps = pages.compactMap { keep(from: $0, calendar: calendar) }
        var words: [String] = []
        var wordSources: [String] = []
        for page in rest {
            for text in page.readerAuthoredTexts {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (8...180).contains(trimmed.count), !words.contains(trimmed) else { continue }
                words.append(trimmed)
                wordSources.append(page.id)
                if words.count >= maximumWords { break }
            }
            if words.count >= maximumWords { break }
        }
        var seenTitles = Set<String>()
        let specimens: [BoundDaySpecimen] = rest.compactMap { page in
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
            speakerName: first(["speakerName", "castName", "fromName", "authorName"]) ?? voice?.name,
            accentHex: voice?.accentHex,
            glyph: voice?.glyph,
            room: first(["sessionRoom"]),
            professor: first(["sessionProfessor", "sessionTeacher", "professorName"]),
            mediaAssets: kind == .plate || kind == .enchantment ? visual : []
        )
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
        return String(format: "%d:%02d", twelve, parts.minute ?? 0)
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
    func trimmedForPrint() -> BoundDayBook? {
        var copy = self
        // 1. A second photograph, and long specimen lists.
        var changed = false
        for index in copy.days.indices {
            if copy.days[index].photos.count > 1 { copy.days[index].photos = Array(copy.days[index].photos.prefix(1)); changed = true }
            if copy.days[index].specimens.count > 3 { copy.days[index].specimens = Array(copy.days[index].specimens.prefix(3)); changed = true }
        }
        if changed { return copy }
        // 2. Days that held only a sentence and a few specimens.
        if copy.days.contains(where: \.isThinYourSide) {
            for index in copy.days.indices where copy.days[index].isThinYourSide {
                copy.days[index].words = []
                copy.days[index].wordSourceIDs = []
                copy.days[index].specimens = []
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
        // 4. Days with a night and no scene lose nothing but their sentence;
        //    then half the nights that held no scene, evenly spaced.
        let sceneless = copy.days.indices.filter { copy.days[$0].scenes.isEmpty && !copy.days[$0].braids.isEmpty }
        if sceneless.count > 4 {
            let keep = Set(EditionPrintFitting.evenlySpaced(sceneless, keeping: sceneless.count / 2))
            for index in sceneless where !keep.contains(index) {
                copy.days[index].braids = []
                copy.days[index].words = []
                copy.days[index].wordSourceIDs = []
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
        day.scenes.count * 3 + day.braids.count * 3 + day.keeps.count * 2 + day.photos.count * 2
            + day.clippings.count + day.castLines.count + day.radio.count + min(day.words.count, 2)
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
