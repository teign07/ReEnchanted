import Foundation
import XCTest

@testable import InsideCoverCore

/// What the braid is allowed to call a day the reader was absent for.
///
/// The braid decided that by asking what tonight's *selection* came back with,
/// and selection admitted material by page origin and type. Neither test has
/// anything to do with whether somebody was there. A reader who kept five
/// Book-offered Pages and wrote in the margin of every one of them was told the
/// day happened without either of them, because `.generated` is not the lived
/// shelf and none of the five was an Academy scene.
///
/// These pin the repair from both ends: what must reach the page, and what the
/// page still may not say about it.
final class BraidKeptMaterialTests: XCTestCase {

    // MARK: - What reaches the page

    /// The night that started this. Five Book-offered Pages, five margin notes.
    func testPagesTheReaderWroteInAreNotAClosedDay() {
        let plan = BraidScenePlanBuilder.plan(for: day(marginNotePages()))
        XCTAssertFalse(plan.isQuietDay, plan.summary)
        XCTAssertEqual(plan.placements.count, 5, plan.summary)

        let text = written(plan)
        XCTAssertFalse(text.contains("happened without either of us"), text)
        for fragment in ["phone call", "handwriting", "being early", "parking deck", "bakery"] {
            XCTAssertTrue(text.contains(fragment), "\(fragment) never reached the page\n\(text)")
        }
    }

    /// A day kept in silence is still a day. The quote and the rain are the
    /// whole record, and the Book is expected to make something of them.
    func testThingsKeptWithoutWritingAreEvidence() {
        let plan = BraidScenePlanBuilder.plan(for: day([quotePage(), weatherPage()]))
        XCTAssertFalse(plan.isQuietDay, plan.summary)
        XCTAssertEqual(plan.evidence.count, 2, plan.summary)
        XCTAssertTrue(plan.evidence.allSatisfy { $0.kind == .keptThing }, plan.summary)
    }

    /// The pairing the whole widening was for: two kept things that share a
    /// word, noticed, with no verdict attached.
    func testTwoKeptThingsMayBeDrawnTogether() {
        let plan = BraidScenePlanBuilder.plan(for: day([quotePage(), weatherPage()]))
        guard let relation = plan.relations.first else { return XCTFail(plan.summary) }
        XCTAssertEqual(relation.kind, .sharedThing)
        XCTAssertEqual(relation.pivot, "rain")

        let line = BraidSceneWriter.write(plan).first { $0.realm == .book }
        guard let line else { return XCTFail("no line drawn\n\(plan.summary)") }
        XCTAssertTrue(line.text.contains("rain"), line.text)
        XCTAssertFalse(BraidDraftVerifier.declaresMeaning(line.text), line.text)
    }

    /// Supporting logs lost their seat by being ranked, never by being barred.
    /// A souvenir still outranks the weather when the night has room for one.
    func testGravityOrdersRatherThanExcludes() {
        let souvenir = BookPage(
            id: "souvenir", type: .souvenir, createdAt: date("2026-10-02T21:00:00Z"),
            promptText: "One true sentence.",
            userInput: "I sat on the step until the street lights came on.",
            origin: .userAuthored)
        let plan = BraidScenePlanBuilder.plan(for: day([weatherPage(), souvenir]))
        XCTAssertEqual(plan.anchorEvidenceID, plan.evidence.first { $0.pageID == "souvenir" }?.id,
                       plan.summary)
        XCTAssertTrue(plan.placements.contains { $0.evidenceID.hasPrefix("weather") }, plan.summary)
    }

    // MARK: - What the page still may not say

    /// The reason a kept thing is not a lived atom. Rumi's sentence is not the
    /// reader's sentence, and the second-person turn would hand it to them as
    /// though it were.
    func testAKeptQuotationIsNeverTurnedToFaceTheReader() {
        let plan = BraidScenePlanBuilder.plan(for: day([quotePage(), weatherPage()]))
        guard let atom = plan.evidence.first(where: { $0.pageID == "quote" }) else {
            return XCTFail(plan.summary)
        }
        XCTAssertFalse(atom.isAboutTheReadersLife)
        let claims = BraidSceneWriter.write(plan)
        let quoted = claims.first { $0.sourceIDs == [atom.id] }
        XCTAssertEqual(quoted?.realm, .kept)
        XCTAssertEqual(quoted?.text, atom.text, "a kept quotation was rewritten")
        XCTAssertFalse(claims.contains { $0.realm == .lived && $0.sourceIDs.contains(atom.id) })
    }

    /// The realms are not interchangeable, and the verifier is where that is
    /// enforced rather than hoped for.
    func testARendererMayNotFileKeptMaterialAsLived() {
        let plan = BraidScenePlanBuilder.plan(for: day([quotePage(), weatherPage()]))
        guard let atom = plan.evidence.first(where: { $0.pageID == "quote" }) else {
            return XCTFail(plan.summary)
        }
        assertRejected(
            "lived:\(atom.id) You wrote about a wound the rain gets into.",
            plan: plan, as: .wrongRealm)
    }

    /// And the other way: the reader's own line is theirs, and may not be
    /// demoted to something that merely passed through.
    func testARendererMayNotFileTheReadersOwnLineAsKept() {
        let plan = BraidScenePlanBuilder.plan(for: day(marginNotePages()))
        guard let atom = plan.evidence.first(where: { $0.kind == .writtenLine }) else {
            return XCTFail(plan.summary)
        }
        assertRejected("kept:\(atom.id) \(atom.text)", plan: plan, as: .wrongRealm)
    }

    /// A kept thing may be named. It may not be explained.
    func testAKeptClaimMayNotRuleOnWhyItWasKept() {
        let plan = BraidScenePlanBuilder.plan(for: day([quotePage(), weatherPage()]))
        guard let atom = plan.evidence.first(where: { $0.pageID == "quote" }) else {
            return XCTFail(plan.summary)
        }
        assertRejected(
            "kept:\(atom.id) You kept this because the real story is that you are hurting.",
            plan: plan, as: .claimedTheReadersLife)
    }

    // MARK: - The backstop, and its limit

    /// The bug class, closed. Whatever selection decides, a day the reader put
    /// their hand on is not a day they were absent for.
    func testAnyKeptMaterialAtAllDefeatsTheClosedDay() {
        // `welcome` and `helpTips` are the Book's furniture and never weave.
        // `bookOfYou` is the braid itself, which `capturedPages` excludes: last
        // night's page is not evidence for tonight's.
        let notEvidence: Set<BookPageType> = [.welcome, .helpTips, .bookOfYou]
        for type in BookPageType.allCases where !notEvidence.contains(type) {
            for origin in [BookPageOrigin.generated, .simulated, .userAuthored, .imported] {
                let page = BookPage(
                    id: "p", type: type, createdAt: date("2026-10-02T09:00:00Z"),
                    promptText: "The Book asked something.",
                    userInput: "The Book's prose.\n\nMargin note: I walked the long way home.",
                    origin: origin)
                let plan = BraidScenePlanBuilder.plan(for: day([page]))
                XCTAssertFalse(
                    plan.isQuietDay,
                    "\(type.rawValue)/\(origin.rawValue) was read as a day the reader kept nothing")
            }
        }
    }

    /// The correction has a floor. A day nobody opened the Book is still a
    /// closed day, and the Book still gets its page for it - the repair must
    /// not have quietly deleted the quiet day.
    func testADayTheReaderKeptNothingIsStillAClosedDay() {
        let plan = BraidScenePlanBuilder.plan(for: day([]))
        XCTAssertTrue(plan.isQuietDay, plan.summary)
        XCTAssertFalse(plan.quietDayBeats.isEmpty, plan.summary)
    }

    // MARK: - Grammar

    /// The reader's own sentence, turned to face them, still has to be English.
    func testTheSecondPersonTurnKeepsVerbAgreement() {
        XCTAssertEqual(
            BraidSceneWriter.secondPerson("I was avoiding the phone call."),
            "You were avoiding the phone call.")
        XCTAssertEqual(
            BraidSceneWriter.secondPerson("I am tired and my hands are cold."),
            "You are tired and your hands are cold.")
        // "was" only moves when it is the pronoun's own verb.
        XCTAssertEqual(
            BraidSceneWriter.secondPerson("My father was quiet."),
            "Your father was quiet.")
    }

    // MARK: - Fixtures

    private func marginNotePages() -> [BookPage] {
        [
            ("p1", BookPageType.askTheBook, 9, "I was avoiding the phone call."),
            ("p2", .note, 11, "Wrote three lines about my father's handwriting."),
            ("p3", .affirmations, 14, "I countersigned the one about being early."),
            ("p4", .todaysSky, 18, "Watched the light go orange over the parking deck."),
            ("p5", .location, 20, "Walked the long way home past the shuttered bakery.")
        ].map { id, type, hour, note in
            BookPage(
                id: id, type: type,
                createdAt: date("2026-10-02T\(String(format: "%02d", hour)):00:00Z"),
                promptText: "The Book asked something.",
                userInput: "The Book's own prose for this Page.\n\nMargin note: \(note)",
                origin: .generated)
        }
    }

    private func quotePage() -> BookPage {
        BookPage(
            id: "quote", type: .quotes, createdAt: date("2026-10-02T10:00:00Z"),
            promptText: "A quote card.",
            userInput: "The wound is the place where the rain enters you.",
            sourceID: "quotes-page", origin: .imported)
    }

    private func weatherPage() -> BookPage {
        BookPage(
            id: "weather", type: .weather, createdAt: date("2026-10-02T08:00:00Z"),
            promptText: "Today's weather.",
            userInput: "Heavy rain all morning, wind off the river.",
            sourceID: "weather-page", origin: .imported)
    }

    private func written(_ plan: BraidScenePlan) -> String {
        BraidSceneWriter.write(plan).map(\.text).joined(separator: "\n")
    }

    private func assertRejected(
        _ draft: String,
        plan: BraidScenePlan,
        as expected: BraidDraftRejection,
        line: UInt = #line
    ) {
        switch BraidDraftVerifier.verify(draft + "\nCOLOPHON The Book kept the page.", against: plan) {
        case .success:
            XCTFail("draft was accepted: \(draft)", line: line)
        case .failure(let rejection):
            XCTAssertEqual(rejection, expected, draft, line: line)
        }
    }

    private func day(_ pages: [BookPage]) -> BookDay {
        BookDay(id: "2026-10-02", date: date("2026-10-02T21:30:00Z"), pages: pages)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
