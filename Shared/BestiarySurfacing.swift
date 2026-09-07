import Foundation

/// The Bestiary's one Page.
///
/// Shares the Book Notices type, the way the grimoire does and for the same
/// reasons: the reader already knows that shape and it already carries the
/// correction machinery. It is its own source, so its cadence, rest and
/// evidence belong to it.
///
/// The rest is kept in the archive rather than in a counter. Every Page this
/// source puts out carries a tag naming exactly what was said — the creature and
/// the kind — and the next reading looks for that tag before saying it again. A
/// counter would eventually disagree with the Pages; the Pages can't disagree
/// with themselves.
struct BestiaryPageSourceAdapter: BookPageSourceAdapter {
    static let sourceID = "the-bestiary"

    let source = BookPageSourceRegistry.source(
        id: BestiaryPageSourceAdapter.sourceID,
        fallbackType: .bookNotices
    )

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive else { return [] }
        // One at a time. The file is a slow thing and there is no version of
        // this that is improved by two of them in a morning.
        guard !day.pages.contains(where: { $0.sourceID == source.id }) else { return [] }
        guard let notice = Bestiary.notice(
            days: inputs.days + [day], anchors: inputs.anchors, now: now
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
        if let notice = Bestiary.notice(
            days: inputs.days + [day], anchors: inputs.anchors, now: now
        ) {
            return surface(for: notice, day: day, now: now)
        }
        return SurfacePage.handOpened(
            source: source, day: day, now: now,
            intent: .reflect, renderStyle: .loreLetter, score: 40,
            metadata: ["bestiaryEmpty": "true"],
            tags: ["bestiary"]
        )
    }

    /// What the reader shuts when they shut this. Keyed to the creature and the
    /// kind, so shutting "no crows since April" never silences the day a crow
    /// comes back.
    private func observationKey(for notice: BestiaryNotice) -> String {
        "bestiary:\(notice.restTag)"
    }

    private func surface(for notice: BestiaryNotice, day: BookDay, now: Date) -> SurfacePage {
        var tags = ["bestiary", notice.kind.rawValue, notice.restTag]
        if let creature = notice.creature { tags.append("creature:\(creature)") }

        var metadata: [String: String] = [
            "source": source.id,
            // The existing correction machinery keys off this, so a notice can
            // be confirmed, corrected or shut with no new plumbing.
            "observationKey": observationKey(for: notice),
            "bestiaryKind": notice.kind.rawValue,
            "tags": tags.joined(separator: ","),
            "adaptiveActions": notice.kind == .commission ? "" : "confirmReading,correctReading"
        ]
        if let creature = notice.creature { metadata["bestiaryCreature"] = creature }
        if let loreID = notice.loreID { metadata["bestiaryLoreID"] = loreID }
        if let group = notice.group { metadata["bestiaryGroup"] = group.rawValue }
        if !notice.evidencePageIDs.isEmpty {
            metadata["evidencePageIDs"] = notice.evidencePageIDs.joined(separator: ",")
        }

        return SurfacePage(
            id: "\(source.id)-\(notice.restTag)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: notice.kind == .commission ? .capture : .reflect,
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

    /// Ranked by how much of it will still be true next week. An errand the
    /// reader completed and a creature seen for the first time are both
    /// perishable; a gap in the file will keep.
    static func score(for kind: BestiaryNoticeKind) -> Int {
        switch kind {
        case .brought: return 92
        case .firstOfItsKind: return 84
        case .theReturn: return 78
        case .goneQuiet: return 74
        case .theCompany: return 70
        case .theLore: return 62
        case .commission: return 58
        }
    }

    static func reason(for kind: BestiaryNoticeKind) -> String {
        switch kind {
        case .brought: return "I asked you for something and you went and got it."
        case .firstOfItsKind: return "Something turned up that has never been in here before."
        case .theReturn: return "Something came back that I'd stopped expecting."
        case .goneQuiet: return "Something stopped turning up and I want to know why."
        case .theCompany: return "I found a pattern in what you photograph."
        case .theLore: return "You've met one of these now, so I can tell you about it."
        case .commission: return "There's a shape of thing my file has none of."
        }
    }
}
