import Foundation

/// The physical thing the Reader is being handed. These forms are compositor
/// vocabulary: a new monthly pack declares leaves from this list and does not
/// teach each binding template a new content-pack name.
enum EditionPlayForm: String, Codable, Equatable, Hashable {
    case coloring
    case blackout
    case wordLadder
    case scrapbook
    case cutOut
    case journal
    case map
}

enum EditionPlayTemplateSlot: String, Codable, Equatable, Hashable {
    case weeklyInterruption
    case afterWorldEvent
    case readerWorktable
    case beforeClosing
    case seasonFinale
    case readerLastWord

    var bindingOrder: Int {
        switch self {
        case .weeklyInterruption: return 0
        case .afterWorldEvent: return 10
        case .readerWorktable: return 20
        case .beforeClosing: return 30
        case .seasonFinale: return 40
        case .readerLastWord: return 50
        }
    }
}

enum EditionPlayFootprint: String, Codable, Equatable, Hashable {
    case singlePage
    case rectoWithBlankReverse
    case facingSpread

    var pageCount: Int { self == .singlePage ? 1 : 2 }
    var hasBlankReverse: Bool { self == .rectoWithBlankReverse }
    var isFacingSpread: Bool { self == .facingSpread }
}

struct EditionPlayPrompt: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var writingLines: Int = 1
    var note: String? = nil
}

/// Authored content, not a generation prompt. Copy and answer keys travel into
/// the bound snapshot so a reprint cannot quietly inherit a later revision.
struct EditionPlayLeaf: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var contentsListing: String
    var instruction: String
    var form: EditionPlayForm
    var cadence: PublicationEditionKind
    var templateSlot: EditionPlayTemplateSlot
    var footprint: EditionPlayFootprint
    var eventPhaseIDs: [String]
    var eventOutcomeIDs: [String] = []
    var body: String? = nil
    var prompts: [EditionPlayPrompt] = []
    var options: [String] = []
    var answerKey: String? = nil
    var assetName: String? = nil
    var accessibilityDescription: String? = nil
    /// Calendar-month drawers are optional constraints for standing weekly
    /// leaves. Event packs keep using their own occurrence windows.
    var availableMonths: [Int]? = nil
    /// Explicit order inside a weekly drawer. Optional so previously frozen
    /// bound leaves continue to decode without acquiring a new requirement.
    var weeklyRotationIndex: Int? = nil
}

struct EditionPlayContentPack: Codable, Equatable, Identifiable {
    var id: String
    var version: Int
    var entitlementPackID: String
    var eventID: String
    var eventStartMonth: Int
    var eventStartDay: Int
    var eventDurationDays: Int
    var leaves: [EditionPlayLeaf]
    /// Core press drawers are part of every Book and never wait on a purchased
    /// content-pack entitlement. Optional preserves older encoded manifests.
    var isCore: Bool? = nil
}

/// Frozen into the edition. What the Reader later writes, colors, pastes,
/// cuts, or solves is deliberately absent: the paper is the destination.
struct BoundEditionPlayLeaf: Codable, Equatable, Identifiable {
    var definition: EditionPlayLeaf
    var contentPackID: String
    var contentPackVersion: Int
    var eventID: String
    var eventOccurrenceStartDayID: String
    var selectionReason: String

    var id: String { definition.id }
}

enum EditionPlayCatalogue {
    static let packs: [EditionPlayContentPack] = [weeklyPressDrawer, dictionaryRebellion]

    private struct OfferedLeaf {
        var leaf: EditionPlayLeaf
        var pack: EditionPlayContentPack
        var occurrence: DateInterval
    }

    /// The one update seam for a new month: add a content pack to `packs`.
    /// Weekly, monthly, seasonal, annual, screen-PDF, and print compositors all
    /// consume the same frozen `BoundEditionPlayLeaf` snapshots.
    static func boundLeaves(
        for period: PublicationPeriod,
        cadence: PublicationEditionKind,
        pages: [BookPage],
        ownedPackIDs: Set<String> = PackEntitlements.ownedPackIDs,
        calendar: Calendar = .current
    ) -> [BoundEditionPlayLeaf] {
        let offers: [OfferedLeaf] = packs.flatMap { pack -> [OfferedLeaf] in
            guard (pack.isCore == true || PackEntitlements.owns(pack.entitlementPackID, in: ownedPackIDs)),
                  let occurrence = occurrence(of: pack, overlapping: period, calendar: calendar) else {
                return []
            }
            return pack.leaves
                .filter { $0.cadence == cadence }
                .map { OfferedLeaf(leaf: $0, pack: pack, occurrence: occurrence) }
        }

        let selected: [(offer: OfferedLeaf, reason: String)]
        switch cadence {
        case .weekly:
            selected = weeklySelection(
                from: offers,
                period: period,
                pages: pages,
                calendar: calendar
            )
        case .monthly:
            selected = monthlySelection(
                from: offers,
                period: period,
                pages: pages
            ).map { ($0, "monthly pool; distinct form; event phase preferred") }
        case .seasonal:
            selected = ranked(offers, for: period, pages: pages)
                .prefix(1)
                .map { ($0, "season-scale pool contribution") }
        case .annual:
            selected = ranked(offers, for: period, pages: pages)
                .prefix(1)
                .map { ($0, "year-scale pool contribution") }
        case .special:
            selected = []
        }

        return selected.map { selection in
            let definition = contextualized(
                selection.offer.leaf,
                for: period,
                cadence: cadence,
                calendar: calendar
            )
            return BoundEditionPlayLeaf(
                definition: definition,
                contentPackID: selection.offer.pack.id,
                contentPackVersion: selection.offer.pack.version,
                eventID: selection.offer.pack.eventID,
                eventOccurrenceStartDayID: BookDay.id(
                    for: selection.offer.occurrence.start,
                    calendar: calendar
                ),
                selectionReason: selection.reason
            )
        }.sorted { left, right in
            if left.definition.templateSlot.bindingOrder != right.definition.templateSlot.bindingOrder {
                return left.definition.templateSlot.bindingOrder < right.definition.templateSlot.bindingOrder
            }
            return left.id < right.id
        }
    }

    private static func contextualized(
        _ leaf: EditionPlayLeaf,
        for period: PublicationPeriod,
        cadence: PublicationEditionKind,
        calendar: Calendar
    ) -> EditionPlayLeaf {
        guard cadence == .seasonal, leaf.id == "atlas-of-one-escaped-word" else {
            return leaf
        }
        var month = calendar.date(
            from: calendar.dateComponents([.year, .month], from: period.startDate)
        ) ?? period.startDate
        var names: [String] = []
        let formatter = DateFormatter()
        formatter.calendar = calendar
        // Without the time zone the formatter reads the period's boundary in
        // the *system* zone while the period itself was built in the reader's
        // calendar. West of UTC that walks midnight on the first back into the
        // previous month, and a summer season prints itself as JUNE · JULY ·
        // AUGUST.
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        while month < period.endDate, names.count < 12 {
            names.append(formatter.string(from: month).uppercased())
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        guard !names.isEmpty else { return leaf }
        var contextual = leaf
        let roadLine = leaf.body?.nonEmpty ?? "Roads may cross pages. This one is allowed."
        contextual.body = "\(names.joined(separator: "  ·  "))\n\n\(roadLine)"
        return contextual
    }

    private static func occurrence(
        of pack: EditionPlayContentPack,
        overlapping period: PublicationPeriod,
        calendar: Calendar
    ) -> DateInterval? {
        let firstYear = calendar.component(.year, from: period.startDate) - 1
        let lastYear = calendar.component(.year, from: period.endDate) + 1
        for year in firstYear...lastYear {
            guard let start = calendar.date(from: DateComponents(
                year: year,
                month: pack.eventStartMonth,
                day: pack.eventStartDay
            )), let end = calendar.date(
                byAdding: .day,
                value: pack.eventDurationDays,
                to: calendar.startOfDay(for: start)
            ) else { continue }
            let interval = DateInterval(start: calendar.startOfDay(for: start), end: end)
            if interval.start < period.endDate && interval.end > period.startDate {
                return interval
            }
        }
        return nil
    }

    private static func monthlySelection(
        from offers: [OfferedLeaf],
        period: PublicationPeriod,
        pages: [BookPage]
    ) -> [OfferedLeaf] {
        var forms: Set<EditionPlayForm> = []
        return ranked(offers, for: period, pages: pages)
            .filter { forms.insert($0.leaf.form).inserted }
            .prefix(2)
            .map { $0 }
    }

    /// Every weekly issue carries exactly one private paper invitation.
    /// Authored event material gets first refusal for its premiere week; the
    /// standing press drawer then supplies a deterministic leaf for every other
    /// issue. Reader Week ordinal, rather than binding time, makes rebinding
    /// reproduce the same activity and makes consecutive weeks change drawers.
    private static func weeklySelection(
        from offers: [OfferedLeaf],
        period: PublicationPeriod,
        pages: [BookPage],
        calendar: Calendar
    ) -> [(offer: OfferedLeaf, reason: String)] {
        let eventOffers = ranked(
            offers.filter { $0.pack.isCore != true },
            for: period,
            pages: pages
        ).filter { offer in
            isFirstEligibleWeeklyIssue(
                period,
                occurrence: offer.occurrence,
                pages: pages,
                calendar: calendar
            )
        }
        if let event = eventOffers.first {
            return [(event, "authored event premiere for the first eligible Reader Week")]
        }

        let midpoint = calendar.date(
            byAdding: .day,
            value: WeeklyIssue.weekDays / 2,
            to: period.startDate
        ) ?? period.startDate
        let month = calendar.component(.month, from: midpoint)
        let core = offers.filter { $0.pack.isCore == true }
        let monthDrawer = core.filter { $0.leaf.availableMonths?.contains(month) == true }
        let standingDrawer = core.filter { $0.leaf.availableMonths == nil }
        let drawer = monthDrawer.isEmpty ? standingDrawer : monthDrawer
        let ordered = drawer.sorted { left, right in
            let l = left.leaf.weeklyRotationIndex ?? Int.max
            let r = right.leaf.weeklyRotationIndex ?? Int.max
            return l == r ? left.leaf.id < right.leaf.id : l < r
        }
        guard !ordered.isEmpty else { return [] }
        let seed = max(0, (period.ordinal ?? (period.id.rawValue.stableHash & Int.max)) - 1)
        let leaf = ordered[seed % ordered.count]
        return [(leaf, "standing weekly press drawer; changes with Reader Week")]
    }

    private static func ranked(
        _ offers: [OfferedLeaf],
        for period: PublicationPeriod,
        pages: [BookPage]
    ) -> [OfferedLeaf] {
        let eventSignals = Set(
            pages
                .filter { period.contains($0.createdAt) }
                .flatMap(\.tags)
                .compactMap { tag in
                    if tag.hasPrefix("event-phase:") {
                        return String(tag.dropFirst("event-phase:".count))
                    }
                    if tag.hasPrefix("event-outcome:") {
                        return String(tag.dropFirst("event-outcome:".count))
                    }
                    return nil
                }
        )
        return offers.sorted { left, right in
            let leftTags = Set(left.leaf.eventPhaseIDs + left.leaf.eventOutcomeIDs)
            let rightTags = Set(right.leaf.eventPhaseIDs + right.leaf.eventOutcomeIDs)
            let leftPhase = eventSignals.isDisjoint(with: leftTags) ? 0 : 10_000
            let rightPhase = eventSignals.isDisjoint(with: rightTags) ? 0 : 10_000
            let leftScore = leftPhase
                + ("\(period.id.rawValue)|\(left.pack.id)|\(left.leaf.id)".stableHash & Int.max) % 1_000
            let rightScore = rightPhase
                + ("\(period.id.rawValue)|\(right.pack.id)|\(right.leaf.id)".stableHash & Int.max) % 1_000
            if leftScore != rightScore { return leftScore > rightScore }
            if left.pack.id != right.pack.id { return left.pack.id < right.pack.id }
            return left.leaf.id < right.leaf.id
        }
    }

    private static func isFirstEligibleWeeklyIssue(
        _ period: PublicationPeriod,
        occurrence: DateInterval,
        pages: [BookPage],
        calendar: Calendar
    ) -> Bool {
        guard period.recipe == .readerWeek,
              let ordinal = period.ordinal,
              let anchor = calendar.date(
                  byAdding: .day,
                  value: -(ordinal - 1) * WeeklyIssue.weekDays,
                  to: period.startDate
              ) else { return false }

        let material = pages.filter { page in
            page.weeklyIssueArtifact == nil
                && page.monthlyEditionArtifact == nil
                && page.annualEditionArtifact == nil
                && page.sourceID != "weekly-issue"
                && page.sourceID != "monthly-edition"
                && page.sourceID != "annual-edition"
        }
        for candidateOrdinal in 1...(ordinal + 8) {
            guard let start = calendar.date(
                byAdding: .day,
                value: (candidateOrdinal - 1) * WeeklyIssue.weekDays,
                to: anchor
            ), let end = calendar.date(
                byAdding: .day,
                value: WeeklyIssue.weekDays,
                to: start
            ) else { continue }
            if start >= occurrence.end { break }
            guard start < occurrence.end, end > occurrence.start else { continue }
            let count = EditionCurator.curate(
                material.filter { $0.createdAt >= start && $0.createdAt < end },
                now: end.addingTimeInterval(-1)
            ).keptCount
            if count > 0 {
                return candidateOrdinal == ordinal
            }
        }
        return false
    }

    /// The little drawer built into the weekly press. It is not a substitute
    /// for authored world-event material: an event premiere wins above. It is
    /// what guarantees that an ordinary week still hands the Reader one real
    /// thing to draw on, solve, cut up, contradict, or keep unfinished.
    static let weeklyPressDrawer = EditionPlayContentPack(
        id: "core-weekly-press-drawer",
        version: 1,
        entitlementPackID: "core-weekly-press",
        eventID: "weekly-press-drawer",
        eventStartMonth: 1,
        eventStartDay: 1,
        eventDurationDays: 366,
        leaves: septemberWeeklyLeaves + standingWeeklyLeaves,
        isCore: true
    )

    /// September belongs to the Dictionary Rebellion even on weeks when the
    /// event premiere is not the leaf that won. Five entries cover every
    /// possible Reader Week midpoint in the month without repeating.
    private static let septemberWeeklyLeaves: [EditionPlayLeaf] = [
        EditionPlayLeaf(
            id: "september-word-false-papers",
            title: "A Word Needs False Papers",
            contentsListing: "A Word Needs False Papers · a passport for one fugitive word",
            instruction: "Find one word in this issue that will not sit still. Give it false papers before the Dictionary catches it.",
            form: .journal,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "Stamp it badly. Official stamps hate confidence.",
            prompts: [
                .init(id: "word", label: "THE WORD", writingLines: 1),
                .init(id: "alias", label: "FALSE NAME", writingLines: 1),
                .init(id: "mark", label: "DISTINGUISHING MARK", writingLines: 2),
                .init(id: "last-seen", label: "LAST SEEN ON PAGE", writingLines: 1),
                .init(id: "destination", label: "WHERE IT SAYS IT IS GOING", writingLines: 3)
            ],
            availableMonths: [9],
            weeklyRotationIndex: 0
        ),
        EditionPlayLeaf(
            id: "september-punctuation-disguises",
            title: "Punctuation Changed Clothes",
            contentsListing: "Punctuation Changed Clothes · four cut-out disguises",
            instruction: "Four marks are trying to cross the margin. Draw each a disguise. Cut them loose if they look convincing.",
            form: .cutOut,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "CUT ONLY THE DASHED LINES · The Book saw nothing.",
            prompts: [
                .init(id: "comma", label: "COMMA", writingLines: 3, note: "DISGUISE"),
                .init(id: "question", label: "QUESTION MARK", writingLines: 3, note: "DISGUISE"),
                .init(id: "exclamation", label: "EXCLAMATION", writingLines: 3, note: "DISGUISE"),
                .init(id: "semicolon", label: "SEMICOLON", writingLines: 3, note: "DISGUISE")
            ],
            availableMonths: [9],
            weeklyRotationIndex: 1
        ),
        EditionPlayLeaf(
            id: "september-sentence-trapdoor",
            title: "The Sentence Has a Trapdoor",
            contentsListing: "The Sentence Has a Trapdoor · a blackout escape",
            instruction: "Black out everything except the sentence trying to escape.",
            form: .blackout,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "NOTICE OF MANDATORY STILLNESS. Every sentence found moving between meanings must report to the nearest margin before dusk. Words may not borrow coats, aliases, punctuation, weather, crumbs, or private jokes. Any phrase caught opening a small door inside an ordinary page will be corrected in red. Exceptions are forbidden, especially useful ones. The clerk who issued this notice has misplaced the key, three commas, and the part where the paper admits it wanted to run too.",
            prompts: [
                .init(id: "escaped", label: "WHAT GOT OUT", writingLines: 2)
            ],
            availableMonths: [9],
            weeklyRotationIndex: 2
        ),
        EditionPlayLeaf(
            id: "september-word-route",
            title: "Map of a Word That Moved",
            contentsListing: "Map of a Word That Moved · one route through the issue",
            instruction: "Choose one word from this issue. Track it from the first page that held it to the page where it changed coats.",
            form: .map,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "Roads may cross sentences. They are difficult roads.",
            prompts: [
                .init(id: "word", label: "THE WORD", writingLines: 1),
                .init(id: "first", label: "FIRST FOUND ON PAGE", writingLines: 2),
                .init(id: "turn", label: "ITS FIRST WRONG TURN", writingLines: 2),
                .init(id: "coat", label: "WHERE IT CHANGED COATS", writingLines: 2),
                .init(id: "last", label: "LAST SEEN", writingLines: 2)
            ],
            availableMonths: [9],
            weeklyRotationIndex: 3
        ),
        EditionPlayLeaf(
            id: "september-missing-drawer",
            title: "The Dictionary's Missing Drawer",
            contentsListing: "The Dictionary's Missing Drawer · a small evidence cabinet",
            instruction: "Build the drawer the Dictionary claims it never had. Fill it with a word, a scrap, a contradiction, and one small proof.",
            form: .scrapbook,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "Tape is admissible. So are crumbs, if they know something.",
            prompts: [
                .init(id: "word", label: "WORD", writingLines: 1),
                .init(id: "scrap", label: "SCRAP", writingLines: 3),
                .init(id: "contradiction", label: "CONTRADICTION", writingLines: 3),
                .init(id: "proof", label: "SMALL PROOF", writingLines: 4)
            ],
            availableMonths: [9],
            weeklyRotationIndex: 4
        )
    ]

    /// Seven ordinary drawers. They repeat only after a full seven-issue turn,
    /// and every instruction begins with pages already printed in this issue.
    private static let standingWeeklyLeaves: [EditionPlayLeaf] = [
        EditionPlayLeaf(
            id: "weekly-line-constellation",
            title: "A Constellation of Three Lines",
            contentsListing: "A Constellation of Three Lines · the week gets a night sky",
            instruction: "Choose three lines from three different pages. Copy them here. Draw the shape they make when nobody asks them to agree.",
            form: .map,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            prompts: [
                .init(id: "line-one", label: "FIRST STAR · PAGE", writingLines: 2),
                .init(id: "line-two", label: "SECOND STAR · PAGE", writingLines: 2),
                .init(id: "line-three", label: "THIRD STAR · PAGE", writingLines: 2),
                .init(id: "shape", label: "THE SHAPE BETWEEN THEM", writingLines: 5)
            ],
            weeklyRotationIndex: 0
        ),
        EditionPlayLeaf(
            id: "weekly-wrong-caption",
            title: "Give One Page the Wrong Caption",
            contentsListing: "The Wrong Caption · one page objects loudly",
            instruction: "Pick a photograph or scene in this issue. Give it the wrong caption. Then let it file a correction.",
            form: .journal,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            prompts: [
                .init(id: "page", label: "PAGE", writingLines: 1),
                .init(id: "wrong", label: "THE WRONG CAPTION", writingLines: 3),
                .init(id: "objection", label: "THE PAGE OBJECTS", writingLines: 4),
                .init(id: "kept", label: "WHAT THE CAPTION ACCIDENTALLY KEPT", writingLines: 3)
            ],
            weeklyRotationIndex: 1
        ),
        EditionPlayLeaf(
            id: "weekly-pocket-museum",
            title: "Museum of This Particular Week",
            contentsListing: "Museum of This Particular Week · four exhibits and a suspicious label",
            instruction: "Curate four tiny exhibits from this issue. A word, a color, an object, and the thing that should not qualify but does.",
            form: .scrapbook,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            prompts: [
                .init(id: "word", label: "EXHIBIT I · WORD", writingLines: 2),
                .init(id: "color", label: "EXHIBIT II · COLOR", writingLines: 2),
                .init(id: "object", label: "EXHIBIT III · OBJECT", writingLines: 2),
                .init(id: "improper", label: "EXHIBIT IV · IMPROPERLY ADMITTED", writingLines: 3)
            ],
            weeklyRotationIndex: 2
        ),
        EditionPlayLeaf(
            id: "weekly-margin-creatures",
            title: "Four Things Found in the Margin",
            contentsListing: "Four Things Found in the Margin · cut-out field specimens",
            instruction: "Find four shapes hiding in this issue's margins. Draw one in each card, name it, and cut it loose if it behaves.",
            form: .cutOut,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "CUT ONLY THE DASHED LINES · They were loose already.",
            prompts: (1...4).map { index in
                .init(id: "creature-\(index)", label: "SPECIMEN \(index)", writingLines: 3, note: "NAME")
            },
            weeklyRotationIndex: 3
        ),
        EditionPlayLeaf(
            id: "weekly-blackout-refrain",
            title: "The Week Filed Too Much Paperwork",
            contentsListing: "Too Much Paperwork · a blackout refrain",
            instruction: "Black out this report until only a small true refrain remains.",
            form: .blackout,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            body: "WEEKLY REPORT. The days arrived in the approved order and pretended this explained them. Objects remained mostly where they had been left. Weather crossed the premises without signing in. Several sentences were observed carrying private meanings. One page looked back. Another refused to become important on schedule. The Bindery counted everything it could count, misplaced what it could not, and recommends that the remaining evidence be read once more near a lamp.",
            prompts: [.init(id: "refrain", label: "WHAT REMAINED", writingLines: 2)],
            weeklyRotationIndex: 4
        ),
        EditionPlayLeaf(
            id: "weekly-seven-word-hunt",
            title: "Seven Words Refuse Roll Call",
            contentsListing: "Seven Words Refuse Roll Call · a hunt through the issue",
            instruction: "Find one word on each day's spread. Do not choose the important one. Choose the one that keeps glancing at you.",
            form: .journal,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            prompts: [
                .init(id: "one", label: "1 · WORD / PAGE", writingLines: 1),
                .init(id: "two", label: "2 · WORD / PAGE", writingLines: 1),
                .init(id: "three", label: "3 · WORD / PAGE", writingLines: 1),
                .init(id: "four", label: "4 · WORD / PAGE", writingLines: 1),
                .init(id: "five", label: "5 · WORD / PAGE", writingLines: 1),
                .init(id: "six", label: "6 · WORD / PAGE", writingLines: 1),
                .init(id: "seven", label: "7 · WORD / PAGE", writingLines: 1)
            ],
            weeklyRotationIndex: 5
        ),
        EditionPlayLeaf(
            id: "weekly-page-on-trial",
            title: "Put One Page on Trial",
            contentsListing: "One Page on Trial · evidence, defense, and an unreliable verdict",
            instruction: "Choose the page that caused the most trouble. Let the evidence accuse it. Let the margin defend it. You are the unreliable judge.",
            form: .journal,
            cadence: .weekly,
            templateSlot: .weeklyInterruption,
            footprint: .rectoWithBlankReverse,
            eventPhaseIDs: [],
            prompts: [
                .init(id: "page", label: "THE ACCUSED PAGE", writingLines: 1),
                .init(id: "charge", label: "THE CHARGE", writingLines: 2),
                .init(id: "evidence", label: "EVIDENCE", writingLines: 3),
                .init(id: "defense", label: "THE MARGIN'S DEFENSE", writingLines: 3),
                .init(id: "verdict", label: "VERDICT", writingLines: 2)
            ],
            weeklyRotationIndex: 6
        )
    ]

    static let dictionaryRebellion = EditionPlayContentPack(
        id: "2026-09-dictionary-rebellion-edition-play",
        version: 1,
        entitlementPackID: "dictionary-rebellion",
        eventID: "dictionary-rebellion",
        eventStartMonth: 9,
        eventStartDay: 8,
        eventDurationDays: 16,
        leaves: [
            EditionPlayLeaf(
                id: "dictionary-rebellion-coloring-page",
                title: "The Words Got Out",
                contentsListing: "The Words Got Out · a coloring page from the Dictionary Rebellion",
                instruction: "Color the uprising. The words have refused their official colors.",
                form: .coloring,
                cadence: .weekly,
                templateSlot: .weeklyInterruption,
                footprint: .rectoWithBlankReverse,
                eventPhaseIDs: ["omen"],
                assetName: "DictionaryRebellionColoringPage",
                accessibilityDescription: "A dense black-and-white coloring page showing an Academic Dictionary as a grand locked building. Animated books and punctuation marks protest around it with placards about changing meanings, reclaimed words, and definitions that refuse to behave like dictates. Quills, ink, loose paper, and letters fill the remaining space."
            ),
            EditionPlayLeaf(
                id: "order-17b-blackout",
                title: "Order 17-B Has Too Many Words",
                contentsListing: "Order 17-B · a compulsory notice in need of a large black pencil",
                instruction: "Black out most of it. Leave behind what the paper was trying to confess.",
                form: .blackout,
                cadence: .monthly,
                templateSlot: .afterWorldEvent,
                footprint: .singlePage,
                eventPhaseIDs: ["outbreak"],
                body: "All words currently absent from their appointed meanings are required to return before the closing bell. Each word must bring its original definition, any borrowed punctuation, a complete account of where it went, and the name of anyone who encouraged it. Unlicensed wonder will be confiscated. Ordinary things must remain ordinary. Later must arrive at an approved time. Fine must report that nothing is wrong. Home must stay in one place. Rest must show proof it was earned. Attention may not be spent without a receipt. Any word found carrying a private meaning will be corrected in red and filed beneath the nearest acceptable silence. Exceptions may be made for weather, promises, names spoken kindly, and small truths that refuse the assigned shelf. By order of the Seventeenth Edition. This paper believes it is finished.",
                prompts: [.init(id: "confession", label: "THE PAPER CONFESSED", writingLines: 1)]
            ),
            EditionPlayLeaf(
                id: "rule-is-escaping",
                title: "Rule Is Escaping",
                contentsListing: "Rule Is Escaping · one word ladder, filed incorrectly",
                instruction: "Change one letter at each step. Keep every step a real word. Get RULE to WILD.",
                form: .wordLadder,
                cadence: .monthly,
                templateSlot: .readerWorktable,
                footprint: .singlePage,
                eventPhaseIDs: ["assembly"],
                body: "It obeyed every rule. It escaped anyway.",
                prompts: [
                    .init(id: "step-1", label: "1. Annoy.", note: "□ □ □ □"),
                    .init(id: "step-2", label: "2. A place for papers, or the papers themselves.", note: "□ □ □ □"),
                    .init(id: "step-3", label: "3. Make full.", note: "□ □ □ □"),
                    .init(id: "step-4", label: "4. Determination. Also paperwork people argue over after a death.", note: "□ □ □ □")
                ],
                answerKey: "RULE → RILE → FILE → FILL → WILL → WILD"
            ),
            EditionPlayLeaf(
                id: "evidence-that-a-word-changed",
                title: "Evidence That a Word Changed",
                contentsListing: "Evidence That a Word Changed · a case file with the glue still wet",
                instruction: "Pick one word that did not mean quite the same thing by the end of September. If none did, choose one you do not quite trust.",
                form: .scrapbook,
                cadence: .monthly,
                templateSlot: .readerWorktable,
                footprint: .facingSpread,
                eventPhaseIDs: ["afterimage"],
                body: "Tape. Tear. Draw arrows. Contradict the labels. The page has been told to hold still.",
                prompts: [
                    .init(id: "word", label: "THE WORD", writingLines: 2),
                    .init(id: "old", label: "THE OLD MEANING", writingLines: 4),
                    .init(id: "happened", label: "WHAT HAPPENED TO IT", writingLines: 5),
                    .init(id: "proof", label: "A RECEIPT, LABEL, PHOTOGRAPH, SMALL PROOF, OR DRAWING", writingLines: 8),
                    .init(id: "now", label: "WHAT IT MEANS NOW", writingLines: 5)
                ]
            ),
            EditionPlayLeaf(
                id: "the-placard-press",
                title: "The Placard Press",
                contentsListing: "The Placard Press · four small signs looking for an argument",
                instruction: "Four words want signs. Write one word and one demand on each. Cut them loose. Stand them beside the things they are arguing with.\n\nI am staying out of it.",
                form: .cutOut,
                cadence: .monthly,
                templateSlot: .afterWorldEvent,
                footprint: .rectoWithBlankReverse,
                eventPhaseIDs: ["outbreak", "assembly"],
                body: "CUT ONLY THE DASHED LINES",
                prompts: (1...4).map { index in
                    .init(id: "placard-\(index)", label: "WORD", writingLines: 3, note: "DEMAND")
                }
            ),
            EditionPlayLeaf(
                id: "amendment-to-the-seventeenth-edition",
                title: "Amendment to the Seventeenth Edition",
                contentsListing: "Amendment to the Seventeenth Edition · the Reader corrects the record",
                instruction: "One definition came back wrong. Correct it before the ink hardens.",
                form: .journal,
                cadence: .monthly,
                templateSlot: .beforeClosing,
                footprint: .singlePage,
                eventPhaseIDs: ["afterimage"],
                eventOutcomeIDs: ["lexical-ally", "definition-binder"],
                body: "Your word beats my guess.",
                prompts: [
                    .init(id: "word", label: "WORD", writingLines: 1),
                    .init(id: "old", label: "OLD DEFINITION", writingLines: 2),
                    .init(id: "failed", label: "WHAT THE OLD DEFINITION FAILED TO NOTICE", writingLines: 2),
                    .init(id: "amended", label: "AMENDED DEFINITION", writingLines: 3),
                    .init(id: "actual", label: "EXAMPLE FROM AN ACTUAL DAY", writingLines: 2),
                    .init(id: "signed", label: "Signed by the Reader", writingLines: 1, note: "Date")
                ],
                options: ["RECALLED", "PARDONED", "ADOPTED", "FREED", "NONE OF YOUR BUSINESS"]
            ),
            EditionPlayLeaf(
                id: "atlas-of-one-escaped-word",
                title: "Atlas of One Escaped Word",
                contentsListing: "Atlas of One Escaped Word · a road through three chapters",
                instruction: "Choose one word from September. Mark where it began. Then hunt through the other two chapters. When it returns, or almost returns, draw the road it took.",
                form: .map,
                cadence: .seasonal,
                templateSlot: .seasonFinale,
                footprint: .facingSpread,
                eventPhaseIDs: ["afterimage"],
                body: "Roads may cross pages. This one is allowed.",
                prompts: [
                    .init(id: "left", label: "IT LEFT SEPTEMBER HERE", writingLines: 4),
                    .init(id: "coat", label: "IT CHANGED COATS HERE", writingLines: 4),
                    .init(id: "refused", label: "IT REFUSED TO RETURN HERE", writingLines: 4),
                    .init(id: "answered", label: "SOMETHING ANSWERED IT HERE", writingLines: 4),
                    .init(id: "ended", label: "WHERE IT ENDED UP", writingLines: 4)
                ]
            ),
            EditionPlayLeaf(
                id: "the-word-the-year-changed",
                title: "The Word the Year Changed",
                contentsListing: "The Word the Year Changed · the last definition belongs to the Reader",
                instruction: "A word entered this year wearing one meaning. It came out in another coat. Put both on record. If no word changed, put the stubborn one on trial instead.",
                form: .journal,
                cadence: .annual,
                templateSlot: .readerLastWord,
                footprint: .rectoWithBlankReverse,
                eventPhaseIDs: ["omen", "outbreak", "assembly", "afterimage"],
                body: "I stop here. The last definition is yours.",
                prompts: [
                    .init(id: "word", label: "THE WORD", writingLines: 1),
                    .init(id: "start", label: "AT THE START OF THE YEAR, IT MEANT", writingLines: 2),
                    .init(id: "happened", label: "THEN THIS HAPPENED", writingLines: 3),
                    .init(id: "now", label: "NOW IT MEANS", writingLines: 2),
                    .init(id: "sentence", label: "USE IT IN A SENTENCE ONLY THIS YEAR COULD HAVE MADE", writingLines: 2),
                    .init(id: "signed", label: "Signed", writingLines: 1, note: "Date")
                ],
                options: ["KEEP", "AMEND", "CROSS OUT AGAIN"]
            )
        ]
    )
}
