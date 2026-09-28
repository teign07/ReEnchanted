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
        CountBraidProofHarness.runIfRequested()
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
        let runID = UUID().uuidString
        let startedAt = Date()
        var results: [Result] = []
        func save(done: Bool) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // Rabbit's speed swung from 3.9 to 0.65 tokens a second between two
            // runs an hour apart; heat and Low Power Mode are the usual reasons.
            let thermal: String
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: thermal = "nominal"
            case .fair: thermal = "fair"
            case .serious: thermal = "serious"
            case .critical: thermal = "critical"
            @unknown default: thermal = "unknown"
            }
            let payload: [String: AnyEncodable] = [
                "runID": AnyEncodable(runID),
                "startedAt": AnyEncodable(startedAt.ISO8601Format()),
                "thermalState": AnyEncodable(thermal),
                "lowPowerMode": AnyEncodable(ProcessInfo.processInfo.isLowPowerModeEnabled),
                "iPhone15Class": AnyEncodable(LocalModelManager.isIPhone15ClassHardware),
                "done": AnyEncodable(done),
                "results": AnyEncodable(results)
            ]
            try? encoder.encode(payload).write(to: outputURL, options: .atomic)
        }
        // Retire the prior completed result before the model starts. A slow or
        // interrupted run must never look like the previous proof succeeded.
        save(done: false)
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
                        masksWornImages: true,
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
                    finished: BraidPointOfView.returningTheReadersActions(
                        in: BraidNarrativeOutput.finished(
                            text,
                            reachedCeiling: reachedCeiling,
                            keeperColophon: "The Book kept the page: [keeper line]."
                        ),
                        readerDay: readerDay(in: item.brief)
                    ).text,
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

    /// The reader-day sentences the brief handed over, as the pipeline gets
    /// them from `BraidScenePlan.readerDayNarration`.
    private static func readerDay(in brief: String) -> [String] {
        guard let line = brief.components(separatedBy: "\n")
            .first(where: { $0.hasPrefix(BraidScenePlan.readerDayLabel) }) else { return [] }
        return line.dropFirst(BraidScenePlan.readerDayLabel.count)
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private struct AnyEncodable: Encodable {
        private let encodeValue: (Encoder) throws -> Void
        init<T: Encodable>(_ value: T) { encodeValue = value.encode }
        func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
    }
}
/// Runs a copied synthetic Count QA day through the production braider and
/// archive/publication seams. Its store lives under Documents/count-braid-proof;
/// it never replaces BookDatabase or reads the Reader's archive/vault context.
enum CountBraidProofHarness {
    private struct Input: Decodable {
        var day: BookDay
        var receipts: [AuthoredContentReceipt]
        /// Replay a captured unbound Gemma result for publication-only fixes;
        /// the report distinguishes this from a fresh model invocation.
        var generatedPage: BookPage?
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--proof-count-braid") else { return }
        Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await run()
        }
    }

    private static func run() async {
        await LocalBrainForeground.shared.holdScreenAwake()
        defer {
            Task {
                await LocalBrainModelCache.shared.releaseAfterFlow(label: "count-braid-proof")
                await MainActor.run { LocalBrainForeground.shared.releaseScreen() }
            }
        }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("count-braid-proof", isDirectory: true)
        let runID = UUID().uuidString
        let runStarted = Date()
        var status = ["run: \(runID)", "started: \(runStarted.ISO8601Format())",
            "thermal at start: \(ProcessInfo.processInfo.thermalState.rawValue)",
            "low power mode: \(ProcessInfo.processInfo.isLowPowerModeEnabled)"]
        func saveStatus() {
            try? status.joined(separator: "\n").write(
                to: folder.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
        }
        saveStatus()
        do {
            let input = try JSONDecoder().decode(Input.self,
                from: Data(contentsOf: folder.appendingPathComponent("input.json")))
            var context = BraidPromptBuilder.Context.empty
            context.authoredStoryReceipts = input.receipts
            var page: BookPage
            if let captured = input.generatedPage {
                guard captured.tags.contains("mlx"), MonthlyIssueBraidMatter.receiptIDs(in: captured).isEmpty else {
                    throw ProofError("replay requires an unbound captured Gemma page")
                }
                page = captured
                status.append("mode: replay captured Gemma telling; no new model invocation")
            } else {
                let started = Date()
                page = try await MLXBookBraider().braid(day: input.day, context: context)
                status.append("mode: fresh production Gemma telling")
                status.append("braider seconds: \(Date().timeIntervalSince(started))")
            }
            page = MonthlyIssueBraidMatter.binding(input.receipts, into: page)
            page = BraidPageDetails.withSourcePages(page,
                pageIDs: Set(input.day.capturedPages.map(\.id)))
            page.createdAt = input.day.date.addingTimeInterval(21 * 3_600)
            var day = input.day
            day.pages.append(page)
            // A new store for each run prevents a previous proof from passing
            // the read-back checks after a failed write.
            let archive = BookArchiveDatabase(storeURL: folder.appendingPathComponent("\(runID).store"))
            try archive.saveDays([day])
            let days = archive.loadDays(migratingFrom: [])
            guard archive.lastLoadSource == .swiftData,
                  let saved = days.flatMap(\.pages).first(where: { $0.id == page.id }),
                  saved.userInput == page.userInput, saved.tags == page.tags,
                  MonthlyIssueBraidMatter.receiptIDs(in: saved) == Set(input.receipts.map(\.id)) else {
                throw ProofError("archive read-back or receipt coverage mismatch")
            }
            try JSONEncoder().encode(days).write(to: folder.appendingPathComponent("saved-days.json"), options: .atomic)
            try saved.userInput.write(to: folder.appendingPathComponent("braid.txt"), atomically: true, encoding: .utf8)
            status.append("OK: Gemma page, authored binding, SwiftData save and read-back")
            saveStatus()

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!.addingTimeInterval(-1)
            let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9))!
            let edition = MonthlyEditionBuilder.edition(from: days, readerName: "Count QA Reader",
                startDate: start, endDate: end, generatedAt: now, calendar: calendar)
            try MonthlyEditionPDFWriter.write(edition, to: folder.appendingPathComponent("monthly-reading.pdf"))
            let count = try MonthlyEditionPDFWriter.writePrintInterior(edition,
                spec: .perfectBoundSoftcover6x9, to: folder.appendingPathComponent("monthly-interior.pdf"))
            status.append("OK: October monthly reading PDF and print interior, \(count) print pages")
            saveStatus()
            let season = MonthlyEditionBuilder.seasonal(from: days,
                startingMonth: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!,
                readerName: "Count QA Reader", calendar: calendar)
            let seasonalCount = try MonthlyEditionPDFWriter.writeVolumePrintInterior(season,
                spec: .perfectBoundSoftcover6x9, to: folder.appendingPathComponent("seasonal-interior.pdf"))
            let annual = MonthlyEditionBuilder.annual(2026, from: days,
                readerName: "Count QA Reader", calendar: calendar)
            let annualCount = try MonthlyEditionPDFWriter.writeVolumePrintInterior(annual,
                spec: .clothFoilHardcover6x9, to: folder.appendingPathComponent("annual-interior.pdf"))
            status.append("OK: seasonal \(seasonalCount) and annual \(annualCount) print pages")
            if let candidate = PublicationPeriodCatalog.readerWeeks(days: days, now: now, calendar: calendar)
                .first(where: \.isBindable),
               let issue = WeeklyIssue.issue(for: candidate.period, days: days, now: now, calendar: calendar) {
                try WeeklyIssuePDFWriter.write(issue, readerName: "Count QA Reader",
                    shareCard: WeeklyIssueShareCard.make(issue: issue),
                    to: folder.appendingPathComponent("weekly-reading.pdf"))
                status.append("OK: weekly reading PDF")
            } else { throw ProofError("no bindable QA week") }
            status.append("total seconds: \(Date().timeIntervalSince(runStarted))")
            status.append("thermal at finish: \(ProcessInfo.processInfo.thermalState.rawValue)")
            status.append("DONE")
        } catch { status.append("FAILED: \(error)") }
        saveStatus()
    }

    private struct ProofError: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }
}
#endif
