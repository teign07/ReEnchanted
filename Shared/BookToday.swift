import Foundation

/// A reader-facing projection of state the Book already owns. This is not a
/// second curator and stores no competing truth. It gives the existing session
/// score, world, Interior, and archive one composed daily frontispiece.
struct BookTodayEdition: Equatable {
    enum Form: String, Equatable {
        case almanacLeaf
        case weatherMap
        case observatoryWindow
        case sealedDocket
        case housePortrait
    }

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
    }

    var dayID: String
    var form: Form
    var headline: String
    var reading: String
    var atmosphereSymbolName: String
    var marginalMark: String?
    var beats: [Beat]
    var census: Census
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
        let form: BookTodayEdition.Form
        if event != nil {
            form = .sealedDocket
        } else if weather != nil {
            form = .weatherMap
        } else if inputs.bookInterior.currentDispute != nil
                    || !inputs.contestedQuestions.isEmpty {
            form = .housePortrait
        } else if intention != nil {
            form = .observatoryWindow
        } else {
            form = .almanacLeaf
        }

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
                line: "I recognize this as \(place.title). I'm reading the room before I speak.",
                symbolName: "location"
            ))
        }

        if let question = inputs.contestedQuestions.first {
            beats.append(.init(
                kind: .inTheMargins,
                line: "I can hear the margins arguing over “\(question.question)” They haven't asked permission.",
                symbolName: "person.2"
            ))
        } else if let dispute = inputs.bookInterior.currentDispute,
                  dispute.hasUnpresentedEvidence {
            beats.append(.init(
                kind: .inTheMargins,
                line: dispute.returnCount == 0
                    ? "Our argument grew fresh claw marks. I kept your sentence beside mine."
                    : "Our old argument's chewing the margin again. Something new fed it.",
                symbolName: "text.quote"
            ))
        } else if let business = inputs.bookInterior.runningBusiness,
                  business.hasUnpresentedChange {
            beats.append(.init(
                kind: .inTheMargins,
                line: business.latestLine,
                symbolName: "text.quote"
            ))
        } else if let dispute = inputs.bookInterior.currentDispute {
            beats.append(.init(
                kind: .inTheMargins,
                line: "I still claim “\(dispute.bookClaim)” Your sentence is beside it, biting back.",
                symbolName: "text.quote"
            ))
        } else if let event {
            beats.append(.init(
                kind: .inTheMargins,
                line: "I caught this in the margin: \(event.phase.packetLine)",
                symbolName: "text.quote"
            ))
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
                line: "You kept “\(pageName(latest)).” It's making weather under my cover now.",
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
                line: "I'll keep what mattered and let the rest of the day remain unbound.",
                symbolName: "moon.stars"
            ))
        }

        let mark = marginalMark(inputs.bookInterior)
        let reading = readingLine(
            intention: intention,
            weatherPresent: weather != nil,
            eventPresent: event != nil,
            relationship: relationship,
            hour: hour
        )
        return BookTodayEdition(
            dayID: day.id,
            form: form,
            headline: headline(
                intention: intention,
                event: event,
                weather: weather,
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
                calendar: calendar,
                selectionSeed: selectionSeed
            )
        )
    }

    private static func headline(
        intention: BookSessionIntention?,
        event: ResolvedWorldEvent?,
        weather: String?,
        mark: String?,
        hour: Int
    ) -> String {
        if let event {
            return "\(event.title) has got into my Stacks."
        }
        if let weather {
            let condition = weather
                .split(separator: ".")
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let mark {
                return "\(condition ?? "The outer weather's got under my cover"). \(capitalized(mark))."
            }
            return "\(condition ?? "The outer weather's got under my cover")."
        }
        if let live = intention?.liveOpportunity {
            return liveOpportunityHeadline(live.kind)
        }
        if let mark {
            return "\(capitalized(mark))."
        }
        if hour < 11 {
            return "The day's still chewing its name. I'm listening."
        }
        if hour >= 20 {
            return "I'm gathering the day's loose pages."
        }
        return "The room's hiding something ordinary. I'm watching its hands."
    }

    private static func readingLine(
        intention: BookSessionIntention?,
        weatherPresent: Bool,
        eventPresent: Bool,
        relationship: BookRelationshipSnapshot,
        hour: Int
    ) -> String {
        guard let intention else {
            if weatherPresent || eventPresent {
                return "Today's already making a racket. I'm after the one strange bit with muddy shoes."
            }
            return relationship.depth == .firstPages
                ? "I don't know enough yet. Good. I'm watching."
                : "The day hasn't shown me its hinge. I'm not making one up."
        }
        let opening = hour < 12 ? "This morning" : (hour < 18 ? "Today" : "This evening")
        return "\(opening), I'm \(attemptLine(for: intention.movement)) \(ambitionEnding(intention.ambition))"
    }

    private static func attemptLine(for movement: BookReenchantmentMovement) -> String {
        switch movement {
        case .freshSight: return "trying to make one familiar thing visible again."
        case .livingWorld: return "looking for proof that the world has business of its own."
        case .scriptFreedom: return "leaving one expected script unlocked."
        case .chosenDetour: return "keeping watch for one worthwhile detour."
        case .exactLanguage: return "waiting for the exact words that make an ordinary thing yours."
        case .humanOtherness: return "making room for another person to remain surprising."
        case .livingContinuity: return "bringing an earlier thing back into the present."
        case .shelter: return "keeping my voice down and making room around you."
        }
    }

    private static func ambitionEnding(_ ambition: BookSessionAmbition) -> String {
        switch ambition {
        case .glint: return "I'll take one glint."
        case .connection: return "I'm arranging a connection, not a conclusion."
        case .return: return "I've got something sniffing its way back."
        case .intervention: return "I think the opening's worth acting on."
        case .revelation: return "I suspect two distant things have been passing notes."
        }
    }

    private static func nightfallLine(
        for intention: BookSessionIntention,
        hour: Int
    ) -> String {
        if intention.liveOpportunity != nil {
            return "The opening is real but temporary. I've put the useful doors among the Pages above."
        }
        if hour >= 18 {
            return "I'm watching to see what follows you home—not whether you obeyed it."
        }
        return "By nightfall, I hope there'll be one detail today couldn't have produced without you."
    }

    private static func consequenceLine(for stage: BookExperienceCueStage) -> String {
        switch stage {
        case .opened: return "A Page you opened is still warm at the binding. I haven't mistaken attention for an answer."
        case .acted: return "Something crossed the threshold from Page into life. I'm waiting for what comes back."
        case .kept: return "A kept Page has crawled under my binding. It's staying."
        case .loved: return "One Page has been given unusual weight. I've dog-eared the evidence."
        case .displayed: return "A Page is waiting without tapping the glass."
        case .dismissed: return "One possibility was sent back under the furniture."
        }
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
            return "a long game has moved"
        }
        if interior.favorite?.firstPresentedAt == nil, interior.favorite != nil {
            return "one Page has been dog-eared"
        }
        return nil
    }

    private static func liveOpportunityHeadline(_ kind: BookLiveOpportunityKind) -> String {
        switch kind {
        case .shelterNeeded: return "I've lowered my voice."
        case .nearbyAnchorArrived: return "I can smell a familiar place nearby."
        case .weatherTurned: return "The weather changed the rules. I saw it."
        case .placeOpened: return "I found a nearby door standing open."
        case .calendarWindowOpened: return "I found a hole in the day's fence."
        case .capacityOpened: return "The day made room. I've put my foot in it."
        }
    }

    private static func pageName(_ page: BookPage) -> String {
        page.promptText.nonEmpty
            .map { String($0.prefix(72)) }
            ?? page.type.rawValue
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

    static func census(
        for day: BookDay,
        inputs: BookSourceInputs,
        relationship: BookRelationshipSnapshot,
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
            facts: selectedFacts(from: candidates, selectionSeed: selectionSeed, limit: 4),
            closingLine: closingLine(
                inputs: inputs,
                relationship: relationship,
                pageCount: pages.count,
                selectionSeed: selectionSeed
            )
        )
    }

    private static func archivePages(day: BookDay, inputs: BookSourceInputs) -> [BookPage] {
        var byID: [String: BookPage] = [:]
        for page in (inputs.days + [day]).flatMap(\.pages) {
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
                "I have \(mediaCount) scraps that are not made only of ink."
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
                "Other people have left \(relationshipReceipts) inspectable \(word(relationshipReceipts, one: "trace", many: "traces")) in the binding."
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
                "\(finishedTales) \(word(finishedTales, one: "tale has", many: "tales have")) found an ending without pretending to be finished forever.",
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
                "I am keeping watch over \(livingConstellations) returning \(word(livingConstellations, one: "pattern", many: "patterns"))."
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
                "Things the Book thought had gone quiet have returned \(constellationReturns) \(word(constellationReturns, one: "time", many: "times")).",
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
                "The sealed margin contains \(inputs.wagers.count) \(word(inputs.wagers.count, one: "bet", many: "bets")) I was not certain I could win."
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
                "I have had to repair \(admittedFaults) of my own \(word(admittedFaults, one: "mistake", many: "mistakes")).",
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
                "Living with you has given me \(revealedQuirks) observable \(word(revealedQuirks, one: "quirk", many: "quirks")).",
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
                "You and I have kept \(disputes) \(word(disputes, one: "argument", many: "arguments")) without flattening either side.",
                "There are \(disputes) honest \(word(disputes, one: "disagreement", many: "disagreements")) in the margins. I did not eat yours."
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
                "\(inputs.pocket.count) small \(word(inputs.pocket.count, one: "thing is", many: "things are")) hiding in the Book's coat."
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
                "\(inputs.readerLexicon.redefinedEntries.count) \(word(inputs.readerLexicon.redefinedEntries.count, one: "word now means", many: "words now mean")) something the Dictionary did not authorize.",
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
                "You have permitted me to carry \(usableFacts) \(word(usableFacts, one: "truth", many: "truths")) about you.",
                "I know \(usableFacts) reader-approved \(word(usableFacts, one: "thing", many: "things")) and am forbidden to pretend I know the rest."
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
                "\(relationship.protectedBoundaryCount) hard \(word(relationship.protectedBoundaryCount, one: "boundary is", many: "boundaries are")) written into how I read you.",
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
                "The recent Academy ledger contains \(recentCastMovements) offstage \(word(recentCastMovements, one: "movement", many: "movements")).",
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
            let hasReaderInk = !page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasReaderInk { summary.writtenPageCount += 1 }
            summary.mediaCount += page.mediaAssets.count
            if page.userInput.contains("?") || page.playerReply.contains("?") {
                summary.questionPageCount += 1
            }
            summary.longestReaderLineWordCount = max(
                summary.longestReaderLineWordCount,
                wordCount("\(page.userInput) \(page.playerReply)")
            )
            if page.type == .plainPage { summary.unpromptedPageCount += 1 }
            if page.type == .bookRemembered { summary.returnedPageCount += 1 }
            if page.type == .bookOfYou { summary.bookOfYouCount += 1 }
            if page.livedQuestReceipt != nil { summary.livedReceiptCount += 1 }
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
            return "I am still mostly cover. That will not last."
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
                greeting = "What in the wild margins—where have you been?"
            }

            if let news = returnNews(from: inputs) {
                return variant([
                    "\(greeting) \(news) Can you believe it? Kept your place anyway.",
                    "\(greeting) Listen: \(news) I have been sitting on this. Kept your place.",
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

    private static func word(_ count: Int, one: String, many: String) -> String {
        count == 1 ? one : many
    }

    private static func wordCount(_ value: String) -> Int {
        value.split(whereSeparator: \.isWhitespace).count
    }

    private static func variant(_ values: [String], key: String) -> String {
        guard !values.isEmpty else { return "" }
        let index = Int(UInt(bitPattern: key.stableHash) % UInt(values.count))
        return values[index]
    }
}
