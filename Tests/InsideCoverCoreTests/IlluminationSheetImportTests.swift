import XCTest
@testable import InsideCoverCore

/// Two hand-painted sheets cut into individual marks. They enter the one shared
/// cabinet, so Pages Rising, Pagewright, and illuminated photos all see them —
/// there is deliberately no surface-specific decoration registry.
final class IlluminationSheetImportTests: XCTestCase {
    private var imported: [IlluminationAsset] {
        IlluminationPackRegistry.installedPacks
            .flatMap(\.allAssets)
            .filter { $0.assetName.hasPrefix("IlluminationStain") || $0.assetName.hasPrefix("IlluminationFlourish") }
    }

    private var punctuationPixieAssets: [IlluminationAsset] {
        CoreMarginsPack.pack.allAssets.filter { $0.assetName.hasPrefix("Punctuation") }
    }

    private var marginaliaGoblinAssets: [IlluminationAsset] {
        CoreMarginsPack.pack.allAssets.filter { $0.assetName.hasPrefix("MarginaliaGoblin") }
    }

    private var academyNoteAssets: [IlluminationAsset] {
        CoreMarginsPack.pack.allAssets.filter { $0.assetName.hasPrefix("AcademyNote") }
    }

    private var academyWarningAssets: [IlluminationAsset] {
        CoreMarginsPack.pack.allAssets.filter { $0.assetName.hasPrefix("AcademyWarning") }
    }

    func testBothSheetsReachedTheSharedCabinet() {
        let stains = imported.filter { $0.assetName.hasPrefix("IlluminationStain") }
        let flourishes = imported.filter { $0.assetName.hasPrefix("IlluminationFlourish") }
        XCTAssertEqual(stains.count, 43)
        XCTAssertEqual(flourishes.count, 49)
    }

    func testEveryImportedMarkStatesItsOwnArtDirection() {
        for asset in imported {
            guard let traits = asset.leafTraits else {
                return XCTFail("\(asset.assetName) carries no art direction.")
            }
            XCTAssertNotNil(traits.semanticRole, "\(asset.assetName) does not say what it is.")
            XCTAssertFalse(traits.preferredAnchors?.isEmpty ?? true, "\(asset.assetName) has no opinion about where it sits.")
            XCTAssertNotNil(traits.aspectRatio, "\(asset.assetName) needs its real proportions to be sized.")
        }
    }

    /// The rule that protects legibility: a mark may only lie under prose if it
    /// is pale enough to read through, and then only as a watermark.
    func testOnlyPaleStainsMayLieUnderProse() {
        for asset in imported {
            let traits = asset.leafTraits
            guard traits?.allowsTextOverlap == true else { continue }
            XCTAssertTrue(
                asset.assetName.hasPrefix("IlluminationStain"),
                "\(asset.assetName): only a stain should ever sit under text."
            )
            XCTAssertEqual(traits?.semanticRole, .texture)
            XCTAssertEqual(traits?.preferredAnchors, [.watermark])
        }

        // Line art is opaque and must never run beneath reading matter.
        for asset in imported where asset.assetName.hasPrefix("IlluminationFlourish") {
            XCTAssertNotEqual(asset.leafTraits?.allowsTextOverlap, true, "\(asset.assetName)")
        }
    }

    func testMarksAreUniquelyIdentifiedAndNamed() {
        let ids = imported.map(\.id)
        let names = imported.map(\.assetName)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate asset ids would make selection ambiguous.")
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testPunctuationPixieSheetReachedBaseContentWithMeaning() {
        XCTAssertEqual(punctuationPixieAssets.count, 28)
        XCTAssertEqual(punctuationPixieAssets.filter { $0.kind == .stamp }.count, 9)
        XCTAssertEqual(punctuationPixieAssets.filter { $0.kind == .doodle }.count, 19)
        XCTAssertEqual(Set(punctuationPixieAssets.map(\.id)).count, 28)
        XCTAssertEqual(Set(punctuationPixieAssets.map(\.assetName)).count, 28)

        for asset in punctuationPixieAssets {
            XCTAssertTrue(asset.tags.contains("punctuation"), "\(asset.assetName) lost its theme")
            XCTAssertNotNil(asset.leafTraits?.semanticRole, "\(asset.assetName) has no physical role")
            XCTAssertNotNil(asset.leafTraits?.aspectRatio, "\(asset.assetName) lost its cut proportions")
            XCTAssertFalse(asset.leafTraits?.preferredAnchors?.isEmpty ?? true, "\(asset.assetName) has nowhere to sit")
            XCTAssertEqual(asset.leafTraits?.allowsTextOverlap, false, "\(asset.assetName) must not lie under prose")
        }
    }

    func testMarginaliaGoblinSheetReachedBaseContentWithMeaning() {
        XCTAssertEqual(marginaliaGoblinAssets.count, 39)
        XCTAssertEqual(marginaliaGoblinAssets.filter { $0.kind == .stamp }.count, 3)
        XCTAssertEqual(marginaliaGoblinAssets.filter { $0.kind == .doodle }.count, 36)
        XCTAssertEqual(Set(marginaliaGoblinAssets.map(\.id)).count, 39)
        XCTAssertEqual(Set(marginaliaGoblinAssets.map(\.assetName)).count, 39)

        for asset in marginaliaGoblinAssets {
            XCTAssertTrue(asset.tags.contains("marginalia-goblin"), "\(asset.assetName) lost its character family")
            XCTAssertTrue(asset.tags.contains("academy"), "\(asset.assetName) lost its world theme")
            XCTAssertNotNil(asset.leafTraits?.semanticRole, "\(asset.assetName) has no physical role")
            XCTAssertNotNil(asset.leafTraits?.aspectRatio, "\(asset.assetName) lost its cut proportions")
            XCTAssertFalse(asset.leafTraits?.preferredAnchors?.isEmpty ?? true, "\(asset.assetName) has nowhere to sit")
            XCTAssertEqual(asset.leafTraits?.allowsTextOverlap, false, "\(asset.assetName) must not lie under prose")
        }
    }

    func testFirstAcademyNoteSheetReachedBaseContentAsOpaqueInk() {
        XCTAssertEqual(academyNoteAssets.count, 37)
        XCTAssertEqual(Set(academyNoteAssets.map(\.id)).count, 37)
        XCTAssertEqual(Set(academyNoteAssets.map(\.assetName)).count, 37)

        for asset in academyNoteAssets {
            XCTAssertEqual(asset.kind, .doodle)
            XCTAssertTrue(asset.tags.contains("academy"), "\(asset.assetName) lost its world theme")
            XCTAssertTrue(asset.tags.contains("handwritten"), "\(asset.assetName) lost its medium")
            XCTAssertEqual(asset.defaultOpacity, 1, "\(asset.assetName) should be solid ink")
            XCTAssertEqual(asset.leafTraits?.semanticRole, .scribble)
            XCTAssertEqual(asset.leafTraits?.allowsTextOverlap, false, "\(asset.assetName) must stay out of prose")
        }
    }

    func testSecondAcademyNoteSheetReachedBaseContentAsSemanticWarnings() {
        XCTAssertEqual(academyWarningAssets.count, 16)
        XCTAssertEqual(Set(academyWarningAssets.map(\.id)).count, 16)
        XCTAssertEqual(Set(academyWarningAssets.map(\.assetName)).count, 16)

        for asset in academyWarningAssets {
            XCTAssertEqual(asset.kind, .doodle)
            XCTAssertTrue(asset.tags.contains("academy"), "\(asset.assetName) lost its world theme")
            XCTAssertTrue(asset.tags.contains("warning"), "\(asset.assetName) lost its family")
            XCTAssertEqual(asset.defaultOpacity, 1, "\(asset.assetName) should be solid ink")
            XCTAssertEqual(asset.leafTraits?.semanticRole, .scribble)
            XCTAssertEqual(asset.leafTraits?.allowsTextOverlap, false, "\(asset.assetName) must stay out of prose")
        }
    }

    func testNewBaseFamiliesAreReachableByTheirSemanticIdentity() throws {
        let resolver = IlluminationAssetResolver()
        let pack = CoreMarginsPack.pack

        let pixie = try XCTUnwrap(resolver.resolveAsset(
            kind: .doodle,
            tags: ["punctuation-pixie"],
            template: nil,
            installedPacks: [pack]
        ))
        XCTAssertTrue(pixie.assetName.hasPrefix("PunctuationPixie"))

        let goblin = try XCTUnwrap(resolver.resolveAsset(
            kind: .doodle,
            tags: ["marginalia-goblin"],
            template: nil,
            installedPacks: [pack]
        ))
        XCTAssertTrue(goblin.assetName.hasPrefix("MarginaliaGoblin"))

        let note = try XCTUnwrap(resolver.resolveAsset(
            kind: .doodle,
            tags: ["reader-words"],
            template: nil,
            installedPacks: [pack]
        ))
        XCTAssertEqual(note.assetName, "AcademyNoteHoldYourWords")

        let warning = try XCTUnwrap(resolver.resolveAsset(
            kind: .doodle,
            tags: ["blue-thread"],
            template: nil,
            installedPacks: [pack]
        ))
        XCTAssertEqual(warning.assetName, "AcademyWarningFollowBlueThread")

        let strongestWarning = try XCTUnwrap(resolver.resolveAsset(
            kind: .doodle,
            tags: ["book", "thread", "blue-thread", "guidance"],
            template: nil,
            installedPacks: [pack]
        ))
        XCTAssertEqual(strongestWarning.assetName, "AcademyWarningFollowBlueThread")
    }

    func testPrintedLeafTextBecomesMarginaliaMotifsWithoutAModelCall() {
        let motifs = LeafDecorationLibrary.semanticMotifs(in: """
        At dusk the goblins followed the blue thread by moonlight.
        A question mark scratched at the library door.
        """)

        XCTAssertTrue(motifs.contains("marginalia-goblin"))
        XCTAssertTrue(motifs.contains("blue-thread"))
        XCTAssertTrue(motifs.contains("moonlight"))
        XCTAssertTrue(motifs.contains("question-mark"))
        XCTAssertTrue(motifs.contains("library"))
        XCTAssertTrue(motifs.contains("door"))
    }

    func testSemanticTextMatchingUsesWordsRatherThanSubstrings() {
        let motifs = LeafDecorationLibrary.semanticMotifs(
            in: "A notebook sat beside a compass. Nothing moved."
        )

        XCTAssertFalse(motifs.contains("book"))
        XCTAssertFalse(motifs.contains("momort"))
        XCTAssertFalse(motifs.contains("marginalia-goblin"))
        XCTAssertFalse(motifs.contains("punctuation-pixie"))
    }

    func testRecipeCarriesLiteralPageSubjectsIntoComposition() {
        let recipe = LeafDecorationLibrary.recipe(
            pageType: .diary,
            metadata: [:],
            semanticText: "Wicker left a warning beside the full moon map.",
            documentID: "semantic-page",
            leafIndex: 0
        )

        XCTAssertTrue(recipe.motifs.contains("wicker-eddies"))
        XCTAssertTrue(recipe.motifs.contains("warning"))
        XCTAssertTrue(recipe.motifs.contains("full-moon"))
        XCTAssertTrue(recipe.motifs.contains("map"))
    }
}

extension IlluminationSheetImportTests {
    func testPlacementTriggerCanGateOneWorldEventPhaseAndMonth() {
        let trigger = IlluminationPlacementTrigger(
            semanticTagsAny: ["words"],
            months: [9],
            activeWorldEventIDs: ["dictionary-rebellion"],
            worldEventPhases: ["assembly"]
        )
        let matching = IlluminationPlacementContext(
            semanticTags: ["book", "words"],
            month: 9,
            activeWorldEventIDs: ["dictionary-rebellion"],
            worldEventPhases: ["assembly"]
        )

        XCTAssertTrue(trigger.allows(matching))
        XCTAssertFalse(trigger.allows(IlluminationPlacementContext(
            semanticTags: matching.semanticTags,
            month: matching.month,
            activeWorldEventIDs: matching.activeWorldEventIDs,
            worldEventPhases: ["outbreak"]
        )))
        XCTAssertFalse(trigger.allows(IlluminationPlacementContext(
            semanticTags: matching.semanticTags,
            month: 10,
            activeWorldEventIDs: matching.activeWorldEventIDs,
            worldEventPhases: matching.worldEventPhases
        )))
    }

    func testResolverCannotChooseARestrictedMarkOutsideItsPhase() throws {
        var mark = try XCTUnwrap(CoreMarginsPack.pack.doodles.first)
        mark.placementTrigger = IlluminationPlacementTrigger(
            activeWorldEventIDs: ["dictionary-rebellion"],
            worldEventPhases: ["assembly"]
        )
        var pack = CoreMarginsPack.pack
        pack.doodles = [mark]
        let resolver = IlluminationAssetResolver()

        XCTAssertNil(resolver.resolveAsset(
            kind: .doodle,
            tags: ["words"],
            template: nil,
            installedPacks: [pack],
            placementContext: IlluminationPlacementContext(
                semanticTags: ["words"],
                month: 9,
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["outbreak"]
            )
        ))
        XCTAssertEqual(resolver.resolveAsset(
            kind: .doodle,
            tags: ["words"],
            template: nil,
            installedPacks: [pack],
            placementContext: IlluminationPlacementContext(
                semanticTags: ["words"],
                month: 9,
                activeWorldEventIDs: ["dictionary-rebellion"],
                worldEventPhases: ["assembly"]
            )
        )?.id, mark.id)
    }

    /// Registering a mark is not the same as it ever being chosen. The recipe
    /// picks from the cabinet by kind and motif, so run it across many leaves
    /// and confirm the imported sheets actually reach the page.
    func testImportedMarksAreActuallySelectable() {
        var seenStain = 0
        var seenFlourish = 0
        var drew = 0

        for i in 0..<400 {
            let recipe = LeafDecorationLibrary.recipe(
                pageType: i.isMultiple(of: 2) ? BookPageType.diary : BookPageType.letter,
                metadata: [:],
                documentID: "import-probe-\(i)",
                leafIndex: i % 3
            )
            let names: [String] = [recipe.primaryAsset, recipe.secondaryAsset, recipe.supportAsset, recipe.fasteningAsset, recipe.textureOverlay]
                    .compactMap { $0?.assetName }
            if !names.isEmpty { drew += 1 }
            if names.contains(where: { $0.hasPrefix("IlluminationStain") }) { seenStain += 1 }
            if names.contains(where: { $0.hasPrefix("IlluminationFlourish") }) { seenFlourish += 1 }
        }

        XCTAssertGreaterThan(drew, 0, "Precondition: the recipe draws marks at all.")
        XCTAssertGreaterThan(seenStain, 0, "No imported stain was ever selected across 400 leaves.")
        XCTAssertGreaterThan(seenFlourish, 0, "No imported flourish was ever selected across 400 leaves.")
    }

    func testPaperStocksHaveDistinctMaterialAssetsAndRestrainedOpacity() {
        let stocks = LeafPaperStock.allCases
        XCTAssertEqual(Set(stocks.map(\.assetName)).count, stocks.count)
        XCTAssertTrue(stocks.allSatisfy { (0.15...0.34).contains($0.baseOpacity) })
    }

    func testEveryLeafInOnePageKeepsTheSamePaperStock() {
        let stocks = (0..<9).map { leafIndex in
            LeafDecorationLibrary.recipe(
                pageType: .bookFae,
                metadata: [:],
                documentID: "one-bound-page",
                leafIndex: leafIndex
            ).paperStock
        }

        XCTAssertEqual(Set(stocks).count, 1)
    }

    func testPaperStockFamiliesVaryDeterministicallyAcrossPages() {
        let firstPass = (0..<120).map { index in
            LeafPaperStock.resolve(pageType: .diary, documentID: "paper-page-\(index)")
        }
        let secondPass = (0..<120).map { index in
            LeafPaperStock.resolve(pageType: .diary, documentID: "paper-page-\(index)")
        }

        XCTAssertEqual(firstPass, secondPass)
        XCTAssertGreaterThanOrEqual(Set(firstPass).count, 3)
    }

    // MARK: - The herbarium sheet

    private var botanicalAssets: [IlluminationAsset] {
        CoreMarginsPack.pack.allAssets.filter { $0.assetName.hasPrefix("Botanical") }
    }

    func testHerbariumSheetReachedTheSharedCabinet() {
        XCTAssertEqual(botanicalAssets.count, 24)
        XCTAssertEqual(Set(botanicalAssets.map(\.id)).count, 24)
        XCTAssertEqual(Set(botanicalAssets.map(\.assetName)).count, 24)

        for asset in botanicalAssets {
            XCTAssertEqual(asset.kind, .doodle)
            XCTAssertTrue(asset.tags.contains("botanical"), "\(asset.assetName) lost its family")
            XCTAssertEqual(asset.leafTraits?.semanticRole, .botanical)
            XCTAssertEqual(
                asset.leafTraits?.allowsTextOverlap, false,
                "\(asset.assetName) is opaque paint and must not lie under prose"
            )
        }
    }

    /// A foxglove is taller than it is wide, and the folio can only know that
    /// if the cut proportions came across with the art.
    func testEveryPressedStudyCarriesItsRealProportions() {
        for asset in botanicalAssets {
            guard let ratio = asset.leafTraits?.aspectRatio else {
                return XCTFail("\(asset.assetName) lost its cut proportions")
            }
            XCTAssertTrue(
                (0.4...2.5).contains(ratio),
                "\(asset.assetName) has an implausible aspect ratio of \(ratio)"
            )
            XCTAssertFalse(
                asset.leafTraits?.preferredAnchors?.isEmpty ?? true,
                "\(asset.assetName) has no opinion about where it sits"
            )
        }
    }

    /// The whole sheet belongs on Pressed & Grown, and the way it gets there is
    /// its own tags — not an authored `shelf`.
    ///
    /// This guards a real trap: the shelf cascade reads `fae` as a *character*
    /// family, so tagging a toadstool with it silently filed the mushroom under
    /// Margin Folk and pushed that shelf over its ceiling.
    func testThePressedSheetStaysOnOneShelf() {
        for asset in botanicalAssets {
            XCTAssertNil(asset.leafTraits?.shelf, "\(asset.assetName) should be filed by its tags")
            XCTAssertEqual(
                MarkShelf.shelf(for: asset), .pressedAndGrown,
                "\(asset.assetName) wandered off Pressed & Grown"
            )
        }
    }

    /// Every cut names a distinct plant, so the Book never places two marks a
    /// reader would read as the same specimen.
    func testEveryStudyNamesItsOwnPlant() {
        var subjects: Set<String> = []
        for asset in botanicalAssets {
            let generic: Set<String> = ["botanical", "pressed", "plant", "herbarium"]
            let named = Set(asset.tags).subtracting(generic)
            XCTAssertFalse(named.isEmpty, "\(asset.assetName) is a plant with no species tags")
            let identifier = asset.id.replacingOccurrences(of: "botanical_", with: "")
            XCTAssertTrue(subjects.insert(identifier).inserted, "\(identifier) was cut twice")
        }
        XCTAssertEqual(subjects.count, 24)
    }
}
