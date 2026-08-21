import XCTest
@testable import InsideCoverCore

/// An editorial harness, not a contract test. It walks every registered source
/// adapter, collects the words a reader would actually see on a card, and
/// prints them so a human can read the Book's whole vocabulary in one sitting.
/// The rising-Pages format shows prompt, detail, and body at once, which is
/// what exposed how often those three say the same thing twice.
///
/// `REENCHANTED_PROSE_AUDIT=1` prints the corpus. `=repeats` prints only the
/// repetition report.
final class ProseAuditTests: XCTestCase {
    private struct Card {
        var sourceID: String
        var type: String
        var prompt: String
        var detail: String
        var headline: String
        var body: String
        var reason: String
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
                        cards.append(Card(
                            sourceID: page.sourceID,
                            type: page.type.rawValue,
                            prompt: page.prompt,
                            detail: page.detail,
                            headline: page.payload.headline,
                            body: page.payload.body,
                            reason: page.reason
                        ))
                    }
                }
            }
        }

        if mode != "repeats" {
            for card in cards.sorted(by: { $0.type < $1.type }) {
                print("AUDIT|CARD|type=\(card.type)|source=\(card.sourceID)")
                print("  reason:   \(oneLine(card.reason))")
                print("  prompt:   \(oneLine(card.prompt))")
                print("  detail:   \(oneLine(card.detail))")
                print("  headline: \(oneLine(card.headline))")
                print("  body:     \(oneLine(card.body))")
            }
        }

        // 1. The same words twice on one card.
        for card in cards {
            let detail = normalized(card.detail)
            let body = normalized(card.body)
            guard !detail.isEmpty, !body.isEmpty else { continue }
            if body == detail {
                print("AUDIT|ECHO-EXACT|\(card.type)|\(card.sourceID)|\(oneLine(card.detail))")
            } else if body.contains(detail), detail.count > 24 {
                print("AUDIT|ECHO-SWALLOWED|\(card.type)|\(card.sourceID)|\(oneLine(card.detail))")
            }
            if normalized(card.prompt) == body, !body.isEmpty {
                print("AUDIT|ECHO-PROMPT|\(card.type)|\(card.sourceID)|\(oneLine(card.prompt))")
            }
        }

        // 2. The same sentence on many different cards.
        var sentenceOwners: [String: Set<String>] = [:]
        for card in cards {
            for sentence in sentences(of: [card.prompt, card.detail, card.body].joined(separator: " ")) {
                sentenceOwners[sentence, default: []].insert("\(card.type):\(card.sourceID)")
            }
        }
        for (sentence, owners) in sentenceOwners.sorted(by: { $0.value.count > $1.value.count })
        where owners.count >= 3 {
            print("AUDIT|REPEATED|cards=\(owners.count)|\(sentence)")
        }

        print("AUDIT|TOTAL|cards=\(cards.count)")
    }

    private func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ⏎ ")
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sentences(of text: String) -> [String] {
        text.replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.split(separator: " ").count >= 4 }
    }
}
