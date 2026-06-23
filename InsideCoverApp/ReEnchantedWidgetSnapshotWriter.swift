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
        radioIsPlaying: Bool
    ) {
        let snapshot = makeSnapshot(
            today: today,
            surfaces: surfaces,
            resurfacedPages: resurfacedPages,
            selfFacts: selfFacts,
            beliefScore: beliefScore,
            radio: radio,
            radioIsPlaying: radioIsPlaying
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
        radioIsPlaying: Bool
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
        let radio = radioStatus(from: radio, isPlaying: radioIsPlaying)
        let enchantments = enchantmentShortcuts()
        let belief = ReEnchantedWidgetBelief(
            title: "Glow",
            detail: beliefDetail(for: beliefScore),
            level: max(0, min(100, beliefScore))
        )

        return ReEnchantedWidgetSnapshot(
            generatedAt: Date(),
            privacyMode: .privateSafe,
            readerName: readerName,
            today: todayPage,
            compass: compass,
            remembered: remembered,
            sky: sky,
            radio: radio,
            enchantments: enchantments,
            belief: belief
        )
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
            point: point
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

    private static func radioStatus(from playback: RadioPlaybackState?, isPlaying: Bool) -> ReEnchantedWidgetRadio? {
        let stations = RadioStationRegistry.coreStations
        let station = playback?.activeStationID
            .flatMap { RadioStationRegistry.station(id: $0) }
            ?? stations.first
        guard let station else { return nil }
        return ReEnchantedWidgetRadio(
            activeStationID: station.id,
            title: station.title,
            detail: station.subtitle.bookPreviewSentenceLimit(1),
            symbolName: "radio",
            frequency: station.displayFrequency,
            signalLine: station.signalLine.bookPreviewSentenceLimit(1),
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
