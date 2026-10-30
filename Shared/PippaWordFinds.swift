import Foundation

/// Prepared away from the UI. A shake selects a scrap; it never reads the archive.
struct PippaScrap: Equatable, Identifiable, Sendable {
    var id: String
    var line: String
    var ornament: String? = nil
    var word: String? = nil
    var sourcePageIDs: [String] = []

    /// What she says for being shaken. She was busy, it was rude, and she's
    /// brought you something anyway.
    static let cheek: [PippaScrap] = [
        .init(id: "cheek:sitting", line: "I was SITTING on that full stop. Now it’s a comma. Hope you’re happy."),
        .init(id: "cheek:name", line: "You nearly shook my name off."),
        .init(id: "cheek:strong", line: "Yes, yes. You’re very big and very strong. Here."),
        .init(id: "cheek:hold", line: "Next time YOU hold on and I’ll do the shaking."),
        .init(id: "cheek:pockets", line: "Everything fell out of my pockets. Mostly full stops. Sorry about your next sentence."),
        .init(id: "cheek:semicolon", line: "I was asleep in a semicolon. Take this and stop shaking."),
        .init(id: "cheek:saving", line: "Again‽ Fine. Here’s one I was saving."),
        .init(id: "cheek:index", line: "You shook me all the way into the index. I came back with this.")
    ]

    /// Exclamation marks are her weakness. One of these answers the reader's.
    static let exclamations: [PippaScrap] = [
        .init(id: "heard:exclamation:index", line: "I heard an exclamation mark! I came the long way round, through the index.", ornament: "!"),
        .init(id: "heard:exclamation:mine", line: "Was that ! for me? I’m keeping it. It’s mine now.", ornament: "!"),
        .init(id: "heard:exclamation:wings", line: "You wrote a ! and I felt it in my wings.", ornament: "!"),
        .init(id: "heard:exclamation:pop", line: "Something exciting happened in your writing. I could tell. It went POP.", ornament: "!")
    ]
}

struct PippaReading: Equatable, Sendable {
    var words: [String] = []
    var scraps: [PippaScrap] = []
    var exclamationCount = 0
    var questionCount = 0

    func favouriteScrap(for word: String) -> PippaScrap? {
        guard words.contains(word), let original = scraps.first(where: { $0.id == "word:\(word)" }) else { return nil }
        return PippaScrap(id: "favourite:\(word)", line: "I’ve still got your ‘\(word)’. It sleeps in my sock now. You can visit.",
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
                    ? "One exclamation mark in your pages. I’ve been standing on it like a pole. Great view."
                    : "\(count) exclamation marks in your pages! I tried stacking them. Ceiling problem.",
                sourcePageIDs: Array(Set(exclamationSources).sorted().prefix(8))
            ))
            if count >= 6 {
                reading.scraps.append(PippaScrap(id: "craft:ladder",
                    line: "I built a ladder out of your exclamation marks. Don’t tell Mook. He thinks they’re for shouting.",
                    ornament: "!—!\n!—!\n!—!",
                    sourcePageIDs: Array(Set(exclamationSources).sorted().prefix(8))))
            }
        }
        if reading.questionCount > 0 {
            let count = reading.questionCount
            reading.scraps.append(PippaScrap(id: "inventory:questions", line: count == 1
                ? "One question mark in your pages. I hung my hat on it."
                : "\(count) question marks in your pages. I put them in a jar. Now they’re asking how to get out.",
                sourcePageIDs: Array(Set(questionSources).sorted().prefix(8))))
        }

        for word in reading.words.prefix(24) {
            guard let fact = vocabulary[word] else { continue }
            let sources = Array(fact.pageIDs.sorted().prefix(8))
            let line = fondWords[word] ?? foundWord(word)
            reading.scraps.append(PippaScrap(id: "word:\(word)", line: line, word: word, sourcePageIDs: sources))
            if fact.count >= 3 {
                reading.scraps.append(PippaScrap(id: "repeat:\(word)",
                    line: "You’ve written ‘\(word)’ \(fact.count) times. They found each other and started a club. I’m not allowed in.",
                    word: word, sourcePageIDs: sources))
            }
            if fact.last.timeIntervalSince(fact.first) >= 7 * 86_400 {
                reading.scraps.append(PippaScrap(id: "return:\(word)",
                    line: "‘\(word)’ came back on another Page. I knew it by its feet.", word: word, sourcePageIDs: sources))
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

    /// Any word she has no particular opinion about yet. Chosen by the word
    /// itself, so the same word always gets the same line and twenty words
    /// don't all get one.
    private static func foundWord(_ word: String) -> String {
        let lines = [
            "You can keep the sentence. I’m keeping ‘\(word)’.",
            "Caught ‘\(word)’ falling off the end of a line. Mine now.",
            "‘\(word)’ was just lying there in your writing, so I picked it up. Finders keepers.",
            "I’ve been riding ‘\(word)’ round the margins. It goes surprisingly fast.",
            "I said ‘\(word)’ out loud forty times. Now it doesn’t sound like a word. It sounds like a bird.",
            "I’ve tucked ‘\(word)’ behind my ear for later.",
            "‘\(word)’ followed me home. Can I keep it? I’m keeping it.",
            "I swapped Mook a full stop for your ‘\(word)’. He got the worse deal."
        ]
        let seed = word.unicodeScalars.reduce(UInt32(2_166_136_261)) { ($0 ^ $1.value) &* 16_777_619 }
        return lines[Int(seed % UInt32(lines.count))]
    }

    private static let fondWords = [
        "moss": "You wrote ‘moss’. Best word. Soft underneath. I napped on it.",
        "velvet": "‘Velvet’. I’m lining my pockets with it. Don’t ask for it back.",
        "home": "I slept in the ‘o’ in your ‘home’. It was warm in there.",
        "perhaps": "‘Perhaps’. I asked it to make its mind up. It said perhaps.",
        "again": "You wrote ‘again’. Again! It keeps coming back. Suspicious.",
        "puddle": "I jumped in your ‘puddle’. Both feet. Worth it.",
        "moon": "You left ‘moon’ in here. I’ve been reading by it.",
        "orchard": "I planted your ‘orchard’ in the margin. Something’s coming up already.",
        "kettle": "Your ‘kettle’ is a small dragon with a handle. I’ve named it Biscuit.",
        "rain": "You wrote ‘rain’. I’m sheltering under the commas till it stops.",
        "tea": "Your ‘tea’ went cold while I was sitting in it. Sorry. Mostly sorry.",
        "coffee": "I had one sip of your ‘coffee’. Now I can see sounds.",
        "cat": "Your ‘cat’ looked at me. I looked back. We’re not friends yet.",
        "dog": "Your ‘dog’ tried to eat me. Fair. I’m very small and shiny.",
        "bird": "Your ‘bird’ and I had a race. I let it win. I did not let it win.",
        "snow": "You wrote ‘snow’. I made a snow angel in it. Tiny. One wing each side.",
        "star": "I climbed your ‘star’. All five points. The top one’s sharp.",
        "window": "I pressed my face on your ‘window’. There’s a smudge now. That’s me.",
        "garden": "I’ve moved into your ‘garden’. Third worm on the left. Come and visit.",
        "bread": "Pinched a crumb off your ‘bread’. That’s me fed for a week.",
        "book": "You wrote ‘book’. Inside a book. I got dizzy.",
        "night": "Your ‘night’ has holes in it. That’s where the stars get out.",
        "sun": "I sat on your ‘sun’. Hot. VERY hot. Wings fine.",
        "sea": "I put one toe in your ‘sea’. It’s very big for something on a page.",
        "walk": "I came on your ‘walk’ with you. You didn’t notice. I was very quiet. For me."
    ]

    private static let connections: [(String, String, String)] = [
        ("door", "key", "A ‘door’ on one Page. A ‘key’ on another. These two wanted to meet."),
        ("moon", "kettle", "Your ‘moon’ and your ‘kettle’ are related. Both borrowed their light. The kettle denies it."),
        ("rain", "kettle", "I introduced your ‘rain’ to your ‘kettle’. They’re arguing. I’m on the kettle’s side."),
        ("home", "moss", "I brought ‘moss’ over to ‘home’. It’s moving in."),
        ("sea", "pocket", "Your ‘sea’ won’t fit in your ‘pocket’. I’ve tried."),
        ("cat", "bird", "Your ‘cat’ and your ‘bird’ are on different Pages. I’m keeping it that way."),
        ("tea", "rain", "Your ‘rain’ fell in your ‘tea’. Now it’s weak tea. Blame the sky."),
        ("dog", "walk", "Your ‘dog’ found your ‘walk’ on another Page. Huge relief all round."),
        ("star", "window", "I hung your ‘star’ in your ‘window’. Don’t move it. It took ages."),
        ("bird", "bread", "Your ‘bird’ found your ‘bread’. I didn’t help. I helped a bit.")
    ]

    private static let stopWords: Set<String> = Set("the and but for with that this there their they them then than was were are been being have has had did does not you your yours our ours she her his him its into onto from about just really very some more much what when where which who how why can could would should will shall may might must don don’t didn didn’t isn isn’t wasn wasn’t couldn couldn’t wouldn wouldn’t shouldn shouldn’t today yesterday tomorrow said says feel felt feeling think thought because also only still even like one two all any each every it’s i’m i’ve i’ll i’d we’re they’re you’re myself yourself itself ourselves themselves".split(separator: " ").map(String.init))
}
