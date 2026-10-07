import XCTest
@testable import InsideCoverCore

/// The Book brings up paper at the end of a season or a year, once, and never
/// to a reader who already has the books coming. The month-close Page steps
/// aside when a bigger one is speaking, so nobody is asked twice in a week.
final class EditionOfferTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
    }

    /// `count` distinct kept pages spread over the days of `months` in `year`.
    private func pages(year: Int, months: ClosedRange<Int>, count: Int) -> [BookDay] {
        var days: [BookDay] = []
        let monthList = Array(months)
        for index in 0..<count {
            let month = monthList[index % monthList.count]
            let day = 1 + (index / monthList.count) % 27
            let when = date(year, month, day)
            let id = "\(year)-\(month)-\(day)-\(index)"
            days.append(BookDay(id: id, date: when, pages: [
                BookPage(
                    id: "p\(id)",
                    type: .souvenir,
                    createdAt: when,
                    promptText: "Souvenir",
                    userInput: "Kept ink \(index): the light on the wall at number \(index * 7 + 3).",
                    origin: .userAuthored
                )
            ]))
        }
        return days
    }

    private func surfaces(
        adapter: some BookPageSourceAdapter,
        now: Date,
        inputs: BookSourceInputs
    ) -> [SurfacePage] {
        let day = BookDay(id: "today", date: now, pages: [])
        return adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
    }

    // MARK: Policy

    func testSeasonIsOfferedInTheTenDaysAfterItCloses() {
        let archive = pages(year: 2026, months: 7...9, count: 40)
        let offer = EditionOfferPolicy.current(days: archive, now: date(2026, 10, 3), calendar: calendar)
        XCTAssertEqual(offer?.cadence, .seasonal)
        XCTAssertEqual(offer?.label, "July to September")
        XCTAssertNil(EditionOfferPolicy.current(days: archive, now: date(2026, 10, 20), calendar: calendar))
        XCTAssertNil(EditionOfferPolicy.current(days: archive, now: date(2026, 9, 28), calendar: calendar))
    }

    func testAThinSeasonIsNotWorthMentioning() {
        let archive = pages(year: 2026, months: 9...9, count: 6)
        XCTAssertNil(EditionOfferPolicy.current(days: archive, now: date(2026, 10, 3), calendar: calendar))
    }

    func testAYearOutranksTheSeasonThatClosesWithIt() {
        let archive = pages(year: 2026, months: 1...12, count: 160)
        let offer = EditionOfferPolicy.current(days: archive, now: date(2027, 1, 5), calendar: calendar)
        XCTAssertEqual(offer?.cadence, .annual)
        XCTAssertEqual(offer?.label, "2026")
        XCTAssertNil(EditionOfferPolicy.season(days: archive, now: date(2027, 1, 5), calendar: calendar))
    }

    func testTheMonthPageStepsAsideWhenASeasonClosedWithIt() {
        let archive = pages(year: 2026, months: 7...9, count: 40)
        XCTAssertTrue(EditionOfferPolicy.monthStepsAside(days: archive, now: date(2026, 10, 3), calendar: calendar))
        XCTAssertFalse(EditionOfferPolicy.monthStepsAside(days: archive, now: date(2026, 8, 3), calendar: calendar))
    }

    func testPeriodIdentityRoundTrips() throws {
        let archive = pages(year: 2026, months: 7...9, count: 40)
        let offer = try XCTUnwrap(EditionOfferPolicy.current(days: archive, now: date(2026, 10, 3), calendar: calendar))
        XCTAssertEqual(PublicationPeriodID(rawValue: offer.periodRawValue), offer.candidate.period.id)
        XCTAssertNil(PublicationPeriodID(rawValue: "nonsense"))
    }

    // MARK: The Pages

    func testTheSeasonPageCarriesThePeriodAndThePrice() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = pages(year: 2026, months: 7...9, count: 40)
        let page = try XCTUnwrap(surfaces(adapter: EditionOfferPageSourceAdapter(), now: date(2026, 10, 3), inputs: inputs).first)
        XCTAssertEqual(page.type, .bindery)
        XCTAssertEqual(page.payload.metadata["editionOfferCadence"], "seasonal")
        XCTAssertNotNil(PublicationPeriodID(rawValue: page.payload.metadata["editionOfferPeriod"] ?? ""))
        XCTAssertTrue(page.payload.body.contains(BoundYearPricing.annualDisplayPrice))
        XCTAssertTrue(page.payload.body.contains(BoundYearPricing.monthlyDisplayPrice))
        XCTAssertTrue(page.payload.body.contains("order just this one"))
    }

    func testAMemberIsNotAskedToJoin() throws {
        var inputs = BookSourceInputs.empty
        inputs.holdsBoundYear = true
        inputs.days = pages(year: 2026, months: 7...9, count: 40)
        let page = try XCTUnwrap(surfaces(adapter: EditionOfferPageSourceAdapter(), now: date(2026, 10, 3), inputs: inputs).first)
        XCTAssertFalse(page.payload.body.contains(BoundYearPricing.annualDisplayPrice))
        XCTAssertTrue(page.payload.body.contains("already posting"))
    }

    func testTheSeasonPageIsOfferedOnce() {
        var inputs = BookSourceInputs.empty
        inputs.days = pages(year: 2026, months: 7...9, count: 40)
        inputs.surfaceHistory["source:bindery-offer-season"] = SurfaceHistoryRecord(
            lastShownAt: date(2026, 10, 2), recentShowCount: 1
        )
        XCTAssertTrue(surfaces(adapter: EditionOfferPageSourceAdapter(), now: date(2026, 10, 3), inputs: inputs).isEmpty)
    }

    func testTheYearPageOutranksTheSeasonPage() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = pages(year: 2026, months: 1...12, count: 160)
        let found = surfaces(adapter: EditionOfferPageSourceAdapter(), now: date(2027, 1, 5), inputs: inputs)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.payload.metadata["editionOfferCadence"], "annual")
    }

    func testTheMonthPageStandsDownForTheSeasonPage() {
        var inputs = BookSourceInputs.empty
        inputs.days = pages(year: 2026, months: 7...9, count: 40)
        XCTAssertTrue(surfaces(adapter: BinderyPageSourceAdapter(), now: date(2026, 10, 3), inputs: inputs).isEmpty)
    }

    func testTheMonthPageMentionsTheBoundYearWithoutLeadingWithIt() throws {
        var inputs = BookSourceInputs.empty
        inputs.days = pages(year: 2026, months: 5...5, count: 8)
        let page = try XCTUnwrap(surfaces(adapter: BinderyPageSourceAdapter(), now: date(2026, 6, 3), inputs: inputs).first)
        let body = page.payload.body
        let print = try XCTUnwrap(body.range(of: "on paper")).lowerBound
        let sub = try XCTUnwrap(body.range(of: "Bound Year")).lowerBound
        XCTAssertLessThan(print, sub, "the single book comes first")
        XCTAssertEqual(page.payload.metadata["opensBookShop"], "true")
    }

    // MARK: Voice

    func testTheCopyKeepsTheBooksVoice() {
        let all = [
            EditionOfferCopy.seasonHeadline(label: "July to September"),
            EditionOfferCopy.seasonBody(label: "July to September", pageCount: 40, isMember: false),
            EditionOfferCopy.seasonBody(label: "July to September", pageCount: 40, isMember: true),
            EditionOfferCopy.annualHeadline(label: "2026"),
            EditionOfferCopy.annualBody(label: "2026", pageCount: 160, isMember: false),
            EditionOfferCopy.annualBody(label: "2026", pageCount: 160, isMember: true),
            EditionOfferCopy.monthlyAddendum(joinMonth: "June", isMember: false),
            EditionOfferCopy.monthlyAddendum(joinMonth: "June", isMember: true),
            EditionOfferCopy.weeklySpineLine(monthName: "June", monthPageCount: 9)
        ] + PublicationEditionKind.allCases.map(EditionOfferCopy.asideLine)
        for text in all {
            let lower = text.lowercased()
            for banned in ["hinge", "ritual", "feel free", "no pressure", "limited time", "don't miss", "exclusive"] {
                XCTAssertFalse(lower.contains(banned), "\(banned) in: \(text)")
            }
            XCTAssertNil(lower.range(of: #"\bnot\b[^.]{0,40}\bbut\b"#, options: .regularExpression), text)
            for stiff in [" do not ", " cannot ", " it is ", " you will ", " i will ", " that is "] {
                XCTAssertFalse(lower.contains(stiff), "\(stiff) in: \(text)")
            }
        }
    }
}
