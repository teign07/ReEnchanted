import Foundation

/// A set of calendar days, stored as a bitmap.
///
/// Every statistic the grimoire needs — how many days a thing happened, how
/// many days two things happened together, whether one followed the other
/// within a week, whether it returns each spring — reduces to a word operation
/// over one of these. That is what lets the Book compare everything against
/// everything without the cost growing with the archive: a bitmap's size is
/// set by how many *years* it spans, not by how many Pages fell inside it.
///
/// Four years is 1,461 days: 23 `UInt64`s, 184 bytes. Leading and trailing
/// empty words are trimmed, so a feature the reader met over one fortnight
/// costs one word no matter how old their Book is.
struct DayBitset: Equatable, Hashable {
    /// Index of the first stored word. Everything before it is zero.
    private(set) var wordOffset: Int
    /// Invariant: either empty, or both first and last word are non-zero.
    private(set) var words: [UInt64]

    init() {
        wordOffset = 0
        words = []
    }

    init(days: [Int]) {
        self.init()
        for day in days { insert(day) }
    }

    fileprivate init(wordOffset: Int, words: [UInt64]) {
        self.wordOffset = wordOffset
        self.words = words
        normalize()
    }

    // MARK: Reading

    var isEmpty: Bool { words.isEmpty }

    /// How many distinct days are in the set. A sum of popcounts.
    var count: Int {
        var total = 0
        for word in words { total += word.nonzeroBitCount }
        return total
    }

    func contains(_ day: Int) -> Bool {
        guard day >= 0 else { return false }
        let word = day >> 6
        guard word >= wordOffset, word < wordOffset + words.count else { return false }
        return words[word - wordOffset] & (1 << UInt64(day & 63)) != 0
    }

    var firstDay: Int? {
        for (offset, word) in words.enumerated() where word != 0 {
            return ((wordOffset + offset) << 6) + word.trailingZeroBitCount
        }
        return nil
    }

    var lastDay: Int? {
        for (offset, word) in words.enumerated().reversed() where word != 0 {
            return ((wordOffset + offset) << 6) + (63 - word.leadingZeroBitCount)
        }
        return nil
    }

    /// Every day in the set, ascending.
    var days: [Int] {
        var out: [Int] = []
        out.reserveCapacity(count)
        for (offset, word) in words.enumerated() where word != 0 {
            var remaining = word
            let base = (wordOffset + offset) << 6
            while remaining != 0 {
                out.append(base + remaining.trailingZeroBitCount)
                remaining &= remaining &- 1
            }
        }
        return out
    }

    /// The word at an absolute index, zero where nothing is stored.
    private func word(at index: Int) -> UInt64 {
        let local = index - wordOffset
        guard local >= 0, local < words.count else { return 0 }
        return words[local]
    }

    // MARK: Writing

    mutating func insert(_ day: Int) {
        guard day >= 0 else { return }
        let word = day >> 6
        let bit = UInt64(1) << UInt64(day & 63)
        if words.isEmpty {
            wordOffset = word
            words = [bit]
            return
        }
        if word < wordOffset {
            words.insert(contentsOf: [UInt64](repeating: 0, count: wordOffset - word), at: 0)
            wordOffset = word
        } else if word >= wordOffset + words.count {
            words.append(contentsOf: [UInt64](repeating: 0, count: word - (wordOffset + words.count) + 1))
        }
        words[word - wordOffset] |= bit
    }

    /// Drop empty words from both ends so the invariant holds and the stored
    /// form of a given set of days is always identical.
    private mutating func normalize() {
        var lead = 0
        while lead < words.count && words[lead] == 0 { lead += 1 }
        if lead == words.count {
            wordOffset = 0
            words = []
            return
        }
        var tail = words.count - 1
        while tail > lead && words[tail] == 0 { tail -= 1 }
        if lead > 0 || tail < words.count - 1 {
            words = Array(words[lead...tail])
            wordOffset += lead
        }
    }

    // MARK: Set algebra — the whole statistical core

    func intersection(_ other: DayBitset) -> DayBitset {
        let low = max(wordOffset, other.wordOffset)
        let high = min(wordOffset + words.count, other.wordOffset + other.words.count)
        guard low < high else { return DayBitset() }
        var out = [UInt64](repeating: 0, count: high - low)
        for index in low..<high {
            out[index - low] = word(at: index) & other.word(at: index)
        }
        return DayBitset(wordOffset: low, words: out)
    }

    func union(_ other: DayBitset) -> DayBitset {
        if words.isEmpty { return other }
        if other.words.isEmpty { return self }
        let low = min(wordOffset, other.wordOffset)
        let high = max(wordOffset + words.count, other.wordOffset + other.words.count)
        var out = [UInt64](repeating: 0, count: high - low)
        for index in low..<high {
            out[index - low] = word(at: index) | other.word(at: index)
        }
        return DayBitset(wordOffset: low, words: out)
    }

    func subtracting(_ other: DayBitset) -> DayBitset {
        guard !words.isEmpty else { return self }
        var out = [UInt64](repeating: 0, count: words.count)
        for index in wordOffset..<(wordOffset + words.count) {
            out[index - wordOffset] = word(at: index) & ~other.word(at: index)
        }
        return DayBitset(wordOffset: wordOffset, words: out)
    }

    /// How many days the two sets share. Cheaper than building the
    /// intersection when only the number is wanted.
    func intersectionCount(_ other: DayBitset) -> Int {
        let low = max(wordOffset, other.wordOffset)
        let high = min(wordOffset + words.count, other.wordOffset + other.words.count)
        guard low < high else { return 0 }
        var total = 0
        for index in low..<high {
            total += (word(at: index) & other.word(at: index)).nonzeroBitCount
        }
        return total
    }

    // MARK: Time shapes

    /// The same days moved later by `days`. Sequence costs a bit shift: to ask
    /// "did the outcome land within three days of the condition", shift the
    /// condition forward and intersect.
    func shiftedForward(by days: Int) -> DayBitset {
        guard days != 0 else { return self }
        guard days > 0 else { return DayBitset() }
        guard !words.isEmpty else { return self }
        let wordShift = days >> 6
        let bitShift = days & 63
        if bitShift == 0 {
            return DayBitset(wordOffset: wordOffset + wordShift, words: words)
        }
        var out = [UInt64](repeating: 0, count: words.count + 1)
        for index in 0..<words.count {
            out[index] |= words[index] << UInt64(bitShift)
            out[index + 1] |= words[index] >> UInt64(64 - bitShift)
        }
        return DayBitset(wordOffset: wordOffset + wordShift, words: out)
    }

    /// The same days moved earlier by `days`. Days that would fall before the
    /// reference day drop off the front rather than wrapping.
    func shiftedBackward(by days: Int) -> DayBitset {
        guard days != 0 else { return self }
        guard days > 0, !words.isEmpty else { return DayBitset() }
        let wordShift = days >> 6
        let bitShift = days & 63
        let low = wordOffset - wordShift - 1
        let high = wordOffset + words.count - wordShift
        guard high > low else { return DayBitset() }
        var out = [UInt64](repeating: 0, count: high - low)
        for index in low..<high {
            let lower = word(at: index + wordShift)
            if bitShift == 0 {
                out[index - low] = lower
            } else {
                let upper = word(at: index + wordShift + 1)
                out[index - low] = (lower >> UInt64(bitShift)) | (upper << UInt64(64 - bitShift))
            }
        }
        var result = DayBitset(wordOffset: low, words: out)
        result.dropDaysBeforeTheBeginning()
        return result
    }

    /// Drop whole words that sit entirely before day zero. Word -1 covers days
    /// -64...-1, none of which exist.
    private mutating func dropDaysBeforeTheBeginning() {
        guard wordOffset < 0 else { return }
        let drop = min(-wordOffset, words.count)
        words.removeFirst(drop)
        wordOffset += drop
        normalize()
    }

    /// The days leading up to each day in the set.
    /// `precedingWindow(from: 1, through: 3)` is "the three days before".
    ///
    /// This is the half of sequence that keeps the arithmetic honest. Asking
    /// "did a photograph land in the three days after Wicker asked" by widening
    /// the *condition* would divide the answer by three; walking backwards from
    /// the photograph instead keeps the denominator what it should be — the
    /// number of times Wicker actually asked.
    func precedingWindow(from first: Int, through last: Int) -> DayBitset {
        guard first <= last, last > 0 else { return DayBitset() }
        var out = DayBitset()
        for step in max(1, first)...last {
            out = out.union(shiftedBackward(by: step))
        }
        return out
    }

    /// Every day from `after` to `through` days past each day in the set.
    /// `window(after: 1, through: 3)` is "the three days following".
    func window(after: Int, through: Int) -> DayBitset {
        guard after <= through, through > 0 else { return DayBitset() }
        var out = DayBitset()
        for step in max(1, after)...through {
            out = out.union(shiftedForward(by: step))
        }
        return out
    }

    /// Every day between two bounds. Fills whole words at once rather than
    /// setting 1,460 bits one at a time — this gets built for the early/late
    /// halves on a hot path, so the difference is not academic.
    static func filled(from first: Int, through last: Int) -> DayBitset {
        guard first <= last, last >= 0 else { return DayBitset() }
        let low = max(0, first)
        guard low <= last else { return DayBitset() }
        let firstWord = low >> 6
        let lastWord = last >> 6
        var words = [UInt64](repeating: .max, count: lastWord - firstWord + 1)
        let lowBit = low & 63
        if lowBit > 0 { words[0] &= ~((UInt64(1) << UInt64(lowBit)) &- 1) }
        let highBit = last & 63
        if highBit < 63 { words[words.count - 1] &= (UInt64(1) << UInt64(highBit + 1)) &- 1 }
        return DayBitset(wordOffset: firstWord, words: words)
    }

    /// A set built by asking a question of every day in a range. Used where the
    /// answer really does vary day by day; prefer `filled` for solid ranges.
    static func mask(from first: Int, through last: Int, where predicate: (Int) -> Bool) -> DayBitset {
        guard first <= last else { return DayBitset() }
        var out = DayBitset()
        for day in first...last where predicate(day) { out.insert(day) }
        return out
    }
}

// MARK: - Storage

extension DayBitset: Codable {
    private enum CodingKeys: String, CodingKey {
        case wordOffset = "o"
        case payload = "w"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let offset = try container.decodeIfPresent(Int.self, forKey: .wordOffset) ?? 0
        let payload = try container.decodeIfPresent(Data.self, forKey: .payload) ?? Data()
        var words: [UInt64] = []
        words.reserveCapacity(payload.count / 8)
        var index = payload.startIndex
        while index + 8 <= payload.endIndex {
            var value: UInt64 = 0
            for byte in 0..<8 {
                value |= UInt64(payload[index + byte]) << UInt64(byte * 8)
            }
            words.append(value)
            index += 8
        }
        self.init(wordOffset: offset, words: words)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var payload = Data()
        payload.reserveCapacity(words.count * 8)
        for word in words {
            for byte in 0..<8 {
                payload.append(UInt8(truncatingIfNeeded: word >> UInt64(byte * 8)))
            }
        }
        try container.encode(wordOffset, forKey: .wordOffset)
        try container.encode(payload, forKey: .payload)
    }
}

// MARK: - Days

/// Turns dates into the day numbers a `DayBitset` indexes.
///
/// The reference day is fixed rather than taken from the reader's first Page,
/// so a day always has the same number no matter what else the archive holds.
/// That means nothing ever has to be renumbered, which is the kind of migration
/// that quietly corrupts a four-year-old Book.
enum GrimoireDay {
    /// 1 January 2015, local. Comfortably before any reader's first Page.
    static func reference(_ calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = 2015
        components.month = 1
        components.day = 1
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_420_070_400)
    }

    static func index(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let base = calendar.startOfDay(for: reference(calendar))
        let days = calendar.dateComponents([.day], from: base, to: start).day ?? 0
        return max(0, days)
    }

    static func date(for index: Int, calendar: Calendar = .current) -> Date {
        let base = calendar.startOfDay(for: reference(calendar))
        return calendar.date(byAdding: .day, value: index, to: base) ?? base
    }

    /// Days from 1 January 1970 to 1 January 2015, the day-zero of the index.
    private static let referenceEpochDay = 16_436

    /// The civil date of a day number, by integer arithmetic.
    ///
    /// `Calendar` is correct and far too slow to call once per day per pair —
    /// it was most of a 448ms desk read. Day numbers are a fixed count from a
    /// fixed day, so proleptic Gregorian arithmetic answers exactly the same
    /// question in nanoseconds. Seasons here are Gregorian months by design;
    /// they are already coarse on purpose.
    static func civil(of index: Int) -> (year: Int, month: Int, day: Int) {
        var z = index + referenceEpochDay
        z += 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let year = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shifted = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shifted + 2) / 5 + 1
        let month = shifted + (shifted < 10 ? 3 : -9)
        return (year + (month <= 2 ? 1 : 0), month, day)
    }

    static func year(of index: Int, calendar: Calendar = .current) -> Int {
        civil(of: index).year
    }

    /// 0 winter, 1 spring, 2 summer, 3 autumn. Northern-hemisphere months, kept
    /// deliberately coarse: the Book is noticing that something returns each
    /// spring, not adjudicating the equinox.
    static func season(of index: Int, calendar: Calendar = .current) -> Int {
        switch civil(of: index).month {
        case 3, 4, 5: return 1
        case 6, 7, 8: return 2
        case 9, 10, 11: return 3
        default: return 0
        }
    }
}
