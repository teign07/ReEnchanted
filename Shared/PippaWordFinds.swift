import Foundation

/// Prepared away from the UI. A shake selects a scrap; it never reads the archive.
struct PippaScrap: Equatable, Identifiable, Sendable {
    var id: String
    var line: String
    var ornament: String? = nil
    var word: String? = nil
    var sourcePageIDs: [String] = []

    static let cheek: [PippaScrap] = [
        .init(id: "cheek:mysterious", line: "I was being mysterious."),
        .init(id: "cheek:name", line: "You nearly shook my name off."),
        .init(id: "cheek:enormous", line: "Yes, yes. You’re enormous."),
        .init(id: "cheek:hold", line: "Next time, YOU hold on."),
        .init(id: "cheek:sitting", line: "I was SITTING there."),
        .init(id: "cheek:wings", line: "All right. Your turn. Fly.")
    ]

    static let exclamation = PippaScrap(
        id: "heard:exclamation", line: "I heard that !\nNearly stood on it.", ornament: "!"
    )
}

struct PippaReading: Equatable, Sendable {
    var words: [String] = []
    var scraps: [PippaScrap] = []
    var exclamationCount = 0
    var questionCount = 0

    func favouriteScrap(for word: String) -> PippaScrap? {
        guard words.contains(word), let original = scraps.first(where: { $0.id == "word:\(word)" }) else { return nil }
        return PippaScrap(id: "favourite:\(word)", line: "Still got ‘\(word)’.\nYou may visit it.",
                          word: word, sourcePageIDs: original.sourcePageIDs)
    }
}

enum PippaWordFinds {
    static func addedExclamation(before: String, after: String) -> Bool {
        guard before != after, after.utf8.contains(33) else { return false }
        // Appending ! is the common path; no filtered String allocations.
        if after.utf8.last == 33, after.hasPrefix(before) { return true }
        return after.utf8.reduce(0) { $0 + ($1 == 33 ? 1 : 0) }
            > before.utf8.reduce(0) { $0 + ($1 == 33 ? 1 : 0) }
    }

    /// Only the provenance-aware reader boundary is allowed into her satchel.
    /// Page bodies, model replies, quoted books and imported prose are not hers
    /// to attribute to the reader. Duplicate archive rows count once.
    static func prepare(days: [BookDay]) -> PippaReading {
        var seen = Set<String>()
        var writings: [Writing] = []
        for day in days {
            for page in day.pages where seen.insert(page.id).inserted {
                guard page.privacy != .localSensitive else { continue }
                let texts = page.readerAuthoredTexts
                if !texts.isEmpty {
                    writings.append(Writing(id: page.id, date: page.createdAt, texts: texts))
                }
            }
        }
        return prepare(writings: writings)
    }

    struct Writing: Sendable {
        var id: String
        var date: Date
        var texts: [String]
    }

    private struct Word {
        var count = 0
        var first: Date
        var last: Date
        var pageIDs = Set<String>()
    }

    /// Pure, deterministic observations. The facts are literal; the opinions
    /// belong to Pippa. No inference about the reader's feelings or life.
    static func prepare(writings: [Writing]) -> PippaReading {
        var reading = PippaReading()
        var vocabulary: [String: Word] = [:]
        var seen = Set<String>()
        var exclamationSources: [String] = []
        var questionSources: [String] = []
        for writing in writings where seen.insert(writing.id).inserted {
            guard !Task.isCancelled else { return PippaReading() }
            for text in writing.texts {
                let exclamations = text.reduce(0) { $0 + ($1 == "!" ? 1 : 0) }
                let questions = text.reduce(0) { $0 + ($1 == "?" ? 1 : 0) }
                reading.exclamationCount += exclamations
                reading.questionCount += questions
                if exclamations > 0 { exclamationSources.append(writing.id) }
                if questions > 0 { questionSources.append(writing.id) }
                for token in text.split(whereSeparator: { !$0.isLetter }) {
                    let word = token.lowercased()
                    guard (3...18).contains(word.count), !stopWords.contains(word) else { continue }
                    var fact = vocabulary[word] ?? Word(first: writing.date, last: writing.date)
                    fact.count += 1
                    fact.first = min(fact.first, writing.date)
                    fact.last = max(fact.last, writing.date)
                    fact.pageIDs.insert(writing.id)
                    vocabulary[word] = fact
                }
            }
        }

        // Recent words lead, with a deterministic tie break. She no longer
        // reaches the first three words in the oldest row and stops forever.
        reading.words = Array(vocabulary.keys.sorted {
            let left = vocabulary[$0]!.last, right = vocabulary[$1]!.last
            return left == right ? $0 < $1 : left > right
        }.prefix(48))

        if reading.exclamationCount > 0 {
            let count = reading.exclamationCount
            reading.scraps.append(PippaScrap(
                id: "inventory:exclamations", line: count == 1
                    ? "One exclamation mark in your kept words. Mine to balance on."
                    : "\(count) exclamation marks in your kept words. I tried stacking them. Ceiling problem.",
                sourcePageIDs: Array(Set(exclamationSources).sorted().prefix(8))
            ))
            if count >= 6 {
                reading.scraps.append(PippaScrap(id: "craft:ladder",
                    line: "I made a ladder from your exclamation marks.", ornament: "!—!\n!—!\n!—!",
                    sourcePageIDs: Array(Set(exclamationSources).sorted().prefix(8))))
            }
        }
        if reading.questionCount > 0 {
            let count = reading.questionCount
            reading.scraps.append(PippaScrap(id: "inventory:questions", line: count == 1
                ? "One question mark in your kept words. I hung my coat on it."
                : "\(count) question marks in your kept words. I put them in a jar. They’re asking how to get out.",
                sourcePageIDs: Array(Set(questionSources).sorted().prefix(8))))
        }

        for word in reading.words.prefix(24) {
            guard let fact = vocabulary[word] else { continue }
            let sources = Array(fact.pageIDs.sorted().prefix(8))
            let line = fondWords[word] ?? "You may keep the sentence. I’m keeping ‘\(word)’."
            reading.scraps.append(PippaScrap(id: "word:\(word)", line: line, word: word, sourcePageIDs: sources))
            if fact.count >= 3 {
                reading.scraps.append(PippaScrap(id: "repeat:\(word)",
                    line: "‘\(word)’ appears \(fact.count) times in your kept words. They’ve formed a small committee.",
                    word: word, sourcePageIDs: sources))
            }
            if fact.last.timeIntervalSince(fact.first) >= 7 * 86_400 {
                reading.scraps.append(PippaScrap(id: "return:\(word)",
                    line: "‘\(word)’ came back on another Page. I recognised its feet.", word: word, sourcePageIDs: sources))
            }
        }

        // These associations are authored, and require both actual words.
        // At least two Pages must be involved before she claims to join leaves.
        for (left, right, line) in connections {
            guard let a = vocabulary[left], let b = vocabulary[right],
                  a.pageIDs.union(b.pageIDs).count >= 2 else { continue }
            reading.scraps.append(PippaScrap(id: "connection:\(left):\(right)", line: line,
                ornament: "\(left)  ↔  \(right)", sourcePageIDs: Array(a.pageIDs.union(b.pageIDs).sorted().prefix(8))))
        }
        return reading
    }

    private static let fondWords = [
        "moss": "You wrote ‘moss’. Excellent word. Soft underneath.",
        "velvet": "‘Velvet’. I’m lining my pockets with it.",
        "home": "I slept in the ‘o’ in ‘home’. You make a good home.",
        "perhaps": "‘Perhaps’. I’ve asked it to make its mind up.",
        "again": "‘Again’. This one keeps coming back. Suspicious.",
        "puddle": "I borrowed ‘puddle’. Both feet wet. Worth it.",
        "moon": "You left ‘moon’ in here. I’ve been reading by it.",
        "orchard": "‘Orchard’. I’ve put it somewhere it can grow.",
        "kettle": "I like your ‘kettle’. A small dragon with a handle.",
        "rain": "You wrote ‘rain’. I’m staying under the commas."
    ]

    private static let connections: [(String, String, String)] = [
        ("door", "key", "A ‘door’ on one Page. A ‘key’ on another. These two wanted to meet."),
        ("moon", "kettle", "Your ‘moon’ and your ‘kettle’ are related. Both borrowed their light. The kettle denies it."),
        ("rain", "kettle", "I introduced your ‘rain’ to your ‘kettle’. They’re arguing. I’m on the kettle’s side."),
        ("home", "moss", "I brought ‘moss’ over to ‘home’. It’s moving in."),
        ("sea", "pocket", "Your ‘sea’ won’t fit in your ‘pocket’. I have tried.")
    ]

    private static let stopWords: Set<String> = Set("the and but for with that this there their they them then than was were are been being have has had did does not you your yours our ours she her his him its into onto from about just really very some more much what when where which who how why can could would should will shall may might must don don’t didn didn’t isn isn’t wasn wasn’t couldn couldn’t wouldn wouldn’t shouldn shouldn’t today yesterday tomorrow said says feel felt feeling think thought because also only still even like one two all any each every it’s i’m i’ve i’ll i’d we’re they’re you’re myself yourself itself ourselves themselves".split(separator: " ").map(String.init))
}
