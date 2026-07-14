import XCTest
@testable import InsideCoverCore

final class HiddenMagicPracticeTests: XCTestCase {
    func testOutwardPagesKeepTheirTypesWhileReceivingDifferentLenses() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let surfaces = [
            surface(.souvenir, id: "souvenir"),
            surface(.body, id: "body"),
            surface(.fuel, id: "fuel"),
            surface(.weather, id: "weather"),
            surface(.location, id: "location"),
            surface(.enchantment, id: "enchantment")
        ]

        let decorated = surfaces.map {
            HiddenMagicPractice.decorating($0, days: [day], now: now)
        }

        XCTAssertEqual(decorated.map(\.type), surfaces.map(\.type))
        XCTAssertTrue(decorated.allSatisfy { $0.hiddenMagicLens != nil })
        XCTAssertGreaterThan(Set(decorated.compactMap { $0.hiddenMagicLens?.sense }).count, 2)
        XCTAssertEqual(BookPageType.weather.deskLane, .outward)
        XCTAssertEqual(BookPageType.enchantment.deskLane, .outward)
    }

    func testCompletedLensRequiresTakenStateAndRealProof() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let decorated = HiddenMagicPractice.decorating(
            surface(.souvenir, id: "souvenir"),
            days: [],
            now: now
        )

        XCTAssertNil(HiddenMagicPractice.finding(for: decorated, input: "A blue shadow.", media: [], now: now))

        let taken = HiddenMagicPractice.markingTaken(decorated)
        XCTAssertNil(HiddenMagicPractice.finding(for: taken, input: "", media: [], now: now))

        let finding = try XCTUnwrap(HiddenMagicPractice.finding(
            for: taken,
            input: "A blue shadow crossed the kettle.",
            media: [],
            now: now
        ))
        XCTAssertEqual(finding.expressionModes, [.words])
        XCTAssertEqual(finding.foundAt, now)
    }

    func testPracticedSenseMakesFutureLensStretchElsewhere() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sightPages = (0..<4).map { index in
            findingPage(
                id: "sight-\(index)",
                sense: .sight,
                date: now.addingTimeInterval(Double(-index) * 86_400),
                text: "Light detail \(index)."
            )
        }
        let day = BookDay(id: "past", date: now.addingTimeInterval(-86_400), pages: sightPages)
        let decorated = HiddenMagicPractice.decorating(
            surface(.souvenir, id: "stretch"),
            days: [day],
            now: now
        )

        XCTAssertNotEqual(decorated.hiddenMagicLens?.sense, .sight)
    }

    func testFindingsBecomeConfirmableWayOfSeeingAndNightReaderCandidate() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let findings = (0..<4).map { index in
            findingPage(
                id: "sound-\(index)",
                sense: .sound,
                date: now.addingTimeInterval(Double(-(index + 1)) * 86_400),
                text: "The room kept a different quiet sound \(index)."
            )
        }
        var inputs = BookSourceInputs()
        inputs.days = findings.map { page in
            BookDay(id: BookDay.id(for: page.createdAt), date: page.createdAt, pages: [page])
        }
        inputs = inputs.withMatureLibrary(now: now)
        let today = BookDay(id: BookDay.id(for: now), date: now, pages: [])

        let surface = try XCTUnwrap(BookNoticesPageSourceAdapter()
            .candidates(for: today, context: .make(for: today), inputs: inputs, now: now)
            .first { $0.payload.metadata["hiddenMagicWayOfSeeing"] == "true" })

        XCTAssertEqual(surface.payload.metadata["hiddenMagicSense"], HiddenMagicSense.sound.rawValue)
        XCTAssertEqual(surface.payload.metadata["connectionNarrative"], "true")
        XCTAssertEqual(surface.payload.metadata["magicMomentEligible"], "true")
        XCTAssertEqual(BookObservationLedger.evidencePageIDs(for: surface).count, 3)

        let candidates = OvernightConnectionReview.candidates(for: today, inputs: inputs, now: now)
        XCTAssertTrue(candidates.contains { $0.observationKey == surface.payload.metadata["observationKey"] })
    }

    private func surface(_ type: BookPageType, id: String) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: type.rawValue,
            intent: .capture,
            renderStyle: .promptCard,
            score: 60,
            reason: "test",
            prompt: type.title,
            detail: "A page in its own voice.",
            payload: BookPagePayload(headline: type.title, body: "A page in its own voice.")
        )
    }

    private func findingPage(
        id: String,
        sense: HiddenMagicSense,
        date: Date,
        text: String
    ) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: date,
            promptText: "Find it.",
            userInput: text,
            tags: ["hidden-magic", "hidden-magic-finding", "hidden-magic-sense:\(sense.rawValue)"],
            hiddenMagicFinding: HiddenMagicFinding(
                lensID: "test:\(sense.rawValue)",
                sense: sense,
                action: "Notice something real.",
                proofPrompt: "Keep one detail.",
                expressionModes: [.words],
                foundAt: date
            )
        )
    }
}
