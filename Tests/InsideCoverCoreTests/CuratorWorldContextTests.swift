import XCTest
@testable import InsideCoverCore

final class CuratorWorldContextTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(
        year: 2026,
        month: 7,
        day: 22,
        hour: 14
    ))!

    func testSettledContextRefreshesOnNinetyMinuteCadence() {
        let signals = RealWorldContextRefreshSignals()
        XCTAssertFalse(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .curation,
            signals: signals,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-89 * 60),
            lastAttemptAt: now.addingTimeInterval(-89 * 60),
            now: now
        ))
        XCTAssertTrue(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .curation,
            signals: signals,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-90 * 60),
            lastAttemptAt: now.addingTimeInterval(-90 * 60),
            now: now
        ))
    }

    func testMeaningfulForegroundReturnRefreshesSoonerWhenLifeIsChanging() {
        let signals = RealWorldContextRefreshSignals(
            hasUpcomingCalendarTransition: true,
            weatherIsMissingOrChangeable: false,
            movedRecently: false
        )
        XCTAssertFalse(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .foreground(backgroundedFor: 25 * 60),
            signals: signals,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-29 * 60),
            lastAttemptAt: now.addingTimeInterval(-29 * 60),
            now: now
        ))
        XCTAssertTrue(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .foreground(backgroundedFor: 25 * 60),
            signals: signals,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-30 * 60),
            lastAttemptAt: now.addingTimeInterval(-30 * 60),
            now: now
        ))
    }

    func testRapidReopeningDoesNotWakeLocationAgain() {
        let signals = RealWorldContextRefreshSignals(
            weatherIsMissingOrChangeable: true
        )
        XCTAssertFalse(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .foreground(backgroundedFor: 2 * 60),
            signals: signals,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-20 * 60),
            lastAttemptAt: now.addingTimeInterval(-20 * 60),
            now: now
        ))
    }

    func testFailedAttemptBacksOffWithoutMakingContextStaleForHours() {
        let signals = RealWorldContextRefreshSignals()
        XCTAssertFalse(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .launch,
            signals: signals,
            lastSuccessfulRefreshAt: nil,
            lastAttemptAt: now.addingTimeInterval(-14 * 60),
            now: now
        ))
        XCTAssertTrue(RealWorldContextRefreshPolicy.allowsAutomaticRefresh(
            trigger: .launch,
            signals: signals,
            lastSuccessfulRefreshAt: nil,
            lastAttemptAt: now.addingTimeInterval(-15 * 60),
            now: now
        ))
    }

    func testExplicitLocationRequestBypassesAutomaticBatteryWindow() {
        XCTAssertTrue(RealWorldContextRefreshPolicy.allowsRefresh(
            isUserInitiated: true,
            trigger: .curation,
            signals: RealWorldContextRefreshSignals(),
            lastSuccessfulRefreshAt: now,
            lastAttemptAt: now,
            now: now
        ))
        XCTAssertFalse(RealWorldContextRefreshPolicy.allowsRefresh(
            isUserInitiated: false,
            trigger: .curation,
            signals: RealWorldContextRefreshSignals(),
            lastSuccessfulRefreshAt: now,
            lastAttemptAt: now,
            now: now
        ))
    }

    func testWeatherContextFavorsWeatherAndMatchingExactPage() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(phrase: "Current: steady rain, 57F", source: "test")
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let rainy = page(id: "rain", type: .weather, tags: "weather,rain")
        let generic = page(id: "generic", type: .weather, tags: "weather,clear")
        let lore = page(id: "lore", type: .lore, tags: "academy")

        XCTAssertTrue(mood.hasWeatherContext)
        XCTAssertTrue(mood.weatherContextTags.contains("rain"))
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: rainy, mood: mood),
            CuratorWorldContextAffinity.boost(for: generic, mood: mood)
        )
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: generic, mood: mood),
            CuratorWorldContextAffinity.boost(for: lore, mood: mood)
        )
    }

    func testCoarsePlaceAndNearbyPlacesFavorOutwardPages() {
        var inputs = BookSourceInputs.empty
        inputs.currentLocationLabel = "Belfast"
        inputs.nearbyPlaces = [
            LocalPlaceSignal(
                id: "harbor",
                name: "Harbor Walk",
                category: "waterfront",
                distanceLabel: "0.4 km",
                locality: "Belfast"
            )
        ]
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let location = page(id: "location", type: .location, tags: "place,outward")
        let compass = page(id: "compass", type: .wonderCompass, tags: "place,noticing")
        let lore = page(id: "lore", type: .lore, tags: "academy")

        XCTAssertTrue(mood.hasCoarseLocationContext)
        XCTAssertTrue(mood.hasNearbyPlaces)
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: location, mood: mood),
            CuratorWorldContextAffinity.boost(for: lore, mood: mood)
        )
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: compass, mood: mood),
            CuratorWorldContextAffinity.boost(for: lore, mood: mood)
        )
    }

    func testCrowdedCalendarFavorsLightPagesAndEasesHeavyPages() {
        var inputs = BookSourceInputs.empty
        inputs.calendarEvents = (1...3).map { offset in
            CalendarEventSignal(
                id: "event-\(offset)",
                title: "Event \(offset)",
                startsAt: now.addingTimeInterval(Double(offset) * 3600),
                isAllDay: false
            )
        }
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let calendar = page(id: "calendar", type: .calendar, tags: "calendar")
        let rest = page(id: "rest", type: .rest, tags: "rest")
        let heavy = page(id: "story", type: .narrativeOS, tags: "story")

        XCTAssertEqual(mood.upcomingCalendarEventCount, 3)
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: calendar, mood: mood),
            CuratorWorldContextAffinity.boost(for: rest, mood: mood)
        )
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: rest, mood: mood),
            CuratorWorldContextAffinity.boost(for: heavy, mood: mood)
        )
    }

    func testReaderNamedHomeFavorsHomeSizedPagesWithoutBanningAnOutwardDoor() {
        var inputs = BookSourceInputs.empty
        inputs.currentLocationLabel = "Home"
        inputs.currentPlaceContext = .home
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let rest = page(id: "rest", type: .rest, tags: "rest,indoors")
        let outward = page(id: "outward", type: .wonderCompass, tags: "outward,noticing")

        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: rest, mood: mood),
            CuratorWorldContextAffinity.boost(for: outward, mood: mood)
        )
        XCTAssertGreaterThan(
            CuratorWorldContextAffinity.boost(for: outward, mood: mood),
            -10
        )
    }

    func testDeclaredIndoorAndTinyTimeAnswersStronglyFavorAFittingPage() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            fact(questionID: "leaving-home", answer: "Keep wonder indoors"),
            fact(questionID: "time-budget", answer: "Ten minutes")
        ]
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let quickIndoor = page(id: "quick", type: .rest, tags: "indoors,seated")
        let longOuting = page(id: "long", type: .pactErrand, tags: "outward,walking,long-distance")

        XCTAssertEqual(mood.declaredCuration.leavingHome, "keep wonder indoors")
        XCTAssertEqual(mood.declaredCuration.timeBudget, "ten minutes")
        XCTAssertGreaterThan(
            CuratorSelfKnowledgeAffinity.boost(for: quickIndoor, mood: mood),
            CuratorSelfKnowledgeAffinity.boost(for: longOuting, mood: mood) + 20
        )
    }

    func testDeclaredSurpriseAndSensoryDoorsNudgeButDoNotGate() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            fact(questionID: "desired-surprise", answer: "A joke"),
            fact(questionID: "sensory-door", answer: "Sound")
        ]
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let quip = page(id: "quip", type: .quip, tags: "play")
        let radio = page(id: "radio", type: .radio, tags: "sound")
        let diary = page(id: "diary", type: .diary, tags: "reflection")

        XCTAssertGreaterThan(CuratorSelfKnowledgeAffinity.boost(for: quip, mood: mood), 0)
        XCTAssertGreaterThan(CuratorSelfKnowledgeAffinity.boost(for: radio, mood: mood), 0)
        XCTAssertEqual(CuratorSelfKnowledgeAffinity.boost(for: diary, mood: mood), 0)
        XCTAssertTrue(mood.allows(diary))
    }

    private func page(id: String, type: BookPageType, tags: String) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: "context-\(type.rawValue)",
            intent: .reflect,
            renderStyle: .promptCard,
            score: 60,
            prompt: id,
            detail: id,
            payload: BookPagePayload(
                headline: id,
                body: id,
                metadata: ["tags": tags]
            )
        )
    }

    private func fact(questionID: String, answer: String) -> SelfFact {
        SelfFact(
            id: "fact-\(questionID)",
            questionID: questionID,
            question: questionID,
            answer: answer,
            bookTranslation: answer,
            sensitivity: .comfort,
            usePermission: .privateContext,
            tags: ["curation"],
            createdAt: now,
            updatedAt: now
        )
    }
}
