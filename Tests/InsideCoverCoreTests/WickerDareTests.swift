import XCTest
@testable import InsideCoverCore

final class WickerDareTests: XCTestCase {
    func testImmediateCatalogHasAtLeastTwentyDistinctDares() {
        XCTAssertGreaterThanOrEqual(WickerDareRegistry.immediate.count, 20)
        XCTAssertEqual(
            Set(WickerDareRegistry.immediate.map(\.id)).count,
            WickerDareRegistry.immediate.count
        )
        for dare in WickerDareRegistry.immediate {
            XCTAssertFalse(dare.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(dare.challenge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(dare.proofPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(dare.tags.contains("wicker-dare"))
            XCTAssertNil(dare.place)
        }
    }

    func testDareIsItsOwnPageTypeAndCarriesVoluntaryBoundary() {
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let day = BookDay(id: "wicker-manual", date: now, pages: [])
        let surface = WickerDarePageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )

        XCTAssertEqual(surface.type, .wickerDare)
        XCTAssertEqual(surface.sourceID, "wickers-dares")
        XCTAssertEqual(surface.payload.metadata["wickerDare"], "true")
        XCTAssertEqual(surface.payload.metadata["voluntary"], "true")
        XCTAssertTrue(surface.payload.body.contains("This is a dare, not a debt."))
        XCTAssertTrue(surface.payload.body.contains("— Wicker"))
    }

    func testDareWithoutLocalSignalsNeverInventsABusiness() {
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let day = BookDay(id: "wicker-no-place", date: now, pages: [])
        let dare = WickerDareRegistry.dare(for: day, inputs: .empty, now: now)

        XCTAssertNil(dare.place)
        XCTAssertFalse(dare.challenge.contains("Library"))
        XCTAssertFalse(dare.challenge.contains("Co-Op"))
    }

    func testLocalDareNamesOnlyAnActuallySuppliedPlaceAndRespectsPostingRules() throws {
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(
                id: "left-bank",
                name: "Left Bank Books",
                category: "Bookstore",
                distanceLabel: "0.4 mi",
                locality: "Belfast"
            )
        ]
        let start = Date(timeIntervalSince1970: 1_783_000_000)
        var selected: WickerDare?
        for offset in 0..<12 {
            let now = start.addingTimeInterval(Double(offset) * 43_200)
            let day = BookDay(id: "wicker-place-\(offset)", date: now, pages: [])
            let dare = WickerDareRegistry.dare(for: day, inputs: inputs, now: now)
            if dare.place != nil {
                selected = dare
                break
            }
        }

        let dare = try XCTUnwrap(selected)
        XCTAssertEqual(dare.place?.id, "left-bank")
        XCTAssertTrue(dare.challenge.contains("Left Bank Books"))
        XCTAssertTrue(dare.challenge.contains("Ask before leaving it"))
    }

    func testSensitiveNearbyPlacesAreNotUsedAsDareDestinations() {
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(
                id: "clinic",
                name: "Neighborhood Clinic",
                category: "Hospital",
                distanceLabel: "nearby",
                locality: "Belfast"
            )
        ]
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let day = BookDay(id: "wicker-sensitive-place", date: now, pages: [])
        let dare = WickerDareRegistry.dare(for: day, inputs: inputs, now: now)

        XCTAssertNil(dare.place)
        XCTAssertFalse(dare.challenge.contains("Neighborhood Clinic"))
    }

    func testOnboardingAnswerShapesLaterWickerDares() {
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let day = BookDay(id: "wicker-shaped", date: now, pages: [])
        let expected: [String: Set<String>] = [
            "slice-of-life": ["object-compliment", "formal-portrait", "honest-opinion", "first-sentence-sky"],
            "arc": ["unnecessary-flourish", "visible-mending", "micro-adventure-invite", "route-mutiny", "beautifully-overdressed-task"],
            "surprise": ["wrong-way-round", "tiny-manifesto", "strange-accessory", "one-minute-character", "tongue-out"]
        ]

        for (mode, ids) in expected {
            var inputs = BookSourceInputs.empty
            inputs.selfFacts = [onboardingFact("onboarding-wicker-mode", answer: mode, now: now)]
            let dare = WickerDareRegistry.dare(for: day, inputs: inputs, now: now)
            XCTAssertTrue(ids.contains(dare.id), "\(mode) produced unrelated dare \(dare.id)")
        }
    }

    func testFirstLaterWickerPageResumesTheInkbonesThreadOnce() {
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let day = BookDay(id: "wicker-rematch", date: now, pages: [])
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            onboardingFact("onboarding-wicker-mode", answer: "surprise", now: now),
            onboardingFact("onboarding-wicker-tier", answer: "cost", now: now),
            onboardingFact(
                "onboarding-wicker-thread",
                answer: "He named the misfire. Named things come back.",
                now: now
            )
        ]

        let first = WickerDarePageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now
        )
        XCTAssertTrue(first.payload.body.contains("You remember the Inkbones."))
        XCTAssertTrue(first.payload.body.contains("Named things come back."))
        XCTAssertEqual(first.payload.metadata["onboardingWickerMode"], "surprise")
        XCTAssertEqual(first.payload.metadata["onboardingWickerTier"], "cost")

        inputs.surfaceHistory["wickers-dares:seen"] = SurfaceHistoryRecord(
            lastShownAt: now,
            recentShowCount: 1
        )
        let later = WickerDarePageSourceAdapter().manualSurface(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: inputs,
            now: now.addingTimeInterval(43_200)
        )
        XCTAssertFalse(later.payload.body.contains("You remember the Inkbones."))
        XCTAssertNil(later.payload.metadata["onboardingWickerThread"])
    }

    private func onboardingFact(_ questionID: String, answer: String, now: Date) -> SelfFact {
        SelfFact(
            id: "test:\(questionID)",
            questionID: questionID,
            question: questionID,
            answer: answer,
            bookTranslation: answer,
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: ["wicker", "onboarding"],
            createdAt: now,
            updatedAt: now
        )
    }
}
