import XCTest
@testable import InsideCoverCore

final class LeafPresentationTests: XCTestCase {
    func testInterleafCanReturnSeveralExactSentencesFromOneKeep() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let page = BookPage(id: "many", type: .souvenir, createdAt: now, promptText: "",
            userInput: "I found the little stone. The gull followed me home! We left the window open.", origin: .userAuthored)
        let lines = InterleafCuration.texts(days: [.init(id: "day", date: now, pages: [page])], noticings: [])
        XCTAssertEqual(lines.map(\.text), ["I found the little stone.", "The gull followed me home!", "We left the window open."])
        XCTAssertEqual(Set(lines.map(\.id)).count, 3)
        XCTAssertEqual(lines.first?.id, "reader:many")
        XCTAssertTrue(lines.allSatisfy { $0.sources.map(\.pageID) == [page.id] })
        XCTAssertTrue(InterleafCuration.texts(days: [], noticings: []).isEmpty)
    }

    func testInterleafBreathesAfterCrowdedNeighborsWithoutOverridingAuthoredDensity() {
        let metadata: [String: String] = [:]
        let baseline = LeafDecorationLibrary.recipe(pageType: .souvenir, metadata: metadata,
            semanticText: "A frog by the pond.", documentID: "boundary", leafIndex: 0,
            decorationPlate: true, densityOverride: .rich)
        let quieted = InterleafCuration.curatedDecoration(baseline: baseline, pageType: .souvenir,
            metadata: metadata, semanticText: "A frog by the pond.", documentID: "boundary",
            previous: nil, recentAssets: [], recentNotes: [], neighborIsCrowded: true)
        XCTAssertEqual(quieted.density, .ordinary)
        let authored = InterleafCuration.curatedDecoration(baseline: baseline, pageType: .souvenir,
            metadata: ["leafMarginaliaDensity": "rich"], semanticText: "A frog by the pond.", documentID: "boundary",
            previous: nil, recentAssets: [], recentNotes: [], neighborIsCrowded: true)
        XCTAssertEqual(authored.density, .rich)
    }

    func testInterleafDiscoveriesAreRareStableAndAuthored() {
        let discoveries = (0..<1000).compactMap { InterleafCuration.discovery(seed: $0) }
        XCTAssertGreaterThan(discoveries.count, 30)
        XCTAssertLessThan(discoveries.count, 100)
        XCTAssertGreaterThan(Set(discoveries).count, 3)
        XCTAssertEqual(InterleafCuration.discovery(seed: 91), InterleafCuration.discovery(seed: 91))
    }

    func testInterleafMixStaysBalancedAcrossAppendsAndEveryStartingPosition() {
        for seed in -40...40 {
            for start in 0..<30 {
                let window = (start..<(start + 10)).map { InterleafCuration.slot(at: $0, seed: seed) }
                XCTAssertEqual(window.filter { $0 == .photo }.count, 2)
                XCTAssertEqual(window.filter { $0 == .illustration }.count, 3)
                XCTAssertEqual(window.filter { $0 == .other }.count, 5)
                XCTAssertTrue((start..<(start + 5)).contains { InterleafCuration.slot(at: $0, seed: seed) == .photo })
            }
            let others = (0..<30).filter { InterleafCuration.slot(at: $0, seed: seed) == .other }
                .map { InterleafCuration.otherIndex(at: $0, seed: seed) }
            XCTAssertEqual(others, Array(0..<15))
            // Appending Pages does not reroll earlier boundaries.
            XCTAssertEqual((0..<8).map { InterleafCuration.slot(at: $0, seed: seed) },
                Array((0..<30).map { InterleafCuration.slot(at: $0, seed: seed) }.prefix(8)))
        }
    }

    func testInterleafTextUsesOlderKeepsAndKeepsAuthorshipSeparate() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let keeps = (0..<48).map { index in
            BookPage(id: "reader-\(index)", type: .souvenir,
                createdAt: now.addingTimeInterval(Double(-index) * 86_400), promptText: "",
                userInput: "I found a different stone number \(index).", origin: .userAuthored)
        }
        let generated = BookPage(id: "story", type: .narrativeOS, promptText: "",
            userInput: "The Book made this whole sentence up.", origin: .generated)
        let sensitive = BookPage(id: "sensitive", type: .souvenir, promptText: "",
            userInput: "This sentence belongs in its shut room.", origin: .userAuthored, privacy: .localSensitive)
        let simulated = BookPage(id: "simulated", type: .souvenir, promptText: "",
            userInput: "This sentence belongs to a test fixture.", origin: .simulated)
        let day = BookDay(id: "archive", date: now, pages: keeps + [generated, sensitive, simulated])
        let texts = InterleafCuration.texts(days: [day], noticings: [])
        XCTAssertEqual(texts.count, 48, "The archive must not shrink to the newest 32 sentences.")
        XCTAssertTrue(texts.contains { $0.id == "reader:reader-47" })
        XCTAssertTrue(texts.allSatisfy { $0.kind == .reader && $0.attribution == "YOU WROTE THIS" })
        XCTAssertFalse(texts.contains { $0.text.contains("Book made") || $0.text.contains("shut room") })
    }

    func testSavedMeasurementsCanSupplyNoticingsWithoutBecomingReaderQuotes() throws {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let page = BookPage(id: "keep", type: .souvenir, promptText: "",
            userInput: "The gull stole my lunch.", origin: .userAuthored)
        let finding = Noticing(id: "clock-writing", kind: .crossing, headline: "Night words",
            line: "You write longer after dark.", counted: "Six nights, three mornings.",
            receipts: [.init(pageID: page.id, date: now, text: "the kept page")],
            sources: [.clock, .writing], rank: 80)
        let day = BookDay(id: "today", date: now, pages: [page])
        let texts = InterleafCuration.texts(days: [day], noticings: [finding])
        let found = try XCTUnwrap(texts.first { $0.kind == .noticing })
        XCTAssertEqual(found.text, "You write longer after dark. Six nights, three mornings.")
        XCTAssertEqual(found.attribution, "I NOTICED THIS")
        XCTAssertEqual(texts.filter { $0.kind == .reader }.map(\.text), ["The gull stole my lunch."])

        XCTAssertFalse(InterleafCuration.texts(days: [day], noticings: [finding],
            excluding: ["crossing:clock-writing"]).contains { $0.kind == .noticing })
        var body = finding
        body.sources.append(.body)
        XCTAssertFalse(InterleafCuration.texts(days: [day], noticings: [body]).contains { $0.kind == .noticing })
        var missing = finding
        missing.receipts[0].pageID = "deleted-page"
        XCTAssertFalse(InterleafCuration.texts(days: [day], noticings: [missing]).contains { $0.kind == .noticing })
    }

    func testSearsportReceiptCannotRepeatOnANewTendOrBoundary() throws {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let line = "Searsport kept turning up, so the pencil started a tally while you were out."
        let receipt = InterleafCuration.Text.receipt(line)
        let fresh = InterleafCuration.Text(id: "new", text: "The gull stole my lunch.", kind: .reader)
        // Round-trip the durable history just as reopening the app does.
        let history = Dictionary(uniqueKeysWithValues: receipt.historyKeys.map { ($0, now) })
        let saved = try JSONEncoder().encode(history)
        let restored = try JSONDecoder().decode([String: Date].self, from: saved)
        for seed in -30...30 {
            XCTAssertEqual(InterleafCuration.text(from: [.receipt(line), fresh], recentlySeen: restored,
                excluding: [], now: now.addingTimeInterval(86_400), seed: seed), fresh)
        }
        XCTAssertNil(InterleafCuration.text(from: [.receipt(line)], recentlySeen: restored,
            excluding: [], now: now, seed: 17), "A quiet leaf is better than repeating the same receipt.")
    }

    func testSameInkOnDifferentPagesAndUpdatedFindingCountsStillRest() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let first = InterleafCuration.Text(id: "reader:a", text: "I kept the small stone.", kind: .reader)
        let duplicate = InterleafCuration.Text(id: "reader:b", text: " I kept  the small STONE. ", kind: .reader)
        let history = Dictionary(uniqueKeysWithValues: first.historyKeys.map { ($0, now) })
        XCTAssertNil(InterleafCuration.text(from: [duplicate], recentlySeen: history,
            excluding: [], now: now, seed: 9))
        let changedCounts = InterleafCuration.Text(id: "noticing:night", text: "Eight nights now.", kind: .noticing)
        XCTAssertNil(InterleafCuration.text(from: [changedCounts], recentlySeen: ["noticing:night": now],
            excluding: [], now: now, seed: 9))
    }

    func testBindingNeverUsesTheSameTextTwiceAndSelectionIgnoresInputOrder() throws {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let texts = (0..<12).map {
            InterleafCuration.Text(id: "reader:\($0)", text: "A different saved sentence \($0).", kind: .reader)
        }
        var used = Set<String>()
        var ids = Set<String>()
        for seed in 0..<texts.count {
            let chosen = try XCTUnwrap(InterleafCuration.text(from: texts, recentlySeen: [:],
                excluding: used, now: now, seed: seed))
            XCTAssertEqual(chosen, InterleafCuration.text(from: Array(texts.reversed()), recentlySeen: [:],
                excluding: used, now: now, seed: seed))
            XCTAssertTrue(ids.insert(chosen.id).inserted)
            used.formUnion(chosen.historyKeys)
        }
        XCTAssertNil(InterleafCuration.text(from: texts, recentlySeen: [:], excluding: used, now: now, seed: 0))
    }

    func testUnseenInkWinsAndOldestRestedInkReturnsAfterTheCooldown() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let old = InterleafCuration.Text(id: "old", text: "An older saved sentence.", kind: .reader)
        let newer = InterleafCuration.Text(id: "newer", text: "A more recent saved sentence.", kind: .reader)
        let unseen = InterleafCuration.Text(id: "unseen", text: "A finding never shown.", kind: .noticing)
        let history = [old.id: now.addingTimeInterval(-60 * 86_400), newer.id: now.addingTimeInterval(-31 * 86_400)]
        XCTAssertEqual(InterleafCuration.text(from: [old, newer, unseen], recentlySeen: history,
            excluding: [], now: now, seed: 4), unseen)
        XCTAssertEqual(InterleafCuration.text(from: [old, newer], recentlySeen: history,
            excluding: [], now: now, seed: 4), old)
    }

    func testIllustrationExposureSurvivesReopeningAndMakesRoomForUnseenArt() throws {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let door = InterleafIllustration(id: "door", assetName: "Door", title: "Door", tags: ["door"])
        let river = InterleafIllustration(id: "river", assetName: "River", title: "River", tags: ["water"])
        var context = IlluminationPlacementContext.empty
        context.semanticTags = ["door"]
        let encoded = try JSONEncoder().encode(["Door": now])
        let history = try JSONDecoder().decode([String: Date].self, from: encoded)
        XCTAssertEqual(InterleafIllustrationLibrary.select(from: [door, river], context: context,
            seed: 1, recentlySeen: history, now: now), river,
            "The same strong subject match must not win every opening.")
        XCTAssertEqual(InterleafIllustrationLibrary.select(from: [door], context: context,
            seed: 1, recentlySeen: history, now: now), door,
            "A small catalogue may still offer familiar art.")
    }

    func testVisualRotationReservesWithinABindingAndLetsMapsRest() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let history = ["a": now, "b": now.addingTimeInterval(-2 * 86_400)]
        XCTAssertEqual(InterleafCuration.visualPool(["a", "b", "c"], recentlySeen: history,
            now: now, allowsRecentFallback: false), ["c"])
        XCTAssertTrue(InterleafCuration.visualPool(["a", "b", "c"], recentlySeen: history,
            excluding: ["c"], now: now, allowsRecentFallback: false).isEmpty)
        XCTAssertEqual(InterleafCuration.visualPool(["a", "b"], recentlySeen: history,
            now: now, allowsRecentFallback: true), ["b"])
        XCTAssertTrue(InterleafCuration.visualPool(["a"], recentlySeen: [:], excluding: ["a"],
            now: now, allowsRecentFallback: true).isEmpty)
        XCTAssertEqual(InterleafCuration.visualPool(["a", "b"], recentlySeen: history,
            now: now.addingTimeInterval(8 * 86_400), allowsRecentFallback: false), ["b"])
    }

    func testQuotationArtUsesItsOwnSubjectsButKeepsOccasionalChanceEncounters() {
        let text = InterleafCuration.Text(id: "reader:sea", text: "I watched a frog in the moonlight.", kind: .reader)
        let metadata = ["tags": "fire,letter", "senderName": "Ambrose",
                        "leafMarginaliaDensity": "rich", "issueYear": "2026", "worldEventPhase": "BUILDUP"]
        var personal = 0
        var chance = 0
        for seed in 0..<200 {
            let context = InterleafCuration.decorationContext(quotation: text, neighboringText: "A letter by the fire.",
                pageType: .letter, metadata: metadata, seed: seed)
            if context.text == text.text {
                personal += 1
                XCTAssertEqual(context.pageType, .souvenir)
                XCTAssertNil(context.metadata["tags"])
                XCTAssertNil(context.metadata["senderName"])
                XCTAssertEqual(context.metadata["leafMarginaliaDensity"], "rich")
                XCTAssertEqual(context.metadata["issueYear"], "2026")
                XCTAssertEqual(context.metadata["worldEventPhase"], "BUILDUP")
                let motifs = LeafDecorationLibrary.resolvedMotifs(pageType: context.pageType,
                    metadata: context.metadata, semanticText: context.text)
                XCTAssertTrue(motifs.contains("frog") && motifs.contains("moon"), "\(motifs)")
                XCTAssertFalse(motifs.contains("ambrose"))
            } else {
                chance += 1
                XCTAssertEqual(context.text, "A letter by the fire.")
                XCTAssertEqual(context.metadata, metadata)
            }
        }
        XCTAssertGreaterThan(personal, chance)
        XCTAssertGreaterThan(chance, 0)
    }

    func testQuotedSubjectsPreservePhaseGatesStoredInTags() throws {
        let quote = InterleafCuration.Text(id: "reader", text: "A frog crossed the path.", kind: .reader)
        let metadata = ["tags": "letter,event-phase:CLIMAX", "decorationMonth": "11", "decorationYear": "2026",
                        "decorationWorldEventIDs": "the-guest"]
        let own = try XCTUnwrap((0..<30).map { seed in
            InterleafCuration.decorationContext(quotation: quote, neighboringText: "An unrelated letter.",
                pageType: .letter, metadata: metadata, seed: seed)
        }.first { $0.text == quote.text })
        XCTAssertEqual(own.metadata["tags"], "event-phase:CLIMAX")
        let context = LeafDecorationLibrary.resolvedPlacementContext(motifs: [], metadata: own.metadata)
        XCTAssertEqual(context.month, 11)
        XCTAssertEqual(context.year, 2026)
        XCTAssertTrue(context.worldEventPhases.contains("CLIMAX"))
        XCTAssertTrue(context.activeWorldEventIDs.contains("the-guest"))
    }

    func testReturnedInkCarriesExactArchiveSourceAndFindingSourcesAreUnique() throws {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let first = BookPage(id: "first", type: .souvenir, createdAt: now, promptText: "Book prompt",
            userInput: "I found the blue stone.", origin: .userAuthored)
        let second = BookPage(id: "second", type: .souvenir, createdAt: now.addingTimeInterval(-86_400),
            promptText: "Another prompt", userInput: "I walked beside the river.", origin: .userAuthored)
        let finding = Noticing(id: "river", kind: .crossing, headline: "River words", line: "You wrote beside the river.",
            receipts: [.init(pageID: first.id, date: now, text: "first"),
                       .init(pageID: second.id, date: second.createdAt, text: "second"),
                       .init(pageID: first.id, date: now, text: "duplicate")], sources: [.writing, .place], rank: 80)
        let texts = InterleafCuration.texts(days: [.init(id: "day", date: now, pages: [first, second])], noticings: [finding])
        let quote = try XCTUnwrap(texts.first { $0.id == "reader:first" })
        XCTAssertEqual(quote.sources.map(\.pageID), [first.id])
        XCTAssertEqual(quote.sources.first?.date, first.createdAt)
        XCTAssertEqual(quote.sources.first?.title, "I found the blue stone.")
        let noticing = try XCTUnwrap(texts.first { $0.kind == .noticing })
        XCTAssertEqual(noticing.sources.map(\.pageID), [first.id, second.id])
        XCTAssertEqual(noticing.sources.last?.date, second.createdAt)
    }

    func testContainerTagsDoNotMakeTheSameHandwrittenCaptionWinEveryLeaf() {
        let selections = (0..<200).compactMap { seed in
            IlluminationMarginaliaLibrary.select(motifs: ["book", "margin", "margins", "illustration"],
                seed: seed, count: 1).first?.id
        }
        XCTAssertGreaterThan(Set(selections).count, 20)
        let mostFrequent = Dictionary(grouping: selections, by: { $0 }).values.map(\.count).max() ?? 0
        XCTAssertLessThan(mostFrequent, 25)
        for seed in 0..<20 {
            let letter = IlluminationMarginaliaLibrary.select(motifs: ["book", "margin", "letter"], seed: seed, count: 1)
            XCTAssertTrue(letter.first?.tags.contains("letter") == true)
        }
    }

    func testPhotoLoadingPrefersLocalThenOneCloudAttemptThenReturnsToLocal() {
        let ids = (0..<20).map { "photo-\($0)" }
        let attempts = InterleafPhotoCuration.loadingAttempts(identifiers: ids, allowsCloud: true)
        XCTAssertEqual(attempts.count, 11)
        XCTAssertEqual(attempts.prefix(4).map(\.identifier), Array(ids.prefix(4)))
        XCTAssertTrue(attempts.prefix(4).allSatisfy { !$0.allowsNetwork })
        XCTAssertEqual(attempts[4], .init(identifier: "photo-0", allowsNetwork: true))
        XCTAssertEqual(attempts.suffix(6).map(\.identifier), Array(ids[4..<10]))
        XCTAssertTrue(attempts.suffix(6).allSatisfy { !$0.allowsNetwork })
        XCTAssertEqual(InterleafPhotoCuration.loadingAttempts(identifiers: ["one", "one"], allowsCloud: false),
            [.init(identifier: "one", allowsNetwork: false)])
        XCTAssertTrue(InterleafPhotoCuration.loadingAttempts(identifiers: [], allowsCloud: true).isEmpty)
    }

    func testPhotoRelevanceUsesAlbumSubjectsAndExplicitNeighbourAttachments() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let candidates = [photo("plain"), photo("album"), photo("attached")]
        let ranked = InterleafPhotoCuration.ranked(candidates,
            subjectTags: ["album": ["library", "books"]], wantedTags: ["library", "books"],
            relatedIdentifiers: ["attached"], recentlySeen: [:], excluding: [],
            captureDatesToAvoid: [], now: now, seed: 7)
        XCTAssertEqual(Set(ranked.prefix(2).map(\.assetLocalIdentifier)), ["album", "attached"])
        XCTAssertEqual(ranked.last?.assetLocalIdentifier, "plain")
        XCTAssertTrue(ranked.first { $0.assetLocalIdentifier == "album" }?.reasons.contains("related album") == true)
    }

    func testRecentAndReservedPhotosStandBackEvenWhenTheyHaveTheHighestScore() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let candidates = [photo("recent", score: 100), photo("reserved", score: 100), photo("fresh")]
        let ranked = InterleafPhotoCuration.ranked(candidates, subjectTags: [:], wantedTags: [],
            relatedIdentifiers: [], recentlySeen: ["recent": now.addingTimeInterval(-86_400)],
            excluding: ["reserved"], captureDatesToAvoid: [], now: now, seed: 7)
        XCTAssertEqual(ranked.map(\.assetLocalIdentifier), ["fresh"])
        let smallLibrary = InterleafPhotoCuration.ranked([photo("only")], subjectTags: [:], wantedTags: [],
            relatedIdentifiers: [], recentlySeen: ["only": now], excluding: ["only"],
            captureDatesToAvoid: [], now: now, seed: 7)
        XCTAssertEqual(smallLibrary.first?.assetLocalIdentifier, "only")
    }

    func testNearDuplicateCapturesStandBackAndRankingDoesNotDependOnFetchOrder() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let candidates = [photo("burst", score: 100, createdAt: now),
                          photo("different", createdAt: now.addingTimeInterval(-86_400)), photo("undated")]
        func rank(_ photos: [PhotoCandidate]) -> [PhotoCandidate] {
            InterleafPhotoCuration.ranked(photos, subjectTags: [:], wantedTags: [], relatedIdentifiers: [],
                recentlySeen: [:], excluding: [], captureDatesToAvoid: [now.addingTimeInterval(-30)], now: now, seed: 9)
        }
        XCTAssertFalse(rank(candidates).contains { $0.assetLocalIdentifier == "burst" })
        XCTAssertEqual(rank(candidates), rank(Array(candidates.reversed())))
    }

    private func photo(_ identifier: String, score: Double = 8, createdAt: Date? = nil) -> PhotoCandidate {
        PhotoCandidate(id: UUID(), assetLocalIdentifier: identifier, creationDate: createdAt,
            pixelWidth: 1_600, pixelHeight: 1_200, isFavorite: false, score: score,
            reasons: [], discoveredAt: Date(timeIntervalSinceReferenceDate: 700_000_000))
    }

    func testMonthlyPlateRequiresItsYearMonthAndStoryPhase() {
        let plate = InterleafIllustration(
            id: "october-door", assetName: "OctoberDoor", title: "The door",
            tags: ["door"], placementTrigger: .init(
                months: [10], issueYear: 2026,
                activeWorldEventIDs: ["count-unbound"], worldEventPhases: ["BUILDUP"]
            )
        )
        var context = IlluminationPlacementContext(
            semanticTags: ["door"], month: 10, year: 2026,
            activeWorldEventIDs: ["count-unbound"], worldEventPhases: ["BUILDUP"]
        )
        XCTAssertTrue(plate.isEligible(in: context))
        context.year = nil
        XCTAssertFalse(plate.isEligible(in: context))
        context.year = 2027
        XCTAssertFalse(plate.isEligible(in: context))
        context.year = 2026
        context.month = 11
        XCTAssertFalse(plate.isEligible(in: context))
        context.month = 10
        context.worldEventPhases = ["SETUP"]
        XCTAssertFalse(plate.isEligible(in: context))
    }

    func testRelatedPlateWinsAndRecentPlateMakesRoomForAnother() {
        let door = InterleafIllustration(id: "door", assetName: "Door", title: "Door", tags: ["door"])
        let river = InterleafIllustration(id: "river", assetName: "River", title: "River", tags: ["river"])
        var context = IlluminationPlacementContext.empty
        context.semanticTags = ["door"]
        XCTAssertEqual(InterleafIllustrationLibrary.select(from: [river, door], context: context, seed: 42), door)
        XCTAssertEqual(InterleafIllustrationLibrary.select(from: [river, door], context: context, seed: 42, excluding: ["Door"]), river)
        XCTAssertEqual(InterleafIllustrationLibrary.select(from: [door], context: context, seed: 42, excluding: ["Door"]), door)
    }

    func testNoEligiblePlateReturnsNoSelection() {
        let plate = InterleafIllustration(
            id: "seasonal", assetName: "Seasonal", title: "Seasonal", tags: [],
            placementTrigger: .init(months: [10])
        )
        XCTAssertNil(InterleafIllustrationLibrary.select(from: [plate], context: .empty, seed: 1))
    }

    func testSelectionIsStableWhenPackOrderChanges() {
        let plates = (0..<8).map {
            InterleafIllustration(id: "plate-\($0)", assetName: "Plate\($0)", title: "Plate", tags: [])
        }
        XCTAssertEqual(
            InterleafIllustrationLibrary.select(from: plates, context: .empty, seed: 101),
            InterleafIllustrationLibrary.select(from: Array(plates.reversed()), context: .empty, seed: 101)
        )
    }

    func testDensityVariesButRemainsStableAndHonorsAuthorship() {
        let resolved = (0..<256).map {
            LeafMarginaliaDensity.resolve(metadata: [:], documentID: "proof-\($0)", leafIndex: 0)
        }
        XCTAssertEqual(Set(resolved), Set(LeafMarginaliaDensity.allCases))
        for index in resolved.indices {
            XCTAssertEqual(resolved[index], .resolve(metadata: [:], documentID: "proof-\(index)", leafIndex: 0))
            XCTAssertEqual(
                LeafMarginaliaDensity.resolve(metadata: ["leafMarginaliaDensity": "overdone"], documentID: "proof-\(index)", leafIndex: 0),
                .overdone
            )
        }
    }

    func testOlderPacksStillDecodeWithoutPresentationFields() throws {
        let data = Data(#"{"id":"old-pack","displayName":"Old pack","version":1,"author":"The Book","availability":"bundledFree","archetypes":[]}"#.utf8)
        let pack = try JSONDecoder().decode(PageArchetypePack.self, from: data)
        XCTAssertNil(pack.interleafIllustrations)
    }
}
