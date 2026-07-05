import XCTest
@testable import InsideCoverCore

final class BookCuratorTests: XCTestCase {
    private func ownDictionaryRebellionForTest() -> Set<String> {
        let savedOwned = PackEntitlements.ownedPackIDs
        PackEntitlements.ownedPackIDs.insert("dictionary-rebellion")
        return savedOwned
    }

    func testCuratorReturnsExactlyThreeWhenEnoughCandidatesExist() {
        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 3
        )

        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(Set(pages.map(\.id)).count, 3)
        XCTAssertTrue(pages.contains { $0.type == .bookOfYou } == false)
    }

    func testDismissingTopSurfaceRefillsFromNextRankedCandidate() throws {
        let day = emptyDay()
        let firstPass = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 3
        )
        let dismissedID = try XCTUnwrap(firstPass.first?.id)

        let secondPass = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 3,
            preferences: CuratorSurfacePreferences(dismissedSurfaceIDs: [dismissedID])
        )

        XCTAssertEqual(secondPass.count, 3)
        XCTAssertFalse(secondPass.contains { $0.id == dismissedID })
        XCTAssertNotEqual(firstPass.map(\.id), secondPass.map(\.id))
    }

    func testDismissingSurfaceFamilyBlocksSiblingPreviewCards() {
        let run = wonderCompassCandidate(
            id: "wonder-run",
            score: 90,
            metadata: ["runID": "morning-loop"]
        )
        let reference = wonderCompassCandidate(
            id: "wonder-reference",
            score: 88,
            metadata: ["snippetID": "wonder-compass-core-loop"]
        )
        let fallback = rankedCandidate(.quip, score: 40)
        let preferences = CuratorSurfacePreferences(dismissedSurfaceIDs: run.curatorDeskExclusionKeys)

        let pages = BookCurator.rankedPages(
            from: [run, reference, fallback],
            limit: 2,
            preferences: preferences,
            mood: .neutral,
            now: localDate(hour: 21)
        ).map(\.page)

        XCTAssertFalse(pages.contains { $0.type == .wonderCompass })
        XCTAssertEqual(pages.map(\.type), [.quip])
    }

    func testMutedSourceIsExcludedInsideCurator() {
        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 8,
            preferences: CuratorSurfacePreferences(disabledSourceIDs: ["wonder-compass"])
        )

        XCTAssertFalse(pages.contains { $0.sourceID == "wonder-compass" })
    }

    func testPreparedIlluminatedPhotoRisesIntoVisibleShelf() {
        let prepared = SurfacePage(
            id: "illuminated-photos-prepared-test",
            type: .illuminatedPhoto,
            sourceID: "illuminated-photos",
            intent: .resurface,
            renderStyle: .illuminatedPhoto,
            score: 96,
            reason: "Penny found a photo with ink on it.",
            prompt: "Found in the Margins",
            detail: "The page is already rendered.",
            payload: BookPagePayload(
                headline: "Field Study",
                body: "The Book kept the page: detail spoke.",
                metadata: [
                    "renderedPreviewPath": "/tmp/reenchanted-prepared-illumination.jpg",
                    "assetLocalIdentifier": "test-photo-asset",
                    "sourceAssetName": "IlluminatedPhotoSource"
                ]
            )
        )
        var inputs = richInputs()
        inputs.preparedIlluminatedPhotoSurface = prepared

        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 14),
            limit: 3
        )

        XCTAssertTrue(pages.contains { $0.id == prepared.id })
    }

    func testEveryActiveSourceHasACuratorAdapter() {
        let adapterSourceIDs = Set(BookPageSourceAdapters.active.map(\.source.id))
        let activeSourceIDs = Set(BookPageSourceRegistry.activeSources.map(\.id))

        XCTAssertTrue(activeSourceIDs.isSubset(of: adapterSourceIDs))
    }

    func testCoreRadioStationsAreAvailableWithoutPacks() throws {
        let stations = RadioStationRegistry.stations()

        XCTAssertEqual(stations.map(\.id), ["fae-fi", "mothlight-beats", "thornwave"])
        XCTAssertTrue(stations.allSatisfy(\.isCore))
        XCTAssertEqual(try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi")).displayFrequency, "88.3")
        XCTAssertEqual(try XCTUnwrap(RadioStationRegistry.station(id: "thornwave")).displayFrequency, "103.7")
    }

    func testPirateStationIsUnlistedButExactDialCanFindIt() throws {
        XCTAssertFalse(RadioStationRegistry.stations().contains { $0.id == "the-bleed" })

        let pirate = try XCTUnwrap(RadioStationRegistry.station(id: "the-bleed"))
        XCTAssertEqual(pirate.displayFrequency, "97.3")
        XCTAssertEqual(pirate.tracks.first?.assetName, "RadioTheBleedPirateSignal")
        XCTAssertEqual(RadioStationRegistry.nearestStation(to: 97.3)?.id, "the-bleed")
        XCTAssertNotEqual(RadioStationRegistry.nearestStation(to: 97.2)?.id, "the-bleed")
        XCTAssertNotEqual(RadioStationRegistry.nearestStation(to: 97.4)?.id, "the-bleed")
        XCTAssertEqual(RadioStationRegistry.tunedStation(to: 97.3)?.id, "the-bleed")
        XCTAssertNil(RadioStationRegistry.tunedStation(to: 97.2))
        XCTAssertNil(RadioStationRegistry.tunedStation(to: 97.4))
        XCTAssertNil(RadioStationRegistry.tunedStation(to: 94.1))
        XCTAssertEqual(RadioStationRegistry.tunedStation(to: 103.8)?.id, "thornwave")
    }

    func testUnlockedRadioSoundPackAddsStationsToDial() throws {
        let lockedStations = RadioStationRegistry.stations()
        let unlockedStations = RadioStationRegistry.stations(unlockedPackIDs: ["academy-night-band"])

        XCTAssertFalse(lockedStations.contains { $0.id == "goblin-market-jazz" })
        XCTAssertTrue(unlockedStations.contains { $0.id == "midnight-bindery" })
        XCTAssertTrue(unlockedStations.contains { $0.id == "goblin-market-jazz" })
        XCTAssertEqual(try XCTUnwrap(RadioStationRegistry.station(id: "goblin-market-jazz", unlockedPackIDs: ["academy-night-band"])).displayFrequency, "105.1")
    }

    func testManualRadioPageCarriesStationMetadata() {
        var inputs = richInputs()
        inputs.radio = RadioPlaybackState(activeStationID: "thornwave")

        let surface = BookPageSourceAdapters.manualSurface(
            for: .radio,
            day: emptyDay(),
            context: CuratorContext.make(for: emptyDay()),
            inputs: inputs,
            now: localDate(hour: 20)
        )

        XCTAssertEqual(surface.type, .radio)
        XCTAssertEqual(surface.sourceID, "reenchanted-radio")
        XCTAssertEqual(surface.payload.metadata["radioStationID"], "thornwave")
        XCTAssertEqual(surface.payload.metadata["radioFrequency"], "103.7")
        XCTAssertEqual(surface.payload.metadata["radioStationTitle"], "Thornwave")
        XCTAssertTrue(surface.payload.metadata["radioEffects"]?.contains("+10") == true)
    }

    func testTunedRadioStationBoostsCuratorMood() {
        var inputs = richInputs()
        inputs.radio = RadioPlaybackState(activeStationID: "mothlight-beats")
        let mood = CuratorMood.make(inputs: inputs, now: localDate(hour: 11))
        let moodPage = SurfacePage(type: .mood, sourceID: "mood-page", prompt: "Inner weather", detail: "Name it.")
        let weatherPage = SurfacePage(type: .weather, sourceID: "weather-page", prompt: "Weather", detail: "Outside.")

        XCTAssertGreaterThan(mood.adjustment(for: moodPage, now: localDate(hour: 11)), mood.adjustment(for: weatherPage, now: localDate(hour: 11)))
    }

    func testSurfacePageSourceMetadataResolvesFromSourceID() {
        let page = SurfacePage(
            type: .weather,
            sourceID: "body-page",
            prompt: "The Body Page is listening quietly.",
            detail: "A soft translation is waiting."
        )

        XCTAssertEqual(page.source.id, "body-page")
        XCTAssertEqual(page.origin, .generated)
        XCTAssertEqual(page.privacy, .localSensitive)
    }

    func testWeatherPreviewSurfacesInDailyWindowsWithoutCachedWeather() throws {
        var inputs = richInputs()
        inputs.weather = nil
        inputs.enchantedWeather = nil

        for (hour, minute, windowID) in [(8, 0, "morning"), (13, 0, "midday"), (18, 0, "evening")] {
            let pages = BookCurator.surfacedPages(
                for: emptyDay(),
                inputs: inputs,
                now: localDate(hour: hour, minute: minute),
                limit: 20
            )
            let weather = try XCTUnwrap(pages.first { $0.type == .weather }, "Expected Weather preview in \(windowID)")

            XCTAssertEqual(weather.payload.metadata["weatherPreview"], "true")
            XCTAssertEqual(weather.payload.metadata["requiresWeatherRefresh"], "true")
            XCTAssertEqual(weather.payload.metadata["checkInWindowID"], windowID)
            XCTAssertTrue(SurfaceReadinessState(surface: weather).needsLocalBrainToOpen)
        }
    }

    func testWeatherPreviewStaysQuietOutsideDailyWindowsWithoutCachedWeather() {
        var inputs = richInputs()
        inputs.weather = nil
        inputs.enchantedWeather = nil

        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 11),
            limit: 20
        )

        XCTAssertFalse(pages.contains { $0.type == .weather })
    }

    func testDailyCheckInAffinityStaggersCoreCapturePages() {
        assertCheckInPrimary(.mood, atHour: 7, minute: 15)
        assertCheckInPrimary(.fuel, atHour: 8, minute: 30)
        assertCheckInPrimary(.souvenir, atHour: 9, minute: 45)

        assertCheckInPrimary(.fuel, atHour: 12, minute: 15)
        assertCheckInPrimary(.souvenir, atHour: 13, minute: 30)
        assertCheckInPrimary(.mood, atHour: 14, minute: 45)

        assertCheckInPrimary(.souvenir, atHour: 18, minute: 0)
        assertCheckInPrimary(.mood, atHour: 18, minute: 35)
        assertCheckInPrimary(.fuel, atHour: 19, minute: 10)
    }

    func testDeskNeverShowsTwoCardsOfTheSameType() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 13)
        let loreA = loreCandidate(id: "lore-a", score: 100)
        let loreB = loreCandidate(id: "lore-b", score: 95)
        let candidates = [
            loreA,
            loreB,
            rankedCandidate(.quip, score: 60),
            rankedCandidate(.illustration, score: 55)
        ]

        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: .neutral, now: now).map(\.page)

        XCTAssertEqual(pages.filter { $0.type == .lore }.count, 1)
        XCTAssertEqual(Set(pages.map(\.type)).count, pages.count)
        XCTAssertEqual(pages.first?.id, "lore-a")
    }

    func testDeskNeverShowsTwoCardsFromSameSourceFamily() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 13)
        let familyA = SurfacePage(
            id: "shared-family-wonder",
            type: .wonderCompass,
            sourceID: "shared-preview-family",
            score: 100,
            prompt: "Wonder Compass",
            detail: "A guide card."
        )
        let familyB = SurfacePage(
            id: "shared-family-lore",
            type: .lore,
            sourceID: "shared-preview-family",
            score: 95,
            prompt: "Lore",
            detail: "A sibling guide card."
        )
        let candidates = [
            familyA,
            familyB,
            rankedCandidate(.quip, score: 60),
            rankedCandidate(.illustration, score: 55)
        ]

        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: .neutral, now: now).map(\.page)

        XCTAssertEqual(pages.filter { $0.sourceID == "shared-preview-family" }.count, 1)
        XCTAssertEqual(pages.first?.id, "shared-family-wonder")
        XCTAssertTrue(pages.contains { $0.type == .quip })
        XCTAssertTrue(pages.contains { $0.type == .illustration })
    }

    func testWonderCompassVariantsShareCuratorDeskFamily() {
        let run = wonderCompassCandidate(
            id: "wonder-run",
            score: 62,
            metadata: ["runID": "morning-loop"]
        )
        let reference = wonderCompassCandidate(
            id: "wonder-reference",
            score: 66,
            metadata: ["snippetID": "wonder-compass-core-loop"]
        )

        XCTAssertFalse(run.curatorDeskExclusionKeys.isDisjoint(with: reference.curatorDeskExclusionKeys))
    }

    func testDeskNeverStacksTwoBlankPagePrompts() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 13)
        let candidates = [
            rankedCandidate(.diary, score: 100),
            rankedCandidate(.souvenir, score: 95),
            rankedCandidate(.mood, score: 90),
            rankedCandidate(.lore, score: 40),
            rankedCandidate(.quip, score: 39)
        ]

        let pages = BookCurator.rankedPages(from: candidates, limit: 3, mood: .neutral, now: now).map(\.page)

        XCTAssertEqual(pages.filter { $0.type.isCompositionPrompt }.count, 1)
        XCTAssertEqual(pages.first?.type, .diary)
        XCTAssertTrue(pages.contains { $0.type == .lore })
        XCTAssertTrue(pages.contains { $0.type == .quip })
    }

    func testCompositionPromptAlreadyWrittenTodayIsPushedDown() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 13)
        var inputs = BookSourceInputs.empty
        inputs.days = [
            BookDay(
                id: "2026-06-01",
                date: localDate(year: 2026, month: 6, day: 1, hour: 0),
                pages: [
                    BookPage(
                        id: "todays-diary",
                        type: .diary,
                        createdAt: localDate(year: 2026, month: 6, day: 1, hour: 9),
                        promptText: "What is happening inside this moment?",
                        userInput: "The kettle clicked like a tiny door latch.",
                        tags: ["diary"]
                    )
                ]
            )
        ]
        let mood = CuratorMood.make(inputs: inputs, now: now)
        let diary = rankedCandidate(.diary, score: 80)
        let souvenir = rankedCandidate(.souvenir, score: 80)

        XCTAssertLessThan(
            mood.adjustment(for: diary, now: now),
            mood.adjustment(for: souvenir, now: now)
        )
        XCTAssertLessThan(mood.adjustment(for: diary, now: now), -20)
    }

    func testBlankPagePromptsEaseDownLateAtNight() {
        let midnight = localDate(hour: 0, minute: 30)
        for type in [BookPageType.diary, .souvenir, .mood, .aboutYou] {
            XCTAssertLessThan(CuratorTimeAffinity.boost(for: type, at: midnight), 0, "\(type) should ease down late at night")
        }
    }

    func testFirstHoursCuratorHidesDeepSystemCards() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        let candidates = [
            rankedCandidate(.bookConnections, score: 100),
            rankedCandidate(.bookRemembered, score: 99),
            rankedCandidate(.faeBargain, score: 98),
            rankedCandidate(.marginsAtlas, score: 97),
            rankedCandidate(.theBleed, score: 96),
            rankedCandidate(.helpTips, score: 40),
            rankedCandidate(.fuel, score: 39),
            rankedCandidate(.souvenir, score: 38)
        ]
        let mood = CuratorMood.make(inputs: .empty, now: now)

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 8,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertFalse(pages.contains { [.bookConnections, .bookRemembered, .faeBargain, .marginsAtlas, .theBleed].contains($0.type) })
        XCTAssertEqual(Set(pages.map(\.type)), [.helpTips, .fuel, .souvenir])
    }

    func testFirstHoursCuratorAllowsActiveBookJumpButHidesStart() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        let start = bookJumpCandidate(action: .start, score: 100)
        let active = bookJumpCandidate(action: .advance, score: 99)
        let orientation = rankedCandidate(.helpTips, score: 40)
        let mood = CuratorMood.make(inputs: .empty, now: now)

        let pages = BookCurator.rankedPages(
            from: [start, active, orientation],
            limit: 3,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertFalse(pages.contains { $0.id == start.id })
        XCTAssertTrue(pages.contains { $0.id == active.id })
        XCTAssertTrue(pages.contains { $0.id == orientation.id })
    }

    func testFirstHoursCuratorBoostsOrientationCards() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 11)
        let candidates = [
            rankedCandidate(.supportGuild, score: 49),
            rankedCandidate(.helpTips, score: 42),
            rankedCandidate(.lore, score: 41),
            rankedCandidate(.mood, score: 40)
        ]
        let mood = CuratorMood.make(inputs: .empty, now: now)

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.first?.type, .helpTips)
        XCTAssertEqual(Set(pages.map(\.type)), [.helpTips, .lore, .mood])
    }

    func testPlayfulMissionWonderCompassGetsHigherCurationWeight() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 13)
        let mission = wonderCompassCandidate(
            id: "wonder-playful",
            score: 58,
            metadata: [
                "playfulMissionID": "pocket-weather",
                "compassStep": "sense",
                "compassMode": "standalone"
            ]
        )
        let reference = wonderCompassCandidate(
            id: "wonder-reference",
            score: 66,
            metadata: ["snippetID": "wonder-compass-core-loop"]
        )

        let pages = BookCurator.rankedPages(
            from: [reference, mission],
            limit: 2,
            mood: .neutral,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.first?.id, "wonder-playful")
    }

    func testStandaloneNorthNoticeWonderCompassGetsHigherCurationWeight() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 13)
        let notice = wonderCompassCandidate(
            id: "wonder-notice",
            score: 59,
            metadata: [
                "compassStep": "notice",
                "compassMode": "standalone"
            ]
        )
        let reference = wonderCompassCandidate(
            id: "wonder-reference",
            score: 66,
            metadata: ["snippetID": "wonder-compass-core-loop"]
        )

        let pages = BookCurator.rankedPages(
            from: [reference, notice],
            limit: 2,
            mood: .neutral,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.first?.id, "wonder-notice")
    }

    func testDeepSystemCardsStayLockedAfterFirstHoursUntilArchiveIsReady() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            SelfFact(
                id: "onboarding-name",
                questionID: "onboarding-name",
                question: "What should the Book call you?",
                answer: "Avery",
                bookTranslation: "The Book knows this now.",
                sensitivity: .identity,
                usePermission: .privateContext,
                tags: ["identity", "onboarding"],
                createdAt: now.addingTimeInterval(-7 * 3600),
                updatedAt: now.addingTimeInterval(-7 * 3600)
            )
        ]
        let candidates = [
            rankedCandidate(.bookConnections, score: 100),
            rankedCandidate(.bookRemembered, score: 99),
            rankedCandidate(.helpTips, score: 40)
        ]
        let mood = CuratorMood.make(inputs: inputs, now: now)

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.map(\.type), [.helpTips])
    }

    func testMemorySystemCardsUnlockAfterFiftyKeptPages() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        let candidates = [
            rankedCandidate(.bookConnections, score: 100),
            rankedCandidate(.bookRemembered, score: 99),
            rankedCandidate(.marginsAtlas, score: 98),
            rankedCandidate(.helpTips, score: 40)
        ]

        var nearlyReady = BookSourceInputs.empty
        nearlyReady.days = [dayWithKeptPageCount(49)]
        let locked = BookCurator.rankedPages(
            from: candidates,
            limit: 4,
            mood: CuratorMood.make(inputs: nearlyReady, now: now),
            now: now
        ).map(\.page.type)

        var ready = BookSourceInputs.empty
        ready.days = [dayWithKeptPageCount(50)]
        let unlocked = BookCurator.rankedPages(
            from: candidates,
            limit: 4,
            mood: CuratorMood.make(inputs: ready, now: now),
            now: now
        ).map(\.page.type)

        XCTAssertEqual(locked, [.helpTips])
        XCTAssertEqual(unlocked, [.bookConnections, .bookRemembered, .marginsAtlas, .helpTips])
    }

    func testRecentlySurfacedPageTypeIsSuppressedBriefly() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        var mood = CuratorMood.neutral
        mood.surfaceHistory = [
            CuratorVarietyGovernor.typeKey(for: .fuel): SurfaceHistoryRecord(
                lastShownAt: now.addingTimeInterval(-20 * 60),
                recentShowCount: 1
            )
        ]
        let candidates = [
            rankedCandidate(.fuel, score: 100),
            rankedCandidate(.weather, score: 40),
            rankedCandidate(.mood, score: 39)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertFalse(pages.contains { $0.type == .fuel })
        XCTAssertEqual(Set(pages.map(\.type)), [.weather, .mood])
    }

    func testSurfacedPageTypeReturnsAfterCooldown() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        var mood = CuratorMood.neutral
        mood.surfaceHistory = [
            CuratorVarietyGovernor.typeKey(for: .fuel): SurfaceHistoryRecord(
                lastShownAt: now.addingTimeInterval(-91 * 60),
                recentShowCount: 1
            )
        ]
        let candidates = [
            rankedCandidate(.fuel, score: 100),
            rankedCandidate(.weather, score: 40)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 2,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertEqual(pages.first?.type, .fuel)
    }

    func testCooldownNeverStarvesTheDesk() {
        // The type-refresh cooldown adds variety; it must never leave the
        // homescreen empty. When every candidate type is still on cooldown,
        // the curator falls back to the full allowed pool so the reader is
        // never stranded with no pages (which previously soft-locked the menu).
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)
        var mood = CuratorMood.neutral
        mood.surfaceHistory = [
            CuratorVarietyGovernor.typeKey(for: .fuel): SurfaceHistoryRecord(
                lastShownAt: now.addingTimeInterval(-5 * 60),
                recentShowCount: 1
            ),
            CuratorVarietyGovernor.typeKey(for: .weather): SurfaceHistoryRecord(
                lastShownAt: now.addingTimeInterval(-5 * 60),
                recentShowCount: 1
            )
        ]
        let candidates = [
            rankedCandidate(.fuel, score: 100),
            rankedCandidate(.weather, score: 40)
        ]

        let pages = BookCurator.rankedPages(
            from: candidates,
            limit: 3,
            mood: mood,
            now: now
        ).map(\.page)

        XCTAssertFalse(pages.isEmpty, "Cooldown must never leave the desk empty")
        XCTAssertEqual(pages.first?.type, .fuel)
    }

    func testSouvenirCanReturnInSeparateCheckInWindows() {
        let adapter = SouvenirPageSourceAdapter()
        let day = BookDay(
            id: "2026-06-01",
            date: localDate(hour: 0),
            pages: [
                BookPage(
                    id: "morning-souvenir",
                    type: .souvenir,
                    createdAt: localDate(hour: 7, minute: 20),
                    promptText: "Catch one bright particular.",
                    userInput: "The kettle clicked like a tiny door latch.",
                    tags: ["souvenir", "check-in-window:morning"]
                )
            ]
        )

        let morning = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: richInputs(), now: localDate(hour: 8))
        let midday = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: richInputs(), now: localDate(hour: 13))

        XCTAssertTrue(morning.isEmpty)
        XCTAssertEqual(midday.first?.payload.metadata["checkInWindowID"], "midday")
    }

    func testGreyPressureAddsOneSentenceSouvenirVariant() {
        let adapter = SouvenirPageSourceAdapter()
        let day = BookDay(id: "2026-06-01", date: localDate(hour: 0), pages: [])
        var inputs = richInputs()
        inputs.quietDays = 3
        inputs.narrative = NarrativeSourceSnapshot(activeThreadCount: 0, relationshipCount: 0, beliefWeight: 0)

        let pages = adapter.candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: localDate(hour: 13)
        )

        let grey = pages.first { $0.payload.metadata["variant"] == "grey-edge" }
        XCTAssertEqual(grey?.type, .souvenir)
        XCTAssertEqual(grey?.payload.metadata["checkInWindowID"], "midday")
        XCTAssertTrue(grey?.prompt.contains("one true detail") == true)
        XCTAssertGreaterThan(grey?.score ?? 0, pages.first { $0.payload.metadata["variant"] == nil }?.score ?? 0)
    }

    func testGreyPressureSouvenirDoesNotAppearAfterWindowSouvenirIsKept() {
        let adapter = SouvenirPageSourceAdapter()
        let day = BookDay(
            id: "2026-06-01",
            date: localDate(hour: 0),
            pages: [
                BookPage(
                    id: "midday-souvenir",
                    type: .souvenir,
                    createdAt: localDate(hour: 13, minute: 5),
                    promptText: "Name one true detail within reach.",
                    userInput: "The spoon flashed once in the sink.",
                    tags: ["souvenir", "grey-edge", "check-in-window:midday"]
                )
            ]
        )
        var inputs = richInputs()
        inputs.quietDays = 3
        inputs.narrative = NarrativeSourceSnapshot(activeThreadCount: 0, relationshipCount: 0, beliefWeight: 0)

        let pages = adapter.candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: localDate(hour: 13, minute: 30)
        )

        XCTAssertTrue(pages.isEmpty)
    }

    func testBookRememberedSurfacesOldPageWhenTodayRhymes() {
        let now = localDate(hour: 9, minute: 15)
        let oldDate = Calendar.current.date(byAdding: .day, value: -180, to: now) ?? now.addingTimeInterval(-180 * 24 * 3600)
        let remembered = BookPage(
            id: "fog-walk",
            type: .souvenir,
            createdAt: oldDate,
            promptText: "Catch one bright particular.",
            userInput: "The fog on the walk made the window light look soft.",
            tags: ["souvenir", "fog", "walk"],
            usedInBookOfYou: true
        )
        var inputs = richInputs().withMatureLibrary(now: now)
        inputs.weather = WeatherSourceSignal(
            phrase: "Fog at the window.",
            source: "test",
            forecast: "fog through morning",
            conditionSymbolName: "cloud.fog"
        )
        inputs.resurfacingCandidates = [remembered]
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let context = CuratorContext.make(for: today)
        let pages = BookRememberedPageSourceAdapter().candidates(
            for: today,
            context: context,
            inputs: inputs,
            now: now
        )

        let page = pages.first { $0.type == BookPageType.bookRemembered }
        XCTAssertEqual(page?.payload.metadata["rememberedPageID"], "fog-walk")
        XCTAssertEqual(page?.payload.metadata["tinyAction"], "Stand at the nearest threshold for ten seconds. Let the outside know you noticed.")
        XCTAssertTrue(page?.payload.body.contains("\"The fog on the walk made the window light look soft.\"") == true)

        let topShelf = BookCurator.surfacedPages(
            for: today,
            inputs: inputs,
            now: now,
            limit: 3
        )
        XCTAssertLessThanOrEqual(topShelf.filter { $0.type == .bookRemembered }.count, 1)
    }

    func testBookRememberedDoesNotRepeatAfterTodayKeptAVisitation() {
        let now = localDate(hour: 9, minute: 15)
        let oldDate = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now.addingTimeInterval(-90 * 24 * 3600)
        let remembered = BookPage(
            id: "rain-window",
            type: .souvenir,
            createdAt: oldDate,
            promptText: "Catch one bright particular.",
            userInput: "Rain threaded the window.",
            tags: ["souvenir", "rain"],
            usedInBookOfYou: true
        )
        let today = BookDay(
            id: BookDay.id(for: now),
            date: Calendar.current.startOfDay(for: now),
            pages: [
                BookPage(
                    id: "already-remembered",
                    type: .bookRemembered,
                    createdAt: now,
                    promptText: "The Book remembered.",
                    userInput: "A remembered page returned.",
                    tags: ["book-remembered", "remembered-page:rain-window"]
                )
            ]
        )
        var inputs = richInputs()
        inputs.resurfacingCandidates = [remembered]

        let pages = BookRememberedPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(pages.isEmpty)
    }

    func testBookRememberedExplainsRelationshipReturns() {
        let now = localDate(hour: 9, minute: 15)
        let oldDate = Calendar.current.date(byAdding: .day, value: -45, to: now) ?? now.addingTimeInterval(-45 * 24 * 3600)
        let remembered = BookPage(
            id: "inkrest-letter",
            type: .letter,
            createdAt: oldDate,
            promptText: "A letter from Dr. Inkrest.",
            userInput: "Dr. Inkrest asked me to keep the difficult page without making it smaller.",
            tags: ["letter", "relationship"],
            usedInBookOfYou: true
        )
        var inputs = richInputs().withMatureLibrary(now: now)
        inputs.resurfacingCandidates = [remembered]
        inputs.relationshipField = [
            "book-authors-reader": RelationshipTie(warmth: 2, tension: 1, familiarity: 4)
        ]
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let pages = BookRememberedPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )

        let page = pages.first { $0.type == BookPageType.bookRemembered }
        XCTAssertEqual(
            page?.payload.metadata["rhymeReason"],
            "Dr. Selene Inkrest is moving in the margins again, so this old page has become evidence."
        )
    }

    func testIllustrationSurfaceExposesBundledMediaAsset() throws {
        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 16
        )
        let illustration = try XCTUnwrap(pages.first { $0.type == .illustration })
        let media = try XCTUnwrap(illustration.mediaAssets.first)

        XCTAssertEqual(media.kind, .bundledImage)
        XCTAssertEqual(media.reference, illustration.payload.metadata["assetName"])
        XCTAssertEqual(media.sourceID, illustration.sourceID)
        XCTAssertFalse(media.caption.isEmpty)
    }

    func testIlluminatedPhotoSurfaceExposesRenderedMediaAsset() {
        let surface = SurfacePage(
            type: .illuminatedPhoto,
            sourceID: "illuminated-photos",
            renderStyle: .illuminatedPhoto,
            prompt: "Found in the Margins",
            detail: "The page is already rendered.",
            payload: BookPagePayload(
                headline: "Lamp Study",
                body: "The Book kept the page: lamp-light gathered in the corner.",
                metadata: [
                    "renderedPreviewPath": "/tmp/reenchanted-illumination.png",
                    "assetLocalIdentifier": "photo-asset-1"
                ]
            )
        )

        XCTAssertTrue(surface.mediaAssets.contains {
            $0.kind == .renderedImageFile && $0.reference == "/tmp/reenchanted-illumination.png"
        })
        XCTAssertTrue(surface.mediaAssets.contains {
            $0.kind == .photoLibraryAsset && $0.reference == "photo-asset-1"
        })
    }

    func testCuratorCandidatesUseRegisteredSourceMetadata() {
        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 16
        )

        XCTAssertFalse(pages.isEmpty)
        for page in pages {
            let source = BookPageSourceRegistry.source(id: page.sourceID, fallbackType: page.type)
            XCTAssertEqual(page.source, source)
            XCTAssertEqual(page.origin, source.origin)
            XCTAssertEqual(page.privacy, source.privacy)
        }
    }

    func testBodyAndWeatherPagesRotateOnFourHourCadence() throws {
        let morning = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 9),
            limit: 20
        )
        let sameWindow = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 11),
            limit: 20
        )
        let nextWindow = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(hour: 13),
            limit: 20
        )

        let morningBody = try XCTUnwrap(morning.first { $0.type == .body })
        let morningWeather = try XCTUnwrap(morning.first { $0.type == .weather })
        let sameWindowBody = try XCTUnwrap(sameWindow.first { $0.type == .body })
        let sameWindowWeather = try XCTUnwrap(sameWindow.first { $0.type == .weather })
        let nextWindowBody = try XCTUnwrap(nextWindow.first { $0.type == .body })
        let nextWindowWeather = try XCTUnwrap(nextWindow.first { $0.type == .weather })

        XCTAssertEqual(morningBody.id, sameWindowBody.id)
        XCTAssertEqual(morningWeather.id, sameWindowWeather.id)
        XCTAssertNotEqual(morningBody.id, nextWindowBody.id)
        XCTAssertNotEqual(morningWeather.id, nextWindowWeather.id)
    }

    func testBodyPageBraidsFuelAndInnerWeatherIntoPrivateFieldReport() throws {
        let now = localDate(hour: 10)
        var inputs = richInputs()
        inputs.body = BodySourceSignal(
            status: "LOW",
            score: 24,
            phrase: "The lamps are low in the stacks.",
            metrics: [
                BodySourceSignal.Metric(id: "stepCount", label: "Steps", value: "640", kind: "sum"),
                BodySourceSignal.Metric(id: "sleepAnalysis", label: "Sleep", value: "4.8", unit: "h", kind: "category")
            ]
        )
        inputs.facultyEntries = [
            FacultyEntry(kind: .fuel, dayID: "2026-06-01", createdAt: localDate(hour: 8), windowID: "morning", windowName: "Morning", rawText: "Coffee and toast."),
            FacultyEntry(kind: .innerWeather, dayID: "2026-06-01", createdAt: localDate(hour: 9), windowID: "morning", windowName: "Morning", rawText: "Static and rain.")
        ]

        let surface = try XCTUnwrap(BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: inputs,
            now: now,
            limit: 20
        ).first { $0.type == .body })

        XCTAssertEqual(surface.payload.metadata["bodyGlyph"], "Small Hearth")
        XCTAssertTrue(surface.payload.body.contains("Vellum reads the chart this way"))
        XCTAssertTrue(surface.payload.body.contains("fuel and inner weather are both on the desk"))
        XCTAssertTrue(surface.payload.body.contains("not obedience"))
        XCTAssertTrue(surface.payload.metadata["metrics"]?.contains("Sleep 4.8 h") == true)
    }

    func testBrightBodyPageOffersCurrentWithoutScoreboard() throws {
        var inputs = richInputs()
        inputs.body = BodySourceSignal(
            status: "BRIGHT",
            score: 78,
            phrase: "There is motion in the margins.",
            metrics: [
                BodySourceSignal.Metric(id: "stepCount", label: "Steps", value: "7200", kind: "sum")
            ]
        )

        let surface = try XCTUnwrap(BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 14),
            limit: 20
        ).first { $0.type == .body })

        XCTAssertEqual(surface.payload.metadata["bodyGlyph"], "Walking Star")
        XCTAssertTrue(surface.prompt.contains("found a current"))
        XCTAssertTrue(surface.payload.body.contains("future-you can touch"))
        XCTAssertTrue(surface.payload.body.contains("scoreboard"))
    }

    func testDismissalLedgerLetsPagesReturnAfterRestWindow() {
        let now = localDate(hour: 12)
        var ledger = SurfaceDismissalLedger()
        ledger.dismiss(surfaceID: "lore-labyrinth-rooms", dayID: "2026-06-01", at: now)

        XCTAssertEqual(
            ledger.activeDismissedSurfaceIDs(
                for: "2026-06-01",
                now: now.addingTimeInterval(30 * 60),
                ttl: 90 * 60
            ),
            ["lore-labyrinth-rooms"]
        )
        XCTAssertTrue(
            ledger.activeDismissedSurfaceIDs(
                for: "2026-06-01",
                now: now.addingTimeInterval(100 * 60),
                ttl: 90 * 60
            ).isEmpty
        )
    }

    func testRepeatableReferenceCardsUseSnippetIdentity() throws {
        // A fixed ordinary date (no sabbat, shower, or full/new-moon esbat) so the
        // Almanac's festival page doesn't claim a slot and make this nondeterministic.
        let morning = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: localDate(year: 2026, month: 7, day: 7, hour: 9),
            limit: 12
        )
        let lore = try XCTUnwrap(morning.first { $0.type == .lore })
        let wonder = try XCTUnwrap(morning.first { $0.type == .wonderCompass })

        XCTAssertTrue(lore.id.hasPrefix("labyrinth-lore-"))
        XCTAssertTrue(wonder.id.hasPrefix("wonder-compass-"))
        XCTAssertNotEqual(lore.id, "labyrinth-lore-importReference")
        XCTAssertNotEqual(wonder.id, "wonder-compass-importReference")
    }

    func testLabyrinthLoreAvoidsProductAndMechanicsCopy() throws {
        let forbiddenTerms = [
            "enchantify",
            "simulation",
            "mechanic",
            "gameplay",
            "belief investment",
            "belief combat",
            "npc decision",
            "read this file",
            "telegram"
        ]

        for snippet in BookReferenceCatalog.enchantifyLore {
            let searchable = "\(snippet.title) \(snippet.prompt) \(snippet.body) \(snippet.tags.joined(separator: " "))"
                .lowercased()
            for term in forbiddenTerms {
                XCTAssertFalse(searchable.contains(term), "\(snippet.id) contains forbidden lore term: \(term)")
            }
            XCTAssertGreaterThan(snippet.body.count, 320, "\(snippet.id) should be long enough to carry story texture.")
            XCTAssertEqual(snippet.sourceID, "labyrinth-lore")
        }
    }

    func testLabyrinthLoreLoadsThroughContentPacks() throws {
        let packs = BookReferenceCatalog.lorePacks
        let corePack = try XCTUnwrap(packs.first { $0.id == LorePackRegistry.corePackID })

        XCTAssertEqual(corePack.displayName, "Core Labyrinth Lore Pack")
        XCTAssertEqual(corePack.availability, .bundledFree)
        XCTAssertGreaterThan(corePack.snippets.count, 10)
        XCTAssertTrue(corePack.themes.contains("characters"))
        XCTAssertTrue(corePack.themes.contains("rooms"))
    }

    func testStoryScenePacketUsesThreeChoiceGrammar() {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        XCTAssertEqual(packet.choices.map(\.role), [.sliceOfLife, .progressArc, .surprise])
        XCTAssertEqual(packet.choices.map(\.role.title), ["Slice of Life", "Progress Arc", "Something Surprising"])
        XCTAssertEqual(Set(packet.choices.map(\.id)).count, 3)
        XCTAssertTrue(packet.choices.allSatisfy { !$0.hiddenEffect.isEmpty })
    }

    func testStoryScenePacketCommitsACharacterFirstTurn() throws {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        let turn = try XCTUnwrap(packet.turn)
        XCTAssertFalse(turn.statement.isEmpty)
        XCTAssertFalse(turn.character.isEmpty)
        XCTAssertFalse(turn.want.isEmpty)
        // One landing per choice path, all distinct — choices land different
        // facts, not different moods.
        let landings = ["slice-of-life", "progress-arc", "surprise"].compactMap { turn.landings[$0]?.nonEmpty }
        XCTAssertEqual(landings.count, 3)
        XCTAssertEqual(Set(landings).count, 3)
        // The committed landing rides each choice's hidden effect.
        for choice in packet.choices {
            XCTAssertEqual(choice.hiddenEffect, turn.landings[choice.id])
        }
    }

    func testStoryScenePacketLeadIsCharacterNotAtmosphereOrObject() throws {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        XCTAssertEqual(packet.selectedEntities.first?.kind, .character)
        XCTAssertFalse(packet.directorIntent.contains("helps Weather in the Stacks"))
        XCTAssertTrue(packet.directorIntent.contains("wants something specific"))
    }

    func testWeatherSignalAloneDoesNotMakeWeatherThreadTheStoryPremise() throws {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Rain at the window.",
            source: "test",
            forecast: "rain later",
            conditionSymbolName: "cloud.rain"
        )

        let packet = StoryScenePacketBuilder.packet(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 16)
        )

        XCTAssertNotEqual(packet.selectedThreads.first?.id, "weather-in-the-stacks")
        XCTAssertEqual(packet.selectedEntities.first?.kind, .character)
    }

    func testAtmosphericThreadsStayUnderPlayableStoryPageFrame() throws {
        var inputs = BookSourceInputs.empty
        inputs.body = BodySourceSignal(status: "LOW", score: 22, phrase: "A quiet day. Small food and rest count.")
        let bodyEvent = NarrativeEvent(
            id: "body-thread-hot",
            kind: .pageAnswered,
            sourcePageType: .body,
            sourcePageID: "body-page",
            createdAt: localDate(hour: 14),
            summary: "The reader let care count.",
            tags: ["body", "care", "rest"],
            effect: NarrativeEventEffect(threadWeightDeltas: ["body-learns-trust": 8])
        )
        inputs.narrative = NarrativeSourceSnapshotBuilder.snapshot(from: [bodyEvent], beliefWeight: 42)

        let day = BookDay(
            id: "2026-06-01",
            date: localDate(year: 2026, month: 6, day: 1, hour: 0),
            pages: [
                BookPage(
                    id: "quiet-souvenir",
                    type: .souvenir,
                    createdAt: localDate(hour: 13),
                    promptText: "Catch one bright particular.",
                    userInput: "I ate something real and left the cup by the lamp.",
                    tags: ["souvenir", "body", "care", "quiet"]
                )
            ]
        )

        let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: localDate(hour: 16))

        XCTAssertTrue(packet.selectedThreads.contains { $0.id == "body-learns-trust" })
        XCTAssertFalse(packet.title.contains("The Body Learns Trust"))
        XCTAssertFalse(packet.playableThreadTitle.contains("The Body Learns Trust"))

        let surface = NarrativeOSPageSourceAdapter.draftCandidate(for: day, inputs: inputs, now: localDate(hour: 16))
        XCTAssertTrue(surface.payload.metadata["selectedThreadIDs"]?.contains("body-learns-trust") == true)
        XCTAssertTrue(surface.payload.metadata["storyThreadUnderlyingTitles"]?.contains("The Body Learns Trust") == true)
        XCTAssertNotEqual(surface.payload.metadata["storyThreadDisplayTitle"], "The Body Learns Trust")
        XCTAssertFalse(surface.payload.headline.contains("The Body Learns Trust"))
    }

    func testStorySceneChoicesAreCharacterActionsNotSensoryAtmosphere() {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        let choiceText = packet.choices.map { "\($0.title) \($0.prompt)" }.joined(separator: " ").lowercased()
        XCTAssertTrue(choiceText.contains("ask") || choiceText.contains("act"))
        XCTAssertFalse(choiceText.contains("examine the shadow"))
        XCTAssertFalse(choiceText.contains("follow the resonance"))
        XCTAssertFalse(choiceText.contains("hold the tide glass"))
    }

    func testStoryTurnLandingResolvesBothIdConventions() {
        // The regression that disabled the result rail: draft choice ids are
        // hyphen-free, landings are hyphenated.
        let landings = [
            "slice-of-life": "She admits it quietly.",
            "progress-arc": "She says it out loud.",
            "surprise": "It lands sideways."
        ]
        XCTAssertEqual(StoryTurnLanding.resolve(landings, choiceID: "sliceoflife"), "She admits it quietly.")
        XCTAssertEqual(StoryTurnLanding.resolve(landings, choiceID: "progressarc"), "She says it out loud.")
        XCTAssertEqual(StoryTurnLanding.resolve(landings, choiceID: "slice-of-life"), "She admits it quietly.")
        XCTAssertEqual(StoryTurnLanding.resolve(landings, choiceID: "surprise"), "It lands sideways.")
    }

    func testSceneIntentIsConcreteAndInterpersonal() {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )
        let turn = try? XCTUnwrap(packet.turn)
        // The want must be a concrete clause, never the raw life-mission goal.
        XCTAssertNotNil(turn)
        XCTAssertFalse(turn?.want.contains("teach safe, playful enchantments") ?? false)
        // Recipe turns may quote the concrete kept detail, but may not fall
        // back to an abstract yes/no dispute.
        XCTAssertFalse(turn?.want.contains("what happened last time") ?? true)
        XCTAssertNotNil(packet.blueprint)
        XCTAssertFalse(packet.blueprint?.grounding.text.isEmpty ?? true)
        XCTAssertFalse(turn?.obstacle.isEmpty ?? true)
        // The subtitle composes cleanly (no "is in the way" run-on).
        let detail = "\(turn!.character) wants \(turn!.want); \(turn!.obstacle)."
        XCTAssertFalse(detail.contains("is in the way"))
    }

    func testStoryTurnValidatorRejectsRoomDominatedProse() {
        let atmosphere = "The afternoon light shifts across the stacks. The air changes when the sun hits the window frame. A bead of condensation forms on the glass. The dust settles in the still air."
        XCTAssertTrue(StoryTurnValidator.isAtmosphereDominated(atmosphere, characterNames: ["Luna Wispwood", "Penny Blackletter"]))

        let interaction = "Luna leaned toward Penny and asked her, plainly, whether she had taken the key. Penny set down her cup and admitted she had."
        XCTAssertFalse(StoryTurnValidator.isAtmosphereDominated(interaction, characterNames: ["Luna Wispwood", "Penny Blackletter"]))

        XCTAssertTrue(StoryTurnValidator.isNearDuplicate(
            "The afternoon light shifts, slicing across the stacks. You notice the way the air changes.",
            of: "The afternoon light shifts, slicing across the stacks. You notice the way the sun moves."
        ))
    }

    func testStoryTurnValidatorRejectsAtmosphereAcceptsChange() {
        // Negative fixture: the copper-scent atmosphere from the screenshots —
        // texture, no event.
        let atmosphere = "Your ear strains against the narrow gap. The silence presses in. A faint dry click echoes from the upper shelf. The metallic scent of old copper sharpens, clinging to your skin like dried ink."
        let landing = "Stonebrook admits the want quietly and is relieved to be heard."
        XCTAssertFalse(StoryTurnValidator.asserts(atmosphere, landing: landing, character: "Professor Stonebrook"))

        let change = "Professor Stonebrook sets down the cracked teacup and admits he already knew what the shelf was counting."
        XCTAssertTrue(StoryTurnValidator.asserts(change, landing: landing, character: "Professor Stonebrook"))

        // The fallback states the change plainly when prose won't.
        let landed = StoryTurnValidator.landed(atmosphere, landing: landing)
        XCTAssertTrue(landed.contains(landing))
    }

    func testStoryScenePacketSelectsWeightedThreadsAndEntitiesFromPacks() throws {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        XCTAssertEqual(packet.packID, NarrativePackRegistry.corePackID)
        XCTAssertFalse(packet.selectedEntities.isEmpty)
        XCTAssertFalse(packet.selectedThreads.isEmpty)
        XCTAssertTrue(packet.selectedThreads.contains { $0.id == "music-as-shelter" })
        XCTAssertTrue(packet.realSignals.contains { $0.contains("Spotify") || $0.contains("headphones") })
    }

    func testStoryScenePacketRestsRecentlySpotlitStoryCharactersAndThreads() throws {
        var inputs = richInputs()
        let recentStory = NarrativeEvent(
            id: "recent-story-inkrest-weather",
            kind: .pageAnswered,
            sourcePageType: .narrativeOS,
            sourcePageID: "story-1",
            createdAt: localDate(hour: 15),
            summary: "Inkrest read the weather in the stacks.",
            tags: [
                "narrative-os",
                "entity:dr-inkrest",
                "entity:weather-page",
                "thread:weather-in-the-stacks"
            ],
            effect: NarrativeEventEffect(
                entityWeightDeltas: ["dr-inkrest": 3, "weather-page": 2],
                threadWeightDeltas: ["weather-in-the-stacks": 3]
            )
        )
        inputs.narrative = NarrativeSourceSnapshotBuilder.snapshot(
            from: [recentStory],
            beliefWeight: 51
        )

        let packet = StoryScenePacketBuilder.packet(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 16)
        )

        XCTAssertEqual(inputs.narrative?.recentlySpotlitEntityIDs.first, "dr-inkrest")
        XCTAssertEqual(inputs.narrative?.recentlySpotlitThreadIDs.first, "weather-in-the-stacks")
        XCTAssertNotEqual(packet.selectedEntities.first?.id, "dr-inkrest")
        XCTAssertNotEqual(packet.selectedThreads.first?.id, "weather-in-the-stacks")
    }

    func testCoreNarrativePackIncludesRelationshipGraphEdges() throws {
        let corePack = try XCTUnwrap(NarrativePackRegistry.enabledPacks.first { $0.id == NarrativePackRegistry.corePackID })

        XCTAssertFalse(corePack.relationships.isEmpty)
        XCTAssertTrue(corePack.relationships.contains { $0.id == "weather-bleeds-book" })
        XCTAssertTrue(corePack.relationships.contains { $0.id == "penny-files-book" })
    }

    func testCoreNarrativePackIncludesPlayableCozyThreads() throws {
        let threadIDs = Set(NarrativePackRegistry.threads.map(\.id))

        XCTAssertTrue(threadIDs.contains("great-hall-small-announcements"))
        XCTAssertTrue(threadIDs.contains("companionable-silence"))
        XCTAssertTrue(threadIDs.contains("pantry-keeps-receipts"))
        XCTAssertTrue(threadIDs.contains("shelf-of-misfiled-days"))
        XCTAssertTrue(threadIDs.contains("rain-room-opens"))
        XCTAssertTrue(threadIDs.contains("lamp-repair-committee"))
        XCTAssertTrue(threadIDs.contains("threshold-ledger"))
    }

    func testCoreNarrativePackIncludesDramaticStoryThreads() throws {
        let threadIDs = Set(NarrativePackRegistry.threads.map(\.id))

        XCTAssertTrue(threadIDs.contains("wickers-case-against-comfort"))
        XCTAssertTrue(threadIDs.contains("pennys-evidence-war"))
        XCTAssertTrue(threadIDs.contains("books-editorial-strike"))
        XCTAssertTrue(threadIDs.contains("courtesy-debt"))
        XCTAssertTrue(threadIDs.contains("ceremony-register-rival"))
        XCTAssertTrue(threadIDs.contains("shelf-accuses-wrong-day"))
        XCTAssertTrue(threadIDs.contains("lamp-heard-too-much"))
    }

    func testOrganicRitualsBoostMatchingAuthoredThreads() throws {
        var inputs = BookSourceInputs.empty
        inputs.storyRituals = ["small-ceremony-register": 4]
        inputs.storySettingAffinities = ["location-great-hall": 8]

        let packet = StoryScenePacketBuilder.packet(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 16)
        )

        XCTAssertTrue(packet.selectedThreads.contains { $0.id == "great-hall-small-announcements" })
        XCTAssertEqual(packet.playableThreadTitle, "The Great Hall of Small Announcements")
    }

    func testRepeatedUnknownMotifBirthsOrganicThreadCandidate() throws {
        var inputs = BookSourceInputs.empty
        inputs.storyMotifs = ["blue-jay": 5]

        let packet = StoryScenePacketBuilder.packet(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 16)
        )

        XCTAssertTrue(packet.selectedThreads.contains { $0.id == "organic-motif-blue-jay" })
        XCTAssertTrue(packet.selectedThreads.contains { $0.packID == OrganicStoryThreadSynthesizer.packID })
        XCTAssertEqual(packet.selectedThreads.first { $0.id == "organic-motif-blue-jay" }?.title, "Blue Jay Keeps Returning")
    }

    func testOrganicThreadsCanAscendIntoStoryArcs() throws {
        let now = localDate(hour: 16)
        let events = (0..<3).map { index in
            NarrativeEvent(
                id: "organic-blue-jay-\(index)",
                kind: .choiceSelected,
                sourcePageType: .narrativeOS,
                sourcePageID: "story-\(index)",
                createdAt: now.addingTimeInterval(Double(-index) * 3600),
                summary: "The blue jay returned.",
                tags: ["organic-thread", "motif", "blue-jay"],
                effect: NarrativeEventEffect(threadWeightDeltas: ["organic-motif-blue-jay": 2])
            )
        }

        let result = ArcKeeper.evaluate(current: nil, events: events, lastCompletedThreadID: nil, now: now)

        XCTAssertEqual(result.arc?.threadID, "organic-motif-blue-jay")
        XCTAssertEqual(result.arc?.title, "Blue Jay Keeps Returning")
        XCTAssertEqual(result.arc?.phase, .rising)
    }

    func testCoreNarrativePackIncludesAcademyRosterAndThreads() throws {
        let corePack = try XCTUnwrap(NarrativePackRegistry.enabledPacks.first { $0.id == NarrativePackRegistry.corePackID })

        XCTAssertTrue(corePack.entities.contains { $0.id == "headmistress-thorne" })
        XCTAssertTrue(corePack.entities.contains { $0.id == "zara-finch" })
        XCTAssertTrue(corePack.entities.contains { $0.id == "wicker-eddies" })
        XCTAssertTrue(corePack.entities.contains { $0.id == "gwendolyn-mythwright" })
        XCTAssertTrue(corePack.entities.contains { $0.id == "dr-inkrest" })
        XCTAssertTrue(corePack.entities.contains { $0.id == "dr-vellum" })
        XCTAssertTrue(corePack.threads.contains { $0.id == "duskthorn-investigation" })
        XCTAssertTrue(corePack.threads.contains { $0.id == "margin-glass-letters" })
        XCTAssertTrue(corePack.threads.contains { $0.id == "inkrest-difficult-pages" })
        XCTAssertTrue(corePack.threads.contains { $0.id == "elowen-refectory-experiments" })
        XCTAssertTrue(corePack.relationships.contains { $0.id == "wicker-tests-belief" })
        XCTAssertTrue(corePack.relationships.contains { $0.id == "gwendolyn-files-letters" })
        XCTAssertTrue(corePack.relationships.contains { $0.id == "inkrest-vellum-compare-charts" })
    }

    func testCoreNPCsCarryUnwrittenInterests() throws {
        let corePack = try XCTUnwrap(NarrativePackRegistry.enabledPacks.first { $0.id == NarrativePackRegistry.corePackID })
        let characterEntities = corePack.entities.filter { $0.kind == .character }

        XCTAssertFalse(characterEntities.isEmpty)
        XCTAssertTrue(characterEntities.allSatisfy {
            ($0.unwrittenInterest ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        })
        XCTAssertTrue(corePack.entities.first { $0.id == "dr-inkrest" }?.unwrittenInterest?.contains("Consciousness") == true)
        XCTAssertTrue(corePack.entities.first { $0.id == "penny-blackletter" }?.unwrittenInterest?.contains("ethical marketing") == true)
    }

    func testCoreNarrativeCharactersAllHaveChapters() throws {
        let corePack = try XCTUnwrap(NarrativePackRegistry.enabledPacks.first { $0.id == NarrativePackRegistry.corePackID })
        let characterEntities = corePack.entities.filter { $0.kind == .character }
        let missingChapters = characterEntities.filter {
            ($0.chapter ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        XCTAssertTrue(missingChapters.isEmpty, "Missing chapters: \(missingChapters.map(\.name).joined(separator: ", "))")
        XCTAssertEqual(corePack.entities.first { $0.id == "dr-inkrest" }?.chapter, "Riddlewind")
        XCTAssertEqual(corePack.entities.first { $0.id == "dr-vellum" }?.chapter, "Mossbloom")
        XCTAssertEqual(corePack.entities.first { $0.id == "wicker-eddies" }?.chapter, "Duskthorn")
    }

    func testCharacterIllustrationsAllHaveChapters() {
        let missingChapters = BookReferenceCatalog.characterIllustrations.filter {
            ($0.chapter ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        XCTAssertTrue(missingChapters.isEmpty, "Missing chapters: \(missingChapters.map(\.characterName).joined(separator: ", "))")
    }

    func testDuskthornHasChapterPreviewProfile() {
        let profile = BookReferenceCatalog.characterIllustrations.first {
            $0.chapter == "Duskthorn" && $0.core.contains("Enchantment Guardian")
        }

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.characterName, "Vesper Thorne")
        XCTAssertTrue(profile?.tags.contains("duskthorn") == true)
    }

    func testLabyrinthIllustrationsOnlyUseBundledCharacterAssets() {
        let missingAssetPlates = BookReferenceCatalog.labyrinthIllustrations.filter {
            !BookReferenceCatalog.bundledCharacterIllustrationAssetNames.contains($0.assetName)
        }

        XCTAssertFalse(BookReferenceCatalog.labyrinthIllustrations.isEmpty)
        XCTAssertTrue(missingAssetPlates.isEmpty, "Missing bundled assets: \(missingAssetPlates.map(\.assetName).joined(separator: ", "))")
    }

    func testSupportFacultyPackIncludesInkrestAndVellumCharts() throws {
        let corePack = try XCTUnwrap(SupportFacultyPackRegistry.enabledPacks.first { $0.id == SupportFacultyPackRegistry.corePackID })

        let inkrest = try XCTUnwrap(corePack.charts.first { $0.id == "inkrest-difficult-page-chart" })
        let vellum = try XCTUnwrap(corePack.charts.first { $0.id == "vellum-body-marginalia-chart" })

        XCTAssertEqual(inkrest.facultyEntityID, "dr-inkrest")
        XCTAssertEqual(inkrest.kind, .difficultPage)
        XCTAssertTrue(inkrest.forbiddenUses.contains("diagnosis"))
        XCTAssertTrue(inkrest.safetyLine.contains("feeling is not a verdict"))

        XCTAssertEqual(vellum.facultyEntityID, "dr-vellum")
        XCTAssertEqual(vellum.kind, .bodyMarginalia)
        XCTAssertTrue(vellum.forbiddenUses.contains("food shame"))
        XCTAssertTrue(vellum.reads.contains("HealthKit body signals"))
    }

    func testSupportFacultyChartsCanBeResolvedFromStoryTags() throws {
        let charts = SupportFacultyPackRegistry.charts(matching: ["body", "therapy-chart", "care"])

        XCTAssertTrue(charts.contains { $0.id == "inkrest-difficult-page-chart" })
        XCTAssertTrue(charts.contains { $0.id == "vellum-body-marginalia-chart" })
    }

    func testStoryScenePacketCarriesSelectedRelationships() {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        XCTAssertFalse(packet.selectedRelationships.isEmpty)
        XCTAssertTrue(packet.relationshipPressures.contains { $0.contains("->") })
    }

    func testNarrativeSnapshotBiasesNextStoryPacketFromKeptEvents() {
        let photoEvent = NarrativeEventResolver.event(forKept: BookPage(
            id: "illuminated-kept",
            type: .illuminatedPhoto,
            createdAt: localDate(hour: 13),
            promptText: "Found in the Margins",
            userInput: "The Book kept the page: the cup glittered.",
            tags: ["photo", "marginalia"]
        ))
        let weatherEvent = NarrativeEventResolver.event(forKept: BookPage(
            id: "weather-kept",
            type: .weather,
            createdAt: localDate(hour: 14),
            promptText: "Weather Page",
            userInput: "The sky stayed bright.",
            tags: ["weather"]
        ))
        var inputs = richInputs()
        inputs.narrative = NarrativeSourceSnapshotBuilder.snapshot(
            from: [photoEvent, weatherEvent],
            beliefWeight: 51
        )

        let packet = StoryScenePacketBuilder.packet(
            for: emptyDay(),
            inputs: inputs,
            now: localDate(hour: 16)
        )

        XCTAssertTrue(packet.selectedEntities.contains { $0.id == "penny-blackletter" || $0.id == "weather-page" })
        XCTAssertTrue(packet.selectedThreads.contains { $0.id == "weather-in-the-stacks" || $0.id == "ordinary-magic" })
        XCTAssertTrue(packet.selectedRelationships.contains { $0.id == "penny-files-book" || $0.id == "weather-bleeds-book" })
    }

    func testStoryPageSurfaceCarriesScenePacketMetadata() throws {
        var inputs = richInputs()
        let draft = NarrativeOSPageSourceAdapter.draftCandidate(
            for: dayWithMusicSouvenir(),
            inputs: inputs,
            now: localDate(hour: 16)
        )
        var metadata = draft.payload.metadata
        metadata["storyScene"] = "The headphones entered the margins as a minor talisman."
        metadata["storyResultSliceOfLife"] = "The ordinary detail gained weight."
        metadata["storyResultProgressArc"] = "The current thread advanced one line."
        metadata["storyResultSurprise"] = "A related side door opened."
        inputs.preparedStoryPageSurface = SurfacePage(
            id: draft.id,
            type: draft.type,
            sourceID: draft.sourceID,
            intent: draft.intent,
            renderStyle: draft.renderStyle,
            score: draft.score,
            reason: draft.reason,
            prompt: draft.prompt,
            detail: draft.detail,
            payload: BookPagePayload(
                headline: draft.payload.headline,
                body: metadata["storyScene"] ?? draft.payload.body,
                metadata: metadata
            )
        )

        let pages = BookCurator.surfacedPages(
            for: dayWithMusicSouvenir(),
            inputs: inputs,
            now: localDate(hour: 16),
            limit: 24
        )

        let storyPage = try XCTUnwrap(pages.first { $0.type == .narrativeOS })

        XCTAssertEqual(storyPage.payload.metadata["choiceRoles"], "Slice of Life | Progress Arc | Something Surprising")
        XCTAssertNotNil(storyPage.payload.metadata["packetID"])
        XCTAssertNotNil(storyPage.payload.metadata["selectedThreads"])
        XCTAssertNotNil(storyPage.payload.metadata["selectedEntities"])
        XCTAssertNotNil(storyPage.payload.metadata["selectedRelationships"])
        XCTAssertNotNil(storyPage.payload.metadata["storyScene"])
    }

    func testBeliefInvestedStoryPageSurfacesAsPreviewBeforeGeneration() throws {
        var inputs = richInputs()
        inputs.preparedStoryPageSurface = nil
        let profiles = BookPageSourceRegistry.beliefProfiles(ledger: ["narrative-os": 80])
        let preferences = CuratorSurfacePreferences(
            pageBeliefProfiles: Dictionary(uniqueKeysWithValues: profiles.map { ($0.sourceID, $0) })
        )

        let pages = BookCurator.surfacedPages(
            for: dayWithMusicSouvenir(),
            inputs: inputs,
            now: localDate(hour: 16),
            limit: 3,
            preferences: preferences
        )
        let storyPage = try XCTUnwrap(pages.first { $0.type == .narrativeOS })

        XCTAssertEqual(storyPage.sourceID, "narrative-os")
        XCTAssertNil(storyPage.payload.metadata["storyScene"])
        XCTAssertTrue(SurfaceReadinessState(surface: storyPage).needsLocalBrainToOpen)
    }

    func testStoryPageMechanicPlannerEventuallySchedulesMechanicWhenEligible() throws {
        let inputs = richInputs()
        let day = dayWithMusicSouvenir()
        let mandate = try XCTUnwrap((0..<80).compactMap { slot -> StoryPageMechanicMandate? in
            let now = localDate(year: 2026, month: 6, day: 2 + (slot / 6), hour: (slot % 6) * 4)
            let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
            let mandate = StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now)
            return mandate.kind == .none ? nil : mandate
        }.first)

        XCTAssertNotEqual(mandate.kind, .none)
        XCTAssertNotNil(mandate.choiceID)
    }

    func testStoryPageMechanicPlannerOffersBeliefDiceJustUnderHalfTheTime() {
        let day = dayWithMusicSouvenir()
        let inputs = richInputs()

        let mechanics = (0..<120).map { slot in
            let now = localDate(year: 2026, month: 6, day: 2 + (slot / 6), hour: (slot % 6) * 4)
            let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
            return StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now).kind
        }
        let dice = mechanics.filter { $0 == .beliefDice }.count
        let compass = mechanics.filter { $0 == .compassRun }.count
        let enchantments = mechanics.filter { $0 == .enchantment }.count

        XCTAssertGreaterThanOrEqual(dice, 48)
        XCTAssertLessThan(dice, 60)
        XCTAssertGreaterThan(dice, compass)
        XCTAssertGreaterThan(dice, enchantments)
    }

    func testRecentExternalStoryMechanicSuppressesAnotherExternalButStillAllowsBeliefDice() throws {
        let now = localDate(year: 2026, month: 6, day: 7, hour: 12)
        let recentExternal = BookPage(
            id: "recent-compass-return",
            type: .narrativeOS,
            createdAt: now.addingTimeInterval(-12 * 3600),
            promptText: "Story Page Return",
            userInput: "A Compass Run returned to the thread.",
            tags: ["story-mechanic-return", "story-mechanic", "story-mechanic:compass-run", "compass-run"]
        )
        let newerPlain = BookPage(
            id: "newer-plain-story",
            type: .narrativeOS,
            createdAt: now.addingTimeInterval(-3600),
            promptText: "The Story Page is stirring.",
            userInput: "Chosen path: Slice of Life",
            tags: ["narrative-os", "choice:sliceoflife"]
        )
        var inputs = richInputs()
        inputs.days = [
            BookDay(
                id: "2026-06-07",
                date: localDate(year: 2026, month: 6, day: 7, hour: 0),
                pages: [recentExternal, newerPlain]
            )
        ]

        let mandates = (0..<160).map { index -> StoryPageMechanicMandateKind in
            let day = BookDay(id: "mechanic-day-\(index)", date: now, pages: [])
            let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
            return StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now).kind
        }

        XCTAssertTrue(mandates.contains(.beliefDice))
        XCTAssertFalse(mandates.contains(.compassRun))
        XCTAssertFalse(mandates.contains(.enchantment))
    }

    func testStoryPageMechanicPlannerHonorsRecentMechanicCooldown() throws {
        let recent = BookPage(
            id: "recent-story-mechanic",
            type: .narrativeOS,
            createdAt: localDate(year: 2026, month: 6, day: 2, hour: 8),
            promptText: "The Story Page returned.",
            userInput: "A Compass Run fed back into the thread.",
            tags: ["story-mechanic", "story-mechanic:compass-run"]
        )
        let inputs = richInputs()
        let day = BookDay(id: "2026-06-02", date: localDate(year: 2026, month: 6, day: 2, hour: 9), pages: [recent])
        let now = localDate(year: 2026, month: 6, day: 2, hour: 12)
        let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)

        let mandate = StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now)

        XCTAssertEqual(mandate.kind, .none)
    }

    func testClashBlueprintMandatesBeliefDice() throws {
        let inputs = richInputs()
        let day = BookDay(id: "clash-mandate-day", date: localDate(hour: 16), pages: [])
        let now = localDate(hour: 16)
        var packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
        var blueprint = try XCTUnwrap(packet.blueprint)
        blueprint.recipeID = "grey-edit"
        packet.blueprint = blueprint
        packet.turn = blueprint.turn

        let mandate = StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now)

        XCTAssertEqual(mandate.kind, .beliefDice)
        XCTAssertNotNil(mandate.choiceID)
    }

    func testStoryPageDraftCarriesMechanicMandateMetadata() {
        let surface = NarrativeOSPageSourceAdapter.draftCandidate(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )

        XCTAssertNotNil(surface.payload.metadata["storyMechanicMandateKind"])
        XCTAssertNotNil(surface.payload.metadata["storyMechanicMandateReason"])
    }

    func testWeatherPageKeptCreatesNarrativeEventForWeatherThread() {
        let page = BookPage(
            id: "weather-kept",
            type: .weather,
            createdAt: localDate(hour: 14),
            promptText: "The Weather Page has opened.",
            userInput: "The sky stayed clear and silver.",
            tags: ["weather"]
        )

        let event = NarrativeEventResolver.event(forKept: page)

        XCTAssertEqual(event.kind, .pageAnswered)
        XCTAssertEqual(event.effect.beliefDelta, 1)
        XCTAssertGreaterThan(event.effect.entityWeightDeltas["weather-page"] ?? 0, 0)
        XCTAssertGreaterThan(event.effect.threadWeightDeltas["weather-in-the-stacks"] ?? 0, 0)
        XCTAssertGreaterThan(event.effect.relationshipWeightDeltas["weather-bleeds-book"] ?? 0, 0)
    }

    func testAcademyClassKeptWeightsProfessorSubjectAndLesson() {
        let page = BookPage(
            id: "glint-class-kept",
            type: .academyClass,
            createdAt: localDate(hour: 9),
            promptText: "Class: The Art of the Glint",
            userInput: "Chosen path: Try the Lesson",
            tags: [
                "academy",
                "class",
                "art-of-the-glint",
                "class:art-of-the-glint",
                "subject:notice-north",
                "entity:lydia-boggle",
                "lesson:glint-specificity-001"
            ]
        )

        let event = NarrativeEventResolver.event(forKept: page)

        XCTAssertGreaterThan(event.effect.entityWeightDeltas["lydia-boggle"] ?? 0, 0)
        XCTAssertGreaterThan(event.effect.threadWeightDeltas["notice-north"] ?? 0, 0)
        XCTAssertGreaterThan(event.effect.threadWeightDeltas["art-of-the-glint"] ?? 0, 0)
        XCTAssertGreaterThan(event.effect.threadWeightDeltas["glint-specificity-001"] ?? 0, 0)
    }

    func testIlluminatedPhotoKeptCreatesPennyEventAndTalismanHint() {
        let page = BookPage(
            id: "photo-kept",
            type: .illuminatedPhoto,
            createdAt: localDate(hour: 15),
            promptText: "Found in the Margins",
            userInput: "The Book kept the page: the lamp won.",
            tags: ["photo", "marginalia"]
        )

        let event = NarrativeEventResolver.event(forKept: page)

        XCTAssertGreaterThan(event.effect.entityWeightDeltas["penny-blackletter"] ?? 0, 0)
        XCTAssertGreaterThan(event.effect.relationshipWeightDeltas["penny-files-book"] ?? 0, 0)
        XCTAssertNotNil(event.effect.createdEntityHint)
    }

    func testIlluminatedPhotoComposerMovesMarginaliaAcrossSeeds() throws {
        let first = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 101
        )
        let second = IlluminatedPageComposer.compose(
            analysis: .academyFallback,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: 9_901
        )

        let firstSlots = Dictionary(uniqueKeysWithValues: first.compositionPlan.textSlots.map { ($0.slotId, $0) })
        let secondSlots = Dictionary(uniqueKeysWithValues: second.compositionPlan.textSlots.map { ($0.slotId, $0) })
        let movedRequiredSlots = ["field-note", "observation-list", "closing-line", "frame-line", "compass-reminder", "souvenir-line"].filter { slotID in
            guard let a = firstSlots[slotID], let b = secondSlots[slotID] else { return false }
            return distance(a.position, b.position) > 140
                || abs(a.size.width - b.size.width) > 20
                || abs(a.size.height - b.size.height) > 20
        }

        XCTAssertGreaterThanOrEqual(movedRequiredSlots.count, 4)
    }

    func testIlluminatedPhotoComposerKeepsDifferentSeedsSerializable() {
        let drafts = (0..<8).map { seed in
            IlluminatedPageComposer.compose(
                analysis: .goodCompanyFallback,
                sourceAssetName: "IlluminatedPhotoSource",
                seed: seed * 1_337 + 42
            )
        }

        let encoded = drafts.compactMap { try? JSONEncoder().encode($0.compositionPlan) }

        XCTAssertEqual(encoded.count, drafts.count)
        XCTAssertEqual(Set(drafts.map(\.compositionPlan.randomSeed)).count, drafts.count)
        XCTAssertTrue(drafts.allSatisfy { $0.compositionPlan.textSlots.count >= 9 })
    }

    func testStoryChoiceCreatesNarrativeEventWithChoiceEffect() throws {
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )
        let choice = try XCTUnwrap(packet.choices.first { $0.role == .progressArc })

        let event = NarrativeEventResolver.event(for: choice, packet: packet, at: localDate(hour: 16))

        XCTAssertEqual(event.kind, .choiceSelected)
        XCTAssertEqual(event.sourcePageType, .narrativeOS)
        XCTAssertEqual(event.effect.beliefDelta, choice.beliefDelta)
        XCTAssertFalse(event.effect.threadWeightDeltas.isEmpty)
    }

    func testKeptStoryPageCreatesChoiceEventsForEachTurn() {
        let page = BookPage(
            id: "story-kept",
            type: .narrativeOS,
            createdAt: localDate(hour: 17),
            promptText: "The Story Page is stirring.",
            userInput: """
            Turn 1

            The weather opened a small silver door.

            Chosen path: Slice of Life

            The ordinary detail gained weight.

            ---

            Turn 2

            The thread found the headphones again.

            Chosen path: Progress Arc

            The current thread advanced one line.

            ---

            Turn 3

            Penny found an extra note under the page.

            Chosen path: Something Surprising

            A related side door opened.
            """,
            tags: ["narrative-os", "weather", "music", "choice:sliceoflife", "choice:progressarc", "choice:surprise"]
        )

        let events = NarrativeEventResolver.events(forKept: page)

        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events.first?.kind, .pageAnswered)
        XCTAssertEqual(events.dropFirst().map(\.kind), [.choiceSelected, .choiceSelected, .choiceSelected])
        XCTAssertTrue(events.contains { $0.id.contains("sliceoflife") })
        XCTAssertTrue(events.contains { $0.id.contains("progressarc") })
        XCTAssertTrue(events.contains { $0.id.contains("surprise") })
        XCTAssertTrue(events.dropFirst().contains { ($0.effect.threadWeightDeltas["music-as-shelter"] ?? 0) > 0 })
    }

    func testNarrativeStoryFieldProjectionAccumulatesEvents() throws {
        let photoEvent = NarrativeEventResolver.event(forKept: BookPage(
            id: "photo-event",
            type: .illuminatedPhoto,
            createdAt: localDate(hour: 12),
            promptText: "Found in the Margins",
            userInput: "The Book kept the page: the chair waited.",
            tags: ["photo"]
        ))
        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 16)
        )
        let surprise = try XCTUnwrap(packet.choices.first { $0.role == .surprise })
        let choiceEvent = NarrativeEventResolver.event(for: surprise, packet: packet, at: localDate(hour: 16))

        let projection = NarrativeStoryFieldProjector.projection(events: [photoEvent, choiceEvent], baseBelief: 30)

        XCTAssertEqual(projection.belief, 32)
        XCTAssertTrue(projection.topEntityIDs.contains("penny-blackletter"))
        XCTAssertTrue(projection.topThreadIDs.contains("ordinary-magic"))
        XCTAssertTrue(projection.topRelationshipIDs.contains("penny-files-book"))
    }

    func testAboutYouSkipsAnsweredQuestionsFromEnabledPacks() throws {
        let day = emptyDay()
        let firstPass = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(selfFacts: []),
            now: localDate(hour: 10),
            limit: 12
        )
        let firstQuestion = try XCTUnwrap(firstPass.first { $0.type == .aboutYou })
        let questionID = try XCTUnwrap(firstQuestion.payload.metadata["questionID"])
        let packID = try XCTUnwrap(firstQuestion.payload.metadata["packID"])

        let answered = SelfFact(
            id: "\(packID):\(questionID)",
            questionID: questionID,
            question: firstQuestion.prompt,
            answer: "Avery",
            bookTranslation: "The Book knows this now.",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["identity"],
            createdAt: localDate(hour: 10),
            updatedAt: localDate(hour: 10)
        )
        let immediateSecondPass = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(selfFacts: [answered]),
            now: localDate(hour: 10),
            limit: 12
        )
        let laterSecondPass = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(selfFacts: [answered]),
            now: localDate(hour: 14),
            limit: 12
        )

        XCTAssertFalse(immediateSecondPass.contains { $0.type == .aboutYou })
        XCTAssertFalse(laterSecondPass.contains { $0.id == firstQuestion.id })
        XCTAssertTrue(laterSecondPass.contains { $0.type == .aboutYou })
    }

    func testBraidPageOnlySurfacesAtNightWithCapturedFragments() {
        let dayDate = localDate(year: 2026, month: 6, day: 1, hour: 0)
        let day = BookDay(
            id: "2026-06-01",
            date: dayDate,
            pages: [
                BookPage(
                    id: "souvenir-1",
                    type: .souvenir,
                    createdAt: localDate(year: 2026, month: 6, day: 1, hour: 12),
                    promptText: "Catch one bright particular.",
                    userInput: "The coffee smelled like toasted sugar.",
                    tags: ["souvenir"]
                )
            ]
        )

        var inputs = richInputs()
        inputs.days = [day]
        let afternoon = BookCurator.surfacedPages(
            for: day,
            inputs: inputs,
            now: localDate(hour: 15),
            limit: 8
        )
        let night = BookCurator.surfacedPages(
            for: day,
            inputs: inputs,
            now: localDate(hour: 21),
            limit: 12
        )

        XCTAssertFalse(afternoon.contains { $0.type == .bookOfYou })
        XCTAssertTrue(night.contains { $0.type == .bookOfYou })
    }

    func testBookOfYouIsGuaranteedAfterAutoBraidTime() {
        let pages = BookCurator.surfacedPages(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: localDate(hour: 21, minute: 31),
            limit: 3
        )

        XCTAssertEqual(pages.count, 3)
        XCTAssertTrue(pages.contains { $0.type == .bookOfYou })
    }

    func testDistressBiasesGentleRestFirst() {
        let dayDate = localDate(year: 2026, month: 6, day: 1, hour: 0)
        let day = BookDay(
            id: "2026-06-01",
            date: dayDate,
            pages: [
                BookPage(
                    id: "hard-1",
                    type: .souvenir,
                    createdAt: localDate(year: 2026, month: 6, day: 1, hour: 8),
                    promptText: "One sentence.",
                    userInput: "A hard low morning.",
                    tags: ["low"]
                )
            ]
        )

        let pages = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(hour: 10),
            limit: 3
        )

        XCTAssertEqual(pages.first?.type, .rest)
    }

    func testPageBeliefRaisesEligiblePageInCuratorRanking() throws {
        let diary = SurfacePage(
            id: "diary-test",
            type: .diary,
            sourceID: "diary-page",
            intent: .capture,
            renderStyle: .promptCard,
            score: 60,
            reason: "Diary is nearby.",
            prompt: "Diary",
            detail: "Diary",
            payload: BookPagePayload(headline: "Diary", body: "Diary")
        )
        let lore = SurfacePage(
            id: "lore-test",
            type: .lore,
            sourceID: "labyrinth-lore",
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 62,
            reason: "Lore is nearby.",
            prompt: "Lore",
            detail: "Lore",
            payload: BookPagePayload(headline: "Lore", body: "Lore")
        )
        let profiles = BookPageSourceRegistry.beliefProfiles(ledger: ["diary-page": 50])
        let preferences = CuratorSurfacePreferences(
            pageBeliefProfiles: Dictionary(uniqueKeysWithValues: profiles.map { ($0.sourceID, $0) })
        )

        let ranked = BookCurator.rankedPages(
            from: [lore, diary],
            limit: 2,
            preferences: preferences
        )

        XCTAssertEqual(ranked.first?.page.sourceID, "diary-page")
    }

    func testAutomagicPageKeepsFloorWhenBeliefIsLow() {
        let fuel = SurfacePage(
            id: "fuel-test",
            type: .fuel,
            sourceID: "fuel-log",
            intent: .capture,
            renderStyle: .promptCard,
            score: 52,
            reason: "Fuel window.",
            prompt: "Fuel",
            detail: "Fuel",
            payload: BookPagePayload(headline: "Fuel", body: "Fuel")
        )
        let profiles = BookPageSourceRegistry.beliefProfiles(ledger: ["fuel-log": -36])
        let preferences = CuratorSurfacePreferences(
            pageBeliefProfiles: Dictionary(uniqueKeysWithValues: profiles.map { ($0.sourceID, $0) })
        )

        XCTAssertGreaterThanOrEqual(preferences.adjustedScore(for: fuel), 68)
    }

    func testManualLorePageRotatesWithinRelevantPool() throws {
        let day = emptyDay()
        let context = CuratorContext.make(for: day)
        let first = BookPageSourceAdapters.manualSurface(
            for: .lore,
            day: day,
            context: context,
            inputs: richInputs(),
            now: localDate(hour: 10, minute: 0)
        )
        let second = BookPageSourceAdapters.manualSurface(
            for: .lore,
            day: day,
            context: context,
            inputs: richInputs(),
            now: localDate(hour: 10, minute: 1)
        )

        let firstSnippetID = try XCTUnwrap(first.payload.metadata["snippetID"])
        let secondSnippetID = try XCTUnwrap(second.payload.metadata["snippetID"])
        XCTAssertNotEqual(firstSnippetID, secondSnippetID)
    }

    func testCuratorLorePageRotatesAcrossSurfaceSlots() throws {
        let day = emptyDay()
        // Fixed ordinary date so Almanac festival pages don't claim a slot.
        let morning = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(year: 2026, month: 7, day: 7, hour: 10, minute: 0),
            limit: 12
        )
        let later = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(year: 2026, month: 7, day: 7, hour: 10, minute: 40),
            limit: 12
        )

        let morningLore = try XCTUnwrap(morning.first { $0.type == .lore }?.payload.metadata["snippetID"])
        let laterLore = try XCTUnwrap(later.first { $0.type == .lore }?.payload.metadata["snippetID"])
        XCTAssertNotEqual(morningLore, laterLore)
    }

    private func emptyDay() -> BookDay {
        BookDay(id: "2026-06-01", date: localDate(year: 2026, month: 6, day: 1, hour: 0), pages: [])
    }

    private func dayWithMusicSouvenir() -> BookDay {
        BookDay(
            id: "2026-06-01",
            date: localDate(year: 2026, month: 6, day: 1, hour: 0),
            pages: [
                BookPage(
                    id: "music-souvenir",
                    type: .souvenir,
                    createdAt: localDate(year: 2026, month: 6, day: 1, hour: 12),
                    promptText: "Catch one bright particular.",
                    userInput: "The sound of Spotify is bopping me along through the headphones.",
                    tags: ["souvenir", "music"]
                )
            ]
        )
    }

    private func dayWithKeptPageCount(_ count: Int) -> BookDay {
        BookDay(
            id: "2026-05-31",
            date: localDate(year: 2026, month: 5, day: 31, hour: 0),
            pages: (0..<count).map { index in
                BookPage(
                    id: "kept-\(index)",
                    type: .souvenir,
                    createdAt: localDate(year: 2026, month: 5, day: 31, hour: min(index % 24, 23)),
                    promptText: "Catch one bright particular.",
                    userInput: "Kept page \(index).",
                    tags: ["souvenir"]
                )
            }
        )
    }

    private func richInputs(selfFacts: [SelfFact] = []) -> BookSourceInputs {
        BookSourceInputs(
            body: BodySourceSignal(
                status: "LOW",
                score: 24,
                phrase: "The lamps are low in the stacks. This is a day for small thresholds."
            ),
            weather: WeatherSourceSignal(
                phrase: "Now: 64 F. Forecast: rain later.",
                source: "Open-Meteo",
                currentTemperature: "64 F",
                forecast: "rain later",
                conditionSymbolName: "cloud.rain"
            ),
            enchantedWeather: EnchantedWeatherSignal(
                summary: "64 F, rain later",
                enchantified: "Rain is tapping at the margins.",
                selector: "test-weather",
                symbolName: "cloud.rain"
            ),
            narrative: NarrativeSourceSnapshot(activeThreadCount: 2, relationshipCount: 1, beliefWeight: 42),
            selfFacts: selfFacts,
            selectedWonderCompass: nil,
            selectedWonderCompassSelector: nil
        )
    }

    func testIllustrationCopyIsWrittenByTheBookInsteadOfExposingDossierMetadata() {
        // A synthetic slug so this exercises the generated dossier path, not a
        // bespoke CastDossier entry — this test guards the generator's voice and
        // its refusal to leak production metadata. The canonical bespoke prose is
        // covered by testEverySurfacingCharacterPlateUsesBespokeDossier.
        let profile = CharacterIllustrationProfile(
            id: "generator-probe-character",
            characterName: "Dr. Elowen Vellum",
            slug: "generator-probe-character",
            status: "canonical",
            chapter: nil,
            core: "Precise in her care; sharp kind eyes",
            signature: "a silver bookmark-caliper and red marginal notes",
            palette: "warm parchment",
            silhouette: "upright",
            continuity: "",
            avoid: "",
            assetName: nil,
            intendedAssetName: "",
            prompt: "production prompt",
            negativePrompt: "",
            marginalia: ["production note"],
            tags: ["character"]
        )

        let title = LabyrinthIllustrationPageSourceAdapter.bookPageTitle(for: profile)
        let body = LabyrinthIllustrationPageSourceAdapter.bookPageBody(for: profile)

        // The title is one of the Book's voiced variants and always names the character.
        XCTAssertTrue(title.contains("Dr. Elowen Vellum"))
        // The body speaks in the Book's voice and carries the character's real
        // signature, without ever leaking the dossier production metadata.
        XCTAssertTrue(body.contains("a silver bookmark-caliper and red marginal notes"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("dossier"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("marginalia:"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("silhouette:"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("production"))
        XCTAssertFalse(body.contains("|"))
    }

    func testEverySurfacingCharacterPlateUsesBespokeDossier() {
        // The bespoke catalog is exactly the canonical Cast that can surface as a
        // plate. This count is independent of how the reference library loads, so
        // it locks the set even though the bundled JSON is unavailable under SwiftPM.
        // 22 base Cast + the Dictionary Rebellion pack's two illustrated cast
        // members: Professor Mook and Pippa Pilcrow.
        XCTAssertEqual(CastDossier.bios.count, 24, "Expected 24 bespoke Cast dossiers")

        // Every bespoke dossier reads like real, longer narrative prose in the
        // Book's voice and never leaks the dossier production metadata.
        for (slug, prose) in CastDossier.bios {
            XCTAssertEqual(CastDossier.bio(forSlug: slug), prose)
            XCTAssertTrue(prose.contains("\n\n"), "\(slug) should be multi-paragraph")
            XCTAssertGreaterThan(prose.count, 400, "\(slug) should be substantial prose")
            XCTAssertFalse(prose.contains("|"), "\(slug) leaked a metadata separator")
            XCTAssertFalse(prose.localizedCaseInsensitiveContains("silhouette:"), "\(slug) leaked metadata")
            XCTAssertFalse(prose.localizedCaseInsensitiveContains("dossier"), "\(slug) leaked metadata")
        }

        // Wherever a bundled character profile is actually available in this
        // environment, the plate body must use its bespoke prose verbatim — never
        // the generic generator.
        let bundled = BookReferenceCatalog.bundledCharacterIllustrationAssetNames
        let available = BookReferenceCatalog.characterIllustrations.filter { profile in
            let asset = (profile.assetName?.isEmpty == false)
                ? (profile.assetName ?? profile.intendedAssetName)
                : profile.intendedAssetName
            return bundled.contains(asset) && asset.hasPrefix("LabyrinthCharacter")
        }
        XCTAssertFalse(available.isEmpty, "No bundled character profiles were available to check")
        for profile in available {
            guard let bespoke = CastDossier.bio(forSlug: profile.slug) else {
                XCTFail("No bespoke dossier for \(profile.characterName) [\(profile.slug)]")
                continue
            }
            XCTAssertEqual(
                LabyrinthIllustrationPageSourceAdapter.bookPageBody(for: profile),
                bespoke,
                "bookPageBody did not return the bespoke dossier for \(profile.slug)"
            )
        }
    }

    func testWorldEventResolverActivatesDictionaryRebellionByCalendar() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 10, hour: 12)

        let events = WorldEventResolver.activeEvents(now: now)
        let event = try XCTUnwrap(events.first { $0.id == "dictionary-rebellion" })

        XCTAssertEqual(event.title, "The Dictionary Rebellion")
        XCTAssertTrue(event.influenceLine.contains("Words are peeling off"))
        XCTAssertFalse(event.phase.lexicalRules.isEmpty)
    }

    func testDictionaryRebellionInfluencesStoryPacket() {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 10, hour: 16)

        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: richInputs(),
            now: now
        )

        XCTAssertTrue(packet.activeWorldEvents.contains { $0.id == "dictionary-rebellion" })
        XCTAssertTrue(packet.realSignals.contains { $0.contains("WORLD EVENT: The Dictionary Rebellion") })
        XCTAssertTrue(packet.selectedEntities.contains { $0.id == "penny-blackletter" })
        XCTAssertTrue(packet.selectedThreads.contains { $0.id == "ordinary-magic" })
    }

    func testWorldEventResolverPromotesOutcomeFromKeptEventPages() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 12, hour: 12)
        let pages = (0..<3).map { index in
            BookPage(
                id: "event-touch-\(index)",
                type: index == 0 ? .letter : .bookNotices,
                createdAt: localDate(year: 2026, month: 9, day: 9 + index, hour: 12),
                promptText: "Dictionary Rebellion",
                userInput: "A word changed.",
                tags: ["world-event", "event:dictionary-rebellion", "event-phase:outbreak"]
            )
        }
        let day = BookDay(id: "2026-09-12", date: localDate(year: 2026, month: 9, day: 12, hour: 0), pages: pages)
        var inputs = richInputs()
        inputs.days = [day]

        let event = try XCTUnwrap(WorldEventResolver.activeEvents(now: now, inputs: inputs).first { $0.id == "dictionary-rebellion" })

        XCTAssertEqual(event.playerTouchCount, 3)
        XCTAssertEqual(event.outcome?.id, "lexical-ally")
        XCTAssertTrue(event.influenceLine.contains("Lexical Ally"))
    }

    func testWorldEventResolverClassifiesTouchKinds() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 12, hour: 12)
        let pages = [
            BookPage(
                id: "event-letter",
                type: .letter,
                createdAt: localDate(year: 2026, month: 9, day: 10, hour: 12),
                promptText: "Dictionary Rebellion",
                userInput: "A letter about a changed word.",
                tags: ["world-event", "event:dictionary-rebellion"]
            ),
            BookPage(
                id: "event-fieldwork",
                type: .bookNotices,
                createdAt: localDate(year: 2026, month: 9, day: 11, hour: 12),
                promptText: "Dictionary Rebellion",
                userInput: "A better definition.",
                tags: ["world-event", "event:dictionary-rebellion", "event-fieldwork"]
            ),
            BookPage(
                id: "event-word-ruling",
                type: .wordNegotiation,
                createdAt: localDate(year: 2026, month: 9, day: 12, hour: 9),
                promptText: "Rule on almost",
                userInput: "Almost means a door deciding.",
                tags: ["word-negotiation", "event:dictionary-rebellion", "event-word-ruled"]
            )
        ]
        let day = BookDay(id: "2026-09-12", date: localDate(year: 2026, month: 9, day: 12, hour: 0), pages: pages)
        var inputs = richInputs()
        inputs.days = [day]

        let event = try XCTUnwrap(WorldEventResolver.activeEvents(now: now, inputs: inputs).first { $0.id == "dictionary-rebellion" })

        XCTAssertEqual(event.playerTouchCount, 3)
        XCTAssertEqual(event.playerTouchCounts?[WorldEventTouchKind.letterKept.rawValue], 1)
        XCTAssertEqual(event.playerTouchCounts?[WorldEventTouchKind.fieldworkCompleted.rawValue], 1)
        XCTAssertEqual(event.playerTouchCounts?[WorldEventTouchKind.wordRuled.rawValue], 1)
        XCTAssertTrue(event.influenceLine.contains("letter 1"))
        XCTAssertTrue(event.influenceLine.contains("fieldwork 1"))
        XCTAssertTrue(event.influenceLine.contains("word ruling 1"))
    }

    func testDictionaryRebellionPackIsLockedAndAvailableAsPaidListing() {
        // The content ships in a locked pack...
        let rebellion = PageArchetypePackRegistry.bundledPacks.first { $0.id == "dictionary-rebellion" }
        XCTAssertNotNil(rebellion, "the dictionary-rebellion content pack should be bundled")
        XCTAssertTrue(rebellion?.isLocked ?? false, "content pack must ship availability:\"locked\"")

        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(PackEntitlements.isUnlocked("dictionary-rebellion"))

        let listing = BookShopCatalog.listing(forPackID: "dictionary-rebellion")
        XCTAssertEqual(listing?.fallbackDisplayPrice, "$4.99")
        XCTAssertEqual(listing?.resolvedSaleState, .standard)
        XCTAssertEqual(listing?.comingSoon, false)
        XCTAssertTrue(listing?.goblinPitch.contains("small riot") == true)

        // Buying the pack unlocks negotiable words through the entitlement-gated registry.
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
        let words = PageArchetypePackRegistry.wordNegotiations()
        let byWord = Dictionary(words.map { ($0.word, $0) }, uniquingKeysWith: { first, _ in first })
        XCTAssertNotNil(byWord["fine"])
        XCTAssertNotNil(byWord["wonder"])

        // The Bargain seed: a word that cannot be ruled.
        XCTAssertEqual(byWord["remember"]?.isMissingSeed, true)
        XCTAssertTrue(byWord["remember"]?.choices.isEmpty ?? false)

        // Every rulable rebellion word offers the full four-verb negotiation.
        for word in words where word.eventID == "dictionary-rebellion" && !word.isMissingSeed {
            XCTAssertEqual(Set(word.choices.map(\.ruling)), [.recalled, .pardoned, .adopted, .freed],
                           "\(word.word) should offer all four rulings")
        }

        // Enough rulable words to keep a 16-day season varied and to settle a Treaty.
        let rulable = words.filter { $0.eventID == "dictionary-rebellion" && !$0.isMissingSeed }
        XCTAssertGreaterThanOrEqual(rulable.count, 20)

        // Each Treaty outcome has a keepable aftermath page, gated to the
        // settling (afterimage) phase and that outcome.
        let aftermath = (rebellion?.archetypes ?? []).filter { $0.tags.contains("aftermath") }
        let outcomesCovered = Set(aftermath.compactMap { $0.trigger?.treatyOutcomes?.first })
        XCTAssertEqual(outcomesCovered, ["restoration", "reformation", "secession"])
        for page in aftermath {
            XCTAssertEqual(page.trigger?.worldEventPhases ?? [], ["afterimage"],
                           "\(page.id) should surface in the rebellion's afterimage phase")
            XCTAssertEqual(page.trigger?.activeWorldEventIDs ?? [], ["dictionary-rebellion"])
        }

        let backToSchoolPages = (rebellion?.archetypes ?? []).filter { $0.tags.contains("back-to-school") }
        XCTAssertEqual(
            Set(backToSchoolPages.map(\.id)),
            [
                "mooks-mandate",
                "note-from-the-pixie",
                "substitute-lecture",
                "roll-call-of-words",
                "spelling-bee-in-the-stacks",
                "the-erased-margin"
            ]
        )
        XCTAssertTrue(backToSchoolPages.allSatisfy { $0.trigger?.months == [9] })
        XCTAssertTrue(backToSchoolPages.allSatisfy { $0.trigger?.activeWorldEventIDs == nil })
        XCTAssertEqual(
            Set(backToSchoolPages.filter { $0.generation != nil }.map(\.id)),
            Set(backToSchoolPages.map(\.id))
        )
        XCTAssertTrue(backToSchoolPages.allSatisfy { $0.cadenceHours >= 12 })
        XCTAssertEqual(backToSchoolPages.first { $0.id == "the-erased-margin" }?.trigger?.rarity, 0.45)
    }

    func testDictionaryRebellionContentIsFullyGatedByOnePack() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer {
            PackEntitlements.ownedPackIDs = savedOwned
        }

        // No entitlement -> the whole season is absent from the base game:
        // no world event, no negotiable words, no aftermath pages.
        PackEntitlements.ownedPackIDs = []
        XCTAssertFalse(WorldEventRegistry.enabledEvents().contains { $0.event.id == "dictionary-rebellion" },
                       "the rebellion world event must not surface without its content pack")
        XCTAssertTrue(PageArchetypePackRegistry.wordNegotiations().allSatisfy { $0.eventID != "dictionary-rebellion" },
                      "no negotiable words without the pack")
        XCTAssertTrue(PageArchetypePackRegistry.archetypes().allSatisfy { !$0.tags.contains("aftermath") },
                      "no treaty aftermath pages without the pack")
        XCTAssertFalse(NarrativePackRegistry.entities.contains { $0.id == "professor-thaddeus-mook" },
                       "gated cast must not exist without the pack")
        XCTAssertFalse(NarrativePackRegistry.entities.contains { $0.id == "pippa-pilcrow" })

        // Owning the single pack id restores every channel at once.
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
        XCTAssertTrue(WorldEventRegistry.enabledEvents().contains { $0.event.id == "dictionary-rebellion" })
        XCTAssertFalse(PageArchetypePackRegistry.wordNegotiations().filter { $0.eventID == "dictionary-rebellion" }.isEmpty)
        XCTAssertEqual(PageArchetypePackRegistry.archetypes().filter { $0.tags.contains("aftermath") }.count, 3)
        XCTAssertTrue(NarrativePackRegistry.entities.contains { $0.id == "professor-thaddeus-mook" })
        XCTAssertTrue(NarrativePackRegistry.entities.contains { $0.id == "pippa-pilcrow" })
    }

    func testWordNegotiationAdapterBuildsPackDrivenSurfaceAndSkipsRuledWords() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 12, hour: 12)
        let day = BookDay(id: "2026-09-12", date: localDate(year: 2026, month: 9, day: 12, hour: 0), pages: [])
        var inputs = richInputs()
        inputs.activeWorldEvents = WorldEventResolver.activeEvents(now: now, inputs: inputs)

        let definition = WordNegotiationDefinition(
            id: "almost-rebels",
            word: "almost",
            originalSense: "not quite",
            grievance: "It is tired of waiting outside the sentence.",
            category: .theme,
            eventID: "dictionary-rebellion",
            isMissingSeed: true,
            score: 88,
            tags: ["test-pack"],
            choices: [
                WordNegotiationChoice(
                    ruling: .adopted,
                    title: "Adopt",
                    detail: "Let almost mean a door deciding.",
                    resultingSense: "a door deciding",
                    responseLine: "Almost steps into the doorway.",
                    category: .theme
                )
            ]
        )
        let adapter = WordNegotiationPageSourceAdapter()

        let surfaces = adapter.candidates(from: [definition], for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        let surface = try XCTUnwrap(surfaces.first)

        XCTAssertEqual(surface.type, .wordNegotiation)
        XCTAssertEqual(surface.intent, .capture)
        XCTAssertEqual(surface.score, 88)
        XCTAssertEqual(surface.payload.metadata["wordNegotiationID"], "almost-rebels")
        XCTAssertEqual(surface.payload.metadata["wordNegotiationWordID"], "almost")
        XCTAssertEqual(surface.payload.metadata["wordNegotiationDefaultRuling"], WordRuling.adopted.rawValue)
        XCTAssertEqual(surface.payload.metadata["wordNegotiationIsMissingSeed"], "true")
        XCTAssertEqual(surface.payload.metadata["wordNegotiationChoice.adopted.sense"], "a door deciding")
        XCTAssertEqual(surface.payload.metadata["worldEventIDs"], "dictionary-rebellion")
        XCTAssertTrue(surface.payload.metadata["tags"]?.contains("event-word-ruled") == true)
        XCTAssertTrue(surface.payload.body.contains("Possible rulings"))

        inputs.readerLexicon.upsert(LexiconEntry(
            word: "almost",
            originalSense: "not quite",
            newSense: "a door deciding",
            ruling: .adopted,
            category: .theme,
            origin: .rebellion,
            ledAt: now
        ))

        XCTAssertTrue(adapter.candidates(from: [definition], for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now).isEmpty)
    }

    func testDictionaryRebellionOutcomeFeedsStoryPacket() {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 12, hour: 16)
        let touches = (0..<5).map { index in
            BookPage(
                id: "definition-touch-\(index)",
                type: .letter,
                createdAt: localDate(year: 2026, month: 9, day: 8 + index, hour: 12),
                promptText: "A rebellion note",
                userInput: "A definition changed.",
                tags: ["world-event", "event:dictionary-rebellion"]
            )
        }
        var inputs = richInputs()
        inputs.days = [BookDay(id: "2026-09-12", date: localDate(year: 2026, month: 9, day: 12, hour: 0), pages: touches)]

        let packet = StoryScenePacketBuilder.packet(
            for: dayWithMusicSouvenir(),
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(packet.activeWorldEvents.first { $0.id == "dictionary-rebellion" }?.outcome?.id, "definition-binder")
        XCTAssertTrue(packet.realSignals.contains { $0.contains("Definition Binder") })
    }

    func testWorldEventsBoostAndTagSurfacedPages() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 10, hour: 10)

        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: now,
            limit: 12
        )
        let affected = pages.filter { $0.payload.metadata["worldEventIDs"]?.contains("dictionary-rebellion") == true }

        XCTAssertFalse(affected.isEmpty)
        XCTAssertTrue(affected.contains { $0.type == .letter || $0.type == .academyClass || $0.type == .bookNotices })
        XCTAssertTrue(affected.allSatisfy { ($0.payload.metadata["tags"] ?? "").contains("event:dictionary-rebellion") })
        XCTAssertTrue(affected.allSatisfy { ($0.payload.metadata["tags"] ?? "").contains("event-outcome:unwitnessed") })
    }

    func testWorldEventDoorSurfacesFieldworkDuringActiveEvent() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 10, hour: 10)

        let pages = BookCurator.surfacedPages(
            for: emptyDay(),
            inputs: richInputs(),
            now: now,
            limit: 12
        )
        let eventDoor = try XCTUnwrap(pages.first { $0.sourceID == "world-event-door" })

        XCTAssertEqual(eventDoor.type, .bookNotices)
        XCTAssertEqual(eventDoor.intent, .capture)
        // The body weaves the fieldwork invitation into the Book's dispatch.
        XCTAssertTrue(eventDoor.payload.body.contains("ordinary word"))
        XCTAssertTrue(eventDoor.payload.metadata["fieldworkPrompt"]?.contains("ordinary word") == true)
        XCTAssertTrue(eventDoor.payload.metadata["tags"]?.contains("event-fieldwork") == true)
    }

    func testWorldEventDoorReflectsOutcomeAfterPlayerTouchesEvent() throws {
        let savedOwned = ownDictionaryRebellionForTest()
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        let now = localDate(year: 2026, month: 9, day: 12, hour: 10)
        let touches = (0..<5).map { index in
            BookPage(
                id: "event-door-touch-\(index)",
                type: .bookNotices,
                createdAt: localDate(year: 2026, month: 9, day: 8 + index, hour: 12),
                promptText: "Dictionary fieldwork",
                userInput: "A better definition.",
                tags: ["world-event", "event:dictionary-rebellion", "event-fieldwork"]
            )
        }
        var inputs = richInputs()
        inputs.days = [BookDay(id: "2026-09-12", date: localDate(year: 2026, month: 9, day: 12, hour: 0), pages: touches)]

        let manual = BookPageSourceAdapters.active
            .first { $0.source.id == "world-event-door" }?
            .manualSurface(for: emptyDay(), context: .make(for: emptyDay()), inputs: inputs, now: now)

        let eventDoor = try XCTUnwrap(manual)
        // The reader's standing surfaces the resolved outcome in the Book's voice.
        XCTAssertTrue(eventDoor.payload.body.range(of: "definition binder", options: .caseInsensitive) != nil)
        XCTAssertEqual(eventDoor.payload.metadata["worldEventOutcome"], "definition-binder")
        XCTAssertTrue(eventDoor.payload.metadata["tags"]?.contains("event-outcome:definition-binder") == true)
    }

    func testWorldEventDoorCanOpenPurchasedArchivedEvent() throws {
        defer { PackEntitlements.ownedPackIDs = [] }
        PackEntitlements.ownedPackIDs = ["starlit-paper-trial-archive"]
        let now = localDate(year: 2026, month: 6, day: 1, hour: 10)

        let manual = BookPageSourceAdapters.active
            .first { $0.source.id == "world-event-door" }?
            .manualSurface(for: emptyDay(), context: .make(for: emptyDay()), inputs: richInputs(), now: now)

        let eventDoor = try XCTUnwrap(manual)
        XCTAssertEqual(eventDoor.payload.metadata["worldEventIDs"], "starlit-paper-trial")
        XCTAssertEqual(eventDoor.payload.metadata["worldEventMode"], WorldEventActivationMode.openedArchive.rawValue)
        // The title heads the page; the body carries the in-world dispatch.
        XCTAssertEqual(eventDoor.payload.headline, "The Starlit Paper Trial")
        XCTAssertTrue(eventDoor.prompt.contains("The Starlit Paper Trial"))
        XCTAssertTrue(eventDoor.payload.metadata["tags"]?.contains("event-fieldwork") == true)
    }

    func testMonthlyEditionBindsWorldEventTracesFromKeptTags() throws {
        let eventPage = BookPage(
            type: .letter,
            createdAt: localDate(year: 2026, month: 9, day: 10, hour: 12),
            promptText: "A letter from Penny",
            userInput: "The word ordinary resigned.",
            tags: ["letter", "world-event", "event:dictionary-rebellion", "event-phase:outbreak", "event-outcome:lexical-ally"]
        )
        let day = BookDay(id: "2026-09-10", date: localDate(year: 2026, month: 9, day: 10, hour: 0), pages: [eventPage])

        let edition = MonthlyEditionBuilder.edition(
            from: [day],
            readerName: "Avery",
            startDate: localDate(year: 2026, month: 9, day: 1, hour: 0),
            endDate: localDate(year: 2026, month: 9, day: 30, hour: 23),
            generatedAt: localDate(year: 2026, month: 9, day: 30, hour: 12)
        )
        let section = try XCTUnwrap(edition.sections.first { $0.id == "world-events" })

        XCTAssertEqual(section.title, "World Events")
        XCTAssertTrue(section.items.first?.body.contains("Dictionary Rebellion") == true)
        XCTAssertTrue(section.items.first?.body.contains("Lexical Ally") == true)
    }

    private func localDate(hour: Int, minute: Int = 0) -> Date {
        // Pinned to a fixed calendar day so curator ranking/variety/almanac
        // rotation is deterministic regardless of the real system date.
        localDate(year: 2026, month: 1, day: 15, hour: hour, minute: minute)
    }

    private func localDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        )) ?? Date()
    }

    private func assertCheckInPrimary(
        _ expected: BookPageType,
        atHour hour: Int,
        minute: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let date = localDate(hour: hour, minute: minute)
        let types: [BookPageType] = [.mood, .fuel, .souvenir]
        let boosts = Dictionary(uniqueKeysWithValues: types.map { ($0, CuratorTimeAffinity.boost(for: $0, at: date)) })
        XCTAssertEqual(boosts[expected], 24, file: file, line: line)
        for type in types where type != expected {
            XCTAssertEqual(boosts[type], -18, file: file, line: line)
        }
    }

    func testReaderLearningCanLiftKeptPageType() {
        let now = localDate(hour: 14, minute: 0)
        let diary = SurfacePage(
            id: "diary-learning",
            type: .diary,
            sourceID: "diary-page",
            intent: .capture,
            renderStyle: .promptCard,
            score: 50,
            prompt: "Diary",
            detail: "Diary",
            payload: BookPagePayload(headline: "Diary", body: "Diary", metadata: ["tags": "sensory,home"])
        )
        let lore = SurfacePage(
            id: "lore-learning",
            type: .lore,
            sourceID: "labyrinth-lore",
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 54,
            prompt: "Lore",
            detail: "Lore",
            payload: BookPagePayload(headline: "Lore", body: "Lore")
        )
        var learning = ReaderLearningModel()
        for offset in 0..<3 {
            learning.record(
                ReaderLearningEvent(
                    dayID: "2026-07-0\(offset + 1)",
                    occurredAt: now.addingTimeInterval(Double(offset) * 60),
                    action: .kept,
                    surfaceID: diary.id,
                    sourceID: diary.sourceID,
                    type: diary.type,
                    varietyKey: diary.varietyKey,
                    hour: 14,
                    tags: diary.readerLearningTags,
                    evidence: "A true kept diary page."
                )
            )
        }

        let ranked = BookCurator.rankedPages(
            from: [lore, diary],
            limit: 2,
            preferences: CuratorSurfacePreferences(readerLearning: learning),
            mood: .neutral,
            now: now
        )

        XCTAssertEqual(ranked.first?.page.id, diary.id)
    }

    func testReaderLearningCoolsDismissedSource() {
        let page = SurfacePage(
            id: "fuel-learning",
            type: .fuel,
            sourceID: "fuel-log",
            intent: .capture,
            renderStyle: .promptCard,
            score: 70,
            prompt: "Fuel",
            detail: "Fuel",
            payload: BookPagePayload(headline: "Fuel", body: "Fuel", metadata: ["tags": "body"])
        )
        var learning = ReaderLearningModel()
        for offset in 0..<2 {
            learning.record(
                ReaderLearningEvent(
                    dayID: "2026-07-0\(offset + 1)",
                    action: .dismissed,
                    surfaceID: page.id,
                    sourceID: page.sourceID,
                    type: page.type,
                    varietyKey: page.varietyKey,
                    hour: 9,
                    tags: page.readerLearningTags
                )
            )
        }

        let neutralScore = CuratorSurfacePreferences.none.adjustedScore(for: page)
        let learnedScore = CuratorSurfacePreferences(readerLearning: learning).adjustedScore(for: page)

        XCTAssertLessThan(learnedScore, neutralScore)
    }

    func testBookLearnsNoticeSurfacesReaderLearningInsights() throws {
        let now = localDate(year: 2026, month: 7, day: 4, hour: 14)
        let oldDay = BookDay(
            id: "2026-07-03",
            date: localDate(year: 2026, month: 7, day: 3, hour: 8),
            pages: [
                BookPage(type: .souvenir, createdAt: localDate(year: 2026, month: 7, day: 3, hour: 8), promptText: "p", userInput: "The cup warmed both hands."),
                BookPage(type: .diary, createdAt: localDate(year: 2026, month: 7, day: 3, hour: 9), promptText: "p", userInput: "The hallway stayed quiet."),
                BookPage(type: .mood, createdAt: localDate(year: 2026, month: 7, day: 3, hour: 10), promptText: "p", userInput: "Weather under the ribs."),
                BookPage(type: .fuel, createdAt: localDate(year: 2026, month: 7, day: 3, hour: 11), promptText: "p", userInput: "Toast and coffee.")
            ]
        )
        let today = BookDay(id: "2026-07-04", date: localDate(year: 2026, month: 7, day: 4, hour: 0), pages: [])
        let page = SurfacePage(
            id: "souvenir-learning",
            type: .souvenir,
            sourceID: "one-sentence-souvenir",
            score: 50,
            prompt: "Souvenir",
            detail: "Souvenir",
            payload: BookPagePayload(headline: "Souvenir", body: "Souvenir", metadata: ["tags": "sensory,home"])
        )
        var learning = ReaderLearningModel()
        for offset in 0..<4 {
            learning.record(
                ReaderLearningEvent(
                    dayID: oldDay.id,
                    occurredAt: now.addingTimeInterval(Double(offset) * 60),
                    action: .kept,
                    surfaceID: page.id,
                    sourceID: page.sourceID,
                    type: page.type,
                    varietyKey: page.varietyKey,
                    hour: 14,
                    tags: page.readerLearningTags
                )
            )
        }
        var inputs = BookSourceInputs.empty
        inputs.days = [oldDay]
        inputs.readerLearning = learning

        let notices = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        )
        let learningNotice = try XCTUnwrap(notices.first { $0.payload.metadata["bookLearning"] == "true" })

        XCTAssertEqual(learningNotice.payload.headline, "The Book Learns")
        XCTAssertTrue(learningNotice.payload.body.contains("I should show my work."))
        XCTAssertTrue(learningNotice.payload.metadata["learningInsights"]?.contains("Souvenir") == true)
    }

    private func rankedCandidate(_ type: BookPageType, score: Int) -> SurfacePage {
        SurfacePage(
            id: "candidate-\(type.rawValue)",
            type: type,
            sourceID: "candidate-\(type.rawValue)",
            score: score,
            prompt: type.title,
            detail: "Candidate for \(type.title)."
        )
    }

    private func loreCandidate(id: String, score: Int) -> SurfacePage {
        SurfacePage(
            id: id,
            type: .lore,
            sourceID: "labyrinth-lore",
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            prompt: "Lore",
            detail: "Candidate for Lore.",
            payload: BookPagePayload(headline: "Lore", body: "Candidate for Lore.")
        )
    }

    private func bookJumpCandidate(action: BookJumpAction, score: Int) -> SurfacePage {
        SurfacePage(
            id: "candidate-book-jump-\(action.rawValue)",
            type: .bookJump,
            sourceID: "book-jump",
            score: score,
            prompt: "Book Jump",
            detail: "Candidate for Book Jump.",
            payload: BookPagePayload(
                headline: action.title,
                body: "Candidate for Book Jump.",
                metadata: ["bookJumpAction": action.rawValue]
            )
        )
    }

    private func wonderCompassCandidate(
        id: String,
        score: Int,
        metadata: [String: String]
    ) -> SurfacePage {
        SurfacePage(
            id: id,
            type: .wonderCompass,
            sourceID: "wonder-compass",
            score: score,
            prompt: "Wonder Compass",
            detail: "Candidate for Wonder Compass.",
            payload: BookPagePayload(
                headline: "Wonder Compass",
                body: "Candidate for Wonder Compass.",
                metadata: metadata
            )
        )
    }

    private func distance(_ a: CodablePoint, _ b: CodablePoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
