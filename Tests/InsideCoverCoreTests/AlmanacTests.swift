import XCTest
@testable import InsideCoverCore

final class AlmanacTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 21)) ?? Date()
    }

    func testSabbatsLandOnTheirDates() {
        XCTAssertEqual(Almanac.activeSabbat(on: date(2026, 10, 31))?.id, "sabbat-samhain")
        XCTAssertEqual(Almanac.activeSabbat(on: date(2026, 5, 1))?.id, "sabbat-beltane")
        XCTAssertEqual(Almanac.activeSabbat(on: date(2026, 2, 1))?.id, "sabbat-imbolc")
        XCTAssertEqual(Almanac.activeSabbat(on: date(2026, 8, 1))?.id, "sabbat-lughnasadh")
        // An ordinary day has no sabbat.
        XCTAssertNil(Almanac.activeSabbat(on: date(2026, 7, 7)))
    }

    func testSouthernHemisphereFlipsTheWheel() {
        // On Samhain's northern date, a southern reader keeps Beltane.
        XCTAssertEqual(Almanac.activeSabbat(on: date(2026, 10, 31), hemisphere: .southern)?.id, "sabbat-beltane")
        // On Beltane's northern date, a southern reader keeps Samhain.
        XCTAssertEqual(Almanac.activeSabbat(on: date(2026, 5, 1), hemisphere: .southern)?.id, "sabbat-samhain")
    }

    func testHemisphereFromLatitude() {
        XCTAssertEqual(Hemisphere.from(latitude: 44.8), .northern)   // Maine
        XCTAssertEqual(Hemisphere.from(latitude: -33.9), .southern)  // Sydney
        XCTAssertEqual(Hemisphere.from(latitude: nil), .northern)    // default
    }

    func testEsbatsDetectFullAndNewMoon() {
        // Scan a synodic month; both a full and a new esbat must occur.
        var sawFull = false
        var sawNew = false
        var probe = date(2026, 1, 1)
        for _ in 0..<31 {
            switch Almanac.activeEsbat(on: probe)?.id {
            case "esbat-full": sawFull = true
            case "esbat-new": sawNew = true
            default: break
            }
            probe = probe.addingTimeInterval(86_400)
        }
        XCTAssertTrue(sawFull, "a full-moon esbat occurs within a month")
        XCTAssertTrue(sawNew, "a new-moon esbat occurs within a month")
    }

    func testMeteorShowersLandInWindow() {
        XCTAssertEqual(Almanac.activeShower(on: date(2026, 8, 12))?.id, "shower-perseids")
        XCTAssertEqual(Almanac.activeShower(on: date(2026, 12, 14))?.id, "shower-geminids")
        XCTAssertNil(Almanac.activeShower(on: date(2026, 7, 7)))
    }

    func testSabbatOutranksEsbatForHeadline() {
        // Samhain always wins the headline even if the moon is also doing something.
        let samhain = date(2026, 10, 31)
        XCTAssertEqual(Almanac.active(on: samhain)?.kind, .sabbat)
    }

    func testGreyShiftBendsTheNothing() {
        // Litha pushes the grey back hard; Samhain lets it nearer.
        XCTAssertLessThan(Almanac.greyShift(on: date(2026, 6, 21)), 0)
        XCTAssertGreaterThan(Almanac.greyShift(on: date(2026, 10, 31)), 0)
        // Wired into the curator's grey computation (clamped to 0...3).
        let lithaGrey = NothingTide.greyLevel(quietDays: 4, narrativeHeat: 0, distressActive: false,
                                              celebrationGreyShift: Almanac.greyShift(on: date(2026, 6, 21)))
        let plainGrey = NothingTide.greyLevel(quietDays: 4, narrativeHeat: 0, distressActive: false)
        XCTAssertLessThan(lithaGrey, plainGrey)
        // Distress still wins: no grey, no celebration override.
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 4, narrativeHeat: 0, distressActive: true,
                                             celebrationGreyShift: 3), 0)
    }

    func testSurfaceBoostsLeanIntoTheFeast() {
        // Samhain leans the feed toward the returning/lost.
        let samhain = Almanac.surfaceBoosts(on: date(2026, 10, 31))
        XCTAssertGreaterThan(samhain[.bookRemembered] ?? 0, 0)
        // Beltane leans toward connection.
        let beltane = Almanac.surfaceBoosts(on: date(2026, 5, 1))
        XCTAssertGreaterThan(beltane[.letter] ?? 0, 0)
        // An ordinary day adds nothing.
        XCTAssertTrue(Almanac.surfaceBoosts(on: date(2026, 7, 7)).isEmpty)
    }

    func testAlmanacBoostReachesTheCurator() {
        var inputs = BookSourceInputs.empty
        let mood = CuratorMood.make(inputs: inputs, now: date(2026, 5, 1)) // Beltane
        let letterPage = SurfacePage(
            id: "l", type: .letter, sourceID: "character-letter", intent: .reflect,
            renderStyle: .loreLetter, score: 50, reason: "", prompt: "p", detail: "d",
            payload: BookPagePayload(headline: "h", body: "b")
        )
        XCTAssertGreaterThan(mood.adjustment(for: letterPage, now: date(2026, 5, 1)), 0)
        _ = inputs
    }

    func testFestivalAdapterSurfacesActiveCelebration() {
        var inputs = BookSourceInputs.empty
        let now = date(2026, 10, 31)
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let pages = FestivalPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
        XCTAssertEqual(pages.first?.type, .festival)
        XCTAssertEqual(pages.first?.payload.metadata["celebrationID"], "sabbat-samhain")
        XCTAssertFalse(pages.first?.payload.metadata["invitation"]?.isEmpty ?? true)
        _ = inputs // silence unused warning if any
    }
}
