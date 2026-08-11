import Foundation

/// Plain Ink: the whole kept archive as ordinary Markdown: readable anywhere,
/// forever, with no app required. The counterpart to the Sealed Copy: that one
/// is for restoring the Book; this one is for reading it outside the Book.
/// Pure string building, so it's testable.
enum PlainInkExport {

    /// Build a Markdown document of every kept page across `days`, oldest first.
    /// Days with no kept pages are skipped. `title` heads the document.
    static func markdown(
        days: [BookDay],
        calendar: Calendar,
        title: String = "ReEnchanted: the Book"
    ) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.dateFormat = "EEEE, MMMM d, yyyy"

        // Order days by their real start, oldest first.
        let ordered = days
            .map { (day: $0, start: BookDay.startDate(for: $0.id, fallback: $0.date, calendar: calendar)) }
            .sorted { $0.start < $1.start }

        var lines: [String] = ["# \(title)", ""]

        for entry in ordered {
            let pages = entry.day.capturedPages.sorted { $0.createdAt < $1.createdAt }
            guard !pages.isEmpty else { continue }

            lines.append("## \(dayFormatter.string(from: entry.start))")
            lines.append("")

            for page in pages {
                lines.append("### \(page.type.title)")
                lines.append("")

                let prompt = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !prompt.isEmpty {
                    lines.append("> \(prompt)")
                    lines.append("")
                }

                let body = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    lines.append(body)
                    lines.append("")
                }

                let reply = page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty {
                    lines.append(reply)
                    lines.append("")
                }

                let tags = page.tags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !tags.isEmpty {
                    lines.append("_" + tags.map { "#\($0)" }.joined(separator: " ") + "_")
                    lines.append("")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
