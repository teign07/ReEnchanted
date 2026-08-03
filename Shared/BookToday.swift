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

    var dayID: String
    var form: Form
    var headline: String
    var reading: String
    var atmosphereSymbolName: String
    var marginalMark: String?
    var beats: [Beat]
}

enum BookTodayProjector {
    static func edition(
        for day: BookDay,
        inputs: BookSourceInputs,
        relationship: BookRelationshipSnapshot,
        experienceProgram: BookExperienceProgram?,
        now: Date = Date(),
        calendar: Calendar = .current
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
            beats: Array(beats.prefix(4))
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
        case .dismissed: return "One possibility has been allowed to sleep."
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
