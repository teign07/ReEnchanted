import Foundation

enum ReEnchantedWidgetPrivacyMode: String, Codable, Equatable {
    case privateSafe
    case personalText
}

struct ReEnchantedWidgetPage: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var source: String
    var symbolName: String
    var urlPath: String
}

struct ReEnchantedWidgetCompass: Codable, Equatable {
    var title: String
    var prompt: String
    var point: String
}

struct ReEnchantedWidgetMemory: Codable, Equatable {
    var title: String
    var body: String
    var ageLine: String
}

struct ReEnchantedWidgetSky: Codable, Equatable {
    var title: String
    var detail: String
    var symbolName: String
}

struct ReEnchantedWidgetRadio: Codable, Equatable {
    var activeStationID: String?
    var title: String
    var detail: String
    var symbolName: String
    var frequency: String
    var signalLine: String
    var isPlaying: Bool
    var stations: [ReEnchantedWidgetRadioStation]
}

enum ReEnchantedRadioWidgetCommandAction: String, Codable, Equatable {
    case tune
    case stop
}

struct ReEnchantedRadioWidgetCommand: Codable, Equatable, Identifiable {
    var id: UUID
    var action: ReEnchantedRadioWidgetCommandAction
    var stationID: String?
    var issuedAt: Date
}

struct ReEnchantedCompassWidgetRun: Codable, Equatable {
    var stepIndex: Int
    var startedAt: Date?
    var updatedAt: Date

    static let stepCount = 5

    static var idle: ReEnchantedCompassWidgetRun {
        ReEnchantedCompassWidgetRun(stepIndex: 0, startedAt: nil, updatedAt: Date(timeIntervalSinceReferenceDate: 0))
    }

    var isStarted: Bool {
        startedAt != nil
    }

    var isComplete: Bool {
        isStarted && stepIndex >= Self.stepCount - 1
    }
}

enum ReEnchantedCompassWidgetCommandAction: String, Codable, Equatable {
    case openRun
}

struct ReEnchantedCompassWidgetCommand: Codable, Equatable, Identifiable {
    var id: UUID
    var action: ReEnchantedCompassWidgetCommandAction
    var issuedAt: Date
}

struct ReEnchantedWidgetDeepLinkRequest: Codable, Equatable, Identifiable {
    var id: UUID
    var urlString: String
    var issuedAt: Date
}

struct ReEnchantedWidgetRadioStation: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var frequency: String
    var detail: String
    var signalLine: String
}

struct ReEnchantedWidgetEnchantment: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var symbolName: String
    var urlPath: String
}

struct ReEnchantedWidgetBelief: Codable, Equatable {
    var title: String
    var detail: String
    var level: Int
}

struct ReEnchantedWidgetWorldEvent: Codable, Equatable {
    var id: String
    var title: String
    var phase: String
    var detail: String
    var symbolName: String
    var urlPath: String
}

struct ReEnchantedWidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var privacyMode: ReEnchantedWidgetPrivacyMode
    var readerName: String?
    var today: ReEnchantedWidgetPage
    var compass: ReEnchantedWidgetCompass?
    var remembered: ReEnchantedWidgetMemory?
    var sky: ReEnchantedWidgetSky?
    var radio: ReEnchantedWidgetRadio?
    var worldEvent: ReEnchantedWidgetWorldEvent?
    var enchantments: [ReEnchantedWidgetEnchantment]
    var belief: ReEnchantedWidgetBelief?

    static let fallback = ReEnchantedWidgetSnapshot(
        generatedAt: Date(timeIntervalSinceReferenceDate: 0),
        privacyMode: .privateSafe,
        readerName: nil,
        today: ReEnchantedWidgetPage(
            id: "fallback",
            title: "The Book is waiting",
            body: "Open ReEnchanted and let today leave one page ajar.",
            source: "ReEnchanted",
            symbolName: "book.closed",
            urlPath: "today"
        ),
        compass: ReEnchantedWidgetCompass(
            title: "Wonder Compass",
            prompt: "Bring back one true sentence from wherever you are.",
            point: "Center"
        ),
        remembered: nil,
        sky: ReEnchantedWidgetSky(
            title: "Between Pages",
            detail: "The Academy is listening.",
            symbolName: "sparkles"
        ),
        radio: ReEnchantedWidgetRadio(
            activeStationID: "fae-fi",
            title: "Fae-Fi",
            detail: "Sun-dappled beats and dandelion synths.",
            symbolName: "radio",
            frequency: "88.3",
            signalLine: "The signal arrives tasting of clover honey and warm afternoons.",
            isPlaying: false,
            stations: [
                ReEnchantedWidgetRadioStation(
                    id: "fae-fi",
                    title: "Fae-Fi",
                    frequency: "88.3",
                    detail: "Sun-dappled beats.",
                    signalLine: "The signal arrives giggling."
                )
            ]
        ),
        worldEvent: nil,
        enchantments: [
            ReEnchantedWidgetEnchantment(
                id: "everything-speaks",
                title: "Everything Speaks",
                detail: "Let a real object answer through close attention.",
                symbolName: "camera.macro",
                urlPath: "enchantment/everything-speaks"
            ),
            ReEnchantedWidgetEnchantment(
                id: "everything-is-magic",
                title: "Everything's Magic",
                detail: "Reveal the spellbook nature of an ordinary subject.",
                symbolName: "sparkles",
                urlPath: "enchantment/everything-is-magic"
            ),
            ReEnchantedWidgetEnchantment(
                id: "mirror-mirror",
                title: "Mirror, Mirror",
                detail: "Ask a selfie for reflection, insight, and prophecy.",
                symbolName: "camera.viewfinder",
                urlPath: "enchantment/mirror-mirror"
            )
        ],
        belief: ReEnchantedWidgetBelief(
            title: "Glow",
            detail: "Ready",
            level: 30
        )
    )
}

enum ReEnchantedWidgetSnapshotStore {
    static let appGroup = "group.com.openclaw.enchantify.insidecover"
    static let stateKey = "reenchantedWidgetSnapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> ReEnchantedWidgetSnapshot {
        guard let data = defaults.data(forKey: stateKey) else {
            return .fallback
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ReEnchantedWidgetSnapshot.self, from: data)) ?? .fallback
    }

    static func save(_ snapshot: ReEnchantedWidgetSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: stateKey)
    }
}

enum ReEnchantedRadioWidgetCommandStore {
    static let commandKey = "reenchantedRadioWidgetCommand"

    static func load() -> ReEnchantedRadioWidgetCommand? {
        guard let data = ReEnchantedWidgetSnapshotStore.defaults.data(forKey: commandKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReEnchantedRadioWidgetCommand.self, from: data)
    }

    static func save(_ command: ReEnchantedRadioWidgetCommand) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(command)
        ReEnchantedWidgetSnapshotStore.defaults.set(data, forKey: commandKey)
    }

    static func clear(id: UUID? = nil) {
        if let id, load()?.id != id { return }
        ReEnchantedWidgetSnapshotStore.defaults.removeObject(forKey: commandKey)
    }
}

enum ReEnchantedCompassWidgetRunStore {
    static let runKey = "reenchantedCompassWidgetRun"
    static let commandKey = "reenchantedCompassWidgetCommand"

    static func loadRun() -> ReEnchantedCompassWidgetRun {
        guard let data = ReEnchantedWidgetSnapshotStore.defaults.data(forKey: runKey) else {
            return .idle
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ReEnchantedCompassWidgetRun.self, from: data)) ?? .idle
    }

    static func saveRun(_ run: ReEnchantedCompassWidgetRun) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(run)
        ReEnchantedWidgetSnapshotStore.defaults.set(data, forKey: runKey)
    }

    static func loadCommand() -> ReEnchantedCompassWidgetCommand? {
        guard let data = ReEnchantedWidgetSnapshotStore.defaults.data(forKey: commandKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReEnchantedCompassWidgetCommand.self, from: data)
    }

    static func saveCommand(_ command: ReEnchantedCompassWidgetCommand) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(command)
        ReEnchantedWidgetSnapshotStore.defaults.set(data, forKey: commandKey)
    }

    static func clearCommand(id: UUID? = nil) {
        if let id, loadCommand()?.id != id { return }
        ReEnchantedWidgetSnapshotStore.defaults.removeObject(forKey: commandKey)
    }
}

enum ReEnchantedWidgetDeepLinkStore {
    static let requestKey = "reenchantedWidgetDeepLinkRequest"

    @discardableResult
    static func enqueue(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "reenchanted" else { return false }
        let request = ReEnchantedWidgetDeepLinkRequest(
            id: UUID(),
            urlString: url.absoluteString,
            issuedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(request) else { return false }
        ReEnchantedWidgetSnapshotStore.defaults.set(data, forKey: requestKey)
        return true
    }

    static func load() -> ReEnchantedWidgetDeepLinkRequest? {
        guard let data = ReEnchantedWidgetSnapshotStore.defaults.data(forKey: requestKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReEnchantedWidgetDeepLinkRequest.self, from: data)
    }

    static func clear(id: UUID? = nil) {
        if let id, load()?.id != id { return }
        ReEnchantedWidgetSnapshotStore.defaults.removeObject(forKey: requestKey)
    }
}

extension Notification.Name {
    static let reEnchantedWidgetDeepLinkReceived = Notification.Name(
        "ReEnchantedWidgetDeepLinkReceived"
    )
}
