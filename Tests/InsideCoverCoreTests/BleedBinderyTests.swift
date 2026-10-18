import XCTest
@testable import InsideCoverCore

final class BleedBinderyTests: XCTestCase {
    private let morning = Date(timeIntervalSince1970: 1_792_321_200)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private var day: BookDay { BookDay(id: "2026-10-18", date: morning, pages: []) }

    private func page(_ id: String, kind: BleedEditionKind, at date: Date) -> BookPage {
        BookPage(
            id: id, type: .theBleed, createdAt: date, promptText: kind.mastheadTitle,
            userInput: "The printed paper: \(id)",
            tags: ["bleed-2026-10-18-\(kind.rawValue)", "bleed:\(kind.rawValue)"]
        )
    }

    private func prepared(kind: BleedEditionKind, body: String) throws -> SurfacePage {
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day, inputs: .empty, now: morning, calendar: calendar, settingTheType: false
        )).withMetadata([
            "bleedSlotID": "bleed-2026-10-18-\(kind.rawValue)",
            "bleedEditionKind": kind.rawValue
        ])
        return TheBleedEditionBuilder.preparedCopy(
            of: announcement, body: body, interestSources: "", printedAt: morning.addingTimeInterval(3600)
        )
    }

    func testShelfIncludesOlderPapersAndKeepsMorningAndEveningSeparate() {
        var older = day
        older.id = "2026-10-17"
        older.pages = [BookPage(id: "older", type: .theBleed, createdAt: morning.addingTimeInterval(-86400),
                               promptText: "The Bleed", userInput: "Yesterday's paper")]
        var today = day
        today.pages = [page("morning", kind: .morning, at: morning),
                       page("evening", kind: .evening, at: morning.addingTimeInterval(36000)),
                       BookPage(type: .souvenir, promptText: "A kept leaf", userInput: "Not a paper")]
        let shelf = BleedBinderyEdition.shelf(days: [older, today], prepared: nil)
        XCTAssertEqual(shelf.map(\.keptPageID), ["evening", "morning", "older"])
        XCTAssertEqual(shelf.prefix(2).map(\.kind), [.evening, .morning])
    }

    func testKeptSlotWinsOverRefreshedLiveTray() throws {
        var today = day
        today.pages = [page("kept", kind: .morning, at: morning)]
        let live = try prepared(kind: .morning, body: "A refreshed live paper")
        let shelf = BleedBinderyEdition.shelf(days: [today], prepared: live)
        XCTAssertEqual(shelf.count, 1)
        XCTAssertEqual(shelf.first?.body, "The printed paper: kept")
        XCTAssertEqual(shelf.first?.keptPageID, "kept")
    }

    func testNewEveningTraySitsAboveKeptMorning() throws {
        var today = day
        today.pages = [page("kept", kind: .morning, at: morning)]
        let live = try prepared(kind: .evening, body: "The evening paper")
        let shelf = BleedBinderyEdition.shelf(days: [today], prepared: live)
        XCTAssertEqual(shelf.map(\.kind), [.evening, .morning])
        XCTAssertNil(shelf.first?.keptPageID)
    }

    func testAnnouncementAndEmptyKeptPageAreNotFinishedEditions() throws {
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day, inputs: .empty, now: morning, calendar: calendar, settingTheType: false
        ))
        var today = day
        var unprinted = page("announcement", kind: .morning, at: morning)
        unprinted.metadata = announcement.payload.metadata
        today.pages = [BookPage(type: .theBleed, promptText: "The Bleed", userInput: "  \n "), unprinted]
        XCTAssertTrue(BleedBinderyEdition.shelf(days: [today], prepared: announcement).isEmpty)
    }

    func testStoredPressProseAndPlatesSurviveTheShelfProjection() throws {
        var kept = page("kept", kind: .evening, at: morning)
        kept.userInput += "\nA later reader note"
        kept.metadata = ["bleedProse": "The exact paper"]
        kept.mediaAssets = [BookPageMediaAsset(id: "plate", kind: .bundledImage, reference: "TheBleedBanner")]
        var today = day
        today.pages = [kept]
        let edition = try XCTUnwrap(BleedBinderyEdition.shelf(days: [today], prepared: nil).first)
        XCTAssertEqual(edition.body, "The exact paper")
        XCTAssertEqual(edition.mediaAssets, kept.mediaAssets)
        XCTAssertEqual(edition.kind, .evening)
    }

    func testPDFRevisionChangesWithTextOrPlates() throws {
        let live = try prepared(kind: .morning, body: "The first paper")
        let edition = try XCTUnwrap(BleedBinderyEdition.shelf(days: [day], prepared: live).first)
        var revised = edition
        revised.body = "A refreshed appointment strip"
        XCTAssertNotEqual(edition.revisionID, revised.revisionID)
        revised = edition
        revised.mediaAssets = [BookPageMediaAsset(id: "plate", kind: .bundledImage, reference: "TheBleedBanner")]
        XCTAssertNotEqual(edition.revisionID, revised.revisionID)
        XCTAssertEqual(edition.revisionID, edition.revisionID)
    }

    func testAPaperNobodyKeptStaysOnTheShelfAsPrintedForAWeek() throws {
        let live = try prepared(kind: .morning, body: "The paper as printed")
            .withMetadata(["bleedBriefs": "a large setting tray"])
        let paper = try XCTUnwrap(BleedPrintedPaper(live))
        XCTAssertNil(paper.surface.payload.metadata["bleedBriefs"])
        XCTAssertEqual(paper.surface.payload.metadata["bleedProse"], "The paper as printed")
        // A refreshed copy replaces its own slot; a paper older than a week leaves the shelf.
        var papers = BleedPrintedPaper.remembering(paper, in: [], now: morning)
        papers = BleedPrintedPaper.remembering(paper, in: papers, now: morning)
        XCTAssertEqual(papers.count, 1)
        XCTAssertTrue(BleedPrintedPaper.remembering(paper, in: [], now: morning.addingTimeInterval(8 * 86400)).isEmpty)
        // On the shelf without being kept, and the kept copy still wins its slot.
        let shelf = BleedBinderyEdition.shelf(days: [day], prepared: nil, printed: papers)
        XCTAssertEqual(shelf.map(\.body), ["The paper as printed"])
        XCTAssertNil(shelf.first?.keptPageID)
        var today = day
        today.pages = [page("kept", kind: .morning, at: morning)]
        XCTAssertEqual(BleedBinderyEdition.shelf(days: [today], prepared: nil, printed: papers).map(\.keptPageID), ["kept"])
    }
}
