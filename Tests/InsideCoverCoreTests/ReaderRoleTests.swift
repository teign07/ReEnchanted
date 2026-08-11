import XCTest
@testable import InsideCoverCore

/// The role is the one claim the Book makes about the reader as an identity
/// rather than as weather, so it has to be total (every reader gets named),
/// stable (the same answers always read the same), and honest (every part of
/// the name traces back to something the reader actually said).
final class ReaderRoleTests: XCTestCase {

    // MARK: The rule the first taxonomy broke

    /// Every role must restate what the reader said they come alive doing.
    /// The previous pass mapped "making something" onto The Mender, who fixes
    /// broken handles, so a reader who makes and never repairs was told a
    /// flat falsehood on night one. That must not be reachable again.
    func testEveryRoleRestatesItsOwnTrigger() {
        let expected: [String: String] = [
            "making": "maker", "outside": "lookout", "people": "porchlight",
            "movement": "detourist", "learning": "rabbit-holer",
            "solitude": "nightlight", "helping": "steady-hand", "story": "stowaway"
        ]
        for (alive, roleID) in expected {
            for magic in ["music", "weather", "places", "coincidence", "details",
                          "laughter", "imagination", "love", "unsure"] {
                let axes = RoleAxes(rut: "phone", alive: alive, magic: magic, hands: "keeping")
                XCTAssertEqual(
                    ReaderRoleRegistry.read(axes: axes).id, roleID,
                    "\(alive) + \(magic) drifted off its own trigger"
                )
            }
        }
    }

    /// Magic colours the reading; it must never rename anybody. This is the
    /// specific failure that produced the wrong role in playtest.
    func testMagicNeverChangesWhoTheReaderIs() {
        let magics = ["music", "weather", "places", "coincidence", "details",
                      "laughter", "imagination", "love", "unsure"]
        for alive in ["making", "outside", "people", "movement", "learning",
                      "solitude", "helping", "story"] {
            let ids = Set(magics.map { magic in
                ReaderRoleRegistry.read(
                    axes: RoleAxes(rut: nil, alive: alive, magic: magic, hands: nil)
                ).id
            })
            XCTAssertEqual(ids.count, 1, "\(alive) split into \(ids) depending on magic")
        }
    }

    func testEveryAliveAnswerHasExactlyOneRole() {
        let covered = ReaderRoleRegistry.all.flatMap(\.aliveAffinity)
        XCTAssertEqual(Set(covered).count, covered.count, "two roles claim the same trigger")
        XCTAssertEqual(Set(covered).count, ReaderRoleRegistry.all.count)
    }

    // MARK: Totality and stability

    func testAReaderWhoAnsweredNothingStillGetsNamed() {
        let composed = ReaderRoleRegistry.compose(axes: RoleAxes())
        XCTAssertFalse(composed.role.name.isEmpty)
        XCTAssertEqual(composed.fullName, composed.role.name)
        // Nothing watched yet, so nothing claimed.
        XCTAssertNil(composed.mark)
        XCTAssertEqual(composed.titledName, composed.role.name)
    }

    func testReadingIsStable() {
        let axes = RoleAxes(rut: "sameness", alive: "making", magic: "details", hands: "making")
        XCTAssertEqual(ReaderRoleRegistry.compose(axes: axes), ReaderRoleRegistry.compose(axes: axes))
    }

    func testRunnerUpDiffersFromThePick() {
        let axes = RoleAxes(rut: "work", alive: "outside", magic: "weather", hands: "returning")
        XCTAssertNotEqual(
            ReaderRoleRegistry.read(axes: axes).id,
            ReaderRoleRegistry.read(axes: axes, offset: 1).id
        )
    }

    func testOffsetPastTheEndClampsRatherThanCrashing() {
        let axes = RoleAxes(rut: "later", alive: "story", magic: "music", hands: "still")
        XCTAssertEqual(
            ReaderRoleRegistry.read(axes: axes, offset: 999).id,
            ReaderRoleRegistry.ranked(axes: axes).last?.id
        )
    }

    // MARK: Marks: the half the Book earned

    func testAMarkIsOnlyGivenForSomethingTheBookWatched() {
        let toldOnly = RoleAxes(rut: "phone", alive: "making", magic: "details", hands: "keeping")
        XCTAssertNil(ReaderRoleRegistry.earnedMark(axes: toldOnly), "a Mark was invented from self-report")

        var watched = toldOnly
        watched.recallKept = 1
        XCTAssertNotNil(ReaderRoleRegistry.earnedMark(axes: watched))
    }

    func testTheHardestEarnedMarkWins() {
        var axes = RoleAxes(alive: "making")
        axes.keptFirstPage = true
        XCTAssertEqual(ReaderRoleRegistry.earnedMark(axes: axes)?.id, "keeper")
        axes.caughtTheWord = true
        XCTAssertEqual(ReaderRoleRegistry.earnedMark(axes: axes)?.id, "quick")
        axes.heldAgainstWicker = true
        XCTAssertEqual(ReaderRoleRegistry.earnedMark(axes: axes)?.id, "unbowed")
        axes.recallKept = 3
        XCTAssertEqual(ReaderRoleRegistry.earnedMark(axes: axes)?.id, "clear-eyed")
    }

    /// Losing the hour is the expected result and must never read as a failure
    /// grade: the reader who admits it gets credited for the admission.
    func testForgettingIsMarkedHonestlyRatherThanPunished() {
        var axes = RoleAxes(alive: "solitude")
        axes.recallKept = 0
        let mark = ReaderRoleRegistry.earnedMark(axes: axes)
        XCTAssertEqual(mark?.id, "straight")
        let evidence = (mark?.evidence ?? "").lowercased()
        for shaming in ["failed", "should have", "unfortunately", "sadly", "poor"] {
            XCTAssertFalse(evidence.contains(shaming), "the Mark scolds: \(shaming)")
        }
    }

    func testTheMarkRidesLastInTheName() {
        var axes = RoleAxes(rut: "phone", alive: "story", magic: "music", hands: "telling")
        axes.recallKept = 3
        let composed = ReaderRoleRegistry.compose(axes: axes)
        XCTAssertEqual(composed.fullName, "The Stowaway of the Blue Hour")
        XCTAssertEqual(composed.titledName, "The Stowaway of the Blue Hour, Clear-Eyed")
    }

    // MARK: Composition

    func testComposedNameReadsAsASentence() {
        let axes = RoleAxes(rut: "phone", alive: "story", magic: "coincidence", hands: "telling")
        let composed = ReaderRoleRegistry.compose(axes: axes)
        XCTAssertEqual(composed.fullName, "The Stowaway of the Blue Hour")
        XCTAssertEqual(composed.signature, "The Stowaway of the Blue Hour, with Telling Hands")
    }

    func testHandsAddTheirCurationWeightOnTopOfTheRole() {
        let axes = RoleAxes(rut: "work", alive: "solitude", magic: "imagination", hands: "still")
        let composed = ReaderRoleRegistry.compose(axes: axes)
        let roleOnly = composed.role.scoreBoosts[.rest] ?? 0
        let handsOnly = ReaderRoleRegistry.hands(id: "still")?.scoreBoosts[.rest] ?? 0
        XCTAssertEqual(composed.scoreBoosts[.rest], roleOnly + handsOnly)
        XCTAssertGreaterThan(handsOnly, 0)
    }

    func testEveryRoleHasAWholeDossierAndAPatron() {
        let voices = Set(KeepMarginalia.voices.map(\.slug))
        for role in ReaderRoleRegistry.all {
            XCTAssertTrue(role.name.hasPrefix("The "), "\(role.id) should be titled")
            XCTAssertGreaterThan(role.dossier.count, 200, "\(role.id) dossier is too thin")
            XCTAssertFalse(role.compassLine.isEmpty, "\(role.id) has no compass line")
            XCTAssertFalse(role.scoreBoosts.isEmpty, "\(role.id) does not bias curation")
            XCTAssertNotNil(CastDossier.bio(forSlug: role.patronSlug), "\(role.id) patron missing")
            XCTAssertTrue(voices.contains(role.voiceSlug), "\(role.id) voice cannot speak")
        }
    }

    func testEveryEpithetHandsAndMarkIDIsDistinct() {
        XCTAssertEqual(Set(ReaderRoleRegistry.all.map(\.id)).count, ReaderRoleRegistry.all.count)
        XCTAssertEqual(Set(ReaderRoleRegistry.epithets.map(\.id)).count, ReaderRoleRegistry.epithets.count)
        XCTAssertEqual(Set(ReaderRoleRegistry.hands.map(\.id)).count, ReaderRoleRegistry.hands.count)
        XCTAssertEqual(Set(ReaderRoleRegistry.marks.map(\.id)).count, ReaderRoleRegistry.marks.count)
    }

    // MARK: Free-text epithets from the About You shelf

    func testEpithetFallsBackToReadingTheSentence() {
        XCTAssertEqual(ReaderRoleRegistry.matchedEpithet(for: "I keep opening my phone without knowing why.")?.id, "phone")
        XCTAssertEqual(ReaderRoleRegistry.matchedEpithet(for: "Figuring out dinner feels like a major administrative task.")?.id, "chores")
        XCTAssertNil(ReaderRoleRegistry.matchedEpithet(for: "   "))
    }

    func testEveryCannedRutSignalAnswerFindsAnEpithet() {
        for line in [
            "Whole weeks are happening, but I couldn't tell you what I did.",
            "I keep opening my phone without knowing why.",
            "Figuring out dinner feels like a major administrative task.",
            "When plans get canceled, relief arrives before disappointment.",
            "Things I usually like feel weirdly flavorless."
        ] {
            XCTAssertNotNil(ReaderRoleRegistry.matchedEpithet(for: line), "no epithet for: \(line)")
        }
    }

    func testAWordIsNotMatchedInsideAnotherWord() {
        XCTAssertNotEqual(ReaderRoleRegistry.matchedEpithet(for: "Whole weeks are happening.")?.id, "phone")
    }

    // MARK: Reading axes back out of saved facts

    private func fact(_ questionID: String, _ answer: String, tags: [String] = [],
                      permission: SelfFactUsePermission = .privateContext) -> SelfFact {
        SelfFact(
            id: "test:\(questionID)", questionID: questionID, question: questionID,
            answer: answer, bookTranslation: "", sensitivity: .identity,
            usePermission: permission, tags: tags,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testOnboardingChipTagsDriveTheRole() {
        let facts = [
            fact("onboarding-rut-strongest", "My phone eats the edges", tags: ["rut-context:phone"]),
            fact("onboarding-most-alive", "Making something", tags: ["alive-context:making"]),
            fact("onboarding-magic-source", "Tiny beautiful details", tags: ["magic-source:details"]),
            fact(ReaderRoleRegistry.handsFactID, "Making Hands", tags: ["hands:making"])
        ]
        let axes = ReaderRoleRegistry.axes(from: facts)
        XCTAssertEqual(axes.alive, "making")
        XCTAssertEqual(ReaderRoleRegistry.currentRole(from: facts)?.role.id, "maker")
    }

    func testAStoredRoleWinsOverAFreshReading() {
        let facts = [
            fact("onboarding-most-alive", "Making something", tags: ["alive-context:making"]),
            fact(ReaderRoleRegistry.roleFactID, "The Nightlight")
        ]
        XCTAssertEqual(ReaderRoleRegistry.currentRole(from: facts)?.role.id, "nightlight")
    }

    func testFactsMarkedDoNotUseAreNotReadAsAxes() {
        let facts = [fact("onboarding-most-alive", "Making something",
                          tags: ["alive-context:making"], permission: .doNotUse)]
        XCTAssertNil(ReaderRoleRegistry.axes(from: facts).alive)
    }

    func testNoAnswersAtAllMeansNoRoleRatherThanAGuess() {
        XCTAssertNil(ReaderRoleRegistry.currentRole(from: []))
    }

    // MARK: Legacy compatibility

    /// Both earlier taxonomies have to keep resolving, or an existing reader's
    /// stored name stops naming anybody.
    func testEveryRetiredRoleIDStillResolves() {
        let retired = [
            "lookout", "pocket-adventurer", "oddity-collector", "color-finder",
            "tiny-maker", "quiet-lantern", "porchlight", "proofkeeper",
            "mender", "magpie", "colourhound", "eavesdropper", "weather-witch",
            "tuning-fork", "detourist", "nightlight", "rabbit-holer"
        ]
        for id in retired {
            XCTAssertNotNil(ReaderRoleRegistry.role(named: id), "retired id \(id) no longer resolves")
        }
    }

    func testLegacyStoredNamesResolveWithAndWithoutTheArticle() {
        XCTAssertEqual(ReaderRoleRegistry.role(named: "The Nightlight")?.id, "nightlight")
        XCTAssertEqual(ReaderRoleRegistry.role(named: "Quiet Lantern")?.id, "nightlight")
        XCTAssertEqual(ReaderRoleRegistry.role(named: "The Mender")?.id, "maker")
        XCTAssertNil(ReaderRoleRegistry.role(named: "Not A Role"))
    }
}


final class ReaderRoleEffectTests: XCTestCase {
    private func fact(_ questionID: String, _ answer: String, tags: [String]) -> SelfFact {
        SelfFact(
            id: "test:\(questionID)", questionID: questionID, question: questionID,
            answer: answer, bookTranslation: "", sensitivity: .identity,
            usePermission: .privateContext, tags: tags,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    /// A Porchlight with Telling Hands should meet more letters than a reader
    /// the Book has never named.
    func testTheRoleSteersTheDesk() {
        let facts = [
            fact("onboarding-rut-strongest", "phone", tags: ["rut-context:phone"]),
            fact("onboarding-most-alive", "people", tags: ["alive-context:people"]),
            fact("onboarding-magic-source", "love", tags: ["magic-source:love"]),
            fact(ReaderRoleRegistry.handsFactID, "Telling Hands", tags: ["hands:telling"])
        ]
        let role = ReaderRoleRegistry.currentRole(from: facts)
        XCTAssertEqual(role?.role.id, "porchlight")

        let letter = SurfacePage(type: .letter, prompt: "A letter", detail: "From someone.")
        XCTAssertGreaterThan(
            ReaderRoleRegistry.scoreBoost(for: letter, role: role),
            ReaderRoleRegistry.scoreBoost(for: letter, role: nil)
        )
    }

    /// The hands are their own axis of curation weight, or the question the
    /// Book asks during onboarding is decoration.
    func testHandsChangeTheDeskIndependentlyOfTheRole() {
        func role(hands: String) -> ComposedRole {
            ReaderRoleRegistry.compose(
                axes: RoleAxes(rut: "phone", alive: "outside", magic: "places", hands: hands)
            )
        }
        let keeping = role(hands: "keeping")
        let still = role(hands: "still")
        XCTAssertEqual(keeping.role.id, still.role.id, "same role, different hands")

        let rest = SurfacePage(type: .rest, prompt: "Rest", detail: "Sit a while.")
        XCTAssertGreaterThan(
            ReaderRoleRegistry.scoreBoost(for: rest, role: still),
            ReaderRoleRegistry.scoreBoost(for: rest, role: keeping)
        )
    }

    /// The Book states the name rather than hedging it, and never turns it into
    /// a label pasted onto the prose.
    func testTheRoleReachesTheProseAsAnInstructionNotALabel() {
        let composed = ReaderRoleRegistry.compose(
            axes: RoleAxes(rut: "later", alive: "learning", magic: "imagination", hands: "making")
        )
        let section = BraidPromptBuilder.readerRoleSection(composed)
        XCTAssertTrue(section.contains(composed.fullName))
        XCTAssertTrue(section.contains("Do not hedge it"))
        XCTAssertTrue(section.contains("Never announce the name"))
        XCTAssertTrue(BraidPromptBuilder.readerRoleSection(nil).isEmpty)
    }
}

/// The patron is the character who took an interest at the naming. They become
/// a recurring margin voice once the greeter clamp lifts, not before, because
/// the first four faces are still earning their repetition, and never as a
/// monopoly, because the margins have to stay a place others can surprise from.
final class ReaderRolePatronTests: XCTestCase {
    private func marginSlugs(patron: String?, priorKeeps: Int, samples: Int = 400) -> [String: Int] {
        var counts: [String: Int] = [:]
        for index in 0..<samples {
            let note = KeepMarginalia.note(
                for: "The kettle sang twice before I noticed it had.",
                pageType: .diary,
                pageID: "patron-sample-\(index)",
                priorKeepCount: priorKeeps,
                patronVoiceSlug: patron
            )
            if let slug = note?.castSlug { counts[slug, default: 0] += 1 }
        }
        return counts
    }

    func testPatronTakesALargerShareOnceTheClampLifts() {
        let withPatron = marginSlugs(patron: "penny-blackletter", priorKeeps: 40)
        let without = marginSlugs(patron: nil, priorKeeps: 40)
        XCTAssertGreaterThan(
            withPatron["penny-blackletter"] ?? 0,
            without["penny-blackletter"] ?? 0,
            "the patron should recur more than an unweighted voice"
        )
    }

    func testPatronNeverMonopolisesTheMargins() {
        let counts = marginSlugs(patron: "penny-blackletter", priorKeeps: 40)
        let total = counts.values.reduce(0, +)
        let patronShare = Double(counts["penny-blackletter"] ?? 0) / Double(max(1, total))
        XCTAssertLessThan(patronShare, 0.5, "the margins stopped being anybody else's")
        XCTAssertGreaterThan(counts.keys.count, 3, "the rest of the cast vanished")
    }

    func testPatronDoesNothingBeforeTheGreeterClampLifts() {
        // Under the threshold the margins still belong to the four greeters,
        // even when the patron is somebody else entirely.
        let counts = marginSlugs(patron: "dr-inkrest", priorKeeps: 5)
        XCTAssertEqual(counts["dr-inkrest"] ?? 0, 0, "a patron jumped the on-ramp")
        XCTAssertTrue(
            Set(counts.keys).isSubset(of: KeepMarginalia.greeterSlugs),
            "the greeter clamp leaked"
        )
    }
}

/// A name that can never be lost is a trophy; a name that has to keep being
/// true is an appointment. The reveal promises "if it stops fitting, I'll earn
/// you a better one", these pin what has to be true before the Book says it.
final class ReaderRoleTenureTests: XCTestCase {
    private let named = Date(timeIntervalSince1970: 1_700_000_000)

    private func pages(_ type: BookPageType, _ count: Int, from start: Date) -> [BookPage] {
        (0..<count).map { index in
            BookPage(
                id: "\(type.rawValue)-\(index)",
                type: type,
                createdAt: start.addingTimeInterval(Double(index) * 3_600),
                promptText: "prompt",
                userInput: "a kept line with enough words in it to count",
                origin: .userAuthored
            )
        }
    }

    private func outgrown(_ current: String, _ kept: [BookPage], days: Int) -> ReaderRole? {
        ReaderRoleRegistry.outgrownRole(
            current: ReaderRoleRegistry.role(id: current)!,
            keptPages: kept,
            namedAt: named,
            now: named.addingTimeInterval(Double(days) * 86_400)
        )
    }

    func testANameThatStillFitsIsLeftAlone() {
        // A Nightlight who keeps resting is still a Nightlight.
        let kept = pages(.rest, 40, from: named)
        XCTAssertNil(outgrown("nightlight", kept, days: 90))
    }

    func testBehaviourThatClearlyOutrunsTheNameEarnsANewOne() {
        // Named a Nightlight, but three months of compass runs and anchors say
        // this reader goes places.
        let kept = pages(.wonderCompass, 30, from: named) + pages(.anchor, 20, from: named)
        let next = outgrown("nightlight", kept, days: 90)
        XCTAssertNotNil(next)
        XCTAssertNotEqual(next?.id, "nightlight")
    }

    func testEvidenceFloorHoldsEvenAfterAVeryLongTime() {
        // Two years and four kept pages is not evidence of anything.
        let kept = pages(.wonderCompass, 4, from: named)
        XCTAssertNil(outgrown("nightlight", kept, days: 730))
    }

    func testDayFloorHoldsEvenForAVeryBusyReader() {
        // A hundred pages in a week is enthusiasm, not a season.
        let kept = pages(.wonderCompass, 100, from: named)
        XCTAssertNil(outgrown("nightlight", kept, days: 6))
    }

    func testPagesKeptBeforeTheNamingDoNotCount() {
        // The name is judged on what happened after it was given.
        let old = pages(.wonderCompass, 60, from: named.addingTimeInterval(-400 * 86_400))
        XCTAssertNil(outgrown("nightlight", old, days: 120))
    }

    func testANarrowLeadIsNotEnoughToRenameSomebody() {
        // Without a margin the name would flicker between two near-equal
        // readings and stop meaning anything.
        let kept = pages(.rest, 30, from: named) + pages(.wonderCompass, 6, from: named)
        XCTAssertNil(outgrown("nightlight", kept, days: 120))
    }

    func testTheReadingIsStableForTheSameEvidence() {
        let kept = pages(.wonderCompass, 30, from: named) + pages(.anchor, 20, from: named)
        XCTAssertEqual(outgrown("nightlight", kept, days: 90)?.id, outgrown("nightlight", kept, days: 90)?.id)
    }

    func testPrivatePagesAreNotEvidenceAboutWhoSomebodyIs() {
        let scored = ReaderRoleRegistry.evidenceScores(
            keptPages: pages(.fuel, 50, from: named) + pages(.body, 50, from: named)
        )
        XCTAssertTrue(scored.values.allSatisfy { $0 == 0 }, "body and fuel logs are not a personality")
    }

    func testTenureTracksWhetherItIsStillBeingLived() {
        var tenure = RoleTenure(roleID: "nightlight", namedAt: named)
        XCTAssertTrue(tenure.isCurrent)
        tenure.supersededAt = named.addingTimeInterval(90 * 86_400)
        XCTAssertFalse(tenure.isCurrent)
        // Seasons are named backwards, by the reader, never by the Book, and
        // never in advance.
        XCTAssertNil(tenure.seasonName)
    }
}

/// The re-naming has to reach the reader as an offer, once, and only when the
/// evidence is real.
final class ReaderRoleOutgrownPageTests: XCTestCase {
    private let named = Date(timeIntervalSince1970: 1_700_000_000)

    private func roleFact(_ name: String, tags: [String] = []) -> SelfFact {
        SelfFact(
            id: "core:reader-role", questionID: ReaderRoleRegistry.roleFactID,
            question: "What the Book named you.", answer: name, bookTranslation: "",
            sensitivity: .identity, usePermission: .privateContext,
            tags: ["reader-role"] + tags, createdAt: named, updatedAt: named
        )
    }

    private func day(_ offsetDays: Int, type: BookPageType, count: Int) -> BookDay {
        let date = named.addingTimeInterval(Double(offsetDays) * 86_400)
        return BookDay(
            id: BookDay.id(for: date),
            date: date,
            pages: (0..<count).map { index in
                BookPage(
                    id: "\(type.rawValue)-\(offsetDays)-\(index)", type: type,
                    createdAt: date.addingTimeInterval(Double(index) * 600),
                    promptText: "prompt", userInput: "a kept line with enough words to count",
                    origin: .userAuthored
                )
            }
        )
    }

    private func page(facts: [SelfFact], days: [BookDay], afterDays: Int) -> SurfacePage? {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = facts
        inputs.days = days
        let now = named.addingTimeInterval(Double(afterDays) * 86_400)
        let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        return AboutYouPageSourceAdapter().candidates(
            for: today, context: CuratorContext.make(for: today), inputs: inputs, now: now
        ).first { $0.payload.metadata["readerRoleOutgrown"] == "true" }
    }

    private var wanderingDays: [BookDay] {
        (1...10).map { day($0 * 8, type: .wonderCompass, count: 6) }
    }

    func testTheBookOffersTheNewNameWhenTheEvidenceIsThere() throws {
        let surfaced = try XCTUnwrap(
            page(facts: [roleFact("The Nightlight")], days: wanderingDays, afterDays: 90)
        )
        XCTAssertEqual(surfaced.payload.metadata["outgrownFromRoleID"], "nightlight")
        XCTAssertNotEqual(surfaced.payload.metadata["outgrownToRoleID"], "nightlight")
        // An offer, not a correction: the reader may keep the name they have.
        XCTAssertTrue(surfaced.payload.body.contains("Refuse if you like"))
        // Stated, not asked for permission, and in the Book's own register.
        XCTAssertTrue(surfaced.payload.body.contains("I only lent you the lettering"))
        XCTAssertFalse(surfaced.payload.body.contains("I would rather"), "elevated register")
        XCTAssertTrue(surfaced.payload.body.contains("I called you The Nightlight and I was right"))
    }

    func testAReaderWhoStillFitsIsNeverAsked() {
        let resting = (1...10).map { day($0 * 8, type: .rest, count: 6) }
        XCTAssertNil(page(facts: [roleFact("The Nightlight")], days: resting, afterDays: 90))
    }

    func testTheQuestionIsAskedOnceAndSilenceIsAnAnswer() throws {
        let first = try XCTUnwrap(
            page(facts: [roleFact("The Nightlight")], days: wanderingDays, afterDays: 90)
        )
        let candidate = try XCTUnwrap(first.payload.metadata["outgrownToRoleID"])
        // The reader let it pass; the Book does not reopen it every evening.
        let asked = roleFact("The Nightlight", tags: ["role-outgrown:\(candidate)"])
        XCTAssertNil(page(facts: [asked], days: wanderingDays, afterDays: 120))
    }

    func testAReaderTheBookNeverNamedIsNeverRenamed() {
        XCTAssertNil(page(facts: [], days: wanderingDays, afterDays: 90))
    }
}

/// The card leaves the phone, so what it carries matters.
final class ReaderRoleShareCardTests: XCTestCase {
    private var composed: ComposedRole {
        ReaderRoleRegistry.compose(
            axes: RoleAxes(rut: "phone", alive: "story", magic: "coincidence", hands: "telling")
        )
    }

    func testTheCardCarriesTheBooksLanguageNotTheReaders() {
        let card = ReaderRoleShareCard.make(composed)
        XCTAssertEqual(card.fullName, "The Stowaway of the Blue Hour")
        XCTAssertEqual(card.handsName, "Telling Hands")
        XCTAssertFalse(card.gloss.isEmpty)
        XCTAssertTrue(card.patronLine.contains("Professor Permancer"))
        // Everything on the card is authored by the Book. None of it is the
        // reader's own kept material, which never leaves the phone this way.
        let surface = [card.fullName, card.gloss, card.patronLine, card.closingLine]
            .joined(separator: " ")
        XCTAssertFalse(surface.contains("Kept text"))
        XCTAssertFalse(surface.contains("detail"))
    }

    func testTheDeluxeWeekEarnsItsExtraInk() {
        let issue = WeeklyIssue(
            number: 3,
            startDate: Date(timeIntervalSince1970: 1_784_000_000),
            endDate: Date(timeIntervalSince1970: 1_784_500_000),
            dateRange: "14–20 July",
            keptCount: 9,
            highlights: [],
            setAsideLine: nil
        )
        let plain = WeeklyIssueShareCard.make(issue: issue, isDeluxe: false)
        let deluxe = WeeklyIssueShareCard.make(issue: issue, isDeluxe: true)

        XCTAssertFalse(plain.isDeluxe)
        XCTAssertTrue(deluxe.isDeluxe)
        XCTAssertTrue(plain.fullStats.isEmpty, "the plain plate does not carry the extra stats")
        XCTAssertFalse(deluxe.fullStats.isEmpty)
        // Same week, same facts: the deluxe cut shows more of them, it does
        // not invent any.
        XCTAssertEqual(plain.keptCount, deluxe.keptCount)
        XCTAssertEqual(plain.title, deluxe.title)
    }
}

/// The Book is a clever half-feral thing, not an elevated one. These pin the
/// register on the prose the reader actually reads, and one grammar trap.
final class ReaderRoleVoiceTests: XCTestCase {
    /// `verb` is stored already in the third person. Anything that appends an
    /// "s" produces "somebody who collectss" / "who looks ups".
    func testRoleVerbsAreAlreadyThirdPersonAndNeedNoSuffix() {
        for role in ReaderRoleRegistry.all {
            let sentence = "somebody who \(role.verb)"
            XCTAssertFalse(sentence.hasSuffix("ss"), "\(role.id): \(sentence)")
            XCTAssertFalse(role.verb.hasSuffix("ups"), "\(role.id): \(role.verb)")
            // Third person: "collects", "mends", "looks up", "takes the long way".
            let head = role.verb.split(separator: " ").first.map(String.init) ?? ""
            XCTAssertTrue(head.hasSuffix("s"), "\(role.id) verb '\(role.verb)' is not third person")
        }
    }

    /// The Book never refers to itself in the third person in its own prose.
    func testTheBookNeverNarratesItselfInTheThirdPerson() {
        let prose = ReaderRoleRegistry.all.flatMap { [$0.dossier, $0.gloss, $0.compassLine] }
            + ReaderRoleRegistry.hands.map(\.gloss)
            + ReaderRoleRegistry.epithets.map(\.cost)
        for line in prose {
            XCTAssertFalse(line.contains("The Book"), "third-person narration: \(line.prefix(70))")
            XCTAssertFalse(line.contains("the Book"), "third-person narration: \(line.prefix(70))")
        }
    }

    /// No apology, no compulsory reassurance, no therapy register.
    func testTheDossiersDoNotConsoleOrApologise() {
        let banned = ["I'm sorry", "I am sorry", "it's okay", "it is okay",
                      "you should be proud", "don't worry", "there's nothing wrong"]
        for role in ReaderRoleRegistry.all {
            let lowered = role.dossier.lowercased()
            for phrase in banned {
                XCTAssertFalse(lowered.contains(phrase), "\(role.id) slipped into reassurance: \(phrase)")
            }
        }
    }

    /// The dossiers speak as I, in contractions, to a you.
    func testTheDossiersSpeakAsIAndUseContractions() {
        let all = ReaderRoleRegistry.all.map(\.dossier).joined(separator: " ")
        // Count the pronoun properly: most of them are contracted ("I've met",
        // "I'd drop that"), so splitting on " I " finds almost none of them.
        let firstPerson = all
            .split { !$0.isLetter && $0 != "'" }
            .filter { $0 == "I" || $0.hasPrefix("I'") }
            .count
        XCTAssertGreaterThan(firstPerson, 4, "the Book stopped speaking as I")
        XCTAssertGreaterThan(all.components(separatedBy: "'").count - 1, 30, "the contractions drained out")
    }
}
