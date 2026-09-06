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

/// Phase 2: what the shelf prints.
final class CorrespondenceShelfTests: XCTestCase {

    /// With no ledger the shelf is the inherited half alone — which is exactly
    /// a new reader's first night, and it must still be worth opening.
    func testAColdShelfIsStillWorthOpening() {
        let sections = CorrespondenceShelf.sections()
        XCTAssertEqual(sections.map(\.id), ["untested", "folk", "academy"])
        XCTAssertTrue(sections.flatMap(\.rows).allSatisfy { $0.origin == .inherited })
        XCTAssertGreaterThanOrEqual(sections.flatMap(\.rows).count, 10)
    }

    func testNothingTheBookHasNotSaidReachesTheShelf() {
        XCTAssertTrue(
            CorrespondenceShelf.sections().allSatisfy { $0.rows.allSatisfy { $0.origin == .inherited } },
            "an empty ledger must contribute no findings of the Book's own"
        )
    }

    func testEverySectionSaysSomethingAndHoldsSomething() {
        for section in CorrespondenceShelf.sections() {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.note.isEmpty, "\(section.id) has a heading and no voice")
            XCTAssertFalse(section.rows.isEmpty, "\(section.id) is an empty heading")
        }
    }

    /// Every inherited row appears exactly once. A row that fell between the
    /// "untested" and "furniture" filters would simply vanish from the shelf.
    func testEveryInheritedRowIsPrintedExactlyOnce() {
        let printed = CorrespondenceShelf.sections().flatMap(\.rows).map(\.id)
        XCTAssertEqual(printed.count, Set(printed).count, "a row is printed twice")
        XCTAssertEqual(
            Set(printed),
            Set(CorrespondenceLibraryRegistry.all.map { "inherited:\($0.id)" }),
            "a row went missing between the sections"
        )
    }

    func testEveryPrintedRowSaysWhoSaysSo() {
        for row in CorrespondenceShelf.sections().flatMap(\.rows) {
            XCTAssertFalse(row.headline.isEmpty, "\(row.id) has no headline")
            XCTAssertFalse(row.attribution.isEmpty, "\(row.id) claims something with nobody's name on it")
        }
    }

    func testAnEmptyShelfPrintsNoEmptyHeadings() {
        XCTAssertTrue(CorrespondenceShelf.sections(inherited: []).isEmpty)
    }

    /// The contents line is redrawn on every desk build, so a number in it
    /// would have to be right every time.
    func testTheContentsLineCarriesNoCount() {
        XCTAssertFalse(CorrespondenceShelf.contentsDetail.contains { $0.isNumber })
    }
}

/// Phase 3: what happens where the two halves meet.
///
/// These hand-build ledger rows on purpose. The claim under test is not "the
/// Book can find X" — that would need real observations projected through the
/// engine, and `InheritedCorrespondenceTests`' wiring lint already covers the
/// feature ids these rows are keyed to. The claim here is narrower: *given* a
/// row in a given state, the shelf says the right thing about it and puts it in
/// the right place.
final class CorrespondenceMeetingTests: XCTestCase {

    private func ledger(_ pairs: [(condition: String, state: GrimoireClaimState)]) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        for (index, pair) in pairs.enumerated() {
            ledger.rows["r\(index)"] = GrimoireCorrespondence(
                id: "r\(index)", shape: .conditional,
                conditionID: pair.condition, outcomeID: "word:lantern",
                state: pair.state, firstObservedAt: Date(), lastObservedAt: Date(),
                falsifier: nil, revisions: [], readerStatus: nil,
                lastSpokenAt: Date(), strengthPeak: 60, interestPeak: 40
            )
        }
        return ledger
    }

    private var waterRow: InheritedCorrespondence {
        CorrespondenceLibraryRegistry.all.first { $0.observable == "place-kind:water" }!
    }

    func testNoEvidenceMeansNoMeeting() {
        XCTAssertNil(CorrespondenceShelf.meetingLine(for: waterRow, in: GrimoireLedger()))
    }

    func testLoreOnlyRowsCanNeverMeetAnything() {
        let furniture = CorrespondenceLibraryRegistry.loreOnly
        let busy = ledger([("place-kind:water", .standing), ("weather:rain", .standing)])
        for row in furniture {
            XCTAssertNil(
                CorrespondenceShelf.meetingLine(for: row, in: busy),
                "\(row.id) has no observable and must never acquire evidence"
            )
        }
    }

    func testTheBookAgreesWhenItsOwnRuleStands() {
        let line = CorrespondenceShelf.meetingLine(
            for: waterRow, in: ledger([("place-kind:water", .standing)])
        )
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("agree") == true)
    }

    /// The important direction: the Book contradicting inherited lore, on
    /// borrowed authority, which it can do long before it has rules of its own.
    func testTheBookContradictsWhenItHadToCrossItsOwnRuleOut() {
        let line = CorrespondenceShelf.meetingLine(
            for: waterRow, in: ledger([("place-kind:water", .crossedOut)])
        )
        XCTAssertNotNil(line)
        XCTAssertTrue(line?.contains("cross") == true)
        XCTAssertTrue(
            line?.contains("only have your days") == true,
            "a contradiction must not claim the tradition is wrong, only that it did not hold here"
        )
    }

    /// A crossing-out outranks agreement: owing a correction is more
    /// interesting than the Book being pleased with itself.
    func testTakingSomethingBackOutranksAgreement() {
        let line = CorrespondenceShelf.meetingLine(
            for: waterRow,
            in: ledger([("place-kind:water", .standing), ("place-kind:water", .crossedOut)])
        )
        XCTAssertTrue(line?.contains("cross") == true)
    }

    func testAnUnrelatedRuleIsNotAMeeting() {
        XCTAssertNil(CorrespondenceShelf.meetingLine(
            for: waterRow, in: ledger([("weather:fog", .standing)])
        ))
    }

    // MARK: Placement

    func testAMetRowLeavesTheUntestedSection() {
        let met = CorrespondenceShelf.sections(ledger: ledger([("place-kind:water", .standing)]))
        let untested = met.first { $0.id == "untested" }?.rows.map(\.id) ?? []
        let meeting = met.first { $0.id == "met" }?.rows.map(\.id) ?? []
        XCTAssertFalse(untested.contains("inherited:\(waterRow.id)"))
        XCTAssertTrue(meeting.contains("inherited:\(waterRow.id)"))
    }

    func testEveryInheritedRowIsStillPrintedExactlyOnceWithEvidence() {
        let sections = CorrespondenceShelf.sections(
            ledger: ledger([
                ("place-kind:water", .standing),
                ("weather:rain", .crossedOut),
                ("hour:evening", .watching)
            ])
        )
        let printed = sections.flatMap(\.rows).filter { $0.origin == .inherited }.map(\.id)
        XCTAssertEqual(printed.count, Set(printed).count, "a row is printed twice")
        XCTAssertEqual(printed.count, CorrespondenceLibraryRegistry.all.count)
    }

    /// A claim with no days behind it is not a claim. Hand-built rows have no
    /// ingested observations, so the shelf must decline to print them rather
    /// than print a half-built sentence.
    func testAFindingWithNothingUnderItIsNotPrinted() {
        let bare = ledger([("place-kind:water", .standing)])
        let row = bare.rows.values.first!
        XCTAssertNil(CorrespondenceShelf.item(for: row, ledger: bare))
        let sections = CorrespondenceShelf.sections(ledger: bare)
        XCTAssertTrue(sections.flatMap(\.rows).allSatisfy { $0.origin == .inherited })
    }
}
