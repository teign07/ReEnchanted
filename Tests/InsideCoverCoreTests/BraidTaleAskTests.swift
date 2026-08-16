import Foundation
import XCTest

@testable import InsideCoverCore

/// The Book asking about a shape it thinks it sees.
///
/// Every test here is really the same test: the ask is rare, it is never an
/// announcement, and saying no must cost the reader nothing.
final class BraidTaleAskTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func tale(
        readerLines: Int = 2,
        openedDaysAgo: Int = 30,
        closed: Bool = false
    ) -> LivingTale {
        let now = date("2026-10-01T21:00:00Z")
        let opened = now.addingTimeInterval(-Double(openedDaysAgo) * 86_400)
        let witnesses = (0..<readerLines).map { index in
            TaleWitness(
                id: "w\(index)",
                beat: index == 0 ? .lack : .crossing,
                receiptID: "p\(index)",
                receiptKind: "reader-page",
                evidence: "I closed the door on the spare room again, number \(index).",
                witnessedAt: opened.addingTimeInterval(Double(index) * 86_400),
                tags: ["threshold"]
            )
        }
        return LivingTale(
            id: "tale-1",
            shape: .forbiddenDoor,
            title: "The Door You Said You Would Not Open",
            witnesses: witnesses,
            openedAt: opened,
            lastWitnessedAt: now,
            closedAt: closed ? now : nil
        )
    }

    private func ask(
        _ tale: LivingTale?,
        lastAskedAt: Date? = nil,
        asked: Set<String> = [],
        shadow: Bool = false
    ) -> BraidTaleAsk.Ask? {
        BraidTaleAsk.ask(
            for: tale,
            lastAskedAt: lastAskedAt,
            alreadyAskedTaleIDs: asked,
            carriesShadow: shadow,
            now: date("2026-10-01T21:00:00Z"),
            calendar: calendar
        )
    }

    func testAMatureTaleWithTheReadersOwnLinesMayBeAskedAbout() {
        XCTAssertNotNil(ask(tale()))
    }

    /// The whole design decision: recognise, lean, and ask - never announce.
    func testTheQuestionNeverNamesTheShapeOrTheTale() {
        guard let subject = ask(tale()) else { return XCTFail("expected an ask") }
        XCTAssertFalse(subject.question.contains("Forbidden Door"))
        XCTAssertFalse(subject.question.lowercased().contains("forbidden"))
        XCTAssertFalse(subject.question.contains("The Door You Said You Would Not Open"))
        XCTAssertFalse(subject.question.lowercased().contains("story"))
        XCTAssertFalse(subject.question.lowercased().contains("pattern in your life"))
    }

    /// Refusing has to be a real option, offered in the Book's own doubt.
    func testTheQuestionOffersItsOwnDoubtAndAWayToSayNo() {
        guard let subject = ask(tale()) else { return XCTFail("expected an ask") }
        XCTAssertTrue(subject.question.contains("making a shape out of too little"))
        XCTAssertFalse(subject.refuse.isEmpty)
    }

    /// House law 3: no naked quantities in reader-visible text.
    func testTheQuestionCountsNothingOutLoud() {
        guard let subject = ask(tale()) else { return XCTFail("expected an ask") }
        for naked in ["2", "3", "twice", "Twice", "three times"] {
            XCTAssertFalse(subject.question.contains(naked), naked)
        }
    }

    func testAYoungTaleIsNotAskedAbout() {
        XCTAssertNil(ask(tale(openedDaysAgo: 3)))
    }

    /// A shape assembled entirely from the Book's own pages is the Book asking
    /// about itself.
    func testATaleTheReaderHasNotWrittenInsideIsNotAskedAbout() {
        XCTAssertNil(ask(tale(readerLines: 1)))
    }

    func testAClosedTaleIsNotAskedAbout() {
        XCTAssertNil(ask(tale(closed: true)))
    }

    func testATaleIsNeverAskedAboutTwice() {
        XCTAssertNil(ask(tale(), asked: ["tale-1"]))
    }

    func testAsksRestBetweenEachOther() {
        let recent = date("2026-09-25T21:00:00Z")
        XCTAssertNil(ask(tale(), lastAskedAt: recent))
        let old = date("2026-08-20T21:00:00Z")
        XCTAssertNotNil(ask(tale(), lastAskedAt: old))
    }

    /// A reader writing about something hard is not being invited to discuss
    /// narrative structure.
    func testTheBookNeverAsksOnANightHoldingShadow() {
        XCTAssertNil(ask(tale(), shadow: true))
    }

    func testAConfirmationBecomesAWitnessInTheReadersOwnHand() {
        let subject = tale()
        let updated = BraidTaleAsk.applying(.keepsHappening, to: subject, now: date("2026-10-01T21:00:00Z"))
        XCTAssertEqual(updated.witnesses.count, subject.witnesses.count + 1)
        XCTAssertTrue(updated.isOpen)
        XCTAssertTrue(updated.witnesses.last?.tags.contains("reader-confirmed") ?? false)
    }

    /// Saying no must actually stop it. Leaning toward a shape the reader has
    /// denied is the presumption the ask exists to avoid.
    func testARefusalClosesTheTaleRatherThanPausingIt() {
        let updated = BraidTaleAsk.applying(.joiningDots, to: tale(), now: date("2026-10-01T21:00:00Z"))
        XCTAssertFalse(updated.isOpen)
        XCTAssertEqual(updated.ending, .abandoned)
    }

    /// A reader line containing the Book's own quotation marks must not be able
    /// to close the quote early.
    func testAReaderLineCannotBreakOutOfTheQuotation() {
        var subject = tale()
        subject.witnesses[1].evidence = "I wrote \u{00AB}enough\u{00BB} and meant it."
        guard let result = ask(subject) else { return XCTFail("expected an ask") }
        XCTAssertEqual(result.question.components(separatedBy: "\u{00AB}").count - 1, 1)
        XCTAssertEqual(result.question.components(separatedBy: "\u{00BB}").count - 1, 1)
    }

    /// The refusal has to survive the rest window. Closing one tale is not
    /// enough: the same receipts recognise the same shape again under a new
    /// id, and the Book would be leaning on something it was told was wrong.
    func testARefusedShapeDoesNotComeBackUnderANewID() {
        let subject = tale()
        // `recognize` wants four witnesses across three days, and a signature
        // tag: "closed-door" and "refusal" are the Forbidden Door's.
        let witnesses = subject.witnesses.map { witness -> TaleWitness in
            var witness = witness
            witness.tags = ["closed-door"]
            return witness
        } + [
            TaleWitness(
                id: "w-extra", beat: .donor, receiptID: "p-extra", receiptKind: "reader-page",
                evidence: "Someone offered to help me clear it and I said no.",
                witnessedAt: date("2026-09-20T21:00:00Z"), tags: ["refusal"]),
            TaleWitness(
                id: "w-extra-2", beat: .price, receiptID: "p-extra-2", receiptKind: "reader-page",
                evidence: "The room costs me something every time I walk past it.",
                witnessedAt: date("2026-09-22T21:00:00Z"), tags: ["closed-door"])
        ]
        let long = date("2027-06-01T21:00:00Z")

        let reopened = TaleGrammar.tend(
            current: nil, witnesses: witnesses, lastClosedAt: nil,
            now: long, calendar: calendar)
        XCTAssertNotNil(reopened.opened, "precondition: these receipts do recognise a shape")

        let barred = TaleGrammar.tend(
            current: nil, witnesses: witnesses, lastClosedAt: nil,
            refusedShapes: [reopened.opened!.shape],
            now: long, calendar: calendar)
        XCTAssertNil(barred.opened, "a denied shape came back under a new id")
    }
}
