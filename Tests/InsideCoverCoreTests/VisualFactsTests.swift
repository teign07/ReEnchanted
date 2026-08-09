import XCTest
@testable import InsideCoverCore

/// The perception packet is the seam between what a photograph contained and
/// what the Book is later allowed to say it contained. These tests guard the
/// two properties the archive depends on: that a dedicated recognizer's reading
/// outranks a permissive whole-image guess, and that a fact's uncertainty
/// survives all the way into the text a writer is handed. A caption that
/// upgrades "maybe" to "clearly" is not a style problem — it is the Book
/// inventing a memory.
final class VisualFactsTests: XCTestCase {

    private func fact(
        _ kind: VisualFactKind,
        _ label: String,
        _ confidence: Double,
        _ source: VisualFactSource,
        region: VisualRegion? = nil
    ) -> VisualFact {
        VisualFact(kind: kind, label: label, confidence: confidence, source: source, region: region)
    }

    // MARK: - The cat the old pipeline could not see

    func testRecognizedAnimalOutranksAConfidentWholeImageLabel() {
        // The exact failure the ensemble exists to fix: the classifier is very
        // sure about the room, and the animal recognizer is less sure about the
        // cat, but the cat is what the photograph is *of*.
        let packet = VisualFactPacket(facts: [
            fact(.setting, "furniture", 0.82, .appleVisionClassifier),
            fact(.setting, "textile", 0.74, .appleVisionClassifier),
            fact(.animal, "Cat", 0.61, .appleVisionAnimal,
                 region: VisualRegion(x: 0.1, y: 0.1, width: 0.4, height: 0.4))
        ])

        XCTAssertEqual(packet.primarySubject?.label, "cat")
        XCTAssertEqual(packet.primarySubject?.kind, .animal)
    }

    func testSaliencyCropLabelOutranksAnEqualWholeImageGuess() {
        // A crop was classified because saliency thought something was there,
        // so at equal confidence it should beat the frame-wide guess.
        let packet = VisualFactPacket(facts: [
            fact(.setting, "indoors", 0.5, .appleVisionClassifier),
            fact(.object, "teacup", 0.5, .appleVisionSaliencyCrop,
                 region: VisualRegion(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
        ])

        XCTAssertEqual(packet.primarySubject?.label, "teacup")
    }

    func testImageStatisticsNeverWinTheSubjectSlot() {
        // Brightness is measured and therefore highly confident, which must not
        // let it masquerade as what the photo is about.
        let packet = VisualFactPacket(facts: [
            fact(.light, "bright light", 0.9, .imageStatistics),
            fact(.colour, "warm", 0.9, .imageStatistics),
            fact(.object, "boat", 0.3, .appleVisionClassifier)
        ])

        XCTAssertEqual(packet.primarySubject?.label, "boat")
    }

    // MARK: - Certainty survives into the prose

    func testCertaintyBandsMapToHedgesTheWriterCanObey() {
        XCTAssertEqual(VisualCertainty(confidence: 0.2), .possible)
        XCTAssertEqual(VisualCertainty(confidence: 0.5), .likely)
        XCTAssertEqual(VisualCertainty(confidence: 0.95), .clear)
        XCTAssertEqual(VisualCertainty(confidence: 0.2).hedge, "maybe")
    }

    func testGroundingLinesCarryTheHedgeAndNeverANumber() {
        let packet = VisualFactPacket(facts: [
            fact(.animal, "dog", 0.28, .appleVisionAnimal,
                 region: VisualRegion(x: 0.0, y: 0.0, width: 0.2, height: 0.2))
        ])

        let line = try? XCTUnwrap(packet.groundingLines.first)
        XCTAssertEqual(line?.hasPrefix("maybe: dog"), true)
        // A decimal reaching the prompt invites the writer to reason about it.
        XCTAssertFalse(packet.groundingLines.joined().contains("0."))
    }

    func testProminentSubjectIsAnnouncedAsLargeInFrame() {
        let packet = VisualFactPacket(facts: [
            fact(.animal, "cat", 0.9, .appleVisionAnimal,
                 region: VisualRegion(x: 0.0, y: 0.0, width: 0.4, height: 0.5))
        ])

        let joined = packet.groundingLines.joined(separator: "\n")
        XCTAssertTrue(joined.contains("large in frame"))
        XCTAssertTrue(joined.contains("lower left"))
    }

    func testVisibleTextIsQuotedVerbatimRatherThanLowercased() {
        // Every other label is normalised; text is the one thing copied onto
        // the page, so its case and spacing must survive.
        let packet = VisualFactPacket(facts: [
            fact(.visibleText, "OPEN Late", 0.8, .appleVisionText)
        ])

        XCTAssertEqual(packet.visibleText.first?.label, "OPEN Late")
        XCTAssertTrue(packet.groundingLines.joined().contains("\"OPEN Late\""))
    }

    // MARK: - Saying what was not seen

    func testThinPacketIsFlaggedSoTheWriterWritesSmall() {
        let thin = VisualFactPacket(facts: [
            fact(.setting, "indoors", 0.2, .appleVisionClassifier)
        ])
        XCTAssertTrue(thin.isThin)

        let solid = VisualFactPacket(facts: [
            fact(.animal, "cat", 0.8, .appleVisionAnimal),
            fact(.setting, "indoors", 0.5, .appleVisionClassifier),
            fact(.light, "low light", 0.9, .imageStatistics),
            fact(.colour, "warm", 0.9, .imageStatistics)
        ])
        XCTAssertFalse(solid.isThin)
    }

    func testPromptGroundingStatesWhatCouldNotBeTold() {
        let packet = VisualFactPacket(
            facts: [fact(.setting, "indoors", 0.3, .appleVisionClassifier)],
            uncertainty: ["no clear subject — do not name one"],
            orientation: .portrait
        )

        let grounding = packet.promptGrounding
        XCTAssertTrue(grounding.contains("WHAT THE EYE COULD NOT TELL"))
        XCTAssertTrue(grounding.contains("no clear subject"))
        XCTAssertTrue(grounding.contains("portrait"))
    }

    func testEmptyPacketSaysNothingLegibleRatherThanNothingAtAll() {
        // Silence in the grounding block reads to a model as "fill this in".
        let grounding = VisualFactPacket().promptGrounding
        XCTAssertTrue(grounding.contains("nothing legible"))
    }

    // MARK: - Combining passes

    func testDuplicateSightingsCollapseToTheStrongest() {
        let packet = VisualFactPacket(facts: [
            fact(.animal, "cat", 0.4, .appleVisionAnimal),
            fact(.animal, "Cat", 0.8, .appleVisionAnimal)
        ])

        XCTAssertEqual(packet.animals.count, 1)
        XCTAssertEqual(packet.animals.first?.confidence, 0.8)
    }

    func testDisagreementBetweenBackendsIsKeptRatherThanResolved() {
        // Two eyes reading the same photo differently is information. The later
        // pass must not silently overwrite the earlier one.
        let vision = VisualFactPacket(
            facts: [fact(.animal, "cat", 0.7, .appleVisionAnimal)],
            backends: ["apple-vision-ensemble-v1"]
        )
        let model = VisualFactPacket(
            facts: [fact(.animal, "rabbit", 0.5, .localVisionModel)],
            backends: ["gemma-4-e2b"]
        )

        let merged = vision.merging(model)
        XCTAssertEqual(merged.animals.count, 2)
        XCTAssertEqual(merged.primarySubject?.label, "cat")
        XCTAssertEqual(merged.backends, ["apple-vision-ensemble-v1", "gemma-4-e2b"])
    }

    func testMergingCarriesBothUncertaintyListsWithoutRepeating() {
        let first = VisualFactPacket(uncertainty: ["the setting is unclear"])
        let second = VisualFactPacket(uncertainty: ["the setting is unclear", "nothing stood out"])

        XCTAssertEqual(
            first.merging(second).uncertainty,
            ["nothing stood out", "the setting is unclear"]
        )
    }

    // MARK: - Regions

    func testPlacementReadsAsWordsNotCoordinates() {
        XCTAssertEqual(VisualRegion(x: 0.4, y: 0.4, width: 0.2, height: 0.2).placement, "centre frame")
        XCTAssertEqual(VisualRegion(x: 0.0, y: 0.7, width: 0.2, height: 0.2).placement, "upper left")
        XCTAssertEqual(VisualRegion(x: 0.8, y: 0.0, width: 0.2, height: 0.2).placement, "lower right")
    }

    func testConfidenceIsClampedSoAStrayScoreCannotOutrankEverything() {
        let wild = VisualFact(kind: .object, label: "kettle", confidence: 9.5, source: .appleVisionClassifier)
        XCTAssertEqual(wild.confidence, 1.0)
    }
}
