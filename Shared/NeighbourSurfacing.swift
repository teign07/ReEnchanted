import Foundation

/// The Neighbours' Pages on the desk: the Book asking whether something has
/// become somebody, and later, asking after the ones that have.
///
/// Shares the Book Notices type, the way the Bestiary does: the reader knows
/// that shape and it carries the correction machinery. It is its own source,
/// so its rest belongs to it. Rest is kept in the archive, as `spoke:` tags on
/// the Pages it put out; a proposal the reader turns away is shut for good
/// through the ordinary reading boundary.
struct NeighboursPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: Neighbours.sourceID, fallbackType: .neighbours)

    /// How long a proposal the reader kept, but didn't answer, waits before
    /// the Book asks again.
    static let proposalRestDays = 30

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        // One at a time. A record written today counts: the reader has
        // already done Neighbour business this morning.
        guard !day.pages.contains(where: { $0.sourceID == source.id }) else { return [] }
        let all = inputs.days + [day]
        let forbidden = Set(inputs.bookReadingBoundaries.map(\.id))

        if let timely = NeighbourNotices.timely(days: all, now: now)
            .first(where: { !forbidden.contains($0.observationKey) }) {
            return [NeighbourNotices.surface(for: timely, source: source, day: day)]
        }

        let resting = BookNoticesPageSourceAdapter.spokenSignalIDs(
            days: all, within: Self.proposalRestDays, now: now
        )
        guard let proposal = Neighbours.proposals(
            days: all,
            excludedNames: Neighbours.excludedNames(inputs: inputs),
            excludedSlugs: Neighbours.excludedSlugs(inputs: inputs),
            declinedKeys: forbidden
        ).first(where: { !resting.contains($0.restKey) }) else { return [] }
        return [Self.surface(for: proposal, source: source, day: day)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let all = inputs.days + [day]
        if let proposal = Neighbours.proposals(
            days: all,
            excludedNames: Neighbours.excludedNames(inputs: inputs),
            excludedSlugs: Neighbours.excludedSlugs(inputs: inputs),
            declinedKeys: Set(inputs.bookReadingBoundaries.map(\.id))
        ).first {
            return Self.surface(for: proposal, source: source, day: day)
        }
        return SurfacePage.handOpened(
            source: source, day: day, now: now,
            intent: .reflect, renderStyle: .loreLetter, score: 40,
            metadata: ["neighboursEmpty": "true"],
            tags: ["neighbours"]
        )
    }

    /// "Gerald. Shall I give Gerald a page?"
    static func surface(for proposal: NeighbourProposal, source: BookPageSource, day: BookDay) -> SurfacePage {
        let spoken = proposal.isEpithet ? Neighbours.capitalized(proposal.name) : proposal.name
        let inSentence = proposal.name
        var lines: [String] = []
        if proposal.working != nil {
            lines.append(proposal.isEpithet
                ? "\(proposal.deed) I didn't catch its name."
                : "\(proposal.deed) \(spoken).")
        } else {
            lines.append(proposal.deed)
        }
        if let quote = proposal.quote {
            lines.append("You wrote: \u{201C}\(quote)\u{201D}")
        }
        lines.append("I want to keep \(inSentence). A page of its own, and every Page it turns up on after this.")

        var metadata = Neighbours.metadata(for: proposal)
        metadata["source"] = source.id
        metadata["observationKey"] = proposal.observationKey
        metadata["noveltyKey"] = proposal.restKey
        metadata["automaticRepeatRestDays"] = "21"
        metadata["adaptiveActions"] = ["giveNeighbourAPage", "notANeighbour"].joined(separator: "\n")
        metadata["tags"] = ["neighbours", "neighbour-propose", "spoke:\(proposal.restKey)", "local-memory"]
            .joined(separator: ",")

        return SurfacePage(
            id: "\(source.id)-\(proposal.restKey)-\(day.id)",
            type: .neighbours,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: proposal.working != nil ? 72 : 64,
            reason: "Something in your days has turned into somebody.",
            prompt: "Shall I give \(inSentence) a page?",
            detail: "\(spoken) might be one of the Neighbours.",
            payload: BookPagePayload(
                headline: "Is This Somebody?",
                body: lines.joined(separator: "\n\n"),
                metadata: metadata
            )
        )
    }
}

// MARK: - Neighbours over time

/// The Neighbour Pages that come on a date: a name-day, a Neighbour gone
/// quiet, a Neighbour back after a long quiet. Each fires on its own dates
/// and is said once; resting and gone Neighbours are never asked after.
enum NeighbourNotices {
    struct Timely: Equatable {
        enum Kind: String, Equatable {
            case nameDay = "nameday"
            case goneQuiet = "quiet"
            case cameBack = "back"
        }

        var neighbour: Neighbour
        var kind: Kind
        /// Years since its founding, for a name-day.
        var years: Int = 0
        /// The quiet stretch: since the last Page for a quiet one, or the gap
        /// it came back across.
        var quietDays: Int = 0
        /// When it was last seen before coming back.
        var before: Date? = nil

        var restKey: String {
            kind == .nameDay
                ? "neighbour-nameday-\(neighbour.slug)-\(years)"
                : "neighbour-\(kind.rawValue)-\(neighbour.slug)"
        }

        var observationKey: String { "neighbour-\(kind.rawValue):\(neighbour.slug)" }
    }

    /// Same thresholds the People of the Book use: real history, then a
    /// quiet stretch long enough to notice and not so long it belongs to the
    /// reader alone.
    static let quietThresholdDays = PeopleOfTheBook.quietThresholdDays
    static let quietCeilingDays = PeopleOfTheBook.quietCeilingDays
    static let returnWindowDays = PeopleOfTheBook.returnWindowDays
    static let quietRestDays = PeopleOfTheBook.quietNoticeRestDays
    static let returnRestDays = PeopleOfTheBook.returnNoticeRestDays
    /// Enough history to miss: Pages on this many different days.
    static let minimumHistoryDays = 2
    static let minimumHistoryPages = 3

    /// Whether today is this Neighbour's name-day, and how many years old.
    /// A Neighbour founded on the twenty-ninth of February keeps its name-day
    /// on the twenty-eighth in other years.
    static func nameDayYears(for neighbour: Neighbour, on now: Date, calendar: Calendar = .current) -> Int? {
        let founded = calendar.dateComponents([.year, .month, .day], from: neighbour.foundedAt)
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        guard let fy = founded.year, let fm = founded.month, let fd = founded.day,
              let ty = today.year, let tm = today.month, let td = today.day, ty > fy else { return nil }
        var day = fd
        if fm == 2, fd == 29,
           let range = calendar.range(of: .day, in: .month,
                                      for: calendar.date(from: DateComponents(year: ty, month: 2, day: 1)) ?? now),
           !range.contains(29) {
            day = 28
        }
        return tm == fm && td == day ? ty - fy : nil
    }

    static func timely(days: [BookDay], now: Date, calendar: Calendar = .current) -> [Timely] {
        let register = Neighbours.register(days: days).filter(\.isLiving)
        guard !register.isEmpty else { return [] }
        let everSpoken = BookNoticesPageSourceAdapter.spokenSignalIDs(days: days, within: nil, now: now)
        let quietSpoken = BookNoticesPageSourceAdapter.spokenSignalIDs(days: days, within: quietRestDays, now: now)
        let backSpoken = BookNoticesPageSourceAdapter.spokenSignalIDs(days: days, within: returnRestDays, now: now)
        var found: [Timely] = []
        for neighbour in register {
            if let years = nameDayYears(for: neighbour, on: now, calendar: calendar) {
                let notice = Timely(neighbour: neighbour, kind: .nameDay, years: years)
                if !everSpoken.contains(notice.restKey) { found.append(notice) }
                continue
            }
            let dates = neighbour.pageDates.filter { $0 <= now }.sorted()
            let distinctDays = Set(dates.map { calendar.startOfDay(for: $0) })
            guard dates.count >= minimumHistoryPages, distinctDays.count >= minimumHistoryDays,
                  let last = dates.last else { continue }
            let quiet = dayCount(from: last, to: now, calendar: calendar)
            if (quietThresholdDays...quietCeilingDays).contains(quiet) {
                let notice = Timely(neighbour: neighbour, kind: .goneQuiet, quietDays: quiet)
                if !quietSpoken.contains(notice.restKey) { found.append(notice) }
            } else if quiet <= returnWindowDays, dates.count >= 2 {
                let previous = dates[dates.count - 2]
                let gap = dayCount(from: previous, to: last, calendar: calendar)
                if gap >= quietThresholdDays {
                    let notice = Timely(neighbour: neighbour, kind: .cameBack, quietDays: gap, before: previous)
                    if !backSpoken.contains(notice.restKey) { found.append(notice) }
                }
            }
        }
        // A name-day will not keep. A return is fresher than a silence.
        let order: [Timely.Kind] = [.nameDay, .cameBack, .goneQuiet]
        return found.sorted {
            let left = order.firstIndex(of: $0.kind) ?? 0
            let right = order.firstIndex(of: $1.kind) ?? 0
            return left != right ? left < right : $0.neighbour.slug < $1.neighbour.slug
        }
    }

    static func dayCount(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    static func yearsAgo(_ years: Int) -> String {
        let words = ["A year", "Two years", "Three years", "Four years", "Five years",
                     "Six years", "Seven years", "Eight years", "Nine years", "Ten years"]
        return years >= 1 && years <= words.count ? words[years - 1] + " ago" : "Years ago"
    }

    static func surface(for notice: Timely, source: BookPageSource, day: BookDay, calendar: Calendar = .current) -> SurfacePage {
        let neighbour = notice.neighbour
        let name = neighbour.name
        let spoken = Neighbours.capitalized(name)
        var metadata: [String: String] = [
            "source": source.id,
            "observationKey": notice.observationKey,
            "noveltyKey": notice.restKey,
            "neighbourSlug": neighbour.slug,
            "neighbourName": name,
            "neighbourNotice": notice.kind.rawValue,
            "evidencePageIDs": neighbour.pageIDs.suffix(6).joined(separator: ",")
        ]
        let tags = ["neighbours", "neighbour-\(notice.kind.rawValue)", "spoke:\(notice.restKey)", "local-memory"]

        switch notice.kind {
        case .nameDay:
            let lead: String
            if neighbour.working != nil, !neighbour.isEpithet, neighbour.formerNames.isEmpty {
                lead = "\(yearsAgo(notice.years)) today you gave \(name) its name."
            } else {
                lead = "\(yearsAgo(notice.years)) today \(name) first turned up in your Pages."
            }
            let quote = neighbour.foundingSentence.map { "You wrote: \u{201C}\($0)\u{201D}" }
            let action: String
            switch neighbour.kind {
            case .thing: action = "Give \(name) something for it. Anything at all. Tell it what it's for."
            case .creature: action = "Say happy name-day where \(name) can hear. Leave it something it might like."
            case .place: action = "Go and see \(name) and say happy name-day out loud."
            }
            let proof = "One sentence about what you gave \(name) for its name-day."
            let title = "\(Neighbours.titled(name)) Has a Name-Day"
            let missionID = notice.restKey
            let body = (["It's \(name)'s name-day. \(lead)"] + [quote].compactMap { $0 } + [action])
                .joined(separator: "\n\n")
            metadata["compassStep"] = "sense"
            metadata["compassMode"] = "standalone"
            metadata["playfulMissionID"] = missionID
            metadata["playfulMissionTitle"] = title
            metadata["mission"] = action
            metadata["souvenirPrompt"] = proof
            metadata["placeholder"] = proof
            metadata["proofKind"] = "sentence"
            metadata["folioTitle"] = title
            metadata["tags"] = (tags + ["neighbour-of:\(neighbour.slug)", "nameday"]).joined(separator: ",")
            return SurfacePage(
                id: "\(source.id)-\(notice.restKey)-\(day.id)",
                type: .wonderCompass,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: 84,
                reason: "It's a name-day.",
                prompt: title,
                detail: "\(spoken) has a name-day today.",
                payload: BookPagePayload(headline: title, body: body, metadata: metadata)
            )
        case .goneQuiet:
            let month = Neighbours.month(neighbour.lastSeen, calendar: calendar)
            let body = """
            \(spoken) hasn't been in your Pages since \(month). I keep looking for it in your ink and it isn't there.

            Is \(name) still where it lives? Go and look, and tell me.
            """
            metadata["tags"] = tags.joined(separator: ",")
            metadata["adaptiveActions"] = "restNeighbour"
            return SurfacePage(
                id: "\(source.id)-\(notice.restKey)-\(day.id)",
                type: .neighbours, sourceID: source.id, intent: .reflect, renderStyle: .loreLetter,
                score: 60,
                reason: "One of the Neighbours has gone quiet.",
                prompt: "Where's \(name) gone?",
                detail: "\(spoken) hasn't been in your Pages since \(month).",
                payload: BookPagePayload(headline: "Gone Quiet", body: body, metadata: metadata)
            )
        case .cameBack:
            let month = notice.before.map { Neighbours.month($0, calendar: calendar) } ?? "a long time"
            let body = """
            \(spoken)'s back. Nothing about it in your Pages since \(month), and then there it was again.

            I've put the new Page with the old ones. Where's it been?
            """
            metadata["tags"] = tags.joined(separator: ",")
            return SurfacePage(
                id: "\(source.id)-\(notice.restKey)-\(day.id)",
                type: .neighbours, sourceID: source.id, intent: .reflect, renderStyle: .loreLetter,
                score: 70,
                reason: "One of the Neighbours came back.",
                prompt: "Look who's back.",
                detail: "\(spoken) is back in your Pages.",
                payload: BookPagePayload(headline: "Look Who's Back", body: body, metadata: metadata)
            )
        }
    }
}
