import XCTest
@testable import InsideCoverCore

/// The addicting-loop legibility pieces: the 6pm early-bird braid option, the
/// session-one first-braid exception, the daytime "thread caught" cue, and the
/// night-one wagers that pay off later as receipts.
final class OnboardingLoopTests: XCTestCase {
    private func date(_ day: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func page(_ text: String, on day: Int, hour: Int) -> BookPage {
        BookPage(type: .souvenir, createdAt: date(day, hour: hour), promptText: "S", userInput: text)
    }

    private func day(_ id: String, dayNum: Int, pageCount: Int, braided: Bool = false) -> BookDay {
        var pages = (1...max(1, pageCount)).map { page("a kept line number \($0), with substance", on: dayNum, hour: 7 + $0) }
        if pageCount == 0 { pages = [] }
        if braided {
            pages.append(BookPage(type: .bookOfYou, createdAt: date(dayNum, hour: 21), promptText: "Book of You", userInput: "braided"))
        }
        return BookDay(id: id, date: date(dayNum), pages: pages)
    }

    // MARK: - 6pm early-bird option (not mandatory)

    func testBraidSurfacesFromSixPMButAutoBraidStillWaits() {
        XCTAssertFalse(BookSchedule.isBraidSurfaceTime(date(1, hour: 17)))
        XCTAssertTrue(BookSchedule.isBraidSurfaceTime(date(1, hour: 18)), "early birds may open the braid from 6pm")
        // The automatic braid stays an evening ritual, so 6pm is an option, not a push.
        XCTAssertFalse(BookSchedule.shouldAutoBraid(date(1, hour: 18)))
        XCTAssertTrue(BookSchedule.shouldAutoBraid(date(1, hour: 22)))
    }

    func testAutomaticBraidClockTargetsTonightBeforeThreshold() {
        let next = BookSchedule.nextAutoBraidDate(after: date(1, hour: 18))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 21)
        XCTAssertEqual(components.minute, 30)
    }

    func testAutomaticBraidClockTargetsTomorrowAfterThreshold() {
        let next = BookSchedule.nextAutoBraidDate(after: date(1, hour: 22))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 2)
        XCTAssertEqual(components.hour, 21)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - First-braid session-one exception

    func testFirstEverBraidMayCloseTheLoopInSessionOne() {
        let today = day("2026-07-01", dayNum: 1, pageCount: 3)
        XCTAssertTrue(
            BookOfYouPageSourceAdapter.mayShowBraid(for: today, previousDays: [], now: date(1, hour: 12)),
            "a morning onboarder with three kept pages should still see their first braid"
        )
    }

    func testFirstBraidExceptionNeedsEnoughThreads() {
        let thin = day("2026-07-01", dayNum: 1, pageCount: 2)
        XCTAssertFalse(BookOfYouPageSourceAdapter.mayShowBraid(for: thin, previousDays: [], now: date(1, hour: 12)))
    }

    func testBraidRevertsToEveningRhythmAfterTheFirstEver() {
        let priorBraided = day("2026-07-01", dayNum: 1, pageCount: 3, braided: true)
        let today = day("2026-07-02", dayNum: 2, pageCount: 3)
        XCTAssertFalse(
            BookOfYouPageSourceAdapter.mayShowBraid(for: today, previousDays: [priorBraided], now: date(2, hour: 12)),
            "once an install has braided once, later braids wait for the evening"
        )
        XCTAssertTrue(BookOfYouPageSourceAdapter.mayShowBraid(for: today, previousDays: [priorBraided], now: date(2, hour: 19)))
    }

    // MARK: - Daytime "thread caught" cue

    func testThreadCaughtMarginFiresOnlyAfterTheFirstDaytimeKeep() {
        XCTAssertNil(KeepMarginalia.braidGatheringLine(keptEarlierToday: 0, now: date(1, hour: 12)),
                     "nothing gathers on the very first keep")
        XCTAssertNotNil(KeepMarginalia.braidGatheringLine(keptEarlierToday: 1, now: date(1, hour: 12)))
        XCTAssertNil(KeepMarginalia.braidGatheringLine(keptEarlierToday: 2, now: date(1, hour: 19)),
                     "in the evening the braid card takes over from the anticipation cue")
    }

    // MARK: - Night-one wagers

    func testFirstWagersAreStableAndDistinct() {
        let a = FirstWagers.three(seed: "Mara")
        let b = FirstWagers.three(seed: "Mara")
        XCTAssertEqual(a.map(\.id), b.map(\.id), "the same install always sees the same three")
        XCTAssertEqual(Set(a.map(\.id)).count, 3, "three distinct wagers")
    }

    func testWagerQuestionIDRoundTrips() {
        let wager = FirstWagers.all[0]
        XCTAssertEqual(FirstWagers.wager(forQuestionID: FirstWagers.questionID(for: wager.id))?.id, wager.id)
        XCTAssertNil(FirstWagers.wager(forQuestionID: "onboarding-snack"))
    }

    private func wagerFact(_ id: String) -> SelfFact {
        SelfFact(
            id: "onboarding:\(FirstWagers.questionID(for: id))",
            questionID: FirstWagers.questionID(for: id),
            question: "A night-one wager.",
            answer: FirstWagers.wager(id: id)?.guess ?? "",
            bookTranslation: "",
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: ["wager", FirstWagers.confirmedTag, "onboarding"],
            createdAt: date(1),
            updatedAt: date(1)
        )
    }

    func testWagerReceiptPaysOffWithTheReadersOwnWords() {
        let pages = [page("The kitchen window held the last of the gold light.", on: 1, hour: 9)]
        let receipt = FirstReading.wagerReceipt(selfFacts: [wagerFact("beauty-seeker")], pages: pages)
        XCTAssertNotNil(receipt)
        XCTAssertTrue(receipt!.contains("I no longer have to guess"))
        XCTAssertTrue(receipt!.contains("gold light"), "the receipt quotes the page that proved the wager")
    }

    func testWagerReceiptFallsBackHonestlyWhenNoPageMatches() {
        let pages = [page("zzz qqq wxyz", on: 1, hour: 9)]
        let receipt = FirstReading.wagerReceipt(selfFacts: [wagerFact("quiet-strength")], pages: pages)
        XCTAssertNotNil(receipt)
        XCTAssertTrue(receipt!.contains("still watching"), "an unproven wager admits it is still a bet")
    }

    func testNoWagerReceiptWithoutConfirmedWagers() {
        let pages = [page("The kitchen window held the last of the gold light.", on: 1, hour: 9)]
        XCTAssertNil(FirstReading.wagerReceipt(selfFacts: [], pages: pages))
    }
}
