import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum ReEnchantedWidgetSnapshotWriter {
    static func write(
        today: BookDay,
        surfaces: [SurfacePage],
        resurfacedPages: [BookPage],
        selfFacts: [SelfFact],
        beliefScore: Int,
        radio: RadioPlaybackState?,
        radioIsPlaying: Bool,
        activeWorldEvents: [ResolvedWorldEvent] = [],
        bookInterior: BookInteriorState = .unawakened
    ) {
        let snapshot = makeSnapshot(
            today: today,
            surfaces: surfaces,
            resurfacedPages: resurfacedPages,
            selfFacts: selfFacts,
            beliefScore: beliefScore,
            radio: radio,
            radioIsPlaying: radioIsPlaying,
            activeWorldEvents: activeWorldEvents,
            bookInterior: bookInterior
        )
        try? ReEnchantedWidgetSnapshotStore.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func makeSnapshot(
        today: BookDay,
        surfaces: [SurfacePage],
        resurfacedPages: [BookPage],
        selfFacts: [SelfFact],
        beliefScore: Int,
        radio: RadioPlaybackState?,
        radioIsPlaying: Bool,
        activeWorldEvents: [ResolvedWorldEvent] = [],
        bookInterior: BookInteriorState = .unawakened
    ) -> ReEnchantedWidgetSnapshot {
        let readerName = selfFacts
            .first { $0.id == "onboarding:onboarding-name" }?
            .answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let todaySurface = preferredTodaySurface(from: surfaces)
        let todayPage = todaySurface.map(pageSummary(from:)) ?? fallbackTodayPage(for: today)
        let compass = compassPrompt(from: surfaces)
        let remembered = rememberedPage(from: resurfacedPages)
        let sky = skyStatus(from: surfaces)
        let radio = radioStatus(from: radio, isPlaying: radioIsPlaying, activeWorldEvents: activeWorldEvents)
        let worldEvent = worldEventStatus(from: activeWorldEvents)
        let enchantments = enchantmentShortcuts()
        let question = questionPrompt(from: surfaces)
        let belief = ReEnchantedWidgetBelief(
            title: "Glow",
            detail: beliefDetail(for: beliefScore),
            level: max(0, min(100, beliefScore))
        )
        let interior = interiorStatus(from: bookInterior)

        return ReEnchantedWidgetSnapshot(
            generatedAt: Date(),
            privacyMode: .privateSafe,
            readerName: readerName,
            today: todayPage,
            compass: compass,
            remembered: remembered,
            sky: sky,
            radio: radio,
            worldEvent: worldEvent,
            enchantments: enchantments,
            belief: belief,
            question: question,
            bookInterior: interior
        )
    }

    private static func questionPrompt(from surfaces: [SurfacePage]) -> ReEnchantedWidgetQuestion? {
        guard let surface = surfaces.first(where: {
            $0.payload.metadata["readerStatePulse"] == "true"
        }) else {
            return nil
        }
        return ReEnchantedWidgetQuestion(
            id: surface.id,
            title: surface.payload.headline.nonEmpty ?? "A question from the Book",
            prompt: privateSafeLine(
                body: surface.payload.body.nonEmpty ?? surface.detail,
                fallback: surface.prompt
            ),
            symbolName: "questionmark.bubble",
            urlPath: "question"
        )
    }

    private static func interiorStatus(from interior: BookInteriorState) -> ReEnchantedWidgetBookInterior? {
        guard interior.isAwake else { return nil }
        if let secret = interior.secret, secret.status == .ready {
            return ReEnchantedWidgetBookInterior(
                title: "A Sealed Leaf",
                line: "One of the Book's own secrets is ready to open.",
                symbolName: "seal",
                urlPath: "today"
            )
        }
        if let favor = interior.activeFavor, favor.status == .offered {
            return ReEnchantedWidgetBookInterior(
                title: "A Favor from the Book",
                line: "Optional fieldwork for \(favor.facet.verb): small enough for ordinary life.",
                symbolName: "bookmark",
                urlPath: "today"
            )
        }
        if let promise = interior.promise, promise.status == .keeping {
            return ReEnchantedWidgetBookInterior(
                title: "The Book Is Keeping Watch",
                line: "An unfinished promise is resting under the ribbon.",
                symbolName: "bookmark.fill",
                urlPath: "today"
            )
        }
        if interior.favorite?.firstPresentedAt == nil {
            return ReEnchantedWidgetBookInterior(
                title: "The Book Chose a Favorite",
                line: "A dog-eared Page is waiting inside. The Book has reasons.",
                symbolName: "book.pages",
                urlPath: "today"
            )
        }
        if let opinion = interior.opinion,
           opinion.firstPresentedAt == nil {
            return ReEnchantedWidgetBookInterior(
                title: opinion.strength == .reconsidering ? "The Book Revised Itself" : "The Book Has an Opinion",
                line: "A \(opinion.strength.confidenceLabel) thought is waiting with its evidence.",
                symbolName: "pencil.and.outline",
                urlPath: "today"
            )
        }
        if let quirk = interior.quirks.first(where: { $0.maturity != .latent && $0.firstPresentedAt == nil }) {
            return ReEnchantedWidgetBookInterior(
                title: "A Habit Became Visible",
                line: "This Book appears to have developed \(quirk.title.lowercased()).",
                symbolName: "book.closed",
                urlPath: "today"
            )
        }
        if let game = interior.longGame, game.phasePresentedAt == nil {
            return ReEnchantedWidgetBookInterior(
                title: "The Book Has Been Trying Something",
                line: "A quiet experiment has left a new note in the margins.",
                symbolName: "map",
                urlPath: "today"
            )
        }
        if let fascination = interior.fascination {
            return ReEnchantedWidgetBookInterior(
                title: "Current Fascination",
                line: "The Book is following a thread about \(fascination.facet.verb).",
                symbolName: "sparkle.magnifyingglass",
                urlPath: "today"
            )
        }
        return nil
    }

    private static func preferredTodaySurface(from surfaces: [SurfacePage]) -> SurfacePage? {
        let preferredTypes: [BookPageType] = [
            .bookRemembered,
            .todaysSky,
            .wonderCompass,
            .letter,
            .souvenir,
            .bookNotices,
            .radio
        ]
        for type in preferredTypes {
            if let surface = surfaces.first(where: { $0.type == type }) {
                return surface
            }
        }
        return surfaces.first
    }

    private static func pageSummary(from surface: SurfacePage) -> ReEnchantedWidgetPage {
        ReEnchantedWidgetPage(
            id: surface.id,
            title: surface.payload.headline.nonEmpty ?? surface.prompt.nonEmpty ?? surface.type.title,
            body: privateSafeLine(
                body: surface.payload.body.nonEmpty ?? surface.detail,
                fallback: surface.reason
            ),
            source: surface.type.shortTitle,
            symbolName: surface.type.symbolName,
            urlPath: urlPath(for: surface.type)
        )
    }

    private static func fallbackTodayPage(for day: BookDay) -> ReEnchantedWidgetPage {
        if let last = day.pages.last {
            return ReEnchantedWidgetPage(
                id: last.id,
                title: last.type.title,
                body: "A kept page is resting in the archive.",
                source: last.type.shortTitle,
                symbolName: last.type.symbolName,
                urlPath: urlPath(for: last.type)
            )
        }
        return ReEnchantedWidgetSnapshot.fallback.today
    }

    private static func compassPrompt(from surfaces: [SurfacePage]) -> ReEnchantedWidgetCompass? {
        guard let surface = surfaces.first(where: { $0.type == .wonderCompass }) else {
            return ReEnchantedWidgetSnapshot.fallback.compass
        }
        let point = surface.payload.metadata["compassStep"]?.capitalized.nonEmpty ?? "Compass"
        return ReEnchantedWidgetCompass(
            title: surface.payload.headline.nonEmpty ?? "Wonder Compass",
            prompt: privateSafeLine(body: surface.payload.body.nonEmpty ?? surface.detail, fallback: surface.prompt),
            point: point,
            run: compassRun(from: surface)
        )
    }

    private static func compassRun(from surface: SurfacePage) -> ReEnchantedWidgetCompassRun? {
        let metadata = surface.payload.metadata
        let id = metadata["runID"]?.nonEmpty ?? surface.id.nonEmpty ?? "compass-run"
        guard let spark = metadata["spark"]?.nonEmpty,
              let destination = metadata["destination"]?.nonEmpty,
              let delight = metadata["delight"]?.nonEmpty,
              let definition = metadata["definition"]?.nonEmpty,
              let mission = metadata["mission"]?.nonEmpty,
              let souvenirPrompt = metadata["souvenirPrompt"]?.nonEmpty,
              let restPrompt = metadata["restPrompt"]?.nonEmpty else {
            return nil
        }

        return ReEnchantedWidgetCompassRun(
            id: id,
            title: surface.payload.headline.nonEmpty ?? surface.prompt.nonEmpty ?? "Compass Run",
            mode: metadata["conciergeMode"]?.split(separator: "-").map { $0.capitalized }.joined(separator: " ") ?? "Wonder",
            timeBox: metadata["timeBox"]?.nonEmpty ?? "10-20 minutes",
            place: metadata["place"]?.nonEmpty ?? "where you are",
            energy: metadata["energy"]?.nonEmpty ?? "ordinary",
            companions: metadata["companions"]?.nonEmpty ?? "solo",
            north: spark,
            eastDestination: destination,
            eastDelight: delight,
            eastDefinition: definition,
            south: mission,
            west: souvenirPrompt,
            center: restPrompt,
            hint: metadata["hint"]?.nonEmpty
        )
    }

    private static func rememberedPage(from pages: [BookPage]) -> ReEnchantedWidgetMemory? {
        guard let page = pages.first else { return nil }
        return ReEnchantedWidgetMemory(
            title: page.type.shortTitle,
            body: "An old page is glowing near today.",
            ageLine: ageLine(for: page.createdAt)
        )
    }

    private static func skyStatus(from surfaces: [SurfacePage]) -> ReEnchantedWidgetSky? {
        if let sky = surfaces.first(where: { $0.type == .todaysSky || $0.type == .weather }) {
            return ReEnchantedWidgetSky(
                title: sky.payload.headline.nonEmpty ?? sky.type.title,
                detail: privateSafeLine(body: sky.payload.body.nonEmpty ?? sky.detail, fallback: sky.reason),
                symbolName: sky.type.symbolName
            )
        }
        return nil
    }

    private static func radioStatus(
        from playback: RadioPlaybackState?,
        isPlaying: Bool,
        activeWorldEvents: [ResolvedWorldEvent] = []
    ) -> ReEnchantedWidgetRadio? {
        let stations = RadioStationRegistry.coreStations
        let station = playback?.activeStationID
            .flatMap { RadioStationRegistry.station(id: $0) }
            ?? stations.first
        guard let station else { return nil }
        let eventLine = activeWorldEvents.radioAtmosphereLine?.bookPreviewSentenceLimit(1)
        return ReEnchantedWidgetRadio(
            activeStationID: station.id,
            title: station.title,
            detail: eventLine ?? station.subtitle.bookPreviewSentenceLimit(1),
            symbolName: "radio",
            frequency: station.displayFrequency,
            signalLine: eventLine ?? station.signalLine.bookPreviewSentenceLimit(1),
            isPlaying: isPlaying && playback?.activeStationID == station.id,
            stations: stations.prefix(4).map { station in
                ReEnchantedWidgetRadioStation(
                    id: station.id,
                    title: station.title,
                    frequency: station.displayFrequency,
                    detail: station.subtitle.bookPreviewSentenceLimit(1),
                    signalLine: station.signalLine.bookPreviewSentenceLimit(1)
                )
            }
        )
    }

    private static func worldEventStatus(from events: [ResolvedWorldEvent]) -> ReEnchantedWidgetWorldEvent? {
        guard let event = events.first else { return nil }
        return ReEnchantedWidgetWorldEvent(
            id: event.id,
            title: event.title,
            phase: event.phase.title,
            detail: (event.packet.widgetWhisperLine ?? event.phase.scene ?? event.packet.logline).bookPreviewSentenceLimit(1),
            symbolName: "textformat.abc.dottedunderline",
            urlPath: "today"
        )
    }

    private static func enchantmentShortcuts() -> [ReEnchantedWidgetEnchantment] {
        StoryEnchantmentCatalog.spells.prefix(6).map { spell in
            ReEnchantedWidgetEnchantment(
                id: spell.id,
                title: spell.title,
                detail: spell.detail.bookPreviewSentenceLimit(1),
                symbolName: symbolName(forEnchantmentID: spell.id),
                urlPath: "enchantment/\(spell.id)"
            )
        }
    }

    private static func symbolName(forEnchantmentID id: String) -> String {
        switch id {
        case "mirror-mirror":
            return "camera.viewfinder"
        case "everything-is-poetry", "everything-is-a-haiku":
            return "text.quote"
        case "everything-is-puzzling":
            return "questionmark.diamond"
        case "everything-is-connected", "everything-is-astral":
            return "sparkles"
        default:
            return "camera.macro"
        }
    }

    private static func privateSafeLine(body: String, fallback: String) -> String {
        let source = body.nonEmpty ?? fallback
        return source
            .replacingOccurrences(of: "\n", with: " ")
            .bookPreviewSentenceLimit(1)
    }

    private static func urlPath(for type: BookPageType) -> String {
        switch type {
        case .souvenir:
            return "capture/souvenir"
        case .wonderCompass:
            return "compass"
        case .bookRemembered:
            return "remembered"
        case .radio:
            return "radio"
        default:
            return "today"
        }
    }

    private static func ageLine(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "From today" }
        if days == 1 { return "From yesterday" }
        return "From \(days) days ago"
    }

    private static func beliefDetail(for score: Int) -> String {
        switch score {
        case ..<12:
            return "Low ember"
        case 12..<35:
            return "Steady"
        case 35..<70:
            return "Bright"
        default:
            return "Luminous"
        }
    }
}
