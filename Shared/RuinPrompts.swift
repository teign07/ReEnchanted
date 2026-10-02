import Foundation

// MARK: - Ruin pages
//
// Some pages of every printed book are built to be handled: scribbled on,
// torn out, stained, folded, taped shut. The reader photographs what they did
// and the Book answers. Print on demand rules out die-cuts and inserts, so
// everything here is pens, scissors, tape, thumbs and a cup of tea.
//
// Guards, held by tests: no fire, nothing that soaks the binding, nothing for
// children, and a leaf is two faces, so whatever happens to one face must be
// survivable by the other.

enum RuinKind: String, Codable, CaseIterable, Equatable {
    // Gentle: safe on any face, whatever the other face is doing.
    case scribble, draw, trace, write
    // Rougher: these change the paper, so they need a face to themselves.
    case tearOut, stain, rubbing, press, fold, tape, collage

    var isGentle: Bool {
        switch self {
        case .scribble, .draw, .trace, .write: return true
        default: return false
        }
    }

    /// A page the reader will probably take out of the book.
    var leavesTheBook: Bool { self == .tearOut }
}

struct RuinPrompt: Codable, Equatable, Identifiable {
    var id: String
    var kind: RuinKind
    var title: String
    /// The Book talking: one to three plain sentences.
    var instruction: String
}

/// One leaf: the two faces a reader gets for a single sheet of paper.
struct RuinLeaf: Codable, Equatable, Identifiable {
    var front: RuinPrompt
    /// What the back of the sheet asks. For a page that will be torn out it is
    /// the companion face ("it goes with the page"), so nothing is lost twice.
    var back: RuinPrompt
    var id: String { front.id }
}

// MARK: - Guards and packs

enum RuinGuards {
    /// Nothing that burns, soaks a binding, cuts a stranger or is for children.
    static let bannedWords = [
        "fire", "flame", "burn", "candle", "match", "lighter", "knife", "blade", "bleach", "soak", "pour",
        "drink", "wine", "beer", "swallow", "eat ", "ritual", "kid", "child"
    ]
    static let maximumInstructionLength = 240

    /// Why a prompt may not be printed. Empty means it may. Runs on every
    /// prompt a pack delivers, so a future edition cannot ship a page that
    /// breaks the guards the core library keeps.
    static func violations(in prompt: RuinPrompt) -> [String] {
        var found: [String] = []
        let text = (prompt.title + " " + prompt.instruction).lowercased()
        for word in bannedWords where text.contains(word) { found.append("says \"\(word)\"") }
        if prompt.id.isEmpty { found.append("has no id") }
        if prompt.title.trimmingCharacters(in: .whitespaces).isEmpty { found.append("has no title") }
        if prompt.instruction.trimmingCharacters(in: .whitespaces).isEmpty { found.append("has no instruction") }
        if prompt.instruction.count > maximumInstructionLength { found.append("is too long") }
        return found
    }
}

/// Ruin prompts that arrive with a month's content pack: themed to its story,
/// and shown only in the months it names. A pack that fails the guards
/// contributes nothing, and a prompt that fails them is dropped alone.
struct RuinPromptPack: Codable, Equatable, Identifiable {
    var id: String
    var version: Int
    var prompts: [RuinPrompt]
    /// Calendar months (1...12) the pack's prompts may appear in. Nil is any month.
    var months: [Int]? = nil

    static let fileSuffix = ".ruinpack.json"

    func appliesTo(month: Int) -> Bool { months?.contains(month) ?? true }

    /// The prompts that pass the guards and do not shadow a core prompt.
    var usablePrompts: [RuinPrompt] {
        let coreIDs = Set(RuinLibrary.prompts.map(\.id))
        return prompts.filter { RuinGuards.violations(in: $0).isEmpty && !coreIDs.contains($0.id) }
    }
}

enum RuinLibrary {
    static let prompts: [RuinPrompt] = gentle + rough

    /// Packs dropped in by the content-pack channels, newest version of each id.
    static func installedPacks(fileManager: FileManager = .default) -> [RuinPromptPack] {
        let decoder = ContentPackFileLocator.decoder()
        var newest: [String: RuinPromptPack] = [:]
        for url in ContentPackFileLocator.urls(suffix: RuinPromptPack.fileSuffix, fileManager: fileManager) {
            guard let data = try? Data(contentsOf: url),
                  let pack = try? decoder.decode(RuinPromptPack.self, from: data),
                  !pack.id.isEmpty, pack.version > 0 else { continue }
            if let existing = newest[pack.id], existing.version >= pack.version { continue }
            newest[pack.id] = pack
        }
        return newest.values.sorted { $0.id < $1.id }
    }

    /// Everything a book printed in `month` may draw from: the core library
    /// and any installed pack that applies, ids unique.
    static func available(month: Int, packs: [RuinPromptPack]? = nil) -> [RuinPrompt] {
        var all = prompts
        var seen = Set(all.map(\.id))
        for pack in packs ?? installedPacks() where pack.appliesTo(month: month) {
            for prompt in pack.usablePrompts where seen.insert(prompt.id).inserted { all.append(prompt) }
        }
        return all
    }

    // MARK: Gentle

    static let gentle: [RuinPrompt] = [
        .init(id: "scribble-the-grey", kind: .scribble, title: "Scribble the grey",
              instruction: "Take your darkest pen and scribble over this whole page until it's as grey as your worst week. Press hard. I can take it."),
        .init(id: "draw-the-rut", kind: .draw, title: "Draw the Rut",
              instruction: "Draw the Rut. Give it teeth. Give it a hat. Everybody's is a little bit silly once it's on paper."),
        .init(id: "draw-a-door", kind: .draw, title: "A door",
              instruction: "Draw a door. It doesn't have to be good. Then draw what's behind it, the thing you've never told anybody."),
        .init(id: "trace-your-hand", kind: .trace, title: "Trace your hand",
              instruction: "Put your hand flat on the page and trace round it. On each finger, write one thing that hand did today."),
        .init(id: "map-of-your-chair", kind: .draw, title: "A map of your chair",
              instruction: "Draw the room you're in, from above. Mark where the Curse sits. It's usually next to the phone."),
        .init(id: "other-hand", kind: .write, title: "The other hand",
              instruction: "Write today's date with the hand you don't write with. Then write what you had for lunch. Go slowly. Let it be ugly."),
        .init(id: "everything-on-the-table", kind: .write, title: "Everything on the table",
              instruction: "List everything on the table in front of you. Don't skip the crumbs. The crumbs are the good part."),
        .init(id: "give-it-a-face", kind: .draw, title: "Give it a face",
              instruction: "Draw a face on the most boring thing within reach, right here on the page. Then give it a name. It's been waiting."),
        .init(id: "note-for-the-next-hand", kind: .write, title: "A note for the next hand",
              instruction: "Write a note to whoever holds this book after you. Don't sign it. Leave the book where they'll find it."),
        .init(id: "draw-your-foot", kind: .draw, title: "Your foot, unseen",
              instruction: "Draw your own foot without looking at the page. Look at the foot the whole time. Then look. Isn't it strange?"),
        .init(id: "street-from-memory", kind: .draw, title: "Your street, from memory",
              instruction: "Draw your street from memory. Then go outside and look. Add everything you forgot in a different colour."),
        .init(id: "a-lie-and-two-truths", kind: .write, title: "Two truths and a lie",
              instruction: "Write three sentences about today. Make one of them a lie. Don't mark which. I'll find out anyway."),
        .init(id: "sounds-as-a-menu", kind: .write, title: "The sounds, as a menu",
              instruction: "Listen for a full minute. Then write what you heard as if it were a menu, with prices."),
        .init(id: "weather-for-your-mood", kind: .write, title: "A forecast for you",
              instruction: "Write a weather report for how you're doing right now. Put in a warning. Put in a small good chance of sun."),
        .init(id: "seven-in-a-minute", kind: .write, title: "Seven in a minute",
              instruction: "Set a timer for one minute. Write seven things you noticed on the way here. If you only get four, that's four more than the Rut wanted."),
        .init(id: "colour-the-margins", kind: .scribble, title: "Colour the margins",
              instruction: "Colour in all four margins of this page. Use any colour that isn't brown. Brown is the Rut's."),
        .init(id: "letter-you-wont-send", kind: .write, title: "The letter you won't send",
              instruction: "Write to somebody you miss. Say the thing. Then close the book on it. You don't have to send it. It's just got to exist."),
        .init(id: "underline-and-copy", kind: .write, title: "Underline it, then copy it wrong",
              instruction: "Find one sentence anywhere in this book that you'd keep. Underline it. Then copy it out here, and change one word on purpose."),
        .init(id: "recipe-for-tuesday", kind: .write, title: "A recipe for Tuesday",
              instruction: "Write a recipe for an ordinary Tuesday. Put in amounts. Two cups of waiting. A pinch of the bus."),
        .init(id: "scribble-a-storm", kind: .scribble, title: "A storm, in pen",
              instruction: "Scribble a storm. Use the whole page. Let it get away from you. When you stop, find the one calm spot in it and put a dot there."),
    ]

    // MARK: Rough

    static let rough: [RuinPrompt] = [
        .init(id: "tear-and-give", kind: .tearOut, title: "Tear this out and give it away",
              instruction: "Rip this page out. Not neatly. Write a name on the back and give it to that person today. Tell them it's from me."),
        .init(id: "tear-in-four", kind: .tearOut, title: "In four pieces",
              instruction: "Tear this page into four. Hide each piece somewhere you'll come across it by Friday: a pocket, a shoe, a library book."),
        .init(id: "tear-a-wish", kind: .tearOut, title: "A wish for nobody to find",
              instruction: "Write one wish on this page. Tear it out. Put it where nobody looks, behind a clock or in a coat. Don't tell me where. I'm not allowed to peek."),
        .init(id: "paper-plane", kind: .tearOut, title: "A plane",
              instruction: "Tear this out and fold it into a plane. Throw it. Go and look at where it landed. Take a picture of the spot."),
        .init(id: "tear-a-bookmark", kind: .tearOut, title: "A bookmark for someone",
              instruction: "Tear off a strip along the dotted line. Write one line on it. Slip it into a book that somebody else is reading."),
        .init(id: "tea-ring", kind: .stain, title: "A tea ring",
              instruction: "Put a damp cup down on this page, once. Just once. When it's dry, turn the ring into a map of somewhere."),
        .init(id: "ink-thumbprints", kind: .stain, title: "A garden of thumbs",
              instruction: "Rub a pen onto your thumb and press it all over this page. Turn every print into a creature. Give each one a job."),
        .init(id: "coin-rubbing", kind: .rubbing, title: "A rubbing",
              instruction: "Put this page over a coin, a key, or a leaf, and rub with the side of a pencil. Whatever comes up is yours now."),
        .init(id: "bark-rubbing", kind: .rubbing, title: "The street, rubbed",
              instruction: "Take this page outside. Rub it over three different things, a wall, a drain cover, a tree. Label what came up."),
        .init(id: "pressed-leaf", kind: .press, title: "Press a leaf",
              instruction: "Find a leaf or a flower. Lay it flat on this page and shut the book. Leave it a week. Write what it was before you forget."),
        .init(id: "fold-it-small", kind: .fold, title: "Fold it small",
              instruction: "Fold this page until it's as small as a stamp. Carry it for a whole day. Then open it up and look at what the creases did."),
        .init(id: "crumple-map", kind: .fold, title: "A crumpled map",
              instruction: "Crumple this page into a ball. Squash it. Open it out again, and draw along the creases. They're rivers now."),
        .init(id: "tape-it-shut", kind: .tape, title: "Tape it shut",
              instruction: "Tape this page to the one in front of it, along the edge. Don't peek for a week. I'll still be here. I'll just be quiet."),
        .init(id: "tape-a-pocket", kind: .tape, title: "A pocket",
              instruction: "Tape three sides of a small piece of paper to this page to make a pocket. Put something in it that you'd hate to lose."),
        .init(id: "stick-a-ticket", kind: .collage, title: "Stick it in",
              instruction: "Stick something here that you'd normally throw away: a ticket, a receipt, a label off a jar. Write why it nearly got binned."),
        .init(id: "collage-your-week", kind: .collage, title: "Your week, in scraps",
              instruction: "Tear or cut scraps from anything you've got, a magazine, an envelope, a wrapper. Stick them down to make this week."),
        .init(id: "cut-a-window", kind: .collage, title: "Cut a window",
              instruction: "Cut a small window in this page with scissors. Look at the page behind it through the hole. Write what the window picked."),
        .init(id: "wrap-something", kind: .fold, title: "Wrap something small",
              instruction: "Fold this page around something small that you carry. Write what's inside on the outside. Give it to somebody."),
        .init(id: "stamp-a-spot", kind: .stain, title: "A cup, a pen, a spot",
              instruction: "Dab a damp teabag on the page, just once, lightly. Let it dry. Find the shape in the stain and draw round it."),
        .init(id: "tear-the-corner", kind: .tearOut, title: "Tear one corner",
              instruction: "Tear one corner off this page. Keep it in your pocket until something reminds you why. Then write that reminder here."),
    ]
}

// MARK: - Choosing leaves

enum RuinPlan {
    /// A book's leaves, in the order they'll fall. The same binding always
    /// gets the same leaves. No two neighbouring fronts share a kind, and the
    /// back of a leaf is always something the front cannot spoil.
    static func leaves(count: Int, seed: String, from pool: [RuinPrompt] = RuinLibrary.prompts) -> [RuinLeaf] {
        guard count > 0 else { return [] }
        var fronts = rank(pool.filter { !$0.kind.isGentle }, seed: "\(seed)|front")
        var backs = rank(pool.filter { $0.kind.isGentle }, seed: "\(seed)|back")
        var chosen: [RuinLeaf] = []
        var lastKind: RuinKind?
        while chosen.count < count, !fronts.isEmpty {
            // The next front whose kind differs from the last, if one exists.
            let index = fronts.firstIndex { $0.kind != lastKind } ?? 0
            let front = fronts.remove(at: index)
            lastKind = front.kind
            guard let back = backs.first else { break }
            backs.removeFirst()
            chosen.append(RuinLeaf(front: front, back: back))
        }
        return chosen
    }

    private static func rank(_ prompts: [RuinPrompt], seed: String) -> [RuinPrompt] {
        prompts.sorted {
            let a = HandbookBuilder.stableHash("\(seed)|\($0.id)"), b = HandbookBuilder.stableHash("\(seed)|\($1.id)")
            return a == b ? $0.id < $1.id : a < b
        }
    }
}
