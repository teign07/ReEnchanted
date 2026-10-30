import XCTest
@testable import InsideCoverCore

/// How much the crossing engine costs a desk build on a heavy archive: two
/// years, four Pages a day, every measurement filled in. Off by default;
/// run with `NOTICING_BENCH=1 swift test --filter NoticingCrossingsBench`.
final class NoticingCrossingsBench: XCTestCase {
    func testTwoYearsOfPages() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NOTICING_BENCH"] == "1")
        let calendar = Calendar.current
        let now = Date()
        let places = ["the harbor", "the bench", "the bakery", "work", "home", "the library"]
        let weathers = [["rain"], ["bright"], ["cloud"], ["fog", "cold"], ["wind"], ["bright", "hot"]]
        let colours = ["blue", "orange", "green", "grey", "red", "gold"]
        let line = "Walked down past the harbor wall where the gulls were arguing about a chip "
            + "and the light was doing that thing it does in the late afternoon when everything goes gold "

        var days: [BookDay] = []
        for ago in (0..<730).reversed() {
            let dayStart = calendar.date(byAdding: .day, value: -ago, to: calendar.startOfDay(for: now))!
            var pages: [BookPage] = []
            for slot in 0..<4 {
                let at = dayStart.addingTimeInterval(TimeInterval(8 * 3600 + slot * 4 * 3600 + (ago * 37 % 50) * 60))
                var context = BookPageContextSnapshot(
                    at: at,
                    calendar: calendar,
                    weatherTags: weathers[(ago + slot) % weathers.count],
                    calendarEventCount: ago % 5,
                    nearbyAnchorID: places[(ago * 3 + slot) % places.count],
                    locationLabel: places[(ago * 3 + slot) % places.count],
                    latitude: 42.66,
                    longitude: -70.62,
                    restingHeartRate: 58 + ago % 9,
                    heartRateVariability: Double(30 + ago % 25)
                )
                context.sleepHours = 5.5 + Double(ago % 7) / 2
                context.steps = 3_000 + (ago * 911) % 12_000
                context.heartRateAtKeep = 64 + (ago * 7 + slot * 3) % 30
                context.respiratoryRate = 13 + Double(ago % 4)
                context.sleepStart = dayStart.addingTimeInterval(-3600 * 1.5)
                context.sleepEnd = dayStart.addingTimeInterval(3600 * 6.5)
                context.weatherMeasurements = WeatherMeasurements(
                    temperatureF: 40 + Double((ago * 3) % 45),
                    precipitationMM: ago % 4 == 0 ? 1.2 : 0,
                    windKmh: Double((ago * 5) % 35),
                    pressureHPa: 1_000 + Double((ago * 7) % 30),
                    pressureChange6h: Double((ago * 11) % 13) - 6,
                    humidity: Double(40 + (ago * 9) % 55),
                    cloudCover: Double((ago * 13) % 100),
                    uvIndex: Double(ago % 8)
                )
                pages.append(BookPage(
                    id: "bench-\(ago)-\(slot)",
                    type: .souvenir,
                    createdAt: at,
                    promptText: "",
                    userInput: String(line.prefix(60 + (ago * 13 + slot * 7) % 120)) + (slot == 2 ? " Why?" : ""),
                    origin: .userAuthored,
                    mediaAssets: slot == 1 ? [BookPageMediaAsset(
                        kind: .photoLibraryAsset,
                        reference: "/tmp/\(ago).jpg",
                        metadata: [
                            "assetLocalIdentifier": "bench-\(ago)",
                            "attentionColorMood": colours[ago % colours.count],
                            "attentionPeopleCount": "\(ago % 3)"
                        ]
                    )] : [],
                    context: context
                ))
            }
            days.append(BookDay(id: BookDay.id(for: dayStart), date: dayStart, pages: pages))
        }

        let cold = Date()
        let found = NoticingCrossings.computeNoticings(days: days, now: now, calendar: calendar)
        let coldMs = Date().timeIntervalSince(cold) * 1000

        _ = NoticingCrossings.noticings(days: days, now: now, calendar: calendar)
        let warm = Date()
        for _ in 0..<20 { _ = NoticingCrossings.noticings(days: days, now: now, calendar: calendar) }
        let warmMs = Date().timeIntervalSince(warm) * 1000 / 20

        func time(_ label: String, _ work: () -> Void) {
            let start = Date()
            work()
            print("NOTICING_BENCH stage \(label): \(Int(Date().timeIntervalSince(start) * 1000))ms")
        }
        var keeps: [NoticingCrossings.Sample] = []
        var recentDays: [NoticingCrossings.Sample] = []
        var recentKeeps: [NoticingCrossings.Sample] = []
        time("keepUnits") { keeps = NoticingCrossings.keepUnits(days: days, calendar: calendar) }
        time("dayUnits") {
            recentKeeps = keeps.filter { $0.date >= now.addingTimeInterval(-84 * 86_400) }
            recentDays = NoticingCrossings.dayUnits(from: recentKeeps, calendar: calendar)
        }
        time("crossings") { _ = NoticingCrossings.crossings(keeps: recentKeeps, days: recentDays) }
        time("longCrossings") { _ = NoticingCrossings.longCrossings(keeps: keeps, now: now, calendar: calendar) }
        time("trends") { _ = NoticingCrossings.trends(days: recentDays) }
        time("sameMinute") { _ = NoticingCrossings.sameMinute(keeps: keeps, now: now, calendar: calendar) }
        time("refrains") { _ = NoticingCrossings.refrains(keeps: keeps, now: now, calendar: calendar) }
        time("sunKeeper") { _ = NoticingCrossings.sunKeeper(keeps: recentKeeps, calendar: calendar) }
        time("sameDay") { _ = NoticingCrossings.sameDay(keeps: keeps, now: now, calendar: calendar) }
        time("records+firsts") {
            let allDays = NoticingCrossings.dayUnits(from: keeps, calendar: calendar)
            _ = NoticingCrossings.records(days: allDays, now: now, calendar: calendar)
            _ = NoticingCrossings.firsts(days: allDays, now: now, calendar: calendar)
        }
        print("NOTICING_BENCH pages=\(days.count * 4) found=\(found.count) cold=\(Int(coldMs))ms memoised=\(String(format: "%.2f", warmMs))ms")
        for noticing in found.prefix(8) { print("NOTICING_BENCH  \(noticing.rank) \(noticing.line)") }
    }
}
