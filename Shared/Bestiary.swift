import Foundation

/// What the Book saw alive in a photograph, and kept.
///
/// Perception has been finding animals since the Vision ensemble landed. Both
/// illumination paths run `VNRecognizeAnimalsRequest`, and the caption path also
/// runs a classifier whose taxonomy is full of birds and insects and horses.
/// Every one of those findings was thrown away at the end of the pass: the VLM
/// path kept only a layout region, and the caption path used the animal list as
/// a test for whether a photograph was boring. Nothing accumulated.
///
/// This is the record that stops the loss. It deliberately does no interpreting
/// — a sighting is "cat, clearly" and never "the cat that watches you" — because
/// the file that defines `VisualFact` already learned this lesson: once a phrase
/// is the stored fact, the Book can cite it a year later as though it were an
/// observation.
///
/// Named for Gwendolyn Mythwright, who keeps a filing system for animals that do
/// not, strictly speaking, exist, and who will take a blurry shape in the hedge
/// completely seriously.

/// One creature, filed once per photograph.
struct CreatureSighting: Codable, Equatable, Hashable {
    /// The Book's filing name for it. Never the raw classifier label.
    var creature: String
    /// How sure perception was, in the words the Book is allowed to use.
    var certainty: VisualCertainty
}

enum Bestiary {

    /// The bar for filing. Perception hands up labels from 0.16, which is right
    /// for a caption — a weak label is still context — and wrong for a shelf.
    /// A creature the Book would have to hedge as "maybe" doesn't get filed at
    /// all, because the bestiary is a record of things seen, not things guessed.
    static let filingCertainty: VisualCertainty = .likely

    /// The labels Gwendolyn files as alive.
    ///
    /// Matched whole, never as a substring. Substring matching files a catfish
    /// under cats and a dogwood under dogs, and the reader would be right to
    /// stop trusting the shelf after the first one.
    static let creatureLabels: Set<String> = [
        // The two the dedicated recognizer knows by name
        "cat", "dog", "kitten", "puppy",
        // Birds
        "bird", "songbird", "bird of prey", "sea bird", "seabird", "duck",
        "duckling", "goose", "swan", "owl", "penguin", "parrot", "flamingo",
        "peacock", "pigeon", "dove", "seagull", "gull", "crane bird", "heron",
        "stork", "chicken", "rooster", "hen", "turkey", "ostrich", "eagle",
        "hawk", "falcon", "kestrel", "woodpecker", "hummingbird", "crow",
        "raven", "magpie", "jay", "robin", "sparrow", "starling", "finch",
        "wren", "kingfisher", "puffin", "pelican", "cormorant", "swift",
        "swallow", "nightingale", "cuckoo", "quail", "pheasant", "partridge",
        // Kept and herded
        "horse", "pony", "foal", "donkey", "mule", "zebra", "cow", "cattle",
        "bull", "calf", "ox", "sheep", "lamb", "ram", "goat", "kid goat",
        "pig", "piglet", "boar", "llama", "alpaca", "camel", "reindeer",
        // Wild and near
        "rabbit", "hare", "squirrel", "chipmunk", "mouse", "rat", "vole",
        "hamster", "guinea pig", "gerbil", "ferret", "hedgehog", "mole",
        "shrew", "bat", "raccoon", "skunk", "opossum", "possum", "beaver",
        "otter", "badger", "weasel", "stoat", "marten", "fox", "wolf",
        "coyote", "bear", "deer", "fawn", "elk", "moose", "bison", "lynx",
        "bobcat", "cougar", "wild boar", "wombat",
        // Far off
        "lion", "tiger", "leopard", "cheetah", "jaguar", "panther", "hyena",
        "elephant", "giraffe", "hippopotamus", "rhinoceros", "monkey", "ape",
        "gorilla", "chimpanzee", "orangutan", "baboon", "lemur", "sloth",
        "kangaroo", "koala", "panda", "meerkat", "armadillo", "anteater",
        // Water
        "fish", "goldfish", "koi", "trout", "salmon", "shark", "stingray",
        "eel", "seahorse", "jellyfish", "octopus", "squid", "crab", "lobster",
        "shrimp", "starfish", "sea urchin", "whale", "dolphin", "porpoise",
        "seal", "sea lion", "walrus", "manatee", "turtle", "tortoise",
        "terrapin",
        // Cold-blooded and small
        "frog", "toad", "tadpole", "salamander", "newt", "lizard", "gecko",
        "iguana", "chameleon", "skink", "snake", "crocodile", "alligator",
        "insect", "butterfly", "moth", "caterpillar", "bee", "bumblebee",
        "wasp", "hornet", "ant", "beetle", "ladybug", "ladybird", "dragonfly",
        "damselfly", "grasshopper", "cricket", "locust", "mantis", "cicada",
        "firefly", "spider", "snail", "slug", "worm", "earthworm",
        "centipede", "millipede", "scorpion", "woodlouse", "moth larva",
        // Added after reading Apple's actual taxonomy rather than guessing at
        // it. `VNClassifyImageRequest.supportedIdentifiers()` returns 1,303
        // labels on revision 2; these are the living ones the first pass of
        // this vocabulary missed.
        "sandpiper", "vulture", "porcupine", "python", "barnacle", "oyster",
        "mussel", "clam", "scallop", "clownfish", "guppy", "angelfish", "tuna",
        "mackerel", "sardine", "barracuda", "swordfish",
        // Apple's own group labels. These are the true answer more often than
        // the specific ones are: the taxonomy has no word for a crow, a magpie
        // or a wren, so a photograph of any of them comes back "bird" and that
        // is genuinely all anybody knows. The dull end of the same ladder —
        // "animal", "mammal", "feline", "canine" — is deliberately left out.
        // "A mammal, seen once" is not a bestiary entry.
        "raptor", "rodent", "reptile", "arachnid", "mollusk", "marsupial",
    ]

    /// The few labels whose filing name isn't the label itself. Only merges the
    /// Book can defend out loud: a puppy really is a dog. Nothing here collapses
    /// a specific creature into a general one — a songbird stays a songbird,
    /// because "bird" is a duller thing to have seen.
    static let filedAs: [String: String] = [
        "kitten": "cat",
        "puppy": "dog",
        "cattle": "cow",
        "bull": "cow",
        "calf": "cow",
        "ox": "cow",
        "lamb": "sheep",
        "ram": "sheep",
        "duckling": "duck",
        "foal": "horse",
        "piglet": "pig",
        "fawn": "deer",
        "hen": "chicken",
        "rooster": "chicken",
        "seabird": "sea bird",
        "gull": "seagull",
        "crane bird": "crane",
        "ladybird": "ladybug",
        "possum": "opossum",
        "earthworm": "worm",
        "moth larva": "caterpillar",
        "kid goat": "goat",
        "wild boar": "boar",
    ]

    /// Every label the filing system answers to: the raw vocabulary plus the
    /// names it files things *under*.
    ///
    /// The second half matters more than it looks. "Crane bird" files as
    /// "crane", and "crane" was never a label in its own right, so asking the
    /// system about its own output came back nil — and the validator asks
    /// exactly that about an already-filed sighting before letting it into the
    /// archive. Every crane the Book ever saw would have been thrown away on
    /// the way in. Filing has to be idempotent or it isn't filing.
    static let recognisedLabels: Set<String> = creatureLabels.union(filedAs.values)

    /// What Apple's Vision can actually put a name to today, as filed names.
    ///
    /// Not a rule — a snapshot, and the honest floor under everything above it.
    /// `VNRecognizeAnimalsRequest` supports exactly two identifiers, Cat and
    /// Dog. Everything else in this vocabulary has to come from
    /// `VNClassifyImageRequest`, whose revision-2 taxonomy is 1,303 labels
    /// wide and has no word for a crow, a magpie, a robin, a wren, a starling,
    /// a swallow, a duck, a goose, a hare, a mouse or a bat. Those photographs
    /// come back as "bird" or as nothing.
    ///
    /// The rest of the vocabulary is kept anyway. It costs a set lookup, Apple
    /// revises this taxonomy between releases, and a second backend that can
    /// name a magpie would light up thirty rows of lore the same afternoon.
    ///
    /// Regenerate with a script that prints
    /// `VNClassifyImageRequest().supportedIdentifiers()`, splits each on comma,
    /// takes the first two synonyms, and normalises them the way `VisualFact`
    /// does — that is exactly what the classifier pass can emit.
    static let namedByAppleVision: Set<String> = [
        "angelfish", "ant", "arachnid", "barnacle", "barracuda", "bear",
        "bee", "bird", "bison", "boar", "bobcat", "butterfly", "camel",
        "cat", "caterpillar", "centipede", "chameleon", "cheetah", "clam",
        "clownfish", "cougar", "cow", "crab", "deer", "dog", "dolphin",
        "donkey", "dove", "dragonfly", "eagle", "elephant", "elk", "ferret",
        "fish", "flamingo", "fox", "frog", "gecko", "gerbil", "giraffe",
        "goat", "goldfish", "guppy", "hamster", "hedgehog", "heron",
        "hippopotamus", "horse", "hummingbird", "hyena", "iguana", "insect",
        "jellyfish", "kangaroo", "koala", "koi", "ladybug", "lemur",
        "leopard", "lion", "lizard", "llama", "lobster", "lynx", "mackerel",
        "marsupial", "millipede", "mollusk", "moose", "moth", "mussel",
        "ostrich", "otter", "owl", "oyster", "panda", "parrot", "peacock",
        "pelican", "penguin", "pig", "pigeon", "porcupine", "puffin",
        "python", "rabbit", "raccoon", "raptor", "rat", "raven", "reptile",
        "rhinoceros", "rodent", "salmon", "sandpiper", "sardine", "scallop",
        "scorpion", "seagull", "seahorse", "seal", "shark", "sheep", "skunk",
        "snail", "snake", "sparrow", "spider", "squirrel", "starfish",
        "stingray", "stork", "swan", "swordfish", "tiger", "toad",
        "tortoise", "trout", "tuna", "turtle", "vulture", "walrus", "whale",
        "woodpecker", "worm", "zebra",
    ]

    /// The Book's name for a perception label, or nil when the label isn't a
    /// living thing as far as the filing system is concerned.
    static func creature(for label: String) -> String? {
        let normalized = VisualFact.normalized(label)
        guard recognisedLabels.contains(normalized) else { return nil }
        return filedAs[normalized] ?? normalized
    }

    /// Labels that name a group rather than a creature, and what sits under
    /// each of them.
    ///
    /// The classifier hands a group up alongside the specific name whenever it
    /// is confident about both, so one raven arrives as "raven" *and* "bird"
    /// and would be filed as two creatures. A group survives only when nothing
    /// underneath it was filed — which is the case that matters, because Apple
    /// has no label for a crow and "bird" is then the honest answer rather than
    /// a vaguer version of a better one.
    static let coveredByGroupLabel: [String: Set<String>] = [
        "bird": [
            "songbird", "bird of prey", "sea bird", "raptor", "vulture", "duck",
            "goose", "swan", "owl", "penguin", "parrot", "flamingo", "peacock",
            "pigeon", "dove", "seagull", "crane", "heron", "stork", "chicken",
            "turkey", "ostrich", "eagle", "hawk", "falcon", "kestrel",
            "woodpecker", "hummingbird", "crow", "raven", "magpie", "jay",
            "robin", "sparrow", "starling", "finch", "wren", "kingfisher",
            "puffin", "pelican", "cormorant", "swift", "swallow", "nightingale",
            "cuckoo", "quail", "pheasant", "partridge", "sandpiper",
        ],
        "raptor": ["eagle", "hawk", "falcon", "kestrel", "owl", "vulture", "bird of prey"],
        "insect": [
            "butterfly", "moth", "caterpillar", "bee", "bumblebee", "wasp",
            "hornet", "ant", "beetle", "ladybug", "dragonfly", "damselfly",
            "grasshopper", "cricket", "locust", "mantis", "cicada", "firefly",
        ],
        "arachnid": ["spider", "scorpion"],
        "mollusk": ["snail", "slug", "octopus", "squid", "oyster", "mussel", "clam", "scallop"],
        "marsupial": ["kangaroo", "koala", "wombat", "opossum"],
        "rodent": [
            "mouse", "rat", "vole", "hamster", "guinea pig", "gerbil",
            "squirrel", "chipmunk", "beaver", "porcupine",
        ],
        "reptile": [
            "lizard", "gecko", "iguana", "chameleon", "skink", "snake",
            "python", "crocodile", "alligator", "turtle", "tortoise", "terrapin",
        ],
        "fish": [
            "goldfish", "koi", "trout", "salmon", "angelfish", "clownfish",
            "guppy", "tuna", "mackerel", "sardine", "barracuda", "swordfish",
            "eel", "seahorse", "shark", "stingray",
        ],
    ]

    /// Everything alive in one photograph, each creature filed once at the best
    /// certainty any pass managed for it.
    ///
    /// Two passes naming the same animal is agreement, not a second animal: the
    /// dedicated recognizer and the classifier both see the one cat.
    static func sightings(in packet: VisualFactPacket) -> [CreatureSighting] {
        var best: [String: CreatureSighting] = [:]
        for fact in packet.facts {
            guard fact.certainty >= filingCertainty,
                  let creature = creature(for: fact.label)
            else { continue }
            let sighting = CreatureSighting(creature: creature, certainty: fact.certainty)
            if let held = best[creature], held.certainty >= sighting.certainty { continue }
            best[creature] = sighting
        }

        // One pass is enough, because every test reads the original set. Given
        // bird, raptor and eagle: bird is covered by both of the others and
        // goes, raptor is covered by eagle and goes, eagle stays.
        let filed = Set(best.keys)
        for (group, covered) in coveredByGroupLabel where !covered.isDisjoint(with: filed) {
            best[group] = nil
        }

        return best.values.sorted { left, right in
            left.certainty == right.certainty
                ? left.creature < right.creature
                : left.certainty > right.certainty
        }
    }

    // MARK: - Carrying a sighting onto the page

    /// Page metadata is a flat `[String: String]`, which is how every other part
    /// of a photo reading already travels. Sightings use the same " | " list the
    /// observations and souvenirs use, so the shape of a page's metadata stays
    /// one thing a reader of this code has to learn rather than two.
    static let metadataKey = "creatures"

    static func encoded(_ sightings: [CreatureSighting]) -> String {
        sightings.map { "\($0.creature):\($0.certainty.rawValue)" }.joined(separator: " | ")
    }

    static func decoded(_ raw: String) -> [CreatureSighting] {
        raw.components(separatedBy: " | ").compactMap { piece in
            let parts = piece.split(separator: ":", maxSplits: 1)
            guard let name = parts.first?.trimmingCharacters(in: .whitespaces).nonEmpty else {
                return nil
            }
            let certainty = parts.count > 1
                ? VisualCertainty(rawValue: String(parts[1]).trimmingCharacters(in: .whitespaces))
                : nil
            return CreatureSighting(creature: name, certainty: certainty ?? .likely)
        }
    }
}

// MARK: - From the desk into the archive

extension CreatureSighting {
    /// The sightings a kept Page inherits from the card it was kept from.
    ///
    /// Follows `BookPageExternalReference.from(surface:)` and the other typed
    /// receipts: Surface metadata is transient and does not survive a keep, so
    /// anything that has to outlive the desk crosses over here, once, as a type.
    static func sightings(from surface: SurfacePage) -> [CreatureSighting]? {
        guard let raw = surface.payload.metadata[Bestiary.metadataKey] else { return nil }
        return Bestiary.decoded(raw)
    }
}

// MARK: - The shelf

/// One creature, and everything the Book can say about having seen it.
struct BestiaryEntry: Identifiable, Equatable {
    var id: String { creature }
    var creature: String
    /// How many photographs it turned up in.
    var count: Int
    /// The surest any pass ever was about it.
    var certainty: VisualCertainty
    /// How often and when, in one line.
    var seenLine: String
    /// Where, using the reader's own names for their places. Nil when none of
    /// the photographs were taken near somewhere they've named.
    var whereLine: String?
    /// A pattern in the sightings, if there is one. The same noticings the
    /// Gazetteer uses about places: they turn out to be about any set of Pages.
    var noticing: String?
}

extension Bestiary {

    /// Everything alive the Book has kept, most-seen first.
    ///
    /// Reads the archive rather than a second ledger, the same way the Gazetteer
    /// does. A creature's history *is* the Pages it appears on.
    static func entries(
        days: [BookDay],
        anchors: [AnchorRecord] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BestiaryEntry] {
        var names: [String: String] = [:]
        for anchor in anchors { names[anchor.id] = anchor.name }

        var pagesByCreature: [String: [BookPage]] = [:]
        var surest: [String: VisualCertainty] = [:]
        for day in days {
            for page in day.pages {
                for sighting in page.creatureSightings ?? [] {
                    pagesByCreature[sighting.creature, default: []].append(page)
                    let held = surest[sighting.creature]
                    if held == nil || sighting.certainty > held! {
                        surest[sighting.creature] = sighting.certainty
                    }
                }
            }
        }

        var entries: [BestiaryEntry] = []
        for (creature, unsorted) in pagesByCreature {
            let pages = unsorted.sorted { $0.createdAt < $1.createdAt }
            guard let first = pages.first, let last = pages.last else { continue }
            let places = pages
                .compactMap { $0.context?.nearbyAnchorID?.nonEmpty }
                .compactMap { names[$0] }
            entries.append(BestiaryEntry(
                creature: creature,
                count: pages.count,
                certainty: surest[creature] ?? .likely,
                seenLine: seenLine(
                    count: pages.count, first: first.createdAt, last: last.createdAt,
                    now: now, calendar: calendar
                ),
                whereLine: whereLine(places: places, count: pages.count),
                noticing: Gazetteer.sharedWeather(of: pages).map { "Every time, \($0)." }
                    ?? Gazetteer.sharedHour(of: pages).map { "Only ever \($0)." }
            ))
        }
        return entries.sorted { left, right in
            left.count == right.count ? left.creature < right.creature : left.count > right.count
        }
    }

    /// How many photographs the Book has actually looked at.
    ///
    /// The shelf needs this to tell "nobody has looked yet" from "we looked and
    /// nothing alive was in any of them", which are different things to say to
    /// somebody, and only one of them is the reader's fault.
    static func photographsExamined(in days: [BookDay]) -> Int {
        days.flatMap(\.pages).filter { $0.creatureSightings != nil }.count
    }

    static func seenLine(
        count: Int,
        first: Date,
        last: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
            && calendar.isDate(first, equalTo: last, toGranularity: .year)
        if count == 1 {
            return "Once, in \(monthLabel(first, now: now, calendar: calendar))."
        }
        let counted = GrimoireVoice.spelled(count)
        let times = counted.prefix(1).uppercased() + counted.dropFirst()
        if sameMonth {
            return "\(times), all in \(monthLabel(last, now: now, calendar: calendar))."
        }
        return "\(times), from \(monthLabel(first, now: now, calendar: calendar)) to \(monthLabel(last, now: now, calendar: calendar))."
    }

    /// Where, from the reader's own names for their places. Never a street and
    /// never a business: an Anchor's name is the one the reader chose, and it's
    /// the only place-word the Book is free to print without asking.
    static func whereLine(places: [String], count: Int) -> String? {
        let distinct = Array(Set(places)).sorted()
        switch distinct.count {
        case 0: return nil
        case 1 where count >= 3: return "Always at \(distinct[0])."
        case 1: return "At \(distinct[0])."
        case 2: return "At \(distinct[0]) and \(distinct[1])."
        default:
            let rest = distinct.count - 2
            return "At \(distinct[0]), \(distinct[1]), and \(rest == 1 ? "one other place" : "\(rest) other places") you've named."
        }
    }

    /// The year is only worth saying when it isn't this one.
    static func monthLabel(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let name = monthFormatter.string(from: date)
        let year = calendar.component(.year, from: date)
        return year == calendar.component(.year, from: now) ? name : "\(name) \(year)"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    /// The Contents line. No count: that line is redrawn on every desk build.
    static let contentsDetail = "Everything alive that has turned up in your photographs."
}
