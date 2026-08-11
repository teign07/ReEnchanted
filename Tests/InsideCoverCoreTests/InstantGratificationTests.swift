import XCTest
@testable import InsideCoverCore

final class InstantGratificationTests: XCTestCase {

    func testKeepConsequenceReceiptExplainsArchiveBeliefAndFirstReading() {
        XCTAssertEqual(
            KeepConsequenceReceipt.lines(
                beliefDelta: 1,
                firstReadingAwakened: true,
                keepsakeLine: "A keepsake also fell loose."
            ),
            [
                "This Page is safely inside your Book now.",
                "I've got enough of your own pages to begin my First Reading.",
                "Your attention kindled 1 Belief."
            ]
        )
    }

    func testKeepConsequenceReceiptStaysQuietWhenOnlyTheArchiveChanged() {
        XCTAssertEqual(
            KeepConsequenceReceipt.lines(
                beliefDelta: 0,
                firstReadingAwakened: false
            ),
            ["This Page is safely inside your Book now."]
        )
    }

    // MARK: KeepMarginalia

    func testMarginNoteIsDeterministicForSamePageID() {
        let first = KeepMarginalia.note(for: "The kettle sang twice before I noticed.", pageType: .diary, pageID: "page-abc")
        let second = KeepMarginalia.note(for: "The kettle sang twice before I noticed.", pageType: .diary, pageID: "page-abc")
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    func testMarginNoteVoicesSpreadAcrossPageIDs() {
        // Across many page IDs the seed should reach more than one voice.
        let slugs = Set((0..<24).compactMap { index in
            KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "spark-page-\(index)"
            )?.castSlug
        })
        XCTAssertGreaterThanOrEqual(slugs.count, 2)
    }

    func testMarginNoteSkipsThinAndPrivateKeeps() {
        XCTAssertNil(KeepMarginalia.note(for: "ok", pageType: .diary, pageID: "thin"))
        XCTAssertNil(
            KeepMarginalia.note(
                for: "Slept badly, achy all over, long strange dreams about rain.",
                pageType: .body,
                pageID: "private-body"
            ),
            "The cast never comments on body logs."
        )
        XCTAssertNil(
            KeepMarginalia.note(
                for: "Two eggs, black coffee, a fistful of blueberries at noon.",
                pageType: .fuel,
                pageID: "private-fuel"
            ),
            "The cast never comments on fuel logs."
        )
    }

    func testFeaturedWordAndSubstitutionLeaveNoPlaceholder() {
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "the parking lot looked like a cathedral"),
            "cathedral"
        )
        // Whichever line the seed picks, no unfilled placeholder may remain.
        for index in 0..<24 {
            let note = KeepMarginalia.note(
                for: "the parking lot looked like a cathedral",
                pageType: .souvenir,
                pageID: "cathedral-\(index)"
            )
            XCTAssertNotNil(note)
            XCTAssertFalse(note?.line.contains("{word}") ?? true)
        }
    }

    func testFeaturedWordPrefersSalienceOverLength() {
        // The old heuristic picked purely by length and lost every one of these.
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "something about the rowan felt different"),
            "rowan"
        )
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "I probably imagined the kestrel"),
            "kestrel"
        )
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "everything smelled like woodsmoke yesterday"),
            "woodsmoke"
        )
    }

    func testFeaturedWordKeepsProperNounCasingAndPrefersNames() {
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "walked the whole afternoon with Marguerite"),
            "Marguerite"
        )
        // A capitalised word opening a sentence is not a name.
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "Kettle boiled over while I was reading."),
            "kettle"
        )
        // A reader typing in caps is not naming anything.
        XCTAssertEqual(
            KeepMarginalia.featuredWord(in: "THE KETTLE BOILED OVER"),
            "kettle"
        )
    }

    func testFeaturedWordStaysSilentRatherThanFeaturingAnEmptyWord() {
        // Nothing here is worth quoting back; the caller falls through to a
        // plain line instead of claiming to have noticed "everything".
        XCTAssertNil(KeepMarginalia.featuredWord(in: "something happened, everything is different"))
        // Contraction stems are never featured.
        XCTAssertNil(KeepMarginalia.featuredWord(in: "I couldn't, I shouldn't"))
    }

    func testFeaturedWordIsStableForTheSameInput() {
        let input = "the rowan and the kestrel shared the same hedge"
        let first = KeepMarginalia.featuredWord(in: input)
        XCTAssertNotNil(first)
        for _ in 0..<20 {
            XCTAssertEqual(KeepMarginalia.featuredWord(in: input), first)
        }
    }

    func testFirstEligibleKeepIsPippasPinnedNote() {
        let note = KeepMarginalia.note(
            for: "A stranger held the door and said something kind.",
            pageType: .diary,
            pageID: "first-keep",
            priorKeepCount: 0
        )
        XCTAssertEqual(note?.castSlug, "pippa-pilcrow")
        XCTAssertEqual(note?.line, KeepMarginalia.firstKeepNote.line)
        // Thin and private keeps are still skipped even on the very first keep.
        XCTAssertNil(KeepMarginalia.note(for: "ok", pageType: .diary, pageID: "first-keep", priorKeepCount: 0))
        XCTAssertNil(
            KeepMarginalia.note(
                for: "Slept badly, achy all over, long strange dreams about rain.",
                pageType: .body,
                pageID: "first-keep",
                priorKeepCount: 0
            )
        )
    }

    func testSecondEligibleKeepIsTheDuet() {
        let note = KeepMarginalia.note(
            for: "The bus was late and the light was the wrong colour.",
            pageType: .diary,
            pageID: "second-keep",
            priorKeepCount: 1
        )
        XCTAssertEqual(note?.castSlug, "professor-thaddeus-mook")
        XCTAssertEqual(note?.rejoinderName, "Pippa Pilcrow")
        XCTAssertNotNil(note?.rejoinderAsset)
        XCTAssertNotNil(note?.rejoinderLine)
    }

    func testGreeterClampBeforeThreshold() {
        for index in 0..<40 {
            let slug = KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "greeter-\(index)",
                priorKeepCount: 5
            )?.castSlug
            XCTAssertNotNil(slug)
            XCTAssertTrue(KeepMarginalia.greeterSlugs.contains(slug ?? ""), "\(slug ?? "nil") is not a greeter")
        }
    }

    func testFullCastAfterThreshold() {
        let slugs = Set((0..<200).compactMap { index in
            KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "mature-\(index)",
                priorKeepCount: 40
            )?.castSlug
        })
        XCTAssertTrue(slugs.contains { !KeepMarginalia.greeterSlugs.contains($0) })
    }

    func testEligibleKeepCountMatchesPagesThatCanShowMarginNotes() {
        let souvenir = BookPage(
            id: "counts", type: .souvenir, promptText: "Catch one bright particular.",
            userInput: "The kettle sang twice before I noticed.", origin: .userAuthored
        )
        let bodyLog = BookPage(
            id: "body", type: .body, promptText: "How is the body?",
            userInput: "Slept badly, achy all over, strange dreams.", origin: .userAuthored
        )
        let thin = BookPage(
            id: "thin", type: .diary, promptText: "A line?",
            userInput: "It rained.", origin: .userAuthored
        )
        let generated = BookPage(
            id: "gen", type: .diary, promptText: "A line?",
            userInput: "The Book wrote this one on its own, at length.", origin: .generated
        )
        let day = BookDay(id: "2026-07-02", date: Date(), pages: [souvenir, bodyLog, thin, generated])
        XCTAssertEqual(KeepMarginalia.eligibleKeepCount(in: [day]), 2)
    }

    func testGeneratedPageKeepAdvancesFirstFriendGate() {
        let generated = BookPage(
            id: "generated-first",
            type: .diary,
            promptText: "The Book offered a page.",
            userInput: "The page had enough honest detail to answer.",
            origin: .generated
        )
        let day = BookDay(id: "2026-07-02", date: Date(), pages: [generated])
        let priorCount = KeepMarginalia.eligibleKeepCount(in: [day])

        let note = KeepMarginalia.note(
            for: "The next kept page should not pretend it is first.",
            pageType: .diary,
            pageID: "after-generated",
            priorKeepCount: priorCount
        )

        XCTAssertEqual(priorCount, 1)
        XCTAssertEqual(note?.castSlug, "professor-thaddeus-mook")
    }

    func testAvoidingRecentCastSlugChoosesDifferentVoiceWhenPossible() throws {
        let base = try XCTUnwrap(KeepMarginalia.note(
            for: "A small true thing happened by the window today.",
            pageType: .diary,
            pageID: "avoid-repeat",
            priorKeepCount: 20
        ))

        let avoided = try XCTUnwrap(KeepMarginalia.note(
            for: "A small true thing happened by the window today.",
            pageType: .diary,
            pageID: "avoid-repeat",
            priorKeepCount: 20,
            avoidingCastSlugs: [base.castSlug]
        ))

        XCTAssertNotEqual(avoided.castSlug, base.castSlug)
    }

    func testRecentCastSlugsReconstructsPriorMarginSpeakers() {
        let first = BookPage(
            id: "first",
            type: .diary,
            createdAt: Date(timeIntervalSince1970: 1),
            promptText: "First",
            userInput: "The first eligible generated page has enough words.",
            origin: .generated
        )
        let second = BookPage(
            id: "second",
            type: .diary,
            createdAt: Date(timeIntervalSince1970: 2),
            promptText: "Second",
            userInput: "The second eligible page has enough words too.",
            origin: .generated
        )
        let day = BookDay(id: "2026-07-02", date: Date(timeIntervalSince1970: 0), pages: [second, first])

        XCTAssertEqual(
            KeepMarginalia.recentCastSlugs(in: [day], limit: 2),
            ["pippa-pilcrow", "professor-thaddeus-mook"]
        )
    }

    func testEveryVoiceHasAccentAndGlyph() {
        for voice in KeepMarginalia.voices {
            XCTAssertEqual(voice.accentHex.count, 6, "\(voice.slug) accent must be RRGGBB")
            var scanned: UInt64 = 0
            XCTAssertTrue(Scanner(string: voice.accentHex).scanHexInt64(&scanned), "\(voice.slug) accent is not hex")
            XCTAssertFalse(voice.glyph.isEmpty, "\(voice.slug) is missing a glyph")
        }
    }

    func testLivingReactionQuotesAWholePageFragmentAndStaysBrief() throws {
        let input = "I meant to hurry past the rain, but the blue bicycle under the sycamore made me stop."
        let reaction = try XCTUnwrap(KeepMarginalia.livingNote(
            for: input,
            prompt: "What interrupted the ordinary day?",
            pageType: .diary,
            pageID: "living-grounded",
            priorKeepCount: 30
        ))

        XCTAssertTrue(reaction.note.line.contains("\u{201C}"))
        XCTAssertTrue(reaction.note.line.contains("\u{201D}"))
        XCTAssertGreaterThan(reaction.note.line.split { !$0.isLetter && !$0.isNumber }.count, 8)
        XCTAssertLessThanOrEqual(reaction.note.line.split { !$0.isLetter && !$0.isNumber }.count, 32)
        XCTAssertFalse(reaction.note.line.contains("{word}"))
    }

    func testLivingReactionCastingFollowsCharacterInterests() throws {
        let domestic = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "In the kitchen I cooked jam, laughed at the spoon, and called the steam household magic.",
            prompt: "What ordinary thing misbehaved beautifully?",
            pageType: .diary,
            pageID: "living-boggle",
            priorKeepCount: 30
        ))
        XCTAssertEqual(domestic.note.castSlug, "lydia-boggle")

        let route = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "I left the road, chose the muddy path instead, and made a bridge when the route disappeared.",
            prompt: "Where did the day lead?",
            pageType: .diary,
            pageID: "living-zara",
            priorKeepCount: 30
        ))
        XCTAssertEqual(route.note.castSlug, "zara-finch")

        let resistance = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "I doubted the rule, argued with it, but chose the hard answer because the evidence held.",
            prompt: "What would not become tidy?",
            pageType: .diary,
            pageID: "living-wicker",
            priorKeepCount: 30
        ))
        XCTAssertEqual(resistance.note.castSlug, "wicker-eddies")
    }

    func testLivingReactionStillHonorsTheGreeterIntroduction() throws {
        let reaction = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "I walked the long road home and chose the unmarked path when the bus vanished.",
            prompt: "Which way did you go?",
            pageType: .diary,
            pageID: "living-greeter",
            priorKeepCount: 5
        ))
        XCTAssertTrue(KeepMarginalia.greeterSlugs.contains(reaction.note.castSlug))
    }

    func testLivingReactionReceiptRoundTripsThroughArchiveTags() throws {
        let reaction = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "The kettle clicked off while the rain made a second window in the glass.",
            prompt: "Catch one exact thing.",
            pageType: .diary,
            pageID: "living-receipt",
            priorKeepCount: 30
        ))
        let page = BookPage(
            id: "receipt-page",
            type: .diary,
            promptText: "Catch one exact thing.",
            userInput: "The kettle clicked off while the rain made a second window in the glass.",
            tags: reaction.receipt.archiveTags
        )
        XCTAssertEqual(KeepMarginalia.ReactionReceipt.read(from: page), reaction.receipt)
    }

    func testLivingReactionHistoryChangesTheRepeatedPerformance() throws {
        let first = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "The garden gate refused to latch, but the blackbird kept using it as a drum.",
            prompt: "What did the ordinary world get up to?",
            pageType: .diary,
            pageID: "living-repeat",
            priorKeepCount: 30
        ))
        let next = try XCTUnwrap(KeepMarginalia.livingNote(
            for: "The garden gate refused to latch, but the blackbird kept using it as a drum.",
            prompt: "What did the ordinary world get up to?",
            pageType: .diary,
            pageID: "living-repeat",
            priorKeepCount: 30,
            avoidingCastSlugs: [first.note.castSlug],
            recentReceipts: [first.receipt]
        ))
        XCTAssertNotEqual(next.receipt.patternID, first.receipt.patternID)
        XCTAssertNotEqual(next.note.castSlug, first.note.castSlug)
    }

    func testLivingReactionNeverCommentsOnPrivateLogs() {
        XCTAssertNil(KeepMarginalia.livingNote(
            for: "Slept badly and woke twice after a long dream about rain.",
            prompt: "How did you rest?",
            pageType: .rest,
            pageID: "living-private",
            priorKeepCount: 30
        ))
    }

    func testWickerOwnsTheReturnFromItsDare() throws {
        let surface = SurfacePage(
            id: "wicker-return",
            type: .wickerDare,
            sourceID: "wickers-dares",
            prompt: "Retire one polite lie.",
            detail: "Tell the oddly specific truth.",
            payload: BookPagePayload(headline: "Wicker's Dare", body: "Do it.", metadata: [
                "wickerDareID": "honest-opinion",
                "onboardingWickerTier": "cost"
            ])
        )

        let note = try XCTUnwrap(LivedMissionReturnMarginalia.note(
            for: surface,
            readerInput: "The soup tasted like a rainy windowsill.",
            priorDays: []
        ))

        XCTAssertEqual(note.castSlug, "wicker-eddies")
        XCTAssertTrue(note.line.contains("rainy windowsill"))
    }

    func testMissionSenderOwnsTheEvidenceThatComesBack() throws {
        let surface = SurfacePage(
            id: "zara-return",
            type: .wonderCompass,
            sourceID: BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID,
            prompt: "Take the less obedient route.",
            detail: "Find one changed detail.",
            payload: BookPagePayload(headline: "South = Sense", body: "Go and notice.", metadata: [
                "playfulMissionID": "motion-long-way",
                "missionHostSlug": "zara-finch",
                "missionHostName": "Zara Finch",
                "missionHostAsset": "LabyrinthCharacterZaraFinch"
            ])
        )

        let note = try XCTUnwrap(LivedMissionReturnMarginalia.note(
            for: surface,
            readerInput: "The alley had blue chalk arrows under the fire escape.",
            priorDays: []
        ))

        XCTAssertEqual(note.castSlug, "zara-finch")
        XCTAssertTrue(note.line.contains("blue chalk arrows"))
    }

    func testDuskThornAnswersShadowProofWithoutCallingDarknessAVerdict() throws {
        let surface = SurfacePage(
            id: "thorn-return",
            type: .souvenir,
            sourceID: "one-sentence-souvenir",
            prompt: "What worn thing held?",
            detail: "Keep one exact thing.",
            payload: BookPagePayload(headline: "Shadow Souvenir", body: "Notice the worn edge.", metadata: [
                "variant": "shadow-wonder"
            ])
        )

        let note = try XCTUnwrap(LivedMissionReturnMarginalia.note(
            for: surface,
            readerInput: "A repaired red mitten waited on the stone wall.",
            priorDays: []
        ))

        XCTAssertEqual(note.castSlug, "dusk-thorn")
        XCTAssertTrue(note.line.contains("repaired red mitten"))
        XCTAssertTrue(note.line.lowercased().contains("dark") || note.line.lowercased().contains("thorn"))
    }

    // MARK: BraidEmber

    func testEmberIsSilentBeforeEvening() {
        let morning = Self.date(year: 2026, month: 6, day: 12, hour: 10)
        XCTAssertNil(BraidEmber.evening(for: dayWithTwoProsePages(), now: morning, calendar: Self.nyCalendar))
        // Even an unwritten day resolves only from 8pm: the afternoon stays open.
        XCTAssertNil(BraidEmber.evening(for: emptyDay(), now: morning, calendar: Self.nyCalendar))
        let earlyEvening = Self.date(year: 2026, month: 6, day: 12, hour: 18)
        XCTAssertNil(BraidEmber.evening(for: dayWithTwoProsePages(), now: earlyEvening, calendar: Self.nyCalendar))
    }

    func testEmberNamesThreadsInTheEvening() throws {
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 21)
        let ember = try XCTUnwrap(
            BraidEmber.evening(for: dayWithTwoProsePages(), now: evening, calendar: Self.nyCalendar)
        )
        XCTAssertEqual(ember.kind, .braid)
        XCTAssertTrue(ember.line.contains("two threads"))
        XCTAssertTrue(ember.line.contains("harbor"))
        XCTAssertTrue(ember.line.contains("cathedral"))
        XCTAssertEqual(ember.undertone, BraidEmber.braidUndertone)
    }

    func testEmberHoldsASingleThread() throws {
        let single = BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [prosePage(id: "one", createdAtHour: 9, input: "Rain over the harbor.")]
        )
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 21)
        let ember = try XCTUnwrap(BraidEmber.evening(for: single, now: evening, calendar: Self.nyCalendar))
        XCTAssertEqual(ember.kind, .singleThread)
        XCTAssertTrue(ember.line.contains("the harbor"))
        XCTAssertFalse(ember.line.contains("{thread}"))
        XCTAssertEqual(ember.undertone, BraidEmber.braidUndertone)
    }

    func testEmberRereadsAnEarlierDayWhenNothingWasKept() throws {
        let yesterday = priorDay(id: "2026-06-11", month: 6, day: 11, input: "Rain over the harbor.")
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 21)
        let ember = try XCTUnwrap(
            BraidEmber.evening(for: emptyDay(), previousDays: [yesterday], now: evening, calendar: Self.nyCalendar)
        )
        XCTAssertEqual(ember.kind, .lamplight)
        XCTAssertTrue(ember.line.contains("harbor"))
        XCTAssertTrue(ember.line.contains("yesterday"))
        XCTAssertFalse(ember.line.contains("{echo}"))
        XCTAssertEqual(ember.undertone, BraidEmber.lamplightUndertone)
    }

    func testEmberLaysTwoEarlierDaysSideBySide() throws {
        let previous = [
            priorDay(id: "2026-06-11", month: 6, day: 11, input: "Rain over the harbor."),
            priorDay(id: "2026-06-10", month: 6, day: 10, input: "The parking lot looked like a cathedral.")
        ]
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 21)
        let ember = try XCTUnwrap(
            BraidEmber.evening(for: emptyDay(), previousDays: previous, now: evening, calendar: Self.nyCalendar)
        )
        XCTAssertEqual(ember.kind, .lamplight)
        XCTAssertTrue(ember.line.contains("harbor"))
        XCTAssertTrue(ember.line.contains("cathedral"))
        XCTAssertFalse(ember.line.contains("{echoA}"))
        XCTAssertFalse(ember.line.contains("{echoB}"))
    }

    func testEmberEchoDatesDistantDays() {
        let phrase = BraidEmber.echoPhrase(
            bare: "harbor",
            dayDate: Self.date(year: 2026, month: 5, day: 20, hour: 9),
            now: Self.date(year: 2026, month: 6, day: 12, hour: 21),
            calendar: Self.nyCalendar
        )
        XCTAssertTrue(phrase.contains("harbor"))
        XCTAssertTrue(phrase.contains("May"))
    }

    func testEmberKeepsTheLampLitWithNoArchive() throws {
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 21)
        let ember = try XCTUnwrap(
            BraidEmber.evening(for: emptyDay(), previousDays: [], now: evening, calendar: Self.nyCalendar)
        )
        XCTAssertEqual(ember.kind, .lamplight)
        XCTAssertFalse(ember.line.isEmpty)
        XCTAssertEqual(ember.undertone, BraidEmber.lamplightUndertone)
    }

    func testEmberIsDeterministicForTheSameEvening() {
        let previous = [priorDay(id: "2026-06-11", month: 6, day: 11, input: "Rain over the harbor.")]
        let evening = Self.date(year: 2026, month: 6, day: 12, hour: 21)
        let first = BraidEmber.evening(for: emptyDay(), previousDays: previous, now: evening, calendar: Self.nyCalendar)
        let second = BraidEmber.evening(for: emptyDay(), previousDays: previous, now: evening, calendar: Self.nyCalendar)
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    func testThreadLabelsPreferVividWordsAndDedupe() {
        let day = BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [
                prosePage(id: "a", createdAtHour: 9, input: "Rain over the harbor."),
                moodPage(id: "b", createdAtHour: 10),
                prosePage(id: "c", createdAtHour: 11, input: "The harbor once more.")
            ]
        )
        let labels = BraidEmber.threadLabels(for: day)
        // A prose page is named by its vivid word; a wordless log falls back to
        // its type title (a mood page reads as the app's inner "weather").
        XCTAssertTrue(labels.contains("the harbor"))
        XCTAssertTrue(labels.contains("a weather"))
        XCTAssertEqual(labels.count, 2, "The two harbor pages dedupe to one label.")
        XCTAssertEqual(labels.count, Set(labels).count, "Labels must dedupe.")
    }

    // MARK: Weekly signature

    func testWeeklySignatureCountsRecentBoundPages() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let pages = [
            boundSouvenir(id: "s1", daysAgo: 2, from: now, input: "The rain made the parking lot look like a page under glass."),
            boundSouvenir(id: "s2", daysAgo: 1, from: now, input: "The bus window held the whole grey street for a moment.")
        ]
        let line = try XCTUnwrap(EditionCurator.weeklySignatureLine(monthPages: pages, now: now))
        XCTAssertTrue(line.contains("2 pages"))
        XCTAssertTrue(line.contains("June"))
        XCTAssertTrue(line.contains("all the way to the binding"))
        // Thread labels run through `featuredWord`, which now prefers the
        // concrete noun over the commonplace one: "glass" and "street" rather
        // than "parking" (a form of "park") or "moment".
        XCTAssertTrue(
            line.contains("glass") || line.contains("street") || line.contains("window"),
            "The signature should name a concrete thing from the week: \(line)"
        )
        XCTAssertFalse(line.contains("moment"), "Commonplace words are never featured: \(line)")
    }

    func testWeeklySignatureExcludesOlderThanAWeek() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let pages = [
            boundSouvenir(id: "s1", daysAgo: 2, from: now, input: "One recent kept sentence with real weather in it."),
            boundSouvenir(id: "old", daysAgo: 20, from: now, input: "A sentence from three weeks ago, long since bound.")
        ]
        // Only one page falls inside the trailing week, so no signature yet.
        XCTAssertNil(EditionCurator.weeklySignatureLine(monthPages: pages, now: now))
    }

    // MARK: Fixtures

    private func dayWithTwoProsePages() -> BookDay {
        BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [
                prosePage(id: "harbor", createdAtHour: 9, input: "Rain over the harbor."),
                prosePage(id: "cathedral", createdAtHour: 11, input: "The parking lot looked like a cathedral under rain.")
            ]
        )
    }

    private func emptyDay() -> BookDay {
        BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: []
        )
    }

    private func priorDay(id: String, month: Int, day: Int, input: String) -> BookDay {
        BookDay(
            id: id,
            date: Self.date(year: 2026, month: month, day: day, hour: 0),
            pages: [
                BookPage(
                    id: "\(id)-page",
                    type: .souvenir,
                    createdAt: Self.date(year: 2026, month: month, day: day, hour: 9),
                    promptText: "Catch one bright particular.",
                    userInput: input,
                    tags: ["souvenir"]
                )
            ]
        )
    }

    private func prosePage(id: String, createdAtHour: Int, input: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: Self.date(year: 2026, month: 6, day: 12, hour: createdAtHour),
            promptText: "Catch one bright particular.",
            userInput: input,
            tags: ["souvenir"]
        )
    }

    private func moodPage(id: String, createdAtHour: Int) -> BookPage {
        BookPage(
            id: id,
            type: .mood,
            createdAt: Self.date(year: 2026, month: 6, day: 12, hour: createdAtHour),
            promptText: "How is the weather inside?",
            userInput: "",
            tags: ["mood"]
        )
    }

    private func boundSouvenir(id: String, daysAgo: Int, from now: Date, input: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: now.addingTimeInterval(TimeInterval(-daysAgo) * 86_400),
            promptText: "Catch one bright particular.",
            userInput: input,
            tags: ["souvenir"],
            origin: .userAuthored
        )
    }

    // MARK: Keep floor, never a silent keep

    func testFloorNoteCatchesThinPublicKeeps() throws {
        // A keep too thin for a full cast voice still earns the Book's own line.
        let note = try XCTUnwrap(KeepMarginalia.floorNote(for: "tired today", pageType: .diary, pageID: "thin-1"))
        XCTAssertEqual(note.castSlug, "book-sprite")
        XCTAssertTrue(KeepMarginalia.floorLines.contains(note.line))
    }

    func testFloorNoteIsDeterministic() {
        XCTAssertEqual(
            KeepMarginalia.floorNote(for: "so tired", pageType: .diary, pageID: "thin-x"),
            KeepMarginalia.floorNote(for: "so tired", pageType: .diary, pageID: "thin-x")
        )
    }

    func testFloorNoteStaysOutOfPrivateEmptyAndSubstantialKeeps() {
        // Private logs stay silent.
        XCTAssertNil(KeepMarginalia.floorNote(for: "so tired", pageType: .body, pageID: "b"))
        // Truly empty keeps stay silent.
        XCTAssertNil(KeepMarginalia.floorNote(for: "   ", pageType: .diary, pageID: "e"))
        // Substantial keeps belong to the real cast voices, not the floor.
        XCTAssertNil(
            KeepMarginalia.floorNote(
                for: "The kettle sang twice before I noticed the morning had turned.",
                pageType: .diary,
                pageID: "rich"
            )
        )
    }

    // MARK: Braid pays off the ember

    func testKeptPromiseLineNamesTheEmbersThreads() throws {
        let line = try XCTUnwrap(BraidEmber.keptPromiseLine(for: dayWithTwoProsePages()))
        XCTAssertTrue(line.contains("harbor"))
        XCTAssertTrue(line.contains("cathedral"))
        XCTAssertTrue(line.hasPrefix("Last night the braid caught"))
    }

    func testKeptPromiseLineIsNilOnUnwrittenDays() {
        XCTAssertNil(BraidEmber.keptPromiseLine(for: emptyDay()))
    }

    func testKeptPromiseLineHandlesSingleThread() throws {
        let single = BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [prosePage(id: "solo", createdAtHour: 9, input: "Rain over the harbor.")]
        )
        let line = try XCTUnwrap(BraidEmber.keptPromiseLine(for: single))
        XCTAssertTrue(line.contains("single thread"))
        XCTAssertTrue(line.contains("harbor"))
    }

    func testWithPromiseEchoRoundTripsThroughTags() throws {
        let braid = BookPage(type: .bookOfYou, promptText: "Book of You: The Kept Harbor", userInput: "Body.")
        let line = try XCTUnwrap(BraidEmber.keptPromiseLine(for: dayWithTwoProsePages()))
        let stamped = BraidPageDetails.withPromiseEcho(braid, line: line)
        XCTAssertEqual(BraidPageDetails.details(for: stamped).promiseEcho, line)
        // A nil line leaves the page's tags untouched.
        XCTAssertEqual(BraidPageDetails.withPromiseEcho(braid, line: nil).tags, braid.tags)
    }

    func testDaytimeKeepPromiseNamesTheSpecificNewThread() throws {
        let noon = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let line = try XCTUnwrap(
            KeepMarginalia.braidGatheringLine(
                keptEarlierToday: 1,
                currentInput: "Rain over the harbor.",
                now: noon
            )
        )
        XCTAssertTrue(line.localizedCaseInsensitiveContains("harbor"))
        XCTAssertTrue(line.localizedCaseInsensitiveContains("tonight")
            || line.localizedCaseInsensitiveContains("evening"))
    }

    // Use the current calendar throughout: `BookDay.capturedPages` derives its
    // day window with `Calendar.current`, so fixtures must live in the same
    // timezone or they fall outside the window on non-UTC hosts.
    private static let nyCalendar = Calendar.current

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
}
