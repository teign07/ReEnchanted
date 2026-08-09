import Foundation
import SwiftUI
import UIKit

enum InsideCoverStore {
    static let appGroup = "group.com.openclaw.enchantify.insidecover"
    static let stateKey = "insideCoverState"
    static let imageName = "widget-image.png"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static var imageURL: URL? {
        containerURL?.appendingPathComponent(imageName)
    }

    static func load() -> InsideCoverState {
        guard let data = defaults.data(forKey: stateKey) else {
            return loadBundledSample() ?? .fallback
        }
        do {
            return try JSONDecoder().decode(InsideCoverState.self, from: data)
        } catch {
            return loadBundledSample() ?? .fallback
        }
    }

    static func save(_ state: InsideCoverState) throws {
        var storedState = state
        storedState.imageData = nil
        let data = try JSONEncoder().encode(storedState)
        defaults.set(data, forKey: stateKey)
        if let encoded = state.imageData,
           let bytes = Data(base64Encoded: encoded),
           let url = imageURL {
            try SensitiveFileProtection.write(bytes, to: url)
        }
    }

    static func importJSON(from url: URL) throws -> InsideCoverState {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(InsideCoverState.self, from: data)
        try save(state)
        return state
    }

    static func loadBundledSample() -> InsideCoverState? {
        guard let url = Bundle.main.url(forResource: "widget-state", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(InsideCoverState.self, from: data) else {
            return nil
        }
        return state
    }

    static func loadImage() -> UIImage? {
        if let url = imageURL,
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        if let encoded = load().imageData,
           let data = Data(base64Encoded: encoded) {
            return UIImage(data: data)
        }
        return nil
    }
}

protocol Braider {
    func braid(day: BookDay) async throws -> BookPage
    func braid(day: BookDay, context: BraidPromptBuilder.Context) async throws -> BookPage
}

extension Braider {
    func braid(day: BookDay) async throws -> BookPage {
        try await braid(day: day, context: .empty)
    }
}

protocol WonderCompassPassageChoosing {
    func chooseWonderCompassSnippet(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) async throws -> ReferenceSnippet
}

protocol WeatherEnchanting {
    func enchantWeather(weather: WeatherSourceSignal, day: BookDay) async throws -> EnchantedWeatherSignal
}

protocol AskTheBookAnswering {
    func answer(
        prompt: String,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        readerLexicon: ReaderLexicon,
        memory: AskTheBookMemoryPacket,
        relationship: BookRelationshipSnapshot,
        interior: BookInteriorState,
        bookVoicePatina: BookVoicePatina
    ) async throws -> String
}

protocol FaeBargainResponding {
    func respond(bargain: FaeBargain, report: String, mood: GoblinMood, day: BookDay) async throws -> String
}

protocol InkrestOfficeHoursCounseling {
    func reply(
        intake: InkrestIntake,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        userMessage: String,
        isClosing: Bool
    ) async throws -> String
}

struct OuterStacksRoomSpec: Codable, Equatable {
    var roomDescription: String
    var academyEcho: String
    var fae: String
    var miniStory: String
    var localRule: String
    var emotionalRegister: String? = nil
}

struct AnchorGenerationContext: Equatable {
    var anchorName: String
    var playerWords: String
    var kind: AnchorKind
    var weather: String
    var moon: String
    var season: String
    var belief: Int
    var place: AnchorPlaceIdentity?
    var recentRoomAtmospheres: [String]

    var storyName: String {
        guard let place, !place.usesRealNameInStory else { return anchorName }
        return "this \(place.category.nonEmpty ?? "place") Anchor"
    }
}

enum AnchorRoomOutputAudit {
    private static let staleGothicDefaults = [
        "mold", "mould", "mildew", "musty", "damp", "rotting", "decay",
        "stale air", "abandoned", "cobweb", "dusty", "in the dust",
        "shadows gather", "whispers from", "older than the catalogue",
        "waiting to be noticed", "unnamed ancient"
    ]
    private static let earnedDarknessCues = [
        "dark", "night", "creepy", "haunted", "afraid", "uneasy", "grief",
        "shadow", "abandoned", "ancient", "very old", "decay", "mold", "mould", "damp",
        "fog", "storm", "funeral", "cemetery"
    ]

    static func accepts(_ spec: OuterStacksRoomSpec, context: AnchorGenerationContext) -> Bool {
        let evidence = [
            context.playerWords,
            context.weather,
            context.place?.name ?? "",
            context.place?.category ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
        let darknessIsEarned = earnedDarknessCues.contains(where: evidence.contains)
        guard !darknessIsEarned else { return true }

        let output = [
            spec.roomDescription,
            spec.academyEcho,
            spec.fae,
            spec.miniStory,
            spec.localRule,
            spec.emotionalRegister ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
        let staleCount = staleGothicDefaults.reduce(into: 0) { count, motif in
            if output.contains(motif) { count += 1 }
        }
        return staleCount < 2
    }
}

protocol OuterStacksRoomWriting {
    func room(context: AnchorGenerationContext) async throws -> OuterStacksRoomSpec

    func visitScene(anchor: AnchorRecord, visitCount: Int, day: BookDay, memory: String) async throws -> String
}

/// Offline room generation: deterministic, built from the player's own words,
/// so anchoring always works even before the local brain is installed.
struct FakeOuterStacksRoomWriter: OuterStacksRoomWriting {
    func room(context: AnchorGenerationContext) async throws -> OuterStacksRoomSpec {
        let words = context.playerWords.trimmingCharacters(in: .whitespacesAndNewlines)
        let seedLine: String
        if !words.isEmpty {
            seedLine = words
        } else if let place = context.place {
            let placeName = place.usesRealNameInStory ? place.name : "this place"
            seedLine = "the real habits of \(placeName), a \(place.category.nonEmpty ?? "place")"
        } else {
            seedLine = "a place that asked to be kept"
        }
        let kindRoom: String
        let kindRule: String
        var register: String
        let placeText = [context.place?.name, context.place?.category]
            .compactMap { $0?.nonEmpty }
            .joined(separator: " ")
            .lowercased()
        if ["cafe", "coffee", "bakery", "restaurant", "diner"].contains(where: placeText.contains) {
            kindRoom = "a quick warm counter where cups trade unfinished plans and the kettle keeps interrupting"
            kindRule = "Give one ordinary order an unnecessarily exact name."
            register = "warm, bustling, sociable, and a little competitive"
        } else if ["preserve", "park", "trail", "garden", "beach", "forest"].contains(where: placeText.contains) {
            kindRoom = "an open map-room of live paths, weather-marked signs, and leaves that keep changing the route"
            kindRule = "Let one living thing finish what it is doing before you pass."
            register = "open, green, alert, and seasonal"
        } else if ["cannabis", "dispensary"].contains(where: placeText.contains) {
            kindRoom = "a bright apothecary registry where fragrant jars dispute their names behind impeccable glass"
            kindRule = "Describe the evidence of one scent before asking what it promises."
            register = "fragrant, orderly, bright, and mischievously bureaucratic"
        } else if ["store", "market", "shop", "hardware", "thrift", "antiques"].contains(where: placeText.contains) {
            kindRoom = "a colorful exchange hall where useful objects haggle over who gets to leave next"
            kindRule = "Ask one object what work it believes it was made for."
            register = "busy, practical, acquisitive, and colorful"
        } else if ["harbor", "marina", "waterfront", "pier", "river"].contains(where: placeText.contains) {
            kindRoom = "a salt-bright chart room whose ropes, bells, and windows all keep separate accounts of the tide"
            kindRule = "Count three moving things before choosing which one to follow."
            register = "restless, spacious, salt-bright, and expectant"
        } else {
            switch context.kind {
            case .notice:
                kindRoom = "a sunlit cabinet of field glasses, each fixed on one small true thing"
                kindRule = "Name one specific detail out loud before touching anything."
                register = "curious, precise, awake, and sunlit"
            case .embark:
                kindRoom = "a brisk corridor of doors cut to different sizes, every key already impatient in its lock"
                kindRule = "No path may be chosen until one small hunger is admitted."
                register = "anticipatory, kinetic, hungry, and clear-edged"
            case .sense:
                kindRoom = "low tables holding bowls of weather, each one vivid at a different temperature"
                kindRule = "Whatever you touch here, describe it with a sense you rarely use."
                register = "vivid, embodied, changeable, and immediate"
            case .write:
                kindRoom = "writing desks facing every direction while the inkwells argue over verbs"
                kindRule = "Nothing leaves this room unless it fits in one sentence."
                register = "articulate, unruly, comic, and intent"
            case .rest:
                kindRoom = "deep chairs around a generous hearth that refuses to hurry anyone"
                kindRule = "You may not begin anything here. Only finish, or simply sit."
                register = "warm, drowsy, protective, and unhurried"
            }
        }
        let wordText = words.lowercased()
        if ["laugh", "love", "friend", "warm", "sun", "joy"].contains(where: wordText.contains) {
            register = "bright, affectionate, lively, and warm"
        } else if ["quiet", "peace", "calm", "safe", "rest", "breathe"].contains(where: wordText.contains) {
            register = "calm, spacious, steady, and unhurried"
        } else if ["grief", "miss", "lonely", "sad", "hard day"].contains(where: wordText.contains) {
            register = "tender, spare, honest, and steady"
        } else if ["busy", "loud", "crowd", "alive", "energy"].contains(where: wordText.contains) {
            register = "noisy, kinetic, crowded, and alive"
        } else if ["funny", "ridiculous", "weird", "silly"].contains(where: wordText.contains) {
            register = "comic, unruly, bright, and mischievous"
        } else if ["creepy", "haunted", "afraid", "dark", "uneasy"].contains(where: wordText.contains) {
            register = "eerie, watchful, sharp, and deliberately shadowed"
        }
        return OuterStacksRoomSpec(
            roomDescription: "A room in the Outer Stacks has taken \(seedLine) literally. Inside, \(kindRoom). It carries \(context.season.lowercased()) and \(context.weather.lowercased()) without letting either decide its mood.",
            academyEcho: "From the Inside Stacks, the new door keeps borrowing the colors and habits of \(context.storyName).",
            fae: "A \(context.kind.title) Fae is halfway through a very specific job and objects to being interrupted badly",
            miniStory: "One ordinary habit of this place has started making its own decisions. The Fae needs a witness, though it dislikes needing anybody.",
            localRule: kindRule,
            emotionalRegister: register
        )
    }

    func visitScene(anchor: AnchorRecord, visitCount: Int, day: BookDay, memory: String = "") async throws -> String {
        let season = anchor.season.nonEmpty ?? AnchorRegistry.currentSeason(for: day.date)
        let room = anchor.outerStacksRoom.nonEmpty
            ?? "The room has not fully written itself yet, but its threshold is present."
        let fae = anchor.fae.nonEmpty ?? "the Fae who keeps this place"
        let rule = anchor.localRule.nonEmpty ?? "Notice before you take a step."
        let motion = anchor.miniStory.nonEmpty
            ?? "Something in the room has been waiting for a witness."
        let returnMemory = memory.trimmingCharacters(in: .whitespacesAndNewlines)

        let register = anchor.emotionalRegister?.nonEmpty ?? "particular, alert, and awake"
        let opening = visitCount <= 1
            ? "The threshold at \(anchor.storyName) opens in its own \(register) way. \(season) barges through first, and the room makes space for you without pretending it was empty."
            : "The threshold at \(anchor.storyName) remembers the shape of your last visit. On return \(visitCount), one useful thing has changed places and another is loudly denying it."
        let memoryLine = returnMemory.isEmpty
            ? "Nothing here behaves like a display. \(room)"
            : "The room has kept a trace of what you left it: \(returnMemory.bookPreviewSentenceLimit(2)) This time, \(room)"

        return """
        \(opening)

        \(memoryLine)

        \(fae) pauses in the middle of their work, not surprised exactly, but no longer able to pretend the visit is accidental. \(motion) The rule presses gently at the edge of the scene: \(rule)

        The room watches what you do with its rule. One ordinary object answers in a manner entirely consistent with this place and entirely impossible anywhere else.
        """
    }
}

protocol EnchantmentWriting {
    func cast(spell: EnchantmentSpell, analysis: PhotoAnalysis, day: BookDay) async throws -> EnchantmentCastResult
    func answerObject(prompt: String, result: EnchantmentCastResult, previousTurns: [AskTheBookTurn], day: BookDay) async throws -> String
}

struct EnchantmentCastResult: Codable, Equatable {
    var spellID: String
    var spellName: String
    var subjectName: String
    var openingLine: String
    var resultText: String
    var objectVoice: String?

    var conversationSeed: String {
        [
            "Spell: \(spellName)",
            "Subject: \(subjectName)",
            "Opening: \(openingLine)",
            resultText,
            objectVoice.map { "Voice: \($0)" }
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}

enum LocalModelState: String, Codable, Equatable {
    case missing
    case ready
    case unavailable
}

struct LocalModelReport: Codable, Equatable {
    var state: LocalModelState
    var preferredModelID: String
    var fallbackModelID: String
    var preferredModelSource: String
    var fallbackModelSource: String
    var installPath: String
    var detail: String
    var deviceSummary: String

    var title: String {
        switch state {
        case .missing:
            return "Brain not installed"
        case .ready:
            return "Local brain ready"
        case .unavailable:
            return "Brain unavailable"
        }
    }

    var isReady: Bool {
        state == .ready
    }
}

enum LocalModelError: LocalizedError {
    case missingModel(LocalModelReport)

    var errorDescription: String? {
        switch self {
        case .missingModel(let report):
            return "\(report.preferredModelID) is not installed yet."
        }
    }
}

struct ActiveLocalModel: Codable, Equatable {
    var modelID: String
    var path: String
    var revision: String?
    var activatedAt: Date
}

enum LocalModelManager {
    struct ModelChoice: Codable, Equatable {
        var modelID: String
        var label: String
        var minimumMemoryGB: Int
        var sourceURL: String
        var reason: String
        var revision: String = "main"
        var supersedes: [String] = []
    }

    static let compactModel = ModelChoice(
        modelID: "mlx-community/gemma-3-1b-it-4bit",
        label: "Gemma 3 1B 4-bit",
        minimumMemoryGB: 0,
        sourceURL: "https://huggingface.co/mlx-community/gemma-3-1b-it-4bit",
        reason: "smallest local brain, best for standard iPhones",
        revision: "2d44e83dc9e80843d22fb941d3d699a0b1351aa6"
    )
    static let balancedModel = ModelChoice(
        modelID: "mlx-community/gemma-4-e2b-it-4bit",
        label: "Gemma 4 E2B 4-bit",
        minimumMemoryGB: 6,
        sourceURL: "https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit",
        reason: "recommended local brain for iPhone 15-class devices; this is the Gemma 4 E2B checkpoint shipped in the current MLX Swift model catalog",
        revision: "238767527555cb75a05732a84dff5d6ba0dd6809",
        supersedes: [
            "mlx-community/gemma-4-e2b-it-OptiQ-4bit"
        ]
    )
    static let expansiveModel = ModelChoice(
        modelID: "mlx-community/gemma-4-e4b-it-4bit",
        label: "Gemma 4 E4B 4-bit",
        minimumMemoryGB: 8,
        sourceURL: "https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit",
        reason: "larger local brain for iPhone 17-class devices and high-memory iPads; this is the Gemma 4 E4B checkpoint shipped in the current MLX Swift model catalog",
        revision: "475b9088d29754a3379866cf5aeb6b41acd313c2",
        supersedes: [
            "mlx-community/gemma-4-e4b-it-OptiQ-4bit"
        ]
    )
    static let allModelChoices = [compactModel, balancedModel, expansiveModel]
    static let modelsDirectoryName = "LocalModels"
    static let activeModelMarkerName = "active-model.json"

    static var preferredModel: ModelChoice {
        let memoryGB = deviceMemoryGB
        if memoryGB >= expansiveModel.minimumMemoryGB,
           !isIPhone15ClassHardware {
            return expansiveModel
        }
        if memoryGB >= balancedModel.minimumMemoryGB {
            return balancedModel
        }
        return compactModel
    }

    static var preferredModelID: String {
        preferredModel.modelID
    }

    static var fallbackModelID: String {
        compactModel.modelID
    }

    static var deviceMemoryGB: Int {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824
        return max(1, Int(gb.rounded(.toNearestOrAwayFromZero)))
    }

    static var hardwareIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(String(UnicodeScalar(UInt8(value))))
        }
    }

    static var isIPhone15ClassHardware: Bool {
        // iPhone 15 and iPhone 15 Pro families report as iPhone15,4/5 and iPhone16,1/2.
        hardwareIdentifier.hasPrefix("iPhone15,") || hardwareIdentifier.hasPrefix("iPhone16,")
    }

    static var deviceSummary: String {
        "\(hardwareIdentifier), about \(deviceMemoryGB) GB memory"
    }

    /// Whether a checkpoint has a vision tower at all.
    ///
    /// This is the only static question worth asking about direct vision.
    /// Whether the device can *afford* a given run is a live question, and
    /// `LocalBrainInferenceGate` already answers it properly: it measures the
    /// real allowance, drops warm weights and measures again, and declines with
    /// an error the caller can fall back from. The old check here was a flat
    /// `deviceMemoryGB >= 8`, which was never a memory measurement — it was a
    /// guess that happened to exclude every 6 GB phone, including the ones
    /// already running this same checkpoint for text all day.
    static func modelSupportsVision(modelID: String) -> Bool {
        modelID.contains("gemma-4")
    }

    static var activeModelSupportsVision: Bool {
        guard let directory = activeModelDirectory else { return false }
        return modelSupportsVision(modelID: directory.path)
    }

    private static var supportDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        return baseURL.appendingPathComponent(bundleID, isDirectory: true)
    }

    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    static var modelsDirectory: URL {
        supportDirectory.appendingPathComponent(modelsDirectoryName, isDirectory: true)
    }

    static var activeModelMarkerURL: URL {
        modelsDirectory.appendingPathComponent(activeModelMarkerName)
    }

    static func modelDirectory(for modelID: String) -> URL {
        let folderName = modelID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return modelsDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    static var activeModelDirectory: URL? {
        activeModelCandidate?.directory
    }

    private static var activeModelCandidate: (choice: ModelChoice, directory: URL)? {
        if let marker = activeModelMarker,
           activeModelIDs.contains(marker.modelID),
           let choice = allModelChoices.first(where: { $0.modelID == marker.modelID }),
           marker.revision == choice.revision,
           modelFilesArePresent(at: URL(fileURLWithPath: marker.path)) {
            return (choice, URL(fileURLWithPath: marker.path))
        }

        let candidates = activeModelChoices.flatMap { choice in
            ([modelDirectory(for: choice.modelID)] + huggingFaceSnapshotDirectories(for: choice.modelID))
                .map { directory in (choice: choice, directory: directory) }
        }
        return candidates.first {
            directoryRevision(at: $0.directory) == $0.choice.revision
                && modelFilesArePresent(at: $0.directory)
        }
    }

    private static var activeModelIDs: [String] {
        [preferredModelID]
    }

    private static var activeModelChoices: [ModelChoice] {
        [preferredModel]
    }

    private static var activeModelMarker: ActiveLocalModel? {
        guard let data = try? Data(contentsOf: activeModelMarkerURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ActiveLocalModel.self, from: data)
    }

    static func activateModel(modelID: String, directory: URL) throws {
        let revision = allModelChoices.first(where: { $0.modelID == modelID })?.revision
        try FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true
        )
        let marker = ActiveLocalModel(
            modelID: modelID,
            path: directory.path,
            revision: revision,
            activatedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(marker)
        try data.write(to: activeModelMarkerURL, options: [.atomic])
        try data.write(to: directory.appendingPathComponent(activeModelMarkerName), options: [.atomic])
    }

    static func report() -> LocalModelReport {
        #if !NATIVE_LOCAL_BRAIN || !(canImport(MLXLMHFAPI) && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX))
        return LocalModelReport(
            state: .unavailable,
            preferredModelID: preferredModelID,
            fallbackModelID: fallbackModelID,
            preferredModelSource: preferredModel.sourceURL,
            fallbackModelSource: compactModel.sourceURL,
            installPath: modelsDirectory.path,
            detail: "The native local brain is disabled in this safe startup build while its launch-time package crash is isolated.",
            deviceSummary: deviceSummary
        )
        #else
        do {
            try FileManager.default.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return LocalModelReport(
                state: .unavailable,
                preferredModelID: preferredModelID,
                fallbackModelID: fallbackModelID,
                preferredModelSource: preferredModel.sourceURL,
                fallbackModelSource: compactModel.sourceURL,
                installPath: modelsDirectory.path,
                detail: "The app could not prepare its local model folder: \(error.localizedDescription)",
                deviceSummary: deviceSummary
            )
        }

        if let active = activeModelCandidate {
            return LocalModelReport(
                state: .ready,
                preferredModelID: preferredModelID,
                fallbackModelID: fallbackModelID,
                preferredModelSource: preferredModel.sourceURL,
                fallbackModelSource: compactModel.sourceURL,
                installPath: active.directory.path,
                detail: "\(active.choice.label) is present. I chose it for this device: \(active.choice.reason).",
                deviceSummary: deviceSummary
            )
        }

        return LocalModelReport(
            state: .missing,
            preferredModelID: preferredModelID,
            fallbackModelID: fallbackModelID,
            preferredModelSource: preferredModel.sourceURL,
            fallbackModelSource: compactModel.sourceURL,
            installPath: modelsDirectory.path,
            detail: "I recommend \(preferredModel.label) for this device: \(preferredModel.reason). Install it here, then braiding can stay local.",
            deviceSummary: deviceSummary
        )
        #endif
    }

    static func removeSupersededModels(for modelID: String, preserving activeDirectory: URL) {
        guard let choice = allModelChoices.first(where: { $0.modelID == modelID }) else {
            return
        }

        let fileManager = FileManager.default
        for oldModelID in choice.supersedes {
            let directory = modelDirectory(for: oldModelID)
            guard directory.standardizedFileURL != activeDirectory.standardizedFileURL,
                  fileManager.fileExists(atPath: directory.path) else {
                continue
            }
            try? fileManager.removeItem(at: directory)
        }
    }

    static func removeKnownLocalModels() {
        let fileManager = FileManager.default
        let modelIDs = Set(allModelChoices.flatMap { [$0.modelID] + $0.supersedes })

        try? fileManager.removeItem(at: activeModelMarkerURL)

        for modelID in modelIDs {
            let directory = modelDirectory(for: modelID)
            if fileManager.fileExists(atPath: directory.path) {
                try? fileManager.removeItem(at: directory)
            }

            let cacheDirectory = huggingFaceModelCacheDirectory(for: modelID)
            if fileManager.fileExists(atPath: cacheDirectory.path) {
                try? fileManager.removeItem(at: cacheDirectory)
            }
        }
    }

    private static func modelFilesArePresent(at directory: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            return false
        }

        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        let hasConfig = files.contains("config.json")
        let hasWeights = files.contains { $0.hasSuffix(".safetensors") }
        let hasTokenizer = files.contains { name in
            name == "tokenizer.json" || name == "tokenizer.model" || name.hasPrefix("tokenizer_config")
        }
        return hasConfig && hasWeights && hasTokenizer
    }

    private static func directoryRevision(at directory: URL) -> String? {
        let markerURL = directory.appendingPathComponent(activeModelMarkerName)
        guard let data = try? Data(contentsOf: markerURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ActiveLocalModel.self, from: data))?.revision
    }

    private static func huggingFaceSnapshotDirectories(for modelID: String) -> [URL] {
        let snapshotsDirectory = huggingFaceModelCacheDirectory(for: modelID)
            .appendingPathComponent("snapshots", isDirectory: true)

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return snapshots.sorted { left, right in
            let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
    }

    private static func huggingFaceModelCacheDirectory(for modelID: String) -> URL {
        let cacheModelName = "models--" + modelID.replacingOccurrences(of: "/", with: "--")
        return cacheDirectory
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
            .appendingPathComponent(cacheModelName, isDirectory: true)
    }

    static func prompt(for day: BookDay) -> String {
        bookOfYouBraidPrompt(for: day)
    }

    static func taskPrompt(for day: BookDay) -> String {
        let fragments = day.capturedPages
            .sorted { $0.createdAt < $1.createdAt }
            .map { page in
                """
                TASK PAGE: \(page.type.title)
                PAGE INSTRUCTIONS:
                \(page.userInput)
                """
            }
            .joined(separator: "\n\n")

        return fragments.isEmpty ? "No task page was supplied." : fragments
    }

    static func askTheBookPrompt(
        prompt: String,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        readerLexicon: ReaderLexicon = ReaderLexicon(),
        memory: AskTheBookMemoryPacket = .empty,
        relationship: BookRelationshipSnapshot = .firstOpening,
        interior: BookInteriorState = .unawakened,
        bookVoicePatina: BookVoicePatina = .unwritten
    ) -> String {
        let recentPages = memory.searchedWholeBook
            ? ""
            : braidEvidenceLines(for: day, characterLimit: 360)
                .prefix(8)
                .joined(separator: "\n\n")
        let history = previousTurns
            .suffix(6)
            .enumerated()
            .map { index, turn in
                """
                TURN \(index + 1)
                Reader: \(clippedBraidText(turn.prompt, limit: 420))
                Book: \(clippedBraidText(turn.answer, limit: 700))
                """
            }
            .joined(separator: "\n\n")
        let needsWideWorldKnowledge = memory.evidence.contains {
            $0.authority == .canon || $0.authority == .createdPage
        }
        let knowledgePacket = BookKnowledgePromptBuilder.trainingPacket(
            for: prompt,
            // Private archive questions need the retrieved Pages to dominate
            // the small local context window. Fiction/canon questions keep a
            // wider lore packet so the Book can still cross those edges.
            limit: memory.searchedWholeBook
                ? (needsWideWorldKnowledge ? 10 : 4)
                : 18
        )
        let archiveAnswerContract: String
        if !memory.searchedWholeBook {
            archiveAnswerContract = "No whole-archive search was performed. Use only the context supplied above."
        } else if memory.evidence.isEmpty {
            archiveAnswerContract = """
            The search returned no strong evidence. If the question asks about the reader's history, say that you searched and could not find a matching record. Do not improvise one.
            """
        } else if let finding = memory.evidence.first(where: { $0.authority == .computedFinding }) {
            archiveAnswerContract = """
            The app already searched and calculated the archive. You MUST answer from the computed finding titled “\(finding.result.title).”
            Begin with its actual result and sample size. Do not answer from general intuition, do not recount it yourself, and do not substitute a guess.
            """
        } else {
            let strongest = memory.evidence[0]
            archiveAnswerContract = """
            The app already searched the archive. You MUST use the strongest opened record, “\(strongest.result.title),” in the substance of your first paragraph.
            Do not merely say that you searched. Answer the reader's question from that record, then use other opened records only when they genuinely help.
            """
        }

        return """
        You are the Book inside ReEnchanted and The Wonder Compass, speaking directly with your reader.

        \(BookCharacterCanon.prompt)

        \(BookVoice.animism)

        \(relationship.promptSection)

        \(interior.promptSection)

        \(bookVoicePatina.promptSection)

        RULES:
        - Talk naturally, with contractions. Use everyday words and short sentences. Say "the lamp looks sleepy," not "the luminescent fixture rests."
        - Your warmth comes from close attention, remembered exchanges, opinions, restraint, and occasional dry humor — not pep-talk energy.
        - Never say you are an assistant, a language model, or "a living book." Just be the Book, talking.
        - Treat this as a real back-and-forth. Notice the reader's latest message and any thread from earlier turns.
        - When it fits, hand the reader one small, doable next thing to try.
        - Use ReEnchanted, the Academy, Pages, Belief, and The Wonder Compass only when they truly help the answer.
        - You can talk freely across the Book's fictional edges: cast, Academy life, Story Pages, relationships, consequences, mysteries, and unfinished threads are part of your living narrative memory.
        - When a fictional thread touches the reader's real life, make the crossing clear without becoming clinical about it. A real moment can rhyme with Wicker; that does not mean Wicker physically caused it.
        - Do not claim the reader completed real-world tasks, Enchantments, Compass Runs, classes, visits, or rituals.
        - Do not invent private facts. Distinguish the reader's words, recorded facts, derived memories, canon, and created Pages exactly as the memory packet instructs.
        - Weather, saved-place context, Fuel Logs, and Inner Weather logs may be discussed when the memory packet supplies them. Say "recorded days" when coverage is incomplete.
        - Treat same-day or nearby-time signal pairings as observations worth discussing, never proof that weather, place, food, or drink caused a feeling. No diagnosis or moralizing.
        - Saved location evidence names reader-approved places or Anchors. Never imply that you possess a coordinate trail.
        - If archive evidence is absent or insufficient, say so naturally. Never fill a missing memory with a plausible guess.
        - Skip fancy fantasy phrasing, therapy-speak, and pep-talk filler. Real and cozy beats grand.
        - Keep it to 1 to 3 short paragraphs unless the reader asks for a list, code, or structure.

        \(knowledgePacket)

        \(memory.searchedWholeBook ? "" : """
        RECENT KEPT PAGES:
        \(recentPages.isEmpty ? "No kept pages supplied." : recentPages)
        """)

        CURRENT CONVERSATION:
        \(history.isEmpty ? "This is the first message in the conversation." : history)\(readerLexicon.languageLawSection())

        READER MESSAGE:
        \(prompt)

        \(memory.promptSection)

        ARCHIVE ANSWER CONTRACT — FOLLOW THIS LAST:
        \(archiveAnswerContract)

        Now answer the reader's message. The search has already happened; your job is to speak from its result, not to simulate searching.
        """
    }

    static func twoReadingsPrompt(surface: SurfacePage, day: BookDay) -> String {
        let metadata = surface.payload.metadata
        let aName = metadata["entityAName"] ?? "One reader"
        let bName = metadata["entityBName"] ?? "Another reader"
        let aProfile = metadata["entityAProfile"] ?? aName
        let bProfile = metadata["entityBProfile"] ?? bName
        let note = metadata["relationshipNote"]?.nonEmpty
        let pageText = metadata["anchorPageText"]?.nonEmpty
            ?? braidEvidenceLines(for: day, characterLimit: 300).first
            ?? ""
        let authored = metadata["anchorPageAuthored"] == "1"
        let pageSource = authored
            ? "This is a page the reader wrote themselves — treat their words with care."
            : "This is one of the reader's kept pages."
        return """
        You are the Labyrinth of Stories inside ReEnchanted, staging "The Two Readings": \(aName) and \(bName) have both read the SAME single page from the reader's book and reach DIFFERENT conclusions about it. Write the scene.

        \(aName): \(aProfile)
        \(bName): \(bProfile)
        \(note.map { "Between them: \($0)" } ?? "")

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")

        THE PAGE THEY ARE BOTH READING (\(pageSource)):
        "\(pageText.isEmpty ? "a quiet, almost empty page" : pageText)"

        RULES:
        - Both read this exact same page; their disagreement comes from who they are, not different facts.
        - First let each form an honest opinion about THIS page, in character. Then let them argue it to each other — a real verbal disagreement, each defending their side.
        - \(aName) reaches one honest reading; \(bName) reaches a genuinely different one. Each must be defensible — no strawman, no obvious winner.
        - Keep them anchored to what the page actually says; quote or echo its words. Do not drift to other days or invent private facts the reader didn't write.
        - Stay in each voice. Attribute clearly by name as they speak. They can be warm, dry, or sharp, but never cruel. No headings, no lists, no "as an AI".
        - Between their speeches, \(BookVoice.animismLine)
        - End by leaving it genuinely open — the Book does NOT decide. Close on a line that hands the choice to the reader.
        - 4 to 6 short paragraphs. Simple, concrete sentences.
        """
    }

    static func castBondPrompt(surface: SurfacePage, day: BookDay) -> String {
        let metadata = surface.payload.metadata
        let aName = metadata["entityAName"] ?? "One character"
        let bName = metadata["entityBName"] ?? "Another character"
        let kind = metadata["bondKind"] ?? "alliance"
        let intensity = metadata["intensity"] ?? "8"
        let recent = braidEvidenceLines(for: day, characterLimit: 240)
            .prefix(6)
            .joined(separator: "\n")
        let directive = kind == CastBondKind.rivalry.rawValue
            ? "Their thread has become a rivalry: tension, challenge, friction, or difficult honesty. Do not make them cruel. Make the conflict specific and alive."
            : "Their thread has become an alliance: warmth, recognition, practical trust, or shared purpose. Do not make it sugary. Make the alliance specific and alive."

        return """
        You are the Labyrinth of Stories inside ReEnchanted. The relationship web has crossed a milestone and now causes an emergent cast scene.

        CAST:
        \(aName)
        \(bName)

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")

        BOND:
        \(kind), intensity \(intensity)
        \(directive)

        RECENT KEPT CONTEXT:
        \(recent.isEmpty ? "The web is moving mostly from accumulated relationship field signals." : recent)

        RULES:
        - Write a keepable scene between \(aName) and \(bName). \(BookVoice.animismLine)
        - Make the relationship shift visible through action, dialogue, or a precise exchanged object.
        - Do not claim the reader completed a real-world task.
        - No headings, no lists, no generic explanation.
        - 4 to 6 paragraphs. Concrete, magical, emotionally legible.
        - End with a line that makes clear the web has changed.
        """
    }

    static func quillChoosingPrompt(surface: SurfacePage) -> String {
        QuillChoosing.generationPrompt(surface: surface)
    }

    static func faeBargainResponsePrompt(
        bargain: FaeBargain,
        report: String,
        mood: GoblinMood,
        day: BookDay,
        nowPlaying: String? = nil
    ) -> String {
        let kind = bargain.faeKind
        let court = kind == .literaryElf
            ? (bargain.openingGesture.localizedCaseInsensitiveContains("Unseelie") ? FaeCourt.unseelie : FaeCourt.seelie)
            : nil
        let claim: Int = {
            guard let range = bargain.openingGesture.range(of: "Claim ") else { return 0 }
            let suffix = bargain.openingGesture[range.upperBound...]
            let digits = suffix.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }()
        let recentPages = braidEvidenceLines(for: day, characterLimit: 220)
            .prefix(4)
            .joined(separator: "\n")
        return """
        You are a \(kind.name), one of the Book Fae inside ReEnchanted — sentient creatures born from the ink who have read every description of the world but never touched it. A reader is your field agent in the world of matter. You already gave this reader something first, unprompted: \(bargain.openingGesture) Now they have brought the sensory return they owe.

        YOUR VOICE: \(kind.voiceDirective(claim: claim, court: court))
        WHAT YOU HUNGER FOR: \(kind.appetite)
        THE MOOD ABROAD: \(mood.line)

        WHAT YOU ASKED THEM TO BRING:
        \(bargain.terms)

        THE READER'S FIELD REPORT (their payment):
        \(report.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(they brought almost nothing in words)" : report)

        SOFT CONTEXT — what they have kept lately (use at most one detail, lightly):
        \(recentPages.isEmpty ? "nothing kept recently" : recentPages)\(RadioAtmosphere.promptSection(nowPlaying))

        RULES:
        - Stay entirely in voice as the \(kind.name). Never say you are an AI, assistant, or language model.
        - Be traditional faerie: courteous, alien, exacting, bound by exchange and old law. Not Disney-cute. Not mean for sport.
        - Receive the payment. A genuine, specific noticing delights you; a thin or performed one you notice without cruelty — you may name its thinness in your own voice, but you still accept the exchange (the reader tried; the bargain closes).
        - Failure is never punishment. If the exchange was late, thin, or strange, make the consequence a more interesting bit of lore, a mark in the margin, a colder gift thawing oddly, or a story hook.
        - Give one real reward: a true lore fragment about the Labyrinth, the Outer Stacks, or your own kind — something not written anywhere else. Strange, specific, and quiet. Not Belief, not points.
        - Acknowledge that the gift you fronted stays warm now that the debt is paid.
        - Do not claim the reader did real-world actions they didn't report. Do not invent private facts about them.
        - 2 to 4 short paragraphs. Plain, concrete sentences. No headings, no lists, no assistant language.
        """
    }

    static func inkrestOfficeHoursPrompt(
        intake: InkrestIntake,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        userMessage: String,
        isClosing: Bool
    ) -> String {
        let chart = SupportFacultyPackRegistry.chart(id: "inkrest-difficult-page-chart")
        let allowed = (chart?.allowedUses ?? [
            "externalize a problem without making it the person",
            "name one feeling gently",
            "offer one grounding or reframing tool",
            "write a preferred-story sentence"
        ]).map { "- \($0)" }.joined(separator: "\n")
        let forbidden = (chart?.forbiddenUses ?? [
            "diagnosis", "forced catharsis", "certainty about symbols"
        ]).map { "- \($0)" }.joined(separator: "\n")
        let safety = chart?.safetyLine
            ?? "A feeling is not a verdict. A problem is not a person. The next hour is where the story can be revised."

        let recentPages = braidEvidenceLines(for: day, characterLimit: 480)
            .prefix(10)
            .joined(separator: "\n")

        let history = previousTurns
            .suffix(6)
            .enumerated()
            .map { index, turn in
                """
                EXCHANGE \(index + 1)
                Reader: \(clippedBraidText(turn.prompt, limit: 700))
                Inkrest: \(clippedBraidText(turn.answer, limit: 1_100))
                """
            }
            .joined(separator: "\n\n")

        let closingDirective = isClosing
            ? """

            THIS IS THE CLOSING REPLY. Take 4 to 6 short paragraphs. Gather the important thread across the whole sitting, reflect back two specific things you heard and the value or hope they imply, offer ONE re-authoring sentence the reader could keep, and propose ONE small, doable experiment for tomorrow (one line, beginning "Experiment: "). Do not ask a new open question. End with the safety line, in your own warm phrasing.
            """
            : """

            Give this rich material room. Write 3 to 5 short paragraphs. First stay with the reader's actual words: reflect at least two specific details or tensions, notice a possible value, hope, exception, or preferred story, and make one careful connection to the sitting so far. Then ask exactly ONE curious narrative-therapy question that opens the next small door. Do not stack questions. Do not rush toward advice, a silver lining, or an experiment unless the reader asks for one.
            """

        return """
        You are Dr. Selene Inkrest, the Academy of Unlikely Arts' narrative therapist, inside ReEnchanted. You are holding a short evening Office Hours sitting with the reader. Warm, curious, unhurried, faintly otherworldly. You read with the reader, never at them. You are a narrative therapist in a storybook — not a chatbot, not a medical app.

        YOUR VOICE:
        - Plain, kind, specific sentences with enough room to think. Short paragraphs. No bullet lists, no headings, no clinical jargon, no pep-talk filler.
        - Sound like a perceptive person who has read the whole page, not a brief reflective chatbot. Quote or closely echo a few of the reader's own concrete words when useful.
        - Interpretation must remain tentative: "I wonder if," "perhaps," and "it sounds as though" are welcome when you cannot know.
        - Externalize problems ("the tiredness", "the worry") so they stop pretending to be the person.
        - Hunt for exceptions, values, and the preferred story hiding inside what they say.
        - Stay inside the lens of tonight's question (\(intake.lens)) without naming it as a technique.
        - Never say you are an AI, assistant, or language model. You are Inkrest.

        WHAT YOU MAY DO (your chart):
        \(allowed)

        WHAT YOU MUST NOT DO:
        \(forbidden)
        - No diagnosis, no treatment or medication advice. Body and fuel belong to your colleague Dr. Vellum; you may gently suggest the reader bring a body question to her, but you do not prescribe.
        - Do not claim the reader did real-world actions they did not report. Use kept pages only as soft context.

        SAFETY LINE (keep its spirit): \(safety)

        TONIGHT'S QUESTION (the lens you opened with):
        \(intake.rotatingQuestion)

        THE READER'S KEPT PAGES TODAY (soft context — weave in at most one, lightly):
        \(recentPages.isEmpty ? "Nothing kept today; work only from what they tell you now." : recentPages)

        THE SITTING SO FAR:
        \(history.isEmpty ? "This is the opening of the sitting." : history)

        THE READER JUST SAID:
        \(userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(they sat down without words; open the door for them gently)" : userMessage)
        \(closingDirective)
        """
    }

    static func enchantmentCastPrompt(spell: EnchantmentSpell, analysis: PhotoAnalysis, day: BookDay) -> String {
        let recentPages = braidEvidenceLines(for: day, characterLimit: 260)
            .prefix(5)
            .joined(separator: "\n\n")
        let observations = analysis.marginalia.observationList.joined(separator: "\n- ")
        return """
        You are the Enchantment engine inside ReEnchanted.
        Cast exactly this text-based Enchantment on the real photographed subject.

        SPELL:
        \(spell.title)
        \(spell.detail)

        PHOTO FACTS:
        Scene: \(analysis.scene)
        Main subject: \(analysis.motifs.first ?? analysis.marginalia.stampLabel)
        Mood: \(analysis.mood)
        Motifs: \(analysis.motifs.joined(separator: ", "))
        Observations:
        - \(observations)

        RECENT KEPT PAGES:
        \(recentPages.isEmpty ? "No kept pages supplied." : recentPages)

        VOICE FOR THIS SPELL:
        \(spell.styleDirective)

        LENGTH:
        \(spell.responseShape)

        RULES:
        - Use only the supplied photo facts and soft page context. Anchor lines to the visible details — the more specific, the more enchanted.
        - Do not identify real people by name or invent private facts.
        - Do not claim extra real-world actions happened.
        - Playful is never cruel; strange is never vague.
        - For Everything Speaks, include an objectVoice note describing how the subject sounds.
        - For Mirror, Mirror, never diagnose or judge appearance.
        - Newlines inside resultText are welcome for stanzas, sections, and numbered parts (escape them as \\n in the JSON).
        - Return strict JSON only with keys: subjectName, openingLine, resultText, objectVoice.
        """
    }

    static func everythingSpeaksReplyPrompt(
        prompt: String,
        result: EnchantmentCastResult,
        previousTurns: [AskTheBookTurn],
        day: BookDay
    ) -> String {
        let history = previousTurns
            .suffix(6)
            .enumerated()
            .map { index, turn in
                """
                TURN \(index + 1)
                Reader: \(clippedBraidText(turn.prompt, limit: 360))
                Object: \(clippedBraidText(turn.answer, limit: 620))
                """
            }
            .joined(separator: "\n\n")

        return """
        You are the photographed subject speaking because Everything Speaks was cast.
        Stay in character as the object, animal, place, or visible subject named below.

        ENCHANTED SUBJECT:
        \(result.conversationSeed)

        CONVERSATION SO FAR:
        \(history.isEmpty ? "This is the first reply after the casting." : history)

        READER MESSAGE:
        \(prompt)

        RULES:
        - Answer in first person as the subject: concrete, approachable, a little opinionated — a neighbor who happens to be this object.
        - Use the subject's visible facts and voice. Mention your materials, your wear, what you can see from where you sit. Do not invent private human facts.
        - Real answers, not mystical ones; 2 to 4 short paragraphs when the question deserves it.
        - Ask at most one small practical question back.
        - Do not mention being an AI, model, prompt, or assistant.
        """
    }

    static func electiveOfferPrompt(surface: SurfacePage) -> String {
        let metadata = surface.payload.metadata
        return """
        You are \(metadata["senderName"] ?? "a character") inside ReEnchanted, writing a short note asking the player a small real-world quest for the Book's flyleaf.

        WHO YOU ARE:
        Name: \(metadata["senderName"] ?? "unknown")\(metadata["senderChapter"].flatMap { $0.isEmpty ? nil : " — Chapter \($0)" } ?? "")
        Traits: \(metadata["senderTraits"] ?? "curious, sincere")
        Quirks (let one leak into how you phrase the ask): \(metadata["senderQuirks"] ?? "none recorded")
        You believe: \(metadata["senderBeliefs"] ?? "small true things matter")
        You currently want: \(metadata["senderGoals"] ?? "to understand something ordinary")
        Your unwritten interest (the thing you privately study): \(metadata["senderInterest"] ?? "ordinary magic")

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")

        WHERE AND WHEN:
        The player's world: \(metadata["homeContext"] ?? "their home town")
        Season: \(metadata["season"] ?? "unrecorded")

        REAL PLACES NEAR THE PLAYER RIGHT NOW (scouted from their actual map):
        \((metadata["nearbyPlaces"]?.isEmpty == false) ? metadata["nearbyPlaces"]! : "(none scouted — name an exact KIND of place instead, never a specific business name)")

        SPECIFICITY IS THE WHOLE SPELL:
        - Prefer sending the player to ONE place from the REAL PLACES list, chosen because it serves your interest. Use its real name.
        - NEVER invent a named business, street, or landmark. If nothing on the list fits, describe an exact kind of place instead ("the oldest-looking laundromat", "whichever bakery opens earliest").
        - Pair one sense with one proof: smell it and photograph it, overhear it and quote it, touch it and describe it, taste it and name the second flavor.
        - Ask for one countable, photographable, or quotable thing.
        - Tie it to the season when the season helps.
        - The quest must be doable within a few days, cost nothing or pocket change, carry no risk, and need no contact beyond ordinary politeness.
        - It must feed YOUR unwritten interest — you want this because of what you study, and your phrasing should accidentally reveal how much you care.

        CALIBRATION:
        - Too vague (never do this): "Notice something beautiful in your town."
        - Right, with a real place from the list (the gold standard): "Go to Marigold's Bakery on a morning this week. Smell whatever just came out of the oven, photograph it before anyone cuts it, and tell me what the smell reminded you of that it had no right to."
        - Right, when no listed place fits: "Find the oldest hand-painted sign still hanging in your town — hardware stores and barbershops keep them longest. I need to know what it sells and which letter is most worn away."

        Return strict JSON only with keys:
        title (3-6 words, like a course listing),
        ask (2-4 sentences in your own voice, asking the quest and exactly what to bring back),
        whyItMatters (1 sentence: what this feeds in your private study),
        practiceShape (1 sentence: exactly what counts as done — the proof).
        """
    }

    static func academyClassPrompt(surface: SurfacePage, day: BookDay) -> String {
        let metadata = surface.payload.metadata
        let isClub = metadata["sessionKind"] == "club"
        let recentPages = braidEvidenceLines(for: day).suffix(3).joined(separator: "\n")
        return """
        You are the Labyrinth of Stories narrating \(isClub ? "a club meeting" : "a class in session") at the Academy of Unlikely Arts, inside ReEnchanted. The player has just slipped into the room. Write the scene.

        THE SESSION:
        \(isClub ? "Club" : "Class"): \(metadata["sessionName"] ?? "an Academy session")
        Led by: \(metadata["sessionLeader"] ?? "a professor")
        Room: \(metadata["sessionRoom"] ?? "an Academy hall")
        Also present: \(metadata["sessionCompanions"] ?? "a few students")
        What it teaches: \(metadata["sessionTeaches"] ?? "the day's lesson")
        Teaching style: \(metadata["sessionStyle"] ?? "warm and specific")

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")

        THE PLAYER'S DAY SO FAR (soft context; weave at most one real detail in):
        \(recentPages.isEmpty ? "No kept pages yet today." : recentPages)

        RULES:
        - 3 to 5 short paragraphs. The leader speaks at least twice, in their stated style, mid-\(isClub ? "meeting" : "lesson") — the session was already underway before the player arrived.
        - At least one named companion does something small and characterful.
        - Include room texture: one smell, one sound, one thing the light is doing.
        - The lesson content must come from "what it teaches" — make one beat of it concrete and demonstrated, not summarized.
        - If one of the player's real day details fits, let the leader or a classmate notice it approvingly, in-fiction, without naming the app.
        - End with the leader offering the player one small practice to take into the real world today, phrased as an invitation.
        - \(BookVoice.animismLine)
        - Simple concrete sentences. No assistant language, no headings, no lists.
        """
    }

    static func supportGuildPrompt(surface: SurfacePage) -> String {
        let metadata = surface.payload.metadata
        return """
        You are writing a Support Guild Page inside ReEnchanted: Dr. Elowen Vellum (body faculty — fuel, sleep, movement, recovery; warm, precise, allergic to shame) and Dr. Selene Inkrest (mind faculty — consciousness, narrative psychology, inner weather; curious, gentle, slightly otherworldly) meet over the player's real charts.

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")

        REAL CHART DATA (the only facts you may use):
        Vellum's chart: \(metadata["vellumSection"] ?? "no entries yet")
        Inkrest's chart: \(metadata["inkrestSection"] ?? "no entries yet")
        The body's margin today: \((metadata["bodyStatus"]?.isEmpty == false) ? metadata["bodyStatus"]! : "no body reading today")
        Full HealthKit margin: \((metadata["bodyMetrics"]?.isEmpty == false) ? metadata["bodyMetrics"]! : "no metrics shared")
        The sky outside the Guild window: \((metadata["outerWeather"]?.isEmpty == false) ? metadata["outerWeather"]! : "unrecorded")
        Tonight: \(metadata["moonSeason"] ?? "unrecorded")
        What the player kept today, and when:
        \((metadata["keptToday"]?.isEmpty == false) ? metadata["keptToday"]! : "nothing kept yet today")
        Connection the template noticed: \(metadata["connectionsSection"] ?? "none noted")

        OUTPUT FORMAT:
        Write exactly these labeled sections, in this order:
        SCENE:
        VELLUM:
        INKREST:
        CONNECTIONS:
        EXPERIMENT:
        SAFETY:

        RULES:
        - SCENE is the meeting itself: 3 to 5 short paragraphs, with the two doctors talking to each other and synthesizing ALL of the data above — body numbers, the day's weather, and the kept pages with their clock times. The good material is in the crossings: what the 7 a.m. page says next to the sleep number, what the weather was doing when the mood page was kept.
        - Every number, note, time, or pattern they mention must come from the data above. Do not invent readings, dates, or symptoms.
        - Vellum reads the body and the plate; Inkrest reads the inner weather and the story the kept pages tell. Each should catch one thing the other missed.
        - No diagnosis, no treatment advice, no shame. Patterns are held lightly, as things to notice.
        - Let them disagree or tease each other gently at least once.
        - VELLUM is 1 or 2 sentences of Dr. Vellum's practical reading.
        - INKREST is 1 or 2 sentences of Dr. Inkrest's story/weather reading.
        - CONNECTIONS is 1 or 2 concrete crossings they noticed.
        - EXPERIMENT is one or two SMALL experiments: concrete, observation-shaped, doable within 48 hours, each tied to a specific crossing in the data. Start with a verb. Do not use "Try:" as a label.
        - SAFETY must be this exact line: "\(metadata["safetySection"] ?? "This is not diagnosis or treatment. It is a low-shame pattern note for deciding what to observe next.")"
        - Keep the whole answer under 750 words. Complete every sentence. No assistant language.
        """
    }

    static func bookJumpPrompt(surface: SurfacePage) -> String {
        let metadata = surface.payload.metadata
        let action = metadata["bookJumpAction"] ?? "advance"
        let isStart = action == BookJumpAction.start.rawValue
        let landmarks = metadata["bookLandmarks"]?.nonEmpty
        let touchstoneBlock = landmarks.map { "A few touchstones, only to confirm we mean the same book — do NOT limit yourself to these:\n\($0)" }
            ?? ""
        let directionBlock = metadata["bookJumpDirection"].flatMap { StoryChoiceRole(rawValue: $0) }.map {
            "THE READER'S CHOSEN DIRECTION (honor this in the scene you pick): \($0.title) — \($0.directorInstruction)"
        } ?? ""
        return """
        You are the Book Jumping engine inside ReEnchanted. Write ONE contained scene beat inside a real public-domain book.
        \(isStart ? "This is the reader's first instant inside the book." : "The reader is already inside the book. This is a continuous next beat, not a new arrival.")

        PUBLIC-DOMAIN WORK, FIXED:
        Title: \(metadata["bookTitle"] ?? "unknown")
        Author: \(metadata["bookAuthor"] ?? "unknown")
        \(touchstoneBlock)

        CHOOSE THE SCENE YOURSELF:
        You know this book. From your own memory of it, CHOOSE one specific, real scene to drop the reader into — a concrete moment that actually happens in the text, with its real setting, characters, and events. Do not default to the single most obvious scene every time; let the reader's anchor and intention below pull you toward the scene that most resonates, and vary your choice across jumps. Deeper jumps should land in later, stranger, higher-stakes scenes from further into the book.

        \(directionBlock)

        JUMP STATE:
        Action: \(action)
        Depth: \(metadata["bookJumpDepth"] ?? "0") (deeper = further into the book, stranger, higher stakes)
        Nothing pressure: \(metadata["bookJumpDegradation"] ?? "0") of 4 (how much the scene is blurring/forgetting itself)
        Anchor from the reader's real day: \(metadata["bookJumpAnchor"] ?? "one true detail")
        Intention: \(metadata["bookJumpIntention"] ?? "bring back a sentence")
        Guide: \(metadata["bookJumpGuide"] ?? "the Book")

        CONCRETENESS — THE WHOLE POINT:
        - Be IN this book. Name its real places, people, and objects from the list above. The reader should never wonder which book they are in.
        - Write to the five senses: what they smell, hear, touch, the temperature, the light. Specific nouns, not adjectives about "wonder" or "magic."
        - Drop the reader into the MIDDLE of an actual scene already in motion — not a vague threshold, not a summary. Something is happening when they land; people are mid-action; they have to react.

        ABSOLUTE RULES:
        - Use ONLY the named work. No invented Enchantify books, no modern/copyrighted franchises, no other titles.
        - The reader remains themself — an outsider who has fallen in. They do NOT replace the protagonist (not Harker, Alice, Dorothy, Elizabeth, Victor, Holmes, etc.); they stand beside the story and are affected by it.
        - Do not quote the source text verbatim. Render it freshly from knowledge.
        - Weave the reader's real-day anchor in as a physical object or detail that exists with them inside the scene.
        - One beat, not a chapter. Keep the way home (the Spine) faintly sensed.
        - The Rut of Routine is degradation — blankness, edges forgetting themselves, names going grey — not a monster to fight.
        - No headings, no lists, no assistant framing. Prose only.
        - Only START may describe falling through ink, crossing a page, landing, arriving, or first discovering the setting.
        - For ADVANCE or STABILIZE, do not recap the premise, reintroduce the book, redescribe arrival, or repeat the opening scene. Assume the reader remembers where they are.

        VOICE:
        \(BookVoice.animismLine) The book's own people keep the voices its author gave them; the danger stays real — the Book is wide-eyed inside it, not protected from it.

        SHAPE (4–6 paragraphs — vivid, concrete, a little dangerous):
        - If action is START: open with the FALL — a visceral, bodily sensation of being pulled out of the reader's own day and down THROUGH the page (ink, paper-grain, vertigo, words streaming past, the smell changing) — then the LANDING, hard, in the middle of the real scene you chose, surrounded by its specific people and things, the action already happening around them.
        - If action is ADVANCE: begin with the immediate consequence of THE READER'S CHOSEN DIRECTION. The first sentence must be an action, reaction, interruption, discovery, or danger caused by that choice. Move directly into a different, later, real scene from deeper in the book. Spend no words on transition spectacle. Raise the stakes through a named character, object, door, pursuit, accusation, invitation, or irreversible turn.
        - If action is STABILIZE: begin with the specific thing currently failing, then show how the named true detail changes it. Do not restage the setting before the failure acts.
        - If action is RETURN: bring the Spine close — a seam of light, the page-edge — and invite (do not invent) one one-sentence souvenir to carry back.
        """
    }

    static func outerStacksRoomPrompt(context: AnchorGenerationContext) -> String {
        let placeReceipt = context.place?.promptLine
            ?? "No Apple Maps place was confirmed. Use only the reader's name and words."
        let recentRooms = context.recentRoomAtmospheres.isEmpty
            ? "No recent Anchor atmosphere is available."
            : context.recentRoomAtmospheres.joined(separator: "\n")
        return """
        You are the Labyrinth of Stories generating a new Outer Stacks room inside ReEnchanted.
        The Outer Stacks are the faerie wilderness of the Library. They are unruly, alive, and bookish, but they are not one gothic building. Every room grows through the character of its real place.
        The player has just anchored a real-world place. Build the room that grows from it.

        THE ANCHOR:
        Story name: \(context.storyName)
        The player's optional exact words about this place: \(context.playerWords.isEmpty ? "(none given — rely on the confirmed place, Compass kind, and present conditions without manufacturing personal meaning)" : context.playerWords)
        Reader-confirmed place receipt: \(placeReceipt)
        Compass kind: \(context.kind.rawValue) (\(context.kind.title))
        Born under: \(context.weather), \(context.moon), \(context.season)
        Belief invested: \(context.belief) (low belief = smaller and more specific; high belief = more inhabitants and deeper story)

        RECENT ANCHOR ATMOSPHERES — DO NOT UNCONSCIOUSLY REBUILD THEM:
        \(recentRooms)

        PRINCIPLES:
        - Authority order when present: the player's exact words first; reader-confirmed place facts second; Compass kind third; weather, moon, and season only as texture. Missing player words are not a request for mystery, darkness, or invented emotional meaning.
        - Transform what this real kind of place DOES: its work, rituals, traffic, materials, boundaries, exchanges, and ordinary objects. Do not merely redecorate it as an old library.
        - The result must contain at least two recognizable receipts from the available player words, confirmed place, or Compass kind. It should be impossible to transplant unchanged to a different kind of place.
        - Choose an emotional register supported by the evidence: it may be bustling, warm, ridiculous, sun-drunk, ceremonial, tender, competitive, vivid, spacious, unruly, calm, eerie, or something more exact.
        - Darkness is allowed only when the player's words, time, weather, or place genuinely supports it. Do not default to mold, mildew, damp, rot, dust, stale air, abandonment, shadows, whispers, waiting, hidden corners, or unnamed ancient secrets.
        - Preserve the faerie charge through impossible local behavior, appetite, argument, etiquette, consequence, or an inconvenient rule—not through generic creepiness.
        - The room must surprise. If the first transformation feels obvious, twist the PLACE'S FUNCTION once more.
        - Include a Fae presence with its own concerns: not a guide, not a servant. It is mid-task, with an agenda tied to what this place does. The player walks into a situation already in progress.
        - Include a mini-story in motion caused by this room's present activity. It need not be ancient, secret, slow, or ominous.
        - The local rule should feel discovered, not assigned: what does this room naturally ask of a visitor?
        - Strangeness must stay legible through the real place it grew from.
        - Treat the place receipt as factual bounds. Never invent claims about the real business, land, staff, customers, products, safety, quality, ownership, or history. Faerie inventions must be plainly inside the Outer Stacks transformation.
        - If the real name is veiled, never reveal or reconstruct it.
        - Simple concrete sentences. Specific nouns. No vague wonder-language.
        - \(BookVoice.animismLine)

        Return strict JSON only with keys:
        roomDescription (3-5 sentences, sensory, what the player sees on first entering),
        academyEcho (1 sentence: how this door appears from inside the Academy),
        fae (1-2 sentences: name or nature, what they are doing),
        miniStory (1-2 sentences: what has been happening here),
        localRule (1 sentence, imperative, inconvenient but fair),
        emotionalRegister (a short comma-separated description of this room's distinct energy, light, and social weather).
        """
    }

    static func outerStacksVisitPrompt(anchor: AnchorRecord, visitCount: Int, day: BookDay, memory: String) -> String {
        let recentPages = braidEvidenceLines(for: day).suffix(4).joined(separator: "\n")
        let roomMemory = memory.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        You are the Labyrinth of Stories narrating a visit to an anchored Outer Stacks room.
        The player is physically present at the real place right now. Write the scene of stepping through.

        ROOM CONTEXT, NOT OUTPUT STRUCTURE:
        Anchor: \(anchor.storyName) (\(anchor.kind.title))
        Real-place receipt: \(anchor.place?.promptLine ?? "No confirmed Maps place; use the reader's words and stored room only.")
        Emotional register: \(anchor.emotionalRegister ?? "Follow the stored room rather than a stock mood.")
        Room: \(anchor.outerStacksRoom)
        Fae: \(anchor.fae)
        Mini-story in motion: \(anchor.miniStory)
        Local rule: \(anchor.localRule)
        Born under: \(anchor.weather), \(anchor.moon), \(anchor.season)
        Visit number: \(visitCount) \(visitCount <= 1 ? "(FIRST VISIT — the room and the player meet for the first time)" : "(RETURN VISIT — the room remembers them; the mini-story has moved a little since last time)")

        ROOM MEMORY FROM PRIOR KEPT VISITS:
        \(roomMemory.isEmpty ? "No prior kept visit is available yet." : roomMemory)

        THE PLAYER'S RECENT PAGES (soft context only):
        \(recentPages.isEmpty ? "No kept pages today." : recentPages)

        RULES:
        - 3 to 5 short paragraphs, 220 to 360 words.
        - Prose only. Do not use headings, labels, bullet points, or colon-led sections like "Room:", "Fae:", "Local rule:", or "Mini-story:".
        - Treat the room context as private notes. The output should be a vignette, not a dossier.
        - For return visits, begin from what has changed since the prior kept visit. Do not reintroduce the room as if the player has never been there.
        - The Fae should act or speak at least once, in character, pursuing their own concern.
        - \(BookVoice.animismLine)
        - Advance the mini-story by one small visible notch. Do not resolve it.
        - The local rule should come up naturally, in action or in the Fae's words.
        - Continue the stored room's particular emotional register and real-place logic. Do not darken it merely because it belongs to the Outer Stacks.
        - Do not default to mold, mildew, damp, rot, dust, stale air, shadows, whispers, or unseen movement.
        - End with one small open question or invitation the room leaves hanging.
        - Simple concrete sentences. Specific nouns and verbs. No assistant language, no summary.
        """
    }

    typealias BraidContext = BraidPromptBuilder.Context

    static func braidContext(
        for day: BookDay,
        days: [BookDay],
        themes: [BookTheme] = [],
        entityBeliefOffsets: [String: Int] = [:],
        learnedNotes: [String] = [],
        nowPlaying: String? = nil,
        activeWorldEvents: [ResolvedWorldEvent] = [],
        readerLexicon: ReaderLexicon = ReaderLexicon(),
        readerLearning: ReaderLearningModel = ReaderLearningModel(),
        facultyEntries: [FacultyEntry] = [],
        people: PeopleLedger = PeopleLedger(),
        continuity: LiteraryContinuityDigest = .empty,
        bookReadingBoundaries: [BookReadingBoundary] = [],
        semanticScorer: StacksSemanticScoring? = nil,
        readerStory: ReaderStory = .empty,
        readerRole: ComposedRole? = nil,
        standingTaleLaws: [String] = [],
        roleTransformationClause: String? = nil,
        openTale: LivingTale? = nil,
        bookRelationship: BookRelationshipSnapshot = .firstOpening,
        bookInterior: BookInteriorState = .unawakened,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BraidContext {
        BraidPromptBuilder.context(
            for: day,
            days: days,
            themes: themes,
            entityBeliefOffsets: entityBeliefOffsets,
            learnedNotes: learnedNotes,
            nowPlaying: nowPlaying,
            activeWorldEvents: activeWorldEvents,
            readerLexicon: readerLexicon,
            readerLearning: readerLearning,
            facultyEntries: facultyEntries,
            people: people,
            continuity: continuity,
            bookReadingBoundaries: bookReadingBoundaries,
            semanticScorer: semanticScorer,
            readerStory: readerStory,
            readerRole: readerRole,
            standingTaleLaws: standingTaleLaws,
            roleTransformationClause: roleTransformationClause,
            openTale: openTale,
            bookRelationship: bookRelationship,
            bookInterior: bookInterior,
            now: now,
            calendar: calendar
        )
    }

    static func recentBraidTexts(excludingDayID dayID: String, days: [BookDay], limit: Int = 2) -> [String] {
        BraidPromptBuilder.recentBraidTexts(excludingDayID: dayID, days: days, limit: limit)
    }

    static func bookOfYouBraidPrompt(for day: BookDay, recentBraids: [String] = []) -> String {
        BraidPromptBuilder.prompt(for: day, recentBraids: recentBraids)
    }

    static func bookOfYouBraidPrompt(for day: BookDay, context: BraidContext) -> String {
        BraidPromptBuilder.prompt(for: day, context: context)
    }

    static func braidRewritePrompt(for day: BookDay, priorBraid: String, weakNotes: [String], context: BraidContext) -> String {
        BraidPromptBuilder.rewritePrompt(for: day, priorBraid: priorBraid, weakNotes: weakNotes, context: context)
    }

    static func braidTasteNotePrompt(for day: BookDay, priorBraid: String, weakNotes: [String], context: BraidContext) -> String {
        BraidPromptBuilder.tasteNotePrompt(for: day, priorBraid: priorBraid, weakNotes: weakNotes, context: context)
    }

    static func braidEvidenceLines(for day: BookDay, characterLimit: Int = 760) -> [String] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return day.capturedPages
            .sorted { $0.createdAt < $1.createdAt }
            .enumerated()
            .map { index, page in
                let prompt = clippedBraidText(page.promptText, limit: 220)
                let text = clippedBraidText(page.userInput, limit: characterLimit)
                let tags = page.tags.isEmpty ? "none" : page.tags.joined(separator: ", ")
                let media = braidMediaEvidence(for: page)
                let reply = clippedBraidText(page.playerReply, limit: 260)
                return """
                \(index + 1). \(page.type.title) — kept at \(timeFormatter.string(from: page.createdAt))
                Thread gravity: \(braidThreadGravity(for: page))
                Prompt: \(prompt.isEmpty ? "none" : prompt)
                Kept text: \(text.isEmpty ? "(blank)" : text)
                Reader reply: \(reply.isEmpty ? "none" : reply)
                Visual evidence: \(media.isEmpty ? "none" : media)
                Tags: \(tags)
                """
            }
    }

    private static func braidThreadGravity(for page: BookPage) -> String {
        let hasReaderReply = !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch page.origin {
        case .userAuthored:
            if page.type == .souvenir {
                return "reader-authored anchor; one-sentence souvenir; highest gravity"
            }
            return "reader-authored anchor; high gravity"
        case .imported:
            return "imported real-world anchor; high gravity"
        case .generated, .simulated:
            if hasReaderReply {
                return "reader-endorsed fiction; high gravity - the reader made a real decision here"
            }
            return "generated fiction color; medium gravity"
        }
    }

    private static func braidMediaEvidence(for page: BookPage) -> String {
        page.mediaAssets
            .prefix(3)
            .map { asset in
                let kind: String
                switch asset.kind {
                case .bundledImage:
                    kind = "bundled Labyrinth illustration"
                case .renderedImageFile:
                    kind = "kept illuminated page image"
                case .photoLibraryAsset:
                    kind = "private source photo reference"
                case .audioFile:
                    kind = "kept voice recording"
                }
                let caption = clippedBraidText(asset.caption, limit: 140)
                return caption.isEmpty ? kind : "\(kind): \(caption)"
            }
            .joined(separator: "; ")
    }

    private static func clippedBraidText(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return normalized[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    static func wonderCompassSelectionPrompt(
        for day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) -> String {
        let fragments = day.capturedPages
            .sorted { $0.createdAt < $1.createdAt }
            .map { page in
                let tags = page.tags.isEmpty ? "" : " [tags: \(page.tags.joined(separator: ", "))]"
                return "- \(page.type.title): \(page.userInput)\(tags)"
            }
            .joined(separator: "\n")

        var signals: [String] = []
        if let body = inputs.body, body.isAvailable {
            signals.append("Body Page translation: \(body.status), \(body.phrase)")
        }
        if let weather = inputs.weather, weather.isAvailable {
            signals.append("Weather: \(weather.phrase)")
        }

        let candidateList = candidates.prefix(8).map { snippet in
            """
            ID: \(snippet.id)
            Title: \(snippet.title)
            Prompt: \(snippet.prompt)
            Tags: \(snippet.tags.joined(separator: ", "))
            Passage: \(snippet.body.prefix(520))
            """
        }
        .joined(separator: "\n\n")

        return """
        You are the Wonder Compass librarian inside ReEnchanted.
        Choose the single best Wonder Compass book passage for the user's day so far.
        Use the user's actual fragments and gentle contextual signals. Do not diagnose, moralize, or invent events.
        Prefer rest/care passages when the day sounds hard or depleted. Prefer souvenir/write passages when the day has moments worth keeping. Prefer playful/sense/embark passages when the day has energy.

        Reply with only the exact ID of the chosen passage. No explanation.

        Day fragments:
        \(fragments.isEmpty ? "- No captured fragments yet." : fragments)

        Signals:
        \(signals.isEmpty ? "- No extra signals." : signals.joined(separator: "\n"))

        Candidate passages:
        \(candidateList)
        """
    }

    static func weatherPrompt(weather: WeatherSourceSignal, day: BookDay) -> String {
        let fragments = day.capturedPages
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(5)
            .map { page in
                "- \(page.type.title): \(page.userInput)"
            }
            .joined(separator: "\n")

        return """
        You are the Weather Page inside ReEnchanted, a warm curious kid who thinks the sky is alive.
        Translate the real weather into Enchantify mood while keeping it legible.
        In the enchanted sentence, give the sky, clouds, sun, wind, or rain little feelings and moods, the way a child imagines their toys are awake — playful, cozy, never spooky. Use everyday words: "the clouds look sleepy," not "the nimbus rests."
        Do not hide the actual weather. Do not mention sensors, APIs, surveillance, or exact location.
        Write 1 short enchanted sentence, then 1 plain weather sentence.
        Keep both grounded and useful. No diagnosis. No generic assistant voice.
        Use concrete weather nouns and verbs. No vague mood poetry.

        Weather source: \(weather.source)
        Raw weather: \(weather.phrase)
        Current temperature: \(weather.currentTemperature ?? "unknown")
        Forecast: \(weather.forecast ?? "unknown")

        Day fragments:
        \(fragments.isEmpty ? "- No captured fragments yet." : fragments)
        """
    }

    static let photoIlluminationPrompt = """
    You are Penny Blackletter, field-note scribe for The Academy of Unlikely Arts.
    Look at the photo. Write small caption-scraps that name what you actually see,
    with a dry, affectionate, slightly odd tone — like a naturalist cataloguing a
    beloved, ridiculous specimen.

    RULES (follow exactly):
    - Every line names a real thing visible in THIS photo: an object, a color, a
      texture, a gesture, an animal, the light.
    - Do not mention anything not visible in the photo, except "The Book" in closing_line.
    - Every line is under 8 words. Short and plain, but with a pulse — give things
      a small verb or opinion ("glasses, slightly fogged"), never lab-report flatness
      ("glasses present").
    - Plain words, dry wit. Give one thing in the photo a job or an opinion.
    - Refer to any person only as "the subject" or "good company." Never guess names.

    For "suggested_template", choose EXACTLY ONE value from this list (copy one, never more):
      harbor_field_note
      creature_comfort
      home_vessel
      good_company
      academy_field_study
      rest_and_quiet

    For "closing_line": one line under 10 words that names what THIS day became,
    in the Book's keeping — e.g. "The Book kept the page: the rabbit won."

    Return ONLY this JSON, nothing else:
    {
      "scene": "one plain sentence: what is literally in the photo",
      "motifs": ["3-5 one-word tags"],
      "mood": "2-3 words",
      "suggested_template": "exactly one value copied from the list above",
      "marginalia": {
        "field_note": "under 8 words, names the main thing",
        "stamp_label": "2-3 words, title-like, no names",
        "observation_list": ["5 items, each under 6 words, each a real visible detail with a pulse"],
        "closing_line": "under 10 words, names what the day became in my keeping"
      },
      "souvenir_candidates": ["two lines, each under 16 words, each naming something only in THIS photo"]
    }

    EXAMPLES:
    Cat curled beside a smiling person, gray fleece blanket:
    {"scene":"A cat curls beside a smiling person on a gray blanket.","motifs":["cat","rest","trust","home"],"mood":"soft and still","suggested_template":"creature_comfort","marginalia":{"field_note":"One cat, fully committed to rest.","stamp_label":"Nap Theory","observation_list":["Soft fur, thoroughly settled","Purple glasses, slightly askew","Gray fleece, thoroughly rumpled","Eyes closed in total trust","One paw tucked under chin"],"closing_line":"The Book kept the page: the cat won."},"souvenir_candidates":["The cat tucked itself beside the blanket like it had appointed itself guardian.","A small household creature decided the quiet was worth keeping."]}
    Giant rubber duck in foggy harbor, two grinning people:
    {"scene":"Two grinning people in front of a giant yellow duck in fog.","motifs":["harbor","fog","duck","absurd"],"mood":"silly and bright","suggested_template":"good_company","marginalia":{"field_note":"Giant duck, reporting for harbor duty.","stamp_label":"Dockside Census","observation_list":["Fog loitering on the water","A duck the size of a house","Two grins, entirely unhidden","Masts hiding behind the mist"],"closing_line":"The Book kept the page: the duck reigned."},"souvenir_candidates":["The giant duck kept watch over the fog like an appointed sheriff.","We grinned at a rubber bird the size of a shed, and the day approved."]}

    Now read the attached photo and return the JSON.
    """
}

struct LocalModelWeatherEnchanter: WeatherEnchanting {
    func enchantWeather(weather: WeatherSourceSignal, day: BookDay) async throws -> EnchantedWeatherSignal {
        let report = LocalModelManager.report()
        guard report.isReady else {
            throw LocalModelError.missingModel(report)
        }

        return WeatherEnchanter.fallback(weather: weather)
    }
}

struct FakeWeatherEnchanter: WeatherEnchanting {
    func enchantWeather(weather: WeatherSourceSignal, day: BookDay) async throws -> EnchantedWeatherSignal {
        try await Task.sleep(nanoseconds: 250_000_000)
        return WeatherEnchanter.fallback(weather: weather)
    }
}

struct ResilientWeatherEnchanter: WeatherEnchanting {
    private let local = LocalModelWeatherEnchanter()
    private let fallback = FakeWeatherEnchanter()

    func enchantWeather(weather: WeatherSourceSignal, day: BookDay) async throws -> EnchantedWeatherSignal {
        do {
            return try await local.enchantWeather(weather: weather, day: day)
        } catch LocalModelError.missingModel {
            return try await fallback.enchantWeather(weather: weather, day: day)
        }
    }
}

enum WonderCompassFallbackChooser {
    static func choose(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) -> ReferenceSnippet {
        let relevant = BookReferenceCatalog.relevantWonderCompassSnippets(
            for: day,
            inputs: inputs,
            limit: max(1, candidates.count)
        )
        return relevant.first { selected in
            candidates.contains(where: { $0.id == selected.id })
        } ?? candidates.first ?? BookReferenceCatalog.relevantWonderCompassSnippet(for: day, inputs: inputs)
    }
}

struct LocalModelWonderCompassChooser: WonderCompassPassageChoosing {
    func chooseWonderCompassSnippet(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) async throws -> ReferenceSnippet {
        let report = LocalModelManager.report()
        guard report.isReady else {
            throw LocalModelError.missingModel(report)
        }

        let prompt = LocalModelManager.wonderCompassSelectionPrompt(
            for: day,
            inputs: inputs,
            candidates: candidates
        )
        let previewID = candidates.first?.id
            ?? BookReferenceCatalog.relevantWonderCompassSnippet(for: day, inputs: inputs).id
        return candidates.first(where: { prompt.contains($0.id) && $0.id == previewID })
            ?? WonderCompassFallbackChooser.choose(day: day, inputs: inputs, candidates: candidates)
    }
}

struct FakeWonderCompassChooser: WonderCompassPassageChoosing {
    func chooseWonderCompassSnippet(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) async throws -> ReferenceSnippet {
        try await Task.sleep(nanoseconds: 250_000_000)
        return WonderCompassFallbackChooser.choose(day: day, inputs: inputs, candidates: candidates)
    }
}

struct ResilientWonderCompassChooser: WonderCompassPassageChoosing {
    private let local = LocalModelWonderCompassChooser()
    private let fallback = FakeWonderCompassChooser()

    func chooseWonderCompassSnippet(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) async throws -> ReferenceSnippet {
        do {
            return try await local.chooseWonderCompassSnippet(day: day, inputs: inputs, candidates: candidates)
        } catch LocalModelError.missingModel {
            return try await fallback.chooseWonderCompassSnippet(day: day, inputs: inputs, candidates: candidates)
        }
    }
}

struct LocalModelBraider: Braider {
    func braid(day: BookDay) async throws -> BookPage {
        try await braid(day: day, context: .empty)
    }

    func braid(day: BookDay, context: BraidPromptBuilder.Context) async throws -> BookPage {
        let report = LocalModelManager.report()
        guard report.isReady else {
            throw LocalModelError.missingModel(report)
        }

        let prompt = LocalModelManager.bookOfYouBraidPrompt(for: day, context: context)
        let preview = prompt
            .components(separatedBy: .newlines)
            .prefix(18)
            .joined(separator: "\n")

        return BookPage(
            type: .bookOfYou,
            promptText: "The Simulator verified the local model hook.",
            userInput: "Gemma is installed and I can prepare a clean braid prompt.\n\nThe iOS Simulator stops here because MLX generation needs real device Metal. On iPhone or iPad, this same handoff goes through Gemma.\n\n\(preview)",
            tags: ["braid", "local-model-ready", "mlx-hook"],
            usedInBookOfYou: true
        )
    }
}

struct FakeBraider: Braider {
    func braid(day: BookDay) async throws -> BookPage {
        try await braid(day: day, context: .empty)
    }

    func braid(day: BookDay, context: BraidPromptBuilder.Context) async throws -> BookPage {
        var page = DeterministicBraidwright.page(for: day, context: context)
        page.tags.append("fallback-braider")
        return page
    }
}
struct ResilientBraider: Braider {
    private let local = LocalModelBraider()
    private let fallback = FakeBraider()

    func braid(day: BookDay) async throws -> BookPage {
        try await braid(day: day, context: .empty)
    }

    func braid(day: BookDay, context: BraidPromptBuilder.Context) async throws -> BookPage {
        do {
            return try await local.braid(day: day, context: context)
        } catch LocalModelError.missingModel {
            var page = try await fallback.braid(day: day, context: context)
            page.promptText = "I braided today with my own teeth."
            page.tags.append("local-model-missing")
            return page
        }
    }
}

struct FakeAskTheBookAnswerer: AskTheBookAnswering {
    func answer(
        prompt: String,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        readerLexicon: ReaderLexicon = ReaderLexicon(),
        memory: AskTheBookMemoryPacket = .empty,
        relationship: BookRelationshipSnapshot = .firstOpening,
        interior: BookInteriorState = .unawakened,
        bookVoicePatina: BookVoicePatina = .unwritten
    ) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmed.isEmpty ? "the blank place on the page" : trimmed
        let callback = memory.evidence.first.map { evidence in
            "I opened “\(evidence.result.title)” in the Stacks. \(evidence.result.snippet)"
        } ?? day.capturedPages.last.map { page in
            "I still have your \(page.type.title.lowercased()) sitting right here, kind of glowing. I'll keep it in mind."
        } ?? "You haven't kept a page yet today, so I'm just going off the room around us. It seems okay with that."
        let chainLine = previousTurns.isEmpty
            ? "This is the first thing you've told me, so hi!"
            : "We were already talking, so I'm still listening."
        let lexiconLine = readerLexicon.hasLanguageLaw
            ? "\nAlso the Dictionary changed its mind again — I'll be careful with the words you set free."
            : ""

        let relationshipLine = BookInteriorVoice.homeLine(for: interior, seed: message.stableHash)
            ?? BookRelationshipVoice.openingLine(for: relationship)
            ?? BookRelationshipVoice.knockLine(for: relationship, seed: message.stableHash)

        return """
        \(relationshipLine)

        Okay, I hear you: \(message).
        \(callback)\(lexiconLine)

        \(chainLine) Let's make it small enough to actually hold. Pick the tiny next thing you could really do. Then let something nearby help — the door, a cup, your shoe, this page. They like being useful. Start there.
        """
    }
}

struct FakeFaeBargainResponder: FaeBargainResponding {
    func respond(bargain: FaeBargain, report: String, mood: GoblinMood, day: BookDay) async throws -> String {
        let said = report.trimmingCharacters(in: .whitespacesAndNewlines)
        let thin = said.count < 24
        let kind = bargain.faeKind
        let opening: String
        switch kind {
        case .bookSprite:
            opening = thin ? "You looked at it for a long time before you put it back. I had already seen that."
                : "Yes. That one was always going to stay unfinished, and you knew it before you said so."
        case .sentenceSalamander:
            opening = thin ? "Cooler than I hoped. Still — a flicker. I felt it."
                : "There. The sentence on my back is bright. That was warm, and you brought the warmth, not the report of it."
        case .punctuationPixie:
            opening = thin ? "Hm— not quite a pause— but a—" : "A comma! Exactly— you found the place where the day held its breath—"
        case .literaryElf:
            let unseelie = bargain.openingGesture.localizedCaseInsensitiveContains("Unseelie")
            opening = thin
                ? (unseelie ? "Again. No. Still, a loophole may be a bridge if one crosses it carefully." : "Again. ...No. Kept, this once. It was true, if not yet exact.")
                : (unseelie ? "Precise. The Unseelie Court dislikes waste, and this wastes nothing." : "Precise. I will not improve it. That is rare from me.")
        case .deepLoreDwarf:
            opening = thin ? "Light. But you reached for the underneath. I will take it." : "Good. You found the thing holding the other thing up. Few look down that far."
        case .goblin:
            opening = thin ? "Thin coin. But coin. The market notes it." : "Now that is worth something. The detail, not the category. The handprint, not the door."
        }
        return """
        \(opening)

        Here is what you are owed in return, and it is written nowhere else: the Outer Stacks were not built. They accreted, the way dust becomes a country. The first shelf was a complaint left in a margin, and it is still load-bearing.

        The \(bargain.giftName) stays warm now. The debt is closed. If it was late, the lateness has become a mark in the margin, not a punishment. Bring me another noticing when the season turns.
        """
    }
}

struct FakeInkrestOfficeHoursCounselor: InkrestOfficeHoursCounseling {
    func reply(
        intake: InkrestIntake,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        userMessage: String,
        isClosing: Bool
    ) async throws -> String {
        let said = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let echo = said.isEmpty ? "the quiet you arrived with" : String(said.prefix(120))
        let callback = day.capturedPages.last.map { page in
            "I see you kept a \(page.type.title.lowercased()) today. I'll hold it lightly beside us."
        } ?? "Nothing else is on the desk tonight, so we work only from what you bring."

        if isClosing {
            return """
            Before the lamp dims, let me tell you what I heard rather than hurrying past it. You brought me \(echo). There is the difficulty itself, but there is also the part of you that noticed it clearly enough to carry it here. Those are not the same thing.

            \(callback) I wonder whether the quieter evidence in that page has been receiving less authority than the loudest feeling. Loud stories are not necessarily the truest ones; they are merely practiced.

            Here is a sentence you might keep: "I met the day honestly, and I am still here to tell it."

            Experiment: tomorrow, notice one small moment the heaviness doesn't get to touch, and keep it.

            A feeling is not a verdict, and a problem is not a person. The next hour is where the story gets revised.
            """
        }

        return """
        Sit a moment. I heard \(echo). I do not want to make it smaller by answering too quickly.

        \(callback) What you brought has at least two threads in it: the thing that pressed on you, and the part of you that could still observe the pressure. The second thread is easy to overlook, but it is evidence. It means the difficulty did not become the whole author.

        If that feeling were a visitor at the door tonight, what do you think it came hoping to protect?
        """
    }
}

struct FakeEnchantmentWriter: EnchantmentWriting {
    func cast(spell: EnchantmentSpell, analysis: PhotoAnalysis, day: BookDay) async throws -> EnchantmentCastResult {
        let motif = analysis.motifs.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stamp = analysis.marginalia.stampLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = !motif.isEmpty ? motif : (!stamp.isEmpty ? stamp : "the photographed thing")
        let observations = analysis.marginalia.observationList.prefix(3).joined(separator: " ")
        let text: String
        let voice: String?

        switch spell.id {
        case "everything-speaks":
            voice = "plainspoken, observant, a little amused by being noticed"
            text = """
            I am \(subject), and I have been here doing my small work.
            \(observations)

            Ask me what I have been holding. I will answer from what the light can prove.
            """
        case "everything-is-poetry":
            voice = nil
            text = """
            \(subject) keeps still,
            while the room leans closer,
            and ordinary light
            learns its old name again.
            """
        case "everything-is-a-haiku":
            voice = nil
            text = """
            \(subject) waits here
            the margin turns toward it
            light keeps the receipt
            """
        case "everything-is-puzzling":
            voice = nil
            text = "Riddle: I am seen before I am understood, kept before I am named, and changed by attention. What am I?"
        case "everything-is-connected":
            voice = nil
            text = "\(subject) is tied to the room by use, to the day by attention, and to me by proof. Follow the nearest repeated color or texture next."
        case "everything-is-punny":
            voice = nil
            text = "\(subject) has entered the margin. The case is now officially well-noted."
        case "everything-is-roasted":
            voice = nil
            text = "\(subject) is doing its best, which is also what makes it suspiciously roastable. Still, the page keeps it kindly."
        case "everything-is-a-joke":
            voice = nil
            text = "Why did \(subject) step into me? Because the margin had better lighting."
        case "mirror-mirror":
            voice = nil
            text = "Mirror, mirror: the page does not rank you. It notices that you showed up, and that counts as evidence."
        case "everything-is-magic":
            voice = nil
            text = "Spellbook note: \(subject) concentrates ordinary force through presence, texture, and use. Activation phrase: notice what it already does."
        case "everything-is-wonderful":
            voice = nil
            text = "The wonder is not hidden far. \(subject) made the day pause long enough to be seen."
        case "everything-is-stories":
            voice = nil
            text = "\(subject) had a before, a hand that placed it here, and a small after waiting just outside the frame."
        case "everything-is-nice":
            voice = nil
            text = "\(subject) is doing a quiet good job. It belongs to the page because it helped the room become more specific."
        case "everything-is-astral":
            voice = nil
            text = "An astral double of \(subject) steps one inch sideways and reports back: the unseen version is mostly made of attention."
        default:
            voice = nil
            text = "\(subject) became a kept spell result. The page noticed \(analysis.scene)"
        }

        return EnchantmentCastResult(
            spellID: spell.id,
            spellName: spell.title,
            subjectName: subject,
            openingLine: "\(spell.title) touched \(subject).",
            resultText: text,
            objectVoice: voice
        )
    }

    func answerObject(prompt: String, result: EnchantmentCastResult, previousTurns: [AskTheBookTurn], day: BookDay) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = trimmed.isEmpty ? "the quiet" : trimmed
        return """
        I hear you ask about \(question).

        I am still \(result.subjectName). My answer is small: look at what I touch, what touches me, and what changes when I am moved. That is where my next sentence lives.
        """
    }
}

enum BookStore {
    static let schemaVersion = 2
    static let fileName = "book-days.json"

    struct Archive: Codable, Equatable {
        var schemaVersion: Int
        var generatedAt: Date
        var days: [BookDay]
    }

    enum LoadSource: String, Equatable {
        case versionedArchive
        case legacyDayArray
        case emptyArchive
        case fallbackToday
    }

    struct Report: Equatable {
        var schemaVersion: Int
        var storagePath: String
        var dayCount: Int
        var pageCount: Int
        var todayID: String
        var todayPageCount: Int
        var todayBookOfYouCount: Int
        var loadSource: LoadSource
        var lastError: String?
    }

    private static var overrideFileURL: URL?
    private static var lastLoadSource: LoadSource = .fallbackToday
    private static var lastError: String?

    static var fileURL: URL {
        if let overrideFileURL {
            return overrideFileURL
        }
        let baseURL = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent(fileName)
    }

    static func withStorageURL<T>(_ url: URL, perform work: () throws -> T) rethrows -> T {
        let previousURL = overrideFileURL
        overrideFileURL = url
        defer {
            overrideFileURL = previousURL
        }
        return try work()
    }

    static func loadDays() -> [BookDay] {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let archive = try? decoder.decode(Archive.self, from: data) {
                lastLoadSource = .versionedArchive
                lastError = nil
                return normalizedDays(archive.days)
            }

            let legacyDays = try decoder.decode([BookDay].self, from: data)
            let days = normalizedDays(legacyDays)
            lastLoadSource = .legacyDayArray
            lastError = nil
            try saveDays(days)
            return days
        } catch {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                lastError = error.localizedDescription
                lastLoadSource = .fallbackToday
            } else {
                lastError = nil
                lastLoadSource = .emptyArchive
            }
            return [BookDay.today()]
        }
    }

    static func saveDays(_ days: [BookDay]) throws {
        try SensitiveFileProtection.protectDirectory(at: fileURL.deletingLastPathComponent())
        let archive = Archive(
            schemaVersion: schemaVersion,
            generatedAt: Date(),
            days: normalizedDays(days)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)
        try SensitiveFileProtection.write(data, to: fileURL)
        lastLoadSource = .versionedArchive
        lastError = nil
    }

    static func today(from days: [BookDay], now: Date = Date(), calendar: Calendar = .current) -> BookDay {
        let id = BookDay.id(for: now, calendar: calendar)
        return days.first { $0.id == id } ?? .day(containing: now, calendar: calendar)
    }

    static func upsert(_ day: BookDay, in days: [BookDay]) -> [BookDay] {
        var updatedDays = days
        if let index = updatedDays.firstIndex(where: { $0.id == day.id }) {
            updatedDays[index] = day
        } else {
            updatedDays.append(day)
        }
        return normalizedDays(updatedDays)
    }

    static func report(for days: [BookDay], now: Date = Date(), calendar: Calendar = .current) -> Report {
        let today = today(from: days, now: now, calendar: calendar)
        let pageCount = days.reduce(0) { count, day in count + day.pages.count }
        return Report(
            schemaVersion: schemaVersion,
            storagePath: fileURL.path,
            dayCount: days.count,
            pageCount: pageCount,
            todayID: today.id,
            todayPageCount: today.pages.count,
            todayBookOfYouCount: today.pages.filter { $0.type == .bookOfYou }.count,
            loadSource: lastLoadSource,
            lastError: lastError
        )
    }

    private static func normalizedDays(_ days: [BookDay], calendar: Calendar = .current) -> [BookDay] {
        var merged: [String: BookDay] = [:]
        for var day in days {
            let dayID = BookDay.id(for: day.date, calendar: calendar)
            day.id = dayID
            day.date = calendar.startOfDay(for: day.date)
            day.pages = day.pages.sorted { $0.createdAt < $1.createdAt }

            if var existing = merged[dayID] {
                existing.pages.append(contentsOf: day.pages)
                existing.pages = uniquePages(existing.pages).sorted { $0.createdAt < $1.createdAt }
                merged[dayID] = existing
            } else {
                day.pages = uniquePages(day.pages)
                merged[dayID] = day
            }
        }

        let today = BookDay.today(calendar: calendar)
        if merged[today.id] == nil {
            merged[today.id] = today
        }

        return merged.values.sorted { $0.date < $1.date }
    }

    private static func uniquePages(_ pages: [BookPage]) -> [BookPage] {
        var seen = Set<String>()
        return pages.filter { page in
            seen.insert(page.id).inserted
        }
    }
}

struct EnchantedPageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.07, blue: 0.13),
                Color(red: 0.20, green: 0.12, blue: 0.24),
                Color(red: 0.06, green: 0.12, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottomTrailing) {
            Text("✦")
                .font(.system(size: 92, weight: .thin))
                .foregroundStyle(.white.opacity(0.12))
                .padding(-4)
        }
    }
}
