import XCTest
@testable import InsideCoverCore

/// Offline proof harness: replays bj's real Mac-side archive (Labyrinth
/// diary, Dr. Inkrest mood log, session notes) through the continuity,
/// constellation, wager, and theme engines, day by day, and prints what the
/// Book would actually have noticed, named, and wagered.
///
/// Gated behind REAL_ARCHIVE_DIR so CI and normal `swift test` skip it:
///
///   REAL_ARCHIVE_DIR=/path/to/local/archive swift test \
///     --filter RealArchiveReplayTests 2>&1
///
/// Everything stays on this machine; the report goes to stdout only.
final class RealArchiveReplayTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    func testReplayRealArchive() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_ARCHIVE_DIR"] else {
            throw XCTSkip("Set REAL_ARCHIVE_DIR to run the real-archive replay.")
        }
        let rootURL = URL(fileURLWithPath: root)
        var pages: [BookPage] = []
        pages += diaryPages(in: rootURL.appendingPathComponent("memory/diary"))
        // memory/*.md session notes are dev logs (session keys, agent ids),
        // not life pages; the on-device Book would never see them, so the
        // replay must not either.
        pages += inkrestPages(at: rootURL.appendingPathComponent("players/bj-inkrest-log.jsonl"))
        XCTAssertFalse(pages.isEmpty, "no archive material found under \(root)")

        let days = groupedDays(pages)
        print("\n================ REAL ARCHIVE REPLAY ================")
        print("Material: \(pages.count) pages across \(days.count) days (\(days.first?.id ?? "?") ... \(days.last?.id ?? "?"))")

        // Day-by-day replay, exactly as tendConstellations would have run.
        var constellations: [Constellation] = []
        var wagers: [BookWager] = []
        var namingLog: [String] = []
        var wagerLog: [String] = []

        for (index, day) in days.enumerated() {
            let daysToDate = Array(days.prefix(index + 1))
            let now = calendar.date(byAdding: .hour, value: 20, to: day.date) ?? day.date
            let digest = LiteraryContinuityProjector.digest(
                days: daysToDate,
                events: [],
                entityMemories: [],
                now: now,
                calendar: calendar
            )
            let before = Set(constellations.filter(\.isNamed).map(\.id))
            constellations = ConstellationKeeper.advanced(constellations, observing: digest, now: now, calendar: calendar)
            for named in constellations.filter(\.isNamed) where !before.contains(named.id) {
                namingLog.append("\(day.id): NAMED \"\(named.name ?? "?")\" (\(named.kind.rawValue), \(named.sightingCount) sightings)")
            }
            let resolved = SealedMarginEngine.resolved(wagers, against: daysToDate, now: now, calendar: calendar)
            for wager in resolved where wager.status != .sealed && wagers.first(where: { $0.id == wager.id })?.status == .sealed {
                wagerLog.append("\(day.id): OPENED \(wager.status == .right ? "RIGHT" : "WRONG") - \(wager.prediction)")
            }
            wagers = resolved
            let minted = SealedMarginEngine.mintWagers(from: digest, existing: wagers, now: now, calendar: calendar)
            for wager in minted {
                wagerLog.append("\(day.id): SEALED - \(wager.prediction)")
            }
            wagers += minted
        }

        // Final state report.
        let finalNow = calendar.date(byAdding: .hour, value: 20, to: days.last?.date ?? Date()) ?? Date()
        let finalDigest = LiteraryContinuityProjector.digest(days: days, events: [], entityMemories: [], now: finalNow, calendar: calendar)

        print("\n--- TOP CONTINUITY SIGNALS (full archive) ---")
        for signal in finalDigest.strongestSignals.prefix(14) {
            print("  [\(signal.strength)] \(signal.kind.rawValue): \(signal.line)")
        }

        print("\n--- CONSTELLATION ROSTER ---")
        for constellation in constellations.sorted(by: { $0.strengthPeak > $1.strengthPeak }).prefix(20) {
            let name = constellation.name.map { "\"\($0)\"" } ?? "(unnamed)"
            print("  \(constellation.phase.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(name) <- \(constellation.subjectName) [peak \(constellation.strengthPeak), \(constellation.sightingCount) sightings]")
        }

        print("\n--- NAMING TIMELINE ---")
        namingLog.forEach { print("  \($0)") }
        if namingLog.isEmpty { print("  (nothing was ever named)") }

        print("\n--- WAGER LEDGER ---")
        wagerLog.forEach { print("  \($0)") }
        if wagerLog.isEmpty { print("  (no wagers were ever sealed)") }

        print("\n--- MONTHLY THEMES ---")
        for monthKey in ["2026-04", "2026-05", "2026-06"] {
            let monthPages = pages.filter { BookThemeEngine.monthKey(for: $0.createdAt, calendar: calendar) == monthKey }
            let monthDays = days.filter { BookThemeEngine.monthKey(for: $0.date, calendar: calendar) == monthKey }
            let monthDigest = LiteraryContinuityProjector.digest(days: monthDays, events: [], entityMemories: [], now: finalNow, calendar: calendar)
            if let theme = BookThemeEngine.theme(for: monthPages, digest: monthDigest, constellations: constellations, monthKey: monthKey, now: finalNow) {
                print("  \(monthKey): \"\(theme.name)\" [strength \(theme.strength)] motifs=\(theme.motifs)")
                print("        \(theme.line)")
                for excerpt in theme.excerptLines.prefix(2) {
                    print("        \u{201C}\(excerpt)\u{201D}")
                }
            } else {
                print("  \(monthKey): (no theme found)")
            }
        }

        print("\n--- MAY FOREWORD (as the Book would write it) ---")
        let mayDays = days.filter { BookThemeEngine.monthKey(for: $0.date, calendar: calendar) == "2026-05" }
        let mayPages = mayDays.flatMap(\.pages)
        let mayDigest = LiteraryContinuityProjector.digest(days: mayDays, events: [], entityMemories: [], now: finalNow, calendar: calendar)
        print(BookForewordWriter.foreword(
            monthTitle: "May 2026",
            pages: mayPages,
            dayCount: mayDays.count,
            continuity: mayDigest,
            constellations: constellations,
            wagers: wagers,
            calendar: calendar
        ))
        print("======================================================\n")

        // Optional: write the continuity export the Labyrinth consumes.
        if let exportPath = ProcessInfo.processInfo.environment["REAL_ARCHIVE_EXPORT"] {
            var themes: [BookTheme] = []
            for monthKey in ["2026-04", "2026-05", "2026-06"] {
                let monthPages = pages.filter { BookThemeEngine.monthKey(for: $0.createdAt, calendar: calendar) == monthKey }
                let monthDays = days.filter { BookThemeEngine.monthKey(for: $0.date, calendar: calendar) == monthKey }
                let monthDigest = LiteraryContinuityProjector.digest(days: monthDays, events: [], entityMemories: [], now: finalNow, calendar: calendar)
                if let theme = BookThemeEngine.theme(for: monthPages, digest: monthDigest, constellations: constellations, monthKey: monthKey, now: finalNow) {
                    themes.append(theme)
                }
            }
            let export = BookArchiveExport(
                generatedAt: finalNow,
                days: [],
                continuity: LiteraryContinuityDigest(
                    signals: Array(finalDigest.strongestSignals.prefix(12)),
                    beliefLifecycles: Array(finalDigest.beliefLifecycles.prefix(6))
                ),
                constellations: constellations,
                wagers: wagers,
                themes: themes,
                calendar: calendar
            )
            try export.encodedData().write(to: URL(fileURLWithPath: exportPath), options: [.atomic])
            print("Continuity export written to \(exportPath)")
        }
    }

    // MARK: Ingestion

    private func diaryPages(in directory: URL) -> [BookPage] {
        filesByDate(in: directory, suffix: ".md").map { date, url, _ in
            BookPage(
                id: "diary-\(url.lastPathComponent)",
                type: .diary,
                createdAt: calendar.date(byAdding: .hour, value: 21, to: date) ?? date,
                promptText: "Labyrinth Diary",
                userInput: trimmedBody(url, limit: 4000),
                tags: ["diary", "labyrinth"]
            )
        }
    }

    private func sessionNotePages(in directory: URL) -> [BookPage] {
        filesByDate(in: directory, suffix: ".md").map { date, url, _ in
            BookPage(
                id: "session-\(url.lastPathComponent)",
                type: .souvenir,
                createdAt: calendar.date(byAdding: .hour, value: 14, to: date) ?? date,
                promptText: "Session Note",
                userInput: trimmedBody(url, limit: 2500),
                tags: ["session"]
            )
        }
    }

    private func inkrestPages(at url: URL) -> [BookPage] {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let formatter = ISO8601DateFormatter()
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        var pages: [BookPage] = []
        for line in data.split(separator: "\n") {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  object["kind"] as? String == "mood-word",
                  let word = object["word"] as? String else { continue }
            let stamp = object["timestamp"] as? String ?? ""
            let date = formatter.date(from: stamp)
                ?? fallbackFormatter.date(from: String(stamp.prefix(19)))
                ?? Date.distantPast
            guard date != .distantPast else { continue }
            let note = object["note"] as? String ?? ""
            pages.append(BookPage(
                id: "mood-\(stamp)",
                type: .mood,
                createdAt: date,
                promptText: "One-word weather",
                userInput: "\(word). \(note)",
                tags: ["mood", "inkrest"]
            ))
        }
        return pages
    }

    private func filesByDate(in directory: URL, suffix: String) -> [(Date, URL, String)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return contents.compactMap { url in
            let name = url.lastPathComponent
            guard name.hasSuffix(suffix), name.count >= 10 else { return nil }
            guard let date = formatter.date(from: String(name.prefix(10))) else { return nil }
            return (date, url, name)
        }
        .sorted { $0.0 < $1.0 }
    }

    private func trimmedBody(_ url: URL, limit: Int) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        let body = text
            .components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("#") && !trimmed.lowercased().hasPrefix("*player") && !trimmed.lowercased().hasPrefix("player:")
            }
            .joined(separator: "\n")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(body.prefix(limit))
    }

    private func groupedDays(_ pages: [BookPage]) -> [BookDay] {
        var byDay: [String: BookDay] = [:]
        for page in pages.sorted(by: { $0.createdAt < $1.createdAt }) {
            let id = BookDay.id(for: page.createdAt, calendar: calendar)
            if var existing = byDay[id] {
                existing.pages.append(page)
                byDay[id] = existing
            } else {
                byDay[id] = BookDay(id: id, date: calendar.startOfDay(for: page.createdAt), pages: [page])
            }
        }
        return byDay.values.sorted { $0.date < $1.date }
    }
}
