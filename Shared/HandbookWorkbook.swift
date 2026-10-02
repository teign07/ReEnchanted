import Foundation

// MARK: - The Workbook
//
// Puzzles, the Examination and the Report Card. Every one of them is made out
// of this reader's own month — their words, their nights, their Cast — so a
// puzzle in one reader's book is not a puzzle in another's. Everything is
// deterministic from the seed: a reprint is the same book.

struct HandbookRandom {
    private var state: UInt64
    init(seed: String) { state = HandbookBuilder.stableHash(seed) | 1 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func int(_ bound: Int) -> Int { bound <= 1 ? 0 : Int(next() % UInt64(bound)) }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var out = items
        guard out.count > 1 else { return out }
        for index in stride(from: out.count - 1, to: 0, by: -1) { out.swapAt(index, int(index + 1)) }
        return out
    }
}

// MARK: Word search

struct HandbookWordSearch: Codable, Equatable {
    struct Placed: Codable, Equatable {
        var word: String
        var row: Int
        var col: Int
        var dRow: Int
        var dCol: Int
    }
    var size: Int
    var rows: [String]
    var words: [Placed]

    static func make(candidates: [String], seed: String, size: Int = 13, limit: Int = 10) -> HandbookWordSearch? {
        var seen = Set<String>()
        let words = candidates
            .map { $0.uppercased().filter { $0 >= "A" && $0 <= "Z" } }
            .filter { (4...min(10, size)).contains($0.count) && seen.insert($0).inserted }
            .prefix(limit)
            .sorted { $0.count > $1.count }
        guard words.count >= 5 else { return nil }
        var rng = HandbookRandom(seed: seed + "|search")
        var grid = Array(repeating: Array(repeating: Character("."), count: size), count: size)
        let directions = [(0, 1), (1, 0), (1, 1), (-1, 1), (0, -1), (1, -1)]
        var placed: [Placed] = []
        for word in words {
            let chars = Array(word)
            for _ in 0..<240 {
                let (dr, dc) = directions[rng.int(directions.count)]
                let row = rng.int(size), col = rng.int(size)
                let endRow = row + dr * (chars.count - 1), endCol = col + dc * (chars.count - 1)
                guard (0..<size).contains(endRow), (0..<size).contains(endCol) else { continue }
                var fits = true
                for i in 0..<chars.count {
                    let cell = grid[row + dr * i][col + dc * i]
                    if cell != "." && cell != chars[i] { fits = false; break }
                }
                guard fits else { continue }
                for i in 0..<chars.count { grid[row + dr * i][col + dc * i] = chars[i] }
                placed.append(Placed(word: word, row: row, col: col, dRow: dr, dCol: dc))
                break
            }
        }
        guard placed.count >= 5 else { return nil }
        let filler = Array("EEEEAAAIIOOTTNNSSRRLLDDCCUUMMPPHHGGBBFFYYWWKKVV")
        for r in 0..<size { for c in 0..<size where grid[r][c] == "." { grid[r][c] = filler[rng.int(filler.count)] } }
        return HandbookWordSearch(size: size, rows: grid.map { String($0) },
                                  words: placed.sorted { $0.word < $1.word })
    }
}

// MARK: Maze

struct HandbookMaze: Codable, Equatable {
    static let north: UInt8 = 1, east: UInt8 = 2, south: UInt8 = 4, west: UInt8 = 8
    var width: Int
    var height: Int
    /// Row-major; each cell's bits say which neighbours it is open to.
    var open: [UInt8]
    var solution: [Int]

    static func make(seed: String, width: Int = 13, height: Int = 17) -> HandbookMaze {
        var rng = HandbookRandom(seed: seed + "|maze")
        var open = Array(repeating: UInt8(0), count: width * height)
        var visited = Array(repeating: false, count: width * height)
        var stack = [0]
        visited[0] = true
        let moves: [(Int, Int, UInt8, UInt8)] = [(0, -1, north, south), (1, 0, east, west), (0, 1, south, north), (-1, 0, west, east)]
        while let current = stack.last {
            let x = current % width, y = current / width
            let options = rng.shuffled(moves).filter { move in
                let nx = x + move.0, ny = y + move.1
                return (0..<width).contains(nx) && (0..<height).contains(ny) && !visited[ny * width + nx]
            }
            guard let move = options.first else { stack.removeLast(); continue }
            let next = (y + move.1) * width + (x + move.0)
            open[current] |= move.2
            open[next] |= move.3
            visited[next] = true
            stack.append(next)
        }
        // Breadth-first from the door in to the far corner.
        let goal = width * height - 1
        var previous = Array(repeating: -1, count: width * height)
        var queue = [0], head = 0
        previous[0] = 0
        while head < queue.count {
            let cell = queue[head]; head += 1
            if cell == goal { break }
            let x = cell % width, y = cell / width
            for move in moves where open[cell] & move.2 != 0 {
                let next = (y + move.1) * width + (x + move.0)
                if previous[next] == -1 { previous[next] = cell; queue.append(next) }
            }
        }
        var path = [goal]
        while let last = path.last, last != 0, previous[last] >= 0 { path.append(previous[last]) }
        return HandbookMaze(width: width, height: height, open: open, solution: path.reversed())
    }
}

// MARK: Cipher, matching, ordering

struct HandbookCipher: Codable, Equatable {
    var plain: String
    var cipher: String
    /// Letters given away, "Q = E", so the first foothold is free.
    var hints: [String]
}

struct HandbookMatching: Codable, Equatable {
    var lines: [String]
    var speakers: [String]
    /// For each line, the index in `speakers` of who said it.
    var answer: [Int]
}

struct HandbookOrdering: Codable, Equatable {
    /// Scrambled; lettered A... on the page.
    var events: [String]
    /// For each scrambled event, where it truly fell (1 = first).
    var rank: [Int]
}

// MARK: Examination

struct HandbookExamQuestion: Codable, Equatable {
    var prompt: String
    var options: [String]
    var answer: Int
}

struct HandbookExam: Codable, Equatable {
    var questions: [HandbookExamQuestion]
    var shortAnswers: [String]
    var outOf: Int { questions.count }
}

// MARK: Report Card

struct HandbookReportCard: Codable, Equatable {
    enum Mark: String, Codable, Equatable {
        case distinction, merit, pass, resit, incomplete

        var title: String {
            switch self {
            case .distinction: return "Distinction"
            case .merit: return "Merit"
            case .pass: return "Pass"
            case .resit: return "Resit"
            case .incomplete: return "Incomplete"
            }
        }
    }

    struct Subject: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        /// What the mark is made of, in plain numbers the reader can check.
        var receipt: String
        var mark: Mark
        /// Set only on a Resit: the errand that clears it.
        var resitErrand: String?
    }

    var proctorSlug: String
    var proctorName: String
    /// A month the reader was in distress is never marked. The Academy keeps
    /// their place, and says so, and the card carries no marks at all.
    var onLeave: Bool
    var subjects: [Subject]
    var verdict: String

    static let defaultProctorSlug = "headmistress-seraphina-thorne"
    static let proctors: [String: String] = [
        "headmistress-seraphina-thorne": "Headmistress Thorne",
        "penny-blackletter": "Penny Blackletter",
        "professor-permancer": "Professor Permancer",
        "ambrose-trencher": "Ambrose Trencher",
        "wicker-eddies": "Wicker Eddies"
    ]
}

struct HandbookWorkbook: Codable, Equatable {
    var wordSearch: HandbookWordSearch?
    var maze: HandbookMaze
    var cipher: HandbookCipher?
    var matching: HandbookMatching?
    var ordering: HandbookOrdering?
    var exam: HandbookExam?
    var reportCard: HandbookReportCard?
}

// MARK: - Builder

enum HandbookWorkbookBuilder {

    static func make(
        pages: [BookPage],
        dayBook: BoundDayBook?,
        terms: [String],
        seed: String,
        dayCount: Int,
        proctorSlug: String = HandbookReportCard.defaultProctorSlug,
        onLeave: Bool = false
    ) -> HandbookWorkbook {
        let days = dayBook?.days ?? []
        let cast = dayBook?.chart.cast ?? []

        var searchWords = HandbookBuilder.normalizedTerms(terms)
        searchWords += cast.compactMap { $0.name.split(separator: " ").first.map(String.init) }
        searchWords += ["Labyrinth", "Margin", "Lantern", "Threshold", "Ember", "Hawthorn"]

        return HandbookWorkbook(
            wordSearch: HandbookWordSearch.make(candidates: searchWords, seed: seed),
            maze: HandbookMaze.make(seed: seed),
            cipher: cipher(days: days, seed: seed),
            matching: matching(days: days, seed: seed),
            ordering: ordering(days: days, seed: seed),
            exam: exam(dayBook: dayBook, seed: seed),
            reportCard: reportCard(pages: pages, dayBook: dayBook, dayCount: dayCount,
                                   proctorSlug: proctorSlug, onLeave: onLeave)
        )
    }

    // MARK: Cipher

    static func cipher(days: [BoundDay], seed: String) -> HandbookCipher? {
        let lines = days.flatMap(\.words)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { (28...110).contains($0.count) && $0.filter(\.isLetter).count >= 20 }
        guard let plain = lines.sorted(by: { HandbookBuilder.stableHash(seed + $0) < HandbookBuilder.stableHash(seed + $1) }).first else {
            return nil
        }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var rng = HandbookRandom(seed: seed + "|cipher")
        var shuffled = alphabet
        for _ in 0..<40 {
            shuffled = rng.shuffled(alphabet)
            if !zip(alphabet, shuffled).contains(where: { $0 == $1 }) { break }
        }
        let key = Dictionary(uniqueKeysWithValues: zip(alphabet, shuffled))
        let encoded = String(plain.uppercased().map { key[$0] ?? $0 })
        let counts = plain.uppercased().filter { key[$0] != nil }.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        let hints = counts.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.prefix(3)
            .compactMap { pair in key[pair.key].map { "\($0) = \(pair.key)" } }
        return HandbookCipher(plain: plain, cipher: encoded, hints: hints)
    }

    // MARK: Who said it

    static func matching(days: [BoundDay], seed: String) -> HandbookMatching? {
        var bySpeaker: [String: BoundDayCastLine] = [:]
        for line in days.flatMap(\.castLines) where (24...150).contains(line.line.count) {
            if let existing = bySpeaker[line.speakerName],
               HandbookBuilder.stableHash(seed + existing.id) <= HandbookBuilder.stableHash(seed + line.id) { continue }
            bySpeaker[line.speakerName] = line
        }
        let chosen = bySpeaker.values
            .sorted { HandbookBuilder.stableHash(seed + $0.id) < HandbookBuilder.stableHash(seed + $1.id) }
            .prefix(5)
        guard chosen.count >= 3 else { return nil }
        var rng = HandbookRandom(seed: seed + "|match")
        let speakers = rng.shuffled(chosen.map(\.speakerName))
        let lines = Array(chosen)
        return HandbookMatching(
            lines: lines.map(\.line),
            speakers: speakers,
            answer: lines.map { line in speakers.firstIndex(of: line.speakerName) ?? 0 }
        )
    }

    // MARK: Put the month in order

    static func ordering(days: [BoundDay], seed: String) -> HandbookOrdering? {
        var events: [(Date, String)] = []
        for day in days {
            if let title = day.braids.first?.title.trimmingCharacters(in: .whitespaces), (4...52).contains(title.count) {
                events.append((day.date, title))
            } else if let scene = day.scenes.first(where: { !$0.isReport }), (4...52).contains(scene.title.count) {
                events.append((day.date, scene.title))
            }
        }
        guard events.count >= 5 else { return nil }
        let picked = events.count <= 6
            ? events
            : (0..<6).map { events[$0 * (events.count - 1) / 5] }
        var rng = HandbookRandom(seed: seed + "|order")
        let scrambled = rng.shuffled(Array(picked.enumerated()))
        return HandbookOrdering(
            events: scrambled.map { $0.element.1 },
            rank: scrambled.map { $0.offset + 1 }
        )
    }

    // MARK: Examination

    private static let moonNames = [
        "New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
        "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"
    ]

    static func exam(dayBook: BoundDayBook?, seed: String) -> HandbookExam? {
        guard let book = dayBook else { return nil }
        var rng = HandbookRandom(seed: seed + "|exam")
        var questions: [HandbookExamQuestion] = []

        func make(_ prompt: String, correct: String, wrong: [String]) {
            var options = Array(Set(wrong.filter { $0 != correct })).sorted()
            options = Array(rng.shuffled(options).prefix(3))
            guard options.count >= 2 else { return }
            options.append(correct)
            options = rng.shuffled(options)
            questions.append(HandbookExamQuestion(prompt: prompt, options: options, answer: options.firstIndex(of: correct) ?? 0))
        }

        let cast = book.chart.cast
        if cast.count >= 3, let lead = cast.first {
            make("Who was in the most scenes you read this month?", correct: lead.name,
                 wrong: cast.dropFirst().prefix(5).map(\.name))
        }

        let rooms = book.chart.roomVisits.sorted { ($1.value, $0.key) < ($0.value, $1.key) }
        if rooms.count >= 3, let top = rooms.first,
           let name = AcademyGeography.room(id: top.key)?.mapLabel {
            make("Which room did the month's story visit most?", correct: name,
                 wrong: rooms.dropFirst().prefix(5).compactMap { AcademyGeography.room(id: $0.key)?.mapLabel })
        }

        if let day = book.days.first(where: { !$0.braids.isEmpty }), moonNames.contains(day.almanac.moonName) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            make("What was the moon doing on \(formatter.string(from: day.date))?", correct: day.almanac.moonName, wrong: moonNames)
        }

        let braided = book.braidCount
        if braided >= 2 {
            let wrong = [braided + 1, braided + 3, max(0, braided - 2), braided + 6, max(0, braided - 4)].map(String.init)
            make("How many nights did the Book braid for you?", correct: String(braided), wrong: wrong)
        }

        let scenes = book.scenes.filter { !$0.isReport }.sorted { $0.readAt < $1.readAt }
        if scenes.count >= 3, let first = scenes.first {
            make("Which scene did you read first?", correct: first.title,
                 wrong: scenes.dropFirst().prefix(6).map(\.title))
        }

        guard questions.count >= 3 else { return nil }
        return HandbookExam(
            questions: questions,
            shortAnswers: [
                "Name one thing you noticed this month that never made it into the Book.",
                "What did you walk past that you now suspect was a door?"
            ]
        )
    }

    // MARK: Report card

    private struct Subject {
        var id: String
        var name: String
        var unit: String
        var target: Double
        var errand: String
        var count: Int
    }

    static func reportCard(
        pages: [BookPage],
        dayBook: BoundDayBook?,
        dayCount: Int,
        proctorSlug: String,
        onLeave: Bool
    ) -> HandbookReportCard {
        let proctor = HandbookReportCard.proctors[proctorSlug] != nil ? proctorSlug : HandbookReportCard.defaultProctorSlug
        let proctorName = HandbookReportCard.proctors[proctor] ?? "Headmistress Thorne"
        if onLeave {
            return HandbookReportCard(
                proctorSlug: proctor, proctorName: proctorName, onLeave: true, subjects: [],
                verdict: "On leave. The Academy has kept your place."
            )
        }

        let days = dayBook?.days ?? []
        let keeps = days.flatMap(\.keeps)
        let braids = days.reduce(0) { $0 + $1.braids.count }
        let photos = days.reduce(0) { $0 + $1.photos.count } + keeps.filter { $0.kind == .plate }.count
        let made = keeps.filter { [.enchantment, .story, .letter].contains($0.kind) }.count
        let sat = keeps.filter { [.classSession, .club].contains($0.kind) }.count
        let creatures = Set(pages.flatMap { $0.creatureSightings ?? [] }.map(\.creature)).count
        let deeds = pages.filter { [.pactErrand, .wickerDare].contains($0.type) || $0.livedQuestReceipt != nil }.count

        let scale = max(0.4, min(3.0, Double(max(dayCount, 1)) / 30.0))
        let subjects = [
            Subject(id: "noticing", name: "Noticing", unit: "nights braided", target: 18 * scale,
                    errand: "Keep three nights before the next volume closes, and make each one hold a detail only you would have caught.",
                    count: braids),
            Subject(id: "initiative", name: "Initiative", unit: "things made or cast", target: 8 * scale,
                    errand: "Cast one enchantment on something ordinary, and write the answer down before you decide whether it counts.",
                    count: made),
            Subject(id: "fieldwork", name: "Fieldwork", unit: "photographs and creatures filed", target: 8 * scale,
                    errand: "Go somewhere you don't usually go and bring back one photograph of something you can't name.",
                    count: photos + creatures),
            Subject(id: "curiosity", name: "Curiosity", unit: "rooms sat", target: 5 * scale,
                    errand: "Sit one class you haven't sat, and bring the worksheet back filled in.",
                    count: sat),
            Subject(id: "deeds", name: "Deeds", unit: "errands and dares answered", target: 3 * scale,
                    errand: "Answer one errand the Academy sets. Small is fine. Unfinished is not an answer.",
                    count: deeds)
        ]

        let marked = subjects.map { subject -> HandbookReportCard.Subject in
            let mark = Self.mark(count: subject.count, target: subject.target)
            return HandbookReportCard.Subject(
                id: subject.id, name: subject.name,
                receipt: "\(subject.count) \(subject.unit)",
                mark: mark,
                resitErrand: mark == .resit ? subject.errand : nil
            )
        }
        return HandbookReportCard(
            proctorSlug: proctor, proctorName: proctorName, onLeave: false,
            subjects: marked, verdict: verdict(for: marked, proctorName: proctorName)
        )
    }

    /// Absence is Incomplete and never a penalty; a Resit means the reader was
    /// here and fell short of a quarter of the mark.
    static func mark(count: Int, target: Double) -> HandbookReportCard.Mark {
        guard count > 0 else { return .incomplete }
        let ratio = Double(count) / max(target, 1)
        if ratio >= 1.0 { return .distinction }
        if ratio >= 0.6 { return .merit }
        if ratio >= 0.25 { return .pass }
        return .resit
    }

    static func verdict(for subjects: [HandbookReportCard.Subject], proctorName: String) -> String {
        let counts = Dictionary(grouping: subjects, by: \.mark).mapValues(\.count)
        let distinctions = counts[.distinction] ?? 0
        let resits = counts[.resit] ?? 0
        let incomplete = counts[.incomplete] ?? 0
        if incomplete == subjects.count {
            return "Nothing was entered. Incomplete isn't a mark against you; it's a seat that was kept."
        }
        if distinctions >= 3 {
            return "The Academy doesn't hand these out. It has noted that you earned them."
        }
        if resits > 0 {
            return "A Resit isn't a failure. It's the Academy saying it can see you were there, and wants more of it."
        }
        if incomplete > 0 {
            return "What you entered is marked. What you didn't is simply open."
        }
        return "A good month. The Academy has written that down, and means it."
    }
}
