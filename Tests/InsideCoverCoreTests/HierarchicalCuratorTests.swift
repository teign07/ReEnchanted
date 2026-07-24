import XCTest
@testable import InsideCoverCore

final class HierarchicalCuratorTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(
        year: 2026,
        month: 7,
        day: 22,
        hour: 14
    ))!

    func testMoreVariantsDoNotBuyATypeMoreLotteryTickets() {
        let weather = page(id: "weather-one", type: .weather, sourceID: "weather-family")
        let lore = page(id: "lore-one", type: .lore, sourceID: "lore-family")
        let manyWeatherPages = (0..<24).map { offset in
            page(id: "weather-\(offset)", type: .weather, sourceID: "weather-family")
        }

        for offset in 0..<120 {
            let seed = "type-fairness-\(offset)"
            let baseline = selectedPage(
                from: [weather, lore],
                seed: seed
            )
            let expanded = selectedPage(
                from: manyWeatherPages + [lore],
                seed: seed
            )

            XCTAssertEqual(
                baseline?.type,
                expanded?.type,
                "Adding individual Pages inside a family must not alter the Page Type draw."
            )
        }
    }

    func testCuratorChoosesDifferentIndividualPagesWithinOneType() {
        let pages = (0..<6).map { offset in
            page(id: "weather-detail-\(offset)", type: .weather, sourceID: "weather-family")
        }
        var selectedContentKeys = Set<String>()

        for offset in 0..<180 {
            let seed = "within-type-variety-\(offset)"
            if let selected = selectedPage(from: pages, seed: seed) {
                selectedContentKeys.insert(selected.curatorContentNoveltyKey)
            }
        }

        XCTAssertGreaterThan(selectedContentKeys.count, 1)
    }

    func testExactPageBeliefSteersWithinTypeWithoutGuaranteeOrVeto() {
        let high = page(id: "believed-weather", type: .weather, sourceID: "weather-family")
        let low = page(id: "unlikely-weather", type: .weather, sourceID: "weather-family")
        let profiles = [
            high.curatorContentNoveltyKey: belief(for: high, amount: 100),
            low.curatorContentNoveltyKey: belief(for: low, amount: 0)
        ]
        let preferences = CuratorSurfacePreferences(pageBeliefProfiles: profiles)
        var highCount = 0
        var lowCount = 0

        for offset in 0..<600 {
            let seed = "exact-belief-\(offset)"
            let selected = selectedPage(from: [high, low], seed: seed, preferences: preferences)
            if selected?.id == high.id { highCount += 1 }
            if selected?.id == low.id { lowCount += 1 }
        }

        XCTAssertGreaterThan(highCount, lowCount)
        XCTAssertGreaterThan(lowCount, 0, "Even the lowest-Belief individual Page remains discoverable.")
        XCTAssertLessThan(highCount, 600, "Even the highest-Belief individual Page is not guaranteed.")
    }

    func testExactPageLearningDistinguishesPagesInsideOneFamily() {
        let known = page(id: "known-weather", type: .weather, sourceID: "weather-family")
        let sibling = page(id: "sibling-weather", type: .weather, sourceID: "weather-family")
        var learning = ReaderLearningModel()

        for offset in 0..<4 {
            learning.record(ReaderLearningEvent(
                dayID: "2026-07-\(10 + offset)",
                occurredAt: now.addingTimeInterval(Double(offset) * 60),
                action: .loved,
                surfaceID: known.id,
                sourceID: known.sourceID,
                type: known.type,
                varietyKey: known.varietyKey,
                contentKey: known.curatorContentNoveltyKey,
                hour: 14
            ))
        }

        XCTAssertGreaterThan(
            learning.scoreAdjustment(for: known),
            learning.scoreAdjustment(for: sibling)
        )
    }

    func testCausalReceiptSeparatesTypeAndIndividualPagePropensities() throws {
        let pages = [
            page(id: "weather-a", type: .weather, sourceID: "weather-family"),
            page(id: "weather-b", type: .weather, sourceID: "weather-family"),
            page(id: "lore-a", type: .lore, sourceID: "lore-family"),
            page(id: "lore-b", type: .lore, sourceID: "lore-family")
        ]
        let selected = try XCTUnwrap(selectedPage(from: pages, seed: "receipt-stages"))
        let receipt = try XCTUnwrap(CausalCurationReceipt.read(from: selected))
        let typePropensity = try XCTUnwrap(receipt.typePropensity)
        let pagePropensity = try XCTUnwrap(receipt.pagePropensityWithinType)

        XCTAssertEqual(receipt.chosenType, selected.type)
        XCTAssertEqual(receipt.pageCandidateCountWithinType, 2)
        XCTAssertEqual(receipt.propensity, typePropensity * pagePropensity, accuracy: 0.000_000_1)
        XCTAssertEqual(Set(receipt.candidates.map(\.armID)).count, 4)
    }

    func testOlderLearningAndCausalReceiptsDecodeWithoutNewExactPageFields() throws {
        let eventJSON = """
        {
          "id":"old-event","dayID":"2026-01-01","occurredAt":0,
          "action":"kept","surfaceID":"old-surface","sourceID":"old-source",
          "type":"lore","varietyKey":"old-variety","hour":12,"tags":[]
        }
        """
        let event = try JSONDecoder().decode(ReaderLearningEvent.self, from: Data(eventJSON.utf8))
        XCTAssertNil(event.contentKey)

        let original = CausalCurationReceipt(
            id: "old-receipt",
            policyVersion: 1,
            sessionID: "old-session",
            movement: .freshSight,
            role: .door,
            chosenSourceID: "old-source",
            chosenArmID: "old-arm",
            contextKey: "old-context",
            propensity: 0.5,
            candidates: [
                CausalCurationCandidate(sourceID: "old-source", armID: "old-arm", weight: 1),
                CausalCurationCandidate(sourceID: "other-source", armID: "other-arm", weight: 1)
            ],
            pressureCost: 0.08,
            selectedAt: now
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
        )
        object.removeValue(forKey: "chosenType")
        object.removeValue(forKey: "typePropensity")
        object.removeValue(forKey: "pagePropensityWithinType")
        object.removeValue(forKey: "pageCandidateCountWithinType")
        let decoded = try JSONDecoder().decode(
            CausalCurationReceipt.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.chosenType)
        XCTAssertNil(decoded.typePropensity)
        XCTAssertNil(decoded.pagePropensityWithinType)
        XCTAssertNil(decoded.pageCandidateCountWithinType)
    }

    func testMajorAuthoredFamiliesOfferConcreteShortlistsToSecondStage() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let inputs = BookSourceInputs.empty
        let diary = DiaryPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
        let stories = NarrativeOSPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
        let quips = QuipPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
        let quotes = QuotesPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
        let believings = AffirmationsPageSourceAdapter().candidates(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )

        XCTAssertEqual(Set(diary.compactMap { $0.payload.metadata["journalPromptID"] }).count, 4)
        XCTAssertGreaterThan(Set(stories.compactMap { $0.payload.metadata["storyRecipeID"] }).count, 1)
        XCTAssertEqual(Set(quips.compactMap { $0.payload.metadata["quipID"] }).count, 4)
        XCTAssertEqual(Set(quotes.compactMap { $0.payload.metadata["quoteID"] }).count, 4)
        XCTAssertEqual(Set(believings.compactMap { $0.payload.metadata["affirmationID"] }).count, 4)
    }

    private func selectedPage(
        from pages: [SurfacePage],
        seed: String,
        preferences: CuratorSurfacePreferences = .none
    ) -> SurfacePage? {
        BookCurator.rankedPages(
            from: pages,
            limit: 1,
            preferences: preferences,
            mood: .neutral,
            now: now,
            intention: intention(seed: seed),
            selectionSeed: seed
        ).first?.page
    }

    private func intention(seed: String) -> BookSessionIntention {
        BookSessionIntention(
            id: "hierarchical-\(seed)",
            dayID: BookDay.id(for: now),
            movement: .freshSight,
            ambition: .glint,
            evidencePageIDs: [],
            evidenceReason: "A deterministic test supplies the opening.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(6 * 3600),
            seed: seed
        )
    }

    private func page(id: String, type: BookPageType, sourceID: String) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: type == .lore ? .importReference : .capture,
            renderStyle: type == .lore ? .loreLetter : .promptCard,
            score: 60,
            prompt: "Prompt for \(id)",
            detail: "Detail for \(id)",
            payload: BookPagePayload(
                headline: "Page \(id)",
                body: "The exact readable body of \(id).",
                metadata: ["noveltyKey": id]
            )
        )
    }

    private func belief(for page: SurfacePage, amount: Int) -> PageBeliefProfile {
        PageBeliefProfile(
            sourceID: page.sourceID,
            type: page.type,
            title: page.payload.headline,
            belief: amount,
            narrativeWeight: 20,
            cadence: "test",
            note: "test"
        )
    }
}
