import XCTest
@testable import InsideCoverCore

/// Locks the Center Page's Gear Shifter selection (Wonder Compass, Chapter 10) and the
/// metadata the RestPageSourceAdapter hands the interactive page.
final class CenterPageTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    // MARK: Gear Shifter menu

    func testMenuIDsAreUniqueAndResolvable() {
        let ids = CenterGearShifterMenu.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "every shifter has a unique id")
        for shifter in CenterGearShifterMenu.all {
            XCTAssertEqual(CenterGearShifterMenu.shifter(id: shifter.id), shifter)
        }
        XCTAssertNil(CenterGearShifterMenu.shifter(id: "no-such-shifter"))
    }

    func testDistressAlwaysGetsTheGentlestAllClear() {
        for hour in [3, 9, 14, 21] {
            let chosen = CenterGearShifterMenu.choose(
                hour: hour,
                distressActive: true,
                daylight: (7..<19).contains(hour),
                seed: hour * 13
            )
            XCTAssertEqual(chosen, CenterGearShifterMenu.softGaze,
                           "distress leads with the Soft Gaze regardless of hour")
        }
    }

    func testEveningLeansDeepTheta() {
        for hour in [20, 22, 23, 0, 4] {
            let chosen = CenterGearShifterMenu.choose(
                hour: hour,
                distressActive: false,
                daylight: false,
                seed: hour + 1
            )
            XCTAssertEqual(chosen.gear, .theta, "the late hours offer deep rest (hour \(hour))")
        }
    }

    func testDaytimeOffersFromTheDaylightPool() {
        // Midday, daylight: every result must be a real menu member chosen from the
        // daytime pool (mostly awake Alpha recharges).
        let daytimePoolIDs: Set<String> = ["fractal-soak", "rhythmic-loop", "soft-gaze", "bored-walk"]
        for seed in 0..<24 {
            let chosen = CenterGearShifterMenu.choose(
                hour: 13,
                distressActive: false,
                daylight: true,
                seed: seed
            )
            XCTAssertTrue(daytimePoolIDs.contains(chosen.id), "midday draws from the daylight pool")
        }
    }

    func testChoiceIsDeterministicForASeed() {
        let a = CenterGearShifterMenu.choose(hour: 13, distressActive: false, daylight: true, seed: 7)
        let b = CenterGearShifterMenu.choose(hour: 13, distressActive: false, daylight: true, seed: 7)
        XCTAssertEqual(a, b, "the same hour, state, and seed always pick the same shifter")
    }

    func testNegativeSeedsStayInBounds() {
        // String.stableHash can be negative; the modulo math must never crash or escape.
        for seed in [-1, -7, -1_000, Int.min / 2] {
            let chosen = CenterGearShifterMenu.choose(hour: 13, distressActive: false, daylight: true, seed: seed)
            XCTAssertTrue(CenterGearShifterMenu.all.contains(chosen))
        }
    }

    // MARK: Adapter wiring

    func testAdapterEmitsCenterGearAndRichBodyOnAnEmptyDay() {
        let now = date(2026, 6, 27, 9)
        let day = BookDay(id: "2026-06-27", date: Calendar.current.startOfDay(for: now), pages: [])
        let surfaces = RestPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: BookSourceInputs(),
            now: now
        )
        XCTAssertEqual(surfaces.count, 1, "an empty day offers a Center Page")
        let surface = try? XCTUnwrap(surfaces.first)
        XCTAssertEqual(surface?.type, .rest)
        XCTAssertEqual(surface?.payload.body, CenterPageCopy.body)

        let gearID = surface?.payload.metadata["centerGearID"]
        XCTAssertNotNil(gearID)
        XCTAssertNotNil(gearID.flatMap(CenterGearShifterMenu.shifter(id:)),
                        "the page carries a resolvable Gear Shifter id")
    }

    func testAdapterStaysQuietOnAFullCalmAfternoon() {
        // No distress, pages already captured, mid-afternoon: the Center Page should not
        // force itself into the day.
        let now = date(2026, 6, 27, 14)
        let page = BookPage(type: .souvenir, createdAt: now, promptText: "Souvenir", userInput: "A kept line.")
        let day = BookDay(id: "2026-06-27", date: Calendar.current.startOfDay(for: now), pages: [page])
        let surfaces = RestPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: BookSourceInputs(),
            now: now
        )
        XCTAssertTrue(surfaces.isEmpty, "a calm, already-captured afternoon needs no forced Center Page")
    }
}
