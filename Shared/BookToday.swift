import Foundation

/// A reader-facing projection of state the Book already owns. This is not a
/// second curator and stores no competing truth. It gives the existing session
/// score, world, Interior, and archive one composed daily frontispiece.
struct BookTodayEdition: Equatable {
    enum BeatKind: String, Equatable {
        case atTheWindows
        case inTheMargins
        case underTheBinding
        case byNightfall

        var title: String {
            switch self {
            case .atTheWindows: return "At the Windows"
            case .inTheMargins: return "In the Margins"
            case .underTheBinding: return "Under the Binding"
            case .byNightfall: return "By Nightfall"
            }
        }

        var symbolName: String {
            switch self {
            case .atTheWindows: return "window.casement"
            case .inTheMargins: return "text.quote"
            case .underTheBinding: return "bookmark"
            case .byNightfall: return "moon.stars"
            }
        }
    }

    struct Beat: Equatable, Identifiable {
        var id: String { kind.rawValue }
        var kind: BeatKind
        var line: String
        var symbolName: String
    }

    /// A few drawers from the Book's accumulated life, chosen afresh for one
    /// opening. The underlying counts never wobble; only which honest facts the
    /// Book feels like mentioning changes.
    struct Census: Equatable {
        struct Fact: Equatable, Identifiable {
            var id: String
            var value: Int
            var line: String
            var symbolName: String
        }

        var title: String
        var begunAt: Date?
        var pageCount: Int
        var facts: [Fact]
        var closingLine: String
        /// What the Book and the Academy got up to in the last day, while the Reader was elsewhere.
        var whileAway: [Fact] = []
    }

    /// Something of the Reader's own, quoted back: a recent line in their hand, or a photograph.
    struct Keepsake: Equatable {
        var pageID: String
        var label: String
        var text: String?
        var photo: BookPageMediaAsset?
        var aside: String
    }

    /// The paper on the mat: this edition's front page, before or after it's printed.
    struct Doorstep: Equatable {
        var kind: BleedEditionKind
        var kicker: String
        var headline: String
        var line: String
    }

    /// The day's outward invitation, shared with the morning paper.
    struct Assignment: Equatable {
        var dareID: String
        var title: String
        var challenge: String
        var filed: Bool
        var page: SurfacePage? = nil
    }

    var dayID: String
    var headline: String
    var reading: String
    var atmosphereSymbolName: String
    var marginalMark: String?
    var beats: [Beat]
    var census: Census
    var keepsake: Keepsake? = nil
    var doorstep: Doorstep? = nil
    var assignment: Assignment? = nil
    /// More of the margins than the one beat: the Cast's business, a line each.
    var margins: [Beat] = []
}

enum BookTodayProjector {
    static func edition(
        for day: BookDay,
        inputs: BookSourceInputs,
        relationship: BookRelationshipSnapshot,
        experienceProgram: BookExperienceProgram?,
        now: Date = Date(),
        calendar: Calendar = .current,
        selectionSeed: Int = 0
    ) -> BookTodayEdition {
        let intention = inputs.activeBookSessionIntention.flatMap {
            $0.isActive(on: day.id, now: now) ? $0 : nil
        }
        let event = inputs.activeWorldEvents.first
        let weather = inputs.enchantedWeather?.enchantified.nonEmpty
            ?? inputs.weather?.phrase.nonEmpty
        let hour = calendar.component(.hour, from: now)

        var beats: [BookTodayEdition.Beat] = []
        if let event {
            beats.append(.init(
                kind: .atTheWindows,
                line: "I found \(event.title) loose in my Pages. \(event.phase.scene?.nonEmpty ?? event.subtitle)",
                symbolName: "sparkles"
            ))
        } else if let weather {
            beats.append(.init(
                kind: .atTheWindows,
                line: "\(weather) I've left the window unlatched.",
                symbolName: inputs.enchantedWeather?.symbolName
                    ?? inputs.weather?.conditionSymbolName
                    ?? "cloud.sun"
            ))
        } else if let place = inputs.currentPlaceContext {
            beats.append(.init(
                kind: .atTheWindows,
                line: "I know this place. It's \(place.title). I'm having a good sniff before I say anything.",
                symbolName: "location"
            ))
        }

        let marginLines = marginBeats(
            inputs: inputs,
            event: event,
            dayID: day.id,
            now: now,
            selectionSeed: selectionSeed
        )
        if let margin = marginLines.first {
            beats.append(margin)
        }

        if let cue = experienceProgram?.pageCues
            .filter({ $0.stage != .displayed && $0.stage != .dismissed })
            .max(by: { $0.lastInteractionAt < $1.lastInteractionAt }) {
            beats.append(.init(
                kind: .underTheBinding,
                line: consequenceLine(for: cue.stage),
                symbolName: cue.stage == .loved ? "heart.fill" : "bookmark.fill"
            ))
        } else if let latest = day.capturedPages.max(by: { $0.createdAt < $1.createdAt }) {
            beats.append(.init(
                kind: .underTheBinding,
                line: underBindingLine(for: latest),
                symbolName: "bookmark.fill"
            ))
        }

        if let intention {
            beats.append(.init(
                kind: .byNightfall,
                line: nightfallLine(for: intention, hour: hour),
                symbolName: hour >= 18 ? "moon.stars.fill" : "hourglass"
            ))
        } else if hour >= 19 {
            beats.append(.init(
                kind: .byNightfall,
                line: "I'll keep the good bits. The rest of the day can go where it likes.",
                symbolName: "moon.stars"
            ))
        }

        let mark = marginalMark(grimoire: inputs.grimoire) ?? marginalMark(inputs.bookInterior)
        let reading = readingLine(
            intention: intention,
            weatherPresent: weather != nil,
            eventPresent: event != nil,
            relationship: relationship,
            hour: hour,
            today: day,
            yesterday: inputs.days.last {
                calendar.isDate($0.date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
            },
            selectionSeed: selectionSeed
        )
        return BookTodayEdition(
            dayID: day.id,
            headline: headline(
                intention: intention,
                event: event,
                mark: mark,
                hour: hour
            ),
            reading: reading,
            atmosphereSymbolName: inputs.enchantedWeather?.symbolName
                ?? inputs.weather?.conditionSymbolName
                ?? (hour >= 18 || hour < 5 ? "moon.stars" : "book.closed"),
            marginalMark: mark,
            beats: Array(beats.prefix(4)),
            census: BookTodayCensusProjector.census(
                for: day,
                inputs: inputs,
                relationship: relationship,
                now: now,
                calendar: calendar,
                selectionSeed: selectionSeed
            ),
            keepsake: BookTodayDoorstep.keepsake(day: day, inputs: inputs, now: now, calendar: calendar,
                                                 selectionSeed: selectionSeed),
            doorstep: BookTodayDoorstep.paper(day: day, inputs: inputs, now: now, calendar: calendar),
            assignment: BookTodayDoorstep.assignment(day: day, inputs: inputs, now: now, calendar: calendar),
            margins: Array(marginLines.dropFirst().prefix(2))
        )
    }

    /// The headline is the shelf subtitle, line-clipped, so it never carries
    /// the weather. The At the Windows beat
    /// is the one place the forecast is written out in full.
    private static func headline(
        intention: BookSessionIntention?,
        event: ResolvedWorldEvent?,
        mark: String?,
        hour: Int
    ) -> String {
        if let event {
            return "\(event.title) has got into my Stacks."
        }
        if let live = intention?.liveOpportunity {
            return liveOpportunityHeadline(live.kind)
        }
        if let mark {
            return "\(capitalized(mark))."
        }
        if hour < 11 {
            return "The day hasn't picked a name yet. I'm listening."
        }
        if hour >= 20 {
            return "I'm gathering the day's loose pages."
        }
        return "Something ordinary is up to something. I'm watching it."
    }

    private static func readingLine(
        intention: BookSessionIntention?,
        weatherPresent: Bool,
        eventPresent: Bool,
        relationship: BookRelationshipSnapshot,
        hour: Int,
        today: BookDay,
        yesterday: BookDay?,
        selectionSeed: Int
    ) -> String {
        guard let intention else {
            // What the Reader actually kept is the best thing the Book can talk about.
            func word(in day: BookDay?) -> (word: String, count: Int)? {
                guard let day, !DistressSignals.evaluate(day: day).isActive else { return nil }
                let written = day.capturedPages.filter { $0.type != .theBleed && $0.readerAuthoredTextForAnalysis?.nonEmpty != nil }
                    .sorted { $0.createdAt > $1.createdAt }
                guard let found = written.lazy
                    .filter({ !BookTodayDoorstep.isHeavy($0) })
                    .compactMap({ $0.readerAuthoredTextForAnalysis.flatMap(BookTodayDoorstep.thing(in:)) })
                    .first else { return nil }
                return (found, written.count)
            }
            let key = "\(today.id)|\(selectionSeed)|reading"
            if let (found, count) = word(in: today) {
                let kept = count == 1 ? "one Page" : "\(BleedDayDesk.numberWord(count)) Pages"
                return BookTodayCensusProjector.variant([
                    "You've kept \(kept) today. I keep going back to the \(found).",
                    "\(kept.prefix(1).uppercased() + kept.dropFirst()) so far, and one of them has a \(found) in it. I'm keeping an eye on the \(found).",
                    "Today's got a \(found) in it now. I didn't put it there. You did."
                ], key: key)
            }
            if let (found, _) = word(in: yesterday) {
                return BookTodayCensusProjector.variant([
                    "Yesterday's still warm on my pages. I keep thinking about the \(found).",
                    "I read yesterday again while you slept. The \(found) was still there.",
                    "The \(found) from yesterday hasn't left. I don't think it wants to."
                ], key: key)
            }
            if weatherPresent || eventPresent {
                return "Today's already making a racket. I'm after the one strange bit with muddy shoes."
            }
            return relationship.depth == .firstPages
                ? "I don't know enough yet. Good. I'm watching."
                : "Nothing strange has happened yet. I'm not going to make one up."
        }
        let opening = hour < 12 ? "This morning" : (hour < 18 ? "Today" : "This evening")
        return "\(opening), I'm \(attemptLine(for: intention.movement)) \(ambitionEnding(intention.ambition))"
    }

    private static func attemptLine(for movement: BookReenchantmentMovement) -> String {
        switch movement {
        case .freshSight: return "trying to find one thing you've stopped seeing."
        case .livingWorld: return "looking for proof the world is up to something without you."
        case .scriptFreedom: return "trying to knock one bit of the usual day off its rails."
        case .chosenDetour: return "keeping an eye out for a good wrong turn."
        case .exactLanguage: return "hunting for the exact word for something."
        case .humanOtherness: return "curious about somebody else in your day."
        case .livingContinuity: return "fetching something old back to see you."
        case .shelter: return "keeping quiet and staying close."
        }
    }

    private static func ambitionEnding(_ ambition: BookSessionAmbition) -> String {
        switch ambition {
        case .glint: return "One glint will do."
        case .connection: return "I want to join two things up. I don't need an answer."
        case .return: return "Something's sniffing its way back."
        case .intervention: return "I think something today is worth a go."
        case .revelation: return "I suspect two distant things have been passing notes."
        }
    }

    private static func nightfallLine(
        for intention: BookSessionIntention,
        hour: Int
    ) -> String {
        if intention.liveOpportunity != nil {
            return "It won't last. I've put the doors for it in the Pages above."
        }
        if hour >= 18 {
            return "I want to see what follows you home."
        }
        return "By tonight I want one thing today couldn't have done without you."
    }

    private static func consequenceLine(for stage: BookExperienceCueStage) -> String {
        switch stage {
        case .opened: return "You opened a Page and left it open. It's still warm. I'm not nagging."
        case .acted: return "Something got out of a Page and into your day. I'm waiting to hear what happened."
        case .kept: return "A kept Page has crawled under my binding. It's staying."
        case .loved: return "You liked one Page more than the others. I've folded its corner down."
        case .displayed: return "A Page is waiting without tapping the glass."
        case .dismissed: return "One Page got sent away. It's sulking under the furniture."
        }
    }

    /// A mark from the accumulated grimoire, when it has one to make.
    ///
    /// Above the Interior's own business on purpose: the Book owing the reader
    /// a correction, or having just let a conviction go, is a larger thing than
    /// its ribbon being cross.
    private static func marginalMark(grimoire: GrimoireLedger) -> String? {
        if grimoire.crossedOut.contains(where: { $0.lastSpokenAt == nil }) {
            return "I have something to take back"
        }
        let held = grimoire.rows.values.filter { $0.state == .standing }.count
        if held >= GrimoireLedger.Bars.maximumHeld { return "my head is full of your rules" }
        if held > 0 { return "I'm sure of \(held) of your rules" }
        if grimoire.rows.values.contains(where: { $0.state == .watching }) {
            return "I'm counting something about you"
        }
        return nil
    }

    private static func marginalMark(_ interior: BookInteriorState) -> String? {
        if interior.secret?.status == .ready { return "a sealed leaf is ready" }
        if interior.promise?.status == .keeping { return "one promise is keeping watch" }
        if interior.opinion?.strength == .reconsidering { return "I'm revising myself" }
        if let business = interior.runningBusiness, business.hasUnpresentedChange {
            switch business.kind {
            case .ribbonDispute: return "my ribbon's started something"
            case .indexDispute: return "my Index is sulking alphabetically"
            case .eraserVindication: return "my eraser wants a crown"
            }
        }
        if interior.currentDispute != nil { return "an argument is loose in my margins" }
        if interior.longGame?.hasUnannouncedPhase == true {
            return "my big plan moved a step"
        }
        if interior.favorite?.firstPresentedAt == nil, interior.favorite != nil {
            return "one Page has been dog-eared"
        }
        return nil
    }

    /// One unresolved Academy question is allowed to persist, but it must not
    /// recite the same jacket copy every morning. These variants stay inside
    /// the question's recorded positions and evidence; the opening seed merely
    /// decides whose pencil is uppermost this time.
    private static func contestedMarginLine(
        for question: ContestedQuestion,
        dayID: String,
        selectionSeed: Int
    ) -> String {
        let subject = question.question
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? "the question with too many fingerprints"
        var lines = [
            "“\(subject)” is loose in the margins again. Nobody has won the pencil.",
            "The footnotes have taken sides over “\(subject)” I'm counting who's shouting loudest.",
            "“\(subject)” has \(question.positions.count) different answers scratching at its door."
        ]

        for position in question.positions {
            guard let claim = position.claim
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty else { continue }
            if position.isSpeaking {
                lines.append(
                    "\(position.holderName) has the pencil today: “\(claim.bookPreviewSentenceLimit(1))” The margin disagrees noisily."
                )
            } else {
                lines.append(
                    "\(position.holderName) still won't answer “\(subject)” The refusal has acquired underlining."
                )
            }
        }

        if let rawEvidence = question.contradictingEvidence,
           let evidence = rawEvidence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty {
            lines.append(
                "New ink reached “\(subject)” \(evidence.bookPreviewSentenceLimit(1)) My earlier pencil is looking nervous."
            )
        }

        let key = "\(dayID)|\(selectionSeed)|\(question.id)|book-today-margin"
        let index = Int(UInt(bitPattern: key.stableHash) % UInt(lines.count))
        return lines[index]
    }

    /// A live question is continuity, not a life sentence for the margin slot.
    /// Gather every current, honest piece of marginal business and let this
    /// opening choose among them. The same opening remains stable; returning
    /// to the Book lets a different live voice reach the top of the pile.
    private static func marginBeats(
        inputs: BookSourceInputs,
        event: ResolvedWorldEvent?,
        dayID: String,
        now: Date,
        selectionSeed: Int
    ) -> [BookTodayEdition.Beat] {
        var candidates: [(line: String, symbolName: String)] = []
        var seenLines: Set<String> = []
        let cutoff = now.addingTimeInterval(-14 * 86_400)

        var entityNames: [String: String] = [:]
        for entity in NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity) {
            entityNames[entity.id] = entity.name
        }

        func entityName(_ id: String) -> String {
            entityNames[id]
                ?? id.split(separator: "-")
                    .map { $0.capitalized }
                    .joined(separator: " ")
        }

        func add(_ rawLine: String?, symbolName: String, alreadyShort: Bool = false) {
            guard let trimmed = rawLine?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty else { return }
            // A quotation is cut before it's quoted; cutting it again would lose its closing mark.
            let line = alreadyShort ? trimmed : String(trimmed.bookPreviewSentenceLimit(2).prefix(220))
            let key = line.lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
            guard !key.isEmpty, seenLines.insert(key).inserted else { return }
            candidates.append((line, symbolName))
        }

        if let question = inputs.contestedQuestions.first(where: \.isLive) {
            add(
                contestedMarginLine(
                    for: question,
                    dayID: dayID,
                    selectionSeed: selectionSeed
                ),
                symbolName: "person.2"
            )
        }

        if let dispute = inputs.bookInterior.currentDispute {
            let line: String
            if dispute.hasUnpresentedEvidence {
                line = dispute.returnCount == 0
                    ? "Our argument grew fresh claw marks. I kept your sentence beside mine."
                    : "Our old argument's chewing the margin again. Something new fed it."
            } else {
                line = "I still claim “\(dispute.bookClaim)” Your sentence is beside it, biting back."
            }
            add(line, symbolName: "text.quote")
        }

        if let business = inputs.bookInterior.runningBusiness,
           let line = business.latestLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty {
            add(line, symbolName: "text.quote")
        }

        // Academy turns: unread movement gets first claim, but recently seen
        // turns remain part of the world's current weather for a little while.
        for movement in inputs.castAgency.unwitnessedMovements
            .filter({ $0.createdAt >= cutoff })
            .prefix(4) {
            add(movement.line, symbolName: "person.2.wave.2")
        }
        for movement in inputs.castAgency.recentMovements
            .filter({ $0.createdAt >= cutoff })
            .prefix(3) {
            add(movement.line, symbolName: "figure.walk.motion")
        }

        // Relationship micro-drama, kept as exact sentences from the act
        // ledger instead of paraphrasing warmth and tension into new events.
        for act in inputs.castActs.records
            .filter({ $0.occurredAt >= cutoff })
            .sorted(by: { $0.occurredAt > $1.occurredAt })
            .prefix(4) {
            add(act.line, symbolName: "person.line.dotted.person.fill")
        }

        // The current relationship field can speak when no single act owns the
        // whole change. It describes the ledger's shape, never claims why.
        let livingTies = inputs.relationshipField
            .filter { $0.value != .zero }
            .sorted { left, right in
                let leftStrength = abs(left.value.warmth) + left.value.tension + left.value.familiarity
                let rightStrength = abs(right.value.warmth) + right.value.tension + right.value.familiarity
                return leftStrength > rightStrength
            }
            .prefix(2)
        for (pairKey, tie) in livingTies {
            let ids = pairKey.split(separator: "|").map(String.init)
            guard ids.count == 2 else { continue }
            let names = ids.map(entityName)
            let line: String
            if tie.tension > max(3, tie.warmth) {
                line = "The thread between \(names[0]) and \(names[1]) is pulled tight. Neither has let go."
            } else if tie.warmth > max(3, tie.tension) {
                line = "\(names[0]) and \(names[1]) have warmed the same thread. It's starting to remember them."
            } else {
                line = "\(names[0]) and \(names[1]) keep turning up in each other's ledger."
            }
            add(line, symbolName: "point.3.connected.trianglepath.dotted")
        }

        // NPC Belief movement is already an authored ledger receipt. Reader
        // and Page-source movements stay out of this fictional Academy drawer.
        for movement in inputs.beliefEconomy.recentMovements
            .filter({ $0.targetKind == .entity && $0.createdAt >= cutoff })
            .prefix(4) {
            let fallback = movement.delta >= 0
                ? "\(movement.targetName)'s Belief has brightened."
                : "\(movement.targetName)'s certainty lost a button."
            add(movement.note.nonEmpty ?? fallback, symbolName: "sparkles")
        }

        // Authored business currently underway, whether or not a Page happened
        // to witness its latest step.
        for undertaking in inputs.castUndertakings
            .filter(\.isRunning)
            .sorted(by: { $0.lastAdvancedAt > $1.lastAdvancedAt })
            .prefix(4) {
            guard let beat = undertaking.currentBeat else { continue }
            let actor = entityName(undertaking.actorID)
            add(
                "\(actor) is still inside “\(undertaking.title)”: \(beat.line)",
                symbolName: "books.vertical.fill"
            )
        }

        // Emergent alliances, rivalries, undertaking turns, and room refusals
        // have already been compiled into short-lived world pressure receipts.
        for pressure in inputs.worldPressures.prefix(3) {
            add(pressure.summary, symbolName: "point.3.filled.connected.trianglepath.dotted")
        }

        // Rooms remember exact incidents. Only recent ones are eligible here;
        // the durable Place ledger itself is still allowed to be much older.
        let roomIncidents = inputs.placeStates.flatMap { placeID, state in
            state.incidents.map { (placeID: placeID, incident: $0) }
        }
        .filter { $0.incident.occurredAt >= cutoff }
        .sorted { $0.incident.occurredAt > $1.incident.occurredAt }
        .prefix(4)
        for item in roomIncidents {
            add(
                "\(entityName(item.placeID)) remembers: \(item.incident.line)",
                symbolName: "door.left.hand.closed"
            )
        }

        if let event {
            add(
                "I caught this in the margin: \(event.phase.packetLine)",
                symbolName: "text.quote"
            )
        }

        // What's going round the corridors: the month's news, told second-hand.
        for memory in inputs.castStoryMemories.memories
            .filter({ $0.witness == .heard && $0.happenedAt >= cutoff && $0.happenedAt <= now })
            .sorted(by: { $0.happenedAt > $1.happenedAt })
            .prefix(3) {
            // Cut the hearsay before quoting it, so the closing mark is never cut off.
            guard let aside = memory.aside?.nonEmpty.map({ String($0.bookPreviewSentenceLimit(1).prefix(150)) }) else { continue }
            add("\(CastStoryNames.short(entityName(memory.entityID))) heard it on the stairs: \u{201C}\(aside)\u{201D}",
                symbolName: "ear", alreadyShort: true)
        }

        guard !candidates.isEmpty else { return [] }
        // The first line keeps its old seat, so one opening is still one reading; the rest of
        // the margin follows in this opening's own order, so a second look turns up other voices.
        let key = "\(dayID)|\(selectionSeed)|book-today-margin-source"
        let index = Int(UInt(bitPattern: key.stableHash) % UInt(candidates.count))
        let first = candidates[index]
        let rest = candidates.enumerated().filter { $0.offset != index }.sorted { left, right in
            let a = "\(key)|\(left.offset)".stableHash
            let b = "\(key)|\(right.offset)".stableHash
            return a == b ? left.offset < right.offset : a < b
        }.map(\.element)
        return ([first] + rest).map {
            BookTodayEdition.Beat(kind: .inTheMargins, line: $0.line, symbolName: $0.symbolName)
        }
    }

    private static func liveOpportunityHeadline(_ kind: BookLiveOpportunityKind) -> String {
        switch kind {
        case .shelterNeeded: return "I've lowered my voice."
        case .nearbyAnchorArrived: return "I can smell a familiar place nearby."
        case .weatherTurned: return "The weather changed the rules. I saw it."
        case .placeOpened: return "I found a nearby door standing open."
        case .calendarWindowOpened: return "I found a hole in the day's fence."
        case .capacityOpened: return "The day's got a gap in it. I've put my foot in it."
        }
    }

    private static func pageName(_ page: BookPage) -> String {
        page.promptText.nonEmpty
            .map { String($0.prefix(72)) }
            ?? page.type.rawValue
    }

    private static func underBindingLine(for page: BookPage) -> String {
        if let choice = page.readerFictionChoices.last?.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))
        ), !choice.isEmpty {
            return "I tucked your choice under my binding: “\(choice)”"
        }
        let name = pageName(page).trimmingCharacters(in: CharacterSet(charactersIn: ".!?…").union(.whitespaces))
        return "You kept “\(name).” It's making weather under my cover now."
    }

    private static func capitalized(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + value.dropFirst()
    }
}

/// Reads the Book's existing ledgers as a curious colophon. It never awards
/// points or invents a target: these are accumulated facts, not obligations.
enum BookTodayCensusProjector {
    private struct Candidate {
        var id: String
        var family: String
        var value: Int
        var line: String
        var symbolName: String

        var fact: BookTodayEdition.Census.Fact {
            .init(id: id, value: value, line: line, symbolName: symbolName)
        }
    }

    /// One pass over the archive. Book Today is rebuilt with the desk, so its
    /// curiosity must not turn into a dozen fresh walks through a long Book.
    private struct PageSummary {
        var keptDayIDs: Set<String> = []
        var pageKindIDs: Set<String> = []
        var pagesByDayID: [String: Int] = [:]
        var writtenPageCount = 0
        var mediaCount = 0
        var questionPageCount = 0
        var longestReaderLineWordCount = 0
        var unpromptedPageCount = 0
        var returnedPageCount = 0
        var bookOfYouCount = 0
        var livedReceiptCount = 0
        var relationshipReceiptCount = 0

        var busiestDayCount: Int { pagesByDayID.values.max() ?? 0 }
    }

    /// How many drawers one opening pulls out. The Book has far more than this; a different
    /// six turn up next time.
    static let drawerCount = 6

    static func census(
        for day: BookDay,
        inputs: BookSourceInputs,
        relationship: BookRelationshipSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current,
        selectionSeed: Int = 0
    ) -> BookTodayEdition.Census {
        let pages = archivePages(day: day, inputs: inputs)
        let begunAt = pages.map(\.createdAt).min()
        let readerName = LabyrinthWelcomePageSourceAdapter.playerName(from: inputs)
        let title = readerName.map { "THE BOOK OF \($0.uppercased())" } ?? "THE BOOK SO FAR"
        let candidates = candidates(
            pages: pages,
            inputs: inputs,
            relationship: relationship,
            calendar: calendar,
            selectionSeed: selectionSeed
        )
        return BookTodayEdition.Census(
            title: title,
            begunAt: begunAt,
            pageCount: pages.count,
            facts: selectedFacts(from: candidates, selectionSeed: selectionSeed, limit: drawerCount),
            closingLine: closingLine(
                inputs: inputs,
                relationship: relationship,
                pageCount: pages.count,
                selectionSeed: selectionSeed
            ),
            whileAway: whileAway(pages: pages, inputs: inputs, now: now, calendar: calendar)
        )
    }

    /// The last day in the Book, counted: proof it carried on while the Reader was out.
    /// Only things that really happened, each with its receipt in a ledger.
    static func whileAway(pages: [BookPage], inputs: BookSourceInputs, now: Date, calendar: Calendar) -> [BookTodayEdition.Census.Fact] {
        let since = now.addingTimeInterval(-24 * 3600)
        func recent(_ date: Date) -> Bool { date > since && date <= now }
        var facts: [BookTodayEdition.Census.Fact] = []
        func add(_ id: String, _ value: Int, _ symbol: String, _ line: String) {
            guard value > 0 else { return }
            facts.append(.init(id: id, value: value, line: line, symbolName: symbol))
        }
        // While the Guest eats at the Academy's table, Penny counts what the Cookery lost.
        if let live = KitchenTally.liveDay(on: now, inputs: inputs, calendar: calendar) {
            let count = KitchenTally.count(liveDay: live.day, eventStart: live.start, days: inputs.days)
            let mine = count.fromReader > 0 ? " \(count.fromReader) of them came back from your kitchen." : ""
            add("away-cookery", count.gone, "book.closed",
                "The Cookery's lost \(count.gone) \(count.gone == 1 ? "letter" : "letters"). \(count.back == 0 ? "None back yet." : "\(count.back) came back.")\(mine)")
        }
        if let braid = pages.filter({ $0.type == .bookOfYou && recent($0.createdAt) }).max(by: { $0.createdAt < $1.createdAt }) {
            let title = braid.userInput.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces).nonEmpty
            add("away-braid", 1, "book.pages", title.map { "I braided a whole day into \u{201C}\($0)\u{201D} while you slept." }
                ?? "I braided a whole day while you slept.")
        }
        let papers = inputs.bleedPrintHistory.filter { recent($0.printedAt) }
        add("away-papers", papers.count, "newspaper",
            papers.count == 1 ? "Penny printed a paper with you in it." : "Penny printed \(papers.count) papers with you in them.")
        let letters = papers.flatMap(\.items).filter { $0.storyID.hasPrefix("cast-letter:") }.count
            + papers.flatMap(\.items).filter { $0.storyID.hasPrefix("cast-letter:") }.reduce(0) { total, item in
                total + max(0, item.body.components(separatedBy: "Dear Editor,").count - 2)
            }
        add("away-letters", letters, "envelope",
            letters == 1 ? "Somebody at the Academy wrote to the paper about you." : "\(letters) letters about you reached the paper.")
        let acts = inputs.castActs.records.filter { recent($0.occurredAt) }.count
        add("away-acts", acts, "theatermasks",
            acts == 1 ? "The Cast did one thing to each other. I wrote it down." : "The Cast did \(acts) things to each other. I wrote them all down.")
        let unseen = inputs.castAgency.unwitnessedMovements.filter { recent($0.createdAt) }.count
        add("away-unseen", unseen, "eye.slash",
            unseen == 1 ? "Something happened at the Academy that nobody saw." : "\(unseen) things happened at the Academy that nobody saw.")
        let gossip = inputs.castStoryMemories.memories.filter { $0.witness == .heard && recent($0.happenedAt) }.count
        add("away-gossip", gossip, "ear",
            gossip == 1 ? "One rumour went round the corridors." : "\(gossip) rumours went round the corridors.")
        let belief = inputs.beliefEconomy.recentMovements.filter { $0.targetKind == .entity && recent($0.createdAt) }.count
        add("away-belief", belief, "sparkles",
            belief == 1 ? "Someone's Belief shifted. I felt it in the spine." : "Belief shifted \(belief) times. I felt it in the spine.")
        return Array(facts.prefix(5))
    }

    private static func archivePages(day: BookDay, inputs: BookSourceInputs) -> [BookPage] {
        var byID: [String: BookPage] = [:]
        for page in inputs.days.lazy.flatMap(\.pages) {
            if let existing = byID[page.id], existing.createdAt > page.createdAt { continue }
            byID[page.id] = page
        }
        for page in day.pages {
            if let existing = byID[page.id], existing.createdAt > page.createdAt { continue }
            byID[page.id] = page
        }
        return byID.values.sorted { left, right in
            if left.createdAt == right.createdAt { return left.id < right.id }
            return left.createdAt < right.createdAt
        }
    }

    private static func candidates(
        pages: [BookPage],
        inputs: BookSourceInputs,
        relationship: BookRelationshipSnapshot,
        calendar: Calendar,
        selectionSeed: Int
    ) -> [Candidate] {
        var result: [Candidate] = []
        let pageSummary = summarize(pages: pages, calendar: calendar)

        func add(
            _ id: String,
            family: String,
            value: Int,
            symbol: String,
            lines: [String]
        ) {
            guard value > 0, !lines.isEmpty else { return }
            result.append(Candidate(
                id: id,
                family: family,
                value: value,
                line: variant(lines, key: "\(selectionSeed)|\(id)|\(value)"),
                symbolName: symbol
            ))
        }

        // The Kitchen: things the reader actually made, in an actual pan.
        let workings = KitchenLedger.workings(in: [BookDay(id: "census", date: Date.distantPast, pages: pages)])
        let cooked = Set(workings.filter { $0.outcome.cooked }.map(\.recipeID)).count
        add(
            "kitchen-made",
            family: "kitchen",
            value: cooked,
            symbol: "fork.knife",
            lines: [
                "\(cooked) of the Kitchen's \(word(cooked, one: "recipe", many: "recipes")) made in your actual kitchen.",
                "You've made \(cooked) \(word(cooked, one: "thing", many: "things")) from the Kitchen. Ambrose has noticed."
            ]
        )
        let rescued = KitchenLedger.rescued(in: [BookDay(id: "census", date: Date.distantPast, pages: pages)]).count
        add(
            "kitchen-rescued",
            family: "kitchen",
            value: rescued,
            symbol: "square.and.pencil",
            lines: [
                "\(rescued) \(word(rescued, one: "recipe", many: "recipes")) rescued from somebody's hands.",
                "\(rescued) \(word(rescued, one: "recipe", many: "recipes")) that would've gone missing, and didn't."
            ]
        )

        // The grimoire is part of the Book's accumulated life, so it gets a
        // drawer like anything else it has been keeping.
        let heldRules = inputs.grimoire.rows.values.filter { $0.state == .standing }.count
        add(
            "rules-held",
            family: "grimoire",
            value: heldRules,
            symbol: "text.book.closed",
            lines: [
                "\(heldRules) \(word(heldRules, one: "rule", many: "rules")) about you that I'm sure of.",
                "I'm holding \(heldRules) \(word(heldRules, one: "rule", many: "rules")) about how you go."
            ]
        )
        let takenBack = inputs.grimoire.crossedOut.count
        add(
            "rules-crossed-out",
            family: "grimoire",
            value: takenBack,
            symbol: "pencil.slash",
            lines: [
                "\(takenBack) \(word(takenBack, one: "rule", many: "rules")) I had to cross out again.",
                "I got \(takenBack) \(word(takenBack, one: "thing", many: "things")) wrong and kept the crossings."
            ]
        )

        let keptDayCount = pageSummary.keptDayIDs.count
        add(
            "kept-days",
            family: "archive",
            value: keptDayCount,
            symbol: "calendar",
            lines: [
                "\(keptDayCount) \(word(keptDayCount, one: "day has", many: "days have")) left ink behind.",
                "I can prove that \(keptDayCount) different \(word(keptDayCount, one: "day existed", many: "days existed")) here."
            ]
        )

        let pageKindCount = pageSummary.pageKindIDs.count
        add(
            "page-kinds",
            family: "archive",
            value: pageKindCount > 1 ? pageKindCount : 0,
            symbol: "square.stack.3d.up",
            lines: [
                "\(pageKindCount) species of Page have learned your hand.",
                "My Pages have split into \(pageKindCount) different species. This seems excessive. Good."
            ]
        )

        let writtenPages = pageSummary.writtenPageCount
        add(
            "reader-ink",
            family: "attention",
            value: writtenPages,
            symbol: "pencil.and.scribble",
            lines: [
                "Your own ink is alive on \(writtenPages) \(word(writtenPages, one: "Page", many: "Pages")).",
                "\(writtenPages) \(word(writtenPages, one: "Page carries", many: "Pages carry")) words only you could have supplied."
            ]
        )

        let mediaCount = pageSummary.mediaCount
        add(
            "media",
            family: "attention",
            value: mediaCount,
            symbol: "photo.on.rectangle.angled",
            lines: [
                "\(mediaCount) \(word(mediaCount, one: "piece", many: "pieces")) of the outside world are pressed between these Pages.",
                "I have \(mediaCount) scraps that aren't made only of ink."
            ]
        )

        let questionPages = pageSummary.questionPageCount
        add(
            "question-pages",
            family: "oddities",
            value: questionPages,
            symbol: "questionmark.bubble.fill",
            lines: [
                "\(questionPages) \(word(questionPages, one: "Page has", many: "Pages have")) left a question mark loose in the binding.",
                "Your own ink has asked \(questionPages) \(word(questionPages, one: "Page-sized question", many: "Page-sized questions")) without demanding a neat answer."
            ]
        )

        let busiestDayCount = pageSummary.busiestDayCount
        add(
            "busiest-day",
            family: "oddities",
            value: busiestDayCount >= 3 ? busiestDayCount : 0,
            symbol: "books.vertical.fill",
            lines: [
                "The fullest day made \(busiestDayCount) Pages share one chair.",
                "My most crowded day held \(busiestDayCount) Pages and several elbows."
            ]
        )

        let longestReaderLine = pageSummary.longestReaderLineWordCount
        add(
            "longest-reader-line",
            family: "oddities",
            value: longestReaderLine >= 20 ? longestReaderLine : 0,
            symbol: "text.alignleft",
            lines: [
                "Your longest kept telling ran to \(longestReaderLine) words before it sat down.",
                "One true thing grew \(longestReaderLine) words long. I measured it while it slept."
            ]
        )

        let unpromptedPages = pageSummary.unpromptedPageCount
        add(
            "unprompted-pages",
            family: "attention",
            value: unpromptedPages,
            symbol: "doc.plaintext",
            lines: [
                "\(unpromptedPages) \(word(unpromptedPages, one: "Page came", many: "Pages came")) in without being asked.",
                "You opened the plain door \(unpromptedPages) \(word(unpromptedPages, one: "time", many: "times")) and brought your own reason."
            ]
        )

        let returnedPages = pageSummary.returnedPageCount
        add(
            "returned-pages",
            family: "continuity",
            value: returnedPages,
            symbol: "arrow.uturn.backward.circle",
            lines: [
                "\(returnedPages) old \(word(returnedPages, one: "Page has", many: "Pages have")) found the path back.",
                "The archive has sent \(returnedPages) \(word(returnedPages, one: "thing", many: "things")) back wearing different weather."
            ]
        )

        let bookOfYouCount = pageSummary.bookOfYouCount
        add(
            "book-of-you",
            family: "bindings",
            value: bookOfYouCount,
            symbol: "book.pages",
            lines: [
                "\(bookOfYouCount) \(word(bookOfYouCount, one: "day has", many: "days have")) been braided into the Book of You.",
                "I have bound \(bookOfYouCount) \(word(bookOfYouCount, one: "braid", many: "braids")) from the day's loose evidence."
            ]
        )

        let livedReceipts = pageSummary.livedReceiptCount
        add(
            "lived-receipts",
            family: "outside-life",
            value: livedReceipts,
            symbol: "figure.walk.arrival",
            lines: [
                "\(livedReceipts) \(word(livedReceipts, one: "Page crossed", many: "Pages crossed")) into life and brought evidence home.",
                "The outside world has answered back \(livedReceipts) \(word(livedReceipts, one: "time", many: "times"))."
            ]
        )

        add(
            "remembered-places",
            family: "places",
            value: inputs.rememberedPlaceCount,
            symbol: "location.fill.viewfinder",
            lines: [
                "\(inputs.rememberedPlaceCount) \(word(inputs.rememberedPlaceCount, one: "place knows", many: "places know")) how to find these Pages again.",
                "The Compass remembers \(inputs.rememberedPlaceCount) \(word(inputs.rememberedPlaceCount, one: "place", many: "places")) you taught it."
            ]
        )

        add(
            "anchors",
            family: "places",
            value: inputs.anchors.count,
            symbol: "mappin.and.ellipse",
            lines: [
                "\(inputs.anchors.count) \(word(inputs.anchors.count, one: "real place has", many: "real places have")) grown an Outer Stacks door.",
                "You have hammered \(inputs.anchors.count) \(word(inputs.anchors.count, one: "Anchor", many: "Anchors")) into the ordinary world."
            ]
        )

        // `visitCount == 1` is the first check-in; only later check-ins are
        // returns, so the census does not dress arrival up as recurrence.
        let anchorReturns = inputs.anchors.reduce(0) { $0 + max(0, $1.visitCount - 1) }
        add(
            "anchor-returns",
            family: "returns",
            value: anchorReturns,
            symbol: "point.bottomleft.forward.to.point.topright.scurvepath",
            lines: [
                "Anchored places have seen you return \(anchorReturns) \(word(anchorReturns, one: "time", many: "times")).",
                "You went back \(anchorReturns) \(word(anchorReturns, one: "time", many: "times")). The places noticed."
            ]
        )

        let activePeople = inputs.people.threads.filter { !$0.resting }.count
        add(
            "people",
            family: "people",
            value: activePeople,
            symbol: "person.2.fill",
            lines: [
                "\(activePeople) real \(word(activePeople, one: "person is", many: "people are")) wandering these Pages by invitation.",
                "\(activePeople) \(word(activePeople, one: "person from your world has", many: "people from your world have")) a thread here."
            ]
        )

        let customCharacters = inputs.customCastMembers.filter { $0.kind == .character }.count
        add(
            "custom-characters",
            family: "people",
            value: customCharacters,
            symbol: "person.crop.rectangle.stack",
            lines: [
                "\(customCharacters) \(word(customCharacters, one: "character has", many: "characters have")) crossed the threshold by your hand.",
                "You wrote \(customCharacters) \(word(customCharacters, one: "character", many: "characters")) into being here."
            ]
        )

        let knownCharacterIDs = Set(
            (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
                .filter { $0.kind == .character }
                .map(\.id)
        )
        let relationshipEntityIDs = inputs.relationshipField.keys.flatMap {
            $0.split(separator: "|").map(String.init)
        }
        let movingCharacterIDs = Set(
            relationshipEntityIDs
                + inputs.castAgency.recentMovements.flatMap { [$0.actorID, $0.targetID] }
                + inputs.castActs.records.flatMap { [$0.actorID, $0.targetID] }
        ).filter { knownCharacterIDs.contains($0) }
        add(
            "characters-in-motion",
            family: "people",
            value: movingCharacterIDs.count,
            symbol: "person.3.fill",
            lines: [
                "\(movingCharacterIDs.count) \(word(movingCharacterIDs.count, one: "character has", many: "characters have")) acquired a life in motion.",
                "\(movingCharacterIDs.count) members of the cast have done enough to leave footprints in the ledgers."
            ]
        )

        let customObjects = inputs.customCastMembers.filter { $0.kind == .object }.count
        add(
            "story-objects",
            family: "inventory",
            value: customObjects,
            symbol: "shippingbox.fill",
            lines: [
                "\(customObjects) ordinary \(word(customObjects, one: "object has", many: "objects have")) acquired story-business.",
                "\(customObjects) \(word(customObjects, one: "object is", many: "objects are")) no longer behaving like scenery."
            ]
        )

        let changedRelationships = inputs.relationshipField.values.filter {
            $0.warmth != 0 || $0.tension != 0 || $0.familiarity != 0
        }.count
        add(
            "changed-relationships",
            family: "relationships",
            value: changedRelationships,
            symbol: "point.3.connected.trianglepath.dotted",
            lines: [
                "\(changedRelationships) \(word(changedRelationships, one: "relationship has", many: "relationships have")) changed shape.",
                "I have \(changedRelationships) living \(word(changedRelationships, one: "tie", many: "ties")) that no longer look as they did at first."
            ]
        )

        let relationshipReceipts = pageSummary.relationshipReceiptCount
        add(
            "relationship-receipts",
            family: "relationships",
            value: relationshipReceipts,
            symbol: "person.line.dotted.person.fill",
            lines: [
                "\(relationshipReceipts) \(word(relationshipReceipts, one: "Page carries", many: "Pages carry")) proof that another life touched yours.",
                "Other people have left \(relationshipReceipts) \(word(relationshipReceipts, one: "fingerprint", many: "fingerprints")) in the binding."
            ]
        )

        add(
            "cast-acts",
            family: "relationships",
            value: inputs.castActs.records.count,
            symbol: "theatermasks.fill",
            lines: [
                "The Academy remembers \(inputs.castActs.records.count) recent \(word(inputs.castActs.records.count, one: "act the cast did", many: "acts the cast did")) to one another.",
                "The cast has left \(inputs.castActs.records.count) concrete \(word(inputs.castActs.records.count, one: "deed", many: "deeds")) behind, including the inconvenient ones."
            ]
        )

        let finishedTales = inputs.boundTales.filter { $0.closedAt != nil }.count
        add(
            "finished-tales",
            family: "tales",
            value: finishedTales,
            symbol: "book.closed.fill",
            lines: [
                "I've finished \(finishedTales) \(word(finishedTales, one: "tale", many: "tales")). They might start up again.",
                "I have tied the last knot on \(finishedTales) \(word(finishedTales, one: "tale", many: "tales"))."
            ]
        )

        if let openTale = inputs.openTale {
            let witnesses = openTale.witnesses.count
            add(
                "open-tale-witnesses",
                family: "tales",
                value: witnesses,
                symbol: "eye.fill",
                lines: [
                    "The living tale has collected \(witnesses) \(word(witnesses, one: "witness", many: "witnesses")) and still refuses to end.",
                    "\(witnesses) pieces of evidence are holding the current tale open."
                ]
            )
        }

        let livingConstellations = inputs.constellations.filter(\.isAlive).count
        add(
            "constellations",
            family: "patterns",
            value: livingConstellations,
            symbol: "sparkles",
            lines: [
                "\(livingConstellations) recurring \(word(livingConstellations, one: "thing has", many: "things have")) gathered enough evidence to become a constellation.",
                "I'm keeping watch over \(livingConstellations) returning \(word(livingConstellations, one: "pattern", many: "patterns"))."
            ]
        )

        let namedConstellations = inputs.constellations.filter { $0.isAlive && $0.isNamed }.count
        add(
            "named-constellations",
            family: "patterns",
            value: namedConstellations,
            symbol: "star.circle.fill",
            lines: [
                "\(namedConstellations) recurring \(word(namedConstellations, one: "thing has", many: "things have")) earned a proper name.",
                "You repeated yourself beautifully enough that \(namedConstellations) \(word(namedConstellations, one: "pattern has", many: "patterns have")) been named."
            ]
        )

        let constellationReturns = inputs.constellations.reduce(0) { $0 + $1.returnCount }
        add(
            "constellation-returns",
            family: "returns",
            value: constellationReturns,
            symbol: "arrow.trianglehead.2.clockwise.rotate.90",
            lines: [
                "Things I thought had gone quiet have come back \(constellationReturns) \(word(constellationReturns, one: "time", many: "times")).",
                "The constellations have climbed back over the wall \(constellationReturns) \(word(constellationReturns, one: "time", many: "times"))."
            ]
        )

        add(
            "motif-clusters",
            family: "patterns",
            value: inputs.clusters.count,
            symbol: "circle.hexagongrid.fill",
            lines: [
                "\(inputs.clusters.count) strange \(word(inputs.clusters.count, one: "neighborhood has", many: "neighborhoods have")) formed between distant things.",
                "My margins contain \(inputs.clusters.count) places where unrelated things have begun passing notes."
            ]
        )

        add(
            "themes",
            family: "bindings",
            value: inputs.themes.count,
            symbol: "paintpalette.fill",
            lines: [
                "\(inputs.themes.count) \(word(inputs.themes.count, one: "month has", many: "months have")) made weather of its own.",
                "The archive has grown \(inputs.themes.count) monthly weather \(word(inputs.themes.count, one: "system", many: "systems"))."
            ]
        )

        add(
            "book-wagers",
            family: "book-self",
            value: inputs.wagers.count,
            symbol: "seal.fill",
            lines: [
                "I have risked my dignity on \(inputs.wagers.count) \(word(inputs.wagers.count, one: "wager", many: "wagers")).",
                "The sealed margin contains \(inputs.wagers.count) \(word(inputs.wagers.count, one: "bet", many: "bets")) I wasn't certain I could win."
            ]
        )

        let wrongWagers = inputs.wagers.filter { $0.status == .wrong }.count
        add(
            "wrong-wagers",
            family: "book-self",
            value: wrongWagers,
            symbol: "exclamationmark.bubble.fill",
            lines: [
                "You have caught me wrong \(wrongWagers) \(word(wrongWagers, one: "time", many: "times")). I kept the evidence.",
                "I lost \(wrongWagers) \(word(wrongWagers, one: "wager", many: "wagers")) and survived the indignity."
            ]
        )

        let admittedFaults = inputs.bookInterior.faultHistory.count
        add(
            "book-faults",
            family: "book-self",
            value: admittedFaults,
            symbol: "bandage.fill",
            lines: [
                "I've had to repair \(admittedFaults) of my own \(word(admittedFaults, one: "mistake", many: "mistakes")).",
                "\(admittedFaults) of my grand conclusions required a bandage."
            ]
        )

        let revealedQuirks = inputs.bookInterior.quirks.filter { $0.maturity != .latent }.count
        add(
            "book-quirks",
            family: "book-self",
            value: revealedQuirks,
            symbol: "scribble.variable",
            lines: [
                "Living with you has given me \(revealedQuirks) \(word(revealedQuirks, one: "quirk", many: "quirks")). You can check.",
                "I have acquired \(revealedQuirks) bad little \(word(revealedQuirks, one: "habit", many: "habits")) you can prove."
            ]
        )

        add(
            "book-tastes",
            family: "book-self",
            value: inputs.bookInterior.acquiredTastes.count,
            symbol: "heart.text.square.fill",
            lines: [
                "This particular Book has developed \(inputs.bookInterior.acquiredTastes.count) \(word(inputs.bookInterior.acquiredTastes.count, one: "taste", many: "tastes")).",
                "Your Pages have taught me to be fond of \(inputs.bookInterior.acquiredTastes.count) particular kinds of thing."
            ]
        )

        add(
            "book-memories",
            family: "book-self",
            value: inputs.bookInterior.autobiography.count,
            symbol: "book.and.wrench.fill",
            lines: [
                "I remember \(inputs.bookInterior.autobiography.count) things about becoming this Book.",
                "I have \(inputs.bookInterior.autobiography.count) memories that belong to me rather than to you."
            ]
        )

        add(
            "private-traditions",
            family: "rituals",
            value: inputs.bookInterior.privateTraditions.count,
            symbol: "party.popper.fill",
            lines: [
                "We have accidentally founded \(inputs.bookInterior.privateTraditions.count) private \(word(inputs.bookInterior.privateTraditions.count, one: "tradition", many: "traditions")).",
                "\(inputs.bookInterior.privateTraditions.count) small \(word(inputs.bookInterior.privateTraditions.count, one: "ceremony belongs", many: "ceremonies belong")) only to this Book."
            ]
        )

        let disputes = inputs.bookInterior.disputeHistory.count
            + (inputs.bookInterior.currentDispute == nil ? 0 : 1)
        add(
            "book-disputes",
            family: "unfinished",
            value: disputes,
            symbol: "quote.bubble.fill",
            lines: [
                "We've got \(disputes) \(word(disputes, one: "argument", many: "arguments")) going, and neither of us has given in.",
                "There are \(disputes) honest \(word(disputes, one: "disagreement", many: "disagreements")) in the margins. I didn't eat yours."
            ]
        )

        let unfinished = (inputs.openTale == nil ? 0 : 1)
            + inputs.contestedQuestions.filter(\.isLive).count
            + (inputs.bookInterior.currentDispute == nil ? 0 : 1)
            + (inputs.bookInterior.runningBusiness == nil ? 0 : 1)
            + inputs.wagers.filter(\.isSealed).count
        add(
            "unfinished-business",
            family: "unfinished",
            value: unfinished,
            symbol: "bookmark.fill",
            lines: [
                "\(unfinished) unfinished \(word(unfinished, one: "thing is", many: "things are")) chewing the same bookmark.",
                "I have \(unfinished) live \(word(unfinished, one: "mystery, argument, or wager", many: "mysteries, arguments, or wagers")) refusing a neat ending."
            ]
        )

        let openQuestions = inputs.contestedQuestions.filter(\.isLive).count
        add(
            "arguing-questions",
            family: "unfinished",
            value: openQuestions,
            symbol: "person.3.sequence.fill",
            lines: [
                "\(openQuestions) \(word(openQuestions, one: "question is", many: "questions are")) still arguing in several voices.",
                "The cast has \(openQuestions) unresolved \(word(openQuestions, one: "question", many: "questions")) and no respectable silence."
            ]
        )

        add(
            "pocket-keepsakes",
            family: "inventory",
            value: inputs.pocket.count,
            symbol: "archivebox.fill",
            lines: [
                "My Pocket is carrying \(inputs.pocket.count) \(word(inputs.pocket.count, one: "keepsake", many: "keepsakes")) and pretending not to bulge.",
                "\(inputs.pocket.count) small \(word(inputs.pocket.count, one: "thing is", many: "things are")) hiding in my coat."
            ]
        )

        add(
            "fae-gifts",
            family: "inventory",
            value: inputs.faeState.gifts.count,
            symbol: "gift.fill",
            lines: [
                "The Inventory contains \(inputs.faeState.gifts.count) Fae \(word(inputs.faeState.gifts.count, one: "gift", many: "gifts")), all with suspicious paperwork.",
                "\(inputs.faeState.gifts.count) impossible \(word(inputs.faeState.gifts.count, one: "object claims", many: "objects claim")) to belong to you."
            ]
        )

        add(
            "bound-folios",
            family: "inventory",
            value: inputs.ownedPackIDs.count,
            symbol: "books.vertical.fill",
            lines: [
                "\(inputs.ownedPackIDs.count) extra \(word(inputs.ownedPackIDs.count, one: "folio has", many: "folios have")) taught the shelves new tricks.",
                "The Goblin Market has got \(inputs.ownedPackIDs.count) \(word(inputs.ownedPackIDs.count, one: "folio", many: "folios")) past my front desk."
            ]
        )

        add(
            "ruled-words",
            family: "language",
            value: inputs.readerLexicon.entries.count,
            symbol: "textformat.abc.dottedunderline",
            lines: [
                "You have stood in judgment over \(inputs.readerLexicon.entries.count) rebellious \(word(inputs.readerLexicon.entries.count, one: "word", many: "words")).",
                "\(inputs.readerLexicon.entries.count) \(word(inputs.readerLexicon.entries.count, one: "word has", many: "words have")) acquired a legal history here."
            ]
        )

        add(
            "redefined-words",
            family: "language",
            value: inputs.readerLexicon.redefinedEntries.count,
            symbol: "character.book.closed.fill",
            lines: [
                "\(inputs.readerLexicon.redefinedEntries.count) \(word(inputs.readerLexicon.redefinedEntries.count, one: "word now means", many: "words now mean")) something the Dictionary didn't authorize.",
                "You gave \(inputs.readerLexicon.redefinedEntries.count) old \(word(inputs.readerLexicon.redefinedEntries.count, one: "word", many: "words")) new work."
            ]
        )

        add(
            "escaped-words",
            family: "language",
            value: inputs.readerLexicon.eatenEntries.count,
            symbol: "text.badge.minus",
            lines: [
                "\(inputs.readerLexicon.eatenEntries.count) \(word(inputs.readerLexicon.eatenEntries.count, one: "word has", many: "words have")) escaped the Dictionary entirely.",
                "The Dictionary is missing \(inputs.readerLexicon.eatenEntries.count) \(word(inputs.readerLexicon.eatenEntries.count, one: "word", many: "words")) and knows what you did."
            ]
        )

        let usableFacts = inputs.selfFacts.filter {
            $0.usePermission != .doNotUse
                && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        add(
            "trusted-truths",
            family: "reader-authority",
            value: usableFacts,
            symbol: "hand.raised.fill",
            lines: [
                "You've let me keep \(usableFacts) true \(word(usableFacts, one: "thing", many: "things")) about you.",
                "I know \(usableFacts) \(word(usableFacts, one: "thing", many: "things")) about you that you said I could. I don't pretend about the rest."
            ]
        )

        add(
            "book-corrections",
            family: "reader-authority",
            value: relationship.softenedReadingCount,
            symbol: "pencil.line",
            lines: [
                "You have corrected my reading \(relationship.softenedReadingCount) \(word(relationship.softenedReadingCount, one: "time", many: "times")), and the corrections stayed.",
                "I have \(relationship.softenedReadingCount) pencil \(word(relationship.softenedReadingCount, one: "mark", many: "marks")) where you taught me better."
            ]
        )

        add(
            "protected-boundaries",
            family: "reader-authority",
            value: relationship.protectedBoundaryCount,
            symbol: "lock.shield.fill",
            lines: [
                "You told me to leave \(relationship.protectedBoundaryCount) \(word(relationship.protectedBoundaryCount, one: "thing", many: "things")) alone. I have.",
                "You closed \(relationship.protectedBoundaryCount) \(word(relationship.protectedBoundaryCount, one: "door", many: "doors")), and I kept them closed."
            ]
        )

        let recentCastMovements = inputs.castAgency.recentMovements.count
        add(
            "recent-cast-movements",
            family: "academy",
            value: recentCastMovements,
            symbol: "figure.walk.motion",
            lines: [
                "The cast got up to \(recentCastMovements) \(word(recentCastMovements, one: "thing", many: "things")) offstage lately.",
                "The cast has done \(recentCastMovements) recent \(word(recentCastMovements, one: "thing", many: "things")) without waiting for the plot to look at them."
            ]
        )

        let unwitnessedMovements = inputs.castAgency.unwitnessedMovements.count
        add(
            "unwitnessed-cast-movements",
            family: "academy",
            value: unwitnessedMovements,
            symbol: "eye.slash.fill",
            lines: [
                "\(unwitnessedMovements) recent \(word(unwitnessedMovements, one: "thing happened", many: "things happened")) in the Academy while nobody was looking.",
                "The cast is sitting on \(unwitnessedMovements) unwitnessed \(word(unwitnessedMovements, one: "incident", many: "incidents")). It looks guilty."
            ]
        )

        // The Reader's own ink, weighed. Every count here is a count of their words.
        // A kept paper stores Penny's whole paper; only its margin is the Reader's.
        let written = pages.compactMap { page in
            page.type == .theBleed ? BleedNewsroom.letterText(of: page) : page.readerAuthoredTextForAnalysis
        }
        let totalWords = written.reduce(0) { $0 + wordCount($1) }
        // Thresholds sit a little above each book's real length, so "longer than" is always true.
        let shelf: [(words: Int, title: String)] = [
            (96_000, "The Hobbit"), (48_000, "The Great Gatsby"), (30_500, "Animal Farm"),
            (27_000, "Alice's Adventures in Wonderland"), (17_500, "The Little Prince"), (1_000, "The Tale of Peter Rabbit")
        ]
        let wordsShown = totalWords.formatted()
        if let beaten = shelf.first(where: { totalWords >= $0.words }) {
            add("words-written", family: "ink", value: totalWords, symbol: "character.cursor.ibeam",
                lines: ["You've written \(wordsShown) words in me. That's longer than \(beaten.title).",
                        "\(wordsShown) words of yours in my pages. \(beaten.title) is shorter. I measured."])
        } else {
            add("words-written", family: "ink", value: totalWords >= 50 ? totalWords : 0, symbol: "character.cursor.ibeam",
                lines: ["You've written \(wordsShown) words in me. Every one of them is still here.",
                        "\(wordsShown) words of yours, and I haven't lost a single one."])
        }

        var hours: [Int: Int] = [:]
        for page in pages where page.type != .theBleed && page.readerAuthoredTextForAnalysis?.nonEmpty != nil {
            hours[calendar.component(.hour, from: page.createdAt), default: 0] += 1
        }
        if let (hour, count) = hours.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }), count >= 3 {
            let twelve = hour % 12 == 0 ? 12 : hour % 12
            let part = hour < 5 ? "in the small hours" : hour < 12 ? "in the morning" : hour < 17 ? "in the afternoon" : hour < 21 ? "in the evening" : "at night"
            add("ink-hour", family: "habits", value: twelve, symbol: "clock",
                lines: ["Your ink turns up most at \(twelve) o'clock \(part). I've started waiting for it.",
                        "\(twelve) o'clock \(part) is your hour. More of your Pages arrive then than at any other."])
        }

        var counts: [String: Int] = [:]
        for text in written {
            for token in text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }) {
                let word = String(token)
                guard word.count >= 5, !commonWords.contains(word) else { continue }
                counts[word, default: 0] += 1
            }
        }
        if let (favourite, uses) = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }), uses >= 4 {
            add("your-word", family: "habits", value: uses, symbol: "textformat",
                lines: ["You've written \u{201C}\(favourite)\u{201D} \(uses) times. It's your word now. I've told the Dictionary.",
                        "\u{201C}\(favourite)\u{201D} turns up \(uses) times in your ink. It's turning into your word."])
        }

        if let first = pages.map(\.createdAt).min(),
           let age = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: Date())).day,
           age >= 2 {
            add("book-age", family: "book-self", value: age + 1, symbol: "hourglass",
                lines: ["\(age + 1) days since you first opened me. I was mostly cover then.",
                        "This particular Book is \(age + 1) days old. I've grown."])
        }

        let frontPages = inputs.bleedFrontPages.filter { $0.headline != BleedDayDesk.unfiledHeadline }.count
        add("front-pages", family: "paper", value: frontPages, symbol: "newspaper",
            lines: ["The Bleed has put your day on its front page \(frontPages) \(word(frontPages, one: "time", many: "times")).",
                    "\(frontPages) \(word(frontPages, one: "front page", many: "front pages")) about you, attested by Penny. She's run out of stamps twice."])

        let together = inputs.castStoryMemories.memories.filter { $0.witness == .withReader }.count
        add("cast-remember-you", family: "academy", value: together, symbol: "person.2.wave.2",
            lines: ["The Cast remember \(together) \(word(together, one: "thing", many: "things")) they did with you. They bring them up.",
                    "\(together) \(word(together, one: "moment", many: "moments")) at the Academy the Cast still talk about, and you were there."])
        let rumours = inputs.castStoryMemories.memories.filter { $0.witness == .heard }.count
        add("rumours", family: "academy", value: rumours, symbol: "ear",
            lines: [rumours == 1 ? "1 rumour has gone round the corridors. It might even be true."
                        : "\(rumours) rumours have gone round the corridors. Some of them were even true.",
                    "The Academy has passed on news it wasn't there for \(rumours) \(word(rumours, one: "time", many: "times"))."])

        let rememberingRooms = inputs.placeStates.values.filter { !$0.incidents.isEmpty }.count
        add(
            "remembering-rooms",
            family: "academy",
            value: rememberingRooms,
            symbol: "door.left.hand.closed",
            lines: [
                "\(rememberingRooms) Academy \(word(rememberingRooms, one: "room remembers", many: "rooms remember")) what happened inside.",
                "\(rememberingRooms) \(word(rememberingRooms, one: "room has", many: "rooms have")) stopped behaving like mere scenery."
            ]
        )

        return result
    }

    private static func summarize(pages: [BookPage], calendar: Calendar) -> PageSummary {
        var summary = PageSummary()
        for page in pages {
            let dayID = BookDay.id(for: page.createdAt, calendar: calendar)
            summary.keptDayIDs.insert(dayID)
            summary.pageKindIDs.insert(page.type.rawValue)
            summary.pagesByDayID[dayID, default: 0] += 1
            let readerInk = (page.type == .theBleed ? BleedNewsroom.letterText(of: page) : page.readerAuthoredTextForAnalysis) ?? ""
            let hasReaderInk = !readerInk.isEmpty
            if hasReaderInk { summary.writtenPageCount += 1 }
            summary.mediaCount += page.readerContributions.filter {
                $0.kind == .photograph || $0.kind == .audioRecording
            }.count
            if readerInk.contains("?") {
                summary.questionPageCount += 1
            }
            summary.longestReaderLineWordCount = max(
                summary.longestReaderLineWordCount,
                wordCount(readerInk)
            )
            if page.type == .plainPage { summary.unpromptedPageCount += 1 }
            if page.type == .bookRemembered { summary.returnedPageCount += 1 }
            if page.type == .bookOfYou { summary.bookOfYouCount += 1 }
            if page.attributableLivedQuestReceipt != nil { summary.livedReceiptCount += 1 }
            if page.relationshipReceipt != nil { summary.relationshipReceiptCount += 1 }
        }
        return summary
    }

    private static func selectedFacts(
        from candidates: [Candidate],
        selectionSeed: Int,
        limit: Int
    ) -> [BookTodayEdition.Census.Fact] {
        guard limit > 0 else { return [] }
        let ordered = candidates.sorted { left, right in
            let leftKey = "\(selectionSeed)|census|\(left.id)".stableHash
            let rightKey = "\(selectionSeed)|census|\(right.id)".stableHash
            return leftKey == rightKey ? left.id < right.id : leftKey < rightKey
        }
        var chosen: [Candidate] = []
        var usedFamilies: Set<String> = []
        for candidate in ordered where chosen.count < limit {
            guard usedFamilies.insert(candidate.family).inserted else { continue }
            chosen.append(candidate)
        }
        if chosen.count < limit {
            let chosenIDs = Set(chosen.map(\.id))
            chosen.append(contentsOf: ordered.filter { !chosenIDs.contains($0.id) }.prefix(limit - chosen.count))
        }
        return chosen.map(\.fact)
    }

    private static func closingLine(
        inputs: BookSourceInputs,
        relationship: BookRelationshipSnapshot,
        pageCount: Int,
        selectionSeed: Int
    ) -> String {
        if pageCount == 0 {
            return "I'm still mostly cover. That won't last."
        }
        if inputs.quietDays > 0 {
            let greeting: String
            switch relationship.depth {
            case .firstPages:
                greeting = "Oh. You're back. Good. I wasn't worried. The ribbon was."
            case .acquainted:
                greeting = "There you are. Where have you been?"
            case .trusted:
                greeting = "Where have you been? I have news."
            case .companion:
                greeting = "What in the wild margins, where have you been?"
            }

            if let news = returnNews(from: inputs) {
                return variant([
                    "\(greeting) \(news) Can you believe it? Kept your place anyway.",
                    "\(greeting) Listen: \(news) I've been sitting on this. Kept your place.",
                    "\(greeting) While you were out: \(news) I knew you would want to know. Kept your place anyway."
                ], key: "\(selectionSeed)|quiet-news-closing")
            }
            return variant([
                "\(greeting) The Index has been unbearable. Kept your place anyway.",
                "\(greeting) I had news and then the ribbon ate the important bit. Kept your place anyway.",
                "\(greeting) I have three theories and a bent corner. Kept your place.",
                "\(greeting) Nothing broke. Several things misbehaved. Kept your place anyway."
            ], key: "\(selectionSeed)|quiet-feral-closing")
        }
        return variant([
            "None of this was here when we began.",
            "Look what your days dragged in. The numbers have teeth now.",
            "I was smaller before you. I have records.",
            "The binding is getting ideas.",
            "Ordinary days did all this while you were busy inside them."
        ], key: "\(selectionSeed)|growing-closing")
    }

    /// Return excitement is best when it has receipts. The Book gossips about
    /// the newest unwitnessed cast movement or unfinished household business
    /// before falling back to harmless cover-and-ribbon commotion.
    private static func returnNews(from inputs: BookSourceInputs) -> String? {
        if let movement = inputs.castAgency.unwitnessedMovements.first,
           let line = movement.line.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return line.bookPreviewSentenceLimit(1)
        }
        if let business = inputs.bookInterior.runningBusiness,
           let line = business.latestLine.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return line.bookPreviewSentenceLimit(1)
        }
        if let question = inputs.contestedQuestions.first(where: \.isLive) {
            return "The margins are still arguing over “\(question.question)”"
        }
        if let tale = inputs.openTale {
            let name = tale.title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? "the living tale"
            return "\(name) moved while you weren't looking. It denies everything."
        }
        return nil
    }

    /// Words too ordinary to be anybody's word.
    private static let commonWords: Set<String> = [
        "about", "after", "again", "there", "their", "which", "would", "could", "should", "today", "really",
        "thing", "things", "think", "still", "every", "being", "other", "where", "while", "first", "before",
        "never", "always", "going", "because", "something", "little", "didn't", "wasn't", "people", "maybe",
        "right", "though", "through", "around", "everything", "nothing", "these", "those", "what's", "there's",
        "don't", "can't", "isn't", "i've", "it's", "that's", "we're", "they're", "you're", "under", "over",
        "until", "since", "made", "kept", "felt", "back", "into", "just", "with", "from", "were", "have",
        "some", "more", "much", "very", "then", "than", "when", "also", "even", "only", "most", "found",
        "another", "without", "enough", "almost", "whole", "anyway", "already", "doesn't", "couldn't", "wouldn't"
    ]

    private static func word(_ count: Int, one: String, many: String) -> String {
        count == 1 ? one : many
    }

    private static func wordCount(_ value: String) -> Int {
        value.split(whereSeparator: \.isWhitespace).count
    }

    static func variant(_ values: [String], key: String) -> String {
        guard !values.isEmpty else { return "" }
        let index = Int(UInt(bitPattern: key.stableHash) % UInt(values.count))
        return values[index]
    }
}

// MARK: - The doorstep: what's waiting for the Reader this opening

/// Book Today's first answer to "what's happening": something of the Reader's own, the paper
/// on the mat, and the one thing the day has asked of them. All of it from real ledgers.
enum BookTodayDoorstep {
    static let asides = [
        "I keep going back to this one.",
        "I read this twice this morning. Don't tell the Index.",
        "This one's still warm.",
        "I've folded the corner down on this one.",
        "Nobody else in the world wrote this. I checked."
    ]

    /// A Page the Book won't hand back unasked: one carrying a heavy tag or phrase, even on a
    /// day that wasn't hard enough to shelter the whole Book.
    static func isHeavy(_ page: BookPage) -> Bool {
        let heavyTags: Set<String> = ["distress", "panic", "hard", "heavy", "low", "numb", "stormy", "depleted", "grief"]
        let heavyPhrases = ["hopeless", "depressed", "panic", "can't do this", "cannot do this", "can't keep", "disappear",
                            "too much", "want to die", "kill myself", "hurt myself"]
        let text = (page.readerAuthoredTextForAnalysis ?? page.userInput).lowercased()
        return !Set(page.tags.map { $0.lowercased() }).isDisjoint(with: heavyTags) || heavyPhrases.contains(where: text.contains)
    }

    /// The thing a sentence is about, as the Book would say "the heron": the first particular
    /// word after "the", "a" or "my". Never a name, never a word too ordinary to be a thing.
    static func thing(in text: String) -> String? {
        let determiners: Set<String> = ["the", "a", "an", "my", "this", "that", "our"]
        let skip: Set<String> = ["same", "other", "first", "last", "whole", "little", "very", "most", "next", "only",
                                 "best", "rest", "kind", "sort", "bit", "lot", "way", "time", "day", "thing", "something"]
        let words = text.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        for index in words.indices.dropLast() {
            let word = words[index].lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard determiners.contains(word) else { continue }
            let raw = words[index + 1].trimmingCharacters(in: .punctuationCharacters)
            guard raw.count >= 3, raw.first?.isLowercase == true, raw.allSatisfy(\.isLetter),
                  !skip.contains(raw), !raw.hasSuffix("ly") else { continue }
            return raw
        }
        return nil
    }

    /// A recent line in the Reader's own hand, or a photograph they kept. Never from a hard day,
    /// never a private Page, rotating between openings among the freshest few.
    static func keepsake(day: BookDay, inputs: BookSourceInputs, now: Date, calendar: Calendar,
                         selectionSeed: Int) -> BookTodayEdition.Keepsake? {
        let cutoff = now.addingTimeInterval(-10 * 86_400)
        let days = (inputs.days.filter { $0.date >= calendar.startOfDay(for: cutoff) } + [day])
            .filter { !DistressSignals.evaluate(day: $0).isActive }
        let pages = days.flatMap(\.pages).filter { page in
            page.createdAt >= cutoff && page.createdAt <= now && page.privacy != .localSensitive && !isHeavy(page)
                && !EditionCurator.defaultPrivateTypes.contains(page.type)
                && ![.theBleed, .bookOfYou].contains(page.type)
                && page.weeklyIssueArtifact == nil && page.monthlyEditionArtifact == nil && page.annualEditionArtifact == nil
        }.sorted { $0.createdAt > $1.createdAt }
        var candidates: [BookTodayEdition.Keepsake] = []
        var seen = Set<String>()
        for page in pages where candidates.count < 5 && seen.insert(page.id).inserted {
            let when = label(for: page.createdAt, now: now, calendar: calendar)
            let aside = asides[abs("\(page.id)|\(selectionSeed)|aside".stableHash) % asides.count]
            if page.hasReaderPhotograph,
               let photo = page.mediaAssets.first(where: { $0.kind == .renderedImageFile || $0.kind == .bundledImage }) {
                candidates.append(.init(pageID: page.id, label: "\(when), you kept this", text: page.readerAuthoredTextForAnalysis?.nonEmpty,
                                        photo: photo, aside: aside))
            } else if let text = page.readerAuthoredTextForAnalysis?.trimmingCharacters(in: .whitespacesAndNewlines),
                      (5...60).contains(text.split(whereSeparator: \.isWhitespace).count), text.count <= 320 {
                candidates.append(.init(pageID: page.id, label: "\(when), you wrote", text: text, photo: nil, aside: aside))
            }
        }
        guard !candidates.isEmpty else { return nil }
        return candidates[abs("\(day.id)|\(selectionSeed)|keepsake".stableHash) % candidates.count]
    }

    static func label(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let hour = calendar.component(.hour, from: date)
            return hour < 12 ? "This morning" : hour < 17 ? "This afternoon" : "This evening"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return "On " + DateFormatter.bleedWeekday(calendar: calendar).string(from: date)
    }

    /// The edition on the mat, morning or evening: the headline the paper ran, or will run
    /// when it's opened. Nil outside the paper's hours.
    static func paper(day: BookDay, inputs: BookSourceInputs, now: Date, calendar: Calendar) -> BookTodayEdition.Doorstep? {
        guard let kind = TheBleedEditionBuilder.editionKind(for: now, calendar: calendar) else { return nil }
        let slot = TheBleedEditionBuilder.slotID(for: kind, day: day)
        let arrived = kind == .morning ? "The morning paper's come." : "The evening paper's in."
        // Already printed: the front page it actually ran.
        if let prepared = inputs.preparedBleedEditionSurface, prepared.payload.metadata["bleedSlotID"] == slot,
           let front = TheBleedEditionBuilder.decodedBriefs(prepared.payload.metadata["bleedPrintedColumns"] ?? "")
            .first(where: { $0.id == "front-page" }) {
            return .init(kind: kind, kicker: front.byline.components(separatedBy: " · ").first ?? "", headline: front.title,
                         line: "\(arrived) You're on the front page again.")
        }
        let history = inputs.bleedPrintHistory.filter { $0.slotID != slot }
        guard let front = BleedDayDesk.frontPage(kind: kind, day: day, inputs: inputs, now: now, calendar: calendar, history: history) else {
            return .init(kind: kind, kicker: "From the Academy", headline: "The Academy Has the Front Page",
                         line: "\(arrived) Yesterday was quiet, so Penny gave the front to the Academy.")
        }
        let line = front.title == BleedDayDesk.unfiledHeadline
            ? "\(arrived) Penny's holding the column for you."
            : "\(arrived) You're on the front page."
        return .init(kind: kind, kicker: front.byline.components(separatedBy: " · ").first ?? "", headline: front.title, line: line)
    }

    /// One outward invitation for the day, retaining the paper's exact Page
    /// when it has printed. All three families can return real proof.
    static func assignment(day: BookDay, inputs: BookSourceInputs, now: Date, calendar: Calendar) -> BookTodayEdition.Assignment? {
        guard !DistressSignals.evaluate(day: day).isActive else { return nil }
        if let receipt = BleedDayDesk.filedAssignmentPage(day: day, inputs: inputs)?.attributableLivedQuestReceipt {
            return .init(dareID: receipt.questID, title: receipt.title, challenge: receipt.invitation, filed: true)
        }
        guard (4..<21).contains(calendar.component(.hour, from: now)) else { return nil }
        let page = BleedDayDesk.dailyAssignmentPage(day: day, inputs: inputs, now: now, calendar: calendar)
        let details = BleedDayDesk.assignmentDetails(page)
        return .init(dareID: details.id, title: details.title, challenge: details.challenge, filed: false, page: page)
    }
}
