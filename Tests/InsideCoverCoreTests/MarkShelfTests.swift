import XCTest
@testable import InsideCoverCore

/// Guards for the browsing axis over the shared mark cabinet.
///
/// The failure this file exists to prevent already happened once: Pagewright
/// browsed by `IlluminationAssetKind`, `.doodle` swallowed 219 of 258 marks,
/// and an 80-item cap made 139 of them unreachable by hand. Shelves fix that
/// once. These tests keep the next two hundred marks from rebuilding it.
final class MarkShelfTests: XCTestCase {

    /// A shelf big enough to need scrolling past is a shelf on its way back to
    /// being "Field". When this trips, split the family — do not raise the cap.
    private let shelfCeiling = 60

    private var allMarks: [IlluminationPackRegistry.ShelvedMark] {
        IlluminationPackRegistry.shelvedMarks()
    }

    // MARK: - Filing

    func testEveryBundledMarkLandsOnAPermanentShelf() {
        let marks = allMarks
        XCTAssertFalse(marks.isEmpty, "The cabinet should not be empty.")

        for mark in marks where !mark.asset.isOccasional {
            XCTAssertTrue(
                MarkShelf.permanentShelves.contains(mark.shelf),
                "\(mark.asset.id) landed on \(mark.shelf.rawValue), which is a location, not a shelf."
            )
        }
    }

    func testResolverNeverReturnsALocation() {
        for pack in IlluminationPackRegistry.installedPacks {
            for asset in pack.allAssets {
                let shelf = MarkShelf.shelf(for: asset)
                XCTAssertFalse(
                    [.thisMonth, .pastMonths, .theDrawer].contains(shelf),
                    "\(asset.id) resolved to \(shelf.rawValue); those are decided at query time."
                )
            }
        }
    }

    func testNoShelfGrowsBackIntoTheFieldCategory() {
        var counts: [MarkShelf: Int] = [:]
        for mark in allMarks {
            counts[mark.shelf, default: 0] += 1
        }

        for (shelf, count) in counts {
            XCTAssertLessThanOrEqual(
                count, shelfCeiling,
                "\(shelf.title) holds \(count) marks. Split the family rather than raising the ceiling."
            )
        }
    }

    func testEveryOfferedShelfHasSomethingOnIt() {
        let populated = IlluminationPackRegistry.populatedShelves()
        for shelf in populated where shelf != .theDrawer {
            XCTAssertFalse(
                IlluminationPackRegistry.marks(on: shelf).isEmpty,
                "\(shelf.title) is offered to the reader and holds nothing."
            )
        }
    }

    func testTheCharacterfulShelvesAreActuallyPopulated() {
        // These are the families the reorganization exists to surface. If the
        // tag vocabulary drifts, they are the first to quietly empty out.
        for shelf: MarkShelf in [
            .academyDesk, .handwriting, .marginFolk, .inklings, .pressedAndGrown, .skyAndNight,
            .wayfinding, .creaturesAndCompany, .shore
        ] {
            XCTAssertFalse(
                IlluminationPackRegistry.marks(on: shelf).isEmpty,
                "\(shelf.title) is empty."
            )
        }
    }

    func testEveryAcademyHandIsFiledAsHandwriting() {
        let handwritten = IlluminationPackRegistry.installedPacks
            .flatMap(\.allAssets)
            .filter { $0.tags.contains("handwritten") && !$0.tags.contains("academy-tip") }

        XCTAssertGreaterThanOrEqual(handwritten.count, 50, "The Academy hands went missing.")
        for asset in handwritten {
            XCTAssertEqual(
                MarkShelf.shelf(for: asset), .handwriting,
                "\(asset.id) is handwritten but filed under \(MarkShelf.shelf(for: asset).rawValue)."
            )
        }

        let curriculum = IlluminationPackRegistry.installedPacks
            .flatMap(\.allAssets)
            .filter { $0.tags.contains("academy-tip") }
        XCTAssertEqual(curriculum.count, 12)
        for asset in curriculum {
            XCTAssertEqual(MarkShelf.shelf(for: asset), .academyDesk)
        }
    }

    func testTapeStaysWithTapeEvenWhenItIsBotanical() {
        // Function beats subject for fastenings: a reader hunting tape wants
        // all of it in one place, not three pieces here and one under ferns.
        let tape = IlluminationPackRegistry.installedPacks
            .flatMap(\.allAssets)
            .filter { $0.kind == .tape }

        XCTAssertFalse(tape.isEmpty)
        for asset in tape {
            XCTAssertEqual(MarkShelf.shelf(for: asset), .fastenings, "\(asset.id) wandered off.")
        }
    }

    func testAuthoredShelfBeatsTheResolver() {
        var asset = IlluminationAsset(
            id: "test-mark",
            assetName: "TestMark",
            kind: .doodle,
            tags: ["moon", "night"],
            supportedTemplates: IlluminatedTemplateID.allCases,
            defaultOpacity: 0.8,
            canTint: false
        )
        XCTAssertEqual(MarkShelf.shelf(for: asset), .skyAndNight)

        asset.leafTraits = LeafAssetTraits(shelf: .shore)
        XCTAssertEqual(MarkShelf.shelf(for: asset), .shore)
    }

    func testAuthoredLocationIsIgnored() {
        // A pack must not be able to park its own marks permanently on the
        // featured shelf.
        var asset = IlluminationAsset(
            id: "pushy-mark",
            assetName: "PushyMark",
            kind: .doodle,
            tags: ["moon"],
            supportedTemplates: IlluminatedTemplateID.allCases,
            defaultOpacity: 0.8,
            canTint: false,
            leafTraits: LeafAssetTraits(shelf: .thisMonth)
        )
        XCTAssertEqual(MarkShelf.shelf(for: asset), .skyAndNight)
        asset.leafTraits = nil
        XCTAssertEqual(MarkShelf.shelf(for: asset), .skyAndNight)
    }

    // MARK: - This Month

    func testOccasionalMarkMovesBetweenThisMonthAndPastMonths() {
        let asset = IlluminationAsset(
            id: "assembly-mark",
            assetName: "AssemblyMark",
            kind: .doodle,
            tags: ["words", "assembly"],
            supportedTemplates: IlluminatedTemplateID.allCases,
            defaultOpacity: 0.8,
            canTint: false,
            placementTrigger: IlluminationPlacementTrigger(
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["assembly"]
            )
        )
        XCTAssertTrue(asset.isOccasional)

        let live = IlluminationPlacementContext(
            semanticTags: [],
            month: 9,
            activeWorldEventIDs: ["dictionary-rebellion"],
            worldEventPhases: ["assembly"]
        )
        XCTAssertTrue(asset.placementTrigger!.allowsOccasion(live))
        XCTAssertFalse(asset.placementTrigger!.allowsOccasion(.empty))
    }

    func testSubjectGateDoesNotExpireATimedMark() {
        // A mark gated to both September and "harbor" must not read as over
        // merely because the browsing context names no harbour.
        let trigger = IlluminationPlacementTrigger(
            semanticTagsAny: ["harbor"],
            months: [9]
        )
        let september = IlluminationPlacementContext(
            semanticTags: [],
            month: 9,
            activeWorldEventIDs: [],
            worldEventPhases: []
        )
        XCTAssertFalse(trigger.allows(september), "The subject gate should still be closed.")
        XCTAssertTrue(trigger.allowsOccasion(september), "The month is open; the mark exists.")
    }

    func testNextIssuesMarksWaitUntilTheirOwnMonthAndDoNotReopenNextYear() {
        let trigger = IlluminationPlacementTrigger(months: [10], issueYear: 2026)
        func context(_ year: Int, _ month: Int) -> IlluminationPlacementContext {
            IlluminationPlacementContext(
                semanticTags: [], month: month, year: year,
                activeWorldEventIDs: [], worldEventPhases: []
            )
        }
        let september = context(2026, 9)
        let october = context(2026, 10)
        let november = context(2026, 11)
        let nextOctober = context(2027, 10)

        XCTAssertTrue(trigger.isFutureIssue(in: september))
        XCTAssertFalse(trigger.allowsOccasion(september))
        XCTAssertFalse(trigger.isFutureIssue(in: october))
        XCTAssertTrue(trigger.allows(october))
        XCTAssertFalse(trigger.allowsOccasion(november))
        XCTAssertFalse(trigger.allows(nextOctober))
    }

    func testMarksWithoutATriggerAreNotOccasional() {
        for mark in allMarks where mark.asset.placementTrigger == nil {
            XCTAssertFalse(mark.asset.isOccasional)
            XCTAssertNotEqual(mark.shelf, .thisMonth)
            XCTAssertNotEqual(mark.shelf, .pastMonths)
        }
    }

    // MARK: - The Drawer

    func testDrawerIsSmallStableAndDaily() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!

        let first = IlluminationPackRegistry.drawerMarks(on: monday, calendar: calendar)
        let again = IlluminationPackRegistry.drawerMarks(on: monday, calendar: calendar)
        let next = IlluminationPackRegistry.drawerMarks(on: tuesday, calendar: calendar)

        XCTAssertEqual(first.count, 12, "The drawer should stay a handful.")
        XCTAssertEqual(first.map(\.id), again.map(\.id), "The drawer moved under the reader's hand.")
        XCTAssertNotEqual(first.map(\.id), next.map(\.id), "The drawer never changed.")
    }

    func testDrawerHoldsNothingFromAClosedMonth() {
        for mark in IlluminationPackRegistry.drawerMarks() {
            XCTAssertNotEqual(
                mark.shelf, .pastMonths,
                "\(mark.asset.id) came out of a month that already ended."
            )
        }
    }

    // MARK: - Reach

    func testEveryMarkInTheCabinetIsReachable() {
        // The regression that started all this: marks that ship, are
        // catalogued, carry an achievement, and cannot be placed by hand.
        let cabinet = Set(
            IlluminationPackRegistry.unlockedPacks.flatMap(\.allAssets).map(\.id)
        )
        var reachable = Set<String>()
        for shelf in MarkShelf.displayOrder where shelf != .theDrawer {
            reachable.formUnion(IlluminationPackRegistry.marks(on: shelf).map(\.asset.id))
        }
        XCTAssertEqual(
            cabinet.subtracting(reachable), [],
            "These marks ship but no shelf shows them."
        )
    }
}
