import XCTest
@testable import InsideCoverCore

/// The sky reaching the paper has one hard requirement above every visual one:
/// it must never assert weather the Book does not actually know about. Most of
/// what follows is about that rather than about how it looks.
final class SkyOnTheLeafTests: XCTestCase {

    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: - The honesty gate

    func testAFreshReadingReachesThePaperAtFullStrength() {
        let reading = PaperSky(
            condition: .rain,
            intensity: 0.8,
            wind: 0.3,
            isDay: true,
            observedAt: noon
        )
        XCTAssertEqual(reading.presence(at: noon), 1, accuracy: 0.0001)
        XCTAssertEqual(
            reading.presence(at: noon.addingTimeInterval(PaperSky.freshFor - 1)),
            1,
            accuracy: 0.0001
        )
    }

    func testAStaleReadingDrawsNothing() {
        let reading = PaperSky(
            condition: .rain,
            intensity: 1,
            wind: 1,
            isDay: true,
            observedAt: noon
        )
        let later = noon.addingTimeInterval(PaperSky.staleAt + 60)
        XCTAssertEqual(reading.presence(at: later), 0)
        XCTAssertNil(
            reading.settled(at: later),
            "A three-hour-old claim about rain must not still be wetting the leaf."
        )
    }

    func testPresenceFadesMonotonicallyBetweenFreshAndStale() {
        let reading = PaperSky(
            condition: .snow,
            intensity: 1,
            wind: 0,
            isDay: false,
            observedAt: noon
        )
        var previous = 1.0
        for minute in stride(from: 45, through: 180, by: 5) {
            let presence = reading.presence(at: noon.addingTimeInterval(Double(minute) * 60))
            XCTAssertLessThanOrEqual(presence, previous + 0.0001, "presence rose at \(minute)m")
            XCTAssertGreaterThanOrEqual(presence, 0)
            previous = presence
        }
        XCTAssertEqual(previous, 0, accuracy: 0.02)
    }

    func testAClockThatWentBackwardsIsNotReadAsAnInfinitelyFreshSky() {
        let reading = PaperSky(
            condition: .storm,
            intensity: 1,
            wind: 1,
            isDay: true,
            observedAt: noon
        )
        let before = noon.addingTimeInterval(-3_600)
        XCTAssertEqual(reading.presence(at: before), 0)
        XCTAssertNil(reading.settled(at: before))
    }

    func testAFadingReadingThinsRatherThanSwitchingOff() throws {
        let reading = PaperSky(
            condition: .rain,
            intensity: 1,
            wind: 0.6,
            isDay: true,
            observedAt: noon
        )
        // Half way through the fade window.
        let halfway = noon.addingTimeInterval(
            PaperSky.freshFor + (PaperSky.staleAt - PaperSky.freshFor) / 2
        )
        let settled = try XCTUnwrap(reading.settled(at: halfway))
        XCTAssertEqual(settled.intensity, 0.5, accuracy: 0.02)
        XCTAssertEqual(settled.wind, 0.3, accuracy: 0.02)
    }

    // MARK: - How often the Book looks up

    func testTheSkyIsReadHourly() {
        XCTAssertEqual(SkyRefresh.interval, 3_600)
    }

    func testAReadingStaysAtFullStrengthUntilItsReplacementIsDue() {
        // The invariant that makes a fading sky *mean* something: while reads
        // are landing on time, the fade never shows. If these two ever drift
        // apart, a thinning page stops being a signal that the Book cannot see
        // out and becomes something that happens every hour for no reason.
        XCTAssertEqual(PaperSky.freshFor, SkyRefresh.interval)

        let reading = PaperSky(
            condition: .rain,
            intensity: 0.7,
            wind: 0.3,
            isDay: true,
            observedAt: noon
        )
        // One minute before the next read is due, still undimmed.
        XCTAssertEqual(
            reading.presence(at: noon.addingTimeInterval(SkyRefresh.interval - 60)),
            1,
            accuracy: 0.0001
        )
    }

    func testASkyWithNoReadingYetIsDueImmediately() {
        XCTAssertTrue(SkyRefresh.isDue(lastReadAt: nil, lastAttemptAt: nil, now: noon))
    }

    func testAFreshSkyIsNotDue() {
        XCTAssertFalse(SkyRefresh.isDue(
            lastReadAt: noon.addingTimeInterval(-600),
            lastAttemptAt: nil,
            now: noon
        ))
    }

    func testAnHourOldSkyIsDue() {
        XCTAssertTrue(SkyRefresh.isDue(
            lastReadAt: noon.addingTimeInterval(-SkyRefresh.interval),
            lastAttemptAt: nil,
            now: noon
        ))
    }

    func testAFailedReadBacksOffInsteadOfRetryingOnEveryWake() {
        // An hour-old sky is due, but the attempt a minute ago failed.
        XCTAssertFalse(SkyRefresh.isDue(
            lastReadAt: noon.addingTimeInterval(-SkyRefresh.interval),
            lastAttemptAt: noon.addingTimeInterval(-60),
            now: noon
        ))
        // ...and is tried again once the backoff has passed.
        XCTAssertTrue(SkyRefresh.isDue(
            lastReadAt: noon.addingTimeInterval(-SkyRefresh.interval),
            lastAttemptAt: noon.addingTimeInterval(-SkyRefresh.failedAttemptBackoff - 1),
            now: noon
        ))
    }

    func testAReadingStampedInTheFutureIsReadAgain() {
        // A clock that moved, not a sky the Book knows about.
        XCTAssertTrue(SkyRefresh.isDue(
            lastReadAt: noon.addingTimeInterval(9_999),
            lastAttemptAt: nil,
            now: noon
        ))
    }

    func testNextDueNeverPointsIntoThePast() {
        let cases: [(Date?, Date?)] = [
            (nil, nil),
            (noon.addingTimeInterval(-9_999), nil),
            (noon.addingTimeInterval(-60), noon.addingTimeInterval(-30)),
            (noon.addingTimeInterval(9_999), nil),
            (nil, noon.addingTimeInterval(-9_999))
        ]
        for (read, attempt) in cases {
            XCTAssertGreaterThanOrEqual(
                SkyRefresh.nextDue(lastReadAt: read, lastAttemptAt: attempt, now: noon),
                noon
            )
        }
    }

    func testNextDueIsAnHourAfterTheLastReading() {
        XCTAssertEqual(
            SkyRefresh.nextDue(
                lastReadAt: noon.addingTimeInterval(-1_200),
                lastAttemptAt: nil,
                now: noon
            ),
            noon.addingTimeInterval(SkyRefresh.interval - 1_200)
        )
    }

    func testAFailedAttemptPushesTheNextTryOut() {
        // Due on the reading's age alone, but held back by the recent failure.
        let due = SkyRefresh.nextDue(
            lastReadAt: noon.addingTimeInterval(-SkyRefresh.interval),
            lastAttemptAt: noon.addingTimeInterval(-60),
            now: noon
        )
        XCTAssertEqual(due, noon.addingTimeInterval(SkyRefresh.failedAttemptBackoff - 60))
    }

    // MARK: - The place the Book remembers

    func testANeverRecordedPlaceIsNotTrusted() {
        XCTAssertFalse(SkyRefresh.trustsPlace(recordedAt: nil, now: noon))
    }

    func testAPlaceFromThisMorningIsStillWorthAskingAbout() {
        XCTAssertTrue(SkyRefresh.trustsPlace(
            recordedAt: noon.addingTimeInterval(-6 * 3_600),
            now: noon
        ))
    }

    func testYesterdayEveningIsStillTrusted() {
        // The common case the remembered place exists for: the Book is opened
        // most evenings from the same room.
        XCTAssertTrue(SkyRefresh.trustsPlace(
            recordedAt: noon.addingTimeInterval(-23 * 3_600),
            now: noon
        ))
    }

    func testAPlaceOlderThanADayIsNotTrusted() {
        // Long enough to have had a journey in it. No sky at all beats a
        // confident sky over the wrong city.
        XCTAssertFalse(SkyRefresh.trustsPlace(
            recordedAt: noon.addingTimeInterval(-SkyRefresh.placeTrustWindow - 1),
            now: noon
        ))
    }

    func testAPlaceStampedInTheFutureIsNotTrusted() {
        XCTAssertFalse(SkyRefresh.trustsPlace(
            recordedAt: noon.addingTimeInterval(3_600),
            now: noon
        ))
    }

    func testAPlaceIsKeptNoMorePreciselyThanTheSkyNeeds() {
        // About a kilometre: finer than any weather grid, and too coarse to be
        // repurposed for anything that wants a doorstep.
        XCTAssertEqual(SkyRefresh.coarse(51.507351), 51.51, accuracy: 0.0001)
        XCTAssertEqual(SkyRefresh.coarse(-0.127758), -0.13, accuracy: 0.0001)
        XCTAssertEqual(SkyRefresh.coarse(0), 0, accuracy: 0.0001)
    }

    func testCoarseningNeverMovesAPlaceFurtherThanItsOwnPrecision() {
        for raw in stride(from: -179.9, through: 179.9, by: 7.3) {
            XCTAssertLessThanOrEqual(
                abs(SkyRefresh.coarse(raw) - raw),
                0.005001,
                "coarsening moved \(raw) too far"
            )
        }
    }

    func testTheFadeOnlyBeginsWhenReadsAreActuallyFailing() {
        // Two hours of missed reads: the sky is visibly thinner but still
        // there. This is the state the fade exists to show.
        let reading = PaperSky(
            condition: .rain,
            intensity: 1,
            wind: 0.5,
            isDay: true,
            observedAt: noon
        )
        let missed = noon.addingTimeInterval(2 * 3_600)
        let settled = reading.settled(at: missed)
        XCTAssertNotNil(settled)
        XCTAssertLessThan(settled?.intensity ?? 1, 0.6)
        XCTAssertGreaterThan(settled?.intensity ?? 0, 0)
    }

    // MARK: - Drawing nothing is the common case

    func testAClearSkyDrawsNothingEvenWhenPerfectlyFresh() {
        let reading = PaperSky(
            condition: .clear,
            intensity: 1,
            wind: 1,
            isDay: true,
            observedAt: noon
        )
        XCTAssertNil(reading.settled(at: noon))
        XCTAssertFalse(SkyCondition.clear.marksThePaper)
        XCTAssertFalse(SkyCondition.cloud.marksThePaper)
    }

    func testCloudDrawsNothing() {
        let reading = PaperSky(
            condition: .cloud,
            intensity: 1,
            wind: 0.5,
            isDay: true,
            observedAt: noon
        )
        XCTAssertNil(reading.settled(at: noon))
    }

    func testFogIsRecognisedButNotYetDrawn() {
        // Fog is a real condition the Book reads and talks about — it simply
        // does not reach the paper yet. Drawing a haze needs to know where the
        // leaf actually ends, and this layer is only handed the Book's frame.
        // Asserted rather than left implicit so restoring it is a deliberate
        // act with a test to update.
        XCTAssertEqual(SkyCode.condition(45).0, .fog)
        XCTAssertFalse(SkyCondition.fog.marksThePaper)

        let foggy = PaperSky(
            condition: .fog,
            intensity: 1,
            wind: 0,
            isDay: true,
            observedAt: noon
        )
        XCTAssertNil(foggy.settled(at: noon))
        XCTAssertEqual(SkyField.count(for: foggy, leafArea: 105_000), 0)
    }

    // MARK: - Reading Open-Meteo

    func testWeatherCodesMapToConditions() {
        XCTAssertEqual(SkyCode.condition(0).0, .clear)
        XCTAssertEqual(SkyCode.condition(3).0, .cloud)
        XCTAssertEqual(SkyCode.condition(48).0, .fog)
        XCTAssertEqual(SkyCode.condition(65).0, .rain)
        XCTAssertEqual(SkyCode.condition(75).0, .snow)
        XCTAssertEqual(SkyCode.condition(99).0, .storm)
    }

    func testHeavierCodesCarryHigherIntensity() {
        XCTAssertLessThan(SkyCode.condition(51).1, SkyCode.condition(55).1)
        XCTAssertLessThan(SkyCode.condition(61).1, SkyCode.condition(65).1)
        XCTAssertLessThan(SkyCode.condition(71).1, SkyCode.condition(75).1)
    }

    func testAnUnknownCodeInventsNoWeather() {
        let (condition, intensity) = SkyCode.condition(4_242)
        XCTAssertEqual(condition, .cloud)
        XCTAssertEqual(intensity, 0)
        XCTAssertFalse(condition.marksThePaper)
    }

    func testMeasuredPrecipitationSharpensIntensity() {
        let light = SkyCode.reading(code: 61, precipitation: 0.2, observedAt: noon)
        let heavy = SkyCode.reading(code: 61, precipitation: 6, observedAt: noon)
        XCTAssertLessThan(light.intensity, heavy.intensity)
        XCTAssertEqual(heavy.intensity, 1, accuracy: 0.0001)
    }

    func testPrecipitationNeverStartsRainUnderAClearCode() {
        // A stray millimetre against a clear-sky code is a sensor artefact,
        // not rain on this reader's head.
        let reading = SkyCode.reading(code: 0, precipitation: 9, observedAt: noon)
        XCTAssertEqual(reading.condition, .clear)
        XCTAssertNil(reading.settled(at: noon))
    }

    func testMeasuredPrecipitationNeverLowersWhatTheCodeAlreadyClaims() {
        // The code says heavy rain; the hourly total has not caught up yet.
        let reading = SkyCode.reading(code: 65, precipitation: 0.1, observedAt: noon)
        XCTAssertEqual(reading.intensity, SkyCode.condition(65).1, accuracy: 0.0001)
    }

    func testWindScalesAndClamps() {
        XCTAssertEqual(SkyCode.reading(code: 0, windSpeed: 0, observedAt: noon).wind, 0)
        XCTAssertEqual(SkyCode.reading(code: 0, windSpeed: 20, observedAt: noon).wind, 0.5, accuracy: 0.001)
        XCTAssertEqual(SkyCode.reading(code: 0, windSpeed: 200, observedAt: noon).wind, 1)
    }

    func testAMissingWindReadsAsStillAirRatherThanAGale() {
        XCTAssertEqual(SkyCode.reading(code: 61, observedAt: noon).wind, 0)
    }

    // MARK: - The field stays bounded

    func testSpeckCountNeverExceedsTheCeiling() {
        for area in [50_000.0, 105_000, 400_000, 4_000_000] {
            for intensity in stride(from: 0.0, through: 1.0, by: 0.1) {
                let reading = PaperSky(
                    condition: .rain,
                    intensity: intensity,
                    wind: 1,
                    isDay: true,
                    observedAt: noon
                )
                let count = SkyField.count(for: reading, leafArea: area)
                XCTAssertLessThanOrEqual(
                    count,
                    SkyField.ceiling,
                    "area \(area) intensity \(intensity) drew \(count) specks"
                )
            }
        }
    }

    func testHeavierWeatherPutsMoreOnThePaper() {
        let drizzle = PaperSky(condition: .rain, intensity: 0.1, wind: 0, isDay: true, observedAt: noon)
        let downpour = PaperSky(condition: .rain, intensity: 1, wind: 0, isDay: true, observedAt: noon)
        XCTAssertLessThan(
            SkyField.count(for: drizzle, leafArea: 105_000),
            SkyField.count(for: downpour, leafArea: 105_000)
        )
    }

    func testABiggerLeafCarriesMoreDropsAtTheSameDensity() {
        let reading = PaperSky(condition: .rain, intensity: 0.5, wind: 0, isDay: true, observedAt: noon)
        XCTAssertLessThan(
            SkyField.count(for: reading, leafArea: 60_000),
            SkyField.count(for: reading, leafArea: 300_000)
        )
    }

    // MARK: - Specks are deterministic and well-formed

    func testTheSameSeedGivesTheSameField() {
        let a = SkyField.specks(count: 12, condition: .rain, seed: 7)
        let b = SkyField.specks(count: 12, condition: .rain, seed: 7)
        XCTAssertEqual(a, b, "A relaunch must not reshuffle the drops on the leaf.")
    }

    func testSpecksAreSpreadRatherThanStacked() {
        let specks = SkyField.specks(count: 20, condition: .rain, seed: 3)
        let lanes = Set(specks.map { Int($0.laneX * 8) })
        XCTAssertGreaterThan(lanes.count, 3, "Twenty drops fell into fewer than four lanes.")
        let phases = Set(specks.map { Int($0.offset * 6) })
        XCTAssertGreaterThan(phases.count, 2, "The drops are arriving in unison.")
    }

    func testSpeckTraitsStayInRange() {
        for condition in [SkyCondition.rain, .snow, .storm] {
            for speck in SkyField.specks(count: SkyField.ceiling, condition: condition, seed: 11) {
                XCTAssert((0...1).contains(speck.laneX))
                XCTAssert((0...1).contains(speck.restY))
                XCTAssert((0...1).contains(speck.size))
                XCTAssert((0...1).contains(speck.offset))
                XCTAssertGreaterThan(speck.period, 0)
            }
        }
    }

    func testSnowDoesNotRunAndSitsLongerThanRain() {
        let snow = SkyField.specks(count: 24, condition: .snow, seed: 5)
        XCTAssertFalse(snow.contains { $0.runs }, "Snow does not run down a page.")

        let rain = SkyField.specks(count: 24, condition: .rain, seed: 5)
        let snowPeriod = snow.map(\.period).reduce(0, +) / Double(snow.count)
        let rainPeriod = rain.map(\.period).reduce(0, +) / Double(rain.count)
        XCTAssertGreaterThan(snowPeriod, rainPeriod)
    }

    func testOnlyAFewDropsRun() {
        let rain = SkyField.specks(count: SkyField.ceiling, condition: .rain, seed: 2)
        let runners = rain.filter(\.runs).count
        XCTAssertLessThan(
            Double(runners) / Double(rain.count),
            0.4,
            "If they all run, the leaf reads as a windscreen rather than paper."
        )
    }

    func testSnowCollectsAtTheHeadOfTheLeaf() {
        let snow = SkyField.specks(count: SkyField.ceiling, condition: .snow, seed: 9)
        let atTheHead = snow.filter { $0.restY < 0.26 }.count
        XCTAssertGreaterThan(
            atTheHead,
            2,
            "Snow should gather along the head of the leaf, not scatter evenly."
        )
    }

    // MARK: - The speck cycle

    func testEverySpeckStaysOnOrNearTheLeafThroughItsWholeCycle() {
        let specks = SkyField.specks(count: SkyField.ceiling, condition: .rain, seed: 4)
        for speck in specks {
            for step in 0..<240 {
                let frame = SkyField.frame(
                    for: speck,
                    condition: .rain,
                    wind: 1,
                    time: Double(step) * 0.25
                )
                // A generous margin: arriving specks are legitimately above the
                // leaf, and wind pushes them sideways. Anything beyond this is
                // a drop drawn somewhere the paper is not.
                XCTAssert((-0.3...1.3).contains(frame.x), "x \(frame.x) off the leaf")
                XCTAssert((-0.3...1.3).contains(frame.y), "y \(frame.y) off the leaf")
                XCTAssert((0...1).contains(frame.beadAlpha))
                XCTAssert((0...1).contains(frame.dampAlpha))
                XCTAssert((0...1).contains(frame.arrival))
            }
        }
    }

    func testADropArrivesFromAboveWhereItWillRest() {
        let speck = SkySpeck(
            laneX: 0.5,
            restY: 0.6,
            size: 0.5,
            period: 10,
            offset: 0,
            runs: false
        )
        let arriving = SkyField.frame(for: speck, condition: .rain, wind: 0, time: 0.05)
        XCTAssertLessThan(arriving.arrival, 1)
        XCTAssertLessThan(arriving.y, speck.restY, "The drop should still be above its resting place.")

        let landed = SkyField.frame(for: speck, condition: .rain, wind: 0, time: 2)
        XCTAssertEqual(landed.arrival, 1)
        XCTAssertEqual(landed.y, speck.restY, accuracy: 0.0001)
    }

    func testTheDampMarkOutlastsTheBead() {
        let speck = SkySpeck(
            laneX: 0.5,
            restY: 0.5,
            size: 0.5,
            period: 10,
            offset: 0,
            runs: false
        )
        // Late in the drying phase: the bead should be gone or nearly so while
        // the paper is still visibly damp. This is the whole difference between
        // wet paper and a dot drawn on top of a page.
        let drying = SkyField.frame(for: speck, condition: .rain, wind: 0, time: 9.2)
        XCTAssertLessThan(drying.beadAlpha, drying.dampAlpha)
    }

    func testTheCycleRepeats() {
        let speck = SkySpeck(
            laneX: 0.3,
            restY: 0.4,
            size: 0.7,
            period: 8,
            offset: 0.2,
            runs: false
        )
        let first = SkyField.frame(for: speck, condition: .rain, wind: 0, time: 3)
        let second = SkyField.frame(for: speck, condition: .rain, wind: 0, time: 3 + 8)
        XCTAssertEqual(first.y, second.y, accuracy: 0.0001)
        XCTAssertEqual(first.beadAlpha, second.beadAlpha, accuracy: 0.0001)
    }

    func testWindPushesArrivingSpecksAndLetsThemStraightenAsTheyLand() {
        let speck = SkySpeck(
            laneX: 0.5,
            restY: 0.7,
            size: 0.5,
            period: 10,
            offset: 0,
            runs: false
        )
        let still = SkyField.frame(for: speck, condition: .rain, wind: 0, time: 0.2)
        XCTAssertEqual(still.x, 0.5, accuracy: 0.0001)

        let landed = SkyField.frame(for: speck, condition: .rain, wind: 1, time: 4)
        XCTAssertEqual(landed.x, 0.5, accuracy: 0.0001, "A landed drop is not still being blown.")
    }

    func testSnowIsBlownFurtherThanRain() {
        let speck = SkySpeck(
            laneX: 0.5,
            restY: 0.8,
            size: 0.5,
            period: 10,
            offset: 0,
            runs: false
        )
        let rain = SkyField.frame(for: speck, condition: .rain, wind: 1, time: 0.3)
        let snow = SkyField.frame(for: speck, condition: .snow, wind: 1, time: 0.3)
        XCTAssertGreaterThan(
            abs(snow.x - 0.5),
            abs(rain.x - 0.5),
            "A flake should be carried further sideways than a drop."
        )
    }

    // MARK: - The fore-edge

    func testTheForeEdgeIsStillWhenTheAirIs() {
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            XCTAssertEqual(SkyField.waver(at: 12.3, alongEdge: t, amplitude: 0), 0)
        }
    }

    func testTheForeEdgeIsHeldAtTheHeadAndTail() {
        // The binding holds one end and the reader's thumb the other; only the
        // middle of the edge actually moves.
        XCTAssertEqual(SkyField.waver(at: 4, alongEdge: 0, amplitude: 4), 0, accuracy: 0.0001)
        XCTAssertEqual(SkyField.waver(at: 4, alongEdge: 1, amplitude: 4), 0, accuracy: 0.0001)
    }

    func testTheForeEdgeStaysWithinItsAmplitude() {
        for step in 0..<400 {
            let time = Double(step) * 0.13
            for t in stride(from: 0.0, through: 1.0, by: 0.05) {
                let waver = SkyField.waver(at: time, alongEdge: t, amplitude: 3.4)
                XCTAssertLessThanOrEqual(abs(waver), 3.41)
            }
        }
    }

    func testTheForeEdgeActuallyMoves() {
        let samples = stride(from: 0.0, through: 20.0, by: 0.25).map {
            SkyField.waver(at: $0, alongEdge: 0.5, amplitude: 3.4)
        }
        XCTAssertGreaterThan(samples.max()! - samples.min()!, 2)
    }

    func testWaverIsScaledByWindAndStaleness() {
        let fresh = PaperSky(condition: .cloud, intensity: 0, wind: 1, isDay: true, observedAt: noon)
        XCTAssertEqual(fresh.foreEdgeWaver(at: noon), 3.4, accuracy: 0.0001)

        let stale = fresh.foreEdgeWaver(at: noon.addingTimeInterval(PaperSky.staleAt + 60))
        XCTAssertEqual(stale, 0, "A stale wind reading must not still be moving the page.")
    }

    // MARK: - Cost

    func testAWholeFrameOfTheHeaviestFieldIsCheap() {
        // The renderer evaluates this for every speck, every frame, at 30fps.
        // It is pure arithmetic, so the budget is generous — but it is worth a
        // guard, because the one way this layer can become a performance
        // problem is by quietly growing per-speck work.
        let specks = SkyField.specks(count: SkyField.ceiling, condition: .storm, seed: 1)
        measure {
            for step in 0..<1_800 { // a minute of frames at 30fps
                let time = Double(step) / 30
                for speck in specks {
                    _ = SkyField.frame(for: speck, condition: .storm, wind: 1, time: time)
                }
            }
        }
    }
}
