import SwiftUI

/// The Almanac: a month-grid over the kept archive so a reader can flip to any
/// day — "what did I write on the third?" — the way every journal lets you.
/// Read-only; tapping a kept page hands it back to the Book to open.
struct AlmanacSheet: View {
    let days: [BookDay]
    let onOpen: (BookPage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var monthAnchor: Date
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    init(days: [BookDay], onOpen: @escaping (BookPage) -> Void) {
        self.days = days
        self.onOpen = onOpen
        // Open on the most recent month that holds anything, else this month.
        let cal = Calendar.current
        let latest = AlmanacModel.bounds(days: days, calendar: cal)?.latest
        _monthAnchor = State(initialValue: latest ?? AlmanacModel.firstOfMonth(for: Date(), calendar: cal))
    }

    private var grid: AlmanacModel.MonthGrid {
        AlmanacModel.grid(forMonthContaining: monthAnchor, days: days, calendar: calendar)
    }

    private var thread: ThreadOfTheMonth.Progress {
        ThreadOfTheMonth.progress(forMonthContaining: monthAnchor, days: days, calendar: calendar)
    }

    private var bounds: (earliest: Date, latest: Date)? {
        AlmanacModel.bounds(days: days, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthHeader
                        if thread.litDays > 0 {
                            threadBanner
                        }
                        weekdayHeader
                        monthGrid
                        if let day = selectedDay {
                            selectedDayList(for: day)
                        } else {
                            Text("Tap a day with a mark to read what you kept then.")
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(BookPalette.nightText.opacity(0.6))
                                .padding(.top, 4)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("The Almanac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(BookPalette.lampGold)
                }
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: grid.monthStart)
    }

    private var canGoBack: Bool {
        guard let earliest = bounds?.earliest else { return false }
        return grid.monthStart > earliest
    }

    private var canGoForward: Bool {
        guard let latest = bounds?.latest else { return false }
        return grid.monthStart < latest
    }

    private var monthHeader: some View {
        HStack {
            Button {
                step(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
            }
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1 : 0.3)

            Spacer()
            Text(monthTitle)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText)
            Spacer()

            Button {
                step(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.3)
        }
        .foregroundStyle(BookPalette.lampGold)
    }

    /// The Thread of the Month: a warm count of lit days and the keepsake earned,
    /// never a chain and never a guilt-inducing gap tally. Only shown for a month
    /// that has something in it.
    private var threadBanner: some View {
        let progress = thread
        return HStack(spacing: 10) {
            Image(systemName: progress.seal.sfSymbol)
                .font(.title3)
                .foregroundStyle(BookPalette.lampGold)
            VStack(alignment: .leading, spacing: 2) {
                Text(threadCountText(progress))
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText)
                Text(threadTierText(progress))
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(BookPalette.nightText.opacity(0.6))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BookPalette.lampGold.opacity(0.10))
        )
    }

    private func threadCountText(_ progress: ThreadOfTheMonth.Progress) -> String {
        let dayWord = progress.litDays == 1 ? "day" : "days"
        return "\(progress.litDays) lit \(dayWord) this month"
    }

    private func threadTierText(_ progress: ThreadOfTheMonth.Progress) -> String {
        if progress.seal != .unbound, let next = progress.nextSeal {
            let more = progress.litDaysToNextSeal
            let dayWord = more == 1 ? "day" : "days"
            return "\(progress.seal.name.capitalized) \u{00B7} \(more) more \(dayWord) to \(next.name)"
        } else if progress.seal != .unbound {
            return "\(progress.seal.name.capitalized) \u{2014} a full, well-kept month"
        } else if let next = progress.nextSeal {
            let more = progress.litDaysToNextSeal
            let dayWord = more == 1 ? "day" : "days"
            return "\(more) more \(dayWord) to start the thread"
        }
        return "The thread has begun."
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        // Rotate so the first column matches the calendar's firstWeekday.
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        VStack(spacing: 6) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { cell in
                        dayCell(cell)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: AlmanacModel.DayCell) -> some View {
        if let date = cell.date {
            let isToday = calendar.isDateInToday(date)
            let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedDay = (cell.keptCount > 0) ? date : nil
                }
                BookFeedback.play(.openPage)
            } label: {
                VStack(spacing: 3) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(cell.keptCount > 0 ? BookPalette.nightText : BookPalette.nightText.opacity(0.4))
                    Circle()
                        .fill(cell.keptCount > 0 ? BookPalette.teal : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? BookPalette.lampGold.opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? BookPalette.lampGold.opacity(0.7) : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(cell.keptCount == 0)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func selectedDayList(for day: Date) -> some View {
        let pages = AlmanacModel.keptPages(on: day, days: days, calendar: calendar)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE, MMMM d"
        return VStack(alignment: .leading, spacing: 10) {
            Text(formatter.string(from: day))
                .font(.system(.headline, design: .serif))
                .foregroundStyle(BookPalette.nightText)
                .padding(.top, 6)
            ForEach(pages) { page in
                Button {
                    onOpen(page)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(page.type.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.lampGold)
                        Text(firstLine(of: page))
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(BookPalette.nightText.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BookPalette.nightText.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func firstLine(of page: BookPage) -> String {
        let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = text.isEmpty ? page.promptText : text
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? page.type.title : body
    }

    private func step(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: grid.monthStart) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            monthAnchor = next
            selectedDay = nil
        }
        BookFeedback.play(.sourceRefresh)
    }
}
