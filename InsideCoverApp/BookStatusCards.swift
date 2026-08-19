import SwiftUI
import OSLog
import Darwin.Mach
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS) && canImport(Contacts) && canImport(ContactsUI)
import Contacts
import ContactsUI
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

/// The Book's hidden systems may keep exact scores, costs, thresholds, and
/// clocks. Reader-facing views translate that state into felt condition and
/// consequence so the Book reads like one living character, not a dashboard.
///
/// Real-world facts (prices, dates, event times, weather, and health readings)
/// remain exact. These helpers are only for fictional simulation state.
enum BookMechanicPresentation {
    static func glow(_ value: Int) -> String {
        BeliefLexicon.glowName(for: max(0, min(100, value)))
    }

    static func quantity(_ value: Int, none: String, some: String, many: String) -> String {
        if value <= 0 { return none }
        if value <= 2 { return some }
        return many
    }

    static func progress(current: Int, total: Int) -> String {
        guard total > 0, current > 0 else { return "The first marks are waiting." }
        if current >= total { return "The binding is ready." }
        if current * 2 < total { return "The binding has begun to gather." }
        return "The binding is nearly holding together."
    }

    static func pressure(current: Int, limit: Int) -> String {
        guard current > 0 else { return "The page is holding steady." }
        if limit > 0, current >= limit { return "The story is coming apart at the edges." }
        if limit > 0, current * 2 >= limit { return "The edges are beginning to forget themselves." }
        return "A little static is worrying the margin."
    }

    static func faeStanding(warmth: Int, claim: Int) -> String {
        if claim >= 60 { return "The old law is watching this relationship closely." }
        if warmth >= 55 { return "The welcome here has grown unmistakably warm." }
        if warmth >= 20 { return "The welcome is warming, cautiously." }
        if claim > 0 { return "The ledger remembers unfinished old law." }
        return "Neither side has decided what to make of the other yet."
    }

    static func pactPresence(
        territory: PactTerritory,
        chapter: AcademyChapter?,
        tier: PactTier
    ) -> String {
        guard let chapter else { return "No Talisman has made this place its own." }
        switch tier {
        case .contesting:
            return "\(chapter.talismanName) has begun leaving small signs here."
        case .influenced:
            return "\(chapter.talismanName) is often found in these margins."
        case .controlled:
            return "\(chapter.talismanName) has become part of how this place speaks."
        case .dominated:
            return "\(chapter.talismanName) has made this place unmistakably its own."
        case .sovereign:
            return "\(chapter.talismanName) moves here with the confidence of an old resident."
        case .none:
            return "\(territory.name) is quiet."
        }
    }
}

struct LabStatusCard: View {
    let report: LocalModelReport
    let storeReport: BookStore.Report
    let databaseReport: BookDatabase.Report
    let lastBraidDuration: TimeInterval?

    private var durationText: String {
        guard let lastBraidDuration else {
            return "no dry ink yet"
        }
        return "\(Int(lastBraidDuration.rounded()))s to dry"
    }

    private var archiveText: String {
        "\(storeReport.dayCount)d / \(storeReport.pageCount)p kept"
    }

    private var shelfStatusText: String {
        let backupText = databaseReport.backupCount > 0 ? " · \(databaseReport.backupCount) backup\(databaseReport.backupCount == 1 ? "" : "s")" : ""
        return "the shelves are holding · v\(databaseReport.schemaVersion) · \(databaseReport.loadSource.rawValue)\(backupText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(report.state == .ready ? "local brain awake" : "local brain dreaming", systemImage: report.state == .ready ? "checkmark.circle" : "hourglass")
                Spacer(minLength: 8)
                Label(durationText, systemImage: "timer")
            }

            HStack(spacing: 10) {
                Label(archiveText, systemImage: "archivebox")
                Spacer(minLength: 8)
                Label("today \(storeReport.todayPageCount)p", systemImage: "calendar")
            }

            if let lastError = databaseReport.lastError ?? storeReport.lastError {
                Text(lastError)
                    .lineLimit(2)
                    .foregroundStyle(.red.opacity(0.88))
            } else {
                Text(shelfStatusText)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}


struct BodySourceCard: View {
    let bodySignal: BodySourceSignal?
    let message: String
    let isRequesting: Bool
    let hasRequested: Bool
    let isAvailable: Bool
    let onRequest: () -> Void

    private var title: String {
        bodySignal == nil ? "Body Doorway" : "Body Page awake"
    }

    private var statusText: String {
        if let bodySignal {
            return bodySignal.status.capitalized
        }
        if !isAvailable {
            return "no doorway"
        }
        if isRequesting {
            return "listening"
        }
        return hasRequested ? "tap to listen again" : "door unopened"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: bodySignal == nil ? "heart.text.square" : "checkmark.seal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                }

                Spacer()

                if isRequesting {
                    ProgressView()
                        .tint(BookPalette.teal)
                } else {
                    Button {
                        onRequest()
                    } label: {
                        Image(systemName: bodySignal == nil ? "heart.circle" : "arrow.clockwise.circle")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.bookPress())
                    .foregroundStyle(BookPalette.teal)
                    .disabled(!isAvailable)
                    .accessibilityLabel(bodySignal == nil ? "Open the body doorway" : "Listen again")
                }
            }

            if let bodySignal {
                Text(bodySignal.phrase)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .parchmentSurface(accent: BookPalette.teal, isActive: bodySignal != nil)
    }
}

struct WeatherSourceCard: View {
    let weatherSignal: WeatherSourceSignal?
    let message: String
    let isRequesting: Bool
    let hasRequested: Bool
    let isAvailable: Bool
    let onRequest: () -> Void

    private var title: String {
        weatherSignal == nil ? "Weather Doorway" : "Weather Page awake"
    }

    private var statusText: String {
        if let weatherSignal {
            return weatherSignal.currentTemperature ?? "sky read"
        }
        if !isAvailable {
            return "no window"
        }
        if isRequesting {
            return "listening"
        }
        return hasRequested ? "tap to listen again" : "door unopened"
    }

    private var iconName: String {
        weatherSignal?.conditionSymbolName ?? "cloud.sun"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BookPalette.gold)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                }

                Spacer()

                if isRequesting {
                    ProgressView()
                        .tint(BookPalette.teal)
                } else {
                    Button {
                        onRequest()
                    } label: {
                        Image(systemName: weatherSignal == nil ? "location.circle" : "arrow.clockwise.circle")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.bookPress())
                    .foregroundStyle(BookPalette.teal)
                    .disabled(!isAvailable)
                    .accessibilityLabel(weatherSignal == nil ? "Open the weather doorway" : "Listen to the sky again")
                }
            }

            if let weatherSignal {
                Text(weatherSignal.phrase)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .parchmentSurface(accent: BookPalette.gold, isActive: weatherSignal != nil)
    }
}

struct AnchorSourceCard: View {
    let proximity: AnchorProximity?
    let message: String
    let isChecking: Bool
    let hasRequested: Bool
    let isAvailable: Bool
    let onRequest: () -> Void

    private var title: String {
        proximity == nil ? "Outer Stacks Doorway" : "Anchor awake"
    }

    private var statusText: String {
        if let proximity {
            return "\(Int(proximity.distanceMeters.rounded()))m · \(proximity.anchor.kind.title)"
        }
        if !isAvailable {
            return "no ley reading"
        }
        if isChecking {
            return "listening"
        }
        return hasRequested ? "tap to check again" : "door unopened"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                }

                Spacer()

                if isChecking {
                    ProgressView()
                        .tint(BookPalette.teal)
                } else {
                    Button {
                        onRequest()
                    } label: {
                        Image(systemName: proximity == nil ? "location.magnifyingglass" : "arrow.clockwise.circle")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.bookPress())
                    .foregroundStyle(BookPalette.teal)
                    .disabled(!isAvailable)
                    .accessibilityLabel(proximity == nil ? "Check nearby Anchors" : "Check nearby Anchors again")
                }
            }

            if let proximity {
                Text(proximity.anchor.name)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .parchmentSurface(accent: BookPalette.teal, isActive: proximity != nil)
    }
}

struct StoryFieldStatusCard: View {
    let surface: SurfacePage?
    let events: [NarrativeEvent]
    let isPreparing: Bool

    private var metadata: [String: String] {
        surface?.payload.metadata ?? [:]
    }

    private var hasPreparedPage: Bool {
        metadata["storyScene"]?.nonEmpty != nil
    }

    private var title: String {
        hasPreparedPage ? "Story Page ready" : "Story Field"
    }

    private var statusText: String {
        if isPreparing {
            return "ink moving"
        }
        if hasPreparedPage {
            return "page waiting"
        }
        if surface != nil {
            return "packet chosen"
        }
        return "listening"
    }

    private var packetText: String {
        guard let packetID = metadata["packetID"]?.nonEmpty else {
            return "no packet chosen yet"
        }
        return "packet \(String(packetID.prefix(8)))"
    }

    private var bookGlowText: String {
        let glow = metadata["bookGlow"]?.nonEmpty ?? metadata["playerBelief"]?.nonEmpty
        return glow.map { "glow \($0)" } ?? "glow unread"
    }

    private var threads: [String] {
        metadataList("selectedThreads")
    }

    private var entities: [String] {
        metadataList("selectedEntities")
    }

    private var relationships: [String] {
        metadataList("selectedRelationships")
    }

    private var signals: [String] {
        metadataLines("realSignals")
    }

    private var pressures: [String] {
        metadataLines("relationshipPressures")
    }

    private var recentChoiceEvents: [NarrativeEvent] {
        Array(events
            .filter { $0.kind == .choiceSelected || $0.sourcePageType == .narrativeOS }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BookPalette.violet)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                }

                Spacer()

                if isPreparing {
                    ScribeInkMeter(accent: BookPalette.violet, reduceMotion: true)
                        .frame(width: 98)
                        .accessibilityLabel("The Story Page is taking ink")
                } else {
                    Text(bookGlowText)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(BookPalette.violet)
                }
            }

            Text(statusBody)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                StoryFieldDebugLine(icon: "number", label: "packet", value: packetText)
                if let proseStatus = metadata["proseStatus"]?.nonEmpty {
                    StoryFieldDebugLine(icon: "pencil.and.scribble", label: "ink", value: proseStatus)
                }
                if !threads.isEmpty {
                    StoryFieldDebugLine(icon: "point.3.connected.trianglepath.dotted", label: "thread", value: threads.prefix(2).joined(separator: " / "))
                }
                if !entities.isEmpty {
                    StoryFieldDebugLine(icon: "person.text.rectangle", label: "entities", value: entities.prefix(3).joined(separator: ", "))
                }
                if !relationships.isEmpty {
                    StoryFieldDebugLine(icon: "arrow.triangle.branch", label: "ties", value: relationships.prefix(2).joined(separator: ", "))
                }
            }

            if !signals.isEmpty || !pressures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(signals.prefix(2).enumerated()), id: \.offset) { _, signal in
                        Text(signal)
                            .storyFieldSmallText()
                    }
                    ForEach(Array(pressures.prefix(1).enumerated()), id: \.offset) { _, pressure in
                        Text(pressure)
                            .storyFieldSmallText()
                    }
                }
            }

            if !recentChoiceEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("recent turns")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.54))
                    ForEach(recentChoiceEvents, id: \.id) { event in
                        Text(event.summary)
                            .storyFieldSmallText()
                    }
                }
            }
        }
        .padding(16)
        .parchmentSurface(accent: BookPalette.violet, isActive: surface != nil || isPreparing)
    }

    private var statusBody: String {
        if hasPreparedPage {
            return "The next Story Page has enough weight to open."
        }
        if surface != nil {
            return "I've chosen what the next Story Page will be about."
        }
        return "I haven't laid a Story Page in the margin yet."
    }

    private func metadataList(_ key: String) -> [String] {
        metadata[key]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private func metadataLines(_ key: String) -> [String] {
        metadata[key]?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }
}

private struct StoryFieldDebugLine: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.5))
                .frame(width: 18)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.52))
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .lineLimit(2)
        }
    }
}

struct StatusBanner: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(.footnote.weight(.bold))
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.nightPanel.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)
    }
}

/// A transient message laid across the Book instead of floating in app chrome.
/// It keeps the same action contract as `StatusBanner`; only its material home
/// changes on the compact Book workspace.
struct BookStatusSlip: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Text(message)
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .lineLimit(5)
                    .minimumScaleFactor(0.88)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.black))
                            .foregroundStyle(BookPalette.ink.opacity(0.48))
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tuck this note away")
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.footnote.weight(.bold))
                    .buttonStyle(.bookPress())
                    .foregroundStyle(BookPalette.violet)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(BookPalette.page)
                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.20)
                    .blendMode(.multiply)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 0.8)
        }
        .rotationEffect(.degrees(-0.55))
        .shadow(color: .black.opacity(0.33), radius: 7, x: 1, y: 5)
        .accessibilityElement(children: .contain)
    }
}

struct BeliefScoreBadge: View {
    let score: Int
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var pop = false
    @State private var inkBurstTrigger = 0

    private var clampedScore: Int {
        min(100, max(0, score))
    }

    private var normalized: Double {
        Double(clampedScore) / 100
    }

    private var tierName: String {
        BeliefLexicon.glowName(for: clampedScore)
    }

    private var glowRadius: CGFloat {
        4 + normalized * 18
    }

    private var glowOpacity: Double {
        0.22 + normalized * 0.48
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.caption.weight(.bold))
                .symbolEffect(.pulse, options: .speed(0.55), value: isBreathing && !isPaused)

            Text(tierName)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(BookPalette.lampGold)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(minWidth: 86, maxWidth: 132)
        .background(
            Capsule(style: .continuous)
                .fill(BookPalette.nightPanel.opacity(0.72))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.34 + normalized * 0.38), lineWidth: 1)
        }
        .shadow(
            color: BookPalette.lampGold.opacity(glowOpacity * (isBreathing ? 1.0 : 0.62)),
            radius: glowRadius * (isBreathing ? 1.08 : 0.78),
            x: 0,
            y: 0
        )
        .overlay {
            LivingInkBurst(
                trigger: inkBurstTrigger,
                text: tierName,
                mood: .belief,
                intensity: 0.42,
                isPaused: isPaused
            )
            .frame(width: 154, height: 78)
        }
        .scaleEffect(isBreathing && !reduceMotion && !isPaused ? 1.025 : 1.0)
        .animation(
            reduceMotion || isPaused ? nil : .easeInOut(duration: 2.4 - normalized * 0.7).repeatForever(autoreverses: true),
            value: isBreathing
        )
        .scaleEffect(pop && !reduceMotion && !isPaused ? 1.18 : 1.0)
        .onAppear {
            guard !reduceMotion && !isPaused else { return }
            isBreathing = true
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                isBreathing = false
                pop = false
            } else if !reduceMotion {
                isBreathing = true
            }
        }
        .onChange(of: score) { _, _ in
            BookFeedback.play(.keepPage)
            if !isPaused {
                inkBurstTrigger += 1
            }
            guard !reduceMotion && !isPaused else { return }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.45)) {
                pop = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    pop = false
                }
            }
        }
        .accessibilityLabel("My Glow is \(tierName.lowercased())")
        .help("My Glow is \(tierName.lowercased())")
    }
}

struct GlowEntityMenuItem: Identifiable, Equatable {
    var id: String
    var name: String
    var kind: String
    var glow: Int
    var line: String

    var glowName: String {
        BeliefLexicon.glowName(for: glow)
    }
}

struct GlowPageMenuItem: Identifiable, Equatable {
    var id: String
    var type: BookPageType
    var sourceID: String
    var title: String
    var detail: String
    var symbolName: String
    var glow: Int
    var narrativeWeight: Int

    var glowName: String {
        BeliefLexicon.glowName(for: glow)
    }

    var curationWeight: Int {
        glow + narrativeWeight
    }
}

struct GlowBookSectionMenuItem: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
}

struct GlowEnchantmentMenuItem: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
}

enum GlowBeliefMode {
    case give
    case take
}

enum GlowMenuAction {
    case giveBelief(GlowEntityMenuItem)
    case takeBelief(GlowEntityMenuItem)
    case givePageBelief(GlowPageMenuItem)
    case takePageBelief(GlowPageMenuItem)
    case spellCompass
    case openAlmanac
    case openEnchantment(GlowEnchantmentMenuItem)
    case openPage(BookPageType)
    case openFlyleaf
    case openPlayfulMission
    case openBookSection(String)
    case openPagewright
    case bindWeeklyIssue
    case rebindWeeklyIssue
    case bindMonthlyEdition
    case bindAnnualEdition
    case exportPlainInk
    case exportSealedCopy
    case openSubscriptions
    case openPrintStudio
    case publishSeasonalVolume
    case openBookShop
    case openPactMap
    case openPeopleOfTheBook
}

private enum GlowMenuSection: String, CaseIterable, Identifiable {
    case bindery
    case pages
    case belief
    case spells
    case book

    var id: String { rawValue }

    var title: String {
        switch self {
        case .belief:
            return "The Cast"
        case .spells:
            return "Spells"
        case .pages:
            return "Pages"
        case .bindery:
            return "The Bindery"
        case .book:
            return "Book"
        }
    }

    var subtitle: String {
        switch self {
        case .belief:
            return "Visit the people currently alive in the margins."
        case .spells:
            return "Open a Compass Run or Enchantment."
        case .pages:
            return "Find open threads and Pages tucked deeper in the binding."
        case .bindery:
            return "Make, share, print, and preserve kept pages."
        case .book:
            return "Read the Wonder Compass source."
        }
    }

    var symbolName: String {
        switch self {
        case .belief:
            return "sparkle.magnifyingglass"
        case .spells:
            return "wand.and.stars"
        case .pages:
            return "book.pages"
        case .bindery:
            return "books.vertical.fill"
        case .book:
            return "book.closed"
        }
    }

    var assetName: String {
        switch self {
        case .belief:
            return "MarginaliaLavender"
        case .spells:
            return "MarginaliaCompass"
        case .pages:
            return "MarginaliaScrap"
        case .bindery:
            return "MarginaliaSeal"
        case .book:
            return "MarginaliaStar"
        }
    }

    var rowOffset: CGFloat {
        switch self {
        case .bindery:
            return 164
        case .pages:
            return 242
        case .belief:
            return 320
        case .spells:
            return 398
        case .book:
            return 476
        }
    }

}

struct GlowCommandMenu: View {
    let score: Int
    let surfaceCount: Int
    let capturedPageCount: Int
    let entities: [GlowEntityMenuItem]
    let pageTypes: [GlowPageMenuItem]
    let bookSections: [GlowBookSectionMenuItem]
    let enchantments: [GlowEnchantmentMenuItem]
    let canBindWeeklyIssue: Bool
    let canBindMonthlyEdition: Bool
    let preparedPagewrightPDFURL: URL?
    let preparedWeeklyIssueCardURL: URL?
    let preparedWeeklyIssuePDFURL: URL?
    let preparedMonthlyEditionURL: URL?
    let preparedAnnualEditionURL: URL?
    let preparedPlainInkURL: URL?
    let preparedSaveFileURL: URL?
    let initialSectionID: String?
    let onCreateCastMember: () -> Void
    let onClose: () -> Void
    let onSelectAction: (GlowMenuAction) -> Void
    /// What the Book named this reader. The Glow panel is the one surface the
    /// reader opens deliberately to ask "what am I to you", so the role lives
    /// here rather than in the toolbar, which has no room for it.
    var readerRole: ComposedRole?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSection: GlowMenuSection?
    @State private var isRoleSeatPresented = false
    @State private var isRoleDossierExpanded = false
    @State private var beliefMode: GlowBeliefMode = .give
    @State private var selectedEntity: GlowEntityMenuItem?
    @State private var selectedPage: GlowPageMenuItem?
    @State private var isLit = false

    private var tierName: String {
        BeliefLexicon.glowName(for: score)
    }

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(430, max(294, proxy.size.width * 0.76))
            let panelTop = max(proxy.safeAreaInsets.top + 58, 82)
            // The crest and the role seat sit above the panel inside the same
            // stack, so the panel can only have what they leave behind. Budget
            // for them explicitly: an expanded dossier shrinks the panel, which
            // has its own scroll view, rather than shoving the whole stack off
            // the top of the screen.
            let headerChrome: CGFloat = 74
            // The four-pointed star rises 23pt above the panel while the Glow
            // pill and role seat are visually nudged downward. Give the star a
            // channel of its own so neither surface can cover its tap target.
            let starClearanceChrome: CGFloat = 40
            let roleChrome: CGFloat = readerRole == nil || !isRoleSeatPresented
                ? 0
                : (isRoleDossierExpanded ? 196 : 78)
            let availableHeight = proxy.size.height - panelTop - headerChrome - roleChrome - starClearanceChrome - 22
            let panelHeight = max(260, min(availableHeight, selectedSection == nil ? 555 : 720))
            let isCompact = proxy.size.width < 720
            let submenuWidth = isCompact ? panelWidth - 28 : min(280, max(232, panelWidth * 0.68))
            let submenuTop = panelTop + (selectedSection?.rowOffset ?? 0) + 44
            let submenuTrailing = isCompact ? 26 : panelWidth + 22

            ZStack {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                ambientRings
                    .allowsHitTesting(false)
            }
            // Give both presentation layers the GeometryReader's actual
            // viewport. The scrim can paint outside its layout bounds because
            // it ignores the safe area; using that painted area as the panel's
            // alignment reference can leave the dimmer visible while the menu
            // itself is laid out beyond the screen.
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .topTrailing) {
                // Anchored by its top, not centred on the panel. A disclosure
                // grows downward, and the reader-role seat gets real vertical
                // room instead of moving the whole menu above the screen.
                VStack(spacing: 0) {
                    headerBadge
                        .frame(width: min(250, panelWidth * 0.72))
                        .offset(y: 12)
                        .zIndex(3)

                    if isRoleSeatPresented {
                        roleSeat
                            .frame(width: min(320, panelWidth * 0.86))
                            .offset(y: 14)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .move(edge: .top).combined(with: .opacity)
                            )
                            .zIndex(3)
                    }

                    Color.clear
                        .frame(height: starClearanceChrome)
                        .accessibilityHidden(true)

                    mainPanel(width: panelWidth, height: panelHeight)
                }
                .frame(width: panelWidth)
                .padding(.top, panelTop)
                .padding(.trailing, 14)
            }
            .overlay {
                if let selectedSection, !isCompact {
                    submenu(width: submenuWidth, section: selectedSection)
                        .position(
                            x: proxy.size.width - (submenuWidth / 2) - submenuTrailing,
                            y: submenuTop + 58
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.86, anchor: .trailing)
                                .combined(with: .move(edge: .trailing))
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .onAppear {
            if let initialSectionID,
               let initialSection = GlowMenuSection(rawValue: initialSectionID) {
                selectedSection = initialSection
            }
            BookFeedback.play(.sourceRefresh)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isLit = true
            }
        }
        .onChange(of: initialSectionID) { _, sectionID in
            guard let sectionID,
                  let section = GlowMenuSection(rawValue: sectionID) else { return }
            withAnimation(BookMotion.reveal(reduceMotion)) {
                selectedSection = section
            }
        }
    }

    private func mainPanel(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 7) {
            crest

            VStack(spacing: 5) {
                Text(tierName)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(BookPalette.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)

                Text("The current belief state is steady\nand gently luminous.")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(GlowMenuSection.allCases) { section in
                        glowMenuRow(section)
                        if selectedSection == section {
                            inlineSubmenu(section)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 30)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 13)
        .padding(.bottom, 10)
        .frame(width: width, height: height)
        .background {
            outerFrame
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            closeSeal
                .offset(x: -20, y: 18)
        }
        .overlay(alignment: .top) {
            topNotch
                .offset(y: -23)
        }
        .shadow(color: .black.opacity(0.50), radius: 30, x: 0, y: 20)
    }

    private var headerBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.headline.weight(.bold))
            Text(tierName)
                .font(.headline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(BookPalette.lampGold)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(BookPalette.nightPanel.opacity(0.96), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.72), lineWidth: 1)
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 3)
                .padding(4)
        }
        .shadow(color: BookPalette.lampGold.opacity(isLit ? 0.62 : 0.26), radius: isLit ? 18 : 8)
    }

    /// The reader's name, where they can actually look it up. Tapping opens the
    /// dossier: a role you cannot re-read is a personality-quiz result you
    /// closed once, which is the failure this whole design exists to avoid.
    @ViewBuilder
    private var roleSeat: some View {
        if let readerRole {
            Button {
                BookFeedback.play(.select)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    isRoleDossierExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(readerRole.fullName)
                                .font(.system(.subheadline, design: .serif).weight(.bold))
                                .foregroundStyle(BookPalette.lampGold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                            if let hands = readerRole.hands {
                                Text(hands.name)
                                    .font(.system(size: 10, weight: .black))
                                    .tracking(0.5)
                                    .foregroundStyle(BookPalette.teal)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isRoleDossierExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BookPalette.lampGold.opacity(0.6))
                    }

                    if isRoleDossierExpanded {
                        Text(readerRole.role.dossier)
                            .font(.system(.footnote, design: .serif))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Label(
                            "\(readerRole.role.patronName) keeps an eye on you",
                            systemImage: "person.crop.circle"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.teal.opacity(0.9))
                    } else {
                        Text(readerRole.role.gloss)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.nightPanel.opacity(0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("You are \(readerRole.signature). \(readerRole.role.gloss)")
            .accessibilityHint(isRoleDossierExpanded ? "Collapse the dossier" : "Read the full dossier")
        }
    }

    private var crest: some View {
        Color.clear
        .frame(height: 32)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private func glowMenuRow(_ section: GlowMenuSection) -> some View {
        let isSelected = section == selectedSection

        return Button {
            BookFeedback.play(.select)
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                selectedSection = selectedSection == section ? nil : section
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Image("ParchmentFiber")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.42)
                    Image(section.assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(section == .book ? 7 : 6)
                        .opacity(isSelected ? 0.96 : 0.76)
                        .shadow(color: BookPalette.lampGold.opacity(0.22), radius: 7)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(isSelected ? 0.58 : 0.22), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(section.subtitle)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.38))
                    .rotationEffect(.degrees(isSelected ? 90 : 0))
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BookPalette.paper.opacity(isSelected ? 0.99 : 0.92),
                                BookPalette.page.opacity(isSelected ? 0.96 : 0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(isSelected ? 0.20 : 0.10), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(isSelected && !reduceMotion ? 1.012 : 1)
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel("\(section.title). \(section.subtitle)")
    }

    private func inlineSubmenu(_ section: GlowMenuSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(section.title, systemImage: section.symbolName)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                Spacer()
                Text("\(surfaceCount) rising · \(capturedPageCount) kept")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }

            submenuContent(section: section, compact: true)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookPalette.page.opacity(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.34), lineWidth: 1)
        }
        .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
    }

    private func submenu(width: CGFloat, section: GlowMenuSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(section.title, systemImage: section.symbolName)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.ink.opacity(0.64))
                Spacer()
                Text("\(surfaceCount) rising · \(capturedPageCount) kept")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }

            ScrollView(.vertical, showsIndicators: true) {
                submenuContent(section: section, compact: false)
            }
            .frame(maxHeight: 500)
        }
        .padding(12)
        .frame(width: width)
        .background {
            ZStack {
                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.22)
                BookPalette.page.opacity(0.96)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.36), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        .id(section.id)
    }

    @ViewBuilder
    private func submenuContent(section: GlowMenuSection, compact: Bool) -> some View {
        switch section {
        case .belief:
            beliefSubmenu(compact: compact)
        case .spells:
            menuButton(
                title: "Compass Run",
                detail: "Start a Compass Run Page.",
                systemImage: "safari",
                compact: compact
            ) {
                onSelectAction(.spellCompass)
            }
            menuButton(
                title: "The Living Almanac",
                detail: "Open the door on whatever temporary weather has got into me.",
                systemImage: "calendar.badge.clock",
                compact: compact
            ) {
                onSelectAction(.openAlmanac)
            }
            Text("Enchantment")
                .font(.caption2.weight(.black))
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .padding(.top, 2)
            ForEach(enchantments) { enchantment in
                menuButton(
                    title: enchantment.title,
                    detail: enchantment.detail,
                    systemImage: "wand.and.stars",
                    compact: compact
                ) {
                    onSelectAction(.openEnchantment(enchantment))
                }
            }
        case .pages:
            ForEach(GlowPagesMenuLayout.orderedSections, id: \.self) { item in
                switch item {
                case .flyleaf:
                    menuButton(
                        title: "The Flyleaf",
                        detail: "All the quests, favors, runs, bargains, and errands currently tucked into me.",
                        systemImage: "bookmark.fill",
                        compact: compact
                    ) {
                        onSelectAction(.openFlyleaf)
                    }
                case .playfulMission:
                    menuButton(
                        title: "Playful Mission",
                        detail: "Let one small piece of mischief loose in the ordinary world.",
                        systemImage: "figure.play",
                        compact: compact
                    ) {
                        onSelectAction(.openPlayfulMission)
                    }
                case .pageBelief:
                    pageBeliefSubmenu(compact: compact)
                case .pactMap:
                    menuButton(
                        title: "The Pact Map",
                        detail: "See where the Talismans have been leaving fingerprints on me.",
                        systemImage: "map",
                        compact: compact
                    ) {
                        onSelectAction(.openPactMap)
                    }
                }
            }
        case .bindery:
            binderySubmenu(compact: compact)
        case .book:
            ForEach(bookSections) { section in
                menuButton(
                    title: section.title,
                    detail: section.detail,
                    systemImage: "text.book.closed",
                    compact: compact
                ) {
                    onSelectAction(.openBookSection(section.id))
                }
            }
        }
    }

    private func binderySubmenu(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "Subscriptions",
                detail: "See what is standing, open either order, or stop one without hunting for the way out.",
                systemImage: "seal",
                compact: compact
            ) {
                onSelectAction(.openSubscriptions)
            }

            menuButton(
                title: "Publish a Seasonal Volume",
                detail: "Gather the latest finished three-month season and open it at the press.",
                systemImage: "leaf.fill",
                compact: compact
            ) {
                onSelectAction(.publishSeasonalVolume)
            }

            if let preparedPagewrightPDFURL {
                shareMenuButton(
                    title: "Share Last Scrapbook Page",
                    detail: "The latest Pagewright PDF is ready for Apple's share sheet.",
                    systemImage: "square.and.arrow.up",
                    url: preparedPagewrightPDFURL,
                    compact: compact
                )
            }

            menuButton(
                title: "Scrapbook a Page",
                detail: "Choose kept pages and bind a Scrap, Pocket, Issue, or Letter PDF.",
                systemImage: "scissors",
                compact: compact
            ) {
                onSelectAction(.openPagewright)
            }

            weeklyIssueBinderyActions(compact: compact)

            binderyExportButton(
                preparedURL: preparedMonthlyEditionURL,
                shareTitle: "Share Monthly Edition",
                bindTitle: "Bind Monthly Edition",
                detail: "The current chapter of kept pages, bound as a PDF.",
                systemImage: "book.pages",
                compact: compact,
                canBind: canBindMonthlyEdition,
                bindAction: .bindMonthlyEdition
            )

            binderyExportButton(
                preparedURL: preparedAnnualEditionURL,
                shareTitle: "Share Annual Volume",
                bindTitle: "Bind Annual Volume",
                detail: "A year of chapters gathered into one book.",
                systemImage: "books.vertical",
                compact: compact,
                canBind: true,
                bindAction: .bindAnnualEdition
            )

            binderyExportButton(
                preparedURL: preparedPlainInkURL,
                shareTitle: "Share Plain Ink",
                bindTitle: "Copy Out Plain Ink",
                detail: "Every kept page as ordinary Markdown text.",
                systemImage: "doc.plaintext",
                compact: compact,
                canBind: true,
                bindAction: .exportPlainInk
            )

            binderyExportButton(
                preparedURL: preparedSaveFileURL,
                shareTitle: "Share Sealed Copy",
                bindTitle: "Seal a Copy",
                detail: "A full local backup of me: pages, photos, and continuity.",
                systemImage: "book.closed",
                compact: compact,
                canBind: true,
                bindAction: .exportSealedCopy
            )

            menuButton(
                title: "Print Studio",
                detail: "Open the press directly for proof files and physical bindings.",
                systemImage: "printer",
                compact: compact
            ) {
                onSelectAction(.openPrintStudio)
            }
        }
    }

    @ViewBuilder
    private func weeklyIssueBinderyActions(compact: Bool) -> some View {
        let hasBoundIssue = preparedWeeklyIssuePDFURL != nil || preparedWeeklyIssueCardURL != nil

        menuButton(
            title: hasBoundIssue ? "Read Weekly Issue" : "Bind Weekly Issue",
            detail: canBindWeeklyIssue
                ? (hasBoundIssue
                    ? "Open the issue itself; sharing lives beside the reading copy."
                    : "Wait for me to finish writing, then open the issue in-app.")
                : "Not enough kept pages are ready for this binding yet.",
            systemImage: hasBoundIssue ? "book" : "newspaper",
            compact: compact,
            isDisabled: !canBindWeeklyIssue
        ) {
            onSelectAction(.bindWeeklyIssue)
        }

        if hasBoundIssue {
            menuButton(
                title: "Re-bind Weekly Issue",
                detail: "Write and bind the week again before replacing the reading copy.",
                systemImage: "arrow.triangle.2.circlepath",
                compact: compact,
                isDisabled: !canBindWeeklyIssue
            ) {
                onSelectAction(.rebindWeeklyIssue)
            }

            if let preparedWeeklyIssuePDFURL {
                shareMenuButton(
                    title: "Share Weekly Issue PDF",
                    detail: "Share the complete reading edition.",
                    systemImage: "doc.richtext",
                    url: preparedWeeklyIssuePDFURL,
                    compact: compact
                )
            }

            if let preparedWeeklyIssueCardURL {
                shareMenuButton(
                    title: "Share Weekly Social Card",
                    detail: "Share the compact illustrated wrap.",
                    systemImage: "photo",
                    url: preparedWeeklyIssueCardURL,
                    compact: compact
                )
            }
        }
    }

    private func pageBeliefSubmenu(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Page belief action", selection: $beliefMode) {
                Text("Warm this Page").tag(GlowBeliefMode.give)
                Text("Let it quiet").tag(GlowBeliefMode.take)
            }
            .pickerStyle(.segmented)

            menuButton(
                title: "The BookShop",
                detail: "The Marginalia Goblins' living market, where the till has opinions and the shelves remember you.",
                systemImage: "books.vertical.fill",
                compact: compact
            ) {
                onSelectAction(.openBookShop)
            }

            ForEach(pageTypes) { page in
                Button {
                    BookFeedback.play(.select)
                    selectedPage = page
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.lampGold)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(page.title)
                                .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                                .foregroundStyle(BookPalette.ink)
                            Text(page.detail)
                                .font(compact ? .caption2 : .caption)
                                .foregroundStyle(BookPalette.ink.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(page.glowName)
                                .font(.caption2.weight(.black))
                                .foregroundStyle(BookPalette.teal)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, compact ? 10 : 12)
                    .padding(.vertical, compact ? 8 : 10)
                    .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel("\(page.title), \(page.glowName)")
            }
        }
        .confirmationDialog(
            selectedPage.map { confirmationTitle(for: $0) } ?? "Move Page Belief?",
            isPresented: Binding(
                get: { selectedPage != nil },
                set: { if !$0 { selectedPage = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let selectedPage {
                Button("Open \(selectedPage.title)") {
                    onSelectAction(.openPage(selectedPage.type))
                    self.selectedPage = nil
                }
                Button(confirmationButtonTitle(for: selectedPage), role: beliefMode == .take ? .destructive : nil) {
                    let action: GlowMenuAction = beliefMode == .give
                        ? .givePageBelief(selectedPage)
                        : .takePageBelief(selectedPage)
                    onSelectAction(action)
                    self.selectedPage = nil
                }
            }
            Button("Cancel", role: .cancel) {
                selectedPage = nil
            }
        }
    }

    private func beliefSubmenu(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "The People of the Book",
                detail: "Real people from your days: who they are, when they went quiet, and (if you choose) into the story.",
                systemImage: "person.2.wave.2",
                compact: compact
            ) {
                onSelectAction(.openPeopleOfTheBook)
            }

            Picker("Belief action", selection: $beliefMode) {
                Text("Brighten").tag(GlowBeliefMode.give)
                Text("Let rest").tag(GlowBeliefMode.take)
            }
            .pickerStyle(.segmented)

            Button {
                onCreateCastMember()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(BookPalette.violet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Invite a new Cast Member")
                            .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Text("State what it is, or give me a photo.")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.38))
                }
                .padding(.horizontal, compact ? 10 : 12)
                .padding(.vertical, compact ? 8 : 10)
                .background(BookPalette.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.violet.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(.bookPress())
            .accessibilityLabel("Invite a new Cast Member")

            ForEach(entities) { entity in
                Button {
                    BookFeedback.play(.select)
                    selectedEntity = entity
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entity.name)
                                .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                                .foregroundStyle(BookPalette.ink)
                            Text(entity.line)
                                .font(compact ? .caption2 : .caption)
                                .foregroundStyle(BookPalette.ink.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Text(entity.glowName)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BookPalette.teal)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, compact ? 10 : 12)
                    .padding(.vertical, compact ? 8 : 10)
                    .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel("\(entity.name), \(entity.glowName)")
            }
        }
        .confirmationDialog(
            selectedEntity.map { confirmationTitle(for: $0) } ?? "Move Belief?",
            isPresented: Binding(
                get: { selectedEntity != nil },
                set: { if !$0 { selectedEntity = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let selectedEntity {
                Button(confirmationButtonTitle(for: selectedEntity), role: beliefMode == .take ? .destructive : nil) {
                    let action: GlowMenuAction = beliefMode == .give
                        ? .giveBelief(selectedEntity)
                        : .takeBelief(selectedEntity)
                    onSelectAction(action)
                    self.selectedEntity = nil
                }
            }
            Button("Cancel", role: .cancel) {
                selectedEntity = nil
            }
        }
    }

    private func confirmationTitle(for entity: GlowEntityMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Brighten \(entity.name)?"
        case .take:
            return "Let \(entity.name) rest?"
        }
    }

    private func confirmationTitle(for page: GlowPageMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Warm \(page.title)?"
        case .take:
            return "Let \(page.title) quiet?"
        }
    }

    private func confirmationButtonTitle(for entity: GlowEntityMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Brighten \(entity.name)"
        case .take:
            return "Let the Glow recede"
        }
    }

    private func confirmationButtonTitle(for page: GlowPageMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Warm \(page.title)"
        case .take:
            return "Let \(page.title) quiet"
        }
    }

    private func menuButton(
        title: String,
        detail: String,
        systemImage: String,
        compact: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            BookFeedback.play(.openPage)
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(detail)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 8 : 10)
            .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isDisabled ? 0.48 : 1)
        }
        .buttonStyle(.bookPress())
        .disabled(isDisabled)
    }

    @ViewBuilder
    private func binderyExportButton(
        preparedURL: URL?,
        shareTitle: String,
        bindTitle: String,
        detail: String,
        systemImage: String,
        compact: Bool,
        canBind: Bool,
        bindAction: GlowMenuAction
    ) -> some View {
        if let preparedURL {
            shareMenuButton(
                title: shareTitle,
                detail: detail,
                systemImage: "square.and.arrow.up",
                url: preparedURL,
                compact: compact
            )
        } else {
            menuButton(
                title: bindTitle,
                detail: canBind ? detail : "Not enough kept pages are ready for this binding yet.",
                systemImage: systemImage,
                compact: compact,
                isDisabled: !canBind
            ) {
                onSelectAction(bindAction)
            }
        }
    }

    private func shareMenuButton(
        title: String,
        detail: String,
        systemImage: String,
        url: URL,
        compact: Bool
    ) -> some View {
        ShareLink(item: url) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(detail)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 8 : 10)
            .background(BookPalette.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.bookPress())
    }

    private var closeSeal: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(BookPalette.nightPanel)
                Circle()
                    .stroke(BookPalette.lampGold.opacity(0.72), lineWidth: 1.4)
                Image(systemName: "xmark")
                    .font(.headline.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
            }
            .frame(width: 54, height: 54)
            .shadow(color: .black.opacity(0.32), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel("Close Glow menu")
    }

    @ViewBuilder
    private var topNotch: some View {
        if readerRole != nil {
            Button(action: toggleRoleSeat) {
                topNotchArtwork
            }
            .buttonStyle(.bookPress())
            .accessibilityLabel(isRoleSeatPresented ? "Hide character sheet" : "Show character sheet")
            .accessibilityHint(
                isRoleSeatPresented
                    ? "Hides what the Book has named you."
                    : "Reveals what the Book has named you."
            )
        } else {
            topNotchArtwork
                .accessibilityHidden(true)
        }
    }

    private var topNotchArtwork: some View {
        ZStack {
            Circle()
                .fill(BookPalette.nightPanel)
                .frame(width: 74, height: 74)
            Circle()
                .stroke(BookPalette.lampGold.opacity(0.80), lineWidth: 1.5)
                .frame(width: 74, height: 74)
            Image(systemName: "sparkle")
                .font(.title.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)
                .shadow(color: BookPalette.lampGold.opacity(isLit ? 0.78 : 0.32), radius: isLit ? 14 : 7)
        }
    }

    private func toggleRoleSeat() {
        guard readerRole != nil else { return }
        BookFeedback.play(.select)
        withAnimation(BookMotion.reveal(reduceMotion)) {
            if isRoleSeatPresented {
                isRoleSeatPresented = false
                isRoleDossierExpanded = false
            } else {
                isRoleSeatPresented = true
            }
        }
    }

    private var outerFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(BookPalette.nightPanel)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.78), lineWidth: 1.4)

            ZStack {
                LinearGradient(
                    colors: [
                        BookPalette.paper,
                        BookPalette.page.opacity(0.99),
                        BookPalette.lampGold.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var ambientRings: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(BookPalette.lampGold.opacity(0.08), lineWidth: 1)
                    .frame(width: CGFloat(360 + index * 160), height: CGFloat(360 + index * 160))
                    .offset(x: 150, y: -180)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

struct BraidingStatusCard: View {
    let quip: String
    let startedAt: Date?

    var body: some View {
        LocalBrainWorkingStatusCard(
            label: "braid",
            quip: quip,
            startedAt: startedAt,
            presentation: .shelf
        )
    }
}

extension Color {
    /// "RRGGBB" → Color; the cast accent hexes live in Shared as plain strings
    /// because InsideCoverCore never imports SwiftUI.
    init(bookHex hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// The instant margin reply shown right after a page is kept: a cast member's
/// one-line note, echoing the keep before the surface retires.
struct KeepMarginNoteToast: View {
    let note: KeepMarginalia.Note
    var showsPressHint: Bool = false
    var announcementTitle: String? = nil
    /// Ordinary keeps get one vivid interruption: the cast member. Unlocks may
    /// still explain themselves here, while receipts settle into the faint
    /// trace after the interruption has gone.
    var showsAftermath: Bool = false

    private var voice: KeepMarginalia.Voice? { KeepMarginalia.voice(forSlug: note.castSlug) }
    private var accent: Color { voice.map { Color(bookHex: $0.accentHex) } ?? BookPalette.gold }
    private var speakerNameColor: Color { BookPalette.lampGold }
    private var rejoinderAccent: Color {
        note.rejoinderName
            .flatMap { name in KeepMarginalia.voices.first { $0.name == name } }
            .map { Color(bookHex: $0.accentHex) } ?? BookPalette.gold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let announcementTitle {
                Label(announcementTitle, systemImage: "theatermasks.fill")
                    .font(.caption.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(BookPalette.violet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let findingLine = note.findingLine {
                VStack(alignment: .leading, spacing: 4) {
                    Label("YOU FOUND IT", systemImage: "sparkles")
                        .font(.caption.weight(.black))
                        .foregroundStyle(BookPalette.lampGold)
                    Text(findingLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 2)
            }
            HStack(alignment: .top, spacing: 10) {
                Image(note.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(accent.opacity(voice == nil ? 0.35 : 0.6), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(note.castName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(speakerNameColor)
                        if let glyph = voice?.glyph {
                            Text(glyph)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(accent.opacity(0.85))
                        }
                    }
                    Text(note.line)
                        .font(.system(.subheadline, design: .serif))
                        .italic()
                        .foregroundStyle(BookPalette.nightText)
                        .fixedSize(horizontal: false, vertical: true)
                    if showsAftermath {
                        if let ripple = note.rippleLine {
                            Text(ripple)
                                .font(.caption2)
                                .foregroundStyle(BookPalette.lampGold.opacity(0.92))
                        }
                        if let carryOutLine = note.carryOutLine {
                            Label(carryOutLine, systemImage: "sparkle.magnifyingglass")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BookPalette.teal.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                        if let braidThreadLine = note.braidThreadLine {
                            Label(braidThreadLine, systemImage: "point.3.filled.connected.trianglepath.dotted")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BookPalette.lampGold.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            if let rejoinderLine = note.rejoinderLine,
               let rejoinderName = note.rejoinderName,
               let rejoinderAsset = note.rejoinderAsset {
                HStack(alignment: .top, spacing: 10) {
                    Image(rejoinderAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(rejoinderAccent.opacity(0.6), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rejoinderName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(speakerNameColor)
                        Text(rejoinderLine)
                            .font(.system(.subheadline, design: .serif))
                            .italic()
                            .foregroundStyle(BookPalette.nightText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
            }
            if showsAftermath && !note.consequenceLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("THE PAGE TOOK HOLD", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.black))
                        .tracking(0.65)
                        .foregroundStyle(BookPalette.teal)

                    ForEach(Array(note.consequenceLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
            }
            if showsPressHint {
                Text("Tap to press a souvenir card.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))
            }
        }
        .padding(12)
        // This note can land over anything from a quiet desk to a bright Page.
        // Keep its reading surface opaque so the underlying artwork never
        // changes the character's legibility.
        .background(BookPalette.nightPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

/// The faint echo the retired keep toast leaves tucked at the page edge: the
/// cast portrait plus one quiet receipt, dimmed, so the settled desk remembers
/// both the interruption and what took hold without holding a second toast.
struct KeepMarginTrace: View {
    let note: KeepMarginalia.Note

    private var voice: KeepMarginalia.Voice? { KeepMarginalia.voice(forSlug: note.castSlug) }
    private var accent: Color { voice.map { Color(bookHex: $0.accentHex) } ?? BookPalette.gold }
    private var settledLine: String? {
        note.consequenceLines.first
            ?? note.braidThreadLine
            ?? note.carryOutLine
            ?? note.rippleLine
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(note.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
                .overlay(Circle().stroke(accent.opacity(0.4), lineWidth: 1))
            if let glyph = voice?.glyph {
                Text(glyph)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent.opacity(0.7))
            }
            if let settledLine {
                Text(settledLine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: 260, alignment: .leading)
        .background(BookPalette.nightPanel.opacity(0.56), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(0.66)
        .accessibilityHidden(true)
    }
}

/// From 8pm, the desk's evening resolution: a braid teaser on kept days, a
/// lamplight note on unwritten ones.
struct BraidEmberStatusCard: View {
    let ember: BraidEmber.Ember

    private var symbolName: String {
        ember.kind == .lamplight ? "lamp.table.fill" : "flame.fill"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 16))
                .foregroundStyle(BookPalette.lampGold)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(ember.line)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.nightText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ember.undertone)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        )
    }
}

/// On weekends, reports which pages the Bindery has sewn into this month's
/// edition over the past week.
struct WeeklySignatureCard: View {
    let line: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 16))
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(line)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.nightText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Monthly Binding gathers its signatures.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        )
    }
}

enum ScribeWorkPresentation {
    case shelf
    case page
    case compact
}

private struct ScribeWorkDescriptor {
    let title: String
    let scribe: String
    let assetName: String
    let status: String
    let quip: String
    let accent: Color

    init(label: String) {
        let normalized = label.lowercased()
        switch normalized {
        case let value where value.contains("fae-parley"):
            let identity: (name: String, asset: String) = {
                if value.contains("sentencesalamander") { return ("Sentence Salamander", "LabyrinthFaeSentenceSalamander") }
                if value.contains("punctuationpixie") { return ("Punctuation Pixie", "LabyrinthFaePunctuationPixie") }
                if value.contains("deeploredwarf") { return ("Deep Lore Dwarf", "LabyrinthFaeDeepLoreDwarf") }
                if value.contains("goblin") { return ("Marginalia Goblin", "LabyrinthFaeMarginaliaGoblin") }
                if value.contains("literaryelf") { return ("Literary Elf", "LabyrinthFaeBookSprite") }
                return ("Book Sprite", "LabyrinthFaeBookSprite")
            }()
            self.init(
                title: "\(identity.name) is answering the parley",
                scribe: identity.name,
                assetName: identity.asset,
                status: "Your chosen wording is changing courtesy, Claim, and the next line.",
                quip: "Old law is exact about verbs. The Fae is deciding which one you earned.",
                accent: BookPalette.lampGold
            )
        case let value where value.contains("photo-illumination"):
            self.init(
                title: "The photograph is developing",
                scribe: "Penny Blackletter",
                assetName: "LabyrinthCharacterPennyBlackletter",
                status: "Reading only what the photograph gives her.",
                quip: "Light, texture, and the honest edges of the frame are taking ink.",
                accent: BookPalette.teal
            )
        case let value where value.contains("enchantment") || value.contains("everything-speaks"):
            self.init(
                title: value.contains("everything-speaks") ? "The subject is finding its voice" : "The Enchantment is taking hold",
                scribe: "Sentence Salamander",
                assetName: "LabyrinthFaeSentenceSalamander",
                status: "The spell and the photograph are staying on this device.",
                quip: "A bright sentence is testing the shape of the real thing.",
                accent: BookPalette.lampGold
            )
        case let value where value.contains("story-page-result") || value.contains("story-choice"):
            self.init(
                title: "Your choice is changing the scene",
                scribe: "Punctuation Pixie",
                assetName: "LabyrinthFaePunctuationPixie",
                status: "The consequence is being written into the living page.",
                quip: "The fork has been chosen. The ink is discovering what it cost.",
                accent: BookPalette.violet
            )
        case let value where value.contains("story-page") || value.contains("academy-class") || value.contains("book-jump"):
            self.init(
                title: "The next scene is taking ink",
                scribe: "Book Sprite",
                assetName: "LabyrinthFaeBookSprite",
                status: "I'm carrying your last choice forward.",
                quip: "The old thread is being tied to the next true sentence.",
                accent: BookPalette.violet
            )
        case let value where value.contains("ask-the-book"):
            self.init(
                title: "I'm reading your question",
                scribe: "Deep Lore Dwarf",
                assetName: "LabyrinthFaeDeepLoreDwarf",
                status: "Recent pages and remembered threads are being consulted.",
                quip: "Something useful is being carried up from the lower shelves.",
                accent: BookPalette.teal
            )
        case let value where value.contains("inkrest"):
            self.init(
                title: "Dr. Inkrest is reading with you",
                scribe: "Dr. Selene Inkrest",
                assetName: "LabyrinthCharacterDrSeleneInkrest",
                status: "Your sitting remains private and on this device.",
                quip: "She is leaving enough quiet around the part that matters.",
                accent: BookPalette.teal
            )
        case let value where value.contains("fae-bargain"):
            self.init(
                title: "The Fae is considering the exchange",
                scribe: "Marginalia Goblin",
                assetName: "LabyrinthFaeMarginaliaGoblin",
                status: "The sensory report is being weighed against the old terms.",
                quip: "The ledger is open. The detail, not the category, will decide it.",
                accent: BookPalette.lampGold
            )
        case let value where value.contains("bookshop-clerk") || value.contains("goblin-clerk"):
            self.init(
                title: "The clerk is composing a private opinion",
                scribe: "Marginalia Goblin",
                assetName: "LabyrinthFaeMarginaliaGoblin",
                status: "The stall, your standing, and the current mood are being consulted.",
                quip: "The clerk has rejected two perfectly serviceable compliments as insufficiently mercantile.",
                accent: BookPalette.lampGold
            )
        case let value where value.contains("wonder-compass") || value.contains("compass") || value.contains("playful-mission"):
            self.init(
                title: "The Compass is choosing a passage",
                scribe: "Punctuation Pixie",
                assetName: "LabyrinthFaePunctuationPixie",
                status: "Your constraints are becoming one small, finishable path.",
                quip: "The needle is refusing every adventure too large for today.",
                accent: BookPalette.teal
            )
        case let value where value.contains("stacks-search"):
            self.init(
                title: "The index is reading your question",
                scribe: "Deep Lore Dwarf",
                assetName: "LabyrinthFaeDeepLoreDwarf",
                status: "The search stays inside your private archive.",
                quip: "Names, moods, objects, and old weather are being cross-referenced.",
                accent: BookPalette.teal
            )
        case let value where value.contains("letter"):
            self.init(
                title: "The letter is opening",
                scribe: "Book Sprite",
                assetName: "LabyrinthFaeBookSprite",
                status: "The sender is finding the words that belong on this page.",
                quip: "The seal is warm. The last line is still deciding how honest to be.",
                accent: BookPalette.teal
            )
        case let value where value.contains("monthly-closing") || value.contains("edition"):
            self.init(
                title: "The month is receiving its last page",
                scribe: "Book Sprite",
                assetName: "LabyrinthFaeBookSprite",
                status: "The closing is being written from the pages already kept.",
                quip: "The binding thread is waiting for one final honest paragraph.",
                accent: BookPalette.lampGold
            )
        case let value where value.contains("gossip") || value.contains("bleed"):
            self.init(
                title: "The margins are comparing notes",
                scribe: "Marginalia Goblin",
                assetName: "LabyrinthFaeMarginaliaGoblin",
                status: "Clippings and remembered details are being set in order.",
                quip: "One source is being dramatic. The clerk has made a note of it.",
                accent: BookPalette.lampGold
            )
        case let value where value.contains("faculty") || value.contains("research") || value.contains("support-guild"):
            self.init(
                title: "The research desk is awake",
                scribe: "Deep Lore Dwarf",
                assetName: "LabyrinthFaeDeepLoreDwarf",
                status: "The faculty are reading the supplied evidence, not inventing a diagnosis.",
                quip: "Several careful notes are becoming one useful page.",
                accent: BookPalette.teal
            )
        case let value where value.contains("braid"):
            self.init(
                title: value.contains("rewrite") ? "The braid is being rewritten" : "The braid is taking ink",
                scribe: "Sentence Salamander",
                assetName: "LabyrinthFaeSentenceSalamander",
                status: "Today’s kept fragments are being braided on this device.",
                quip: "A ribbon is being tied around the ordinary without squeezing it flat.",
                accent: BookPalette.teal
            )
        default:
            self.init(
                title: "The local scribe is writing",
                scribe: "Book Sprite",
                assetName: "LabyrinthFaeBookSprite",
                status: "One private page is taking ink at a time.",
                quip: "The shelves are staying quiet so the sentence can land.",
                accent: BookPalette.violet
            )
        }
    }

    private init(title: String, scribe: String, assetName: String, status: String, quip: String, accent: Color) {
        self.title = title
        self.scribe = scribe
        self.assetName = assetName
        self.status = status
        self.quip = quip
        self.accent = accent
    }
}

struct LocalBrainWorkingStatusCard: View {
    let label: String
    var quip: String? = nil
    var startedAt: Date? = nil
    var queuedCount = 0
    var liveText: String? = nil
    var progressLine: String? = nil
    var presentation: ScribeWorkPresentation = .page

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activity: WaitActivity?
    @State private var loosePageSalt = 0
    @State private var radioManager = BookRadioManager.shared

    private var descriptor: ScribeWorkDescriptor { ScribeWorkDescriptor(label: label) }
    private var isCompact: Bool { presentation == .compact }
    private var livePreview: String? {
        liveText?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
    private var progressCaption: String? {
        progressLine?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private enum WaitActivity: String, CaseIterable {
        case loosePage
        case radio
        case reset

        var title: String {
            switch self {
            case .loosePage: return "Loose page"
            case .radio: return "Radio"
            case .reset: return "60-sec reset"
            }
        }

        var symbol: String {
            switch self {
            case .loosePage: return "book.pages"
            case .radio: return "radio"
            case .reset: return "circle.dotted"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 13) {
            HStack(alignment: .top, spacing: 12) {
                scribePortrait

                VStack(alignment: .leading, spacing: 5) {
                    Text("WRITING PRIVATELY ON THIS DEVICE")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                        .foregroundStyle(descriptor.accent)

                    Text(descriptor.title)
                        .font(isCompact ? .subheadline.weight(.bold) : .headline)
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    ScribeInkMeter(accent: descriptor.accent, reduceMotion: reduceMotion)

                    if !isCompact {
                        Text(descriptor.status)
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                if queuedCount > 0 {
                    Text("\(queuedCount) waiting")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(descriptor.accent)
                }
            }

            if !isCompact {
                if let livePreview {
                    liveInkPreview(livePreview)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Text(quip?.nonEmpty ?? descriptor.quip)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .id(quip)
                    .transition(.opacity)

                waitActivities

                Label("No cloud. This page and its private source material do not leave your device.", systemImage: "lock.shield")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("You can keep reading while the ink dries.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
            }
        }
        .padding(isCompact ? 12 : 16)
        .parchmentSurface(accent: descriptor.accent, isActive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(descriptor.scribe). \(descriptor.title). Writing privately on this device.")
    }

    private func liveInkPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label("Wet ink", systemImage: "text.cursor")
                    .font(.caption2.weight(.black))
                    .textCase(.uppercase)
                    .foregroundStyle(descriptor.accent)
                Spacer(minLength: 8)
                if let progressCaption {
                    Text(progressCaption)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.46))
                        .lineLimit(1)
                }
            }

            GhostInkText(text: text)
                .font(.system(.callout, design: .serif))
                .lineSpacing(3)
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .contentTransition(.opacity)
        }
        .waitActivitySurface(accent: descriptor.accent)
        .animation(.easeInOut(duration: 0.18), value: text.count)
    }

    private var scribePortrait: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(descriptor.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: isCompact ? 46 : 58, height: isCompact ? 46 : 58)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(descriptor.accent.opacity(0.52), lineWidth: 1)
                }

            Image(systemName: "pencil.and.scribble")
                .font(.caption2.weight(.black))
                .foregroundStyle(BookPalette.paper)
                .padding(5)
                .background(descriptor.accent, in: Circle())
        }
        .accessibilityHidden(true)
    }

    private var waitActivities: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHILE THE INK DRIES")
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .foregroundStyle(BookPalette.ink.opacity(0.48))

            HStack(spacing: 7) {
                ForEach(WaitActivity.allCases, id: \.rawValue) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activity = activity == option ? nil : option
                        }
                    } label: {
                        Label(option.title, systemImage: option.symbol)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(activity == option ? descriptor.accent : BookPalette.ink.opacity(0.62))
                }
            }

            if let activity {
                activityContent(activity)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func activityContent(_ activity: WaitActivity) -> some View {
        switch activity {
        case .loosePage:
            VStack(alignment: .leading, spacing: 8) {
                Text(loosePageText)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Turn the loose page") { loosePageSalt += 1 }
                    .font(.caption2.weight(.bold))
                    .buttonStyle(.bookPress())
                    .foregroundStyle(descriptor.accent)
            }
            .waitActivitySurface(accent: descriptor.accent)
        case .radio:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: radioManager.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                        .foregroundStyle(descriptor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(radioManager.isPlaying ? (radioManager.activeStation?.title ?? "ReEnchanted Radio") : "Let the Radio keep the room")
                            .font(.caption.weight(.bold))
                        Text(radioManager.isPlaying ? radioManager.statusLine : "Pick a station while the page writes.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.58))
                    }
                    Spacer()
                    if radioManager.isPlaying {
                        Button("Stop") { radioManager.stop() }
                            .font(.caption2.weight(.bold))
                            .buttonStyle(.bordered)
                            .tint(descriptor.accent)
                    }
                }

                let stations = RadioStationRegistry.stations(
                    unlockedPackIDs: Set(PlayerVault.shared.data.ownedPacks ?? [])
                )
                if !stations.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(stations) { station in
                            let isActive = radioManager.isPlaying
                                && radioManager.activeStation?.id == station.id
                            Button {
                                tuneStation(station.id)
                            } label: {
                                Text(station.title)
                                    .font(.caption2.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(isActive ? descriptor.accent : BookPalette.ink.opacity(0.62))
                        }
                    }
                }
            }
            .waitActivitySurface(accent: descriptor.accent)
        case .reset:
            resetView
        }
    }

    private var resetView: some View {
        BreathingMinuteView(accent: descriptor.accent, reduceMotion: reduceMotion, startImmediately: true)
            .waitActivitySurface(accent: descriptor.accent)
    }

    private var loosePageText: String {
        guard !LoosePageReader.fragments.isEmpty else {
            return "A blank leaf has been left here for the sentence that is still arriving."
        }
        return LoosePageReader.fragments[abs("scribe-wait-\(label)-\(loosePageSalt)".stableHash) % LoosePageReader.fragments.count]
    }

    private func tuneStation(_ stationID: String) {
        let unlocked = Set(PlayerVault.shared.data.ownedPacks ?? [])
        // Tapping the station that's already on the air turns the radio off.
        if radioManager.isPlaying, radioManager.activeStation?.id == stationID {
            radioManager.stop()
            return
        }
        radioManager.tune(stationID: stationID, unlockedPackIDs: unlocked)
    }
}

/// Observation boundary for live Gemma output. This deliberately forwards the
/// exact same text and progress caption to `LocalBrainWorkingStatusCard`; its
/// only job is to keep high-frequency progress invalidations inside this card.
struct LiveLocalBrainWorkingStatusCard: View {
    let progress: LocalBrainProgressViewState
    let label: String
    var quip: String? = nil
    var startedAt: Date? = nil
    var queuedCount = 0
    var presentation: ScribeWorkPresentation = .page

    var body: some View {
        LocalBrainWorkingStatusCard(
            label: label,
            quip: quip,
            startedAt: startedAt,
            queuedCount: queuedCount,
            liveText: progress.preview,
            progressLine: progress.progressLine,
            presentation: presentation
        )
    }
}

/// Preserves the shelf's existing one-time scroll when the first live preview
/// arrives without making the entire home view observe every Gemma snapshot.
struct LocalBrainPreviewStartObserver: View {
    let progress: LocalBrainProgressViewState
    let isWorking: Bool
    let onPreviewStart: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: progress.preview) { oldValue, newValue in
                guard isWorking,
                      oldValue?.nonEmpty == nil,
                      newValue?.nonEmpty != nil else { return }
                onPreviewStart()
            }
            .accessibilityHidden(true)
    }
}

private struct GhostInkText: View {
    let text: String

    var body: some View {
        // The model already streams. Re-typing the full accumulated preview at
        // 24 ms intervals multiplied each model update into dozens of text
        // layouts on MainActor, which was visible as sticky scrolling.
        Text(text)
    }
}

/// The 60-second "Do Nothing" minute from Wonder Compass Chapter 10: a single breathing
/// circle that counts one minute down while the chair holds your weight. Shared by the
/// scribe wait card and the Center Page. Optional, never a requirement.
struct BreathingMinuteView: View {
    var accent: Color
    var reduceMotion: Bool
    /// When true the minute begins the moment the view appears (used where opening this
    /// view is itself the "begin"). Otherwise a gentle start button shows first.
    var startImmediately: Bool = false
    /// An optional italic line revealed when the minute lands.
    var completionNote: String? = nil

    @State private var startedAt: Date?

    var body: some View {
        Group {
            if let startedAt {
                running(from: startedAt)
            } else {
                startButton
            }
        }
        .onAppear {
            if startImmediately, startedAt == nil {
                startedAt = Date()
            }
        }
    }

    private var startButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                startedAt = Date()
            }
        } label: {
            Label("Begin the minute", systemImage: "circle.dotted")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(accent)
    }

    private func running(from started: Date) -> some View {
        TimelineView(.periodic(from: started, by: 1)) { timeline in
            let elapsed = max(0, Int(timeline.date.timeIntervalSince(started)))
            let remaining = max(0, 60 - elapsed)
            let breathIn = (elapsed % 8) < 4
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(accent.opacity(breathIn ? 0.28 : 0.13))
                        .overlay { Circle().stroke(accent.opacity(0.56), lineWidth: 1) }
                        .frame(
                            width: breathIn && !reduceMotion ? 48 : 36,
                            height: breathIn && !reduceMotion ? 48 : 36
                        )
                        .animation(.easeInOut(duration: 1), value: breathIn)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leadLine(remaining: remaining, breathIn: breathIn))
                            .font(.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(remaining == 0 ? "Stay, read, or close the reset." : "\(remaining) seconds. Stay or bolt; the timer cannot chase you.")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BookPalette.ink.opacity(0.56))
                    }
                    Spacer(minLength: 0)
                }
                if remaining == 0, let completionNote {
                    Text(completionNote)
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func leadLine(remaining: Int, breathIn: Bool) -> String {
        if remaining == 0 { return "The minute is yours." }
        return breathIn
            ? "Breathe in, without improving anything."
            : "Breathe out. Let the chair hold your weight."
    }
}

private struct ScribeInkMeter: View {
    let accent: Color
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            bars(tick: 0, isActive: false)
        } else {
            TimelineView(.periodic(from: .now, by: 0.8)) { timeline in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.8)
                bars(tick: tick, isActive: true)
                    .animation(.easeInOut(duration: 0.35), value: tick)
            }
        }
    }

    private func bars(tick: Int, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(accent.opacity(index == tick % 4 && isActive ? 0.78 : 0.24))
                    .frame(width: CGFloat(18 + ((index * 11 + tick * 7) % 24)), height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

private extension View {
    func waitActivitySurface(accent: Color) -> some View {
        padding(10)
            .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            }
    }
}

struct ModelStatusCard: View {
    let report: LocalModelReport
    let isInstalling: Bool
    let installMessage: String
    let installProgress: Double?
    let onRefresh: () -> Void
    let onInstall: () -> Void

    private var statusColor: Color {
        switch report.state {
        case .missing:
            return BookPalette.gold
        case .ready:
            return BookPalette.teal
        case .unavailable:
            return .red.opacity(0.78)
        }
    }

    private var iconName: String {
        switch report.state {
        case .missing:
            return "brain.head.profile"
        case .ready:
            return "checkmark.seal"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 34, height: 34)
                    .background(statusColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Book Brain")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.52))
                    Text(report.title)
                        .font(.headline)
                        .foregroundStyle(BookPalette.ink)
                }

                Spacer(minLength: 12)

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
                .accessibilityLabel("Ask whether the local brain is awake")
            }

            Text(report.detail)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Label(mlxRuntimeLinked ? "the model shelf is reachable" : "the model shelf is missing", systemImage: "cpu")
                Label("this device: \(report.deviceSummary)", systemImage: "lock.shield")
                Label("the Book chose: \(report.preferredModelID)", systemImage: "sparkles")
                Label("small fallback: \(report.fallbackModelID)", systemImage: "arrow.triangle.2.circlepath")
                Link(destination: URL(string: report.preferredModelSource) ?? URL(string: "https://huggingface.co/mlx-community")!) {
                    Label("model source", systemImage: "link")
                }
            }
            .font(.caption)
            .foregroundStyle(BookPalette.ink.opacity(0.58))
            .lineLimit(2)
            .minimumScaleFactor(0.82)

            if report.state == .missing {
                Button {
                    onInstall()
                } label: {
                    Label(isInstalling ? "I'm fetching my brain..." : "Fetch the local brain", systemImage: "arrow.down.circle")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling || !mlxRuntimeLinked)
            }

            if isInstalling {
                VStack(alignment: .leading, spacing: 6) {
                    if let installProgress {
                        ProgressView(value: installProgress)
                            .tint(BookPalette.teal)
                        Text("\(Int(installProgress * 100))%")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(BookPalette.teal)
                    } else {
                        ProgressView()
                            .tint(BookPalette.teal)
                        Text("Opening the model shelf")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.teal)
                    }
                }
            }

            if !installMessage.isEmpty {
                Text(installMessage)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .parchmentSurface(accent: statusColor, isActive: report.state == .ready)
    }
}

struct FaeGiftCard: View {
    let gift: FaeGift
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReadingLoosePage = false
    @State private var loosePageSalt = 0
    @State private var arrived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(gift.name, systemImage: "gift")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                Spacer()
                Text(gift.isActive ? gift.effect.title : "Resting")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((gift.isActive ? BookPalette.teal : BookPalette.ink).opacity(0.14), in: Capsule())
                    .foregroundStyle(gift.isActive ? BookPalette.teal : BookPalette.ink.opacity(0.5))
            }
            Text(gift.effect.effectLine)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            if gift.effect == .loosePage, gift.isActive {
                Button {
                    loosePageSalt += 1
                    isReadingLoosePage.toggle()
                } label: {
                    Label(isReadingLoosePage ? "Turn the page" : "Read the loose page", systemImage: "book.pages")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
                if isReadingLoosePage {
                    Text(loosePageText)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(BookPalette.page.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(BookPalette.ink.opacity(0.12), lineWidth: 1) }
        .scaleEffect(arrived || reduceMotion ? 1 : 0.86)
        .opacity(arrived || reduceMotion ? 1 : 0)
        .onAppear {
            guard !arrived else { return }
            if gift.isActive { BookFeedback.faeArrival(kind: gift.name) }
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.45, dampingFraction: 0.58)) {
                arrived = true
            }
        }
    }

    private var loosePageText: String {
        // Local salt lets "turn the page" reveal a different fragment immediately.
        LoosePageReader.fragments.isEmpty
            ? ""
            : LoosePageReader.fragments[abs("\(gift.id)-\(loosePageSalt)".stableHash) % LoosePageReader.fragments.count]
    }
}

// MARK: - The Pact Map (the Talismans' territory war)

struct PactMapSheet: View {
    let pactWar: PactWarState
    let boundTalismanID: String?
    var onPressClaim: (String) -> Void = { _ in }   // territoryID
    var pendingVerdict: SurfacePage? = nil
    var onRuleVerdict: (_ winnerTalismanID: String, _ loserTalismanID: String) -> Void = { _, _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressedTerritoryID: String?

    private var boundChapterName: String? {
        boundTalismanID.flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0)?.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let boundChapterName {
                        Text("You are Bound to \(boundChapterName). Its Talisman recognizes your seal when you leave it in a place.")
                            .font(.footnote)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("You are not yet Bound to a Chapter. The Talismans fight over your margins regardless.")
                            .font(.footnote.italic())
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let pendingVerdict {
                        sectionTitle("Awaiting Your Ruling")
                        Text("Two Talismans read one of your real days differently. I wasn't there. You were.")
                            .font(.footnote)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                        PactVerdictOptions(surface: pendingVerdict, onRule: onRuleVerdict)
                    }

                    frontSection("My Shelves", territories: PactTerritoryRegistry.shelves)
                    frontSection("The Real-World Doors", territories: PactTerritoryRegistry.integrations)

                    if !pactWar.log.isEmpty {
                        sectionTitle("Recent News")
                        ForEach(pactWar.log.prefix(3)) { record in
                            Text("• \(record.line)")
                                .font(.caption)
                                .foregroundStyle(BookPalette.ink.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
            }
            .background(BookPalette.page.ignoresSafeArea())
            .navigationTitle("The Pact Map")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func frontSection(_ title: String, territories: [PactTerritory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            ForEach(territories) { territory in
                territoryCard(territory)
            }
        }
    }

    private func territoryCard(_ territory: PactTerritory) -> some View {
        let controller = pactWar.controller(of: territory.id)
        let controllerChapter = controller.flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0) }
        let tier = pactWar.tier(of: territory.id)
        let isPressing = pressedTerritoryID == territory.id
        return VStack(alignment: .leading, spacing: 8) {
            Text(territory.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.ink)
            Text(territory.blurb)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            if let controllerChapter {
                HStack(spacing: 8) {
                    CharacterPortraitView(name: controllerChapter.talismanName, size: 30)
                    Text("Held by \(controllerChapter.talismanName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.teal)
                }
                Text(BookMechanicPresentation.pactPresence(
                    territory: territory,
                    chapter: controllerChapter,
                    tier: tier
                ))
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(BookMechanicPresentation.pactPresence(
                    territory: territory,
                    chapter: nil,
                    tier: tier
                ))
                    .font(.caption.italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.56))
            }
            if boundTalismanID != nil {
                Button {
                    pressClaim(territory.id)
                } label: {
                    Label(isPressing ? "The seal is taking…" : "Leave your seal here", systemImage: isPressing ? "seal.fill" : "hand.point.up.left")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
                .disabled(isPressing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(isPressing ? BookPalette.lampGold.opacity(0.7) : BookPalette.ink.opacity(0.12), lineWidth: isPressing ? 1.6 : 1) }
        .overlay(alignment: .topTrailing) {
            if isPressing {
                Image(systemName: "sparkles")
                    .foregroundStyle(BookPalette.lampGold)
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(isPressing && !reduceMotion ? 1.012 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.72), value: isPressing)
    }

    private func pressClaim(_ territoryID: String) {
        guard pressedTerritoryID == nil else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.68)) {
            pressedTerritoryID = territoryID
        }
        let finish = {
            onPressClaim(territoryID)
            withAnimation(.easeOut(duration: 0.18)) {
                pressedTerritoryID = nil
            }
        }
        if reduceMotion {
            finish()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: finish)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.ink.opacity(0.5))
    }

}

// MARK: - The People of the Book (the flyleaf)

/// The reader's register of real people. The Book witnesses by default; from
/// here the reader can add who someone is, wake or rest a thread, introduce
/// someone the Book has not suggested, or write a person into the story
/// (which mints a linked Cast member). The crossing is always the reader's.
struct PeopleOfTheBookSheet: View {
    let ledger: PeopleLedger
    let castMemberIDs: Set<String>
    var days: [BookDay] = []
    var now: Date = Date()
    var onWriteIntoStory: (String) -> Void = { _ in }        // slug
    var onUpdateWords: (String, String) -> Void = { _, _ in } // slug, words
    var onUpdateRelationship: (String, PersonRelationshipProfile) -> Void = { _, _ in }
    var onRest: (String) -> Void = { _ in }                   // slug
    var onWake: (String) -> Void = { _ in }                   // slug
    var onIntroduce: (String, String, String?, ReaderBirthday?) -> Void = { _, _, _, _ in } // name, words, contact id, birthday
    var onWakeDeclinedName: (String) -> Void = { _ in }       // slug

    @Environment(\.dismiss) private var dismiss
    @State private var introduceName = ""
    @State private var introduceWords = ""
    @State private var introduceContactIdentifier: String?
    @State private var introduceBirthday: ReaderBirthday?
    @State private var isContactPickerPresented = false
    @State private var editingSlug: String?
    @State private var editingWords = ""
    @State private var editingRoles = ""
    @State private var editingSettings = Set<PersonRelationshipSetting>()
    @State private var editingChannels = Set<PersonContactChannel>()
    @State private var editingInterests = ""
    @State private var editingRituals = ""
    @State private var editingBoundaries = ""
    @State private var editingSeason = ""
    @State private var editingInvitationPermission: PersonInvitationPermission = .playful
    @State private var isCompanyVolumePresented = false

    private var activeThreads: [PersonThread] {
        ledger.threads.filter { !$0.resting }.sorted { $0.name < $1.name }
    }
    private var restingThreads: [PersonThread] {
        ledger.threads.filter { $0.resting }.sorted { $0.name < $1.name }
    }
    private func isInStory(_ thread: PersonThread) -> Bool {
        if let id = thread.castMemberID { return castMemberIDs.contains(id) }
        return false
    }

    private var companyVolume: CompanyYouKeptVolume {
        PeopleOfTheBook.companyYouKept(ledger: ledger, days: days, now: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("These are the real people who keep arriving in your pages. By default I only witness them: I keep what you wrote, and never put words in their mouths. Where the real ends and the story begins is yours to draw.")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    introduceCard

                    if !companyVolume.chapters.isEmpty {
                        companyVolumeCard
                    }

                    if !activeThreads.isEmpty {
                        sectionTitle("In Your Book")
                        ForEach(activeThreads) { threadCard($0) }
                    }

                    if !restingThreads.isEmpty {
                        sectionTitle("Resting")
                        ForEach(restingThreads) { restingCard($0) }
                    }

                    if !ledger.restingNames.isEmpty {
                        sectionTitle("Names You Set Aside")
                        Text("Names I once asked about and you let rest. I will not suggest them again unless you wake them.")
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(ledger.restingNames.sorted(), id: \.self) { slug in
                            declinedRow(slug)
                        }
                    }

                    if ledger.threads.isEmpty && ledger.restingNames.isEmpty {
                        Text("No one yet. As a name recurs in your own pages, I will ask about it here, or you can introduce someone above.")
                            .font(.footnote.italic())
                            .foregroundStyle(BookPalette.ink.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(BookPalette.page.ignoresSafeArea())
            .navigationTitle("The People of the Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $isCompanyVolumePresented) {
                CompanyYouKeptSheet(ledger: ledger, days: days, now: now)
            }
            #if os(iOS) && canImport(Contacts) && canImport(ContactsUI)
            .sheet(isPresented: $isContactPickerPresented) {
                PeopleContactPicker { name, identifier, birthday in
                    introduceName = name
                    introduceContactIdentifier = identifier
                    introduceBirthday = birthday
                    isContactPickerPresented = false
                } onCancel: {
                    isContactPickerPresented = false
                }
            }
            #endif
        }
    }

    private var companyVolumeCard: some View {
        Button {
            BookFeedback.play(.select)
            isCompanyVolumePresented = true
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("The Company You Kept", systemImage: "books.vertical.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                Text("A living volume of \(companyVolume.chapters.count) people and \(companyVolume.entryCount) attributed crossings, never a ranking, never a guessed intimacy.")
                    .font(.system(.caption, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                if companyVolume.readerWrittenCount > 0 {
                    Text("\(companyVolume.readerWrittenCount) are in your own hand.")
                        .font(.caption2.weight(.bold))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(BookPalette.nightText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(BookPalette.nightPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.bookPress())
    }

    private var introduceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Introduce Someone")
            TextField("Their name", text: $introduceName)
                .textFieldStyle(.roundedBorder)
            #if os(iOS) && canImport(Contacts) && canImport(ContactsUI)
            Button {
                isContactPickerPresented = true
            } label: {
                Label(
                    introduceContactIdentifier == nil ? "Choose one person from Contacts" : "Chosen from Contacts",
                    systemImage: introduceContactIdentifier == nil ? "person.crop.circle.badge.plus" : "checkmark.circle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.teal)
            }
            .buttonStyle(.bookPress())
            #endif
            TextField("Who are they, to you? (optional)", text: $introduceWords, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            Button {
                let name = introduceName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                BookFeedback.play(.select)
                onIntroduce(name, introduceWords, introduceContactIdentifier, introduceBirthday)
                introduceName = ""
                introduceWords = ""
                introduceContactIdentifier = nil
                introduceBirthday = nil
            } label: {
                Text("Add to the Book")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(introduceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? BookPalette.ink.opacity(0.35) : BookPalette.teal)
            }
            .buttonStyle(.bookPress())
            .disabled(introduceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.parchmentEdge.opacity(0.2), lineWidth: 1)
        }
    }

    private func threadCard(_ thread: PersonThread) -> some View {
        let inStory = isInStory(thread)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: inStory ? "theatermasks.fill" : "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(inStory ? BookPalette.violet : BookPalette.teal)
                Text(thread.name)
                    .font(.headline)
                    .foregroundStyle(BookPalette.ink)
                Spacer()
                statusPill(inStory ? "In the story" : "Kept", tint: inStory ? BookPalette.violet : BookPalette.teal)
            }

            if !thread.readerWords.isEmpty {
                Text(thread.readerWords)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let profile = thread.relationship, !profile.isEmpty {
                Label(relationshipSummary(profile), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(BookPalette.teal.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(historyLine(thread))
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            if editingSlug == slug(thread) {
                relationshipEditor(thread)
            } else {
                HStack(spacing: 14) {
                    if !inStory {
                        cardAction("Write into the story", "theatermasks") {
                            onWriteIntoStory(slug(thread))
                        }
                    }
                    cardAction(thread.relationship == nil ? "Teach me" : "Edit relationship", "point.3.connected.trianglepath.dotted") {
                        beginEditing(thread)
                    }
                    cardAction("Let rest", "moon.zzz") {
                        onRest(slug(thread))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((inStory ? BookPalette.violet : BookPalette.parchmentEdge).opacity(0.2), lineWidth: 1)
        }
    }

    private func relationshipEditor(_ thread: PersonThread) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHO ARE THEY, TO YOU?")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.52))
            TextField("Your own line about them", text: $editingWords, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            TextField("Roles: partner, sister, friend, coworker…", text: $editingRoles, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...2)

            relationshipChoiceTitle("Where this relationship lives")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(PersonRelationshipSetting.allCases, id: \.rawValue) { setting in
                    relationshipChip(setting.label, selected: editingSettings.contains(setting)) {
                        toggle(setting, in: &editingSettings)
                    }
                }
            }

            relationshipChoiceTitle("How you usually meet")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(PersonContactChannel.allCases, id: \.rawValue) { channel in
                    relationshipChip(channel.label, selected: editingChannels.contains(channel)) {
                        toggle(channel, in: &editingChannels)
                    }
                }
            }

            TextField("Things you share. AI, old movies, gardening…", text: $editingInterests, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            TextField("Ordinary rituals: morning coffee, Tuesday texts…", text: $editingRituals, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            TextField("Boundaries I must respect", text: $editingBoundaries, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            TextField("What season is this relationship in?", text: $editingSeason, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...2)

            Picker("Favors from the Book", selection: $editingInvitationPermission) {
                ForEach(PersonInvitationPermission.allCases, id: \.rawValue) { permission in
                    Text(permission.label).tag(permission)
                }
            }
            .pickerStyle(.segmented)

            if thread.relationship?.contactIdentifier != nil {
                Label("Linked to a contact you chose", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.52))
            }

            HStack(spacing: 14) {
                Button("Save what is true") {
                    onUpdateWords(slug(thread), editingWords)
                    onUpdateRelationship(slug(thread), editedProfile(for: thread))
                    editingSlug = nil
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)
                Button("Cancel") { editingSlug = nil }
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.5))
            }
        }
        .padding(.top, 4)
    }

    private func relationshipChoiceTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(BookPalette.ink.opacity(0.52))
    }

    private func relationshipChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(selected ? BookPalette.page : BookPalette.ink.opacity(0.72))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .background(selected ? BookPalette.teal : BookPalette.paper.opacity(0.7), in: Capsule())
                .overlay { Capsule().stroke(BookPalette.teal.opacity(selected ? 0 : 0.24), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func beginEditing(_ thread: PersonThread) {
        let profile = thread.relationship ?? PersonRelationshipProfile()
        editingWords = thread.readerWords
        editingRoles = profile.roles.joined(separator: ", ")
        editingSettings = Set(profile.settings)
        editingChannels = Set(profile.channels)
        editingInterests = profile.sharedInterests.joined(separator: ", ")
        editingRituals = profile.ordinaryRituals.joined(separator: ", ")
        editingBoundaries = profile.boundaries.joined(separator: ", ")
        editingSeason = profile.season
        editingInvitationPermission = profile.invitationPermission
        editingSlug = slug(thread)
    }

    private func editedProfile(for thread: PersonThread) -> PersonRelationshipProfile {
        PersonRelationshipProfile(
            roles: splitList(editingRoles),
            settings: PersonRelationshipSetting.allCases.filter(editingSettings.contains),
            channels: PersonContactChannel.allCases.filter(editingChannels.contains),
            sharedInterests: splitList(editingInterests),
            ordinaryRituals: splitList(editingRituals),
            boundaries: splitList(editingBoundaries),
            season: editingSeason,
            invitationPermission: editingInvitationPermission,
            contactIdentifier: thread.relationship?.contactIdentifier,
            birthday: thread.relationship?.birthday,
            evidence: thread.relationship?.evidence ?? []
        )
    }

    private func relationshipSummary(_ profile: PersonRelationshipProfile) -> String {
        var pieces = profile.roles
        pieces.append(contentsOf: profile.settings.map(\.label))
        pieces.append(contentsOf: profile.channels.map(\.label))
        if !profile.sharedInterests.isEmpty {
            pieces.append("Shares \(profile.sharedInterests.joined(separator: ", "))")
        }
        if !profile.ordinaryRituals.isEmpty {
            pieces.append("Returns through \(profile.ordinaryRituals.joined(separator: ", "))")
        }
        if !profile.season.isEmpty { pieces.append(profile.season) }
        return pieces.joined(separator: " · ")
    }

    private func splitList(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func restingCard(_ thread: PersonThread) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.subheadline)
                .foregroundStyle(BookPalette.ink.opacity(0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.7))
                if !thread.readerWords.isEmpty {
                    Text(thread.readerWords)
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer()
            cardAction("Wake", "sun.max") { onWake(slug(thread)) }
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.25), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func declinedRow(_ slug: String) -> some View {
        HStack {
            Text(slug.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.subheadline)
                .foregroundStyle(BookPalette.ink.opacity(0.6))
            Spacer()
            cardAction("Let it back", "arrow.uturn.backward") { onWakeDeclinedName(slug) }
        }
        .padding(.vertical, 4)
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private func cardAction(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            BookFeedback.play(.select)
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.caption2.weight(.bold))
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(BookPalette.teal)
        }
        .buttonStyle(.bookPress())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.ink.opacity(0.5))
            .padding(.top, 4)
    }

    private func slug(_ thread: PersonThread) -> String {
        String(thread.id.dropFirst("person:".count))
    }

    private func historyLine(_ thread: PersonThread) -> String {
        let month = monthName(fromDayID: thread.firstMentionDay)
        let count = thread.mentionPageCount
        if count <= 0 {
            return "You introduced them yourself."
        }
        let pages = count == 1 ? "1 page" : "\(count) pages"
        return "\(pages) in your own hand, since \(month)."
    }

    private func monthName(fromDayID dayID: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar.current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dayID) else { return "earlier" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
}

/// The long-horizon relational binding. It deliberately reads like a book,
/// not a contact dashboard: chapters are people, entries are attributed
/// crossings, and public finds retain their source door.
private struct CompanyYouKeptSheet: View {
    let ledger: PeopleLedger
    let days: [BookDay]
    var now: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear: Int?

    private var availableYears: [Int] {
        Array(Set(days.flatMap(\.pages).map { Calendar.current.component(.year, from: $0.createdAt) })).sorted(by: >)
    }

    private var volume: CompanyYouKeptVolume {
        let scope = selectedYear.map(CompanyYouKeptVolume.Scope.year) ?? .lifetime
        return PeopleOfTheBook.companyYouKept(ledger: ledger, days: days, scope: scope, now: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(volume.title)
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(BookPalette.nightText)
                        Text(volume.subtitle)
                            .font(.system(.headline, design: .serif).italic())
                            .foregroundStyle(BookPalette.lampGold)
                        Text(volume.foreword)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(BookPalette.nightText.opacity(0.86))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !availableYears.isEmpty {
                        Picker("Binding", selection: $selectedYear) {
                            Text("All years").tag(Int?.none)
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(Optional(year))
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if volume.chapters.isEmpty {
                        Text("This year's signatures are still blank. I won't pad them with guesses.")
                            .font(.system(.callout, design: .serif).italic())
                            .foregroundStyle(BookPalette.nightText.opacity(0.7))
                    } else {
                        ForEach(volume.chapters) { chapter in
                            companyChapter(chapter)
                        }
                    }

                    Text(volume.closing)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.nightText)
                        .lineSpacing(4)
                        .padding(.vertical, 8)

                    ShareLink(item: volume.shareText) {
                        Label("Carry out a copy", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(BookPalette.ink)
                            .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(BookPalette.nightPanel.ignoresSafeArea())
            .navigationTitle("Relational Volume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BookPalette.lampGold)
                }
            }
        }
    }

    private func companyChapter(_ chapter: CompanyYouKeptVolume.Chapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chapter.name)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(BookPalette.lampGold)
            if !chapter.readerWords.isEmpty {
                Text(chapter.readerWords)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(BookPalette.nightText.opacity(0.9))
            }
            let context = chapter.roles + chapter.sharedInterests.map { "shared: \($0)" } + chapter.ordinaryRituals
            if !context.isEmpty {
                Text(context.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
            }
            if chapter.entries.isEmpty {
                Text("Their thread exists. This binding is waiting for lived pages.")
                    .font(.caption.italic())
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))
            } else {
                ForEach(chapter.entries.suffix(10)) { entry in
                    companyEntry(entry)
                }
            }
        }
        .padding(15)
        .background(BookPalette.ink.opacity(0.24), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.2), lineWidth: 1)
        }
    }

    private func companyEntry(_ entry: CompanyYouKeptVolume.Entry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.authority.label.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.6)
                    .foregroundStyle(entry.authority == .bookOffer ? BookPalette.violet : BookPalette.teal)
                Spacer()
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.5))
            }
            Text(entry.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.nightText)
            Text(entry.text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            if let reference = entry.externalReference,
               let url = URL(string: reference.url) {
                Link(destination: url) {
                    Label("\(reference.sourceName): open source", systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.lampGold)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

#if os(iOS) && canImport(Contacts) && canImport(ContactsUI)
/// A deliberately narrow Contacts door. `CNContactPickerViewController` gives
/// the app only the person's final selection and does not require broad address
/// book permission; the Book stores the chosen local identifier as a bridge.
private struct PeopleContactPicker: UIViewControllerRepresentable {
    var onSelect: (String, String, ReaderBirthday?) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: PeopleContactPicker
        init(parent: PeopleContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let formatted = CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let name = formatted?.nonEmpty ?? fallback
            guard !name.isEmpty else { parent.onCancel(); return }
            // The picker hands over the one contact the reader chose, so the
            // birthday comes with it. Month and day only; the year is dropped.
            var birthday: ReaderBirthday?
            if let parts = contact.birthday, let month = parts.month, let day = parts.day {
                let candidate = ReaderBirthday(month: month, day: day)
                birthday = candidate.isRealDate() ? candidate : nil
            }
            parent.onSelect(name, contact.identifier, birthday)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onCancel()
        }
    }
}
#endif

/// The reader rules a contested reading: two Talismans read one real kept page
/// through opposite philosophies, and the reader decides which is true. Presented
/// from the daily feed; the winner gains the territory that governs the page.
struct PactVerdictSheet: View {
    let surface: SurfacePage
    var onRule: (_ winnerTalismanID: String, _ loserTalismanID: String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Two Talismans stopped on the same page of your life and cannot agree on what it was. I won't settle it. You were there: rule for the reading that's true.")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    PactVerdictOptions(surface: surface) { winner, loser in
                        onRule(winner, loser)
                        dismiss()
                    }
                }
                .padding(20)
            }
            .background(BookPalette.page.ignoresSafeArea())
            .navigationTitle("The Pact War Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
        }
    }
}

/// The two ruling rows, shared by the verdict sheet and the Pact Map's pending
/// section. Reads the talismans, readings, and territory from the surface payload.
struct PactVerdictOptions: View {
    let surface: SurfacePage
    var onRule: (_ winnerTalismanID: String, _ loserTalismanID: String) -> Void

    var body: some View {
        let meta = surface.payload.metadata
        let talismanA = meta["talismanA"] ?? ""
        let talismanB = meta["talismanB"] ?? ""
        let territoryName = meta["territoryName"] ?? "this shelf"
        VStack(spacing: 12) {
            option(name: meta["talismanAName"] ?? "A Talisman",
                   reading: meta["readingA"] ?? "",
                   territoryName: territoryName) { onRule(talismanA, talismanB) }
            option(name: meta["talismanBName"] ?? "A Talisman",
                   reading: meta["readingB"] ?? "",
                   territoryName: territoryName) { onRule(talismanB, talismanA) }
        }
    }

    @ViewBuilder
    private func option(name: String, reading: String, territoryName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(BookPalette.ink)
                Text(reading)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Rule for this reading: \(territoryName) shifts toward it")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.bookPress(playsHaptic: false))
        .bookCardHover()
    }
}

/// A Talisman has sent the reader into the real day; the reader pays the errand
/// with a genuine field report. The talisman gains Control Belief on its territory.
struct PactErrandSheet: View {
    let surface: SurfacePage
    var onDeliver: (_ report: String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var report = ""

    private var trimmed: String { report.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let meta = surface.payload.metadata
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(meta["openingLine"] ?? "A Talisman sets a task.")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("THE ERRAND")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.5))
                    Text(meta["terms"] ?? "")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("YOUR FIELD REPORT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.5))
                    TextField("What you actually did, saw, or heard…", text: $report, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.system(.body, design: .serif))
                        .padding(12)
                        .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10).stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                        }

                    Button {
                        onDeliver(trimmed)
                        dismiss()
                    } label: {
                        Text("Deliver: \(meta["talismanName"] ?? "the Talisman") gains \(meta["territoryName"] ?? "ground")")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(trimmed.count < 3)
                }
                .padding(20)
            }
            .background(BookPalette.page.ignoresSafeArea())
            .navigationTitle("A Talisman's Errand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
        }
    }
}
