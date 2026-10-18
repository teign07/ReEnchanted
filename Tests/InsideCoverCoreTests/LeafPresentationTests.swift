import XCTest
@testable import InsideCoverCore

final class LeafPresentationTests: XCTestCase {
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
