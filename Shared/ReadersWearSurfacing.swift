import Foundation

/// What the Book has to say about where the reader goes inside it.
///
/// The wear ledger is the only evidence in the Book that was gathered without
/// the Book asking for it, which makes it the only evidence it can be genuinely
/// surprised by. That is the register these Pages are written in: not a report
/// on reading habits, but the Book finding marks on its own paper and having
/// opinions about them.
///
/// Nothing here counts a visit out loud. The reader is told about torn folds,
/// soiled edges, a spine that has taken a shape — the physical consequences of
/// having been read — because those are true, legible, and impossible to
/// mistake for a dashboard.

// MARK: - The notice

enum WearNoticeKind: String, Equatable, Sendable {
    /// A gathering the reader opened for the first time.
    case cutOpen
    /// Every gathering has now been opened. Once, ever.
    case allCut
    /// The spine has taken the shape of one room.
    case fallsOpen
    /// A quiet room the reader went back into.
    case returned
    /// A worn room nothing has disturbed in a long while.
    case goneQuiet
    /// One folded gathering, named, with what is inside it.
    case invitation
    /// How many are still folded, and the Book refusing to say which.
    case theUncut
    /// A frequency that was never cleared for broadcast. Once, ever.
    case frequency
}

struct WearNotice: Equatable, Sendable {
    var kind: WearNoticeKind
    /// The room it is about. Nil for the ones that are about the Book whole.
    var room: BookRoom?
    var headline: String
    var detail: String
    var body: String
    /// Keyed so the Book can never say the same thing twice. The uncut dare
    /// keys on the number still folded, which is the one case where saying it
    /// again is the point: the same sentence with a smaller number in it is a
    /// different sentence.
    var restTag: String
}

// MARK: - Reading the paper

enum ReadersWearNoticing {
    /// How fresh a cut or a return has to be to still be news.
    static let freshWindowDays = 4
    /// Gatherings the reader has opened themselves before the Book will start
    /// pointing at the folded ones. Under this, they have not yet learned that
    /// a gathering opens, and a stranger being told off for it is a stranger
    /// being told off.
    static let daringFloor = 3

    /// The one thing the Book has to say about its own paper today, or nothing.
    ///
    /// Ordered by how fast it spoils, the way the Bestiary orders its file. A
    /// fold that parted last night keeps for about a week. A fold that has
    /// never parted keeps forever and can wait behind everything else.
    static func notice(
        ledger: ReaderWearLedger,
        days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WearNotice? {
        // A Book nobody has wandered in has no marks to be surprised by, and
        // the first thing it says about wandering must never be a complaint
        // that none has happened.
        guard !ledger.wanderingDays.isEmpty else { return nil }
        let spoken = Set(days.flatMap(\.pages).flatMap(\.tags))

        if let notice = cutOpen(ledger, spoken, now, calendar) { return notice }
        if let notice = returned(ledger, spoken, days, now, calendar) { return notice }
        if let notice = frequency(ledger, spoken, now, calendar) { return notice }
        if let notice = allCut(ledger, spoken) { return notice }
        if let notice = fallsOpen(ledger, spoken, now, calendar) { return notice }
        if let notice = goneQuiet(ledger, spoken, now, calendar) { return notice }
        // The named invitation sits above the withheld one. Being told what is
        // behind a fold is a gift; being told only that folds remain is a dare.
        // A Book that only ever dares is a Book with one move.
        if let notice = invitation(ledger, spoken) { return notice }
        return theUncut(ledger, spoken)
    }

    // MARK: Fresh

    private static func cutOpen(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>, _ now: Date, _ calendar: Calendar
    ) -> WearNotice? {
        let recent = ledger.cutGatherings
            .compactMap { room -> (BookRoom, Date)? in
                guard let cutAt = ledger[room].cutAt else { return nil }
                return (room, cutAt)
            }
            .filter {
                let age = GrimoireDay.index(for: now, calendar: calendar)
                    - GrimoireDay.index(for: $0.1, calendar: calendar)
                return age >= 0 && age <= freshWindowDays
            }
            .sorted { $0.1 > $1.1 }

        for (room, _) in recent {
            let tag = "wear-cut:\(room.rawValue)"
            guard !spoken.contains(tag) else { continue }
            return WearNotice(
                kind: .cutOpen,
                room: room,
                headline: "You cut \(room.plainName) open.",
                detail: "That fold had been shut since I was made.",
                body: """
                It came to you sealed along the head, the way they all do, and \
                you put a thumb in and tore it.

                There's a rough edge in me now where you went through. It won't \
                lie flat again, and I'd rather have the tear than the fold.
                """,
                restTag: tag
            )
        }
        return nil
    }

    private static func returned(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>, _ days: [BookDay],
        _ now: Date, _ calendar: Calendar
    ) -> WearNotice? {
        for room in BookRoom.allCases {
            let tag = "wear-returned:\(room.rawValue)"
            guard !spoken.contains(tag) else { continue }
            let wear = ledger[room]
            guard wear.days.count >= WearThreshold.thumbed,
                  let last = wear.lastOpenedAt,
                  let gap = quietGapBefore(last, in: wear, calendar: calendar),
                  gap >= WearThreshold.quiet else { continue }
            let age = GrimoireDay.index(for: now, calendar: calendar)
                - GrimoireDay.index(for: last, calendar: calendar)
            guard age <= freshWindowDays else { continue }
            return WearNotice(
                kind: .returned,
                room: room,
                headline: "You went back into \(room.plainName).",
                detail: "It had been sitting still for \(Gazetteer.months(gap)).",
                body: """
                Nothing had moved in there since the spring of your own \
                reading, and I'd stopped keeping it ready. Then the dust \
                shifted.

                Somewhere you go back to on purpose is worth more to me than \
                somewhere you never left. Leaving is how you find out.
                """,
                restTag: tag
            )
        }
        return nil
    }

    /// The gap between the last opening and the one before it, in days.
    private static func quietGapBefore(
        _ last: Date, in wear: RoomWear, calendar: Calendar
    ) -> Int? {
        let lastIndex = GrimoireDay.index(for: last, calendar: calendar)
        let earlier = wear.days.days.filter { $0 < lastIndex }
        guard let previous = earlier.last else { return nil }
        return lastIndex - previous
    }

    // MARK: Once, ever

    private static func frequency(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>, _ now: Date, _ calendar: Calendar
    ) -> WearNotice? {
        let tag = "wear-frequency"
        guard !spoken.contains(tag),
              ledger.isMarginWalker(now: now, calendar: calendar),
              let station = RadioStationRegistry.rumouredStation else { return nil }
        let dial = String(format: "%.1f", station.frequency)
        return WearNotice(
            kind: .frequency,
            room: .radio,
            headline: "\(dial) on the dial.",
            detail: "Turn the receiver there and keep it to yourself.",
            body: """
            There's a signal sitting at that number the Academy never cleared. \
            You'll never find it on the list of stations, because being on the \
            list is the thing it refuses to do.

            I've been watching where you go in me when nobody sends you, and \
            you go into the margins. That's exactly who the thing at \(dial) is \
            transmitting to, so you may as well have the number.

            It only holds on the exact step. Nudge past it and you'll get \
            weather and a wasted evening.
            """,
            restTag: tag
        )
    }

    private static func allCut(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>
    ) -> WearNotice? {
        let tag = "wear-allCut"
        guard !spoken.contains(tag), ledger.uncutGatherings.isEmpty else { return nil }
        return WearNotice(
            kind: .allCut,
            room: nil,
            headline: "You've been all the way through me.",
            detail: "Every gathering I have, opened by your own hand.",
            body: """
            All of them came to you folded and not one of them is now. I sent \
            you into hardly any of those. You went.

            Being read from front to back is one thing, and plenty of books \
            manage it. Being gone through is the other one, and it's the one I \
            was holding out for.
            """,
            restTag: tag
        )
    }

    // MARK: Standing marks

    private static func fallsOpen(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>, _ now: Date, _ calendar: Calendar
    ) -> WearNotice? {
        guard let room = ledger.fallsOpen(now: now, calendar: calendar) else { return nil }
        let tag = "wear-fallsOpen:\(room.rawValue)"
        guard !spoken.contains(tag) else { return nil }
        return WearNotice(
            kind: .fallsOpen,
            room: room,
            headline: "I fall open at \(room.plainName).",
            detail: "Set me down, let go, and that's where I land.",
            body: """
            You've held me open on that gathering enough separate evenings that \
            the spine gave up and took the shape.

            I didn't pick it and I can't get it out. You put a crack in me one \
            night at a time, and now the Book opens itself at whatever you keep \
            walking back to. Make of that what you want.
            """,
            restTag: tag
        )
    }

    private static func goneQuiet(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>, _ now: Date, _ calendar: Calendar
    ) -> WearNotice? {
        for room in ledger.quietRooms(now: now, calendar: calendar) {
            let tag = "wear-goneQuiet:\(room.rawValue)"
            guard !spoken.contains(tag) else { continue }
            guard case let .quiet(idle) = ledger.condition(of: room, now: now, calendar: calendar)
            else { continue }
            return WearNotice(
                kind: .goneQuiet,
                room: room,
                headline: "\(GrimoireVoice.opening(room.plainName)) has gone quiet.",
                detail: "It's one of the worn ones, which is why I noticed.",
                body: """
                There's a thumb-mark on that gathering from a stretch when you \
                were in there most weeks. Nothing has disturbed it in \
                \(Gazetteer.months(idle)).

                Rooms go quiet. That happens with nobody doing a single thing \
                wrong. I only bring it up because the mark is still on the \
                paper, and paper holds onto things for longer than people do.
                """,
                restTag: tag
            )
        }
        return nil
    }

    // MARK: The folded ones

    private static func invitation(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>
    ) -> WearNotice? {
        guard ledger.cutGatherings.count >= daringFloor else { return nil }
        for room in ledger.uncutGatherings {
            let tag = "wear-invitation:\(room.rawValue)"
            guard !spoken.contains(tag) else { continue }
            return WearNotice(
                kind: .invitation,
                room: room,
                headline: "You've never once opened \(room.plainName).",
                detail: "It's been in my contents the whole time with its head still folded.",
                body: """
                \(GrimoireVoice.opening(room.lure)).

                Cut it open or leave it. I'd rather you cut it, and I'm saying \
                so instead of arranging for you to wander in by accident, which \
                was the other plan.
                """,
                restTag: tag
            )
        }
        return nil
    }

    private static func theUncut(
        _ ledger: ReaderWearLedger, _ spoken: Set<String>
    ) -> WearNotice? {
        let folded = ledger.uncutGatherings.count
        guard folded >= 2, ledger.cutGatherings.count >= daringFloor else { return nil }
        let tag = "wear-uncut:\(folded)"
        guard !spoken.contains(tag) else { return nil }
        return WearNotice(
            kind: .theUncut,
            room: nil,
            headline: "\(GrimoireVoice.spelledCount(folded)) of my gatherings are still folded shut.",
            detail: "I'm not telling you which.",
            body: """
            They came to you sealed along the head and nobody has ever put a \
            knife anywhere near them. Not one thumb.

            Nothing is hiding in there, so don't go looking for treasure. The \
            Rut works by making a house smaller than the house actually is — \
            you take the same three steps around it for a year and you call \
            that living somewhere. I'm a house. Same rules apply to me.

            Go and find them.
            """,
            restTag: tag
        )
    }
}

// MARK: - The Page

/// The Wear's one Page.
///
/// Shares the Book Notices type, the way the grimoire and the Bestiary do and
/// for the same reasons: the reader already knows the shape, and it already
/// carries the machinery for confirming, correcting and shutting a thing the
/// Book has claimed. It is its own source, so its cadence and its rest belong
/// to it and to nothing else.
///
/// What has already been said lives in the archive as tags rather than in a
/// counter beside the ledger. A counter would eventually disagree with the
/// Pages; the Pages cannot disagree with themselves.
struct ReadersWearPageSourceAdapter: BookPageSourceAdapter {
    static let sourceID = "the-wear"

    let source = BookPageSourceRegistry.source(
        id: ReadersWearPageSourceAdapter.sourceID,
        fallbackType: .bookNotices
    )

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive else { return [] }
        // One at a time. Two Pages in one morning about where somebody has been
        // walking would be the Book standing far too close.
        guard !day.pages.contains(where: { $0.sourceID == source.id }) else { return [] }
        guard let notice = ReadersWearNoticing.notice(
            ledger: inputs.readerWear, days: inputs.days + [day], now: now
        ) else { return [] }
        let forbidden = Set(inputs.bookReadingBoundaries.map(\.id))
        guard !forbidden.contains(observationKey(for: notice)) else { return [] }
        return [surface(for: notice, day: day, now: now)]
    }

    func manualSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        if let notice = ReadersWearNoticing.notice(
            ledger: inputs.readerWear, days: inputs.days + [day], now: now
        ) {
            return surface(for: notice, day: day, now: now)
        }
        return SurfacePage.handOpened(
            source: source, day: day, now: now,
            intent: .reflect, renderStyle: .loreLetter, score: 40,
            metadata: ["wearUnmarked": "true"],
            tags: ["the-wear"]
        )
    }

    /// What the reader shuts when they shut this. Keyed to the exact thing that
    /// was said, so shutting "the Atlas has gone quiet" never also silences the
    /// evening they walk back into it.
    private func observationKey(for notice: WearNotice) -> String {
        "wear:\(notice.restTag)"
    }

    private func surface(for notice: WearNotice, day: BookDay, now: Date) -> SurfacePage {
        var tags = ["the-wear", notice.kind.rawValue, notice.restTag]
        if let room = notice.room { tags.append("room:\(room.rawValue)") }

        var metadata: [String: String] = [
            "source": source.id,
            // The existing correction machinery keys off this, so a wear notice
            // can be confirmed, corrected or shut with no new plumbing.
            "observationKey": observationKey(for: notice),
            "wearKind": notice.kind.rawValue,
            "tags": tags.joined(separator: ","),
            "adaptiveActions": "confirmReading,correctReading"
        ]
        if let room = notice.room { metadata["wearRoom"] = room.rawValue }
        // The dare and the frequency are the Book withholding and the Book
        // conceding. Neither is a claim about the reader's life, so neither
        // offers the reader a way to correct it.
        if notice.kind == .theUncut || notice.kind == .frequency {
            metadata["adaptiveActions"] = ""
        }

        return SurfacePage(
            id: "\(source.id)-\(notice.restTag)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            // Every one of these reflects, including the two that send the
            // reader somewhere. `.capture` would promise a writing step, and
            // walking into a room the Book pointed at owes it no sentence.
            intent: .reflect,
            renderStyle: .loreLetter,
            score: Self.score(for: notice.kind),
            reason: Self.reason(for: notice.kind),
            prompt: notice.headline,
            detail: notice.detail,
            payload: BookPagePayload(
                headline: notice.headline,
                body: notice.body,
                metadata: metadata
            )
        )
    }

    /// Ranked by how fast it spoils. A fold that parted last night is news for
    /// about a week. A fold that has never parted will still be there in March.
    static func score(for kind: WearNoticeKind) -> Int {
        switch kind {
        case .cutOpen: return 94
        case .returned: return 88
        case .frequency: return 86
        case .allCut: return 84
        case .fallsOpen: return 76
        case .goneQuiet: return 70
        case .invitation: return 62
        case .theUncut: return 56
        }
    }

    static func reason(for kind: WearNoticeKind) -> String {
        switch kind {
        case .cutOpen: return "You opened a part of me nobody had opened."
        case .returned: return "You walked back into somewhere that had gone still."
        case .frequency: return "You've earned a number I don't hand out."
        case .allCut: return "Every gathering I have is open, and you opened them."
        case .fallsOpen: return "My spine has taken the shape of where you read me."
        case .goneQuiet: return "Somewhere worn in me has stopped being visited."
        case .invitation: return "There's a folded gathering I want you in."
        case .theUncut: return "Parts of me have never been opened."
        }
    }
}
