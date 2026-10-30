import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

// MARK: - Noticing without the model
//
// docs/noticing-and-writing-sessions-plan.md §8. Every kept page already
// carries measurements: when and where it was kept, the sky, the moon, the
// reader's sleep and heart, what their photograph showed, how long they wrote.
// The word counter flattened all of that into words and found "photo goes with
// photo". This crosses the measurements themselves.
//
// The four rules, as code:
//  1. Compare measurements, not vocabulary. Every value here is a number or a
//     closed category; no free text is counted.
//  2. Cross-checks need independent sources. Two measures from one source
//     (two body readings, two photo readings, two clock readings) never pair.
//  3. Combinations, not single words.
//  4. Only say it when it beats chance: enough distinct days on both sides, a
//     real difference, an effect that holds for most of the days, and a
//     sentence shape for each kind so it sounds like the Book.

/// Where a measurement came from. Two measures from one source are one fact.
enum NoticingSource: String, CaseIterable {
    case writing, photo, body, weather, sky, clock, place, calendar
    /// How the phone was held and its state: posture, battery, screen, headphones.
    case device
}

/// What one surviving noticing says, and the receipts behind it.
struct Noticing: Identifiable, Equatable {
    enum Kind: String {
        case crossing, trend, coincidence, record, first, absence, sunKeeper, refrain
        case rhyme, colour, nobody, shift
        case rhythm, carried
    }

    struct Receipt: Equatable {
        var pageID: String
        var date: Date
        var text: String
    }

    var id: String
    var kind: Kind
    var headline: String
    /// The noticing itself, in the Book's voice.
    var line: String
    /// The numbers, plainly: what the Book actually counted.
    var counted: String?
    /// What would make the Book cross it out.
    var falsifier: String?
    /// A small thing to go and check.
    var errand: String?
    var receipts: [Receipt]
    var sources: [NoticingSource]
    /// Higher is stranger and better supported.
    var rank: Int

    /// How to test a crossing again on days that haven't happened yet: the
    /// condition, the measurement, which way it should go, and past what.
    struct Test: Equatable, Codable {
        var categoryID: String
        var value: String
        var numberID: String
        var rises: Bool
        /// The rest-of-the-time middle the prediction is measured against.
        var threshold: Double
        var conditionKey: String { "\(categoryID)|\(value)" }
    }

    /// Only crossings carry one.
    var test: Test? = nil

    /// Anything read from the reader's body stays private like the body pages.
    var touchesBody: Bool { sources.contains(.body) }
}

enum NoticingCrossings {
    /// Pairs are judged inside a recent window so a season can't pose as a
    /// finding ("cold days, you sleep longer" might only mean winter).
    static let windowDays = 84
    static let minimumOutsideDays = 6

    /// The desk is curated many times a day and the archive changes far less
    /// often: same pages, same hour, same noticings.
    static func noticings(days: [BookDay], now: Date, calendar: Calendar = .current) -> [Noticing] {
        ArchiveMemo.value(
            "noticing.crossings",
            days: days,
            salt: "\(Int(now.timeIntervalSince1970 / 3600))"
        ) {
            computeNoticings(days: days, now: now, calendar: calendar)
        }
    }

    static func computeNoticings(days: [BookDay], now: Date, calendar: Calendar) -> [Noticing] {
        let keeps = keepUnits(days: days, calendar: calendar)
        guard !keeps.isEmpty else { return [] }
        let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let recentKeeps = keeps.filter { $0.date >= windowStart && $0.date <= now }
        let recentDays = dayUnits(from: recentKeeps, calendar: calendar)

        var found: [Noticing] = []
        found += crossings(keeps: recentKeeps, days: recentDays)
        found += longCrossings(keeps: keeps, now: now, calendar: calendar)
        found += trends(days: recentDays)
        found += sameMinute(keeps: keeps, now: now, calendar: calendar)
        found += twinLengths(keeps: keeps, now: now, calendar: calendar)
        found += records(days: dayUnits(from: keeps, calendar: calendar), now: now, calendar: calendar)
        found += firsts(days: dayUnits(from: keeps, calendar: calendar), now: now, calendar: calendar)
        found += missingWeekday(keeps: keeps, now: now, calendar: calendar)
        found += sunKeeper(keeps: recentKeeps, calendar: calendar)
        found += refrains(keeps: keeps, now: now, calendar: calendar)
        found += sameDay(keeps: keeps, now: now, calendar: calendar)
        found += monthColours(keeps: keeps, now: now, calendar: calendar)
        found += nobodyInThePictures(keeps: recentKeeps)
        found += questionShift(keeps: keeps, now: now)
        found += sleepRhythms(keeps: recentKeeps)
        found += carried(keeps: keeps, now: now, calendar: calendar)
        found += heartAtKeepRecord(keeps: keeps, now: now)
        found += crossedOutMoreThanKept(keeps: keeps, now: now)
        found += firstFace(keeps: keeps, now: now)
        found += auroraWeather(keeps: keeps, now: now, calendar: calendar)
        return found.sorted { left, right in
            left.rank == right.rank ? left.id < right.id : left.rank > right.rank
        }
    }

    // MARK: Units

    /// One kept reader page, or one day of them, as measurements.
    struct Sample {
        var dayID: String
        var date: Date
        var pages: [BookPage]
        var numbers: [String: Double]
        var categories: [String: Set<String>]

        var representative: BookPage? {
            pages.first { $0.readerAuthoredTextForAnalysis != nil } ?? pages.first
        }
    }

    static func keepUnits(days: [BookDay], calendar: Calendar) -> [Sample] {
        days.flatMap { day in
            day.pages
                .filter { $0.carriesReaderAttention && $0.origin != .simulated && $0.type != .bookNotices }
                .map { keepUnit($0, dayID: day.id, calendar: calendar) }
        }
        .sorted { $0.date < $1.date }
    }

    private static func keepUnit(_ page: BookPage, dayID: String, calendar: Calendar) -> Sample {
        var numbers: [String: Double] = [:]
        var categories: [String: Set<String>] = [:]
        let at = page.createdAt

        if !EditionCurator.defaultPrivateTypes.contains(page.type),
           let text = page.readerAuthoredTextForAnalysis {
            let words = wordCount(text)
            if words > 0 { numbers["words"] = Double(words) }
            if words >= 5 { numbers["questions"] = Double(text.filter { $0 == "?" }.count) }
        }
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: at)
        numbers["hour"] = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        if let weekday = components.weekday {
            categories["weekday"] = [weekdayNames[(weekday - 1) % 7]]
        }

        let moon = MoonPhaseCalendar.phase(on: at)
        if moon.illuminatedFraction >= 0.93 { categories["moon"] = ["full"] }
        if moon.illuminatedFraction <= 0.07 { categories["moon"] = ["new"] }

        for asset in page.mediaAssets where page.hasReaderPhotograph {
            if let people = asset.metadata["attentionPeopleCount"].flatMap(Double.init) {
                numbers["photoPeople"] = people
            }
            // "muted" is the keep path's default when Vision saw no colour.
            if let colour = asset.metadata["attentionColorMood"]?.lowercased().nonEmpty, colour != "muted" {
                categories["photoColour", default: []].insert(colour)
            }
        }

        if let context = page.context {
            if context.dayPart != "unknown", !context.dayPart.isEmpty {
                categories["dayPart"] = [context.dayPart]
            }
            let weather = Set(context.weatherTags.filter { RadioPageContext.knownWeatherTags.contains($0) })
            if !weather.isEmpty { categories["weather"] = weather }
            if let anchor = context.nearbyAnchorID?.nonEmpty {
                categories["place"] = [context.locationLabel?.nonEmpty ?? anchor]
            }
            if let sleep = context.sleepHours, sleep > 0 { numbers["sleep"] = sleep }
            if let steps = context.steps, steps > 0 { numbers["steps"] = Double(steps) }
            if let heart = context.restingHeartRate, heart > 0 { numbers["restingHeart"] = Double(heart) }
            if let hrv = context.heartRateVariability, hrv > 0 { numbers["hrv"] = hrv }
            if let events = context.calendarEventCount { numbers["calendar"] = Double(events) }
            if let heart = context.heartRateAtKeep, heart > 0 { numbers["heartAtKeep"] = Double(heart) }
            if let breathing = context.respiratoryRate, breathing > 0 { numbers["breathing"] = breathing }
            if let glucose = context.bloodGlucose, glucose > 0 { numbers["glucose"] = glucose }
            if let writing = context.writing {
                if let seconds = writing.secondsWriting, seconds >= 5 { numbers["writingMinutes"] = seconds / 60 }
                if let deleted = writing.charactersDeleted, let kept = writing.charactersKept, deleted + kept >= 20 {
                    numbers["crossedOut"] = Double(deleted) / Double(deleted + kept) * 100
                }
            }
            if let holding = context.holding {
                if let posture = holding.posture { categories["posture"] = [posture.rawValue] }
                if let brightness = holding.screenBrightness { categories["screen"] = [brightness <= 0.25 ? "dark" : "bright"] }
                if let battery = holding.batteryPercent, holding.charging != true {
                    categories["battery"] = [battery <= 15 ? "low" : "fine"]
                }
                if let headphones = holding.headphones { categories["headphones"] = [headphones ? "on" : "off"] }
                if let moving = holding.moving { categories["moving"] = [moving ? "moving" : "still"] }
            }
            if let since = context.minutesSinceEventEnded {
                categories["afterEvent"] = [since <= 20 ? "justAfter" : "later"]
            }
            if let altitude = context.sunAltitude { categories["sunLight"] = [SunHeight.light(degrees: altitude)] }
            if let sea = context.sea {
                if let rising = sea.rising { categories["tide"] = [rising ? "in" : "out"] }
                numbers["waves"] = sea.waveHeightMeters
            }
            numbers["airQuality"] = context.air?.usAQI
            if let extras = context.bodyExtras {
                numbers["daylight"] = extras.daylightMinutes
                numbers["flights"] = extras.flightsClimbed.map(Double.init)
                numbers["loggedMood"] = extras.loggedValence
                numbers["loudness"] = extras.environmentDecibels
                if let workout = extras.lastWorkout, let since = extras.minutesSinceWorkout, since <= 180 {
                    categories["afterWorkout"] = [workout]
                }
            }
            if let sky = context.weatherMeasurements {
                numbers["temperature"] = sky.temperatureF
                numbers["pressure"] = sky.pressureHPa
                numbers["pressureChange"] = sky.pressureChange6h
                numbers["humidity"] = sky.humidity
                numbers["cloud"] = sky.cloudCover
                numbers["wind"] = sky.windKmh
                if let change = sky.pressureChange6h {
                    categories["barometer"] = [change <= -3 ? "falling" : (change >= 3 ? "rising" : "steady")]
                }
            }
        }
        return Sample(dayID: dayID, date: at, pages: [page], numbers: numbers, categories: categories)
    }

    /// Keep-grain measures averaged over the day; day-grain ones (the body,
    /// the calendar) taken once; categories are whatever the day held.
    static func dayUnits(from keeps: [Sample], calendar: Calendar) -> [Sample] {
        Dictionary(grouping: keeps, by: \.dayID).values.compactMap { group -> Sample? in
            guard let first = group.first else { return nil }
            var numbers: [String: Double] = [:]
            for measure in numberMeasures {
                let values = group.compactMap { $0.numbers[measure.id] }
                guard !values.isEmpty else { continue }
                numbers[measure.id] = measure.grain == .day ? values[0] : values.reduce(0, +) / Double(values.count)
            }
            var categories: [String: Set<String>] = [:]
            for unit in group {
                for (key, values) in unit.categories { categories[key, default: []].formUnion(values) }
            }
            return Sample(
                dayID: first.dayID,
                date: calendar.startOfDay(for: first.date),
                pages: group.flatMap(\.pages),
                numbers: numbers,
                categories: categories
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: The catalogue

    enum Grain { case keep, day }

    struct NumberMeasure {
        var id: String
        var source: NoticingSource
        var grain: Grain
        var title: String
        var rises: String
        var falls: String
        var unit: String
        var decimals: Int
        /// Smaller than this and the difference isn't worth a sentence.
        var minimumDifference: Double
        var check: String?
        var isClock = false
        /// The world's measurements (the sky) can explain the reader; they are
        /// never the finding. "Nights are colder" is not a noticing about you.
        var isConditionOnly = false
    }

    static let numberMeasures: [NumberMeasure] = [
        NumberMeasure(id: "words", source: .writing, grain: .keep, title: "Your Words",
                      rises: "your pages run longer", falls: "your pages come out shorter",
                      unit: "words", decimals: 0, minimumDifference: 15, check: "count your words"),
        NumberMeasure(id: "questions", source: .writing, grain: .keep, title: "Your Questions",
                      rises: "you ask me more", falls: "you ask me less",
                      unit: "questions a page", decimals: 1, minimumDifference: 0.5, check: "ask me something"),
        NumberMeasure(id: "hour", source: .clock, grain: .keep, title: "The Hour You Come",
                      rises: "you find me later", falls: "you find me earlier",
                      unit: "", decimals: 0, minimumDifference: 1.5, check: "look at the clock when you open me",
                      isClock: true),
        NumberMeasure(id: "photoPeople", source: .photo, grain: .keep, title: "People in Your Pictures",
                      rises: "more people get into your pictures", falls: "fewer people get into your pictures",
                      unit: "people a picture", decimals: 1, minimumDifference: 0.7, check: nil),
        NumberMeasure(id: "sleep", source: .body, grain: .day, title: "Sleep",
                      rises: "you sleep longer", falls: "you sleep less",
                      unit: "hours", decimals: 1, minimumDifference: 0.6, check: "notice when you wake up"),
        NumberMeasure(id: "steps", source: .body, grain: .day, title: "Your Walking",
                      rises: "you walk further", falls: "you walk less",
                      unit: "steps", decimals: 0, minimumDifference: 1_500, check: "look at your steps before bed"),
        NumberMeasure(id: "restingHeart", source: .body, grain: .day, title: "Your Heart",
                      rises: "your heart goes faster", falls: "your heart goes slower",
                      unit: "beats a minute", decimals: 0, minimumDifference: 3,
                      check: "count your pulse before you get up"),
        NumberMeasure(id: "hrv", source: .body, grain: .day, title: "The Gaps Between Your Heartbeats",
                      rises: "the gaps between your heartbeats get wider",
                      falls: "the gaps between your heartbeats get narrower",
                      unit: "milliseconds between beats", decimals: 0, minimumDifference: 6, check: nil),
        NumberMeasure(id: "calendar", source: .calendar, grain: .day, title: "Your Calendar",
                      rises: "your calendar fills up", falls: "your calendar empties out",
                      unit: "things on the calendar", decimals: 1, minimumDifference: 1.5, check: nil),
        NumberMeasure(id: "heartAtKeep", source: .body, grain: .keep, title: "Your Heart When You Write",
                      rises: "your heart is quicker when you write to me", falls: "your heart is slower when you write to me",
                      unit: "beats a minute", decimals: 0, minimumDifference: 6,
                      check: "put two fingers on your wrist before you write"),
        NumberMeasure(id: "breathing", source: .body, grain: .day, title: "Your Breathing",
                      rises: "you breathe faster", falls: "you breathe slower",
                      unit: "breaths a minute", decimals: 1, minimumDifference: 1, check: nil),
        NumberMeasure(id: "glucose", source: .body, grain: .keep, title: "Your Glucose",
                      rises: "your glucose runs higher", falls: "your glucose runs lower",
                      unit: "mg/dL", decimals: 0, minimumDifference: 15, check: nil),
        NumberMeasure(id: "writingMinutes", source: .writing, grain: .keep, title: "How Long You Write",
                      rises: "you take your time", falls: "you're quick about it",
                      unit: "minutes writing", decimals: 1, minimumDifference: 1, check: nil),
        NumberMeasure(id: "crossedOut", source: .writing, grain: .keep, title: "What You Cross Out",
                      rises: "you cross out more", falls: "you cross out less",
                      unit: "% crossed out", decimals: 0, minimumDifference: 10, check: nil),
        NumberMeasure(id: "daylight", source: .body, grain: .day, title: "Daylight",
                      rises: "you're out in the light longer", falls: "you get less daylight",
                      unit: "minutes in daylight", decimals: 0, minimumDifference: 30, check: "go and stand in the light for a minute"),
        NumberMeasure(id: "flights", source: .body, grain: .day, title: "Stairs",
                      rises: "you climb more stairs", falls: "you climb fewer stairs",
                      unit: "flights of stairs", decimals: 0, minimumDifference: 3, check: nil),
        NumberMeasure(id: "loggedMood", source: .body, grain: .keep, title: "The Mood You Log",
                      rises: "the mood you log in Health is brighter", falls: "the mood you log in Health is lower",
                      unit: "on Health's mood scale", decimals: 1, minimumDifference: 0.3, check: nil),
        NumberMeasure(id: "waves", source: .weather, grain: .keep, title: "The Sea",
                      rises: "the sea is rough", falls: "the sea is calm",
                      unit: "m waves", decimals: 1, minimumDifference: 0.5, check: nil, isConditionOnly: true),
        NumberMeasure(id: "airQuality", source: .weather, grain: .keep, title: "The Air",
                      rises: "the air is thick", falls: "the air is clean",
                      unit: "on the air-quality scale", decimals: 0, minimumDifference: 20, check: nil, isConditionOnly: true),
        NumberMeasure(id: "loudness", source: .device, grain: .day, title: "The Noise Around You",
                      rises: "it's loud around you", falls: "it's quiet around you",
                      unit: "decibels around you", decimals: 0, minimumDifference: 6, check: nil, isConditionOnly: true),
        NumberMeasure(id: "temperature", source: .weather, grain: .keep, title: "The Temperature",
                      rises: "it's warmer", falls: "it's colder",
                      unit: "degrees", decimals: 0, minimumDifference: 6, check: nil, isConditionOnly: true),
        NumberMeasure(id: "pressure", source: .weather, grain: .keep, title: "The Barometer",
                      rises: "the barometer is high", falls: "the barometer is low",
                      unit: "hPa", decimals: 0, minimumDifference: 4, check: nil, isConditionOnly: true),
        NumberMeasure(id: "pressureChange", source: .weather, grain: .keep, title: "The Barometer Moving",
                      rises: "the barometer is rising", falls: "the barometer is falling",
                      unit: "hPa in six hours", decimals: 1, minimumDifference: 2, check: nil, isConditionOnly: true),
        NumberMeasure(id: "humidity", source: .weather, grain: .keep, title: "The Damp",
                      rises: "the air is damp", falls: "the air is dry",
                      unit: "% humidity", decimals: 0, minimumDifference: 12, check: nil, isConditionOnly: true),
        NumberMeasure(id: "cloud", source: .weather, grain: .keep, title: "The Cloud",
                      rises: "the sky is covered", falls: "the sky is open",
                      unit: "% cloud", decimals: 0, minimumDifference: 25, check: nil, isConditionOnly: true),
        NumberMeasure(id: "wind", source: .weather, grain: .keep, title: "The Wind",
                      rises: "the wind is up", falls: "the air is still",
                      unit: "km/h of wind", decimals: 0, minimumDifference: 8, check: nil, isConditionOnly: true)
    ]

    struct CategoryMeasure {
        var id: String
        var source: NoticingSource
        var grain: Grain
        var minimumDays: Int
        /// Days or keeps that never observed this category aren't "outside" it:
        /// a day with no weather reading isn't a dry day.
        var outsideNeedsObservation: Bool
        var phrase: (String) -> String
        var title: (String) -> String
        var plural: (String) -> String
        var singular: (String) -> String
        var rest: String
        /// Cycles the claim must span. The moon comes round every 29.5 days,
        /// and anything else with a rhythm near that (a pay cycle, a period, a
        /// rota) can line up with three moons by accident.
        var minimumCycles = 1
        /// Read over a longer window than the default, for claims that need
        /// many cycles and aren't seasonal.
        var windowDays: Int? = nil
        /// Measurements this one is the same fact as, seen another way:
        /// golden hour *is* an hour of the day.
        var entangledNumbers: Set<String> = []
    }

    private static let weatherNouns: [String: (phrase: String, title: String, plural: String, singular: String)] = [
        "rain": ("On rain days", "Rain", "rain days", "rain day"),
        "snow": ("On snow days", "Snow", "snow days", "snow day"),
        "fog": ("On foggy days", "Fog", "foggy days", "foggy day"),
        "storm": ("On stormy days", "Storms", "stormy days", "stormy day"),
        "wind": ("On windy days", "Wind", "windy days", "windy day"),
        "cloud": ("On grey days", "Grey Days", "grey days", "grey day"),
        "bright": ("On bright days", "Bright Days", "bright days", "bright day"),
        "frost": ("On frosty days", "Frost", "frosty days", "frosty day"),
        "hot": ("On hot days", "Hot Days", "hot days", "hot day"),
        "cold": ("On cold days", "Cold Days", "cold days", "cold day")
    ]

    private static let backgroundValues = [
        "barometer": "steady", "battery": "fine", "headphones": "off", "moving": "still",
        "afterEvent": "later", "screen": "bright"
    ]

    private static let postureNouns: [String: (phrase: String, title: String, plural: String, singular: String)] = [
        "flat": ("When I'm lying flat", "Lying Flat", "flat pages", "page with me lying flat"),
        "upright": ("When you hold me up", "Held Up", "held-up pages", "page held up"),
        "sideways": ("When you write lying on your side", "On Your Side", "pages on your side", "page written on your side"),
        "overhead": ("When you hold me over your face", "Held Overhead", "overhead pages", "page held over your face")
    ]

    private static let sunNouns: [String: (phrase: String, title: String, plural: String, singular: String)] = [
        "golden hour": ("In golden hour", "Golden Hour", "golden-hour pages", "golden-hour page"),
        "blue hour": ("In the blue hour", "The Blue Hour", "blue-hour pages", "blue-hour page"),
        "dark": ("After dark", "After Dark", "pages after dark", "page after dark"),
        "daylight": ("In daylight", "Daylight", "daylight pages", "daylight page")
    ]

    private static let dayPartNouns: [String: (phrase: String, title: String, plural: String, singular: String)] = [
        "morning": ("In the mornings", "Mornings", "morning pages", "morning page"),
        "afternoon": ("In the afternoons", "Afternoons", "afternoon pages", "afternoon page"),
        "evening": ("In the evenings", "Evenings", "evening pages", "evening page"),
        "night": ("At night", "Night", "night pages", "night page")
    ]

    static let categoryMeasures: [CategoryMeasure] = [
        CategoryMeasure(
            id: "weather", source: .weather, grain: .day, minimumDays: 5, outsideNeedsObservation: true,
            phrase: { weatherNouns[$0]?.phrase ?? "On \($0) days" },
            title: { weatherNouns[$0]?.title ?? $0.capitalized },
            plural: { weatherNouns[$0]?.plural ?? "\($0) days" },
            singular: { weatherNouns[$0]?.singular ?? "\($0) day" },
            rest: "Other days"
        ),
        CategoryMeasure(
            id: "moon", source: .sky, grain: .day, minimumDays: 5, outsideNeedsObservation: false,
            phrase: { $0 == "full" ? "Under a full moon" : "Under a new moon" },
            title: { $0 == "full" ? "Full Moons" : "New Moons" },
            plural: { $0 == "full" ? "full-moon days" : "new-moon days" },
            singular: { $0 == "full" ? "full moon" : "new moon" },
            rest: "Other nights",
            minimumCycles: 4,
            windowDays: 240
        ),
        CategoryMeasure(
            id: "barometer", source: .weather, grain: .day, minimumDays: 5, outsideNeedsObservation: true,
            phrase: { $0 == "falling" ? "When the barometer falls" : "When the barometer climbs" },
            title: { $0 == "falling" ? "A Falling Barometer" : "A Rising Barometer" },
            plural: { $0 == "falling" ? "falling-barometer days" : "rising-barometer days" },
            singular: { $0 == "falling" ? "falling-barometer day" : "rising-barometer day" },
            rest: "Steady days"
        ),
        CategoryMeasure(
            id: "posture", source: .device, grain: .keep, minimumDays: 4, outsideNeedsObservation: true,
            phrase: { postureNouns[$0]?.phrase ?? "When you hold me that way" },
            title: { postureNouns[$0]?.title ?? $0.capitalized },
            plural: { postureNouns[$0]?.plural ?? "\($0) pages" },
            singular: { postureNouns[$0]?.singular ?? "\($0) page" },
            rest: "Other ways you hold me"
        ),
        CategoryMeasure(
            id: "screen", source: .device, grain: .keep, minimumDays: 4, outsideNeedsObservation: true,
            phrase: { $0 == "dark" ? "In the dark" : "With the screen bright" },
            title: { $0 == "dark" ? "The Dark" : "Bright Screen" },
            plural: { $0 == "dark" ? "pages in the dark" : "bright-screen pages" },
            singular: { $0 == "dark" ? "page in the dark" : "bright-screen page" },
            rest: "With the lights on",
            entangledNumbers: ["hour"]
        ),
        CategoryMeasure(
            id: "battery", source: .device, grain: .keep, minimumDays: 3, outsideNeedsObservation: true,
            phrase: { _ in "When your phone is nearly out" }, title: { _ in "Nearly Out of Battery" },
            plural: { _ in "nearly-flat pages" }, singular: { _ in "page on a nearly-flat phone" },
            rest: "With battery to spare"
        ),
        CategoryMeasure(
            id: "headphones", source: .device, grain: .keep, minimumDays: 3, outsideNeedsObservation: true,
            phrase: { _ in "With headphones in" }, title: { _ in "Headphones" },
            plural: { _ in "headphone pages" }, singular: { _ in "page with headphones in" },
            rest: "Without them"
        ),
        CategoryMeasure(
            id: "moving", source: .device, grain: .keep, minimumDays: 3, outsideNeedsObservation: true,
            phrase: { _ in "When you write on the move" }, title: { _ in "On the Move" },
            plural: { _ in "pages on the move" }, singular: { _ in "page written on the move" },
            rest: "Sitting still"
        ),
        CategoryMeasure(
            id: "afterEvent", source: .calendar, grain: .keep, minimumDays: 3, outsideNeedsObservation: true,
            phrase: { _ in "Right after something on your calendar ends" }, title: { _ in "Just After" },
            plural: { _ in "pages right after things end" }, singular: { _ in "page right after something ends" },
            rest: "Other times"
        ),
        CategoryMeasure(
            id: "sunLight", source: .sky, grain: .keep, minimumDays: 4, outsideNeedsObservation: true,
            phrase: { sunNouns[$0]?.phrase ?? "In that light" }, title: { sunNouns[$0]?.title ?? $0.capitalized },
            plural: { sunNouns[$0]?.plural ?? "\($0) pages" }, singular: { sunNouns[$0]?.singular ?? "\($0) page" },
            rest: "In other light",
            entangledNumbers: ["hour"]
        ),
        CategoryMeasure(
            id: "tide", source: .weather, grain: .keep, minimumDays: 5, outsideNeedsObservation: true,
            phrase: { $0 == "in" ? "When the tide's coming in" : "When the tide's going out" },
            title: { $0 == "in" ? "The Tide Coming In" : "The Tide Going Out" },
            plural: { $0 == "in" ? "incoming-tide pages" : "outgoing-tide pages" },
            singular: { $0 == "in" ? "incoming tide" : "outgoing tide" },
            rest: "The other way"
        ),
        CategoryMeasure(
            id: "afterWorkout", source: .body, grain: .keep, minimumDays: 3, outsideNeedsObservation: false,
            phrase: { "After a \($0)" }, title: { "After a \($0.capitalized)" },
            plural: { "pages after a \($0)" }, singular: { "page after a \($0)" },
            rest: "Other times"
        ),
        CategoryMeasure(
            id: "weekday", source: .clock, grain: .day, minimumDays: 4, outsideNeedsObservation: false,
            phrase: { "On \($0)s" }, title: { "\($0)s" }, plural: { "\($0)s" }, singular: { $0 },
            rest: "Other days"
        ),
        CategoryMeasure(
            id: "dayPart", source: .clock, grain: .keep, minimumDays: 4, outsideNeedsObservation: true,
            phrase: { dayPartNouns[$0]?.phrase ?? "In the \($0)" },
            title: { dayPartNouns[$0]?.title ?? $0.capitalized },
            plural: { dayPartNouns[$0]?.plural ?? "\($0) pages" },
            singular: { dayPartNouns[$0]?.singular ?? "\($0) page" },
            rest: "The rest of the day",
            entangledNumbers: ["hour"]
        ),
        CategoryMeasure(
            id: "place", source: .place, grain: .day, minimumDays: 3, outsideNeedsObservation: false,
            phrase: { "On days you go to \($0)" }, title: { $0 }, plural: { "\($0) days" },
            singular: { "day at \($0)" }, rest: "Everywhere else"
        ),
        CategoryMeasure(
            id: "photoColour", source: .photo, grain: .day, minimumDays: 3, outsideNeedsObservation: true,
            phrase: { "On days you photograph something \($0)" }, title: { "\($0.capitalized) Pictures" },
            plural: { "\($0) days" }, singular: { "day you photograph something \($0)" },
            rest: "Other picture days"
        )
    ]

    /// How unrelated two sources usually are. Barometer and heart outrank
    /// steps and photos.
    static func strangeness(_ left: NoticingSource, _ right: NoticingSource) -> Int {
        switch Set([left, right]) {
        case [.weather, .body], [.sky, .body], [.photo, .body], [.device, .body]: return 5
        case [.sky, .writing], [.sky, .photo], [.place, .body], [.photo, .weather], [.device, .writing], [.weather, .device]: return 4
        case [.weather, .writing], [.place, .writing], [.clock, .body], [.calendar, .body], [.sky, .clock],
             [.sky, .device], [.calendar, .writing]: return 3
        default: return 2
        }
    }

    // MARK: Category × number

    static func crossings(keeps: [Sample], days: [Sample]) -> [Noticing] {
        // One finding per measure pair is plenty; keep the strongest value.
        var tests: [(CategoryMeasure, String, NumberMeasure, [Sample])] = []
        for category in categoryMeasures where category.windowDays == nil {
            for number in numberMeasures where number.source != category.source && !number.isConditionOnly
                && !category.entangledNumbers.contains(number.id) {
                // A morning page's hour is the morning.
                if category.id == "dayPart", number.grain == .day { continue }
                let units = (category.grain == .day || number.grain == .day) ? days : keeps
                for value in Set(units.flatMap { $0.categories[category.id] ?? [] }).sorted() {
                    tests.append((category, value, number, units))
                }
            }
        }
        return strongestPerPair(tests)
    }

    /// Every (category value, measurement) pair asked is one more chance to be
    /// fooled, so the bar each one must clear is set by how many were asked.
    private static func strongestPerPair(_ tests: [(CategoryMeasure, String, NumberMeasure, [Sample])]) -> [Noticing] {
        let alpha = 0.05 / Double(max(1, tests.count))
        let critical = criticalDistance(alpha: alpha)
        var best: [String: Candidate] = [:]
        for (category, value, number, units) in tests {
            guard let candidate = crossing(category: category, value: value, number: number, units: units, critical: critical) else { continue }
            let key = "\(category.id)|\(number.id)"
            if let current = best[key], current.noticing.rank >= candidate.noticing.rank { continue }
            best[key] = candidate
        }
        // Well past the bar, the arithmetic is enough. Near it, the shapes of
        // real data (a few huge step counts, a lumpy heart) can fool the
        // arithmetic, so those few are dealt out for real.
        return best.values.compactMap { candidate in
            if candidate.distance >= critical + 1.5 { return candidate.noticing }
            return survivesShuffling(
                inside: candidate.inside, outside: candidate.outside, observed: candidate.observed,
                alpha: alpha, seed: candidate.seed
            ) ? candidate.noticing : nil
        }
    }

    /// How many spreads of the shuffled difference the real one sits from zero.
    static func distanceFromChance(inside: [Double], outside: [Double], observed: Double) -> Double {
        let pooled = inside + outside
        let pooledMean = mean(pooled)
        let pooledVariance = pooled.reduce(0) { $0 + ($1 - pooledMean) * ($1 - pooledMean) } / Double(max(1, pooled.count - 1))
        let spread = sqrt(pooledVariance * (1 / Double(inside.count) + 1 / Double(outside.count)))
        return spread > 0 ? observed / spread : 0
    }

    /// The two-sided distance a normal tail needs to be rarer than `alpha`.
    static func criticalDistance(alpha: Double) -> Double {
        var low = 0.0, high = 12.0
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if erfc(middle / 2.0.squareRoot()) > alpha { low = middle } else { high = middle }
        }
        return high
    }

    /// Categories that need many cycles, read over their own longer window.
    static func longCrossings(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        var tests: [(CategoryMeasure, String, NumberMeasure, [Sample])] = []
        for category in categoryMeasures {
            guard let window = category.windowDays else { continue }
            let start = now.addingTimeInterval(-Double(window) * 86_400)
            let windowKeeps = keeps.filter { $0.date >= start && $0.date <= now }
            let windowDays = dayUnits(from: windowKeeps, calendar: calendar)
            for number in numberMeasures where number.source != category.source && !number.isConditionOnly
                && !category.entangledNumbers.contains(number.id) {
                let units = (category.grain == .day || number.grain == .day) ? windowDays : windowKeeps
                for value in Set(units.flatMap { $0.categories[category.id] ?? [] }).sorted() {
                    tests.append((category, value, number, units))
                }
            }
        }
        return strongestPerPair(tests)
    }

    /// A permutation test: deal the same values into "inside" and "outside"
    /// at random thousands of times and count how often chance does as well.
    /// Seeded from the finding, so the same archive always gets the same
    /// answer. Stops as soon as chance has matched it too often to pass.
    static func survivesShuffling(inside: [Double], outside: [Double], observed: Double, alpha: Double, seed: String) -> Bool {
        let rounds = min(20_000, Int((2 / alpha).rounded(.up)))
        let allowed = Int((alpha * Double(rounds + 1)).rounded(.down)) - 1
        guard allowed >= 0 else { return false }
        var pool = inside + outside
        let total = pool.reduce(0, +)
        let insideCount = inside.count, outsideCount = outside.count
        var random = SplitMix(seed: fnv1a(seed))
        var matched = 0
        for _ in 0..<rounds {
            var insideSum = 0.0
            for index in 0..<insideCount {
                let pick = index + Int(random.next() % UInt64(pool.count - index))
                pool.swapAt(index, pick)
                insideSum += pool[index]
            }
            let difference = insideSum / Double(insideCount) - (total - insideSum) / Double(outsideCount)
            if abs(difference) >= observed - 1e-9 {
                matched += 1
                if matched > allowed { return false }
            }
        }
        return true
    }

    private struct SplitMix {
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

    /// Stable across launches, unlike `Hasher`.
    private static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
    }

    private static func replicates(inside: [Sample], outside: [Sample], number: NumberMeasure, rises: Bool) -> Bool {
        let dates = (inside + outside).map(\.date).sorted()
        guard dates.count >= 4 else { return false }
        let middle = dates[dates.count / 2]
        for half in [{ (unit: Sample) in unit.date < middle }, { (unit: Sample) in unit.date >= middle }] {
            let halfIn = inside.filter(half).compactMap { $0.numbers[number.id] }
            let halfOut = outside.filter(half).compactMap { $0.numbers[number.id] }
            guard halfIn.count >= 2, halfOut.count >= 3 else { return false }
            let difference = mean(halfIn) - mean(halfOut)
            guard (difference > 0) == rises, abs(difference) >= number.minimumDifference / 2 else { return false }
        }
        return true
    }

    /// Which moon this is, counted from its own new moon, so every day of one
    /// full moon belongs to the same cycle.
    private static func lunation(_ date: Date) -> Int {
        let newMoonDay = date.timeIntervalSince1970 / 86_400 - MoonPhaseCalendar.phase(on: date).ageDays
        return Int((newMoonDay / MoonPhaseCalendar.synodicMonthDays).rounded())
    }

    /// A crossing that cleared every cheap gate, with what the shuffle needs.
    private struct Candidate {
        var noticing: Noticing
        var inside: [Double]
        var outside: [Double]
        var observed: Double
        var distance: Double
        var seed: String
    }

    private static func crossing(
        category: CategoryMeasure, value: String, number: NumberMeasure, units: [Sample], critical: Double
    ) -> Candidate? {
        // The ordinary state is the background the unusual one is measured
        // against: a steady glass, a phone with battery, no headphones.
        if backgroundValues[category.id] == value { return nil }
        let measured = units.filter { $0.numbers[number.id] != nil }
        let inside = measured.filter { $0.categories[category.id]?.contains(value) == true }
        let outside = measured.filter { unit in
            guard unit.categories[category.id]?.contains(value) != true else { return false }
            return !category.outsideNeedsObservation || unit.categories[category.id]?.isEmpty == false
        }
        let insideDays = Set(inside.map(\.dayID)).count
        let outsideDays = Set(outside.map(\.dayID)).count
        guard insideDays >= category.minimumDays, outsideDays >= minimumOutsideDays else { return nil }
        if category.minimumCycles > 1 {
            // A moon counts only if it gave at least two days: one day at the
            // edge of the archive isn't a moon's worth of evidence.
            let daysPerCycle = Dictionary(grouping: inside, by: { lunation($0.date) })
                .mapValues { Set($0.map(\.dayID)).count }
            guard daysPerCycle.values.filter({ $0 >= 2 }).count >= category.minimumCycles else { return nil }
        }

        let insideValues = inside.compactMap { $0.numbers[number.id] }
        let outsideValues = outside.compactMap { $0.numbers[number.id] }
        let meanIn = mean(insideValues)
        let meanOut = mean(outsideValues)
        let difference = meanIn - meanOut
        guard abs(difference) >= number.minimumDifference else { return nil }
        let pooled = sqrt((variance(insideValues) + variance(outsideValues)) / 2)
        guard pooled > 0 else { return nil }
        let effect = difference / pooled
        let standardError = sqrt(variance(insideValues) / Double(insideValues.count)
                                 + variance(outsideValues) / Double(outsideValues.count))
        guard abs(effect) >= 0.8, standardError > 0, abs(difference / standardError) >= 2.5 else { return nil }
        // Twenty-odd measurements crossed both ways will line up by chance
        // somewhere. A finding has to hold in the older half of the evidence
        // and again in the newer half, the way a real habit would.
        guard replicates(inside: inside, outside: outside, number: number, rises: difference > 0) else { return nil }
        let distance = distanceFromChance(inside: insideValues, outside: outsideValues, observed: abs(difference))
        guard distance >= critical else { return nil }
        let outsideMedian = median(outsideValues)
        let rises = difference > 0
        let agreeing = insideValues.filter { rises ? $0 > outsideMedian : $0 < outsideMedian }.count
        let consistency = Double(agreeing) / Double(insideValues.count)
        guard consistency >= 0.7 else { return nil }

        let clause = rises ? number.rises : number.falls
        let plural = category.plural(value)
        let receipts = inside.suffix(4).reversed().compactMap { unit -> Noticing.Receipt? in
            guard let page = unit.representative, let measuredValue = unit.numbers[number.id] else { return nil }
            return Noticing.Receipt(
                pageID: page.id,
                date: unit.date,
                text: "\(excerpt(page)) \u{2014} \(format(measuredValue, number))"
            )
        }
        let strange = strangeness(category.source, number.source)
        let line = "\(category.phrase(value)), \(clause). I counted. "
            + "\(spelled(agreeing).capitalizedFirst) of \(spelled(insideValues.count)) \(plural) went that way."
        let noticing = Noticing(
            id: "crossing-\(category.id)-\(slug(value))-\(number.id)",
            kind: .crossing,
            headline: "\(category.title(value)) and \(number.title)",
            line: line,
            counted: "\(plural.capitalizedFirst): \(format(meanIn, number)). \(category.rest): \(format(meanOut, number)).",
            falsifier: "If the next three \(plural) go the other way, I'll cross this out.",
            errand: number.check.map { "Next \(category.singular(value)), \($0)." },
            receipts: Array(receipts),
            sources: [category.source, number.source],
            // The rarer condition is the finding: "rain days run slow", not
            // "every day that isn't rain runs fast".
            rank: strange * 12 + min(25, Int(abs(effect) * 10)) + Int(consistency * 20) + min(10, insideDays)
                + Int((1 - Double(insideDays) / Double(insideDays + outsideDays)) * 10),
            test: Noticing.Test(categoryID: category.id, value: value, numberID: number.id,
                                rises: rises, threshold: outsideMedian)
        )
        return Candidate(
            noticing: noticing, inside: insideValues, outside: outsideValues,
            observed: abs(difference), distance: distance, seed: "\(category.id)|\(value)|\(number.id)"
        )
    }

    // MARK: Number × number

    static func trends(days: [Sample]) -> [Noticing] {
        var found: [Noticing] = []
        for (index, first) in numberMeasures.enumerated() {
            for second in numberMeasures[(index + 1)...] where second.source != first.source {
                // The sky can only ever be the cause.
                if first.isConditionOnly && second.isConditionOnly { continue }
                let (cause, effect) = second.isConditionOnly ? (second, first) : (first, second)
                let pairs = days.compactMap { unit -> (Double, Double, Sample)? in
                    guard let a = unit.numbers[cause.id], let b = unit.numbers[effect.id] else { return nil }
                    return (a, b, unit)
                }
                guard pairs.count >= 21 else { continue }
                let rho = spearman(pairs.map(\.0), pairs.map(\.1))
                guard abs(rho) >= 0.55 else { continue }
                // Same test as the crossings: it must hold in each half.
                let chronological = pairs.sorted { $0.2.date < $1.2.date }
                let halfway = chronological.count / 2
                let older = Array(chronological[..<halfway]), newer = Array(chronological[halfway...])
                let olderRho = spearman(older.map(\.0), older.map(\.1))
                let newerRho = spearman(newer.map(\.0), newer.map(\.1))
                guard olderRho * rho > 0, newerRho * rho > 0,
                      abs(olderRho) >= 0.35, abs(newerRho) >= 0.35 else { continue }
                let sorted = pairs.sorted { $0.0 < $1.0 }
                let third = max(3, sorted.count / 3)
                let low = Array(sorted.prefix(third))
                let high = Array(sorted.suffix(third))
                let effectGap = mean(high.map(\.1)) - mean(low.map(\.1))
                guard abs(effectGap) >= effect.minimumDifference else { continue }
                let together = rho > 0
                let line = "When \(cause.rises), \(together ? effect.rises : effect.falls). "
                    + "Not every day. Most of them. I lined \(spelled(pairs.count)) days up to check."
                let counted = "Your highest third: \(format(mean(high.map(\.0)), cause)), \(format(mean(high.map(\.1)), effect)). "
                    + "Your lowest third: \(format(mean(low.map(\.0)), cause)), \(format(mean(low.map(\.1)), effect))."
                let receipts = (high.suffix(2) + low.prefix(2)).compactMap { a, b, unit -> Noticing.Receipt? in
                    guard let page = unit.representative else { return nil }
                    return Noticing.Receipt(
                        pageID: page.id,
                        date: unit.date,
                        text: "\(excerpt(page)) \u{2014} \(format(a, cause)), \(format(b, effect))"
                    )
                }
                found.append(Noticing(
                    id: "trend-\(cause.id)-\(effect.id)",
                    kind: .trend,
                    headline: "\(cause.title) and \(effect.title)",
                    line: line,
                    counted: counted,
                    falsifier: "If the next week runs the other way round, I'll cross this out.",
                    errand: effect.check.map { "Tomorrow, \($0)." },
                    receipts: receipts,
                    sources: [cause.source, effect.source],
                    rank: strangeness(cause.source, effect.source) * 12 + Int(abs(rho) * 30) + min(10, pairs.count / 3)
                ))
            }
        }
        return found
    }

    // MARK: Coincidences, records, firsts, absences

    static func sameMinute(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        let byMinute = Dictionary(grouping: keeps) { unit -> String in
            let parts = calendar.dateComponents([.hour, .minute], from: unit.date)
            let hour12 = ((parts.hour ?? 0) + 11) % 12 + 1
            return String(format: "%d:%02d", hour12, parts.minute ?? 0)
        }
        let found = byMinute.compactMap { minute, units -> Noticing? in
            let days = Set(units.map(\.dayID))
            let digits = minute.filter(\.isNumber)
            let isPretty = Set(digits).count == 1 || ["1234", "123", "234", "345", "456"].contains(digits)
            // On the hour is when alarms and reminders go off, not a coincidence.
            guard isPretty || !minute.hasSuffix(":00"),
                  days.count >= (isPretty ? 3 : 5),
                  let latest = units.map(\.date).max(),
                  now.timeIntervalSince(latest) < 3 * 86_400 else { return nil }
            let receipts = units.suffix(4).reversed().compactMap { unit in
                unit.representative.map { Noticing.Receipt(pageID: $0.id, date: unit.date, text: excerpt($0)) }
            }
            return Noticing(
                id: "coincidence-minute-\(digits)",
                kind: .coincidence,
                headline: "Exactly \(minute)",
                line: "\(spelled(days.count).capitalizedFirst) pages at exactly \(minute). I don't know what it means. I'm writing it down.",
                counted: "\(spelled(days.count).capitalizedFirst) different days. Same minute.",
                falsifier: nil,
                errand: "Look at the clock next time you open me.",
                receipts: Array(receipts),
                sources: [.clock],
                rank: 40 + min(days.count, 6) * 4 + (isPretty ? 10 : 0)
            )
        }
        // One minute is a coincidence; a list of them is a timetable.
        return found.max { $0.rank == $1.rank ? $0.id > $1.id : $0.rank < $1.rank }.map { [$0] } ?? []
    }

    static func twinLengths(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        let recent = keeps.filter { now.timeIntervalSince($0.date) < 3 * 86_400 && ($0.numbers["words"] ?? 0) >= 25 }
        for newer in recent.reversed() {
            guard let count = newer.numbers["words"] else { continue }
            let twin = keeps.last { older in
                older.numbers["words"] == count && newer.date.timeIntervalSince(older.date) >= 21 * 86_400
            }
            guard let twin, let newPage = newer.representative, let oldPage = twin.representative else { continue }
            let apart = calendar.dateComponents([.day], from: twin.date, to: newer.date).day ?? 0
            return [Noticing(
                id: "coincidence-twins-\(oldPage.id)-\(newPage.id)",
                kind: .coincidence,
                headline: "\(spelled(Int(count)).capitalizedFirst) Words Each",
                line: "Two pages, \(spelled(apart)) days apart. \(spelled(Int(count)).capitalizedFirst) words each. I counted twice.",
                counted: nil,
                falsifier: nil,
                errand: nil,
                receipts: [
                    Noticing.Receipt(pageID: newPage.id, date: newer.date, text: excerpt(newPage)),
                    Noticing.Receipt(pageID: oldPage.id, date: twin.date, text: excerpt(oldPage))
                ],
                sources: [.writing],
                rank: 46
            )]
        }
        return []
    }

    static func records(days: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        let measured = days.filter { $0.numbers["steps"] != nil }
        guard measured.count >= 30,
              let latest = measured.last,
              now.timeIntervalSince(latest.date) < 2 * 86_400,
              let steps = latest.numbers["steps"] else { return [] }
        let previous = measured.dropLast().compactMap { $0.numbers["steps"] }.max() ?? 0
        guard steps > previous * 1.05, let page = latest.representative else { return [] }
        return [Noticing(
            id: "record-steps-\(latest.dayID)",
            kind: .record,
            headline: "The Most You've Walked",
            line: "That's the most you've walked since I started counting. Where did you go?",
            counted: "\(groupedNumber(steps)) steps. The last most was \(groupedNumber(previous)).",
            falsifier: nil,
            errand: "Tell me where your feet went.",
            receipts: [Noticing.Receipt(pageID: page.id, date: latest.date, text: excerpt(page))],
            sources: [.body],
            rank: 62
        )]
    }

    static func firsts(days: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        guard let earliest = days.first?.date,
              now.timeIntervalSince(earliest) >= 45 * 86_400 else { return [] }
        let nouns = ["snow": "snow", "frost": "frost", "storm": "storm", "fog": "fog"]
        return nouns.compactMap { tag, noun -> Noticing? in
            guard let first = days.first(where: { $0.categories["weather"]?.contains(tag) == true }),
                  now.timeIntervalSince(first.date) < 2 * 86_400,
                  let page = first.representative else { return nil }
            return Noticing(
                id: "first-\(tag)-\(first.dayID)",
                kind: .first,
                headline: "First \(noun.capitalized)",
                line: "First \(noun) you've shown me. I've been waiting.",
                counted: nil,
                falsifier: nil,
                errand: "Go and touch some of it.",
                receipts: [Noticing.Receipt(pageID: page.id, date: first.date, text: excerpt(page))],
                sources: [.weather],
                rank: 64
            )
        }
    }

    static func missingWeekday(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        guard let earliest = keeps.first?.date else { return [] }
        let windowStart = max(earliest, calendar.date(byAdding: .day, value: -56, to: now) ?? now)
        guard now.timeIntervalSince(windowStart) >= 42 * 86_400 else { return [] }
        let window = keeps.filter { $0.date >= windowStart }
        guard window.count >= 20 else { return [] }
        let counts = Dictionary(grouping: window) { calendar.component(.weekday, from: $0.date) }.mapValues(\.count)
        let busy = counts.values.filter { $0 >= 4 }.count
        guard busy >= 4 else { return [] }
        for weekday in 1...7 where counts[weekday] == nil {
            let name = weekdayNames[weekday - 1]
            var occurrences = 0
            var day = calendar.startOfDay(for: windowStart)
            while day <= now {
                if calendar.component(.weekday, from: day) == weekday { occurrences += 1 }
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? now.addingTimeInterval(1)
            }
            guard occurrences >= 6 else { continue }
            return [Noticing(
                id: "absence-weekday-\(weekday)",
                kind: .absence,
                headline: "No \(name)s",
                line: "You never write on \(name)s. \(spelled(occurrences).capitalizedFirst) \(name)s now. What happens on \(name)s?",
                counted: "\(window.count) pages in eight weeks. None of them on a \(name).",
                falsifier: "Write me one on a \(name) and I'll stop saying it.",
                errand: "Next \(name), leave me one line.",
                receipts: [],
                sources: [.clock],
                rank: 58
            )]
        }
        return []
    }

    static func sunKeeper(keeps: [Sample], calendar: Calendar) -> [Noticing] {
        let placed = keeps.compactMap { unit -> (Sample, Date)? in
            guard let context = unit.pages.first?.context,
                  let latitude = context.latitude, let longitude = context.longitude else { return nil }
            let coordinate = ReaderCoordinate(latitude: latitude, longitude: longitude)
            guard let sunset = SolarClock.sunset(on: unit.date, at: coordinate, calendar: calendar) else { return nil }
            return (unit, sunset)
        }
        let atSunset = placed.filter { abs($0.0.date.timeIntervalSince($0.1)) <= 20 * 60 }
        let days = Set(atSunset.map(\.0.dayID))
        guard days.count >= 4, placed.count >= 12,
              Double(days.count) / Double(Set(placed.map(\.0.dayID)).count) >= 0.12 else { return [] }
        let receipts = atSunset.suffix(4).reversed().compactMap { unit, _ in
            unit.representative.map { Noticing.Receipt(pageID: $0.id, date: unit.date, text: excerpt($0)) }
        }
        return [Noticing(
            id: "sun-keeper-\(days.count)",
            kind: .sunKeeper,
            headline: "Sunset Pages",
            line: "\(spelled(days.count).capitalizedFirst) pages within twenty minutes of sunset. You don't set an alarm. You just turn up.",
            counted: "\(days.count) sunsets out of \(Set(placed.map(\.0.dayID)).count) days I know where you were.",
            falsifier: nil,
            errand: "Tonight, look west when the light goes.",
            receipts: Array(receipts),
            sources: [.sky, .clock],
            rank: 66
        )]
    }

    /// The same stretch of the reader's own writing, weeks apart, quoted as
    /// they wrote it: whole words, their capitals, their full stop.
    static func refrains(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        struct Written {
            var unit: Sample
            var page: BookPage
            var text: String
            var words: [(word: String, range: Range<String.Index>)]
        }
        func tokens(_ text: String) -> [(word: String, range: Range<String.Index>)] {
            var found: [(String, Range<String.Index>)] = []
            var start: String.Index?
            var index = text.startIndex
            while index < text.endIndex {
                let character = text[index]
                let inWord = character.isLetter || character.isNumber || character == "'" || character == "\u{2019}"
                if inWord, start == nil { start = index }
                if !inWord, let begun = start {
                    found.append((text[begun..<index].lowercased(), begun..<index))
                    start = nil
                }
                index = text.index(after: index)
            }
            if let begun = start { found.append((text[begun...].lowercased(), begun..<text.endIndex)) }
            return found
        }
        let written = keeps.compactMap { unit -> Written? in
            guard let page = unit.representative,
                  !EditionCurator.defaultPrivateTypes.contains(page.type),
                  let text = page.readerAuthoredTextForAnalysis else { return nil }
            let words = tokens(text)
            return words.count >= 5 ? Written(unit: unit, page: page, text: text, words: words) : nil
        }
        let halfYear = now.addingTimeInterval(-183 * 86_400)
        let recent = written.filter { now.timeIntervalSince($0.unit.date) < 3 * 86_400 }.suffix(2)
        for newer in recent.reversed() {
            let newWords = newer.words.map(\.word)
            var best: (length: Int, newStart: Int, older: Written)?
            for older in written where older.unit.date >= halfYear
                && newer.unit.date.timeIntervalSince(older.unit.date) >= 21 * 86_400 {
                // Longest run of words the two pages share, in order.
                let oldWords = older.words.map(\.word)
                var previous = [Int](repeating: 0, count: oldWords.count + 1)
                for i in 1...newWords.count {
                    var current = [Int](repeating: 0, count: oldWords.count + 1)
                    for j in 1...max(1, oldWords.count) where j <= oldWords.count && newWords[i - 1] == oldWords[j - 1] {
                        current[j] = previous[j - 1] + 1
                        if current[j] > (best?.length ?? 0) { best = (current[j], i - current[j], older) }
                    }
                    previous = current
                }
            }
            // A refrain is a phrase they keep reaching for. A whole sentence
            // or page said twice is a copy, and quoting it back is no news.
            guard let best, (5...14).contains(best.length) else { continue }
            let run = Array(newWords[best.newStart..<(best.newStart + best.length)])
            let content = run.filter { $0.count >= 4 && !LiteraryContinuityProjector.stopWords.contains($0) }
            // "The light was doing that thing" is one real word long and still
            // a refrain; a five-word run needs two.
            guard content.count >= 2 || (best.length >= 6 && content.count >= 1) else { continue }
            // Quote the reader's own characters, and their full stop if the run ends a sentence.
            let first = newer.words[best.newStart].range.lowerBound
            var last = newer.words[best.newStart + best.length - 1].range.upperBound
            if last < newer.text.endIndex, ".!?".contains(newer.text[last]) { last = newer.text.index(after: last) }
            var quoted = String(newer.text[first..<last])
            if let initial = quoted.first, initial.isLowercase { quoted = initial.uppercased() + quoted.dropFirst() }
            if let end = quoted.last, !".!?".contains(end) { quoted += "\u{2026}" }
            let month = monthName(best.older.unit.date, calendar: calendar)
            return [Noticing(
                id: "refrain-\(slug(run.joined(separator: " ")))",
                kind: .refrain,
                headline: "You Said It Again",
                line: "\u{201C}\(quoted)\u{201D} You wrote that in \(month). You wrote it again \(relativeDay(newer.unit.date, now: now, calendar: calendar)).",
                counted: nil,
                falsifier: nil,
                errand: nil,
                receipts: [
                    Noticing.Receipt(pageID: newer.page.id, date: newer.unit.date, text: excerpt(newer.page)),
                    Noticing.Receipt(pageID: best.older.page.id, date: best.older.unit.date, text: excerpt(best.older.page))
                ],
                sources: [.writing],
                rank: 58 + min(best.length, 10) * 2
            )]
        }
        return []
    }

    // MARK: Rhymes, colours, empty pictures, shifts

    /// Today is an old day again: same place, same weather, same part of the day.
    static func sameDay(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        func signature(_ unit: Sample) -> (place: String, weather: Set<String>, part: String)? {
            guard let place = unit.categories["place"]?.first,
                  let weather = unit.categories["weather"], !weather.isEmpty,
                  let part = unit.categories["dayPart"]?.first else { return nil }
            return (place, weather, part)
        }
        for recent in keeps.reversed() where now.timeIntervalSince(recent.date) < 2 * 86_400 {
            guard let today = signature(recent), let page = recent.representative else { continue }
            let match = keeps.last { older in
                guard recent.date.timeIntervalSince(older.date) >= 28 * 86_400,
                      let then = signature(older) else { return false }
                return then.place == today.place && then.part == today.part && !then.weather.isDisjoint(with: today.weather)
            }
            guard let match, let oldPage = match.representative else { continue }
            let skies = ["rain": "rain", "snow": "snow", "fog": "fog", "storm": "a storm", "wind": "wind",
                         "cloud": "a grey sky", "bright": "a bright sky", "frost": "frost", "hot": "heat", "cold": "cold"]
            let weather = today.weather.intersection(match.categories["weather"] ?? [])
                .sorted().first.map { skies[$0] ?? $0 } ?? "the same sky"
            let part = today.part
            let when = "\(calendar.component(.day, from: match.date)) \(monthName(match.date, calendar: calendar))"
            let lead: String
            if calendar.isDate(recent.date, inSameDayAs: now) {
                lead = "Today's the same as"
            } else {
                lead = "Yesterday was the same as"
            }
            return [Noticing(
                id: "rhyme-\(oldPage.id)-\(page.id)",
                kind: .rhyme,
                headline: "This Day Again",
                line: "\(lead) \(when): \(weather), \(today.place), the \(part). I put them side by side.",
                counted: nil,
                falsifier: nil,
                errand: "Read the old one. See what changed.",
                receipts: [
                    Noticing.Receipt(pageID: page.id, date: recent.date, text: excerpt(page)),
                    Noticing.Receipt(pageID: oldPage.id, date: match.date, text: excerpt(oldPage))
                ],
                sources: [.place, .weather, .clock],
                rank: 68
            )]
        }
        return []
    }

    /// "September was green. October's been orange." Only when a month has
    /// enough pictures for a colour to win.
    static func monthColours(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        func dominant(in month: Date) -> (colour: String, share: Double, count: Int)? {
            let colours = keeps
                .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .flatMap { $0.categories["photoColour"] ?? [] }
            guard colours.count >= 6 else { return nil }
            let counts = Dictionary(grouping: colours, by: { $0 }).mapValues(\.count)
            guard let top = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }) else { return nil }
            return (top.key, Double(top.value) / Double(colours.count), colours.count)
        }
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
              let then = dominant(in: lastMonth), let current = dominant(in: now),
              then.share >= 0.35, current.share >= 0.35, then.colour != current.colour else { return [] }
        let previousName = monthName(lastMonth, calendar: calendar)
        let currentName = monthName(now, calendar: calendar)
        return [Noticing(
            id: "colour-\(calendar.component(.year, from: now))-\(calendar.component(.month, from: now))-\(current.colour)",
            kind: .colour,
            headline: "\(currentName) Is \(current.colour.capitalized)",
            line: "\(previousName) was \(then.colour). \(currentName)'s been \(current.colour). Your pictures did that, not me.",
            counted: "\(Int((then.share * 100).rounded()))% of \(then.count) pictures in \(previousName). \(Int((current.share * 100).rounded()))% of \(current.count) so far in \(currentName).",
            falsifier: nil,
            errand: "Find something \(then.colour) today. See if it still looks right.",
            receipts: [],
            sources: [.photo],
            rank: 60
        )]
    }

    static func nobodyInThePictures(keeps: [Sample]) -> [Noticing] {
        let counted = keeps.compactMap { $0.numbers["photoPeople"] }
        guard counted.count >= 12, counted.allSatisfy({ $0 == 0 }) else { return [] }
        let receipts = keeps.filter { $0.numbers["photoPeople"] != nil }.suffix(3).reversed().compactMap { unit in
            unit.representative.map { Noticing.Receipt(pageID: $0.id, date: unit.date, text: excerpt($0)) }
        }
        return [Noticing(
            id: "nobody-\(counted.count / 6)",
            kind: .nobody,
            headline: "Nobody in the Pictures",
            line: "\(spelled(counted.count).capitalizedFirst) pictures and nobody in any of them. Where is everybody?",
            counted: nil,
            falsifier: "Bring me one picture with a person in it and I'll stop asking.",
            errand: nil,
            receipts: Array(receipts),
            sources: [.photo],
            rank: 57
        )]
    }

    /// The reader who never asked starts asking.
    static func questionShift(keeps: [Sample], now: Date) -> [Noticing] {
        let weekStart = now.addingTimeInterval(-7 * 86_400)
        let baselineStart = now.addingTimeInterval(-63 * 86_400)
        let thisWeek = keeps.filter { $0.date >= weekStart && $0.numbers["questions"] != nil }
        let before = keeps.filter { $0.date >= baselineStart && $0.date < weekStart && $0.numbers["questions"] != nil }
        let asked = Int(thisWeek.compactMap { $0.numbers["questions"] }.reduce(0, +))
        let askedBefore = Int(before.compactMap { $0.numbers["questions"] }.reduce(0, +))
        guard asked >= 3, thisWeek.filter({ ($0.numbers["questions"] ?? 0) > 0 }).count >= 2,
              before.count >= 10, Double(askedBefore) / 8 < 0.5 else { return [] }
        let receipts = thisWeek.filter { ($0.numbers["questions"] ?? 0) > 0 }.suffix(3).reversed().compactMap { unit in
            unit.representative.map { Noticing.Receipt(pageID: $0.id, date: unit.date, text: excerpt($0)) }
        }
        return [Noticing(
            id: "shift-questions-\(Int(now.timeIntervalSince1970 / (7 * 86_400)))",
            kind: .shift,
            headline: "You Started Asking",
            line: "You asked me \(spelled(asked)) questions this week. You never used to ask me anything.",
            counted: "The eight weeks before: \(spelled(askedBefore)), across \(before.count) pages.",
            falsifier: nil,
            errand: "Ask me another one.",
            receipts: Array(receipts),
            sources: [.writing],
            rank: 63
        )]
    }

    // MARK: Sleep, carried pictures, the heart at the keep

    /// The last page before sleep and the first after waking, when the reader
    /// keeps the same distance from their own night.
    static func sleepRhythms(keeps: [Sample]) -> [Noticing] {
        var nights: [Date: Date] = [:]
        for unit in keeps {
            guard let context = unit.pages.first?.context,
                  let start = context.sleepStart, let end = context.sleepEnd, end > start else { continue }
            nights[start] = end
        }
        guard nights.count >= 6 else { return [] }
        let times = keeps.map(\.date).sorted()

        func rhythm(_ gaps: [Double], before: Bool) -> Noticing? {
            guard gaps.count >= 6 else { return nil }
            let middle = median(gaps)
            let near = gaps.filter { abs($0 - middle) <= 20 }.count
            guard Double(near) / Double(gaps.count) >= 0.7, middle <= (before ? 90 : 45) else { return nil }
            let minutes = max(5, Int((middle / 5).rounded()) * 5)
            let spelledMinutes = minutes <= 20 ? spelled(minutes) : "\(minutes)"
            let counted = "\(spelled(near).capitalizedFirst) nights out of \(spelled(gaps.count))."
            return before
                ? Noticing(
                    id: "rhythm-before-sleep-\(minutes)",
                    kind: .rhythm,
                    headline: "The Last Page Before Sleep",
                    line: "You give me your last page about \(spelledMinutes) minutes before you fall asleep. I'm the last thing.",
                    counted: counted,
                    falsifier: "If you start writing at midnight and sleeping at two, I'll notice that too.",
                    errand: nil, receipts: [], sources: [.body, .clock], rank: 70)
                : Noticing(
                    id: "rhythm-after-waking-\(minutes)",
                    kind: .rhythm,
                    headline: "The First Thing After Waking",
                    line: "You find me about \(spelledMinutes) minutes after you wake up. Before breakfast, mostly.",
                    counted: counted,
                    falsifier: nil,
                    errand: "Tomorrow, write down the first thing you see.",
                    receipts: [], sources: [.body, .clock], rank: 66)
        }

        var before: [Double] = []
        var after: [Double] = []
        for (start, end) in nights {
            if let last = times.last(where: { $0 < start }), start.timeIntervalSince(last) <= 4 * 3600 {
                before.append(start.timeIntervalSince(last) / 60)
            }
            if let first = times.first(where: { $0 > end }), first.timeIntervalSince(end) <= 3 * 3600 {
                after.append(first.timeIntervalSince(end) / 60)
            }
        }
        return [rhythm(before, before: true), rhythm(after, before: false)].compactMap(\.self)
    }

    /// A picture taken days before it was given.
    static func carried(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        for unit in keeps.reversed() where now.timeIntervalSince(unit.date) < 3 * 86_400 {
            guard let page = unit.pages.first,
                  let taken = page.mediaAssets.compactMap(PhotoTakenAt.takenAt).first else { continue }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: taken),
                                               to: calendar.startOfDay(for: unit.date)).day ?? 0
            guard days >= 2, days <= 60 else { continue }
            let takenDay = days < 7 ? "on \(weekdayNames[calendar.component(.weekday, from: taken) - 1])"
                : "on \(calendar.component(.day, from: taken)) \(monthName(taken, calendar: calendar))"
            let givenDay = relativeDay(unit.date, now: now, calendar: calendar)
            let distance = page.mediaAssets.lazy.compactMap { PhotoDetails.carriedKilometres($0, keptAt: page.context) }.first
            let far = distance.map { $0 >= 5 ? " And \(groupedNumber($0)) kilometres." : "" } ?? ""
            return [Noticing(
                id: "carried-\(page.id)",
                kind: .carried,
                headline: "You Carried This One",
                line: "You took this picture \(takenDay). You gave it to me \(givenDay). You carried it \(spelled(days)) days.\(far)",
                counted: nil,
                falsifier: nil,
                errand: "What made you bring it now?",
                receipts: [Noticing.Receipt(pageID: page.id, date: unit.date, text: excerpt(page))],
                sources: [.photo, .clock],
                rank: 67
            )]
        }
        return []
    }

    /// The fastest the heart has been at a keep this month, on the newest page.
    static func heartAtKeepRecord(keeps: [Sample], now: Date) -> [Noticing] {
        let month = keeps.filter { now.timeIntervalSince($0.date) < 30 * 86_400 && $0.numbers["heartAtKeep"] != nil }
        guard month.count >= 10,
              let latest = month.last, now.timeIntervalSince(latest.date) < 2 * 86_400,
              let beat = latest.numbers["heartAtKeep"], let page = latest.representative else { return [] }
        let others = month.dropLast().compactMap { $0.numbers["heartAtKeep"] }
        guard let previous = others.max(), beat >= previous + 5 else { return [] }
        return [Noticing(
            id: "record-heart-\(page.id)",
            kind: .record,
            headline: "Your Heart at This Page",
            line: "Your heart was going fast when you gave me this one. Faster than any page this month.",
            counted: "\(Int(beat)) beats a minute. Your usual when you write to me: \(Int(median(others).rounded())).",
            falsifier: nil,
            errand: "What was happening?",
            receipts: [Noticing.Receipt(pageID: page.id, date: latest.date, text: excerpt(page))],
            sources: [.body, .writing],
            rank: 69
        )]
    }

    // MARK: How it was written, who was in it, what the sky was doing

    static func crossedOutMoreThanKept(keeps: [Sample], now: Date) -> [Noticing] {
        for unit in keeps.reversed() where now.timeIntervalSince(unit.date) < 2 * 86_400 {
            guard let page = unit.pages.first, let writing = page.context?.writing,
                  let deleted = writing.charactersDeleted, let kept = writing.charactersKept,
                  kept >= 15, deleted > kept else { continue }
            return [Noticing(
                id: "record-crossed-out-\(page.id)",
                kind: .record,
                headline: "What You Crossed Out",
                line: "You crossed out more than you kept on this one. I only got what you left. I didn't read the rest.",
                counted: nil,
                falsifier: nil,
                errand: nil,
                receipts: [Noticing.Receipt(pageID: page.id, date: unit.date, text: excerpt(page))],
                sources: [.writing],
                rank: 61
            )]
        }
        return []
    }

    /// The first photograph from the front camera.
    static func firstFace(keeps: [Sample], now: Date) -> [Noticing] {
        let selfies = keeps.filter { unit in
            unit.pages.first?.mediaAssets.contains { $0.metadata[PhotoDetails.cameraKey] == "front" } == true
        }
        guard selfies.count == 1, let only = selfies.first, now.timeIntervalSince(only.date) < 2 * 86_400,
              keeps.count >= 20, let page = only.pages.first else { return [] }
        return [Noticing(
            id: "first-face-\(page.id)",
            kind: .first,
            headline: "Your Own Face",
            line: "That's the first time you've shown me your own face. I've had your handwriting for ages.",
            counted: nil,
            falsifier: nil,
            errand: nil,
            receipts: [Noticing.Receipt(pageID: page.id, date: only.date, text: excerpt(page))],
            sources: [.photo],
            rank: 72
        )]
    }

    /// A geomagnetic storm overhead while the reader kept a page.
    static func auroraWeather(keeps: [Sample], now: Date, calendar: Calendar) -> [Noticing] {
        guard let unit = keeps.last(where: { now.timeIntervalSince($0.date) < 86_400 && ($0.pages.first?.context?.kpIndex ?? 0) >= 5 }),
              let page = unit.pages.first else { return [] }
        return [Noticing(
            id: "first-aurora-\(unit.dayID)",
            kind: .first,
            headline: "A Storm You Can't Hear",
            line: "There was a magnetic storm in the sky when you kept this. Aurora weather. Did you look up?",
            counted: nil,
            falsifier: nil,
            errand: "Tonight, if it's clear, look north.",
            receipts: [Noticing.Receipt(pageID: page.id, date: unit.date, text: excerpt(page))],
            sources: [.sky],
            rank: 66
        )]
    }

    // MARK: Helpers

    /// The Book speaks English whatever the device's calendar locale says;
    /// a bare Gregorian calendar hands back "Thu".
    static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                             "August", "September", "October", "November", "December"]

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        return values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count - 1)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    static func spearman(_ left: [Double], _ right: [Double]) -> Double {
        func ranks(_ values: [Double]) -> [Double] {
            let order = values.indices.sorted { values[$0] < values[$1] }
            var result = [Double](repeating: 0, count: values.count)
            var index = 0
            while index < order.count {
                var end = index
                while end + 1 < order.count, values[order[end + 1]] == values[order[index]] { end += 1 }
                let rank = Double(index + end) / 2
                for position in index...end { result[order[position]] = rank }
                index = end + 1
            }
            return result
        }
        let a = ranks(left), b = ranks(right)
        let meanA = mean(a), meanB = mean(b)
        var numerator = 0.0, sumA = 0.0, sumB = 0.0
        for index in a.indices {
            numerator += (a[index] - meanA) * (b[index] - meanB)
            sumA += (a[index] - meanA) * (a[index] - meanA)
            sumB += (b[index] - meanB) * (b[index] - meanB)
        }
        guard sumA > 0, sumB > 0 else { return 0 }
        return numerator / sqrt(sumA * sumB)
    }

    static func wordCount(_ text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "\u{2019}" }.count
    }

    static func format(_ value: Double, _ measure: NumberMeasure) -> String {
        if measure.isClock {
            let hour = Int(value) % 24
            let minute = Int(((value - Double(Int(value))) * 60).rounded()) % 60
            let hour12 = (hour + 11) % 12 + 1
            return String(format: "%d:%02d %@", hour12, minute, hour < 12 ? "in the morning" : (hour < 18 ? "in the afternoon" : "at night"))
        }
        let number = measure.decimals == 0 ? groupedNumber(value) : String(format: "%.\(measure.decimals)f", value)
        return "\(number) \(measure.unit)"
    }

    static func groupedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    static func spelled(_ value: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                     "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
                     "eighteen", "nineteen", "twenty"]
        return words.indices.contains(value) ? words[value] : "\(value)"
    }

    static func excerpt(_ page: BookPage) -> String {
        let text = (page.readerAuthoredTextForAnalysis ?? page.archivePreviewText ?? page.type.title)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 70 else { return "\u{201C}\(text)\u{201D}" }
        let clipped = text.prefix(70)
        let cut = clipped.lastIndex(of: " ") ?? clipped.endIndex
        return "\u{201C}\(clipped[..<cut])\u{2026}\u{201D}"
    }

    static func slug(_ value: String) -> String {
        value.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { $0.append($1) }
    }

    static func monthName(_ date: Date, calendar: Calendar) -> String {
        monthNames[calendar.component(.month, from: date) - 1]
    }

    static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        return "on \(weekdayNames[calendar.component(.weekday, from: date) - 1])"
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - On the desk

extension BookNoticesPageSourceAdapter {
    static let crossingSpokeTagPrefix = "crossing-spoke:"
    static let crossingCoincidenceTag = "crossing-coincidence"

    /// The strangest noticings that haven't been said, as "I Notice" Pages.
    /// The front of the leaf says it; the fold holds what was counted, the
    /// pages it came from, what would prove it wrong, and a small errand.
    func crossingSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let alreadyNoticed = day.pages.contains { $0.type == .bookNotices || $0.tags.contains("book-notices") }
        guard !alreadyNoticed else { return [] }
        let allDays = inputs.days + [day]
        let keptTags = allDays.flatMap(\.pages).flatMap(\.tags)
        let spoken = Set(keptTags.compactMap { tag in
            tag.hasPrefix(Self.crossingSpokeTagPrefix) ? String(tag.dropFirst(Self.crossingSpokeTagPrefix.count)) : nil
        })
        // Coincidences and refrains are delight, not data: one a week each.
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let recentPages = allDays.flatMap(\.pages).filter { $0.createdAt >= weekAgo }
        let recentCoincidence = recentPages.contains { $0.tags.contains(Self.crossingCoincidenceTag) }
        let recentRefrain = recentPages.contains { $0.tags.contains("crossing-refrain") }

        // The model's verdict, when it has given one, is final: a dropped
        // noticing is one a person would have shrugged at.
        let dropped = Set((inputs.writingDesk.verdicts ?? [:]).filter { !$0.value.keep }.keys)
        var chosen: [Noticing] = []
        for noticing in NoticingCrossings.noticings(days: allDays, now: now)
        where !spoken.contains(noticing.id) && !dropped.contains(noticing.id) {
            if noticing.kind == .coincidence, recentCoincidence { continue }
            if noticing.kind == .refrain, recentRefrain { continue }
            if chosen.contains(where: { $0.kind == noticing.kind }) { continue }
            chosen.append(noticing)
            if chosen.count == 2 { break }
        }
        return chosen.map { surface(for: $0, day: day, now: now) }
    }

    private func surface(for noticing: Noticing, day: BookDay, now: Date) -> SurfacePage {
        let separator = "\u{1F}"
        var cards: [(String, String, String)] = []
        if let counted = noticing.counted { cards.append(("What I counted", counted, "number")) }
        for receipt in noticing.receipts.prefix(4) {
            cards.append((Self.crossingDateLabel(receipt.date, now: now), receipt.text, "doc.text"))
        }
        if let falsifier = noticing.falsifier { cards.append(("What would make me wrong", falsifier, "xmark.circle")) }
        if let errand = noticing.errand { cards.append(("Try this", errand, "figure.walk")) }

        var tags = ["book-notices", "crossing", "crossing-\(noticing.kind.rawValue)",
                    "\(Self.crossingSpokeTagPrefix)\(noticing.id)"]
        if noticing.kind == .coincidence { tags.append(Self.crossingCoincidenceTag) }
        if noticing.touchesBody { tags.append("private-body") }

        let body = [noticing.line, noticing.counted].compactMap(\.self).joined(separator: "\n\n")
        return SurfacePage(
            id: "\(source.id)-crossing-\(noticing.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(92, 60 + noticing.rank / 4),
            reason: noticing.line.bookPreviewSentenceLimit(1),
            prompt: Self.crossingPrompt(noticing.kind),
            detail: noticing.line.bookPreviewSentenceLimit(2),
            payload: BookPagePayload(
                headline: noticing.headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "crossingID": noticing.id,
                    "crossingKind": noticing.kind.rawValue,
                    "crossingSources": noticing.sources.map(\.rawValue).joined(separator: ","),
                    "observationKey": "crossing:\(noticing.id)",
                    "evidencePageIDs": noticing.receipts.map(\.pageID).joined(separator: ","),
                    "tinyPatternCards": cards.map { [$0.0, $0.1, $0.2].joined(separator: separator) }.joined(separator: "\n"),
                    "magicMomentEligible": noticing.rank >= 80 ? "true" : "false",
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }

    private static func crossingPrompt(_ kind: Noticing.Kind) -> String {
        switch kind {
        case .crossing, .trend: return "I counted something."
        case .coincidence: return "Something lined up."
        case .record: return "That's new."
        case .first: return "A first."
        case .absence: return "Something's missing."
        case .sunKeeper: return "I watched when you come."
        case .refrain: return "You said it again."
        case .rhyme: return "This day happened before."
        case .colour: return "Your pictures changed colour."
        case .nobody: return "Nobody's there."
        case .shift: return "Something changed."
        case .rhythm: return "I know when you come."
        case .carried: return "You kept this one a while."
        }
    }

    private static func crossingDateLabel(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }
}


// MARK: - When a photograph was taken

/// The camera's own date, so the Book can tell a picture taken today from one
/// carried for three days before it was given. Reads EXIF `DateTimeOriginal`
/// with its offset when the camera wrote one; nothing leaves the device.
enum PhotoTakenAt {
    static let metadataKey = "attentionTakenAt"

    static func date(from data: Data) -> Date? {
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
        return parse(stamp, offset: offset)
        #else
        return nil
        #endif
    }

    /// "2026:10:21 16:44:02" plus an optional "-04:00".
    static func parse(_ stamp: String, offset: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = offset == nil ? "yyyy:MM:dd HH:mm:ss" : "yyyy:MM:dd HH:mm:ssZZZZZ"
        if offset == nil { formatter.timeZone = .current }
        return formatter.date(from: stamp + (offset ?? ""))
    }

    static func metadata(from data: Data) -> [String: String] {
        guard let taken = date(from: data) else { return [:] }
        return [metadataKey: ISO8601DateFormatter().string(from: taken)]
    }

    static func takenAt(_ asset: BookPageMediaAsset) -> Date? {
        asset.metadata[metadataKey].flatMap { ISO8601DateFormatter().date(from: $0) }
    }
}
