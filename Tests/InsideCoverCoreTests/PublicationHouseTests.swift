import XCTest
@testable import InsideCoverCore

final class PublicationHouseTests: XCTestCase {
    func testSpecialEditionsAreCatalogueRecipesRatherThanCheckoutForks() throws {
        let people = PublicationHouseCatalogue.peopleYouKept
        XCTAssertEqual(people.id, "special-people-you-kept")
        XCTAssertTrue(people.sourceKinds.contains(.keptPeople))
        XCTAssertTrue(people.sourceKinds.contains(.relationshipReceipts))
        XCTAssertTrue(people.bindingKinds.contains(.softcover))
        XCTAssertTrue(people.canOrderALaCarte)
        XCTAssertTrue(people.canGift)

        let letters = PublicationHouseCatalogue.lettersFromTheLabyrinth
        XCTAssertTrue(letters.sourceKinds.contains(.castLetters))
        XCTAssertTrue(letters.sourceKinds.contains(.marginalia))
        XCTAssertFalse(letters.canGift)

        let roundTrip = try JSONDecoder().decode(
            PublicationEditionRecipe.self,
            from: JSONEncoder().encode(people)
        )
        XCTAssertEqual(roundTrip, people)
    }

    func testSpecialEditionRecipeIDsAreUnique() {
        let recipes = PublicationHouseCatalogue.specialEditions
        XCTAssertEqual(Set(recipes.map(\.id)).count, recipes.count)
    }

    func testSpecialEditionRecipeControlsItsPhysicalBindings() {
        var edition = sampleEdition()
        edition.publicationKind = .special
        edition.publicationRecipeID = PublicationHouseCatalogue.peopleYouKept.id

        let variants = PrintSpec.printableVariants(for: edition)
        XCTAssertEqual(
            variants.map(\.publicationBindingKind),
            [.softcover, .illustratedHardcover, .clothFoilHardcover]
        )
        XCTAssertFalse(variants.contains { $0.coverTreatment == .saddleStitch })
    }

    func testWeeklyIssueUsesFoldedPageGeometry() {
        let spec = PrintSpec.saddleStitchedWeekly6x9
        XCTAssertEqual(PrintGeometry.boundPageCount(rawPages: 5, spec: spec), 8)
        XCTAssertEqual(PrintGeometry.boundPageCount(rawPages: 46, spec: spec), 48)
        XCTAssertEqual(PrintGeometry.spineWidthInches(pageCount: 48, spec: spec), 0)
        XCTAssertEqual(spec.maximumPages, 48)
        // A weekly is as long as its week; this is only the pre-render estimate.
        XCTAssertEqual(spec.preferredPageCount, WeeklyPrintEditorialPolicy.typicalPages)
        XCTAssertEqual(spec.safeMarginInches, 0.5)
        XCTAssertEqual(spec.publicationBindingKind, .saddleStitched)
    }

    private func week(_ perDay: [Int], binding: String? = nil) -> WeeklyIssue {
        var issue = sampleIssue(keptCount: perDay.reduce(0, +))
        issue.pages = perDay.enumerated().flatMap { day, count in
            (0..<count).map { index in
                BookPage(id: "d\(day)-\(index)", type: .diary,
                         createdAt: issue.startDate.addingTimeInterval(Double(day) * 86_400 + Double(index) * 600 + 3_600),
                         promptText: "p", userInput: "Line \(day)-\(index).")
            }
        }
        issue.bindingStory = binding
        return issue
    }

    /// bj, 2026-09-23: the weekly is variable length, up to the press maximum.
    func testAWeeklyIsAsLongAsItsWeekInSignaturesOfFour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let thin = WeeklyPrintLayoutPlan.make(for: week([1, 0, 0, 1, 0, 0, 0]), dedication: nil, calendar: calendar)
        let full = WeeklyPrintLayoutPlan.make(for: week([3, 2, 2, 3, 1, 2, 2],
            binding: String(repeating: "The week kept its shape. ", count: 180)), dedication: nil, calendar: calendar)
        for plan in [thin, full] {
            XCTAssertEqual(plan.plannedPageCount, plan.targetPageCount)
            XCTAssertTrue(plan.targetPageCount.isMultiple(of: 4))
            XCTAssertLessThanOrEqual(plan.targetPageCount, WeeklyPrintEditorialPolicy.technicalMaximumPages)
            XCTAssertEqual(plan.interactivePageCount, 2)
            let beforeActivity = plan.sections.prefix { $0.kind != .interactiveLeaf }.reduce(0) { $0 + $1.pageCount }
            XCTAssertTrue(beforeActivity.isMultiple(of: 2), "the worktable opens on a recto")
            XCTAssertEqual(plan.sections.last?.kind, .colophon)
        }
        XCTAssertLessThan(thin.targetPageCount, full.targetPageCount)
        XCTAssertLessThanOrEqual(thin.targetPageCount, 20, "a two-day week is not a forty-page magazine")
        XCTAssertEqual(thin.dayLeaves, [1, 0, 0, 1, 0, 0, 0])
        XCTAssertEqual(thin.pages(.quietDays), 1, "quiet days share one leaf")
        XCTAssertEqual(thin.pages(.findings), 0, "no finding is invented")
        XCTAssertEqual(full.pages(.bindingStory), 4)
    }

    func testTheWeeklyPlanNeverPassesThePress() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var issue = week([4, 4, 4, 4, 4, 4, 4], binding: String(repeating: "A long week. ", count: 600))
        issue.revelations = (0..<3).map { index in
            BindingRevelations.Revelation(id: "r\(index)", kind: .recurringWord, title: "T", body: "B", evidence: [], strength: 60)
        }
        issue.previousLooseThread = WeeklyLooseThread(title: "Old", body: "Thread", evidence: [])
        let dedication = try? XCTUnwrap(BoundDedication(text: "For you."))
        let plan = WeeklyPrintLayoutPlan.make(for: issue, dedication: dedication, hasDeskConversation: true, calendar: calendar)
        XCTAssertLessThanOrEqual(plan.targetPageCount, 48)
        XCTAssertEqual(plan.plannedPageCount, plan.targetPageCount)
        XCTAssertTrue(plan.targetPageCount.isMultiple(of: 4))
    }

    func testWeeklyPublicationMatterSurvivesArchiveRoundTrip() throws {
        let matter = WeeklyPublicationMatter(
            issue: sampleIssue(keptCount: 7),
            card: WeeklyIssueShareCard.make(issue: sampleIssue(keptCount: 7)),
            readerName: "Reader",
            editorialNote: "The week came in with mud on it.",
            closingNote: "It left one lamp burning."
        )
        var edition = sampleEdition()
        edition.publicationKind = .weekly
        edition.publicationRecipeID = "weekly-issue-4"
        edition.weeklyPublication = matter

        let decoded = try JSONDecoder().decode(
            MonthlyEdition.self,
            from: JSONEncoder().encode(edition)
        )
        XCTAssertEqual(decoded.weeklyPublication, matter)
        XCTAssertEqual(PrintSpec.printableVariants(for: decoded), [.saddleStitchedWeekly6x9])
    }

    private func sampleEdition() -> MonthlyEdition {
        MonthlyEdition(
            title: "A Small Edition",
            subtitle: "Proof copy",
            generatedAt: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_749_000_000),
            endDate: Date(timeIntervalSince1970: 1_750_000_000),
            dayCount: 7,
            pageCount: 8,
            readerName: "Reader",
            chapterNumber: 1,
            monthName: "June",
            theme: nil,
            constellations: [],
            foreword: "The Book found a small stack.",
            sections: [],
            continuity: .empty,
            howYouSee: nil
        )
    }

    private func sampleIssue(keptCount: Int) -> WeeklyIssue {
        WeeklyIssue(
            number: 4,
            startDate: Date(timeIntervalSince1970: 1_749_000_000),
            endDate: Date(timeIntervalSince1970: 1_749_604_800),
            dateRange: "Jun 5–11",
            keptCount: keptCount,
            highlights: ["The blue cup waited by the sink."],
            setAsideLine: nil
        )
    }
}
