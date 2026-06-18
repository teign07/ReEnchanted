import XCTest
@testable import InsideCoverCore

final class ConstellationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func signal(
        id: String = "pattern-harbor",
        kind: LiterarySignalKind = .pattern,
        subjectID: String = "harbor",
        subjectName: String = "Harbor",
        strength: Int = 70,
        at seen: Date
    ) -> LiteraryContinuitySignal {
        LiteraryContinuitySignal(
            id: id,
            kind: kind,
            subjectID: subjectID,
            subjectName: subjectName,
            line: "The word harbor has gathered across kept pages.",
            evidencePageIDs: ["page-1", "page-2", "page-3"],
            relatedEntityIDs: [],
            tags: [subjectID, "pattern", "literary-continuity"],
            firstSeenAt: seen,
            lastSeenAt: seen,
            strength: strength
        )
    }

    private func digest(_ signals: [LiteraryContinuitySignal]) -> LiteraryContinuityDigest {
        LiteraryContinuityDigest(signals: signals, beliefLifecycles: [])
    }

    private func continuityPage(id: String, day: Int, text: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: date(2026, 5, day),
            promptText: "Souvenir",
            userInput: text
        )
    }

    private func continuityDay(_ day: Int, pages: [BookPage]) -> BookDay {
        BookDay(
            id: String(format: "2026-05-%02d", day),
            date: date(2026, 5, day, hour: 0),
            pages: pages
        )
    }

    // MARK: Continuity signal quality

    func testContinuityProjectorKeepsMotifsButDropsWeakSubjects() {
        let days = [
            continuityDay(1, pages: [continuityPage(id: "p1", day: 1, text: "The harbor felt flat after the scene fell out of climax.")]),
            continuityDay(2, pages: [continuityPage(id: "p2", day: 2, text: "At the harbor, the same flat line fell through the chapter climax.")]),
            continuityDay(3, pages: [continuityPage(id: "p3", day: 3, text: "The harbor light returned while flat, fell, and climax stayed as scaffolding.")])
        ]

        let digest = LiteraryContinuityProjector.digest(
            days: days,
            events: [],
            entityMemories: [],
            now: date(2026, 5, 4),
            calendar: calendar
        )

        XCTAssertTrue(digest.signals.contains { $0.subjectID == "harbor" })
        XCTAssertFalse(digest.signals.contains { ["flat", "fell", "climax", "scene", "chapter"].contains($0.subjectID) })
    }

    // MARK: Lifecycle

    func testConstellationPromotesNoticedToWatchedToNamed() {
        var ledger: [Constellation] = []
        let start = date(2026, 5, 1)

        ledger = ConstellationKeeper.advanced(ledger, observing: digest([signal(at: start)]), now: start, calendar: calendar)
        XCTAssertEqual(ledger.count, 1)
        XCTAssertEqual(ledger[0].phase, .noticed)
        XCTAssertNil(ledger[0].name)

        for offset in 1...2 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            ledger = ConstellationKeeper.advanced(ledger, observing: digest([signal(at: day)]), now: day, calendar: calendar)
        }
        XCTAssertEqual(ledger[0].phase, .watched)
        XCTAssertEqual(ledger[0].sightingCount, 3)

        for offset in 3...15 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            ledger = ConstellationKeeper.advanced(ledger, observing: digest([signal(at: day)]), now: day, calendar: calendar)
        }
        XCTAssertEqual(ledger[0].phase, .woven)
        XCTAssertNotNil(ledger[0].name)
        XCTAssertNotNil(ledger[0].namedAt)
        XCTAssertNotNil(ledger[0].wovenAt)
        XCTAssertTrue(ledger[0].name!.contains("Harbor"))
    }

    func testConstellationNameIsDeterministic() {
        let first = ConstellationKeeper.constellationName(kind: .pattern, subjectName: "Harbor", seed: "constellation-pattern-harbor")
        let second = ConstellationKeeper.constellationName(kind: .pattern, subjectName: "Harbor", seed: "constellation-pattern-harbor")
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.contains("Harbor"))
    }

    func testConstellationFadesWhenQuietAndKeepsNameOnReturn() {
        var ledger: [Constellation] = []
        let start = date(2026, 3, 1)
        for offset in 0...15 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            ledger = ConstellationKeeper.advanced(ledger, observing: digest([signal(at: day)]), now: day, calendar: calendar)
        }
        let name = ledger[0].name
        XCTAssertNotNil(name)

        let quietDay = calendar.date(byAdding: .day, value: 50, to: start)!
        ledger = ConstellationKeeper.advanced(ledger, observing: digest([]), now: quietDay, calendar: calendar)
        XCTAssertEqual(ledger[0].phase, .faded)
        XCTAssertNotNil(ledger[0].fadedAt)

        let returnDay = calendar.date(byAdding: .day, value: 51, to: start)!
        ledger = ConstellationKeeper.advanced(ledger, observing: digest([signal(at: returnDay)]), now: returnDay, calendar: calendar)
        XCTAssertNotEqual(ledger[0].phase, .faded)
        XCTAssertEqual(ledger[0].name, name)
        XCTAssertEqual(ledger[0].returnCount, 1)
    }

    func testNewlyNamedFindsConstellationsNamedToday() {
        var ledger: [Constellation] = []
        let start = date(2026, 4, 1)
        var namedDay: Date?
        for offset in 0...20 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            ledger = ConstellationKeeper.advanced(ledger, observing: digest([signal(at: day)]), now: day, calendar: calendar)
            if namedDay == nil, ledger[0].namedAt != nil {
                namedDay = day
            }
        }
        XCTAssertNotNil(namedDay)
        XCTAssertEqual(ConstellationKeeper.newlyNamed(ledger, on: namedDay!, calendar: calendar).count, 1)
        XCTAssertTrue(ConstellationKeeper.newlyNamed(ledger, on: date(2026, 1, 1), calendar: calendar).isEmpty)
    }

    // MARK: Sealed wagers

    func testWagerMintingRespectsThresholdsAndCap() {
        let now = date(2026, 6, 1)
        let strongPattern = signal(id: "pattern-harbor", subjectID: "harbor", subjectName: "Harbor", strength: 70, at: now)
        let weakPattern = signal(id: "pattern-fog", subjectID: "fog", subjectName: "Fog", strength: 60, at: now)
        let strongAbsence = signal(id: "absence-shoreline", kind: .absence, subjectID: "shoreline", subjectName: "Shoreline", strength: 65, at: now)

        let minted = SealedMarginEngine.mintWagers(
            from: digest([strongPattern, weakPattern, strongAbsence]),
            existing: [],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(minted.count, 2)
        XCTAssertTrue(minted.allSatisfy(\.isSealed))
        XCTAssertFalse(minted.contains { $0.subjectID == "fog" })

        let again = SealedMarginEngine.mintWagers(
            from: digest([strongPattern, strongAbsence]),
            existing: minted,
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(again.isEmpty)
    }

    func testWagerResolvesRightWhenSubjectReturns() {
        let sealedAt = date(2026, 6, 1)
        let minted = SealedMarginEngine.mintWagers(
            from: digest([signal(strength: 70, at: sealedAt)]),
            existing: [],
            now: sealedAt,
            calendar: calendar
        )
        XCTAssertEqual(minted.count, 1)

        let keptDay = BookDay(
            id: "2026-06-05",
            date: date(2026, 6, 5, hour: 0),
            pages: [
                BookPage(id: "return", type: .souvenir, createdAt: date(2026, 6, 5), promptText: "Souvenir", userInput: "Back at the harbor, the rope smelled of tar.")
            ]
        )
        let openDay = date(2026, 6, 20)
        let resolved = SealedMarginEngine.resolved(minted, against: [keptDay], now: openDay, calendar: calendar)
        XCTAssertEqual(resolved[0].status, .right)
        XCTAssertNotNil(resolved[0].resolutionLine)

        let resolvedWrong = SealedMarginEngine.resolved(minted, against: [], now: openDay, calendar: calendar)
        XCTAssertEqual(resolvedWrong[0].status, .wrong)
        XCTAssertTrue(resolvedWrong[0].resolutionLine?.contains("wrong") == true)
    }

    func testWagerStaysSealedBeforeOpenDate() {
        let sealedAt = date(2026, 6, 1)
        let minted = SealedMarginEngine.mintWagers(
            from: digest([signal(strength: 70, at: sealedAt)]),
            existing: [],
            now: sealedAt,
            calendar: calendar
        )
        let early = SealedMarginEngine.resolved(minted, against: [], now: date(2026, 6, 5), calendar: calendar)
        XCTAssertEqual(early[0].status, .sealed)
    }

    // MARK: Book Notices surfaces

    func testAdapterSurfacesNamingAndWagerPages() {
        let now = date(2026, 6, 10)
        let day = BookDay(id: "2026-06-10", date: date(2026, 6, 10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.constellations = [
            Constellation(
                id: "constellation-pattern-harbor",
                signalID: "pattern-harbor",
                kind: .pattern,
                subjectID: "harbor",
                subjectName: "Harbor",
                name: "The Harbor Thread",
                phase: .named,
                firstNoticedAt: date(2026, 5, 1),
                lastSeenAt: now,
                namedAt: now,
                sightingDayIDs: ["a", "b", "c", "d", "e"],
                strengthPeak: 80,
                latestLine: "The word harbor has gathered across kept pages.",
                evidencePageIDs: ["page-1"],
                relatedEntityIDs: [],
                tags: ["harbor"]
            )
        ]
        inputs.wagers = [
            BookWager(
                id: "wager-sealed-today",
                subjectID: "fog",
                subjectName: "Fog",
                kind: .pattern,
                prediction: "Fog will return within 14 days.",
                sealedAt: now,
                opensAt: date(2026, 6, 24),
                status: .sealed,
                basisSignalID: "pattern-fog",
                basisLine: "The word fog has gathered."
            ),
            BookWager(
                id: "wager-opened-today",
                subjectID: "shoreline",
                subjectName: "Shoreline",
                kind: .absence,
                prediction: "Shoreline will appear again within 21 days.",
                sealedAt: date(2026, 5, 15),
                opensAt: date(2026, 6, 5),
                status: .right,
                resolvedAt: now,
                resolutionLine: "I was right.",
                basisSignalID: "absence-shoreline",
                basisLine: "Shoreline went quiet."
            )
        ]
        let pages = BookNoticesPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        XCTAssertTrue(pages.contains { $0.payload.headline.contains("The Harbor Thread") })
        XCTAssertTrue(pages.contains { $0.payload.metadata["wagerMoment"] == "sealed" })
        XCTAssertTrue(pages.contains { $0.payload.metadata["wagerMoment"] == "opened" && $0.payload.headline.contains("Right") })
    }

    // MARK: Letters

    func testFirstLetterIsIntroductionLetter() {
        let now = date(2026, 6, 10)
        let day = BookDay(id: "2026-06-10", date: date(2026, 6, 10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.continuity = LiteraryContinuityDigest(
            signals: [signal(id: "absence-shoreline", kind: .absence, subjectID: "shoreline", subjectName: "Shoreline", strength: 70, at: now)],
            beliefLifecycles: []
        )
        let draft = CharacterLetterPageGenerator.draftCandidate(for: day, inputs: inputs, now: now)
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.payload.metadata["letterRelationshipStage"], "introduction")
        XCTAssertTrue(draft?.payload.metadata["letterOccasion"]?.contains("first letter") == true)
        XCTAssertTrue(draft?.payload.body.contains("Introduce yourself before asking anything") == true)
    }

    func testLetterUsesAbsenceSignalAsOccasion() {
        let now = date(2026, 6, 10)
        let entity = NarrativePackRegistry.entities.first { $0.id == "penny-blackletter" }!
        let priorLetter = BookPage(
            type: .letter,
            createdAt: date(2026, 6, 8),
            promptText: "Letter from \(entity.name)",
            userInput: "Dear friend, I noticed the harbor again.",
            tags: ["letter", "sender:\(entity.id)"]
        )
        let day = BookDay(id: "2026-06-10", date: date(2026, 6, 10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.days = [BookDay(id: "2026-06-08", date: date(2026, 6, 8, hour: 0), pages: [priorLetter])]
        inputs.continuity = LiteraryContinuityDigest(
            signals: [signal(id: "absence-shoreline", kind: .absence, subjectID: "shoreline", subjectName: "Shoreline", strength: 70, at: now)],
            beliefLifecycles: []
        )
        let draft = CharacterLetterPageGenerator.draftCandidate(
            for: entity,
            source: BookPageSourceRegistry.source(for: .letter),
            day: day,
            inputs: inputs,
            now: now
        )
        let occasion = draft.payload.metadata["letterOccasion"] ?? ""
        XCTAssertEqual(draft.payload.metadata["letterRelationshipStage"], "continuing")
        XCTAssertTrue(occasion.contains("Shoreline"))
        XCTAssertTrue(draft.payload.body.contains("Letter occasion:"))
    }

    func testLetterPacketMentionsNamedConstellations() {
        let now = date(2026, 6, 10)
        let day = BookDay(id: "2026-06-10", date: date(2026, 6, 10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.constellations = [
            Constellation(
                id: "constellation-pattern-harbor",
                signalID: "pattern-harbor",
                kind: .pattern,
                subjectID: "harbor",
                subjectName: "Harbor",
                name: "The Harbor Thread",
                phase: .named,
                firstNoticedAt: date(2026, 5, 1),
                lastSeenAt: now,
                namedAt: date(2026, 6, 1),
                sightingDayIDs: ["a", "b", "c", "d", "e"],
                strengthPeak: 80,
                latestLine: "Harbors keep gathering.",
                evidencePageIDs: [],
                relatedEntityIDs: [],
                tags: ["harbor"]
            )
        ]
        let draft = CharacterLetterPageGenerator.draftCandidate(for: day, inputs: inputs, now: now)
        XCTAssertTrue(draft?.payload.body.contains("The Harbor Thread") == true)
    }

    // MARK: Foreword

    func testForewordMentionsCountsNamesAndWagers() {
        let foreword = BookForewordWriter.foreword(
            monthTitle: "May 2026",
            pages: [
                BookPage(id: "p1", type: .souvenir, createdAt: date(2026, 5, 2), promptText: "Souvenir", userInput: "The harbor kept its minutes.")
            ],
            dayCount: 1,
            continuity: digest([signal(strength: 70, at: date(2026, 5, 2))]),
            constellations: [
                Constellation(
                    id: "constellation-pattern-harbor",
                    signalID: "pattern-harbor",
                    kind: .pattern,
                    subjectID: "harbor",
                    subjectName: "Harbor",
                    name: "The Harbor Thread",
                    phase: .named,
                    firstNoticedAt: date(2026, 4, 1),
                    lastSeenAt: date(2026, 5, 30),
                    namedAt: date(2026, 5, 10),
                    sightingDayIDs: ["a", "b", "c", "d", "e"],
                    strengthPeak: 80,
                    latestLine: "Harbors keep gathering.",
                    evidencePageIDs: [],
                    relatedEntityIDs: [],
                    tags: ["harbor"]
                )
            ],
            wagers: [
                BookWager(
                    id: "w1",
                    subjectID: "fog",
                    subjectName: "Fog",
                    kind: .pattern,
                    prediction: "Fog returns.",
                    sealedAt: date(2026, 5, 1),
                    opensAt: date(2026, 5, 15),
                    status: .wrong,
                    resolvedAt: date(2026, 5, 15),
                    resolutionLine: "I was wrong.",
                    basisSignalID: "pattern-fog",
                    basisLine: "Fog gathered."
                )
            ],
            calendar: calendar
        )
        XCTAssertTrue(foreword.contains("May 2026"))
        XCTAssertTrue(foreword.contains("The Harbor Thread"))
        XCTAssertTrue(foreword.contains("wrong"))
        XCTAssertTrue(foreword.hasSuffix("- The Book"))
    }

    func testMonthlyEditionCarriesForeword() {
        let now = date(2026, 7, 12)
        let june = BookDay(
            id: "2026-06-03",
            date: date(2026, 6, 3, hour: 0),
            pages: [
                BookPage(id: "souvenir", type: .souvenir, createdAt: date(2026, 6, 3), promptText: "Souvenir", userInput: "The harbor kept its minutes.")
            ]
        )
        let edition = MonthlyEditionBuilder.previousMonth(from: [june], now: now, calendar: calendar)
        XCTAssertFalse(edition.foreword.isEmpty)
        XCTAssertTrue(edition.foreword.contains("June 2026"))
    }

    func testAnnualEditionSpansTheYear() {
        let now = date(2027, 1, 5)
        let june = BookDay(
            id: "2026-06-03",
            date: date(2026, 6, 3, hour: 0),
            pages: [
                BookPage(id: "souvenir", type: .souvenir, createdAt: date(2026, 6, 3), promptText: "Souvenir", userInput: "The harbor kept its minutes.")
            ]
        )
        let outside = BookDay(
            id: "2025-12-31",
            date: date(2025, 12, 31, hour: 0),
            pages: [
                BookPage(id: "old", type: .souvenir, createdAt: date(2025, 12, 31), promptText: "Old", userInput: "Last year.")
            ]
        )
        let annual = MonthlyEditionBuilder.annual(2026, from: [june, outside], now: now, calendar: calendar)
        XCTAssertEqual(annual.title, "Book of You: The 2026 Annual")
        XCTAssertEqual(annual.pageCount, 1)
        // Only the in-year month (June) becomes a chapter; last year is excluded.
        XCTAssertEqual(annual.chapters.count, 1)
        XCTAssertEqual(annual.chapters.first?.monthName, "June 2026")
    }

    // MARK: Export

    func testArchiveExportCarriesContinuityAndConstellations() throws {
        let cluster = BookMotifCluster(
            id: "cluster-shoreline",
            name: "The Shoreline Cluster",
            family: "shoreline",
            line: "Water, weather, and places of return are gathering into one margin.",
            motifs: ["fog", "harbor"],
            strength: 78,
            signalIDs: ["pattern-harbor"],
            constellationIDs: ["constellation-pattern-harbor"],
            themeIDs: ["theme-2026-06"],
            evidencePageIDs: [],
            discoveredAt: date(2026, 6, 10)
        )
        let export = BookArchiveExport(
            days: [],
            continuity: digest([signal(strength: 70, at: date(2026, 6, 1))]),
            constellations: [
                Constellation(
                    id: "constellation-pattern-harbor",
                    signalID: "pattern-harbor",
                    kind: .pattern,
                    subjectID: "harbor",
                    subjectName: "Harbor",
                    name: "The Harbor Thread",
                    phase: .named,
                    firstNoticedAt: date(2026, 5, 1),
                    lastSeenAt: date(2026, 6, 1),
                    namedAt: date(2026, 5, 20),
                    sightingDayIDs: ["a"],
                    strengthPeak: 80,
                    latestLine: "Harbors keep gathering.",
                    evidencePageIDs: [],
                    relatedEntityIDs: [],
                    tags: ["harbor"]
                )
            ],
            wagers: [],
            themes: [
                BookTheme(
                    id: "theme-2026-06",
                    monthKey: "2026-06",
                    name: "Harbors and Lamps",
                    motifs: ["harbor", "lamp"],
                    line: "The month kept returning to harbors and lamps.",
                    strength: 72,
                    evidencePageIDs: [],
                    excerptLines: [],
                    discoveredAt: date(2026, 6, 10)
                )
            ],
            clusters: [cluster],
            calendar: calendar
        )
        let data = try export.encodedData()
        let decoded = try BookArchiveExport.decoded(from: data)
        XCTAssertEqual(decoded.constellations?.first?.name, "The Harbor Thread")
        XCTAssertEqual(decoded.continuity?.signals.count, 1)
        XCTAssertEqual(decoded.themes?.first?.name, "Harbors and Lamps")
        XCTAssertEqual(decoded.clusters?.first?.name, "The Shoreline Cluster")
        XCTAssertEqual(decoded.schemaVersion, 2)
    }

    // MARK: Clusters

    func testMotifClusterEngineFindsShorelineCluster() {
        let now = date(2026, 6, 10)
        let digest = LiteraryContinuityDigest(
            signals: [
                signal(id: "pattern-harbor", subjectID: "harbor", subjectName: "Harbor", strength: 74, at: now),
                signal(id: "pattern-fog", subjectID: "fog", subjectName: "Fog", strength: 66, at: now)
            ],
            beliefLifecycles: []
        )
        let clusters = BookMotifClusterEngine.clusters(from: digest, constellations: [], themes: [], now: now)
        XCTAssertEqual(clusters.first?.name, "The Shoreline Cluster")
        XCTAssertTrue(clusters.first?.motifs.contains("harbor") == true)
        XCTAssertTrue(clusters.first?.motifs.contains("fog") == true)
        XCTAssertTrue((clusters.first?.strength ?? 0) >= 58)
    }

    func testBookNoticesSurfaceCanLeadWithCluster() {
        let now = date(2026, 6, 10)
        let day = BookDay(id: "2026-06-10", date: date(2026, 6, 10, hour: 0), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.continuity = LiteraryContinuityDigest(
            signals: [
                signal(id: "pattern-harbor", subjectID: "harbor", subjectName: "Harbor", strength: 74, at: now),
                signal(id: "pattern-fog", subjectID: "fog", subjectName: "Fog", strength: 66, at: now)
            ],
            beliefLifecycles: []
        )
        inputs.clusters = BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: [], themes: [], now: now)

        let pages = BookNoticesPageSourceAdapter().candidates(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(pages.first?.payload.body.contains("The Shoreline Cluster") == true)
        XCTAssertTrue(pages.first?.payload.metadata["motifClusters"]?.contains("The Shoreline Cluster") == true)
    }

    // MARK: Gossip

    func testGossipIsSpecificWithQuotesWitnessAndReaderEcho() {
        let now = date(2026, 6, 10)
        let day = BookDay(
            id: "2026-06-10",
            date: date(2026, 6, 10, hour: 0),
            pages: [
                BookPage(id: "d1", type: .diary, createdAt: date(2026, 6, 10, hour: 9), promptText: "Diary", userInput: "Walked the long way past the harbor and watched the ferries trade places."),
                BookPage(id: "d2", type: .mood, createdAt: date(2026, 6, 10, hour: 10), promptText: "Mood", userInput: "Steady, like a kept lamp in daylight hours today.")
            ]
        )
        let surface = GossipSimulationBuilder.surface(for: day, inputs: .empty, now: now)
        let body = surface.payload.body
        XCTAssertTrue(body.contains("Overheard"), "gossip should still be overheard")
        XCTAssertTrue(body.contains("\""), "gossip should carry quoted speech")
        XCTAssertTrue(
            body.contains("If it works") || body.contains("What is at stake") || body.contains("The margins disagreed."),
            "gossip should state stakes"
        )
        XCTAssertTrue(
            body.contains("The margins matched it to one of the reader's own kept pages"),
            "gossip should call back to the reader's day"
        )
        let tags = (surface.payload.metadata["tags"] ?? "").split(separator: ",").map(String.init)
        XCTAssertTrue(tags.contains { $0.hasPrefix("witness:") }, "gossip should record its witness")
        XCTAssertTrue(surface.payload.metadata["simulationPacket"]?.isEmpty == false)
    }

    func testGossipIsDeterministicForSameDayAndSlot() {
        let now = date(2026, 6, 10)
        let day = BookDay(id: "2026-06-10", date: date(2026, 6, 10, hour: 0), pages: [])
        let first = GossipSimulationBuilder.surface(for: day, inputs: .empty, now: now)
        let second = GossipSimulationBuilder.surface(for: day, inputs: .empty, now: now)
        XCTAssertEqual(first.payload.body, second.payload.body)
    }
}

// MARK: - Themes

final class BookThemeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day, hour: hour))!
    }

    private func page(_ id: String, day: Int, text: String) -> BookPage {
        BookPage(id: id, type: .diary, createdAt: date(2026, 6, day), promptText: "Diary", userInput: text)
    }

    private var harborPages: [BookPage] {
        [
            page("p1", day: 1, text: "Kept a secret about the harbor today, and told no one."),
            page("p2", day: 3, text: "The harbor was grey and the secret stayed warm in my pocket."),
            page("p3", day: 6, text: "Another harbor walk; the secret is becoming a friend."),
            page("p4", day: 9, text: "Secrets weigh less near water. Harbor again."),
            page("p5", day: 12, text: "The harbor at dusk. I almost told the secret to a gull.")
        ]
    }

    func testThemeEngineFindsAndNamesTheme() {
        let theme = BookThemeEngine.theme(
            for: harborPages,
            digest: .empty,
            monthKey: "2026-06",
            now: date(2026, 6, 15)
        )
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.monthKey, "2026-06")
        XCTAssertTrue(theme!.motifs.contains("harbor"))
        XCTAssertTrue(theme!.motifs.contains("secret") || theme!.motifs.contains("secrets"))
        XCTAssertTrue(theme!.name.lowercased().contains("harbor") || theme!.name.lowercased().contains("secret"))
        XCTAssertFalse(theme!.line.isEmpty)
        XCTAssertFalse(theme!.excerptLines.isEmpty)
    }

    func testThemeIsDeterministic() {
        let first = BookThemeEngine.theme(for: harborPages, digest: .empty, monthKey: "2026-06", now: date(2026, 6, 15))
        let second = BookThemeEngine.theme(for: harborPages, digest: .empty, monthKey: "2026-06", now: date(2026, 6, 15))
        XCTAssertEqual(first?.name, second?.name)
        XCTAssertEqual(first?.motifs, second?.motifs)
    }

    func testThemeNeedsEnoughMaterial() {
        let sparse = [page("p1", day: 1, text: "Hello.")]
        XCTAssertNil(BookThemeEngine.theme(for: sparse, digest: .empty, monthKey: "2026-06", now: date(2026, 6, 15)))
    }

    func testRememberedThemesKeepOldMonths() {
        let may = BookTheme(
            id: "theme-2026-05",
            monthKey: "2026-05",
            name: "Rain and Lamps",
            motifs: ["rain", "lamps"],
            line: "Rain ran under May.",
            strength: 50,
            evidencePageIDs: [],
            excerptLines: [],
            discoveredAt: date(2026, 5, 30)
        )
        let june = BookThemeEngine.theme(for: harborPages, digest: .empty, monthKey: "2026-06", now: date(2026, 6, 15))
        let remembered = BookThemeEngine.remembered([may], observing: june, monthKey: "2026-06")
        XCTAssertEqual(remembered.count, 2)
        XCTAssertEqual(BookThemeEngine.theme(forMonth: "2026-05", in: remembered)?.name, "Rain and Lamps")
        XCTAssertNotNil(BookThemeEngine.theme(forMonth: "2026-06", in: remembered))
    }

    func testEditionCarriesChapterHeadingAndThemeSection() {
        let days = [
            BookDay(id: "2026-05-10", date: date(2026, 5, 10, hour: 0), pages: [page("may", day: 10, text: "May page.")]),
            BookDay(id: "2026-06-03", date: date(2026, 6, 3, hour: 0), pages: harborPages)
        ]
        let edition = MonthlyEditionBuilder.previousMonth(
            from: days,
            readerName: "bj",
            now: date(2026, 7, 12),
            calendar: calendar
        )
        XCTAssertEqual(edition.readerName, "bj")
        XCTAssertEqual(edition.chapterNumber, 2)
        XCTAssertEqual(edition.chapterHeading, "The Book of You - bj - Chapter 2 - June 2026")
        XCTAssertNotNil(edition.theme)
        XCTAssertEqual(edition.subtitle, edition.theme?.name)
        XCTAssertTrue(edition.sections.contains { $0.id == "the-months-theme" && !$0.items.isEmpty })
    }

    func testRememberedThemeWinsOverFreshComputation() {
        let pinned = BookTheme(
            id: "theme-2026-06",
            monthKey: "2026-06",
            name: "Secrets and Harbors",
            motifs: ["secret", "harbor"],
            line: "Secrets ran under June.",
            strength: 80,
            evidencePageIDs: [],
            excerptLines: ["The harbor kept its minutes."],
            discoveredAt: date(2026, 6, 30)
        )
        let days = [BookDay(id: "2026-06-03", date: date(2026, 6, 3, hour: 0), pages: harborPages)]
        let edition = MonthlyEditionBuilder.previousMonth(
            from: days,
            themes: [pinned],
            readerName: "bj",
            now: date(2026, 7, 12),
            calendar: calendar
        )
        XCTAssertEqual(edition.theme?.name, "Secrets and Harbors")
        XCTAssertEqual(edition.subtitle, "Secrets and Harbors")
    }

    // MARK: - Listening constellations

    func testRecordListeningAccumulatesDistinctDays() {
        var state = RadioPlaybackState.off
        state.recordListening(stationID: "thornwave", now: date(2026, 6, 1), calendar: calendar)
        state.recordListening(stationID: "thornwave", now: date(2026, 6, 1, hour: 20), calendar: calendar)
        state.recordListening(stationID: "thornwave", now: date(2026, 6, 2), calendar: calendar)

        XCTAssertEqual(state.daysHeard(stationID: "thornwave"), 2)
        XCTAssertEqual(state.listening?["thornwave"]?.sessions, 3)
    }

    func testListeningSignalsRespectNoticeThreshold() {
        var state = RadioPlaybackState.off
        state.recordListening(stationID: "thornwave", now: date(2026, 6, 1), calendar: calendar)
        state.recordListening(stationID: "thornwave", now: date(2026, 6, 2), calendar: calendar)
        // Only two days — below the notice threshold.
        XCTAssertTrue(RadioStationRegistry.listeningSignals(state: state, now: date(2026, 6, 2)).isEmpty)

        state.recordListening(stationID: "thornwave", now: date(2026, 6, 3), calendar: calendar)
        let signals = RadioStationRegistry.listeningSignals(state: state, now: date(2026, 6, 3))
        XCTAssertEqual(signals.count, 1)
        let signal = signals[0]
        XCTAssertEqual(signal.kind, .listening)
        XCTAssertEqual(signal.subjectID, "radio:thornwave")
        XCTAssertEqual(signal.subjectName, "Thornwave")
        XCTAssertGreaterThanOrEqual(signal.strength, ConstellationKeeper.noticeThreshold)
    }

    func testListeningConstellationCanBeNamedOverTime() {
        var state = RadioPlaybackState.off
        var constellations: [Constellation] = []
        // The companion arc is a slow burn: founding needs 3 days of listening,
        // then five sightings and two weeks of age before the Book names it.
        let days = [1, 3, 5, 8, 12, 16, 20]
        for day in days {
            let now = date(2026, 6, day)
            state.recordListening(stationID: "thornwave", now: now, calendar: calendar)
            var digest = LiteraryContinuityDigest(signals: [], beliefLifecycles: [])
            digest.signals = RadioStationRegistry.listeningSignals(state: state, now: now)
            constellations = ConstellationKeeper.advanced(constellations, observing: digest, now: now, calendar: calendar)
        }

        let radio = constellations.first { $0.subjectID == "radio:thornwave" }
        XCTAssertNotNil(radio)
        XCTAssertEqual(radio?.phase, .named)
        XCTAssertEqual(radio?.name, ConstellationKeeper.constellationName(kind: .listening, subjectName: "Thornwave", seed: radio!.id))
    }

    func testListeningConstellationNamesAreCompanionable() {
        let name = ConstellationKeeper.constellationName(kind: .listening, subjectName: "Mothlight Beats", seed: "constellation-radio-listening-mothlight-beats")
        XCTAssertTrue(
            ["Frequency", "You and", "After Midnight", "Tuned to"].contains { name.contains($0) },
            "Unexpected listening name: \(name)"
        )
    }
}
