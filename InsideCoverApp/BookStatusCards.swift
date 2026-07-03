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
            return "The next Story Page is gathering around this exact packet."
        }
        return "The Book has not laid a Story Page in the margin yet."
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
                .foregroundStyle(.white.opacity(0.86))
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
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
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
        .accessibilityLabel("Belief \(tierName), \(clampedScore) out of 100")
        .help("Belief \(clampedScore) out of 100")
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
    case openBookSection(String)
    case openBookShop
    case openPactMap
}

private enum GlowMenuSection: String, CaseIterable, Identifiable {
    case belief
    case spells
    case pages
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
        case .book:
            return "Book"
        }
    }

    var subtitle: String {
        switch self {
        case .belief:
            return "Give or take Belief among characters."
        case .spells:
            return "Open a Compass Run or Enchantment."
        case .pages:
            return "Tune which Pages the Book notices."
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
        case .book:
            return "MarginaliaStar"
        }
    }

    var rowOffset: CGFloat {
        switch self {
        case .belief:
            return 192
        case .spells:
            return 300
        case .pages:
            return 408
        case .book:
            return 516
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
    let onCreateCastMember: () -> Void
    let onClose: () -> Void
    let onSelectAction: (GlowMenuAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSection: GlowMenuSection?
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
            let panelTop = max(proxy.safeAreaInsets.top + 74, 98)
            let panelHeight = min(proxy.size.height - panelTop - 30, selectedSection == nil ? 500 : 690)
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

                VStack(spacing: 0) {
                    headerBadge
                        .frame(width: min(250, panelWidth * 0.72))
                        .offset(y: 12)
                        .zIndex(3)

                    mainPanel(width: panelWidth, height: panelHeight)
                }
                .position(
                    x: proxy.size.width - (panelWidth / 2) - 14,
                    y: panelTop + (panelHeight / 2)
                )
                .zIndex(1)

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
                        .zIndex(2)
                }
            }
        }
        .onAppear {
            BookFeedback.play(.sourceRefresh)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isLit = true
            }
        }
    }

    private func mainPanel(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 10) {
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
                VStack(spacing: 8) {
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
        .padding(.top, 17)
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

    private var crest: some View {
        Color.clear
        .frame(height: 44)
        .padding(.top, 4)
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
            HStack(spacing: 14) {
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
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(isSelected ? 0.58 : 0.22), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
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
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
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
            .frame(maxHeight: 390)
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
                detail: "Open the world event door: active or archived temporary physics, phases, and fieldwork.",
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
            pageBeliefSubmenu(compact: compact)
            menuButton(
                title: "The Pact Map",
                detail: "Watch the Talismans contest the Book's shelves and your real-world doors.",
                systemImage: "map",
                compact: compact
            ) {
                onSelectAction(.openPactMap)
            }
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

    private func pageBeliefSubmenu(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Page belief action", selection: $beliefMode) {
                Text("Give Belief").tag(GlowBeliefMode.give)
                Text("Take Belief").tag(GlowBeliefMode.take)
            }
            .pickerStyle(.segmented)

            menuButton(
                title: "The BookShop",
                detail: "The Marginalia Goblins' living market: App Store packs, Attention, Belief, and your standing with the Fae.",
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
            Picker("Belief action", selection: $beliefMode) {
                Text("Give Belief").tag(GlowBeliefMode.give)
                Text("Take Belief").tag(GlowBeliefMode.take)
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
                        Text("Give Belief to a new Cast Member")
                            .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Text("State what it is, or give the Book a photo.")
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
            .accessibilityLabel("Give Belief to a new Cast Member")

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
            return "Are you sure you want to give belief to \(entity.name)?"
        case .take:
            return "Are you sure you want to take belief from \(entity.name)?"
        }
    }

    private func confirmationTitle(for page: GlowPageMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Give belief to \(page.title)?"
        case .take:
            return "Take belief from \(page.title)?"
        }
    }

    private func confirmationButtonTitle(for entity: GlowEntityMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Give \(entity.name) +3 Belief"
        case .take:
            return "Try to Take Belief"
        }
    }

    private func confirmationButtonTitle(for page: GlowPageMenuItem) -> String {
        switch beliefMode {
        case .give:
            return "Give \(page.title) +3 Belief"
        case .take:
            return "Take \(page.title) -3 Belief"
        }
    }

    private func menuButton(
        title: String,
        detail: String,
        systemImage: String,
        compact: Bool,
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

    private var topNotch: some View {
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
        .accessibilityHidden(true)
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

/// The instant margin reply shown right after a page is kept — a cast member's
/// one-line note, echoing the keep before the surface retires.
struct KeepMarginNoteToast: View {
    let note: KeepMarginalia.Note
    var showsPressHint: Bool = false

    private var voice: KeepMarginalia.Voice? { KeepMarginalia.voice(forSlug: note.castSlug) }
    private var accent: Color { voice.map { Color(bookHex: $0.accentHex) } ?? BookPalette.gold }
    private var rejoinderAccent: Color {
        note.rejoinderName
            .flatMap { name in KeepMarginalia.voices.first { $0.name == name } }
            .map { Color(bookHex: $0.accentHex) } ?? BookPalette.gold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                            .foregroundStyle(voice == nil ? BookPalette.nightText.opacity(0.72) : accent)
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
                    if let ripple = note.rippleLine {
                        Text(ripple)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.lampGold.opacity(0.92))
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
                            .foregroundStyle(rejoinderAccent)
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
            if showsPressHint {
                Text("Tap to press a souvenir card.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))
            }
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

/// From 5pm, teases which threads tonight's Book of You braid has already caught.
struct BraidEmberStatusCard: View {
    let teaser: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(BookPalette.lampGold)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(teaser)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Book of You braids tonight.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Monthly Binding gathers its signatures.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                status: "The Book is carrying your last choice forward.",
                quip: "The old thread is being tied to the next true sentence.",
                accent: BookPalette.violet
            )
        case let value where value.contains("ask-the-book"):
            self.init(
                title: "The Book is reading your question",
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
                    Text("WRITING PRIVATELY ON THIS IPHONE")
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
        .accessibilityLabel("\(descriptor.scribe). \(descriptor.title). Writing privately on this iPhone.")
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

            GhostInkText(text: text, reduceMotion: reduceMotion)
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
            HStack(spacing: 10) {
                Image(systemName: radioManager.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                    .foregroundStyle(descriptor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(radioManager.isPlaying ? (radioManager.activeStation?.title ?? "ReEnchanted Radio") : "Let the Radio keep the room")
                        .font(.caption.weight(.bold))
                    Text(radioManager.isPlaying ? radioManager.statusLine : "One tap tunes Fae-Fi while the page writes.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                }
                Spacer()
                Button(radioManager.isPlaying ? "Stop" : "Tune in") { toggleRadio() }
                    .font(.caption2.weight(.bold))
                    .buttonStyle(.bordered)
                    .tint(descriptor.accent)
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

    private func toggleRadio() {
        if radioManager.isPlaying {
            radioManager.stop()
            return
        }
        let unlocked = Set(PlayerVault.shared.data.ownedPacks ?? [])
        let stationID = RadioStationRegistry.station(id: "fae-fi", unlockedPackIDs: unlocked)?.id
            ?? RadioStationRegistry.stations(unlockedPackIDs: unlocked).first?.id
        if let stationID {
            radioManager.tune(stationID: stationID, unlockedPackIDs: unlocked)
        }
    }
}

private struct GhostInkText: View {
    let text: String
    let reduceMotion: Bool

    @State private var visibleText = ""
    @State private var visibleCharacterCount = 0

    var body: some View {
        Text(visibleText)
            .task(id: text) {
                await reveal(text)
            }
            .onAppear {
                if reduceMotion {
                    visibleText = text
                    visibleCharacterCount = text.count
                }
            }
    }

    @MainActor
    private func reveal(_ target: String) async {
        guard !reduceMotion else {
            visibleText = target
            visibleCharacterCount = target.count
            return
        }

        if target.isEmpty {
            visibleText = ""
            visibleCharacterCount = 0
            return
        }

        guard target.hasPrefix(visibleText), visibleCharacterCount <= target.count else {
            visibleText = target
            visibleCharacterCount = target.count
            return
        }

        let targetCount = target.count
        guard visibleCharacterCount < targetCount else {
            visibleText = target
            visibleCharacterCount = targetCount
            return
        }

        let remaining = targetCount - visibleCharacterCount
        let step = max(1, min(12, remaining / 18 + 1))

        while visibleCharacterCount < targetCount && !Task.isCancelled {
            visibleCharacterCount = min(targetCount, visibleCharacterCount + step)
            visibleText = String(target.prefix(visibleCharacterCount))
            try? await Task.sleep(for: .milliseconds(24))
        }

        if !Task.isCancelled {
            visibleText = target
            visibleCharacterCount = targetCount
        }
    }
}

/// The 60-second "Do Nothing" minute from Wonder Compass Chapter 10 — a single breathing
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
                        Text(remaining == 0 ? "Stay, read, or close the reset." : "\(remaining) seconds — optional, never a requirement.")
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
                Label("this device: \(report.deviceSummary)", systemImage: "iphone")
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
                    Label(isInstalling ? "The Book is fetching its brain..." : "Fetch the local brain", systemImage: "arrow.down.circle")
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
                Label(gift.name, systemImage: gift.isCold ? "snowflake" : "gift")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(gift.isCold ? BookPalette.ink.opacity(0.45) : BookPalette.lampGold)
                Spacer()
                Text(gift.isActive ? gift.effect.title : (gift.isCold ? "Cold" : "Spent"))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((gift.isActive ? BookPalette.teal : BookPalette.ink).opacity(0.14), in: Capsule())
                    .foregroundStyle(gift.isActive ? BookPalette.teal : BookPalette.ink.opacity(0.5))
            }
            Text(gift.isCold ? "\(gift.effect.effectLine) — dormant until the debt is repaid." : gift.effect.effectLine)
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

    private var boundChapterName: String? {
        boundTalismanID.flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0)?.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let boundChapterName {
                        Text("You are Bound to \(boundChapterName). Pressing a claim invests Belief in its Talisman.")
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
                        Text("Two Talismans read one of your real days differently. Rule it, and the shelf it governs shifts toward the reading you chose.")
                            .font(.footnote)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                        PactVerdictOptions(surface: pendingVerdict, onRule: onRuleVerdict)
                    }

                    frontSection("The Book's Shelves", territories: PactTerritoryRegistry.shelves)
                    frontSection("The Real-World Doors", territories: PactTerritoryRegistry.integrations)

                    if !pactWar.log.isEmpty {
                        sectionTitle("Recent Moves")
                        ForEach(pactWar.log.prefix(6)) { record in
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
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(territory.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                Spacer()
                Text(tier.label)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((controller == nil ? BookPalette.ink : BookPalette.lampGold).opacity(0.14), in: Capsule())
                    .foregroundStyle(controller == nil ? BookPalette.ink.opacity(0.5) : BookPalette.lampGold)
            }
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
                Text(territoryStatusLine(territory, chapter: controllerChapter, tier: tier))
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(AcademyChapterRegistry.chapters, id: \.id) { chapter in
                let value = pactWar.control(chapter.talismanID, territory.id)
                if value > 0 {
                    HStack(spacing: 6) {
                        Text(chapter.talismanName)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.7))
                            .frame(width: 96, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(BookPalette.ink.opacity(0.08))
                                Capsule()
                                    .fill((controller == chapter.talismanID ? BookPalette.lampGold : BookPalette.teal).opacity(0.5))
                                    .frame(width: max(4, geo.size.width * CGFloat(min(100, value)) / 100))
                            }
                        }
                        .frame(height: 8)
                        Text("\(value)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BookPalette.ink.opacity(0.55))
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
            if boundTalismanID != nil {
                Button {
                    onPressClaim(territory.id)
                } label: {
                    Label("Press your claim", systemImage: "hand.point.up.left")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(BookPalette.ink.opacity(0.12), lineWidth: 1) }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.ink.opacity(0.5))
    }

    private func territoryStatusLine(_ territory: PactTerritory, chapter: AcademyChapter, tier: PactTier) -> String {
        switch tier {
        case .contesting:
            return "\(chapter.talismanName) has only a trace here. The territory is noticing its doctrine, but the app is not changing yet."
        case .influenced:
            return "\(chapter.talismanName) has a foothold. Verdicts, errands, or pressed claims can turn this into real control."
        case .controlled:
            return "\(chapter.talismanName) now shapes this territory: related pages surface more often and may carry its framing."
        case .dominated:
            return "\(chapter.talismanName) has a strong hold. This territory is being actively pulled toward \(chapter.name)'s way of reading."
        case .sovereign:
            return "\(chapter.talismanName) reigns here. It can act through this territory without waiting to be asked."
        case .none:
            return "\(territory.name) is quiet."
        }
    }
}

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
                    Text("Two Talismans stopped on the same page of your life and cannot agree on what it was. The Book won't settle it. You were there — rule for the reading that's true.")
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
                Text("Rule for this reading — \(territoryName) shifts toward it")
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
        .buttonStyle(.plain)
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
                        Text("Deliver — \(meta["talismanName"] ?? "the Talisman") gains \(meta["territoryName"] ?? "ground")")
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
