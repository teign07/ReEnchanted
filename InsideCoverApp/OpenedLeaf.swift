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

    func body(content: Content) -> some View {
        content
            .overlay {
                OpenedLeafPatina(
                    recipe: recipe,
                    tint: style.accent,
                    footClearance: footClearance,
                    headClearance: headClearance
                )
                .clipShape(cut)
            }
            .parchmentSurface(
                style: style,
                paperStock: recipe.paperStock,
                textureSeed: recipe.seed,
                cut: cut,
                // A leaf the reader is holding is always the lit one.
                isActive: true
            )
            // With nothing behind the sheet, this shadow is the only thing
            // separating the held leaf from the Book showing through. It falls
            // down and slightly left, the way a sheet lifted by its fore-edge
            // actually throws one.
            .shadow(color: .black.opacity(0.50), radius: 22, x: -4, y: 14)
            .shadow(color: .black.opacity(0.30), radius: 6, x: -1, y: 3)
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
