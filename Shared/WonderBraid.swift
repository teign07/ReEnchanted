import Foundation

/// The wonder braid: a nightly telling made of small jobs.
///
/// Why it exists. Handed one long brief, the on-device Gemma recites the day,
/// dumps the reader's block back, and invents sensations for the Book. It can
/// connect and it can follow, but it cannot invent a good small impossible
/// thing. So the invention is authored (`WonderBraid.lines`: what an ordinary
/// thing wanted or did), and Gemma's work in each paragraph is small: tell ONE
/// true thing from the reader's day in plain words, let one ordinary thing in it
/// do something odd, and carry the Labyrinth's news. Every paragraph is checked
/// and re-asked; the checks are the doctrine, not the taste:
///
///   - the Book never does the reader's acts ("I watched you ...");
///   - Gemma may invent what OBJECTS do, never what the READER did or felt;
///   - nothing from the cliche list reaches the page;
///   - the reader's own words are kept.
///
/// Everything here is pure: the model is a closure, so the whole thing is tested
/// with a fake. Nothing here runs on a hard night; those keep the tender path.
enum WonderBraid {
    // MARK: - The library

    struct Line: Equatable {
        var id: String
        var nouns: [String]
        /// When present, the line fits only a page that also carries one of these.
        var needs: [String]
        var text: String
    }

    /// Parsed once. Rows are "id|nouns|needs|line"; commas separate words.
    static let lines: [Line] = rows.compactMap { row in
        let parts = row.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4 else { return nil }
        return Line(
            id: parts[0],
            nouns: parts[1].split(separator: ",").map(String.init),
            needs: parts[2].split(separator: ",").map(String.init),
            text: parts[3]
        )
    }

    /// Setting nouns turn up in passing ("on the sofa", "across the tiles"). They
    /// only speak when nothing else on the page acts.
    static let weak: Set<String> = [
        "window", "floor", "rug", "carpet", "tiles", "chair", "chairs", "sofa", "table", "desk", "door", "doors", "wall",
        "gate", "fence", "road", "street", "pavement", "bed", "lamp", "lights", "bag", "bags", "sky", "park", "bench",
        "shop", "sink", "plates", "dishes", "cup", "mug", "pan", "bin", "rubbish", "lane", "market", "store",
        "morning", "mornings", "night", "midnight", "bedtime", "autumn", "october", "smell", "smelled", "smells", "smelt",
        "noise", "sound", "sounds", "sleep", "asleep", "nap", "tired", "water", "shadow", "shadows", "silence", "quiet",
        "stillness", "list", "note", "notes", "kitchen", "hall", "hallway", "bathroom", "office", "meeting", "emails",
        "email", "school", "dust", "floor"
    ]

    /// A line a monthly pack delivers: new wonder for the nouns the month is about,
    /// or a fix to an old line (same id replaces it). `retires` ids leave the library.
    struct Delivered: Codable, Equatable {
        var id: String
        var nouns: [String]
        var needs: [String]?
        var line: String
    }

    /// The bundled library with a month's deliveries merged in. A delivered line
    /// is held to the same promises as the bundled ones; a bad one is dropped, not
    /// fatal, because a pack's other content must still install.
    static func library(delivered: [Delivered], retiring: Set<String> = []) -> [Line] {
        var byID: [String: Line] = [:]
        var order: [String] = []
        for line in lines where !retiring.contains(line.id) {
            byID[line.id] = line
            order.append(line.id)
        }
        for item in delivered where !retiring.contains(item.id) && acceptable(item) {
            if byID[item.id] == nil { order.append(item.id) }
            byID[item.id] = Line(id: item.id, nouns: item.nouns.map { $0.lowercased() }, needs: (item.needs ?? []).map { $0.lowercased() }, text: item.line)
        }
        return order.compactMap { byID[$0] }
    }

    /// The promises every line keeps: one short plain sentence or two, about a
    /// thing, never the banned words, never "I" (these are the world's, not the Book's).
    static func acceptable(_ item: Delivered) -> Bool {
        let text = item.line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = text.lowercased()
        guard !item.id.isEmpty, !item.nouns.isEmpty, item.nouns.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return false }
        guard text.last == "." || text.last == "!", text.split(whereSeparator: \.isWhitespace).count <= 32 else { return false }
        return !["hinge", "ritual"].contains(where: lowered.contains) && !has(firstPersonPattern, in: text)
    }

    struct Beat: Equatable {
        /// The reader's own words, already facing the reader ("You found ...").
        var detail: String
        var lines: [String]
        var lineIDs: [String]
    }

    // MARK: - Matching

    private static func lowercasedTokens(_ text: String) -> Set<String> {
        var tokens = Set<String>()
        var word = ""
        for character in text.lowercased() {
            if character.isLetter {
                word.append(character)
            } else if !word.isEmpty {
                tokens.insert(word)
                word = ""
            }
        }
        if !word.isEmpty { tokens.insert(word) }
        return tokens
    }

    private static func present(_ noun: String, in lowered: String, tokens: Set<String>) -> Bool {
        if noun.contains(" ") || noun.contains("-") {
            return lowered.range(of: "\\b" + NSRegularExpression.escapedPattern(for: noun) + "s?\\b", options: .regularExpression) != nil
        }
        return !tokens.isDisjoint(with: [noun, noun + "s", noun + "es", noun + "ed", noun + "ing"])
    }

    private struct Group: Hashable {
        var nouns: [String]
        var specific: Bool
    }

    /// The one line that fits this text, or nil. A line written for this very
    /// situation beats a general one, then the order the nouns appear in; setting
    /// nouns only speak when nothing acts; and the day rotates which line a noun
    /// says so it does not say the same thing twice running.
    static func pick(text: String, dateKey: String, excluding used: Set<String>, library: [Line]? = nil) -> Line? {
        let lowered = text.lowercased()
        let tokens = lowercasedTokens(text)
        var groups: [Group: [Line]] = [:]
        var presentNouns: [Group: Set<String>] = [:]
        for line in library ?? lines {
            let here = line.nouns.filter { present($0, in: lowered, tokens: tokens) }
            guard !here.isEmpty else { continue }
            if !line.needs.isEmpty, !line.needs.contains(where: { present($0, in: lowered, tokens: tokens) }) { continue }
            let group = Group(nouns: line.nouns, specific: !line.needs.isEmpty)
            groups[group, default: []].append(line)
            presentNouns[group] = Set(here)
        }
        guard !groups.isEmpty else { return nil }
        // A setting noun ("on the sofa") speaks only when nothing on the page acts.
        let strong = groups.filter { !(presentNouns[$0.key] ?? []).isSubset(of: weak) }
        let pool = strong.isEmpty ? groups : strong

        func firstAt(_ group: Group) -> Int {
            var best = Int.max
            for noun in group.nouns {
                if let range = lowered.range(of: noun) { best = min(best, lowered.distance(from: lowered.startIndex, to: range.lowerBound)) }
            }
            return best
        }
        let ordered = pool.keys.sorted {
            if $0.specific != $1.specific { return $0.specific }
            let a = firstAt($0), b = firstAt($1)
            if a != b { return a < b }
            return $0.nouns.joined(separator: ",") < $1.nouns.joined(separator: ",")
        }
        for group in ordered {
            let candidates = pool[group] ?? []
            guard !candidates.isEmpty else { continue }
            let start = Int(stableHash(dateKey + "|" + group.nouns.joined(separator: ",")) % UInt64(candidates.count))
            for offset in 0..<candidates.count {
                let line = candidates[(start + offset) % candidates.count]
                if !used.contains(line.id) { return line }
            }
        }
        return nil
    }

    /// The reader's day as beats. A short fragment rides with the sentence before
    /// it; a beat that found a line leads; at most four paragraphs, with any overflow merged into the last.
    static func beats(details: [String], dateKey: String, resting: Set<String>, limit: Int = 4, library: [Line]? = nil) -> [Beat] {
        var used = resting
        var raw: [Beat] = []
        for detail in details {
            let text = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if text.split(whereSeparator: \.isWhitespace).count < 5, var last = raw.popLast() {
                last.detail += " " + text
                raw.append(last)
                continue
            }
            if let line = pick(text: text, dateKey: dateKey, excluding: used, library: library) {
                used.insert(line.id)
                raw.append(Beat(detail: text, lines: [line.text], lineIDs: [line.id]))
            } else {
                raw.append(Beat(detail: text, lines: [], lineIDs: []))
            }
        }
        var ordered = raw.filter { !$0.lines.isEmpty } + raw.filter { $0.lines.isEmpty }
        // Nothing the plan placed is left out: the "what was used" receipts credit every
        // placed Page, so a beat past the cap rides in the last paragraph's material.
        if ordered.count > limit, limit > 0 {
            let overflow = ordered[limit...].map(\.detail)
            ordered = Array(ordered[..<limit])
            ordered[limit - 1].detail += " " + overflow.joined(separator: " ")
        }
        return ordered
    }

    // MARK: - Weather: a beat that comes round, not every night

    enum WeatherMode: String { case skip, mention, beat }

    /// A one-sentence mention or its own short paragraph, never two nights
    /// running and never more than three nights without. Stateless: the sequence
    /// is walked forward from a fixed anchor, so a date always gets one answer.
    static func weatherMode(dateKey: String) -> WeatherMode {
        guard let target = dayNumber(dateKey), let anchor = dayNumber("2026-09-01"), target >= anchor else { return .skip }
        var gap = 0
        var last = WeatherMode.skip
        var cursor = anchor
        while true {
            let h = Int(stableHash("weather|\(cursor)") % 100)
            let mode: WeatherMode
            if last != .skip {
                mode = .skip
            } else if gap >= 3 {
                mode = h < 45 ? .mention : .beat
            } else {
                mode = h < 50 ? .skip : (h < 78 ? .mention : .beat)
            }
            gap = mode == .skip ? gap + 1 : 0
            last = mode
            if cursor >= target || cursor - anchor > 4_000 { return mode }
            cursor += 1
        }
    }

    /// Days since 1970-01-01 for "yyyy-MM-dd", with no calendar or time zone.
    static func dayNumber(_ dateKey: String) -> Int? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var y = parts[0]
        let m = parts[1], d = parts[2]
        y -= m <= 2 ? 1 : 0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// The real tags of the Page, said plainly. The moon is named from its phase.
    static func weatherLine(weather: String?, place: String?, moonPhaseName: String?) -> String? {
        guard let weather = weather?.trimmingCharacters(in: .whitespaces).lowercased(), !weather.isEmpty,
              weather != "not recorded" else { return nil }
        var sentence = "It was \(weather)"
        if let place = place?.trimmingCharacters(in: .whitespaces), !place.isEmpty, place.lowercased() != "current place" {
            sentence += " over \(place)"
        }
        if let moon = moonClause(moonPhaseName) { sentence += ", and \(moon)" }
        return sentence + "."
    }

    static func moonClause(_ phase: String?) -> String? {
        guard let name = phase?.lowercased(), !name.isEmpty else { return nil }
        if name.contains("new") { return "there was no moon" }
        if name.contains("full") { return "the moon was full" }
        if name.contains("first quarter") { return "the moon was at its first quarter" }
        if name.contains("last quarter") || name.contains("third quarter") { return "the moon was at its last quarter" }
        if name.contains("crescent") { return "the moon was a \(name)" }
        if name.contains("gibbous") { return "the moon was a \(name)" }
        return nil
    }

    // MARK: - Checks

    enum Problem: Equatable {
        case length(Int)
        case firstPerson
        case stock
        case inventedReader
        case youVerb(String)
        case repeatedSentence
        case readerWordsLost
        case taleLost
        case tic
        case contradictsWeather

        /// A paragraph that fails any of these is never kept as a best effort.
        var isHard: Bool {
            switch self {
            case .firstPerson, .inventedReader, .youVerb, .repeatedSentence, .contradictsWeather: return true
            default: return false
            }
        }
    }

    static let stockPattern = try! NSRegularExpression(
        pattern: "\\b(shimmer\\w*|iridescent|ethereal|glimmer\\w*|tapestry|motes?|suddenly|seemed|couldn't help|a sense of|"
            + "whispered secrets|dancing|dance|symphony|testament|witness|monument|felt|feeling|whisper\\w*|hush\\w*|echo\\w*|"
            + "canine|ballet|sanctuary|haven|cocoon|embrace\\w*|veil|savou?ry|palpable|profound\\w*|somehow)\\b",
        options: [.caseInsensitive]
    )
    private static let firstPersonPattern = try! NSRegularExpression(
        pattern: "\\b(I|I'm|I've|I'd|I'll|my|me|myself)\\b"
    )
    private static let inventedReaderPattern = try! NSRegularExpression(
        pattern: "\\byour (?:hand|hands|shoulders?|face|eyes?|heart|breath|fingers?|smile|jaw|voice|stomach|chest|skin|hair|lips|cheeks?)\\b"
            + "|\\byou (?:felt|seemed|noticed|realised|realized|wondered|thought|decided|drifted|dozed|smiled|sighed|laughed|were (?:nervous|happy|sad|tired|worried|anxious|relieved))\\b",
        options: [.caseInsensitive]
    )
    private static let youVerbPattern = try! NSRegularExpression(pattern: "\\byou(?:'d|'ve)?\\s+(\\w+)", options: [.caseInsensitive])
    private static let ticPattern = try! NSRegularExpression(pattern: "\\bdid [a-z]+\\b", options: [.caseInsensitive])

    private static func has(_ regex: NSRegularExpression, in text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func captures(_ regex: NSRegularExpression, in text: String) -> [String] {
        regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static let irregular: [String: String] = [
        "saw": "see", "took": "take", "went": "go", "came": "come", "got": "get", "made": "make", "found": "find", "ran": "run",
        "sat": "sit", "stood": "stand", "fell": "fall", "held": "hold", "kept": "keep", "left": "leave", "told": "tell", "said": "say",
        "had": "have", "did": "do", "heard": "hear", "knew": "know", "gave": "give", "brought": "bring", "bought": "buy",
        "thought": "think", "rang": "ring", "wrote": "write", "ate": "eat", "drank": "drink", "slept": "sleep", "met": "meet",
        "spilled": "spill", "dropped": "drop", "stopped": "stop", "lay": "lie", "spent": "spend", "lost": "lose", "won": "win"
    ]

    static func stem(_ word: String) -> String {
        var w = irregular[word] ?? word
        for suffix in ["ing", "ed", "es", "s", "ly", "er", "e"] where w.hasSuffix(suffix) && w.count - suffix.count >= 3 {
            w = String(w.dropLast(suffix.count))
            break
        }
        if w.count > 3, let last = w.last, w.dropLast().last == last, !"aeiouls".contains(last) { w = String(w.dropLast()) }
        return w
    }

    private static let stopWords: Set<String> = Set((
        "the a an and or but of to in on at for with from by as is are was were be been it its this that these those you your "
        + "i my me we our they them he she his her not no so if then than when while where which who what into out up down over "
        + "under again once each every one two just have has had do does did will would could should can may might about after "
        + "before through across along around near tonight today"
    ).split(separator: " ").map(String.init))

    static func contentWords(_ text: String) -> Set<String> {
        Set(lowercasedTokens(text).filter { $0.count >= 4 && !stopWords.contains($0) })
    }

    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"").replacingOccurrences(of: "\u{201D}", with: "\"")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            current.append(character)
            if ".!?".contains(character) {
                let next = index + 1 < characters.count ? characters[index + 1] : " "
                if next.isWhitespace || next == "\"" || next == "\u{201D}" {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { result.append(trimmed) }
                    current = ""
                }
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private static let allowedYouVerbs: Set<String> = [
        "were", "was", "had", "did", "didn't", "could", "would", "saw", "just", "still", "also", "may", "might", "have", "don't",
        "can", "never", "always", "only", "even", "all", "ever", "got", "watched", "looked", "heard", "stood", "sat", "went",
        "watch", "see", "look", "hear", "stand", "sit", "go"
    ]

    /// What is wrong with a paragraph of the reader's day.
    static func check(_ text: String, beat: Beat, tale: String?) -> [Problem] {
        var problems: [Problem] = []
        let count = text.split(whereSeparator: \.isWhitespace).count
        if count < 22 || count > 95 { problems.append(.length(count)) }
        if has(firstPersonPattern, in: text) { problems.append(.firstPerson) }
        if has(stockPattern, in: text) { problems.append(.stock) }
        if has(inventedReaderPattern, in: text), !has(inventedReaderPattern, in: beat.detail) { problems.append(.inventedReader) }
        let allowed = Set(lowercasedTokens(beat.detail + " " + (tale ?? "")).map(stem)).union(allowedYouVerbs)
        for verb in captures(youVerbPattern, in: text) {
            let lowered = verb.lowercased()
            if !allowed.contains(stem(lowered)) && !allowed.contains(lowered) {
                problems.append(.youVerb(lowered))
                break
            }
        }
        let seen = sentences(text).map(normalized)
        if seen.count != Set(seen).count { problems.append(.repeatedSentence) }
        let need = contentWords(beat.detail)
        if !need.isEmpty, Double(need.intersection(contentWords(text)).count) / Double(need.count) < 0.4 {
            problems.append(.readerWordsLost)
        }
        if let tale {
            let key = Array(contentWords(tale)).sorted().prefix(3)
            if !key.isEmpty, !key.contains(where: { contentWords(text).contains($0) }) { problems.append(.taleLost) }
        }
        return problems
    }

    /// The app's scrub does this for the plain braid: drop the sentence that
    /// carries the cliche, keep the rest. Authored lines are never dropped.
    static func repaired(_ text: String, keeping lines: [String]) -> String? {
        let kept = sentences(text).filter { sentence in
            !has(stockPattern, in: sentence) || lines.contains { normalized(sentence).contains(normalized($0)) }
        }
        let fixed = kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return fixed.isEmpty || fixed == text ? nil : fixed
    }

    // MARK: - Prompts

    static let readerSystem = "You write one paragraph of a contemporary domestic faerie tale: exact, physical, a little funny, sometimes cozy, "
        + "sometimes terrible. Plain words, contractions, past tense. You tell it to the reader as 'you'. "
        + "Never invent people, places, objects or feelings that are not given. Never write 'I' or 'my'."

    static let bookSystem = "You are the Book: an old, mischievous, good-hearted book who keeps a day and has business of its own. "
        + "Short plain words, contractions, past tense. You say 'I' for yourself and 'you' for the reader. "
        + "You cannot touch or smell or taste: you only notice, and you read, and you listen to the building. "
        + "Never describe your body or your feelings. Never invent people. State odd things as plain fact."

    static func jobPrompt(beat: Beat, tale: String?) -> String {
        var parts = ["Something true from the reader's day: \(beat.detail)"]
        for line in beat.lines {
            parts.append("A seed for the small impossible thing an ordinary object here might have done or wanted: \"\(line)\" "
                + "Use it, bend it, or invent a better one of your own. Have fun with it.")
        }
        if let tale { parts.append("Something odd also happened nearby, to work in as one sentence: \(tale)") }
        parts.append("Write 40-60 words, 3 or 4 sentences, one paragraph, in the past tense, to the reader as 'you'. "
            + "Tell the true thing in your own plain words"
            + (beat.lines.isEmpty ? "" : ", then let one ordinary thing in it do or want one small impossible thing, stated as plain fact")
            + ". Do not invent anything the reader did or felt.")
        return parts.joined(separator: "\n")
    }

    static func playPrompt(told: [String], tale: String?, idea: String?) -> String {
        var parts = ["Already told, do not repeat it: " + told.map { $0.hasSuffix(".") ? $0 : $0 + "." }.joined(separator: " ")]
        if let tale { parts.append("The Labyrinth's odd news, to carry on from: \(tale)") }
        if let idea { parts.append("One idea you may use, bend, or beat: \(idea)") }
        parts.append("Write 55-85 words, one paragraph, past tense: what happened NEXT. Follow the odd news (or one ordinary thing) as it wandered "
            + "off through the building and got into small, funny, impossible trouble. Be specific and a bit silly, with a named object or two. "
            + "You may say 'I' as the Book watching, but never say what the reader did or felt beyond what is given.")
        return parts.joined(separator: "\n")
    }

    static func businessPrompt(opening: String) -> String {
        "Begin with this sentence exactly: \"\(opening)\"\nSay one small thing the hunt turned up. It is not the answer.\n"
            + "Write 25-45 words, 2 or 3 sentences, one paragraph, past tense. Add one small odd thing, stated as fact. Do not solve or finish anything."
    }

    static func weatherBeatPrompt(opening: String) -> String {
        "Begin with this sentence exactly: \"\(opening)\"\nSay what the sky was doing, plainly, and one odd small thing the dark did about it.\n"
            + "Write 25-45 words, 2 or 3 sentences, one paragraph, past tense. Add one small odd thing, stated as fact. Do not solve or finish anything."
    }

    static func weatherSentencePrompt(world: String) -> String {
        "The weather tonight: \(world)\nWrite ONE sentence, 12-22 words, past tense, of the Book noticing it at the window, "
            + "with one small odd thing the weather did. Do not say how it felt or smelled."
    }

    // MARK: - Orchestration

    /// One model call: system text, user text, sampling, and a token ceiling.
    typealias Teller = (_ system: String, _ user: String, _ temperature: Float, _ topP: Float, _ maxTokens: Int) async throws -> String

    struct Input {
        /// The reader's day, one entry per atom, already facing the reader.
        var details: [String]
        var dateKey: String
        var tale: String?
        /// The Book's own thread for the night, in its own voice.
        var business: String?
        /// The Page's real weather, moon and place as one plain sentence.
        var weather: String?
        /// Words the Book wrote on kept Pages, carried whole (never the reader's).
        var bookLines: [String] = []
        /// Library lines used in the last weeks.
        var resting: Set<String> = []
        /// What the month's installed packs add to, and take out of, the library.
        var delivered: [Delivered] = []
        var retiring: Set<String> = []
        /// How the model is waited on. It can be busy (a margin reply from the keep
        /// that prompted a re-braid is still being written) or briefly short of
        /// room; neither is a reason to assemble the night without it.
        var patience = Patience()
    }

    /// How long a job waits for a busy or briefly refusing model before the
    /// telling is given up (and nothing is published) rather than assembled
    /// without Gemma. Tests pass a zero pause.
    struct Patience: Equatable {
        var pauseSeconds: Double = 2
        /// Waits allowed for a reader's paragraph: about a minute by default.
        var waits = 30
        /// Waits for the optional paragraphs (play, weather, business), which can go without.
        var optionalWaits = 3
    }

    /// The model never answered. The braid reports it and the Page is left as it was.
    struct ModelUnavailable: Error, LocalizedError {
        var underlying: Error
        var errorDescription: String? { underlying.localizedDescription }
    }

    /// One model call that waits out a busy model. A cancelled braid stops at once.
    private static func ask(
        _ tell: Teller, _ system: String, _ user: String, _ temperature: Float, _ topP: Float, _ maxTokens: Int,
        waits: Int, pauseSeconds: Double
    ) async throws -> String {
        var waited = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await tell(system, user, temperature, topP, maxTokens)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard waited < waits else { throw ModelUnavailable(underlying: error) }
                waited += 1
                if pauseSeconds > 0 { try await Task.sleep(nanoseconds: UInt64(pauseSeconds * 1_000_000_000)) }
            }
        }
    }

    struct Output: Equatable {
        var paragraphs: [String]
        var lineIDs: [String]
        var jobsFellBack: Int
        var thin: Bool
        var weather: WeatherMode
        var prose: String { paragraphs.joined(separator: "\n\n") }
    }

    /// The telling, or nil when the night is not for this path (nothing to
    /// braid, or Gemma failed so badly there is nothing honest to keep).
    static func write(_ input: Input, tell: Teller) async throws -> Output? {
        let beats = Self.beats(
            details: input.details, dateKey: input.dateKey, resting: input.resting,
            library: library(delivered: input.delivered, retiring: input.retiring)
        )
        guard !beats.isEmpty else { return nil }
        var paragraphs: [String] = []
        var fellBack = 0

        for (index, beat) in beats.enumerated() {
            let beatTale = (index == 1 || (index == 0 && beats.count == 1)) ? input.tale : nil
            if let text = try await readerParagraph(beat: beat, tale: beatTale, tell: tell, patience: input.patience) {
                paragraphs.append(text)
            } else {
                fellBack += 1
                let detail = beat.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                paragraphs.append(([detail.hasSuffix(".") ? detail : detail + "."] + beat.lines).joined(separator: " "))
            }
        }
        // The Book's own words from kept Pages, whole, after the first paragraph.
        if !input.bookLines.isEmpty {
            paragraphs.insert(input.bookLines.joined(separator: " "), at: min(1, paragraphs.count))
        }
        // A thin day gets room to play, because there is little else to carry the page.
        let thin = beats.count <= 2
        if thin, let play = await playParagraph(
            told: beats.map(\.detail), tale: input.tale, idea: beats.compactMap(\.lines.first).first, tell: tell,
            patience: input.patience
        ) {
            paragraphs.append(play)
        }
        let weatherMode = input.weather == nil ? WeatherMode.skip : Self.weatherMode(dateKey: input.dateKey)
        var weatherBeat: String?
        if let weather = input.weather {
            switch weatherMode {
            case .beat:
                weatherBeat = await bookParagraph(opening: weather, user: weatherBeatPrompt(opening: weather), tell: tell, patience: input.patience)
            case .mention:
                if let sentence = await weatherSentence(world: weather, tell: tell, patience: input.patience), !paragraphs.isEmpty {
                    paragraphs[0] += " " + sentence
                }
            case .skip:
                break
            }
        }
        if let weatherBeat { paragraphs.append(weatherBeat) }
        if let business = input.business?.trimmingCharacters(in: .whitespacesAndNewlines), !business.isEmpty {
            let text = await bookParagraph(opening: business, user: businessPrompt(opening: business), tell: tell, patience: input.patience)
            paragraphs.append(text ?? business)
        }
        return Output(
            paragraphs: paragraphs,
            lineIDs: beats.flatMap(\.lineIDs),
            jobsFellBack: fellBack,
            thin: thin,
            weather: weatherMode
        )
    }

    private static func readerParagraph(beat: Beat, tale: String?, tell: Teller, patience: Patience) async throws -> String? {
        var attempts: [(text: String, problems: [Problem])] = []
        for _ in 0..<4 {
            // A model that cannot be reached is not a bad paragraph: wait for it, or give the telling up.
            var text = try await ask(
                tell, readerSystem, jobPrompt(beat: beat, tale: tale), 0.70, 0.90, 170,
                waits: patience.waits, pauseSeconds: patience.pauseSeconds
            )
            text = firstParagraph(text)
            var problems = check(text, beat: beat, tale: tale)
            if problems.contains(.stock), let fixed = repaired(text, keeping: beat.lines), check(fixed, beat: beat, tale: tale).isEmpty {
                text = fixed
                problems = []
            }
            if problems.isEmpty { return text }
            attempts.append((text, problems))
        }
        // The cleanest attempt with no HARD failure beats assembling without Gemma.
        let usable = attempts.filter { !$0.problems.contains(where: \.isHard) }
        return usable.min { $0.problems.count < $1.problems.count }?.text
    }

    private static func playParagraph(told: [String], tale: String?, idea: String?, tell: Teller, patience: Patience) async -> String? {
        let allowedStems = Set(told.flatMap { lowercasedTokens($0) }.map(stem))
        for _ in 0..<4 {
            guard let raw = try? await ask(tell, bookSystem, playPrompt(told: told, tale: tale, idea: idea), 0.95, 0.95, 170, waits: patience.optionalWaits, pauseSeconds: patience.pauseSeconds) else { continue }
            let text = firstParagraph(raw)
            let count = text.split(whereSeparator: \.isWhitespace).count
            let badYou = captures(youVerbPattern, in: text).contains {
                let v = $0.lowercased()
                return !allowedStems.contains(stem(v)) && !allowedYouVerbs.contains(v)
            }
            let hard = text.range(
                of: "\\b(shimmer\\w*|iridescent|ethereal|tapestry|motes?|suddenly|testament|symphony|palpable|felt|smell\\w*|tast\\w*)\\b",
                options: [.regularExpression, .caseInsensitive]
            ) != nil
            let tic = captures(ticPattern, in: text).count > 1 || text.range(of: "\\bseeds?\\b", options: [.regularExpression, .caseInsensitive]) != nil
            if (40...110).contains(count), !badYou, !hard, !tic { return text }
        }
        return nil
    }

    private static func bookParagraph(opening: String, user: String, tell: Teller, patience: Patience) async -> String? {
        for _ in 0..<4 {
            guard let raw = try? await ask(tell, bookSystem, user, 0.70, 0.90, 120, waits: patience.optionalWaits, pauseSeconds: patience.pauseSeconds) else { continue }
            let text = firstParagraph(raw)
            let count = text.split(whereSeparator: \.isWhitespace).count
            let body = text.range(
                of: "\\b(felt|smell\\w*|tast\\w*|my (?:fingers?|hands?|eyes?|teeth|skin|heart)|did [a-z]+)\\b",
                options: [.regularExpression, .caseInsensitive]
            ) != nil
            if normalized(text).contains(normalized(opening)), (18...60).contains(count), !has(stockPattern, in: text), !body {
                return text
            }
        }
        return nil
    }

    private static func weatherSentence(world: String, tell: Teller, patience: Patience) async -> String? {
        let tag = Set(lowercasedTokens(world).filter { $0.count >= 4 && !stopWords.contains($0) }.map(stem))
        let sky = world.range(of: "overcast|rain|grey|gray|cloud", options: [.regularExpression, .caseInsensitive]) != nil
        for _ in 0..<4 {
            guard let raw = try? await ask(tell, bookSystem, weatherSentencePrompt(world: world), 0.70, 0.90, 60, waits: patience.optionalWaits, pauseSeconds: patience.pauseSeconds) else { continue }
            let text = (raw.split(separator: "\n").first.map(String.init) ?? raw).trimmingCharacters(in: .whitespacesAndNewlines)
            let count = text.split(whereSeparator: \.isWhitespace).count
            let contradicts = sky && text.range(of: "\\b(stars?|sun|sunny|sunshine|blue)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            let usesTag = lowercasedTokens(text).contains { tag.contains(stem($0)) }
            let body = text.range(of: "\\b(felt|smell\\w*|tast\\w*|did [a-z]+)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            if (9...28).contains(count), text.filter({ $0 == "." }).count <= 1, !has(stockPattern, in: text), !contradicts, usesTag, !body {
                return text
            }
        }
        return nil
    }

    private static func firstParagraph(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.components(separatedBy: "\n\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
    }

    /// FNV-1a: stable across launches and platforms (Swift's Hasher is not).
    static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    // MARK: - Kept Pages the Book wrote

    /// The Book's own sentences from Pages it wrote and the reader kept (a Margin
    /// Atlas, say): carried whole, never paraphrased and never given to the
    /// reader. Instructions to tap or pinch are screen furniture, not story.
    static func bookLines(from sentences: [String], limit: Int = 3) -> [String] {
        let imperative = try! NSRegularExpression(
            pattern: "^(open|tap|pinch|drag|swipe|press|write|try|look|pick|choose|bring|notice|find|take|go|come|read|ask|tell|keep|add|return|carry|leave)\\b",
            options: [.caseInsensitive]
        )
        var kept: [String] = []
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !has(imperative, in: trimmed) else { continue }
            kept.append(trimmed)
            if kept.count == limit { break }
        }
        let joined = kept.joined(separator: " ")
        return joined.split(whereSeparator: \.isWhitespace).count > 60 ? [] : (kept.isEmpty ? [] : [joined])
    }
}

/// Which library lines the Book used lately, read back from its own braids' tags.
enum WonderBraidHistory {
    static let tagPrefix = "wonder-line:"

    /// Lines used in the previous three weeks rest, so a noun does not say the same
    /// thing twice in a month.
    static func resting(in days: [BookDay], before date: Date, within daysBack: Int = 21) -> Set<String> {
        let floor = date.addingTimeInterval(-Double(daysBack) * 86_400)
        var ids = Set<String>()
        for day in days where day.date >= floor && day.date < date {
            for page in day.pages where page.type == .bookOfYou {
                for tag in page.tags where tag.hasPrefix(tagPrefix) { ids.insert(String(tag.dropFirst(tagPrefix.count))) }
            }
        }
        return ids
    }

    /// "yyyy-MM-dd" for the braid's day: its own id when it is one, else its date.
    static func dateKey(for day: BookDay) -> String {
        let id = day.id
        if id.count == 10, id.dropFirst(4).first == "-", id.dropFirst(7).first == "-", id.prefix(4).allSatisfy(\.isNumber) {
            return id
        }
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
}

extension WonderBraid {
    /// Authored lines: id | nouns | needs | line. Mirrors scripts/braid_wonder/lines.json (the Mac lab reads that
    /// file); WonderBraidTests fails if the two drift.
    static let rows: [String] = [
        "w000a|kettle,kettles||The kettle was in the middle of a sentence, and nobody had told it how the sentence ended.",
        "w000b|kettle,kettles||The kettle had boiled for people for eleven years and had never once been asked what it thought.",
        "w001a|egg,eggs||The egg had been eyeing the bin all week.",
        "w001b|egg,eggs||The last egg had heard the others talk about the floor, and had decided to see for itself.",
        "w002a|dog,dogs,puppy||The dog had promised the stick it would fit, and the stick had believed him.",
        "w002b|dog,dogs,puppy||The dog kept a list in his head of everyone who had ever left, and in his opinion every one of them was coming back.",
        "w003a|cat,cats,kitten||The cat sat on the exact spot where the sun was going to be, and the sun, being polite, came.",
        "w003b|cat,cats,kitten||The cat had been guarding the doorway for no one in particular, which is the hardest kind of guarding.",
        "w004a|coffee||The coffee gave up its heat a degree at a time, like a guest leaving a party who doesn't want to make a fuss.",
        "w004b|coffee||The coffee went cold out of tact; it could see you were busy.",
        "w005a|tea,teabag||The tea went the colour of the afternoon and stayed there.",
        "w005b|tea,teabag||The teabag had opinions about being squeezed and kept them in the cup.",
        "w006a|toast||The toast popped up looking like something that had thought it over all night.",
        "w006b|toast||The toast landed butter-side up, because it knew who was watching.",
        "w007a|porridge||The porridge pan had decided to forgive you, but only if you said sorry to the spoon first.",
        "w007b|porridge||The porridge bubbled in a language only the wooden spoon spoke, and the spoon wasn't telling.",
        "w008a|bread,loaf||The loaf had been waiting all week to be the good news.",
        "w008b|bread,loaf||The bread kept its crust hard so that nobody would ask what it was like inside.",
        "w009a|soup||The soup simmered over a thought it hadn't decided to have yet.",
        "w009b|soup||For one spoonful the soup tasted like the kitchen it was remembering.",
        "w010a|milk||The milk knew the date on its side was only a suggestion, and was thinking hard about it.",
        "w010b|milk||The milk went round the cup once, like someone changing their mind.",
        "w011a|mug,cup||The mug had a chip on its rim that it kept like a medal.",
        "w011b|mug,cup||The cup held onto the warmth after you'd gone, in case you came back for it.",
        "w012a|pan,pans||The pan had a burn on its bottom in the shape of a country nobody had named yet.",
        "w012b|pan,pans||The pan hung on its hook and held a grudge against the whole cooker.",
        "w013a|fridge,freezer||The fridge hummed one long note it had been holding since winter.",
        "w013b|fridge,freezer||The fridge light came on for you and went out the moment you looked away, to find out what that was like.",
        "w014a|door,doors||The door had a way of staying nearly closed that made everyone in the house lower their voice.",
        "w014b|door,doors||The door knew everyone's footsteps and hadn't decided yet about yours.",
        "w015a|key,keys||The keys sat on the hook counting themselves, one short, as they did every night.",
        "w015b|key,keys||The key had been lost twice and now went to the same pocket every time, out of spite.",
        "w016a|window,windows||The window kept a small piece of every morning on its glass until somebody wiped it away.",
        "w016b|window,windows||The window liked the view and thought very little of the curtains.",
        "w017a|stairs,stair,staircase||The third stair had said one word in the night and refused to say it again.",
        "w017b|stairs,stair,staircase||The stairs went up one more step than they came down, and nobody had ever mentioned it.",
        "w018a|bus,buses||The bus took the corner as if it had been asked a hard question.",
        "w018b|bus,buses||The bus knew everyone's stop and was too polite to mention the ones they kept missing.",
        "w019a|train,trains,tram||The train went through the dark with all its windows lit, like a long sentence nobody was reading aloud.",
        "w019b|train,trains,tram||The train had been somewhere else all day and was slightly proud of it.",
        "w020a|car,cars||The car knew the way home so well that it was a little offended when you used the map.",
        "w020b|car,cars||The car warmed up slowly, and in that time it told the engine everything.",
        "w021a|bike,bicycle||The bike leaned on the wall as if it had come from a much longer ride.",
        "w021b|bike,bicycle||The bike's bell wanted very badly to be rung at a dog.",
        "w022a|rain,raining,rained||The rain was only checking that the glass still knew its name.",
        "w022b|rain,raining,rained||The rain had come a long way to tell the roof one small thing, and it said it over and over.",
        "w023a|wind,windy,breeze||The wind went through the coats on the hooks and asked each one a question.",
        "w023b|wind,windy,breeze||The wind tried every door on the street and found them all in the middle of something.",
        "w024a|snow,snowed||The snow covered the garden's mistakes first.",
        "w024b|snow,snowed||The snow stayed quiet on purpose, to hear what the street sounded like without anyone's help.",
        "w025a|sun,sunlight,sunshine,sunny||The sunlight took the long way across the kitchen, stopping at everything it liked.",
        "w025b|sun,sunlight,sunshine,sunny||The sun came in and lay on the floor as if it had a right to.",
        "w026a|moon||The moon kept its one good side to the house and hoped nobody asked about the other.",
        "w026b|moon||The moon looked in at the window the way it always did, to see if the house had changed its mind about anything.",
        "w027a|tree,trees||The tree had stood there so long that it considered the street a rumour.",
        "w027b|tree,trees||The tree held its leaves out like a hand that hadn't decided what to ask for.",
        "w028a|leaf,leaves||The leaves came down in the order they had agreed on, and nobody fell early.",
        "w028b|leaf,leaves||The leaves went along the pavement in a small rush, arguing about which way was home.",
        "w029a|garden,lawn,hedge||The garden was doing a great deal when nobody was looking, and stopped the moment you did.",
        "w029b|garden,lawn,hedge||The garden kept its own hours, and none of them were yours.",
        "w030a|pigeon,pigeons,bird,birds,crow,robin,seagull,gull||The pigeon, who had never once waved back, gave a very small bow.",
        "w030b|pigeon,pigeons,bird,birds,crow,robin,seagull,gull||The bird sat on the wire and told the street exactly what it thought, in one note.",
        "w031a|phone,phones||The phone lay face-down on the table, listening to the room with the one ear it had.",
        "w031b|phone,phones||The phone lit up for no one and went dark again, embarrassed.",
        "w032a|laptop,computer,screen||The laptop fan sighed like someone being asked for one more thing.",
        "w032b|laptop,computer,screen||The screen kept the shape of the last page you'd read, in case you wanted it back.",
        "w033a|clock,watch||The clock was four minutes fast out of nerves, and would hear no argument.",
        "w033b|clock,watch||The watch kept going on a wrist the way a very small animal keeps going.",
        "w034a|glasses,spectacles||The glasses stayed on and kept watch, so that the person under them could finally stop.",
        "w034b|glasses,spectacles||The glasses had seen everything you'd read this year and were keeping very quiet about it.",
        "w035a|shoes,shoe,boots,trainers||The shoes by the door stood in a nervous half-circle, waiting to be told where they were going.",
        "w035b|shoes,shoe,boots,trainers||The left shoe had gone one place further than the right all week, and the right was sore about it.",
        "w036a|coat,jacket,jumper,cardigan||The coat held the shape of your shoulders for a while after you took it off, in case of questions.",
        "w036b|coat,jacket,jumper,cardigan||The coat on the hook kept one pocket empty on purpose, for the day it was needed.",
        "w037a|umbrella||The umbrella opened with the look of something that had been proved right.",
        "w037b|umbrella||The umbrella had no idea it was the only thing between you and the whole sky, and it was better off.",
        "w038a|scarf,hat,gloves||The scarf had long ago given up on being a straight line.",
        "w038b|scarf,hat,gloves||The hat knew exactly what you looked like at your worst and had agreed to cover it.",
        "w039a|bed,bedroom,duvet||The bed kept the dent of the night before, as if it were holding your place in a long queue.",
        "w039b|bed,bedroom,duvet||The bed waited all day with its corner turned down, like an open door.",
        "w040a|pillow,pillows||The pillow kept everything that was ever said into it and had never once repeated any of it.",
        "w040b|pillow,pillows||The pillow had two sides and kept the cool one for later.",
        "w041a|sofa,couch,armchair,chair,chairs||The sofa took the whole of your weight and said nothing, which is what it was for.",
        "w041b|sofa,couch,armchair,chair,chairs||The empty chair kept its arms slightly open in case anyone changed their mind.",
        "w042a|table,desk||The table bore the ring of every cup it had ever forgiven.",
        "w042b|table,desk||The table stood on three legs and one decision.",
        "w043a|lamp,lamps,lights||The lamp made a small round room inside the larger room and stayed in it.",
        "w043b|lamp,lamps,lights||The light in the hall came on one second late, as though it had to be told twice.",
        "w044a|candle,candles||The candle burned down by hours and did not once complain about the hours.",
        "w044b|candle,candles||The flame leaned toward whoever was talking.",
        "w045a|book,books,novel||The book lay open at the page it had been told to keep.",
        "w045b|book,books,novel||The book had a spine that remembered every place it had been bent.",
        "w046a|pen,pencil,notebook,diary,journal||The pen had one sentence left in it and was saving it.",
        "w046b|pen,pencil,notebook,diary,journal||The notebook lay shut on the table, being very careful not to know anything yet.",
        "w047a|letter,letters,envelope,postcard,post||The letter lay face-down on the mat, thinking about being read.",
        "w047b|letter,letters,envelope,postcard,post||The envelope was sealed so tightly that it was holding its breath.",
        "w048a|mirror||The mirror was always the last to know.",
        "w048b|mirror||The mirror kept its best angle for whoever wasn't looking.",
        "w049a|bath,shower||The bath filled slowly, listening to itself fill.",
        "w049b|bath,shower||The shower sang one note until the water was hot, and then fell silent out of respect.",
        "w050a|washing,laundry,shirts,clothes||The washing went round and round in the machine, telling itself it was a tide.",
        "w050b|washing,laundry,shirts,clothes||The shirts hung on the line with their arms out, practising.",
        "w051a|dishes,plates,washing-up,sink||The dishes stacked up in the sink and held a small, damp parliament.",
        "w051b|dishes,plates,washing-up,sink||The plates leaned on each other in the rack the way people do at the end of a long evening.",
        "w052a|bin,rubbish||The bin took everything in and kept a poker face about all of it.",
        "w052b|bin,rubbish||The bin was as full as it could be and had one more thing in it than that.",
        "w053a|hoover,vacuum,broom,sweeping||The hoover went round the room roaring at what it found, and was always disappointed in the dust.",
        "w053b|hoover,vacuum,broom,sweeping||The broom stood in its corner with the posture of something that had once been told it could fly.",
        "w054a|plant,plants,flowers,flower,roses,herbs||The plant on the sill leaned toward the window as though the window had said something.",
        "w054b|plant,plants,flowers,flower,roses,herbs||The flowers in the jar had stopped being cut flowers and were just flowers now, and held their heads like it.",
        "w055a|music,song,songs,radio,playlist||The song ended, and the room kept the shape of it a moment longer.",
        "w055b|music,song,songs,radio,playlist||The radio talked low to itself in the kitchen, in a voice that knew all the old songs.",
        "w056a|shop,shops,supermarket,market,store||The supermarket hummed its one bright note over every aisle, and nobody in it looked up.",
        "w056b|shop,shops,supermarket,market,store||The shop bell rang for you as though it had been saving it.",
        "w057a|bag,bags,rucksack,backpack||The bag held more than it showed and less than it promised.",
        "w057b|bag,bags,rucksack,backpack||The bag sat by the door, already thinking about the journey.",
        "w058a|ticket,tickets||The ticket in the pocket was soft at the corners from waiting.",
        "w058b|ticket,tickets||The ticket had a time on it and meant it.",
        "w059a|sandwich,sandwiches||The sandwich was cut in half, and each half missed the other.",
        "w059b|sandwich,sandwiches||The sandwich held together out of loyalty.",
        "w060a|cake,biscuit,biscuits,cookies||The cake sat under its cloth and knew exactly how it would be remembered.",
        "w060b|cake,biscuit,biscuits,cookies||The biscuit tin rattled once, to say it was still a tin of biscuits and not a tin of anything else.",
        "w061a|apple,apples,orange,pear,banana,fruit||The apple was red on one side as a matter of principle.",
        "w061b|apple,apples,orange,pear,banana,fruit||The fruit bowl sat in the middle of the table, pretending not to be waiting for anyone.",
        "w062a|dinner,supper||The dinner went on the table in the order of its feelings.",
        "w062b|dinner,supper||The pot on the cooker kept the last of the dinner warm for a second helping that might still come.",
        "w063a|river,stream,canal||The river had somewhere to be and said so quietly all day.",
        "w063b|river,stream,canal||The river carried the sky along without ever once dropping it.",
        "w064a|road,street,pavement,lane||The road went on ahead of you with the air of knowing the way.",
        "w064b|road,street,pavement,lane||The pavement kept the day's footsteps in its cracks and gave none of them away.",
        "w065a|sea,beach,shore,waves||The sea took everything in and kept the shape of none of it.",
        "w065b|sea,beach,shore,waves||The waves came up the beach to ask the same question and went back for the answer.",
        "w066a|wall,fence,gate||The gate leaned on its post like someone who'd been told the news.",
        "w066b|wall,fence,gate||The wall had held up its end of things for a hundred years and wanted it noted.",
        "w067a|bench,park||The bench had been waiting for the right person to sit down and had decided that anyone would do.",
        "w067b|bench,park||The park kept its quiet in the middle, where the grass was longest.",
        "w068a|cloud,clouds,sky||The cloud over the roofs had lost its way and was too proud to ask.",
        "w068b|cloud,clouds,sky||The sky was the colour of the inside of a shell and did not mean anything by it.",
        "w069a|stick,sticks||The stick had never wanted to go through the gate and was not about to start.",
        "w069b|stick,sticks||The stick lay in the grass, certain it was a sword.",
        "w070a|spoon,spoons,fork,knife,cutlery||The spoon in the drawer had stirred more secrets than any priest.",
        "w070b|spoon,spoons,fork,knife,cutlery||The knives lay in their tray like a row of people who had agreed not to talk.",
        "w071a|rug,carpet,floor,tiles||The rug had been walked across so often it had stopped minding and started listening.",
        "w071b|rug,carpet,floor,tiles||The floor kept every footstep it had ever been given.",
        "w072a|stove,cooker,oven,hob||The oven ticked as it cooled, counting the whole evening back to nothing.",
        "w072b|stove,cooker,oven,hob||The cooker had a ring that came on slowly, like a thought.",
        "w073a|washing machine,dryer,machine||The machine ended its song with a small, satisfied click, like a person finishing a hard sum.",
        "w073b|washing machine,dryer,machine||The dryer kept the warmth of a day that had gone somewhere else.",
        "w900a|lunch||The lunch was eaten in the time it takes a clock to forgive you.",
        "w900b|lunch||The sandwich held together out of loyalty, which is more than can be said for the afternoon.",
        "w901a|breakfast||The breakfast table was set for a better day than the one that came.",
        "w901b|breakfast||The breakfast things sat out until noon, like guests who hadn't been told it was over.",
        "x000a|fog,mist,foggy||The fog had come in to look for something and was too polite to say what.",
        "x000b|fog,mist,foggy||The fog sat on the road and let the cars be sorry first.",
        "x001a|storm,thunder,lightning||The thunder rolled around the sky like furniture being moved in the flat upstairs.",
        "x001b|storm,thunder,lightning||The storm made a great deal of noise about a very small decision.",
        "x002a|frost,ice,icy,frozen||The frost wrote on the windscreen in a hand nobody could read, and was proud of it.",
        "x002b|frost,ice,icy,frozen||The ice on the puddle kept the shape of the sky it had been given.",
        "x003a|morning,mornings||The morning came in on tiptoe and turned the radio on by accident.",
        "x003b|morning,mornings||The morning had been folded very small and put in the day's top pocket.",
        "x004a|night,midnight,bedtime||The night went round the house turning things over, checking they were all still there.",
        "x004b|night,midnight,bedtime||The night arrived in the order the lamps asked for it.",
        "x005a|autumn,october||October had been left on all the pavements, and was beginning to be trodden in.",
        "x005b|autumn,october||The autumn smelled of the inside of a coat that had been somewhere good.",
        "x006a|onion,onions,garlic||The onions made their case and everyone in the kitchen wept with them.",
        "x006b|onion,onions,garlic||The garlic went into the pan with the confidence of something that had never been to a funeral.",
        "x007a|pasta,spaghetti,rice,noodles||The pasta turned in the pot slowly, as if reading the water.",
        "x007b|pasta,spaghetti,rice,noodles||The rice swelled until it had opinions.",
        "x008a|pizza,chips,burger,takeaway||The pizza box sat on the table with its lid up, like a mouth that has just said something.",
        "x008b|pizza,chips,burger,takeaway||The chips went cold at exactly the speed of a good conversation.",
        "x009a|chocolate,sweets,sweet,candy||The chocolate broke into its squares along the lines it had been practising.",
        "x009b|chocolate,sweets,sweet,candy||The sweet sat in the bowl, certain it was the one.",
        "x010a|wine,beer,cider,pint,whisky||The wine sat in the glass thinking about being grapes.",
        "x010b|wine,beer,cider,pint,whisky||The pint went down by the ordinary amount and was flat by the end of the story.",
        "x011a|cheese,butter,jam,honey,marmalade||The butter softened slowly, like someone being told a kind thing.",
        "x011b|cheese,butter,jam,honey,marmalade||The jam had been waiting at the back of the cupboard for exactly this slice of toast.",
        "x012a|salad,vegetables,carrots,potatoes,peas,beans||The potatoes sat in their sack and gossiped about the weather underground.",
        "x012b|salad,vegetables,carrots,potatoes,peas,beans||The carrots had decided to be orange about it.",
        "x013a|jar,bottle,bottles,tin,tins||The jar would not open for anyone, and was not sorry.",
        "x013b|jar,bottle,bottles,tin,tins||The bottle held on to the last inch of itself with great dignity.",
        "x014a|basket,bucket,box,boxes,parcel,package||The parcel on the step had come a very long way to be left with nobody in.",
        "x014b|basket,bucket,box,boxes,parcel,package||The box held the shape of what had been in it for a week after.",
        "x015a|boiler,radiator,heating||The boiler cleared its throat before every thought.",
        "x015b|boiler,radiator,heating||The radiator ticked as it warmed, like a small animal deciding to trust the room.",
        "x016a|kitchen||The kitchen kept its own hours and a drawer for everything it had forgiven.",
        "x016b|kitchen||The kitchen smelled of three different days at once and was fond of all of them.",
        "x017a|hallway,hall,landing,corridor||The hall light came on for the shoes and nobody else.",
        "x017b|hallway,hall,landing,corridor||The hallway listened to everything that was said in it and kept the good bits.",
        "x018a|bathroom,toilet,towel,towels||The bathroom tap held one drop back, for later.",
        "x018b|bathroom,toilet,towel,towels||The towel on the rail had been warm once and remembered it.",
        "x019a|cupboard,drawer,drawers,shelf,shelves,attic,cellar||The drawer held three batteries, a key and a promise, and none of them worked.",
        "x019b|cupboard,drawer,drawers,shelf,shelves,attic,cellar||The cupboard door swung open a hand's width, as if the cupboard had just thought of something.",
        "x020a|curtain,curtains,blind,blinds||The curtains held the dark back with one hand.",
        "x020b|curtain,curtains,blind,blinds||The curtain moved once, though there was no draught to blame it on.",
        "x021a|roof,skylight,chimney,gutter,gutters||The gutter carried the rain away like a rumour it didn't believe.",
        "x021b|roof,skylight,chimney,gutter,gutters||The chimney stood in the sky with its hands in its pockets.",
        "x022a|smell,smelled,smells,smelt||The smell went through the flat first and told the rooms what to expect.",
        "x022b|smell,smelled,smells,smelt||The smell had already been in every room by the time you noticed it.",
        "x023a|noise,sound,sounds,creak,creaked,creaking||The noise from the next room stopped as soon as it was listened for.",
        "x023b|noise,sound,sounds,creak,creaked,creaking||The creak in the floor said the same word it always said, a little louder for company.",
        "x024a|dust,dusty||The dust settled on the shelf the way a cat settles, after much deliberation.",
        "x024b|dust,dusty||The dust kept a careful record of everything that had not been moved.",
        "x025a|spider,spiders,web||The spider had put a great deal of thought into the corner and wanted it noted.",
        "x025b|spider,spiders,web||The web caught the morning and held it up to the light for approval.",
        "x026a|fly,flies,bee,bees,wasp,moth,insect,butterfly||The moth went round the lamp like someone trying to remember a name.",
        "x026b|fly,flies,bee,bees,wasp,moth,insect,butterfly||The bee crossed the kitchen as though it had an appointment.",
        "x027a|squirrel,squirrels,fox,hedgehog,badger,rabbit,mouse,mice,rat||The fox crossed the road as if the road had been laid for him.",
        "x027b|squirrel,squirrels,fox,hedgehog,badger,rabbit,mouse,mice,rat||The squirrel ran along the fence with its news and could not be stopped.",
        "x028a|duck,ducks,swan,swans,goose,geese||The ducks went by in a line, each one convinced the others were following.",
        "x028b|duck,ducks,swan,swans,goose,geese||The swan held the whole pond up on its back and looked cross about it.",
        "x029a|horse,horses,cow,cows,sheep,lamb,pony||The sheep looked up at the same moment, as if they had been told something.",
        "x029b|horse,horses,cow,cows,sheep,lamb,pony||The horse stood in the field holding very still, to see if the field would move first.",
        "x030a|heron||The heron stood in the shallows like it had been asked to wait and was determined to do it properly.",
        "x030b|heron||The heron kept one leg in reserve.",
        "x031a|snail,slug,worm,worms||The snail crossed the path with the whole of its house and none of its doubts.",
        "x031b|snail,slug,worm,worms||The worm came up after the rain to see what all the noise had been.",
        "x032a|lift,elevator,escalator||The lift thought about the ground floor for a long time before agreeing to it.",
        "x032b|lift,elevator,escalator||The escalator took everyone up at exactly the speed of their own mistakes.",
        "x033a|taxi,cab,uber||The taxi waited at the kerb with its light on, like a very patient idea.",
        "x033b|taxi,cab,uber||The cab knew the city by its corners and its grudges.",
        "x034a|plane,airport,flight,ferry,boat,ship||The plane drew a white line across the sky and then thought better of it.",
        "x034b|plane,airport,flight,ferry,boat,ship||The boat knocked at the harbour wall all night like a dog that wanted letting in.",
        "x035a|platform,station,timetable||The platform waited for the train the way a dog waits for a name.",
        "x035b|platform,station,timetable||The timetable on the wall had a plan and was not about to share it.",
        "x036a|traffic,roundabout,lights,junction||The traffic lights changed their minds three times in your favour and once against.",
        "x036b|traffic,roundabout,lights,junction||The roundabout kept everyone going round in case they remembered what they'd come for.",
        "x037a|church,cathedral,bell,bells,steeple||The church bell struck the hour and then a second time, very quietly, for the one it had missed.",
        "x037b|church,cathedral,bell,bells,steeple||The steeple held a piece of the sky in place.",
        "x038a|pub,cafe,bar,restaurant,diner||The pub had kept its warmth through the afternoon for exactly this.",
        "x038b|pub,cafe,bar,restaurant,diner||The cafe window had steamed up to give everyone inside a little privacy.",
        "x039a|school,classroom,playground,lesson||The playground was quiet in the way a bell is quiet before it goes.",
        "x039b|school,classroom,playground,lesson||The classroom clock had been watching the same afternoon since September.",
        "x040a|library||The library hummed with all the sentences it was not allowed to say aloud.",
        "x040b|library||The library kept every book's secret in alphabetical order.",
        "x041a|office,meeting,emails,email,printer||The printer thought about each page as though it were signing it.",
        "x041b|office,meeting,emails,email,printer||The meeting room had a table too big for what was said around it.",
        "x042a|bank,post office,queue||The queue moved forward one person at a time, like a thought being slowly agreed upon.",
        "x042b|bank,post office,queue||The post office smelled of string, paper and other people's good news.",
        "x043a|hospital,ward,nurse,doctor||The corridor went on a little longer than the plan said, out of tact.",
        "x044a|charger,battery,wifi,signal||The signal came and went like a small shy animal at the edge of the room.",
        "x044b|charger,battery,wifi,signal||The charger lay on the floor with its one hand out.",
        "x045a|headphones,earbuds,podcast||The headphones kept the whole street out and one song in.",
        "x045b|headphones,earbuds,podcast||The podcast went on talking in the kitchen to nobody, and was happy.",
        "x046a|photo,photos,camera,photograph,picture,pictures,painting||The photograph kept the afternoon exactly as it had been and was a little tired of it.",
        "x046b|photo,photos,camera,photograph,picture,pictures,painting||The picture on the wall had been looking at the same view for years and had opinions.",
        "x047a|list,lists,note,notes,receipt,calendar,diary||The list on the fridge had one item crossed out so hard that it showed through.",
        "x047b|list,lists,note,notes,receipt,calendar,diary||The receipt in the pocket remembered the whole afternoon and could not stop itself.",
        "x048a|map,maps,compass||The map had never once agreed with the road.",
        "x048b|map,maps,compass||The map was folded wrong along a line that had been right for years.",
        "x049a|coin,coins,money,change,purse,wallet||The coin had been to a great many hands and brought back nothing but the weather.",
        "x049b|coin,coins,money,change,purse,wallet||The wallet held the whole week flat and folded.",
        "x050a|button,buttons,zip,thread,needle,sewing||The button hung by one thread and was very calm about it.",
        "x050b|button,buttons,zip,thread,needle,sewing||The needle went in and out of the cloth like a very small, well-meaning argument.",
        "x051a|paint,brush,brushes,ladder,hammer,tools,screwdriver,drill||The ladder leaned against the wall as if it had been told a secret and was holding it up for you to see.",
        "x051b|paint,brush,brushes,ladder,hammer,tools,screwdriver,drill||The hammer lay where it was left and dreamed of being exactly the right size.",
        "x052a|torch,flashlight,matches||The torch made a small yellow room in the dark and invited the moths in.",
        "x052b|torch,flashlight,matches||The match flared once, to show it could.",
        "x053a|string,rope,ribbon,tape,glue||The string had been tied in a knot nobody could remember agreeing to.",
        "x053b|string,rope,ribbon,tape,glue||The tape peeled up at the corner like a small, sticky question.",
        "x054a|balloon,toy,toys,ball,doll,lego,puzzle||The balloon lowered itself a little each day, out of manners.",
        "x054b|balloon,toy,toys,ball,doll,lego,puzzle||The puzzle was missing one piece and had stopped mentioning it.",
        "x055a|piano,guitar,violin,drum,drums,harmonica,flute||The piano in the corner held every song it had been taught and played none of them unasked.",
        "x055b|piano,guitar,violin,drum,drums,harmonica,flute||The guitar leaned in its case with the look of something that had just been told a joke.",
        "x056a|sock,socks,jeans,trousers,pyjamas,dress,shirt,tights||The odd sock had been looking for its other half so long it had forgotten what it looked like.",
        "x056b|sock,socks,jeans,trousers,pyjamas,dress,shirt,tights||The pyjamas were warm from the airing cupboard and ready to be told everything.",
        "x057a|boots,wellies,slippers,sandals||The slippers waited by the bed with their mouths open, ready for the day's news.",
        "x057b|boots,wellies,slippers,sandals||The wellies stood in the porch with the mud of a whole field in them.",
        "x058a|hair,brush,comb,razor,toothbrush,soap||The toothbrush stood to attention in the mug and awaited the day's orders.",
        "x058b|hair,brush,comb,razor,toothbrush,soap||The soap had been used so long that it was mostly an idea.",
        "x059a|sleep,asleep,nap,dream,dreams,dreamt,snoring||The sleep came in sideways, like a cat through a half-open door.",
        "x059b|sleep,asleep,nap,dream,dreams,dreamt,snoring||The dream waited behind the eyelids until the room was properly dark.",
        "x060a|tired,yawn,yawned,yawning||The tiredness sat down in the chair behind you and asked nothing.",
        "x061a|laugh,laughed,laughing,giggle,joke||The laugh got out before the rest of the sentence and had to be waited for.",
        "x061b|laugh,laughed,laughing,giggle,joke||The joke sat in the room afterwards, pleased with itself and a little embarrassed.",
        "x062a|tea towel,apron,oven glove,gloves||The oven glove held on to the heat of everything it had ever touched.",
        "x062b|tea towel,apron,oven glove,gloves||The tea towel had dried the world and was still damp about it.",
        "x063a|stone,stones,pebble,rock,rocks,shell,shells||The pebble in the pocket had been a mountain once and did not mention it.",
        "x063b|stone,stones,pebble,rock,rocks,shell,shells||The shell kept the sea in the back of its mind and hummed it when asked.",
        "x064a|flower,bouquet,daffodils,tulips,poppy,sunflower||The tulips leaned out of the vase to see who was talking.",
        "x064b|flower,bouquet,daffodils,tulips,poppy,sunflower||The sunflower turned its face to the window and then to you, on principle.",
        "x065a|grass,field,fields,hill,hills,woods,forest,wood,path||The path ran on ahead and waited at every bend, pretending to look at something else.",
        "x065b|grass,field,fields,hill,hills,woods,forest,wood,path||The hill took the whole sky on its shoulders and went on being a hill.",
        "x066a|bridge,tunnel,underpass,steps||The bridge held the river up to the light and let it carry on.",
        "x066b|bridge,tunnel,underpass,steps||The tunnel kept a little of last night in the middle, to be sure.",
        "x067a|smoke,fire,fireplace,bonfire,embers,ash||The fire talked to itself in the grate, softly, in a language of small collapses.",
        "x067b|smoke,fire,fireplace,bonfire,embers,ash||The embers kept the shape of the log for as long as they could.",
        "x068a|water,puddle,puddles,drip,dripping,tap||The puddle had the sky in it and was a little proud of the arrangement.",
        "x068b|water,puddle,puddles,drip,dripping,tap||The tap dripped on at its own count, patient as a priest.",
        "x069a|shadow,shadows||The shadow lay along the floor and waited for the lamp to change its mind.",
        "x069b|shadow,shadows||The shadow of the chair stretched out and tried the door.",
        "x070a|silence,quiet,stillness||The quiet filled up the room like water finding its level.",
        "x070b|silence,quiet,stillness||The silence was the kind that has been left on purpose.",
        "s000|dog,dogs,puppy|stick|The dog had promised the stick it would fit, and the stick had believed him.",
        "s001|dog,dogs,puppy|wind,windy,walk,walked|The dog walked into the wind with his ears doing all the talking.",
        "s002|dog,dogs,puppy|park,field,fields,woods|The dog ran the whole park twice, to make sure it was still all there.",
        "s003|cat,cats,kitten|laptop,keyboard,meeting|The cat lay across the keyboard and typed the only sentence she'd ever meant.",
        "s004|cat,cats,kitten|window,windowsill,sill|The cat watched the street from the sill with the interest of a landlord.",
        "s005|egg,eggs|dropped,rolled,floor|The egg had been eyeing the bin all week.",
        "s006|egg,eggs|breakfast,boiled,fried,scrambled|The egg sat in its cup like a small bald king waiting for the knock.",
        "s007|bus,buses|missed,late,waited|The bus pulled away from the stop with the look of someone leaving a party at exactly the wrong moment.",
        "s008|train,trains,tram|window,windows|The train carried the window along and let the fields come and go in it like thoughts.",
        "s009|rain,raining,rained|umbrella,coat,wet|The rain found the one gap in the coat and was thorough about it.",
        "s010|coffee|cold,cooled|The coffee went cold out of tact; it could see you were busy.",
        "s011|coffee|morning,first,hot|The coffee steamed up in the cup like a tiny, hopeful weather system.",
        "s012|tea|spilled,spill,spilt|The tea ran across the table to see how far it could get, and got as far as the letter.",
        "s013|sofa,couch|asleep,slept,nap|The sofa took the whole of her weight and said nothing, which is what it was for.",
        "s014|glasses,spectacles|asleep,slept,sofa|The glasses stayed on and kept watch, so that the person under them could finally stop.",
        "s015|phone,phones|died,dead,battery|The phone went dark in the middle of its own sentence, and the room got larger.",
        "s016|phone,phones|rang,ringing,call,called|The phone rang the way it always did, as if it were bringing news of a death or an offer.",
        "s017|key,keys|lost,found,pocket,drawer|The key had been lost twice and now went to the same pocket every time, out of spite.",
        "s018|key,keys|open,opens,doesn't,didn't|The key was cut for a lock that had been taken down years ago, and still hoped.",
        "s019|candle,candles|lit,light,burning|The flame leaned toward whoever was talking.",
        "s020|book,books|library,read,reading|The book lay open at the page it had been told to keep.",
        "s021|bread,loaf,toast|stale,burnt,burned|The bread had gone hard to protect what was left of it.",
        "s022|bread,loaf|baked,made,dough|The dough rose slowly, like a rumour in a small town.",
        "s023|walk,walked,walking|river,canal,stream|The river walked along beside you and kept up its end of the conversation.",
        "s024|walk,walked,walking|home,long way,dark|The road home was longer than the road out, by the exact length of the day.",
        "s025|mirror|crack,cracked,broken|The mirror held the crack like a secret it had agreed not to repeat.",
        "s026|mirror|street,carrying,carried|The mirror carried the street along with it and was careful not to spill any.",
        "s027|tree,trees|orange,gold,yellow,red,autumn|The tree had gone orange all at once, because it had been told, and it was keeping very quiet about who told it.",
        "s028|leaf,leaves|kicked,kick,everywhere|The leaves rose when kicked and settled again in a slightly better arrangement.",
        "s029|snow,snowed|gloves,forecast,cold|The snow was in the forecast and the forecast was feeling smug.",
        "s030|moon|bright,garden,stairs|The moon came down the stairs of the garden one white step at a time.",
        "s031|sun,sunlight,sunshine|floor,kitchen,stood|The sunlight lay on the floor at three o'clock like a rug that someone had paid a great deal for.",
        "s032|fridge|hum,humming,noise,night|The fridge hummed the same low note the whole house had been tuned to.",
        "s033|washing machine,machine|finished,phone,call|The washing machine finished mid-sentence of the day and waited to be forgiven.",
        "s034|heron|river,shallows|The heron stood in the shallows like it had been asked to wait and was determined to do it properly.",
        "s035|pigeon,pigeons|shop|The pigeon walked in as if the shop had been built round it, looked at everything, and walked out.",
        "s036|pigeon,pigeons|waved,wave,waving|The pigeon, who had never once waved back, gave a very small bow.",
        "s037|cake,biscuits,biscuit|small,occasion|The cake was exactly as big as the occasion and not one crumb bigger.",
        "s038|plant,plants|leaning,leaned,window,sill|The plant leaned away from you with great tact, toward the thing it actually wanted.",
        "s039|cooked,cooking,cook|onions,smelled,flat|The smell of onions went through the flat and told every room it was staying for supper.",
        "s040|letter,post|send,meant,spilled|The letter lay on the table, damp at one corner, thinking again about what it had been going to say.",
        "s041|shop,shops|bell,counter|The shop bell rang for you as though it had been saving it.",
        "s042|hospital,ward|waited,waiting,asleep|The corridor went on a little longer than the plan said, out of tact.",
        "s043|tiles,ceiling|counted,counting|The ceiling tiles held still to be counted, and kept their own total.",
        "s044|boiler,radiator|ticked,tick,ticking|The boiler ticked in the dark like a very small clock that has lost its owner.",
    ]
}
