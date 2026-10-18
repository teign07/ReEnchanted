import XCTest
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
@testable import InsideCoverCore

/// What semantic passage selection costs on a lived-in archive.
///
/// The Student Note adapter asks `MeaningfulPassageSelector` for the best
/// passage in up to eighty kept Pages, every desk build, with a query that
/// carries the time of day — so the query changes through the day while the
/// Pages do not. Sampled on a phone, one such build spent 33 seconds in the
/// sentence model. Gated so a normal `swift test` never pays for it:
///
///   PASSAGE_BENCH=1 swift test --filter PassageEmbeddingBench
final class PassageEmbeddingBench: XCTestCase {
    private func corpus(dayCount: Int = 120) -> [BookPage] {
        let openings = ["The kettle clicked off", "Down at the harbour", "A kestrel held still", "Rain came sideways",
                        "My sister called", "The bakery had cardamom buns", "I couldn't sleep", "Work was loud",
                        "Found a pressed leaf", "The bus was late again", "The cat brought in a moth", "We walked to the lighthouse"]
        let middles = ["and I stood there longer than I needed to", "while the radio argued with itself",
                       "because nobody else was awake yet", "until the streetlights came on",
                       "and the gulls kept score of nothing", "but the window stayed fogged",
                       "and I thought about the old house", "so I wrote it down before it went"]
        let closings = ["It felt like a small door.", "Nothing happened, and that was the point.",
                        "I want to remember the colour.", "Tomorrow I'll try the other street.",
                        "The quiet had a shape.", "I laughed at the wrong moment."]
        var pages: [BookPage] = []
        let start = Date(timeIntervalSinceNow: -Double(dayCount) * 86_400)
        for day in 0..<dayCount {
            for slot in 0..<3 {
                let seed = day * 3 + slot
                let sentences = (0..<(4 + seed % 4)).map { index -> String in
                    let a = openings[(seed + index * 5) % openings.count]
                    let b = middles[(seed * 7 + index) % middles.count]
                    return "\(a) on day \(day), \(b)."
                } + [closings[(seed + day) % closings.count]]
                pages.append(BookPage(
                    id: "bench-passage-\(day)-\(slot)",
                    type: [.diary, .souvenir, .mood][slot],
                    createdAt: start.addingTimeInterval(Double(day) * 86_400 + Double(slot) * 14_400),
                    promptText: "What stayed with you?",
                    userInput: sentences.joined(separator: " "),
                    origin: .userAuthored
                ))
            }
        }
        return pages
    }

    private func time(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    func testSemanticPassageSelectionCost() throws {
        guard ProcessInfo.processInfo.environment["PASSAGE_BENCH"] != nil else {
            throw XCTSkip("Set PASSAGE_BENCH=1 to run the passage embedding bench.")
        }
        guard let scorer = NaturalLanguageStacksEmbeddingScorer() else {
            throw XCTSkip("No sentence embedding on this machine.")
        }
        let pages = corpus()
        let queries = [
            "Wicker leaves a note. Morning, before class. Your lesson on margins. Wicker remembered the lantern at the jetty.",
            "Wicker leaves a note. Late afternoon, after class. Your lesson on margins. Wicker remembered the lantern at the jetty.",
            "Wicker leaves a note. Evening, the lamps are lit. Your lesson on margins. Wicker remembered the lantern at the jetty."
        ]
        var picks: [String] = []
        var lines: [String] = []
        for (index, query) in queries.enumerated() {
            var selection: [MeaningfulPassageSelector.Selection] = []
            let cold = time {
                selection = MeaningfulPassageSelector.rankedSelections(
                    pages: pages, query: query, inputs: .empty, scorer: scorer, limit: 3,
                    maximumAge: 365 * 86_400, minimumScore: 8, honorPriorUse: false
                )
            }
            let warm = time {
                _ = MeaningfulPassageSelector.rankedSelections(
                    pages: pages, query: query, inputs: .empty, scorer: scorer, limit: 3,
                    maximumAge: 365 * 86_400, minimumScore: 8, honorPriorUse: false
                )
            }
            picks.append(selection.map { "\($0.pageID)|\($0.score)|\($0.excerpt)" }.joined(separator: " ; "))
            lines.append(String(format: "query %d: first %.0f ms, repeated %.0f ms", index + 1, cold, warm))
        }
        print("PASSAGE_BENCH \(pages.count) pages\n" + lines.joined(separator: "\n"))
        print("PASSAGE_BENCH picks:\n" + picks.joined(separator: "\n"))
    }

    /// The scorer reproduces the sentence model's own distance from vectors it
    /// embeds once and keeps. If the model ever changes what `distance` means,
    /// this is where it shows.
    func testVectorScoreMatchesTheModelsOwnDistance() throws {
        #if canImport(NaturalLanguage)
        guard let scorer = NaturalLanguageStacksEmbeddingScorer(),
              let model = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw XCTSkip("No sentence embedding on this machine.")
        }
        let texts = [
            "Wicker leaves a note. Late evening. Your class on margins. Wicker remembered the lantern at the jetty.",
            "The kettle clicked off before the frost left the window.",
            "Down at the harbour a lantern kept swinging over the jetty, and nobody came to tend it.",
            "Rain all afternoon; I read by the window and forgot the time until the streetlights came on.",
            "lantern jetty harbour",
            "ok",
            "Ünïcödé café — naïve résumé"
        ]
        for query in texts {
            for document in texts {
                let direct = max(0, min(1, 1 - model.distance(between: query, and: document)))
                let scored = try XCTUnwrap(scorer.similarity(between: query, and: document))
                XCTAssertEqual(scored, direct, accuracy: 1e-5, "\(query) / \(document)")
            }
        }
        #else
        throw XCTSkip("NaturalLanguage is not available.")
        #endif
    }
}
