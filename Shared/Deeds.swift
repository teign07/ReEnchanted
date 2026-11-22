import Foundation

// MARK: - The deed chronicle
//
// What the reader has done, read out of the archive: workings they went out
// on and came back from, spells cast, deals made and answered, Neighbours met,
// named and lost, feasts kept. Every deed is dated, points at the Page that
// proves it, and carries the reader's own sentence whole or not at all.
//
// The month told as deeds, and the titles the reader has earned, are built
// from this list and nothing else. No deed is ever inferred from a Page the
// Book wrote by itself: a deed needs the reader's hand on it.

struct Deed: Identifiable, Equatable {
    enum Kind: String, Equatable, CaseIterable {
        case workingReturned
        case spellCast
        case dealAnswered
        case neighbourMet
        case neighbourNamed
        case neighbourGone
        case visitAnswered
        case nameDayKept
        case feastKept
    }

    var id: String { "\(kind.rawValue):\(pageID)" }
    var kind: Kind
    var date: Date
    /// The Page that proves it: the reader's own, or for a Neighbour the
    /// record the reader confirmed.
    var pageID: String
    /// What was done, after "you", in the past tense: "told a tree it was
    /// called Gerald".
    var phrase: String
    /// The reader's own sentence from that Page, whole, when it's short.
    var sentence: String?
    /// The working or spell id, when there was one.
    var working: String?
    var neighbourSlug: String?
    var neighbourKind: NeighbourKind?
}

/// An epithet the reader earned by a particular deed on a particular day.
/// Never a claim about their character: each one says what they did.
struct ReaderTitle: Identifiable, Equatable {
    var id: String
    var title: String
    var earnedAt: Date
    var deedID: String
    /// "You told a tree it was called Gerald, in May 2026."
    var because: String
}

enum DeedChronicle {
    static func deeds(days: [BookDay]) -> [Deed] {
        let pages = Neighbours.allPages(in: days)
        let register = Neighbours.register(days: days)
        let bySlug = Dictionary(register.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        var found: [Deed] = []

        for page in pages {
            if Neighbours.isRecord(page) {
                guard let slug = page.tags.first(where: { $0.hasPrefix("neighbour:") }).map({ String($0.dropFirst(10)) }),
                      let neighbour = bySlug[slug] else { continue }
                let event = page.tags.first(where: { $0.hasPrefix("neighbour-event:") }).map { String($0.dropFirst(16)) }
                let named = neighbour.isEpithet ? nil : neighbour.name
                if event == Neighbours.Event.founded.rawValue, page.id == neighbour.foundingRecordID {
                    let terms = neighbour.working.flatMap { Neighbours.namingWorkings[$0] }
                    let phrase: String
                    let kind: Deed.Kind
                    if let named, let working = neighbour.working, terms != nil {
                        kind = .neighbourNamed
                        phrase = namingPhrase(working: working, name: named)
                    } else {
                        kind = .neighbourMet
                        phrase = "made \(neighbour.name) one of your Neighbours"
                    }
                    found.append(Deed(kind: kind, date: neighbour.foundedAt, pageID: page.id, phrase: phrase,
                                      sentence: neighbour.foundingSentence, working: neighbour.working,
                                      neighbourSlug: slug, neighbourKind: neighbour.kind))
                } else if event == Neighbours.Event.gone.rawValue, neighbour.status == .gone {
                    found.append(Deed(kind: .neighbourGone, date: page.createdAt, pageID: page.id,
                                      phrase: "told me \(neighbour.name) was gone", sentence: nil,
                                      working: neighbour.working, neighbourSlug: slug, neighbourKind: neighbour.kind))
                }
                continue
            }
            guard page.hasReaderContribution else { continue }
            let sentence = Neighbours.quotable(Neighbours.readerText(page))

            if page.type == .spell,
               let spellID = page.tags.first(where: { $0.hasPrefix("spell:") }).map({ String($0.dropFirst(6)) }) {
                // A spell that named a Neighbour is told once, as the naming.
                if register.contains(where: { $0.foundingPageID == page.id && !$0.isEpithet }) { continue }
                let phrase = PlayfulMissionRegistry.promiseTerms[spellID]?.deed
                    ?? SpellRegistry.all.first(where: { $0.id == spellID }).map { "cast \u{201C}\($0.title)\u{201D}" }
                    ?? "cast a spell"
                found.append(Deed(kind: .spellCast, date: page.createdAt, pageID: page.id, phrase: phrase,
                                  sentence: sentence, working: "spell:\(spellID)"))
                continue
            }

            if page.type == .festival, let name = page.metadata?["commonName"]?.nonEmpty {
                found.append(Deed(kind: .feastKept, date: page.createdAt, pageID: page.id,
                                  phrase: "kept \(name)", sentence: sentence))
                continue
            }

            let tags = (page.attributableLivedQuestReceipt?.sourceTags ?? []) + page.tags
            let bare = tags.map { $0.hasPrefix("mission:") ? String($0.dropFirst(8)) : $0 }
            if let call = bare.first(where: { $0.hasPrefix("promise-call:") }) {
                let pageID = call.dropFirst("promise-call:".count).split(separator: ":").dropLast().joined(separator: ":")
                let neighbour = register.first { $0.foundingPageID == pageID }
                let phrase = neighbour.map { "told me how your deal with \($0.name) was going" }
                    ?? "told me how a deal was going"
                found.append(Deed(kind: .dealAnswered, date: page.createdAt, pageID: page.id, phrase: phrase,
                                  sentence: sentence, neighbourSlug: neighbour?.slug, neighbourKind: neighbour?.kind))
                continue
            }
            if let slug = bare.first(where: { $0.hasPrefix("neighbour-of:") }).map({ String($0.dropFirst(13)) }),
               let neighbour = bySlug[slug] {
                let isNameDay = bare.contains("nameday")
                found.append(Deed(kind: isNameDay ? .nameDayKept : .visitAnswered, date: page.createdAt,
                                  pageID: page.id,
                                  phrase: isNameDay ? "kept \(neighbour.name)'s name-day" : "went to see \(neighbour.name)",
                                  sentence: sentence, neighbourSlug: slug, neighbourKind: neighbour.kind))
                continue
            }
            if let receipt = page.attributableLivedQuestReceipt {
                found.append(Deed(kind: .workingReturned, date: receipt.completedAt, pageID: page.id,
                                  phrase: "went out on \u{201C}\(receipt.title)\u{201D} and came back with something",
                                  sentence: sentence, working: "\(receipt.kind.rawValue):\(receipt.questID)"))
            }
        }
        return found.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

    static func namingPhrase(working: String, name: String) -> String {
        switch working {
        case "spell:name-a-tree": return "told a tree it was called \(name)"
        case "dare:room-renaming": return "gave a room a new name, \(name)"
        case "mission:tiny-kindness": return "gave a lost thing a name, \(name)"
        case "mission:chair-held": return "gave a chair a name, \(name)"
        default: return "gave something a name, \(name)"
        }
    }

    // MARK: Counting, in words

    static func times(_ count: Int) -> String {
        switch count {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(number(count)) times"
        }
    }

    static func number(_ count: Int) -> String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                     "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
                     "eighteen", "nineteen", "twenty"]
        return count >= 0 && count < words.count ? words[count] : "more than twenty"
    }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    // MARK: The month, told as deeds

    /// The span told with the reader as the one who did things, built only
    /// from the deeds in it. Deterministic. Empty when nothing was done.
    ///
    /// "In October you told a tree it was called Gerald. Gerald was in your
    /// Pages eleven times."
    static func told(
        deeds all: [Deed], days: [BookDay], from start: Date, to end: Date,
        periodName: String, sentenceLimit: Int = 3
    ) -> [String] {
        let deeds = all.filter { $0.date >= start && $0.date <= end }
        guard !deeds.isEmpty else { return [] }
        var paragraphs: [String] = []
        var opening: [String] = []

        let namings = deeds.filter { $0.kind == .neighbourNamed }
        let metAll = deeds.filter { $0.kind == .neighbourMet }
        let firsts = namings.map(\.phrase) + metAll.map(\.phrase)
        if let first = firsts.first {
            opening.append("In \(periodName) you \(first).")
            for more in firsts.dropFirst().prefix(3) { opening.append("You \(more).") }
        }

        // How often each Neighbour turned up in the span.
        let register = Neighbours.register(days: days)
        for neighbour in register where !neighbour.isEpithet || deeds.contains(where: { $0.neighbourSlug == neighbour.slug }) {
            let count = neighbour.pageDates.filter { $0 >= start && $0 <= end }.count
            guard count >= 2 else { continue }
            opening.append("\(Neighbours.capitalized(neighbour.name)) was in your Pages \(times(count)).")
        }
        if !opening.isEmpty { paragraphs.append(opening.joined(separator: " ")) }

        var middle: [String] = []
        let spells = deeds.filter { $0.kind == .spellCast }
        if spells.count == 1, let spell = spells.first {
            middle.append(opening.isEmpty ? "In \(periodName) you \(spell.phrase)." : "You \(spell.phrase).")
        } else if spells.count > 1 {
            middle.append("You cast \(number(spells.count)) spells.")
        }
        let workings = deeds.filter { $0.kind == .workingReturned }
        if workings.count == 1, let working = workings.first {
            middle.append("You \(working.phrase).")
        } else if workings.count > 1 {
            middle.append("You went out on \(number(workings.count)) errands and came back from every one with something.")
        }
        let deals = deeds.filter { $0.kind == .dealAnswered }
        if !deals.isEmpty {
            middle.append(deals.count == 1 ? "You \(deals[0].phrase)." : "You told me how your deals were going \(times(deals.count)).")
        }
        let visits = deeds.filter { $0.kind == .visitAnswered || $0.kind == .nameDayKept }
        for visit in visits.prefix(3) { middle.append("You \(visit.phrase).") }
        let feasts = deeds.filter { $0.kind == .feastKept }.map { String($0.phrase.dropFirst("kept ".count)) }
        if !feasts.isEmpty { middle.append("You kept \(list(Array(Set(feasts)).sorted().prefix(4).map { $0 })).") }
        if !middle.isEmpty {
            if paragraphs.isEmpty, let first = middle.first, !first.hasPrefix("In ") {
                middle[0] = "In \(periodName) y" + first.dropFirst()
            }
            paragraphs.append(middle.joined(separator: " "))
        }

        let endings = deeds.filter { $0.kind == .neighbourGone }
        if !endings.isEmpty {
            paragraphs.append(endings.map { "You \($0.phrase)." }.joined(separator: " "))
        }

        // The reader's own sentences, whole, from the deeds that had one.
        let sentences = deeds.compactMap(\.sentence)
        var seen: Set<String> = []
        let quoted = sentences.filter { seen.insert($0).inserted }.prefix(sentenceLimit)
        if !quoted.isEmpty {
            paragraphs.append(quoted.map { "\u{201C}\($0)\u{201D}" }.joined(separator: "\n"))
        }
        return paragraphs
    }

    // MARK: Titles

    /// Each title names the deed that earned it and the day it was earned.
    static func titles(deeds: [Deed], calendar: Calendar = .current) -> [ReaderTitle] {
        var titles: [ReaderTitle] = []
        func earn(_ id: String, _ title: String, by deed: Deed) {
            guard !titles.contains(where: { $0.id == id }) else { return }
            titles.append(ReaderTitle(
                id: id, title: title, earnedAt: deed.date, deedID: deed.id,
                because: "You \(deed.phrase), in \(Neighbours.monthYear(deed.date, calendar: calendar))."
            ))
        }
        func nth(_ kinds: Set<Deed.Kind>, _ n: Int, where predicate: (Deed) -> Bool = { _ in true }) -> Deed? {
            let matching = deeds.filter { kinds.contains($0.kind) && predicate($0) }
            return matching.count >= n ? matching[n - 1] : nil
        }

        if let deed = deeds.first(where: { $0.kind == .neighbourNamed && $0.working == "spell:name-a-tree" }) {
            earn("namer-of-trees", "Namer of Trees", by: deed)
        }
        if let deed = deeds.first(where: { $0.kind == .neighbourNamed && $0.working == "dare:room-renaming" }) {
            earn("namer-of-rooms", "Who Renamed a Room", by: deed)
        }
        if let deed = deeds.first(where: { $0.kind == .neighbourNamed && $0.working == "mission:tiny-kindness" }) {
            earn("lost-property", "Keeper of Lost Things", by: deed)
        }
        if let deed = nth([.neighbourNamed, .neighbourMet], 3, where: { $0.neighbourKind == .thing }) {
            earn("friend-of-things", "Friend of Things", by: deed)
        }
        if let deed = deeds.first(where: { ($0.kind == .neighbourMet || $0.kind == .neighbourNamed) && $0.neighbourKind == .creature }) {
            earn("known-to-creatures", "Known to a Creature", by: deed)
        }
        if let deed = nth([.dealAnswered], 3) {
            earn("keeper-of-deals", "Who Answers for Deals", by: deed)
        }
        if let deed = nth([.workingReturned], 10) {
            earn("who-went-out", "Who Goes Out When Asked", by: deed)
        }
        if let deed = nth([.spellCast], 7) {
            earn("spell-caster", "Caster of Seven Spells", by: deed)
        }
        if let deed = nth([.feastKept], 3) {
            earn("keeper-of-feasts", "Keeper of Feasts", by: deed)
        }
        if let deed = deeds.first(where: { $0.kind == .nameDayKept }) {
            earn("name-day", "Who Kept a Name-Day", by: deed)
        }
        return titles.sorted { $0.earnedAt == $1.earnedAt ? $0.id < $1.id : $0.earnedAt < $1.earnedAt }
    }
}
