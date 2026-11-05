import Foundation

// MARK: - The Book's mood, in its ink

/// What the Book's mood does to its lettering: the colour its ink leans toward
/// and how fast new ink runs onto a leaf. Never a word about the mood itself —
/// the weather is shown, not declared (see `BookMood`).
///
/// Only colour and the one-time arrival change. Letter size and spacing never
/// do, so no leaf has to be laid out again, and nothing here animates on its
/// own. A mood is sorted into three strengths, so ink only changes when the
/// mood crosses a step, not as it fades minute by minute.
///
/// The reader's hand is never touched: the mood is the Book's.
struct BookMoodLettering: Equatable, Sendable {
    /// Turn this off and every leaf is back to the plain ink it had before.
    static let isEnabled = true

    let stance: BookStance
    /// 1 faint … 3 strong.
    let strength: Int
    let night: Bool

    init(stance: BookStance, strength: Int, night: Bool) {
        self.stance = stance
        self.strength = max(1, min(3, strength))
        self.night = night
    }

    /// The lettering for the mood in force, or nil when the Book isn't awake
    /// yet (or the whole thing is switched off).
    static func current(interior: BookInteriorState?, now: Date, calendar: Calendar = .current) -> BookMoodLettering? {
        guard isEnabled, let interior, interior.isAwake else { return nil }
        let standing = interior.mood.flatMap { $0.isSpent(at: now) ? nil : $0 }
        let mood = standing ?? .resting(interior.baselineStance, at: now)
        let intensity = max(1, mood.intensity(at: now))
        let strength = intensity <= 2 ? 1 : (intensity == 3 ? 2 : 3)
        return BookMoodLettering(stance: mood.stance, strength: strength, night: BookNight.isNight(at: now, calendar: calendar))
    }

    struct RGB: Equatable, Sendable {
        let red: Double, green: Double, blue: Double

        func mixed(toward other: RGB, by amount: Double) -> RGB {
            let t = max(0, min(1, amount))
            return RGB(red: red + (other.red - red) * t,
                       green: green + (other.green - green) * t,
                       blue: blue + (other.blue - blue) * t)
        }
    }

    /// The ink each mood leans toward. Old inks, fae ones: nothing pastel.
    var hue: RGB {
        let base: RGB
        switch stance {
        case .curious: base = RGB(red: 0.08, green: 0.40, blue: 0.36)     // verdigris
        case .mischievous: base = RGB(red: 0.46, green: 0.10, blue: 0.40)  // foxglove
        case .intent: base = RGB(red: 0.07, green: 0.09, blue: 0.24)       // iron gall
        case .protective: base = RGB(red: 0.44, green: 0.08, blue: 0.10)   // oxblood
        case .pleased: base = RGB(red: 0.60, green: 0.40, blue: 0.06)      // tarnished gold
        case .contrite: base = RGB(red: 0.38, green: 0.36, blue: 0.34)     // ash
        case .hushed: base = RGB(red: 0.20, green: 0.24, blue: 0.36)       // moth
        }
        // Night cools whatever mood is standing, the way a lamp does.
        return night ? base.mixed(toward: RGB(red: 0.14, green: 0.18, blue: 0.32), by: 0.3) : base
    }

    /// How far the Book's printed text leans toward the mood. Kept small: print
    /// has to stay easy to read on any paper.
    var printLean: Double {
        [0.14, 0.24, 0.34][strength - 1]
    }

    /// How far its handwritten margins lean. The hand is where a mood shows.
    var handLean: Double {
        [0.32, 0.50, 0.68][strength - 1]
    }

    /// A tired or sorry Book presses less hard.
    var inkOpacity: Double {
        var opacity = 1.0
        if stance == .contrite || stance == .hushed { opacity -= 0.05 * Double(strength) }
        if night { opacity -= 0.05 }
        return max(0.8, opacity)
    }

    /// How long new ink takes to run onto a leaf, against the usual time.
    /// Below 1 is quicker (a pleased or mischievous Book can't wait); above is
    /// slower (a sorry or hushed Book pools).
    var tempo: Double {
        let full: Double
        switch stance {
        case .pleased: full = 0.70
        case .mischievous: full = 0.76
        case .curious: full = 0.90
        case .intent: full = 1.0
        case .protective: full = 1.12
        case .contrite: full = 1.35
        case .hushed: full = 1.45
        }
        let scaled = 1 + (full - 1) * [0.5, 0.75, 1.0][strength - 1]
        return min(1.6, max(0.7, scaled * (night ? 1.12 : 1)))
    }
}
