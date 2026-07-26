import AppIntents
import SwiftUI
import WidgetKit

struct ReEnchantedWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ReEnchantedWidgetSnapshot
}

struct ReEnchantedWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReEnchantedWidgetEntry {
        ReEnchantedWidgetEntry(date: Date(), snapshot: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReEnchantedWidgetEntry) -> Void) {
        completion(ReEnchantedWidgetEntry(date: Date(), snapshot: ReEnchantedWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReEnchantedWidgetEntry>) -> Void) {
        let entry = ReEnchantedWidgetEntry(date: Date(), snapshot: ReEnchantedWidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private struct QuestionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReEnchantedWidgetEntry

    private var question: ReEnchantedWidgetQuestion {
        entry.snapshot.question ?? ReEnchantedWidgetQuestion(
            id: "question-fallback",
            title: "Did anything become real?",
            prompt: "Bring the Book one true line when there is one.",
            symbolName: "questionmark.bubble",
            urlPath: "question"
        )
    }

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryInline:
            Label(question.title, systemImage: question.symbolName)
                .widgetURL(deepLinkURL(question.urlPath))
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: question.symbolName)
                    .font(.title3.weight(.bold))
            }
            .widgetURL(deepLinkURL(question.urlPath))
        default:
            VStack(alignment: .leading, spacing: 2) {
                Label(question.title, systemImage: question.symbolName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(question.prompt)
                    .font(.caption2)
                    .lineLimit(2)
            }
            .widgetURL(deepLinkURL(question.urlPath))
        }
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReEnchantedWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodayPage(snapshot: entry.snapshot)
        case .systemLarge, .systemExtraLarge:
            OpenDesk(snapshot: entry.snapshot)
        default:
            MediumTodayPage(snapshot: entry.snapshot)
        }
    }
}

private struct RadioWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReEnchantedWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRadio(snapshot: entry.snapshot)
        case .systemLarge, .systemExtraLarge:
            LargeRadio(snapshot: entry.snapshot)
        default:
            MediumRadio(snapshot: entry.snapshot)
        }
    }
}

private struct EnchantmentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReEnchantedWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallEnchantment(snapshot: entry.snapshot)
        case .systemLarge, .systemExtraLarge:
            LargeEnchantment(snapshot: entry.snapshot)
        default:
            MediumEnchantment(snapshot: entry.snapshot)
        }
    }
}

private struct CompassWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReEnchantedWidgetEntry

    var run: ReEnchantedCompassWidgetRun {
        ReEnchantedCompassWidgetRunStore.loadRun()
    }

    var step: CompassWidgetStep {
        CompassWidgetStep.steps[max(0, min(run.stepIndex, CompassWidgetStep.steps.count - 1))]
    }

    var compassRun: ReEnchantedWidgetCompassRun? {
        entry.snapshot.compass?.run
    }

    var body: some View {
        if family == .systemLarge || family == .systemExtraLarge {
            LargeCompassRun(snapshot: entry.snapshot, run: run, step: step, compassRun: compassRun)
        } else {
            CompactCompassRun(snapshot: entry.snapshot, run: run, step: step, compassRun: compassRun, isSmall: family == .systemSmall)
        }
    }
}

private struct CompassWidgetStep: Identifiable {
    var id: Int
    var title: String
    var prompt: String
    var symbolName: String

    static let steps: [CompassWidgetStep] = [
        CompassWidgetStep(
            id: 0,
            title: "North = Notice",
            prompt: "Choose the run's goal as one I wonder question.",
            symbolName: "sparkle.magnifyingglass"
        ),
        CompassWidgetStep(
            id: 1,
            title: "East = Embark",
            prompt: "Make a tiny plan: destination, delight, and definition of done.",
            symbolName: "figure.walk"
        ),
        CompassWidgetStep(
            id: 2,
            title: "South = Sense",
            prompt: "Let the body answer through color, sound, edge, texture, or weather.",
            symbolName: "hand.draw"
        ),
        CompassWidgetStep(
            id: 3,
            title: "West = Write",
            prompt: "Keep the best sensory moment from the run in one true sentence.",
            symbolName: "pencil.and.scribble"
        ),
        CompassWidgetStep(
            id: 4,
            title: "Center = Rest",
            prompt: "Put the phone down for one quiet minute. Then bring the sentence back.",
            symbolName: "book.closed"
        )
    ]
}

private struct CompactCompassRun: View {
    var snapshot: ReEnchantedWidgetSnapshot
    var run: ReEnchantedCompassWidgetRun
    var step: CompassWidgetStep
    var compassRun: ReEnchantedWidgetCompassRun?
    var isSmall: Bool

    var body: some View {
        ReWidgetBackground {
            ParchmentPanel(accent: .teal) {
                VStack(alignment: .leading, spacing: isSmall ? 7 : 9) {
                    CompassHeader(run: run)
                    CompassProgress(stepIndex: run.stepIndex, isStarted: run.isStarted)

                    Text(run.isStarted ? step.title : "Begin a Compass Run")
                        .font(.system(isSmall ? .headline : .title3, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    if !isSmall, let compassRun {
                        CompassRunChips(compassRun: compassRun)
                    }

                    Text(run.isStarted ? promptText : (snapshot.compass?.prompt ?? "Bring back one true sentence from wherever you are."))
                        .font(isSmall ? .caption : .callout)
                        .foregroundStyle(ReTheme.mutedInk)
                        .lineLimit(isSmall ? 3 : 4)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 0)

                    if isSmall {
                        CompactCompassControls(run: run)
                    } else {
                        FullCompassControls(run: run)
                    }
                }
            }
        }
    }

    private var promptText: String {
        compassRun?.prompt(forStepIndex: step.id) ?? step.prompt
    }
}

private struct LargeCompassRun: View {
    var snapshot: ReEnchantedWidgetSnapshot
    var run: ReEnchantedCompassWidgetRun
    var step: CompassWidgetStep
    var compassRun: ReEnchantedWidgetCompassRun?

    var body: some View {
        ReWidgetBackground {
            ParchmentPanel(accent: .teal) {
                VStack(alignment: .leading, spacing: 10) {
                    CompassHeader(run: run)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(run.isStarted ? step.title : (compassRun?.title ?? "Begin a Compass Run"))
                                .font(.system(.title2, design: .serif, weight: .bold))
                                .foregroundStyle(ReTheme.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)

                            if let compassRun {
                                CompassRunChips(compassRun: compassRun)
                            }

                            Text(run.isStarted ? promptText : introText)
                                .font(.callout)
                                .foregroundStyle(ReTheme.mutedInk)
                                .lineLimit(5)
                                .minimumScaleFactor(0.72)

                            if let hint = compassRun?.hint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
                                Text(hint)
                                    .font(.caption)
                                    .foregroundStyle(ReTheme.ink.opacity(0.72))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                            }

                            Spacer(minLength: 0)
                            FullCompassControls(run: run)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 6) {
                            ForEach(CompassWidgetStep.steps) { compassStep in
                                CompassDirectionRow(
                                    step: compassStep,
                                    state: directionState(for: compassStep),
                                    prompt: compassRun?.prompt(forStepIndex: compassStep.id)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var introText: String {
        guard let compassRun else {
            return snapshot.compass?.prompt ?? "Bring back one true sentence from wherever you are."
        }
        return "\(compassRun.north) Start when you can give it \(compassRun.timeBox)."
    }

    private var promptText: String {
        compassRun?.prompt(forStepIndex: step.id) ?? step.prompt
    }

    private func directionState(for compassStep: CompassWidgetStep) -> CompassDirectionRow.State {
        guard run.isStarted else { return compassStep.id == 0 ? .current : .future }
        if compassStep.id < run.stepIndex { return .complete }
        if compassStep.id == run.stepIndex { return .current }
        return .future
    }
}

private struct CompassHeader: View {
    var run: ReEnchantedCompassWidgetRun

    var body: some View {
        HStack {
            WidgetHeader(title: "Wonder Compass", symbolName: "safari", accent: .teal)
            Spacer(minLength: 6)
            Text(run.isStarted ? "Underway" : "Ready")
                .font(.caption2.weight(.bold))
                .foregroundStyle(ReTheme.teal)
        }
    }
}

private struct CompassDirectionRow: View {
    enum State {
        case complete
        case current
        case future
    }

    var step: CompassWidgetStep
    var state: State
    var prompt: String?

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(iconColor)
                .frame(width: 20, height: 20)
                .background(iconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(prompt ?? step.prompt)
                    .font(.caption2)
                    .foregroundStyle(ReTheme.mutedInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var symbolName: String {
        switch state {
        case .complete:
            return "checkmark"
        case .current:
            return step.symbolName
        case .future:
            return "circle"
        }
    }

    private var iconColor: Color {
        switch state {
        case .complete:
            return ReTheme.night
        case .current:
            return ReTheme.night
        case .future:
            return ReTheme.teal.opacity(0.75)
        }
    }

    private var iconBackground: Color {
        switch state {
        case .complete:
            return ReTheme.gold
        case .current:
            return ReTheme.teal.opacity(0.28)
        case .future:
            return ReTheme.paper.opacity(0.52)
        }
    }

    private var rowBackground: Color {
        switch state {
        case .current:
            return ReTheme.teal.opacity(0.12)
        case .complete:
            return ReTheme.gold.opacity(0.12)
        case .future:
            return ReTheme.paper.opacity(0.20)
        }
    }
}

private struct CompassRunChips: View {
    var compassRun: ReEnchantedWidgetCompassRun

    var body: some View {
        HStack(spacing: 5) {
            CompassRunChip(text: compassRun.mode)
            CompassRunChip(text: compassRun.timeBox)
            CompassRunChip(text: compassRun.place)
        }
    }
}

private struct CompassRunChip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(ReTheme.teal)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(ReTheme.teal.opacity(0.12), in: Capsule())
    }
}

private struct CompassProgress: View {
    var stepIndex: Int
    var isStarted: Bool

    var body: some View {
        Capsule()
            .fill(isStarted ? ReTheme.teal : ReTheme.mutedInk.opacity(0.24))
            .frame(height: 5)
            .accessibilityLabel(isStarted ? "The Compass Run is underway" : "The Compass Run is ready")
    }
}

private struct CompactCompassControls: View {
    var run: ReEnchantedCompassWidgetRun

    var body: some View {
        HStack(spacing: 6) {
            if run.isComplete {
                Button(intent: ReEnchantedOpenCompassIntent()) {
                    Image(systemName: "book.closed")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ReTheme.night)
                        .frame(width: 34, height: 28)
                        .background(ReTheme.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button(intent: ReEnchantedAdvanceCompassIntent()) {
                    Image(systemName: run.isStarted ? "arrow.right" : "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ReTheme.night)
                        .frame(width: 34, height: 28)
                        .background(ReTheme.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button(intent: ReEnchantedResetCompassIntent()) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReTheme.teal)
                    .frame(width: 30, height: 28)
                    .background(ReTheme.paper.opacity(0.62), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FullCompassControls: View {
    var run: ReEnchantedCompassWidgetRun

    var body: some View {
        HStack(spacing: 7) {
            if run.isComplete {
                Button(intent: ReEnchantedOpenCompassIntent()) {
                    CompassControlLabel(title: "Keep to Book", symbolName: "book.closed", filled: true)
                }
                .buttonStyle(.plain)
            } else {
                Button(intent: ReEnchantedAdvanceCompassIntent()) {
                    CompassControlLabel(title: run.isStarted ? "Next" : "Start", symbolName: run.isStarted ? "arrow.right" : "play.fill", filled: true)
                }
                .buttonStyle(.plain)
            }

            Button(intent: ReEnchantedResetCompassIntent()) {
                CompassControlLabel(title: "Reset", symbolName: "arrow.counterclockwise", filled: false)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CompassControlLabel: View {
    var title: String
    var symbolName: String
    var filled: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(filled ? ReTheme.night : ReTheme.teal)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(filled ? ReTheme.gold : ReTheme.paper.opacity(0.62), in: Capsule())
        .overlay {
            if !filled {
                Capsule().stroke(ReTheme.teal.opacity(0.35), lineWidth: 1)
            }
        }
    }
}

private struct RememberedWidgetView: View {
    let entry: ReEnchantedWidgetEntry

    var body: some View {
        Link(destination: deepLinkURL("remembered")) {
            ReWidgetBackground {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "Returned From the Stacks", symbolName: "clock.arrow.circlepath", accent: .gold)
                    Spacer(minLength: 0)
                    Text(entry.snapshot.remembered?.title ?? "The Book Remembers")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.gold)
                        .lineLimit(2)
                    Text(entry.snapshot.remembered?.body ?? "No old page is calling yet.")
                        .font(.caption)
                        .foregroundStyle(ReTheme.paperText)
                        .lineLimit(3)
                    NoteStrip(text: entry.snapshot.remembered?.ageLine ?? "Open the stacks", tint: .gold)
                }
            }
        }
    }
}

private struct GlowWidgetView: View {
    let entry: ReEnchantedWidgetEntry

    var body: some View {
        Link(destination: deepLinkURL("glow")) {
            ReWidgetBackground {
                VStack(alignment: .leading, spacing: 10) {
                    GlowPill(text: glowTitle)
                    Text("The current belief state is \(glowLine.lowercased()).")
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.paperText)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        GlowShortcut(title: "Cast", symbol: "person.2", tint: .rose)
                        GlowShortcut(title: "Spells", symbol: "sparkles", tint: .gold)
                        GlowShortcut(title: "Pages", symbol: "doc.text", tint: .teal)
                    }
                }
            }
        }
    }

    private var glowTitle: String {
        entry.snapshot.belief?.detail ?? "Warming Glow"
    }

    private var glowLine: String {
        switch entry.snapshot.belief?.level ?? 30 {
        case ..<12: return "low ember"
        case 12..<35: return "steady"
        case 35..<70: return "bright"
        default: return "luminous"
        }
    }
}

private struct SmallTodayPage: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var body: some View {
        Link(destination: deepLinkURL(snapshot.today.urlPath)) {
            ReWidgetBackground {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "ReEnchanted", symbolName: snapshot.today.symbolName, accent: .gold)
                    Spacer(minLength: 0)
                    Text(snapshot.today.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.gold)
                        .lineLimit(3)
                        .minimumScaleFactor(0.74)
                    Text(snapshot.today.source.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ReTheme.teal)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct MediumTodayPage: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var body: some View {
        ReWidgetBackground {
            HStack(spacing: 12) {
                Link(destination: deepLinkURL(snapshot.today.urlPath)) {
                    VStack(alignment: .leading, spacing: 7) {
                        WidgetHeader(title: snapshot.today.source, symbolName: snapshot.today.symbolName, accent: .gold)
                        Text(snapshot.today.title)
                            .font(.system(.headline, design: .serif, weight: .bold))
                            .foregroundStyle(ReTheme.gold)
                            .lineLimit(2)
                        Text(snapshot.today.body)
                            .font(.caption)
                            .foregroundStyle(ReTheme.paperText)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Link(destination: deepLinkURL("capture/souvenir")) {
                    ParchmentPanel(accent: .teal) {
                        VStack(alignment: .leading, spacing: 7) {
                            WidgetHeader(title: "Keep One", symbolName: "quote.opening", accent: .teal)
                            Text(snapshot.bookInterior?.line ?? snapshot.compass?.prompt ?? "Bring back one true sentence from today.")
                                .font(.system(.callout, design: .serif, weight: .bold))
                                .foregroundStyle(ReTheme.ink)
                                .lineLimit(5)
                        }
                    }
                }
            }
        }
    }
}

private struct OpenDesk: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var body: some View {
        ReWidgetBackground {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    WidgetHeader(title: greeting, symbolName: "book.closed", accent: .gold)
                    Spacer()
                    GlowPill(text: snapshot.belief?.detail ?? "Glow")
                }
                if let interior = snapshot.bookInterior {
                    Label(interior.line, systemImage: interior.symbolName)
                        .font(.caption)
                        .foregroundStyle(ReTheme.paperText)
                        .lineLimit(2)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    DeskTile(title: snapshot.today.title, detail: snapshot.today.body, symbolName: snapshot.today.symbolName, path: snapshot.today.urlPath, tint: .gold)
                    DeskTile(title: "Radio", detail: snapshot.radio?.title ?? "The dial is waiting.", symbolName: "radio", path: "radio", tint: .gold)
                    if let event = snapshot.worldEvent {
                        DeskTile(title: event.title, detail: event.phase, symbolName: event.symbolName, path: event.urlPath, tint: .rose)
                    } else {
                        DeskTile(title: "Enchantment", detail: snapshot.enchantments.first?.title ?? "Pick a spell and take a photo.", symbolName: "camera.macro", path: "enchantment", tint: .rose)
                    }
                    DeskTile(title: snapshot.compass?.title ?? "Wonder Compass", detail: snapshot.compass?.prompt ?? "Choose one thing to notice.", symbolName: "safari", path: "compass", tint: .teal)
                }
            }
        }
    }

    private var greeting: String {
        if let name = snapshot.readerName, !name.isEmpty {
            return "Open Desk, \(name)"
        }
        return "The Open Desk"
    }
}

private struct SmallRadio: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var radio: ReEnchantedWidgetRadio {
        snapshot.radio ?? ReEnchantedWidgetSnapshot.fallback.radio!
    }

    var body: some View {
        ReWidgetBackground {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: radio.isPlaying ? "On Air" : "Radio", symbolName: "radio", accent: .gold)
                Spacer(minLength: 0)
                RadioDial(frequency: radio.frequency)
                    .frame(height: 54)
                Text(radio.title)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(ReTheme.gold)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if radio.isPlaying {
                        StopRadioButton(compact: true)
                    } else {
                        TuneRadioButton(stationID: radio.activeStationID ?? radio.stations.first?.id ?? "fae-fi", title: "Play", compact: true)
                    }
                    Text(radio.frequency)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ReTheme.teal)
                }
            }
        }
    }
}

private struct MediumRadio: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var radio: ReEnchantedWidgetRadio {
        snapshot.radio ?? ReEnchantedWidgetSnapshot.fallback.radio!
    }

    var body: some View {
        ReWidgetBackground {
            HStack(spacing: 12) {
                RadioDial(frequency: radio.frequency)
                    .frame(width: 92)
                VStack(alignment: .leading, spacing: 7) {
                    WidgetHeader(title: radio.isPlaying ? "ReEnchanted Radio - On Air" : "ReEnchanted Radio", symbolName: "radio", accent: .gold)
                    Text(radio.title)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.gold)
                        .lineLimit(1)
                    Text(radio.signalLine)
                        .font(.caption)
                        .foregroundStyle(ReTheme.paperText)
                        .lineLimit(2)
                    Waveform()
                        .frame(height: 18)
                    HStack(spacing: 7) {
                        if radio.isPlaying {
                            StopRadioButton(compact: false)
                        } else {
                            TuneRadioButton(stationID: radio.activeStationID ?? radio.stations.first?.id ?? "fae-fi", title: "Play", compact: false)
                        }
                        ForEach(radio.stations.prefix(2)) { station in
                            TuneRadioButton(stationID: station.id, title: station.title, compact: false)
                        }
                    }
                }
            }
        }
    }
}

private struct LargeRadio: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var radio: ReEnchantedWidgetRadio {
        snapshot.radio ?? ReEnchantedWidgetSnapshot.fallback.radio!
    }

    var body: some View {
        ReWidgetBackground {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "ReEnchanted Radio", symbolName: "radio", accent: .gold)
                HStack(spacing: 12) {
                    RadioDial(frequency: radio.frequency)
                        .frame(width: 100, height: 100)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(radio.title)
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(ReTheme.gold)
                        Text(radio.detail)
                            .font(.caption)
                            .foregroundStyle(ReTheme.paperText)
                            .lineLimit(3)
                        Waveform()
                            .frame(height: 22)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(radio.stations.prefix(4)) { station in
                        Link(destination: deepLinkURL("radio/tune/\(station.id)")) {
                            StationTile(
                                station: station,
                                isActive: radio.isPlaying && radio.activeStationID == station.id
                            )
                        }
                    }
                }
                StopRadioButton(compact: false)
            }
        }
    }
}

private struct SmallEnchantment: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var enchantment: ReEnchantedWidgetEnchantment {
        snapshot.enchantments.first ?? ReEnchantedWidgetSnapshot.fallback.enchantments[0]
    }

    var body: some View {
        Link(destination: deepLinkURL(enchantment.urlPath)) {
            ReWidgetBackground {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "Enchantment", symbolName: "camera.macro", accent: .rose)
                    Spacer(minLength: 0)
                    Image(systemName: enchantment.symbolName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(ReTheme.gold)
                    Text(enchantment.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.gold)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct MediumEnchantment: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var enchantment: ReEnchantedWidgetEnchantment {
        snapshot.enchantments.first ?? ReEnchantedWidgetSnapshot.fallback.enchantments[0]
    }

    var body: some View {
        Link(destination: deepLinkURL(enchantment.urlPath)) {
            ReWidgetBackground {
                HStack(spacing: 12) {
                    PhotoFramePreview(symbolName: enchantment.symbolName)
                        .frame(width: 108)
                    VStack(alignment: .leading, spacing: 7) {
                        WidgetHeader(title: "Choose Spell. Take Photo.", symbolName: "sparkles", accent: .rose)
                        Text(enchantment.title)
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(ReTheme.gold)
                            .lineLimit(2)
                        Text(enchantment.detail)
                            .font(.caption)
                            .foregroundStyle(ReTheme.paperText)
                            .lineLimit(3)
                        NoteStrip(text: "Keep it to the Book", tint: .rose)
                    }
                }
            }
        }
    }
}

private struct LargeEnchantment: View {
    let snapshot: ReEnchantedWidgetSnapshot

    var enchantments: [ReEnchantedWidgetEnchantment] {
        let items = snapshot.enchantments
        return items.isEmpty ? ReEnchantedWidgetSnapshot.fallback.enchantments : items
    }

    var body: some View {
        ReWidgetBackground {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "Enchantment Cabinet", symbolName: "camera.macro", accent: .rose)
                HStack(spacing: 12) {
                    PhotoFramePreview(symbolName: enchantments[0].symbolName)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(enchantments.prefix(3)) { enchantment in
                            Link(destination: deepLinkURL(enchantment.urlPath)) {
                                SpellRow(enchantment: enchantment)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DeskTile: View {
    var title: String
    var detail: String
    var symbolName: String
    var path: String
    var tint: ReAccent

    var body: some View {
        Link(destination: deepLinkURL(path)) {
            ParchmentPanel(accent: tint) {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint.color)
                    Text(title)
                        .font(.system(.callout, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.ink)
                        .lineLimit(2)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(ReTheme.mutedInk)
                        .lineLimit(3)
                }
            }
            .frame(minHeight: 92)
        }
    }
}

private struct TuneRadioButton: View {
    var stationID: String
    var title: String
    var compact: Bool

    var body: some View {
        Link(destination: deepLinkURL("radio/tune/\(stationID)")) {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(ReTheme.night)
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 5 : 6)
            .background(ReTheme.gold, in: Capsule())
        }
    }
}

private struct StopRadioButton: View {
    var compact: Bool

    var body: some View {
        Link(destination: deepLinkURL("radio/stop")) {
            HStack(spacing: 4) {
                Image(systemName: "stop.fill")
                Text("Stop")
                    .lineLimit(1)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(ReTheme.paperText)
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 5 : 6)
            .background(ReTheme.night.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(ReTheme.gold.opacity(0.55), lineWidth: 1))
        }
    }
}

private struct StationTile: View {
    var station: ReEnchantedWidgetRadioStation
    var isActive: Bool

    var body: some View {
        ParchmentPanel(accent: .gold) {
            HStack(spacing: 8) {
                Seal(symbolName: isActive ? "waveform" : "radio", tint: .gold)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ReTheme.ink)
                        .lineLimit(1)
                    Text(station.frequency)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ReTheme.teal)
                        .lineLimit(1)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isActive {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ReTheme.gold)
                    .padding(6)
            }
        }
    }
}

private struct SpellRow: View {
    var enchantment: ReEnchantedWidgetEnchantment

    var body: some View {
        ParchmentPanel(accent: .rose) {
            HStack(spacing: 8) {
                Image(systemName: enchantment.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReTheme.rose)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(enchantment.title)
                        .font(.system(.callout, design: .serif, weight: .bold))
                        .foregroundStyle(ReTheme.ink)
                        .lineLimit(1)
                    Text(enchantment.detail)
                        .font(.caption2)
                        .foregroundStyle(ReTheme.mutedInk)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct WidgetHeader: View {
    var title: String
    var symbolName: String
    var accent: ReAccent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(accent.color)
        .textCase(.uppercase)
    }
}

private struct GlowPill: View {
    var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(ReTheme.gold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ReTheme.night.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(ReTheme.gold.opacity(0.55), lineWidth: 1))
    }
}

private struct GlowShortcut: View {
    var title: String
    var symbol: String
    var tint: ReAccent

    var body: some View {
        VStack(spacing: 6) {
            Seal(symbolName: symbol, tint: tint)
                .frame(width: 42, height: 42)
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(ReTheme.paperText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RadioDial: View {
    var frequency: String

    var body: some View {
        ZStack {
            Circle()
                .fill(ReTheme.night)
                .overlay(Circle().stroke(ReTheme.gold.opacity(0.7), lineWidth: 2))
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index % 3 == 0 ? ReTheme.gold : ReTheme.paperText.opacity(0.45))
                    .frame(width: 2, height: index % 3 == 0 ? 14 : 8)
                    .offset(y: -35)
                    .rotationEffect(.degrees(Double(index) * 20))
            }
            VStack(spacing: 1) {
                Text(frequency)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(ReTheme.gold)
                Text("FM")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ReTheme.teal)
            }
        }
    }
}

private struct Waveform: View {
    private let heights: [CGFloat] = [0.35, 0.8, 0.45, 1, 0.62, 0.3, 0.74, 0.5, 0.9, 0.4, 0.68]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(ReTheme.teal.opacity(0.9))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(y: height, anchor: .center)
            }
        }
    }
}

private struct PhotoFramePreview: View {
    var symbolName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ReTheme.paper.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(ReTheme.gold.opacity(0.55), lineWidth: 1))
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), ReTheme.teal.opacity(0.24), ReTheme.rose.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(12)
            Image(systemName: symbolName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(ReTheme.ink.opacity(0.7))
            PaperScrap(text: "The frame is fictional.", tint: .gold)
                .offset(x: -16, y: -42)
            PaperScrap(text: "The attention is real.", tint: .teal)
                .offset(x: 26, y: 48)
        }
        .frame(minHeight: 118)
    }
}

private struct ParchmentPanel<Content: View>: View {
    var accent: ReAccent
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [ReTheme.paper, ReTheme.paper.opacity(0.76)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent.color.opacity(0.45), lineWidth: 1)
            }
    }
}

private struct ReWidgetBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            ReTheme.night
            OrbitalLines()
            Speckles()
            content
                .padding(14)
        }
        .containerBackground(for: .widget) {
            ReTheme.night
        }
    }
}

private struct OrbitalLines: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(ReTheme.gold.opacity(0.08), lineWidth: 1)
                    .scaleEffect(1 + CGFloat(index) * 0.34)
                    .offset(x: 70, y: -26)
            }
        }
    }
}

private struct Speckles: View {
    private let points: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.18), CGPoint(x: 0.28, y: 0.74), CGPoint(x: 0.48, y: 0.24),
        CGPoint(x: 0.66, y: 0.68), CGPoint(x: 0.84, y: 0.32), CGPoint(x: 0.91, y: 0.82)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(ReTheme.gold.opacity(0.25))
                    .frame(width: 3, height: 3)
                    .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
            }
        }
    }
}

private struct Seal: View {
    var symbolName: String
    var tint: ReAccent

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.color.opacity(0.72))
            Circle()
                .stroke(Color.white.opacity(0.32), lineWidth: 1.2)
                .padding(4)
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.95))
        }
    }
}

private struct NoteStrip: View {
    var text: String
    var tint: ReAccent

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint.color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(ReTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct PaperScrap: View {
    var text: String
    var tint: ReAccent

    var body: some View {
        Text(text)
            .font(.system(size: 8, design: .serif).weight(.semibold))
            .foregroundStyle(ReTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(ReTheme.paper, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(tint.color.opacity(0.35), lineWidth: 0.8))
            .rotationEffect(.degrees(-3))
    }
}

private enum ReAccent {
    case gold
    case teal
    case rose

    var color: Color {
        switch self {
        case .gold: return ReTheme.gold
        case .teal: return ReTheme.teal
        case .rose: return ReTheme.rose
        }
    }
}

private enum ReTheme {
    static let night = Color(red: 0.025, green: 0.023, blue: 0.045)
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.40)
    static let teal = Color(red: 0.05, green: 0.54, blue: 0.56)
    static let rose = Color(red: 0.64, green: 0.23, blue: 0.36)
    static let paper = Color(red: 0.88, green: 0.79, blue: 0.58)
    static let ink = Color(red: 0.16, green: 0.12, blue: 0.08)
    static let mutedInk = Color(red: 0.39, green: 0.33, blue: 0.25)
    static let paperText = Color(red: 0.83, green: 0.78, blue: 0.66)
}

private func deepLinkURL(_ path: String) -> URL {
    URL(string: "reenchanted://\(path)") ?? URL(string: "reenchanted://today")!
}

private struct ReEnchantedTodayWidget: Widget {
    let kind = "ReEnchantedTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("ReEnchanted")
        .description("A page the Book left open for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private struct ReEnchantedRadioWidget: Widget {
    let kind = "ReEnchantedRadioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            RadioWidgetView(entry: entry)
        }
        .configurationDisplayName("ReEnchanted Radio")
        .description("Tune the station the Book is hearing.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private struct ReEnchantedEnchantmentWidget: Widget {
    let kind = "ReEnchantedEnchantmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            EnchantmentWidgetView(entry: entry)
        }
        .configurationDisplayName("ReEnchanted Enchantment")
        .description("Pick a spell, take a photo, and keep the result to the Book.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private struct ReEnchantedCompassWidget: Widget {
    let kind = "ReEnchantedCompassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            CompassWidgetView(entry: entry)
        }
        .configurationDisplayName("Wonder Compass")
        .description("Guide a full five-direction Compass Run from noticing to return.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private struct ReEnchantedRememberedWidget: Widget {
    let kind = "ReEnchantedRememberedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            RememberedWidgetView(entry: entry)
        }
        .configurationDisplayName("Returned From the Stacks")
        .description("A remembered page when the Book wants it near today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ReEnchantedGlowWidget: Widget {
    let kind = "ReEnchantedGlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            GlowWidgetView(entry: entry)
        }
        .configurationDisplayName("ReEnchanted Glow")
        .description("A quick view of the current glow state and its doors.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ReEnchantedQuestionWidget: Widget {
    let kind = "ReEnchantedQuestionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReEnchantedWidgetProvider()) { entry in
            QuestionWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("A Question from the Book")
        .description("One quiet return question on the Lock Screen.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ReEnchantedWidgets: WidgetBundle {
    var body: some Widget {
        ReEnchantedTodayWidget()
        ReEnchantedRadioWidget()
        ReEnchantedEnchantmentWidget()
        ReEnchantedCompassWidget()
        ReEnchantedRememberedWidget()
        ReEnchantedGlowWidget()
        ReEnchantedQuestionWidget()
    }
}
