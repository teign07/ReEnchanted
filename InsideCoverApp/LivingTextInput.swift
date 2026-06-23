import SwiftUI

struct LivingTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat
    var builderPack: SentenceBuilderPack = .core

    @State private var isBuilderOpen = false
    @State private var completedKinds: Set<SentenceBuilderStepKind> = []
    @State private var selectedTokenID: Int?
    @State private var didTransmute = false
    @State private var shimmer = false

    private var engine: SentenceBuilderEngine {
        SentenceBuilderEngine(pack: builderPack)
    }

    private var nudge: SentenceBuilderNudge {
        engine.nudge(for: text, completedKinds: completedKinds)
    }

    private var analysis: SentenceBuilderAnalysis {
        engine.analyze(text)
    }

    private var scaffold: SentenceScaffold {
        engine.scaffold(for: text)
    }

    private var selectedToken: ScaffoldToken? {
        guard let id = selectedTokenID else { return nil }
        return scaffold.tokens.first { $0.id == id }
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var alchemyLevels: [SentenceBuilderAlchemyLevel] {
        engine.alchemyLevels(for: text)
    }

    private var shareText: String {
        engine.souvenirShareText(for: text)
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
            // Drop a stale selection if its word changed out from under us.
            if let id = selectedTokenID, !scaffold.tokens.contains(where: { $0.id == id }) {
                selectedTokenID = nil
            }
            handleTransmutation()
        }
    }

    /// Fire the one-time "Tiny spell" shimmer the moment the sentence becomes vivid.
    private func handleTransmutation() {
        if analysis.isVivid, !didTransmute {
            didTransmute = true
            BookFeedback.play(.keepPage)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shimmer = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.5)) { shimmer = false }
            }
        } else if !analysis.isVivid {
            didTransmute = false
        }
    }

    private var sentenceBuilderDrawer: some View {
        VStack(alignment: .leading, spacing: 12) {
            builderHeader
            livingSentenceCard
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

    // MARK: - Living sentence card

    private var livingSentenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(cardEyebrow)
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

            if hasText {
                tokenStrip
                if let token = selectedToken, token.isTransformable {
                    moveRow(for: token)
                } else {
                    coachLine
                }
            } else {
                Text(builderPack.replayPrompt)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                Text(builderPack.replayHelper)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.64), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((shimmer ? BookPalette.lampGold : BookPalette.teal).opacity(shimmer ? 0.5 : 0.18), lineWidth: shimmer ? 1.5 : 1)
        }
        .shadow(color: BookPalette.lampGold.opacity(shimmer ? 0.45 : 0), radius: shimmer ? 14 : 0)
        .scaleEffect(shimmer ? 1.015 : 1)
    }

    private var cardEyebrow: String {
        if !hasText { return "Catch the first real thing" }
        if selectedToken != nil { return "Transmute the word" }
        if analysis.isVivid { return "A tiny spell" }
        return "Tap a glowing word to deepen it"
    }

    /// The user's own sentence, rendered word-by-word. Craft words glow and are tappable;
    /// misty / stage-smoke words pulse to invite grounding. Glue words stay plain.
    private var tokenStrip: some View {
        FlowLayout(spacing: 5, lineSpacing: 6) {
            ForEach(scaffold.tokens) { token in
                tokenView(token)
            }
        }
    }

    @ViewBuilder
    private func tokenView(_ token: ScaffoldToken) -> some View {
        if token.isTransformable {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    selectedTokenID = (selectedTokenID == token.id) ? nil : token.id
                }
                BookFeedback.play(.tap)
            } label: {
                Text(token.surface.trimmingCharacters(in: .whitespaces))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(roleColor(token.role))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        roleColor(token.role).opacity(selectedTokenID == token.id ? 0.18 : 0.08),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(roleColor(token.role).opacity(roleNeedsHelp(token.role) ? 0.8 : 0.4))
                            .frame(height: roleNeedsHelp(token.role) ? 2 : 1)
                            .padding(.horizontal, 4)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(token.word), \(roleLabel(token.role)). Tap to transmute.")
        } else {
            Text(token.surface.trimmingCharacters(in: .whitespaces))
                .font(.body)
                .foregroundStyle(BookPalette.ink.opacity(0.7))
        }
    }

    private func moveRow(for token: ScaffoldToken) -> some View {
        let moves = engine.moves(for: token, in: scaffold)
        return VStack(alignment: .leading, spacing: 8) {
            Text(moveHint(for: token))
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(moves) { move in
                    Button {
                        apply(move, to: token)
                    } label: {
                        Text(move.label)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(moveTint(move).opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule().stroke(moveTint(move).opacity(0.4), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(moveTint(move))
                    .accessibilityLabel("Change \(token.word) to \(move.word)")
                }
            }
        }
    }

    private var coachLine: some View {
        Group {
            if let diagnostic = analysis.diagnostics.first {
                Label(diagnostic.message, systemImage: diagnostic.severity == .warning ? "exclamationmark.triangle" : "wand.and.stars")
                    .font(.caption2)
                    .foregroundStyle(diagnostic.severity == .warning ? BookPalette.lampGold : BookPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let missing = firstMissingMark {
                Label(missing.hint, systemImage: symbol(for: missing.id))
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Your sentence can stand. Tap any word to push it further.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.teal)
            }
        }
    }

    private var firstMissingMark: SentenceBuilderCraftMark? {
        analysis.craftMarks.first { !$0.isPresent }
    }

    private func apply(_ move: SentenceMove, to token: ScaffoldToken) {
        let updated = scaffold.replacing(tokenID: token.id, with: move.word, using: builderPack)
        text = updated.rendered
        BookFeedback.play(.select)
        // Keep the same slot selected so the user can keep transmuting it.
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            selectedTokenID = token.id
        }
    }

    private func moveHint(for token: ScaffoldToken) -> String {
        switch token.role {
        case .misty: return "'\(token.word)' may be true — give it a body."
        case .smoke: return "Let the magic arrive through matter, not the word '\(token.word)'."
        case .thing: return "Swap the witness. Which real thing remembers it best?"
        case .sense: return "Sharpen the sense — or let one borrow from another."
        case .motion: return "Pick the verb that makes it feel alive."
        case .crossing: return "Cross the wires a different way."
        case .plain: return ""
        }
    }

    private func roleColor(_ role: SentenceRole) -> Color {
        switch role {
        case .thing: return BookPalette.teal
        case .sense: return BookPalette.lampGold
        case .motion: return BookPalette.teal
        case .crossing: return BookPalette.lampGold
        case .misty: return BookPalette.ink.opacity(0.55)
        case .smoke: return BookPalette.lampGold
        case .plain: return BookPalette.ink.opacity(0.7)
        }
    }

    private func roleNeedsHelp(_ role: SentenceRole) -> Bool {
        role == .misty || role == .smoke
    }

    private func roleLabel(_ role: SentenceRole) -> String {
        switch role {
        case .thing: return "a real thing"
        case .sense: return "a sense"
        case .motion: return "a living verb"
        case .crossing: return "a crossed sense"
        case .misty: return "a misty word"
        case .smoke: return "stage smoke"
        case .plain: return "a word"
        }
    }

    private func moveTint(_ move: SentenceMove) -> Color {
        switch move.group {
        case "cross": return BookPalette.lampGold
        case "ground": return BookPalette.teal
        case "sense": return BookPalette.lampGold
        default: return BookPalette.teal
        }
    }

    private var builderActions: some View {
        VStack(alignment: .leading, spacing: 8) {
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

/// A simple wrapping layout: lays children left-to-right, breaking to a new line
/// when the next child would overflow the available width. Powers the token strip
/// so the user's sentence reflows like real prose.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        rows.removeAll()
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = subviews[item].sizeThatFits(.unspecified)
                subviews[item].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.width == 0 ? size.width : current.width + spacing + size.width
            if projected > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
                current.items = [index]
                current.width = size.width
                current.height = size.height
            } else {
                if !current.items.isEmpty { current.width += spacing }
                current.items.append(index)
                current.width += size.width
                current.height = max(current.height, size.height)
            }
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
