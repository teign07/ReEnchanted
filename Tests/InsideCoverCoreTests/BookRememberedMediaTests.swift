import XCTest
@testable import InsideCoverCore

final class BookRememberedMediaTests: XCTestCase {
    func testSurfaceMediaMetadataRoundTripsTheExistingMediaModel() {
        let assets = [
            BookPageMediaAsset(
                id: "plate",
                kind: .renderedImageFile,
                reference: "/private/plate.jpg",
                caption: "The kept plate",
                sourceID: "illuminated-photo",
                metadata: ["proof": "reader"]
            ),
            BookPageMediaAsset(
                id: "voice",
                kind: .audioFile,
                reference: "/private/voice.m4a",
                sourceID: "voice-note"
            )
        ]

        let encoded = BookPageMediaAsset.encodedForSurfaceMetadata(assets)

        XCTAssertEqual(BookPageMediaAsset.decodedFromSurfaceMetadata(encoded), assets)
    }

    func testBookRememberedReturnsThePlateWithoutPrintingItsFilename() {
        let now = Date(timeIntervalSince1970: 1_786_550_400)
        let plate = BookPageMediaAsset(
            id: "kept-plate",
            kind: .renderedImageFile,
            reference: "/private/illuminated-ABC123.jpg",
            caption: "A remembered ordinary thing",
            sourceID: "illuminated-photo"
        )
        let page = BookPage(
            id: "old-illuminated-page",
            type: .illuminatedPhoto,
            createdAt: now.addingTimeInterval(-90 * 86_400),
            promptText: "Look what the light kept.",
            userInput: "The chipped cup caught the window.\n\nRendered plate: illuminated-ABC123.jpg",
            tags: ["illuminated-photo"],
            origin: .userAuthored,
            mediaAssets: [plate]
        )
        let visitation = BookRememberedVisitation(
            page: page,
            score: 70,
            reason: "The same blue came back.",
            todayConnections: ["Blue crossed the old Page and today."],
            action: "Look once more."
        )

        let surface = visitation.surface(
            source: BookPageSourceRegistry.source(for: .bookRemembered),
            day: BookDay(id: BookDay.id(for: now), date: now, pages: []),
            now: now
        )

        XCTAssertFalse(surface.payload.body.contains("Rendered plate:"))
        XCTAssertFalse(surface.payload.body.contains("illuminated-ABC123.jpg"))
        XCTAssertEqual(surface.mediaAssets, [plate])
    }
}
