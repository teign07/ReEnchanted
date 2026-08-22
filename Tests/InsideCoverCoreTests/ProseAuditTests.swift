import XCTest
@testable import InsideCoverCore

/// An editorial harness, not a contract test.
///
/// The rising-Pages format prints a leaf's title, headline, deck, body, and
/// provenance in one column, which is what exposed how often those lines say
/// the same thing and how often they say it in documentation voice. This walks
/// every registered source adapter, collects the words a reader would actually
/// meet, and ranks the sources by how much of it the Book would be embarrassed
/// to have read aloud.
///
/// `REENCHANTED_PROSE_AUDIT=1` prints the whole corpus and the report.
/// `=report` prints the findings only.
final class ProseAuditTests: XCTestCase {
    private struct Card {
        var sourceID: String
        var type: String
        var page: SurfacePage
    }

    func testProseCorpusAudit() {
        let mode = ProcessInfo.processInfo.environment["REENCHANTED_PROSE_AUDIT"] ?? ""
        guard !mode.isEmpty else { return }

        var cards: [Card] = []
        var seen: Set<String> = []
        let base = Date(timeIntervalSince1970: 1_755_000_000)
        for dayOffset in 0..<3 {
            for hour in [7, 13, 21] {
                let now = base.addingTimeInterval(Double(dayOffset) * 86_400 + Double(hour) * 3_600)
                let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
                let context = CuratorContext.make(for: day)
                let inputs = BookSourceInputs()
                for adapter in BookPageSourceAdapters.active {
                    let produced = adapter.candidates(for: day, context: context, inputs: inputs, now: now)
                        + [adapter.manualSurface(for: day, context: context, inputs: inputs, now: now)]
                    for page in produced {
                        let key = "\(page.type.rawValue)|\(page.prompt)|\(page.detail)|\(page.payload.body)"
                        guard seen.insert(key).inserted else { continue }
                        cards.append(Card(sourceID: page.sourceID, type: page.type.rawValue, page: page))
                    }
                }
            }
        }

        if mode != "report" {
            for card in cards.sorted(by: { $0.type < $1.type }) {
                print("AUDIT|CARD|type=\(card.type)|source=\(card.sourceID)")
                print("  prompt:   \(oneLine(card.page.prompt))")
                print("  headline: \(oneLine(card.page.payload.headline))")
                print("  detail:   \(oneLine(card.page.detail))")
                print("  body:     \(oneLine(card.page.payload.body))")
                print("  reason:   \(oneLine(card.page.reason))")
            }
        }

        var byRule: [String: [String]] = [:]
        var bySource: [String: Int] = [:]
        for card in cards {
            for finding in BookCharacterLint.prosePatterns(surface: card.page) {
                byRule[finding.rule, default: []].append(
                    "\(card.type)/\(card.sourceID): \(oneLine(finding.excerpt))"
                )
                bySource[card.sourceID, default: 0] += 1
            }
            for finding in BookCharacterLint.inspect(card.page) where finding.severity == .error {
                byRule["ERROR:\(finding.rule)", default: []].append(
                    "\(card.type)/\(card.sourceID): \(oneLine(finding.excerpt))"
                )
                bySource[card.sourceID, default: 0] += 1
            }
        }

        // The same sentence handed to many different sources. One shared line
        // is a house style; a line on a dozen unrelated Pages is a template
        // showing through.
        var sentenceOwners: [String: Set<String>] = [:]
        for card in cards {
            let visible = [card.page.prompt, card.page.detail, card.page.payload.body]
                .joined(separator: " ")
            for sentence in visible
                .replacingOccurrences(of: "\n", with: " ")
                .components(separatedBy: CharacterSet(charactersIn: ".?!"))
                .map({ $0.trimmingCharacters(in: .whitespaces) })
            where sentence.split(separator: " ").count >= 5 {
                sentenceOwners[sentence, default: []].insert(card.sourceID)
            }
        }

        print("\nPROSE AUDIT")
        print("cards=\(cards.count) sources=\(Set(cards.map(\.sourceID)).count)")
        for (rule, hits) in byRule.sorted(by: { $0.value.count > $1.value.count }) {
            print("\n\(rule): \(hits.count)")
            for hit in hits.prefix(12) { print("  · \(hit)") }
        }
        print("\nrepeated across sources:")
        for (sentence, owners) in sentenceOwners.sorted(by: { $0.value.count > $1.value.count }).prefix(12)
        where owners.count >= 3 {
            print("  · \(owners.count) sources · \(sentence)")
        }
        print("\nworst sources:")
        for (source, count) in bySource.sorted(by: { $0.value > $1.value }).prefix(15) {
            print("  · \(count) · \(source)")
        }
        print("END PROSE AUDIT\n")
    }

    // MARK: - The rules themselves

    func testExplainerVoiceIsCaught() {
        let page = card(
            prompt: "The Loom",
            detail: "This shows which cast members are connected and whether each tie is warm or tense.",
            body: "Thirty-six crossings."
        )
        XCTAssertTrue(rules(page).contains("explainer-voice"))
    }

    func testReversalCloserIsCaught() {
        let page = card(
            prompt: "Appoint a Dusk Lamp",
            detail: "Let one lamp mark the moment the day becomes evening.",
            body: "The lamp isn't for brightness. It's the household noticing that the sky changed shifts."
        )
        XCTAssertTrue(rules(page).contains("reversal-closer"))
    }

    func testLabelDumpAndEmptyLabelAreCaught() {
        let page = card(
            prompt: "Compass Run",
            detail: "A full loop, customized to now.",
            body: "Location:\nTime limit:\nEnergy:\nWho is with me:"
        )
        XCTAssertTrue(rules(page).contains("label-dump"))
        XCTAssertTrue(rules(page).contains("empty-label"))
    }

    func testAnEchoTheFolioAlreadyDropsIsNotCharged() {
        let dropped = card(
            prompt: "Give the sky inside you a name.",
            detail: "One tap is plenty.",
            body: "Give the sky inside you a name."
        )
        XCTAssertFalse(rules(dropped).contains("echoed-line"))

        // What the leaf really does show twice: a title the body then says
        // again, a few lines under it.
        let survives = card(
            prompt: "Between Bells",
            detail: "Nothing is in session.",
            body: "The corridor is empty. The Marginalia Guild gathers at seven bells in the Corridor of Whispered Secrets.",
            headline: "The Marginalia Guild gathers at seven bells in the Corridor of Whispered Secrets."
        )
        XCTAssertTrue(rules(survives).contains("echoed-line"))
    }

    func testTheBookMayWriteInItsOwnWeatherWords() {
        let page = card(
            prompt: "The Weather Page is pressed up at the window.",
            detail: "Tap to grab the real forecast and turn it into my own weather-words.",
            body: "Touch it, and I'll ask the actual sky before I write."
        )
        XCTAssertFalse(
            BookCharacterLint.inspect(page).contains { $0.rule == "private-token-in-prose" },
            BookCharacterLint.report([page])
        )

        let slug = card(prompt: "Today", detail: "Filed under weather-clear-mild.", body: "Nothing else.")
        XCTAssertTrue(BookCharacterLint.inspect(slug).contains { $0.rule == "private-token-in-prose" })
    }

    // MARK: - The leaf must not lose the Page's own words

    /// A first-order model of `FolioLeafComposer`'s field rules, kept here
    /// because the folio lives in the app target and the corpus lives in the
    /// package. It caught the Quotes Page printing its theme and its
    /// attribution while dropping the quotation itself: the quote lives in
    /// `prompt`, and the leaf now titles itself from `headline`.
    private struct LeafSketch {
        var title: String
        var deck: String?
        var body: String?

        var printed: String { [title, deck ?? "", body ?? ""].joined(separator: "\n") }
    }

    private func leafSketch(for page: SurfacePage) -> LeafSketch {
        let prompt = page.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = page.payload.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = page.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let keptReadback = page.payload.metadata["keptPageID"]?.nonEmpty != nil
            || page.payload.metadata["keptPage"] == "true"
        let responseOwns = !keptReadback && [
            BookPageType.mood, .diary, .souvenir, .body, .fuel,
            .weather, .location, .aboutYou, .plainPage
        ].contains(page.type)
        let title = page.payload.metadata["folioTitle"]?.nonEmpty
            ?? (responseOwns
                ? (page.payload.metadata["handOpened"] == "true" ? detail : prompt)
                : (headline.isEmpty ? prompt : headline))

        var paragraphs = page.payload.body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let above = [prompt, headline, detail].map(normalizedLine)
        while let first = paragraphs.first, above.contains(normalizedLine(first)) {
            paragraphs.removeFirst()
        }
        let readingBody = paragraphs.joined(separator: "\n\n")
        let showsBody = !responseOwns
            && !readingBody.isEmpty
            && normalizedLine(readingBody) != normalizedLine(prompt)
            && normalizedLine(readingBody) != normalizedLine(detail)
        return LeafSketch(
            title: title,
            deck: showsBody ? nil : detail,
            body: showsBody ? readingBody : nil
        )
    }

    func testNoPageLosesItsOwnWordsOnTheLeaf() {
        let now = Date(timeIntervalSince1970: 1_755_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let inputs = BookSourceInputs()
        var lost: [String] = []

        for adapter in BookPageSourceAdapters.active {
            let produced = adapter.candidates(for: day, context: context, inputs: inputs, now: now)
                + [adapter.manualSurface(for: day, context: context, inputs: inputs, now: now)]
            for page in produced {
                // A Page waiting on the local writer shows a generation leaf
                // instead of its text; that is the one honest omission.
                guard !SurfaceReadinessState(surface: page).needsLocalBrainToOpen else { continue }
                let prompt = page.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard prompt.split(separator: " ").count >= 4 else { continue }
                let sketch = leafSketch(for: page)
                guard !normalizedLine(sketch.printed).contains(normalizedLine(prompt)) else { continue }
                // A card hook may fall away. "The Center Page just opened"
                // announced a tap; on paper the Page is simply open, and the
                // writing under the title is the Page. The loss only matters
                // when the leaf prints no body at all — then `prompt` was the
                // only writing there was, and the Page arrives with nothing to
                // read. Both Quotes and Affirmations lost their line that way.
                guard sketch.body == nil else { continue }
                lost.append("\(page.type.rawValue)/\(page.sourceID): “\(prompt)”")
            }
        }

        XCTAssertTrue(
            lost.isEmpty,
            "the leaf drops the Page's own words:\n" + Set(lost).sorted().joined(separator: "\n")
        )
    }

    private func normalizedLine(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    // MARK: - Writers' packets stay off the Page

    func testNoteAndLetterPagesNeverCarryTheWriterPacketAsTheirOwnWords() throws {
        let now = Date(timeIntervalSince1970: 1_755_000_000)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let context = CuratorContext.make(for: day)
        let inputs = BookSourceInputs()

        let pages = StudentNotePageSourceAdapter()
            .candidates(for: day, context: context, inputs: inputs, now: now)
            + CharacterLetterPageSourceAdapter()
            .candidates(for: day, context: context, inputs: inputs, now: now)
            + FacultyResearchPageSourceAdapter()
            .candidates(for: day, context: context, inputs: inputs, now: now)
        try XCTSkipIf(pages.isEmpty, "no note, letter, or research folio surfaced for this fixture")

        let packetMarkers = [
            "Address the player as:", "Writing voice:", "Draft packet:",
            "Note kind:", "Sender:", "Avoid:", "Do not claim the player",
            "Research focus:", "Body signals:", "No diagnosis", "Use uncertainty"
        ]
        for page in pages {
            for marker in packetMarkers {
                XCTAssertFalse(
                    page.payload.body.contains(marker),
                    "\(page.type.rawValue) prints the writer's packet as its own words: \(marker)"
                )
            }
            XCTAssertFalse(page.payload.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(
                page.generationPromptPacket.contains("Address the player as:")
                    || page.generationPromptPacket.contains("Research focus:"),
                "the packet should still reach the writer"
            )
        }
    }

    // MARK: - The quip shelf

    func testQuipShelfIsNotOneJokeToldOverAndOver() {
        let shelf = QuipPackRegistry.enabledPacks.flatMap(\.quips)
        let census = Dictionary(grouping: shelf, by: \.shape).mapValues(\.count)
        for shape in QuipShape.allCases {
            XCTAssertGreaterThanOrEqual(
                census[shape] ?? 0, 6,
                "the shelf has almost nothing in the \(shape.rawValue) shape: \(census)"
            )
        }
        let equations = Double(census[.equation] ?? 0) / Double(max(1, shelf.count))
        XCTAssertLessThan(equations, 0.75, "the shelf is still mostly equations: \(census)")
    }

    func testADeskOfQuipsCarriesMoreThanOneShape() {
        let base = Date(timeIntervalSince1970: 1_755_000_000)
        for offset in 0..<14 {
            let now = base.addingTimeInterval(Double(offset) * 86_400)
            let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
            let quips = QuipPackRegistry.rankedQuips(for: day, now: now, limit: 4)
            XCTAssertGreaterThanOrEqual(
                Set(quips.map(\.shape)).count, 2,
                "day \(offset) served four of the same move: \(quips.map(\.text))"
            )
        }
    }

    private func rules(_ page: SurfacePage) -> [String] {
        BookCharacterLint.prosePatterns(surface: page).map(\.rule)
    }

    /// `.lore` rather than `.plainPage`: a Page that owns a response box keeps
    /// its prompt as the title and prints neither deck nor body, so the
    /// structural rules would have nothing to look at.
    private func card(
        prompt: String,
        detail: String,
        body: String,
        headline: String = ""
    ) -> SurfacePage {
        SurfacePage(
            id: "prose-audit-fixture",
            type: .lore,
            sourceID: "prose-audit",
            intent: nil,
            renderStyle: .promptCard,
            score: 50,
            reason: "",
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(headline: headline, body: body, metadata: [:])
        )
    }

    private func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ⏎ ")
    }
}
