import XCTest
@testable import InsideCoverCore

final class TheBleedTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 6, day: day, hour: hour))!
    }

    private func septemberDate(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 9, day: day, hour: hour))!
    }

    private func interestFact(_ id: String, _ answer: String) -> SelfFact {
        SelfFact(
            id: "fact-\(id)",
            questionID: id,
            question: "What's an interest of yours?",
            answer: answer,
            bookTranslation: "",
            sensitivity: .delight,
            usePermission: .quoteAllowed,
            tags: ["interest"],
            createdAt: date(1, hour: 9),
            updatedAt: date(1, hour: 9)
        )
    }

    private func themePage(_ id: String, day: Int, text: String) -> BookPage {
        BookPage(id: id, type: .diary, createdAt: date(day, hour: 10), promptText: "Diary", userInput: text)
    }

    private var day: BookDay {
        BookDay(id: "2026-06-10", date: date(10, hour: 0), pages: [])
    }

    func testEditionKindFollowsTheClock() {
        XCTAssertEqual(TheBleedEditionBuilder.editionKind(for: date(10, hour: 7), calendar: calendar), .morning)
        XCTAssertEqual(TheBleedEditionBuilder.editionKind(for: date(10, hour: 12), calendar: calendar), .morning)
        XCTAssertNil(TheBleedEditionBuilder.editionKind(for: date(10, hour: 14), calendar: calendar))
        XCTAssertEqual(TheBleedEditionBuilder.editionKind(for: date(10, hour: 18), calendar: calendar), .evening)
    }

    func testAnnouncementCarriesBriefsAndInterest() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing"), interestFact("interest-02", "weird history")]
        inputs.bleedIssueNumber = 12
        let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: date(10, hour: 8), calendar: calendar)
        XCTAssertNotNil(announcement)
        XCTAssertEqual(announcement?.type, .theBleed)
        XCTAssertTrue(announcement?.payload.headline.contains("Issue #12") == true)
        XCTAssertTrue(announcement?.prompt.contains("The newest edition") == true)
        let briefs = TheBleedEditionBuilder.decodedBriefs(announcement?.payload.metadata["bleedBriefs"] ?? "")
        XCTAssertTrue(briefs.contains { $0.id == "front-page" && $0.needsLocalBrain })
        XCTAssertTrue(briefs.contains { $0.id == "weather-desk" && !$0.needsLocalBrain })
        XCTAssertTrue(briefs.contains { $0.id == "interest-desk" })
        XCTAssertFalse((announcement?.payload.metadata["bleedInterest"] ?? "").isEmpty)
    }

    func testThemeDeskReportsUnstableThemeInTheBleed() throws {
        let pages = [
            themePage("theme-1", day: 1, text: "The harbor kept a secret and the secret kept the harbor."),
            themePage("theme-2", day: 3, text: "The harbor made the secret sound like weather."),
            themePage("theme-3", day: 5, text: "The secret came back to the harbor before breakfast.")
        ]
        let theme = try XCTUnwrap(BookThemeEngine.theme(
            for: pages,
            digest: .empty,
            monthKey: "2026-06",
            now: date(5, hour: 12),
            calendar: calendar
        ))
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-06-theme", date: date(5, hour: 0), pages: pages)]
        inputs.themes = [theme]

        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: date(10, hour: 8), calendar: calendar))
        let briefs = TheBleedEditionBuilder.decodedBriefs(announcement.payload.metadata["bleedBriefs"] ?? "")
        let themeBrief = try XCTUnwrap(briefs.first { $0.id == "theme-desk" })

        XCTAssertEqual(announcement.payload.metadata["monthlyThemeStatus"], "provisional")
        XCTAssertTrue(announcement.payload.body.contains("still unstable"))
        XCTAssertTrue(themeBrief.composedBody.contains("UNSTABLE THEME WATCH"))
        XCTAssertTrue(themeBrief.composedBody.contains("reading the headline in pencil"))
    }

    func testThemeDeskReportsStableThemeInTheBleed() throws {
        let pages = [
            themePage("theme-1", day: 1, text: "The harbor kept a secret and the secret kept the harbor."),
            themePage("theme-2", day: 3, text: "The harbor made the secret sound like weather."),
            themePage("theme-3", day: 5, text: "The secret came back to the harbor before breakfast."),
            themePage("theme-4", day: 7, text: "The harbor wrote the secret in rainwater."),
            themePage("theme-5", day: 9, text: "The secret returned to the harbor with salt on it."),
            themePage("theme-6", day: 11, text: "The harbor held the secret up to the light."),
            themePage("theme-7", day: 13, text: "The secret and the harbor finally agreed on a name.")
        ]
        let theme = try XCTUnwrap(BookThemeEngine.theme(
            for: pages,
            digest: .empty,
            monthKey: "2026-06",
            now: date(13, hour: 12),
            calendar: calendar
        ))
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-06-theme", date: date(13, hour: 0), pages: pages)]
        inputs.themes = [theme]

        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: date(13, hour: 8), calendar: calendar))
        let briefs = TheBleedEditionBuilder.decodedBriefs(announcement.payload.metadata["bleedBriefs"] ?? "")
        let themeBrief = try XCTUnwrap(briefs.first { $0.id == "theme-desk" })

        XCTAssertEqual(announcement.payload.metadata["monthlyThemeStatus"], "stable")
        XCTAssertTrue(announcement.payload.body.contains("is stable for the month"))
        XCTAssertTrue(themeBrief.composedBody.contains("STABLE MONTHLY THEME"))
        XCTAssertTrue(themeBrief.composedBody.contains("set in type for the month"))
    }

    func testAnnouncementCarriesActiveWorldEventPacket() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
        var inputs = BookSourceInputs.empty
        inputs.bleedIssueNumber = 13
        let september = BookDay(id: "2026-09-10", date: septemberDate(10, hour: 0), pages: [])
        let announcement = TheBleedEditionBuilder.announcementSurface(for: september, inputs: inputs, now: septemberDate(10, hour: 8), calendar: calendar)

        XCTAssertEqual(announcement?.payload.metadata["worldEventIDs"], "dictionary-rebellion")
        XCTAssertTrue(announcement?.payload.metadata["worldEventBleedPacket"]?.contains("Treat the rebellion as live campus news") == true)
        XCTAssertTrue(announcement?.payload.metadata["tags"]?.contains("event:dictionary-rebellion") == true)
        XCTAssertTrue(announcement?.payload.body.contains("Special bulletin: The Dictionary Rebellion") == true)
    }

    func testMorningAndEveningPickDifferentInterests() {
        let facts = [interestFact("interest-01", "sailing"), interestFact("interest-02", "weird history")]
        let morning = TheBleedEditionBuilder.selectedInterest(from: facts, dayID: "2026-06-10", kind: .morning)
        let evening = TheBleedEditionBuilder.selectedInterest(from: facts, dayID: "2026-06-10", kind: .evening)
        XCTAssertNotNil(morning)
        XCTAssertNotNil(evening)
        XCTAssertNotEqual(morning, evening)
    }

    func testKeptEditionSuppressesAnnouncementForThatSlot() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing")]
        let slot = TheBleedEditionBuilder.slotID(for: .morning, day: day)
        var keptDay = day
        keptDay.pages = [
            BookPage(id: "kept-bleed", type: .theBleed, createdAt: date(10, hour: 9), promptText: "The Bleed", userInput: "Edition body", tags: [slot])
        ]
        XCTAssertNil(TheBleedEditionBuilder.announcementSurface(for: keptDay, inputs: inputs, now: date(10, hour: 10), calendar: calendar))
        // Evening still publishes.
        XCTAssertNotNil(TheBleedEditionBuilder.announcementSurface(for: keptDay, inputs: inputs, now: date(10, hour: 18), calendar: calendar))
    }

    func testMorningEditionRecursNextDayWithoutRepeatingTheSameOccurrence() throws {
        let firstNow = date(10, hour: 8)
        let secondNow = date(11, hour: 8)
        let firstDay = BookDay(id: "2026-06-10", date: date(10, hour: 0), pages: [])
        let secondDay = BookDay(id: "2026-06-11", date: date(11, hour: 0), pages: [])
        let inputs = BookSourceInputs.empty
        let first = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: firstDay,
            inputs: inputs,
            now: firstNow,
            calendar: calendar
        ))
        let second = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: secondDay,
            inputs: inputs,
            now: secondNow,
            calendar: calendar
        ))
        XCTAssertEqual(first.curatorContentNoveltyKey, second.curatorContentNoveltyKey)
        XCTAssertNotEqual(first.curatorAutomaticRecurrenceHistoryKey, second.curatorAutomaticRecurrenceHistoryKey)
        let history = CuratorVarietyGovernor.recordingServed(
            keys: first.curatorServedHistoryKeys,
            into: [:],
            now: firstNow
        )

        XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
            first,
            history: history,
            preferences: .none,
            now: firstNow.addingTimeInterval(3600)
        ))
        XCTAssertTrue(CuratorNoveltyPolicy.allowsAutomaticSurface(
            second,
            history: history,
            preferences: .none,
            now: secondNow
        ))
    }

    func testPreparedBleedEditionGetsItsOwnStageWithinTheEditionSlot() throws {
        let now = date(10, hour: 8)
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day,
            inputs: .empty,
            now: now,
            calendar: calendar
        ))
        let prepared = TheBleedEditionBuilder.preparedCopy(
            of: announcement,
            body: "THE PAPER",
            interestSources: ""
        )
        let announcementHistory = CuratorVarietyGovernor.recordingServed(
            keys: announcement.curatorServedHistoryKeys,
            into: [:],
            now: now
        )

        XCTAssertNotEqual(announcement.curatorAutomaticRecurrenceHistoryKey, prepared.curatorAutomaticRecurrenceHistoryKey)
        XCTAssertTrue(CuratorNoveltyPolicy.allowsAutomaticSurface(
            prepared,
            history: announcementHistory,
            preferences: .none,
            now: now
        ))

        let preparedHistory = CuratorVarietyGovernor.recordingServed(
            keys: prepared.curatorServedHistoryKeys,
            into: announcementHistory,
            now: now
        )
        XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
            prepared,
            history: preparedHistory,
            preferences: .none,
            now: now.addingTimeInterval(3600)
        ))
    }

    func testAlmanacUsesTodayInTheMorningAndTomorrowInTheEvening() {
        var inputs = BookSourceInputs.empty
        inputs.calendarEvents = [
            CalendarEventSignal(id: "today", title: "Harbor walk", startsAt: date(10, hour: 15), isAllDay: false),
            CalendarEventSignal(id: "tomorrow", title: "Ferry to town", startsAt: date(11, hour: 9), isAllDay: false)
        ]
        let morning = TheBleedEditionBuilder.almanacColumn(kind: .morning, inputs: inputs, now: date(10, hour: 8), calendar: calendar)
        XCTAssertTrue(morning.contains("Harbor walk"))
        XCTAssertFalse(morning.contains("Ferry to town"))
        let evening = TheBleedEditionBuilder.almanacColumn(kind: .evening, inputs: inputs, now: date(10, hour: 18), calendar: calendar)
        XCTAssertTrue(evening.contains("Ferry to town"))
        XCTAssertFalse(evening.contains("Harbor walk"))
        XCTAssertTrue(evening.hasPrefix("Tomorrow"))
    }

    func testAlmanacDoesNotMistakeAClosedDoorwayForAnEmptyDay() {
        var inputs = BookSourceInputs.empty
        inputs.calendarIntegrationEnabled = false

        let column = TheBleedEditionBuilder.almanacColumn(
            kind: .morning,
            inputs: inputs,
            now: date(10, hour: 8),
            calendar: calendar
        )

        XCTAssertTrue(column.contains("Calendar Doorway is closed"))
        XCTAssertTrue(column.contains("not an empty day"))
    }

    func testAlmanacBriefRefreshesAfterCalendarPermissionArrivesAtPressTime() throws {
        var inputs = BookSourceInputs.empty
        inputs.calendarIntegrationEnabled = false
        let stale = TheBleedEditionBuilder.columnBriefs(
            kind: .morning,
            day: day,
            inputs: inputs,
            interest: nil,
            now: date(10, hour: 8),
            calendar: calendar
        )
        inputs.calendarIntegrationEnabled = true
        inputs.calendarEvents = [
            CalendarEventSignal(
                id: "press-time-event",
                title: "Ink inspection",
                startsAt: date(10, hour: 11),
                isAllDay: false
            )
        ]

        let refreshed = TheBleedEditionBuilder.refreshingAlmanacBriefs(
            stale,
            kind: .morning,
            inputs: inputs,
            now: date(10, hour: 8),
            calendar: calendar
        )
        let almanac = try XCTUnwrap(refreshed.first { $0.id == "almanac" })

        XCTAssertTrue(almanac.composedBody.contains("Ink inspection"))
        XCTAssertFalse(almanac.composedBody.contains("Doorway is closed"))
    }

    func testWeatherBriefCanRefreshFromPlainForecastAtPressTime() throws {
        let staleBriefs = TheBleedEditionBuilder.columnBriefs(
            kind: .morning,
            day: day,
            inputs: .empty,
            interest: nil,
            now: date(10, hour: 8),
            calendar: calendar
        )
        let staleWeather = try XCTUnwrap(staleBriefs.first { $0.id == "weather-desk" })
        XCTAssertTrue(staleWeather.composedBody.contains("sky declined to file"))

        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Current: Rain, 64 F | Forecast: showers later",
            source: "Open-Meteo",
            currentTemperature: "64 F",
            forecast: "showers later",
            conditionSymbolName: "cloud.rain"
        )

        let refreshed = TheBleedEditionBuilder.refreshingWeatherBriefs(staleBriefs, kind: .morning, inputs: inputs)
        let weather = try XCTUnwrap(refreshed.first { $0.id == "weather-desk" })

        XCTAssertTrue(weather.composedBody.contains("Current: Rain, 64 F"))
        XCTAssertFalse(weather.composedBody.contains("Academy's own translation"))
    }

    func testWeatherBriefStillUsesGeneratedEnchantedForecastWhenAvailable() throws {
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Current: Fog, 55 F | Forecast: mist through noon",
            source: "Open-Meteo",
            currentTemperature: "55 F",
            forecast: "mist through noon",
            conditionSymbolName: "cloud.fog"
        )
        inputs.enchantedWeather = EnchantedWeatherSignal(
            summary: "Fog, 55 F",
            enchantified: "The world is speaking in pencil.",
            selector: "gemma-weather",
            symbolName: "cloud.fog"
        )

        let briefs = TheBleedEditionBuilder.columnBriefs(
            kind: .evening,
            day: day,
            inputs: .empty,
            interest: nil,
            now: date(10, hour: 18),
            calendar: calendar
        )
        let refreshed = TheBleedEditionBuilder.refreshingWeatherBriefs(briefs, kind: .evening, inputs: inputs)
        let weather = try XCTUnwrap(refreshed.first { $0.id == "weather-desk" })

        XCTAssertTrue(weather.composedBody.contains("Current: Fog, 55 F"))
        XCTAssertTrue(weather.composedBody.contains("The Academy's own translation: The world is speaking in pencil."))
    }

    func testCompositedBodyReadsLikeAPaper() {
        let briefs = TheBleedEditionBuilder.columnBriefs(
            kind: .morning,
            day: day,
            inputs: .empty,
            interest: "sailing",
            now: date(10, hour: 8),
            calendar: calendar
        )
        let columns = briefs.map { brief in
            (brief: brief, body: brief.needsLocalBrain ? "Column text for \(brief.id)." : brief.composedBody)
        }
        let body = TheBleedEditionBuilder.compositedBody(kind: .morning, issueNumber: 7, columns: columns, now: date(10, hour: 8), calendar: calendar)
        XCTAssertTrue(body.contains("THE BLEED - MORNING EDITION"))
        XCTAssertTrue(body.contains("Issue #7"))
        XCTAssertTrue(body.contains("CASEMENT WEATHER"))
        XCTAssertTrue(body.contains("THE READER'S SHELF: SAILING"))
        XCTAssertTrue(body.contains("P. Blackletter"))
    }

    func testFrontPagePacketIncludesWorldEventDesk() {
        let savedOwned = PackEntitlements.ownedPackIDs
        defer { PackEntitlements.ownedPackIDs = savedOwned }
        PackEntitlements.ownedPackIDs = ["dictionary-rebellion"]
        let september = BookDay(id: "2026-09-10", date: septemberDate(10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs = inputs.resolvingWorldEvents(for: september, now: septemberDate(10, hour: 8))

        let packet = TheBleedEditionBuilder.frontPagePacket(kind: .morning, day: september, inputs: inputs)

        XCTAssertTrue(packet.contains("Active world-event desk"))
        XCTAssertTrue(packet.contains("The Dictionary Rebellion"))
        XCTAssertTrue(packet.contains("Treat the rebellion as live campus news"))
    }

    func testPennysLedgerReceivesSemanticMultimodalAndLivedEvidence() {
        let evidencePage = BookPage(
            id: "harbor-photo-proof",
            type: .elective,
            createdAt: date(6, hour: 18),
            promptText: "Bring back the harbor light",
            userInput: "The brass rail held the sunset while the ferry folded its wake.",
            tags: ["harbor", "light", "return"],
            origin: .userAuthored,
            mediaAssets: [
                // The reader's own photograph. A bare rendered image file is a
                // Book-made plate and no longer counts as a reader photograph,
                // so a multimodal witness has to actually have one.
                BookPageMediaAsset(
                    kind: .photoLibraryAsset,
                    reference: "/private/local/harbor.jpg",
                    caption: "Harbor proof",
                    sourceID: "elective"
                )
            ],
            sensoryFolio: SensoryFolio(
                observations: [
                    SensoryObservation(dimension: .modality, value: "photo", confidence: 1, extractorID: "test"),
                    SensoryObservation(dimension: .subject, value: "brass rail", confidence: 0.9, extractorID: "test"),
                    SensoryObservation(dimension: .palette, value: "amber and blue", confidence: 0.8, extractorID: "test"),
                    SensoryObservation(dimension: .composition, value: "wide horizon", confidence: 0.8, extractorID: "test")
                ]
            ),
            livedQuestReceipt: LivedQuestReceipt(
                kind: .elective,
                questID: "harbor-return",
                title: "Bring Back the Harbor Light",
                invitation: "Find one light worth returning with.",
                proofPrompt: "Bring back a sentence or photograph.",
                facets: [.exactAttention, .deliberateReturn],
                sourceTags: ["harbor", "light"],
                hasWrittenProof: true,
                hasVisualProof: true,
                completedAt: date(6, hour: 18),
                wasPromptedByBook: true
            )
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [
            BookDay(id: "2026-06-06", date: date(6, hour: 0), pages: [evidencePage])
        ]
        inputs.continuity = LiteraryContinuityDigest(
            signals: [
                LiteraryContinuitySignal(
                    id: "sensory-harbor-light",
                    kind: .sensory,
                    subjectID: "harbor-light",
                    subjectName: "Harbor Light",
                    line: "A photograph and a later sentence gathered around the same brass-colored return.",
                    evidencePageIDs: [evidencePage.id],
                    relatedEntityIDs: [],
                    tags: ["harbor", "light", "return"],
                    firstSeenAt: date(2, hour: 10),
                    lastSeenAt: date(6, hour: 18),
                    strength: 78
                )
            ],
            beliefLifecycles: []
        )

        let packet = TheBleedEditionBuilder.frontPagePacket(
            kind: .morning,
            day: day,
            inputs: inputs,
            now: date(10, hour: 8),
            calendar: calendar
        )

        XCTAssertTrue(packet.contains("SEMANTICALLY SELECTED PASSAGES"))
        XCTAssertTrue(packet.contains(evidencePage.id))
        XCTAssertTrue(packet.contains("MULTIMODAL WITNESSES"))
        XCTAssertTrue(packet.contains("subjects brass rail"))
        XCTAssertTrue(packet.contains("palette amber and blue"))
        XCTAssertTrue(packet.contains("CROSS-MEDIA CONTINUITY"))
        XCTAssertTrue(packet.contains("LIVED QUEST RECEIPTS"))
        XCTAssertTrue(packet.contains("written + photograph evidence"))
        XCTAssertTrue(packet.contains("A photograph may attest objects"))
    }

    func testCorridorWhispersUsesTheGossipPageSourcePacketAndEditorialLaw() {
        let packet = TheBleedEditionBuilder.whispersPacket(
            day: day,
            inputs: .empty,
            now: date(10, hour: 8)
        )
        let prompt = GossipPageForm.bleedColumnPrompt(
            title: "Corridor Whispers",
            packet: packet,
            pennyCanon: "Penny canon"
        )

        XCTAssertTrue(packet.contains("same source packet used by a Gossip Page"))
        XCTAssertTrue(packet.contains("GOSSIP PAGE MODE"))
        XCTAssertTrue(packet.contains("SIMULATION TURNS"))
        XCTAssertTrue(prompt.contains("Keep every actor, thread, action, visible trace, and consequence"))
        XCTAssertTrue(prompt.contains("What changed"))
        XCTAssertTrue(prompt.contains("Penny may add one dry editor's aside"))
    }

    func testIssueSelectsAtMostTwoRecentKeptVisualPlatesWithProvenance() throws {
        let illuminated = BookPage(
            id: "recent-illumination",
            type: .illuminatedPhoto,
            createdAt: date(8, hour: 18),
            promptText: "The Kettle Kept Watch",
            userInput: "Blue light stayed on the handle.",
            sourceID: "illuminated-photo",
            origin: .generated,
            mediaAssets: [
                BookPageMediaAsset(
                    id: "illumination-image",
                    kind: .bundledImage,
                    reference: "TestIllumination",
                    caption: "Original illumination",
                    sourceID: "illuminated-photo"
                )
            ]
        )
        let pagewright = BookPage(
            id: "recent-pagewright",
            type: .plainPage,
            createdAt: date(9, hour: 18),
            promptText: "A Pagewright Weather Map",
            userInput: "Three scraps agreed on rain.",
            tags: ["pagewright", "scrapbook"],
            sourceID: "plain-page",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    id: "pagewright-image",
                    kind: .renderedImageFile,
                    reference: "/private/local/pagewright.png",
                    caption: "Original Pagewright caption",
                    sourceID: "plain-page",
                    metadata: ["format": "png"]
                )
            ]
        )
        let forbiddenShare = BookPage(
            id: "shared-but-not-weavable",
            type: .plainPage,
            createdAt: date(10, hour: 7),
            promptText: "A Shared Photograph",
            userInput: "A photograph from elsewhere.",
            sourceID: "external-share:example",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    id: "forbidden-image",
                    kind: .renderedImageFile,
                    reference: "/private/local/forbidden.png",
                    sourceID: "external-share:example"
                )
            ],
            externalReference: BookPageExternalReference(
                title: "A Shared Photograph",
                sourceName: "Example",
                url: "https://example.com/post",
                fetchedAt: date(10, hour: 7),
                provenance: "share-extension",
                captureID: "capture-forbidden",
                wasPromptedByBook: false,
                learningAllowed: true,
                weavingAllowed: false,
                attachments: []
            )
        )
        var inputs = BookSourceInputs.empty
        inputs.days = [
            BookDay(
                id: "2026-06-visuals",
                date: date(10, hour: 0),
                pages: [illuminated, pagewright, forbiddenShare]
            )
        ]

        let announcement = try XCTUnwrap(
            TheBleedEditionBuilder.announcementSurface(
                for: day,
                inputs: inputs,
                now: date(10, hour: 8),
                calendar: calendar
            )
        )
        let plates = announcement.mediaAssets

        XCTAssertEqual(plates.count, 2)
        XCTAssertTrue(plates.contains { $0.metadata["bleedPlatePageID"] == illuminated.id })
        XCTAssertTrue(plates.contains { $0.metadata["bleedPlatePageID"] == pagewright.id })
        XCTAssertFalse(plates.contains { $0.metadata["bleedPlatePageID"] == forbiddenShare.id })
        XCTAssertTrue(plates.allSatisfy { $0.caption.contains("kept") })
        XCTAssertEqual(
            Set(announcement.payload.metadata["bleedPlatePageIDs"]?.split(separator: ",").map(String.init) ?? []),
            Set([illuminated.id, pagewright.id])
        )
    }

    func testPreparedCopyCarriesProseAndDropsPlaceholder() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing")]
        let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: date(10, hour: 8), calendar: calendar)!
        let prepared = TheBleedEditionBuilder.preparedCopy(of: announcement, body: "THE PAPER", interestSources: "https://example.com")
        XCTAssertEqual(prepared.payload.metadata["bleedProse"], "THE PAPER")
        XCTAssertNil(prepared.payload.metadata["placeholder"])
        XCTAssertEqual(prepared.payload.body, "THE PAPER")
        XCTAssertEqual(prepared.id, announcement.id)
        XCTAssertFalse(SurfaceReadinessState(surface: prepared).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(surface: announcement).needsLocalBrainToOpen)
    }

    func testAdapterPrefersPreparedEdition() {
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [interestFact("interest-01", "sailing")]
        let now = date(10, hour: 8)
        let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: now, calendar: calendar)!
        inputs.preparedBleedEditionSurface = TheBleedEditionBuilder.preparedCopy(of: announcement, body: "THE PAPER", interestSources: "")
        let pages = TheBleedPageSourceAdapter().candidates(for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].payload.metadata["bleedProse"], "THE PAPER")
    }
}
