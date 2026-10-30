import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - The moment of a keep
//
// docs/noticing-and-writing-sessions-plan.md §8, "richer captures". The Page
// sheet tells this recorder how the words are arriving, and a light motion
// sampler runs only while a Page is open. `pageContextSnapshot` reads both at
// the keep. Nothing here stores a word the reader deleted, a sound, or a
// picture: counts, a posture and a few device readings.

@MainActor
enum KeepMoment {
    private static var firstEditAt: Date?
    private static var lastEditAt: Date?
    private static var charactersDeleted = 0
    private static var pauses = 0
    private static var chunks = 0
    private static var charactersKept = 0

    /// A Page opened: whatever was being written before belongs to it, not this one.
    static func beginPage() {
        firstEditAt = nil
        lastEditAt = nil
        charactersDeleted = 0
        pauses = 0
        chunks = 0
        charactersKept = 0
    }

    static func recordEdit(from old: String, to new: String, at now: Date = Date()) {
        if firstEditAt == nil { firstEditAt = now }
        if let lastEditAt, now.timeIntervalSince(lastEditAt) >= 30 { pauses += 1 }
        let change = new.count - old.count
        if change < 0 { charactersDeleted -= change }
        // A run of words that lands at once was spoken or pasted, not typed.
        if change >= 15 { chunks += 1 }
        lastEditAt = now
        charactersKept = new.count
    }

    /// How this keep was written, if the reader wrote anything on this Page.
    static func writing(at now: Date) -> WritingProcess? {
        guard let firstEditAt, let lastEditAt, now.timeIntervalSince(lastEditAt) < 30 * 60 else { return nil }
        return WritingProcess(
            secondsWriting: max(0, now.timeIntervalSince(firstEditAt)),
            charactersDeleted: charactersDeleted,
            pauses: pauses,
            spokenOrPastedChunks: chunks,
            charactersKept: charactersKept
        )
    }

    /// How the phone was being held, and the device's state, right now.
    static func holding() -> HoldingSnapshot {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let battery = device.batteryLevel
        let screen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
        var headphones: Bool?
        #if canImport(AVFoundation)
        let personal: Set<AVAudioSession.Port> = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        headphones = AVAudioSession.sharedInstance().currentRoute.outputs.contains { personal.contains($0.portType) }
        #endif
        let posture = HoldingSensor.shared.latest
        return HoldingSnapshot(
            posture: posture?.posture,
            moving: posture?.moving,
            batteryPercent: battery >= 0 ? Int((battery * 100).rounded()) : nil,
            charging: device.batteryState == .unknown ? nil : (device.batteryState == .charging || device.batteryState == .full),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            screenBrightness: screen.map { Double($0.brightness) },
            headphones: headphones
        )
    }
}

/// Reads which way gravity points, a few times a second, only while a Page is
/// open. Raw motion needs no permission; nothing is kept but the last reading.
@MainActor
final class HoldingSensor {
    static let shared = HoldingSensor()

    struct Reading {
        var posture: HoldingSnapshot.Posture
        var moving: Bool
    }

    private(set) var latest: Reading?
    #if canImport(CoreMotion)
    private let manager = CMMotionManager()
    #endif
    private var openPages = 0
    private var recentShake: [Double] = []

    func start() {
        openPages += 1
        #if canImport(CoreMotion)
        guard openPages == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 0.25
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { self?.record(motion) }
        }
        #endif
    }

    func stop() {
        openPages = max(0, openPages - 1)
        #if canImport(CoreMotion)
        if openPages == 0 { manager.stopDeviceMotionUpdates() }
        #endif
    }

    #if canImport(CoreMotion)
    private func record(_ motion: CMDeviceMotion) {
        let gravity = motion.gravity
        let posture: HoldingSnapshot.Posture
        if gravity.z < -0.8 {
            posture = .flat
        } else if gravity.z > 0.6 {
            posture = .overhead
        } else if abs(gravity.x) > 0.6 {
            posture = .sideways
        } else {
            posture = .upright
        }
        let acceleration = motion.userAcceleration
        recentShake.append((acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z).squareRoot())
        if recentShake.count > 12 { recentShake.removeFirst(recentShake.count - 12) }
        let shake = recentShake.reduce(0, +) / Double(recentShake.count)
        latest = Reading(posture: posture, moving: shake > 0.08)
    }
    #endif
}
