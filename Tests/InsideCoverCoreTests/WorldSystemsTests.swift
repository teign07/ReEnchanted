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

    // MARK: The Nothing

    func testGreyLevelRespectsTheKindnessRules() {
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 5, narrativeHeat: 0, distressActive: true), 0, "distress silences the Nothing absolutely")
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 0, narrativeHeat: 0, distressActive: false), 0)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 1, narrativeHeat: 0, distressActive: false), 1)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 3, narrativeHeat: 0, distressActive: false), 2)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 5, narrativeHeat: 0, distressActive: false), 3)
        XCTAssertEqual(NothingTide.greyLevel(quietDays: 3, narrativeHeat: 8, distressActive: false), 1, "a hot story field pushes the grey back")
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
        XCTAssertEqual(StoryFormRegistry.coreRecipes.count, 12)
        XCTAssertTrue(StoryFormRegistry.coreRecipes.contains { $0.id == "souvenir-door" })
        XCTAssertTrue(StoryFormRegistry.coreRecipes.allSatisfy(StoryFormRegistry.recipeIsValid))
        XCTAssertTrue(StoryFormRegistry.coreRecipes.allSatisfy { $0.beats.count == StoryVignetteBeats.maximumInteractiveTurns })
        XCTAssertFalse(StoryFormRegistry.coreRecipes.contains { recipe in
            recipe.turns.contains { $0.wantTemplate.localizedCaseInsensitiveContains("without turning it into a confrontation") }
        })
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
        let page = BookPage(type: .souvenir, promptText: "Keep one thing", userInput: "The blue receipt has a coffee ring.", tags: ["souvenir"])
        let day = BookDay(id: "recipe-day", date: Date(), pages: [page])
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: .empty)
        XCTAssertEqual(packet.blueprint?.grounding.kind, .keptPage)
        XCTAssertTrue(packet.blueprint?.grounding.text.contains("blue receipt") == true)
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
        // (cadence-gated) — but never an offer without the places line.
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

        let mission = PlayfulMissionRegistry.mission(
            for: BookDay(id: "water-mission", date: now, pages: []),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(mission.id, "water-flow-low-point")
        XCTAssertTrue(mission.tags.contains("water"))
        XCTAssertTrue(mission.prompt.lowercased().contains("water"))
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

        XCTAssertEqual(notice.payload.metadata["startingPageBelief"], "62")
        XCTAssertNil(notice.payload.metadata["readerBeliefReward"])

        let source = notice.source
        let baseline = BookPageSourceRegistry.defaultBelief(for: source)
        let narrativeBias = (BookPageSourceRegistry.narrativeWeight(for: source) - 20) / 4
        let adjusted = CuratorSurfacePreferences.none.adjustedScore(for: notice)
        XCTAssertEqual(adjusted, notice.score + narrativeBias + (62 - baseline) / 2)
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

        XCTAssertEqual(mission.payload.metadata["startingPageBelief"], "62")
        XCTAssertNil(mission.payload.metadata["readerBeliefReward"])

        let source = mission.source
        let baseline = BookPageSourceRegistry.defaultBelief(for: source)
        let narrativeBias = (BookPageSourceRegistry.narrativeWeight(for: source) - 20) / 4
        let adjusted = CuratorSurfacePreferences.none.adjustedScore(for: mission)
        XCTAssertEqual(adjusted, mission.score + narrativeBias + (62 - baseline) / 2)
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

    func testShadowWonderAddsSeparateVariantsForExistingPageTypes() throws {
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets[ShadowWonder.duskThornTalismanID] = 1
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 19))!
        let day = BookDay(id: "shadow-surfaces", date: now, pages: [])
        let context = CuratorContext.make(for: day)

        let souvenirs = SouvenirPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        let compassPages = WonderCompassPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        let quips = QuipPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        let lore = EnchantifyLorePageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)

        let normalSouvenir = try XCTUnwrap(souvenirs.first { $0.payload.metadata["variant"] == nil })
        let shadowSouvenir = try XCTUnwrap(souvenirs.first { $0.payload.metadata["variant"] == "shadow-wonder" })
        let normalCompass = try XCTUnwrap(compassPages.first { $0.payload.metadata["variant"] == nil })
        let shadowCompass = try XCTUnwrap(compassPages.first { $0.payload.metadata["variant"] == "shadow-wonder" })
        let normalQuip = try XCTUnwrap(quips.first { $0.payload.metadata["variant"] == nil })
        let shadowQuip = try XCTUnwrap(quips.first { $0.payload.metadata["variant"] == "shadow-wonder" })
        let normalLore = try XCTUnwrap(lore.first { $0.payload.metadata["variant"] == nil })
        let shadowLore = try XCTUnwrap(lore.first { $0.payload.metadata["variant"] == "shadow-wonder" })

        XCTAssertEqual(normalSouvenir.type, .souvenir)
        XCTAssertEqual(shadowSouvenir.type, .souvenir)
        XCTAssertEqual(normalCompass.type, .wonderCompass)
        XCTAssertEqual(shadowCompass.type, .wonderCompass)
        XCTAssertEqual(normalQuip.type, .quip)
        XCTAssertEqual(shadowQuip.type, .quip)
        XCTAssertEqual(normalLore.type, .lore)
        XCTAssertEqual(shadowLore.type, .lore)

        XCTAssertFalse(normalSouvenir.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertFalse(normalCompass.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertFalse(normalQuip.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertFalse(normalLore.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertTrue(shadowSouvenir.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertTrue(shadowCompass.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertTrue(shadowQuip.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertTrue(shadowLore.payload.metadata["tags"]?.contains("shadow-wonder") == true)
        XCTAssertFalse(shadowSouvenir.payload.metadata["shadowVariantOf"]?.isEmpty ?? true)
        XCTAssertFalse(shadowCompass.payload.metadata["shadowVariantOf"]?.isEmpty ?? true)
        XCTAssertFalse(shadowQuip.payload.metadata["shadowVariantOf"]?.isEmpty ?? true)
        XCTAssertFalse(shadowLore.payload.metadata["shadowVariantOf"]?.isEmpty ?? true)
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
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 21))!
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
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 22))!
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
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 22))!
        let day = BookDay(id: "shadow-variants-day", date: now, pages: [])
        let context = CuratorContext.make(for: day)

        // The standalone North = Notice "I wonder" card has a shadow sibling.
        let compass: [SurfacePage] = WonderCompassPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        let shadowNotice = try XCTUnwrap(compass.first(where: {
            $0.payload.metadata["variant"] == "shadow-wonder"
                && $0.payload.metadata["compassStep"] == "notice"
                && $0.payload.metadata["standalone"] == "true"
        }), "A shadow standalone Notice card should surface on a fresh day")
        XCTAssertTrue(shadowNotice.payload.body.lowercased().contains("i wonder"))

        // Inner Weather, Center/Rest, and Today's Sky each gain a shadow variant.
        let mood: [SurfacePage] = MoodPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        XCTAssertNotNil(mood.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" && $0.type == .mood }))

        let rest: [SurfacePage] = RestPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
        XCTAssertNotNil(rest.first(where: { $0.payload.metadata["variant"] == "shadow-wonder" && $0.type == .rest }))

        let sky: [SurfacePage] = TodaysSkyPageSourceAdapter().candidates(for: day, context: context, inputs: inputs, now: now)
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
        let ranked = BookCurator.rankedPages(
            from: [page("q1", .quip, score: 90), page("q2", .quip, score: 88), page("d1", .diary, score: 60)],
            limit: 2
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
        // No custom cast at all — a bundled character should still surface.
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
        XCTAssertTrue(preview?.payload.body.contains("Hour Page") == true)
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
            readerBelief: 40,
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
            readerBelief: 41,
            events: [event],
            state: first.state
        ))

        XCTAssertEqual(second.readerDelta, 0)
        XCTAssertTrue(second.entityDeltas.isEmpty)
        XCTAssertTrue(second.pageDeltas.isEmpty)
    }

    func testBeliefEconomySettlesHighUntouchedGlow() {
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

        XCTAssertEqual(result.readerDelta, -3)
        XCTAssertEqual(result.entityDeltas["zara-finch"], -1)
        XCTAssertEqual(result.pageDeltas[source.id], -2)
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
        XCTAssertTrue(choice.evidenceLines.contains { $0.contains("Ember Seal") })
    }

    func testChapterBindingOracleCanChooseDuskthorn() {
        let days = [
            bindingDay(1, text: "The honest hard truth was that I needed a boundary."),
            bindingDay(2, text: "I protected the day by naming the difficult thing instead of avoiding it."),
            bindingDay(3, text: "The page kept the conflict because smoothing it away would have made the story false."),
            bindingDay(4, text: "A thorn can be protection, not cruelty."),
            bindingDay(5, text: "The Nothing loses ground when the sentence is interesting enough to stay.")
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

    func testWelcomePageGreetsNamedReaderBeforeChapterBinding() {
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
        XCTAssertTrue(welcome?.payload.body.contains("Hello, Beej") == true)
        XCTAssertTrue(welcome?.payload.body.contains("Pages will surface") == true)
        XCTAssertTrue(welcome?.payload.body.contains("Chapter Binding can wait") == true)
        XCTAssertGreaterThan(welcome?.score ?? 0, 80)
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

    func testFirstDoorOriginSurfaceCollectsOnboardingAnswers() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let day = BookDay(id: "2026-06-01", date: startedAt, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)

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
        XCTAssertTrue(origin?.payload.body.contains("peanut butter toast") == true)
        XCTAssertTrue(origin?.payload.body.contains("Small strange things count.") == true)
        XCTAssertTrue(origin?.payload.body.contains("The lamp made a small gold island on the desk.") == true)
    }

    func testFirstRunSequenceShowsOriginAfterWelcomeBeforeBrain() {
        let calendar = utcCalendar
        let startedAt = date(2026, 6, 1, hour: 9, calendar: calendar)
        let day = BookDay(id: "2026-06-01", date: startedAt, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = firstDoorFacts(startedAt: startedAt)
        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: startedAt, recentShowCount: 1)
        ]

        let pages = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: startedAt
        )

        XCTAssertEqual(pages?.map(\.sourceID), ["labyrinth-welcome", "first-door-origin"])

        inputs.surfaceHistory["first-door-origin"] = SurfaceHistoryRecord(lastShownAt: startedAt, recentShowCount: 1)

        let followUp = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: startedAt
        )

        XCTAssertEqual(followUp?.map(\.sourceID), ["labyrinth-welcome", FirstRunPageSequence.localBrainSetupSourceID])
        XCTAssertEqual(followUp?.last?.payload.metadata["firstRunStep"], "local-brain-setup")
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

        let pages = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(pages?.map(\.sourceID), ["labyrinth-welcome"])

        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1),
            "source:local-brain-awake": SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        ]
        inputs.localBrainIsReady = true

        // The reader already gave a true sentence in onboarding, so the first run
        // closes with a playful first mission rather than asking for one again.
        let afterWelcomeAndBrain = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(afterWelcomeAndBrain?.map(\.sourceID), ["labyrinth-welcome", "local-brain-awake", FirstRunPageSequence.enchantmentIntroSourceID])
        let enchantment = afterWelcomeAndBrain?.last
        XCTAssertEqual(enchantment?.type, .enchantment)
        XCTAssertEqual(enchantment?.payload.metadata["firstRunStep"], "enchantment-intro")
        XCTAssertTrue(enchantment?.payload.body.contains("Enchantment") == true)

        inputs.surfaceHistory["source:\(FirstRunPageSequence.enchantmentIntroSourceID)"] = SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        let afterEnchantmentBeforeCompassWindow = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        XCTAssertEqual(afterEnchantmentBeforeCompassWindow?.map(\.sourceID), ["labyrinth-welcome", "local-brain-awake", FirstRunPageSequence.firstMissionSourceID])
        XCTAssertFalse(afterEnchantmentBeforeCompassWindow?.last?.payload.body.lowercased().contains("one true sentence") ?? true)

        // Once the mission has been served, the first run is complete.
        inputs.surfaceHistory["source:\(FirstRunPageSequence.firstMissionSourceID)"] = SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        let afterMission = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        XCTAssertNil(afterMission)
    }

    func testFirstRunSequenceOffersCalendarDoorBeforeFirstMissionWhenClosed() {
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
        inputs.localBrainIsReady = true
        inputs.calendarIntegrationEnabled = false

        let pages = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(pages?.map(\.sourceID), ["labyrinth-welcome", "local-brain-awake", FirstRunPageSequence.enchantmentIntroSourceID])

        inputs.surfaceHistory["source:\(FirstRunPageSequence.enchantmentIntroSourceID)"] = SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        let afterEnchantment = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )
        XCTAssertEqual(afterEnchantment?.map(\.sourceID), ["labyrinth-welcome", "local-brain-awake", "calendar-page"])
        XCTAssertEqual(afterEnchantment?.last?.payload.metadata["calendarDoorPreview"], "true")

        inputs.surfaceHistory["source:calendar-page"] = SurfaceHistoryRecord(lastShownAt: Date(), recentShowCount: 1)
        let afterCalendarDoor = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(afterCalendarDoor?.map(\.sourceID), ["labyrinth-welcome", "local-brain-awake", FirstRunPageSequence.firstMissionSourceID])
    }

    func testFirstRunSequenceOffersMissionWhenOnboardingSkippedSouvenirAfterFeatureIntros() {
        let day = BookDay.today()
        let now = Date()
        var inputs = BookSourceInputs.empty
        inputs.surfaceHistory = [
            "source:labyrinth-welcome": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1),
            "source:local-brain-awake": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1),
            "source:\(FirstRunPageSequence.enchantmentIntroSourceID)": SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1)
        ]
        inputs.localBrainIsReady = true

        // No kept first souvenir: the First Door still closes with the same
        // playful mission, because onboarding no longer requires a duplicate
        // one-sentence toll before the ordinary feed can begin.
        let pages = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: Date()
        )

        XCTAssertEqual(pages?.last?.sourceID, FirstRunPageSequence.firstMissionSourceID)
        XCTAssertEqual(pages?.last?.type, .helpTips)
        XCTAssertEqual(pages?.last?.payload.metadata["firstRunStep"], "first-mission")
    }

    func testFirstRunSequenceSurfacesCompassRunOnlyInsidePostBrainWindow() {
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

        let tooSoon = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(20 * 60)
        )
        XCTAssertEqual(tooSoon?.last?.sourceID, FirstRunPageSequence.firstMissionSourceID)

        let inWindow = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(45 * 60)
        )
        XCTAssertEqual(inWindow?.map(\.sourceID), ["labyrinth-welcome", "local-brain-awake", FirstRunPageSequence.compassRunIntroSourceID])
        XCTAssertEqual(inWindow?.last?.type, .wonderCompass)
        XCTAssertEqual(inWindow?.last?.payload.metadata["firstRunStep"], "compass-run")

        let tooLate = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(9 * 3600)
        )
        XCTAssertEqual(tooLate?.last?.sourceID, FirstRunPageSequence.firstMissionSourceID)

        inputs.surfaceHistory["source:\(FirstRunPageSequence.compassRunIntroSourceID)"] = SurfaceHistoryRecord(lastShownAt: brainShownAt.addingTimeInterval(45 * 60), recentShowCount: 1)
        let afterCompass = FirstRunPageSequence.surfaces(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: brainShownAt.addingTimeInterval(60 * 60)
        )
        XCTAssertEqual(afterCompass?.last?.sourceID, FirstRunPageSequence.firstMissionSourceID)
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
        XCTAssertTrue(surfaces.first?.payload.body.contains("I have noticed") == true)
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

    func testBookJumpCollapseGoesColdAndCostsBelief() {
        let now = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let work = BookJumpEngine.publicDomainShelf[0]
        let state = BookJumpState(active: activeJumpFixture(work: work, depth: 3, degradation: 2, now: now))
        let result = BookJumpEngine.collapse(state, now: now)
        XCTAssertNil(result.state.active)
        XCTAssertGreaterThan(result.lostBelief, 0)
        XCTAssertTrue(result.state.isCold(work.id, at: now))
        XCTAssertEqual(result.state.returned.first?.souvenir, "")
    }

    func testBookJumpDailyDecayCollapsesWhenLongUnstable() {
        let start = date(2026, 6, 10, hour: 21, calendar: utcCalendar)
        let later = date(2026, 6, 12, hour: 21, calendar: utcCalendar)
        let work = BookJumpEngine.publicDomainShelf[0]
        // Already at the brink, untouched for a day -> the Nothing overruns it.
        let state = BookJumpState(active: activeJumpFixture(work: work, depth: 3, degradation: 4, now: start))
        let result = BookJumpEngine.dailyDecay(state, now: later)
        XCTAssertTrue(result.collapsed)
        XCTAssertNil(result.state.active)
        XCTAssertTrue(result.state.isCold(work.id, at: later))
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
        XCTAssertEqual(BookJumpEngine.advanceCost(depth: 1), 0)
        XCTAssertEqual(BookJumpEngine.advanceCost(depth: 3), 2)
        XCTAssertEqual(BookJumpEngine.returnReward(depth: 1, hasSouvenir: true), BookJumpEngine.returnReward)
        XCTAssertGreaterThan(BookJumpEngine.returnReward(depth: 4, hasSouvenir: true), BookJumpEngine.returnReward)
        XCTAssertEqual(BookJumpEngine.returnReward(depth: 4, hasSouvenir: false), 1)
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
}
