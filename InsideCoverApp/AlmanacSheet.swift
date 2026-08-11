import SwiftUI

/// The Almanac: a month-grid over the kept archive so a reader can flip to any
/// day: "what did I write on the third?": the way every journal lets you.
/// Read-only; tapping a kept page hands it back to the Book to open.
struct AlmanacSheet: View {
    let days: [BookDay]
    let isEmbedded: Bool
    let selectedPageID: String?
    let onNavigationChange: (Date, Date?) -> Void
    let onOpen: (BookPage) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var monthAnchor: Date
    @State private var selectedDay: Date?
    @State private var monthDirection = 1

    private let calendar = Calendar.current

    init(
        days: [BookDay],
        isEmbedded: Bool = false,
        selectedPageID: String? = nil,
        initialMonthAnchor: Date? = nil,
        initialSelectedDay: Date? = nil,
        onNavigationChange: @escaping (Date, Date?) -> Void = { _, _ in },
        onOpen: @escaping (BookPage) -> Void
    ) {
        self.days = days
        self.isEmbedded = isEmbedded
        self.selectedPageID = selectedPageID
        self.onNavigationChange = onNavigationChange
        self.onOpen = onOpen
        // Open on the most recent month that holds anything, else this month.
        let cal = Calendar.current
        let latest = AlmanacModel.bounds(days: days, calendar: cal)?.latest
        _monthAnchor = State(
            initialValue: initialMonthAnchor
                ?? latest
                ?? AlmanacModel.firstOfMonth(for: Date(), calendar: cal)
        )
        _selectedDay = State(initialValue: initialSelectedDay)
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

    @ViewBuilder
    var body: some View {
        if isEmbedded {
            almanacRoot
        } else {
            NavigationStack {
                almanacRoot
            }
        }
    }

    private var almanacRoot: some View {
        ZStack {
                BookBackground(isQuiet: isEmbedded, showsAmbientLetters: !isEmbedded)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthHeader
                        if thread.litDays > 0 {
                            threadBanner
                        }
                        weekdayHeader
                        monthGrid
                            .id(grid.monthStart)
                            .transition(monthTransition)
                        if let day = selectedDay {
                            selectedDayList(for: day)
                                .id(day)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            Text("Tap a day with a mark to read what you kept then.")
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(BookPalette.nightText.opacity(0.6))
                                .padding(.top, 4)
                        }
                    }
                    .padding(18)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: monthAnchor)
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: selectedDay)
        }
        .navigationTitle("The Almanac")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmbedded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(BookPalette.lampGold)
                }
            }
        }
        .onChange(of: monthAnchor) { _, month in
            onNavigationChange(month, selectedDay)
        }
        .onChange(of: selectedDay) { _, day in
            onNavigationChange(monthAnchor, day)
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
            .buttonStyle(.bookPress(playsHaptic: false))

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
            .buttonStyle(.bookPress(playsHaptic: false))
        }
        .foregroundStyle(BookPalette.lampGold)
    }

    /// The Thread of the Month is a warm look backward at what arrived. There is
    /// no next tier, denominator, streak, or gap tally.
    private var threadBanner: some View {
        let progress = thread
        return HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.title3)
                .foregroundStyle(BookPalette.lampGold)
            VStack(alignment: .leading, spacing: 2) {
                Text(threadCountText(progress))
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText)
                Text(threadReflectionText(progress))
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
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM"
        let month = formatter.string(from: progress.monthStart)
        if progress.litDays == 1 {
            return "\(month) holds one day from your life"
        }
        return "\(month) holds \(progress.litDays) days from your life"
    }

    private func threadReflectionText(_ progress: ThreadOfTheMonth.Progress) -> String {
        let pageWord = progress.keptPages == 1 ? "Page" : "Pages"
        return "\(progress.keptPages) kept \(pageWord). The Almanac keeps whatever showed up. The rest can answer for itself."
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

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let incoming: Edge = monthDirection >= 0 ? .trailing : .leading
        let outgoing: Edge = monthDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: incoming).combined(with: .opacity),
            removal: .move(edge: outgoing).combined(with: .opacity)
        )
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
                        .scaleEffect(isSelected && !reduceMotion ? 1.65 : 1)
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
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(BookPalette.lampGold.opacity(isSelected ? 0.72 : 0), lineWidth: 1.2)
                        .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1)
                }
            }
            .buttonStyle(.bookPress(scale: 0.94, playsHaptic: false))
            .bookCardHover()
            .disabled(cell.keptCount == 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dayAccessibilityLabel(date: date, keptCount: cell.keptCount, isToday: isToday, isSelected: isSelected))
            .accessibilityHint(cell.keptCount > 0 ? "Shows pages kept on this day" : "No kept pages on this day")
        } else {
            Color.clear.frame(height: 40)
                .accessibilityHidden(true)
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
                let isSelected = isEmbedded && selectedPageID == page.id
                Button {
                    BookFeedback.play(.openPage)
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
                            .fill(
                                isSelected
                                    ? BookPalette.lampGold.opacity(0.18)
                                    : BookPalette.nightText.opacity(0.05)
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? BookPalette.lampGold.opacity(0.72) : Color.clear,
                                lineWidth: 1.5
                            )
                    }
                }
                .buttonStyle(.bookPress(playsHaptic: false))
                .bookCardHover()
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint("Opens on the reading stand")
                .contextMenu {
                    Button {
                        BookFeedback.play(.openPage)
                        onOpen(page)
                    } label: {
                        Label("Open on Reading Stand", systemImage: "book.pages")
                    }
                }
            }
        }
    }

    private func dayAccessibilityLabel(
        date: Date,
        keptCount: Int,
        isToday: Bool,
        isSelected: Bool
    ) -> String {
        let formatted = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        let pages = keptCount == 1 ? "1 kept page" : "\(keptCount) kept pages"
        return [formatted, pages, isToday ? "today" : nil, isSelected ? "selected" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func firstLine(of page: BookPage) -> String {
        page.archivePreviewText ?? page.type.title
    }

    private func step(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: grid.monthStart) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            monthDirection = months
            monthAnchor = next
            selectedDay = nil
        }
        BookFeedback.play(.sourceRefresh)
    }
}
