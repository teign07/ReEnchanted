import SwiftUI

struct LivingTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat
    var builderPack: SentenceBuilderPack = .core

    @State private var isBuilderOpen = false
    @State private var completedKinds: Set<SentenceBuilderStepKind> = []

    private var engine: SentenceBuilderEngine {
        SentenceBuilderEngine(pack: builderPack)
    }

    private var nudge: SentenceBuilderNudge {
        engine.nudge(for: text, completedKinds: completedKinds)
    }

    private var analysis: SentenceBuilderAnalysis {
        engine.analyze(text)
    }

    private var visibleChips: [String] {
        engine.chips(for: nudge.step, text: text)
    }

    private var alchemyLevels: [SentenceBuilderAlchemyLevel] {
        engine.alchemyLevels(for: text)
    }

    private var shareText: String {
        engine.souvenirShareText(for: text)
    }

    private var orderedBuilderKinds: [SentenceBuilderStepKind] {
        [.anchor, .sense, .motion, .crossing]
    }

    private var currentStepNumber: Int {
        guard let index = orderedBuilderKinds.firstIndex(of: nudge.step.kind) else { return 1 }
        return index + 1
    }

    private var builderStatusText: String {
        if analysis.isVivid {
            return "Strong sentence"
        }
        if analysis.canStandAsComplete {
            return "Enough to keep"
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Start with one real thing"
        }
        return "Keep shaping"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isBuilderOpen.toggle()
                    }
                    BookFeedback.play(.tap)
                } label: {
                    Label(isBuilderOpen ? "Let me write" : "Wake the sentence", systemImage: isBuilderOpen ? "checkmark.seal" : "pencil.and.scribble")
                        .labelStyle(.iconOnly)
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(isBuilderOpen ? BookPalette.teal : BookPalette.lampGold)
                        .background(BookPalette.page.opacity(0.76), in: Circle())
                        .overlay {
                            Circle()
                                .stroke((isBuilderOpen ? BookPalette.teal : BookPalette.lampGold).opacity(0.38), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isBuilderOpen ? "Close sentence builder" : "Wake the sentence")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundStyle(BookPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: minHeight)
                    .dictationInput(text: $text)
                    .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                    }

                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(BookPalette.ink.opacity(0.3))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            if isBuilderOpen {
                sentenceBuilderDrawer
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: text) { _, _ in
            if completedKinds.count >= 3, !analysis.canStandAsComplete {
                completedKinds = []
            }
        }
    }

    private var sentenceBuilderDrawer: some View {
        VStack(alignment: .leading, spacing: 12) {
            builderHeader
            currentStepCard
            builderActions
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        }
    }

    private var builderHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Label(builderPack.ritualTitle, systemImage: "sparkle.magnifyingglass")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                Spacer()
                Text(builderStatusText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(analysis.canStandAsComplete ? BookPalette.teal : BookPalette.ink.opacity(0.56))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(BookPalette.page.opacity(0.64), in: Capsule())
            }

            HStack(spacing: 6) {
                ForEach(analysis.craftMarks) { mark in
                    builderProgressPill(mark)
                }
            }
        }
    }

    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(stepEyebrow)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
                Spacer()
                if let diagnostic = analysis.diagnostics.first {
                    Image(systemName: diagnostic.severity == .warning ? "exclamationmark.triangle.fill" : "wand.and.stars")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(diagnostic.severity == .warning ? BookPalette.lampGold : BookPalette.teal)
                        .accessibilityLabel(diagnostic.title)
                }
            }

            Text(primaryQuestion)
                .font(.callout.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Text(primaryHelper)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            suggestionGrid

            if let diagnostic = analysis.diagnostics.first {
                Text(diagnostic.message)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.18), lineWidth: 1)
        }
    }

    private var stepEyebrow: String {
        if nudge.step.kind == .cutMist || nudge.step.kind == .groundGlow {
            return "Quick fix"
        }
        return "Step \(currentStepNumber) of \(orderedBuilderKinds.count): \(nudge.step.title)"
    }

    private var primaryQuestion: String {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return builderPack.replayPrompt
        }
        return nudge.step.question
    }

    private var primaryHelper: String {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return builderPack.replayHelper
        }
        return nudge.step.helper
    }

    private var suggestionGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(visibleChips, id: \.self) { chip in
                Button {
                    text = engine.append(engine.phrase(for: chip, step: nudge.step), to: text)
                    completedKinds.insert(nudge.step.kind)
                    BookFeedback.play(.select)
                } label: {
                    Text(chip)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(BookPalette.paper.opacity(0.82), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .accessibilityLabel("Add \(chip)")
            }
        }
    }

    private var builderActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    completedKinds.insert(nudge.step.kind)
                    BookFeedback.play(.tap)
                } label: {
                    Label("Skip this step", systemImage: "arrow.right")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(BookPalette.page.opacity(0.58), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.teal)

                Button {
                    completedKinds = []
                    BookFeedback.play(.tap)
                } label: {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(BookPalette.page.opacity(0.58), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
            }

            HStack(spacing: 8) {
                if !shareText.isEmpty {
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(BookPalette.page.opacity(0.58), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BookPalette.teal)
                    .simultaneousGesture(TapGesture().onEnded {
                        BookFeedback.play(.tap)
                    })
                }

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        isBuilderOpen = false
                    }
                    BookFeedback.play(.keepPage)
                } label: {
                    Label(analysis.canStandAsComplete ? "Keep sentence" : "Close helper", systemImage: analysis.canStandAsComplete ? "checkmark" : "xmark")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background((analysis.canStandAsComplete ? BookPalette.lampGold : BookPalette.page).opacity(analysis.canStandAsComplete ? 0.24 : 0.58), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(analysis.canStandAsComplete ? BookPalette.lampGold : BookPalette.ink.opacity(0.58))
            }
        }
    }

    private func builderProgressPill(_ mark: SentenceBuilderCraftMark) -> some View {
        Label(mark.title, systemImage: mark.isPresent ? "checkmark.circle.fill" : symbol(for: mark.id))
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .foregroundStyle(mark.isPresent ? BookPalette.teal : BookPalette.ink.opacity(0.44))
            .background((mark.isPresent ? BookPalette.teal : BookPalette.page).opacity(mark.isPresent ? 0.13 : 0.54), in: Capsule())
            .overlay {
                Capsule()
                    .stroke((mark.isPresent ? BookPalette.teal : BookPalette.ink).opacity(mark.isPresent ? 0.24 : 0.08), lineWidth: 1)
            }
            .accessibilityLabel(mark.isPresent ? "\(mark.title) present" : mark.hint)
    }

    private var replayCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(builderPack.replayPrompt)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
            Text(builderPack.replayHelper)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.lampGold.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private var craftMarks: some View {
        let columns = [GridItem(.adaptive(minimum: 58), spacing: 6)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(analysis.craftMarks) { mark in
                Label(mark.title, systemImage: mark.isPresent ? "seal.fill" : symbol(for: mark.id))
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(mark.isPresent ? BookPalette.teal : BookPalette.ink.opacity(0.46))
                    .background((mark.isPresent ? BookPalette.teal : BookPalette.page).opacity(mark.isPresent ? 0.13 : 0.54), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke((mark.isPresent ? BookPalette.teal : BookPalette.ink).opacity(mark.isPresent ? 0.24 : 0.08), lineWidth: 1)
                    }
                    .accessibilityLabel(mark.isPresent ? "\(mark.title) present" : mark.hint)
            }
        }
    }

    private var alchemyLadder: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(alchemyLevels) { level in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: level.isCurrent ? "seal.fill" : "circle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(level.isCurrent ? BookPalette.lampGold : BookPalette.ink.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(level.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(level.isCurrent ? BookPalette.lampGold : BookPalette.ink.opacity(0.5))
                        Text(level.example)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(level.isCurrent ? 0.72 : 0.46))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(10)
        .background(BookPalette.page.opacity(0.54), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.08), lineWidth: 1)
        }
    }

    private func diagnosticRow(_ diagnostic: SentenceBuilderDiagnostic) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.title)
                    .font(.caption.weight(.bold))
                Text(diagnostic.message)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: diagnostic.severity == .warning ? "exclamationmark.triangle" : "wand.and.stars")
        }
        .foregroundStyle(diagnostic.severity == .warning ? BookPalette.lampGold : BookPalette.teal)
        .padding(9)
        .background(BookPalette.page.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((diagnostic.severity == .warning ? BookPalette.lampGold : BookPalette.teal).opacity(0.2), lineWidth: 1)
        }
    }

    private func symbol(for kind: SentenceBuilderStepKind) -> String {
        switch kind {
        case .anchor: return "smallcircle.filled.circle"
        case .sense: return "hand.draw"
        case .motion: return "wind"
        case .crossing: return "sparkles"
        case .cutMist: return "scissors"
        case .groundGlow: return "lamp.desk"
        }
    }
}
