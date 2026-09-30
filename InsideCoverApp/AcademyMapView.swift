import SwiftUI

/// The Book's map of the Labyrinth and the Academy inside it, as it sits on
/// the leaf: a small copy of the whole thing. Touching it opens the map out
/// to the whole screen, where it can be pinched and dragged about.
///
/// Drawn like a plan in ink: walls, shelving, stairs, hedges, and footprints
/// where the Cast are standing right now, each with a name on a ribbon. Only
/// as far as the Book has been, though. A room nobody's been to is blank
/// paper, and a path towards it stops about halfway, where the Book stopped
/// knowing. The layout comes from `AcademyGeography`; what's drawn, and who's
/// where, from `AcademyCartographer`.
struct AcademyMapView: View {
    /// Everything but the time. The map works out who's where again every
    /// minute, so people walk off while it's being looked at.
    let inputs: AcademyChartInputs
    /// A kept Page the reader touched in a room's note.
    var onOpenPage: (BookPage) -> Void = { _ in }
    /// A Cast member the reader touched, on the map or in a note, by entity id.
    var onOpenCastMember: (String) -> Void = { _ in }

    @State private var isOpen = false

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            leaf(AcademyCartographer.chart(inputs.at(timeline.date)), clock: timeline.date)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isOpen) {
            AcademyMapViewer(inputs: inputs, onOpenPage: onOpenPage, onOpenCastMember: onOpenCastMember)
        }
        #endif
    }

    private func leaf(_ chart: AcademyChart, clock: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                let zoom = proxy.size.width / AcademyMapDrawing.size.width
                AcademyMapDrawing(chart: chart, selectedID: .constant(nil), isInteractive: false, clock: clock)
                    .scaleEffect(zoom, anchor: .topLeading)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .aspectRatio(AcademyMapDrawing.size.width / AcademyMapDrawing.size.height, contentMode: .fit)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                BookFeedback.play(.openPage, fill: true)
                isOpen = true
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("A map of the Labyrinth")
            .accessibilityHint("Opens the map out")
            .accessibilityAddTraits(.isButton)

            Text("Touch the map and I'll open it out.")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text(chart.footer)
                if let unseen = chart.unseenLine {
                    Text(unseen)
                }
            }
            .font(.system(size: 12, design: .serif))
            .italic()
            .foregroundStyle(BookPalette.ink.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Opened out

/// The map across the whole screen. It opens a little closer than the whole
/// thing, on the Great Hall, and from there it pinches and drags like paper
/// under a glass.
///
/// The drawing is laid out once at its own size and looked at through a
/// camera, so it stays sharp at any zoom and only ever paints what's on the
/// screen.
struct AcademyMapViewer: View {
    let inputs: AcademyChartInputs
    var onOpenPage: (BookPage) -> Void = { _ in }
    var onOpenCastMember: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?
    /// Screen points per drawing point, and where the drawing's top-left
    /// corner sits on the screen. Nil until the screen's been measured.
    @State private var camera: Camera?
    @State private var settled: Camera?

    struct Camera: Equatable {
        var zoom: CGFloat
        var origin: CGPoint
    }

    /// How much closer than "the whole width" the map opens.
    static let openingZoom: CGFloat = 1.6
    static let deepestZoom: CGFloat = 4

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            glass(AcademyCartographer.chart(inputs.at(timeline.date)))
        }
    }

    private func glass(_ chart: AcademyChart) -> some View {
        GeometryReader { proxy in
            let viewport = proxy.size
            let current = camera ?? Self.opening(in: viewport)
            ZStack(alignment: .topLeading) {
                AcademyMapDrawing.paper.ignoresSafeArea()

                AcademyMapDrawing(
                    chart: chart,
                    selectedID: $selectedID,
                    isInteractive: true,
                    animates: true,
                    onOpenCastMember: { id in leave { onOpenCastMember(id) } }
                )
                .scaleEffect(current.zoom, anchor: .topLeading)
                .offset(x: current.origin.x, y: current.origin.y)
                .frame(width: viewport.width, height: viewport.height, alignment: .topLeading)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(pan(viewport: viewport))
                .simultaneousGesture(pinch(viewport: viewport))
                .onTapGesture(count: 2) { location in
                    zoomToggle(at: location, viewport: viewport)
                }

                closeMark
                    .padding(.leading, 16)
                    .padding(.top, 8)

                if let id = selectedID, let room = chart.room(id), room.isDrawn {
                    VStack {
                        Spacer()
                        ScrollView {
                            AcademyRoomNote(
                                room: room,
                                chart: chart,
                                onOpenPage: { page in leave { onOpenPage(page) } },
                                onOpenCastMember: { id in leave { onOpenCastMember(id) } }
                            )
                        }
                        .frame(maxHeight: viewport.height * 0.42)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AcademyMapDrawing.paper)
                                .shadow(color: .black.opacity(0.18), radius: 10, y: 2)
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: selectedID)
        }
    }

    private var closeMark: some View {
        Button {
            BookFeedback.play(.tap)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Circle().fill(AcademyMapDrawing.paper))
                .overlay(Circle().stroke(BookPalette.ink.opacity(0.4), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close the map")
    }

    /// Close the map first, then go wherever the reader was going. A Page or a
    /// Cast member opens in the Book underneath, not on top of the map.
    private func leave(then go: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: go)
    }

    // MARK: Camera

    static func fitZoom(in viewport: CGSize) -> CGFloat {
        min(viewport.width / AcademyMapDrawing.size.width, viewport.height / AcademyMapDrawing.size.height * 1.4)
    }

    static func opening(in viewport: CGSize) -> Camera {
        let zoom = fitZoom(in: viewport) * openingZoom
        let hall = AcademyGeography.room(id: "location-great-hall").map { AcademyMapDrawing.point($0.point) }
            ?? CGPoint(x: AcademyMapDrawing.size.width / 2, y: AcademyMapDrawing.size.height / 2)
        return clamped(Camera(
            zoom: zoom,
            origin: CGPoint(x: viewport.width / 2 - hall.x * zoom, y: viewport.height / 2 - hall.y * zoom)
        ), in: viewport)
    }

    /// Keep the paper on the screen: no dragging the whole map off into the
    /// dark, and a map smaller than the screen sits in the middle of it.
    static func clamped(_ camera: Camera, in viewport: CGSize) -> Camera {
        var camera = camera
        let fit = fitZoom(in: viewport)
        camera.zoom = min(max(camera.zoom, fit * 0.9), fit * deepestZoom)
        let content = CGSize(
            width: AcademyMapDrawing.size.width * camera.zoom,
            height: AcademyMapDrawing.size.height * camera.zoom
        )
        func axis(_ origin: CGFloat, content: CGFloat, view: CGFloat) -> CGFloat {
            content <= view ? (view - content) / 2 : min(0, max(view - content, origin))
        }
        camera.origin.x = axis(camera.origin.x, content: content.width, view: viewport.width)
        camera.origin.y = axis(camera.origin.y, content: content.height, view: viewport.height)
        return camera
    }

    private func pan(viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = settled ?? camera ?? Self.opening(in: viewport)
                if settled == nil { settled = start }
                var moved = start
                moved.origin.x += value.translation.width
                moved.origin.y += value.translation.height
                camera = Self.clamped(moved, in: viewport)
            }
            .onEnded { _ in settled = nil }
    }

    private func pinch(viewport: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = settled ?? camera ?? Self.opening(in: viewport)
                if settled == nil { settled = start }
                // Keep the bit of paper under the fingers under the fingers.
                let anchor = value.startLocation
                let drawingPoint = CGPoint(
                    x: (anchor.x - start.origin.x) / start.zoom,
                    y: (anchor.y - start.origin.y) / start.zoom
                )
                let fit = Self.fitZoom(in: viewport)
                let zoom = min(max(start.zoom * value.magnification, fit * 0.9), fit * Self.deepestZoom)
                camera = Self.clamped(Camera(
                    zoom: zoom,
                    origin: CGPoint(x: anchor.x - drawingPoint.x * zoom, y: anchor.y - drawingPoint.y * zoom)
                ), in: viewport)
            }
            .onEnded { _ in settled = nil }
    }

    /// Double tap: in closer where the finger is, or back out if it's
    /// already close.
    private func zoomToggle(at location: CGPoint, viewport: CGSize) {
        let current = camera ?? Self.opening(in: viewport)
        let fit = Self.fitZoom(in: viewport)
        let target = current.zoom > fit * 2.2 ? fit * Self.openingZoom : fit * 3
        let drawingPoint = CGPoint(
            x: (location.x - current.origin.x) / current.zoom,
            y: (location.y - current.origin.y) / current.zoom
        )
        withAnimation(.easeInOut(duration: 0.28)) {
            camera = Self.clamped(Camera(
                zoom: target,
                origin: CGPoint(x: location.x - drawingPoint.x * target, y: location.y - drawingPoint.y * target)
            ), in: viewport)
        }
    }
}

// MARK: - A room's note

/// What the Book knows about one room: its note, who's in it, the way out,
/// and the Pages it's written about it.
struct AcademyRoomNote: View {
    let room: AcademyChartRoom
    let chart: AcademyChart
    var onOpenPage: (BookPage) -> Void = { _ in }
    var onOpenCastMember: (String) -> Void = { _ in }

    private var ink: Color { BookPalette.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(room.room.name)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(ink.opacity(0.92))
            ForEach(Array(room.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !room.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(room.people, id: \.characterID) { person in
                            Button {
                                BookFeedback.play(.tap)
                                onOpenCastMember(person.characterID)
                            } label: {
                                VStack(spacing: 4) {
                                    CharacterPortraitView(name: person.name, size: 40)
                                    Text(person.mapName)
                                        .font(.system(size: 11, weight: .semibold, design: .serif))
                                        .foregroundStyle(ink.opacity(0.82))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(person.name)
                            .accessibilityHint("Opens their page")
                        }
                    }
                }
            }
            if let ways = chart.waysOut(from: room.id) {
                Text(ways)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.parchmentEdge)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !room.pages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Where I've written about it:")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(ink.opacity(0.7))
                    ForEach(room.pages) { page in
                        Button {
                            onOpenPage(page)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 10))
                                Text("\(page.type.title), \(Self.pageDate.string(from: page.createdAt))")
                                    .font(.system(size: 13, design: .serif))
                                    .underline(color: ink.opacity(0.3))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(LeafInk.gold)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    private static let pageDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()
}

// MARK: - The drawing

/// The whole map, laid out at its own fixed size in drawing points. Whoever
/// shows it scales it: small on the leaf, large under the viewer's glass.
struct AcademyMapDrawing: View {
    let chart: AcademyChart
    @Binding var selectedID: String?
    /// False on the leaf, where the whole map is one thing to touch.
    var isInteractive: Bool = true
    /// Footprints walk and pace only when this is on, and Reduce Motion isn't.
    var animates: Bool = false
    /// The moment the chart was worked out for. A still map is drawn as of now.
    var clock: Date = Date()
    var onOpenCastMember: (String) -> Void = { _ in }

    static let size = CGSize(width: 520, height: 788)
    /// Rooms out of other books are drawn in someone else's ink.
    static let borrowedInk = Color(red: 0.55, green: 0.22, blue: 0.14)
    static let paper = Color(red: 0.95, green: 0.91, blue: 0.82)
    private var ink: Color { BookPalette.ink }

    /// A point on the chart, in drawing points.
    static func point(_ p: AcademyMapPoint) -> CGPoint {
        CGPoint(x: size.width * (0.04 + CGFloat(p.x) * 0.92), y: size.height * (0.03 + CGFloat(p.y) * 0.88))
    }

    var body: some View {
        let plan = Plan(size: Self.size, chart: chart)
        ZStack(alignment: .topLeading) {
            Self.paper
            Canvas { context, _ in
                drawFrame(in: &context, plan: plan)
                drawStacks(in: &context, plan: plan)
                drawPassages(in: &context, plan: plan)
                drawRooms(in: &context, plan: plan)
                drawCompassRose(in: &context, plan: plan)
            }
            ForEach(chart.rooms.filter(\.isDrawn)) { room in
                roomTarget(room, plan: plan)
            }
            AcademyFootprintLayer(
                walkers: plan.walkers,
                animates: animates,
                clock: clock,
                isInteractive: isInteractive,
                onOpenCastMember: onOpenCastMember
            )
            ForEach(plan.crowds, id: \.id) { crowd in
                Text("+\(crowd.more)")
                    .font(.system(size: 7, weight: .bold, design: .serif))
                    .foregroundStyle(ink.opacity(0.75))
                    .padding(.horizontal, 3)
                    .background(Capsule().fill(Self.paper))
                    .overlay(Capsule().stroke(ink.opacity(0.5), lineWidth: 0.5))
                    .position(x: crowd.at.x, y: crowd.at.y + 13)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            titleCartouche(plan: plan)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .allowsHitTesting(isInteractive)
    }

    // MARK: - Layout

    /// Everything the drawing and the touch targets agree on, worked out once
    /// per size.
    struct Plan {
        let size: CGSize
        let rooms: [String: AcademyChartRoom]
        private(set) var walkers: [Walker] = []
        /// "+12" beside a room with more people in it than it can show.
        private(set) var crowds: [(id: String, at: CGPoint, more: Int)] = []

        init(size: CGSize, chart: AcademyChart) {
            self.size = size
            self.rooms = Dictionary(uniqueKeysWithValues: chart.rooms.map { ($0.id, $0) })
            var walkers: [Walker] = []
            var crowds: [(id: String, at: CGPoint, more: Int)] = []
            for room in chart.rooms where room.isDrawn && !room.people.isEmpty {
                let box = Plan.box(of: room, in: size)
                let isRing = room.room.form == .ring
                let shownCount = min(room.people.count, AcademyMapDrawing.walkersPerRoom)
                let spacing = min(38, (isRing ? 120 : box.width) / CGFloat(max(1, shownCount)))
                // In the Stacks, people are somewhere along the top shelves,
                // off to one side of the name plate.
                let anchor = isRing
                    ? CGPoint(x: box.minX + box.width * 0.72, y: box.minY + 4)
                    : CGPoint(x: box.midX, y: box.midY + max(5, box.height * 0.16))
                for (index, person) in room.people.enumerated() {
                    let isShown = index < shownCount
                    let offset = (CGFloat(index) - CGFloat(shownCount - 1) / 2) * spacing
                    let slot = isShown ? CGPoint(x: anchor.x + offset, y: anchor.y) : CGPoint(x: box.midX, y: box.midY)
                    let arrival = chart.arrivals[person.characterID]
                    // Somebody past the crowd limit is only drawn while they
                    // walk in; once they're here they're part of the "+N".
                    guard isShown || arrival != nil else { continue }
                    walkers.append(Walker(
                        person: person,
                        at: slot,
                        heading: Angle.degrees(Double(abs(person.characterID.stableHash) % 70) - 35),
                        motion: AcademyMotion.of(person),
                        pacingReach: isRing ? 18 : min(box.width * 0.28, 18),
                        // Neighbours too close for two ribbons side by side
                        // take turns: every other name drops a line.
                        ribbonDrop: spacing < 46 && index % 2 == 1 ? 11 : 0,
                        isShownAtRest: isShown,
                        walk: arrival.flatMap { walk(from: $0, to: room.id, endingAt: slot, chart: chart) }
                    ))
                }
                if room.people.count > shownCount {
                    // Under the row of names, where nothing else is written.
                    crowds.append((room.id, CGPoint(x: anchor.x, y: anchor.y + (spacing < 46 ? 24 : 14)),
                                   room.people.count - shownCount))
                }
            }
            // Walking off the edge of what the Book knows: drawn as far as
            // the paper goes, then gone.
            for person in chart.unseen {
                guard let arrival = chart.arrivals[person.characterID],
                      let walk = walk(from: arrival, to: person.roomID, endingAt: nil, chart: chart) else { continue }
                walkers.append(Walker(
                    person: person, at: walk.points.last ?? .zero, heading: .zero, motion: .stationary,
                    pacingReach: 0, ribbonDrop: 0, isShownAtRest: false, walk: walk
                ))
            }
            self.walkers = walkers
            self.crowds = crowds
        }

        /// The way somebody walks, as points on the drawing: through the rooms
        /// between, and only over paper the Book's drawn. Coming out of the
        /// blank, they appear partway along; going into it, they fade out
        /// partway along.
        func walk(from arrival: AcademyArrival, to goal: String, endingAt slot: CGPoint?, chart: AcademyChart) -> Walk? {
            guard let ids = AcademyRoute.rooms(from: arrival.fromRoomID, to: goal,
                                               passages: chart.allPassages, avoiding: chart.closedRoomIDs),
                  ids.count > 1 else { return nil }
            let drawn = ids.map { rooms[$0]?.isDrawn ?? false }
            var points: [CGPoint] = []
            func centre(_ id: String) -> CGPoint? {
                guard let room = rooms[id] else { return nil }
                let box = box(of: room)
                if room.room.form == .ring {
                    return ringLanding(from: points.last ?? CGPoint(x: size.width / 2, y: size.height / 2), ring: box)
                }
                return CGPoint(x: box.midX, y: box.midY)
            }
            func between(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
                CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            if drawn.last == true {
                let first = (drawn.lastIndex(of: false) ?? -1) + 1
                for id in ids[first...] { if let point = centre(id) { points.append(point) } }
                if first > 0, let blank = centre(ids[first - 1]), let entry = points.first {
                    points.insert(between(entry, blank, 0.45), at: 0)
                }
                if let slot { points[points.count - 1] = slot }
            } else if drawn.first == true, let edge = drawn.firstIndex(of: false) {
                for id in ids[..<edge] { if let point = centre(id) { points.append(point) } }
                if let last = points.last, let blank = centre(ids[edge]) {
                    points.append(between(last, blank, 0.45))
                }
            } else {
                return nil
            }
            guard points.count > 1 else { return nil }
            return Walk(points: points, startedAt: arrival.startedAt, duration: AcademyMotion.walkSeconds)
        }

        func box(of room: AcademyChartRoom) -> CGRect { Plan.box(of: room, in: size) }

        static func box(of room: AcademyChartRoom, in size: CGSize) -> CGRect {
            let centre = CGPoint(
                x: size.width * (0.04 + CGFloat(room.point.x) * 0.92),
                y: size.height * (0.03 + CGFloat(room.point.y) * 0.88)
            )
            let w = size.width * 0.92 * CGFloat(room.room.size.x)
            let h = size.height * 0.88 * CGFloat(room.room.size.y)
            return CGRect(x: centre.x - w / 2, y: centre.y - h / 2, width: w, height: h)
        }

        /// Where a path leaves a room on its way to `toward`.
        func exit(from room: AcademyChartRoom, toward target: CGPoint) -> CGPoint {
            let box = box(of: room)
            if room.room.form == .ring { return ringLanding(from: target, ring: box) }
            let centre = CGPoint(x: box.midX, y: box.midY)
            let dx = target.x - centre.x, dy = target.y - centre.y
            guard dx != 0 || dy != 0 else { return centre }
            if room.room.form == .tower {
                let r = min(box.width, box.height) / 2
                let length = (dx * dx + dy * dy).squareRoot()
                return CGPoint(x: centre.x + dx / length * r, y: centre.y + dy / length * r)
            }
            let tx = dx == 0 ? CGFloat.infinity : (box.width / 2) / abs(dx)
            let ty = dy == 0 ? CGFloat.infinity : (box.height / 2) / abs(dy)
            let t = min(tx, ty)
            return CGPoint(x: centre.x + dx * t, y: centre.y + dy * t)
        }

        /// A way to the Stacks runs to the nearest wall of shelving, not to
        /// the middle of the school.
        func ringLanding(from q: CGPoint, ring outer: CGRect) -> CGPoint {
            let inner = outer.insetBy(dx: AcademyMapDrawing.ringBand, dy: AcademyMapDrawing.ringBand)
            if inner.contains(q) {
                let sides: [(CGFloat, CGPoint)] = [
                    (q.x - inner.minX, CGPoint(x: inner.minX, y: q.y)),
                    (inner.maxX - q.x, CGPoint(x: inner.maxX, y: q.y)),
                    (q.y - inner.minY, CGPoint(x: q.x, y: inner.minY)),
                    (inner.maxY - q.y, CGPoint(x: q.x, y: inner.maxY))
                ]
                return sides.min { $0.0 < $1.0 }!.1
            }
            return CGPoint(
                x: min(max(q.x, outer.minX), outer.maxX),
                y: min(max(q.y, outer.minY), outer.maxY)
            )
        }
    }

    struct Walker: Identifiable {
        let person: AcademyWhereabout
        /// Where they stand once they've got here.
        let at: CGPoint
        let heading: Angle
        let motion: AcademyMotion
        /// How far either side of `at` they pace.
        let pacingReach: CGFloat
        /// How far below the usual line their name sits, so it doesn't sit
        /// on top of a neighbour's.
        let ribbonDrop: CGFloat
        /// False for someone who's part of a crowd's "+N" once they arrive.
        let isShownAtRest: Bool
        /// Set while they're on their way here.
        let walk: Walk?
        var id: String { person.characterID }
    }

    struct Walk {
        let points: [CGPoint]
        let startedAt: Date
        let duration: TimeInterval

        var length: CGFloat {
            zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
        }

        /// How far along they are at `time`, 0 to 1, easing in and out like
        /// somebody who stops and starts. Nil once they've arrived.
        func progress(at time: Date) -> CGFloat? {
            let raw = time.timeIntervalSince(startedAt) / duration
            guard raw < 1 else { return nil }
            let t = CGFloat(max(0, raw))
            return t * t * (3 - 2 * t)
        }

        /// The point `distance` along the way, and which way they're facing.
        func point(at distance: CGFloat) -> (CGPoint, Angle) {
            var remaining = max(0, distance)
            for (a, b) in zip(points, points.dropFirst()) {
                let segment = hypot(b.x - a.x, b.y - a.y)
                let facing = Angle.radians(Double(atan2(b.y - a.y, b.x - a.x)) + .pi / 2)
                if remaining <= segment || b == points.last {
                    let t = segment > 0 ? min(1, remaining / segment) : 1
                    return (CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), facing)
                }
                remaining -= segment
            }
            return (points.last ?? .zero, .zero)
        }
    }

    static let walkersPerRoom = 3
    static let ringBand: CGFloat = 9

    // MARK: - Touch

    private func roomTarget(_ room: AcademyChartRoom, plan: Plan) -> some View {
        let isSelected = room.id == selectedID
        let box = plan.box(of: room)
        let isRing = room.room.form == .ring
        // The Stacks are touched by their name plate on the top shelf; the
        // rest of the ring is too thin to aim at and too big to cover.
        let target = isRing
            ? CGRect(x: box.midX - 50, y: box.minY - 6, width: 100, height: 20)
            : box.insetBy(dx: -4, dy: -4)
        let fits = !isRing && box.height >= 26 && room.room.form != .corridor
        return ZStack {
            if !isRing {
                Text(room.room.mapLabel.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .serif))
                    .tracking(0.6)
                    .italic(room.room.zone == .labyrinth)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? LeafInk.gold : ink.opacity(0.84))
                    .frame(width: max(box.width - 6, 84))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .background(fits ? Color.clear : Self.paper.opacity(0.78))
                    .position(
                        x: box.midX,
                        // Inside when it fits. A corridor wears its name above
                        // it, and anything else too small wears it underneath.
                        y: fits ? box.minY + min(13, box.height * 0.34)
                            : room.room.form == .corridor ? box.minY - 9 : box.maxY + 10
                    )
                    .allowsHitTesting(false)
            }
            Button {
                BookFeedback.play(.tap)
                withAnimation(.easeOut(duration: 0.18)) {
                    selectedID = isSelected ? nil : room.id
                }
            } label: {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: target.width, height: target.height)
            .position(x: target.midX, y: target.midY)
            .accessibilityLabel(room.room.name)
            .accessibilityHint(room.lines.first ?? "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func titleCartouche(plan: Plan) -> some View {
        VStack(spacing: 1) {
            Text("THE LABYRINTH")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .tracking(2.4)
            Text("drawn by me, as far as I've got")
                .font(.system(size: 8, design: .serif))
                .italic()
        }
        .foregroundStyle(ink.opacity(0.78))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(RibbonShape().fill(Self.paper))
        .overlay(RibbonShape().stroke(ink.opacity(0.55), lineWidth: 0.8))
        .position(x: plan.size.width / 2, y: plan.size.height * 0.955)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Ink

    private func drawFrame(in context: inout GraphicsContext, plan: Plan) {
        let rect = CGRect(origin: .zero, size: plan.size).insetBy(dx: 1, dy: 1)
        // Old paper darkens at its edges first.
        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [ink.opacity(0), ink.opacity(0.07)]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: min(rect.width, rect.height) * 0.35,
                endRadius: max(rect.width, rect.height) * 0.72
            )
        )
        context.stroke(Path(rect), with: .color(ink.opacity(0.55)), lineWidth: 1.2)
        context.stroke(Path(rect.insetBy(dx: 3.5, dy: 3.5)), with: .color(ink.opacity(0.35)), lineWidth: 0.5)
    }

    /// The Stacks: a band of shelving all the way round the school, with its
    /// bays ruled across it.
    private func drawStacks(in context: inout GraphicsContext, plan: Plan) {
        guard let stacks = plan.rooms["location-stacks"], stacks.isDrawn else { return }
        let outer = plan.box(of: stacks)
        let inner = outer.insetBy(dx: Self.ringBand, dy: Self.ringBand)
        let colour = stacks.id == selectedID ? LeafInk.gold : ink
        context.stroke(Path(roundedRect: outer, cornerRadius: 14), with: .color(colour.opacity(0.7)), lineWidth: 1.3)
        context.stroke(Path(roundedRect: inner, cornerRadius: 8), with: .color(colour.opacity(0.7)), lineWidth: 0.9)

        var bays = Path()
        let step: CGFloat = 6
        var x = outer.minX + 14
        while x < outer.maxX - 14 {
            bays.move(to: CGPoint(x: x, y: outer.minY)); bays.addLine(to: CGPoint(x: x, y: inner.minY))
            bays.move(to: CGPoint(x: x, y: inner.maxY)); bays.addLine(to: CGPoint(x: x, y: outer.maxY))
            x += step
        }
        var y = outer.minY + 14
        while y < outer.maxY - 14 {
            bays.move(to: CGPoint(x: outer.minX, y: y)); bays.addLine(to: CGPoint(x: inner.minX, y: y))
            bays.move(to: CGPoint(x: inner.maxX, y: y)); bays.addLine(to: CGPoint(x: outer.maxX, y: y))
            y += step
        }
        context.stroke(bays, with: .color(colour.opacity(0.28)), lineWidth: 0.5)

        // Its name, on a plate on the top shelf.
        let label = context.resolve(
            Text("THE STACKS")
                .font(.system(size: 8, weight: .bold, design: .serif))
                .tracking(1.4)
                .italic()
                .foregroundColor(colour.opacity(0.85))
        )
        let labelSize = label.measure(in: CGSize(width: 200, height: 20))
        let plate = CGRect(
            x: outer.midX - labelSize.width / 2 - 6, y: outer.minY - 1,
            width: labelSize.width + 12, height: Self.ringBand + 2
        )
        context.fill(Path(plate), with: .color(Self.paper))
        context.stroke(Path(plate), with: .color(colour.opacity(0.5)), lineWidth: 0.6)
        context.draw(label, at: CGPoint(x: plate.midX, y: plate.midY))
    }

    private func drawPassages(in context: inout GraphicsContext, plan: Plan) {
        for passage in chart.passages {
            guard let a = plan.rooms[passage.from], let b = plan.rooms[passage.to] else { continue }
            let (from, to) = a.isDrawn ? (a, b) : (b, a)
            let known = from.isDrawn && to.isDrawn
            let fromBox = plan.box(of: from), toBox = plan.box(of: to)
            let fromCentre = CGPoint(x: fromBox.midX, y: fromBox.midY)
            var start: CGPoint
            var end: CGPoint
            if to.room.form == .ring {
                end = plan.ringLanding(from: fromCentre, ring: toBox)
                start = plan.exit(from: from, toward: end)
            } else if from.room.form == .ring {
                let toCentre = CGPoint(x: toBox.midX, y: toBox.midY)
                start = plan.ringLanding(from: toCentre, ring: fromBox)
                end = plan.exit(from: to, toward: start)
            } else {
                let toCentre = CGPoint(x: toBox.midX, y: toBox.midY)
                start = plan.exit(from: from, toward: toCentre)
                end = plan.exit(from: to, toward: fromCentre)
            }
            if !known {
                // The Book walked about halfway and then stopped knowing.
                end = CGPoint(x: start.x + (end.x - start.x) * 0.45, y: start.y + (end.y - start.y) * 0.45)
                var stub = Path()
                stub.move(to: start)
                stub.addLine(to: end)
                context.stroke(stub, with: .color(ink.opacity(0.3)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [2, 3]))
                context.fill(Path(ellipseIn: CGRect(x: end.x - 1.2, y: end.y - 1.2, width: 2.4, height: 2.4)), with: .color(ink.opacity(0.3)))
                continue
            }
            drawPassage(passage.kind, from: start, to: end, in: &context)
        }
    }

    private func drawPassage(_ kind: AcademyPassageKind, from start: CGPoint, to end: CGPoint, in context: inout GraphicsContext) {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        // A unit step along the way, and one across it.
        let along = CGPoint(x: dx / length, y: dy / length)
        let across = CGPoint(x: -along.y, y: along.x)
        func offset(_ p: CGPoint, _ d: CGFloat) -> CGPoint { CGPoint(x: p.x + across.x * d, y: p.y + across.y * d) }
        func rails(_ half: CGFloat) -> Path {
            var path = Path()
            path.move(to: offset(start, half)); path.addLine(to: offset(end, half))
            path.move(to: offset(start, -half)); path.addLine(to: offset(end, -half))
            return path
        }
        func rungs(_ half: CGFloat, every step: CGFloat) -> Path {
            var path = Path()
            var t: CGFloat = step / 2
            while t < length {
                let p = CGPoint(x: start.x + along.x * t, y: start.y + along.y * t)
                path.move(to: offset(p, half)); path.addLine(to: offset(p, -half))
                t += step
            }
            return path
        }
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        switch kind {
        case .corridor:
            context.stroke(rails(1.8), with: .color(ink.opacity(0.6)), lineWidth: 0.7)
        case .door:
            context.stroke(line, with: .color(ink.opacity(0.6)), lineWidth: 1.1)
        case .stair:
            context.stroke(rails(2.4), with: .color(ink.opacity(0.55)), lineWidth: 0.6)
            context.stroke(rungs(2.4, every: 2.6), with: .color(ink.opacity(0.5)), lineWidth: 0.6)
        case .drawbridge:
            context.stroke(rails(3), with: .color(ink.opacity(0.7)), lineWidth: 0.9)
            context.stroke(rungs(3, every: 2), with: .color(ink.opacity(0.55)), lineWidth: 0.8)
        case .path:
            context.stroke(line, with: .color(ink.opacity(0.5)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [0.5, 3]))
        case .hidden:
            context.stroke(line, with: .color(ink.opacity(0.3)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [0.5, 5]))
        }
    }

    private func drawRooms(in context: inout GraphicsContext, plan: Plan) {
        for room in chart.rooms where room.isDrawn && room.room.form != .ring {
            let box = plan.box(of: room)
            let colour = room.id == selectedID ? LeafInk.gold : room.room.isBorrowed ? Self.borrowedInk : ink
            switch room.room.form {
            case .ring:
                break
            case .room:
                walls(Path(box), inner: Path(box.insetBy(dx: 2.4, dy: 2.4)), colour: colour, in: &context)
            case .doors:
                walls(Path(box), inner: Path(box.insetBy(dx: 2.4, dy: 2.4)), colour: colour, in: &context)
                // Doors all along both long walls, each with its swing.
                var swings = Path()
                var x = box.minX + 6
                while x < box.maxX - 6 {
                    swings.move(to: CGPoint(x: x + 3.2, y: box.minY + 2.4))
                    swings.addArc(center: CGPoint(x: x, y: box.minY + 2.4), radius: 3.2,
                                  startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                    swings.move(to: CGPoint(x: x + 3.2, y: box.maxY - 2.4))
                    swings.addArc(center: CGPoint(x: x, y: box.maxY - 2.4), radius: 3.2,
                                  startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
                    x += 8
                }
                context.stroke(swings, with: .color(colour.opacity(0.45)), lineWidth: 0.5)
            case .shelving:
                context.fill(Path(box), with: .color(Self.paper))
                context.stroke(Path(box), with: .color(colour.opacity(0.8)), lineWidth: 1.1)
                var rows = Path()
                var y = box.minY + 3
                while y < box.maxY - 1 {
                    rows.move(to: CGPoint(x: box.minX + 2, y: y)); rows.addLine(to: CGPoint(x: box.maxX - 2, y: y))
                    y += 3.2
                }
                context.stroke(rows, with: .color(colour.opacity(0.22)), lineWidth: 0.5)
            case .tower:
                let r = min(box.width, box.height) / 2
                let circle = CGRect(x: box.midX - r, y: box.midY - r, width: r * 2, height: r * 2)
                walls(Path(ellipseIn: circle), inner: Path(ellipseIn: circle.insetBy(dx: 3, dy: 3)), colour: colour, in: &context)
            case .yard:
                context.fill(Path(box), with: .color(Self.paper))
                context.stroke(Path(box), with: .color(colour.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                speckle(box.insetBy(dx: 4, dy: 4), count: 14, seed: room.id, colour: colour, in: &context)
            case .garden:
                context.fill(Path(roundedRect: box, cornerRadius: 6), with: .color(Self.paper))
                hedge(around: box, colour: colour, in: &context)
                trees(in: box.insetBy(dx: 7, dy: 7), seed: room.id, colour: colour, in: &context)
            case .corridor:
                var walls = Path()
                walls.move(to: CGPoint(x: box.minX, y: box.minY)); walls.addLine(to: CGPoint(x: box.maxX, y: box.minY))
                walls.move(to: CGPoint(x: box.minX, y: box.maxY)); walls.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
                context.fill(Path(box), with: .color(Self.paper))
                context.stroke(walls, with: .color(colour.opacity(0.8)), lineWidth: 1.2)
                // The notes pinned along it.
                var notes = Path()
                var x = box.minX + 5
                while x < box.maxX - 4 {
                    notes.addRect(CGRect(x: x, y: box.minY + 1.5, width: 2.4, height: 2.4))
                    x += 7
                }
                context.stroke(notes, with: .color(colour.opacity(0.35)), lineWidth: 0.4)
            case .stair:
                walls(Path(box), inner: nil, colour: colour, in: &context)
                var steps = Path()
                var x = box.minX + 2.5
                while x < box.maxX - 1 {
                    steps.move(to: CGPoint(x: x, y: box.minY + 1)); steps.addLine(to: CGPoint(x: x, y: box.maxY - 1))
                    x += 2.6
                }
                context.stroke(steps, with: .color(colour.opacity(0.5)), lineWidth: 0.5)
            }
            if chart.closedRoomIDs.contains(room.id) {
                // Shut: the Book's hatched it over and crossed it through.
                var hatch = Path()
                var x = box.minX - box.height
                while x < box.maxX {
                    hatch.move(to: CGPoint(x: max(box.minX, x), y: x < box.minX ? box.minY + (box.minX - x) : box.minY))
                    let endX = min(box.maxX, x + box.height)
                    hatch.addLine(to: CGPoint(x: endX, y: box.minY + (endX - x)))
                    x += 5
                }
                context.stroke(hatch, with: .color(colour.opacity(0.18)), lineWidth: 0.6)
                var cross = Path()
                cross.move(to: CGPoint(x: box.minX, y: box.minY)); cross.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
                cross.move(to: CGPoint(x: box.maxX, y: box.minY)); cross.addLine(to: CGPoint(x: box.minX, y: box.maxY))
                context.stroke(cross, with: .color(colour.opacity(0.55)), lineWidth: 1)
            }
            if room.room.id == AcademyGeography.dormID {
                // You are here. Always.
                let dot = CGRect(x: box.maxX - 9, y: box.maxY - 9, width: 5, height: 5)
                context.fill(Path(ellipseIn: dot), with: .color(colour))
                context.stroke(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)), with: .color(colour.opacity(0.6)), lineWidth: 0.5)
            }
        }
    }

    private func walls(_ outer: Path, inner: Path?, colour: Color, in context: inout GraphicsContext) {
        context.fill(outer, with: .color(Self.paper))
        context.fill(outer, with: .color(colour.opacity(0.035)))
        context.stroke(outer, with: .color(colour.opacity(0.85)), lineWidth: 1.5)
        if let inner {
            context.stroke(inner, with: .color(colour.opacity(0.5)), lineWidth: 0.5)
        }
    }

    private func hedge(around box: CGRect, colour: Color, in context: inout GraphicsContext) {
        var bumps = Path()
        let r: CGFloat = 2.2
        var x = box.minX + r
        while x <= box.maxX - r {
            bumps.addEllipse(in: CGRect(x: x - r, y: box.minY - r, width: r * 2, height: r * 2))
            bumps.addEllipse(in: CGRect(x: x - r, y: box.maxY - r, width: r * 2, height: r * 2))
            x += r * 1.7
        }
        var y = box.minY + r
        while y <= box.maxY - r {
            bumps.addEllipse(in: CGRect(x: box.minX - r, y: y - r, width: r * 2, height: r * 2))
            bumps.addEllipse(in: CGRect(x: box.maxX - r, y: y - r, width: r * 2, height: r * 2))
            y += r * 1.7
        }
        context.fill(bumps, with: .color(Self.paper))
        context.stroke(bumps, with: .color(colour.opacity(0.6)), lineWidth: 0.6)
    }

    /// A few seeded points inside a box, the same every time for the same room.
    private func scatter(_ box: CGRect, count: Int, seed: String) -> [CGPoint] {
        var state = UInt64(truncatingIfNeeded: seed.stableHash) | 1
        func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 1000) / 1000
        }
        return (0..<count).map { _ in CGPoint(x: box.minX + next() * box.width, y: box.minY + next() * box.height) }
    }

    private func trees(in box: CGRect, seed: String, colour: Color, in context: inout GraphicsContext) {
        for point in scatter(box, count: 4, seed: seed) {
            let crown = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            context.stroke(Path(ellipseIn: crown), with: .color(colour.opacity(0.4)), lineWidth: 0.6)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 0.7, y: point.y - 0.7, width: 1.4, height: 1.4)),
                         with: .color(colour.opacity(0.5)))
        }
    }

    private func speckle(_ box: CGRect, count: Int, seed: String, colour: Color, in context: inout GraphicsContext) {
        var dots = Path()
        for point in scatter(box, count: count, seed: seed) {
            dots.addEllipse(in: CGRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        context.fill(dots, with: .color(colour.opacity(0.3)))
    }

    private func drawCompassRose(in context: inout GraphicsContext, plan: Plan) {
        let centre = CGPoint(x: plan.size.width * 0.075, y: plan.size.height * 0.05)
        let long: CGFloat = 12, waist: CGFloat = 2
        var star = Path()
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 - .pi / 2
            let r = i % 2 == 0 ? long : long * 0.55
            let tip = CGPoint(x: centre.x + CGFloat(cos(angle)) * r, y: centre.y + CGFloat(sin(angle)) * r)
            let side = CGPoint(x: CGFloat(cos(angle + .pi / 2)) * waist, y: CGFloat(sin(angle + .pi / 2)) * waist)
            star.move(to: CGPoint(x: centre.x + side.x, y: centre.y + side.y))
            star.addLine(to: tip)
            star.addLine(to: CGPoint(x: centre.x - side.x, y: centre.y - side.y))
            star.closeSubpath()
        }
        context.fill(star, with: .color(Self.paper))
        context.stroke(star, with: .color(ink.opacity(0.6)), lineWidth: 0.6)
        context.stroke(Path(ellipseIn: CGRect(x: centre.x - 6.5, y: centre.y - 6.5, width: 13, height: 13)),
                       with: .color(ink.opacity(0.4)), lineWidth: 0.5)
        context.draw(
            Text("N").font(.system(size: 7, weight: .bold, design: .serif)).foregroundColor(ink.opacity(0.7)),
            at: CGPoint(x: centre.x, y: centre.y - long - 5)
        )
    }
}

// MARK: - Footprints

/// Everybody's feet, and their names on ribbons. Its own layer, so the only
/// thing redrawn thirty times a second is ink the size of a thumbnail.
///
/// Walking leaves a short trail of prints along the way that fades behind
/// them. Pacing goes up and down a stride or two either side of where they
/// stand. Standing still is two feet, with a shift of weight now and then.
struct AcademyFootprintLayer: View {
    let walkers: [AcademyMapDrawing.Walker]
    var animates: Bool
    var clock: Date
    var isInteractive: Bool
    var onOpenCastMember: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stride: CGFloat = 6
    private static let trail = 7
    private var ink: Color { BookPalette.ink }

    var body: some View {
        let moving = animates && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !moving)) { timeline in
            let now = moving ? timeline.date : clock
            let poses = walkers.compactMap { pose(of: $0, at: now, moving: moving) }
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for pose in poses {
                        for print in pose.prints {
                            draw(print, in: &context)
                        }
                    }
                }
                ForEach(poses, id: \.walker.id) { pose in
                    ribbon(pose.walker, at: pose.ribbonAt, drop: pose.isWalking ? 0 : pose.walker.ribbonDrop)
                }
            }
        }
        .frame(width: AcademyMapDrawing.size.width, height: AcademyMapDrawing.size.height)
    }

    // MARK: Where the feet are

    private struct Print {
        var at: CGPoint
        var facing: Angle
        var isLeft: Bool
        var alpha: Double
    }

    private struct Pose {
        var walker: AcademyMapDrawing.Walker
        var prints: [Print]
        var ribbonAt: CGPoint
        var isWalking = false
    }

    private func pose(of walker: AcademyMapDrawing.Walker, at now: Date, moving: Bool) -> Pose? {
        // A still map shows a walk frozen at the moment it was drawn.
        if let walk = walker.walk, let progress = walk.progress(at: now) {
            let travelled = walk.length * progress
            var prints: [Print] = []
            let last = Int(travelled / Self.stride)
            for step in max(0, last - Self.trail + 1)...max(0, last) {
                let (point, facing) = walk.point(at: CGFloat(step) * Self.stride)
                let age = Double(last - step) / Double(Self.trail)
                prints.append(Print(at: point, facing: facing, isLeft: step % 2 == 0, alpha: 1 - age))
            }
            let (head, _) = walk.point(at: travelled)
            return Pose(walker: walker, prints: prints, ribbonAt: head, isWalking: true)
        }
        // Arrived. Someone who's joined a crowd is part of its "+N" now.
        guard walker.isShownAtRest else { return nil }

        let phase = Double(abs(walker.id.stableHash) % 1000) / 1000
        switch walker.motion {
        case .pacing where moving && walker.pacingReach > 2:
            // Up and down, turning at each end.
            let period = 6.0 + phase * 3
            let t = (now.timeIntervalSinceReferenceDate / period + phase).truncatingRemainder(dividingBy: 1)
            let reach = walker.pacingReach
            let span = reach * 2
            let travelled = CGFloat(t) * span * 2
            var prints: [Print] = []
            let last = Int(travelled / Self.stride)
            for step in max(0, last - 4)...last {
                let d = CGFloat(step) * Self.stride
                let x = d < span ? -reach + d : reach - (d - span)
                prints.append(Print(
                    at: CGPoint(x: walker.at.x + x, y: walker.at.y),
                    facing: .degrees(d < span ? 90 : -90),
                    isLeft: step % 2 == 0,
                    alpha: 1 - Double(last - step) / 5
                ))
            }
            return Pose(walker: walker, prints: prints, ribbonAt: walker.at)
        default:
            // Standing. Every few seconds one foot shifts, then settles.
            let beat = (now.timeIntervalSinceReferenceDate / (5 + phase * 4) + phase).truncatingRemainder(dividingBy: 1)
            let shifting = moving && beat < 0.1
            return Pose(walker: walker, prints: [
                Print(at: CGPoint(x: walker.at.x - 2.2, y: walker.at.y - 1.8), facing: walker.heading, isLeft: true, alpha: 1),
                Print(at: CGPoint(x: walker.at.x + 2.2 + (shifting ? 0.9 : 0), y: walker.at.y + 1.8 - (shifting ? 0.8 : 0)),
                      facing: walker.heading + .degrees(shifting ? 12 : 0), isLeft: false, alpha: 1)
            ], ribbonAt: walker.at)
        }
    }

    private func draw(_ print: Print, in context: inout GraphicsContext) {
        var foot = context
        foot.translateBy(x: print.at.x, y: print.at.y)
        foot.rotate(by: print.facing)
        let side: CGFloat = print.isLeft ? -1.3 : 1.3
        let sole = CGRect(x: side - 1.3, y: -3.2, width: 2.6, height: 4.2)
        let heel = CGRect(x: side - 1.0, y: 1.4, width: 2.0, height: 1.8)
        foot.fill(Path(ellipseIn: sole), with: .color(ink.opacity(0.8 * print.alpha)))
        foot.fill(Path(ellipseIn: heel), with: .color(ink.opacity(0.8 * print.alpha)))
    }

    // MARK: Names

    @ViewBuilder
    private func ribbon(_ walker: AcademyMapDrawing.Walker, at point: CGPoint, drop: CGFloat) -> some View {
        let label = Text(walker.person.mapName)
            .font(.system(size: 7, weight: .semibold, design: .serif))
            .italic()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(walker.person.isVisitor ? AcademyMapDrawing.borrowedInk : ink.opacity(0.9))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RibbonShape().fill(AcademyMapDrawing.paper))
            .overlay(RibbonShape().stroke(ink.opacity(0.6), lineWidth: 0.6))
            // The footprints sit above the ribbon, inside the same target.
            .padding(.top, 12)
        if walker.person.isVisitor || !isInteractive {
            // A visitor out of another book has no page here to open.
            label
                .position(x: point.x, y: point.y + 5 + drop)
                .allowsHitTesting(false)
                .accessibilityLabel("\(walker.person.name), here right now")
        } else {
            Button {
                BookFeedback.play(.tap)
                onOpenCastMember(walker.person.characterID)
            } label: {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: point.x, y: point.y + 5 + drop)
            .accessibilityLabel("\(walker.person.name), here right now")
            .accessibilityHint("Opens their page")
        }
    }
}

/// A banner with its ends cut into swallowtails.
struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(4, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX + notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX - notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
