import XCTest
@testable import InsideCoverCore

/// Fuel Log and Inner Weather are owed once per bell, and the log floor seats
/// them. This runs a real day of sittings, with served history recorded as the
/// app records it and the reader logging nothing, and asks whether they are on
/// the desk each time.
final class LogBellsDayTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func sittings(hours: [Int], distressTag: Bool = false) -> [(hour: Int, types: Set<BookPageType>)] {
        let dayStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 0))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: dayStart.addingTimeInterval(-30 * 86_400))
        inputs.localBrainIsReady = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 46
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        // A reader twelve days in, with something kept each day: the new-reader
        // curriculum stages the logs in, and this is about a settled Book.
        var past: [BookDay] = []
        for offset in 1...12 {
            let start = calendar.date(byAdding: .day, value: -offset, to: dayStart)!
            past.append(BookDay(
                id: BookDay.id(for: start, calendar: calendar), date: start,
                pages: [BookPage(
                    id: "kept-\(offset)", type: .souvenir, createdAt: start.addingTimeInterval(3_600),
                    promptText: "p", userInput: "A small true thing, day \(offset).", origin: .userAuthored
                )]
            ))
        }
        var today = BookDay(id: BookDay.id(for: dayStart, calendar: calendar), date: dayStart, pages: [])
        if distressTag {
            today.pages = [BookPage(
                id: "hard", type: .souvenir,
                createdAt: dayStart.addingTimeInterval(6 * 3600), promptText: "p",
                userInput: "I feel hopeless.", origin: .userAuthored
            )]
        }
        var history: [String: SurfaceHistoryRecord] = [:]
        var result: [(Int, Set<BookPageType>)] = []
        for hour in hours {
            let now = calendar.date(bySettingHour: hour, minute: 15, second: 0, of: dayStart)!
            inputs.days = past.reversed() + [today]
            inputs.surfaceHistory = history
            let bench = BookCurator.surfacedPages(
                for: today, inputs: inputs, now: now, limit: BookDeskRound.candidateBenchCapacity
            )
            let desk = Array(bench.prefix(BookDeskRound.reserveCapacity))
            result.append((hour, Set(desk.map(\.type))))
            history = CuratorVarietyGovernor.recordingServed(
                keys: desk.flatMap(\.curatorServedHistoryKeys), into: history, now: now
            )
        }
        return result
    }

    func testFuelLogAndInnerWeatherAreOnTheDeskAtEveryBell() {
        // Morning, midday and evening bells; the night bell is the fourth.
        for sitting in sittings(hours: [8, 13, 19, 22]) {
            XCTAssertTrue(sitting.types.contains(.fuel), "no Fuel Log at \(sitting.hour):15")
            XCTAssertTrue(sitting.types.contains(.mood), "no Inner Weather at \(sitting.hour):15")
        }
    }

    func testTheyAreStillOnTheDeskOnAHardDay() {
        for sitting in sittings(hours: [8, 13, 19], distressTag: true) {
            XCTAssertTrue(sitting.types.contains(.fuel), "no Fuel Log at \(sitting.hour):15 on a hard day")
            XCTAssertTrue(sitting.types.contains(.mood), "no Inner Weather at \(sitting.hour):15 on a hard day")
        }
    }
}
