import Foundation

// MARK: - The Book's running threads
//
// A single night's game is charming. A game that comes back is alive: the Book
// puts its best sentence under a teacup on Monday, and on Thursday it hatches.
// A thread is a short arc (four nights) of the Book's own business, written to
// be lifted: each step stands alone in case a night is skipped, and the last one
// pays off.
//
// How it runs, held by tests:
// - A braid that carried step N says so in a tag (`braid-thread:<id>:<N>`), and
//   the next night carries step N+1, as long as that braid was within six days.
// - With no thread running, one starts about three nights in five, never one used
//   in the last fortnight.
// - A hard night plays the quiet set and does not advance the thread. The Book
//   goes on with its game on a kinder night.
// - A re-braid of tonight repeats tonight's step, not the next.
// - Never about the reader, never an announced mood, never funny at anyone's
//   expense.

enum BookThreads {
    struct Thread: Equatable, Identifiable {
        var id: String
        var steps: [String]
    }

    static let tagPrefix = "braid-thread:"
    static let idPrefix = "thread:"
    /// A thread whose last step is older than this is let go.
    static let patienceDays = 6
    /// Long enough that a month's printed book never tells the same game twice.
    static let restDays = 45

    static let all: [Thread] = [
        Thread(id: "teacup", steps: [
            "I've put my best sentence under a teacup to see if it hatches.",
            "The teacup's still down. I tapped it. Something tapped back, or I imagined it.",
            "I've moved the teacup to the warm shelf. Hatching takes patience. I haven't got any, so I'm borrowing the Index's.",
            "The sentence under the teacup hatched. It's small, with the wrong end first. I've named it Whenever."
        ]),
        Thread(id: "stair-names", steps: [
            "I'm learning the names of the stairs. Eleven so far.",
            "The seventh stair told me its name and then asked for it back.",
            "I've started naming the stairs after weather. The top one is Drizzle. It sulks in the sun.",
            "Every stair answers to its name now except one. It says it's thinking. It's been thinking since Tuesday."
        ]),
        Thread(id: "rude-letter", steps: [
            "I'm writing a rude letter to the rain, and I'm not going to send it.",
            "My rude letter to the rain is three pages long. Page two is only the word honestly.",
            "I sent the rude letter. I know. Don't look at me. It went out of the window by itself.",
            "The rain wrote back to my rude letter. It's one drop on the sill, and it's polite about it."
        ]),
        Thread(id: "biscuit-bet", steps: [
            "I've bet the Index a biscuit about how this ends.",
            "The Index wants to see my working for the biscuit bet. I haven't got any working. I've got a feeling.",
            "I've raised the biscuit bet to two biscuits. The Index is pretending not to be tempted.",
            "I lost the bet. The Index ate the biscuit in front of me, slowly, with a book open. I'll remember that."
        ]),
        Thread(id: "lost-tuesday", steps: [
            "I've lost track of a Tuesday.",
            "I've looked behind the shelves, under the stairs and in the teapot. No Tuesday.",
            "Penny says Tuesdays don't get lost, they get borrowed. I'd like to know by who.",
            "Found the lost Tuesday. It was folded into eight in my back cover, with a crumb in it. I've put it back on the calendar. It looks tired."
        ]),
        Thread(id: "smallest-door", steps: [
            "I'm hunting for the smallest door in the building.",
            "Found a door the size of a thumb. It's locked. It has a brass number seven on it.",
            "I've been knocking on the thumb-sized door. Somebody inside coughed.",
            "The door opened a crack. Inside there's a smaller door. I'm going to need a smaller knock."
        ]),
        Thread(id: "hidden-word", steps: [
            "I've hidden one word somewhere in the building, and I'll know by morning if anyone found it.",
            "Somebody moved my hidden word. I know because it's the wrong way up.",
            "I've decided to be pleased about my hidden word being moved. It means somebody's reading the building.",
            "My hidden word came back with another word stuck to it. Now there are two. I don't know whose is whose."
        ]),
        Thread(id: "dragon", steps: [
            "I'm writing a dragon into the margin. A small one.",
            "The dragon has opinions about the margin. It says it's too narrow. It's right.",
            "I've given the dragon a bigger margin. It's asked for a window, a chair and a dry bit of bench.",
            "The dragon's asleep on the page. I closed the book gently around it. It's snoring in the Index's ear. The Index is being brave."
        ]),
        Thread(id: "whistle", steps: [
            "I'm teaching myself to whistle. I haven't got the lips for it and I'm doing it anyway.",
            "I can do half a whistle. It sounds like a kettle thinking.",
            "The lamps whistled back. Or the draught did. We've agreed it was the lamps.",
            "I did a whole whistle. It was one note. It was a good note."
        ]),
        Thread(id: "second-moon", steps: [
            "I'm sure there's a second moon behind the first one. I'm checking.",
            "I checked for the second moon. The first moon is thorough. I couldn't see behind it.",
            "I asked the stairs to hold the ladder so I could look behind the moon. The stairs say they're stairs, not ladders. Fair.",
            "There's a second moon. It's the size of a button, and it's hiding behind a cloud that isn't there."
        ]),
        Thread(id: "back-cover-pocket", steps: [
            "I've got a pocket in my back cover, and I'm filling it with the best words of the day.",
            "The pocket in my back cover is getting heavy. Orchard's in there, and nearly, and one excellent sneeze.",
            "I tipped my back-cover pocket out to count the words. They rolled under the Index and wouldn't come out.",
            "Got them all back except nearly. It's under there somewhere, nearly."
        ]),
        Thread(id: "opinions", steps: [
            "I'm giving everything in the room an opinion.",
            "The chair thinks it's too early. The lamp thinks it's too late. The kettle has no opinion and it's smug about it.",
            "The window has changed its mind about the room. I didn't know windows could.",
            "I asked the door what it thinks of me. It stayed shut. I'm taking that as respect."
        ])
    ]

    struct Running: Equatable {
        var threadID: String
        var step: Int
        var at: Date
    }

    /// The steps carried by recent braids, newest first.
    static func carried(in recentDays: [BookDay], before date: Date, calendar: Calendar) -> [Running] {
        var found: [Running] = []
        for day in recentDays {
            for page in day.pages where page.type == .bookOfYou {
                // Tonight's own braid, if it exists, is being redone: it must not advance itself.
                if calendar.isDate(page.createdAt, inSameDayAs: date) { continue }
                for tag in page.tags where tag.hasPrefix(tagPrefix) {
                    let parts = tag.dropFirst(tagPrefix.count).split(separator: ":").map(String.init)
                    guard parts.count == 2, let step = Int(parts[1]) else { continue }
                    found.append(Running(threadID: parts[0], step: step, at: page.createdAt))
                }
            }
        }
        return found.sorted { $0.at > $1.at }
    }

    static func line(thread: Thread, step: Int) -> BookBusiness.Line {
        BookBusiness.Line(id: "\(idPrefix)\(thread.id):\(step)", text: thread.steps[step])
    }

    /// Tonight's step of a running thread, or the first step of a new one, or
    /// nothing (the ordinary single-night business takes the slot).
    static func pick(
        recentDays: [BookDay],
        on date: Date,
        hardNight: Bool,
        calendar: Calendar = .current,
        threads: [Thread] = BookThreads.all
    ) -> BookBusiness.Line? {
        guard !hardNight else { return nil }
        let history = carried(in: recentDays, before: date, calendar: calendar)
        let patience = date.addingTimeInterval(-Double(patienceDays) * 86_400)

        // A running thread carries on, if it was seen lately and has steps left.
        if let latest = history.first, latest.at >= patience, latest.at < date,
           let thread = threads.first(where: { $0.id == latest.threadID }),
           latest.step + 1 < thread.steps.count {
            return line(thread: thread, step: latest.step + 1)
        }

        // Otherwise one starts about three nights in five.
        let day = Int(calendar.startOfDay(for: date).timeIntervalSince1970 / 86_400)
        guard HandbookBuilder.stableHash("thread|\(day)") % 5 < 3 else { return nil }
        let rest = date.addingTimeInterval(-Double(restDays) * 86_400)
        let recentlyUsed = Set(history.filter { $0.at >= rest }.map(\.threadID))
        let candidates = threads.filter { !recentlyUsed.contains($0.id) }
        guard !candidates.isEmpty else { return nil }
        let chosen = candidates[Int(HandbookBuilder.stableHash("thread-choice|\(day)") % UInt64(candidates.count))]
        return line(thread: chosen, step: 0)
    }
}
