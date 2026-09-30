import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(QuartzCore)
import QuartzCore
#endif

/// How much the Book says out loud. Separate from the haptic mode: some readers
/// want the touch without the music, and some the music without the buzz.
enum BookSoundMode: String, CaseIterable, Identifiable {
    /// Every touch has a voice: presses, the select ladder, page turns, all of it.
    case full
    /// Only the moments that matter: keeps, weaves, arrivals, ceremonies, errors.
    case quiet
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "Full"
        case .quiet: return "Quiet"
        case .off: return "Off"
        }
    }
}

/// The Book's voice. Sounds are rendered by scripts/generate_book_sounds.py:
/// lute, mandolin, kalimba and glass in D pentatonic, so any two that overlap
/// are consonant. This type decides *which* rendering plays, so the same touch
/// is never the same sound twice:
///
/// - **variants** rotate round-robin, never repeating back to back;
/// - the **select ladder** climbs a rung for every choice made in quick
///   succession, and resets after a pause;
/// - the **keep count** escalates through the day: the eighth page kept today is a
///   full flourish, not the same stamp again.
///
/// Plays through AudioServices, as the cues always have: it follows the silent
/// switch, mixes with the radio and other apps' audio, and needs no session.
enum BookSoundBank {
    /// One family of renderings on disk (`<family>-<n>.caf`).
    enum Family: String, CaseIterable {
        case press, tap, select, open, dismiss, keep, undo
        case braidstart, braidcomplete, refresh, error, knock, knockreply
        case turn, turnback, toggle, ink, radiolock
        case fae, constellation, belief, rise, jump, nothing, ceremony
        case overture, today, seal, lift, drop, whisper
        case peek, confirm, begin

        /// Everyday touches. Quiet mode keeps only the families that mark a moment.
        var isEveryday: Bool {
            switch self {
            case .press, .tap, .select, .turn, .turnback, .toggle, .ink, .seal, .lift, .drop, .peek, .confirm, .begin:
                return true
            default:
                return false
            }
        }

        /// The floor between two plays of the same family: a stuttering double-call
        /// (one tap firing its cue twice) becomes one sound, and a held key or a fast
        /// scroll becomes a cadence instead of a rattle.
        var minimumInterval: TimeInterval {
            switch self {
            case .press: return 0.05
            case .turn, .turnback: return 0.14        // fast flipping stays a soft flutter, not a rattle
            case .tap, .select, .toggle, .seal: return 0.045
            case .lift, .drop, .confirm, .begin: return 0.08
            case .peek: return 0.06
            case .ink: return 0.12
            default: return 0.03
            }
        }
    }

    // MARK: Mode

    static var mode: BookSoundMode {
        get { BookSoundMode(rawValue: UserDefaults.standard.string(forKey: "bookSoundMode") ?? "full") ?? .full }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "bookSoundMode") }
    }

    // MARK: Playing

    /// Plays a cue with the escalation rules each one has.
    ///
    /// Three levels of voice. By default a cue is a single pleasing gesture that never asks for
    /// attention (peek, confirm, begin, refresh). `fill: true` is for impactful moments: opening
    /// a major room, binding an edition, a braid, a pact. It swaps in the full flourish. Keeping a
    /// page is always a fill and escalates through the day.
    static func playCue(_ cue: BookFeedback.Cue, fill: Bool = false) {
        switch cue {
        case .tap: play(.tap)
        case .select: playLadderRung()
        case .openPage: play(fill ? .open : .peek)
        case .keepPage: playKeepStreak()
        case .dismissPage: play(.dismiss)
        case .undo: play(.undo)
        case .braidStart: play(fill ? .braidstart : .begin)
        case .braidComplete: play(fill ? .braidcomplete : .confirm)
        case .sourceRefresh: play(.refresh)
        case .error: play(.error)
        case .knock: play(.knock)
        case .knockReply: play(.knockreply)
        }
    }

    /// A specific rendering, or a random one that isn't the last one played.
    static func play(_ family: Family, variant: Int? = nil) {
        #if canImport(AudioToolbox)
        let current = mode
        guard current != .off else { return }
        if current == .quiet, family.isEveryday { return }

        state.lock.lock()
        let now = CACurrentMediaTime()
        if let last = state.lastPlayed[family], now - last < family.minimumInterval {
            state.lock.unlock()
            return
        }
        state.lastPlayed[family] = now
        let count = variantCount(for: family)
        let index: Int
        if let variant {
            index = max(0, min(variant, max(0, count - 1)))
        } else if count <= 1 {
            index = 0
        } else {
            var pick = Int.random(in: 0..<count)
            if pick == state.lastVariant[family] { pick = (pick + 1) % count }
            index = pick
        }
        state.lastVariant[family] = index
        state.lock.unlock()

        guard let soundID = soundID(family, index) else { return }
        AudioServicesPlaySystemSound(soundID)
        #endif
    }

    // MARK: Escalation

    /// Ten rungs, F#4 up to E6. Choose again within `ladderWindow` and it climbs;
    /// at the top it turns around and walks back down, so a long run of
    /// selections is a little melody instead of a plateau.
    private static let ladderWindow: TimeInterval = 1.3

    private static func playLadderRung() {
        #if canImport(AudioToolbox)
        let rungs = max(1, variantCount(for: .select))
        state.lock.lock()
        let now = CACurrentMediaTime()
        if now - state.ladderAt > ladderWindow {
            state.ladderRung = Int.random(in: 0...min(2, rungs - 1))
            state.ladderDirection = 1
        } else {
            var next = state.ladderRung + state.ladderDirection
            if next >= rungs { state.ladderDirection = -1; next = max(0, rungs - 2) }
            if next < 0 { state.ladderDirection = 1; next = min(1, rungs - 1) }
            state.ladderRung = next
        }
        state.ladderAt = now
        let rung = state.ladderRung
        state.lock.unlock()
        play(.select, variant: rung)
        #endif
    }

    /// Eight tiers, one per keep across the day: the first page kept today is the plain stamp, the
    /// second a little bigger, and so on up to a full flourish from the eighth keep onward. The count
    /// is per calendar day (local time) and survives relaunches, so a day of keeping is an arc.
    private static let keepCountKey = "bookKeepCountToday"
    private static let keepDayKey = "bookKeepDay"

    private static func playKeepStreak() {
        #if canImport(AudioToolbox)
        let tiers = max(1, variantCount(for: .keep))
        let tier = min(registerKeepToday() - 1, tiers - 1)
        play(.keep, variant: max(0, tier))
        #endif
    }

    /// Counts a keep against today and returns how many have been kept, this one included.
    private static func registerKeepToday(now: Date = Date()) -> Int {
        let defaults = UserDefaults.standard
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let today = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        state.lock.lock()
        defer { state.lock.unlock() }
        var count = defaults.integer(forKey: keepCountKey)
        if defaults.string(forKey: keepDayKey) != today {
            defaults.set(today, forKey: keepDayKey)
            count = 0
        }
        count += 1
        defaults.set(count, forKey: keepCountKey)
        return count
    }

    // MARK: Moments

    static func press() { play(.press) }

    static func pageTurn(forward: Bool) { play(forward ? .turn : .turnback) }

    static func toggle(on: Bool) {
        // toggle-0/1 rise, toggle-2/3 fall
        play(.toggle, variant: (on ? 0 : 2) + Int.random(in: 0...1))
    }

    /// The quill lifts at the end of a sentence.
    static func inkSentence() { play(.ink) }

    static func radioLocked() { play(.radiolock) }

    static func faeArrival(kind: String, court: String?) {
        let key = kind.lowercased()
        let variant: Int
        if key.contains("pixie") { variant = 1 }
        else if key.contains("goblin") { variant = 2 }
        else if key.contains("sprite") { variant = 3 }
        else if key.contains("salamander") { variant = 4 }
        else if key.contains("dwarf") { variant = 5 }
        else if court?.lowercased().contains("unseelie") == true { variant = 6 }
        else { variant = 0 }
        play(.fae, variant: variant)
    }

    /// Two stars is the least a constellation can be; the sound is timed to the
    /// haptic beats, one note per star.
    static func constellation(nodes: Int) {
        play(.constellation, variant: max(2, min(nodes, 7)) - 2)
    }

    static func beliefTransferred(amount: Int) {
        play(.belief, variant: max(1, min(amount, 5)) - 1)
    }

    /// Tier 2 matches the rarity the haptic already treats as special.
    static func pageRising(rarity: Int) {
        play(.rise, variant: rarity >= 80 ? 2 : (rarity >= 40 ? 1 : 0))
    }

    static func bookJump(_ cue: BookFeedback.BookJumpCue) {
        switch cue {
        case .start: play(.jump, variant: 0)
        case .deeper: play(.jump, variant: 1)
        case .stabilize: play(.jump, variant: 2)
        case .returnHome: play(.jump, variant: 3)
        }
    }

    static func nothingPressure(_ level: Int) {
        play(.nothing, variant: max(1, min(level, 4)) - 1)
    }

    static func monthBound() { play(.ceremony, variant: 0) }

    static func pressReady() { play(.ceremony, variant: 1) }

    // MARK: The launch, and the day

    /// The three beats of the Book waking, timed to `OpeningBookLoadingView`.
    enum OvertureBeat: Int {
        /// The Book appears and its title is written (t = 0, ~0.65 s lead-in).
        case appear = 0
        /// The cover swings open and light floods (the 0.45 s reveal; the chord lands at ~0.4 s).
        case open = 1
        /// "Found your place": the desk fades in.
        case settle = 2
    }

    static func overture(_ beat: OvertureBeat) { play(.overture, variant: beat.rawValue) }

    /// Book Today rising as the first reading surface: the most-heard flourish in the app, three
    /// roots rotating so it never lands identically twice.
    static func todaySurfaces() { play(.today) }

    // MARK: Small gestures

    static func sealTick(engaged: Bool) { play(.seal, variant: engaged ? 0 : 1) }

    static func pagewrightLift() { play(.lift) }

    static func pagewrightDrop() { play(.drop) }

    // MARK: Notification chime

    /// The Book's own voice for its whispers, installed where iOS looks for custom notification
    /// sounds (Library/Sounds) the first time it is needed.
    static let notificationSoundFileName = "BookWhisper.caf"

    #if canImport(UserNotifications)
    static var notificationSound: UNNotificationSound {
        installNotificationSoundIfNeeded()
        return isNotificationSoundInstalled
            ? UNNotificationSound(named: UNNotificationSoundName(rawValue: notificationSoundFileName))
            : .default
    }
    #endif

    private static var notificationSoundDestination: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent(notificationSoundFileName)
    }

    private static var isNotificationSoundInstalled: Bool {
        guard let destination = notificationSoundDestination else { return false }
        return FileManager.default.fileExists(atPath: destination.path)
    }

    static func installNotificationSoundIfNeeded() {
        guard let destination = notificationSoundDestination,
              let source = Bundle.main.url(forResource: "whisper-0", withExtension: "caf", subdirectory: "BookSounds")
        else { return }
        let fileManager = FileManager.default
        let sourceSize = (try? fileManager.attributesOfItem(atPath: source.path)[.size] as? Int) ?? -1
        let destinationSize = (try? fileManager.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? -2
        if sourceSize == destinationSize { return }        // already the current chime
        try? fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fileManager.removeItem(at: destination)
        try? fileManager.copyItem(at: source, to: destination)
    }

    // MARK: Loading

    /// Creates every SystemSoundID off the main thread so the first touch of a
    /// session isn't the one that pays for opening files.
    static func prewarm() {
        #if canImport(AudioToolbox)
        DispatchQueue.global(qos: .utility).async {
            installNotificationSoundIfNeeded()
            for family in Family.allCases {
                for index in 0..<variantCount(for: family) {
                    _ = soundID(family, index)
                }
            }
        }
        #endif
    }

    #if canImport(AudioToolbox)
    private final class State {
        let lock = NSLock()
        var ids: [String: SystemSoundID] = [:]
        var lastPlayed: [Family: TimeInterval] = [:]
        var lastVariant: [Family: Int] = [:]
        var ladderRung = 0
        var ladderDirection = 1
        var ladderAt: TimeInterval = -100
    }

    private static let state = State()

    /// How many renderings of each family the bundle holds (from manifest.json,
    /// falling back to probing the folder). Computed once, thread-safely.
    private static let counts: [Family: Int] = {
        var result: [Family: Int] = [:]
        for family in Family.allCases {
            var count = manifest[family.rawValue] ?? 0
            if count == 0 {
                while bundledURL(family, count) != nil { count += 1 }
            }
            result[family] = count
        }
        return result
    }()

    private static func variantCount(for family: Family) -> Int {
        counts[family] ?? 0
    }

    private static let manifest: [String: Int] = {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "BookSounds"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded
    }()

    private static func bundledURL(_ family: Family, _ index: Int) -> URL? {
        Bundle.main.url(forResource: "\(family.rawValue)-\(index)", withExtension: "caf", subdirectory: "BookSounds")
    }

    private static func soundID(_ family: Family, _ index: Int) -> SystemSoundID? {
        let name = "\(family.rawValue)-\(index)"
        state.lock.lock()
        if let cached = state.ids[name] {
            state.lock.unlock()
            return cached
        }
        state.lock.unlock()
        guard let url = bundledURL(family, index) else { return nil }
        var id: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { return nil }
        state.lock.lock()
        if let raced = state.ids[name] {
            state.lock.unlock()
            AudioServicesDisposeSystemSoundID(id)
            return raced
        }
        state.ids[name] = id
        state.lock.unlock()
        return id
    }
    #endif
}

import SwiftUI

extension View {
    /// Gives a switch the Book's voice: a rising two-note step on, a falling one off. Attach it to
    /// the Toggle (or its container) with the value the Toggle is bound to.
    func bookToggleSound(_ isOn: Bool) -> some View {
        onChange(of: isOn) { _, now in BookSoundBank.toggle(on: now) }
    }
}
