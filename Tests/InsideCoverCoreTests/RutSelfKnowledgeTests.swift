import XCTest
@testable import InsideCoverCore

final class RutSelfKnowledgeTests: XCTestCase {
    func testProgressiveYouShelfIsBroadUniqueAndStillOptional() throws {
        let questions = SelfKnowledgePackRegistry.questions
        XCTAssertGreaterThanOrEqual(questions.count, 45)
        XCTAssertEqual(Set(questions.map(\.id)).count, questions.count)
        XCTAssertEqual(SelfKnowledgePackRegistry.maxAboutYouFactsPerDay, 5)
        XCTAssertEqual(SelfKnowledgePackRegistry.minimumHoursBetweenAboutYouFacts, 1)

        for id in ["favorite-weather", "sensory-door", "best-time", "social-energy", "leaving-home", "movement-access", "time-budget", "money-boundary", "desired-surprise"] {
            let question = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: id))
            XCTAssertFalse(SelfKnowledgePackRegistry.exampleLines(for: question).isEmpty, "Missing choices for \(id)")
            XCTAssertEqual(SelfKnowledgePackRegistry.choicePrompt(for: question), "A FEW ANSWERS TO TRY ON")
        }
        XCTAssertEqual(
            try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "story-no")).defaultUsePermission,
            .doNotUse
        )
    }

    func testFreshUnnamedPlaceOffersAConsentPageWithoutCoordinates() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.currentLocationLabel = "Belfast"
        inputs.currentPlaceNamingOpportunityID = "opaque-opportunity"

        let pages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let place = try XCTUnwrap(pages.first { $0.payload.metadata["placeNamingOffer"] == "true" })

        XCTAssertEqual(place.type, .aboutYou)
        XCTAssertEqual(place.payload.metadata["questionID"], "familiar-place-opaque-opportunity")
        XCTAssertTrue(place.payload.metadata["exampleLines"]?.contains("Home") == true)
        XCTAssertTrue(place.payload.metadata["exampleLines"]?.contains("Don't remember this place") == true)
        XCTAssertFalse(place.payload.metadata.keys.contains { $0.lowercased().contains("latitude") || $0.lowercased().contains("longitude") })
        XCTAssertFalse(place.payload.metadata.values.contains { $0.contains("54.") || $0.contains("-5.") })

        inputs.currentPlaceContext = .home
        let recognizedPages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        XCTAssertFalse(recognizedPages.contains { $0.payload.metadata["placeNamingOffer"] == "true" })
    }

    func testRutQuestionsAreHighPriorityAndPlainSpoken() throws {
        let signal = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-signal"))
        let depth = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth"))
        let season = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-season"))
        let entry = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "wonder-entry"))
        let home = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "home-place"))

        XCTAssertGreaterThan(signal.priority, home.priority)
        XCTAssertGreaterThan(depth.priority, home.priority)
        XCTAssertGreaterThan(season.priority, home.priority)
        XCTAssertGreaterThan(entry.priority, home.priority)

        XCTAssertTrue(signal.prompt.contains("that's me"))
        XCTAssertTrue(signal.detail.contains("not diagnosing"))
        XCTAssertEqual(SelfKnowledgePackRegistry.exampleLines(for: signal).count, 5)
        XCTAssertTrue(SelfKnowledgePackRegistry.exampleLines(for: signal).allSatisfy { $0.hasSuffix(".") })
        XCTAssertTrue(SelfKnowledgePackRegistry.exampleLines(for: home).isEmpty)
        XCTAssertTrue(depth.detail.contains("weather report"))
        XCTAssertTrue(season.detail.contains("teeth"))
        XCTAssertTrue(entry.detail.contains("tired Tuesday"))
    }

    func testRutTranslationsKeepLabelsAsStateNotIdentity() throws {
        let depth = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth"))
        let season = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-season"))
        let entry = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "wonder-entry"))

        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: depth, answer: "4-7: in the rut"),
            "I'll treat this as a weather report, not a diagnosis: 4-7: in the rut."
        )
        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: season, answer: "The Too-Many-Tabs Era"),
            "I'll call this season The Too-Many-Tabs Era when it needs to name the gray without making it permanent."
        )
        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: entry, answer: "a snack walk"),
            "I'll start near a snack walk when wonder needs to feel easy."
        )

        let earned = AboutYouQuestion(
            id: "earned-wonder-label",
            packID: SelfKnowledgePackRegistry.corePackID,
            prompt: "Your First Working Title",
            detail: "",
            placeholder: "",
            sensitivity: .identity,
            defaultUsePermission: .privateContext,
            tags: ["earned-label"],
            priority: 0
        )
        XCTAssertEqual(
            SelfKnowledgePackRegistry.translation(for: earned, answer: "Proofkeeper"),
            "I treat this as an earned working title, not a personality box: Proofkeeper."
        )
    }

    func testRutRecognitionLinesComeFromReaderAuthoredKeeps() {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let pages = [
            BookPage(
                id: "souvenir",
                type: .souvenir,
                createdAt: now,
                promptText: "Keep one sentence.",
                userInput: "The grocery store flowers looked braver than I felt.",
                tags: ["souvenir"]
            ),
            BookPage(
                id: "mission",
                type: .wonderCompass,
                createdAt: now.addingTimeInterval(-60),
                promptText: "Find the smallest rebellion.",
                userInput: "A weed had pushed straight through the painted curb.",
                tags: ["playful-mission"]
            ),
            BookPage(
                id: "letter",
                type: .letter,
                createdAt: now.addingTimeInterval(-120),
                promptText: "A generated letter that must not become a choice.",
                userInput: "Generated letter prose.",
                playerReply: "I think I have been waiting for permission to begin."
            )
        ]

        let lines = AboutYouPageSourceAdapter.readerLines(in: pages)

        XCTAssertEqual(lines.map(\.text), [
            "I think I have been waiting for permission to begin.",
            "The grocery store flowers looked braver than I felt.",
            "A weed had pushed straight through the painted curb."
        ])
        XCTAssertEqual(lines.map(\.source), [
            "a letter you answered",
            "a one-sentence souvenir",
            "a playful mission"
        ])
        XCTAssertFalse(lines.contains { $0.text == "Generated letter prose." })
    }

    func testRutRecognitionSurfacesBeforeGeneralAboutYouQuestions() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let first = try XCTUnwrap(SelfKnowledgePackRegistry.nextQuestion(knownFacts: [], day: day, now: now))
        XCTAssertEqual(first.id, "rut-signal")

        let answeredSignal = selfFact(for: first, answer: "Phone fog", now: now)
        let second = try XCTUnwrap(SelfKnowledgePackRegistry.nextQuestion(knownFacts: [answeredSignal], day: day, now: now))
        XCTAssertEqual(second.id, "rut-depth")
    }

    func testFirstInterestFollowsOnboardingNameWithoutWaitingBehindRutSequence() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let name = SelfFact(
            id: "onboarding:name",
            questionID: "name",
            question: "What should the Book call you?",
            answer: "Avery",
            bookTranslation: "The Book may call you Avery.",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["name", "identity"],
            createdAt: now,
            updatedAt: now
        )

        let next = try XCTUnwrap(
            SelfKnowledgePackRegistry.nextQuestion(knownFacts: [name], day: day, now: now)
        )

        XCTAssertEqual(next.id, "interest-01")

        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [name] + (0..<6).map { index in
            SelfFact(
                id: "onboarding-extra-\(index)",
                questionID: "onboarding-extra-\(index)",
                question: "First Door detail",
                answer: "Answer \(index)",
                bookTranslation: "Answer \(index)",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["onboarding"],
                createdAt: now,
                updatedAt: now
            )
        }
        let pages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now.addingTimeInterval(60)
        )
        let interestPage = try XCTUnwrap(pages.first { $0.payload.metadata["questionID"] == "interest-01" })
        XCTAssertEqual(interestPage.score, 91)
        XCTAssertTrue(interestPage.reason.contains("The Bleed"))
    }

    func testColdStartQuestionTargetsTheContextualUncertaintyThatWouldChangeCuration() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let interest = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "interest-01"))
        let facts = [
            SelfFact(
                id: "onboarding-name",
                questionID: "onboarding-name",
                question: "What should the Book call you?",
                answer: "Avery",
                bookTranslation: "Avery",
                sensitivity: .identity,
                usePermission: .privateContext,
                tags: ["name", "onboarding"],
                createdAt: now.addingTimeInterval(-7_200),
                updatedAt: now.addingTimeInterval(-7_200)
            ),
            SelfFact(
                id: "onboarding-magic",
                questionID: "onboarding-magic-source",
                question: "What actually feels like magic?",
                answer: "Wild weather",
                bookTranslation: "Begin with wild weather sometimes.",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["onboarding", "curation-signal"],
                createdAt: now.addingTimeInterval(-7_100),
                updatedAt: now.addingTimeInterval(-7_100)
            ),
            selfFact(
                for: interest,
                answer: "Old maps",
                now: now.addingTimeInterval(-7_000)
            )
        ]

        let next = try XCTUnwrap(SelfKnowledgePackRegistry.nextQuestion(
            knownFacts: facts,
            day: day,
            now: now,
            coldStart: CausalColdStartQuestionContext(hasWeatherContext: true)
        ))

        XCTAssertEqual(next.id, "favorite-weather")
        XCTAssertTrue(SelfKnowledgePackRegistry.isCausalColdStartQuestion(next.id))
    }

    func testAboutYouMarksColdStartQuestionsAndLimitsThemToOnePerLivedDay() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let name = SelfFact(
            id: "name",
            questionID: "onboarding-name",
            question: "Name",
            answer: "Avery",
            bookTranslation: "Avery",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["name", "onboarding"],
            createdAt: now.addingTimeInterval(-8_000),
            updatedAt: now.addingTimeInterval(-8_000)
        )
        let interestQuestion = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "interest-01"))
        let interest = selfFact(
            for: interestQuestion,
            answer: "Old maps",
            now: now.addingTimeInterval(-7_000)
        )
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [name, interest]

        let pages = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let directed = try XCTUnwrap(pages.first {
            $0.payload.metadata["causalColdStartQuestion"] == "true"
        })
        XCTAssertEqual(directed.score, 77)
        XCTAssertTrue(directed.reason.contains("change which real door"))

        let answeredQuestion = try XCTUnwrap(
            SelfKnowledgePackRegistry.question(
                id: directed.payload.metadata["questionID"] ?? ""
            )
        )
        inputs.selfFacts.append(
            selfFact(for: answeredQuestion, answer: "Ten minutes", now: now)
        )
        let sameDay = AboutYouPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now.addingTimeInterval(2 * 3_600)
        )

        XCTAssertFalse(sameDay.contains {
            $0.payload.metadata["causalColdStartQuestion"] == "true"
        })
    }

    /// The role itself is handed over during onboarding. This page is the later
    /// proof that the naming was not a party trick, so it waits for a real
    /// shelf: five kept pages across at least two distinct days.
    func testRoleReceiptsPageWaitsForRealEvidence() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            selfFact(for: try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-signal")), answer: "Phone fog", now: now),
            selfFact(for: try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth")), answer: "4-7: in the rut", now: now)
        ]

        func receiptsPage(_ inputs: BookSourceInputs) -> SurfacePage? {
            AboutYouPageSourceAdapter().candidates(
                for: today,
                context: CuratorContext.make(for: today),
                inputs: inputs,
                now: now
            ).first { $0.payload.metadata["earnedLabel"] == "true" }
        }

        XCTAssertNil(receiptsPage(inputs), "no kept pages at all should never earn receipts")

        // One busy day is not evidence — the claim is that the role holds up
        // over time, so a single sitting must not satisfy it.
        let yesterday = now.addingTimeInterval(-86_400)
        func page(_ text: String, at date: Date) -> BookPage {
            BookPage(type: .souvenir, createdAt: date, promptText: "Catch one real thing.", userInput: text, tags: ["souvenir"])
        }
        inputs.days = [
            BookDay(id: BookDay.id(for: yesterday), date: yesterday, pages: [
                page("I put the phone down and noticed the window light.", at: yesterday),
                page("The screen kept eating the quiet, but I came back.", at: yesterday),
                page("Rain on the skylight for a whole minute.", at: yesterday),
                page("The bus was late and the sky was doing something.", at: yesterday),
                page("Somebody's radio, two streets over.", at: yesterday)
            ])
        ]
        XCTAssertNil(receiptsPage(inputs), "five pages in one day is one sitting, not a pattern")

        // A second day crosses the floor.
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)
        inputs.days.append(
            BookDay(id: BookDay.id(for: twoDaysAgo), date: twoDaysAgo, pages: [
                page("A stranger's laugh in the stairwell.", at: twoDaysAgo)
            ])
        )

        let earned = try XCTUnwrap(receiptsPage(inputs))
        XCTAssertEqual(earned.payload.metadata["questionID"], "earned-wonder-label")
        let role = try XCTUnwrap(ReaderRoleRegistry.currentRole(from: inputs.selfFacts))
        XCTAssertEqual(earned.payload.metadata["earnedLabelName"], role.fullName)
        XCTAssertEqual(earned.payload.headline, role.fullName)
        // The Book stands behind the night-one claim rather than hedging it.
        XCTAssertTrue(earned.payload.body.contains("I called you \(role.role.name)"))
        XCTAssertTrue(earned.payload.body.contains("I was right about you."))
        XCTAssertFalse(earned.payload.body.contains("Not a personality box"))
    }

    func testEarnedWonderTitleShapesCompassAndScoring() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var titledInputs = BookSourceInputs.empty
        titledInputs.selfFacts = [earnedTitleFact("Pocket Adventurer", now: now)]

        let compass = WonderCompassPageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: titledInputs,
            now: now
        )
        // Stored under the pre-rename id; it still resolves, now as The Detourist.
        XCTAssertEqual(compass.payload.metadata["wonderTitleName"], "The Detourist")
        XCTAssertTrue(compass.detail.contains("The Detourist"))
        // The Detourist's compass line, rewritten with the taxonomy.
        XCTAssertTrue(compass.payload.body.contains("Go the wrong way on purpose"))

        let plainMood = CuratorMood.make(inputs: .empty, now: now)
        let titledMood = CuratorMood.make(inputs: titledInputs, now: now)
        let anchor = SurfacePage(type: .anchor, prompt: "A nearby door", detail: "Try a tiny outing.")
        XCTAssertGreaterThan(
            titledMood.adjustment(for: anchor, now: now),
            plainMood.adjustment(for: anchor, now: now)
        )
    }

    func testCuratorAssumesRoutineAtTheEdgesAndFightsItBeforeNamingIt() {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let assessment = NothingTide.rutAssessment(
            inputs: .empty,
            distressActive: false,
            now: now
        )
        XCTAssertEqual(assessment.pressure, 1)
        XCTAssertFalse(assessment.mayNameRut)

        var mood = CuratorMood.make(inputs: .empty, now: now)
        mood.isFirstHours = false
        mood.keptPageCount = 100
        let warning = rutWarningSurface()
        let smallDoor = SurfacePage(
            type: .anchor,
            prompt: "A nearby door",
            detail: "Change scale for ten minutes."
        )

        XCTAssertFalse(mood.allows(warning))
        XCTAssertGreaterThan(
            mood.adjustment(for: smallDoor, now: now),
            CuratorMood.neutral.adjustment(for: smallDoor, now: now)
        )
    }

    func testCurrentReaderRutReportAllowsOneProvisionalWarning() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let depth = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth"))
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [selfFact(for: depth, answer: "4-7: in the rut", now: now)]

        let assessment = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: false,
            now: now
        )
        XCTAssertEqual(assessment.pressure, 2)
        XCTAssertTrue(assessment.mayNameRut)

        var mood = CuratorMood.make(inputs: inputs, now: now)
        mood.isFirstHours = false
        mood.keptPageCount = 100
        XCTAssertTrue(mood.allows(rutWarningSurface()))
    }

    func testAppSilenceNeitherRaisesRutPressureNorAccusesTheReader() {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        var inputs = BookSourceInputs.empty
        inputs.quietDays = 4

        let assessment = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: false,
            now: now
        )

        XCTAssertEqual(assessment.pressure, 1)
        XCTAssertFalse(assessment.mayNameRut)
        XCTAssertFalse(assessment.evidence.contains { $0.contains("quiet-days") })
    }

    func testReaderNamedRutSignalCanRaiseStoryPressureWithoutAppAttendanceEvidence() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let signal = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-signal"))
        var inputs = BookSourceInputs.empty
        inputs.quietDays = 0
        inputs.selfFacts = [selfFact(for: signal, answer: "Phone fog", now: now)]

        let assessment = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: false,
            now: now
        )

        XCTAssertEqual(assessment.pressure, 2)
        XCTAssertTrue(assessment.mayNameRut)
        XCTAssertTrue(assessment.evidence.contains("reader-recognized-rut-signal"))
    }

    func testAntiRutCurationUsesTheReadersLowFrictionWonderDoor() {
        let pocketDoor = SurfacePage(
            type: .anchor,
            prompt: "A nearby door",
            detail: "A pocket-sized outing."
        )
        let genericOddity = SurfacePage(
            type: .quip,
            prompt: "An oddity",
            detail: "One strange sentence."
        )

        XCTAssertGreaterThan(
            RutInterventionPolicy.scoreBoost(
                for: pocketDoor,
                pressure: 2,
                preferredDoor: "A pocket adventure"
            ),
            RutInterventionPolicy.scoreBoost(
                for: genericOddity,
                pressure: 2,
                preferredDoor: "A pocket adventure"
            )
        )
    }

    func testDistressSilencesBothRutWarningAndAntiRutPressure() throws {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let depth = try XCTUnwrap(SelfKnowledgePackRegistry.question(id: "rut-depth"))
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [selfFact(for: depth, answer: "8-10: whirlpool", now: now)]

        let assessment = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: true,
            now: now
        )

        XCTAssertEqual(assessment.pressure, 0)
        XCTAssertFalse(assessment.mayNameRut)
    }

    func testAttentionProbeCyclePausesThenReturnsInsteadOfGraduating() {
        let start = Date(timeIntervalSince1970: 1_783_484_800)
        var ledger = AttentionProbeLedger.empty
        for index in 0..<ledger.currentCycleTarget {
            let scheduled = start.addingTimeInterval(Double(index) * 3_600)
            ledger.record(
                id: "sample-\(index)",
                scheduledAt: scheduled,
                answeredAt: scheduled.addingTimeInterval(12),
                answer: index.isMultiple(of: 2) ? .here : .elsewhere,
                cycle: 0
            )
        }

        XCTAssertNotNil(ledger.pausedUntil)
        XCTAssertEqual(
            ledger.latestCompletedCycle?.answeredCount,
            AttentionProbeLedger.target(for: 0)
        )
        XCTAssertFalse(ledger.shouldSchedule(now: start.addingTimeInterval(2 * 86_400)))

        let returned = ledger.reconciled(now: start.addingTimeInterval(12 * 86_400))
        XCTAssertEqual(returned.currentCycle, 1)
        XCTAssertNil(returned.pausedUntil)
        XCTAssertTrue(returned.shouldSchedule(now: start.addingTimeInterval(12 * 86_400)))
    }

    func testUnansweredAttentionKnocksRemainUnknownForever() {
        let start = Date(timeIntervalSince1970: 1_783_484_800)
        var ledger = AttentionProbeLedger.empty
        ledger.record(
            id: "the-only-answer",
            scheduledAt: start,
            answeredAt: start.addingTimeInterval(9),
            answer: .elsewhere,
            cycle: 0
        )

        let muchLater = ledger.reconciled(now: start.addingTimeInterval(180 * 86_400))
        XCTAssertEqual(muchLater.currentCycleAnswerCount, 1)
        XCTAssertEqual(muchLater.currentCycleElsewhereCount, 1)
        XCTAssertNil(muchLater.latestCompletedCycle)
        XCTAssertEqual(
            muchLater.currentCycle,
            0,
            "elapsed time and unanswered opportunities must never be recoded as Elsewhere"
        )
    }

    func testAttentionStudyKeepsAFiftyDayRunwayWithoutStackingDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let start = calendar.startOfDay(for: now)

        let slots = AttentionProbeSchedule.slots(
            ledger: .empty,
            startingAt: start,
            now: now,
            calendar: calendar
        )

        XCTAssertGreaterThanOrEqual(slots.count, AttentionProbeSchedule.horizonDays - 1)
        XCTAssertEqual(Set(slots.map(\.dayID)).count, slots.count)
        XCTAssertEqual(Set(slots.map(\.id)).count, slots.count)
        XCTAssertTrue(slots.allSatisfy { $0.cycle == 0 && $0.fireAt > now })
    }

    func testCompletedAttentionSeasonsProduceAnAnsweredOnlyComparison() throws {
        let start = Date(timeIntervalSince1970: 1_783_484_800)
        var ledger = AttentionProbeLedger.empty

        func finishCycle(_ cycle: Int, elsewhereCount: Int, start: Date) {
            let target = AttentionProbeLedger.target(for: cycle)
            for index in 0..<target {
                let scheduled = start.addingTimeInterval(Double(index) * 3_600)
                ledger.record(
                    id: "cycle-\(cycle)-sample-\(index)",
                    scheduledAt: scheduled,
                    answeredAt: scheduled.addingTimeInterval(8),
                    answer: index < elsewhereCount ? .elsewhere : .here,
                    cycle: cycle
                )
            }
        }

        finishCycle(0, elsewhereCount: 10, start: start)
        ledger = ledger.reconciled(now: start.addingTimeInterval(12 * 86_400))
        let secondStart = start.addingTimeInterval(12 * 86_400)
        finishCycle(1, elsewhereCount: 20, start: secondStart)

        let comparison = try XCTUnwrap(ledger.latestCycleComparison)
        XCTAssertEqual(comparison.previous.cycle, 0)
        XCTAssertEqual(comparison.current.cycle, 1)
        XCTAssertGreaterThan(comparison.elsewherePercentagePointChange, 0)
        XCTAssertEqual(
            comparison.current.answeredCount,
            comparison.current.hereCount + comparison.current.elsewhereCount,
            "only answered knocks are allowed into the comparison"
        )
    }

    func testLongUseWithoutFlatteningCannotSummonLaterGrey() {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        let braids = (0..<24).map { index in
            BookPage(
                id: "braid-varied-\(index)",
                type: .bookOfYou,
                createdAt: now.addingTimeInterval(-(60 - Double(index) * 2.5) * 86_400),
                promptText: "Braid \(index)",
                userInput: "A distinct page \(index) kept its own particular detail.",
                origin: .simulated
            )
        }

        let assessment = BookFamiliarityRutEngine.assess(
            pages: braids,
            readerLearning: ReaderLearningModel(),
            attentionProbes: .empty,
            now: now
        )

        XCTAssertEqual(assessment.phase, .familiar)
        XCTAssertFalse(assessment.mayThreaten)
        XCTAssertTrue(assessment.evidence.isEmpty)
    }

    func testLaterGreyRequiresContinuedUseAndIndependentFlatteningSignals() {
        let now = Date(timeIntervalSince1970: 1_783_484_800)
        var pages = (0..<24).map { index in
            BookPage(
                id: "braid-flat-\(index)",
                type: .bookOfYou,
                createdAt: now.addingTimeInterval(-(60 - Double(index) * 2.5) * 86_400),
                promptText: "Braid \(index)",
                userInput: "A kept Braid with detail \(index).",
                origin: .simulated
            )
        }
        pages += (0..<18).map { index in
            BookPage(
                id: "clockwork-\(index)",
                type: .souvenir,
                createdAt: now.addingTimeInterval(-Double(18 - index) * 86_400 + 8 * 3_600),
                promptText: "One sentence",
                userInput: "same words",
                origin: .userAuthored
            )
        }
        let facts = (1...2).map { index in
            SelfFact(
                id: "book-memory-\(index)",
                questionID: "book-memory-probe-\(index)",
                question: "What stayed from the last Braid?",
                answer: "I remember nothing",
                bookTranslation: "The Braid went grey in memory.",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["book-memory-probe"],
                createdAt: now.addingTimeInterval(-Double(3 - index) * 86_400),
                updatedAt: now.addingTimeInterval(-Double(3 - index) * 86_400)
            )
        }

        let assessment = BookFamiliarityRutEngine.assess(
            pages: pages,
            readerLearning: ReaderLearningModel(),
            attentionProbes: .empty,
            selfFacts: facts,
            now: now
        )

        XCTAssertEqual(assessment.phase, .rote)
        XCTAssertTrue(assessment.mayThreaten)
        XCTAssertTrue(assessment.evidence.contains("memory-of-the-book-went-grey"))
        XCTAssertTrue(assessment.evidence.contains("session-hours-became-uniform"))

        let allOld = pages.map { page -> BookPage in
            var copy = page
            copy.createdAt = now.addingTimeInterval(-90 * 86_400)
            return copy
        }
        let away = BookFamiliarityRutEngine.assess(
            pages: allOld,
            readerLearning: ReaderLearningModel(),
            attentionProbes: .empty,
            selfFacts: facts,
            now: now
        )
        XCTAssertFalse(away.mayThreaten, "time away is not flattening evidence")
    }

    private func rutWarningSurface() -> SurfacePage {
        SurfacePage(
            type: .bookNotices,
            prompt: "The Book Suspects the Rut",
            detail: "A hunch with an eraser.",
            payload: BookPagePayload(
                headline: "The Book Suspects the Rut",
                body: "I may be wrong.",
                metadata: ["packArchetypeID": "the-nothing-stirs"]
            )
        )
    }

    private func selfFact(for question: AboutYouQuestion, answer: String, now: Date) -> SelfFact {
        SelfFact(
            id: "\(question.packID):\(question.id)",
            questionID: question.id,
            question: question.prompt,
            answer: answer,
            bookTranslation: SelfKnowledgePackRegistry.translation(for: question, answer: answer),
            sensitivity: question.sensitivity,
            usePermission: question.defaultUsePermission,
            tags: question.tags,
            createdAt: now,
            updatedAt: now
        )
    }

    private func earnedTitleFact(_ title: String, now: Date) -> SelfFact {
        SelfFact(
            id: "core-self-knowledge:earned-wonder-label",
            questionID: "earned-wonder-label",
            question: "Your First Working Title",
            answer: title,
            bookTranslation: "The Book treats this as an earned working title, not a personality box: \(title).",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["earned-label"],
            createdAt: now,
            updatedAt: now
        )
    }
}
