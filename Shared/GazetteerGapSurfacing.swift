import Foundation

/// The Gazetteer asking for somewhere it has never been, and noticing when the
/// reader went.
///
/// This is the Bestiary's commission with better stakes. The Book cannot verify
/// most of what it asks for and has to take the reader's word; here it is the
/// thing holding the map, so it knows. Nobody has to report back. They go, they
/// keep something while they are there, and the Book works it out.

enum GazetteerGapNoticeKind: String, Equatable, Sendable {
    /// The Book asking for a shape of place its map has none of.
    case errand
    /// The reader went.
    case went
}

struct GazetteerGapNotice: Equatable, Sendable {
    var kind: GazetteerGapNoticeKind
    var gap: GazetteerGap
    var headline: String
    var detail: String
    var body: String
    var restTag: String
    var evidencePageIDs: [String] = []
    /// The reader's usual edge at the moment of asking, carried on the Page so
    /// the answer is judged against the habit the errand was written about
    /// rather than against a boundary the errand itself moved.
    var edgeAtAsk: Double = 0
}

enum GazetteerGapNoticing {

    /// One thing about the holes in the map, or nothing.
    static func notice(
        days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> GazetteerGapNotice? {
        let world = ReaderWorld.measured(from: days)
        let spoken = Set(days.flatMap(\.pages).flatMap(\.tags))

        // An errand answered outranks anything the Book might think of on its
        // own, because the reader already went somewhere on the strength of it.
        if let outstanding = GazetteerGaps.outstanding(in: days),
           let answer = firstAnswer(to: outstanding, in: days, world: world) {
            return went(
                gap: outstanding.gap, point: answer, askedAt: outstanding.askedAt,
                calendar: calendar
            )
        }
        // One errand at a time. Two open asks turn a Book into a list of
        // chores, and the whole argument here is that this is not that.
        guard GazetteerGaps.outstanding(in: days) == nil else { return nil }

        let open = GazetteerGaps.open(in: world, days: days)
        for gap in ordered(open) where !spoken.contains(restTag(for: .errand, gap: gap)) {
            return errand(gap: gap, world: world)
        }
        return nil
    }

    /// Cheapest ask first, and a direction last: the night errand costs nobody
    /// a journey, and asking a reader to go somewhere new is the largest thing
    /// this Book ever requests of anybody.
    private static func ordered(_ gaps: [GazetteerGap]) -> [GazetteerGap] {
        let rank: (GazetteerGap) -> Int = { gap in
            switch gap {
            case .afterDark: return 0
            case .water: return 1
            case .pastTheUsualEdge: return 2
            case .theEmptyQuarter: return 3
            }
        }
        return gaps.sorted { rank($0) < rank($1) }
    }

    private static func firstAnswer(
        to outstanding: (gap: GazetteerGap, askedAt: Date, edge: Double),
        in days: [BookDay],
        world: ReaderWorld
    ) -> WorldPoint? {
        WorldPoint.points(in: days)
            .filter { $0.at > outstanding.askedAt }
            .sorted { $0.at < $1.at }
            .first {
                outstanding.gap.isClosed(by: $0, in: world, edgeAtAsk: outstanding.edge)
            }
    }

    static func restTag(for kind: GazetteerGapNoticeKind, gap: GazetteerGap) -> String {
        switch kind {
        case .errand: return "gazetteer-errand:\(gap.id)"
        case .went: return "gazetteer-went:\(gap.id)"
        }
    }

    // MARK: The ask

    private static func errand(gap: GazetteerGap, world: ReaderWorld) -> GazetteerGapNotice {
        let copy = ask(for: gap)
        return GazetteerGapNotice(
            kind: .errand,
            gap: gap,
            headline: copy.headline,
            detail: copy.detail,
            body: copy.body,
            restTag: restTag(for: .errand, gap: gap),
            edgeAtAsk: world.usualEdgeMeters
        )
    }

    private static func ask(
        for gap: GazetteerGap
    ) -> (headline: String, detail: String, body: String) {
        switch gap {
        case .afterDark:
            return (
                "Nowhere in here has ever been dark.",
                "Take me somewhere you already know, at night.",
                """
                Every place on my map was standing in daylight when you showed \
                it to me. Not one of them has ever been dark.

                So don't go anywhere new. Pick somewhere you could walk to with \
                your eyes shut, and take me there after the light has gone. It \
                will be a different place. The trees will be doing something \
                else. That is the entire trick, and it costs nothing, and it \
                works every single time.
                """
            )
        case .water:
            return (
                "Nothing you've shown me has ever been near water.",
                "Find some. A river counts. A canal counts.",
                """
                No sea, no river, no reservoir, no scummy canal behind an \
                industrial estate. My whole map is dry.

                Water is the one thing in a landscape that is never doing the \
                same thing twice, which is why people have always gone and \
                stood next to it. Go and stand next to some, and keep something \
                while you're there.
                """
            )
        case .pastTheUsualEdge:
            return (
                "I know where you stop.",
                "Take me one street further than that. One is enough.",
                """
                There's a line around you. It isn't drawn anywhere and nobody \
                put it there on purpose, but almost everything you have ever \
                shown me is inside it, and I can see exactly where it runs.

                I'm not asking for a journey. Go past it by one street, one \
                field, one bend in the road, and keep something on the other \
                side. I want to find out what you've been walking around.
                """
            )
        case let .theEmptyQuarter(quarter):
            return (
                "You've never taken me \(quarter.appetite).",
                "There's a whole direction I've never been.",
                """
                Everything on my map is in the other three directions. \
                \(GrimoireVoice.opening(quarter.appetite)) of you is a blank \
                where the paper never got used.

                I have no idea what's over there. Neither of us does, which is \
                the interesting part — you've been living beside it the whole \
                time. Go \(quarter.appetite) until it stops being familiar, and \
                keep something.
                """
            )
        }
    }

    // MARK: The answer

    private static func went(
        gap: GazetteerGap,
        point: WorldPoint,
        askedAt: Date,
        calendar: Calendar
    ) -> GazetteerGapNotice {
        let days = calendar.dateComponents([.day], from: askedAt, to: point.at).day ?? 0
        let took: String
        switch days {
        case ...0: took = "Same day."
        case 1: took = "The next day."
        case 2...13: took = "It took you \(GrimoireVoice.spelledCount(days).lowercased()) days."
        default: took = "It took you a while. I didn't mind waiting."
        }
        return GazetteerGapNotice(
            kind: .went,
            gap: gap,
            headline: "You went.",
            detail: wentDetail(for: gap),
            body: """
            \(took) Nobody made you, nobody was watching, and there was no \
            reason to do it except that I asked and you felt like finding out.

            \(wentClosing(for: gap))
            """,
            restTag: restTag(for: .went, gap: gap),
            evidencePageIDs: [point.pageID]
        )
    }

    private static func wentDetail(for gap: GazetteerGap) -> String {
        switch gap {
        case .afterDark: return "There's a dark place on my map now."
        case .water: return "There's water on my map now."
        case .pastTheUsualEdge: return "You went over the line."
        case let .theEmptyQuarter(quarter): return "The \(quarter.plainName) isn't blank any more."
        }
    }

    private static func wentClosing(for gap: GazetteerGap) -> String {
        switch gap {
        case .afterDark:
            return """
            Somewhere you have walked a hundred times, and it had a whole other \
            version you had never met. It has always had that. It has one \
            tonight as well.
            """
        case .water:
            return """
            It was there the whole time, doing that, whether or not anybody \
            came to watch it. Most of the good things are like that.
            """
        case .pastTheUsualEdge:
            return """
            The line moved. It'll settle again somewhere new, because lines \
            always do, and I'll tell you where when it has.
            """
        case let .theEmptyQuarter(quarter):
            return """
            I'd stopped believing there was anything \(quarter.appetite) of \
            you. That was my failure of imagination, and you've just corrected \
            it, which is the correct order for those two things.
            """
        }
    }
}

// MARK: - The Page

/// The Gazetteer's errand, on a leaf.
///
/// Its own source rather than the Gazetteer shelf's, because a shelf is
/// somewhere the reader goes and this has to come and find them. It shares
/// `.bookNotices` with the grimoire, the Bestiary and the Wear for the reasons
/// those already gave.
struct GazetteerGapPageSourceAdapter: BookPageSourceAdapter {
    static let sourceID = "the-map-gaps"

    let source = BookPageSourceRegistry.source(
        id: GazetteerGapPageSourceAdapter.sourceID,
        fallbackType: .bookNotices
    )

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard !day.pages.contains(where: { $0.sourceID == source.id }) else { return [] }
        guard let notice = GazetteerGapNoticing.notice(
            days: inputs.days + [day], now: now
        ) else { return [] }
        let forbidden = Set(inputs.bookReadingBoundaries.map(\.id))
        guard !forbidden.contains("gazetteer-gap:\(notice.restTag)") else { return [] }
        return [surface(for: notice, day: day, now: now)]
    }

    func manualSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        if let notice = GazetteerGapNoticing.notice(days: inputs.days + [day], now: now) {
            return surface(for: notice, day: day, now: now)
        }
        return SurfacePage.handOpened(
            source: source, day: day, now: now,
            intent: .reflect, renderStyle: .loreLetter, score: 40,
            metadata: ["mapGapNone": "true"],
            tags: ["the-map-gaps"]
        )
    }

    private func surface(for notice: GazetteerGapNotice, day: BookDay, now: Date) -> SurfacePage {
        var tags = ["the-map-gaps", notice.kind.rawValue, notice.restTag]
        if notice.kind == .errand {
            // The edge rides along so the answer is judged against the habit
            // this errand was written about. Rounded to a metre: the fix is
            // worth a neighbourhood and the tag should not pretend otherwise.
            tags.append("gazetteer-edge:\(Int(notice.edgeAtAsk.rounded()))")
        }

        var metadata: [String: String] = [
            "source": source.id,
            "observationKey": "gazetteer-gap:\(notice.restTag)",
            "mapGapKind": notice.kind.rawValue,
            "mapGapID": notice.gap.id,
            "tags": tags.joined(separator: ","),
            // An errand is a thing to go and do, so it offers no reading to
            // confirm or correct. The Book noticing that somebody went is a
            // claim about their day, and that one they can argue with.
            "adaptiveActions": notice.kind == .went ? "confirmReading,correctReading" : ""
        ]
        if !notice.evidencePageIDs.isEmpty {
            metadata["evidencePageIDs"] = notice.evidencePageIDs.joined(separator: ",")
        }

        return SurfacePage(
            id: "\(source.id)-\(notice.restTag)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: notice.kind == .errand ? .capture : .reflect,
            renderStyle: .loreLetter,
            score: notice.kind == .went ? 95 : 66,
            reason: notice.kind == .went
                ? "I asked you to go somewhere and you went."
                : "There's a shape of place my map has none of.",
            prompt: notice.headline,
            detail: notice.detail,
            payload: BookPagePayload(
                headline: notice.headline,
                body: notice.body,
                metadata: metadata
            )
        )
    }
}
