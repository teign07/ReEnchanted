import XCTest
@testable import InsideCoverCore

final class BookTodayTests: XCTestCase {
    func testWeatherBecomesAtmosphereRatherThanDashboardData() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T14:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.weather = WeatherSourceSignal(
            phrase: "Fog along the harbor. 61°F.",
            source: "test"
        )

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(edition.form, .weatherMap)
        XCTAssertTrue(edition.headline.contains("Fog along the harbor"))
        XCTAssertEqual(edition.beats.first?.kind, .atTheWindows)
        XCTAssertEqual(edition.beats.first?.symbolName, "cloud.fog")
        XCTAssertFalse(edition.reading.localizedCaseInsensitiveContains("score"))
        XCTAssertFalse(edition.reading.localizedCaseInsensitiveContains("page ready"))
    }

    func testActiveSessionIntentionIsTranslatedIntoBookLanguage() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T09:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.activeBookSessionIntention = BookSessionIntention(
            id: "session",
            dayID: day.id,
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: [],
            evidenceReason: "private test evidence",
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            seed: "stable"
        )

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(edition.form, .observatoryWindow)
        XCTAssertTrue(edition.reading.contains("familiar thing visible again"))
        XCTAssertTrue(edition.reading.contains("I'll take one glint"))
        XCTAssertTrue(edition.reading.contains("I'm trying"))
        XCTAssertFalse(edition.reading.contains("private test evidence"))
        XCTAssertEqual(edition.beats.last?.kind, .byNightfall)
    }

    func testQuietEditionRefusesToManufactureSignificance() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T15:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: .empty,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertEqual(edition.form, .almanacLeaf)
        XCTAssertTrue(edition.reading.contains("I'm watching"))
        XCTAssertTrue(edition.beats.isEmpty)
    }

    func testRunningBusinessEntersTodayAsTheSameUnfinishedJoke() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-27T15:00:00Z"))
        let day = BookDay(id: "2026-07-27", date: now, pages: [])
        let business = BookRunningBusiness(
            id: "ribbon-business",
            kind: .ribbonDispute,
            title: "The Ribbon Dispute",
            latestLine: "The ribbon moved. It says my eyes did it.",
            callbackCount: 0,
            bornAt: now,
            lastAdvancedAt: now,
            evidencePageIDs: []
        )
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: now, runningBusiness: business)

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar
        )

        XCTAssertTrue(edition.beats.contains { $0.line == business.latestLine })
        XCTAssertTrue(edition.marginalMark?.contains("ribbon") == true)
        XCTAssertFalse(edition.reading.contains("the Book is"))
    }

    func testContestedMarginChangesVoiceAcrossOpeningsWithoutChangingTheEvidence() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T14:00:00Z"))
        let day = BookDay(id: "2026-08-08", date: now, pages: [])
        let positions = [
            ContestedPosition(
                id: "ambrose",
                holderID: "ambrose-trencher",
                holderName: "Ambrose",
                claim: "The recipe card was left there on purpose.",
                groundedInIDs: ["unsigned-recipe"],
                confidence: 62,
                silence: .none,
                formedAt: now
            ),
            ContestedPosition(
                id: "penny",
                holderID: "penny-blackletter",
                holderName: "Penny",
                claim: "The Index moved it after supper.",
                groundedInIDs: ["unsigned-recipe"],
                confidence: 48,
                silence: .none,
                formedAt: now
            ),
            ContestedPosition(
                id: "mook",
                holderID: "professor-thaddeus-mook",
                holderName: "Professor Mook",
                claim: "Professor Mook has declined to comment.",
                groundedInIDs: ["unsigned-recipe"],
                confidence: 40,
                silence: .wouldHaveToAdmitSomething,
                formedAt: now
            )
        ]
        var inputs = BookSourceInputs.empty
        inputs.contestedQuestions = [ContestedQuestion(
            id: "unsigned-recipe",
            question: "What is actually going on with the unsigned recipe?",
            aboutMovementIDs: ["unsigned-recipe"],
            placeID: nil,
            positions: positions,
            bookPosition: "The Book suspects Ambrose knows more than he says.",
            bookBackedHolderID: "ambrose-trencher",
            status: .open,
            openedAt: now,
            lastMovedAt: now,
            embarrassedHolderID: nil,
            contradictingEvidence: nil
        )]

        func marginLine(seed: Int) throws -> String {
            let edition = BookTodayProjector.edition(
                for: day,
                inputs: inputs,
                relationship: .firstOpening,
                experienceProgram: nil,
                now: now,
                calendar: utcCalendar,
                selectionSeed: seed
            )
            return try XCTUnwrap(edition.beats.first(where: { $0.kind == .inTheMargins })?.line)
        }

        let lines = try (0..<64).map { try marginLine(seed: $0) }
        XCTAssertGreaterThan(Set(lines).count, 1)
        XCTAssertEqual(try marginLine(seed: 17), try marginLine(seed: 17))
        XCTAssertFalse(lines.contains {
            $0 == "I can hear the margins arguing over “What is actually going on with the unsigned recipe?” They haven't asked permission."
        })
        XCTAssertTrue(lines.allSatisfy { line in
            ["unsigned recipe", "Ambrose", "Penny", "Professor Mook"].contains {
                line.localizedCaseInsensitiveContains($0)
            }
        })

        let businessLine = "The ribbon moved itself and has retained counsel."
        inputs.bookInterior = BookInteriorState(
            awakenedAt: now,
            runningBusiness: BookRunningBusiness(
                id: "ribbon-business",
                kind: .ribbonDispute,
                title: "The Ribbon Dispute",
                latestLine: businessLine,
                callbackCount: 1,
                bornAt: now,
                lastAdvancedAt: now,
                evidencePageIDs: []
            )
        )
        let mixedLines = try (0..<64).map { try marginLine(seed: $0) }
        XCTAssertTrue(mixedLines.contains(businessLine))
        XCTAssertTrue(mixedLines.contains { $0.localizedCaseInsensitiveContains("unsigned recipe") })
    }

    func testMarginBenchReadsAcrossTheAcademyLedgers() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T14:00:00Z"))
        let day = BookDay(id: "2026-08-08", date: now, pages: [])
        var inputs = BookSourceInputs.empty

        var agency = CastAgencyState()
        agency.remember(
            CastAgencyMovement(
                slotID: "academy-turn",
                kind: .relationship,
                actorID: "penny-blackletter",
                actorName: "Penny",
                targetID: "wicker-eddies",
                targetName: "Wicker",
                amount: -1,
                line: "Penny moved Wicker's chair six inches away from the committee table.",
                createdAt: now
            ),
            keepingRecentSlots: ["academy-turn"]
        )
        inputs.castAgency = agency

        var acts = CastActLedger.empty
        acts.record(CastActRecord(
            id: "academy-act",
            actorID: "wicker-eddies",
            actorName: "Wicker",
            targetID: "penny-blackletter",
            targetName: "Penny",
            act: .coverFor,
            line: "Wicker took the blame for Penny's missing catalog card and looked delighted by the accusation.",
            occurredAt: now,
            tags: ["relationship"]
        ))
        inputs.castActs = acts
        inputs.relationshipField = [
            "penny-blackletter|wicker-eddies": RelationshipTie(warmth: 2, tension: 11, familiarity: 7)
        ]

        var belief = BeliefEconomyState()
        belief.remember([BeliefEconomyMovement(
            targetKind: .entity,
            targetID: "penny-blackletter",
            targetName: "Penny",
            delta: 2,
            reason: .castSpent,
            note: "Penny invested two Belief in the Index's right to sulk.",
            createdAt: now
        )])
        inputs.beliefEconomy = belief

        let undertakingLine = "Wicker counted the east-corridor doors twice and erased only the seventh tally."
        inputs.castUndertakings = [CastUndertaking(
            id: "door-count",
            actorID: "wicker-eddies",
            title: "The Door Count",
            pursuit: "counting doors",
            why: "he will not say",
            stages: [CastUndertakingStage(
                id: "seventh-door",
                line: undertakingLine,
                trace: "A chalk nub under door seven.",
                tags: ["doors"]
            )],
            stageIndex: 0,
            status: .active,
            startedAt: now,
            lastAdvancedAt: now,
            nextEligibleAt: now.addingTimeInterval(3_600)
        )]

        inputs.worldPressures = [WorldPressure(
            id: "pressure-rivalry",
            origin: .rivalry,
            subjectIDs: ["penny-blackletter", "wicker-eddies"],
            summary: "Penny and Wicker have stopped pretending to agree about the west staircase.",
            fingerprints: [],
            beganAt: now,
            expiresAt: now.addingTimeInterval(86_400)
        )]
        inputs.placeStates = [
            "east-corridor": PlaceState(
                id: "east-corridor",
                incidents: [PlaceIncident(
                    id: "corridor-incident",
                    line: "A door appeared between six and eight, then denied being seven.",
                    participantIDs: ["wicker-eddies"],
                    tags: ["doors"],
                    occurredAt: now
                )]
            )
        ]

        let lines = (0..<512).compactMap { seed -> String? in
            BookTodayProjector.edition(
                for: day,
                inputs: inputs,
                relationship: .firstOpening,
                experienceProgram: nil,
                now: now,
                calendar: utcCalendar,
                selectionSeed: seed
            ).beats.first(where: { $0.kind == .inTheMargins })?.line
        }
        let joined = lines.joined(separator: "\n")
        for receipt in [
            "moved Wicker's chair",
            "missing catalog card",
            "thread between Penny Blackletter and Wicker Eddies",
            "invested two Belief",
            undertakingLine,
            "west staircase",
            "denied being seven"
        ] {
            XCTAssertTrue(joined.localizedCaseInsensitiveContains(receipt), receipt)
        }
    }

    func testCensusCountsTheCurrentDayOnceAndUsesPermittedReaderName() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T14:00:00Z"))
        let page = BookPage(
            id: "one-true-page",
            type: .souvenir,
            createdAt: now,
            promptText: "The jar on the windowsill caught a square of blue light."
        )
        let day = BookDay(id: "2026-08-08", date: now, pages: [page])
        var inputs = BookSourceInputs.empty
        // The live day may also be present in the archive snapshot. The census
        // deduplicates by Page id rather than inflating the accomplishment.
        inputs.days = [day]
        inputs.rememberedPlaceCount = 3
        inputs.selfFacts = [SelfFact(
            id: "name",
            questionID: "onboarding-name",
            question: "What shall I call you?",
            answer: "Mira",
            bookTranslation: "Mira",
            sensitivity: .identity,
            usePermission: .privateContext,
            tags: ["name"],
            createdAt: now,
            updatedAt: now
        )]

        let edition = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar,
            selectionSeed: 41
        )

        XCTAssertEqual(edition.census.title, "THE BOOK OF MIRA")
        XCTAssertEqual(edition.census.pageCount, 1)
        XCTAssertEqual(edition.census.begunAt, now)
        XCTAssertTrue(edition.census.facts.contains { $0.id == "remembered-places" && $0.value == 3 })
        XCTAssertTrue(edition.census.facts.allSatisfy { $0.value > 0 })
    }

    func testCensusSelectionIsStableForOneOpeningAndLimitedToFourDrawers() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T03:00:00Z"))
        let pageTypes: [BookPageType] = [
            .plainPage, .diary, .souvenir, .bookRemembered, .bookOfYou, .letter
        ]
        let pages = pageTypes.enumerated().map { index, type in
            BookPage(
                id: "page-\(index)",
                type: type,
                createdAt: now.addingTimeInterval(TimeInterval(index * 60)),
                promptText: "Page \(index)",
                userInput: "This is a sufficiently long true line with several ordinary words and one peculiar blue window waiting at the end."
            )
        }
        let day = BookDay(id: "2026-08-08", date: now, pages: pages)
        var inputs = BookSourceInputs.empty
        inputs.rememberedPlaceCount = 4
        inputs.relationshipField = [
            "penny|wicker": RelationshipTie(warmth: 2, tension: 1, familiarity: 3)
        ]
        var pocket = PocketLedger()
        pocket.press(PocketKeepsake(
            id: "keepsake",
            dayID: day.id,
            pageType: .souvenir,
            object: "a blue thread",
            glyph: "scribble",
            foundAt: now
        ))
        inputs.pocket = pocket

        let first = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar,
            selectionSeed: 902
        ).census
        let rebuilt = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar,
            selectionSeed: 902
        ).census
        let nextOpening = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar,
            selectionSeed: 903
        ).census

        XCTAssertEqual(first, rebuilt)
        XCTAssertNotEqual(first.facts, nextOpening.facts)
        XCTAssertEqual(first.facts.count, 4)
        XCTAssertEqual(Set(first.facts.map(\.id)).count, first.facts.count)
        XCTAssertTrue(first.facts.allSatisfy { $0.value > 0 })
        for drainedPhrase in ["not a score", "no pressure", "you don't have to", "when you're ready"] {
            XCTAssertFalse(first.closingLine.localizedCaseInsensitiveContains(drainedPhrase))
        }
    }

    func testQuietReturnSoundsAttachedAndCarriesActualCastNews() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T14:00:00Z"))
        let page = BookPage(type: .souvenir, createdAt: now, promptText: "A blue thread")
        let day = BookDay(id: "2026-08-08", date: now, pages: [page])
        var inputs = BookSourceInputs.empty
        inputs.quietDays = 4
        inputs.castAgency.recentMovements = [CastAgencyMovement(
            slotID: "wicker-news",
            kind: .relationship,
            actorID: "wicker",
            actorName: "Wicker",
            targetID: "penny-blackletter",
            targetName: "Penny Blackletter",
            amount: 1,
            line: "Wicker hid Penny's catalog cards in the rafters.",
            createdAt: now,
            witnessed: false
        )]
        var relationship = BookRelationshipSnapshot.firstOpening
        relationship.depth = .companion

        let closing = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: relationship,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar,
            selectionSeed: 19
        ).census.closingLine

        XCTAssertTrue(closing.contains("What in the wild margins, where have you been?"))
        XCTAssertTrue(closing.contains("Wicker hid Penny's catalog cards in the rafters."))
        XCTAssertTrue(closing.localizedCaseInsensitiveContains("kept your place"))
        XCTAssertFalse(closing.localizedCaseInsensitiveContains("fuck"))
        XCTAssertFalse(closing.contains("not an accusation"))
    }

    func testCensusDoesNotUseAForbiddenName() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T14:00:00Z"))
        let page = BookPage(type: .souvenir, createdAt: now, promptText: "A true thing")
        let day = BookDay(id: "2026-08-08", date: now, pages: [page])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [SelfFact(
            id: "forbidden-name",
            questionID: "onboarding-name",
            question: "What shall I call you?",
            answer: "Secret Name",
            bookTranslation: "Secret Name",
            sensitivity: .identity,
            usePermission: .doNotUse,
            tags: ["name"],
            createdAt: now,
            updatedAt: now
        )]

        let census = BookTodayProjector.edition(
            for: day,
            inputs: inputs,
            relationship: .firstOpening,
            experienceProgram: nil,
            now: now,
            calendar: utcCalendar,
            selectionSeed: 7
        ).census

        XCTAssertEqual(census.title, "THE BOOK SO FAR")
        XCTAssertFalse(census.title.contains("SECRET NAME"))
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
