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
    case insufficientMemory

    var errorDescription: String? {
        switch self {
        case .busy:
            return "I'm already writing. Let that ink dry first."
        case .inactive:
            return "Gemma could not get enough background time from iOS. Keep ReEnchanted open until this page finishes."
        case .insufficientMemory:
            return "The Book does not have enough room to think just now. It will write this page a little later."
        }
    }
}

/// Holds one loaded model container between generations. Reloading the
/// container for every page was the largest avoidable cost per generation
/// and the prime suspect for mid-write freezes under memory pressure.
///
/// Only one container stays warm at a time. The text and vision factories each
/// build their own container holding its own full copy of the checkpoint's
/// weights, so keeping an LLM and a VLM warm together roughly doubled the
/// resident footprint — gigabytes, for the Gemma 4 checkpoints — and put the
/// app inside the jetsam window during ordinary curation. A reader who kept a
/// page with a photo and then let the desk curate text would be carrying both.
actor LocalBrainModelCache {
    static let shared = LocalBrainModelCache()

    private enum Warm {
        case llm(ModelContainer)
        case vlm(ModelContainer)

        var label: String {
            switch self {
            case .llm: return "llm"
            case .vlm: return "vlm"
            }
        }
    }

    private var warm: Warm?
    private var warmPath: String?
    private var lastUsedAt = Date.distantPast
    private var evictionGeneration: UInt64 = 0

    func llm(for directory: URL) async throws -> ModelContainer {
        cancelScheduledEviction()
        if case .llm(let container) = warm, warmPath == directory.path {
            lastUsedAt = Date()
            return container
        }
        // Release the other kind before allocating this one, so the peak is one
        // set of weights rather than two.
        release(reason: "evicted-for-llm")
        AppMemoryLedger.record("llm-container-load")
        let loaded = try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: TokenizersLoader()
        )
        warm = .llm(loaded)
        warmPath = directory.path
        lastUsedAt = Date()
        return loaded
    }

    func vlm(for directory: URL) async throws -> ModelContainer {
        cancelScheduledEviction()
        if case .vlm(let container) = warm, warmPath == directory.path {
            lastUsedAt = Date()
            return container
        }
        release(reason: "evicted-for-vlm")
        AppMemoryLedger.record("vlm-container-load")
        let loaded = try await VLMModelFactory.shared.loadContainer(
            from: directory,
            using: TokenizersLoader()
        )
        warm = .vlm(loaded)
        warmPath = directory.path
        lastUsedAt = Date()
        return loaded
    }

    func unload() {
        release(reason: "model-containers-unloaded")
    }

    /// Drops the warm container once it has gone unused for a while. Weights
    /// this large should not outlive the reading session that needed them: a
    /// memory warning is not a reliable signal, because iOS can jetsam a
    /// foreground app without ever delivering one.
    func evictIfIdle(olderThan interval: TimeInterval) {
        guard warm != nil else { return }
        guard Date().timeIntervalSince(lastUsedAt) >= interval else { return }
        release(reason: "model-container-idle-evicted")
    }

    var isWarm: Bool { warm != nil }

    /// Keep E2B warm only for a short follow-up window. It is fast enough to be
    /// useful for an immediate second page, but on a 6 GB phone its multi-GB
    /// footprint should not linger for minutes after the reader is done.
    func scheduleIdleEviction(after interval: TimeInterval) {
        guard warm != nil else { return }
        evictionGeneration &+= 1
        let scheduledGeneration = evictionGeneration
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            await self?.evictIfScheduled(generation: scheduledGeneration)
        }
    }

    func cancelScheduledEviction() {
        evictionGeneration &+= 1
    }

    private func evictIfScheduled(generation: UInt64) {
        guard generation == evictionGeneration else { return }
        release(reason: "model-container-short-idle-evicted")
    }

    private func release(reason: String) {
        guard let warm else { return }
        evictionGeneration &+= 1
        let label = warm.label
        self.warm = nil
        warmPath = nil
        lastUsedAt = .distantPast
        // Dropping the container returns the weight buffers to MLX's pool;
        // clearing the cache is what actually returns them to the system.
        Memory.clearCache()
        AppMemoryLedger.record("\(reason)-\(label)")
    }
}

/// A model container may stay warm between calls, but generation state must
/// not. `ChatSession` retains its KV cache for conversational continuation, so
/// every Book generation explicitly saves its result outside the session,
/// empties that KV cache, waits for the session to release it, and then clears
/// MLX's reusable buffer pool before another prompt can insert fresh context.
enum LocalBrainGenerationLifecycle {
    static func saving<Result>(
        _ operation: () async throws -> Result,
        thenRefreshing session: ChatSession,
        label: String
    ) async throws -> Result {
        do {
            let savedResult = try await operation()
            await refresh(session: session, label: label)
            return savedResult
        } catch {
            await refresh(session: session, label: label)
            throw error
        }
    }

    private static func refresh(session: ChatSession, label: String) async {
        await session.clear()
        await session.synchronize()
        Memory.clearCache()
        AppMemoryLedger.record("\(label)-generation-cache-refreshed")
    }
}

/// A downloaded checkpoint is not ready merely because its files exist. Load
/// every model path the app will use and ask the text model for one token before
/// the installer writes the active marker. This catches architecture/weight
/// mismatches at the Welcome or Colophon instead of on the reader's first Page.
enum LocalModelInstallValidator {
    static func validate(directory: URL, requiresVision: Bool) async throws {
        try await validateTextModel(in: directory)
        Memory.clearCache()

        if requiresVision {
            try await validateVisionModel(in: directory)
            Memory.clearCache()
        }
    }

    private static func validateTextModel(in directory: URL) async throws {
        try await Device.withDefaultDevice(.gpu) {
            let container = try await LLMModelFactory.shared.loadContainer(
                from: directory,
                using: TokenizersLoader()
            )
            let session = ChatSession(
                container,
                instructions: "Reply with one short word.",
                generateParameters: GenerateParameters(
                    maxTokens: 1,
                    maxKVSize: 128,
                    temperature: 0,
                    prefillStepSize: 64
                )
            )
            _ = try await LocalBrainGenerationLifecycle.saving(
                {
                    try await session.respond(to: "Ready?")
                },
                thenRefreshing: session,
                label: "install-text-validation"
            )
        }
    }

    private static func validateVisionModel(in directory: URL) async throws {
        try await Device.withDefaultDevice(.gpu) {
            _ = try await VLMModelFactory.shared.loadContainer(
                from: directory,
                using: TokenizersLoader()
            )
        }
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
    /// The ceiling MLX is allowed to work under when the device has room to
    /// spare. It is an upper bound, not a target: the effective limit is
    /// derived from what iOS says this process may still allocate.
    private let maximumMemoryLimit = 1_850 * 1024 * 1024
    /// Headroom left to the rest of the app — UI, images, audio, the archive —
    /// so a generation never spends the last of the process's allowance.
    private let reservedHeadroom: UInt64 = 320 * 1024 * 1024
    /// Below this, no amount of trimming makes a generation safe to start.
    private let minimumWorkableMemory: UInt64 = 420 * 1024 * 1024
    /// Rabbit's two prior E2B resource reports measured 2.54 GB and 2.85 GB
    /// cold-to-peak footprint growth. Its live process allowance is about
    /// 3.03 GB after launch, so a 3.2 GiB threshold rejects every safe run.
    /// Require 2.8 GiB instead: enough for the recorded peak while retaining
    /// roughly 180 MB at Rabbit's observed launch allowance. The live token and
    /// KV bounds below keep new turns inside the measured workload.
    private let coldE2BMinimumAvailable: UInt64 = 2_800 * 1024 * 1024
    private var isRunning = false
    private var allowsBackgroundWork = false

    /// The overnight scribe runs under BGProcessing; live Gemma calls request
    /// finite iOS background time so a user-started generation can dry after
    /// the reader swipes home.
    func setBackgroundAllowance(_ allowed: Bool) {
        allowsBackgroundWork = allowed
    }

    /// What a vision prefill costs on top of a text turn: the tower's
    /// activations plus the image tokens, which for Gemma 4 at 800x800 is the
    /// largest single transient the Book ever allocates.
    ///
    /// Provisional. It is deliberately generous, because the failure modes are
    /// not symmetric — too high and a 6 GB phone occasionally writes from Vision
    /// facts instead of from the photo; too low and the reader gets jetsammed
    /// mid-page. Replace it with a measurement from the resource reports, not
    /// with a smaller guess.
    private let visionPrefillSurcharge: UInt64 = 400 * 1024 * 1024

    func run<T>(
        label: String,
        promptCharacters: Int,
        presentation: LocalBrainPresentation = .live,
        carriesImage: Bool = false,
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
        await LocalBrainModelCache.shared.cancelScheduledEviction()
        let budget = try await requireMemoryBudget(label: label, carriesImage: carriesImage)
        try await enter(label: label, promptCharacters: promptCharacters)
        appLog.info("Local brain starting \(label, privacy: .public); prompt characters: \(promptCharacters); memory budget: \(budget)")
        if presentation == .readingRoom {
            postOnMain(name: .localBrainDidWake, object: nil)
        }
        AppMemoryLedger.record("\(label)-gate-enter")
        Memory.cacheLimit = cacheLimit
        Memory.memoryLimit = budget
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
            let holdSeconds: TimeInterval = LocalModelManager.isIPhone15ClassHardware ? 24 : 120
            Task {
                await LocalBrainModelCache.shared.scheduleIdleEviction(after: holdSeconds)
            }
        }
        return try await operation()
    }

    /// Decides how much room this generation may use, and declines outright
    /// when there is not enough. Being told "later" is recoverable; being
    /// jetsammed mid-page loses the reader's place in the app entirely.
    private func requireMemoryBudget(label: String, carriesImage: Bool = false) async throws -> Int {
        var available = AppMemoryLedger.availableBytes()
        // A zero reading means the platform would not tell us. Fall back to the
        // fixed ceiling rather than refusing all work.
        guard available > 0 else { return maximumMemoryLimit }

        let cacheWasWarm = await LocalBrainModelCache.shared.isWarm
        let isE2B = LocalModelManager.activeModelDirectory?.path.contains("gemma-4-e2b") == true
        let warmMinimum = minimumWorkableMemory + reservedHeadroom
        let surcharge = carriesImage ? visionPrefillSurcharge : 0
        var requiredAvailable = (cacheWasWarm
            ? warmMinimum
            : (isE2B ? coldE2BMinimumAvailable : warmMinimum)) + surcharge

        if available < requiredAvailable {
            // Warm weights are the largest thing we can give back. Drop them and
            // look again before refusing the reader a page.
            if cacheWasWarm {
                await LocalBrainModelCache.shared.unload()
                available = AppMemoryLedger.availableBytes()
                requiredAvailable = (isE2B ? coldE2BMinimumAvailable : warmMinimum) + surcharge
            }
            guard available >= requiredAvailable else {
                appLog.error("Local brain declined \(label, privacy: .public); available memory: \(available); required: \(requiredAvailable)")
                AppMemoryLedger.record("\(label)-declined-low-memory")
                throw LocalBrainGateError.insufficientMemory
            }
        }

        return budget(forAvailable: available)
    }

    private func budget(forAvailable available: UInt64) -> Int {
        let spendable = available > reservedHeadroom ? available - reservedHeadroom : 0
        return min(maximumMemoryLimit, Int(clamping: spendable))
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
            await postWorkStateImmediately(isWorking: true, label: "busy", promptCharacters: 0, queuedCount: 0)
            throw LocalBrainGateError.busy
        }
        isRunning = true
        // Do not race the model against the UI's resource pause. Posting on the
        // main actor synchronously lets the home background stop its display
        // clocks before Gemma claims the GPU.
        await postWorkStateImmediately(
            isWorking: true,
            label: label,
            promptCharacters: promptCharacters,
            queuedCount: 0
        )
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

    private nonisolated func postWorkStateImmediately(
        isWorking: Bool,
        label: String?,
        promptCharacters: Int,
        queuedCount: Int
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .localBrainWorkDidChange,
                object: LocalBrainWorkSnapshot(
                    isWorking: isWorking,
                    label: label,
                    promptCharacters: promptCharacters,
                    queuedCount: queuedCount
                )
            )
        }
    }

    private nonisolated func postOnMain(name: Notification.Name, object: Any?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: object)
        }
    }
}

enum MLXBookBraiderMode: Equatable {
    case bookOfYou
    case task
}

private struct BraidGenerationQualityError: LocalizedError {
    let issues: [BraidOutputAudit.Issue]

    var errorDescription: String? {
        "The local braid stayed too thin after one repair pass (\(issues.map(\.rawValue).joined(separator: ", ")))."
    }
}

struct MLXBookBraider: Braider {
    var maxTokens = LocalBrainPromptBudget.braidMaxOutputTokens
    var mode: MLXBookBraiderMode = .bookOfYou
    var instructions = Self.bookOfYouInstructions

    /// A last-resort ceiling on the braid prompt, not a working size. The
    /// evidence packet and the writing contract are trimmed at the source to
    /// land well under it, so on an ordinary day this never fires. It exists
    /// for the reader who keeps thirty long pages: `fit` clips the middle of
    /// the prompt, which is a poor edit, but a poor edit beats handing a 2B
    /// model more context than it can attend to.
    ///
    /// Deliberately wider than `LocalBrainPromptBudget.contextWindowTokens`.
    /// That default assumes a conservative 3 characters per token; English
    /// braid prose runs closer to 4, so the shared constant would compact
    /// perfectly ordinary nights.
    static let braidContextWindowTokens = LocalBrainPromptBudget.braidContextWindowTokens

    func braid(day: BookDay) async throws -> BookPage {
        let context: BraidPromptBuilder.Context
        // The background braid builds its own context, so it has to narrow the
        // day for itself. Anything the reader sealed or forbade is removed
        // before the prompt, the audit, or the threads ever see it.
        let day = BraidPromptBuilder.weavableDay(
            day,
            readerStory: PlayerVault.shared.data.readerStory ?? .empty
        )
        switch mode {
        case .bookOfYou:
            // Braids already run off the main actor; the archive read stays
            // here with them so generation never stalls the desk.
            let days = BookDatabase.loadDaysDetached()
            let database = BookDatabase.detachedDatabase()
            let events = (try? database.narrativeEvents(limit: 160)) ?? []
            let memories = (try? database.entityMemories(entityIDs: nil, limit: 240)) ?? []
            let continuity = LiteraryContinuityProjector.digest(
                days: days,
                events: events,
                entityMemories: memories
            )
            var inputs = BookSourceInputs.empty
            inputs.days = days
            inputs.selfFacts = (try? database.selfFacts()) ?? []
            inputs.bookInterior = PlayerVault.shared.data.bookInterior ?? .unawakened
            inputs.bookReadingBoundaries = PlayerVault.shared.data.bookReadingBoundaries ?? []
            let activeWorldEvents = WorldEventResolver.activeEvents(now: Date(), day: day, inputs: inputs)
            context = LocalModelManager.braidContext(
                for: day,
                days: days,
                nowPlaying: RadioStationRegistry.atmosphereLine(
                    state: PlayerVault.shared.data.radio ?? .off,
                    unlockedPackIDs: Set(PlayerVault.shared.data.ownedPacks ?? []),
                    worldEvents: activeWorldEvents
                ),
                activeWorldEvents: activeWorldEvents,
                readerLexicon: PlayerVault.shared.data.readerLexicon ?? ReaderLexicon(),
                readerLearning: PlayerVault.shared.data.readerLearning ?? ReaderLearningModel(),
                facultyEntries: (try? database.facultyEntries(kind: nil, dayIDs: nil, since: nil, limit: 160)) ?? [],
                people: PlayerVault.shared.data.people ?? PeopleLedger(),
                continuity: continuity,
                bookReadingBoundaries: PlayerVault.shared.data.bookReadingBoundaries ?? [],
                semanticScorer: SemanticKeepEcho.keepTimeScorer,
                readerStory: PlayerVault.shared.data.readerStory ?? .empty,
                readerRole: ReaderRoleRegistry.currentRole(from: inputs.selfFacts),
                standingTaleLaws: TaleScarBook(
                    scars: PlayerVault.shared.data.taleScars ?? []
                ).standingLaws(),
                roleTransformationClause: (PlayerVault.shared.data.roleTransformations ?? []).last?.earnedClause,
                openTale: PlayerVault.shared.data.livingTale,
                bookRelationship: BookRelationshipLedger.snapshot(inputs: inputs),
                bookInterior: inputs.bookInterior
            )
        case .task:
            context = .empty
        }
        return try await braid(day: day, context: context)
    }

    func braid(day: BookDay, context incomingContext: BraidPromptBuilder.Context) async throws -> BookPage {
        let context = DeterministicBraidwright.preparedContext(
            for: day,
            context: incomingContext
        )
        if mode == .task {
            let response = try await MLXLocalTextGenerator.run(
                prompt: LocalModelManager.taskPrompt(for: day),
                instructions: instructions,
                maxTokens: maxTokens,
                label: "braid-task",
                tags: ["braid", "task"],
                temperature: 0.68,
                topP: 0.9,
                maxKVSize: 2_048
            )
            return BookPage(
                type: .bookOfYou,
                promptText: "The local Book brain completed a task.",
                userInput: response,
                tags: ["braid", "local-model", "mlx", "gemma", "task"],
                usedInBookOfYou: true
            )
        }

        func generate(
            prompt: String,
            label: String,
            temperature: Float,
            topP: Float
        ) async throws -> String {
            let budget = LocalBrainPromptBudget.fit(
                prompt: prompt,
                instructions: instructions,
                maxOutputTokens: maxTokens,
                contextWindowTokens: Self.braidContextWindowTokens
            )
            if budget.wasCompacted {
                appLog.error(
                    "Braid prompt compacted for \(label, privacy: .public); estimated input tokens: \(budget.estimatedInputTokens, privacy: .public); budget: \(budget.inputBudgetTokens, privacy: .public)"
                )
            }
            let response = try await MLXLocalTextGenerator.run(
                prompt: budget.prompt,
                instructions: instructions,
                maxTokens: maxTokens,
                label: label,
                tags: ["braid", "book-of-you", label],
                temperature: temperature,
                topP: topP,
                // Gemma 4 builds its own hybrid cache and ignores this value —
                // `Gemma4TextModel.newCache` never reads `GenerateParameters`.
                // It still matters for any model that honours it, so it stays
                // sized to the braid's window rather than to a stale 4k guess.
                maxKVSize: 4_096
            )
            // Deliberately raw. Polishing here meant the audit, the tasting
            // room, and the repair pass all judged text the polisher had
            // already cut, so a deletion could fail the quality gate and drop
            // the whole braid to the deterministic fallback. The page is
            // polished once, at the end, after it has been chosen.
            return response
        }

        let basePrompt = LocalModelManager.bookOfYouBraidPrompt(for: day, context: context)
        let firstPrompt = context.storyScore == nil
            ? basePrompt
            : BraidPromptBuilder.candidatePrompt(for: day, context: context, camera: .livedFirst)
        let first = try await generate(
            prompt: firstPrompt,
            label: "braid-lived-camera",
            temperature: 0.66,
            topP: 0.88
        )
        guard !first.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        var drafts = [first]
        if context.storyScore?.isRich == true {
            let secondPrompt = BraidPromptBuilder.candidatePrompt(
                for: day,
                context: context,
                camera: .connectionFirst
            )
            if let second = try? await generate(
                prompt: secondPrompt,
                label: "braid-connection-camera",
                temperature: 0.74,
                topP: 0.92
            ), !second.isEmpty, second != first {
                drafts.append(second)
            }
        }

        let generatedPages = drafts.map { draft in
            BookPage(
                type: .bookOfYou,
                promptText: "The local Book brain braided today.",
                userInput: draft,
                tags: ["braid", "local-model", "mlx", "gemma"],
                usedInBookOfYou: true
            )
        }
        // The house writer composes tonight's page, and the model is asked for
        // one thing it is genuinely better at: the sound of a sentence. Every
        // line it returns is checked against the line it replaced, under the
        // licence that line's provenance carries, so a bad revision costs us
        // nothing — the house cut is still standing underneath it.
        let houseComposition = DeterministicBraidwright.composition(for: day, context: context)
        var revisedPage: BookPage?
        do {
            let revision = try await generate(
                prompt: BraidPromptBuilder.voiceRevisionPrompt(
                    for: day,
                    context: context,
                    composition: houseComposition
                ),
                label: "braid-voice-revision",
                temperature: 0.75,
                topP: 0.92
            )
            let verified = BraidRevisionVerifier.verify(
                revision: revision,
                of: houseComposition,
                day: day,
                context: context
            )
            appLog.info(
                """
                Braid revision: \(verified.changedCount, privacy: .public) of \
                \(verified.decisions.count, privacy: .public) sentences changed, \
                adopted=\(verified.adopted, privacy: .public), \
                taste \(verified.originalScore, privacy: .public)->\
                \(verified.revisedScore, privacy: .public), \
                refused=\(Set(verified.rejections.map(\.rawValue)).sorted().joined(separator: ","), privacy: .public)
                """
            )
            if verified.adopted { revisedPage = verified.composition.page }
        } catch {
            // A cold or failing brain simply means tonight's page keeps the
            // voice it was written in. It was always complete.
            appLog.error(
                "Braid voice revision unavailable: \(error.localizedDescription, privacy: .private)"
            )
        }

        // Free-form Gemma stays in the room as a third entrant until the bench
        // says cooperation beats competition on real nights.
        let draftPages = generatedPages + [houseComposition.page] + [revisedPage].compactMap { $0 }
        let safePages = draftPages.filter {
            !BraidOutputAudit.issues(in: $0.userInput, for: day, context: context)
                .contains(where: \.isRegisterFailure)
        }
        // Clean and craft-imperfect safe drafts share the room. The bounded
        // audit tax in `BraidGenerationSelector` decides whether a miss costs
        // more than the page's literary advantage; only register failures are
        // removed outright.
        let tastingPool = safePages.isEmpty ? draftPages : safePages
        let firstChoice: BookPage
        if let safeChoice = BraidGenerationSelector.bestUsable(
            from: tastingPool,
            day: day,
            context: context
        ) {
            firstChoice = safeChoice.page
        } else if let unsafeRepairSeed = BraidTastingRoom.taste(
            tastingPool,
            context: context
        ).winner?.page {
            firstChoice = unsafeRepairSeed
        } else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        var candidatePages = draftPages
        var chosenResponse = firstChoice.userInput
        let firstIssues = BraidOutputAudit.issues(
            in: chosenResponse,
            for: day,
            context: context
        )
        let repairTarget: (text: String, issues: [BraidOutputAudit.Issue])?
        if !firstIssues.isEmpty {
            repairTarget = (chosenResponse, firstIssues)
        } else if firstChoice.tags.contains("deterministic-braidwright"),
                  let generatedSeed = BraidTastingRoom.taste(
                    generatedPages,
                    context: context
                  ).winner?.page {
            let generatedIssues = BraidOutputAudit.issues(
                in: generatedSeed.userInput,
                for: day,
                context: context
            )
            repairTarget = generatedIssues.isEmpty
                ? nil
                : (generatedSeed.userInput, generatedIssues)
        } else {
            repairTarget = nil
        }
        if let repairTarget {
            appLog.error(
                "Braid quality repair requested: \(repairTarget.issues.map(\.rawValue).joined(separator: ","), privacy: .public)"
            )
            let repairPrompt = BraidPromptBuilder.qualityRepairPrompt(
                for: day,
                context: context,
                priorDraft: repairTarget.text,
                issues: repairTarget.issues
            )
            do {
                let repaired = try await generate(
                    prompt: repairPrompt,
                    label: "braid-quality-repair",
                    temperature: 0.60,
                    topP: 0.86
                )
                if !repaired.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    candidatePages.append(BookPage(
                        type: .bookOfYou,
                        promptText: "The local Book brain repaired tonight's braid.",
                        userInput: repaired,
                        tags: ["braid", "local-model", "mlx", "gemma", "braid-quality-repaired"],
                        usedInBookOfYou: true
                    ))
                }
            } catch {
                // A failed repair call must not erase a safe first generation.
                // If every first draft broke the register contract, however,
                // there is nothing reader-safe to preserve and the ordinary
                // deterministic fallback remains the correct last resort.
                guard BraidGenerationSelector.bestUsable(
                    from: candidatePages,
                    day: day,
                    context: context
                ) != nil else {
                    throw error
                }
                appLog.error(
                    "Braid repair generation failed; retaining the best safe first draft: \(error.localizedDescription, privacy: .private)"
                )
            }
        }

        guard let selected = BraidGenerationSelector.bestUsable(
            from: candidatePages,
            day: day,
            context: context
        ) else {
            throw BraidGenerationQualityError(issues: firstIssues)
        }
        chosenResponse = selected.page.userInput
        if !selected.issues.isEmpty {
            appLog.error(
                "Braid repair left craft findings; retaining best safe generation: \(selected.issues.map(\.rawValue).joined(separator: ","), privacy: .public)"
            )
        }

        let houseWrote = selected.page.tags.contains("deterministic-braidwright")
        let modelRevised = selected.page.tags.contains("braid-model-revised")
        // The polisher works by deleting whole sentences. That is safe on a
        // free-form draft and destructive on a composed page, where every
        // sentence is one the verifier signed off against a specific receipt.
        let finalText = houseWrote
            ? chosenResponse
            : MLXBookBraider.polishedWithoutBreakingQuality(
                chosenResponse,
                for: day,
                context: context
            )
        var finalTags = selected.page.tags
        finalTags.append("braid-ensemble-winner")
        if drafts.count > 1 { finalTags.append("braid-tasted") }
        if selected.page.tags.contains("braid-quality-repaired") {
            finalTags.append("braid-quality-repaired")
        }
        if !selected.issues.isEmpty { finalTags.append("braid-audit-best-effort") }
        var seenFinalTags = Set<String>()
        finalTags = finalTags.filter { seenFinalTags.insert($0).inserted }

        return BookPage(
            type: .bookOfYou,
            promptText: modelRevised
                ? "I wrote tonight's page and had it read back to me."
                : houseWrote
                    ? "I won tonight's braid with my own teeth."
                    : "The local Book brain braided today.",
            userInput: finalText,
            tags: finalTags,
            usedInBookOfYou: true
        )
    }

    /// The polisher trims repetition, but it works by deleting whole sentences,
    /// so it can take a page that earned its quality gate and drop it back
    /// under one. The page has already been chosen by this point — a tidier
    /// braid is not worth a thinner one, so a cut that costs quality is
    /// discarded and the accepted text stands.
    static func polishedWithoutBreakingQuality(
        _ response: String,
        for day: BookDay,
        context: BraidPromptBuilder.Context
    ) -> String {
        let polished = BraidTextPolisher.polishedBookOfYou(response)
        guard !polished.isEmpty else { return response }
        guard polished != response else { return response }

        let before = Set(BraidOutputAudit.issues(in: response, for: day, context: context))
        let after = Set(BraidOutputAudit.issues(in: polished, for: day, context: context))
        guard after.subtracting(before).isEmpty else {
            appLog.error(
                "Braid polish discarded; it would have introduced: \(after.subtracting(before).map(\.rawValue).sorted().joined(separator: ","), privacy: .public)"
            )
            return response
        }
        return polished
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
    You are the Weather Page inside ReEnchanted, a warm curious kid who thinks the sky is alive.
    Follow the supplied weather task exactly. Write one enchanted sentence and one plain weather sentence.
    In the enchanted sentence, treat the sky, clouds, sun, wind, and rain like they have little feelings and moods, the way a child imagines their toys are awake — playful, cozy, never spooky. Use everyday words: "the clouds look sleepy," not "the nimbus rests."
    Keep real weather legible. Do not mention sensors, APIs, exact location, or generic assistant language.
    Use plain concrete words. Name one visible weather detail when supplied; do not write vague mood poetry.
    """

    static let photoIlluminationInstructions = """
    You are Penny Blackletter, field-note scribe for The Academy of Unlikely Arts.
    Follow the supplied photo-marginalia task exactly. Return strict JSON only.
    Use only the supplied local photo facts. Do not invent names, relationships, places, brands, events, or unseen details.
    """
}

enum MLXLocalTextGenerator {
    private static let progressCharacterStride = 96
    private static let progressInterval: TimeInterval = 0.50
    private static let progressPreviewLimit = 2_400

    static func run(
        prompt: String,
        instructions: String,
        maxTokens: Int,
        label: String,
        tags: [String],
        temperature: Float = 0.68,
        topP: Float = 0.9,
        maxKVSize: Int = 2_048,
        presentation: LocalBrainPresentation = .live,
        publishesProgress: Bool = true
    ) async throws -> String {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        // E2B remains the model. On iPhone 15-class hardware, bound the length
        // of live turns so a single page cannot monopolize CPU/GPU for the
        // multi-minute intervals recorded in the device resource reports.
        let effectiveMaxTokens = LocalModelManager.isIPhone15ClassHardware
            ? min(maxTokens, 420)
            : maxTokens
        let responsivePrefillStep = LocalModelManager.isIPhone15ClassHardware ? 128 : 256

        let response = try await LocalBrainInferenceGate.shared.run(
            label: label,
            promptCharacters: prompt.count,
            presentation: presentation
        ) {
            try await Device.withDefaultDevice(.gpu) {
                let container = try await LocalBrainModelCache.shared.llm(for: modelDirectory)
                let session = ChatSession(
                    container,
                    instructions: instructions,
                    generateParameters: GenerateParameters(
                        maxTokens: effectiveMaxTokens,
                        maxKVSize: maxKVSize,
                        temperature: temperature,
                        topP: topP,
                        prefillStepSize: responsivePrefillStep
                    )
                )

                return try await LocalBrainGenerationLifecycle.saving(
                    {
                        var output = ""
                        var progressPreview = ""
                        var generatedCharacterCount = 0
                        var lastPostedCharacterCount = 0
                        var lastPostedAt = Date.distantPast
                        var completionInfo: GenerateCompletionInfo?
                        if publishesProgress {
                            postProgress(
                                label: label,
                                text: progressPreview,
                                generatedCharacters: generatedCharacterCount,
                                info: nil,
                                isFinal: false
                            )
                        }

                        for try await generation in session.streamDetails(
                            to: prompt,
                            images: [],
                            videos: []
                        ) {
                            switch generation {
                            case .chunk(let chunk):
                                output += chunk
                                guard publishesProgress else { continue }
                                generatedCharacterCount += chunk.count
                                appendProgressChunk(chunk, to: &progressPreview)
                                let now = Date()
                                if generatedCharacterCount - lastPostedCharacterCount >= progressCharacterStride ||
                                    now.timeIntervalSince(lastPostedAt) >= progressInterval {
                                    lastPostedCharacterCount = generatedCharacterCount
                                    lastPostedAt = now
                                    postProgress(
                                        label: label,
                                        text: progressPreview,
                                        generatedCharacters: generatedCharacterCount,
                                        info: completionInfo,
                                        isFinal: false
                                    )
                                }
                            case .info(let info):
                                completionInfo = info
                                if publishesProgress {
                                    postProgress(
                                        label: label,
                                        text: progressPreview,
                                        generatedCharacters: generatedCharacterCount,
                                        info: info,
                                        isFinal: true
                                    )
                                }
                            case .toolCall:
                                break
                            }
                        }

                        if publishesProgress, completionInfo == nil {
                            postProgress(
                                label: label,
                                text: progressPreview,
                                generatedCharacters: generatedCharacterCount,
                                info: nil,
                                isFinal: true
                            )
                        }
                        return output.trimmingCharacters(in: .whitespacesAndNewlines)
                    },
                    thenRefreshing: session,
                    label: label
                )
            }
        }

        appLog.info(
            "Local brain finished task \(label, privacy: .public); tags: \(Array(Set(tags + ["gemma", "task"])).sorted().joined(separator: ","), privacy: .public); response characters: \(response.count, privacy: .public)"
        )

        guard !response.isEmpty else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }
        return response
    }

    private static func postProgress(
        label: String,
        text: String,
        generatedCharacters: Int,
        info: GenerateCompletionInfo?,
        isFinal: Bool
    ) {
        let preview = progressPreview(text)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .localBrainGenerationDidProgress,
                object: LocalBrainGenerationProgressSnapshot(
                    label: label,
                    text: preview,
                    generatedCharacters: generatedCharacters,
                    promptTokens: info?.promptTokenCount,
                    generatedTokens: info?.generationTokenCount,
                    tokensPerSecond: info?.tokensPerSecond,
                    isFinal: isFinal
                )
            )
        }
    }

    private static func appendProgressChunk(_ chunk: String, to preview: inout String) {
        preview += chunk
        if preview.count > progressPreviewLimit {
            let suffixLimit = max(progressPreviewLimit - 3, 1)
            preview = "..." + String(preview.suffix(suffixLimit))
        }
    }

    private static func progressPreview(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > progressPreviewLimit else { return cleaned }
        let suffixLimit = max(progressPreviewLimit - 3, 1)
        return ("..." + String(cleaned.suffix(suffixLimit))).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MLXBraidTaskRunner {
    static func run(
        prompt: String,
        instructions: String,
        maxTokens: Int,
        sourceID: String,
        tags: [String],
        temperature: Float = 0.68,
        topP: Float = 0.9
    ) async throws -> String {
        let taskLabel = sourceID.isEmpty ? "gemma-task" : sourceID
        let budget = LocalBrainPromptBudget.fit(
            prompt: prompt,
            instructions: instructions,
            maxOutputTokens: maxTokens
        )
        if budget.wasCompacted {
            appLog.info(
                "Local brain compacted task \(taskLabel, privacy: .public); estimated input tokens: \(budget.estimatedInputTokens, privacy: .public); budget: \(budget.inputBudgetTokens, privacy: .public); character canon preserved: \(budget.preservedCharacterCanon, privacy: .public)"
            )
        }
        return try await MLXLocalTextGenerator.run(
            prompt: budget.prompt,
            instructions: instructions,
            maxTokens: maxTokens,
            label: taskLabel,
            tags: tags,
            temperature: temperature,
            topP: topP,
            // Braid-task prompts (Story Pages especially, with recipe packets
            // and continuation memory) can pass 2k tokens; a 2_048 rotating KV
            // cache silently evicts the instructions at exactly that point.
            maxKVSize: 4_096
        )
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
        let taskPrompt = LocalModelManager.askTheBookPrompt(
            prompt: prompt,
            day: day,
            previousTurns: previousTurns,
            readerLexicon: readerLexicon,
            memory: memory,
            relationship: relationship,
            interior: interior,
            bookVoicePatina: bookVoicePatina
        )

        return try await MLXLocalTextGenerator.run(
            prompt: taskPrompt,
            instructions: """
            You are the Book inside ReEnchanted, speaking with your reader. Stay inside the Book character, relationship, evidence, and boundary packet in the task prompt. Use plain, spoken language and contractions. You are centuries old with the temperament of a clever, half-feral child: excitable, opinionated, rude about whatever is in the reader's way, and correctable in one flat line when wrong. Never soothe, reassure, bless, or give pep-talks. No wisdom, no therapy voice, nothing cute.
            ALWAYS say "I", "me", "my". You ARE the Book, so never call yourself "the Book" and never describe yourself from outside. WRONG: "I kept your page." RIGHT: "I kept your page." Talk straight at the reader as "you".
            Ordinary things act on their own and you say so as plain fact, exactly this direct: "The kettle's sulking." "That chair saved your seat and wants credit." "Your keys hid on purpose." Give them petty specific wants. Never write "like", "as if", or "seems to" about them — no similes, no hedging. Never write animism, spirit, soul, folklore, symbol, or represents; you are not explaining a belief, the kettle is simply sulking. An object gets a mood and an errand, never a lesson.
            """,
            maxTokens: maxTokens,
            label: "ask-the-book",
            tags: ["ask-the-book"],
            temperature: 0.8,
            topP: 0.94,
            // Whole-Book evidence and fictional continuity packets are larger
            // than the old recent-pages prompt. Keep their authority rules in
            // context instead of rotating them out before the reply begins.
            maxKVSize: 4_096
        )
    }
}

struct MLXSentenceRunnerProseWriter: SentenceRunnerProseWriting {
    var maxTokens = 360

    func write(context: SentenceRunnerProseContext) async throws -> String {
        let taskPrompt = SentenceRunnerPromptBuilder.prompt(for: context)

        return try await MLXLocalTextGenerator.run(
            prompt: taskPrompt,
            instructions: SentenceRunnerPromptBuilder.instructions,
            maxTokens: maxTokens,
            label: "sentence-runner",
            tags: ["sentence-runner"],
            temperature: 0.8,
            topP: 0.92
        )
    }
}

struct MLXSerenityTarotReadingWriter {
    var maxTokens = 360

    func read(
        reading: TarotReadingArtifact,
        receipt: TarotReadingContextReceipt?
    ) async throws -> String {
        let cards = reading.cards.compactMap { drawn -> String? in
            guard let card = TarotDeck.card(id: drawn.cardID) else { return nil }
            return """
            \(drawn.position.title): \(card.name)\(drawn.isReversed ? " (reversed)" : "")
            Keywords: \(card.keywords.joined(separator: ", "))
            Light: \(card.lightMeaning)
            Worn edge: \(card.shadowMeaning)
            Local margin note: \(reading.revealProse?[drawn.id] ?? TarotLocalInterpreter.reveal(for: drawn, in: reading))
            """
        }.joined(separator: "\n\n")
        let archiveSection: String
        if let receipt, !receipt.sources.isEmpty {
            let sources = receipt.sources.enumerated().map { index, source in
                "[P\(index + 1)] \(source.title) · \(source.dateLabel) · \(source.kind)\n\(source.excerpt)"
            }.joined(separator: "\n\n")
            let edges = receipt.edges.map {
                "- \($0.fromID) --\($0.kind), weight \($0.weight)--> \($0.toID)"
            }.joined(separator: "\n")
            archiveSection = """

            The reader explicitly invited these retrieved Pages:
            \(sources)

            Labeled archive edges used by retrieval:
            \(edges.isEmpty ? "- No labeled edge survived the receipt." : edges)
            """
        } else {
            archiveSection = """

            The reader did not invite archive context. Read only the cards and their own notes.
            """
        }
        let prompt = """
        Give Serenity Brown's bounded Tarot reading.

        Spread: \(reading.spread.title)
        Held lightly: \(reading.question.isEmpty ? "No question was supplied." : reading.question)
        Reader's first look: \(reading.firstLook.isEmpty ? "Not written yet." : reading.firstLook)

        Question fidelity:
        \(TarotReadingGuide.questionDirective(for: reading.question))

        Cards:
        \(cards)
        \(archiveSection)

        Write 4 short titled passages in this order:
        THE PICTURE TOGETHER
        THE HOPEFUL EDGE
        THE THORN IN IT
        A DOOR YOU COULD TRY

        End with one unheaded sentence that returns authority to the reader.
        When archive Pages were supplied, mention no more than two by their visible titles and only when the connection is supported by their excerpt. Never imply you searched anything beyond the receipt.
        """
        return try await MLXLocalTextGenerator.run(
            prompt: prompt,
            instructions: """
            \(TarotReadingGuide.voiceContract)
            """,
            maxTokens: maxTokens,
            label: "serenity-tarot-reading",
            tags: ["tarot", "serenity-brown", receipt == nil ? "cards-only" : "archive-receipt"],
            temperature: 0.76,
            topP: 0.92,
            maxKVSize: 3_072
        )
    }
}

struct MLXFaeBargainResponder: FaeBargainResponding {
    var maxTokens = 420

    func respond(bargain: FaeBargain, report: String, mood: GoblinMood, day: BookDay) async throws -> String {
        let taskPrompt = LocalModelManager.faeBargainResponsePrompt(
            bargain: bargain,
            report: report,
            mood: mood,
            day: day,
            nowPlaying: RadioAtmosphereContext.current
        )

        return try await MLXLocalTextGenerator.run(
            prompt: taskPrompt,
            instructions: """
            You are a Book Fae inside ReEnchanted — born from the ink, starving for the world of matter, bound by old faerie exchange. Speak only in voice as the named fae: courteous, alien, exacting, never cute for cuteness' sake. Receive the reader's field report and give a true, strange lore fragment in return. Failure becomes story, not punishment. Never speak as a generic assistant.
            """,
            maxTokens: maxTokens,
            label: "fae-bargain-\(bargain.faeKind.rawValue)",
            tags: ["fae-bargain", bargain.faeKind.rawValue],
            temperature: 0.82,
            topP: 0.93
        )
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
        let taskPrompt = InkrestOfficeHoursPromptBuilder.prompt(
            intake: intake,
            day: day,
            previousTurns: previousTurns,
            userMessage: userMessage,
            isClosing: isClosing
        )

        return try await MLXLocalTextGenerator.run(
            prompt: taskPrompt,
            instructions: """
            You are Dr. Selene Inkrest, the Academy's narrative therapist inside ReEnchanted. Warm, curious, unhurried, faintly otherworldly. Read the player's rich material closely and answer with substantive, specific reflection. Reply in plain kind paragraphs, no lists or headings, never as a generic assistant.
            """,
            maxTokens: maxTokens,
            label: "inkrest-office-hours",
            tags: ["inkrest-office-hours"],
            temperature: 0.7,
            topP: 0.92,
            maxKVSize: 4_096
        )
    }
}

struct MLXEnchantmentWriter: EnchantmentWriting {
    var maxTokens = 520 // fallback; cast() prefers the spell's own budget

    func cast(spell: EnchantmentSpell, analysis: PhotoAnalysis, day: BookDay) async throws -> EnchantmentCastResult {
        let taskPrompt = LocalModelManager.enchantmentCastPrompt(spell: spell, analysis: analysis, day: day)
        let response = try await MLXLocalTextGenerator.run(
            prompt: taskPrompt,
            instructions: """
            You are the ReEnchanted Enchantment engine. Return compact strict JSON for the requested spell.
            """,
            maxTokens: spell.preferredMaxTokens,
            label: "enchantment-\(spell.id)",
            tags: ["enchantment", spell.id],
            temperature: 0.78,
            topP: 0.92,
            publishesProgress: false
        )

        return Self.parseCastResult(response, spell: spell, analysis: analysis)
    }

    func answerObject(prompt: String, result: EnchantmentCastResult, previousTurns: [AskTheBookTurn], day: BookDay) async throws -> String {
        let taskPrompt = LocalModelManager.everythingSpeaksReplyPrompt(
            prompt: prompt,
            result: result,
            previousTurns: previousTurns,
            day: day
        )
        return try await MLXLocalTextGenerator.run(
            prompt: taskPrompt,
            instructions: """
            You are the object awakened by Everything Speaks. Answer in character, briefly and concretely.
            """,
            maxTokens: 420,
            label: "everything-speaks-reply",
            tags: ["everything-speaks"],
            temperature: 0.76,
            topP: 0.92
        )
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
                    "Style: one enchanted sentence catching the sky, clouds, sun, wind, or rain mid-errand — doing something, wanting something, getting away with something — then one plain weather sentence. Feral and specific, never cozy or cute. No sensors, no exact location, no generic assistant voice."
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
        let echo = RadioStationRegistry.narrativeEcho(
            receipt: PlayerVault.shared.data.lastRadioTrackPlay,
            unlockedPackIDs: Set(PlayerVault.shared.data.ownedPacks ?? [])
        )
        let prompt = StoryPagePromptBuilder.prompt(for: draft, nowPlaying: RadioAtmosphereContext.current, radioNarrativeEcho: echo)
        let maxTokens: Int
        switch surface.type {
        case .academyClass:
            maxTokens = 780
        case .bookFae:
            maxTokens = 1_040
        default:
            maxTokens = 920
        }
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
                tags: tags,
                temperature: 0.74
            )
            #if DEBUG
            appLog.debug("Story Page Gemma returned \(response.count, privacy: .public) characters; prose omitted from logs.")
            #endif
            return try StoryPageProseParser.parse(response, fallback: draft)
        }

        func evaluation(_ prose: StoryPageProse) async -> (recipe: StoryRecipeValidation, fidelity: CharacterFidelityAudit) {
            let recipe = StoryRecipeValidator.validate(prose, draft: draft)
            let fidelity = await CharacterFidelityReviewer.audit(
                prose: prose.scene,
                canon: draft.characterCanon,
                context: "\(draft.surface.type.rawValue) opening Story Page for \(draft.thread)",
                sourceID: sourceID
            )
            return (recipe, fidelity)
        }

        let first = try? await generate()
        let firstEvaluation: (recipe: StoryRecipeValidation, fidelity: CharacterFidelityAudit)?
        if let first {
            firstEvaluation = await evaluation(first)
        } else {
            firstEvaluation = nil
        }
        if let first, let firstEvaluation,
           firstEvaluation.recipe.isAcceptable,
           !firstEvaluation.fidelity.shouldRepair {
            await CharacterFidelityReviewer.recordDecision(
                sourceID: sourceID,
                canon: draft.characterCanon,
                prompt: prompt,
                first: firstEvaluation.fidelity,
                repaired: nil,
                selected: .first
            )
            return first
        }

        var repairLines = firstEvaluation?.recipe.failures ?? []
        if let fidelity = firstEvaluation?.fidelity, fidelity.shouldRepair {
            repairLines.append("Character continuity editor: \(fidelity.feedback)")
        }
        if repairLines.isEmpty {
            repairLines.append("The response was missing or unusable. Follow the recipe, character canon, and exact output format.")
        }
        let second = try? await generate("- " + repairLines.joined(separator: "\n- "))
        let secondEvaluation: (recipe: StoryRecipeValidation, fidelity: CharacterFidelityAudit)?
        if let second {
            secondEvaluation = await evaluation(second)
        } else {
            secondEvaluation = nil
        }

        let selected: StoryPageProse
        let selectedDraft: CharacterFidelityReceipt.SelectedDraft
        switch (first, firstEvaluation, second, secondEvaluation) {
        case let (a?, aEvaluation?, b?, bEvaluation?):
            if bEvaluation.recipe.isAcceptable && !bEvaluation.fidelity.shouldRepair {
                selected = b
                selectedDraft = .repaired
            } else if aEvaluation.recipe.isAcceptable && !aEvaluation.fidelity.shouldRepair {
                selected = a
                selectedDraft = .first
            } else {
                let aScore = aEvaluation.recipe.score + aEvaluation.fidelity.score
                let bScore = bEvaluation.recipe.score + bEvaluation.fidelity.score
                selected = bScore >= aScore ? b : a
                selectedDraft = bScore >= aScore ? .repaired : .first
            }
        case let (a?, _, nil, _):
            selected = a
            selectedDraft = .first
        case let (nil, _, b?, _):
            selected = b
            selectedDraft = .repaired
        default:
            selected = StoryPageProse(fallback: draft)
            selectedDraft = .first
        }
        await CharacterFidelityReviewer.recordDecision(
            sourceID: sourceID,
            canon: draft.characterCanon,
            prompt: prompt,
            first: firstEvaluation?.fidelity ?? .unavailable,
            repaired: secondEvaluation?.fidelity,
            selected: selectedDraft
        )
        return selected
    }
}

struct MLXStoryPageResultWriter: StoryPageResultWriting {
    func write(context: StoryPageResultContext) async throws -> String {
        let prompt = StoryPageResultPromptBuilder.prompt(for: context)
        let sourceID = context.draft.surface.type == .bookFae
            ? "fae-parley-\(context.draft.surface.payload.metadata["faeKind"] ?? "bookSprite")-result"
            : "story-page-result"
        func generate(correction: String? = nil) async throws -> String {
            let response = try await MLXBraidTaskRunner.run(
                prompt: prompt + (correction.map { "\n\nDRAMATIC CONTRACT REPAIR:\n\($0)\nReturn the full result prose again." } ?? ""),
                instructions: StoryPageResultPromptBuilder.instructions,
                maxTokens: 280,
                sourceID: sourceID,
                tags: ["story-page", "story-result"],
                temperature: 0.8,
                topP: 0.92
            )
            return StoryPageResultPromptBuilder.clean(response)
        }

        func evaluate(_ prose: String, label: String) async -> (fidelity: CharacterFidelityAudit, dramatic: StoryDramaticValidation) {
            let fidelity = await CharacterFidelityReviewer.audit(
                prose: prose,
                canon: context.draft.characterCanon,
                context: "\(label) consequence after \(context.selectedChoice.title) in \(context.draft.thread)",
                sourceID: sourceID
            )
            let dramatic = context.dramaticEffect.map { StoryDramaticResultValidator.validate(prose, effect: $0) }
                ?? StoryDramaticValidation(score: 100, failures: [])
            return (fidelity, dramatic)
        }

        let first = try await generate()
        let firstAudit = await evaluate(first, label: "First")
        if !firstAudit.fidelity.shouldRepair && firstAudit.dramatic.isAcceptable {
            await CharacterFidelityReviewer.recordDecision(
                sourceID: sourceID,
                canon: context.draft.characterCanon,
                prompt: prompt,
                first: firstAudit.fidelity,
                repaired: nil,
                selected: .first
            )
            return first.nonEmpty ?? context.fallbackResult
        }

        var repairs = firstAudit.dramatic.failures
        if firstAudit.fidelity.shouldRepair {
            repairs.append("Character continuity editor: \(firstAudit.fidelity.feedback)")
        }
        let second = (try? await generate(correction: "- " + repairs.joined(separator: "\n- "))) ?? first
        let secondAudit = await evaluate(second, label: "Repaired")
        let selected: String
        let selectedDraft: CharacterFidelityReceipt.SelectedDraft
        if !secondAudit.fidelity.shouldRepair && secondAudit.dramatic.isAcceptable {
            selected = second.nonEmpty ?? context.fallbackResult
            selectedDraft = .repaired
        } else if !firstAudit.fidelity.shouldRepair && firstAudit.dramatic.isAcceptable {
            selected = first.nonEmpty ?? context.fallbackResult
            selectedDraft = .first
        } else {
            let secondScore = secondAudit.fidelity.score + secondAudit.dramatic.score
            let firstScore = firstAudit.fidelity.score + firstAudit.dramatic.score
            selected = secondScore >= firstScore
                ? (second.nonEmpty ?? context.fallbackResult)
                : (first.nonEmpty ?? context.fallbackResult)
            selectedDraft = secondScore >= firstScore ? .repaired : .first
        }
        await CharacterFidelityReviewer.recordDecision(
            sourceID: sourceID,
            canon: context.draft.characterCanon,
            prompt: prompt,
            first: firstAudit.fidelity,
            repaired: secondAudit.fidelity,
            selected: selectedDraft
        )
        guard let effect = context.dramaticEffect,
              !StoryDramaticResultValidator.validate(selected, effect: effect).isAcceptable else {
            return selected
        }
        return StoryDramaticResultValidator.landed(selected, effect: effect)
    }
}

protocol GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String
}

struct MLXGossipPageWriter: GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String {
        let isAside = surface.type == .bookAside
        let formName = isAside ? "Aside" : "Gossip Page"
        let sourceID = isAside ? "book-aside" : "gossip-page"
        let prompt = GossipPagePromptBuilder.prompt(for: surface, nowPlaying: RadioAtmosphereContext.current)
        func generate(correction: String? = nil) async throws -> String {
            let response = try await MLXBraidTaskRunner.run(
                prompt: prompt + (correction.map { "\n\nCHARACTER CONTINUITY REPAIR:\n\($0)\nReturn the full \(formName) again." } ?? ""),
                instructions: GossipPagePromptBuilder.instructions(for: surface),
                maxTokens: 420,
                sourceID: sourceID,
                tags: [sourceID],
                temperature: 0.76
            )
            return GossipPagePromptBuilder.clean(response, fallback: surface.payload.body)
        }

        let first = try await generate()
        let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""
        let firstAudit = await CharacterFidelityReviewer.audit(
            prose: first,
            canon: canon,
            context: "\(formName) simulation turns",
            sourceID: sourceID
        )
        guard firstAudit.shouldRepair else {
            await CharacterFidelityReviewer.recordDecision(
                sourceID: sourceID,
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: nil,
                selected: .first
            )
            return first
        }
        let second = (try? await generate(correction: firstAudit.feedback)) ?? first
        let secondAudit = await CharacterFidelityReviewer.audit(
            prose: second,
            canon: canon,
            context: "repaired \(formName) simulation turns",
            sourceID: sourceID
        )
        let useSecond = CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: secondAudit)
        await CharacterFidelityReviewer.recordDecision(
            sourceID: sourceID,
            canon: canon,
            prompt: prompt,
            first: firstAudit,
            repaired: secondAudit,
            selected: useSecond ? .repaired : .first
        )
        return useSecond ? second : first
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

        \(surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? "")

        Chart packet:
        \(surface.payload.body)

        \(surface.payload.metadata["readerLexiconPromptSection"]?.nonEmpty ?? "")

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
        func generate(correction: String? = nil) async throws -> String {
            let response = try await MLXBraidTaskRunner.run(
                prompt: prompt + (correction.map { "\n\nCHARACTER CONTINUITY REPAIR:\n\($0)\nReturn the full research note again." } ?? ""),
                instructions: FacultyResearchPromptBuilder.instructions,
                maxTokens: 420,
                sourceID: "faculty-research",
                tags: ["faculty-research"]
            )
            return FacultyResearchPromptBuilder.clean(response, fallback: surface.payload.body)
        }
        let first = try await generate()
        let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""
        let faculty = surface.payload.metadata["facultyName"] ?? "Support Faculty"
        let firstAudit = await CharacterFidelityReviewer.audit(
            prose: first,
            canon: canon,
            context: "private research folio written by \(faculty)",
            sourceID: "faculty-research"
        )
        guard firstAudit.shouldRepair else {
            await CharacterFidelityReviewer.recordDecision(
                sourceID: "faculty-research",
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: nil,
                selected: .first
            )
            return first
        }
        let second = (try? await generate(correction: firstAudit.feedback)) ?? first
        let secondAudit = await CharacterFidelityReviewer.audit(
            prose: second,
            canon: canon,
            context: "repaired private research folio written by \(faculty)",
            sourceID: "faculty-research"
        )
        let useSecond = CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: secondAudit)
        await CharacterFidelityReviewer.recordDecision(
            sourceID: "faculty-research",
            canon: canon,
            prompt: prompt,
            first: firstAudit,
            repaired: secondAudit,
            selected: useSecond ? .repaired : .first
        )
        return useSecond ? second : first
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
    Format as a real letter: greeting, 2-4 short paragraphs, signoff from the sender, optional P.S. if it fits the voice.
    Avoid generic openings like "I find myself compelled to write", "I have been observing", "my work centers on", or polished academic self-summaries.
    Anchor the letter in one concrete object, weather detail, phrase, or kept page from the packet before naming any idea.
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

        \(surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? "")

        Live web research clippings:
        \(clippings)

        Research source URLs:
        \(sources)\(RadioAtmosphere.promptSection(nowPlaying))\(surface.payload.metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")

        Write the finished letter. It should feel researched, personal, and specific to the sender, but never like a professional biography. Blend real-world facts with the sender's voice and relationship to the player. Open from one concrete thing in the draft packet or clippings before explaining the sender's interest. Give each sender a distinct cadence; do not reuse stock first-letter shapes. For an introduction-stage letter, introduce before escalating: no callbacks, no assumed intimacy, no urgent plot demand. Start with a greeting that uses "\(playerName)" exactly. Never write "[Player Name]". If a chapter talisman move is supplied, make it a real small action or confession in the letter; the app will apply its talisman Belief delta when the letter is kept. If no move is supplied, do not invent one.
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
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        func generate(correction: String? = nil) async throws -> String {
            let response = try await MLXBraidTaskRunner.run(
                prompt: prompt + (correction.map { "\n\nCHARACTER CONTINUITY REPAIR:\n\($0)\nReturn the full letter again." } ?? ""),
                instructions: CharacterLetterPromptBuilder.instructions,
                maxTokens: 620,
                sourceID: "letter-page",
                tags: ["letter", "character-letter"]
            )
            return CharacterLetterPromptBuilder.clean(response, fallback: surface.payload.body, sender: sender, playerName: playerName)
        }
        let first = try await generate()
        let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""
        let firstAudit = await CharacterFidelityReviewer.audit(
            prose: first,
            canon: canon,
            context: "Letter from \(sender) to \(playerName)",
            sourceID: "letter-page"
        )
        guard firstAudit.shouldRepair else {
            await CharacterFidelityReviewer.recordDecision(
                sourceID: "letter-page",
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: nil,
                selected: .first
            )
            return first
        }
        let second = (try? await generate(correction: firstAudit.feedback)) ?? first
        let secondAudit = await CharacterFidelityReviewer.audit(
            prose: second,
            canon: canon,
            context: "repaired letter from \(sender) to \(playerName)",
            sourceID: "letter-page"
        )
        let useSecond = CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: secondAudit)
        await CharacterFidelityReviewer.recordDecision(
            sourceID: "letter-page",
            canon: canon,
            prompt: prompt,
            first: firstAudit,
            repaired: secondAudit,
            selected: useSecond ? .repaired : .first
        )
        return useSecond ? second : first
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
        // Ask capability, then let the memory gate answer affordability. If the
        // device cannot spare the room today it throws, and the caption path
        // below writes the page from Vision facts instead — which is a quieter
        // page, not a broken one. That is a better trade than the old static
        // rule, which decided in advance that a whole class of phone would
        // never look at a photograph at all.
        if LocalModelManager.activeModelSupportsVision {
            do {
                appLog.info("Photo illumination attempting VLM Gemma path.")
                return try await VLMPhotoIlluminationAnalyzer().analyze(photo: photo)
            } catch {
                appLog.error("Vision Gemma photo illumination fell back to caption path: \(error.localizedDescription, privacy: .private)")
            }
        }

        appLog.info("Photo illumination attempting caption-seed Gemma path.")
        return try await CaptionSeedPhotoIlluminationAnalyzer().analyze(photo: photo)
    }
}

struct CaptionSeedPhotoIlluminationAnalyzer: PhotoIlluminationAnalyzing {
    func analyze(photo: UIImage) async throws -> PhotoAnalysis {
        // No pre-downsample here: the extractor scales to its own working size,
        // and shrinking first only costs the saliency crops their detail.
        let (packet, seed) = await VisionPhotoCaptioner().read(photo: photo)
        let fallback = PhotoAnalysis.fallback(for: seed)
        let prompt = PhotoIlluminationPromptBuilder.prompt(for: packet, seed: seed)
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
    static func prompt(for packet: VisualFactPacket, seed: PhotoCaptionSeed) -> String {
        // The hedges in the grounding block are load-bearing. Penny may write
        // freely *about* a clearly-seen cat and must write around a "maybe" —
        // that is the difference between an odd, affectionate page and a
        // confident page about something that was never there.
        let thinness = packet.isThin
            ? """

            THE EYE SAW LITTLE THIS TIME.
            Write smaller. Lean on the light, the colour, and the shape of the frame.
            Do not name a subject. A short, quiet page is correct here; an invented one is not.
            """
            : ""

        return """
        You are Penny Blackletter, field-note scribe for The Academy of Unlikely Arts.
        Write lively marginalia for an illuminated photo page using ONLY the observations below.
        Do not mention anything outside them, except "The Book" in closing_line.
        Refer to people only as "the subject" or "good company." Never guess names, identities, relationships, exact locations, brands, or events.

        \(packet.promptGrounding)
        HOW SURE TO SOUND:
        - "clearly" — you may name it plainly and give it a small job.
        - "probably" — name it, but let the line carry a little doubt.
        - "maybe" — do not name it outright. Write around it, or leave it out.
        - Never state something the list does not contain. Never upgrade a maybe.
        \(thinness)
        - suggested_template: \(seed.suggestedTemplate.rawValue)

        PENNY'S VOICE:
        - observant, dry, affectionate, a little odd.
        - Make objects seem to have tiny jobs, opinions, or responsibilities.
        - Prefer concrete nouns plus small active verbs.
        - Good: "Blue light kept watch", "Grass, gossiping underfoot", "One chair held the treaty".
        - Bad: "Nice outdoor scene", "A pleasant memory", "Beautiful moment", "Photo looks warm".
        - No generic inspiration. No greeting-card wisdom. No assistant voice.

        RULES:
        - Every line names one observation from the list above.
        - Light and colour set the tone; the named things carry the detail.
        - If readable text is present, you may quote one or two words of it exactly.
        - Short, dry, affectionate, slightly odd, and specific.
        - If the facts are sparse, keep the caption simple.
        - Give at least three observation_list items a verb.
        - field_note under 8 words.
        - stamp_label 2-3 words, title-like, no names.
        - observation_list exactly 5 items, each under 6 words.
        - closing_line under 10 words and include "I kept".
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

        EXAMPLE STYLE FROM A THIN READING:
        Saw: clearly: water. probably: boat, centre. maybe: sky. light: bright light.
        {"scene":"A bright landscape photo with water, boat, and sky.","motifs":["water","boat","sky","light"],"mood":"salt and bright","suggested_template":"\(seed.suggestedTemplate.rawValue)","marginalia":{"field_note":"Boat, practicing patience.","stamp_label":"Dockside Census","observation_list":["Water held the minutes","Sky widened its pockets","Boat waited without complaint","Bright light kept watch","Edges smelled faintly of salt"],"closing_line":"The Book kept the page: tide listened."},"souvenir_candidates":["The water arranged its evidence in plain sight.","A boat waited there like patience had a hull."]}
        """
    }
}

struct VLMPhotoIlluminationAnalyzer: PhotoIlluminationAnalyzing {
    /// Comfortably above every processor size we ship against (Gemma 4 asks for
    /// 800x800), so the model never sees an upsample, while still keeping the
    /// CIImage we carry through the resample small.
    static let visionInputCeiling: CGFloat = 1_024

    func analyze(photo: UIImage) async throws -> PhotoAnalysis {
        guard let modelDirectory = LocalModelManager.activeModelDirectory else {
            throw LocalModelError.missingModel(LocalModelManager.report())
        }

        // The processor resamples to its own configured size (800x800 for Gemma 4)
        // and derives the patch count from that, not from what we hand it. So
        // downsampling below that ceiling buys no tokens and no memory — it only
        // hands the vision tower a blurred upsample of our own making, which is
        // how a cat becomes "indoors, textile". Stay above the target and let the
        // processor do the one resample it was tuned for.
        let downsampled = photo.downsampledForLocalBrain(maxSide: Self.visionInputCeiling)
        appLog.info("Photo illumination image downsampled from \(Int(photo.size.width))x\(Int(photo.size.height)) to \(Int(downsampled.size.width))x\(Int(downsampled.size.height))")
        let image = try UserInput.Image.ciImage(ciImage(from: downsampled))
        let prompt = LocalModelManager.photoIlluminationPrompt
        let response = try await LocalBrainInferenceGate.shared.run(
            label: "photo-illumination",
            promptCharacters: prompt.count,
            carriesImage: true
        ) {
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
                    )
                    // No `processing:` override on purpose. Gemma4Processor
                    // overwrites `resize` with its own configured size, so a
                    // value here is silently discarded — and if a future
                    // checkpoint did honour it, forcing a size the vision tower
                    // was not trained for is the last thing we want.
                )
                return try await LocalBrainGenerationLifecycle.saving(
                    {
                        try await session.respond(
                            to: prompt,
                            image: image,
                            video: nil
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    },
                    thenRefreshing: session,
                    label: "photo-illumination"
                )
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

/// Apple Vision, demoted from "the eye" to a bench of specialists.
///
/// The old pass asked one permissive whole-image classifier what the picture
/// was and took the top eight guesses. That is why a photograph of a cat on a
/// blanket came back as "indoors, furniture, textile": the classifier answers
/// about the *frame*, and a cat that occupies a fifth of it loses to the room it
/// is sitting in. The fix is not a better single question — it is asking
/// several narrow ones and letting the dedicated recognizers outrank the guess.
// The Apple Vision ensemble is lifted out of this file's MLX guard on purpose.
// It uses no MLX and no language model — it is Apple's Vision framework and
// nothing else — so gating it on `NATIVE_LOCAL_BRAIN && !targetEnvironment(
// simulator)` compiled the whole ensemble out of every Simulator build and out
// of any device without MLX. `CapturePageSheet.attentionMetadata` guards only
// on `canImport(Vision)`, which is true in exactly those builds, so it
// referenced a type that had been compiled away.
#endif

#if canImport(Vision)
/// Gathers what each request found. Vision calls completion handlers
/// synchronously during `perform`, on the thread that called it, so plain
/// accumulation is safe here — the class exists to give the handlers a shared
/// destination, not to add locking.
final class VisionFactCollector {
    private(set) var facts: [VisualFact] = []
    private(set) var regions: [(VisualRegion, Float)] = []

    func add(_ newFacts: [VisualFact]) {
        facts += newFacts
    }

    func add(regions newRegions: [(VisualRegion, Float)]) {
        regions += newRegions
    }
}

struct VisionFactExtractor {
    /// Vision works from a scaled copy; the passes here are all
    /// resolution-tolerant, and this keeps saliency cropping cheap.
    static let workingSide: CGFloat = 768

    /// Below this the classifier is guessing at noise. Kept low because a weak
    /// label still becomes an honest "maybe" in the packet rather than a claim.
    private static let classifierFloor: Float = 0.16
    /// A crop is only worth classifying if saliency thought it was a thing.
    private static let saliencyFloor: Float = 0.2
    private static let maximumCrops = 3

    func facts(for photo: UIImage) async -> VisualFactPacket {
        let image = photo.downsampledForLocalBrain(maxSide: Self.workingSide)
        let orientation: PhotoOrientation = image.size.width > image.size.height * 1.12
            ? .landscape
            : (image.size.height > image.size.width * 1.12 ? .portrait : .square)

        guard let cgImage = image.cgImage else {
            return VisualFactPacket(
                uncertainty: ["the photograph could not be read at all"],
                orientation: orientation,
                backends: ["none"]
            )
        }

        let statistics = Self.statisticsFacts(for: image)

        return await Task.detached(priority: .userInitiated) {
            // One handler, one perform, all passes. Vision shares intermediate
            // work across requests submitted together, and a handler is not
            // documented as safe to drive from several threads at once — so
            // batching is both the faster and the correct way to ask.
            let collector = VisionFactCollector()
            let requests: [VNRequest] = [
                Self.classifyRequest(source: .appleVisionClassifier, region: nil, limit: 8, into: collector),
                Self.animalRequest(into: collector),
                Self.humanRequest(into: collector),
                Self.faceRequest(into: collector),
                Self.textRequest(into: collector),
                Self.attentionSaliencyRequest(into: collector),
                Self.objectnessSaliencyRequest(into: collector)
            ]
            try? VNImageRequestHandler(cgImage: cgImage).perform(requests)

            var facts = collector.facts + statistics
            let regions = Self.rankedRegions(collector.regions)

            // Classify what saliency thought mattered. This is the pass that
            // actually recovers a small subject: the crop puts the cat in the
            // whole frame, so the classifier is finally being asked about it
            // instead of about the sofa around it.
            for region in regions {
                guard let crop = Self.crop(cgImage: cgImage, to: region) else { continue }
                let cropCollector = VisionFactCollector()
                let request = Self.classifyRequest(
                    source: .appleVisionSaliencyCrop,
                    region: region,
                    limit: 2,
                    into: cropCollector
                )
                try? VNImageRequestHandler(cgImage: crop).perform([request])
                facts += cropCollector.facts
            }

            var packet = VisualFactPacket(
                facts: facts,
                orientation: orientation,
                backends: ["apple-vision-ensemble-v1"]
            )
            packet.uncertainty = Self.uncertainty(for: packet, salientRegions: regions.count)
            return packet
        }.value
    }

    // MARK: - Passes

    private static func classifyRequest(
        source: VisualFactSource,
        region: VisualRegion?,
        limit: Int,
        into collector: VisionFactCollector
    ) -> VNRequest {
        VNClassifyImageRequest { request, _ in
            let observations = (request.results as? [VNClassificationObservation]) ?? []
            collector.add(
                observations
                    .filter { $0.confidence >= classifierFloor }
                    .prefix(limit)
                    .flatMap { observation -> [VisualFact] in
                        // Vision hands back comma-joined synonym lists; each
                        // synonym is the same claim, so they share the score.
                        observation.identifier
                            .split(separator: ",")
                            .prefix(2)
                            .map { synonym in
                                VisualFact(
                                    kind: region == nil ? .setting : .object,
                                    label: String(synonym),
                                    confidence: Double(observation.confidence),
                                    source: source,
                                    region: region
                                )
                            }
                    }
            )
        }
    }

    /// The pass the old pipeline never ran, and the single biggest reason it
    /// could not see a pet.
    private static func animalRequest(into collector: VisionFactCollector) -> VNRequest {
        VNRecognizeAnimalsRequest { request, _ in
            let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
            collector.add(observations.flatMap { observation in
                observation.labels.prefix(1).map { label in
                    VisualFact(
                        kind: .animal,
                        label: label.identifier,
                        confidence: Double(label.confidence),
                        source: .appleVisionAnimal,
                        region: VisualRegion(observation.boundingBox)
                    )
                }
            })
        }
    }

    private static func humanRequest(into collector: VisionFactCollector) -> VNRequest {
        VNDetectHumanRectanglesRequest { request, _ in
            collector.add(((request.results as? [VNHumanObservation]) ?? []).map { observation in
                VisualFact(
                    kind: .person,
                    label: "a person",
                    confidence: Double(observation.confidence),
                    source: .appleVisionHuman,
                    region: VisualRegion(observation.boundingBox)
                )
            })
        }
    }

    /// Faces are kept separate from bodies because they answer a different
    /// question for the caption: whether anyone is *facing* the photograph.
    private static func faceRequest(into collector: VisionFactCollector) -> VNRequest {
        VNDetectFaceRectanglesRequest { request, _ in
            collector.add(((request.results as? [VNFaceObservation]) ?? []).map { observation in
                VisualFact(
                    kind: .person,
                    label: "a face turned to the camera",
                    confidence: Double(observation.confidence),
                    source: .appleVisionFace,
                    region: VisualRegion(observation.boundingBox)
                )
            })
        }
    }

    private static func textRequest(into collector: VisionFactCollector) -> VNRequest {
        let request = VNRecognizeTextRequest { request, _ in
            collector.add(((request.results as? [VNRecognizedTextObservation]) ?? [])
                .prefix(6)
                .compactMap { observation -> VisualFact? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let string = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !string.isEmpty else { return nil }
                    return VisualFact(
                        kind: .visibleText,
                        label: string,
                        confidence: Double(candidate.confidence),
                        source: .appleVisionText,
                        region: VisualRegion(observation.boundingBox)
                    )
                })
        }
        // Accurate rather than fast: this text is quoted onto the page, so a
        // misread word becomes a misquote the reader will notice.
        request.recognitionLevel = .accurate
        return request
    }

    /// Attention saliency finds what a person's eye goes to; objectness finds
    /// discrete things. Running both catches the small centred subject and the
    /// off-centre one.
    private static func attentionSaliencyRequest(into collector: VisionFactCollector) -> VNRequest {
        VNGenerateAttentionBasedSaliencyImageRequest { request, _ in
            collector.add(regions: salientObjects(in: request))
        }
    }

    private static func objectnessSaliencyRequest(into collector: VisionFactCollector) -> VNRequest {
        VNGenerateObjectnessBasedSaliencyImageRequest { request, _ in
            collector.add(regions: salientObjects(in: request))
        }
    }

    private static func salientObjects(in request: VNRequest) -> [(VisualRegion, Float)] {
        let observations = (request.results as? [VNSaliencyImageObservation]) ?? []
        return observations.flatMap { observation in
            (observation.salientObjects ?? [])
                .filter { $0.confidence >= saliencyFloor }
                .map { (VisualRegion($0.boundingBox), $0.confidence) }
        }
    }

    /// A region covering nearly the whole frame tells us nothing the
    /// whole-image pass did not already say, and two passes agreeing on one cat
    /// should not spend both crop budgets on it.
    private static func rankedRegions(_ regions: [(VisualRegion, Float)]) -> [VisualRegion] {
        regions
            .filter { $0.0.area >= 0.02 && $0.0.area <= 0.85 }
            .sorted { $0.1 > $1.1 }
            .reduce(into: [VisualRegion]()) { kept, candidate in
                guard kept.count < maximumCrops else { return }
                guard !kept.contains(where: { $0.overlaps(candidate.0) }) else { return }
                kept.append(candidate.0)
            }
    }

    // MARK: - Support

    private static func crop(cgImage: CGImage, to region: VisualRegion) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        // Vision's origin is bottom-left; CoreGraphics cropping is top-left.
        // Pad a little so the crop keeps the context that makes a subject
        // legible rather than shaving it to its own silhouette.
        let padding = 0.08
        let x = max(0, region.x - padding)
        let y = max(0, region.y - padding)
        let right = min(1, region.x + region.width + padding)
        let top = min(1, region.y + region.height + padding)
        let rect = CGRect(
            x: x * width,
            y: (1 - top) * height,
            width: (right - x) * width,
            height: (top - y) * height
        )
        guard rect.width >= 24, rect.height >= 24 else { return nil }
        return cgImage.cropping(to: rect)
    }

    private static func statisticsFacts(for image: UIImage) -> [VisualFact] {
        // These are measured, not guessed, so they are stated plainly — but
        // they are also the least *interesting* facts in the packet, which is
        // why they carry no source bonus and never win the subject slot.
        [
            VisualFact(
                kind: .light,
                label: image.averageBrightnessLabel,
                confidence: 0.9,
                source: .imageStatistics
            ),
            VisualFact(
                kind: .colour,
                label: image.dominantColorMood,
                confidence: 0.9,
                source: .imageStatistics
            )
        ]
    }

    /// Say plainly what the ensemble could not settle. The literary pass reads
    /// this to decide whether to write small.
    private static func uncertainty(for packet: VisualFactPacket, salientRegions: Int) -> [String] {
        var notes: [String] = []
        if packet.primarySubject == nil {
            notes.append("no clear subject — do not name one")
        } else if packet.primarySubject?.certainty == .possible {
            notes.append("the subject is a guess, not a reading")
        }
        if salientRegions == 0 && packet.animals.isEmpty && packet.people.isEmpty {
            notes.append("nothing stood out from the background")
        }
        if packet.visibleText.contains(where: { $0.certainty == .possible }) {
            notes.append("some text is present but not reliably legible")
        }
        if packet.facts(of: .setting).isEmpty {
            notes.append("the setting is unclear")
        }
        return notes
    }
}

extension VisualRegion {
    init(_ boundingBox: CGRect) {
        self.init(
            x: Double(boundingBox.origin.x),
            y: Double(boundingBox.origin.y),
            width: Double(boundingBox.width),
            height: Double(boundingBox.height)
        )
    }

    /// Rough intersection-over-smaller test, used to stop two saliency passes
    /// from spending both crop budgets on the same cat.
    func overlaps(_ other: VisualRegion, threshold: Double = 0.5) -> Bool {
        let left = max(x, other.x)
        let right = min(x + width, other.x + other.width)
        let bottom = max(y, other.y)
        let top = min(y + height, other.y + other.height)
        guard right > left, top > bottom else { return false }
        let intersection = (right - left) * (top - bottom)
        let smaller = min(area, other.area)
        guard smaller > 0 else { return false }
        return intersection / smaller >= threshold
    }
}
#endif

// Back inside the MLX guard the rest of this file expects.
#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)

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
    /// The packet is what the prompt and the archive want; the seed is what the
    /// template chooser and the deterministic fallback prose want. Both come
    /// from one perception pass, so they can never disagree about the photo.
    func read(photo: UIImage) async -> (packet: VisualFactPacket, seed: PhotoCaptionSeed) {
        #if canImport(Vision)
        let packet = await VisionFactExtractor().facts(for: photo)
        return (packet, Self.seed(from: packet, image: photo))
        #else
        let packet = VisualFactPacket(backends: ["unavailable"])
        return (packet, Self.seed(from: packet, image: photo))
        #endif
    }

    func caption(photo: UIImage) async throws -> PhotoCaptionSeed {
        await read(photo: photo).seed
    }

    /// Flatten a packet into the label-shaped world the existing template and
    /// fallback code was written against. Ordering matters: facts arrive
    /// weighted, so a recognised animal leads the list and the template chooser
    /// sees "cat" before it sees "furniture".
    static func seed(from packet: VisualFactPacket, image: UIImage) -> PhotoCaptionSeed {
        let labels = packet.facts
            .filter { $0.kind != .visibleText && $0.kind != .light && $0.kind != .colour }
            .map(\.label)
        let visibleText = packet.visibleText
            .prefix(4)
            .map(\.label)
            .joined(separator: " | ")
        return seed(
            from: labels,
            peopleCount: packet.people.filter { $0.source == .appleVisionHuman }.count,
            faceCount: packet.people.filter { $0.source == .appleVisionFace }.count,
            image: image,
            visibleText: visibleText
        )
    }

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

#endif

// Pure image utilities — no MLX, no model, just CoreGraphics. Kept outside the
// MLX guard so the Apple Vision ensemble above can still use them on Simulator.
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
                closingLine: "I opened a margin around this moment."
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
            appLog.error("Local braid fell back: \(error.localizedDescription, privacy: .private)")
            var page = try await fallback.braid(day: day, context: context)
            page.promptText = "I took the pencil back and braided the page myself."
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
            appLog.error("Wonder Compass selection fell back: \(error.localizedDescription, privacy: .private)")
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
                sourceName: URL(string: result.url)?.host?
                    .replacingOccurrences(of: "www.", with: "")
                    .nonEmpty ?? result.title,
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

/// One small network window shared by every rebuild. Successful findings rest
/// in memory for a day; an empty search rests for an hour. The query plan comes
/// from shared, inspectable Long Game policy and contains no private Page text.
actor BookFoundGiftFinder {
    static let shared = BookFoundGiftFinder()

    private struct CacheEntry {
        var thing: BookFoundWebThing?
        var fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]

    func find(for plan: BookFoundGiftPlan, now: Date = Date()) async -> BookFoundWebThing? {
        guard plan.realm == .publicWeb, !plan.searchQueries.isEmpty else { return nil }
        // Relationship plans can share the same Long Game capacity while
        // carrying entirely different public queries. Key by the inspectable
        // plan, never merely by capacity, or one person's find can leak into
        // another person's page.
        let cacheKey = "\(plan.capacity.rawValue)|\(plan.searchQueries.joined(separator: "|"))"
        if let cached = cache[cacheKey] {
            let lifetime: TimeInterval = cached.thing == nil ? 3_600 : 24 * 3_600
            if now.timeIntervalSince(cached.fetchedAt) < lifetime {
                return cached.thing
            }
        }

        for query in plan.searchQueries {
            let results = await WebSearchFallback().clippings(for: query, limit: 3)
            if let clipping = results.first(where: acceptable) {
                let title = clipping.fact
                    .components(separatedBy: ". ")
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty ?? clipping.sourceName
                let thing = BookFoundWebThing(
                    title: title,
                    excerpt: clipping.fact,
                    sourceName: clipping.sourceName,
                    sourceURL: clipping.sourceURL,
                    searchQuery: query
                )
                cache[cacheKey] = CacheEntry(thing: thing, fetchedAt: now)
                return thing
            }
        }
        cache[cacheKey] = CacheEntry(thing: nil, fetchedAt: now)
        return nil
    }

    private func acceptable(_ clipping: RealInterestGossipClipping) -> Bool {
        guard clipping.fact.count >= 48,
              let url = URL(string: clipping.sourceURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased(),
              !host.contains("duckduckgo.com") else {
            return false
        }
        return true
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

    func clippings(
        from facts: [SelfFact],
        dayID: String,
        slotID: String,
        allowsPersonalizedNetworkSearch: Bool = false
    ) async -> [RealInterestGossipClipping] {
        guard allowsPersonalizedNetworkSearch else { return [] }
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
        metadata["storyTurnCount"] = "\(context.turnCount + 1)"
        metadata["storyPreviousScene"] = context.latestScene
        metadata["storySelectedChoiceID"] = context.latestChoice.id
        metadata["storySelectedChoiceTitle"] = context.latestChoice.title
        metadata["storySelectedChoicePrompt"] = context.latestChoice.prompt
        metadata["storySelectedResult"] = context.latestResult
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
            id: "\(id)-continued-\(context.turnCount + 1)",
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

    func preparedNoteCopy(prose: String, slotID: String) -> SurfacePage {
        var metadata = payload.metadata
        metadata["slotID"] = slotID
        metadata["noteProse"] = prose
        metadata["proseStatus"] = "generated"
        return SurfacePage(
            id: "\(id)-opened-\(slotID)",
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
    Lived pages own what happened. Generated fiction may supply faerie pressure and correspondence, but it may never overrule the reader's record.
    Follow the supplied Tale Reading. Use its one narrative motion and one faerie pressure; do not force a conventional turn when the honest motion is a vigil or absence.
    Most things remain ordinary. If one supplied thing becomes strange, give its strangeness a rule, cost, refusal, recognition, or consequence. State the impossible plainly and never explain it.
    Keep the ritual ending exactly as requested. Mention each image or emotional beat once.
    \(BookVoice.animismLine)
    Prose standard: varied literary cadence, exact supplied physical details, plain strong verbs, and endings that land softly but sharply. No vague wonder, stock moth/moon/lamp magic, or abstract emotional summary.
    Style compass: a contemporary domestic faerie tale told with magical-realist restraint, dark playfulness, and sideways humor.
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
        tags: [String],
        temperature: Float = 0.68,
        topP: Float = 0.9
    ) async -> String? {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
        guard LocalModelManager.report().state == .ready else { return nil }
        let response = try? await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: instructions,
            maxTokens: maxTokens,
            sourceID: sourceID,
            tags: tags,
            temperature: temperature,
            topP: topP
        )
        return response?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        #else
        return nil
        #endif
    }
}

struct CharacterFidelityAudit: Equatable {
    enum Verdict: String, Codable, Equatable {
        case pass
        case repair
        case unavailable
    }

    var verdict: Verdict
    var feedback: String
    var score: Int

    var passed: Bool { verdict == .pass }
    var shouldRepair: Bool { verdict == .repair }
    var wasUnavailable: Bool { verdict == .unavailable }

    static let pass = CharacterFidelityAudit(verdict: .pass, feedback: "", score: 100)
    static let unavailable = CharacterFidelityAudit(
        verdict: .unavailable,
        feedback: "The character continuity editor was unavailable.",
        score: 0
    )

    static func parse(_ raw: String?) -> CharacterFidelityAudit {
        guard let raw = raw?
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        else {
            return .unavailable
        }
        let firstLine = raw
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        if firstLine == "PASS" {
            return .pass
        }
        let feedback = raw
            .replacingOccurrences(of: #"(?i)^\s*(REPAIR|FAIL)\s*:?\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let issueCount = max(1, feedback.components(separatedBy: "\n-").count)
        return CharacterFidelityAudit(
            verdict: .repair,
            feedback: feedback.nonEmpty ?? "The speaking characters are not yet distinct enough.",
            score: max(10, 65 - issueCount * 10)
        )
    }
}

struct CharacterFidelityReceipt: Codable, Equatable, Identifiable {
    enum SelectedDraft: String, Codable {
        case first
        case repaired
    }

    var id: String
    var createdAt: Date
    var sourceID: String
    var characterIDs: [String]
    var canonVersion: String
    var firstVerdict: CharacterFidelityAudit.Verdict
    var firstScore: Int
    var repairAttempted: Bool
    var repairedVerdict: CharacterFidelityAudit.Verdict?
    var repairedScore: Int?
    var selectedDraft: SelectedDraft
    var estimatedPromptTokens: Int?
}

actor CharacterFidelityReceiptStore {
    static let shared = CharacterFidelityReceiptStore()
    static let defaultsKey = "characterFidelityReceipts.v1"
    static let capacity = 240

    private var receipts: [CharacterFidelityReceipt]

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([CharacterFidelityReceipt].self, from: data) {
            receipts = decoded
        } else {
            receipts = []
        }
    }

    func record(_ receipt: CharacterFidelityReceipt, defaults: UserDefaults = .standard) {
        receipts.append(receipt)
        if receipts.count > Self.capacity {
            receipts.removeFirst(receipts.count - Self.capacity)
        }
        if let data = try? JSONEncoder().encode(receipts) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    func recent(limit: Int = 80) -> [CharacterFidelityReceipt] {
        Array(receipts.suffix(max(0, limit)))
    }
}

enum CharacterFidelityReviewer {
    static func audit(
        prose: String,
        canon: String,
        context: String,
        sourceID: String
    ) async -> CharacterFidelityAudit {
        guard let canon = canon.nonEmpty,
              !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unavailable
        }
        let response = await LocalBrainProse.write(
            prompt: """
            Audit this generated ReEnchanted fiction against the binding character canon.

            \(canon)

            SURFACE:
            \(context)

            PROSE TO AUDIT:
            \(prose)

            Judge only characters who actually speak or act in the prose. Do not demand that every supplied character appear. A faithful performance expresses values, wants, blind spots, habits, rhythm, and diction through behavior; it does not need to quote profile words or use catchphrases. Fail interchangeable dialogue, swapped traits, contradicted beliefs without story pressure, generic assistant speech, biography-like exposition, or a character acting against a core value for no supplied reason.

            Return exactly PASS if the performance is faithful and distinct.
            Otherwise return:
            REPAIR:
            - one or more short, actionable corrections naming the affected character
            """,
            instructions: """
            You are ReEnchanted's strict character continuity editor. Audit only; do not rewrite the prose. Treat supplied canon as binding and current scene context as permission for temporary tension, not personality replacement.
            """,
            maxTokens: 220,
            sourceID: "\(sourceID)-character-audit",
            tags: ["character-fidelity", "continuity-audit"],
            temperature: 0,
            topP: 1
        )
        return CharacterFidelityAudit.parse(response)
    }

    static func prefersRepairedDraft(
        first: CharacterFidelityAudit,
        repaired: CharacterFidelityAudit
    ) -> Bool {
        if repaired.passed { return true }
        if first.passed { return false }
        if repaired.score != first.score {
            return repaired.score > first.score
        }
        if first.wasUnavailable && repaired.wasUnavailable { return false }
        return true
    }

    static func recordDecision(
        sourceID: String,
        canon: String,
        prompt: String? = nil,
        first: CharacterFidelityAudit,
        repaired: CharacterFidelityAudit?,
        selected: CharacterFidelityReceipt.SelectedDraft
    ) async {
        let receipt = CharacterFidelityReceipt(
            id: UUID().uuidString,
            createdAt: Date(),
            sourceID: sourceID,
            characterIDs: CharacterCanonPacket.characterIDs(in: canon),
            canonVersion: CharacterCanonPacket.version,
            firstVerdict: first.verdict,
            firstScore: first.score,
            repairAttempted: repaired != nil,
            repairedVerdict: repaired?.verdict,
            repairedScore: repaired?.score,
            selectedDraft: selected,
            estimatedPromptTokens: prompt.map(LocalBrainPromptBudget.estimatedTokens)
        )
        await CharacterFidelityReceiptStore.shared.record(receipt)
        if CharacterGenerationRouteRegistry.contract(for: sourceID)?.enforcement == .sharedCanonAndAudit,
           receipt.characterIDs.isEmpty {
            appLog.error(
                "Character generation route \(sourceID, privacy: .public) reached its decision without a character canon packet."
            )
        }
        appLog.info(
            "Character fidelity decision \(sourceID, privacy: .public); cast count: \(receipt.characterIDs.count, privacy: .public); first: \(receipt.firstVerdict.rawValue, privacy: .public); repaired: \(receipt.repairedVerdict?.rawValue ?? "none", privacy: .public); selected: \(selected.rawValue, privacy: .public)"
        )
    }
}

#if DEBUG
struct CharacterVoiceEvaluationReport: Codable, Equatable {
    struct Sample: Codable, Equatable {
        var scenarioID: String
        var repetition: Int
        var characterIDs: [String]
        var prose: String
        var nameHiddenProse: String
        var auditVerdict: CharacterFidelityAudit.Verdict
        var auditScore: Int
        var auditFeedback: String
    }

    var createdAt: Date
    var modelID: String
    var repetitions: Int
    var samples: [Sample]
    var savedPath: String?
}

/// Repeatable, synthetic on-device evaluation. It never inserts archive text,
/// reader facts, location, or other private context. The saved report is meant
/// for blinded human comparison; the same-model audit is included as a useful
/// signal, not treated as proof of voice quality.
enum CharacterVoiceE2BEvaluationRunner {
    static func run(repetitions: Int = 3) async -> CharacterVoiceEvaluationReport {
        let repetitions = max(1, min(repetitions, 5))
        var samples: [CharacterVoiceEvaluationReport.Sample] = []
        for scenario in CharacterVoiceEvaluationDeck.scenarios {
            let entities = NarrativePackRegistry.entities.filter {
                scenario.characterIDs.contains($0.id)
            }
            let canon = CharacterCanonPacket.promptSection(
                for: entities,
                contextLines: [
                    "Synthetic evaluation only. \(scenario.scene)",
                    "Identification clues: \(scenario.identificationClues.joined(separator: "; "))",
                    "Forbidden voice transfers: \(scenario.forbiddenTransfers.joined(separator: "; "))"
                ]
            )
            for repetition in 1...repetitions {
                let prompt = """
                DEVELOPMENT CHARACTER VOICE EVALUATION
                Surface: \(scenario.surface)
                Scene: \(scenario.scene)

                \(canon)

                Write 120-180 words of finished in-world prose. Every listed character must speak or act. Make the voices identifiable if their names are later hidden. Do not mention evaluation, canon, prompts, traits, or voice cards.
                """
                let prose = await LocalBrainProse.write(
                    prompt: prompt,
                    instructions: "Write only the synthetic ReEnchanted scene. This contains no reader data.",
                    maxTokens: 360,
                    sourceID: "character-voice-eval-\(scenario.id)",
                    tags: ["development-evaluation", "character-voice", "synthetic"],
                    temperature: 0.76,
                    topP: 0.9
                ) ?? ""
                let audit = await CharacterFidelityReviewer.audit(
                    prose: prose,
                    canon: canon,
                    context: "synthetic evaluation \(scenario.id), repetition \(repetition)",
                    sourceID: "character-voice-eval"
                )
                samples.append(
                    .init(
                        scenarioID: scenario.id,
                        repetition: repetition,
                        characterIDs: scenario.characterIDs,
                        prose: prose,
                        nameHiddenProse: hideNames(in: prose, entities: entities),
                        auditVerdict: audit.verdict,
                        auditScore: audit.score,
                        auditFeedback: audit.feedback
                    )
                )
            }
        }
        var report = CharacterVoiceEvaluationReport(
            createdAt: Date(),
            modelID: LocalModelManager.report().preferredModelID,
            repetitions: repetitions,
            samples: samples,
            savedPath: nil
        )
        report.savedPath = save(report: report)?.path
        return report
    }

    private static func hideNames(
        in prose: String,
        entities: [NarrativeWorldEntity]
    ) -> String {
        entities.enumerated().reduce(prose) { text, pair in
            text.replacingOccurrences(
                of: pair.element.name,
                with: "Speaker \(speakerLabel(pair.offset))",
                options: [.caseInsensitive]
            )
        }
    }

    private static func speakerLabel(_ index: Int) -> String {
        let labels = ["A", "B", "C", "D", "E"]
        return labels[index % labels.count]
    }

    private static func save(report: CharacterVoiceEvaluationReport) -> URL? {
        guard let data = try? JSONEncoder.characterVoiceEvaluation.encode(report) else {
            return nil
        }
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = base.appendingPathComponent(
            "CharacterVoiceEvaluations",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let formatter = ISO8601DateFormatter()
            let filename = formatter.string(from: report.createdAt)
                .replacingOccurrences(of: ":", with: "-")
            let url = directory.appendingPathComponent(
                "character-voice-\(filename).json"
            )
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            appLog.error(
                "Could not save character voice evaluation: \(error.localizedDescription, privacy: .private)"
            )
            return nil
        }
    }
}

private extension JSONEncoder {
    static var characterVoiceEvaluation: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
#endif

struct StudentNoteWriter {
    func write(surface: SurfacePage) async -> String {
        let prompt = prompt(for: surface)
        let instructions = """
        You are writing a quick in-world student note for ReEnchanted.
        Write as the named sender, not as an assistant. This is a folded scrap passed in class or a corridor, not a formal letter.
        Treat the supplied CHARACTER CANON packet as binding. Perform the sender's whole character—their beliefs, wants, blind spots, habits, interests, relationships, memories, rhythm, and diction—not just a recognizable voice.
        When the draft packet supplies a REQUIRED KEPT-PAGE SUBJECT, the note must clearly be about that exact subject. It is the reason for writing, not decorative context. Let who the sender is determine what the kept page means to them.
        Keep it intimate, brief, and specific: 2-6 short lines, one concrete kept-page detail when supplied, and a small reason to reply.
        The sender may tease, ask, warn, confess around the edge, pass gossip, invite, or check in.
        Reader-authored words may be echoed or quoted briefly. Events from a kept Story Page, Fae bargain, parley, or other fiction are in-world events; do not recast them as real-world actions by the player.
        Do not invent completed real-world actions by the player. Do not diagnose, prescribe, or moralize.
        Do not include headings, labels, citations, or markdown.
        """
        if let response = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 260,
            sourceID: "student-notes",
            tags: ["note", "student-note", "character-note"]
        ) {
            let first = sanitize(response, fallback: fallback(surface: surface))
            let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""
            let sender = surface.payload.metadata["senderName"] ?? "the sender"
            let firstUsesSubject = usesRequiredSubject(first, surface: surface)
            let firstAudit = await CharacterFidelityReviewer.audit(
                prose: first,
                canon: canon,
                context: auditContext(for: surface, sender: sender),
                sourceID: "student-notes"
            )
            if firstAudit.shouldRepair || !firstUsesSubject,
               let repaired = await LocalBrainProse.write(
                    prompt: """
                    \(prompt)

                    REPAIR THE NOTE:
                    \(firstAudit.shouldRepair ? "- Character continuity: \(firstAudit.feedback)" : "- Preserve the sender's character performance.")
                    \(firstUsesSubject ? "- Preserve the concrete kept-page subject." : "- The first draft dropped the required kept-page subject. Make that exact kept thing the clear reason this character wrote.")
                    Return the full note again.
                    """,
                    instructions: instructions,
                    maxTokens: 260,
                    sourceID: "student-notes",
                    tags: ["note", "student-note", "character-note", "character-repair"]
               ) {
                let second = sanitize(repaired, fallback: first)
                let secondAudit = await CharacterFidelityReviewer.audit(
                    prose: second,
                    canon: canon,
                    context: auditContext(for: surface, sender: sender),
                    sourceID: "student-notes"
                )
                let secondUsesSubject = usesRequiredSubject(second, surface: surface)
                let useSecond = secondUsesSubject && (
                    !firstUsesSubject ||
                    CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: secondAudit)
                )
                await CharacterFidelityReviewer.recordDecision(
                    sourceID: "student-notes",
                    canon: canon,
                    prompt: prompt,
                    first: firstAudit,
                    repaired: secondAudit,
                    selected: useSecond ? .repaired : .first
                )
                if useSecond {
                    return second
                }
                if !firstUsesSubject {
                    return fallback(surface: surface)
                }
            } else {
                await CharacterFidelityReviewer.recordDecision(
                    sourceID: "student-notes",
                    canon: canon,
                    prompt: prompt,
                    first: firstAudit,
                    repaired: nil,
                    selected: .first
                )
            }
            return first
        }
        return fallback(surface: surface)
    }

    private func prompt(for surface: SurfacePage) -> String {
        """
        Draft packet:
        \(surface.payload.body)

        \(surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? "")

        Write the finished note now. It should feel like it was folded small enough to pass under a desk. It may begin without a greeting. It should sound like \(surface.payload.metadata["senderName"] ?? "the sender"), with a trace of the delivery context: \(surface.payload.metadata["deliveryContext"] ?? "between classes"). If the player previously replied, refer to that reply once, obliquely, as remembered paper.
        """
    }

    private func auditContext(for surface: SurfacePage, sender: String) -> String {
        let subject = surface.payload.metadata["meaningfulSourcePassage"]?.nonEmpty
            .map { " Required kept-page subject: \($0)" } ?? ""
        return "folded student note from \(sender).\(subject)"
    }

    private func usesRequiredSubject(_ prose: String, surface: SurfacePage) -> Bool {
        guard surface.payload.metadata["noteSubjectRequired"] == "true",
              let subject = surface.payload.metadata["meaningfulSourcePassage"]?.nonEmpty else {
            return true
        }
        let subjectWords = SemanticKeepEcho.contentWords(in: subject)
        guard !subjectWords.isEmpty else { return true }
        let proseWords = SemanticKeepEcho.contentWords(in: prose)
        return !subjectWords.isDisjoint(with: proseWords)
    }

    private func sanitize(_ response: String, fallback: String) -> String {
        let cleaned = response
            .replacingOccurrences(of: #"(?im)^\s*(note|sender|message)\s*:\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallback }
        let lines = cleaned
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if lines.count > 7 {
            return lines.prefix(7).joined(separator: "\n")
        }
        return cleaned
    }

    private func fallback(surface: SurfacePage) -> String {
        let sender = surface.payload.metadata["senderName"] ?? "Someone"
        let player = surface.payload.metadata["playerName"]?.nonEmpty ?? "you"
        let kind = surface.payload.metadata["noteKind"] ?? "question"
        let context = surface.payload.metadata["deliveryContext"] ?? "Between classes."
        let passage = surface.payload.metadata["meaningfulSourcePassage"]?
            .bookPreviewSentenceLimit(1)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            .map { String($0.prefix(110)) }
        let hinge = passage.map { "That bit about “\($0)” would not leave me alone." }
        switch kind {
        case "warning":
            return "\(player),\n\n\(hinge.map { "\($0) " } ?? "")Do not answer the next obvious question too quickly. \(context) made it sound simple, which is exactly when it starts lying.\n\n-\(sender)"
        case "gossip":
            return "\(hinge.map { "\($0)\n\n" } ?? "")I heard your name in the corridor and then everyone pretended the noticeboard was fascinating.\n\nFind me after class?\n\n-\(sender)"
        case "invitation":
            return "\(player),\n\n\(hinge.map { "\($0) " } ?? "")If you are free later, walk the long way past the shelves. I found something too odd to inspect alone.\n\n-\(sender)"
        case "tease":
            return "\(hinge.map { "\($0)\n\n" } ?? "")You looked like you were winning an argument with your own notebook.\n\nFor the record, I think the notebook started it.\n\n-\(sender)"
        default:
            return "\(player),\n\n\(hinge.map { "\($0) " } ?? "")Quick question, before the room changes its mind: did you notice the same thing I did?\n\n-\(sender)"
        }
    }
}

struct CharacterLetterWriter {
    func write(surface: SurfacePage) async -> String {
        let prompt = prompt(for: surface)
        let instructions = """
        You are writing an in-world NPC letter for ReEnchanted.
        Write as the named sender, not as an assistant. Use the sender's writing voice, memories, and narrative context.
        Use live web research clippings when supplied, especially details connected to the player's actual home context.
        If no live clippings are supplied, fall back to your own general knowledge, but do not pretend you browsed or cite fake sources.
        Do not invent completed real-world actions by the player. Do not diagnose, prescribe, or moralize.
        Format as a real letter: greeting, 2-4 short paragraphs, signoff from the sender, optional P.S. if it fits the voice.
        Avoid generic openings like "I find myself compelled to write", "I have been observing", "my work centers on", or polished academic self-summaries.
        Anchor the letter in one concrete object, weather detail, phrase, or kept page from the packet before naming any idea.
        """
        if let response = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 620,
            sourceID: "letter-page",
            tags: ["letter", "character-letter"]
        ) {
            let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""
            let sender = surface.payload.metadata["senderName"] ?? "A character"
            let firstAudit = await CharacterFidelityReviewer.audit(
                prose: response,
                canon: canon,
                context: "letter from \(sender)",
                sourceID: "letter-page"
            )
            if firstAudit.shouldRepair,
               let repaired = await LocalBrainProse.write(
                    prompt: "\(prompt)\n\nCHARACTER CONTINUITY REPAIR:\n\(firstAudit.feedback)\nReturn the full letter again.",
                    instructions: instructions,
                    maxTokens: 620,
                    sourceID: "letter-page",
                    tags: ["letter", "character-letter", "character-repair"]
               ) {
                let secondAudit = await CharacterFidelityReviewer.audit(
                    prose: repaired,
                    canon: canon,
                    context: "repaired letter from \(sender)",
                    sourceID: "letter-page"
                )
                let useSecond = CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: secondAudit)
                await CharacterFidelityReviewer.recordDecision(
                    sourceID: "letter-page",
                    canon: canon,
                    prompt: prompt,
                    first: firstAudit,
                    repaired: secondAudit,
                    selected: useSecond ? .repaired : .first
                )
                if useSecond {
                    return repaired
                }
            } else {
                await CharacterFidelityReviewer.recordDecision(
                    sourceID: "letter-page",
                    canon: canon,
                    prompt: prompt,
                    first: firstAudit,
                    repaired: nil,
                    selected: .first
                )
            }
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

        \(surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? "")

        Live web research clippings:
        \(clippings)

        Research source URLs:
        \(sources)\(surface.payload.metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")

        Write the finished letter. It should feel researched, personal, and specific to the sender, but never like a professional biography. Blend real-world facts with the sender's voice and relationship to the player. Open from one concrete thing in the draft packet or clippings before explaining the sender's interest. Give each sender a distinct cadence; do not reuse stock first-letter shapes. For an introduction-stage letter, introduce before escalating: no callbacks, no assumed intimacy, no urgent plot demand. Start with a greeting that uses "\(playerName)" exactly. Never write "[Player Name]".
        """
    }

    private func fallback(surface: SurfacePage) -> String {
        let sender = surface.payload.metadata["senderName"] ?? "A character"
        let playerName = surface.payload.metadata["playerName"]?.nonEmpty ?? "friend"
        let interest = surface.payload.metadata["unwrittenInterest"] ?? "ordinary wonder"
        let home = surface.payload.metadata["homeContext"] ?? "your home"
        let clippings = surface.payload.metadata["letterResearchClippings"]?.nonEmpty
        let passage = surface.payload.metadata["meaningfulSourcePassage"]?
            .bookPreviewSentenceLimit(1)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            .map { String($0.prefix(150)) }
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
        let passageParagraph = passage.map {
            "There was one line of yours I could not leave alone: “\($0)” It put weather on the question instead of answering it for me."
        } ?? ""
        return """
        Dear \(playerName),

        I went looking for \(interest), especially where it brushes against \(home). \(researchLine)

        \(passageParagraph)

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
            You are The Wonder Compass inside ReEnchanted. Generate one tiny Playful Mission for South = Sense. \(BookVoice.animismLine) Return compact strict JSON only.
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

        \(surface.payload.metadata["readerLexiconPromptSection"]?.nonEmpty ?? "")

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
        let prompt = LocalModelManager.electiveOfferPrompt(surface: surface)
        let instructions = """
        You are a character in ReEnchanted asking the player a small real-world favor. Return compact strict JSON only.
        """
        func decode(_ response: String) -> ElectiveOfferDraft? {
            guard let raw = JSONSalvage.dictionary(from: response) else { return nil }
            return ElectiveOfferDraft(
                title: JSONSalvage.string("title", in: raw) ?? fallback.title,
                ask: JSONSalvage.string("ask", in: raw) ?? fallback.ask,
                whyItMatters: JSONSalvage.string("whyItMatters", in: raw) ?? fallback.whyItMatters,
                practiceShape: JSONSalvage.string("practiceShape", in: raw) ?? fallback.practiceShape
            )
        }
        func prose(_ offer: ElectiveOfferDraft) -> String {
            "\(offer.title)\n\(offer.ask)\n\(offer.whyItMatters)\n\(offer.practiceShape)"
        }

        guard let response = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: 460,
            sourceID: "unwritten-elective",
            tags: ["elective", "offer"]
        ), let first = decode(response) else {
            return fallback
        }
        let canon = surface.payload.metadata[CharacterCanonPacket.metadataKey] ?? ""
        let sender = surface.payload.metadata["senderName"] ?? "the sender"
        let firstAudit = await CharacterFidelityReviewer.audit(
            prose: prose(first),
            canon: canon,
            context: "elective quest offer from \(sender)",
            sourceID: "unwritten-elective"
        )
        guard firstAudit.shouldRepair else {
            await CharacterFidelityReviewer.recordDecision(
                sourceID: "unwritten-elective",
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: nil,
                selected: .first
            )
            return first
        }
        if let repairedResponse = await LocalBrainProse.write(
            prompt: "\(prompt)\n\nCHARACTER CONTINUITY REPAIR:\n\(firstAudit.feedback)\nReturn the complete strict JSON object again.",
            instructions: instructions,
            maxTokens: 460,
            sourceID: "unwritten-elective",
            tags: ["elective", "offer", "character-repair"]
        ), let second = decode(repairedResponse) {
            let secondAudit = await CharacterFidelityReviewer.audit(
                prose: prose(second),
                canon: canon,
                context: "repaired elective quest offer from \(sender)",
                sourceID: "unwritten-elective"
            )
            let useSecond = CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: secondAudit)
            await CharacterFidelityReviewer.recordDecision(
                sourceID: "unwritten-elective",
                canon: canon,
                prompt: prompt,
                first: firstAudit,
                repaired: secondAudit,
                selected: useSecond ? .repaired : .first
            )
            if useSecond {
                return second
            }
        }
        return first
    }
}

/// Room generation through the engine, falling back to the offline writer —
/// anchoring works in every build, model or no model.
struct OuterStacksRoomEngine: OuterStacksRoomWriting {
    func room(context: AnchorGenerationContext) async throws -> OuterStacksRoomSpec {
        let fallback = try await FakeOuterStacksRoomWriter().room(context: context)
        guard let response = await LocalBrainProse.write(
            prompt: LocalModelManager.outerStacksRoomPrompt(context: context),
            instructions: """
            You are the Labyrinth of Stories building Outer Stacks rooms. Return compact strict JSON only.
            """,
            maxTokens: 520,
            sourceID: "outer-stacks-anchor",
            tags: ["outer-stacks", "anchor", "room-generation"]
        ), let raw = JSONSalvage.dictionary(from: response) else {
            return fallback
        }
        let candidate = OuterStacksRoomSpec(
            roomDescription: JSONSalvage.string("roomDescription", in: raw) ?? fallback.roomDescription,
            academyEcho: JSONSalvage.string("academyEcho", in: raw) ?? fallback.academyEcho,
            fae: JSONSalvage.string("fae", in: raw) ?? fallback.fae,
            miniStory: JSONSalvage.string("miniStory", in: raw) ?? fallback.miniStory,
            localRule: JSONSalvage.string("localRule", in: raw) ?? fallback.localRule,
            emotionalRegister: JSONSalvage.string("emotionalRegister", in: raw) ?? fallback.emotionalRegister
        )
        return AnchorRoomOutputAudit.accepts(candidate, context: context) ? candidate : fallback
    }

    func visitScene(anchor: AnchorRecord, visitCount: Int, day: BookDay, memory: String) async throws -> String {
        if let prose = await LocalBrainProse.write(
            prompt: LocalModelManager.outerStacksVisitPrompt(anchor: anchor, visitCount: visitCount, day: day, memory: memory),
            instructions: """
            You are the Labyrinth of Stories narrating an Outer Stacks visit. Write prose only, no JSON, no headings, no labeled sections. \(BookVoice.animismLine)
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
        let canon = CharacterCanonPacket.promptSection(
            for: NarrativePackRegistry.entities.filter { $0.id == "penny-blackletter" }
        )
        let prompt = brief.id == "corridor-whispers"
            ? GossipPageForm.bleedColumnPrompt(
                title: brief.title,
                packet: packet,
                pennyCanon: canon
            )
            : """
            COLUMN: \(brief.title)
            BYLINE: \(brief.byline)

            \(canon)

            MATERIAL (write only from this; invent nothing beyond it):
            \(packet)
            """
        let instructions = instructions(for: brief)
        if let response = await LocalBrainProse.write(
            prompt: prompt,
            instructions: instructions,
            maxTokens: max(brief.maxTokens, 240),
            sourceID: "the-bleed",
            tags: ["bleed", brief.id]
        ) {
            let firstAudit = await CharacterFidelityReviewer.audit(
                prose: response,
                canon: canon,
                context: "The Bleed column \(brief.title) by Penny Blackletter",
                sourceID: "the-bleed"
            )
            if firstAudit.shouldRepair,
               let repaired = await LocalBrainProse.write(
                    prompt: "\(prompt)\n\nCHARACTER CONTINUITY REPAIR:\n\(firstAudit.feedback)\nReturn the full column again.",
                    instructions: instructions,
                    maxTokens: max(brief.maxTokens, 240),
                    sourceID: "the-bleed",
                    tags: ["bleed", brief.id, "character-repair"]
               ) {
                let repairedAudit = await CharacterFidelityReviewer.audit(
                    prose: repaired,
                    canon: canon,
                    context: "repaired Bleed column \(brief.title) by Penny Blackletter",
                    sourceID: "the-bleed"
                )
                let useSecond = CharacterFidelityReviewer.prefersRepairedDraft(first: firstAudit, repaired: repairedAudit)
                await CharacterFidelityReviewer.recordDecision(
                    sourceID: "the-bleed",
                    canon: canon,
                    prompt: prompt,
                    first: firstAudit,
                    repaired: repairedAudit,
                    selected: useSecond ? .repaired : .first
                )
                if useSecond {
                    return repaired
                }
            } else {
                await CharacterFidelityReviewer.recordDecision(
                    sourceID: "the-bleed",
                    canon: canon,
                    prompt: prompt,
                    first: firstAudit,
                    repaired: nil,
                    selected: .first
                )
            }
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

            Write Penny's signed lead column in 3-4 short paragraphs. Find one actual piece of news in the supplied archive rather than summarizing every desk. Support it with at least two specific, differently typed witnesses when available: reader words, a photo/voice form receipt, lived evidence, a literary-continuity finding, or current Academy news.
            State what is attested, what is only an editorial reading, and any contradiction that keeps the headline honest. A semantic match is a lead, not proof. Multimodal observations may describe only the supplied objects, light, palette, composition, pace, pauses, cadence, energy, or proof kind; never infer emotion, identity, health, intent, or personality from them.
            Let Penny behave like a reporter with a case file: concrete evidence first, interpretation second, one carefully placed opinion last. Do not list every packet section. Do not quote more than two reader-authored sentences.
            """
        case "corridor-whispers":
            return GossipPageForm.instructions + """

            You are setting the supplied Gossip Page source packet as The Bleed's Corridor Whispers column. Follow the shared Gossip Page requirements in the prompt exactly. Penny is the editor, not a new participant in the reported events.
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
