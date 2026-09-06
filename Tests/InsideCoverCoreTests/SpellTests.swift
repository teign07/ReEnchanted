import XCTest
@testable import InsideCoverCore

/// Phase 1 of `docs/spells-plan.md`. A Spell is an instruction the Book hands
/// the reader for the next ten minutes: something people really did, with a way
/// of bringing back what happened.
final class SpellTests: XCTestCase {

    private var all: [SpellDef] { SpellRegistry.all }

    func testThereAreEnoughSpellsToChooseBetween() {
        XCTAssertGreaterThanOrEqual(all.count, 10)
        XCTAssertGreaterThan(all.count, SpellRegistry.offeredAtOnce,
                             "the shelf must hold more than one sitting's worth")
    }

    func testIdentifiersAreUnique() {
        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertNotNil(SpellRegistry.spell(id: "derive"))
        XCTAssertNil(SpellRegistry.spell(id: "not-a-spell"))
    }

    // MARK: Attribution

    func testEverySpellNamesThePracticeItComesFrom() {
        for spell in all {
            XCTAssertFalse(spell.practice.trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(spell.id) asks for something with nobody's name on it")
            XCTAssertFalse(spell.title.isEmpty)
            XCTAssertFalse(spell.blurb.isEmpty)
            XCTAssertFalse(spell.invitation.isEmpty)
        }
    }

    /// The Academy may invent. It may not invent and sound like a source.
    func testAcademyInventionsAdmitTheyAreInventions() {
        let invented = all.filter { $0.source == .academy }
        XCTAssertFalse(invented.isEmpty, "the Academy should have a spell of its own")
        for spell in invented {
            XCTAssertTrue(spell.attributionLine.contains("Academy"), "\(spell.id) hides that it is invented")
            let admissions = ["no evidence", "cannot prove", "can't prove", "made this up", "invented"]
            XCTAssertTrue(
                admissions.contains { spell.blurb.lowercased().contains($0) },
                "\(spell.id) is invented and does not admit it in its own account"
            )
        }
    }

    /// An entirely antiquarian shelf reads as a museum. The reader's life is
    /// now, so a real share of these have to be from now.
    func testTheShelfIsNotAMuseum() {
        let modern = all.filter { spell in
            ["19", "20"].contains { spell.practice.contains($0) } || spell.practice.contains("phone")
        }
        XCTAssertGreaterThanOrEqual(modern.count, 5, "not enough of these come from living memory")
    }

    // MARK: What a spell may ask for

    /// Asserting each mechanic is a member of its own enum proves nothing, so
    /// this asserts the thing that can actually go wrong: a corpus that resolves
    /// every spell the same way. Five ways of coming back exist; a feature that
    /// only ever asks for a line is one-note, and the two mechanics that leave
    /// something behind would never be exercised at all.
    func testTheSpellsUseMoreThanOneWayOfComingBack() {
        let used = Set(all.map(\.mechanic))
        XCTAssertGreaterThanOrEqual(
            used.count, 4,
            "the shelf resolves nearly everything the same way: \(used.map(\.rawValue).sorted())"
        )
        XCTAssertTrue(used.contains(.pressAKeepsake), "nothing ever ends up in the Pocket")
        XCTAssertTrue(used.contains(.nameSomething), "the Book is never given a name to keep using")
        XCTAssertLessThanOrEqual(
            used.count, CelebrationMechanic.allCases.count,
            "a spell resolves through a mechanic the Book does not have"
        )
    }

    /// The house law: doable in the next ten minutes with what is to hand. This
    /// cannot be checked properly, so it checks the ways it usually breaks.
    func testNoSpellSendsTheReaderShoppingOrWaiting() {
        // "order " used to be in here and flagged a spell about ordering a
        // different coffee in a cafe the reader is already standing in. The rule
        // is against *acquiring* things and against waiting, not against the
        // word: narrowed to phrases that really mean go and get something.
        let forbidden = ["buy ", "purchase", "order online", "add to cart",
                         "wait until", "next week", "next month", "tomorrow",
                         "in the spring", "in the autumn"]
        for spell in all {
            let text = spell.invitation.lowercased()
            for phrase in forbidden {
                XCTAssertFalse(text.contains(phrase),
                               "\(spell.id) asks the reader to \(phrase.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    /// It is an instruction, so it has to tell the reader to do something.
    func testEveryInvitationIsAnInstruction() {
        for spell in all {
            let words = spell.invitation.split(separator: " ").count
            XCTAssertGreaterThan(words, 6, "\(spell.id) is too thin to act on")
            XCTAssertLessThan(words, 45, "\(spell.id) is an essay, not an instruction")
        }
    }

    /// The Book offers; it never promises. A spell that claims an effect is the
    /// one thing this feature must not do.
    func testNoSpellClaimsItWorks() {
        let claims = ["will make you", "guarantees", "you will feel", "this works",
                      "proven", "cures", "will bring you luck"]
        for spell in all {
            let text = (spell.blurb + " " + spell.invitation).lowercased()
            for claim in claims {
                XCTAssertFalse(text.contains(claim), "\(spell.id) promises an effect")
            }
        }
    }

    // MARK: Voice

    /// The same lint the Correspondences corpus gets: the tells are shapes, not
    /// words. See `CorrespondenceVoiceTests`.
    func testSpellsAreWrittenInTheBooksVoice() {
        for spell in all {
            let prose = [spell.blurb, spell.invitation]
            for text in prose {
                XCTAssertFalse(text.contains(";"), "\(spell.id) balances a clause instead of stopping")
                XCTAssertFalse(text.contains(", which "), "\(spell.id) remarks on its own observation")
                for sentence in text.split(whereSeparator: { ".!?".contains($0) }) {
                    XCTAssertLessThanOrEqual(
                        sentence.split(separator: " ").count, 60,
                        "\(spell.id) has a sentence that has stopped being a sentence"
                    )
                }
            }
        }
    }

    func testSpellsSurviveARoundTrip() throws {
        let pack = try XCTUnwrap(SpellRegistry.bundledPacks.first)
        let decoded = try JSONDecoder().decode(SpellPack.self, from: JSONEncoder().encode(pack))
        XCTAssertEqual(decoded, pack)
    }
}

/// Phase 2/3: what the Book offers, and the Page a Spell becomes.
final class SpellOfferingTests: XCTestCase {

    func testTheOfferIsStableWithinADay() {
        let first = SpellOffering.offered(on: "2026-09-06").map(\.id)
        let second = SpellOffering.offered(on: "2026-09-06").map(\.id)
        XCTAssertEqual(first, second, "the shelf reshuffled under the reader's thumb")
    }

    func testTheOfferChangesBetweenDays() {
        var seen: Set<String> = []
        for day in 1...20 {
            seen.formUnion(SpellOffering.offered(on: "2026-09-\(day)").map(\.id))
        }
        XCTAssertGreaterThan(seen.count, SpellRegistry.offeredAtOnce,
                             "the same spells come up every day")
    }

    func testTheOfferIsCappedSoItStaysAChoice() {
        XCTAssertEqual(SpellOffering.offered(on: "2026-09-06").count, SpellRegistry.offeredAtOnce)
        XCTAssertTrue(SpellOffering.offered(on: "2026-09-06", from: []).isEmpty)
        XCTAssertTrue(SpellOffering.offered(on: "2026-09-06", limit: 0).isEmpty)
    }

    /// Weight tilts the draw. It must not fix it, or the light spells are dead
    /// content that never once reaches a reader.
    func testEveryUnconditionalSpellCanStillComeUp() {
        var seen: Set<String> = []
        for day in 0..<400 {
            seen.formUnion(SpellOffering.offered(on: "day-\(day)").map(\.id))
        }
        let anywhere = Set(SpellRegistry.all.filter { $0.trigger == nil }.map(\.id))
        XCTAssertTrue(
            anywhere.subtracting(seen).isEmpty,
            "these can never be offered at all: \(anywhere.subtracting(seen).sorted())"
        )
    }

    /// A spell with conditions must not leak out on a day that does not meet
    /// them. With no context the Book knows nothing about today, so it offers
    /// only what works anywhere.
    func testConditionalSpellsDoNotAppearWithoutAContext() {
        let offered = SpellOffering.offered(on: "2026-09-06", context: nil)
        XCTAssertTrue(
            offered.allSatisfy { $0.trigger == nil },
            "a conditional spell was offered on a day nothing was known about"
        )
    }

    /// Half the shelf should be conditional, or the feature is still a menu.
    func testAGoodShareOfTheShelfOnlyExistsSometimes() {
        let conditional = SpellRegistry.all.filter { $0.trigger != nil }
        XCTAssertGreaterThanOrEqual(conditional.count, 10)
        XCTAssertGreaterThan(
            conditional.count, SpellRegistry.all.count / 3,
            "too little of this depends on the world"
        )
    }

    /// Weather, place and hour all have to be represented, or one axis is
    /// carrying the whole idea.
    func testEveryConditionAxisIsUsed() {
        let triggers = SpellRegistry.all.compactMap(\.trigger)
        XCTAssertTrue(triggers.contains { !($0.weatherTags ?? []).isEmpty }, "no spell keys on weather")
        XCTAssertTrue(triggers.contains { !($0.placeKinds ?? []).isEmpty }, "no spell keys on place")
        XCTAssertTrue(triggers.contains { !($0.timeBands ?? []).isEmpty }, "no spell keys on the hour")
    }

    /// Place-keyed spells are only reachable through an Anchor's own category,
    /// so they must use keys `PlaceKind` can actually produce.
    func testPlaceKeyedSpellsUseRealCategories() {
        for spell in SpellRegistry.all {
            for kind in spell.trigger?.placeKinds ?? [] {
                XCTAssertEqual(
                    PlaceKind.key(fromCategoryRawValue: "MKPOICategory\(kind.prefix(1).uppercased())\(kind.dropFirst())"),
                    kind,
                    "\(spell.id) keys on \(kind), which is not shaped like a category key"
                )
            }
        }
    }

    // MARK: The Page

    private var castPage: SurfacePage {
        SpellOffering.surface(for: SpellRegistry.spell(id: "derive")!, dayID: "2026-09-06")
    }

    func testACastSpellIsASpellPage() {
        XCTAssertEqual(castPage.type, .spell)
        XCTAssertEqual(castPage.intent, .capture)
        XCTAssertTrue(castPage.payload.body.contains("Debord"))
        XCTAssertTrue(castPage.payload.body.contains("take the turn you never take"))
    }

    /// The affordance is decided by metadata the capture sheet already knows how
    /// to render, so a Spell must write the same contract a feast does.
    func testTheCastPageCarriesAMechanicTheSheetCanRender() {
        let metadata = castPage.payload.metadata
        XCTAssertEqual(metadata["festivalMechanic"], CelebrationMechanic.nameSomething.rawValue)
        XCTAssertFalse((metadata["festivalMechanicPrompt"] ?? "").isEmpty)
        XCTAssertFalse((metadata["placeholder"] ?? "").isEmpty)
        XCTAssertEqual(metadata["spellID"], "derive")
    }

    /// Whoever kept the practice travels with the Page, so a cast spell never
    /// looks like something the Book invented on the spot.
    func testTheCastPageSaysWhoKeptThePractice() {
        XCTAssertTrue(castPage.reason.contains("Debord"))
        XCTAssertEqual(castPage.payload.metadata["spellSource"], LoreSource.folk.rawValue)
    }

    /// The two mechanics that leave something behind need their extra keys, or
    /// the resolver has nothing to press into the Pocket.
    func testKeepsakeAndNamingSpellsCarryWhatTheResolverNeeds() {
        let keepsake = SpellOffering.metadata(
            for: SpellRegistry.spell(id: "camera-roll-bibliomancy")!, dayID: "d"
        )
        XCTAssertFalse((keepsake["festivalKeepsakeObject"] ?? "").isEmpty)
        XCTAssertFalse((keepsake["festivalKeepsakeGlyph"] ?? "").isEmpty)

        let naming = SpellOffering.metadata(for: SpellRegistry.spell(id: "name-a-tree")!, dayID: "d")
        XCTAssertEqual(naming["festivalNameFactID"], "spell-name:name-a-tree")
    }

    func testEverySpellCanBecomeAPage() {
        for spell in SpellRegistry.all {
            let page = SpellOffering.surface(for: spell, dayID: "2026-09-06")
            XCTAssertFalse(page.payload.body.isEmpty, "\(spell.id) makes an empty Page")
            XCTAssertFalse((page.payload.metadata["festivalMechanic"] ?? "").isEmpty,
                           "\(spell.id) makes a Page with no way to answer it")
        }
    }
}

/// Phase 5: manners. A spell the reader put down stays down, and one they have
/// just worked is not handed back the next morning.
final class SpellMannersTests: XCTestCase {

    private var anywhere: [SpellDef] { SpellRegistry.all.filter { $0.trigger == nil } }

    func testARestedSpellIsNeverOfferedAgain() {
        let victim = anywhere.first!
        for day in 0..<200 {
            let offered = SpellOffering.offered(on: "day-\(day)", rested: [victim.id])
            XCTAssertFalse(offered.contains { $0.id == victim.id },
                           "a spell the reader put down came back on day \(day)")
        }
    }

    func testRestingEverythingLeavesNothingRatherThanCrashing() {
        let offered = SpellOffering.offered(
            on: "d", rested: Set(SpellRegistry.all.map(\.id))
        )
        XCTAssertTrue(offered.isEmpty)
    }

    func testAJustWorkedSpellRests() {
        let worked = anywhere.first!
        let now = Date()
        let offered = SpellOffering.offered(
            on: "d", lastCast: [worked.id: now], now: now, from: anywhere
        )
        XCTAssertFalse(offered.contains { $0.id == worked.id })
    }

    func testItComesBackOnceTheCooldownIsUp() {
        let worked = anywhere.first!
        let now = Date()
        let longAgo = now.addingTimeInterval(-SpellOffering.castCooldown - 60)
        var seen = false
        for day in 0..<200 where !seen {
            let offered = SpellOffering.offered(
                on: "day-\(day)", lastCast: [worked.id: longAgo], now: now, from: anywhere
            )
            seen = offered.contains { $0.id == worked.id }
        }
        XCTAssertTrue(seen, "a spell worked long ago never came back")
    }

    /// A device whose clock has gone backwards is a clock problem, not a reason
    /// to withhold every spell the reader has ever worked.
    func testAClockRunningBackwardsDoesNotHideEverything() {
        let worked = anywhere.first!
        let now = Date()
        let future = now.addingTimeInterval(60 * 60 * 24 * 30)
        var seen = false
        for day in 0..<200 where !seen {
            let offered = SpellOffering.offered(
                on: "day-\(day)", lastCast: [worked.id: future], now: now, from: anywhere
            )
            seen = offered.contains { $0.id == worked.id }
        }
        XCTAssertTrue(seen, "a clock skew silently retired a spell")
    }

    /// The cooldown exists so the one feature that breaks a routine does not
    /// become one. It must be long enough to matter and short enough to return.
    func testTheCooldownIsDayScale() {
        XCTAssertGreaterThanOrEqual(SpellOffering.castCooldown, 24 * 3_600)
        XCTAssertLessThanOrEqual(SpellOffering.castCooldown, 30 * 24 * 3_600)
    }

    /// Every spell carries the door out, or a reader stuck with one they hate
    /// has no way to say so.
    func testEverySpellCanBePutDown() {
        for spell in SpellRegistry.all {
            let metadata = SpellOffering.metadata(for: spell, dayID: "d")
            XCTAssertEqual(metadata["festivalCanRest"], "true", "\(spell.id) cannot be refused")
            XCTAssertFalse((metadata["festivalRestLabel"] ?? "").isEmpty)
            XCTAssertEqual(metadata["spellID"], spell.id,
                           "\(spell.id) cannot be identified when the reader rests it")
        }
    }
}

/// What the Book can say about a spell the reader has worked before.
final class SpellCastMemoryTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(
        _ offsetDays: Int,
        spellID: String,
        weather: [String] = [],
        placeKind: String? = nil,
        at hour: Int = 14,
        now: Date
    ) -> BookDay {
        let when = calendar.date(byAdding: .day, value: -offsetDays, to: now) ?? now
        let stamped = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: when) ?? when
        let page = BookPage(
            id: "p-\(offsetDays)-\(spellID)", type: .spell, createdAt: stamped,
            promptText: "", userInput: "",
            tags: ["spell", "spell:\(spellID)"], origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: stamped, calendar: calendar,
                weatherTags: weather, placeKind: placeKind
            )
        )
        return BookDay(id: "d-\(offsetDays)", date: stamped, pages: [page])
    }

    func testANeverWorkedSpellHasNothingToRecall() {
        XCTAssertNil(SpellCastMemory.recall(of: "derive", in: []))
        let elsewhere = [day(3, spellID: "sonder", now: Date())]
        XCTAssertNil(SpellCastMemory.recall(of: "derive", in: elsewhere, calendar: calendar))
    }

    /// The whole point: the weather is read back out of the kept Page rather
    /// than stored a second time in the cast log.
    func testTheBookRemembersTheWeatherItWasWorkedIn() {
        let now = Date()
        let days = [day(40, spellID: "derive", weather: ["rain"], now: now)]
        let line = SpellCastMemory.recall(of: "derive", in: days, now: now, calendar: calendar)
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("in the rain") == true, "got: \(line ?? "nil")")
        XCTAssertTrue(line?.hasPrefix("You did this one before") == true)
    }

    func testRepeatedWorkingsAreCounted() {
        let now = Date()
        let days = [
            day(40, spellID: "derive", weather: ["rain"], now: now),
            day(90, spellID: "derive", weather: ["fog"], now: now)
        ]
        let line = SpellCastMemory.recall(of: "derive", in: days, now: now, calendar: calendar)
        XCTAssertTrue(line?.contains("2 times") == true, "got: \(line ?? "nil")")
        XCTAssertTrue(line?.contains("in the rain") == true, "the most recent working is the one recalled")
    }

    /// Weather beats a place, a place beats an hour, and nothing at all beats a
    /// guess. The Book says the most particular true thing it has and stops.
    func testOneCircumstanceOnlyAndTheMostParticularOne() {
        let now = Date()
        let both = SpellCastMemory.Working(at: now, weather: "fog", placeKind: "beach", dayPart: "night")
        XCTAssertEqual(SpellCastMemory.circumstance(of: both), "in the fog")

        let place = SpellCastMemory.Working(at: now, weather: nil, placeKind: "beach", dayPart: "night")
        XCTAssertEqual(SpellCastMemory.circumstance(of: place), "at beach")

        let hour = SpellCastMemory.Working(at: now, weather: nil, placeKind: nil, dayPart: "night")
        XCTAssertEqual(SpellCastMemory.circumstance(of: hour), "at night")

        let nothing = SpellCastMemory.Working(at: now, weather: nil, placeKind: nil, dayPart: "afternoon")
        XCTAssertNil(SpellCastMemory.circumstance(of: nothing), "the Book invented a circumstance")
    }

    /// A weather tag the Book has no phrase for must produce no phrase, rather
    /// than "in the bright" or similar.
    func testAnUnknownWeatherTagIsNotDressedUp() {
        let odd = SpellCastMemory.Working(at: Date(), weather: "cloud", placeKind: nil, dayPart: "afternoon")
        XCTAssertNil(SpellCastMemory.circumstance(of: odd))
    }

    func testAWorkingWithNoContextStillRecallsTheDate() {
        let now = Date()
        let page = BookPage(
            id: "bare", type: .spell, createdAt: now, promptText: "", userInput: "",
            tags: ["spell:sonder"], origin: .userAuthored, context: nil
        )
        let days = [BookDay(id: "d", date: now, pages: [page])]
        let line = SpellCastMemory.recall(of: "sonder", in: days, now: now, calendar: calendar)
        XCTAssertEqual(line, "You did this one before, earlier this month.")
    }

    func testTheRecallReachesTheCastPage() {
        let spell = SpellRegistry.spell(id: "derive")!
        let page = SpellOffering.surface(for: spell, dayID: "d", recall: "You did this one before, in the rain, back in March.")
        XCTAssertTrue(page.payload.body.contains("in the rain"))
        XCTAssertEqual(page.payload.metadata["spellRecall"], "You did this one before, in the rain, back in March.")

        let fresh = SpellOffering.surface(for: spell, dayID: "d")
        XCTAssertNil(fresh.payload.metadata["spellRecall"])
        XCTAssertFalse(fresh.payload.body.hasSuffix("\n\n"), "an absent recall left a hole in the page")
    }
}
