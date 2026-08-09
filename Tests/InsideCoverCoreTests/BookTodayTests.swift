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

        XCTAssertTrue(closing.contains("What in the wild margins—where have you been?"))
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
