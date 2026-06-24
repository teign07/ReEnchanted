import SwiftUI
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
}

#if canImport(LocalAuthentication)
@MainActor
final class BookAppLock: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var message = "The Book is closed."

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
            message = error?.localizedDescription ?? "Set a device passcode to lock the Book."
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
            message = "The Book stayed closed."
            BookFeedback.play(.dismissPage)
        }
        return false
    }

    func lock() {
        guard isUnlocked else { return }
        isUnlocked = false
        message = "The Book is closed."
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
        AudioServicesPlaySystemSound(bookSoundID(for: cue) ?? cue.systemSoundID)
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
    /// A lock-screen pause is reversible. The in-app power/Quiet controls still
    /// call `stop`, which clears the station and removes Now Playing metadata.
    private var isPausedByRemoteControl = false
    /// Invalidates pending caption-only advances when the dial changes.
    private var playoutToken = UUID()
    /// Song queued to play once the current DJ break finishes.
    private var pendingTrack: RadioTrack?

    /// Optional hook so the app can feed live world-state (the Nothing's grey,
    /// an active festival) into banter selection without coupling the manager to
    /// the broader state graph. Time-of-day and the listening streak are derived
    /// locally. Returns (grey 0–100, festivalActive).
    var worldContextProvider: (() -> (grey: Int, festivalActive: Bool, pageContext: RadioPageContext))?

    /// Latest world snapshot pushed by the app (see `updateWorldState`). Takes
    /// precedence over `worldContextProvider`; both fall back to calm.
    private var liveWorld: (grey: Int, festivalActive: Bool, pageContext: RadioPageContext)?

    /// Push the current world-state in. Cheap to call often (e.g. on appear, on
    /// tune, on scene-active) — grey/festival change at most daily. `grey` is on
    /// the 0–100 scale the banter conditions use.
    func updateWorldState(grey: Int, festivalActive: Bool, pageContext: RadioPageContext = RadioPageContext()) {
        liveWorld = (max(0, min(100, grey)), festivalActive, pageContext)
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
        isPausedByRemoteControl = false
        isPlayingTuningNoise = false
        nowPlayingBanter = nil
        playoutToken = UUID()
        pendingTrack = nil

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
                audioPlayer.play()
                filePlayer = audioPlayer
                activeBuffer = nil
                activeTrack = track
                sourceLine = "Playing \(track.title) from local radio assets."
                updateSystemNowPlayingSong(track, station: station, duration: audioPlayer.duration)
            } catch {
                appLog.error("Radio asset failed: \(error.localizedDescription, privacy: .public)")
                playProceduralFallback(for: station, track: track)
            }
        } else {
            playProceduralFallback(for: station, track: track)
        }

        if let trackID = track?.id {
            let historyLimit = max(1, (station.tracks.count - 1) / 2)
            playback.recordTrack(trackID, historyLimit: historyLimit)
        }
        statusLine = "\(station.displayFrequency) \(station.title) — \(track?.title ?? "broadcasting")."
    }

    // MARK: - Playout loop (songs interleaved with DJ breaks)

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.handlePlayoutItemFinished() }
    }

    private func handlePlayoutItemFinished() {
        guard isPlaying, let station = activeStation else { return }
        if isPlayingBanter {
            // A break just ended — play whatever song was queued behind it (an
            // intro's bound song, or the next in rotation) so the order holds.
            resumeAfterBanter(for: station)
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
            playBanter(banter, for: station)
        } else {
            pendingTrack = nil
            beginTrack(upcoming, for: station)
        }
    }

    private func playBanter(_ banter: RadioBanter, for station: RadioStation) {
        playback.recordBanter(banter.id)
        tracksSinceBanter = 0
        nowPlayingBanter = banter
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
        isPausedByRemoteControl = false
        isPlayingTuningNoise = true
        nowPlayingBanter = nil
        activeStation = nil
        activeTrack = nil
        pendingTrack = nil
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
        isPausedByRemoteControl = false
        isPlayingTuningNoise = false
        nowPlayingBanter = nil
        tracksSinceTune = 0
        tracksSinceBanter = 0
        playoutToken = UUID()
        pendingTrack = nil
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
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — paused." } ?? "Radio static paused."
        setSystemNowPlayingPlaybackRate(0)
        return true
    }

    private func resumeFromRemoteControl() -> Bool {
        guard isPausedByRemoteControl else { return false }
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
        isPausedByRemoteControl = false
        statusLine = activeStation.map { "\($0.displayFrequency) \($0.title) — on air." } ?? "Radio static on air."
        setSystemNowPlayingPlaybackRate(1)
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
        isPlaying = true
        isPausedByRemoteControl = false
        isPlayingBanter = false
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
            MPMediaItemPropertyComments: banter.caption,
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
            pageContext: world.pageContext
        )
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
    private init() {}
    func restore(state: RadioPlaybackState, unlockedPackIDs: Set<String>) { playback = state }
    func tune(stationID: String, unlockedPackIDs: Set<String>) {
        activeStation = RadioStationRegistry.station(id: stationID, unlockedPackIDs: unlockedPackIDs)
        activeTrack = activeStation?.tracks.first
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
        if persist {
            PlayerVault.shared.data.radio = playback
            PlayerVault.shared.save()
        }
    }
    func hapticTick() {}
}
#endif

extension Notification.Name {
    static let localBrainDidWake = Notification.Name("localBrainDidWake")
    static let localBrainDidRest = Notification.Name("localBrainDidRest")
    static let localBrainWorkDidChange = Notification.Name("localBrainWorkDidChange")
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

enum AppMemoryLedger {
    static func record(_ checkpoint: String) {
        let resident = residentBytes()
        let message = "Memory checkpoint \(checkpoint); resident: \(resident)"
        appLog.info("\(message, privacy: .public)")
        print(message)
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
        "The Book is checking the corners for meaning.",
        "A small clerk in the margins has found a useful comma.",
        "Sorting bright fragments from dramatic lint.",
        "The page is warming its hands before it speaks.",
        "Listening for the sentence that has been hiding in the day.",
        "A ribbon is being tied around the ordinary.",
        "The ink is asking one follow-up question very quietly.",
        "Cross-referencing tea stains, weather, and courage.",
        "The Book is refusing to hurry the delicate bit.",
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
            phrase = "The Book has softened the room today; the body asked for fewer sharp edges and a slower kind of courage."
        } else if steps < 900 && activeKilocalories < 120 {
            status = "LOW"
            score = 34
            phrase = "The lamps are low in the stacks. This looks like a day for small thresholds, warm fuel, and no heroic errands."
        } else if steps > 5_500 || distanceMeters > 3_500 {
            status = "BRIGHT"
            score = 76
            phrase = "There is motion in the margins. The Book can feel the day has had footsteps in it."
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
        let weather = try await OpenMeteoClient.forecast(for: location.coordinate)
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
        #else
        throw ReaderError.unavailable
        #endif
    }
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
                manager.requestLocation()
            case .denied, .restricted:
                finish(throwing: WeatherLocationReader.ReaderError.denied)
            @unknown default:
                finish(throwing: WeatherLocationReader.ReaderError.noLocation)
            }
        }
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
/// instead of choosing one from the library.
struct BookCameraCaptureView: UIViewControllerRepresentable {
    let onImageData: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageData: onImageData) {
            dismiss()
        }
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImageData: (Data) -> Void
        let dismiss: () -> Void

        init(onImageData: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onImageData = onImageData
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.86) {
                onImageData(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif

#if canImport(UserNotifications)
import UserNotifications
#endif

/// The Book's voice outside the app: a few quiet, in-world local
/// notifications. Class bells, the evening braid whisper, and aging favors.
/// Everything is prefixed so a refresh can sweep ours without touching
/// anything else, and the whole channel has one switch in the Colophon.
enum BookWhispers {
    static let identifierPrefix = "book-whisper-"

    static func refreshSchedule(enabled: Bool, electives: [UnwrittenElective], whisperController: String? = nil, whisperSovereign: Bool = false, festivalWhisper: (title: String, body: String)? = nil, now: Date = Date()) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            guard enabled else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                schedule(center: center, electives: electives, whisperController: whisperController, whisperSovereign: whisperSovereign, festivalWhisper: festivalWhisper, now: now)
            }
        }
        #endif
    }

    #if canImport(UserNotifications)
    private static func schedule(center: UNUserNotificationCenter, electives: [UnwrittenElective], whisperController: String?, whisperSovereign: Bool, festivalWhisper: (title: String, body: String)?, now: Date) {
        var requests: [UNNotificationRequest] = []
        let calendar = Calendar.current

        // Class and club bells for the next three days, only future ones.
        for dayOffset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard let plan = AcademyScheduleRegistry.week[weekday] else { continue }
            if let id = plan.morning,
               let session = AcademyScheduleRegistry.classes[id],
               let request = bellRequest(for: session, on: day, hour: 9, isClub: false, calendar: calendar, now: now) {
                requests.append(request)
            }
            if let id = plan.club,
               let session = AcademyScheduleRegistry.clubs[id],
               let request = bellRequest(for: session, on: day, hour: 19, isClub: true, calendar: calendar, now: now) {
                requests.append(request)
            }
        }

        // The evening braid whisper, repeating daily — recolored by whoever holds
        // the Whisper Channel in the Pact War.
        let whisper = PactVoices.braidWhisper(controller: whisperController)
        let braidContent = UNMutableNotificationContent()
        braidContent.title = whisper.title
        braidContent.body = whisper.body
        braidContent.sound = .default
        var braidTime = DateComponents()
        braidTime.hour = 20
        braidTime.minute = 45
        requests.append(UNNotificationRequest(
            identifier: "\(identifierPrefix)braid",
            content: braidContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: braidTime, repeats: true)
        ))

        // A festival on the Wheel calls the reader to it in the early evening.
        if let festivalWhisper {
            let content = UNMutableNotificationContent()
            content.title = festivalWhisper.title
            content.body = festivalWhisper.body
            content.sound = .default
            var feastTime = DateComponents()
            feastTime.hour = 18
            feastTime.minute = 0
            requests.append(UNNotificationRequest(
                identifier: "\(identifierPrefix)festival",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: feastTime, repeats: false)
            ))
        }

        // Sovereign automation: a Talisman that reigns over the Whisper Channel
        // speaks an extra, unprompted morning whisper in its own voice.
        if whisperSovereign, let sovereign = PactVoices.sovereignWhisper(controller: whisperController) {
            let content = UNMutableNotificationContent()
            content.title = sovereign.title
            content.body = sovereign.body
            content.sound = .default
            var morning = DateComponents()
            morning.hour = 8
            morning.minute = 30
            requests.append(UNNotificationRequest(
                identifier: "\(identifierPrefix)sovereign",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: morning, repeats: true)
            ))
        }

        // Favors that have waited three days.
        for elective in electives.filter(\.isActive) {
            let remindAt = elective.createdAt.addingTimeInterval(3 * 24 * 3600)
            guard remindAt > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "A favor is waiting in the flyleaf"
            content.body = "\(elective.characterName) is still hoping for \"\(elective.title)\". One sentence of proof completes it."
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
            requests.append(UNNotificationRequest(
                identifier: "\(identifierPrefix)elective-\(elective.id)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }

        for request in requests {
            center.add(request)
        }
    }

    private static func bellRequest(
        for session: AcademySession,
        on day: Date,
        hour: Int,
        isClub: Bool,
        calendar: Calendar,
        now: Date
    ) -> UNNotificationRequest? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }
        let content = UNMutableNotificationContent()
        content.title = isClub ? "\(session.name) is gathering" : "The \(session.name) bell"
        content.body = isClub
            ? "\(session.room), seven bells. \(session.companions.first.map { "\($0) will be there." } ?? "The regulars are arriving.")"
            : "\(session.leader) is starting in \(session.room)."
        content.sound = .default
        let dayID = calendar.dateComponents([.year, .month, .day], from: day)
        return UNNotificationRequest(
            identifier: "\(identifierPrefix)bell-\(session.id)-\(dayID.year ?? 0)-\(dayID.month ?? 0)-\(dayID.day ?? 0)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }
    #endif
}

#if canImport(UserNotifications)
/// Lets the Book's whispers show as banners even while the app is in the
/// foreground (iOS suppresses them by default without this).
final class BookWhisperPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BookWhisperPresenter()
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
#endif

extension BookWhispers {
    /// Install the foreground presenter once, at launch.
    static func configureForegroundPresentation() {
        #if canImport(UserNotifications)
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
            content.body = "If you can read this, the Book's voice reaches you. (It waited about ten seconds.)"
            content.sound = .default
            center.add(UNNotificationRequest(
                identifier: "\(identifierPrefix)test-\(UUID().uuidString)",
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

/// The overnight scribe: while the phone charges, the Book pre-writes the
/// next Story Page so mornings open onto fresh ink instead of a spinner.
enum OvernightScribe {
    static let taskIdentifier = "com.openclaw.enchantify.insidecover.overnight-scribe"
    static let freshnessWindow: TimeInterval = 18 * 3600

    private struct Draft: Codable {
        var generatedAt: Date
        var surface: SurfacePage
    }

    static var draftURL: URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OvernightStoryPage.json")
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

        let draft: SurfacePage = await MainActor.run {
            let days = BookDatabase.loadDays(migratingFrom: BookStore.loadDays())
            let day = BookStore.today(from: days)
            var inputs = BookSourceInputs.from(insideCover: InsideCoverStore.load())
            inputs.selfFacts = (try? BookDatabase.selfFacts()) ?? []
            let events = (try? BookDatabase.narrativeEvents(limit: 160)) ?? []
            let memories = (try? BookDatabase.entityMemories(limit: 240)) ?? []
            inputs.narrative = NarrativeSourceSnapshotBuilder.snapshot(
                from: events,
                memories: memories,
                beliefWeight: nil
            )
            return NarrativeOSPageSourceAdapter.draftCandidate(for: day, inputs: inputs, now: now)
        }

        await LocalBrainInferenceGate.shared.setBackgroundAllowance(true)
        defer {
            Task { await LocalBrainInferenceGate.shared.setBackgroundAllowance(false) }
        }
        do {
            let prose = try await MLXStoryPageWriter().write(surface: draft)
            let prepared = draft.preparedStoryPageCopy(
                prose: prose,
                slotID: SurfaceCadence.slotID(for: now, hours: 4)
            )
            let data = try JSONEncoder().encode(Draft(generatedAt: now, surface: prepared))
            try data.write(to: draftURL, options: [.atomic])
            return true
        } catch {
            appLog.error("Overnight scribe failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
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
}

/// All transient "the Book is writing" state, extracted from ContentView:
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

/// Owns PlayerVaultData on disk. Replaces five separate JSON-in-AppStorage
/// ledgers; migrates them once on first launch and then becomes the only
/// writer. Observable, so views tracking vault-backed values stay live.
@Observable
final class PlayerVault {
    static let shared = PlayerVault()

    var data: PlayerVaultData

    private static var fileURL: URL {
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PlayerVault.json")
    }

    private init() {
        if let bytes = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode(PlayerVaultData.self, from: bytes) {
            data = decoded
            return
        }
        data = Self.migrateFromLegacyLedgers()
        persist()
    }

    func save() {
        persist()
    }

    private func persist() {
        guard let bytes = try? JSONEncoder().encode(data) else { return }
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
        return migrated
    }
}


#if canImport(EventKit)
import EventKit
#endif

/// The Calendar Doorway: reads today's and tomorrow's real events so the
/// curator can feel the day's hinges. Nothing leaves the device.
enum CalendarDoorway {
    static var isAvailable: Bool {
        #if canImport(EventKit)
        return true
        #else
        return false
        #endif
    }

    static func upcomingEvents(now: Date = Date()) async -> [CalendarEventSignal] {
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
        let end = calendar.date(byAdding: .day, value: 2, to: now) ?? now.addingTimeInterval(2 * 86_400)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay || calendar.isDate($0.startDate, inSameDayAs: now) }
            .prefix(24)
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
/// the most literal way the Book bleeds off the screen. Always user-initiated.
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
}

#if canImport(MapKit)
import MapKit
#endif

/// Scouts real named places near the player via Apple Maps POI search, so
/// characters can send them to places that actually exist. Results are
/// cached for days and the category pool rotates weekly so favors vary.
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
        var existing: Cache?
        if let raw = UserDefaults.standard.string(forKey: cacheKey)?.data(using: .utf8) {
            existing = try? JSONDecoder().decode(Cache.self, from: raw)
        }
        guard let coordinate = try? await AnchorLocationReader.requestLocation() else {
            return existing?.places ?? []
        }
        if let existing,
           now.timeIntervalSince(existing.fetchedAt) < staleAfter,
           AnchorMath.distanceMeters(
               fromLatitude: existing.latitude, longitude: existing.longitude,
               toLatitude: coordinate.latitude, longitude: coordinate.longitude
           ) < moveThresholdMeters {
            return existing.places
        }

        // Rotate five categories per refresh so the pool changes weekly.
        let week = Calendar.current.component(.weekOfYear, from: now)
        let rotated = (0..<5).map { categoryPool[(week * 3 + $0 * 2) % categoryPool.count] }
        var found: [LocalPlaceSignal] = []
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
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
                    fromLatitude: coordinate.latitude, longitude: coordinate.longitude,
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
                    locality: item.placemark.locality ?? ""
                ))
            }
        }
        var seen = Set<String>()
        let places = found.filter { seen.insert($0.name).inserted }
        guard !places.isEmpty else { return existing?.places ?? [] }
        let cache = Cache(fetchedAt: now, latitude: coordinate.latitude, longitude: coordinate.longitude, places: places)
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
        radiusMeters: Double? = nil
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
            name: context.title,
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
        let places = await LocalPlacesScout.refreshIfNeeded()
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
               let listing = BookShopCatalog.listings.first(where: { $0.productID == transaction.productID }) {
                owned.insert(listing.packID)
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
                displayPrice: "$0.00 dev",
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

    static func estimate(for entry: String) async -> NutritionEstimate? {
        let items = FuelParser.items(from: entry)
        guard !items.isEmpty else { return nil }
        var total = NutritionEstimate.zero
        var matched = 0
        for item in items.prefix(6) {
            guard let per100g = await lookupPer100g(item.name) else { continue }
            total = total + FuelParser.scale(per100g: per100g, item: item)
            matched += 1
        }
        guard matched > 0, total.kilocalories > 0 else { return nil }
        return total
    }

    private static func lookupPer100g(_ food: String) async -> NutritionEstimate? {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: food),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy"),
            URLQueryItem(name: "pageSize", value: "1")
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = parsed["foods"] as? [[String: Any]],
              let first = foods.first,
              let nutrients = first["foodNutrients"] as? [[String: Any]] else {
            return nil
        }
        func value(_ names: [String]) -> Double {
            for nutrient in nutrients {
                guard let name = nutrient["nutrientName"] as? String,
                      names.contains(where: { name.hasPrefix($0) }),
                      let amount = nutrient["value"] as? Double else { continue }
                return amount
            }
            return 0
        }
        let estimate = NutritionEstimate(
            kilocalories: value(["Energy"]),
            protein: value(["Protein"]),
            carbohydrates: value(["Carbohydrate, by difference"]),
            fat: value(["Total lipid (fat)"])
        )
        return estimate.kilocalories > 0 ? estimate : nil
    }
}

/// A tactile press style for the Book's hand-made tap targets: a gentle scale
/// and brightness dip while held, on a soft spring. The press response is direct
/// manipulation (not autonomous motion), so it intentionally stays active under
/// Reduce Motion. Purely visual — it does not fire haptics or sounds, so it is
/// safe to layer onto buttons that already play their own `BookFeedback` cue.
struct BookPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

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
                if isPressed { BookFeedback.pressTick() }
            }
    }
}

extension ButtonStyle where Self == BookPressStyle {
    /// Tactile press feedback matching the Book's parchment aesthetic.
    static func bookPress(scale: CGFloat = 0.96) -> BookPressStyle {
        BookPressStyle(scale: scale)
    }
}
