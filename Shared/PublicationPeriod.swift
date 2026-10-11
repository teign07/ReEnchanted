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

// MARK: - Mentioning paper

/// When the Book brings up a printed edition, and what it says.
///
/// Every mention is attached to something the reader was just handed for free
/// (an issue, a month, a season, a year), so it reads as the Book wanting to
/// be a real object, never as a gate. The single edition is always the first
/// thing offered; the Bound Year is the second sentence, not the headline.
/// Weeklies and months stay small. Seasons and years are the big moments, and
/// a year outranks the season that closes with it so the reader is never
/// asked twice in the same week.
enum EditionOfferPolicy {
    /// Days after a season closes that the Book still brings it up.
    static let seasonWindowDays = 10
    /// Days after a year closes. Longer: January is when people look back.
    static let annualWindowDays = 21
    /// A season shorter than this is a few weeks of a reader who just began.
    static let seasonMinimumPages = 24
    /// A year shorter than this is a season with a bigger name.
    static let annualMinimumPages = 80

    struct Offer: Equatable {
        var cadence: PublicationEditionKind
        var candidate: PublicationCandidate
        /// "October to December" or "2026".
        var label: String
        var pageCount: Int
        /// The first instant the Book may mention it.
        var opensAt: Date

        var periodRawValue: String { candidate.period.id.rawValue }
    }

    /// The closed season or year worth talking about today, if there is one.
    /// A year wins over the season that closes with it.
    static func current(
        days: [BookDay],
        today: BookDay? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Offer? {
        annual(days: days, today: today, now: now, calendar: calendar)
            ?? season(days: days, today: today, now: now, calendar: calendar)
    }

    static func season(
        days: [BookDay],
        today: BookDay? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Offer? {
        let candidates = PublicationPeriodCatalog.calendarSeasons(
            days: days, today: today, now: now, calendar: calendar
        )
        guard let candidate = latestInWindow(
            candidates,
            windowDays: seasonWindowDays,
            minimumPages: seasonMinimumPages,
            now: now,
            calendar: calendar
        ) else { return nil }
        // The year closes with its last season. When the year is itself
        // worth mentioning, it does the talking.
        if let year = annual(days: days, today: today, now: now, calendar: calendar),
           year.candidate.period.endDate == candidate.period.endDate {
            return nil
        }
        let last = calendar.date(byAdding: .second, value: -1, to: candidate.period.endDate)
            ?? candidate.period.endDate
        return Offer(
            cadence: .seasonal,
            candidate: candidate,
            label: "\(monthName(candidate.period.startDate, calendar: calendar)) to \(monthName(last, calendar: calendar))",
            pageCount: candidate.eligiblePageCount,
            opensAt: candidate.period.endDate
        )
    }

    static func annual(
        days: [BookDay],
        today: BookDay? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Offer? {
        let candidates = PublicationPeriodCatalog.calendarYears(
            days: days, today: today, now: now, calendar: calendar
        )
        guard let candidate = latestInWindow(
            candidates,
            windowDays: annualWindowDays,
            minimumPages: annualMinimumPages,
            now: now,
            calendar: calendar
        ) else { return nil }
        return Offer(
            cadence: .annual,
            candidate: candidate,
            label: "\(calendar.component(.year, from: candidate.period.startDate))",
            pageCount: candidate.eligiblePageCount,
            opensAt: candidate.period.endDate
        )
    }

    /// Whether the month-close Page should step aside because a season or a
    /// year closed with that month and has its own, bigger, Page.
    static func monthStepsAside(
        days: [BookDay],
        today: BookDay? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        current(days: days, today: today, now: now, calendar: calendar) != nil
    }

    private static func latestInWindow(
        _ candidates: [PublicationCandidate],
        windowDays: Int,
        minimumPages: Int,
        now: Date,
        calendar: Calendar
    ) -> PublicationCandidate? {
        candidates
            .filter { candidate in
                guard candidate.isCompleted,
                      candidate.eligiblePageCount >= minimumPages,
                      let close = calendar.date(
                        byAdding: .day, value: windowDays, to: candidate.period.endDate
                      ) else { return false }
                return now >= candidate.period.endDate && now < close
            }
            .max { $0.period.endDate < $1.period.endDate }
    }

    private static func monthName(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
}

/// What the Book says. Held to the Book's voice: contractions, short, an
/// object that wants things. The Book has no hands, so the press and the
/// Bindery do the making. Prices are the Bound Year's own constants, so the
/// words can't drift from the till.
enum EditionOfferCopy {
    static func seasonHeadline(label: String) -> String {
        "\(label) Wants a Spine"
    }

    static func seasonBody(label: String, pageCount: Int, isMember: Bool) -> String {
        let finished = """
        \(label) is finished. That's \(pageCount) pages across three months: the weather you wrote down, the small things that kept turning up, the days you almost let go.

        I'd like to be a real book for this one. Paper you can write on, a spine, your name on it. It's the biggest I get short of the whole year.
        """
        if isMember {
            return finished + "\n\nThe Bound Year's already posting you the books it owes. If you want this one as an extra, or for somebody else, the Bindery will print it."
        }
        return finished + """


        You can order just this one. Or start the Bound Year and I'll post you four a year without being asked: three seasons and a hardcover to close the year. It counts from the first of the month you join, so the sooner you start, the more of your year goes in. \(BoundYearPricing.annualDisplayPrice) a year, or \(BoundYearPricing.monthlyDisplayPrice) a month. \(boundYearWelcomeLine)
        """
    }

    static func annualHeadline(label: String) -> String {
        "\(label) Wants Real Boards"
    }

    static func annualBody(label: String, pageCount: Int, isMember: Bool) -> String {
        let finished = """
        \(label) is finished, and it's \(pageCount) pages thick. A whole year of you, in order, from the first thing you kept to the last.

        This is the one I most want to be real. Hardcover, sewn, the year on the spine. It'd sit on a shelf as if it had always lived there.
        """
        if isMember {
            return finished + "\n\nYour Bound Year's hardcover comes in its own time. If you want this calendar year as well, or one for somebody else, the Bindery will print it."
        }
        return finished + """


        Order just \(label) if that's all you want. Or start a Bound Year and I'll post you the next four: three seasons, then the hardcover. \(BoundYearPricing.annualDisplayPrice) for the year, or \(BoundYearPricing.monthlyDisplayPrice) a month. \(boundYearWelcomeLine)
        """
    }

    /// Appended to the month-close Page. The month stays the headline.
    static func monthlyAddendum(joinMonth: String, isMember: Bool) -> String {
        if isMember {
            return "\n\nWant it on paper too? The press will print it. It's yours either way."
        }
        return "\n\nWant it on paper? The press will print it. Or start the Bound Year instead: four books a year, counted from the first of the month you join, so \(joinMonth) would go in the first one. \(BoundYearPricing.monthlyDisplayPrice) a month or \(BoundYearPricing.annualDisplayPrice) a year. \(boundYearWelcomeLine)"
    }

    /// The Bound Year's welcome, said wherever the Book pitches it.
    static let boundYearWelcomeLine = "And your first full week comes bound and posted, on me."

    /// The one line on the desk when the welcome weekly goes to the press.
    static let welcomeWeeklyDeskLine = "Your first week's on its way to you, bound. The staples are very proud of themselves."

    /// The weekly Page's closing paragraph: the month as a book in progress.
    /// Small on purpose. It sells nothing; it makes the month visible.
    static func weeklySpineLine(monthName: String, monthPageCount: Int) -> String {
        "\(monthName)'s book is \(monthPageCount) \(monthPageCount == 1 ? "page" : "pages") thick so far. It closes on the 1st, and then it can be paper."
    }

    /// The quiet line under a single order. A door, not a banner.
    static func asideLine(for cadence: PublicationEditionKind) -> String {
        switch cadence {
        case .weekly:
            return "Four books a year instead of one at a time? The Bound Year starts at \(BoundYearPricing.monthlyDisplayPrice) a month, and your first full week comes posted, on me."
        case .monthly:
            return "Rather not do this every month? The Bound Year posts four books a year, from \(BoundYearPricing.monthlyDisplayPrice) a month."
        case .seasonal:
            return "Want the next three seasons posted without asking? That's the Bound Year, \(BoundYearPricing.annualDisplayPrice) a year."
        case .annual, .special:
            return "Want next year's four books posted without asking? That's the Bound Year, \(BoundYearPricing.annualDisplayPrice) a year."
        }
    }
}

extension PublicationPeriodID {
    /// The inverse of `rawValue`, so a Page can carry a period in its
    /// metadata and the app can find it again.
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let recipe = PublicationPeriodRecipe(rawValue: parts[0]) else { return nil }
        self.init(recipe: recipe, startDayID: parts[1], endDayID: parts[2])
    }
}

// MARK: - The welcome weekly

/// Every new Bound Year member gets their first full week bound and posted,
/// free: one saddle-stitched Tale of Your Week, once per membership. The
/// Worker holds the real claim and refuses a second; this is the Book's own
/// note of where it's got to, so it waits for the right week, retries quietly
/// and says so on the desk exactly once.
struct BoundYearWelcomeWeekly: Codable, Equatable {
    /// The Worker's parcel slot beside the seasonal `yyyy-Smm` keys.
    static let slotKey = "welcome-weekly"

    var membershipID: String
    /// When this Book first saw the membership. Only a reader week starting
    /// on or after this day counts as the first full week.
    var joinedAt: Date
    /// The week that went, frozen once the press took it.
    var periodID: String?
    var postedAt: Date?
    var luluPrintJobID: String?
    /// When the Book said so on the desk. Nil on a posted welcome means the
    /// line's still owed.
    var announcedAt: Date?
    var lastAttemptAt: Date?
    var failedAttempts: Int?

    var hasPosted: Bool { postedAt != nil }
    var owesAnnouncement: Bool { hasPosted && announcedAt == nil }

    /// The record to keep for this membership: the existing one, or a fresh
    /// one the first time the Book sees a current membership. A new
    /// membership id is a new member's welcome; nil means nothing to track.
    static func tracking(
        _ existing: BoundYearWelcomeWeekly?,
        membershipID: String?,
        membership: BoundYearMembership?,
        now: Date
    ) -> BoundYearWelcomeWeekly? {
        guard let membershipID, let membership else { return existing }
        if let existing, existing.membershipID == membershipID { return existing }
        guard membership.isCurrent else { return existing }
        return BoundYearWelcomeWeekly(membershipID: membershipID, joinedAt: now)
    }

    /// The Worker says the welcome's already at the press. Mark it posted;
    /// only a Book that tried to send it itself still owes the desk line,
    /// since another device will have said it already.
    mutating func adoptServerClaim(luluPrintJobID: String?, at now: Date) {
        guard !hasPosted else { return }
        postedAt = now
        self.luluPrintJobID = luluPrintJobID ?? self.luluPrintJobID
        failedAttempts = 0
        if lastAttemptAt == nil { announcedAt = now }
    }
}

/// When the welcome weekly goes, and which week it is.
enum WelcomeWeeklyPolicy {
    /// A week with fewer kept days than this is too thin to be the first
    /// thing a member holds. The Book waits for the next one.
    static let minimumKeptDays = 3
    /// How many first weeks it waits through before sending the fullest of
    /// them anyway. The welcome is owed; it never quietly lapses.
    static let weeksToWait = 4

    /// One reader week, as the policy needs to see it.
    struct WeekTally: Equatable {
        var period: PublicationPeriod
        /// Distinct days in the week with at least one kept page in them.
        var keptDays: Int
        /// Pages the issue would actually bind.
        var eligiblePageCount: Int
    }

    enum Decision: Equatable {
        /// Already at the press. Nothing more to do.
        case posted
        /// Not yet: no qualifying week has closed, the membership isn't
        /// current, or a failed attempt is still resting.
        case wait
        case send(PublicationPeriod)
    }

    /// Quiet retries: an hour, then six, then a day at most between tries.
    /// No failure is ever shown to the reader; the present just arrives late.
    static func retryDelay(afterFailures failures: Int) -> TimeInterval {
        switch failures {
        // An attempt is under way, or the app closed in the middle of one.
        case ..<1: return 600
        case 1: return 3_600
        case 2: return 6 * 3_600
        default: return 24 * 3_600
        }
    }

    static func decide(
        welcome: BoundYearWelcomeWeekly,
        membership: BoundYearMembership,
        weeks: [WeekTally],
        now: Date,
        calendar: Calendar = .current
    ) -> Decision {
        if welcome.hasPosted { return .posted }
        guard membership.isCurrent, membership.digitalPaymentVerified != false else { return .wait }
        if let last = welcome.lastAttemptAt,
           now < last.addingTimeInterval(retryDelay(afterFailures: welcome.failedAttempts ?? 0)) {
            return .wait
        }
        let joinedDay = calendar.startOfDay(for: welcome.joinedAt)
        let afterJoining = weeks
            .filter { $0.period.startDate >= joinedDay }
            .sorted { $0.period.startDate < $1.period.startDate }
        let printable = { (week: WeekTally) in week.eligiblePageCount >= WeeklyIssue.minimumIssuePages }

        let firstWeeks = afterJoining.prefix(weeksToWait)
        for week in firstWeeks {
            guard week.period.isClosed(at: now) else { return .wait }
            if week.keptDays >= minimumKeptDays && printable(week) { return .send(week.period) }
        }
        guard firstWeeks.count == weeksToWait else { return .wait }
        // Four thin weeks. Send the fullest of them rather than make a new
        // member keep earning their own present.
        if let fullest = firstWeeks
            .filter({ $0.keptDays > 0 && printable($0) })
            .max(by: { ($0.keptDays, $1.period.startDate) < ($1.keptDays, $0.period.startDate) }) {
            return .send(fullest.period)
        }
        // Nothing at all to bind yet. The first later week with anything in it.
        for week in afterJoining.dropFirst(weeksToWait) {
            guard week.period.isClosed(at: now) else { return .wait }
            if week.keptDays > 0 && printable(week) { return .send(week.period) }
        }
        return .wait
    }
}

extension PublicationPeriodCatalog {
    /// Reader weeks as the welcome policy counts them: kept days, not pages,
    /// so one busy evening can't pass for a lived-in week.
    static func welcomeWeeklyTallies(
        candidates: [PublicationCandidate],
        days: [BookDay],
        today: BookDay? = nil,
        calendar: Calendar = .current
    ) -> [WelcomeWeeklyPolicy.WeekTally] {
        let material = normalizedDays(days, today: today)
            .flatMap(\.pages)
            .filter { !isBoundPublicationArtifact($0) && publicationPageHasMaterial($0) }
        return candidates
            .filter { $0.period.recipe == .readerWeek }
            .map { candidate in
                let keptDays = Set(material
                    .filter { candidate.period.contains($0.createdAt) }
                    .map { calendar.startOfDay(for: $0.createdAt) })
                return WelcomeWeeklyPolicy.WeekTally(
                    period: candidate.period,
                    keptDays: keptDays.count,
                    eligiblePageCount: candidate.eligiblePageCount
                )
            }
    }
}
