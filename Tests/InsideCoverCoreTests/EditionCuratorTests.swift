import XCTest
@testable import InsideCoverCore

final class EditionCuratorTests: XCTestCase {

    private func page(
        _ type: BookPageType,
        id: String,
        input: String = "",
        used: Bool = false,
        origin: BookPageOrigin = .generated
    ) -> BookPage {
        BookPage(
            id: id,
            type: type,
            createdAt: Date(),
            promptText: "Prompt",
            userInput: input,
            usedInBookOfYou: used,
            origin: origin
        )
    }

    /// The motivating bug: a short month produced a fifty-page book because
    /// every mundane daily log was bound. The curator should sip only a couple
    /// of each and set the rest aside.
    func testMundaneLogsAreSampledNotBoundWholesale() {
        var pages: [BookPage] = []
        for index in 0..<12 {
            pages.append(page(.weather, id: "weather-\(index)", input: "Inner weather note \(index), a little more text to carry substance."))
        }
        let curated = EditionCurator.curate(pages)
        let boundWeather = curated.pages.filter { $0.type == .weather }
        XCTAssertLessThanOrEqual(boundWeather.count, EditionCurator.mundaneSamplePerType)
        XCTAssertEqual(curated.setAside[.weather], 12 - boundWeather.count)
        XCTAssertNotNil(curated.setAsideLine)
    }

    /// Expressive, reader-authored pages are the book's spine and are always kept.
    func testCenterpiecePagesAreAlwaysKept() {
        let pages = [
            page(.bookOfYou, id: "braid", input: "The night braided itself into something I could keep."),
            page(.souvenir, id: "souvenir", input: "The harbor kept its minutes."),
            page(.letter, id: "letter", input: "Dear reader, a voice spoke back.", origin: .userAuthored)
        ]
        let curated = EditionCurator.curate(pages)
        XCTAssertEqual(curated.keptCount, 3)
        XCTAssertEqual(curated.setAsideTotal, 0)
    }

    /// A page that earned its way into a nightly braid outscores a notable page
    /// that carries no substance at all.
    func testUsedInBookOfYouBoostsScore() {
        let used = page(.fuel, id: "fuel-used", input: "Tea.", used: true)
        let empty = page(.gossip, id: "gossip-empty")
        XCTAssertGreaterThan(EditionCurator.bindingScore(used), EditionCurator.bindingScore(empty))
        // The empty notable page should not be bound.
        let curated = EditionCurator.curate([empty])
        XCTAssertTrue(curated.pages.isEmpty)
        XCTAssertEqual(curated.setAside[.gossip], 1)
    }

    /// The same text bound twice collapses to one.
    func testExactDuplicatesCollapse() {
        let pages = [
            page(.souvenir, id: "a", input: "Identical fragment."),
            page(.souvenir, id: "b", input: "Identical fragment.")
        ]
        let curated = EditionCurator.curate(pages)
        XCTAssertEqual(curated.pages.count, 1)
        XCTAssertEqual(curated.setAside[.souvenir], 1)
    }

    func testRepeatedBookPromptKeepsEachDistinctReaderSentence() {
        let first = BookPage(id: "first", type: .narrativeOS, promptText: "Look again",
                             userInput: "The Book held out a page.", playerReply: "A moth on the sill.", origin: .generated)
        let second = BookPage(id: "return", type: .narrativeOS, promptText: "Look again",
                              userInput: "The Book held out a page.", playerReply: "Only dust remained.", origin: .generated)
        let replyOnly = BookPage(id: "reply-only", type: .narrativeOS, promptText: "Look again",
                                 userInput: "", playerReply: "Rain on the pane.", origin: .generated)
        XCTAssertEqual(EditionCurator.curate([first, second, replyOnly]).pages.map(\.id),
                       ["first", "return", "reply-only"])
    }

    func testDistinctAuthoredScenesSurviveRepeatedBookFrame() {
        var first = page(.narrativeOS, id: "scene-a", input: "The school bell rang.")
        var second = page(.narrativeOS, id: "scene-b", input: "The school bell rang.")
        first.tags.append("authored-story-scene")
        second.tags.append("authored-story-scene")
        XCTAssertEqual(EditionCurator.curate([first, second]).pages.map(\.id), ["scene-a", "scene-b"])
    }

    func testAudioOnlyPlainPageIsBoundAsContent() {
        let voice = BookPage(
            id: "voice",
            type: .plainPage,
            createdAt: Date(),
            promptText: "Voice Note",
            userInput: "",
            tags: ["voice-note"],
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .audioFile,
                    reference: "/private/voice.m4a",
                    metadata: ["durationSeconds": "14", "voiceCadence": "measured"]
                )
            ]
        )

        let curated = EditionCurator.curate([voice])

        XCTAssertEqual(curated.pages.map(\.id), ["voice"])
        XCTAssertEqual(voice.bindingDisplayTitle, "Voice Note")
        XCTAssertTrue(voice.bindingBodyText.contains("14 seconds"))
    }
}
