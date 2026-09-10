import Foundation

// MARK: - The sky, brought as far as the paper
//
// The Book has had the real weather for a long time, and has only ever done
// one thing with it: talked about it. It reached the braid prompt, the Weather
// Page, and a whisper. It never reached a pixel — the souvenir card even
// stamps a little weather glyph on the paper, chosen from a fixed pool by
// seed, so the Book was already *pretending* to have weather on its pages.
//
// This is the real one. When it rains where the reader is standing, it rains
// on the leaf they are holding.
//
// Two rules keep it from becoming a screensaver:
//
// 1. **It must be true.** A reading has an age, and the sky fades out of the
//    paper as that age passes (`presence(at:)`). Drawing rain on the leaf
//    while the reader stands in sunshine is the Book claiming something that
//    is not so, which is the one thing it must never do.
// 2. **Most days are dry.** `clear` draws nothing at all, and the layer that
//    renders this is not mounted when there is nothing to draw. The effect
//    only means something if it is usually absent.
//
// Everything here is pure and analytic on purpose. There is no simulation
// state and no per-frame allocation: a speck's whole life is a function of
// its seed and the clock, so the renderer can ask where every drop is at time
// `t` without keeping anything between frames.

/// What the sky is doing, at the coarseness the paper can actually show.
///
/// Deliberately smaller than Open-Meteo's code list. The paper cannot tell
/// "drizzle" from "light rain", and pretending otherwise would add branches
/// that never render differently.
public enum SkyCondition: String, Equatable, CaseIterable, Sendable {
    case clear
    case cloud
    case fog
    case rain
    case snow
    case storm

    /// Whether this condition puts anything on the leaf at all.
    ///
    /// `clear` and `cloud` are the common case and cost nothing: the renderer
    /// checks this before it mounts a timeline.
    ///
    /// `fog` is here with them, and deliberately. Fog has no specks to land —
    /// it is a haze over the page — and drawing one convincingly needs to know
    /// where the paper actually ends. This layer is handed the *Book's* frame
    /// and infers the leaf from it, so a haze with any edge to it lands a grey
    /// panel on the page wherever that inference is a few points out, and a
    /// haze soft enough to be safe is too faint to see at all. Both were built
    /// and both looked wrong. It waits for a real leaf anchor.
    public var marksThePaper: Bool {
        switch self {
        case .clear, .cloud, .fog: return false
        case .rain, .snow, .storm: return true
        }
    }
}

/// One reading of the real sky, with the two facts the paper needs beyond the
/// condition itself: how hard it is coming down, and how much the air is
/// moving.
public struct PaperSky: Equatable, Sendable {
    public var condition: SkyCondition
    /// How much of the condition there is, 0...1. Drizzle and a downpour are
    /// the same `.rain` with very different intensities.
    public var intensity: Double
    /// How much the air is moving, 0...1. Carried separately because wind
    /// accompanies every condition, including a clear one.
    public var wind: Double
    public var isDay: Bool
    /// When this was read from the sky. The honesty gate depends on it.
    public var observedAt: Date

    public init(
        condition: SkyCondition,
        intensity: Double,
        wind: Double,
        isDay: Bool,
        observedAt: Date
    ) {
        self.condition = condition
        self.intensity = min(1, max(0, intensity))
        self.wind = min(1, max(0, wind))
        self.isDay = isDay
        self.observedAt = observedAt
    }

    /// A reading is at full strength for exactly as long as it is the newest
    /// one the Book should have.
    ///
    /// Deliberately *defined as* the refresh interval rather than picked to sit
    /// near it. While the sky is being re-read on time, a reading is always
    /// replaced before it begins to fade, so the fade never shows during normal
    /// use — which means a visibly thinning sky is not decoration but a signal
    /// that the reads are failing: no signal, permission withdrawn, a long
    /// spell in the background. Two independent constants would have made that
    /// meaning drift the first time either was tuned.
    public static var freshFor: TimeInterval { SkyRefresh.interval }

    /// And is gone entirely by this age, having faded the whole way.
    ///
    /// The weather signal refreshes on a four-hour slot, so a reading at the
    /// end of its life is the one most likely to be wrong. The fade is not
    /// only a graphical nicety: rain thinning off the leaf as the fact ages is
    /// the Book being honest about how well it knows.
    public static let staleAt: TimeInterval = 3 * 60 * 60

    /// How much of this reading still reaches the paper, 0...1.
    public func presence(at now: Date) -> Double {
        let age = now.timeIntervalSince(observedAt)
        // A clock that has gone backwards (timezone change, a restored
        // backup) should not be read as an infinitely fresh sky.
        guard age >= 0 else { return 0 }
        if age <= Self.freshFor { return 1 }
        if age >= Self.staleAt { return 0 }
        let span = Self.staleAt - Self.freshFor
        return 1 - ((age - Self.freshFor) / span)
    }

    /// The reading as it should actually be drawn right now, or `nil` when
    /// there is nothing to draw.
    ///
    /// This is the single gate the renderer asks. It folds together every
    /// reason to draw nothing — a clear sky, a stale reading, an intensity
    /// that rounds away — so no view has to remember the whole list.
    public func settled(at now: Date) -> PaperSky? {
        guard condition.marksThePaper else { return nil }
        let presence = presence(at: now)
        guard presence > 0.02 else { return nil }
        let faded = intensity * presence
        guard faded > 0.02 else { return nil }
        var copy = self
        copy.intensity = faded
        copy.wind = wind * presence
        return copy
    }

    /// The furthest the fore-edge ever moves, in points, at a full gale.
    ///
    /// Wind is the one effect that reads as *the book* rather than as weather
    /// on it, so it stays small. A page that flaps is a cartoon; a page whose
    /// edge is never quite still is a page in a room with a draught.
    public static let foreEdgeAmplitude: Double = 3.4

    /// How far the fore-edge should waver for this reading, in points.
    ///
    /// Takes staleness into account, so it is the figure for a *raw* reading.
    /// A reading already put through `settled(at:)` has had its wind faded, and
    /// should scale `foreEdgeAmplitude` by that wind directly rather than
    /// paying the staleness toll twice.
    public func foreEdgeWaver(at now: Date) -> Double {
        wind * presence(at: now) * Self.foreEdgeAmplitude
    }
}

// MARK: - How often the Book looks up

/// When the sky is due to be read again.
///
/// This is deliberately *not* part of `RealWorldContextRefreshPolicy`, which
/// governs the one-shot GPS fix and is careful with the battery for good
/// reason. Reading the sky needs no sensor at all — it is one small request
/// against a coordinate the Book already has — so it has no business being
/// rationed by the sensor's economy. Where the reader is standing does not need
/// rechecking every hour; what the sky is doing there does.
public enum SkyRefresh {
    /// How often the sky is re-read while the Book is open and awake.
    public static let interval: TimeInterval = 60 * 60

    /// How long to wait after a failed read before trying again.
    ///
    /// Failures come in runs — no signal is no signal for a while — and the
    /// only cost of waiting is a sky that fades a little, which is the honest
    /// thing for it to do while the Book cannot see out.
    public static let failedAttemptBackoff: TimeInterval = 10 * 60

    /// How long a remembered place is worth asking the sky about.
    ///
    /// The Book keeps the last place it knew it was standing, so it can read
    /// the sky the instant it opens instead of waiting on a GPS fix. That fix
    /// is still taken, and still overwrites this — the remembered place is a
    /// head start, never a replacement.
    ///
    /// The bet: on any given launch the reader is far more likely to be where
    /// they were last time than not, and if they are not, the location pass
    /// corrects it within about a minute. A day is where that bet stops being
    /// worth making — a coordinate older than that has probably had a journey
    /// in it, and no sky at all beats a confident sky over the wrong city.
    public static let placeTrustWindow: TimeInterval = 24 * 60 * 60

    /// Whether a remembered place is still worth asking about.
    public static func trustsPlace(recordedAt: Date?, now: Date = Date()) -> Bool {
        guard let recordedAt else { return false }
        let age = now.timeIntervalSince(recordedAt)
        // A place stamped in the future is a moved clock, not somewhere the
        // Book has been.
        guard age >= 0 else { return false }
        return age <= placeTrustWindow
    }

    /// A place recorded no more precisely than the sky needs.
    ///
    /// Weather grids are kilometres across, so two decimal places is already
    /// finer than the answer. Storing it coarsely is not only good manners —
    /// it means this value cannot later be quietly reused for anything that
    /// wants to know exactly where the reader was standing.
    public static func coarse(_ degrees: Double) -> Double {
        (degrees * 100).rounded() / 100
    }

    /// Whether the sky should be read now.
    ///
    /// `lastReadAt` is the observation time of the reading in hand, not the
    /// time it was stored; a reading recovered from somewhere else is exactly
    /// as old as the sky it describes.
    public static func isDue(
        lastReadAt: Date?,
        lastAttemptAt: Date?,
        now: Date = Date()
    ) -> Bool {
        if let lastAttemptAt, now.timeIntervalSince(lastAttemptAt) < failedAttemptBackoff {
            return false
        }
        guard let lastReadAt else { return true }
        // A reading stamped in the future is a clock that moved, not a sky the
        // Book knows about. Read again.
        guard now >= lastReadAt else { return true }
        return now.timeIntervalSince(lastReadAt) >= interval
    }

    /// The next moment worth trying. Scheduling information, not permission —
    /// callers must still ask `isDue` after waking, because consent and app
    /// state can change while a clock sleeps.
    public static func nextDue(
        lastReadAt: Date?,
        lastAttemptAt: Date?,
        now: Date = Date()
    ) -> Date {
        var due = lastReadAt.map { $0 <= now ? $0.addingTimeInterval(interval) : now } ?? now
        if let lastAttemptAt {
            due = max(due, lastAttemptAt.addingTimeInterval(failedAttemptBackoff))
        }
        return max(now, due)
    }
}

// MARK: - Reading Open-Meteo

/// Open-Meteo's `weather_code` and its neighbours, turned into something the
/// paper can draw.
public enum SkyCode {
    /// Map one WMO code to a condition and the base intensity that code
    /// implies on its own.
    ///
    /// The code alone already distinguishes light from heavy in most families
    /// (WMO numbers them that way), so it carries the intensity when no
    /// measured precipitation is available.
    public static func condition(_ code: Int) -> (SkyCondition, Double) {
        switch code {
        case 0, 1:
            return (.clear, 0)
        case 2, 3:
            return (.cloud, 0)
        case 45, 48:
            return (.fog, 0.7)
        case 51, 56:
            return (.rain, 0.22)
        case 53, 57:
            return (.rain, 0.34)
        case 55:
            return (.rain, 0.46)
        case 61, 66, 80:
            return (.rain, 0.45)
        case 63, 81:
            return (.rain, 0.66)
        case 65, 67, 82:
            return (.rain, 0.9)
        case 71, 85:
            return (.snow, 0.34)
        case 73:
            return (.snow, 0.58)
        case 75, 77, 86:
            return (.snow, 0.85)
        case 95:
            return (.storm, 0.72)
        case 96, 99:
            return (.storm, 0.95)
        default:
            // An unknown code is not an excuse to invent weather.
            return (.cloud, 0)
        }
    }

    /// Build a reading from what the forecast endpoint returns.
    ///
    /// `precipitation` (mm in the last hour) and `windSpeed` (km/h) are both
    /// optional because the reading has to survive a response that predates
    /// them — an old cached signal, or a partial decode.
    public static func reading(
        code: Int,
        precipitation: Double? = nil,
        windSpeed: Double? = nil,
        isDay: Bool = true,
        observedAt: Date
    ) -> PaperSky {
        let (condition, baseIntensity) = condition(code)

        // Measured precipitation beats the code's implied intensity when it is
        // present and the code already agrees that something is falling. It is
        // never allowed to *start* precipitation: a stray millimetre against a
        // clear-sky code is a sensor artefact, not rain on this reader's head.
        var intensity = baseIntensity
        if condition == .rain || condition == .snow || condition == .storm,
           let precipitation, precipitation > 0 {
            // 4mm in an hour is already a firm rain; treat it as the top of
            // the scale so ordinary wet days use most of the range instead of
            // huddling near zero.
            let measured = min(1, precipitation / 4)
            intensity = max(baseIntensity, measured)
        }

        // 40 km/h is a day when things blow off tables. Above that the paper
        // has nothing more to say.
        let wind = windSpeed.map { min(1, max(0, $0 / 40)) } ?? 0

        return PaperSky(
            condition: condition,
            intensity: intensity,
            wind: wind,
            isDay: isDay,
            observedAt: observedAt
        )
    }
}

// MARK: - What lands on the leaf

/// One drop or flake, as a fixed set of seeded traits.
///
/// A speck never changes. Where it is at time `t` is computed from these
/// numbers and the clock, which is what lets the whole field be drawn with no
/// state carried between frames and nothing allocated per drop per frame.
public struct SkySpeck: Equatable, Sendable {
    /// Where it sits across the leaf, 0...1.
    public var laneX: Double
    /// Where it comes to rest down the leaf, 0...1.
    public var restY: Double
    /// Relative size, 0...1.
    public var size: Double
    /// How long its whole arrive-sit-dry cycle takes, in seconds.
    public var period: Double
    /// Where in that cycle it is at t = 0, 0...1. Staggers the field so drops
    /// do not arrive in unison.
    public var offset: Double
    /// Whether this one runs a little way down the page before it stops.
    /// A few do; a field where they all do looks like a car window.
    public var runs: Bool

    public init(
        laneX: Double,
        restY: Double,
        size: Double,
        period: Double,
        offset: Double,
        runs: Bool
    ) {
        self.laneX = laneX
        self.restY = restY
        self.size = size
        self.period = period
        self.offset = offset
        self.runs = runs
    }
}

/// Where a speck is, and how much of it there is, at one instant.
public struct SkySpeckFrame: Equatable, Sendable {
    /// 0...1 across the leaf.
    public var x: Double
    /// 0...1 down the leaf.
    public var y: Double
    /// Relative size, 0...1.
    public var size: Double
    /// The bead itself: bright, short-lived.
    public var beadAlpha: Double
    /// The mark it leaves in the paper: dimmer, and it outlasts the bead.
    /// This is the part that actually reads as *wet paper* rather than as a
    /// dot drawn on top of a page.
    public var dampAlpha: Double
    /// How far it has fallen toward its resting place, 0...1. Below 1 the
    /// speck is still arriving and should be drawn with a short streak behind
    /// it rather than as a bead.
    public var arrival: Double
}

/// The field of specks: how many, where, and where each one is now.
public enum SkyField {
    /// The most specks that may ever be on the leaf at once.
    ///
    /// A hard ceiling rather than a guideline. Everything else in this file is
    /// cheap per speck, so the only way this layer can become a performance
    /// problem is by drawing an unbounded number of them.
    public static let ceiling = 26

    /// How many specks a leaf of this size, in this weather, should carry.
    ///
    /// Scaled by area so the effect has the same density on a phone and on a
    /// pad, rather than the same count spread thinner.
    public static func count(
        for reading: PaperSky,
        leafArea: Double
    ) -> Int {
        guard reading.condition.marksThePaper else { return 0 }
        // A phone leaf is roughly 105_000 sq pt. This puts a moderate rain at
        // about a dozen drops on it, which is enough to read as weather and
        // few enough to still read as individual drops.
        let density = leafArea / 9_000
        let scaled = density * (0.25 + reading.intensity * 0.75)
        return min(ceiling, max(3, Int(scaled.rounded())))
    }

    /// Build the speck table for a field of `count`.
    ///
    /// Pure and seeded, so the same leaf carries the same drops across a
    /// relaunch, and so this can be cached by count and reused rather than
    /// rebuilt per frame.
    public static func specks(
        count: Int,
        condition: SkyCondition,
        seed: Int = 0
    ) -> [SkySpeck] {
        guard count > 0 else { return [] }
        let isSnow = condition == .snow
        return (0..<count).map { index in
            func unit(_ salt: Int) -> Double {
                let mixed = (seed &+ index &* 7_919 &+ salt &* 104_729).stableScramble
                return Double(UInt(bitPattern: mixed) % 10_000) / 9_999
            }

            // Snow settles: it collects along the head of the leaf and in the
            // gutter rather than landing evenly, because that is where it
            // would actually stay on a book held open.
            let restY: Double
            if isSnow {
                let settle = unit(5)
                restY = settle < 0.62 ? unit(6) * 0.26 : 0.26 + unit(7) * 0.68
            } else {
                restY = unit(6)
            }

            // Snow hangs about far longer than rain, and dries — melts, but
            // the paper is not that literal — more slowly.
            let period = isSnow
                ? 14 + unit(3) * 12
                : 7 + unit(3) * 9

            return SkySpeck(
                laneX: unit(1),
                restY: restY,
                size: unit(2),
                period: period,
                offset: unit(4),
                // Runners are rain only, and rare. Snow does not run.
                runs: !isSnow && unit(8) > 0.82
            )
        }
    }

    /// Where a speck is at time `t`.
    ///
    /// The cycle is: arrive (a short fall onto the paper), sit as a bead, then
    /// dry — the bead going first and the damp mark lingering behind it. Every
    /// phase is a straight function of the cycle position, so this is a few
    /// arithmetic operations and no branching on stored state.
    public static func frame(
        for speck: SkySpeck,
        condition: SkyCondition,
        wind: Double,
        time: TimeInterval
    ) -> SkySpeckFrame {
        let isSnow = condition == .snow

        // Cycle position, 0...1.
        var u = (time / speck.period + speck.offset).truncatingRemainder(dividingBy: 1)
        if u < 0 { u += 1 }

        // Snow takes longer to come down and sits far longer once it has.
        let arriveEnd = isSnow ? 0.22 : 0.09
        let dryStart = isSnow ? 0.72 : 0.55

        let arrival = u < arriveEnd ? u / arriveEnd : 1

        // Falling: the speck comes in from just above where it will rest, not
        // from the top of the screen. This is weather *on the leaf*, so a drop
        // that streaked the whole height of the page would be drawing rain in
        // the room instead — and the room is deliberately a still stage.
        let approach = isSnow ? 0.20 : 0.11
        var y = speck.restY - approach * (1 - arrival)

        // Runners creep a little further down once landed, then stop. Water
        // beading and then letting go is the whole charm; water sliding the
        // full height of the page is a windscreen.
        if speck.runs, arrival >= 1 {
            let since = (u - arriveEnd) / max(0.0001, 1 - arriveEnd)
            y += 0.06 * min(1, since * 2.4)
        }

        // Wind pushes the arriving speck sideways and lets it straighten as it
        // lands. Snow, being slower and lighter, is pushed much further.
        let sway = isSnow ? 0.16 : 0.05
        let gust = sin(time * 0.8 + speck.offset * 6.28) * 0.5 + 0.5
        let x = speck.laneX + wind * sway * (1 - arrival) * (0.4 + gust * 0.6)

        // The bead: brightest just after it lands, gone by the end of drying.
        let beadAlpha: Double
        if u < arriveEnd {
            beadAlpha = arrival
        } else if u < dryStart {
            beadAlpha = 1
        } else {
            let dry = (u - dryStart) / max(0.0001, 1 - dryStart)
            // Squared so the bead goes quickly and then is properly gone,
            // rather than lingering as a faint dot for half its life.
            beadAlpha = max(0, 1 - dry * dry * 1.6)
        }

        // The damp mark: arrives with the drop, outlasts it, fades out flat.
        let dampAlpha: Double
        if u < arriveEnd {
            dampAlpha = arrival * 0.55
        } else if u < dryStart {
            let sit = (u - arriveEnd) / max(0.0001, dryStart - arriveEnd)
            dampAlpha = 0.55 + sit * 0.45
        } else {
            let dry = (u - dryStart) / max(0.0001, 1 - dryStart)
            dampAlpha = max(0, 1 - dry)
        }

        return SkySpeckFrame(
            x: x,
            y: y,
            size: speck.size,
            beadAlpha: min(1, max(0, beadAlpha)),
            dampAlpha: min(1, max(0, dampAlpha)),
            arrival: arrival
        )
    }

    /// The fore-edge's sideways offset at time `t`, in points.
    ///
    /// Two sines at unrelated rates, so the edge never settles into a visible
    /// loop. Called once per rendered row of the edge, not per frame per view.
    public static func waver(
        at time: TimeInterval,
        alongEdge t: Double,
        amplitude: Double
    ) -> Double {
        guard amplitude > 0 else { return 0 }
        let travelling = sin(time * 1.7 + t * 5.6)
        let slow = sin(time * 0.41 + t * 2.1)
        // The head and tail of the leaf are held by the binding and the
        // reader's thumb; the middle of the fore-edge is what actually moves.
        let held = sin(t * .pi)
        return (travelling * 0.62 + slow * 0.38) * amplitude * held
    }
}
