import Foundation

// MARK: - The Bleed (distilled edition)
//
// The Academy's student newspaper, edited by Penny Blackletter, Records
// Clerk, Department of Attestation. The full broadsheet lives on the Mac;
// this is the pocket edition: a morning paper to start the day (weather,
// today's calendar, the latest from the Book, and a researched column on
// one of the reader's own interests) and an evening paper that looks at
// tomorrow and opens a second interest column.
//
// Delivery is two-stage on purpose: the Book surfaces an in-character
// announcement first ("the newest edition is here"), and opening it sets
// the presses running - several local-brain calls composited into one page.

enum BleedEditionKind: String, Codable, Equatable, CaseIterable {
    case morning
    case evening

    var mastheadTitle: String {
        switch self {
        case .morning: return "The Bleed - Morning Edition"
        case .evening: return "The Bleed - Evening Edition"
        }
    }

    var focusLine: String {
        switch self {
        case .morning: return "the day ahead"
        case .evening: return "tomorrow, seen from tonight"
        }
    }

    var announcementLine: String {
        switch self {
        case .morning:
            return "Hot off the press: Penny Blackletter has put the Morning Edition to bed. Weather, the day's hinges, what the Book noticed overnight, and a column on one of your own shelves."
        case .evening:
            return "The Evening Edition is set in type. Tomorrow's shape, tonight's margins, the latest from the Book, and a fresh column from your own shelf of interests."
        }
    }
}

struct BleedColumnBrief: Codable, Equatable {
    var id: String
    var title: String
    var byline: String
    /// Pre-written column text (deterministic columns), or empty when the
    /// column needs the local brain.
    var composedBody: String
    /// The structured packet a model call should write from. Empty for
    /// deterministic columns.
    var packet: String
    var maxTokens: Int

    var needsLocalBrain: Bool { composedBody.isEmpty }
}

enum TheBleedEditionBuilder {
    static let plateAssetsMetadataKey = "bleedPlateAssets"

    /// Which edition the presses would run right now. Mornings before 13:00,
    /// evenings from 16:00. The quiet afternoon belongs to the reader.
    static func editionKind(for now: Date, calendar: Calendar = .current) -> BleedEditionKind? {
        let hour = calendar.component(.hour, from: now)
        if hour >= 4 && hour < 13 { return .morning }
        if hour >= 16 { return .evening }
        return nil
    }

    static func slotID(for kind: BleedEditionKind, day: BookDay) -> String {
        "bleed-\(day.id)-\(kind.rawValue)"
    }

    // MARK: Announcement

    static func announcementSurface(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) -> SurfacePage? {
        guard let kind = editionKind(for: now, calendar: calendar) else { return nil }
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        let slot = slotID(for: kind, day: day)
        guard !day.pages.contains(where: { $0.tags.contains(slot) }) else { return nil }
        let source = BookPageSourceRegistry.source(for: .theBleed)
        let issueNumber = inputs.bleedIssueNumber
        let interest = selectedInterest(from: inputs.selfFacts, dayID: day.id, kind: kind)
        let archive = archivePages(day: day, inputs: inputs)
        let semanticPassages = semanticPassageLines(
            from: archive,
            kind: kind,
            inputs: inputs,
            now: now
        )
        let plates = selectedPlateAssets(
            day: day,
            inputs: inputs,
            kind: kind,
            now: now,
            semanticPageIDs: semanticPassages.pageIDs
        )
        let briefs = columnBriefs(
            kind: kind,
            day: day,
            inputs: inputs,
            interest: interest,
            now: now,
            calendar: calendar,
            semanticPassages: semanticPassages,
            plates: plates
        )
        let eventTags = inputs.activeWorldEvents.eventTags
        let eventLine = inputs.activeWorldEvents
            .first
            .map { "\n\nSpecial bulletin: \($0.title) - \($0.phase.title). \($0.packet.bleedInstruction ?? $0.packet.logline)" } ?? ""
        let themeLine = "\n\nTheme desk: \(themeDeskAnnouncementLine(day: day, inputs: inputs, now: now, calendar: calendar))"
        let tags = (["the-bleed", slot, "bleed-\(kind.rawValue)"] + eventTags).joined(separator: ",")

        return SurfacePage(
            id: "\(source.id)-\(slot)",
            type: .theBleed,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: kind == .morning ? 90 : 86,
            reason: inputs.activeWorldEvents.first.map { "Issue #\(issueNumber) is waiting under the door. \($0.title) has reached the press room." } ?? "Issue #\(issueNumber) is waiting under the door.",
            prompt: "The newest edition of The Bleed is here.",
            detail: inputs.activeWorldEvents.first.map { "Open it - Penny is holding the presses over \($0.title)." } ?? "Open it - Penny Blackletter is holding the presses.",
            payload: BookPagePayload(
                headline: "\(kind.mastheadTitle) - Issue #\(issueNumber)",
                body: kind.announcementLine + themeLine + eventLine,
                metadata: [
                    "source": source.id,
                    "bleedEditionKind": kind.rawValue,
                    "bleedSlotID": slot,
                    "automaticRecurrenceSlot": "announcement:\(slot)",
                    "bleedIssueNumber": "\(issueNumber)",
                    "bleedInterest": interest ?? "",
                    "bleedBriefs": encodedBriefs(briefs),
                    plateAssetsMetadataKey: encodedPlateAssets(plates),
                    "bleedPlatePageIDs": plates.compactMap { $0.metadata["bleedPlatePageID"] }.joined(separator: ","),
                    "worldEventIDs": inputs.activeWorldEvents.map(\.id).joined(separator: ","),
                    "worldEventTitles": inputs.activeWorldEvents.map(\.title).joined(separator: ", "),
                    "worldEventPacket": inputs.activeWorldEvents.influencePacket,
                    "worldEventBleedPacket": inputs.activeWorldEvents.bleedPacket,
                    "monthlyThemeStatus": currentTheme(for: day, inputs: inputs, now: now, calendar: calendar)?.stability.rawValue ?? "unnamed",
                    "placeholder": "The presses are inked and waiting. Open the edition to set them running.",
                    "tags": tags
                ]
            )
        )
    }

    // MARK: Column briefs

    static func columnBriefs(
        kind: BleedEditionKind,
        day: BookDay,
        inputs: BookSourceInputs,
        interest: String?,
        now: Date,
        calendar: Calendar = .current,
        semanticPassages: (lines: String, pageIDs: [String])? = nil,
        plates: [BookPageMediaAsset]? = nil
    ) -> [BleedColumnBrief] {
        var briefs: [BleedColumnBrief] = []

        briefs.append(BleedColumnBrief(
            id: "weather-desk",
            title: "Casement Weather",
            byline: "from the window ledge, attested",
            composedBody: weatherColumn(kind: kind, inputs: inputs),
            packet: "",
            maxTokens: 0
        ))

        briefs.append(BleedColumnBrief(
            id: "almanac",
            title: kind == .morning ? "Today at the Academy" : "Tomorrow, Posted Early",
            byline: "the corridor noticeboard",
            composedBody: almanacColumn(kind: kind, inputs: inputs, now: now, calendar: calendar),
            packet: "",
            maxTokens: 0
        ))

        briefs.append(BleedColumnBrief(
            id: "theme-desk",
            title: "Theme Desk",
            byline: "from the unstable type tray",
            composedBody: themeDeskColumn(day: day, inputs: inputs, now: now, calendar: calendar),
            packet: "",
            maxTokens: 0
        ))

        briefs.append(BleedColumnBrief(
            id: "front-page",
            title: kind == .morning ? "Penny's Morning Ledger" : "Penny's Evening Ledger",
            byline: "by Penny Blackletter, Records Clerk, Department of Attestation",
            composedBody: "",
            packet: frontPagePacket(
                kind: kind,
                day: day,
                inputs: inputs,
                now: now,
                calendar: calendar,
                semanticPassages: semanticPassages,
                plates: plates
            ),
            maxTokens: 480
        ))

        briefs.append(BleedColumnBrief(
            id: "corridor-whispers",
            title: "Corridor Whispers",
            byline: "compiled from signed corridor sources",
            composedBody: "",
            packet: whispersPacket(day: day, inputs: inputs, now: now),
            maxTokens: 280
        ))

        if let interest {
            briefs.append(BleedColumnBrief(
                id: "interest-desk",
                title: "The Reader's Shelf: \(interest.capitalized)",
                byline: "by Penny Blackletter, filed from beyond the casement",
                composedBody: "",
                packet: interestPacket(interest: interest, kind: kind),
                maxTokens: 380
            ))
        }

        return briefs
    }

    /// Morning and evening pick different interests on the same day, so the
    /// two editions never repeat a shelf.
    static func selectedInterest(from facts: [SelfFact], dayID: String, kind: BleedEditionKind) -> String? {
        let candidates = facts
            .filter { fact in
                fact.questionID.hasPrefix("interest-")
                    && fact.usePermission != .doNotUse
                    && !fact.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .flatMap { fact in
                fact.answer
                    .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.count >= 3 && $0.count <= 80 }
            }
            .reduce(into: [String]()) { unique, interest in
                if !unique.contains(where: { $0.localizedCaseInsensitiveCompare(interest) == .orderedSame }) {
                    unique.append(interest)
                }
            }
        guard !candidates.isEmpty else { return nil }
        let offset = kind == .morning ? 0 : 1
        let index = (ConstellationKeeper.stableIndex(for: "bleed-interest-\(dayID)", count: candidates.count) + offset) % candidates.count
        return candidates[index]
    }

    // MARK: Deterministic columns

    static func weatherColumn(kind: BleedEditionKind, inputs: BookSourceInputs) -> String {
        guard let weather = inputs.weather?.phrase.nonEmpty else {
            return "The casement reports nothing today; the sky declined to file. The clerk notes the omission and moves on, as clerks must."
        }
        let enchanted = inputs.enchantedWeather?.enchantified.nonEmpty
        let opening = kind == .morning
            ? "The window ledge files the following, sworn and stamped: \(weather)."
            : "As the lamps come up, the casement's last deposition reads: \(weather)."
        let translation = enchanted.map { " The Academy's own translation: \($0)" } ?? ""
        return opening + translation
    }

    static func refreshingWeatherBriefs(
        _ briefs: [BleedColumnBrief],
        kind: BleedEditionKind,
        inputs: BookSourceInputs
    ) -> [BleedColumnBrief] {
        briefs.map { brief in
            guard brief.id == "weather-desk" else { return brief }
            var refreshed = brief
            refreshed.composedBody = weatherColumn(kind: kind, inputs: inputs)
            return refreshed
        }
    }

    static func almanacColumn(
        kind: BleedEditionKind,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        guard inputs.calendarIntegrationEnabled else {
            return "The Calendar Doorway is closed, so the noticeboard makes no claim about the day. A blank board without a witness is not an empty day."
        }
        let targetDayStart: Date
        let dayWord: String
        switch kind {
        case .morning:
            targetDayStart = calendar.startOfDay(for: now)
            dayWord = "Today"
        case .evening:
            targetDayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            dayWord = "Tomorrow"
        }
        let targetDayEnd = calendar.date(byAdding: .day, value: 1, to: targetDayStart) ?? targetDayStart
        let events = inputs.calendarEvents
            .filter { $0.startsAt >= targetDayStart && $0.startsAt < targetDayEnd }
            .sorted { $0.startsAt < $1.startsAt }

        guard !events.isEmpty else {
            return "\(dayWord)'s noticeboard is bare. The corridor reads an empty board as either freedom or an ambush; the clerk recommends treating it as the former until proven otherwise."
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "h:mm a"
        let lines = events.prefix(6).map { event in
            "\u{2022} \(event.isAllDay ? "All day" : formatter.string(from: event.startsAt)) - \(event.title)"
        }.joined(separator: "\n")
        let count = events.count
        let pressure = count >= 4
            ? "A crowded board. The clerk advises guarding one unclaimed hour the way one guards a window seat."
            : "A reasonable board, by Registry standards."
        return "\(dayWord)'s hinges, as posted:\n\(lines)\n\(pressure)"
    }

    static func refreshingAlmanacBriefs(
        _ briefs: [BleedColumnBrief],
        kind: BleedEditionKind,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) -> [BleedColumnBrief] {
        briefs.map { brief in
            guard brief.id == "almanac" else { return brief }
            var refreshed = brief
            refreshed.composedBody = almanacColumn(
                kind: kind,
                inputs: inputs,
                now: now,
                calendar: calendar
            )
            return refreshed
        }
    }

    static func themeDeskColumn(
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let monthKey = BookThemeEngine.monthKey(for: now, calendar: calendar)
        let monthPages = pagesForThemeDesk(day: day, inputs: inputs, monthKey: monthKey, calendar: calendar)
        let observedDays = BookThemeEngine.observedDayCount(for: monthPages, calendar: calendar)

        guard let theme = currentTheme(for: day, inputs: inputs, now: now, calendar: calendar) else {
            if observedDays < BookThemeEngine.minimumObservedDaysForTheme {
                let remaining = BookThemeEngine.minimumObservedDaysForTheme - observedDays
                let dayWord = remaining == 1 ? "one more kept day" : "\(remaining) more kept days"
                return "No monthly theme has been named yet. The Book waits for \(dayWord) before pretending a month has a weather system."
            }
            return "No monthly theme has been named yet. There are enough days on file, but the motifs have not repeated loudly enough for a responsible headline."
        }

        switch theme.stability {
        case .provisional:
            let remaining = max(0, BookThemeEngine.stableObservedDaysForTheme - theme.observedDayCount)
            let dayLine = remaining == 1
                ? "one more kept day could settle it"
                : "\(remaining) more kept days could settle it"
            return """
            UNSTABLE THEME WATCH: \(theme.name).
            \(theme.line)
            The Book has seen this across \(theme.observedDayCount) kept days; \(dayLine). Penny advises reading the headline in pencil.
            """
        case .stable:
            return """
            STABLE MONTHLY THEME: \(theme.name).
            \(theme.line)
            The Book has seen this across \(theme.observedDayCount) kept days. The headline is now set in type for the month.
            """
        }
    }

    // MARK: Model packets

    static func frontPagePacket(
        kind: BleedEditionKind,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date? = nil,
        calendar: Calendar = .current,
        semanticPassages suppliedSemanticPassages: (lines: String, pageIDs: [String])? = nil,
        plates suppliedPlates: [BookPageMediaAsset]? = nil
    ) -> String {
        let pressTime = now ?? day.date
        let archive = archivePages(day: day, inputs: inputs)
        let signals = inputs.continuity.strongestSignals.prefix(6).map {
            "- [\($0.kind.rawValue), strength \($0.strength)] \($0.promptLine)"
        }.joined(separator: "\n")
        let sensorySignals = inputs.continuity.strongestSignals
            .filter { $0.kind == .sensory }
            .prefix(3)
            .map { "- \($0.promptLine) [evidence: \($0.evidencePageIDs.joined(separator: ", "))]" }
            .joined(separator: "\n")
        let constellations = ConstellationKeeper.namedConstellations(inputs.constellations).prefix(3)
            .map { "- \($0.displayName): \($0.latestLine)" }
            .joined(separator: "\n")
        let wagers = inputs.wagers.filter(\.isSealed).prefix(2).map { "- \($0.promptLine)" }.joined(separator: "\n")
        let theme = themeDeskColumn(day: day, inputs: inputs, now: pressTime, calendar: calendar)
        let arc = inputs.currentArc.map { "Current story arc: \($0.title), phase \($0.phase.rawValue)." } ?? "No arc currently promoted."
        let eventPacket = inputs.activeWorldEvents.bleedPacket.nonEmpty ?? "No authored world event is currently changing the press room."
        let recentPages = day.capturedPages.suffix(5)
            .map { "- \($0.promptText): \($0.userInput.bookPreviewSentenceLimit(1))" }
            .joined(separator: "\n")
        let semanticPassages = suppliedSemanticPassages ?? semanticPassageLines(
            from: archive, kind: kind, inputs: inputs, now: pressTime
        )
        let multimodalWitnesses = multimodalWitnessLines(
            from: archive,
            preferredPageIDs: Set(semanticPassages.pageIDs)
        )
        let livedReceipts = livedReceiptLines(from: archive)
        let plates = suppliedPlates ?? selectedPlateAssets(
            day: day,
            inputs: inputs,
            kind: kind,
            now: pressTime,
            semanticPageIDs: semanticPassages.pageIDs
        )
        let plateLines = plates.map { plate in
            "- [page \(plate.metadata["bleedPlatePageID"] ?? "unknown")] \(plate.caption)"
        }.joined(separator: "\n")
        return """
        EDITION: \(kind.mastheadTitle), focused on \(kind.focusLine).

        WHOLE-ARCHIVE LITERARY OBSERVATIONS (readings, not verdicts):
        \(signals.nonEmpty ?? "- The margins are quiet.")

        SEMANTICALLY SELECTED PASSAGES (reader-authored evidence chosen for this edition, not merely the newest pages):
        \(semanticPassages.lines.nonEmpty ?? "- No passage cleared the evidence threshold.")

        MULTIMODAL WITNESSES (local receipts; report only the supplied objects, light, composition, voice form, or proof kind):
        \(multimodalWitnesses.nonEmpty ?? "- No cross-sense witness is on file.")

        CROSS-MEDIA CONTINUITY (a finding, not a fact about the reader):
        \(sensorySignals.nonEmpty ?? "- No mature cross-media connection is on file.")

        LIVED QUEST RECEIPTS (completion evidence, not proof of permanent change):
        \(livedReceipts.nonEmpty ?? "- No lived receipt is relevant yet.")

        SELECTED ILLUSTRATION PLATES (these appear in the issue; captions must not exceed their filed provenance):
        \(plateLines.nonEmpty ?? "- No visual plate was selected.")

        Named constellations the Book keeps about the reader:
        \(constellations.nonEmpty ?? "- None named yet.")

        Sealed wagers pending:
        \(wagers.nonEmpty ?? "- None.")

        Theme desk:
        \(theme)
        \(arc)

        Active world-event desk:
        \(eventPacket)

        The reader's own kept pages today:
        \(recentPages.nonEmpty ?? "- No pages kept yet today.")

        EDITORIAL EVIDENCE LAW:
        - Build the column around one newsworthy reading supported by at least two supplied items.
        - Prefer an unexpected crossing between different evidence kinds over a recap.
        - Name tensions or contrary evidence when the packet contains them.
        - A photograph may attest objects, light, palette, and composition; it may not diagnose a person or prove an emotion.
        - A voice receipt may attest pace, pauses, cadence, or energy only; it may not infer mood, health, or identity.
        - A lived receipt proves that evidence returned, not that the reader was transformed.
        - Never turn a literary observation into a clinical, causal, or permanent claim.
        """
    }

    static func whispersPacket(day: BookDay, inputs: BookSourceInputs, now: Date) -> String {
        let gossip = GossipSimulationBuilder.surface(for: day, inputs: inputs, now: now)
        return """
        This column is a newspaper setting of the same source packet used by a Gossip Page.
        Preserve its causal ledger and its finished-page social shape.

        \(GossipPageForm.sourcePacket(for: gossip))
        """
    }

    private static func archivePages(day: BookDay, inputs: BookSourceInputs) -> [BookPage] {
        let pages = (inputs.days + [day]).flatMap(\.pages)
        return Dictionary(pages.map { ($0.id, $0) }, uniquingKeysWith: { left, right in
            left.createdAt >= right.createdAt ? left : right
        })
        .values
        .sorted { $0.createdAt < $1.createdAt }
    }

    private static func semanticPassageLines(
        from pages: [BookPage],
        kind: BleedEditionKind,
        inputs: BookSourceInputs,
        now: Date
    ) -> (lines: String, pageIDs: [String]) {
        var queryParts = [
            kind.focusLine,
            inputs.currentArc?.title
        ].compactMap { $0 }
        queryParts += inputs.continuity.strongestSignals.prefix(6).flatMap {
            [$0.subjectName, $0.line] + Array($0.tags.prefix(4))
        }
        queryParts += inputs.clusters.sorted { $0.strength > $1.strength }.prefix(3).flatMap {
            [$0.name, $0.line] + Array($0.motifs.prefix(4))
        }
        queryParts += inputs.themes.sorted { $0.strength > $1.strength }.prefix(2).flatMap {
            [$0.name, $0.line] + Array($0.motifs.prefix(4))
        }
        let query = queryParts.joined(separator: ". ")
        let scorer: StacksSemanticScoring? = inputs.semanticPassageSelectionEnabled
            ? SemanticKeepEcho.keepTimeScorer
            : nil
        let selections = MeaningfulPassageSelector.rankedSelections(
            pages: pages,
            query: query,
            inputs: inputs,
            scorer: scorer,
            limit: 4,
            maximumAge: 365 * 86_400,
            minimumScore: 12,
            honorPriorUse: false,
            diversifyPageTypes: true,
            now: now
        )
        let lines = selections.map { selection in
            let semantic = selection.semanticSimilarity.map { String(format: "%.2f", $0) } ?? "lexical"
            return "- [page \(selection.pageID), \(selection.pageType.shortTitle), relevance \(semantic)] \"\(selection.excerpt)\""
        }.joined(separator: "\n")
        return (lines, selections.map(\.pageID))
    }

    private static func multimodalWitnessLines(
        from pages: [BookPage],
        preferredPageIDs: Set<String>
    ) -> String {
        let witnesses = pages
            .filter { page in
                guard page.origin == .userAuthored || page.origin == .imported,
                      !EditionCurator.defaultPrivateTypes.contains(page.type) else {
                    return false
                }
                let modalities = page.resolvedSensoryFolio.modalities
                return !page.mediaAssets.isEmpty
                    || modalities.contains("photo")
                    || modalities.contains("voice")
                    || page.livedQuestReceipt?.hasVisualProof == true
            }
            .sorted { left, right in
                let leftPreferred = preferredPageIDs.contains(left.id)
                let rightPreferred = preferredPageIDs.contains(right.id)
                if leftPreferred != rightPreferred { return leftPreferred }
                return left.createdAt > right.createdAt
            }
            .prefix(4)

        return witnesses.map { page in
            let folio = page.resolvedSensoryFolio
            let modalities = folio.modalities.sorted().joined(separator: " + ").nonEmpty ?? "media"
            let subjects = folio.values(for: .subject).prefix(4).joined(separator: ", ")
            let visual = [
                folio.values(for: .palette).first.map { "palette \($0)" },
                folio.values(for: .brightness).first.map { "light \($0)" },
                folio.values(for: .composition).first.map { "composition \($0)" }
            ].compactMap { $0 }.joined(separator: "; ")
            let voice = [
                folio.values(for: .voiceCadence).first.map { "cadence \($0)" },
                folio.values(for: .voicePause).first.map { "pauses \($0)" },
                folio.values(for: .voiceEnergy).first.map { "energy \($0)" }
            ].compactMap { $0 }.joined(separator: "; ")
            let details = [
                subjects.nonEmpty.map { "subjects \($0)" },
                visual.nonEmpty,
                voice.nonEmpty
            ].compactMap { $0 }.joined(separator: "; ")
            let excerpt = page.archivePreviewText?.bookPreviewSentenceLimit(1).nonEmpty
                .map { " Reader words: \"\($0)\"" } ?? ""
            return "- [page \(page.id), \(modalities)] \(details.nonEmpty ?? "Media receipt kept without descriptive observations.").\(excerpt)"
        }.joined(separator: "\n")
    }

    private static func livedReceiptLines(from pages: [BookPage]) -> String {
        pages.compactMap { page -> (Date, String)? in
            guard let receipt = page.livedQuestReceipt,
                  receipt.hasWrittenProof || receipt.hasVisualProof else { return nil }
            let proof = [
                receipt.hasWrittenProof ? "written" : nil,
                receipt.hasVisualProof ? "photograph" : nil
            ].compactMap { $0 }.joined(separator: " + ")
            let facets = receipt.facets.prefix(4).map(\.title).joined(separator: ", ")
            return (
                receipt.completedAt,
                "- \(receipt.title) [\(proof) evidence; facets: \(facets); page \(page.id)]"
            )
        }
        .sorted { $0.0 > $1.0 }
        .prefix(4)
        .map(\.1)
        .joined(separator: "\n")
    }

    static func interestPacket(interest: String, kind: BleedEditionKind) -> String {
        """
        READER INTEREST: \(interest)
        EDITION: \(kind.rawValue)

        Live web clippings (filled in at press time):
        {{CLIPPINGS}}
        """
    }

    // MARK: Compositing

    /// Assembles written columns into the final page body. Columns appear
    /// in brief order; the masthead and colophon are the builder's.
    static func compositedBody(
        kind: BleedEditionKind,
        issueNumber: Int,
        columns: [(brief: BleedColumnBrief, body: String)],
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        var parts: [String] = [
            """
            \(kind.mastheadTitle.uppercased())
            Issue #\(issueNumber) \u{00B7} \(formatter.string(from: now))
            Where the Labyrinth meets the page. Where the page bleeds into the world.
            """
        ]
        for column in columns {
            let body = column.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            parts.append("""
            \u{2014} \(column.brief.title.uppercased()) \u{2014}
            \(column.brief.byline)

            \(body)
            """)
        }
        parts.append("Set in type by P. Blackletter, who attests every word and regrets several.")
        return parts.joined(separator: "\n\n")
    }

    static func preparedCopy(
        of announcement: SurfacePage,
        body: String,
        interestSources: String
    ) -> SurfacePage {
        var metadata = announcement.payload.metadata
        metadata["bleedProse"] = body
        metadata["bleedInterestSources"] = interestSources
        if let slot = metadata["bleedSlotID"]?.nonEmpty {
            metadata["automaticRecurrenceSlot"] = "edition:\(slot)"
        }
        metadata.removeValue(forKey: "placeholder")
        return SurfacePage(
            id: announcement.id,
            type: announcement.type,
            sourceID: announcement.sourceID,
            intent: announcement.intent,
            renderStyle: announcement.renderStyle,
            score: announcement.score,
            reason: announcement.reason,
            prompt: announcement.payload.metadata["bleedEditionKind"] == BleedEditionKind.morning.rawValue
                ? "The Morning Edition, unfolded."
                : "The Evening Edition, unfolded.",
            detail: "Read it by lamplight, and keep the bits that feel too good to lose.",
            payload: BookPagePayload(
                headline: announcement.payload.headline,
                body: body,
                metadata: metadata
            )
        )
    }

    static func decodedBriefs(_ encoded: String) -> [BleedColumnBrief] {
        guard let data = encoded.data(using: .utf8),
              let briefs = try? JSONDecoder().decode([BleedColumnBrief].self, from: data) else {
            return []
        }
        return briefs
    }

    static func decodedPlateAssets(_ encoded: String) -> [BookPageMediaAsset] {
        guard let data = encoded.data(using: .utf8),
              let assets = try? JSONDecoder().decode([BookPageMediaAsset].self, from: data) else {
            return []
        }
        return assets
    }

    private static func encodedBriefs(_ briefs: [BleedColumnBrief]) -> String {
        guard let data = try? JSONEncoder().encode(briefs) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func encodedPlateAssets(_ assets: [BookPageMediaAsset]) -> String {
        guard !assets.isEmpty,
              let data = try? JSONEncoder().encode(assets) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func selectedPlateAssets(
        day: BookDay,
        inputs: BookSourceInputs,
        kind: BleedEditionKind,
        now: Date,
        semanticPageIDs: [String]? = nil
    ) -> [BookPageMediaAsset] {
        let archive = archivePages(day: day, inputs: inputs)
        let semanticRanks = Dictionary(
            uniqueKeysWithValues: (semanticPageIDs ?? semanticPassageLines(
                from: archive,
                kind: kind,
                inputs: inputs,
                now: now
            ).pageIDs).enumerated().map { ($0.element, 200 - $0.offset * 20) }
        )
        let continuityStrength = inputs.continuity.strongestSignals.reduce(into: [String: Int]()) { scores, signal in
            for pageID in signal.evidencePageIDs {
                scores[pageID] = max(scores[pageID] ?? 0, signal.strength)
            }
        }

        let candidates = archive.compactMap { page -> (BookPage, BookPageMediaAsset, Int)? in
            guard now.timeIntervalSince(page.createdAt) >= 0,
                  now.timeIntervalSince(page.createdAt) <= 45 * 86_400,
                  page.origin == .userAuthored
                    || page.origin == .imported
                    || page.type == .illustration
                    || page.type == .illuminatedPhoto,
                  !EditionCurator.defaultPrivateTypes.contains(page.type),
                  page.externalReference?.allowsWeaving != false else {
                return nil
            }
            let isPagewright = page.sourceID == "pagewright"
                || page.sourceID == "plain-page"
                || page.tags.contains("pagewright")
                || page.tags.contains("scrapbook")
            let isSharedVisual = page.externalReference != nil && !page.mediaAssets.isEmpty
            guard page.type == .illuminatedPhoto
                    || page.type == .illustration
                    || isPagewright
                    || isSharedVisual else {
                return nil
            }
            guard let sourceAsset = page.mediaAssets.first(where: { asset in
                guard asset.kind != .audioFile else { return false }
                let format = asset.metadata["format"]?.lowercased() ?? ""
                return format != "pdf" && !asset.reference.lowercased().hasSuffix(".pdf")
            }) else {
                return nil
            }

            let provenance: String
            if page.type == .illuminatedPhoto {
                provenance = "a kept illuminated photograph"
            } else if page.type == .illustration {
                provenance = "a kept Illustration Page"
            } else if isPagewright {
                provenance = "a kept Pagewright page"
            } else {
                provenance = "a shared visual from \(page.externalReference?.sourceName.nonEmpty ?? "another app")"
            }
            let captionTitle = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? sourceAsset.caption.nonEmpty
                ?? page.type.title
            var metadata = sourceAsset.metadata
            metadata["bleedPlatePageID"] = page.id
            metadata["bleedPlateProvenance"] = provenance
            metadata["bleedPlateOriginalSourceID"] = page.sourceID
            metadata["bleedPlateCaption"] = "\(captionTitle): \(provenance)."
            let plate = BookPageMediaAsset(
                id: "bleed-plate-\(page.id)-\(sourceAsset.id)",
                kind: sourceAsset.kind,
                reference: sourceAsset.reference,
                caption: metadata["bleedPlateCaption"] ?? captionTitle,
                sourceID: sourceAsset.sourceID.nonEmpty ?? page.sourceID,
                metadata: metadata
            )

            let ageDays = Int(now.timeIntervalSince(page.createdAt) / 86_400)
            var score = semanticRanks[page.id] ?? 0
            score += continuityStrength[page.id] ?? 0
            score += max(0, 45 - ageDays)
            if page.type == .illuminatedPhoto { score += 24 }
            if isPagewright { score += 18 }
            if isSharedVisual { score += 14 }
            return (page, plate, score)
        }
        .sorted { left, right in
            if left.2 == right.2 { return left.0.createdAt > right.0.createdAt }
            return left.2 > right.2
        }

        var selected: [BookPageMediaAsset] = []
        var seenReferences = Set<String>()
        for candidate in candidates where selected.count < 2 {
            guard seenReferences.insert("\(candidate.1.kind.rawValue):\(candidate.1.reference)").inserted else {
                continue
            }
            selected.append(candidate.1)
        }
        return selected
    }

    private static func themeDeskAnnouncementLine(
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar
    ) -> String {
        guard let theme = currentTheme(for: day, inputs: inputs, now: now, calendar: calendar) else {
            return "no monthly theme has been named yet."
        }
        switch theme.stability {
        case .provisional:
            return "\(theme.name) is still unstable and may update as the month gathers evidence."
        case .stable:
            return "\(theme.name) is stable for the month."
        }
    }

    private static func currentTheme(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar
    ) -> BookTheme? {
        let monthKey = BookThemeEngine.monthKey(for: now, calendar: calendar)
        return BookThemeEngine.theme(forMonth: monthKey, in: inputs.themes)
    }

    private static func pagesForThemeDesk(
        day: BookDay,
        inputs: BookSourceInputs,
        monthKey: String,
        calendar: Calendar
    ) -> [BookPage] {
        (inputs.days + [day])
            .flatMap(\.pages)
            .filter { BookThemeEngine.monthKey(for: $0.createdAt, calendar: calendar) == monthKey }
    }
}

struct TheBleedPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .theBleed)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        if let prepared = inputs.preparedBleedEditionSurface,
           let kind = TheBleedEditionBuilder.editionKind(for: now),
           prepared.payload.metadata["bleedSlotID"] == TheBleedEditionBuilder.slotID(for: kind, day: day),
           !day.pages.contains(where: { $0.tags.contains(TheBleedEditionBuilder.slotID(for: kind, day: day)) }) {
            return [prepared]
        }
        guard let announcement = TheBleedEditionBuilder.announcementSurface(for: day, inputs: inputs, now: now) else {
            return []
        }
        return [announcement]
    }
}
