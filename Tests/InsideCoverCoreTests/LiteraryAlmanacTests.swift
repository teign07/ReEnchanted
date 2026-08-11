import XCTest
@testable import InsideCoverCore

/// The Book keeps its own saints' days: whose birthday it is, which manuscript
/// somebody once said yes to, the day an Elizabethan tried to get angels to
/// talk to him, and the holidays that exist only because readers made them.
final class LiteraryAlmanacTests: XCTestCase {
    private func date(_ month: Int, _ day: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = month; c.day = day; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    func testTheOccasionsAreWellFormed() {
        XCTAssertGreaterThan(LiteraryAlmanac.occasions.count, 25)
        XCTAssertEqual(Set(LiteraryAlmanac.occasions.map(\.id)).count, LiteraryAlmanac.occasions.count)
        for occasion in LiteraryAlmanac.occasions {
            XCTAssertTrue((1...12).contains(occasion.month), occasion.id)
            XCTAssertTrue((1...31).contains(occasion.day), occasion.id)
            XCTAssertTrue(occasion.kind.isBookish, "\(occasion.id) is not a bookish kind")
            XCTAssertGreaterThan(occasion.blurb.count, 60, "\(occasion.id) blurb is too thin")
            XCTAssertFalse(occasion.invitation.isEmpty, occasion.id)
            XCTAssertGreaterThan(occasion.beliefBonus, 0, occasion.id)
        }
    }

    /// Variety of kind is the defence against a daily festival becoming
    /// wallpaper, so the families have to actually be populated.
    func testEveryBookishFamilyIsRepresented() {
        let kinds = Set(LiteraryAlmanac.occasions.map(\.kind))
        for kind in [CelebrationKind.author, .publication, .occult, .inWorld] {
            XCTAssertTrue(kinds.contains(kind), "no occasions of kind \(kind.rawValue)")
        }
    }

    func testKnownDatesLandOnTheirDay() {
        let expected: [(Int, Int, String)] = [
            (1, 3, "lit-tolkien-born"),
            (9, 21, "lit-hobbit-published"),
            (9, 22, "lit-hobbit-day"),
            (6, 16, "lit-bloomsday"),
            (5, 25, "lit-towel-day"),
            (3, 25, "lit-tolkien-reading-day"),
            (7, 13, "lit-dee-born")
        ]
        for (month, day, id) in expected {
            let ids = LiteraryAlmanac.occasions(on: date(month, day)).map(\.id)
            XCTAssertTrue(ids.contains(id), "\(id) missing on \(month)/\(day); found \(ids)")
        }
    }

    /// They ride the existing Almanac so surfacing, Belief and festival gating
    /// come along for free.
    func testTheyReachTheAlmanacTheRestOfTheAppReads() {
        let bloomsday = Almanac.celebrations(on: date(6, 16))
        XCTAssertTrue(bloomsday.contains { $0.id == "lit-bloomsday" })
        XCTAssertNotNil(Almanac.active(on: date(6, 16)))
    }

    /// A bookish anniversary is warmth, never weather. The grey answers only to
    /// the reader's own record, so an author's birthday must never move it.
    func testABookishDayNeverMovesTheGrey() {
        for occasion in LiteraryAlmanac.occasions {
            let shift = Almanac.greyShift(on: date(occasion.month, occasion.day))
            let astronomical = Almanac.celebrations(on: date(occasion.month, occasion.day))
                .filter { !$0.kind.isBookish }
                .reduce(0) { $0 + $1.greyShift }
            XCTAssertEqual(shift, astronomical, "\(occasion.id) moved the grey")
        }
    }

    /// A solstice outranks an author's birthday.
    func testAstronomicalDaysStillOutrankBookishOnes() {
        for occasion in LiteraryAlmanac.occasions {
            let all = Almanac.celebrations(on: date(occasion.month, occasion.day))
            guard let headline = all.first, all.contains(where: { !$0.kind.isBookish }) else { continue }
            XCTAssertFalse(headline.kind.isBookish, "\(occasion.id) displaced an astronomical celebration")
        }
    }

    /// Some days ask for something rather than only telling the reader a fact.
    func testSomeOccasionsCarrySomethingToDo() {
        let withMechanics = LiteraryAlmanac.occasions.filter { $0.mechanic != nil }
        XCTAssertGreaterThan(withMechanics.count, 4, "almost nothing to do on any of them")
        XCTAssertLessThan(withMechanics.count, LiteraryAlmanac.occasions.count,
                          "every single day asks for something; some should just be told")
    }

    /// These are the Book's own saints' days, so it has to be *in* them. The
    /// first draft read as encyclopedia entries: well-written, but a voice
    /// that could have belonged to anybody. A book keeping other books'
    /// birthdays should sound personally involved.
    func testTheBookIsPresentInItsOwnAlmanac() {
        let blurbs = LiteraryAlmanac.occasions.map(\.blurb)
        let speaks = blurbs.filter { $0.contains("I ") || $0.contains("I'") }
        XCTAssertGreaterThan(
            Double(speaks.count) / Double(blurbs.count), 0.75,
            "the almanac stopped sounding like anybody in particular"
        )
        let contracted = blurbs.filter { blurb in
            ["'s", "n't", "'re", "'ll", "'ve", "'d", "'m"].contains { blurb.contains($0) }
        }
        XCTAssertGreaterThan(Double(contracted.count) / Double(blurbs.count), 0.8)
    }

    /// Never narrating itself in the third person, and never apologising for
    /// its own enthusiasm.
    func testTheAlmanacKeepsTheRegister() {
        for occasion in LiteraryAlmanac.occasions {
            let text = occasion.blurb + " " + occasion.invitation
            XCTAssertFalse(text.contains("The Book"), occasion.id)
            XCTAssertFalse(text.contains("the Book"), occasion.id)
            for hedge in ["I'm sorry", "of course", "don't worry", "if you'd like"] {
                XCTAssertFalse(text.lowercased().contains(hedge.lowercased()), "\(occasion.id): \(hedge)")
            }
        }
    }

    /// Dates the Book cannot stand behind are parked, not guessed at.
    func testUnverifiedCandidatesAreParkedRatherThanShipped() {
        XCTAssertFalse(LiteraryAlmanac.unverifiedCandidates.isEmpty)
        let shipped = Set(LiteraryAlmanac.occasions.map { $0.commonName.lowercased() })
        for candidate in LiteraryAlmanac.unverifiedCandidates {
            XCTAssertFalse(shipped.contains(candidate.lowercased()))
        }
    }
}
