import XCTest
@testable import InsideCoverCore

/// The filing system. Perception has been finding animals for months and
/// throwing them away; these are the rules for what gets kept and what doesn't,
/// because a shelf that files a catfish under cats is worse than no shelf.
final class BestiaryFilingTests: XCTestCase {

    private func fact(
        _ label: String,
        _ confidence: Double,
        kind: VisualFactKind = .setting,
        source: VisualFactSource = .appleVisionClassifier
    ) -> VisualFact {
        VisualFact(kind: kind, label: label, confidence: confidence, source: source)
    }

    // MARK: What counts as alive

    func testTheDedicatedRecognizersAnimalsAreFiled() {
        let packet = VisualFactPacket(facts: [
            fact("Cat", 0.94, kind: .animal, source: .appleVisionAnimal)
        ])
        XCTAssertEqual(
            Bestiary.sightings(in: packet),
            [CreatureSighting(creature: "cat", certainty: .clear)]
        )
    }

    /// The classifier's taxonomy is full of animals the dedicated pass can't
    /// see. It only knows cats and dogs; the whole rest of the bestiary comes
    /// from labels that arrive as plain scene tags.
    func testAClassifierLabelCanNameACreature() {
        let packet = VisualFactPacket(facts: [fact("crow", 0.8)])
        XCTAssertEqual(Bestiary.sightings(in: packet).first?.creature, "crow")
    }

    func testThingsThatAreNotAliveAreNotFiled() {
        let packet = VisualFactPacket(facts: [
            fact("bicycle", 0.9), fact("kitchen", 0.9), fact("sunset", 0.9)
        ])
        XCTAssertTrue(Bestiary.sightings(in: packet).isEmpty)
    }

    /// The reason the match is on the whole label and never a substring. A
    /// reader who finds a catfish filed under cats stops trusting the shelf,
    /// and they'd be right to.
    func testACatfishIsNotACat() {
        XCTAssertNil(Bestiary.creature(for: "catfish"))
        XCTAssertNil(Bestiary.creature(for: "dogwood"))
        XCTAssertNil(Bestiary.creature(for: "hot dog"))
        XCTAssertNil(Bestiary.creature(for: "catkin"))
    }

    // MARK: How sure the Book has to be

    /// Perception hands up labels from 0.16 because a weak label is still
    /// useful context for a caption. It is not enough to put an animal on a
    /// shelf and say it was there.
    func testAMaybeIsNotFiled() {
        let packet = VisualFactPacket(facts: [fact("owl", 0.2)])
        XCTAssertTrue(Bestiary.sightings(in: packet).isEmpty)
        XCTAssertEqual(VisualCertainty(confidence: 0.2), .possible)
    }

    func testAProbablyIsFiled() {
        let packet = VisualFactPacket(facts: [fact("owl", 0.5)])
        XCTAssertEqual(
            Bestiary.sightings(in: packet),
            [CreatureSighting(creature: "owl", certainty: .likely)]
        )
    }

    // MARK: One animal, several passes

    /// The dedicated recognizer and the classifier both see the one cat. Two
    /// passes agreeing is agreement, not a second animal.
    func testTwoPassesNamingTheSameAnimalFileItOnce() {
        let packet = VisualFactPacket(facts: [
            fact("cat", 0.4),
            fact("Cat", 0.95, kind: .animal, source: .appleVisionAnimal)
        ])
        XCTAssertEqual(Bestiary.sightings(in: packet).count, 1)
        XCTAssertEqual(Bestiary.sightings(in: packet).first?.certainty, .clear)
    }

    /// A puppy really is a dog, and the Book can defend that merge out loud.
    func testTheFewDefensibleMergesHappen() {
        XCTAssertEqual(Bestiary.creature(for: "puppy"), "dog")
        XCTAssertEqual(Bestiary.creature(for: "kitten"), "cat")
        XCTAssertEqual(Bestiary.creature(for: "lamb"), "sheep")
    }

    /// Nothing collapses a specific creature into a general one. "Bird" is a
    /// duller thing to have seen than a songbird, and the shelf is for the
    /// interesting version.
    func testSpecificCreaturesAreNotFlattenedIntoGeneralOnes() {
        XCTAssertEqual(Bestiary.creature(for: "songbird"), "songbird")
        XCTAssertEqual(Bestiary.creature(for: "kingfisher"), "kingfisher")
        XCTAssertEqual(Bestiary.creature(for: "tortoise"), "tortoise")
    }

    func testTheOrderIsStable() {
        let packet = VisualFactPacket(facts: [
            fact("heron", 0.5), fact("fox", 0.9), fact("bee", 0.5)
        ])
        XCTAssertEqual(
            Bestiary.sightings(in: packet).map(\.creature),
            ["fox", "bee", "heron"],
            "surest first, then alphabetical, so the same photo files the same way twice"
        )
    }

    func testAnEmptyPacketFilesNothingRatherThanFailing() {
        XCTAssertTrue(Bestiary.sightings(in: VisualFactPacket()).isEmpty)
    }

    // MARK: Carrying it onto the page

    func testSightingsSurviveTheTripThroughPageMetadata() {
        let sightings = [
            CreatureSighting(creature: "fox", certainty: .clear),
            CreatureSighting(creature: "heron", certainty: .likely)
        ]
        XCTAssertEqual(Bestiary.decoded(Bestiary.encoded(sightings)), sightings)
    }

    func testAnEmptyMetadataStringDecodesToNothing() {
        XCTAssertTrue(Bestiary.decoded("").isEmpty)
    }

    func testAMetadataStringMissingItsCertaintyStillNamesTheCreature() {
        XCTAssertEqual(Bestiary.decoded("fox").first?.creature, "fox")
    }
}

/// The archive side. `PhotoAnalysis` is decoded straight out of a language
/// model's JSON, so both the absence of the field and a model's opinions about
/// it have to be handled before anything reaches a shelf.
final class CreatureRecordTests: XCTestCase {

    private var analysis: PhotoAnalysis { .academyFallback }

    /// Nobody looking is a different fact from looking and finding nothing. A
    /// shelf that can't tell them apart would eventually tell the reader they
    /// have photographed no animals on the strength of pages from before the
    /// detector ran at all.
    func testNothingLookedIsNotTheSameAsNothingSeen() {
        XCTAssertNil(analysis.creatures, "an unexamined photo claims nothing")
        var looked = analysis
        looked.creatures = []
        XCTAssertEqual(looked.creatures, [])
    }

    /// The whole reason `creatures` is optional rather than defaulted-empty: a
    /// non-optional property with a default still throws on a missing key, and
    /// Gemma's JSON will never mention this field.
    func testAnAnalysisWithoutCreaturesStillDecodes() throws {
        // The template id comes from the type rather than a literal: this test
        // is about a missing key, and a stale raw value would fail it for the
        // wrong reason.
        let template = PhotoAnalysis.academyFallback.suggestedTemplate.rawValue
        let json = """
        {"scene":"A quiet yard.","motifs":["yard"],"mood":"quiet",
         "suggestedTemplate":"\(template)",
         "marginalia":{"fieldNote":"n","stampLabel":"s",
                       "observationList":["a"],"closingLine":"c"},
         "souvenirCandidates":["one"]}
        """
        let decoded = try JSONDecoder().decode(PhotoAnalysis.self, from: Data(json.utf8))
        XCTAssertNil(decoded.creatures)
    }

    /// A model that decides to mention a wolf must not be able to put one in
    /// the archive. The bestiary is a record of what a detector saw.
    func testTheValidatorRefusesACreatureTheFilingSystemDoesNotKnow() {
        var invented = analysis
        invented.creatures = [
            CreatureSighting(creature: "fox", certainty: .clear),
            CreatureSighting(creature: "the watcher in the hedge", certainty: .clear)
        ]
        let validated = PhotoAnalysisValidator.validate(invented, fallback: .academyFallback)
        XCTAssertEqual(validated.creatures?.map(\.creature), ["fox"])
    }

    func testTheValidatorKeepsNothingLookedAsNothingLooked() {
        let validated = PhotoAnalysisValidator.validate(analysis, fallback: .academyFallback)
        XCTAssertNil(validated.creatures)
    }

    func testSightingsReachThePageAndComeBack() {
        var read = analysis
        read.creatures = [CreatureSighting(creature: "crow", certainty: .likely)]
        let metadata = [Bestiary.metadataKey: Bestiary.encoded(read.creatures ?? [])]
        let recovered = PhotoAnalysis.fromSurfaceMetadata(metadata, fallback: .academyFallback)
        XCTAssertEqual(recovered.creatures, read.creatures)
    }
}
