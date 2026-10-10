import XCTest
@testable import InsideCoverCore

/// Opt-in proof material. Calls the Mac mirror of the phone's Gemma, using the
/// app's exact weekly writing jobs and acceptance checks. Ordinary tests never
/// load a model or touch the network. The supplied days must be QA fixtures.
final class WeeklyTaleLabTests: XCTestCase {
    struct Notes: Codable {
        var startDate: Date
        var title: String?
        var opening: String
        var closing: String
        var drafts: [String]
        var accepted: [String]
    }

    func testProofTheWeeklyWithGemmaWhenAsked() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let output = env["WEEKLY_LAB_OUT"] else { return }
        let days = try env["WEEKLY_LAB_DAYS"].map {
            try JSONDecoder().decode([BookDay].self, from: Data(contentsOf: URL(fileURLWithPath: $0)))
        } ?? []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let server = URL(string: env["BRAID_LAB_URL"] ?? "http://127.0.0.1:8765/")!
        func date(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
        }
        func tell(_ prompt: String, tokens: Int) async throws -> String {
            var request = URLRequest(url: server)
            request.httpMethod = "POST"
            request.timeoutInterval = 600
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "system": WeeklyTaleReading.instructions, "user": prompt,
                "temperature": 0.65, "topP": 0.88, "maxTokens": tokens
            ])
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Reply: Decodable { var text: String }
            return try JSONDecoder().decode(Reply.self, from: data).text
        }
        var issues: [WeeklyIssue] = try env["WEEKLY_LAB_ISSUES"].map {
            try JSONDecoder().decode([WeeklyIssue].self, from: Data(contentsOf: URL(fileURLWithPath: $0)))
        } ?? []
        for startDay in (issues.isEmpty && !days.isEmpty ? [8, 15, 22] : []) {
            let start = date(10, startDay)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            let period = PublicationPeriodCatalog.period(recipe: .readerWeek, startDate: start, endDate: end,
                                                          ordinal: 41 + (startDay - 8) / 7, calendar: calendar)
            issues.append(try XCTUnwrap(WeeklyIssue.issue(for: period, days: days, now: end, calendar: calendar)))
        }
        let thin = BookPage(id: "thin-proof", type: .diary, createdAt: date(2, 10),
                            promptText: "One true thing", userInput: "I miss Dad. I still put two cups on the table.")
        issues.append(WeeklyIssue(number: 7, startDate: date(2, 8), endDate: date(2, 15), dateRange: "Feb 8–14",
                                  keptCount: 1, highlights: [], setAsideLine: nil, pages: [thin]))
        var result: [Notes] = []
        for issue in issues {
            let reading = WeeklyTaleReading(issue: issue, calendar: calendar)
            var record = Notes(startDate: issue.startDate, title: nil,
                               opening: reading.note(at: .opening), closing: reading.note(at: .closing),
                               drafts: [], accepted: [])
            if let prompt = reading.titlePrompt {
                let raw = try await tell(prompt, tokens: 48)
                // Freeze the same safe title floor the app uses, too. Simulator
                // language assets can differ from the phone and the Mac mirror.
                record.title = reading.acceptedTitle(raw) ?? reading.title
                record.drafts.append("TITLE: " + raw)
            }
            for position in [WeeklyTaleReading.Position.opening, .closing] {
                for attempt in 1...2 {
                    let raw = try await tell(reading.prompt(at: position), tokens: 130)
                    record.drafts.append("\(position.rawValue) \(attempt): " + raw)
                    guard let lines = reading.acceptedBookLines(raw, at: position) else { continue }
                    let note = reading.note(at: position, bookLines: lines)
                    if position == .opening { record.opening = note } else { record.closing = note }
                    record.accepted.append(position.rawValue)
                    break
                }
            }
            print("WEEKLY_PROOF \(issue.dateRange) title=\(record.title ?? reading.title ?? "none") Gemma=\(record.accepted)")
            print(record.opening + "\n\n" + record.closing)
            result.append(record)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(result).write(to: URL(fileURLWithPath: output))
        }
        XCTAssertEqual(result.count, issues.count)
    }
}
