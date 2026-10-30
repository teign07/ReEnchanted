import SwiftUI
import UIKit

/// Her reading desk is local and idle work. Nothing here is called by a frame,
/// a shake, or a keystroke. Enrichments with unchanged reader words reuse it.
private actor PippaReadingWorker {
    private var signature: Int?
    private var reading = PippaReading()

    func prepare(days: [BookDay]) -> PippaReading {
        var hasher = Hasher()
        var seen = Set<String>()
        var writings: [PippaWordFinds.Writing] = []
        for day in days {
            for page in day.pages where seen.insert(page.id).inserted {
                guard !Task.isCancelled else { return reading }
                guard page.privacy != .localSensitive else { continue }
                let texts = page.readerAuthoredTexts
                guard !texts.isEmpty else { continue }
                hasher.combine(page.id)
                hasher.combine(page.createdAt)
                hasher.combine(texts)
                writings.append(.init(id: page.id, date: page.createdAt, texts: texts))
            }
        }
        let next = hasher.finalize()
        guard next != signature else { return reading }
        let made = PippaWordFinds.prepare(writings: writings)
        guard !Task.isCancelled else { return reading }
        signature = next
        reading = made
        return made
    }
}

@MainActor
@Observable
final class PippaReadingDesk {
    static let shared = PippaReadingDesk()
    private(set) var reading = PippaReading()
    @ObservationIgnored private let worker = PippaReadingWorker()
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var recentIDs: [String] = []
    @ObservationIgnored private var recentWords: [String] = []
    @ObservationIgnored private var favourite: String?
    @ObservationIgnored private var encounter = 0

    func prepare(days: [BookDay]) {
        preparation?.cancel()
        revision &+= 1
        let ticket = revision
        let worker = worker
        preparation = Task(priority: .background) { [weak self] in
            // Let the Keep's absorption, retirement and archive writes finish.
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            await KeepReplyStage.waitForQuiet()
            guard !Task.isCancelled else { return }
            let made = await worker.prepare(days: days)
            guard !Task.isCancelled, let self, ticket == self.revision else { return }
            if self.reading != made { self.reading = made }
            if let favourite = self.favourite, made.favouriteScrap(for: favourite) == nil {
                self.favourite = nil
            }
            self.preparation = nil
        }
    }

    /// A bounded deck, with no immediate word or message repeats. A favourite
    /// is a callback, not a reason to show the same first word forever.
    func nextScrap() -> PippaScrap {
        encounter += 1
        let personal = reading.scraps.filter {
            !recentIDs.contains($0.id) && ($0.word.map { !recentWords.contains($0) } ?? true)
        }
        // Choose a kind of discovery before a particular scrap. Twenty words
        // must not drown out the one punctuation count or cross-Page meeting.
        let families = Dictionary(grouping: personal) { $0.id.split(separator: ":").first.map(String.init) ?? "word" }
        var candidates = encounter % 3 == 1 ? PippaScrap.cheek : (families.values.randomElement() ?? [])
        if encounter % 7 == 0, let favourite,
           let callback = reading.favouriteScrap(for: favourite), !recentIDs.contains(callback.id) {
            candidates = [callback]
        }
        candidates = candidates.filter { !recentIDs.contains($0.id) }
        if candidates.isEmpty {
            candidates = PippaScrap.cheek.filter { $0.id != recentIDs.last }
        }
        let scrap = candidates.randomElement() ?? PippaScrap.cheek[0]
        recentIDs = Array((recentIDs + [scrap.id]).suffix(8))
        if let word = scrap.word {
            recentWords = Array((recentWords + [word]).suffix(4))
            if favourite == nil { favourite = word }
        }
        return scrap
    }
}

/// Immutable geometry, shared by her existing Canvas and the card's finite
/// GeometryEffect. Native text is laid out once, not resolved into every frame.
///
/// The card hangs from a thread through a hole near its top corner, so every
/// card position here is that hole, and the card swings around it.
struct PippaDeliveryFlight {
    /// `.asked` is the accessible request: a button or action, not a shake.
    enum Kind: Equatable { case shake, exclamation, asked }
    var kind: Kind
    var startedAt: TimeInterval
    var origin: CGPoint
    var landing: CGPoint
    /// Where the card's thread hole comes to rest.
    var cardHole: CGPoint
    var room: CGSize
    var cardWidth: CGFloat
    /// How crooked it lies once it's down. A dropped scrap is never square.
    var restTilt: Double = 0

    static let duration = 2.4
    static let release = 0.76
    /// The hole, measured from the card's top-left corner.
    static let holeInset = CGSize(width: -30, height: 16)
    static let threadLength: CGFloat = 58

    func holeOffset() -> CGPoint {
        CGPoint(x: cardWidth + Self.holeInset.width, y: Self.holeInset.height)
    }

    func progress(at time: TimeInterval) -> Double {
        min(1, max(0, (time - startedAt) / Self.duration))
    }

    func fairy(at progress: Double, returningTo ambient: CGPoint) -> CGPoint {
        let below = CGPoint(x: origin.x, y: room.height + 38)
        let launch = CGPoint(x: room.width - 35, y: room.height + 25)
        let tow = CGPoint(x: cardHole.x + 6, y: cardHole.y - Self.threadLength)
        let release = CGPoint(x: tow.x + 14, y: tow.y - 18)
        if kind == .shake {
            if progress < 0.18 { return Self.mix(origin, below, progress / 0.18) }
            if progress < 0.30 { return Self.mix(below, launch, (progress - 0.18) / 0.12) }
            if progress < 0.60 { return Self.mix(launch, tow, (progress - 0.30) / 0.30) }
        } else if progress < 0.60 {
            return Self.mix(origin, tow, progress / 0.60)
        }
        if progress < Self.release { return Self.mix(tow, release, (progress - 0.60) / 0.16) }
        if progress < 0.90 { return Self.mix(release, landing, (progress - Self.release) / 0.14) }
        return Self.mix(landing, ambient, (progress - 0.90) / 0.10)
    }

    /// The hole's position. The card rises from wholly below the room.
    func card(at progress: Double) -> CGPoint {
        let below = CGPoint(x: room.width - 26, y: room.height + 40)
        let tow = CGPoint(x: cardHole.x + 6, y: cardHole.y + 10)
        let release = CGPoint(x: cardHole.x + 10, y: cardHole.y - 10)
        if progress < 0.30 { return below }
        if progress < 0.60 { return Self.mix(below, tow, (progress - 0.30) / 0.30) }
        if progress < Self.release { return Self.mix(tow, release, (progress - 0.60) / 0.16) }
        return Self.mix(release, cardHole, (progress - Self.release) / 0.24)
    }

    /// Swings on its thread while towed; let go, it rocks a few times and
    /// settles crooked.
    func tilt(at progress: Double) -> Double {
        let swing = { (p: Double) in sin(p * .pi * 3) * 0.10 }
        guard progress >= Self.release else { return swing(progress) }
        let u = (progress - Self.release) / (1 - Self.release)
        return restTilt + (swing(Self.release) - restTilt) * exp(-4 * u) * cos(2.5 * .pi * u)
    }

    static func mix(_ a: CGPoint, _ b: CGPoint, _ fraction: Double) -> CGPoint {
        let t = min(1, max(0, fraction))
        let eased = CGFloat(t * t * (3 - 2 * t))
        return CGPoint(x: a.x + (b.x - a.x) * eased, y: a.y + (b.y - a.y) * eased)
    }
}

/// The card is laid out where it comes to rest; this carries it there from
/// wherever the hole is in its flight and turns it about the hole. Laying it
/// out at rest keeps its touch area where the reader sees it.
///
/// `caughtUp` is how far her clock had already run when the card first
/// appeared. It isn't animated, so the card starts there at once and stays on
/// the end of her thread even when its first frame is late.
private struct PippaCardFlightEffect: GeometryEffect {
    var progress: Double
    var caughtUp: Double = 0
    let flight: PippaDeliveryFlight
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = caughtUp + self.progress * (1 - caughtUp)
        let point = flight.card(at: progress)
        let hole = flight.holeOffset()
        let transform = CGAffineTransform(translationX: point.x - flight.cardHole.x + hole.x,
                                          y: point.y - flight.cardHole.y + hole.y)
            .rotated(by: flight.tilt(at: progress))
            .translatedBy(x: -hole.x, y: -hole.y)
        return ProjectionTransform(transform)
    }
}

/// Flicked away: it drops, turns and is gone.
private struct PippaCardLeaveEffect: GeometryEffect {
    var amount: Double
    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let scale = 1 - 0.1 * amount
        let transform = CGAffineTransform(translationX: size.width / 2 + 26 * amount,
                                          y: size.height / 2 + 70 * amount * amount)
            .rotated(by: 0.22 * amount)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

/// Pippa's own red, the one on her signature stamp.
private let pippaRed = Color(red: 0.71, green: 0.22, blue: 0.18)

struct PippaMessageCard: View {
    let scrap: PippaScrap
    let flight: PippaDeliveryFlight
    let restsImmediately: Bool
    let isReleased: Bool
    let dismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var progress = 0.0
    @State private var caughtUp = 0.0
    @State private var leaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { words }
                    .frame(height: min(350, flight.room.height * 0.42))
            } else {
                words
            }
            signature
        }
        .padding(.leading, 38)
        .padding(.trailing, 24)
        .padding(.top, 30)
        .padding(.bottom, 18)
        .frame(width: flight.cardWidth, alignment: .leading)
        .background {
            PippaScrapPaper(seed: PippaScrapPaper.seed(scrap.id), hole: flight.holeOffset())
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: putAway)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A scrap from Pippa: \(scrap.line)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Puts the scrap away")
        .modifier(PippaCardLeaveEffect(amount: leaving ? 1 : 0))
        .opacity(leaving ? 0 : 1)
        .modifier(PippaCardFlightEffect(progress: restsImmediately ? 1 : progress, caughtUp: caughtUp, flight: flight))
        .offset(x: flight.cardHole.x - flight.holeOffset().x, y: flight.cardHole.y - flight.holeOffset().y)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting((isReleased || restsImmediately) && !leaving)
        .accessibilityHidden(!isReleased && !restsImmediately)
        .onAppear {
            guard !restsImmediately else { progress = 1; return }
            caughtUp = flight.progress(at: PixieFlight.clock(Date()))
            withAnimation(.linear(duration: PippaDeliveryFlight.duration * (1 - caughtUp))) { progress = 1 }
        }
    }

    /// The flick starts on the touch; the card is only removed once it's gone.
    private func putAway() {
        guard !leaving else { return }
        BookFeedback.play(.tap, sound: false)
        BookSoundBank.play(.drop)
        withAnimation(.easeIn(duration: 0.24)) { leaving = true } completion: { dismiss() }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scrap.line)
                .font(.custom("BradleyHandITCTT-Bold", size: 19, relativeTo: .body))
                .foregroundStyle(BookPalette.ink)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            if let ornament = scrap.ornament {
                Text(ornament)
                    .font(.system(.title3, design: .monospaced).weight(.heavy))
                    .foregroundStyle(pippaRed)
                    .rotationEffect(.degrees(-6))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var signature: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Spacer(minLength: 0)
            Text("Pippa")
                .font(.custom("BradleyHandITCTT-Bold", size: 15, relativeTo: .footnote))
            // Her interrobang, built from its two halves: the single glyph
            // turns into a plain question mark at this weight.
            ZStack {
                Text("?")
                Text("!").offset(x: 0.5)
            }
            .font(.custom("Baskerville-SemiBold", size: 22, relativeTo: .footnote))
        }
        .foregroundStyle(pippaRed)
        .rotationEffect(.degrees(-4))
        .accessibilityHidden(true)
    }
}

/// A scrap torn out of somebody's margin: ragged top and bottom with the pale
/// fibres showing, a red margin rule, a fold from her carrying it, foxing,
/// browned edges, and a punched hole with her bitten-off thread knotted in it.
/// Drawn once per card; the flight moves it without redrawing it.
struct PippaScrapPaper: View {
    var seed: UInt64
    var hole: CGPoint

    /// Stable across launches, so the same scrap always tears the same way.
    static func seed(_ id: String) -> UInt64 {
        id.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1.value)) &* 1_099_511_628_211 }
    }

    private static let bleed: CGFloat = 14
    private static let fibre = Color(red: 1.0, green: 0.985, blue: 0.94)
    private static let paperLight = Color(red: 0.985, green: 0.94, blue: 0.82)
    private static let paperDeep = Color(red: 0.945, green: 0.87, blue: 0.71)
    private static let brown = Color(red: 0.46, green: 0.29, blue: 0.13)
    private static let thread = Color(red: 0.20, green: 0.14, blue: 0.08)

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: Self.bleed, y: Self.bleed)
            let card = CGSize(width: size.width - Self.bleed * 2, height: size.height - Self.bleed * 2)
            let (fringe, body) = Self.tear(card, seed: seed)
            let punch = Path(ellipseIn: CGRect(x: hole.x - 3.4, y: hole.y - 3.4, width: 6.8, height: 6.8))
            var outer = fringe
            outer.addPath(punch)
            var inner = body
            inner.addPath(punch)

            var lifted = context
            lifted.addFilter(.shadow(color: .black.opacity(0.26), radius: 5, x: 1.5, y: 4))
            lifted.fill(outer, with: .color(Self.fibre), style: FillStyle(eoFill: true))
            context.fill(inner, with: .linearGradient(
                Gradient(colors: [Self.paperLight, Self.paperDeep]),
                startPoint: .zero, endPoint: CGPoint(x: card.width, y: card.height)
            ), style: FillStyle(eoFill: true))

            var paper = context
            paper.clip(to: inner, style: FillStyle(eoFill: true))
            var rng = SplitMix(seed: seed)
            // Browned where it was torn and handled.
            var toasted = paper
            toasted.addFilter(.blur(radius: 4))
            toasted.stroke(body, with: .color(Self.brown.opacity(0.20)), lineWidth: 7)
            // Foxing.
            for _ in 0..<3 {
                let r = CGFloat(rng.unit() * 9 + 5)
                let c = CGPoint(x: CGFloat(rng.unit()) * card.width, y: CGFloat(rng.unit()) * card.height)
                paper.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: .radialGradient(Gradient(colors: [Self.brown.opacity(0.10), .clear]),
                                                 center: c, startRadius: 0, endRadius: r))
            }
            // The margin rule of the page it came from.
            var rule = Path()
            rule.move(to: CGPoint(x: 24, y: 0))
            rule.addLine(to: CGPoint(x: 24.6, y: card.height))
            paper.stroke(rule, with: .color(pippaRed.opacity(0.42)), lineWidth: 1)
            // Folded once, to carry.
            let foldY = card.height * CGFloat(0.48 + rng.unit() * 0.12)
            let foldLean = CGFloat(rng.unit() * 8 - 4)
            var fold = Path()
            fold.move(to: CGPoint(x: 0, y: foldY - foldLean))
            fold.addLine(to: CGPoint(x: card.width, y: foldY + foldLean))
            paper.stroke(fold, with: .color(.white.opacity(0.55)), lineWidth: 1)
            paper.stroke(fold.offsetBy(dx: 0, dy: 1.2), with: .color(Self.brown.opacity(0.10)), lineWidth: 1.2)

            // Round the hole: a bruise in the paper, then her knot and the bitten end.
            context.stroke(Path(ellipseIn: CGRect(x: hole.x - 4.6, y: hole.y - 4.6, width: 9.2, height: 9.2)),
                           with: .color(Self.brown.opacity(0.28)), lineWidth: 1)
            var tail = Path()
            tail.move(to: CGPoint(x: hole.x + 1, y: hole.y - 3))
            tail.addQuadCurve(to: CGPoint(x: hole.x + 7, y: hole.y + 9),
                              control: CGPoint(x: hole.x + 10, y: hole.y - 2))
            tail.addQuadCurve(to: CGPoint(x: hole.x + 4, y: hole.y + 15),
                              control: CGPoint(x: hole.x + 4, y: hole.y + 12))
            context.stroke(tail, with: .color(Self.thread.opacity(0.6)), lineWidth: 0.8)
            context.fill(Path(ellipseIn: CGRect(x: hole.x - 0.4, y: hole.y - 4.6, width: 2.6, height: 2.6)),
                         with: .color(Self.thread.opacity(0.7)))
        }
        .padding(-Self.bleed)
        .allowsHitTesting(false)
    }

    /// The torn outline and, just inside it, the paper's body. The gap between
    /// them is the pale fibre a real tear leaves: wide on the torn top and
    /// bottom, a hair on the cut sides.
    static func tear(_ size: CGSize, seed: UInt64) -> (Path, Path) {
        var rng = SplitMix(seed: seed)
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        func add(_ point: CGPoint, inward: CGVector, fibre: ClosedRange<Double>) {
            outer.append(point)
            let depth = CGFloat(rng.unit() * (fibre.upperBound - fibre.lowerBound) + fibre.lowerBound)
            inner.append(CGPoint(x: point.x + inward.dx * depth, y: point.y + inward.dy * depth))
        }
        func torn(_ depth: Double) -> CGFloat {
            // Mostly a fine ragged line, sometimes a proper bite.
            CGFloat(rng.unit() * depth + (rng.unit() < 0.12 ? rng.unit() * 5 + 2 : 0))
        }
        var x: CGFloat = 0
        while x < size.width {
            add(CGPoint(x: x, y: torn(4)), inward: CGVector(dx: 0, dy: 1), fibre: 0.8...3.4)
            x += CGFloat(rng.unit() * 5 + 3.5)
        }
        var y: CGFloat = 0
        while y < size.height {
            add(CGPoint(x: size.width - CGFloat(rng.unit() * 1.6), y: y), inward: CGVector(dx: -1, dy: 0), fibre: 0.2...0.9)
            y += CGFloat(rng.unit() * 8 + 8)
        }
        x = size.width
        while x > 0 {
            add(CGPoint(x: x, y: size.height - torn(4.5)), inward: CGVector(dx: 0, dy: -1), fibre: 0.8...3.6)
            x -= CGFloat(rng.unit() * 5 + 3.5)
        }
        y = size.height
        while y > 0 {
            add(CGPoint(x: CGFloat(rng.unit() * 1.6), y: y), inward: CGVector(dx: 1, dy: 0), fibre: 0.2...0.9)
            y -= CGFloat(rng.unit() * 8 + 8)
        }
        func path(_ points: [CGPoint]) -> Path {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }
        return (path(outer), path(inner))
    }
}

/// A tiny seeded generator, so tears and spills are repeatable per seed.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<1
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// What falls out of her when she's poked: her pocketful of punctuation, and
/// now and then one of the reader's own words. It's a burst, not a message;
/// nothing here waits on the archive and it's gone in about a second.
struct PippaSpill: Identifiable {
    struct Piece {
        var text: String
        var isWord: Bool
        var velocity: CGVector
        var spin: Double
        var size: CGFloat
    }

    var id: TimeInterval
    var origin: CGPoint
    var pieces: [Piece]
    /// What she shouts as she goes, if anything, and where: kept on screen
    /// even when she was sitting at the edge.
    var protest: String?
    var protestOrigin: CGPoint

    /// Louder each time she's poked before she's calmed down.
    static let protests: [[String]] = [
        ["Eep!", "Oi!", "Hey!", "Eek!"],
        ["Rude!", "I’m WORKING.", "Hands!", "Do you MIND‽"],
        ["Fine! Have them ALL!", "I’m telling Mook.", "Pockets EMPTY. Happy?"]
    ]

    static let duration = 1.25
    private static let marks = ["!", "?", ",", ";", "\u{2026}", "\u{203D}", ":", "\u{2014}", "\u{00B6}", "\u{201C}", "("]

    /// `fury` 0, 1, 2: first poke, second, and the one that empties her pockets.
    static func make(id: TimeInterval, origin: CGPoint, fury: Int, word: String?, protest: String?,
                     room: CGSize) -> PippaSpill {
        var rng = SplitMix(seed: UInt64(bitPattern: Int64(id * 1000)))
        let count = [6, 8, 14][min(2, fury)]
        var pieces: [Piece] = (0..<count).map { _ in
            Piece(text: marks[Int(rng.unit() * Double(marks.count)) % marks.count], isWord: false,
                  velocity: CGVector(dx: rng.unit() * 220 - 110, dy: -(rng.unit() * 170 + 70)),
                  spin: rng.unit() * 900 - 450, size: CGFloat(rng.unit() * 10 + 15))
        }
        if let word {
            pieces.append(Piece(text: word, isWord: true,
                                velocity: CGVector(dx: rng.unit() * 80 - 40, dy: -(rng.unit() * 60 + 150)),
                                spin: rng.unit() * 160 - 80, size: 17))
        }
        let protestOrigin = CGPoint(x: min(max(origin.x, 120), room.width - 120), y: max(origin.y, 90))
        return PippaSpill(id: id, origin: origin, pieces: pieces, protest: protest, protestOrigin: protestOrigin)
    }
}

struct PippaSpillView: View {
    let spill: PippaSpill
    @State private var progress = 0.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(spill.pieces.indices, id: \.self) { index in
                let piece = spill.pieces[index]
                Text(piece.text)
                    .font(piece.isWord
                          ? .custom("BradleyHandITCTT-Bold", fixedSize: piece.size)
                          : .system(size: piece.size, weight: .heavy, design: .serif))
                    // Red, gold and ink: gold and red still read when they
                    // tumble off the paper into the dark room.
                    .foregroundStyle(piece.isWord ? BookPalette.ink
                                     : [pippaRed, BookPalette.lampGold, BookPalette.ink][index % 3])
                    .fixedSize()
                    .modifier(PippaFallingPiece(progress: progress, piece: piece, origin: spill.origin))
            }
            if let protest = spill.protest {
                Text(protest)
                    .font(.custom("BradleyHandITCTT-Bold", fixedSize: 22))
                    .foregroundStyle(pippaRed)
                    .shadow(color: BookPalette.page.opacity(0.9), radius: 2)
                    .multilineTextAlignment(.center)
                    .frame(width: 240)
                    .modifier(PippaProtest(progress: progress, origin: spill.protestOrigin))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            withAnimation(.linear(duration: PippaSpill.duration)) { progress = 1 }
        }
    }
}

/// Thrown up, then gravity. Only transform and opacity move, so no text is
/// laid out again while it falls.
private struct PippaFallingPiece: ViewModifier, Animatable {
    var progress: Double
    let piece: PippaSpill.Piece
    let origin: CGPoint
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress * PippaSpill.duration
        let gravity = piece.isWord ? 520.0 : 760.0
        let x = origin.x + piece.velocity.dx * t
        let y = origin.y + piece.velocity.dy * t + 0.5 * gravity * t * t
        let pop = min(1, progress / 0.08)
        return content
            .scaleEffect(0.4 + 0.6 * pop)
            .rotationEffect(.degrees(piece.spin * t))
            .opacity(progress < 0.55 ? 1 : max(0, 1 - (progress - 0.55) / 0.45))
            .offset(x: x - piece.size * 0.3, y: y - piece.size * 0.6)
    }
}

/// Her parting shout: up and out, quickly.
private struct PippaProtest: ViewModifier, Animatable {
    var progress: Double
    let origin: CGPoint
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let rise = 1 - pow(1 - min(1, progress / 0.5), 3)
        return content
            .scaleEffect(0.6 + 0.4 * min(1, progress / 0.12))
            .rotationEffect(.degrees(-8))
            .opacity(progress < 0.6 ? 1 : max(0, 1 - (progress - 0.6) / 0.4))
            .offset(x: origin.x - 120, y: origin.y - 52 - 34 * rise)
    }
}

/// A passive UIKit shake receiver. It claims an otherwise idle responder slot,
/// never an editor's focus, and uses no accelerometer stream or polling timer.
struct PippaShakeReceiver: UIViewRepresentable {
    var isEnabled: Bool
    var onShake: () -> Void

    func makeUIView(context: Context) -> Receiver {
        let view = Receiver()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: Receiver, context: Context) {
        view.onShake = onShake
        view.enabled = isEnabled
        view.updateFocusSoon()
    }

    static func dismantleUIView(_ view: Receiver, coordinator: ()) {
        view.enabled = false
        view.onShake = nil
        view.resignFirstResponder()
    }

    final class Receiver: UIView {
        var enabled = false
        var onShake: (() -> Void)?
        override var canBecomeFirstResponder: Bool { enabled }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateFocusSoon()
        }

        func updateFocusSoon() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.enabled, self.window?.isKeyWindow == true else {
                    if self.isFirstResponder { self.resignFirstResponder() }
                    return
                }
                // Do not dismiss typing, dictation or a hardware-keyboard
                // editor when SwiftUI updates the surrounding Book.
                guard !UIApplication.shared.reenchantedHasFocusedTextInput() else { return }
                if !self.isFirstResponder { self.becomeFirstResponder() }
            }
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake, enabled,
                  !UIApplication.shared.reenchantedHasFocusedTextInput() else {
                super.motionEnded(motion, with: event)
                return
            }
            onShake?()
        }
    }
}
