import Foundation

private func publicationPageHasMaterial(_ page: BookPage) -> Bool {
    page.type != .bookOfYou
        && (page.hasReaderContribution
            || page.bookAuthoredText != nil
            || !page.mediaAssets.isEmpty
            || page.usedInBookOfYou)
}

/// The one date the Book must not keep rediscovering. Without a frozen Reader
/// Week anchor, importing an older page would renumber every later issue and a
/// time-zone change could move the first boundary under an already-bound book.
struct BookPublicationEpoch: Codable, Equatable {
    var readerWeekAnchorDayID: String
    var timeZoneIdentifier: String
    var establishedAt: Date

    func calendar(basedOn fallback: Calendar = .current) -> Calendar {
        var calendar = fallback
        if let zone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = zone
        }
        return calendar
    }

    func readerWeekAnchor(calendar fallback: Calendar = .current) -> Date {
        let calendar = calendar(basedOn: fallback)
        return BookDay.startDate(
            for: readerWeekAnchorDayID,
            fallback: establishedAt,
            calendar: calendar
        )
    }

    static func seeded(
        from days: [BookDay],
        today: BookDay? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BookPublicationEpoch? {
        var byID: [String: BookDay] = [:]
        for day in days { byID[day.id] = day }
        if let today { byID[today.id] = today }
        let firstKeep = byID.values
            .flatMap(\.pages)
            .filter { page in
                page.type != .bookOfYou
                    && page.weeklyIssueArtifact == nil
                    && page.monthlyEditionArtifact == nil
                    && page.annualEditionArtifact == nil
                    && page.sourceID != "weekly-issue"
                    && page.sourceID != "monthly-edition"
                    && page.sourceID != "annual-edition"
                    && publicationPageHasMaterial(page)
            }
            .map(\.createdAt)
            .min()
        guard let firstKeep else { return nil }
        return BookPublicationEpoch(
            readerWeekAnchorDayID: BookDay.id(for: firstKeep, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier,
            establishedAt: now
        )
    }
}

/// The clock a publication follows.
///
/// Calendar books and the prepaid Bound Year may cover similar spans, but they
/// are not interchangeable: a July-September seasonal edition is not the same
/// promise as a member's second three-month dispatch. The recipe travels in the
/// identity so neither the shelf nor the press can silently substitute one for
/// the other.
enum PublicationPeriodRecipe: String, Codable, Equatable, Hashable, CaseIterable {
    case readerWeek
    case calendarMonth
    case calendarSeason
    case calendarYear
    case boundYearSeason
    case boundYearAnnual

    var cadence: PublicationEditionKind {
        switch self {
        case .readerWeek:
            return .weekly
        case .calendarMonth:
            return .monthly
        case .calendarSeason, .boundYearSeason:
            return .seasonal
        case .calendarYear, .boundYearAnnual:
            return .annual
        }
    }

    /// This threshold decides whether the Book knocks. It does not decide
    /// whether the reader is allowed to bind a completed, nonempty period.
    var recommendationMinimum: Int {
        switch self {
        case .readerWeek:
            return WeeklyIssue.minimumIssuePages
        case .calendarMonth:
            return 3
        case .calendarSeason, .calendarYear, .boundYearSeason, .boundYearAnnual:
            return 1
        }
    }
}

/// Stable identity for a publication window. Day ids are deliberately stored
/// instead of formatting `Date` at the point of use: the same finished period
/// keeps its shelf identity when the reader travels across a time-zone seam.
struct PublicationPeriodID: Codable, Equatable, Hashable, Identifiable {
    var recipe: PublicationPeriodRecipe
    var startDayID: String
    var endDayID: String

    var id: String { rawValue }
    var rawValue: String {
        "\(recipe.rawValue)|\(startDayID)|\(endDayID)"
    }
}

/// One exact editorial interval. `endDate` is exclusive, which lets adjacent
/// periods touch without sharing midnight or losing a page at the boundary.
struct PublicationPeriod: Codable, Equatable, Identifiable {
    var id: PublicationPeriodID
    var startDate: Date
    var endDate: Date
    /// Reader Week issue number or dispatch number where one exists.
    var ordinal: Int?

    var recipe: PublicationPeriodRecipe { id.recipe }
    var cadence: PublicationEditionKind { recipe.cadence }

    func contains(_ date: Date) -> Bool {
        date >= startDate && date < endDate
    }

    func isClosed(at now: Date) -> Bool {
        now >= endDate
    }
}

enum PublicationMaterialStatus: String, Codable, Equatable {
    /// The period has not ended. It may be previewed, but not finally bound.
    case gathering
    /// It ended without a single page the edition curator would bind.
    case empty
    /// It ended with material. The reader may bind it, though the Book does
    /// not spend an interruption knocking about it.
    case quiet
    /// It ended with enough material for the Book to recommend it.
    case ready
}

/// A derived shelf entry. Nothing here needs persistence: the archive and its
/// already-bound artifacts are authoritative, and the catalogue can be rebuilt
/// whenever the date, pages, or imports change.
struct PublicationCandidate: Equatable, Identifiable {
    var period: PublicationPeriod
    var eligiblePageCount: Int
    var boundRevisionCount: Int
    var materialStatus: PublicationMaterialStatus

    var id: PublicationPeriodID { period.id }
    var isCompleted: Bool { materialStatus != .gathering }
    var isBindable: Bool { isCompleted && eligiblePageCount > 0 }
    var isRecommended: Bool { materialStatus == .ready }
    var hasBoundEdition: Bool { boundRevisionCount > 0 }
}

/// Enumerates publication periods independently of the short-lived Pages that
/// invite the reader to bind them. Invitations may go quiet; these candidates
/// do not expire.
enum PublicationPeriodCatalog {
    static func readerWeeks(
        days: [BookDay],
        today: BookDay? = nil,
        frozenAnchor: Date? = nil,
        boundRevisionCounts: [PublicationPeriodID: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PublicationCandidate] {
        let archive = normalizedDays(days, today: today)
        // One candidate per reader-week since the first keep, each of which
        // curates its own slice of the archive. A reader a year in pays for
        // fifty-two of them every time something asks what can be bound.
        let salt = [
            "reader-week",
            "anchor:\(frozenAnchor.map { Int($0.timeIntervalSince1970) } ?? -1)",
            "day:\(Int(calendar.startOfDay(for: now).timeIntervalSince1970))",
            boundRevisionSalt(boundRevisionCounts)
        ].joined(separator: "|")
        return ArchiveMemo.value(
            "publication.reader-weeks",
            days: archive,
            salt: salt,
            compute: {
                gatheredReaderWeeks(
                    archive: archive,
                    frozenAnchor: frozenAnchor,
                    boundRevisionCounts: boundRevisionCounts,
                    now: now,
                    calendar: calendar
                )
            }
        )
    }

    private static func gatheredReaderWeeks(
        archive: [BookDay],
        frozenAnchor: Date?,
        boundRevisionCounts: [PublicationPeriodID: Int],
        now: Date,
        calendar: Calendar
    ) -> [PublicationCandidate] {
        let captured = archive
            .flatMap(\.pages)
            .filter { page in
                page.type != .bookOfYou
                    && !isBoundPublicationArtifact(page)
                    && publicationPageHasMaterial(page)
            }
        guard let firstKeep = frozenAnchor ?? captured.map(\.createdAt).min() else { return [] }
        let anchor = calendar.startOfDay(for: firstKeep)
        let currentDay = calendar.startOfDay(for: now)
        guard let elapsed = calendar.dateComponents([.day], from: anchor, to: currentDay).day,
              elapsed >= 0 else { return [] }

        let currentOrdinal = elapsed / WeeklyIssue.weekDays + 1
        return (1...currentOrdinal).reversed().compactMap { ordinal in
            guard let start = calendar.date(
                byAdding: .day,
                value: (ordinal - 1) * WeeklyIssue.weekDays,
                to: anchor
            ), let end = calendar.date(byAdding: .day, value: WeeklyIssue.weekDays, to: start) else {
                return nil
            }
            let period = makePeriod(
                recipe: .readerWeek,
                start: start,
                end: end,
                ordinal: ordinal,
                calendar: calendar
            )
            return candidate(
                for: period,
                archive: archive,
                boundRevisionCounts: boundRevisionCounts,
                now: now,
                calendar: calendar
            )
        }
    }

    static func calendarMonths(
        days: [BookDay],
        today: BookDay? = nil,
        boundRevisionCounts: [PublicationPeriodID: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PublicationCandidate] {
        calendarCandidates(
            recipe: .calendarMonth,
            days: days,
            today: today,
            boundRevisionCounts: boundRevisionCounts,
            now: now,
            calendar: calendar
        )
    }

    /// Fixed, non-overlapping calendar blocks: Jan-Mar, Apr-Jun, Jul-Sep,
    /// Oct-Dec. A reader may name the volume; its period does not move later.
    static func calendarSeasons(
        days: [BookDay],
        today: BookDay? = nil,
        boundRevisionCounts: [PublicationPeriodID: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PublicationCandidate] {
        calendarCandidates(
            recipe: .calendarSeason,
            days: days,
            today: today,
            boundRevisionCounts: boundRevisionCounts,
            now: now,
            calendar: calendar
        )
    }

    static func calendarYears(
        days: [BookDay],
        today: BookDay? = nil,
        boundRevisionCounts: [PublicationPeriodID: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PublicationCandidate] {
        calendarCandidates(
            recipe: .calendarYear,
            days: days,
            today: today,
            boundRevisionCounts: boundRevisionCounts,
            now: now,
            calendar: calendar
        )
    }

    /// The actual dispatch clock for a prepaid Bound Year. The fourth dispatch
    /// covers the whole twelve-month membership year; it is not mistaken for a
    /// three-month calendar season simply because both end on the same day.
    static func boundYearVolumes(
        membership: BoundYearMembership,
        days: [BookDay],
        today: BookDay? = nil,
        boundRevisionCounts: [PublicationPeriodID: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PublicationCandidate] {
        let archive = normalizedDays(days, today: today)
        var periods: [PublicationPeriod] = []

        for index in 0..<(BoundYearCycle.seasonsPerYear * 100) {
            guard let window = BoundYearCycle.seasonWindow(index, membership: membership, calendar: calendar) else {
                continue
            }
            guard window.start <= now else { break }
            guard BoundYearCycle.seasonIsEarned(
                index,
                membership: membership,
                calendar: calendar
            ) else { continue }
            guard let end = calendar.date(byAdding: .second, value: 1, to: window.end) else { continue }

            let isAnnual = BoundYearCycle.isAnnualVolume(index)
            let start: Date
            if isAnnual,
               let firstSeason = BoundYearCycle.seasonWindow(
                   index - (BoundYearCycle.seasonsPerYear - 1),
                   membership: membership,
                   calendar: calendar
               ) {
                start = firstSeason.start
            } else {
                start = window.start
            }
            periods.append(makePeriod(
                recipe: isAnnual ? .boundYearAnnual : .boundYearSeason,
                start: start,
                end: end,
                ordinal: index + 1,
                calendar: calendar
            ))
        }

        return periods.reversed().map { period in
            candidate(
                for: period,
                archive: archive,
                boundRevisionCounts: boundRevisionCounts,
                now: now,
                calendar: calendar
            )
        }
    }

    static func period(
        recipe: PublicationPeriodRecipe,
        startDate: Date,
        endDate: Date,
        ordinal: Int? = nil,
        calendar: Calendar = .current
    ) -> PublicationPeriod {
        makePeriod(
            recipe: recipe,
            start: startDate,
            end: endDate,
            ordinal: ordinal,
            calendar: calendar
        )
    }

    private static func calendarCandidates(
        recipe: PublicationPeriodRecipe,
        days: [BookDay],
        today: BookDay?,
        boundRevisionCounts: [PublicationPeriodID: Int],
        now: Date,
        calendar: Calendar
    ) -> [PublicationCandidate] {
        let archive = normalizedDays(days, today: today)
        // Every candidate re-reads the archive for its period and curates what
        // it finds, once per period since the reader began. The Glow menu asks
        // for months, seasons and years while it is on screen, so this ran
        // several times over on every pass of the menu's body. The answer only
        // moves when the archive does, when a binding is made, or when the day
        // turns.
        let salt = [
            recipe.rawValue,
            "day:\(Int(calendar.startOfDay(for: now).timeIntervalSince1970))",
            boundRevisionSalt(boundRevisionCounts)
        ].joined(separator: "|")
        return ArchiveMemo.value(
            "publication.calendar-candidates",
            days: archive,
            salt: salt,
            compute: {
                gatheredCalendarCandidates(
                    recipe: recipe,
                    archive: archive,
                    boundRevisionCounts: boundRevisionCounts,
                    now: now,
                    calendar: calendar
                )
            }
        )
    }

    private static func gatheredCalendarCandidates(
        recipe: PublicationPeriodRecipe,
        archive: [BookDay],
        boundRevisionCounts: [PublicationPeriodID: Int],
        now: Date,
        calendar: Calendar
    ) -> [PublicationCandidate] {
        guard let first = firstMaterialDate(in: archive) else { return [] }
        let firstStart = calendarStart(containing: first, recipe: recipe, calendar: calendar)
        let currentStart = calendarStart(containing: now, recipe: recipe, calendar: calendar)

        var periods: [PublicationPeriod] = []
        var cursor = firstStart
        var ordinal = 1
        while cursor <= currentStart, periods.count < 1_200 {
            guard let end = nextCalendarBoundary(after: cursor, recipe: recipe, calendar: calendar) else { break }
            periods.append(makePeriod(
                recipe: recipe,
                start: cursor,
                end: end,
                ordinal: ordinal,
                calendar: calendar
            ))
            cursor = end
            ordinal += 1
        }

        return periods.reversed().map { period in
            candidate(
                for: period,
                archive: archive,
                boundRevisionCounts: boundRevisionCounts,
                now: now,
                calendar: calendar
            )
        }
    }

    private static func candidate(
        for period: PublicationPeriod,
        archive: [BookDay],
        boundRevisionCounts: [PublicationPeriodID: Int],
        now: Date,
        calendar: Calendar
    ) -> PublicationCandidate {
        let pages: [BookPage]
        if period.recipe == .readerWeek {
            pages = archive
                .flatMap(\.pages)
                .filter { page in
                    page.type != .bookOfYou
                        && period.contains(page.createdAt)
                        && !isBoundPublicationArtifact(page)
                }
        } else {
            pages = archive
                .filter { day in
                    let dayStart = calendar.startOfDay(for: day.date)
                    return dayStart >= period.startDate && dayStart < period.endDate
                }
                .flatMap(\.pages)
                .filter { $0.type != .bookOfYou && !isBoundPublicationArtifact($0) }
        }
        let curatedCount = EditionCurator.curate(pages, now: min(now, period.endDate)).keptCount
        let status: PublicationMaterialStatus
        if !period.isClosed(at: now) {
            status = .gathering
        } else if curatedCount == 0 {
            status = .empty
        } else if curatedCount < period.recipe.recommendationMinimum {
            status = .quiet
        } else {
            status = .ready
        }
        return PublicationCandidate(
            period: period,
            eligiblePageCount: curatedCount,
            boundRevisionCount: boundRevisionCounts[period.id, default: 0],
            materialStatus: status
        )
    }

    private static func makePeriod(
        recipe: PublicationPeriodRecipe,
        start: Date,
        end: Date,
        ordinal: Int?,
        calendar: Calendar
    ) -> PublicationPeriod {
        let start = calendar.startOfDay(for: start)
        let finalInstant = end.addingTimeInterval(-1)
        return PublicationPeriod(
            id: PublicationPeriodID(
                recipe: recipe,
                startDayID: BookDay.id(for: start, calendar: calendar),
                endDayID: BookDay.id(for: finalInstant, calendar: calendar)
            ),
            startDate: start,
            endDate: end,
            ordinal: ordinal
        )
    }

    private static func calendarStart(
        containing date: Date,
        recipe: PublicationPeriodRecipe,
        calendar: Calendar
    ) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1
        let month = components.month ?? 1
        switch recipe {
        case .calendarMonth:
            return calendar.date(from: DateComponents(year: year, month: month, day: 1))
                ?? calendar.startOfDay(for: date)
        case .calendarSeason:
            let firstMonth = ((month - 1) / 3) * 3 + 1
            return calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1))
                ?? calendar.startOfDay(for: date)
        case .calendarYear:
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
                ?? calendar.startOfDay(for: date)
        case .readerWeek, .boundYearSeason, .boundYearAnnual:
            return calendar.startOfDay(for: date)
        }
    }

    private static func nextCalendarBoundary(
        after start: Date,
        recipe: PublicationPeriodRecipe,
        calendar: Calendar
    ) -> Date? {
        switch recipe {
        case .calendarMonth:
            return calendar.date(byAdding: .month, value: 1, to: start)
        case .calendarSeason:
            return calendar.date(byAdding: .month, value: 3, to: start)
        case .calendarYear:
            return calendar.date(byAdding: .year, value: 1, to: start)
        case .readerWeek, .boundYearSeason, .boundYearAnnual:
            return nil
        }
    }

    /// Every binding the reader has made, exactly — not a count and a sum.
    ///
    /// A memo key has to *determine* its value. Keying on how many bindings
    /// exist lets two different sets of bindings share an answer, and a Book
    /// that hands one reader's month another's is worse than a slow one.
    private static func boundRevisionSalt(_ counts: [PublicationPeriodID: Int]) -> String {
        counts
            .map { "\($0.key.rawValue)=\($0.value)" }
            .sorted()
            .joined(separator: ",")
    }

    private static func normalizedDays(_ days: [BookDay], today: BookDay?) -> [BookDay] {
        var byID: [String: BookDay] = [:]
        for day in days { byID[day.id] = day }
        if let today { byID[today.id] = today }
        return byID.values.sorted { $0.date < $1.date }
    }

    private static func firstMaterialDate(in days: [BookDay]) -> Date? {
        days.flatMap(\.pages)
            .filter { !isBoundPublicationArtifact($0) && publicationPageHasMaterial($0) }
            .map(\.createdAt)
            .min()
    }

    private static func isBoundPublicationArtifact(_ page: BookPage) -> Bool {
        page.weeklyIssueArtifact != nil
            || page.monthlyEditionArtifact != nil
            || page.annualEditionArtifact != nil
            || page.sourceID == "weekly-issue"
            || page.sourceID == "monthly-edition"
            || page.sourceID == "annual-edition"
    }
}
