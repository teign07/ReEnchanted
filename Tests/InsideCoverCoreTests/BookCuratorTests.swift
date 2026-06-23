import XCTest
@testable import InsideCoverCore

final class BookCuratorTests: XCTestCase {
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

    func testFirstHoursCuratorBoostsOrientationCards() {
        let now = localDate(year: 2026, month: 6, day: 1, hour: 11)
        let candidates = [
            rankedCandidate(.castMember, score: 49),
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

    func testDeepSystemCardsReturnAfterFirstHours() {
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

        XCTAssertEqual(pages.map(\.type), [.bookConnections, .bookRemembered, .helpTips])
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
        var inputs = richInputs()
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
            limit: 12
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

        let afternoon = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(hour: 15),
            limit: 8
        )
        let night = BookCurator.surfacedPages(
            for: day,
            inputs: richInputs(),
            now: localDate(hour: 21),
            limit: 8
        )

        XCTAssertFalse(afternoon.contains { $0.type == .bookOfYou })
        XCTAssertTrue(night.contains { $0.type == .bookOfYou })
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
        let profile = CharacterIllustrationProfile(
            id: "dr-elowen-vellum",
            characterName: "Dr. Elowen Vellum",
            slug: "dr-elowen-vellum",
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

    func testWorldEventResolverActivatesDictionaryRebellionByCalendar() throws {
        let now = localDate(year: 2026, month: 9, day: 10, hour: 12)

        let events = WorldEventResolver.activeEvents(now: now)
        let event = try XCTUnwrap(events.first { $0.id == "dictionary-rebellion" })

        XCTAssertEqual(event.title, "The Dictionary Rebellion")
        XCTAssertTrue(event.influenceLine.contains("Words are peeling off"))
        XCTAssertFalse(event.phase.lexicalRules.isEmpty)
    }

    func testDictionaryRebellionInfluencesStoryPacket() {
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

    func testDictionaryRebellionOutcomeFeedsStoryPacket() {
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
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
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
