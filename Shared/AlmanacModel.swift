import Foundation

/// The Almanac: a browsable month-grid over the kept archive, so a reader can
/// flip to "what did I write on the third" the way every journal lets you.
/// Pure data + arithmetic — no SwiftUI, no app types — so it's testable.
enum AlmanacModel {

    /// One cell in the month grid. `date` is the day's start; leading/trailing
    /// blanks that pad the grid to whole weeks carry `date == nil`.
    struct DayCell: Equatable, Identifiable {
        var id: String { date.map { AlmanacModel.dayID(for: $0, calendar: .current) } ?? "blank-\(blankIndex)" }
        var date: Date?
        var keptCount: Int
        /// Only meaningful for blank padding cells, to keep ids unique.
        var blankIndex: Int
    }

    /// A single month laid out as weeks of seven cells each.
    struct MonthGrid: Equatable {
        /// First day of the month (midnight).
        var monthStart: Date
        /// Rows of seven cells; leading/trailing padding cells have `date == nil`.
        var weeks: [[DayCell]]
    }

    /// Stable per-day key ("yyyy-MM-dd") in the given calendar's terms.
    static func dayID(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Number of kept (captured, non-generated) pages per day, keyed by dayID.
    /// Uses `BookDay.capturedPages` so generated Book-of-You pages don't count.
    static func keptCounts(days: [BookDay], calendar: Calendar) -> [String: Int] {
        var counts: [String: Int] = [:]
        for day in days {
            let n = day.capturedPages.count
            guard n > 0 else { continue }
            let start = BookDay.startDate(for: day.id, fallback: day.date, calendar: calendar)
            counts[dayID(for: start, calendar: calendar), default: 0] += n
        }
        return counts
    }

    /// Build the grid for the month containing `monthAnchor`. Weeks start on the
    /// calendar's `firstWeekday`. Cell counts come from `keptCounts`.
    static func grid(forMonthContaining monthAnchor: Date, days: [BookDay], calendar: Calendar) -> MonthGrid {
        let counts = keptCounts(days: days, calendar: calendar)
        let comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        let monthStart = calendar.date(from: comps) ?? monthAnchor
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? (1..<31)
        let dayCount = range.count

        // Leading blanks: distance from the week's first weekday to the 1st.
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [DayCell] = []
        var blankIndex = 0
        for _ in 0..<leading {
            cells.append(DayCell(date: nil, keptCount: 0, blankIndex: blankIndex))
            blankIndex += 1
        }
        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: monthStart) else { continue }
            let count = counts[dayID(for: date, calendar: calendar)] ?? 0
            cells.append(DayCell(date: date, keptCount: count, blankIndex: 0))
        }
        // Trailing blanks to complete the final week.
        while cells.count % 7 != 0 {
            cells.append(DayCell(date: nil, keptCount: 0, blankIndex: blankIndex))
            blankIndex += 1
        }

        let weeks = stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
        return MonthGrid(monthStart: monthStart, weeks: weeks)
    }

    /// First-of-month for the earliest / latest kept day, so month paging can
    /// clamp to the archive's real bounds. Nil when there are no kept pages.
    static func bounds(days: [BookDay], calendar: Calendar) -> (earliest: Date, latest: Date)? {
        let kept = days.filter { !$0.capturedPages.isEmpty }
        guard !kept.isEmpty else { return nil }
        let starts = kept.map { BookDay.startDate(for: $0.id, fallback: $0.date, calendar: calendar) }
        guard let min = starts.min(), let max = starts.max() else { return nil }
        return (firstOfMonth(for: min, calendar: calendar), firstOfMonth(for: max, calendar: calendar))
    }

    /// The kept pages of a specific day, newest first, for the expanded list.
    static func keptPages(on date: Date, days: [BookDay], calendar: Calendar) -> [BookPage] {
        let target = dayID(for: date, calendar: calendar)
        for day in days {
            let start = BookDay.startDate(for: day.id, fallback: day.date, calendar: calendar)
            if dayID(for: start, calendar: calendar) == target {
                return day.capturedPages.sorted { $0.createdAt > $1.createdAt }
            }
        }
        return []
    }

    static func firstOfMonth(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}

/// The Thread of the Month: a deliberately guilt-free "streak."
///
/// It counts *lit days* — days with at least one kept page — within a single
/// calendar month, and it never counts consecutive days. A missed day dims
/// nothing and breaks nothing, because there is no chain to break: the thread
/// only ever gains stitches, one per lit day, and holds them until the month
/// ends. Each month is its own binding (a fresh Monthly Edition), so the reset
/// is how books work, not a punishment. One kept page lights a day; a second or
/// tenth adds nothing, so the thread never rewards grinding pages over keeping
/// one true one. Pure arithmetic over the archive — no SwiftUI, no app types.
///
/// This is the counterweight to `NothingTide`: the grey counts the days you let
/// slip; the thread counts the days you showed up. Only the thread is ever shown
/// to the reader as a number.
enum ThreadOfTheMonth {

    /// The keepsake a month earns purely by how many of its days were lit. Warm
    /// binder's names, never medal tiers; each tier only ever adds, never
    /// revokes, and a thin month is still a real, named month.
    enum Seal: Int, Comparable, CaseIterable {
        case unbound = 0   // below the first stitch-count; a month begun
        case inked         // a handful of lit days — the month has ink in it
        case sealed        // enough to warrant a wax seal
        case ribboned      // a ribbon around a well-kept month
        case bound         // cloth binding — a full, well-inked month

        static func < (lhs: Seal, rhs: Seal) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Lit-day count at which the tier is earned. Kept low on purpose: the
        /// bars should feel reachable, so the thread is encouragement, not a quota.
        var litDaysRequired: Int {
            switch self {
            case .unbound: return 0
            case .inked: return 3
            case .sealed: return 8
            case .ribboned: return 15
            case .bound: return 22
            }
        }

        /// Warm, lower-case display name for the tier.
        var name: String {
            switch self {
            case .unbound: return "a month begun"
            case .inked: return "inked"
            case .sealed: return "wax-sealed"
            case .ribboned: return "ribboned"
            case .bound: return "cloth-bound"
            }
        }

        /// SF Symbol name for the tier's mark in the Almanac. Just a string, so
        /// the pure model stays free of SwiftUI while the UI stays trivial.
        var sfSymbol: String {
            switch self {
            case .unbound: return "book.closed"
            case .inked: return "drop.fill"
            case .sealed: return "seal.fill"
            case .ribboned: return "rosette"
            case .bound: return "books.vertical.fill"
            }
        }
    }

    /// The lit-day counts that earn a story reaction as the reader crosses them.
    /// They are exactly the seal thresholds, so every milestone hands over a
    /// keepsake tier — four warm beats across a month, no busywork in between.
    static var milestones: [Int] { Seal.allCases.map(\.litDaysRequired).filter { $0 > 0 } }

    /// A month's thread, snapshotted.
    struct Progress: Equatable {
        var monthStart: Date
        /// Days this month with at least one kept page.
        var litDays: Int
        /// Total days in the month (for "12 of 30" phrasing).
        var daysInMonth: Int
        /// The keepsake tier earned so far.
        var seal: Seal
        /// The next tier not yet reached, and how many more lit days it wants.
        /// Nil once the top tier is earned.
        var nextSeal: Seal?
        var litDaysToNextSeal: Int
    }

    /// The set of lit dayIDs within the month containing `anchor`.
    static func litDayIDs(inMonthContaining anchor: Date, days: [BookDay], calendar: Calendar) -> Set<String> {
        let comps = calendar.dateComponents([.year, .month], from: anchor)
        var lit: Set<String> = []
        for day in days where !day.capturedPages.isEmpty {
            let start = BookDay.startDate(for: day.id, fallback: day.date, calendar: calendar)
            let dayComps = calendar.dateComponents([.year, .month], from: start)
            guard dayComps.year == comps.year, dayComps.month == comps.month else { continue }
            lit.insert(AlmanacModel.dayID(for: start, calendar: calendar))
        }
        return lit
    }

    /// Count of lit days in the month containing `anchor`.
    static func litDayCount(inMonthContaining anchor: Date, days: [BookDay], calendar: Calendar) -> Int {
        litDayIDs(inMonthContaining: anchor, days: days, calendar: calendar).count
    }

    /// The keepsake tier for a given lit-day count.
    static func seal(forLitDays litDays: Int) -> Seal {
        Seal.allCases.last { litDays >= $0.litDaysRequired } ?? .unbound
    }

    /// Full thread snapshot for the month containing `anchor`.
    static func progress(forMonthContaining anchor: Date, days: [BookDay], calendar: Calendar) -> Progress {
        let monthStart = AlmanacModel.firstOfMonth(for: anchor, calendar: calendar)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let litDays = litDayCount(inMonthContaining: anchor, days: days, calendar: calendar)
        let seal = seal(forLitDays: litDays)
        let next = Seal.allCases.first { $0.litDaysRequired > litDays }
        return Progress(
            monthStart: monthStart,
            litDays: litDays,
            daysInMonth: daysInMonth,
            seal: seal,
            nextSeal: next,
            litDaysToNextSeal: next.map { max(0, $0.litDaysRequired - litDays) } ?? 0
        )
    }

    /// The milestone just crossed when the month's lit-day count moves from
    /// `before` to `after` (a keep that lights a new day). Nil when no threshold
    /// falls in that gap — so it fires once, on the day the count reaches it.
    static func milestoneCrossed(from before: Int, to after: Int) -> Int? {
        guard after > before else { return nil }
        return milestones.first { $0 > before && $0 <= after }
    }
}
