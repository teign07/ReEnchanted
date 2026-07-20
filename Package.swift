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
                "ReEnchantedWidgetSnapshot.swift",
                "SentenceBuilder.swift",
                "BookArchiveDatabase.swift",
                "PageModel.swift",
                "Tarot.swift",
                "SurfaceAndCurator.swift",
                "NarrativeCore.swift",
                "StoryEngine.swift",
                "LiteraryContinuity.swift",
                "Constellations.swift",
                "TheBleed.swift",
                "MonthlyEdition.swift",
                "PhysicalBookOrders.swift",
                "EditionCurator.swift",
                "ReferenceLibrary.swift",
                "Illumination.swift",
                "WorldSystems.swift",
                "WorldEvents.swift",
                "PagePacks.swift",
                "SourceAdapters.swift",
                "StacksSearch.swift",
                "AlmanacModel.swift",
                "PressedPhotograph.swift",
                "PlainInkExport.swift",
                "QuillCompanion.swift"
            ]
        ),
        .testTarget(
            name: "InsideCoverCoreTests",
            dependencies: ["InsideCoverCore"],
            path: "Tests/InsideCoverCoreTests"
        )
    ]
)
