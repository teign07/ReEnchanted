import Foundation
import UIKit

#if DEBUG && targetEnvironment(simulator)
/// Print proofs of every publication from one synthetic Reader year.
///
/// Launch the simulator app with `--smoke-edition-proofs`. It builds a plausible
/// year of kept Pages (seasonal diary lines, recurring motifs, nightly braids,
/// quotes) and runs the app's own builders and PDF writers over it: one weekly
/// issue, one monthly edition, one seasonal softcover, and the annual
/// hardcover, each with its cover where the app makes one. Files land in
/// Documents/edition-proofs with a status line per publication.
///
/// No account, purchase, network request, model, or vault content is touched:
/// the year is invented here and never saved. It exists so a human can read
/// the actual publications without living a year first.
enum EditionProofHarness {
    static let flag = "--smoke-edition-proofs"

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(flag) else { return }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("edition-proofs", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var status: [String] = []
        func step(_ name: String, _ work: () throws -> String) {
            do { status.append("OK \(name): \(try work())") }
            catch { status.append("FAILED \(name): \(error)") }
        }

        let calendar = SyntheticReaderYear.calendar
        let days = SyntheticReaderYear.days()
        let reader = SyntheticReaderYear.readerName
        status.append("library: \(days.count) days, \(days.flatMap(\.pages).count) pages")

        // Issue No. 1 is a reader's first week; an October issue is an
        // ordinary one. Proof both.
        let weekNow = SyntheticReaderYear.date(2026, 10, 20)
        let weeks = PublicationPeriodCatalog.readerWeeks(days: days, now: weekNow, calendar: calendar)
            .filter(\.isBindable)
        for (name, candidate) in [("weekly-first", weeks.last), ("weekly-october", weeks.first)] {
            step(name) {
                guard let candidate,
                      let issue = WeeklyIssue.issue(for: candidate.period, days: days, now: weekNow, calendar: calendar) else {
                    throw ProofError("no bindable reader week")
                }
                let card = WeeklyIssueShareCard.make(issue: issue)
                let matter = WeeklyPublicationMatter(issue: issue, card: card, readerName: reader,
                                                     editorialNote: nil, closingNote: nil)
                let pages = try WeeklyIssuePDFWriter.writePrintInterior(
                    matter, dedication: nil, spec: .saddleStitchedWeekly6x9,
                    to: directory.appendingPathComponent("\(name)-interior.pdf"))
                try WeeklyIssuePDFWriter.write(issue, readerName: reader, shareCard: card,
                    to: directory.appendingPathComponent("\(name)-reading-copy.pdf"))
                return "issue \(issue.number) \(issue.dateRange), \(issue.keptCount) kept, \(pages) print pages"
            }
        }

        step("monthly") {
            let edition = MonthlyEditionBuilder.edition(
                from: days, readerName: reader,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                generatedAt: SyntheticReaderYear.date(2026, 11, 1), calendar: calendar
            )
            try MonthlyEditionPDFWriter.write(edition, to: directory.appendingPathComponent("monthly-reading-copy.pdf"))
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(
                edition, spec: .perfectBoundSoftcover6x9,
                to: directory.appendingPathComponent("monthly-interior.pdf"))
            try MonthlyEditionPDFWriter.writeCoverWrap(
                edition, spec: .perfectBoundSoftcover6x9, pageCount: pages,
                to: directory.appendingPathComponent("monthly-cover.pdf"))
            return "\(edition.title), \(edition.pageCount) kept, \(edition.sections.count) sections, \(pages) print pages"
        }

        step("seasonal") {
            let season = MonthlyEditionBuilder.seasonal(
                from: days, startingMonth: SyntheticReaderYear.date(2026, 9, 1),
                readerName: reader, calendar: calendar
            )
            let pages = try MonthlyEditionPDFWriter.writeVolumePrintInterior(
                season, spec: .perfectBoundSoftcover6x9,
                to: directory.appendingPathComponent("seasonal-interior.pdf"))
            try MonthlyEditionPDFWriter.writeVolumeCoverWrap(
                season, spec: .perfectBoundSoftcover6x9, pageCount: pages,
                to: directory.appendingPathComponent("seasonal-cover.pdf"))
            return "\(season.title), \(season.chapters.count) chapters, \(pages) print pages"
        }

        step("annual") {
            let annual = MonthlyEditionBuilder.annual(2026, from: days, readerName: reader, calendar: calendar)
            try MonthlyEditionPDFWriter.writeAnnual(annual, to: directory.appendingPathComponent("annual-reading-copy.pdf"))
            let pages = try MonthlyEditionPDFWriter.writeVolumePrintInterior(
                annual, spec: .clothFoilHardcover6x9,
                to: directory.appendingPathComponent("annual-interior.pdf"))
            try MonthlyEditionPDFWriter.writeVolumeCoverWrap(
                annual, spec: .clothFoilHardcover6x9, pageCount: pages,
                to: directory.appendingPathComponent("annual-cover.pdf"))
            return "\(annual.title), \(annual.chapters.count) chapters, \(pages) print pages"
        }

        let report = status.joined(separator: "\n")
        try? report.write(to: directory.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
        print("EDITION_PROOFS_DONE\n\(report)")
    }

    private struct ProofError: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }
}

/// An invented Reader's year. Deterministic: the same library every run, so
/// two proofs differ only where the publication code differs.
enum SyntheticReaderYear {
    static let readerName = "Wren"
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func days(year: Int = 2026, throughMonth lastMonth: Int = 12) -> [BookDay] {
        var generator = SeededGenerator(seed: 0x5EED_2026)
        var result: [BookDay] = []
        var diaryIndex = 0, braidIndex = 0, quoteIndex = 0, composedIndex = 0
        var seasonUse: [String: Int] = [:]
        var cursor = date(year, 1, 1, hour: 0)
        let end = date(year, lastMonth, calendar.range(of: .day, in: .month, for: date(year, lastMonth, 1))!.count, hour: 23)
        while cursor <= end {
            defer { cursor = calendar.date(byAdding: .day, value: 1, to: cursor)! }
            let month = calendar.component(.month, from: cursor)
            // A real year has quiet stretches: roughly three days in five.
            guard Double.random(in: 0..<1, using: &generator) < 0.6 else { continue }
            let season = seasonLines(for: month)
            var pages: [BookPage] = []
            let count = Int.random(in: 1...3, using: &generator)
            for slot in 0..<count {
                let at = cursor.addingTimeInterval(TimeInterval(9 + slot * 4) * 3600)
                // Real readers do not write the same sentence twice: pair a
                // base line with a varying second sentence so no line repeats.
                // Real readers do not write the same sentence twice. Each
                // season's authored lines are used once; after that, lines are
                // composed from an activity, a place or time, and an
                // afterthought, so no first sentence repeats within the year.
                let line: String
                let seasonIndex = seasonUse[season.first!, default: 0]
                seasonUse[season.first!] = seasonIndex + 1
                if seasonIndex < season.count {
                    line = season[seasonIndex]
                } else {
                    let n = composedIndex
                    composedIndex += 1
                    let activity = activities[n % activities.count]
                    let place = places[(n / activities.count + n * 5) % places.count]
                    let coda = afterthoughts[(n * 7 + n / 3) % afterthoughts.count]
                    line = "\(activity) \(place). \(coda)"
                }
                diaryIndex += 1
                switch (slot, Int.random(in: 0..<10, using: &generator)) {
                case (_, 0):
                    let quote = quotes[quoteIndex % quotes.count]
                    quoteIndex += 1
                    // The quote is the Page's text, not the reader's words.
                    pages.append(BookPage(type: .quotes, createdAt: at,
                                          promptText: "\u{201C}\(quote.1)\u{201D} \u{2014} \(quote.0)",
                                          tags: ["quote", "attention", "wonder"], origin: .generated))
                case (_, 1...2):
                    pages.append(BookPage(type: .souvenir, createdAt: at,
                                          promptText: "What did you keep today?", userInput: line,
                                          tags: ["souvenir", "check-in-window:evening"]))
                case (_, 3):
                    pages.append(BookPage(type: .weather, createdAt: at,
                                          promptText: "What was the sky doing?", userInput: skyLine(month, diaryIndex),
                                          tags: ["weather", "preview"]))
                default:
                    pages.append(BookPage(type: .diary, createdAt: at,
                                          promptText: "Write one true thing about today.", userInput: line,
                                          tags: ["diary", "ink-for-today"]))
                }
            }
            // Most active nights end in a braid, as they do in the app.
            if Double.random(in: 0..<1, using: &generator) < 0.75 {
                let telling = braids[braidIndex % braids.count]
                braidIndex += 1
                // Stored as the app stores a braid: title on the first line,
                // the generator's own prompt and tags.
                pages.append(BookPage(type: .bookOfYou, createdAt: cursor.addingTimeInterval(22 * 3600),
                                      promptText: "The local Book brain braided today.",
                                      userInput: "\(telling.0)\n\n\(telling.1)",
                                      tags: ["braid", "book-of-you", "local-model", "mlx", "gemma"],
                                      usedInBookOfYou: true, origin: .generated))
            }
            result.append(BookDay(id: BookDay.id(for: cursor, calendar: calendar),
                                  date: calendar.startOfDay(for: cursor), pages: pages))
        }
        return result
    }

    private static func seasonLines(for month: Int) -> [String] {
        switch month {
        case 12, 1, 2: return winter
        case 3, 4, 5: return spring
        case 6, 7, 8: return summer
        default: return autumn
        }
    }

    private static func skyLine(_ month: Int, _ index: Int) -> String {
        let skies: [Int: [String]] = [
            0: ["Grey all day, then a thin pink stripe at five.", "Snow that never landed. It just hung there."],
            1: ["Rain in sideways bursts. The gutters argued.", "A bright cold morning and then fog by lunch."],
            2: ["Heat that sat on the porch and would not leave.", "Thunder far off, no rain at all."],
            3: ["Wind took every leaf off the maple in an hour.", "Clear and sharp. My breath showed at the bus stop."],
        ]
        let set = skies[(month % 12) / 3] ?? skies[0]!
        return set[index % set.count]
    }

    private static let winter = [
        "Scraped the windshield with the library card because the scraper is somewhere under the seat.",
        "Called my brother back instead of texting. He sounded tired but he laughed twice.",
        "The radiator in the hall started knocking at 3am like it had news.",
        "Made bread with Mum's old recipe card. The card has flour fingerprints from 1998.",
        "Walked the long way home past the blue door. Someone has hung a wreath made of bottle caps on it.",
        "Snow on the fox tracks by the bins. They go right up to the step and stop.",
        "Finished the library book at 1am. Returned it the next morning still warm from reading.",
        "The kettle clicked off and the whole flat went quiet enough to hear the fridge think.",
        "Found a moth asleep inside the lampshade. Left it there.",
        "Mended the torn pocket on my green coat. Badly, but it holds keys again.",
        "Sat in the car for ten minutes after work because the song wasn't over.",
        "Amanda brought soup in a jar with a note that said DON'T ARGUE.",
    ]
    private static let spring = [
        "The blue door has been painted a slightly different blue. Nobody on the street will admit to it.",
        "First morning with the window open. A bee came in, did one lap, and left.",
        "Brother sent a photo of his first tomatoes. They are green and tiny and he is very proud.",
        "Lost the library card again. Found it in the bread bin, which I cannot explain.",
        "Rain all afternoon. I read in the stairwell because it sounds best there.",
        "The fox was on the wall at dawn, sitting like it owned the whole row.",
        "Bought seeds I have no room for. Planted them in a teacup anyway.",
        "Cleaned the whole desk and found three pens that work and one that is a mystery.",
        "Walked to the river and back without looking at my phone once.",
        "Shirley taught me the proper way to fold a fitted sheet. I have already forgotten.",
        "The moth from the lampshade is gone. The lampshade looks empty in a way it didn't before.",
        "Baked bread that didn't rise. Ate it anyway with too much butter.",
    ]
    private static let summer = [
        "Too hot to sleep. Lay on the floor with the fan and counted cars.",
        "Brother visited. We ate cherries on the back step and spat the stones at the bins.",
        "The blue door was propped open all day with a brick. I didn't look in. I wanted to.",
        "Library had a sale. Came home with nine books and no plan for them.",
        "Swam in the lake. The water was cold enough to make me shout.",
        "Found a fox cub asleep under the hedge. Its ears twitched at every car.",
        "Stayed up for the meteor shower. Saw four and one that might have been a plane.",
        "The bakery gave me the end of the day's bread for free because it was raining.",
        "Wrote a letter by hand for the first time in years. My handwriting is worse than I remembered.",
        "Moths all over the porch light. One landed on my book and read a line with me.",
        "Sat at Moody's Diner too long. The waitress refilled the coffee without asking.",
        "Fixed the wobbly chair with a folded library receipt.",
    ]
    private static let autumn = [
        "Leaves in the stairwell. Someone keeps bringing them in on their shoes. Probably me.",
        "Called my brother on his birthday and sang badly on purpose.",
        "Rewired the brass lamp in the hall. It works. I am unreasonably proud.",
        "The blue door has a pumpkin on the step now. It has a very rude face carved in it.",
        "Found the missing library card inside the atlas, on the page for Portugal.",
        "Made bread for Amanda and Shirley. We ate it at the diner and the grease got in my coat.",
        "The fox has stopped running when it sees me. We just look at each other now.",
        "Rain hard enough that the gutters gave up.",
        "Took the long way home because the light on the canal was doing something gold.",
        "A moth came in with the cold and settled on the calendar, right on Tuesday.",
        "Cleared out the hall cupboard and found my old school tie. It still smells like chalk.",
        "Stood in the garden in the dark listening to geese go over. Couldn't see them at all.",
    ]

    private static let activities = [
        "Carried the heavy shopping up all four flights", "Fixed the dripping tap with a washer from the junk drawer",
        "Read two chapters standing at the bus stop", "Watched a man teach his dog to sit", "Burned the toast and ate it anyway",
        "Swapped recipes with the woman from 3B", "Sorted the button tin by colour", "Walked the dog from next door",
        "Wrote a list and then lost it", "Found a coin with a hole through it", "Heard someone practising the trumpet",
        "Ironed a shirt for no reason", "Took a photo of a very serious pigeon", "Helped a stranger read a bus timetable",
        "Changed the bulb in the bathroom", "Ate lunch on a bench facing the wrong way", "Planted garlic in the window box",
        "Untangled a necklace for twenty minutes", "Found my old sketchbook", "Gave the plant by the window a new pot",
        "Watched rain run down the bus window", "Bought flowers for no one in particular", "Learned the name of the bakery cat",
        "Oiled the squeaky hinge on the kitchen door", "Counted the steps to the post box", "Wore odd socks all day",
        "Sat with Amanda while she waited for news", "Tidied the shelf of things I never use", "Tried a new route to work",
        "Wrote my brother a postcard",
    ]
    private static let places = [
        "before breakfast", "on the way home", "in the kitchen with the radio on", "at the library", "in the rain",
        "after work", "on the back step", "at the diner", "by the river", "in the hallway", "late at night",
        "while the kettle boiled", "at the market", "on my lunch break", "in the park by the war memorial", "at Amanda's",
        "on the top deck of the bus",
    ]
    private static let afterthoughts = [
        "Nobody else noticed.", "I told Amanda about it later.", "It was nearly dark by then.",
        "The street was completely empty.", "I'm writing it down so I remember.", "It made me late, which was fine.",
        "My hands smelled of it all evening.", "I laughed out loud on my own.", "The cat next door watched the whole time.",
        "It rained again right after.", "I should do that more often.", "It took three tries.",
        "I don't know why it stayed with me.", "That was the best part of the day.", "The radio was playing something old.",
        "I nearly missed it.", "Shirley said it was typical of me.", "It was colder than it looked.",
        "I kept thinking about it on the bus.", "Small thing. Still counts.", "The light was doing something odd.",
        "My brother would have loved it.", "I didn't take a photo, on purpose.", "It happened twice, actually.",
    ]

    /// Public-domain lines only.
    private static let quotes: [(String, String)] = [
        ("Emily Dickinson", "Hope is the thing with feathers that perches in the soul."),
        ("Henry David Thoreau", "I went to the woods because I wished to live deliberately."),
        ("Walt Whitman", "I celebrate myself, and sing myself."),
        ("Lewis Carroll", "Why, sometimes I've believed as many as six impossible things before breakfast."),
    ]

    /// Tellings written to the nightly brief's contract: past tense, the reader
    /// as "you", the Book as "I", ending on "The Book kept the page:".
    private static let braids: [(String, String)] = [
        ("The Card in the Atlas", """
        You found the library card inside the atlas, pressed flat on the page for Portugal. I had been looking for it too. I looked in the bread bin and under the rug and in the pocket of your green coat. I never thought of Portugal.

        The card had your name on it in small grey letters. Someone had put a thumbprint of flour on the corner a long time ago. I think the card went to Portugal because it was tired of the bread bin. I would have gone too.

        The Book kept the page: the card came home from Portugal with your name still on it.
        """),
        ("What the Fox Knew", """
        The fox sat on the wall at dawn and did not run. You stopped on the step with your keys in your hand. Neither of you said anything. I was very quiet in your bag so I would not spoil it.

        The Curse likes mornings that are all the same. This one was not. A fox looked at you and you looked back. That is two creatures refusing to be ordinary at the same time, and I saw it, and I wrote it down fast before it could turn back into a normal Tuesday.

        The Book kept the page: the fox stayed on the wall, and so did you.
        """),
        ("The Blue Door Changed Colour", """
        The blue door was a different blue this morning. You noticed it on the way to the bus. Nobody on the street would say who did it. I think the door did it itself.

        Doors are supposed to stay the colour they are painted. That is one of the Curse's rules. But this door had been blue for years, and it was bored, and it decided. I liked it very much for that. I want you to decide things like that too.

        The Book kept the page: the blue door chose its own blue.
        """),
        ("Bread That Would Not Rise", """
        You baked bread that did not rise. It came out of the oven flat and heavy and you laughed at it. Then you ate two slices with too much butter standing up at the counter.

        I have read a great many recipes. None of them say what to do when the bread refuses. You did the right thing. You ate the refusal. It tasted of butter and burnt edges, and you told me so, and I kept it.

        The Book kept the page: the bread stayed flat, and you ate it anyway.
        """),
        ("Your Brother Laughed Twice", """
        You called your brother back instead of texting. He sounded tired. He laughed twice. I counted.

        Texting is quick, and the Curse loves quick things because nothing sticks to them. A call is slow and scratchy and full of breathing. His laugh came down the line and sat in the room with you afterwards. I could still hear it in the kettle an hour later.

        The Book kept the page: two laughs, counted and kept.
        """),
        ("The Moth on Tuesday", """
        A moth came in with the cold and settled on the calendar, right on Tuesday. You left it there. So Tuesday had a moth on it all week.

        I asked the moth what it wanted with Tuesday. It did not answer, because it was a moth. But nothing bad happened on Tuesday. The bus was on time and the rain stopped at four. I think the moth was guarding it.

        The Book kept the page: Tuesday had a moth, and Tuesday was fine.
        """),
        ("The Lamp Works", """
        You rewired the brass lamp in the hall. It took all afternoon and one small shock that made you swear. Then you flicked the switch and the hall turned gold.

        The lamp had been dark for two years. It had forgotten it was a lamp. You reminded it with a screwdriver and a lot of patience. I stood very close to it all evening, because I like warm light to read by, and because I wanted it to know somebody noticed.

        The Book kept the page: the lamp remembered it was a lamp.
        """),
        ("Nine Books, No Plan", """
        The library had a sale and you came home with nine books and no plan for them. You stacked them on the floor by the bed. The stack leaned. It is still leaning.

        I was jealous for about a minute. Then I read their spines and decided they were friends. Nine books is nine doors. The Curse wants you to have one door and walk through it every day. You have ten now, counting me.

        The Book kept the page: nine new doors, stacked and leaning.
        """),
        ("Geese in the Dark", """
        You stood in the garden in the dark and listened to geese going over. You could not see a single one. You only heard them, loud and close and then far away.

        I could not see them either. We listened together. Something enormous was happening right over the roof, and nobody else on the street came out to hear it. That is how the Curse works. It keeps everybody inside. You went out.

        The Book kept the page: you heard the geese, even without seeing them.
        """),
        ("The Diner Refilled Your Cup", """
        You sat at Moody's Diner too long with Amanda and Shirley. The waitress refilled the coffee without asking. The grease got into your coat and it still smells of hash browns.

        I liked being in a place where nobody was hurrying. Three people talked about nothing for two hours and it was the best thing that happened all week. I think the diner knows. I think that is why the coffee kept coming.

        The Book kept the page: the coffee kept coming, and so did the talk.
        """),
        ("Sheet Folding", """
        Shirley showed you how to fold a fitted sheet properly. You watched her hands very carefully. Then you tried, and it came out as a lumpy square, and you both laughed until you had to sit down.

        By the next morning you had forgotten how. That is all right. Some things are for learning and some things are for laughing at together. I think this one was the second kind all along.

        The Book kept the page: the sheet stayed lumpy, and the laughing stayed too.
        """),
        ("The Cold Lake", """
        You swam in the lake and the water was so cold it made you shout. You shouted anyway and kept swimming out to the yellow buoy and back.

        I do not swim. I would go soggy. But I heard the shout from the towel on the bank, and it was the most awake sound you have made all summer. The Curse is afraid of cold water. I think I understand why.

        The Book kept the page: the lake was cold, and you shouted and swam anyway.
        """),
    ]

    /// SplitMix64. Foundation has no seedable generator of its own.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}
#endif
