import XCTest
@testable import InsideCoverCore

final class WorldSystemsTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func shadowDate(
        for family: ShadowWonder.VisitationFamily,
        inputs: BookSourceInputs,
        after start: Date
    ) -> Date {
        for offset in 0..<96 {
            let candidate = start.addingTimeInterval(Double(offset) * 2 * 60 * 60)
            if ShadowWonder.shouldSurface(family, inputs: inputs, now: candidate) {
                return candidate
            }
        }
        XCTFail("Shadow visitation family \(family.rawValue) did not receive a turn")
        return start
    }

    private func firstDate(
        after start: Date,
        where predicate: (Date) -> Bool,
        calendar: Calendar
    ) -> Date {
        var probe = start
        for _ in 0..<40 {
            if predicate(probe) { return probe }
            probe = calendar.date(byAdding: .day, value: 1, to: probe) ?? probe.addingTimeInterval(86_400)
        }
        return start
    }

    // MARK: Moon

    func testMoonPhaseAtReferenceNewMoonIsNew() {
        var components = DateComponents(year: 2000, month: 1, day: 6, hour: 18, minute: 14)
        components.timeZone = TimeZone(identifier: "UTC")
        let reference = Calendar(identifier: .gregorian).date(from: components)!
        let phase = MoonPhaseCalendar.phase(on: reference)
        XCTAssertEqual(phase.name, "New Moon")
        XCTAssertLessThan(phase.illuminatedFraction, 0.02)
    }

    func testMoonPhaseHalfCycleLaterIsFull() {
        var components = DateComponents(year: 2000, month: 1, day: 6, hour: 18, minute: 14)
        components.timeZone = TimeZone(identifier: "UTC")
        let reference = Calendar(identifier: .gregorian).date(from: components)!
        let halfCycle = reference.addingTimeInterval(MoonPhaseCalendar.synodicMonthDays / 2 * 86_400)
        let phase = MoonPhaseCalendar.phase(on: halfCycle)
        XCTAssertEqual(phase.name, "Full Moon")
        XCTAssertGreaterThan(phase.illuminatedFraction, 0.98)
    }

    // MARK: Academy schedule

    func testMondayMorningIsArtOfTheGlint() {
        let calendar = utcCalendar
        // 2026-06-08 is a Monday.
        let monday = date(2026, 6, 8, hour: 9, calendar: calendar)
        let session = AcademyScheduleRegistry.sessionInProgress(at: monday, calendar: calendar)
        XCTAssertEqual(session?.session.id, "art-of-the-glint")
        XCTAssertEqual(session?.block, "morning")
    }

    func testMondayEveningIsInkwrightSociety() {
        let calendar = utcCalendar
        let monday = date(2026, 6, 8, hour: 19, calendar: calendar)
        let session = AcademyScheduleRegistry.sessionInProgress(at: monday, calendar: calendar)
        XCTAssertEqual(session?.session.id, "inkwright-society")
        XCTAssertEqual(session?.session.kind, .club)
    }

    func testSundayAfternoonHasNoSession() {
        let calendar = utcCalendar
        // 2026-06-07 is a Sunday; no afternoon class on Sundays.
        let sunday = date(2026, 6, 7, hour: 13, calendar: calendar)
        XCTAssertNil(AcademyScheduleRegistry.sessionInProgress(at: sunday, calendar: calendar))
    }

    func testWednesdayHasNoClub() {
        let calendar = utcCalendar
        // 2026-06-10 is a Wednesday.
        let wednesday = date(2026, 6, 10, hour: 20, calendar: calendar)
        XCTAssertNil(AcademyScheduleRegistry.sessionInProgress(at: wednesday, calendar: calendar))
    }

    func testEveryScheduledSessionExists() {
        for (_, plan) in AcademyScheduleRegistry.week {
            if let id = plan.morning {
                XCTAssertNotNil(AcademyScheduleRegistry.classes[id], "missing class \(id)")
            }
            if let id = plan.afternoon {
                XCTAssertNotNil(AcademyScheduleRegistry.classes[id], "missing class \(id)")
            }
            if let id = plan.club {
                XCTAssertNotNil(AcademyScheduleRegistry.clubs[id], "missing club \(id)")
            }
        }
    }

    func testGlintClassCarriesLessonModuleAndProfessorIdentity() {
        let session = AcademyScheduleRegistry.classes["art-of-the-glint"]

        XCTAssertEqual(session?.leader, "Professor Lydia Boggle")
        XCTAssertEqual(session?.leaderEntityID, "lydia-boggle")
        XCTAssertEqual(session?.subjectThreadID, "notice-north")

        let lesson = AcademyScheduleRegistry.lessonModules["art-of-the-glint"]
        XCTAssertEqual(lesson?.sessionID, "art-of-the-glint")
        XCTAssertEqual(lesson?.title, "Specificity Breaks the Rut")
        XCTAssertFalse(lesson?.lectureBeats.isEmpty ?? true)
        XCTAssertTrue(lesson?.realWorldPractice.contains("observable facts") ?? false)
    }

    func testAcademyTurnClassIsQuietAndLessonPreservingClubIsActive() throws {
        let classSession = try XCTUnwrap(AcademyScheduleRegistry.classes["art-of-the-glint"])
        let classLesson = AcademyScheduleRegistry.lessonModules["art-of-the-glint"]
        let classTurn = AcademyTurnBuilder.turn(
            session: classSession, lesson: classLesson, isClub: false, slotKey: "k"
        )
        XCTAssertEqual(classTurn.register, .quiet)
        XCTAssertEqual(classTurn.character, classSession.leader)
        XCTAssertTrue(classTurn.statement.contains("lesson's point still lands"),
                      "a class turn must protect the lesson")
        let classLandings = ["slice-of-life", "progress-arc", "surprise"].compactMap { classTurn.landings[$0]?.nonEmpty }
        XCTAssertEqual(Set(classLandings).count, 3)

        let clubSession = try XCTUnwrap(AcademyScheduleRegistry.clubs.values.first)
        let clubTurn = AcademyTurnBuilder.turn(
            session: clubSession, lesson: AcademyScheduleRegistry.lessonModules[clubSession.id], isClub: true, slotKey: "k"
        )
        XCTAssertEqual(clubTurn.register, .active)
        XCTAssertFalse(clubTurn.statement.contains("lesson's point still lands"))
    }

    func testEveryScheduledSessionHasALessonModule() {
        let sessions = Array(AcademyScheduleRegistry.classes.values) + Array(AcademyScheduleRegistry.clubs.values)

        for session in sessions {
            let lesson = AcademyScheduleRegistry.lessonModules[session.id]
            XCTAssertNotNil(lesson, "missing lesson module for \(session.id)")
            XCTAssertEqual(lesson?.sessionID, session.id)
            XCTAssertFalse(lesson?.title.isEmpty ?? true, "missing title for \(session.id)")
            XCTAssertFalse(lesson?.realSubject.isEmpty ?? true, "missing real subject for \(session.id)")
            XCTAssertFalse(lesson?.concept.isEmpty ?? true, "missing concept for \(session.id)")
            XCTAssertGreaterThanOrEqual(lesson?.lectureBeats.count ?? 0, 3, "needs at least three lecture beats for \(session.id)")
            XCTAssertFalse(lesson?.demonstration.isEmpty ?? true, "missing demonstration for \(session.id)")
            XCTAssertFalse(lesson?.interactionPrompt.isEmpty ?? true, "missing interaction prompt for \(session.id)")
            XCTAssertFalse(lesson?.realWorldPractice.isEmpty ?? true, "missing real-world practice for \(session.id)")
        }
    }

    func testEveryScheduledClassProfessorIsInTheNarrativeCast() {
        let professorNames = Set(AcademyScheduleRegistry.classes.values.map(\.leader))
        let castNames = Set(NarrativePackRegistry.entities.filter { $0.kind == .character }.map(\.name))

        XCTAssertTrue(
            professorNames.isSubset(of: castNames),
            "Missing scheduled professors: \(professorNames.subtracting(castNames).sorted().joined(separator: ", "))"
        )
    }

    func testEveryScheduledClassProfessorHasAnIllustrationDossier() {
        let professorNames = Set(AcademyScheduleRegistry.classes.values.map(\.leader))
        let dossierNames = Set(BookReferenceCatalog.characterIllustrations.map(\.characterName))

        XCTAssertTrue(
            professorNames.isSubset(of: dossierNames),
            "Missing professor dossiers: \(professorNames.subtracting(dossierNames).sorted().joined(separator: ", "))"
        )
    }

    // MARK: Page pack templates

    func testTemplateRendererSubstitutesSignals() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(phrase: "light rain, 54F", source: "test")
        inputs.selfFacts = [
            SelfFact(
                id: "f1",
                questionID: "onboarding-name",
                question: "What should the Book call you?",
                answer: "Avery",
                bookTranslation: "Avery",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["name"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        let day = BookDay.today()
        let rendered = PageTemplateRenderer.render(
            "Hello {playerName}: {weather} under a {moon}.",
            day: day,
            inputs: inputs
        )
        XCTAssertTrue(rendered.contains("Avery"))
        XCTAssertTrue(rendered.contains("light rain, 54F"))
        XCTAssertFalse(rendered.contains("{moon}"))
        XCTAssertFalse(rendered.contains("{playerName}"))
    }

    func testBundledPackArchetypesAreWellFormed() {
        let archetypes = PageArchetypePackRegistry.bundledPacks.flatMap(\.archetypes)
        XCTAssertFalse(archetypes.isEmpty)
        for archetype in archetypes {
            XCTAssertFalse(archetype.id.isEmpty)
            XCTAssertFalse(archetype.bodyTemplate.isEmpty)
            XCTAssertGreaterThan(archetype.cadenceHours, 0)
            if let hours = archetype.activeHours {
                XCTAssertTrue(hours.allSatisfy { (0..<24).contains($0) })
            }
            if let trigger = archetype.trigger {
                if let weekdays = trigger.weekdays {
                    XCTAssertTrue(weekdays.allSatisfy { (1...7).contains($0) })
                }
                if let rarity = trigger.rarity {
                    XCTAssertTrue((0...1).contains(rarity))
                }
            }
        }
    }

    func testPageTriggerReadsLiveWorldSignals() {
        let calendar = utcCalendar
        let fullMoonDay = MoonPhaseCalendar.nextFullMoon(after: date(2026, 1, 1, hour: 0, calendar: calendar), calendar: calendar)
        let now = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: fullMoonDay)!
        let oldDate = calendar.date(byAdding: .day, value: -3, to: now)!
        let today = BookDay.day(containing: now, calendar: calendar)
        let oldDay = BookDay(
            id: BookDay.id(for: oldDate, calendar: calendar),
            date: calendar.startOfDay(for: oldDate),
            pages: [
                BookPage(
                    type: .souvenir,
                    createdAt: oldDate,
                    promptText: "Commuter umbrella",
                    userInput: "Rain on the train window.",
                    tags: ["commute", "rain-memory"]
                )
            ]
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [oldDay]
        inputs.quietDays = 3
        inputs.weather = WeatherSourceSignal(phrase: "steady rain against the glass", source: "test")

        let context = PageTriggerContext(day: today, inputs: inputs, now: now, calendar: calendar)

        XCTAssertTrue(PageTrigger(
            timeBands: ["day"],
            moonPhases: ["full moon"],
            weatherTags: ["rain"],
            recentTags: ["commute"],
            minQuietDays: 2,
            minAbsenceDays: 2
        ).allows(context: context, archetypeID: "test-rain-moon-return"))
        XCTAssertFalse(PageTrigger(weatherTags: ["bright"]).allows(context: context, archetypeID: "test-bright"))
        XCTAssertFalse(PageTrigger(minGrey: 1).allows(context: context, archetypeID: "test-grey"))
        XCTAssertFalse(PageTrigger(minAbsenceDays: 4).allows(context: context, archetypeID: "test-too-absent"))
    }

    func testWorldEventPackPageSurfacesOnlyDuringActiveEvent() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
        let calendar = utcCalendar
        let adapter = PackPageSourceAdapter()
        let septemberNow = date(2026, 9, 10, hour: 10, calendar: calendar)
        let september = BookDay.day(containing: septemberNow, calendar: calendar)
        let septemberPages = adapter.candidates(
            for: september,
            context: CuratorContext.make(for: september),
            inputs: .empty,
            now: septemberNow
        )
        XCTAssertTrue(septemberPages.contains { $0.id.contains("dictionary-rebellion-picket-line") })

        let julyNow = date(2026, 7, 10, hour: 10, calendar: calendar)
        let july = BookDay.day(containing: julyNow, calendar: calendar)
        let julyPages = adapter.candidates(
            for: july,
            context: CuratorContext.make(for: july),
            inputs: .empty,
            now: julyNow
        )
        XCTAssertFalse(julyPages.contains { $0.id.contains("dictionary-rebellion-picket-line") })
    }

    func testBackToSchoolPackPagesSurfaceForAllOfSeptember() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
        let calendar = utcCalendar
        let adapter = PackPageSourceAdapter()
        let septemberNow = date(2026, 9, 1, hour: 10, calendar: calendar)
        let september = BookDay.day(containing: septemberNow, calendar: calendar)
        let septemberPages = adapter.candidates(
            for: september,
            context: CuratorContext.make(for: september),
            inputs: .empty,
            now: septemberNow
        )
        XCTAssertTrue(septemberPages.contains { $0.id.contains("mooks-mandate") })
        XCTAssertTrue(septemberPages.contains { $0.id.contains("note-from-the-pixie") })
        XCTAssertFalse(septemberPages.contains { $0.id.contains("dictionary-rebellion-picket-line") })

        let julyNow = date(2026, 7, 10, hour: 10, calendar: calendar)
        let july = BookDay.day(containing: julyNow, calendar: calendar)
        let julyPages = adapter.candidates(
            for: july,
            context: CuratorContext.make(for: july),
            inputs: .empty,
            now: julyNow
        )
        XCTAssertFalse(julyPages.contains { $0.id.contains("mooks-mandate") })
        XCTAssertFalse(julyPages.contains { $0.id.contains("note-from-the-pixie") })
    }

    // MARK: Margin tutor

    func testMarginTutorLedgerRoundTrips() {
        let seen: Set<String> = ["glow-menu", "seal-body"]
        let decoded = MarginTutorLedger.seenIDs(from: MarginTutorLedger.encode(seen))
        XCTAssertEqual(decoded, seen)
        XCTAssertEqual(MarginTutorLedger.seenIDs(from: "not json"), [])
    }

    func testMarginTutorCatalogCoversCoreTouches() {
        for id in ["glow-menu", "seal-body", "seal-weather", "seal-location", "keep-page", "story-page", "flyleaf"] {
            XCTAssertNotNil(MarginTutorCatalog.note(for: id), "missing tutor note \(id)")
        }
    }

    func testReaderFacingEconomyCopyDoesNotExposeOptimizationArithmetic() {
        let tutorCopy = MarginTutorCatalog.notes.map(\.text)
        let marketCopy = GoblinMarketEngine.inWorldWares.flatMap { [$0.clerkPitch, $0.contents] }
        let readerCopy = (tutorCopy + marketCopy).joined(separator: "\n")
        let arithmeticPattern = #"\b\d+\s+(Belief|Attention|Warmth|Claim)\b"#

        XCTAssertNil(
            readerCopy.range(of: arithmeticPattern, options: [.regularExpression, .caseInsensitive]),
            "Reader-facing copy should describe felt consequences without exposing fictional currency arithmetic."
        )
    }

    func testBeliefCombatKeepsExactMechanicsButPresentsAFeltResult() {
        let result = BeliefCombatResult(
            attackerName: "Wicker",
            attackerKind: .npc,
            targetName: "the thread",
            targetKind: .thread,
            attackerBeliefBefore: 44,
            attackerBeliefAfter: 39,
            targetBeliefBefore: 52,
            targetBeliefAfter: 47,
            requestedSpend: 5,
            actualSpend: 5,
            dealt: 5,
            backlash: 0,
            roll: 73,
            threshold: 50,
            difficulty: .standard,
            outcome: .success
        )

        XCTAssertEqual(result.actualSpend, 5)
        XCTAssertEqual(result.dealt, 5)
        XCTAssertFalse(result.summaryLine.contains("73"))
        XCTAssertFalse(result.summaryLine.contains("50"))
        XCTAssertFalse(result.summaryLine.localizedCaseInsensitiveContains("rolled"))
    }

    func testMarginTutorCatalogCoversScrapbookOnboarding() throws {
        let ids = [
            "scrapbook-studio",
            "scrapbook-scraps",
            "scrapbook-marks",
            "scrapbook-achievements",
            "scrapbook-keep"
        ]

        for id in ids {
            let note = try XCTUnwrap(MarginTutorCatalog.note(for: id), "missing tutor note \(id)")
            XCTAssertTrue(note.text.localizedCaseInsensitiveContains("scrap") ||
                          note.text.localizedCaseInsensitiveContains("page"),
                          "\(id) should describe the scrapbook work in user language")
        }

        let marks = try XCTUnwrap(MarginTutorCatalog.note(for: "scrapbook-marks"))
        let achievements = try XCTUnwrap(MarginTutorCatalog.note(for: "scrapbook-achievements"))
        XCTAssertFalse(marks.text.localizedCaseInsensitiveContains("spend one"))
        XCTAssertFalse(marks.text.contains("1 Belief"))
        XCTAssertTrue(marks.text.localizedCaseInsensitiveContains("hint"))
        XCTAssertTrue(achievements.text.localizedCaseInsensitiveContains("achievement"))
    }

    func testMarginTutorCatalogCoversIntroductionCurriculumDebuts() throws {
        let whatCues = ["This", " is ", " are ", "means", "shows", "lets", "live here", "happens"]
        let whyCues = ["appears", "because", "when", "after", "enough", "real"]
        let howCues = ["Tap", "Read", "Choose", "Use", "Play", "Pick", "Do", "Listen", "Treat"]

        for type in IntroductionCurriculum.requiredStage.keys {
            let id = try XCTUnwrap(MarginTutorCatalog.noteID(for: type), "missing tutor id for \(type.rawValue)")
            let note = try XCTUnwrap(MarginTutorCatalog.note(for: id), "missing tutor note \(id) for \(type.rawValue)")
            XCTAssertTrue(
                whatCues.contains { note.text.localizedCaseInsensitiveContains($0) },
                "\(id) should explain what the page is"
            )
            XCTAssertTrue(
                whyCues.contains { note.text.localizedCaseInsensitiveContains($0) },
                "\(id) should explain why it appeared"
            )
            XCTAssertTrue(
                howCues.contains { note.text.localizedCaseInsensitiveContains($0) },
                "\(id) should explain how to use it"
            )
            XCTAssertFalse(note.text.localizedCaseInsensitiveContains("threshold"), "\(id) should hide threshold mechanics")
            XCTAssertFalse(note.text.localizedCaseInsensitiveContains("stage "), "\(id) should hide stage mechanics")
            XCTAssertFalse(note.text.localizedCaseInsensitiveContains("score"), "\(id) should hide scoring mechanics")
        }
    }

    // MARK: Stable hashing

    func testStableHashIsDeterministic() {
        XCTAssertEqual("wonder".stableHash, "wonder".stableHash)
        XCTAssertNotEqual("wonder".stableHash, "wander".stableHash)
        XCTAssertEqual(42.stableScramble, 42.stableScramble)
        XCTAssertNotEqual(42.stableScramble, 43.stableScramble)
    }

    // MARK: Memory consolidation

    func testConsolidatorMergesNearDuplicates() {
        func memory(_ id: String, _ summary: String, daysAgo: Double, weight: Int = 2) -> NarrativeEntityMemory {
            NarrativeEntityMemory(
                id: id,
                entityID: "penny-blackletter",
                sourceEventID: "e-\(id)",
                sourcePageID: nil,
                summary: summary,
                tags: [],
                narrativeWeight: weight,
                createdAt: Date().addingTimeInterval(-daysAgo * 86_400)
            )
        }
        let memories = [
            memory("a", "Penny Blackletter remembers: you mentioned the harbor lights", daysAgo: 6),
            memory("b", "Penny Blackletter remembers: you mentioned the harbor lights again", daysAgo: 2),
            memory("c", "Penny Blackletter remembers: the photograph of the kettle", daysAgo: 1)
        ]
        let consolidated = NarrativeEntityMemoryConsolidator.consolidate(memories)
        XCTAssertEqual(consolidated.count, 2)
        let harbor = consolidated.first { $0.summary.contains("harbor") }
        XCTAssertNotNil(harbor)
        XCTAssertGreaterThan(harbor?.narrativeWeight ?? 0, 2)
    }

    func testConsolidatorKeepsDistinctMemoriesApart() {
        func memory(_ id: String, entity: String, _ summary: String) -> NarrativeEntityMemory {
            NarrativeEntityMemory(
                id: id,
                entityID: entity,
                sourceEventID: "e-\(id)",
                sourcePageID: nil,
                summary: summary,
                tags: [],
                narrativeWeight: 2,
                createdAt: Date()
            )
        }
        let memories = [
            memory("a", entity: "penny-blackletter", "Penny remembers: the harbor lights"),
            memory("b", entity: "dr-inkrest", "Inkrest remembers: the harbor lights")
        ]
        XCTAssertEqual(NarrativeEntityMemoryConsolidator.consolidate(memories).count, 2)
    }

    // MARK: The knock

    func testKnockNotesKnowThings() {
        // Persistence gets dry treatment.
        XCTAssertTrue(BannerKnockNotes.note(greyLevel: 0, ascendantChapterName: nil, hour: 12, moonName: "New Moon", knocksThisSession: 7, roll: 0).contains("whole shelf"))
        // Grey days get kindness first.
        XCTAssertTrue(BannerKnockNotes.note(greyLevel: 2, ascendantChapterName: nil, hour: 12, moonName: "New Moon", knocksThisSession: 1, roll: 0).contains("knock helps"))
        // Deep night knows about the Nocturne.
        XCTAssertTrue(BannerKnockNotes.note(greyLevel: 0, ascendantChapterName: nil, hour: 2, moonName: "New Moon", knocksThisSession: 1, roll: 1).contains("Nocturne"))
        // Daytime pool rotates by roll.
        let a = BannerKnockNotes.note(greyLevel: 0, ascendantChapterName: nil, hour: 12, moonName: "New Moon", knocksThisSession: 1, roll: 1)
        let b = BannerKnockNotes.note(greyLevel: 0, ascendantChapterName: nil, hour: 12, moonName: "New Moon", knocksThisSession: 1, roll: 2)
        XCTAssertNotEqual(a, b)
    }

    // MARK: Fuel arithmetic

    func testFuelParserSplitsAndQuantifies() {
        let items = FuelParser.items(from: "Two eggs, toast with butter and coffee")
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0], FuelItem(name: "eggs", quantity: 2))
        XCTAssertEqual(items[1].name, "toast")
        XCTAssertEqual(items[2].name, "butter")
        XCTAssertEqual(items[3].name, "coffee")
    }

    func testFuelParserHandlesNumberWordsAndFiller() {
        let items = FuelParser.items(from: "a bowl of oatmeal, half banana")
        XCTAssertEqual(items.first?.name, "oatmeal")
        XCTAssertEqual(items.first?.quantity, 1)
        XCTAssertEqual(items.last, FuelItem(name: "banana", quantity: 0.5))
    }

    func testPortionScalingUsesCommonPortions() {
        // Eggs: 50g portion, so two eggs = 100g = exactly the per-100g values.
        let per100g = NutritionEstimate(kilocalories: 143, protein: 12.4, carbohydrates: 0.96, fat: 9.96)
        let scaled = FuelParser.scale(per100g: per100g, item: FuelItem(name: "eggs", quantity: 2))
        XCTAssertEqual(scaled.kilocalories, 143, accuracy: 0.1)
        // Unknown food defaults to 100g.
        let unknown = FuelParser.scale(per100g: per100g, item: FuelItem(name: "mystery casserole", quantity: 1))
        XCTAssertEqual(unknown.kilocalories, 143, accuracy: 0.1)
    }

    func testEstimateChartLineIsHonestAboutRoughness() {
        let estimate = NutritionEstimate(kilocalories: 412.4, protein: 21.6, carbohydrates: 38.2, fat: 17.8)
        XCTAssertTrue(estimate.chartLine.contains("412 kcal"))
        XCTAssertTrue(estimate.chartLine.contains("rough"))
    }

    func testFoodDataCentralParserUsesKcalEnergyNotKilojoules() {
        let food = FoodDataCentralFood(
            fdcId: 747997,
            description: "Eggs, Grade A, Large, egg white",
            dataType: "Foundation",
            score: 338,
            foodNutrients: [
                FoodDataCentralNutrient(nutrientName: "Energy", nutrientNumber: "268", unitName: "kJ", value: 231),
                FoodDataCentralNutrient(nutrientName: "Energy", nutrientNumber: "208", unitName: "KCAL", value: 55),
                FoodDataCentralNutrient(nutrientName: "Protein", nutrientNumber: "203", unitName: "G", value: 10.7),
                FoodDataCentralNutrient(nutrientName: "Carbohydrate, by difference", nutrientNumber: "205", unitName: "G", value: 2.36),
                FoodDataCentralNutrient(nutrientName: "Total lipid (fat)", nutrientNumber: "204", unitName: "G", value: 0)
            ]
        )

        let estimate = FoodDataCentralNutritionParser.estimatePer100g(from: food)

        XCTAssertEqual(estimate?.kilocalories, 55)
        XCTAssertEqual(estimate?.protein, 10.7)
    }

    func testFoodDataCentralParserPenalizesEggWhiteForWholeEggQuery() {
        let eggWhite = FoodDataCentralFood(
            fdcId: 1,
            description: "Eggs, Grade A, Large, egg white",
            dataType: "Foundation",
            score: 338,
            foodNutrients: [
                FoodDataCentralNutrient(nutrientName: "Energy", nutrientNumber: "208", unitName: "KCAL", value: 55)
            ]
        )
        let wholeEgg = FoodDataCentralFood(
            fdcId: 2,
            description: "Egg, whole, raw, fresh",
            dataType: "SR Legacy",
            score: 300,
            foodNutrients: [
                FoodDataCentralNutrient(nutrientName: "Energy", nutrientNumber: "208", unitName: "KCAL", value: 143)
            ]
        )

        let match = FoodDataCentralNutritionParser.bestMatch(in: [eggWhite, wholeEgg], for: "eggs")

        XCTAssertEqual(match?.food.fdcId, 2)
    }

    func testFuelPatternDigestMakesRepeatedCluesVellumReadable() {
        let entries = [
            FacultyEntry(kind: .fuel, dayID: "today", createdAt: Date(), windowID: "morning", windowName: "Morning", rawText: "eggs and toast", tags: ["fuel-clue:protein-anchor"]),
            FacultyEntry(kind: .fuel, dayID: "today", createdAt: Date(), windowID: "midday", windowName: "Midday", rawText: "chicken and rice", tags: ["fuel-clue:protein-anchor", "fuel-clue:quick-fuel"])
        ]

        let digest = VellumFuelPatternDigest.make(from: entries)

        XCTAssertTrue(digest.summary.contains("protein anchor x2"))
        XCTAssertTrue(digest.contains("protein-anchor"))
        XCTAssertTrue(digest.researchLine.contains("protein-anchor=2"))
    }

    func testSupportGuildMakesFuelPatternTheStar() {
        let now = date(2026, 6, 12, hour: 23, calendar: utcCalendar)
        let day = BookDay(id: "today", date: now, pages: [])
        var inputs = BookSourceInputs()
        inputs.facultyEntries = [
            FacultyEntry(kind: .fuel, dayID: "today", createdAt: now, windowID: "morning", windowName: "Morning", rawText: "eggs and toast", tags: ["fuel-clue:protein-anchor"]),
            FacultyEntry(kind: .innerWeather, dayID: "today", createdAt: now, windowID: "evening", windowName: "Evening", rawText: "steady enough")
        ]

        let surface = SupportGuildSynthesisGenerator.surface(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)

        XCTAssertTrue(surface?.payload.body.contains("Pattern star") == true)
        XCTAssertTrue(surface?.payload.metadata["fuelPatternDigest"]?.contains("protein anchor") == true)
        XCTAssertTrue(surface?.payload.body.contains("steadiness") == true)
        XCTAssertTrue(surface?.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Dr. Elowen Vellum") == true)
        XCTAssertTrue(surface?.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Dr. Selene Inkrest") == true)
    }

    // MARK: Nocturne Folio

    func testNocturneFolioUnlocksContentAndSparks() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer {
            PackEntitlements.ownedPackIDs = savedOwned
        }
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(PageArchetypePackRegistry.archetypes().contains { $0.id == "last-light" })
        let baseCount = WonderSparkRegistry.sparks.count

        PackEntitlements.ownedPackIDs.insert("nocturne-folio")
        XCTAssertTrue(PageArchetypePackRegistry.archetypes().contains { $0.id == "last-light" })
        XCTAssertEqual(WonderSparkRegistry.sparks.count, baseCount + WonderSparkRegistry.nocturneSparks.count)
    }

    // MARK: The Rut of Routine

    func testGreyLevelRespectsTheKindnessRules() {
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 5, narrativeHeat: 0, distressActive: true), 0, "distress silences Routine absolutely")
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 0, narrativeHeat: 0, distressActive: false), 0)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 1, narrativeHeat: 0, distressActive: false), 0)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 3, narrativeHeat: 0, distressActive: false), 0)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 5, narrativeHeat: 0, distressActive: false), 0)
        XCTAssertEqual(NothingTide.greyLevel(readerRutPressure: 2, narrativeHeat: 0, distressActive: false), 2)
        XCTAssertEqual(NothingTide.greyLevel(readerRutPressure: 2, narrativeHeat: 8, distressActive: false), 2, "story heat cannot rewrite reader evidence")
    }

    func testGreyStorySignalsExistOnlyWhenGreyIsUp() {
        XCTAssertNil(NothingTide.storySignal(forGreyLevel: 0))
        XCTAssertNil(NothingTide.storySignal(forGreyLevel: 1))
        XCTAssertNotNil(NothingTide.storySignal(forGreyLevel: 2))
        XCTAssertNotNil(NothingTide.returnLine(forGreyLevel: 2))
        XCTAssertNil(NothingTide.returnLine(forGreyLevel: 0))
    }

    // MARK: Story Arcs

    private func threadEvent(_ threadID: String, hoursAgo: Double) -> NarrativeEvent {
        NarrativeEvent(
            id: "arc-test-\(threadID)-\(hoursAgo)",
            kind: .pageKept,
            sourcePageType: .diary,
            sourcePageID: nil,
            createdAt: Date().addingTimeInterval(-hoursAgo * 3600),
            summary: "test",
            tags: [],
            effect: NarrativeEventEffect(threadWeightDeltas: [threadID: 2])
        )
    }

    func testArcPromotionNeedsSustainedHeat() {
        let threadID = NarrativePackRegistry.threads.first { !ArcKeeper.ambientThreadIDs.contains($0.id) }!.id
        let cold = ArcKeeper.evaluate(current: nil, events: [threadEvent(threadID, hoursAgo: 2)], lastCompletedThreadID: nil)
        XCTAssertNil(cold.arc)
        let hotEvents = [threadEvent(threadID, hoursAgo: 2), threadEvent(threadID, hoursAgo: 20), threadEvent(threadID, hoursAgo: 40)]
        let hot = ArcKeeper.evaluate(current: nil, events: hotEvents, lastCompletedThreadID: nil)
        XCTAssertEqual(hot.arc?.threadID, threadID)
        XCTAssertEqual(hot.arc?.phase, .rising)
        XCTAssertNotNil(hot.announcement)
        let cooled = ArcKeeper.evaluate(current: nil, events: hotEvents, lastCompletedThreadID: threadID)
        XCTAssertNil(cooled.arc, "the just-completed arc thread is on cooldown")
    }

    func testArcAdvancesOnlyWithTimeAndActivity() {
        let threadID = NarrativePackRegistry.threads.first { !ArcKeeper.ambientThreadIDs.contains($0.id) }!.id
        let now = Date()
        var arc = StoryArc(threadID: threadID, title: "T", phase: .rising, startedAt: now.addingTimeInterval(-5 * 86_400), phaseAdvancedAt: now.addingTimeInterval(-3 * 86_400))
        // Time but no activity: holds.
        let held = ArcKeeper.evaluate(current: arc, events: [], lastCompletedThreadID: nil, now: now)
        XCTAssertEqual(held.arc?.phase, .rising)
        // Time and activity: climax.
        let active = [threadEvent(threadID, hoursAgo: 10), threadEvent(threadID, hoursAgo: 30)]
        let advanced = ArcKeeper.evaluate(current: arc, events: active, lastCompletedThreadID: nil, now: now)
        XCTAssertEqual(advanced.arc?.phase, .climax)
        // Fading completes by time alone.
        arc.phase = .fading
        arc.phaseAdvancedAt = now.addingTimeInterval(-3 * 86_400)
        let done = ArcKeeper.evaluate(current: arc, events: [], lastCompletedThreadID: nil, now: now)
        XCTAssertNil(done.arc)
        XCTAssertNotNil(done.announcement)
    }

    func testPacketCarriesTheCurrentArc() {
        let threadID = NarrativePackRegistry.threads.first { !ArcKeeper.ambientThreadIDs.contains($0.id) }!.id
        var inputs = BookSourceInputs.empty
        inputs.currentArc = StoryArc(threadID: threadID, title: "Test Arc", phase: .climax, startedAt: Date(), phaseAdvancedAt: Date())
        let packet = StoryScenePacketBuilder.packet(for: BookDay.today(), inputs: inputs)
        XCTAssertEqual(packet.selectedThreads.first?.id, threadID, "the arc thread leads the scene")
        XCTAssertTrue(packet.realSignals.contains { $0.contains("CURRENT ARC") && $0.contains("CLIMAX") })
    }

    // MARK: The BookShop

    func testCatalogListingsAreWellFormed() {
        var seenProducts = Set<String>()
        for listing in BookShopCatalog.listings {
            let prefix = listing.family == .standingOrder
                ? "com.openclaw.enchantify.insidecover.pass."
                : "com.openclaw.enchantify.insidecover.pack."
            XCTAssertTrue(listing.productID.hasPrefix(prefix), listing.id)
            XCTAssertTrue(seenProducts.insert(listing.productID).inserted, "duplicate product \(listing.productID)")
            XCTAssertFalse(listing.goblinPitch.isEmpty)
            XCTAssertFalse(listing.contents.isEmpty)
        }
        let eventListing = BookShopCatalog.listing(forPackID: "starlit-paper-trial-archive")
        XCTAssertEqual(eventListing?.resolvedSaleState, .archivedEvent)
        XCTAssertEqual(eventListing?.fallbackDisplayPrice, "$2.99")
        let pass = BookShopCatalog.listing(forPackID: PackEntitlements.standingOrderPackID)
        XCTAssertEqual(pass?.family, .standingOrder)
    }

    func testStandingOrderUnlocksEveryPack() {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = [PackEntitlements.standingOrderPackID]
        XCTAssertTrue(PackEntitlements.hasStandingOrder)
        XCTAssertTrue(PackEntitlements.isUnlocked("dictionary-rebellion"))
        XCTAssertTrue(PackEntitlements.isUnlocked("starlit-paper-trial-archive"))
        XCTAssertTrue(PackEntitlements.isUnlocked("pack.night-and-garden"))
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(PackEntitlements.isUnlocked("dictionary-rebellion"))
    }

    func testEntitlementsUnlockLockedPacks() {
        defer { PackEntitlements.ownedPackIDs = [] }
        let locked = StoryFormPack(
            id: "test-locked-looms", displayName: "Test", version: 1, author: "t",
            availability: "locked", forms: [], genres: []
        )
        XCTAssertTrue(locked.isLocked)
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(PackEntitlements.isUnlocked(locked.id))
        PackEntitlements.ownedPackIDs.insert(locked.id)
        XCTAssertTrue(PackEntitlements.isUnlocked(locked.id))
    }

    func testEventArchivesUsePackEntitlements() {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(WorldEventRegistry.enabledEvents().contains { $0.packID == "starlit-paper-trial-archive" })

        PackEntitlements.ownedPackIDs.insert("starlit-paper-trial-archive")

        XCTAssertTrue(WorldEventRegistry.enabledEvents().contains { $0.packID == "starlit-paper-trial-archive" })
    }

    func testArchivedEventsResolveOnlyAfterTheirWindow() {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["starlit-paper-trial-archive"]
        let calendar = Calendar(identifier: .gregorian)
        let during = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!
        let after = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!

        XCTAssertTrue(WorldEventResolver.archivedEvents(now: during, calendar: calendar).isEmpty)
        XCTAssertEqual(WorldEventResolver.archivedEvents(now: after, calendar: calendar).first?.id, "starlit-paper-trial")
    }

    func testArchivedEventHasAClosedDoorAftermathEvenWithoutPlayer() throws {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["starlit-paper-trial-archive"]
        let calendar = Calendar(identifier: .gregorian)
        let after = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        let event = try XCTUnwrap(
            WorldEventResolver.archivedEvents(now: after, calendar: calendar).first
        )
        let page = WorldEventPageSourceAdapter.aftermathSurface(
            for: event,
            day: BookDay(id: BookDay.id(for: after), date: after, pages: []),
            now: after
        )

        XCTAssertEqual(page.payload.metadata["worldEventAftermath"], "true")
        XCTAssertEqual(page.payload.metadata["worldEventPlayerTouches"], "0")
        XCTAssertTrue(page.payload.body.contains("without your hand"))
        XCTAssertTrue(page.payload.body.contains("door is closed"))
        XCTAssertTrue((page.payload.metadata["tags"] ?? "").contains("event-missed"))
        XCTAssertNil(page.payload.metadata["fieldworkPrompt"])
    }

    func testOpenedArchiveUsesActivationClockOutOfSeason() throws {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["starlit-paper-trial-archive"]
        let calendar = Calendar(identifier: .gregorian)
        let opened = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 9))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 12, day: 4, hour: 9))!
        var inputs = BookSourceInputs.empty
        inputs.openWorldEventArchive = OpenWorldEventArchive(
            packID: "starlit-paper-trial-archive",
            eventID: "starlit-paper-trial",
            openedAt: opened
        )

        let event = try XCTUnwrap(WorldEventResolver.openedArchiveEvent(now: now, inputs: inputs, calendar: calendar))

        XCTAssertEqual(event.id, "starlit-paper-trial")
        XCTAssertEqual(event.activationMode, .openedArchive)
        XCTAssertEqual(event.startedAt, opened)
        XCTAssertEqual(event.phase.id, "hearing")
    }

    func testCurrentEventsCanCarryLiveSeasonAndOpenedArchiveTogether() {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion", "starlit-paper-trial-archive"]
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 12))!
        var inputs = BookSourceInputs.empty
        inputs.openWorldEventArchive = OpenWorldEventArchive(
            packID: "starlit-paper-trial-archive",
            eventID: "starlit-paper-trial",
            openedAt: calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
        )

        let events = WorldEventResolver.currentEvents(now: now, inputs: inputs, calendar: calendar)

        XCTAssertEqual(Set(events.map(\.id)), ["dictionary-rebellion", "starlit-paper-trial"])
        XCTAssertEqual(events.first { $0.id == "dictionary-rebellion" }?.activationMode, .liveCalendar)
        XCTAssertEqual(events.first { $0.id == "starlit-paper-trial" }?.activationMode, .openedArchive)
    }

    func testOpenedArchiveStaysPlayableAfterNominalDuration() throws {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["starlit-paper-trial-archive"]
        let calendar = Calendar(identifier: .gregorian)
        let opened = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 9))!
        let late = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20, hour: 9))!
        let page = BookPage(
            id: "late-archive-fieldwork",
            type: .bookNotices,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 12, day: 18, hour: 9))!,
            promptText: "The Starlit Paper Trial",
            userInput: "A receipt takes the stand.",
            tags: ["world-event", "event:starlit-paper-trial", "event-fieldwork"]
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-12-18", date: page.createdAt, pages: [page])]
        inputs.openWorldEventArchive = OpenWorldEventArchive(
            packID: "starlit-paper-trial-archive",
            eventID: "starlit-paper-trial",
            openedAt: opened
        )

        let event = try XCTUnwrap(WorldEventResolver.openedArchiveEvent(now: late, inputs: inputs, calendar: calendar))

        XCTAssertEqual(event.phase.id, "verdict")
        XCTAssertEqual(event.playerTouchCount, 1)
        XCTAssertEqual(event.playerTouchCounts?[WorldEventTouchKind.fieldworkCompleted.rawValue], 1)
    }

    func testWorldEventTriggersAreScopedToTheSameEventAndMode() {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["starlit-paper-trial-archive"]
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 12))!
        let day = BookDay(id: "2026-09-12", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.openWorldEventArchive = OpenWorldEventArchive(
            packID: "starlit-paper-trial-archive",
            eventID: "starlit-paper-trial",
            openedAt: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12))!
        )
        inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let context = PageTriggerContext(day: day, inputs: inputs, now: now, calendar: calendar)

        let crossedWires = PageTrigger(
            activeWorldEventIDs: ["dictionary-rebellion"],
            worldEventPhases: ["verdict"]
        )
        let archiveVerdict = PageTrigger(
            activeWorldEventIDs: ["starlit-paper-trial"],
            worldEventPhases: ["verdict"],
            worldEventModes: ["openedArchive"]
        )

        XCTAssertFalse(crossedWires.allows(context: context, archetypeID: "crossed"))
        XCTAssertTrue(archiveVerdict.allows(context: context, archetypeID: "archive"))
    }

    func testOneShotWorldEventsCanBeBoundToARealYear() {
        let calendar = Calendar(identifier: .gregorian)
        let inYear = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!
        let nextYear = calendar.date(from: DateComponents(year: 2027, month: 5, day: 4, hour: 12))!

        XCTAssertNotNil(WorldEventRegistry.starlitPaperTrial.calendar.interval(containing: inYear, calendar: calendar))
        XCTAssertNil(WorldEventRegistry.starlitPaperTrial.calendar.interval(containing: nextYear, calendar: calendar))
    }

    func testVaultCarriesOwnedPacks() throws {
        var data = PlayerVaultData()
        data.ownedPacks = ["nocturne-folio"]
        data.openWorldEventArchive = OpenWorldEventArchive(
            packID: "starlit-paper-trial-archive",
            eventID: "starlit-paper-trial",
            openedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded.ownedPacks, ["nocturne-folio"])
        XCTAssertEqual(decoded.openWorldEventArchive?.eventID, "starlit-paper-trial")
    }

    // MARK: Wonder sparks

    func testSparkPoolIsLargeAndWellFormed() {
        XCTAssertGreaterThanOrEqual(WonderSparkRegistry.sparks.count, 60)
        var seen = Set<String>()
        for spark in WonderSparkRegistry.sparks {
            XCTAssertTrue(spark.text.lowercased().hasPrefix("i wonder"), spark.id)
            XCTAssertTrue(spark.text.hasSuffix("?"), spark.id)
            XCTAssertFalse(spark.modes.isEmpty, spark.id)
            XCTAssertTrue(seen.insert(spark.id).inserted, "duplicate spark id \(spark.id)")
        }
        // Every concierge mode has a real pool to draw from.
        for mode in WonderConciergeMode.allCases {
            let pool = WonderSparkRegistry.sparks.filter { $0.modes.contains(mode) }
            XCTAssertGreaterThanOrEqual(pool.count, 8, "mode \(mode) pool too small")
        }
    }

    func testSparksRotateAcrossSlots() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 8))!
        var picks = Set<String>()
        for dayOffset in 0..<5 {
            let when = calendar.date(byAdding: .day, value: dayOffset, to: morning)!
            picks.insert(WonderSparkRegistry.spark(for: .closeToHome, inputs: .empty, now: when, dayID: "day-\(dayOffset)"))
        }
        XCTAssertGreaterThanOrEqual(picks.count, 3, "five days should yield several different sparks")
    }

    func testRainLeansTowardRainSparks() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(phrase: "steady rain, 52F", source: "test")
        // Across several days, rain context should surface a rain-tagged
        // spark at least once for the modes that carry them.
        var sawRainSpark = false
        let morning = date(2026, 6, 10, hour: 9, calendar: utcCalendar)
        for day in 0..<8 {
            let text = WonderSparkRegistry.spark(for: .vibe, inputs: inputs, now: morning, dayID: "rain-day-\(day)")
            if text.contains("rain") || text.contains("percussion") {
                sawRainSpark = true
            }
        }
        XCTAssertTrue(sawRainSpark)
    }

    // MARK: Compass venture reading

    func testDepletedEnergyStaysHome() {
        XCTAssertEqual(
            CompassVenture.decide(energyText: "10% - exhausted", considerations: "", timeLimit: "2 hours", hasPlaces: true, roll: 0.99),
            .homebound
        )
        XCTAssertEqual(
            CompassVenture.decide(energyText: "completely wiped", considerations: "", timeLimit: "an hour", hasPlaces: true, roll: 0.01),
            .homebound
        )
    }

    func testConsiderationsForceHomeRegardlessOfEnergy() {
        XCTAssertEqual(
            CompassVenture.decide(energyText: "90% - great", considerations: "kids napping, can't leave", timeLimit: "2 hours", hasPlaces: true, roll: 0.01),
            .homebound
        )
    }

    func testSteadyEnergySometimesVenturesSometimesNot() {
        let out = CompassVenture.decide(energyText: "60% - okay", considerations: "", timeLimit: "an hour", hasPlaces: true, roll: 0.2)
        let home = CompassVenture.decide(energyText: "60% - okay", considerations: "", timeLimit: "an hour", hasPlaces: true, roll: 0.9)
        XCTAssertEqual(out, .destination)
        XCTAssertEqual(home, .neighborhood)
    }

    func testShortTimeLimitCapsTheVenture() {
        XCTAssertEqual(
            CompassVenture.decide(energyText: "85% - energized", considerations: "", timeLimit: "10 minutes", hasPlaces: true, roll: 0.01),
            .neighborhood
        )
    }

    func testNoPlacesMeansNoNamedDestination() {
        XCTAssertEqual(
            CompassVenture.decide(energyText: "85% - energized", considerations: "", timeLimit: "2 hours", hasPlaces: false, roll: 0.01),
            .neighborhood
        )
    }

    func testCompassVentureDeterministicRollIsStable() {
        let first = CompassVenture.deterministicRoll(seed: "run-a|home|steady")
        let second = CompassVenture.deterministicRoll(seed: "run-a|home|steady")
        XCTAssertEqual(first, second)
        XCTAssertGreaterThanOrEqual(first, 0)
        XCTAssertLessThan(first, 1)
    }

    func testCompassPlaceContextInfersCafeAndHarbor() {
        XCTAssertEqual(
            CompassPlaceContext.inferred(from: [
                LocalPlaceSignal(id: "a", name: "Downshift Coffee", category: "coffee shop", distanceLabel: "120 m", locality: "Waterville")
            ]),
            .cafe
        )
        XCTAssertEqual(
            CompassPlaceContext.inferred(from: [
                LocalPlaceSignal(id: "b", name: "Belfast Harbor Walk", category: "harbor", distanceLabel: "0.4 km", locality: "Belfast")
            ]),
            .harbor
        )
    }

    func testCompassRunStepBodiesCarryGoalForward() {
        let seed = WonderCompassRunSeed(
            id: "linked-run",
            mode: .closeToHome,
            timeBox: "10 minutes",
            budget: "$0",
            place: "home",
            energy: "steady",
            companions: "solo",
            considerations: "quiet",
            circumstance: "ordinary morning",
            spark: "I wonder what the kitchen light is trying to show me?",
            destination: "the kitchen window",
            delight: "a glass of water",
            definition: "stop when the light changes",
            mission: "Notice the warmest color and the quietest sound.",
            souvenirPrompt: "Write the best sensory moment in one sentence.",
            restPrompt: "Set the phone down for one minute.",
            tags: ["wonder-compass-run"]
        )

        let embark = seed.body(for: .embark)
        XCTAssertTrue(embark.contains(seed.spark))
        XCTAssertTrue(embark.contains("East makes the plan"))

        let sense = seed.body(for: .sense)
        XCTAssertTrue(sense.contains(seed.spark))
        XCTAssertTrue(sense.contains(seed.destination))
        XCTAssertTrue(sense.contains("puts you in your body"))

        let write = seed.body(for: .write)
        XCTAssertTrue(write.contains(seed.spark))
        XCTAssertTrue(write.contains(seed.destination))
        XCTAssertTrue(write.contains("best sensory moment"))
    }

    // MARK: Story forms

    func testStoryFormRegistryIsWellFormed() {
        XCTAssertGreaterThanOrEqual(StoryFormRegistry.forms.count, 6)
        XCTAssertGreaterThanOrEqual(StoryFormRegistry.genres.count, 8)
        for form in StoryFormRegistry.forms {
            XCTAssertEqual(form.beats.count, StoryVignetteBeats.maximumInteractiveTurns, "\(form.id) should stay snack-sized")
        }
        for genre in StoryFormRegistry.genres {
            XCTAssertFalse(genre.lens.isEmpty)
        }
        XCTAssertGreaterThanOrEqual(StoryFormRegistry.coreRecipes.count, 35)
        XCTAssertTrue(StoryFormRegistry.coreRecipes.contains { $0.id == "souvenir-door" })
        XCTAssertTrue(StoryFormRegistry.coreRecipes.contains { $0.id == "forage-day" })
        XCTAssertTrue(StoryFormRegistry.coreRecipes.contains { $0.id == "the-quill-disagrees" })
        XCTAssertTrue(StoryFormRegistry.coreRecipes.allSatisfy(StoryFormRegistry.recipeIsValid))
        XCTAssertTrue(StoryFormRegistry.coreRecipes.allSatisfy { $0.beats.count == StoryVignetteBeats.maximumInteractiveTurns })
        XCTAssertFalse(StoryFormRegistry.coreRecipes.contains { recipe in
            recipe.turns.contains { $0.wantTemplate.localizedCaseInsensitiveContains("without turning it into a confrontation") }
        })
    }

    func testPlayfulStoryRecipesHaveComedyWithoutLosingGrounding() {
        let playfulIDs: Set<String> = [
            "wrong-size-emergency",
            "one-simple-conversation",
            "rumor-with-good-shoes",
            "petty-prophecy",
            "unscheduled-parade",
            "rule-nobody-read"
        ]
        let playful = StoryFormRegistry.coreRecipes.filter { playfulIDs.contains($0.id) }

        XCTAssertEqual(Set(playful.map(\.id)), playfulIDs)
        XCTAssertTrue(playful.allSatisfy(StoryFormRegistry.recipeIsValid))
        XCTAssertTrue(playful.allSatisfy { $0.preferredGenreIDs.contains("screwball") })
        XCTAssertEqual(playful.filter(\.isWorldLed).count, 3)
        XCTAssertEqual(playful.filter { $0.requirements.contains(.groundedSource) }.count, 3)
    }

    func testLegacyStoryFormPackDecodesWithoutRecipes() throws {
        let data = Data(#"{"id":"old","displayName":"Old","version":1,"author":"Reader","availability":"bundledFree","forms":[],"genres":[]}"#.utf8)
        let pack = try JSONDecoder().decode(StoryFormPack.self, from: data)
        XCTAssertEqual(pack.id, "old")
        XCTAssertTrue(pack.recipes.isEmpty)
    }

    func testLegacyGenreDecodesWithoutExemplarOrPalette() throws {
        let data = Data(#"{"id":"noir","name":"Noir","lens":"Rain and regret.","moodTags":["night"]}"#.utf8)
        let genre = try JSONDecoder().decode(StoryGenre.self, from: data)
        XCTAssertEqual(genre.id, "noir")
        XCTAssertTrue(genre.exemplar.isEmpty)
        XCTAssertTrue(genre.palette.isEmpty)
    }

    func testGenreExemplarAndPaletteRoundTripThroughPackJSON() throws {
        let genre = StoryGenre(
            id: "campus-gothic", name: "Campus Gothic", lens: "Ivy with opinions.",
            moodTags: ["night"], exemplar: "\"The library keeps hours we don't,\" she said.",
            palette: ["ivy", "reading lamp", "card catalog"]
        )
        let data = try JSONEncoder().encode(genre)
        let decoded = try JSONDecoder().decode(StoryGenre.self, from: data)
        XCTAssertEqual(decoded, genre)
    }

    func testBundledGenresShipExemplarAndPalette() {
        for genre in StoryFormRegistry.genres {
            XCTAssertFalse(genre.exemplar.isEmpty, "\(genre.id) needs an exemplar passage for the local brain to imitate")
            XCTAssertGreaterThanOrEqual(genre.palette.count, 4, "\(genre.id) needs concrete palette nouns for quiet days")
            let words = genre.exemplar.split { $0.isWhitespace }.count
            XCTAssertLessThanOrEqual(words, 75, "\(genre.id) exemplar should stay small enough for the E2B prompt budget")
        }
    }

    func testUnquietFolioPackIsWellFormed() {
        let pack = StoryFormRegistry.bundledPacks.first { $0.id == "unquiet-folio" }
        XCTAssertNotNil(pack)
        XCTAssertEqual(pack?.genres.count, 3)
        XCTAssertEqual(pack?.recipes.count, 4)
        XCTAssertTrue(pack?.genres.allSatisfy { $0.moodTags.contains("clash") } ?? false)
        XCTAssertTrue(pack?.recipes.allSatisfy { $0.preferredTags.contains("clash") } ?? false)
        XCTAssertTrue(pack?.recipes.allSatisfy(StoryFormRegistry.recipeIsValid) ?? false)
        XCTAssertTrue(pack?.recipes.allSatisfy { $0.beats.count == StoryVignetteBeats.maximumInteractiveTurns } ?? false)
    }

    func testClashGenresNeverSurfaceWithoutClashRecipe() {
        for day in 1...14 {
            let picked = StoryFormRegistry.select(
                tags: ["rain", "evening", "mischief", "grey"], surfaceHistory: [:], ascendantChapterID: nil,
                dayID: "2026-07-\(day)", slot: "slot-\(day)", now: Date()
            )
            XCTAssertFalse(picked.genre.moodTags.contains("clash"), "clash genre \(picked.genre.id) surfaced with no clash recipe")
        }
    }

    func testClashRecipePrefersClashGenre() {
        let greyEdit = StoryFormRegistry.recipes.first { $0.id == "grey-edit" }
        XCTAssertNotNil(greyEdit)
        let picked = StoryFormRegistry.select(
            tags: [], surfaceHistory: [:], ascendantChapterID: nil,
            dayID: "2026-07-01", slot: "slot-a", recipe: greyEdit, now: Date()
        )
        XCTAssertTrue(greyEdit?.preferredGenreIDs.contains(picked.genre.id) ?? false)
    }

    func testRivalryEdgeDetection() {
        let all = NarrativePackRegistry.entities
        XCTAssertTrue(StoryFormRegistry.hasRivalryEdge(among: all), "the bundled cast should contain at least one tense edge (e.g. Finn Bridges)")
        XCTAssertFalse(StoryFormRegistry.hasRivalryEdge(among: []))
    }

    func testChosenRegisterRecipesAreRareAndWellFormed() {
        let entrusting = StoryFormRegistry.coreRecipes.first { $0.id == "the-entrusting" }
        let summons = StoryFormRegistry.coreRecipes.first { $0.id == "the-summons" }
        let mark = StoryFormRegistry.coreRecipes.first { $0.id == "the-readers-mark" }
        XCTAssertNotNil(entrusting)
        XCTAssertNotNil(summons)
        XCTAssertNotNil(mark)
        XCTAssertTrue(entrusting?.requirements.contains(.deepBond) ?? false, "a confidence from a near-stranger rings false")
        // Election has to stay rare: chosen-register cooldowns are measured in days, not hours.
        for recipe in [entrusting, summons, mark].compactMap({ $0 }) {
            XCTAssertGreaterThanOrEqual(recipe.cooldownHours, 168, "\(recipe.id) should rest at least a week between firings")
        }
    }

    func testDeepBondConfidantRequiresDocumentedHistory() {
        let cast = NarrativePackRegistry.entities.filter { $0.kind == .character }
        let friend = cast[0]
        let stranger = cast[1]
        func memory(_ n: Int, of entityID: String) -> NarrativeEntityMemory {
            NarrativeEntityMemory(id: "m\(entityID)\(n)", entityID: entityID, sourceEventID: "e\(n)",
                sourcePageID: nil, summary: "a kept day", tags: [], narrativeWeight: 4, createdAt: Date())
        }
        XCTAssertNil(StoryFormRegistry.deepBondConfidant(among: cast, memories: []),
            "no memories, no bond: the gate must hold before the library matures")
        let thin = [memory(1, of: friend.id), memory(2, of: friend.id)]
        XCTAssertNil(StoryFormRegistry.deepBondConfidant(among: cast, memories: thin),
            "two memories is acquaintance, not entrusting depth")
        let deep = (1...3).map { memory($0, of: friend.id) } + [memory(9, of: stranger.id)]
        XCTAssertEqual(StoryFormRegistry.deepBondConfidant(among: cast, memories: deep)?.id, friend.id,
            "the confidant must be the character who actually holds the history")
    }

    func testMalformedRecipeTokenDoesNotInvalidateOtherRecipes() {
        var malformed = StoryFormRegistry.coreRecipes[0]
        malformed.id = "bad-token"
        malformed.premiseTemplate = "{{unknown-person}} arrives."
        XCTAssertFalse(StoryFormRegistry.recipeIsValid(malformed))
        XCTAssertTrue(StoryFormRegistry.recipeIsValid(StoryFormRegistry.coreRecipes[1]))
    }

    func testStoryFormSelectionAvoidsRecentForm() {
        let now = Date()
        let first = StoryFormRegistry.select(
            tags: [], surfaceHistory: [:], ascendantChapterID: nil,
            dayID: "2026-06-11", slot: "slot-a", now: now
        )
        var history: [String: SurfaceHistoryRecord] = [:]
        history["form:\(first.form.id)"] = SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 2)
        let second = StoryFormRegistry.select(
            tags: [], surfaceHistory: history, ascendantChapterID: nil,
            dayID: "2026-06-11", slot: "slot-a", now: now
        )
        XCTAssertNotEqual(first.form.id, second.form.id, "the just-used form should step back")
    }

    func testPacketCarriesFormAndGenre() {
        let packet = StoryScenePacketBuilder.packet(for: BookDay.today(), inputs: .empty)
        XCTAssertNotNil(packet.storyFormID)
        XCTAssertFalse(packet.storyFormBeats?.isEmpty ?? true)
        XCTAssertNotNil(packet.storyGenreLens)
        XCTAssertNotNil(packet.blueprint)
        XCTAssertFalse(packet.blueprint?.grounding.text.isEmpty ?? true)
        XCTAssertFalse(packet.blueprint?.premise.contains("{{") ?? true)
    }

    func testStoryRecipePrefersKeptPageGrounding() {
        let now = date(2026, 8, 8, hour: 16, calendar: utcCalendar)
        let page = BookPage(
            type: .souvenir,
            createdAt: now,
            promptText: "Keep one thing",
            userInput: "The blue receipt has a coffee ring.",
            tags: ["souvenir"]
        )
        let day = BookDay(id: "recipe-day", date: now, pages: [page])
        var inputs = BookSourceInputs.empty
        // Steer selection to a reader-grounded recipe: world-led recipes are
        // allowed to win this day too, and they ground in atmosphere instead.
        inputs.storyRecipeBoosts = ["grey-edit": 12]
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
        XCTAssertEqual(packet.blueprint?.grounding.kind, .keptPage)
        XCTAssertTrue(packet.blueprint?.grounding.text.contains("blue receipt") == true)
    }

    func testWorldLedRecipesAreWellFormedAndUngrounded() {
        let worldLed = StoryFormRegistry.coreRecipes.filter(\.isWorldLed)
        XCTAssertGreaterThanOrEqual(worldLed.count, 6)
        for recipe in worldLed {
            XCTAssertTrue(StoryFormRegistry.recipeIsValid(recipe))
            XCTAssertFalse(recipe.premiseTemplate.contains("{{grounding}}"),
                "\(recipe.id) is world-led; its premise must not orbit the reader's pages")
            XCTAssertFalse(recipe.requirements.contains(.keptPage),
                "\(recipe.id) must stay playable on days with nothing kept")
            XCTAssertFalse(recipe.requirements.contains(.souvenirDoor))
            XCTAssertTrue(StoryFormRegistry.isWorldLedRecipe(id: recipe.id))
        }
        XCTAssertFalse(StoryFormRegistry.isWorldLedRecipe(id: "grey-edit"))
        XCTAssertFalse(StoryFormRegistry.isWorldLedRecipe(id: "no-such-recipe"))
    }

    func testWorldLedRecipeGroundsInAtmosphereNotKeptPages() {
        let page = BookPage(type: .diary, promptText: "Today", userInput: "The dentist rescheduled and I cried in the car.", tags: ["diary"])
        let day = BookDay(id: "world-led-day", date: Date(), pages: [page])
        var inputs = BookSourceInputs.empty
        inputs.storyRecipeBoosts = ["unshelved-expedition": 12]
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs)
        XCTAssertEqual(packet.blueprint?.recipeID, "unshelved-expedition")
        XCTAssertNotEqual(packet.blueprint?.grounding.kind, .keptPage)
        XCTAssertFalse(packet.blueprint?.grounding.text.contains("dentist") ?? true,
            "a world-led scene must never pull the reader's kept line into the premise")
        XCTAssertFalse(packet.blueprint?.premise.contains("dentist") ?? true)
    }

    func testRecipeBecomesPrimaryVarietyKeyAndKeepsFormGenreKeys() {
        let surface = NarrativeOSPageSourceAdapter.draftCandidate(for: BookDay.today(), inputs: .empty, now: Date())
        XCTAssertTrue(surface.varietyKey.hasPrefix("recipe:"))
        XCTAssertTrue(surface.supplementalStoryVarietyKeys.contains { $0.hasPrefix("form:") })
        XCTAssertTrue(surface.supplementalStoryVarietyKeys.contains { $0.hasPrefix("genre:") })
    }

    func testGenreSelectionFollowsMoodTags() {
        let pick = StoryFormRegistry.select(
            tags: ["rain", "evening", "tea"], surfaceHistory: [:],
            ascendantChapterID: nil, dayID: "d", slot: "s"
        )
        XCTAssertEqual(pick.genre.id, "cozy-mystery", "rainy evening tea should brew a cozy mystery")
    }

    // MARK: Real-place electives

    func testOfferSurfaceCarriesNearbyPlaces() {
        let adapter = ElectivePageSourceAdapter()
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(id: "p1", name: "Tom's Diner", category: "diner", distanceLabel: "1.2 km", locality: "Riverside")
        ]
        inputs.selfFacts = []
        let day = BookDay.today()
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: noon)
        if let offer = pages.first(where: { $0.payload.metadata["electiveOffer"] == "true" }) {
            XCTAssertTrue(offer.payload.metadata["nearbyPlaces"]?.contains("Tom's Diner") == true)
        }
        // Either an offer surfaced carrying the place, or none surfaced
        // (cadence-gated), but never an offer without the places line.
        for offer in pages where offer.payload.metadata["electiveOffer"] == "true" {
            XCTAssertNotNil(offer.payload.metadata["nearbyPlaces"])
        }
    }

    func testElectiveOfferCoolsDownRecentDestination() {
        let adapter = ElectivePageSourceAdapter()
        let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(id: "youngs", name: "Young's Lobster Pound", category: "seafood", distanceLabel: "1.2 km", locality: "Belfast"),
            LocalPlaceSignal(id: "co-op", name: "Belfast Co-op", category: "grocery", distanceLabel: "900 m", locality: "Belfast")
        ]
        inputs.electives = [
            UnwrittenElective(
                id: "recent-youngs",
                characterID: "old-sender",
                characterName: "Old Sender",
                title: "A Visit to Young's Lobster Pound",
                ask: "Go to Young's Lobster Pound this week.",
                whyItMatters: "It matters",
                practiceShape: "One sentence",
                createdAt: now.addingTimeInterval(-3 * 86_400),
                completedAt: now.addingTimeInterval(-2 * 86_400),
                proof: "Done."
            )
        ]

        let pages = adapter.candidates(for: BookDay.today(), context: CuratorContext.make(for: BookDay.today()), inputs: inputs, now: now)
        let offer = pages.first { $0.payload.metadata["electiveOffer"] == "true" }

        XCTAssertFalse((offer?.payload.metadata["nearbyPlaces"] ?? "").contains("Young's Lobster Pound"))
        XCTAssertTrue((offer?.payload.metadata["nearbyPlaces"] ?? "").contains("Belfast Co-op"))
        XCTAssertEqual(offer?.payload.metadata["cooledDestinationCount"], "1")
    }

    func testElectiveOfferAllowsDestinationAfterCooldown() {
        let adapter = ElectivePageSourceAdapter()
        let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(id: "youngs", name: "Young's Lobster Pound", category: "seafood", distanceLabel: "1.2 km", locality: "Belfast")
        ]
        inputs.electives = [
            UnwrittenElective(
                id: "old-youngs",
                characterID: "old-sender",
                characterName: "Old Sender",
                title: "A Visit to Young's Lobster Pound",
                ask: "Go to Young's Lobster Pound this week.",
                whyItMatters: "It matters",
                practiceShape: "One sentence",
                createdAt: now.addingTimeInterval(-45 * 86_400),
                completedAt: now.addingTimeInterval(-44 * 86_400),
                proof: "Done."
            )
        ]

        let pages = adapter.candidates(for: BookDay.today(), context: CuratorContext.make(for: BookDay.today()), inputs: inputs, now: now)
        let offer = pages.first { $0.payload.metadata["electiveOffer"] == "true" }

        XCTAssertTrue((offer?.payload.metadata["nearbyPlaces"] ?? "").contains("Young's Lobster Pound"))
        XCTAssertEqual(offer?.payload.metadata["cooledDestinationCount"], "0")
    }

    func testCharacterLetterUsesOnboardingPlayerName() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            SelfFact(
                id: "onboarding:onboarding-name",
                questionID: "onboarding-name",
                question: "What should the Book call you?",
                answer: "Beej",
                bookTranslation: "Beej",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["name", "identity", "onboarding"],
                createdAt: Date(),
                updatedAt: Date()
            ),
            SelfFact(
                id: "core-self-knowledge:called",
                questionID: "called",
                question: "What do you like to be called?",
                answer: "The Later Name",
                bookTranslation: "The Book may call you The Later Name.",
                sensitivity: .identity,
                usePermission: .quoteAllowed,
                tags: ["name", "identity"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        let entity = NarrativePackRegistry.entities.first { $0.id == "penny-blackletter" }!
        let surface = CharacterLetterPageGenerator.draftCandidate(
            for: entity,
            source: BookPageSourceRegistry.source(for: .letter),
            day: BookDay.today(),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(surface.payload.metadata["playerName"], "Beej")
        XCTAssertTrue(surface.payload.body.contains("Address the player as: Beej"))
        XCTAssertFalse(surface.payload.body.contains("[Player Name]"))
        XCTAssertTrue(surface.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("Penny Blackletter") == true)
        XCTAssertTrue(surface.payload.metadata[CharacterCanonPacket.metadataKey]?.contains("one honest detail can save a day") == true)
    }

    func testChapterTalismanBeliefMovesTargetOwnAndRivalTalismans() {
        let penny = NarrativePackRegistry.entities.first { $0.id == "penny-blackletter" }!
        let give = ChapterTalismanBeliefMoves.giveMove(for: penny)
        XCTAssertEqual(give?.targetTalismanID, "wind-cipher")
        XCTAssertEqual(give?.ledgerDelta, 1)
        XCTAssertEqual(give?.ledgerToken, "wind-cipher:1")

        let take = ChapterTalismanBeliefMoves.takeMove(for: penny, seed: 42)
        XCTAssertNotNil(take)
        XCTAssertNotEqual(take?.targetTalismanID, "wind-cipher")
        if take?.succeeded == true {
            XCTAssertEqual(take?.ledgerDelta, -1)
            XCTAssertTrue(take?.ledgerToken?.hasSuffix(":-1") == true)
        } else {
            XCTAssertEqual(take?.ledgerDelta, 0)
            XCTAssertNil(take?.ledgerToken)
        }
    }

    func testCharacterLetterCanCarryCountingChapterTalismanDelta() throws {
        let entity = NarrativePackRegistry.entities.first { $0.id == "penny-blackletter" }!
        let source = BookPageSourceRegistry.source(for: .letter)
        let candidate = (0..<80).compactMap { index -> SurfacePage? in
            let now = Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2026, month: 6, day: 11, hour: 9)
            )!
            let day = BookDay(id: "test-day-\(index)", date: now, pages: [])
            let surface = CharacterLetterPageGenerator.draftCandidate(
                for: entity,
                source: source,
                day: day,
                inputs: .empty,
                now: now
            )
            return surface.payload.metadata["chapterTalismanDeltas"]?.isEmpty == false ? surface : nil
        }.first

        let surface = try XCTUnwrap(candidate)
        XCTAssertTrue(surface.payload.body.contains("Chapter talisman move:"))
        XCTAssertFalse(surface.payload.metadata["chapterTalismanMoves"]?.isEmpty ?? true)
        XCTAssertFalse(surface.payload.metadata["chapterTalismanDeltas"]?.isEmpty ?? true)
    }

    func testAttentionMissionsJoinPlayfulMissionRegistry() {
        XCTAssertGreaterThanOrEqual(PlayfulMissionRegistry.attentionMissions.count, 40)
        XCTAssertTrue(PlayfulMissionRegistry.missions.contains { $0.id == "body-heartbeat-location" })
        XCTAssertTrue(PlayfulMissionRegistry.missions.contains { $0.id == "light-route" })
        XCTAssertTrue(PlayfulMissionRegistry.missions.contains { $0.id == "strange-technical-miracle" })
    }

    func testRidiculousMissionsWorkAnywhereInThePresentMoment() {
        let missions = PlayfulMissionRegistry.ridiculousMissions

        XCTAssertEqual(missions.count, 20)
        XCTAssertEqual(Set(missions.map(\.id)).count, missions.count)
        XCTAssertTrue(missions.allSatisfy { mission in
            mission.tags.contains("ridiculous")
                && mission.tags.contains("anywhere")
                && mission.tags.contains("present-moment")
                && mission.allowsPhoto
                && !mission.prompt.isEmpty
                && !mission.proofPrompt.isEmpty
        })
        XCTAssertTrue(missions.allSatisfy { PlayfulMissionRegistry.missions.contains($0) })
        XCTAssertTrue(missions.contains { $0.tags.contains("body") })
        XCTAssertTrue(missions.contains { $0.tags.contains("sound") })
        XCTAssertTrue(missions.contains { $0.tags.contains("visual") })
        XCTAssertTrue(missions.contains { $0.tags.contains("touch") })
    }

    func testSharedWonderMissionsJoinPlayfulMissionRegistry() {
        XCTAssertGreaterThanOrEqual(PlayfulMissionRegistry.sharedWonderMissions.count, 10)
        XCTAssertTrue(PlayfulMissionRegistry.missions.contains { $0.id == "shared-no-reply-glint" })
        XCTAssertTrue(PlayfulMissionRegistry.missions.allSatisfy { !$0.prompt.isEmpty && !$0.proofPrompt.isEmpty })
        XCTAssertTrue(PlayfulMissionRegistry.sharedWonderMissions.allSatisfy { $0.tags.contains("shared-wonder") })
    }

    func testHostedSurpriseMissionsAddSixDifferentKindsOfPlay() {
        let missions = PlayfulMissionRegistry.hostedSurpriseMissions
        let byHost = Dictionary(grouping: missions, by: { $0.host.slug })

        XCTAssertEqual(missions.count, 24)
        XCTAssertEqual(Set(missions.map(\.id)).count, missions.count)
        XCTAssertEqual(Set(missions.map(\.title)).count, missions.count)
        XCTAssertEqual(Set(missions.map(\.proofPrompt)).count, missions.count)
        XCTAssertTrue(missions.allSatisfy { $0.tags.contains("hosted-surprise") })
        XCTAssertTrue(missions.allSatisfy { PlayfulMissionRegistry.missions.contains($0) })
        XCTAssertEqual(
            Set(byHost.keys),
            [
                "pippa-pilcrow",
                "penny-blackletter",
                "zara-finch",
                "serenity-brown",
                "lydia-boggle",
                "gwendolyn-mythwright"
            ]
        )
        XCTAssertTrue(byHost.values.allSatisfy { $0.count == 4 })
        XCTAssertGreaterThanOrEqual(
            missions.filter { $0.missionPressureCost < 0.75 }.count,
            20,
            "surprise should usually fit into real life instead of spending the high-pressure budget"
        )
        XCTAssertGreaterThanOrEqual(
            Set(missions.map(\.playMode)).count,
            6,
            "hosted surprise should change the kind of act, not only its wording"
        )
        XCTAssertTrue(missions.allSatisfy { !$0.souvenirInvitation.isEmpty })
    }

    func testRidiculousPerspectiveQuipsJoinCoreOddities() {
        let quips = QuipPackRegistry.ridiculousPerspectiveQuips
        let bundledIDs = Set(QuipPackRegistry.bundledPacks.flatMap(\.quips).map(\.id))

        XCTAssertEqual(quips.count, 40)
        XCTAssertEqual(Set(quips.map(\.id)).count, quips.count)
        XCTAssertEqual(Set(quips.map(\.text)).count, quips.count)
        XCTAssertTrue(quips.allSatisfy { quip in
            quip.tags.contains("ridiculous")
                && quip.tags.contains("perspective")
                && quip.weight >= 2
                && bundledIDs.contains(quip.id)
        })
    }

    func testEverydayEnchantmentsSurfaceAsOneTipPerHelpPage() {
        let enchantments = HelpTipsCatalog.everydayEnchantmentEntries

        XCTAssertEqual(enchantments.count, 31)
        XCTAssertEqual(Set(enchantments.map(\.id)).count, enchantments.count)
        XCTAssertTrue(enchantments.allSatisfy { entry in
            entry.tags.contains("everyday-enchantment")
                && entry.tags.contains("wonder-filled")
                && !entry.title.isEmpty
                && !entry.prompt.isEmpty
                && !entry.body.isEmpty
                && HelpTipsCatalog.entries.contains(entry)
        })

        let day = BookDay.today()
        let surfaces = HelpTipsPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: Date(timeIntervalSinceReferenceDate: 987_654)
        )

        XCTAssertEqual(surfaces.count, 1)
        XCTAssertFalse(surfaces[0].payload.metadata["tipID"]?.isEmpty ?? true)

        let rotation = (0..<48).map { offset in
            HelpTipsCatalog.entry(
                for: day,
                now: Date(timeIntervalSinceReferenceDate: 987_654 + Double(offset * 6 * 3_600))
            )
        }
        XCTAssertTrue(rotation.contains { $0.tags.contains("everyday-enchantment") })
        XCTAssertTrue(rotation.contains { !$0.tags.contains("everyday-enchantment") })
    }

    func testPlayfulMissionRegistryStillReturnsSenseMission() {
        let mission = PlayfulMissionRegistry.mission(
            for: BookDay.today(),
            inputs: .empty,
            now: Date(timeIntervalSinceReferenceDate: 123_456)
        )

        XCTAssertFalse(mission.id.isEmpty)
        XCTAssertFalse(mission.prompt.isEmpty)
        XCTAssertFalse(mission.proofPrompt.isEmpty)
    }

    func testPlayfulMissionRegistryUsesWaningGibbousMoonErrand() {
        let calendar = utcCalendar
        let start = date(2026, 7, 1, hour: 21, calendar: calendar)
        let waning = firstDate(after: start, where: { MoonPhaseCalendar.phase(on: $0).name == "Waning Gibbous" }, calendar: calendar)

        let mission = PlayfulMissionRegistry.mission(
            for: BookDay(id: "moon-mission", date: waning, pages: []),
            inputs: .empty,
            now: waning
        )

        XCTAssertEqual(mission.id, "moon-waning-gibbous-shadow")
        XCTAssertTrue(mission.tags.contains("natural-phenomenon"))
        XCTAssertTrue(mission.prompt.lowercased().contains("moon"))
    }

    func testMoonMissionLookupSchedulesOnlyMoonNights() {
        let calendar = utcCalendar
        let start = date(2026, 7, 1, hour: 21, calendar: calendar)
        let full = firstDate(after: start, where: { MoonPhaseCalendar.phase(on: $0).name == "Full Moon" }, calendar: calendar)
        let quarter = firstDate(after: start, where: { MoonPhaseCalendar.phase(on: $0).name == "First Quarter" }, calendar: calendar)

        let fullMission = PlayfulMissionRegistry.moonMission(on: full)
        XCTAssertEqual(fullMission?.id, "moon-full-face")
        XCTAssertTrue(fullMission?.tags.contains("natural-phenomenon") == true)
        XCTAssertNil(PlayfulMissionRegistry.moonMission(on: quarter))

        let waning = PlayfulMissionRegistry.moonMission(on: firstDate(after: start, where: { MoonPhaseCalendar.phase(on: $0).name == "Waning Gibbous" }, calendar: calendar))
        XCTAssertEqual(waning?.id, "moon-waning-gibbous-shadow")
        XCTAssertTrue(waning?.tags.contains("natural-phenomenon") == true)
    }

    func testPlayfulMissionRegistryUsesStormWindErrandFromWeather() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Pressure drop and storms after dark",
            source: "test",
            forecast: "gusts with a cold front"
        )
        let now = MoonPhaseCalendar.nextNewMoon(after: date(2026, 7, 1, hour: 12, calendar: utcCalendar), calendar: utcCalendar)

        let mission = PlayfulMissionRegistry.mission(
            for: BookDay(id: "storm-mission", date: now, pages: []),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(mission.id, "storm-wind-shift")
        XCTAssertTrue(mission.tags.contains("wind"))
        XCTAssertFalse(mission.allowsPhoto)
    }

    func testPlayfulMissionRegistryUsesWaterPlaceErrand() {
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(id: "harbor", name: "Belfast Harbor Walk", category: "harbor", distanceLabel: "0.4 km", locality: "Belfast")
        ]
        let now = MoonPhaseCalendar.nextNewMoon(after: date(2026, 7, 1, hour: 12, calendar: utcCalendar), calendar: utcCalendar)
        let day = BookDay(id: "water-mission", date: now, pages: [])
        var surfacedIDs = Set<String>()
        for offset in 0..<4 {
            let mission = PlayfulMissionRegistry.mission(
                for: day,
                inputs: inputs,
                now: now.addingTimeInterval(TimeInterval(offset * 2 * 60 * 60))
            )
            XCTAssertTrue(mission.tags.contains("water"))
            surfacedIDs.insert(mission.id)
            inputs.surfaceHistory["playful-mission:\(mission.id)"] = SurfaceHistoryRecord(
                lastShownAt: now.addingTimeInterval(TimeInterval(offset * 2 * 60 * 60)),
                recentShowCount: 1
            )
        }

        XCTAssertEqual(surfacedIDs.count, 4, "A persistent waterfront signal should surface each place-aware mission once.")

        let nextMission = PlayfulMissionRegistry.mission(
            for: day,
            inputs: inputs,
            now: now.addingTimeInterval(8 * 60 * 60)
        )
        XCTAssertFalse(nextMission.tags.contains("water"), "After the waterfront opener, the feed should return to the whole mission pool.")
    }

    func testStandaloneNoticeWonderCompassStartsWithHigherPageBelief() throws {
        let now = date(2026, 7, 1, hour: 12, calendar: utcCalendar)
        let day = BookDay(id: "notice-boost", date: now, pages: [])
        let pages = WonderCompassPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )
        let notice = try XCTUnwrap(pages.first {
            $0.payload.metadata["compassMode"] == "standalone" &&
            $0.payload.metadata["compassStep"] == "notice"
        })

        XCTAssertEqual(notice.sourceID, BookPageSourceRegistry.wonderCompassNoticeSourceID)
        XCTAssertEqual(notice.source.title, "North = Notice")
        XCTAssertEqual(notice.payload.metadata["startingPageBelief"], "62")
        XCTAssertNil(notice.payload.metadata["readerBeliefReward"])

        let source = notice.source
        let baseline = BookPageSourceRegistry.defaultBelief(for: source)
        let narrativeBias = (BookPageSourceRegistry.narrativeWeight(for: source) - 20) / 4
        let adjusted = CuratorSurfacePreferences.none.adjustedScore(for: notice)
        XCTAssertEqual(adjusted, notice.score + narrativeBias + (62 - baseline) / 5)
    }

    func testPlayfulMissionWonderCompassStartsWithHigherPageBelief() throws {
        let now = date(2026, 7, 1, hour: 12, calendar: utcCalendar)
        let day = BookDay(id: "playful-belief-boost", date: now, pages: [])
        let pages = WonderCompassPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )
        let mission = try XCTUnwrap(pages.first {
            $0.payload.metadata["compassMode"] == "standalone" &&
            $0.payload.metadata["playfulMissionID"]?.isEmpty == false
        })

        XCTAssertEqual(mission.sourceID, BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID)
        XCTAssertEqual(mission.source.title, "South = Sense")
        let missionID = try XCTUnwrap(mission.payload.metadata["playfulMissionID"])
        XCTAssertTrue(mission.curatorServedHistoryKeys.contains("playful-mission:\(missionID)"))
        XCTAssertEqual(mission.payload.metadata["startingPageBelief"], "62")
        XCTAssertEqual(mission.payload.metadata["primaryLivedInvitation"], "true")
        XCTAssertNil(mission.payload.metadata["readerBeliefReward"])

        let source = mission.source
        let baseline = BookPageSourceRegistry.defaultBelief(for: source)
        let narrativeBias = (BookPageSourceRegistry.narrativeWeight(for: source) - 20) / 4
        let adjusted = CuratorSurfacePreferences.none.adjustedScore(for: mission)
        XCTAssertEqual(adjusted, mission.score + narrativeBias + (62 - baseline) / 5)
    }

    func testCompassChildSourcesAreListedForPageBeliefWithoutEmbarkClone() throws {
        let profiles = BookPageSourceRegistry.beliefProfiles()
        let activeIDs = Set(BookPageSourceRegistry.activeSources.map(\.id))

        let notice = try XCTUnwrap(profiles.first { $0.sourceID == BookPageSourceRegistry.wonderCompassNoticeSourceID })
        let sense = try XCTUnwrap(profiles.first { $0.sourceID == BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID })
        let souvenir = try XCTUnwrap(profiles.first { $0.sourceID == "one-sentence-souvenir" })

        XCTAssertTrue(activeIDs.contains(BookPageSourceRegistry.wonderCompassNoticeSourceID))
        XCTAssertTrue(activeIDs.contains(BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID))
        XCTAssertEqual(notice.title, "North = Notice")
        XCTAssertEqual(sense.title, "South = Sense")
        XCTAssertEqual(notice.belief, 36)
        XCTAssertEqual(sense.belief, 36)
        XCTAssertEqual(souvenir.type, .souvenir)
        XCTAssertFalse(activeIDs.contains("wonder-compass-embark"))
    }

    func testPennySentenceMasterySurfacesMultipleChapterNinePages() throws {
        let now = date(2026, 7, 1, hour: 12, calendar: utcCalendar)
        let day = BookDay(id: "penny-sentence-mastery", date: now, pages: [])
        let pages = WonderCompassPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )
        let pennyPages = pages.filter { $0.payload.metadata["pennySentenceLesson"] != nil }
        let lessonIDs = Set(pennyPages.compactMap { $0.payload.metadata["pennySentenceLesson"] })
        let expectedIDs = Set(PennySentenceMasteryLesson.allCases.map(\.rawValue))

        XCTAssertEqual(lessonIDs, expectedIDs)
        XCTAssertEqual(pennyPages.count, PennySentenceMasteryLesson.allCases.count)
        for page in pennyPages {
            XCTAssertEqual(page.type, .wonderCompass)
            XCTAssertEqual(page.intent, .capture)
            XCTAssertEqual(page.payload.metadata["snippetID"], "wonder-compass-chapter9")
            XCTAssertTrue(page.payload.metadata["tags"]?.contains("sentence-mastery") == true)
            XCTAssertTrue(page.prompt.contains("Penny Blackletter"))
            XCTAssertFalse(page.payload.metadata["placeholder"]?.isEmpty ?? true)
        }
    }

    func testShadowWonderActivatesAfterDuskThornInvestmentAtNight() {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!

        let state = ShadowWonder.state(inputs: inputs, now: now)

        XCTAssertTrue(state.isUnlocked)
        XCTAssertTrue(state.isNight)
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(ShadowWonder.tags(inputs: inputs, now: now).contains("shadow-wonder"))
    }

    func testShadowWonderVariantBiasesPlayfulMissionsToShadowPool() {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!

        let normalMission = PlayfulMissionRegistry.mission(
            for: BookDay(id: "shadow-day", date: now, pages: []),
            inputs: inputs,
            now: now
        )
        let mission = PlayfulMissionRegistry.mission(
            for: BookDay(id: "shadow-day", date: now, pages: []),
            inputs: inputs,
            now: now,
            shadowVariant: true
        )

        XCTAssertFalse(normalMission.tags.contains("shadow-wonder"))
        XCTAssertTrue(ShadowWonder.prefers(mission: mission))
        XCTAssertTrue(mission.tags.contains("shadow-wonder"))
    }

    func testShadowWonderVisitsOneSurfaceFamilyAtATime() {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!
        var familiesSeen = Set<ShadowWonder.VisitationFamily>()

        for offset in 0..<48 {
            let now = start.addingTimeInterval(Double(offset) * 2 * 60 * 60)
            let visiting = ShadowWonder.VisitationFamily.allCases.filter {
                ShadowWonder.shouldSurface($0, inputs: inputs, now: now)
            }
            XCTAssertEqual(visiting.count, 1, "Shadow Wonder should visit one shelf, not recolor the whole Book")
            familiesSeen.formUnion(visiting)
        }

        XCTAssertGreaterThan(familiesSeen.count, 1, "The Dusk Thorn should move around the Book")

        let quipNow = shadowDate(for: .quip, inputs: inputs, after: start)
        let quipDay = BookDay(id: "shadow-quip-day", date: quipNow, pages: [])
        let quips = QuipPageSourceAdapter().candidates(
            for: quipDay,
            context: CuratorContext.make(for: quipDay),
            inputs: inputs,
            now: quipNow
        )
        XCTAssertNotNil(
            quips.first { $0.payload.metadata["variant"] == "shadow-wonder" },
            "Quips must obey the same visitation rule as every other shadow sibling"
        )
    }

    func testShadowWonderActivatesOnSomberWeatherInDaylight() {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        inputs.weather = WeatherSourceSignal(phrase: "cold rain on the glass", source: "test")
        // Midday, Duskthorn not ascendant: only the broadened triggers can fire.
        let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 13))!

        let state = ShadowWonder.state(inputs: inputs, now: noon)

        XCTAssertFalse(state.isNight)
        XCTAssertTrue(state.isSomberWeather)
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(ShadowWonder.tags(inputs: inputs, now: noon).contains("somber-weather"))
    }

    func testShadowWonderActivatesOnHardDay() {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        inputs.body = BodySourceSignal(status: "watch", score: 30, phrase: "running low, take it gently")
        let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 13))!

        let state = ShadowWonder.state(inputs: inputs, now: noon)

        XCTAssertTrue(state.isHardDay)
        XCTAssertTrue(state.isActive)
    }

    func testShadowWonderStaysLockedUntilDuskThornInvested() {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(phrase: "fog over everything", source: "test")
        let night = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 22))!

        let state = ShadowWonder.state(inputs: inputs, now: night)

        XCTAssertFalse(state.isUnlocked)
        XCTAssertFalse(state.isActive, "Shadow Wonder must stay dormant until the Dusk Thorn is invested in")
    }

    func testShadowSentenceRunnerVariantSurfacesWhenActive() throws {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!
        let now = shadowDate(for: .runner, inputs: inputs, after: start)
        // A day with enough distinct kept phrases for the runner to open.
        let sentences = [
            "The kettle ticked on the cold sill",
            "A blue receipt held a coffee ring",
            "The window fogged at the edges",
            "Gravel shifted under one slow shoe",
            "The lamp guttered once and held",
            "Rain counted itself on the glass",
            "A hinge complained in the dark hall",
            "The mug kept the last of the heat"
        ]
        let pages = sentences.enumerated().map { i, line in
            BookPage(
                id: "kept-\(i)",
                type: .souvenir,
                createdAt: now.addingTimeInterval(Double(-i) * 600),
                promptText: "Souvenir",
                userInput: line
            )
        }
        let day = BookDay(id: "shadow-game-day", date: now, pages: pages)
        let context = CuratorContext.make(for: day)

        let games: [SurfacePage] = GamePageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        let normalGame = try XCTUnwrap(games.first(where: { $0.payload.metadata["variant"] == nil }))
        let shadowGame = try XCTUnwrap(games.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" }))

        XCTAssertEqual(shadowGame.type, .gamePage)
        XCTAssertEqual(shadowGame.payload.metadata["gameID"], "shadow-sentence-runner")
        XCTAssertGreaterThan(shadowGame.score, normalGame.score, "The shadow runner should outscore the bright runner so it wins the slot")
        // The Thornlight lexicon must reach the catchable words.
        let shadowPhrases = (shadowGame.payload.metadata["gamePhrases"] ?? "").lowercased()
        XCTAssertTrue(ShadowWonder.gameWords.contains { shadowPhrases.contains($0) },
                      "Shadow runner should mix the Thornlight lexicon into its words")
    }

    func testShadowVariantWinsTypeSlotOverBrightSibling() {
        // The curator never shows two of the same type at once (SurfaceAndCurator's
        // pickedTypes rule), so a higher-scored shadow variant must take the single
        // slot for its type rather than appearing alongside its bright sibling.
        let bright = SurfacePage(
            id: "souv-bright",
            type: .souvenir,
            score: 60,
            prompt: "One-Sentence Souvenir",
            detail: "Keep one bright particular.",
            payload: BookPagePayload(headline: "h", body: "b", metadata: ["source": "one-sentence-souvenir"])
        )
        let shadow = SurfacePage(
            id: "souv-shadow",
            type: .souvenir,
            score: 72,
            prompt: "One-Sentence Souvenir",
            detail: "Keep one worn particular.",
            payload: BookPagePayload(headline: "h", body: "b", metadata: [
                "source": "one-sentence-souvenir",
                "variant": "shadow-wonder",
                "shadowVariantOf": "souv-bright"
            ])
        )

        let ranked = BookCurator.rankedPages(from: [bright, shadow], limit: 3)
        let souvenirSlots = ranked.filter { $0.page.type == .souvenir }
        XCTAssertEqual(souvenirSlots.count, 1, "Only one souvenir may take the shelf")
        XCTAssertEqual(souvenirSlots.first?.page.payload.metadata["variant"], "shadow-wonder")
    }

    func testShadowLoreRotatesThroughDarkShelf() {
        // The Dusk Thorn's shelf must offer a real body of folklore, not one card.
        let pool = BookReferenceCatalog.shadowLore
        XCTAssertGreaterThanOrEqual(pool.count, 8, "The shadow lore shelf should be a body of folklore")
        XCTAssertTrue(pool.allSatisfy { $0.tags.map { $0.lowercased() }.contains("shadow-wonder") })
        // The real-world lore the reader asked for is reachable.
        let ids = Set(pool.map(\.id))
        XCTAssertTrue(ids.contains("shadow-lore-unseelie-court"))
        XCTAssertTrue(ids.contains("shadow-lore-dealing-with-unseelie"))
        XCTAssertTrue(ids.contains("shadow-lore-correspondences"))

        // Rotation over the day surfaces more than a single snippet.
        let day = BookDay(id: "shadow-lore-day", date: Date(), pages: [])
        var seen = Set<String>()
        for hour in stride(from: 0, through: 22, by: 2) {
            let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: hour))!
            seen.insert(BookReferenceCatalog.rotatingShadowLoreSnippet(for: day, now: now).id)
        }
        XCTAssertGreaterThan(seen.count, 1, "Shadow lore should rotate across the shelf, not repeat one card")
    }

    func testShadowLoreVariantSurfacesUnseelieFolklore() throws {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!
        let now = shadowDate(for: .lore, inputs: inputs, after: start)
        let day = BookDay(id: "shadow-lore-surface", date: now, pages: [])
        let context = CuratorContext.make(for: day)

        let lore: [SurfacePage] = EnchantifyLorePageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        let shadowLore = try XCTUnwrap(lore.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" }))

        XCTAssertEqual(shadowLore.type, .lore)
        XCTAssertTrue(BookReferenceCatalog.shadowLore.map(\.id).contains(shadowLore.payload.metadata["snippetID"] ?? ""),
                      "The shadow lore variant should draw from the dark shelf")
        XCTAssertTrue(shadowLore.payload.metadata["tags"]?.contains("shadow-wonder") == true)
    }

    func testShadowSparkPoolRotatesIWonderQuestions() {
        XCTAssertGreaterThanOrEqual(ShadowWonder.shadowSparks.count, 12, "The dark Notice pool should be a real body of sparks")
        XCTAssertTrue(ShadowWonder.shadowSparks.allSatisfy { $0.text.lowercased().contains("i wonder") })

        var seen = Set<String>()
        for hour in stride(from: 0, through: 22, by: 2) {
            let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: hour))!
            seen.insert(ShadowWonder.spark(inputs: .empty, now: now, dayID: "spark-day"))
        }
        XCTAssertGreaterThan(seen.count, 1, "Shadow sparks should rotate, not repeat one question")
    }

    func testShadowStandaloneNoticeAndCaptureVariantsSurface() throws {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!

        // The standalone North = Notice "I wonder" card has a shadow sibling.
        let compassNow = shadowDate(for: .compass, inputs: inputs, after: start)
        let compassDay = BookDay(id: "shadow-compass-day", date: compassNow, pages: [])
        let compass: [SurfacePage] = WonderCompassPageSourceAdapter().candidates(
            for: compassDay,
            context: CuratorContext.make(for: compassDay),
            inputs: inputs,
            now: compassNow
        )
        let shadowNotice = try XCTUnwrap(compass.first(where: {
            $0.payload.metadata["variant"] == "shadow-wonder"
                && $0.payload.metadata["compassStep"] == "notice"
                && $0.payload.metadata["standalone"] == "true"
        }), "A shadow standalone Notice card should surface on a fresh day")
        // The standalone Notice no longer borrows the Compass Run's "I wonder"
        // spark; it draws from its own Shadow Wonder pool instead.
        XCTAssertEqual(shadowNotice.payload.headline, "North = Notice")
        let shadowID = try XCTUnwrap(shadowNotice.payload.metadata["noticeNowID"])
        XCTAssertTrue(
            NoticeNowRegistry.shadow.contains { $0.id == shadowID },
            "\(shadowID) should come from the Shadow Wonder Notice pool"
        )

        // Inner Weather, Center/Rest, and Today's Sky each gain a shadow variant.
        let moodNow = shadowDate(for: .innerWeather, inputs: inputs, after: start)
        let moodDay = BookDay(id: "shadow-mood-day", date: moodNow, pages: [])
        let mood: [SurfacePage] = MoodPageSourceAdapter().candidates(
            for: moodDay,
            context: CuratorContext.make(for: moodDay),
            inputs: inputs,
            now: moodNow
        )
        XCTAssertNotNil(mood.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" && $0.type == .mood }))

        let restNow = shadowDate(for: .rest, inputs: inputs, after: start)
        let restDay = BookDay(id: "shadow-rest-day", date: restNow, pages: [])
        let rest: [SurfacePage] = RestPageSourceAdapter().candidates(
            for: restDay,
            context: CuratorContext.make(for: restDay),
            inputs: inputs,
            now: restNow
        )
        XCTAssertNotNil(rest.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" && $0.type == .rest }))

        let skyNow = shadowDate(for: .sky, inputs: inputs, after: start)
        let skyDay = BookDay(id: "shadow-sky-day", date: skyNow, pages: [])
        let sky: [SurfacePage] = TodaysSkyPageSourceAdapter().candidates(
            for: skyDay,
            context: CuratorContext.make(for: skyDay),
            inputs: inputs,
            now: skyNow
        )
        let shadowSky = try XCTUnwrap(sky.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" && $0.type == .todaysSky }))
        let skyTags = shadowSky.payload.metadata["tags"] ?? ""
        XCTAssertTrue(skyTags.contains("dark-moon") || skyTags.contains("between-hours"))
    }

    func testFallbackOfferUsesRealPlaceWhenAvailable() {
        let surface = SurfacePage(
            id: "offer", type: .elective, sourceID: "unwritten-elective",
            prompt: "p", detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: [
                "senderName": "Penny Blackletter",
                "senderInterest": "household loyalty",
                "nearbyPlaces": "Tom's Diner (diner, 1.2 km, Riverside)\nMarigold's Bakery (bakery, 800 m, Riverside)"
            ])
        )
        let offer = ElectiveOfferFallback.offer(surface: surface)
        XCTAssertTrue(offer.ask.contains("Tom's Diner"), offer.ask)
        XCTAssertTrue(offer.title.contains("Tom's Diner"))
    }

    func testFallbackOfferStaysGenericWithoutPlaces() {
        let surface = SurfacePage(
            id: "offer", type: .elective, sourceID: "unwritten-elective",
            prompt: "p", detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: ["senderName": "Zara Finch"])
        )
        let offer = ElectiveOfferFallback.offer(surface: surface)
        XCTAssertFalse(offer.ask.contains("(")) // no leaked formatting
        XCTAssertTrue(offer.ask.contains("your town"))
    }

    // MARK: Curator awareness

    func testFatiguePenaltyDecaysOverTime() {
        let now = Date()
        var history: [String: SurfaceHistoryRecord] = [:]
        history["cast:compassion"] = SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3600), recentShowCount: 1)
        let fresh = CuratorVarietyGovernor.fatiguePenalty(forKey: "cast:compassion", history: history, now: now)
        history["cast:compassion"] = SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-5 * 86_400), recentShowCount: 1)
        let stale = CuratorVarietyGovernor.fatiguePenalty(forKey: "cast:compassion", history: history, now: now)
        XCTAssertGreaterThan(fresh, 25)
        XCTAssertLessThan(stale, 8)
        XCTAssertEqual(CuratorVarietyGovernor.fatiguePenalty(forKey: "never-shown", history: history, now: now), 0)
    }

    func testRepeatedlyShownContentLosesToFreshContent() {
        let now = Date()
        func candidate(_ id: String, entityID: String, score: Int) -> SurfacePage {
            SurfacePage(
                id: id, type: .illustration, sourceID: "labyrinth-illustrations",
                score: score, prompt: id, detail: "",
                payload: BookPagePayload(headline: id, body: "", metadata: ["illustrationKind": "cast", "entityID": entityID])
            )
        }
        let tired = candidate("a", entityID: "compassion", score: 70)
        let fresh = candidate("b", entityID: "serenity-brown", score: 60)
        var mood = CuratorMood.neutral
        mood.surfaceHistory = ["cast:compassion": SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3600), recentShowCount: 4)]
        let ranked = BookCurator.rankedPages(from: [tired, fresh], limit: 2, mood: mood, now: now)
        XCTAssertEqual(ranked.first?.page.id, "b", "fatigued content should yield to fresh content")
    }

    func testFinalPickPrefersTypeDiversity() {
        func page(_ id: String, _ type: BookPageType, score: Int) -> SurfacePage {
            SurfacePage(id: id, type: type, sourceID: nil, score: score, prompt: id, detail: "",
                        payload: BookPagePayload(headline: id, body: ""))
        }
        var mood = CuratorMood.neutral
        mood.keptPageCount = 30
        let ranked = BookCurator.rankedPages(
            from: [page("q1", .quip, score: 90), page("q2", .quip, score: 88), page("d1", .diary, score: 60)],
            limit: 2,
            mood: mood
        )
        XCTAssertEqual(Set(ranked.map(\.page.type)).count, 2, "two card slots should hold two kinds")
    }

    func testCastRotationExcludesRecentlySeenMember() {
        let adapter = CastIllustrationPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        func member(_ id: String, belief: Int) -> CustomCastMember {
            CustomCastMember(
                id: id, name: id, kind: .motif, meaning: "m", description: "d",
                traits: [], beliefs: [], goals: [], tags: [],
                baseBelief: belief, narrativeWeight: 20,
                createdAt: Date(), updatedAt: Date(), imageAsset: nil
            )
        }
        inputs.customCastMembers = [member("compassion", belief: 90), member("quiet-shelf", belief: 10)]
        inputs.surfaceHistory = ["cast:compassion": SurfaceHistoryRecord(lastShownAt: Date().addingTimeInterval(-3600), recentShowCount: 2)]
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())
        // The recently-seen favorite steps back; someone else from the cast pool
        // (custom or bundled) takes the page instead.
        XCTAssertNotNil(pages.first?.payload.metadata["entityID"])
        XCTAssertNotEqual(pages.first?.payload.metadata["entityID"], "compassion",
                          "the favorite steps back after being seen")
    }

    func testCastPoolIncludesBundledCharacters() {
        let adapter = CastIllustrationPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        // No custom cast at all: a bundled character should still surface.
        inputs.customCastMembers = []
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())
        XCTAssertEqual(pages.first?.type, .illustration)
        XCTAssertFalse(pages.first?.payload.metadata["entityID"]?.isEmpty ?? true)
    }

    func testLocationBeliefCanSurfaceLocationIllustration() {
        let adapter = CastIllustrationPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets = ["location-kitchens": 80]
        let day = BookDay.today()

        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: Date())

        XCTAssertEqual(pages.first?.payload.metadata["entityID"], "location-kitchens")
        XCTAssertEqual(pages.first?.payload.metadata["entityKind"], "location")
        XCTAssertEqual(pages.first?.payload.metadata["illustrationKind"], "location")
    }

    func testInkedHourSurfacesBeforeEvent() {
        let adapter = CalendarPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        let now = Date()
        inputs.calendarEvents = [
            CalendarEventSignal(id: "e1", title: "Dentist", startsAt: now.addingTimeInterval(30 * 60), isAllDay: false),
            CalendarEventSignal(id: "e2", title: "Far away", startsAt: now.addingTimeInterval(5 * 3600), isAllDay: false)
        ]
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertTrue(pages.contains { $0.payload.metadata["eventTitle"] == "Dentist" })
        XCTAssertFalse(pages.contains { $0.payload.metadata["eventTitle"] == "Far away" })
    }

    func testCalendarDoorPreviewSurfacesWhenIntegrationIsOff() {
        let adapter = CalendarPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        inputs.calendarIntegrationEnabled = false
        let day = BookDay.today()

        let pages = adapter.candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        let preview = pages.first

        XCTAssertEqual(preview?.type, .calendar)
        XCTAssertEqual(preview?.payload.metadata["calendarDoorPreview"], "true")
        XCTAssertEqual(preview?.payload.metadata["requiresCalendarPermission"], "true")
        XCTAssertTrue(preview?.payload.body.contains("I want the hinges") == true)
        XCTAssertTrue(preview?.payload.body.contains("meetings before they pounce") == true)
    }

    func testCalendarDoorPreviewDoesNotInterruptExistingCalendarEvents() {
        let adapter = CalendarPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        inputs.calendarIntegrationEnabled = false
        let now = Date()
        inputs.calendarEvents = [
            CalendarEventSignal(id: "e1", title: "Dentist", startsAt: now.addingTimeInterval(30 * 60), isAllDay: false)
        ]
        let day = BookDay.today()

        let pages = adapter.candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(pages.contains { $0.payload.metadata["eventTitle"] == "Dentist" })
        XCTAssertFalse(pages.contains { $0.payload.metadata["calendarDoorPreview"] == "true" })
    }

    func testHourPageBeforeEventCarriesQuestionAndSupport() {
        let adapter = CalendarPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        let now = Date()
        inputs.calendarEvents = [
            CalendarEventSignal(id: "e1", title: "Dentist", startsAt: now.addingTimeInterval(30 * 60), isAllDay: false)
        ]
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        let page = pages.first { $0.payload.metadata["eventTitle"] == "Dentist" }

        XCTAssertEqual(page?.payload.metadata["hourPhase"], "before")
        XCTAssertEqual(page?.payload.metadata["hourPhaseTitle"], "Before the Hour")
        XCTAssertFalse(page?.payload.metadata["hourQuestion"]?.isEmpty ?? true)
        XCTAssertFalse(page?.payload.metadata["hourSupportTip"]?.isEmpty ?? true)
        XCTAssertTrue(page?.payload.metadata["tags"]?.contains("hour-page") ?? false)
    }

    func testHourPageSurfacesAfterEventForSouvenir() {
        let adapter = CalendarPageSourceAdapter()
        var inputs = BookSourceInputs.empty
        let now = Date()
        let endedAt = now.addingTimeInterval(-35 * 60)
        inputs.calendarEvents = [
            CalendarEventSignal(
                id: "e1",
                title: "Therapy",
                startsAt: endedAt.addingTimeInterval(-60 * 60),
                endsAt: endedAt,
                isAllDay: false
            )
        ]
        let day = BookDay.today()
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        let page = pages.first { $0.payload.metadata["eventTitle"] == "Therapy" }

        XCTAssertEqual(page?.payload.metadata["hourPhase"], "after")
        XCTAssertEqual(page?.payload.metadata["hourPhaseTitle"], "After the Hour")
        XCTAssertTrue(page?.payload.metadata["tags"]?.contains("one-sentence-souvenir") ?? false)
        XCTAssertTrue(page?.payload.metadata["placeholder"]?.contains("One sentence") ?? false)
    }

    func testCalendarPressureQuietsHeavyPages() {
        var mood = CuratorMood.neutral
        mood.minutesToNextCalendarEvent = 20
        let story = SurfacePage(id: "s", type: .narrativeOS, sourceID: nil, score: 80, prompt: "s", detail: "",
                                payload: BookPagePayload(headline: "s", body: ""))
        XCTAssertLessThan(mood.adjustment(for: story), 0)
    }

    // MARK: Search the Stacks

    private func searchDay(id: String, pages: [BookPage]) -> BookDay {
        var day = BookDay.today()
        day = BookDay(id: id, date: Date().addingTimeInterval(-86_400), pages: pages)
        return day
    }

    func testGlowTierQueryFindsMatchingCast() {
        var dataset = StacksSearchDataset()
        dataset.entities = NarrativePackRegistry.entities
        let results = StacksSearchEngine.search("Show me everything with Small Glow", in: dataset)
        XCTAssertFalse(results.isEmpty)
        for result in results where result.kind == .castMember {
            XCTAssertTrue(result.snippet.contains("Small Glow"), result.snippet)
        }
    }

    func testTiredCorrelationFindsCoKeptPages() {
        let moodPage = BookPage(
            type: .mood,
            promptText: "What is the weather inside?",
            userInput: "Completely exhausted, heavy fog",
            tags: ["heavy"]
        )
        let souvenirPage = BookPage(
            type: .souvenir,
            promptText: "One sentence",
            userInput: "The porch light buzzed like a patient wasp.",
            tags: ["porch"]
        )
        var dataset = StacksSearchDataset()
        dataset.days = [searchDay(id: "2026-06-10", pages: [moodPage, souvenirPage])]
        let results = StacksSearchEngine.search("What did I keep when I was tired?", in: dataset)
        XCTAssertTrue(results.contains { $0.referenceID == souvenirPage.id }, "co-kept page should surface")
    }

    func testNameQueryFindsPagesAndMemories() {
        let page = BookPage(
            type: .diary,
            promptText: "Right now",
            userInput: "Morgan laughed at the crooked shelf again.",
            tags: []
        )
        var dataset = StacksSearchDataset()
        dataset.days = [searchDay(id: "2026-06-10", pages: [page])]
        dataset.memories = [
            NarrativeEntityMemory(
                id: "m1", entityID: "penny-blackletter", sourceEventID: "e1", sourcePageID: nil,
                summary: "Penny remembers: Morgan's shelf joke", tags: [], narrativeWeight: 3, createdAt: Date()
            )
        ]
        let results = StacksSearchEngine.search("pages about Morgan", in: dataset)
        XCTAssertTrue(results.contains { $0.kind == .keptPage })
        XCTAssertTrue(results.contains { $0.kind == .memory })
    }

    func testTypeWordFiltersToFamily() {
        let photo = BookPage(type: .illuminatedPhoto, promptText: "Found in the margins", userInput: "kettle", tags: [])
        let diary = BookPage(type: .diary, promptText: "Now", userInput: "kettle", tags: [])
        var dataset = StacksSearchDataset()
        dataset.days = [searchDay(id: "2026-06-10", pages: [photo, diary])]
        let results = StacksSearchEngine.search("photos of kettle", in: dataset)
        let pageResults = results.filter { $0.kind == .keptPage }
        XCTAssertEqual(pageResults.count, 1)
        XCTAssertEqual(pageResults.first?.referenceID, photo.id)
    }

    func testSearchGraphCoversBroadArchiveRecords() {
        let page = BookPage(type: .diary, promptText: "Right now", userInput: "The old shelf creaked.", tags: ["shelf"])
        let event = NarrativeEvent(
            id: "event-1",
            kind: .choiceSelected,
            sourcePageType: .diary,
            sourcePageID: page.id,
            createdAt: Date(),
            summary: "Morgan noticed the shelf again.",
            tags: ["morgan"],
            effect: NarrativeEventEffect()
        )
        let fact = SelfFact(
            id: "fact-1",
            questionID: "favorite-place",
            question: "Where do you return?",
            answer: "The porch.",
            bookTranslation: "The porch is a threshold.",
            sensitivity: .comfort,
            usePermission: .storyOnly,
            tags: ["porch"],
            createdAt: Date(),
            updatedAt: Date()
        )
        let faculty = FacultyEntry(
            id: "faculty-1",
            kind: .innerWeather,
            dayID: "2026-06-10",
            sourcePageID: page.id,
            createdAt: Date(),
            windowID: "weather",
            windowName: "Inner Weather",
            rawText: "A soft fog around the morning.",
            tags: ["fog"]
        )
        var dataset = StacksSearchDataset()
        dataset.days = [searchDay(id: "2026-06-10", pages: [page])]
        dataset.narrativeEvents = [event]
        dataset.selfFacts = [fact]
        dataset.facultyEntries = [faculty]

        let graph = StacksSearchEngine.buildSearchGraph(from: dataset)

        XCTAssertTrue(graph.documents.contains { $0.kind == .keptPage && $0.referenceID == page.id })
        XCTAssertTrue(graph.documents.contains { $0.kind == .narrativeEvent && $0.referenceID == event.id })
        XCTAssertTrue(graph.documents.contains { $0.kind == .selfFact && $0.referenceID == fact.id })
        XCTAssertTrue(graph.documents.contains { $0.kind == .facultyEntry && $0.referenceID == faculty.id })
        XCTAssertTrue(graph.links.contains { $0.fromID == "event-\(event.id)" && $0.toID == "page-\(page.id)" })
        XCTAssertTrue(graph.links.contains { $0.fromID == "faculty-\(faculty.id)" && $0.toID == "page-\(page.id)" })
    }

    func testHybridSearchUsesOnDeviceSemanticEmbeddingsWhenAvailable() throws {
        #if canImport(NaturalLanguage)
        guard let scorer = NaturalLanguageStacksEmbeddingScorer() else {
            throw XCTSkip("NaturalLanguage sentence embeddings are not available on this runtime.")
        }
        let exact = try XCTUnwrap(scorer.similarity(
            between: "I fell asleep on the sofa after dinner.",
            and: "I fell asleep on the sofa after dinner."
        ))
        let unrelated = try XCTUnwrap(scorer.similarity(
            between: "I fell asleep on the sofa after dinner.",
            and: "The brass compass named a thunderstorm over the harbor."
        ))

        XCTAssertGreaterThan(exact, unrelated, "on-device embeddings should score identical meaning above unrelated text")
        #else
        throw XCTSkip("NaturalLanguage is not available on this platform.")
        #endif
    }

    // MARK: Player vault

    func testPlayerVaultDataRoundTrips() throws {
        var data = PlayerVaultData()
        data.entityBelief = ["tide-glass": 12]
        data.tutorSeen = ["glow-menu"]
        data.beliefEconomy = BeliefEconomyState(lastDailyTickDayID: "2026-02-03")
        let alivenessDate = date(2026, 6, 11, hour: 19, calendar: utcCalendar)
        data.readerAliveness = ReaderAlivenessModel(
            observations: [ReaderAlivenessObservation(
                id: "learning-rain-evening",
                sessionID: "session-rain-evening",
                movement: .freshSight,
                role: .door,
                sourceID: "wonder-compass",
                pageID: "silver-city",
                dayID: BookDay.id(for: alivenessDate),
                occurredAt: alivenessDate,
                kind: .livedEvidence,
                authority: .livedReceipt,
                impact: 90,
                facets: ["weather:rain", "time:evening", "place:old-streets"],
                evidenceLine: "The wet city went silver."
            )],
            causalLedger: CausalCurationLedger(
                opportunities: [CausalCurationOpportunity(
                    id: "causal-rain-evening",
                    policyVersion: CausalCurationReceipt.currentPolicyVersion,
                    sessionID: "session-rain-evening",
                    movement: .freshSight,
                    role: .door,
                    selectedSourceID: "wonder-compass",
                    selectedArmID: "freshSight-door-wonder-compass",
                    contextKey: "rain-evening",
                    propensity: 0.6,
                    candidates: [
                        CausalCurationCandidate(
                            sourceID: "wonder-compass",
                            armID: "freshSight-door-wonder-compass",
                            weight: 3
                        ),
                        CausalCurationCandidate(
                            sourceID: "weather",
                            armID: "freshSight-door-weather",
                            weight: 2
                        )
                    ],
                    pressureCost: 0.08,
                    selectedAt: alivenessDate,
                    dayID: BookDay.id(for: alivenessDate)
                )],
                outcomes: [CausalCurationOutcome(
                    id: "lived-causal-rain-evening",
                    opportunityID: "causal-rain-evening",
                    occurredAt: alivenessDate.addingTimeInterval(3600),
                    kind: .livedEvidence,
                    value: 0.9,
                    evidenceLine: "The wet city went silver."
                )],
                lastRecordedAt: alivenessDate.addingTimeInterval(3600)
            ),
            lastUpdatedAt: alivenessDate
        )
        data.castAgency = CastAgencyState(
            resolvedSlotIDs: ["2026-06-12-s02"],
            recentMovements: [
                CastAgencyMovement(
                    slotID: "2026-06-12-s02",
                    kind: .relationship,
                    actorID: "penny-blackletter",
                    actorName: "Penny Blackletter",
                    targetID: "dr-inkrest",
                    targetName: "Dr. Selene Inkrest",
                    amount: 1,
                    line: "Penny Blackletter invested 1 Belief in Dr. Selene Inkrest.",
                    createdAt: date(2026, 6, 12, hour: 8, calendar: utcCalendar)
                )
            ]
        )
        data.compassKnownPlaces = [
            CompassKnownPlace(
                id: "compass-place-cafe-1",
                name: "Cafe",
                contextID: CompassPlaceContext.cafe.rawValue,
                latitude: 44.1,
                longitude: -69.1,
                radiusMeters: 180,
                updatedAt: date(2026, 6, 12, hour: 8, calendar: utcCalendar)
            )
        ]
        data.bookJump = BookJumpState(returned: [
            ReturnedBookJump(
                id: "return-alice",
                bookID: "alice-wonderland",
                title: "Alice's Adventures in Wonderland",
                author: "Lewis Carroll",
                returnedAt: date(2026, 6, 12, hour: 21, calendar: utcCalendar),
                depth: 2,
                degradation: 0,
                souvenir: "The door was smaller than the worry.",
                outcome: "Found the Spine."
            )
        ])
        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded, data)
        XCTAssertEqual(decoded.version, PlayerVaultData.currentVersion)
        XCTAssertEqual(decoded.castAgency?.recentMovements.first?.actorID, "penny-blackletter")
        XCTAssertEqual(decoded.readerAliveness?.observations.first?.pageID, "silver-city")
        XCTAssertEqual(decoded.readerAliveness?.causalLedger?.opportunities.first?.id, "causal-rain-evening")
        XCTAssertEqual(decoded.readerAliveness?.causalLedger?.outcomes.first?.value, 0.9)
    }

    func testCastAgencyStateRemembersRecentSlotsOnly() {
        let now = date(2026, 6, 12, hour: 12, calendar: utcCalendar)
        let recentSlots: Set<String> = ["2026-06-12-s02", "2026-06-12-s03"]
        var state = CastAgencyState(resolvedSlotIDs: ["2026-06-11-s01"])
        let movement = CastAgencyMovement(
            slotID: "2026-06-12-s03",
            kind: .pageSource,
            actorID: "wicker-eddies",
            actorName: "Wicker Eddies",
            targetID: "gossip-page",
            targetName: "Gossip Page",
            amount: 1,
            line: "Wicker Eddies took 1 Belief from Gossip Page Pages.",
            createdAt: now
        )

        state.remember(movement, keepingRecentSlots: recentSlots)

        XCTAssertTrue(state.hasResolved(slotID: "2026-06-12-s03"))
        XCTAssertFalse(state.hasResolved(slotID: "2026-06-11-s01"))
        XCTAssertEqual(state.recentMovements.first, movement)
    }

    // MARK: Support Guild prose

    func testSupportGuildParserKeepsDraftLabelsOutOfVisibleScene() {
        let raw = """
        SCENE:
        Try: Dr. Vellum smoothed the edge of her parchment.

        Try: Dr. Inkrest looked at the weather in the margins.

        VELLUM:
        Try: Read the plate as context, not judgment.
        INKREST:
        Try: Read the mood as weather, not a verdict.
        CONNECTIONS:
        Try: The late page and short sleep are sharing a corner.
        EXPERIMENT:
        Try: Pair the next fuel note with one inner-weather word.
        SAFETY:
        This is not diagnosis or treatment. It is a low-shame pattern note for deciding what to observe next.
        """

        let parsed = SupportGuildProseParser.parse(raw)

        XCTAssertFalse(parsed.scene.contains("Try:"))
        XCTAssertFalse(parsed.vellum.contains("Try:"))
        XCTAssertEqual(parsed.experiment, "Pair the next fuel note with one inner-weather word.")
    }

    func testSupportGuildParserDropsDanglingCutOffTail() {
        let raw = """
        Dr. Vellum closed the chart softly. Dr. Inkrest nodded.

        The useful thing was not certainty. It was the place where the notes touched.

        Try: Dr. Sel
        """

        let parsed = SupportGuildProseParser.parse(raw, fallbackBody: "Fallback.")

        XCTAssertFalse(parsed.scene.contains("Try:"))
        XCTAssertFalse(parsed.scene.hasSuffix("Dr. Sel"))
        XCTAssertTrue(parsed.scene.contains("The useful thing was not certainty."))
    }

    // MARK: Belief economy

    func testBeliefEconomyDailyTickRunsOnceAndDoesNotFeedWholeCast() {
        let now = date(2026, 2, 3, hour: 9, calendar: utcCalendar)
        let yesterday = date(2026, 2, 2, hour: 9, calendar: utcCalendar)
        let page = BookPage(type: .souvenir, createdAt: yesterday, promptText: "One sentence", sourceID: BookPageSourceRegistry.source(for: .souvenir).id)
        let day = BookDay(id: BookDay.id(for: yesterday, calendar: utcCalendar), date: utcCalendar.startOfDay(for: yesterday), pages: [page])
        let event = NarrativeEvent(
            id: "touch-zara",
            kind: .pageKept,
            sourcePageType: .souvenir,
            sourcePageID: page.id,
            createdAt: yesterday,
            summary: "Zara was present.",
            tags: ["entity:zara-finch"],
            effect: NarrativeEventEffect(entityWeightDeltas: ["zara-finch": 1])
        )

        let first = BeliefEconomyEngine.dailyTick(BeliefEconomyDailyContext(
            now: now,
            days: [day],
            entities: NarrativePackRegistry.entities,
            entityBelief: [:],
            pageBelief: [:],
            readerBelief: 4,
            events: [event],
            state: BeliefEconomyState()
        ))

        XCTAssertEqual(first.readerDelta, 1)
        XCTAssertEqual(first.entityDeltas["zara-finch"], 1)
        XCTAssertLessThanOrEqual(first.entityDeltas.count, 2)

        let second = BeliefEconomyEngine.dailyTick(BeliefEconomyDailyContext(
            now: now,
            days: [day],
            entities: NarrativePackRegistry.entities,
            entityBelief: first.entityDeltas,
            pageBelief: [:],
            readerBelief: 5,
            events: [event],
            state: first.state
        ))

        XCTAssertEqual(second.readerDelta, 0)
        XCTAssertTrue(second.entityDeltas.isEmpty)
        XCTAssertTrue(second.pageDeltas.isEmpty)
    }

    func testDailyTickNeverCoolsReaderCastOrPageGlowForTimeAway() {
        let now = date(2026, 2, 3, hour: 9, calendar: utcCalendar)
        let source = BookPageSourceRegistry.source(for: .twoReadings)
        let result = BeliefEconomyEngine.dailyTick(BeliefEconomyDailyContext(
            now: now,
            days: [],
            entities: NarrativePackRegistry.entities,
            entityBelief: ["zara-finch": 70],
            pageBelief: [source.id: 60],
            readerBelief: 92,
            events: [],
            state: BeliefEconomyState()
        ))

        XCTAssertEqual(result.readerDelta, 0)
        XCTAssertTrue(result.entityDeltas.isEmpty)
        XCTAssertTrue(result.pageDeltas.isEmpty)
        XCTAssertTrue(result.movements.isEmpty)
    }

    func testHighReaderGlowDoesNotOverflowIntoRecentlyTouchedCast() {
        let now = date(2026, 2, 3, hour: 9, calendar: utcCalendar)
        let event = NarrativeEvent(
            id: "overflow-touch-zara",
            kind: .pageKept,
            sourcePageType: .gossip,
            sourcePageID: "overflow-page",
            createdAt: now.addingTimeInterval(-3_600),
            summary: "Zara was recently present.",
            tags: ["entity:zara-finch"],
            effect: NarrativeEventEffect(entityWeightDeltas: ["zara-finch": 1])
        )
        let result = BeliefEconomyEngine.dailyTick(BeliefEconomyDailyContext(
            now: now,
            days: [],
            entities: NarrativePackRegistry.entities,
            entityBelief: ["zara-finch": 40],
            pageBelief: [:],
            readerBelief: 91,
            events: [event],
            state: BeliefEconomyState()
        ))

        XCTAssertEqual(result.readerDelta, 0)
        XCTAssertEqual(result.entityDeltas["zara-finch"], 1)
        XCTAssertFalse(result.movements.contains { $0.targetKind == .reader })
        XCTAssertFalse(result.movements.contains { $0.note.contains("overflow") })
    }

    func testBeliefWalletPolicyEarnsFromRealityAndPricesFictionOnce() {
        func surface(_ type: BookPageType, metadata: [String: String] = [:]) -> SurfacePage {
            let source = BookPageSourceRegistry.source(for: type)
            return SurfacePage(
                id: "belief-policy-\(type.rawValue)",
                type: type,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: 50,
                reason: "test",
                prompt: "test",
                detail: "test",
                payload: BookPagePayload(headline: "Test", body: "Test", metadata: metadata)
            )
        }

        XCTAssertEqual(BeliefGenerationKind.storyPage.cost, 5)
        XCTAssertEqual(BeliefGenerationKind.letter.cost, 3)
        XCTAssertEqual(BeliefGenerationKind.note.cost, 1)
        XCTAssertEqual(BeliefGenerationKind.faeParley.cost, 6)
        XCTAssertEqual(BeliefGenerationKind.gossip.cost, 2)
        XCTAssertEqual(BeliefGenerationKind.enchantment.cost, 4)

        let storyDraft = surface(.narrativeOS)
        XCTAssertEqual(BeliefEconomyPolicy.generationKind(for: storyDraft), .storyPage)
        XCTAssertNil(BeliefEconomyPolicy.generationKind(for: storyDraft.recordingBeliefGenerationPayment(.storyPage)))

        XCTAssertEqual(BeliefEconomyPolicy.keepReward(for: surface(.souvenir)), 1)
        XCTAssertEqual(BeliefEconomyPolicy.keepReward(for: storyDraft), 0)
        XCTAssertEqual(BeliefEconomyPolicy.keepReward(for: surface(.souvenir, metadata: ["noBeliefReward": "true"])), 0)

        XCTAssertGreaterThan(BeliefEconomyPolicy.compassRunReward, BeliefEconomyPolicy.electiveCompletionReward)
        XCTAssertGreaterThan(
            BeliefEconomyPolicy.compassRunReward,
            BookJumpEngine.returnReward(depth: BookJumpEngine.maxDepth, hasSouvenir: true)
        )
    }

    func testBeliefEconomyWarmsKeptSourceOncePerDay() {
        let now = date(2026, 2, 3, hour: 9, calendar: utcCalendar)
        let source = BookPageSourceRegistry.source(for: .souvenir)
        let dayID = BookDay.id(for: now, calendar: utcCalendar)
        let first = BeliefEconomyEngine.sourceKeep(source: source, dayID: dayID, now: now, pageBelief: [:], state: BeliefEconomyState())
        let second = BeliefEconomyEngine.sourceKeep(source: source, dayID: dayID, now: now, pageBelief: [source.id: first.delta], state: first.state)

        XCTAssertEqual(first.delta, 1)
        XCTAssertEqual(second.delta, 0)
    }

    func testBeliefEconomyCoolsAfterRepeatedDismissals() {
        let now = date(2026, 2, 3, hour: 9, calendar: utcCalendar)
        let source = BookPageSourceRegistry.source(for: .twoReadings)
        let dayID = BookDay.id(for: now, calendar: utcCalendar)
        let first = BeliefEconomyEngine.sourceDismissed(source: source, dayID: dayID, now: now, pageBelief: [:], state: BeliefEconomyState())
        let second = BeliefEconomyEngine.sourceDismissed(source: source, dayID: dayID, now: now, pageBelief: [:], state: first.state)

        XCTAssertEqual(first.delta, 0)
        XCTAssertEqual(second.delta, -1)
    }

    func testCastSpendDeltaNeverSpendsBelowFloor() {
        XCTAssertEqual(BeliefEconomyEngine.castSpendDelta(actorBelief: 40, requested: 3), -3)
        XCTAssertEqual(BeliefEconomyEngine.castSpendDelta(actorBelief: 19, requested: 3), -1)
        XCTAssertEqual(BeliefEconomyEngine.castSpendDelta(actorBelief: 18, requested: 3), 0)
    }

    // MARK: Chapters and Talismans

    func testEveryChapterHasItsTalismanInThePack() {
        XCTAssertEqual(AcademyChapterRegistry.chapters.count, 5)
        XCTAssertEqual(AcademyChapterRegistry.publicChapters.count, 5)
        XCTAssertTrue(AcademyChapterRegistry.publicChapters.contains { $0.id == "duskthorn" })
        for chapter in AcademyChapterRegistry.chapters {
            let talisman = NarrativePackRegistry.entities.first { $0.id == chapter.talismanID }
            XCTAssertNotNil(talisman, "missing talisman \(chapter.talismanID)")
            XCTAssertEqual(talisman?.kind, .talisman)
            XCTAssertEqual(talisman?.chapter, chapter.name)
        }
    }

    func testEveryChapterBindingCeremonyHasOathAndInvitation() {
        for chapter in AcademyChapterRegistry.publicChapters {
            let ceremony = ChapterBindingCeremony.profile(for: chapter)
            XCTAssertFalse(ceremony.arrivalLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(ceremony.sealLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(ceremony.oathLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(ceremony.invitationLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(ceremony.aftermathLine.contains("After this"))
        }
    }

    func testEveryCharacterHasAChapter() {
        let chapterNames = Set(AcademyChapterRegistry.chapters.map(\.name))
        for entity in NarrativePackRegistry.entities where entity.kind == .character {
            let chapter = entity.chapter ?? ""
            XCTAssertTrue(chapterNames.contains(chapter), "\(entity.id) has no valid chapter (\(chapter))")
        }
    }

    func testAscendancyFollowsBelief() {
        let entities = NarrativePackRegistry.entities
        let unmoved = TalismanAscendancy.ascendant(entities: entities, beliefOffsets: [:])
        XCTAssertEqual(unmoved?.id, "dusk-thorn", "Dusk Thorn ships with the most Belief")
        let talismanBelief = Dictionary(
            uniqueKeysWithValues: entities
                .filter { $0.kind == .talisman }
                .map { ($0.id, $0.belief) }
        )
        XCTAssertEqual(talismanBelief["dusk-thorn"], 10)
        XCTAssertEqual(talismanBelief["ember-seal"], 10)
        XCTAssertEqual(talismanBelief["wind-cipher"], 10)
        XCTAssertEqual(talismanBelief["tide-glass"], 10)
        XCTAssertEqual(talismanBelief["moss-clasp"], 10)

        let flipped = TalismanAscendancy.ascendant(
            entities: entities,
            beliefOffsets: ["moss-clasp": 90]
        )
        XCTAssertEqual(flipped?.id, "moss-clasp", "player Belief can flip ascendancy")
    }

    func testChapterBindingWaitsThenSurfacesChosenChapterUntilBound() {
        let adapter = AboutYouPageSourceAdapter()
        let calendar = Calendar.current
        let now = date(2026, 6, 8, hour: 12, calendar: calendar)
        let days = [
            bindingDay(1, text: "Amanda and I walked by the harbor and the water made the whole day feel shared."),
            bindingDay(2, text: "A letter from the margins made the room feel less lonely."),
            bindingDay(3, text: "We talked about the small adventure and kept laughing about the coffee sign."),
            bindingDay(4, text: "Together was the word that kept returning to the page."),
            bindingDay(5, text: "The Book noticed companionship before it noticed courage.")
        ]
        let day = days.last!
        var inputs = BookSourceInputs.empty
        inputs.days = days
        inputs.selfFacts = [fact("onboarding-name", tags: ["name"])]
        inputs.surfaceHistory = shownChapterPrimerHistory(now: now)
        let unbound = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        let binding = unbound.first { $0.payload.metadata["chapterBinding"] == "true" }
        XCTAssertNotNil(binding)
        XCTAssertEqual(binding?.payload.metadata["chosenChapterID"], "riddlewind")
        XCTAssertEqual(binding?.payload.metadata["chosenChapterName"], "Riddlewind")
        XCTAssertTrue(binding?.payload.body.contains("No questionnaire") == true)
        XCTAssertTrue(binding?.payload.body.contains("Chapter Riddlewind") == true)
        guard let riddlewind = AcademyChapterRegistry.chapter(id: "riddlewind") else {
            XCTFail("Missing Riddlewind")
            return
        }
        let ceremony = ChapterBindingCeremony.profile(for: riddlewind)
        XCTAssertEqual(binding?.payload.metadata["bindingSealLine"], ceremony.sealLine)
        XCTAssertEqual(binding?.payload.metadata["bindingOathLine"], ceremony.oathLine)
        XCTAssertEqual(binding?.payload.metadata["bindingInvitationLine"], ceremony.invitationLine)
        XCTAssertEqual(binding?.payload.metadata["bindingAftermathLine"], ceremony.aftermathLine)
        XCTAssertTrue(binding?.payload.body.contains("The seal does not stop at naming you") == true)
        XCTAssertTrue(binding?.payload.body.contains(ceremony.invitationLine) == true)

        inputs.selfFacts.append(fact("chapter-binding", tags: ["chapter"]))
        let bound = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertFalse(bound.contains { $0.payload.metadata["chapterBinding"] == "true" })
    }

    func testChapterPrimerSurfacesBeforeBindingIsReady() {
        let adapter = AboutYouPageSourceAdapter()
        let now = date(2026, 6, 4, hour: 12, calendar: Calendar.current)
        let days = [
            bindingDay(1, text: "The rain made the morning quiet."),
            bindingDay(2, text: "A small sentence stayed in the margins.")
        ]
        let day = days.last!
        var inputs = BookSourceInputs.empty
        inputs.days = days
        inputs.selfFacts = [fact("onboarding-name", tags: ["name"])]

        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)

        XCTAssertNil(pages.first { $0.payload.metadata["chapterBinding"] == "true" })
        let primer = pages.first { $0.payload.metadata["chapterPrimer"] == "true" }
        XCTAssertNotNil(primer)
        XCTAssertTrue(primer?.payload.body.contains("The Binding") == true)
    }

    func testChapterBindingDoesNotUseAgeAsASubstituteForEvidence() {
        let oldThinLibrary = [
            bindingDay(1, text: "A first page."),
            bindingDay(2, text: "A second page.")
        ]
        let readiness = ChapterBindingOracle.readiness(
            days: oldThinLibrary,
            now: date(2026, 6, 30, hour: 12, calendar: .current)
        )
        XCTAssertFalse(readiness.isReady)
    }

    func testChapterBindingRequiresAllPrimerCardsToHaveShown() {
        let adapter = AboutYouPageSourceAdapter()
        let calendar = Calendar.current
        let now = date(2026, 6, 8, hour: 12, calendar: calendar)
        let days = [
            bindingDay(1, text: "Amanda and I walked by the harbor and the water made the whole day feel shared."),
            bindingDay(2, text: "A letter from the margins made the room feel less lonely."),
            bindingDay(3, text: "We talked about the small adventure and kept laughing about the coffee sign."),
            bindingDay(4, text: "Together was the word that kept returning to the page."),
            bindingDay(5, text: "The Book noticed companionship before it noticed courage.")
        ]
        let day = days.last!
        var inputs = BookSourceInputs.empty
        inputs.days = days
        inputs.selfFacts = [fact("onboarding-name", tags: ["name"])]

        let firstPass = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        let firstPrimer = firstPass.first { $0.payload.metadata["chapterPrimer"] == "true" }
        XCTAssertNil(firstPass.first { $0.payload.metadata["chapterBinding"] == "true" })
        XCTAssertEqual(firstPrimer?.payload.metadata["primerStage"], "1")
        XCTAssertEqual(firstPrimer?.varietyKey, "chapter-primer:1")

        inputs.surfaceHistory = [
            "chapter-primer:1": SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-3600), recentShowCount: 1),
            "chapter-primer:2": SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(-1800), recentShowCount: 1)
        ]
        let thirdPass = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        let thirdPrimer = thirdPass.first { $0.payload.metadata["chapterPrimer"] == "true" }
        XCTAssertNil(thirdPass.first { $0.payload.metadata["chapterBinding"] == "true" })
        XCTAssertEqual(thirdPrimer?.payload.metadata["primerStage"], "3")

        inputs.surfaceHistory = shownChapterPrimerHistory(now: now)
        let bindingPass = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertNotNil(bindingPass.first { $0.payload.metadata["chapterBinding"] == "true" })
        XCTAssertNil(bindingPass.first { $0.payload.metadata["chapterPrimer"] == "true" })
    }

    func testChapterBindingOracleHonorsTalismanBeliefInvestment() {
        let days = [
            bindingDay(1, text: "A quiet page about rain."),
            bindingDay(2, text: "A quiet page about moss."),
            bindingDay(3, text: "A quiet page about rest.")
        ]
        let choice = ChapterBindingOracle.chooseChapter(
            days: days,
            selfFacts: [],
            entityBeliefOffsets: ["ember-seal": 30]
        )

        XCTAssertEqual(choice.chapter.id, "emberheart")
        XCTAssertGreaterThan(choice.scores["emberheart"] ?? 0, choice.scores["mossbloom"] ?? 0)
    }

    func testChapterBindingOracleCanChooseDuskthorn() {
        let days = [
            bindingDay(1, text: "The honest hard truth was that I needed a boundary."),
            bindingDay(2, text: "I protected the day by naming the difficult thing instead of avoiding it."),
            bindingDay(3, text: "The page kept the conflict because smoothing it away would have made the story false."),
            bindingDay(4, text: "A thorn can be protection, not cruelty."),
            bindingDay(5, text: "The Rut of Routine loses ground when the sentence is interesting enough to stay.")
        ]
        let selfFacts = [
            SelfFact(
                id: "dusk-self",
                questionID: "belief-style",
                question: "What kind of truth matters?",
                answer: "Honest boundaries and difficult protection.",
                bookTranslation: "Honest boundaries and difficult protection.",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["honest", "boundary", "protection"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let choice = ChapterBindingOracle.chooseChapter(days: days, selfFacts: selfFacts)

        XCTAssertEqual(choice.chapter.id, "duskthorn")
        XCTAssertTrue(choice.evidenceLines.contains { $0.contains("difficult") || $0.contains("protection") })
    }

    func testWelcomePageRestoresAuthoredBookBrainInvitation() {
        let day = BookDay.today()
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            SelfFact(
                id: "onboarding-name",
                questionID: "onboarding-name",
                question: "What should the Book call you?",
                answer: "Beej",
                bookTranslation: "Beej",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["name", "identity", "onboarding"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let welcome = LabyrinthWelcomePageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        ).first

        XCTAssertEqual(welcome?.type, .welcome)
        XCTAssertEqual(welcome?.payload.metadata["playerName"], "Beej")
        XCTAssertEqual(welcome?.payload.headline, "Oh. There You Are.")
        XCTAssertTrue(welcome?.payload.body.contains("I have your name now") == true)
        XCTAssertTrue(welcome?.payload.body.contains("I don’t have a brain yet") == true)
        XCTAssertTrue(welcome?.payload.body.contains("I want to see what your Tuesdays are hiding") == true)
        XCTAssertTrue(welcome?.payload.metadata["tags"]?.contains("local-brain") == true)
        XCTAssertTrue(welcome?.payload.metadata["tags"]?.contains("colophon") == true)
        XCTAssertGreaterThan(welcome?.score ?? 0, 80)
    }

    func testWelcomePageKeepsBookBrainInvitationAfterCompletedFirstDoor() {
        let startedAt = Date()
        let day = BookDay.today()
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)

        let welcome = LabyrinthWelcomePageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: startedAt
        ).first

        XCTAssertEqual(welcome?.payload.headline, "Oh. There You Are.")
        XCTAssertTrue(welcome?.payload.body.contains("I don’t have a brain yet") == true)
        XCTAssertTrue(welcome?.payload.metadata["tags"]?.contains("local-brain") == true)
    }

    func testWelcomePageDoesNotRepeatAfterBeingServed() {
        let day = BookDay.today()
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            SelfFact(
                id: "onboarding-name",
                questionID: "onboarding-name",
                question: "What should the Book call you?",
                answer: "Beej",
                bookTranslation: "Beej",
                sensitivity: .delight,
                usePermission: .privateContext,
                tags: ["name", "identity", "onboarding"],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        ]

        let pages = LabyrinthWelcomePageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertTrue(pages.isEmpty)
    }

    func testFirstDoorOriginSurfaceReturnsFullAuthoredOnboardingEvidence() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let day = BookDay(id: "2026-06-01", date: startedAt, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)
        inputs.selfFacts.append(contentsOf: [
            firstDoorFact(
                "onboarding-moment-fate",
                answer: "I mean to, then forget",
                tags: ["attention", "lived-experience", "onboarding"],
                startedAt: startedAt
            ),
            firstDoorFact(
                "onboarding-hidden-magic",
                answer: "Not yet. Show me.",
                tags: ["hidden-magic", "lived-experience", "onboarding"],
                startedAt: startedAt
            ),
            firstDoorFact(
                "onboarding-taste",
                answer: "oddities",
                tags: ["taste", "pages", "onboarding"],
                startedAt: startedAt
            ),
            firstDoorFact(
                "onboarding-comfort-boundary",
                answer: "strange",
                tags: ["comfort", "edge", "onboarding"],
                startedAt: startedAt
            )
        ])

        let origin = FirstDoorOriginPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: startedAt
        ).first

        XCTAssertEqual(origin?.type, .welcome)
        XCTAssertEqual(origin?.sourceID, "first-door-origin")
        XCTAssertEqual(origin?.payload.metadata["firstDoorOrigin"], "true")
        XCTAssertEqual(origin?.varietyKey, "first-door-origin")
        XCTAssertTrue(origin?.payload.body.contains("Beej") == true)
        XCTAssertTrue(origin?.payload.body.contains("The lamp made a small gold island on the desk.") == true)
        XCTAssertTrue(origin?.payload.body.contains("I mean to, then forget") == true)
        XCTAssertTrue(origin?.payload.body.contains("Not yet. Show me.") == true)
        XCTAssertTrue(origin?.payload.body.contains("peanut butter toast") == true)
        XCTAssertTrue(origin?.payload.body.contains("Small strange things count.") == true)
        XCTAssertTrue(origin?.payload.body.contains("Funny little oddities") == true)
        XCTAssertTrue(origin?.payload.body.contains("Let it get strange") == true)
    }

    func testFirstRunSequenceLeavesWelcomeAndOriginOnTheShelf() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let day = BookDay(id: "2026-06-01", date: startedAt, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)

        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: startedAt
        ))

        XCTAssertEqual(
            LabyrinthWelcomePageSourceAdapter().candidates(
                for: day,
                context: CuratorContext.make(for: day),
                inputs: inputs,
                now: startedAt
            ).first?.sourceID,
            "labyrinth-welcome"
        )
        XCTAssertEqual(
            FirstDoorOriginPageSourceAdapter().candidates(
                for: day,
                context: CuratorContext.make(for: day),
                inputs: inputs,
                now: startedAt
            ).first?.sourceID,
            "first-door-origin"
        )
        XCTAssertNil(FirstRunPageSequence.pendingLocalBrainUpgrade(inputs: inputs))

        inputs.firstRunEngagedKeys.insert("source:\(FirstRunPageSequence.firstMissionSourceID)")
        XCTAssertEqual(
            FirstRunPageSequence.pendingLocalBrainUpgrade(inputs: inputs)?.sourceID,
            FirstRunPageSequence.localBrainSetupSourceID
        )
    }

    func testFirstRunSequenceOffersEnchantmentAfterBrainInsteadOfDuplicateSouvenirAsk() {
        var day = BookDay.today()
        day.pages.append(BookPage(
            type: .souvenir,
            promptText: "What was the first true sentence you kept?",
            userInput: "The lamp made a small gold island on the desk.",
            tags: ["souvenir", "first-run-souvenir", "onboarding-first-souvenir"],
            sourceID: "one-sentence-souvenir",
            origin: .userAuthored,
            privacy: .privateLocal
        ))
        var inputs = BookSourceInputs.empty

        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        ))

        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1),
            "source:local-brain-awake": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        ]
        inputs.firstRunEngagedKeys = [
            "source:\(FirstRunPageSequence.firstMissionSourceID)",
            "source:local-brain-awake"
        ]
        inputs.localBrainIsReady = true

        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        ))

        let enchantment = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        XCTAssertEqual(enchantment?.type, .enchantment)
        XCTAssertEqual(enchantment?.sourceID, FirstRunPageSequence.enchantmentIntroSourceID)
        XCTAssertEqual(enchantment?.payload.metadata["firstRunStep"], "enchantment-intro")
        XCTAssertTrue(enchantment?.payload.body.contains("Enchantment") == true)

        inputs.firstRunEngagedKeys.insert("source:\(FirstRunPageSequence.enchantmentIntroSourceID)")
        inputs.calendarIntegrationEnabled = true
        let afterEnchantment = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        XCTAssertEqual(afterEnchantment?.sourceID, FirstRunPageSequence.compassIntroductionSourceID)
        XCTAssertTrue(afterEnchantment?.payload.body.contains("North · Notice") == true)
        XCTAssertTrue(afterEnchantment?.payload.body.contains("Center · Rest") == true)

    }

    func testFirstRunSequenceOffersCalendarDoorAfterTheFirstMissionWhenClosed() {
        var day = BookDay.today()
        day.pages.append(BookPage(
            type: .souvenir,
            promptText: "What was the first true sentence you kept?",
            userInput: "The lamp made a small gold island on the desk.",
            tags: ["souvenir", "first-run-souvenir", "onboarding-first-souvenir"],
            sourceID: "one-sentence-souvenir",
            origin: .userAuthored,
            privacy: .privateLocal
        ))
        var inputs = BookSourceInputs.empty
        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1),
            "source:local-brain-awake": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        ]
        inputs.firstRunEngagedKeys = [
            "source:\(FirstRunPageSequence.firstMissionSourceID)",
            "source:local-brain-awake"
        ]
        inputs.localBrainIsReady = true
        inputs.calendarIntegrationEnabled = false

        let pages = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(pages?.sourceID, FirstRunPageSequence.enchantmentIntroSourceID)

        inputs.firstRunEngagedKeys.insert("source:\(FirstRunPageSequence.enchantmentIntroSourceID)")
        let afterEnchantment = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        XCTAssertEqual(afterEnchantment?.sourceID, "calendar-page")
        XCTAssertEqual(afterEnchantment?.payload.metadata["calendarDoorPreview"], "true")

        inputs.firstRunEngagedKeys.insert("source:calendar-page")
        let afterCalendarDoor = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(afterCalendarDoor?.sourceID, FirstRunPageSequence.compassIntroductionSourceID)
    }

    func testFirstRunSequenceLeadsWithMissionWhenOnboardingSkippedSouvenir() {
        let day = BookDay.today()
        let now = Date()
        var inputs = BookSourceInputs.empty
        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1),
            "source:local-brain-awake": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1),
            "source:\(FirstRunPageSequence.enchantmentIntroSourceID)": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1)
        ]
        inputs.firstRunEngagedKeys = [
            "source:labyrinth-welcome",
            "source:local-brain-awake",
            "source:\(FirstRunPageSequence.enchantmentIntroSourceID)",
            "source:\(FirstRunPageSequence.compassIntroductionSourceID)",
            "source:\(FirstRunPageSequence.compassRunIntroSourceID)"
        ]
        inputs.localBrainIsReady = true
        inputs.calendarIntegrationEnabled = true

        // No kept first souvenir: Home still leads with a real-world act rather
        // than another orientation toll.
        let pages = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(pages?.sourceID, FirstRunPageSequence.firstMissionSourceID)
        XCTAssertEqual(pages?.type, .helpTips)
        XCTAssertEqual(pages?.payload.metadata["firstRunStep"], "first-mission")
    }

    func testFirstRunSequenceTeachesCompassThenOffersARealRunWithoutATimeWindow() {
        let calendar = utcCalendar
        let brainShownAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let day = BookDay(id: "2026-06-01", date: brainShownAt, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.localBrainIsReady = true
        inputs.calendarIntegrationEnabled = true
        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: brainShownAt, recentShowCount: 1),
            "source:local-brain-awake": SurfaceHistoryRecord(lastShownAt: brainShownAt, recentShowCount: 1),
            "source:\(FirstRunPageSequence.enchantmentIntroSourceID)": SurfaceHistoryRecord(lastShownAt: brainShownAt, recentShowCount: 1)
        ]
        inputs.firstRunEngagedKeys = [
            "source:\(FirstRunPageSequence.firstMissionSourceID)",
            "source:labyrinth-welcome",
            "source:local-brain-awake",
            "source:\(FirstRunPageSequence.enchantmentIntroSourceID)"
        ]

        let introduction = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(20 * 60)
        )
        XCTAssertEqual(introduction?.sourceID, FirstRunPageSequence.compassIntroductionSourceID)
        XCTAssertEqual(introduction?.payload.metadata["firstRunStep"], "compass-introduction")
        XCTAssertTrue(introduction?.payload.body.contains("not a map app") == true)
        XCTAssertTrue(introduction?.payload.body.contains("time and energy") == true)
        XCTAssertTrue(introduction?.payload.body.contains("before wonder turns into homework") == true)

        inputs.firstRunEngagedKeys.insert("source:\(FirstRunPageSequence.compassIntroductionSourceID)")
        let run = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(13 * 3600)
        )
        XCTAssertEqual(run?.sourceID, FirstRunPageSequence.compassRunIntroSourceID)
        XCTAssertEqual(run?.type, .wonderCompass)
        XCTAssertEqual(run?.payload.metadata["firstRunStep"], "compass-run")
        XCTAssertTrue(run?.detail.contains("six small questions one at a time") == true)

        inputs.firstRunEngagedKeys.insert("source:\(FirstRunPageSequence.compassRunIntroSourceID)")
        let afterCompass = FirstRunPageSequence.guidedRider(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(60 * 60)
        )
        XCTAssertNil(afterCompass)
    }

    func testCompassRunConstraintQuestionsHaveOneCompleteOrderedPass() {
        XCTAssertEqual(
            CompassRunConstraintStep.allCases,
            [.location, .time, .energy, .companions, .budget, .considerations]
        )
        XCTAssertEqual(CompassRunConstraintStep.location.previous, nil)
        XCTAssertEqual(CompassRunConstraintStep.location.next, .time)
        XCTAssertEqual(CompassRunConstraintStep.budget.next, .considerations)
        XCTAssertEqual(CompassRunConstraintStep.considerations.next, nil)
        XCTAssertEqual(CompassRunConstraintStep.considerations.ordinal, 6)
        XCTAssertEqual(Set(CompassRunConstraintStep.allCases.map(\.question)).count, 6)
    }

    func testLivingDeskOpensAfterTheShortFirstDoorCeremony() {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: now)
        inputs.firstRunEngagedKeys = [
            "source:labyrinth-welcome",
            "first-door-origin",
            "source:\(FirstRunPageSequence.localBrainSetupSourceID)"
        ]

        let current = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let feed = [
            SurfacePage(type: .lore, sourceID: "test-lore", prompt: "Lore", detail: "One strange fact."),
            SurfacePage(type: .mood, sourceID: "test-mood", prompt: "Mood", detail: "One feeling."),
            SurfacePage(type: .narrativeOS, sourceID: "test-story", prompt: "Story", detail: "One living scene."),
            SurfacePage(type: .quip, sourceID: "test-quip", prompt: "Quip", detail: "One joke.")
        ]

        let merged = FirstRunPageSequence.mergingCurrentStep(current, into: feed, limit: 3)

        XCTAssertNil(current)
        XCTAssertEqual(merged.map(\.sourceID), ["test-lore", "test-mood", "test-story"])
        XCTAssertFalse(merged.contains { $0.sourceID == "labyrinth-welcome" })
        XCTAssertFalse(merged.contains { $0.sourceID == "first-door-origin" })
    }

    func testRealFirstCuratorFeedIsNotHeldBehindAnOriginReplay() {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.days = [day]
        inputs.selfFacts = firstDoorFacts(startedAt: now)
        inputs.localBrainIsReady = true
        inputs.firstRunEngagedKeys = [
            "source:labyrinth-welcome",
            "first-door-origin",
            "source:\(FirstRunPageSequence.localBrainSetupSourceID)",
            "source:local-brain-awake"
        ]
        inputs.surfaceHistory["source:labyrinth-welcome"] = SurfaceHistoryRecord(
            lastShownAt: now.addingTimeInterval(-60),
            recentShowCount: 1
        )

        let current = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        let feed = BookCurator.surfacedPages(
            for: day,
            inputs: inputs,
            now: now,
            limit: 12
        )
        let merged = FirstRunPageSequence.mergingCurrentStep(current, into: feed, limit: 12)

        XCTAssertNil(current)
        XCTAssertGreaterThan(merged.count, 1)
        XCTAssertEqual(merged.map(\.id), Array(feed.prefix(12)).map(\.id))
        XCTAssertLessThanOrEqual(merged.prefix(3).filter(\.isReaderActionCommission).count, 1)
    }

    func testFirstWelcomeRemainsARealShelfPageRatherThanACeremony() throws {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        ))

        let welcome = try XCTUnwrap(
            LabyrinthWelcomePageSourceAdapter().candidates(
                for: day,
                context: CuratorContext.make(for: day),
                inputs: .empty,
                now: now
            ).first
        )
        XCTAssertEqual(welcome.sourceID, "labyrinth-welcome")
        XCTAssertFalse(FirstRunPageSequence.isCeremonySurface(welcome))
    }

    func testOptionalBrainDoesNotBlockTheLivingDeskOrLaterGuidance() {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: now)
        inputs.calendarIntegrationEnabled = true
        inputs.firstRunEngagedKeys = [
            "source:\(FirstRunPageSequence.firstMissionSourceID)"
        ]

        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        ))
        XCTAssertEqual(
            FirstRunPageSequence.guidedRider(
                for: day,
                context: CuratorContext.make(for: day),
                inputs: inputs,
                now: now
            )?.sourceID,
            FirstRunPageSequence.compassIntroductionSourceID
        )
        XCTAssertEqual(
            FirstRunPageSequence.pendingLocalBrainUpgrade(inputs: inputs)?.sourceID,
            FirstRunPageSequence.localBrainSetupSourceID
        )
    }

    func testBrainAwakeDoesNotReopenThePostDoorCeremony() {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: now)
        inputs.localBrainIsReady = true
        inputs.firstRunEngagedKeys = ["source:\(FirstRunPageSequence.firstMissionSourceID)"]

        XCTAssertNil(FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        ))
    }

    func testAlivenessAnswerStillAuthorsAnOriginShelfPage() throws {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: now) + [
            firstDoorFact(
                "onboarding-most-alive",
                answer: "Outside somewhere",
                tags: ["aliveness", "attention", "onboarding"],
                startedAt: now
            )
        ]
        let origin = try XCTUnwrap(FirstDoorOriginPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        ).first)
        XCTAssertEqual(origin.sourceID, "first-door-origin")

        inputs.firstRunEngagedKeys.insert("source:\(FirstRunPageSequence.firstMissionSourceID)")
        XCTAssertEqual(
            FirstRunPageSequence.pendingLocalBrainUpgrade(inputs: inputs)?.sourceID,
            FirstRunPageSequence.localBrainSetupSourceID
        )
    }

    func testGuidedFirstDoorRiderSharesAFullDeskWithTwoOrdinaryPages() {
        let rider = SurfacePage(
            type: .wonderCompass,
            sourceID: FirstRunPageSequence.compassRunIntroSourceID,
            prompt: "First run",
            detail: "Try the Compass.",
            payload: BookPagePayload(headline: "First run", body: "Try it.", metadata: [
                "firstRunStep": "compass-run"
            ])
        )
        let feed = [
            SurfacePage(
                type: .helpTips,
                sourceID: "first-door-apprenticeship",
                prompt: "Another lesson",
                detail: "This one should rest.",
                payload: BookPagePayload(headline: "Another lesson", body: "Rest.", metadata: [
                    "firstDoorApprenticeshipDay": "2",
                    "curatorActionCommission": "true"
                ])
            ),
            SurfacePage(
                type: .mood,
                sourceID: "test-mood",
                prompt: "Mood",
                detail: "One genuine Page."
            ),
            SurfacePage(
                type: .lore,
                sourceID: "test-lore",
                prompt: "Lore",
                detail: "Another genuine Page."
            ),
            SurfacePage(
                type: .quip,
                sourceID: "test-quip",
                prompt: "Quip",
                detail: "A spare genuine Page."
            )
        ]

        let merged = FirstRunPageSequence.mergingGuidedRider(rider, into: feed, limit: 3)

        XCTAssertEqual(merged.map(\.sourceID), [
            FirstRunPageSequence.compassRunIntroSourceID,
            "test-mood",
            "test-lore"
        ])
        XCTAssertEqual(merged.filter(FirstRunPageSequence.isFirstDoorGuidance).count, 1)
        XCTAssertEqual(merged.filter(\.isReaderActionCommission).count, 1)
    }

    func testDayZeroApprenticeshipDoesNotRepeatTheOnboardingSouvenirAsk() {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: now)

        let pages = FirstDoorApprenticeshipPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(pages.isEmpty)
    }

    func testDayZeroApprenticeshipStillOffersAFirstKeepWhenOnboardingHasNone() {
        let now = date(2026, 6, 1, hour: 13, calendar: utcCalendar)
        let day = BookDay(id: "2026-06-01", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: now).filter {
            $0.questionID != "onboarding-first-souvenir"
        }

        let pages = FirstDoorApprenticeshipPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(pages.first?.payload.metadata["firstDoorApprenticeshipDay"], "0")
        XCTAssertEqual(pages.first?.payload.metadata["curatorActionCommission"], "true")
    }

    func testFirstDoorApprenticeshipSurfacesOneDailyPageDuringFirstWeek() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let now = date(2026, 6, 3, hour: 10, calendar: calendar)
        let day = BookDay(id: "2026-06-03", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)

        let surface = FirstDoorApprenticeshipPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        ).first

        XCTAssertEqual(surface?.sourceID, "first-door-apprenticeship")
        XCTAssertEqual(surface?.type, .helpTips)
        XCTAssertEqual(surface?.payload.metadata["firstDoorApprenticeshipDay"], "2")
        XCTAssertEqual(surface?.varietyKey, "first-door-apprenticeship:2")
        XCTAssertTrue(surface?.payload.body.contains("Small strange things count.") == true)
    }

    func testFirstDoorApprenticeshipDoesNotRepeatSeenDay() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let now = date(2026, 6, 3, hour: 10, calendar: calendar)
        let day = BookDay(id: "2026-06-03", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)
        inputs.surfaceHistory = [
            "first-door-apprenticeship:2": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1)
        ]

        let surfaces = FirstDoorApprenticeshipPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(surfaces.isEmpty)
    }

    func testFirstDoorApprenticeshipStopsAfterFirstWeek() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let now = date(2026, 6, 8, hour: 10, calendar: calendar)
        let day = BookDay(id: "2026-06-08", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)

        let surfaces = FirstDoorApprenticeshipPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(surfaces.isEmpty)
    }

    private func fact(_ questionID: String, tags: [String]) -> SelfFact {
        SelfFact(
            id: questionID, questionID: questionID, question: "q", answer: "a",
            bookTranslation: "a", sensitivity: .delight, usePermission: .privateContext,
            tags: tags, createdAt: Date(), updatedAt: Date()
        )
    }

    private func firstDoorFacts(startedAt: Date) -> [SelfFact] {
        [
            firstDoorFact(
                "onboarding-name",
                answer: "Beej",
                tags: ["name", "identity", "onboarding"],
                startedAt: startedAt
            ),
            firstDoorFact(
                "onboarding-snack",
                answer: "peanut butter toast",
                tags: ["snack", "comfort", "onboarding"],
                startedAt: startedAt
            ),
            firstDoorFact(
                "onboarding-belief",
                answer: "Small strange things count.",
                tags: ["belief", "values", "onboarding"],
                startedAt: startedAt
            ),
            firstDoorFact(
                "onboarding-first-souvenir",
                answer: "The lamp made a small gold island on the desk.",
                tags: ["souvenir", "first-run-souvenir", "onboarding"],
                startedAt: startedAt
            )
        ]
    }

    private func firstDoorFact(_ questionID: String, answer: String, tags: [String], startedAt: Date) -> SelfFact {
        SelfFact(
            id: questionID,
            questionID: questionID,
            question: "q",
            answer: answer,
            bookTranslation: answer,
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: tags,
            createdAt: startedAt,
            updatedAt: startedAt
        )
    }

    private func bindingDay(_ day: Int, text: String) -> BookDay {
        let calendar = Calendar.current
        let dayDate = date(2026, 6, day, hour: 0, calendar: calendar)
        return BookDay(
            id: String(format: "2026-06-%02d", day),
            date: dayDate,
            pages: [
                BookPage(
                    id: "binding-\(day)-souvenir",
                    type: .souvenir,
                    createdAt: date(2026, 6, day, hour: 12, calendar: calendar),
                    promptText: "Keep one true thing.",
                    userInput: text,
                    tags: ["souvenir"]
                ),
                BookPage(
                    id: "binding-\(day)-diary",
                    type: .diary,
                    createdAt: date(2026, 6, day, hour: 18, calendar: calendar),
                    promptText: "What stayed with you?",
                    userInput: text + " It stayed with me when evening came.",
                    tags: ["diary"]
                )
            ]
        )
    }

    private func shownChapterPrimerHistory(now: Date) -> [String: SurfaceHistoryRecord] {
        Dictionary(
            uniqueKeysWithValues: (1...3).map { stage in
                (
                    "chapter-primer:\(stage)",
                    SurfaceHistoryRecord(lastShownAt: now.addingTimeInterval(TimeInterval(-stage * 3600)), recentShowCount: 1)
                )
            }
        )
    }

    // MARK: Save file

    func testSaveFileRoundTrips() throws {
        var readerLexicon = ReaderLexicon()
        readerLexicon.treaty = .reformation
        readerLexicon.bargainSeedSurfaced = true
        readerLexicon.upsert(LexiconEntry(
            word: "almost",
            originalSense: "not quite",
            newSense: "a door deciding",
            ruling: .adopted,
            category: .theme,
            origin: .rebellion,
            ledAt: Date(timeIntervalSinceReferenceDate: 31),
            sourcePageID: "word-page-almost"
        ))
        let openArchive = OpenWorldEventArchive(
            packID: "starlit-paper-trial-archive",
            eventID: "starlit-paper-trial",
            openedAt: Date(timeIntervalSinceReferenceDate: 32)
        )
        let save = ReEnchantedSaveFile(
            exportedAt: Date(),
            days: [BookDay.today()],
            selfFacts: [],
            narrativeEvents: [],
            entityMemories: [],
            facultyEntries: [],
            customCastMembers: [],
            anchors: [],
            compassKnownPlaces: [
                CompassKnownPlace(
                    id: "compass-place-library-1",
                    name: "Library",
                    contextID: CompassPlaceContext.library.rawValue,
                    latitude: 44.2,
                    longitude: -69.2,
                    radiusMeters: 180,
                    updatedAt: Date()
                )
            ],
            electives: [],
            beliefScore: 42,
            entityBeliefLedger: ["penny-blackletter": 3],
            pageBeliefLedger: ["inner-weather": -3],
            marginTutorSeen: ["glow-menu"],
            didCompleteStoryOnboarding: true,
            sourcePreferences: ["quip-page": false],
            readerLexicon: readerLexicon,
            openWorldEventArchive: openArchive
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReEnchantedSaveFile.self, from: encoder.encode(save))
        XCTAssertEqual(decoded.version, ReEnchantedSaveFile.currentVersion)
        XCTAssertEqual(decoded.beliefScore, 42)
        XCTAssertEqual(decoded.entityBeliefLedger["penny-blackletter"], 3)
        XCTAssertEqual(decoded.marginTutorSeen, ["glow-menu"])
        XCTAssertEqual(decoded.compassKnownPlaces?.first?.context, .library)
        XCTAssertEqual(decoded.days.count, 1)
        XCTAssertEqual(decoded.readerLexicon, readerLexicon)
        XCTAssertEqual(decoded.openWorldEventArchive, openArchive)
    }

    func testWordNegotiationDefinitionsDecodePackFriendlyDefaults() throws {
        let json = """
        {
          "id": "test-pack",
          "displayName": "Test Pack",
          "version": 1,
          "author": "Tests",
          "availability": "bundledFree",
          "archetypes": [],
          "wordNegotiations": [
            {
              "id": "almost-rebels",
              "word": "almost",
              "originalSense": "not quite",
              "grievance": "It is tired of standing outside the sentence.",
              "category": "theme",
              "choices": [
                {
                  "ruling": "adopted",
                  "title": "Adopt",
                  "detail": "Let almost mean a door deciding.",
                  "resultingSense": "a door deciding"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let pack = try JSONDecoder().decode(PageArchetypePack.self, from: json)
        let definition = try XCTUnwrap(pack.wordNegotiations?.first)

        XCTAssertEqual(definition.origin, .rebellion)
        XCTAssertEqual(definition.score, 76)
        XCTAssertEqual(definition.cadenceHours, 12)
        XCTAssertEqual(definition.symbolName, "textformat.abc.dottedunderline")
        XCTAssertEqual(definition.tags, [])
        XCTAssertFalse(definition.isMissingSeed)
        XCTAssertEqual(definition.stableWordID, "almost")
    }

    func testDefaultAnchorsShipEmpty() {
        XCTAssertTrue(AnchorRegistry.defaultAnchors.isEmpty, "Anchors are save data, never binary data")
    }

    func testAnchorPlaceReceiptRoundTripsAndCanVeilTheMapsName() throws {
        let identity = AnchorPlaceIdentity(
            name: "Bright Cup Cafe",
            category: "cafe",
            locality: "Portland",
            latitude: 43.65,
            longitude: -70.25,
            matchDistanceMeters: 14,
            usesRealNameInStory: false
        )
        let anchor = AnchorRecord(
            id: "bright-cup",
            name: "Bright Cup Cafe",
            latitude: 43.65,
            longitude: -70.25,
            radiusMeters: 200,
            kind: .sense,
            belief: 10,
            created: "2026-08-07",
            weather: "sunny",
            moon: "New Moon",
            season: "Summer",
            playerWords: "I come here when I need the day to begin again.",
            academyEcho: "A warm door argues with the bell.",
            outerStacksRoom: "Every cup is carrying an unfinished plan.",
            fae: "The Steam Clerk",
            miniStory: "The espresso machine has bitten the bell.",
            localRule: "Name the order precisely.",
            visitCount: 0,
            lastVisited: "none",
            place: identity,
            emotionalRegister: "warm, bustling, and competitive"
        )

        let decoded = try JSONDecoder().decode(AnchorRecord.self, from: JSONEncoder().encode(anchor))

        XCTAssertEqual(decoded, anchor)
        XCTAssertEqual(decoded.storyName, "this cafe Anchor")
        XCTAssertTrue(decoded.place?.promptLine.contains("real name veiled") == true)
        XCTAssertFalse(decoded.place?.promptLine.contains("Bright Cup") == true)
    }

    func testLegacyAnchorWithoutPlaceReceiptStillDecodes() throws {
        let legacy = """
        {
          "id":"porch","name":"Porch","latitude":40,"longitude":-73,
          "radiusMeters":200,"kind":"NOTICE","belief":7,"created":"2026-06-01",
          "weather":"rain","moon":"New Moon","season":"Summer",
          "playerWords":"The place with the good lamp.",
          "academyEcho":"A door smells faintly of rain.",
          "outerStacksRoom":"A small warm room.","fae":"The Lamp Minder",
          "miniStory":"The lamp moved.","localRule":"Name one color.",
          "visitCount":1,"lastVisited":"2026-06-10"
        }
        """

        let decoded = try JSONDecoder().decode(AnchorRecord.self, from: Data(legacy.utf8))

        XCTAssertNil(decoded.place)
        XCTAssertNil(decoded.emotionalRegister)
        XCTAssertEqual(decoded.storyName, "Porch")
    }

    func testAnchorCheckInUsesConservedRewardAmount() {
        let anchor = AnchorRecord(
            id: "porch",
            name: "Porch",
            latitude: 40,
            longitude: -73,
            radiusMeters: 200,
            kind: .notice,
            belief: 7,
            created: "2026-06-01",
            weather: "rain",
            moon: "New Moon",
            season: "Summer",
            playerWords: "The place with the good lamp.",
            academyEcho: "A door smells faintly of rain.",
            outerStacksRoom: "A small room of warm shelves and careful dust.",
            fae: "A parchment-masked Fae",
            miniStory: "A map has shifted on the low table.",
            localRule: "Offer quiet before touching the shelves.",
            visitCount: 1,
            lastVisited: "2026-06-10"
        )

        XCTAssertEqual(AnchorRegistry.checkInBeliefReward, 2)
        let checkedIn = anchor.checkedIn(on: date(2026, 6, 12, hour: 12, calendar: utcCalendar), beliefGiven: 2)
        XCTAssertEqual(checkedIn.belief, 9)
        XCTAssertEqual(checkedIn.visitCount, 2)
        XCTAssertEqual(checkedIn.lastVisited, "2026-06-12")

        let dimVisit = anchor.checkedIn(on: date(2026, 6, 13, hour: 12, calendar: utcCalendar), beliefGiven: 0)
        XCTAssertEqual(dimVisit.belief, 7)
        XCTAssertEqual(dimVisit.visitCount, 2)
    }

    func testAnchorTurnBuilderCreatesPlaceNativeTurn() {
        let anchor = AnchorRecord(
            id: "home",
            name: "Home",
            latitude: 40,
            longitude: -73,
            radiusMeters: 200,
            kind: .notice,
            belief: 7,
            created: "2026-06-01",
            weather: "rain",
            moon: "New Moon",
            season: "Summer",
            playerWords: "The place with the good lamp.",
            academyEcho: "A door smells faintly of rain.",
            outerStacksRoom: "A small room of warm shelves and careful dust.",
            fae: "A parchment-masked Fae",
            miniStory: "A map has shifted on the low table.",
            localRule: "Offer quiet before touching the shelves.",
            visitCount: 3,
            lastVisited: "2026-06-10"
        )

        let firstTurn = AnchorTurnBuilder.turn(anchor: anchor, visitMode: "FIRST_VISIT", slotKey: "first")
        XCTAssertEqual(firstTurn.register, .quiet)
        XCTAssertFalse(firstTurn.want.isEmpty)
        XCTAssertFalse(firstTurn.statement.isEmpty)
        XCTAssertFalse(firstTurn.character.isEmpty)

        let returnTurn = AnchorTurnBuilder.turn(anchor: anchor, visitMode: "RETURN_VISIT", slotKey: "return")
        XCTAssertEqual(returnTurn.register, .quiet)
        XCTAssertTrue(returnTurn.want.contains("visit 3"))
        let landings = ["slice-of-life", "progress-arc", "surprise"].compactMap { returnTurn.landings[$0]?.nonEmpty }
        XCTAssertEqual(landings.count, 3)
        XCTAssertEqual(Set(landings).count, 3)
    }

    func testAnchorMiniStoryAdvancesAsRollingGist() {
        let previous = "A map has shifted on the low table. The dust remembered a name."
        let landing = "The room trusts the reader with one more exact, kept detail; the bond warms a notch."

        let advanced = AnchorMiniStory.advanced(previous: previous, landing: landing)

        XCTAssertTrue(advanced.contains(landing))
        XCTAssertTrue(advanced.contains("Before that"))
        XCTAssertTrue(advanced.contains("A map has shifted on the low table."))
        XCTAssertLessThanOrEqual(advanced.count, AnchorMiniStory.maxLength)

        let metadata = [
            "storyTurnLandingProgressArc": "The Fae reveals the next guarded piece.",
            "storyTurnStatement": "The room changes."
        ]
        XCTAssertEqual(
            AnchorMiniStory.landing(from: metadata, tags: ["anchor", "choice:progressarc"]),
            "The Fae reveals the next guarded piece."
        )
    }

    func testAnchorVisitSurfaceCarriesStoryPageChoices() {
        let now = date(2026, 6, 12, hour: 12, calendar: utcCalendar)
        let anchor = AnchorRecord(
            id: "home",
            name: "Home",
            latitude: 40,
            longitude: -73,
            radiusMeters: 200,
            kind: .notice,
            belief: 7,
            created: "2026-06-01",
            weather: "rain",
            moon: "New Moon",
            season: "Summer",
            playerWords: "The place with the good lamp.",
            academyEcho: "A door smells faintly of rain.",
            outerStacksRoom: "A small room of warm shelves and careful dust.",
            fae: "A parchment-masked Fae",
            miniStory: "A map has shifted on the low table.",
            localRule: "Offer quiet before touching the shelves.",
            visitCount: 1,
            lastVisited: "2026-06-10"
        )
        var inputs = BookSourceInputs.empty
        inputs.nearbyAnchor = AnchorProximity(anchor: anchor, distanceMeters: 12)
        let day = BookDay(id: "today", date: now, pages: [])

        let surface = OuterStacksAnchorPageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(surface.isStoryPlayablePage)
        XCTAssertEqual(surface.payload.metadata["storyChoiceSliceOfLifeTitle"], "Honor the Rule")
        XCTAssertEqual(surface.payload.metadata["storyChoiceProgressArcTitle"], "Approach the Fae")
        XCTAssertEqual(surface.payload.metadata["storyChoiceSurpriseTitle"], "Test the Threshold")
        XCTAssertEqual(surface.payload.metadata["storyChoiceSliceOfLifeMechanic"], "none")
        XCTAssertEqual(surface.payload.metadata["beliefReward"], "2")
        XCTAssertFalse(surface.payload.metadata["storyTurnStatement"]?.isEmpty ?? true)
        XCTAssertFalse(surface.payload.metadata["storyTurnLandingSliceOfLife"]?.isEmpty ?? true)
        XCTAssertFalse(surface.payload.metadata["storyTurnLandingProgressArc"]?.isEmpty ?? true)
        XCTAssertFalse(surface.payload.metadata["storyTurnLandingSurprise"]?.isEmpty ?? true)
        guard let scene = surface.payload.metadata["storyScene"]?.nonEmpty else {
            XCTFail("Anchor visits should carry playable story prose.")
            return
        }
        XCTAssertFalse(scene.contains("Room:"))
        XCTAssertFalse(scene.contains("Fae:"))
        XCTAssertFalse(scene.contains("Local rule:"))
        XCTAssertFalse(scene.contains("Mini-story:"))
        XCTAssertFalse(surface.payload.body.contains("Room:"))
        XCTAssertTrue(scene.contains("A small room of warm shelves and careful dust."))
    }

    func testAnchorVisitSurfaceCarriesPlaceReceiptAndItsOwnEmotionalRegister() throws {
        let now = date(2026, 8, 7, hour: 12, calendar: utcCalendar)
        let place = AnchorPlaceIdentity(
            name: "Sunward Preserve",
            category: "nature preserve",
            locality: "Freeport",
            latitude: 43.8,
            longitude: -70.1,
            matchDistanceMeters: 9,
            usesRealNameInStory: true
        )
        let anchor = AnchorRecord(
            id: "sunward-preserve",
            name: "Sunward Preserve",
            latitude: 43.8,
            longitude: -70.1,
            radiusMeters: 200,
            kind: .notice,
            belief: 10,
            created: "2026-08-07",
            weather: "clear",
            moon: "New Moon",
            season: "Summer",
            playerWords: "The pines make the traffic let go of me.",
            academyEcho: "A green door keeps changing its trail marks.",
            outerStacksRoom: "Live paths cross an open map-room under green light.",
            fae: "The Boundary Gardener",
            miniStory: "A trail marker has chosen a new direction.",
            localRule: "Let one living thing finish before you pass.",
            visitCount: 0,
            lastVisited: "none",
            place: place,
            emotionalRegister: "open, green, alert, and seasonal"
        )
        var inputs = BookSourceInputs.empty
        inputs.nearbyAnchor = AnchorProximity(anchor: anchor, distanceMeters: 5)

        let surface = OuterStacksAnchorPageSourceAdapter().manualSurface(
            for: BookDay(id: "today", date: now, pages: []),
            context: CuratorContext.make(for: BookDay(id: "today", date: now, pages: [])),
            inputs: inputs,
            now: now
        )
        let scene = try XCTUnwrap(surface.payload.metadata["storyScene"])

        XCTAssertEqual(surface.payload.metadata["anchorEmotionalRegister"], "open, green, alert, and seasonal")
        XCTAssertTrue(surface.payload.metadata["anchorPlaceReceipt"]?.contains("Sunward Preserve") == true)
        XCTAssertTrue(scene.contains("open, green, alert, and seasonal"))
        XCTAssertFalse(scene.lowercased().contains("dark seems to be keeping count"))
        XCTAssertFalse(scene.lowercased().contains("open in the dust"))
    }

    func testWonderCompassRunSurfaceCarriesNearbyAnchorFlavor() {
        let now = date(2026, 6, 12, hour: 12, calendar: utcCalendar)
        let anchor = AnchorRecord(
            id: "harbor-lamp",
            name: "Harbor Lamp",
            latitude: 44,
            longitude: -69,
            radiusMeters: 200,
            kind: .sense,
            belief: 5,
            created: "2026-06-01",
            weather: "mist",
            moon: "Waxing Moon",
            season: "Gold Season",
            playerWords: "Salt air and yellow glass.",
            academyEcho: "A brass bell waits in fog.",
            outerStacksRoom: "A narrow room of green rope and lantern light.",
            fae: "The Lantern Clerk",
            miniStory: "The tide has moved one shelf higher.",
            localRule: "Count three reflected lights before asking.",
            visitCount: 2,
            lastVisited: "2026-06-10"
        )
        var inputs = BookSourceInputs.empty
        inputs.nearbyAnchor = AnchorProximity(anchor: anchor, distanceMeters: 18)
        let day = BookDay(id: "today", date: now, pages: [])

        let surface = WonderCompassPageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(surface.payload.metadata["anchorName"], "Harbor Lamp")
        XCTAssertEqual(surface.payload.metadata["anchorKind"], "Sense")
        XCTAssertEqual(surface.payload.metadata["anchorDistanceMeters"], "18")
        XCTAssertEqual(surface.payload.metadata["anchorRoom"], "A narrow room of green rope and lantern light.")
        XCTAssertEqual(surface.payload.metadata["anchorFae"], "The Lantern Clerk")
        XCTAssertEqual(surface.payload.metadata["anchorLocalRule"], "Count three reflected lights before asking.")
        XCTAssertEqual(surface.payload.metadata["anchorVisitMode"], "RETURN_VISIT")
    }

    // MARK: Margins Atlas

    func testMarginsAtlasLayoutIsDeterministicAndBounded() {
        let graph = NarrativeGraphData.loom(
            entities: NarrativePackRegistry.entities,
            relationships: NarrativePackRegistry.relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: [:]
        )

        let first = GraphLayoutEngine.layout(data: graph, width: 320, height: 390, seed: "test-atlas")
        let second = GraphLayoutEngine.layout(data: graph, width: 320, height: 390, seed: "test-atlas")

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
        for point in first.values {
            XCTAssertGreaterThanOrEqual(point.x, 40)
            XCTAssertLessThanOrEqual(point.x, 280)
            XCTAssertGreaterThanOrEqual(point.y, 40)
            XCTAssertLessThanOrEqual(point.y, 350)
        }
    }

    func testMarginsAtlasAdapterBuildsConstellationFromBeliefLedgerEvents() {
        var inputs = BookSourceInputs.empty
        inputs.recentNarrativeEvents = [
            NarrativeEvent(
                id: "belief-penny",
                kind: .beliefInvested,
                sourcePageType: nil,
                sourcePageID: nil,
                createdAt: Date(),
                summary: "The reader gave Penny Belief.",
                tags: ["belief"],
                effect: NarrativeEventEffect(entityWeightDeltas: ["penny-blackletter": 3])
            )
        ]
        inputs.narrative = NarrativeSourceSnapshotBuilder.snapshot(from: inputs.recentNarrativeEvents, beliefWeight: 40)

        let pages = MarginsAtlasPageSourceAdapter().candidates(
            for: BookDay.today(),
            context: CuratorContext.make(for: BookDay.today()),
            inputs: inputs,
            now: Date()
        )
        let constellation = pages.first { $0.payload.metadata["graphVariant"] == MarginsAtlasVariant.constellation.rawValue }

        XCTAssertNotNil(constellation)
        XCTAssertTrue(constellation?.payload.metadata["graphNodes"]?.contains("the-reader") == true)
        XCTAssertTrue(constellation?.payload.metadata["graphEdges"]?.contains("flow-penny-blackletter") == true)
    }

    // MARK: Electives

    func testElectiveOfferRespectsFiveActiveCap() {
        let adapter = ElectivePageSourceAdapter()
        var inputs = BookSourceInputs.empty
        var calendar = utcCalendar
        calendar.timeZone = TimeZone.current
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date().addingTimeInterval(-86_400))!
        inputs.electives = (0..<5).map { index in
            UnwrittenElective(
                id: "e\(index)",
                characterID: "char-\(index)",
                characterName: "Character \(index)",
                title: "Favor \(index)",
                ask: "Do the thing",
                whyItMatters: "It matters",
                practiceShape: "One sentence",
                createdAt: noon.addingTimeInterval(Double(index) * -3600)
            )
        }
        let day = BookDay.today()
        let pages = adapter.candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        )
        XCTAssertFalse(pages.contains { $0.payload.metadata["electiveOffer"] == "true" })
        XCTAssertTrue(pages.contains { $0.payload.metadata["electiveFlyleaf"] == "true" })
    }

    func testNamedFlyleafDoorAlwaysOpensQuestLedger() {
        let surface = ElectivePageSourceAdapter().flyleafSurface(
            for: BookDay.today(),
            inputs: .empty,
            now: Date()
        )

        XCTAssertEqual(surface.prompt, "The Flyleaf")
        XCTAssertEqual(surface.payload.metadata["electiveFlyleaf"], "true")
        XCTAssertNil(surface.payload.metadata["electiveOffer"])
        XCTAssertEqual(surface.payload.metadata["activeCount"], "0")
    }

    func testFlyleafIsPinnedFirstInGlowPagesMenu() {
        XCTAssertEqual(GlowPagesMenuLayout.orderedSections.first, .flyleaf)
        XCTAssertEqual(
            GlowPagesMenuLayout.orderedSections.filter { $0 == .flyleaf }.count,
            1
        )
    }

    func testFlyleafLedgerAggregatesCanonicalOpenThreadsWithoutRevivingReleasedNotes() {
        let now = Date()
        var day = BookDay.day(containing: now)
        day.pages.append(
            BookPage(
                id: "compass-notice",
                type: .wonderCompass,
                createdAt: now,
                promptText: "North = Notice",
                userInput: "Where does the alley light go?",
                tags: [
                    "wonder-compass-run",
                    "compass-step:notice",
                    "compass-run:run-one"
                ]
            )
        )

        let characterQuest = UnwrittenElective(
            id: "character-quest",
            characterID: "penny-blackletter",
            characterName: "Penny Blackletter",
            title: "Bring Back a Wrong Turn",
            ask: "Take one harmless wrong turn and notice what is there.",
            whyItMatters: "Penny suspects the map is showing off.",
            practiceShape: "One exact sentence.",
            createdAt: now.addingTimeInterval(-600)
        )
        let bookFavor = UnwrittenElective(
            id: "book-favor",
            characterID: "the-book",
            characterName: "The Book",
            title: "The Unanswered Object",
            ask: "Find an ordinary object with one honest mystery.",
            whyItMatters: "Mystery makes the ordinary world larger.",
            practiceShape: "One fact and one unanswered question.",
            createdAt: now.addingTimeInterval(-500),
            bookFavorID: "favor-one"
        )
        var releasedQuest = UnwrittenElective(
            id: "released-quest",
            characterID: "wicker",
            characterName: "Wicker",
            title: "A Resting Dare",
            ask: "This one has already been put down.",
            whyItMatters: "",
            practiceShape: "Nothing.",
            createdAt: now.addingTimeInterval(-400)
        )
        releasedQuest.releasedAt = now.addingTimeInterval(-60)

        var inputs = BookSourceInputs.empty
        inputs.electives = [releasedQuest, bookFavor, characterQuest]
        let work = BookJumpEngine.publicDomainShelf[0]
        inputs.bookJump = BookJumpState(
            active: activeJumpFixture(work: work, depth: 2, degradation: 0, now: now)
        )

        var fae = FaePlayerState()
        fae.bargains = [
            FaeBargain(
                id: "fae-open",
                faeKind: .goblin,
                slot: "test",
                giftID: "gift-one",
                giftName: "The Green Thread",
                giftEffectLine: "It remembers one loose edge.",
                openingGesture: "A thread is laid across the page.",
                terms: "Notice one repair that is still holding.",
                offeredAt: now.addingTimeInterval(-300),
                deadline: now.addingTimeInterval(3_600),
                status: .owed,
                fieldReport: nil,
                faeResponse: nil,
                rewardText: nil,
                deliveredAt: nil
            )
        ]
        inputs.faeState = fae

        var pact = PactWarState()
        pact.errands = [
            PactErrand(
                id: "pact-open",
                talismanID: "ember-seal",
                territoryID: "shelf-story",
                openingLine: "The Ember Seal has found a loose border.",
                terms: "Bring back one true change in a familiar place.",
                offeredAt: now.addingTimeInterval(-200),
                deadline: now.addingTimeInterval(7_200),
                status: .owed,
                fieldReport: nil,
                talismanResponse: nil,
                deliveredAt: nil
            )
        ]
        inputs.pactWar = pact

        let ledger = FlyleafLedger(day: day, inputs: inputs, now: now)

        XCTAssertEqual(ledger.electives.map(\.id), ["character-quest", "book-favor"])
        XCTAssertEqual(ledger.characterQuestCount, 1)
        XCTAssertEqual(ledger.bookFavorCount, 1)
        XCTAssertEqual(
            ledger.doors.map(\.kind),
            [.bookJump, .compassRun, .faeBargain, .pactErrand]
        )
        XCTAssertEqual(ledger.openThreadCount, 6)

        let surface = ElectivePageSourceAdapter().flyleafSurface(
            for: day,
            inputs: inputs,
            now: now
        )
        XCTAssertEqual(surface.payload.metadata["activeCount"], "6")
        XCTAssertEqual(surface.payload.metadata["activeElectiveCount"], "2")
        XCTAssertEqual(surface.payload.metadata["bookFavorCount"], "1")
        XCTAssertEqual(surface.payload.metadata["doorCount"], "4")
        XCTAssertEqual(
            surface.payload.metadata["doorKinds"],
            "bookJump,compassRun,faeBargain,pactErrand"
        )
    }

    func testElectiveReleaseFreesItsSlotWithoutBecomingCompletionProof() throws {
        let elective = UnwrittenElective(
            id: "legacy-note",
            characterID: "wicker",
            characterName: "Wicker",
            title: "A Small Dare",
            ask: "Notice one bent rule.",
            whyItMatters: "Wicker is curious.",
            practiceShape: "One sentence.",
            createdAt: Date()
        )

        // A pre-release-model payload has no releasedAt key and must still
        // decode as the active note it always was.
        let legacyData = try JSONEncoder().encode(elective)
        let decoded = try JSONDecoder().decode(UnwrittenElective.self, from: legacyData)
        XCTAssertTrue(decoded.isActive)
        XCTAssertNil(decoded.releasedAt)

        var released = decoded
        released.releasedAt = Date()
        XCTAssertFalse(released.isActive)
        XCTAssertTrue(released.isReleased)
        XCTAssertNil(released.completedAt)
        XCTAssertNil(released.proof)
    }

    // MARK: Literary continuity

    func testLiteraryContinuityFindsRepeatedPatternAndAbsence() {
        let calendar = utcCalendar
        let now = date(2026, 6, 12, hour: 12, calendar: calendar)
        let oldOne = BookPage(
            id: "old-harbor-1",
            type: .souvenir,
            createdAt: date(2026, 3, 1, hour: 9, calendar: calendar),
            promptText: "Souvenir",
            userInput: "The harbor kept its minutes.",
            tags: ["harbor", "water"]
        )
        let oldTwo = BookPage(
            id: "old-harbor-2",
            type: .diary,
            createdAt: date(2026, 3, 8, hour: 9, calendar: calendar),
            promptText: "Diary",
            userInput: "I walked near the harbor again.",
            tags: ["harbor"]
        )
        let oldThree = BookPage(
            id: "old-harbor-3",
            type: .weather,
            createdAt: date(2026, 3, 15, hour: 9, calendar: calendar),
            promptText: "Weather",
            userInput: "Fog over the harbor.",
            tags: ["harbor", "fog"]
        )
        let recent = BookPage(
            id: "recent-porch",
            type: .souvenir,
            createdAt: date(2026, 6, 10, hour: 9, calendar: calendar),
            promptText: "Souvenir",
            userInput: "The porch light stayed warm.",
            tags: ["porch"]
        )
        let digest = LiteraryContinuityProjector.digest(
            days: [BookDay(id: "d1", date: date(2026, 6, 12, hour: 0, calendar: calendar), pages: [oldOne, oldTwo, oldThree, recent])],
            events: [],
            entityMemories: [],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(digest.signals.contains { $0.kind == .pattern && $0.subjectID == "harbor" })
        XCTAssertTrue(digest.signals.contains { $0.kind == .absence && $0.subjectID == "harbor" })
    }

    func testBookNoticesPageSurfacesContinuitySignals() {
        let calendar = utcCalendar
        let now = date(2026, 6, 12, hour: 12, calendar: calendar)
        var inputs = BookSourceInputs.empty.withMatureLibrary(now: now, calendar: calendar)
        inputs.continuity = LiteraryContinuityDigest(
            signals: [
                LiteraryContinuitySignal(
                    id: "pattern-water",
                    kind: .pattern,
                    subjectID: "water",
                    subjectName: "Water",
                    line: "Water has gathered across four kept pages.",
                    evidencePageIDs: ["a", "b", "c"],
                    relatedEntityIDs: [],
                    tags: ["water", "pattern"],
                    firstSeenAt: date(2026, 5, 1, hour: 9, calendar: calendar),
                    lastSeenAt: now,
                    strength: 78
                ),
                LiteraryContinuitySignal(
                    id: "duration-book",
                    kind: .duration,
                    subjectID: "book",
                    subjectName: "The Book",
                    line: "The oldest kept page has been in the Book for 42 days.",
                    evidencePageIDs: ["a"],
                    relatedEntityIDs: [],
                    tags: ["duration"],
                    firstSeenAt: date(2026, 5, 1, hour: 9, calendar: calendar),
                    lastSeenAt: now,
                    strength: 70
                )
            ],
            beliefLifecycles: []
        )

        let day = BookDay(id: "today", date: date(2026, 6, 12, hour: 0, calendar: calendar), pages: [])
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(surfaces.first?.type, .bookNotices)
        // The body names the subject once; the observation line itself lives in
        // the "What I found" card, not restated a second time in prose.
        XCTAssertTrue(surfaces.first?.payload.body.contains("Water") == true)
        XCTAssertFalse(surfaces.first?.payload.body.contains("Water has gathered") == true)
        XCTAssertTrue(surfaces.first?.payload.metadata["tinyPatternCards"]?.contains("Water has gathered") == true)
        XCTAssertTrue(surfaces.first?.payload.metadata["continuitySignals"]?.contains("oldest kept page") == true)
        XCTAssertEqual(surfaces.first?.payload.metadata["source"], "the-book-notices")
    }

    func testBookJumpShelfUsesPublicDomainProfiles() {
        XCTAssertGreaterThanOrEqual(BookJumpEngine.publicDomainShelf.count, 8)
        XCTAssertTrue(BookJumpEngine.publicDomainShelf.allSatisfy { !$0.gutenbergID.isEmpty })
        XCTAssertTrue(BookJumpEngine.publicDomainShelf.allSatisfy { $0.gutenbergURL.hasPrefix("https://www.gutenberg.org/ebooks/") })
        XCTAssertFalse(BookJumpEngine.publicDomainShelf.contains { $0.title.lowercased().contains("enchantify") })
    }

    func testBookJumpStateAdvancesAndReturnsWithSouvenir() {
        let calendar = utcCalendar
        let now = date(2026, 6, 12, hour: 20, calendar: calendar)
        let day = BookDay(id: "today", date: now, pages: [
            BookPage(type: .souvenir, promptText: "Souvenir", userInput: "Fog on the window.", tags: ["fog"])
        ])
        let start = BookJumpEngine.surface(
            for: BookJumpState(),
            day: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now,
            manual: true
        )

        var state = BookJumpEngine.start(from: start, now: now)
        XCTAssertEqual(state.active?.depth, 1)
        XCTAssertEqual(state.active?.title, start.payload.metadata["bookTitle"])

        state = BookJumpEngine.advance(state, line: "The page turned.", now: now.addingTimeInterval(60))
        XCTAssertEqual(state.active?.depth, 2)
        XCTAssertEqual(state.active?.souvenirDue, true)

        state = BookJumpEngine.return(state, souvenir: "The fog knew the way home.", outcome: "Found the Spine.", now: now.addingTimeInterval(120))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.returned.first?.souvenir, "The fog knew the way home.")
    }

    func testShelfSelectedBookJumpStartPreservesTheExistingJumpLedger() {
        let now = date(2026, 6, 12, hour: 20, calendar: utcCalendar)
        let priorReturn = ReturnedBookJump(
            id: "prior-return",
            bookID: "wizard-oz",
            title: "The Wonderful Wizard of Oz",
            author: "L. Frank Baum",
            returnedAt: now.addingTimeInterval(-86_400),
            depth: 2,
            degradation: 0,
            souvenir: "The road was brightest at the worn stones.",
            outcome: "Home by the Spine."
        )
        let borrowed = BorrowedRule(
            id: "prior-rule",
            bookID: "wizard-oz",
            bookTitle: "The Wonderful Wizard of Oz",
            text: "Friendship is a road-making tool.",
            effect: .warmTheCast,
            grantedAt: now.addingTimeInterval(-3_600),
            expiresAt: now.addingTimeInterval(3 * 86_400)
        )
        let reopenDate = now.addingTimeInterval(2 * 86_400)
        let existing = BookJumpState(
            returned: [priorReturn],
            borrowedRules: [borrowed],
            coldBooks: ["sherlock-holmes": reopenDate]
        )
        let day = BookDay(id: "today", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.bookJump = existing
        let surface = BookJumpEngine.surface(
            for: existing,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now,
            manual: true
        )

        let started = BookJumpEngine.start(from: surface, into: existing, now: now)

        XCTAssertNotNil(started.active)
        XCTAssertEqual(started.returned, existing.returned)
        XCTAssertEqual(started.borrowedRules, existing.borrowedRules)
        XCTAssertEqual(started.coldBooks, existing.coldBooks)
    }

    private func activeJumpFixture(
        work: BookJumpWork,
        depth: Int,
        degradation: Int,
        now: Date
    ) -> ActiveBookJump {
        ActiveBookJump(
            id: "jump-test",
            bookID: work.id,
            title: work.title,
            author: work.author,
            gutenbergID: work.gutenbergID,
            world: work.world,
            arrival: work.arrival,
            nothing: work.nothing,
            rules: work.rules,
            resonances: work.resonances,
            anchor: "fog on the window",
            intention: "bring back one sentence",
            guide: "the Book",
            startedAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-60),
            depth: depth,
            returnCount: 0,
            degradation: degradation,
            souvenirDue: depth >= 2,
            beats: []
        )
    }

    func testBookJumpProgressionForcesStabilizeAndReturn() {
        let now = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let work = BookJumpEngine.publicDomainShelf[0]
        let day = BookDay(id: "today", date: now, pages: [])

        // High Nothing pressure forces a stabilize beat.
        var inputs = BookSourceInputs.empty
        inputs.bookJump = BookJumpState(active: activeJumpFixture(work: work, depth: 3, degradation: 3, now: now))
        let unstable = BookJumpPageSourceAdapter().candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).first
        XCTAssertEqual(unstable?.payload.metadata["bookJumpAction"], "stabilize")

        // At max depth, the book offers the way home.
        inputs.bookJump = BookJumpState(active: activeJumpFixture(work: work, depth: BookJumpEngine.maxDepth, degradation: 0, now: now))
        let deepest = BookJumpPageSourceAdapter().candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).first
        XCTAssertEqual(deepest?.payload.metadata["bookJumpAction"], "return")
    }

    func testBookJumpReturnGrantsBorrowedRuleOnlyWithSouvenir() {
        let now = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let work = BookJumpEngine.work(id: "sherlock-holmes") ?? BookJumpEngine.publicDomainShelf[0]
        let state = BookJumpState(active: activeJumpFixture(work: work, depth: 2, degradation: 1, now: now))

        let empty = BookJumpEngine.return(state, souvenir: "   ", outcome: "back", now: now)
        XCTAssertTrue(empty.borrowedRules.isEmpty, "no souvenir, no rule")

        let granted = BookJumpEngine.return(state, souvenir: "The smallest detail was loudest.", outcome: "back", now: now)
        XCTAssertEqual(granted.borrowedRules.count, 1)
        XCTAssertEqual(granted.borrowedRules.first?.bookID, work.id)
        XCTAssertTrue(granted.borrowedRules.first?.isActive(at: now) ?? false)
        // Sherlock's attention resonances sharpen the reader's notice.
        XCTAssertEqual(granted.borrowedRules.first?.effect, .sharpenNotices)
        XCTAssertFalse(BookJumpEngine.surfaceBoosts(state: granted, now: now).isEmpty)
    }

    func testExplicitBookJumpCollapseCanStillCarryChoiceDrivenStakes() {
        let now = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let work = BookJumpEngine.publicDomainShelf[0]
        let state = BookJumpState(active: activeJumpFixture(work: work, depth: 3, degradation: 2, now: now))
        let result = BookJumpEngine.collapse(state, now: now)
        XCTAssertNil(result.state.active)
        XCTAssertGreaterThan(result.lostBelief, 0)
        XCTAssertTrue(result.state.isCold(work.id, at: now))
        XCTAssertEqual(result.state.returned.first?.souvenir, "")
    }

    func testTimeAwayLeavesAnActiveBookJumpExactlyWhereTheReaderLeftIt() {
        let start = date(2026, 6, 10, hour: 21, calendar: utcCalendar)
        let later = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let work = BookJumpEngine.publicDomainShelf[0]
        let state = BookJumpState(active: activeJumpFixture(work: work, depth: 3, degradation: 4, now: start))
        let result = BookJumpEngine.dailyDecay(state, now: later)
        XCTAssertFalse(result.collapsed)
        XCTAssertEqual(result.lostBelief, 0)
        XCTAssertEqual(result.state.active, state.active)
        XCTAssertFalse(result.state.isCold(work.id, at: later))
    }

    func testBookJumpColdBooksAreNotSelected() {
        let now = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let day = BookDay(id: "today", date: now, pages: [
            BookPage(type: .souvenir, promptText: "S", userInput: "curiosity and play and small adventures")
        ])
        var inputs = BookSourceInputs.empty
        // Make Alice cold; selection must pick a different open book.
        var jump = BookJumpState()
        jump.coldBooks["alice-wonderland"] = now.addingTimeInterval(3 * 86_400)
        inputs.bookJump = jump
        let picked = BookJumpEngine.selectWork(day: day, inputs: inputs, now: now)
        XCTAssertNotEqual(picked.id, "alice-wonderland")
    }

    func testBookJumpAdvanceCostEscalatesWithDepth() {
        XCTAssertEqual(BookJumpEngine.advanceCost(depth: 1), 1)
        XCTAssertEqual(BookJumpEngine.advanceCost(depth: 3), 2)
        XCTAssertEqual(BookJumpEngine.returnReward(depth: 1, hasSouvenir: true), BookJumpEngine.returnReward)
        XCTAssertGreaterThan(BookJumpEngine.returnReward(depth: 4, hasSouvenir: true), BookJumpEngine.returnReward)
        XCTAssertEqual(BookJumpEngine.returnReward(depth: 4, hasSouvenir: false), 0)
        XCTAssertLessThan(
            BookJumpEngine.returnReward(depth: BookJumpEngine.maxDepth, hasSouvenir: true),
            BeliefEconomyPolicy.compassRunReward
        )
    }

    func testBookJumpCompanionConstellationFormsOnRepeatVisits() {
        let now = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        func returned(_ bookID: String, _ title: String) -> ReturnedBookJump {
            ReturnedBookJump(id: "r-\(bookID)-\(title)", bookID: bookID, title: title, author: "a", returnedAt: now, depth: 2, degradation: 0, souvenir: "a kept sentence", outcome: "back")
        }
        // One visit: no constellation yet.
        XCTAssertNil(BookJumpEngine.companionLine(state: BookJumpState(returned: [returned("wizard-oz", "Oz")])))
        // Two returns to the same book: a bond names itself.
        let repeated = BookJumpState(returned: [returned("wizard-oz", "Oz"), returned("wizard-oz", "Oz")])
        XCTAssertTrue(BookJumpEngine.companionLine(state: repeated)?.contains("Oz") ?? false)
    }

    func testBookJumpOpenShelfImprovisesADoor() {
        let work = BookJumpEngine.improvisedWork(title: "The Voyage of the Dawn Treader", author: "C. S. Lewis", gutenbergID: "")
        XCTAssertNotNil(work)
        XCTAssertEqual(work?.resonances.contains("water"), true)
        let state = BookJumpEngine.startCustom(work: work!, anchor: "", intention: "", guide: "", into: BookJumpState())
        XCTAssertEqual(state.active?.title, "The Voyage of the Dawn Treader")
        XCTAssertEqual(state.active?.depth, 1)
    }

    // MARK: Radio held-station effects

    private func heldRadio(stationID: String, days: Int, calendar: Calendar) -> RadioPlaybackState {
        var state = RadioPlaybackState(activeStationID: stationID)
        for day in 1...days {
            state.recordListening(stationID: stationID, now: date(2026, 6, day, hour: 12, calendar: calendar), calendar: calendar)
        }
        return state
    }

    func testHeldStationRequiresEnoughDaysAndBeingTuned() {
        let cal = utcCalendar
        XCTAssertNil(RadioStationRegistry.heldStationID(state: heldRadio(stationID: "thornwave", days: 3, calendar: cal)))
        XCTAssertEqual(RadioStationRegistry.heldStationID(state: heldRadio(stationID: "thornwave", days: 4, calendar: cal)), "thornwave")

        // Heard enough, but no longer the tuned station → no held effect.
        var untuned = heldRadio(stationID: "thornwave", days: 4, calendar: cal)
        untuned.activeStationID = nil
        XCTAssertNil(RadioStationRegistry.heldStationID(state: untuned))
    }

    func testHeldThornwavePullsGreyNearerAndFaeFiPushesItBack() {
        let cal = utcCalendar
        XCTAssertEqual(RadioStationRegistry.greyShift(state: heldRadio(stationID: "thornwave", days: 4, calendar: cal)), 1)
        XCTAssertEqual(RadioStationRegistry.greyShift(state: heldRadio(stationID: "fae-fi", days: 4, calendar: cal)), -1)
        XCTAssertEqual(RadioStationRegistry.greyShift(state: heldRadio(stationID: "thornwave", days: 2, calendar: cal)), 0)
        XCTAssertEqual(RadioStationRegistry.greyShift(state: .off), 0)
    }

    func testHeldMothlightDeepensRemembering() {
        let cal = utcCalendar
        XCTAssertEqual(RadioStationRegistry.heldSurfaceBoosts(state: heldRadio(stationID: "mothlight-beats", days: 4, calendar: cal)), [.bookRemembered: 8])
        XCTAssertTrue(RadioStationRegistry.heldSurfaceBoosts(state: heldRadio(stationID: "mothlight-beats", days: 3, calendar: cal)).isEmpty)
        XCTAssertTrue(RadioStationRegistry.heldSurfaceBoosts(state: heldRadio(stationID: "thornwave", days: 4, calendar: cal)).isEmpty)
    }

    func testEveryScheduledSessionHasItsOwnInteractiveAcademyActivity() {
        let sessions = Array(AcademyScheduleRegistry.classes.values) + AcademyScheduleRegistry.clubs.values
        var activityIDs = Set<String>()
        var activityKinds = Set<AcademyActivity.Kind>()

        for session in sessions {
            let activity = AcademyActivityRegistry.activity(for: session.id)
            XCTAssertNotNil(activity, "missing Academy activity for \(session.id)")
            XCTAssertEqual(activity?.sessionID, session.id)
            XCTAssertFalse(activity?.title.isEmpty ?? true)
            XCTAssertFalse(activity?.invitation.isEmpty ?? true)
            XCTAssertTrue(activityIDs.insert(activity?.id ?? "").inserted, "activities should not be reskins")
            XCTAssertTrue(activityKinds.insert(activity?.kind ?? .evidenceLog).inserted, "each session needs a distinct practice shape")
        }
    }

    func testCompassRunningUsesTheFullCompassRunActivity() throws {
        let activity = try XCTUnwrap(AcademyActivityRegistry.activity(for: "compass-running"))

        XCTAssertEqual(activity.kind, .compassRun)
        XCTAssertTrue(activity.isCompassRun)
        XCTAssertTrue(activity.fields.isEmpty)
    }

    func testArtOfTheGlintStartsWithThreeSeparateObservableFacts() throws {
        let activity = try XCTUnwrap(AcademyActivityRegistry.activity(for: "art-of-the-glint"))

        XCTAssertEqual(activity.kind, .evidenceLog)
        XCTAssertEqual(activity.fields.map(\.id), ["fact-one", "fact-two", "fact-three"])
        XCTAssertTrue(activity.invitation.contains("evidence before enchantment"))
    }

    func testBasicEnchantmentsLaunchesTheExistingFourteenSpellCatalog() throws {
        let activity = try XCTUnwrap(AcademyActivityRegistry.activity(for: "basic-enchantments"))

        XCTAssertEqual(activity.kind, .enchantmentCasting)
        XCTAssertTrue(activity.fields.isEmpty)
        XCTAssertEqual(StoryEnchantmentCatalog.spells.count, 14)
    }

    func testEveryAcademyActivityCanBuildAnAnswerLedDebriefContract() throws {
        let sessions = Array(AcademyScheduleRegistry.classes.values) + AcademyScheduleRegistry.clubs.values

        for session in sessions {
            let activity = try XCTUnwrap(AcademyActivityRegistry.activity(for: session.id))
            let submittedDetail = "reader-specific-\(session.id)"
            let debrief = try XCTUnwrap(AcademyActivityDebrief(metadata: [
                "academyActivityTitle": activity.title,
                "academyActivityOutcome": "Submitted detail: \(submittedDetail)"
            ]))

            XCTAssertTrue(debrief.promptSection.contains(submittedDetail), session.id)
            XCTAssertTrue(debrief.promptSection.lowercased().contains("not a repeated lesson"), session.id)
            XCTAssertTrue(debrief.isAcknowledged(in: "The professor answers \(submittedDetail) directly."), session.id)
            XCTAssertFalse(debrief.isAcknowledged(in: "The professor repeats the old demonstration."), session.id)
        }
    }

    func testSynestheticResonanceDebriefRequiresTheReadersSensoryAnswer() throws {
        let debrief = try XCTUnwrap(AcademyActivityDebrief(metadata: [
            "academyActivityTitle": "Score the Room",
            "academyActivityOutcome": """
            One sound: the radiator ticking twice
            Its color: bruised apricot
            One body sensation: warmth behind my knees
            """
        ]))

        XCTAssertTrue(debrief.promptSection.contains("the radiator ticking twice"))
        XCTAssertTrue(debrief.anchorTerms.contains("radiator"))
        XCTAssertTrue(debrief.isAcknowledged(in: "Euphony repeats 'bruised apricot' before answering it."))
        XCTAssertFalse(debrief.isAcknowledged(in: "Euphony rings the glass bell and teaches the same scene again."))
    }

    func testAcademyDebriefRequiresANonemptySubmittedOutcome() {
        XCTAssertNil(AcademyActivityDebrief(metadata: [
            "academyActivityTitle": "Score the Room",
            "academyActivityOutcome": "   "
        ]))
    }
}
