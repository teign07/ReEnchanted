import Foundation

/// What the Book has to say about the animals it has filed.
///
/// The Bestiary shelf is a place the reader goes. This is the part that comes
/// to them, and it exists because a list is not a character. The Book is
/// supposed to be obsessed with getting the reader back out into the world, and
/// a record of everything alive that has crossed their path is the best lever it
/// has ever had for that.
///
/// Seven things it can say, ranked. Every one of them is derived from the
/// archive — the sightings on the Pages, and the tags on the Pages the Book has
/// already spoken. Nothing here keeps a second ledger, because a second ledger
/// is a thing that can drift out of step with the truth.

/// The rough shape of a creature, for the one thing the Book asks the reader to
/// go and do. Membership is explicit rather than derived from the label, because
/// there is no rule that puts a bat with the birds and a penguin with the fish
/// and gets both right.
/// Declaration order is the order the Book asks in, easiest first. Wings are
/// everywhere and findable on any walk, and something small is findable without
/// leaving the garden. Water is last because it needs the reader to go
/// somewhere specific, and an errand nobody can run is worse than no errand.
/// Raw values are stable, so reordering never breaks a commission already out.
enum CreatureGroup: String, CaseIterable, Codable {
    case wings
    case small
    case fourLegged
    case water

    /// What the Book calls it out loud.
    var plainName: String {
        switch self {
        case .wings: return "wings"
        case .water: return "water"
        case .small: return "something small"
        case .fourLegged: return "four legs"
        }
    }

    /// The ask, in the Book's own words. An errand, not a request.
    var ask: String {
        switch self {
        case .wings: return "Bring me something with wings."
        case .water: return "Bring me something that lives in water."
        case .small: return "Bring me something small enough to walk past."
        case .fourLegged: return "Bring me something on four legs."
        }
    }

    /// Why the gap is worth closing, said plainly.
    var gapLine: String {
        switch self {
        case .wings: return "Not one thing in here flies."
        case .water: return "Nothing in here has ever been in water."
        case .small: return "Everything in here is big enough to notice without trying."
        case .fourLegged: return "Nothing in here walks on four legs."
        }
    }

    var members: Set<String> {
        switch self {
        case .wings:
            return [
                "bird", "songbird", "bird of prey", "sea bird", "duck", "goose",
                "swan", "owl", "parrot", "flamingo", "peacock", "pigeon", "dove",
                "seagull", "crane", "heron", "stork", "chicken", "turkey",
                "eagle", "hawk", "falcon", "kestrel", "woodpecker", "hummingbird",
                "crow", "raven", "magpie", "jay", "robin", "sparrow", "starling",
                "finch", "wren", "kingfisher", "puffin", "pelican", "cormorant",
                "swift", "swallow", "nightingale", "cuckoo", "quail", "pheasant",
                "partridge", "bat", "butterfly", "moth", "bee", "bumblebee",
                "wasp", "hornet", "dragonfly", "damselfly", "firefly", "cicada",
            ]
        case .water:
            return [
                "fish", "goldfish", "koi", "trout", "salmon", "shark", "stingray",
                "eel", "seahorse", "jellyfish", "octopus", "squid", "crab",
                "lobster", "shrimp", "starfish", "sea urchin", "whale", "dolphin",
                "porpoise", "seal", "sea lion", "walrus", "manatee", "turtle",
                "terrapin", "frog", "toad", "tadpole", "newt", "salamander",
                "penguin", "otter", "beaver", "duck", "swan", "goose", "heron",
                "kingfisher", "pelican", "cormorant", "puffin", "flamingo",
            ]
        case .small:
            return [
                "insect", "butterfly", "moth", "caterpillar", "bee", "bumblebee",
                "wasp", "hornet", "ant", "beetle", "ladybug", "dragonfly",
                "damselfly", "grasshopper", "cricket", "locust", "mantis",
                "cicada", "firefly", "spider", "snail", "slug", "worm",
                "centipede", "millipede", "scorpion", "woodlouse", "mouse",
                "vole", "shrew", "gecko", "skink", "tadpole",
            ]
        case .fourLegged:
            return [
                "cat", "dog", "horse", "pony", "donkey", "mule", "zebra", "cow",
                "sheep", "goat", "pig", "boar", "llama", "alpaca", "camel",
                "reindeer", "rabbit", "hare", "squirrel", "chipmunk", "mouse",
                "rat", "vole", "hamster", "guinea pig", "gerbil", "ferret",
                "hedgehog", "mole", "shrew", "raccoon", "skunk", "opossum",
                "beaver", "otter", "badger", "weasel", "stoat", "marten", "fox",
                "wolf", "coyote", "bear", "deer", "elk", "moose", "bison",
                "lynx", "bobcat", "cougar", "lion", "tiger", "leopard",
                "cheetah", "jaguar", "hyena", "elephant", "giraffe",
                "hippopotamus", "rhinoceros", "panda", "meerkat", "armadillo",
                "wombat", "koala", "sloth",
            ]
        }
    }

    func contains(_ creature: String) -> Bool {
        members.contains(VisualFact.normalized(creature))
    }
}

enum BestiaryNoticeKind: String, Equatable {
    /// The Book asked for something and the reader went and got it.
    case brought
    /// A creature filed for the first time ever.
    case firstOfItsKind
    /// One that stopped turning up and then turned up.
    case theReturn
    /// One that used to turn up and has not, for a long time.
    case goneQuiet
    /// Two that never seem to arrive apart.
    case theCompany
    /// What people have said about a creature the reader now has.
    case theLore
    /// The Book asking for a shape of thing its file has none of.
    case commission
}

/// One thing the Book has to say about the file, ready to be a Page.
struct BestiaryNotice: Equatable {
    var kind: BestiaryNoticeKind
    /// The creature it's about. Nil for a commission, which is about a gap.
    var creature: String?
    var headline: String
    /// The card's single callout line.
    var detail: String
    var body: String
    /// The lore row underneath it, when there is one.
    var loreID: String?
    var group: CreatureGroup?
    /// The Pages this rests on, so the reader can go and check the Book.
    var evidencePageIDs: [String]

    /// The tag that stops the Book saying this one again. Written onto the
    /// Page, read back out of the archive: the record of what has been said is
    /// the archive itself, never a counter that can drift away from it.
    var restTag: String {
        switch kind {
        case .commission: return "bestiary-commission:\(group?.rawValue ?? "any")"
        case .brought: return "bestiary-brought:\(group?.rawValue ?? "any")"
        default: return "bestiary-\(kind.rawValue):\(creature ?? "any")"
        }
    }
}

extension Bestiary {

    /// How long a creature has to be missing before the Book counts it as gone.
    /// Longer than a place, because an animal was never yours to visit.
    static let creatureQuietDays = 90
    /// How long an absence has to run for a reappearance to be a return.
    static let creatureReturnDays = 60
    /// How fresh a first sighting or a return has to be to be worth raising.
    static let freshWindowDays = 4
    /// How many creatures the file needs before its gaps mean anything. A file
    /// with two things in it has nothing but gaps.
    static let commissionFloor = 3

    /// The one thing the Book has to say about the file today, or nothing.
    static func notice(
        days: [BookDay],
        anchors: [AnchorRecord] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BestiaryNotice? {
        let pages = days.flatMap(\.pages)
        let spoken = Set(pages.flatMap(\.tags))
        let entries = entries(days: days, anchors: anchors, now: now, calendar: calendar)

        // A commission the reader kept and then answered. The Book committed to
        // an errand in advance, so the result outranks everything it might have
        // thought of on its own — including, especially, when they did it.
        if let asked = outstandingCommission(pages: pages),
           let answer = pages
            .filter({ $0.createdAt > asked.askedAt })
            .flatMap({ page in (page.creatureSightings ?? []).map { (page, $0) } })
            .first(where: { asked.group.contains($0.1.creature) }) {
            return brought(group: asked.group, page: answer.0, creature: answer.1.creature,
                           askedAt: asked.askedAt, now: now, calendar: calendar)
        }

        guard !entries.isEmpty else {
            // Nothing filed at all. The Book has no file to have gaps in yet,
            // and asking for wings from somebody who has never photographed an
            // animal is a stranger asking a favour.
            return nil
        }

        var appearances: [String: [BookPage]] = [:]
        for page in pages {
            for sighting in page.creatureSightings ?? [] {
                appearances[sighting.creature, default: []].append(page)
            }
        }
        for key in appearances.keys {
            appearances[key]?.sort { $0.createdAt < $1.createdAt }
        }

        if let notice = firstOfItsKind(
            appearances: appearances, spoken: spoken, now: now, calendar: calendar
        ) { return notice }

        if let notice = theReturn(
            appearances: appearances, spoken: spoken, now: now, calendar: calendar
        ) { return notice }

        if let notice = goneQuiet(
            appearances: appearances, spoken: spoken, now: now, calendar: calendar
        ) { return notice }

        if let notice = theCompany(days: days, spoken: spoken) { return notice }

        // The errand goes above the lore, and it has to. There are forty lore
        // rows and a reader will never exhaust them, so lore sitting higher
        // would mean the Book never once asked anybody to go outside — which is
        // the only thing on this list it actually exists to do. There are four
        // commissions ever. Furniture can wait.
        if let notice = commission(entries: entries, spoken: spoken) { return notice }

        return theLore(entries: entries, appearances: appearances, spoken: spoken)
    }

    // MARK: The errand

    /// The most recent commission the reader kept and hasn't yet answered.
    ///
    /// Read out of the archive rather than a ledger, and keyed on a *kept*
    /// Page: keeping the card is how the reader takes the errand on. Swiping it
    /// away costs them nothing and owes them nothing, which is the same shape
    /// the Fae Bargain already uses.
    static func outstandingCommission(pages: [BookPage]) -> (group: CreatureGroup, askedAt: Date)? {
        let asks = pages.compactMap { page -> (CreatureGroup, Date)? in
            guard let tag = page.tags.first(where: { $0.hasPrefix("bestiary-commission:") }),
                  let group = CreatureGroup(rawValue: String(tag.dropFirst("bestiary-commission:".count)))
            else { return nil }
            return (group, page.createdAt)
        }
        guard let latest = asks.max(by: { $0.1 < $1.1 }) else { return nil }
        // Already settled. The Book said its piece and the errand is closed.
        let settled = pages.contains { $0.tags.contains("bestiary-brought:\(latest.0.rawValue)") }
        return settled ? nil : (latest.0, latest.1)
    }

    private static func brought(
        group: CreatureGroup,
        page: BookPage,
        creature: String,
        askedAt: Date,
        now: Date,
        calendar: Calendar
    ) -> BestiaryNotice {
        let days = calendar.dateComponents([.day], from: askedAt, to: page.createdAt).day ?? 0
        let took: String
        switch days {
        case ...0: took = "You did it the same day."
        case 1: took = "You did it the next day."
        case 2...13: took = "That took you \(days) days."
        default: took = "That took you a while. I didn't mind waiting."
        }
        var body = "I asked for \(group.plainName) and you brought me a \(creature). \(took) I want you to notice that you went outside and something happened, and that the something was findable the whole time."
        if let words = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            body += "\n\nYou wrote: “\(words.count > 200 ? String(words.prefix(197)) + "…" : words)”"
        }
        return BestiaryNotice(
            kind: .brought,
            creature: creature,
            headline: "You went and got one",
            detail: "I asked for \(group.plainName). You brought a \(creature).",
            body: body,
            loreID: CreatureLore.lore(for: creature)?.id,
            group: group,
            evidencePageIDs: [page.id]
        )
    }

    private static func commission(
        entries: [BestiaryEntry],
        spoken: Set<String>
    ) -> BestiaryNotice? {
        guard entries.count >= commissionFloor else { return nil }
        let held = Set(entries.map(\.creature))
        // The emptiest gap, and never one already asked for. A group the reader
        // has one thing from isn't a gap, it's a start.
        // First unfilled group in declaration order, which is the order the
        // Book asks in. Sorting alphabetically instead sent a reader looking
        // for a woodlouse before it ever mentioned birds.
        guard let gap = CreatureGroup.allCases.first(where: { group in
            !held.contains(where: group.contains)
                && !spoken.contains("bestiary-commission:\(group.rawValue)")
        }) else { return nil }

        return BestiaryNotice(
            kind: .commission,
            creature: nil,
            headline: "There's a gap in the file",
            detail: gap.ask,
            body: "I've got \(entries.count) creatures in here now. \(gap.gapLine)\n\n\(gap.ask) A photograph is enough. I'll know when you have — I'm the one who looks at them, and I don't need you to tell me what it was.\n\nKeep this page if you'll take it on. Let it go if you won't, and I won't bring it up again.",
            loreID: nil,
            group: gap,
            evidencePageIDs: []
        )
    }

    // MARK: What the file did on its own

    private static func firstOfItsKind(
        appearances: [String: [BookPage]],
        spoken: Set<String>,
        now: Date,
        calendar: Calendar
    ) -> BestiaryNotice? {
        let candidates = appearances.compactMap { creature, pages -> (String, BookPage)? in
            guard pages.count >= 1, let first = pages.first else { return nil }
            guard !spoken.contains("bestiary-firstOfItsKind:\(creature)") else { return nil }
            let age = calendar.dateComponents([.day], from: first.createdAt, to: now).day ?? .max
            guard age >= 0, age <= freshWindowDays else { return nil }
            return (creature, first)
        }
        guard let (creature, page) = candidates.max(by: { $0.1.createdAt < $1.1.createdAt })
        else { return nil }

        let lore = CreatureLore.lore(for: creature)
        var body = "Nothing like it has been in here before. I've started a folder.\n\nNow I'll know if it comes back, and how long it took, and what the weather was doing both times. That's the whole trick — I only have to see a thing twice before it stops being an accident."
        if let lore {
            body += "\n\n\(lore.lore)"
        }
        return BestiaryNotice(
            kind: .firstOfItsKind,
            creature: creature,
            headline: "A \(creature). That's new.",
            detail: "First one you've ever brought me.",
            body: body,
            loreID: lore?.id,
            group: nil,
            evidencePageIDs: [page.id]
        )
    }

    private static func theReturn(
        appearances: [String: [BookPage]],
        spoken: Set<String>,
        now: Date,
        calendar: Calendar
    ) -> BestiaryNotice? {
        for (creature, pages) in appearances.sorted(by: { $0.key < $1.key }) {
            guard pages.count >= 2, let latest = pages.last else { continue }
            let previous = pages[pages.count - 2]
            guard !spoken.contains("bestiary-theReturn:\(creature)") else { continue }
            let fresh = calendar.dateComponents([.day], from: latest.createdAt, to: now).day ?? .max
            guard fresh >= 0, fresh <= freshWindowDays else { continue }
            let gap = calendar.dateComponents([.day], from: previous.createdAt, to: latest.createdAt).day ?? 0
            guard gap >= creatureReturnDays else { continue }
            let lore = CreatureLore.lore(for: creature)
            var body = "The last one was \(monthLabel(previous.createdAt, now: now, calendar: calendar)). \(Gazetteer.months(gap)) with nothing, and then there it was.\n\nI'd stopped expecting it. That's my fault and not yours. A thing being gone a while isn't the same as a thing being gone."
            if let lore { body += "\n\n\(lore.lore)" }
            return BestiaryNotice(
                kind: .theReturn,
                creature: creature,
                headline: "The \(creature) came back",
                detail: "\(Gazetteer.months(gap)), and then there it was.",
                body: body,
                loreID: lore?.id,
                group: nil,
                evidencePageIDs: [previous.id, latest.id]
            )
        }
        return nil
    }

    /// The one that reads like the place noticings, and should. A creature
    /// dropping out of the record is the reader's world getting smaller, and
    /// arguing with exactly that is what the Book is for.
    private static func goneQuiet(
        appearances: [String: [BookPage]],
        spoken: Set<String>,
        now: Date,
        calendar: Calendar
    ) -> BestiaryNotice? {
        for (creature, pages) in appearances.sorted(by: { $0.value.count > $1.value.count }) {
            guard pages.count >= 3, let latest = pages.last else { continue }
            guard !spoken.contains("bestiary-goneQuiet:\(creature)") else { continue }
            let since = calendar.dateComponents([.day], from: latest.createdAt, to: now).day ?? 0
            guard since >= creatureQuietDays else { continue }
            return BestiaryNotice(
                kind: .goneQuiet,
                creature: creature,
                headline: "No \(plural(creature)) since \(monthLabel(latest.createdAt, now: now, calendar: calendar))",
                detail: "You used to bring me one every few weeks.",
                body: "\(GrimoireVoice.spelledCount(pages.count)) of them, and then \(Gazetteer.months(since)) of nothing.\n\nThey haven't left. \(plural(creature).prefix(1).uppercased() + plural(creature).dropFirst()) don't leave a whole town. Something changed about where you go, or when you go there, or whether you're looking up. I'd like to know which.",
                loreID: CreatureLore.lore(for: creature)?.id,
                group: nil,
                evidencePageIDs: pages.suffix(3).map(\.id)
            )
        }
        return nil
    }

    /// Two creatures that have never turned up apart. The kind of thing nobody
    /// notices about their own life, which is the only kind worth saying.
    private static func theCompany(days: [BookDay], spoken: Set<String>) -> BestiaryNotice? {
        var byDay: [String: Set<String>] = [:]
        var pageIDs: [String: [String]] = [:]
        for day in days {
            for page in day.pages {
                for sighting in page.creatureSightings ?? [] {
                    byDay[day.id, default: []].insert(sighting.creature)
                    pageIDs[day.id, default: []].append(page.id)
                }
            }
        }
        let dayIDs = byDay.keys.sorted()
        var appearsOn: [String: Set<String>] = [:]
        for dayID in dayIDs {
            for creature in byDay[dayID] ?? [] { appearsOn[creature, default: []].insert(dayID) }
        }

        for (creature, own) in appearsOn.sorted(by: { $0.key < $1.key }) {
            guard own.count >= 3 else { continue }
            for (other, theirs) in appearsOn.sorted(by: { $0.key < $1.key }) where other != creature {
                // Every day the first turned up, so did the second. Not the
                // other way round: the claim is one-directional and the Book
                // must say the direction it can actually support.
                guard own.isSubset(of: theirs) else { continue }
                guard !spoken.contains("bestiary-theCompany:\(creature)") else { continue }
                return BestiaryNotice(
                    kind: .theCompany,
                    creature: creature,
                    headline: "Never a \(creature) without a \(other)",
                    detail: "\(GrimoireVoice.spelledCount(own.count)) days with a \(creature). A \(other) on every one.",
                    body: "I don't think you've noticed this and I don't think you'd have any reason to.\n\nEvery single day you've brought me a \(creature), there's been a \(other) somewhere in the same day's photographs. \(GrimoireVoice.spelledCount(own.count)) times out of \(GrimoireVoice.spelledCount(own.count)).\n\nIt might be one place that has both. It might be one hour of the day. It might be nothing. But it's true so far, and I'd rather tell you a true small thing than wait until I've got a large one.",
                    loreID: nil,
                    group: nil,
                    evidencePageIDs: Array((own.sorted().flatMap { pageIDs[$0] ?? [] }).prefix(4))
                )
            }
        }
        return nil
    }

    /// What people have said about a creature the reader now actually has.
    private static func theLore(
        entries: [BestiaryEntry],
        appearances: [String: [BookPage]],
        spoken: Set<String>
    ) -> BestiaryNotice? {
        for entry in entries {
            guard !spoken.contains("bestiary-theLore:\(entry.creature)") else { continue }
            guard let lore = CreatureLore.lore(for: entry.creature) else { continue }
            let pages = appearances[entry.creature] ?? []
            var body = lore.lore
            // The reader's own words about the day they saw it, when they left
            // any. Their sentence next to four hundred years of somebody
            // else's is the entire point of the shelf.
            if let words = pages.reversed()
                .compactMap({ $0.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty })
                .first {
                body += "\n\nYou wrote this on the day you saw one: “\(words.count > 200 ? String(words.prefix(197)) + "…" : words)”"
            }
            body += "\n\nI'm not saying any of it is true. I'm saying somebody kept it for a very long time, and it got all the way to you, and now you've seen one."
            return BestiaryNotice(
                kind: .theLore,
                creature: entry.creature,
                headline: "\(lore.subject) — \(lore.sense)",
                detail: entry.seenLine,
                body: body,
                loreID: lore.id,
                group: nil,
                evidencePageIDs: pages.suffix(2).map(\.id)
            )
        }
        return nil
    }

    /// Plurals for the handful of creature words that don't just take an s.
    static func plural(_ creature: String) -> String {
        let irregular = [
            "mouse": "mice", "goose": "geese", "sheep": "sheep", "deer": "deer",
            "fish": "fish", "ox": "oxen", "fox": "foxes", "finch": "finches",
            "thrush": "thrushes", "moose": "moose", "bison": "bison",
            "lynx": "lynxes", "octopus": "octopuses", "wolf": "wolves",
            "starfish": "starfish", "porpoise": "porpoises", "walrus": "walruses",
            "butterfly": "butterflies", "damselfly": "damselflies",
            "dragonfly": "dragonflies", "firefly": "fireflies",
            "pony": "ponies", "donkey": "donkeys", "puppy": "puppies",
            "guinea pig": "guinea pigs", "millipede": "millipedes",
            "woodlouse": "woodlice",
        ]
        if let known = irregular[creature] { return known }
        if creature.hasSuffix("s") || creature.hasSuffix("x") || creature.hasSuffix("sh")
            || creature.hasSuffix("ch") { return creature + "es" }
        if creature.hasSuffix("y"), let last = creature.dropLast().last, !"aeiou".contains(last) {
            return creature.dropLast() + "ies"
        }
        return creature + "s"
    }
}
