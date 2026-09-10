import SwiftUI
#if canImport(InsideCoverCore)
import InsideCoverCore
#endif

/// The real sky, drawn onto the leaf the reader is holding.
///
/// The model behind this lives in `Shared/SkyOnTheLeaf.swift` and is pure: a
/// speck's whole life is a function of its seed and the clock. This file only
/// turns those numbers into marks on paper.
///
/// **Performance is the design constraint here**, because this is the one layer
/// in the app that can be on screen continuously while the reader is reading.
/// The rules it keeps:
///
/// 1. **A clear sky costs nothing.** `PaperSky.settled(at:)` returns `nil` on a
///    clear day, a stale reading, or an intensity that rounds away, and the
///    caller does not mount this view at all. There is no idling timeline.
/// 2. **Only weather that lands is drawn.** `SkyCondition.marksThePaper` is
///    false for clear, cloudy, *and* foggy skies — see the note on it.
/// 3. **One `Canvas`, one timeline, capped at 30fps.** The specks and the
///    fore-edge are drawn in a single pass. No per-drop views, and no animating
///    `Shape`, which would re-tessellate a path every frame.
/// 4. **The speck table is built in `body`, not in the frame closure.** It is
///    rebuilt when the weather changes, not thirty times a second.
/// 5. **It never takes a touch.** The leaves turn via `UIPageViewController`,
///    which hit-tests untransformed frames; a greedy overlay here would eat
///    page turns without looking as though it had.
struct SkyOnTheLeafLayer: View {
    /// The settled reading — already faded for staleness by the caller.
    let sky: PaperSky
    /// Where the Book is, in this layer's coordinate space.
    let bookRect: CGRect
    /// Ambient motion is suspended (the Book is working, or off screen).
    var isPaused = false
    /// Renders one still frame at this moment instead of starting a clock.
    ///
    /// The same seam `AmbientLetterField` uses: it lets an offscreen renderer
    /// ask for a chosen instant, so how the weather actually looks on paper can
    /// be checked without booting the whole app.
    var frozenTime: TimeInterval? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Water darkens paper. Every wet mark here is this colour under
    /// `.multiply`, which is what makes it read as *the paper being wet*
    /// rather than as a grey dot sitting on top of the page.
    private static let damp = Color(red: 0.32, green: 0.24, blue: 0.15)
    /// The light caught in a standing bead.
    private static let beadLight = Color(red: 1.0, green: 0.97, blue: 0.88)
    /// Snow, which is lit rather than wet.
    private static let flake = Color(red: 0.98, green: 0.98, blue: 1.0)
    /// The cool grey a flake casts onto cream paper. Without this, snow glows
    /// through the leaf like a firefly instead of resting on it.
    private static let flakeShadow = Color(red: 0.42, green: 0.45, blue: 0.52)

    /// The leaf inside the Book's frame.
    ///
    /// The Book publishes one anchor for its whole self; the paper is inset
    /// within it. These are proportions rather than points so the same figures
    /// hold on a phone and a pad.
    private var leafRect: CGRect {
        guard bookRect.width > 40, bookRect.height > 40 else { return .zero }
        return bookRect.insetBy(
            dx: bookRect.width * 0.055,
            dy: bookRect.height * 0.045
        )
    }

    private var speckCount: Int {
        SkyField.count(for: sky, leafArea: Double(leafRect.width * leafRect.height))
    }

    /// Stillness has two causes with the same answer: the reader asked for
    /// less motion, or the Book is busy and ambient motion is suspended. Both
    /// get the weather at rest rather than no weather — drops already sitting
    /// on the paper, which is a real thing paper does and costs one frame.
    private var isStill: Bool { isPaused || reduceMotion }

    var body: some View {
        // A book too small to be real (a first layout pass, a collapsed frame)
        // gets nothing. Drawing into a zero rect is wasted work, and dividing
        // by its dimensions is worse.
        if leafRect.width > 20, leafRect.height > 20 {
            content
                // The leaves turn underneath this. It must never take a touch.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var content: some View {
        // Built here rather than inside the frame closure: `body` runs when the
        // weather changes, the closure runs thirty times a second.
        let specks = SkyField.specks(
            count: speckCount,
            condition: sky.condition,
            seed: 0x5EED
        )

        if isStill || frozenTime != nil {
            // One frame, held. The clock defaults to a moment where most of the
            // field has already landed, so a stilled leaf reads as *rained on*
            // rather than as a page caught mid-storm.
            let time = frozenTime ?? 4.2
            // A held frame keeps the wind in the fore-edge only when the
            // caller chose the moment; ambient stillness means a still page.
            let wind = frozenTime == nil ? 0 : sky.wind
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                draw(specks: specks, in: context, time: time, wind: wind)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                    draw(specks: specks, in: context, time: time, wind: sky.wind)
                }
            }
        }
    }

    // MARK: - Drawing

    private func draw(
        specks: [SkySpeck],
        in context: GraphicsContext,
        time: TimeInterval,
        wind: Double
    ) {
        let leaf = leafRect
        let isSnow = sky.condition == .snow

        for speck in specks {
            let frame = SkyField.frame(
                for: speck,
                condition: sky.condition,
                wind: wind,
                time: time
            )
            let point = CGPoint(
                x: leaf.minX + leaf.width * frame.x,
                y: leaf.minY + leaf.height * frame.y
            )
            // A speck whose wind drift carried it off the paper is simply not
            // drawn. Clipping would cut it in half against an invisible edge.
            guard leaf.insetBy(dx: -2, dy: -2).contains(point) else { continue }

            if isSnow {
                drawFlake(frame, at: point, in: context)
            } else {
                drawDrop(frame, at: point, in: context)
            }
        }

        drawForeEdge(in: context, time: time, wind: wind)
    }

    /// A drop of water sitting on paper.
    ///
    /// The thing that makes this read as water rather than as a grey stud is
    /// that the drop is mostly *not there*: paper shows straight through it.
    /// What the eye actually reads is the darkening it causes — the soaked
    /// halo around it, and the ring where the curve of the drop bends the light
    /// at its own edge. The bright speck is the smallest part, not the biggest.
    private func drawDrop(
        _ frame: SkySpeckFrame,
        at point: CGPoint,
        in context: GraphicsContext
    ) {
        // Heavier weather makes bigger drops, not only more of them.
        let radius = (1.5 + frame.size * 2.4) * (0.82 + sky.intensity * 0.42)

        // Water darkens paper. Multiplying is what makes this soak *into* the
        // page instead of settling as a grey film on top of it.
        var wet = context
        wet.blendMode = .multiply

        // The soaked halo, as a radial gradient. A flat ellipse at low alpha
        // reads as a disc with an edge; the whole point of a damp mark is that
        // it has no edge.
        if frame.dampAlpha > 0.01 {
            let spread = radius * 2.8
            let strength = 0.30 * frame.dampAlpha * (0.45 + sky.intensity * 0.55)
            wet.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - spread,
                    y: point.y - spread * 0.88,
                    width: spread * 2,
                    height: spread * 1.76
                )),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Self.damp.opacity(strength), location: 0),
                        .init(color: Self.damp.opacity(strength * 0.55), location: 0.45),
                        .init(color: Self.damp.opacity(0), location: 1)
                    ]),
                    center: point,
                    startRadius: 0,
                    endRadius: spread
                )
            )
        }

        guard frame.beadAlpha > 0.01 else { return }

        // The streak behind an arriving drop. Short on purpose: this is
        // weather on the leaf, and a streak spanning the page would be drawing
        // rain in the room instead.
        if frame.arrival < 1 {
            var streak = Path()
            streak.move(to: CGPoint(x: point.x, y: point.y - radius * 5.5 * (1 - frame.arrival)))
            streak.addLine(to: point)
            wet.stroke(
                streak,
                with: .color(Self.damp.opacity(0.20 * frame.beadAlpha)),
                style: StrokeStyle(lineWidth: radius * 0.42, lineCap: .round)
            )
        }

        let body = CGRect(
            x: point.x - radius,
            y: point.y - radius * 0.88,
            width: radius * 2,
            height: radius * 1.76
        )

        // The lens itself. A drop darkens the paper most at its perimeter,
        // where its curve is steepest and turns the light furthest aside — but
        // that darkening is a gradient, not a drawn ring. Stroking a circle
        // here is precisely what makes a drop look like a small metal washer.
        //
        // The gradient's centre sits up and to the left of the drop's own
        // centre, toward the lamp, so the far rim carries more weight than the
        // near one and the bead reads as round rather than as a hoop.
        wet.fill(
            Path(ellipseIn: body),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Self.damp.opacity(0.03 * frame.beadAlpha), location: 0),
                    .init(color: Self.damp.opacity(0.08 * frame.beadAlpha), location: 0.52),
                    .init(color: Self.damp.opacity(0.26 * frame.beadAlpha), location: 0.84),
                    .init(color: Self.damp.opacity(0.44 * frame.beadAlpha), location: 1)
                ]),
                center: CGPoint(x: point.x - radius * 0.18, y: point.y - radius * 0.20),
                startRadius: 0,
                endRadius: radius * 1.14
            )
        )

        // The lamp, caught once. Small and sharp — this is a specular
        // highlight, not a painted dot.
        var lit = context
        lit.blendMode = .plusLighter
        lit.fill(
            Path(ellipseIn: CGRect(
                x: point.x - radius * 0.60,
                y: point.y - radius * 0.66,
                width: radius * 0.46,
                height: radius * 0.38
            )),
            with: .color(Self.beadLight.opacity(0.62 * frame.beadAlpha))
        )

        // And the light that went through the drop and landed under its far
        // side. Faint, but it is the difference between a bead of water and a
        // hole in the page.
        lit.fill(
            Path(ellipseIn: CGRect(
                x: point.x + radius * 0.05,
                y: point.y + radius * 0.20,
                width: radius * 0.80,
                height: radius * 0.52
            )),
            with: .color(Self.beadLight.opacity(0.20 * frame.beadAlpha))
        )
    }

    private func drawFlake(
        _ frame: SkySpeckFrame,
        at point: CGPoint,
        in context: GraphicsContext
    ) {
        guard frame.beadAlpha > 0.01 else { return }
        let radius = (1.4 + frame.size * 2.2) * (0.85 + sky.intensity * 0.4)

        // The shadow first, so the flake sits on the paper rather than glowing
        // through it. Offset down-right, opposite the lamp.
        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - radius * 0.8 + radius * 0.35,
                y: point.y - radius * 0.8 + radius * 0.45,
                width: radius * 1.6,
                height: radius * 1.6
            )),
            with: .color(Self.flakeShadow.opacity(0.20 * frame.beadAlpha))
        )

        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .color(Self.flake.opacity(0.82 * frame.beadAlpha))
        )
    }

    /// The fore-edge, never quite still on a windy day.
    ///
    /// Drawn here as light and shadow along the right edge rather than by
    /// animating `DeckledPaperScrapShape`: that shape is used by every scrap in
    /// the app, and animating its `amplitude` would re-tessellate a path per
    /// frame in every one of them. This is one more path in a Canvas that is
    /// already open.
    private func drawForeEdge(
        in context: GraphicsContext,
        time: TimeInterval,
        wind: Double
    ) {
        // `sky` has already been through `settled(at:)`, so its wind carries the
        // staleness fade. Scaling the model's own amplitude rather than a
        // second copy of the figure keeps the two from drifting apart.
        let amplitude = wind * PaperSky.foreEdgeAmplitude
        guard amplitude > 0.15 else { return }

        // Hugging the Book's own edge rather than the guessed leaf inset. A
        // line of light a few points away from where the paper actually ends
        // reads as a rule someone drew; on the edge itself it reads as the
        // page. The small inset is the edge's own thickness.
        let edgeX = bookRect.maxX - 3
        let top = leafRect.minY
        let height = leafRect.height

        // Sixteen segments is enough for a curve at this amplitude, and keeps
        // the whole edge to a couple of dozen points.
        let steps = 16
        var outerPoints: [CGPoint] = []
        var innerPoints: [CGPoint] = []
        outerPoints.reserveCapacity(steps + 1)
        innerPoints.reserveCapacity(steps + 1)
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let offset = SkyField.waver(at: time, alongEdge: t, amplitude: amplitude)
            let y = top + height * t
            // How far the edge has curled here, 0...1, regardless of direction.
            let lift = min(1, abs(offset) / max(0.0001, amplitude))
            outerPoints.append(CGPoint(x: edgeX + offset, y: y))
            // The band widens where the curl is greatest, which is what gives
            // the edge a sense of turning toward the light rather than sliding
            // sideways.
            innerPoints.append(CGPoint(x: edgeX + offset - 1.5 - lift * 5, y: y))
        }

        var inner = Path()
        inner.addLines(innerPoints)

        // The face of the lifted edge: a narrow ribbon between the paper's edge
        // and where it is still flat, brightest at the edge itself.
        var ribbon = Path()
        ribbon.addLines(outerPoints + innerPoints.reversed())
        ribbon.closeSubpath()
        context.fill(
            ribbon,
            with: .linearGradient(
                Gradient(colors: [
                    BookPalette.lampGold.opacity(0),
                    BookPalette.lampGold.opacity(0.22 * wind)
                ]),
                startPoint: CGPoint(x: edgeX - 7, y: top),
                endPoint: CGPoint(x: edgeX + amplitude, y: top)
            )
        )

        // And the shadow the raised edge casts back onto the leaf.
        var shade = context
        shade.blendMode = .multiply
        shade.stroke(
            inner,
            with: .color(Color(red: 0.28, green: 0.21, blue: 0.13).opacity(0.20 * wind)),
            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
        )
    }
}
