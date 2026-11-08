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

final class OverheadStationTests: XCTestCase {
    private func sky(_ condition: SkyCondition, intensity: Double = 0.6, wind: Double = 0.1, isDay: Bool = true) -> PaperSky {
        PaperSky(condition: condition, intensity: intensity, wind: wind, isDay: isDay, observedAt: Date())
    }

    func testOverheadIsOnTheDialClearOfItsNeighbours() throws {
        let stations = RadioStationRegistry.availableStations(unlockedPackIDs: [])
        let overhead = try XCTUnwrap(stations.first { $0.id == OverheadSky.stationID })
        XCTAssertEqual(RadioStationRegistry.tunedStation(to: overhead.frequency, in: stations)?.id, overhead.id)
        for other in stations where other.id != overhead.id {
            XCTAssertGreaterThan(abs(other.frequency - overhead.frequency), 0.7, other.id)
        }
        XCTAssertTrue(RadioStationRegistry.stations(in: stations).contains { $0.id == overhead.id }, "listed, not hidden")
    }

    func testNoBelievedSkyIsOffTheAir() {
        XCTAssertNil(OverheadSky.from(nil))
        XCTAssertTrue(OverheadSky.playedBy(nil).hasPrefix("Off the air"))
    }

    func testEachSkyGetsItsComposer() {
        XCTAssertEqual(OverheadSky.from(sky(.storm, intensity: 0.9)), .storm(amount: 0.9))
        XCTAssertEqual(OverheadSky.from(sky(.rain, intensity: 0.4)), .rain(amount: 0.4))
        XCTAssertEqual(OverheadSky.from(sky(.fog)), .fog)
        XCTAssertEqual(OverheadSky.from(sky(.clear, isDay: false)), .clear(night: true))
        XCTAssertEqual(OverheadSky.from(sky(.cloud, wind: 0.8)), .windy(amount: 0.8, night: false))
        // Wind never takes over weather that is falling.
        XCTAssertEqual(OverheadSky.from(sky(.snow, wind: 0.9)), .snow(amount: 0.6))
    }

    func testTitleLineNamesWhoIsPlaying() {
        XCTAssertEqual(OverheadSky.playedBy(sky(.rain, intensity: 0.5, wind: 0.4, isDay: false)), "Played tonight by rain, a little wind.")
        XCTAssertEqual(OverheadSky.playedBy(sky(.rain, intensity: 0.9, wind: 0.1)), "Played today by a downpour.")
        XCTAssertEqual(OverheadSky.playedBy(sky(.clear, wind: 0.9)), "Played today by the wind.")
    }
}

final class RadioPastSelfTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ pages: [BookPage]) -> BookDay {
        BookDay(id: "d", date: now, pages: pages)
    }

    private func page(daysAgo: Double, words: String, memo: String? = nil) -> BookPage {
        var page = BookPage(type: .diary, createdAt: now.addingTimeInterval(-daysAgo * 86_400), promptText: "", userInput: words, tags: [])
        if let memo {
            page.mediaAssets = [BookPageMediaAsset(id: "m", kind: .audioFile, reference: memo)]
        }
        return page
    }

    func testOnlyThePastIsCarried() {
        let echoes = RadioPastSelf.echoes(
            days: [day([page(daysAgo: 2, words: "the kettle sang at the wrong moment"),
                        page(daysAgo: 30, words: "the kettle sang at the right moment")])],
            now: now
        )
        XCTAssertEqual(echoes.map(\.quote), ["the kettle sang at the right moment"])
    }

    func testAnniversariesComeFirstAndMissingMemosAreDropped() {
        let echoes = RadioPastSelf.echoes(
            days: [day([page(daysAgo: 50, words: "fifty days of rain on the shed roof"),
                        page(daysAgo: 21, words: "three weeks since the gull stole lunch", memo: "/kept/voice.m4a"),
                        page(daysAgo: 40, words: "a voice that was never saved", memo: "/kept/missing.m4a")])],
            now: now,
            fileExists: { $0 == "/kept/voice.m4a" }
        )
        XCTAssertEqual(echoes.first?.voicePath, "/kept/voice.m4a")
        XCTAssertNil(echoes.first { $0.quote == "a voice that was never saved" }?.voicePath)
    }

    func testQuotesAreTheReadersOwnFirstFourteenWords() {
        XCTAssertNil(RadioPastSelf.quote("ok"))
        let long = (1...20).map { "w\($0)" }.joined(separator: " ")
        XCTAssertEqual(RadioPastSelf.quote(long), (1...14).map { "w\($0)" }.joined(separator: " ") + "\u{2026}")
    }

    func testPickPrefersVoiceOnlyWhenAsked() {
        let echoes = [
            RadioPastSelfEcho(pageID: "a", keptAt: now, quote: "words only here", voicePath: nil),
            RadioPastSelfEcho(pageID: "b", keptAt: now, quote: nil, voicePath: "/v.m4a")
        ]
        XCTAssertEqual(RadioPastSelf.pick(echoes, wantingVoice: true, seed: 3)?.pageID, "b")
        XCTAssertEqual(RadioPastSelf.pick(echoes, wantingVoice: false, seed: 3)?.pageID, "a")
        XCTAssertNil(RadioPastSelf.pick([], wantingVoice: false, seed: 1))
    }
}
