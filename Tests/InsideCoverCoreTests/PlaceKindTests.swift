import XCTest
@testable import InsideCoverCore

/// Phase 5 of `docs/correspondences-plan.md`. Before this the Book could form
/// "you write differently at anchor-7f3a" but not "you write differently near
/// water": the only place identity it had was a name, and the only way it knew
/// a place was watery was whether the name contained "water".
final class PlaceKindTests: XCTestCase {

    // MARK: The key

    func testKeyDropsApplesPrefixAndKeepsTheRest() {
        XCTAssertEqual(PlaceKind.key(fromCategoryRawValue: "MKPOICategoryBeach"), "beach")
        XCTAssertEqual(PlaceKind.key(fromCategoryRawValue: "MKPOICategoryNationalPark"), "nationalPark")
    }

    func testKeyIsNilWhenMapsOffersNoCategory() {
        XCTAssertNil(PlaceKind.key(fromCategoryRawValue: nil))
        XCTAssertNil(PlaceKind.key(fromCategoryRawValue: ""))
        XCTAssertNil(PlaceKind.key(fromCategoryRawValue: "   "))
    }

    /// A value that never carried the prefix is still a usable key, so the
    /// helper is safe to call on anything already stored.
    func testKeyPassesThroughAnUnprefixedValue() {
        XCTAssertEqual(PlaceKind.key(fromCategoryRawValue: "beach"), "beach")
    }

    // MARK: What the grimoire can now see

    private func features(label: String?, kind: String?) -> [LoomFeatureRef] {
        WorldConditionsProjector.features(for: BookPageContextSnapshot(
            locationLabel: label,
            placeKind: kind
        ))
    }

    func testAKindBecomesItsOwnFeature() {
        let ids = features(label: "The Quiet End", kind: "beach").map(\.id)
        XCTAssertTrue(ids.contains("place-kind:beach"))
    }

    /// The whole point: a name that merely contains "water" is not water.
    func testARealCategoryOutranksASuggestiveName() {
        let ids = features(label: "Waterloo Road Cafe", kind: "cafe").map(\.id)
        XCTAssertFalse(
            ids.contains("place-kind:water"),
            "a cafe on Waterloo Road is not a place beside water"
        )
    }

    /// And the other way: a beach the reader named themselves still counts.
    func testARealCategoryRescuesAPlaceWhoseNameHidesIt() {
        let ids = features(label: "The Quiet End", kind: "beach").map(\.id)
        XCTAssertTrue(
            ids.contains("place-kind:water"),
            "Maps says beach, so it is water whatever the reader called it"
        )
    }

    /// Pages kept before the taxonomy arrived carry no kind. They must keep the
    /// older reading rather than silently losing a feature they used to have.
    func testPagesWithoutAKindKeepTheOlderNameReading() {
        let ids = features(label: "Rockland Harbor", kind: nil).map(\.id)
        XCTAssertTrue(ids.contains("place-kind:water"))
    }

    func testNoPlaceMeansNoPlaceFeatures() {
        let ids = features(label: nil, kind: nil).map(\.id)
        XCTAssertFalse(ids.contains { $0.hasPrefix("place:") || $0.hasPrefix("place-kind:") })
    }

    /// Every feature this projector emits must sit in a domain it declares —
    /// the same contract `GrimoireWiringTests` enforces across the registry.
    func testEmittedPlaceFeaturesStayInsideDeclaredDomains() {
        let emitted = Set(features(label: "The Quiet End", kind: "beach").map(\.domain))
        XCTAssertTrue(emitted.isSubset(of: Set(WorldConditionsProjector.domains)))
    }
}
