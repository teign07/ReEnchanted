import Foundation
#if (DEBUG || BRAID_PROOF) && NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
import MLXLMCommon
import UIKit

/// Measures what the phone's own Gemma path writes for a braid brief, without
/// touching the reader's library.
///
/// Copy `Documents/braid-proof/input.json` onto the device, then launch with
/// `--proof-braid`. Each case runs through `MLXLocalTextGenerator.run` exactly
/// as the nightly braid does (same instructions, sampling and KV size) at each
/// requested output ceiling, and `output.json` records the raw text, token
/// counts, speed and whether generation stopped on its own or hit the ceiling.
/// Nothing is kept, filed, braided or shown to the reader.
///
/// Debug builds compile MLX at -O0 and run several times slower than a reader's
/// build. For honest timings build Release with the harness compiled in:
///
///     xcodebuild -scheme InsideCoverApp -configuration Release \
///       -destination 'id=<device>' \
///       SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) BRAID_PROOF' build
enum BraidProofHarness {
    static let flag = "--proof-braid"

    private struct Input: Decodable {
        var instructions: String?
        var cases: [Case]
        var ceilings: [Int]
        var temperature: Float?
        var topP: Float?
    }

    private struct Case: Decodable {
        var name: String
        var brief: String
    }

    private struct Result: Encodable {
        var name: String
        var ceiling: Int
        var text: String
        /// What the braid would keep: `BraidNarrativeOutput.finished`, with a
        /// stand-in for the plan's keeper line.
        var finished: String
        var promptTokens: Int?
        var generatedTokens: Int?
        var tokensPerSecond: Double?
        var promptSeconds: Double?
        var stopReason: String?
        var seconds: Double
        var error: String?
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(flag) else { return }
        Task.detached(priority: .utility) {
            // Let launch settle before the model claims the GPU.
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await run()
        }
    }

    private static func run() async {
        // Nobody touches the phone during a run. An auto-lock sends the app to
        // the background, where the GPU is withdrawn and the run is lost.
        await LocalBrainForeground.shared.holdScreenAwake()
        defer {
            Task { @MainActor in LocalBrainForeground.shared.releaseScreen() }
        }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("braid-proof", isDirectory: true)
        let outputURL = folder.appendingPathComponent("output.json")
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("input.json")),
              let input = try? JSONDecoder().decode(Input.self, from: data) else {
            try? Data("{\"error\":\"missing or unreadable input.json\"}".utf8).write(to: outputURL)
            return
        }
        let instructions = input.instructions ?? BraidInstructions.nightlyBookOfYou
        var results: [Result] = []
        func save(done: Bool) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let payload: [String: AnyEncodable] = [
                "iPhone15Class": AnyEncodable(LocalModelManager.isIPhone15ClassHardware),
                "done": AnyEncodable(done),
                "results": AnyEncodable(results)
            ]
            try? encoder.encode(payload).write(to: outputURL, options: .atomic)
        }
        for ceiling in input.ceilings {
            for item in input.cases {
                let started = Date()
                var info: GenerateCompletionInfo?
                var text = ""
                var failure: String?
                do {
                    text = try await MLXLocalTextGenerator.run(
                        prompt: item.brief,
                        instructions: instructions,
                        maxTokens: ceiling,
                        label: "braid-proof",
                        tags: ["braid-proof"],
                        temperature: input.temperature ?? 0.70,
                        topP: input.topP ?? 0.90,
                        maxKVSize: 4_096,
                        publishesProgress: false,
                        iPhone15OutputCeiling: ceiling,
                        completion: { info = $0 }
                    )
                } catch {
                    failure = String(describing: error)
                }
                var reachedCeiling = false
                if case .length = info?.stopReason { reachedCeiling = true }
                results.append(Result(
                    name: item.name,
                    ceiling: ceiling,
                    text: text,
                    finished: BraidNarrativeOutput.finished(
                        text,
                        reachedCeiling: reachedCeiling,
                        keeperColophon: "The Book kept the page: [keeper line]."
                    ),
                    promptTokens: info?.promptTokenCount,
                    generatedTokens: info?.generationTokenCount,
                    tokensPerSecond: info.map { Double($0.generationTokenCount) / max($0.generateTime, 0.001) },
                    promptSeconds: info?.promptTime,
                    stopReason: info.map { String(describing: $0.stopReason) },
                    seconds: Date().timeIntervalSince(started),
                    error: failure
                ))
                save(done: false)
            }
        }
        save(done: true)
    }

    private struct AnyEncodable: Encodable {
        private let encodeValue: (Encoder) throws -> Void
        init<T: Encodable>(_ value: T) { encodeValue = value.encode }
        func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
    }
}
#endif
