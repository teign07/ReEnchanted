import Foundation

// MARK: - Keepsakes
//
// What a month's book gives back that the reader did not know to ask for. Every piece is made from the
// reader's own month (their sentences, the days they kept, the words they kept coming back to) and is
// deterministic from the seed, so a reprint is the same book. Nothing here draws.
//
//   Month in pixels   every day coloured by how much was kept, and a blank grid to colour next month
//   Found poem        the month's own sentences, in order, set as a poem
//   Passport          a stamp for every day kept
//   Bookmarks         three, cut from one leaf, each with a line of the reader's own
//   Questions         for someone they love, two of them from the reader's own words
//   Eight words       a story to write from the words the month kept returning to
//   Time capsule      a letter to this month, next year

struct HandbookKeepsakes: Codable, Equatable {
    var pixels: Pixels?
    var photos: Photos?
    var superlatives: Superlatives?
    var poem: Poem?
    var index: Index?
    var passport: Passport?
    var cutouts: Cutouts?
    var questions: Questions?
    var eightWords: EightWords?
    var capsule: Capsule?

    // MARK: Pieces

    struct Pixels: Codable, Equatable {
        var monthName: String
        var year: Int
        /// Blank cells before the 1st so the grid lines up with the weekdays.
        var leadingBlanks: Int
        /// 0 (nothing kept) to 4 (a full day), one per day of the month.
        var levels: [Int]
        /// How much of the moon was lit each day, 0...1.
        var moon: [Double]
        var keptDays: Int
        var longestRun: Int
        /// The day of the month with the most kept, and how much that was.
        var busiestDay: Int?
        var busiestCount: Int
        var weekdayLetters: [String]
    }

    /// Everything the reader photographed this month, with the one the Book would frame.
    struct Photos: Codable, Equatable {
        struct Shot: Codable, Equatable {
            var dateLabel: String
            var title: String
            var assets: [BookPageMediaAsset]
            var weight: Int
        }
        var monthName: String
        var shots: [Shot]
        var featuredIndex: Int
    }

    /// Yearbook awards, each from the reader's own month. Only the ones the month earned are printed.
    struct Superlatives: Codable, Equatable {
        struct Award: Codable, Equatable {
            var title: String
            var headline: String
            var detail: String
        }
        var monthName: String
        var awards: [Award]
    }

    struct Poem: Codable, Equatable {
        struct Line: Codable, Equatable {
            var text: String
            var dateLabel: String
        }
        var title: String
        var stanzas: [[Line]]
    }

    /// A real book's index, of this month: the words that kept coming back and the days they came up,
    /// the Cast who appeared, and the rooms of the Labyrinth that were visited.
    struct Index: Codable, Equatable {
        struct Entry: Codable, Equatable {
            var term: String
            /// "3, 9, 14" or "5 visits": already set as it will be printed.
            var locator: String
        }
        var monthName: String
        var words: [Entry]
        var cast: [Entry]
        var rooms: [Entry]
    }

    struct Passport: Codable, Equatable {
        var monthName: String
        var year: Int
        var daysInMonth: Int
        /// Days of the month (1-based) that earn a stamp.
        var keptDays: [Int]
    }

    struct Cutouts: Codable, Equatable {
        struct Bookmark: Codable, Equatable {
            var line: String
            var moonName: String
            var moonLit: Double
        }
        var monthName: String
        var bookmarks: [Bookmark]
    }

    struct Questions: Codable, Equatable {
        var items: [String]
    }

    struct EightWords: Codable, Equatable {
        var words: [String]
        var frame: String
    }

    struct Capsule: Codable, Equatable {
        var monthName: String
        var openYear: Int
        var prompts: [String]
    }

    var isEmpty: Bool {
        pixels == nil && photos == nil && superlatives == nil && poem == nil && index == nil && passport == nil && cutouts == nil
            && questions == nil && eightWords == nil && capsule == nil
    }

    /// The extras go first when a book must be thinner: a time capsule, questions, a story frame,
    /// bookmarks and the poem. None of them is the month itself.
    mutating func removeExtra() -> Bool {
        if capsule != nil { capsule = nil; return true }
        if questions != nil { questions = nil; return true }
        if index != nil { index = nil; return true }
        if eightWords != nil { eightWords = nil; return true }
        if cutouts != nil { cutouts = nil; return true }
        if poem != nil { poem = nil; return true }
        return false
    }

    /// The month at a glance (the passport, superlatives, photographs and pixels) is small, wholly the
    /// reader's, and is given up only when nothing else can be.
    mutating func removeCore() -> Bool {
        if passport != nil { passport = nil; return true }
        if superlatives != nil { superlatives = nil; return true }
        if photos != nil { photos = nil; return true }
        if pixels != nil { pixels = nil; return true }
        return false
    }

    /// One piece given up, the most expendable first.
    mutating func removeOne() -> Bool { removeExtra() || removeCore() }
}

// MARK: - Builder

enum HandbookKeepsakesBuilder {
    private static func hash(_ seed: String, _ text: String) -> UInt64 { HandbookBuilder.stableHash(seed + text) }

    static func make(days: [BoundDay], pages: [BookPage], seed: String, calendar: Calendar, chart: LabyrinthMonthChart? = nil) -> HandbookKeepsakes? {
        guard let first = days.map(\.date).min() else { return nil }
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: first)) ?? first
        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.timeZone = calendar.timeZone
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "LLLL"
        let monthName = monthFormatter.string(from: monthStart)
        let year = calendar.component(.year, from: monthStart)

        let lines = poemCandidates(days: days, calendar: calendar)
        let built = HandbookKeepsakes(
            pixels: pixels(days: days, monthStart: monthStart, monthName: monthName, year: year, calendar: calendar),
            photos: photos(days: days, monthName: monthName, calendar: calendar),
            superlatives: superlatives(days: days, pages: pages, monthName: monthName, calendar: calendar),
            poem: poem(lines: lines, pages: pages, monthName: monthName, seed: seed),
            index: index(days: days, pages: pages, monthName: monthName, calendar: calendar, chart: chart),
            passport: passport(days: days, monthStart: monthStart, monthName: monthName, year: year, calendar: calendar),
            cutouts: cutouts(lines: lines, days: days, monthName: monthName, seed: seed),
            questions: questions(pages: pages, seed: seed),
            eightWords: eightWords(pages: pages, seed: seed),
            capsule: capsule(monthName: monthName, year: year, seed: seed)
        )
        return built.isEmpty ? nil : built
    }

    // MARK: Pixels and passport

    /// How much a day holds of the reader's own: nights braided, photographs, typed keeps, their words.
    static func weight(of day: BoundDay) -> Int {
        day.braids.count + day.photos.count + day.keeps.count + min(2, day.words.count)
    }

    static func level(forWeight weight: Int) -> Int {
        switch weight {
        case ...0: return 0
        case 1: return 1
        case 2: return 2
        case 3...4: return 3
        default: return 4
        }
    }

    private static func dayOfMonth(_ date: Date, calendar: Calendar) -> Int { calendar.component(.day, from: date) }

    static func pixels(days: [BoundDay], monthStart: Date, monthName: String, year: Int, calendar: Calendar) -> HandbookKeepsakes.Pixels? {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let total = range.count
        var weights = Array(repeating: 0, count: total)
        for day in days {
            let index = dayOfMonth(day.date, calendar: calendar) - 1
            guard (0..<total).contains(index), calendar.isDate(day.date, equalTo: monthStart, toGranularity: .month) else { continue }
            weights[index] = max(weights[index], weight(of: day))
        }
        let levels = weights.map(level(forWeight:))
        guard levels.contains(where: { $0 > 0 }) else { return nil }
        let moon = (0..<total).map { index -> Double in
            let date = calendar.date(byAdding: .day, value: index, to: monthStart) ?? monthStart
            return MoonPhaseCalendar.phase(on: calendar.date(byAdding: .hour, value: 12, to: date) ?? date).illuminatedFraction
        }
        var run = 0, longest = 0
        for level in levels { run = level > 0 ? run + 1 : 0; longest = max(longest, run) }
        let busiest = weights.enumerated().max { ($0.element, -$0.offset) < ($1.element, -$1.offset) }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let letters = (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
        return HandbookKeepsakes.Pixels(
            monthName: monthName, year: year, leadingBlanks: leading, levels: levels, moon: moon,
            keptDays: levels.filter { $0 > 0 }.count, longestRun: longest,
            busiestDay: (busiest?.element ?? 0) > 0 ? (busiest?.offset ?? 0) + 1 : nil,
            busiestCount: busiest?.element ?? 0, weekdayLetters: letters
        )
    }

    static func passport(days: [BoundDay], monthStart: Date, monthName: String, year: Int, calendar: Calendar) -> HandbookKeepsakes.Passport? {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let kept = Set(days.filter { weight(of: $0) > 0 && calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
            .map { dayOfMonth($0.date, calendar: calendar) }).sorted()
        guard kept.count >= 2 else { return nil }
        return HandbookKeepsakes.Passport(monthName: monthName, year: year, daysInMonth: range.count, keptDays: kept)
    }

    // MARK: Index

    /// Ordinary words only: a person's name is never an index entry.
    static func index(days: [BoundDay], pages: [BookPage], monthName: String, calendar: Calendar, chart: LabyrinthMonthChart? = nil) -> HandbookKeepsakes.Index? {
        let dated: [(day: Int, words: Set<String>)] = pages
            .filter { $0.carriesReaderAttention && $0.type != .bookOfYou && $0.type != .theBleed }
            .compactMap { page in
                guard let text = page.readerAuthoredTextForAnalysis, !text.isEmpty else { return nil }
                return (calendar.component(.day, from: page.createdAt),
                        Set(LiteraryContinuityProjector.meaningfulWords(in: text).map { $0.lowercased() }))
            }
        // A word the reader never wrote in lowercase is more likely a name than a word (a name at the
        // start of a sentence looks like any other word), so it is not an entry.
        let lowercaseWritten = Set(pages.flatMap { page -> [String] in
            guard let text = page.readerAuthoredTextForAnalysis else { return [] }
            return text.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.first?.isLowercase == true }
        })
        let stems: Set<String> = ["didn", "doesn", "wasn", "couldn", "wouldn", "shouldn", "isn", "aren", "hadn", "hasn", "haven", "weren", "else", "wrote"]
        let terms = WeeklyCuration.refrain(from: pages, limit: 60, minPages: 2)
            .filter { $0.first?.isLowercase == true && lowercaseWritten.contains($0) && !stems.contains($0) }
        var words: [HandbookKeepsakes.Index.Entry] = []
        for term in terms {
            let daysSeen = Set(dated.filter { $0.words.contains(term) }.map(\.day)).sorted()
            guard daysSeen.count >= 2 else { continue }
            let shown = daysSeen.prefix(7).map(String.init).joined(separator: ", ") + (daysSeen.count > 7 ? "…" : "")
            words.append(.init(term: term, locator: shown))
        }
        words.sort { $0.term < $1.term }
        guard words.count >= 8 else { return nil }

        // The Cast who spoke, by the days they spoke on.
        var castDays: [String: Set<Int>] = [:]
        for day in days { for line in day.castLines { castDays[line.speakerName, default: []].insert(calendar.component(.day, from: day.date)) } }
        let cast = castDays.filter { $0.value.count >= 1 }
            .map { HandbookKeepsakes.Index.Entry(term: $0.key, locator: $0.value.sorted().prefix(7).map(String.init).joined(separator: ", ")) }
            .sorted { $0.term < $1.term }
            .prefix(10)

        var rooms: [HandbookKeepsakes.Index.Entry] = []
        for (id, count) in chart?.roomVisits ?? [:] {
            guard let label = AcademyGeography.room(id: id)?.mapLabel else { continue }
            let noun = count == 1 ? "visit" : "visits"
            rooms.append(HandbookKeepsakes.Index.Entry(term: label, locator: "\(count) \(noun)"))
        }
        rooms.sort { $0.term < $1.term }
        rooms = Array(rooms.prefix(8))

        return HandbookKeepsakes.Index(monthName: monthName, words: Array(words.prefix(34)), cast: Array(cast), rooms: rooms)
    }

    // MARK: Photographs

    static func photos(days: [BoundDay], monthName: String, calendar: Calendar) -> HandbookKeepsakes.Photos? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        var shots: [HandbookKeepsakes.Photos.Shot] = []
        var seen = Set<String>()
        for day in days.sorted(by: { $0.date < $1.date }) {
            for item in day.photos {
                // A photograph whose file has gone is left out; the rest are still the month.
                let assets = BookPageMediaAsset.displayable(item.mediaAssets, limit: 1)
                    .filter { seen.insert($0.reference).inserted }
                guard !assets.isEmpty else { continue }
                let raw = (day.braids.first?.title ?? item.title).trimmingCharacters(in: .whitespacesAndNewlines)
                let title = raw.count > 38 ? String(raw.prefix(37)).trimmingCharacters(in: .whitespaces) + "…" : raw
                shots.append(.init(dateLabel: formatter.string(from: day.date), title: title, assets: assets, weight: weight(of: day)))
            }
        }
        guard shots.count >= 3 else { return nil }
        let kept = Array(shots.prefix(21))
        let featured = kept.enumerated().max { ($0.element.weight, -$0.offset) < ($1.element.weight, -$1.offset) }?.offset ?? 0
        return HandbookKeepsakes.Photos(monthName: monthName, shots: kept, featuredIndex: featured)
    }

    // MARK: Superlatives

    /// The longest run of days between the first and last kept day with nothing kept.
    static func longestQuiet(days: [BoundDay], calendar: Calendar) -> (length: Int, start: Date, end: Date)? {
        let ordered = days.sorted { $0.date < $1.date }
        guard let first = ordered.first?.date, let last = ordered.last?.date else { return nil }
        let kept = Set(ordered.filter { weight(of: $0) > 0 }.map { calendar.startOfDay(for: $0.date) })
        var run = 0, best = 0
        var bestEnd: Date?
        var cursor = calendar.startOfDay(for: first)
        while cursor <= last {
            if kept.contains(cursor) { run = 0 } else { run += 1; if run > best { best = run; bestEnd = cursor } }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        guard best > 0, let end = bestEnd, let start = calendar.date(byAdding: .day, value: -(best - 1), to: end) else { return nil }
        return (best, start, end)
    }

    static func superlatives(days: [BoundDay], pages: [BookPage], monthName: String, calendar: Calendar) -> HandbookKeepsakes.Superlatives? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        var awards: [HandbookKeepsakes.Superlatives.Award] = []
        let ordered = days.sorted { $0.date < $1.date }

        // The hour the reader writes.
        let hours = pages.filter { $0.carriesReaderAttention && $0.type != .bookOfYou && $0.type != .theBleed && ($0.readerAuthoredTextForAnalysis?.isEmpty == false) }
            .map { calendar.component(.hour, from: $0.createdAt) }
        if hours.count >= 8 {
            let tally = Dictionary(grouping: hours, by: { $0 }).mapValues(\.count)
            if let top = tally.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) }), top.value >= 3 {
                let twelve = top.key % 12 == 0 ? 12 : top.key % 12
                awards.append(.init(title: "Most Likely to Be Found Writing at", headline: "\(twelve) \(top.key < 12 ? "a.m." : "p.m.")",
                                    detail: "\(top.value) of your \(hours.count) pages were written in that hour."))
            }
        }

        // The word of the month.
        // An ordinary word, never a person's name: a name is a person, and this is an award.
        if let word = WeeklyCuration.refrain(from: pages, limit: 6).first(where: { $0.first?.isLowercase == true }) {
            let count = pages.filter { page in
                guard page.carriesReaderAttention, let text = page.readerAuthoredTextForAnalysis else { return false }
                return LiteraryContinuityProjector.meaningfulWords(in: text).contains { $0.lowercased() == word.lowercased() }
            }.count
            awards.append(.init(title: "Word of the Month", headline: word.prefix(1).uppercased() + word.dropFirst(),
                                detail: "It came up on \(count) different pages."))
        }

        // The longest and shortest sentences.
        let sentences = ordered.flatMap { day in
            day.words.map { (day.date, WeeklyCuration.cleaned($0).replacingOccurrences(of: "\n", with: " ")) }
        }.filter { $0.1.count >= 12 && !$0.1.lowercased().contains("http") }
        if sentences.count >= 5 {
            if let longest = sentences.max(by: { $0.1.count < $1.1.count }), longest.1.count >= 60 {
                awards.append(.init(title: "The Long Sentence", headline: "\(longest.1.split(separator: " ").count) words",
                                    detail: "Said on \(formatter.string(from: longest.0)): “\(WeeklyCuration.sentenceClamp(longest.1, limit: 90))”"))
            }
            if let shortest = sentences.min(by: { $0.1.count < $1.1.count }), shortest.1.count <= 40 {
                awards.append(.init(title: "The Short One", headline: "“\(shortest.1)”", detail: "Said on \(formatter.string(from: shortest.0)). Sometimes that is all it takes."))
            }
        }

        // Busiest day and most photographed day.
        if let busiest = ordered.max(by: { (weight(of: $0), $1.date) < (weight(of: $1), $0.date) }), weight(of: busiest) >= 3 {
            awards.append(.init(title: "Busiest Day", headline: formatter.string(from: busiest.date), detail: "You kept \(weight(of: busiest)) things that day."))
        }
        if let shot = ordered.max(by: { ($0.photos.count, $1.date) < ($1.photos.count, $0.date) }), shot.photos.count >= 2 {
            awards.append(.init(title: "Most Photographed Day", headline: formatter.string(from: shot.date), detail: "\(shot.photos.count) photographs."))
        }

        // The longest quiet, said kindly.
        if let quiet = longestQuiet(days: ordered, calendar: calendar), quiet.length >= 3 {
            awards.append(.init(title: "The Longest Quiet", headline: "\(quiet.length) days",
                                detail: "\(formatter.string(from: quiet.start)) to \(formatter.string(from: quiet.end)). The Book kept the lamp lit."))
        }

        // The moon you kept most under.
        let moonTally = Dictionary(grouping: ordered.filter { weight(of: $0) > 0 }, by: { $0.almanac.moonName }).mapValues(\.count)
        if let moon = moonTally.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), moon.value >= 3, !moon.key.isEmpty {
            awards.append(.init(title: "Kept Most Under the", headline: moon.key, detail: "\(moon.value) of your days."))
        }

        guard awards.count >= 4 else { return nil }
        return HandbookKeepsakes.Superlatives(monthName: monthName, awards: Array(awards.prefix(8)))
    }

    // MARK: The reader's own lines

    struct OwnLine: Equatable {
        var date: Date
        var text: String
        var label: String
    }

    /// One short, whole sentence of the reader's own from each day that has one.
    static func poemCandidates(days: [BoundDay], calendar: Calendar) -> [OwnLine] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        var out: [OwnLine] = []
        var seen = Set<String>()
        for day in days.sorted(by: { $0.date < $1.date }) {
            let usable = day.words.compactMap { raw -> String? in
                let line = WeeklyCuration.cleaned(raw)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let count = line.split(separator: " ").count
                guard (4...14).contains(count), (24...78).contains(line.count),
                      !line.lowercased().contains("http"), line.filter(\.isNumber).count <= 4,
                      line.first?.isLetter == true else { return nil }
                return line
            }
            // A sentence said twice is a poem line once.
            guard let best = usable.filter({ !seen.contains($0.lowercased()) }).min(by: { abs($0.count - 48) < abs($1.count - 48) }) else { continue }
            seen.insert(best.lowercased())
            out.append(OwnLine(date: day.date, text: best, label: formatter.string(from: day.date)))
        }
        return out
    }

    // MARK: Found poem

    static func poem(lines: [OwnLine], pages: [BookPage], monthName: String, seed: String) -> HandbookKeepsakes.Poem? {
        guard lines.count >= 6 else { return nil }
        let chosen = EditionPrintFitting.evenlySpaced(lines, keeping: min(12, lines.count))
        let size: Int
        switch chosen.count {
        case 12, 9, 6: size = 3
        case 8, 4: size = 4
        default: size = 3
        }
        var stanzas: [[HandbookKeepsakes.Poem.Line]] = []
        var index = 0
        while index < chosen.count {
            let remaining = chosen.count - index
            let take = remaining < size + 2 ? remaining : size
            stanzas.append(chosen[index..<(index + take)].map { .init(text: $0.text, dateLabel: $0.label) })
            index += take
        }
        let refrain = WeeklyCuration.refrain(from: pages, limit: 2).map { $0.prefix(1).uppercased() + $0.dropFirst() }
        let title: String
        switch refrain.count {
        case 2...: title = "On \(refrain[0]) and \(refrain[1])"
        case 1: title = "On \(refrain[0])"
        default: title = "\(monthName), Said Plainly"
        }
        return HandbookKeepsakes.Poem(title: title, stanzas: stanzas)
    }

    // MARK: Cut-outs

    /// Three bookmarks: the leaf is the only thing in the book meant for scissors, and cutting it
    /// costs nothing because both of its faces are the bookmarks themselves.
    static func cutouts(lines: [OwnLine], days: [BoundDay], monthName: String, seed: String) -> HandbookKeepsakes.Cutouts? {
        guard lines.count >= 3 else { return nil }
        // The best lines for a bookmark are short enough to read at a glance.
        let ranked = lines.sorted { left, right in
            let l = abs(left.text.count - 38), r = abs(right.text.count - 38)
            return l == r ? hash(seed + "|bm", left.text) < hash(seed + "|bm", right.text) : l < r
        }
        let ordered = days.sorted { $0.date < $1.date }
        let moons = [ordered.first, ordered.dropFirst(ordered.count / 2).first, ordered.last].compactMap { $0?.almanac }
        let bookmarks = ranked.prefix(3).enumerated().map { offset, line in
            HandbookKeepsakes.Cutouts.Bookmark(
                line: line.text,
                moonName: moons.indices.contains(offset) ? moons[offset].moonName : "Full Moon",
                moonLit: moons.indices.contains(offset) ? moons[offset].moonIlluminated : 1
            )
        }
        return HandbookKeepsakes.Cutouts(monthName: monthName, bookmarks: Array(bookmarks))
    }

    // MARK: Questions, eight words, capsule

    static let questionBank = [
        "What is the best thing that happened to you this year that you never told anyone?",
        "What did you want to be when you were small, and what did you think it would feel like?",
        "What is a smell that takes you straight back somewhere?",
        "What is a rule in your family that nobody ever wrote down?",
        "What would you do with an extra hour every day, if you could not spend it on work?",
        "Who taught you to do something that you still do their way?",
        "What is the best meal you have ever eaten, and who was across the table?",
        "What do you hope people say about you after you leave the room?",
        "What are you better at than you let on?",
        "What was the last thing that made you laugh until it hurt?",
        "What is a place you would go back to, and what time of day would it be?",
        "What did you believe at ten that you still half believe?",
        "Which song do you know every word of, and why?",
        "What small thing did someone do for you that you still think about?",
        "What do you do when you cannot sleep?",
        "If this week had a colour, what would it be?",
        "What were you afraid of that turned out fine?",
        "What do you wish you had asked someone while you still could?",
        "What was the hardest part of this month, and what was the easiest?",
        "Where does your mind go when you are bored?",
        "What is the kindest thing a stranger ever did for you?",
        "What have you been meaning to say to someone?",
        "What would a perfectly ordinary Tuesday look like, if you designed it?",
        "What is the oldest thing you own, and where did it come from?"
    ]

    /// Words that are not names: a name is a person, and these questions are for asking, not for
    /// putting words in a real person's mouth.
    private static func plainWords(from pages: [BookPage], limit: Int, minPages: Int, seed: String) -> [String] {
        WeeklyCuration.refrain(from: pages, limit: limit * 3, minPages: minPages, seed: seed)
            .filter { $0.first?.isLowercase == true }
            .prefix(limit)
            .map { String($0) }
    }

    static func questions(pages: [BookPage], seed: String) -> HandbookKeepsakes.Questions? {
        let generic = questionBank
            .sorted { hash(seed + "|q", $0) < hash(seed + "|q", $1) }
            .prefix(6)
        var items = Array(generic)
        let words = plainWords(from: pages, limit: 2, minPages: 2, seed: seed)
        if let word = words.first {
            items.insert("You wrote about \(word) more than once this month. What does \(word) mean to someone you love?", at: 1)
        }
        if words.count > 1 {
            items.insert("Ask someone about their \(words[1]). Write down what surprised you.", at: 4)
        }
        return HandbookKeepsakes.Questions(items: Array(items.prefix(8)))
    }

    static func eightWords(pages: [BookPage], seed: String) -> HandbookKeepsakes.EightWords? {
        var words = plainWords(from: pages, limit: 8, minPages: 2, seed: seed)
        if words.count < 8 {
            let more = plainWords(from: pages, limit: 12, minPages: 1, seed: seed + "|fill").filter { !words.contains($0) }
            words += more.prefix(8 - words.count)
        }
        guard words.count >= 6 else { return nil }
        return HandbookKeepsakes.EightWords(
            words: Array(words.prefix(8)),
            frame: "These are the words your month kept returning to. Write the story of the month using every one of them. It is allowed to be a lie, if it is a good one."
        )
    }

    static func capsule(monthName: String, year: Int, seed: String) -> HandbookKeepsakes.Capsule? {
        let all = [
            "Three things you hope are true by then.",
            "Something you are worried about that you suspect will not matter.",
            "What you would like to be doing on this very day next year.",
            "A question you want to ask the person you will be.",
            "One thing you are proud of this month, written down in case you forget.",
            "Something you are sure of now, in case you change your mind."
        ]
        let prompts = all.sorted { hash(seed + "|cap", $0) < hash(seed + "|cap", $1) }.prefix(3)
        return HandbookKeepsakes.Capsule(monthName: monthName, openYear: year + 1, prompts: Array(prompts))
    }
}

// MARK: - The back cover

/// What a custom book says on its back: a blurb in the Book's own voice, and what is inside, counted.
/// Only counts and the month's own title go on the outside of a book. The reader's sentences stay
/// inside it, because a shelf is a public place.
enum BackCoverCopy {
    struct Copy: Equatable {
        var blurb: String
        var contains: [String]
        var onlyCopy: String
    }

    static func make(
        readerName: String, monthName: String, keptPages: Int, nights: Int, scenes: Int, photos: Int,
        hasIndex: Bool, seed: String
    ) -> Copy {
        let name = readerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "you" : name
        let nightWord = nights == 1 ? "night" : "nights"
        let templates: [String] = [
            "\(monthName) came and went, and I kept it. \(nights > 0 ? "\(nights) \(nightWord) of it, to be exact, " : "")set down in the order they happened to \(who).",
            "I kept \(keptPages) of \(who)'s pages this month, and I'd have kept more. Here they are, in the order the days came.",
            "Everything in here happened in \(monthName), and I was there for \(scenes > 0 ? "the Labyrinth's half of it and " : "")as much of \(who)'s half as \(who) let me see."
        ]
        let blurb = templates[Int(HandbookBuilder.stableHash(seed + "|blurb") % UInt64(templates.count))]

        var contains: [String] = ["\(keptPages) kept \(keptPages == 1 ? "page" : "pages")"]
        if nights > 0 { contains.append("\(nights) braided \(nightWord)") }
        if scenes > 0 { contains.append("\(scenes) \(scenes == 1 ? "scene" : "scenes") from the Labyrinth") }
        if photos > 0 { contains.append("\(photos) \(photos == 1 ? "photograph" : "photographs")") }
        if hasIndex { contains.append("an index of the month") }
        return Copy(blurb: blurb, contains: contains, onlyCopy: "There is only one of this book. I made it for \(who).")
    }
}
