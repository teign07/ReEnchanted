import XCTest
@testable import InsideCoverCore

final class OpenWindowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!
        return value
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 1 + day, hour: 12))!
    }

    private func archive(count: Int = 40, span: Int = 70, improving: Bool = true) -> [BookDay] {
        (0..<count).map { index in
            let offset = index * span / max(count - 1, 1)
            let input = improving && index >= count / 2
                ? "The cold kettle hissed while silver rain moved across the kitchen window."
                : "I walked around the block today."
            let when = date(offset)
            return BookDay(
                id: BookDay.id(for: when, calendar: calendar),
                date: calendar.startOfDay(for: when),
                pages: [BookPage(id: "seeing-\(index)", type: .souvenir, createdAt: when, promptText: "Notice.", userInput: input)]
            )
        }
    }

    func testHowYouSeeStaysSilentForYoungOrShortArchive() {
        XCTAssertNil(HowYouSee.receipt(days: archive(count: 39), now: date(70)))
        XCTAssertNil(HowYouSee.receipt(days: archive(span: 30), now: date(30)))
    }

    func testHowYouSeeRequiresRealImprovementAndIsDeterministic() {
        XCTAssertNil(HowYouSee.receipt(days: archive(improving: false), now: date(70)))
        let days = archive()
        let first = HowYouSee.receipt(days: days, now: date(70))
        XCTAssertNotNil(first)
        XCTAssertEqual(first, HowYouSee.receipt(days: days, now: date(70)))
        XCTAssertNotEqual(first?.earlierQuote, first?.recentQuote)
        XCTAssertGreaterThanOrEqual(first?.recentStrength ?? 0, 3)
    }

    private func anchor(_ id: String, name: String, visits: Int, belief: Int, radius: Double = 50) -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: 44, longitude: -69, radiusMeters: radius,
            kind: .notice, belief: belief, created: "2026-01-01", weather: "clear",
            moon: "Full Moon", season: "Deep Winter", playerWords: "",
            academyEcho: "", outerStacksRoom: "", fae: "", miniStory: "",
            localRule: "", visitCount: visits, lastVisited: "none"
        )
    }

    func testAnchorDoorbellsRankCapCoolDownAndMatchWater() {
        let now = date(70)
        let anchors = [
            anchor("harbor", name: "Harbor Walk", visits: 9, belief: 20),
            anchor("high", name: "High Street", visits: 8, belief: 80),
            anchor("a", name: "A", visits: 7, belief: 10),
            anchor("b", name: "B", visits: 6, belief: 10),
            anchor("c", name: "C", visits: 5, belief: 10)
        ]
        let bells = AnchorDoorbells.plan(anchors: anchors, lastArmed: ["high": now.addingTimeInterval(-86_400)], now: now)
        XCTAssertEqual(bells.count, 4)
        XCTAssertEqual(bells.first?.anchorID, "harbor")
        XCTAssertEqual(bells.first?.radiusMeters, 150)
        XCTAssertTrue(bells.first?.body.hasPrefix("You're near a page I keep open.") == true)
        XCTAssertTrue(bells.first?.tags.contains("anchor:harbor") == true)
        XCTAssertFalse(bells.contains { $0.anchorID == "high" })
    }

    func testWeatherBellPriorityAndSilence() {
        XCTAssertEqual(PlayfulMissionRegistry.weatherBellMission(weatherText: "storm and rain")?.id, "storm-wind-shift")
        XCTAssertEqual(PlayfulMissionRegistry.weatherBellMission(weatherText: "light drizzle")?.id, "sky-rain-stage")
        XCTAssertEqual(PlayfulMissionRegistry.weatherBellMission(weatherText: "morning fog")?.id, "weather-scent")
        XCTAssertNil(PlayfulMissionRegistry.weatherBellMission(weatherText: "sunny and bright"))
    }

    func testOutwardWakeUsesRecentOutwardKeepsOnly() {
        let now = date(70)
        let old = BookPage(type: .souvenir, createdAt: date(60), promptText: "Old", userInput: "old detail")
        let recent = BookPage(type: .todaysSky, createdAt: date(69), promptText: "Sky")
        XCTAssertFalse(StoryFormRegistry.hasRecentOutwardKeep(days: [BookDay(id: "old", date: date(60), pages: [old])], now: now))
        XCTAssertTrue(StoryFormRegistry.hasRecentOutwardKeep(days: [BookDay(id: "new", date: date(69), pages: [recent])], now: now))
    }
}
