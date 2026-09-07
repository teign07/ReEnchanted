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

    /// The Book's name for a perception label, or nil when the label isn't a
    /// living thing as far as the filing system is concerned.
    static func creature(for label: String) -> String? {
        let normalized = VisualFact.normalized(label)
        guard creatureLabels.contains(normalized) else { return nil }
        return filedAs[normalized] ?? normalized
    }

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
