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
        XCTAssertEqual(spec.preferredPageCount, 32)
        XCTAssertEqual(spec.safeMarginInches, 0.5)
        XCTAssertEqual(spec.publicationBindingKind, .saddleStitched)
    }

    func testWeeklyEditorialTargetsDoNotTreatFortyEightAsAQuota() {
        var quiet = sampleIssue(keptCount: 3)
        XCTAssertEqual(WeeklyPrintEditorialPolicy.preferredPageCount(for: quiet), 20)

        quiet.keptCount = 6
        XCTAssertEqual(WeeklyPrintEditorialPolicy.preferredPageCount(for: quiet), 24)

        quiet.keptCount = 7
        XCTAssertEqual(WeeklyPrintEditorialPolicy.preferredPageCount(for: quiet), 32)

        quiet.keptCount = 3
        quiet.bindingStory = "The week found a shape larger than its page count."
        XCTAssertEqual(WeeklyPrintEditorialPolicy.preferredPageCount(for: quiet), 32)
        XCTAssertEqual(WeeklyPrintEditorialPolicy.technicalMaximumPages, 48)
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
