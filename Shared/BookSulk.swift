import Foundation

// MARK: - The Book's sulks
//
// The Book writes the Tale's pages, so a page the reader puts in the Trash is
// a page it wrote that went in the bin. The story carries on regardless; the
// Book may mind a little, out loud, once in a while.
//
// Rules, held by tests:
// - Rare: about two trashes in three provoke one, and never two in a week.
// - Never on a hard night. The Book has better manners than that.
// - Never the reader's fault. The grievance is with the bin, the soup, the
//   Index, the stairs, and it is over by the next line.
// - Shown, not announced: the Book never says it is sulking.
// - Funny and fond. A sulk that makes the reader smile has done its job.
//
// A sulk rides in the braid as the Book's business for the night (see
// `BookBusiness`), so Gemma can lift it, bend it, or leave it.

enum BookSulk {
    /// A story scene the reader put in the Trash.
    struct Trashed: Codable, Equatable, Identifiable {
        var id: String
        var title: String?
        var at: Date
    }

    static let idPrefix = "sulk:"
    /// Stamped on a braid that carried a sulk, so the next week's nights know.
    static let tagPrefix = "braid-sulk:"
    static let withinDays = 4
    static let restDays = 7

    /// Lines about a particular page. `{title}` is the scene's title.
    static let titled: [String] = [
        "I wrote “{title}” by the light of one small candle. It went in the bin. I'm not discussing it. I'm discussing it a bit.",
        "I've told the Index about “{title}”. The Index said nothing. That's worse.",
        "I'm being extremely normal about “{title}”. Watch how normal I'm being.",
        "I'm not saying “{title}” was my best work. I'm saying it was some of it.",
        "I've drawn a frowning face in the margin where “{title}” used to be. It's a good face. It's got eyebrows.",
        "“{title}” had a joke in it. A real one. Now it's out there with nobody to laugh at it.",
        "I rewrote the first line of “{title}” eleven times, and the bin got the lot.",
        "I've decided “{title}” was too good for the desk. The desk and I have agreed to disagree.",
        "I'm eating my biscuit alone tonight. The biscuit was going to go in “{title}”.",
        "Ambrose says “{title}” will keep. Ambrose also says a pot will boil. We'll see.",
        "I've pinned a note to the Index: “{title}”, one copy, lost, no hard feelings. There are some feelings.",
        "I'm reading the last page of “{title}” to the stairs. The stairs are being supportive. The stairs aren't listening.",
        "I've been through everything I wrote for “{title}” looking for what went wrong. It was the soup. It was always going to be the soup.",
        "Penny says “{title}” made the Bleed's second draft. I'm choosing to hear that as a compliment.",
        "Wicker read the first line of “{title}” in the corridor and said huh. I've been thinking about huh all day.",
        "I've tucked “{title}” into the back of my mind, where I keep things I'm not thinking about. It's crowded back there.",
        "If anyone asks, I never wrote “{title}”. If anyone doesn't ask, I definitely wrote it.",
        "Somewhere a page of “{title}” is lying in a dark drawer, thinking about me.",
        "I'm leaving a light on for “{title}”. I know. I know.",
        "I told the lamps about “{title}”. They flickered in sympathy, or they were bored. Hard to say.",
        "I've asked the bin for “{title}” back. The bin says it's thinking about it.",
        "I put “{title}” on the windowsill to dry its eyes. It's a page. It doesn't have eyes. It's managing anyway.",
        "I've given “{title}” a funeral in my head. It was short and the sandwiches were good.",
        "I keep opening to where “{title}” was and finding the next page there, looking pleased with itself.",
        "I've stopped mentioning “{title}”. I've mentioned that I've stopped mentioning it. That's fine. That's allowed."
    ]

    /// Lines for when the page's title wasn't kept.
    static let untitled: [String] = [
        "A page I wrote went in the bin this week. I've moved on. I've moved on twice.",
        "I wrote a good one this week and it went straight in the bin. The bin looked smug. Bins always do.",
        "One of my pages is in the bin and I'm being brave about it, loudly, with a lot of sighing.",
        "The next one will be better. I've started it. It has a dragon in it, a small one, with opinions.",
        "I've been telling the shelves about the page that got binned. They've heard it four times. They're polite.",
        "There's a gap where a page of mine used to be. I keep patting it.",
        "I'm saving a seat for the page that went in the bin, in case it changes its mind. It won't. It's a nice seat."
    ]

    /// The scenes this reader put in the Trash recently, newest first. Leaving
    /// a Jump episode is a different thing and isn't a Trash.
    static func trashed(
        from ledger: AuthoredContentReceiptLedger,
        now: Date,
        withinDays days: Int = BookSulk.withinDays
    ) -> [Trashed] {
        let since = now.addingTimeInterval(-Double(days) * 86_400)
        return ledger.receipts
            .filter {
                $0.channel == .storyScene && $0.state == .dismissed
                    && !$0.occurrenceID.hasPrefix("left-episode:")
                    && $0.recordedAt >= since && $0.recordedAt <= now
            }
            .sorted { $0.recordedAt > $1.recordedAt }
            .map { Trashed(id: $0.id, title: $0.printedTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue, at: $0.recordedAt) }
    }

    /// Tonight's sulk, if there is one.
    static func pick(
        trashed: [Trashed],
        recentDays: [BookDay],
        on date: Date,
        hardNight: Bool,
        calendar: Calendar = .current
    ) -> BookBusiness.Line? {
        guard !hardNight, let newest = trashed.first(where: { $0.at <= date }) else { return nil }
        let hash = HandbookBuilder.stableHash("sulk|\(newest.id)")
        // Two trashes in three. The third is forgiven without a word.
        guard hash % 3 != 0 else { return nil }
        // Never twice in a week.
        let weekAgo = date.addingTimeInterval(-Double(restDays) * 86_400)
        let sulkedRecently = recentDays.contains { day in
            day.date >= weekAgo && day.pages.contains { $0.tags.contains { $0.hasPrefix(tagPrefix) } }
        }
        guard !sulkedRecently else { return nil }

        let template: String
        if let title = newest.title {
            template = titled[Int((hash / 3) % UInt64(titled.count))].replacingOccurrences(of: "{title}", with: title)
        } else {
            template = untitled[Int((hash / 3) % UInt64(untitled.count))]
        }
        return BookBusiness.Line(id: idPrefix + String(hash % 1_000_000), text: template)
    }
}

private extension String {
    var nonEmptyValue: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
