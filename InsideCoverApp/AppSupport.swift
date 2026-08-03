import SwiftUI
import Foundation
import OSLog
import Darwin.Mach
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(QuartzCore)
import QuartzCore
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

#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX)
let mlxRuntimeLinked = true
#else
let mlxRuntimeLinked = false
#endif

let appLog = Logger(subsystem: "com.openclaw.enchantify.insidecover", category: "InsideCoverApp")

extension Notification.Name {
    static let bookAppLockAuthorized = Notification.Name("bookAppLockAuthorized")
    static let promptWhisperKept = Notification.Name("promptWhisperKept")
    static let promptWhisperOpenReceived = Notification.Name("promptWhisperOpenReceived")
}

/// A notification may wake the process before `ContentView` exists, or while
/// the Book is still behind its app lock. Persist the exact prompt snapshot and
/// let the first ready Book view consume it.
struct PromptWhisperOpenRequest: Codable, Equatable {
    var id: UUID
    var whisper: PromptWhisper
    var issuedAt: Date
}

enum PromptWhisperOpenStore {
    static let requestKey = "promptWhisperOpenRequest"

    @discardableResult
    static func enqueue(_ whisper: PromptWhisper, now: Date = Date()) -> PromptWhisperOpenRequest? {
        let request = PromptWhisperOpenRequest(id: UUID(), whisper: whisper, issuedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(request) else { return nil }
        UserDefaults.standard.set(data, forKey: requestKey)
        return request
    }

    static func load() -> PromptWhisperOpenRequest? {
        guard let data = UserDefaults.standard.data(forKey: requestKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PromptWhisperOpenRequest.self, from: data)
    }

    static func clear(id: UUID? = nil) {
        if let id, load()?.id != id { return }
        UserDefaults.standard.removeObject(forKey: requestKey)
    }
}

// MARK: - Public Margins network doorway

enum PublicMarginsAPI {
    static let incomingOptInKey = "publicMarginsIncomingOptIn"
    static let outgoingOptInKey = "publicMarginsOutgoingOptIn"
    static let deletionReceiptsKey = "publicMarginsDeletionReceipts"

    private static var baseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "PublicMarginsAPIBaseURL") as? String,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "https://community-api.reenchanted.app/v1")!
    }

    static func fetchSnapshot(session: URLSession = .shared) async throws -> PublicMarginsSnapshot {
        let url = baseURL.appendingPathComponent("community/snapshot")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData
        let (data, response) = try await session.data(for: request)
        try requireSuccess(response)
        return try JSONDecoder().decode(PublicMarginsSnapshot.self, from: data)
    }

    static func submit(
        _ contribution: PublicMarginsContributionRequest,
        session: URLSession = .shared
    ) async throws -> PublicMarginsContributionReceipt {
        var request = URLRequest(url: baseURL.appendingPathComponent("contributions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(contribution)
        let (data, response) = try await session.data(for: request)
        try requireSuccess(response)
        let receipt = try JSONDecoder().decode(PublicMarginsContributionReceipt.self, from: data)
        storeDeletionReceipt(receipt)
        return receipt
    }

    static var storedDeletionReceiptCount: Int {
        (UserDefaults.standard.dictionary(forKey: deletionReceiptsKey) as? [String: String] ?? [:]).count
    }

    static func withdrawAllStoredContributions(session: URLSession = .shared) async -> Int {
        var receipts = UserDefaults.standard.dictionary(forKey: deletionReceiptsKey) as? [String: String] ?? [:]
        var deleted = 0
        for (id, token) in receipts {
            var request = URLRequest(
                url: baseURL
                    .appendingPathComponent("contributions")
                    .appendingPathComponent(id)
            )
            request.httpMethod = "DELETE"
            request.timeoutInterval = 15
            request.setValue(token, forHTTPHeaderField: "X-Deletion-Token")
            do {
                let (_, response) = try await session.data(for: request)
                try requireSuccess(response)
                receipts.removeValue(forKey: id)
                deleted += 1
            } catch {
                // Keep the local receipt so a later attempt remains possible.
            }
        }
        UserDefaults.standard.set(receipts, forKey: deletionReceiptsKey)
        return deleted
    }

    private static func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PublicMarginsAPIError.requestFailed
        }
    }

    private static func storeDeletionReceipt(_ receipt: PublicMarginsContributionReceipt) {
        var receipts = UserDefaults.standard.dictionary(forKey: deletionReceiptsKey) as? [String: String] ?? [:]
        receipts[receipt.id] = receipt.deletionToken
        UserDefaults.standard.set(receipts, forKey: deletionReceiptsKey)
    }
}

enum PublicMarginsAPIError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        "The Public Margins didn't answer. Your Book stayed private; nothing was sent again."
    }
}

#if canImport(LocalAuthentication)
@MainActor
final class BookAppLock: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var message = "I'm closed."

    @discardableResult
    func authenticate() async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Leave closed"
        context.localizedFallbackTitle = "Use passcode"

        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            message = error?.localizedDescription ?? "Set a device passcode to lock me."
            isUnlocked = false
            return false
        }

        do {
            let reason = "Open ReEnchanted and unlock your private Book."
            if try await context.evaluatePolicy(policy, localizedReason: reason) {
                isUnlocked = true
                message = "The cover opens."
                BookFeedback.play(.openPage)
                return true
            }
        } catch {
            isUnlocked = false
            message = "I stayed closed."
            BookFeedback.play(.dismissPage)
        }
        return false
    }

    func lock() {
        guard isUnlocked else { return }
        isUnlocked = false
        message = "I'm closed."
    }

    func acceptCurrentAuthorization() {
        isUnlocked = true
        message = "The cover opens."
    }
}
#endif

enum BookFeedback {
    enum HapticMode: String, CaseIterable, Identifiable {
        case full
        case gentle
        case off

        var id: String { rawValue }

        var title: String {
            switch self {
            case .full: return "Full"
            case .gentle: return "Gentle"
            case .off: return "Off"
            }
        }
    }

    enum BookJumpCue {
        case start
        case deeper
        case stabilize
        case returnHome
    }

    enum Cue {
        case tap
        case select
        case openPage
        case keepPage
        case dismissPage
        case undo
        case braidStart
        case braidComplete
        case sourceRefresh
        case error
        case knock
        case knockReply

        #if canImport(AudioToolbox)
        /// Generic iOS fallback if a bundled sound is ever missing.
        var systemSoundID: SystemSoundID {
            switch self {
            case .tap:
                return 1104
            case .select:
                return 1105
            case .openPage:
                return 1106
            case .keepPage:
                return 1113
            case .dismissPage:
                return 1107
            case .undo:
                return 1157
            case .braidStart:
                return 1114
            case .braidComplete:
                return 1117
            case .sourceRefresh:
                return 1108
            case .error:
                return 1053
            case .knock:
                return 1104
            case .knockReply:
                return 1105
            }
        }
        #endif

        /// Bundled bookish sound, synthesized by scripts/generate_book_sounds.py.
        var soundName: String {
            switch self {
            case .tap:
                return "tap"
            case .select:
                return "select"
            case .openPage:
                return "open-page"
            case .keepPage:
                return "keep-page"
            case .dismissPage:
                return "dismiss-page"
            case .undo:
                return "undo"
            case .braidStart:
                return "braid-start"
            case .braidComplete:
                return "braid-complete"
            case .sourceRefresh:
                return "source-refresh"
            case .error:
                return "error"
            case .knock:
                return "knock"
            case .knockReply:
                return "knock-reply"
            }
        }
    }

    #if canImport(AudioToolbox)
    private static var bookSoundIDs: [String: SystemSoundID] = [:]

    private static func bookSoundID(for cue: Cue) -> SystemSoundID? {
        if let cached = bookSoundIDs[cue.soundName] {
            return cached
        }
        guard let url = Bundle.main.url(
            forResource: cue.soundName,
            withExtension: "caf",
            subdirectory: "BookSounds"
        ) else {
            return nil
        }
        var soundID: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError else {
            return nil
        }
        bookSoundIDs[cue.soundName] = soundID
        return soundID
    }

    private static func playBookSound(_ cue: Cue) {
        AudioServicesPlaySystemSound(bookSoundID(for: cue) ?? cue.systemSoundID)
    }
    #endif

    static func play(_ cue: Cue) {
        let playedComposedHaptic = BookHapticEngine.shared.play(cue)
        #if canImport(UIKit)
        if !playedComposedHaptic, hapticMode != .off {
            switch cue {
            case .tap:
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.35)
            case .select:
                UISelectionFeedbackGenerator().selectionChanged()
            case .openPage, .sourceRefresh, .braidStart:
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
            case .keepPage, .braidComplete:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .dismissPage, .undo:
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.42)
            case .error:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .knock:
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
            case .knockReply:
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred(intensity: 0.7)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    generator.impactOccurred(intensity: 0.62)
                }
            }
        }
        #endif

        #if canImport(AudioToolbox)
        playBookSound(cue)
        #endif
    }

    /// A whisper-light haptic with no sound, for press-down feedback on tap
    /// targets. Safe to fire on every button: it carries no audio, and lands
    /// on touch-down so it layers under (rather than collides with) any cue a
    /// button plays on release. Respects the reader's haptic-mode setting.
    static func pressTick() {
        #if canImport(UIKit)
        guard hapticMode != .off else { return }
        let intensity = hapticMode == .gentle ? 0.18 : 0.3
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: intensity)
        #endif
    }

    /// The tactile edge of the dismiss threshold: a silent tick at the moment a
    /// drag crosses into — or back out of — the range where letting go would
    /// let the page pass. It carries no audio, because the reader is still
    /// mid-gesture and nothing has happened yet; the sound belongs to the
    /// dismissal itself. Engaging is firmer than releasing, so the reader can
    /// tell the two crossings apart by feel without watching the seal.
    static func sealTick(engaged: Bool) {
        #if canImport(UIKit)
        guard hapticMode != .off else { return }
        let gentle = hapticMode == .gentle
        let intensity = engaged ? (gentle ? 0.34 : 0.55) : (gentle ? 0.16 : 0.26)
        UIImpactFeedbackGenerator(style: engaged ? .rigid : .soft)
            .impactOccurred(intensity: intensity)
        #endif
    }

    /// The quill's own tick, under the reader's fingers as they write. iOS keyboard
    /// haptics are off by default, so a page the reader is filling with their own
    /// words otherwise feels like nothing at all. Silent — the keyboard already has
    /// a voice — and shaped like handwriting rather than a buzz: letters are barely
    /// there, a space is the small lift between words, a full stop lands.
    ///
    /// Only hand-typed single characters and single deletions tick. Pastes,
    /// dictation, and the sentence builder's own insertions are left alone: they
    /// aren't handwriting, and they already carry their own cues.
    static func inkTick(from old: String, to new: String) {
        #if canImport(UIKit)
        let mode = hapticMode
        guard mode != .off else { return }

        // utf8.count is O(1) on native strings; this runs on every keystroke of
        // a page that may be thousands of characters long.
        let growth = new.utf8.count - old.utf8.count
        guard growth != 0 else { return }

        if growth < 0 {
            guard growth >= -4 else { return }
            inkStroke(style: .soft, intensity: mode == .gentle ? 0.09 : 0.15)
            return
        }

        guard growth <= 4 else { return }

        // The inserted character is only knowable cheaply when it landed at the
        // end. Mid-sentence edits fall back to the plain letter tick.
        let typed: Character? = (new.last != old.last) ? new.last : nil
        switch typed {
        case "\n":
            inkStroke(style: .rigid, intensity: mode == .gentle ? 0.22 : 0.36)
        case ".", "!", "?", "…":
            inkStroke(style: .rigid, intensity: mode == .gentle ? 0.2 : 0.32)
        case " ":
            inkStroke(style: .soft, intensity: mode == .gentle ? 0.14 : 0.22)
        default:
            // Gentle keeps only the joints of the sentence — the letters
            // between them stay quiet.
            guard mode != .gentle else { return }
            inkStroke(style: .light, intensity: 0.14)
        }
        #endif
    }

    #if canImport(UIKit)
    /// Held-down keys and very fast typing become a cadence, not a rattle.
    private static let inkMinimumInterval: TimeInterval = 0.03
    private static var lastInkTickAt: TimeInterval = 0
    private static var inkGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]

    private static func inkStroke(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        let now = CACurrentMediaTime()
        guard now - lastInkTickAt >= inkMinimumInterval else { return }
        lastInkTickAt = now

        let generator: UIImpactFeedbackGenerator
        if let cached = inkGenerators[style] {
            generator = cached
        } else {
            generator = UIImpactFeedbackGenerator(style: style)
            inkGenerators[style] = generator
        }
        generator.impactOccurred(intensity: intensity)
        // Keep the engine warm for the rest of the typing run.
        generator.prepare()
    }
    #endif

    static var hapticMode: HapticMode {
        get { HapticMode(rawValue: UserDefaults.standard.string(forKey: "bookHapticMode") ?? "full") ?? .full }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "bookHapticMode")
            BookHapticEngine.shared.modeDidChange()
        }
    }

    static func beliefTransferred(amount: Int, recipientGlow: Int) {
        BookHapticEngine.shared.playBeliefTransfer(amount: amount, recipientGlow: recipientGlow)
    }

    static func bookJump(_ cue: BookJumpCue) {
        BookHapticEngine.shared.playBookJump(cue)
    }

    static func faeArrival(kind: String, court: String? = nil) {
        BookHapticEngine.shared.playFaeArrival(kind: kind, court: court)
    }

    static func constellationDiscovered(nodes: Int) {
        BookHapticEngine.shared.playConstellation(nodes: nodes)
    }

    static func chapterBinding() {
        BookHapticEngine.shared.playChapterBinding()
    }

    static func chapterBindingReveal() {
        BookHapticEngine.shared.playChapterBinding()
        #if canImport(AudioToolbox)
        playBookSound(.braidStart)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            playBookSound(.sourceRefresh)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            playBookSound(.braidComplete)
        }
        #endif
    }

    static func chapterBindingAccepted() {
        BookHapticEngine.shared.playChapterBinding()
        #if canImport(AudioToolbox)
        playBookSound(.braidComplete)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            playBookSound(.keepPage)
        }
        #endif
    }

    /// The Monthly Binding's own ceremonial haptic — distinct from every page
    /// and braid cue, reserved for the month being sewn between covers.
    static func monthBound() {
        BookHapticEngine.shared.playMonthBound()
    }

    /// The print-ready export's ceremonial haptic — the foil-stamp press,
    /// reserved for a month set for a physical printer.
    static func pressReady() {
        BookHapticEngine.shared.playPressReady()
    }

    static func pageRising(rarity: Int) {
        BookHapticEngine.shared.playPageRise(rarity: rarity)
    }

    static func nothingPressure(_ level: Int) {
        BookHapticEngine.shared.playNothing(level: level)
    }

    static func radioLocked() {
        BookHapticEngine.shared.playRadioLock()
    }
}

extension View {
    /// Gives a writing surface the quill's tick: a silent, whisper-light haptic
    /// under each character the reader types. Attach it to any field the reader
    /// writes *into the Book* with — not to search boxes, addresses, or keys,
    /// which are errands rather than writing.
    func inkFeedback(text: String) -> some View {
        onChange(of: text) { old, new in
            BookFeedback.inkTick(from: old, to: new)
        }
    }
}

struct LivingInkBurst: View {
    enum Mood {
        case kept
        case sentence
        case belief

        var palette: [Color] {
            switch self {
            case .kept:
                return [BookPalette.lampGold, BookPalette.teal, BookPalette.violet, BookPalette.paper]
            case .sentence:
                return [BookPalette.teal, BookPalette.lampGold, BookPalette.gold]
            case .belief:
                return [BookPalette.lampGold, BookPalette.gold, BookPalette.teal]
            }
        }

        var drift: CGSize {
            switch self {
            case .kept: return CGSize(width: 22, height: -56)
            case .sentence: return CGSize(width: 0, height: -42)
            case .belief: return CGSize(width: 0, height: -24)
            }
        }
    }

    let trigger: Int
    var text: String
    var mood: Mood = .kept
    var intensity: Double = 1
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [LivingInkParticle] = []
    @State private var startedAt = Date.distantPast
    @State private var isActive = false

    private var duration: TimeInterval {
        reduceMotion ? 0.42 : 1.35
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive || isPaused)) { timeline in
            Canvas { context, size in
                draw(context: &context, size: size, now: timeline.date)
            }
        }
        .allowsHitTesting(false)
        .opacity(isActive && !isPaused ? 1 : 0)
        .onAppear {
            if trigger > 0 { restart() }
        }
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            restart()
        }
    }

    private func restart() {
        guard !isPaused else { return }
        particles = LivingInkParticle.make(
            seed: UInt64(max(trigger, 1)),
            text: text,
            mood: mood,
            intensity: intensity
        )
        startedAt = Date()
        isActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.08) {
            guard Date().timeIntervalSince(startedAt) >= duration else { return }
            isActive = false
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize, now: Date) {
        guard isActive, size.width > 0, size.height > 0 else { return }
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        let progress = min(1, elapsed / duration)
        let eased = 1 - pow(1 - progress, 3)
        let fade = reduceMotion ? sin(progress * .pi) : max(0, 1 - progress)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.54)

        for particle in particles {
            let delay = reduceMotion ? 0 : particle.delay
            let local = min(1, max(0, (elapsed - delay) / max(0.1, duration - delay)))
            guard local > 0 else { continue }
            let localEase = 1 - pow(1 - local, 3)
            let alpha = particle.alpha * max(0, 1 - local) * fade
            guard alpha > 0.01 else { continue }

            let spread = reduceMotion ? 0.18 : 1
            let x = center.x + particle.start.width + (particle.velocity.width + mood.drift.width) * localEase * spread
            let y = center.y + particle.start.height + (particle.velocity.height + mood.drift.height) * localEase * spread
            let scale = CGFloat(reduceMotion ? 0.82 : 0.78 + 0.28 * sin(local * .pi))
            let color = particle.color.opacity(alpha)

            context.drawLayer { layer in
                layer.addFilter(.shadow(color: particle.color.opacity(alpha * 0.55), radius: 5 * (1 - local)))
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .radians(particle.rotation + particle.spin * eased))
                let resolved = Text(String(particle.glyph))
                    .font(.system(size: particle.size * scale, weight: .bold, design: .serif))
                    .foregroundStyle(color)
                layer.draw(resolved, at: .zero, anchor: .center)
            }

            if particle.isSpark {
                let sparkRect = CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)
                context.fill(Path(ellipseIn: sparkRect), with: .color(color))
            }
        }
    }
}

private struct LivingInkParticle: Identifiable {
    var id: Int
    var glyph: Character
    var color: Color
    var start: CGSize
    var velocity: CGSize
    var size: CGFloat
    var alpha: Double
    var rotation: Double
    var spin: Double
    var delay: TimeInterval
    var isSpark: Bool

    static func make(seed: UInt64, text: String, mood: LivingInkBurst.Mood, intensity: Double) -> [LivingInkParticle] {
        var rng = LivingInkRandom(seed: seed &+ UInt64(text.count * 97))
        let cleaned = text.uppercased().filter { $0.isLetter || $0.isNumber }
        let source = cleaned.isEmpty ? "KEPT" : String(cleaned.prefix(18))
        let glyphs = Array(source)
        let count = max(7, min(22, Int(Double(glyphs.count + 7) * max(0.72, min(1.2, intensity)))))
        let colors = mood.palette

        return (0..<count).map { index in
            let fallbackGlyphs = Array("*+.")
            let glyph = index < glyphs.count ? glyphs[index] : fallbackGlyphs[rng.int(in: 0..<fallbackGlyphs.count)]
            let angle = rng.double(in: 0..<(Double.pi * 2))
            let radius = rng.double(in: 4...30)
            let speed = rng.double(in: 26...84) * max(0.74, min(1.18, intensity))
            return LivingInkParticle(
                id: index,
                glyph: glyph,
                color: colors[index % colors.count],
                start: CGSize(width: cos(angle) * radius, height: sin(angle) * radius * 0.72),
                velocity: CGSize(width: cos(angle) * speed, height: sin(angle) * speed),
                size: CGFloat(rng.double(in: 8...16)),
                alpha: rng.double(in: 0.34...0.72),
                rotation: rng.double(in: -0.35...0.35),
                spin: rng.double(in: -0.9...0.9),
                delay: rng.double(in: 0...0.16),
                isSpark: index >= glyphs.count || rng.double(in: 0...1) > 0.68
            )
        }
    }
}

private struct LivingInkRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    mutating func double(in range: Range<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    mutating func int(in range: Range<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound))
    }
}

private final class BookHapticEngine {
    static let shared = BookHapticEngine()

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    private var lastPlayedAt: [String: Date] = [:]
    #endif

    private init() {
        prepare()
    }

    func modeDidChange() {
        if BookFeedback.hapticMode == .off {
            #if canImport(CoreHaptics)
            engine?.stop(completionHandler: nil)
            #endif
        } else {
            prepare()
        }
    }

    func play(_ cue: BookFeedback.Cue) -> Bool {
        switch cue {
        case .tap: return pattern("tap", [beat(0, 0.22, 0.55)])
        case .select: return pattern("select", [beat(0, 0.28, 0.72)])
        case .openPage: return pattern("open-page", [beat(0, 0.20, 0.18), beat(0.075, 0.28, 0.38), beat(0.16, 0.34, 0.62)])
        case .keepPage: return pattern("keep-page", [beat(0, 0.34, 0.74), beat(0.11, 0.22, 0.30), beat(0.25, 0.48, 0.42)])
        case .dismissPage: return pattern("dismiss-page", [beat(0, 0.30, 0.72), beat(0.10, 0.16, 0.28)])
        case .undo: return pattern("undo", [beat(0, 0.30, 0.68), beat(0.13, 0.22, 0.42)])
        case .braidStart: return pattern("braid-start", [beat(0, 0.14, 0.18), beat(0.08, 0.18, 0.28), beat(0.17, 0.23, 0.42)])
        case .braidComplete: return pattern("braid-complete", [beat(0, 0.22, 0.30), beat(0.10, 0.35, 0.52), beat(0.22, 0.48, 0.72)])
        case .sourceRefresh: return pattern("source-refresh", [beat(0, 0.18, 0.28), beat(0.09, 0.24, 0.48)])
        case .error: return pattern("error", [beat(0, 0.60, 0.90), beat(0.16, 0.42, 0.82)])
        case .knock: return pattern("knock", [beat(0, 0.72, 0.94)])
        case .knockReply: return pattern("knock-reply", [beat(0, 0.48, 0.60), beat(0.22, 0.42, 0.52)])
        }
    }

    func playBeliefTransfer(amount: Int, recipientGlow: Int) {
        let count = max(1, min(5, amount))
        var events = (0..<count).map { index in
            beat(Double(index) * 0.075, 0.20 + Double(index) * 0.05, 0.35 + Double(index) * 0.08)
        }
        events.append(beat(Double(count) * 0.075 + 0.12, min(0.78, 0.38 + Double(recipientGlow) / 220), 0.34))
        _ = pattern("belief-transfer", events, minimumInterval: 0.12)
    }

    func playBookJump(_ cue: BookFeedback.BookJumpCue) {
        let events: [HapticBeat]
        switch cue {
        case .start:
            events = [beat(0, 0.12, 0.18), beat(0.06, 0.18, 0.30), beat(0.12, 0.28, 0.45), beat(0.19, 0.44, 0.64), beat(0.31, 0.88, 0.92)]
        case .deeper:
            events = [beat(0, 0.82, 0.16), beat(0.16, 0.48, 0.30)]
        case .stabilize:
            events = [beat(0, 0.12, 0.82), beat(0.12, 0.16, 0.66), beat(0.24, 0.24, 0.48), beat(0.39, 0.42, 0.30)]
        case .returnHome:
            events = [beat(0, 0.62, 0.48), beat(0.10, 0.42, 0.40), beat(0.20, 0.28, 0.32), beat(0.34, 0.20, 0.22), beat(0.52, 0.50, 0.38)]
        }
        _ = pattern("book-jump-\(cue)", events, minimumInterval: 0.25)
    }

    func playFaeArrival(kind: String, court: String?) {
        let key = kind.lowercased()
        let events: [HapticBeat]
        if key.contains("pixie") {
            events = [beat(0, 0.15, 0.82), beat(0.045, 0.12, 0.74), beat(0.14, 0.18, 0.88), beat(0.20, 0.10, 0.68)]
        } else if key.contains("goblin") {
            events = [beat(0, 0.62, 0.82), beat(0.09, 0.40, 0.70), beat(0.17, 0.54, 0.76)]
        } else if key.contains("sprite") {
            events = [beat(0, 0.12, 0.20), beat(0.07, 0.18, 0.36), beat(0.15, 0.25, 0.54), beat(0.25, 0.34, 0.72)]
        } else if key.contains("salamander") {
            events = [beat(0, 0.18, 0.22), beat(0.07, 0.27, 0.36), beat(0.14, 0.39, 0.50), beat(0.22, 0.52, 0.66)]
        } else if key.contains("dwarf") {
            events = [beat(0, 0.76, 0.36), beat(0.28, 0.82, 0.30)]
        } else if court?.lowercased().contains("unseelie") == true {
            events = [beat(0, 0.46, 0.50), beat(0.13, 0.34, 0.38), beat(0.41, 0.58, 0.62)]
        } else {
            events = [beat(0, 0.38, 0.38), beat(0.13, 0.48, 0.48), beat(0.26, 0.38, 0.38)]
        }
        _ = pattern("fae-\(key)", events, minimumInterval: 0.5)
    }

    func playConstellation(nodes: Int) {
        let count = max(2, min(nodes, 7))
        var events = (0..<count).map { beat(Double($0) * 0.07, 0.16, 0.78) }
        events.append(beat(Double(count) * 0.07 + 0.10, 0.52, 0.30))
        _ = pattern("constellation", events, minimumInterval: 1)
    }

    func playChapterBinding() {
        _ = pattern("chapter-binding", [beat(0, 0.18, 0.18), beat(0.10, 0.24, 0.26), beat(0.21, 0.32, 0.38), beat(0.34, 0.44, 0.52), beat(0.52, 0.92, 0.82)], minimumInterval: 2)
    }

    /// The print-ready export — the month set for a physical press. A heavy
    /// approach, the foil stamp landing hard and sharp, a release, a confirming
    /// second stamp, then a metallic settle. Weightier than the sewn cue: this
    /// one is about atoms, not pages.
    func playPressReady() {
        _ = pattern(
            "press-ready",
            [
                beat(0.00, 0.55, 0.30),
                beat(0.18, 1.00, 0.95),
                beat(0.31, 0.40, 0.60),
                beat(0.50, 0.86, 0.90),
                beat(0.66, 0.30, 0.52)
            ],
            minimumInterval: 2
        )
    }

    /// The Monthly Binding — the biggest recurring peak. Four quick rising
    /// stitches (the signatures being sewn), a soft low settle (the covers
    /// closing), then a firm, sharp press (the gilt wax seal). Deliberately
    /// grander and longer than any single-page cue.
    func playMonthBound() {
        _ = pattern(
            "month-bound",
            [
                beat(0.00, 0.14, 0.32),
                beat(0.10, 0.17, 0.36),
                beat(0.20, 0.20, 0.40),
                beat(0.30, 0.24, 0.44),
                beat(0.46, 0.44, 0.22),
                beat(0.68, 0.72, 0.20),
                beat(0.94, 1.00, 0.94)
            ],
            minimumInterval: 2
        )
    }

    func playPageRise(rarity: Int) {
        var events = [beat(0, 0.10, 0.18), beat(0.06, 0.14, 0.28), beat(0.13, 0.20, 0.42)]
        if rarity >= 80 { events.append(beat(0.34, 0.58, 0.66)) }
        _ = pattern("page-rise", events, minimumInterval: 0.8)
    }

    func playNothing(level: Int) {
        let pressure = max(1, min(level, 4))
        var events = [beat(0, 0.36, 0.92)]
        if pressure >= 2 { events.append(beat(0.19, 0.26, 0.84)) }
        if pressure >= 4 { events.append(beat(0.58, 0.12, 0.76)) }
        _ = pattern("nothing", events, minimumInterval: 1)
    }

    func playRadioLock() {
        _ = pattern("radio-lock", [beat(0, 0.12, 0.82), beat(0.05, 0.14, 0.78), beat(0.11, 0.18, 0.70), beat(0.22, 0.62, 0.42)], minimumInterval: 0.35)
    }

    private struct HapticBeat {
        var time: TimeInterval
        var intensity: Double
        var sharpness: Double
    }

    private func beat(_ time: TimeInterval, _ intensity: Double, _ sharpness: Double) -> HapticBeat {
        HapticBeat(time: time, intensity: intensity, sharpness: sharpness)
    }

    private func prepare() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { [weak self] _ in self?.engine = nil }
            engine.resetHandler = { [weak self] in
                self?.engine = nil
                self?.prepare()
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
        #endif
    }

    @discardableResult
    private func pattern(_ key: String, _ beats: [HapticBeat], minimumInterval: TimeInterval = 0.04) -> Bool {
        #if canImport(CoreHaptics)
        let mode = BookFeedback.hapticMode
        guard mode != .off, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        let now = Date()
        if let last = lastPlayedAt[key], now.timeIntervalSince(last) < minimumInterval { return true }
        lastPlayedAt[key] = now
        prepare()
        guard let engine else { return false }
        let scale = mode == .gentle ? 0.48 : 1.0
        let selected = mode == .gentle && beats.count > 3
            ? beats.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
            : beats
        let events = selected.map { item in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(min(1, item.intensity * scale))),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(min(1, item.sharpness)))
                ],
                relativeTime: item.time
            )
        }
        do {
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            self.engine = nil
            return false
        }
        #else
        return false
        #endif
    }
}

#if canImport(AVFoundation)
@Observable
@MainActor
final class BookRadioManager: NSObject, AVAudioPlayerDelegate {
    static let shared = BookRadioManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var filePlayer: AVAudioPlayer?
    private var activeBuffer: AVAudioPCMBuffer?
    private var didAttachPlayer = false
    private var didConfigureRemoteCommands = false
    private var systemNowPlayingStartedAt: Date?
    private var systemNowPlayingPausedElapsed: TimeInterval?
    private var systemNowPlayingDuration: TimeInterval?

    private(set) var playback = RadioPlaybackState.off
    private(set) var activeStation: RadioStation?
    private(set) var activeTrack: RadioTrack?
    private(set) var isPlaying = false
    private(set) var isPlayingTuningNoise = false
    private(set) var statusLine = "The dial is cold."
    private(set) var sourceLine = "No broadcast is tuned."
    /// The DJ break currently on air, if any (for UI; nil while a song plays).
    private(set) var nowPlayingBanter: RadioBanter?

    /// Packs unlocked when the current station was tuned — needed to re-resolve
    /// the station for banter selection as the playout loop advances.
    private var currentPackIDs: Set<String> = []
    /// Songs played since this station was tuned, drives the banter cadence.
    private var tracksSinceTune = 0
    /// Songs since the last spoken break. Alive cadence varies between one and
    /// two rather than marching on a fixed modulo.
    private var tracksSinceBanter = 0
    /// True while a spoken break is on air (so the finish handler knows to
    /// resume music rather than count another song).
    private var isPlayingBanter = false
    /// True while a station-format interstitial (for example pirate static)
    /// is on air between real broadcast items.
    private var isPlayingInterstitial = false
    /// A lock-screen pause is reversible. The in-app power/Quiet controls still
    /// call `stop`, which clears the station and removes Now Playing metadata.
    private var isPausedByRemoteControl = false
    /// A memory-pressure pause is also reversible, but only by the local-brain
    /// work lifecycle that caused it. User power/Quiet controls still win.
    private var isPausedForMemoryPressure = false
    /// Invalidates pending caption-only advances when the dial changes.
    private var playoutToken = UUID()
    /// Song queued to play once the current DJ break finishes.
    private var pendingTrack: RadioTrack?
    /// DJ break queued to play once an interstitial finishes.
    private var pendingBanter: RadioBanter?

    /// Optional hook so the app can feed live world-state (Routine's grey,
    /// an active festival) into banter selection without coupling the manager to
    /// the broader state graph. Time-of-day and the listening streak are derived
    /// locally. Returns (grey 0–100, festivalActive).
    var worldContextProvider: (() -> (grey: Int, festivalActive: Bool, pageContext: RadioPageContext))?

    /// Latest world snapshot pushed by the app (see `updateWorldState`). Takes
    /// precedence over `worldContextProvider`; both fall back to calm.
    private var liveWorld: (grey: Int, festivalActive: Bool, pageContext: RadioPageContext)?
    /// The current score from the existing BookSessionDirector. Updating it
    /// never interrupts audio; it changes only the next playout decision.
    private var liveExperienceProgram: BookExperienceProgram?

    /// Push the current world-state in. Cheap to call often (e.g. on appear, on
    /// tune, on scene-active) — grey/festival change at most daily. `grey` is on
    /// the 0–100 scale the banter conditions use.
    func updateWorldState(grey: Int, festivalActive: Bool, pageContext: RadioPageContext = RadioPageContext()) {
        liveWorld = (max(0, min(100, grey)), festivalActive, pageContext)
    }

    func updateExperienceProgram(_ program: BookExperienceProgram?) {
        guard let program, Date() < program.expiresAt else {
            liveExperienceProgram = nil
            return
        }
        liveExperienceProgram = program
    }

    private override init() { super.init() }

    func restore(state: RadioPlaybackState, unlockedPackIDs: Set<String>) {
        configureSystemNowPlayingIfNeeded()
        playback = state
        tracksSinceTune = 0
        tracksSinceBanter = 0
        activeStation = RadioStationRegistry.station(id: state.activeStationID, unlockedPackIDs: unlockedPackIDs)
        // Remember which station was last tuned for display, but do not resume
        // playback on launch — the dial stays silent until the reader tunes in.
        isPlaying = false
        if let station = activeStation, state.isTuned {
            activeTrack = selectTrack(for: station)
            statusLine = "\(station.displayFrequency) \(station.title) — tap to tune in."
            sourceLine = "No broadcast is tuned."
        }
    }

    func tune(to station: RadioStation, unlockedPackIDs: Set<String>, persist: Bool = true) {
        configureAudioSession()
        configureSystemNowPlayingIfNeeded()
        currentPackIDs = unlockedPackIDs
        tracksSinceTune = 0
        tracksSinceBanter = 0
        isPlayingBanter = false
        isPlayingInterstitial = false
        isPausedByRemoteControl = false
        isPausedForMemoryPressure = false
        isPlayingTuningNoise = false
        nowPlayingBanter = nil
        playoutToken = UUID()
        pendingTrack = nil
        pendingBanter = nil

        let track = selectTrack(for: station)
        isPlaying = true
        activeStation = station
        playback = RadioPlaybackState(
            activeStationID: station.id,
            startedAt: playback.activeStationID == station.id ? playback.startedAt ?? Date() : Date(),
            lastTunedAt: Date(),
            lastTrackID: track?.id,
            tuningNoise: 0,
            listening: playback.listening,
            recentBanterIDs: playback.activeStationID == station.id ? playback.recentBanterIDs : nil,
            recentTrackIDs: playback.activeStationID == station.id ? playback.recentTrackIDs : nil
        )
        // A real tune (not a silent restore) counts as listening today — the
        // substrate for listening constellations and held-station effects.
        if persist {
            playback.recordListening(stationID: station.id)
        }

        beginTrack(track, for: station)

        if persist {
            PlayerVault.shared.data.radio = playback
            PlayerVault.shared.save()
        }
    }

    /// Play one song. Real assets play once (numberOfLoops = 0) so the delegate
    /// can advance the playout loop and slip DJ breaks between songs; the
    /// procedural fallback still loops (no sequencing without bundled audio).
    private func beginTrack(_ track: RadioTrack?, for station: RadioStation) {
        isPlayingBanter = false
        isPlayingInterstitial = false
        nowPlayingBanter = nil
        player.stop()
        filePlayer?.stop()
        filePlayer = nil

        if let track, let url = resolvedAudioURL(for: track) {
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer.numberOfLoops = 0
                audioPlayer.volume = station.id == "thornwave" ? 0.48 : 0.42
                audioPlayer.delegate = self
                audioPlayer.prepareToPlay()
                guard audioPlayer.play() else {
                    playProceduralFallback(for: station, track: track)
                    return
                }
                filePlayer = audioPlayer
                activeBuffer = nil
                activeTrack = track
                sourceLine = "Playing \(track.title) from local radio assets."
                updateSystemNowPlayingSong(track, station: station, duration: audioPlayer.duration)
                PlayerVault.shared.data.lastRadioTrackPlay = RadioTrackPlayReceipt(
                    stationID: station.id, trackID: track.id, startedAt: Date()
                )
                PlayerVault.shared.save()
            } catch {
                appLog.error("Radio asset failed: \(error.localizedDescription, privacy: .public)")
                playProceduralFallback(for: station, track: track)
            }
        } else {
            playProceduralFallback(for: station, track: track)
        }

        if let trackID = track?.id {
            playback.recordTrack(trackID, stationTrackIDs: station.tracks.map(\.id))
            recordExperienceBroadcast(
                stationID: station.id,
                kind: .track,
                itemID: trackID,
                candidateIDs: station.tracks.map(\.id)
            )
        }
        statusLine = "\(station.displayFrequency) \(station.title) — \(track?.title ?? "broadcasting")."
    }

    // MARK: - Playout loop (songs interleaved with DJ breaks)

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.handlePlayoutItemFinished() }
    }

    private func handlePlayoutItemFinished() {
        guard isPlaying, let station = activeStation else { return }
        if isPlayingInterstitial {
            resumeAfterInterstitial(for: station)
            return
        }
        if isPlayingBanter {
            // A break just ended — play whatever song was queued behind it (an
            // intro's bound song, or the next in rotation) so the order holds.
            if shouldPlayInterstitial(for: station) {
                playInterstitial(for: station)
            } else {
                resumeAfterBanter(for: station)
            }
            return
        }
        // A song just ended. Look both ways: the song that just finished (for
        // outro transitions) and the song queued next (for intros).
        tracksSinceTune += 1
        tracksSinceBanter += 1
        let justFinishedID = activeTrack?.id
        let upcoming = selectNextTrack(for: station)
        let context = makeWorldContext(for: station)
        if RadioStationRegistry.shouldBanter(
            songsSinceLastBanter: tracksSinceBanter,
            state: playback,
            context: context,
            justFinishedTrackID: justFinishedID,
            upcomingTrackID: upcoming?.id,
            unlockedPackIDs: currentPackIDs
        ),
           let banter = RadioStationRegistry.nextBanter(
                state: playback,
                context: context,
                unlockedPackIDs: currentPackIDs,
                justFinishedTrackID: justFinishedID,
                upcomingTrackID: upcoming?.id
           ) {
            // Hold the upcoming song so it plays right after the break — this is
            // what makes an intro ("Coming up, Folktronica…") land on its song.
            pendingTrack = upcoming
            if shouldPlayExperienceSilence(for: station) {
                pendingBanter = banter
                playExperienceSilence(for: station)
            } else if shouldPlayInterstitial(for: station) {
                pendingBanter = banter
                playInterstitial(for: station)
            } else {
                playBanter(banter, for: station)
            }
        } else {
            if shouldPlayExperienceSilence(for: station) {
                pendingTrack = upcoming
                playExperienceSilence(for: station)
            } else if shouldPlayInterstitial(for: station) {
                pendingTrack = nil
                playInterstitial(for: station)
            } else {
                pendingTrack = nil
                beginTrack(upcoming, for: station)
            }
        }
    }

    private func shouldPlayExperienceSilence(for station: RadioStation) -> Bool {
        guard let program = liveExperienceProgram,
              program.nextBroadcastFunction == .release,
              !program.nextBroadcastIsAutonomous,
              program.broadcastReceipts.last?.kind != .silence else {
            return false
        }
        let seed = "\(program.seed)|silence|\(station.id)|\(playback.lastTrackID ?? "none")|\(tracksSinceTune)"
        return UInt(bitPattern: seed.stableHash) % 3 == 0
    }

    /// A short, authored absence between playout items. It never powers the
    /// station off or asks the reader to return; it simply lets a clean no or
    /// completed Page stop echoing for one measure.
    private func playExperienceSilence(for station: RadioStation) {
        nowPlayingBanter = nil
        isPlayingBanter = false
        isPlayingInterstitial = true
        statusLine = "\(station.displayFrequency) \(station.title) — one empty measure."
        sourceLine = "The station leaves a little air between things."
        player.stop()
        filePlayer?.stop()
        filePlayer = nil
        recordExperienceBroadcast(
            stationID: station.id,
            kind: .silence,
            itemID: "one-empty-measure",
            candidateIDs: ["one-empty-measure"]
        )
        let token = playoutToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self,
                  self.isPlaying,
                  self.isPlayingInterstitial,
                  self.playoutToken == token else { return }
            self.resumeAfterInterstitial(for: station)
        }
    }

    private func shouldPlayInterstitial(for station: RadioStation) -> Bool {
        station.interstitialAssetName.flatMap { resolvedAudioURL(forAssetName: $0) } != nil
    }

    private func playInterstitial(for station: RadioStation) {
        guard let asset = station.interstitialAssetName,
              let url = resolvedAudioURL(forAssetName: asset) else {
            resumeAfterInterstitial(for: station)
            return
        }
        nowPlayingBanter = nil
        isPlayingBanter = false
        isPlayingInterstitial = true
        statusLine = "\(station.displayFrequency) \(station.title) — static between broadcasts."
        sourceLine = "On air: \(station.interstitialTitle ?? "Pirate static")."
        player.stop()
        filePlayer?.stop()
        filePlayer = nil

        do {
            let staticPlayer = try AVAudioPlayer(contentsOf: url)
            staticPlayer.numberOfLoops = 0
            staticPlayer.volume = 0.72
            staticPlayer.delegate = self
            staticPlayer.prepareToPlay()
            staticPlayer.play()
            filePlayer = staticPlayer
            recordExperienceBroadcast(
                stationID: station.id,
                kind: .interstitial,
                itemID: station.interstitialTitle ?? asset,
                candidateIDs: [station.interstitialTitle ?? asset]
            )
            updateSystemNowPlayingStatic(frequency: station.frequency)
        } catch {
            appLog.error("Radio interstitial failed: \(error.localizedDescription, privacy: .public)")
            resumeAfterInterstitial(for: station)
        }
    }

    private func resumeAfterInterstitial(for station: RadioStation) {
        isPlayingInterstitial = false
        if let banter = pendingBanter {
            pendingBanter = nil
            playBanter(banter, for: station)
        } else {
            resumeAfterBanter(for: station)
        }
    }

    private func playBanter(_ banter: RadioBanter, for station: RadioStation) {
        playback.recordBanter(banter.id)
        recordExperienceBroadcast(
            stationID: station.id,
            kind: .banter,
            itemID: banter.id,
            candidateIDs: station.resolvedBanters.map(\.id)
        )
        tracksSinceBanter = 0
        nowPlayingBanter = banter
        isPlayingInterstitial = false
        statusLine = "\(station.displayFrequency) \(station.title) — \(station.hostDisplayName) on air."
        player.stop()
        filePlayer?.stop()
        filePlayer = nil
        PlayerVault.shared.data.radio = playback
        PlayerVault.shared.save()

        if let asset = banter.assetName, let url = resolvedAudioURL(forAssetName: asset) {
            do {
                let voice = try AVAudioPlayer(contentsOf: url)
                voice.numberOfLoops = 0
                voice.volume = 1.0
                voice.delegate = self
                voice.prepareToPlay()
                voice.play()
                filePlayer = voice
                isPlayingBanter = true
                sourceLine = "On air: \(station.title) — \(banter.category)."
                updateSystemNowPlayingBanter(banter, station: station, duration: voice.duration)
                return
            } catch {
                appLog.error("Banter asset failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        // Caption-only (no audio yet): hold the line a beat, then resume music.
        isPlayingBanter = false
        sourceLine = "On air: \(station.title) — \(banter.category) (caption)."
        updateSystemNowPlayingBanter(banter, station: station, duration: 5)
        let token = playoutToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.isPlaying, self.playoutToken == token else { return }
            self.resumeAfterBanter(for: station)
        }
    }

    /// After a DJ break, play the song held behind it (the intro's bound song or
    /// the next in rotation), then clear the hold.
    private func resumeAfterBanter(for station: RadioStation) {
        let track = pendingTrack ?? selectNextTrack(for: station)
        pendingTrack = nil
        pendingBanter = nil
        beginTrack(track, for: station)
    }

    func tune(stationID: String, unlockedPackIDs: Set<String>) {
        guard let station = RadioStationRegistry.station(id: stationID, unlockedPackIDs: unlockedPackIDs) else {
            statusLine = "That frequency is not unlocked yet."
            return
        }
        tune(to: station, unlockedPackIDs: unlockedPackIDs)
        BookFeedback.radioLocked()
    }

    func tuneDial(frequency: Double, unlockedPackIDs: Set<String>) {
        if let station = RadioStationRegistry.tunedStation(to: frequency, unlockedPackIDs: unlockedPackIDs) {
            if activeStation?.id == station.id, isPlaying, !isPlayingTuningNoise { return }
            tune(to: station, unlockedPackIDs: unlockedPackIDs)
            BookFeedback.radioLocked()
        } else {
            playTuningNoise(frequency: frequency)
        }
    }

    func playTuningNoise(frequency: Double, persist: Bool = true) {
        configureAudioSession()
        configureSystemNowPlayingIfNeeded()
        currentPackIDs = []
        tracksSinceTune = 0
        tracksSinceBanter = 0
        isPlaying = true
        isPlayingBanter = false
        isPlayingInterstitial = false
        isPausedByRemoteControl = false
        isPausedForMemoryPressure = false
        isPlayingTuningNoise = true
        nowPlayingBanter = nil
        activeStation = nil
        activeTrack = nil
        pendingTrack = nil
        pendingBanter = nil
        playoutToken = UUID()

        let noise = min(1, max(0.18, abs(sin(frequency)) * 0.82))
        playback = RadioPlaybackState(
            activeStationID: nil,
            startedAt: nil,
            lastTunedAt: Date(),
            lastTrackID: nil,
            tuningNoise: noise,
            listening: playback.listening,
            recentBanterIDs: playback.recentBanterIDs,
            recentTrackIDs: playback.recentTrackIDs
        )
        statusLine = String(format: "%.1f FM — static between stations.", frequency)
        sourceLine = staticSourceLine(for: frequency)

        filePlayer?.stop()
        filePlayer = nil
        attachPlayerIfNeeded()
        if !player.isPlaying || activeBuffer == nil {
            let buffer = makeTuningNoiseBuffer(seedFrequency: frequency)
            activeBuffer = buffer
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: [.loops])
            if !engine.isRunning {
                do {
                    try engine.start()
                } catch {
                    statusLine = "The static sparked but would not hold: \(error.localizedDescription)"
                    appLog.error("Radio static engine failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
            }
            player.volume = 0.20
            player.play()
        }

        if persist {
            PlayerVault.shared.data.radio = playback
            PlayerVault.shared.save()
        }
        updateSystemNowPlayingStatic(frequency: frequency)
    }

    func stop(persist: Bool = true) {
        player.stop()
        filePlayer?.stop()
        filePlayer = nil
        activeBuffer = nil
        isPlaying = false
        isPlayingBanter = false
        isPlayingInterstitial = false
        isPausedByRemoteControl = false
        isPausedForMemoryPressure = false
        isPlayingTuningNoise = false
        nowPlayingBanter = nil
        tracksSinceTune = 0
        tracksSinceBanter = 0
        playoutToken = UUID()
        pendingTrack = nil
        pendingBanter = nil
        playback = .off
        activeStation = nil
        activeTrack = nil
        statusLine = "The dial is cold."
        sourceLine = "No broadcast is tuned."
        if persist {
            PlayerVault.shared.data.radio = playback
            PlayerVault.shared.save()
        }
        clearSystemNowPlaying()
    }

    func hapticTick() {
        BookFeedback.play(.select)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            appLog.error("Radio audio session failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func configureSystemNowPlayingIfNeeded() {
        #if canImport(MediaPlayer)
        guard !didConfigureRemoteCommands else {
            updateRemoteCommandAvailability()
            return
        }
        didConfigureRemoteCommands = true
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in _ = self?.resumeFromRemoteControl() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in _ = self?.pauseFromRemoteControl() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggleRemotePlayback() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in _ = self?.skipToNextRadioItemFromRemoteControl() }
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        #if canImport(UIKit)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
        updateRemoteCommandAvailability()
        #endif
    }

    private func pauseFromRemoteControl() -> Bool {
        guard isPlaying else { return false }
        systemNowPlayingPausedElapsed = currentSystemNowPlayingElapsed()
        filePlayer?.pause()
        if player.isPlaying {
            player.pause()
        }
        isPlaying = false
        isPausedByRemoteControl = true
        isPausedForMemoryPressure = false
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — paused." } ?? "Radio static paused."
        setSystemNowPlayingPlaybackRate(0)
        return true
    }

    private func resumeFromRemoteControl() -> Bool {
        guard isPausedByRemoteControl else { return false }
        guard resumePausedPlayback() else { return false }
        isPausedByRemoteControl = false
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — on air." } ?? "Radio static on air."
        setSystemNowPlayingPlaybackRate(1)
        return true
    }

    @discardableResult
    func pauseForMemoryPressureDuringGeneration() -> Bool {
        guard isPlaying else { return false }
        systemNowPlayingPausedElapsed = currentSystemNowPlayingElapsed()
        filePlayer?.pause()
        if player.isPlaying {
            player.pause()
        }
        isPlaying = false
        isPausedByRemoteControl = false
        isPausedForMemoryPressure = true
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — paused while the local brain frees memory." } ?? "Radio static paused while the local brain frees memory."
        setSystemNowPlayingPlaybackRate(0)
        AppMemoryLedger.record("radio-paused-for-memory-pressure")
        return true
    }

    @discardableResult
    func resumeAfterMemoryPressureIfNeeded() -> Bool {
        guard isPausedForMemoryPressure else { return false }
        guard resumePausedPlayback() else { return false }
        isPausedForMemoryPressure = false
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — on air." } ?? "Radio static on air."
        setSystemNowPlayingPlaybackRate(1)
        AppMemoryLedger.record("radio-resumed-after-memory-pressure")
        return true
    }

    private func resumePausedPlayback() -> Bool {
        configureAudioSession()
        if let elapsed = systemNowPlayingPausedElapsed {
            systemNowPlayingStartedAt = Date().addingTimeInterval(-elapsed)
        }
        systemNowPlayingPausedElapsed = nil
        if filePlayer == nil, nowPlayingBanter != nil, let station = activeStation {
            resumeAfterBanter(for: station)
        } else if let filePlayer {
            filePlayer.play()
        } else if activeBuffer != nil {
            attachPlayerIfNeeded()
            if !engine.isRunning {
                do {
                    try engine.start()
                } catch {
                    appLog.error("Radio engine resume failed: \(error.localizedDescription, privacy: .public)")
                    return false
                }
            }
            player.play()
        } else if let station = activeStation {
            beginTrack(activeTrack ?? selectTrack(for: station), for: station)
        } else {
            return false
        }
        isPlaying = true
        return true
    }

    private func toggleRemotePlayback() {
        if isPlaying {
            _ = pauseFromRemoteControl()
        } else {
            _ = resumeFromRemoteControl()
        }
    }

    private func skipToNextRadioItemFromRemoteControl() -> Bool {
        guard let station = activeStation else { return false }
        configureAudioSession()
        configureSystemNowPlayingIfNeeded()
        pendingTrack = nil
        pendingBanter = nil
        isPlaying = true
        isPausedByRemoteControl = false
        isPausedForMemoryPressure = false
        isPlayingBanter = false
        isPlayingInterstitial = false
        tracksSinceTune += 1
        beginTrack(selectNextTrack(for: station), for: station)
        PlayerVault.shared.data.radio = playback
        PlayerVault.shared.save()
        return true
    }

    private func updateSystemNowPlayingSong(_ track: RadioTrack?, station: RadioStation, duration: TimeInterval?) {
        #if canImport(MediaPlayer)
        configureSystemNowPlayingIfNeeded()
        systemNowPlayingStartedAt = Date()
        systemNowPlayingPausedElapsed = nil
        systemNowPlayingDuration = duration ?? track?.durationSeconds.map(TimeInterval.init)

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track?.title ?? station.title,
            MPMediaItemPropertyArtist: track?.artist ?? station.title,
            MPMediaItemPropertyAlbumTitle: "\(station.displayFrequency) \(station.title)",
            MPNowPlayingInfoPropertyIsLiveStream: duration == nil,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let duration = systemNowPlayingDuration, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork = makeRadioArtwork(title: station.title) {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
        updateRemoteCommandAvailability()
        #endif
    }

    private func updateSystemNowPlayingBanter(_ banter: RadioBanter, station: RadioStation, duration: TimeInterval?) {
        #if canImport(MediaPlayer)
        configureSystemNowPlayingIfNeeded()
        systemNowPlayingStartedAt = Date()
        systemNowPlayingPausedElapsed = nil
        systemNowPlayingDuration = duration

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "DJ: \(station.hostDisplayName)",
            MPMediaItemPropertyArtist: station.title,
            MPMediaItemPropertyAlbumTitle: "\(station.displayFrequency) \(station.title)",
            MPMediaItemPropertyComments: banter.readerFacingCaption,
            MPNowPlayingInfoPropertyIsLiveStream: duration == nil,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let duration, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork = makeRadioArtwork(title: station.hostDisplayName) {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
        updateRemoteCommandAvailability()
        #endif
    }

    private func updateSystemNowPlayingStatic(frequency: Double) {
        #if canImport(MediaPlayer)
        configureSystemNowPlayingIfNeeded()
        systemNowPlayingStartedAt = Date()
        systemNowPlayingPausedElapsed = nil
        systemNowPlayingDuration = nil

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "Static between stations",
            MPMediaItemPropertyArtist: "ReEnchanted Radio",
            MPMediaItemPropertyAlbumTitle: String(format: "%.1f FM", frequency),
            MPMediaItemPropertyComments: sourceLine,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let artwork = makeRadioArtwork(title: "Static") {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
        updateRemoteCommandAvailability()
        #endif
    }

    private func setSystemNowPlayingPlaybackRate(_ rate: Double) {
        #if canImport(MediaPlayer)
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentSystemNowPlayingElapsed()
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = rate == 0 ? .paused : .playing
        updateRemoteCommandAvailability()
        #endif
    }

    private func clearSystemNowPlaying() {
        #if canImport(MediaPlayer)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        systemNowPlayingStartedAt = nil
        systemNowPlayingPausedElapsed = nil
        systemNowPlayingDuration = nil
        updateRemoteCommandAvailability()
        #endif
    }

    private func currentSystemNowPlayingElapsed() -> TimeInterval {
        if let filePlayer {
            return filePlayer.currentTime
        }
        if let paused = systemNowPlayingPausedElapsed {
            return paused
        }
        guard let startedAt = systemNowPlayingStartedAt else { return 0 }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        if let duration = systemNowPlayingDuration, duration > 0 {
            return elapsed.truncatingRemainder(dividingBy: duration)
        }
        return elapsed
    }

    private func updateRemoteCommandAvailability() {
        #if canImport(MediaPlayer)
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = isPausedByRemoteControl
        commandCenter.pauseCommand.isEnabled = isPlaying
        commandCenter.togglePlayPauseCommand.isEnabled = isPlaying || isPausedByRemoteControl
        commandCenter.nextTrackCommand.isEnabled = activeStation != nil
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        #endif
    }

    private func makeRadioArtwork(title: String) -> Any? {
        #if canImport(MediaPlayer) && canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
            UIColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1).setFill()
            context.fill(rect)
            UIColor(red: 0.96, green: 0.73, blue: 0.36, alpha: 1).setStroke()
            let outer = CGRect(x: 64, y: 64, width: 384, height: 384)
            UIBezierPath(ovalIn: outer).stroke()
            let icon = UIImage(systemName: "radio.fill")?
                .withTintColor(UIColor(red: 0.96, green: 0.73, blue: 0.36, alpha: 1), renderingMode: .alwaysOriginal)
            icon?.draw(in: CGRect(x: 166, y: 128, width: 180, height: 180))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor(red: 0.93, green: 0.88, blue: 0.76, alpha: 1),
                .paragraphStyle: paragraph
            ]
            let displayTitle = String(title.prefix(28))
            displayTitle.draw(in: CGRect(x: 46, y: 326, width: 420, height: 92), withAttributes: attributes)
        }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        #else
        return nil
        #endif
    }

    private func attachPlayerIfNeeded() {
        guard !didAttachPlayer else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: makeFormat())
        didAttachPlayer = true
    }

    private func selectTrack(for station: RadioStation) -> RadioTrack? {
        let previous = playback.activeStationID == station.id ? playback.lastTrackID : nil
        return selectCuratedTrack(for: station, previousTrackID: previous, playTurn: 0)
    }

    /// Next song for the playout loop: score the station's candidates from the
    /// current time slot, prior track, and play turn so the broadcast feels
    /// curated rather than linear while still avoiding immediate repeats.
    private func selectNextTrack(for station: RadioStation) -> RadioTrack? {
        guard !station.tracks.isEmpty else { return nil }
        return selectCuratedTrack(for: station, previousTrackID: playback.lastTrackID, playTurn: tracksSinceTune)
    }

    private func selectCuratedTrack(for station: RadioStation, previousTrackID: String?, playTurn: Int, now: Date = Date()) -> RadioTrack? {
        let sameStation = playback.activeStationID == station.id
        let sessionDate = sameStation ? playback.startedAt ?? now : now
        return RadioStationRegistry.curatedTrack(
            station: station,
            previousTrackID: previousTrackID,
            recentTrackIDs: sameStation ? playback.recentTrackIDs ?? [] : [],
            playTurn: playTurn,
            context: makeWorldContext(for: station, now: now),
            sessionSeed: String(sessionDate.timeIntervalSince1970),
            now: now
        )
    }

    /// Snapshot of live world-state for banter conditions. Time-of-day and the
    /// listening streak are derived here; grey/festival come from the app via
    /// `worldContextProvider` when wired (defaults to calm).
    private func makeWorldContext(for station: RadioStation, now: Date = Date()) -> RadioWorldContext {
        let world = liveWorld ?? worldContextProvider?() ?? (grey: 0, festivalActive: false, pageContext: RadioPageContext())
        return RadioWorldContext(
            timeOfDay: RadioWorldContext.band(for: now),
            grey: world.grey,
            festivalActive: world.festivalActive,
            listeningDays: playback.daysHeard(stationID: station.id),
            weekday: Calendar.current.component(.weekday, from: now),
            pageContext: world.pageContext,
            experienceProgram: liveExperienceProgram
        )
    }

    private func recordExperienceBroadcast(
        stationID: String,
        kind: BookExperienceBroadcastKind,
        itemID: String,
        candidateIDs: [String],
        now: Date = Date()
    ) {
        guard var program = liveExperienceProgram, now < program.expiresAt else {
            liveExperienceProgram = nil
            return
        }
        program.recordBroadcast(
            stationID: stationID,
            kind: kind,
            itemID: itemID,
            candidateIDs: candidateIDs,
            at: now
        )
        liveExperienceProgram = program
        PlayerVault.shared.data.activeExperienceProgram = program
        PlayerVault.shared.save()
    }

    private func resolvedAudioURL(for track: RadioTrack) -> URL? {
        resolvedAudioURL(forAssetName: track.assetName)
    }

    private func resolvedAudioURL(forAssetName rawName: String?) -> URL? {
        guard let assetName = rawName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !assetName.isEmpty else {
            return nil
        }
        let extensions = ["m4a", "mp3", "wav", "aac", "caf", "aiff"]
        // Bundled radio audio lives in the RadioAudio folder reference; fall back
        // to the bundle root for any loose resources.
        for ext in extensions {
            if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "RadioAudio") {
                return url
            }
            if let url = Bundle.main.url(forResource: assetName, withExtension: ext) {
                return url
            }
        }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let roots = [
            documents,
            documents.appendingPathComponent("Radio", isDirectory: true),
            documents.appendingPathComponent("RadioPacks", isDirectory: true)
        ]
        for root in roots {
            for ext in extensions {
                let url = root.appendingPathComponent(assetName).appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        return nil
    }

    private func playProceduralFallback(for station: RadioStation, track: RadioTrack?) {
        isPlayingTuningNoise = false
        attachPlayerIfNeeded()
        let buffer = makeStationBuffer(for: station)
        activeBuffer = buffer
        activeTrack = track
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.loops])
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                statusLine = "The station sparked but would not hold: \(error.localizedDescription)"
                appLog.error("Radio engine failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        player.volume = station.id == "thornwave" ? 0.38 : 0.32
        player.play()
        sourceLine = track.map { "Procedural fallback for \($0.title). Drop \($0.assetName ?? $0.id).m4a into Radio to replace it." }
            ?? "Procedural fallback broadcast."
        updateSystemNowPlayingSong(track, station: station, duration: nil)
    }

    private func makeFormat() -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    }

    private func makeStationBuffer(for station: RadioStation) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let duration = 10.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = makeFormat()
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        let recipe = recipe(for: station.id)
        var noiseSeed = UInt64(abs(station.id.stableHash) + 1)
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let slow = sin(2 * .pi * recipe.slowHz * t)
            let shimmer = sin(2 * .pi * recipe.shimmerHz * t + slow * 0.8)
            let pulse = sin(2 * .pi * recipe.pulseHz * t)
            noiseSeed = noiseSeed &* 6364136223846793005 &+ 1442695040888963407
            let rawNoise = Double(Int64(bitPattern: noiseSeed) % 10_000) / 10_000.0
            let noise = (rawNoise - 0.5) * recipe.staticAmount
            let base = sin(2 * .pi * recipe.baseHz * t + shimmer * 0.03)
            let overtone = sin(2 * .pi * recipe.overtoneHz * t + pulse * 0.05)
            let sample = Float((base * recipe.baseGain) + (overtone * recipe.overtoneGain) + noise)
            left[frame] = sample
            right[frame] = Float(Double(sample) * 0.86 + shimmer * recipe.shimmerGain)
        }
        return buffer
    }

    private func makeTuningNoiseBuffer(seedFrequency: Double) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let duration = 7.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = makeFormat()
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        var noiseSeed = UInt64(abs(Int(seedFrequency * 10_000))) + 97
        let driftHz = 0.07 + (seedFrequency.truncatingRemainder(dividingBy: 3) * 0.02)
        let whistleHz = 520.0 + seedFrequency * 3.0
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            noiseSeed = noiseSeed &* 2862933555777941757 &+ 3037000493
            let rawNoise = Double(noiseSeed & 0xffff) / Double(UInt16.max)
            let hiss = (rawNoise - 0.5) * 0.17
            let drift = sin(2 * .pi * driftHz * t)
            let whistle = sin(2 * .pi * (whistleHz + drift * 22) * t) * 0.018
            let flutter = sin(2 * .pi * 6.0 * t + drift) * 0.012
            let sample = Float(hiss + whistle + flutter)
            left[frame] = sample
            right[frame] = Float(Double(sample) * 0.78 - whistle * 0.35)
        }
        return buffer
    }

    private func staticSourceLine(for frequency: Double) -> String {
        let lines = [
            "Static, page-rustle, and a voice ducking behind the wallpaper.",
            "A narrow-band hiss with something tapping from the other side.",
            "Between stations: silver noise, bent bells, almost-words.",
            "The dial is catching weather instead of music."
        ]
        let index = abs(Int((frequency * 10).rounded())) % lines.count
        return lines[index]
    }

    private func recipe(for stationID: String) -> (baseHz: Double, overtoneHz: Double, shimmerHz: Double, slowHz: Double, pulseHz: Double, baseGain: Double, overtoneGain: Double, shimmerGain: Double, staticAmount: Double) {
        switch stationID {
        case "mothlight-beats":
            return (146.83, 220.0, 1.4, 0.05, 0.11, 0.055, 0.030, 0.010, 0.010)
        case "thornwave":
            return (73.42, 146.83, 2.2, 0.033, 0.07, 0.060, 0.026, 0.008, 0.040)
        default: // fae-fi: bright and playful
            return (130.81, 261.63, 1.8, 0.041, 0.09, 0.050, 0.028, 0.010, 0.018)
        }
    }
}
#else
@Observable
@MainActor
final class BookRadioManager {
    static let shared = BookRadioManager()
    private(set) var playback = RadioPlaybackState.off
    private(set) var activeStation: RadioStation?
    private(set) var activeTrack: RadioTrack?
    private(set) var isPlaying = false
    private(set) var isPlayingTuningNoise = false
    private(set) var statusLine = "Audio playback is unavailable on this platform."
    private(set) var sourceLine = "No broadcast is tuned."
    private(set) var nowPlayingBanter: RadioBanter?
    private var isPausedForMemoryPressure = false
    private var liveExperienceProgram: BookExperienceProgram?
    private init() {}
    func updateWorldState(grey: Int, festivalActive: Bool, pageContext: RadioPageContext = RadioPageContext()) {}
    func updateExperienceProgram(_ program: BookExperienceProgram?) {
        liveExperienceProgram = program
    }
    func restore(state: RadioPlaybackState, unlockedPackIDs: Set<String>) { playback = state }
    func tune(stationID: String, unlockedPackIDs: Set<String>) {
        activeStation = RadioStationRegistry.station(id: stationID, unlockedPackIDs: unlockedPackIDs)
        activeTrack = activeStation?.tracks.first
        isPlaying = true
        isPlayingTuningNoise = false
        isPausedForMemoryPressure = false
        playback = RadioPlaybackState(activeStationID: stationID, startedAt: Date(), lastTunedAt: Date(), lastTrackID: activeStation?.tracks.first?.id)
        PlayerVault.shared.data.radio = playback
        PlayerVault.shared.save()
    }
    func tuneDial(frequency: Double, unlockedPackIDs: Set<String>) {
        if let station = RadioStationRegistry.tunedStation(to: frequency, unlockedPackIDs: unlockedPackIDs) {
            tune(stationID: station.id, unlockedPackIDs: unlockedPackIDs)
        } else {
            playTuningNoise(frequency: frequency)
        }
    }
    func playTuningNoise(frequency: Double, persist: Bool = true) {
        isPlaying = true
        isPlayingTuningNoise = true
        isPausedForMemoryPressure = false
        activeStation = nil
        activeTrack = nil
        nowPlayingBanter = nil
        playback = RadioPlaybackState(activeStationID: nil, lastTunedAt: Date(), tuningNoise: 1)
        statusLine = String(format: "%.1f FM — static between stations.", frequency)
        sourceLine = "Between stations: silver noise, bent bells, almost-words."
        if persist {
            PlayerVault.shared.data.radio = playback
            PlayerVault.shared.save()
        }
    }
    func stop(persist: Bool = true) {
        playback = .off
        activeStation = nil
        activeTrack = nil
        nowPlayingBanter = nil
        isPlaying = false
        isPlayingTuningNoise = false
        isPausedForMemoryPressure = false
        if persist {
            PlayerVault.shared.data.radio = playback
            PlayerVault.shared.save()
        }
    }
    @discardableResult
    func pauseForMemoryPressureDuringGeneration() -> Bool {
        guard isPlaying else { return false }
        isPlaying = false
        isPausedForMemoryPressure = true
        statusLine = "Radio paused while the local brain frees memory."
        AppMemoryLedger.record("radio-paused-for-memory-pressure")
        return true
    }
    @discardableResult
    func resumeAfterMemoryPressureIfNeeded() -> Bool {
        guard isPausedForMemoryPressure else { return false }
        isPlaying = true
        isPausedForMemoryPressure = false
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — on air." } ?? "Radio static on air."
        AppMemoryLedger.record("radio-resumed-after-memory-pressure")
        return true
    }
    func hapticTick() {}
}
#endif

extension Notification.Name {
    static let localBrainDidWake = Notification.Name("localBrainDidWake")
    static let localBrainDidRest = Notification.Name("localBrainDidRest")
    static let localBrainWorkDidChange = Notification.Name("localBrainWorkDidChange")
    static let localBrainGenerationDidProgress = Notification.Name("localBrainGenerationDidProgress")
}

enum LocalBrainPresentation {
    case live
    case readingRoom
}

struct LocalBrainWorkSnapshot {
    var isWorking: Bool
    var label: String?
    var promptCharacters: Int
    var queuedCount: Int
}

struct LocalBrainGenerationProgressSnapshot {
    var label: String
    var text: String
    var generatedCharacters: Int
    var promptTokens: Int?
    var generatedTokens: Int?
    var tokensPerSecond: Double?
    var isFinal: Bool
}

/// View-facing progress lives outside `ContentView`'s large value-state graph.
/// Gemma can publish several snapshots per second; keeping the latest snapshot
/// in this small observable lets only the wet-ink card redraw instead of
/// invalidating every shelf on the home screen. The text is stored verbatim.
@Observable
final class LocalBrainProgressViewState {
    private(set) var snapshot: LocalBrainGenerationProgressSnapshot?

    var preview: String? {
        guard let text = snapshot?.text else { return nil }
        let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? nil : preview
    }

    var progressLine: String? {
        guard let snapshot else { return nil }
        var parts: [String] = []
        if let generatedTokens = snapshot.generatedTokens {
            parts.append("\(generatedTokens) tokens")
        } else if snapshot.generatedCharacters > 0 {
            parts.append("\(snapshot.generatedCharacters) chars")
        }
        if let tokensPerSecond = snapshot.tokensPerSecond {
            parts.append("\(String(format: "%.1f", tokensPerSecond)) tok/s")
        }
        if let promptTokens = snapshot.promptTokens {
            parts.append("\(promptTokens) prompt tokens")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func update(_ snapshot: LocalBrainGenerationProgressSnapshot) {
        self.snapshot = snapshot
    }

    func reset() {
        snapshot = nil
    }
}

/// Serializes the durable half of a keep away from the UI actor. The value
/// snapshots crossing this boundary are immutable copies; each operation gets
/// a fresh SwiftData context while the expensive container stays warm.
struct BookPersistenceWriteResult: @unchecked Sendable {
    let revision: UInt64
    let days: [BookDay]
    let storeReport: BookStore.Report
    let databaseReport: BookArchiveDatabase.Report
    let resurfacedPages: [BookPage]
    let returnedStackCards: [ReturnedStackCard]
    let usedFallbackStore: Bool
}

actor BookPersistenceWriter {
    static let shared = BookPersistenceWriter()

    private let database = BookDatabase.detachedDatabase()
    private var latestAcceptedRevision: UInt64 = 0

    func persist(
        revision: UInt64,
        day: BookDay,
        fallbackDays: [BookDay]
    ) throws -> BookPersistenceWriteResult? {
        // Calls originate in short-lived UI tasks. If a newer snapshot reaches
        // the actor first, never let an older full-archive write replace it.
        guard revision > latestAcceptedRevision else { return nil }
        latestAcceptedRevision = revision

        do {
            let databaseDays = try database.upsert(day, fallbackDays: fallbackDays)
            try BookStore.saveDays(databaseDays)
            return result(
                revision: revision,
                days: databaseDays,
                usedFallbackStore: false
            )
        } catch {
            // Keep the existing JSON fallback, but do its whole-archive encode
            // and atomic write here rather than stalling scrolling on MainActor.
            try BookStore.saveDays(fallbackDays)
            return result(
                revision: revision,
                days: fallbackDays,
                usedFallbackStore: true
            )
        }
    }

    /// Commits a migration/enrichment snapshot in one archive transaction.
    /// This avoids rewriting the whole JSON archive once per Page while still
    /// sharing the same monotonic revision gate as ordinary Keeps.
    func persistArchive(
        revision: UInt64,
        days: [BookDay]
    ) throws -> BookPersistenceWriteResult? {
        guard revision > latestAcceptedRevision else { return nil }
        latestAcceptedRevision = revision

        do {
            try database.saveDays(days)
            try BookStore.saveDays(days)
            return result(
                revision: revision,
                days: days,
                usedFallbackStore: false
            )
        } catch {
            try BookStore.saveDays(days)
            return result(
                revision: revision,
                days: days,
                usedFallbackStore: true
            )
        }
    }

    private func result(
        revision: UInt64,
        days: [BookDay],
        usedFallbackStore: Bool
    ) -> BookPersistenceWriteResult {
        let now = Date()
        return BookPersistenceWriteResult(
            revision: revision,
            days: days,
            storeReport: BookStore.report(for: days),
            databaseReport: database.report(for: days),
            resurfacedPages: (try? database.resurfacingCandidates(before: now, limit: 64)) ?? [],
            returnedStackCards: (try? database.returnedStacksCards(from: days, now: now, limit: 3)) ?? [],
            usedFallbackStore: usedFallbackStore
        )
    }
}

/// Gives an in-flight keep enough time to finish its atomic writes if the
/// reader backgrounds the app immediately after tapping Keep.
@MainActor
final class BookPersistenceBackgroundTask {
    #if canImport(UIKit)
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    #endif

    init() {
        #if canImport(UIKit)
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Keep Book page") { [weak self] in
            Task { @MainActor in self?.finish() }
        }
        #endif
    }

    func finish() {
        #if canImport(UIKit)
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
        #endif
    }
}

extension View {
    func keepsFocusedTextInputVisible() -> some View {
        modifier(FocusedTextInputVisibilityModifier())
    }
}

#if canImport(UIKit)
private weak var focusedTextInputCurrentResponder: UIResponder?

private struct FocusedTextInputVisibilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .background(KeyboardDismissInteractionInstaller())
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                UIApplication.shared.reenchantedEnableInteractiveKeyboardDismissal()
                adjustFocusedInput(for: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                UIApplication.shared.reenchantedEnableInteractiveKeyboardDismissal()
                adjustFocusedInput(for: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
                UIApplication.shared.reenchantedEnableInteractiveKeyboardDismissal()
                adjustFocusedInputSoon()
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidBeginEditingNotification)) { _ in
                UIApplication.shared.reenchantedEnableInteractiveKeyboardDismissal()
                adjustFocusedInputSoon()
            }
    }

    private func adjustFocusedInput(for notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            adjustFocusedInputSoon()
            return
        }

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let options = UIView.AnimationOptions(rawValue: curve << 16)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            UIView.reenchantedScrollFirstResponderIntoView(
                keyboardFrame: keyboardFrame,
                duration: duration,
                options: options
            )
        }
    }

    private func adjustFocusedInputSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UIView.reenchantedScrollFirstResponderIntoView(
                keyboardFrame: nil,
                duration: 0.22,
                options: [.curveEaseOut]
            )
        }
    }
}

private struct KeyboardDismissInteractionInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.install(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        func install(from view: UIView) {
            guard let window = view.window else { return }
            guard self.window !== window || recognizer == nil else {
                window.reenchantedEnableInteractiveKeyboardDismissal()
                return
            }

            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTapWindow(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.window = window
            self.recognizer = recognizer
            window.reenchantedEnableInteractiveKeyboardDismissal()
        }

        @objc private func didTapWindow(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            UIApplication.shared.reenchantedDismissKeyboard()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard UIResponder.reenchantedCurrentFirstResponder() is UIView else { return false }
            return touch.view?.reenchantedIsTextInputOrDescendant != true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIResponder {
    @objc func reenchantedCaptureFirstResponder() {
        focusedTextInputCurrentResponder = self
    }

    static func reenchantedCurrentFirstResponder() -> UIResponder? {
        focusedTextInputCurrentResponder = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.reenchantedCaptureFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        return focusedTextInputCurrentResponder
    }
}

private extension UIApplication {
    func reenchantedDismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func reenchantedEnableInteractiveKeyboardDismissal() {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.reenchantedEnableInteractiveKeyboardDismissal() }
    }
}

private extension UIView {
    static func reenchantedScrollFirstResponderIntoView(
        keyboardFrame: CGRect?,
        duration: TimeInterval,
        options: UIView.AnimationOptions
    ) {
        guard let responder = UIResponder.reenchantedCurrentFirstResponder() as? UIView,
              let window = responder.window,
              let scrollView = responder.reenchantedOuterScrollView else { return }

        let targetRect = scrollView
            .convert(responder.bounds, from: responder)
            .insetBy(dx: -8, dy: -14)
        var visibleRect = scrollView.bounds

        if let keyboardFrame {
            let keyboardInWindow = window.convert(keyboardFrame, from: nil)
            let keyboardInScrollView = scrollView.convert(keyboardInWindow, from: window)
            if keyboardInScrollView.minY < visibleRect.maxY {
                visibleRect.size.height = max(44, keyboardInScrollView.minY - visibleRect.minY - 18)
            }
        }

        guard !visibleRect.contains(targetRect) else { return }

        var offset = scrollView.contentOffset
        if targetRect.maxY > visibleRect.maxY {
            offset.y += targetRect.maxY - visibleRect.maxY
        }
        if targetRect.minY < visibleRect.minY {
            offset.y -= visibleRect.minY - targetRect.minY
        }

        let insets = scrollView.adjustedContentInset
        let minY = -insets.top
        let maxY = max(
            minY,
            scrollView.contentSize.height - visibleRect.height + insets.bottom
        )
        offset.y = min(max(offset.y, minY), maxY)

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    var reenchantedOuterScrollView: UIScrollView? {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            candidate = view.superview
        }
        return self as? UIScrollView
    }

    var reenchantedIsTextInputOrDescendant: Bool {
        var candidate: UIView? = self
        while let view = candidate {
            if view is UITextField || view is UITextView || view is UISearchBar {
                return true
            }
            candidate = view.superview
        }
        return false
    }

    func reenchantedEnableInteractiveKeyboardDismissal() {
        if let scrollView = self as? UIScrollView {
            scrollView.keyboardDismissMode = .interactive
        }
        subviews.forEach { $0.reenchantedEnableInteractiveKeyboardDismissal() }
    }
}
#else
private struct FocusedTextInputVisibilityModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}
#endif

enum AppMemoryLedger {
    static func record(_ checkpoint: String) {
        let resident = residentBytes()
        let available = availableBytes()
        let message = "Memory checkpoint \(checkpoint); resident: \(resident); available: \(available)"
        appLog.info("\(message, privacy: .public)")
        print(message)
    }

    /// How many bytes this process may still allocate before iOS terminates it.
    /// Unlike a memory warning, this is readable *before* the app is in
    /// trouble, so the local brain can decline work it cannot afford instead of
    /// being killed partway through a page.
    static func availableBytes() -> UInt64 {
        #if canImport(UIKit)
        let available = os_proc_available_memory()
        return available > 0 ? UInt64(available) : 0
        #else
        return 0
        #endif
    }

    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
}

enum BraidingQuips {
    static let lines = [
        "I'm checking the corners for meaning.",
        "A small clerk in the margins has found a useful comma.",
        "Sorting bright fragments from dramatic lint.",
        "The page is warming its hands before it speaks.",
        "Listening for the sentence that has been hiding in the day.",
        "A ribbon is being tied around the ordinary.",
        "The ink is asking one follow-up question very quietly.",
        "Cross-referencing tea stains, weather, and courage.",
        "I'm refusing to hurry the delicate bit.",
        "A little wonder has been located under the floorboards.",
        "The margins are arguing over the best adjective.",
        "Almost there. The sentence has put on its shoes."
    ]
}

enum HealthKitBodyReader {
    enum ReaderError: LocalizedError {
        case unavailable
        case missingTypes
        case deniedOrEmpty

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "HealthKit is not available on this device."
            case .missingTypes:
                return "This build could not prepare the requested HealthKit types."
            case .deniedOrEmpty:
                return "HealthKit did not return enough body signal yet."
            }
        }
    }

    static var isAvailable: Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    static func requestBodySignal() async throws -> BodySourceSignal {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw ReaderError.unavailable
        }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw ReaderError.missingTypes
        }

        let store = HKHealthStore()
        let optionalQuantityTypes: [HKQuantityType] = [
            .quantityType(forIdentifier: .heartRate),
            .quantityType(forIdentifier: .restingHeartRate),
            .quantityType(forIdentifier: .heartRateVariabilitySDNN),
            .quantityType(forIdentifier: .walkingHeartRateAverage),
            .quantityType(forIdentifier: .oxygenSaturation),
            .quantityType(forIdentifier: .respiratoryRate),
            .quantityType(forIdentifier: .bloodPressureSystolic),
            .quantityType(forIdentifier: .bloodPressureDiastolic),
            .quantityType(forIdentifier: .bloodGlucose),
            .quantityType(forIdentifier: .bodyMass),
            .quantityType(forIdentifier: .bodyMassIndex),
            .quantityType(forIdentifier: .dietaryEnergyConsumed),
            .quantityType(forIdentifier: .dietaryWater),
            .quantityType(forIdentifier: .dietaryProtein),
            .quantityType(forIdentifier: .dietaryCarbohydrates),
            .quantityType(forIdentifier: .dietaryFatTotal),
            .quantityType(forIdentifier: .dietaryFiber)
        ].compactMap(\.self)
        let readTypes = Set<HKObjectType>([stepType, distanceType, activeEnergyType, sleepType] + optionalQuantityTypes)
        try await store.requestAuthorization(toShare: [], read: readTypes)

        async let steps = optionalQuantitySum(for: stepType, unit: .count(), store: store, daysBack: 1)
        async let distance = optionalQuantitySum(for: distanceType, unit: .meter(), store: store, daysBack: 1)
        async let energy = optionalQuantitySum(for: activeEnergyType, unit: .kilocalorie(), store: store, daysBack: 1)
        async let sleep = optionalSleepHours(for: sleepType, store: store)
        async let richerMetrics = optionalDoctorMetrics(store: store)

        return translate(
            steps: await steps,
            distanceMeters: await distance,
            activeKilocalories: await energy,
            sleepHours: await sleep,
            metrics: await richerMetrics
        )
        #else
        throw ReaderError.unavailable
        #endif
    }

    #if canImport(HealthKit)
    private static func optionalQuantitySum(
        for type: HKQuantityType,
        unit: HKUnit,
        store: HKHealthStore,
        daysBack: Int
    ) async -> Double {
        (try? await quantitySum(for: type, unit: unit, store: store, daysBack: daysBack)) ?? 0
    }

    private static func quantitySum(
        for type: HKQuantityType,
        unit: HKUnit,
        store: HKHealthStore,
        daysBack: Int
    ) async throws -> Double {
        let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private static func optionalSleepHours(for type: HKCategoryType, store: HKHealthStore) async -> Double {
        (try? await sleepHours(for: type, store: store)) ?? 0
    }

    private static func optionalDoctorMetrics(store: HKHealthStore) async -> [BodySourceSignal.Metric] {
        await withTaskGroup(of: BodySourceSignal.Metric?.self) { group in
            func addLatest(_ identifier: HKQuantityTypeIdentifier, label: String, unit: HKUnit, displayUnit: String, decimals: Int = 0) {
                guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
                group.addTask {
                    await optionalLatestMetric(for: type, label: label, unit: unit, displayUnit: displayUnit, decimals: decimals, store: store)
                }
            }

            func addSum(_ identifier: HKQuantityTypeIdentifier, label: String, unit: HKUnit, displayUnit: String, daysBack: Int = 1, decimals: Int = 0) {
                guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
                group.addTask {
                    let value = await optionalQuantitySum(for: type, unit: unit, store: store, daysBack: daysBack)
                    guard value > 0 else { return nil }
                    return BodySourceSignal.Metric(
                        id: identifier.rawValue,
                        label: label,
                        value: formatted(value, decimals: decimals),
                        unit: displayUnit,
                        kind: "sum"
                    )
                }
            }

            addLatest(.heartRate, label: "Heart rate", unit: HKUnit.count().unitDivided(by: .minute()), displayUnit: "bpm")
            addLatest(.restingHeartRate, label: "Resting heart rate", unit: HKUnit.count().unitDivided(by: .minute()), displayUnit: "bpm")
            addLatest(.heartRateVariabilitySDNN, label: "HRV", unit: .secondUnit(with: .milli), displayUnit: "ms")
            addLatest(.walkingHeartRateAverage, label: "Walking heart rate", unit: HKUnit.count().unitDivided(by: .minute()), displayUnit: "bpm")
            addLatest(.oxygenSaturation, label: "Oxygen saturation", unit: .percent(), displayUnit: "%", decimals: 1)
            addLatest(.respiratoryRate, label: "Respiratory rate", unit: HKUnit.count().unitDivided(by: .minute()), displayUnit: "/min", decimals: 1)
            addLatest(.bloodPressureSystolic, label: "Blood pressure systolic", unit: .millimeterOfMercury(), displayUnit: "mmHg")
            addLatest(.bloodPressureDiastolic, label: "Blood pressure diastolic", unit: .millimeterOfMercury(), displayUnit: "mmHg")
            addLatest(.bloodGlucose, label: "Blood glucose", unit: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)), displayUnit: "mg/dL")
            addLatest(.bodyMass, label: "Body mass", unit: .pound(), displayUnit: "lb", decimals: 1)
            addLatest(.bodyMassIndex, label: "BMI", unit: .count(), displayUnit: "", decimals: 1)
            addSum(.dietaryEnergyConsumed, label: "Dietary energy", unit: .kilocalorie(), displayUnit: "kcal")
            addSum(.dietaryWater, label: "Water", unit: .literUnit(with: .milli), displayUnit: "mL")
            addSum(.dietaryProtein, label: "Protein", unit: .gram(), displayUnit: "g")
            addSum(.dietaryCarbohydrates, label: "Carbohydrates", unit: .gram(), displayUnit: "g")
            addSum(.dietaryFatTotal, label: "Fat", unit: .gram(), displayUnit: "g")
            addSum(.dietaryFiber, label: "Fiber", unit: .gram(), displayUnit: "g")
            var metrics: [BodySourceSignal.Metric] = []
            for await metric in group {
                if let metric {
                    metrics.append(metric)
                }
            }
            return metrics.sorted { $0.label < $1.label }
        }
    }

    private static func optionalLatestMetric(
        for type: HKQuantityType,
        label: String,
        unit: HKUnit,
        displayUnit: String,
        decimals: Int,
        store: HKHealthStore
    ) async -> BodySourceSignal.Metric? {
        guard let sample = try? await latestQuantitySample(for: type, store: store),
              sample.quantity.doubleValue(for: unit) > 0 else {
            return nil
        }
        return BodySourceSignal.Metric(
            id: type.identifier,
            label: label,
            value: formatted(sample.quantity.doubleValue(for: unit), decimals: decimals),
            unit: displayUnit,
            kind: "latest",
            observedAt: sample.endDate
        )
    }

    private static func latestQuantitySample(for type: HKQuantityType, store: HKHealthStore) async throws -> HKQuantitySample? {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample])?.first)
            }
            store.execute(query)
        }
    }

    private static func formatted(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private static func sleepHours(for type: HKCategoryType, store: HKHealthStore) async throws -> Double {
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 3600)
            }
            store.execute(query)
        }
    }
    #endif

    private static func translate(
        steps: Double,
        distanceMeters: Double,
        activeKilocalories: Double,
        sleepHours: Double,
        metrics: [BodySourceSignal.Metric]
    ) -> BodySourceSignal {
        let status: String
        let score: Int
        let phrase: String

        if sleepHours > 0, sleepHours < 5 {
            status = "WATCH"
            score = 30
            phrase = "I've softened the room today; the body asked for fewer sharp edges and a slower kind of courage."
        } else if steps < 900 && activeKilocalories < 120 {
            status = "LOW"
            score = 34
            phrase = "The lamps are low in the stacks. This looks like a day for small thresholds, warm fuel, and no heroic errands."
        } else if steps > 5_500 || distanceMeters > 3_500 {
            status = "BRIGHT"
            score = 76
            phrase = "There's motion in the margins. I can feel the day has had footsteps in it."
        } else {
            status = "STEADY"
            score = 58
            phrase = "The body page is steady enough for ordinary magic: a little movement, a little rest, and one honest page."
        }

        let baseMetrics: [BodySourceSignal.Metric] = [
            BodySourceSignal.Metric(id: "stepCount", label: "Steps", value: formatted(steps, decimals: 0), kind: "sum"),
            BodySourceSignal.Metric(id: "distanceWalkingRunning", label: "Distance", value: formatted(distanceMeters / 1_609.344, decimals: 2), unit: "mi", kind: "sum"),
            BodySourceSignal.Metric(id: "activeEnergyBurned", label: "Active energy", value: formatted(activeKilocalories, decimals: 0), unit: "kcal", kind: "sum"),
            BodySourceSignal.Metric(id: "sleepAnalysis", label: "Sleep", value: formatted(sleepHours, decimals: 1), unit: "h", kind: "category")
        ].filter { Double($0.value) ?? 0 > 0 }

        return BodySourceSignal(status: status, score: score, phrase: phrase, metrics: baseMetrics + metrics)
    }
}

enum WeatherLocationReader {
    enum ReaderError: LocalizedError {
        case unavailable
        case denied
        case noLocation
        case badResponse

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Location is not available in this build."
            case .denied:
                return "Location permission is needed to read local weather and nearby Anchors."
            case .noLocation:
                return "The device did not return a location yet."
            case .badResponse:
                return "Open-Meteo did not return a readable forecast."
            }
        }
    }

    static var isAvailable: Bool {
        #if canImport(CoreLocation)
        CLLocationManager.locationServicesEnabled()
        #else
        false
        #endif
    }

    static func requestWeatherSignal() async throws -> WeatherSourceSignal {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            throw ReaderError.unavailable
        }

        let location = try await OneShotLocationReader.requestLocation(
            desiredAccuracy: kCLLocationAccuracyThreeKilometers
        )
        return try await weatherSignal(for: location.coordinate)
        #else
        throw ReaderError.unavailable
        #endif
    }

    /// Reuses a coordinate already obtained for the shared real-world context
    /// pass, so weather, Anchors, and nearby-place scouting do not each wake GPS.
    static func weatherSignal(latitude: Double, longitude: Double) async throws -> WeatherSourceSignal {
        #if canImport(CoreLocation)
        return try await weatherSignal(for: CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        ))
        #else
        throw ReaderError.unavailable
        #endif
    }

    #if canImport(CoreLocation)
    fileprivate static func weatherSignal(for coordinate: CLLocationCoordinate2D) async throws -> WeatherSourceSignal {
        let weather = try await OpenMeteoClient.forecast(for: coordinate)
        let temperature = weather.currentTemperature
        let condition = WeatherCode.describe(weather.current.weatherCode)
        let forecast = weather.todayForecast.map { daily in
            "\(WeatherCode.describe(daily.weatherCode)), high \(daily.highTemperature), low \(daily.lowTemperature)"
        }
        let phrase = [
            "Current: \(condition), \(temperature)",
            forecast.map { "Forecast: \($0)" }
        ].compactMap(\.self).joined(separator: " | ")

        return WeatherSourceSignal(
            phrase: phrase,
            source: "Open-Meteo",
            currentTemperature: temperature,
            forecast: forecast,
            conditionSymbolName: WeatherCode.symbolName(weather.current.weatherCode)
        )
    }
    #endif
}

enum AnchorLocationReader {
    enum ReaderError: LocalizedError {
        case unavailable
        case denied
        case noLocation

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Location is not available in this build."
            case .denied:
                return "Location permission is needed to check nearby Anchors."
            case .noLocation:
                return "The device did not return a location yet."
            }
        }
    }

    static var isAvailable: Bool {
        #if canImport(CoreLocation)
        CLLocationManager.locationServicesEnabled()
        #else
        false
        #endif
    }

    static func requestLocation() async throws -> (latitude: Double, longitude: Double) {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            throw ReaderError.unavailable
        }
        let location = try await OneShotLocationReader.requestLocation(
            desiredAccuracy: kCLLocationAccuracyHundredMeters
        )
        return (location.coordinate.latitude, location.coordinate.longitude)
        #else
        throw ReaderError.unavailable
        #endif
    }
}

/// The small piece of live context a nightly braid needs. It deliberately
/// carries no coordinates into the page: GPS is used once to recognize a saved
/// place (such as Home), a nearby Anchor, or a coarse locality, and to fetch the
/// local sky.
struct NightlyBraidLiveContext: Equatable {
    var locationLabel: String
    var weather: WeatherSourceSignal?
    var latitude: Double
    var longitude: Double
    var anchorProximity: AnchorProximity?
}

enum NightlyBraidContextReader {
    static func request(anchors: [AnchorRecord]) async throws -> NightlyBraidLiveContext {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            throw AnchorLocationReader.ReaderError.unavailable
        }

        let location = try await OneShotLocationReader.requestLocation(
            desiredAccuracy: kCLLocationAccuracyHundredMeters
        )
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let knownPlace = CompassPlaceMemory.nearestKnownPlace(latitude: latitude, longitude: longitude)
        let anchorProximity = AnchorRegistry.nearestAnchor(
            to: latitude,
            longitude: longitude,
            anchors: anchors
        )

        async let weather = try? WeatherLocationReader.weatherSignal(for: location.coordinate)
        async let coarseLocality = coarseLocality(for: location)
        let resolvedWeather = await weather
        let resolvedLocality = await coarseLocality
        let locationLabel = knownPlace?.name.nonEmpty
            ?? anchorProximity?.anchor.name.nonEmpty
            ?? resolvedLocality
            ?? "Current place"

        return NightlyBraidLiveContext(
            locationLabel: locationLabel,
            weather: resolvedWeather,
            latitude: latitude,
            longitude: longitude,
            anchorProximity: anchorProximity
        )
        #else
        throw AnchorLocationReader.ReaderError.unavailable
        #endif
    }

    #if canImport(CoreLocation)
    private static func coarseLocality(for location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        if let locality = placemark.locality?.nonEmpty {
            return locality
        }
        return placemark.subLocality?.nonEmpty
            ?? placemark.administrativeArea?.nonEmpty
    }
    #endif
}

#if canImport(CoreLocation)
private enum OpenMeteoClient {
    struct Response: Decodable {
        var current: Current
        var daily: Daily?

        struct Current: Decodable {
            var temperature2m: Double
            var weatherCode: Int

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
            }
        }

        struct Daily: Decodable {
            var weatherCode: [Int]
            var temperature2mMax: [Double]
            var temperature2mMin: [Double]

            enum CodingKeys: String, CodingKey {
                case weatherCode = "weather_code"
                case temperature2mMax = "temperature_2m_max"
                case temperature2mMin = "temperature_2m_min"
            }
        }

        struct DailyForecast {
            var weatherCode: Int
            var highTemperature: String
            var lowTemperature: String
        }

        var currentTemperature: String {
            Self.temperatureFormatter.string(from: Measurement(value: current.temperature2m, unit: UnitTemperature.fahrenheit))
        }

        var todayForecast: DailyForecast? {
            guard let daily,
                  let code = daily.weatherCode.first,
                  let high = daily.temperature2mMax.first,
                  let low = daily.temperature2mMin.first else {
                return nil
            }
            return DailyForecast(
                weatherCode: code,
                highTemperature: Self.temperatureFormatter.string(from: Measurement(value: high, unit: UnitTemperature.fahrenheit)),
                lowTemperature: Self.temperatureFormatter.string(from: Measurement(value: low, unit: UnitTemperature.fahrenheit))
            )
        }

        private static let temperatureFormatter: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .providedUnit
            formatter.unitStyle = .short
            formatter.numberFormatter.maximumFractionDigits = 0
            return formatter
        }()
    }

    static func forecast(for coordinate: CLLocationCoordinate2D) async throws -> Response {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = components?.url else {
            throw WeatherLocationReader.ReaderError.badResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherLocationReader.ReaderError.badResponse
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private enum WeatherCode {
    static func describe(_ code: Int) -> String {
        switch code {
        case 0:
            return "clear sky"
        case 1:
            return "mostly clear"
        case 2:
            return "partly cloudy"
        case 3:
            return "overcast"
        case 45, 48:
            return "fog"
        case 51, 53, 55:
            return "drizzle"
        case 56, 57:
            return "freezing drizzle"
        case 61, 63, 65:
            return "rain"
        case 66, 67:
            return "freezing rain"
        case 71, 73, 75, 77:
            return "snow"
        case 80, 81, 82:
            return "rain showers"
        case 85, 86:
            return "snow showers"
        case 95, 96, 99:
            return "thunderstorm"
        default:
            return "changing weather"
        }
    }

    static func symbolName(_ code: Int) -> String {
        switch code {
        case 0, 1:
            return "sun.max"
        case 2:
            return "cloud.sun"
        case 3:
            return "cloud"
        case 45, 48:
            return "cloud.fog"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain"
        case 71, 73, 75, 77, 85, 86:
            return "snowflake"
        case 95, 96, 99:
            return "cloud.bolt.rain"
        default:
            return "cloud.sun"
        }
    }
}

@MainActor
private final class OneShotLocationReader: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    static func requestLocation(desiredAccuracy: CLLocationAccuracy) async throws -> CLLocation {
        let reader = OneShotLocationReader()
        reader.manager.desiredAccuracy = desiredAccuracy
        return try await reader.location()
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    private func location() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let status = manager.authorizationStatus
            switch status {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                if let cached = recentSystemLocation() {
                    finish(returning: cached)
                } else {
                    manager.requestLocation()
                }
            case .denied, .restricted:
                finish(throwing: WeatherLocationReader.ReaderError.denied)
            @unknown default:
                finish(throwing: WeatherLocationReader.ReaderError.noLocation)
            }
        }
    }

    /// Core Location often already has a recent fix from Maps, Weather, or an
    /// earlier Book request. Reusing that system-owned reading makes an
    /// intelligent refresh effectively free instead of waking GPS again.
    private func recentSystemLocation(now: Date = Date()) -> CLLocation? {
        guard let location = manager.location else { return nil }
        let age = now.timeIntervalSince(location.timestamp)
        let acceptableAccuracy = max(manager.desiredAccuracy * 2, 500)
        guard age >= 0,
              age <= 2 * 60,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= acceptableAccuracy else { return nil }
        return location
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                finish(throwing: WeatherLocationReader.ReaderError.denied)
            case .notDetermined:
                break
            @unknown default:
                finish(throwing: WeatherLocationReader.ReaderError.noLocation)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.last {
                finish(returning: location)
            } else {
                finish(throwing: WeatherLocationReader.ReaderError.noLocation)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finish(throwing: error)
        }
    }

    private func finish(returning location: CLLocation) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
#endif

extension Notification.Name {
    /// System memory pressure, abstracted so ContentView can observe it
    /// without platform conditionals in the view body.
    static var bookMemoryPressure: Notification.Name {
        #if canImport(UIKit)
        UIApplication.didReceiveMemoryWarningNotification
        #else
        Notification.Name("bookMemoryPressure")
        #endif
    }
}

#if canImport(UIKit)
/// Shared full-screen camera capture used by any page that can take a photo
/// instead of choosing one from the library. The system camera remains the
/// trustworthy capture surface; the Book owns the threshold around it so the
/// lens opens like an iris instead of arriving as an unrelated black screen.
struct BookCameraCaptureView: View {
    let onImageData: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var captureFlashOpacity = 0.0

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ZStack {
            BookSystemCameraController(
                onImageData: capture,
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()

            CameraIrisArrivalOverlay()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Color.white
                .opacity(captureFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func capture(_ data: Data) {
        guard !reduceMotion else {
            onImageData(data)
            dismiss()
            return
        }

        withAnimation(.easeOut(duration: 0.045)) {
            captureFlashOpacity = 0.88
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(85))
            withAnimation(.easeIn(duration: 0.10)) {
                captureFlashOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(95))
            onImageData(data)
            dismiss()
        }
    }
}

private struct BookSystemCameraController: UIViewControllerRepresentable {
    let onImageData: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageData: onImageData, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImageData: (Data) -> Void
        let onCancel: () -> Void

        init(onImageData: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onImageData = onImageData
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.86) else {
                onCancel()
                return
            }
            onImageData(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

/// A single threshold animation, not an always-on camera ornament. Six faint
/// aperture marks fold out while the live view is uncovered, then disappear so
/// nothing competes with the subject the reader is actually trying to see.
private struct CameraIrisArrivalOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openingProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let diagonal = hypot(proxy.size.width, proxy.size.height)

            ZStack {
                Color.black.opacity(0.98)

                Circle()
                    .frame(
                        width: diagonal * max(openingProgress, 0.002),
                        height: diagonal * max(openingProgress, 0.002)
                    )
                    .blendMode(.destinationOut)

                Circle()
                    .stroke(BookPalette.lampGold.opacity(0.68 * (1 - openingProgress)), lineWidth: 1.5)
                    .frame(
                        width: diagonal * max(openingProgress, 0.04),
                        height: diagonal * max(openingProgress, 0.04)
                    )

                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(BookPalette.paper.opacity(0.30 * (1 - openingProgress)))
                        .frame(width: 1, height: min(proxy.size.width, proxy.size.height) * 0.22)
                        .offset(y: -min(proxy.size.width, proxy.size.height) * (0.10 + openingProgress * 0.28))
                        .rotationEffect(.degrees(Double(index) * 60 + Double(openingProgress) * 24))
                }
            }
            .compositingGroup()
            .opacity(openingProgress >= 0.995 ? 0 : 1)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                openingProgress = 1
                return
            }
            Task { @MainActor in
                await Task.yield()
                withAnimation(.easeInOut(duration: 0.54)) {
                    openingProgress = 1
                }
            }
        }
    }
}
#endif

#if canImport(UserNotifications)
import UserNotifications
#endif

/// The one honest promise the paywall makes real: a local notification the day
/// before a free trial converts to a charge. Independent of the `BookWhispers`
/// channel (and its Colophon switch) so it fires even if in-world whispers are
/// off — a billing courtesy, not a story beat. Non-repeating; a fresh purchase
/// replaces any prior reminder.
enum StandingOrderTrialReminder {
    static let identifier = "standing-order-trial-reminder"

    enum AuthorizationState: Equatable, Sendable {
        case allowed
        case notDetermined
        case unavailable
    }

    static func authorizationState() async -> AuthorizationState {
        #if canImport(UserNotifications)
        let settings = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings {
                continuation.resume(returning: $0)
            }
        }
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .unavailable
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    @discardableResult
    static func schedule(
        trialEndsAt: Date,
        price: String,
        periodUnit: String,
        now: Date = Date(),
        requestAuthorizationIfNeeded: Bool = true
    ) async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        guard let plan = StandingOrderTrialReminderPlan.make(
            trialEndsAt: trialEndsAt,
            price: price,
            periodUnit: periodUnit,
            now: now
        ) else {
            cancel()
            return false
        }
        let authorization = await authorizationState()
        let allowed: Bool
        switch authorization {
        case .allowed:
            allowed = true
        case .notDetermined where requestAuthorizationIfNeeded:
            allowed = await requestAuthorization()
        case .notDetermined, .unavailable:
            allowed = false
        }
        guard allowed else { return false }

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.userInfo = [
            "kind": "standing-order-trial-reminder",
            "trialEndsAt": plan.trialEndsAt.timeIntervalSince1970
        ]

        let interval = max(1, plan.fireDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        return await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
        #else
        return false
        #endif
    }

    @discardableResult
    static func schedule(
        trialDays: Int,
        price: String,
        periodUnit: String,
        now: Date = Date()
    ) async -> Bool {
        let trialEndsAt = Calendar.current.date(
            byAdding: .day,
            value: trialDays,
            to: now
        ) ?? now
        return await schedule(
            trialEndsAt: trialEndsAt,
            price: price,
            periodUnit: periodUnit,
            now: now
        )
    }

    /// Prefer StoreKit's verified expiration to the catalog's day count. The
    /// fallback exists for the development counter and a just-finished purchase
    /// whose entitlement has not propagated into `currentEntitlements` yet.
    @discardableResult
    static func scheduleForPurchasedTrial(
        productID: String,
        fallbackTrialDays: Int,
        price: String,
        periodUnit: String,
        now: Date = Date()
    ) async -> Bool {
        #if canImport(StoreKit)
        let exactEnd = await currentTrial(productID: productID)?.endsAt
        #else
        let exactEnd: Date? = nil
        #endif
        let fallbackEnd = Calendar.current.date(
            byAdding: .day,
            value: fallbackTrialDays,
            to: now
        ) ?? now
        return await schedule(
            trialEndsAt: exactEnd ?? fallbackEnd,
            price: price,
            periodUnit: periodUnit,
            now: now
        )
    }

    /// Rebuilds the reminder from the verified active introductory transaction
    /// on launch. Once the trial has ended, the stale request is removed.
    static func reconcileCurrentTrial(now: Date = Date()) async {
        #if canImport(StoreKit)
        guard let trial = await currentTrial(productID: nil),
              trial.endsAt > now else {
            cancel()
            return
        }
        let tier = BookShopCatalog.standingOrderTiers.first {
            $0.productID == trial.productID
        }
        let product = try? await Product.products(for: [trial.productID]).first
        _ = await schedule(
            trialEndsAt: trial.endsAt,
            price: product?.displayPrice ?? tier?.fallbackDisplayPrice ?? "the confirmed price",
            periodUnit: tier?.periodUnit ?? "period",
            now: now,
            requestAuthorizationIfNeeded: false
        )
        #endif
    }

    static func cancel() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }

    #if canImport(UserNotifications)
    private static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
                granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
    #endif

    #if canImport(StoreKit)
    private struct CurrentTrial {
        var productID: String
        var endsAt: Date
    }

    private static func currentTrial(productID: String?) async -> CurrentTrial? {
        let standingOrderProductIDs = Set(BookShopCatalog.standingOrderTiers.map(\.productID))
        var latest: CurrentTrial?
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  standingOrderProductIDs.contains(transaction.productID),
                  productID == nil || transaction.productID == productID,
                  transaction.offerType == .introductory,
                  transaction.revocationDate == nil,
                  let expirationDate = transaction.expirationDate else {
                continue
            }
            if latest == nil || expirationDate > latest!.endsAt {
                latest = CurrentTrial(productID: transaction.productID, endsAt: expirationDate)
            }
        }
        return latest
    }
    #endif
}

/// The Book's voice outside the app: a few quiet, in-world local
/// notifications. One morning prompt, one evening return, and aging quests.
/// Everything is prefixed so a refresh can sweep ours without touching
/// anything else, and the whole channel has one switch in the Colophon.
enum BookWhispers {
    static let identifierPrefix = "book-whisper-"
    static let promptCategoryIdentifier = "book-whisper-prompt"
    static let promptReplyActionIdentifier = "prompt-keep-reply"
    static let outcomeCategoryIdentifier = "book-whisper-outcome"
    static let outcomeNothingActionIdentifier = "outcome-nothing"
    static let outcomeFlickerActionIdentifier = "outcome-flicker"
    static let outcomeRealActionIdentifier = "outcome-real"
    static let attentionCategoryIdentifier = "book-whisper-attention"
    static let attentionHereActionIdentifier = "attention-here"
    static let attentionElsewhereActionIdentifier = "attention-elsewhere"

    struct RefreshContext {
        var cadence: BookWhisperCadence
        var day: BookDay
        var inputs: BookSourceInputs
        var electives: [UnwrittenElective]
        var people: PeopleLedger
        var calendarEvents: [CalendarEventSignal]
        var whisperController: String?
        var whisperSovereign: Bool
        var eventWhisper: (title: String, body: String)?
        var festivalWhisper: (title: String, body: String)?
        var bookInterior: BookInteriorState
        var attentionProbes: AttentionProbeLedger

        init(
            cadence: BookWhisperCadence,
            day: BookDay,
            inputs: BookSourceInputs,
            electives: [UnwrittenElective],
            people: PeopleLedger = PeopleLedger(),
            calendarEvents: [CalendarEventSignal] = [],
            whisperController: String? = nil,
            whisperSovereign: Bool = false,
            eventWhisper: (title: String, body: String)? = nil,
            festivalWhisper: (title: String, body: String)? = nil,
            bookInterior: BookInteriorState = .unawakened,
            attentionProbes: AttentionProbeLedger = .empty
        ) {
            self.cadence = cadence
            self.day = day
            self.inputs = inputs
            self.electives = electives
            self.people = people
            self.calendarEvents = calendarEvents
            self.whisperController = whisperController
            self.whisperSovereign = whisperSovereign
            self.eventWhisper = eventWhisper
            self.festivalWhisper = festivalWhisper
            self.bookInterior = bookInterior
            self.attentionProbes = attentionProbes
        }
    }

    #if canImport(UserNotifications)
    private final class RefreshGeneration: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func advance() -> Int {
            lock.lock()
            defer { lock.unlock() }
            value &+= 1
            return value
        }

        func isCurrent(_ candidate: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return value == candidate
        }

        /// Keeps the final generation check and notification-center mutation
        /// in one critical section. A newer refresh cannot slip between them
        /// and leave a stale request behind.
        @discardableResult
        func performIfCurrent(_ candidate: Int, _ action: () -> Void) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard value == candidate else { return false }
            action()
            return true
        }

        /// Lets a late, fully eligible contextual hinge become the newest
        /// generation without invalidating an ordinary refresh when it cannot
        /// actually claim a seat.
        @discardableResult
        func supersedeIf(
            _ isEligible: () -> Bool,
            perform action: () -> Void
        ) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard isEligible() else { return false }
            value &+= 1
            action()
            return true
        }
    }

    private static let refreshGeneration = RefreshGeneration()

    private struct SeatReservation: Codable, Equatable {
        var candidateID: String
        var identifier: String
        var dayID: String
        var window: BookInterruptionWindow
        var kind: BookInterruptionKind
        var isSpecific: Bool
        var fireAt: Date
        var title: String
        var body: String
        var prompt: PromptWhisper?
        var outcome: DelayedOutcomePrompt? = nil
        var attentionProbeID: String? = nil
        var attentionCycle: Int? = nil

        var seatID: String { "\(dayID)|\(window.rawValue)" }
    }

    private static let reservationDefaultsKey = "bookWhisperSeatReservations.v1"
    private static let remindedFavorDefaultsKey = "bookWhisperRemindedFavorIDs.v1"

    private static func seatRequestIdentifier(
        dayID: String,
        window: BookInterruptionWindow
    ) -> String {
        "\(identifierPrefix)seat-\(dayID)-\(window.rawValue)"
    }

    private static func loadReservations() -> [SeatReservation] {
        guard let data = UserDefaults.standard.data(forKey: reservationDefaultsKey),
              let decoded = try? JSONDecoder().decode([SeatReservation].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func saveReservations(_ reservations: [SeatReservation], now: Date) {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let kept = reservations
            .filter { $0.fireAt >= cutoff }
            .sorted { ($0.fireAt, $0.identifier) < ($1.fireAt, $1.identifier) }
        guard let data = try? JSONEncoder().encode(kept) else { return }
        UserDefaults.standard.set(data, forKey: reservationDefaultsKey)
    }

    private static func remindedFavorIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: remindedFavorDefaultsKey) ?? [])
    }

    private static func recordRemindedFavorIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: remindedFavorDefaultsKey)
    }

    private static func interiorWhisper(
        for bookInterior: BookInteriorState
    ) -> (title: String, body: String)? {
        if let secret = bookInterior.secret, secret.status == .ready {
            return ("A sealed leaf shifted", "One of my own secrets is ready inside.")
        }
        if let promise = bookInterior.promise, promise.status == .keeping {
            return (
                "The ribbon kept its place",
                "There's an unfinished promise still on the shelf. Not tonight's problem."
            )
        }
        if let opinion = bookInterior.opinion,
           opinion.strength == .reconsidering,
           opinion.firstPresentedAt == nil {
            return (
                "An erasure in the margin",
                "I changed my mind and kept the reason beside the correction."
            )
        }
        if let game = bookInterior.longGame, game.phasePresentedAt == nil {
            return (
                "I've been trying something",
                "A quiet experiment has left a new note in the margins."
            )
        }
        if let fascination = bookInterior.fascination {
            return (
                "I'm still thinking",
                "A thread about \(fascination.facet.verb) is moving quietly in my margins."
            )
        }
        return nil
    }

    private static func promptContent(_ prompt: PromptWhisper) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = prompt.title
        content.body = prompt.body
        content.sound = .default
        content.categoryIdentifier = promptCategoryIdentifier
        content.userInfo = [
            "promptWhisperID": prompt.id,
            "keepPrompt": prompt.keepPrompt,
            "title": prompt.title,
            "body": prompt.body,
            "tags": prompt.tags.joined(separator: ","),
            "kind": prompt.kind.rawValue,
            "allowsPhoto": prompt.allowsPhoto ?? false
        ]
        return content
    }

    private static func notificationRequest(
        for reservation: SeatReservation,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content: UNMutableNotificationContent
        if reservation.kind == .attention {
            content = attentionContent(for: reservation)
        } else if let outcome = reservation.outcome {
            content = outcomeContent(outcome)
        } else if let prompt = reservation.prompt {
            content = promptContent(prompt)
        } else {
            content = UNMutableNotificationContent()
            content.title = reservation.title
            content.body = reservation.body
            content.sound = .default
        }
        content.userInfo["bookInterruptionSpecific"] = reservation.isSpecific
        content.userInfo["bookInterruptionKind"] = reservation.kind.rawValue
        content.userInfo["bookInterruptionDayID"] = reservation.dayID
        content.userInfo["bookInterruptionWindow"] = reservation.window.rawValue
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reservation.fireAt
        )
        return UNNotificationRequest(
            identifier: reservation.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private static func attentionContent(
        for reservation: SeatReservation
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "WHERE'S YOUR MIND?"
        content.body = "Quick. Where was your mind just before I knocked?"
        content.sound = .default
        content.categoryIdentifier = attentionCategoryIdentifier
        content.userInfo = [
            "attentionProbeID": reservation.attentionProbeID ?? reservation.candidateID,
            "attentionScheduledAt": reservation.fireAt.timeIntervalSince1970,
            "attentionCycle": reservation.attentionCycle ?? 0
        ]
        return content
    }

    private static func outcomeContent(_ prompt: DelayedOutcomePrompt) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = prompt.title
        content.body = prompt.body
        content.sound = .default
        content.categoryIdentifier = outcomeCategoryIdentifier
        if let data = try? JSONEncoder().encode(prompt) {
            content.userInfo["delayedOutcomePrompt"] = data.base64EncodedString()
        }
        return content
    }
    #endif

    /// Reconciles every ordinary Book interruption in one sweep. Test and
    /// billing notices use different identifiers and intentionally survive.
    /// Whether the Book has earned the right to ask for the notification
    /// permission yet.
    ///
    /// The reader is asked "when should I tap the glass?" during the First
    /// Door. Prompting before that means iOS's dialog arrives cold, before
    /// anybody has said they want to hear from the Book at all — and a "no"
    /// there is permanent and unaskable-again. So the system prompt waits for
    /// the reader to choose a cadence, and asks in the same breath.
    private static let whisperCadenceChosenKey = "bookWhispersCadenceChosen"

    /// Asks iOS only once the reader has chosen a cadence. Before that, an
    /// undetermined permission is reported as "not granted" so the sweep
    /// tidies up without a dialog ever appearing.
    private static func requestAuthorizationIfEarned(
        center: UNUserNotificationCenter,
        completion: @escaping (Bool) -> Void
    ) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            default:
                guard mayRequestNotificationAuthorization else {
                    completion(false)
                    return
                }
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            }
        }
    }

    static var mayRequestNotificationAuthorization: Bool {
        get { UserDefaults.standard.bool(forKey: whisperCadenceChosenKey) }
        set { UserDefaults.standard.set(newValue, forKey: whisperCadenceChosenKey) }
    }

    static func refreshAll(context: RefreshContext, now: Date = Date()) {
        #if canImport(UserNotifications)
        let generation = refreshGeneration.advance()
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            guard refreshGeneration.isCurrent(generation) else { return }
            let ordinary = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            let previous = loadReservations()
            let elapsed = previous.filter { $0.fireAt <= now }
            requestAuthorizationIfEarned(center: center) { granted in
                guard refreshGeneration.isCurrent(generation) else { return }
                guard granted else {
                    refreshGeneration.performIfCurrent(generation) {
                        center.removePendingNotificationRequests(withIdentifiers: ordinary)
                        saveReservations(elapsed, now: now)
                    }
                    return
                }
                let calendar = Calendar.current
                let start = BookDay.startDate(for: context.day.id, fallback: context.day.date, calendar: calendar)
                let ordinaryHorizonEnd = calendar.date(byAdding: .day, value: 3, to: start)
                    ?? start.addingTimeInterval(3 * 86_400)
                let attentionHorizonEnd = calendar.date(
                    byAdding: .day,
                    value: AttentionProbeSchedule.horizonDays + 1,
                    to: start
                ) ?? start.addingTimeInterval(
                    Double(AttentionProbeSchedule.horizonDays + 1) * 86_400
                )
                var candidates: [BookInterruptionCandidate] = []
                var reservations: [String: SeatReservation] = [:]

                func add(
                    id: String,
                    dayID: String,
                    window: BookInterruptionWindow,
                    kind: BookInterruptionKind,
                    isSpecific: Bool = false,
                    priority: Int = 0,
                    fireAt: Date,
                    title: String,
                    body: String,
                    prompt: PromptWhisper? = nil,
                    outcome: DelayedOutcomePrompt? = nil,
                    attentionProbeID: String? = nil,
                    attentionCycle: Int? = nil,
                    allowedUntil: Date? = nil
                ) {
                    guard fireAt > now,
                          fireAt < (allowedUntil ?? ordinaryHorizonEnd) else { return }
                    let candidate = BookInterruptionCandidate(
                        id: id,
                        dayID: dayID,
                        window: window,
                        kind: kind,
                        isSpecific: isSpecific,
                        priority: priority,
                        expiresAt: fireAt
                    )
                    candidates.append(candidate)
                    reservations[id] = SeatReservation(
                        candidateID: id,
                        identifier: seatRequestIdentifier(dayID: dayID, window: window),
                        dayID: dayID,
                        window: window,
                        kind: kind,
                        isSpecific: isSpecific,
                        fireAt: fireAt,
                        title: title,
                        body: body,
                        prompt: prompt,
                        outcome: outcome,
                        attentionProbeID: attentionProbeID,
                        attentionCycle: attentionCycle
                    )
                }

                let attention = context.attentionProbes.reconciled(now: now)
                for slot in AttentionProbeSchedule.slots(
                    ledger: attention,
                    startingAt: start,
                    now: now,
                    calendar: calendar
                ) {
                    let hour = calendar.component(.hour, from: slot.fireAt)
                    let sampleWindow: BookInterruptionWindow
                    switch context.cadence {
                    case .evening:
                        sampleWindow = .evening
                    case .both:
                        sampleWindow = hour < 16 ? .morning : .evening
                    case .inside, .morning:
                        sampleWindow = .morning
                    }
                    add(
                        id: slot.id,
                        dayID: slot.dayID,
                        window: sampleWindow,
                        kind: .attention,
                        isSpecific: true,
                        priority: 150,
                        fireAt: slot.fireAt,
                        title: "WHERE'S YOUR MIND?",
                        body: "Quick. Where was your mind just before I knocked?",
                        attentionProbeID: slot.id,
                        attentionCycle: slot.cycle,
                        allowedUntil: attentionHorizonEnd
                    )
                }

                for offset in 0..<3 {
                    guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                    let dayID = BookDay.id(for: date, calendar: calendar)
                    var morning = calendar.dateComponents([.year, .month, .day], from: date)
                    morning.hour = 11
                    morning.minute = 0
                    if let fire = calendar.date(from: morning) {
                        let promptDay = BookDay(
                            id: dayID,
                            date: calendar.startOfDay(for: date),
                            pages: offset == 0 ? context.day.pages : []
                        )
                        let ordinary = PromptWhisperRegistry.prompts(
                            for: promptDay,
                            inputs: context.inputs,
                            now: date,
                            count: 1
                        ).first
                        let sovereign = offset == 0 && context.whisperSovereign
                            ? PactVoices.sovereignWhisper(controller: context.whisperController)
                            : nil
                        let contextual = offset == 0
                            ? (context.eventWhisper ?? sovereign.map { ($0.title, $0.body) })
                            : nil
                        let prompt = contextual.map {
                            PromptWhisper(
                                id: "contextual-\(dayID)",
                                kind: .checkIn,
                                title: $0.0,
                                body: $0.1,
                                keepPrompt: $0.1,
                                tags: ["contextual-whisper"]
                            )
                        } ?? ordinary
                        if let prompt {
                            add(
                                id: contextual == nil ? "morning-\(dayID)" : "context-morning-\(dayID)",
                                dayID: dayID,
                                window: .morning,
                                kind: .ordinary,
                                isSpecific: contextual != nil,
                                priority: contextual == nil ? 0 : 80,
                                fireAt: fire,
                                title: prompt.title,
                                body: prompt.body,
                                prompt: prompt
                            )
                        }
                    }

                    let festival = offset == 0 ? context.festivalWhisper : nil
                    let interior = offset == 0 ? interiorWhisper(for: context.bookInterior) : nil
                    let braid = PactVoices.braidWhisper(controller: context.whisperController)
                    let eveningWhisper = festival
                        ?? interior
                        ?? (title: braid.title, body: braid.body)
                    var evening = calendar.dateComponents([.year, .month, .day], from: date)
                    evening.hour = festival == nil ? 20 : 18
                    evening.minute = festival == nil ? 45 : 0
                    if let fire = calendar.date(from: evening) {
                        add(
                            id: festival != nil
                                ? "festival-\(dayID)"
                                : interior != nil ? "interior-\(dayID)" : "evening-\(dayID)",
                            dayID: dayID,
                            window: .evening,
                            kind: festival != nil ? .festival : interior != nil ? .interior : .braid,
                            isSpecific: festival != nil || interior != nil,
                            priority: festival != nil ? 120 : interior != nil ? 70 : 0,
                            fireAt: fire,
                            title: eveningWhisper.title,
                            body: eveningWhisper.body
                        )
                    }
                }

                for weather in previous where weather.kind == .weather && weather.fireAt > now {
                    add(
                        id: weather.candidateID,
                        dayID: weather.dayID,
                        window: .morning,
                        kind: .weather,
                        isSpecific: true,
                        priority: 110,
                        fireAt: weather.fireAt,
                        title: weather.title,
                        body: weather.body,
                        prompt: weather.prompt
                    )
                }

                for outcome in previous where outcome.kind == .outcome && outcome.fireAt > now {
                    add(
                        id: outcome.candidateID,
                        dayID: outcome.dayID,
                        window: outcome.window,
                        kind: .outcome,
                        isSpecific: true,
                        priority: 95,
                        fireAt: outcome.fireAt,
                        title: outcome.title,
                        body: outcome.body,
                        outcome: outcome.outcome
                    )
                }

                for working in previous where working.kind == .working && working.fireAt > now {
                    add(
                        id: working.candidateID,
                        dayID: working.dayID,
                        window: working.window,
                        kind: .working,
                        isSpecific: true,
                        priority: 65,
                        fireAt: working.fireAt,
                        title: working.title,
                        body: working.body,
                        prompt: working.prompt
                    )
                }

                for charge in PeopleOfTheBook.preMeetingCharges(
                    ledger: context.people,
                    events: context.calendarEvents,
                    now: now
                ) {
                    let id = "person-\(charge.eventID)"
                    let dayID = BookDay.id(for: charge.fireAt, calendar: calendar)
                    let prompt = PromptWhisper(
                        id: id,
                        kind: .mission,
                        title: charge.title,
                        body: charge.body,
                        keepPrompt: charge.keepPrompt,
                        tags: charge.tags
                    )
                    add(
                        id: id,
                        dayID: dayID,
                        window: .morning,
                        kind: .person,
                        isSpecific: true,
                        priority: 115,
                        fireAt: charge.fireAt,
                        title: charge.title,
                        body: charge.body,
                        prompt: prompt
                    )
                }

                var reminded = remindedFavorIDs()
                for elective in context.electives where elective.isActive && !reminded.contains(elective.id) {
                    let due = elective.createdAt.addingTimeInterval(3 * 86_400)
                    guard due < ordinaryHorizonEnd else { continue }
                    let base = max(due, now)
                    var targetDay = calendar.startOfDay(for: base)
                    var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
                    components.hour = 19
                    components.minute = 30
                    var fire = calendar.date(from: components) ?? base
                    if fire <= now || fire < due {
                        targetDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
                        components = calendar.dateComponents([.year, .month, .day], from: targetDay)
                        components.hour = 19
                        components.minute = 30
                        fire = calendar.date(from: components) ?? targetDay
                    }
                    let title = elective.bookFavorID == nil
                        ? "A quest is waiting in the flyleaf"
                        : "An optional favor rests in the flyleaf"
                    let body = elective.bookFavorID == nil
                        ? "\(elective.characterName) is still hoping for “\(elective.title)”. Sentence, photo, or GPS proof completes it."
                        : "\(elective.title) is still there if you want it. I'm not going to nag."
                    add(
                        id: "favor-\(elective.id)",
                        dayID: BookDay.id(for: fire, calendar: calendar),
                        window: .evening,
                        kind: .favor,
                        isSpecific: true,
                        priority: 100,
                        fireAt: fire,
                        title: title,
                        body: body
                    )
                }

                let consumed = Set(elapsed.map(\.seatID))
                let winners = BookInterruptionBudget.plan(
                    candidates: candidates,
                    cadence: context.cadence,
                    consumed: consumed
                ).winners.compactMap { reservations[$0.id] }

                refreshGeneration.performIfCurrent(generation) {
                    center.removePendingNotificationRequests(withIdentifiers: ordinary)
                    for reservation in winners {
                        center.add(notificationRequest(for: reservation, calendar: calendar))
                        if reservation.kind == .favor,
                           reservation.candidateID.hasPrefix("favor-") {
                            reminded.insert(String(reservation.candidateID.dropFirst("favor-".count)))
                        }
                    }
                    recordRemindedFavorIDs(reminded)
                    saveReservations(elapsed + winners, now: now)
                }
            }
        }
        #endif
    }

    #if canImport(UserNotifications)
    /// A late weather hinge may take today's still-future generic morning seat.
    /// It never displaces another specific lived-world interruption and never
    /// reopens a seat whose scheduled fire time has already passed.
    static func offerWeather(_ whisper: PromptWhisper, now: Date = Date()) async -> Bool {
        let cadence = BookWhisperCadence.resolved(
            bookWhispersEnabled: UserDefaults.standard.bool(forKey: "bookWhispersEnabled"),
            promptWhispersEnabled: UserDefaults.standard.bool(forKey: "promptWhispersEnabled")
        )
        guard cadence.allowsMorning else { return false }

        let calendar = Calendar.current
        let dayID = BookDay.id(for: now, calendar: calendar)
        let seatID = "\(dayID)|\(BookInterruptionWindow.morning.rawValue)"
        let existing = loadReservations()
        guard !existing.contains(where: { $0.seatID == seatID && $0.fireAt <= now }),
              !existing.contains(where: {
                  $0.seatID == seatID && $0.fireAt > now && $0.isSpecific
              }) else {
            return false
        }

        let center = UNUserNotificationCenter.current()
        let granted: Bool = await withCheckedContinuation { continuation in
            requestAuthorizationIfEarned(center: center) { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return false }

        let pending: [UNNotificationRequest] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
        let specificPrefixes = [
            "\(identifierPrefix)person-",
            "\(identifierPrefix)person-charge-",
            "\(identifierPrefix)context-morning-",
            "\(identifierPrefix)weather-"
        ]
        let fixedMorningSeatIdentifier = seatRequestIdentifier(dayID: dayID, window: .morning)
        guard !pending.contains(where: { request in
            if request.identifier == fixedMorningSeatIdentifier {
                // A fixed-seat request without metadata is treated
                // conservatively: never overwrite a possibly specific hinge
                // when the local reservation ledger is missing or stale.
                return (request.content.userInfo["bookInterruptionSpecific"] as? Bool) ?? true
            }
            guard specificPrefixes.contains(where: request.identifier.hasPrefix) else { return false }
            let fireAt: Date?
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                fireAt = trigger.nextTriggerDate()
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                fireAt = now.addingTimeInterval(trigger.timeInterval)
            } else {
                fireAt = nil
            }
            guard let fireAt else { return false }
            return calendar.isDate(fireAt, inSameDayAs: now)
        }) else {
            return false
        }

        let fireAt = now.addingTimeInterval(60)
        let weatherCandidate = BookInterruptionCandidate(
            id: "weather-\(dayID)",
            dayID: dayID,
            window: .morning,
            kind: .weather,
            isSpecific: true,
            priority: 110,
            expiresAt: fireAt
        )
        let existingCandidates = existing.filter {
            $0.seatID == seatID && $0.fireAt > now
        }.map {
            BookInterruptionCandidate(
                id: $0.candidateID,
                dayID: $0.dayID,
                window: $0.window,
                kind: $0.kind,
                isSpecific: $0.isSpecific,
                priority: 0,
                expiresAt: $0.fireAt
            )
        }
        let consumed = Set(existing.filter { $0.fireAt <= now }.map(\.seatID))
        guard BookInterruptionBudget.plan(
            candidates: existingCandidates + [weatherCandidate],
            cadence: cadence,
            consumed: consumed
        ).winners.contains(where: { $0.id == weatherCandidate.id }) else {
            return false
        }

        let reservation = SeatReservation(
            candidateID: weatherCandidate.id,
            identifier: seatRequestIdentifier(dayID: dayID, window: .morning),
            dayID: dayID,
            window: .morning,
            kind: .weather,
            isSpecific: true,
            fireAt: fireAt,
            title: whisper.title,
            body: whisper.body,
            prompt: whisper
        )
        let weatherContent = promptContent(whisper)
        weatherContent.userInfo["bookInterruptionSpecific"] = true
        weatherContent.userInfo["bookInterruptionKind"] = BookInterruptionKind.weather.rawValue
        weatherContent.userInfo["bookInterruptionDayID"] = dayID
        weatherContent.userInfo["bookInterruptionWindow"] = BookInterruptionWindow.morning.rawValue
        let request = UNNotificationRequest(
            identifier: reservation.identifier,
            content: weatherContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )
        // Do not invalidate a full reconcile until Weather has passed every
        // eligibility check. The seat is re-read under the same lock used by
        // the ordinary scheduler.
        var updatedReservations: [SeatReservation] = []
        let committed = refreshGeneration.supersedeIf({
            let currentCadence = BookWhisperCadence.resolved(
                bookWhispersEnabled: UserDefaults.standard.bool(forKey: "bookWhispersEnabled"),
                promptWhispersEnabled: UserDefaults.standard.bool(forKey: "promptWhispersEnabled")
            )
            guard currentCadence.allowsMorning else { return false }
            let current = loadReservations()
            let currentConsumed = Set(current.filter { $0.fireAt <= now }.map(\.seatID))
            let currentCandidates = current.filter {
                $0.seatID == seatID && $0.fireAt > now && !$0.isSpecific
            }.map {
                BookInterruptionCandidate(
                    id: $0.candidateID,
                    dayID: $0.dayID,
                    window: $0.window,
                    kind: $0.kind,
                    isSpecific: false,
                    priority: 0,
                    expiresAt: $0.fireAt
                )
            }
            let winner = BookInterruptionBudget.plan(
                candidates: currentCandidates + [weatherCandidate],
                cadence: currentCadence,
                consumed: currentConsumed
            ).winners.first { $0.dayID == dayID && $0.window == .morning }
            guard winner?.id == weatherCandidate.id,
                  !current.contains(where: {
                      $0.seatID == seatID && $0.fireAt > now && $0.isSpecific
                  }) else {
                return false
            }

            updatedReservations = current.filter { $0.seatID != seatID }
            updatedReservations.append(reservation)
            return true
        }, perform: {
            center.add(request)
            saveReservations(updatedReservations, now: now)
        })
        return committed
    }

    /// Reserves one already-governed interruption seat for an attributable
    /// delayed outcome. It may replace a generic whisper, never another
    /// specific lived-world hinge, and never creates a third daily seat.
    static func offerDelayedOutcome(
        _ prompt: DelayedOutcomePrompt,
        earliest: Date,
        now: Date = Date()
    ) async -> Bool {
        let cadence = BookWhisperCadence.resolved(
            bookWhispersEnabled: UserDefaults.standard.bool(forKey: "bookWhispersEnabled"),
            promptWhispersEnabled: UserDefaults.standard.bool(forKey: "promptWhispersEnabled")
        )
        guard cadence != .inside else { return false }

        let calendar = Calendar.current
        let preferredWindow: BookInterruptionWindow = cadence.allowsEvening ? .evening : .morning
        let hour = preferredWindow == .evening ? 20 : 11
        let minute = preferredWindow == .evening ? 15 : 0
        var chosen: (dayID: String, fireAt: Date)?
        for offset in 0..<4 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else {
                continue
            }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let fireAt = calendar.date(from: components),
                  fireAt >= earliest,
                  fireAt > now else { continue }
            let dayID = BookDay.id(for: fireAt, calendar: calendar)
            let seatID = "\(dayID)|\(preferredWindow.rawValue)"
            let current = loadReservations()
            guard !current.contains(where: { $0.seatID == seatID && $0.fireAt <= now }),
                  !current.contains(where: {
                      $0.seatID == seatID && $0.fireAt > now && $0.isSpecific
                  }) else { continue }
            chosen = (dayID, fireAt)
            break
        }
        guard let chosen else { return false }

        let center = UNUserNotificationCenter.current()
        let granted: Bool = await withCheckedContinuation { continuation in
            requestAuthorizationIfEarned(center: center) { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return false }

        let candidate = BookInterruptionCandidate(
            id: prompt.id,
            dayID: chosen.dayID,
            window: preferredWindow,
            kind: .outcome,
            isSpecific: true,
            priority: 95,
            expiresAt: chosen.fireAt
        )
        let reservation = SeatReservation(
            candidateID: candidate.id,
            identifier: seatRequestIdentifier(dayID: chosen.dayID, window: preferredWindow),
            dayID: chosen.dayID,
            window: preferredWindow,
            kind: .outcome,
            isSpecific: true,
            fireAt: chosen.fireAt,
            title: prompt.title,
            body: prompt.body,
            prompt: nil,
            outcome: prompt
        )
        let request = notificationRequest(for: reservation, calendar: calendar)
        var updated: [SeatReservation] = []
        return refreshGeneration.supersedeIf({
            let currentCadence = BookWhisperCadence.resolved(
                bookWhispersEnabled: UserDefaults.standard.bool(forKey: "bookWhispersEnabled"),
                promptWhispersEnabled: UserDefaults.standard.bool(forKey: "promptWhispersEnabled")
            )
            let seatID = reservation.seatID
            let current = loadReservations()
            guard currentCadence != .inside,
                  !current.contains(where: { $0.seatID == seatID && $0.fireAt <= now }),
                  !current.contains(where: {
                      $0.seatID == seatID && $0.fireAt > now && $0.isSpecific
                  }) else {
                return false
            }
            updated = current.filter { $0.seatID != seatID }
            updated.append(reservation)
            return true
        }, perform: {
            center.add(request)
            saveReservations(updated, now: now)
        })
    }

    /// Gives one future Working an existing morning/evening seat. This can
    /// replace an ordinary braid or prompt, but never another contextual hinge;
    /// the Book therefore remains inside the same two-seat daily budget.
    static func offerWorking(_ working: BookWorking, now: Date = Date()) async -> Bool {
        let cadence = BookWhisperCadence.resolved(
            bookWhispersEnabled: UserDefaults.standard.bool(forKey: "bookWhispersEnabled"),
            promptWhispersEnabled: UserDefaults.standard.bool(forKey: "promptWhispersEnabled")
        )
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: working.startsAt)
        let window: BookInterruptionWindow = hour < 16 ? .morning : .evening
        guard working.startsAt > now,
              (window == .morning ? cadence.allowsMorning : cadence.allowsEvening) else {
            return false
        }

        let dayID = BookDay.id(for: working.startsAt, calendar: calendar)
        let seatID = "\(dayID)|\(window.rawValue)"
        let candidateID = "book-working-\(working.id)"
        if loadReservations().contains(where: {
            $0.candidateID == candidateID && $0.fireAt > now
        }) {
            return true
        }
        let center = UNUserNotificationCenter.current()
        let granted: Bool = await withCheckedContinuation { continuation in
            requestAuthorizationIfEarned(center: center) { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return false }

        let prompt = PromptWhisper(
            id: candidateID,
            kind: .mission,
            title: working.title,
            body: working.summons,
            keepPrompt: working.invitation,
            tags: ["book-working", "entity:\(working.initiatorID)"]
        )
        let candidate = BookInterruptionCandidate(
            id: prompt.id,
            dayID: dayID,
            window: window,
            kind: .working,
            isSpecific: true,
            priority: 65,
            expiresAt: working.startsAt
        )
        let reservation = SeatReservation(
            candidateID: candidate.id,
            identifier: seatRequestIdentifier(dayID: dayID, window: window),
            dayID: dayID,
            window: window,
            kind: .working,
            isSpecific: true,
            fireAt: working.startsAt,
            title: prompt.title,
            body: prompt.body,
            prompt: prompt
        )
        let request = notificationRequest(for: reservation, calendar: calendar)
        var updated: [SeatReservation] = []
        return refreshGeneration.supersedeIf({
            let currentCadence = BookWhisperCadence.resolved(
                bookWhispersEnabled: UserDefaults.standard.bool(forKey: "bookWhispersEnabled"),
                promptWhispersEnabled: UserDefaults.standard.bool(forKey: "promptWhispersEnabled")
            )
            let current = loadReservations()
            let currentConsumed = Set(current.filter { $0.fireAt <= now }.map(\.seatID))
            let currentCandidates = current.filter {
                $0.seatID == seatID && $0.fireAt > now
            }.map {
                BookInterruptionCandidate(
                    id: $0.candidateID,
                    dayID: $0.dayID,
                    window: $0.window,
                    kind: $0.kind,
                    isSpecific: $0.isSpecific,
                    priority: $0.isSpecific ? 140 : 0,
                    expiresAt: $0.fireAt
                )
            }
            guard BookInterruptionBudget.plan(
                candidates: currentCandidates + [candidate],
                cadence: currentCadence,
                consumed: currentConsumed
            ).winners.contains(where: { $0.id == candidate.id }) else {
                return false
            }
            updated = current.filter { $0.seatID != seatID }
            updated.append(reservation)
            return true
        }, perform: {
            center.add(request)
            saveReservations(updated, now: now)
        })
    }

    static func cancelWorking(_ working: BookWorking, now: Date = Date()) {
        let candidateID = "book-working-\(working.id)"
        var reservations = loadReservations()
        let matches = reservations.filter { $0.candidateID == candidateID }
        guard !matches.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: matches.map(\.identifier))
        reservations.removeAll { $0.candidateID == candidateID }
        saveReservations(reservations, now: now)
    }
    #endif

    static func refreshAnchorDoorbells(enabled: Bool, anchors: [AnchorRecord], now: Date = Date()) {
        #if canImport(UserNotifications) && canImport(CoreLocation)
        let center = UNUserNotificationCenter.current()
        let prefix = "book-whisper-doorbell-"
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            // Anchor arrivals are foreground/in-app under the current location
            // permission contract. Remove only legacy external doorbells.
        }
        #endif
    }

    #if canImport(UserNotifications)
    static func registerPromptCategory() {
        let reply = UNTextInputNotificationAction(
            identifier: promptReplyActionIdentifier,
            title: "Keep it",
            options: [],
            textInputButtonTitle: "Keep",
            textInputPlaceholder: "One sentence..."
        )
        let category = UNNotificationCategory(
            identifier: promptCategoryIdentifier,
            actions: [reply],
            intentIdentifiers: [],
            options: []
        )
        let outcomeCategory = UNNotificationCategory(
            identifier: outcomeCategoryIdentifier,
            actions: [
                UNNotificationAction(
                    identifier: outcomeRealActionIdentifier,
                    title: "A real moment",
                    options: []
                ),
                UNNotificationAction(
                    identifier: outcomeFlickerActionIdentifier,
                    title: "A flicker",
                    options: []
                ),
                UNNotificationAction(
                    identifier: outcomeNothingActionIdentifier,
                    title: "Nothing",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        let attentionCategory = UNNotificationCategory(
            identifier: attentionCategoryIdentifier,
            actions: [
                UNNotificationAction(
                    identifier: attentionHereActionIdentifier,
                    title: "HERE",
                    options: []
                ),
                UNNotificationAction(
                    identifier: attentionElsewhereActionIdentifier,
                    title: "ELSEWHERE",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
            var updated = categories.filter {
                $0.identifier != promptCategoryIdentifier
                    && $0.identifier != outcomeCategoryIdentifier
                    && $0.identifier != attentionCategoryIdentifier
            }
            updated.insert(category)
            updated.insert(outcomeCategory)
            updated.insert(attentionCategory)
            center.setNotificationCategories(updated)
        }
    }

    #endif
}

#if canImport(UserNotifications)
/// Lets the Book's whispers show as banners even while the app is in the
/// foreground (iOS suppresses them by default without this).
final class BookWhisperPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BookWhisperPresenter()
    @MainActor var onPromptReply: ((PromptWhisper, String) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == BookWhispers.attentionCategoryIdentifier {
            let answer: AttentionProbeAnswer?
            switch response.actionIdentifier {
            case BookWhispers.attentionHereActionIdentifier:
                answer = .here
            case BookWhispers.attentionElsewhereActionIdentifier:
                answer = .elsewhere
            default:
                answer = nil
            }
            guard let answer,
                  let sample = Self.attentionSample(
                    from: response.notification.request.content.userInfo
                  ) else {
                completionHandler()
                return
            }
            Task { @MainActor in
                let paused = Self.recordAttentionSampleHeadlessly(
                    id: sample.id,
                    scheduledAt: sample.scheduledAt,
                    cycle: sample.cycle,
                    answer: answer
                )
                if paused {
                    Self.cancelPendingAttentionSamples(center: center)
                }
                completionHandler()
            }
            return
        }

        if response.notification.request.content.categoryIdentifier == BookWhispers.outcomeCategoryIdentifier {
            guard let prompt = Self.delayedOutcomePrompt(
                from: response.notification.request.content.userInfo
            ) else {
                completionHandler()
                return
            }
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                if let url = URL(string: "reenchanted://question") {
                    _ = ReEnchantedWidgetDeepLinkStore.enqueue(url)
                }
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: .reEnchantedWidgetDeepLinkReceived,
                        object: nil
                    )
                    completionHandler()
                }
                return
            }
            let outcome: (score: Int, code: String, line: String)?
            switch response.actionIdentifier {
            case BookWhispers.outcomeNothingActionIdentifier:
                outcome = (0, "nothing", "Nothing came of it.")
            case BookWhispers.outcomeFlickerActionIdentifier:
                outcome = (5, "flicker", "There was a flicker.")
            case BookWhispers.outcomeRealActionIdentifier:
                outcome = (8, "real-moment", "It became a real moment.")
            default:
                outcome = nil
            }
            guard let outcome else {
                completionHandler()
                return
            }
            Task { @MainActor in
                Self.recordDelayedOutcomeHeadlessly(
                    prompt: prompt,
                    score: outcome.score,
                    code: outcome.code,
                    line: outcome.line
                )
                completionHandler()
            }
            return
        }

        guard response.notification.request.content.categoryIdentifier == BookWhispers.promptCategoryIdentifier,
              let whisper = Self.promptWhisper(from: response.notification.request.content.userInfo) else {
            completionHandler()
            return
        }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            _ = PromptWhisperOpenStore.enqueue(whisper)
            Task { @MainActor in
                NotificationCenter.default.post(name: .promptWhisperOpenReceived, object: nil)
            }
            completionHandler()
            return
        }

        guard response.actionIdentifier == BookWhispers.promptReplyActionIdentifier,
              let textResponse = response as? UNTextInputNotificationResponse else {
            completionHandler()
            return
        }

        let answer = textResponse.userText
        Task { @MainActor in
            if let onPromptReply {
                onPromptReply(whisper, answer)
                completionHandler()
                return
            }
            Self.keepPromptReplyHeadlessly(whisper: whisper, answer: answer)
            completionHandler()
        }
    }

    private static func attentionSample(
        from userInfo: [AnyHashable: Any]
    ) -> (id: String, scheduledAt: Date, cycle: Int)? {
        guard let id = userInfo["attentionProbeID"] as? String else { return nil }
        let scheduledInterval = (userInfo["attentionScheduledAt"] as? NSNumber)?.doubleValue
            ?? (userInfo["attentionScheduledAt"] as? Double)
            ?? Date().timeIntervalSince1970
        let cycle = (userInfo["attentionCycle"] as? NSNumber)?.intValue
            ?? (userInfo["attentionCycle"] as? Int)
            ?? 0
        return (id, Date(timeIntervalSince1970: scheduledInterval), cycle)
    }

    @MainActor
    @discardableResult
    private static func recordAttentionSampleHeadlessly(
        id: String,
        scheduledAt: Date,
        cycle: Int,
        answer: AttentionProbeAnswer
    ) -> Bool {
        let vault = PlayerVault.shared
        var ledger = vault.data.attentionProbes ?? .empty
        ledger.record(
            id: id,
            scheduledAt: scheduledAt,
            answeredAt: Date(),
            answer: answer,
            cycle: cycle
        )
        vault.data.attentionProbes = ledger
        vault.save()
        return ledger.pausedUntil != nil
    }

    private static func cancelPendingAttentionSamples(
        center: UNUserNotificationCenter
    ) {
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.compactMap { request in
                request.content.categoryIdentifier == BookWhispers.attentionCategoryIdentifier
                    ? request.identifier
                    : nil
            }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static func delayedOutcomePrompt(
        from userInfo: [AnyHashable: Any]
    ) -> DelayedOutcomePrompt? {
        guard let encoded = userInfo["delayedOutcomePrompt"] as? String,
              let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(DelayedOutcomePrompt.self, from: data)
    }

    @MainActor
    private static func recordDelayedOutcomeHeadlessly(
        prompt: DelayedOutcomePrompt,
        score: Int,
        code: String,
        line: String
    ) {
        let now = Date()
        let pulse = ReaderStatePulseRecord(
            id: "reader-state-pulse-\(prompt.id)",
            dimension: .delayedOutcome,
            score: score,
            answerCode: code,
            answerLine: line,
            note: nil,
            askedAt: prompt.askedAt,
            answeredAt: now,
            dayID: BookDay.id(for: now),
            context: nil,
            facets: ["notification-outcome"],
            target: prompt.target
        )
        let vault = PlayerVault.shared
        var pulses = vault.data.readerStatePulses ?? .empty
        pulses.record(pulse)
        vault.data.readerStatePulses = pulses
        var aliveness = vault.data.readerAliveness ?? .unwritten
        aliveness.ingest(pulse)
        vault.data.readerAliveness = aliveness
        vault.save()
    }

    private static func promptWhisper(from userInfo: [AnyHashable: Any]) -> PromptWhisper? {
        guard let id = userInfo["promptWhisperID"] as? String,
              let keepPrompt = userInfo["keepPrompt"] as? String,
              let title = userInfo["title"] as? String,
              let kindRaw = userInfo["kind"] as? String,
              let kind = PromptWhisper.Kind(rawValue: kindRaw) else {
            return nil
        }
        let body = userInfo["body"] as? String ?? keepPrompt
        let tagsRaw = userInfo["tags"] as? String ?? ""
        let tags = tagsRaw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let allowsPhoto = (userInfo["allowsPhoto"] as? NSNumber)?.boolValue
            ?? (userInfo["allowsPhoto"] as? Bool)
        return PromptWhisper(
            id: id,
            kind: kind,
            title: title,
            body: body,
            keepPrompt: keepPrompt,
            tags: tags,
            allowsPhoto: allowsPhoto
        )
    }

    @MainActor
    private static func keepPromptReplyHeadlessly(whisper: PromptWhisper, answer: String) {
        guard let page = PromptWhisperKeep.page(for: whisper, answer: answer, now: Date()) else { return }
        let legacyDays = BookStore.loadDays()
        let days = BookDatabase.loadDays(migratingFrom: legacyDays)
        let now = Date()
        let dayID = BookDay.id(for: now)
        var day = (try? BookDatabase.day(id: dayID)) ?? BookStore.today(from: days, now: now)
        day.pages.append(page)
        do {
            let databaseDays = try BookDatabase.upsert(day, fallbackDays: days)
            try? BookStore.saveDays(databaseDays)
            NotificationCenter.default.post(name: .promptWhisperKept, object: page)
        } catch {
            appLog.error("Prompt whisper keep failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif

extension BookWhispers {
    /// Install the foreground presenter once, at launch.
    static func configureForegroundPresentation() {
        #if canImport(UserNotifications)
        registerPromptCategory()
        UNUserNotificationCenter.current().delegate = BookWhisperPresenter.shared
        #endif
    }

    /// Fire a one-off whisper ~10 seconds out so the reader can confirm the
    /// whole notification pipeline end to end.
    static func sendTestWhisper() {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "A test whisper"
            content.body = "If you can read this, my voice reaches you. (It waited about ten seconds.)"
            content.sound = .default
            center.add(UNNotificationRequest(
                identifier: "book-test-whisper-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            ))
        }
        #endif
    }
}

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// The overnight interpretation forge: while the phone charges, the Book may
/// ask its local model to risk a correctable opinion or rare reframe from a
/// small packet of newly proven connections and exact shared-history lines.
enum OvernightScribe {
    static let taskIdentifier = "com.openclaw.enchantify.insidecover.overnight-scribe"
    static let freshnessWindow: TimeInterval = 18 * 3600

    private struct Draft: Codable {
        var generatedAt: Date
        var surface: SurfacePage
    }

    private struct ConnectionDrafts: Codable {
        var generatedAt: Date
        var drafts: [OvernightConnectionDraft]
    }

    private struct StrategyDraft: Codable {
        var generatedAt: Date
        var strategy: BookReenchantmentStrategy
    }

    static var draftURL: URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OvernightStoryPage.json")
    }

    static var connectionDraftsURL: URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OvernightConnections.json")
    }

    static var strategyDraftURL: URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OvernightReenchantmentStrategy.json")
    }

    static func register() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let task = task as? BGProcessingTask else { return }
            handle(task)
        }
        #endif
    }

    static func scheduleNext(now: Date = Date()) {
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        request.earliestBeginDate = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 2),
            matchingPolicy: .nextTime
        )
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            appLog.info("Overnight scribe could not be scheduled: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    #if canImport(BackgroundTasks)
    private static func handle(_ task: BGProcessingTask) {
        scheduleNext()
        let work = Task {
            let wrote = await writeDraft()
            AppMemoryLedger.record(wrote ? "overnight-scribe-wrote" : "overnight-scribe-skipped")
            task.setTaskCompleted(success: wrote)
        }
        task.expirationHandler = {
            work.cancel()
            AppMemoryLedger.record("overnight-scribe-expired")
            task.setTaskCompleted(success: false)
        }
    }
    #endif

    static func writeDraft(now: Date = Date()) async -> Bool {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        guard LocalModelManager.report().state == .ready else { return false }

        let prepared: (
            story: SurfacePage,
            connections: [OvernightConnectionCandidate],
            ingredients: [BookInterpretationIngredient],
            strategyPacket: ReenchantmentStrategyPacket?
        ) = await MainActor.run {
            let days = BookDatabase.loadDays(migratingFrom: BookStore.loadDays())
            let day = BookStore.today(from: days)
            let priorDays = days.filter { $0.id != day.id }
            let vault = PlayerVault.shared.data
            var inputs = BookSourceInputs.from(insideCover: InsideCoverStore.load())
            inputs.days = days
            inputs.selfFacts = (try? BookDatabase.selfFacts()) ?? []
            let events = (try? BookDatabase.narrativeEvents(limit: 160)) ?? []
            let memories = (try? BookDatabase.entityMemories(limit: 240)) ?? []
            inputs.entityBeliefOffsets = vault.entityBelief
            inputs.relationshipField = vault.relationshipField ?? [:]
            inputs.magicMoment = vault.magicMoment ?? MagicMomentState()
            inputs.bookObservations = vault.bookObservations ?? []
            inputs.bookReadingBoundaries = vault.bookReadingBoundaries ?? []
            inputs.readerLearning = vault.readerLearning ?? ReaderLearningModel()
            inputs.readerAliveness = vault.readerAliveness ?? .unwritten
            inputs.readerStatePulses = vault.readerStatePulses ?? .empty
            inputs.bookInterior = vault.bookInterior ?? BookInteriorState(awakenedAt: now)
            inputs.constellations = vault.constellations ?? []
            inputs.wagers = vault.wagers ?? []
            inputs.themes = vault.themes ?? []
            inputs.narrative = NarrativeSourceSnapshotBuilder.snapshot(
                from: events,
                memories: memories,
                beliefWeight: nil
            )
            inputs.overnightConnectionDrafts = vault.overnightConnectionDrafts ?? []
            inputs.chosenQuill = vault.chosenQuill
            let connections = OvernightConnectionReview.candidates(for: day, inputs: inputs, now: now)
            let packet = ReenchantmentStrategyPacketBuilder.make(inputs: inputs, now: now)
            let game = inputs.bookInterior.longGame
            let strategyPacket = NightGardenerReviewGate.shouldReview(
                packet: packet,
                activeStrategy: game?.activeStrategy,
                strategyHistory: game?.strategyHistory ?? [],
                now: now
            ) ? packet : nil
            return (
                NarrativeOSPageSourceAdapter.draftCandidate(for: day, inputs: inputs, now: now),
                connections,
                OvernightConnectionReview.ingredients(inputs: inputs),
                strategyPacket
            )
        }

        await LocalBrainInferenceGate.shared.setBackgroundAllowance(true)
        defer {
            Task { await LocalBrainInferenceGate.shared.setBackgroundAllowance(false) }
        }
        var wroteSomething = false
        do {
            let prose = try await MLXStoryPageWriter().write(surface: prepared.story)
            let story = prepared.story.preparedStoryPageCopy(
                prose: prose,
                slotID: SurfaceCadence.slotID(for: now, hours: 4)
            )
            let data = try JSONEncoder().encode(Draft(generatedAt: now, surface: story))
            try data.write(to: draftURL, options: [.atomic])
            wroteSomething = true
        } catch {
            appLog.error("Overnight scribe failed: \(error.localizedDescription, privacy: .public)")
        }

        if !prepared.connections.isEmpty,
           let packet = try? JSONEncoder().encode(prepared.connections),
           let candidateJSON = String(data: packet, encoding: .utf8),
           let ingredientPacket = try? JSONEncoder().encode(prepared.ingredients),
           let ingredientJSON = String(data: ingredientPacket, encoding: .utf8) {
            do {
                let response = try await MLXLocalTextGenerator.run(
                    prompt: """
                    CONNECTION CANDIDATES — frozen deterministic findings:
                    \(candidateJSON)

                    SHARED-HISTORY INGREDIENTS — exact lines and IDs:
                    \(ingredientJSON)

                    Return strict JSON with this exact shape:
                    {"connections":[{"candidateID":"exact supplied id","confidence":84,"headline":"short","interpretation":"one Book-voiced connection grounded in the evidence","question":"one curious question?","thesis":"a specific first-person Book opinion of 12-60 words that changes the angle","counterReading":"the strongest honest rival explanation in plain spoken language","falsifier":"If ... then I should revise this opinion.","whyItMatters":"why this could change how the reader sees an ordinary part of their life","surpriseHeadline":"optional short title","surpriseSynthesis":"optional 18-95 word Book-voiced reframe joining at least two supplied shared-history ingredients; deliver the insight, do not explain the machinery","surpriseWhyUnexpected":"why these exact pieces do not obviously belong together","surpriseIngredientIDs":["exact supplied ingredient id","another exact supplied ingredient id"],"surpriseConfidence":90}]}

                    Omit a candidate when you only have a paraphrase. A thesis must contain tension, stakes, or a changed angle—not merely say that a pattern exists. A surprise must make the ordinary life look different after reading it. Use exact supplied details. Never add an ID, event, motive, feeling, diagnosis, or biographical fact. Silence is better than a respectable observation.
                    """,
                    instructions: "You are the Book at its most perceptive. \(BookVoice.animismLine) Stay inside the supplied evidence. Write the connection with confidence; keep the counter-reading and erasure rule plain and short. Return strict JSON only.",
                    maxTokens: 1_180,
                    label: "overnight-interpretation-forge",
                    tags: ["overnight", "opinions", "surprise", "hidden-magic"],
                    temperature: 0.56,
                    topP: 0.88,
                    maxKVSize: 4_096,
                    presentation: .readingRoom,
                    publishesProgress: false
                )
                let drafts = OvernightConnectionReview.drafts(
                    from: response,
                    candidates: prepared.connections,
                    ingredients: prepared.ingredients,
                    now: now
                )
                if !drafts.isEmpty {
                    let data = try JSONEncoder().encode(ConnectionDrafts(generatedAt: now, drafts: drafts))
                    try data.write(to: connectionDraftsURL, options: [.atomic])
                    wroteSomething = true
                }
            } catch {
                appLog.error("Overnight connection review failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if let packet = prepared.strategyPacket {
            do {
                let naturalistText = try await MLXLocalTextGenerator.run(
                    prompt: NightGardenerPromptBuilder.naturalist(packet: packet),
                    instructions: "You are the Naturalist in the Book's Night Council. Stay inside the frozen evidence packet. Return strict JSON only. The object is lived aliveness outside the app, never engagement or a higher score.",
                    maxTokens: 980,
                    label: "night-gardener-naturalist",
                    tags: ["overnight", "night-gardener", "naturalist", "local-only"],
                    temperature: 0.52,
                    topP: 0.86,
                    maxKVSize: 4_096,
                    presentation: .readingRoom,
                    publishesProgress: false
                )
                guard let naturalist = NightGardenerJSON.decode(
                    NightGardenerNaturalistResponse.self,
                    from: naturalistText
                ), !naturalist.candidates.isEmpty else {
                    throw CocoaError(.coderReadCorrupt)
                }

                let hereticText = try await MLXLocalTextGenerator.run(
                    prompt: NightGardenerPromptBuilder.heretic(
                        packet: packet,
                        naturalist: naturalist
                    ),
                    instructions: "You are the Heretic in the Book's Night Council. Your loyalty is to the reader's real life and to disconfirming evidence, not to the Book's preferred story. Return strict JSON only.",
                    maxTokens: 900,
                    label: "night-gardener-heretic",
                    tags: ["overnight", "night-gardener", "heretic", "local-only"],
                    temperature: 0.38,
                    topP: 0.82,
                    maxKVSize: 4_096,
                    presentation: .readingRoom,
                    publishesProgress: false
                )
                guard let heretic = NightGardenerJSON.decode(
                    NightGardenerHereticResponse.self,
                    from: hereticText
                ), !heretic.assessments.isEmpty else {
                    throw CocoaError(.coderReadCorrupt)
                }

                let gardenerText = try await MLXLocalTextGenerator.run(
                    prompt: NightGardenerPromptBuilder.gardener(
                        packet: packet,
                        naturalist: naturalist,
                        heretic: heretic
                    ),
                    instructions: "You are the Gardener in the Book's Night Council. Propose one small falsifiable experiment or remain silent. You cannot authorize action. Return strict JSON only.",
                    maxTokens: 640,
                    label: "night-gardener-gardener",
                    tags: ["overnight", "night-gardener", "gardener", "local-only"],
                    temperature: 0.48,
                    topP: 0.84,
                    maxKVSize: 4_096,
                    presentation: .readingRoom,
                    publishesProgress: false
                )
                guard let gardener = NightGardenerJSON.decode(
                    NightGardenerProposal.self,
                    from: gardenerText
                ) else {
                    throw CocoaError(.coderReadCorrupt)
                }

                switch BookReenchantmentStrategyValidator.validate(
                    packet: packet,
                    naturalist: naturalist,
                    heretic: heretic,
                    gardener: gardener,
                    aliveness: await MainActor.run {
                        PlayerVault.shared.data.readerAliveness ?? .unwritten
                    },
                    now: now
                ) {
                case .success(let strategy):
                    let data = try JSONEncoder().encode(
                        StrategyDraft(generatedAt: now, strategy: strategy)
                    )
                    try data.write(to: strategyDraftURL, options: [.atomic])
                    wroteSomething = true
                case .failure(let error):
                    appLog.info(
                        "Night Gardener produced no admissible strategy: \(error.rawValue, privacy: .public)"
                    )
                }
            } catch {
                appLog.error("Night Gardener failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return wroteSomething
        #else
        return false
        #endif
    }

    /// Returns the overnight draft if it is still fresh. The file is
    /// consumed either way so a stale draft never lingers.
    static func adoptDraft(now: Date = Date()) -> SurfacePage? {
        guard let data = try? Data(contentsOf: draftURL) else { return nil }
        try? FileManager.default.removeItem(at: draftURL)
        let decoder = JSONDecoder()
        guard let draft = try? decoder.decode(Draft.self, from: data),
              now.timeIntervalSince(draft.generatedAt) < freshnessWindow else {
            return nil
        }
        return draft.surface
    }

    /// Adopts the interpretation forge's grounded connection drafts. The file is
    /// consumed even when stale so yesterday's surprise cannot masquerade as
    /// a fresh noticing after its evidence has moved on.
    static func adoptConnectionDrafts(now: Date = Date()) -> [OvernightConnectionDraft] {
        guard let data = try? Data(contentsOf: connectionDraftsURL) else { return [] }
        try? FileManager.default.removeItem(at: connectionDraftsURL)
        guard let bundle = try? JSONDecoder().decode(ConnectionDrafts.self, from: data),
              now.timeIntervalSince(bundle.generatedAt) < freshnessWindow else { return [] }
        return bundle.drafts
    }

    /// Returns one already-validated, still-fresh strategy proposal. Adoption
    /// compares its evidence signature with a freshly rebuilt Observatory
    /// packet before it can enter the Long Game.
    static func adoptStrategyDraft(now: Date = Date()) -> BookReenchantmentStrategy? {
        guard let data = try? Data(contentsOf: strategyDraftURL) else { return nil }
        try? FileManager.default.removeItem(at: strategyDraftURL)
        guard let draft = try? JSONDecoder().decode(StrategyDraft.self, from: data),
              now.timeIntervalSince(draft.generatedAt) < freshnessWindow,
              draft.strategy.expiresAt > now else { return nil }
        return draft.strategy
    }
}

enum WeatherBell {
    static let taskIdentifier = "com.openclaw.enchantify.insidecover.weather-bell"

    static func register() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handle(task)
        }
        #endif
    }

    static func scheduleNext(now: Date = Date()) {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = now.addingTimeInterval(2.5 * 3600)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    #if canImport(BackgroundTasks)
    private static func handle(_ task: BGAppRefreshTask) {
        scheduleNext()
        let work = Task {
            _ = await refresh()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
    #endif

    static func refresh(now: Date = Date()) async -> Bool? {
        guard UserDefaults.standard.bool(forKey: "promptWhispersEnabled") else { return false }
        if let last = UserDefaults.standard.object(forKey: "weatherBellLastFired") as? Date,
           Calendar.current.isDate(last, inSameDayAs: now) { return false }
        do {
            let signal = try await withThrowingTaskGroup(of: WeatherSourceSignal.self) { group in
                group.addTask { try await WeatherLocationReader.requestWeatherSignal() }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw CancellationError()
                }
                let value = try await group.next()!
                group.cancelAll()
                return value
            }
            let text = [signal.phrase, signal.forecast].compactMap { $0 }.joined(separator: " ")
            guard let mission = PlayfulMissionRegistry.weatherBellMission(weatherText: text) else { return false }
            #if canImport(UserNotifications)
            let whisper = PromptWhisperRegistry.promptWhisper(from: mission)
            guard await BookWhispers.offerWeather(whisper, now: now) else { return false }
            #else
            return false
            #endif
            UserDefaults.standard.set(now, forKey: "weatherBellLastFired")
            return true
        } catch {
            return nil
        }
    }
}

/// All transient "I'm writing" state, extracted from ContentView:
/// prepared surfaces, in-flight flags, and retry/recovery bookkeeping for
/// every generated page family. Observable, so only views that read a given
/// property re-evaluate when it changes.
@Observable
final class GenerationCoordinator {
    var isBraiding = false
    var braidingStartedAt: Date?
    var lastBraidDuration: TimeInterval?
    var braidRecovery = BraidRecoveryState()
    var didAutoBraidTodayID: String?
    var automaticIlluminatedSurface: SurfacePage?
    var isPreparingAutomaticIllumination = false
    var preparedStoryPageSurface: SurfacePage?
    var isPreparingStoryPage = false
    var storyPageRecovery = PreparedPageRecoveryState()
    var preparedGossipPageSurface: SurfacePage?
    var isPreparingGossipPage = false
    var gossipPageRecovery = PreparedPageRecoveryState()
    var preparedFacultyResearchSurface: SurfacePage?
    var isPreparingFacultyResearchPage = false
    var facultyResearchRecovery = PreparedPageRecoveryState()
    var preparedLetterSurface: SurfacePage?
    var isPreparingLetterPage = false
    var letterPageRecovery = PreparedPageRecoveryState()
    var preparedBleedEditionSurface: SurfacePage?
    var isPreparingBleedEdition = false
    var bleedEditionRecovery = PreparedPageRecoveryState()
}

/// A tiny, bounded diagnostic/recovery copy of the last visible desk. Launch
/// curation never publishes this snapshot as interactive UI: the first cards a
/// reader can touch must come from the current session's curator.
enum LaunchDeskSnapshotStore {
    private static let defaultsKey = "launchDeskSnapshotV1"
    private static let maximumSurfaceBytes = 256 * 1_024
    private static let maximumSnapshotBytes = 640 * 1_024

    private struct Snapshot: Codable {
        var version: Int
        var dayID: String
        var savedAt: Date
        var surfaces: [SurfacePage]
    }

    /// Only same-day, bounded snapshots are eligible. A generated page can
    /// carry large embedded metadata; excluding an oversized card keeps this
    /// launch shortcut from quietly becoming another expensive archive.
    static func load(dayID: String, now: Date = Date()) -> [SurfacePage] {
        guard let data = InsideCoverStore.defaults.data(forKey: defaultsKey),
              data.count <= maximumSnapshotBytes,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.version == 1,
              snapshot.dayID == dayID,
              now.timeIntervalSince(snapshot.savedAt) < 24 * 60 * 60 else {
            return []
        }
        return Array(snapshot.surfaces.prefix(3))
    }

    static func save(_ surfaces: [SurfacePage], dayID: String, now: Date = Date()) {
        let encoder = JSONEncoder()
        let bounded = surfaces.prefix(3).filter { surface in
            guard let data = try? encoder.encode(surface) else { return false }
            return data.count <= maximumSurfaceBytes
        }
        let snapshot = Snapshot(
            version: 1,
            dayID: dayID,
            savedAt: now,
            surfaces: Array(bounded)
        )
        guard let data = try? encoder.encode(snapshot),
              data.count <= maximumSnapshotBytes else { return }
        InsideCoverStore.defaults.set(data, forKey: defaultsKey)
    }
}

/// Owns PlayerVaultData on disk. Replaces five separate JSON-in-AppStorage
/// ledgers; migrates them once on first launch and then becomes the only
/// writer. Observable, so views tracking vault-backed values stay live.
@Observable
final class PlayerVault {
    static let shared = PlayerVault()

    var data: PlayerVaultData
    @ObservationIgnored private let persistenceQueue = DispatchQueue(
        label: "com.openclaw.reenchanted.player-vault",
        qos: .utility
    )
    @ObservationIgnored private let persistenceLock = NSLock()
    @ObservationIgnored private var persistenceRevision: UInt64 = 0

    private static var fileURL: URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PlayerVault.json")
    }

    private init() {
        if let bytes = try? Data(contentsOf: Self.fileURL),
           var decoded = try? JSONDecoder().decode(PlayerVaultData.self, from: bytes) {
            // One-time seed: first-run steps used to advance on served-history
            // alone. Anyone already served a step under that rule counts as
            // engaged, so onboarding never replays for existing readers.
            if decoded.firstRunEngaged == nil {
                // A launch desk is curated underneath the First Door. If the app
                // was interrupted mid-onboarding, its hidden Welcome may already
                // be in served history even though the reader never saw it. Only
                // use the legacy served-history migration for Books whose story
                // onboarding was already complete; an in-progress First Door
                // starts an explicit empty engagement ledger instead.
                if UserDefaults.standard.bool(forKey: "didCompleteStoryOnboarding") {
                    decoded.firstRunEngaged = FirstRunPageSequence.seededEngagementKeys(
                        fromServedHistory: decoded.surfaceHistory ?? [:]
                    )
                } else {
                    decoded.firstRunEngaged = []
                }
            }
            data = decoded
            return
        }
        data = Self.migrateFromLegacyLedgers()
        persistImmediately(data)
    }

    /// Applies several field changes as a single observable mutation.
    ///
    /// `data` is one observable property, so *any* assignment through it —
    /// `vault.data.readerLearning = …` — invalidates every view that reads any
    /// part of the vault. A run of consecutive field writes therefore rebuilt
    /// the whole desk once per field. Compute the new values first, then apply
    /// them here in one pass.
    ///
    /// Do not nest calls, and do not read `vault.data` inside the closure
    /// expecting to see the changes being made: the draft is only published
    /// when the closure returns.
    func mutate(_ change: (inout PlayerVaultData) -> Void) {
        var draft = data
        change(&draft)
        data = draft
    }

    func save() {
        // The observable in-memory value is authoritative during the session.
        // JSON encoding plus an atomic file replacement used to run inline on
        // every tap/keep/economy tick, producing visible interaction hitches.
        // Coalesce bursts and serialize the durable writes on a utility queue.
        let snapshot = data
        let url = Self.fileURL
        persistenceLock.lock()
        persistenceRevision &+= 1
        let revision = persistenceRevision
        persistenceLock.unlock()

        persistenceQueue.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            self.persistenceLock.lock()
            let isLatest = revision == self.persistenceRevision
            self.persistenceLock.unlock()
            guard isLatest else { return }
            guard let bytes = try? JSONEncoder().encode(snapshot) else { return }
            try? bytes.write(to: url, options: [.atomic])
        }
    }

    private func persistImmediately(_ snapshot: PlayerVaultData) {
        guard let bytes = try? JSONEncoder().encode(snapshot) else { return }
        try? bytes.write(to: Self.fileURL, options: [.atomic])
    }

    /// One-time migration from the old per-ledger AppStorage keys. The old
    /// keys are left in place (never written again) as a safety copy.
    private static func migrateFromLegacyLedgers() -> PlayerVaultData {
        let defaults = UserDefaults.standard
        var migrated = PlayerVaultData()
        let decoder = JSONDecoder()
        if let raw = defaults.string(forKey: "anchorLedgerV1")?.data(using: .utf8),
           let anchors = try? decoder.decode([AnchorRecord].self, from: raw) {
            migrated.anchors = anchors.filter { !AnchorRegistry.retiredAnchorIDs.contains($0.id) }
        }
        if let raw = defaults.string(forKey: "unwrittenElectivesV1")?.data(using: .utf8),
           let electives = try? decoder.decode([UnwrittenElective].self, from: raw) {
            migrated.electives = electives
        }
        if let raw = defaults.string(forKey: "entityBeliefLedger")?.data(using: .utf8),
           let ledger = try? decoder.decode([String: Int].self, from: raw) {
            migrated.entityBelief = ledger
        }
        if let raw = defaults.string(forKey: "pageBeliefLedger")?.data(using: .utf8),
           let ledger = try? decoder.decode([String: Int].self, from: raw) {
            migrated.pageBelief = ledger
        }
        if let raw = defaults.string(forKey: "marginTutorSeenV1")?.data(using: .utf8),
           let seen = try? decoder.decode([String].self, from: raw) {
            migrated.tutorSeen = seen
        }
        // A newly created vault must never look eligible for the legacy
        // served-history migration on its second launch.
        migrated.firstRunEngaged = []
        return migrated
    }
}


#if canImport(EventKit)
import EventKit
#endif

/// The Calendar Doorway: reads today's and tomorrow's real events so the
/// curator can feel the day's hinges. Nothing leaves the device.
enum CalendarDoorway {
    enum AccessState: Equatable {
        case unavailable
        case notDetermined
        case authorized
        case denied
    }

    static var isAvailable: Bool {
        #if canImport(EventKit)
        return true
        #else
        return false
        #endif
    }

    static var accessState: AccessState {
        #if canImport(EventKit)
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .authorized, .fullAccess:
            return .authorized
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
        #else
        return .unavailable
        #endif
    }

    static func upcomingEvents(
        now: Date = Date(),
        horizonDays: Int = 2
    ) async -> [CalendarEventSignal] {
        #if canImport(EventKit)
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        guard granted else { return [] }
        let calendar = Calendar.current
        let start = now.addingTimeInterval(-3600)
        let days = max(1, min(7, horizonDays))
        let end = calendar.date(byAdding: .day, value: days, to: now)
            ?? now.addingTimeInterval(TimeInterval(days) * 86_400)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay || calendar.isDate($0.startDate, inSameDayAs: now) }
            .prefix(days > 2 ? 64 : 24)
            .map { event in
                CalendarEventSignal(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "an unnamed appointment",
                    startsAt: event.startDate,
                    endsAt: event.endDate,
                    isAllDay: event.isAllDay
                )
            }
        #else
        return []
        #endif
    }
}

/// Writes the world back out into the reader's real Reminders and Calendar -
/// the most literal way the Book bleeds off the screen. Ordinary methods are
/// user-initiated; Workings require the separate standing authority pact.
enum EventKitWriter {
    static func addReminder(title: String, notes: String, due: Date?) async -> Bool {
        #if canImport(EventKit)
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .reminder)) ?? false
        }
        guard granted else { return false }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        do { try store.save(reminder, commit: true); return true } catch { return false }
        #else
        return false
        #endif
    }

    static func addEvent(title: String, notes: String, start: Date, end: Date) async -> Bool {
        #if canImport(EventKit)
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        guard granted, let calendar = store.defaultCalendarForNewEvents else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.startDate = start
        event.endDate = end
        event.calendar = calendar
        do { try store.save(event, span: .thisEvent, commit: true); return true } catch { return false }
        #else
        return false
        #endif
    }

    static func addAcademySessionEvent(sessionID: String, title: String, notes: String, room: String, start: Date, end: Date) async -> Bool {
        #if canImport(EventKit)
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        guard granted, let calendar = store.defaultCalendarForNewEvents else { return false }

        let marker = "ReEnchanted Academy Session: \(sessionID)"
        let searchStart = start.addingTimeInterval(-60)
        let searchEnd = end.addingTimeInterval(60)
        let predicate = store.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: [calendar])
        if store.events(matching: predicate).contains(where: { event in
            event.title == title &&
            abs(event.startDate.timeIntervalSince(start)) < 60 &&
            (event.notes ?? "").contains(marker)
        }) {
            return true
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = [notes, marker].filter { !$0.isEmpty }.joined(separator: "\n\n")
        event.location = room
        event.startDate = start
        event.endDate = end
        event.calendar = calendar
        do { try store.save(event, span: .thisEvent, commit: true); return true } catch { return false }
        #else
        return false
        #endif
    }

    static func arrangeBookWorking(_ working: BookWorking) async -> Bool {
        #if canImport(EventKit)
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        guard granted, let fallback = store.defaultCalendarForNewEvents else { return false }
        let marker = "ReEnchanted Working: \(working.id)"
        let predicate = store.predicateForEvents(
            withStart: working.startsAt.addingTimeInterval(-60),
            end: working.endsAt.addingTimeInterval(60),
            calendars: nil
        )
        if store.events(matching: predicate).contains(where: { ($0.notes ?? "").contains(marker) }) {
            return true
        }

        let calendarTitle = "ReEnchanted — Openings"
        let calendar: EKCalendar
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            calendar = existing
        } else {
            let proposed = EKCalendar(for: .event, eventStore: store)
            proposed.title = calendarTitle
            proposed.source = fallback.source
            if (try? store.saveCalendar(proposed, commit: true)) != nil {
                calendar = proposed
            } else {
                calendar = fallback
            }
        }
        let event = EKEvent(eventStore: store)
        event.title = working.title
        event.notes = [working.invitation, "Arranged by \(working.initiatorName).", marker]
            .joined(separator: "\n\n")
        event.startDate = working.startsAt
        event.endDate = working.endsAt
        event.calendar = calendar
        do { try store.save(event, span: .thisEvent, commit: true); return true } catch { return false }
        #else
        return false
        #endif
    }

    static func removeBookWorking(_ working: BookWorking) async -> Bool {
        #if canImport(EventKit)
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard status == .fullAccess else { return false }
        } else {
            guard status == .authorized else { return false }
        }
        let marker = "ReEnchanted Working: \(working.id)"
        let predicate = store.predicateForEvents(
            withStart: working.startsAt.addingTimeInterval(-60),
            end: working.endsAt.addingTimeInterval(60),
            calendars: nil
        )
        let matches = store.events(matching: predicate).filter { ($0.notes ?? "").contains(marker) }
        do {
            for event in matches { try store.remove(event, span: .thisEvent, commit: false) }
            if !matches.isEmpty { try store.commit() }
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}

#if canImport(MapKit)
import MapKit
#endif

/// Scouts real named places near the player via Apple Maps POI search, so
/// characters can send them to places that actually exist. Results are
/// cached for days and the category pool rotates weekly so quests vary.
enum LocalPlacesScout {
    struct Cache: Codable {
        var fetchedAt: Date
        var latitude: Double
        var longitude: Double
        var places: [LocalPlaceSignal]
    }

    static let cacheKey = "localPlacesCacheV1"
    static let staleAfter: TimeInterval = 5 * 86_400
    static let moveThresholdMeters = 12_000.0

    static let categoryPool = [
        "diner", "bakery", "coffee shop", "hardware store", "bookstore",
        "thrift store", "antiques", "farm stand", "library", "park",
        "ice cream", "pizza", "fish market", "garden center", "barber shop",
        "harbor", "marina", "waterfront", "trail", "train station"
    ]

    static func cachedPlaces() -> [LocalPlaceSignal] {
        guard let raw = UserDefaults.standard.string(forKey: cacheKey)?.data(using: .utf8),
              let cache = try? JSONDecoder().decode(Cache.self, from: raw) else {
            return []
        }
        return cache.places
    }

    static func refreshIfNeeded(now: Date = Date()) async -> [LocalPlaceSignal] {
        #if canImport(MapKit)
        guard let coordinate = try? await AnchorLocationReader.requestLocation() else {
            return cachedPlaces()
        }
        return await refreshIfNeeded(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            now: now
        )
        #else
        return []
        #endif
    }

    /// Uses a coordinate from the shared foreground context read. Map search is
    /// still cached for days and only reruns after meaningful travel.
    static func refreshIfNeeded(
        latitude: Double,
        longitude: Double,
        now: Date = Date()
    ) async -> [LocalPlaceSignal] {
        #if canImport(MapKit)
        var existing: Cache?
        if let raw = UserDefaults.standard.string(forKey: cacheKey)?.data(using: .utf8) {
            existing = try? JSONDecoder().decode(Cache.self, from: raw)
        }
        if let existing,
           now.timeIntervalSince(existing.fetchedAt) < staleAfter,
           AnchorMath.distanceMeters(
               fromLatitude: existing.latitude, longitude: existing.longitude,
               toLatitude: latitude, longitude: longitude
           ) < moveThresholdMeters {
            return existing.places
        }

        // Rotate five categories per refresh so the pool changes weekly.
        let week = Calendar.current.component(.weekOfYear, from: now)
        let rotated = (0..<5).map { categoryPool[(week * 3 + $0 * 2) % categoryPool.count] }
        var found: [LocalPlaceSignal] = []
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            latitudinalMeters: 24_000,
            longitudinalMeters: 24_000
        )
        for category in rotated {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category
            request.region = region
            request.resultTypes = .pointOfInterest
            guard let response = try? await MKLocalSearch(request: request).start() else { continue }
            for item in response.mapItems.prefix(3) {
                guard let name = item.name, !name.isEmpty else { continue }
                let location = item.placemark.coordinate
                let meters = AnchorMath.distanceMeters(
                    fromLatitude: latitude, longitude: longitude,
                    toLatitude: location.latitude, longitude: location.longitude
                )
                guard meters < 25_000 else { continue }
                let distance = meters < 1_500
                    ? "\(Int(meters)) m"
                    : String(format: "%.1f km", meters / 1000)
                found.append(LocalPlaceSignal(
                    id: "place-\(name.stableHash)",
                    name: name,
                    category: category,
                    distanceLabel: distance,
                    locality: item.placemark.locality ?? "",
                    latitude: location.latitude,
                    longitude: location.longitude
                ))
            }
        }
        var seen = Set<String>()
        let places = found.filter { seen.insert($0.name).inserted }
        guard !places.isEmpty else { return existing?.places ?? [] }
        let cache = Cache(fetchedAt: now, latitude: latitude, longitude: longitude, places: places)
        if let data = try? JSONEncoder().encode(cache), let encoded = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
        AppMemoryLedger.record("places-scouted-\(places.count)")
        return places
        #else
        return []
        #endif
    }
}

enum QuestLocationProof {
    static let defaultRadiusMeters = 180.0

    static func verify(elective: UnwrittenElective) async -> (success: Bool, summary: String) {
        guard let targetLatitude = elective.targetLatitude,
              let targetLongitude = elective.targetLongitude,
              let placeName = elective.targetPlaceName?.nonEmpty else {
            return (false, "This quest does not have a GPS destination attached.")
        }
        do {
            let current = try await AnchorLocationReader.requestLocation()
            let meters = AnchorMath.distanceMeters(
                fromLatitude: current.latitude,
                longitude: current.longitude,
                toLatitude: targetLatitude,
                longitude: targetLongitude
            )
            let radius = elective.targetRadiusMeters ?? defaultRadiusMeters
            let distance = meters < 1_000
                ? "\(Int(meters.rounded())) m"
                : String(format: "%.1f km", meters / 1000)
            if meters <= radius {
                return (true, "GPS proof: within \(distance) of \(placeName).")
            }
            return (false, "GPS says you are \(distance) from \(placeName). Get within \(Int(radius)) m and try again.")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

enum CompassPlaceMemory {
    static let storageKey = "compassKnownPlacesV1"

    static func knownPlaces() -> [CompassKnownPlace] {
        migrateLegacyDefaultsIfNeeded()
        return PlayerVault.shared.data.compassKnownPlaces ?? []
    }

    static func nearestKnownPlace(latitude: Double, longitude: Double) -> CompassKnownPlace? {
        knownPlaces()
            .map { place in (place, place.distanceMeters(to: latitude, longitude: longitude)) }
            .filter { $0.1 <= $0.0.radiusMeters }
            .min { $0.1 < $1.1 }?
            .0
    }

    @discardableResult
    static func remember(
        context: CompassPlaceContext,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double? = nil,
        displayName: String? = nil
    ) -> CompassKnownPlace {
        let radius = radiusMeters ?? defaultRadius(for: context)
        let now = Date()
        let existingPlaces = knownPlaces()
        let matchingIndex = existingPlaces
            .enumerated()
            .filter { _, place in
                place.contextID == context.rawValue &&
                    place.distanceMeters(to: latitude, longitude: longitude) <= max(place.radiusMeters, radius)
            }
            .min { left, right in
                left.element.distanceMeters(to: latitude, longitude: longitude) <
                    right.element.distanceMeters(to: latitude, longitude: longitude)
            }?
            .offset
        let place = CompassKnownPlace(
            id: matchingIndex.flatMap { existingPlaces[$0].id }
                ?? "compass-place-\(context.rawValue)-\(Int(now.timeIntervalSince1970))-\(abs("\(latitude),\(longitude)".stableHash))",
            name: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? context.title,
            contextID: context.rawValue,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radius,
            updatedAt: now
        )

        var places = existingPlaces
        if let matchingIndex {
            places[matchingIndex] = place
        } else {
            places.append(place)
        }
        save(places)
        return place
    }

    private static func save(_ places: [CompassKnownPlace]) {
        PlayerVault.shared.data.compassKnownPlaces = places.sorted { $0.updatedAt > $1.updatedAt }
        PlayerVault.shared.save()
    }

    private static func migrateLegacyDefaultsIfNeeded() {
        guard PlayerVault.shared.data.compassKnownPlaces == nil else { return }
        guard let raw = UserDefaults.standard.string(forKey: storageKey)?.data(using: .utf8),
              let places = try? JSONDecoder().decode([CompassKnownPlace].self, from: raw) else {
            PlayerVault.shared.data.compassKnownPlaces = []
            PlayerVault.shared.save()
            return
        }
        PlayerVault.shared.data.compassKnownPlaces = places
        PlayerVault.shared.save()
    }

    private static func defaultRadius(for context: CompassPlaceContext) -> Double {
        switch context {
        case .home, .work, .cafe, .library, .indoors:
            return 180
        case .harbor, .waterfront, .park, .trail:
            return 320
        case .store, .transit, .neighborhood:
            return 240
        case .current, .other:
            return 180
        }
    }
}

struct CompassCurrentPlaceSignal: Equatable {
    var label: String
    var context: CompassPlaceContext
    var detail: String
    var nearbyPlaces: [LocalPlaceSignal]
    var latitude: Double
    var longitude: Double
    var knownPlace: CompassKnownPlace?
    var anchorProximity: AnchorProximity?
}

enum CompassCurrentPlaceReader {
    static func request(anchors: [AnchorRecord] = []) async throws -> CompassCurrentPlaceSignal {
        let coordinate = try await AnchorLocationReader.requestLocation()
        let places = await LocalPlacesScout.refreshIfNeeded(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let anchorProximity = AnchorRegistry.nearestAnchor(
            to: coordinate.latitude,
            longitude: coordinate.longitude,
            anchors: anchors
        )
        if let knownPlace = CompassPlaceMemory.nearestKnownPlace(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            let detail = [
                "Known place: \(knownPlace.name). The Compass will use this saved area.",
                anchorProximity.map(anchorDetail)
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            return CompassCurrentPlaceSignal(
                label: knownPlace.name,
                context: knownPlace.context,
                detail: detail,
                nearbyPlaces: places,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                knownPlace: knownPlace,
                anchorProximity: anchorProximity
            )
        }
        let context = CompassPlaceContext.inferred(from: places)
        let namedPlace = bestPlace(for: context, places: places)
        let label = anchorProximity.map { "At \($0.anchor.name)" }
            ?? namedPlace.map { "Near \($0.name)" }
            ?? context.promptValue
        let detail: String
        if let anchorProximity {
            detail = anchorDetail(for: anchorProximity)
        } else if let namedPlace {
            detail = "\(context.title) reading from \(namedPlace.promptLine)"
        } else {
            detail = "\(context.title) reading from approximate device location"
        }
        return CompassCurrentPlaceSignal(
            label: label,
            context: context,
            detail: detail,
            nearbyPlaces: places,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            knownPlace: nil,
            anchorProximity: anchorProximity
        )
    }

    private static func anchorDetail(for proximity: AnchorProximity) -> String {
        let anchor = proximity.anchor
        let distance = Int(proximity.distanceMeters.rounded())
        let rememberedDetail = anchor.outerStacksRoom.nonEmpty
            ?? anchor.academyEcho.nonEmpty
            ?? anchor.localRule.nonEmpty
            ?? "The room remembers you."
        return "Anchor detected: \(anchor.name) is awake \(distance)m away. \(rememberedDetail)"
    }

    private static func bestPlace(for context: CompassPlaceContext, places: [LocalPlaceSignal]) -> LocalPlaceSignal? {
        places.first { place in
            let text = "\(place.name) \(place.category)".lowercased()
            switch context {
            case .cafe:
                return text.contains("coffee") || text.contains("cafe") || text.contains("bakery")
            case .harbor:
                return text.contains("harbor") || text.contains("harbour") || text.contains("marina") || text.contains("pier") || text.contains("fish market")
            case .waterfront:
                return text.contains("waterfront") || text.contains("beach") || text.contains("river") || text.contains("shore")
            case .trail:
                return text.contains("trail") || text.contains("greenway") || text.contains("walkway")
            case .park:
                return text.contains("park") || text.contains("garden")
            case .library:
                return text.contains("library")
            case .store:
                return text.contains("store") || text.contains("market") || text.contains("shop") || text.contains("pharmacy")
            case .transit:
                return text.contains("station") || text.contains("terminal") || text.contains("bus") || text.contains("train")
            default:
                return false
            }
        } ?? places.first
    }
}

#if canImport(StoreKit)
import StoreKit
#endif

/// The public legal documents, hosted on the landing site. App Review requires
/// functional Terms of Use (EULA) and Privacy Policy links inside the binary,
/// near the subscription. Mirrored in App Store Connect metadata.
enum LegalDocuments {
    static let termsOfUse = URL(string: "https://reenchanted.app/terms.html")!
    static let privacyPolicy = URL(string: "https://reenchanted.app/privacy.html")!
}

/// What the BookShop needs from a payment system. Real purchases always use
/// StoreKit prices; in-world currencies stay separate.
struct BookShopOffer: Identifiable, Equatable {
    var id: String          // productID
    var listing: BookShopListing
    var displayPrice: String
    var isPurchasable: Bool
}

enum BookShopPurchaseOutcome: Equatable {
    case bound          // owned, persist it
    case pending        // ask-to-buy etc.
    case cancelled
    case failed(String)
}

protocol BookShopMerchant {
    var tillName: String { get }
    func offers() async -> [BookShopOffer]
    func purchase(productID: String) async -> BookShopPurchaseOutcome
    func restorePurchases() async -> Set<String>   // owned pack IDs
}

/// The real till: StoreKit 2. Compiles today; comes alive the moment the
/// products exist in App Store Connect under a paid developer membership.
struct StoreKitMerchant: BookShopMerchant {
    let tillName = "App Store"

    func offers() async -> [BookShopOffer] {
        #if canImport(StoreKit)
        let listings = BookShopCatalog.listings.filter { !$0.comingSoon }
        guard let products = try? await Product.products(for: listings.map(\.productID)) else {
            return []
        }
        return products.compactMap { product in
            guard let listing = BookShopCatalog.listings.first(where: { $0.productID == product.id }) else {
                return nil
            }
            return BookShopOffer(
                id: product.id,
                listing: listing,
                displayPrice: product.displayPrice,
                isPurchasable: true
            )
        }
        #else
        return []
        #endif
    }

    func purchase(productID: String) async -> BookShopPurchaseOutcome {
        #if canImport(StoreKit)
        guard let product = try? await Product.products(for: [productID]).first else {
            return .failed("The Goblins cannot find that item in the till.")
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("The receipt would not verify.")
                }
                await transaction.finish()
                return .bound
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("The till made an unfamiliar noise.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .failed("No till in this build.")
        #endif
    }

    func restorePurchases() async -> Set<String> {
        #if canImport(StoreKit)
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               let packID = BookShopCatalog.packID(forProductID: transaction.productID) {
                owned.insert(packID)
            }
        }
        return owned
        #else
        return []
        #endif
    }
}

/// The dev counter: lets the whole shop flow be exercised before the paid
/// developer membership exists. Clearly labeled in the UI; binds instantly.
struct ScrivenersCounterMerchant: BookShopMerchant {
    let tillName = "Scrivener's Counter (dev)"

    func offers() async -> [BookShopOffer] {
        BookShopCatalog.listings.filter { !$0.comingSoon }.map { listing in
            BookShopOffer(
                id: listing.productID,
                listing: listing,
                displayPrice: listing.fallbackDisplayPrice ?? "$0.00 dev",
                isPurchasable: true
            )
        }
    }

    func purchase(productID: String) async -> BookShopPurchaseOutcome {
        .bound
    }

    func restorePurchases() async -> Set<String> {
        []
    }
}

/// Live pricing for one Standing Order cadence, resolved from StoreKit when the
/// product exists in App Store Connect. Trial fields are populated only when
/// StoreKit confirms this reader is currently eligible for that product's free
/// introductory offer.
struct StandingOrderTierPricing: Equatable {
    var productID: String
    var displayPrice: String
    /// StoreKit's localized numeric price, used only to calculate an honest
    /// monthly-versus-annual savings badge.
    var price: Decimal
    /// e.g. "30-day free trial", nil when the product has no introductory offer.
    var trialSummary: String?
    /// The introductory free-trial length in days, if any.
    var trialDays: Int?
}

enum StandingOrderPricing {
    /// Queries StoreKit for the two offered cadences and returns a map keyed by
    /// productID. Empty until the products go live in App Store Connect.
    static func load() async -> [String: StandingOrderTierPricing] {
        #if canImport(StoreKit)
        let ids = BookShopCatalog.standingOrderTiers.map(\.productID)
        guard let products = try? await Product.products(for: ids) else { return [:] }
        var result: [String: StandingOrderTierPricing] = [:]
        for product in products {
            var trialSummary: String?
            var trialDays: Int?
            if let subscription = product.subscription,
               let intro = subscription.introductoryOffer,
               intro.paymentMode == .freeTrial,
               await subscription.isEligibleForIntroOffer {
                let count = intro.period.value
                let unit = unitLabel(for: intro.period.unit, count: count)
                trialSummary = "\(count)-\(unit) free trial"
                trialDays = approximateDays(intro.period)
            }
            result[product.id] = StandingOrderTierPricing(
                productID: product.id,
                displayPrice: product.displayPrice,
                price: product.price,
                trialSummary: trialSummary,
                trialDays: trialDays
            )
        }
        return result
        #else
        return [:]
        #endif
    }

    #if canImport(StoreKit)
    private static func unitLabel(for unit: Product.SubscriptionPeriod.Unit, count: Int) -> String {
        let base: String
        switch unit {
        case .day: base = "day"
        case .week: base = "week"
        case .month: base = "month"
        case .year: base = "year"
        @unknown default: base = "period"
        }
        return count == 1 ? base : "\(base)s"
    }

    private static func approximateDays(_ period: Product.SubscriptionPeriod) -> Int {
        let per: Int
        switch period.unit {
        case .day: per = 1
        case .week: per = 7
        case .month: per = 30
        case .year: per = 365
        @unknown default: per = 1
        }
        return per * period.value
    }
    #endif
}

enum BookShopTill {
    /// StoreKit in distribution builds. Debug builds keep the dev counter so the
    /// shop can be exercised before App Store Connect products exist.
    static func resolveMerchant() async -> BookShopMerchant {
        let storeKit = StoreKitMerchant()
        #if DEBUG
        let live = await storeKit.offers()
        if !live.isEmpty {
            return storeKit
        }
        return ScrivenersCounterMerchant()
        #else
        return storeKit
        #endif
    }
}

/// Vellum's assistant: turns parsed fuel items into rough nutrition via the
/// USDA FoodData Central API. Always background, never blocks a keep; a
/// missing key or dead network simply means no numbers this time.
enum VellumNutritionist {
    static let keyStorageKey = "usdaFoodDataKey"

    private static var apiKey: String {
        let stored = UserDefaults.standard.string(forKey: keyStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? "DEMO_KEY" : stored
    }

    static func estimate(for entry: String) async -> VellumFuelLedger? {
        let items = FuelParser.items(from: entry)
        guard !items.isEmpty else { return nil }
        var total = NutritionEstimate.zero
        var ledgerItems: [FuelLedgerItem] = []
        var matched = 0
        for item in items.prefix(6) {
            guard let match = await lookupPer100g(item.name) else { continue }
            let scaled = FuelParser.scale(per100g: match.estimate, item: item)
            total = total + scaled
            ledgerItems.append(FuelLedgerItem(
                name: item.name,
                quantity: item.quantity,
                grams: FuelParser.estimatedGrams(for: item),
                sourceDescription: match.food.description,
                sourceID: match.food.fdcId,
                estimate: scaled
            ))
            matched += 1
        }
        guard matched > 0, total.kilocalories > 0 else { return nil }
        let confidence: VellumLedgerConfidence
        if matched == items.count, items.count <= 3 {
            confidence = .high
        } else if matched >= max(1, items.count / 2) {
            confidence = .fair
        } else {
            confidence = .low
        }
        let assumptions = ledgerItems.prefix(3).map { item in
            let grams = Int(item.grams.rounded())
            return "\(item.name) ≈ \(grams)g via \(item.sourceDescription)"
        }
        return VellumFuelLedger(
            total: total,
            confidence: confidence,
            items: ledgerItems,
            assumptions: assumptions,
            patternClues: FuelPatternRecognizer.clues(entry: entry, total: total, parsedItems: items, matchedItems: matched)
        )
    }

    private static func lookupPer100g(_ food: String) async -> FoodDataCentralNutritionMatch? {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: food),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy,FNDDS"),
            URLQueryItem(name: "pageSize", value: "8")
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = try? JSONDecoder().decode(FoodDataCentralSearchResponse.self, from: data) else {
            return nil
        }
        return FoodDataCentralNutritionParser.bestMatch(in: parsed.foods, for: food)
    }
}

/// The Book's small shared motion vocabulary. Views choose the meaning of a
/// change rather than inventing another spring, and Reduced Motion gets a quiet
/// crossfade instead of a spatial imitation of the full choreography.
enum BookMotion {
    static func direct(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.26, dampingFraction: 0.78)
    }

    static func reveal(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.46, dampingFraction: 0.86)
    }

    static func result(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.52, dampingFraction: 0.84)
    }

    static func retreat(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.14) : .easeInOut(duration: 0.24)
    }

    static func pageTurn(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.48)
    }

    static func deal(delay: Double = 0, reduceMotion: Bool) -> Animation? {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.54, dampingFraction: 0.84).delay(delay)
    }

    static func riseTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.985))
    }

    static func foldTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top))
    }
}

/// A generated answer should not pop into the layout like a refreshed label.
/// It settles as ink: a short lift, focus, and extinguishing gilt glow. This is
/// intentionally a one-shot arrival, not another perpetual ambient animation.
private struct BookResultArrivalModifier: ViewModifier {
    let reduceMotion: Bool
    var delay: Double

    @State private var didSettle = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || didSettle ? 1 : 0)
            .offset(y: reduceMotion || didSettle ? 0 : 14)
            .scaleEffect(reduceMotion || didSettle ? 1 : 0.985, anchor: .top)
            .blur(radius: reduceMotion || didSettle ? 0 : 3)
            .shadow(
                color: BookPalette.lampGold.opacity(reduceMotion || didSettle ? 0 : 0.30),
                radius: reduceMotion || didSettle ? 0 : 18,
                y: 6
            )
            .onAppear {
                guard !didSettle else { return }
                if reduceMotion {
                    didSettle = true
                } else {
                    withAnimation(BookMotion.result(false)?.delay(delay)) {
                        didSettle = true
                    }
                }
            }
    }
}

/// A photograph is treated as an object placed on the page: it lands a little
/// askew, finds focus, and settles flat. The movement happens once on insertion;
/// photographs do not hover or breathe after the reader has chosen them.
private struct BookPhotographArrivalModifier: ViewModifier {
    let reduceMotion: Bool
    var delay: Double
    @State private var didLand = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || didLand ? 1 : 0)
            .scaleEffect(reduceMotion || didLand ? 1 : 0.91)
            .rotationEffect(.degrees(reduceMotion || didLand ? 0 : -2.6))
            .offset(y: reduceMotion || didLand ? 0 : 18)
            .blur(radius: reduceMotion || didLand ? 0 : 2.2)
            .shadow(
                color: BookPalette.ink.opacity(reduceMotion || didLand ? 0.12 : 0.28),
                radius: reduceMotion || didLand ? 4 : 16,
                y: reduceMotion || didLand ? 2 : 10
            )
            .onAppear {
                guard !didLand else { return }
                if reduceMotion {
                    didLand = true
                } else {
                    withAnimation(BookMotion.deal(delay: delay, reduceMotion: false)) {
                        didLand = true
                    }
                }
            }
    }
}

extension View {
    func bookResultArrival(reduceMotion: Bool, delay: Double = 0) -> some View {
        modifier(BookResultArrivalModifier(reduceMotion: reduceMotion, delay: delay))
    }

    func bookPhotographArrival(reduceMotion: Bool, delay: Double = 0) -> some View {
        modifier(BookPhotographArrivalModifier(reduceMotion: reduceMotion, delay: delay))
    }
}

/// A tactile press style for the Book's hand-made tap targets: a gentle scale
/// and brightness dip while held, on a soft spring. The press response is direct
/// manipulation (not autonomous motion), so it intentionally stays active under
/// Reduce Motion. Purely visual — it does not fire haptics or sounds, so it is
/// safe to layer onto buttons that already play their own `BookFeedback` cue.
struct BookPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    /// Frequent controls still deserve to feel physical, but should not spend
    /// the haptic budget on every touch-down (calendar cells, formatting tools,
    /// and similar quick choices). Consequential actions keep the default.
    var playsHaptic = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // A press-down scale is direct manipulation, not autonomous motion,
            // so Apple's HIG keeps it even under Reduce Motion. We deliberately
            // do NOT gate this on reduceMotion so taps always feel alive.
            .scaleEffect(configuration.isPressed ? scale : 1, anchor: .center)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && playsHaptic { BookFeedback.pressTick() }
            }
    }
}

extension ButtonStyle where Self == BookPressStyle {
    /// Tactile press feedback matching the Book's parchment aesthetic.
    static func bookPress(scale: CGFloat = 0.96, playsHaptic: Bool = true) -> BookPressStyle {
        BookPressStyle(scale: scale, playsHaptic: playsHaptic)
    }
}

/// A pointer-only lift for large, crafted surfaces. It is deliberately opt-in:
/// small utility buttons already get enough feedback from `BookPressStyle`, and
/// the Book should never feel as if every piece of ink is clamoring for notice.
struct BookCardHoverModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.hoverEffect(.lift)
    }
}

extension View {
    func bookCardHover() -> some View {
        modifier(BookCardHoverModifier())
    }
}
