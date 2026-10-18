import XCTest
@testable import InsideCoverCore

final class ExplorationBreadthTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func page(
        _ type: BookPageType,
        _ entry: String,
        metadata: [String: String] = [:],
        framing: String = "original"
    ) -> SurfacePage {
        SurfacePage(
            id: "\(type.rawValue)-\(entry)-\(framing)", type: type,
            sourceID: "fixture-\(type.rawValue)", score: 70,
            prompt: "\(entry) \(framing)", detail: "\(entry) detail \(framing)",
            payload: BookPagePayload(
                headline: entry, body: "\(entry) body \(framing)", metadata: metadata
            )
        )
    }

    func testUsingAPageLeavesItsUnusedSiblingAvailableForEveryType() {
        for type in BookPageType.allCases {
            let used = page(type, "used")
            let sibling = page(type, "unused")
            let history = CuratorVarietyGovernor.recordingServed(
                keys: used.curatorServedHistoryKeys, into: [:], now: now
            )
            let fresh = BookCurator.freshDeeperPages(
                from: [used, sibling], alreadyShown: [used], history: history,
                now: now.addingTimeInterval(60), limit: 9
            )
            XCTAssertEqual(fresh.map(\.id), [sibling.id], type.rawValue)
        }
    }

    func testServedTypeCooldownDoesNotVetoAnEligibleSiblingDuringExploration() {
        var eligibleTypesChecked = 0
        for type in BookPageType.allCases {
            let used = page(type, "used")
            let sibling = page(type, "unused")
            var mood = CuratorMood.neutral
            mood.keptPageCount = 200
            mood.isFirstHours = false
            mood.deckRound = 1
            let baseline = BookCurator.rankedPages(from: [sibling], limit: 1, mood: mood, now: now)
            // Availability, maturity, and capability gates still apply. Check
            // every family which could actually surface in this fixture.
            guard !baseline.isEmpty else { continue }
            eligibleTypesChecked += 1
            mood.surfaceHistory = CuratorVarietyGovernor.recordingServed(
                keys: used.curatorServedHistoryKeys, into: [:], now: now
            )
            mood.excludedContentKeys = [used.curatorContentNoveltyKey]
            let next = BookCurator.rankedPages(
                from: [used, sibling], limit: 1, mood: mood, now: now.addingTimeInterval(60)
            )
            XCTAssertEqual(next.map(\.page.id), [sibling.id], type.rawValue)
        }
        XCTAssertGreaterThan(eligibleTypesChecked, 10)
    }

    func testLaterTierStillAdmitsSiblingsAfterEmptyDiversityPasses() {
        let earlierTier = [page(.quotes, "earlier-1"), page(.quotes, "earlier-2")]
        let siblings = (0..<4).map { page(.quotes, "sibling-\($0)") }
        let next = BookCurator.freshDeeperPages(
            from: siblings, alreadyShown: [], history: [:], now: now,
            maxPerType: 4, alsoExcluding: earlierTier, limit: 2
        )
        // Passes one and two are empty because the earlier tier has already
        // taken two Quotes. Empty alone must never end the diversity walk.
        XCTAssertEqual(next.map(\.id), Array(siblings.prefix(2)).map(\.id))
    }

    func testExhaustedContentDoesNotHideFreshSiblingsInLaterPasses() {
        let shown = page(.quotes, "known", metadata: ["quoteID": "known"])
        let reframed = (0..<12).map {
            page(.quotes, "known", metadata: ["quoteID": "known"], framing: "seat-\($0)")
        }
        let first = page(.lore, "first")
        let second = page(.lore, "second")
        let next = BookCurator.freshDeeperPages(
            from: reframed + [first, second], alreadyShown: [shown],
            history: [:], now: now, maxPerType: 2, limit: 9
        )
        XCTAssertEqual(next.map(\.id), [first.id, second.id])
    }

    func testPuttingDownOnePageNeverRestsItsSharedFamilyNotation() {
        for type in BookPageType.allCases {
            let metadata = ["compassFamily": "shared-family-\(type.rawValue)"]
            let used = page(type, "used", metadata: metadata)
            let sibling = page(type, "unused", metadata: metadata)
            XCTAssertEqual(used.varietyKey, sibling.varietyKey)
            let preferences = CuratorSurfacePreferences(dismissedSurfaceIDs: used.curatorDismissalRestKeys)
            XCTAssertFalse(preferences.allows(used), type.rawValue)
            XCTAssertTrue(preferences.allows(sibling), type.rawValue)
        }
    }

    func testExplorationBenchRetainsEveryIndividuallyEligibleTypeTogether() {
        var mood = CuratorMood.neutral
        mood.keptPageCount = 200
        mood.isFirstHours = false
        mood.deckRound = 1
        let shelf = BookPageType.allCases.flatMap { type in
            (0..<3).map { page(type, "entry-\($0)") }
        }
        let eligibleTypes = Set(BookPageType.allCases.filter { type in
            !BookCurator.rankedPages(
                from: [page(type, "entry-0")], limit: 1, mood: mood, now: now
            ).isEmpty
        })
        let bench = BookCurator.rankedPages(
            from: shelf, limit: BookDeskRound.explorationBenchCapacity,
            mood: mood, now: now, selectionSeed: "whole-exploration-bench"
        )
        XCTAssertEqual(Set(bench.map(\.page.type)), eligibleTypes)
    }

    func testCataloguePageIdentitySurvivesDifferentFramingButSiblingsStayDistinct() {
        let catalogues: [(BookPageType, String)] = [
            (.wonderCompass, "playfulMissionID"), (.wickerDare, "wickerDareID"),
            (.diary, "journalPromptID"), (.affirmations, "affirmationID"),
            (.quotes, "quoteID"), (.quip, "quipID"), (.lore, "snippetID"),
            (.enchantment, "enchantmentID"), (.spell, "spellID"),
            (.helpTips, "tipID"), (.illustration, "plateID"),
            (.bookRemembered, "rememberedPageID")
        ]
        for (type, key) in catalogues {
            let used = page(type, "one", metadata: [key: "one"])
            let reframed = page(type, "one", metadata: [key: "one"], framing: "new host and wording")
            let sibling = page(type, "two", metadata: [key: "two"])
            XCTAssertEqual(used.curatorContentNoveltyKey, reframed.curatorContentNoveltyKey, key)
            XCTAssertNotEqual(used.curatorContentNoveltyKey, sibling.curatorContentNoveltyKey, key)
            let history = CuratorVarietyGovernor.recordingServed(
                keys: used.curatorServedHistoryKeys, into: [:], now: now
            )
            XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
                reframed, history: history, preferences: .none, now: now.addingTimeInterval(60)
            ), key)
            XCTAssertTrue(CuratorNoveltyPolicy.allowsAutomaticSurface(
                sibling, history: history, preferences: .none, now: now.addingTimeInterval(60)
            ), key)
        }
    }

    func testExistingFingerprintHistoryStillRestsTheExactPage() {
        let quote = page(.quotes, "one", metadata: ["quoteID": "one"])
        let history = [quote.curatorLegacyContentNoveltyKey:
            SurfaceHistoryRecord(lastShownAt: now, recentShowCount: 1)]
        XCTAssertFalse(CuratorNoveltyPolicy.allowsAutomaticSurface(
            quote, history: history, preferences: .none, now: now.addingTimeInterval(60)
        ))
    }

    func testExistingExactPageBeliefSurvivesCatalogueIdentityAdoption() {
        let quote = page(.quotes, "one", metadata: ["quoteID": "one"])
        let profile = PageBeliefProfile(
            sourceID: quote.sourceID, type: quote.type, title: quote.prompt,
            belief: 91, narrativeWeight: 20, cadence: "test", note: "test"
        )
        let preferences = CuratorSurfacePreferences(pageBeliefProfiles: [quote.curatorLegacyContentNoveltyKey: profile])
        XCTAssertEqual(preferences.beliefProfile(for: quote).belief, 91)
    }

    func testEverySampledShelfOffersMoreSiblingsAtTheRealCurrentTime() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let opening = BookSourceInputs.empty
        var exploring = opening
        exploring.deckRound = 1
        let adapters: [BookPageSourceAdapter] = [
            DiaryPageSourceAdapter(), WonderCompassPageSourceAdapter(),
            WickerDarePageSourceAdapter(), QuipPageSourceAdapter(),
            QuotesPageSourceAdapter(), AffirmationsPageSourceAdapter(),
            EnchantifyLorePageSourceAdapter(), HelpTipsPageSourceAdapter(),
            LabyrinthIllustrationPageSourceAdapter(), CastIllustrationPageSourceAdapter(),
            EnchantmentPageSourceAdapter(), SpellPageSourceAdapter()
        ]
        for adapter in adapters {
            let sample = adapter.candidates(for: day, context: context, inputs: opening, now: now)
            let shelf = adapter.candidates(for: day, context: context, inputs: exploring, now: now)
            XCTAssertGreaterThan(shelf.count, sample.count, adapter.source.id)
            let fresh = BookCurator.freshDeeperPages(
                from: shelf, alreadyShown: sample, history: [:], now: now, limit: 9
            )
            XCTAssertFalse(fresh.isEmpty, "\(adapter.source.id) exhausted its entire family with its opening sample")
            // Going past the old eight-draw ceiling must not shrink the shelf.
            exploring.deckRound = 99
            let lateShelf = adapter.candidates(for: day, context: context, inputs: exploring, now: now)
            XCTAssertEqual(Set(shelf.map(\.curatorContentNoveltyKey)), Set(lateShelf.map(\.curatorContentNoveltyKey)), adapter.source.id)
            exploring.deckRound = 1
        }
    }

    func testExplorationStillIncludesEveryCurrentSourceFromTheOpeningPool() {
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let opening = BookCurator.candidatePool(for: day, context: .make(for: day), now: now)
        var inputs = BookSourceInputs.empty
        inputs.deckRound = 20
        let deeper = BookCurator.candidatePool(for: day, context: .make(for: day), inputs: inputs, now: now)
        XCTAssertTrue(Set(opening.map(\.sourceID)).isSubset(of: Set(deeper.map(\.sourceID))))
    }

    func testLongExplorationKeepsFreshPagesFromEverySuppliedTypeWithoutTheCupboard() {
        // Enough siblings in every family to make scarcity impossible. This
        // catches whole-type retirement across pulls, independently of which
        // families a particular reader has unlocked.
        let families = BookPageType.allCases
        let shelf = families.flatMap { type in (0..<40).map { page(type, "entry-\($0)") } }
        var shown: [SurfacePage] = []
        var history: [String: SurfaceHistoryRecord] = [:]
        var encounteredTypes = Set<BookPageType>()
        var cupboardCalls = 0
        for pull in 0..<100 {
            let offset = (pull % families.count) * 40
            let rotated = Array(shelf.dropFirst(offset) + shelf.prefix(offset))
            let next = BookCurator.deeperPull(
                bench: rotated, alreadyShown: shown, history: history,
                now: now.addingTimeInterval(Double(pull) * 60), limit: 9
            ) { _, _, _ in cupboardCalls += 1; return [] }
            XCTAssertEqual(next.count, 9, "pull \(pull)")
            XCTAssertEqual(Set(next.map(\.type)).count, 9, "pull \(pull)")
            encounteredTypes.formUnion(next.map(\.type))
            shown += next
            history = CuratorVarietyGovernor.recordingServed(
                keys: next.flatMap(\.curatorServedHistoryKeys), into: history,
                now: now.addingTimeInterval(Double(pull) * 60)
            )
        }
        XCTAssertEqual(cupboardCalls, 0)
        XCTAssertEqual(encounteredTypes, Set(families))
        XCTAssertEqual(Set(shown.map(\.curatorContentNoveltyKey)).count, shown.count)
    }

    func testRestedPagesReturnFromTheWholeBenchBeforeTheCupboard() {
        let families: [BookPageType] = [.weather, .fuel, .rest, .lore, .illustration, .gamePage, .body, .location, .helpTips]
        let old = families.map { page($0, "rested") }
        // Put the old leaves outside the two-pull repeat window.
        let recent = (0..<18).map { page(.quotes, "recent-\($0)") }
        let history = CuratorVarietyGovernor.recordingServed(
            keys: old.flatMap(\.curatorServedHistoryKeys), into: [:], now: now.addingTimeInterval(-60 * 86_400)
        )
        var cupboardCalls = 0
        let next = BookCurator.deeperPull(
            bench: old, alreadyShown: old + recent, history: history, now: now, limit: 9
        ) { _, _, _ in cupboardCalls += 1; return [] }
        XCTAssertEqual(Set(next.map(\.type)), Set(families))
        XCTAssertEqual(cupboardCalls, 0)
        XCTAssertEqual(Set(next.map(\.curatorContentNoveltyKey)), Set(old.map(\.curatorContentNoveltyKey)))
        XCTAssertTrue(next.allSatisfy { $0.payload.metadata["pagesRisingFolioDocumentID"] != nil })
    }

    func testAnOldSeatingCannotReturnBeforeItsIndividualRestExpires() {
        let old = page(.lore, "one", metadata: ["snippetID": "one"])
        let recent = (0..<18).map { page(.quotes, "recent-\($0)") }
        let history = CuratorVarietyGovernor.recordingServed(keys: old.curatorServedHistoryKeys, into: [:], now: now)
        let next = BookCurator.deeperPull(
            bench: [old], alreadyShown: [old] + recent, history: history,
            now: now.addingTimeInterval(60), limit: 9
        ) { _, _, _ in [] }
        XCTAssertTrue(next.isEmpty)
    }
}
