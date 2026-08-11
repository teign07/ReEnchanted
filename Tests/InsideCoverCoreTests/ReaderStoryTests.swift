import XCTest
@testable import InsideCoverCore

/// The reader's story: two shelves, threads that outlive a night, and seasons
/// only the reader may name.
final class ReaderStoryTests: XCTestCase {

    // MARK: - The two shelves

    func testShadowIsRecognisedButOrdinaryDaysStayLight() {
        let ordinary = page("The bread came out right for once and the kitchen smelled like a bakery.")
        XCTAssertEqual(ReaderShelf.of(ordinary), .light)

        let heavy = page("Sat in the hospital car park for an hour before I could go in.")
        XCTAssertEqual(ReaderShelf.of(heavy), .shadow)

        // A rainy, tired, slightly sad day is not shadow material. Over-reading
        // solemnity into ordinary days is the expensive mistake here.
        let greyButOrdinary = page("Rain all day, low energy, didn't get much done. Watched two films.")
        XCTAssertEqual(ReaderShelf.of(greyButOrdinary), .light)
    }

    func testSolitudeAndLaughterAreNeverMistakenForWeight() {
        // This app asks "what kind of being alone feels good?": reading
        // solitude as sorrow would get the reader exactly backwards.
        XCTAssertEqual(ReaderShelf.of(page("A whole evening alone with a book and the good lamp on.")), .light)
        XCTAssertEqual(ReaderShelf.of(page("We cried laughing at the state of the cake.")), .light)
        XCTAssertEqual(ReaderShelf.of(page("Absolutely died laughing when the dog stole it.")), .light)
    }

    func testReaderMarkOverridesInferenceInBothDirections() {
        var marked = page("The bread came out right for once.")
        marked.tags = [ReaderShelf.shadowTag]
        XCTAssertEqual(ReaderShelf.of(marked), .shadow)

        var unmarked = page("Sat in the hospital car park for an hour.")
        unmarked.tags = [ReaderShelf.lightTag]
        XCTAssertEqual(ReaderShelf.of(unmarked), .light)
    }

    func testSealedPagesLeaveTheWeaveEntirely() {
        var sealed = page("Something I only wanted written down, not used.")
        sealed.tags = [ReaderShelf.sealedTag]
        XCTAssertFalse(ReaderShelf.isWeavable(sealed))
        XCTAssertTrue(ReaderShelf.isWeavable(page("An ordinary keep.")))

        // The seal is enforced at the source, not merely asked for in a prompt.
        var marked = page("Something I only wanted written down, not used.")
        marked.tags = [ReaderShelf.sealedTag]
        let today = day("2026-07-01", pages: [marked, page("An ordinary keep about bread.")])
        let eligible = BraidPromptBuilder.braidEligiblePages(in: today)
        XCTAssertEqual(eligible.count, 1)
        XCTAssertFalse(BraidPromptBuilder.evidenceLines(for: today).joined().contains("only wanted written down"))
    }

    func testNeverWriteRemovesShadowPagesBeforeAnythingSeesThem() {
        let heavy = page("The funeral was on Tuesday. I did not speak.")
        let ordinary = page("Made soup and read on the balcony.")
        let today = day("2026-07-01", pages: [heavy, ordinary])

        var permissive = ReaderStory.empty
        permissive.shadowPermission = .onlyWhenOld
        XCTAssertEqual(BraidPromptBuilder.weavableDay(today, readerStory: permissive).capturedPages.count, 2)

        var refused = ReaderStory.empty
        refused.shadowPermission = .knowButNeverWrite
        let narrowed = BraidPromptBuilder.weavableDay(today, readerStory: refused)
        XCTAssertEqual(narrowed.capturedPages.count, 1)

        // Not "asked not to write it": genuinely absent from the evidence.
        let evidence = BraidPromptBuilder.evidenceLines(for: narrowed).joined()
        XCTAssertFalse(evidence.contains("funeral"))
        XCTAssertTrue(evidence.contains("soup"))
        XCTAssertTrue(BraidPromptBuilder.shadowSection(for: narrowed, context: .empty).isEmpty)
    }

    // MARK: - Open threads

    func testAnUnresolvedDayOpensExactlyOneThread() {
        let day = day(
            "2026-07-01",
            pages: [page("Waited at the table for an hour. He never came and never texted.")]
        )
        var story = ReaderStory.empty
        story.reconcile(day: day, reading: reading(motion: .vigil), now: day.date)

        XCTAssertEqual(story.openThreads.count, 1)
        XCTAssertEqual(story.openThreads[0].movement, .began)
        XCTAssertTrue(story.openThreads[0].isOpen)
    }

    func testAResolvedDayOpensNothing() {
        let day = day("2026-07-01", pages: [page("Finally fixed the gate hinge that has been loose since spring.")])
        var story = ReaderStory.empty
        story.reconcile(day: day, reading: reading(motion: .repair), now: day.date)
        XCTAssertTrue(story.openThreads.isEmpty)
    }

    func testThreadsNeverOpenTwoNightsRunningAndNeverExceedThree() {
        var story = ReaderStory.empty
        var when = iso("2026-07-01T21:00:00Z")

        for index in 0..<10 {
            let text = "Unfinished business number \(index) with entirely distinct wording \(index) throughout"
            let today = day("2026-07-\(String(format: "%02d", index + 1))", pages: [page(text)])
            story.reconcile(day: today, reading: reading(motion: .vigil, anchor: text), now: when)
            when = when.addingTimeInterval(86_400)
        }

        XCTAssertLessThanOrEqual(story.carriedThreads(now: when).count, ReaderStory.maximumCarriedThreads)
    }

    func testATouchedThreadDeepensAndAResolvingMotionClosesIt() {
        let opening = day("2026-07-01", pages: [page("The coat is still hanging in the hall where he left it.")])
        var story = ReaderStory.empty
        let openedAt = iso("2026-07-01T21:00:00Z")
        story.reconcile(day: opening, reading: reading(motion: .vigil), now: openedAt)
        XCTAssertEqual(story.openThreads.count, 1)

        let touching = day("2026-07-04", pages: [page("Moved the coat from the hall into the wardrobe today.")])
        story.reconcile(day: touching, reading: reading(motion: .crossing), now: openedAt.addingTimeInterval(3 * 86_400))

        XCTAssertEqual(story.openThreads[0].movement, .resolved)
        XCTAssertFalse(story.openThreads[0].isOpen)
        XCTAssertEqual(story.carriedThreads(now: openedAt.addingTimeInterval(3 * 86_400)).count, 0)
    }

    func testAnUntouchedThreadRestsRatherThanResolving() {
        let opening = day("2026-07-01", pages: [page("The coat is still hanging in the hall where he left it.")])
        var story = ReaderStory.empty
        let openedAt = iso("2026-07-01T21:00:00Z")
        story.reconcile(day: opening, reading: reading(motion: .vigil), now: openedAt)

        let muchLater = openedAt.addingTimeInterval(TimeInterval(ReaderStory.threadRestDays + 1) * 86_400)
        let unrelated = day("2026-07-23", pages: [page("Made soup. Read on the balcony until the light went.")])
        story.reconcile(day: unrelated, reading: reading(motion: .encounter, anchor: "Made soup"), now: muchLater)

        // Rest is not resolution: the distinction is the whole point.
        XCTAssertEqual(story.openThreads[0].movement, .rested)
        XCTAssertNotEqual(story.openThreads[0].movement, .resolved)
    }

    // MARK: - Named seasons

    func testNamingASeasonClosesThePriorOneAndDuplicatesAreIgnored() {
        var story = ReaderStory.empty
        let first = iso("2026-02-01T09:00:00Z")
        story.nameSeason("The Fog", at: first)
        XCTAssertEqual(story.currentSeason?.name, "The Fog")

        story.nameSeason("the fog", at: first.addingTimeInterval(86_400))
        XCTAssertEqual(story.seasons.count, 1, "Re-naming the same season should not start a new one")

        let second = first.addingTimeInterval(60 * 86_400)
        story.nameSeason("Getting Back to Colour", at: second)
        XCTAssertEqual(story.seasons.count, 2)
        XCTAssertEqual(story.currentSeason?.name, "Getting Back to Colour")
        XCTAssertEqual(story.priorSeasons.first?.name, "The Fog")
        XCTAssertEqual(story.priorSeasons.first?.endedAt, second)
    }

    // MARK: - The aging gate

    func testFreshShadowMayNotTakeTaleFormButAgedShadowMay() {
        let story = ReaderStory.empty
        let now = iso("2026-07-01T21:00:00Z")
        XCTAssertEqual(story.shadowPermission, .onlyWhenOld, "The unanswered default must be the cautious one")
        XCTAssertFalse(story.shadowMayTakeTaleForm(keptAt: now.addingTimeInterval(-3 * 86_400), now: now))
        XCTAssertTrue(
            story.shadowMayTakeTaleForm(
                keptAt: now.addingTimeInterval(-TimeInterval(ReaderStory.shadowTaleFormDays + 1) * 86_400),
                now: now
            )
        )
    }

    func testStandingPermissionOutranksAge() {
        let now = iso("2026-07-01T21:00:00Z")
        let ancient = now.addingTimeInterval(-400 * 86_400)

        var refused = ReaderStory.empty
        refused.shadowPermission = .knowButNeverWrite
        XCTAssertFalse(refused.shadowMayTakeTaleForm(keptAt: ancient, now: now), "Age must never override a refusal")

        var asks = ReaderStory.empty
        asks.shadowPermission = .askEachTime
        XCTAssertFalse(asks.shadowMayTakeTaleForm(keptAt: ancient, now: now), "Unasked must resolve to no")

        var allowed = ReaderStory.empty
        allowed.shadowPermission = .mayUse
        XCTAssertTrue(allowed.shadowMayTakeTaleForm(keptAt: now, now: now))
    }

    func testAmbiguousPermissionAnswersFallToTheStricterRule() {
        XCTAssertEqual(ReaderStory.shadowPermission(fromAnswer: "Know it, never write it"), .knowButNeverWrite)
        XCTAssertEqual(ReaderStory.shadowPermission(fromAnswer: "Ask me each time"), .askEachTime)
        XCTAssertEqual(ReaderStory.shadowPermission(fromAnswer: "You can use it"), .mayUse)
        XCTAssertEqual(ReaderStory.shadowPermission(fromAnswer: "Only once it's old"), .onlyWhenOld)
        // An answer the parser cannot read is never treated as broad permission.
        XCTAssertEqual(ReaderStory.shadowPermission(fromAnswer: "hmm, depends I suppose"), .onlyWhenOld)
        XCTAssertEqual(ReaderStory.shadowPermission(fromAnswer: ""), .onlyWhenOld)
    }

    func testARefusalReachesTheBraidAsAProhibition() {
        var story = ReaderStory.empty
        story.shadowPermission = .knowButNeverWrite
        var context = BraidPromptBuilder.Context()
        context.readerStory = story

        let heavy = day("2026-07-01", pages: [page("The funeral was on Tuesday. I did not speak.")])
        let section = BraidPromptBuilder.shadowSection(for: heavy, context: context)

        XCTAssertTrue(section.contains("you may not write it"))
        XCTAssertTrue(section.contains("not as image, not as echo"))
    }

    // MARK: - Prompt sections

    func testOpenThreadsReachThePromptAsQuestionNotMaterial() {
        var story = ReaderStory.empty
        story.openThreads = [
            OpenThread(
                id: "t1",
                line: "The coat is still hanging in the hall",
                shelf: .shadow,
                openedAt: iso("2026-06-20T21:00:00Z"),
                lastTouchedAt: iso("2026-06-20T21:00:00Z"),
                movement: .began,
                sourcePageID: nil,
                touchCount: 0,
                closedAt: nil
            )
        ]
        story.nameSeason("The Fog", at: iso("2026-06-01T09:00:00Z"))

        var context = BraidPromptBuilder.Context()
        context.readerStory = story
        let section = BraidPromptBuilder.readerStorySection(
            for: day("2026-07-01", pages: [page("An ordinary day.")]),
            context: context
        )

        XCTAssertTrue(section.contains("THREADS STILL OPEN"))
        XCTAssertTrue(section.contains("The coat is still hanging in the hall"))
        XCTAssertTrue(section.contains("These are not material"))
        XCTAssertTrue(section.contains("Never resolve a thread the evidence has not resolved"))
        XCTAssertTrue(section.contains("\"The Fog\""))
        XCTAssertTrue(section.contains("never declare it over"))
    }

    func testShadowSectionAppearsOnlyWithShadowMaterialAndForbidsTheRutRouting() {
        let ordinary = day("2026-07-01", pages: [page("Made soup and read on the balcony.")])
        XCTAssertTrue(BraidPromptBuilder.shadowSection(for: ordinary, context: .empty).isEmpty)

        let heavy = day("2026-07-01", pages: [page("The funeral was on Tuesday. I did not speak.")])
        let section = BraidPromptBuilder.shadowSection(for: heavy, context: .empty)

        XCTAssertTrue(section.contains("SHADOW LAW"))
        XCTAssertTrue(section.contains("Change the handle, never the weight"))
        XCTAssertTrue(section.contains("No consolation was asked for"))
        XCTAssertTrue(section.contains("This is not the Rut"))
    }

    // MARK: - Register safety

    func testConsolingOrResolvingProseFailsTheAuditOnShadowNights() {
        let heavy = day("2026-07-01", pages: [page("The funeral was on Tuesday. I did not speak.")])

        let consoling = "You did your best, and that was enough. The Book kept the page: the chairs stayed empty."
        XCTAssertTrue(BraidOutputAudit.registerIssues(in: consoling, for: heavy).contains(.consoledUnbidden))

        let closing = "By evening you had made peace with it. The Book kept the page: the chairs stayed empty."
        XCTAssertTrue(BraidOutputAudit.registerIssues(in: closing, for: heavy).contains(.resolvedTheUnresolved))

        let explaining = "It happened for a reason, and the lesson arrived later."
        XCTAssertTrue(BraidOutputAudit.registerIssues(in: explaining, for: heavy).contains(.assignedMeaning))

        let mindreading = "Deep down you felt the room close, and part of you wanted to run."
        XCTAssertTrue(BraidOutputAudit.registerIssues(in: mindreading, for: heavy).contains(.spokeForTheReader))

        let clean = "Tuesday. Eleven chairs, four of them filled. You stood at the back and did not speak. The Book kept the page: the chairs stayed empty."
        XCTAssertTrue(BraidOutputAudit.registerIssues(in: clean, for: heavy).isEmpty)
    }

    func testRegisterChecksStayOffOrdinaryDays() {
        // On a day with no weight, warmth is just warmth.
        let ordinary = day("2026-07-01", pages: [page("Made soup and read on the balcony.")])
        let warm = "You did your best with the stock, and made peace with the burnt edge."
        XCTAssertTrue(BraidOutputAudit.registerIssues(in: warm, for: ordinary).isEmpty)
    }

    func testRegisterFailuresOutrankCraftFailures() {
        XCTAssertTrue(BraidOutputAudit.Issue.consoledUnbidden.isRegisterFailure)
        XCTAssertTrue(BraidOutputAudit.Issue.spokeForTheReader.isRegisterFailure)
        XCTAssertFalse(BraidOutputAudit.Issue.tooShort.isRegisterFailure)
        XCTAssertFalse(BraidOutputAudit.Issue.missingRitualEnding.isRegisterFailure)
    }

    // MARK: - The shadow shelf gate

    func testShadowQuestionsExistButStayLockedUntilTheBookHasEarnedThem() {
        let shadow = SelfKnowledgePackRegistry.questions.filter {
            $0.tags.contains(SelfKnowledgePackRegistry.shadowTag)
        }
        XCTAssertGreaterThanOrEqual(shadow.count, 7, "The shelf needs a real second half, not a token question")

        // Nothing on the shadow shelf offers answers to try on, except the
        // consent question, which is a choice rather than an invitation.
        for question in shadow where question.id != SelfKnowledgePackRegistry.darkPermissionQuestionID {
            XCTAssertTrue(
                SelfKnowledgePackRegistry.exampleLines(for: question).isEmpty,
                "\(question.id) should not offer multiple choice"
            )
        }

        XCTAssertFalse(SelfKnowledgePackRegistry.isShadowShelfUnlocked(knownFacts: []))
        XCTAssertTrue(SelfKnowledgePackRegistry.isShadowShelfUnlocked(knownFacts: ordinaryFacts(count: 12)))
    }

    func testAReaderWhoClosedEveryDoorIsNeverAskedAShadowQuestion() {
        let facts = ordinaryFacts(count: 12) + [
            fact(id: "story-no", questionID: "story-no", answer: "Everything. I'd rather you didn't use any of it.")
        ]
        XCTAssertFalse(SelfKnowledgePackRegistry.isShadowShelfUnlocked(knownFacts: facts))
    }

    func testConsentIsAskedBeforeTheQuestionsItGoverns() {
        let facts = ordinaryFacts(count: 20)
        var seen: Set<String> = []
        var asked: [String] = []
        var known = facts

        // Walk the shelf and record the order shadow questions arrive in.
        for index in 0..<40 {
            guard let next = SelfKnowledgePackRegistry.nextQuestion(
                knownFacts: known,
                day: day("2026-07-\(String(format: "%02d", (index % 28) + 1))", pages: []),
                now: iso("2026-07-01T09:00:00Z").addingTimeInterval(TimeInterval(index) * 86_400)
            ) else { break }
            guard !seen.contains(next.id) else { break }
            seen.insert(next.id)
            if next.tags.contains(SelfKnowledgePackRegistry.shadowTag) { asked.append(next.id) }
            known.append(fact(id: next.id, questionID: next.id, answer: "an answer", tags: next.tags))
        }

        if let first = asked.first {
            XCTAssertEqual(
                first,
                SelfKnowledgePackRegistry.darkPermissionQuestionID,
                "Consent must be the first shadow question the reader ever sees"
            )
        }
    }

    func testShadowAnswersAreReceivedNotBrightened() {
        let question = SelfKnowledgePackRegistry.question(id: "carrying")!
        let translation = SelfKnowledgePackRegistry.translation(for: question, answer: "My mother is ill.")

        // No thanks, no reframe, no promise to make something lovely of it, and
        // never the answer itself echoed back on the shelf.
        for reflex in ["thank", "beautiful", "lovely", "gift", "grateful", "brave", "journey"] {
            XCTAssertFalse(translation.lowercased().contains(reflex), "Shadow translation should not \(reflex)")
        }
        XCTAssertFalse(translation.contains("My mother is ill."))
    }

    // MARK: - The backwards question

    func testTheBookAsksAboutASeasonTheReaderClosed() {
        var story = ReaderStory.empty
        story.nameSeason("The Fog", at: iso("2026-01-01T09:00:00Z"))
        story.nameSeason("Getting Back to Colour", at: iso("2026-04-01T09:00:00Z"))

        let question = BraidBackwardQuestion.question(
            for: day("2026-07-01", pages: [page("Made soup and read on the balcony.")]),
            story: story,
            days: [],
            now: iso("2026-07-01T21:00:00Z")
        )

        let line = try? XCTUnwrap(question?.line)
        XCTAssertEqual(question?.key, "season:\(story.priorSeasons[0].id)")
        XCTAssertTrue(line?.contains("The Fog") == true)
        // Asks when it ended; never what it meant.
        XCTAssertTrue(line?.contains("Tell me if you want that door open. Otherwise it stays shut.") == true)
    }

    func testTheQuestionIsAlwaysBackwardsNeverForwards() {
        var story = ReaderStory.empty
        story.nameSeason("The Fog", at: iso("2026-01-01T09:00:00Z"))
        story.nameSeason("After", at: iso("2026-04-01T09:00:00Z"))
        story.openThreads = [restedThread(closedAt: iso("2026-05-01T21:00:00Z"))]

        let ordinary = day("2026-07-01", pages: [page("Made soup and read on the balcony.")])
        let old = [day("2026-01-05", pages: [page("The gate hinge has been loose since spring.")])]

        // Whichever candidate the seed lands on, it may not commission anything.
        for offset in 0..<12 {
            var probe = story
            probe.lastBackwardQuestionAt = nil
            let when = iso("2026-07-01T21:00:00Z").addingTimeInterval(TimeInterval(offset) * 86_400)
            guard let question = BraidBackwardQuestion.question(
                for: ordinary, story: probe, days: old, now: when
            ) else { continue }
            let line = question.line.lowercased()
            for commissioning in ["tomorrow", "this week", "try ", "go and", "next time", "you should", "why don't you"] {
                XCTAssertFalse(line.contains(commissioning), "Backwards question drifted forwards: \(question.line)")
            }
        }
    }

    func testTheBookNeverAsksTwiceAndRespectsItsCooldown() {
        var story = ReaderStory.empty
        story.nameSeason("The Fog", at: iso("2026-01-01T09:00:00Z"))
        story.nameSeason("After", at: iso("2026-04-01T09:00:00Z"))
        let today = day("2026-07-01", pages: [page("Made soup and read on the balcony.")])
        let now = iso("2026-07-01T21:00:00Z")

        let first = BraidBackwardQuestion.question(for: today, story: story, days: [], now: now)
        XCTAssertNotNil(first)

        // Asked once, never again, even years later.
        story.askedBackwardKeys = [first!.key]
        XCTAssertNil(
            BraidBackwardQuestion.question(for: today, story: story, days: [], now: now.addingTimeInterval(900 * 86_400))
        )

        // And the cooldown holds even when a fresh subject exists.
        var cooling = ReaderStory.empty
        cooling.nameSeason("The Fog", at: iso("2026-01-01T09:00:00Z"))
        cooling.nameSeason("After", at: iso("2026-04-01T09:00:00Z"))
        cooling.lastBackwardQuestionAt = now.addingTimeInterval(-3 * 86_400)
        XCTAssertNil(BraidBackwardQuestion.question(for: today, story: cooling, days: [], now: now))
    }

    func testTheBookNeverAsksOnADayThatIsCarryingSomething() {
        var story = ReaderStory.empty
        story.nameSeason("The Fog", at: iso("2026-01-01T09:00:00Z"))
        story.nameSeason("After", at: iso("2026-04-01T09:00:00Z"))

        let heavy = day("2026-07-01", pages: [page("The funeral was on Tuesday. I did not speak.")])
        XCTAssertNil(
            BraidBackwardQuestion.question(for: heavy, story: story, days: [], now: iso("2026-07-01T21:00:00Z")),
            "A day already carrying weight is not the night to ask for more"
        )
    }

    func testARestedThreadHasToSettleBeforeItIsAskedAbout() {
        var story = ReaderStory.empty
        let closedAt = iso("2026-06-29T21:00:00Z")
        story.openThreads = [restedThread(closedAt: closedAt)]
        let today = day("2026-07-01", pages: [page("Made soup and read on the balcony.")])

        XCTAssertNil(
            BraidBackwardQuestion.question(for: today, story: story, days: [], now: closedAt.addingTimeInterval(2 * 86_400))
        )
        let settled = BraidBackwardQuestion.question(
            for: today,
            story: story,
            days: [],
            now: closedAt.addingTimeInterval(TimeInterval(BraidBackwardQuestion.restedThreadSettlingDays + 1) * 86_400)
        )
        XCTAssertTrue(settled?.line.contains("I stopped asking") == true)
    }

    func testTheQuestionRidesBelowTheRitualEndingNotInsideIt() {
        let braid = BookPage(
            type: .bookOfYou,
            createdAt: iso("2026-07-01T21:00:00Z"),
            promptText: "Book of You",
            userInput: "Soup, and the balcony. The Book kept the page: the stock was better than the recipe.",
            tags: []
        )
        let marked = BraidPageDetails.withBackwardQuestion(
            braid,
            question: .init(key: "season:x", line: "You used to call that stretch \u{201C}The Fog.\u{201D}")
        )

        // Carried as page metadata, so it can never be mistaken for braid prose
        // and can never displace "The Book kept the page:".
        XCTAssertEqual(marked.userInput, braid.userInput)
        XCTAssertEqual(BraidPageDetails.details(for: marked).backwardQuestion, "You used to call that stretch \u{201C}The Fog.\u{201D}")
        XCTAssertNil(BraidPageDetails.details(for: braid).backwardQuestion)
    }

    private func restedThread(closedAt: Date) -> OpenThread {
        OpenThread(
            id: "t-rested",
            line: "the gate hinge that has been loose since spring",
            shelf: .light,
            openedAt: closedAt.addingTimeInterval(-30 * 86_400),
            lastTouchedAt: closedAt.addingTimeInterval(-30 * 86_400),
            movement: .rested,
            sourcePageID: nil,
            touchCount: 0,
            closedAt: closedAt
        )
    }

    // MARK: - Helpers

    private func page(_ text: String) -> BookPage {
        BookPage(
            type: .souvenir,
            createdAt: iso("2026-07-01T12:00:00Z"),
            promptText: "One true thing",
            userInput: text,
            tags: []
        )
    }

    /// Re-stamps every page into the day it belongs to. `BookDay.capturedPages`
    /// filters by timestamp, so a page dated elsewhere silently vanishes from
    /// the braid: midday UTC keeps the day stable across time zones.
    private func day(_ id: String, pages: [BookPage]) -> BookDay {
        let noon = iso("\(id)T12:00:00Z")
        return BookDay(
            id: id,
            date: noon,
            pages: pages.map { page in
                var stamped = page
                stamped.createdAt = noon
                return stamped
            }
        )
    }

    private func reading(
        motion: BraidPromptBuilder.NarrativeMotion,
        pressure: BraidPromptBuilder.FaeriePressure = .witness,
        anchor: String = "The coat is still hanging in the hall where he left it"
    ) -> BraidPromptBuilder.TaleReading {
        BraidPromptBuilder.TaleReading(
            scale: .small,
            motion: motion,
            pressure: pressure,
            anchorPageID: nil,
            anchor: anchor,
            turn: nil,
            visibleSupportingLogs: false
        )
    }

    private func fact(id: String, questionID: String, answer: String, tags: [String] = []) -> SelfFact {
        SelfFact(
            id: id,
            questionID: questionID,
            question: questionID,
            answer: answer,
            bookTranslation: answer,
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: tags,
            createdAt: iso("2026-01-01T09:00:00Z"),
            updatedAt: iso("2026-01-01T09:00:00Z")
        )
    }

    private func ordinaryFacts(count: Int) -> [SelfFact] {
        (0..<count).map { fact(id: "ordinary-\($0)", questionID: "ordinary-\($0)", answer: "something light") }
    }

    private func iso(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
