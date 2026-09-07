// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InsideCoverCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "InsideCoverCore", targets: ["InsideCoverCore"])
    ],
    targets: [
        .target(
            name: "InsideCoverCore",
            path: "Shared",
            exclude: [
                "BookReferenceLibrary.json",
                "InsideCoverStore.swift"
            ],
            sources: [
                "InsideCoverState.swift",
                "SensitiveFileProtection.swift",
                "ExternalShareInbox.swift",
                "ReEnchantedWidgetSnapshot.swift",
                "SentenceBuilder.swift",
                "BookArchiveDatabase.swift",
                "BookInterruptionBudget.swift",
                "BookToday.swift",
                "BookWorkings.swift",
                "CastUndertakings.swift",
                "EmergentScenes.swift",
                "WorldPressure.swift",
                "PlaceMemory.swift",
                "WorldAccounts.swift",
                "AcademySeason.swift",
                "ContestedQuestions.swift",
                "AcademyDispatch.swift",
                "PageModel.swift",
                "Tarot.swift",
                "SurfaceAndCurator.swift",
                "NarrativeCore.swift",
                "StoryEngine.swift",
                "TaleGrammar.swift",
                "BraidScenePlan.swift",
                "WeeklyBindingPlan.swift",
                "StoryCanonLedger.swift",
                "StoryBeatTaste.swift",
                "ProseTaste.swift",
                "FolioSetting.swift",
                "LiteraryContinuity.swift",
                "Constellations.swift",
                "TheBleed.swift",
                "MonthlyEdition.swift",
                "PublicationPeriod.swift",
                "ReaderAtlas.swift",
                "EditionPlayContent.swift",
                "PhysicalBookOrders.swift",
                "EditionCurator.swift",
                "ReferenceLibrary.swift",
                "Illumination.swift",
                "EditionMarginalia.swift",
                "WorldSystems.swift",
                "WorldEvents.swift",
                "AuthoredContent.swift",
                "MonthlyIssueAuthoring.swift",
                "MonthlyIssueNativeContent.swift",
                "PagePacks.swift",
                "SourceAdapters.swift",
                "StacksSearch.swift",
                "AlmanacModel.swift",
                "PressedPhotograph.swift",
                "PlainInkExport.swift",
                "QuillCompanion.swift",
                "BindingRevelations.swift",
                "BookClaimTier.swift",
                "Daybook.swift",
                "StandingLedger.swift",
                "InferredSignals.swift",
                "ReadersSheet.swift",
                "TwinExperiments.swift",
                "VisualFacts.swift",
                "DayBitset.swift",
                "GrimoireExperiments.swift",
                "GrimoireLedger.swift",
                "GrimoireSweep.swift",
                "GrimoireVoice.swift",
                "LoomProjectors.swift",
                "GrimoireSurfacing.swift",
                "Atlas.swift",
                "Bestiary.swift",
                "BestiaryNoticing.swift",
                "BestiarySurfacing.swift",
                "CreatureLore.swift"
            ]
        ),
        .testTarget(
            name: "InsideCoverCoreTests",
            dependencies: ["InsideCoverCore"],
            path: "Tests/InsideCoverCoreTests"
        )
    ]
)
