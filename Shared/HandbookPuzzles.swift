import Foundation

// MARK: - More puzzles
//
// Five more kinds for the Workbook, so one week's puzzles are not the next week's:
// the Missing Words, the Scrambled Cast, Vowels Fled, the Chairs (a small sudoku) and
// the Odd One Out. Each is made of what this reader's days actually held, or, for the
// Chairs, of nothing but the seed. Nothing here draws; the same seed is the same book.

struct HandbookCloze: Codable, Equatable {
    /// Each sentence is the reader's own, with `blank` where a word was lifted out.
    var sentences: [String]
    /// The lifted words plus a couple of decoys, shuffled.
    var bank: [String]
    /// The lifted words in reading order.
    var answers: [String]
    static let blank = "_______"
}

struct HandbookAnagrams: Codable, Equatable {
    struct Item: Codable, Equatable {
        var scrambled: String
        var answer: String
        var clue: String
    }
    var items: [Item]
}

struct HandbookVowels: Codable, Equatable {
    struct Item: Codable, Equatable {
        var stripped: String
        var answer: String
        var clue: String
    }
    var items: [Item]
}

struct HandbookSudoku: Codable, Equatable {
    var size: Int
    var boxRows: Int
    var boxCols: Int
    var symbols: [String]
    /// Row-major; -1 is an empty square, otherwise an index into `symbols`.
    var given: [Int]
    var solution: [Int]
}

struct HandbookOddOne: Codable, Equatable {
    struct Round: Codable, Equatable {
        var options: [String]
        var answer: Int
        var reason: String
    }
    var rounds: [Round]
}

extension HandbookWorkbook {
    enum PuzzleKind: String, CaseIterable {
        case cipher, matching, ordering, cloze, anagrams, vowels, sudoku, oddOne

        /// The lighter kinds can stand in a thin week; matching and ordering need a fuller one.
        var needsFullWeek: Bool { self == .matching || self == .ordering }
    }

    var presentKinds: [PuzzleKind] {
        PuzzleKind.allCases.filter { has($0) }
    }

    func has(_ kind: PuzzleKind) -> Bool {
        switch kind {
        case .cipher: return cipher != nil
        case .matching: return matching != nil
        case .ordering: return ordering != nil
        case .cloze: return cloze != nil
        case .anagrams: return anagrams != nil
        case .vowels: return vowels != nil
        case .sudoku: return sudoku != nil
        case .oddOne: return oddOne != nil
        }
    }

    mutating func remove(_ kind: PuzzleKind) {
        switch kind {
        case .cipher: cipher = nil
        case .matching: matching = nil
        case .ordering: ordering = nil
        case .cloze: cloze = nil
        case .anagrams: anagrams = nil
        case .vowels: vowels = nil
        case .sudoku: sudoku = nil
        case .oddOne: oddOne = nil
        }
    }

    /// Keeps `keep` of the kinds this reader has material for, chosen by the seed, so each
    /// issue gets its own mix. `allowed` lets a thin week leave out the heavier kinds first.
    mutating func rotate(seed: String, keep: Int, allowed: (PuzzleKind) -> Bool = { _ in true }) {
        for kind in PuzzleKind.allCases where has(kind) && !allowed(kind) { remove(kind) }
        let present = presentKinds
        guard present.count > keep else { return }
        var rng = HandbookRandom(seed: seed + "|rotate")
        let kept = Set(rng.shuffled(present).prefix(keep))
        for kind in present where !kept.contains(kind) { remove(kind) }
    }
}

extension HandbookWorkbookBuilder {

    private static func letters(_ text: String) -> String { text.filter(\.isLetter) }

    private static func hash(_ seed: String, _ text: String) -> UInt64 { HandbookBuilder.stableHash(seed + text) }

    private static func roomLabels(_ chart: LabyrinthMonthChart?) -> [String] {
        guard let visits = chart?.roomVisits else { return [] }
        return visits.sorted { ($1.value, $0.key) < ($0.value, $1.key) }
            .compactMap { AcademyGeography.room(id: $0.key)?.mapLabel }
    }

    // MARK: Missing words

    static func cloze(days: [BoundDay], seed: String) -> HandbookCloze? {
        let cipherLine = cipher(days: days, seed: seed)?.plain
        let lines = days.flatMap(\.words)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { (36...150).contains($0.count) && $0.split(separator: " ").count >= 7 && $0 != cipherLine }
            .sorted { hash(seed + "|cloze", $0) < hash(seed + "|cloze", $1) }

        func candidates(in line: String) -> [(index: Int, word: String)] {
            let tokens = line.split(separator: " ").map(String.init)
            return tokens.enumerated().compactMap { index, token in
                let word = token.trimmingCharacters(in: .punctuationCharacters)
                guard index > 0, index < tokens.count - 1, letters(word).count >= 5, word.allSatisfy({ $0.isLetter || $0 == "'" }),
                      !WeeklyCuration.isMetaWord(word) else { return nil }
                return (index, word)
            }
        }

        var sentences: [String] = []
        var answers: [String] = []
        var spare: [String] = []
        for line in lines {
            let options = candidates(in: line).sorted { hash(seed, $0.word) < hash(seed, $1.word) }
            guard let pick = options.first, !answers.map({ $0.lowercased() }).contains(pick.word.lowercased()) else { continue }
            if sentences.count < 3 {
                var tokens = line.split(separator: " ").map(String.init)
                let token = tokens[pick.index]
                let tail = token.reversed().prefix { $0.isPunctuation && $0 != "'" }.reversed()
                tokens[pick.index] = HandbookCloze.blank + String(tail)
                sentences.append(tokens.joined(separator: " "))
                answers.append(pick.word)
                spare += options.dropFirst().map(\.word)
            } else {
                spare += options.map(\.word)
            }
        }
        guard sentences.count >= 2 else { return nil }
        var seen = Set(answers.map { $0.lowercased() })
        let decoys = spare.sorted { hash(seed + "|decoy", $0) < hash(seed + "|decoy", $1) }
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(2)
        var rng = HandbookRandom(seed: seed + "|clozebank")
        return HandbookCloze(sentences: sentences, bank: rng.shuffled(answers + decoys), answers: answers)
    }

    // MARK: The scrambled cast

    static func anagrams(terms: [String], dayBook: BoundDayBook?, seed: String) -> HandbookAnagrams? {
        var rng = HandbookRandom(seed: seed + "|anagram")
        func word(_ raw: String) -> String? {
            let w = raw.uppercased().filter { $0 >= "A" && $0 <= "Z" }
            return (5...9).contains(w.count) && Set(w).count >= 4 ? w : nil
        }
        let cast = (dayBook?.chart.cast ?? []).compactMap { $0.name.split(separator: " ").first.flatMap { word(String($0)) } }
        let rooms = roomLabels(dayBook?.chart)
            .compactMap { label -> String? in label.split(separator: " ").count == 1 ? word(label) : nil }
        let own = HandbookBuilder.normalizedTerms(terms).compactMap { word($0) }
        var pools: [[(String, String)]] = [
            rng.shuffled(cast).map { ($0, "Someone from your Cast") },
            rng.shuffled(rooms).map { ($0, "A place in the Labyrinth") },
            rng.shuffled(own).map { ($0, "A word from your pages") }
        ]
        var picked: [(String, String)] = []
        var seen = Set<String>()
        while picked.count < 5, pools.contains(where: { !$0.isEmpty }) {
            for index in pools.indices where picked.count < 5 {
                guard let next = pools[index].first else { continue }
                pools[index].removeFirst()
                if seen.insert(next.0).inserted { picked.append(next) }
            }
        }
        guard picked.count >= 4 else { return nil }
        let items = picked.map { answer, clue -> HandbookAnagrams.Item in
            var scrambled = Array(answer)
            for _ in 0..<30 {
                scrambled = rng.shuffled(Array(answer))
                if String(scrambled) != answer { break }
            }
            return HandbookAnagrams.Item(scrambled: String(scrambled), answer: answer, clue: clue)
        }
        return HandbookAnagrams(items: items)
    }

    // MARK: Vowels fled

    static func vowels(dayBook: BoundDayBook?, seed: String) -> HandbookVowels? {
        guard let book = dayBook else { return nil }
        var pool: [(String, String)] = []
        for day in book.days {
            if let title = day.braids.first?.title { pool.append((title, "A night the Book braided")) }
            if let scene = day.scenes.first(where: { !$0.isReport }) { pool.append((scene.title, "A scene you read")) }
        }
        pool += roomLabels(book.chart).map { ($0, "A place in the Labyrinth") }
        pool += book.chart.cast.map { ($0.name, "Someone from your Cast") }
        var seen = Set<String>()
        let usable = pool
            .map { ($0.0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)), $0.1) }
            .filter { entry in
                let words = entry.0.split(separator: " ")
                // Every word must keep a consonant, or "A" would be left standing among the missing.
                return (7...30).contains(entry.0.count) && entry.0.filter({ "aeiouAEIOU".contains($0) }).count >= 3
                    && words.allSatisfy { $0.contains { ch in ch.isLetter && !"aeiouAEIOU".contains(ch) } }
                    && seen.insert(entry.0.lowercased()).inserted
            }
            .sorted { hash(seed + "|vowel", $0.0) < hash(seed + "|vowel", $1.0) }
            .prefix(5)
        guard usable.count >= 4 else { return nil }
        return HandbookVowels(items: usable.map { answer, clue in
            let stripped = answer.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
                let kept = word.filter { !"aeiouAEIOU".contains($0) }
                return (kept.isEmpty ? String(word) : String(kept)).uppercased()
            }.joined(separator: " ")
            return HandbookVowels.Item(stripped: stripped, answer: answer, clue: clue)
        })
    }

    // MARK: The chairs

    static func sudoku(terms: [String], dayBook: BoundDayBook?, seed: String) -> HandbookSudoku? {
        let size = 6, boxRows = 2, boxCols = 3
        var rng = HandbookRandom(seed: seed + "|sudoku")

        // Six different letters, from a word of the reader's if one has six, so the grid is theirs.
        let words = HandbookBuilder.normalizedTerms(terms) + (dayBook?.chart.cast.map(\.name) ?? [])
        var symbols = ["L", "A", "B", "Y", "R", "I"]
        for word in words.sorted(by: { hash(seed + "|sym", $0) < hash(seed + "|sym", $1) }) {
            var distinct: [String] = []
            for ch in word.uppercased() where ch >= "A" && ch <= "Z" && !distinct.contains(String(ch)) { distinct.append(String(ch)) }
            if distinct.count >= size { symbols = Array(distinct.prefix(size)); break }
        }

        // A valid grid, then shuffled in ways that keep it valid.
        func band(_ count: Int, per: Int) -> [Int] {
            var order = Array(0..<count)
            order = rng.shuffled(order)
            return order.flatMap { b in rng.shuffled(Array(0..<per)).map { b * per + $0 } }
        }
        let rowOrder = band(size / boxRows, per: boxRows)
        let colOrder = band(size / boxCols, per: boxCols)
        let symbolOrder = rng.shuffled(Array(0..<size))
        var solution = Array(repeating: 0, count: size * size)
        for r in 0..<size {
            for c in 0..<size {
                let base = (boxCols * (rowOrder[r] % boxRows) + rowOrder[r] / boxRows + colOrder[c]) % size
                solution[r * size + c] = symbolOrder[base]
            }
        }

        var given = solution
        var order = rng.shuffled(Array(0..<(size * size)))
        var clues = size * size
        while let cell = order.popLast(), clues > 14 {
            let saved = given[cell]
            given[cell] = -1
            if solutionCount(given, size: size, boxRows: boxRows, boxCols: boxCols, limit: 2) == 1 {
                clues -= 1
            } else {
                given[cell] = saved
            }
        }
        return HandbookSudoku(size: size, boxRows: boxRows, boxCols: boxCols, symbols: symbols, given: given, solution: solution)
    }

    /// How many ways the grid can be finished, counted only up to `limit`.
    static func solutionCount(_ grid: [Int], size: Int, boxRows: Int, boxCols: Int, limit: Int) -> Int {
        var grid = grid
        func allowed(_ cell: Int) -> [Int] {
            let r = cell / size, c = cell % size
            var used = Set<Int>()
            for i in 0..<size { used.insert(grid[r * size + i]); used.insert(grid[i * size + c]) }
            let br = r / boxRows * boxRows, bc = c / boxCols * boxCols
            for dr in 0..<boxRows { for dc in 0..<boxCols { used.insert(grid[(br + dr) * size + bc + dc]) } }
            return (0..<size).filter { !used.contains($0) }
        }
        func solve() -> Int {
            // The emptiest-choice square first keeps this instant at 6x6.
            var best: (cell: Int, options: [Int])?
            for cell in 0..<grid.count where grid[cell] == -1 {
                let options = allowed(cell)
                if options.isEmpty { return 0 }
                if best == nil || options.count < best!.options.count { best = (cell, options) }
            }
            guard let target = best else { return 1 }
            var found = 0
            for option in target.options {
                grid[target.cell] = option
                found += solve()
                grid[target.cell] = -1
                if found >= limit { break }
            }
            return found
        }
        return solve()
    }

    // MARK: Odd one out

    static func oddOne(dayBook: BoundDayBook?, seed: String) -> HandbookOddOne? {
        var rng = HandbookRandom(seed: seed + "|odd")
        let cast = (dayBook?.chart.cast ?? []).map(\.name)
        let rooms = roomLabels(dayBook?.chart)
        let moons = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        var rounds: [HandbookOddOne.Round] = []
        func round(of three: [String], intruder: String, reason: String) {
            var options = Array(three.prefix(3)) + [intruder]
            options = rng.shuffled(options)
            rounds.append(HandbookOddOne.Round(options: options, answer: options.firstIndex(of: intruder) ?? 0, reason: reason))
        }
        if cast.count >= 3, let room = rng.shuffled(rooms).first {
            round(of: rng.shuffled(cast), intruder: room, reason: "\(room) is a place; the rest are in your Cast.")
        }
        if rooms.count >= 3, let name = rng.shuffled(cast).first {
            round(of: rng.shuffled(rooms), intruder: name, reason: "\(name) is someone; the rest are rooms.")
        }
        if let day = rng.shuffled(weekdays).first {
            round(of: rng.shuffled(moons), intruder: day, reason: "\(day) is a day; the rest are phases of the moon.")
        }
        if let moon = rng.shuffled(moons).first {
            round(of: rng.shuffled(weekdays), intruder: moon, reason: "\(moon) is a moon; the rest are days.")
        }
        guard rounds.count >= 3, !(cast.count < 3 && rooms.count < 3) else { return nil }
        return HandbookOddOne(rounds: Array(rounds.prefix(4)))
    }
}

// MARK: - Notes in the margins of the book
//
// Lined space for the reader, each with a small encouragement or a prompt. The bundled bank is
// only the floor: a monthly pack can deliver its own (`notePrompts`) and retire old ones
// (`retiredNotePromptIDs`), so the invitations stay fresh without an app update. A pack's own
// prompts are dealt before the bundled ones, so a new month reads like a new month.

enum NotePrompts {
    enum Kind: String, Codable, CaseIterable {
        /// For the foot of a day's page.
        case day
        /// For spare room on a leaf of puzzles.
        case puzzle
        /// For the open margin of a lesson or worksheet.
        case margin
        /// Fits anywhere.
        case any
    }

    struct Row: Equatable {
        var id: String
        var kind: Kind
        var text: String
    }

    /// What a pack delivers. `kind` may be left out, which means anywhere.
    struct Delivered: Codable, Equatable {
        var id: String
        var kind: String?
        var text: String
    }

    static let bundled: [Row] = [
        Row(id: "np-d01", kind: .day, text: "One sentence about today, in your own words."),
        Row(id: "np-d02", kind: .day, text: "What did you notice that nobody else did?"),
        Row(id: "np-d03", kind: .day, text: "Write down the best thing anyone said to you."),
        Row(id: "np-d04", kind: .day, text: "A smell, a sound, a colour. Pick one and keep it."),
        Row(id: "np-d05", kind: .day, text: "What are you carrying over into tomorrow?"),
        Row(id: "np-d06", kind: .day, text: "Something small that went right."),
        Row(id: "np-d07", kind: .day, text: "Who did you think of today, and why?"),
        Row(id: "np-d08", kind: .day, text: "What did you eat, and was it any good?"),
        Row(id: "np-d09", kind: .day, text: "A line you would be glad to find in a year."),
        Row(id: "np-d10", kind: .day, text: "What was the weather doing, and what was it doing to you?"),
        Row(id: "np-d11", kind: .day, text: "One thing you meant to do and didn't. It is forgiven."),
        Row(id: "np-d12", kind: .day, text: "Draw something here if the words won't come."),
        Row(id: "np-d13", kind: .day, text: "What made you laugh, even a little?"),
        Row(id: "np-d14", kind: .day, text: "Where did you go today that you didn't have to?"),
        Row(id: "np-d15", kind: .day, text: "A sentence is enough. Any sentence."),
        Row(id: "np-d16", kind: .day, text: "What did your hands do today?"),
        Row(id: "np-p01", kind: .puzzle, text: "Make up a riddle about something in your room."),
        Row(id: "np-p02", kind: .puzzle, text: "Try a sentence with no letter E. It is harder than it sounds."),
        Row(id: "np-p03", kind: .puzzle, text: "Hide one of your words somewhere on this page for the next reader."),
        Row(id: "np-p04", kind: .puzzle, text: "Write the first line of a story, then stop."),
        Row(id: "np-p05", kind: .puzzle, text: "Draw the maze you wish you were in."),
        Row(id: "np-p06", kind: .puzzle, text: "Write down a question you would like the Book to answer."),
        Row(id: "np-p07", kind: .puzzle, text: "Three words you would like to meet in next week's puzzles."),
        Row(id: "np-p08", kind: .puzzle, text: "Scratch your working out here. Nobody is marking it."),
        Row(id: "np-m01", kind: .margin, text: "What does this remind you of? Write the first thing that comes."),
        Row(id: "np-m02", kind: .margin, text: "One thing from this you would actually like to try."),
        Row(id: "np-m03", kind: .margin, text: "Disagree with the lesson here. Politely, if you must."),
        Row(id: "np-m04", kind: .margin, text: "Where in your own week did this already happen?"),
        Row(id: "np-m05", kind: .margin, text: "Put it in your own words, as if telling a friend."),
        Row(id: "np-m06", kind: .margin, text: "A question the room didn't answer."),
        Row(id: "np-m07", kind: .margin, text: "Sketch the room, or the person teaching it."),
        Row(id: "np-m08", kind: .margin, text: "Which part made you want to look away? Write that part."),
        Row(id: "np-m09", kind: .margin, text: "Something you knew already and never said."),
        Row(id: "np-m10", kind: .margin, text: "Write the line you want to remember from this, exactly."),
        Row(id: "np-m11", kind: .margin, text: "What would you change about this lesson?"),
        Row(id: "np-m12", kind: .margin, text: "Who else should be sitting in this room with you?"),
        Row(id: "np-m13", kind: .margin, text: "Write the opposite of this lesson. Does it hold up?"),
        Row(id: "np-m14", kind: .margin, text: "A person you would like to teach this to."),
        Row(id: "np-m15", kind: .margin, text: "What would this look like in the smallest possible version?"),
        Row(id: "np-m16", kind: .margin, text: "Note what you felt in your body while you read it."),
        Row(id: "np-m17", kind: .margin, text: "A word from this you want to use on purpose this week."),
        Row(id: "np-m18", kind: .margin, text: "Leave the margin to the room. Draw whatever it is doing."),
        Row(id: "np-m19", kind: .margin, text: "What is the lesson afraid you will notice?"),
        Row(id: "np-m20", kind: .margin, text: "Write a footnote to this, as if from a very serious scholar."),
        Row(id: "np-a01", kind: .any, text: "What are you looking forward to?"),
        Row(id: "np-a02", kind: .any, text: "What would you like the next issue to remember about you?"),
        Row(id: "np-a03", kind: .any, text: "A page for whatever comes to mind."),
        Row(id: "np-a04", kind: .any, text: "Write one true thing, however small."),
        Row(id: "np-a05", kind: .any, text: "Leave a note for the person you will be next week."),
        Row(id: "np-a06", kind: .any, text: "Who should hear from you? Write their name, then a line.")
    ]

    private static let bannedWords = ["hinge", "ritual"]

    /// A delivered prompt is held to the same promises as the bundled ones; a bad one is dropped,
    /// not fatal, because the pack's other content must still install.
    static func acceptable(_ item: Delivered) -> Bool {
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.id.isEmpty, [".", "?", "!"].contains(String(text.last ?? " ")),
              text.split(whereSeparator: \.isWhitespace).count <= 24, text.count >= 12 else { return false }
        if let kind = item.kind, Kind(rawValue: kind) == nil { return false }
        let lowered = text.lowercased()
        return !bannedWords.contains(where: lowered.contains)
    }

    /// The bundled bank with a month's deliveries merged in. The same id replaces; retired ids leave.
    static func bank(delivered: [Delivered] = [], retiring: Set<String> = []) -> (bundled: [Row], delivered: [Row]) {
        let ids = Set(delivered.filter(acceptable).map(\.id))
        let base = bundled.filter { !retiring.contains($0.id) && !ids.contains($0.id) }
        let fresh = delivered.filter { acceptable($0) && !retiring.contains($0.id) }
            .map { Row(id: $0.id, kind: $0.kind.flatMap(Kind.init) ?? .any, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return (base, fresh)
    }

    /// The prompt for this spot: a pack's own first, then the bundled, each in an order fixed by
    /// the seed, skipping anything the book has already used.
    static func pick(kind: Kind, seed: String, avoiding used: Set<String>,
                     delivered: [Delivered] = [], retiring: Set<String> = []) -> Row? {
        let (base, fresh) = bank(delivered: delivered, retiring: retiring)
        func order(_ rows: [Row]) -> [Row] {
            rows.filter { $0.kind == kind || $0.kind == .any }
                .sorted { HandbookBuilder.stableHash(seed + $0.id) < HandbookBuilder.stableHash(seed + $1.id) }
        }
        let ordered = order(fresh) + order(base)
        return ordered.first { !used.contains($0.id) } ?? ordered.first
    }
}
