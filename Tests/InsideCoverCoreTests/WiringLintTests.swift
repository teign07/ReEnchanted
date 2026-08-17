import Foundation
import XCTest

@testable import InsideCoverCore

/// The bug class this project keeps producing, made into a test.
///
/// Over one weekend, nine separate features were found built, believed in, and
/// wired to something that never runs: cross-night returns, the tale lean
/// (twice), a polisher and a repair pass keyed to a tag the writer stopped
/// setting, two model calls a night whose output was discarded, the fallback
/// braider still on a replaced engine, the money boundary the reader is asked
/// about in onboarding, and the Book's own interior life.
///
/// Every one of them passed the whole test suite, because a test asserts that
/// code does what it says - never that anything calls it. These scan the source
/// instead, and fail when a decision is keyed to something no producer emits.
///
/// **When one of these fails**, the fix is almost never to add to the allowlist.
/// It is to wire the thing up, or delete it. The allowlist is for cases where
/// the dead branch is genuinely carried by a live sibling, and each entry says
/// why.
final class WiringLintTests: XCTestCase {
    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func productionSources() throws -> [String: String] {
        let root = repoRoot()
        var out: [String: String] = [:]
        for dir in ["Shared", "InsideCoverApp", "ReEnchantedWidgets", "ReEnchantedShare"] {
            let base = root.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(atPath: base.path) else { continue }
            for case let name as String in walker where name.hasSuffix(".swift") {
                let url = base.appendingPathComponent(name)
                out["\(dir)/\(name)"] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
        }
        XCTAssertGreaterThan(out.count, 40, "the lint found almost no source; the path is wrong")
        return out
    }

    private func matches(_ pattern: String, in text: String, group: Int = 1) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        else { return [] }
        let full = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: full).compactMap { m in
            guard group < m.numberOfRanges else { return nil }
            return Range(m.range(at: group), in: text).map { String(text[$0]) }
        }
    }

    private func count(_ pattern: String, in text: String) -> Int {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return re.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private func removing(_ pattern: String, from text: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    // MARK: - A decision on a tag nothing produces

    /// Tags that are read but never emitted, and are *known* to be harmless.
    ///
    /// Each of these sits inside an `||` chain whose other branches are live, so
    /// the decision still fires - they are dead weight, not dead behaviour.
    private let acceptedDeadTags: Set<String> = [
        // carried by "rut-reopened" and "grey-threat-rescued" in the same chain
        "living-ink-reopened",
        // carried by "play" and "quip" in the same chain
        "game",
        // carried by "walking" and "stairs"; the movement accommodation also
        // works through reach-derived mobility, which is live
        "long-distance",
        // the social-energy accommodation also works through page type
        "requires-company",
        // page.type == .rest carries this branch
        "seated"
    ]

    func testEveryTagDecisionHasSomethingThatProducesIt() throws {
        let prod = try productionSources()

        // Harvest everything that could ever end up in a tag list - but only
        // after deleting the read sites themselves, so a tag is never counted as
        // its own producer. That subtlety is the whole test: `tags.contains("x")`
        // puts the literal "x" in the file, and a naive scan calls it produced.
        let readSite = "\\btags\\s*\\.\\s*contains\\s*\\(\\s*\"[^\"]+\"\\s*\\)"
        var produced = Set<String>()
        var prefixes = Set<String>()
        for text in prod.values {
            for literal in matches("\"((?:[^\"\\\\]|\\\\.)*)\"", in: removing(readSite, from: text)) {
                produced.insert(literal)
                // A metadata tag string is comma-joined and any piece of it may
                // be interpolated, so both the split and the prefix have to be
                // taken per piece: "faculty-research,faculty:\(id)" produces the
                // prefix `faculty:`, not `faculty-research,faculty:`.
                for piece in literal.split(separator: ",") {
                    let part = piece.trimmingCharacters(in: .whitespaces)
                    if part.contains("\\(") {
                        let prefix = part.components(separatedBy: "\\(")[0]
                        if prefix.count >= 3 { prefixes.insert(prefix) }
                    } else {
                        produced.insert(part)
                    }
                }
            }
        }
        let enumCases = Set(prod.values.flatMap { matches("\\bcase\\s+([A-Za-z_][A-Za-z0-9_]*)", in: $0) })

        var offenders: [String: [String]] = [:]
        for (path, text) in prod {
            for tag in matches("\\btags\\s*\\.\\s*contains\\s*\\(\\s*\"([^\"\\\\]+)\"\\s*\\)", in: text) {
                if acceptedDeadTags.contains(tag) { continue }
                if produced.contains(tag) { continue }
                if prefixes.contains(where: { tag.hasPrefix($0) }) { continue }
                let camel = tag.split(whereSeparator: { "-_: ".contains($0) })
                    .enumerated()
                    .map { $0.offset == 0 ? String($0.element) : $0.element.capitalized }
                    .joined()
                if enumCases.contains(camel) || enumCases.contains(tag) { continue }
                offenders[tag, default: []].append(path)
            }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            """
            These tags are read to make a decision, and nothing in production ever \
            produces them, so the decision never fires:
            \(offenders.map { "  \($0.key)  read in \($0.value.joined(separator: ", "))" }
                .sorted().joined(separator: "\n"))
            Wire it up or delete it. Add to `acceptedDeadTags` only if a live \
            sibling in the same condition already carries the decision.
            """
        )
    }

    // MARK: - A page the reader can never be handed

    /// Found unwired, still unwired, and waiting on a product decision.
    ///
    /// **`BookPersonalityActuator.enacting`** is the Book's interior life
    /// touching a Page: the fault it admits and repairs, the reminiscence it has
    /// been holding. Everything around it exists and runs - `interior.currentFault`
    /// is set in ContentView, the widget snapshot reads it, and two places in the
    /// app read `bookFaultID`/`bookReminiscenceID` off a surface to mark the item
    /// as presented. The actuator that would put those keys on a Page is the only
    /// producer of them, and nothing in production calls it. So the Book's inner
    /// life reaches the widget and never reaches a page, and `presentedAt` can
    /// never be set.
    ///
    /// Not wired here because doing so changes what appears on a reader's desk,
    /// which is bj's call rather than an audit's. Its own doc comment names the
    /// intended integration: applied after desk ranking, changing the Page the
    /// Book was already going to hand over rather than taking a second slot.
    private let unwiredAwaitingDecision: Set<String> = ["enacting"]

    /// Producers deliberately left uncalled, with the reason.
    private let acceptedUncalledProducers: Set<String> = [
        // A convenience wrapper. `livedEncounterContract` falls back to
        // `.inferred(for:)`, so the contract is applied either way.
        "withLivedEncounterContract",
        // A decorating helper. ContentView calls `enchantWeather` and applies
        // the signal itself, so enchanted weather does reach the reader.
        "enchantedWeatherCopy"
    ]

    func testEveryPageProducerIsCalledBySomething() throws {
        let prod = try productionSources()
        let all = prod.values.joined(separator: "\n")

        var producers: [String: [String]] = [:]
        for (path, text) in prod {
            for name in matches(
                "\\bfunc\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\([^)]*\\)[^{\\n]*->\\s*\\[?\\s*(?:SurfacePage|BookPage)\\s*\\]?\\??",
                in: text
            ) {
                producers[name, default: []].append(path)
            }
        }
        XCTAssertGreaterThan(producers.count, 100, "the producer scan found too little")

        var offenders: [String: [String]] = [:]
        for (name, paths) in producers {
            if acceptedUncalledProducers.contains(name) { continue }
            if unwiredAwaitingDecision.contains(name) { continue }
            let declarations = count("\\bfunc\\s+\(name)\\s*\\(", in: all)
            let mentions = count("(?<![A-Za-z0-9_])\(name)\\s*\\(", in: all)
            if mentions <= declarations { offenders[name] = paths.sorted() }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            """
            These build a Page for the reader and nothing in production calls them, \
            so whatever they make can never be handed to anybody:
            \(offenders.map { "  \($0.key)  declared in \($0.value.joined(separator: ", "))" }
                .sorted().joined(separator: "\n"))
            """
        )
    }
}
