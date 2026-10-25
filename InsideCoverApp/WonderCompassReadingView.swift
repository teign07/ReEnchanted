import SwiftUI
#if canImport(QuickLook)
import QuickLook
#endif

/// The same reading door serves Contents and the chapter-preview leaves.
/// Images stay beside their authored passages; ordinary Compass errands and
/// short chapter quotations do not acquire a whole chapter's illustrations.
///
/// Each block is its own row of the folio stack, so a leaf turns between
/// paragraphs rather than through the middle of a line.
struct WonderCompassReadingView: View {
    private let blocks: [WonderCompassBlock]
    private let direction: WonderCompassDirection?
    private let onOpenSection: (String) -> Void
    @State private var previewURL: URL?

    /// `blockRange` draws part of a section; the debug layout render uses it.
    init(snippet: ReferenceSnippet, text: String, blockRange: Range<Int>? = nil,
         onOpenSection: @escaping (String) -> Void) {
        let blocks = snippet.wonderCompassBlocks(for: text)
        self.blocks = blockRange.map { Array(blocks[$0.clamped(to: blocks.indices)]) } ?? blocks
        direction = blocks.lazy.compactMap { block -> WonderCompassDirection? in
            if case .opener(_, _, let direction) = block { return direction }
            return nil
        }.first
        self.onOpenSection = onOpenSection
    }

    var body: some View {
        FolioControlStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        #if canImport(QuickLook)
        .quickLookPreview($previewURL)
        #endif
    }

    /// The chapter's own quarter of the Compass tints its marks.
    private var accent: Color { direction?.ink ?? BookPalette.teal }

    @ViewBuilder
    private func view(for block: WonderCompassBlock) -> some View {
        switch block {
        case .part(let label, let title, let subtitle):
            WonderCompassPartTitle(label: label, title: title, subtitle: subtitle)
        case .opener(let kicker, let title, let direction):
            WonderCompassChapterTitle(kicker: kicker, title: title, direction: direction)
        case .lede(let text):
            lede(text)
        case .heading(let text, let major):
            heading(text, major: major)
        case .kicker(let text):
            kicker(text)
        case .compass(let direction, let label, let detail, let text):
            WonderCompassStep(direction: direction, label: label, detail: detail, text: text)
        case .labeled(let label, let text):
            labeled(label, text)
        case .list(let items):
            list(items, numbered: false)
        case .numbered(let items):
            list(items, numbered: true)
        case .prose(let text):
            prose(text)
        case .keyLine(let text):
            keyLine(text)
        case .summary(let title, let items):
            card(title: title, symbol: "book.closed", tint: BookPalette.gold, items: items)
        case .quickWin(let title, let items):
            card(title: title, symbol: "sparkles", tint: accent, items: items)
        case .certificate(let title, let items):
            WonderCompassCertificate(title: title, items: items)
        case .souvenir(let title, let lines):
            WonderCompassSouvenirLines(title: title, lines: lines, tint: accent)
        case .credit(let text):
            Text(text)
                .font(.system(.caption2, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.5))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        case .caption(let text):
            Text(text.uppercased())
                .font(.system(.caption, design: .serif).weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        case .illustration(let illustration):
            plate(illustration)
        case .contents(let links):
            contents(links)
        }
    }

    // MARK: Prose

    private func prose(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .serif))
            .lineSpacing(3)
            .foregroundStyle(BookPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The chapter opens the way a printed book does: its first words in
    /// small capitals, in the chapter's ink.
    private func lede(_ text: String) -> some View {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        let leadCount = min(words.count, 4)
        let lead = words.prefix(leadCount).joined(separator: " ")
        let rest = words.dropFirst(leadCount).joined(separator: " ")
        return (Text(lead)
            .font(.system(.body, design: .serif).weight(.semibold).smallCaps())
            .foregroundColor(accent)
            + Text(rest.isEmpty ? "" : " " + rest)
            .font(.system(.body, design: .serif))
            .foregroundColor(BookPalette.ink))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private func heading(_ text: String, major: Bool) -> some View {
        let parts = Self.headingParts(text)
        return VStack(alignment: .leading, spacing: 4) {
            if major {
                WonderCompassRule(tint: accent)
                    .padding(.bottom, 8)
            }
            if let label = parts.label {
                kicker(label)
            }
            Text(parts.title)
                .font(.custom("Baskerville-SemiBold", size: major ? 25 : 21, relativeTo: major ? .title2 : .title3))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, major ? 18 : 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The Adventure Recipe's three ingredients carry the infographic's marks.
    static func recipeSymbol(_ label: String) -> String? {
        switch label {
        case "Destination": return "mappin.and.ellipse"
        case "Delight": return "gift"
        case "Definition": return "timer"
        default: return nil
        }
    }

    /// "The Science: Why Motivation Is a Myth" sets its label above the title.
    static func headingParts(_ text: String) -> (label: String?, title: String) {
        guard let colon = text.firstIndex(of: ":") else { return (nil, text) }
        let label = String(text[..<colon])
        let title = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, WonderCompassFormatter.isHeadingLabel(label) else { return (nil, text) }
        return (label, title)
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .serif).weight(.bold))
            .tracking(1.6)
            .foregroundStyle(accent)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        let mark = Self.recipeSymbol(label).map {
            Text(Image(systemName: $0)).font(.footnote).foregroundColor(accent) + Text(" ")
        } ?? Text("")
        return (mark
            + Text(label + ": ")
            .font(.system(.body, design: .serif).weight(.semibold))
            .foregroundColor(accent)
            + Text(text)
            .font(.system(.body, design: .serif))
            .foregroundColor(BookPalette.ink))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func list(_ items: [String], numbered: Bool) -> some View {
        // Folio rows, so a long list turns the leaf between items.
        FolioControlStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let parts = numbered ? Self.numberParts(item) : (marker: nil, text: item)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let marker = parts.marker {
                        Text(marker)
                            .font(.custom("Baskerville-SemiBold", size: 17, relativeTo: .body))
                            .foregroundStyle(accent)
                            .frame(minWidth: 18, alignment: .trailing)
                    } else {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(BookPalette.gold)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                            .frame(width: 10)
                            .accessibilityHidden(true)
                    }
                    listItem(parts.text)
                }
            }
        }
        .padding(.leading, 4)
    }

    /// "Tracking alone: 38% success" keeps its label in the chapter's ink.
    @ViewBuilder
    private func listItem(_ item: String) -> some View {
        if case .labeled(let label, let text)? = WonderCompassFormatter.labeled(item) {
            labeled(label, text)
        } else {
            prose(item)
        }
    }

    static func numberParts(_ item: String) -> (marker: String?, text: String) {
        guard let range = item.range(of: #"^[0-9]+[.)]\s*"#, options: .regularExpression) else { return (nil, item) }
        return (item[range].trimmingCharacters(in: .whitespaces), String(item[range.upperBound...]))
    }

    private func keyLine(_ text: String) -> some View {
        VStack(spacing: 10) {
            WonderCompassRule(tint: accent, short: true)
            Text(text)
                .font(.custom("Baskerville-Italic", size: 22, relativeTo: .title3))
                .foregroundStyle(BookPalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            WonderCompassRule(tint: accent, short: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Cards

    private func card(title: String, symbol: String, tint: Color, items: [WonderCompassBlock]) -> some View {
        FolioControlStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
                Text(title.uppercased())
                    .font(.system(.footnote, design: .serif).weight(.bold))
                    .tracking(1.6)
            }
            .foregroundStyle(tint)
            .accessibilityAddTraits(.isHeader)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                // A card's rows are themselves blocks; erase the recursion.
                AnyView(view(for: item))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(tint.opacity(0.45), lineWidth: 1)
                .padding(3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.top, 8)
    }

    // MARK: Contents and plates

    private func contents(_ links: [ReferenceContentsLink]) -> some View {
        FolioControlStack(alignment: .leading, spacing: 0) {
            ForEach(links) { link in
                Button {
                    onOpenSection(link.sectionID)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(link.label)
                            .font(.system(.body, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(BookPalette.teal)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this section of The Wonder Compass")
                .folioControlUnbroken()
            }
        }
    }

    @ViewBuilder
    private func plate(_ illustration: ReferenceIllustration) -> some View {
        if let url = Bundle.main.url(
            forResource: illustration.fileName,
            withExtension: nil,
            subdirectory: "WonderCompassImages"
        ) {
            Button {
                BookFeedback.play(.openPage)
                previewURL = url
            } label: {
                VStack(alignment: .trailing, spacing: 5) {
                    // Display-sized decoding is asynchronous and cached. Quick
                    // Look opens the full-resolution bundled image for zoom.
                    BookMarginaliaImage(assetName: url.path)
                        .aspectRatio(
                            CGFloat(illustration.pixelWidth) / CGFloat(max(1, illustration.pixelHeight)),
                            contentMode: .fit
                        )
                        .frame(maxWidth: .infinity, maxHeight: 380)
                        .accessibilityHidden(true)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.6))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(illustration.title)
            .accessibilityHint("Opens the full-screen image. Pinch to zoom and drag to look around.")
            .folioControlUnbroken()
        }
    }
}

extension WonderCompassDirection {
    /// North teal, East gold, South violet, West rubric, Center paper-brown.
    var ink: Color {
        switch self {
        case .north: return BookPalette.teal
        case .east: return BookPalette.gold
        case .south: return BookPalette.violet
        case .west: return BookPalette.rubricRed
        case .center: return BookPalette.parchmentEdge
        }
    }
}

// MARK: - Title pages

private struct WonderCompassPartTitle: View {
    let label: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 10) {
            WonderCompassRose(direction: nil)
                .frame(width: 44, height: 44)
            Text(label.uppercased())
                .font(.system(.footnote, design: .serif).weight(.bold))
                .tracking(3)
                .foregroundStyle(BookPalette.gold)
            Text(title)
                .font(.custom("Baskerville-SemiBold", size: 28, relativeTo: .title))
                .foregroundStyle(BookPalette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.custom("Baskerville-Italic", size: 18, relativeTo: .body))
                    .foregroundStyle(BookPalette.ink.opacity(0.75))
            }
            WonderCompassRule(tint: BookPalette.gold)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct WonderCompassChapterTitle: View {
    let kicker: String?
    let title: String
    let direction: WonderCompassDirection?

    var body: some View {
        VStack(spacing: 12) {
            WonderCompassRose(direction: direction)
                .frame(width: 72, height: 72)
            if let kicker {
                Text(kicker.uppercased())
                    .font(.system(.footnote, design: .serif).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(direction?.ink ?? BookPalette.rubricRed)
            }
            Text(title)
                .font(.custom("Baskerville-SemiBold", size: 32, relativeTo: .largeTitle))
                .foregroundStyle(BookPalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            WonderCompassRule(tint: direction?.ink ?? BookPalette.gold)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A four-point compass star. The chapter's own quarter is inked in its
/// colour; the others stay as faint gold guide lines.
struct WonderCompassRose: View {
    let direction: WonderCompassDirection?

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let long = min(size.width, size.height) / 2
            let short = long * 0.22
            let quarters: [(WonderCompassDirection, CGFloat)] = [
                (.north, -.pi / 2), (.east, 0), (.south, .pi / 2), (.west, .pi),
            ]
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - long * 0.62, y: center.y - long * 0.62,
                                       width: long * 1.24, height: long * 1.24)),
                with: .color(BookPalette.gold.opacity(0.45)), lineWidth: 0.8
            )
            for (quarter, angle) in quarters {
                let tip = CGPoint(x: center.x + cos(angle) * long, y: center.y + sin(angle) * long)
                let left = CGPoint(x: center.x + cos(angle - .pi / 2) * short, y: center.y + sin(angle - .pi / 2) * short)
                let right = CGPoint(x: center.x + cos(angle + .pi / 2) * short, y: center.y + sin(angle + .pi / 2) * short)
                var point = Path()
                point.move(to: center)
                point.addLine(to: left)
                point.addLine(to: tip)
                point.addLine(to: right)
                point.closeSubpath()
                let lit = direction == quarter || direction == .center
                let ink = lit ? (direction?.ink ?? BookPalette.gold) : BookPalette.gold
                context.fill(point, with: .color(ink.opacity(lit ? 0.9 : (direction == nil ? 0.55 : 0.22))))
                context.stroke(point, with: .color(ink.opacity(lit ? 1 : 0.45)), lineWidth: 0.6)
            }
            let hub = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: hub), with: .color(direction?.ink ?? BookPalette.gold))
        }
        .accessibilityHidden(true)
    }
}

/// A hairline with a small diamond at its centre.
struct WonderCompassRule: View {
    let tint: Color
    var short = false

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(tint.opacity(0.5)).frame(height: 0.8)
            Image(systemName: "diamond.fill")
                .font(.system(size: 6))
                .foregroundStyle(tint)
            Rectangle().fill(tint.opacity(0.5)).frame(height: 0.8)
        }
        .frame(maxWidth: short ? 120 : .infinity)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Compass steps

private struct WonderCompassStep: View {
    let direction: WonderCompassDirection
    let label: String?
    let detail: String?
    let text: String?

    var body: some View {
        if let text {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                medallion(size: 22)
                // "North: Notice the details…" already says its step.
                (Text(label.map { $0 + "  " } ?? "")
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundColor(direction.ink)
                    + Text(text)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(BookPalette.ink))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(spacing: 12) {
                medallion(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label ?? direction.step)
                        .font(.custom("Baskerville-SemiBold", size: 20, relativeTo: .title3))
                        .foregroundStyle(direction.ink)
                    if let detail {
                        Text(detail)
                            .font(.custom("Baskerville-Italic", size: 16, relativeTo: .callout))
                            .foregroundStyle(BookPalette.ink.opacity(0.75))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(direction.ink.opacity(0.08))
            )
            .padding(.top, 6)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    private func medallion(size: CGFloat) -> some View {
        Text(direction.letter)
            .font(.custom("Baskerville-SemiBold", size: size * 0.55, relativeTo: .body))
            .foregroundStyle(BookPalette.page)
            .frame(width: size, height: size)
            .background(Circle().fill(direction.ink))
            .overlay(Circle().strokeBorder(BookPalette.page.opacity(0.6), lineWidth: 1).padding(2))
            .accessibilityLabel(direction.rawValue.capitalized)
    }
}

// MARK: - Certificate

/// A permission slip the reader is meant to sign, set like one: a bordered
/// certificate whose blanks are lines to write on.
private struct WonderCompassCertificate: View {
    let title: String
    let items: [WonderCompassBlock]

    var body: some View {
        FolioControlStack(spacing: 14) {
            WonderCompassRose(direction: nil)
                .frame(width: 30, height: 30)
            Text(title)
                .font(.custom("Baskerville-SemiBold", size: 19, relativeTo: .headline))
                .tracking(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(BookPalette.ink)
            WonderCompassRule(tint: BookPalette.gold, short: true)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                line(for: item)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(BookPalette.page)
        .overlay(Rectangle().strokeBorder(BookPalette.gold.opacity(0.8), lineWidth: 1.5).padding(5))
        .overlay(Rectangle().strokeBorder(BookPalette.gold.opacity(0.5), lineWidth: 0.6).padding(9))
        .shadow(color: BookPalette.parchmentEdge.opacity(0.25), radius: 4, y: 2)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func line(for item: WonderCompassBlock) -> some View {
        switch item {
        case .kicker(let label):
            signature(label)
        case .prose(let text) where text.trimmingCharacters(in: .punctuationCharacters) == "Signed":
            signature(text)
        case .prose(let text), .lede(let text):
            Text(Self.blanked(text))
                .font(.custom("Baskerville-Italic", size: 18, relativeTo: .body))
                .foregroundStyle(BookPalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        case .list(let items):
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, text in
                    Text(Self.blanked(text))
                        .font(.custom("Baskerville-Italic", size: 18, relativeTo: .body))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(BookPalette.ink)
        default:
            Text(Self.blanked(WonderCompassCertificate.plainText(item)))
                .font(.custom("Baskerville-Italic", size: 18, relativeTo: .body))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func signature(_ label: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(label)
                .font(.custom("Baskerville-SemiBold", size: 16, relativeTo: .callout))
                .foregroundStyle(BookPalette.ink.opacity(0.8))
            Rectangle()
                .fill(BookPalette.ink.opacity(0.45))
                .frame(height: 0.8)
                .offset(y: -3)
        }
        .padding(.top, 8)
    }

    /// The print book's blanks ("----", or a run of spaces) become a line
    /// long enough to write on.
    static func blanked(_ text: String) -> String {
        text.replacingOccurrences(of: #"-{3,}"#, with: "_________", options: .regularExpression)
            .replacingOccurrences(of: #" {4,}"#, with: " _________", options: .regularExpression)
    }

    static func plainText(_ block: WonderCompassBlock) -> String {
        switch block {
        case .labeled(let label, let text): return label + ": " + text
        case .heading(let text, _), .keyLine(let text): return text
        default: return ""
        }
    }
}

// MARK: - Souvenir

/// The print book's ruled lines for a One Sentence Souvenir.
private struct WonderCompassSouvenirLines: View {
    let title: String
    let lines: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.custom("BradleyHandITCTT-Bold", size: 20, relativeTo: .title3))
            }
            .foregroundStyle(tint)
            .padding(.bottom, 6)
            ForEach(0..<lines, id: \.self) { _ in
                Rectangle()
                    .fill(BookPalette.ink.opacity(0.22))
                    .frame(height: 0.8)
                    .padding(.top, 30)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(BookPalette.page.opacity(0.7))
                .shadow(color: BookPalette.parchmentEdge.opacity(0.18), radius: 3, y: 1)
        )
        .rotationEffect(.degrees(-0.6))
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }
}
