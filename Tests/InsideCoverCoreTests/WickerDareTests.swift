import XCTest
@testable import InsideCoverCore

final class WickerDareTests: XCTestCase {
    func testImmediateCatalogHasAtLeastFortyDistinctDares() {
        XCTAssertGreaterThanOrEqual(WickerDareRegistry.immediate.count, 40)
        XCTAssertEqual(
            Set(WickerDareRegistry.immediate.map(\.id)).count,
            WickerDareRegistry.immediate.count
        )
        for dare in WickerDareRegistry.immediate {
            XCTAssertFalse(dare.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(dare.challenge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(dare.proofPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(dare.tags.contains("wicker-dare"))
            XCTAssertTrue(dare.tags.contains("comfort-edge"))
            XCTAssertFalse(dare.challenge.contains("Wicker"))
            XCTAssertNil(dare.place)
        }
    }

    func testExpandedCatalogContainsDifferentKindsOfMischief() {
        let ids = Set(WickerDareRegistry.immediate.map(\.id))

        XCTAssertTrue(ids.isSuperset(of: [
            "pocket-museum",
            "municipal-drama",
            "friend-dares-back",
            "chapter-the-commute",
            "tiny-boundary",
            "local-honor",
            "ceremonial-snack"
        ]))
    }

    func testWickerDaresHaveVariedRealWorldPressure() throws {
        let tiny = try XCTUnwrap(WickerDareRegistry.immediate.first { $0.id == "tongue-out" })
        let route = try XCTUnwrap(WickerDareRegistry.immediate.first { $0.id == "route-mutiny" })

        XCTAssertFalse(tiny.goesOutward)
        XCTAssertTrue(route.goesOutward)
        XCTAssertLessThan(tiny.pressureCost, route.pressureCost)
        XCTAssertLessThan(tiny.estimatedMinutes, route.estimatedMinutes)
    }

    func testEstablishedRivalryUnlocksDaresBeyondTheOnboardingHandful() {
        let start = Date(timeIntervalSince1970: 1_783_000_000)
        let openingHand: Set<String> = [
            "object-compliment", "formal-portrait", "honest-opinion", "first-sentence-sky"
        ]
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [onboardingFact("onboarding-wicker-mode", answer: "slice-of-life", now: start)]
        inputs.days = [BookDay(
            id: "wicker-history",
            date: start.addingTimeInterval(-86_400),
            pages: (0..<3).map { index in
                wickerReceiptPage(index: index, completedAt: start.addingTimeInterval(Double(index - 3) * 3_600))
            }
        )]

        let selected = Set((0..<24).map { offset -> String in
            let now = start.addingTimeInterval(Double(offset) * 43_200)
            let day = BookDay(id: "wicker-wide-\(offset)", date: now, pages: [])
            return WickerDareRegistry.dare(for: day, inputs: inputs, now: now).id
        })

        XCTAssertTrue(selected.contains { !openingHand.contains($0) })
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
        XCTAssertEqual(surface.payload.metadata["primaryLivedInvitation"], "true")
        XCTAssertTrue(surface.isReaderActionCommission)
        XCTAssertTrue(surface.payload.body.contains("Skip it."))
        XCTAssertTrue(surface.payload.body.contains("Wicker"))
        XCTAssertTrue(surface.prompt.hasPrefix("I Dare You:"))
        XCTAssertFalse(surface.payload.body.contains("Wicker would"))
    }

    func testWickerKeepsOneRotatingCandidateOnTheBench() {
        let start = Date(timeIntervalSince1970: 1_783_000_000)
        let adapter = WickerDarePageSourceAdapter()

        for offset in 0..<8 {
            let now = start.addingTimeInterval(Double(offset) * 12 * 60 * 60)
            let day = BookDay(id: "wicker-bench-\(offset)", date: now, pages: [])
            let candidates = adapter.candidates(
                for: day,
                context: CuratorContext.make(for: day),
                inputs: .empty,
                now: now
            )

            XCTAssertEqual(candidates.count, 1, "Wicker vanished in twelve-hour slot \(offset)")
        }
    }

    func testWickerBeginsWithMainLoopBeliefRatherThanRareNoveltyBelief() {
        let source = BookPageSourceRegistry.source(for: .wickerDare)

        XCTAssertEqual(BookPageSourceRegistry.defaultBelief(for: source), 40)
        XCTAssertEqual(BookPageSourceRegistry.narrativeWeight(for: source), 28)
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
                name: "Left Bank Library",
                category: "Library",
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
        XCTAssertTrue(dare.challenge.contains("Left Bank Library"))
        XCTAssertTrue(dare.challenge.contains("short poem"))
        XCTAssertTrue(dare.challenge.contains("Ask before leaving it"))
    }

    func testLocalDarePrefersARealNearbyBookstoreForTheStrangerQuestion() throws {
        var inputs = BookSourceInputs.empty
        inputs.nearbyPlaces = [
            LocalPlaceSignal(
                id: "town-library",
                name: "Town Library",
                category: "Library",
                distanceLabel: "0.2 mi",
                locality: "Belfast"
            ),
            LocalPlaceSignal(
                id: "left-bank-books",
                name: "Left Bank Books",
                category: "Book Store",
                distanceLabel: "0.4 mi",
                locality: "Belfast"
            )
        ]
        let start = Date(timeIntervalSince1970: 1_783_000_000)
        var selected: WickerDare?
        for offset in 0..<12 {
            let now = start.addingTimeInterval(Double(offset) * 43_200)
            let day = BookDay(id: "wicker-bookstore-\(offset)", date: now, pages: [])
            let dare = WickerDareRegistry.dare(for: day, inputs: inputs, now: now)
            if dare.place != nil {
                selected = dare
                break
            }
        }

        let dare = try XCTUnwrap(selected)
        XCTAssertEqual(dare.place?.id, "left-bank-books")
        XCTAssertTrue(dare.challenge.contains("Left Bank Books"))
        XCTAssertTrue(dare.challenge.lowercased().contains("ask another browser"))
        XCTAssertTrue(dare.proofPrompt.contains("book they named"))
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

    func testOnlyTheFirstDareRemembersTheOnboardingSceneAndItRemindsTheReader() throws {
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [
            onboardingFact("onboarding-wicker-mode", answer: "slice-of-life", now: now),
            onboardingFact("onboarding-wicker-tier", answer: "hold", now: now),
            onboardingFact(
                "onboarding-wicker-thread",
                answer: "I mark the Rut as the place your next undeniable detail can prove him wrong again.",
                now: now
            )
        ]
        let day = BookDay(id: "wicker-first", date: now, pages: [])
        let first = WickerDarePageSourceAdapter().manualSurface(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
        // Wicker says who he is and what happened, so nobody has to remember it.
        XCTAssertTrue(first.payload.body.contains("Wicker here."))
        XCTAssertTrue(first.payload.body.contains("picked up your first page and sneered at it"))
        XCTAssertTrue(first.payload.body.contains("one small true thing from your real life"))
        XCTAssertTrue(first.payload.body.contains("Your first dare."))
        XCTAssertEqual(first.payload.metadata["wickerFirstDare"], "true")
        // The stored thread is the Book's bookkeeping, never Wicker's words.
        XCTAssertFalse(first.payload.body.contains("undeniable detail"))

        // Same slot, already on the desk: the page keeps its opener.
        inputs.surfaceHistory["source:wickers-dares"] = SurfaceHistoryRecord(
            lastShownAt: now, recentShowCount: 1
        )
        let again = WickerDarePageSourceAdapter().manualSurface(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        )
        XCTAssertEqual(again.payload.metadata["wickerFirstDare"], "true")

        // A later slot: no reference to the scene, ever.
        for offset in 1..<40 {
            let at = now.addingTimeInterval(Double(offset) * 43_200 + 86_400)
            let laterDay = BookDay(id: "wicker-later-\(offset)", date: at, pages: [])
            let later = WickerDarePageSourceAdapter().manualSurface(
                for: laterDay, context: CuratorContext.make(for: laterDay), inputs: inputs, now: at
            )
            XCTAssertNil(later.payload.metadata["wickerFirstDare"])
            let text = [later.payload.body, later.detail, later.prompt, later.reason].joined(separator: "\n")
            for banned in ["Inkbones", "Inscription", "onboarding", "sneered at it", "first page", "Your first dare"] {
                XCTAssertFalse(text.contains(banned), "\(banned) in \(later.payload.headline)")
            }
            XCTAssertNil(later.payload.metadata["onboardingWickerThread"])
        }
    }

    func testFirstDareOpenerCoversEveryAnswerAndStaysPlainWithoutOne() {
        for mode in ["slice-of-life", "arc", "surprise"] {
            for tier in ["triumph", "hold", "glance", "cost"] {
                let line = WickerDarePageSourceAdapter.firstDareOpener(mode: mode, tier: tier)
                XCTAssertTrue(line.hasPrefix("Wicker here."), line)
                XCTAssertTrue(line.hasSuffix("Your first dare."), line)
                XCTAssertFalse(line.contains("Inkbones"), line)
            }
        }
        let skipped = WickerDarePageSourceAdapter.firstDareOpener(mode: nil, tier: nil)
        XCTAssertFalse(skipped.contains("We met"), "No scene happened, so none is remembered.")
    }

    func testAReaderWhoReturnedADareNeverGetsTheFirstOpener() {
        let start = Date(timeIntervalSince1970: 1_783_000_000)
        var inputs = BookSourceInputs.empty
        inputs.selfFacts = [onboardingFact("onboarding-wicker-mode", answer: "arc", now: start)]
        inputs.days = [BookDay(
            id: "wicker-done", date: start.addingTimeInterval(-86_400),
            pages: [wickerReceiptPage(index: 0, completedAt: start.addingTimeInterval(-3_600))]
        )]
        let day = BookDay(id: "wicker-after", date: start, pages: [])
        let page = WickerDarePageSourceAdapter().manualSurface(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: start
        )
        XCTAssertNil(page.payload.metadata["wickerFirstDare"])
        XCTAssertTrue(page.payload.body.contains("You brought back"))
    }

    func testEveryDareIsPlainSpeechWithNoLegalHedging() {
        for dare in WickerDareRegistry.immediate {
            let text = "\(dare.title) \(dare.challenge) \(dare.proofPrompt)".lowercased()
            for banned in ["your veto", "trapped yes", "let no be easy", "comfort edge", "inscription", "onboarding"] {
                XCTAssertFalse(text.contains(banned), "\(banned) in \(dare.id)")
            }
            XCTAssertTrue(dare.proofPrompt.hasPrefix("Bring me") || dare.proofPrompt.hasPrefix("Tell me"), dare.id)
        }
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

    private func wickerReceiptPage(index: Int, completedAt: Date) -> BookPage {
        let receipt = LivedQuestReceipt(
            kind: .wickerDare,
            questID: "finished-wicker-\(index)",
            title: "Finished Wicker Dare \(index)",
            invitation: "Do one harmless disobedient thing.",
            proofPrompt: "Bring back one exact sentence.",
            facets: [.scriptFreedom],
            sourceTags: ["wicker-dare", "entity:wicker-eddies"],
            hasWrittenProof: true,
            hasVisualProof: false,
            completedAt: completedAt,
            wasPromptedByBook: true
        )
        return BookPage(
            id: "wicker-receipt-\(index)",
            type: .wickerDare,
            createdAt: completedAt,
            promptText: receipt.title,
            userInput: "The ordinary rule objected and I objected back.",
            tags: ["wicker-dare"],
            livedQuestReceipt: receipt
        )
    }
}
