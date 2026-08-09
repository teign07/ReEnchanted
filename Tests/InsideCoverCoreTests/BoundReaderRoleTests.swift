import XCTest
@testable import InsideCoverCore

/// Phase 0 of the bound-volumes plan: the Book names the reader on night one,
/// and the bound volume must know it. These tests pin the places that name is
/// allowed to appear, and — more importantly — pin the *receipt*: a mark may
/// never be printed without the evidence that earned it.
final class BoundReaderRoleTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var bindingDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 21)) ?? Date()
    }

    private func role(withMark: Bool) -> BoundReaderRole {
        BoundReaderRole(
            fullName: "The Magpie of the Blue Hour",
            signature: "The Magpie of the Blue Hour, with Quiet Hands",
            gloss: "You come alive when something catches the light.",
            compassLine: "Take one bright thing off the street today.",
            markName: withMark ? "Clear-Eyed" : nil,
            markEvidence: withMark ? "You wrote down the crack in the pavement before you wrote down the promotion." : nil
        )
    }

    /// Page ids are derived from the day so a multi-day fixture does not hand
    /// the curator seven copies of the same page and get one back.
    private func day(_ now: Date) -> BookDay {
        let dayID = BookDay.id(for: now, calendar: calendar)
        return BookDay(
            id: dayID,
            date: calendar.startOfDay(for: now),
            pages: [
                BookPage(
                    id: "p-\(dayID)",
                    type: .souvenir,
                    createdAt: now,
                    promptText: "One true sentence",
                    userInput: "The harbour kept its minutes on \(dayID) and gave none of them back."
                )
            ]
        )
    }

    private func edition(role: BoundReaderRole?) -> MonthlyEdition {
        let now = bindingDate
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
        return MonthlyEditionBuilder.edition(
            from: [day(now)],
            readerName: "Reader",
            readerRole: role,
            startDate: monthStart,
            endDate: now,
            generatedAt: now,
            calendar: calendar
        )
    }

    // MARK: The flattening

    func testNilComposedRoleFlattensToNil() {
        XCTAssertNil(BoundReaderRole(nil))
    }

    func testMarkedNameFallsBackToFullNameWithoutAMark() {
        XCTAssertEqual(role(withMark: false).markedName, "The Magpie of the Blue Hour")
        XCTAssertEqual(role(withMark: true).markedName, "The Magpie of the Blue Hour, Clear-Eyed")
    }

    func testRoleSurvivesACodableRoundTrip() throws {
        let original = role(withMark: true)
        let decoded = try JSONDecoder().decode(
            BoundReaderRole.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded, original)
    }

    // MARK: The volume

    func testChapterHeadingPrefersTheRoleAndFallsBackToTheName() {
        XCTAssertTrue(
            edition(role: role(withMark: false)).chapterHeading.contains("The Magpie of the Blue Hour"),
            "A named reader should be named in their own chapter heading."
        )
        let unnamed = edition(role: nil)
        XCTAssertTrue(unnamed.chapterHeading.contains("Reader"))
        XCTAssertFalse(unnamed.chapterHeading.contains("Magpie"))
    }

    func testTheEditionCarriesTheRoleItWasBoundWith() {
        XCTAssertEqual(edition(role: role(withMark: true)).readerRole, role(withMark: true))
        XCTAssertNil(edition(role: nil).readerRole)
    }

    // MARK: The prose

    func testForewordAddressesTheReaderByRole() {
        XCTAssertTrue(
            edition(role: role(withMark: false)).foreword.contains("The Magpie of the Blue Hour"),
            "The first line of the reader's own chapter is where the naming pays off."
        )
    }

    func testForewordNeverNamesTheReaderBeforeTheBookHas() {
        XCTAssertFalse(edition(role: nil).foreword.contains("Magpie"))
    }

    /// The load-bearing rule. A mark is the Book making a claim about the
    /// reader; printing it without the evidence that earned it turns the whole
    /// naming ceremony into flattery.
    func testAMarkIsNeverPrintedWithoutItsEvidence() {
        let marked = edition(role: role(withMark: true)).foreword
        XCTAssertTrue(marked.contains("Clear-Eyed"))
        XCTAssertTrue(
            marked.contains("You wrote down the crack in the pavement before you wrote down the promotion."),
            "The mark must always be accompanied by the receipt for it."
        )
    }

    func testAnUnmarkedRoleClaimsNoMark() {
        XCTAssertFalse(edition(role: role(withMark: false)).foreword.contains("Clear-Eyed"))
    }

    func testClosingCarriesTheCompassLineAsAStandingCharge() {
        let closing = edition(role: role(withMark: false)).closing ?? ""
        XCTAssertTrue(
            closing.contains("Take one bright thing off the street today."),
            "The compass line is an imperative, and belongs in the last words of the chapter."
        )
    }

    func testClosingStaysQuietWithoutARole() {
        XCTAssertFalse((edition(role: nil).closing ?? "").contains("Take one bright thing"))
    }

    // MARK: The weekly issue

    func testWeeklyIssueCarriesTheRole() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9)) ?? bindingDate
        let days = (0..<8).compactMap { offset -> BookDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return day(date)
        }
        let issue = WeeklyIssue.current(
            days: days,
            readerRole: role(withMark: true),
            now: calendar.date(byAdding: .day, value: 8, to: start) ?? start,
            calendar: calendar
        )
        XCTAssertEqual(issue?.readerRole?.fullName, "The Magpie of the Blue Hour")
    }



    // MARK: The frontispiece

    func testPatronPlateAssetIsDerivedFromTheSlug() {
        let role = BoundReaderRole(
            fullName: "The Maker", signature: "The Maker", gloss: "g", compassLine: "c",
            patronSlug: "orion-blackthorn", patronName: "Orion Blackthorn"
        )
        XCTAssertEqual(role.patronPlateAssetName, "LabyrinthCharacterOrionBlackthorn")
    }

    func testMultiPartSlugsPascalCaseCorrectly() {
        let role = BoundReaderRole(
            fullName: "R", signature: "R", gloss: "g", compassLine: "c",
            patronSlug: "professor-cedric-stonebrook"
        )
        XCTAssertEqual(role.patronPlateAssetName, "LabyrinthCharacterProfessorCedricStonebrook")
    }

    func testARoleWithNoPatronAsksForNoPlate() {
        XCTAssertNil(role(withMark: false).patronPlateAssetName)
    }
}
