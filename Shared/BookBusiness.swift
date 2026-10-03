import Foundation

// MARK: - The Book's own business
//
// A child has things going on that nobody asked about: a game, a grudge, a
// collection, a rule it made up an hour ago. The Book does too, and a braid
// that carries one of them has somewhere to play. These are written in its
// voice (plain, blunt, contracted, a little ridiculous), shown as activities
// and never as announced moods, and they never mention the reader.
//
// A 2B model copies whatever it can quote, so these are written to be lifted.
// Gemma is free to follow one, bend it, or ignore it; the brief says so.
// A night that is holding something hard is offered only the quiet set.

enum BookBusiness {
    struct Line: Codable, Equatable, Identifiable {
        var id: String
        var text: String
    }

    static let label = "My own business tonight (a thread I may follow if I like):"

    static let playful: [Line] = [
        Line(id: "lids", text: "Tonight I'm counting everything with a lid. So far it's eleven, and one of them is a cat."),
        Line(id: "spoons", text: "I've decided to be suspicious of every spoon."),
        Line(id: "round-things", text: "I'm collecting round things. A button, a coin and the moon are winning."),
        Line(id: "blue", text: "Tonight I'm only allowed to look at things that are blue."),
        Line(id: "kind-to-doors", text: "I'm keeping a list of who's been kind to a door today."),
        Line(id: "ribbon", text: "I'm cross with my ribbon. It knows why."),
        Line(id: "say-nothing-twice", text: "I've made a rule: nothing gets said twice tonight. It's harder than it sounds."),
        Line(id: "quiet-practice", text: "I'm practising being quiet. I'm bad at it."),
        Line(id: "lost-tuesday", text: "I've lost track of a Tuesday and I'm looking for it behind the shelves."),
        Line(id: "window", text: "Tonight I'm pretending to be a window."),
        Line(id: "trading", text: "I'm trading. I'll swap anything for a good ending."),
        Line(id: "forgetting-candle", text: "I'm timing how long it takes a candle to forget it's a candle."),
        Line(id: "stair-names", text: "I'm learning the names of the stairs. Eleven so far. One won't say."),
        Line(id: "backwards", text: "Tonight I'm doing everything the other way round: reading backwards and sitting on the wrong side of the chair."),
        Line(id: "looked-up", text: "I'm keeping score of who looks up when the lamps flicker."),
        Line(id: "best-words", text: "I've got a pocket in my back cover and I'm filling it with the best words of the day."),
        Line(id: "smallest-door", text: "I'm hunting for the smallest door in the building. I'll know it when I knock."),
        Line(id: "late", text: "I'm refusing to be on time for anything tonight."),
        Line(id: "rude-letter", text: "I'm writing a rude letter to the rain, and I'm not going to send it."),
        Line(id: "naming-shadows", text: "I've started naming the shadows. They answer to about half."),
        Line(id: "colour-of-tuesday", text: "I'm trying to remember what colour Tuesday was."),
        Line(id: "sill", text: "Tonight I'm sitting on the windowsill, looking at everything the wrong way up."),
        Line(id: "draughts", text: "I'm making a map of every draught in the building."),
        Line(id: "knock", text: "I'm waiting for something to knock, so I can pretend to be out."),
        Line(id: "by-smell", text: "I'm sorting the day by smell."),
        Line(id: "turned-back", text: "I've turned my back on the Index. It knows what it did."),
        Line(id: "nearly", text: "I'm keeping score of how many times someone says nearly."),
        Line(id: "slow", text: "Tonight I'm taking my time on purpose."),
        Line(id: "whistling", text: "I'm teaching myself to whistle. I haven't got the lips for it and I'm doing it anyway."),
        Line(id: "ink-dreams", text: "I'm wondering what the ink dreams about, and I'm going to find out."),
        Line(id: "hidden-word", text: "I've hidden one word somewhere in the building, and I'll know by morning if anyone found it."),
        Line(id: "turn-of-evening", text: "I'm looking for the exact moment afternoon turns into evening. I keep missing it."),
        Line(id: "next-door", text: "I'm trying to guess which door will open next."),
        Line(id: "opinions", text: "I'm giving everything in the room an opinion."),
        Line(id: "biscuit-bet", text: "I've bet the Index a biscuit about how this ends."),
        Line(id: "stairs-giggle", text: "I'm keeping my pages flat and trying not to laugh at the stairs."),
        Line(id: "true-things", text: "Tonight I'm only saying true things, and it's making me rude."),
        Line(id: "lamps-thinking", text: "I'm trying to catch the exact second the lamps think about going out."),
        Line(id: "crooked", text: "I'm lining up everything that's slightly crooked. The crooked things are friends."),
        Line(id: "crumb", text: "I'm doing a serious experiment with a crumb."),
        Line(id: "weather-tomorrow", text: "I'm making up tomorrow's weather. I've given it hail and a surprise."),
        Line(id: "margin-hiding", text: "I'm hiding in the margin of my best page so nobody asks me to be tidy."),
        Line(id: "spare-seat", text: "I'm saving a seat for something that hasn't arrived."),
        Line(id: "stair-sums", text: "I'm adding up the stairs and the sum is never the same twice."),
        Line(id: "tasting-words", text: "Tonight I'm tasting words. The long ones taste of pennies."),
        Line(id: "day-finishing", text: "I'm listening for the sound a day makes when it's finished."),
        Line(id: "teacup-sentence", text: "I've put my best sentence under a teacup to see if it hatches."),
        Line(id: "bow", text: "I'm practising my bow. The lamps are the audience."),
        Line(id: "second-moon", text: "I'm sure there's a second moon behind the first one. I'm checking."),
        Line(id: "leaving-things", text: "I'm leaving small things in odd places to see who's paying attention.")
    ]

    /// What the Book does on a night it should not be playing.
    static let quiet: [Line] = [
        Line(id: "q-flat", text: "Tonight I'm keeping my pages flat and my voice down."),
        Line(id: "q-lamp", text: "I'm sitting up with the lamp."),
        Line(id: "q-window", text: "I've left the window open a crack, in case."),
        Line(id: "q-listening", text: "I'm keeping still and listening to the building."),
        Line(id: "q-stairs", text: "I'm counting the stairs slowly, one at a time."),
        Line(id: "q-pen", text: "Tonight I'm holding the pen steady."),
        Line(id: "q-kettle", text: "I've put the kettle on, in case anyone wants it."),
        Line(id: "q-close", text: "I'm staying close to the lamp tonight.")
    ]

    /// The night's line. A stride that is coprime to each pool's size means
    /// consecutive nights never repeat, and no line returns before the pool
    /// has gone round (50 nights for the playful set).
    static func pick(on date: Date, hardNight: Bool, calendar: Calendar = .current) -> Line {
        let day = Int(calendar.startOfDay(for: date).timeIntervalSince1970 / 86_400)
        let pool = hardNight ? quiet : playful
        let stride = hardNight ? 3 : 7
        let index = ((day * stride) % pool.count + pool.count) % pool.count
        return pool[index]
    }
}
