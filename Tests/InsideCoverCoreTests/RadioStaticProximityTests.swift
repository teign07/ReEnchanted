import XCTest
@testable import InsideCoverCore

final class RadioStaticProximityTests: XCTestCase {
    private func station(_ id: String, at frequency: Double) -> RadioStation {
        RadioStation(
            id: id,
            title: id,
            frequency: frequency,
            subtitle: "",
            unlockRule: "core",
            moodTags: [],
            signalLine: "",
            tracks: [],
            interludeTitles: [],
            effects: []
        )
    }

    func testStaticRisesTowardAStationAndIsOpenFarAway() {
        let band = [station("fae-fi", at: 94.1), station("thornwave", at: 101.3)]
        let far = RadioStationRegistry.staticProximity(at: 97.7, in: band)
        let near = RadioStationRegistry.staticProximity(at: 94.6, in: band)
        let edge = RadioStationRegistry.staticProximity(at: 94.45, in: band)

        XCTAssertEqual(far, 0)
        XCTAssertGreaterThan(near, 0.5)
        XCTAssertGreaterThan(edge, near)
        XCTAssertLessThanOrEqual(edge, 1)
    }

    func testHiddenStationBleedsThroughOnlyNearby() {
        let band = [station("the-bleed", at: 99.9)]
        XCTAssertEqual(RadioStationRegistry.staticProximity(at: 99.0, in: band), 0)
        XCTAssertGreaterThan(RadioStationRegistry.staticProximity(at: 100.1, in: band), 0.4)
    }
}

final class RadioBandWeatherTests: XCTestCase {
    private func sky(_ condition: SkyCondition, intensity: Double = 0.6, wind: Double = 0.1, isDay: Bool = true) -> PaperSky {
        PaperSky(condition: condition, intensity: intensity, wind: wind, isDay: isDay, observedAt: Date())
    }

    func testNoBelievedSkyIsACalmBandWithNoClaim() {
        XCTAssertEqual(RadioBandWeather.band(for: nil), .calm)
        XCTAssertNil(RadioBandWeather.calm.dialLine)
    }

    func testOnlyStormsCrash() {
        for condition in SkyCondition.allCases where condition != .storm {
            XCTAssertEqual(RadioBandWeather.band(for: sky(condition)).crashes, 0, "\(condition)")
        }
        XCTAssertGreaterThan(RadioBandWeather.band(for: sky(.storm)).crashes, 0.5)
    }

    func testRainFriesHarderTheHarderItFalls() {
        let drizzle = RadioBandWeather.band(for: sky(.rain, intensity: 0.1))
        let downpour = RadioBandWeather.band(for: sky(.rain, intensity: 1))
        XCTAssertGreaterThan(downpour.sizzle, drizzle.sizzle)
        XCTAssertNotNil(drizzle.dialLine)
    }

    func testFarVoicesCarryOnlyOnClearNights() {
        XCTAssertEqual(RadioBandWeather.band(for: sky(.clear, isDay: true)).reach, 0)
        XCTAssertGreaterThan(RadioBandWeather.band(for: sky(.clear, isDay: false)).reach, 0.5)
    }

    func testFogMufflesAndWindFades() {
        XCTAssertGreaterThan(RadioBandWeather.band(for: sky(.fog)).darkness, 0.5)
        XCTAssertGreaterThan(RadioBandWeather.band(for: sky(.cloud, wind: 0.9)).fading, 0.6)
    }

    func testCrashesShareTheLeafsStrikeClock() {
        // The dial must crash on the very instants the leaf is lit.
        XCTAssertEqual(RadioBandWeather.lightningSeed, 0x5707)
    }
}
