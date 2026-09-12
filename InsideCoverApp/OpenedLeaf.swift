import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - The opened leaf
//
// A Page the reader has opened is a leaf lifted out of the Book, not a panel
// laid over it. Everything in this file exists so that the opened Page is made
// of the same matter as the leaves behind it: the same five paper stocks, the
// same seeded foxing and water rings, the same wandering cut edge.
//
// The folio has its own copies of these ideas (`FolioLeafPatina`,
// `FolioWornLeafShape`), shaped for a fixed-size bound leaf that is paginated
// in advance. A lifted leaf is a different object: it is as tall as the sheet
// that holds it, its content is measured at render time rather than paginated,
// and it has no spine. These are deliberately separate implementations of a
// shared idea rather than one contorted to serve both.

// MARK: Cut edge

/// The cut edge of a leaf that was torn or trimmed by hand.
///
/// The wander is smooth noise, not white noise. Sampling an independent random
/// number at each step — which is what `DeckledPaperScrapShape` does, correctly,
/// for a scrap a few dozen points wide — puts a full swing between every pair of
/// neighbours. Over the length of a phone screen that stops reading as fibre and
/// starts reading as saw teeth. So each edge is a slow drift between control
/// points a good inch apart, with a small fast component riding on top: the
/// coarse one is where the sheet was pulled from the mould, the fine one is the
/// fibre standing off the cut.
struct OpenedLeafEdgeShape: Shape {
    var seed: Int
    /// Peak deviation from a straight edge, in points.
    var amplitude: CGFloat = 1.7
    /// Distance between control points of the slow drift.
    var coarseWavelength: CGFloat = 62
    /// Distance between control points of the fibre riding on it.
    var fineWavelength: CGFloat = 17
    /// Distance between plotted points. Small enough that the interpolation
    /// reads as a curve rather than as its own facets.
    var resolution: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let inset = amplitude * 1.6
        let field = rect.insetBy(dx: inset, dy: inset)
        guard field.width > 1, field.height > 1 else {
            return Path(rect)
        }

        var path = Path()
        let headSteps = steps(for: field.width)
        let sideSteps = steps(for: field.height)

        path.move(to: CGPoint(x: field.minX, y: field.minY + wander(0, length: field.width, salt: 11)))

        // Head
        for step in 0...headSteps {
            let t = CGFloat(step) / CGFloat(headSteps)
            path.addLine(to: CGPoint(
                x: field.minX + field.width * t,
                y: field.minY + wander(t, length: field.width, salt: 11)
            ))
        }
        // Fore-edge
        for step in 0...sideSteps {
            let t = CGFloat(step) / CGFloat(sideSteps)
            path.addLine(to: CGPoint(
                x: field.maxX + wander(t, length: field.height, salt: 1_009),
                y: field.minY + field.height * t
            ))
        }
        // Tail
        for step in 0...headSteps {
            let t = CGFloat(step) / CGFloat(headSteps)
            path.addLine(to: CGPoint(
                x: field.maxX - field.width * t,
                y: field.maxY + wander(t, length: field.width, salt: 2_011)
            ))
        }
        // Back edge
        for step in 0...sideSteps {
            let t = CGFloat(step) / CGFloat(sideSteps)
            path.addLine(to: CGPoint(
                x: field.minX + wander(t, length: field.height, salt: 3_037),
                y: field.maxY - field.height * t
            ))
        }

        path.closeSubpath()
        return path
    }

    private func steps(for length: CGFloat) -> Int {
        max(8, min(220, Int(length / resolution)))
    }

    /// Two octaves of value noise along one edge, in `-amplitude...amplitude`.
    private func wander(_ t: CGFloat, length: CGFloat, salt: Int) -> CGFloat {
        let coarse = noise(t * length / coarseWavelength, salt: salt)
        let fine = noise(t * length / fineWavelength, salt: salt &+ 977)
        return (coarse * 0.76 + fine * 0.24) * amplitude
    }

    /// Value noise in `-1...1`: random at whole numbers, smoothstepped between.
    private func noise(_ x: CGFloat, salt: Int) -> CGFloat {
        let cell = x.rounded(.down)
        let fraction = x - cell
        let low = random(Int(cell), salt: salt)
        let high = random(Int(cell) + 1, salt: salt)
        let eased = fraction * fraction * (3 - 2 * fraction)
        return low + (high - low) * eased
    }

    private func random(_ index: Int, salt: Int) -> CGFloat {
        let mixed = (seed &+ salt &* 40_503 &+ index &* 6_247).stableScramble
        return CGFloat(UInt(bitPattern: mixed) % 2_001) / 1_000 - 1
    }
}

// MARK: Patina

/// The accidents a lifted leaf carries: edge darkening, foxing, and at most one
/// louder mark. Seeded from the Page's own identifier, so a Page wears the same
/// history every time it is opened.
///
/// The foot band is kept clear on purpose. The reader's marks live there, and a
/// water ring under a wax seal reads as a rendering bug rather than as age.
struct OpenedLeafPatina: View {
    let recipe: LeafDecorationRecipe
    let tint: Color
    /// Height of the fixed foot margin, measured from the tail of the leaf.
    var footClearance: CGFloat = 96
    /// Height of the fixed head margin.
    var headClearance: CGFloat = 62

    private enum Accident: Int {
        case waterRing
        case inkSpatter
        case softCrease
    }

    var body: some View {
        Canvas { context, size in
            let wear = recipe.wearLevel
            let field = CGRect(
                x: 0,
                y: headClearance,
                width: size.width,
                height: max(1, size.height - headClearance - footClearance)
            )

            // Every edge of a lifted leaf has been handled, so all four darken.
            context.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: 10 + unit(1) * 8)),
                with: .color(BookPalette.parchmentEdge.opacity(wear * 0.12))
            )
            context.fill(
                Path(CGRect(x: size.width - 12 - unit(2) * 8, y: 0, width: 20, height: size.height)),
                with: .color(BookPalette.parchmentEdge.opacity(wear * 0.15))
            )
            context.fill(
                Path(CGRect(x: -8, y: 0, width: 14 + unit(3) * 6, height: size.height)),
                with: .color(BookPalette.parchmentEdge.opacity(wear * 0.11))
            )
            context.fill(
                Path(CGRect(x: 0, y: size.height - 12 - unit(4) * 7, width: size.width, height: 20)),
                with: .color(BookPalette.parchmentEdge.opacity(wear * 0.13))
            )

            if recipe.hasFoxing {
                for index in 0..<15 {
                    let radius = 0.8 + unit(20 + index) * 2.6
                    let hugsEdge = index.isMultiple(of: 3)
                    let x = hugsEdge
                        ? (unit(50 + index) < 0.5
                            ? unit(70 + index) * 26
                            : size.width - unit(70 + index) * 28)
                        : unit(70 + index) * size.width
                    let y = field.minY + unit(100 + index) * field.height
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(Color.brown.opacity(0.032 + Double(unit(130 + index)) * 0.05))
                    )
                }
            }

            switch accident {
            case .waterRing?:
                let diameter = min(size.width, field.height) * (0.22 + unit(170) * 0.10)
                let ring = CGRect(
                    x: size.width * (0.52 + unit(171) * 0.20) - diameter / 2,
                    y: field.minY + field.height * (0.30 + unit(172) * 0.40) - diameter / 2,
                    width: diameter,
                    height: diameter * 0.84
                )
                context.stroke(Path(ellipseIn: ring), with: .color(Color.brown.opacity(0.075)), lineWidth: 1.2)
                context.stroke(
                    Path(ellipseIn: ring.insetBy(dx: 4, dy: 3)),
                    with: .color(Color.brown.opacity(0.028)),
                    lineWidth: 3.5
                )

            case .inkSpatter?:
                let center = CGPoint(
                    x: size.width * (0.68 + unit(190) * 0.18),
                    y: field.minY + field.height * (0.46 + unit(191) * 0.34)
                )
                for index in 0..<8 {
                    let radius = 0.7 + unit(200 + index) * (index == 0 ? 4.5 : 1.8)
                    let x = center.x + (unit(220 + index) - 0.5) * 42
                    let y = center.y + (unit(240 + index) - 0.5) * 38
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2.1,
                            height: radius * 1.65
                        )),
                        with: .color(BookPalette.ink.opacity(index == 0 ? 0.14 : 0.09))
                    )
                }

            case .softCrease?:
                var crease = Path()
                let startY = field.minY + field.height * (0.24 + unit(270) * 0.46)
                crease.move(to: CGPoint(x: size.width * 0.08, y: startY))
                crease.addCurve(
                    to: CGPoint(x: size.width * 0.92, y: startY + (unit(271) - 0.5) * 20),
                    control1: CGPoint(x: size.width * 0.33, y: startY - 6),
                    control2: CGPoint(x: size.width * 0.66, y: startY + 8)
                )
                context.stroke(crease, with: .color(Color.brown.opacity(0.045)), lineWidth: 1)
                context.stroke(crease, with: .color(.white.opacity(0.045)), lineWidth: 0.45)

            case nil:
                break
            }

            if recipe.hasWornCorner {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width - 36,
                        y: size.height - 31,
                        width: 46,
                        height: 40
                    )),
                    with: .color(tint.opacity(0.028))
                )
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (recipe.seed &+ salt &* 4_049).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }

    /// One loud mark at most. A leaf that carried every accident it owns would
    /// look decorated rather than used.
    private var accident: Accident? {
        var candidates: [Accident] = []
        if recipe.hasWaterRing { candidates.append(.waterRing) }
        if recipe.hasInkSpatter { candidates.append(.inkSpatter) }
        if recipe.hasSoftCrease { candidates.append(.softCrease) }
        return candidates.min { left, right in
            (recipe.seed &+ left.rawValue &* 7_919).stableScramble
                < (recipe.seed &+ right.rawValue &* 7_919).stableScramble
        }
    }
}

// MARK: Paper

/// Turns any view into a lifted leaf.
///
/// The material is not a copy of the folio's: it is the folio's. Colour,
/// fibre map, grain weight and the pair of edge strokes all come from the same
/// `parchmentSurface` modifier `FolioLeafPage` applies, given the same
/// `PageVisualStyle` and the same `LeafPaperStock` the folio would resolve for
/// this Page. Only two things are added on top — the seeded accidents, and the
/// shadow of a sheet held off the thing behind it.
private struct OpenedLeafPaper: ViewModifier {
    let style: PageVisualStyle
    let recipe: LeafDecorationRecipe
    let headClearance: CGFloat
    let footClearance: CGFloat

    private var cut: ParchmentSurfaceCut {
        .openedLeaf(seed: recipe.seed)
    }

    // The same layers `parchmentSurface` stacks around a folio leaf, stacked so
    // that nothing the reader scrolls has to be redrawn through them. Hung off
    // the whole leaf, scroll view included, every scrolled frame re-derived
    // three blurs, two masks, a colour filter and two blends from writing that
    // had only moved. None of them depend on the writing: the shadows follow
    // the cut, and the fibre and the accidents only multiply into whatever is
    // beneath them.
    func body(content: Content) -> some View {
        let paper = ParchmentMaterial(
            style: style,
            paperStock: recipe.paperStock,
            textureSeed: recipe.seed,
            // A leaf the reader is holding is always the lit one.
            isActive: true
        )
        let cut = self.cut

        return content
            // Beneath the writing: the sheet and every shadow it throws, drawn
            // once from the cut. With nothing behind the sheet, the shadow is
            // the only thing separating the held leaf from the Book showing
            // through. It falls down and slightly left, the way a sheet lifted
            // by its fore-edge actually throws one.
            .background {
                paper.fill(cut)
                    .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
                    // The stock's fibre map is square and fills the leaf, so on
                    // a leaf taller than it is wide it reaches past the cut on
                    // either side. Out there it has always shown as a faint grey
                    // veil over the dark, and the leaf's shadow has always
                    // fallen from it too. It is laid down here, beneath the
                    // writing, with a second sheet over the part inside the
                    // leaf. Overlays rather than a ZStack: a ZStack would stretch
                    // both sheets to the fibre's square.
                    .overlay {
                        paper.fiber(multipliesIntoPage: false)
                            .clipShape(cut)
                    }
                    .overlay {
                        paper.fill(cut)
                    }
                    .shadow(color: paper.glowColor, radius: paper.glowRadius, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.50), radius: 22, x: -4, y: 14)
                    .shadow(color: .black.opacity(0.30), radius: 6, x: -1, y: 3)
            }
            // Over the writing, as before: the leaf's accidents and the stock's
            // fibre, multiplied into the ink. Multiplied onto white they come
            // out as one finished sheet, and multiplying that sheet into the
            // page once is the same as multiplying each of them in turn. Both
            // hang off the white sheet as overlays, so they are placed on the
            // leaf and not on the square the fibre fills.
            .overlay {
                cut.fill(Color.white)
                    .overlay {
                        OpenedLeafPatina(
                            recipe: recipe,
                            tint: style.accent,
                            footClearance: footClearance,
                            headClearance: headClearance
                        )
                    }
                    .overlay {
                        paper.fiber()
                    }
                    .clipShape(cut)
                    .drawingGroup()
                    .blendMode(.multiply)
                    // Paper takes no touches. These layers cover the whole leaf,
                    // the reader's scroll view included, and a filled sheet — a
                    // rasterised one especially — answers a hit test that belongs
                    // to the writing underneath it.
                    .allowsHitTesting(false)
            }
            // The grain's specks all sit well inside the cut, so it needs no mask.
            .overlay {
                paper.grain()
                    .allowsHitTesting(false)
            }
            .overlay {
                paper.edgeStroke(cut)
                    .allowsHitTesting(false)
            }
            .overlay {
                paper.accentStroke(cut)
                    .allowsHitTesting(false)
            }
            .overlay {
                paper.moonwriteGlow(cut)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Applies the lifted-leaf material. `headClearance` and `footClearance`
    /// name the fixed margins so the patina keeps them clear of accidents.
    func openedLeafPaper(
        style: PageVisualStyle,
        recipe: LeafDecorationRecipe,
        headClearance: CGFloat = 62,
        footClearance: CGFloat = 96
    ) -> some View {
        modifier(OpenedLeafPaper(
            style: style,
            recipe: recipe,
            headClearance: headClearance,
            footClearance: footClearance
        ))
    }
}

// MARK: - Typography instead of containers

/// A rule drawn by hand: not quite level, heavier at one end, the way a ruled
/// line pressed with a nib actually lands. Replaces the hairline strokes of
/// rounded rectangles used to fence sections apart.
struct LeafRule: View {
    var seed: Int = 0
    var tint: Color = BookPalette.ink
    var opacity: Double = 0.20
    var weight: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let drift = (unit(3) - 0.5) * 1.6
            path.move(to: CGPoint(x: 0, y: size.height / 2 - drift))
            path.addCurve(
                to: CGPoint(x: size.width, y: size.height / 2 + drift),
                control1: CGPoint(x: size.width * 0.34, y: size.height / 2 + drift * 0.6),
                control2: CGPoint(x: size.width * 0.68, y: size.height / 2 - drift * 0.4)
            )
            context.stroke(
                path,
                with: .color(tint.opacity(opacity)),
                style: StrokeStyle(lineWidth: weight, lineCap: .round)
            )
        }
        .frame(height: max(2, weight * 2))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 6_007).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

/// A section head as a compositor would set it: small, tracked, in ink, with
/// the rule under it doing the work a box used to do.
struct LeafSectionHead: View {
    let title: String
    var symbolName: String?
    var tint: Color = BookPalette.ink
    var seed: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.system(.caption2, design: .serif, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1.6)
            }
            .foregroundStyle(tint.opacity(0.66))

            LeafRule(seed: seed, tint: tint, opacity: 0.16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// An aside set into the page: indented, with a rule down its inner margin.
/// The book equivalent of a callout box, without the box.
struct LeafAside<Content: View>: View {
    var tint: Color = BookPalette.ink
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.leading, 13)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tint.opacity(0.30))
                    .frame(width: 1.5)
                    .allowsHitTesting(false)
            }
    }
}

/// The ruled lines a reader writes between. Drawn behind the writing area so
/// the reader's own words land on the page rather than inside a control.
struct LeafRuledLines: View {
    var seed: Int = 0
    var spacing: CGFloat = 27
    var tint: Color = BookPalette.ink
    var opacity: Double = 0.14

    var body: some View {
        Canvas { context, size in
            guard spacing > 4 else { return }
            var y = spacing
            var index = 0
            while y < size.height - 2 {
                var path = Path()
                let drift = (unit(index) - 0.5) * 1.1
                path.move(to: CGPoint(x: 2, y: y - drift))
                path.addCurve(
                    to: CGPoint(x: size.width - 2, y: y + drift),
                    control1: CGPoint(x: size.width * 0.35, y: y + drift * 0.7),
                    control2: CGPoint(x: size.width * 0.70, y: y - drift * 0.5)
                )
                context.stroke(
                    path,
                    with: .color(tint.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )
                y += spacing
                index += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 7_013).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

// MARK: - Marks the reader can press

/// Keep, as a seal pressed into wax. It is round because wax is round, it sits
/// slightly proud of the paper, and it darkens rather than tints when disabled:
/// cold wax, not a greyed-out control.
struct LeafWaxSeal: View {
    let title: String
    var symbolName: String = "seal.fill"
    var seed: Int = 0
    var isEnabled: Bool = true
    var isPressed: Bool = false

    /// Warm sealing wax under the lamp; and the same wax gone cold, which is
    /// what an unpressed seal looks like. Fading the hot colour instead would
    /// make it a greyed-out control, and on cream paper a faded red is barely
    /// there at all — the seal read as a rendering failure rather than as a
    /// thing waiting to be pressed.
    private var wax: Color {
        isEnabled
            ? Color(red: 0.54, green: 0.12, blue: 0.13)
            : Color(red: 0.38, green: 0.13, blue: 0.14)
    }

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [wax, wax.opacity(0.80)],
                            center: UnitPoint(x: 0.36, y: 0.30),
                            startRadius: 1,
                            endRadius: 22
                        )
                    )
                    .overlay {
                        // Wax squeezes out unevenly under the matrix.
                        Circle()
                            .stroke(wax.opacity(0.55), lineWidth: 2.5)
                            .blur(radius: 1.6)
                            .scaleEffect(1.06 + CGFloat(unit(5)) * 0.05)
                    }
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(isEnabled ? 0.22 : 0.10), lineWidth: 0.8)
                            .padding(3)
                    }
                    .saturation(isEnabled ? 1 : 0.72)
                    .brightness(isEnabled ? 0 : -0.05)

                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(BookPalette.page.opacity(isEnabled ? 0.84 : 0.52))
                    .shadow(color: .black.opacity(0.5), radius: 0.6, x: 0, y: 0.6)
            }
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(Double(unit(7) - 0.5) * 14))
            .shadow(color: .black.opacity(isEnabled ? 0.34 : 0.12), radius: isPressed ? 1 : 3, x: 0, y: isPressed ? 0.5 : 2)

            Text(title)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(BookPalette.ink.opacity(isEnabled ? 0.88 : 0.46))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .scaleEffect(isPressed ? 0.97 : 1)
        .contentShape(Rectangle())
    }

    private func unit(_ salt: Int) -> CGFloat {
        let raw = UInt(bitPattern: (seed &+ salt &* 8_017).stableScramble) % 10_000
        return CGFloat(raw) / 9_999
    }
}

/// Letting a Page wait is a pencil note in the foot margin, not a button. It
/// gets an underline so it still reads as pressable, drawn as a stroke rather
/// than a border.
struct LeafPencilMark: View {
    let title: String
    var symbolName: String?
    var seed: Int = 0
    var tint: Color = BookPalette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(.subheadline, design: .serif))
                    .lineLimit(2)
            }
            .foregroundStyle(tint.opacity(0.68))

            LeafRule(seed: seed &+ 41, tint: tint, opacity: 0.26, weight: 0.9)
                .frame(height: 2)
        }
        // The underline is a Canvas, and a Canvas takes every point it is
        // offered. Without this the mark swallowed the Spacer beside it, so a
        // Close meant for the right-hand margin sat against the title with a
        // rule dragged out across the whole head.
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
    }
}

// MARK: - Ink on paper

/// The inks a leaf is written in.
///
/// A Page opened over the night sky was lit in `BookPalette.lampGold` — a
/// lamp colour, bright because it had darkness to carry it. On paper that same
/// gold is a pale wash on a pale ground and all but disappears. These are the
/// paper-side equivalents: the same warmth, mixed dark enough to be read.
enum LeafInk {
    /// Gilt as it lands on parchment: bronze rather than lamplight. Carries the
    /// weight `lampGold` carried at night, at roughly five to one against the
    /// page, so it stays legible as running text and not only as ornament.
    static let gold = Color(red: 0.52, green: 0.30, blue: 0.08)

    /// A pencil note rather than a written one.
    static let pencil = Color(red: 0.34, green: 0.31, blue: 0.28)
}

/// A small action written into the page rather than mounted on it: a short ink
/// label with a rule under it, sized to its own words instead of stretched
/// across the column.
///
/// This is what replaced the tinted pill. A full-width capsule is the clearest
/// single signal that a surface is an app: paper has no controls, only marks —
/// but a mark still has to look pressable, so it gets the underline a hand
/// would give a word it meant you to act on.
struct LeafInkMark: View {
    let title: String
    var symbolName: String?
    var seed: Int = 0
    var tint: Color = LeafInk.gold
    /// A quieter second choice sitting under a first one.
    var isSecondary: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: isSecondary ? 10 : 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(
                        isSecondary ? .footnote : .subheadline,
                        design: .serif,
                        weight: isSecondary ? .regular : .semibold
                    ))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(tint.opacity(isSecondary ? 0.68 : 0.92))

            LeafRule(
                seed: seed &+ title.count &* 13,
                tint: tint,
                opacity: isSecondary ? 0.20 : 0.34,
                weight: isSecondary ? 0.8 : 1
            )
            .frame(height: 2)
        }
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
    }
}

// MARK: - What a surface is made of

/// Whether a view is being drawn against the night or written on a leaf.
///
/// Most of the Book's shelves are built once and shown in two places: on a
/// leaf, when the reader opens a division, and against the night on the iPad
/// dashboard. Lamp colours only work in the dark, ink only works on paper, so
/// a shelf has to be told which it is standing on. It is told through the
/// environment rather than a parameter because the shelves are assembled by
/// `ContentView` methods, far above the surface that finally holds them.
enum BookSurfaceMaterial {
    case night
    case paper
}

private struct BookSurfaceMaterialKey: EnvironmentKey {
    static let defaultValue: BookSurfaceMaterial = .night
}

private struct BookDivisionTitleKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var bookSurfaceMaterial: BookSurfaceMaterial {
        get { self[BookSurfaceMaterialKey.self] }
        set { self[BookSurfaceMaterialKey.self] = newValue }
    }

    /// The running head of the division being read, when there is one. A shelf
    /// whose own title repeats it does not print the title a second time.
    var bookDivisionTitle: String? {
        get { self[BookDivisionTitleKey.self] }
        set { self[BookDivisionTitleKey.self] = newValue }
    }
}

/// Colours that pick themselves when drawn, from the surface they land on.
///
/// This has to be a `ShapeStyle` rather than a `Color` chosen up front: the
/// view that asks for gilt is built by a `ContentView` method, whose own
/// environment is always the night. Only at render time, inside the leaf, is
/// the right answer knowable.
struct MaterialInk: ShapeStyle {
    fileprivate enum Role {
        case gilt
        case text
        case accent(Color)
    }

    fileprivate let role: Role

    /// Lamp gold at night; bronze on paper.
    static let gilt = MaterialInk(role: .gilt)
    /// Night text at night; ink on paper.
    static let text = MaterialInk(role: .text)

    /// A caller's own accent, except that lamp gold becomes bronze on paper.
    static func accent(_ color: Color) -> MaterialInk {
        MaterialInk(role: .accent(color))
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        let onPaper = environment.bookSurfaceMaterial == .paper
        switch role {
        case .gilt:
            return onPaper ? LeafInk.gold : BookPalette.lampGold
        case .text:
            return onPaper ? BookPalette.ink : BookPalette.nightText
        case .accent(let color):
            guard onPaper, color == BookPalette.lampGold else { return color }
            return LeafInk.gold
        }
    }
}

/// A panel lit against the night. On paper it is nothing, or a rule down the
/// inner margin: the section head and its rule already do a card's work there,
/// and a rounded card laid on a leaf is the app showing through the book.
struct BookNightCard: ViewModifier {
    enum OnPaper {
        case nothing
        case aside
    }

    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 12
    var fillOpacity: Double = 0.46
    var stroke: Color = BookPalette.lampGold
    var strokeOpacity: Double = 0.22
    var strokeWidth: CGFloat = 1
    var castsShadow = false
    var onPaper: OnPaper = .nothing

    @Environment(\.bookSurfaceMaterial) private var material

    @ViewBuilder
    func body(content: Content) -> some View {
        if material == .paper {
            switch onPaper {
            case .nothing:
                content
                    .padding(.vertical, 4)
            case .aside:
                content
                    .padding(.leading, 13)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(MaterialInk.accent(stroke).opacity(0.45))
                            .frame(width: 1.5)
                            .allowsHitTesting(false)
                    }
            }
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .padding(padding)
                .background {
                    if castsShadow {
                        shape
                            .fill(BookPalette.nightPanel.opacity(fillOpacity))
                            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
                    } else {
                        shape
                            .fill(BookPalette.nightPanel.opacity(fillOpacity))
                    }
                }
                .overlay {
                    shape.stroke(stroke.opacity(strokeOpacity), lineWidth: strokeWidth)
                }
        }
    }
}

/// A faint panel set inside a night card. On paper, a rule down its inner edge.
struct BookInsetPanel: ViewModifier {
    var horizontalPadding: CGFloat = 14
    var stroke: Color = BookPalette.lampGold

    @Environment(\.bookSurfaceMaterial) private var material

    @ViewBuilder
    func body(content: Content) -> some View {
        if material == .paper {
            content
                .padding(.leading, 13)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(MaterialInk.accent(stroke).opacity(0.40))
                        .frame(width: 1.5)
                        .allowsHitTesting(false)
                }
        } else {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            content
                .padding(.horizontal, horizontalPadding)
                .background(BookPalette.paper.opacity(0.08), in: shape)
                .overlay {
                    shape.stroke(stroke.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

/// A parchment card that stands out against the night. On a leaf it is
/// already paper, and a paper card on paper is a card on a card.
struct BookPaperCard: ViewModifier {
    var cornerRadius: CGFloat = 8
    var padding: CGFloat = 20

    @Environment(\.bookSurfaceMaterial) private var material

    @ViewBuilder
    func body(content: Content) -> some View {
        if material == .paper {
            content
                .padding(.vertical, 6)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .padding(padding)
                .background(BookPalette.paper.opacity(0.92), in: shape)
                .overlay {
                    shape.stroke(BookPalette.gold.opacity(0.30), lineWidth: 1)
                }
        }
    }
}

/// A shadow or glow that only makes sense in the dark. On paper a card does
/// not float and gilt does not shine, and every shadow dropped here is one the
/// render server no longer has to blur on a surface that scrolls.
struct BookNightShadow: ViewModifier {
    let color: Color
    let radius: CGFloat
    var x: CGFloat = 0
    var y: CGFloat = 0

    @Environment(\.bookSurfaceMaterial) private var material

    @ViewBuilder
    func body(content: Content) -> some View {
        if material == .paper {
            content
        } else {
            content.shadow(color: color, radius: radius, x: x, y: y)
        }
    }
}

// MARK: - Shelves inside a division

/// A folded shelf's title, which a leaf already prints as its running head
/// when the division and the shelf are the same thing.
struct ShelfRunningTitle: View {
    let title: String

    @Environment(\.bookSurfaceMaterial) private var material
    @Environment(\.bookDivisionTitle) private var divisionTitle

    var body: some View {
        if !(material == .paper && divisionTitle == title) {
            Text(title)
                .sectionRuneLabel()
        }
    }
}

/// "open" and the chevron. A division the reader opened on purpose does not
/// fold, so on its own leaf the fold mark is furniture and is left off.
struct ShelfFoldMark: View {
    let title: String
    let isExpanded: Bool
    let accent: Color
    /// The word a shelf uses for unfolded. Most say "open"; Colophon has always
    /// said "visible", and the night surfaces keep their own word.
    var openLabel = "open"

    @Environment(\.bookSurfaceMaterial) private var material
    @Environment(\.bookDivisionTitle) private var divisionTitle

    var body: some View {
        if !(material == .paper && divisionTitle == title) {
            Text(isExpanded ? openLabel : "folded")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.gold.opacity(0.78))

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(MaterialInk.accent(accent))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }
}

/// Stops the header of a shelf that is its own division from folding the leaf
/// shut. With the fold mark gone there would be nothing to say it could.
struct ShelfHeaderLock: ViewModifier {
    let title: String

    @Environment(\.bookSurfaceMaterial) private var material
    @Environment(\.bookDivisionTitle) private var divisionTitle

    func body(content: Content) -> some View {
        let isLocked = material == .paper && divisionTitle == title
        content
            .allowsHitTesting(!isLocked)
            .accessibilityRemoveTraits(isLocked ? .isButton : [])
    }
}

// MARK: - A division, opened

extension BookObjectDivision {
    /// The Page family whose paper this division is printed on. Divisions are
    /// not Pages, but they are made of the same stock as the Pages they gather,
    /// so each borrows the family it is closest to.
    var leafPaperType: BookPageType {
        switch self {
        case .bookToday: return .bookNotices
        case .cast: return .castBond
        case .correspondences: return .bookConnections
        case .bestiary: return .illuminatedPhoto
        case .gazetteer: return .wonderCompass
        case .atlas: return .marginsAtlas
        case .todaysMargins: return .note
        case .returned: return .bookRemembered
        case .bookOfYou: return .bookOfYou
        case .colophon: return .frontMatter
        }
    }
}

/// The lifted leaf as a frame: a running head with its Close mark, the paper,
/// and the environment that tells everything inside it that it is written on
/// paper. The content brings its own scrolling, so a surface that already owns
/// a `ScrollViewReader` keeps it.
///
/// Closes through `dismiss`, which ends whichever sheet holds it.
struct BookLeafFrame<Content: View>: View {
    let title: String
    let paperType: BookPageType
    let seedID: String
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let style = PageVisualStyle.style(for: paperType)
        let recipe = LeafDecorationLibrary.recipe(
            pageType: paperType,
            metadata: [:],
            semanticText: title,
            documentID: seedID,
            leafIndex: 0
        )

        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(.caption2, design: .serif, weight: .bold))
                        .textCase(.uppercase)
                        .kerning(1.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(style.accent.opacity(0.82))
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 8)

                    Button {
                        BookFeedback.play(.dismissPage)
                        dismiss()
                    } label: {
                        LeafPencilMark(
                            title: "Close",
                            symbolName: "xmark",
                            seed: recipe.seed,
                            tint: LeafInk.pencil
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close \(title)")
                }

                LeafRule(seed: recipe.seed, tint: BookPalette.ink, opacity: 0.22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // The leaf holds still; only the writing on it moves. That keeps
            // the paper's fibre map, grain and patina out of every scrolled
            // frame, which matters on the surfaces people scroll longest.
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .environment(\.bookSurfaceMaterial, .paper)
        .environment(\.bookDivisionTitle, title)
        .openedLeafPaper(
            style: style,
            recipe: recipe,
            headClearance: 62,
            footClearance: 20
        )
        .padding(5)
    }
}

/// A division of the Book, opened: the same lifted leaf as an opened Page,
/// holding a shelf rather than a Page.
///
/// Takes its content already built, so the call in `ContentView` carries no
/// closure. `ContentView` is an address-only struct of some seventeen kilobytes
/// and every self-capturing closure in an argument list costs a stack copy of
/// it; see `captureSheet(for:)`.
struct BookDivisionLeaf: View {
    let title: String
    let paperType: BookPageType
    let seedID: String
    let content: AnyView

    var body: some View {
        BookLeafFrame(title: title, paperType: paperType, seedID: seedID) {
            ScrollView {
                content
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// A dark fill laid behind lamp-lit writing. On a leaf that writing is ink and
/// the page is its ground, so there is nothing to lay down; a night fill left
/// under converted text would put ink on a dark panel.
struct BookNightFill: ViewModifier {
    var opacity: Double
    var cornerRadius: CGFloat = 8

    @Environment(\.bookSurfaceMaterial) private var material

    @ViewBuilder
    func body(content: Content) -> some View {
        if material == .paper {
            content
        } else {
            content.background(
                BookPalette.nightPanel.opacity(opacity),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
