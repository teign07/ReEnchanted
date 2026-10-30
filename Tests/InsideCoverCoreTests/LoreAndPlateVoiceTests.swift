import XCTest
@testable import InsideCoverCore

/// Lore and the Cast plates are the Book telling you about its own insides, so
/// they get childlike honesty: say plainly what a thing is and what it does,
/// believe it, and skip the essayist's turns. These read the JSON the app
/// ships, because SwiftPM only ever sees the small fallback shelf.
final class LoreAndPlateVoiceTests: XCTestCase {
    private func library() throws -> BookReferenceLibraryPayload {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(
            BookReferenceLibraryPayload.self,
            from: Data(contentsOf: root.appendingPathComponent("Shared/BookReferenceLibrary.json"))
        )
    }

    private func everyLoreEntry() throws -> [ReferenceSnippet] {
        try library().enchantifyLore + BookReferenceCatalog.fallbackEnchantifyLore
    }

    // MARK: Lore

    /// A lore leaf asks nothing of you. Its headline used to be a slogan
    /// ("Let a place become a room."), and an opening imperative makes the
    /// Curator count the page as an ask, so 42 of 90 lore pages were quietly
    /// spending the desk's ask allowance.
    func testNoLorePageSpendsTheAskBudget() throws {
        for snippet in try everyLoreEntry() {
            let surface = SurfacePage(
                id: snippet.id, type: .lore, sourceID: snippet.sourceID, intent: .importReference,
                renderStyle: .loreLetter, score: 60, reason: "", prompt: snippet.prompt, detail: snippet.title,
                payload: BookPagePayload(headline: snippet.title, body: snippet.body, metadata: ["snippetID": snippet.id])
            )
            XCTAssertFalse(surface.spendsCuratorAskBudget, "\(snippet.id) reads as an ask: \(snippet.prompt)")
        }
    }

    func testLoreSaysItPlainly() throws {
        let banned = [
            "teeth", " like a ", " as if ", "the way a ", "seems to", ", not ", "—", ", which",
            "tasseography", "animism", "sympathetic magic", "chaperone", "co-conspirator", "glamour",
            "liminal", "room-feeling", "lore card", "hinge", "ritual", "journey"
        ]
        let uncontracted = [
            "you are ", "you have ", "i am ", "i will ", "it is ", "does not ", "do not ",
            "is not ", "are not ", "i have ", "that is ", "there is "
        ]
        for snippet in try everyLoreEntry() {
            for line in [snippet.prompt, snippet.body, snippet.practice ?? ""] {
                let lowered = " " + line.lowercased() + " "
                for phrase in banned + uncontracted where lowered.contains(phrase) {
                    XCTFail("\(snippet.id): “\(phrase.trimmingCharacters(in: .whitespaces))” in \(line)")
                }
            }
        }
    }

    /// "Door" was the house metaphor: walls admitting they had a door,
    /// hospitality is a door, give today its own door. Only real doors stay.
    func testDoorsInLoreAreRealDoors() throws {
        let realDoors: Set<String> = ["real-lore-iron", "real-lore-household-wards", "labyrinth-lore-schedule"]
        for snippet in try everyLoreEntry() where !realDoors.contains(snippet.id) {
            let text = [snippet.prompt, snippet.body, snippet.practice ?? ""].joined(separator: " ").lowercased()
            XCTAssertFalse(text.contains("door"), "\(snippet.id) uses door as a figure of speech")
        }
    }

    func testEveryShippedLoreEntryHasSomethingToTry() throws {
        for snippet in try library().enchantifyLore {
            XCTAssertFalse((snippet.practice ?? "").isEmpty, "\(snippet.id) has no practice line")
        }
    }

    /// The confusing ones were the pages explaining my own workings in
    /// invented nouns. Each now says what actually happens.
    func testTheSystemPagesSayWhatActuallyHappens() throws {
        let lore = try library().enchantifyLore
        func body(_ id: String) throws -> String {
            try XCTUnwrap(lore.first { $0.id == id }?.body.lowercased(), id)
        }
        let anchors = try body("labyrinth-system-anchor-rooms")
        for fact in ["name", "room", "fae", "rule", "come back", "belief"] {
            XCTAssertTrue(anchors.contains(fact), "Anchor Rooms should say: \(fact)")
        }
        XCTAssertTrue(try body("labyrinth-system-belief").contains("glow"))
        XCTAssertTrue(try body("labyrinth-system-enchantments").contains("photo"))
        XCTAssertTrue(try body("labyrinth-system-the-nothing").contains("nobody's fault"))
    }

    // MARK: Cast plates

    /// Every plate a reader can actually meet has a hand-written page.
    func testEveryPlateWithArtHasAHandWrittenPage() throws {
        let bundled = BookReferenceCatalog.bundledCharacterIllustrationAssetNames
        for profile in try library().characterIllustrations {
            let asset = profile.assetName?.isEmpty == false
                ? (profile.assetName ?? profile.intendedAssetName)
                : profile.intendedAssetName
            guard bundled.contains(asset) else { continue }
            XCTAssertNotNil(CastDossier.bio(forSlug: profile.slug), "\(profile.characterName) has art but no page")
        }
    }

    func testATalismanIsNeverWrittenUpAsAPerson() {
        let talisman = probe(tags: ["talisman", "object"], core: "A clasp of living moss and old silver")
        XCTAssertEqual(talisman.illustrationTag, "talisman")
        let text = [
            LabyrinthIllustrationPageSourceAdapter.bookPageBody(for: talisman),
            LabyrinthIllustrationPageSourceAdapter.bookDetail(for: talisman)
        ].joined(separator: " ").lowercased()
        for phrase in ["person", "reputation", "character", "they bring", "them"] {
            XCTAssertFalse(text.contains(phrase), "a talisman got written up as somebody: \(phrase)")
        }
    }

    /// The generator used to paste the canon note straight onto the page
    /// ("Mossbloom. Kind-hearted, self-sacrificing.") plus a list of paint
    /// colours. Art direction and production notes never reach a reader.
    func testAGeneratedPageNeverLeaksArtDirection() {
        let profile = probe(
            tags: ["character"],
            core: "Mossbloom; kind-hearted, self-sacrificing; healing herbs; clear expressive eyes and a memorable silhouette; 50 Belief invested by somebody: Bond tier",
            chapter: "Mossbloom"
        )
        let body = LabyrinthIllustrationPageSourceAdapter.bookPageBody(for: profile)
        for leak in ["silhouette", "eyes", "Belief invested", "Bond tier", "moss green", "Mossbloom. ", "settles into"] {
            XCTAssertFalse(body.contains(leak), "generated page leaked: \(leak)\n\(body)")
        }
        XCTAssertTrue(body.contains("healing herbs"))
        XCTAssertTrue(body.contains("a moss-edged notebook"))
    }

    func testNoHandWrittenPageReadsOutItsPalette() throws {
        let bios = CastDossier.bios.values.map { $0.lowercased() }
        for profile in try library().characterIllustrations {
            let colours = profile.palette.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            guard colours.count >= 2 else { continue }
            let run = "\(colours[0]), \(colours[1])"
            XCTAssertFalse(bios.contains { $0.contains(run) }, "a page reads out the palette “\(run)”")
        }
    }

    func testHandWrittenPagesSkipTheEssayistTurns() {
        let banned = [" like a ", "the way a ", "the way kids", "seems to", "seem to", "teeth", "verdict",
                      "diagnos", "protocol", "controlled trial", "low shame", "irony", "heretical"]
        // The Guest's page is written by the November pack and still moving.
        for (slug, prose) in CastDossier.bios where slug != GuestCast.entityID {
            let lowered = " " + prose.lowercased() + " "
            for phrase in banned where lowered.contains(phrase) {
                XCTFail("\(slug): “\(phrase.trimmingCharacters(in: .whitespaces))”")
            }
        }
    }

    private func probe(tags: [String], core: String, chapter: String? = nil) -> CharacterIllustrationProfile {
        CharacterIllustrationProfile(
            id: "probe", characterName: "Probe", slug: "probe-\(tags.joined())", status: "canonical",
            chapter: chapter, core: core, signature: "a moss-edged notebook or pressed leaf",
            palette: "moss green, bark brown", silhouette: "upright", continuity: "", avoid: "",
            assetName: nil, intendedAssetName: "", prompt: "p", negativePrompt: "", marginalia: [], tags: tags
        )
    }
}
