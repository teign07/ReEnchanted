import XCTest
@testable import InsideCoverCore

final class BookMoodLetteringTests: XCTestCase {
    private let noon: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
    }()

    private func interior(_ mood: BookMood?, baseline: BookStance = .curious) -> BookInteriorState {
        var interior = BookInteriorState(awakenedAt: noon.addingTimeInterval(-86_400 * 30), baselineStance: baseline)
        interior.mood = mood
        return interior
    }

    func testAnUnawakenedBookWritesInPlainInk() {
        XCTAssertNil(BookMoodLettering.current(interior: nil, now: noon))
        XCTAssertNil(BookMoodLettering.current(interior: BookInteriorState(awakenedAt: Date(timeIntervalSinceReferenceDate: 0)), now: noon))
    }

    func testMoodsAreSortedIntoThreeSteps() {
        func strength(_ intensity: Int) -> Int? {
            let mood = BookMood(stance: .mischievous, intensity: intensity, cause: .reading, arrivedAt: noon, halfLife: 3_600)
            return BookMoodLettering.current(interior: interior(mood), now: noon)?.strength
        }
        XCTAssertEqual(strength(1), 1)
        XCTAssertEqual(strength(3), 2)
        XCTAssertEqual(strength(5), 3)
    }

    func testAFadingMoodOnlyChangesInkWhenItCrossesAStep() {
        let mood = BookMood(stance: .pleased, intensity: 5, cause: .keeping, arrivedAt: noon, halfLife: 3 * 3_600)
        let a = BookMoodLettering.current(interior: interior(mood), now: noon)
        let b = BookMoodLettering.current(interior: interior(mood), now: noon.addingTimeInterval(60))
        XCTAssertEqual(a, b, "a minute of fading isn't a new ink")
        let later = BookMoodLettering.current(interior: interior(mood), now: noon.addingTimeInterval(4 * 3_600))
        XCTAssertNotEqual(a, later)
    }

    func testASpentMoodReturnsToTheBooksTemperament() {
        let mood = BookMood(stance: .contrite, intensity: 2, cause: .correction, arrivedAt: noon.addingTimeInterval(-86_400), halfLife: 3_600)
        let lettering = BookMoodLettering.current(interior: interior(mood, baseline: .intent), now: noon)
        XCTAssertEqual(lettering?.stance, .intent)
        XCTAssertEqual(lettering?.strength, 1)
    }

    /// Print leans only a little, so the Book's text stays dark enough to read
    /// on the leaf in every mood, at night, at full strength.
    func testPrintStaysReadableInEveryMood() {
        let ink = BookMoodLettering.RGB(red: 0.18, green: 0.14, blue: 0.10)
        func luminance(_ c: BookMoodLettering.RGB) -> Double {
            func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue)
        }
        for stance in BookStance.allCases {
            for night in [false, true] {
                let lettering = BookMoodLettering(stance: stance, strength: 3, night: night)
                let leaned = ink.mixed(toward: lettering.hue, by: lettering.printLean)
                XCTAssertLessThan(luminance(leaned), 0.06, "\(stance) at night=\(night)")
                XCTAssertLessThan(lettering.printLean, lettering.handLean)
                XCTAssertGreaterThanOrEqual(lettering.inkOpacity, 0.8)
            }
        }
    }

    func testEagerMoodsInkFasterThanQuietOnes() {
        let pleased = BookMoodLettering(stance: .pleased, strength: 3, night: false)
        let hushed = BookMoodLettering(stance: .hushed, strength: 3, night: false)
        XCTAssertLessThan(pleased.tempo, 1)
        XCTAssertGreaterThan(hushed.tempo, 1)
        for stance in BookStance.allCases {
            for strength in 1...3 {
                for night in [false, true] {
                    let tempo = BookMoodLettering(stance: stance, strength: strength, night: night).tempo
                    XCTAssertTrue((0.7...1.6).contains(tempo), "\(stance) \(strength) \(night): \(tempo)")
                }
            }
        }
    }
}
