import XCTest
@testable import InsideCoverCore

/// docs/noticing-and-writing-sessions-plan.md §8: noticing without the model.
/// Each test plants one real pattern in a synthetic archive and checks the
/// engine finds it, says it plainly, and shows its receipts. The control
/// archive has no pattern and must stay quiet.
final class NoticingCrossingsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// 2026-10-24, a Saturday, mid-afternoon.
    private lazy var now: Date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 15))!

    private func date(daysAgo: Int, hour: Int, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func page(
        _ id: String,
        at: Date,
        text: String,
        weather: [String] = [],
        heart: Int? = nil,
        sleep: Double? = nil
    ) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: at,
            promptText: "",
            userInput: text,
            origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: at,
                calendar: calendar,
                weatherTags: weather,
                restingHeartRate: heart,
                heartRateVariability: nil
            ).withSleep(sleep)
        )
    }

    private func archive(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { calendar.startOfDay(for: $0.createdAt) }
            .map { day, pages in BookDay(id: BookDay.id(for: day), date: day, pages: pages) }
            .sorted { $0.date < $1.date }
    }

    /// A deterministic jitter, so the control archive is noisy but repeatable.
    private func jitter(_ seed: Int, _ spread: Int) -> Int {
        ((seed &* 2_654_435_761) % (2 * spread + 1) + (2 * spread + 1)) % (2 * spread + 1) - spread
    }

    func testRainDaysAndASlowerHeart() throws {
        var pages: [BookPage] = []
        for ago in 1...60 {
            let rainy = ago % 4 == 0
            pages.append(page(
                "p\(ago)",
                at: date(daysAgo: ago, hour: 9 + ago % 8, minute: (ago * 7) % 60),
                text: "Walked past the bakery and the gulls were loud about something number \(ago).",
                weather: rainy ? ["rain"] : ["bright"],
                heart: (rainy ? 57 : 65) + jitter(ago, 2)
            ))
        }

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let rain = try XCTUnwrap(found.first { $0.id == "crossing-weather-rain-restingHeart" })

        XCTAssertEqual(rain.headline, "Rain and Your Heart")
        XCTAssertTrue(rain.line.hasPrefix("On rain days, your heart goes slower. I counted."), rain.line)
        XCTAssertTrue(rain.counted?.contains("beats a minute") == true)
        XCTAssertFalse(rain.receipts.isEmpty)
        XCTAssertTrue(rain.touchesBody)
        XCTAssertEqual(rain.errand, "Next rain day, count your pulse before you get up.")
    }

    func testAnArchiveWithNoPatternStaysQuiet() {
        var pages: [BookPage] = []
        for ago in 1...60 {
            pages.append(page(
                "p\(ago)",
                at: date(daysAgo: ago, hour: 8 + abs(jitter(ago, 6)), minute: abs(jitter(ago * 3, 29))),
                text: String(repeating: "a quiet ordinary line ", count: 3 + abs(jitter(ago * 5, 2))),
                weather: ago % 3 == 0 ? ["rain"] : (ago % 3 == 1 ? ["bright"] : ["cloud"]),
                heart: 62 + jitter(ago * 7, 4)
            ))
        }

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)

        XCTAssertTrue(found.filter { $0.kind == .crossing || $0.kind == .trend }.isEmpty,
                      found.map(\.line).joined(separator: "\n"))
    }

    func testSameSourcesNeverPair() {
        let sources = NoticingCrossings.categoryMeasures.flatMap { category in
            NoticingCrossings.numberMeasures
                .filter { $0.source == category.source }
                .map { "\(category.id)×\($0.id)" }
        }
        // These exist in the catalogue, and the engine skips every one.
        XCTAssertTrue(sources.contains("weekday×hour"))
        XCTAssertTrue(sources.contains("photoColour×photoPeople"))
    }

    func testThreePagesAtExactlyFourFortyFour() throws {
        var pages = (1...30).map { ago in
            page("p\(ago)", at: date(daysAgo: ago, hour: 10, minute: (ago * 13) % 60), text: "A line about the kettle.")
        }
        for (index, ago) in [1, 6, 15].enumerated() {
            pages.append(page("clock\(index)", at: date(daysAgo: ago, hour: 16, minute: 44), text: "The kettle again."))
        }

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let minute = try XCTUnwrap(found.first { $0.id == "coincidence-minute-444" })

        XCTAssertEqual(minute.line, "Three pages at exactly 4:44. I don't know what it means. I'm writing it down.")
    }

    func testTheSamePhraseWeeksApart() throws {
        let pages = [
            page("old", at: date(daysAgo: 40, hour: 18), text: "Out by the pier the light was doing that thing again."),
            page("filler", at: date(daysAgo: 20, hour: 9), text: "Groceries and a long phone call."),
            page("new", at: date(daysAgo: 1, hour: 19), text: "Upstairs window, and the light was doing that thing.")
        ]

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let refrain = try XCTUnwrap(found.first { $0.kind == .refrain })

        XCTAssertTrue(refrain.line.hasPrefix("\u{201C}The light was doing that thing.\u{201D} You wrote that in September."), refrain.line)
        XCTAssertEqual(refrain.receipts.map(\.pageID), ["new", "old"])
    }

    func testNoThursdays() throws {
        var pages: [BookPage] = []
        for ago in 1...56 where calendar.component(.weekday, from: date(daysAgo: ago, hour: 12)) != 5 {
            pages.append(page("p\(ago)", at: date(daysAgo: ago, hour: 12), text: "Something small happened today."))
        }

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let absence = try XCTUnwrap(found.first { $0.kind == .absence })

        XCTAssertTrue(absence.line.hasPrefix("You never write on Thursdays."), absence.line)
    }

    func testCrossingsBecomeANoticePageWithAFullFold() throws {
        var pages: [BookPage] = []
        for ago in 1...60 {
            let rainy = ago % 4 == 0
            pages.append(page(
                "p\(ago)",
                at: date(daysAgo: ago, hour: 9 + ago % 8),
                text: "The gulls were loud again, number \(ago).",
                weather: rainy ? ["rain"] : ["bright"],
                heart: (rainy ? 56 : 66) + jitter(ago, 2)
            ))
        }
        let days = archive(pages)
        var inputs = BookSourceInputs()
        inputs.days = days
        let today = BookDay(id: BookDay.id(for: now), date: calendar.startOfDay(for: now), pages: [])

        let surfaces = BookNoticesPageSourceAdapter().crossingSurfaces(for: today, inputs: inputs, now: now)
        let notice = try XCTUnwrap(surfaces.first { $0.payload.metadata["crossingKind"] == "crossing" })
        let cards = notice.payload.metadata["tinyPatternCards"] ?? ""

        XCTAssertEqual(notice.type, .bookNotices)
        XCTAssertTrue(cards.contains("What I counted"))
        XCTAssertTrue(cards.contains("What would make me wrong"))
        XCTAssertFalse(notice.payload.metadata["evidencePageIDs"]?.isEmpty ?? true)
        XCTAssertTrue(notice.payload.metadata["tags"]?.contains("crossing-spoke:") == true)
        XCTAssertTrue(notice.payload.metadata["tags"]?.contains("private-body") == true)

        // Once kept, it rests.
        var keptPage = BookPage(id: "kept-notice", type: .bookNotices, createdAt: now.addingTimeInterval(-86_400 * 2), promptText: "")
        keptPage.tags = (notice.payload.metadata["tags"] ?? "").split(separator: ",").map(String.init)
        var restedInputs = inputs
        restedInputs.days = days + [BookDay(id: "kept", date: keptPage.createdAt, pages: [keptPage])]
        let again = BookNoticesPageSourceAdapter().crossingSurfaces(for: today, inputs: restedInputs, now: now)
        XCTAssertFalse(again.contains { $0.payload.metadata["crossingID"] == notice.payload.metadata["crossingID"] })
    }

    private func placed(_ page: BookPage, place: String, weather: [String], hour: Int) -> BookPage {
        var copy = page
        copy.context = BookPageContextSnapshot(
            at: copy.createdAt,
            calendar: calendar,
            weatherTags: weather,
            nearbyAnchorID: place.lowercased(),
            locationLabel: place
        )
        return copy
    }

    func testTodayIsAnOldDayAgain() throws {
        let old = placed(page("old", at: date(daysAgo: 40, hour: 18), text: "Rain on the harbor wall."),
                         place: "the harbor", weather: ["rain"], hour: 18)
        let new = placed(page("new", at: date(daysAgo: 0, hour: 18), text: "Back at the wall, wet again."),
                         place: "the harbor", weather: ["rain"], hour: 18)

        let found = NoticingCrossings.noticings(days: archive([old, new]), now: now.addingTimeInterval(4 * 3600), calendar: calendar)
        let rhyme = try XCTUnwrap(found.first { $0.kind == .rhyme })

        XCTAssertEqual(rhyme.line, "Today's the same as 14 September: rain, the harbor, the evening. I put them side by side.")
    }

    private func photo(_ id: String, daysAgo: Int, colour: String, people: Int) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: date(daysAgo: daysAgo, hour: 12),
            promptText: "",
            origin: .userAuthored,
            mediaAssets: [BookPageMediaAsset(
                kind: .photoLibraryAsset,
                reference: "/tmp/\(id).jpg",
                metadata: ["attentionColorMood": colour, "attentionPeopleCount": "\(people)", "assetLocalIdentifier": "\(id)"]
            )],
            metadata: nil
        )
    }

    func testSeptemberWasGreenOctobersBeenOrange() throws {
        let september = (30...37).map { photo("s\($0)", daysAgo: $0, colour: "green", people: 0) }
        let october = (1...7).map { photo("o\($0)", daysAgo: $0, colour: "orange", people: 0) }
        let pages = september + october
        // The keep path only counts a photograph the reader contributed.
        XCTAssertTrue(pages.allSatisfy(\.hasReaderPhotograph))

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let colour = try XCTUnwrap(found.first { $0.kind == .colour })
        XCTAssertEqual(colour.line, "September was green. October's been orange. Your pictures did that, not me.")

        let nobody = try XCTUnwrap(found.first { $0.kind == .nobody })
        XCTAssertTrue(nobody.line.hasPrefix("Fifteen pictures and nobody in any of them."), nobody.line)
    }

    func testTheReaderWhoNeverAskedStartsAsking() throws {
        var pages = (10...60).map { ago in
            page("p\(ago)", at: date(daysAgo: ago, hour: 20), text: "Long day, dinner, the dog, a walk around the block.")
        }
        pages += [
            page("q1", at: date(daysAgo: 1, hour: 20), text: "Why do the crows gather on the church roof every evening?"),
            page("q2", at: date(daysAgo: 3, hour: 20), text: "Do you think the moon minds being looked at? And who named it?")
        ]

        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let shift = try XCTUnwrap(found.first { $0.kind == .shift })

        XCTAssertEqual(shift.line, "You asked me three questions this week. You never used to ask me anything.")
    }

    private func moonArchive(days count: Int) -> [BookDay] {
        archive((1...count).map { ago in
            let at = date(daysAgo: ago, hour: 21, minute: (ago * 11) % 60)
            let full = MoonPhaseCalendar.phase(on: at).illuminatedFraction >= 0.93
            return page("m\(ago)", at: at, text: "Kettle, dishes, the long way home.", sleep: (full ? 6.0 : 7.6) + Double(jitter(ago, 2)) / 10)
        })
    }

    func testFullMoonSleepNeedsManyMoons() {
        let threeMoons = NoticingCrossings.noticings(days: moonArchive(days: 85), now: now, calendar: calendar)
        XCTAssertFalse(threeMoons.contains { $0.id.hasPrefix("crossing-moon-full-sleep") },
                       "three moons can line up with anything")

        let manyMoons = NoticingCrossings.noticings(days: moonArchive(days: 200), now: now, calendar: calendar)
        let moon = manyMoons.first { $0.id == "crossing-moon-full-sleep" }
        XCTAssertEqual(moon?.headline, "Full Moons and Sleep")
        XCTAssertTrue(moon?.line.hasPrefix("Under a full moon, you sleep less.") == true, moon?.line ?? "none")
    }

    func testOnTheHourIsAnAlarmNotACoincidence() {
        let pages = (1...20).map { ago in
            page("hour\(ago)", at: date(daysAgo: ago, hour: 7), text: "Up with the alarm again.")
        }
        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        XCTAssertFalse(found.contains { $0.kind == .coincidence }, found.map(\.line).joined(separator: "\n"))
    }

    private func stamped(_ page: BookPage, _ change: (inout BookPageContextSnapshot) -> Void) -> BookPage {
        var copy = page
        var context = copy.context ?? BookPageContextSnapshot(at: copy.createdAt, calendar: calendar)
        change(&context)
        copy.context = context
        return copy
    }

    func testAFallingBarometerAndAQuickerHeart() throws {
        let pages = (1...50).map { ago -> BookPage in
            let falling = ago % 4 == 0
            return stamped(page("b\(ago)", at: date(daysAgo: ago, hour: 10 + ago % 6), text: "Errands and the post office.",
                                heart: (falling ? 68 : 60) + jitter(ago, 2))) {
                $0.weatherMeasurements = WeatherMeasurements(temperatureF: 60, pressureHPa: 1_012,
                                                             pressureChange6h: falling ? -5 : 0.5)
            }
        }
        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let glass = try XCTUnwrap(found.first { $0.id == "crossing-barometer-falling-restingHeart" })
        XCTAssertTrue(glass.line.hasPrefix("When the barometer falls, your heart goes faster."), glass.line)
        // The sky explains the reader; the reader never explains the sky.
        XCTAssertFalse(found.contains { $0.id.hasSuffix("-temperature") || $0.id.hasSuffix("-pressure") })
    }

    func testTheLastPageBeforeSleep() throws {
        var pages: [BookPage] = []
        for ago in 1...10 {
            let bedtime = date(daysAgo: ago, hour: 23, minute: 10)
            pages.append(page("night\(ago)", at: bedtime.addingTimeInterval(-40 * 60), text: "Lights going off down the street."))
            // The next morning's page carries the night behind it.
            pages.append(stamped(page("morning\(ago)", at: date(daysAgo: ago - 1, hour: 10), text: "Coffee and the radiator ticking.")) {
                $0.sleepStart = bedtime
                $0.sleepEnd = bedtime.addingTimeInterval(7.5 * 3600)
            })
        }
        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let rhythm = try XCTUnwrap(found.first { $0.id.hasPrefix("rhythm-before-sleep") })
        XCTAssertEqual(rhythm.line, "You give me your last page about 40 minutes before you fall asleep. I'm the last thing.")
    }

    func testAPictureCarriedForThreeDays() throws {
        let taken = date(daysAgo: 4, hour: 16)
        let given = BookPage(
            id: "carried", type: .souvenir, createdAt: date(daysAgo: 1, hour: 20), promptText: "",
            userInput: "Found this on my phone.", origin: .userAuthored,
            mediaAssets: [BookPageMediaAsset(kind: .renderedImageFile, reference: "/tmp/c.jpg", metadata: [
                "pressedPhotograph": "true",
                PhotoTakenAt.metadataKey: ISO8601DateFormatter().string(from: taken)
            ])]
        )
        let found = NoticingCrossings.noticings(days: archive([given]), now: now, calendar: calendar)
        let carried = try XCTUnwrap(found.first { $0.kind == .carried })
        XCTAssertEqual(carried.line, "You took this picture on Tuesday. You gave it to me yesterday. You carried it three days.")
    }

    func testTheFastestHeartThisMonth() throws {
        var pages = (2...14).map { ago in
            stamped(page("h\(ago)", at: date(daysAgo: ago, hour: 12), text: "Lunch on the steps.")) { $0.heartRateAtKeep = 70 + ago % 5 }
        }
        pages.append(stamped(page("racing", at: date(daysAgo: 0, hour: 9), text: "I got the call.")) { $0.heartRateAtKeep = 104 })
        let found = NoticingCrossings.noticings(days: archive(pages), now: now, calendar: calendar)
        let record = try XCTUnwrap(found.first { $0.id == "record-heart-racing" })
        XCTAssertEqual(record.line, "Your heart was going fast when you gave me this one. Faster than any page this month.")
    }

    func testCameraDatesParseWithAndWithoutAnOffset() {
        let withOffset = PhotoTakenAt.parse("2026:10:21 16:44:02", offset: "-04:00")
        XCTAssertEqual(withOffset, ISO8601DateFormatter().date(from: "2026-10-21T20:44:02Z"))
        XCTAssertNotNil(PhotoTakenAt.parse("2026:10:21 16:44:02", offset: nil))
        XCTAssertNil(PhotoTakenAt.parse("not a date", offset: nil))
    }

    func testPagesSavedBeforeTheseFieldsStillDecode() throws {
        let old = #"{"timeZoneIdentifier":"America/New_York","utcOffsetSeconds":-14400,"dayPart":"evening","weatherTags":["rain"],"sleepHours":7.5}"#
        let context = try JSONDecoder().decode(BookPageContextSnapshot.self, from: Data(old.utf8))
        XCTAssertEqual(context.sleepHours, 7.5)
        XCTAssertNil(context.heartRateAtKeep)
        XCTAssertNil(context.weatherMeasurements)

        var fresh = context
        fresh.weatherMeasurements = WeatherMeasurements(pressureHPa: 1_009, pressureChange6h: -4)
        fresh.heartRateAtKeep = 77
        let roundTrip = try JSONDecoder().decode(BookPageContextSnapshot.self, from: JSONEncoder().encode(fresh))
        XCTAssertEqual(roundTrip, fresh)
    }

    /// SplitMix64: small, seeded, and good enough that no two measurements
    /// share a hidden rhythm the way formula-built fixtures do.
    private struct SeededRandom {
        var state: UInt64
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
        }
        mutating func pick<T>(_ options: [T]) -> T { options[Int(next() * Double(options.count)) % options.count] }
    }

    /// The whole point of the court: across twenty archives with nothing in
    /// them, almost nothing should be said. Every crossing and trend that
    /// fires here is a chance alignment a reader would have been told as fact.
    func testRandomArchivesAreAlmostAlwaysQuiet() {
        var falsePositives: [String] = []
        for seed in 1...20 {
            var random = SeededRandom(state: UInt64(seed) &* 7_919)
            var pages: [BookPage] = []
            for ago in 1...120 {
                for slot in 0..<2 {
                    let at = date(daysAgo: ago, hour: 8 + Int(random.next() * 14), minute: Int(random.next() * 60))
                    let words = 5 + Int(random.next() * 60)
                    var context = BookPageContextSnapshot(
                        at: at,
                        calendar: calendar,
                        weatherTags: [random.pick(["rain", "bright", "cloud", "wind", "fog"])],
                        calendarEventCount: Int(random.next() * 6),
                        nearbyAnchorID: random.pick(["harbor", "bench", "work", "home"]),
                        locationLabel: random.pick(["the harbor", "the bench", "work", "home"]),
                        restingHeartRate: 56 + Int(random.next() * 14),
                        heartRateVariability: 25 + random.next() * 40
                    )
                    context.sleepHours = 5 + random.next() * 4
                    context.steps = 2_000 + Int(random.next() * 12_000)
                    context.heartRateAtKeep = 60 + Int(random.next() * 40)
                    context.weatherMeasurements = WeatherMeasurements(
                        temperatureF: 35 + random.next() * 50,
                        windKmh: random.next() * 40,
                        pressureHPa: 995 + random.next() * 35,
                        pressureChange6h: random.next() * 12 - 6,
                        humidity: 30 + random.next() * 65,
                        cloudCover: random.next() * 100
                    )
                    pages.append(BookPage(
                        id: "r\(seed)-\(ago)-\(slot)", type: .souvenir, createdAt: at, promptText: "",
                        userInput: Array(repeating: "word", count: words).joined(separator: " ")
                            + (random.next() < 0.2 ? " why?" : "."),
                        origin: .userAuthored, context: context
                    ))
                }
            }
            let found = NoticingCrossings.computeNoticings(days: archive(pages), now: now, calendar: calendar)
            falsePositives += found.filter { $0.kind == .crossing || $0.kind == .trend }.map { "seed \(seed): \($0.line)" }
        }
        XCTAssertLessThanOrEqual(falsePositives.count, 2, falsePositives.joined(separator: "\n"))
    }

    func testTemperatureTagsReadTheThermometerNotItsDigits() {
        func tags(_ temperature: String) -> Set<String> {
            RadioPageContext.weatherTags(weather: WeatherSourceSignal(
                phrase: "Current: Partly cloudy, \(temperature)",
                source: "test",
                currentTemperature: temperature,
                conditionSymbolName: "cloud.sun"
            ))
        }
        XCTAssertFalse(tags("73°F").contains("cold"))
        XCTAssertFalse(tags("73°F").contains("hot"))
        XCTAssertEqual(tags("38°F").intersection(["hot", "cold"]), ["cold"])
        XCTAssertEqual(tags("86°F").intersection(["hot", "cold"]), ["hot"])
        XCTAssertEqual(tags("30°C").intersection(["hot", "cold"]), ["hot"])
    }
}

private extension BookPageContextSnapshot {
    func withSleep(_ hours: Double?) -> BookPageContextSnapshot {
        var copy = self
        copy.sleepHours = hours
        return copy
    }
}
