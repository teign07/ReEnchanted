import XCTest
@testable import InsideCoverCore

/// Phase 1 of `docs/correspondences-plan.md`: the inherited half of the
/// Correspondences shelf, so it is full on a reader's first night instead of
/// empty for the month the Book needs to work anything out for itself.
final class InheritedCorrespondenceTests: XCTestCase {

    private var all: [InheritedCorrespondence] { CorrespondenceLibraryRegistry.all }

    func testTheShelfIsNotEmptyOnANewReadersFirstNight() {
        XCTAssertGreaterThanOrEqual(all.count, 10)
    }

    func testEveryRowIsAttributed() {
        for row in all {
            XCTAssertFalse(
                row.tradition.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(row.id) claims a correspondence with nobody's name on it"
            )
            XCTAssertFalse(row.subject.isEmpty, "\(row.id) has no subject")
            XCTAssertFalse(row.sense.isEmpty, "\(row.id) has no sense")
            XCTAssertFalse(row.lore.isEmpty, "\(row.id) has no lore")
        }
    }

    func testIdentifiersAreUnique() {
        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate correspondence id")
    }

    /// The Academy may invent. It may not invent *and* sound like a source.
    func testAcademyInventionsSaySoInTheirAttribution() {
        let academy = all.filter { $0.source == .academy }
        XCTAssertFalse(academy.isEmpty, "the Academy should have opinions of its own")
        for row in academy {
            XCTAssertTrue(
                row.attributionLine.contains("Academy"),
                "\(row.id) is invented and does not admit it"
            )
        }
    }

    func testEveryRowKnowsItIsInherited() {
        XCTAssertTrue(all.allSatisfy { $0.origin == .inherited })
    }

    // MARK: Lore-only rows are furniture, permanently

    func testLoreOnlyRowsAreNeverTestable() {
        for row in CorrespondenceLibraryRegistry.loreOnly {
            XCTAssertNil(row.observable)
            XCTAssertFalse(
                row.isTestable,
                "\(row.id) has no observable and must never be treated as a claim"
            )
        }
    }

    func testTheShelfIsMostlyFurniture() {
        XCTAssertGreaterThan(
            CorrespondenceLibraryRegistry.loreOnly.count,
            CorrespondenceLibraryRegistry.testable.count,
            "most correspondence lore maps onto nothing measurable, and that is the point"
        )
    }

    func testTestableAndLoreOnlyPartitionTheShelf() {
        let testable = Set(CorrespondenceLibraryRegistry.testable.map(\.id))
        let lore = Set(CorrespondenceLibraryRegistry.loreOnly.map(\.id))
        XCTAssertTrue(testable.isDisjoint(with: lore))
        XCTAssertEqual(testable.union(lore), Set(all.map(\.id)))
    }

    // MARK: The wiring lint

    /// Every feature id the world projector can actually produce, gathered by
    /// running it rather than by copying its source.
    private func producibleFeatureIDs() -> Set<String> {
        var ids: Set<String> = []
        let calendar = Calendar.current
        let dayParts = [9, 14, 19, 2].map { hour -> Date in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        }
        let weatherTags = ["rain", "snow", "fog", "clear", "wind", "cloud", "storm", "heat", "cold"]
        let placeKinds: [String?] = [nil, "beach", "marina", "cafe", "park"]

        for date in dayParts {
            for tag in weatherTags {
                for kind in placeKinds {
                    let context = BookPageContextSnapshot(
                        at: date,
                        weatherTags: [tag],
                        locationLabel: "Somewhere",
                        placeKind: kind
                    )
                    ids.formUnion(WorldConditionsProjector.features(for: context).map(\.id))
                }
            }
        }
        return ids
    }

    /// A row keyed to a feature nothing emits is a correspondence the Book can
    /// never have an opinion about — it would sit in "inherited, untested"
    /// forever while looking like it was waiting for evidence.
    func testEveryTestableRowIsKeyedToAFeatureSomethingActuallyProduces() {
        let producible = producibleFeatureIDs()
        XCTAssertFalse(producible.isEmpty, "the probe produced no features at all")
        // Proof the lint has teeth: if the probe accepted anything, the check
        // below would pass no matter how wrong a key was.
        XCTAssertFalse(
            producible.contains("weather:brimstone"),
            "the probe accepts ids nothing emits, so it cannot catch a bad key"
        )
        for row in CorrespondenceLibraryRegistry.testable {
            let observable = try? XCTUnwrap(row.observable)
            XCTAssertTrue(
                producible.contains(observable ?? ""),
                "\(row.id) is keyed to \(row.observable ?? "nil"), which no projector emits"
            )
        }
    }

    func testMatchingFindsRowsByObservable() {
        let water = CorrespondenceLibraryRegistry.matching(observable: "place-kind:water")
        XCTAssertFalse(water.isEmpty)
        XCTAssertTrue(water.allSatisfy { $0.observable == "place-kind:water" })
        XCTAssertTrue(CorrespondenceLibraryRegistry.matching(observable: "weather:brimstone").isEmpty)
    }

    func testRowsSurviveARoundTrip() throws {
        let pack = try XCTUnwrap(CorrespondenceLibraryRegistry.bundledPacks.first)
        let decoded = try JSONDecoder().decode(
            CorrespondencePack.self,
            from: JSONEncoder().encode(pack)
        )
        XCTAssertEqual(decoded, pack)
    }
}
