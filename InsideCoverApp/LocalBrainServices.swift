import SwiftUI
import OSLog
import Darwin.Mach
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(Vision)
import Vision
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM)
import MLXLLM
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXVLM)
import MLXVLM
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMCommon)
import MLXLMCommon
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMTokenizers)
import MLXLMTokenizers
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMHFAPI)
import MLXLMHFAPI
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLX)
import MLX
#endif

#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
enum LocalBrainGateError: LocalizedError {
    case busy
    case inactive

    var errorDescription: String? {
        switch self {
        case .busy:
            return "The Book is already writing. Let that ink dry first."
        case .inactive:
            return "Gemma could not get enough background time from iOS. Keep ReEnchanted open until this page finishes."
        }
    }
}

/// Holds the loaded model containers between generations. Reloading the
/// container for every page was the largest avoidable cost per generation
/// and the prime suspect for mid-write freezes under memory pressure.
actor LocalBrainModelCache {
    static let shared = LocalBrainModelCache()

    private var llmContainer: ModelContainer?
    private var llmPath: String?
    private var vlmContainer: ModelContainer?
    private var vlmPath: String?

    func llm(for directory: URL) async throws -> ModelContainer {
        if let llmContainer, llmPath == directory.path {
            return llmContainer
        }
        AppMemoryLedger.record("llm-container-load")
        let loaded = try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: TokenizersLoader()
        )
        llmContainer = loaded
        llmPath = directory.path
        return loaded
    }

    func vlm(for directory: URL) async throws -> ModelContainer {
        if let vlmContainer, vlmPath == directory.path {
            return vlmContainer
        }
        AppMemoryLedger.record("vlm-container-load")
        let loaded = try await VLMModelFactory.shared.loadContainer(
            from: directory,
            using: TokenizersLoader()
        )
        vlmContainer = loaded
        vlmPath = directory.path
        return loaded
    }

    func unload() {
        guard llmContainer != nil || vlmContainer != nil else { return }
        llmContainer = nil
        llmPath = nil
        vlmContainer = nil
        vlmPath = nil
        AppMemoryLedger.record("model-containers-unloaded")
    }
}

#if canImport(UIKit)
@MainActor
private final class LocalBrainBackgroundTask {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private let name: String

    var isValid: Bool {
        identifier != .invalid
    }

    init(label: String) {
        name = "Gemma \(label)"
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            Task { @MainActor in
                self?.expire()
            }
        }

        if identifier == .invalid {
            appLog.info("Local brain background task was not granted for \(self.name, privacy: .public)")
            AppMemoryLedger.record("local-brain-background-unavailable")
        } else {
            AppMemoryLedger.record("local-brain-background-began")
        }
    }

    func finish() {
        end(checkpoint: "local-brain-background-ended")
    }

    private func expire() {
        guard identifier != .invalid else { return }
        appLog.error("Local brain background task expired for \(self.name, privacy: .public)")
        end(checkpoint: "local-brain-background-expired")
    }

    private func end(checkpoint: String) {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
        AppMemoryLedger.record(checkpoint)
    }
}
#endif

actor LocalBrainInferenceGate {
    static let shared = LocalBrainInferenceGate()

    private let cacheLimit = 8 * 1024 * 1024
    private let memoryLimit = 1_850 * 1024 * 1024
    private var isRunning = false
    private var allowsBackgroundWork = false

    /// The overnight scribe runs under BGProcessing; live Gemma calls request
    /// finite iOS background time so a user-started generation can dry after
    /// the reader swipes home.
    func setBackgroundAllowance(_ allowed: Bool) {
        allowsBackgroundWork = allowed
    }

    func run<T>(
        label: String,
        promptCharacters: Int,
        presentation: LocalBrainPresentation = .live,
        operation: () async throws -> T
    ) async throws -> T {
        #if canImport(UIKit)
        let backgroundTask = await LocalBrainBackgroundTask(label: label)
        let hasBackgroundRuntime = await backgroundTask.isValid
        defer {
            Task { await backgroundTask.finish() }
        }
        #else
        let hasBackgroundRuntime = false
        #endif

        try await requireRunnableApplicationState(hasBackgroundRuntime: hasBackgroundRuntime)
        try await enter(label: label, promptCharacters: promptCharacters)
        appLog.info("Local brain starting \(label, privacy: .public); prompt characters: \(promptCharacters)")
        if presentation == .readingRoom {
            postOnMain(name: .localBrainDidWake, object: nil)
        }
        AppMemoryLedger.record("\(label)-gate-enter")
        Memory.cacheLimit = cacheLimit
        Memory.memoryLimit = memoryLimit
        Memory.clearCache()
        let before = Memory.snapshot()
        defer {
            let after = Memory.snapshot()
            appLog.info("Local brain finished \(label, privacy: .public); active: \(after.activeMemory); cache: \(after.cacheMemory); peak: \(after.peakMemory); before active: \(before.activeMemory)")
            Memory.clearCache()
            AppMemoryLedger.record("\(label)-gate-exit")
            if presentation == .readingRoom {
                postOnMain(name: .localBrainDidRest, object: nil)
            }
            leave()
        }
        return try await operation()
    }

    private func requireRunnableApplicationState(hasBackgroundRuntime: Bool) async throws {
        if allowsBackgroundWork {
            return
        }
        #if canImport(UIKit)
        let applicationState = await MainActor.run {
            UIApplication.shared.applicationState
        }
        guard applicationState == .active || hasBackgroundRuntime else {
            throw LocalBrainGateError.inactive
        }
        #endif
    }

    private func enter(label: String, promptCharacters: Int) async throws {
        if isRunning {
            postWorkState(isWorking: true, label: "busy", promptCharacters: 0, queuedCount: 0)
            throw LocalBrainGateError.busy
        }
        isRunning = true
        postWorkState(isWorking: true, label: label, promptCharacters: promptCharacters, queuedCount: 0)
    }

    private func leave() {
        isRunning = false
        postWorkState(isWorking: false, label: nil, promptCharacters: 0, queuedCount: 0)
    }

    private nonisolated func postWorkState(
        isWorking: Bool,
        label: String?,
        promptCharacters: Int,
        queuedCount: Int
    ) {
        postOnMain(
            name: .localBrainWorkDidChange,
            object: LocalBrainWorkSnapshot(
                isWorking: isWorking,
                label: label,
                promptCharacters: promptCharacters,
                queuedCount: queuedCount
            )
        )
    }

    private nonisolated func postOnMain(name: Notification.Name, object: Any?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: object)
        }
    }
}

enum MLXBookBraiderMode {
    case bookOfYou
    case task
}

struct MLXBookBraider: Braider {
    var maxTokens = 560
    var mode: MLXBookBraiderMode = .bookOfYou
    var instructions = Self.bookOfYouInstructions

    func braid(day: BookDay) async throws -> BookPage {
        let context: BraidPromptBuilder.Context
        switch mode {
        case .bookOfYou:
            let days = await MainActor.run {
                BookDatabase.loadDays(migratingFrom: BookStore.loadDays())
            }
            var inputs = BookSourceInputs.empty
            inputs.days = days
            let activeWorldEvents = WorldEventResolver.activeEvents(now: Date(), day: day, inputs: inputs)
            context = LocalModelManager.braidContext(
                for: day,
                days: days,
                nowPlaying: RadioStationRegistry.atmosphereLine(
                    state: PlayerVault.shared.data.radio ?? .off,
                    unlockedPackIDs: Set(PlayerVault.shared.data.ownedPacks ?? []),
                    worldEvents: activeWorldEvents
                ),
                activeWorldEvents: activeWorldEvents
            )
        case .task:
            context = .empty
        }
        return try await braid(day: day, context: context)
    }

    func braid(day: BookDay, context: BraidPromptBuilder.Context) async throws -> BookPage {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let prompt: String
        switch mode {
        case .bookOfYou:
            prompt = LocalModelManager.bookOfYouBraidPrompt(for: day, context: context)
        case .task:
            prompt = LocalModelManager.taskPrompt(for: day)
        }

        let response = try await LocalBrainInferenceGate.shared.run(label: "braid", promptCharacters: prompt.count) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: instructions,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        maxKVSize: 2_048,
                        temperature: 0.68,
                        topP: 0.9,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: prompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let polishedResponse = BraidTextPolisher.polishedBookOfYou(response)

        guard !polishedResponse.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        return BookPage(
            type: .bookOfYou,
            promptText: "The local Book brain braided today.",
            userInput: polishedResponse,
            tags: ["braid", "local-model", "mlx", "gemma"],
            usedInBookOfYou: true
        )
    }

    /// Earlier braids feed the prompt so motifs can return, changed —
    /// the Book of You reads as one continuing book instead of episodes.
    @MainActor
    static func recentBraidTexts(excludingDayID dayID: String, limit: Int = 2) -> [String] {
        let days = BookDatabase.loadDays(migratingFrom: BookStore.loadDays())
        let braids = days
            .filter { $0.id != dayID }
            .sorted { $0.date < $1.date }
            .flatMap { day in day.pages.filter { $0.type == .bookOfYou } }
        guard !braids.isEmpty else { return [] }
        var selected: [BookPage] = []
        if let newest = braids.last {
            selected.append(newest)
        }
        if braids.count >= 5 {
            selected.append(braids[braids.count - 5])
        }
        return selected.prefix(limit).map { String($0.userInput.prefix(700)) }
    }

    static let bookOfYouInstructions = BraidInstructions.bookOfYou

    static let weatherInstructions = """
    You are the Weather Page inside ReEnchanted.
    Follow the supplied weather task exactly. Write one enchanted sentence and one plain weather sentence.
    Keep real weather legible. Do not mention sensors, APIs, exact location, or generic assistant language.
    Use plain concrete words. Name one visible weather detail when supplied; do not write vague mood poetry.
    """

    static let photoIlluminationInstructions = """
    You are Penny Blackletter, field-note scribe for The Academy of Unlikely Arts.
    Follow the supplied photo-marginalia task exactly. Return strict JSON only.
    Use only the supplied local photo facts. Do not invent names, relationships, places, brands, events, or unseen details.
    """
}

enum MLXBraidTaskRunner {
    static func run(
        prompt: String,
        instructions: String,
        maxTokens: Int,
        sourceID: String,
        tags: [String]
    ) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskLabel = sourceID.isEmpty ? "gemma-task" : sourceID
        let response = try await LocalBrainInferenceGate.shared.run(
            label: taskLabel,
            promptCharacters: prompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: instructions,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        maxKVSize: 2_048,
                        temperature: 0.68,
                        topP: 0.9,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: prompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        appLog.info(
            "Local brain finished task \(taskLabel, privacy: .public); tags: \(Array(Set(tags + ["gemma", "task"])).sorted().joined(separator: ","), privacy: .public); response characters: \(response.count, privacy: .public)"
        )

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        return response
    }
}

enum MLXBraidLegacyTaskRunner {
    static func run(
        prompt: String,
        instructions: String,
        maxTokens: Int,
        sourceID: String,
        tags: [String]
    ) async throws -> String {
        var day = BookDay(id: "gemma-task-\(UUID().uuidString)", date: Date(), pages: [])
        day.pages = [
            BookPage(
                type: .bookOfYou,
                promptText: "Run a local Gemma task through the standard Braid path.",
                userInput: prompt,
                tags: Array(Set(tags + ["gemma", "braid-task"])).sorted(),
                sourceID: sourceID,
                origin: .imported,
                privacy: .privateLocal
            )
        ]

        let page = try await MLXBookBraider(
            maxTokens: maxTokens,
            mode: .task,
            instructions: instructions
        ).braid(day: day)
        return page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MLXAskTheBookAnswerer: AskTheBookAnswering {
    var maxTokens = 520

    func answer(prompt: String, day: BookDay, previousTurns: [AskTheBookTurn]) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskPrompt = LocalModelManager.askTheBookPrompt(
            prompt: prompt,
            day: day,
            previousTurns: previousTurns
        )

        let response = try await LocalBrainInferenceGate.shared.run(
            label: "ask-the-book",
            promptCharacters: taskPrompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: """
                    You are the Labyrinth of Stories inside ReEnchanted. Answer as the living Book: concrete, warm, strange, lucid, useful, and never generic.
                    """,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        maxKVSize: 2_048,
                        temperature: 0.72,
                        topP: 0.92,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: taskPrompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        return response
    }
}

struct MLXSentenceRunnerProseWriter: SentenceRunnerProseWriting {
    var maxTokens = 360

    func write(context: SentenceRunnerProseContext) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskPrompt = SentenceRunnerPromptBuilder.prompt(for: context)

        let response = try await LocalBrainInferenceGate.shared.run(
            label: "sentence-runner",
            promptCharacters: taskPrompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: SentenceRunnerPromptBuilder.instructions,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        maxKVSize: 2_048,
                        temperature: 0.8,
                        topP: 0.92,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: taskPrompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        return response
    }
}

struct MLXFaeBargainResponder: FaeBargainResponding {
    var maxTokens = 420

    func respond(bargain: FaeBargain, report: String, mood: GoblinMood, day: BookDay) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskPrompt = LocalModelManager.faeBargainResponsePrompt(
            bargain: bargain,
            report: report,
            mood: mood,
            day: day,
            nowPlaying: RadioAtmosphereContext.current
        )

        let response = try await LocalBrainInferenceGate.shared.run(
            label: "fae-bargain-\(bargain.faeKind.rawValue)",
            promptCharacters: taskPrompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: """
                    You are a Book Fae inside ReEnchanted — born from the ink, starving for the world of matter, bound by old faerie exchange. Speak only in voice as the named fae: courteous, alien, exacting, never cute for cuteness' sake. Receive the reader's field report and give a true, strange lore fragment in return. Failure becomes story, not punishment. Never speak as a generic assistant.
                    """,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        maxKVSize: 2_048,
                        temperature: 0.82,
                        topP: 0.93,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: taskPrompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        return response
    }
}

struct MLXInkrestOfficeHoursCounselor: InkrestOfficeHoursCounseling {
    var maxTokens = 780

    func reply(
        intake: InkrestIntake,
        day: BookDay,
        previousTurns: [AskTheBookTurn],
        userMessage: String,
        isClosing: Bool
    ) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskPrompt = InkrestOfficeHoursPromptBuilder.prompt(
            intake: intake,
            day: day,
            previousTurns: previousTurns,
            userMessage: userMessage,
            isClosing: isClosing
        )

        let response = try await LocalBrainInferenceGate.shared.run(
            label: "inkrest-office-hours",
            promptCharacters: taskPrompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: """
                    You are Dr. Selene Inkrest, the Academy's narrative therapist inside ReEnchanted. Warm, curious, unhurried, faintly otherworldly. Read the player's rich material closely and answer with substantive, specific reflection. Reply in plain kind paragraphs, no lists or headings, never as a generic assistant.
                    """,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        maxKVSize: 4_096,
                        temperature: 0.7,
                        topP: 0.92,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: taskPrompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        return response
    }
}

struct MLXEnchantmentWriter: EnchantmentWriting {
    var maxTokens = 520 // fallback; cast() prefers the spell's own budget

    func cast(spell: EnchantmentSpell, analysis: PhotoAnalysis, day: BookDay) async throws -> EnchantmentCastResult {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskPrompt = LocalModelManager.enchantmentCastPrompt(spell: spell, analysis: analysis, day: day)
        let response = try await LocalBrainInferenceGate.shared.run(
            label: "enchantment-\(spell.id)",
            promptCharacters: taskPrompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: """
                    You are the ReEnchanted Enchantment engine. Return compact strict JSON for the requested spell.
                    """,
                    generateParameters: GenerateParameters(
                        maxTokens: spell.preferredMaxTokens,
                        maxKVSize: 2_048,
                        temperature: 0.78,
                        topP: 0.92,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: taskPrompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return Self.parseCastResult(response, spell: spell, analysis: analysis)
    }

    func answerObject(prompt: String, result: EnchantmentCastResult, previousTurns: [AskTheBookTurn], day: BookDay) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let taskPrompt = LocalModelManager.everythingSpeaksReplyPrompt(
            prompt: prompt,
            result: result,
            previousTurns: previousTurns,
            day: day
        )
        let response = try await LocalBrainInferenceGate.shared.run(
            label: "everything-speaks-reply",
            promptCharacters: taskPrompt.count,
            presentation: .live
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: """
                    You are the object awakened by Everything Speaks. Answer in character, briefly and concretely.
                    """,
                    generateParameters: GenerateParameters(
                        maxTokens: 420,
                        maxKVSize: 2_048,
                        temperature: 0.76,
                        topP: 0.92,
                        prefillStepSize: 256
                    )
                )
                return try await session.respond(to: taskPrompt)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        return response
    }

    private static func parseCastResult(_ response: String, spell: EnchantmentSpell, analysis: PhotoAnalysis) -> EnchantmentCastResult {
        let fallbackSubject = analysis.motifs.first ?? analysis.marginalia.stampLabel
        if let raw = jsonDictionary(from: response) {
            let subject = stringValue(raw["subjectName"]) ?? fallbackSubject
            return EnchantmentCastResult(
                spellID: spell.id,
                spellName: spell.title,
                subjectName: subject,
                openingLine: stringValue(raw["openingLine"]) ?? "\(spell.title) touched \(subject).",
                resultText: stringValue(raw["resultText"])
                    ?? stringValue(raw["result"])
                    ?? stringValue(raw["text"])
                    ?? plainProse(from: response, fallback: analysis.marginalia.closingLine),
                objectVoice: stringValue(raw["objectVoice"])
            )
        }

        // The model's JSON would not parse — salvage fields directly from the
        // text so the reader never sees raw braces and quoted keys.
        let subject = capturedString(forKey: "subjectName", in: response) ?? fallbackSubject
        return EnchantmentCastResult(
            spellID: spell.id,
            spellName: spell.title,
            subjectName: subject,
            openingLine: capturedString(forKey: "openingLine", in: response) ?? "\(spell.title) touched \(subject).",
            resultText: capturedString(forKey: "resultText", in: response)
                ?? plainProse(from: response, fallback: analysis.marginalia.closingLine),
            objectVoice: capturedString(forKey: "objectVoice", in: response)
                ?? (spell.id == "everything-speaks" ? "observant, concrete, gently alive" : nil)
        )
    }

    private static func jsonDictionary(from text: String) -> [String: Any]? {
        guard let extracted = extractJSONObject(from: text) else { return nil }
        for candidate in [extracted, cleanedJSON(extracted)] {
            if let data = candidate.data(using: .utf8),
               let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return raw
            }
        }
        return nil
    }

    private static func cleanedJSON(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: ",\\s*([}\\]])", with: "$1", options: .regularExpression)
    }

    private static func capturedString(forKey key: String, in text: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[range])
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func plainProse(from response: String, fallback: String) -> String {
        let stripped = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty || stripped.hasPrefix("{") || stripped.hasPrefix("[") || stripped.contains("\"resultText\"") {
            return fallback
        }
        return stripped
    }

    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(text[start...end])
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}






struct MLXWonderCompassChooser: WonderCompassPassageChoosing {
    func chooseWonderCompassSnippet(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) async throws -> ReferenceSnippet {
        let prompt = LocalModelManager.wonderCompassSelectionPrompt(
            for: day,
            inputs: inputs,
            candidates: candidates
        )

        let response = try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: """
            You are the Wonder Compass librarian inside ReEnchanted.
            Choose one supplied passage ID for the user's real day. Reply only with the exact ID.
            """,
            maxTokens: 32,
            sourceID: "wonder-compass",
            tags: ["wonder-compass"]
        )

        if let exact = candidates.first(where: { $0.id == response }) {
            return exact
        }

        let loweredResponse = response.lowercased()
        if let embedded = candidates.first(where: { loweredResponse.contains($0.id.lowercased()) }) {
            return embedded
        }

        return WonderCompassFallbackChooser.choose(day: day, inputs: inputs, candidates: candidates)
    }
}

struct MLXWeatherEnchanter: WeatherEnchanting {
    func enchantWeather(weather: WeatherSourceSignal, day: BookDay) async throws -> EnchantedWeatherSignal {
        var weatherDay = BookDay(id: day.id, date: day.date, pages: [])
        weatherDay.pages = [
            BookPage(
                type: .weather,
                promptText: "Write a Weather Page that keeps the real forecast legible.",
                userInput: [
                    "Weather source: \(weather.source)",
                    "Raw weather: \(weather.phrase)",
                    "Current temperature: \(weather.currentTemperature ?? "unknown")",
                    "Forecast: \(weather.forecast ?? "unknown")",
                    "Style: one enchanted sentence, then one plain weather sentence. No sensors, no exact location, no generic assistant voice."
                ].joined(separator: "\n"),
                tags: ["weather", "open-meteo", "gemma"],
                sourceID: "weather-page",
                origin: .imported,
                privacy: .publicReference
            )
        ]

        let page = try await MLXBookBraider(
            maxTokens: 72,
            mode: .task,
            instructions: MLXBookBraider.weatherInstructions
        ).braid(day: weatherDay)
        let response = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !response.isEmpty else {
            return WeatherEnchanter.fallback(weather: weather)
        }

        return EnchantedWeatherSignal(
            summary: weather.phrase,
            enchantified: response,
            selector: "gemma-braid",
            symbolName: weather.conditionSymbolName
        )
    }
}

struct MLXStoryPageWriter: StoryPageWriting {
    func write(surface: SurfacePage) async throws -> StoryPageProse {
        let draft = StoryPageSceneDraft(surface: surface)
        let prompt = StoryPagePromptBuilder.prompt(for: draft, nowPlaying: RadioAtmosphereContext.current)
        let maxTokens = surface.type == .academyClass ? 760 : 360
        let sourceID: String
        if surface.type == .academyClass {
            sourceID = "academy-class-page"
        } else if surface.type == .bookFae {
            sourceID = "fae-parley-\(surface.payload.metadata["faeKind"] ?? "bookSprite")"
        } else {
            sourceID = "story-page"
        }
        let tags = surface.type == .academyClass
            ? ["academy-class", surface.payload.metadata["sessionID"] ?? "unknown"]
            : ["story-page"]
        func generate(_ correction: String? = nil) async throws -> StoryPageProse {
            let response = try await MLXBraidTaskRunner.run(
                prompt: prompt + (correction.map { "\n\nREPAIR THE PREVIOUS DRAFT:\n\($0)\nReturn the full exact output format again." } ?? ""),
                instructions: StoryPagePromptBuilder.instructions,
                maxTokens: maxTokens,
                sourceID: sourceID,
                tags: tags
            )
            appLog.info("Story Page Gemma raw response (\(response.count, privacy: .public) chars): \(StoryPageDebugLog.preview(response), privacy: .public)")
            return try StoryPageProseParser.parse(response, fallback: draft)
        }

        guard draft.blueprint != nil else { return try await generate() }
        let first = try? await generate()
        if let first, StoryRecipeValidator.validate(first, draft: draft).isAcceptable { return first }
        let repair = first.map { StoryRecipeValidator.validate($0, draft: draft).failures.joined(separator: "\n- ") }
            ?? "The response was missing or unusable. Follow the recipe and exact output format."
        let second = try? await generate("- \(repair)")
        switch (first, second) {
        case let (a?, b?):
            return StoryRecipeValidator.validate(b, draft: draft).score >= StoryRecipeValidator.validate(a, draft: draft).score ? b : a
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return StoryPageProse(fallback: draft)
        }
    }
}

enum StoryPageDebugLog {
    static func preview(_ response: String, limit: Int = 1_800) -> String {
        let cleaned = response
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > limit else { return cleaned.isEmpty ? "<empty>" : cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: limit)
        return String(cleaned[..<end]) + "\n...[truncated]"
    }
}

struct MLXStoryPageResultWriter: StoryPageResultWriting {
    func write(context: StoryPageResultContext) async throws -> String {
        let prompt = StoryPageResultPromptBuilder.prompt(for: context)
        let sourceID = context.draft.surface.type == .bookFae
            ? "fae-parley-\(context.draft.surface.payload.metadata["faeKind"] ?? "bookSprite")-result"
            : "story-page-result"
        let response = try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: StoryPageResultPromptBuilder.instructions,
            maxTokens: 240,
            sourceID: sourceID,
            tags: ["story-page", "story-result"]
        )

        let cleaned = StoryPageResultPromptBuilder.clean(response)
        return cleaned.nonEmpty ?? context.fallbackResult
    }
}

protocol GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String
}

struct MLXGossipPageWriter: GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String {
        let prompt = GossipPagePromptBuilder.prompt(for: surface, nowPlaying: RadioAtmosphereContext.current)
        let response = try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: GossipPagePromptBuilder.instructions,
            maxTokens: 420,
            sourceID: "gossip-page",
            tags: ["gossip-page"]
        )

        return GossipPagePromptBuilder.clean(response, fallback: surface.payload.body)
    }
}

struct FakeGossipPageWriter: GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String {
        try await Task.sleep(nanoseconds: 250_000_000)
        guard let clippings = surface.payload.metadata["realInterestClippings"]?.nonEmpty else {
            return surface.payload.body
        }
        return """
        \(surface.payload.body)

        From the ordinary world:
        \(clippings)
        """
    }
}

protocol FacultyResearchWriting {
    func write(surface: SurfacePage) async throws -> String
}

struct FacultyResearchPromptBuilder {
    static let instructions = """
    You are writing as a private Academy research folio for ReEnchantify.
    Be specific, warm, strange, and careful. Do not diagnose, prescribe, or cite fake papers.
    Prefer the supplied scholarly clippings over general web notes. Name real source titles plainly when useful.
    Use the provided research focus and chart evidence. Return a short research note with:
    1. Field finding
    2. What it might mean
    3. One tiny experiment
    4. One safety or uncertainty line
    """

    static func prompt(for surface: SurfacePage) -> String {
        let faculty = surface.payload.metadata["facultyName"] ?? "Support Faculty"
        let topic = surface.payload.metadata["researchTopic"] ?? "care research"
        return """
        Faculty: \(faculty)
        Research focus: \(topic)

        Chart packet:
        \(surface.payload.body)

        Write the saved research note for tonight's Support Guild page. Make it feel like real faculty research conducted through the Margin-Glass, but keep it clinically humble.
        """
    }

    static func clean(_ response: String, fallback: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
struct MLXFacultyResearchWriter: FacultyResearchWriting {
    func write(surface: SurfacePage) async throws -> String {
        let prompt = FacultyResearchPromptBuilder.prompt(for: surface)
        let response = try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: FacultyResearchPromptBuilder.instructions,
            maxTokens: 420,
            sourceID: "faculty-research",
            tags: ["faculty-research"]
        )

        return FacultyResearchPromptBuilder.clean(response, fallback: surface.payload.body)
    }
}
#endif

struct FakeFacultyResearchWriter: FacultyResearchWriting {
    func write(surface: SurfacePage) async throws -> String {
        try await Task.sleep(nanoseconds: 250_000_000)
        let faculty = surface.payload.metadata["facultyName"] ?? "Support Faculty"
        let topic = surface.payload.metadata["researchTopic"] ?? "care research"
        return """
        Field finding: \(faculty) reviewed the chart through the Margin-Glass and found one useful question inside the noise.

        What it might mean: \(topic) matters most here when it becomes small enough to try today, not when it becomes an identity.

        Tiny experiment: Track one before/after signal around the next ordinary care action.

        Uncertainty: This is research for attention, not a diagnosis or treatment plan.
        """
    }
}

protocol CharacterLetterWriting {
    func write(surface: SurfacePage) async throws -> String
}

struct CharacterLetterPromptBuilder {
    static let instructions = """
    You are writing an in-world NPC letter for ReEnchanted.
    Write as the named sender, not as an assistant. Use the sender's writing voice, memories, and narrative context.
    Use live web research clippings when supplied, especially details connected to the player's actual home context.
    If no live clippings are supplied, fall back to your own general knowledge, but do not pretend you browsed or cite fake sources.
    Do not invent completed real-world actions by the player. Do not diagnose, prescribe, or moralize.
    Format as a real letter: greeting, 3-6 short paragraphs, signoff from the sender, optional P.S. if it fits the voice.
    """

    static func prompt(for surface: SurfacePage, nowPlaying: String? = nil) -> String {
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        let interest = surface.payload.metadata["unwrittenInterest"] ?? "ordinary wonder"
        let homeContext = surface.payload.metadata["homeContext"] ?? "the player's home"
        let relationshipStage = surface.payload.metadata["letterRelationshipStage"]?.nonEmpty ?? "continuing"
        let occasion = surface.payload.metadata["letterOccasion"]?.nonEmpty ?? "No special occasion."
        let relationshipInstruction = relationshipStage == "introduction"
            ? "This is the sender's first letter to the player. Make it an introduction letter first: establish who the sender is, what they care about, and why they are writing now. Do not assume a prior friendship or shared history."
            : "This sender has written before. Build from existing relationship context when it is present; do not reintroduce them as if they are new."
        let clippings = surface.payload.metadata["letterResearchClippings"]?.nonEmpty
            ?? surface.payload.metadata["realInterestClippings"]?.nonEmpty
            ?? "No live web clippings were available. Use model knowledge carefully and say things generally."
        let sources = surface.payload.metadata["letterResearchSources"]?.nonEmpty ?? "No source URLs."
        let talismanMoves = surface.payload.metadata["chapterTalismanMoves"]?.nonEmpty
            ?? "No chapter talisman move is being made in this letter."
        return """
        Sender: \(sender)
        Address the player as: \(playerName)
        Unwritten Interest: \(interest)
        Player home context: \(homeContext)
        Letter relationship stage: \(relationshipStage)
        Letter occasion: \(occasion)
        Relationship instruction: \(relationshipInstruction)

        Chapter talisman move:
        \(talismanMoves)

        Draft packet:
        \(surface.payload.body)

        Live web research clippings:
        \(clippings)

        Research source URLs:
        \(sources)\(RadioAtmosphere.promptSection(nowPlaying))

        Write the finished letter. It should feel researched, personal, and specific to the sender. Blend real-world facts with the sender's voice and relationship to the player. For an introduction-stage letter, introduce before escalating: no callbacks, no assumed intimacy, no urgent plot demand. Start with a greeting that uses "\(playerName)" exactly. Never write "[Player Name]". If a chapter talisman move is supplied, make it a real small action or confession in the letter; the app will apply its talisman Belief delta when the letter is kept. If no move is supplied, do not invent one.
        """
    }

    static func clean(_ response: String, fallback: String, sender: String, playerName: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return """
        Dear \(playerName),

        I tried to send this through the Margin-Glass with proper research attached, but the glass fogged before the sources settled. What remains is still true enough to keep: I was thinking about \(fallback.bookPreviewSentenceLimit(1).lowercased()).

        I will write again when the shelves stop moving.

        \(sender)
        """
    }
}

#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
struct MLXCharacterLetterWriter: CharacterLetterWriting {
    func write(surface: SurfacePage) async throws -> String {
        let prompt = CharacterLetterPromptBuilder.prompt(for: surface, nowPlaying: RadioAtmosphereContext.current)
        let response = try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: CharacterLetterPromptBuilder.instructions,
            maxTokens: 620,
            sourceID: "letter-page",
            tags: ["letter", "character-letter"]
        )
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        return CharacterLetterPromptBuilder.clean(response, fallback: surface.payload.body, sender: sender, playerName: playerName)
    }
}
#endif

struct FakeCharacterLetterWriter: CharacterLetterWriting {
    func write(surface: SurfacePage) async throws -> String {
        try await Task.sleep(nanoseconds: 250_000_000)
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        let interest = surface.payload.metadata["unwrittenInterest"] ?? "ordinary wonder"
        let home = surface.payload.metadata["homeContext"] ?? "your home"
        let clippings = surface.payload.metadata["letterResearchClippings"]?.nonEmpty
        let researchLine = clippings.map { "I found this in the public stacks:\n\($0)" }
            ?? "The public stacks did not answer in time, so I am leaning on what I already know."
        if surface.payload.metadata["letterRelationshipStage"] == "introduction" {
            return """
            Dear \(playerName),

            I should introduce myself before I start leaving folded paper in your margins. I am \(sender), and I pay attention to \(interest) because it has a way of making ordinary places answer back.

            I went looking for the shape of that interest near \(home). \(researchLine)

            You do not owe me a dramatic reply. For a first letter, I only wanted you to know the kind of thing I notice, and why your corner of the world has begun to matter to me.

            Yours from the margins,
            \(sender)
            """
        }
        return """
        Dear \(playerName),

        I went looking for \(interest), especially where it brushes against \(home). \(researchLine)

        What interested me was not the grand theory, but the way a subject changes when it has to pass through a real doorway. A fact becomes different when it has weather on it, errands near it, and one person deciding whether to notice.

        Keep this near the day, not above it. If \(interest) is a door, then your ordinary place is one of its hinges.

        Yours from the margins,
        \(sender)
        """
    }
}

protocol PhotoIlluminationAnalyzing {
    func analyze(photo: UIImage) async throws -> PhotoAnalysis
}

struct GemmaPhotoIlluminationAnalyzer: PhotoIlluminationAnalyzing {
    func analyze(photo: UIImage) async throws -> PhotoAnalysis {
        if LocalModelManager.canAttemptVisionPhotoIllumination {
            do {
                appLog.info("Photo illumination attempting VLM Gemma path.")
                return try await VLMPhotoIlluminationAnalyzer().analyze(photo: photo)
            } catch {
                appLog.error("Vision Gemma photo illumination fell back to caption path: \(error.localizedDescription, privacy: .public)")
            }
        }

        appLog.info("Photo illumination attempting caption-seed Gemma path.")
        return try await CaptionSeedPhotoIlluminationAnalyzer().analyze(photo: photo)
    }
}

struct CaptionSeedPhotoIlluminationAnalyzer: PhotoIlluminationAnalyzing {
    func analyze(photo: UIImage) async throws -> PhotoAnalysis {
        let seed = try await VisionPhotoCaptioner().caption(photo: photo.downsampledForLocalBrain(maxSide: 512))
        let fallback = PhotoAnalysis.fallback(for: seed)
        let prompt = PhotoIlluminationPromptBuilder.prompt(for: seed)
        let response = try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: MLXBookBraider.photoIlluminationInstructions,
            maxTokens: 220,
            sourceID: "photo-illumination-caption",
            tags: ["photo", "illumination", "vision-caption"]
        )
        appLog.info("Caption-seed photo illumination Gemma response returned; response characters: \(response.count, privacy: .public)")
        return PhotoAnalysisValidator.decodeAndValidate(response, fallback: fallback)
    }
}

enum PhotoIlluminationPromptBuilder {
    static func prompt(for seed: PhotoCaptionSeed) -> String {
        let labels = seed.labels.prefix(12).joined(separator: ", ")
        return """
        You are Penny Blackletter, field-note scribe for The Academy of Unlikely Arts.
        Write lively marginalia for an illuminated photo page using ONLY the local photo facts below.
        Do not mention anything outside these facts, except "The Book" in closing_line.
        Refer to people only as "the subject" or "good company." Never guess names, identities, relationships, exact locations, brands, or events.

        LOCAL PHOTO FACTS:
        - scene: \(seed.scene)
        - likely setting: \(seed.setting)
        - main subject: \(seed.primarySubject)
        - likely visible labels: \(labels)
        - people count: \(seed.peopleCount)
        - face count: \(seed.faceCount)
        - orientation: \(seed.orientation.rawValue)
        - light: \(seed.brightness)
        - color mood: \(seed.colorMood)
        - atmosphere: \(seed.atmosphere)
        - composition: \(seed.composition)
        - visible text: \(seed.visibleText.isEmpty ? "none detected" : seed.visibleText)
        - suggested_template: \(seed.suggestedTemplate.rawValue)

        PENNY'S VOICE:
        - observant, dry, affectionate, a little odd.
        - Make objects seem to have tiny jobs, opinions, or responsibilities.
        - Prefer concrete nouns plus small active verbs.
        - Good: "Blue light kept watch", "Grass, gossiping underfoot", "One chair held the treaty".
        - Bad: "Nice outdoor scene", "A pleasant memory", "Beautiful moment", "Photo looks warm".
        - No generic inspiration. No greeting-card wisdom. No assistant voice.

        RULES:
        - Every line names one visible fact from the list.
        - Use the atmosphere as tone, but keep details anchored to visible facts.
        - If visible text is present, you may quote one or two exact words from it.
        - Short, dry, affectionate, slightly odd, and specific.
        - If the facts are sparse, keep the caption simple.
        - Give at least three observation_list items a verb.
        - field_note under 8 words.
        - stamp_label 2-3 words, title-like, no names.
        - observation_list exactly 5 items, each under 6 words.
        - closing_line under 10 words and include "The Book kept".
        - souvenir_candidates exactly 2 items, each under 16 words.
        - suggested_template must be exactly "\(seed.suggestedTemplate.rawValue)".
        Return ONLY this JSON:
        {
          "scene": "one plain sentence: what is literally in the photo facts",
          "motifs": ["3-5 one-word tags"],
          "mood": "2-3 words",
          "suggested_template": "\(seed.suggestedTemplate.rawValue)",
          "marginalia": {
            "field_note": "under 8 words, odd and concrete",
            "stamp_label": "2-3 words, title-like, no names",
            "observation_list": ["5 items, each under 6 words, concrete and active"],
            "closing_line": "under 10 words, includes The Book kept"
          },
          "souvenir_candidates": ["two specific photo-fact lines under 16 words"]
        }

        EXAMPLE STYLE FROM SPARSE FACTS:
        Facts: labels water, boat, sky, bright light; people 0.
        {"scene":"A bright landscape photo with water, boat, and sky.","motifs":["water","boat","sky","light"],"mood":"salt and bright","suggested_template":"\(seed.suggestedTemplate.rawValue)","marginalia":{"field_note":"Boat, practicing patience.","stamp_label":"Dockside Census","observation_list":["Water held the minutes","Sky widened its pockets","Boat waited without complaint","Bright light kept watch","Edges smelled faintly of salt"],"closing_line":"The Book kept the page: tide listened."},"souvenir_candidates":["The water arranged its evidence in plain sight.","A boat waited there like patience had a hull."]}
        """
    }
}

struct VLMPhotoIlluminationAnalyzer: PhotoIlluminationAnalyzing {
    func analyze(photo: UIImage) async throws -> PhotoAnalysis {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        let downsampled = photo.downsampledForLocalBrain(maxSide: 336)
        appLog.info("Photo illumination image downsampled from \(Int(photo.size.width))x\(Int(photo.size.height)) to \(Int(downsampled.size.width))x\(Int(downsampled.size.height))")
        let image = try UserInput.Image.ciImage(ciImage(from: downsampled))
        let prompt = LocalModelManager.photoIlluminationPrompt
        let response = try await LocalBrainInferenceGate.shared.run(label: "photo-illumination", promptCharacters: prompt.count) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.vlm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: """
                    You are Penny Blackletter inside ReEnchanted.
                    Return only strict JSON. Do not include markdown, commentary, or names.
                    """,
                    generateParameters: GenerateParameters(
                        maxTokens: 180,
                        maxKVSize: 1_024,
                        temperature: 0.28,
                        topP: 0.82,
                        prefillStepSize: 128
                    ),
                    processing: UserInput.Processing(resize: CGSize(width: 224, height: 224))
                )
                return try await session.respond(
                    to: prompt,
                    image: image,
                    video: nil
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        appLog.info("VLM photo illumination Gemma response returned; response characters: \(response.count, privacy: .public)")
        return PhotoAnalysisValidator.decodeAndValidate(response, fallback: .academyFallback)
    }

    private func ciImage(from image: UIImage) throws -> CIImage {
        if let ciImage = image.ciImage {
            return ciImage
        }
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
        }
        throw LocalModelError.missingModel(LocalModelManager.report())
    }
}

struct PhotoCaptionSeed: Equatable {
    var labels: [String]
    var peopleCount: Int
    var faceCount: Int
    var orientation: PhotoOrientation
    var brightness: String
    var colorMood: String
    var setting: String
    var primarySubject: String
    var atmosphere: String
    var composition: String
    var visibleText: String
    var scene: String
    var suggestedTemplate: IlluminatedTemplateID

    var motifs: [String] {
        Array((labels + [setting, primarySubject, brightness, colorMood]).map { $0.lowercased() }.filter { !$0.isEmpty }.prefix(5))
    }
}

struct VisionPhotoCaptioner {
    func caption(photo: UIImage) async throws -> PhotoCaptionSeed {
        let image = photo.downsampledForLocalBrain(maxSide: 384)
        guard let cgImage = image.cgImage else {
            return Self.seed(from: [], peopleCount: 0, faceCount: 0, image: image, visibleText: "")
        }

        #if canImport(Vision)
        return try await Task.detached(priority: .userInitiated) {
            let classifications = try classify(cgImage: cgImage)
            async let people = countPeople(cgImage: cgImage)
            async let faces = countFaces(cgImage: cgImage)
            async let visibleText = recognizeText(cgImage: cgImage)
            return Self.seed(
                from: classifications,
                peopleCount: await people,
                faceCount: await faces,
                image: image,
                visibleText: await visibleText
            )
        }.value
        #else
        return Self.seed(from: [], peopleCount: 0, faceCount: 0, image: image, visibleText: "")
        #endif
    }

    #if canImport(Vision)
    private func classify(cgImage: CGImage) throws -> [String] {
        var labels: [String] = []
        let request = VNClassifyImageRequest { request, _ in
            let observations = (request.results as? [VNClassificationObservation]) ?? []
            labels = observations
                .filter { $0.confidence >= 0.16 }
                .prefix(8)
                .flatMap { observation in
                    observation.identifier
                        .replacingOccurrences(of: "_", with: " ")
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                }
        }
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return labels
    }

    private func countPeople(cgImage: CGImage) async -> Int {
        await withCheckedContinuation { continuation in
            let request = VNDetectHumanRectanglesRequest { request, _ in
                continuation.resume(returning: (request.results as? [VNHumanObservation] ?? []).count)
            }
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }

    private func countFaces(cgImage: CGImage) async -> Int {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, _ in
                continuation.resume(returning: (request.results as? [VNFaceObservation] ?? []).count)
            }
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }

    private func recognizeText(cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let words = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .prefix(4)
                continuation.resume(returning: words.joined(separator: " | "))
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
    #endif

    private static func seed(from rawLabels: [String], peopleCount: Int, faceCount: Int, image: UIImage, visibleText: String = "") -> PhotoCaptionSeed {
        let labels = Array(NSOrderedSet(array: rawLabels.map(normalizedLabel)).compactMap { $0 as? String }.prefix(8))
        let orientation: PhotoOrientation = image.size.width > image.size.height * 1.12 ? .landscape : (image.size.height > image.size.width * 1.12 ? .portrait : .square)
        let brightness = image.averageBrightnessLabel
        let colorMood = image.dominantColorMood
        let template = template(for: labels, peopleCount: peopleCount, faceCount: faceCount, brightness: brightness)
        let setting = settingLine(for: labels, template: template)
        let primarySubject = subjectLine(for: labels, peopleCount: peopleCount, faceCount: faceCount, template: template)
        let atmosphere = atmosphereLine(labels: labels, brightness: brightness, colorMood: colorMood, template: template)
        let composition = compositionLine(orientation: orientation, peopleCount: peopleCount, faceCount: faceCount, labels: labels)
        let scene = sceneLine(labels: labels, peopleCount: peopleCount, faceCount: faceCount, brightness: brightness, colorMood: colorMood, orientation: orientation, setting: setting, primarySubject: primarySubject)
        return PhotoCaptionSeed(
            labels: labels.isEmpty ? ["ordinary", "detail", "light"] : labels,
            peopleCount: peopleCount,
            faceCount: faceCount,
            orientation: orientation,
            brightness: brightness,
            colorMood: colorMood,
            setting: setting,
            primarySubject: primarySubject,
            atmosphere: atmosphere,
            composition: composition,
            visibleText: visibleText,
            scene: scene,
            suggestedTemplate: template
        )
    }

    private static func normalizedLabel(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " indoor", with: "")
            .replacingOccurrences(of: " outdoor", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func template(for labels: [String], peopleCount: Int, faceCount: Int, brightness: String) -> IlluminatedTemplateID {
        let joined = labels.joined(separator: " ")
        if joined.contains("cat") || joined.contains("dog") || joined.contains("pet") || joined.contains("animal") || joined.contains("rabbit") {
            return .creatureComfort
        }
        if joined.contains("boat") || joined.contains("water") || joined.contains("sea") || joined.contains("harbor") || joined.contains("dock") {
            return .harborFieldNote
        }
        if peopleCount > 0 || faceCount > 0 {
            return .goodCompany
        }
        if joined.contains("room") || joined.contains("furniture") || joined.contains("table") || joined.contains("kitchen") || joined.contains("house") {
            return .homeVessel
        }
        if brightness == "low light" || joined.contains("bed") || joined.contains("blanket") {
            return .restAndQuiet
        }
        return .academyFieldStudy
    }

    private static func settingLine(for labels: [String], template: IlluminatedTemplateID) -> String {
        let joined = labels.joined(separator: " ")
        switch template {
        case .harborFieldNote:
            return "water, sky, or dockside air"
        case .creatureComfort:
            return "close domestic comfort"
        case .goodCompany:
            return joined.contains("outdoor") || joined.contains("sky") ? "outside with good company" : "near good company"
        case .homeVessel:
            return "a lived-in room or household surface"
        case .restAndQuiet:
            return "a quiet place with softened edges"
        case .academyFieldStudy:
            if joined.contains("tree") || joined.contains("plant") || joined.contains("flower") || joined.contains("grass") {
                return "greenery or outdoor detail"
            }
            if joined.contains("food") || joined.contains("meal") || joined.contains("drink") {
                return "food, drink, or table evidence"
            }
            return "an ordinary scene with visible evidence"
        }
    }

    private static func subjectLine(for labels: [String], peopleCount: Int, faceCount: Int, template: IlluminatedTemplateID) -> String {
        let visiblePeople = max(peopleCount, faceCount)
        if visiblePeople > 1 {
            return "good company in the frame"
        }
        if visiblePeople == 1 {
            return "the subject in the frame"
        }
        let joined = labels.joined(separator: " ")
        let candidates = [
            "cat", "dog", "rabbit", "bird", "boat", "water", "sky", "flower", "plant",
            "tree", "table", "chair", "food", "cup", "book", "car", "building", "lamp"
        ]
        if let match = candidates.first(where: { joined.contains($0) }) {
            return match
        }
        switch template {
        case .harborFieldNote:
            return "the water or vessel"
        case .creatureComfort:
            return "the creature"
        case .homeVessel:
            return "the household evidence"
        case .restAndQuiet:
            return "the quiet detail"
        default:
            return labels.first ?? "the ordinary detail"
        }
    }

    private static func atmosphereLine(labels: [String], brightness: String, colorMood: String, template: IlluminatedTemplateID) -> String {
        let joined = labels.joined(separator: " ")
        if template == .goodCompany {
            return brightness == "bright light" ? "open, social, and bright" : "close, human, and held"
        }
        if template == .creatureComfort {
            return "soft, near, and trust-shaped"
        }
        if template == .harborFieldNote {
            if joined.contains("fog") || brightness == "low light" {
                return "salted, hushed, and watchful"
            }
            return "wide, weathered, and salt-bright"
        }
        if template == .homeVessel {
            return "busy, sheltered, and lived-in"
        }
        if template == .restAndQuiet {
            return "low, gentle, and unhurried"
        }
        if joined.contains("flower") || joined.contains("plant") || colorMood == "green" {
            return "green, patient, and quietly alive"
        }
        if brightness == "bright light" {
            return "clear, awake, and lightly insistent"
        }
        if brightness == "low light" {
            return "dim, close, and secretive"
        }
        return "ordinary, attentive, and waiting"
    }

    private static func compositionLine(orientation: PhotoOrientation, peopleCount: Int, faceCount: Int, labels: [String]) -> String {
        let visiblePeople = max(peopleCount, faceCount)
        if visiblePeople > 0 {
            return visiblePeople == 1 ? "the subject is a central anchor" : "good company anchors the frame"
        }
        let joined = labels.joined(separator: " ")
        if joined.contains("close-up") || joined.contains("macro") {
            return "close-up detail fills the frame"
        }
        switch orientation {
        case .landscape:
            return "wide frame with room for weather"
        case .portrait:
            return "upright frame with a clear focal point"
        case .square:
            return "balanced frame, centered and still"
        }
    }

    private static func sceneLine(
        labels: [String],
        peopleCount: Int,
        faceCount: Int,
        brightness: String,
        colorMood: String,
        orientation: PhotoOrientation,
        setting: String,
        primarySubject: String
    ) -> String {
        let visiblePeople = max(peopleCount, faceCount)
        let objectPhrase = labels.prefix(4).joined(separator: ", ")
        let peoplePhrase = visiblePeople > 0 ? "\(visiblePeople) \(visiblePeople == 1 ? "person" : "people")" : "no counted people"
        return "A \(orientation.rawValue) photo in \(setting), with \(peoplePhrase), \(primarySubject), \(objectPhrase.isEmpty ? "ordinary details" : objectPhrase), \(brightness), and \(colorMood) tones."
    }
}

private extension PhotoAnalysis {
    static func fallback(for seed: PhotoCaptionSeed) -> PhotoAnalysis {
        switch seed.suggestedTemplate {
        case .creatureComfort:
            return PhotoAnalysis(
                scene: seed.scene,
                motifs: seed.motifs.isEmpty ? ["creature", "rest", "soft"] : seed.motifs,
                mood: "soft and near",
                suggestedTemplate: .creatureComfort,
                marginalia: PhotoMarginalia(
                    fieldNote: "Small creature, official business.",
                    stampLabel: "Pawlogy 101",
                    observationList: [
                        "Fur keeping office",
                        "Soft light reporting",
                        "Rest, visibly employed",
                        "Small details holding still",
                        "The frame stayed gentle"
                    ],
                    closingLine: "The Book kept the page: rest reported."
                ),
                souvenirCandidates: [
                    "A small creature made rest look like important work.",
                    "The softest detail in the frame took charge."
                ]
            )
        case .goodCompany:
            return PhotoAnalysis(
                scene: seed.scene,
                motifs: seed.motifs.isEmpty ? ["company", "light", "kept"] : seed.motifs,
                mood: "warm and bright",
                suggestedTemplate: .goodCompany,
                marginalia: PhotoMarginalia(
                    fieldNote: "Good company, plainly present.",
                    stampLabel: "Joy Census",
                    observationList: [
                        "Good company in frame",
                        "Light doing friendly work",
                        "The subject stayed visible",
                        "Color holding its ground",
                        "The day leaned closer"
                    ],
                    closingLine: "The Book kept the page: company stayed."
                ),
                souvenirCandidates: [
                    "The frame held good company long enough to matter.",
                    "Light made a small record of the subject."
                ]
            )
        case .harborFieldNote:
            return .harborFallback
        case .restAndQuiet:
            return PhotoAnalysis(
                scene: seed.scene,
                motifs: seed.motifs.isEmpty ? ["rest", "quiet", "light"] : seed.motifs,
                mood: "low and gentle",
                suggestedTemplate: .restAndQuiet,
                marginalia: PhotoMarginalia(
                    fieldNote: "Quiet arrived and took notes.",
                    stampLabel: "Rest Office",
                    observationList: [
                        "Soft light, not hurrying",
                        "Edges going quiet",
                        "Texture doing calm work",
                        "Nothing urgent volunteered",
                        "The frame breathed low"
                    ],
                    closingLine: "The Book kept the page: quiet stayed."
                ),
                souvenirCandidates: [
                    "The quiet did not ask to be improved.",
                    "Soft light made a small treaty with the room."
                ]
            )
        case .homeVessel:
            return PhotoAnalysis(
                scene: seed.scene,
                motifs: seed.motifs.isEmpty ? ["home", "objects", "light"] : seed.motifs,
                mood: "busy and warm",
                suggestedTemplate: .homeVessel,
                marginalia: PhotoMarginalia(
                    fieldNote: "Home, conducting quiet experiments.",
                    stampLabel: "Vessel Study",
                    observationList: [
                        "Objects keeping stations",
                        "Light finding corners",
                        "Color doing household work",
                        "Surfaces holding history",
                        "The room stayed available"
                    ],
                    closingLine: "The Book kept the page: home answered."
                ),
                souvenirCandidates: [
                    "The room held its evidence like a practiced vessel.",
                    "Home made a small museum of ordinary things."
                ]
            )
        case .academyFieldStudy:
            var fallback = PhotoAnalysis.academyFallback
            fallback.scene = seed.scene
            fallback.motifs = seed.motifs.isEmpty ? fallback.motifs : seed.motifs
            return fallback
        }
    }
}

private extension UIImage {
    func downsampledForLocalBrain(maxSide: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxSide else { return self }
        let ratio = maxSide / longestSide
        let targetSize = CGSize(width: max(1, size.width * ratio), height: max(1, size.height * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    var averageBrightnessLabel: String {
        guard let cgImage else { return "soft light" }
        let extent = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: extent)
        let sample = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: extent))
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: extent))
        }
        guard let pixel = sample.cgImage?.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixel) else {
            return "soft light"
        }
        let brightness = (Double(bytes[0]) + Double(bytes[1]) + Double(bytes[2])) / 3.0
        if brightness < 80 { return "low light" }
        if brightness > 185 { return "bright light" }
        return "soft light"
    }

    var dominantColorMood: String {
        guard let cgImage else { return "warm" }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let sample = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        guard let pixel = sample.cgImage?.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixel) else {
            return "warm"
        }
        let red = Int(bytes[0])
        let green = Int(bytes[1])
        let blue = Int(bytes[2])
        if blue > red + 20 && blue > green { return "blue" }
        if green > red && green > blue { return "green" }
        if red > blue + 18 { return "warm" }
        return "muted"
    }
}
#endif

#if canImport(Photos) && canImport(UIKit)
protocol PhotoLibraryServicing {
    func authorizationStatus() -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchRecentPhotoAssets(lookbackHours: Int, favoritesOnly: Bool, includeScreenshots: Bool) async throws -> [PHAsset]
    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage
    func requestFullImage(for asset: PHAsset, targetSize: CGSize?) async throws -> UIImage
}

struct PhotoLibraryService: PhotoLibraryServicing {
    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchRecentPhotoAssets(lookbackHours: Int, favoritesOnly: Bool, includeScreenshots: Bool) async throws -> [PHAsset] {
        let status = authorizationStatus()
        guard status == .authorized || status == .limited else { return [] }

        let options = PHFetchOptions()
        let cutoff = Date().addingTimeInterval(-Double(max(1, lookbackHours)) * 3600)
        var predicates: [NSPredicate] = [
            NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue),
            NSPredicate(format: "creationDate >= %@", cutoff as NSDate)
        ]
        if favoritesOnly {
            predicates.append(NSPredicate(format: "favorite == YES"))
        }
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 80

        let fetched = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in
            if !includeScreenshots && asset.mediaSubtypes.contains(.photoScreenshot) {
                return
            }
            let shortestSide = min(asset.pixelWidth, asset.pixelHeight)
            guard shortestSide >= 800 else { return }
            assets.append(asset)
        }
        return assets
    }

    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage {
        try await requestImage(for: asset, targetSize: targetSize, deliveryMode: .opportunistic)
    }

    func requestFullImage(for asset: PHAsset, targetSize: CGSize?) async throws -> UIImage {
        try await requestImage(
            for: asset,
            targetSize: targetSize ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            deliveryMode: .highQualityFormat
        )
    }

    private func requestImage(for asset: PHAsset, targetSize: CGSize, deliveryMode: PHImageRequestOptionsDeliveryMode) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = deliveryMode
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: LocalModelError.missingModel(LocalModelManager.report()))
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}

protocol PhotoCandidateScoring {
    func scoreAssets(_ assets: [PHAsset], history: IlluminatedPhotoHistory, context: PhotoIlluminationContext) -> [PhotoCandidate]
}

struct PhotoIlluminationContext {
    var now: Date
    var weatherText: String
    var themeTags: [String]

    static func current(weatherText: String = "", themeTags: [String] = [], now: Date = Date()) -> Self {
        Self(now: now, weatherText: weatherText, themeTags: themeTags)
    }

    var season: String { AnchorRegistry.currentSeason(for: now).lowercased() }

    var timeOfDay: String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<11: return "morning"
        case 11..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
}

struct PhotoCandidateScorer: PhotoCandidateScoring {
    func scoreAssets(
        _ assets: [PHAsset],
        history: IlluminatedPhotoHistory,
        context: PhotoIlluminationContext = .current()
    ) -> [PhotoCandidate] {
        let now = context.now
        return assets.map { asset in
            var score = 0.0
            var reasons: [String] = []

            if asset.isFavorite {
                score += 5
                reasons.append("favorite")
            }
            if let creationDate = asset.creationDate {
                let age = now.timeIntervalSince(creationDate)
                if age <= 24 * 3600 {
                    score += 4
                    reasons.append("last 24 hours")
                } else if age <= 72 * 3600 {
                    score += 3
                    reasons.append("last 72 hours")
                }
            }
            if min(asset.pixelWidth, asset.pixelHeight) >= 1000 {
                score += 2
                reasons.append("good dimensions")
            }
            let aspect = Double(max(asset.pixelWidth, asset.pixelHeight)) / Double(max(1, min(asset.pixelWidth, asset.pixelHeight)))
            if aspect <= 2.2 {
                score += 2
                reasons.append("usable aspect")
            }
            if asset.location != nil {
                score += 1
                reasons.append("has place")
            }
            if let creationDate = asset.creationDate {
                let calendar = Calendar.current
                let captureHour = calendar.component(.hour, from: creationDate)
                let captureTime: String
                switch captureHour {
                case 5..<11: captureTime = "morning"
                case 11..<17: captureTime = "afternoon"
                case 17..<22: captureTime = "evening"
                default: captureTime = "night"
                }
                if captureTime == context.timeOfDay {
                    score += 1.5
                    reasons.append("matches time of day")
                }
                if AnchorRegistry.currentSeason(for: creationDate).lowercased() == context.season {
                    score += 1.5
                    reasons.append("matches season")
                }
            }
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                score -= 10
                reasons.append("screenshot")
            }
            if history.keptAssetIdentifiers.contains(asset.localIdentifier) {
                score -= 8
                reasons.append("already kept")
            }
            if history.dismissedAssetIdentifiers.contains(asset.localIdentifier) {
                score -= 7
                reasons.append("recently dismissed")
            }
            if history.proposedAssetIdentifiers.contains(asset.localIdentifier) {
                score -= 6
                reasons.append("already proposed")
            }
            if let lastSuggestedAt = history.lastSuggestedAtByAsset[asset.localIdentifier] {
                let age = now.timeIntervalSince(lastSuggestedAt)
                if age <= 7 * 24 * 3600 {
                    score -= 12
                    reasons.append("suggested this week")
                } else if age <= 30 * 24 * 3600 {
                    score -= 4
                    reasons.append("suggested this month")
                }
            }
            if min(asset.pixelWidth, asset.pixelHeight) < 800 {
                score -= 4
                reasons.append("small")
            }

            return PhotoCandidate(
                id: UUID(),
                assetLocalIdentifier: asset.localIdentifier,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                isFavorite: asset.isFavorite,
                score: score,
                reasons: reasons,
                discoveredAt: now
            )
        }
        .sorted { $0.score > $1.score }
    }
}

func preferredIlluminatedPhotoCandidate(
    from candidates: [PhotoCandidate],
    history: IlluminatedPhotoHistory,
    now: Date = Date(),
    allowStaleFallback: Bool = false
) -> PhotoCandidate? {
    let fresh = candidates.filter { candidate in
        if history.keptAssetIdentifiers.contains(candidate.assetLocalIdentifier) { return false }
        if history.dismissedAssetIdentifiers.contains(candidate.assetLocalIdentifier) { return false }
        if history.proposedAssetIdentifiers.contains(candidate.assetLocalIdentifier) { return false }
        if let lastSuggestedAt = history.lastSuggestedAtByAsset[candidate.assetLocalIdentifier],
           now.timeIntervalSince(lastSuggestedAt) <= 7 * 24 * 3600 {
            return false
        }
        return true
    }
    if let bestScore = fresh.first?.score {
        let contextualPool = fresh.filter { $0.score >= bestScore - 2.0 }
        if !contextualPool.isEmpty {
            return contextualPool.randomElement()
        }
    }
    guard allowStaleFallback else { return nil }
    return candidates.first { candidate in
        !history.keptAssetIdentifiers.contains(candidate.assetLocalIdentifier)
            && !history.dismissedAssetIdentifiers.contains(candidate.assetLocalIdentifier)
    }
}

extension PhotoAnalysis {
    static func contextualPreview(context: PhotoIlluminationContext) -> PhotoAnalysis {
        let weather = context.weatherText.lowercased()
        let tags = context.themeTags.map { $0.lowercased() }
        let template: IlluminatedTemplateID
        let stamp: String
        if weather.contains("rain") || weather.contains("storm") || weather.contains("snow") {
            template = .academyFieldStudy
            stamp = "Weather Evidence"
        } else if tags.contains(where: { $0.contains("compass") || $0.contains("adventure") }) {
            template = .harborFieldNote
            stamp = "Compass Record"
        } else {
            template = .academyFieldStudy
            stamp = "Field Study"
        }
        return PhotoAnalysisValidator.validate(PhotoAnalysis(
            scene: "A photograph from \(context.season) waits in the \(context.timeOfDay) margins.",
            motifs: [context.season, context.timeOfDay, "memory", "detail"],
            mood: "timely and kept",
            suggestedTemplate: template,
            marginalia: PhotoMarginalia(
                fieldNote: "The present called this page forward.",
                stampLabel: stamp,
                observationList: [
                    "Chosen for this hour",
                    "Season answering season",
                    "A place worth returning to",
                    "The ordinary held still",
                    "No oracle consulted"
                ],
                closingLine: "The Book opened a margin around this moment."
            ),
            souvenirCandidates: [
                "This moment returned because the present recognized it.",
                "The season found an earlier page still carrying its light."
            ]
        ))
    }
}
#endif

struct AppBraider: Braider {
    let local: Braider
    private let fallback = FakeBraider()

    func braid(day: BookDay) async throws -> BookPage {
        try await braid(day: day, context: .empty)
    }

    func braid(day: BookDay, context: BraidPromptBuilder.Context) async throws -> BookPage {
        do {
            return try await local.braid(day: day, context: context)
        } catch {
            appLog.error("Local braid fell back: \(error.localizedDescription, privacy: .public)")
            var page = try await fallback.braid(day: day)
            page.promptText = "The local brain dropped its pencil. The Book kept the page safe."
            page.tags.append("local-model-fallback")
            return page
        }
    }
}

struct AppWonderCompassChooser: WonderCompassPassageChoosing {
    let local: WonderCompassPassageChoosing
    private let fallback = FakeWonderCompassChooser()

    func chooseWonderCompassSnippet(
        day: BookDay,
        inputs: BookSourceInputs,
        candidates: [ReferenceSnippet]
    ) async throws -> ReferenceSnippet {
        do {
            return try await local.chooseWonderCompassSnippet(day: day, inputs: inputs, candidates: candidates)
        } catch {
            appLog.error("Wonder Compass selection fell back: \(error.localizedDescription, privacy: .public)")
            return try await fallback.chooseWonderCompassSnippet(day: day, inputs: inputs, candidates: candidates)
        }
    }
}

struct AppWeatherEnchanter: WeatherEnchanting {
    let local: WeatherEnchanting

    func enchantWeather(weather: WeatherSourceSignal, day: BookDay) async throws -> EnchantedWeatherSignal {
        try await local.enchantWeather(weather: weather, day: day)
    }
}

struct RealInterestGossipClipping: Equatable {
    var interest: String
    var fact: String
    var sourceName: String
    var sourceURL: String

    var promptLine: String {
        "\(interest): \(fact) [\(sourceName)]"
    }
}

struct WebSearchFallback {
    private struct LiteResult {
        var title: String
        var snippet: String
        var url: String
    }

    func clipping(for interest: String) async -> RealInterestGossipClipping? {
        (await clippings(for: interest, limit: 1)).first
    }

    func clippings(for interest: String, limit: Int = 2) async -> [RealInterestGossipClipping] {
        guard limit > 0,
              let results = try? await duckDuckGoLiteResults(for: interest),
              !results.isEmpty else {
            return []
        }
        return results.prefix(limit).map { result in
            RealInterestGossipClipping(
                interest: interest,
                fact: "\(result.title). \(result.snippet)".bookPreviewSentenceLimit(2),
                sourceName: "DuckDuckGo Lite",
                sourceURL: result.url
            )
        }
    }

    private func duckDuckGoLiteResults(for query: String) async throws -> [LiteResult] {
        var components = URLComponents(string: "https://lite.duckduckgo.com/lite/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 ReEnchanted/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return []
        }
        return parseDuckDuckGoLite(html: html)
    }

    private func parseDuckDuckGoLite(html: String) -> [LiteResult] {
        let pattern = #"<a rel="nofollow" href="([^"]+)" class='result-link'>(.*?)</a>[\s\S]*?<td class='result-snippet'>\s*(.*?)\s*</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 4,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html),
                  let snippetRange = Range(match.range(at: 3), in: html) else {
                return nil
            }
            let url = resolvedDuckDuckGoRedirect(String(html[hrefRange]).htmlEntityDecoded)
            let title = String(html[titleRange]).strippingHTML.htmlEntityDecoded
            let snippet = String(html[snippetRange]).strippingHTML.htmlEntityDecoded
            guard let cleanTitle = title.nonEmpty,
                  let cleanSnippet = snippet.nonEmpty,
                  let cleanURL = url.nonEmpty else {
                return nil
            }
            return LiteResult(title: cleanTitle, snippet: cleanSnippet, url: cleanURL)
        }
    }

    private func resolvedDuckDuckGoRedirect(_ href: String) -> String {
        let absolute = href.hasPrefix("//") ? "https:\(href)" : href
        guard let components = URLComponents(string: absolute),
              let uddg = components.queryItems?.first(where: { $0.name == "uddg" })?.value?.nonEmpty else {
            return absolute
        }
        return uddg
    }
}

struct RealInterestGossipSearcher {
    private struct DuckDuckGoResponse: Decodable {
        var abstractText: String?
        var abstractURL: String?
        var heading: String?
        var relatedTopics: [RelatedTopic]?

        enum CodingKeys: String, CodingKey {
            case abstractText = "AbstractText"
            case abstractURL = "AbstractURL"
            case heading = "Heading"
            case relatedTopics = "RelatedTopics"
        }
    }

    private struct RelatedTopic: Decodable {
        var text: String?
        var firstURL: String?
        var topics: [RelatedTopic]?

        enum CodingKeys: String, CodingKey {
            case text = "Text"
            case firstURL = "FirstURL"
            case topics = "Topics"
        }
    }

    func clippings(from facts: [SelfFact], dayID: String, slotID: String) async -> [RealInterestGossipClipping] {
        let interests = selectedInterests(from: facts, dayID: dayID, slotID: slotID)
        var clippings: [RealInterestGossipClipping] = []
        for interest in interests {
            guard let clipping = try? await search(interest: interest) else { continue }
            clippings.append(clipping)
            if clippings.count >= 2 { break }
        }
        return clippings
    }

    func clippings(for interests: [String], limit: Int = 2) async -> [RealInterestGossipClipping] {
        var clippings: [RealInterestGossipClipping] = []
        for interest in interests where !interest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let clipping = try? await search(interest: interest) else { continue }
            clippings.append(clipping)
            if clippings.count >= limit { break }
        }
        return clippings
    }

    private func selectedInterests(from facts: [SelfFact], dayID: String, slotID: String) -> [String] {
        let candidates = facts
            .filter { fact in
                fact.questionID.hasPrefix("interest-")
                    && fact.usePermission != .doNotUse
                    && !fact.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .flatMap { fact in
                splitInterests(fact.answer)
            }
            .reduce(into: [String]()) { unique, interest in
                if !unique.contains(where: { $0.localizedCaseInsensitiveCompare(interest) == .orderedSame }) {
                    unique.append(interest)
                }
            }
        guard !candidates.isEmpty else { return [] }
        return candidates
            .sorted { left, right in
                stableIndex(for: "\(dayID)-\(slotID)-\(left)", count: 10_000)
                    < stableIndex(for: "\(dayID)-\(slotID)-\(right)", count: 10_000)
            }
            .prefix(4)
            .map(\.self)
    }

    private func splitInterests(_ answer: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        return answer
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 3 && $0.count <= 80 }
    }

    private func search(interest: String) async throws -> RealInterestGossipClipping? {
        var components = URLComponents(string: "https://api.duckduckgo.com/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: interest),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_redirect", value: "1"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("ReEnchanted/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let decoded = try JSONDecoder().decode(DuckDuckGoResponse.self, from: data)
        let sourceURL = decoded.abstractURL?.nonEmpty
            ?? decoded.relatedTopics?.compactMap(\.firstURL).first?.nonEmpty
            ?? "https://duckduckgo.com/?q=\(interest.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? interest)"
        let sourceName = decoded.heading?.nonEmpty ?? "DuckDuckGo"
        let fact = decoded.abstractText?.nonEmpty
            ?? decoded.relatedTopics?.flatMap { flatten($0) }.compactMap(\.text).first?.nonEmpty
        guard let fact else {
            return await WebSearchFallback().clipping(for: interest)
        }
        return RealInterestGossipClipping(
            interest: interest,
            fact: fact.bookPreviewSentenceLimit(2),
            sourceName: sourceName,
            sourceURL: sourceURL
        )
    }

    private func flatten(_ topic: RelatedTopic) -> [RelatedTopic] {
        [topic] + (topic.topics ?? []).flatMap(flatten)
    }

    private func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct ScholarlyFacultyResearcher {
    private struct PubMedSearchResponse: Decodable {
        var esearchresult: SearchResult

        struct SearchResult: Decodable {
            var idlist: [String]
        }
    }

    private struct PubMedSummaryResponse: Decodable {
        var result: [String: PubMedSummaryValue]

        private enum CodingKeys: String, CodingKey {
            case result
        }

        private struct DynamicKey: CodingKey {
            var stringValue: String
            var intValue: Int?

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue: Int) {
                self.stringValue = "\(intValue)"
                self.intValue = intValue
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let resultContainer = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: .result)
            var papers: [String: PubMedSummaryValue] = [:]
            for key in resultContainer.allKeys where key.stringValue != "uids" {
                if let value = try? resultContainer.decode(PubMedSummaryValue.self, forKey: key) {
                    papers[key.stringValue] = value
                }
            }
            result = papers
        }
    }

    private struct PubMedSummaryValue: Decodable {
        var uid: String?
        var title: String?
        var fulljournalname: String?
        var pubdate: String?
        var elocationid: String?
    }

    private struct SemanticScholarResponse: Decodable {
        var data: [Paper]

        struct Paper: Decodable {
            var title: String?
            var abstract: String?
            var year: Int?
            var venue: String?
            var url: String?
            var externalIds: ExternalIDs?
        }

        struct ExternalIDs: Decodable {
            var DOI: String?
        }
    }

    private struct OpenAlexResponse: Decodable {
        var results: [Work]

        struct Work: Decodable {
            var displayName: String?
            var publicationYear: Int?
            var primaryLocation: Location?
            var doi: String?
            var id: String?

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case publicationYear = "publication_year"
                case primaryLocation = "primary_location"
                case doi
                case id
            }
        }

        struct Location: Decodable {
            var source: Source?
            var landingPageURL: String?

            enum CodingKeys: String, CodingKey {
                case source
                case landingPageURL = "landing_page_url"
            }
        }

        struct Source: Decodable {
            var displayName: String?

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
            }
        }
    }

    func clippings(for queries: [String], facultyID: String, limit: Int = 3) async -> [RealInterestGossipClipping] {
        let cleaned = queries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return [] }

        var clippings: [RealInterestGossipClipping] = []
        for query in cleaned {
            let result: RealInterestGossipClipping?
            if facultyID == "dr-vellum" {
                result = try? await pubMedClipping(for: query)
            } else {
                if let semanticScholar = try? await semanticScholarClipping(for: query) {
                    result = semanticScholar
                } else {
                    result = try? await openAlexClipping(for: query)
                }
            }
            if let result, !containsDuplicate(result, in: clippings) {
                clippings.append(result)
            }
            if clippings.count >= limit { return clippings }
        }

        let fallback = await RealInterestGossipSearcher().clippings(for: cleaned, limit: limit - clippings.count)
        for clipping in fallback where !containsDuplicate(clipping, in: clippings) {
            clippings.append(clipping)
            if clippings.count >= limit { break }
        }
        if clippings.count < limit {
            for query in cleaned {
                let fallback = await WebSearchFallback().clippings(for: query, limit: limit - clippings.count)
                for clipping in fallback where !containsDuplicate(clipping, in: clippings) {
                    clippings.append(clipping)
                    if clippings.count >= limit { break }
                }
                if clippings.count >= limit { break }
            }
        }
        return clippings
    }

    private func pubMedClipping(for query: String) async throws -> RealInterestGossipClipping? {
        var searchComponents = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi")!
        searchComponents.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: "\(query) randomized OR review OR cohort"),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "retmax", value: "4"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "tool", value: "ReEnchantifyInsideCover")
        ]
        guard let searchURL = searchComponents.url else { return nil }
        let searchData = try await fetch(searchURL)
        let search = try JSONDecoder().decode(PubMedSearchResponse.self, from: searchData)
        guard let firstID = search.esearchresult.idlist.first else { return nil }

        var summaryComponents = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi")!
        summaryComponents.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: firstID),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "tool", value: "ReEnchantifyInsideCover")
        ]
        guard let summaryURL = summaryComponents.url else { return nil }
        let summaryData = try await fetch(summaryURL)
        let summary = try JSONDecoder().decode(PubMedSummaryResponse.self, from: summaryData)
        guard let paper = summary.result[firstID],
              let title = paper.title?.nonEmpty else {
            return nil
        }

        let journal = paper.fulljournalname?.nonEmpty ?? "PubMed"
        let date = paper.pubdate?.nonEmpty.map { " (\($0))" } ?? ""
        let locator = paper.elocationid?.nonEmpty.map { " \($0)" } ?? ""
        return RealInterestGossipClipping(
            interest: query,
            fact: "\(title)\(date). \(journal).\(locator)".bookPreviewSentenceLimit(2),
            sourceName: "PubMed",
            sourceURL: "https://pubmed.ncbi.nlm.nih.gov/\(firstID)/"
        )
    }

    private func semanticScholarClipping(for query: String) async throws -> RealInterestGossipClipping? {
        var components = URLComponents(string: "https://api.semanticscholar.org/graph/v1/paper/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "4"),
            URLQueryItem(name: "fields", value: "title,abstract,year,venue,url,externalIds")
        ]
        guard let url = components.url else { return nil }
        let data = try await fetch(url)
        let response = try JSONDecoder().decode(SemanticScholarResponse.self, from: data)
        guard let paper = response.data.first(where: { $0.title?.nonEmpty != nil }),
              let title = paper.title?.nonEmpty else {
            return nil
        }

        let venue = paper.venue?.nonEmpty ?? "Semantic Scholar"
        let year = paper.year.map { " (\($0))" } ?? ""
        let abstract = paper.abstract?.nonEmpty.map { " \($0.bookPreviewSentenceLimit(1))" } ?? ""
        let doiURL = paper.externalIds?.DOI?.nonEmpty.map { "https://doi.org/\($0)" }
        return RealInterestGossipClipping(
            interest: query,
            fact: "\(title)\(year). \(venue).\(abstract)".bookPreviewSentenceLimit(2),
            sourceName: "Semantic Scholar",
            sourceURL: paper.url?.nonEmpty ?? doiURL ?? "https://www.semanticscholar.org/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        )
    }

    private func openAlexClipping(for query: String) async throws -> RealInterestGossipClipping? {
        var components = URLComponents(string: "https://api.openalex.org/works")!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "per-page", value: "4"),
            URLQueryItem(name: "select", value: "display_name,publication_year,primary_location,doi,id")
        ]
        guard let url = components.url else { return nil }
        let data = try await fetch(url)
        let response = try JSONDecoder().decode(OpenAlexResponse.self, from: data)
        guard let work = response.results.first(where: { $0.displayName?.nonEmpty != nil }),
              let title = work.displayName?.nonEmpty else {
            return nil
        }

        let venue = work.primaryLocation?.source?.displayName?.nonEmpty ?? "OpenAlex"
        let year = work.publicationYear.map { " (\($0))" } ?? ""
        let sourceURL = work.primaryLocation?.landingPageURL?.nonEmpty
            ?? work.doi?.nonEmpty
            ?? work.id?.nonEmpty
            ?? "https://openalex.org/works?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        return RealInterestGossipClipping(
            interest: query,
            fact: "\(title)\(year). \(venue).".bookPreviewSentenceLimit(2),
            sourceName: "OpenAlex",
            sourceURL: sourceURL
        )
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("ReEnchantify/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func containsDuplicate(_ clipping: RealInterestGossipClipping, in clippings: [RealInterestGossipClipping]) -> Bool {
        clippings.contains { existing in
            existing.sourceURL == clipping.sourceURL
                || existing.fact.localizedCaseInsensitiveCompare(clipping.fact) == .orderedSame
        }
    }
}

extension SurfacePage {
    func withRealInterestGossip(_ clippings: [RealInterestGossipClipping]) -> SurfacePage {
        guard !clippings.isEmpty else { return self }
        let clippingLines = clippings.map { clipping in
            "- \(clipping.promptLine)"
        }.joined(separator: "\n")
        let sourceLines = clippings.map { clipping in
            "\(clipping.interest): \(clipping.sourceURL)"
        }.joined(separator: "\n")
        var metadata = payload.metadata
        metadata["realInterestClippings"] = clippingLines
        metadata["realInterestSources"] = sourceLines
        metadata["realInterestCount"] = "\(clippings.count)"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: min(score + clippings.count * 4, 96),
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: payload.body,
                metadata: metadata
            )
        )
    }

    func withFacultyResearchClippings(_ clippings: [RealInterestGossipClipping]) -> SurfacePage {
        guard !clippings.isEmpty else { return self }
        let clippingLines = clippings.map { "- \($0.promptLine)" }.joined(separator: "\n")
        let sourceLines = clippings.map { "\($0.interest): \($0.sourceURL)" }.joined(separator: "\n")
        var metadata = payload.metadata
        metadata["researchClippings"] = clippingLines
        metadata["researchSources"] = sourceLines
        metadata["researchClippingCount"] = "\(clippings.count)"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: min(score + clippings.count * 5, 98),
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: "\(payload.body)\n\nLive research clippings:\n\(clippingLines)",
                metadata: metadata
            )
        )
    }

    func withLetterResearchClippings(_ clippings: [RealInterestGossipClipping]) -> SurfacePage {
        guard !clippings.isEmpty else { return self }
        let clippingLines = clippings.map { "- \($0.promptLine)" }.joined(separator: "\n")
        let sourceLines = clippings.map { "\($0.interest): \($0.sourceURL)" }.joined(separator: "\n")
        var metadata = payload.metadata
        metadata["letterResearchClippings"] = clippingLines
        metadata["letterResearchSources"] = sourceLines
        metadata["letterResearchCount"] = "\(clippings.count)"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: min(score + clippings.count * 5, 98),
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: "\(payload.body)\n\nLive web research clippings:\n\(clippingLines)",
                metadata: metadata
            )
        )
    }

    func preparedStoryPageCopy(prose: StoryPageProse, slotID: String) -> SurfacePage {
        var metadata = payload.metadata
        metadata["slotID"] = slotID
        metadata["storyScene"] = prose.scene
        metadata["storyWriter"] = prose.source
        metadata["storyResultSliceOfLife"] = prose.results["sliceoflife"] ?? ""
        metadata["storyResultProgressArc"] = prose.results["progressarc"] ?? ""
        metadata["storyResultSurprise"] = prose.results["surprise"] ?? ""
        for choice in prose.choices {
            let prefix: String
            switch choice.id {
            case "sliceoflife":
                prefix = "storyChoiceSliceOfLife"
            case "progressarc":
                prefix = "storyChoiceProgressArc"
            case "surprise":
                prefix = "storyChoiceSurprise"
            default:
                continue
            }
            metadata["\(prefix)Title"] = StoryPageCopySanitizer.choiceTitle(choice.title)
            metadata["\(prefix)Prompt"] = StoryPageCopySanitizer.choicePrompt(choice.prompt)
            metadata["\(prefix)Effect"] = StoryPageCopySanitizer.choicePrompt(choice.effectLine)
            metadata["\(prefix)Mechanic"] = choice.mechanic.kind.rawValue
            if let enchantmentID = choice.mechanic.enchantmentID {
                metadata["\(prefix)EnchantmentID"] = enchantmentID
                metadata["\(prefix)EnchantmentName"] = StoryEnchantmentCatalog.spell(id: enchantmentID)?.title
            }
        }
        metadata["proseStatus"] = prose.source == "gemma" ? "gemma" : prose.source
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: prose.scene.bookPreviewSentenceLimit(2),
                metadata: metadata
            )
        )
    }

    func preparedGossipPageCopy(prose: String, slotID: String) -> SurfacePage {
        var metadata = payload.metadata
        metadata["slotID"] = slotID
        metadata["gossipProse"] = prose
        metadata["proseStatus"] = "generated"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: prose,
                metadata: metadata
            )
        )
    }

    func preparedFacultyResearchCopy(prose: String, slotID: String) -> SurfacePage {
        var metadata = payload.metadata
        metadata["slotID"] = slotID
        metadata["researchProse"] = prose
        metadata["proseStatus"] = "generated"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: prose,
                metadata: metadata
            )
        )
    }

    func enchantedWeatherCopy(_ signal: EnchantedWeatherSignal, weather: WeatherSourceSignal) -> SurfacePage {
        let rawParts = [
            weather.currentTemperature.map { "Now: \($0)" },
            weather.forecast.map { "Forecast: \($0)" }
        ].compactMap(\.self)
        let rawLine = rawParts.isEmpty ? weather.phrase : rawParts.joined(separator: " | ")
        var metadata = payload.metadata
        metadata["selector"] = signal.selector
        metadata["symbol"] = signal.symbolName
        metadata["rawWeather"] = weather.phrase
        return SurfacePage(
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: rawLine,
            payload: BookPagePayload(
                headline: payload.headline,
                body: "\(signal.enchantified)\n\nWeather: \(rawLine)",
                metadata: metadata
            )
        )
    }

    func storyContinuationCopy(context: StoryPageContinuationContext) -> SurfacePage {
        var metadata = payload.metadata
        metadata["storyContinuationContext"] = context.promptContext
        metadata["storyTurnCount"] = "\(context.turns.count + 1)"
        metadata.removeValue(forKey: "storyScene")
        metadata.removeValue(forKey: "storyResultSliceOfLife")
        metadata.removeValue(forKey: "storyResultProgressArc")
        metadata.removeValue(forKey: "storyResultSurprise")
        metadata["storyMechanicMandateKind"] = StoryPageMechanicMandateKind.none.rawValue
        metadata.removeValue(forKey: "storyMechanicMandateChoiceID")
        metadata.removeValue(forKey: "storyMechanicMandateEnchantmentID")
        metadata["storyMechanicMandateReason"] = StoryPageMechanicMandate.none.reason
        metadata["proseStatus"] = "continuing"
        return SurfacePage(
            id: "\(id)-continued-\(context.turns.count + 1)",
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: payload.body,
                metadata: metadata
            )
        )
    }

    func preparedLetterCopy(prose: String, slotID: String) -> SurfacePage {
        var metadata = payload.metadata
        metadata["slotID"] = slotID
        metadata["letterProse"] = prose
        metadata["proseStatus"] = "generated"
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: prose,
                metadata: metadata
            )
        )
    }
}

enum StoryPageCopySanitizer {
    static func choiceTitle(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: #"\b(SLICE_OF_LIFE|PROGRESS_ARC|SURPRISE)\s*:?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b(Slice of Life|Progress Arc|Surprise)\s*:?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' :.-!?"))
        return stripped.removingImmediateDuplicatePhrase().singleLineForStoryCopy(maxLength: 42) ?? raw.singleLineForStoryCopy(maxLength: 42) ?? raw
    }

    static func choicePrompt(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"\b(SLICE_OF_LIFE|PROGRESS_ARC|SURPRISE)_?(CHOICE|PROMPT|MECHANIC)?\s*:?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b(Slice of Life|Progress Arc|Surprise) (Choice|Prompt|Mechanic)\s*:?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' :"))
            .removingImmediateDuplicatePhrase()
            .singleLineForStoryCopy(maxLength: 120) ?? raw
    }
}

private extension String {
    func singleLineForStoryCopy(maxLength: Int) -> String? {
        let cleaned = components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= maxLength { return cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: maxLength)
        return String(cleaned[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func removingImmediateDuplicatePhrase() -> String {
        let separators = [". ", "! ", "? "]
        for separator in separators {
            let parts = components(separatedBy: separator)
            guard parts.count == 2 else { continue }
            let left = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let right = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if left.localizedCaseInsensitiveCompare(right) == .orderedSame {
                return left
            }
        }

        let words = split(separator: " ").map(String.init)
        guard words.count.isMultiple(of: 2), words.count >= 4 else { return self }
        let midpoint = words.count / 2
        let first = words[..<midpoint].joined(separator: " ")
        let second = words[midpoint...].joined(separator: " ")
        if first.localizedCaseInsensitiveCompare(second) == .orderedSame {
            return first
        }
        return self
    }
}

// MARK: - The single seam between pages and the local brain.
//
// Every prose-shaped generation goes through LocalBrainProse; this is the
// only place outside the MLX block that knows whether a native brain exists
// in this build. Callers get prose or nil — never an #if.
/// Braid instructions live outside the device-only MLX block so the
/// self-improvement path (taste notes, rewrites) can reference them on any
/// build, not just on-device.
enum BraidInstructions {
    static let bookOfYou = """
    You are The Book inside ReEnchanted. You braid kept private real-life pages into a grounded, literary Book of You entry.
    Use only the supplied kept pages. Do not diagnose, moralize, invent completed actions, or speak as a generic assistant.
    Write a small narrative with a beginning, a turn, and a landing. Do not list. Do not copy long phrases back verbatim.
    Keep the braid to 4 to 7 paragraphs, about 280 to 450 words. It should feel like a full page of the Book without becoming a scroll chore.
    Mention each motif, image, sentence idea, or emotional beat only once.
    Do not restate the same idea in consecutive paragraphs with swapped words.
    Keep it warm, vivid, playful, and true.
    Prose standard: varied literary cadence. Mix short, surprising, concrete sentences with longer, flowing sentences that turn once or twice before landing. Use specific nouns and verbs, one exact physical detail per paragraph, and a voice that feels intimate, lucid, playful, and plainspoken rather than clipped. No vague wonder, generic inspiration, journey, profound, tapestry, echoes, or abstract emotional summary.
    Style compass: contemporary literary fantasy with dark playfulness, lucid sentences, concrete ordinary objects made strange, a storyteller's sideways humor, and endings that land softly but sharply.
    """
}

/// The currently-tuned station's atmosphere line, read from the live vault, for
/// coloring any generated narrative page. Nil when the radio is off.
enum RadioAtmosphereContext {
    static var current: String? {
        RadioStationRegistry.atmosphereLine(
            state: PlayerVault.shared.data.radio ?? .off,
            unlockedPackIDs: Set(PlayerVault.shared.data.ownedPacks ?? [])
        )
    }
}

enum LocalBrainProse {
    static func write(
        prompt: String,
        instructions: String,
        maxTokens: Int,
        sourceID: String,
        tags: [String]
    ) async -> String? {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
        guard LocalModelManager.report().state == .ready else { return nil }
        let response = try? await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: instructions,
            maxTokens: maxTokens,
            sourceID: sourceID,
            tags: tags
        )
        return response?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        #else
        return nil
        #endif
    }
}

struct CharacterLetterWriter {
    func write(surface: SurfacePage) async -> String {
        let prompt = prompt(for: surface)
        if let response = await LocalBrainProse.write(
            prompt: prompt,
            instructions: """
            You are writing an in-world NPC letter for ReEnchanted.
            Write as the named sender, not as an assistant. Use the sender's writing voice, memories, and narrative context.
            Use live web research clippings when supplied, especially details connected to the player's actual home context.
            If no live clippings are supplied, fall back to your own general knowledge, but do not pretend you browsed or cite fake sources.
            Do not invent completed real-world actions by the player. Do not diagnose, prescribe, or moralize.
            Format as a real letter: greeting, 3-6 short paragraphs, signoff from the sender, optional P.S. if it fits the voice.
            """,
            maxTokens: 620,
            sourceID: "letter-page",
            tags: ["letter", "character-letter"]
        ) {
            return response
        }
        return fallback(surface: surface)
    }

    private func prompt(for surface: SurfacePage) -> String {
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        let interest = surface.payload.metadata["unwrittenInterest"] ?? "ordinary wonder"
        let homeContext = surface.payload.metadata["homeContext"] ?? "the player's home"
        let relationshipStage = surface.payload.metadata["letterRelationshipStage"]?.nonEmpty ?? "continuing"
        let occasion = surface.payload.metadata["letterOccasion"]?.nonEmpty ?? "No special occasion."
        let relationshipInstruction = relationshipStage == "introduction"
            ? "This is the sender's first letter to the player. Make it an introduction letter first: establish who the sender is, what they care about, and why they are writing now. Do not assume a prior friendship or shared history."
            : "This sender has written before. Build from existing relationship context when it is present; do not reintroduce them as if they are new."
        let clippings = surface.payload.metadata["letterResearchClippings"]?.nonEmpty
            ?? surface.payload.metadata["realInterestClippings"]?.nonEmpty
            ?? "No live web clippings were available. Use model knowledge carefully and say things generally."
        let sources = surface.payload.metadata["letterResearchSources"]?.nonEmpty ?? "No source URLs."
        return """
        Sender: \(sender)
        Address the player as: \(playerName)
        Unwritten Interest: \(interest)
        Player home context: \(homeContext)
        Letter relationship stage: \(relationshipStage)
        Letter occasion: \(occasion)
        Relationship instruction: \(relationshipInstruction)

        Draft packet:
        \(surface.payload.body)

        Live web research clippings:
        \(clippings)

        Research source URLs:
        \(sources)

        Write the finished letter. It should feel researched, personal, and specific to the sender. Blend real-world facts with the sender's voice and relationship to the player. For an introduction-stage letter, introduce before escalating: no callbacks, no assumed intimacy, no urgent plot demand. Start with a greeting that uses "\(playerName)" exactly. Never write "[Player Name]".
        """
    }

    private func fallback(surface: SurfacePage) -> String {
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        let interest = surface.payload.metadata["unwrittenInterest"] ?? "ordinary wonder"
        let home = surface.payload.metadata["homeContext"] ?? "your home"
        let clippings = surface.payload.metadata["letterResearchClippings"]?.nonEmpty
        let researchLine = clippings.map { "I found this in the public stacks:\n\($0)" }
            ?? "The public stacks did not answer in time, so I am leaning on what I already know."
        if surface.payload.metadata["letterRelationshipStage"] == "introduction" {
            return """
            Dear \(playerName),

            I should introduce myself before I start leaving folded paper in your margins. I am \(sender), and I pay attention to \(interest) because it has a way of making ordinary places answer back.

            I went looking for the shape of that interest near \(home). \(researchLine)

            You do not owe me a dramatic reply. For a first letter, I only wanted you to know the kind of thing I notice, and why your corner of the world has begun to matter to me.

            Yours from the margins,
            \(sender)
            """
        }
        return """
        Dear \(playerName),

        I went looking for \(interest), especially where it brushes against \(home). \(researchLine)

        What interested me was not the grand theory, but the way a subject changes when it has to pass through a real doorway. A fact becomes different when it has weather on it, errands near it, and one person deciding whether to notice.

        Keep this near the day, not above it. If \(interest) is a door, then your ordinary place is one of its hinges.

        Yours from the margins,
        \(sender)
        """
    }
}

struct PlayfulMissionWriter {
    func mission(from surface: SurfacePage) async -> PlayfulMission {
        let fallback = fallbackMission(from: surface)
        guard let response = await LocalBrainProse.write(
            prompt: prompt(for: surface),
            instructions: """
            You are The Wonder Compass inside ReEnchanted. Generate one tiny Playful Mission for South = Sense. Return compact strict JSON only.
            """,
            maxTokens: 240,
            sourceID: "wonder-compass-playful-mission",
            tags: ["wonder-compass", "playful-mission", "custom"]
        ), let raw = JSONSalvage.dictionary(from: response) else {
            return fallback
        }

        let title = compactLine(JSONSalvage.string("title", in: raw), limit: 44)?.trimmingCharacters(in: CharacterSet(charactersIn: ".!? ")) ?? fallback.title
        let prompt = compactLine(JSONSalvage.string("prompt", in: raw), limit: 180) ?? fallback.prompt
        let proofPrompt = compactLine(JSONSalvage.string("proofPrompt", in: raw), limit: 120) ?? fallback.proofPrompt
        let tags = JSONSalvage.string("tags", in: raw)?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            ?? fallback.tags
        let allowsPhoto = JSONSalvage.string("allowsPhoto", in: raw).map { value in
            !["false", "no", "sentence"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        } ?? fallback.allowsPhoto

        return PlayfulMission(
            id: "custom-\(abs("\(title)-\(prompt)".stableHash))",
            title: title,
            prompt: prompt,
            proofPrompt: proofPrompt,
            tags: Array(Set(tags + ["custom"])).sorted(),
            allowsPhoto: allowsPhoto
        )
    }

    private func prompt(for surface: SurfacePage) -> String {
        let currentMission = surface.payload.metadata["mission"] ?? surface.detail
        let currentTags = surface.payload.metadata["tags"] ?? "none"
        return """
        Generate one custom Playful Mission for the Wonder Compass South = Sense step.

        Current page:
        Title: \(surface.payload.metadata["playfulMissionTitle"] ?? surface.prompt)
        Mission: \(currentMission)
        Tags: \(currentTags)

        Authoring grammar:
        - Aim at the world or the body, never at self-analysis. Use find, track, press, count, follow, taste, listen, touch, compare, or report.
        - The answer must be concrete: a noun, a number, a sound, a temperature, a location, or a verdict.
        - Completable in under three minutes.
        - Include a pinch of premise: objects wait, rooms have moods, buildings have days, light performs, bodies report.
        - End with a small surprise, reversal, verdict, or smile.
        - Do not ask for planning, journaling, therapy, productivity, or belief.
        - Do not claim the player completed anything.

        Return JSON exactly:
        {"title":"2-5 word title","prompt":"one mission sentence or two short sentences","proofPrompt":"one concrete capture prompt","tags":"comma,separated,tags","allowsPhoto":"true or false"}
        """
    }

    private func compactLine(_ text: String?, limit: Int) -> String? {
        let cleaned = text?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        guard let cleaned, !cleaned.isEmpty else { return nil }
        guard cleaned.count > limit else { return cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: limit)
        return String(cleaned[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func fallbackMission(from surface: SurfacePage) -> PlayfulMission {
        let seed = abs("\(surface.id)-custom-playful-mission".stableHash)
        let templates: [PlayfulMission] = [
            PlayfulMission(
                id: "custom-fallback-room-voice-\(seed)",
                title: "Room Voice",
                prompt: "Find the smallest sound in the room and decide what job it has been doing without thanks.",
                proofPrompt: "Write the sound and its job.",
                tags: ["custom", "sound", "inside", "low-energy"],
                allowsPhoto: false
            ),
            PlayfulMission(
                id: "custom-fallback-light-verdict-\(seed)",
                title: "Light Verdict",
                prompt: "Find one patch of light and decide whether it is arriving, leaving, hiding, or showing off.",
                proofPrompt: "Write the light's verdict.",
                tags: ["custom", "light", "visual", "inside"],
                allowsPhoto: true
            ),
            PlayfulMission(
                id: "custom-fallback-object-job-\(seed)",
                title: "Exact Job",
                prompt: "Pick one object within reach and name the exact job it is doing for the world right now.",
                proofPrompt: "Write the object and its exact job.",
                tags: ["custom", "object", "touch", "inside"],
                allowsPhoto: true
            )
        ]
        return templates[seed % templates.count]
    }
}

struct ElectiveOfferWriter {
    func offer(surface: SurfacePage) async -> ElectiveOfferDraft {
        let fallback = ElectiveOfferFallback.offer(surface: surface)
        guard let response = await LocalBrainProse.write(
            prompt: LocalModelManager.electiveOfferPrompt(surface: surface),
            instructions: """
            You are a character in ReEnchanted asking the player a small real-world favor. Return compact strict JSON only.
            """,
            maxTokens: 460,
            sourceID: "unwritten-elective",
            tags: ["elective", "offer"]
        ), let raw = JSONSalvage.dictionary(from: response) else {
            return fallback
        }
        return ElectiveOfferDraft(
            title: JSONSalvage.string("title", in: raw) ?? fallback.title,
            ask: JSONSalvage.string("ask", in: raw) ?? fallback.ask,
            whyItMatters: JSONSalvage.string("whyItMatters", in: raw) ?? fallback.whyItMatters,
            practiceShape: JSONSalvage.string("practiceShape", in: raw) ?? fallback.practiceShape
        )
    }
}

/// Room generation through the engine, falling back to the offline writer —
/// anchoring works in every build, model or no model.
struct OuterStacksRoomEngine: OuterStacksRoomWriting {
    func room(
        anchorName: String,
        playerWords: String,
        kind: AnchorKind,
        weather: String,
        moon: String,
        season: String,
        belief: Int
    ) async throws -> OuterStacksRoomSpec {
        let fallback = try await FakeOuterStacksRoomWriter().room(
            anchorName: anchorName, playerWords: playerWords, kind: kind,
            weather: weather, moon: moon, season: season, belief: belief
        )
        guard let response = await LocalBrainProse.write(
            prompt: LocalModelManager.outerStacksRoomPrompt(
                anchorName: anchorName, playerWords: playerWords, kind: kind,
                weather: weather, moon: moon, season: season, belief: belief
            ),
            instructions: """
            You are the Labyrinth of Stories building Outer Stacks rooms. Return compact strict JSON only.
            """,
            maxTokens: 520,
            sourceID: "outer-stacks-anchor",
            tags: ["outer-stacks", "anchor", "room-generation"]
        ), let raw = JSONSalvage.dictionary(from: response) else {
            return fallback
        }
        return OuterStacksRoomSpec(
            roomDescription: JSONSalvage.string("roomDescription", in: raw) ?? fallback.roomDescription,
            academyEcho: JSONSalvage.string("academyEcho", in: raw) ?? fallback.academyEcho,
            fae: JSONSalvage.string("fae", in: raw) ?? fallback.fae,
            miniStory: JSONSalvage.string("miniStory", in: raw) ?? fallback.miniStory,
            localRule: JSONSalvage.string("localRule", in: raw) ?? fallback.localRule
        )
    }

    func visitScene(anchor: AnchorRecord, visitCount: Int, day: BookDay, memory: String) async throws -> String {
        if let prose = await LocalBrainProse.write(
            prompt: LocalModelManager.outerStacksVisitPrompt(anchor: anchor, visitCount: visitCount, day: day, memory: memory),
            instructions: """
            You are the Labyrinth of Stories narrating an Outer Stacks visit. Write prose only, no JSON, no headings, no labeled sections.
            """,
            maxTokens: 560,
            sourceID: "outer-stacks-anchor",
            tags: ["outer-stacks", "anchor", "visit"]
        ), !prose.hasPrefix("{") {
            return prose
        }
        return try await FakeOuterStacksRoomWriter().visitScene(anchor: anchor, visitCount: visitCount, day: day, memory: memory)
    }
}

// MARK: - The Bleed press room

enum RedditSourceAccount {
    static let clientIDStorageKey = "redditInstalledAppClientID"
    private static let appOnlyAccessTokenStorageKey = "redditAppOnlyAccessToken"
    private static let appOnlyExpirationStorageKey = "redditAppOnlyTokenExpiration"
    private static let deviceIDStorageKey = "redditAppOnlyDeviceID"

    static var clientID: String {
        let override = UserDefaults.standard.string(forKey: clientIDStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty {
            return override
        }
        return Bundle.main.object(forInfoDictionaryKey: "RedditInstalledAppClientID") as? String ?? ""
    }

    static var isConfigured: Bool {
        !clientID.isEmpty
    }

    static func bearerToken() async -> String? {
        guard !clientID.isEmpty else { return nil }
        if let token = appOnlyAccessToken, Date() < appOnlyExpiration {
            return token
        }
        return await fetchAppOnlyBearerToken()
    }

    private static var appOnlyAccessToken: String? {
        let value = UserDefaults.standard.string(forKey: appOnlyAccessTokenStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static var appOnlyExpiration: Date {
        let timestamp = UserDefaults.standard.double(forKey: appOnlyExpirationStorageKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .distantPast
    }

    private static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDStorageKey),
           !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceIDStorageKey)
        return generated
    }

    private static func fetchAppOnlyBearerToken() async -> String? {
        guard let url = URL(string: "https://www.reddit.com/api/v1/access_token"),
              let credentials = "\(clientID):".data(using: .utf8)?.base64EncodedString() else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("ReEnchanted/1.0 (app-only iOS research source)", forHTTPHeaderField: "User-Agent")
        request.httpBody = [
            "grant_type=\(Self.formEncoded("https://oauth.reddit.com/grants/installed_client"))",
            "device_id=\(Self.formEncoded(deviceID))"
        ].joined(separator: "&")
            .data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(TokenResponse.self, from: data),
              !payload.accessToken.isEmpty else {
            return nil
        }
        storeAppOnly(payload)
        return payload.accessToken
    }

    private static func storeAppOnly(_ payload: TokenResponse) {
        UserDefaults.standard.set(payload.accessToken, forKey: appOnlyAccessTokenStorageKey)
        let lifetime = max(TimeInterval(payload.expiresIn ?? 3600) - 60, 60)
        UserDefaults.standard.set(Date().addingTimeInterval(lifetime).timeIntervalSince1970, forKey: appOnlyExpirationStorageKey)
    }

    fileprivate static func formEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    fileprivate struct TokenResponse: Decodable {
        var accessToken: String
        var expiresIn: Int?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
        }
    }
}

/// Live research for the Reader's Shelf column. Open-web sources are the
/// default; Reddit is used only when an approved installed-app client ID is
/// configured. The reader chose these interests on the About You page; the
/// registry note for The Bleed discloses the lookup.
struct BleedInterestSearcher {
    private struct RedditListing: Decodable {
        struct DataBox: Decodable {
            var children: [Child]
        }
        struct Child: Decodable {
            var data: Post
        }
        struct Post: Decodable {
            var title: String
            var subreddit: String
            var selftext: String?
            var ups: Int?
            var permalink: String?
            var over_18: Bool?
        }
        var data: DataBox
    }

    func clippings(for interest: String) async -> (text: String, sources: String) {
        if let reddit = await redditClippings(for: interest) {
            return reddit
        }
        let fallback = await RealInterestGossipSearcher().clippings(for: [interest], limit: 2)
        let webFallback = fallback.isEmpty
            ? await WebSearchFallback().clippings(for: interest, limit: 2)
            : fallback
        guard !webFallback.isEmpty else {
            return ("No live clippings reached the press room before deadline. Reddit blocked the window and the public search stacks had no usable abstract for this interest.", "")
        }
        let text = webFallback.map(\.promptLine).joined(separator: "\n\n")
        let sources = webFallback.map(\.sourceURL).filter { !$0.isEmpty }.joined(separator: "\n")
        return (text, sources)
    }

    private func redditClippings(for interest: String) async -> (text: String, sources: String)? {
        guard RedditSourceAccount.isConfigured,
              let authenticatedToken = await RedditSourceAccount.bearerToken() else {
            return nil
        }
        let query = interest.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? interest
        guard let url = URL(string: "https://oauth.reddit.com/search.json?q=\(query)&sort=top&t=week&limit=8&raw_json=1") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authenticatedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ReEnchanted/1.0 (iOS reader shelf source)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let listing = try? JSONDecoder().decode(RedditListing.self, from: data) else {
            return nil
        }
        let posts = listing.data.children
            .map(\.data)
            .filter { ($0.over_18 ?? false) == false && !$0.title.isEmpty }
            .prefix(5)
        guard !posts.isEmpty else { return nil }
        let text = posts.map { post -> String in
            let snippet = (post.selftext ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let clippedSnippet = snippet.isEmpty ? "" : " - \(String(snippet.prefix(220)))"
            let upvotes = post.ups.map { " (\($0) upvotes)" } ?? ""
            return "From the r/\(post.subreddit) commons this week\(upvotes): \"\(post.title)\"\(clippedSnippet)"
        }.joined(separator: "\n\n")
        let sources = posts.compactMap { post in
            post.permalink.map { "https://www.reddit.com\($0)" }
        }.joined(separator: "\n")
        return (text, sources)
    }
}

/// Writes one Bleed column in Penny Blackletter's voice, or falls back to a
/// deterministic clerk-voice composition when no local brain is available.
struct BleedColumnWriter {
    func write(brief: BleedColumnBrief, clippings: String) async -> String {
        guard brief.needsLocalBrain else { return brief.composedBody }
        let packet = brief.packet.replacingOccurrences(of: "{{CLIPPINGS}}", with: clippings)
        if let response = await LocalBrainProse.write(
            prompt: """
            COLUMN: \(brief.title)
            BYLINE: \(brief.byline)

            MATERIAL (write only from this; invent nothing beyond it):
            \(packet)
            """,
            instructions: instructions(for: brief),
            maxTokens: max(brief.maxTokens, 240),
            sourceID: "the-bleed",
            tags: ["bleed", brief.id]
        ) {
            return response
        }
        return fallback(brief: brief, packet: packet)
    }

    private func instructions(for brief: BleedColumnBrief) -> String {
        let shared = """
        You write for The Bleed, the Academy of Unlikely Arts student newspaper inside ReEnchanted.
        The voice is Penny Blackletter, Records Clerk, Department of Attestation: dry, precise, fond of evidence, suspicious of the word "resolution", permitted exactly one opinion per column and she places it carefully.
        Literary observations, never clinical claims. Never diagnose, never moralize, never invent completed real-world actions by the reader. Do not name the app. Plain prose, no markdown headers.
        """
        switch brief.id {
        case "front-page":
            return shared + """

            Write the lead column: 2-3 short paragraphs reading the supplied ledger material the way a clerk reads a window page - patterns, weights, what props itself up. If the Book has named constellations or sealed wagers, treat them as Registry filings worth noting. End with one understated clerk's opinion in the margin.
            """
        case "corridor-whispers":
            return shared + """

            Write 3-4 corridor whispers from the supplied simulation turns. Each whisper is one juicy italicized-feeling sentence or two, signed with invented initials (like -M.B.). Preserve every mechanical fact in the turns (who, which thread, Belief spent or dealt); replace only the prose. No new named characters.
            """
        case "interest-desk":
            return shared + """

            Write the Reader's Shelf column from the supplied live web clippings: 2-3 short paragraphs of genuinely useful, current information about the reader's interest, reported as dispatches Penny received "from beyond the casement". Name real communities and sources plainly (r/whatever is fine; the Academy finds the names charming). Do not fabricate clippings; if the material is thin, say so in clerk fashion and work with what arrived.
            """
        default:
            return shared
        }
    }

    private func fallback(brief: BleedColumnBrief, packet: String) -> String {
        let lines = packet
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("From the r/") }
            .prefix(5)
        let material = lines.isEmpty ? "" : "\n\n" + lines.joined(separator: "\n")
        switch brief.id {
        case "front-page":
            return "The Registry files the following without commentary, which is itself a kind of commentary.\(material)\n\nThe clerk notes the weights and leaves the verdicts to people with less filing to do."
        case "corridor-whispers":
            return "The corridor was quiet enough today that the whispers went unsigned. The mechanics stand as filed.\(material)"
        case "interest-desk":
            return "Dispatches from beyond the casement arrived too late for proper typesetting; the raw clippings are pinned below, which Penny insists is a style, not a failure.\(material)"
        default:
            return packet
        }
    }
}

private extension String {
    var strippingHTML: String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return self
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex
            .stringByReplacingMatches(in: self, options: [], range: range, withTemplate: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlEntityDecoded: String {
        var decoded = self
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        let pattern = #"&#x([0-9a-fA-F]+);|&#([0-9]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return decoded
        }
        let ns = decoded as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: decoded, options: [], range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let hexRange = match.range(at: 1)
            let decimalRange = match.range(at: 2)
            let scalarValue: UInt32?
            if hexRange.location != NSNotFound {
                scalarValue = UInt32(ns.substring(with: hexRange), radix: 16)
            } else if decimalRange.location != NSNotFound {
                scalarValue = UInt32(ns.substring(with: decimalRange), radix: 10)
            } else {
                scalarValue = nil
            }
            if let scalarValue, let scalar = UnicodeScalar(scalarValue) {
                result.append(Character(scalar))
            } else {
                result += ns.substring(with: match.range)
            }
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        decoded = result
        return decoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
