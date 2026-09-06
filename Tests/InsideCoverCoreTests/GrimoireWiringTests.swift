import XCTest
@testable import InsideCoverCore

/// Does what the projectors *say* match what they *do*?
///
/// The bug that prompted this: a test hand-built a ledger using a feature id no
/// projector has ever emitted, so it proved the engine and not the wiring, and a
/// whole shape could not fire on real data while its test stayed green. These
/// are the checks that catch that shape of mistake without anyone remembering to.
final class GrimoireWiringTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// One slice built to touch every registered projector at least once.
    private func richSlice() -> GrimoireSlice {
        // A day the almanac actually marks, so that lane is exercised rather
        // than merely declared. `LiteraryAlmanac.celebrations` carries the
        // bookish anniversaries; an ordinary Tuesday returns nothing and the
        // fixture would only prove the projector stays quiet.
        let anniversary = calendar.date(from: DateComponents(year: 2016, month: 9, day: 22))!
        let date = calendar.date(byAdding: .hour, value: 14, to: anniversary)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let dayID = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)

        let written = BookPage(
            id: "written", type: .diary, createdAt: date,
            promptText: "p",
            userInput: "The lantern swung over the harbour and the kettle sang.",
            tags: ["entity:wicker", "choice:the-long-way", "genre:mystery", "form:letter"],
            origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: date, calendar: calendar, weatherTags: ["rain"],
                bodyScore: 20, nearbyAnchorID: "East Harbor", sleepHours: 4.5
            )
        )
        let run = BookPage(
            id: "run", type: .wonderCompass, createdAt: date,
            promptText: "p", userInput: "That was unreasonably good.",
            tags: [
                "wonder-compass", "concierge:closeToHome",
                "compass-place:indoors", "place-kind:water"
            ],
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar)
        )
        // Reader media and a named person, so the media, sensory and people
        // lanes are exercised rather than merely declared.
        var kept = BookPage(
            id: "kept", type: .souvenir, createdAt: date,
            promptText: "p", userInput: "A slate afternoon, spoken aloud.",
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, calendar: calendar)
        )
        kept.mediaAssets = [
            BookPageMediaAsset(id: "photo", kind: .photoLibraryAsset, reference: "asset://p"),
            BookPageMediaAsset(id: "voice", kind: .audioFile, reference: "/tmp/v.m4a")
        ]
        kept.relationshipReceipt = RelationshipPageReceipt(
            personID: "p1", personName: "Sam", kind: .witness,
            bookOffer: "A small thing for Sam.", evidenceAuthority: "reader-confirmed"
        )
        kept.sensoryFolio = SensoryFolio(
            schemaVersion: SensoryFolio.currentSchemaVersion,
            observations: [
                SensoryObservation(dimension: .modality, value: "photograph", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .subject, value: "harbour", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .palette, value: "slate-dark", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .brightness, value: "dim", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .composition, value: "wide", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .voiceCadence, value: "rapid-paused", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .voiceEnergy, value: "low", confidence: 1, extractorID: "test")
            ],
            vectors: []
        )
        let day = BookDay(id: dayID, date: calendar.startOfDay(for: date), pages: [written, run, kept])

        var entry = DaybookEntry(dayID: dayID, date: date, fidelity: .live)
        entry.weatherTags = ["fog"]
        entry.placeLabel = "West Harbor"
        entry.travelled = true
        entry.daylightMinutes = 8 * 60
        entry.calendarEventCount = 7
        entry.alivenessScore = 9

        let pulse = ReaderStatePulseRecord(
            id: "pulse", dimension: .wonder, score: 9,
            answerCode: "yes", answerLine: "Yes, plainly.",
            askedAt: date, answeredAt: date, dayID: dayID, facets: []
        )

        let bargain = FaeBargain(
            id: "b", faeKind: .sentenceSalamander, slot: "s", giftID: "g",
            giftName: "A Gift", giftEffectLine: "It hums.",
            openingGesture: "A thread.", terms: "Notice one thing.",
            offeredAt: date, deadline: date.addingTimeInterval(86_400),
            status: .delivered, fieldReport: nil, faeResponse: nil,
            rewardText: nil, deliveredAt: date
        )
        let working = BookWorking(
            id: "w", recipeID: "unnecessary-route",
            initiatorKind: .character, initiatorID: "wicker", initiatorName: "Wicker",
            title: "T", summons: "s", invitation: "i", returnPrompt: "r",
            createdAt: date, startsAt: date, endsAt: date,
            status: .returned, effects: [], returnedAt: date
        )
        let signal = LiteraryContinuitySignal(
            id: "harbour", kind: .pattern, subjectID: "harbour", subjectName: "the harbour",
            line: "The harbour keeps coming back.", evidencePageIDs: ["written"],
            relatedEntityIDs: [], tags: [], firstSeenAt: date, lastSeenAt: date, strength: 80
        )

        // A settled errand and an answered aside, so the newest lanes are
        // exercised rather than merely declared.
        let errand = PactErrand(
            id: "e", talismanID: "ember-seal", territoryID: "shelf",
            openingLine: "The seal found a loose border.", terms: "Bring back one true change.",
            offeredAt: date.addingTimeInterval(-86_400 * 3),
            deadline: date.addingTimeInterval(86_400),
            status: .delivered, fieldReport: nil, talismanResponse: nil,
            deliveredAt: date
        )
        var aside = BookAsideReceipt(
            id: "a", servedAt: date.addingTimeInterval(-3_600), surfaceID: "s",
            sourceID: "the-book-notices", intention: "i",
            thoughtKey: "t", wordingKey: "w"
        )
        aside.response = .goOn
        aside.respondedAt = date

        let keepsake = PocketKeepsake(
            id: "k", dayID: dayID, pageType: .souvenir, object: "a ticket stub",
            glyph: "ticket", foundAt: date, sourceSurfaceID: nil,
            title: nil, excerpt: nil, reason: nil, mediaAssets: nil
        )
        let jump = ReturnedBookJump(
            id: "j", bookID: "carroll-wonderland", title: "Wonderland",
            author: "Carroll", returnedAt: date, depth: 2, degradation: 0,
            souvenir: "A tin key.", outcome: "returned"
        )
        var tradition = BookPrivateTradition(
            id: "t", kind: .dogEarDay, title: "Dog-Ear Day",
            observance: "Fold one corner.", originMemoryID: "m",
            evidencePageIDs: [], foundedAt: date.addingTimeInterval(-86_400 * 365),
            cadenceDays: 365, nextDueAt: date.addingTimeInterval(86_400),
            observanceCount: 3
        )
        tradition.lastObservedAt = date

        return GrimoireSlice(
            days: [day],
            daybookRows: [entry],
            readerStatePulses: [pulse],
            peopleNames: ["p1": "Sam"],
            faeBargains: [bargain],
            workings: [working],
            pactErrands: [errand],
            asideReceipts: [aside],
            pocketKeepsakes: [keepsake],
            returnedJumps: [jump],
            traditions: [tradition],
            worldEvents: [
                ResolvedWorldEvent(
                    id: "e", packID: "p", title: "The Dictionary Rebellion",
                    subtitle: "s",
                    phase: WorldEventPhase(
                        id: "ph", title: "Buildup", startsAtProgress: 0,
                        packetLine: "l", intensity: 2, lexicalRules: [], role: .buildup
                    ),
                    startedAt: date.addingTimeInterval(-86_400),
                    endsAt: date.addingTimeInterval(86_400),
                    progress: 0.5,
                    playerTouchCount: 0, effects: [],
                    packet: EventInfluencePacket(
                        logline: "l", atmosphere: "a", storyInstruction: "s",
                        classInstruction: "c", letterInstruction: "le",
                        monthlyEditionLine: "m",
                        fieldworkPrompt: "f", fieldworkPlaceholder: "fp",
                        fieldworkRewardLine: "fr"
                    )
                )
            ],
            continuity: LiteraryContinuityDigest(signals: [signal], beliefLifecycles: []),
            calendar: calendar
        )
    }

    private func everyFeature() -> [LoomFeatureRef] {
        GrimoireProjection.observations(from: richSlice()).flatMap(\.features)
    }

    // MARK: The checks

    /// The real hazard: `intern` keeps the newest description of a feature, so
    /// two projectors emitting the same id with different roles would make that
    /// feature's behaviour depend on the order the archive happened to arrive
    /// in. `weather:` and `place:` are each emitted from two places today.
    func testTheSameFeatureIdNeverArrivesWithTwoDifferentMeanings() {
        var byID: [String: LoomFeatureRef] = [:]
        for feature in everyFeature() {
            guard let seen = byID[feature.id] else {
                byID[feature.id] = feature
                continue
            }
            XCTAssertEqual(seen.domain, feature.domain, "\(feature.id) has two domains")
            XCTAssertEqual(seen.role, feature.role, "\(feature.id) has two roles")
            XCTAssertEqual(seen.provenance, feature.provenance, "\(feature.id) has two provenances")
            XCTAssertEqual(seen.sensitivity, feature.sensitivity, "\(feature.id) has two sensitivities")
            XCTAssertEqual(seen.rank, feature.rank, "\(feature.id) has two ranks")
        }
        XCTAssertFalse(byID.isEmpty)
    }

    /// A declared domain nothing emits is a promise the Book does not keep —
    /// and it is exactly what makes a coverage table read better than the code.
    func testEveryDeclaredDomainIsActuallyProduced() {
        let slice = richSlice()
        for projector in GrimoireProjection.registered {
            // Each projector answered on its own, so a domain declared by one
            // and produced only by another still counts as a broken promise.
            var mine: [LoomFeatureRef] = []
            for day in slice.days {
                mine += projector.features(forDay: day, in: slice)
                for page in day.capturedPages { mine += projector.features(forPage: page, in: slice) }
            }
            for entry in slice.daybookRows { mine += projector.features(forDaybook: entry, in: slice) }
            for pulse in slice.readerStatePulses { mine += projector.features(forPulse: pulse, in: slice) }
            let produced = Set(mine.map(\.domain))
            let missing = projector.domains.filter { !produced.contains($0) }
            XCTAssertTrue(
                missing.isEmpty,
                "\(projector.id) declares \(missing.joined(separator: ", ")) but never emitted it"
            )
        }
    }

    /// And the other direction: something arriving in the ledger that no
    /// projector admits to producing.
    func testEveryProducedDomainWasDeclared() {
        var declared = Set(GrimoireProjection.registered.flatMap { $0.domains })
        declared.insert(GrimoireProjection.blendDomain)
        let undeclared = Set(everyFeature().map(\.domain)).subtracting(declared).sorted()
        XCTAssertTrue(undeclared.isEmpty, "undeclared: \(undeclared.joined(separator: ", "))")
    }

    /// Every shape the sweep can create must be reachable from real receipts.
    /// A shape only the engine tests can produce is a shape that does not exist.
    func testEveryShapeIsReachableThroughTheProjectors() {
        // Named rather than derived, so adding a shape forces a decision about
        // whether anything real can produce it.
        let reachable: Set<GrimoireShape> = [
            .conditional, .sequential, .seasonal, .sibling, .returnInterval
        ]
        XCTAssertEqual(
            Set(GrimoireShape.allCases), reachable,
            "a shape exists that no end-to-end test covers — add one, or remove the shape"
        )
    }

    /// Nothing the Book generated may describe the reader. This is the standing
    /// law, checked against everything the projectors actually emit rather than
    /// against the one projector that remembered it.
    func testNothingTheBookWroteCanBecomeAnOutcomeAboutTheReader() {
        for feature in everyFeature() where feature.provenance == .generatedFiction {
            XCTAssertEqual(
                feature.role, .conditionOnly,
                "\(feature.id) is generated and could still stand as an outcome"
            )
        }
        // And the pairing rule agrees, whatever a projector declares.
        let fiction = LoomFeatureRef(
            id: "story:x", domain: "story", label: "x",
            conditionClause: "c", outcomeClause: "o",
            role: .either, provenance: .generatedFiction
        )
        let real = LoomFeatureRef(
            id: "weather:rain", domain: "weather", label: "rain",
            conditionClause: "c", outcomeClause: "o", role: .conditionOnly
        )
        XCTAssertFalse(GrimoireLedger.canPair(real, fiction))
    }

    /// Anything about the reader's body or inner state has to be marked, or the
    /// ordinary speaking path will not know to hold it back.
    func testInnerStateAndPeopleAreMarkedSensitiveWhereverTheyComeFrom() {
        for feature in everyFeature() {
            if feature.domain == "body" || feature.domain == "sleep" {
                XCTAssertEqual(feature.sensitivity, .innerState, "\(feature.id) is unmarked")
            }
            if feature.domain == "person" {
                XCTAssertEqual(feature.sensitivity, .person, "\(feature.id) is unmarked")
            }
        }
    }
}
