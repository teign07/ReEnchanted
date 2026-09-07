import XCTest
@testable import InsideCoverCore

/// What the Book says about the file, and — more to the point — what it refuses
/// to say. Every rule here is a rule about not overclaiming.
final class BestiaryNoticingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    /// 2026-08-29.
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func daysAgo(_ count: Int, hour: Int = 14) -> Date {
        let day = calendar.date(byAdding: .day, value: -count, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func page(
        _ id: String,
        _ creatures: [String],
        daysAgo ago: Int,
        hour: Int = 14,
        words: String = "",
        tags: [String] = []
    ) -> BookPage {
        let when = daysAgo(ago, hour: hour)
        return BookPage(
            id: id, type: .enchantment, createdAt: when, promptText: "", userInput: words,
            tags: tags,
            context: BookPageContextSnapshot(at: when, calendar: calendar),
            creatureSightings: creatures.map { CreatureSighting(creature: $0, certainty: .clear) }
        )
    }

    /// A Page carrying no sightings at all — the shape a Book Notice the Book
    /// itself wrote takes when it lands back in the archive.
    private func spokenPage(_ id: String, tags: [String], daysAgo ago: Int) -> BookPage {
        BookPage(
            id: id, type: .bookNotices, createdAt: daysAgo(ago), promptText: "",
            userInput: "", tags: tags, sourceID: BestiaryPageSourceAdapter.sourceID
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        pages.map { BookDay(id: "d-\($0.id)", date: $0.createdAt, pages: [$0]) }
    }

    /// Several creatures on one calendar day, which is what the company
    /// noticing actually reads.
    private func day(_ id: String, _ pages: [BookPage]) -> BookDay {
        BookDay(id: id, date: pages.first?.createdAt ?? now, pages: pages)
    }

    // MARK: Nothing to say

    func testAnEmptyArchiveSaysNothing() {
        XCTAssertNil(Bestiary.notice(days: [], now: now, calendar: calendar))
    }

    /// Asking somebody who has never photographed an animal to go and find one
    /// is a stranger asking a favour. The file has to exist before its gaps do.
    func testTheBookDoesNotSendYouOutBeforeItHasAFile() {
        let notice = Bestiary.notice(
            days: days([page("a", ["fox"], daysAgo: 200)]), now: now, calendar: calendar
        )
        XCTAssertNotEqual(notice?.kind, .commission)
    }

    // MARK: The first of its kind

    func testANewCreatureOpensAFolder() {
        let notice = Bestiary.notice(
            days: days([page("a", ["heron"], daysAgo: 1)]), now: now, calendar: calendar
        )
        XCTAssertEqual(notice?.kind, .firstOfItsKind)
        XCTAssertEqual(notice?.creature, "heron")
        XCTAssertTrue(notice?.headline.contains("heron") == true)
    }

    /// The first sighting of something is only news for a few days. After that
    /// it's just a line in a list.
    func testAFirstSightingGoesStaleRatherThanWaiting() {
        let notice = Bestiary.notice(
            days: days([page("a", ["heron"], daysAgo: 40)]), now: now, calendar: calendar
        )
        XCTAssertNotEqual(notice?.kind, .firstOfItsKind)
    }

    /// The record of what has been said IS the archive. A Page the Book already
    /// wrote carries the tag that stops it saying the same thing twice.
    func testTheBookDoesNotOpenTheSameFolderTwice() {
        let notice = Bestiary.notice(days: days([
            page("a", ["heron"], daysAgo: 1),
            spokenPage("said", tags: ["bestiary", "bestiary-firstOfItsKind:heron"], daysAgo: 0)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .firstOfItsKind)
    }

    // MARK: The return

    func testSomethingBackAfterALongGapIsARETurn() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 300),
            page("b", ["fox"], daysAgo: 1)
        ]), now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .theReturn)
        XCTAssertTrue(notice?.detail.contains("months") == true, "got: \(notice?.detail ?? "nil")")
    }

    /// Three weeks is not an absence. A creature you see most months coming
    /// back is not a thing that needs saying out loud.
    func testAShortGapIsNotAReturn() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 21),
            page("b", ["fox"], daysAgo: 1)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .theReturn)
    }

    // MARK: Gone quiet

    /// The one that reads like the place noticings. A creature dropping out of
    /// the record is the reader's world getting smaller.
    func testSomethingThatStoppedTurningUpIsRaised() {
        let notice = Bestiary.notice(days: days([
            page("a", ["crow"], daysAgo: 300),
            page("b", ["crow"], daysAgo: 280),
            page("c", ["crow"], daysAgo: 260)
        ]), now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .goneQuiet)
        XCTAssertTrue(notice?.headline.contains("crows") == true, "got: \(notice?.headline ?? "nil")")
    }

    /// Twice is not a habit, so its absence is not a loss. The Book would be
    /// inventing a routine in order to mourn it.
    func testTwoSightingsIsNotAHabitToLose() {
        let notice = Bestiary.notice(days: days([
            page("a", ["crow"], daysAgo: 300),
            page("b", ["crow"], daysAgo: 280)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .goneQuiet)
    }

    // MARK: The company

    /// One-directional on purpose. "Never a crow without a dog" is supportable
    /// from the record; the reverse needs its own evidence and might be false.
    func testTwoCreaturesThatNeverArriveApart() {
        let notice = Bestiary.notice(days: [
            day("d1", [page("a", ["crow"], daysAgo: 40), page("b", ["dog"], daysAgo: 40)]),
            day("d2", [page("c", ["crow"], daysAgo: 30), page("d", ["dog"], daysAgo: 30)]),
            day("d3", [page("e", ["crow"], daysAgo: 20), page("f", ["dog"], daysAgo: 20)]),
            day("d4", [page("g", ["dog"], daysAgo: 10)])
        ], now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .theCompany)
        XCTAssertEqual(notice?.creature, "crow", "the claim runs from the rarer one to the commoner one")
        XCTAssertTrue(notice?.headline.contains("without a dog") == true, "got: \(notice?.headline ?? "nil")")
    }

    func testACreatureSeenOnceIsNotKeepingCompany() {
        let notice = Bestiary.notice(days: [
            day("d1", [page("a", ["crow"], daysAgo: 40), page("b", ["dog"], daysAgo: 40)]),
            day("d2", [page("c", ["dog"], daysAgo: 30)])
        ], now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .theCompany)
    }

    func testOneDayApartBreaksTheClaim() {
        let notice = Bestiary.notice(days: [
            day("d1", [page("a", ["crow"], daysAgo: 40), page("b", ["dog"], daysAgo: 40)]),
            day("d2", [page("c", ["crow"], daysAgo: 30), page("d", ["dog"], daysAgo: 30)]),
            day("d3", [page("e", ["crow"], daysAgo: 20)])
        ], now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .theCompany)
    }

    // MARK: The lore

    func testMeetingAnAnimalUnlocksWhatPeopleSayAboutIt() {
        let notice = Bestiary.notice(days: days([
            page("a", ["magpie"], daysAgo: 200, words: "Just the one, on the fence."),
            page("b", ["magpie"], daysAgo: 100)
        ]), now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .theLore)
        XCTAssertEqual(notice?.loreID, "creature-magpie")
        XCTAssertTrue(notice?.headline.contains("one for sorrow") == true, "the sense is the headline")
        XCTAssertTrue(notice?.body.contains("One for sorrow, two for joy") == true, "the rhyme itself is the payload")
    }

    /// The reader's own sentence next to four hundred years of somebody else's
    /// is the whole point of the shelf.
    func testTheReadersOwnWordsGoNextToTheLore() {
        let notice = Bestiary.notice(days: days([
            page("a", ["magpie"], daysAgo: 200, words: "Just the one, on the fence.")
        ]), now: now, calendar: calendar)
        XCTAssertTrue(
            notice?.body.contains("Just the one, on the fence.") == true,
            "got: \(notice?.body ?? "nil")"
        )
    }

    /// Lore is only unlocked, never shipped. A creature the reader has never
    /// photographed has no page waiting for them.
    func testLoreOnlyExistsForCreaturesYouHaveActuallyMet() {
        XCTAssertNotNil(CreatureLore.lore(for: "magpie"))
        XCTAssertTrue(CreatureLore.rows(for: ["fox"]).map(\.id) == ["creature-fox"])
        XCTAssertTrue(CreatureLore.rows(for: []).isEmpty)
    }

    func testACreatureWithNoLoreSimplyHasNone() {
        XCTAssertNil(CreatureLore.lore(for: "woodlouse"))
    }

    // MARK: The commission

    func testAGapInTheFileBecomesAnErrand() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["deer"], daysAgo: 190),
            page("c", ["squirrel"], daysAgo: 180)
        ]), now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .commission)
        XCTAssertEqual(notice?.group, .wings, "three four-legged things and nothing that flies")
    }

    /// The order the Book asks in is the order the errands are easy in. Wings
    /// first: findable on any walk. Water last: needs somewhere specific.
    func testTheEasiestErrandIsAskedForFirst() {
        XCTAssertEqual(CreatureGroup.allCases.first, .wings)
        XCTAssertEqual(CreatureGroup.allCases.last, .water)
    }

    /// A group the reader already has something from is not a gap.
    func testAGroupYouAlreadyHaveIsNotAGap() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["crow"], daysAgo: 190),
            page("c", ["bee"], daysAgo: 180),
            page("d", ["frog"], daysAgo: 170)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .commission, "every group is covered, so there is nothing to ask for")
        XCTAssertEqual(notice?.kind, .theLore, "with no errand owed, the lore underneath it speaks")
    }

    // MARK: The errand comes back

    /// The Book committed to an errand in advance, so the result outranks
    /// everything it might have thought of on its own.
    func testBringingBackWhatWasAskedForOutranksEverything() {
        let asked = spokenPage("ask", tags: ["bestiary", "bestiary-commission:wings"], daysAgo: 10)
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["deer"], daysAgo: 190),
            page("c", ["squirrel"], daysAgo: 180),
            asked,
            // Also a first-of-its-kind, which would normally win.
            page("d", ["heron"], daysAgo: 2, words: "Down by the water, not moving.")
        ]), now: now, calendar: calendar)
        XCTAssertEqual(notice?.kind, .brought)
        XCTAssertEqual(notice?.creature, "heron")
        XCTAssertEqual(notice?.group, .wings)
        XCTAssertTrue(notice?.body.contains("Down by the water") == true, "their words come back to them")
    }

    /// Keeping the card is how the errand is taken on. A commission the reader
    /// never kept never happened, so nothing can settle it.
    func testAnErrandTheReaderNeverKeptCannotBeSettled() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["deer"], daysAgo: 190),
            page("c", ["squirrel"], daysAgo: 180),
            page("d", ["heron"], daysAgo: 2)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .brought)
    }

    /// Something filed before the ask doesn't count. The errand is a thing the
    /// reader goes and does, not a search of their back catalogue.
    func testACreatureAlreadyOnFileDoesNotSettleTheErrand() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["heron"], daysAgo: 190),
            page("c", ["squirrel"], daysAgo: 180),
            spokenPage("ask", tags: ["bestiary", "bestiary-commission:wings"], daysAgo: 10)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .brought)
    }

    func testAnErrandIsOnlySettledOnce() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["deer"], daysAgo: 190),
            page("c", ["squirrel"], daysAgo: 180),
            spokenPage("ask", tags: ["bestiary", "bestiary-commission:wings"], daysAgo: 10),
            page("d", ["heron"], daysAgo: 5),
            spokenPage("paid", tags: ["bestiary", "bestiary-brought:wings"], daysAgo: 4)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .brought)
    }

    func testTheBookDoesNotAskForTheSameShapeTwice() {
        let notice = Bestiary.notice(days: days([
            page("a", ["fox"], daysAgo: 200),
            page("b", ["deer"], daysAgo: 190),
            page("c", ["squirrel"], daysAgo: 180),
            spokenPage("ask", tags: ["bestiary", "bestiary-commission:wings"], daysAgo: 100),
            spokenPage("paid", tags: ["bestiary", "bestiary-brought:wings"], daysAgo: 90)
        ]), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.group, .wings)
    }

    // MARK: The vocabulary holds together

    /// A group naming a label the filing system doesn't know would be an errand
    /// that can never be completed.
    func testEveryGroupMemberIsSomethingTheBookCanActuallyFile() {
        for group in CreatureGroup.allCases {
            for member in group.members {
                XCTAssertNotNil(
                    Bestiary.creature(for: member),
                    "\(group.rawValue) asks for \(member), which nothing can ever file"
                )
            }
        }
    }

    /// A group nothing belongs to is an errand nobody can run.
    func testNoGroupIsEmpty() {
        for group in CreatureGroup.allCases {
            XCTAssertGreaterThanOrEqual(group.members.count, 10, group.rawValue)
        }
    }

    /// The test that matters most about the errand, and the one I only knew to
    /// write after reading Apple's real taxonomy.
    ///
    /// A commission is the Book sending somebody outside on the promise that it
    /// will recognise what they come back with. If a group's members are all
    /// things Vision cannot name, that promise is a lie and the errand can
    /// never be closed. Twelve is a floor, not a target: it wants the reader to
    /// have a real chance of walking into one, not a technicality.
    func testEveryErrandCanActuallyBeCompleted() {
        for group in CreatureGroup.allCases {
            let reachable = group.members.filter(Bestiary.namedByAppleVision.contains)
            XCTAssertGreaterThanOrEqual(
                reachable.count, 12,
                "\(group.rawValue) has \(reachable.count) members Vision can name. " +
                "The Book would be asking for something it can't see."
            )
        }
    }

    /// The commonest photograph in the whole feature. Apple has no label for a
    /// crow, so a crow comes back "bird" — and "bird" has to be filable or the
    /// most likely sighting in the app files nothing at all.
    func testTheAnswerForABirdItCannotNameIsStillABird() {
        XCTAssertTrue(Bestiary.namedByAppleVision.contains("bird"))
        XCTAssertEqual(Bestiary.creature(for: "bird"), "bird")
        XCTAssertNotNil(CreatureLore.lore(for: "bird"), "the unnamed-bird page has to exist")
    }

    /// One raven is one creature. The classifier hands up the specific name and
    /// the group name together, and filing both would put two animals on the
    /// shelf for one photograph.
    func testAGroupNameIsDroppedWhenSomethingUnderItWasFiled() {
        let packet = VisualFactPacket(facts: [
            VisualFact(kind: .setting, label: "bird", confidence: 0.9, source: .appleVisionClassifier),
            VisualFact(kind: .setting, label: "raven", confidence: 0.8, source: .appleVisionClassifier)
        ])
        XCTAssertEqual(Bestiary.sightings(in: packet).map(\.creature), ["raven"])
    }

    /// Three rungs at once still leaves one animal.
    func testTheWholeLadderCollapsesToItsMostSpecificRung() {
        let packet = VisualFactPacket(facts: [
            VisualFact(kind: .setting, label: "bird", confidence: 0.9, source: .appleVisionClassifier),
            VisualFact(kind: .setting, label: "raptor", confidence: 0.85, source: .appleVisionClassifier),
            VisualFact(kind: .setting, label: "eagle", confidence: 0.8, source: .appleVisionClassifier)
        ])
        XCTAssertEqual(Bestiary.sightings(in: packet).map(\.creature), ["eagle"])
    }

    /// But a group name on its own survives, because then it is the true answer
    /// rather than a vaguer version of a better one.
    func testAGroupNameOnItsOwnIsKept() {
        let packet = VisualFactPacket(facts: [
            VisualFact(kind: .setting, label: "bird", confidence: 0.9, source: .appleVisionClassifier)
        ])
        XCTAssertEqual(Bestiary.sightings(in: packet).map(\.creature), ["bird"])
    }

    /// A cat and a bird in one frame are two animals. Suppression must not eat
    /// a real second creature on its way to tidying up a redundant label.
    func testTwoDifferentAnimalsInOneFrameBothSurvive() {
        let packet = VisualFactPacket(facts: [
            VisualFact(kind: .animal, label: "Cat", confidence: 0.95, source: .appleVisionAnimal),
            VisualFact(kind: .setting, label: "bird", confidence: 0.8, source: .appleVisionClassifier)
        ])
        XCTAssertEqual(Set(Bestiary.sightings(in: packet).map(\.creature)), ["cat", "bird"])
    }

    /// Every group label's covered list has to be filable, or suppression would
    /// silently never fire for that entry.
    func testEveryGroupLabelAndItsCoveredNamesAreFilable() {
        for (group, covered) in Bestiary.coveredByGroupLabel {
            XCTAssertNotNil(Bestiary.creature(for: group), "group label \(group) cannot be filed")
            for name in covered {
                XCTAssertNotNil(Bestiary.creature(for: name), "\(group) covers \(name), which nothing files")
            }
        }
    }

    /// Lore keyed to a label the filing system doesn't know would never unlock.
    func testEveryLoreRowIsKeyedToAFilableCreature() {
        for (creature, row) in CreatureLore.rowsByCreature {
            XCTAssertNotNil(
                Bestiary.creature(for: creature),
                "lore row \(row.id) waits on \(creature), which nothing can file"
            )
        }
    }

    /// Inherited lore is furniture. Nothing here may become a claim about the
    /// reader, which is the same law the rest of the inherited library runs on.
    func testNoCreatureLoreIsTestableAgainstTheReader() {
        for (_, row) in CreatureLore.rowsByCreature {
            XCTAssertFalse(row.isTestable, "\(row.id) would turn folklore into evidence")
        }
    }

    func testLoreIdsAreUnique() {
        let ids = CreatureLore.rowsByCreature.map(\.1.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// Filing has to be idempotent. The validator asks the filing system about
    /// an already-filed name before letting a sighting into the archive, so a
    /// name the system produces but doesn't recognise is a sighting silently
    /// destroyed on the way in. "Crane bird" files as "crane", and "crane" was
    /// not a label. Every crane would have been lost.
    func testFilingANameTheSystemItselfProducedGivesTheSameNameBack() {
        for label in Bestiary.creatureLabels {
            let filed = Bestiary.creature(for: label)
            XCTAssertNotNil(filed, label)
            XCTAssertEqual(Bestiary.creature(for: filed ?? ""), filed, "filing \(label) is not idempotent")
        }
    }

    func testPluralsTheBookWouldOtherwiseGetWrong() {
        XCTAssertEqual(Bestiary.plural("mouse"), "mice")
        XCTAssertEqual(Bestiary.plural("goose"), "geese")
        XCTAssertEqual(Bestiary.plural("sheep"), "sheep")
        XCTAssertEqual(Bestiary.plural("fox"), "foxes")
        XCTAssertEqual(Bestiary.plural("butterfly"), "butterflies")
        XCTAssertEqual(Bestiary.plural("crow"), "crows")
        XCTAssertEqual(Bestiary.plural("finch"), "finches")
    }
}
