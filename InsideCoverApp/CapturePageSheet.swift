import SwiftUI
import OSLog
import Darwin.Mach
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif

private extension View {
    func inventoryObjectSurface(accent: Color) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            }
    }
}

#if canImport(UIKit)
// The same file-local serif helper the other renderers carry
// (BookSurfaceViews, ContentViewFeatures, MonthlyEditionPDF): the
// established pattern is a fileprivate copy per rendering file.
private extension UIFont {
    static func serifFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size, weight: weight)
    }
}

enum StudentNoteShareCardRenderer {
    static func render(surface: SurfacePage) -> URL? {
        let size = CGSize(width: 1080, height: 1440)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(surface: surface, in: CGRect(origin: .zero, size: size), context: context.cgContext)
        }
        guard let data = image.pngData() else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReEnchantedNoteCards", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(surface.id.replacingOccurrences(of: "/", with: "-"))-\(Int(Date().timeIntervalSince1970)).png"
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func draw(surface: SurfacePage, in rect: CGRect, context: CGContext) {
        let sender = surface.payload.metadata["senderName"]?.nonEmpty ?? "Someone"
        let contextLine = surface.payload.metadata["deliveryContext"]?.nonEmpty ?? "Folded in passing"
        let note = (surface.payload.metadata["noteProse"]?.nonEmpty ?? surface.payload.body)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        UIColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 1).setFill()
        UIBezierPath(rect: rect).fill()

        let card = rect.insetBy(dx: 78, dy: 86)
        UIColor(red: 0.92, green: 0.84, blue: 0.67, alpha: 1).setFill()
        UIBezierPath(roundedRect: card, cornerRadius: 34).fill()

        UIColor(red: 0.37, green: 0.24, blue: 0.20, alpha: 0.28).setStroke()
        let border = UIBezierPath(roundedRect: card.insetBy(dx: 18, dy: 18), cornerRadius: 24)
        border.lineWidth = 3
        border.stroke()

        let portraitRect = CGRect(x: card.minX + 58, y: card.minY + 58, width: 156, height: 156)
        drawPortrait(sender: sender, surface: surface, rect: portraitRect, context: context)

        drawText(
            sender,
            in: CGRect(x: portraitRect.maxX + 30, y: portraitRect.minY + 18, width: card.width - 280, height: 60),
            font: .serifFont(ofSize: 42, weight: .semibold),
            color: UIColor(red: 0.20, green: 0.15, blue: 0.13, alpha: 1)
        )
        drawText(
            contextLine.uppercased(),
            in: CGRect(x: portraitRect.maxX + 32, y: portraitRect.minY + 86, width: card.width - 300, height: 54),
            font: .systemFont(ofSize: 19, weight: .bold),
            color: UIColor(red: 0.39, green: 0.26, blue: 0.22, alpha: 0.66)
        )

        let noteRect = CGRect(x: card.minX + 78, y: card.minY + 280, width: card.width - 156, height: card.height - 420)
        UIColor(red: 0.98, green: 0.92, blue: 0.77, alpha: 0.74).setFill()
        UIBezierPath(roundedRect: noteRect, cornerRadius: 18).fill()
        UIColor(red: 0.36, green: 0.22, blue: 0.18, alpha: 0.20).setStroke()
        let noteBorder = UIBezierPath(roundedRect: noteRect, cornerRadius: 18)
        noteBorder.lineWidth = 2
        noteBorder.stroke()

        drawText(
            note,
            in: noteRect.insetBy(dx: 46, dy: 48),
            font: .serifFont(ofSize: 38, weight: .regular),
            color: UIColor(red: 0.18, green: 0.13, blue: 0.11, alpha: 1),
            lineSpacing: 12
        )

        drawText(
            "REENCHANTED NOTES",
            in: CGRect(x: card.minX + 78, y: card.maxY - 92, width: card.width - 156, height: 32),
            font: .systemFont(ofSize: 18, weight: .heavy),
            color: UIColor(red: 0.39, green: 0.26, blue: 0.22, alpha: 0.56),
            alignment: .center
        )
    }

    private static func drawPortrait(sender: String, surface: SurfacePage, rect: CGRect, context: CGContext) {
        let image: UIImage?
        if let reference = surface.payload.metadata["imageAssetReference"],
           surface.payload.metadata["imageAssetKind"] == BookPageMediaAsset.Kind.renderedImageFile.rawValue {
            image = UIImage(contentsOfFile: reference)
        } else if let asset = surface.payload.metadata["assetName"]?.nonEmpty ?? CharacterPortrait.intendedAssetName(forName: sender) {
            image = UIImage(named: asset)
        } else {
            image = nil
        }

        // Keep the portrait crop local; the note and footer are drawn into this
        // same renderer context immediately after this method returns.
        context.saveGState()
        let path = UIBezierPath(ovalIn: rect)
        path.addClip()
        if let image {
            image.draw(in: rect)
        } else {
            UIColor(red: 0.33, green: 0.28, blue: 0.40, alpha: 1).setFill()
            path.fill()
            drawText(
                CharacterPortrait.initials(forName: sender),
                in: rect.insetBy(dx: 22, dy: 48),
                font: .serifFont(ofSize: 48, weight: .bold),
                color: .white,
                alignment: .center
            )
        }
        context.restoreGState()

        UIColor(red: 0.76, green: 0.57, blue: 0.24, alpha: 0.82).setStroke()
        let stroke = UIBezierPath(ovalIn: rect)
        stroke.lineWidth = 5
        stroke.stroke()
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        lineSpacing: CGFloat = 4,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = alignment
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
}
#else
enum StudentNoteShareCardRenderer {
    static func render(surface: SurfacePage) -> URL? { nil }
}
#endif

struct InkbonesThrow: Identifiable, Equatable {
    var id = UUID()
    var choiceID: String
    var resolution: StoryInkbonesResolution
    var effectLine: String

    var threshold: Int { resolution.threshold }
    var roll: Int { resolution.roll }
    var band: StoryInkbonesBand { resolution.band }
    var outcome: String { resolution.band.outcome }
    var texture: String { resolution.band.texture }

    static func make(choice: StoryPageChoiceDraft) -> InkbonesThrow {
        let threshold = BeliefCombatResolver.finalThreshold(for: 50, difficulty: .standard)
        let roll = Int.random(in: 1...100)
        return InkbonesThrow(
            choiceID: choice.id,
            resolution: StoryInkbonesResolution(roll: roll, threshold: threshold),
            effectLine: choice.effectLine
        )
    }
}

private extension StoryInkbonesBand {
    var symbolName: String {
        switch self {
        case .triumph: return "sparkles"
        case .favor: return "checkmark.seal.fill"
        case .hesitate: return "link"
        case .cost: return "exclamationmark.triangle.fill"
        case .sideways: return "arrow.triangle.branch"
        }
    }

    var accent: Color {
        switch self {
        case .triumph: return BookPalette.gold
        case .favor: return BookPalette.teal
        case .hesitate: return BookPalette.lampGold
        case .cost: return BookPalette.violet
        case .sideways: return Color(red: 0.24, green: 0.34, blue: 0.50)
        }
    }
}

private struct InkbonesThrowOverlay: View {
    let throwState: InkbonesThrow
    let reduceMotion: Bool
    @State private var thrown = false
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "die.face.5.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Throw the Inkbones")
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.lampGold)
                    Text(reveal ? throwState.outcome : "I cup the bones in my margin.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if reveal {
                    Image(systemName: throwState.band.symbolName)
                        .font(.title3.weight(.black))
                        .foregroundStyle(BookPalette.page)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(throwState.band.accent.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    InkbonesPiece(index: index, thrown: thrown, reduceMotion: reduceMotion)
                }
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            if reveal {
                Text(throwState.texture)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.nightPanel.opacity(0.98),
                    (reveal ? throwState.band.accent : BookPalette.violet).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((reveal ? throwState.band.accent : BookPalette.lampGold).opacity(0.5), lineWidth: 1)
        }
        .shadow(color: BookPalette.ink.opacity(0.34), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            reveal
                ? "Threw the Inkbones. \(throwState.outcome). \(throwState.texture)"
                : "I'm throwing the Inkbones."
        )
        .task(id: throwState.id) {
            if reduceMotion {
                reveal = true
                return
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.62)) {
                thrown = true
            }
            try? await Task.sleep(for: .milliseconds(780))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                reveal = true
            }
        }
    }
}

/// The durable half of the reveal. The ceremonial overlay may leave, but the
/// felt result and the prose it shaped remain together on the Story Page.
private struct StoryInkbonesResultSummary: View {
    let resolution: StoryInkbonesResolution

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            bandLabel

            Text(resolution.band.texture)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            resolution.band.accent.opacity(0.11),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(resolution.band.accent.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(resolution.band.outcome). \(resolution.band.texture)"
        )
    }

    private var bandLabel: some View {
        Label(resolution.band.outcome, systemImage: resolution.band.symbolName)
            .font(.caption.weight(.black))
            .foregroundStyle(resolution.band.accent)
            .fixedSize(horizontal: false, vertical: true)
    }

}

/// One tumbling "bone" of the Inkbones belief-throw. Internal (not private) so
/// the onboarding Wicker roll can reuse the same dice visual grammar.
struct InkbonesPiece: View {
    let index: Int
    let thrown: Bool
    let reduceMotion: Bool

    private var startX: CGFloat { CGFloat(index - 2) * 10 }
    private var endX: CGFloat { [-116, -54, 4, 68, 122][index] }
    private var startY: CGFloat { -18 }
    private var endY: CGFloat { [18, 1, 24, 7, 20][index] }
    private var rotation: Double { [-420, 310, -260, 390, -330][index] }

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BookPalette.page, BookPalette.paper, BookPalette.lampGold.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: [34, 42, 30, 38, 32][index], height: [12, 13, 11, 12, 10][index])
            .overlay {
                Capsule(style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.34), lineWidth: 1)
            }
            .overlay(alignment: .center) {
                Circle()
                    .fill(BookPalette.ink.opacity(0.42))
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: index.isMultiple(of: 2) ? -7 : 7)
            }
            .rotationEffect(.degrees(reduceMotion ? 0 : (thrown ? rotation : Double(index * 12 - 24))))
            .offset(x: reduceMotion ? endX : (thrown ? endX : startX), y: reduceMotion ? endY : (thrown ? endY : startY))
            .opacity(thrown || reduceMotion ? 1 : 0.45)
            .animation(.spring(response: 0.64 + Double(index) * 0.04, dampingFraction: 0.58), value: thrown)
    }
}
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

private enum AtlasGraphMetadataCodec {
    static func decodeNodes(_ raw: String) -> [GraphNode] {
        raw.split(separator: "\n").compactMap { line in
            let parts = split(line)
            guard parts.count >= 5 else { return nil }
            return GraphNode(
                id: parts[0],
                label: parts[1],
                weight: Double(parts[2]) ?? 6,
                chapterID: parts[3].isEmpty ? nil : parts[3],
                kindLabel: parts[4]
            )
        }
    }

    static func decodeEdges(_ raw: String) -> [GraphEdge] {
        raw.split(separator: "\n").compactMap { line in
            let parts = split(line)
            guard parts.count >= 6 else { return nil }
            return GraphEdge(
                id: parts[0],
                sourceID: parts[1],
                targetID: parts[2],
                strength: Double(parts[3]) ?? 0.2,
                warmth: Double(parts[4]) ?? 0,
                label: parts[5]
            )
        }
    }

    private static func split(_ line: Substring) -> [String] {
        String(line)
            .components(separatedBy: "||")
            .map(unescape)
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\p", with: "||")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

private struct MarginsAtlasGraphView: View {
    let variant: MarginsAtlasVariant
    let graph: NarrativeGraphData
    @Binding var selectedNodeID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Pinch-to-zoom + pan over the graph. The layout is dense with many nodes,
    // so the reader needs to magnify into a region to separate overlapping
    // labels. `zoom`/`pan` are the live transform; `lastZoom`/`lastPan` commit
    // each gesture so the next one continues from where the last left off.
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var traceProgress = 1.0

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 4

    private var isTransformed: Bool {
        abs(zoom - 1) > 0.01 || abs(pan.width) > 0.5 || abs(pan.height) > 0.5
    }

    private var selectedEdges: [GraphEdge] {
        guard let selectedNodeID else { return graph.edges }
        return graph.edges.filter { $0.sourceID == selectedNodeID || $0.targetID == selectedNodeID }
    }

    private var connectedIDs: Set<String> {
        guard selectedNodeID != nil else { return Set(graph.nodes.map(\.id)) }
        return Set(selectedEdges.flatMap { [$0.sourceID, $0.targetID] })
    }

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: max(1, proxy.size.width), height: max(1, proxy.size.height))
            let positions = GraphLayoutEngine.layout(
                data: graph,
                width: size.width,
                height: size.height,
                seed: "margins-atlas-\(variant.rawValue)"
            )

            ZStack {
                atlasBackground

                graphContent(positions: positions, size: size)
                    .scaleEffect(zoom)
                    .offset(pan)
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: zoom)
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: pan)
            }
            .contentShape(Rectangle())
            .gesture(panGesture(viewport: size).simultaneously(with: zoomGesture))
            .overlay(alignment: .bottomTrailing) {
                if isTransformed {
                    resetButton
                        .padding(8)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .onChange(of: selectedNodeID) { _, selectedID in
            guard !reduceMotion, selectedID != nil else {
                traceProgress = 1
                return
            }
            traceProgress = 0
            withAnimation(.easeInOut(duration: 0.44)) {
                traceProgress = 1
            }
        }
    }

    private func graphContent(positions: [String: CodablePoint], size: CGSize) -> some View {
        ZStack {
            Canvas { context, _ in
                for edge in graph.edges {
                    guard let source = positions[edge.sourceID],
                          let target = positions[edge.targetID] else { continue }
                    let isLit = selectedNodeID == nil || selectedEdges.contains(where: { $0.id == edge.id })
                    var path = Path()
                    path.move(to: CGPoint(x: source.x, y: source.y))
                    path.addLine(to: CGPoint(x: target.x, y: target.y))
                    context.stroke(
                        isLit && selectedNodeID != nil ? path.trimmedPath(from: 0, to: traceProgress) : path,
                        with: .color(edgeColor(edge).opacity(isLit ? 0.78 : 0.13)),
                        lineWidth: max(1.2, 1.4 + edge.strength * 5.8)
                    )
                }
            }
            .allowsHitTesting(false)

            ForEach(graph.nodes) { node in
                if let point = positions[node.id] {
                    AtlasNodeButton(
                        node: node,
                        variant: variant,
                        isSelected: selectedNodeID == node.id,
                        isDimmed: selectedNodeID != nil && !connectedIDs.contains(node.id)
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedNodeID = selectedNodeID == node.id ? nil : node.id
                        }
                    }
                    .position(x: point.x, y: point.y)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(maxZoom, max(minZoom, lastZoom * value))
            }
            .onEnded { _ in
                lastZoom = zoom
                if zoom <= minZoom + 0.01 { resetPan() }
            }
    }

    private func panGesture(viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let proposed = CGSize(
                    width: lastPan.width + value.translation.width,
                    height: lastPan.height + value.translation.height
                )
                pan = clampedPan(proposed, viewport: viewport)
            }
            .onEnded { value in
                let proposed = CGSize(
                    width: lastPan.width + value.translation.width,
                    height: lastPan.height + value.translation.height
                )
                pan = clampedPan(proposed, viewport: viewport)
                lastPan = pan
            }
    }

    /// Keeps the scaled graph from being dragged entirely off-screen: panning is
    /// bounded by how much larger the zoomed content is than the viewport.
    private func clampedPan(_ proposed: CGSize, viewport: CGSize) -> CGSize {
        let maxX = max(0, (viewport.width * zoom - viewport.width) / 2)
        let maxY = max(0, (viewport.height * zoom - viewport.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }

    private func resetPan() {
        pan = .zero
        lastPan = .zero
    }

    private var resetButton: some View {
        Button {
            BookFeedback.play(.select)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                zoom = 1
                lastZoom = 1
                resetPan()
            }
        } label: {
            Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(BookPalette.nightText)
                .padding(9)
                .background(BookPalette.nightPanel.opacity(0.86), in: Circle())
                .overlay { Circle().stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1) }
        }
        .buttonStyle(.bookPress())
        .accessibilityLabel("Reset zoom")
    }

    private var atlasBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BookPalette.nightPanel,
                    Color(red: 0.15, green: 0.20, blue: 0.22),
                    Color(red: 0.22, green: 0.18, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ForEach(0..<36, id: \.self) { index in
                Circle()
                    .fill(BookPalette.lampGold.opacity(index.isMultiple(of: 5) ? 0.22 : 0.10))
                    .frame(width: CGFloat(1 + (index % 3)), height: CGFloat(1 + (index % 3)))
                    .position(
                        x: CGFloat((index * 47 + abs(variant.rawValue.stableHash % 31)) % 320),
                        y: CGFloat((index * 83 + abs(variant.rawValue.stableHash % 53)) % 390)
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private func edgeColor(_ edge: GraphEdge) -> Color {
        if edge.warmth < -0.18 {
            return Color(red: 0.82, green: 0.25, blue: 0.33)
        }
        if edge.warmth > 0.18 {
            return Color(red: 0.96, green: 0.69, blue: 0.28)
        }
        if variant == .company { return BookPalette.lampGold }
        return variant == .constellation ? BookPalette.teal : BookPalette.violet
    }
}

private struct AtlasNodeButton: View {
    let node: GraphNode
    let variant: MarginsAtlasVariant
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    private var diameter: CGFloat {
        let base = variant == .constellation ? 22 : (variant == .company ? 20 : 18)
        return CGFloat(base) + CGFloat(min(34, max(0, node.weight))) * 0.52
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(nodeColor.opacity(isDimmed ? 0.28 : 0.88))
                    Circle()
                        .stroke(BookPalette.paper.opacity(isSelected ? 0.86 : 0.42), lineWidth: isSelected ? 3 : 1.4)
                    if variant == .constellation {
                        Circle()
                            .fill(BookPalette.paper.opacity(isDimmed ? 0.12 : 0.72))
                            .frame(width: max(4, diameter * 0.18), height: max(4, diameter * 0.18))
                    }
                }
                .frame(width: diameter, height: diameter)
                .shadow(color: nodeColor.opacity(isDimmed ? 0 : 0.38), radius: isSelected ? 12 : 7, x: 0, y: 0)

                Text(node.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.paper.opacity(isDimmed ? 0.35 : 0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: 96)
            }
        }
        .buttonStyle(.bookPress())
        .opacity(isDimmed ? 0.45 : 1)
        .accessibilityLabel("\(node.label), \(node.kindLabel)")
    }

    private var nodeColor: Color {
        if variant == .company {
            switch node.kindLabel {
            case LifeKnowledgeNodeKind.reader.rawValue: return BookPalette.lampGold
            case LifeKnowledgeNodeKind.person.rawValue: return BookPalette.teal
            case LifeKnowledgeNodeKind.interest.rawValue: return BookPalette.violet
            case LifeKnowledgeNodeKind.ritual.rawValue: return Color(red: 0.86, green: 0.48, blue: 0.28)
            case LifeKnowledgeNodeKind.page.rawValue: return BookPalette.paper
            case LifeKnowledgeNodeKind.boundary.rawValue: return Color(red: 0.55, green: 0.58, blue: 0.62)
            default: return Color(red: 0.43, green: 0.62, blue: 0.52)
            }
        }
        switch node.chapterID {
        case "emberheart":
            return Color(red: 0.90, green: 0.25, blue: 0.20)
        case "mossbloom":
            return Color(red: 0.40, green: 0.66, blue: 0.36)
        case "tidecrest":
            return Color(red: 0.24, green: 0.58, blue: 0.78)
        case "riddlewind":
            return Color(red: 0.78, green: 0.54, blue: 0.22)
        case "duskthorn":
            return Color(red: 0.52, green: 0.34, blue: 0.62)
        default:
            return variant == .constellation ? BookPalette.teal : BookPalette.violet
        }
    }
}

private struct MarginsAtlasNodeCard: View {
    let node: GraphNode
    let graph: NarrativeGraphData
    let variant: MarginsAtlasVariant

    private var touchedEdges: [GraphEdge] {
        graph.edges.filter { $0.sourceID == node.id || $0.targetID == node.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(node.label, systemImage: variant == .loom ? "link" : (variant == .company ? "person.2.fill" : "sparkle"))
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.ink)

            Text(variant == .company
                ? node.kindLabel.capitalized
                : "\(node.kindLabel.capitalized). Glow \(Int(node.weight.rounded()))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.58))

            if touchedEdges.isEmpty {
                Text("No lit thread touches this point yet.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
            } else {
                Text(touchedEdges.prefix(4).map(\.label).joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct MarginsAtlasFullScreenView: View {
    let variant: MarginsAtlasVariant
    let graph: NarrativeGraphData
    @Binding var selectedNodeID: String?
    @Environment(\.dismiss) private var dismiss

    private var selectedNode: GraphNode? {
        graph.nodes.first { $0.id == selectedNodeID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookPalette.nightPanel.ignoresSafeArea()

                MarginsAtlasGraphView(
                    variant: variant,
                    graph: graph,
                    selectedNodeID: $selectedNodeID
                )
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()

                    Group {
                        if let selectedNode {
                            MarginsAtlasNodeCard(node: selectedNode, graph: graph, variant: variant)
                        } else {
                            Text(graph.nodes.isEmpty ? "No lines yet. Keep Pages or name people, and I will draw a line when two things are actually connected." : "Tap a name to see its lines. Pinch to zoom. Drag to move around the map.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(variant.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        BookFeedback.play(.dismissPage)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RadioSignalMeter: View {
    let stationID: String
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: !isPlaying || reduceMotion)) { timeline in
            let tick = Int(timeline.date.timeIntervalSince1970 * 4)
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(index: index))
                        .frame(width: 5, height: barHeight(index: index, tick: tick))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(BookPalette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.10), lineWidth: 1)
            }
        }
    }

    private func barHeight(index: Int, tick: Int) -> CGFloat {
        guard isPlaying else { return CGFloat(8 + (index % 3) * 3) }
        let seed = abs("\(stationID)-\(index)-\(tick / 2)".stableHash)
        let wave = 8 + (seed % 28)
        let centerBias = 10 - min(10, abs(index - 12))
        return CGFloat(max(8, min(38, wave + centerBias / 2)))
    }

    private func barColor(index: Int) -> Color {
        if !isPlaying {
            return BookPalette.ink.opacity(0.22)
        }
        return index % 5 == 0 ? BookPalette.lampGold.opacity(0.82) : BookPalette.teal.opacity(0.78)
    }
}

private struct CompassChoiceOption: Identifiable, Equatable {
    var id: String
    var title: String
    var value: String
    var symbol: String
    var detail: String = ""
}

private struct BookCeremonyEvidence: Identifiable, Hashable {
    var id: String
    var text: String
    var pageID: String?
}

enum BookNoticeFeedbackChoice {
    case trueReading
    case notQuite
    case doNotReadThisWay

    var label: String {
        switch self {
        case .trueReading: return "Yes. Keep the underline."
        case .notQuite: return "Not quite. Lift the pencil."
        case .doNotReadThisWay: return "Never read me this way."
        }
    }

    var symbol: String {
        switch self {
        case .trueReading: return "checkmark.seal"
        case .notQuite: return "slider.horizontal.3"
        case .doNotReadThisWay: return "hand.raised"
        }
    }

    var observationStatus: BookObservationStatus {
        switch self {
        case .trueReading: return .confirmed
        case .notQuite: return .notQuite
        case .doNotReadThisWay: return .doNotRead
        }
    }

    var reactionLine: String {
        observationStatus.feedbackReactionLine
    }
}

enum BookNoticeAdaptiveAction: String, Identifiable {
    case scrapbookPage
    case bindWeeklyIssue
    case letPatternRest
    // The People of the Book: confirm a suggested name into a witness
    // thread, write them straight into the story as Cast, decline a
    // suggestion permanently, or press a thread to rest.
    case openPersonThread
    case writePersonIntoStory
    case letPersonRest
    case restPersonThread
    case confirmPersonContext
    case openPeopleOfTheBook

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scrapbookPage: return "Scrapbook this thread"
        case .bindWeeklyIssue: return "Bind this week"
        case .letPatternRest: return "Let the pattern rest"
        case .openPersonThread: return "Open a thread for them"
        case .writePersonIntoStory: return "Write them into the story"
        case .letPersonRest: return "Let this name rest"
        case .restPersonThread: return "Let this thread rest"
        case .confirmPersonContext: return "Yes: remember this"
        case .openPeopleOfTheBook: return "Teach me differently"
        }
    }

    var symbol: String {
        switch self {
        case .scrapbookPage: return "square.and.arrow.up"
        case .bindWeeklyIssue: return "books.vertical"
        case .letPatternRest: return "moon.zzz"
        case .openPersonThread: return "person.text.rectangle"
        case .writePersonIntoStory: return "theatermasks"
        case .letPersonRest: return "moon.zzz"
        case .restPersonThread: return "moon.zzz"
        case .confirmPersonContext: return "checkmark.seal"
        case .openPeopleOfTheBook: return "person.2"
        }
    }

    var shouldDismissSheet: Bool {
        switch self {
        case .scrapbookPage, .bindWeeklyIssue:
            return true
        case .letPatternRest, .openPersonThread, .writePersonIntoStory, .letPersonRest, .restPersonThread, .confirmPersonContext, .openPeopleOfTheBook:
            return false
        }
    }
}

/// How the reader wants a page held.
///
/// Deliberately phrased as instructions to the Book rather than labels on the
/// reader: "this one's heavy" is a request; "Shadow / Grief" would be the app
/// filing someone's life into categories, which is exactly what it must never
/// do. Left unset, the Book reads the page as it finds it; the reader always
/// gets the last word over that reading, in both directions.
enum ReaderShelfMark: String, CaseIterable, Identifiable {
    case unset
    case heavy
    case lighter
    case sealed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unset: return "However you find it"
        case .heavy: return "Gently: this one's heavy"
        case .lighter: return "Lighter than it looks"
        case .sealed: return "Never use this in a story"
        }
    }

    var detail: String {
        switch self {
        case .unset: return "I'll read it the way I read everything else."
        case .heavy: return "I'll keep it out of the scenery and hold it for a long while before it becomes anything."
        case .lighter: return "I'll stop treating it as weight."
        case .sealed: return "It stays in your archive and never reaches a page I write."
        }
    }

    var symbolName: String {
        switch self {
        case .unset: return "ellipsis.circle"
        case .heavy: return "moon.circle"
        case .lighter: return "sun.max.circle"
        case .sealed: return "hand.raised.circle"
        }
    }

    var tag: String? {
        switch self {
        case .unset: return nil
        case .heavy: return ReaderShelf.shadowTag
        case .lighter: return ReaderShelf.lightTag
        case .sealed: return ReaderShelf.sealedTag
        }
    }
}

struct CapturePageSheet: View {
    let surface: SurfacePage
    let day: BookDay
    let isLocalBrainWorking: Bool
    let localBrainWorkLabel: String
    let localBrainWorkStartedAt: Date?
    let localBrainQueuedCount: Int
    let localBrainProgress: LocalBrainProgressViewState
    /// Whether the private local mind (Gemma) is already installed. Drives the
    /// in-page "Download the private mind" control on pages that mention it.
    var localBrainIsReady: Bool = false
    var isInstallingLocalBrain: Bool = false
    var localBrainInstallMessage: String = ""
    var localBrainInstallProgress: Double? = nil
    var onInstallLocalBrain: () -> Void = {}
    let onReplaceIlluminatedSurface: (SurfacePage) -> Void
    let onNavigateToSurface: (SurfacePage) -> Void
    let onCompleteCompassRun: (SurfacePage) -> Void
    var compassAnchors: [AnchorRecord] = []
    let onStoryMechanicCompleted: (SurfacePage, String) -> Void
    let onGenerateLetter: (SurfacePage) -> Void
    let onGenerateNote: (SurfacePage) -> Void
    let onGeneratePlayfulMission: (SurfacePage) -> Void
    var onRequestTarotReading: (TarotReadingArtifact, Bool) async -> TarotReadingArtifact = { reading, _ in reading }
    var readerBeliefScore: Int = 0
    var onSpendBeliefForGeneration: (BeliefGenerationKind) -> Bool = { _ in false }
    var onRefundBeliefForGeneration: (BeliefGenerationKind) -> Void = { _ in }
    var onAnchorPlace: (AnchorPlaceDraft) -> Void = { _ in }
    /// Permanently retires a feast day the reader would rather not be marked.
    var onRestCelebration: ((String) -> Void)? = nil
    var onBindChapter: (ChapterBindingAcceptance) -> Void = { _ in }
    var flyleafLedger: FlyleafLedger = .empty
    var onOpenBookWorkingAuthority: () -> Void = {}
    var onCompleteElective: (String, String, String?, String?) -> Void = { _, _, _, _ in }
    var onReleaseElective: (String) -> Void = { _ in }
    var onOpenFlyleafDoor: (FlyleafDoor) -> Void = { _ in }
    var onAcceptFaeBargain: (String) -> SurfacePage? = { _ in nil }
    var onPayFaeBargain: (String, String, String) -> Void = { _, _, _ in }
    /// (chosenID, chosenName, otherID, otherName) when the reader sides in The Two Readings.
    var onTwoReadingsSided: (String, String, String, String) -> Void = { _, _, _, _ in }
    var radioPlayback: RadioPlaybackState = .off
    var onTuneRadio: (String) -> Void = { _ in }
    var onStopRadio: () -> Void = {}
    var inventoryKeptPages: [BookPage] = []
    var inventoryStoryObjects: [CustomCastMember] = []
    var inventoryObjectBeliefOffsets: [String: Int] = [:]
    var onUseInventoryGift: (String, String?) -> Void = { _, _ in }
    var onOpenInventoryMarket: () -> Void = {}
    var onOpenInventoryBargain: (FaeBargain) -> Void = { _ in }
    var onLoveBraid: (String) -> String = { _ in "" }
    var onBraidMissedMe: (String) -> String = { _ in "" }
    var onImproveNextBraid: (String) async -> String = { _ in "" }
    var onRewriteBraid: (String) async -> String = { _ in "" }
    var onBookInterjectionResponse: (SurfacePage, BookInterjectionResponse, Date) -> String = { _, _, _ in "" }
    var onBookNoticeFeedback: (SurfacePage, BookNoticeFeedbackChoice) -> String = { _, _ in "" }
    var onBookOpinionContested: (SurfacePage, String, Date) -> String = { _, _, _ in "" }
    var onBookNoticeAdaptiveAction: (SurfacePage, BookNoticeAdaptiveAction) -> String = { _, _ in "" }
    var onRenameSeasonalDispatch: (String, String) -> String = { _, _ in "" }
    var onSetSeasonalDispatchCover: (String, BoundVolumeCoverChoice, String?, Data?) -> String = { _, _, _, _ in "" }
    var onSetSeasonalDispatchDedication: (String, String) -> String = { _, _ in "" }
    var onSetSeasonalDispatchHeld: (String, Bool) -> String = { _, _ in "" }
    var onOpenSeasonalDispatchAddress: () -> Void = {}
    var onKeepPlainPhoto: (BookPageMediaAsset) -> Void = { _ in }
    var weatherSignal: WeatherSourceSignal?
    var readerLearning: ReaderLearningModel = ReaderLearningModel()
    var onPageOpened: (SurfacePage, Date) -> Void = { _, _ in }
    var onMomentaryAction: (SurfacePage, String, Date) -> MomentaryActionOutcome = { _, text, _ in
        MomentaryActionOutcome(
            recognitionLine: MomentaryAttentionEngine.recognition(for: text, stage: .notice),
            keepsakeLine: nil
        )
    }
    /// The reader's living Lexicon, so word rulings actually bend the sentence
    /// scaffold the player writes with. Defaults empty for previews/callers that
    /// don't have a vault.
    var readerLexicon: ReaderLexicon = ReaderLexicon()
    /// The same Book that greeted the reader and raised this Page. This is a
    /// projection of durable archive history, not a selectable chat persona.
    var bookRelationship: BookRelationshipSnapshot = .firstOpening
    /// Durable wants, promises, favorites, fascinations, and self-secrets for
    /// this particular Book. Chat receives the same inner life as the cover.
    var bookInterior: BookInteriorState = .unawakened
    /// The private archive-derived grain of this reader's Book. This is a
    /// read-only projection, not a persona setting and not model training.
    var bookVoicePatina: BookVoicePatina = .unwritten
    /// Whole-archive, permission-aware retrieval for Chat with the Book.
    /// Previews keep the empty default; the live Book supplies the durable store.
    var askTheBookMemoryLookup: (String, [AskTheBookTurn]) async -> AskTheBookMemoryPacket = { _, _ in .empty }
    /// Records only a reader-initiated reply to a deterministic Book teaser.
    /// Creating or opening the teaser never invokes the local model.
    var onBookInitiativeAnswered: (String, String, Date) -> Void = { _, _, _ in }
    var onExternalSparkContinuation: (String, ExternalSparkContinuation, Date) -> String = {
        _, _, _ in ""
    }
    var onExternalSparkReturn: (String, ExternalSparkContinuation, String, Bool, Date) -> String = {
        _, _, _, _, _ in ""
    }
    var isShadowWonderActive: Bool = false
    var isEmbedded = false
    var onDismissRequest: (() -> Void)? = nil
    /// (surface, input, tags, extraMedia). `extraMedia` carries a pressed
    /// photograph when the reader attached one; empty otherwise.
    /// (kept page ID, mark): re-marks a page already in the archive. A seal the
    /// reader can only apply in the two seconds before keeping is not much of a
    /// seal; regret arrives later than that. Declared above `onSave` so the
    /// trailing-closure call site keeps working.
    var onRemarkKeptPage: ((String, ReaderShelfMark) -> Void)? = nil
    let onSave: (SurfacePage, String, [String], [BookPageMediaAsset]) -> Void

    private static let localBrainStatusScrollID = "page-local-brain-status"
    /// A finished Enchantment lands *above* where the reader was watching: the
    /// illuminated plate and the whole prepared-page block are inserted higher
    /// up the scroll than the casting card they were staring at. Without an
    /// anchor to scroll to, the payoff either never came into view or slid out
    /// of it as the layout settled.
    private static let enchantmentPlateScrollID = "page-enchantment-plate"
    private static let enchantmentResultScrollID = "page-enchantment-result"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedWeather = ""
    @State private var isCommittingKeep = false
    @State private var isTuckingPage = false
    @State private var shelfMark: ReaderShelfMark = .unset
    @State private var centerGearOffset = 0
    /// The feast-day throw is already decided when the page is built; this only
    /// tracks whether the reader has turned it over yet.
    @State private var festivalBonesRevealed = false
    @State private var text = ""
    @State private var didRecordPageOpened = false
    @State private var playfulMissionOpenBurstTrigger = 0
    @State private var didPlayPlayfulMissionOpenBurst = false
    @State private var isJournalDeeperQuestionOpen = false
    @State private var letterReply = ""
    @State private var didSealReply = false
    @State private var sealStamp = false
    @State private var noteShareURL: URL?
    @State private var isPressingNoteShareCard = false
    @State private var manualPhotoImage: UIImage?
    @State private var manualPhotoDraft: IlluminatedPhotoDraft?
    @State private var isLoadingManualPhoto = false
    @State private var isChoosingBookPhoto = false
    @State private var isSavingIlluminatedArtifact = false
    @State private var illuminationMessage = "Penny can choose from recent photos, or you can hand her one yourself."
    @State private var renderedIlluminatedPageURL: URL?
    @State private var selectedStoryChoice: StoryPageChoiceDraft?
    @State private var storyTurns: [StoryPageSessionTurn] = []
    @State private var isContinuingStoryPage = false
    @State private var isGeneratingStoryResult = false
    @State private var generatingStoryResultChoiceID: String?
    @State private var storyContinuationMessage = ""
    @State private var externalSparkContinuation: ExternalSparkContinuation?
    @State private var externalSparkReturnLine = ""
    @State private var externalSparkMessage = ""
    @State private var resolvedStoryMechanics: [String: String] = [:]
    @State private var activeInkbonesThrow: InkbonesThrow?
    @State private var academyActivityResponses: [String: String] = [:]
    @State private var academyBookJumpSelection: String?
    @State private var glintObject = ""
    @State private var glintStage = 0
    @State private var glintInterpretation = ""
    @State private var academyActivityStages: [String: Int] = [:]
    @State private var academyActivitySelections: [String: String] = [:]
    @State private var quietSecondsRemaining = 60
    @State private var askPrompt = ""
    @State private var askTurns: [AskTheBookTurn] = []
    @State private var askEvidenceByTurnID: [String: [AskTheBookEvidence]] = [:]
    @State private var askSearchCountByTurnID: [String: Int] = [:]
    @State private var openedAskEvidence: AskTheBookEvidence?
    @State private var isAskingTheBook = false
    @State private var askTheBookMessage = ""
    @State private var inkrestIntake = InkrestIntake()
    @State private var inkrestSeeded = false
    @State private var inkrestStarted = false
    @State private var inkrestClosed = false
    @State private var inkrestChatInput = ""
    @State private var inkrestTurns: [AskTheBookTurn] = []
    @State private var isInkrestSitting = false
    @State private var inkrestMessage = ""
    @State private var faeReport = ""
    @State private var faeResponseText = ""
    @State private var isFaeAccepting = false
    @State private var isFaePaying = false
    @State private var faeMessage = ""
    @State private var greyThreatChoice: String?
    @State private var greyRescueLine = ""
    @State private var festivalMessage = ""
    @State private var todaysSkyMessage = ""
    @State private var academyCalendarMessage = ""
    @State private var radioDialFrequency = 94.1
    @State private var selectedRadioStationID: String?
    @State private var hasTouchedRadioDial = false
    @State private var radioManager = BookRadioManager.shared
    @State private var twoReadingsSide: String?
    @State private var selectedEnchantmentID: String?
    @State private var enchantmentResult: EnchantmentCastResult?
    /// Bumped each time a cast lands, so the page can carry the reader to it.
    @State private var enchantmentArrivalTick = 0
    @State private var enchantmentTurns: [AskTheBookTurn] = []
    @State private var enchantmentPrompt = ""
    @State private var enchantmentMessage = ""
    @State private var isCastingEnchantment = false
    @State private var isSavingEnchantmentArtifact = false
    @State private var isAnsweringEnchantedObject = false
    @State private var currentEnchantmentSurface: SurfacePage?
    @State private var selectedAtlasNodeID: String?
    @State private var isAtlasFullScreenPresented = false
    @State private var proofPhotoImage: UIImage?
    @State private var proofPhotoURL: URL?
    @State private var proofPhotoMessage = ""
    /// The surface these controls were seeded from. Keyed on identity rather
    /// than a one-shot flag because the sheet can stay mounted while `surface`
    /// changes: `compassRunReadyView` navigates within it: which left a second
    /// run showing the previous run's answers and resuming mid-questionnaire.
    @State private var seededCompassSurfaceID: String?
    @State private var compassConstraintStep: CompassRunConstraintStep = .location
    @State private var compassPlaceContextID = CompassPlaceContext.current.rawValue
    @State private var compassLocation = ""
    @State private var compassTimeLimit = ""
    @State private var compassEnergy = ""
    @State private var compassCompanions = ""
    @State private var compassBudget = ""
    @State private var compassConsiderationIDs: Set<String> = []
    @State private var compassCurrentPlaceMessage = ""
    @State private var compassNearbyPlacesOverride = ""
    @State private var compassCurrentLatitude: Double?
    @State private var compassCurrentLongitude: Double?
    @State private var compassAnchorProximity: AnchorProximity?
    @State private var isResolvingCompassPlace = false
    @State private var isWritingManualCompassRun = false
    @State private var manualCompassSpark = ""
    @State private var manualCompassDestination = ""
    @State private var manualCompassDelight = ""
    @State private var manualCompassDefinition = ""
    @State private var manualCompassMission = ""
    @State private var manualCompassSouvenirPrompt = ""
    @State private var manualCompassRestPrompt = ""
    @State private var isGeneratingCompassRun = false
    @State private var compassGenerationMessage = ""
    @State private var lastVentureMode: CompassVentureMode = .neighborhood
    @State private var isGeneratingPlayfulMission = false
    @State private var playfulMissionGenerationMessage = ""
    @State private var bleedPDFURL: URL?
    @State private var bleedExportMessage = ""
    @State private var illuminatedQuoteCardURL: URL?
    @State private var isPreparingQuoteCard = false
    @State private var quoteCardMessage = ""
    @State private var bookOfYouShareCardURL: URL?
    @State private var isPressingBookOfYouShareCard = false
    @State private var bookOfYouShareMessage = ""
    @State private var bookOfYouRevealVideoURL: URL?
    @State private var isPressingBookOfYouRevealVideo = false
    @State private var inventoryRevision = 0
    @State private var inventoryMessage = ""
    @State private var inventoryUnspokenSentence = ""
    @State private var isWritingUnspokenSentence = false
    @State private var isGamePagePresented = false
    @AppStorage(PublicMarginsAPI.outgoingOptInKey) private var publicMarginsOutgoingOptIn = false
    @State private var isPublicMarginsContributionPresented = false
    @State private var gameResultSurface: SurfacePage?
    @State private var lastGameResult: SentenceRunnerResult?
    @State private var isBraidingGameRun = false
    @State private var gameRunBraided = false
    @State private var gameBraidMessage = ""
    @State private var inspectedPhraseSource: SentenceRunnerPhraseSource?
    @State private var chosenRunnerThread = ""
    @State private var runnerReturnPhrase = ""
    @State private var sessionRunnerFolioRuns = 0
    @State private var braidFeedbackMessage = ""
    @State private var didMarkBraidMissed = false
    @State private var didAnswerTaleAsk = false
    @State private var taleAskReply = ""
    @State private var isImprovingBraid = false
    @State private var isRewritingBraid = false
    @State private var didRewriteBraid = false
    @State private var bookNoticeFeedbackMessage = ""
    @State private var bookInterjectionResponseMessage = ""
    @State private var didAnswerBookInterjection = false
    @State private var seasonalDispatchName = ""
    @State private var seasonalDispatchCoverChoice: BoundVolumeCoverChoice = .bookChooses
    @State private var seasonalDispatchPlateID = PublicationCoverCatalogue.rotating.first?.id ?? "hedge-door"
    @State private var seasonalDispatchPhotoData: Data?
    @State private var seasonalDispatchPhotoFocus: PublicationCoverFocus?
    @State private var seasonalDispatchDedication = ""
    @State private var seasonalDispatchMessage = ""
    @State private var seasonalDispatchIsHeld = false
    @AppStorage("includePrivateWeatherInMonthlyBinding") private var includePrivateWeatherInBoundVolumes = false
    @State private var didCorrectBookNotice = false
    @State private var bookOpinionArgument = ""
    @State private var didContestBookOpinion = false
    @State private var didPlayCeremonyOpen = false
    @State private var didRevealCeremony = false
    /// The reader opening receipts the Book did not hand over. See
    /// `BookTelling.EvidencePosture`: a cold Book leaves its evidence where it
    /// can be found rather than spreading it on the desk.
    @State private var didOpenWithheldEvidence = false
    @State private var didRevealOpenedPage = false
    @State private var openedPageTurnProgress = 1.0
    @State private var loosePageTurns: [String: Int] = [:]
    @State private var tarotReading: TarotReadingArtifact?
    @AppStorage("tarotReadingDraftV1") private var tarotReadingDraftData = ""
    @AppStorage("illuminatedPhotoHistory") private var illuminatedPhotoHistoryData = "{}"
    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pressedPhotoItem: PhotosPickerItem?
    @State private var seasonalDispatchPhotoItem: PhotosPickerItem?
    #endif
    /// A photograph pressed between the pages of an ordinary kept page, ready to
    /// travel with it into the archive. Nil until the reader chooses one.
    @State private var pressedPhotoAsset: BookPageMediaAsset?
    @State private var pressedPhotoMessage: String?
    @State private var isLoadingPressedPhoto = false
    @StateObject private var keptVoiceRecorder = KeptVoiceRecorder()
    @State private var keptVoiceAsset: BookPageMediaAsset?
    @State private var keptVoiceMessage: String?

    /// Extra media the reader attached to this page: a pressed photograph, a
    /// kept voice recording: to travel into the archive with it.
    private var keptExtraMedia: [BookPageMediaAsset] {
        [pressedPhotoAsset, keptVoiceAsset].compactMap { $0 }
    }

    #if canImport(UIKit)
    @State private var isCameraPresented = false
    @State private var didAutoOpenCamera = false
    @State private var pendingCameraPhotoData: Data?
    @State private var pendingCameraPhotoImage: UIImage?
    @State private var pendingCameraPhotoURL: URL?
    @State private var isChoosingCameraEnchantment = false
    #endif
    private var marginTutorSeenData: String {
        get { MarginTutorLedger.encode(Set(PlayerVault.shared.data.tutorSeen)) }
        nonmutating set {
            PlayerVault.shared.data.tutorSeen = Array(MarginTutorLedger.seenIDs(from: newValue)).sorted()
            PlayerVault.shared.save()
        }
    }
    @AppStorage("didCompleteStoryOnboarding") private var didCompleteStoryOnboarding = false
    @State private var activeTutorNote: MarginTutorNote?

    private let weatherOptions = ["Fog", "Rain", "Static", "Heavy", "Bright", "Restless", "Soft", "Numb", "Stormy", "Clearing"]

    private var compassPlaceOptions: [CompassChoiceOption] {
        CompassPlaceContext.allCases.map { context in
            CompassChoiceOption(
                id: context.rawValue,
                title: context.title,
                value: context.promptValue,
                symbol: compassPlaceSymbol(for: context)
            )
        }
    }

    private let compassTimeOptions: [CompassChoiceOption] = [
        CompassChoiceOption(id: "1m", title: "1 minute", value: "1 minute", symbol: "timer"),
        CompassChoiceOption(id: "5m", title: "5 minutes", value: "5 minutes", symbol: "timer"),
        CompassChoiceOption(id: "10m", title: "10 minutes", value: "10 minutes", symbol: "timer"),
        CompassChoiceOption(id: "20m", title: "20 minutes", value: "20 minutes", symbol: "timer"),
        CompassChoiceOption(id: "45m", title: "45 minutes", value: "45 minutes", symbol: "timer"),
        CompassChoiceOption(id: "half-day", title: "Half day", value: "half a day", symbol: "sun.max")
    ]

    private let compassEnergyOptions: [CompassChoiceOption] = [
        CompassChoiceOption(id: "depleted", title: "Depleted", value: "10%: depleted", symbol: "battery.0percent"),
        CompassChoiceOption(id: "low", title: "Low", value: "35%: low", symbol: "battery.25percent"),
        CompassChoiceOption(id: "steady", title: "Steady", value: "60%: steady", symbol: "battery.50percent"),
        CompassChoiceOption(id: "bright", title: "Bright", value: "85%: bright", symbol: "battery.100percent")
    ]

    private let compassCompanionOptions: [CompassChoiceOption] = [
        CompassChoiceOption(id: "solo", title: "Solo", value: "solo", symbol: "person"),
        CompassChoiceOption(id: "partner", title: "Partner", value: "with a partner", symbol: "person.2"),
        CompassChoiceOption(id: "kids", title: "Kids", value: "with kids", symbol: "figure.2.and.child.holdinghands"),
        CompassChoiceOption(id: "friend", title: "Friend", value: "with a friend", symbol: "person.2"),
        CompassChoiceOption(id: "group", title: "Group", value: "with a small group", symbol: "person.3")
    ]

    private let compassBudgetOptions: [CompassChoiceOption] = [
        CompassChoiceOption(id: "zero", title: "$0", value: "$0", symbol: "dollarsign.circle"),
        CompassChoiceOption(id: "five", title: "$5", value: "$5 or less", symbol: "dollarsign.circle"),
        CompassChoiceOption(id: "twenty", title: "$20", value: "$20 or less", symbol: "dollarsign.circle"),
        CompassChoiceOption(id: "available", title: "Use what I have", value: "use what is already available", symbol: "bag"),
        CompassChoiceOption(id: "flexible", title: "Flexible", value: "flexible", symbol: "sparkles")
    ]

    private let compassConsiderationOptions: [CompassChoiceOption] = [
        CompassChoiceOption(id: "indoors", title: "Indoors", value: "indoors only", symbol: "house"),
        CompassChoiceOption(id: "accessible", title: "Accessible", value: "accessible route", symbol: "figure.roll"),
        CompassChoiceOption(id: "no-driving", title: "No driving", value: "no driving", symbol: "figure.walk"),
        CompassChoiceOption(id: "no-strangers", title: "No strangers", value: "no strangers", symbol: "person.crop.circle.badge.xmark"),
        CompassChoiceOption(id: "kid-safe", title: "Kid-safe", value: "kid-safe", symbol: "figure.and.child.holdinghands"),
        CompassChoiceOption(id: "quiet", title: "Quiet", value: "quiet", symbol: "speaker.slash"),
        CompassChoiceOption(id: "weather-safe", title: "Weather-safe", value: "weather-safe", symbol: "cloud.sun")
    ]

    private let compassMemoryOptions: [CompassPlaceContext] = [
        .home, .work, .cafe, .harbor, .park, .store, .library, .waterfront, .trail
    ]

    private var isLocalBrainIssuePage: Bool {
        surface.payload.metadata["source"] == "local-brain" ||
            surface.payload.metadata["status"] == "failed"
    }

    private var isKeptReadbackPage: Bool {
        surface.payload.metadata["keptPage"] == "true"
    }

    private var isBookWorkingInvitationPage: Bool {
        surface.payload.metadata["bookWorkingInvitation"] == "true"
    }

    private var isSeasonalDispatchPage: Bool {
        surface.payload.metadata["seasonalDispatch"] == "true"
            && surface.payload.metadata["seasonalDispatchID"]?.nonEmpty != nil
    }

    private var isExternalSparkReadbackPage: Bool {
        isKeptReadbackPage && surface.payload.metadata["externalShare"] == "true"
    }

    private var isScrapbookReadbackPage: Bool {
        guard isKeptReadbackPage else { return false }
        let tags = surface.payload.metadata["tags", default: ""]
        return tags.contains("scrapbook") || tags.contains("pagewright")
    }

    private var pageSheetTitle: String {
        if isScrapbookReadbackPage { return "Scrapbook Page" }
        return surface.payload.metadata["pageTitle"]?.nonEmpty ?? surface.type.title
    }

    private var pageSheetSymbolName: String {
        if isScrapbookReadbackPage { return "photo.artframe" }
        return surface.payload.metadata["pageSymbol"]?.nonEmpty ?? surface.type.symbolName
    }

    private var isQuillChoosingPage: Bool {
        surface.payload.metadata["tags", default: ""].contains(QuillChoosing.chosenTag)
    }

    private var scrapbookImagePreviewURL: URL? {
        guard let path = surface.payload.metadata["renderedPreviewPath"]?.nonEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension.lowercased() != "pdf" else { return nil }
        return ImagePreview.url(forFilePath: path)
    }

    private var scrapbookPDFPreviewURL: URL? {
        guard let path = surface.payload.metadata["pagewrightPDFPath"]?.nonEmpty else { return nil }
        return ImagePreview.url(forFilePath: path)
    }

    private var scrapbookNoteText: String? {
        let body = surface.payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = body.components(separatedBy: "\n\nScraps bound here:").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return note?.nonEmpty
    }

    private var isMoonwriteSouvenirPage: Bool {
        surface.type == .souvenir && Almanac.isMoonwriteActive()
    }

    private var keptPageID: String? {
        surface.payload.metadata["keptPageID"]?.nonEmpty
    }

    private var canGiveBraidFeedback: Bool {
        surface.type == .bookOfYou &&
            isKeptReadbackPage &&
            keptPageID != nil &&
            !surface.payload.metadata["tags", default: ""].contains(BraidLearningLoop.missedMeTag) &&
            !surface.payload.metadata["tags", default: ""].contains(BraidLearningLoop.lovedItTag)
    }

    private var isPendingLetterPage: Bool {
        surface.type == .letter && surface.payload.metadata["letterProse"]?.nonEmpty == nil
    }

    private var isPendingNotePage: Bool {
        surface.type == .note && noteProseText == nil
    }

    /// An opened letter (prose written) from a real sender: the state in which
    /// the reader can write back.
    private var isOpenedLetterPage: Bool {
        surface.type == .letter
            && surface.payload.metadata["letterProse"]?.nonEmpty != nil
            && letterSenderID != nil
    }

    private var isOpenedNotePage: Bool {
        surface.type == .note
            && noteProseText != nil
    }

    private var noteProseText: String? {
        guard surface.type == .note else { return nil }
        if let note = surface.payload.metadata["noteProse"]?.nonEmpty {
            return note
        }
        let proseStatus = surface.payload.metadata["proseStatus"]
        let body = surface.payload.body.nonEmpty
        if proseStatus == "generated" || proseStatus == "kept" {
            return body
        }
        if surface.payload.metadata["keptPage"] == "true" || surface.payload.metadata["noteReplied"] == "true" {
            return body
        }
        return nil
    }

    private var letterSenderID: String? {
        surface.payload.metadata["senderID"]?.nonEmpty
    }

    private var letterSenderName: String {
        surface.payload.metadata["senderName"]?.nonEmpty ?? (surface.type == .note ? "someone" : "them")
    }

    private var isEnchantmentPage: Bool {
        surface.type == .enchantment || surface.payload.metadata["source"] == "enchantment"
    }

    private var isCameraFirstIlluminatedPage: Bool {
        surface.type == .illuminatedPhoto && surface.payload.metadata["cameraFirst"] == "true"
    }

    #if canImport(UIKit)
    private var hasPendingCameraPhoto: Bool {
        pendingCameraPhotoData != nil && pendingCameraPhotoImage != nil
    }

    private var shouldShowCameraCapturePage: Bool {
        isCameraFirstIlluminatedPage && (hasPendingCameraPhoto || manualPhotoDraft != nil || enchantmentResult != nil)
    }
    #endif

    private var activeEnchantmentSpell: EnchantmentSpell? {
        StoryEnchantmentCatalog.spell(id: selectedEnchantmentID ?? surface.payload.metadata["enchantmentID"])
    }

    private var isCastEnchantmentLandingPage: Bool {
        isEnchantmentPage && activeEnchantmentSpell == nil
    }

    private var isPreparedPage: Bool {
        if isSeasonalDispatchPage {
            return true
        }
        if isLocalBrainIssuePage {
            return true
        }
        if isKeptReadbackPage {
            return true
        }
        if surface.type == .aboutYou, surface.payload.metadata["earnedLabel"] == "true" {
            return true
        }
        return surface.intent == .importReference ||
            surface.renderStyle == .illuminatedPhoto ||
            currentEnchantmentSurface != nil ||
            surface.type == .narrativeOS ||
            surface.type == .bookFae ||
            surface.type == .gossip ||
            surface.type == .note ||
            surface.type == .bookRemembered ||
            surface.type == .bookPocket ||
            surface.type == .bookNotices ||
            surface.type == .taleBound ||
            surface.type == .theBleed ||
            surface.type == .letter ||
            surface.type == .elective ||
            surface.type == .academyClass ||
            surface.type == .castBond ||
            surface.type == .anchor ||
            surface.type == .radio ||
            surface.type == .inventory ||
            surface.type == .frontMatter ||
            isChapterPrimerPage ||
            surface.renderStyle == .gentleTranslation ||
            surface.origin == .imported
    }

    private var sentenceBuilderContext: SentenceBuilderContext {
        makeSentenceBuilderContext(intent: inferredSentenceBuilderIntent)
    }

    private var inferredSentenceBuilderIntent: SentenceBuilderIntent {
        if surface.type == .souvenir { return .souvenir }
        if surface.type == .wonderCompass && (
            surface.payload.metadata["proofKind"] != nil
                || surface.payload.metadata["compassStep"] == "write"
                || isStandalonePlayfulMissionPage
                || isPennySentenceMasteryPage
        ) {
            return .missionProof
        }
        if surface.intent == .reflect || [.mood, .diary, .body, .fuel, .rest, .aboutYou].contains(surface.type) {
            return .reflection
        }
        return .marginNote
    }

    private func makeSentenceBuilderContext(
        intent: SentenceBuilderIntent,
        prompt: String? = nil,
        sourceText: String? = nil,
        recipientName: String? = nil
    ) -> SentenceBuilderContext {
        let metadataTags = surface.payload.metadata["tags", default: ""]
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace })
            .map(String.init)
        let recentWords = (inventoryKeptPages + day.pages)
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap(\.readerAuthoredTextForAnalysis)
            .prefix(6)
        let hour = Calendar.current.component(.hour, from: Date())
        let dayPart: String
        switch hour {
        case 5...11: dayPart = "morning"
        case 12...16: dayPart = "afternoon"
        case 17...20: dayPart = "evening"
        default: dayPart = "night"
        }

        let contextualFactKeys = [
            "scene", "objects", "colors", "weather", "weatherPhrase",
            "mission", "souvenirPrompt", "imageCaption"
        ]
        let contextualFacts = contextualFactKeys.compactMap { surface.payload.metadata[$0]?.nonEmpty }
        let baseSource = sourceText ?? surface.payload.body
        let combinedSource = ([baseSource] + contextualFacts).joined(separator: " ")

        return SentenceBuilderContext(
            intent: intent,
            prompt: prompt ?? surface.prompt,
            sourceText: combinedSource,
            tags: [surface.type.rawValue, surface.sourceID] + metadataTags,
            recipientName: recipientName,
            weather: weatherSignal?.phrase,
            timeOfDay: dayPart,
            personalWords: readerLexicon.packEntries
                .sorted { $0.ledAt > $1.ledAt }
                .prefix(24)
                .map(\.word),
            recentMotifs: Array(recentWords)
        )
    }

    private var isCompassPracticePage: Bool {
        surface.type == .wonderCompass && surface.payload.metadata["compassStep"] != nil
    }

    private var isAnchorOfferPage: Bool {
        surface.type == .anchor && surface.payload.metadata["anchorOffer"] == "true"
    }

    private var isElectiveFlyleafPage: Bool {
        surface.type == .elective && surface.payload.metadata["electiveFlyleaf"] == "true"
    }

    private var isChapterBindingPage: Bool {
        surface.type == .aboutYou && surface.payload.metadata["chapterBinding"] == "true"
    }

    private var isChapterPrimerPage: Bool {
        surface.type == .aboutYou && surface.payload.metadata["chapterPrimer"] == "true"
    }

    private var isBookJumpPage: Bool {
        surface.type == .bookJump
    }

    private var bookJumpAction: BookJumpAction? {
        surface.payload.metadata["bookJumpAction"].flatMap(BookJumpAction.init(rawValue:))
    }

    private var isBookJumpReturnPage: Bool {
        isBookJumpPage && bookJumpAction == .return
    }

    /// An open jump (any beat past Opening the Spine) is steered by the in-page
    /// Go Deeper / Find the Spine controls rather than the generic Keep button.
    private var isBookJumpActivePage: Bool {
        isBookJumpPage && bookJumpAction != nil && bookJumpAction != .start
    }

    /// Keep the open jump as a chosen beat, rewriting the action (and its tag)
    /// so the reader's fork: deeper, steady, or home: is what gets applied.
    private func keepBookJump(as action: BookJumpAction, direction: StoryChoiceRole? = nil) {
        var metadata = surface.payload.metadata
        let previous = metadata["bookJumpAction"] ?? "advance"
        metadata["bookJumpAction"] = action.rawValue
        if action == .return {
            metadata["bookJumpHasSouvenir"] = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ? "false" : "true"
        }
        if let direction {
            metadata["bookJumpChosenDirection"] = direction.rawValue
        }
        if let tags = metadata["tags"] {
            metadata["tags"] = tags.replacingOccurrences(of: "book-jump:\(previous)", with: "book-jump:\(action.rawValue)")
        }
        let variant = SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: BookPagePayload(
                headline: surface.payload.headline,
                body: surface.payload.body,
                metadata: metadata
            )
        )
        let input = preparedInput
        let tags = preparedTags(for: variant)
        requestDismiss()
        DispatchQueue.main.async {
            onSave(variant, input, tags, [])
        }
    }

    private func tutorTouchForThisPage() {
        if let id = MarginTutorCatalog.noteID(for: surface.type),
           !(surface.type == .narrativeOS && isLocalBrainIssuePage) {
            tutorTouch(id)
        } else if surface.isStoryPlayablePage, !isLocalBrainIssuePage {
            tutorTouch("story-page")
        } else if isEnchantmentPage {
            tutorTouch("enchantment-page")
        } else if isElectiveFlyleafPage {
            tutorTouch("flyleaf")
        } else if isCompassRunStartPage {
            tutorTouch("compass-run")
        } else if surface.type == .askTheBook {
            tutorTouch("ask-the-book")
        }
    }

    private func tutorTouch(_ id: String) {
        guard didCompleteStoryOnboarding else { return }
        var seen = MarginTutorLedger.seenIDs(from: marginTutorSeenData)
        guard !seen.contains(id), let note = MarginTutorCatalog.note(for: id) else { return }
        seen.insert(id)
        marginTutorSeenData = MarginTutorLedger.encode(seen)
        withAnimation(BookMotion.reveal(reduceMotion)) {
            activeTutorNote = note
        }
    }

    private var isCompassRunStepPage: Bool {
        guard surface.type == .wonderCompass,
              surface.payload.metadata["runID"] != nil,
              surface.payload.metadata["compassStep"] != nil,
              surface.payload.metadata["compassStep"] != "run",
              surface.payload.metadata["compassMode"] != "standalone",
              surface.payload.metadata["standalone"] != "true" else {
            return false
        }
        return surface.payload.metadata["compassMode"] == "runStep" ||
            surface.payload.metadata["compassMode"] == nil
    }

    private var allowsCompassPhotoProof: Bool {
        surface.type == .wonderCompass && surface.payload.metadata["proofKind"] == "sentence-or-photo"
    }

    private var isCompassRunStartPage: Bool {
        surface.type == .wonderCompass &&
            surface.payload.metadata["compassStep"] == "run" &&
            surface.payload.metadata["compassMode"] != "standalone"
    }

    private var isPreparedCompassRunStartPage: Bool {
        isCompassRunStartPage && surface.payload.metadata["compassRunPrepared"] == "true"
    }

    private var isStandalonePlayfulMissionPage: Bool {
        surface.type == .wonderCompass &&
            surface.payload.metadata["compassStep"] == "sense" &&
            surface.payload.metadata["compassMode"] == "standalone" &&
            surface.payload.metadata["playfulMissionID"] != nil
    }

    private var playfulMissionOpenBurstText: String {
        surface.payload.metadata["playfulMissionTitle"]?.nonEmpty ?? "PLAY"
    }

    private var activePennySentenceLesson: PennySentenceMasteryLesson? {
        guard surface.type == .wonderCompass,
              let rawValue = surface.payload.metadata["pennySentenceLesson"] else {
            return nil
        }
        return PennySentenceMasteryLesson(rawValue: rawValue)
    }

    private var isPennySentenceMasteryPage: Bool {
        activePennySentenceLesson != nil
    }

    private var standalonePlayfulMissionProof: String {
        surface.payload.metadata["souvenirPrompt"]?.nonEmpty ??
            "Keep one concrete detail as evidence."
    }

    private var standalonePlayfulMissionProofLabel: String {
        allowsCompassPhotoProof ? "KEEP WHAT YOU FOUND" : "KEEP ONE SENTENCE AS PROOF"
    }

    private var standalonePlayfulMissionAside: String {
        if allowsCompassPhotoProof {
            return "Type or paste one sentence below, add one photo, or use both."
        }
        return "Type or paste one sentence below. That is all you need to keep this mission."
    }

    private var showsGenericMarginNoteEditor: Bool {
        !isScrapbookReadbackPage &&
            !(isCompassRunStepPage && currentCompassStep != .write) &&
            !surface.isStoryPlayablePage &&
            (currentCompassStep == nil || currentCompassStep == .write) &&
            surface.type != .askTheBook &&
            surface.type != .calendar &&
            surface.type != .gamePage &&
            surface.type != .inkrestOfficeHours &&
            surface.type != .faeBargain &&
            !isChapterPrimerPage &&
            !isBookJumpPage &&
            surface.type != .note &&
            surface.type != .bookRemembered &&
            surface.type != .bookNotices &&
            surface.type != .bookPocket &&
            surface.type != .taleBound &&
            surface.type != .tarot &&
            !isPendingLetterPage
    }

    /// These generated reflective Pages can carry the same reader keepsakes as
    /// an ordinary Page. Kept readbacks remain read-only because their thought,
    /// photograph, and voice memo are already bound into the archived copy.
    private var acceptsReaderKeepsakes: Bool {
        guard !isKeptReadbackPage else { return false }
        return surface.type == .bookRemembered ||
            surface.type == .bookNotices ||
            surface.type == .bookPocket
    }

    private var preparedPageLabel: String {
        if surface.renderStyle == .gentleTranslation {
            return "Private translation"
        }
        return surface.payload.headline
    }

    private var keepPageButtonTitle: String {
        #if canImport(UIKit)
        if isCameraFirstIlluminatedPage,
           hasPendingCameraPhoto,
           manualPhotoDraft == nil,
           enchantmentResult == nil {
            return "Keep original"
        }
        #endif
        if surface.type == .bookRemembered {
            return "Bind this return"
        }
        if surface.type == .taleBound {
            return "Keep this tale"
        }
        if surface.type == .tarot {
            return "Keep this reading"
        }
        if surface.type == .bookNotices {
            let metadata = surface.payload.metadata
            if metadata["constellationName"]?.nonEmpty != nil {
                return "Keep this name"
            }
            if metadata["wagerMoment"] == "sealed" {
                return "Seal this margin"
            }
            if metadata["wagerMoment"] == "opened" {
                return "Keep this verdict"
            }
            return "Keep this noticing"
        }
        if isStandalonePlayfulMissionPage {
            return currentCompassNote.isEmpty && proofPhotoURL != nil ? "Keep photo" : "Keep sentence"
        }
        if isPreparedCompassRunStartPage {
            return "Begin at North"
        }
        if isCompassRunStartPage {
            return "Finish the six questions"
        }
        if isBookJumpPage, bookJumpAction == .start {
            return "Open the Spine"
        }
        return "Keep this page"
    }

    private var externalURL: URL? {
        guard let value = surface.payload.metadata["url"] else {
            return nil
        }
        return URL(string: value)
    }

    private var weatherSymbolName: String? {
        guard surface.type == .weather else { return nil }
        return surface.payload.metadata["symbol"]
    }

    private var illustrationAssetName: String? {
        guard surface.type == .illustration else { return nil }
        let value = surface.payload.metadata["assetName"] ?? ""
        return value.isEmpty ? nil : value
    }

    /// A small signed-letter portrait (e.g. Pippa on the First Mission), driven
    /// purely by metadata so any lore letter can claim a face.
    private var letterPortraitAssetName: String? {
        surface.payload.metadata["portraitAsset"]?.nonEmpty
    }

    private var illuminatedDraft: IlluminatedPhotoDraft? {
        if let manualPhotoDraft {
            return manualPhotoDraft
        }
        #if canImport(UIKit)
        guard !isCameraFirstIlluminatedPage else { return nil }
        #endif
        guard surface.type == .illuminatedPhoto,
              let sourceAssetName = surface.payload.metadata["sourceAssetName"] else {
            return nil
        }
        let fallback = FakePhotoIlluminationAnalyzer.analyze(assetName: sourceAssetName)
        let analysis = PhotoAnalysis.fromSurfaceMetadata(surface.payload.metadata, fallback: fallback)
        return IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: sourceAssetName,
            seed: abs(surface.id.stableHash),
            assetLocalIdentifier: surface.payload.metadata["assetLocalIdentifier"]
        )
    }

    private var illuminatedArtifactURL: URL? {
        if let renderedIlluminatedPageURL,
           FileManager.default.fileExists(atPath: renderedIlluminatedPageURL.path) {
            return renderedIlluminatedPageURL
        }
        if let renderedPath = surface.payload.metadata["renderedPreviewPath"],
           FileManager.default.fileExists(atPath: renderedPath) {
            return URL(fileURLWithPath: renderedPath)
        }
        return nil
    }

    private var quoteCardShareURL: URL? {
        guard let illuminatedQuoteCardURL,
              FileManager.default.fileExists(atPath: illuminatedQuoteCardURL.path) else {
            return nil
        }
        return illuminatedQuoteCardURL
    }

    private var bookOfYouPressedPageURL: URL? {
        guard let bookOfYouShareCardURL,
              FileManager.default.fileExists(atPath: bookOfYouShareCardURL.path) else {
            return nil
        }
        return bookOfYouShareCardURL
    }

    private var bookOfYouPageRevealURL: URL? {
        guard let bookOfYouRevealVideoURL,
              FileManager.default.fileExists(atPath: bookOfYouRevealVideoURL.path) else {
            return nil
        }
        return bookOfYouRevealVideoURL
    }

    private var canPressBookOfYouShareCard: Bool {
        surface.type == .bookOfYou && BookOfYouShareArtifact.make(from: surface) != nil
    }

    private var canShareIlluminatedQuoteCard: Bool {
        switch surface.type {
        case .gamePage:
            return gameResultSurface != nil && illuminatedQuoteText != nil
        case .wonderCompass:
            return illuminatedQuoteText != nil &&
                (currentCompassStep == .write || isStandalonePlayfulMissionPage || isKeptReadbackPage)
        case .souvenir, .rest:
            return illuminatedQuoteText != nil
        case .quotes:
            return illuminatedQuoteText != nil
        default:
            return isKeptReadbackPage && illuminatedQuoteText != nil
        }
    }

    private var illuminatedQuoteText: String? {
        let candidates: [String?]
        switch surface.type {
        case .gamePage:
            candidates = [
                gameResultSurface?.payload.body,
                surface.payload.metadata["poem"],
                isKeptReadbackPage ? preparedInput : nil
            ]
        case .wonderCompass:
            candidates = [
                currentCompassStep == .write ? preparedInput : nil,
                surface.payload.metadata["souvenir"],
                surface.payload.metadata["sentence"],
                surface.payload.metadata["mission"],
                isKeptReadbackPage ? preparedInput : nil
            ]
        case .souvenir, .rest:
            candidates = [
                preparedInput,
                surface.payload.metadata["quote"],
                surface.payload.metadata["souvenir"],
                surface.payload.metadata["sentence"],
                surface.payload.metadata["centerSentence"],
                isKeptReadbackPage ? surface.payload.body : nil
            ]
        default:
            candidates = [
                surface.payload.metadata["quote"],
                surface.payload.metadata["souvenir"],
                surface.payload.metadata["sentence"],
                surface.payload.metadata["centerSentence"],
                surface.payload.metadata["poem"],
                isKeptReadbackPage ? preparedInput : nil
            ]
        }
        for candidate in candidates {
            guard let line = quoteCandidate(from: candidate) else { continue }
            return line
        }
        return nil
    }

    private func quoteCandidate(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cleaned = trimmed
            .components(separatedBy: "\n\n")
            .first { block in
                let lower = block.lowercased()
                return !lower.hasPrefix("margin note:") &&
                    !lower.hasPrefix("souvenir prompt:") &&
                    !lower.hasPrefix("question:") &&
                    !lower.hasPrefix("response:")
            }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= 420 {
            return cleaned
        }
        let clipped = String(cleaned.prefix(417)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped.isEmpty ? nil : "\(clipped)..."
    }

    private var quoteCardSourceTitle: String {
        if surface.type == .gamePage {
            return "Sentence Runner"
        }
        if surface.type == .wonderCompass {
            return surface.payload.metadata["playfulMissionTitle"]?.nonEmpty ?? "Wonder Compass"
        }
        if surface.type == .rest {
            return "Center Card"
        }
        if surface.type == .souvenir {
            return "One-Sentence Souvenir"
        }
        if surface.type == .quotes {
            return surface.payload.metadata["quoteAuthor"]?.nonEmpty ?? "A Quote to Keep"
        }
        return surface.type.shortTitle
    }

    private var quoteCardWeatherLine: String {
        let metadata = surface.payload.metadata
        let candidate = metadata["weather"]?.nonEmpty ??
            metadata["weatherPhrase"]?.nonEmpty ??
            metadata["weatherLine"]?.nonEmpty ??
            weatherSignal?.phrase.nonEmpty
        return candidate ?? "Weather unrecorded; the page kept its own light."
    }

    private var quoteCardDateLine: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private var enchantmentArtifactURL: URL? {
        if let renderedPath = currentEnchantmentSurface?.payload.metadata["renderedPreviewPath"],
           FileManager.default.fileExists(atPath: renderedPath) {
            return URL(fileURLWithPath: renderedPath)
        }
        if let renderedIlluminatedPageURL,
           FileManager.default.fileExists(atPath: renderedIlluminatedPageURL.path) {
            return renderedIlluminatedPageURL
        }
        if surface.type == .enchantment,
           let renderedPath = surface.payload.metadata["renderedPreviewPath"],
           FileManager.default.fileExists(atPath: renderedPath) {
            return URL(fileURLWithPath: renderedPath)
        }
        return nil
    }

    private var castMemberImage: UIImage? {
        guard surface.payload.metadata["illustrationKind"] == "cast",
              surface.payload.metadata["imageAssetKind"] == BookPageMediaAsset.Kind.renderedImageFile.rawValue,
              let path = surface.payload.metadata["imageAssetReference"],
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }

    private var effectiveSurface: SurfacePage {
        gameResultSurface ?? currentEnchantmentSurface ?? currentIlluminatedSurface ?? surface
    }

    private var effectiveProofSurface: SurfacePage {
        var result: SurfacePage
        if surface.type == .wonderCompass, let proofPhotoURL {
            result = surfaceWithProofImage(
                url: proofPhotoURL,
                caption: surface.payload.metadata["playfulMissionTitle"] ?? surface.payload.headline
            )
        } else {
        #if canImport(UIKit)
            if isCameraFirstIlluminatedPage,
               currentEnchantmentSurface == nil,
               currentIlluminatedSurface == nil,
               let pendingCameraPhotoURL {
                result = surfaceWithProofImage(url: pendingCameraPhotoURL, caption: surface.payload.headline)
            } else {
                result = effectiveSurface
            }
        #else
            result = effectiveSurface
        #endif
        }
        if surface.type == .tarot,
           let tarotReading,
           let data = try? JSONEncoder().encode(tarotReading),
           let encoded = String(data: data, encoding: .utf8) {
            var tarotMetadata = [
                TarotReadingArtifact.metadataKey: encoded,
                "tarotSpread": tarotReading.spread.rawValue,
                "tarotDeckVersion": tarotReading.deckVersion,
                "tarotCastReading": tarotReading.castReading?.isEmpty == false ? "true" : "false",
                "tarotReaderID": tarotReading.readerID ?? "legacy-aurora",
                "tarotContextSourceCount": "\(tarotReading.contextReceipt?.sources.count ?? 0)",
                "tarotContextEdgeCount": "\(tarotReading.contextReceipt?.edges.count ?? 0)",
                "tarotRetrievalMode": tarotReading.contextReceipt?.retrievalMode ?? "cards-only"
            ]
            if let receipt = tarotReading.contextReceipt {
                tarotMetadata["tarotContextSourceIDs"] = receipt.sources.map(\.referenceID).joined(separator: ",")
                tarotMetadata["tarotContextEdgeKinds"] = Array(Set(receipt.edges.map(\.kind))).sorted().joined(separator: ",")
            }
            result = result.withMetadata(tarotMetadata)
        }
        return result
    }

    private func surfaceWithProofImage(url: URL, caption: String) -> SurfacePage {
        var metadata = surface.payload.metadata
        metadata["proofImagePath"] = url.path
        metadata["proofCaption"] = caption
        return SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: BookPagePayload(
                headline: surface.payload.headline,
                body: surface.payload.body,
                metadata: metadata
            )
        )
    }

    private var currentIlluminatedSurface: SurfacePage? {
        guard surface.type == .illuminatedPhoto,
              let illuminatedDraft else {
            return nil
        }
        return SurfacePage.illuminatedPhotoSurface(
            draft: illuminatedDraft,
            renderedURL: illuminatedArtifactURL,
            idSuffix: "active-\(illuminatedDraft.id.uuidString)"
        )
    }

    private var articlePreviews: [(title: String, url: URL, publishedAt: String, preview: String)] {
        guard surface.type == .patreon,
              let previews = surface.payload.metadata["articlePreviews"]?.nonEmpty else {
            return []
        }

        return previews
            .split(separator: "\n")
            .compactMap { line -> (title: String, url: URL, publishedAt: String, preview: String)? in
                let parts = line.components(separatedBy: "||")
                guard parts.count >= 2,
                      let url = URL(string: parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    return nil
                }
                let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let publishedAt = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let preview = parts.count > 3 ? parts[3...].joined(separator: "||").trimmingCharacters(in: .whitespacesAndNewlines) : ""
                return title.isEmpty ? nil : (title, url, publishedAt, preview)
            }
    }

    private var articleLinks: [(title: String, url: URL)] {
        guard surface.type == .patreon,
              let links = surface.payload.metadata["links"] else {
            return []
        }

        return links
            .split(separator: "\n")
            .compactMap { line -> (title: String, url: URL)? in
                let parts = line.components(separatedBy: "||")
                guard parts.count == 2,
                      let url = URL(string: parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    return nil
                }
                let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? nil : (title, url)
            }
    }

    private var storySceneDraft: StoryPageSceneDraft? {
        guard surface.isStoryPlayablePage else { return nil }
        return StoryPageSceneDraft(surface: surface)
    }

    private var activeStoryTurn: StoryPageSessionTurn? {
        storyTurns.last ?? storySceneDraft.map { StoryPageSessionTurn(draft: $0) }
    }

    private var isFaeParleyPage: Bool {
        surface.type == .bookFae && (
            surface.payload.metadata["storyGenreName"] == "Old Faerie Parley" ||
            surface.payload.metadata["faeInteraction"] == "true"
        )
    }

    private func storyScribeLabel(stage: String) -> String {
        guard isFaeParleyPage else { return "story-page-\(stage)" }
        return "fae-parley-\(surface.payload.metadata["faeKind"] ?? "bookSprite")-\(stage)"
    }

    private var sheetHasLocalBrainActions: Bool {
        switch surface.type {
        case .illuminatedPhoto,
             .narrativeOS,
             .bookFae,
             .academyClass,
             .askTheBook,
             .enchantment,
             .inkrestOfficeHours,
             .faeBargain,
             .wonderCompass,
             .letter,
             .gossip,
             .facultyResearch,
             .supportGuild,
             .twoReadings,
             .castBond,
             .bookJump,
             .elective,
             .packPage,
             .theBleed:
            return true
        default:
            return isEnchantmentPage
        }
    }

    private var pageOwnedScribeLabel: String? {
        if let label = localPageOwnedScribeLabel { return label }
        if let label = ambientPageOwnedScribeLabel { return label }
        return nil
    }

    private var localPageOwnedScribeLabel: String? {
        if isCastingEnchantment { return "enchantment" }
        if isAnsweringEnchantedObject { return "everything-speaks-reply" }
        if isLoadingManualPhoto || isChoosingBookPhoto { return "photo-illumination" }
        if isGeneratingStoryResult { return storyScribeLabel(stage: "result") }
        if isContinuingStoryPage { return storyScribeLabel(stage: "continuation") }
        if isAskingTheBook { return "ask-the-book" }
        if isInkrestSitting { return "inkrest-office-hours" }
        if isFaePaying { return "fae-bargain" }
        if isGeneratingCompassRun { return "wonder-compass-run" }
        if isGeneratingPlayfulMission { return "wonder-compass-playful-mission" }
        if isRewritingBraid { return "braid-rewrite" }
        if isImprovingBraid { return "braid-taste-note" }
        return nil
    }

    private var ambientPageOwnedScribeLabel: String? {
        guard isLocalBrainWorking, sheetHasLocalBrainActions else { return nil }
        let label = localBrainWorkLabel.lowercased()
        if isPendingLetterPage, label.contains("letter") { return localBrainWorkLabel }
        switch surface.type {
        case .letter where label.contains("letter"):
            return localBrainWorkLabel
        case .gossip where label.contains("gossip") || label.contains("aside"),
             .bookAside where label.contains("gossip") || label.contains("aside"):
            return localBrainWorkLabel
        case .facultyResearch where label.contains("faculty") || label.contains("research"):
            return localBrainWorkLabel
        case .supportGuild where label.contains("support-guild"):
            return localBrainWorkLabel
        case .twoReadings where label.contains("two-readings"):
            return localBrainWorkLabel
        case .castBond where label.contains("cast-bond"):
            return localBrainWorkLabel
        case .bookJump where label.contains("book-jump"):
            return localBrainWorkLabel
        case .elective where label.contains("elective"):
            return localBrainWorkLabel
        case .packPage where label.contains("pack-page"):
            return localBrainWorkLabel
        case .theBleed where label.contains("the-bleed"):
            return localBrainWorkLabel
        case .wonderCompass where label.contains("wonder-compass"):
            return localBrainWorkLabel
        case .narrativeOS where label.contains("story-page") || label.contains("narrative"):
            return localBrainWorkLabel
        case .bookFae where label.contains("fae") || label.contains("book-fae"):
            return localBrainWorkLabel
        default:
            return nil
        }
    }

    private func scribeWorkCard(
        _ label: String,
        quip: String? = nil,
        presentation: ScribeWorkPresentation = .page
    ) -> some View {
        LiveLocalBrainWorkingStatusCard(
            progress: localBrainProgress,
            label: label,
            quip: quip,
            startedAt: localBrainWorkStartedAt,
            queuedCount: localBrainQueuedCount,
            presentation: presentation
        )
        .id(Self.localBrainStatusScrollID)
        .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
    }

    private func scrollToLocalBrainStatus(_ scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if reduceMotion {
                scrollProxy.scrollTo(Self.localBrainStatusScrollID, anchor: .top)
            } else {
                withAnimation(.easeInOut(duration: 0.28)) {
                    scrollProxy.scrollTo(Self.localBrainStatusScrollID, anchor: .top)
                }
            }
        }
    }

    /// Carry the reader to the finished Enchantment. The plate and the result
    /// text are inserted above the casting card they were watching, so without
    /// this the page silently reflows out from under them. The delay lets the
    /// insertion animation settle first, or the scroll chases a moving target.
    private func scrollToEnchantmentArrival(_ scrollProxy: ScrollViewProxy) {
        let target = illuminatedDraft == nil
            ? Self.enchantmentResultScrollID
            : Self.enchantmentPlateScrollID
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.45)) {
            if reduceMotion {
                scrollProxy.scrollTo(target, anchor: .top)
            } else {
                withAnimation(.easeInOut(duration: 0.42)) {
                    scrollProxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }

    private var openPagePrimaryText: Color {
        BookPalette.lampGold
    }

    private var openPageSecondaryText: Color {
        BookPalette.nightText.opacity(0.86)
    }

    private var calloutBodyText: Color {
        isPreparedPage ? BookPalette.ink.opacity(0.78) : openPageSecondaryText
    }

    private var sharePageText: String {
        let marginNote = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String

        if surface.isStoryPlayablePage, let activeStoryTurn {
            let choiceLines = activeStoryTurn.draft.choices.map { "• \($0.kindLabel): \($0.title)" }.joined(separator: "\n")
            let selectedResult = activeStoryTurn.selectedChoice.map { choice in
                let inkbones = activeStoryTurn.inkbonesResolution(for: choice)
                    .map { "\n\nInkbones: \($0.mechanicSummary)" }
                    ?? ""
                return "\n\nChosen path: \(choice.title)\(inkbones)\n\n\(activeStoryTurn.result(for: choice))"
            } ?? ""
            body = [
                activeStoryTurn.draft.scene,
                choiceLines.isEmpty ? nil : "Choices:\n\(choiceLines)",
                selectedResult.nonEmpty
            ].compactMap { $0 }.joined(separator: "\n\n")
        } else if isPreparedPage {
            body = bleedEditionText ?? surface.payload.body
        } else {
            body = [surface.detail, preparedInput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }

        let note = marginNote.isEmpty ? "" : "\n\nMargin note: \(marginNote)"
        let source = externalURL.map { "\n\nPublic shelf: \($0.absoluteString)" } ?? ""
        return [
            surface.prompt,
            body.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            + note
            + source
            + "\n\nReEnchanted"
    }

    @ViewBuilder
    private var moonwriteGlowNote: some View {
        Label("Moonwrite is active. Souvenir sentences glow under the full moon.", systemImage: "moonphase.full.moon")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(red: 0.92, green: 0.88, blue: 1.0))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.24, blue: 0.48).opacity(0.72),
                        BookPalette.nightPanel.opacity(0.84)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.70, green: 0.62, blue: 1.0).opacity(0.22), radius: 12, x: 0, y: 0)
    }

    @ViewBuilder
    private var pageShareControl: some View {
        if surface.type == .bookOfYou {
            bookOfYouPressedPageShareControl
        } else if let artifactURL = illuminatedArtifactURL {
            ShareLink(item: artifactURL) {
                Label("Share page", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                    }
            }
            .foregroundStyle(BookPalette.lampGold)
        } else if canShareIlluminatedQuoteCard, let cardURL = quoteCardShareURL {
            VStack(alignment: .leading, spacing: 8) {
                ShareLink(item: cardURL) {
                    Label("Share illuminated card", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                        }
                }
                .foregroundStyle(BookPalette.lampGold)

                ShareLink(item: sharePageText) {
                    Label("Share text instead", systemImage: "text.quote")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(BookPalette.paper.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .foregroundStyle(openPageSecondaryText)
            }
        } else if canShareIlluminatedQuoteCard {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await prepareIlluminatedQuoteCard(force: true) }
                } label: {
                    Label(isPreparingQuoteCard ? "Illuminating..." : "Prepare share card", systemImage: "wand.and.sparkles")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.lampGold)
                .disabled(isPreparingQuoteCard)

                if !quoteCardMessage.isEmpty {
                    Text(quoteCardMessage)
                        .font(.caption)
                        .foregroundStyle(openPageSecondaryText)
                }
            }
        } else {
            ShareLink(item: sharePageText) {
                Label("Share page", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                    }
            }
            .foregroundStyle(BookPalette.lampGold)
        }
    }

    @ViewBuilder
    private var bookOfYouPressedPageShareControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artifact = BookOfYouShareArtifact.make(from: surface) {
                BookOfYouPressedPageSpotlight(
                    artifact: artifact,
                    isWorking: isPressingBookOfYouShareCard || isPressingBookOfYouRevealVideo
                )
            }

            if let videoURL = bookOfYouPageRevealURL {
                ShareLink(item: videoURL) {
                    Label("Share page reveal", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.44), lineWidth: 1)
                        }
                }
                .foregroundStyle(BookPalette.lampGold)
            } else if canPressBookOfYouShareCard {
                Button {
                    Task { await prepareBookOfYouRevealVideo() }
                } label: {
                    Label(isPressingBookOfYouRevealVideo ? "Pressing reveal..." : "Make page reveal video", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.44), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.lampGold)
                .disabled(isPressingBookOfYouRevealVideo || isPressingBookOfYouShareCard)
            }

            if let url = bookOfYouPressedPageURL {
                ShareLink(item: url) {
                    Label("Share pressed page", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                        }
                }
                .foregroundStyle(BookPalette.lampGold)

                ShareLink(item: sharePageText) {
                    Label("Share text instead", systemImage: "text.quote")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(BookPalette.paper.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .foregroundStyle(openPageSecondaryText)
            } else if canPressBookOfYouShareCard {
                Button {
                    Task { await prepareBookOfYouShareCard(force: true) }
                } label: {
                    Label(isPressingBookOfYouShareCard ? "Pressing..." : "Press share page", systemImage: "book.pages")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.lampGold)
                .disabled(isPressingBookOfYouShareCard)
            } else {
                ShareLink(item: sharePageText) {
                    Label("Share page", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                        }
                }
                .foregroundStyle(BookPalette.lampGold)
            }

            if !bookOfYouShareMessage.isEmpty {
                Text(bookOfYouShareMessage)
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText)
            }
        }
    }

    @ViewBuilder
    var body: some View {
        if isEmbedded {
            pageRoot
        } else {
            NavigationStack {
                pageRoot
            }
        }
    }

    private var pageRoot: some View {
        ZStack {
                BookBackground(
                    isQuiet: isLocalBrainWorking || isEmbedded,
                    showsAmbientLetters: !isEmbedded
                )

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        AnyView(pageSheetContent)
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 44)
                            .frame(maxWidth: isEmbedded ? 740 : nil)
                            .frame(maxWidth: .infinity)
                            // All of the page's prose is long-press selectable/copyable.
                            // (Editable fields keep their own selection behavior.)
                            .textSelection(.enabled)
                    }
                    .onChange(of: isLocalBrainWorking) { _, isWorking in
                        guard isWorking else { return }
                        scrollToLocalBrainStatus(scrollProxy)
                    }
                    .onChange(of: localPageOwnedScribeLabel) { _, label in
                        guard label != nil else { return }
                        scrollToLocalBrainStatus(scrollProxy)
                    }
                    .onChange(of: enchantmentArrivalTick) { _, tick in
                        guard tick > 0 else { return }
                        scrollToEnchantmentArrival(scrollProxy)
                    }
                    .background {
                        LocalBrainPreviewStartObserver(
                            progress: localBrainProgress,
                            isWorking: isLocalBrainWorking
                        ) {
                            scrollToLocalBrainStatus(scrollProxy)
                        }
                    }
                }
                .scrollIndicators(.visible)

                if isStandalonePlayfulMissionPage {
                    LivingInkBurst(
                        trigger: playfulMissionOpenBurstTrigger,
                        text: playfulMissionOpenBurstText,
                        mood: .kept,
                        intensity: 1.08
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                    .zIndex(10)
                }

                if isCommittingKeep {
                    Label("KEPT", systemImage: "seal.fill")
                        .font(.system(.headline, design: .serif, weight: .black))
                        .tracking(1.4)
                        .foregroundStyle(BookPalette.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold, in: Capsule())
                        .overlay {
                            Capsule().stroke(BookPalette.paper.opacity(0.88), lineWidth: 2)
                        }
                        .shadow(color: BookPalette.lampGold.opacity(0.48), radius: 18)
                        .transition(.scale(scale: 0.55).combined(with: .opacity))
                        .zIndex(20)
                        .accessibilityLabel("Page kept")
                }

                if isTuckingPage {
                    Color(red: 0.24, green: 0.06, blue: 0.08)
                        .opacity(reduceMotion ? 0.22 : 0.68)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if openedPageTurnProgress > 0.001 {
                    PageTurnWipe(progress: openedPageTurnProgress)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .zIndex(30)
                }

                if surface.payload.metadata["bookInterjectionPhysicalAct"] == "dog-ear" {
                    VStack {
                        HStack {
                            Spacer()
                            BookInterjectionDogEarMark(tint: BookPalette.lampGold)
                                .frame(width: 62, height: 62)
                                .accessibilityLabel("The Book dog-eared this Page")
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 6)
                    .allowsHitTesting(false)
                    .zIndex(12)
                }

                if surface.payload.metadata["bookInterjectionPhysicalAct"] == "smudge" {
                    VStack {
                        HStack {
                            Spacer()
                            BookInterjectionSmudgeMark(tint: BookPalette.ink)
                                .frame(width: 72, height: 110)
                                .rotationEffect(.degrees(-7))
                        }
                        Spacer()
                    }
                    .padding(.top, 132)
                    .padding(.trailing, 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(2)
                }

                if surface.payload.metadata["bookInterjectionPhysicalAct"] == "left-open" {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            BookInterjectionOpenLeafMark(tint: BookPalette.lampGold)
                                .frame(width: 92, height: 50)
                                .accessibilityLabel("The Book left an older Page open here")
                        }
                    }
                    .padding(.bottom, 12)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
                    .zIndex(12)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: isCommittingKeep)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isTuckingPage)
            .animation(BookMotion.result(reduceMotion), value: pageOwnedScribeLabel)
            .sheet(isPresented: $isPublicMarginsContributionPresented) {
                PublicMarginsContributionSheet(
                    eventID: "page-souvenir",
                    initialSentence: publicMarginsSuggestedSentence
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEmbedded ? "Close page" : (isKeptReadbackPage ? "Close" : "Let it wait")) {
                        BookFeedback.play(.dismissPage)
                        letPageWait()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                if isKeptReadbackPage, keptPageID != nil, onRemarkKeptPage != nil {
                    ToolbarItem(placement: .secondaryAction) {
                        shelfMarkMenu
                    }
                }
                if !isKeptReadbackPage && !isBookJumpActivePage && !isPendingNotePage && !isBookWorkingInvitationPage {
                    ToolbarItem(placement: .secondaryAction) {
                        shelfMarkMenu
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(keepPageButtonTitle) {
                            keepCurrentPage()
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!canKeep || isGeneratingCompassRun || isCommittingKeep)
                    }
                }
            }
            .toolbarBackground(BookPalette.nightPanel.opacity(0.98), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #if canImport(PhotosUI)
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if allowsCompassPhotoProof {
                        await loadCompassProofPhoto(from: newValue)
                    } else if isEnchantmentPage {
                        await castEnchantment(from: newValue)
                    } else if isCameraFirstIlluminatedPage {
                        await loadCameraPhotoForChoice(from: newValue)
                    } else {
                        await loadManualPhoto(from: newValue)
                    }
                }
            }
            .onChange(of: pressedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadPressedPhoto(from: newValue) }
            }
            #endif
            .onDisappear {
                // Finalize (don't delete) any in-progress take so the mic and
                // audio session don't stay live after the sheet closes.
                if keptVoiceRecorder.isRecording {
                    _ = keptVoiceRecorder.stop()
                }
            }
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: .bookReclaimMemoryForGeneration)) { _ in
                // A generation is about to be refused for want of room, and a
                // full-resolution photograph is the largest thing this Page
                // holds. Once its plate has been drawn to a file the original
                // has no job left: the preview reads the file, and only a
                // re-prepare would want the source back. Better to redraw a
                // plate on request than to refuse the reader their next page.
                guard renderedIlluminatedPageURL != nil else { return }
                manualPhotoImage = nil
                pendingCameraPhotoData = nil
                pendingCameraPhotoImage = nil
            }
            #endif
            #if canImport(UIKit) && canImport(PhotosUI)
            .task {
                guard isCameraFirstIlluminatedPage, !didAutoOpenCamera else { return }
                didAutoOpenCamera = true
                if BookCameraCaptureView.isCameraAvailable {
                    isCameraPresented = true
                } else {
                    illuminationMessage = "This device cannot open the camera here. Choose a photo from the library instead."
                }
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                BookCameraCaptureView { data in
                    Task {
                        if allowsCompassPhotoProof {
                            await loadCompassProofPhoto(imageData: data)
                        } else if isEnchantmentPage {
                            await castEnchantment(imageData: data)
                        } else if isCameraFirstIlluminatedPage {
                            await holdCameraPhotoForChoice(imageData: data)
                        } else {
                            await loadManualPhoto(imageData: data)
                        }
                    }
                }
                .ignoresSafeArea()
            }
            #endif
            .fullScreenCover(isPresented: $isGamePagePresented) {
                SentenceRunnerGameView(
                    phrases: runnerPhrasesForNextRun,
                    nothingPhrases: gameNothingPhrases,
                    phraseSources: gamePhraseSources,
                    chosenThread: activeRunnerThread,
                    runShape: gameRunShape,
                    folioRunCount: sentenceRunnerFolioRunNumber - 1,
                    onCancel: {
                        isGamePagePresented = false
                    },
                    onFinish: { result in
                        lastGameResult = result
                        gameRunBraided = false
                        gameBraidMessage = ""
                        gameResultSurface = gameResultPage(from: result)
                        text = result.keepText
                        if let returnPhrase = result.returnPhrase {
                            runnerReturnPhrase = returnPhrase
                        }
                        sessionRunnerFolioRuns += 1
                        isGamePagePresented = false
                    }
                )
            }
            .fullScreenCover(isPresented: $isAtlasFullScreenPresented) {
                MarginsAtlasFullScreenView(
                    variant: atlasVariant,
                    graph: atlasGraph,
                    selectedNodeID: $selectedAtlasNodeID
                )
            }
            .sheet(item: $inspectedPhraseSource) { source in
                phraseSourceModal(source)
            }
            .task {
                if surface.type == .illuminatedPhoto && !isCameraFirstIlluminatedPage {
                    await prepareIlluminatedArtifactIfNeeded()
                }
                if canShareIlluminatedQuoteCard, quoteCardShareURL == nil {
                    await prepareIlluminatedQuoteCard(force: false)
                }
                if canPressBookOfYouShareCard, bookOfYouPressedPageURL == nil {
                    await prepareBookOfYouShareCard(force: false)
                }
                if surface.isStoryPlayablePage, !isLocalBrainIssuePage, storyTurns.isEmpty, let storySceneDraft {
                    storyTurns = [StoryPageSessionTurn(draft: storySceneDraft)]
                }
            }
            .onAppear {
                if !didRecordPageOpened {
                    didRecordPageOpened = true
                    onPageOpened(surface, Date())
                }
                seedExternalSparkContinuation()
                seedTarotReadingIfNeeded()
                if isStandalonePlayfulMissionPage, !didPlayPlayfulMissionOpenBurst {
                    didPlayPlayfulMissionOpenBurst = true
                    playfulMissionOpenBurstTrigger += 1
                }
                tutorTouchForThisPage()
                seedInkrestIntakeIfNeeded()
                playCeremonyOpenCueIfNeeded()
                revealOpenedPageIfNeeded()
                seedSeasonalDispatchControls()
            }
            .onChange(of: tarotReading) { _, reading in
                persistTarotDraft(reading)
            }
            .overlay(alignment: .bottom) {
                if let activeTutorNote {
                    MarginTutorNoteCard(note: activeTutorNote) {
                        withAnimation(BookMotion.retreat(reduceMotion)) {
                            self.activeTutorNote = nil
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: activeTutorNote.id) {
                        try? await Task.sleep(for: .seconds(12))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.5)) {
                            self.activeTutorNote = nil
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let activeInkbonesThrow {
                    InkbonesThrowOverlay(throwState: activeInkbonesThrow, reduceMotion: reduceMotion)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .zIndex(12)
                }
            }
        .keepsFocusedTextInputVisible()
    }

    private func requestDismiss() {
        if let onDismissRequest {
            onDismissRequest()
        } else {
            dismiss()
        }
    }

    private func seedSeasonalDispatchControls() {
        guard isSeasonalDispatchPage, seasonalDispatchName.isEmpty else { return }
        seasonalDispatchName = surface.payload.metadata["seasonReaderNamed"]?.nonEmpty
            ?? surface.payload.metadata["seasonProposedTitle"]?.nonEmpty
            ?? surface.payload.metadata["seasonCoverLine"]
            ?? ""
        seasonalDispatchIsHeld = surface.payload.metadata["seasonIsHeld"] == "true"
        seasonalDispatchDedication = surface.payload.metadata["seasonDedication"] ?? ""
        seasonalDispatchCoverChoice = BoundVolumeCoverChoice(
            rawValue: surface.payload.metadata["seasonCoverChoice"] ?? ""
        ) ?? .bookChooses
        seasonalDispatchPlateID = surface.payload.metadata["seasonCoverPlateID"]?.nonEmpty
            ?? PublicationCoverCatalogue.rotating.first?.id
            ?? "hedge-door"
        if let x = Double(surface.payload.metadata["seasonCoverFocusX"] ?? ""),
           let y = Double(surface.payload.metadata["seasonCoverFocusY"] ?? "") {
            seasonalDispatchPhotoFocus = PublicationCoverFocus(x: x, y: y)
        }
    }

    private var seasonalDispatchControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The parcel is listening", systemImage: "shippingbox.fill")
                .font(.subheadline.weight(.black))
                .foregroundStyle(BookPalette.lampGold)

            TextField(
                surface.payload.metadata["boundYearAnnual"] == "true"
                    ? "What this year was called"
                    : "What this season was called",
                text: $seasonalDispatchName
            )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.sentences)
            Text("\(seasonalDispatchName.count)/\(SeasonalDispatchWindow.coverTitleCharacterLimit) on the coat")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(
                    seasonalDispatchName.count > SeasonalDispatchWindow.coverTitleCharacterLimit
                        ? Color.red
                        : openPageSecondaryText.opacity(0.72)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button {
                guard let dispatchID = surface.payload.metadata["seasonalDispatchID"] else { return }
                seasonalDispatchMessage = onRenameSeasonalDispatch(dispatchID, seasonalDispatchName)
                BookFeedback.play(.select)
            } label: {
                Label("Put that on the cover", systemImage: "character.cursor.ibeam")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(
                seasonalDispatchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || seasonalDispatchName.count > SeasonalDispatchWindow.coverTitleCharacterLimit
            )

            seasonalDispatchCoverControls

            VStack(alignment: .leading, spacing: 5) {
                Toggle(isOn: $includePrivateWeatherInBoundVolumes) {
                    Label("Let the private charts into this book", systemImage: "heart.text.square")
                        .font(.caption.weight(.bold))
                }
                .toggleStyle(.switch)
                .tint(BookPalette.lampGold)
                Text("When this is on, the almanac may print counts and recurring food, drink, and Inner Weather patterns from Vellum and Inkrest. It does not print raw Health values or diagnose them.")
                    .font(.caption2)
                    .foregroundStyle(openPageSecondaryText.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .background(BookPalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("A dedication, if this one is for somebody")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(openPageSecondaryText)
                TextEditor(text: $seasonalDispatchDedication)
                    .frame(minHeight: 72)
                    .padding(6)
                    .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
                    .onChange(of: seasonalDispatchDedication) { _, value in
                        if value.count > BoundDedication.characterLimit {
                            seasonalDispatchDedication = String(value.prefix(BoundDedication.characterLimit))
                        }
                    }
                Text("\(seasonalDispatchDedication.count)/\(BoundDedication.characterLimit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(openPageSecondaryText.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Button {
                    guard let dispatchID = surface.payload.metadata["seasonalDispatchID"] else { return }
                    seasonalDispatchMessage = onSetSeasonalDispatchDedication(dispatchID, seasonalDispatchDedication)
                    BookFeedback.play(.select)
                } label: {
                    Label(
                        seasonalDispatchDedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Leave the leaf blank"
                            : "Put these words inside",
                        systemImage: "text.book.closed"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.lampGold)
            }

            Button {
                guard let dispatchID = surface.payload.metadata["seasonalDispatchID"] else { return }
                seasonalDispatchMessage = onSetSeasonalDispatchHeld(dispatchID, !seasonalDispatchIsHeld)
                seasonalDispatchIsHeld.toggle()
                BookFeedback.play(seasonalDispatchIsHeld ? .dismissPage : .openPage)
            } label: {
                Label(
                    seasonalDispatchIsHeld ? "Release it" : "Hold it a while",
                    systemImage: seasonalDispatchIsHeld ? "paperplane.fill" : "hand.raised.fill"
                )
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.violet)

            Button {
                onOpenSeasonalDispatchAddress()
                BookFeedback.play(.openPage)
            } label: {
                Label("Check where it goes", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)

            if !seasonalDispatchMessage.isEmpty {
                Text(seasonalDispatchMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.lampGold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
    }

    private var seasonalDispatchCoverControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose its coat")
                .font(.caption.weight(.bold))
                .foregroundStyle(openPageSecondaryText)
            Text("Your photograph, a Bindery plate, or the Book's own choice. All included.")
                .font(.caption2)
                .foregroundStyle(openPageSecondaryText.opacity(0.78))

            HStack(spacing: 6) {
                seasonalDispatchCoverButton(title: "Book chooses", symbol: "sparkles", choice: .bookChooses) {
                    guard let dispatchID = surface.payload.metadata["seasonalDispatchID"] else { return }
                    seasonalDispatchCoverChoice = .bookChooses
                    seasonalDispatchMessage = onSetSeasonalDispatchCover(dispatchID, .bookChooses, nil, nil)
                }
                seasonalDispatchCoverButton(title: "Plates", symbol: "photo.artframe", choice: .binderyPlate) {
                    guard let dispatchID = surface.payload.metadata["seasonalDispatchID"] else { return }
                    seasonalDispatchCoverChoice = .binderyPlate
                    seasonalDispatchMessage = onSetSeasonalDispatchCover(
                        dispatchID, .binderyPlate, seasonalDispatchPlateID, nil
                    )
                }
            }

            if seasonalDispatchCoverChoice == .binderyPlate {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PublicationCoverCatalogue.rotating) { plate in
                            Button {
                                guard let dispatchID = surface.payload.metadata["seasonalDispatchID"] else { return }
                                seasonalDispatchPlateID = plate.id
                                seasonalDispatchMessage = onSetSeasonalDispatchCover(
                                    dispatchID, .binderyPlate, plate.id, nil
                                )
                                BookFeedback.play(.select)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    #if canImport(UIKit)
                                    if let image = UIImage(named: plate.assetName) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 64, height: 96)
                                            .clipped()
                                    }
                                    #endif
                                    Text(plate.title)
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .padding(6)
                                .background(
                                    seasonalDispatchPlateID == plate.id
                                        ? BookPalette.teal.opacity(0.18)
                                        : BookPalette.page.opacity(0.65),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            #if canImport(PhotosUI)
            PhotosPicker(selection: $seasonalDispatchPhotoItem, matching: .images, photoLibrary: .shared()) {
                Label(
                    seasonalDispatchCoverChoice == .readerPhoto ? "Choose another photograph" : "Use your photograph",
                    systemImage: "photo.on.rectangle.angled"
                )
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.violet)
            .onChange(of: seasonalDispatchPhotoItem) { _, item in
                guard let item else { return }
                Task { await loadSeasonalDispatchCoverPhoto(from: item) }
            }
            #endif

            #if canImport(UIKit)
            if let proof = seasonalDispatchCoverProofImage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The coat, with its real words on")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(openPageSecondaryText)
                    Image(uiImage: proof)
                    .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.24), radius: 8, y: 4)
                    Text(surface.payload.metadata["boundYearAnnual"] == "true"
                        ? (seasonalDispatchCoverChoice == .bookChooses
                            ? "This is the dust jacket. Navy linen and gold spine foil wait underneath."
                            : "This prints as the illustrated hardcase. Choosing art replaces linen; it does not pretend foil can print on the boards.")
                        : "This is the front of the perfect-bound softcover. The press file adds its back, spine, and bleed around it.")
                        .font(.caption2)
                        .foregroundStyle(openPageSecondaryText.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            #endif
        }
        .padding(10)
        .background(BookPalette.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    #if canImport(UIKit)
    private var seasonalDispatchCoverProofImage: UIImage? {
        let artwork: MonthlyEditionPDFWriter.VolumeCoverArtwork?
        switch seasonalDispatchCoverChoice {
        case .binderyPlate:
            guard let plate = PublicationCoverCatalogue.plate(id: seasonalDispatchPlateID),
                  let image = UIImage(named: plate.assetName) else { return nil }
            artwork = .init(image: image, titleLayout: plate.titleLayout, id: plate.id)
        case .readerPhoto:
            guard let data = seasonalDispatchPhotoData,
                  let image = UIImage(data: data) else { return nil }
            artwork = .init(
                image: image,
                titleLayout: .photographFooter,
                id: "reader-photo-proof",
                focusPoint: seasonalDispatchPhotoFocus.map { CGPoint(x: $0.x, y: $0.y) }
            )
        case .bookChooses:
            guard !PublicationCoverCatalogue.rotating.isEmpty else { return nil }
            let dispatchID = surface.payload.metadata["seasonalDispatchID"] ?? surface.id
            let index = ConstellationKeeper.stableIndex(
                for: "\(dispatchID)-included-cover",
                count: PublicationCoverCatalogue.rotating.count
            )
            let plate = PublicationCoverCatalogue.rotating[index]
            guard let image = UIImage(named: plate.assetName) else { return nil }
            artwork = .init(image: image, titleLayout: plate.titleLayout, id: plate.id)
        }
        guard let artwork else { return nil }
        let typedTitle = seasonalDispatchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let coverLine = typedTitle.nonEmpty
            ?? surface.payload.metadata["seasonCoverLine"]
            ?? "This Season"
        let originalSubline = surface.payload.metadata["seasonCoverSubline"]
            ?? (surface.payload.metadata["boundYearAnnual"] == "true" ? "the membership year, bound" : "a season, bound")
        let subline = typedTitle.nonEmpty == nil
            ? originalSubline
            : originalSubline.replacingOccurrences(of: "a season I would call this", with: "the season you named")
        let copy = MonthlyEditionPDFWriter.VolumeCoverCopy(
            readerName: surface.payload.metadata["seasonCoverReaderName"] ?? "THE READER",
            coverLine: coverLine,
            coverSubline: subline
        )
        return MonthlyEditionPDFWriter.volumeCoverFrontProof(copy: copy, artwork: artwork)
    }
    #endif

    private func seasonalDispatchCoverButton(
        title: String,
        symbol: String,
        choice: BoundVolumeCoverChoice,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(seasonalDispatchCoverChoice == choice ? BookPalette.teal : BookPalette.violet)
    }

    #if canImport(PhotosUI)
    @MainActor
    private func loadSeasonalDispatchCoverPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              !data.isEmpty,
              let dispatchID = surface.payload.metadata["seasonalDispatchID"] else {
            seasonalDispatchMessage = "That photograph wouldn't come out of the little glass drawer."
            return
        }
        seasonalDispatchPhotoData = data
        if let image = UIImage(data: data) {
            seasonalDispatchPhotoFocus = MonthlyEditionPDFWriter.readerPhotoFocus(for: image)
        } else {
            seasonalDispatchPhotoFocus = nil
        }
        seasonalDispatchCoverChoice = .readerPhoto
        seasonalDispatchMessage = onSetSeasonalDispatchCover(dispatchID, .readerPhoto, nil, data)
        BookFeedback.play(.select)
    }
    #endif

    private func revealOpenedPageIfNeeded() {
        guard !didRevealOpenedPage else { return }
        didRevealOpenedPage = true
        guard !reduceMotion else {
            openedPageTurnProgress = 0
            return
        }
        openedPageTurnProgress = 1
        Task { @MainActor in
            // Let the sheet or iPad reading stand commit its first frame under
            // opaque paper, then turn that paper away in one uninterrupted beat.
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(55))
            guard !Task.isCancelled else { return }
            withAnimation(BookMotion.pageTurn(false)) {
                openedPageTurnProgress = 0
            }
        }
    }

    private func seedExternalSparkContinuation() {
        guard externalSparkContinuation == nil else { return }
        externalSparkContinuation = surface.payload.metadata["tags", default: ""]
            .split(separator: ",")
            .map(String.init)
            .first(where: { $0.hasPrefix("external-continuation:") })
            .flatMap {
                ExternalSparkContinuation(
                    rawValue: String($0.dropFirst("external-continuation:".count))
                )
            }
    }

    private var externalSparkWitnessText: String {
        let title = surface.payload.metadata["sourceTitle"]?.nonEmpty ?? surface.prompt
        return (externalSparkContinuation ?? .ask).witnessText(
            title: title,
            url: surface.payload.metadata["url"]
        )
    }

    private var externalSparkPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("What should this become?", systemImage: "arrow.up.right.circle.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                Text("Choose one door. The original scrap stays exactly as it was.")
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                spacing: 8
            ) {
                ForEach(ExternalSparkContinuation.allCases) { continuation in
                    Button {
                        guard let pageID = keptPageID else { return }
                        externalSparkContinuation = continuation
                        externalSparkMessage = onExternalSparkContinuation(
                            pageID,
                            continuation,
                            Date()
                        )
                        BookFeedback.play(.select)
                    } label: {
                        Label(continuation.title, systemImage: continuation.symbolName)
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(
                                externalSparkContinuation == continuation
                                    ? BookPalette.nightText
                                    : BookPalette.lampGold
                            )
                            .background(
                                externalSparkContinuation == continuation
                                    ? BookPalette.lampGold
                                    : BookPalette.lampGold.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let continuation = externalSparkContinuation {
                Text(continuation.invitation)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(openPagePrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        BookPalette.teal.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                if continuation == .ask {
                    ShareLink(item: externalSparkWitnessText) {
                        Label(
                            "Bring one person in",
                            systemImage: "person.crop.circle.badge.plus"
                        )
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            BookPalette.teal.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .foregroundStyle(BookPalette.teal)
                }

                TextField(
                    "What happened out there? One true line.",
                    text: $externalSparkReturnLine,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .inkFeedback(text: externalSparkReturnLine)

                HStack(spacing: 8) {
                    Button("Nothing came of it") {
                        guard let pageID = keptPageID else { return }
                        externalSparkMessage = onExternalSparkReturn(
                            pageID,
                            continuation,
                            "",
                            false,
                            Date()
                        )
                        BookFeedback.play(.dismissPage)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.violet)

                    Button("Keep what happened") {
                        guard let pageID = keptPageID else { return }
                        let line = externalSparkReturnLine
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !line.isEmpty else { return }
                        externalSparkMessage = onExternalSparkReturn(
                            pageID,
                            continuation,
                            line,
                            true,
                            Date()
                        )
                        externalSparkReturnLine = ""
                        BookFeedback.play(.braidComplete)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(
                        externalSparkReturnLine
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }

            if !externalSparkMessage.isEmpty {
                Text(externalSparkMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
            }
        }
        .padding(14)
        .background(
            BookPalette.nightPanel.opacity(0.56),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
    }

    private func seedTarotReadingIfNeeded() {
        guard surface.type == .tarot, tarotReading == nil else { return }
        let encoded = surface.payload.metadata[TarotReadingArtifact.metadataKey]
            ?? (isKeptReadbackPage ? nil : tarotReadingDraftData.nonEmpty)
        guard let encoded,
              let data = encoded.data(using: .utf8),
              let artifact = try? JSONDecoder().decode(TarotReadingArtifact.self, from: data) else {
            return
        }
        tarotReading = artifact
    }

    private func persistTarotDraft(_ reading: TarotReadingArtifact?) {
        guard surface.type == .tarot, !isKeptReadbackPage else { return }
        guard let reading,
              let data = try? JSONEncoder().encode(reading),
              let encoded = String(data: data, encoding: .utf8) else {
            tarotReadingDraftData = ""
            return
        }
        tarotReadingDraftData = encoded
    }

    /// Quiet by default: an unmarked page shows a plain ellipsis and says
    /// nothing about itself. The Book's own reading is never displayed back as a
    /// verdict: the reader is offered a say, not shown a diagnosis.
    @ViewBuilder
    private var shelfMarkMenu: some View {
        Menu {
            Picker("How should I hold this?", selection: $shelfMark) {
                ForEach(ReaderShelfMark.allCases) { mark in
                    Label(mark.title, systemImage: mark.symbolName).tag(mark)
                }
            }
            .pickerStyle(.inline)
            Text(shelfMark.detail)
        } label: {
            Label("How should I hold this?", systemImage: shelfMark.symbolName)
        }
        .onChange(of: shelfMark) { _, newValue in
            BookFeedback.play(.select)
            // On an archived page the change lands immediately: the reader is
            // changing their mind about something already written down, and
            // there is no "keep" left to hang it on.
            if isKeptReadbackPage, let pageID = keptPageID {
                onRemarkKeptPage?(pageID, newValue)
            }
        }
        .onAppear {
            guard isKeptReadbackPage, shelfMark == .unset else { return }
            let tags = surface.payload.metadata["tags", default: ""]
            if tags.contains(ReaderShelf.sealedTag) {
                shelfMark = .sealed
            } else if tags.contains(ReaderShelf.shadowTag) {
                shelfMark = .heavy
            } else if tags.contains(ReaderShelf.lightTag) {
                shelfMark = .lighter
            }
        }
    }

    private func keepCurrentPage() {
        #if canImport(UIKit)
        if isCameraFirstIlluminatedPage,
           hasPendingCameraPhoto,
           manualPhotoDraft == nil,
           enchantmentResult == nil {
            keepOriginalCameraPhoto()
            return
        }
        #endif
        if isPreparedCompassRunStartPage {
            onNavigateToSurface(compassStepSurface(from: surface, step: .notice))
        } else if isCompassRunStartPage {
            Task { await generateAndSaveCompassRun() }
        } else if isCompassRunStepPage {
            keepCompassStepAndAdvance()
        } else {
            commitCurrentPage()
        }
    }

    private func commitCurrentPage() {
        guard !isCommittingKeep else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.66)) {
            isCommittingKeep = true
        }

        let finish = {
            let input = preparedInput
            let proofSurface = effectiveProofSurface
            let tags = preparedTags(for: proofSurface)
            let extraMedia = keptExtraMedia
            markIlluminatedDraftKept()
            if proofSurface.type == .tarot {
                tarotReadingDraftData = ""
            }

            // Detach the expensive Capture sheet before any observable save
            // mutation can ask SwiftUI to rebuild it. The Keep pipeline touches
            // PlayerVault and the desk several times; doing that on this button's
            // presentation stack can exhaust the main thread's stack.
            requestDismiss()
            DispatchQueue.main.async {
                onSave(proofSurface, input, tags, extraMedia)
                completeStoryMechanicIfNeeded(surface: proofSurface, outcome: input)
                completeFaeBargainIfNeeded()
                completeTwoReadingsIfNeeded()
            }
        }
        if reduceMotion {
            finish()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: finish)
        }
    }

    private func letPageWait() {
        guard !isTuckingPage else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeIn(duration: 0.18)) {
            isTuckingPage = true
        }
        let finish = { requestDismiss() }
        if reduceMotion {
            finish()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: finish)
        }
    }

    @ViewBuilder
    /// The character(s) whose face belongs on this page, in display order.
    private var portraitNames: [String] {
        let metadata = surface.payload.metadata
        func nonEmpty(_ key: String) -> String? { metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
        switch surface.type {
        case .note:
            return [nonEmpty("senderName")].compactMap { $0 }
        case .letter:
            return [nonEmpty("senderName")].compactMap { $0 }
        case .diary where nonEmpty("journalAuthorID") != "the-book":
            return [nonEmpty("journalAuthorName")].compactMap { $0 }
        case .illustration where metadata["illustrationKind"] == "cast":
            return [nonEmpty("entityName")].compactMap { $0 }
        case .twoReadings, .castBond:
            return [nonEmpty("entityAName"), nonEmpty("entityBName")].compactMap { $0 }
        case .gossip, .bookAside:
            let actors = (nonEmpty("actorNames") ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return Array(actors.prefix(3))
        case .wickerDare:
            return ["Wicker Eddies"]
        case .wonderCompass where metadata["playfulMissionID"] != nil:
            return [nonEmpty("missionHostName")].compactMap { $0 }
        case _ where metadata["variant"] == "shadow-wonder":
            return ["The Dusk Thorn"]
        default:
            return []
        }
    }

    /// A custom cast member's attached photo for the Cast page, if present.
    private func portraitCustomAsset(for name: String) -> BookPageMediaAsset? {
        guard surface.payload.metadata["illustrationKind"] == "cast",
              surface.payload.metadata["entityName"] == name,
              let kindRaw = surface.payload.metadata["imageAssetKind"],
              let kind = BookPageMediaAsset.Kind(rawValue: kindRaw),
              let reference = surface.payload.metadata["imageAssetReference"]?.nonEmpty else {
            return nil
        }
        return BookPageMediaAsset(kind: kind, reference: reference, caption: name, sourceID: surface.sourceID, metadata: [:])
    }

    private var noteSenderCustomAsset: BookPageMediaAsset? {
        guard surface.type == .note,
              let kindRaw = surface.payload.metadata["imageAssetKind"],
              let kind = BookPageMediaAsset.Kind(rawValue: kindRaw),
              let reference = surface.payload.metadata["imageAssetReference"]?.nonEmpty else {
            return nil
        }
        return BookPageMediaAsset(kind: kind, reference: reference, caption: letterSenderName, sourceID: surface.sourceID, metadata: [:])
    }

    @ViewBuilder
    private var characterPortraitHeader: some View {
        let names = portraitNames
        if !names.isEmpty {
            HStack(spacing: 14) {
                ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                    VStack(spacing: 5) {
                        CharacterPortraitView(name: name, size: names.count > 2 ? 44 : 56, customAsset: portraitCustomAsset(for: name))
                        Text(name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(openPageSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: 92)
                }
            }
        }
    }

    /// True when the surfaced page is a Shadow Wonder variant of an ordinary page
    /// type: set by the source adapters once the Dusk Thorn is invested in and the
    /// world turns toward the worn edge (night, Duskthorn ascendant, hard/grey day,
    /// or somber weather).
    private var isShadowWonderVariant: Bool {
        surface.payload.metadata["variant"] == "shadow-wonder"
    }

    /// A quiet Duskthorn-toned badge so a Shadow Wonder page reads as distinct from
    /// its bright sibling rather than looking like an ordinary souvenir or quip.
    private var shadowWonderBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "theatermasks.fill")
                .font(.caption.weight(.bold))
            VStack(alignment: .leading, spacing: 1) {
                Text("THE DUSK THORN TURNED THIS PAGE")
                    .font(.caption2.weight(.black))
                    .tracking(1.2)
                Text("It wants the worn side of the day without calling the dark a verdict.")
                    .font(.caption2)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(BookPalette.violet)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.violet.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Dusk Thorn turned this Page toward Shadow Wonder")
    }

    private var journalAuthorName: String {
        surface.payload.metadata["journalAuthorName"]?.nonEmpty ?? "The Book"
    }

    /// The small caption above the writing box. It names the job this
    /// particular Page is asking for, rather than calling everything a margin
    /// note. See `BookPageType.marginAsk`.
    private var pageResponseTitle: String {
        if let authored = surface.payload.metadata["responseLabel"]?.nonEmpty {
            return authored
        }
        if surface.type == .diary, surface.payload.metadata["journalAuthorID"] == "penny-blackletter" {
            return "Penny's case file"
        }
        return surface.type.marginAsk.label
    }

    /// A Page that knows its own dare, feast, or question writes a sharper
    /// invitation than the type-level one, so its `placeholder` wins. That
    /// metadata used to be read on journal Pages only, which quietly threw
    /// away the invitation on Dares, Feasts, Glow, Word Negotiations, and
    /// every Compass step.
    private var pageResponsePlaceholder: String {
        surface.payload.metadata["placeholder"]?.nonEmpty ?? surface.type.marginAsk.placeholder
    }

    private var journalAuthorLead: String? {
        if let lead = surface.payload.metadata["journalAuthorLead"]?.nonEmpty {
            return lead
        }
        let firstParagraph = surface.payload.body
            .components(separatedBy: "\n\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return firstParagraph?.nonEmpty == surface.prompt.nonEmpty ? nil : firstParagraph?.nonEmpty
    }

    @ViewBuilder
    private var journalPageOpening: some View {
        let authorID = surface.payload.metadata["journalAuthorID"]?.nonEmpty ?? "the-book"
        let authorLead = journalAuthorLead
        let invitation = surface.payload.metadata["journalResponseInvitation"]?.nonEmpty
            ?? (authorID == "penny-blackletter"
                ? "Don't work up a conclusion. One honest scrap of evidence in the box below is plenty — Penny brought a very small folder."
                : "Write your answer in the box below. One sentence is enough, and I'm not grading it.")

        VStack(alignment: .leading, spacing: 12) {
            Text(surface.payload.headline)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(openPagePrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(authorID == "the-book"
                ? "I picked one question out of your day. Nobody sees your answer but me."
                : "A private question, left for you by \(journalAuthorName).")
                .font(.callout.weight(.semibold))
                .foregroundStyle(openPageSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let authorLead {
                Text(authorLead)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(authorID == "penny-blackletter" ? "PENNY'S QUESTION" : "THE QUESTION")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(BookPalette.teal)

                Text(surface.prompt)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(openPagePrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(invitation)
                    .font(.callout)
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
            }
        }
    }

    private var pageSheetContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(pageSheetTitle, systemImage: pageSheetSymbolName)
                .font(.headline)
                .foregroundStyle(openPagePrimaryText)

            if isShadowWonderVariant {
                shadowWonderBadge
            }

            characterPortraitHeader

            if surface.type == .diary {
                journalPageOpening
            } else {
                Text(surface.prompt)
                    .font(.system(
                        surface.payload.metadata["bookCharacterCadence"] == "small-hand" ? .title3 :
                            (surface.payload.metadata["bookCharacterCadence"] == "spilling-over" ? .largeTitle : .title),
                        design: .serif,
                        weight: .semibold
                    ))
                    .foregroundStyle(openPagePrimaryText)
                    .shadow(color: BookPalette.lampGold.opacity(0.14), radius: 6, x: 0, y: 2)
                    .fixedSize(horizontal: false, vertical: true)

                if !isStandalonePlayfulMissionPage {
                    Text(surface.detail)
                        .font(.body)
                        .foregroundStyle(openPageSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actedMargin = surface.payload.metadata["bookActedMargin"]?.nonEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label(
                        surface.payload.metadata["bookActedMarginTitle"]?.nonEmpty ?? "I interfered",
                        systemImage: bookInterjectionMarginSymbol
                    )
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    if surface.payload.metadata["bookInterjectionPhysicalAct"] == "underline",
                       let excerpt = surface.payload.metadata["bookInterjectionTargetExcerpt"]?.nonEmpty {
                        Text("“\(excerpt)”")
                            .font(.system(.body, design: .serif, weight: .semibold))
                            .underline(true, color: BookPalette.lampGold.opacity(0.92))
                            .accessibilityLabel("The Book underlined: \(excerpt)")
                    }
                    Text(actedMargin)
                        .font(.system(
                            surface.payload.metadata["bookInterjectionPhysicalAct"] == "sprawling-hand" ? .title3 :
                                (surface.payload.metadata["bookInterjectionPhysicalAct"] == "tiny-hand" ? .callout : .body),
                            design: .serif
                        ).italic())
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if surface.payload.metadata["bookInterjectionID"]?.nonEmpty != nil {
                        if didAnswerBookInterjection {
                            Text(bookInterjectionResponseMessage)
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(BookPalette.ink.opacity(0.78))
                                .padding(.top, 3)
                        } else {
                            HStack(spacing: 7) {
                                ForEach(BookInterjectionResponse.allCases, id: \.rawValue) { response in
                                    Button(response.label) {
                                        bookInterjectionResponseMessage = onBookInterjectionResponse(surface, response, Date())
                                        didAnswerBookInterjection = true
                                        BookFeedback.play(response == .wrong ? .sourceRefresh : .openPage)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(response == .wrong ? BookPalette.teal : BookPalette.lampGold)
                                }
                            }
                            .padding(.top, 3)
                        }
                    }
                }
                .foregroundStyle(BookPalette.lampGold)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.lampGold.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(BookPalette.lampGold.opacity(0.72))
                        .frame(width: 2)
                        .padding(.vertical, 6)
                }
                .accessibilityElement(children: surface.payload.metadata["bookInterjectionID"] == nil ? .combine : .contain)
            }

            if isMoonwriteSouvenirPage {
                moonwriteGlowNote
            }

            if surface.type != .note && surface.type != .tarot {
                pageShareControl
            }

            if isExternalSparkReadbackPage {
                externalSparkPanel
            }

            if isLocalBrainWorking, sheetHasLocalBrainActions, localPageOwnedScribeLabel == nil {
                scribeWorkCard(pageOwnedScribeLabel ?? localBrainWorkLabel)
            }

            if let story = surface.payload.metadata["pactShelfStory"]?.nonEmpty {
                pactFramingCard(
                    story,
                    title: surface.payload.metadata["pactShelfTalisman"].map { "\($0) is moving here" } ?? "A Talisman is moving here",
                    subtitle: nil
                )
            }

            if let framing = surface.payload.metadata["pactFraming"]?.nonEmpty {
                pactFramingCard(
                    framing,
                    title: surface.payload.metadata["pactTalisman"].map { "\($0) frames this page" } ?? "This shelf frames this page",
                    subtitle: nil
                )
            }

            if let epigraph = surface.payload.metadata["pactDoorEpigraph"]?.nonEmpty {
                pactFramingCard(
                    epigraph,
                    title: surface.payload.metadata["pactDoorTalisman"].map { "\($0) holds this door" } ?? "This door is held",
                    subtitle: "A threshold between worlds"
                )
            }

            if (isPreparedPage && !isChapterPrimerPage && !isBookJumpPage) || isCompassPracticePage {
                AnyView(preparedPageContent)
            }

            if surface.type == .academyClass {
                AnyView(academyCalendarControl)
            }

            if isKeptReadbackPage,
               let note = GoblinMarginalia.note(
                forID: surface.payload.metadata["keptPageID"] ?? surface.id,
                text: surface.payload.body
               ) {
                faeMarginaliaCard(note)
            }

            if isKeptReadbackPage,
               let voicePath = surface.payload.metadata["keptVoicePath"]?.nonEmpty,
               FileManager.default.fileExists(atPath: voicePath) {
                KeptVoicePlaybackChip(filePath: voicePath)
            }

            if isScrapbookReadbackPage {
                scrapbookReadbackPlate
            }

            if let ask = taleAsk {
                taleAskCard(ask)
            }

            if canGiveBraidFeedback {
                braidFeedbackCard
            }

            if !compassGenerationMessage.isEmpty {
                Text(compassGenerationMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !playfulMissionGenerationMessage.isEmpty {
                Text(playfulMissionGenerationMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if surface.type == .mood {
                AnyView(moodOptions)
            }

            if surface.type == .aboutYou, !aboutYouExampleLines.isEmpty {
                AnyView(aboutYouExampleLineOptions)
            }

            if surface.type == .affirmations, !affirmationCountersigns.isEmpty {
                AnyView(affirmationCountersignOptions)
            }

            if festivalMechanic != nil {
                AnyView(festivalMechanicCard)
            }

            if festivalCanBeRested {
                AnyView(festivalRestRow)
            }

            if isAnchorOfferPage {
                AnchorOfferFormView(surface: surface, onAnchorPlace: onAnchorPlace)
            }

            if isElectiveFlyleafPage {
                ElectiveFlyleafListView(
                    ledger: flyleafLedger,
                    onCompleteElective: onCompleteElective,
                    onReleaseElective: onReleaseElective,
                    onOpenDoor: onOpenFlyleafDoor
                )
            }

            if isChapterBindingPage {
                ChapterBindingFormView(surface: surface, onBindChapter: onBindChapter)
            }

            if isChapterPrimerPage {
                chapterPrimerView
            }

            if let externalURL {
                externalPageLink(externalURL)
            }

            if !articlePreviews.isEmpty || !articleLinks.isEmpty {
                articleLinkList
            }

            if surface.type == .askTheBook {
                AnyView(askTheBookView)
            }

            if surface.type == .inkrestOfficeHours {
                AnyView(inkrestOfficeHoursView)
            }

            if surface.type == .faeBargain {
                AnyView(faeBargainView)
            }

            if surface.payload.metadata["greyThreat"] == "true" {
                AnyView(greyPageThreatView)
            }

            if surface.type == .festival {
                AnyView(festivalView)
            }

            if surface.type == .todaysSky {
                AnyView(todaysSkyView)
            }

            if isBookJumpPage {
                AnyView(bookJumpView)
            }

            if surface.type == .twoReadings {
                AnyView(twoReadingsView)
            }

            if isStandalonePlayfulMissionPage {
                AnyView(playfulMissionGeneratorControl)
            }

            if isEnchantmentPage {
                AnyView(enchantmentPageView)
            }

            #if canImport(UIKit)
            if surface.type == .illuminatedPhoto, !shouldShowCameraCapturePage, let result = enchantmentResult {
                enchantmentResultCard(result)

                if activeEnchantmentSpell?.id == "everything-speaks" {
                    AnyView(everythingSpeaksConversationView)
                }
            }
            #else
            if surface.type == .illuminatedPhoto, let result = enchantmentResult {
                enchantmentResultCard(result)

                if activeEnchantmentSpell?.id == "everything-speaks" {
                    AnyView(everythingSpeaksConversationView)
                }
            }
            #endif

            if surface.type == .marginsAtlas {
                marginsAtlasView
            }

            if surface.type == .calendar {
                hourPageView
            }

            if surface.type == .gamePage {
                gamePageView
            }

            if surface.type == .tarot {
                TarotPageView(
                    reading: $tarotReading,
                    isReadOnly: isKeptReadbackPage,
                    localBrainIsReady: localBrainIsReady,
                    isLocalBrainWorking: isLocalBrainWorking,
                    onRequestSerenityReading: onRequestTarotReading
                )
            }

            if surface.type == .diary,
               surface.payload.metadata["journalDeeperQuestion"]?.nonEmpty != nil {
                journalDeeperQuestionControl
            }

            if showsGenericMarginNoteEditor {
                marginNoteEditor(
                    minHeight: isPreparedPage ? 92 : (surface.type == .souvenir ? 120 : 150)
                )
            } else if isBookJumpActivePage {
                // Every open beat can carry a line: a souvenir to bring home, or
                // a real detail to steady the page, so the fork controls have it.
                marginNoteEditor(minHeight: 118)
            } else if surface.isStoryPlayablePage && !isLocalBrainIssuePage {
                storyMarginNoteField
            }

            if publicMarginsOutgoingOptIn,
               surface.privacy != .publicReference,
               surface.type != .note,
               surface.type != .tarot {
                publicMarginsExportControl
            }
        }
    }

    private var bookInterjectionMarginSymbol: String {
        switch surface.payload.metadata["bookInterjectionPhysicalAct"] {
        case "dog-ear": return "bookmark.fill"
        case "underline": return "underline"
        case "smudge": return "fingerprint"
        case "left-open": return "book.pages"
        case "sprawling-hand": return "pencil.line"
        case "tiny-hand": return "pencil.tip"
        default: return "pencil.and.scribble"
        }
    }

    @ViewBuilder
    private var scrapbookReadbackPlate: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Scrapbook Page", systemImage: "photo.artframe")
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.teal)

            #if canImport(UIKit)
            if let url = scrapbookImagePreviewURL,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                    }
                    .accessibilityLabel("Kept scrapbook page image")
                    .imagePreviewOnTap { url }
            }
            #endif

            HStack(spacing: 8) {
                if let imageURL = scrapbookImagePreviewURL {
                    Label("Open image", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(BookPalette.teal.opacity(0.12), in: Capsule())
                        .imagePreviewOnTap { imageURL }
                }

                if let pdfURL = scrapbookPDFPreviewURL {
                    Label("Open PDF", systemImage: "doc.richtext")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.lampGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(BookPalette.lampGold.opacity(0.12), in: Capsule())
                        .imagePreviewOnTap { pdfURL }
                }
            }

            if let caption = surface.payload.metadata["imageCaption"]?.nonEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note = scrapbookNoteText {
                Text(note)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(openPageSecondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private var gamePhrases: [String] {
        splitMetadataList(surface.payload.metadata["gamePhrases"])
    }

    private var gameNothingPhrases: [String] {
        splitMetadataList(surface.payload.metadata["nothingPhrases"])
    }

    private var gameRunShape: SentenceRunnerRunShape {
        SentenceRunnerRunShape(rawValue: surface.payload.metadata["runnerShape"] ?? "") ?? .lowRoad
    }

    /// The player chooses a real phrase to carry into the run. A recently
    /// restored phrase joins the choices so Routine can never have the last word.
    private var runnerThreadChoices: [String] {
        var choices = Array(gamePhrases.prefix(3))
        if let returnPhrase = runnerReturnPhrase.nonEmpty,
           !choices.contains(where: { $0.caseInsensitiveCompare(returnPhrase) == .orderedSame }) {
            choices.insert(returnPhrase, at: 0)
        }
        return Array(choices.prefix(3))
    }

    private var activeRunnerThread: String {
        if runnerThreadChoices.contains(chosenRunnerThread) { return chosenRunnerThread }
        return runnerThreadChoices.first ?? gamePhrases.first ?? ""
    }

    private var runnerPhrasesForNextRun: [String] {
        var phrases = gamePhrases
        if let returnPhrase = runnerReturnPhrase.nonEmpty,
           !phrases.contains(where: { $0.caseInsensitiveCompare(returnPhrase) == .orderedSame }) {
            phrases.insert(returnPhrase, at: 0)
        }
        return phrases
    }

    /// A Folio is deliberately made of saved runs, not a streak. Closing the
    /// app costs nothing; three kept runner pages still bind when they happen.
    private var sentenceRunnerFolioProgress: Int {
        inventoryKeptPages.filter { page in
            page.tags.contains("sentence-runner") && page.tags.contains("loom-run")
        }.count % SentenceRunnerFolio.runsToBind
    }

    private var sentenceRunnerFolioRunNumber: Int {
        min(SentenceRunnerFolio.runsToBind, sentenceRunnerFolioProgress + sessionRunnerFolioRuns + 1)
    }

    /// Maps each archive phrase to the exact kept page it came from, parsed from the
    /// adapter's "phrase¶pageID¶timestamp¶label||..." sidecar, so rescued grey words
    /// can cite, and open: their source page, dated.
    private var gamePhraseSources: [String: SentenceRunnerPhraseSource] {
        var map: [String: SentenceRunnerPhraseSource] = [:]
        for entry in splitMetadataList(surface.payload.metadata["phraseSources"]) {
            let parts = entry.components(separatedBy: "¶")
            guard parts.count == 4, let timestamp = Double(parts[2]) else { continue }
            let phrase = parts[0]
            map[phrase] = SentenceRunnerPhraseSource(
                phrase: phrase,
                pageID: parts[1],
                date: Date(timeIntervalSince1970: timestamp),
                label: parts[3]
            )
        }
        return map
    }

    /// The structured restored grey words for the most recent run (drives the
    /// interactive result UI; empty when no run is loaded).
    private var gameRescueItems: [SentenceRunnerRescueItem] {
        guard let result = lastGameResult else { return [] }
        return SentenceRunnerRescue.items(grey: result.nothingHits, archive: gamePhrases, provenance: gamePhraseSources)
    }

    /// The result body with the plain-text restored block stripped, so the live
    /// panel can render the rescues interactively instead.
    private var gameResultProseText: String {
        guard let body = gameResultSurface?.payload.body else { return "" }
        return (body.components(separatedBy: "\n\nThe Book restored:").first ?? body)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitMetadataList(_ value: String?) -> [String] {
        (value ?? "")
            .components(separatedBy: "||")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var gamePageView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let resultSurface = gameResultSurface {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Run Complete", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(BookPalette.teal)
                    Text(gameResultProseText)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(openPageSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !gameRescueItems.isEmpty {
                        gameRescueSection
                    }

                    if let result = lastGameResult {
                        gameFolioReceipt(result)
                    }

                    gameRunBraidControl

                    Button {
                        gameResultSurface = nil
                        lastGameResult = nil
                        gameRunBraided = false
                        gameBraidMessage = ""
                        BookFeedback.play(.openPage)
                    } label: {
                        Label(
                            runnerReturnPhrase.isEmpty ? "Run another thread" : "Carry the restored phrase onward",
                            systemImage: "arrow.right.circle.fill"
                        )
                        .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)

                    if let note = GoblinMarginalia.note(forID: resultSurface.id, text: resultSurface.payload.body) {
                        faeMarginaliaCard(note)
                    }
                }
                .padding(12)
                .background(BookPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                sentenceRunnerThreadPicker

                Button {
                    BookFeedback.play(.openPage)
                    isGamePagePresented = true
                } label: {
                    Label("Run the margin", systemImage: "figure.run")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(gamePhrases.count < 6)

                if gamePhrases.count < 6 {
                    Text("The Loom needs a small handful of usable phrases from kept pages before this game can open.")
                        .font(.caption)
                        .foregroundStyle(openPageSecondaryText)
                }
            }

            phrasePreview(title: "Archive words in motion", phrases: Array(gamePhrases.prefix(6)), tint: BookPalette.teal)
            phrasePreview(title: "Nothing words to avoid", phrases: Array(gameNothingPhrases.prefix(6)), tint: openPageSecondaryText)
        }
    }

    private func gameFolioReceipt(_ result: SentenceRunnerResult) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(
                SentenceRunnerFolio.title(completing: result.folioRunCount),
                systemImage: result.folioRunCount >= SentenceRunnerFolio.runsToBind ? "books.vertical.fill" : "book.pages"
            )
            .font(.caption.weight(.black))
            .foregroundStyle(result.folioRunCount >= SentenceRunnerFolio.runsToBind ? BookPalette.lampGold : BookPalette.teal)
            if result.targetCaught {
                Text("You carried “\(result.chosenThread)” across the margin.")
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText)
            }
            if !result.lockedLines.isEmpty {
                Text(result.lockedLines.count == 1
                     ? "A sentence-line held before the run ended."
                     : "Several sentence-lines held before the run ended.")
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText)
            }
            if result.folioRunCount >= SentenceRunnerFolio.runsToBind {
                Text("Keep this and I can sew the Folio into your archive.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.lampGold)
            }
        }
        .padding(10)
        .background(BookPalette.lampGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var sentenceRunnerThreadPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Choose a thread to carry", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.teal)
                Spacer()
                Text("\(sentenceRunnerFolioRunNumber) caught · \(max(0, SentenceRunnerFolio.runsToBind - sentenceRunnerFolioRunNumber)) still loose")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(openPageSecondaryText.opacity(0.72))
            }
            Text(gameRunShape.title + " · " + gameRunShape.invitation)
                .font(.caption)
                .foregroundStyle(openPageSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(runnerThreadChoices, id: \.self) { phrase in
                Button {
                    chosenRunnerThread = phrase
                    BookFeedback.play(.tap)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: activeRunnerThread == phrase ? "checkmark.circle.fill" : "circle")
                        Text("“\(phrase)”")
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(activeRunnerThread == phrase ? BookPalette.lampGold : openPageSecondaryText)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BookPalette.teal.opacity(activeRunnerThread == phrase ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var gameRescueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("I restored", systemImage: "wand.and.stars.inverse")
                .font(.caption2.weight(.black))
                .foregroundStyle(BookPalette.lampGold)

            ForEach(gameRescueItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    (
                        Text(item.grey).strikethrough().foregroundColor(openPageSecondaryText.opacity(0.65))
                        + Text("  →  ").foregroundColor(openPageSecondaryText.opacity(0.45))
                        + Text(item.restored).foregroundColor(BookPalette.lampGold)
                    )
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                    if let source = item.source {
                        Button {
                            BookFeedback.play(.openPage)
                            inspectedPhraseSource = source
                        } label: {
                            Label(
                                "from your \(source.label) · \(SentenceRunnerRescue.dateFormatter.string(from: source.date))",
                                systemImage: "doc.text.magnifyingglass"
                            )
                            .font(.caption2.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .tint(BookPalette.teal)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.lampGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func phraseSourceModal(_ source: SentenceRunnerPhraseSource) -> some View {
        let page = inventoryKeptPages.first { $0.id == source.pageID }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("THE WORD CAME FROM")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BookPalette.teal)
                        Text("\(source.label) · \(SentenceRunnerRescue.dateFormatter.string(from: source.date))")
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(BookPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("\u{201C}\(source.phrase)\u{201D}")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.lampGold)
                        .fixedSize(horizontal: false, vertical: true)

                    if let page {
                        if !page.promptText.isEmpty {
                            phraseSourceField("The page asked", page.promptText)
                        }
                        if let readerText = page.readerAuthoredTextForAnalysis {
                            phraseSourceField("What you wrote", readerText)
                        }
                        if let bookText = page.bookAuthoredText {
                            phraseSourceField("What I wrote around it", bookText)
                        }
                    } else {
                        Text("This page has since left the archive, but the Loom still remembers the words it loosened.")
                            .font(.callout)
                            .foregroundStyle(BookPalette.ink.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(BookPalette.page.ignoresSafeArea())
            .navigationTitle("Source Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { inspectedPhraseSource = nil }
                        .tint(BookPalette.lampGold)
                }
            }
        }
    }

    private func phraseSourceField(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.55))
            Text(body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var gameRunBraidControl: some View {
        if let result = lastGameResult, !result.caught.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if gameRunBraided {
                    Label("Braided by the Scribe", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.lampGold)
                } else {
                    Button {
                        Task { await braidGameRun() }
                    } label: {
                        Label("Let the Scribe braid this run", systemImage: "wand.and.stars")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.lampGold)
                    .disabled(isBraidingGameRun || isLocalBrainWorking)
                }

                if isBraidingGameRun {
                    scribeWorkCard(
                        "sentence-runner-braid",
                        quip: "The Scribe is re-enchanting the grey and braiding your caught words."
                    )
                }

                if !gameBraidMessage.isEmpty {
                    Text(gameBraidMessage)
                        .font(.caption2)
                        .foregroundStyle(openPageSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
    }

    private func braidGameRun() async {
        guard let result = lastGameResult, !isBraidingGameRun, !gameRunBraided else { return }
        isBraidingGameRun = true
        gameBraidMessage = "The Scribe is reading the run."
        let context = SentenceRunnerProseContext(
            caught: result.caught,
            nothingHits: result.nothingHits,
            outcomeTitle: result.outcome.title,
            form: SentenceRunnerPoem.form(caught: result.caught, nothingHits: result.nothingHits).rawValue,
            deterministic: result.keepText,
            archiveSamples: Array(gamePhrases.prefix(8)),
            rescues: SentenceRunnerRescue.lines(gameRescueItems)
        )
        do {
            let prose: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXSentenceRunnerProseWriter().write(context: context)
            #else
            prose = try await FakeSentenceRunnerProseWriter().write(context: context)
            #endif
            gameResultSurface = gameResultPage(from: result, braided: prose)
            text = prose
            gameRunBraided = true
            gameBraidMessage = ""
            BookFeedback.play(.braidComplete)
        } catch {
            gameBraidMessage = "The Scribe could not braid this run: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
        isBraidingGameRun = false
    }

    private func phrasePreview(title: String, phrases: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(tint)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(phrases, id: \.self) { phrase in
                    Text(phrase)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(openPageSecondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func gameResultPage(from result: SentenceRunnerResult, braided: String? = nil) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .gamePage)
        let form = SentenceRunnerPoem.form(caught: result.caught, nothingHits: result.nothingHits)
        let poem = braided ?? SentenceRunnerPoem.compose(caught: result.caught, nothingHits: result.nothingHits)
        let rescueItems = SentenceRunnerRescue.items(grey: result.nothingHits, archive: gamePhrases, provenance: gamePhraseSources)
        let rescues = SentenceRunnerRescue.lines(rescueItems)
        let restoredBlock = rescues.isEmpty ? nil : (["I restored:"] + rescues).joined(separator: "\n")
        var tags = ["game-page", "sentence-runner", "loom-run", "outcome:\(result.outcome.rawValue)", "prose-form:\(form.rawValue)"]
        tags.append(braided == nil ? "prose:deterministic" : "prose:gemma")
        tags += result.caught.prefix(6).map { "caught:\($0.slugTag)" }
        tags += result.nothingHits.prefix(4).map { "nothing-hit:\($0.slugTag)" }
        if !result.chosenThread.isEmpty { tags.append("carried:\(result.chosenThread.slugTag)") }
        if result.targetCaught { tags.append("carried-thread-caught") }
        if !result.lockedLines.isEmpty { tags.append("sentence-line-locked") }
        tags.append("runner-shape:\(result.runShape.rawValue)")
        tags.append("loom-folio:\(result.folioRunCount)")
        if result.folioRunCount >= SentenceRunnerFolio.runsToBind { tags.append("loom-folio-complete") }
        if !result.nothingHits.isEmpty { tags.append("nothing-influenced") }
        if !rescues.isEmpty { tags.append("grey-rescued") }
        return SurfacePage(
            id: "\(surface.id)-result-\(Int(Date().timeIntervalSince1970))",
            type: .gamePage,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: result.folioRunCount >= SentenceRunnerFolio.runsToBind ? 82 : 72,
            reason: result.folioRunCount >= SentenceRunnerFolio.runsToBind
                ? "Three kept runs have gathered enough thread for a Loom Folio."
                : "A Game Page run made a keepable result.",
            prompt: "The Sentence Runner Result",
            detail: result.outcome.title,
            payload: BookPagePayload(
                headline: result.folioRunCount >= SentenceRunnerFolio.runsToBind
                    ? "The Loom bound a small folio."
                    : result.outcome.headline,
                body: [
                    result.outcome.summary,
                    result.chosenThread.isEmpty ? nil : "You chose to carry “\(result.chosenThread)”. \(result.targetCaught ? "It crossed with you." : "The run kept looking for it.")",
                    result.lockedLines.isEmpty ? nil : "Locked line\(result.lockedLines.count == 1 ? "" : "s"): \(result.lockedLines.map { "“\($0)”" }.joined(separator: " / "))",
                    SentenceRunnerFolio.title(completing: result.folioRunCount),
                    poem,
                    restoredBlock
                ].compactMap { $0 }.joined(separator: "\n\n"),
                metadata: [
                    "source": source.id,
                    "gameID": "sentence-runner",
                    "gameOutcome": result.outcome.rawValue,
                    "proseForm": form.rawValue,
                    "proseSource": braided == nil ? "deterministic" : "gemma",
                    "proseRescued": rescues.isEmpty ? "false" : "true",
                    "caughtWords": result.caught.joined(separator: "||"),
                    "nothingHits": result.nothingHits.joined(separator: "||"),
                    "chosenThread": result.chosenThread,
                    "targetCaught": result.targetCaught ? "true" : "false",
                    "lockedLines": result.lockedLines.joined(separator: "||"),
                    "runnerShape": result.runShape.rawValue,
                    "loomFolioRun": "\(result.folioRunCount)",
                    "loomFolioComplete": result.folioRunCount >= SentenceRunnerFolio.runsToBind ? "true" : "false",
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }

    private var chapterPrimerView: some View {
        let metadata = surface.payload.metadata
        let chapter = AcademyChapterRegistry.chapter(id: metadata["chapterID"] ?? "")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: chapter?.symbolName ?? "book.closed")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 34, height: 34)
                    .background(BookPalette.lampGold.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(metadata["privacy"]?.uppercased() ?? "PUBLIC REFERENCE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(BookPalette.teal)
                    Text(surface.payload.headline)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let chapter {
                VStack(alignment: .leading, spacing: 6) {
                    Label(chapter.name, systemImage: chapter.symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.lampGold)
                    Text(chapter.philosophy)
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.lampGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
                }
            }
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }

    private var hourPageView: some View {
        let metadata = surface.payload.metadata
        let phase = metadata["hourPhase"] ?? "before"
        let question = metadata["hourQuestion"] ?? "What does this hour mean for you?"
        let support = metadata["hourSupportTip"] ?? "Take one breath before the next door opens."
        let placeholder = metadata["placeholder"] ?? (phase == "after"
            ? "One sentence about how it actually went."
            : "What you want from this hour, or what you're dreading about it.")
        let eventTitle = metadata["eventTitle"] ?? surface.detail
        let eventTime = metadata["eventTime"] ?? ""

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(metadata["hourPhaseTitle"] ?? (phase == "after" ? "After the Hour" : "Before the Hour"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
                Text(eventTitle)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !eventTime.isEmpty {
                    Label(eventTime, systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                }
                Text(surface.payload.body)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
            }

            hourPageCallout(
                title: phase == "after" ? "I'm asking" : "Before you go",
                symbol: phase == "after" ? "quote.opening" : "sparkle.magnifyingglass",
                body: question,
                tint: BookPalette.lampGold
            )

            hourPageCallout(
                title: "Small support spell",
                symbol: "hands.sparkles",
                body: support,
                tint: BookPalette.teal
            )

            LivingTextEditor(
                title: phase == "after" ? "How it went" : "Before you go in",
                placeholder: placeholder,
                text: $text,
                minHeight: 92,
                builderPack: phase == "after"
                    ? SentenceBuilderPackRegistry.composedSouvenir(readerLexicon: readerLexicon, shadowWonderActive: isShadowWonderActive)
                    : SentenceBuilderPackRegistry.composedCore(readerLexicon: readerLexicon, shadowWonderActive: isShadowWonderActive),
                builderContext: makeSentenceBuilderContext(
                    intent: phase == "after" ? .souvenir : .marginNote,
                    prompt: question,
                    sourceText: [eventTitle, surface.payload.body, support].joined(separator: " ")
                )
            )
        }
    }

    private func hourPageCallout(title: String, symbol: String, body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(body)
                .font(.callout.weight(.semibold))
                .foregroundStyle(calloutBodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
    }

    private var atlasGraph: NarrativeGraphData {
        NarrativeGraphData(
            nodes: AtlasGraphMetadataCodec.decodeNodes(surface.payload.metadata["graphNodes"] ?? ""),
            edges: AtlasGraphMetadataCodec.decodeEdges(surface.payload.metadata["graphEdges"] ?? "")
        )
    }

    private var atlasVariant: MarginsAtlasVariant {
        MarginsAtlasVariant(rawValue: surface.payload.metadata["graphVariant"] ?? "") ?? .loom
    }

    private var marginsAtlasView: some View {
        let graph = atlasGraph
        return VStack(alignment: .leading, spacing: 12) {
            MarginsAtlasGraphView(
                variant: atlasVariant,
                graph: graph,
                selectedNodeID: $selectedAtlasNodeID
            )
            .frame(height: 390)
            .background(BookPalette.nightPanel.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    BookFeedback.play(.select)
                    isAtlasFullScreenPresented = true
                } label: {
                    Label("Open full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BookPalette.nightText)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(BookPalette.lampGold.opacity(0.32), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(10)
                .accessibilityLabel("Open \(atlasVariant.title) full screen")
            }

            if let selectedNode = graph.nodes.first(where: { $0.id == selectedAtlasNodeID }) {
                MarginsAtlasNodeCard(node: selectedNode, graph: graph, variant: atlasVariant)
            } else {
                Text(graph.nodes.isEmpty ? "No lines yet. Keep Pages or name people, and I will draw a line when two things are actually connected." : "Tap a name to see its lines. Pinch to zoom. Drag to move around the map.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pactFramingCard(_ framing: String, title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(title, systemImage: "seal")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold.opacity(0.9))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.45))
                }
            }
            Text(framing)
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(openPageSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.lampGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private func faeMarginaliaCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tag")
                .font(.caption)
                .foregroundStyle(BookPalette.teal.opacity(0.8))
            Text(note)
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(openPageSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.2), lineWidth: 1)
        }
    }

    private var localBrainIssueBody: some View {
        Text(surface.payload.body)
            .font(.system(.body, design: .serif))
            .foregroundStyle(BookPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var isWelcomeIntroductionPage: Bool {
        surface.payload.metadata["welcomePage"] == "true"
    }

    private var welcomeIntroductionParagraphs: [String] {
        surface.payload.body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private var welcomeIntroductionBody: some View {
        let paragraphs = welcomeIntroductionParagraphs
        if paragraphs.count >= 14 {
            VStack(alignment: .leading, spacing: 16) {
                Text(paragraphs[0])
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink)

                VStack(alignment: .leading, spacing: 13) {
                    Text(paragraphs[1])
                    Text(paragraphs[2])
                }
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))

                Text(paragraphs[3])
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.gold)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 13) {
                    Text(paragraphs[4])
                    Text(paragraphs[5])
                        .fontWeight(.semibold)
                }
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .lineSpacing(3)

                VStack(alignment: .leading, spacing: 12) {
                    Text(paragraphs[6])
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(BookPalette.gold)

                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: "brain.head.profile")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(BookPalette.teal)
                            .accessibilityHidden(true)
                        Text(paragraphs[7])
                            .font(.system(.title2, design: .serif).weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                    }

                    Text(paragraphs[8])
                    Text(paragraphs[9])
                }
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .lineSpacing(3)
                .padding(14)
                .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(paragraphs[10])
                        .foregroundStyle(BookPalette.ink.opacity(0.70))
                    Text(paragraphs[11])
                        .fontWeight(.bold)
                        .foregroundStyle(BookPalette.ink)
                }
                .font(.system(.title3, design: .serif))
                .italic()
                .padding(.leading, 13)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(BookPalette.lampGold.opacity(0.78))
                        .frame(width: 3)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(paragraphs[12])
                        .font(.system(.title3, design: .serif).weight(.semibold))
                    Text(paragraphs[13])
                        .font(.system(.title2, design: .serif).weight(.bold))
                }
                .foregroundStyle(BookPalette.ink)
                .padding(.top, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// True on pages that talk about the private local mind while it isn't yet
    /// installed: the first Welcome, the recovery install rider, and any
    /// local-brain issue page. These get an inline download button so the reader
    /// never has to hunt for the Colophon.
    private var showsLocalBrainInstallControl: Bool {
        guard !localBrainIsReady else { return false }
        if isLocalBrainIssuePage { return true }
        let tags = surface.payload.metadata["tags"] ?? ""
        return tags.contains("local-brain") || tags.contains("colophon")
    }

    @ViewBuilder
    private var localBrainInstallControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .overlay(BookPalette.ink.opacity(0.14))

            if isInstallingLocalBrain {
                if let localBrainInstallProgress {
                    ProgressView(value: localBrainInstallProgress)
                        .tint(BookPalette.teal)
                }
                Text(localBrainInstallMessage.nonEmpty ?? "Fetching the private mind…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(calloutBodyText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    BookFeedback.play(.openPage)
                    onInstallLocalBrain()
                } label: {
                    Label(
                        isWelcomeIntroductionPage
                            ? "Download Gemma · Wake My Brain"
                            : "Download the private mind",
                        systemImage: "brain.head.profile"
                    )
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.teal.opacity(0.36), lineWidth: 1)
                        }
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)

                if let message = localBrainInstallMessage.nonEmpty {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(calloutBodyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var bleedEditionText: String? {
        surface.payload.metadata["bleedProse"]?.nonEmpty ?? surface.payload.body.nonEmpty
    }

    private var bleedEditionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("TheBleedBanner")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.18), lineWidth: 1)
                }
                .accessibilityLabel("The Bleed pocket student newspaper")

            if !surface.mediaAssets.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("PLATES FROM THE FILE")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))

                    ForEach(surface.mediaAssets.prefix(2)) { asset in
                        HStack(alignment: .top, spacing: 10) {
                            BookOfYouMediaThumbnail(
                                asset: asset,
                                width: 126,
                                height: 96
                            )
                            Text(asset.caption.nonEmpty ?? "An image entered into the issue without a caption.")
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(BookPalette.ink.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(10)
                .background(
                    BookPalette.paper.opacity(0.48),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                }
            }

            if let bleedEditionText {
                Text(bleedEditionText)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The formes are locked, but the ink has not reached this copy yet.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let sources = surface.payload.metadata["bleedInterestSources"]?.nonEmpty {
                Text("I cut these clippings from: \(sources)")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .overlay(BookPalette.ink.opacity(0.14))

            if let bleedPDFURL {
                ShareLink(item: bleedPDFURL) {
                    Label("Share The Bleed PDF", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
                        }
                }
                .foregroundStyle(BookPalette.lampGold)
            } else {
                Button {
                    bindBleedPDF()
                } label: {
                    Label("Bind The Bleed as PDF", systemImage: "newspaper")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BookPalette.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.teal.opacity(0.36), lineWidth: 1)
                        }
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
                .disabled(bleedEditionText == nil)
            }

            if !bleedExportMessage.isEmpty {
                Text(bleedExportMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bindBleedPDF() {
        guard let body = bleedEditionText else {
            bleedExportMessage = "No edition has been printed yet."
            BookFeedback.play(.error)
            return
        }
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TheBleed-\(formatter.string(from: Date())).pdf")
            try BleedPDFWriter.write(
                headline: surface.payload.headline,
                body: body,
                mediaAssets: surface.mediaAssets,
                to: url
            )
            bleedPDFURL = url
            bleedExportMessage = "The Bleed is bound for sharing."
            BookFeedback.play(.braidComplete)
        } catch {
            bleedExportMessage = "The edition would not bind: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
    }

    @ViewBuilder
    private var askTheBookView: some View {
        if let openedAskEvidence {
            askEvidenceDetailView(openedAskEvidence)
        } else {
            askTheBookConversationView
        }
    }

    private var askTheBookConversationView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if askTurns.isEmpty, let opening = bookInitiativeOpening {
                VStack(alignment: .leading, spacing: 8) {
                    Label("THE BOOK SPOKE FIRST", systemImage: "bookmark.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(BookPalette.teal)
                    Text(opening)
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let invitation = surface.payload.metadata["bookInitiativeInvitation"]?.nonEmpty {
                        Text(invitation)
                            .font(.callout)
                            .foregroundStyle(openPageSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("The next bit of ink is yours, if there is one.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(openPageSecondaryText.opacity(0.82))
                }
                .padding(14)
                .background(BookPalette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
                }
            }

            if !askTurns.isEmpty {
                ForEach(Array(askTurns.enumerated()), id: \.element.id) { index, turn in
                    askTurnCard(
                        turn,
                        index: index,
                        evidence: askEvidenceByTurnID[turn.id] ?? [],
                        searchedRecordCount: askSearchCountByTurnID[turn.id] ?? 0
                    )
                }
            }

            if askTurns.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach((bookInitiativeSuggestedPrompts + [
                            "What are you thinking about?",
                            "What do you want from me?",
                            "Which Page is your favorite?",
                            "Tell me one of your secrets.",
                            "What have you changed your mind about?",
                            "What is your long-term goal?",
                            "What opinion do you hold?",
                            "What are your quirks?"
                        ]), id: \.self) { question in
                            Button(question) { askPrompt = question }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(BookPalette.teal)
                        }
                    }
                }
                .accessibilityLabel("Questions about my inner life")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(askTurns.isEmpty && bookInitiativeOpening != nil ? "Say something back, or don't" : (askTurns.isEmpty ? "What do you want to say?" : "Put another sentence between us"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(openPageSecondaryText)
                TextEditor(text: $askPrompt)
                    .font(.body)
                    .foregroundStyle(BookPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 116)
                    .inkFeedback(text: askPrompt)
                    .dictationInput(text: $askPrompt)
                    .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                    }
            }

            Button {
                Task { await askTheBook() }
            } label: {
                Label(isAskingTheBook ? "I'm replying" : (bookInitiativeOpening == nil ? "Come closer" : "Stay a little longer"), systemImage: isAskingTheBook ? "pencil.and.scribble" : "text.bubble")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.teal.opacity(0.36), lineWidth: 1)
                    }
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(BookPalette.teal)
            .disabled(isAskingTheBook || askPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLocalBrainWorking)

            if isAskingTheBook {
                scribeWorkCard("ask-the-book")
            }

            if !askTheBookMessage.isEmpty {
                Text(askTheBookMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bookInitiativeOpening: String? {
        guard surface.payload.metadata["bookInitiativeMode"] == BookInitiativeMode.conversation.rawValue,
              surface.payload.metadata["bookInitiativeGenerationPolicy"] == "user-initiated-only" else { return nil }
        return surface.payload.metadata["bookInitiativeOpening"]?.nonEmpty
    }

    private var bookInitiativeSuggestedPrompts: [String] {
        surface.payload.metadata["bookInitiativeSuggestedPrompts"]?
            .components(separatedBy: "||")
            .compactMap(\.nonEmpty) ?? []
    }

    private func askTurnCard(
        _ turn: AskTheBookTurn,
        index: Int,
        evidence: [AskTheBookEvidence] = [],
        searchedRecordCount: Int = 0
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(index == 0 ? "BETWEEN US" : "THE THREAD CONTINUED")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            Text(turn.prompt)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if searchedRecordCount > 0 {
                Label(
                    evidence.isEmpty
                        ? "I searched the permitted shelves. Nothing answered hard enough."
                        : "I opened the old leaves that answered.",
                    systemImage: "books.vertical"
                )
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.88))
            }
            Divider()
                .overlay(BookPalette.ink.opacity(0.16))
            Text(turn.answer)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !evidence.isEmpty {
                Divider()
                    .overlay(BookPalette.ink.opacity(0.12))
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(evidence) { item in
                            Button {
                                openedAskEvidence = item
                            } label: {
                                HStack(alignment: .top, spacing: 9) {
                                    Image(systemName: item.result.kind.symbolName)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.result.title)
                                            .font(.caption.weight(.bold))
                                        Text([
                                            item.authority.readerLabel,
                                            item.result.dateLabel
                                        ].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption2)
                                            .foregroundStyle(openPageSecondaryText)
                                        Text(item.result.snippet)
                                            .font(.caption)
                                            .foregroundStyle(BookPalette.ink.opacity(0.72))
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(openPageSecondaryText)
                                }
                                .multilineTextAlignment(.leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Label(
                        "The leaves I opened",
                        systemImage: "books.vertical"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
                }
            }
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
        .bookResultArrival(reduceMotion: reduceMotion)
    }

    private func askEvidenceDetailView(_ evidence: AskTheBookEvidence) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                openedAskEvidence = nil
            } label: {
                Label("Back to the conversation", systemImage: "chevron.left")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BookPalette.teal)

            Text(evidence.authority.readerLabel.uppercased())
                .font(.caption2.weight(.black))
                .tracking(1.1)
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            Text(evidence.result.title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(BookPalette.ink)
            if !evidence.result.dateLabel.isEmpty {
                Text(evidence.result.dateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
            }
            Divider()
                .overlay(BookPalette.ink.opacity(0.16))
            Text(evidence.fullText)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }

    private var festivalView: some View {
        let metadata = surface.payload.metadata
        let blurb = metadata["blurb"]?.nonEmpty ?? surface.payload.body
        let invitation = metadata["invitation"] ?? surface.detail
        return VStack(alignment: .leading, spacing: 14) {
            hourPageCallout(
                title: metadata["commonName"] ?? "A Festival of the Wheel",
                symbol: surface.type.symbolName,
                body: blurb,
                tint: BookPalette.lampGold
            )
            hourPageCallout(
                title: metadata["invitationTitle"] ?? "The invitation",
                symbol: "sparkles",
                body: invitation,
                tint: BookPalette.teal
            )
            Button {
                Task { await addFestivalToCalendar() }
            } label: {
                Label("Add this feast to my Calendar", systemImage: "calendar.badge.plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(BookPalette.teal)

            if !festivalMessage.isEmpty {
                Text(festivalMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addFestivalToCalendar() async {
        let metadata = surface.payload.metadata
        let title = metadata["academyTitle"] ?? "A Festival of the Wheel"
        let start = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        let ok = await EventKitWriter.addEvent(
            title: "\(title) (\(metadata["commonName"] ?? "the Wheel"))",
            notes: metadata["invitation"] ?? "",
            start: start,
            end: start.addingTimeInterval(3_600)
        )
        festivalMessage = ok
            ? "The feast is marked on your calendar."
            : "It could not be added (check Calendar permission in Settings)."
        BookFeedback.play(ok ? .select : .error)
    }

    private var todaysSkyView: some View {
        let m = surface.payload.metadata
        let pct = m["moonIllum"].flatMap { $0.nonEmpty }
        let moonGlyph = m["moonGlyph"]?.nonEmpty
        let sunGlyph = m["sunGlyph"]?.nonEmpty
        let moonTitle: String = {
            var t = m["moonName"] ?? "The Moon"
            if let pct { t += " · \(pct)% lit" }
            if let sign = m["moonSign"]?.nonEmpty { t += " in \(sign) \(moonGlyph ?? "")" }
            return t
        }()
        let moonBody = m["moonLine"]?.nonEmpty ?? surface.payload.body
        let sunTitle: String = {
            if let sign = m["sunSign"]?.nonEmpty { return "Sun in \(sign) \(sunGlyph ?? "")" }
            return "The turning of the light"
        }()
        let sunBody = m["lightTrend"]?.nonEmpty ?? "The light is turning."
        let eventTitle = m["eventName"]?.nonEmpty.map { "Next overhead: \($0)" } ?? "Look up soon"
        let eventBody = m["eventLine"].flatMap { $0.nonEmpty }.map { "Worth looking up for \($0)." }
            ?? "Keep one true sentence about the sky tonight."

        return VStack(alignment: .leading, spacing: 14) {
            hourPageCallout(
                title: moonTitle,
                symbol: m["moonSymbol"]?.nonEmpty ?? "moon.stars",
                body: moonBody,
                tint: BookPalette.teal
            )
            hourPageCallout(
                title: sunTitle,
                symbol: m["lightSymbol"]?.nonEmpty ?? "sun.max",
                body: sunBody,
                tint: BookPalette.lampGold
            )
            hourPageCallout(
                title: eventTitle,
                symbol: m["eventSymbol"]?.nonEmpty ?? "sparkles",
                body: eventBody,
                tint: BookPalette.teal
            )
            Button {
                Task { await addSkyWatchToCalendar() }
            } label: {
                Label("Add a sky-watch to my Calendar", systemImage: "calendar.badge.plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(BookPalette.teal)

            if !todaysSkyMessage.isEmpty {
                Text(todaysSkyMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addSkyWatchToCalendar() async {
        let m = surface.payload.metadata
        let eventName = m["eventName"]?.nonEmpty ?? "a celestial event"
        let when: Date = {
            if let ts = m["eventTimestamp"].flatMap({ Double($0) }) {
                let day = Date(timeIntervalSince1970: ts)
                return Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: day) ?? day
            }
            return Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        }()
        let ok = await EventKitWriter.addEvent(
            title: "Look up: \(eventName)",
            notes: m["eventLine"].flatMap { $0.nonEmpty }.map { "\(eventName): \($0)." } ?? "",
            start: when,
            end: when.addingTimeInterval(3_600)
        )
        todaysSkyMessage = ok
            ? "The sky-watch is marked on your calendar."
            : "It could not be added (check Calendar permission in Settings)."
        BookFeedback.play(ok ? .select : .error)
    }

    private var academyCalendarControl: some View {
        let m = surface.payload.metadata
        let isClub = m["sessionKind"] == "club"
        let sessionName = m["sessionName"]?.nonEmpty ?? surface.prompt
        let room = m["sessionRoom"]?.nonEmpty ?? ""
        let leader = m["sessionLeader"]?.nonEmpty ?? ""
        let blockLine = academySessionTimeLine(metadata: m)
        let sessionDetailLine = [Optional(sessionName), blockLine, Optional(room)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(isClub ? "Add this club to Calendar" : "Add this class to Calendar")
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.teal)
                    Text(sessionDetailLine)
                        .font(.callout)
                        .foregroundStyle(openPageSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                Task { await addAcademySessionToCalendar() }
            } label: {
                Label(isClub ? "Add club" : "Add class", systemImage: "calendar.badge.plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(BookPalette.teal)

            if !leader.isEmpty && !isClub {
                Text("\(leader) will be listed in the notes.")
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText.opacity(0.82))
            }

            if !academyCalendarMessage.isEmpty {
                Text(academyCalendarMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private func academySessionTimeLine(metadata: [String: String]) -> String? {
        guard let start = metadata["sessionStartTimestamp"].flatMap(Double.init),
              let end = metadata["sessionEndTimestamp"].flatMap(Double.init) else {
            return nil
        }
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(
            from: Date(timeIntervalSince1970: start),
            to: Date(timeIntervalSince1970: end)
        )
    }

    private func addAcademySessionToCalendar() async {
        let m = surface.payload.metadata
        let isClub = m["sessionKind"] == "club"
        let sessionName = m["sessionName"]?.nonEmpty ?? surface.prompt
        guard let startTimestamp = m["sessionStartTimestamp"].flatMap(Double.init),
              let endTimestamp = m["sessionEndTimestamp"].flatMap(Double.init) else {
            academyCalendarMessage = "This session does not have a calendar time yet."
            BookFeedback.play(.error)
            return
        }
        let leader = m["sessionLeader"]?.nonEmpty ?? ""
        let room = m["sessionRoom"]?.nonEmpty ?? ""
        let practice = m["lessonRealWorldPractice"]?.nonEmpty
        let title = isClub ? sessionName : "Class: \(sessionName)"
        let notes = [
            isClub ? "A ReEnchanted Academy club is gathering." : "A ReEnchanted Academy class is in session.",
            leader.isEmpty ? nil : "Leader: \(leader)",
            practice.map { "Practice: \($0)" }
        ].compactMap { $0 }.joined(separator: "\n")

        let ok = await EventKitWriter.addAcademySessionEvent(
            sessionID: m["sessionID"] ?? surface.id,
            title: title,
            notes: notes,
            room: room,
            start: Date(timeIntervalSince1970: startTimestamp),
            end: Date(timeIntervalSince1970: endTimestamp)
        )
        academyCalendarMessage = ok
            ? "\(isClub ? "The club" : "The class") is marked on your calendar."
            : "It could not be added (check Calendar permission in Settings)."
        BookFeedback.play(ok ? .select : .error)
    }

    private var radioPageView: some View {
        let unlocked = Set(PlayerVault.shared.data.ownedPacks ?? [])
        let stations = RadioStationRegistry.stations(unlockedPackIDs: unlocked)
        let currentPlayback = radioManager.isPlaying ? radioManager.playback : (radioManager.playback.isTuned ? radioManager.playback : radioPlayback)
        let dialStation = RadioStationRegistry.tunedStation(to: radioDialFrequency, unlockedPackIDs: unlocked)
        let liveDialIsBetweenStations = (radioManager.isPlaying || hasTouchedRadioDial) && dialStation == nil && selectedRadioStationID == nil
        let fallbackID = liveDialIsBetweenStations ? nil : (currentPlayback.activeStationID ?? surface.payload.metadata["radioStationID"] ?? stations.first?.id)
        let activeID = dialStation?.id ?? selectedRadioStationID ?? fallbackID
        let active = activeID.flatMap { RadioStationRegistry.station(id: $0, unlockedPackIDs: unlocked) } ?? (liveDialIsBetweenStations ? nil : stations.first)
        let isPowered = radioManager.isPlaying
        let interlude = RadioStationRegistry.currentInterlude(state: currentPlayback, unlockedPackIDs: unlocked)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BookPalette.nightPanel.opacity(0.92))
                    Circle()
                        .stroke(BookPalette.lampGold.opacity(0.55), lineWidth: 2)
                    Image(systemName: "radio")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(BookPalette.lampGold)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(active.map { "\($0.displayFrequency) FM" } ?? String(format: "%.1f FM", radioDialFrequency))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(BookPalette.teal)
                    Text(active?.title ?? "Between stations")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.ink)
                    Text(radioManager.statusLine)
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    if isPowered {
                        BookFeedback.play(.dismissPage)
                        onStopRadio()
                    } else if let station = dialStation ?? active {
                        selectedRadioStationID = station.id
                        radioDialFrequency = station.frequency
                        onTuneRadio(station.id)
                    } else {
                        BookFeedback.play(.sourceRefresh)
                        radioManager.playTuningNoise(frequency: radioDialFrequency)
                    }
                } label: {
                    Image(systemName: isPowered ? "power.circle.fill" : "power.circle")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isPowered ? BookPalette.teal : BookPalette.ink.opacity(0.62))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel(isPowered ? "Turn radio off" : "Turn radio on")
            }

            RadioSignalMeter(
                stationID: active?.id ?? "static",
                isPlaying: !isLocalBrainWorking && isPowered && (active == nil || radioManager.playback.activeStationID == active?.id)
            )
            .frame(height: 42)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("88")
                    Spacer()
                    Text(String(format: "%.1f", radioDialFrequency))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(BookPalette.lampGold)
                    Spacer()
                    Text("108")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.52))

                Slider(value: $radioDialFrequency, in: 88...108, step: 0.1)
                    .tint(BookPalette.teal)
                    .onChange(of: radioDialFrequency) { _, value in
                        hasTouchedRadioDial = true
                        let tuned = RadioStationRegistry.tunedStation(to: value, unlockedPackIDs: unlocked)
                        if selectedRadioStationID != tuned?.id {
                            selectedRadioStationID = tuned?.id
                            radioManager.hapticTick()
                        }
                        guard radioManager.isPlaying else { return }
                        if let tuned {
                            if radioManager.playback.activeStationID != tuned.id || radioManager.isPlayingTuningNoise {
                                onTuneRadio(tuned.id)
                            }
                        } else {
                            radioManager.playTuningNoise(frequency: value)
                        }
                    }
            }

            if let active {
                hourPageCallout(
                    title: active.signalLine,
                    symbol: "antenna.radiowaves.left.and.right",
                    body: active.subtitle,
                    tint: BookPalette.teal
                )
                if radioManager.isPlaying,
                   radioManager.activeStation?.id == active.id,
                   let banter = radioManager.nowPlayingBanter {
                    hourPageCallout(
                        title: "DJ: \(active.hostDisplayName)",
                        symbol: "mic.fill",
                        body: banter.readerFacingCaption,
                        tint: BookPalette.violet
                    )
                } else if radioManager.isPlaying,
                          radioManager.activeStation?.id == active.id,
                          let track = radioManager.activeTrack {
                    hourPageCallout(
                        title: "Now playing: \(track.title)",
                        symbol: "waveform",
                        body: [
                            track.artist,
                            track.meaning?.sanitized().ordinaryLifeCue
                        ].compactMap { $0?.nonEmpty }.joined(separator: "\n"),
                        tint: BookPalette.lampGold
                    )
                } else {
                    Text(radioManager.sourceLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !radioManager.isPlaying, let interlude {
                    hourPageCallout(
                        title: "Broadcast interruption",
                        symbol: "quote.bubble",
                        body: interlude,
                        tint: BookPalette.violet
                    )
                }
                Text(radioWorldEffectLine(active))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                hourPageCallout(
                    title: "Static between frequencies",
                    symbol: "waveform.path.ecg",
                    body: radioManager.sourceLine,
                    tint: BookPalette.violet
                )
            }

            VStack(spacing: 8) {
                ForEach(stations) { station in
                    Button {
                        selectedRadioStationID = station.id
                        radioDialFrequency = station.frequency
                        BookFeedback.play(.select)
                        onTuneRadio(station.id)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(station.displayFrequency)  \(station.title)")
                                    .font(.subheadline.weight(.bold))
                                Text(station.subtitle)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: currentPlayback.activeStationID == station.id ? "dot.radiowaves.left.and.right" : "chevron.right")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(BookPalette.ink)
                        .padding(12)
                        .background((currentPlayback.activeStationID == station.id ? BookPalette.teal.opacity(0.18) : BookPalette.paper.opacity(0.58)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke((currentPlayback.activeStationID == station.id ? BookPalette.teal : BookPalette.ink.opacity(0.12)), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.bookPress())
                }
            }

            HStack(spacing: 10) {
                Button {
                    guard let active else { return }
                    BookFeedback.play(.sourceRefresh)
                    selectedRadioStationID = active.id
                    radioDialFrequency = active.frequency
                    onTuneRadio(active.id)
                } label: {
                    Label("Tune station", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)

                Button {
                    BookFeedback.play(.dismissPage)
                    onStopRadio()
                } label: {
                    Label("Quiet", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.ink)
            }

            Text(radioPageBody(active: active, stations: stations, isPowered: isPowered, frequency: radioDialFrequency, interlude: interlude))
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            if liveDialIsBetweenStations {
                selectedRadioStationID = nil
            } else {
                let station = active ?? stations.first
                selectedRadioStationID = station?.id
                radioDialFrequency = station?.frequency ?? 94.1
            }
        }
    }

    private func radioWorldEffectLine(_ station: RadioStation) -> String {
        let doors = station.effects.map { effect in
            switch effect.pageType {
            case .narrativeOS, .gossip, .bookAside, .taleBound:
                return "story leaves"
            case .weather, .todaysSky:
                return "weather leaves"
            case .souvenir, .bookRemembered:
                return "remembered things"
            case .quip, .quotes, .affirmations:
                return "borrowed sparks"
            case .lore, .bookConnections, .bookNotices:
                return "noticing leaves"
            case .wonderCompass, .wickerDare, .pactErrand:
                return "small errands"
            default:
                return "\(effect.pageType.shortTitle.lowercased()) leaves"
            }
        }
        var seen = Set<String>()
        let unique = doors.filter { seen.insert($0).inserted }
        let named = unique.isEmpty ? "a few restless leaves" : unique.joined(separator: ", ")
        return "While \(station.title) is singing, \(named) shove nearer the top of my pile."
    }

    private func radioPageBody(active: RadioStation?, stations: [RadioStation], isPowered: Bool, frequency: Double, interlude: String?) -> String {
        let stationLines = stations
            .map { "\($0.displayFrequency): \($0.title): \($0.subtitle)" }
            .joined(separator: "\n")
        guard let active else {
            return """
            The receiver is powered \(isPowered ? "on" : "off") at \(String(format: "%.1f", frequency)) FM, between stations.

            Static combs the edge of the page. Now and then, a syllable almost becomes a name and thinks better of it.

            Core frequencies now on the dial:
            \(stationLines)
            """
        }
        return """
        The receiver is tuned to \(active.displayFrequency): \(active.title).

        \(active.signalLine)

        \(interlude.map { "Broadcast interruption: \($0)\n\n" } ?? "")\(radioWorldEffectLine(active))

        Core frequencies now on the dial:
        \(stationLines)
        """
    }

    private var bookJumpView: some View {
        let metadata = surface.payload.metadata
        let action = bookJumpAction ?? .start
        let title = metadata["bookTitle"]?.nonEmpty ?? "a public-domain book"
        let author = metadata["bookAuthor"]?.nonEmpty ?? "the public stacks"
        let depth = Int(metadata["bookJumpDepth"] ?? "") ?? 0
        let degradation = Int(metadata["bookJumpDegradation"] ?? "") ?? 0
        let rules = (metadata["bookRules"] ?? "")
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 38, height: 38)
                    .background(BookPalette.ink.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(BookPalette.teal)
                    Text(title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(author)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bookJumpDepthLine(depth))
                Text(BookMechanicPresentation.pressure(current: degradation, limit: 4))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(degradation >= 2 ? BookPalette.violet : BookPalette.teal)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(BookPalette.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !rules.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Rules of this book", systemImage: "text.book.closed")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                    ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                        Text(rule)
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(BookPalette.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if action == .start {
                Label(
                    "Keeping this page lends the jump some Belief and opens the Spine.",
                    systemImage: "sparkles"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                if readerBeliefScore < BookJumpEngine.startCost {
                    Text("The Spine will wait. Real-world attention will rekindle enough Glow to open it.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.violet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                bookJumpForkControls(depth: depth, degradation: degradation)
            }

            if let url = metadata["gutenbergURL"].flatMap(URL.init(string:)) {
                Link(destination: url) {
                    Label("Public-domain source", systemImage: "link")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(BookPalette.teal)
            }
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }

    private func bookJumpDepthLine(_ depth: Int) -> String {
        switch depth {
        case ...0:
            return "The Spine is still close."
        case 1:
            return "The Spine is still within earshot."
        case 2:
            return "The book has begun closing behind you."
        default:
            return "You are deep in borrowed ink."
        }
    }

    /// The reader steers an open jump: go deeper (more risk, richer return),
    /// steady the page when Routine is loud, or find the Spine and come home.
    @ViewBuilder
    private func bookJumpForkControls(depth: Int, degradation: Int) -> some View {
        let canDeepen = depth < BookJumpEngine.maxDepth
        let canReturn = depth >= 2
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 10) {
            if canReturn {
                Text("Write one sentence to bring home, then find the Spine, or press deeper first.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            } else if degradation >= 2 {
                Text("The page is blurring. Name one true real-world detail to steady it, or press deeper anyway.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.violet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if canDeepen {
                let advanceCost = BookJumpEngine.advanceCost(depth: depth)
                Text("The next page will take a little more Belief. Choose how it turns:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(StoryChoiceRole.allCases, id: \.self) { role in
                    bookJumpDeeperButton(role: role, depth: depth, degradation: degradation)
                }
                if readerBeliefScore < advanceCost {
                    Text("The next page needs more attention from the world outside me.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.violet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if degradation >= 1 {
                bookJumpActionButton(
                    title: "Steady the page",
                    systemImage: "hand.raised",
                    tint: BookPalette.lampGold
                ) { keepBookJump(as: .stabilize) }
            }
            if canReturn {
                bookJumpActionButton(
                    title: trimmed.isEmpty ? "Find the Spine (no souvenir)" : "Find the Spine and return",
                    systemImage: "arrow.uturn.backward.circle.fill",
                    tint: BookPalette.lampGold,
                    prominent: true
                ) { keepBookJump(as: .return) }
            }
        }
    }

    private func bookJumpActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background((prominent ? tint.opacity(0.22) : BookPalette.ink.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(prominent ? 0.7 : 0.4), lineWidth: 1)
                }
        }
        .buttonStyle(.bookPress())
        .foregroundStyle(tint)
    }

    private func bookJumpDeeperButton(role: StoryChoiceRole, depth: Int, degradation: Int) -> some View {
        let tint = degradation >= 2 ? BookPalette.violet : BookPalette.teal
        let beliefCost = BookJumpEngine.advanceCost(depth: depth)
        let (subtitle, symbol): (String, String) = {
            switch role {
            case .sliceOfLife: return ("Linger in a quiet, human corner of the book.", "leaf")
            case .progressArc: return ("Push toward the book's central drama.", "arrow.up.forward")
            case .surprise: return ("Veer somewhere unexpected but true to the book.", "sparkles")
            }
        }()
        return Button {
            keepBookJump(as: .advance, direction: role)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.title)
                        .font(.caption.weight(.bold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.bookPress())
        .foregroundStyle(tint)
        .disabled(readerBeliefScore < beliefCost)
        .opacity(readerBeliefScore < beliefCost ? 0.55 : 1)
    }

    private var twoReadingsView: some View {
        let metadata = surface.payload.metadata
        let aID = metadata["entityAID"] ?? "a"
        let aName = metadata["entityAName"] ?? "One reader"
        let bID = metadata["entityBID"] ?? "b"
        let bName = metadata["entityBName"] ?? "Another reader"
        return VStack(alignment: .leading, spacing: 14) {
            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.92))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.nightPanel.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
                }

            Text("I won't settle it. Whose reading do you keep closer? Your agreement lends their reading a little Belief and takes a little from the margins.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                twoReadingsSideButton(name: aName, id: aID)
                twoReadingsSideButton(name: bName, id: bID)
            }

            if let twoReadingsSide {
                Label("You sided with \(twoReadingsSide == aID ? aName : bName). Keep the page to make it so.",
                      systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.lampGold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func twoReadingsSideButton(name: String, id: String) -> some View {
        let selected = twoReadingsSide == id
        return Button {
            BookFeedback.play(.select)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                twoReadingsSide = id
            }
        } label: {
            Label("Agree with \(name)", systemImage: selected ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background((selected ? BookPalette.teal : BookPalette.nightPanel).opacity(selected ? 0.28 : 0.88),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke((selected ? BookPalette.teal : BookPalette.lampGold).opacity(selected ? 0.65 : 0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.bookPress())
        .foregroundStyle(selected ? BookPalette.nightText : BookPalette.nightText.opacity(0.86))
    }

    private func completeTwoReadingsIfNeeded() {
        guard surface.type == .twoReadings, let side = twoReadingsSide else { return }
        let metadata = surface.payload.metadata
        let aID = metadata["entityAID"] ?? ""
        let bID = metadata["entityBID"] ?? ""
        let aName = metadata["entityAName"] ?? "One reader"
        let bName = metadata["entityBName"] ?? "Another reader"
        let chosenID = side
        let chosenName = side == aID ? aName : bName
        let otherID = side == aID ? bID : aID
        let otherName = side == aID ? bName : aName
        onTwoReadingsSided(chosenID, chosenName, otherID, otherName)
    }

    private var faeBargainView: some View {
        let metadata = surface.payload.metadata
        let isOffer = metadata["status"] == FaeBargainStatus.offered.rawValue
        let hasMovedOn = metadata["hasMovedOn"] == "true" || metadata["status"] == FaeBargainStatus.lapsed.rawValue
        let faeName = metadata["faeName"] ?? "A Book Fae"
        let giftName = metadata["giftName"] ?? "a gift"
        let giftLine = metadata["giftEffectLine"] ?? ""
        let giftUseLine = metadata["giftUseLine"] ?? "Find it in Inventory under Fae Gifts."
        let terms = metadata["terms"] ?? surface.detail
        let consequenceLine = metadata["consequenceLine"]
            ?? "When the window passes, the gift goes cold and the old terms close a market door until repaired."
        return VStack(alignment: .leading, spacing: 14) {
            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(openPageSecondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            hourPageCallout(
                title: isOffer ? "\(faeName) is holding out: \(giftName)" : "\(faeName) gave first: \(giftName)",
                symbol: "gift",
                body: giftLine,
                tint: BookPalette.lampGold
            )

            hourPageCallout(
                title: "Where to find and use it",
                symbol: "shippingbox",
                body: giftUseLine,
                tint: BookPalette.teal
            )

            if isOffer {
                hourPageCallout(
                    title: "The price, if you take it",
                    symbol: "hands.sparkles",
                    body: terms,
                    tint: BookPalette.teal
                )

                hourPageCallout(
                    title: "The old law",
                    symbol: "exclamationmark.seal",
                    body: consequenceLine,
                    tint: BookPalette.lampGold
                )

                Button {
                    guard !isFaeAccepting,
                          let bargainID = metadata["bargainID"] else { return }
                    isFaeAccepting = true
                    defer { isFaeAccepting = false }
                    if let accepted = onAcceptFaeBargain(bargainID) {
                        onNavigateToSurface(accepted)
                    } else {
                        faeMessage = "The offer slipped out of reach."
                        BookFeedback.play(.error)
                    }
                } label: {
                    Label(
                        isFaeAccepting ? "The ink is binding..." : "Take the gift. Owe the price.",
                        systemImage: "seal"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.lampGold)
                .disabled(isFaeAccepting)
            } else {
                hourPageCallout(
                    title: hasMovedOn ? "The terms that remain" : "What the Fae is asking",
                    symbol: "hands.sparkles",
                    body: terms,
                    tint: BookPalette.teal
                )

                hourPageCallout(
                    title: hasMovedOn ? "What has gone cold" : "While the exchange waits",
                    symbol: hasMovedOn ? "snowflake" : "hourglass",
                    body: hasMovedOn ? consequenceLine : "The exchange is still open. \(consequenceLine)",
                    tint: BookPalette.lampGold
                )
            }

            if !isOffer, !hasMovedOn, faeResponseText.isEmpty, faeDeadline != nil {
                Button {
                    Task { await setFaeBargainReminder() }
                } label: {
                    Label("Remind me while the exchange is waiting", systemImage: "bell.badge")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bookPress())
                .foregroundStyle(BookPalette.teal)
            }

            if !isOffer {
                if faeResponseText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                    Text(hasMovedOn ? "Answer anyway, if you want" : "Your field report")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(openPageSecondaryText)
                    Text("Sensory and specific. Not the category: the detail. The fae can tell the difference.")
                        .font(.caption)
                        .foregroundStyle(openPageSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    TextEditor(text: $faeReport)
                        .font(.body)
                        .foregroundStyle(BookPalette.ink)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 120)
                        .inkFeedback(text: faeReport)
                        .dictationInput(text: $faeReport)
                        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                        }

                    Button {
                        Task { await payFaeBargainInSheet() }
                    } label: {
                        Label(isFaePaying ? "The Fae is considering..." : (hasMovedOn ? "Send the noticing" : "Answer the bargain"),
                              systemImage: isFaePaying ? "pencil.and.scribble" : "arrow.up.heart")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.bookPress())
                    .foregroundStyle(BookPalette.lampGold)
                    .disabled(isFaePaying || faeReport.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLocalBrainWorking)

                    if isFaePaying {
                        scribeWorkCard("fae-bargain")
                    }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                    Label(faeName, systemImage: "sparkles")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.lampGold.opacity(0.9))
                    Text(faeResponseText)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(hasMovedOn
                          ? "The late answer was welcomed. Keep the page to remember it."
                          : "The bargain is closed. Keep the page to remember it.",
                          systemImage: "checkmark.seal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.teal)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                    }
                }
            }

            if !faeMessage.isEmpty {
                Text(faeMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var greyPageThreatView: some View {
        let metadata = surface.payload.metadata
        let status = GreyPageThreatStatus(
            rawValue: metadata["greyThreatStatus"] ?? ""
        ) ?? .marked
        let title = metadata["greyTargetTitle"] ?? "the marked Page"
        let deadline = metadata["deadline"].flatMap {
            ISO8601DateFormatter().date(from: $0)
        }
        return VStack(alignment: .leading, spacing: 14) {
            if status == .fading {
                hourPageCallout(
                    title: "What is actually at stake",
                    symbol: "rectangle.dashed",
                    body: "The raw Page remains in Stacks and export. The Grey can only take it from living memory: future resurfacing, quotation, connection, and story.",
                    tint: BookPalette.lampGold
                )

                if let deadline {
                    TimelineView(.periodic(from: Date(), by: 60)) { context in
                        let remaining = max(0, deadline.timeIntervalSince(context.date))
                        Text(remaining <= 3_600
                             ? "The ink of “\(title)” is fading now."
                             : "The window around “\(title)” is narrowing.")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.lampGold)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        greyThreatChoice = "rescue"
                    } label: {
                        Label("Bring it one new true detail", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bookPress())
                    .foregroundStyle(greyThreatChoice == "rescue" ? BookPalette.lampGold : BookPalette.teal)

                    if greyThreatChoice == "rescue" {
                        Text("Something this Page could not have known when it was first kept.")
                            .font(.caption)
                            .foregroundStyle(openPageSecondaryText)
                        TextEditor(text: $greyRescueLine)
                            .font(.body)
                            .foregroundStyle(BookPalette.ink)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 110)
                            .inkFeedback(text: greyRescueLine)
                            .dictationInput(text: $greyRescueLine)
                            .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                            }
                    }

                    Button {
                        greyThreatChoice = "surrender"
                        greyRescueLine = ""
                    } label: {
                        Label("Let this Page leave living memory", systemImage: "wind")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bookPress())
                    .foregroundStyle(greyThreatChoice == "surrender" ? BookPalette.lampGold : BookPalette.teal)
                }
            } else if status == .erased {
                hourPageCallout(
                    title: "The scar is real",
                    symbol: "rectangle.dashed",
                    body: "“\(title)” remains readable in raw Stacks and export, but the living Book will no longer use it as memory.",
                    tint: BookPalette.lampGold
                )
            }
        }
    }

    private var inkrestOfficeHoursView: some View {
        VStack(alignment: .leading, spacing: 14) {
            hourPageCallout(
                title: "Tonight, Inkrest is curious about",
                symbol: "lamp.desk",
                body: inkrestIntake.rotatingQuestion,
                tint: BookPalette.lampGold
            )

            if !inkrestTurns.isEmpty {
                ForEach(Array(inkrestTurns.enumerated()), id: \.element.id) { index, turn in
                    inkrestTurnCard(turn, index: index)
                }
            }

            if !inkrestStarted {
                inkrestIntakeForm
            } else if !inkrestClosed {
                inkrestChatComposer
            } else {
                Label("Dr. Inkrest closed the sitting. Keep it below to remember, or let it wait.", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !inkrestMessage.isEmpty {
                Text(inkrestMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isInkrestSitting {
                scribeWorkCard("inkrest-office-hours")
            }
        }
    }

    private var inkrestIntakeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            inkrestFormField(
                title: "Your answer to tonight's question",
                placeholder: "However it actually was: small is fine.",
                text: $inkrestIntake.rotatingAnswer,
                minHeight: 92
            )
            inkrestFormField(
                title: "Inner weather right now",
                placeholder: "Foggy, bright, thunder behind the eyes...",
                text: $inkrestIntake.innerWeather,
                minHeight: 52
            )
            inkrestFormField(
                title: "Anything else for the desk (optional)",
                placeholder: "A worry, a small win, a thing you can't put down.",
                text: $inkrestIntake.freeNote,
                minHeight: 60
            )

            Button {
                beginInkrestSitting()
            } label: {
                Label(isInkrestSitting ? "Knocking..." : "Knock on the door", systemImage: isInkrestSitting ? "pencil.and.scribble" : "door.left.hand.open")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1)
                    }
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(BookPalette.lampGold)
            .disabled(isInkrestSitting || !inkrestIntake.hasSomethingToOpenWith || isLocalBrainWorking)
        }
    }

    private var inkrestChatComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Say more to Dr. Inkrest")
                .font(.caption.weight(.bold))
                .foregroundStyle(openPageSecondaryText)
            TextEditor(text: $inkrestChatInput)
                .font(.body)
                .foregroundStyle(BookPalette.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 100)
                .inkFeedback(text: inkrestChatInput)
                .dictationInput(text: $inkrestChatInput)
                .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                }

            Button {
                continueInkrestSitting(forceClose: false)
            } label: {
                Label(isInkrestSitting ? "Dr. Inkrest is answering" : "Continue", systemImage: isInkrestSitting ? "pencil.and.scribble" : "arrow.right.circle")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.teal.opacity(0.36), lineWidth: 1)
                    }
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(BookPalette.teal)
            .disabled(isInkrestSitting || inkrestChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLocalBrainWorking)

            Button {
                continueInkrestSitting(forceClose: true)
            } label: {
                Label("Let her close the sitting", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bookPress())
            .foregroundStyle(openPageSecondaryText)
            .disabled(isInkrestSitting || isLocalBrainWorking)
        }
    }

    private func inkrestFormField(title: String, placeholder: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(openPageSecondaryText)
            TextEditor(text: text)
                .font(.body)
                .foregroundStyle(BookPalette.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: minHeight)
                .inkFeedback(text: text.wrappedValue)
                .dictationInput(text: text)
                .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(BookPalette.ink.opacity(0.3))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func inkrestTurnCard(_ turn: AskTheBookTurn, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(index == 0 ? "YOU BROUGHT" : "YOU SAID")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            Text(turn.prompt)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
                .overlay(BookPalette.ink.opacity(0.16))
            Label("Dr. Inkrest", systemImage: "lamp.desk")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.lampGold.opacity(0.9))
            Text(turn.answer)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }

    private var enchantmentPageView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isCastEnchantmentLandingPage {
                enchantmentSpellGrid
            }

            if let spell = activeEnchantmentSpell {
                enchantmentCastingCard(spell)
            }

            if let result = enchantmentResult {
                enchantmentResultCard(result)
            }

            if activeEnchantmentSpell?.id == "everything-speaks", enchantmentResult != nil {
                AnyView(everythingSpeaksConversationView)
            }
        }
    }

    private var enchantmentSpellGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 10)], spacing: 10) {
            ForEach(StoryEnchantmentCatalog.spells) { spell in
                Button {
                    selectedEnchantmentID = spell.id
                    enchantmentMessage = "Choose a photo for \(spell.title)."
                    BookFeedback.play(.openPage)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(spell.title, systemImage: spell.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Text(spell.detail)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.62))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                    }
                }
                .buttonStyle(.bookPress())
            }
        }
    }

    private func enchantmentCastingCard(_ spell: EnchantmentSpell) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(spell.title, systemImage: spell.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)

            Text(spell.detail)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            #if canImport(PhotosUI)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Label(
                    isCastingEnchantment
                        ? "Casting..."
                        : "\(enchantmentResult == nil ? "Choose photo and cast" : "Cast on another photo"): the spell will borrow some Belief",
                    systemImage: "photo"
                )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(
                isCastingEnchantment ||
                isLocalBrainWorking ||
                readerBeliefScore < BeliefGenerationKind.enchantment.cost
            )
            #endif

            #if canImport(UIKit)
            if BookCameraCaptureView.isCameraAvailable {
                Button {
                    BookFeedback.play(.openPage)
                    isCameraPresented = true
                } label: {
                    Label(
                        "Take photo and cast",
                        systemImage: "camera"
                    )
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.lampGold)
                .disabled(
                    isCastingEnchantment ||
                    isLocalBrainWorking ||
                    readerBeliefScore < BeliefGenerationKind.enchantment.cost
                )
            }
            #endif

            if readerBeliefScore < BeliefGenerationKind.enchantment.cost {
                Text("The spell is waiting for my Glow to warm.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
            }

            if isCastingEnchantment {
                scribeWorkCard(
                    "enchantment-\(spell.id)",
                    quip: "The spell is reading only what the photo gives it."
                )
            }

            if !enchantmentMessage.isEmpty {
                Text(enchantmentMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.26), lineWidth: 1)
        }
    }

    private func enchantmentResultCard(_ result: EnchantmentCastResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.openingLine)
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)
            Text(result.resultText)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let voice = result.objectVoice, !voice.isEmpty {
                Text("Voice: \(voice)")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                BookFeedback.play(.sourceRefresh)
                Task { await saveEnchantmentArtifactToPhotos() }
            } label: {
                Label(isSavingEnchantmentArtifact ? "Saving..." : "Save result to Photos", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(isSavingEnchantmentArtifact || enchantmentArtifactURL == nil)

            if effectiveSurface.payload.metadata["storyMechanicReturn"] == "true" {
                Button {
                    completeStoryMechanicIfNeeded(surface: effectiveSurface, outcome: preparedInput)
                    requestDismiss()
                } label: {
                    Label(
                        effectiveSurface.payload.metadata["academyActivityReturn"] == "true" ? "Return to Class" : "Continue Story",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
            }
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
        .bookResultArrival(reduceMotion: reduceMotion)
        .id(Self.enchantmentResultScrollID)
    }

    private var everythingSpeaksConversationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !enchantmentTurns.isEmpty {
                ForEach(Array(enchantmentTurns.enumerated()), id: \.element.id) { index, turn in
                    askTurnCard(turn, index: index)
                }
            }

            TextEditor(text: $enchantmentPrompt)
                .font(.body)
                .foregroundStyle(BookPalette.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 96)
                .inkFeedback(text: enchantmentPrompt)
                .dictationInput(text: $enchantmentPrompt)
                .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                }

            Button {
                Task { await askEnchantedObject() }
            } label: {
                Label(isAnsweringEnchantedObject ? "Listening..." : "Ask the subject", systemImage: "text.bubble")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
            .disabled(isAnsweringEnchantedObject || enchantmentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLocalBrainWorking)

            if isAnsweringEnchantedObject {
                scribeWorkCard("everything-speaks-reply")
            }
        }
    }

    private func storyMechanicActionCard(choice: StoryPageChoiceDraft, draft: StoryPageSceneDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(choice.mechanic.title, systemImage: choice.mechanic.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(choice.tint)

            Text(choice.mechanic.detail)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                runStoryMechanic(choice: choice, draft: draft)
            } label: {
                Label(choice.mechanic.actionTitle, systemImage: choice.mechanic.symbolName)
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(choice.tint)
            .disabled(activeInkbonesThrow != nil)
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(choice.tint.opacity(0.34), lineWidth: 1)
        }
    }

    private func storyMechanicIsResolved(
        _ choice: StoryPageChoiceDraft,
        in turn: StoryPageSessionTurn
    ) -> Bool {
        switch choice.mechanic.kind {
        case .none:
            return true
        case .beliefDice:
            return turn.inkbonesResolution(for: choice) != nil
        case .compassRun, .enchantment:
            return resolvedStoryMechanics[choice.id] != nil
        }
    }

    private func storyNarrativeResultIsReady(
        _ choice: StoryPageChoiceDraft,
        in turn: StoryPageSessionTurn
    ) -> Bool {
        guard storyMechanicIsResolved(choice, in: turn) else { return false }
        guard choice.mechanic.kind == .beliefDice else { return true }
        return turn.generatedResults[choice.id]?.nonEmpty != nil
    }

    private func runStoryMechanic(choice: StoryPageChoiceDraft, draft: StoryPageSceneDraft) {
        switch choice.mechanic.kind {
        case .none:
            Task { await generateStoryResultForActiveTurn(choiceID: choice.id) }
        case .beliefDice:
            beginStoryBeliefDiceThrow(choice: choice, draft: draft)
        case .compassRun:
            onNavigateToSurface(storyCompassRunSurface(choice: choice, draft: draft))
        case .enchantment:
            onNavigateToSurface(storyEnchantmentSurface(choice: choice, draft: draft))
        }
    }

    private func beginStoryBeliefDiceThrow(choice: StoryPageChoiceDraft, draft: StoryPageSceneDraft) {
        guard activeInkbonesThrow == nil else { return }
        let inkbonesThrow = InkbonesThrow.make(choice: choice)
        activeInkbonesThrow = inkbonesThrow
        storyContinuationMessage = ""
        BookFeedback.play(.braidStart)
        Task {
            try? await Task.sleep(for: reduceMotion ? .milliseconds(520) : .milliseconds(1_520))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                completeStoryBeliefDiceThrow(inkbonesThrow)
            }
        }
    }

    @MainActor
    private func completeStoryBeliefDiceThrow(_ inkbonesThrow: InkbonesThrow) {
        guard activeInkbonesThrow?.id == inkbonesThrow.id else { return }
        if let turnIndex = storyTurns.indices.last {
            // `generatedResults` is reserved for story prose. The old path put
            // the roll summary there, which made the result writer believe the
            // narrative consequence had already been written.
            storyTurns[turnIndex].inkbonesResolutions[inkbonesThrow.choiceID] = inkbonesThrow.resolution
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            activeInkbonesThrow = nil
        }
        storyContinuationMessage = "The Inkbones landed. I'm writing what changed."
        BookFeedback.play(.braidComplete)
        Task {
            await generateStoryResultForActiveTurn(choiceID: inkbonesThrow.choiceID)
        }
    }

    private func storyCompassRunSurface(choice: StoryPageChoiceDraft, draft: StoryPageSceneDraft) -> SurfacePage {
        var page = BookPageSourceAdapters.manualSurface(
            for: .wonderCompass,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: BookSourceInputs(),
            now: Date()
        )
        return page.withStoryMechanicReturn(
            mechanic: choice.mechanic,
            storySurface: surface,
            draft: draft,
            choice: choice
        )
    }

    private func academyCompassRunSurface(activity: AcademyActivity, draft: StoryPageSceneDraft) -> SurfacePage {
        let page = BookPageSourceAdapters.manualSurface(
            for: .wonderCompass,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: BookSourceInputs(),
            now: Date()
        )
        return page.withAcademyActivityReturn(activity: activity, draft: draft)
    }

    private func academyEnchantmentSurface(
        spell: EnchantmentSpell,
        activity: AcademyActivity,
        draft: StoryPageSceneDraft
    ) -> SurfacePage {
        let page = SurfacePage(
            id: "academy-enchantment-\(spell.id)-\(day.id)-\(Int(Date().timeIntervalSince1970))",
            type: .enchantment,
            sourceID: BookPageSourceRegistry.source(for: .enchantment).id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 72,
            reason: "Professor Wispwood assigned one of my real Enchantments.",
            prompt: spell.title,
            detail: spell.detail,
            payload: BookPagePayload(
                headline: "Basic Enchantments: \(spell.title)",
                body: "Wispwood sends you to cast \(spell.title) on one real subject. Choose or take a photograph, let the existing Enchantment do its work, then bring the result back to class.",
                metadata: [
                    "source": "enchantment",
                    "enchantmentID": spell.id,
                    "enchantmentName": spell.title,
                    "tags": "academy,enchantment,proof,real-world-magic,\(spell.id)"
                ]
            )
        )
        return page.withAcademyActivityReturn(activity: activity, draft: draft)
    }

    private func storyEnchantmentSurface(choice: StoryPageChoiceDraft, draft: StoryPageSceneDraft) -> SurfacePage {
        let spell = StoryEnchantmentCatalog.spell(id: choice.mechanic.enchantmentID) ?? StoryEnchantmentCatalog.spells.first!
        let page = SurfacePage(
            id: "story-enchantment-\(spell.id)-\(day.id)-\(Int(Date().timeIntervalSince1970))",
            type: .enchantment,
            sourceID: BookPageSourceRegistry.source(for: .enchantment).id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 68,
            reason: "The Story Page asked for a real Enchantment before the thread moves on.",
            prompt: spell.title,
            detail: spell.detail,
            payload: BookPagePayload(
                headline: "Enchantment Page: \(spell.title)",
                body: "\(spell.detail)\n\nChoose a photo. The Story Page will continue from the illuminated result.",
                metadata: [
                    "source": "enchantment",
                    "enchantmentID": spell.id,
                    "enchantmentName": spell.title,
                    "tags": "enchantment,proof,real-world-magic,\(spell.id)"
                ]
            )
        )
        return page.withStoryMechanicReturn(
            mechanic: choice.mechanic,
            storySurface: surface,
            draft: draft,
            choice: choice
        )
    }

    @ViewBuilder
    private var preparedPageContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let letterPortraitAssetName {
                HStack {
                    Spacer(minLength: 0)
                    Image(letterPortraitAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(BookPalette.gold.opacity(0.4), lineWidth: 1))
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                }
            }

            if let illustrationAssetName {
                Image(illustrationAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                    }
                    .accessibilityLabel(surface.payload.headline)
                    .imagePreviewOnTap { ImagePreview.url(forAsset: illustrationAssetName) }
            }

            #if canImport(UIKit)
            if shouldShowCameraCapturePage {
                cameraCapturePage
            } else if let illuminatedDraft {
                illuminatedPreview(draft: illuminatedDraft, height: 360)
                    .id(Self.enchantmentPlateScrollID)
            }
            #else
            if let illuminatedDraft {
                illuminatedPreview(draft: illuminatedDraft, height: 360)
                    .id(Self.enchantmentPlateScrollID)
            }
            #endif

            if let castMemberImage {
                Image(uiImage: castMemberImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                    }
                    .accessibilityLabel(surface.payload.headline)
                    .imagePreviewOnTap { surface.payload.metadata["imageAssetReference"].flatMap { ImagePreview.url(forFilePath: $0) } }
            }

            #if canImport(UIKit)
            if surface.type == .illuminatedPhoto && !shouldShowCameraCapturePage {
                AnyView(illuminatedPhotoActions)
            }
            #else
            if surface.type == .illuminatedPhoto {
                AnyView(illuminatedPhotoActions)
            }
            #endif

            if isPendingLetterPage {
                pendingLetterPageView
            }

            if isPendingNotePage {
                pendingNotePageView
            }

            if isSeasonalDispatchPage {
                seasonalDispatchControls
            }

            if isLocalBrainIssuePage {
                localBrainIssueBody
            } else if surface.type == .theBleed {
                bleedEditionView
            } else if surface.type == .radio {
                radioPageView
            } else if surface.type == .inventory {
                inventoryPageView
            } else if let activeStoryTurn {
                storySceneView(activeStoryTurn)
            }

            if isCompassPracticePage {
                AnyView(compassPracticeView)
            }

            if isPennySentenceMasteryPage {
                AnyView(pennySentenceMasteryView)
            }

            if surface.type == .supportGuild {
                SupportGuildSectionView(surface: surface)
            }

            if isOpenedNotePage {
                studentNoteView
            }

            if allowsCompassPhotoProof {
                compassProofPhotoPicker
            }

            if surface.type == .bookRemembered {
                bookRememberedOpeningView
            } else if surface.type == .bookNotices {
                if isBookWorkingInvitationPage {
                    bookWorkingInvitationView
                } else if surface.payload.metadata["firstReading"] == "true" {
                    firstReadingOpeningView
                } else {
                    bookNoticesOpeningView
                }
            } else if surface.type == .bookPocket {
                bookPocketOpeningView
            } else if isQuillChoosingPage {
                quillChoosingOpeningView
            } else if surface.payload.metadata["weeklyIssue"] == "true" {
                weeklyIssueOpeningView
            } else {
                HStack(spacing: 8) {
                    if let weatherSymbolName {
                        Image(systemName: weatherSymbolName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BookPalette.gold)
                    }
                    Text(preparedPageLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                }
            }

            if acceptsReaderKeepsakes {
                Divider()
                    .overlay(BookPalette.ink.opacity(0.12))

                marginNoteEditor(
                    minHeight: 104,
                    placeholder: "\(pageResponsePlaceholder) A photo or a voice memo can go here too."
                )
            }

            if !surface.isStoryPlayablePage && surface.type != .theBleed && surface.type != .radio && surface.type != .inventory && surface.type != .bookRemembered && surface.type != .bookNotices && surface.type != .bookPocket && !isQuillChoosingPage && surface.payload.metadata["weeklyIssue"] != "true" && !isCompassPracticePage && !isPennySentenceMasteryPage && surface.type != .supportGuild && surface.type != .note && !isPendingLetterPage {
                if isWelcomeIntroductionPage {
                    welcomeIntroductionBody
                } else {
                    Text(surface.payload.body)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(BookPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if showsLocalBrainInstallControl {
                localBrainInstallControl
            }

            if surface.type == .rest {
                centerRestPractice
            }

            if isOpenedLetterPage {
                letterReplySection
            }

            if isOpenedNotePage {
                noteReplySection
            }

            if let practiceText {
                tryThisCallout(practiceText)
            }
        }
        .padding(14)
        .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
        }
    }

    private var quillChoosingOpeningView: some View {
        let metadata = surface.payload.metadata
        let name = metadata["quillName"]?.nonEmpty ?? "The waiting quill"
        let make = metadata["quillMake"]?.nonEmpty ?? "A living instrument from the school overhead"
        return VStack(alignment: .leading, spacing: 14) {
            if let asset = metadata["locationAsset"]?.nonEmpty {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        LinearGradient(
                            colors: [.clear, BookPalette.ink.opacity(0.62)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("THE QUILLQUARIUM")
                                .font(.caption2.weight(.black))
                                .tracking(1.2)
                            Text("Where the instrument chose the writer")
                                .font(.system(.callout, design: .serif, weight: .semibold))
                        }
                        .foregroundStyle(BookPalette.paper)
                        .padding(14)
                    }
                    .accessibilityLabel("The Quillquarium, where living instruments choose their writers")
                    .imagePreviewOnTap { ImagePreview.url(forAsset: asset) }
            }

            ceremonyHeader(
                title: name,
                subtitle: make,
                symbol: "pencil.and.scribble",
                tint: BookPalette.lampGold
            )

            if let nature = metadata["quillNature"]?.nonEmpty {
                artifactQuoteCard(nature, symbol: "sparkles", tint: BookPalette.teal)
            }

            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "Keep the Page and the choosing would stand. Let it wait and \(name) would go back to the school and sulk about it.",
                systemImage: "book.closed.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(BookPalette.ink.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bookRememberedOpeningView: some View {
        let metadata = surface.payload.metadata
        let rememberedText = metadata["rememberedText"]?.nonEmpty ?? surface.payload.body
        let reason = metadata["rhymeReason"]?.nonEmpty ?? surface.reason
        let todayConnections = metadata["todayConnectionLines"]?
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let connectionText = (todayConnections?.isEmpty == false ? todayConnections : nil)?
            .joined(separator: "\n\n") ?? reason
        let action = metadata["tinyAction"]?.nonEmpty
        let provenance = bookRememberedProvenanceLine(metadata)
        let rememberedPage = metadata["rememberedPageID"].flatMap { keptPage(id: $0) }
        let rememberedTextTitle: String
        let rememberedTextOwner = metadata["rememberedTextOwner"]
        if rememberedTextOwner == BookPageOrigin.generated.rawValue
            || rememberedTextOwner == BookPageOrigin.simulated.rawValue {
            rememberedTextTitle = "A Page I wrote; you kept"
        } else if rememberedTextOwner == BookPageOrigin.imported.rawValue {
            rememberedTextTitle = "A scrap you brought"
        } else {
            rememberedTextTitle = "Words you wrote"
        }
        let readerContributions = metadata["rememberedReaderContributions"]?.nonEmpty

        return VStack(alignment: .leading, spacing: 14) {
            ceremonyHeader(
                title: "I brought an old Page back.",
                subtitle: provenance ?? "I found the reason. It is below.",
                symbol: "clock.arrow.circlepath",
                tint: BookPalette.lampGold
            )

            ceremonyFindingCard(
                title: rememberedTextTitle,
                text: rememberedText,
                symbol: "book.closed",
                tint: BookPalette.lampGold
            )

            if let readerContributions {
                ceremonyFindingCard(
                    title: "What you put into it",
                    text: readerContributions,
                    symbol: "hand.draw",
                    tint: BookPalette.teal
                )
            }

            ceremonyFindingCard(
                title: "Why I brought it back today",
                text: connectionText,
                symbol: "sparkle.magnifyingglass",
                tint: BookPalette.teal
            )

            if let rememberedPage {
                returnedPageButton(rememberedPage)
            }

            if let action {
                ritualCard(action, title: "What now")
            }
        }
        .opacity(didRevealCeremony ? 1 : 0.01)
        .offset(y: didRevealCeremony ? 0 : 8)
        .animation(.easeOut(duration: 0.55), value: didRevealCeremony)
    }

    /// The First Reading: a once-ever milestone, so it wears a warmer, lamplit
    /// ceremony than the investigative teal of ordinary pattern-noticing. It is
    /// the first time the Book proves it read *you*, and it should feel like a
    /// light coming on, not a case being opened.
    /// The Weekly Issue: the reader's past seven days becoming a private
    /// literary magazine. The opening is only its cover ceremony; the nightly
    /// braids, findings, Cast desk, plates, and loose thread appear after binding.
    private var weeklyIssueOpeningView: some View {
        let m = surface.payload.metadata
        let number = m["weeklyIssueNumber"] ?? "1"
        let range = m["weeklyIssueRange"] ?? ""
        let keptCount = m["weeklyIssueKeptCount"] ?? ""
        let isFirst = m["weeklyIssueFirst"] == "true"
        let highlights = (m["weeklyIssueHighlights"] ?? "")
            .split(separator: "\n").map(String.init)
        let countWord = keptCount == "1" ? "page" : "pages"
        let publicSeal = m["publicSeal"] ?? "Made with ReEnchanted \u{00B7} reenchanted.app"

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("THE BOOK OF YOU")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(BookPalette.ink.opacity(0.55))
                    Spacer(minLength: 8)
                    Text(range)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.55))
                }
                Text("Issue No. \(number)")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                Text(isFirst ? "Your first week, bound." : "Your week became a literary magazine.")
                    .font(.system(.callout, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.lampGold)
            }

            Rectangle()
                .fill(BookPalette.lampGold.opacity(0.3))
                .frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.caption)
                    .foregroundStyle(BookPalette.teal)
                Text("\(keptCount) \(countWord) kept this week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.7))
            }

            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("In this issue")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.teal)
                    ForEach(Array(highlights.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(BookPalette.lampGold)
                                .padding(.top, 7)
                            Text(line)
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(BookPalette.ink.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Text("The month and the year are still gathering. This week is already whole: keep the issue to shelve it.")
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            Text(publicSeal)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .opacity(didRevealCeremony ? 1 : 0.01)
        .offset(y: didRevealCeremony ? 0 : 8)
        .animation(.easeOut(duration: 0.55), value: didRevealCeremony)
    }

    private var firstReadingOpeningView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.bold))
                Text("The First Reading")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.6)
            }
            .foregroundStyle(BookPalette.lampGold)

            ceremonyHeader(
                title: surface.payload.headline.nonEmpty ?? "I Read Back",
                subtitle: "The first time I read you, and meant it.",
                symbol: "book.closed",
                tint: BookPalette.lampGold
            )

            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            ceremonyFindingCard(
                title: "A first light",
                text: "This is the least I will ever know you.",
                symbol: "sparkle",
                tint: BookPalette.lampGold
            )
        }
        .opacity(didRevealCeremony ? 1 : 0.01)
        .offset(y: didRevealCeremony ? 0 : 8)
        .animation(.easeOut(duration: 0.55), value: didRevealCeremony)
    }

    private var bookNoticesOpeningView: some View {
        let metadata = surface.payload.metadata
        let opening = bookNoticesOpeningLine(metadata)
        let subtitle = metadata["magicMoment"] == "true"
            ? "I found enough evidence to ask about this."
            : bookNoticesSubtitle(metadata)
        let slips = bookNoticesEvidenceSlips(metadata)
        let patternCards = bookNoticesPatternCards(metadata)
        let adaptiveActions = bookNoticeAdaptiveActions(metadata)

        return VStack(alignment: .leading, spacing: 14) {
            ceremonyHeader(
                title: opening,
                subtitle: subtitle,
                symbol: "sparkle.magnifyingglass",
                tint: BookPalette.teal
            )

            let posture = bookEvidencePosture(metadata)
            let showsEvidence = posture == .volunteered || didOpenWithheldEvidence

            if !slips.isEmpty || !patternCards.isEmpty, !showsEvidence {
                bookWithheldEvidenceLatch(posture)
            }

            if !slips.isEmpty, showsEvidence {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pages I used")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.teal)
                    ForEach(slips) { slip in
                        evidenceSlip(slip)
                    }
                }
            }

            if !patternCards.isEmpty, showsEvidence {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What I found")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.teal)
                    ForEach(patternCards) { card in
                        ceremonyFindingCard(
                            title: card.title,
                            text: card.text,
                            symbol: card.symbol,
                            tint: BookPalette.teal
                        )
                    }
                }
            }

            if let omen = bookNoticesOmen(metadata) {
                ceremonyFindingCard(
                    title: omen.title,
                    text: omen.text,
                    symbol: omen.symbol,
                    tint: omen.tint
                )
            }

            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !adaptiveActions.isEmpty {
                bookNoticeAdaptiveActionsView(adaptiveActions)
            }

            bookNoticeFeedbackCard(metadata)
        }
        .opacity(didRevealCeremony ? 1 : 0.01)
        .offset(y: didRevealCeremony ? 0 : 8)
        .animation(.easeOut(duration: 0.55), value: didRevealCeremony)
    }

    private var bookWorkingInvitationView: some View {
        VStack(alignment: .leading, spacing: 14) {
            ceremonyHeader(
                title: surface.payload.headline,
                subtitle: "The world keeps happening outside my covers. I object.",
                symbol: "key.fill",
                tint: BookPalette.lampGold
            )

            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            ceremonyFindingCard(
                title: "You mark the doors",
                text: "Calendar, summons, cast interference: choose exactly what I may touch and how often I may try it.",
                symbol: "hand.raised.fill",
                tint: BookPalette.teal
            )

            ceremonyFindingCard(
                title: "Snatch the keys back",
                text: "Snatch the keys back. Shut the pact and I crawl inside my covers. I don't keep debts you never made.",
                symbol: "lock.open.fill",
                tint: BookPalette.violet
            )

            Button {
                BookFeedback.play(.openPage)
                onOpenBookWorkingAuthority()
            } label: {
                Label("Put one key in the binding", systemImage: "key.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)

            Button("Not yet") {
                BookFeedback.play(.dismissPage)
                letPageWait()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(BookPalette.violet)
            .frame(maxWidth: .infinity)
        }
        .opacity(didRevealCeremony ? 1 : 0.01)
        .offset(y: didRevealCeremony ? 0 : 8)
        .animation(.easeOut(duration: 0.55), value: didRevealCeremony)
    }

    private func returnedPageButton(_ page: BookPage) -> some View {
        Button {
            BookFeedback.play(.openPage)
            onNavigateToSurface(keptSurface(for: page))
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Open the old page")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(BookPalette.lampGold)
                    Text(page.promptText.nonEmpty ?? page.type.title)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.86))
                        .lineLimit(2)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.42))
                    .padding(.top, 3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.lampGold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.26), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private struct PocketItem: Identifiable {
        let id: String
        let glyph: String
        let title: String
        let excerpt: String?
        let reason: String?
        let pageShort: String
        let foundAt: Date?
        let mediaAssets: [BookPageMediaAsset]
        let isRealPageFragment: Bool
    }

    private struct BookNoticePatternDisplay: Identifiable {
        let id: String
        let title: String
        let text: String
        let symbol: String
    }

    private var pocketItems: [PocketItem] {
        if let encoded = surface.payload.metadata[PocketKeepsakeArchive.metadataKey] {
            let keepsakes = PocketKeepsakeArchive.decode(encoded)
            if !keepsakes.isEmpty {
                return keepsakes.map { keepsake in
                    PocketItem(
                        id: keepsake.id,
                        glyph: keepsake.glyph,
                        title: keepsake.title?.nonEmpty ?? pocketDisplayObject(keepsake.object),
                        excerpt: keepsake.excerpt?.nonEmpty,
                        reason: keepsake.reason?.nonEmpty,
                        pageShort: keepsake.pageType.shortTitle,
                        foundAt: keepsake.foundAt,
                        mediaAssets: keepsake.mediaAssets ?? [],
                        isRealPageFragment: keepsake.isRealPageFragment
                    )
                }
            }
        }
        let raw = surface.payload.metadata["pocketItems"] ?? ""
        return raw.split(separator: "\n").compactMap { line -> PocketItem? in
            let parts = line.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3, !parts[1].isEmpty else { return nil }
            let date = parts.count >= 4 ? Double(parts[3]).map { Date(timeIntervalSince1970: $0) } : nil
            return PocketItem(
                id: "legacy-\(parts.joined().stableHash)",
                glyph: parts[0],
                title: pocketDisplayObject(parts[1]),
                excerpt: nil,
                reason: nil,
                pageShort: parts[2],
                foundAt: date,
                mediaAssets: [],
                isRealPageFragment: false
            )
        }
    }

    private func pocketDisplayObject(_ object: String) -> String {
        guard let first = object.first else { return object }
        return first.uppercased() + object.dropFirst()
    }

    private var bookPocketOpeningView: some View {
        let items = pocketItems
        let total = Int(surface.payload.metadata["pocketTotal"] ?? "") ?? items.count
        return VStack(alignment: .leading, spacing: 14) {
            ceremonyHeader(
                title: "I turn out my Pocket.",
                subtitle: "Real fragments of the Pages that left: their words, pictures, and origins.",
                symbol: "bag.fill",
                tint: BookPalette.lampGold
            )

            Text("Letting a Page go did not make it vanish without a trace.")
                .font(.system(.callout, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        if let mediaAsset = item.mediaAssets.first {
                            BookOfYouMediaThumbnail(asset: mediaAsset, width: 88, height: 88)
                        } else {
                            Image(systemName: item.glyph.isEmpty ? "doc.text" : item.glyph)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(BookPalette.lampGold)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(BookPalette.lampGold.opacity(0.12)))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.system(.callout, design: .serif, weight: .semibold))
                                .foregroundStyle(BookPalette.ink.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)

                            if let excerpt = item.excerpt {
                                Text("\u{201C}\(excerpt)\u{201D}")
                                    .font(.system(.caption, design: .serif))
                                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if !item.isRealPageFragment {
                                Text("An earlier keepsake. The Page's words were not preserved when this was found.")
                                    .font(.caption2)
                                    .foregroundStyle(BookPalette.ink.opacity(0.48))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let reason = item.reason,
                               reason.caseInsensitiveCompare(item.title) != .orderedSame,
                               reason.caseInsensitiveCompare(item.excerpt ?? "") != .orderedSame {
                                Text("Why it had risen: \(reason)")
                                    .font(.caption2)
                                    .italic()
                                    .foregroundStyle(BookPalette.ink.opacity(0.54))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 6) {
                                Text("from the \(item.pageShort.lowercased()) Page")
                                if let date = item.foundAt {
                                    Text("\u{2022}")
                                    Text(date, style: .date)
                                }
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BookPalette.ink.opacity(0.48))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(BookPalette.page.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
                    }
                }
            }

            if total > items.count {
                Text("\(total - items.count) more wait deeper in the lining.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.55))
            }
        }
    }

    private func ceremonyHeader(title: String, subtitle: String?, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func artifactQuoteCard(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(text)
                .font(.system(.title3, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.lampGold.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.30), lineWidth: 1)
        }
    }

    private func ceremonyFindingCard(title: String, text: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
                Text(text)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        }
    }

    private func ritualCard(_ text: String, title: String = "Tiny ritual") -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "hand.sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.lampGold)
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(BookPalette.lampGold)
            }
            Text(text)
                .font(.system(.title3, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.90))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [BookPalette.lampGold.opacity(0.14), BookPalette.teal.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.30), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func evidenceSlip(_ evidence: BookCeremonyEvidence) -> some View {
        if let pageID = evidence.pageID, let page = keptPage(id: pageID) {
            Button {
                BookFeedback.play(.openPage)
                onNavigateToSurface(keptSurface(for: page))
            } label: {
                evidenceSlipBody(evidence.text, linked: true)
            }
            .buttonStyle(.plain)
        } else {
            evidenceSlipBody(evidence.text, linked: false)
        }
    }

    private func evidenceSlipBody(_ text: String, linked: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: linked ? "text.page.badge.magnifyingglass" : "text.page")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
            Text(text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
            if linked {
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.38))
                    .padding(.top, 4)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(linked ? 0.70 : 0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((linked ? BookPalette.teal : BookPalette.ink).opacity(linked ? 0.22 : 0.10), lineWidth: 1)
        }
    }

    private func bookRememberedProvenanceLine(_ metadata: [String: String]) -> String? {
        var parts: [String] = []
        if let ageLine = metadata["rememberedAgeLine"]?.nonEmpty {
            parts.append(ageLine)
        } else if let date = metadata["rememberedPageDate"].flatMap(rememberedDateLine) {
            parts.append(date)
        }
        if let type = metadata["rememberedPageType"]?.nonEmpty {
            let rememberedType = BookPageType(rawValue: type)
            parts.append(rememberedType.map { "from \($0.title)" } ?? "from an older Page")
        }
        let usedInBraid = metadata["rememberedUsedInBraid"] == "true"
        let inventorySaysUsed = metadata["rememberedPageID"].flatMap { keptPage(id: $0) }?.usedInBookOfYou == true
        if usedInBraid || inventorySaysUsed {
            parts.append("I used it in a Book of You Page before")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func rememberedDateLine(_ rawValue: String) -> String? {
        guard let date = ISO8601DateFormatter().date(from: rawValue) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return "I kept it in \(formatter.string(from: date))"
    }

    private func bookNoticesOpeningLine(_ metadata: [String: String]) -> String {
        if metadata["constellationName"]?.nonEmpty != nil {
            return "I named a repeat."
        }
        if metadata["wagerMoment"] == "opened" {
            return "A sealed margin opens."
        }
        if metadata["wagerMoment"] == "sealed" {
            return "I'm risking a prediction."
        }
        if metadata["connectionNarrative"] == "true" {
            return "I found a connection."
        }
        if metadata["tags"]?.contains("book-learning") == true {
            return "I learned from your choices."
        }
        return "I noticed a repeat."
    }

    private func bookNoticesSubtitle(_ metadata: [String: String]) -> String? {
        if let name = metadata["constellationName"]?.nonEmpty {
            return name
        }
        if let subject = metadata["wagerSubject"]?.nonEmpty {
            return subject
        }
        // The lead signal's line is already shown once, as its own card under
        // "What I found", so the header stays a neutral summary rather
        // than restating it a second time.
        let count = bookNoticesPatternCards(metadata).count
        switch count {
        case 0: return "No finding cards"
        case 1: return "One finding"
        case 2: return "Two findings"
        default: return "Several findings"
        }
    }

    private func bookNoticesOmen(_ metadata: [String: String]) -> (title: String, text: String, symbol: String, tint: Color)? {
        if let name = metadata["constellationName"]?.nonEmpty {
            return (
                "Why I named it",
                "I saw this repeat enough times to call it \(name). If it changes, I will change the name.",
                "sparkles.rectangle.stack",
                BookPalette.lampGold
            )
        }
        if metadata["wagerMoment"] == "sealed", let subject = metadata["wagerSubject"]?.nonEmpty {
            return (
                "What I predicted",
                "I wrote down my prediction about \(subject) and dated it. The seal will show whether I was right.",
                "seal",
                BookPalette.lampGold
            )
        }
        if metadata["wagerMoment"] == "opened" {
            let status = metadata["wagerStatus"] == "right" ? "right" : "wrong"
            return (
                "What happened",
                "The seal opened. I was \(status). I wrote the result down.",
                status == "right" ? "checkmark.seal" : "xmark.seal",
                status == "right" ? BookPalette.teal : BookPalette.lampGold
            )
        }
        let evidenceCount = bookNoticesEvidencePageIDs(metadata).count
        if evidenceCount > 0 {
            return (
                "Why I said this",
                "I used \(evidenceCount) kept Page\(evidenceCount == 1 ? "" : "s") to make this finding.",
                "books.vertical",
                BookPalette.teal
            )
        }
        return nil
    }

    private func bookNoticeAdaptiveActionsView(_ actions: [BookNoticeAdaptiveAction]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("What next")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(BookPalette.lampGold)

            VStack(spacing: 8) {
                ForEach(actions) { action in
                    Button {
                        let message = onBookNoticeAdaptiveAction(surface, action)
                        if !message.isEmpty {
                            bookNoticeFeedbackMessage = message
                        }
                        BookFeedback.play(action == .letPatternRest ? .dismissPage : .openPage)
                        if action.shouldDismissSheet {
                            requestDismiss()
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: action.symbol)
                                .font(.subheadline.weight(.bold))
                            Text(action.label)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                            Spacer(minLength: 6)
                            Image(systemName: action.shouldDismissSheet ? "chevron.right" : "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.ink.opacity(0.44))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(action == .letPatternRest ? BookPalette.ink.opacity(0.58) : BookPalette.lampGold)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.lampGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private func bookNoticeFeedbackCard(_ metadata: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your pencil has the last word", systemImage: "pencil.and.outline")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.teal)

            Text(bookNoticeFeedbackMessage.nonEmpty ?? "Do I keep the underline, lift it, or leave this whole way of reading alone?")
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            if !didCorrectBookNotice {
                VStack(spacing: 8) {
                    bookNoticeFeedbackButton(.trueReading, tint: BookPalette.teal)
                    bookNoticeFeedbackButton(.notQuite, tint: BookPalette.lampGold)
                    bookNoticeFeedbackButton(.doNotReadThisWay, tint: BookPalette.ink.opacity(0.62))
                }
            }

            if metadata["bookOpinionID"]?.nonEmpty != nil && !didContestBookOpinion {
                Divider().overlay(BookPalette.teal.opacity(0.18))
                Text("Or argue with me properly")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.74))
                TextField("Your words, not one of my buttons", text: $bookOpinionArgument, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                Button {
                    let line = bookOpinionArgument.trimmingCharacters(in: .whitespacesAndNewlines)
                    let message = onBookOpinionContested(surface, line, Date())
                    bookNoticeFeedbackMessage = message.nonEmpty ?? "Good. I've put your words beside mine. I'm not conceding yet."
                    didContestBookOpinion = true
                    BookFeedback.play(.sourceRefresh)
                } label: {
                    Label("Put this in the margin", systemImage: "pencil.and.scribble")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.lampGold)
                .disabled(bookOpinionArgument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        }
    }

    private func bookNoticeFeedbackButton(_ choice: BookNoticeFeedbackChoice, tint: Color) -> some View {
        Button {
            let message = onBookNoticeFeedback(surface, choice)
            bookNoticeFeedbackMessage = message.nonEmpty ?? choice.reactionLine
            didCorrectBookNotice = true
            BookFeedback.play(choice == .trueReading ? .keepPage : .sourceRefresh)
        } label: {
            Label(choice.label, systemImage: choice.symbol)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }

    /// How willing the Book is, in its current weather, to spread its receipts
    /// on the desk. Pages composed before the weather existed volunteer them,
    /// which is the behaviour they have always had.
    private func bookEvidencePosture(_ metadata: [String: String]) -> BookTelling.EvidencePosture {
        metadata["bookEvidencePosture"]
            .flatMap(BookTelling.EvidencePosture.init(rawValue:)) ?? .volunteered
    }

    /// The receipts are always reachable — they are why the reader trusts that
    /// the Book is not making this up. A cold Book simply does not hand them
    /// over, and says so in its own words rather than as a disclosure control.
    @ViewBuilder
    private func bookWithheldEvidenceLatch(_ posture: BookTelling.EvidencePosture) -> some View {
        let line = posture == .leftToFind
            ? "The leaves are where I left them."
            : "I have the leaves for this, if you want them."
        Button {
            withAnimation(.easeOut(duration: 0.3)) { didOpenWithheldEvidence = true }
            BookFeedback.play(.sourceRefresh)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "leaf")
                    .font(.caption)
                Text(line)
                    .font(.system(.subheadline, design: .serif).italic())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(BookPalette.teal.opacity(posture == .leftToFind ? 0.72 : 0.9))
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Pages this reading rests on.")
    }

    private func bookNoticesPatternCards(_ metadata: [String: String]) -> [BookNoticePatternDisplay] {
        (metadata["tinyPatternCards"]?.nonEmpty ?? "")
            .split(separator: "\n")
            .enumerated()
            .compactMap { index, line -> BookNoticePatternDisplay? in
                let parts = line.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 2 else { return nil }
                let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let text = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !text.isEmpty else { return nil }
                let symbol = parts.indices.contains(2)
                    ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "sparkle.magnifyingglass"
                    : "sparkle.magnifyingglass"
                return BookNoticePatternDisplay(
                    id: "\(index)-\(title.stableHash)-\(text.stableHash)",
                    title: title,
                    text: text,
                    symbol: symbol
                )
            }
    }

    private func bookNoticeAdaptiveActions(_ metadata: [String: String]) -> [BookNoticeAdaptiveAction] {
        (metadata["adaptiveActions"]?.nonEmpty ?? "")
            .split(separator: "\n")
            .compactMap { BookNoticeAdaptiveAction(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// The evidence slips are the *raw* pages behind the patterns: the kept
    /// lines the Book compared, not a third restatement of the observations
    /// (those live once, in the "What I found" cards). Each slip quotes
    /// an actual kept page and links to it.
    private func bookNoticesEvidenceSlips(_ metadata: [String: String]) -> [BookCeremonyEvidence] {
        var slips: [BookCeremonyEvidence] = []
        if let name = metadata["constellationName"]?.nonEmpty {
            slips.append(BookCeremonyEvidence(id: "name-\(name.stableHash)", text: "Named: \(name)", pageID: nil))
        }
        if let subject = metadata["wagerSubject"]?.nonEmpty {
            slips.append(BookCeremonyEvidence(id: "wager-\(subject.stableHash)", text: "Subject: \(subject)", pageID: nil))
        }
        var seenPageIDs = Set<String>()
        for id in bookNoticesEvidencePageIDs(metadata) {
            guard seenPageIDs.insert(id).inserted, let page = keptPage(id: id) else { continue }
            let excerpt = bookNoticesEvidenceExcerpt(for: page)
            guard !excerpt.isEmpty else { continue }
            slips.append(BookCeremonyEvidence(id: "evidence-\(id.stableHash)", text: excerpt, pageID: id))
            if slips.count >= 4 { break }
        }
        return Array(slips.prefix(4))
    }

    /// A short, whole-word-clipped quote from a kept page for an evidence slip.
    private func bookNoticesEvidenceExcerpt(for page: BookPage, limit: Int = 72) -> String {
        let raw = (page.archivePreviewText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        guard firstLine.count > limit else { return "\u{201C}\(firstLine)\u{201D}" }
        let clipped = firstLine.prefix(limit)
        let lastSpace = clipped.lastIndex(of: " ") ?? clipped.endIndex
        return "\u{201C}\(clipped[..<lastSpace])\u{2026}\u{201D}"
    }

    private func bookNoticesEvidencePageIDs(_ metadata: [String: String]) -> [String] {
        (metadata["evidencePageIDs"]?.nonEmpty ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func keptPage(id: String) -> BookPage? {
        inventoryKeptPages.first { $0.id == id }
    }

    private func keptSurface(for page: BookPage) -> SurfacePage {
        let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = text.isEmpty ? page.promptText : text
        let source = BookPageSourceRegistry.source(id: page.sourceID, fallbackType: page.type)
        let title = page.type.title
        let prompt = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title
            : page.promptText
        return SurfacePage(
            id: "kept-\(page.id)",
            type: page.type,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: 80,
            reason: "I've already got this Page.",
            prompt: prompt,
            detail: "Kept \(page.createdAt.formatted(date: .abbreviated, time: .omitted))",
            payload: BookPagePayload(
                headline: title,
                body: body,
                metadata: [
                    "source": source.id,
                    "keptPageID": page.id,
                    "keptPage": "true",
                    "tags": page.tags.joined(separator: ",")
                ]
            )
        )
    }

    private func playCeremonyOpenCueIfNeeded() {
        guard !didPlayCeremonyOpen else { return }
        guard surface.type == .bookRemembered || surface.type == .bookNotices else { return }
        didPlayCeremonyOpen = true
        didRevealCeremony = true
        BookFeedback.play(surface.type == .bookRemembered ? .braidComplete : .sourceRefresh)
    }

    /// The Book's invitation for this page: a small real-world thing to try.
    /// Only lore pages currently carry one, and it reveals when the page opens.
    private var practiceText: String? {
        guard let practice = surface.payload.metadata["practice"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !practice.isEmpty else { return nil }
        return practice
    }

    // MARK: Center Page: the interactive Rest practice (Wonder Compass, Chapter 10).

    /// The Gear Shifter the page is currently offering. Starts at the one the curator
    /// chose for the hour and the day's state; "Offer me another" walks the menu.
    private var centerGearShifter: CenterGearShifter {
        let menu = CenterGearShifterMenu.all
        guard !menu.isEmpty else { return CenterGearShifterMenu.softGaze }
        let start = surface.payload.metadata["centerGearID"].flatMap { id in
            menu.firstIndex { $0.id == id }
        } ?? 0
        let index = ((start + centerGearOffset) % menu.count + menu.count) % menu.count
        return menu[index]
    }

    /// The two small reliefs the Center Page offers: a do-nothing minute, then
    /// one Gear Shifter toward awake or deeper rest. Neither is a task, and the
    /// labels make no claim about a measured brainwave state.
    private var centerRestPractice: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("The Do-Nothing Minute", systemImage: "circle.dotted")
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(BookPalette.teal)
                Text("Phone face down, out of reach. Don't meditate, don't plan dinner: just let the chair do the holding.")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                BreathingMinuteView(
                    accent: BookPalette.teal,
                    reduceMotion: reduceMotion,
                    completionNote: "If a line turned up in the quiet, keep it below. If not, you got a minute back."
                )
            }

            centerGearShifterCard
        }
        .padding(.top, 4)
    }

    private var centerGearShifterCard: some View {
        let shifter = centerGearShifter
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: shifter.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text(shifter.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(shifter.gear.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            Text(shifter.move)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text(shifter.why)
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    centerGearOffset += 1
                }
            } label: {
                Label("Offer me another", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.gold)
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookPalette.gold.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .id(shifter.id)
        .transition(.opacity)
    }

    private func tryThisCallout(_ practice: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.teal)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Try this")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(BookPalette.teal)
                Text(practice)
                    .font(.system(.callout, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.ink.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookPalette.teal.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.top, 4)
    }

    private var inventoryFae: FaePlayerState {
        _ = inventoryRevision
        return PlayerVault.shared.data.fae ?? FaePlayerState()
    }

    /// The Book's question about a shape it thinks it sees, if tonight is one
    /// of the rare nights it may ask at all.
    ///
    /// Derived here rather than stamped on the page: the vault already holds
    /// the running tale, and the rationing is a property of the reader's whole
    /// history rather than of this page.
    private var taleAsk: BraidTaleAsk.Ask? {
        guard surface.type == .bookOfYou, isKeptReadbackPage, !didAnswerTaleAsk else { return nil }
        let tags = surface.payload.metadata["tags", default: ""]
        let vault = PlayerVault.shared.data
        return BraidTaleAsk.ask(
            for: vault.livingTale,
            lastAskedAt: vault.lastTaleAskAt,
            alreadyAskedTaleIDs: Set(vault.askedTaleIDs ?? []),
            // The braid stamps the night's own shadow state; a reader writing
            // about something hard is not being invited to discuss shape.
            carriesShadow: tags.contains("braid-shadow-tender")
                || tags.contains("braid-shadow-plain")
        )
    }

    @ViewBuilder
    private func taleAskCard(_ ask: BraidTaleAsk.Ask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Something I keep noticing", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)

            Text(taleAskReply.isEmpty ? ask.question : taleAskReply)
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            if taleAskReply.isEmpty {
                HStack(spacing: 10) {
                    // Neither answer is the loud one. A "no" that looks like a
                    // lesser button is not a real offer to be wrong.
                    Button {
                        answerTaleAsk(ask, .keepsHappening)
                    } label: {
                        Text(ask.confirm)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.lampGold)

                    Button {
                        answerTaleAsk(ask, .joiningDots)
                    } label: {
                        Text(ask.refuse)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookPalette.lampGold.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.top, 4)
    }

    private func answerTaleAsk(_ ask: BraidTaleAsk.Ask, _ answer: BraidTaleAsk.Answer) {
        PlayerVault.shared.mutate {
            if let tale = $0.livingTale, tale.id == ask.taleID {
                let updated = BraidTaleAsk.applying(answer, to: tale)
                if updated.isOpen {
                    $0.livingTale = updated
                } else {
                    // A denied tale is not bound. Binding it would surface the
                    // reader's own "no" back to them as a finished story.
                    $0.livingTale = nil
                    $0.lastTaleClosedAt = Date()
                    var refused = $0.refusedTaleShapes ?? []
                    if !refused.contains(tale.shape.rawValue) {
                        refused.append(tale.shape.rawValue)
                    }
                    $0.refusedTaleShapes = refused
                }
            }
            $0.lastTaleAskAt = Date()
            var asked = $0.askedTaleIDs ?? []
            if !asked.contains(ask.taleID) { asked.append(ask.taleID) }
            $0.askedTaleIDs = Array(asked.suffix(40))
        }
        didAnswerTaleAsk = true
        taleAskReply = answer == .keepsHappening
            ? "Then I will keep watching it, and I will not say what it means."
            : "Good. I have put it down and I will not pick it up again."
        BookFeedback.play(.keepPage)
    }

    private var braidFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Teach me", systemImage: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.teal)

            Text(braidFeedbackMessage.isEmpty ? "Tell me whether this page found you." : braidFeedbackMessage)
                .font(.footnote)
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            if !didMarkBraidMissed {
                HStack(spacing: 10) {
                    Button {
                        guard let keptPageID else { return }
                        let message = onLoveBraid(keptPageID)
                        braidFeedbackMessage = message.isEmpty ? "I marked this as a true page." : message
                        BookFeedback.play(.keepPage)
                    } label: {
                        Label("I loved this one", systemImage: "heart")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    // The prominent style used to sit on "This missed me", so
                    // the loudest thing on a finished page was the way to
                    // reject it. The Book may ask how it did; it should not
                    // lead with the assumption that it failed.
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.lampGold)

                    Button {
                        guard let keptPageID else { return }
                        // The page is tagged immediately for instant feedback;
                        // the Book then reads it with the local brain to learn
                        // for the next braid, and reveals the rewrite offer.
                        let lesson = onBraidMissedMe(keptPageID)
                        braidFeedbackMessage = lesson.isEmpty
                            ? "I'm reading this again to learn how your days want to be told."
                            : lesson
                        didMarkBraidMissed = true
                        isImprovingBraid = true
                        BookFeedback.play(.braidStart)
                        Task {
                            let learned = await onImproveNextBraid(keptPageID)
                            isImprovingBraid = false
                            if !learned.isEmpty { braidFeedbackMessage = learned }
                        }
                    } label: {
                        Label("This missed me", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                }
                .disabled(!braidFeedbackMessage.isEmpty)
            } else if !didRewriteBraid {
                // The reader said it missed; offer to let the Book try again.
                Button {
                    guard let keptPageID, !isRewritingBraid else { return }
                    isRewritingBraid = true
                    braidFeedbackMessage = "I'm rewriting this page closer to your day…"
                    BookFeedback.play(.braidStart)
                    Task {
                        let result = await onRewriteBraid(keptPageID)
                        isRewritingBraid = false
                        didRewriteBraid = true
                        if !result.isEmpty { braidFeedbackMessage = result }
                    }
                } label: {
                    Label("Rewrite this braid", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(isRewritingBraid || isImprovingBraid)
            }

            if isImprovingBraid || isRewritingBraid {
                scribeWorkCard(isRewritingBraid ? "braid-rewrite" : "braid-taste-note")
            }
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
        }
    }

    private var inventoryOwnedListings: [BookShopListing] {
        _ = inventoryRevision
        let owned = Set(PlayerVault.shared.data.ownedPacks ?? [])
        return BookShopCatalog.listings.filter { owned.contains($0.packID) }
    }

    private var inventoryPageView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(surface.payload.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !inventoryMessage.isEmpty {
                Label(inventoryMessage, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }

            inventorySectionTitle("Fae gifts", symbol: "hands.sparkles")
            if inventoryFae.gifts.isEmpty {
                Text("This shelf is empty. The Fae give first; I'd advise reading the terms afterward.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
            } else {
                ForEach(inventoryFae.gifts.sorted { $0.acquiredAt > $1.acquiredAt }) { gift in
                    inventoryGiftCard(gift)
                }
            }

            inventorySectionTitle("Installed folios", symbol: "books.vertical.fill")
            if inventoryOwnedListings.isEmpty {
                Text("No purchased folios are bound to this Book yet.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
            } else {
                ForEach(inventoryOwnedListings) { listing in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(listing.title, systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text("ACTIVE")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(BookPalette.teal)
                        }
                        Text(listing.contents)
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Installed automatically. Its Pages, stations, art, and story forms join their normal rotations.")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BookPalette.teal.opacity(0.82))
                    }
                    .inventoryObjectSurface(accent: BookPalette.teal)
                }
            }

            inventorySectionTitle("Story objects", symbol: "key.horizontal.fill")
            if inventoryStoryObjects.isEmpty {
                Text("Objects you create in the Cast will live here too. They are not consumables; they are participants in the story.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
            } else {
                ForEach(inventoryStoryObjects.sorted { $0.updatedAt > $1.updatedAt }) { object in
                    let glow = max(0, min(100, object.baseBelief + (inventoryObjectBeliefOffsets[object.id] ?? 0)))
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label(object.name, systemImage: "key.horizontal.fill")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text(BookMechanicPresentation.glow(glow))
                                .font(.caption2.weight(.black))
                                .foregroundStyle(BookPalette.lampGold)
                        }
                        if !object.meaning.isEmpty {
                            Text(object.meaning)
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(BookPalette.ink.opacity(0.82))
                        }
                        if !object.description.isEmpty {
                            Text(object.description)
                                .font(.caption)
                                .foregroundStyle(BookPalette.ink.opacity(0.62))
                        }
                        Text("An enduring member of the Cast. When it brightens, the Book remembers to make room for it.")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BookPalette.teal.opacity(0.82))
                    }
                    .inventoryObjectSurface(accent: BookPalette.violet)
                }
            }
        }
    }

    private func inventorySectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline.weight(.bold))
            .foregroundStyle(BookPalette.ink)
    }

    private func inventoryGiftCard(_ gift: FaeGift) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Label(gift.name, systemImage: gift.faeKind.symbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                Spacer()
                Text(inventoryGiftState(gift))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BookPalette.teal)
            }
            Text(gift.descriptionText)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Text(gift.effect.effectLine)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            inventoryGiftControl(gift)
        }
        .inventoryObjectSurface(accent: BookPalette.lampGold)
    }

    @ViewBuilder
    private func inventoryGiftControl(_ gift: FaeGift) -> some View {
        switch gift.effect {
            case .quieting:
                if gift.isActive, let expiresAt = gift.expiresAt {
                    Label(expiresAt > Date() ? "Quieting is active" : "The quiet has lifted", systemImage: "moon.zzz.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(BookPalette.teal)
                } else {
                    inventoryActionButton("Invoke until tomorrow", symbol: "moon.zzz") { useInventoryGift(gift.id, target: nil) }
                }
            case .callingCard:
                if gift.isActive {
                    inventoryActionButton("Present at the Goblin Market", symbol: "storefront") { onOpenInventoryMarket() }
                } else {
                    Text("Spent. The Goblins have punched a neat, insulting hole through it.")
                        .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.55))
                }
            case .loosePage:
                Text(inventoryLoosePageText(gift))
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(BookPalette.paper.opacity(0.62), in: RoundedRectangle(cornerRadius: 6))
                inventoryActionButton("Turn the loose page", symbol: "book.pages") {
                    loosePageTurns[gift.id, default: 0] += 1
                    inventoryRevision += 1
                    inventoryMessage = "The loose page changed while you were looking at it. Naturally."
                }
            case .unspokenPen:
                if !inventoryUnspokenSentence.isEmpty {
                    Text(inventoryUnspokenSentence)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(BookPalette.paper.opacity(0.62), in: RoundedRectangle(cornerRadius: 6))
                }
                inventoryActionButton(
                    isWritingUnspokenSentence ? "Gemma is uncapping it" : "Write an unspoken sentence",
                    symbol: "pencil.and.scribble"
                ) {
                    writeUnspokenSentence(with: gift)
                }
                .disabled(isWritingUnspokenSentence)
                if isWritingUnspokenSentence {
                    scribeWorkCard("unspoken-pen")
                }
            case .reshelving:
                if let target = gift.boundSourceID,
                   let source = BookPageSourceRegistry.sources.first(where: { $0.id == target }) {
                    Label("Calling back: \(source.title)", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(BookPalette.teal)
                } else {
                    Menu {
                        ForEach(BookPageSourceRegistry.sources.filter { FaeGiftEffects.reshelfEligible.contains($0.type) }) { source in
                            Button(source.title) { useInventoryGift(gift.id, target: source.id) }
                        }
                    } label: {
                        Label("Choose a Page to call back", systemImage: "books.vertical")
                    }
                    .buttonStyle(.bordered).tint(BookPalette.teal)
                }
            case .longMemory:
                if let target = gift.boundSourceID,
                   let page = inventoryKeptPages.first(where: { $0.id == target }) {
                    Label("Remembering: \(page.promptText)", systemImage: "bookmark.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(BookPalette.teal)
                } else if inventoryKeptPages.isEmpty {
                    Text("Keep a Page first. The quill needs something true enough to refuse forgetting.")
                        .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.58))
                } else {
                    Menu {
                        ForEach(inventoryKeptPages.prefix(30)) { page in
                            Button(page.promptText) { useInventoryGift(gift.id, target: page.id) }
                        }
                    } label: {
                        Label("Choose a Page to remember", systemImage: "bookmark")
                    }
                    .buttonStyle(.bordered).tint(BookPalette.teal)
                }
        }
    }

    private func inventoryActionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: symbol) }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
    }

    private func useInventoryGift(_ giftID: String, target: String?) {
        onUseInventoryGift(giftID, target)
        inventoryRevision += 1
        inventoryMessage = "The Inventory has amended itself in fresh ink."
        BookFeedback.play(.select)
    }

    private func writeUnspokenSentence(with gift: FaeGift) {
        guard !isWritingUnspokenSentence else { return }
        isWritingUnspokenSentence = true
        inventoryMessage = "Gemma is trying to write one sentence no one has said before."
        Task {
            let sentence = await unspokenPenSentence()
            await MainActor.run {
                isWritingUnspokenSentence = false
                inventoryUnspokenSentence = sentence
                inventoryMessage = "The Unspoken Pen wrote: \(sentence)"
                useInventoryGift(gift.id, target: nil)
            }
        }
    }

    private func unspokenPenSentence() async -> String {
        let prompt = """
        Write exactly one original English sentence that is very unlikely to have ever been spoken before.
        It should still make sense: concrete, grammatically complete, and meaningful rather than random.
        Do not explain the sentence. Do not use quotation marks. Do not write more than one sentence.
        """
        let raw = await LocalBrainProse.write(
            prompt: prompt,
            instructions: "Exactly one coherent sentence, no heading, no commentary, no quotation marks.",
            maxTokens: 80,
            sourceID: "unspoken-pen",
            tags: ["inventory", "goblin-market", "unspoken-pen"]
        )
        return cleanUnspokenSentence(raw)
    }

    private func cleanUnspokenSentence(_ raw: String?) -> String {
        var sentence = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        sentence = sentence.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
        if let firstTerminator = sentence.firstIndex(where: { ".!?".contains($0) }) {
            sentence = String(sentence[...firstTerminator])
        }
        if sentence.isEmpty {
            sentence = "The brass moon folded its receipt into the teacup and remembered why the windows smelled blue."
        }
        if !".!?".contains(sentence.last ?? ".") {
            sentence += "."
        }
        return sentence
    }

    private func inventoryGiftState(_ gift: FaeGift) -> String {
        if gift.effect == .callingCard, !gift.isActive { return "SPENT" }
        if (gift.effect == .reshelving || gift.effect == .longMemory), gift.boundSourceID?.isEmpty != false { return "READY" }
        if gift.isActive { return gift.effect == .loosePage ? "COLLECTED" : "ACTIVE" }
        return "READY"
    }

    private func inventoryLoosePageText(_ gift: FaeGift) -> String {
        guard !LoosePageReader.fragments.isEmpty else { return "" }
        let turn = loosePageTurns[gift.id, default: 0]
        let index = abs("\(gift.id)-inventory-\(turn)".stableHash) % LoosePageReader.fragments.count
        return LoosePageReader.fragments[index]
    }

    private var pendingLetterPageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Letter waiting", systemImage: "envelope.open")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)

            Text("A sealed letter from \(surface.payload.metadata["senderName"] ?? "someone") is waiting in the margins. Open it to let the public stacks, old memories, and today's page resolve into something you can read.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isLocalBrainWorking {
                Label("Opening now", systemImage: "wand.and.stars")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            } else {
                Button {
                    BookFeedback.play(.sourceRefresh)
                    onGenerateLetter(surface)
                } label: {
                    Label(
                        "Open and read: the letter will borrow some Belief",
                        systemImage: "envelope.open"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(readerBeliefScore < BeliefGenerationKind.letter.cost)

                if readerBeliefScore < BeliefGenerationKind.letter.cost {
                    Text("The letter will wait until the margins warm.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                }
            }
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
        }
    }

    private var pendingNotePageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Folded note", systemImage: "note.text")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)

            // `waitingLine` is prose the Page shows while the note is still
            // folded. It used to live under `placeholder`, which now feeds the
            // writing box and would have put a status line where an
            // instruction belongs.
            Text(surface.payload.metadata["waitingLine"]?.nonEmpty
                 ?? surface.payload.metadata["placeholder"]?.nonEmpty
                 ?? "\(letterSenderName.capitalized) just slipped you a note.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isLocalBrainWorking {
                Label("Unfolding now", systemImage: "wand.and.stars")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            } else {
                Button {
                    BookFeedback.play(.sourceRefresh)
                    onGenerateNote(surface)
                } label: {
                    Label(
                        "Unfold and read: the note will borrow a little Belief",
                        systemImage: "note.text"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(readerBeliefScore < BeliefGenerationKind.note.cost)

                if readerBeliefScore < BeliefGenerationKind.note.cost {
                    Text("The folded note will wait until the margins warm.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                }
            }
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
        }
    }

    private var studentNoteView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                CharacterPortraitView(name: letterSenderName.capitalized, size: 56, customAsset: noteSenderCustomAsset)
                VStack(alignment: .leading, spacing: 3) {
                    Text(letterSenderName.capitalized)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(BookPalette.ink)
                    Text(surface.payload.metadata["deliveryContext"]?.nonEmpty ?? "Folded in passing")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Text(noteProseText ?? "")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            BookPalette.paper.opacity(0.96),
                            BookPalette.page.opacity(0.88),
                            BookPalette.lampGold.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "paperclip")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.38))
                        .rotationEffect(.degrees(10))
                        .padding(10)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }

            HStack(spacing: 10) {
                Button {
                    pressNoteShareCard()
                } label: {
                    Label(isPressingNoteShareCard ? "Pressing..." : "Press share card", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPressingNoteShareCard)

                if let noteShareURL {
                    ShareLink(item: noteShareURL) {
                        Label("Share", systemImage: "square.and.arrow.up.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                }
            }
        }
        .padding(14)
        .background(BookPalette.paper.opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
        }
    }

    private var noteDisplaySurface: SurfacePage {
        guard surface.type == .note,
              let noteText = noteProseText,
              noteText != surface.payload.body else {
            return surface
        }
        var metadata = surface.payload.metadata
        metadata["noteProse"] = noteText
        return SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: BookPagePayload(
                headline: surface.payload.headline,
                body: noteText,
                metadata: metadata
            )
        )
    }

    @ViewBuilder
    private var letterReplySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(BookPalette.ink.opacity(0.12))

            if didSealReply {
                HStack(spacing: 10) {
                    Image("MarginaliaSeal")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .scaleEffect(sealStamp ? 1 : 1.4)
                        .opacity(sealStamp ? 1 : 0)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sealed & sent")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                        Text("Your reply is folded into the margins. \(letterSenderName.capitalized) will carry it.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                LivingTextEditor(
                    title: "Write back to \(letterSenderName.capitalized)",
                    placeholder: "A line back through the margins…",
                    text: $letterReply,
                    minHeight: 120,
                    builderPack: SentenceBuilderPackRegistry.composedCore(readerLexicon: readerLexicon, shadowWonderActive: isShadowWonderActive),
                    builderContext: makeSentenceBuilderContext(
                        intent: .letterReply,
                        sourceText: surface.payload.metadata["letterProse"] ?? surface.payload.body,
                        recipientName: letterSenderName
                    )
                )

                Button {
                    sealAndSendReply()
                } label: {
                    Label("Seal & send your reply", systemImage: "seal")
                        .font(.callout.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.lampGold)
                .disabled(letterReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var noteReplySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(BookPalette.ink.opacity(0.12))

            if didSealReply {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                        .frame(width: 42, height: 42)
                        .scaleEffect(sealStamp ? 1 : 1.35)
                        .opacity(sealStamp ? 1 : 0)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slipped back")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                        Text("\(letterSenderName.capitalized) will remember the shape of your reply.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                LivingTextEditor(
                    title: "Slip a note back to \(letterSenderName.capitalized)",
                    placeholder: "Fold one quick line back...",
                    text: $letterReply,
                    minHeight: 96,
                    builderPack: SentenceBuilderPackRegistry.composedCore(readerLexicon: readerLexicon, shadowWonderActive: isShadowWonderActive),
                    builderContext: makeSentenceBuilderContext(
                        intent: .letterReply,
                        sourceText: surface.payload.metadata["noteProse"] ?? surface.payload.body,
                        recipientName: letterSenderName
                    )
                )

                Button {
                    slipBackNoteReply()
                } label: {
                    Label("Fold & slip back", systemImage: "paperplane")
                        .font(.callout.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.lampGold)
                .disabled(letterReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func pressNoteShareCard() {
        guard !isPressingNoteShareCard else { return }
        isPressingNoteShareCard = true
        defer { isPressingNoteShareCard = false }
        noteShareURL = StudentNoteShareCardRenderer.render(surface: noteDisplaySurface)
        BookFeedback.pressTick()
    }

    private func slipBackNoteReply() {
        let reply = letterReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { return }
        BookFeedback.chapterBinding()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            didSealReply = true
            sealStamp = true
        }

        var metadata = surface.payload.metadata
        let noteText = noteProseText ?? surface.payload.body
        metadata["noteProse"] = noteText
        metadata["playerReply"] = reply
        metadata["noteReplied"] = "true"
        let sealed = SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: BookPagePayload(
                headline: surface.payload.headline,
                body: noteText,
                metadata: metadata
            )
        )
        let tags = preparedTags(for: sealed) + ["reply", "student-note"]
        DispatchQueue.main.async {
            onSave(sealed, noteText, tags, [])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            requestDismiss()
        }
    }

    /// The distinct, ceremonial reply gesture: stamps a wax seal, binds the
    /// letter with the reply attached (its own keep), and dismisses. The plain
    /// toolbar "Keep" remains for letters the reader chooses to leave unanswered.
    private func sealAndSendReply() {
        let reply = letterReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { return }
        BookFeedback.chapterBinding()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            didSealReply = true
            sealStamp = true
        }

        var metadata = surface.payload.metadata
        metadata["playerReply"] = reply
        metadata["letterSealed"] = "true"
        let sealed = SurfacePage(
            id: surface.id,
            type: surface.type,
            sourceID: surface.sourceID,
            intent: surface.intent,
            renderStyle: surface.renderStyle,
            score: surface.score,
            reason: surface.reason,
            prompt: surface.prompt,
            detail: surface.detail,
            payload: BookPagePayload(
                headline: surface.payload.headline,
                body: surface.payload.body,
                metadata: metadata
            )
        )
        let input = preparedInput
        let tags = preparedTags(for: sealed) + ["reply", "pen-pal"]
        DispatchQueue.main.async {
            onSave(sealed, input, tags, [])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            requestDismiss()
        }
    }

    @ViewBuilder

    private var compassPracticeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isStandalonePlayfulMissionPage {
                standalonePlayfulMissionCard
            } else {
                if let step = surface.payload.metadata["compassStep"], step == "run" {
                    if isPreparedCompassRunStartPage {
                        compassRunReadyView
                    } else {
                        compassRunConstraintForm
                    }
                } else {
                    compassStepSummary
                }

                Text(surface.payload.body)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private var standalonePlayfulMissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.subheadline.weight(.bold))
                Text("YOUR ONE MISSION")
                    .font(.caption.weight(.black))
                    .tracking(0.9)
            }
            .foregroundStyle(BookPalette.teal)

            Text(surface.payload.metadata["mission"]?.nonEmpty ?? surface.detail)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let hostLead = surface.payload.metadata["missionHostLead"]?.nonEmpty {
                Text(hostLead)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let continuity = surface.payload.metadata["missionContinuityLine"]?.nonEmpty {
                Label(continuity, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.violet.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(
                "Do it away from the screen, then come back with what you found. Leave it entirely if it is unsafe, unwelcome, inaccessible, or simply not yours.",
                systemImage: "eye"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(BookPalette.ink.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(BookPalette.ink.opacity(0.12))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(standalonePlayfulMissionProofLabel)
                    .font(.caption.weight(.black))
                    .tracking(0.9)
                    .foregroundStyle(BookPalette.lampGold)

                Text(standalonePlayfulMissionProof)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    standalonePlayfulMissionAside,
                    systemImage: allowsCompassPhotoProof ? "camera.macro" : "pencil.and.scribble"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            }

            LivingTextEditor(
                title: allowsCompassPhotoProof ? "Your sentence proof (or add a photo below)" : "Your sentence proof",
                placeholder: standalonePlayfulMissionProof,
                text: $text,
                minHeight: 112,
                builderPack: SentenceBuilderPackRegistry.composedCore(
                    readerLexicon: readerLexicon,
                    shadowWonderActive: isShadowWonderActive
                ),
                builderContext: sentenceBuilderContext
            )
        }
    }

    @ViewBuilder
    private var pennySentenceMasteryView: some View {
        if let lesson = activePennySentenceLesson {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image("LabyrinthCharacterPennyBlackletter")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Penny Blackletter")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BookPalette.ink)
                        Text("A sentence lesson from Chapter 9")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.ink.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ceremonyFindingCard(
                    title: lesson.title,
                    text: lesson.pennyBriefing,
                    symbol: lesson.symbolName,
                    tint: BookPalette.lampGold
                )

                compassRail("Practice", lesson.practicePrompt)
                compassRail("Penny's standard", lesson.masteryHint)

                LivingTextEditor(
                    title: "Filed sentence",
                    placeholder: lesson.placeholder,
                    text: $text,
                    minHeight: 110,
                    builderPack: pennySentenceMasteryPack,
                    builderContext: makeSentenceBuilderContext(
                        intent: .missionProof,
                        prompt: lesson.practicePrompt,
                        sourceText: lesson.pennyBriefing
                    )
                )

                pennySentenceMasteryMeter(lesson: lesson)
            }
        }
    }

    private var pennySentenceMasteryPack: SentenceBuilderPack {
        SentenceBuilderPackRegistry.composedChapterNineMastery(
            readerLexicon: readerLexicon,
            shadowWonderActive: isShadowWonderActive
        )
    }

    private var pennySentenceMasteryAnalysis: SentenceBuilderAnalysis {
        SentenceBuilderEngine(pack: pennySentenceMasteryPack).analyze(text)
    }

    private func pennySentenceMasteryMeter(lesson: PennySentenceMasteryLesson) -> some View {
        let analysis = pennySentenceMasteryAnalysis
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let status: String
        if trimmed.isEmpty {
            status = "No evidence filed yet."
        } else if lesson == .crossedWires, !analysis.hasCrossedSense {
            status = "Penny is waiting for one crossed sense."
        } else if lesson == .worldTakesVerb, !analysis.hasWorldActor {
            status = "Penny is waiting for the world to take a verb."
        } else if analysis.isVivid {
            status = "Filed as admissible. Future-you may enter here."
        } else if analysis.canStandAsComplete {
            status = "This can stand. One sharper detail would make it harder to forget."
        } else {
            status = "Penny needs one more physical hook."
        }

        return VStack(alignment: .leading, spacing: 10) {
            Label("Mastery check", systemImage: analysis.isVivid ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
                .font(.caption.weight(.bold))
                .foregroundStyle(analysis.isVivid ? BookPalette.teal : BookPalette.lampGold)

            Text(status)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(analysis.craftMarks) { mark in
                    Label(mark.title, systemImage: mark.isPresent ? "checkmark.circle.fill" : "circle")
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 6)
                        .foregroundStyle(mark.isPresent ? BookPalette.teal : BookPalette.ink.opacity(0.48))
                        .background((mark.isPresent ? BookPalette.teal : BookPalette.paper).opacity(mark.isPresent ? 0.13 : 0.74), in: Capsule())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((analysis.isVivid ? BookPalette.teal : BookPalette.lampGold).opacity(0.24), lineWidth: 1)
        }
    }

    private var compassRunConstraintForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label(
                    compassConstraintStep.title.uppercased(),
                    systemImage: compassConstraintStep.symbol
                )
                .font(.caption.weight(.black))
                .tracking(0.7)
                .foregroundStyle(BookPalette.teal)

                Text(compassConstraintStep.question)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(compassConstraintStep.guidance)
                    .font(.callout)
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                switch compassConstraintStep {
                case .location:
                    compassPlaceMenu
                case .time:
                    compassMenuField("Time limit", options: compassTimeOptions, selection: $compassTimeLimit)
                case .energy:
                    compassMenuField("Energy", options: compassEnergyOptions, selection: $compassEnergy)
                case .companions:
                    compassMenuField("Who is with me", options: compassCompanionOptions, selection: $compassCompanions)
                case .budget:
                    compassMenuField("Budget", options: compassBudgetOptions, selection: $compassBudget)
                case .considerations:
                    compassConsiderationPicker
                }
            }
            .id(compassConstraintStep)
            .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))

            HStack(spacing: 10) {
                if let previous = compassConstraintStep.previous {
                    Button {
                        BookFeedback.play(.select)
                        withAnimation(BookMotion.reveal(reduceMotion)) {
                            compassConstraintStep = previous
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.ink.opacity(0.72))
                }

                if let next = compassConstraintStep.next {
                    Button {
                        BookFeedback.play(.select)
                        withAnimation(BookMotion.reveal(reduceMotion)) {
                            compassConstraintStep = next
                        }
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(!canAdvanceCompassConstraintStep)
                } else {
                    Button {
                        BookFeedback.play(.braidStart)
                        Task { await generateAndSaveCompassRun() }
                    } label: {
                        Label(isGeneratingCompassRun ? "Drawing the route..." : "Draw My Compass Run", systemImage: "safari")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(!canSubmitCompassRun)
                }
            }

            if compassConstraintStep == .considerations {
                DisclosureGroup(isExpanded: $isWritingManualCompassRun) {
                    manualCompassRunForm
                        .padding(.top, 8)
                } label: {
                    Label("Write my own Compass Run", systemImage: "square.and.pencil")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                }
                .padding(12)
                .background(BookPalette.paper.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
            }

            if isGeneratingCompassRun {
                scribeWorkCard(
                    "wonder-compass",
                    quip: "The needle is taking every constraint seriously."
                )
            }
        }
        .onAppear {
            seedCompassRunControlsIfNeeded()
        }
        // onAppear does not fire again when the sheet stays mounted and only the
        // surface changes, which is exactly how a second run arrives.
        .onChange(of: surface.id) { _, _ in
            seedCompassRunControlsIfNeeded()
        }
    }

    private var compassRunReadyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("YOUR ROUTE IS DRAWN", systemImage: "safari.fill")
                .font(.caption.weight(.black))
                .tracking(0.9)
                .foregroundStyle(BookPalette.teal)

            Text("Read the whole little route once. Then begin at North and let each direction hand you to the next.")
                .font(.callout.weight(.semibold))
                .foregroundStyle(openPageSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            compassRail("North · Notice", surface.payload.metadata["spark"])

            VStack(alignment: .leading, spacing: 8) {
                compassRail("East · Destination", surface.payload.metadata["destination"])
                compassRail("East · Delight", surface.payload.metadata["delight"])
                compassRail("East · Definition", surface.payload.metadata["definition"])
            }

            compassRail("South · Sense", surface.payload.metadata["mission"])
            compassRail("West · Write", surface.payload.metadata["souvenirPrompt"])
            compassRail("Center · Rest", surface.payload.metadata["restPrompt"])

            Button {
                BookFeedback.play(.openPage)
                onNavigateToSurface(compassStepSurface(from: surface, step: .notice))
            } label: {
                Label("Begin at North: Notice", systemImage: "arrow.up.circle.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
        }
    }

    private var manualCompassRunForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            compassManualTextField(
                "North goal",
                text: $manualCompassSpark,
                placeholder: "I wonder what this place wants me to notice?"
            )
            compassManualTextField(
                "East destination",
                text: $manualCompassDestination,
                placeholder: "The kitchen window, the harbor edge, the nearest threshold..."
            )
            compassManualTextField(
                "East delight",
                text: $manualCompassDelight,
                placeholder: "A drink, a song, a warm layer, a tiny treat..."
            )
            compassManualTextField(
                "East definition",
                text: $manualCompassDefinition,
                placeholder: "Done after 10 minutes, one answer, one photo, one lap..."
            )
            compassManualTextField(
                "South body mission",
                text: $manualCompassMission,
                placeholder: "At the destination or start, notice one sound, one texture, one color..."
            )
            compassManualTextField(
                "West sentence prompt",
                text: $manualCompassSouvenirPrompt,
                placeholder: "Write the best sensory moment from the run in one sentence."
            )
            compassManualTextField(
                "Center rest",
                text: $manualCompassRestPrompt,
                placeholder: "Put the phone down for 60 seconds and let the run land."
            )

            Button {
                BookFeedback.play(.braidStart)
                saveManualCompassRun()
            } label: {
                Label("Start My Compass Run", systemImage: "arrow.right.circle")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.lampGold)
            .disabled(!canSubmitManualCompassRun)
        }
    }

    private var compassStepSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            let step = surface.payload.metadata["compassStep"]
            if step == "notice" {
                compassRail("Spark", surface.payload.metadata["spark"])
            } else if step == "embark" {
                compassRail("Goal", surface.payload.metadata["spark"])
                compassRail("Destination", surface.payload.metadata["destination"])
                compassRail("Delight", surface.payload.metadata["delight"])
                compassRail("Definition", surface.payload.metadata["definition"])
            } else if step == "sense" {
                compassRail("Goal", surface.payload.metadata["spark"])
                compassRail("Destination", surface.payload.metadata["destination"])
                compassRail("Body Mission", surface.payload.metadata["mission"])
            } else if step == "write" {
                compassRail("Goal", surface.payload.metadata["spark"])
                compassRail("Best Sensory Moment", surface.payload.metadata["souvenirPrompt"])
                Text("Write the best sensory moment from the run in one sentence. When it feels specific enough to keep, continue to Center: Rest.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            } else if step == "rest" {
                compassRail("Goal", surface.payload.metadata["spark"])
                compassRail("Rest", surface.payload.metadata["restPrompt"])
            }

            if let currentStep = currentCompassStep {
                Button {
                    BookFeedback.play(.openPage)
                    keepCompassStepAndAdvance()
                } label: {
                    Label(compassStepActionTitle(for: currentStep), systemImage: compassStepActionSymbol(for: currentStep))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(!canKeep)
            }
        }
    }

    private var playfulMissionGeneratorControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                BookFeedback.play(.braidStart)
                isGeneratingPlayfulMission = true
                playfulMissionGenerationMessage = "I am inventing one fresh sensory errand."
                onGeneratePlayfulMission(surface)
            } label: {
                Label(isGeneratingPlayfulMission ? "I am plotting..." : "Give me another small trouble", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
            .disabled(isGeneratingPlayfulMission || isLocalBrainWorking)

            if isGeneratingPlayfulMission {
                scribeWorkCard("wonder-compass-playful-mission")
            }

            Text("I will keep it tiny, concrete, sensory, and small enough to finish before three minutes escape.")
                .font(.caption)
                .foregroundStyle(openPageSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private var compassPlaceMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            compassMenuButton(
                title: "Location",
                selectionTitle: selectedCompassPlaceContext.title,
                symbol: compassPlaceSymbol(for: selectedCompassPlaceContext)
            ) {
                ForEach(compassPlaceOptions) { option in
                    Button {
                        BookFeedback.play(.select)
                        compassPlaceContextID = option.id
                        if option.id != CompassPlaceContext.current.rawValue {
                            compassLocation = option.value
                            compassCurrentPlaceMessage = ""
                        }
                    } label: {
                        Label(option.title, systemImage: option.symbol)
                    }
                }
            }

            if selectedCompassPlaceContext == .current {
                Button {
                    BookFeedback.play(.sourceRefresh)
                    Task { await resolveCompassCurrentPlace() }
                } label: {
                    Label(isResolvingCompassPlace ? "Reading place..." : "Use current GPS place", systemImage: "location.magnifyingglass")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                .disabled(isResolvingCompassPlace)
            }

            if !compassCurrentPlaceMessage.isEmpty {
                Text(compassCurrentPlaceMessage)
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if canRememberCompassCurrentPlace {
                Menu {
                    ForEach(compassMemoryOptions, id: \.rawValue) { context in
                        Button {
                            rememberCompassCurrentPlace(as: context)
                        } label: {
                            Label(context.title, systemImage: compassPlaceSymbol(for: context))
                        }
                    }
                } label: {
                    Label("Remember this area", systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.lampGold)
            }
        }
    }

    private func compassMenuField(_ title: String, options: [CompassChoiceOption], selection: Binding<String>) -> some View {
        let selected = selectedCompassOption(in: options, value: selection.wrappedValue)
        return compassMenuButton(
            title: title,
            selectionTitle: selected?.title ?? selection.wrappedValue.nonEmpty ?? "Choose",
            symbol: selected?.symbol ?? "chevron.up.chevron.down"
        ) {
            ForEach(options) { option in
                Button {
                    BookFeedback.play(.select)
                    selection.wrappedValue = option.value
                } label: {
                    Label(option.title, systemImage: option.symbol)
                }
            }
        }
    }

    private func compassMenuButton<Items: View>(
        title: String,
        selectionTitle: String,
        symbol: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            Menu {
                items()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .frame(width: 20)
                    Text(selectionTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(BookPalette.ink)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
            }
        }
    }

    private func compassManualTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            TextField(placeholder, text: text, axis: .vertical)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .inkFeedback(text: text.wrappedValue)
                .dictationInput(text: text)
                .padding(10)
                .background(BookPalette.page.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var compassConsiderationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONSIDERATIONS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(compassConsiderationOptions) { option in
                    let selected = compassConsiderationIDs.contains(option.id)
                    Button {
                        BookFeedback.play(.select)
                        if selected {
                            compassConsiderationIDs.remove(option.id)
                        } else {
                            compassConsiderationIDs.insert(option.id)
                        }
                    } label: {
                        Label(option.title, systemImage: selected ? "checkmark.circle.fill" : option.symbol)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 8)
                            .background(
                                selected ? BookPalette.teal.opacity(0.18) : BookPalette.paper.opacity(0.74),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selected ? BookPalette.teal.opacity(0.42) : BookPalette.ink.opacity(0.10), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BookPalette.ink)
                }
            }
        }
    }

    private var selectedCompassPlaceContext: CompassPlaceContext {
        CompassPlaceContext(rawValue: compassPlaceContextID) ?? .current
    }

    private var canRememberCompassCurrentPlace: Bool {
        compassCurrentLatitude != nil &&
            compassCurrentLongitude != nil &&
            !isResolvingCompassPlace
    }

    private var currentNearbyPlacesText: String {
        compassNearbyPlacesOverride.nonEmpty ?? surface.payload.metadata["nearbyPlaces"] ?? ""
    }

    private var selectedCompassConsiderations: String {
        let selected = compassConsiderationOptions
            .filter { compassConsiderationIDs.contains($0.id) }
            .map(\.value)
        return selected.isEmpty ? "no special constraints known" : selected.joined(separator: ", ")
    }

    private func selectedCompassOption(in options: [CompassChoiceOption], value: String) -> CompassChoiceOption? {
        options.first { $0.value == value || $0.id == value }
    }

    private func compassPlaceSymbol(for context: CompassPlaceContext) -> String {
        switch context {
        case .current: return "location.magnifyingglass"
        case .home: return "house"
        case .work: return "briefcase"
        case .cafe: return "cup.and.saucer"
        case .harbor: return "sailboat"
        case .park: return "tree"
        case .store: return "basket"
        case .library: return "books.vertical"
        case .transit: return "tram"
        case .waterfront: return "water.waves"
        case .trail: return "figure.hiking"
        case .neighborhood: return "map"
        case .indoors: return "door.left.hand.closed"
        case .other: return "mappin"
        }
    }

    private func seedCompassRunControlsIfNeeded() {
        guard seededCompassSurfaceID != surface.id else { return }
        seededCompassSurfaceID = surface.id
        // A new run always begins at the first question.
        compassConstraintStep = .location
        let place = surface.payload.metadata["place"]?.nonEmpty
        let context = surface.payload.metadata["placeContextID"]
            .flatMap(CompassPlaceContext.init(rawValue:))
            ?? CompassPlaceContext.current
        compassPlaceContextID = context.rawValue
        compassLocation = place ?? context.promptValue
        compassTimeLimit = surface.payload.metadata["timeBox"]?.nonEmpty ?? "10 minutes"
        compassEnergy = normalizedCompassEnergy(surface.payload.metadata["energy"]) ?? "60%: steady"
        compassCompanions = surface.payload.metadata["companions"]?.nonEmpty ?? "solo"
        compassBudget = surface.payload.metadata["budget"]?.nonEmpty ?? "$0"
        compassNearbyPlacesOverride = surface.payload.metadata["nearbyPlaces"] ?? ""
        manualCompassSpark = surface.payload.metadata["spark"]?.nonEmpty ?? ""
        manualCompassDestination = surface.payload.metadata["destination"]?.nonEmpty ?? ""
        manualCompassDelight = surface.payload.metadata["delight"]?.nonEmpty ?? ""
        manualCompassDefinition = surface.payload.metadata["definition"]?.nonEmpty ?? ""
        manualCompassMission = surface.payload.metadata["mission"]?.nonEmpty ?? ""
        manualCompassSouvenirPrompt = surface.payload.metadata["souvenirPrompt"]?.nonEmpty ?? ""
        manualCompassRestPrompt = surface.payload.metadata["restPrompt"]?.nonEmpty ?? ""
    }

    private func normalizedCompassEnergy(_ value: String?) -> String? {
        guard let lowered = value?.lowercased(), !lowered.isEmpty else { return nil }
        if lowered.contains("depleted") || lowered.contains("exhaust") || lowered.contains("10%") {
            return "10%: depleted"
        }
        if lowered.contains("low") || lowered.contains("tired") || lowered.contains("35%") {
            return "35%: low"
        }
        if lowered.contains("bright") || lowered.contains("great") || lowered.contains("energ") || lowered.contains("85%") {
            return "85%: bright"
        }
        return "60%: steady"
    }

    @MainActor
    private func resolveCompassCurrentPlace() async {
        guard !isResolvingCompassPlace else { return }
        isResolvingCompassPlace = true
        compassCurrentPlaceMessage = "I'm reading the ground under your feet."
        defer { isResolvingCompassPlace = false }
        do {
            let signal = try await CompassCurrentPlaceReader.request(anchors: compassAnchors)
            compassPlaceContextID = signal.context.rawValue
            compassLocation = signal.label
            compassNearbyPlacesOverride = signal.nearbyPlaces.prefix(10).map(\.promptLine).joined(separator: "\n")
            compassCurrentLatitude = signal.latitude
            compassCurrentLongitude = signal.longitude
            compassAnchorProximity = signal.anchorProximity
            compassCurrentPlaceMessage = signal.detail
            BookFeedback.play(.braidComplete)
        } catch {
            compassCurrentPlaceMessage = error.localizedDescription
            BookFeedback.play(.error)
        }
    }

    private func rememberCompassCurrentPlace(as context: CompassPlaceContext) {
        guard let latitude = compassCurrentLatitude,
              let longitude = compassCurrentLongitude else {
            return
        }
        let place = CompassPlaceMemory.remember(
            context: context,
            latitude: latitude,
            longitude: longitude
        )
        compassPlaceContextID = context.rawValue
        compassLocation = place.name
        compassCurrentPlaceMessage = "Saved \(place.name). Future GPS reads inside this area will use \(context.title)."
        BookFeedback.play(.braidComplete)
    }

    @ViewBuilder
    private func compassRail(_ title: String, _ value: String?) -> some View {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal.opacity(0.82))
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var moodOptions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(weatherOptions, id: \.self) { option in
                Button {
                    BookFeedback.play(.select)
                    selectedWeather = option
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedWeather == option ? BookPalette.teal.opacity(0.18) : BookPalette.paper,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedWeather == option ? BookPalette.teal : BookPalette.ink.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.bookPress())
            }
        }
    }

    /// The tap-to-stamp phrases an affirmation carries ("I will." / "I might." /
    /// "We'll see."), parsed from the adapter's `||`-joined metadata.
    private var affirmationCountersigns: [String] {
        splitMetadataList(surface.payload.metadata["countersigns"])
    }

    private var aboutYouExampleLines: [String] {
        splitMetadataList(surface.payload.metadata["exampleLines"])
    }

    private var aboutYouExampleLineSources: [String] {
        splitMetadataList(surface.payload.metadata["exampleLineSources"])
    }

    private var aboutYouLinesComeFromReader: Bool {
        surface.payload.metadata["exampleLineMode"] == "reader-archive"
    }

    private var aboutYouChoicePrompt: String {
        surface.payload.metadata["choicePrompt"]?.nonEmpty
            ?? (aboutYouLinesComeFromReader ? "LINES FROM YOUR BOOK" : "A FEW ANSWERS TO TRY ON")
    }

    private var aboutYouExampleLineOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(aboutYouChoicePrompt)
                .font(.caption2.weight(.black))
                .tracking(0.8)
                .foregroundStyle(BookPalette.lampGold)

            ForEach(Array(aboutYouExampleLines.enumerated()), id: \.element) { index, line in
                let isSelected = text.trimmingCharacters(in: .whitespacesAndNewlines) == line
                Button {
                    BookFeedback.play(.select)
                    text = line
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? BookPalette.lampGold : openPageSecondaryText.opacity(0.55))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line)
                                .font(.system(.callout, design: .serif).weight(.semibold))
                                .foregroundStyle(openPageSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if aboutYouLinesComeFromReader,
                               aboutYouExampleLineSources.indices.contains(index) {
                                Text(aboutYouExampleLineSources[index].uppercased())
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.5)
                                    .foregroundStyle(BookPalette.lampGold.opacity(0.72))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? BookPalette.lampGold.opacity(0.16) : BookPalette.paper.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? BookPalette.lampGold.opacity(0.72) : openPageSecondaryText.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel("Choose: \(line)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// One tap drops a countersign into the ordinary margin note. The words stay
    /// editable: a reader can stamp "I will." and grow it into "I will, but
    /// only after coffee." Tapping a different chip while the note is still just
    /// a stamp swaps it; once the reader has written their own words, a chip
    /// appends instead of overwriting them.
    private var affirmationCountersignOptions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(affirmationCountersigns, id: \.self) { phrase in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let isStamped = trimmed == phrase || trimmed.hasPrefix(phrase)
                Button {
                    BookFeedback.play(.select)
                    if trimmed.isEmpty || affirmationCountersigns.contains(trimmed) {
                        text = phrase
                    } else {
                        text = "\(trimmed) \(phrase)"
                    }
                } label: {
                    Text(phrase)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isStamped ? BookPalette.lampGold.opacity(0.20) : BookPalette.paper,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isStamped ? BookPalette.lampGold : BookPalette.ink.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.bookPress())
            }
        }
    }

    // MARK: - Feast mechanics
    //
    // A festival that carries a mechanic asks for something rather than only
    // announcing itself. Everything here rides on metadata the adapter set, so
    // the affordance is decided by the Almanac, not by this view.

    private var festivalMechanic: CelebrationMechanic? {
        guard surface.type == .festival,
              let raw = surface.payload.metadata["festivalMechanic"]?.nonEmpty else { return nil }
        return CelebrationMechanic(rawValue: raw)
    }

    private var festivalBonesLine: String? {
        surface.payload.metadata["festivalBonesLine"]?.nonEmpty
    }

    @ViewBuilder
    private var festivalMechanicCard: some View {
        if let mechanic = festivalMechanic {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    surface.payload.metadata["festivalMechanicTitle"] ?? mechanic.title,
                    systemImage: surface.payload.metadata["festivalMechanicSymbol"] ?? mechanic.symbolName
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)

                if let prompt = surface.payload.metadata["festivalMechanicPrompt"]?.nonEmpty {
                    Text(prompt)
                        .font(.callout)
                        .foregroundStyle(openPageSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch mechanic {
                case .countersign:
                    if !affirmationCountersigns.isEmpty {
                        affirmationCountersignOptions
                    }
                case .throwTheBones:
                    festivalBonesThrow
                case .findOneLine, .nameSomething, .pressAKeepsake:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(BookPalette.lampGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
            }
        }
    }

    /// The throw is seeded on (feast, day) in the adapter, so tapping turns a
    /// card over rather than rolling. There is deliberately no second tap.
    @ViewBuilder
    private var festivalBonesThrow: some View {
        if festivalBonesRevealed, let line = festivalBonesLine {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(surface.payload.metadata["festivalBonesRoll"] ?? "?")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(BookPalette.lampGold)
                    Text(surface.payload.metadata["festivalBonesHeadline"] ?? "The bones fell")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(calloutBodyText)
                }
                Text(line)
                    .font(.callout)
                    .foregroundStyle(calloutBodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .transition(.opacity)
        } else {
            Button {
                BookFeedback.play(.braidComplete)
                withAnimation(BookMotion.reveal(reduceMotion)) {
                    festivalBonesRevealed = true
                }
            } label: {
                Label("Throw them", systemImage: "dice.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookPalette.lampGold.opacity(0.20), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.bookPress())
        }
    }

    private var festivalCanBeRested: Bool {
        surface.type == .festival && surface.payload.metadata["festivalCanRest"] == "true"
    }

    /// The door out of a day the Book marks without knowing whether it applies.
    /// Deliberately plain and deliberately not a confirmation dialogue: a
    /// reader retiring Mother's Day should not have to argue about it.
    private var festivalRestRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let tradition = surface.payload.metadata["festivalTradition"]?.nonEmpty {
                Text("A \(tradition) day. I keep the whole world's calendar; I've never assumed it's yours.")
                    .font(.caption)
                    .foregroundStyle(openPageSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                BookFeedback.play(.dismissPage)
                onRestCelebration?(surface.payload.metadata["celebrationID"] ?? surface.id)
                dismiss()
            } label: {
                Label(
                    surface.payload.metadata["festivalRestLabel"] ?? "Don't mark this day again",
                    systemImage: "bell.slash"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(openPageSecondaryText)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func externalPageLink(_ url: URL) -> some View {
        Link(destination: url) {
            Label(
                surface.payload.metadata["bookFoundGift"] == "true"
                    ? "See what I found"
                    : (surface.payload.metadata["platform"] == "x" ? "View on X" : "Open the public shelf"),
                systemImage: "arrow.up.right.square"
            )
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(BookPalette.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.teal.opacity(0.34), lineWidth: 1)
                }
        }
        .foregroundStyle(BookPalette.teal)
    }

    private var publicMarginsSuggestedSentence: String {
        let possibilities = [text, preparedInput, surface.detail]
        return possibilities.lazy.compactMap(PublicMarginsText.preparedSentence(from:)).first ?? ""
    }

    private var publicMarginsExportControl: some View {
        Button {
            BookFeedback.play(.tap)
            isPublicMarginsContributionPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label("Leave something in the Public Margins", systemImage: "text.bubble.fill")
                    .font(.subheadline.weight(.bold))
                Text("Offer one sentence or answer today's quiet question. Each gets its own confirmation.")
                    .font(.caption)
                    .opacity(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(BookPalette.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.teal.opacity(0.32), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(BookPalette.teal)
    }

    private var articleLinkList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Letters on the public shelf")
                .font(.caption.weight(.bold))
                .foregroundStyle(openPageSecondaryText)

            ForEach(articlePreviews.isEmpty ? articleLinks.map { (title: $0.title, url: $0.url, publishedAt: "", preview: "") } : articlePreviews, id: \.url) { article in
                Link(destination: article.url) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BookPalette.gold)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(article.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BookPalette.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                            if !article.publishedAt.isEmpty {
                                Text(article.publishedAt)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(openPageSecondaryText)
                            }
                            if !article.preview.isEmpty {
                                Text(article.preview)
                                    .font(.caption)
                                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(4)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                    }
                    .padding(12)
                    .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                    }
                }
            }
        }
    }

    private func marginNoteEditor(
        minHeight: CGFloat,
        title: String? = nil,
        placeholder: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LivingTextEditor(
                title: title ?? pageResponseTitle,
                placeholder: placeholder ?? pageResponsePlaceholder,
                text: $text,
                minHeight: minHeight,
                builderPack: SentenceBuilderPackRegistry.composedCore(readerLexicon: readerLexicon, shadowWonderActive: isShadowWonderActive),
                builderContext: sentenceBuilderContext
            )
            if allowsPressedPhoto {
                if BookNoticesPicker<EmptyView>.isAvailable {
                    bookNoticesBar
                }
                pressedPhotoBar
            }
            keptVoiceBar
        }
    }

    @ViewBuilder
    private var journalDeeperQuestionControl: some View {
        if let deeperQuestion = surface.payload.metadata["journalDeeperQuestion"]?.nonEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    BookFeedback.pressTick()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        isJournalDeeperQuestionOpen.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isJournalDeeperQuestionOpen ? "book.pages.fill" : "book.pages")
                        Text(isJournalDeeperQuestionOpen ? "The next question" : "Turn the page")
                            .font(.callout.weight(.bold))
                        Spacer(minLength: 8)
                        Image(systemName: isJournalDeeperQuestionOpen ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(BookPalette.teal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isJournalDeeperQuestionOpen {
                    Text(deeperQuestion)
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(BookPalette.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var bookNoticesBar: some View {
        BookNoticesPicker { seed in
            guard !seed.isEmpty else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = trimmed.isEmpty ? seed : "\(trimmed) \(seed)"
            BookFeedback.play(.openPage)
        } label: {
            Label("What I noticed today…", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)
        }
    }

    /// Whether this page may carry a pressed photograph. Ordinary writing pages
    /// only: pages with their own photo/proof flows opt out.
    private var allowsPressedPhoto: Bool {
        !isKeptReadbackPage && !isEnchantmentPage && !allowsCompassPhotoProof
    }

    @ViewBuilder
    private var pressedPhotoBar: some View {
        #if canImport(PhotosUI)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $pressedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        pressedPhotoAsset == nil ? "Press a photograph" : "Photograph pressed",
                        systemImage: pressedPhotoAsset == nil ? "photo.badge.plus" : "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                .disabled(isLoadingPressedPhoto)

                if pressedPhotoAsset != nil {
                    Button {
                        pressedPhotoAsset = nil
                        pressedPhotoItem = nil
                        pressedPhotoMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                    .tint(BookPalette.ink.opacity(0.5))
                    .accessibilityLabel("Remove the pressed photograph")
                }
                Spacer(minLength: 0)
            }

            if let pressedPhotoAsset,
               let preview = UIImage(contentsOfFile: pressedPhotoAsset.reference) {
                HStack(spacing: 10) {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(BookPalette.paper.opacity(0.92), lineWidth: 2)
                        }
                        .bookPhotographArrival(reduceMotion: reduceMotion)

                    Text("This exact photograph will travel into the archive with the page.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
            }
            if let message = pressedPhotoMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .transition(.opacity)
            }
        }
        .animation(BookMotion.reveal(reduceMotion), value: pressedPhotoAsset?.reference)
            #else
        EmptyView()
        #endif
    }

    #if canImport(PhotosUI)
    private func loadPressedPhoto(from item: PhotosPickerItem) async {
        await MainActor.run {
            isLoadingPressedPhoto = true
            pressedPhotoMessage = nil
        }
        defer { Task { @MainActor in isLoadingPressedPhoto = false } }

        guard let raw = try? await item.loadTransferable(type: Data.self),
              let jpeg = PressedPhotograph.downscaledJPEG(from: raw),
              let image = UIImage(data: jpeg) else {
            await MainActor.run { pressedPhotoMessage = "That photograph could not be read." }
            return
        }
        let attention = await attentionMetadata(for: image)
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("pressed-\(UUID().uuidString).jpg")
        do {
            try jpeg.write(to: url, options: [.atomic])
            let asset = BookPageMediaAsset(
                kind: .renderedImageFile,
                reference: url.path,
                caption: "",
                sourceID: surface.sourceID,
                metadata: attention.merging(["pressedPhotograph": "true"]) { current, _ in current }
            )
            await MainActor.run {
                pressedPhotoAsset = asset
                pressedPhotoMessage = "Pressed between the pages."
                BookFeedback.play(.openPage)
            }
        } catch {
            await MainActor.run { pressedPhotoMessage = "That photograph could not be kept." }
        }
    }
    #endif

    @ViewBuilder
    private var keptVoiceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    toggleKeptVoice()
                } label: {
                    HStack(spacing: 7) {
                        if keptVoiceRecorder.isRecording {
                            BookVoiceInkMeter(active: true, reduceMotion: reduceMotion)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Image(systemName: keptVoiceRecorder.isRecording
                            ? "stop.circle.fill"
                            : (keptVoiceAsset == nil ? "waveform" : "checkmark.circle.fill"))
                            .symbolEffect(.pulse, isActive: keptVoiceRecorder.isRecording && !reduceMotion)
                        Text(keptVoiceRecorder.isRecording
                            ? "Stop (\(Self.voiceDuration(keptVoiceRecorder.elapsed)))"
                            : (keptVoiceAsset == nil ? "Keep your voice" : "Voice kept"))
                    }
                    .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .tint(keptVoiceRecorder.isRecording ? BookPalette.lampGold : BookPalette.teal)

                if keptVoiceAsset != nil && !keptVoiceRecorder.isRecording {
                    Button {
                        keptVoiceAsset = nil
                        keptVoiceMessage = nil
                        keptVoiceRecorder.discard()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                    .tint(BookPalette.ink.opacity(0.5))
                    .accessibilityLabel("Remove the kept voice")
                }
                Spacer(minLength: 0)
            }

            if keptVoiceRecorder.isRecording {
                Label("The page is listening. Tap Stop when the thought is whole.", systemImage: "quote.opening")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.lampGold.opacity(0.82))
                    .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
            }
            if let message = keptVoiceMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .bookResultArrival(reduceMotion: reduceMotion)
            }
        }
        .animation(BookMotion.direct(reduceMotion), value: keptVoiceRecorder.isRecording)
        .animation(BookMotion.result(reduceMotion), value: keptVoiceAsset?.reference)
    }

    private func toggleKeptVoice() {
        if keptVoiceRecorder.isRecording {
            keptVoiceMessage = nil
            let duration = keptVoiceRecorder.elapsed
            if let url = keptVoiceRecorder.stop() {
                var metadata = [
                    "keptVoice": "true",
                    "durationSeconds": "\(Int(duration.rounded()))"
                ]
                if let cadence = keptVoiceRecorder.lastCadenceReceipt {
                    metadata.merge(cadence.metadata) { _, measured in measured }
                }
                keptVoiceAsset = BookPageMediaAsset(
                    kind: .audioFile,
                    reference: url.path,
                    caption: "",
                    sourceID: surface.sourceID,
                    metadata: metadata
                )
                keptVoiceMessage = keptVoiceRecorder.lastCadenceReceipt == nil
                    ? "Your voice is kept."
                    : "Your voice is kept, pauses and all."
                BookFeedback.play(.keepPage)
            } else {
                keptVoiceMessage = "Nothing was recorded."
            }
        } else {
            // Replace any earlier take.
            keptVoiceAsset = nil
            BookFeedback.play(.tap)
            if !keptVoiceRecorder.start() {
                keptVoiceMessage = "The microphone could not start."
            }
        }
    }

    private static func voiceDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var storyMarginNoteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(pageResponseTitle) — optional")
                .font(.caption.weight(.bold))
                .foregroundStyle(openPageSecondaryText)
            TextField(pageResponsePlaceholder, text: $text, axis: .vertical)
                .font(.callout)
                .foregroundStyle(BookPalette.ink)
                .lineLimit(2...4)
                .inkFeedback(text: text)
                .dictationInput(text: $text)
                .padding(12)
                .background(BookPalette.page.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var compassProofPhotoPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proof can be one sentence, one photo, or both.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(openPageSecondaryText)

            if let proofPhotoImage {
                Image(uiImage: proofPhotoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                    }
                    .accessibilityLabel("Playful mission proof photo")
                    .bookPhotographArrival(reduceMotion: reduceMotion)
            }

            HStack(spacing: 10) {
                #if canImport(PhotosUI)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label(proofPhotoImage == nil ? "Add proof photo" : "Replace proof photo", systemImage: "photo")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                #endif

                #if canImport(UIKit)
                if BookCameraCaptureView.isCameraAvailable {
                    Button {
                        BookFeedback.play(.openPage)
                        isCameraPresented = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.lampGold)
                }
                #endif
            }

            if !proofPhotoMessage.isEmpty {
                Text(proofPhotoMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .bookResultArrival(reduceMotion: reduceMotion)
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func illuminatedPreview(draft: IlluminatedPhotoDraft, height: CGFloat) -> some View {
        if manualPhotoDraft != nil,
           let renderedIlluminatedPageURL,
           let image = UIImage(contentsOfFile: renderedIlluminatedPageURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .accessibilityLabel("Illuminated photo page draft")
                .imagePreviewOnTap { renderedIlluminatedPageURL }
        } else if let renderedPath = surface.payload.metadata["renderedPreviewPath"],
           let image = UIImage(contentsOfFile: renderedPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .accessibilityLabel("Illuminated photo page draft")
                .imagePreviewOnTap { surface.payload.metadata["renderedPreviewPath"].flatMap { ImagePreview.url(forFilePath: $0) } }
        } else {
            IlluminatedArtifactPreview(draft: draft, sourceImage: manualPhotoImage)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                }
                .accessibilityLabel("Illuminated photo page draft")
        }
    }

    @ViewBuilder
    private func storySceneView(_ turn: StoryPageSessionTurn) -> some View {
        let draft = turn.draft
        let turnNumber = storyTurns.firstIndex(where: { $0.id == turn.id }).map { $0 + 1 } ?? storyTurns.count
        VStack(alignment: .leading, spacing: 14) {
            if storyTurns.count > 1 {
                let arcLabel = StoryArcShape(
                    beats: draft.formBeats,
                    turnsWritten: max(turnNumber - 1, 0),
                    formName: draft.formName
                ).progressLabel
                Text(arcLabel.isEmpty ? "The story continues" : arcLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.gold)
            }

            Text(draft.scene)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let academyActivity {
                academyActivityCard(academyActivity, draft: draft)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Choose how the page turns")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.56))

                ForEach(draft.choices) { choice in
                    Button {
                        BookFeedback.play(.select)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedStoryChoice = choice
                            updateActiveStoryTurn(choice: choice)
                        }
                        if choice.mechanic.kind == .none {
                            Task { await generateStoryResultForActiveTurn(choiceID: choice.id) }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: choice.symbolName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(choice.tint)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(choice.kindLabel)
                                    .font(.caption2.weight(.bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(choice.tint.opacity(0.82))
                                Text(choice.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(BookPalette.ink)
                                Text(choice.prompt)
                                    .font(.caption)
                                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                            }
                            Spacer(minLength: 8)
                            if choice.mechanic.kind != .none {
                                Image(systemName: choice.mechanic.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(choice.tint)
                            }
                            if selectedStoryChoice?.id == choice.id {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(BookPalette.teal)
                            }
                        }
                        .padding(12)
                        .background(
                            selectedStoryChoice?.id == choice.id ? choice.tint.opacity(0.16) : BookPalette.paper.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedStoryChoice?.id == choice.id ? choice.tint.opacity(0.52) : BookPalette.ink.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.bookPress())
                    .disabled(activeInkbonesThrow != nil || isGeneratingStoryResult || (isLocalBrainWorking && choice.mechanic.kind == .none))
                }
            }

            if let selectedStoryChoice {
                if isGeneratingStoryResult && generatingStoryResultChoiceID == selectedStoryChoice.id {
                    scribeWorkCard(storyScribeLabel(stage: "result"))
                }

                if storyMechanicIsResolved(selectedStoryChoice, in: turn) {
                    VStack(alignment: .leading, spacing: 8) {
                        let inkbonesResolution = turn.inkbonesResolution(for: selectedStoryChoice)
                        Label(
                            inkbonesResolution == nil ? "The page answers" : "The bones change the story",
                            systemImage: inkbonesResolution == nil ? "sparkles" : "book.pages"
                        )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                        if !isGeneratingStoryResult {
                            if let inkbonesResolution {
                                StoryInkbonesResultSummary(resolution: inkbonesResolution)
                            }
                            Text(turn.result(for: selectedStoryChoice))
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(BookPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if let texture = storyConsequenceTextureLine(choice: selectedStoryChoice, draft: draft) {
                                Text(texture)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .padding(12)
                    .background(BookPalette.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.gold.opacity(0.28), lineWidth: 1)
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    .bookResultArrival(reduceMotion: reduceMotion)
                } else {
                    storyMechanicActionCard(choice: selectedStoryChoice, draft: draft)
                }

                if currentStoryArc?.isComplete == true {
                    VStack(spacing: 8) {
                        Text("The vignette is ready to keep.")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            BookFeedback.play(.select)
                            text = "I should keep this thread here."
                        } label: {
                            Label("Keep this page", systemImage: "bookmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.caption.weight(.bold))
                    .tint(BookPalette.teal)
                } else {
                    HStack(spacing: 10) {
                        Button {
                            BookFeedback.play(.select)
                            text = "I should keep this thread here."
                        } label: {
                            Label("Keep this page", systemImage: "bookmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGeneratingStoryResult || !storyNarrativeResultIsReady(selectedStoryChoice, in: turn))

                        Button {
                            BookFeedback.play(.braidStart)
                            Task { await continueStoryPage(from: draft, choice: selectedStoryChoice) }
                        } label: {
                            Label(isContinuingStoryPage ? "Ink drying..." : "One more beat", systemImage: "arrow.turn.down.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isContinuingStoryPage || isGeneratingStoryResult || isLocalBrainWorking || !storyNarrativeResultIsReady(selectedStoryChoice, in: turn))
                    }
                    .font(.caption.weight(.bold))
                    .tint(BookPalette.teal)
                }

                if isContinuingStoryPage {
                    scribeWorkCard(storyScribeLabel(stage: "continuation"))
                }
            }

            if !storyContinuationMessage.isEmpty {
                Text(storyContinuationMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
            }
        }
    }

    private var academyActivity: AcademyActivity? {
        guard surface.type == .academyClass,
              surface.payload.metadata["academyActivityOutcome"] == nil,
              let sessionID = surface.payload.metadata["sessionID"]?.nonEmpty else {
            return nil
        }
        return AcademyActivityRegistry.activity(for: sessionID)
    }

    @ViewBuilder
    private func academyActivityCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(activity.title, systemImage: academyActivitySymbol(activity))
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.teal)

            Text(activity.invitation)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            if activity.isCompassRun {
                Button {
                    onNavigateToSurface(academyCompassRunSurface(activity: activity, draft: draft))
                } label: {
                    Label(activity.actionTitle, systemImage: "safari")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
            } else if activity.kind == .evidenceLog {
                glintPracticeCard(activity, draft: draft)
            } else {
                academySpecialPracticeCard(activity, draft: draft)
            }
        }
        .padding(12)
        .background(BookPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.30), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func glintPracticeCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        let facts = activity.fields
        VStack(alignment: .leading, spacing: 10) {
            Text(glintStage == 0 ? "1 of 3 · Choose a witness" : glintStage == 1 ? "2 of 3 · File the evidence" : "3 of 3 · Let it mean something")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.gold)

            if glintStage == 0 {
                Text("Pick an ordinary object close enough to inspect. Boggle's rule: do not improve it yet.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                TextField("The object in the lens", text: $glintObject)
                    .textFieldStyle(.roundedBorder)
                Button("Set it in the lens") {
                    glintStage = 1
                }
                .buttonStyle(.bordered)
                .disabled(glintObject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else if glintStage == 1 {
                Text("Three facts someone else could check. Save the story of the object for the next step.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                ForEach(facts) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.ink.opacity(0.64))
                        TextField(
                            field.placeholder,
                            text: Binding(
                                get: { academyActivityResponses[field.id, default: ""] },
                                set: { academyActivityResponses[field.id] = $0 }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(2...3)
                        .textFieldStyle(.roundedBorder)
                        if let reading = glintEvidenceReading(for: academyActivityResponses[field.id, default: ""]) {
                            Label(reading.text, systemImage: reading.symbol)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(reading.isEvidence ? BookPalette.teal : BookPalette.gold)
                        }
                    }
                }
                HStack {
                    Button("Choose another object") { glintStage = 0 }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Turn the lens") { glintStage = 2 }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.teal)
                        .disabled(!academyActivityIsReady(activity))
                }
            } else {
                Text("Your evidence is in the ledger. Now interpretation is welcome, but it must answer the facts, not replace them.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                ForEach(facts) { field in
                    let fact = academyActivityResponses[field.id, default: ""]
                    if !fact.isEmpty {
                        Text("• \(fact)")
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.72))
                    }
                }
                TextField("What did exact attention change or make possible?", text: $glintInterpretation, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Back to facts") { glintStage = 1 }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Bring the glint back") {
                        completeGlintPractice(activity, draft: draft)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(glintInterpretation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(10)
        .background(BookPalette.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func glintEvidenceReading(for text: String) -> (text: String, symbol: String, isEvidence: Bool)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        let interpretationWords = ["beautiful", "ugly", "sad", "lonely", "happy", "important", "seems", "feels", "means", "reminds"]
        if interpretationWords.contains(where: { lowered.contains($0) }) {
            return ("There may be a conclusion here. What could a camera record first?", "camera.macro", false)
        }
        return ("Good evidence: specific enough for another pair of eyes.", "checkmark.seal", true)
    }

    private func completeGlintPractice(_ activity: AcademyActivity, draft: StoryPageSceneDraft) {
        let facts = activity.fields.compactMap { field -> String? in
            academyActivityResponses[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
        guard facts.count == activity.fields.count else { return }
        let outcome = """
        Object under the glint-lens: \(glintObject.trimmingCharacters(in: .whitespacesAndNewlines))
        Evidence:\n\(facts.map { "- \($0)" }.joined(separator: "\n"))
        What exact attention changed: \(glintInterpretation.trimmingCharacters(in: .whitespacesAndNewlines))
        """
        completeAcademyActivity(activity, draft: draft, outcome: outcome)
    }

    @ViewBuilder
    private func academySpecialPracticeCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        switch activity.kind {
        case .thresholdPlan:
            thresholdPracticeCard(activity, draft: draft)
        case .sensoryScore:
            sensoryScoreCard(activity, draft: draft)
        case .sentenceWorkshop:
            sentenceWorkshopCard(activity, draft: draft)
        case .restCheckIn:
            restPracticeCard(activity, draft: draft)
        case .enchantmentCasting:
            enchantmentClassCard(activity, draft: draft)
        case .landingProtocol:
            landingProtocolCard(activity, draft: draft)
        case .souvenirCircle:
            souvenirCircleCard(activity, draft: draft)
        case .marginalNote:
            marginaliaCard(activity, draft: draft)
        case .workshopNote:
            inkwrightCard(activity, draft: draft)
        case .doorProtocol:
            bookJumpersCard(activity, draft: draft)
        case .compassRun, .evidenceLog:
            EmptyView()
        }
    }

    @ViewBuilder
    private func thresholdPracticeCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Pick which one this is, then fill in the boxes. Moving toward something changes what happens next. Getting away from something just gets you away.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        activityOptionRow(activity, options: [
            ("threshold", "I am moving toward something small"),
            ("escape", "I am trying to get away from something")
        ])
        activityFields(activity.fields)
        if academyActivitySelections[activity.id] == "escape" {
            Text("Good, that's honest. Say where you'll come back to as well, so this is a trip and not a disappearance.")
                .font(.caption).foregroundStyle(BookPalette.gold)
        }
        activityCompletionButton(activity, draft: draft)
    }

    @ViewBuilder
    private func sensoryScoreCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Take one moment from today and describe it three ways in the boxes below: what you heard, what colour it was, what your body did. Be literal first; get poetic after.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        HStack(spacing: 8) {
            sensoryInstrument("Sound", symbol: "waveform", tint: BookPalette.teal)
            sensoryInstrument("Color", symbol: "circle.lefthalf.filled", tint: BookPalette.violet)
            sensoryInstrument("Body", symbol: "hand.raised", tint: BookPalette.gold)
        }
        activityFields(activity.fields)
        activityCompletionButton(activity, draft: draft, label: "Let the room answer")
    }

    private func sensoryInstrument(_ title: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(BookPalette.ink.opacity(0.66))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private func sentenceWorkshopCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Write your sentence below, then write it again with one bit of showing-off taken out. Keep only what a stranger standing there could have seen.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        activityFields(activity.fields)
        Text("Villanelle's test: is the second version truer, or only fancier?")
            .font(.caption.weight(.semibold)).foregroundStyle(BookPalette.violet)
        activityCompletionButton(activity, draft: draft)
    }

    @ViewBuilder
    private func restPracticeCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        let stage = academyActivityStages[activity.id, default: 0]
        if stage == 0 {
            Text("One minute of doing nothing. You don't have to earn it first. Press the button and sit there.")
                .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
            Button("Begin one quiet minute") { beginQuietMinute(activity) }
                .buttonStyle(.borderedProminent).tint(BookPalette.teal)
        } else if stage == 1 {
            ProgressView(value: Double(60 - quietSecondsRemaining), total: 60)
                .tint(BookPalette.teal)
            Text("Nothing to solve. \(quietSecondsRemaining) seconds left.")
                .font(.callout).foregroundStyle(BookPalette.ink.opacity(0.72))
        } else {
            Text("That's the minute. Write below what the quiet got you — even if the answer is nothing much.")
                .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
            activityFields(activity.fields)
            activityCompletionButton(activity, draft: draft, label: "Return from the pause")
        }
    }

    @ViewBuilder
    private func enchantmentClassCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Pick an Enchantment below, then point it at something real in front of you — an object, a room, whatever's there. That's the whole class.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 8)], spacing: 8) {
            ForEach(StoryEnchantmentCatalog.spells) { spell in
                Button {
                    onNavigateToSurface(academyEnchantmentSurface(spell: spell, activity: activity, draft: draft))
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(spell.title, systemImage: spell.symbolName)
                            .font(.caption.weight(.bold)).foregroundStyle(BookPalette.ink)
                        Text(spell.detail)
                            .font(.caption2).foregroundStyle(BookPalette.ink.opacity(0.62))
                            .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.bookPress())
            }
        }
    }

    @ViewBuilder
    private func landingProtocolCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Permancer won't open a story until three things are written down. Fill in the boxes: the way in, what the weather's doing, and how you get back out.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        activityFields(activity.fields)
        activityCompletionButton(activity, draft: draft, label: "Set the bookmark")
    }

    @ViewBuilder
    private func souvenirCircleCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Everyone reads one sentence out. First pick how you'd listen to someone else's, then write yours in the box below.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        activityOptionRow(activity, options: [
            ("detail", "Ask about one concrete detail"),
            ("silence", "Let the sentence land in silence"),
            ("echo", "Echo back the truest noun")
        ])
        activityFields(activity.fields)
        activityCompletionButton(activity, draft: draft, label: "Read to the circle")
    }

    @ViewBuilder
    private func marginaliaCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Somebody will read this margin years from now. Pick the kind of mark you're leaving, then write the note in the box below — make it something they can actually answer.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        activityOptionRow(activity, options: [
            ("question", "Ask a future reader"),
            ("underline", "Underline the strange verb"),
            ("disagree", "Disagree without flattening")
        ])
        activityFields(activity.fields)
        activityCompletionButton(activity, draft: draft, label: "Leave the note")
    }

    @ViewBuilder
    private func inkwrightCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("Nobody fixes anybody's line here. Pick what you're going to say about it, then say it in the box below.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))
        activityOptionRow(activity, options: [
            ("effect", "Say what it did to me"),
            ("question", "Ask where it could go next"),
            ("craft", "Point at one thing that works")
        ])
        activityFields(activity.fields)
        activityCompletionButton(activity, draft: draft, label: "Offer the workshop note")
    }

    @ViewBuilder
    private func bookJumpersCard(_ activity: AcademyActivity, draft: StoryPageSceneDraft) -> some View {
        Text("You can't jump into “a book” in general. Pick one off the shelf below, then settle how you get in, where you land, and how you get home.")
            .font(.caption).foregroundStyle(BookPalette.ink.opacity(0.66))

        Text("Choose tonight’s book")
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.ink.opacity(0.64))

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
            ForEach(BookJumpEngine.publicDomainShelf) { work in
                Button {
                    academyBookJumpSelection = work.id
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: academyBookJumpSelection == work.id ? "book.closed.fill" : "book.closed")
                                .foregroundStyle(academyBookJumpSelection == work.id ? BookPalette.teal : BookPalette.ink.opacity(0.54))
                            Text(work.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        Text(work.author)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.58))
                        Text(work.world)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(
                        academyBookJumpSelection == work.id ? BookPalette.teal.opacity(0.12) : BookPalette.paper.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                academyBookJumpSelection == work.id ? BookPalette.teal.opacity(0.72) : BookPalette.teal.opacity(0.18),
                                lineWidth: academyBookJumpSelection == work.id ? 1.5 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }

        Text("Choose the agreement")
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.ink.opacity(0.64))
        activityOptionRow(activity, options: [
            ("consensus", "We agree on all three"),
            ("door", "We agree on the door only"),
            ("return", "We agree on the return first")
        ])
        activityFields(activity.fields)
        activityCompletionButton(activity, draft: draft, label: "Put it to the group")
    }

    @ViewBuilder
    private func activityFields(_ fields: [AcademyActivity.Field]) -> some View {
        ForEach(fields) { field in
            VStack(alignment: .leading, spacing: 4) {
                Text(field.label).font(.caption.weight(.bold)).foregroundStyle(BookPalette.ink.opacity(0.64))
                TextField(field.placeholder, text: activityResponseBinding(for: field.id), axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func activityResponseBinding(for id: String) -> Binding<String> {
        Binding(
            get: { academyActivityResponses[id, default: ""] },
            set: { academyActivityResponses[id] = $0 }
        )
    }

    @ViewBuilder
    private func activityOptionRow(_ activity: AcademyActivity, options: [(String, String)]) -> some View {
        ForEach(options.indices, id: \.self) { index in
            let option = options[index]
            Button {
                academyActivitySelections[activity.id] = option.0
            } label: {
                HStack {
                    Image(systemName: academyActivitySelections[activity.id] == option.0 ? "checkmark.circle.fill" : "circle")
                    Text(option.1).multilineTextAlignment(.leading)
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .padding(9)
                .foregroundStyle(academyActivitySelections[activity.id] == option.0 ? BookPalette.teal : BookPalette.ink.opacity(0.72))
                .background(BookPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func activityCompletionButton(_ activity: AcademyActivity, draft: StoryPageSceneDraft, label: String? = nil) -> some View {
        Button {
            completeSpecialAcademyActivity(activity, draft: draft)
        } label: {
            Label(label ?? activity.actionTitle, systemImage: "arrow.turn.down.right")
                .font(.headline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(BookPalette.teal)
        .disabled(!academySpecialActivityIsReady(activity))
    }

    private func academyFieldsReady(_ fields: [AcademyActivity.Field]) -> Bool {
        fields.allSatisfy { academyActivityResponses[$0.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil }
    }

    private func academySpecialActivityIsReady(_ activity: AcademyActivity) -> Bool {
        guard academyActivityIsReady(activity) else { return false }
        switch activity.kind {
        case .thresholdPlan, .souvenirCircle, .marginalNote, .workshopNote:
            return academyActivitySelections[activity.id] != nil
        case .doorProtocol:
            return academyActivitySelections[activity.id] != nil && academyBookJumpSelection != nil
        case .restCheckIn:
            return academyActivityStages[activity.id, default: 0] >= 2
        default:
            return true
        }
    }

    private func completeSpecialAcademyActivity(_ activity: AcademyActivity, draft: StoryPageSceneDraft) {
        guard academySpecialActivityIsReady(activity) else { return }
        let response = activity.fields.compactMap { field -> String? in
            academyActivityResponses[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty.map { "\(field.label): \($0)" }
        }.joined(separator: "\n")
        let choice = academyActivitySelections[activity.id].map { "Practice stance: \($0)\n" } ?? ""
        let chosenBook = academyBookJumpSelection
            .flatMap(BookJumpEngine.work(id:))
            .map { "Chosen book: \($0.title) by \($0.author)\n" } ?? ""
        completeAcademyActivity(activity, draft: draft, outcome: chosenBook + choice + response)
    }

    private func beginQuietMinute(_ activity: AcademyActivity) {
        academyActivityStages[activity.id] = 1
        quietSecondsRemaining = 60
        Task { @MainActor in
            for remaining in stride(from: 59, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard academyActivityStages[activity.id] == 1 else { return }
                quietSecondsRemaining = remaining
            }
            academyActivityStages[activity.id] = 2
        }
    }

    private func academyActivityIsReady(_ activity: AcademyActivity) -> Bool {
        activity.fields.allSatisfy {
            academyActivityResponses[$0.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil
        }
    }

    private func academyActivitySymbol(_ activity: AcademyActivity) -> String {
        switch activity.kind {
        case .compassRun: return "safari"
        case .evidenceLog: return "eye"
        case .thresholdPlan: return "figure.walk"
        case .sensoryScore: return "waveform"
        case .sentenceWorkshop, .marginalNote, .workshopNote: return "pencil.and.scribble"
        case .restCheckIn: return "moon.stars"
        case .enchantmentCasting: return "wand.and.stars"
        case .landingProtocol, .doorProtocol: return "bookmark"
        case .souvenirCircle: return "person.2"
        }
    }

    private func completeAcademyActivity(_ activity: AcademyActivity, draft: StoryPageSceneDraft) {
        guard academyActivityIsReady(activity) else { return }
        let outcome = activity.fields.compactMap { field -> String? in
            let value = academyActivityResponses[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : "\(field.label): \(value)"
        }.joined(separator: "\n")
        completeAcademyActivity(activity, draft: draft, outcome: outcome)
    }

    private func completeAcademyActivity(_ activity: AcademyActivity, draft: StoryPageSceneDraft, outcome: String) {
        let completedSurface = surface.withAcademyActivityReturn(activity: activity, draft: draft)
        let tags = preparedTags(for: completedSurface)
        requestDismiss()
        DispatchQueue.main.async {
            onSave(completedSurface, outcome, tags, [])
            onStoryMechanicCompleted(completedSurface, outcome)
        }
    }

    private func storyConsequenceTextureLine(choice: StoryPageChoiceDraft, draft: StoryPageSceneDraft) -> String? {
        let metadata = draft.surface.payload.metadata
        var tags: [String] = ["choice:\(choice.id)"]
        switch draft.surface.type {
        case .bookFae:
            tags.append(contentsOf: ["book-fae", "fae"])
            if let faeKind = metadata["faeKind"]?.nonEmpty {
                tags.append("fae:\(faeKind)")
            }
        case .anchor:
            tags.append(contentsOf: ["anchor", "outer-stacks"])
        case .academyClass:
            tags.append("academy-class")
        default:
            tags.append("narrative-os")
        }
        if let rawTags = metadata["tags"]?.nonEmpty {
            tags.append(contentsOf: rawTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        let entityIDs = (metadata["selectedEntityIDs"] ?? metadata["selectedEntities"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-") }
            .filter { !$0.isEmpty }
        tags.append(contentsOf: entityIDs.prefix(4).map { "entity:\($0)" })
        let threadIDs = (metadata["selectedThreadIDs"] ?? metadata["selectedThreads"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-") }
            .filter { !$0.isEmpty }
        tags.append(contentsOf: threadIDs.prefix(3).map { "thread:\($0)" })

        let probe = BookPage(
            type: draft.surface.type,
            promptText: draft.surface.prompt,
            userInput: "\(draft.scene)\n\nChosen path: \(choice.kindLabel)\n\n\(choice.prompt)\n\n\(choice.effectLine)",
            tags: tags,
            sourceID: draft.surface.sourceID,
            origin: draft.surface.origin,
            privacy: draft.surface.privacy
        )
        return StoryConsequenceResolver.resolvedConsequence(forChoiceID: choice.id, page: probe).textureLine
    }

    @ViewBuilder
    private var illuminatedPhotoActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(illuminationMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.58))

            #if canImport(UIKit)
            if hasPendingCameraPhoto {
                cameraPostCaptureChoiceCard
            } else {
                illuminatedPhotoPickerActions
            }
            #else
            illuminatedPhotoPickerActions
            #endif

            illuminatedArtifactActions

            if isLoadingManualPhoto || isChoosingBookPhoto {
                scribeWorkCard(
                    "photo-illumination",
                    quip: isChoosingBookPhoto
                        ? "Penny is looking for one recent photograph worth giving margins."
                        : "Penny is reading the photograph without letting it leave the room."
                )
            }
        }
        .tint(BookPalette.teal)
    }

    private var illuminatedPhotoPickerActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    BookFeedback.play(.sourceRefresh)
                    loadSampleIllumination()
                } label: {
                    Label("Try another", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    BookFeedback.play(.sourceRefresh)
                    Task { await letTheBookChoosePhoto() }
                } label: {
                    Label(isChoosingBookPhoto ? "Looking..." : "Let Book choose", systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isChoosingBookPhoto || isLoadingManualPhoto || isLocalBrainWorking)
            }
            .font(.caption.weight(.bold))

            HStack(spacing: 10) {
                #if canImport(PhotosUI)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label(isLoadingManualPhoto ? "Reading..." : "Choose myself", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingManualPhoto || isChoosingBookPhoto || isLocalBrainWorking)
                #endif

                #if canImport(UIKit)
                if BookCameraCaptureView.isCameraAvailable {
                    Button {
                        BookFeedback.play(.openPage)
                        isCameraPresented = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoadingManualPhoto || isChoosingBookPhoto || isLocalBrainWorking)
                }
                #endif

                Button {
                    BookFeedback.play(.openPage)
                    text = illuminatedDraft?.analysis.marginalia.observationList.joined(separator: "\n") ?? text
                } label: {
                    Label("Edit margins", systemImage: "pencil.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.caption.weight(.bold))
        }
    }

    private var illuminatedArtifactActions: some View {
        HStack(spacing: 10) {
            Button {
                BookFeedback.play(.sourceRefresh)
                Task { await saveIlluminatedArtifactToPhotos() }
            } label: {
                Label(isSavingIlluminatedArtifact ? "Saving..." : "Save plate", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isSavingIlluminatedArtifact || illuminatedDraft == nil)

            if let artifactURL = illuminatedArtifactURL {
                ShareLink(item: artifactURL) {
                    Label("Share plate", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    BookFeedback.play(.sourceRefresh)
                    Task { await prepareIlluminatedArtifactIfNeeded(force: true) }
                } label: {
                    Label("Prepare share", systemImage: "wand.and.sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(illuminatedDraft == nil || isLocalBrainWorking)
            }
        }
        .font(.caption.weight(.bold))
    }

    #if canImport(UIKit)
    @ViewBuilder
    private var cameraCapturePage: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isWorking = isLoadingManualPhoto || isCastingEnchantment || isLocalBrainWorking

            Label(
                enchantmentResult == nil && manualPhotoDraft == nil ? "Photo captured" : "Photo page ready",
                systemImage: enchantmentResult == nil && manualPhotoDraft == nil ? "camera.fill" : "checkmark.seal.fill"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(BookPalette.teal)

            if let image = cameraCaptureDisplayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 430)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                    }
                    .accessibilityLabel("Captured photo")
                    .bookPhotographArrival(reduceMotion: reduceMotion)
            }

            if isWorking {
                scribeWorkCard(
                    isCastingEnchantment ? "camera-enchantment" : "camera-illumination",
                    quip: isCastingEnchantment
                        ? "The Enchantment is reading the photo and writing its text."
                        : "Penny is pressing the photograph into one illuminated plate."
                )
            }

            if isChoosingCameraEnchantment {
                Text("Choose an Enchantment")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.62))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 10)], spacing: 10) {
                    ForEach(Array(StoryEnchantmentCatalog.spells.enumerated()), id: \.element.id) { index, spell in
                        Button {
                            selectedEnchantmentID = spell.id
                            BookFeedback.play(.openPage)
                            Task { await castPendingCameraPhoto(with: spell) }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(spell.title, systemImage: spell.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BookPalette.ink)
                                Text(spell.detail)
                                    .font(.caption2)
                                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selectedEnchantmentID == spell.id ? BookPalette.teal.opacity(0.5) : BookPalette.ink.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.bookPress())
                        .disabled(isCastingEnchantment || isLocalBrainWorking)
                        .bookResultArrival(reduceMotion: reduceMotion, delay: Double(index) * 0.045)
                    }
                }
                .animation(BookMotion.direct(reduceMotion), value: selectedEnchantmentID)

                Button {
                    BookFeedback.play(.select)
                    isChoosingCameraEnchantment = false
                } label: {
                    Label("Back to photo choices", systemImage: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
                .transition(BookMotion.foldTransition(reduceMotion: reduceMotion))
            } else {
                if enchantmentResult == nil && manualPhotoDraft == nil {
                    HStack(spacing: 10) {
                        Button {
                            BookFeedback.play(.sourceRefresh)
                            Task { await illuminatePendingCameraPhoto() }
                        } label: {
                            Label(isLoadingManualPhoto ? "Illuminating..." : "Illuminate", systemImage: "sparkles")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isWorking)

                        Button {
                            BookFeedback.play(.select)
                            isChoosingCameraEnchantment = true
                        } label: {
                            Label("Enchant", systemImage: "wand.and.stars")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isWorking)
                    }

                    Button {
                        keepOriginalCameraPhoto()
                    } label: {
                        Label("Keep original", systemImage: "photo.badge.checkmark")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                    .disabled(isWorking || pendingCameraPhotoURL == nil || isCommittingKeep)
                }

                if let result = enchantmentResult {
                    enchantmentResultCard(result)
                    if activeEnchantmentSpell?.id == "everything-speaks" {
                        AnyView(everythingSpeaksConversationView)
                    }
                }

                if manualPhotoDraft != nil {
                    illuminatedArtifactActions
                }
            }

            HStack(spacing: 10) {
                Button {
                    BookFeedback.play(.openPage)
                    isCameraPresented = true
                } label: {
                    Label("Retake", systemImage: "camera")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)

                #if canImport(PhotosUI)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Use library", systemImage: "photo")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
                #endif
            }

            if !cameraCaptureStatusMessage.isEmpty {
                Text(cameraCaptureStatusMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
        .animation(BookMotion.reveal(reduceMotion), value: isChoosingCameraEnchantment)
        .animation(BookMotion.result(reduceMotion), value: cameraCaptureStatusMessage)
    }

    private var cameraPostCaptureChoiceCard: some View {
        cameraCapturePage
    }

    private var cameraCaptureDisplayImage: UIImage? {
        return manualPhotoImage ?? pendingCameraPhotoImage
    }

    private var cameraCaptureStatusMessage: String {
        if isCastingEnchantment {
            return enchantmentMessage
        }
        if isLoadingManualPhoto {
            return illuminationMessage
        }
        if !enchantmentMessage.isEmpty && enchantmentResult != nil {
            return enchantmentMessage
        }
        return illuminationMessage
    }
    #endif

    private func loadSampleIllumination() {
        let plate = BookReferenceCatalog.labyrinthIllustrations.randomElement()
            ?? BookReferenceCatalog.labyrinthIllustration(for: BookDay.today())
        let next = plate.assetName
        manualPhotoImage = nil
        let draft = IlluminatedPageComposer.compose(
            analysis: FakePhotoIlluminationAnalyzer.analyze(illustration: plate),
            sourceAssetName: next,
            seed: Int.random(in: 1...Int.max / 2),
            assetLocalIdentifier: "bundled-illustration:\(plate.id)"
        )
        manualPhotoDraft = draft
        renderedIlluminatedPageURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: nil)
        illuminationMessage = renderedIlluminatedPageURL == nil
            ? "Penny pulled a Labyrinth illustration through the press. The plate can be prepared again."
            : "Penny pulled a Labyrinth illustration through the press."
        publishCurrentIlluminatedSurfaceIfReady()
    }

    #if canImport(PhotosUI)
    private func loadCompassProofPhoto(from item: PhotosPickerItem) async {
        proofPhotoMessage = "I'm tucking the proof into the margin."
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            BookFeedback.play(.error)
            proofPhotoMessage = "That photo would not open. A sentence still counts."
            return
        }
        await loadCompassProofPhoto(imageData: data)
    }

    private func loadCompassProofPhoto(imageData data: Data) async {
        proofPhotoMessage = "I'm tucking the proof into the margin."
        guard let image = UIImage(data: data) else {
            BookFeedback.play(.error)
            proofPhotoMessage = "That photo would not open. A sentence still counts."
            return
        }
        do {
            let url = try saveCompassProofPhotoData(data)
            await MainActor.run {
                proofPhotoImage = image
                proofPhotoURL = url
                proofPhotoMessage = "Proof photo ready."
                BookFeedback.play(.select)
            }
        } catch {
            await MainActor.run {
                BookFeedback.play(.error)
                proofPhotoMessage = "The photo could not be saved. A sentence still counts."
            }
        }
    }

    private func loadCameraPhotoForChoice(from item: PhotosPickerItem) async {
        illuminationMessage = "I'm opening that photograph."
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            BookFeedback.play(.error)
            illuminationMessage = "That photograph would not open. Try another one."
            return
        }
        await holdCameraPhotoForChoice(imageData: data)
    }

    private func loadManualPhoto(from item: PhotosPickerItem) async {
        guard !isLocalBrainWorking else {
            illuminationMessage = "The local brain is already writing. Let that ink dry first."
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            BookFeedback.play(.error)
            illuminationMessage = "The photograph would not open. The margins stayed quiet."
            return
        }
        await loadManualPhoto(imageData: data)
    }

    private func loadManualPhoto(imageData data: Data) async {
        guard !isLocalBrainWorking else {
            illuminationMessage = "The local brain is already writing. Let that ink dry first."
            return
        }
        isLoadingManualPhoto = true
        illuminationMessage = "Penny is reading the photograph without letting it leave the room."
        defer {
            isLoadingManualPhoto = false
        }
        guard let image = UIImage(data: data) else {
            BookFeedback.play(.error)
            illuminationMessage = "The photograph would not open. The margins stayed quiet."
            return
        }
        AppMemoryLedger.record("photo-manual-decoded")
        let analysis: PhotoAnalysis
        do {
            analysis = try await analyzeIlluminatedPhoto(image)
        } catch {
            await MainActor.run {
                BookFeedback.play(.error)
                illuminationMessage = "Penny could not reach Gemma for this photo: \(error.localizedDescription)"
            }
            return
        }
        AppMemoryLedger.record("photo-manual-after-gemma")
        let draft = IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: "IlluminatedPhotoSource",
            seed: data.count ^ Int(Date().timeIntervalSinceReferenceDate * 1000),
            assetLocalIdentifier: "manual:\(UUID().uuidString)"
        )
        AppMemoryLedger.record("photo-manual-before-render")
        let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)
        AppMemoryLedger.record("photo-manual-after-render")
        await MainActor.run {
            manualPhotoImage = image
            manualPhotoDraft = draft
            renderedIlluminatedPageURL = renderedURL
            illuminationMessage = renderedURL == nil
                ? "Penny wrote the margins. The rendered plate can be made again from the kept page."
                : "Penny wrote the margins. The plate is ready to keep."
            publishCurrentIlluminatedSurfaceIfReady()
            BookFeedback.play(.braidComplete)
        }
    }

    #if canImport(UIKit)
    @MainActor
    private func holdCameraPhotoForChoice(imageData data: Data) async {
        guard let image = UIImage(data: data) else {
            BookFeedback.play(.error)
            illuminationMessage = "The camera returned a photo I couldn't read. Try again."
            return
        }
        guard let url = try? saveCameraFirstPhotoData(data) else {
            BookFeedback.play(.error)
            illuminationMessage = "The photograph opened, but I couldn't keep a local copy. Try again."
            return
        }
        pendingCameraPhotoData = data
        pendingCameraPhotoImage = image
        pendingCameraPhotoURL = url
        isChoosingCameraEnchantment = false
        illuminationMessage = "Choose what the captured photo becomes."
        BookFeedback.play(.select)
    }

    @MainActor
    private func clearPendingCameraPhoto() {
        pendingCameraPhotoData = nil
        pendingCameraPhotoImage = nil
        pendingCameraPhotoURL = nil
        isChoosingCameraEnchantment = false
    }

    private func saveCameraFirstPhotoData(_ data: Data) throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = baseURL
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("CameraFirstPhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "camera-first-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        guard let jpeg = PressedPhotograph.downscaledJPEG(from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try jpeg.write(to: url, options: [.atomic])
        return url
    }

    @MainActor
    private func keepOriginalCameraPhoto() {
        guard !isCommittingKeep,
              let url = pendingCameraPhotoURL,
              let image = pendingCameraPhotoImage else {
            BookFeedback.play(.error)
            illuminationMessage = "Take or choose a photograph before keeping the original."
            return
        }
        isCommittingKeep = true
        illuminationMessage = "I'm keeping a private memory of what the photograph contains."
        Task {
            let attention = await attentionMetadata(for: image)
            await MainActor.run {
                let asset = BookPageMediaAsset(
                    kind: .renderedImageFile,
                    reference: url.path,
                    caption: "Original photograph",
                    sourceID: "plain-page",
                    metadata: attention.merging([
                        "plainPhoto": "true",
                        "uneditedPhoto": "true",
                        "cameraSeal": "true"
                    ]) { current, _ in current }
                )
                onKeepPlainPhoto(asset)
                requestDismiss()
            }
        }
    }

    /// Vision runs entirely on device and stores only a small descriptive
    /// fingerprint beside the kept asset, never the feature tensors.
    ///
    /// This used to carry its own copy of the classifier pass, which meant a
    /// plain kept photo was read by a weaker eye than an illuminated one. It
    /// now goes through the same ensemble, so what the Book remembers about a
    /// photograph does not depend on which door it came in by.
    private func attentionMetadata(for image: UIImage) async -> [String: String] {
        guard image.cgImage != nil else {
            return ["attentionModality": "photo"]
        }
        #if canImport(Vision)
        let packet = await VisionFactExtractor().facts(for: image)
        #else
        return ["attentionModality": "photo"]
        #endif
        // Light and colour ride in their own fields below; letting them into
        // the label list too would put "warm" in the motifs twice.
        let labels = packet.facts
            .filter { $0.kind != .visibleText && $0.kind != .light && $0.kind != .colour }
            .map(\.label)
        let peopleCount = packet.people.filter { $0.source == .appleVisionHuman }.count
        let visibleText = packet.visibleText.prefix(4).map(\.label).joined(separator: " | ")

        var metadata = [
            "attentionModality": "photo",
            "attentionLabels": labels.joined(separator: ","),
            "attentionMotifs": labels.prefix(5).joined(separator: ","),
            "attentionSubject": packet.primarySubject?.label ?? "",
            "attentionScene": labels.prefix(3).joined(separator: ","),
            "attentionBrightness": packet.facts(of: .light).first?.label ?? "soft light",
            "attentionColorMood": packet.facts(of: .colour).first?.label ?? "muted",
            "attentionComposition": "\(packet.orientation.rawValue), people-\(peopleCount)",
            "attentionPeopleCount": "\(peopleCount)",
            // Provenance travels with the fingerprint so a later reader can tell
            // which eye wrote it, and how sure that eye was.
            "attentionBackend": packet.backends.joined(separator: ","),
            "attentionCertainty": packet.strongestCertainty.rawValue
        ]
        if !visibleText.isEmpty {
            metadata["attentionVisibleText"] = visibleText
        }
        if !packet.uncertainty.isEmpty {
            metadata["attentionUncertainty"] = packet.uncertainty.joined(separator: "; ")
        }
        return metadata
    }

    private func illuminatePendingCameraPhoto() async {
        guard let data = pendingCameraPhotoData else { return }
        await loadManualPhoto(imageData: data)
        await MainActor.run {
            if manualPhotoDraft != nil {
                clearPendingCameraPhoto()
            }
        }
    }

    private func castPendingCameraPhoto(with spell: EnchantmentSpell) async {
        guard let data = pendingCameraPhotoData else { return }
        await MainActor.run {
            selectedEnchantmentID = spell.id
            enchantmentMessage = "Casting \(spell.title) on the captured photo."
        }
        await castEnchantment(imageData: data)
        await MainActor.run {
            if enchantmentResult != nil {
                clearPendingCameraPhoto()
            }
        }
    }
    #endif

    private func castEnchantment(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            BookFeedback.play(.error)
            enchantmentMessage = "That photo would not open. The spell did not land."
            return
        }
        await castEnchantment(imageData: data)
    }

    private func castEnchantment(imageData data: Data) async {
        guard let spell = activeEnchantmentSpell else {
            enchantmentMessage = "Choose an Enchantment first."
            BookFeedback.play(.error)
            return
        }
        guard !isLocalBrainWorking, !isCastingEnchantment else {
            enchantmentMessage = "The local brain is already writing. Let that ink dry first."
            return
        }
        isCastingEnchantment = true
        enchantmentMessage = "Casting \(spell.title) on the photo."
        defer { isCastingEnchantment = false }

        guard let image = UIImage(data: data) else {
            BookFeedback.play(.error)
            enchantmentMessage = "That photo would not open. The spell did not land."
            return
        }
        guard onSpendBeliefForGeneration(.enchantment) else {
            enchantmentMessage = "This spell is waiting for my Glow to warm."
            return
        }

        do {
            let analysis = try await analyzeIlluminatedPhoto(image)
            let result = try await writeEnchantmentResult(spell: spell, analysis: analysis)
            let spellAnalysis = enchantedAnalysis(from: analysis, result: result)
            let draft = IlluminatedPageComposer.compose(
                analysis: spellAnalysis,
                sourceAssetName: "IlluminatedPhotoSource",
                seed: data.count ^ spell.id.stableHash ^ Int(Date().timeIntervalSinceReferenceDate * 1000),
                assetLocalIdentifier: "enchantment:\(spell.id):\(UUID().uuidString)"
            )
            let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)
            await MainActor.run {
                manualPhotoImage = image
                manualPhotoDraft = draft
                renderedIlluminatedPageURL = renderedURL
                enchantmentResult = result
                enchantmentTurns = []
                enchantmentPrompt = ""
                currentEnchantmentSurface = enchantmentSurface(spell: spell, draft: draft, result: result, renderedURL: renderedURL)
                enchantmentMessage = renderedURL == nil
                    ? "\(spell.title) wrote the result. The illuminated plate can be prepared again."
                    : "\(spell.title) wrote the illuminated result."
                enchantmentArrivalTick += 1
                BookFeedback.play(.braidComplete)
            }
            // The spell is written and the plate is drawn, so nothing is left
            // for the weights to do. Hand the room back now rather than on a
            // timer: with E2B resident this device cannot raise a keyboard, and
            // the reader's next move is often to go and type something.
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            await LocalBrainModelCache.shared.releaseAfterFlow(label: "enchantment")
            #endif
        } catch {
            onRefundBeliefForGeneration(.enchantment)
            appLog.error("Enchantment cast failed: \(error.localizedDescription, privacy: .private)")
            await MainActor.run {
                BookFeedback.play(.error)
                enchantmentMessage = "\(spell.title) did not finish. The local brain dropped its pencil, and your Belief was returned."
            }
        }
    }
    #endif

    private func writeEnchantmentResult(spell: EnchantmentSpell, analysis: PhotoAnalysis) async throws -> EnchantmentCastResult {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        return try await MLXEnchantmentWriter().cast(spell: spell, analysis: analysis, day: day)
        #else
        return try await FakeEnchantmentWriter().cast(spell: spell, analysis: analysis, day: day)
        #endif
    }

    private func enchantedAnalysis(from analysis: PhotoAnalysis, result: EnchantmentCastResult) -> PhotoAnalysis {
        let observations = result.resultText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let shortened = observations.isEmpty ? [result.resultText] : Array(observations.prefix(5))
        return PhotoAnalysis(
            scene: analysis.scene,
            motifs: Array(Set(analysis.motifs + [result.subjectName, result.spellName])).sorted(),
            mood: analysis.mood,
            suggestedTemplate: analysis.suggestedTemplate,
            marginalia: PhotoMarginalia(
                fieldNote: result.openingLine,
                stampLabel: result.spellName.uppercased(),
                observationList: shortened,
                closingLine: result.resultText
            ),
            souvenirCandidates: [result.openingLine, result.resultText] + analysis.souvenirCandidates
        )
    }

    private func enchantmentSurface(
        spell: EnchantmentSpell,
        draft: IlluminatedPhotoDraft,
        result: EnchantmentCastResult,
        renderedURL: URL?
    ) -> SurfacePage {
        var metadata = surface.payload.metadata
        metadata.merge([
            "source": "enchantment",
            "sourceAssetName": draft.sourceAssetName,
            "assetLocalIdentifier": draft.assetLocalIdentifier,
            "template": draft.compositionPlan.templateId.rawValue,
            "assetPack": draft.compositionPlan.assetPackId,
            "status": draft.status.rawValue,
            "privacy": "private local draft",
            "enchantmentID": spell.id,
            "enchantmentName": spell.title,
            "enchantmentSubject": result.subjectName,
            "enchantmentOpeningLine": result.openingLine,
            "enchantmentResultText": result.resultText,
            BeliefEconomyPolicy.generationPaidKey: "true",
            BeliefEconomyPolicy.generationKindKey: BeliefGenerationKind.enchantment.rawValue,
            BeliefEconomyPolicy.generationCostKey: "\(BeliefGenerationKind.enchantment.cost)",
            "noBeliefReward": "true",
            "fieldNote": draft.analysis.marginalia.fieldNote,
            "stampLabel": draft.analysis.marginalia.stampLabel,
            "observations": draft.analysis.marginalia.observationList.joined(separator: " | "),
            "closingLine": draft.analysis.marginalia.closingLine,
            "scene": draft.analysis.scene,
            "motifs": draft.analysis.motifs.joined(separator: ","),
            "mood": draft.analysis.mood,
            "souvenirs": draft.analysis.souvenirCandidates.joined(separator: " | "),
            "tags": "enchantment,proof,real-world-magic,\(spell.id),illuminated-photo"
        ]) { _, new in new }
        if let renderedURL {
            metadata["renderedPreviewPath"] = renderedURL.path
        }
        if let objectVoice = result.objectVoice {
            metadata["enchantmentObjectVoice"] = objectVoice
        }
        return SurfacePage(
            id: "enchantment-result-\(spell.id)-\(draft.id.uuidString)",
            type: .enchantment,
            sourceID: BookPageSourceRegistry.source(for: .enchantment).id,
            intent: .capture,
            renderStyle: .illuminatedPhoto,
            score: 98,
            reason: "\(spell.title) completed with photo proof and an illuminated result.",
            prompt: "\(spell.title): \(result.subjectName)",
            detail: result.openingLine,
            payload: BookPagePayload(
                headline: spell.title,
                body: result.resultText,
                metadata: metadata
            )
        )
    }

    private func saveCompassProofPhotoData(_ data: Data) throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "com.openclaw.enchantify.insidecover"
        let directory = baseURL
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("CompassProofs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "compass-proof-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        guard let jpeg = PressedPhotograph.downscaledJPEG(from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try jpeg.write(to: url, options: [.atomic])
        return url
    }

    private func letTheBookChoosePhoto() async {
        #if canImport(Photos) && canImport(UIKit)
        guard !isLocalBrainWorking else {
            illuminationMessage = "The local brain is already writing. Let that ink dry first."
            return
        }
        isChoosingBookPhoto = true
        illuminationMessage = "I'm asking the camera roll for one recent page worth keeping."
        defer { isChoosingBookPhoto = false }

        let library = PhotoLibraryService()
        let status = library.authorizationStatus()
        let finalStatus = (status == .notDetermined) ? await library.requestAuthorization() : status
        guard finalStatus == .authorized || finalStatus == .limited else {
            BookFeedback.play(.error)
            illuminationMessage = "I can't see the camera roll yet. You can still choose a photo yourself."
            return
        }

        do {
            let history = decodedIlluminatedPhotoHistory()
            let assets = try await library.fetchRecentPhotoAssets(
                lookbackHours: PhotoSuggestionSettings.default.lookbackHours,
                favoritesOnly: PhotoSuggestionSettings.default.favoritesOnly,
                includeScreenshots: PhotoSuggestionSettings.default.includeScreenshots
            )
            let illuminationContext = PhotoIlluminationContext.current(
                themeTags: (surface.payload.metadata["tags"] ?? "")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    + [surface.type.rawValue],
                now: Date()
            )
            let candidates = PhotoCandidateScorer().scoreAssets(assets, history: history, context: illuminationContext)
            guard let candidate = preferredIlluminatedPhotoCandidate(from: candidates, history: history) else {
                BookFeedback.play(.error)
                illuminationMessage = "The margins are quiet. Try choosing a photo by hand."
                return
            }
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [candidate.assetLocalIdentifier], options: nil).firstObject else {
                BookFeedback.play(.error)
                illuminationMessage = "That photo slipped behind a shelf. Try another."
                return
            }

            let image = try await library.requestFullImage(for: asset, targetSize: CGSize(width: 1400, height: 1400))
            let analysis = PhotoAnalysis.contextualPreview(context: illuminationContext)
            let draft = IlluminatedPageComposer.compose(
                analysis: analysis,
                sourceAssetName: "IlluminatedPhotoSource",
                seed: abs(candidate.assetLocalIdentifier.stableHash ^ Int(Date().timeIntervalSinceReferenceDate * 1000)),
                assetLocalIdentifier: candidate.assetLocalIdentifier
            )
            let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)

            await MainActor.run {
                var updatedHistory = history
                updatedHistory.proposedAssetIdentifiers.insert(candidate.assetLocalIdentifier)
                updatedHistory.lastSuggestedAtByAsset[candidate.assetLocalIdentifier] = Date()
                illuminatedPhotoHistoryData = encodedIlluminatedPhotoHistory(updatedHistory)
                manualPhotoImage = image
                manualPhotoDraft = draft
                renderedIlluminatedPageURL = renderedURL
                illuminationMessage = "Penny found a recent photograph and gave it margins."
                publishCurrentIlluminatedSurfaceIfReady()
                BookFeedback.play(.braidComplete)
            }
        } catch {
            BookFeedback.play(.error)
            illuminationMessage = "The page tore while being assembled. Try again, or choose one by hand."
        }
        #else
        illuminationMessage = "This build cannot open the camera roll, but Labyrinth illustration plates still work."
        #endif
    }

    private func analyzeIlluminatedPhoto(_ image: UIImage) async throws -> PhotoAnalysis {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        appLog.info("Illuminated Photo Page sending photo to Gemma analyzer.")
        return try await GemmaPhotoIlluminationAnalyzer().analyze(photo: image)
        #else
        return PhotoAnalysis.academyFallback
        #endif
    }

    private func decodedIlluminatedPhotoHistory() -> IlluminatedPhotoHistory {
        guard let data = illuminatedPhotoHistoryData.data(using: .utf8),
              let history = try? JSONDecoder().decode(IlluminatedPhotoHistory.self, from: data) else {
            return IlluminatedPhotoHistory()
        }
        return history
    }

    private func encodedIlluminatedPhotoHistory(_ history: IlluminatedPhotoHistory) -> String {
        guard let data = try? JSONEncoder().encode(history),
              let encoded = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return encoded
    }

    @MainActor
    private func publishCurrentIlluminatedSurfaceIfReady() {
        #if canImport(UIKit)
        guard !isCameraFirstIlluminatedPage else {
            return
        }
        #endif
        guard let currentIlluminatedSurface,
              currentIlluminatedSurface.payload.metadata["renderedPreviewPath"]?.isEmpty == false else {
            return
        }
        onReplaceIlluminatedSurface(currentIlluminatedSurface)
    }

    @MainActor
    private func prepareIlluminatedArtifactIfNeeded(force: Bool = false) async {
        guard force || illuminatedArtifactURL == nil else {
            return
        }
        guard let illuminatedDraft else {
            return
        }
        let renderedURL = IlluminatedPageRenderer.renderPreview(draft: illuminatedDraft, sourceImage: manualPhotoImage)
        renderedIlluminatedPageURL = renderedURL
        if renderedURL == nil {
            BookFeedback.play(.error)
            illuminationMessage = "The plate did not finish drying. Try preparing it again."
        } else if force {
            BookFeedback.play(.braidComplete)
        }
        publishCurrentIlluminatedSurfaceIfReady()
    }

    @MainActor
    private func prepareIlluminatedQuoteCard(force: Bool = false) async {
        guard force || quoteCardShareURL == nil else {
            return
        }
        guard canShareIlluminatedQuoteCard,
              let quote = illuminatedQuoteText else {
            return
        }
        isPreparingQuoteCard = true
        quoteCardMessage = force ? "I'm gilding the card." : ""
        defer { isPreparingQuoteCard = false }

        let renderedURL = IlluminatedQuoteCardRenderer.render(
            quote: quote,
            sourceTitle: quoteCardSourceTitle,
            weatherLine: quoteCardWeatherLine,
            dateLine: quoteCardDateLine,
            style: PageVisualStyle.style(for: surface.type),
            seed: surface.id.stableHash ^ quote.stableHash
        )
        illuminatedQuoteCardURL = renderedURL
        if renderedURL == nil {
            BookFeedback.play(.error)
            quoteCardMessage = "The card did not finish drying. Text sharing still works."
        } else {
            if force {
                BookFeedback.play(.braidComplete)
            }
            quoteCardMessage = ""
        }
    }

    @MainActor
    private func prepareBookOfYouShareCard(force: Bool = false) async {
        guard force || bookOfYouPressedPageURL == nil else {
            return
        }
        guard let artifact = BookOfYouShareArtifact.make(from: surface) else {
            return
        }
        isPressingBookOfYouShareCard = true
        bookOfYouShareMessage = force ? "I'm pressing one safe page for the outside world." : ""
        defer { isPressingBookOfYouShareCard = false }

        let renderedURL = BookOfYouShareCardRenderer.render(artifact: artifact)
        bookOfYouShareCardURL = renderedURL
        if renderedURL == nil {
            BookFeedback.play(.error)
            bookOfYouShareMessage = "The page did not finish pressing. Text sharing still works."
        } else {
            if force {
                BookFeedback.play(.braidComplete)
            }
            bookOfYouShareMessage = "Only this pressed image is shared. The full braid stays in your Book."
        }
    }

    @MainActor
    private func prepareBookOfYouRevealVideo() async {
        guard bookOfYouPageRevealURL == nil else {
            return
        }
        guard let artifact = BookOfYouShareArtifact.make(from: surface) else {
            return
        }
        isPressingBookOfYouRevealVideo = true
        bookOfYouShareMessage = "I'm pressing a short reveal for Stories."
        defer { isPressingBookOfYouRevealVideo = false }

        let renderedURL = await BookOfYouPageRevealVideoRenderer.render(artifact: artifact)
        bookOfYouRevealVideoURL = renderedURL
        if renderedURL == nil {
            BookFeedback.play(.error)
            bookOfYouShareMessage = "The reveal did not finish pressing. The still page is ready to share."
        } else {
            BookFeedback.play(.braidComplete)
            bookOfYouShareMessage = "Only this reveal video is shared. The full braid stays in your Book."
        }
    }

    @MainActor
    private func saveIlluminatedArtifactToPhotos() async {
        isSavingIlluminatedArtifact = true
        defer { isSavingIlluminatedArtifact = false }

        await prepareIlluminatedArtifactIfNeeded()
        guard let artifactURL = illuminatedArtifactURL else {
            BookFeedback.play(.error)
            illuminationMessage = "The plate is not ready to save yet."
            return
        }

        #if canImport(Photos)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: artifactURL)
            }
            BookFeedback.play(.keepPage)
            illuminationMessage = "The plate is tucked into Photos."
        } catch {
            BookFeedback.play(.error)
            illuminationMessage = "Photos would not take the plate yet. Check photo permissions, then try again."
        }
        #else
        illuminationMessage = "This build cannot save to Photos, but the plate is prepared."
        #endif
    }

    @MainActor
    private func saveEnchantmentArtifactToPhotos() async {
        isSavingEnchantmentArtifact = true
        defer { isSavingEnchantmentArtifact = false }

        guard let artifactURL = enchantmentArtifactURL else {
            BookFeedback.play(.error)
            enchantmentMessage = "The Enchantment result is not ready to save yet."
            return
        }

        #if canImport(Photos)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: artifactURL)
            }
            BookFeedback.play(.keepPage)
            enchantmentMessage = "The Enchantment result is tucked into Photos."
        } catch {
            BookFeedback.play(.error)
            enchantmentMessage = "Photos would not take the Enchantment result yet. Check photo permissions, then try again."
        }
        #else
        enchantmentMessage = "This build cannot save to Photos, but the Enchantment result is prepared."
        #endif
    }

    private func markIlluminatedDraftKept() {
        guard surface.type == .illuminatedPhoto,
              let illuminatedDraft else {
            return
        }
        var history = decodedIlluminatedPhotoHistory()
        history.keptAssetIdentifiers.insert(illuminatedDraft.assetLocalIdentifier)
        illuminatedPhotoHistoryData = encodedIlluminatedPhotoHistory(history)
    }

    private func updateActiveStoryTurn(choice: StoryPageChoiceDraft) {
        guard surface.isStoryPlayablePage else { return }
        if storyTurns.isEmpty, let storySceneDraft {
            storyTurns = [StoryPageSessionTurn(draft: storySceneDraft, selectedChoice: choice)]
            return
        }
        guard let lastIndex = storyTurns.indices.last else { return }
        storyTurns[lastIndex].selectedChoice = choice
    }

    @MainActor
    private func generateStoryResultForActiveTurn(choiceID: String) async {
        guard surface.isStoryPlayablePage else { return }
        guard let turnIndex = storyTurns.indices.last,
              let choice = storyTurns[turnIndex].selectedChoice,
              choice.id == choiceID else {
            return
        }
        let inkbonesResolution = storyTurns[turnIndex].inkbonesResolution(for: choice)
        guard !isGeneratingStoryResult else {
            storyContinuationMessage = "I'm already answering one path. Let that ink dry first."
            return
        }
        let mechanicIsResolved = storyMechanicIsResolved(choice, in: storyTurns[turnIndex])
        if choice.mechanic.kind != .none && !mechanicIsResolved {
            storyContinuationMessage = "This path needs its mechanic first."
            return
        }
        if storyTurns[turnIndex].generatedResults[choiceID]?.nonEmpty != nil {
            return
        }
        // A prepared result is sufficient for ordinary choices. A completed
        // Inkbones throw must rewrite it through the roll's narrative band.
        if inkbonesResolution == nil,
           storyTurns[turnIndex].draft.preparedResults[choiceID]?.nonEmpty != nil {
            return
        }

        let context = StoryPageResultContext(
            previousTurns: Array(storyTurns.prefix(turnIndex)),
            draft: storyTurns[turnIndex].draft,
            selectedChoice: choice,
            inkbonesResolution: inkbonesResolution
        )

        guard !isLocalBrainWorking else {
            if inkbonesResolution != nil {
                storyTurns[turnIndex].generatedResults[choiceID] = context.fallbackResult
                storyContinuationMessage = "The bones changed the scene without waking another local scribe."
                BookFeedback.play(.braidComplete)
            } else {
                storyContinuationMessage = "The local brain is already writing. Let that ink dry first."
            }
            return
        }

        isGeneratingStoryResult = true
        generatingStoryResultChoiceID = choiceID
        storyContinuationMessage = "I'm answering the path you chose."
        defer {
            isGeneratingStoryResult = false
            generatingStoryResultChoiceID = nil
        }

        func writeStoryResult(correction: String? = nil) async throws -> String {
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            return try await MLXStoryPageResultWriter().write(context: context, correction: correction)
            #else
            return try await FakeStoryPageResultWriter().write(context: context, correction: correction)
            #endif
        }

        do {
            var result = try await writeStoryResult()
            // Validation rail: if the result drifts back into atmosphere instead
            // of enacting the committed landing, regenerate once, then state the
            // change plainly so the page still moves.
            if let landing = StoryTurnLanding.resolve(context.draft.turnLandings, choiceID: choiceID) {
                let character = context.draft.turnCharacter
                let names = context.draft.entities
                func acceptable(_ text: String) -> Bool {
                    StoryTurnValidator.asserts(text, landing: landing, character: character)
                        && !StoryTurnValidator.isAtmosphereDominated(text, characterNames: names)
                }
                if !acceptable(result) {
                    // Say what was wrong, rather than rolling the same dice
                    // again. A bare second call is an independent sample of the
                    // same request: it has no reason to fix anything, and no
                    // reason to resemble the beat the reader was about to read.
                    let correction = StoryTurnValidator.correction(
                        for: result, landing: landing, character: character, names: names)
                    let retry = (try? await writeStoryResult(correction: correction)) ?? result

                    // Keep the better draft, never merely the later one. This
                    // discarded the first attempt even when the retry was worse,
                    // which is how a long first beat lost to a short second one.
                    if acceptable(retry) {
                        result = retry
                    } else {
                        let kept = StoryTurnValidator.preferred(first: result, second: retry)
                        result = StoryTurnValidator.landed(kept, landing: landing)
                    }
                }
            }
            if let inkbonesResolution {
                result = inkbonesResolution.ensuringNarrativeBand(in: result)
            }
            guard storyTurns.indices.contains(turnIndex) else { return }
            storyTurns[turnIndex].generatedResults[choiceID] = result
            let arc = StoryArcShape(
                beats: storyTurns[turnIndex].draft.formBeats,
                turnsWritten: max(storyTurns.count, 1),
                formName: storyTurns[turnIndex].draft.formName,
                promiseSeed: storyTurns[turnIndex].draft.promiseSeed,
                turnStatement: storyTurns[turnIndex].draft.turnStatement,
                turnCharacter: storyTurns[turnIndex].draft.turnCharacter,
                turnLanding: StoryTurnLanding.resolve(storyTurns[turnIndex].draft.turnLandings, choiceID: choiceID) ?? ""
            )
            storyContinuationMessage = arc.isComplete
                ? "The vignette is ready to keep."
                : "The path has answered. Keep the page here, or ask for one more beat."
            BookFeedback.play(.braidComplete)
        } catch {
            guard storyTurns.indices.contains(turnIndex) else { return }
            storyTurns[turnIndex].generatedResults[choiceID] = context.fallbackResult
            storyContinuationMessage = "The chosen path answered softly, without waking the full local brain."
            BookFeedback.play(.error)
        }
    }

    @MainActor
    private func continueStoryPage(from draft: StoryPageSceneDraft, choice: StoryPageChoiceDraft) async {
        guard currentStoryArc?.isComplete != true else {
            storyContinuationMessage = "The vignette is already ready to keep."
            return
        }
        guard !isContinuingStoryPage, !isGeneratingStoryResult, !isLocalBrainWorking else {
            storyContinuationMessage = "The local brain is already writing. Let that ink dry first."
            return
        }
        isContinuingStoryPage = true
        storyContinuationMessage = "I'm writing one more beat."
        defer { isContinuingStoryPage = false }

        let context = StoryPageContinuationContext(turns: storyTurns, currentDraft: draft, selectedChoice: choice)
        let continuationSurface = draft.surface.storyContinuationCopy(context: context)

        func writeContinuation() async throws -> StoryPageProse {
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            return try await MLXStoryPageWriter().write(surface: continuationSurface)
            #else
            return try await FakeStoryPageWriter().write(surface: continuationSurface)
            #endif
        }

        do {
            var prose = try await writeContinuation()
            // Anti-degradation rail: reject a turn that shrank to fragments,
            // echoed the prior opening, or drifted to room-as-protagonist -
            // regenerate once before accepting it.
            let priorScene = draft.scene
            let names = draft.entities
            func acceptable(_ p: StoryPageProse) -> Bool {
                let s = p.scene
                let sentences = s.split { ".!?".contains($0) }.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).count > 3 }.count
                let words = s.split { $0 == " " || $0 == "\n" }.count
                let rejectsAtmosphere = draft.blueprint.map { $0.sceneMode == .conversation } ?? true
                return sentences >= 5 && words >= 110
                    && !StoryTurnValidator.isNearDuplicate(s, of: priorScene)
                    && (!rejectsAtmosphere || !StoryTurnValidator.isAtmosphereDominated(s, characterNames: names))
            }
            if !acceptable(prose), let retry = try? await writeContinuation(), acceptable(retry) {
                prose = retry
            }
            let nextSurface = continuationSurface.preparedStoryPageCopy(prose: prose, slotID: "continued-\(storyTurns.count + 1)")
            let nextDraft = StoryPageSceneDraft(surface: nextSurface)
            storyTurns.append(StoryPageSessionTurn(draft: nextDraft))
            selectedStoryChoice = nil
            storyContinuationMessage = "One more beat has surfaced. Choose how it lands."
            BookFeedback.play(.braidComplete)
        } catch {
            storyContinuationMessage = "The ink did not finish the next turn. The current page is still safe to keep."
            BookFeedback.play(.error)
        }
    }

    /// The current vignette's arc position, used to gate the single optional
    /// final beat.
    private var currentStoryArc: StoryArcShape? {
        guard let draft = storyTurns.last?.draft ?? storySceneDraft else { return nil }
        return StoryArcShape(
            beats: draft.formBeats,
            turnsWritten: max(storyTurns.count, 1),
            formName: draft.formName
        )
    }

    private var canKeep: Bool {
        if isPendingLetterPage || isPendingNotePage {
            return false
        }
        if isBookJumpPage, bookJumpAction == .start {
            return readerBeliefScore >= BookJumpEngine.startCost
        }
        #if canImport(UIKit)
        if isCameraFirstIlluminatedPage {
            if hasPendingCameraPhoto, manualPhotoDraft == nil, enchantmentResult == nil {
                return pendingCameraPhotoURL != nil
            }
            return manualPhotoDraft != nil || enchantmentResult != nil
        }
        #endif
        if isCompassRunStartPage {
            // Intake advances through its own one-question controls. The page's
            // toolbar action wakes only after the complete route is revealed.
            return isPreparedCompassRunStartPage
        }
        if let currentCompassStep, currentCompassStep != .write {
            // North, East, South, and Center are actions, not forms. West is
            // the one direction that asks the reader to bring back words.
            return true
        }
        if surface.isStoryPlayablePage {
            guard !isGeneratingStoryResult,
                  activeInkbonesThrow == nil,
                  let turn = storyTurns.last,
                  let choice = turn.selectedChoice,
                  storyNarrativeResultIsReady(choice, in: turn) else {
                return false
            }
            return true
        }
        if surface.type == .askTheBook {
            return !isAskingTheBook && !askTurns.isEmpty
        }
        if surface.type == .inkrestOfficeHours {
            return !isInkrestSitting && !inkrestTurns.isEmpty
        }
        if surface.type == .faeBargain {
            return !isFaePaying && !faeResponseText.isEmpty
        }
        if surface.payload.metadata["greyThreat"] == "true" {
            let status = surface.payload.metadata["greyThreatStatus"]
            guard status == GreyPageThreatStatus.fading.rawValue else { return false }
            if greyThreatChoice == "surrender" { return true }
            return greyThreatChoice == "rescue"
                && !greyRescueLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if surface.type == .twoReadings {
            return twoReadingsSide != nil
        }
        if surface.type == .tarot {
            guard let tarotReading else { return false }
            return !tarotReading.firstLook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !tarotReading.reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if isBookJumpPage {
            return !isBookJumpReturnPage || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if isEnchantmentPage {
            return !isCastingEnchantment && enchantmentResult != nil
        }
        if surface.type == .gamePage {
            return gameResultSurface != nil
        }
        if isAnchorOfferPage || isChapterBindingPage || isChapterPrimerPage {
            return false
        }
        if isPennySentenceMasteryPage {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if allowsCompassPhotoProof, proofPhotoURL != nil {
            return true
        }
        if isLocalBrainIssuePage {
            return false
        }
        if surface.type == .taleBound,
           surface.payload.metadata["taleUnavailable"] == "true" {
            return false
        }
        if isCompassRunStepPage, currentCompassStep != .write {
            return true
        }
        if currentCompassStep == .write {
            return !preparedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return isPreparedPage || !preparedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmitCompassRun: Bool {
        guard !isGeneratingCompassRun else { return false }
        if selectedCompassPlaceContext == .current {
            return !compassLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !compassCurrentPlaceMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var canAdvanceCompassConstraintStep: Bool {
        guard compassConstraintStep == .location else { return true }
        if selectedCompassPlaceContext == .current {
            return !compassLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !compassCurrentPlaceMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !compassLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmitManualCompassRun: Bool {
        guard !isGeneratingCompassRun else { return false }
        return !manualCompassSpark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !manualCompassDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !manualCompassDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !manualCompassMission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !manualCompassSouvenirPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentCompassStep: CompassRunStep? {
        guard isCompassRunStepPage,
              let rawValue = surface.payload.metadata["compassStep"],
              rawValue != "run" else {
            return nil
        }
        return CompassRunStep(rawValue: rawValue)
    }

    private var currentCompassNote: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldSaveCurrentCompassStep: Bool {
        guard let currentCompassStep else { return false }
        return currentCompassStep == .write && !currentCompassNote.isEmpty
    }

    private func nextCompassSurfaceAfterKeepingCurrentStep() -> SurfacePage? {
        guard let currentStep = currentCompassStep,
              let nextStep = nextCompassStep(after: currentStep) else {
            return nil
        }
        return compassStepSurface(from: surface, step: nextStep)
    }

    private func keepCompassStepAndAdvance() {
        let savedStep: (surface: SurfacePage, input: String, tags: [String])? = if shouldSaveCurrentCompassStep {
            (effectiveProofSurface, preparedInput, preparedTags)
        } else {
            nil
        }
        if let nextSurface = nextCompassSurfaceAfterKeepingCurrentStep() {
            onNavigateToSurface(nextSurface)
            if let savedStep {
                DispatchQueue.main.async {
                    onSave(savedStep.surface, savedStep.input, savedStep.tags, [])
                }
            }
        } else {
            let completedSurface = surface
            let outcome = compassPreparedInput(for: completedSurface)
            requestDismiss()
            DispatchQueue.main.async {
                if let savedStep {
                    onSave(savedStep.surface, savedStep.input, savedStep.tags, [])
                }
                onCompleteCompassRun(completedSurface)
                completeStoryMechanicIfNeeded(surface: completedSurface, outcome: outcome)
            }
        }
    }

    private func completeStoryMechanicIfNeeded(surface completedSurface: SurfacePage, outcome: String) {
        guard completedSurface.payload.metadata["storyMechanicReturn"] == "true" else { return }
        onStoryMechanicCompleted(completedSurface, outcome)
    }

    private func nextCompassStep(after step: CompassRunStep) -> CompassRunStep? {
        let steps = CompassRunStep.allCases
        guard let index = steps.firstIndex(of: step) else { return nil }
        let nextIndex = steps.index(after: index)
        return nextIndex < steps.endIndex ? steps[nextIndex] : nil
    }

    private func compassStepActionTitle(for step: CompassRunStep) -> String {
        if let next = nextCompassStep(after: step) {
            return "Continue to \(next.compassPoint): \(next.title)"
        }
        return "Complete Compass Run"
    }

    private func compassStepActionSymbol(for step: CompassRunStep) -> String {
        nextCompassStep(after: step) == nil ? "checkmark.seal" : "arrow.right.circle"
    }

    private func compassStepSurface(from base: SurfacePage, step: CompassRunStep) -> SurfacePage {
        var metadata = base.payload.metadata
        let existingTags = metadata["tags"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        metadata["compassStep"] = step.rawValue
        metadata["compassMode"] = "runStep"
        metadata["standalone"] = "false"
        metadata["runID"] = metadata["runID"] ?? base.id
        metadata["placeholder"] = step.capturePlaceholder
        metadata["symbol"] = compassSymbol(for: step)
        metadata["tags"] = Array(Set(existingTags + [
            "wonder-compass",
            "wonder-compass-run",
            "compass-step:\(step.rawValue)"
        ])).sorted().joined(separator: ",")

        let body: String
        switch step {
        case .notice:
            body = """
            North sets the bearing by turning curiosity into the goal.

            I wonder goal:
            \(metadata["spark"] ?? "I wonder what is asking for attention nearby?")

            Keep this and the question takes the reins. Send it away and North will sulk in private.
            """
        case .embark:
            body = """
            North made the goal:
            \(metadata["spark"] ?? "I wonder what is asking for attention nearby?")

            East makes the plan to fulfill that goal.

            Destination:
            \(metadata["destination"] ?? "")

            Delight:
            \(metadata["delight"] ?? "")

            Definition:
            \(metadata["definition"] ?? "")

            Cross one real threshold when this plan feels small enough to begin.
            """
        case .sense:
            body = """
            Keep North's goal in mind:
            \(metadata["spark"] ?? "I wonder what is asking for attention nearby?")

            Follow East's plan toward:
            \(metadata["destination"] ?? "")

            South puts you in your body when you reach the goal, or right at the start if this is a stay-put run.

            Mission:
            \(metadata["mission"] ?? "")

            Let your senses answer what the goal was asking.
            """
        case .write:
            body = """
            The run began with:
            \(metadata["spark"] ?? "I wonder what is asking for attention nearby?")

            The plan pointed toward:
            \(metadata["destination"] ?? "")

            West keeps the best sensory moment from the run in one sentence.

            Souvenir prompt:
            \(metadata["souvenirPrompt"] ?? "")

            Write that sentence in the text box below, then continue to Center: Rest.
            """
        case .rest:
            body = """
            You followed the Compass from a question into a body-memory.

            Rest:
            \(metadata["restPrompt"] ?? "Put the phone face down for sixty seconds and let the run land.")

            Keep this page after the quiet minute to complete the run. The Book's Glow will warm.
            """
        }

        let runID = metadata["runID"] ?? base.id
        return SurfacePage(
            id: "\(base.sourceID)-custom-run-\(runID)-\(step.rawValue)-\(Int(Date().timeIntervalSince1970))",
            type: .wonderCompass,
            sourceID: base.sourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: max(base.score, 62),
            reason: "The next Compass direction is ready.",
            prompt: "\(step.compassPoint): \(step.title)",
            detail: step.standaloneDetail,
            payload: BookPagePayload(
                headline: "\(step.compassPoint) = \(step.title)",
                body: body,
                metadata: metadata
            )
        )
    }

    private func compassSymbol(for step: CompassRunStep) -> String {
        switch step {
        case .notice:
            return "sparkle.magnifyingglass"
        case .embark:
            return "figure.walk"
        case .sense:
            return "hand.draw"
        case .write:
            return "pencil.and.scribble"
        case .rest:
            return "moon.stars"
        }
    }

    private var preparedInput: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if surface.payload.metadata["greyThreat"] == "true" {
            if greyThreatChoice == "rescue" {
                return greyRescueLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if greyThreatChoice == "surrender" {
                return "I let this Page leave the living Book."
            }
            return ""
        }
        if surface.type == .tarot {
            return tarotReading?.archiveText ?? ""
        }
        if isLocalBrainIssuePage {
            return ""
        }
        if surface.type == .taleBound {
            return surface.payload.body
        }
        if surface.isStoryPlayablePage {
            let turns = storyTurns.isEmpty
                ? [storySceneDraft.map { StoryPageSessionTurn(draft: $0, selectedChoice: selectedStoryChoice) }].compactMap { $0 }
                : storyTurns
            let threadText = turns.enumerated().map { index, turn in
                let choice = turn.selectedChoice
                return [
                    "Turn \(index + 1)",
                    turn.draft.scene,
                    choice.map { "Chosen path: \($0.title)" } ?? "Chosen path: unresolved",
                    choice.flatMap { selected in
                        turn.inkbonesResolution(for: selected).map { "Inkbones: \($0.mechanicSummary)" }
                    },
                    choice.map { turn.result(for: $0) } ?? "The page was kept before this turn chose a path."
                ].compactMap { $0 }.joined(separator: "\n\n")
            }.joined(separator: "\n\n---\n\n")
            let marginNote = trimmed.isEmpty ? "" : "\n\nMargin note: \(trimmed)"
            return threadText + marginNote
        }
        if surface.type == .gamePage, let gameResultSurface {
            return gameResultSurface.payload.body
        }
        if surface.type == .askTheBook {
            return askTurns.enumerated().map { index, turn in
                var sections = [
                    "Let’s Chat · \(index + 1)",
                    "Reader: \(turn.prompt)",
                    "Answer: \(turn.answer)"
                ]
                if let searchedCount = askSearchCountByTurnID[turn.id], searchedCount > 0 {
                    sections.append("Archive records searched: \(searchedCount)")
                }
                let evidence = askEvidenceByTurnID[turn.id] ?? []
                if !evidence.isEmpty {
                    let sources = evidence.map {
                        "\($0.authority.rawValue)|\($0.result.kind.rawValue)|\($0.result.referenceID)|\($0.result.title)"
                    }.joined(separator: "\n")
                    sections.append("Sources consulted:\n\(sources)")
                }
                return sections.joined(separator: "\n\n")
            }.joined(separator: "\n\n---\n\n")
        }
        if surface.type == .note, let noteText = noteProseText {
            let marginNote = trimmed.isEmpty ? "" : "\n\nMargin note: \(trimmed)"
            return noteText + marginNote
        }
        if isBookJumpPage {
            let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
            var sections = [surface.payload.body]
            if isBookJumpReturnPage {
                sections.append("Souvenir: \(note)")
            } else if !note.isEmpty {
                sections.append("Margin note: \(note)")
            }
            return sections.joined(separator: "\n\n")
        }
        if surface.type == .twoReadings {
            let metadata = surface.payload.metadata
            var sections: [String] = [surface.payload.body]
            if let side = twoReadingsSide {
                let aID = metadata["entityAID"] ?? ""
                let name = side == aID ? (metadata["entityAName"] ?? "") : (metadata["entityBName"] ?? "")
                sections.append("You sided with \(name).")
            }
            let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty { sections.append("Your note: \(note)") }
            return sections.joined(separator: "\n\n")
        }
        if surface.type == .castBond {
            let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if note.isEmpty {
                return surface.payload.body
            }
            return "\(surface.payload.body)\n\nMargin note: \(note)"
        }
        if surface.type == .faeBargain {
            let metadata = surface.payload.metadata
            var sections: [String] = ["A Fae Bargain: \(metadata["faeName"] ?? "a Book Fae")"]
            sections.append(metadata["openingGesture"] ?? surface.payload.body)
            if let gift = metadata["giftName"], !gift.isEmpty {
                sections.append("They fronted you \(gift): \(metadata["giftEffectLine"] ?? "")")
            }
            sections.append("What you owed: \(metadata["terms"] ?? surface.detail)")
            let report = faeReport.trimmingCharacters(in: .whitespacesAndNewlines)
            if !report.isEmpty {
                sections.append("Your field report: \(report)")
            }
            if !faeResponseText.isEmpty {
                sections.append("\(metadata["faeName"] ?? "The Fae") answered:\n\(faeResponseText)")
            }
            return sections.joined(separator: "\n\n---\n\n")
        }
        if surface.type == .inkrestOfficeHours {
            var sections: [String] = ["Dr. Inkrest's Office Hours"]
            let lensQuestion = inkrestIntake.rotatingQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !lensQuestion.isEmpty {
                sections.append("Tonight's question (\(inkrestIntake.lens)): \(lensQuestion)")
            }
            sections.append(contentsOf: inkrestTurns.map { turn in
                [
                    "You: \(turn.prompt)",
                    "Dr. Inkrest: \(turn.answer)"
                ].joined(separator: "\n\n")
            })
            return sections.joined(separator: "\n\n---\n\n")
        }
        if surface.type == .calendar {
            let metadata = surface.payload.metadata
            let eventTitle = metadata["eventTitle"] ?? surface.detail
            let eventTime = metadata["eventTime"] ?? ""
            let phase = metadata["hourPhaseTitle"] ?? "Hour Page"
            let question = metadata["hourQuestion"] ?? surface.prompt
            var sections = [
                phase,
                eventTime.isEmpty ? eventTitle : "\(eventTitle) at \(eventTime)",
                "Question: \(question)"
            ].filter { !$0.isEmpty }.joined(separator: "\n\n")
            if !trimmed.isEmpty {
                sections += "\n\nReader: \(trimmed)"
            }
            return sections
        }
        if surface.type == .radio {
            let unlocked = Set(PlayerVault.shared.data.ownedPacks ?? [])
            let station = RadioStationRegistry.station(
                id: radioManager.playback.activeStationID ?? selectedRadioStationID ?? surface.payload.metadata["radioStationID"],
                unlockedPackIDs: unlocked
            )
            let note = trimmed.isEmpty ? "No margin note. The station itself was the kept weather." : trimmed
            return [
                "ReEnchanted Radio",
                station.map { "\($0.displayFrequency) FM: \($0.title)" } ?? surface.payload.headline,
                station?.signalLine ?? surface.payload.body,
                station.map(radioWorldEffectLine),
                "Listening note: \(note)"
            ].compactMap { $0 }.joined(separator: "\n\n")
        }
        if isEnchantmentPage || currentEnchantmentSurface != nil {
            let resultText = enchantmentResult.map { result in
                [
                    "Enchantment: \(result.spellName)",
                    "Subject: \(result.subjectName)",
                    result.openingLine,
                    result.resultText
                ].joined(separator: "\n\n")
            } ?? currentEnchantmentSurface?.payload.body ?? surface.payload.body
            let conversation = enchantmentTurns.isEmpty ? "" : "\n\nConversation:\n" + enchantmentTurns.enumerated().map { index, turn in
                [
                    "Turn \(index + 1)",
                    "Reader: \(turn.prompt)",
                    "Subject: \(turn.answer)"
                ].joined(separator: "\n")
            }.joined(separator: "\n\n---\n\n")
            let renderLine = renderedIlluminatedPageURL.map { "\n\nRendered plate: \($0.lastPathComponent)" } ?? ""
            let marginNote = trimmed.isEmpty ? "" : "\n\nMargin note: \(trimmed)"
            return resultText + conversation + renderLine + marginNote
        }
        if isPennySentenceMasteryPage {
            let lessonTitle = activePennySentenceLesson?.title ?? surface.payload.metadata["pennySentenceLessonTitle"] ?? "Sentence mastery"
            return [
                surface.payload.headline,
                surface.payload.body,
                "Filed sentence (\(lessonTitle)):",
                trimmed
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        }
        if isPreparedPage {
            if surface.type == .aboutYou, surface.payload.metadata["earnedLabel"] == "true" {
                return surface.payload.metadata["earnedLabelName"] ?? surface.payload.body
            }
            if isCompassPracticePage {
                if currentCompassStep == .write {
                    return trimmed
                }
                let marginNote = trimmed.isEmpty ? "" : "\n\nMargin note: \(trimmed)"
                return compassPreparedInput + marginNote
            }
            if surface.type == .illuminatedPhoto, let illuminatedDraft {
                let manualNote = trimmed.isEmpty ? "" : "\n\nMargin note: \(trimmed)"
                let renderLine = renderedIlluminatedPageURL.map { "\n\nRendered plate: \($0.lastPathComponent)" } ?? ""
                return [
                    illuminatedDraft.analysis.scene,
                    illuminatedDraft.analysis.marginalia.fieldNote,
                    illuminatedDraft.analysis.marginalia.observationList.joined(separator: "\n"),
                    illuminatedDraft.analysis.marginalia.closingLine
                ].joined(separator: "\n\n") + renderLine + manualNote
            }
            if surface.type == .theBleed {
                let body = bleedEditionText ?? surface.payload.body
                guard !trimmed.isEmpty else {
                    return body
                }
                return "\(body)\n\nMargin note: \(trimmed)"
            }
            guard !trimmed.isEmpty else {
                return surface.payload.body
            }
            return "\(surface.payload.body)\n\nMargin note: \(trimmed)"
        }
        guard surface.type == .mood, !selectedWeather.isEmpty else {
            return trimmed
        }
        if trimmed.isEmpty {
            return selectedWeather
        }
        return "\(selectedWeather): \(trimmed)"
    }

    private var compassPreparedInput: String {
        compassPreparedInput(for: surface)
    }

    private func compassPreparedInput(for preparedSurface: SurfacePage) -> String {
        let metadata = preparedSurface.payload.metadata
        let step = metadata["compassStep"] ?? "run"
        if step == "run" {
            let lines: [String?] = [
                "Wonder Compass Run",
                "Location: \(compassValue(compassLocation, fallback: metadata["place"] ?? "unknown"))",
                "Place Kind: \(metadata["placeContext"] ?? selectedCompassPlaceContext.title)",
                compassAnchorPreparedLine(from: metadata),
                "Time Limit: \(compassValue(compassTimeLimit, fallback: metadata["timeBox"] ?? "unknown"))",
                "Energy: \(compassValue(compassEnergy, fallback: metadata["energy"] ?? "unknown"))",
                "Who is with me: \(compassValue(compassCompanions, fallback: metadata["companions"] ?? "unknown"))",
                "Budget: \(compassValue(compassBudget, fallback: metadata["budget"] ?? "unknown"))",
                "Special Needs/Considerations: \(compassValue(selectedCompassConsiderations, fallback: metadata["considerations"] ?? "unknown"))",
                "",
                "NORTH (NOTICE)",
                metadata["spark"],
                "",
                "EAST (EMBARK)",
                "Destination: \(metadata["destination"] ?? "")",
                "Delight: \(metadata["delight"] ?? "")",
                "Definition: \(metadata["definition"] ?? "")",
                "",
                "SOUTH (SENSE)",
                metadata["mission"],
                "",
                "WEST (WRITE)",
                metadata["souvenirPrompt"],
                "",
                "CENTER (REST)",
                metadata["restPrompt"]
            ]
            return lines
            .compactMap { $0 }
            .joined(separator: "\n")
        }
        if preparedSurface.id == surface.id, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return preparedSurface.payload.metadata["placeholder"] ?? preparedSurface.payload.body
    }

    private func compassAnchorPreparedLine(from metadata: [String: String]) -> String? {
        guard let name = metadata["anchorName"]?.nonEmpty else { return nil }
        let kind = metadata["anchorKind"]?.nonEmpty
        let distance = metadata["anchorDistanceMeters"]?.nonEmpty.map { "\($0)m" }
        let details = [kind, distance].compactMap { $0 }.joined(separator: ", ")
        return details.isEmpty ? "Anchor: \(name)" : "Anchor: \(name) (\(details))"
    }

    private func compassValue(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private var preparedTags: [String] {
        preparedTags(for: effectiveProofSurface)
    }

    private func preparedTags(for preparedSurface: SurfacePage) -> [String] {
        let metadataTags = preparedSurface.payload.metadata["tags"]?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            ?? []

        var tags = metadataTags
        // The reader's own hand on the shelf. Last word, both directions.
        if let shelfTag = shelfMark.tag {
            tags.append(shelfTag)
        }
        if preparedSurface.payload.metadata["greyThreat"] == "true",
           let threatID = preparedSurface.payload.metadata["greyThreatID"] {
            tags.append("grey-threat")
            tags.append("grey-threat:\(threatID)")
            if greyThreatChoice == "rescue" {
                tags.append("grey-threat-rescued")
            } else if greyThreatChoice == "surrender" {
                tags.append("grey-threat-surrendered")
            }
        }
        if preparedSurface.type == .tarot, let tarotReading {
            tags.append("tarot")
            tags.append("tarot-spread:\(tarotReading.spread.rawValue)")
            tags.append(contentsOf: tarotReading.cards.map { "tarot-card:\($0.cardID)" })
        }
        if let source = preparedSurface.payload.metadata["source"], !source.isEmpty {
            tags.append(source)
        }
        if let status = preparedSurface.payload.metadata["status"], !status.isEmpty {
            tags.append(status.lowercased())
        }
        if let facultyID = preparedSurface.payload.metadata["facultyID"], !facultyID.isEmpty {
            tags.append(facultyID)
        }
        if let facultyKind = preparedSurface.payload.metadata["facultyKind"], !facultyKind.isEmpty {
            tags.append("faculty-kind:\(facultyKind)")
        }
        if let facultyWindowID = preparedSurface.payload.metadata["facultyWindowID"], !facultyWindowID.isEmpty {
            tags.append("faculty-window:\(facultyWindowID)")
        }
        if preparedSurface.type == .illuminatedPhoto {
            tags.append("illuminated-photo")
            tags.append(manualPhotoImage == nil ? "book-chosen" : "manual-photo")
            if let template = illuminatedDraft?.compositionPlan.templateId.rawValue {
                tags.append(template)
            }
            if renderedIlluminatedPageURL != nil {
                tags.append("rendered")
            }
        }
        if preparedSurface.type == .enchantment || preparedSurface.payload.metadata["source"] == "enchantment" {
            tags.append("enchantment")
            tags.append("illuminated-photo")
            if let spellID = preparedSurface.payload.metadata["enchantmentID"] {
                tags.append("enchantment:\(spellID)")
            }
            if let turns = preparedSurface.payload.metadata["enchantmentTurns"], turns != "0" {
                tags.append("enchantment-turns:\(turns)")
            }
        }
        if preparedSurface.isStoryPlayablePage {
            switch preparedSurface.type {
            case .bookFae:
                tags.append("book-fae")
            case .anchor:
                tags.append("anchor")
                tags.append("outer-stacks")
                if let anchorID = preparedSurface.payload.metadata["anchorID"], !anchorID.isEmpty {
                    tags.append("anchor:\(anchorID)")
                }
            default:
                tags.append(preparedSurface.type == .academyClass ? "academy-class" : "narrative-os")
            }
            if let selectedStoryChoice {
                tags.append("choice:\(selectedStoryChoice.id)")
                if let draft = storySceneDraft {
                    let closureText = [
                        selectedStoryChoice.title,
                        selectedStoryChoice.prompt,
                        selectedStoryChoice.effectLine,
                        draft.result(for: selectedStoryChoice)
                    ].joined(separator: " ")
                    tags.append(contentsOf: StoryChoiceClosure.tags(
                        chosenChoiceID: selectedStoryChoice.id,
                        availableChoiceIDs: draft.choices.map(\.id),
                        chosenText: closureText
                    ))
                }
                if storyTurns.isEmpty,
                   let draft = storySceneDraft,
                   let contract = draft.dramaticContract,
                   let effect = contract.effect(for: selectedStoryChoice.id),
                   let receipt = StoryDramaticOutcomeReceipt(
                       contract: contract,
                       effect: effect,
                       turnKind: draft.blueprint?.turn.kind ?? .smallDecision
                   ).encodedTag {
                    tags.append(receipt)
                }
            }
            for turn in storyTurns {
                if let choice = turn.selectedChoice {
                    tags.append("choice:\(choice.id)")
                    let closureText = [
                        choice.title,
                        choice.prompt,
                        choice.effectLine,
                        turn.result(for: choice)
                    ].joined(separator: " ")
                    tags.append(contentsOf: StoryChoiceClosure.tags(
                        chosenChoiceID: choice.id,
                        availableChoiceIDs: turn.draft.choices.map(\.id),
                        chosenText: closureText
                    ))
                    if let contract = turn.draft.dramaticContract,
                       let effect = contract.effect(for: choice.id),
                       let receipt = StoryDramaticOutcomeReceipt(
                           contract: contract,
                           effect: effect,
                           turnKind: turn.draft.blueprint?.turn.kind ?? .smallDecision
                       ).encodedTag {
                        tags.append(receipt)
                    }
                    if let resolution = turn.inkbonesResolution(for: choice) {
                        tags.append("story-mechanic:belief-dice")
                        tags.append("inkbones-band:\(resolution.band.rawValue)")
                        tags.append("inkbones-roll:\(resolution.roll)")
                        tags.append("inkbones-threshold:\(resolution.threshold)")
                    }
                }
            }
            tags.append("story-turns:\(max(storyTurns.count, 1))")
            if let recipeID = preparedSurface.payload.metadata["storyRecipeID"]?.nonEmpty {
                tags.append("story-recipe:\(recipeID)")
            }
            // Carry the scene's cast into the kept page so those entities
            // mint memories of what happened to them in this Story Page.
            let entityIDs = (preparedSurface.payload.metadata["selectedEntityIDs"]
                ?? preparedSurface.payload.metadata["selectedEntities"]
                ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-") }
                .filter { !$0.isEmpty }
            for entityID in entityIDs.prefix(4) {
                tags.append("entity:\(entityID)")
            }
            let threadIDs = (preparedSurface.payload.metadata["selectedThreadIDs"]
                ?? preparedSurface.payload.metadata["selectedThreads"]
                ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-") }
                .filter { !$0.isEmpty }
            for threadID in threadIDs.prefix(3) {
                tags.append("thread:\(threadID)")
            }
            let consequenceProbe = BookPage(
                type: preparedSurface.type,
                promptText: preparedSurface.prompt,
                userInput: preparedInput,
                tags: tags,
                sourceID: preparedSurface.sourceID,
                origin: preparedSurface.origin,
                privacy: preparedSurface.privacy
            )
            for consequence in StoryConsequenceResolver.resolvedConsequences(forKept: consequenceProbe) {
                tags.append(contentsOf: consequence.eventTags)
            }
        }
        if preparedSurface.type == .gossip {
            tags.append("gossip-page")
        }
        if preparedSurface.type == .theBleed {
            tags.append("the-bleed")
            if let slotID = preparedSurface.payload.metadata["bleedSlotID"], !slotID.isEmpty {
                tags.append(slotID)
            }
            if let kind = preparedSurface.payload.metadata["bleedEditionKind"], !kind.isEmpty {
                tags.append("bleed:\(kind)")
            }
        }
        if preparedSurface.type == .radio {
            tags.append("radio")
            tags.append("music")
            if let stationID = radioManager.playback.activeStationID ?? selectedRadioStationID ?? preparedSurface.payload.metadata["radioStationID"], !stationID.isEmpty {
                tags.append("radio-station:\(stationID)")
            }
            if let frequency = preparedSurface.payload.metadata["radioFrequency"], !frequency.isEmpty {
                tags.append("radio-frequency:\(frequency)")
            }
        }
        if preparedSurface.type == .askTheBook {
            tags.append("ask-chain")
            tags.append("turns:\(askTurns.count)")
        }
        if preparedSurface.type == .twoReadings {
            tags.append("two-readings")
            if let side = twoReadingsSide {
                tags.append("sided:\(side)")
                tags.append("\(StoryChoiceClosure.chosenPrefix)\(side)")
                let metadata = preparedSurface.payload.metadata
                let other = side == metadata["entityAID"]
                    ? metadata["entityBID"]
                    : metadata["entityAID"]
                if let other = other?.nonEmpty {
                    tags.append("\(StoryChoiceClosure.closedPrefix)\(other)")
                }
            }
        }
        if preparedSurface.type == .bookJump {
            tags.append("book-jump")
            if let action = preparedSurface.payload.metadata["bookJumpAction"], !action.isEmpty {
                tags.append("book-jump:\(action)")
            }
            if let bookID = preparedSurface.payload.metadata["bookID"], !bookID.isEmpty {
                tags.append("book:\(bookID)")
            }
        }
        if preparedSurface.type == .castBond {
            tags.append("cast-bond")
            if let kind = preparedSurface.payload.metadata["bondKind"], !kind.isEmpty {
                tags.append(kind)
            }
            if let firedKey = preparedSurface.payload.metadata["bondFiredKey"], !firedKey.isEmpty {
                tags.append("cast-bond:\(firedKey)")
            }
            if let aID = preparedSurface.payload.metadata["entityAID"], !aID.isEmpty {
                tags.append("entity:\(aID)")
            }
            if let bID = preparedSurface.payload.metadata["entityBID"], !bID.isEmpty {
                tags.append("entity:\(bID)")
            }
        }
        if preparedSurface.type == .faeBargain {
            tags.append("fae-bargain")
            tags.append("attention")
            if let kind = preparedSurface.payload.metadata["faeKind"], !kind.isEmpty {
                tags.append("fae:\(kind)")
            }
            if preparedSurface.payload.metadata["hasMovedOn"] == "true" {
                tags.append("fae-moved-on")
            }
        }
        if preparedSurface.type == .inkrestOfficeHours {
            tags.append("inkrest-office-hours")
            tags.append("dr-inkrest")
            tags.append("therapy-chart")
            tags.append("narrative-therapy")
            tags.append("faculty:dr-inkrest")
            tags.append("lens:\(inkrestIntake.lens)")
            tags.append("exchanges:\(inkrestTurns.count)")
            if let slot = preparedSurface.payload.metadata["slot"], !slot.isEmpty {
                tags.append("inkrest-office-hours:\(slot)")
            }
        }
        if preparedSurface.type == .calendar {
            tags.append("hour-page")
            if let phase = preparedSurface.payload.metadata["hourPhase"], !phase.isEmpty {
                tags.append("hour:\(phase)")
            }
            if let eventID = preparedSurface.payload.metadata["eventID"], !eventID.isEmpty {
                tags.append("calendar-event:\(eventID)")
            }
        }
        if preparedSurface.type == .wonderCompass,
           let lessonID = preparedSurface.payload.metadata["pennySentenceLesson"], !lessonID.isEmpty {
            tags.append("wonder-compass")
            tags.append("wonder-compass:chapter-9")
            tags.append("west-write")
            tags.append("penny-blackletter")
            tags.append("sentence-mastery")
            tags.append("sentence-builder")
            tags.append("sentence-lesson:\(lessonID)")
        }
        if preparedSurface.type == .wonderCompass, let runID = preparedSurface.payload.metadata["runID"] {
            tags.append("wonder-compass")
            tags.append("wonder-compass-run")
            tags.append("compass-run:\(runID)")
            if let step = preparedSurface.payload.metadata["compassStep"], step != "run" {
                tags.append("compass-step:\(step)")
            }
            if let mode = preparedSurface.payload.metadata["conciergeMode"] {
                tags.append("concierge:\(mode)")
            }
            if let authoringMode = preparedSurface.payload.metadata["runAuthoringMode"] {
                tags.append("compass-run:\(authoringMode)")
            }
        }
        if preparedSurface.payload.metadata["storyMechanicReturn"] == "true" {
            tags.append("story-mechanic")
            if let mechanic = preparedSurface.payload.metadata["storyMechanicKind"] {
                tags.append("story-mechanic:\(mechanic)")
            }
            if let choice = preparedSurface.payload.metadata["storyChoiceID"] {
                tags.append("choice:\(choice)")
            }
            if let enchantmentID = preparedSurface.payload.metadata["storyEnchantmentID"] {
                tags.append("enchantment:\(enchantmentID)")
            }
            if let tier = preparedSurface.payload.metadata["storyMechanicOutcomeTier"] {
                tags.append("clash-outcome:\(tier)")
            }
        }
        if preparedSurface.payload.metadata["storyRecipePackID"] == "unquiet-folio" {
            tags.append("clash")
            if let recipeID = preparedSurface.payload.metadata["storyRecipeID"]?.nonEmpty {
                tags.append("clash:\(recipeID)")
            }
        }
        if preparedSurface.type == .mood, !selectedWeather.isEmpty {
            tags.append(selectedWeather.lowercased())
        }
        return Array(Set(tags)).sorted()
    }

    @MainActor
    private func generateAndSaveCompassRun() async {
        guard !isGeneratingCompassRun else { return }
        isGeneratingCompassRun = true
        compassGenerationMessage = "Gemma is drawing a custom Compass Run from your constraints."
        defer { isGeneratingCompassRun = false }

        let constraints = compassRunConstraints()
        let plan: [String: String]
        do {
            let response = try await generateCompassRunWithGemma(constraints: constraints)
            plan = parseCompassRunPlan(response, constraints: constraints)
            compassGenerationMessage = ""
        } catch {
            plan = fallbackCompassRunPlan(constraints: constraints)
            compassGenerationMessage = "Gemma did not finish, so I made a local run from the same constraints."
        }

        let savedSurface = surface.withCompassRunPlan(plan, constraints: constraints)
        let input = compassPreparedInput(for: savedSurface)
        let tags = preparedTags(for: savedSurface)
        onNavigateToSurface(savedSurface)
        DispatchQueue.main.async {
            onSave(savedSurface, input, tags, [])
        }
    }

    private func saveManualCompassRun() {
        guard canSubmitManualCompassRun else { return }
        let constraints = compassRunConstraints()
            .merging([
                "runAuthoringMode": "manual",
                "selector": "manual-custom-run"
            ]) { _, new in new }
        let savedSurface = surface.withCompassRunPlan(manualCompassRunPlan(), constraints: constraints)
        let input = compassPreparedInput(for: savedSurface)
        let tags = preparedTags(for: savedSurface)
        onNavigateToSurface(savedSurface)
        DispatchQueue.main.async {
            onSave(savedSurface, input, tags, [])
        }
    }

    private func manualCompassRunPlan() -> [String: String] {
        [
            "spark": compassValue(manualCompassSpark, fallback: "I wonder what is asking for attention nearby?"),
            "destination": compassValue(manualCompassDestination, fallback: "one real threshold nearby"),
            "delight": compassValue(manualCompassDelight, fallback: "one small comfort that helps the run begin"),
            "definition": compassValue(manualCompassDefinition, fallback: "finish when the North question has one answer"),
            "mission": compassValue(manualCompassMission, fallback: "Let the body answer the North question through one sound, one color, and one texture."),
            "souvenirPrompt": compassValue(manualCompassSouvenirPrompt, fallback: "Write the best sensory moment from the run in one sentence."),
            "restPrompt": compassValue(manualCompassRestPrompt, fallback: "Put the phone face down for 60 seconds and let the run land."),
            "hint": "You wrote this run. Keep it small enough to actually do."
        ]
    }

    private func compassRunConstraints() -> [String: String] {
        let context = selectedCompassPlaceContext
        let location = compassLocation.nonEmpty ?? context.promptValue
        var constraints = [
            "location": compassValue(location, fallback: surface.payload.metadata["place"] ?? context.promptValue),
            "placeContext": context.title,
            "placeContextID": context.rawValue,
            "nearbyPlaces": currentNearbyPlacesText,
            "timeLimit": compassValue(compassTimeLimit, fallback: surface.payload.metadata["timeBox"] ?? "10-20 minutes"),
            "energy": compassValue(compassEnergy, fallback: surface.payload.metadata["energy"] ?? "ordinary tired adult"),
            "companions": compassValue(compassCompanions, fallback: surface.payload.metadata["companions"] ?? "solo"),
            "budget": compassValue(compassBudget, fallback: surface.payload.metadata["budget"] ?? "$0"),
            "considerations": compassValue(selectedCompassConsiderations, fallback: surface.payload.metadata["considerations"] ?? "no special constraints known")
        ]
        if let proximity = compassAnchorProximity {
            let anchor = proximity.anchor
            constraints["anchorName"] = anchor.name
            constraints["anchorKind"] = anchor.kind.title
            constraints["anchorDistanceMeters"] = "\(Int(proximity.distanceMeters.rounded()))"
            constraints["anchorRoom"] = anchor.outerStacksRoom
            constraints["anchorFae"] = anchor.fae
            constraints["anchorLocalRule"] = anchor.localRule
            constraints["anchorVisitMode"] = proximity.visitMode
            constraints["anchorMiniStory"] = anchor.miniStory
            constraints["anchorAcademyEcho"] = anchor.academyEcho
        } else {
            for key in [
                "anchorName",
                "anchorKind",
                "anchorDistanceMeters",
                "anchorRoom",
                "anchorFae",
                "anchorLocalRule",
                "anchorVisitMode",
                "anchorMiniStory",
                "anchorAcademyEcho"
            ] {
                if let value = surface.payload.metadata[key]?.nonEmpty {
                    constraints[key] = value
                }
            }
        }
        return constraints
    }

    private var compassVentureMode: CompassVentureMode {
        let places = currentNearbyPlacesText.nonEmpty
        let seed = [
            surface.id,
            compassLocation,
            compassPlaceContextID,
            compassTimeLimit,
            compassEnergy,
            compassCompanions,
            compassBudget,
            selectedCompassConsiderations
        ].joined(separator: "|")
        return CompassVenture.decide(
            energyText: compassEnergy.isEmpty ? (surface.payload.metadata["energy"] ?? "") : compassEnergy,
            considerations: selectedCompassConsiderations,
            timeLimit: compassTimeLimit.isEmpty ? (surface.payload.metadata["timeBox"] ?? "") : compassTimeLimit,
            hasPlaces: places != nil,
            roll: CompassVenture.deterministicRoll(seed: seed)
        )
    }

    private func ventureSection(for mode: CompassVentureMode) -> String {
        switch mode {
        case .homebound:
            return """
            VENTURE READING: The energy says stay. The entire cycle must work without leaving home: the EAST Destination is a room, chair, window, doorway, or patch of light INSIDE or just outside the door. Never name an outside place. The adventure is depth, not distance.
            """
        case .neighborhood:
            return """
            VENTURE READING: There is fuel for the block, not for a trip. The EAST Destination should be within a few minutes of the front door, described by KIND ("the nearest tree older than the house", "the corner with the loudest birds"), never by a business name. Do not invent named places.
            """
        case .destination:
            let places = currentNearbyPlacesText
            return """
            VENTURE READING: There is real fuel today: this run may go somewhere true.
            REAL PLACES NEARBY (verified to exist; the only named places you may use):
            \(places)
            Choose ONE whose nature honestly fits the time limit, budget, and considerations, set the EAST Destination to its real name, and shape the SOUTH mission to what that place actually is (a bakery's mission smells; a hardware store's mission is texture and weight). If none fits, fall back to an unnamed nearby kind of place. Never invent a named place.
            """
        }
    }

    private func compassAnchorPrompt(from constraints: [String: String]) -> String {
        guard let name = constraints["anchorName"]?.nonEmpty else {
            return "No known Anchor is active at this place."
        }
        let kind = constraints["anchorKind"]?.nonEmpty ?? "Anchor"
        let distance = constraints["anchorDistanceMeters"]?.nonEmpty.map { "\($0)m away" } ?? "nearby"
        let room = constraints["anchorRoom"]?.nonEmpty ?? constraints["anchorAcademyEcho"]?.nonEmpty ?? "The Anchor has local memory."
        let fae = constraints["anchorFae"]?.nonEmpty ?? "the place's keeper"
        let rule = constraints["anchorLocalRule"]?.nonEmpty ?? "notice before asking for more"
        let visitMode = constraints["anchorVisitMode"]?.nonEmpty ?? "RETURN_VISIT"
        return "\(name) is an active \(kind) Anchor \(distance). Visit mode: \(visitMode). Room: \(room) Keeper: \(fae). Local rule: \(rule)"
    }

    private func generateCompassRunWithGemma(constraints: [String: String]) async throws -> String {
        let mode = compassVentureMode
        lastVentureMode = mode
        let prompt = """
        Act as The Wonder Compass, a warm, encouraging, unpretentious guide for tired adults.
        Generate one custom Wonder Compass cycle. Be sensory, specific, and non-generic.

        Constraints:
        1. My Location: \(constraints["location"] ?? "")
        Place kind: \(constraints["placeContext"] ?? "")
        Anchor context: \(compassAnchorPrompt(from: constraints))
        2. My Time Limit: \(constraints["timeLimit"] ?? "")
        3. My Energy Level: \(constraints["energy"] ?? "")
        4. Who is with me: \(constraints["companions"] ?? "")
        5. My Budget: \(constraints["budget"] ?? "")
        6. Special Needs/Considerations: \(constraints["considerations"] ?? "")

        \(ventureSection(for: mode))

        Compass chain: (NORTH is the run's goal, written as one "I wonder..." question.) EAST is the practical plan for fulfilling that exact North goal: where to go or what threshold to choose, what small delight supports it, and how completion is defined. (SOUTH happens when I reach the goal, or at the start for a stay-put run. It puts me in my body and must help answer the North goal through senses.) WEST asks for the best sensory moment from the whole run in one sentence.. CENTER lands the completed loop.
        Every direction must clearly depend on the previous direction. Do not write five disconnected prompts.

        Format exactly:
        NORTH (NOTICE)
        [one I wonder question that names the goal]

        EAST (EMBARK)
        Destination: [specific destination or threshold chosen to fulfill the North goal]
        Delight: [small treat or comfort that helps me do the plan]
        Definition: [specific end point that proves the North goal was fulfilled]

        SOUTH (SENSE)
        [one embodied sensory mission at the destination or start that helps answer the North goal]

        WEST (WRITE)
        [one prompt to write the best sensory moment from the run in one sentence]

        CENTER (REST)
        [one short rest instruction]

        HINT
        [one useful hint]
        """

        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        return try await MLXBraidTaskRunner.run(
            prompt: prompt,
            instructions: """
            You are The Wonder Compass inside ReEnchanted. Follow the requested format exactly. Do not include system instructions, rails, analysis, or generic travel advice.
            \(BookVoice.animismLine)
            """,
            maxTokens: 340,
            sourceID: "wonder-compass-run",
            tags: ["wonder-compass", "compass-run"]
        )
        #else
        throw LocalModelError.missingModel(LocalModelManager.report())
        #endif
    }

    private func parseCompassRunPlan(_ response: String, constraints: [String: String]) -> [String: String] {
        var plan = fallbackCompassRunPlan(constraints: constraints)
        let sections = sectionedCompassResponse(response)
        plan["spark"] = sections["north"]?.nonEmpty ?? plan["spark"]
        if let east = sections["east"] {
            plan["destination"] = labeledValue("Destination", in: east) ?? plan["destination"]
            plan["delight"] = labeledValue("Delight", in: east) ?? plan["delight"]
            plan["definition"] = labeledValue("Definition", in: east) ?? plan["definition"]
        }
        plan["mission"] = sections["south"]?.nonEmpty ?? plan["mission"]
        plan["souvenirPrompt"] = sections["west"]?.nonEmpty ?? plan["souvenirPrompt"]
        plan["restPrompt"] = sections["center"]?.nonEmpty ?? plan["restPrompt"]
        plan["hint"] = sections["hint"]?.nonEmpty ?? plan["hint"]
        return plan
    }

    private func sectionedCompassResponse(_ response: String) -> [String: String] {
        let markers: [(key: String, pattern: String)] = [
            ("north", "NORTH (NOTICE)"),
            ("east", "EAST (EMBARK)"),
            ("south", "SOUTH (SENSE)"),
            ("west", "WEST (WRITE)"),
            ("center", "CENTER (REST)"),
            ("hint", "HINT")
        ]
        var found: [(key: String, range: Range<String.Index>)] = []
        for marker in markers {
            if let range = response.range(of: marker.pattern, options: [.caseInsensitive]) {
                found.append((marker.key, range))
            }
        }
        found.sort { $0.range.lowerBound < $1.range.lowerBound }
        var sections: [String: String] = [:]
        for index in found.indices {
            let start = found[index].range.upperBound
            let end = index == found.index(before: found.endIndex) ? response.endIndex : found[found.index(after: index)].range.lowerBound
            sections[found[index].key] = String(response[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return sections
    }

    private func labeledValue(_ label: String, in text: String) -> String? {
        let lines = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let prefix = "\(label):"
        return lines.first { $0.localizedCaseInsensitiveContains(prefix) }?
            .replacingOccurrences(of: prefix, with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private func fallbackCompassRunPlan(constraints: [String: String]) -> [String: String] {
        let location = constraints["location"] ?? "where you are"
        let time = constraints["timeLimit"] ?? "10-20 minutes"
        let context = constraints["placeContextID"].flatMap(CompassPlaceContext.init(rawValue:)) ?? .current
        let lowEnergy = lastVentureMode == .homebound
        if let anchorName = constraints["anchorName"]?.nonEmpty {
            let anchorRoom = constraints["anchorRoom"]?.nonEmpty
                ?? constraints["anchorAcademyEcho"]?.nonEmpty
                ?? "the room that knows this place"
            let keeper = constraints["anchorFae"]?.nonEmpty ?? "the place's keeper"
            let rule = constraints["anchorLocalRule"]?.nonEmpty ?? "notice before asking for more"
            let visitMode = constraints["anchorVisitMode"]?.nonEmpty ?? "RETURN_VISIT"
            let mission = visitMode == "FIRST_VISIT"
                ? "Introduce yourself to \(anchorName) without saying your name: notice one edge, one sound, and one object that seems to be guarding the room. Then honor the rule: \(rule)."
                : "Find one detail proving \(anchorName) changed since the last visit. Ask what \(keeper) wants noticed, then honor the rule: \(rule)."
            return [
                "spark": "I wonder what \(anchorName) remembered about me before I noticed it?",
                "destination": lowEnergy ? "the gentlest threshold inside \(anchorName)" : "\(anchorName): the Anchor already awake here",
                "delight": lowEnergy ? "water, softer light, or one comfortable place to sit" : "one tiny offering that suits \(anchorName): warmth, quiet, a favorite sip, or a careful look",
                "definition": "the North question is complete after \(time), or when the Anchor gives one remembered detail",
                "mission": mission,
                "souvenirPrompt": "Write the best sensory moment from \(anchorName) in one sentence: \(anchorRoom)",
                "restPrompt": "Before leaving \(anchorName), give it three quiet breaths and let it recognize you.",
                "hint": "Do not hunt for magic. Let the local rule make one ordinary detail brighter."
            ]
        }
        if lastVentureMode == .destination,
           let firstPlace = currentNearbyPlacesText
               .split(separator: "\n").first
               .flatMap({ $0.split(separator: "(").first })
               .map({ $0.trimmingCharacters(in: .whitespaces) }),
           !firstPlace.isEmpty {
            return [
                "spark": "I wonder what \(firstPlace) is like at exactly this hour?",
                "destination": "\(firstPlace): it really exists, and it is close",
                "delight": "whatever small good thing \(firstPlace) does best",
                "definition": "the North question is complete after \(time), or when you know one thing true about this hour at \(firstPlace)",
                "mission": "At \(firstPlace), let your body answer the North question: find the thing they are proudest of and the thing nobody notices. Smell one of them.",
                "souvenirPrompt": "Write the best sensory moment from \(firstPlace) in one sentence.",
                "restPrompt": "Before leaving, stand still for three breaths and let the place file you under regulars."
            ]
        }
        let placeMission: String
        let placeDestination: String
        switch context {
        case .home, .indoors:
            placeDestination = "one room, window, doorway, sink, chair, or patch of light"
            placeMission = "Find the oldest, softest, and most recently moved thing in this room. Let one of them win."
        case .work:
            placeDestination = "one threshold inside the workday: desk, hallway, break room, doorway, or machine"
            placeMission = "Find the sound your workplace makes that no other building makes. Name it without complaining about it."
        case .cafe:
            placeDestination = "one seat, counter, window, cup, pastry case, or corner in \(location)"
            placeMission = "Track three layers: cup sound, human sound, machine sound. Decide which one is conducting the room."
        case .harbor, .waterfront:
            placeDestination = "one edge where land meets water"
            placeMission = "Find one rope, reflection, gull-mark, tide-line, or boat-sound. Ask what job it is doing today."
        case .park, .trail:
            placeDestination = "one living threshold: path, tree, bench, stone, sign, or patch of shade"
            placeMission = "Collect three kinds of green or brown and one sound that arrived before you did."
        case .store:
            placeDestination = "one aisle, shelf, sign, basket, counter, or waiting place"
            placeMission = "Find one strange label, one tiny kindness, and one object designed by a stranger's hand."
        case .library:
            placeDestination = "one shelf, table, return cart, quiet corner, or public notice"
            placeMission = "Let shelf chance choose one title, then find the quietest object doing work nearby."
        case .transit:
            placeDestination = "one waiting edge: platform, stop, seat, window, crossing, or route marker"
            placeMission = "Watch one moving thing nobody else is watching. Give its errand a name."
        case .neighborhood:
            placeDestination = "one corner, tree, sign, stoop, fence, mailbox, or threshold nearby"
            placeMission = "Find three details proving this block is not generic: one old thing, one repair, and one color."
        case .current, .other:
            placeDestination = "one real threshold in or near \(location)"
            placeMission = "Find three textures, two colors, and the quietest sound nearby."
        }
        return [
            "spark": lowEnergy
                ? "I wonder what is the smallest true thing I can notice from \(location)?"
                : "I wonder what detail in \(location) has been waiting for me to notice it?",
            "destination": lowEnergy ? "one nearby chair, window, doorway, or patch of light" : placeDestination,
            "delight": lowEnergy ? "water, soft light, silence, or something warm to hold" : "a favorite drink, song, jacket, or tiny treat",
            "definition": "the North question is complete after \(time), or sooner if the body says stop",
            "mission": lowEnergy ? "Start where you are and let the body answer the North question: find one thing that supports weight: floor, chair, wall, cup, blanket, or breath. Notice exactly how it holds." : "\(placeMission) Let that sensory detail answer the North question.",
            "souvenirPrompt": "Write the best sensory moment from the run in one sentence: I want to keep...",
            "restPrompt": "Put the phone face down for 60 seconds and let the run land.",
            "hint": "Make it smaller before you make it harder."
        ]
    }

    private func askTheBook() async {
        let prompt = askPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isAskingTheBook else { return }
        let isFirstTurn = askTurns.isEmpty
        isAskingTheBook = true
        askTheBookMessage = "I'm climbing into the Stacks."
        do {
            let memory = await askTheBookMemoryLookup(prompt, askTurns)
            askTheBookMessage = memory.evidence.isEmpty
                ? "I went through the permitted shelves. Nothing bit hard enough yet."
                : "A few old leaves tugged back. I am reading their corners."
            appLog.info(
                "Chat with the Book archive search finished; records: \(memory.searchedRecordCount, privacy: .public); opened: \(memory.evidence.count, privacy: .public); inquiry: \(memory.inquiryKind.rawValue, privacy: .public)"
            )
            let answer: String
            if let interiorAnswer = BookInteriorAnswerGrounder.answer(to: prompt, interior: bookInterior) {
                answer = interiorAnswer
                appLog.info("Chat with the Book answered from durable Book interior state.")
            } else if let deterministic = AskTheBookAnswerGrounder.deterministicAnswer(for: memory) {
                answer = deterministic
                appLog.info("Chat with the Book used deterministic archive calculation.")
            } else {
                let generated: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            appLog.info("Chat with the Book sending message to Gemma; message characters: \(prompt.count, privacy: .public); previous turns: \(askTurns.count, privacy: .public)")
            generated = try await MLXAskTheBookAnswerer().answer(
                prompt: prompt,
                day: day,
                previousTurns: askTurns,
                readerLexicon: readerLexicon,
                memory: memory,
                relationship: bookRelationship,
                interior: bookInterior,
                bookVoicePatina: bookVoicePatina
            )
            appLog.info("Chat with the Book Gemma reply returned; reply characters: \(generated.count, privacy: .public)")
        #else
            appLog.info("Chat with the Book using preview fallback; native local brain is not available in this build.")
            generated = try await FakeAskTheBookAnswerer().answer(
                prompt: prompt,
                day: day,
                previousTurns: askTurns,
                readerLexicon: readerLexicon,
                memory: memory,
                relationship: bookRelationship,
                interior: bookInterior,
                bookVoicePatina: bookVoicePatina
            )
            #endif
                answer = AskTheBookAnswerGrounder.finalizeGenerated(
                    generated,
                    prompt: prompt,
                    memory: memory
                )
            }
            let turn = AskTheBookTurn(prompt: prompt, answer: answer)
            askTurns.append(turn)
            if isFirstTurn,
               let initiativeID = surface.payload.metadata["bookInitiativeID"]?.nonEmpty,
               surface.payload.metadata["bookInitiativeGenerationPolicy"] == "user-initiated-only" {
                onBookInitiativeAnswered(initiativeID, prompt, Date())
            }
            askEvidenceByTurnID[turn.id] = memory.evidence
            askSearchCountByTurnID[turn.id] = memory.searchedRecordCount
            askPrompt = ""
            askTheBookMessage = memory.evidence.isEmpty
                ? "The answer is here. I did not invent a memory to make it prettier."
                : "The answer is here. The leaves that pulled at it are tucked underneath."
            BookFeedback.play(.braidComplete)
        } catch {
            appLog.error("Let’s Chat failed: \(error.localizedDescription, privacy: .public)")
            askTheBookMessage = "The sentence slipped before it settled. I kept the question."
            BookFeedback.play(.error)
        }
        // The reader's next move here is to type again, and they cannot: with
        // E2B resident this device has no room to raise a keyboard. Give the
        // weights back between turns rather than holding them for a reply that
        // can never be written.
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        await LocalBrainModelCache.shared.releaseAfterFlow(label: "ask-the-book")
        #endif
        isAskingTheBook = false
    }

    private func seedInkrestIntakeIfNeeded() {
        guard surface.type == .inkrestOfficeHours, !inkrestSeeded else { return }
        inkrestSeeded = true
        let metadata = surface.payload.metadata
        inkrestIntake = InkrestIntake(
            promptID: metadata["rotatingPromptID"] ?? "open",
            lens: metadata["rotatingLens"] ?? "open",
            rotatingQuestion: metadata["rotatingQuestion"] ?? "How did today actually go?"
        )
    }

    private var inkrestReplyCap: Int { InkrestOfficeHours.replyCap }

    private func beginInkrestSitting() {
        guard !inkrestStarted, !isInkrestSitting else { return }
        guard inkrestIntake.hasSomethingToOpenWith else { return }
        inkrestStarted = true
        Task { await sendInkrestMessage(inkrestIntake.openingMessage, forceClose: false) }
    }

    private func continueInkrestSitting(forceClose: Bool) {
        guard inkrestStarted, !inkrestClosed, !isInkrestSitting else { return }
        let message = inkrestChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !forceClose {
            guard !message.isEmpty else { return }
        }
        Task { await sendInkrestMessage(message, forceClose: forceClose) }
    }

    private func sendInkrestMessage(_ message: String, forceClose: Bool) async {
        guard !isInkrestSitting else { return }
        isInkrestSitting = true
        inkrestMessage = "Dr. Inkrest is reading with you."
        // The opening intake counts as the first exchange, so the sitting closes once the
        // next reply would reach the cap, or when the reader asks her to close.
        let isClosing = forceClose || (inkrestTurns.count + 1 >= inkrestReplyCap)
        do {
            let reply: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            appLog.info("Inkrest Office Hours sending to Gemma; characters: \(message.count, privacy: .public); exchanges: \(inkrestTurns.count, privacy: .public); closing: \(isClosing, privacy: .public)")
            reply = try await MLXInkrestOfficeHoursCounselor().reply(
                intake: inkrestIntake,
                day: day,
                previousTurns: inkrestTurns,
                userMessage: message,
                isClosing: isClosing
            )
            #else
            appLog.info("Inkrest Office Hours using preview fallback; native local brain is not available in this build.")
            reply = try await FakeInkrestOfficeHoursCounselor().reply(
                intake: inkrestIntake,
                day: day,
                previousTurns: inkrestTurns,
                userMessage: message,
                isClosing: isClosing
            )
            #endif
            inkrestTurns.append(AskTheBookTurn(prompt: message, answer: reply))
            inkrestChatInput = ""
            if isClosing {
                inkrestClosed = true
                inkrestMessage = "Dr. Inkrest set the lamp down. Keep the sitting, or let it wait."
            } else {
                inkrestMessage = "Dr. Inkrest answered. Stay a while, or keep the sitting."
            }
            BookFeedback.play(.braidComplete)
        } catch {
            // The opening attempt failed: let the reader try again from the form.
            if inkrestTurns.isEmpty {
                inkrestStarted = false
            }
            inkrestMessage = "The sitting did not settle: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
        isInkrestSitting = false
    }

    private var faeDeadline: Date? {
        surface.payload.metadata["deadline"].flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    /// Set a real Reminder a few hours before the accepted exchange bites.
    private func setFaeBargainReminder() async {
        guard let deadline = faeDeadline else { return }
        let remindAt = max(Date().addingTimeInterval(60), deadline.addingTimeInterval(-3 * 3_600))
        let metadata = surface.payload.metadata
        let fae = metadata["faeName"] ?? "A Book Fae"
        let gift = metadata["giftName"] ?? "the gift"
        let ok = await EventKitWriter.addReminder(
            title: "A Fae exchange is still waiting",
            notes: "\(fae) is waiting for this noticing. If the window passes, \(gift) goes cold and their market door shuts until repaired:\n\(metadata["terms"] ?? "")",
            due: remindAt
        )
        faeMessage = ok
            ? "A Reminder is set while the exchange is still waiting."
            : "The Reminder could not be set (check Reminders permission in Settings)."
        BookFeedback.play(ok ? .select : .error)
    }

    private func payFaeBargainInSheet() async {
        guard surface.type == .faeBargain, !isFaePaying else { return }
        let report = faeReport.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !report.isEmpty else { return }
        let metadata = surface.payload.metadata
        let bargain = faeBargainFromMetadata(metadata)
        isFaePaying = true
        faeMessage = "\(bargain.faeKind.name) turns the report over in its hands."
        let mood = FaeEconomy.mood(for: Date())
        do {
            let reply: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            appLog.info("Fae Bargain payment to Gemma; fae: \(bargain.faeKind.rawValue, privacy: .public); report characters: \(report.count, privacy: .public)")
            reply = try await MLXFaeBargainResponder().respond(bargain: bargain, report: report, mood: mood, day: day)
            #else
            appLog.info("Fae Bargain using preview fallback; native local brain is not available in this build.")
            reply = try await FakeFaeBargainResponder().respond(bargain: bargain, report: report, mood: mood, day: day)
            #endif
            faeResponseText = reply
            faeMessage = "The exchange is complete. Keep the page to remember it."
            BookFeedback.play(.braidComplete)
        } catch {
            faeMessage = "The exchange did not settle: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
        isFaePaying = false
    }

    /// Reconstructs the bargain from page metadata so the responder has full context.
    private func faeBargainFromMetadata(_ metadata: [String: String]) -> FaeBargain {
        let kind = FaeKind(rawValue: metadata["faeKind"] ?? "") ?? .goblin
        let opening = metadata["openingGesture"] ?? surface.payload.body
        let context = metadata["faeContext"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptedOpening = context?.isEmpty == false ? "\(opening)\n\n\(context ?? "")" : opening
        return FaeBargain(
            id: metadata["bargainID"] ?? "fae-bargain",
            faeKind: kind,
            slot: "",
            giftID: "",
            giftName: metadata["giftName"] ?? "a gift",
            giftEffectLine: metadata["giftEffectLine"] ?? "",
            openingGesture: promptedOpening,
            terms: metadata["terms"] ?? surface.detail,
            offeredAt: Date(),
            deadline: Date(),
            status: (metadata["status"]).flatMap(FaeBargainStatus.init) ?? .owed,
            fieldReport: nil,
            faeResponse: nil,
            rewardText: nil,
            deliveredAt: nil
        )
    }

    private func completeFaeBargainIfNeeded() {
        guard surface.type == .faeBargain,
              !faeResponseText.isEmpty,
              let bargainID = surface.payload.metadata["bargainID"] else { return }
        onPayFaeBargain(bargainID, faeReport.trimmingCharacters(in: .whitespacesAndNewlines), faeResponseText)
    }

    private func askEnchantedObject() async {
        let prompt = enchantmentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let result = enchantmentResult,
              !prompt.isEmpty,
              !isAnsweringEnchantedObject else {
            return
        }
        isAnsweringEnchantedObject = true
        enchantmentMessage = "\(result.subjectName) is answering."
        do {
            let answer: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            answer = try await MLXEnchantmentWriter().answerObject(prompt: prompt, result: result, previousTurns: enchantmentTurns, day: day)
            #else
            answer = try await FakeEnchantmentWriter().answerObject(prompt: prompt, result: result, previousTurns: enchantmentTurns, day: day)
            #endif
            enchantmentTurns.append(AskTheBookTurn(prompt: prompt, answer: answer))
            enchantmentPrompt = ""
            enchantmentMessage = "\(result.subjectName) answered."
            currentEnchantmentSurface = currentEnchantmentSurface?.withEnchantmentConversation(enchantmentTurns)
            BookFeedback.play(.braidComplete)
        } catch {
            enchantmentMessage = "The subject did not answer clearly: \(error.localizedDescription)"
            BookFeedback.play(.error)
        }
        isAnsweringEnchantedObject = false
    }
}

extension SurfacePage {
    func withPlayfulMission(_ mission: PlayfulMission, slotID: String) -> SurfacePage {
        var metadata = payload.metadata
        metadata["compassStep"] = "sense"
        metadata["compassMode"] = "standalone"
        metadata.removeValue(forKey: "runID")
        metadata["playfulMissionID"] = mission.id
        metadata["playfulMissionTitle"] = mission.title
        metadata["playfulMissionMode"] = mission.playMode.rawValue
        metadata["mission"] = mission.prompt
        metadata["souvenirPrompt"] = mission.souvenirInvitation
        metadata["placeholder"] = mission.souvenirInvitation
        metadata["proofKind"] = mission.allowsPhoto ? "sentence-or-photo" : "sentence"
        metadata["symbol"] = mission.allowsPhoto ? "camera.macro" : "hand.raised"
        metadata["selector"] = "gemma-custom-playful-mission"
        let existingTags = metadata["tags"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        metadata["tags"] = Array(Set(existingTags + ["compass-step:sense", "playful-mission", "custom-playful-mission", "play-mode:\(mission.playMode.rawValue)"] + mission.tags.map { "mission:\($0)" }))
            .sorted()
            .joined(separator: ",")

        return SurfacePage(
            id: "\(sourceID)-playful-mission-\(mission.id)-\(slotID)",
            type: type,
            sourceID: sourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: max(score, 66),
            reason: "Gemma made a fresh playful mission from the South = Sense grammar.",
            prompt: "Playful Mission: \(mission.title)",
            detail: mission.prompt,
            payload: BookPagePayload(
                headline: "South = Sense",
                body: "\(mission.prompt)\n\nBring back: \(mission.souvenirInvitation)",
                metadata: metadata
            )
        )
    }

    func withEnchantmentConversation(_ turns: [AskTheBookTurn]) -> SurfacePage {
        guard !turns.isEmpty else { return self }
        var metadata = payload.metadata
        metadata["enchantmentTurns"] = "\(turns.count)"
        metadata["enchantmentConversation"] = turns.enumerated().map { index, turn in
            [
                "Turn \(index + 1)",
                "Reader: \(turn.prompt)",
                "Subject: \(turn.answer)"
            ].joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: [
                    payload.body,
                    metadata["enchantmentConversation"].map { "Conversation:\n\($0)" }
                ].compactMap { $0 }.joined(separator: "\n\n"),
                metadata: metadata
            )
        )
    }
}

enum StoryPageMechanicKind: String, Equatable {
    case none
    case beliefDice = "belief-dice"
    case compassRun = "compass-run"
    case enchantment
}

struct StoryPageChoiceMechanic: Equatable {
    var kind: StoryPageMechanicKind = .none
    var enchantmentID: String?

    static let none = StoryPageChoiceMechanic()

    var spell: EnchantmentSpell? {
        StoryEnchantmentCatalog.spell(id: enchantmentID)
    }

    var title: String {
        switch kind {
        case .none:
            return "Story choice"
        case .beliefDice:
            return "Throw the Inkbones"
        case .compassRun:
            return "Compass Run Page"
        case .enchantment:
            return spell.map { "Enchantment: \($0.title)" } ?? "Enchantment Page"
        }
    }

    var detail: String {
        switch kind {
        case .none:
            return ""
        case .beliefDice:
            return "Cast my little bones before the Story Page writes the consequence."
        case .compassRun:
            return "Complete a real Compass Run, then the Story Page continues from it."
        case .enchantment:
            return spell?.detail ?? "Complete the chosen Enchantment with real proof."
        }
    }

    var actionTitle: String {
        switch kind {
        case .none:
            return "Choose path"
        case .beliefDice:
            return "Throw the Inkbones"
        case .compassRun:
            return "Open Compass Run"
        case .enchantment:
            return "Open Enchantment"
        }
    }

    var symbolName: String {
        switch kind {
        case .none:
            return "sparkles"
        case .beliefDice:
            return "die.face.5"
        case .compassRun:
            return "safari"
        case .enchantment:
            return "wand.and.stars"
        }
    }

    static func parse(_ raw: String?, enchantmentID: String? = nil) -> StoryPageChoiceMechanic {
        let value = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !value.isEmpty, value != "none", value != "no" else {
            return .none
        }
        if value.contains("belief") || value.contains("dice") || value.contains("roll") {
            return StoryPageChoiceMechanic(kind: .beliefDice)
        }
        if value.contains("compass") {
            return StoryPageChoiceMechanic(kind: .compassRun)
        }
        if value.contains("enchantment") || value.contains("spell") {
            let parsedID = value
                .replacingOccurrences(of: "enchantment:", with: "")
                .replacingOccurrences(of: "spell:", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            return StoryPageChoiceMechanic(
                kind: .enchantment,
                enchantmentID: enchantmentID?.nonEmpty ?? StoryEnchantmentCatalog.spell(id: parsedID)?.id ?? parsedID.nonEmpty
            )
        }
        return .none
    }
}

struct StoryPageChoiceDraft: Identifiable, Equatable {
    var id: String
    var title: String
    var prompt: String
    var effectLine: String
    var symbolName: String
    var tint: Color
    var mechanic: StoryPageChoiceMechanic = .none

    var kindLabel: String {
        if mechanic.kind != .none {
            return mechanic.title
        }
        switch id {
        case "sliceoflife":
            return "Slice of Life"
        case "progressarc":
            return "Arc"
        case "surprise":
            return "Surprise"
        default:
            return "Path"
        }
    }
}

struct StoryPageChoiceText: Equatable {
    var title: String
    var prompt: String
    var effectLine: String
    var mechanic: StoryPageChoiceMechanic = .none

    var isEmpty: Bool {
        title.nonEmpty == nil && prompt.nonEmpty == nil && effectLine.nonEmpty == nil && mechanic.kind == .none
    }
}

private enum SentenceRunnerFolio {
    static let runsToBind = 3

    static func title(completing run: Int) -> String {
        run >= runsToBind ? "The Loom Folio is ready to bind." : BookMechanicPresentation.progress(current: run, total: runsToBind)
    }
}

private struct SentenceRunnerResult: Equatable {
    enum Outcome: String, Equatable {
        case brightRun
        case mixedThread
        case greyTouched
        case emptyHands

        var title: String {
            switch self {
            case .brightRun: return "Bright Run"
            case .mixedThread: return "Mixed Thread"
            case .greyTouched: return "Grey-Touched Run"
            case .emptyHands: return "Empty Hands"
            }
        }

        var headline: String {
            switch self {
            case .brightRun: return "The words formed a bridge."
            case .mixedThread: return "The sentence held, with weather."
            case .greyTouched: return "The Rut of Routine got ink on the edge."
            case .emptyHands: return "The page kept the attempt."
            }
        }

        var summary: String {
            switch self {
            case .brightRun:
                return "You crossed the margin on bright words. The Loom will remember which phrases carried you."
            case .mixedThread:
                return "You caught live words and brushed the grey. The result is not failure; it is a map of where the sentence thinned."
            case .greyTouched:
                return "The Rut of Routine pressed vague language into the run, but one kept word can still hold a door open."
            case .emptyHands:
                return "No bright phrase stayed caught this time. I keep the attempt because attempts are evidence too."
            }
        }
    }

    var caught: [String]
    var nothingHits: [String]
    var chosenThread: String
    var targetCaught: Bool
    var lockedLines: [String]
    var runShape: SentenceRunnerRunShape
    var folioRunCount: Int
    var returnPhrase: String?

    var outcome: Outcome {
        if caught.isEmpty { return .emptyHands }
        if nothingHits.count >= caught.count { return .greyTouched }
        if nothingHits.isEmpty { return .brightRun }
        return .mixedThread
    }

    var keepText: String {
        SentenceRunnerPoem.compose(caught: caught, nothingHits: nothingHits, lockedLines: lockedLines)
    }
}

private enum SentenceRunnerPoem {
    /// Catch a handful and the run condenses into a short poem; catch more and the
    /// Loom has enough thread to weave a small story instead.
    static let storyThreshold = 4

    enum Form: String {
        case emptyHands
        case poem
        case miniStory
    }

    static func form(caught: [String], nothingHits: [String]) -> Form {
        let bright = cleaned(caught)
        if bright.isEmpty { return .emptyHands }
        return bright.count >= storyThreshold ? .miniStory : .poem
    }

    static func compose(caught: [String], nothingHits: [String], lockedLines: [String] = []) -> String {
        let bright = cleaned(caught)
        switch form(caught: bright, nothingHits: nothingHits) {
        case .emptyHands:
            return emptyHands(nothingHits: nothingHits)
        case .poem:
            return foundPoem(caught: bright, expansive: false, lockedLines: lockedLines)
        case .miniStory:
            return foundPoem(caught: bright, expansive: true, lockedLines: lockedLines)
        }
    }

    private static func cleaned(_ phrases: [String]) -> [String] {
        var seen = Set<String>()
        return phrases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static func emptyHands(nothingHits: [String]) -> String {
        let grey = nothingHits.first ?? "nothing much"
        return "The run came back with \(grey), grey at the edges.\nThe Book wrote down the empty space anyway."
    }

    /// The caught phrases are real but partial fragments lifted from kept pages, so
    /// stitching them into one grammatical sentence reads as nonsense. Instead the
    /// run becomes a found poem: each fragment kept on its own line, quoted, framed
    /// by the Book's voice, broken grammar reads as deliberate erasure, not error.
    private static func foundPoem(caught: [String], expansive: Bool, lockedLines: [String]) -> String {
        let limit = expansive ? 8 : 3
        let lines = caught.prefix(limit).map { "“\($0)”" }
        let opening = expansive
            ? "The reader crossed the margin, and the page kept what was said:"
            : "The margin made a road out of your own words:"
        let closing = expansive
            ? "Bright enough to count, and counted.\nThe Loom wound them back into the book, path and all."
            : "The Loom kept the path, not the score."
        let lock = lockedLines.last.map { ["", "The run locked one line before it could scatter:", "“\($0)”"] } ?? []
        return ([opening, ""] + lines + lock + ["", closing]).joined(separator: "\n")
    }
}

private struct PublicMarginsContributionSheet: View {
    let eventID: String

    @Environment(\.dismiss) private var dismiss
    @State private var sentence: String
    @State private var isSending = false
    @State private var receipt: PublicMarginsContributionReceipt?
    @State private var message = ""
    @State private var choicePoll: PublicMarginsChoicePoll?
    @State private var selectedChoiceID: String?
    @State private var isSendingChoice = false
    @State private var choiceReceipt: PublicMarginsContributionReceipt?
    @State private var choiceMessage = ""

    init(eventID: String, initialSentence: String) {
        self.eventID = eventID
        _sentence = State(initialValue: initialSentence)
    }

    private var preparedSentence: String? {
        PublicMarginsText.preparedSentence(from: sentence)
    }

    private var selectedChoice: PublicMarginsChoiceOption? {
        choicePoll?.options.first { $0.id == selectedChoiceID }
    }

    private var hasReceipt: Bool {
        receipt != nil || choiceReceipt != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground(isQuiet: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("One sentence, beyond the cover", systemImage: "text.bubble.fill")
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(BookPalette.ink)

                        Text("A sentence that passes automatic safety and privacy checks may appear publicly on reenchanted.app and in other readers' Books.")
                            .font(.subheadline)
                            .foregroundStyle(BookPalette.ink.opacity(0.72))

                        TextEditor(text: $sentence)
                            .font(.body)
                            .foregroundStyle(BookPalette.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(10)
                            .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                            }

                        HStack {
                            Text("\(sentence.count)/\(PublicMarginsText.maximumCharacters)")
                            Spacer()
                            Text(preparedSentence == nil ? "One sentence, with no links" : "Ready for exact preview")
                        }
                        .font(.caption)
                        .foregroundStyle(preparedSentence == nil ? BookPalette.violet : BookPalette.teal)

                        if let preparedSentence {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Exactly what will be public")
                                    .font(.caption.weight(.bold))
                                    .textCase(.uppercase)
                                Text("“\(preparedSentence)”")
                                    .font(.system(.body, design: .serif))
                                    .textSelection(.enabled)
                            }
                            .foregroundStyle(BookPalette.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(BookPalette.lampGold.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Text("Nothing else leaves this page: not its page ID, surrounding writing, archive, photos, location, health, Calendar, Belief, or Book of You. A private deletion receipt stays on this device.")
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.64))

                        if let receipt {
                            Label(
                                receipt.status == "approved"
                                    ? "Placed in the Public Margins."
                                    : "Received, but the automatic safety check did not publish it.",
                                systemImage: receipt.status == "approved" ? "checkmark.seal.fill" : "shield.lefthalf.filled"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(receipt.status == "approved" ? BookPalette.teal : BookPalette.violet)
                        } else {
                            Button {
                                Task { await send(preparedSentence) }
                            } label: {
                                Label(isSending ? "Placing the sentence..." : "Yes: make exactly this sentence public", systemImage: "arrow.up.right.circle.fill")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(BookPalette.teal.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(BookPalette.teal)
                            .disabled(preparedSentence == nil || isSending)
                        }

                        if !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(BookPalette.violet)
                        }

                        Divider().overlay(BookPalette.ink.opacity(0.12))

                        VStack(alignment: .leading, spacing: 12) {
                            Label("One quiet choice", systemImage: "checklist")
                                .font(.system(.title3, design: .serif, weight: .bold))
                                .foregroundStyle(BookPalette.ink)

                            if let poll = choicePoll {
                                Text(poll.question)
                                    .font(.system(.headline, design: .serif, weight: .semibold))
                                    .foregroundStyle(BookPalette.ink)

                                if let choiceReceipt {
                                    Label(
                                        choiceReceipt.status == "approved"
                                            ? "Counted anonymously."
                                            : "This choice was not published.",
                                        systemImage: choiceReceipt.status == "approved" ? "checkmark.circle.fill" : "shield.lefthalf.filled"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(choiceReceipt.status == "approved" ? BookPalette.teal : BookPalette.violet)
                                } else {
                                    ForEach(poll.options) { option in
                                        Button {
                                            BookFeedback.play(.select)
                                            selectedChoiceID = option.id
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: selectedChoiceID == option.id ? "checkmark.circle.fill" : "circle")
                                                Text(option.label)
                                                    .font(.subheadline.weight(.semibold))
                                                Spacer(minLength: 8)
                                            }
                                            .foregroundStyle(selectedChoiceID == option.id ? BookPalette.teal : BookPalette.ink)
                                            .padding(11)
                                            .background(
                                                (selectedChoiceID == option.id ? BookPalette.teal : BookPalette.paper).opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if let selectedChoice {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Exactly what will be counted")
                                                .font(.caption.weight(.bold))
                                                .textCase(.uppercase)
                                            Text("\(poll.question): \(selectedChoice.label)")
                                                .font(.system(.callout, design: .serif))
                                        }
                                        .foregroundStyle(BookPalette.ink)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(BookPalette.lampGold.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                                        Button {
                                            Task { await sendChoice(poll: poll, choice: selectedChoice) }
                                        } label: {
                                            Label(
                                                isSendingChoice ? "Counting the choice..." : "Yes: count exactly this choice",
                                                systemImage: "checkmark.circle.fill"
                                            )
                                            .font(.subheadline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(BookPalette.teal.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(BookPalette.teal)
                                        .disabled(isSendingChoice)
                                    }
                                }
                            } else {
                                Text("The quiet question could not be fetched. Nothing was sent.")
                                    .font(.caption)
                                    .foregroundStyle(BookPalette.ink.opacity(0.64))
                            }

                            if !choiceMessage.isEmpty {
                                Text(choiceMessage)
                                    .font(.caption)
                                    .foregroundStyle(BookPalette.violet)
                            }

                            Text("The public count receives only the selected answer: no sentence, Page, account, or device identifier.")
                                .font(.caption)
                                .foregroundStyle(BookPalette.ink.opacity(0.64))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Public Margins")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadChoicePoll() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(hasReceipt ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func send(_ exactSentence: String?) async {
        guard let exactSentence, !isSending else { return }
        isSending = true
        message = ""
        defer { isSending = false }
        do {
            receipt = try await PublicMarginsAPI.submit(PublicMarginsContributionRequest(
                requestID: UUID().uuidString,
                eventID: eventID,
                kind: .souvenir,
                text: exactSentence,
                category: nil,
                choiceID: nil,
                confirmedAt: ISO8601DateFormatter().string(from: Date()),
                consent: .init(publicDisplay: true, moderation: true)
            ))
            BookFeedback.play(.keepPage)
        } catch {
            message = error.localizedDescription
            BookFeedback.play(.error)
        }
    }

    @MainActor
    private func loadChoicePoll() async {
        guard choicePoll == nil else { return }
        do {
            choicePoll = (try await PublicMarginsAPI.fetchSnapshot()).choicePoll
        } catch {
            choiceMessage = "The Public Margins didn't answer. Nothing was sent."
        }
    }

    @MainActor
    private func sendChoice(poll: PublicMarginsChoicePoll, choice: PublicMarginsChoiceOption) async {
        guard !isSendingChoice, choiceReceipt == nil else { return }
        isSendingChoice = true
        choiceMessage = ""
        defer { isSendingChoice = false }
        do {
            choiceReceipt = try await PublicMarginsAPI.submit(PublicMarginsContributionRequest(
                requestID: UUID().uuidString,
                eventID: poll.id,
                kind: .choice,
                text: nil,
                category: "quiet-choice",
                choiceID: choice.id,
                confirmedAt: ISO8601DateFormatter().string(from: Date()),
                consent: .init(publicDisplay: true, moderation: true)
            ))
            BookFeedback.play(.keepPage)
        } catch {
            choiceMessage = error.localizedDescription
            BookFeedback.play(.error)
        }
    }
}

/// Where a caught archive phrase originally came from: the exact kept page, dated.
struct SentenceRunnerPhraseSource: Identifiable, Equatable {
    var id: String { pageID }
    let phrase: String
    let pageID: String
    let date: Date
    let label: String
}

/// One restored grey word: the flat word, the concrete phrase it was hiding, and
/// (when known) the source page that phrase came from.
struct SentenceRunnerRescueItem: Identifiable, Equatable {
    let id = UUID()
    let grey: String
    let restored: String
    let source: SentenceRunnerPhraseSource?
}

private enum SentenceRunnerRescue {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Each grey word Routine pressed into the run is flattened language; the
    /// Book restores it by pairing it with a concrete phrase the reader actually
    /// kept (and, when known, the exact page it came from). Deterministic.
    static func items(grey: [String], archive: [String], provenance: [String: SentenceRunnerPhraseSource]) -> [SentenceRunnerRescueItem] {
        let pool = archive.filter { !$0.isEmpty }
        guard !pool.isEmpty else { return [] }
        var used = Set<Int>()
        return grey.prefix(4).map { word in
            var index = abs("\(word)-rescue".stableHash) % pool.count
            if used.count < pool.count {
                while used.contains(index) { index = (index + 1) % pool.count }
            }
            used.insert(index)
            let phrase = pool[index]
            return SentenceRunnerRescueItem(grey: word, restored: phrase, source: provenance[phrase])
        }
    }

    /// Flat text form of the rescues, for the saved page body and the Gemma draft.
    static func lines(_ items: [SentenceRunnerRescueItem]) -> [String] {
        items.map { item in
            let from = item.source.map { " (from your \($0.label), \(dateFormatter.string(from: $0.date)))" } ?? ""
            return "\(item.grey). Routine flattened this. What you meant: \(item.restored)\(from)."
        }
    }

    static func returnPhrase(grey: [String], archive: [String]) -> String? {
        items(grey: grey, archive: archive, provenance: [:]).first?.restored
    }
}

private struct SentenceRunnerGameView: View {
    let phrases: [String]
    let nothingPhrases: [String]
    let phraseSources: [String: SentenceRunnerPhraseSource]
    let chosenThread: String
    let runShape: SentenceRunnerRunShape
    let folioRunCount: Int
    let onCancel: () -> Void
    let onFinish: (SentenceRunnerResult) -> Void

    @State private var run = SentenceRunnerRunState()
    @State private var startedAt = Date()
    @State private var lastTick = Date()
    @State private var caught: [String] = []
    @State private var nothingHits: [String] = []
    @State private var currentLine: [String] = []
    @State private var lockedLines: [String] = []
    @State private var targetCaught = false
    @State private var caughtSourceLine = ""
    @State private var sparks: [CaughtSpark] = []
    @State private var finished = false

    private var runDuration: TimeInterval { runShape.runDuration }

    private var tokens: [SentenceRunnerToken] {
        SentenceRunnerRunBuilder.tokens(phrases: phrases, nothingPhrases: nothingPhrases, shape: runShape)
    }

    private var progress: Double {
        min(1, max(0, Date().timeIntervalSince(startedAt) / runDuration))
    }

    var body: some View {
        ZStack {
            BookBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THE SENTENCE RUNNER")
                            .font(.caption.weight(.black))
                            .foregroundStyle(BookPalette.lampGold)
                        Text(caught.isEmpty ? "the margin is listening…" : caught.joined(separator: " "))
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(caught.isEmpty ? BookPalette.nightText.opacity(0.6) : BookPalette.lampGold)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(.easeOut(duration: 0.25), value: caught)
                        Text("Carry “\(chosenThread)” · \(runShape.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.teal)
                            .lineLimit(1)
                        if !caughtSourceLine.isEmpty {
                            Text(caughtSourceLine)
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.62))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button("Exit") { onCancel() }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.lampGold)
                }

                HStack(spacing: 10) {
                    runnerState(
                        "Thread",
                        caught.isEmpty ? "listening" : (targetCaught ? "carried" : "gathering"),
                        BookPalette.teal
                    )
                    runnerState(
                        "Margin",
                        nothingHits.isEmpty ? "clear" : "grey-touched",
                        nothingHits.isEmpty ? BookPalette.lampGold : BookPalette.ink.opacity(0.55)
                    )
                    runnerState(
                        "Road",
                        progress < 0.35 ? "opening" : (progress < 0.78 ? "running" : "nearly home"),
                        BookPalette.lampGold
                    )
                }

                GeometryReader { proxy in
                    TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
                        Canvas { context, size in
                            drawRun(context: &context, size: size)
                        }
                        .onChange(of: timeline.date) { _, date in
                            tick(date: date, size: proxy.size)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture().onEnded {
                                jump()
                            }
                        )
                    }
                    .background(BookPalette.nightPanel.opacity(0.40), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
                    }
                }
                .frame(minHeight: 360)

                Button {
                    jump()
                } label: {
                    Label("Jump", systemImage: "arrow.up")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.lampGold)

                Text("Bright phrases come from kept pages. Grey phrases are Routine trying to flatten the run. A grey touch is not failure; it is evidence.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.nightText.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .onAppear {
            startedAt = Date()
            lastTick = startedAt
            sparks = []
            caught = []
            nothingHits = []
            finished = false
            run = SentenceRunnerRunState(tokens: tokens)
            currentLine = []
            lockedLines = []
            targetCaught = false
            caughtSourceLine = ""
        }
    }

    private func jump() {
        guard !finished else { return }
        if run.playerY <= 2 || run.coyoteTime > 0 {
            run.velocityY = 580
            run.coyoteTime = 0
            BookFeedback.play(.select)
        }
    }

    private func tick(date: Date, size: CGSize) {
        guard !finished, size.width > 0, size.height > 0 else { return }
        let dt = min(0.05, max(0.001, date.timeIntervalSince(lastTick)))
        lastTick = date
        run.advance(dt: dt, size: size, scrollSpeed: runShape.scrollSpeed)
        collectCollisions(size: size)
        ageSparks(dt: dt)
        if date.timeIntervalSince(startedAt) >= runDuration || run.tokens.allSatisfy(\.wasResolved) {
            finished = true
            onFinish(SentenceRunnerResult(
                caught: caught,
                nothingHits: nothingHits,
                chosenThread: chosenThread,
                targetCaught: targetCaught,
                lockedLines: lockedLines,
                runShape: runShape,
                folioRunCount: folioRunCount + 1,
                returnPhrase: SentenceRunnerRescue.returnPhrase(grey: nothingHits, archive: phrases)
            ))
        }
    }

    private func ageSparks(dt: TimeInterval) {
        guard !sparks.isEmpty else { return }
        for index in sparks.indices {
            sparks[index].age += dt
            // drift up and toward the header, where the sentence is assembling
            sparks[index].position.y -= CGFloat(dt) * 170
            sparks[index].position.x -= CGFloat(dt) * 55
        }
        sparks.removeAll { $0.age >= CaughtSpark.lifetime }
    }

    private func collectCollisions(size: CGSize) {
        let player = run.playerRect(in: size)
        for token in run.tokens where !token.wasResolved {
            let rect = run.rect(for: token, in: size)
            guard player.intersects(rect) else { continue }
            run.resolve(tokenID: token.id)
            if token.isNothing {
                nothingHits.append(token.text)
                currentLine.removeAll()
                run.greyFlash = 0.25
                BookFeedback.play(.undo)
            } else {
                caught.append(token.text)
                currentLine.append(token.text)
                if token.text.caseInsensitiveCompare(chosenThread) == .orderedSame {
                    targetCaught = true
                }
                if let source = phraseSources[token.text] {
                    caughtSourceLine = "From your \(source.label) · \(SentenceRunnerRescue.dateFormatter.string(from: source.date))"
                }
                if currentLine.count == 3 {
                    lockedLines.append(currentLine.joined(separator: " · "))
                    currentLine.removeAll()
                    BookFeedback.play(.braidComplete)
                }
                run.sparkFlash = 0.25
                sparks.append(CaughtSpark(text: token.text, position: CGPoint(x: rect.midX, y: rect.midY)))
                BookFeedback.play(.tap)
            }
        }
    }

    private func drawRun(context: inout GraphicsContext, size: CGSize) {
        let groundY = run.groundY(in: size)
        context.fill(
            Path(CGRect(x: 0, y: groundY + 38, width: size.width, height: max(0, size.height - groundY))),
            with: .color(BookPalette.ink.opacity(0.18))
        )
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: 0, y: groundY + 38))
                path.addLine(to: CGPoint(x: size.width, y: groundY + 38))
            },
            with: .color(BookPalette.lampGold.opacity(0.34)),
            lineWidth: 2
        )

        for lane in 0..<3 {
            let y = groundY - CGFloat(lane) * 72
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                },
                with: .color(BookPalette.nightText.opacity(0.08)),
                lineWidth: 1
            )
        }

        for token in run.tokens where !token.wasResolved {
            draw(token: token, context: &context, size: size)
        }

        drawPlayer(context: &context, size: size)

        for spark in sparks {
            let progress = spark.age / CaughtSpark.lifetime
            let rise = 1 + progress * 0.45
            var sparkContext = context
            sparkContext.opacity = max(0, 1 - progress)
            sparkContext.draw(
                Text(spark.text)
                    .font(.system(size: 13 * rise, weight: .bold, design: .serif))
                    .foregroundColor(BookPalette.lampGold),
                at: spark.position
            )
        }

        if run.greyFlash > 0 {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BookPalette.ink.opacity(0.12 * run.greyFlash / 0.25)))
        }
        if run.sparkFlash > 0 {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BookPalette.lampGold.opacity(0.08 * run.sparkFlash / 0.25)))
        }
    }

    private func draw(token: SentenceRunnerToken, context: inout GraphicsContext, size: CGSize) {
        let rect = run.rect(for: token, in: size)
        guard rect.maxX > -40, rect.minX < size.width + 60 else { return }
        let path = Path(roundedRect: rect, cornerRadius: 8)
        context.fill(path, with: .color(token.isNothing ? BookPalette.nightText.opacity(0.18) : BookPalette.lampGold.opacity(0.94)))
        context.stroke(path, with: .color(token.isNothing ? BookPalette.nightText.opacity(0.26) : BookPalette.nightPanel.opacity(0.22)), lineWidth: 1)

        let text = Text(token.text)
            .font(.system(size: 13, weight: .bold, design: .serif))
            .foregroundColor(token.isNothing ? BookPalette.nightText.opacity(0.62) : BookPalette.nightPanel)
        context.draw(text, in: rect.insetBy(dx: 8, dy: 7))
    }

    private func drawPlayer(context: inout GraphicsContext, size: CGSize) {
        let rect = run.playerRect(in: size)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let t = run.time
        let airborne = run.playerY > 2
        let inkColor = BookPalette.ink

        // Squash & stretch from vertical velocity: stretch rising, squash on landing.
        let stretch = max(-0.20, min(0.34, run.velocityY / 2_600))
        let scaleX = 1 - stretch * 0.7
        let scaleY = 1 + stretch
        let baseR = rect.width * 0.64

        // Soft cast shadow on the ground line.
        let groundY = run.groundY(in: size) + 38
        let shadowW = baseR * (airborne ? 1.1 : 1.7)
        let shadowAlpha = airborne ? 0.10 : 0.22
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - shadowW / 2, y: groundY - 6, width: shadowW, height: 10)),
            with: .color(inkColor.opacity(shadowAlpha))
        )

        // A trailing ink drip: a long string when airborne, a small wobble at rest.
        let dripLen = airborne ? baseR * (1.2 + 0.3 * sin(t * 6)) : baseR * (0.42 + 0.12 * sin(t * 4))
        let dripTop = CGPoint(x: center.x - baseR * 0.05, y: center.y + baseR * 0.45 * scaleY)
        var drip = Path()
        drip.move(to: CGPoint(x: dripTop.x - baseR * 0.20, y: dripTop.y))
        drip.addQuadCurve(
            to: CGPoint(x: dripTop.x, y: dripTop.y + dripLen),
            control: CGPoint(x: dripTop.x - baseR * 0.30, y: dripTop.y + dripLen * 0.6)
        )
        drip.addQuadCurve(
            to: CGPoint(x: dripTop.x + baseR * 0.20, y: dripTop.y),
            control: CGPoint(x: dripTop.x + baseR * 0.30, y: dripTop.y + dripLen * 0.6)
        )
        drip.closeSubpath()
        context.fill(drip, with: .color(inkColor.opacity(0.92)))

        // Wobbling ink blob body.
        let lobes: CGFloat = 7
        let amp: CGFloat = airborne ? 0.11 : 0.06
        let steps = 48
        var blob = Path()
        for i in 0...steps {
            let a = CGFloat(i) / CGFloat(steps) * .pi * 2
            let wobble = 1 + amp * sin(a * lobes + t * 3.4) + 0.04 * sin(a * 3 - t * 2.1)
            let r = baseR * wobble
            let point = CGPoint(x: center.x + cos(a) * r * scaleX, y: center.y + sin(a) * r * scaleY)
            if i == 0 { blob.move(to: point) } else { blob.addLine(to: point) }
        }
        blob.closeSubpath()
        context.fill(blob, with: .color(inkColor))
        context.stroke(blob, with: .color(BookPalette.lampGold.opacity(0.70)), lineWidth: 1.5)

        // Glossy teal sheen near the top-left to keep the brand spark on the ink.
        let sheen = Path(ellipseIn: CGRect(
            x: center.x - baseR * 0.52,
            y: center.y - baseR * 0.72,
            width: baseR * 0.72,
            height: baseR * 0.5
        ))
        context.fill(sheen, with: .color(BookPalette.teal.opacity(0.45)))

        // Eyes, set toward the direction of travel; pupils glance up on the jump.
        let eyeR = baseR * 0.17
        let eyeY = center.y - baseR * 0.06
        let look: CGFloat = airborne ? -eyeR * 0.7 : eyeR * 0.15 * sin(t * 2)
        for dx in [baseR * 0.16, baseR * 0.56] {
            let eye = CGPoint(x: center.x + dx, y: eyeY)
            context.fill(
                Path(ellipseIn: CGRect(x: eye.x - eyeR, y: eye.y - eyeR * 1.15, width: eyeR * 2, height: eyeR * 2.4)),
                with: .color(BookPalette.paper)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: eye.x - eyeR * 0.5, y: eye.y - eyeR * 0.5 + look, width: eyeR, height: eyeR)),
                with: .color(inkColor)
            )
        }
    }

    private func runnerState(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(BookPalette.nightText.opacity(0.58))
            Text(value)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(BookPalette.nightPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SentenceRunnerRunState {
    var tokens: [SentenceRunnerToken] = []
    var distance: CGFloat = 0
    var playerY: CGFloat = 0
    var velocityY: CGFloat = 0
    var coyoteTime: TimeInterval = 0
    var greyFlash: TimeInterval = 0
    var sparkFlash: TimeInterval = 0
    var time: TimeInterval = 0
    let playerX: CGFloat = 74
    let groundY: CGFloat = 0

    init(tokens: [SentenceRunnerToken] = []) {
        self.tokens = tokens
        self.playerY = groundY
    }

    mutating func advance(dt: TimeInterval, size: CGSize, scrollSpeed: CGFloat = 168) {
        time += dt
        distance += CGFloat(dt) * scrollSpeed
        velocityY -= CGFloat(dt) * 1_420
        playerY += velocityY * CGFloat(dt)
        if playerY <= groundY {
            playerY = groundY
            velocityY = 0
            coyoteTime = 0.09
        } else {
            coyoteTime = max(0, coyoteTime - dt)
        }
        greyFlash = max(0, greyFlash - dt)
        sparkFlash = max(0, sparkFlash - dt)
    }

    func groundY(in size: CGSize) -> CGFloat {
        max(160, size.height - 94)
    }

    func playerRect(in size: CGSize) -> CGRect {
        let h: CGFloat = 42
        return CGRect(x: playerX, y: groundY(in: size) - playerY - h, width: 38, height: h)
    }

    func rect(for token: SentenceRunnerToken, in size: CGSize) -> CGRect {
        let x = token.startX - distance
        let laneY = groundY(in: size) - token.height
        return CGRect(x: x, y: laneY - 24, width: token.width, height: 42)
    }

    mutating func resolve(tokenID: String) {
        guard let index = tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        tokens[index].wasResolved = true
    }
}

/// A caught word lifting off the run and settling toward the assembling sentence.
private struct CaughtSpark: Identifiable {
    let id = UUID()
    let text: String
    var position: CGPoint
    var age: TimeInterval = 0
    static let lifetime: TimeInterval = 0.85
}

private struct SentenceRunnerToken: Equatable {
    var id: String
    var text: String
    var isNothing: Bool
    var startX: CGFloat
    var height: CGFloat
    var width: CGFloat
    var wasResolved = false
}

private enum SentenceRunnerRunBuilder {
    static func tokens(
        phrases: [String],
        nothingPhrases: [String],
        shape: SentenceRunnerRunShape = .lowRoad
    ) -> [SentenceRunnerToken] {
        let bright = phrases.prefix(14).map { ($0, false) }
        let grey = nothingPhrases.prefix(7).map { ($0, true) }
        let pool = (bright + grey).sorted {
            "\($0.0)-runner".stableHash < "\($1.0)-runner".stableHash
        }
        return pool.enumerated().map { index, item in
            let text = item.0
            let isNothing = item.1
            let baseGap: Int
            switch shape {
            case .lowRoad: baseGap = 178
            case .staircase: baseGap = 158
            case .weather: baseGap = 138
            }
            let gap = CGFloat(baseGap + abs("\(text)-gap".stableHash % 72))
            let startX = 340 + CGFloat(index) * gap
            let lane: Int
            switch shape {
            case .lowRoad: lane = abs("\(text)-lane".stableHash % 2)
            case .staircase: lane = index % 3
            case .weather: lane = abs("\(text)-lane".stableHash % 3)
            }
            let height = CGFloat(42 + lane * 58)
            let width = CGFloat(min(190, max(92, 42 + text.count * 7)))
            return SentenceRunnerToken(
                id: "\(index)-\(text.stableHash)",
                text: text,
                isNothing: isNothing,
                startX: startX,
                height: height,
                width: width
            )
        }
        .sorted { $0.startX < $1.startX }
    }
}

private extension String {
    var slugTag: String {
        lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .prefix(5)
            .joined(separator: "-")
    }
}

struct StoryPageSessionTurn: Identifiable, Equatable {
    var id = UUID()
    var draft: StoryPageSceneDraft
    var selectedChoice: StoryPageChoiceDraft?
    /// Completed mechanics belong to the turn, not to its prose. Choice ids are
    /// reused by later turns, so keeping this here also prevents an old throw
    /// from resolving a new page by accident.
    var inkbonesResolutions: [String: StoryInkbonesResolution] = [:]
    var generatedResults: [String: String] = [:]

    func inkbonesResolution(for choice: StoryPageChoiceDraft) -> StoryInkbonesResolution? {
        inkbonesResolutions[choice.id]
    }

    func result(for choice: StoryPageChoiceDraft) -> String {
        generatedResults[choice.id]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? draft.result(for: choice)
    }
}

/// Maps a playable page's authored beats onto a snack-sized loop: setup,
/// choice, consequence, and at most one final choice/consequence.
struct StoryArcShape: Equatable {
    enum Act {
        case beginning, resolution, epilogue
    }

    var beats: [String]
    /// Turns already written, including the opening scene (>= 1 once a session
    /// has started).
    var turnsWritten: Int
    var formName: String
    /// The concrete element planted in the opening; the resolution must return
    /// it, changed. Empty when the page has no promise (older drafts).
    var promiseSeed: String = ""
    /// The committed change the whole page must enact, and the specific landing
    /// for the path the reader took. These drive the climax/resolution so the
    /// beat changes state instead of re-describing atmosphere.
    var turnStatement: String = ""
    var turnCharacter: String = ""
    var turnLanding: String = ""

    var condensedBeats: [String] { StoryVignetteBeats.snackSized(beats) }

    /// The beat this next turn should render, clamped to the two-beat vignette.
    var nextBeatIndex: Int { min(max(turnsWritten, 0), max(condensedBeats.count - 1, 0)) }

    /// True after the optional final beat has received a choice/consequence.
    var isComplete: Bool {
        turnsWritten >= StoryVignetteBeats.maximumInteractiveTurns
    }

    var act: Act {
        if isComplete { return .epilogue }
        return turnsWritten <= 0 ? .beginning : .resolution
    }

    /// Short reader-facing arc position for the page chrome.
    var progressLabel: String {
        switch act {
        case .beginning: return "Beginning"
        case .resolution: return "Final beat"
        case .epilogue: return "Ready to keep"
        }
    }

    /// The beat directive handed to the writer for the next continuation.
    var directive: String {
        if isComplete {
            return "The vignette is ready to keep. Write only a brief afterimage if asked: one concrete sign that the new normal is holding. No fresh conflict, no new door."
        }
        let who = turnCharacter.isEmpty ? "the character" : turnCharacter
        let beat = condensedBeats.indices.contains(nextBeatIndex) ? condensedBeats[nextBeatIndex] : ""
        let owedChange = turnLanding.nonEmpty ?? turnStatement.nonEmpty ?? "the reader's last choice matters in one visible way"
        let formLine = formName.isEmpty ? "the playable page" : "\"\(formName)\""
        let beatLine = beat.isEmpty ? "" : "\nFinal beat to set up: \(beat)"
        return """
        FINAL SETUP for \(formLine): write the final playable scene before the last choice.
        The previous consequence has already happened. Let it alter what \(who) says or does next.
        Keep the vignette small: no new subplot, no new phase, no cliffhanger.
        Leave the final landing for the reader's next choice/result. Do not resolve a new choice inside SCENE.
        Owed change for the final consequence: \(owedChange)\(beatLine)
        """
    }
}

struct StoryPageContinuationContext: Equatable {
    var turns: [StoryPageSessionTurn]
    var currentDraft: StoryPageSceneDraft
    var selectedChoice: StoryPageChoiceDraft

    var resolvedTurns: [StoryPageSessionTurn] {
        turns.isEmpty
            ? [StoryPageSessionTurn(draft: currentDraft, selectedChoice: selectedChoice)]
            : turns.map { turn in
                var copy = turn
                if copy.id == turns.last?.id, copy.selectedChoice == nil {
                    copy.selectedChoice = selectedChoice
                }
                return copy
            }
    }

    var turnCount: Int {
        resolvedTurns.count
    }

    var latestTurn: StoryPageSessionTurn {
        resolvedTurns.last ?? StoryPageSessionTurn(draft: currentDraft, selectedChoice: selectedChoice)
    }

    var latestChoice: StoryPageChoiceDraft {
        latestTurn.selectedChoice ?? selectedChoice
    }

    var latestScene: String {
        latestTurn.draft.scene
    }

    var latestResult: String {
        latestTurn.result(for: latestChoice)
    }

    var promptContext: String {
        let turnsForPrompt = resolvedTurns

        // Prior turns arrive COMPRESSED: the model never sees full earlier
        // prose, because whatever it sees, it echoes. Summaries carry the
        // facts; the contract below forbids reuse.
        let turnCount = turnsForPrompt.count
        let rendered = turnsForPrompt.enumerated().map { index, turn in
            let choice = turn.selectedChoice ?? selectedChoice
            let isLatest = index == turnsForPrompt.count - 1
            let sceneLine = isLatest
                ? turn.draft.scene.bookPreviewSentenceLimit(4)
                : turn.draft.scene.bookPreviewSentenceLimit(1)
            let resultLine = turn.result(for: choice).bookPreviewSentenceLimit(isLatest ? 3 : 1)
            let inkbonesLine = turn.inkbonesResolution(for: choice)
                .map { "Inkbones: \($0.mechanicSummary)" }
                ?? ""
            return """
            TURN \(index + 1) (already written, already read):
            What happened: \(sceneLine)
            The reader chose: \(choice.title): \(choice.prompt)
            \(inkbonesLine)
            Consequence / last visible state: \(resultLine)
            Hidden movement: \(choice.effectLine)
            """
        }.joined(separator: "\n\n")

        let arc = StoryArcShape(
            beats: currentDraft.formBeats,
            turnsWritten: turnCount,
            formName: currentDraft.formName,
            promiseSeed: currentDraft.promiseSeed,
            turnStatement: currentDraft.turnStatement,
            turnCharacter: currentDraft.turnCharacter,
            turnLanding: StoryTurnLanding.resolve(currentDraft.turnLandings, choiceID: selectedChoice.id) ?? ""
        )
        let beatDirective = arc.directive
        let lensLine = currentDraft.genreLens.isEmpty ? "" : "\nKeep the \(currentDraft.genreName) lens: \(currentDraft.genreLens)"
        let recipeContinuation: String
        if let blueprint = currentDraft.blueprint {
            let modeLine: String
            switch blueprint.sceneMode {
            case .conversation: modeLine = "Conversation may carry the beat, but it need not become an argument."
            case .balanced: modeLine = "Balance speech, observation, and action."
            case .action: modeLine = "Advance through physical consequence; dialogue is optional."
            case .environmental: modeLine = "The setting, objects, weather, or Nothing may act and receive reactions."
            }
            recipeContinuation = """
            - SAME RECIPE: \(blueprint.recipeName). \(blueprint.continuationDirective)
            - MODE: \(modeLine) The original grounding already appeared; continue its consequence without repeating its wording.
            """
        } else {
            recipeContinuation = "- Spoken lines carry the new scene; characters react to people, and rooms, light, and props stay backdrop. No scenes built on handling small objects."
        }

        return """
        The reader asked for the one optional final beat. Everything under "already written" has ALREADY BEEN READ: it is context, never material to reuse.

        LAST VISIBLE STATE TO CONTINUE FROM:
        \(latestResult.bookPreviewSentenceLimit(3))

        THE CONTRACT FOR THE NEW SCENE: (Never repeat a sentence, image, or opening line from earlier turns, and never re-describe the setting; it exists.) The chosen action and its consequence already happened. The first sentence must begin AFTER the last visible state above.. Start from what the consequence changed and show its cost or gift through what a character says; do not restate the action itself.
        \(recipeContinuation) (140-220 words in 2-3 short paragraphs, beginning at a new point in the conversation. This is the final setup before the final reader choice) do not open a third beat.
        \(beatDirective)\(lensLine)

        \(rendered)
        """
    }
}

struct StoryPageProse: Equatable {
    var scene: String
    var choices: [StoryPageChoiceDraft]
    var results: [String: String]
    var source: String

    init(scene: String, choices: [StoryPageChoiceDraft], results: [String: String], source: String = "generated") {
        self.scene = scene
        self.choices = choices
        self.results = results
        self.source = source
    }

    init(fallback draft: StoryPageSceneDraft) {
        self.scene = draft.scene
        self.choices = draft.choices
        self.results = Dictionary(uniqueKeysWithValues: draft.choices.map { ($0.id, draft.result(for: $0)) })
        self.source = "fallback"
    }

    func result(for choice: StoryPageChoiceDraft) -> String {
        results[choice.id]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? choice.effectLine + " I record the change without making a fuss."
    }
}

struct StoryRecipeValidation: Equatable {
    var score: Int
    var failures: [String]
    var isAcceptable: Bool { failures.isEmpty }
}

enum StoryRecipeValidator {
    static func validate(_ prose: StoryPageProse, draft: StoryPageSceneDraft) -> StoryRecipeValidation {
        var score = 100
        var failures: [String] = []
        let metadata = draft.surface.payload.metadata
        let selectedIDs = (metadata["selectedEntityIDs"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let knownCharacterSelected = selectedIDs.contains { id in
            NarrativePackRegistry.entities.first(where: { $0.id == id })?.kind == .character
        }
        let expectsCharacterPerformance = draft.surface.type != .bookFae
            && (knownCharacterSelected
                || metadata["sessionLeaderEntityID"]?.nonEmpty != nil
                || draft.blueprint?.leadID.nonEmpty != nil)
        if expectsCharacterPerformance && draft.characterCanon.nonEmpty == nil {
            failures.append("Attach the binding character canon packet before generating prose.")
            score -= 45
        }
        if let debrief = AcademyActivityDebrief(metadata: metadata),
           !debrief.isAcknowledged(in: prose.scene) {
            let anchors = debrief.anchorTerms.prefix(6).joined(separator: ", ")
            failures.append(
                "This is an Academy practice return. Respond to the reader's submitted answer by naming at least one exact detail"
                    + (anchors.isEmpty ? "." : " (for example: \(anchors)).")
                    + " Do not replay the original lesson."
            )
            score -= 60
        }

        guard let blueprint = draft.blueprint else {
            return StoryRecipeValidation(score: score, failures: failures)
        }
        let scene = prose.scene.lowercased()
        // World-led recipes treat grounding as atmosphere, so a scene that
        // never quotes it is doing its job, not failing it.
        if !StoryFormRegistry.isWorldLedRecipe(id: blueprint.recipeID) {
            let stop = Set(["this", "that", "with", "from", "have", "into", "page", "says", "player", "their"])
            let groundingWords = blueprint.grounding.text.lowercased().split { !$0.isLetter && !$0.isNumber }
                .map(String.init).filter { $0.count >= 4 && !stop.contains($0) }
            let overlap = Set(groundingWords).filter { scene.contains($0) }.count
            if overlap < min(2, max(1, Set(groundingWords).count)) {
                failures.append("Use the selected grounded detail explicitly."); score -= 35
            }
        }
        if !scene.contains(blueprint.leadName.split(separator: " ").first.map(String.init)?.lowercased() ?? blueprint.leadName.lowercased()) {
            failures.append("Put \(blueprint.leadName) visibly in the scene."); score -= 25
        }
        if let companion = blueprint.companionName,
           !scene.contains(companion.split(separator: " ").first.map(String.init)?.lowercased() ?? companion.lowercased()) {
            failures.append("Put \(companion) visibly in the scene."); score -= 20
        }
        let words = scene.split { $0.isWhitespace }.count
        let sentences = scene.split { ".!?".contains($0) }.count
        if words < 100 || sentences < 5 { failures.append("Write a complete vignette of at least five sentences."); score -= 20 }
        let dialogueMarks = prose.scene.filter { $0 == "\"" || $0 == "“" || $0 == "”" }.count
        if blueprint.sceneMode == .conversation && dialogueMarks < 4 {
            failures.append("Let conversation carry this conversation-mode recipe."); score -= 15
        }
        let generic = [
            "follow the thread", "stay with it", "look closer", "do something surprising",
            "press the want", "open a side door", "choose the detail", "move the plot",
            "ask softly", "let them act", "let it act", "follow the clue"
        ]
        if prose.choices.contains(where: { choice in generic.contains { choice.title.lowercased().contains($0) || choice.prompt.lowercased().contains($0) } }) {
            failures.append("Anchor every choice to this exact scene."); score -= 10
        }
        if let contract = blueprint.dramaticContract {
            let requiredFields = [
                contract.leadCharacterWant, contract.leadCharacterWorry,
                contract.leadCharacterBlindSpot, contract.otherCharacterPressure,
                contract.relationshipQuestion, contract.stakes
            ]
            if requiredFields.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                || contract.choiceEffects.count != StoryChoiceRole.allCases.count {
                failures.append("Resolve the complete dramatic contract before prose generation.")
                score -= 60
            }
            let pressureTerms = significantTerms(
                contract.leadCharacterWant + " " + contract.leadCharacterWorry + " " + contract.otherCharacterPressure
            )
            let sceneTerms = Set(scene.split { !$0.isLetter }.map(String.init))
            if pressureTerms.intersection(sceneTerms).count < min(4, max(2, pressureTerms.count)) {
                failures.append("Stage the lead's want, worry, and the other character's counter-pressure in the opening.")
                score -= 35
            }
            for choice in prose.choices {
                guard let effect = contract.effect(for: choice.id) else {
                    failures.append("Give every path a precommitted character effect.")
                    score -= 30
                    continue
                }
                let choiceText = "\(choice.title) \(choice.prompt)".lowercased()
                let reactor = effect.requiredReactorName.split(separator: " ").first.map(String.init)?.lowercased()
                    ?? effect.requiredReactorName.lowercased()
                let lead = contract.leadCharacterName.split(separator: " ").first.map(String.init)?.lowercased()
                    ?? contract.leadCharacterName.lowercased()
                if !choiceText.contains(reactor) && !choiceText.contains(lead) {
                    failures.append("Make the \(choice.kindLabel) path name who it pressures: \(effect.requiredReactorName) or \(contract.leadCharacterName).")
                    score -= 15
                }
            }
            let choiceActions = prose.choices.map { significantTerms($0.prompt) }
            if choiceActions.count == 3,
               choiceActions[0].intersection(choiceActions[1]).count >= min(choiceActions[0].count, choiceActions[1].count),
               choiceActions[1].intersection(choiceActions[2]).count >= min(choiceActions[1].count, choiceActions[2].count) {
                failures.append("Make the three choices exert genuinely different pressure on the characters.")
                score -= 20
            }
        }
        return StoryRecipeValidation(score: score, failures: failures)
    }

    private static func significantTerms(_ text: String) -> Set<String> {
        let stop: Set<String> = [
            "about", "after", "again", "because", "before", "between", "could", "their",
            "there", "these", "those", "through", "under", "which", "while", "with", "would"
        ]
        return Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 4 && !stop.contains($0) })
    }
}

protocol StoryPageWriting {
    func write(surface: SurfacePage) async throws -> StoryPageProse
}

struct StoryPageResultContext: Equatable {
    var previousTurns: [StoryPageSessionTurn]
    var draft: StoryPageSceneDraft
    var selectedChoice: StoryPageChoiceDraft
    var inkbonesResolution: StoryInkbonesResolution? = nil

    var committedLanding: String? {
        StoryTurnLanding.resolve(draft.turnLandings, choiceID: selectedChoice.id)
    }

    var dramaticEffect: StoryDramaticChoiceEffect? {
        draft.dramaticContract?.effect(for: selectedChoice.id)
    }

    var fallbackResult: String {
        guard let inkbonesResolution else {
            return draft.result(for: selectedChoice)
        }
        return inkbonesResolution.fallbackConsequence(
            preparedResult: draft.result(for: selectedChoice),
            committedLanding: committedLanding,
            effectLine: selectedChoice.effectLine
        )
    }
}

protocol StoryPageResultWriting {
    /// `correction` names what was wrong with the previous attempt.
    ///
    /// The outer validator used to answer a rejected beat by calling this again
    /// with an identical context, which is not a retry - it is an independent
    /// sample of the same request, so the second beat had no reason to resemble
    /// or improve on the first. The writer already had a correction channel for
    /// its own inner repair pass; this exposes it.
    func write(context: StoryPageResultContext, correction: String?) async throws -> String
}

extension StoryPageResultWriting {
    func write(context: StoryPageResultContext) async throws -> String {
        try await write(context: context, correction: nil)
    }
}

private struct AppStoryPageWriter: StoryPageWriting {
    let local: StoryPageWriting
    private let fallback = FakeStoryPageWriter()

    func write(surface: SurfacePage) async throws -> StoryPageProse {
        do {
            return try await local.write(surface: surface)
        } catch {
            appLog.error("Local Story Page prose fell back: \(error.localizedDescription, privacy: .private)")
            return try await fallback.write(surface: surface)
        }
    }
}

struct FakeStoryPageWriter: StoryPageWriting {
    func write(surface: SurfacePage) async throws -> StoryPageProse {
        try await Task.sleep(nanoseconds: 450_000_000)
        return StoryPageProse(fallback: StoryPageSceneDraft(surface: surface))
    }
}

private struct FakeStoryPageResultWriter: StoryPageResultWriting {
    func write(context: StoryPageResultContext, correction: String?) async throws -> String {
        try await Task.sleep(nanoseconds: 350_000_000)
        return context.fallbackResult
    }
}

struct SentenceRunnerProseContext: Equatable {
    var caught: [String]
    var nothingHits: [String]
    var outcomeTitle: String
    var form: String
    var deterministic: String
    var archiveSamples: [String] = []
    var rescues: [String] = []
}

protocol SentenceRunnerProseWriting {
    func write(context: SentenceRunnerProseContext) async throws -> String
}

struct FakeSentenceRunnerProseWriter: SentenceRunnerProseWriting {
    func write(context: SentenceRunnerProseContext) async throws -> String {
        try await Task.sleep(nanoseconds: 350_000_000)
        return context.deterministic
    }
}

enum SentenceRunnerPromptBuilder {
    static let instructions = """
    You are The Book inside ReEnchanted, writing up the result of a Game Page called The Sentence Runner.
    The reader just played a small runner game whose obstacles are phrases pulled from their own kept pages (bright words) and Routine's vague filler (grey words).
    Your real work is RE-ENCHANTMENT: Routine flattens real life into grey words like "fine" or "later"; you restore the concrete thing each grey word was hiding, using only the reader's own kept phrases as the source of that meaning.
    You are given the bright words they caught, the grey words that touched them, sample phrases from their archive, a deterministic rescue draft, and a deterministic prose draft. Rewrite both drafts into finished prose.
    Use ONLY the supplied caught words, grey words, and archive samples as material. Do not invent new events, characters, places, or facts.
    Do not mention games, scores, points, tokens, taps, code, prompts, or simulation machinery.
    \(BookVoice.animismLine)
    """

    static func prompt(for context: SentenceRunnerProseContext) -> String {
        let caught = context.caught.isEmpty ? "(none)" : context.caught.joined(separator: ", ")
        let grey = context.nothingHits.isEmpty ? "(none)" : context.nothingHits.joined(separator: ", ")
        let samples = context.archiveSamples.isEmpty ? "(none)" : context.archiveSamples.joined(separator: ", ")
        let formInstruction = context.form == "miniStory"
            ? "Write a short mini-story of 4-6 sentences that weaves the caught words into one small scene of the reader crossing the margin."
            : "Write a short poem of 2-4 lines built from the caught words."
        var sections = [
            "Outcome: \(context.outcomeTitle)",
            "Caught (bright) words: \(caught)",
            "Grey words touched: \(grey)",
            "Archive samples (the only material for re-enchantment): \(samples)",
            "\(formInstruction)\nIf any grey words are present, do not leave them flat: re-enchant each one into the concrete memory it was hiding, drawn from the archive samples, then let the run move past it."
        ]
        if !context.rescues.isEmpty {
            sections.append("Rescue draft to elevate (one restored line per grey word; keep each word's restored meaning):\n" + context.rescues.joined(separator: "\n"))
        }
        sections.append("Deterministic draft to elevate (keep its shape and meaning):\n\(context.deterministic)")
        return sections.joined(separator: "\n\n")
    }
}

enum GossipPagePromptBuilder {
    static func instructions(for surface: SurfacePage) -> String {
        surface.type == .bookAside ? BookAsideForm.instructions : GossipPageForm.instructions
    }

    static func prompt(for surface: SurfacePage, nowPlaying: String? = nil) -> String {
        if surface.type == .bookAside {
            return bookAsidePrompt(for: surface, nowPlaying: nowPlaying)
        }
        let metadata = surface.payload.metadata
        return """
        Rewrite the following deterministic Gossip Page simulation output as a finished page for the user.

        Requirements:
        \(GossipPageForm.finishedPageRequirements). Keep it under 320 words.

        Actors: \(metadata["actorNames"] ?? metadata["actorName"] ?? "unknown")
        Threads: \(metadata["threadTitles"] ?? metadata["threadTitle"] ?? "unknown")
        Actions: \(metadata["actionKinds"] ?? metadata["actionKind"] ?? "unknown")
        Hidden effects to preserve without naming as mechanics:
        \(metadata["hiddenEffect"] ?? "none")

        Simulation turns:
        \(metadata["simulationPacket"] ?? "none")

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")

        Draft:
        \(metadata["gossipDraft"] ?? surface.payload.body)

        Real-world interest clippings:
        \(metadata["realInterestClippings"] ?? "none")

        Real-world sources, for grounding only:
        \(metadata["realInterestSources"] ?? "none")\(RadioAtmosphere.promptSection(nowPlaying))\(metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(metadata[BookVoicePatina.metadataKey]?.nonEmpty.map { "\n\n\($0)" } ?? "")

        Return only the finished Gossip Page text.
        """
    }

    private static func bookAsidePrompt(for surface: SurfacePage, nowPlaying: String?) -> String {
        let metadata = surface.payload.metadata
        return """
        Turn the following exact fictional receipts into a private Aside spoken by the living Book to its reader.

        \(BookAsideForm.sourcePacket(for: surface))

        BOOK'S CURRENT RELATIONSHIP TO THE READER:
        This is a confidant moment. The Book witnessed the event, has a personal reaction, and has been waiting to tell the reader. It may be delighted, worried, indignant, proud, suspicious, or willing to admit it was wrong. It must not pretend to know facts outside the supplied packet.

        \(metadata[CharacterCanonPacket.metadataKey] ?? "")\(RadioAtmosphere.promptSection(nowPlaying))\(metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(metadata[BookVoicePatina.metadataKey]?.nonEmpty.map { "\n\n\($0)" } ?? "")

        Return only the finished Aside. No title and no explanatory preface.
        """
    }

    static func clean(_ response: String, fallback: String) -> String {
        let cleaned = response
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallback }
        return cleaned
    }
}

#if !NATIVE_LOCAL_BRAIN || !(canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator))
protocol GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String
}

struct FakeGossipPageWriter: GossipPageWriting {
    func write(surface: SurfacePage) async throws -> String {
        try await Task.sleep(nanoseconds: 250_000_000)
        guard let clippings = surface.payload.metadata["realInterestClippings"]?.nonEmpty else {
            return surface.payload.body
        }
        return """
        \(surface.payload.body)

        From the ordinary world:
        \(clippings)
        """
    }
}
#endif

enum StoryPageResultPromptBuilder {
    static let instructions = """
    You are The Book inside ReEnchanted.
    Write only the consequence of the selected Story Page action. The app owns the mechanics; you write the ink.
    Do not invent completed real-world actions, exact locations, diagnoses, private facts, identities, or surveillance details.
    Keep it grounded, strange, concrete, and warm. No headings. No labels. No choices.
    \(BookVoice.animismLine)
    Prose standard: simple surprising sentences; specific nouns and verbs; dialogue before stage business; no generic wisdom, no abstract emotional summary, no mist, echoes, tapestry, journey, profound, or quiet magic.
    """

    static func prompt(for context: StoryPageResultContext) -> String {
        let prior = context.previousTurns.suffix(2).enumerated().map { index, turn in
            let chosen = turn.selectedChoice.map { choice in
                "Chosen: \(choice.kindLabel): \(choice.title). Result: \(turn.result(for: choice).bookPreviewSentenceLimit(2))"
            } ?? "Chosen: unresolved."
            return """
            PRIOR TURN \(index + 1):
            \(turn.draft.scene.bookPreviewSentenceLimit(2))
            \(chosen)
            """
        }.joined(separator: "\n\n")

        let landing = context.committedLanding
        let who = context.draft.turnCharacter.nonEmpty ?? "the character present"
        let recipeResultRule: String
        if let blueprint = context.draft.blueprint {
            switch blueprint.sceneMode {
            case .conversation:
                recipeResultRule = "Let \(who)'s speech carry the consequence, without requiring conflict."
            case .balanced:
                recipeResultRule = "Use speech, observation, or action in whatever balance best resolves the chosen path."
            case .action:
                recipeResultRule = "Show the physical consequence first; dialogue is optional."
            case .environmental:
                recipeResultRule = "The place, object, weather, or Nothing may act and change; dialogue is optional."
            }
        } else {
            recipeResultRule = "Show \(who) saying it to another person. Keep the room and props as backdrop."
        }
        let turnBlock = landing.map { line in
            """

            THIS ACTION RESOLVES THE SCENE'S TURN. By the end, this must be TRUE:
            \(line)
            \(recipeResultRule) Do not restate the chosen action as a sentence: show its consequence.
            """
        } ?? ""
        let dramaticBlock = context.dramaticEffect.map { effect in
            """

            THIS CHOICE'S CHARACTER CONSEQUENCE IS PRECOMMITTED:
            Required reactor: \(effect.requiredReactorName)
            Required visible reaction: \(effect.requiredReaction)
            Changed fact that becomes canon: \(effect.changedFact)
            What the reader's choice changes: \(effect.readerChoiceEffect)
            The result must show all four. Do not substitute a different character, reaction, or emotional outcome.
            """
        } ?? ""

        let voice = context.draft.genreName.isEmpty
            ? ""
            : "\n\nGENRE VOICE: \(context.draft.genreName): \(context.draft.genreLens)"
        let inkbonesBlock = context.inkbonesResolution.map {
            "\n\n" + $0.narrativePromptSection(
                committedLanding: landing,
                effectLine: context.selectedChoice.effectLine
            )
        } ?? ""
        let mechanicRequirement = context.inkbonesResolution == nil
            ? "If SELECTED MECHANIC is not none, write only around the supplied consequence. Do not invent that an unfinished mechanic was completed."
            : "The Inkbones mechanic is complete. Make its supplied band visibly change how the committed landing happens; do not reroll or reduce it to a win/loss label."
        return """
        Write the result for this selected Story Page action.

        THREAD:
        \(context.draft.thread)\(voice)

        \(context.draft.characterCanon)

        CURRENT SCENE:
        \(context.draft.scene)
        \(turnBlock)
        SELECTED PATH TYPE:
        \(context.selectedChoice.kindLabel)

        SELECTED MECHANIC:
        \(context.selectedChoice.mechanic.kind.rawValue)

        BESPOKE BUTTON:
        \(context.selectedChoice.title)

        ACTION PROMPT:
        \(context.selectedChoice.prompt)

        HIDDEN MOVEMENT TO DRAMATIZE WITHOUT NAMING AS MECHANICS:
        \(context.selectedChoice.effectLine)\(dramaticBlock)\(inkbonesBlock)

        RECENT THREAD MEMORY:
        \(prior.isEmpty ? "No prior turns." : prior)\(context.draft.surface.payload.metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(context.draft.surface.payload.metadata["storyQuillDirective"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(context.draft.surface.payload.metadata[BookVoicePatina.metadataKey]?.nonEmpty.map { "\n\n\($0)" } ?? "")

        REQUIREMENTS: (Return only the result prose.) 90-150 words. (5-8 sentences.) Make the consequence specific to the selected action, not generic. (\(context.draft.blueprint == nil ? "Make most of this result spoken exchange and include no more than one small physical action." : recipeResultRule)) Let one relationship, secret, refusal, promise, or question gain weight. (Make the named reactor answer, trust, hide, refuse, admit, decide, or revise something on the page; atmosphere is not a reaction.) If this is Progress Arc, let the thread move one step. (If this is Slice of Life, let an ordinary detail deepen.) If this is Surprise, reveal a strange related angle that still belongs here. (\(mechanicRequirement)) Do not include headings, button titles, labels, JSON, markdown, or additional choices.
        """
    }

    static func clean(_ response: String) -> String {
        response
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "RESULT:", with: "")
            .replacingOccurrences(of: "Result:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum StoryPagePromptBuilder {
    static let instructions = """
    You are The Book inside ReEnchanted, writing one interactive storybook vignette.
    Write like a sharp storyteller, never an assistant: simple surprising sentences, specific nouns and verbs, people who show themselves by what they say.
    \(BookVoice.animismLine)
    Never invent completed real-world actions, exact locations, diagnoses, private facts, or identities.
    Never write filler: no generic wisdom, no abstract emotional summary, no "tapestry", "echoes", "journey", "profound", or "quiet magic".
    """

    static func prompt(for draft: StoryPageSceneDraft, nowPlaying: String? = nil, radioNarrativeEcho: RadioNarrativeEcho? = nil) -> String {
        if draft.surface.type == .academyClass {
            return academyLessonPrompt(for: draft)
        }
        let entities = draft.entities.isEmpty ? "The Book" : draft.entities.joined(separator: ", ")
        let setting = draft.storySettingName.isEmpty
            ? "No named setting; stage the scene wherever the concrete material lives."
            : "\(draft.storySettingName): \(draft.storySettingDetail.nonEmpty ?? "The physical stage, not a speaking character.")"
        let paletteSeeds = draft.rotatedGenrePalette(count: 4)
        let signals: String
        if !draft.signals.isEmpty {
            signals = draft.signals.prefix(6).map { "- \($0)" }.joined(separator: "\n")
        } else if !paletteSeeds.isEmpty {
            signals = "- The day sent no outside signal. Build the scene around two or three of these instead, made specific: \(paletteSeeds.joined(separator: ", "))."
        } else {
            signals = "- The day sent no outside signal. Invent two small concrete props (a cup gone cold, a note under a door, a key that fits nothing) and let them matter."
        }
        let pressures = draft.pressures.isEmpty ? "" : "\n\nRELATIONSHIP / STORY PRESSURE:\n" + draft.pressures.prefix(4).map { "- \($0)" }.joined(separator: "\n")
        let memories = draft.memories.isEmpty ? "" : "\n\nENTITY MEMORY:\n" + draft.memories.prefix(4).map { "- \($0)" }.joined(separator: "\n")
        let talismanMoves = draft.chapterTalismanMoves.isEmpty ? "" : "\n\nCHAPTER TALISMAN MOVES: show the listed move as a visible character action; never invent one:\n" + draft.chapterTalismanMoves.prefix(3).map { "- \($0)" }.joined(separator: "\n")
        let continuation = draft.continuationContext.map {
            """

            CONTINUATION MEMORY:
            \($0)
            """
        } ?? ""
        let mechanicPlan = mechanicPlanPrompt(for: draft.mechanicMandate)
        let structure: String
        let formBeats = StoryVignetteBeats.snackSized(draft.formBeats)
        if formBeats.isEmpty {
            structure = "A snack-sized vignette with setup, choice pressure, and a landing held open."
        } else {
            let beats = formBeats.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            structure = """
            This page follows the shape called "\(draft.formName)":
            \(beats)
            Write beat 1 now; beat 2 comes only after the reader chooses. Beats are felt, never named in the prose.
            """
        }
        let promise: String
        if draft.promiseSeed.isEmpty {
            promise = ""
        } else {
            promise = """


            THE PROMISE: plant now, pay off at the end:
            Seed (an ordinary, specific, slightly charged detail; introduce it, never resolve or explain it yet): \(draft.promiseSeed)
            The whole vignette leans toward: \(draft.promiseQuestion)
            """
        }
        let engine: String
        if let blueprint = draft.blueprint {
            let modeRule: String
            switch blueprint.sceneMode {
            case .conversation:
                modeRule = "Dialogue carries the scene; every line concerns the concrete premise. Warmth or play is fine; conflict is not required."
            case .balanced:
                modeRule = "Balance dialogue, observation, and consequential action."
            case .action:
                modeRule = "Physical action carries the scene and changes the situation; dialogue is optional."
            case .environmental:
                modeRule = "The place, weather, objects, or Routine may act and cause consequences; keep the reader's possible response concrete."
            }
            let groundingRule = StoryFormRegistry.isWorldLedRecipe(id: blueprint.recipeID)
                ? "Real-day atmosphere: let it tint light, weather, and hour only. Never quote, discuss, or explain the reader's pages or day; the world is running its own errand: \(blueprint.grounding.text)"
                : "This exact material MUST drive the scene as causation, evidence, a topic, or a threatened thing, never wallpaper: \(blueprint.grounding.text)"
            let dramaticContract = blueprint.dramaticContract.map { contract in
                let effects = contract.choiceEffects.map { effect in
                    "- \(effect.role.title): \(effect.requiredReactorName) must \(effect.requiredReaction) Changed fact: \(effect.changedFact)"
                }.joined(separator: "\n")
                return """

                DRAMATIC CONTRACT: decided before prose:
                Who is here: \(contract.leadCharacterName) and \(contract.otherCharacterName).
                What \(contract.leadCharacterName) wants: \(contract.leadCharacterWant)
                What they worry about: \(contract.leadCharacterWorry)
                What they may be wrong about: \(contract.leadCharacterBlindSpot)
                Pressure from \(contract.otherCharacterName): \(contract.otherCharacterPressure)
                Relationship question: \(contract.relationshipQuestion)
                Stakes if nobody answers: \(contract.stakes)
                The three reader paths must pressure the relationship differently:
                \(effects)
                The opening must visibly stage the want, worry or blind spot, and counter-pressure. Do not answer the relationship question yet.
                """
            } ?? ""
            engine = """


            SCENE RECIPE: \(blueprint.recipeName):
            Premise: \(blueprint.premise)
            \(groundingRule)
            Cast: \([blueprint.leadName, blueprint.companionName].compactMap { $0 }.joined(separator: ", "))
            Setting: \(setting)
            Beats, in order:
            \(StoryVignetteBeats.snackSized(blueprint.beats).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
            Required change by the end: \(blueprint.turn.statement)
            \(dramaticContract)
            Grounding: \(blueprint.groundingDirective)
            Tone: \(blueprint.toneDirective)
            Scene mode: \(modeRule)
            The setting constrains the scene but is not a cast member; name concrete nouns and actions, not vague feelings.
            """
        } else if draft.turnStatement.isEmpty {
            engine = ""
        } else {
            let registerLine = draft.turnRegister == "quiet"
                ? "Register: quiet: low and warm; the change can be a small thing understood."
                : "Register: active: someone does, decides, or says something that changes the situation."
            engine = """


            THE SCENE'S ENGINE:
            \(draft.turnCharacter) wants: \(draft.turnWant)
            In the way: \(draft.turnObstacle)
            By the end of this whole page this must become true: \(draft.turnStatement)
            Open on \(draft.turnCharacter) already talking to another person: wanting this, obstacle audible, unresolved. They speak within the first two sentences.
            Dialogue carries the scene; actions are brief interruptions. Rooms, weather, light, and props stay backdrop: characters react to people, and nobody builds a scene around handling small objects.
            \(registerLine)
            """
        }
        let voice: String
        if draft.genreName.isEmpty {
            voice = ""
        } else {
            let sample = draft.genreExemplar.nonEmpty.map {
                "\nHear the register in this sample from a DIFFERENT story: match its music, never reuse its people, props, or lines:\n\"\($0)\""
            } ?? "\nThe lens colors diction, pacing, and what the camera notices; it never overrides the real material."
            voice = "\n\nGENRE VOICE: \(draft.genreName): \(draft.genreLens)\(sample)"
        }
        let isBookFae = draft.surface.type == .bookFae
        let faeDirective = isBookFae
            ? """

            BOOK FAE PAGE:
            This is not an ordinary Story Page and not a Fae Bargain. It is a parley with \(draft.surface.payload.metadata["faeName"] ?? "a Book Fae").
            The Book itself narrates the visitation. Its voice is intimate, observant, faintly amused, and alert to old dangers. Do not narrate as the Fae, an assistant, or a neutral game master.
            Use old faerie manners: courtesy, exact wording, beautiful danger, gifts with edges, loopholes, and alien attention.
            Failure must never read as punishment. Consequences are marks, obligations, debts of attention, strange gifts, and story hooks.
            Build the scene from the supplied Fae identity, court, omen, standing, recent kept material, and entity memory. The visitor must want, notice, test, offer, conceal, or interrupt something specific.
            Make the parley about the Fae's voice, appetite, courtesy, refusal, rules, and concealed desire. Kept objects may be named as evidence or bait, but they must not become the subject of the page or be moved around as business.
            Let the Fae speak at least three times in direct quotation. Their speech should be exact, strange, and transactional, with one line that sounds courteous and one line that sounds dangerous.
            Preserve the three old-law paths beneath the choices: courtesy softens Claim, naming the law deepens the relationship, and taking the thorn sharpens Claim for a secret.
            Rewrite every visible choice title and prompt to fit this exact vignette. Anchor each choice to a specific line, object, gesture, mark, loophole, or offer that appeared in SCENE. Never reuse the framework titles "Offer Courtesy", "Name the Law", or "Take the Thorn" unless those exact words are uniquely necessary in this scene.
            Use the Book of You braid style: varied literary cadence, concrete ordinary objects made strange, dark playfulness, lucid sentences, and endings that land softly but sharply.
            """
            : ""
        return """
        Write one ReEnchanted Story Page.

        World rule: magic here is written, never waved. Cast members work spells through pens, quills, and pencils (there are no wands) and every writing implement has opinions of its own about what it is asked to write.

        THREAD:
        \(draft.thread)

        STRUCTURE:
        \(structure)\(promise)\(engine)\(voice)

        CAST AND WORLD ENTITIES:
        \(entities)

        \(draft.characterCanon)

        SETTING:
        \(setting)

        REAL MATERIAL:
        \(signals)\(pressures)\(memories)\(talismanMoves)\(faeDirective)\(RadioAtmosphere.promptSection(nowPlaying))\(RadioNarrativeEchoPrompt.section(radioNarrativeEcho))\(draft.surface.payload.metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(draft.surface.payload.metadata["storyQuillDirective"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(draft.surface.payload.metadata[BookVoicePatina.metadataKey]?.nonEmpty.map { "\n\n\($0)" } ?? "")
        \(continuation)\(mechanicPlan)

        OUTPUT FORMAT, EXACTLY:
        SCENE:
        \(isBookFae ? "240-380" : "260-420") words in 3-5 short paragraphs. Setup, choice pressure, and a landing held open for the reader. Real life becoming a fantasy story, not a quest log. Address the reader as "you" only when natural.\(draft.blueprint == nil ? " Mostly dialogue when a character is present; rooms and props stay backdrop." : " Follow SCENE RECIPE's mode for what carries the scene.")\(draft.continuationContext == nil ? "" : " Continue the same thread: do not recap; begin after the previous consequence and let it change the first paragraph.")
        Only the vignette goes here: no choices, button titles, labels, mechanics, or instructions.

        SLICE_OF_LIFE_CHOICE:
        Button title, 2-5 words: staying with one concrete detail from this exact scene.

        SLICE_OF_LIFE_PROMPT:
        One sentence under 16 words: the specific action the reader takes.

        PROGRESS_ARC_CHOICE:
        Button title, 2-5 words: moving \(draft.thread) one step forward.

        PROGRESS_ARC_PROMPT:
        One sentence under 16 words: the specific action the reader takes.

        SURPRISE_CHOICE:
        Button title, 2-5 words: a strange related move that still belongs here.

        SURPRISE_PROMPT:
        One sentence under 16 words: the specific action the reader takes.

        Choice rule: every choice must name a specific person, spoken line, object, or fact from SCENE: something said, asked, refused, given, opened, followed, or protected. Every choice must visibly put pressure on the named character assigned to that path, while leaving its result unwritten.\(draft.blueprint.map { " Choices should offer: \($0.choiceDirective)" } ?? "") Never use generic titles like "Stay With It", "Follow the Thread", or "Look Closer".
        Do not write any result sections; The Book writes the consequence after the reader chooses.
        """
    }

    private static func academyLessonPrompt(for draft: StoryPageSceneDraft) -> String {
        let metadata = draft.surface.payload.metadata
        let isClub = metadata["sessionKind"] == "club"
        let debrief = AcademyActivityDebrief(metadata: metadata)
        let leader = metadata["sessionLeader"] ?? "the professor"
        let lessonTitle = metadata["lessonTitle"]?.nonEmpty ?? metadata["sessionName"] ?? "The Lesson"
        let lectureBeats = metadata["lessonLectureBeats"]?.nonEmpty ?? metadata["sessionTeaches"] ?? "Teach the day's subject concretely."
        let concept = metadata["lessonConcept"]?.nonEmpty ?? metadata["sessionTeaches"] ?? "The lesson has a real subject."
        let realSubject = metadata["lessonRealSubject"]?.nonEmpty ?? "the Academy subject"
        let demonstration = metadata["lessonDemonstration"]?.nonEmpty ?? "Demonstrate the subject with one concrete classroom object."
        let interaction = metadata["lessonInteractionPrompt"]?.nonEmpty ?? "Ask the reader one answerable question about the lesson."
        let practice = metadata["lessonRealWorldPractice"]?.nonEmpty ?? "Offer one small real-world practice for later; do not claim it is done."
        let continuation = draft.continuationContext.map {
            "\n\nCONTINUATION MEMORY:\n\($0)"
        } ?? ""
        let socialTurn = draft.turnStatement.isEmpty ? "" : """


        THE SOCIAL TURN (rides alongside the lesson: it must NOT replace the teaching):
        \(draft.turnCharacter) wants: \(draft.turnWant)
        In the way: \(draft.turnObstacle)
        By the end of this page this also becomes true: \(draft.turnStatement)
        Let \(draft.turnCharacter) and the students be people with a small stake, not mouthpieces, but the lesson's concept still lands fully. The turn is the warmth around the teaching, never instead of it.
        """
        let mechanicPlan = mechanicPlanPrompt(for: draft.mechanicMandate)
        let pagePurpose = debrief == nil
            ? "This page is a compact lesson first and a vignette second. It should read like the reader has actually stepped into a useful class, not like a teaser for one. Define the idea plainly, let a student test it aloud, use one brief demonstration, and leave the reader with one concrete practice."
            : "This page is the debrief after the reader completed the class practice. Their submitted answer (not the original demonstration) is the subject of this new beat. The lesson advances by receiving and interpreting what they actually wrote."
        let debriefSection = debrief.map { "\n\n\($0.promptSection)" } ?? ""
        let outputSceneContract = debrief == nil
            ? """
            220-320 words. A living classroom scene with the lesson already underway, the required leader visibly teaching, and the reader invited into the exercise.
            Structure the SCENE as 3 short paragraphs, with no headings:
            1. The lesson already underway, one vivid classroom detail, and the leader's spoken thesis.
            2. The leader's mini-lecture using two supplied lecture beats, one concrete example, and a student's spoken test or mistake.
            3. The leader's correction, the reader's direct question, and one real-world practice invitation for later.
            """
            : """
            150-240 words in 2-3 short paragraphs. Begin with the submitted practice already in the leader's hands.
            1. The leader quotes or names one exact detail from the reader's answer and responds to what that detail changes.
            2. Apply the lesson's concept to the answer; let one companion react or revise their own understanding.
            3. End on one new, answer-shaped observation or question. Do not repeat the old lecture, demonstration, practice invitation, or classroom entrance.
            """
        let hardRules = debrief == nil
            ? """
            - \(leader) must be physically present, must teach, and must speak at least twice.
            - Most of SCENE should be dialogue: lecture lines, student answers, corrections, and the reader-facing question.
            - This must teach the real subject, not merely mention it. Include two accurate mini-lecture beats and one demonstrated example.
            - Use the first two supplied lecture beats in order. Do not skip the lesson just to reach the choices.
            - Spend most of SCENE on the class exchange: explanation, student response, correction, and reader question. Keep arrival/setup to one sentence.
            - The professor or leader asks the reader one direct, answerable classroom question.
            - Do not claim the reader completed the practice, attended earlier, or did any real-world task.
            - Complete every sentence. If space gets tight, shorten description before cutting the lesson, question, or practice invitation.
            """
            : """
            - \(leader) must be physically present, speak at least twice, and receive the submitted answer before doing anything else.
            - Name or quote at least one exact submitted detail in the first paragraph. A generic “good work” does not count.
            - Teach by applying the core concept to the reader's detail. Do not recite the lecture beats or repeat the demonstration.
            - The completed practice is already real because the reader submitted it. Do not question whether they did it, invent anything beyond it, or assign it again.
            - The final question must follow from the submitted detail and must differ from the original Reader interaction.
            - Complete every sentence. If space gets tight, preserve the exact detail and the leader's response before anything else.
            """

        return """
        Write one ReEnchanted Academy \(isClub ? "Club Page" : "Class Page") using the Story Page format.

        \(pagePurpose)\(debriefSection)

        SESSION:
        \(isClub ? "Club" : "Class"): \(metadata["sessionName"] ?? "an Academy session")
        Required leader present in the room: \(leader)
        Room: \(metadata["sessionRoom"] ?? "an Academy room")
        Also present: \(metadata["sessionCompanions"] ?? "students")
        Teaching style: \(metadata["sessionStyle"] ?? "specific and alive")

        \(draft.characterCanon)

        REAL LESSON:
        Lesson title: \(lessonTitle)
        Real subject: \(realSubject)
        Core concept: \(concept)
        Lecture beats:
        \(lectureBeats)
        Demonstration: \(demonstration)
        Reader interaction: \(interaction)
        Real-world practice invitation: \(practice)
        \(socialTurn)
        \(continuation)\(metadata["readerLexiconPromptSection"]?.nonEmpty.map { "\n\n\($0)" } ?? "")\(mechanicPlan)

        HARD RULES:
        \(hardRules) (At least one companion reacts in a small characterful way.) Include only one room texture detail total. (Do not build the scene around moving classroom props. One demonstration object is allowed; repeated handling is not.) If CONTINUATION MEMORY is present, everything in it has already been read. Continue from the consequence; do not repeat the previous classroom scene, opening setup, image, dialogue, or chosen action. (A continued class scene must start one beat later: the lesson has advanced, or someone has visibly changed their answer.) If READER'S COMPLETED PRACTICE is present, it outranks the generic lesson structure. Use at least one exact submitted detail in SCENE, and never give the same assignment again.. Simple concrete sentences. No assistant language, no headings or labels inside SCENE.

        OUTPUT FORMAT, EXACTLY:
        SCENE:
        \(outputSceneContract)

        SLICE_OF_LIFE_CHOICE:
        Button title, 2-5 words: staying with one ordinary classroom detail.

        SLICE_OF_LIFE_PROMPT:
        One sentence under 16 words: the classroom action.

        PROGRESS_ARC_CHOICE:
        Button title, 2-5 words: answering or attempting the lesson.

        PROGRESS_ARC_PROMPT:
        One sentence under 16 words: the lesson action.

        SURPRISE_CHOICE:
        Button title, 2-5 words: a strange but subject-related side door.

        SURPRISE_PROMPT:
        One sentence under 16 words: the sideways action.

        Choice rule: visible titles must sound like natural class actions tied to this exact lesson.
        """
    }

    /// The app enforces the mandate in code after parsing, so the model never
    /// writes mechanic fields; it only shapes the mandated choice's wording.
    private static func mechanicPlanPrompt(for mandate: StoryPageMechanicMandate) -> String {
        guard mandate.kind != .none, let choiceID = mandate.choiceID else { return "" }
        let choiceName: String
        switch choiceID {
        case .sliceOfLife:
            choiceName = "SLICE_OF_LIFE"
        case .progressArc:
            choiceName = "PROGRESS_ARC"
        case .surprise:
            choiceName = "SURPRISE"
        }
        let inviteText: String
        switch mandate.kind {
        case .none:
            return ""
        case .beliefDice:
            inviteText = "a risky, uncertain story move worth rolling the Belief dice on"
        case .compassRun:
            inviteText = "a small real-world noticing errand"
        case .enchantment:
            let spell = StoryEnchantmentCatalog.spell(id: mandate.enchantmentID) ?? StoryEnchantmentCatalog.spells.first
            inviteText = "casting \"\(spell?.title ?? "an enchantment")\" (\(spell?.detail.lowercased() ?? "a small spell")) on one concrete thing in the scene"
        }
        return """


        MECHANIC NOTE (\(mandate.reason)):
        When it is tapped, the \(choiceName) choice will trigger \(inviteText). Write that choice's title and prompt so the action naturally invites this, without naming any mechanic or system.
        """
    }
}

enum StoryPageProseParser {
    enum ParseError: LocalizedError {
        case emptyResponse
        case missingScene(String)

        var errorDescription: String? {
            switch self {
            case .emptyResponse:
                return "Gemma returned an empty Story Page."
            case .missingScene(let preview):
                return "Gemma did not return a usable SCENE section for the Story Page.\n\nGemma returned:\n\(preview)"
            }
        }
    }

    static func parse(_ response: String, fallback draft: StoryPageSceneDraft) throws -> StoryPageProse {
        let fallbackProse = StoryPageProse(fallback: draft)
        let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedResponse.isEmpty else {
            throw ParseError.emptyResponse
        }

        guard let scene = section(.scene, in: cleanedResponse)
            .nonEmpty
            .map(cleanSceneText)?
            .nonEmpty ?? looseScene(in: cleanedResponse) else {
            throw ParseError.missingScene(responsePreview(cleanedResponse, limit: 900))
        }

        var choices = fallbackProse.choices
        choices = choices.map { choice in
            var updated = choice
            switch choice.id {
            case "sliceoflife":
                updated.title = bestTitle(for: .sliceChoice, promptMarker: .slicePrompt, in: cleanedResponse, fallback: choice.title)
                updated.prompt = section(.slicePrompt, in: cleanedResponse).singleLine(maxLength: 120) ?? section(.sliceChoice, in: cleanedResponse).singleLine(maxLength: 120) ?? choice.prompt
                updated.effectLine = updated.prompt
                updated.mechanic = StoryPageChoiceMechanic.parse(section(.sliceMechanic, in: cleanedResponse))
            case "progressarc":
                updated.title = bestTitle(for: .progressChoice, promptMarker: .progressPrompt, in: cleanedResponse, fallback: choice.title)
                updated.prompt = section(.progressPrompt, in: cleanedResponse).singleLine(maxLength: 120) ?? section(.progressChoice, in: cleanedResponse).singleLine(maxLength: 120) ?? choice.prompt
                updated.effectLine = updated.prompt
                updated.mechanic = StoryPageChoiceMechanic.parse(section(.progressMechanic, in: cleanedResponse))
            case "surprise":
                updated.title = bestTitle(for: .surpriseChoice, promptMarker: .surprisePrompt, in: cleanedResponse, fallback: choice.title)
                updated.prompt = section(.surprisePrompt, in: cleanedResponse).singleLine(maxLength: 120) ?? section(.surpriseChoice, in: cleanedResponse).singleLine(maxLength: 120) ?? choice.prompt
                updated.effectLine = updated.prompt
                updated.mechanic = StoryPageChoiceMechanic.parse(section(.surpriseMechanic, in: cleanedResponse))
            default:
                break
            }
            return updated
        }
        var results: [String: String] = [:]
        if let value = section(.sliceResult, in: cleanedResponse).nonEmpty {
            results["sliceoflife"] = value
        }
        if let value = section(.progressResult, in: cleanedResponse).nonEmpty {
            results["progressarc"] = value
        }
        if let value = section(.surpriseResult, in: cleanedResponse).nonEmpty {
            results["surprise"] = value
        }
        let repairedChoices = characterActionChoices(choices, fallback: fallbackProse.choices, draft: draft)
        let mandatedChoices = enforceMechanicMandate(draft.mechanicMandate, choices: repairedChoices)
        return StoryPageProse(scene: scene, choices: limitedMechanicChoices(mandatedChoices), results: results, source: "gemma")
    }

    private static func enforceMechanicMandate(
        _ mandate: StoryPageMechanicMandate,
        choices: [StoryPageChoiceDraft]
    ) -> [StoryPageChoiceDraft] {
        guard mandate.kind != .none, let mandatedChoiceID = mandate.choiceID?.rawValue else {
            return choices.map { choice in
                var copy = choice
                copy.mechanic = .none
                return copy
            }
        }
        return choices.map { choice in
            var copy = choice
            guard choice.id == mandatedChoiceID else {
                copy.mechanic = .none
                return copy
            }
            switch mandate.kind {
            case .none:
                copy.mechanic = .none
            case .beliefDice:
                copy.mechanic = StoryPageChoiceMechanic(kind: .beliefDice)
            case .compassRun:
                copy.mechanic = StoryPageChoiceMechanic(kind: .compassRun)
            case .enchantment:
                copy.mechanic = StoryPageChoiceMechanic(
                    kind: .enchantment,
                    enchantmentID: mandate.enchantmentID ?? StoryEnchantmentCatalog.spells.first?.id
                )
            }
            return copy
        }
    }

    private static func limitedMechanicChoices(_ choices: [StoryPageChoiceDraft]) -> [StoryPageChoiceDraft] {
        var hasMechanic = false
        return choices.map { choice in
            guard choice.mechanic.kind != .none else { return choice }
            if hasMechanic {
                var copy = choice
                copy.mechanic = .none
                return copy
            }
            hasMechanic = true
            return choice
        }
    }

    private static func characterActionChoices(_ choices: [StoryPageChoiceDraft], fallback: [StoryPageChoiceDraft], draft: StoryPageSceneDraft) -> [StoryPageChoiceDraft] {
        choices.map { choice in
            guard let fallbackChoice = fallback.first(where: { $0.id == choice.id }) else {
                return choice
            }
            guard draft.blueprint == nil, choiceReadsAsAtmosphere(choice) else {
                return choice
            }
            var repaired = fallbackChoice
            repaired.mechanic = choice.mechanic
            return repaired
        }
    }

    private static func choiceReadsAsAtmosphere(_ choice: StoryPageChoiceDraft) -> Bool {
        let text = "\(choice.title) \(choice.prompt)".lowercased()
        let sensoryTerms = [
            "atmosphere", "shadow", "light", "glass", "talisman", "resonance",
            "weather", "stillness", "silence", "scent", "smell", "sound",
            "listen", "watch", "examine", "hold", "follow", "notice", "trace",
            "texture", "surface", "glow", "color", "colour"
        ]
        let characterTerms = [
            "ask", "tell", "admit", "decide", "choose", "refuse", "offer",
            "answer", "trust", "name", "give", "take", "interrupt", "promise",
            "warn", "invite", "confront", "help"
        ]
        let hasSensoryHook = sensoryTerms.contains { text.contains($0) }
        let hasCharacterAction = characterTerms.contains { text.contains($0) }
        return hasSensoryHook && !hasCharacterAction
    }

    private static func responsePreview(_ response: String, limit: Int) -> String {
        let cleaned = response
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > limit else { return cleaned.isEmpty ? "<empty>" : cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: limit)
        return String(cleaned[..<end]) + "\n...[truncated]"
    }

    static func cleanSceneText(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let firstMarker = StoryPageSectionMarker.allCases
            .flatMap(\.aliases)
            .filter { !$0.lowercased().hasPrefix("scene") }
            .compactMap { alias -> String.Index? in
                normalized.range(of: "\n\(alias):", options: [.caseInsensitive])?.lowerBound
            }
            .min()
        let slice = firstMarker.map { normalized[..<$0] } ?? Substring(normalized)
        return String(slice).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looseScene(in response: String) -> String? {
        let normalized = response
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "```", with: "")
        let firstMarker = StoryPageSectionMarker.allCases
            .filter { $0 != .scene }
            .flatMap(\.aliases)
            .compactMap { alias -> String.Index? in
                normalized.range(of: "\n\(alias):", options: [.caseInsensitive])?.lowerBound
                    ?? normalized.range(of: "\n### \(alias)", options: [.caseInsensitive])?.lowerBound
                    ?? normalized.range(of: "\n**\(alias)**", options: [.caseInsensitive])?.lowerBound
            }
            .min()
        let slice = firstMarker.map { normalized[..<$0] } ?? Substring(normalized)
        let cleaned = String(slice)
            .replacingOccurrences(of: #"(?im)^\s*#{1,4}\s*scene\s*:?\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?im)^\s*\*{0,2}scene\*{0,2}\s*:?\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 80 else { return nil }
        guard cleaned.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?")) != nil else { return nil }
        return cleanSceneText(cleaned).nonEmpty
    }

    private static func section(_ marker: StoryPageSectionMarker, in response: String) -> String {
        let normalized = response.replacingOccurrences(of: "\r\n", with: "\n")
        guard let match = marker.aliases
            .compactMap({ alias -> Range<String.Index>? in
                normalized.range(of: "\(alias):", options: [.caseInsensitive])
            })
            .min(by: { $0.lowerBound < $1.lowerBound })
        else { return "" }
        let remainder = normalized[match.upperBound...]
        let next = StoryPageSectionMarker.allCases
            .flatMap(\.aliases)
            .compactMap { alias in
                remainder.range(of: "\n\(alias):", options: [.caseInsensitive])?.lowerBound
            }
            .min()
        let slice = next.map { remainder[..<$0] } ?? Substring(remainder)
        return String(slice).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestTitle(
        for marker: StoryPageSectionMarker,
        promptMarker: StoryPageSectionMarker,
        in response: String,
        fallback: String
    ) -> String {
        let explicit = titleFromButtonBlock(before: promptMarker, in: response)
        let roleTitle = section(marker, in: response).singleLine(maxLength: 42)
        return cleanChoiceTitle(explicit ?? roleTitle, fallback: fallback)
    }

    private static func titleFromButtonBlock(before promptMarker: StoryPageSectionMarker, in response: String) -> String? {
        let normalized = response.replacingOccurrences(of: "\r\n", with: "\n")
        guard let promptRange = promptMarker.aliases
            .compactMap({ normalized.range(of: "\($0):", options: [.caseInsensitive]) })
            .min(by: { $0.lowerBound < $1.lowerBound })
        else { return nil }
        let prefix = normalized[..<promptRange.lowerBound]
        guard let titleRange = prefix.range(of: "button title:", options: [.caseInsensitive, .backwards]) else { return nil }
        let titleSlice = prefix[titleRange.upperBound...]
        return String(titleSlice).singleLine(maxLength: 42)?.withoutTrailingSentencePunctuation
    }

    private static func cleanChoiceTitle(_ raw: String?, fallback: String) -> String {
        let cleaned = (raw?.withoutTrailingSentencePunctuation.nonEmpty ?? fallback)
            .replacingOccurrences(of: #"\b(SLICE_OF_LIFE|PROGRESS_ARC|SURPRISE)\s*:?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b(Slice of Life|Progress Arc|Surprise)\s*:?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' :.-"))
        let collapsed = cleaned.removingImmediateDuplicateSentence().singleLine(maxLength: 60)?.withoutTrailingSentencePunctuation
            ?? fallback.withoutTrailingSentencePunctuation
        // A button title is a short phrase. The model sometimes runs the title
        // straight into its own prompt ("Ask About the Light Ask what the light
        // means"): keep only the first clause, capped at six words, so the
        // button never shows half a sentence.
        let firstClause = collapsed.split(whereSeparator: { ",;—".contains($0) }).first.map(String.init) ?? collapsed
        let words = firstClause.split(separator: " ")
        let clamped = words.prefix(6).joined(separator: " ")
        return clamped.nonEmpty ?? fallback.withoutTrailingSentencePunctuation
    }

    private enum StoryPageSectionMarker: CaseIterable {
        case scene
        case sliceChoice
        case slicePrompt
        case sliceMechanic
        case sliceResult
        case progressChoice
        case progressPrompt
        case progressMechanic
        case progressResult
        case surpriseChoice
        case surprisePrompt
        case surpriseMechanic
        case surpriseResult

        var aliases: [String] {
            switch self {
            case .scene:
                ["SCENE", "Scene"]
            case .sliceChoice:
                ["SLICE_OF_LIFE_CHOICE", "Slice of Life Choice", "Slice of Life"]
            case .slicePrompt:
                ["SLICE_OF_LIFE_PROMPT", "Slice of Life Prompt"]
            case .sliceMechanic:
                ["SLICE_OF_LIFE_MECHANIC", "Slice of Life Mechanic"]
            case .sliceResult:
                ["SLICE_OF_LIFE_RESULT", "Slice of Life Result"]
            case .progressChoice:
                ["PROGRESS_ARC_CHOICE", "Progress Arc Choice", "Progress Arc"]
            case .progressPrompt:
                ["PROGRESS_ARC_PROMPT", "Progress Arc Prompt"]
            case .progressMechanic:
                ["PROGRESS_ARC_MECHANIC", "Progress Arc Mechanic"]
            case .progressResult:
                ["PROGRESS_ARC_RESULT", "Progress Arc Result"]
            case .surpriseChoice:
                ["SURPRISE_CHOICE", "Surprise Choice", "Something Surprising", "Surprise"]
            case .surprisePrompt:
                ["SURPRISE_PROMPT", "Surprise Prompt"]
            case .surpriseMechanic:
                ["SURPRISE_MECHANIC", "Surprise Mechanic"]
            case .surpriseResult:
                ["SURPRISE_RESULT", "Surprise Result"]
            }
        }
    }
}

private extension String {
    func singleLine(maxLength: Int) -> String? {
        let cleaned = components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= maxLength {
            return cleaned
        }
        let end = cleaned.index(cleaned.startIndex, offsetBy: maxLength)
        return String(cleaned[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    var withoutTrailingSentencePunctuation: String {
        trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
    }

    func removingImmediateDuplicateSentence() -> String {
        let separators = [". ", "! ", "? "]
        for separator in separators {
            let parts = components(separatedBy: separator)
            guard parts.count == 2 else { continue }
            let left = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let right = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if left.localizedCaseInsensitiveCompare(right) == .orderedSame {
                return left
            }
        }

        let words = split(separator: " ").map(String.init)
        guard words.count.isMultiple(of: 2), words.count >= 4 else { return self }
        let midpoint = words.count / 2
        let first = words[..<midpoint].joined(separator: " ")
        let second = words[midpoint...].joined(separator: " ")
        if first.localizedCaseInsensitiveCompare(second) == .orderedSame {
            return first
        }
        return self
    }
}

private extension SurfacePage {
    func withAcademyActivityReturn(activity: AcademyActivity, draft: StoryPageSceneDraft) -> SurfacePage {
        var metadata = payload.metadata
        let academyMetadata = draft.surface.payload.metadata
        metadata["storyMechanicReturn"] = "true"
        metadata["academyActivityReturn"] = "true"
        metadata["academyActivityID"] = activity.id
        metadata["academyActivityKind"] = activity.kind.rawValue
        metadata["academyActivityTitle"] = activity.title
        metadata["storyMechanicKind"] = "academy-activity"
        metadata["storySourceSurfaceID"] = draft.surface.id
        metadata["storyThread"] = academyMetadata["sessionName"] ?? draft.thread
        metadata["storyScene"] = draft.scene
        metadata["storyChoiceTitle"] = activity.title
        metadata["storyChoicePrompt"] = activity.invitation
        metadata["storyChoiceEffect"] = "The completed Academy practice changes what the room can teach next."
        for key in [
            "source", "sessionID", "sessionKind", "sessionName", "sessionLeader", "sessionLeaderEntityID",
            "sessionRoom", "sessionCompanions", "sessionTeaches", "sessionStyle", "sessionSubjectThreadID",
            "lessonModuleID", "lessonTitle", "lessonRealSubject", "lessonConcept", "lessonLectureBeats",
            "lessonDemonstration", "lessonInteractionPrompt", "lessonRealWorldPractice", "sessionBlock"
        ] {
            if let value = academyMetadata[key]?.nonEmpty {
                metadata["academyReturn_\(key)"] = value
            }
        }
        let tags = metadata["tags"]?.nonEmpty
            .map { "\($0),academy-activity,academy-activity:\(activity.id),story-mechanic,academy-activity" }
            ?? "academy-activity,academy-activity:\(activity.id),story-mechanic,academy-activity"
        metadata["tags"] = tags
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(headline: payload.headline, body: payload.body, metadata: metadata)
        )
    }

    func withStoryMechanicReturn(
        mechanic: StoryPageChoiceMechanic,
        storySurface: SurfacePage,
        draft: StoryPageSceneDraft,
        choice: StoryPageChoiceDraft
    ) -> SurfacePage {
        var metadata = payload.metadata
        metadata["storyMechanicReturn"] = "true"
        metadata["storyMechanicKind"] = mechanic.kind.rawValue
        metadata["storySourceSurfaceID"] = storySurface.id
        metadata["storyThread"] = draft.thread
        metadata["storyScene"] = draft.scene
        if let blueprint = draft.blueprint {
            metadata["storyRecipePackID"] = blueprint.recipePackID
            metadata["storyRecipeID"] = blueprint.recipeID
        }
        metadata["storyChoiceID"] = choice.id
        metadata["storyChoiceTitle"] = choice.title
        metadata["storyChoicePrompt"] = choice.prompt
        metadata["storyChoiceEffect"] = choice.effectLine
        if let enchantmentID = mechanic.enchantmentID {
            metadata["storyEnchantmentID"] = enchantmentID
            metadata["storyEnchantmentName"] = StoryEnchantmentCatalog.spell(id: enchantmentID)?.title
        }
        let mechanicTag = "story-mechanic:\(mechanic.kind.rawValue)"
        let tags = metadata["tags"]?.nonEmpty.map { "\($0),story-mechanic,\(mechanic.kind.rawValue),\(mechanicTag),choice:\(choice.id)" }
            ?? "story-mechanic,\(mechanic.kind.rawValue),\(mechanicTag),choice:\(choice.id)"
        metadata["tags"] = tags
        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: payload.body,
                metadata: metadata
            )
        )
    }

    func withCompassRunPlan(_ plan: [String: String], constraints: [String: String]) -> SurfacePage {
        var metadata = payload.metadata
        metadata["place"] = constraints["location"]
        metadata["placeContext"] = constraints["placeContext"]
        metadata["placeContextID"] = constraints["placeContextID"]
        if let nearbyPlaces = constraints["nearbyPlaces"]?.nonEmpty {
            metadata["nearbyPlaces"] = nearbyPlaces
        }
        for key in [
            "anchorName",
            "anchorKind",
            "anchorDistanceMeters",
            "anchorRoom",
            "anchorFae",
            "anchorLocalRule",
            "anchorVisitMode",
            "anchorMiniStory",
            "anchorAcademyEcho"
        ] {
            if let value = constraints[key]?.nonEmpty {
                metadata[key] = value
            } else {
                metadata.removeValue(forKey: key)
            }
        }
        metadata["timeBox"] = constraints["timeLimit"]
        metadata["energy"] = constraints["energy"]
        metadata["companions"] = constraints["companions"]
        metadata["budget"] = constraints["budget"]
        metadata["considerations"] = constraints["considerations"]
        metadata["spark"] = plan["spark"]
        metadata["destination"] = plan["destination"]
        metadata["delight"] = plan["delight"]
        metadata["definition"] = plan["definition"]
        metadata["mission"] = plan["mission"]
        metadata["souvenirPrompt"] = plan["souvenirPrompt"]
        metadata["restPrompt"] = plan["restPrompt"]
        metadata["hint"] = plan["hint"]
        metadata["selector"] = constraints["selector"] ?? "gemma-custom-run"
        metadata["runAuthoringMode"] = constraints["runAuthoringMode"] ?? "generated"
        metadata["compassMode"] = "runStart"
        metadata["compassRunPrepared"] = "true"
        metadata["privacy"] = "private local practice"

        let body = """
        Your custom Compass Run is ready.

        Keep this page to begin with North: Notice. The next Pages will guide you one direction at a time.
        """

        return SurfacePage(
            id: id,
            type: type,
            sourceID: sourceID,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: payload.headline,
                body: body,
                metadata: metadata
            )
        )
    }
}

struct StoryPageSceneDraft: Equatable {
    var surface: SurfacePage
    var thread: String
    var entities: [String]
    var storySettingID: String
    var storySettingName: String
    var storySettingDetail: String
    var signals: [String]
    var pressures: [String]
    var memories: [String]
    var chapterTalismanMoves: [String]
    var characterCanon: String
    var formName: String
    var formBeats: [String]
    var genreName: String
    var genreLens: String
    var genreExemplar: String
    var genrePalette: [String]
    var promiseSeed: String
    var promiseQuestion: String
    var turnCharacter: String
    var turnWant: String
    var turnObstacle: String
    var turnStatement: String
    var turnRegister: String
    var turnLandings: [String: String]
    var blueprint: StorySceneBlueprint?
    var preparedScene: String?
    var preparedChoices: [String: StoryPageChoiceText]
    var preparedResults: [String: String]
    var continuationContext: String?
    var mechanicMandate: StoryPageMechanicMandate

    var dramaticContract: StoryDramaticContract? { blueprint?.dramaticContract }

    init(surface: SurfacePage) {
        self.surface = surface
        let metadata = surface.payload.metadata
        mechanicMandate = StoryPageMechanicMandate.from(metadata: metadata)
        thread = metadata["storyThreadDisplayTitle"]?.nonEmpty
            ?? metadata["sessionSubjectThreadID"]?.nonEmpty
            ?? metadata["selectedThreads"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first ?? "Ordinary Magic"
        if surface.type == .academyClass {
            var academyEntities = [metadata["sessionLeader"]?.nonEmpty, metadata["sessionCompanions"]?.nonEmpty]
                .compactMap { $0 }
                .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                .filter { !$0.isEmpty }
            if academyEntities.isEmpty {
                academyEntities = ["The Book"]
            }
            entities = academyEntities
        } else {
            entities = metadata["selectedEntities"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? ["The Book"]
        }
        storySettingID = metadata["storySettingID"] ?? ""
        storySettingName = metadata["storySettingName"] ?? ""
        storySettingDetail = metadata["storySettingDetail"] ?? ""
        signals = metadata["realSignals"]?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        pressures = metadata["relationshipPressures"]?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        memories = metadata["entityMemories"]?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        chapterTalismanMoves = metadata["chapterTalismanMoves"]?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        characterCanon = metadata[CharacterCanonPacket.metadataKey] ?? ""
        formName = metadata["storyFormName"] ?? ""
        formBeats = StoryVignetteBeats.snackSized(metadata["storyBeats"]?
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? [])
        genreName = metadata["storyGenreName"] ?? ""
        genreLens = metadata["storyGenreLens"] ?? ""
        genreExemplar = metadata["storyGenreExemplar"] ?? ""
        genrePalette = metadata["storyGenrePalette"]?
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        promiseSeed = metadata["storyPromiseSeed"] ?? ""
        promiseQuestion = metadata["storyPromiseQuestion"] ?? ""
        turnCharacter = metadata["storyTurnCharacter"] ?? ""
        turnWant = metadata["storyTurnWant"] ?? ""
        turnObstacle = metadata["storyTurnObstacle"] ?? ""
        turnStatement = metadata["storyTurnStatement"] ?? ""
        turnRegister = metadata["storyTurnRegister"] ?? ""
        turnLandings = [
            "slice-of-life": metadata["storyTurnLandingSliceOfLife"] ?? "",
            "progress-arc": metadata["storyTurnLandingProgressArc"] ?? "",
            "surprise": metadata["storyTurnLandingSurprise"] ?? ""
        ]
        if let recipeID = metadata["storyRecipeID"]?.nonEmpty,
           let modeRaw = metadata["storyRecipeSceneMode"],
           let mode = StoryRecipeSceneMode(rawValue: modeRaw),
           let groundingText = metadata["storyRecipeGrounding"]?.nonEmpty {
            let groundingKind = StoryGroundingKind(rawValue: metadata["storyRecipeGroundingKind"] ?? "") ?? .realSignal
            let resolvedTurn = StoryTurn(
                kind: StoryTurnKind(rawValue: metadata["storyTurnKind"] ?? "") ?? .smallDecision,
                character: turnCharacter, want: turnWant, obstacle: turnObstacle,
                statement: turnStatement, register: StoryRegister(rawValue: turnRegister) ?? .quiet,
                landings: turnLandings
            )
            let dramaticContract = metadata[StoryDramaticContract.metadataKey]
                .flatMap(StoryDramaticContract.init(encodedMetadata:))
            blueprint = StorySceneBlueprint(
                recipeID: recipeID,
                recipeName: metadata["storyRecipeName"] ?? recipeID,
                recipePackID: metadata["storyRecipePackID"] ?? "",
                sceneMode: mode,
                leadID: metadata["storyRecipeLeadID"] ?? "",
                leadName: metadata["storyRecipeLeadName"] ?? turnCharacter,
                companionID: metadata["storyRecipeCompanionID"]?.nonEmpty,
                companionName: metadata["storyRecipeCompanionName"]?.nonEmpty,
                premise: metadata["storyRecipePremise"] ?? "",
                grounding: StoryGrounding(kind: groundingKind, sourceID: metadata["storyRecipeGroundingSourceID"] ?? "", text: groundingText),
                beats: StoryVignetteBeats.snackSized(metadata["storyRecipeBeats"]?.split(separator: "\n").map(String.init) ?? []),
                groundingDirective: metadata["storyRecipeGroundingDirective"] ?? "",
                toneDirective: metadata["storyRecipeToneDirective"] ?? "",
                choiceDirective: metadata["storyRecipeChoiceDirective"] ?? "",
                continuationDirective: metadata["storyRecipeContinuationDirective"] ?? "",
                turn: resolvedTurn,
                dramaticContract: dramaticContract
            )
        } else {
            blueprint = nil
        }
        preparedScene = metadata["storyScene"].map(StoryPageProseParser.cleanSceneText)?.nonEmpty
        var choicesByID: [String: StoryPageChoiceText] = [:]
        let sliceChoice = StoryPageChoiceText(
            title: metadata["storyChoiceSliceOfLifeTitle"] ?? "",
            prompt: metadata["storyChoiceSliceOfLifePrompt"] ?? "",
            effectLine: metadata["storyChoiceSliceOfLifeEffect"] ?? "",
            mechanic: StoryPageChoiceMechanic.parse(
                metadata["storyChoiceSliceOfLifeMechanic"],
                enchantmentID: metadata["storyChoiceSliceOfLifeEnchantmentID"]
            )
        )
        let arcChoice = StoryPageChoiceText(
            title: metadata["storyChoiceProgressArcTitle"] ?? "",
            prompt: metadata["storyChoiceProgressArcPrompt"] ?? "",
            effectLine: metadata["storyChoiceProgressArcEffect"] ?? "",
            mechanic: StoryPageChoiceMechanic.parse(
                metadata["storyChoiceProgressArcMechanic"],
                enchantmentID: metadata["storyChoiceProgressArcEnchantmentID"]
            )
        )
        let surpriseChoice = StoryPageChoiceText(
            title: metadata["storyChoiceSurpriseTitle"] ?? "",
            prompt: metadata["storyChoiceSurprisePrompt"] ?? "",
            effectLine: metadata["storyChoiceSurpriseEffect"] ?? "",
            mechanic: StoryPageChoiceMechanic.parse(
                metadata["storyChoiceSurpriseMechanic"],
                enchantmentID: metadata["storyChoiceSurpriseEnchantmentID"]
            )
        )
        if !sliceChoice.isEmpty {
            choicesByID["sliceoflife"] = sliceChoice
        }
        if !arcChoice.isEmpty {
            choicesByID["progressarc"] = arcChoice
        }
        if !surpriseChoice.isEmpty {
            choicesByID["surprise"] = surpriseChoice
        }
        preparedChoices = choicesByID
        preparedResults = [
            "sliceoflife": metadata["storyResultSliceOfLife"] ?? "",
            "progressarc": metadata["storyResultProgressArc"] ?? "",
            "surprise": metadata["storyResultSurprise"] ?? ""
        ].compactMapValues(\.nonEmpty)
        continuationContext = metadata["storyContinuationContext"]?.nonEmpty
    }

    /// A stable per-page slice of the genre palette, so quiet days get
    /// concrete props without every page of a genre reusing the same ones.
    func rotatedGenrePalette(count: Int) -> [String] {
        guard !genrePalette.isEmpty else { return [] }
        let seed = surface.id.unicodeScalars.reduce(UInt32(2_166_136_261)) { hash, scalar in
            (hash ^ scalar.value) &* 16_777_619
        }
        let start = Int(seed % UInt32(genrePalette.count))
        let rotated = Array(genrePalette[start...] + genrePalette[..<start])
        return Array(rotated.prefix(max(count, 1)))
    }

    var scene: String {
        if let preparedScene {
            return preparedScene
        }
        if surface.type == .academyClass {
            return academyFallbackScene
        }
        if let blueprint {
            let companion = blueprint.companionName.map { " with \($0)" } ?? ""
            return """
            \(blueprint.leadName) enters the scene\(companion) because \(blueprint.premise.lowercased())

            The exact evidence is this: \(blueprint.grounding.text) \(blueprint.beats.first ?? "Something specific changes.")

            \(blueprint.turn.statement)
            """
        }
        let entity = entities.first ?? "The Book"
        let signalLine = signals.prefix(2).joined(separator: " ")
        let pressureLine = pressures.first ?? "The margins have found enough weight to turn."
        return """
        \(entity) stands near the edge of \(thread), not as an assignment, but as a door left slightly open.

        \(signalLine.isEmpty ? "The day has offered a few small pieces of evidence." : signalLine)

        \(pressureLine) The Book does not ask the reader to leave real life. It asks which part of real life is ready to become story.
        """
    }

    private var academyFallbackScene: String {
        let metadata = surface.payload.metadata
        let leader = metadata["sessionLeader"]?.nonEmpty ?? "The professor"
        let sessionName = metadata["sessionName"]?.nonEmpty ?? "the class"
        let room = metadata["sessionRoom"]?.nonEmpty ?? "the classroom"
        let style = metadata["sessionStyle"]?.nonEmpty ?? "careful and alive"
        let title = metadata["lessonTitle"]?.nonEmpty ?? sessionName
        let concept = metadata["lessonConcept"]?.nonEmpty
            ?? metadata["sessionTeaches"]?.nonEmpty
            ?? "A useful practice becomes real when it is demonstrated, tried, and carried back into ordinary life."
        let beats = (metadata["lessonLectureBeats"]?.nonEmpty ?? metadata["sessionTeaches"] ?? "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let firstBeat = beats.first ?? concept
        let secondBeat = beats.dropFirst().first ?? "The lesson works best when the reader keeps it small enough to finish."
        let demonstration = metadata["lessonDemonstration"]?.nonEmpty
            ?? "\(leader) gives one quick example, then asks the room to test the idea aloud."
        let interaction = metadata["lessonInteractionPrompt"]?.nonEmpty
            ?? "What part of this lesson could you try without making the day heavier?"
        let practice = metadata["lessonRealWorldPractice"]?.nonEmpty
            ?? "Carry one small version of the lesson into the real world later, then keep one exact sentence from it."
        let companion = metadata["sessionCompanions"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "one student"

        if let debrief = AcademyActivityDebrief(metadata: metadata) {
            let firstDetail = debrief.outcome
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? debrief.outcome
            return """
            The returned page is already open in \(room). Under “\(debrief.activityTitle),” it carries your answer exactly as you left it:

            \(debrief.outcome)

            \(leader) does not begin \(sessionName) again. “I heard this: \(firstDetail),” they say. “Now the lesson has something real to answer.” They apply \(concept.lowercased()) to that detail, making the distinction smaller and more exact instead of repeating the demonstration. \(companion) looks back at their own answer and changes one word.

            “Keep the part of your answer that only you could have supplied,” \(leader) says. “What does that exact detail let you notice next?” The room waits at this new place in the lesson; the old assignment is not given again.
            """
        }

        return """
        The door to \(room) is already open, and \(sessionName) is underway. Chalk dust smells faintly mineral. A chair leg ticks against the floor while the light leans across the desks. \(leader) taps the board and says, "\(title) begins here: \(concept)"

        In a \(style) voice, \(leader) makes the lesson plain. "\(firstBeat)" A pause lets the sentence settle. "\(secondBeat)" The point is not to admire the idea from a distance. The point is to make it small enough to test while the day is still ordinary.

        \(demonstration) \(companion) answers first, a little too fast, and has to revise in front of everyone. "Try that again with a smaller claim," \(leader) says. That is useful. The lesson becomes less decorative and more usable.

        \(leader) turns toward you. "\(interaction)" The question waits without hurry. For later, the practice is simple: \(practice) Nothing has to be completed inside this page. The class only asks you to leave with a better-shaped beginning.
        """
    }

    private var defaultChoices: [StoryPageChoiceDraft] {
        if surface.type == .academyClass {
            return [
                StoryPageChoiceDraft(
                    id: "sliceoflife",
                    title: "Study the Detail",
                    prompt: "Stay with one ordinary thing the lesson made visible.",
                    effectLine: "A classroom detail gains weight without forcing the lesson forward.",
                    symbolName: "leaf",
                    tint: BookPalette.violet
                ),
                StoryPageChoiceDraft(
                    id: "progressarc",
                    title: "Try the Lesson",
                    prompt: "Answer the professor and attempt the exercise.",
                    effectLine: "\(thread) advances through practice, not summary.",
                    symbolName: "graduationcap",
                    tint: BookPalette.teal
                ),
                StoryPageChoiceDraft(
                    id: "surprise",
                    title: "Open a Side Door",
                    prompt: "Follow the strange implication without leaving the classroom.",
                    effectLine: "The subject reveals a sideways application that can return later.",
                    symbolName: "sparkles",
                    tint: BookPalette.gold
                )
            ]
        }
        return [
            StoryPageChoiceDraft(
                id: "sliceoflife",
                title: "Ask the Small Thing",
                prompt: "Ask \(storyActor) about one exact detail in the room.",
                effectLine: turnLandings["slice-of-life"]?.nonEmpty ?? "\(storyActor) reveals one small truth in ordinary conversation.",
                symbolName: "leaf",
                tint: BookPalette.violet
            ),
            StoryPageChoiceDraft(
                id: "progressarc",
                title: "Make the Move",
                prompt: "Let \(storyActor) choose the next visible action.",
                effectLine: turnLandings["progress-arc"]?.nonEmpty ?? "\(storyActor) advances \(thread) through a visible decision.",
                symbolName: "point.3.connected.trianglepath.dotted",
                tint: BookPalette.teal
            ),
            StoryPageChoiceDraft(
                id: "surprise",
                title: "Name the Wrongness",
                prompt: "Ask which part of this scene is pretending to be ordinary.",
                effectLine: turnLandings["surprise"]?.nonEmpty ?? "\(storyActor)'s want slips sideways and changes the scene.",
                symbolName: "sparkles",
                tint: BookPalette.gold
            )
        ]
    }

    private var storyActor: String {
        turnCharacter.nonEmpty ?? entities.first ?? "The Book"
    }

    private var storyActorShort: String {
        let actor = storyActor
            .replacingOccurrences(of: "Dr. ", with: "")
            .replacingOccurrences(of: "Professor ", with: "")
            .replacingOccurrences(of: "Headmistress ", with: "")
        return actor.split(separator: " ").last.map(String.init) ?? actor
    }

    var choices: [StoryPageChoiceDraft] {
        defaultChoices.map { choice in
            guard let prepared = preparedChoices[choice.id] else {
                return choice
            }
            return StoryPageChoiceDraft(
                id: choice.id,
                title: prepared.title.nonEmpty ?? choice.title,
                prompt: prepared.prompt.nonEmpty ?? choice.prompt,
                effectLine: prepared.effectLine.nonEmpty ?? prepared.prompt.nonEmpty ?? choice.effectLine,
                symbolName: choice.symbolName,
                tint: choice.tint,
                mechanic: prepared.mechanic
            )
        }
    }

    func result(for choice: StoryPageChoiceDraft) -> String {
        if let prepared = preparedResults[choice.id] {
            return prepared
        }
        let entity = entities.first ?? "The Book"
        return "\(choice.effectLine) \(entity) keeps the page warm, and the story field changes quietly underneath."
    }
}
