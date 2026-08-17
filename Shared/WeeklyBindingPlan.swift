import Foundation

/// The week, decided before it is written.
///
/// The nightly braid is verified sentence by sentence against the reader's own
/// receipts. Nothing above it was verified at all: the weekly, monthly and
/// annual binding stories were free-form model prose over clipped summaries,
/// with no fact check, no polarity check and no provenance - and those are the
/// artifacts that get printed, bound and sold. A page that invents a detail
/// about somebody's father is a bad evening; a hardcover that does it is
/// permanent, was paid for, and is the thing they hand to family.
///
/// So the week uses the same architecture as the night. Deterministic code
/// decides what the week was; the model writes from that decision; a verifier
/// refuses anything the nights do not support; a house floor stands underneath.
///
/// This reads the leaf each night left behind (`braid-plan-*`) rather than
/// re-reading its prose, so the week inherits decisions instead of guesses.

// MARK: - One night, as the week sees it

struct WeekNight: Equatable, Codable, Identifiable {
    var id: String
    var date: Date
    var title: String
    /// The night's own body, which is what a `NIGHT:` claim is checked against.
    var body: String
    /// The anchor the night chose, when it left one behind.
    var spine: String?
    var form: String?
    /// Something that came back that night, and after how long.
    var returnedAfterDays: Int?
    var returnedText: String?
    /// Where that night's day crossed the fiction.
    var crossing: String?
    /// Evidence ids the night refused to resolve. Ids only, never words.
    var openIDs: [String]
    /// Kept pages whose material actually reached the night's page.
    var receiptPageIDs: [String]

    /// A night that left a leaf can be bound from its decisions. A night from
    /// before the leaf existed can still be bound, from its prose.
    var carriesLeaf: Bool { spine != nil || form != nil }
}

/// Something the week saw more than once.
struct WeekReturn: Equatable, Codable {
    var nightIDs: [String]
    /// The shared thing, in the reader's own words as one night recorded it.
    var pivot: String
    var daysApart: Int
}

// MARK: - The plan

struct WeeklyBindingPlan: Equatable, Codable {
    var issueNumber: Int
    var dateRange: String
    var nights: [WeekNight]
    /// The night the issue leads with.
    var coverNightID: String?
    /// Threads the week picked up more than once.
    var returns: [WeekReturn]
    /// Evidence ids still unresolved at the week's end. Ids, never text: a
    /// binding that wants the thread resolves it against the reader's own
    /// archive rather than quoting their worst week back at them from a tag.
    var stillOpenIDs: [String]
    /// The week's shape, from the forms its nights actually took.
    var shape: String
    var earnedWords: ClosedRange<Int>

    func night(_ id: String) -> WeekNight? { nights.first { $0.id == id } }

    var cover: WeekNight? { coverNightID.flatMap(night) }

    /// A stable, prose-free rendering, so the *decision* can be golden-tested
    /// without golden-testing any sentence.
    var summary: String {
        var lines = [
            "issue \(issueNumber) · \(dateRange)",
            "shape \(shape)",
            "earned \(earnedWords.lowerBound)-\(earnedWords.upperBound) words",
            "nights \(nights.count) (\(nights.filter(\.carriesLeaf).count) with a leaf)"
        ]
        if let coverNightID { lines.append("cover \(coverNightID)") }
        for entry in returns {
            lines.append(
                "  return    \(entry.nightIDs.joined(separator: "+"))  [\(entry.pivot)] \(entry.daysApart)d")
        }
        if !stillOpenIDs.isEmpty {
            lines.append("open \(stillOpenIDs.sorted().joined(separator: " "))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Building it

enum WeeklyBindingPlanner {
    static let spinePrefix = "braid-plan-spine:"
    static let formPrefix = "braid-plan-form:"
    static let returnPrefix = "braid-plan-return:"
    static let crossingPrefix = "braid-plan-crossing:"
    static let openPrefix = "braid-plan-open-id:"
    static let evidencePrefix = "braid-plan-evidence:"

    static func plan(for issue: WeeklyIssue, calendar: Calendar = .current) -> WeeklyBindingPlan {
        let nights = issue.pages
            .filter { $0.type == .bookOfYou }
            .sorted { $0.createdAt < $1.createdAt }
            .map { night(from: $0) }

        let returns = returns(among: nights, calendar: calendar)
        return WeeklyBindingPlan(
            issueNumber: issue.number,
            dateRange: issue.dateRange,
            nights: nights,
            coverNightID: coverNightID(among: nights, returns: returns),
            returns: returns,
            stillOpenIDs: Array(Set(nights.flatMap(\.openIDs))).sorted(),
            shape: shape(of: nights),
            earnedWords: earnedWords(for: nights, returns: returns)
        )
    }

    static func night(from page: BookPage) -> WeekNight {
        func value(_ prefix: String) -> String? {
            page.tags.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        func values(_ prefix: String) -> [String] {
            page.tags.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        let returned = value(returnPrefix).map { raw -> (Int?, String) in
            let parts = raw.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { return (nil, raw) }
            return (Int(parts[0]), String(parts[1]))
        }
        let details = BraidPageDetails.details(for: page)
        return WeekNight(
            id: page.id,
            date: page.createdAt,
            title: details.title,
            body: details.body,
            spine: value(spinePrefix),
            form: value(formPrefix),
            returnedAfterDays: returned?.0,
            returnedText: returned?.1,
            crossing: value(crossingPrefix),
            openIDs: values(openPrefix).sorted(),
            receiptPageIDs: values(evidencePrefix).sorted()
        )
    }

    /// The night the issue leads with.
    ///
    /// A week is not a list of days and its cover is a judgement: the night that
    /// carried the longest return wins, because a thing coming back after six
    /// days is the strongest evidence the week had a shape. Failing that, the
    /// night whose page rested on the most of the reader's own material.
    static func coverNightID(among nights: [WeekNight], returns: [WeekReturn]) -> String? {
        guard !nights.isEmpty else { return nil }
        if let longest = nights
            .filter({ $0.returnedAfterDays != nil })
            .max(by: { ($0.returnedAfterDays ?? 0) < ($1.returnedAfterDays ?? 0) }) {
            return longest.id
        }
        if let carried = returns.max(by: { $0.daysApart < $1.daysApart }),
           let first = carried.nightIDs.first {
            return first
        }
        return nights.max { left, right in
            if left.receiptPageIDs.count == right.receiptPageIDs.count {
                return left.date < right.date
            }
            return left.receiptPageIDs.count < right.receiptPageIDs.count
        }?.id
    }

    /// Threads the week picked up more than once.
    ///
    /// Detected, never inferred - the same rule the night works under. Two
    /// nights are related when they name the same distinctive thing, which the
    /// reader can check. "These both feel like endings" is a horoscope.
    static func returns(among nights: [WeekNight], calendar: Calendar) -> [WeekReturn] {
        var found: [WeekReturn] = []
        var spoken = Set<String>()
        for (index, left) in nights.enumerated() {
            for right in nights.dropFirst(index + 1) {
                guard let pivot = sharedThing(left, right) else { continue }
                guard spoken.insert(pivot).inserted else { continue }
                let days = abs(
                    calendar.dateComponents([.day], from: left.date, to: right.date).day ?? 0)
                found.append(
                    WeekReturn(nightIDs: [left.id, right.id], pivot: pivot, daysApart: days))
            }
        }
        // A week that relates everything to everything is a conspiracy board.
        return Array(found.prefix(3))
    }

    private static func sharedThing(_ left: WeekNight, _ right: WeekNight) -> String? {
        let leftWords = distinctive(in: [left.spine, left.returnedText, left.crossing])
        let rightWords = distinctive(in: [right.spine, right.returnedText, right.crossing])
        return leftWords.intersection(rightWords).sorted().first
    }

    private static func distinctive(in fields: [String?]) -> Set<String> {
        var words = Set<String>()
        for field in fields.compactMap({ $0 }) {
            for word in BraidRevisionVerifier.contentWords(in: field) where word.count > 3 {
                words.insert(word)
            }
        }
        return words.subtracting(weekStopwords)
    }

    private static let weekStopwords: Set<String> = [
        "that", "this", "with", "from", "into", "then", "than", "them", "they",
        "were", "have", "been", "about", "after", "before", "again", "still",
        "there", "where", "which", "would", "could", "should", "your", "yours"
    ]

    /// The week's shape, from what its nights actually were rather than from a
    /// mood the binding fancied.
    static func shape(of nights: [WeekNight]) -> String {
        let forms = nights.compactMap(\.form)
        guard !forms.isEmpty else { return "unshaped" }
        var counts: [String: Int] = [:]
        for form in forms { counts[form, default: 0] += 1 }
        let ranked = counts.sorted { left, right in
            left.value == right.value ? left.key < right.key : left.value > right.value
        }
        guard let dominant = ranked.first else { return "unshaped" }
        // A week of one form is a week with a shape. A week of many is a week
        // that moved, and saying so is more honest than picking a winner.
        if dominant.value * 2 <= forms.count && ranked.count > 2 { return "various" }
        return dominant.key
    }

    /// What the issue has earned.
    ///
    /// Length comes from what the week actually holds - nights that proved
    /// something, and threads that came back - never from a target the writer
    /// has to pad out to. The nightly band was built on the same rule after
    /// raising a floor bought ninety-eight words of which none were the
    /// reader's.
    static func earnedWords(
        for nights: [WeekNight],
        returns: [WeekReturn]
    ) -> ClosedRange<Int> {
        let substantial = nights.filter { !$0.body.isEmpty }
        guard !substantial.isEmpty else { return 120...200 }
        let perNight = 55
        let perReturn = 45
        let editorial = 60
        let floor = substantial.count * perNight + returns.count * perReturn + editorial
        return max(150, floor)...max(260, Int(Double(floor) * 1.6))
    }
}

// MARK: - The brief

extension WeeklyBindingPlan {
    static let markerContract = """
        FORMAT. Every sentence begins with its claim and nothing else may appear.
          NIGHT:<night-id> a sentence about that one night
          WEEK:<night-id>,<night-id> a sentence relating those nights
          EDITOR the issue's own voice, resting on no night
          COLOPHON one closing line
        A NIGHT sentence may only say what that night's page says. A WEEK sentence \
        may name what two nights have in common and may never rule on what it \
        meant. Nothing may say the reader did something no night recorded.
        """

    func brief() -> String {
        var lines = ["Write the binding story for issue \(issueNumber), \(dateRange)."]
        lines.append("")
        lines.append("SHAPE: the week's nights were mostly \(shape).")
        if let cover {
            lines.append("LEAD WITH: \(cover.spine ?? cover.title)  [\(cover.id)]")
        }
        lines.append("LENGTH: \(earnedWords.lowerBound)-\(earnedWords.upperBound) words.")

        if !returns.isEmpty {
            lines.append("")
            lines.append(
                "THE WEEK PICKED THESE UP TWICE. One or two sentences each, marked WEEK with both ids. Say what is true of the pair; do not say what it meant.")
            for entry in returns {
                lines.append(
                    "  \(entry.nightIDs.joined(separator: ",")) [\(entry.pivot), \(entry.daysApart) days apart]")
            }
        }

        lines.append("")
        lines.append("THE NIGHTS. Each is locked. Rewrite the wording freely; change nothing that happened.")
        for night in nights.sorted(by: { $0.date < $1.date }) {
            lines.append("  \(night.id)  \(night.spine ?? night.title)")
            if let returned = night.returnedText, let days = night.returnedAfterDays {
                lines.append("      came back after \(days) days: \(returned)")
            }
        }

        if !stillOpenIDs.isEmpty {
            lines.append("")
            lines.append(
                "\(stillOpenIDs.count) thing(s) the week refused to resolve. Do not reach for them, do not resolve them, and do not brighten the issue to compensate.")
        }

        lines.append("")
        lines.append(Self.markerContract)
        return lines.joined(separator: "\n")
    }
}

// MARK: - What came back from the model

struct WeeklyClaim: Equatable {
    enum Realm: String, Equatable {
        case night, week, editor, colophon
    }

    var realm: Realm
    var nightIDs: [String]
    var text: String
}

enum WeeklyBindingRejection: String, Equatable, Error {
    case emptyDraft
    case missingMarker
    case malformedMarker
    case unknownNightID
    case inventedContent
    case changedPolarity
    case claimedTheReadersLife
    case declaredMeaning
    case missingColophon
    case lostTheCover
}

/// The gate the printed page has to pass.
///
/// Built on the nightly verifier's laws rather than beside them: a sentence
/// about one night is checked against that night's own page, exactly as a
/// nightly `LIVED:` sentence is checked against its receipt.
enum WeeklyBindingVerifier {
    struct Verified: Equatable {
        var claims: [WeeklyClaim]
        var text: String
    }

    struct Salvage: Equatable {
        var verified: Verified
        var dropped: [WeeklyBindingRejection]
    }

    /// Drop the sentence that cannot be trusted; keep the issue.
    ///
    /// The same lesson the nightly braid learned: whole-draft rejection cost
    /// three pages of seven when the rest of each draft was true. The issue
    /// still goes whole when what survives is not an issue - no closing line, or
    /// nothing left of the night it was meant to lead with.
    static func salvage(
        _ raw: String,
        against plan: WeeklyBindingPlan
    ) -> Result<Salvage, WeeklyBindingRejection> {
        let lines = raw.components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard lines.contains(where: { !$0.isEmpty }) else { return .failure(.emptyDraft) }

        var claims: [WeeklyClaim] = []
        var display: [String] = []
        var dropped: [WeeklyBindingRejection] = []

        for line in lines {
            guard !line.isEmpty else {
                display.append("")
                continue
            }
            guard let claim = claim(from: line) else {
                dropped.append(.missingMarker)
                continue
            }
            if let rejection = reject(claim, plan: plan) {
                dropped.append(rejection)
                continue
            }
            claims.append(claim)
            display.append(claim.text)
        }

        guard claims.contains(where: { $0.realm == .colophon }) else {
            return .failure(.missingColophon)
        }
        if let coverID = plan.coverNightID,
           plan.night(coverID) != nil,
           !claims.contains(where: { $0.nightIDs.contains(coverID) }) {
            return .failure(.lostTheCover)
        }
        return .success(
            Salvage(
                verified: Verified(
                    claims: claims,
                    text: display.joined(separator: "\n")
                        .replacingOccurrences(of: "\n\n\n", with: "\n\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                dropped: dropped
            )
        )
    }

    static func claim(from line: String) -> WeeklyClaim? {
        if line.hasPrefix("EDITOR") {
            let text = String(line.dropFirst("EDITOR".count))
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : WeeklyClaim(realm: .editor, nightIDs: [], text: text)
        }
        if line.hasPrefix("COLOPHON") {
            let text = String(line.dropFirst("COLOPHON".count))
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : WeeklyClaim(realm: .colophon, nightIDs: [], text: text)
        }
        for realm in [WeeklyClaim.Realm.night, .week] {
            let marker = realm.rawValue.uppercased() + ":"
            guard line.hasPrefix(marker) else { continue }
            let rest = String(line.dropFirst(marker.count))
            guard let space = rest.firstIndex(of: " ") else { return nil }
            let ids = String(rest[rest.startIndex..<space])
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let text = String(rest[rest.index(after: space)...])
                .trimmingCharacters(in: .whitespaces)
            guard !ids.isEmpty, !text.isEmpty else { return nil }
            return WeeklyClaim(realm: realm, nightIDs: ids, text: text)
        }
        return nil
    }

    private static func reject(
        _ claim: WeeklyClaim,
        plan: WeeklyBindingPlan
    ) -> WeeklyBindingRejection? {
        switch claim.realm {
        case .colophon:
            return nil

        case .editor:
            // The issue's own voice, which is allowed to say what it is doing -
            // this is the week's equivalent of the nightly `BOOK` realm. It
            // rests on no night, so it may add words, and for exactly that
            // reason it may not put the reader in the past tense or rule on what
            // their week meant.
            if BraidDraftVerifier.assertsSomethingHappenedToTheReader(claim.text) {
                return .claimedTheReadersLife
            }
            return BraidDraftVerifier.declaresMeaning(claim.text) ? .declaredMeaning : nil

        case .night:
            // One sentence, one night. Two nights in one `NIGHT:` claim is how
            // Tuesday's walk and Friday's phone call become one afternoon.
            guard claim.nightIDs.count == 1 else { return .malformedMarker }
            guard let night = plan.night(claim.nightIDs[0]) else { return .unknownNightID }
            let source = [night.spine, night.returnedText, night.body]
                .compactMap { $0 }
                .joined(separator: " ")
            guard BraidRevisionVerifier.preservesPolarity(claim.text, of: source) else {
                return .changedPolarity
            }
            // Deliberately not `preservesFacts`.
            //
            // That check also requires the candidate to carry back every noun of
            // its original, which is right for a sentence rewritten into another
            // sentence and wrong here: a week sentence is *allowed* to compress a
            // whole night down to the part the issue is built on. What it may
            // never do is add. So the addition half of the law applies and the
            // retention half does not.
            let supplied = BraidRevisionVerifier.contentWords(in: source)
            let offered = BraidRevisionVerifier.contentWords(in: claim.text)
            guard offered.allSatisfy({ word in
                supplied.contains { BraidRevisionVerifier.matches($0, word) }
            }) else {
                return .inventedContent
            }
            return nil

        case .week:
            guard claim.nightIDs.count >= 2 else { return .malformedMarker }
            for id in claim.nightIDs where plan.night(id) == nil {
                return .unknownNightID
            }
            // A week sentence may name what two nights share. It may not put the
            // reader in the past tense - only a night claim, checked against its
            // own page, may say what they did - and it may not hand back a
            // verdict on what their week meant.
            if BraidDraftVerifier.assertsSomethingHappenedToTheReader(claim.text) {
                return .claimedTheReadersLife
            }
            return BraidDraftVerifier.declaresMeaning(claim.text) ? .declaredMeaning : nil
        }
    }
}

// MARK: - The floor

/// The issue that ships when no model issue survives.
///
/// Deliberately plain. It is a real binding rather than a placeholder, because
/// it is what a reader gets on any week the model fails, and the weekly issue is
/// something they may have paid to have printed.
enum WeeklyBindingWriter {
    static func write(_ plan: WeeklyBindingPlan) -> [WeeklyClaim] {
        guard !plan.nights.isEmpty else { return [] }
        var claims: [WeeklyClaim] = []

        if let cover = plan.cover {
            claims.append(
                WeeklyClaim(
                    realm: .night, nightIDs: [cover.id],
                    text: BraidSceneWriter.secondPerson(cover.spine ?? cover.title)))
            claims.append(
                WeeklyClaim(realm: .editor, nightIDs: [], text: coverFraming(cover)))
        }
        for night in plan.nights.sorted(by: { $0.date < $1.date }) where night.id != plan.coverNightID {
            guard let line = night.spine ?? night.body.nonEmpty else { continue }
            claims.append(
                WeeklyClaim(
                    realm: .night, nightIDs: [night.id],
                    text: BraidSceneWriter.secondPerson(String(line.prefix(180)))))
        }
        for entry in plan.returns {
            claims.append(
                WeeklyClaim(realm: .week, nightIDs: entry.nightIDs, text: returnLine(entry)))
        }
        claims.append(
            WeeklyClaim(realm: .colophon, nightIDs: [], text: colophon(for: plan)))
        return claims
    }

    /// The issue saying what it is doing. Kept in the editor's realm rather than
    /// the night's, because it adds words the night never wrote - and a night
    /// claim may not add.
    private static func coverFraming(_ night: WeekNight) -> String {
        if let days = night.returnedAfterDays {
            return "It had been \(days) days, and it came back inside the same week. This issue is built around that."
        }
        return "This issue is built around that one."
    }

    private static func returnLine(_ entry: WeekReturn) -> String {
        entry.daysApart <= 1
            ? "The \(entry.pivot) turns up on consecutive days of this issue."
            : "The \(entry.pivot) is in this week twice, \(entry.daysApart) days apart."
    }

    private static func colophon(for plan: WeeklyBindingPlan) -> String {
        if !plan.stillOpenIDs.isEmpty {
            return "The Book bound the week: some of it is still going."
        }
        if !plan.returns.isEmpty {
            return "The Book bound the week: the same things kept arriving."
        }
        return "The Book bound the week: seven days, kept as they came."
    }

    /// The finished prose, paragraphed by realm the way a night's page is.
    static func issue(for plan: WeeklyBindingPlan) -> String? {
        let claims = write(plan)
        guard claims.contains(where: { $0.realm != .colophon }) else { return nil }
        var blocks: [String] = []
        var current: [String] = []
        var lastRealm: WeeklyClaim.Realm?
        for claim in claims where claim.realm != .colophon {
            if let lastRealm, lastRealm != claim.realm, !current.isEmpty {
                blocks.append(current.joined(separator: " "))
                current = []
            }
            current.append(claim.text)
            lastRealm = claim.realm
        }
        if !current.isEmpty { blocks.append(current.joined(separator: " ")) }
        if let colophon = claims.last(where: { $0.realm == .colophon }) {
            blocks.append(colophon.text)
        }
        return blocks.joined(separator: "\n\n")
    }
}
