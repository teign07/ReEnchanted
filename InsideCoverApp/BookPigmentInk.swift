import SwiftUI
import UIKit
import PencilKit
import Accelerate
#if canImport(InsideCoverCore)
import InsideCoverCore
#endif

/// The same bounded GPU phase renders native SwiftUI marks and temporary
/// UIKit snapshots. No renderer or clock remains on settled reading views.
struct BookInkMaterialPhase: AnimatableModifier {
    var progress: Double
    let isSinking: Bool
    private let isPicture: Bool
    private let phaseSeed: Float
    private let regionDelaySpan: Float
    private let regionDuration: Float
    private let objectDelay: Float
    private let clockImage: Image

    init(progress: Double, seed: String, isSinking: Bool, style: BookInkStyle = .writing, sentenceClock: UIImage? = nil) {
        self.progress = progress
        self.isSinking = isSinking
        isPicture = style == .picture
        // These values belong to the mark, not the animation frame. Keep the
        // deterministic hashing and image wrapper outside animatable body work.
        phaseSeed = Float(BookInkTiming.variation(seed) * 97)
        regionDelaySpan = Float(sentenceClock == nil ? 0 : BookInkTiming.regionalDelaySpan / BookInkTiming.arrivalDuration)
        regionDuration = Float((sentenceClock == nil ? BookInkTiming.emergenceDuration(seed) : BookInkTiming.regionalPhaseDuration) / BookInkTiming.arrivalDuration)
        objectDelay = Float(sentenceClock == nil ? BookInkTiming.emergenceDelay(seed) / BookInkTiming.arrivalDuration : 0)
        clockImage = Image(uiImage: sentenceClock ?? Self.emptyClock)
    }

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let emptyClock: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    func body(content: Content) -> some View {
        // Transparent breathing room lets pigment bloom outside a serif or
        // feather without changing the line measure or moving its neighbours.
        content
            .padding(12)
            .layerEffect(
                ShaderLibrary.bookPigment(
                    .boundingRect,
                    .float(min(1, max(0, progress))),
                    .float(isSinking ? 1.0 : 0.0),
                    .float(phaseSeed),
                    .float(regionDelaySpan),
                    .float(regionDuration),
                    .float(objectDelay),
                    .float(isPicture ? 1.0 : 0.0),
                    .image(clockImage)
                ),
                maxSampleOffset: CGSize(width: 24, height: 24),
                isEnabled: progress > 0 && progress < 1
            )
            .opacity(isSinking ? (progress >= 1 ? 0 : 1) : (progress <= 0 ? 0 : 1))
            .padding(-12)
    }
}

/// A snapshot's finite clock catches up after a view is recreated. Its image
/// and timing map are released when the UIKit owner restores the live view.
private struct BookPigmentSnapshot: View {
    let image: UIImage
    let clock: UIImage?
    let size: CGSize
    let startedAt: Date
    let duration: Double
    let seed: String
    let isSinking: Bool
    @State private var progress: Double = 0

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .modifier(BookInkMaterialPhase(progress: progress, seed: seed, isSinking: isSinking, sentenceClock: clock))
            .task(id: startedAt) {
                // Use the same display-driven interpolation as live ink. A
                // separate 30 Hz timeline rebuilt the image subtree each tick
                // and could miss the display's intervening frames.
                let elapsed = Date().timeIntervalSince(startedAt)
                let caughtUp = min(1, max(0, elapsed / duration))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { progress = caughtUp }
                guard !Task.isCancelled, caughtUp < 1 else { return }
                withAnimation(.linear(duration: duration * (1 - caughtUp))) {
                    progress = 1
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// UILabel draws the exact attributed text into this one temporary image.
/// The host is a transparent sibling of its glyph drawing, never a mask on
/// the original text. Sentences have independent, overlapping pigment clocks.
@MainActor
final class BookLabelPigment {
    private var host: UIHostingController<AnyView>?
    private var finishTask: Task<Void, Never>?
    private var mapTask: Task<Void, Never>?

    func remove() {
        mapTask?.cancel()
        mapTask = nil
        finishTask?.cancel()
        finishTask = nil
        host?.view.removeFromSuperview()
        host = nil
    }

    func install(on label: UILabel, arrival: Date, seed: String, draw: (CGRect) -> Void, finish: @escaping () -> Void) -> Bool {
        remove()
        let elapsed = Date().timeIntervalSince(arrival)
        guard elapsed < BookInkTiming.arrivalDuration,
              label.bounds.width > 0, label.bounds.height > 0,
              let attributed = label.attributedText?.copy() as? NSAttributedString, attributed.length > 0 else { return false }
        let seed = BookInkTiming.arrivalSeed(seed, arrival: arrival)
        // At most two million pixels per text box; reading precision returns
        // to the native label, independent of this temporary texture budget.
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = min(2, sqrt(2_000_000 / max(1, label.bounds.width * label.bounds.height)))
        let size = label.bounds.size
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(label.bounds) }
        let textRect = label.textRect(forBounds: label.bounds, limitedToNumberOfLines: 0)
        let lineBreakMode = label.lineBreakMode
        // The timing maps take tens of milliseconds of layout, glyph drawing
        // and blurring; the leaf is turning, so they are built off the main
        // thread. The label is already blank and the shader catches up to the
        // arrival clock, so a late host loses only the first faint frames.
        mapTask = Task { @MainActor [weak self, weak label] in
            let clock = await Task.detached(priority: .userInitiated) {
                Self.sentenceMap(attributed: attributed, size: size, textRect: textRect,
                                 lineBreakMode: lineBreakMode, seed: seed, ink: image)
            }.value
            guard let self, let label, !Task.isCancelled else { return }
            let view = BookPigmentSnapshot(image: image, clock: clock, size: size, startedAt: arrival,
                                          duration: BookInkTiming.arrivalDuration, seed: seed, isSinking: false)
            let host = UIHostingController(rootView: AnyView(view))
            host.view.backgroundColor = .clear
            host.view.isOpaque = false
            host.view.isUserInteractionEnabled = false
            host.view.accessibilityElementsHidden = true
            host.view.frame = label.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            label.addSubview(host.view)
            self.host = host
        }
        finishTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(max(0, BookInkTiming.arrivalDuration - elapsed))) }
            catch { return }
            guard let self else { return }
            self.remove()
            finish()
        }
        return true
    }

    /// The label's own ink, blurred once on arrival, is the puddle's surface:
    /// thresholding it lets neighbouring letters run together as liquid. A ring
    /// of shader taps at puddle width drew a dozen copies of each glyph instead.
    /// Coverage goes to the green channel only, beside the red order ramp.
    nonisolated private static func puddleField(_ ink: UIImage, size: CGSize, margin: CGFloat) -> UIImage? {
        guard let cgImage = ink.cgImage else { return nil }
        let width = Int(ceil(size.width + margin * 2)), height = Int(ceil(size.height + margin * 2))
        var coverage = [UInt8](repeating: 0, count: width * height)
        var blurred = coverage
        let drawn = coverage.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: margin, y: CGFloat(height) - margin - size.height,
                                             width: size.width, height: size.height))
            return true
        }
        guard drawn else { return nil }
        // A 13-point tent at 1x spreads like a Gaussian of about 2.6pt.
        let error = coverage.withUnsafeMutableBytes { source in
            blurred.withUnsafeMutableBytes { destination in
                var src = vImage_Buffer(data: source.baseAddress, height: vImagePixelCount(height),
                                        width: vImagePixelCount(width), rowBytes: width)
                var dst = vImage_Buffer(data: destination.baseAddress, height: vImagePixelCount(height),
                                        width: vImagePixelCount(width), rowBytes: width)
                return vImageTentConvolve_Planar8(&src, &dst, nil, 0, 0, 13, 13, 0, vImage_Flags(kvImageBackgroundColorFill))
            }
        }
        guard error == kvImageNoError else { return nil }
        var green = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) { green[index * 4 + 1] = blurred[index] }
        guard let provider = CGDataProvider(data: Data(green) as CFData),
              let field = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: field)
    }

    nonisolated private static func sentenceMap(attributed: NSAttributedString, size: CGSize, textRect: CGRect,
                                                lineBreakMode: NSLineBreakMode, seed: String, ink: UIImage) -> UIImage {
        let storage = NSTextStorage(attributedString: attributed)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: size.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = lineBreakMode
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        // UILabel centres its text in a taller box; the map must follow it.
        let yOffset = textRect.minY + max(0, (size.height - textRect.height) / 2) - layout.usedRect(for: container).minY
        var ranges: [NSRange] = []
        attributed.string.enumerateSubstrings(in: attributed.string.startIndex..<attributed.string.endIndex,
                                             options: [.bySentences, .substringNotRequired]) { _, _, enclosing, _ in
            ranges.append(NSRange(enclosing, in: attributed.string))
        }
        if ranges.isEmpty { ranges = [NSRange(location: 0, length: attributed.length)] }
        // Both maps span the shader's padded layer, including the transparent
        // 12pt margin a puddle may spill into. Start bands fill the top half.
        // In the bottom half each sentence's reading order runs as a red ramp
        // along its own lines, so its ink writes from its first letter
        // to its last, and the puddle field shares those pixels in green. The
        // two grey rows at the foot let the shader undo whatever colour
        // conversion the ramp meets.
        let margin: CGFloat = 12
        let width = size.width + margin * 2
        let height = ceil(size.height) + margin * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func grey(_ value: CGFloat) -> CGColor { CGColor(colorSpace: space, components: [value, value, value, 1])! }
        func red(_ value: CGFloat) -> CGColor { CGColor(colorSpace: space, components: [value, 0, 0, 1])! }
        let field = Self.puddleField(ink, size: size, margin: margin)
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height * 2 + 2), format: format).image { context in
            let cg = context.cgContext
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height * 2 + 2))
            cg.setFillColor(grey(0.5))
            cg.fill(CGRect(x: 0, y: height * 2, width: width, height: 2))
            // Line boxes tile the paper between and around the words. They
            // nearly touch the glyphs, so the glyphs themselves are drawn over
            // them, thickened a little, carrying their own line's clock: an
            // ascender or descender reaching into a neighbouring box keeps its
            // own timing instead of firing early as a stray mark.
            var boxes: [(rect: CGRect, glyphs: NSRange, clock: UIColor, start: CGFloat, end: CGFloat)] = []
            for (index, range) in ranges.enumerated() {
                let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var lines: [(rect: CGRect, glyphs: NSRange)] = []
                layout.enumerateLineFragments(forGlyphRange: glyphs) { _, _, _, lineGlyphs, _ in
                    let part = NSIntersectionRange(lineGlyphs, glyphs)
                    let rect = layout.boundingRect(forGlyphRange: part, in: container)
                    if part.length > 0, rect.width > 0 {
                        lines.append((rect.offsetBy(dx: margin, dy: yOffset + margin), part))
                    }
                }
                let length = max(1, lines.reduce(0) { $0 + $1.rect.width })
                var written: CGFloat = 0
                for line in lines {
                    let start = 0.1 + 0.9 * written / length
                    written += line.rect.width
                    boxes.append((line.rect, line.glyphs, BookInkTiming.clockColor(seed, index: index),
                                  start, 0.1 + 0.9 * written / length))
                }
            }
            for box in boxes {
                let area = box.rect.insetBy(dx: -2, dy: 0)
                box.clock.setFill()
                context.fill(area)
                guard let ramp = CGGradient(colorsSpace: space, colors: [red(box.start), red(box.end)] as CFArray,
                                            locations: [0, 1]) else { continue }
                cg.saveGState()
                cg.clip(to: area.offsetBy(dx: 0, dy: height))
                cg.drawLinearGradient(ramp, start: CGPoint(x: box.rect.minX, y: 0), end: CGPoint(x: box.rect.maxX, y: 0),
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                cg.restoreGState()
            }
            let everything = NSRange(location: 0, length: storage.length)
            let allGlyphs = layout.glyphRange(for: container)
            let origin = CGPoint(x: margin, y: yOffset + margin)
            storage.removeAttribute(.shadow, range: everything)
            storage.addAttribute(.strokeWidth, value: -8, range: everything)
            for box in boxes {
                let characters = layout.characterRange(forGlyphRange: box.glyphs, actualGlyphRange: nil)
                storage.addAttribute(.foregroundColor, value: box.clock, range: characters)
            }
            layout.drawGlyphs(forGlyphRange: allGlyphs, at: origin)
            for box in boxes {
                var glyph = box.glyphs.location
                while glyph < NSMaxRange(box.glyphs) {
                    let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                    let x = line.minX + layout.location(forGlyphAt: glyph).x + margin
                    let along = min(1, max(0, (x - box.rect.minX) / box.rect.width))
                    let characters = layout.characterRange(forGlyphRange: NSRange(location: glyph, length: 1), actualGlyphRange: nil)
                    storage.addAttribute(.foregroundColor,
                                         value: UIColor(red: box.start + (box.end - box.start) * along, green: 0, blue: 0, alpha: 1),
                                         range: characters)
                    glyph += 1
                }
            }
            layout.drawGlyphs(forGlyphRange: allGlyphs, at: CGPoint(x: origin.x, y: origin.y + height))
            field?.draw(in: CGRect(x: 0, y: height, width: width, height: height), blendMode: .plusLighter, alpha: 1)
        }
    }
}

extension View {
    /// SwiftUI's TextEditor and PencilKit are UIKit surfaces. Their transparent
    /// snapshot feeds the same pigment shader without filtering paper/controls.
    func bookUIKitInkAbsorption(isActive: Bool, seed: String, startedAt: Date? = nil) -> some View {
        modifier(BookUIKitInkAbsorption(isActive: isActive, seed: seed, startedAt: startedAt))
    }
}

private struct BookUIKitInkAbsorption: ViewModifier {
    let isActive: Bool
    let seed: String
    let startedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var capture: BookInkCapture?
    @State private var localStart = Date()
    @State private var inkHasSunk = false

    func body(content: Content) -> some View {
        content
            .background {
                BookInkCaptureProbe(isActive: isActive && !reduceMotion && !voiceOver) {
                    if !inkHasSunk { capture = $0 }
                }
            }
            .opacity(isActive && (capture != nil || inkHasSunk || reduceMotion || voiceOver) ? 0 : 1)
            .overlay(alignment: .topLeading) {
                if isActive, !reduceMotion, !voiceOver, let capture {
                    BookPigmentSnapshot(image: capture.image, clock: nil, size: capture.rect.size,
                                        startedAt: startedAt ?? localStart, duration: BookInkTiming.absorptionDuration,
                                        seed: seed, isSinking: true)
                        .offset(x: capture.rect.minX, y: capture.rect.minY)
                }
            }
            .onChange(of: isActive, initial: true) { _, active in
                if active { localStart = startedAt ?? Date() }
                else { capture = nil; inkHasSunk = false }
            }
            .task(id: isActive) {
                guard isActive else { return }
                let remaining = BookInkTiming.absorptionDuration - Date().timeIntervalSince(startedAt ?? localStart)
                if remaining > 0 {
                    do { try await Task.sleep(for: .seconds(remaining)) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                inkHasSunk = true
                capture = nil
            }
    }
}

private struct BookInkCapture {
    let image: UIImage
    let rect: CGRect
}

/// A background probe searches only its enclosing control. It takes one
/// snapshot after focus/dictation has stopped, never while the reader types.
private struct BookInkCaptureProbe: UIViewRepresentable {
    let isActive: Bool
    let onCapture: (BookInkCapture?) -> Void

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.onCapture = onCapture
        view.setActive(isActive)
    }
    static func dismantleUIView(_ uiView: Probe, coordinator: ()) { uiView.cancel() }

    final class Probe: UIView {
        var onCapture: ((BookInkCapture?) -> Void)?
        private var active = false
        private var captured = false
        private var pending: Task<Void, Never>?

        func setActive(_ value: Bool) {
            guard active != value else { return }
            active = value
            captured = false
            cancel()
            if value { schedule() }
        }
        func cancel() { pending?.cancel(); pending = nil }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { cancel() }
            else if active && !captured { schedule() }
        }
        private func schedule() {
            cancel()
            pending = Task { @MainActor [weak self] in
                // One frame lets FocusState and voice shutdown reach UIKit.
                do { try await Task.sleep(for: .milliseconds(20)) }
                catch { return }
                guard let self, self.active, !self.captured, self.window != nil else { return }
                guard let control = self.enclosingInkControl(), control.bounds.width > 1, control.bounds.height > 1 else { return }
                let rect = control.convert(control.bounds, to: self)
                let format = UIGraphicsImageRendererFormat()
                format.opaque = false
                format.scale = min(2, sqrt(2_000_000 / max(1, rect.width * rect.height)))
                let background = control.backgroundColor
                let tint = control.tintColor
                let opaque = control.isOpaque
                control.backgroundColor = .clear
                control.tintColor = .clear
                control.isOpaque = false
                defer {
                    control.backgroundColor = background
                    control.tintColor = tint
                    control.isOpaque = opaque
                }
                let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
                    if let canvas = control as? PKCanvasView {
                        // PencilKit's Metal surface cannot be layer-rendered.
                        // Its own drawing export supplies the actual strokes,
                        // sampled at the same visible zoom and scroll position.
                        let zoom = max(0.01, canvas.zoomScale)
                        let visible = CGRect(x: canvas.contentOffset.x / zoom,
                                             y: canvas.contentOffset.y / zoom,
                                             width: canvas.bounds.width / zoom,
                                             height: canvas.bounds.height / zoom)
                        canvas.drawing.image(from: visible, scale: format.scale * zoom)
                            .draw(in: CGRect(origin: .zero, size: rect.size))
                    } else {
                        // The editor's actual viewport supplies its typography,
                        // selection-free ink and scroll offset without reflow.
                        context.cgContext.translateBy(x: -control.bounds.minX, y: -control.bounds.minY)
                        control.layer.render(in: context.cgContext)
                    }
                }
                self.captured = true
                self.onCapture?(BookInkCapture(image: image, rect: rect))
            }
        }
        private func enclosingInkControl() -> UIView? {
            func find(_ view: UIView, depth: Int) -> UIView? {
                if view is UITextView || view is PKCanvasView { return view }
                guard depth > 0 else { return nil }
                for child in view.subviews where child !== self {
                    if let match = find(child, depth: depth - 1) { return match }
                }
                return nil
            }
            var parent = superview
            for _ in 0..<4 {
                guard let current = parent else { break }
                if let match = find(current, depth: 7) { return match }
                parent = current.superview
            }
            return nil
        }
    }
}

#if DEBUG
/// A single tuning leaf using the production label, editor, illustration and
/// illuminated photo seams. It never writes a Keep or changes a reader's Book.
struct BookPigmentProofLeaf: View {
    @State private var arrival = Date()
    @State private var words = "I found a feather beside the gate."
    @State private var sinking = false
    private let photo = IlluminatedPageComposer.compose(analysis: .academyFallback, sourceAssetName: "IlluminatedSamplePhoto01", seed: 29)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("The ink is finding its feet.")
                    .font(.system(.title2, design: .serif))
                    .bookInkEmergence(seed: "proof-title")
                ProofProse(arrival: arrival)
                    .frame(height: 116)
                HStack {
                    Image("IlluminationScrapS01_15").resizable().scaledToFit()
                        .frame(width: 100, height: 150)
                        .bookInkEmergence(seed: "proof-illustration", style: .picture)
                    IlluminatedArtifactPreview(draft: photo)
                        .frame(height: 220)
                }
                Text("The gate tried to keep it.")
                    .font(BookHand.book.font(16))
                    .foregroundStyle(BookPalette.violet)
                    .bookInkEmergence(seed: "proof-handwriting")
                LivingTextEditor(title: "Your words", placeholder: "Leave a real thing here.", text: $words,
                                 minHeight: 110, isAbsorbingInk: sinking)
                HStack {
                    Button("Replay arrival") { arrival = Date() }
                    Spacer()
                    Button("Sink these words") { sinking = true }
                        .disabled(sinking || words.isEmpty)
                }
                .font(.system(.footnote, design: .serif))
            }
            .padding(28)
        }
        .background(BookPalette.page)
        .foregroundStyle(BookPalette.ink)
        .environment(\.bookLeafInkEnabled, true)
        .environment(\.bookLeafInkArrival, arrival)
        .task(id: sinking) {
            guard sinking else { return }
            do { try await Task.sleep(for: .seconds(BookInkTiming.absorptionDuration)) }
            catch { return }
            words = ""
            sinking = false
        }
    }

    private struct ProofProse: UIViewRepresentable {
        let arrival: Date
        func makeUIView(context: Context) -> FolioWrappingLabel {
            let label = FolioWrappingLabel()
            label.numberOfLines = 0
            label.backgroundColor = .clear
            return label
        }
        func updateUIView(_ label: FolioWrappingLabel, context: Context) {
            label.folioWidth = 290
            label.attributedText = NSAttributedString(
                string: "The hedge brought me a feather. It was still warm. I asked what had happened to the bird, but the hedge only shook its leaves.",
                attributes: [.font: UIFont(name: "Georgia", size: 17) ?? UIFont.systemFont(ofSize: 17),
                             .foregroundColor: UIColor(BookPalette.ink)]
            )
            label.revealsInk = true
            label.inkArrival = arrival
            label.inkSeed = "proof-prose"
            label.setNeedsLayout()
        }
    }
}

#Preview("Pigment tuning leaf") { BookPigmentProofLeaf() }
#endif
