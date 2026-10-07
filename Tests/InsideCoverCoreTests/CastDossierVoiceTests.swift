import XCTest
@testable import InsideCoverCore

/// The Cast Pages are the Book's own sentences about people it's fond of, so
/// they get the Book's voice: contracted, plain, no balanced clauses and no
/// appositive asides. Content (faults, objects, palettes) is the canon; this
/// guards the sentences, not the facts.
final class CastDossierVoiceTests: XCTestCase {
    func testEveryBespokeDossierIsContractedAndPlain() {
        let uncontracted = [
            "does not ", "do not ", "is not ", "are not ", "was not ", "has not ", "have not ",
            "it is ", "he is ", "she is ", "i am ", "i will ", "that is ", "there is ", "i have ", "they are "
        ]
        let banned = [", which ", " (", "—", "rather than", "not so much", "hinge", "ritual", "journey"]
        for (slug, prose) in CastDossier.bios {
            let lowered = " " + prose.lowercased() + " "
            for phrase in uncontracted where lowered.contains(phrase) {
                XCTFail("\(slug): uncontracted “\(phrase.trimmingCharacters(in: .whitespaces))”")
            }
            for phrase in banned where lowered.contains(phrase) {
                XCTFail("\(slug): “\(phrase.trimmingCharacters(in: .whitespaces))” is an old-voice shape")
            }
        }
    }

    func testGeneratedCastCopyIsContractedToo() {
        let profile = CharacterIllustrationProfile(
            id: "voice-probe", characterName: "Probe", slug: "voice-probe", status: "canonical",
            chapter: nil, core: "Precise in her care; sharp kind eyes",
            signature: "a silver bookmark-caliper and red marginal notes", palette: "warm parchment",
            silhouette: "upright", continuity: "", avoid: "", assetName: nil, intendedAssetName: "",
            prompt: "p", negativePrompt: "", marginalia: [], tags: ["character"]
        )
        for tag in ["location", "book-fae", "character"] {
            var probe = profile
            probe.tags = [tag]
            let text = [
                LabyrinthIllustrationPageSourceAdapter.bookPageBody(for: probe),
                LabyrinthIllustrationPageSourceAdapter.bookDetail(for: probe),
                LabyrinthIllustrationPageSourceAdapter.bookPageTitle(for: probe)
            ].joined(separator: "\n").lowercased()
            for phrase in [" is not ", " does not ", " it is ", " will start", " that is "] {
                XCTAssertFalse(text.contains(phrase), "\(tag): \(phrase)")
            }
        }
    }
}
