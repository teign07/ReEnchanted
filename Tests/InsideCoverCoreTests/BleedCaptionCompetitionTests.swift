import XCTest
@testable import InsideCoverCore

/// The caption competition: a picture goes up, the Reader enters in the margin,
/// the Cast enter in their own voices, and Penny judges by her house rules.
final class BleedCaptionCompetitionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private let picture = BleedCaptionDesk.Picture(
        id: "tarot:major-12", assetName: "TarotMajor12HangedMan", from: "From Serenity's deck", title: "The Hanged Man",
        description: "Professor Permancer hangs calmly upside down by one ankle loop from a living story-door.")

    private func inputs(_ pages: [BookPage] = []) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [SelfFact(id: "name", questionID: "onboarding-name", question: "Your name?", answer: "Wren",
                                     bookTranslation: "Wren", sensitivity: .identity, usePermission: .quoteAllowed,
                                     tags: ["name"], createdAt: date(1, 9), updatedAt: date(1, 9))]
        inputs.days = pages.map { BookDay(id: BookDay.id(for: $0.createdAt, calendar: calendar),
                                         date: calendar.startOfDay(for: $0.createdAt), pages: [$0]) }
        return inputs
    }

    private func today(_ day: Int) -> BookDay {
        BookDay(id: BookDay.id(for: date(day, 9), calendar: calendar), date: calendar.startOfDay(for: date(day, 9)), pages: [])
    }

    private func ran(_ storyID: String, at: Date) -> BleedPrintRecord {
        BleedPrintRecord(slotID: "slot-\(at.timeIntervalSince1970)", printedAt: at,
                         items: [.init(storyID: storyID, revision: "x", title: "", body: "", sourcePageIDs: [])])
    }

    private func contest(reader: String?) -> BleedCaptionContest {
        BleedCaptionContest(pictureID: picture.id, assetName: picture.assetName, pictureTitle: picture.title,
                            pictureWords: Array(BleedCaptionDesk.contentWords(picture.title + " " + picture.description)).sorted(),
                            readerName: "Wren", readerCaption: reader, entrantIDs: ["wicker-eddies", "pippa-pilcrow", "zara-finch"])
    }

    func testAPictureGoesUpInTheMorningAboutOnceAWeek() throws {
        let now = date(20, 7)
        let column = try XCTUnwrap(BleedCaptionDesk.competition(kind: .morning, inputs: .empty, now: now, calendar: calendar,
                                                                history: [], pool: [picture]))
        XCTAssertTrue(column.composedBody.hasPrefix("PICTURE · TarotMajor12HangedMan\nFrom Serenity's deck: The Hanged Man."), column.composedBody)
        XCTAssertTrue(column.composedBody.contains("margin of this paper"), column.composedBody)
        XCTAssertEqual(BleedPrintDesign.piece(title: column.title, byline: column.byline), .competition)
        XCTAssertNil(BleedCaptionDesk.competition(kind: .evening, inputs: .empty, now: now, calendar: calendar, history: [], pool: [picture]))
        XCTAssertNil(BleedCaptionDesk.competition(kind: .morning, inputs: .empty, now: now, calendar: calendar,
                                                  history: [ran(column.storyID!, at: date(17, 7))], pool: [picture]))
    }

    func testTheMarginOfTheKeptPaperIsTheEntryNotALetter() throws {
        let opened = date(19, 7)
        let kept = BookPage(id: "kept-paper", type: .theBleed, createdAt: date(19, 20), promptText: "The Morning Edition, unfolded.",
                            userInput: "THE BLEED\n\n— Caption Competition —\nthe caption desk\n\nPICTURE · x\n\nMargin note: Permancer, reading the door the right way up.")
        XCTAssertFalse(BleedNewsroom.isCorrespondence(kept))
        let results = try XCTUnwrap(BleedCaptionDesk.results(
            kind: .morning, day: today(20), inputs: inputs([kept]), now: date(20, 7), calendar: calendar,
            history: [ran("caption-competition:\(picture.id)", at: opened)], pool: [picture]))
        XCTAssertEqual(results.caption?.readerCaption, "Permancer, reading the door the right way up.")
        XCTAssertEqual(results.sourcePageIDs, ["kept-paper"])
        XCTAssertTrue(results.needsLocalBrain, "the Cast's captions are the local model's to write")
        XCTAssertTrue(results.fallbackBody?.contains("Wren · “Permancer, reading the door the right way up.”") == true,
                      results.fallbackBody ?? "")
        // Too soon after the picture went up: entries are still open.
        XCTAssertNil(BleedCaptionDesk.results(kind: .evening, day: today(19), inputs: inputs([kept]), now: date(19, 18),
                                              calendar: calendar, history: [ran("caption-competition:\(picture.id)", at: opened)],
                                              pool: [picture]))
    }

    func testPennyJudgesByHerHouseRulesAndTheReadersWordsPrintWhole() {
        let cast = """
        Wicker Eddies: I have no idea who hung him there but it certainly was not me or anybody I know personally
        Pippa Pilcrow: Upside down! Again!
        Zara Finch: The view from here is mostly ceiling.
        """
        let body = BleedCaptionDesk.results(castLines: cast, contest: contest(reader: "The door's idea of a joke."))
        XCTAssertTrue(body.contains("Wren · “The door's idea of a joke.”"), body)
        XCTAssertTrue(body.contains("Winner: Wren."), body)
        XCTAssertTrue(body.contains("Wicker Eddies's was longer than the picture.") || body.contains("Wicker's was longer than the picture."), body)
        XCTAssertTrue(body.contains("used an exclamation mark. It has been confiscated."), body)
        XCTAssertTrue(body.hasPrefix("PICTURE · TarotMajor12HangedMan"), body)
    }

    func testTheReaderCanLoseFairlyAndIsHighlyCommended() {
        let cast = """
        Wicker Eddies: The door started it.
        Pippa Pilcrow: Hanging about again.
        Zara Finch: Permancer, upside down, perfectly calm.
        """
        let long = "I think this is a picture of a man who has decided that the floor is overrated and frankly I agree with him about that"
        let body = BleedCaptionDesk.results(castLines: cast, contest: contest(reader: long))
        XCTAssertFalse(body.contains("Winner: Wren."), body)
        XCTAssertTrue(body.contains("Highly commended: Wren."), body)
    }

    func testWithNoEntryTheCastCompeteAndAMissingCaptionIsStoodInFor() {
        let body = BleedCaptionDesk.results(castLines: "Wicker Eddies: The door started it.", contest: contest(reader: nil))
        XCTAssertTrue(body.contains("No entry from Wren."), body)
        // Pippa and Zara wrote nothing: the house stands in, and every entrant still appears.
        XCTAssertEqual(body.components(separatedBy: "\n").filter { $0.contains(" · “") }.count, 3, body)
    }
}
