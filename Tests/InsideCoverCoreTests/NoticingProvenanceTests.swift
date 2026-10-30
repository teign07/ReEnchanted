import XCTest
@testable import InsideCoverCore

/// Phase 0 of docs/noticing-and-writing-sessions-plan.md. bj's two reported
/// noticings were "photo media is connected to the word photo" and days "with
/// author in them". Both came from things the reader never wrote being counted
/// as if they had.
final class NoticingProvenanceTests: XCTestCase {
    private func readerPhotoPage(id: String = "photo-page") -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            promptText: "",
            userInput: "The gulls were arguing over the harbor.",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .photoLibraryAsset,
                    reference: "/tmp/gull.jpg",
                    metadata: [
                        "attentionModality": "photo",
                        "attentionLabels": "gull,water,pier",
                        "attentionSubject": "gull",
                        "attentionBrightness": "soft light",
                        "attentionColorMood": "muted",
                        "attentionComposition": "portrait, people-0",
                        "attentionBackend": "appleVisionClassifier,imageStatistics",
                        "attentionCertainty": "likely",
                        "proofPhoto": "true"
                    ]
                ),
                BookPageMediaAsset(
                    kind: .audioFile,
                    reference: "/tmp/note.m4a",
                    metadata: [
                        "keptVoice": "true",
                        "durationSeconds": "12",
                        BookPageMediaAsset.voiceTranscriptMetadataKey: "the lighthouse blinked twice"
                    ]
                )
            ]
        )
    }

    func testPhotoBookkeepingIsNotSomethingTheReaderNoticed() {
        let fingerprint = readerPhotoPage().resolvedAttentionFingerprint

        for bookkeeping in ["photo", "likely", "portrait", "people", "soft", "light", "muted",
                            "applevisionclassifier", "imagestatistics", "true"] {
            XCTAssertFalse(fingerprint.patternTokens.contains(bookkeeping), "counted \(bookkeeping)")
        }
        XCTAssertTrue(fingerprint.visualTokens.contains("gull"))
        XCTAssertTrue(fingerprint.visualTokens.contains("pier"))
        XCTAssertTrue(fingerprint.voiceTokens.contains("lighthouse"))
        XCTAssertEqual(Set(fingerprint.modalities), ["words", "photo", "voice"])
    }

    func testTheBooksOwnPromptIsNeverTheReadersWords() {
        let quote = BookPage(
            id: "quote-page",
            type: .quotes,
            promptText: "\u{201C}The world is full of magic things.\u{201D} \u{2014} the author W. B. Yeats",
            userInput: "I read this twice on the bus.",
            origin: .generated
        )
        let tokens = quote.resolvedAttentionFingerprint.patternTokens

        XCTAssertFalse(tokens.contains("author"))
        XCTAssertFalse(tokens.contains("yeats"))
        XCTAssertTrue(tokens.contains("twice"))
    }

    func testOldStoredFingerprintsAreRebuilt() {
        var page = readerPhotoPage()
        page.attentionFingerprint = AttentionFingerprint(
            subjectTokens: ["author"],
            visualTokens: ["likely", "portrait"],
            voiceTokens: ["true"],
            contextTokens: [],
            modalities: ["photo"]
        )

        let resolved = page.resolvedAttentionFingerprint

        XCTAssertEqual(resolved.version, AttentionFingerprint.currentVersion)
        XCTAssertFalse(resolved.patternTokens.contains("likely"))
        XCTAssertTrue(resolved.visualTokens.contains("gull"))
    }

    private func feature(_ id: String, _ family: RelationalLoomFeature.Family) -> RelationalLoomFeature {
        RelationalLoomFeature(
            id: id, family: family, label: id,
            conditionClause: id, outcomeClause: id,
            symbolName: "circle", carriesReaderSuppliedMeaning: false
        )
    }

    func testOneFactSeenTwiceIsNeverAConnection() {
        let photo = feature("modality:photo", .modality)
        XCTAssertTrue(RelationalLoom.areEntangled(photo, feature("visualPalette:blue", .visualPalette)))
        XCTAssertTrue(RelationalLoom.areEntangled(photo, feature("subject:photograph", .subject)))
        XCTAssertTrue(RelationalLoom.areEntangled(
            feature("visualBrightness:bright", .visualBrightness),
            feature("weather:sun", .weather)
        ))
        XCTAssertTrue(RelationalLoom.areEntangled(
            feature("activity:kept:weather", .activity),
            feature("weather:rain", .weather)
        ))
        XCTAssertTrue(RelationalLoom.areEntangled(
            feature("activity:kept:mood", .activity),
            feature("inner-weather:calm", .innerWeather)
        ))
        XCTAssertTrue(RelationalLoom.areEntangled(
            feature("context-blend:weather:rain+place:harbor", .contextBlend),
            feature("weather:fog", .weather)
        ))
    }

    func testThingsThatCouldHaveComeApartStillConnect() {
        XCTAssertFalse(RelationalLoom.areEntangled(feature("weather:rain", .weather), feature("place:harbor", .place)))
        XCTAssertFalse(RelationalLoom.areEntangled(
            feature("inner-weather:calm", .innerWeather),
            feature("weather:rain", .weather)
        ))
        XCTAssertFalse(RelationalLoom.areEntangled(
            feature("activity:kept:diary", .activity),
            feature("weather:rain", .weather)
        ))
        XCTAssertFalse(RelationalLoom.areEntangled(
            feature("context-blend:weather:rain+place:harbor", .contextBlend),
            feature("modality:photo", .modality)
        ))
    }
}
