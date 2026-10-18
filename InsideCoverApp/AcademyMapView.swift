import SwiftUI

/// The Book's map of the Labyrinth and the Academy inside it, as it sits on
/// the leaf: a small copy of the whole thing. Touching it opens the map out
/// to the whole screen, where it can be pinched and dragged about.
///
/// Illustrated parchment leaves: walls, shelving, stairs, hedges, and footprints
/// where the Cast are standing right now, each with a name on a ribbon.
/// The Academy's surveyed walls stay on the paper. Its people, weather doors,
/// borrowed rooms and the Reader's Anchors change with the living Book.
/// The layout comes from `AcademyGeography`; what's drawn, and who's where,
/// from `AcademyCartographer`.
struct AcademyMapView: View {
    /// Everything but the time. The map works out who's where again every
    /// minute, so people walk off while it's being looked at.
    let inputs: AcademyChartInputs
    /// A kept Page the reader touched in a room's note.
    var onOpenPage: (BookPage) -> Void = { _ in }
    /// A Cast member the reader touched, on the map or in a note, by entity id.
    var onOpenCastMember: (String) -> Void = { _ in }

    @State private var isOpen = false
    /// On an iPad the map folds straight out when its division is opened: the
    /// glass is big enough to be the map, so there is no small plate to touch
    /// first. Closing it leaves the plate on the leaf, as before.
    @State private var didFoldOut = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            leaf(AcademyCartographer.chart(inputs.at(Date())), clock: Date())
        }
        .onAppear {
            #if os(iOS)
            guard UIDevice.current.userInterfaceIdiom == .pad, !didFoldOut else { return }
            didFoldOut = true
            isOpen = true
            #endif
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isOpen) {
            AcademyMapViewer(inputs: inputs, onOpenPage: onOpenPage, onOpenCastMember: onOpenCastMember)
        }
        #endif
    }

    private func leaf(_ chart: AcademyChart, clock: Date) -> some View {
        // The contents leaf is the school plate. All four levels and the
        // growing Anchor archive are opened out in the full-screen atlas.
        return VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                let zoom = proxy.size.width / AcademyMapDrawing.size.width
                AcademyMapDrawing(chart: AcademyIllustratedAtlas.chart(chart, on: .ground), selectedID: .constant(nil), isInteractive: false, clock: clock)
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
            .accessibilityLabel(chart.anchorRooms.isEmpty ? "A map of the Labyrinth" : "A map of the Labyrinth and \(chart.anchorRooms.count) doors to your places")
            .accessibilityHint("Opens the map out")
            .accessibilityAddTraits(.isButton)

            Text("Four leaves. One Academy. Touch it and I'll open it out.")
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
/// Four illustrated plates sit under live ink. A camera moves over each
/// leaf; its full-resolution artwork is loaded only while that leaf is shown.
struct AcademyMapViewer: View {
    let inputs: AcademyChartInputs
    var onOpenPage: (BookPage) -> Void = { _ in }
    var onOpenCastMember: (String) -> Void = { _ in }

    var body: some View {
        TimelineView(.everyMinute) { _ in
            AcademyMapGlass(
                source: AcademyCartographer.chart(inputs.at(Date())),
                onOpenPage: onOpenPage,
                onOpenCastMember: onOpenCastMember
            )
        }
    }
}

/// Camera and selection updates belong to the glass. They must not ask the
/// Cartographer to reconstruct the school's life on every drag or pinch.
private struct AcademyMapGlass: View {
    let source: AcademyChart
    var onOpenPage: (BookPage) -> Void
    var onOpenCastMember: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?
    @State private var unfoldedDoors: Set<String> = []
    @State private var observedArrivals: [String: AcademyArrival] = [:]
    @State private var selectedCastID: String?
    @State private var level: AcademyMapLevel = .ground
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Screen points per drawing point, and where the drawing's top-left
    /// corner sits on the screen. Nil until the screen's been measured.
    @State private var camera: Camera?
    @State private var settled: Camera?

    struct Camera: Equatable {
        var zoom: CGFloat
        var origin: CGPoint
    }

    /// How much closer than "the whole width" the map opens.
    static let openingZoom: CGFloat = 2.2
    static let deepestZoom: CGFloat = 6

    var body: some View {
        glass(source, at: Date())
    }

    private func glass(_ source: AcademyChart, at now: Date) -> some View {
        var chart = source
        for (id, arrival) in observedArrivals {
            if chart.arrivals[id] == nil, arrival.isUnderway(at: now) {
                chart.arrivals[id] = arrival
            }
        }
        return GeometryReader { proxy in
            let viewport = proxy.size
            let displayed = AcademyIllustratedAtlas.chart(chart, on: level)
            let extent = AcademyMapDrawing.extent(for: displayed)
            let current = Self.clamped(camera ?? Self.opening(in: viewport, extent: extent), in: viewport, extent: extent)
            ZStack(alignment: .topLeading) {
                AcademyMapDrawing.paper.ignoresSafeArea()

                AcademyMapDrawing(
                    chart: displayed,
                    selectedID: $selectedID,
                    isInteractive: true,
                    animates: true,
                    onOpenCastMember: { id in leave { onOpenCastMember(id) } },
                    onDiscoverAnchor: { id in unfold(id) },
                    selectedCastID: selectedCastID,
                    level: level,
                    doors: AcademyIllustratedAtlas.doors(in: chart, on: level),
                    roomNames: Dictionary(uniqueKeysWithValues: chart.rooms.map { ($0.id, $0.room.mapLabel) }),
                    onTakeDoor: { id in focus(id, chart: chart, viewport: viewport) }
                )
                .scaleEffect(current.zoom, anchor: .topLeading)
                .offset(x: current.origin.x, y: current.origin.y)
                .frame(width: viewport.width, height: viewport.height, alignment: .topLeading)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(pan(viewport: viewport, extent: extent))
                .simultaneousGesture(pinch(viewport: viewport, extent: extent))
                .onTapGesture(count: 2) { location in
                    zoomToggle(at: location, viewport: viewport, extent: extent)
                }

                closeMark
                    .padding(.leading, 16)
                    .padding(.top, 8)

                Text(now.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.custom("Baskerville-Italic", size: 11))
                    .foregroundStyle(AcademyMapDrawing.mapInk.opacity(0.8))
                    .padding(5).background(AcademyMapDrawing.paper.opacity(0.9))
                    .padding(.leading, 16).padding(.top, 51)
                    .allowsHitTesting(false)

                HStack(spacing: 6) {
                    Spacer()
                    castMark(chart, viewport: viewport, extent: extent)
                    if !chart.anchorRooms.isEmpty {
                        placesMark(chart, viewport: viewport, extent: extent)
                    }
                }
                    .padding(.trailing, 16)
                    .padding(.top, 8)

                VStack(spacing: 3) {
                    Text(level.title).font(.custom("Baskerville-SemiBold", size: 16))
                    Text(level.note).font(.custom("Baskerville-Italic", size: 11))
                }
                .foregroundStyle(AcademyMapDrawing.mapInk)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(AcademyMapDrawing.paper.opacity(0.94))
                .frame(width: viewport.width)
                .padding(.top, 80)
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    levelMarks(chart, viewport: viewport)
                }
                .padding(.horizontal, 12).padding(.bottom, 12)

                if let id = selectedID,
                   (chart.room(id)?.isDrawn == true || chart.anchorRooms.contains(where: { $0.id == id })) {
                    VStack {
                        Spacer()
                        ScrollView {
                            VStack(spacing: 0) {
                            if let room = chart.room(id), room.isDrawn {
                                AcademyRoomNote(
                                    room: room,
                                    chart: chart,
                                    onOpenPage: { page in leave { onOpenPage(page) } },
                                    onOpenCastMember: { id in leave { onOpenCastMember(id) } }
                                )
                                roomDoors(room.id, chart: chart, viewport: viewport)
                            } else if let room = chart.anchorRooms.first(where: { $0.id == id }) {
                                AcademyAnchorNote(room: room, showsFoldedWords: unfoldedDoors.contains(room.id),
                                                  onUnfold: { unfold(room.id) },
                                                  onOpenPage: { page in leave { onOpenPage(page) } })
                            }
                            }
                        }
                        .frame(maxHeight: viewport.height * 0.42)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AcademyMapDrawing.paper)
                                .shadow(color: .black.opacity(0.18), radius: 10, y: 2)
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: selectedID)
            .onChange(of: source.anchorRooms.count) { old, new in
                // New paper unfolds north. Keep the bit already under the
                // Reader's glass still, whether it's a Cast room or a door.
                guard level == .labyrinth else { return }
                var moved = camera ?? Self.opening(in: viewport, extent: extent)
                let growth = (AcademyAnchorExtension.height(for: new) - AcademyAnchorExtension.height(for: old)) * AcademyMapDrawing.anchorScale
                moved.origin.y -= growth * moved.zoom
                camera = Self.clamped(moved, in: viewport, extent: extent)
                settled = nil
            }
            .onChange(of: source.rooms.flatMap(\.people)) { old, new in
                let previous = Dictionary(old.map { ($0.characterID, $0.roomID) }, uniquingKeysWith: { first, _ in first })
                let departureTime = Date()
                var next = observedArrivals.filter { $0.value.isUnderway(at: departureTime) }
                for person in new {
                    if let from = previous[person.characterID], from != person.roomID {
                        next[person.characterID] = source.arrivals[person.characterID]
                            ?? AcademyArrival.departing(person, from: from, at: departureTime,
                                                       passages: source.allPassages, closedRoomIDs: source.closedRoomIDs)
                    }
                }
                observedArrivals = next
                if let id = selectedCastID, !new.contains(where: { $0.characterID == id }) {
                    selectedCastID = nil
                }
            }
            .onChange(of: selectedID) { _, roomID in
                if let id = selectedCastID,
                   roomID.flatMap({ chart.room($0) })?.people.contains(where: { $0.characterID == id }) != true {
                    selectedCastID = nil
                }
            }
            .onChange(of: chart.anchorRooms.map(\.id)) { _, ids in
                if let id = selectedID, id.hasPrefix("academy-anchor:"), !ids.contains(id) { selectedID = nil }
            }
        }
    }

    private func unfold(_ id: String) {
        BookFeedback.play(.tap)
        withAnimation(.easeOut(duration: 0.25)) {
            unfoldedDoors.insert(id)
            selectedID = id
        }
    }

    private func focus(_ id: String, chart: AcademyChart, viewport: CGSize, castID: String? = nil) {
        guard let room = chart.room(id) else { return }
        let moment = Date()
        let person = castID.flatMap { id in chart.rooms.flatMap(\.people).first { $0.characterID == id } }
        let destination = person.map { AcademyIllustratedAtlas.level(of: $0, at: moment, in: chart) }
            ?? AcademyIllustratedAtlas.level(of: id, in: chart)
        let leaf = AcademyIllustratedAtlas.chart(chart, on: destination)
        let projected = AcademyIllustratedAtlas.projectedRoom(room, in: chart)
        let box = AcademyMapDrawing.Plan.box(of: projected, in: AcademyMapDrawing.size)
        var center = CGPoint(x: box.midX, y: box.midY)
        if let castID, chart.arrivals[castID]?.isUnderway(at: moment) == true {
            let plan = AcademyMapDrawing.Plan(size: AcademyMapDrawing.size, chart: leaf, level: destination)
            if let walk = plan.walkers.first(where: {
                $0.id == castID && $0.walk.map { moment >= $0.startedAt && $0.progress(at: moment) != nil } == true
            })?.walk, let progress = walk.progress(at: moment) {
                center = walk.point(at: walk.length * progress).0
            }
        }
        let zoom = min(Self.fitZoom(in: viewport) * Self.deepestZoom,
                       max(Self.fitZoom(in: viewport) * 2.8, viewport.width * 0.78 / box.width))
        let move = {
            level = destination
            selectedCastID = castID
            selectedID = id
            settled = nil
            camera = Self.clamped(Camera(zoom: zoom, origin: CGPoint(
                x: viewport.width / 2 - center.x * zoom,
                y: viewport.height * 0.30 - (center.y + AcademyMapDrawing.anchorHeight(for: leaf)) * zoom
            )), in: viewport, extent: AcademyMapDrawing.extent(for: leaf))
        }
        BookFeedback.play(.tap)
        if reduceMotion { move() } else { withAnimation(.easeInOut(duration: 0.35), move) }
    }

    private func levelMarks(_ chart: AcademyChart, viewport: CGSize) -> some View {
        HStack(spacing: 0) {
            ForEach(AcademyMapLevel.allCases) { destination in
                let moment = Date()
                let count = chart.rooms.flatMap(\.people).filter {
                    AcademyIllustratedAtlas.level(of: $0, at: moment, in: chart) == destination
                }.count
                Button {
                    BookFeedback.play(.tap)
                    let leaf = AcademyIllustratedAtlas.chart(chart, on: destination)
                    let extent = AcademyMapDrawing.extent(for: leaf)
                    let zoom = Self.fitZoom(in: viewport) * 1.25
                    let turn = {
                        level = destination
                        selectedID = nil; selectedCastID = nil; settled = nil
                        camera = Self.clamped(Camera(zoom: zoom, origin: CGPoint(
                            x: (viewport.width - AcademyMapDrawing.size.width * zoom) / 2,
                            y: viewport.height * 0.43 - (AcademyMapDrawing.size.height * 0.46 + AcademyMapDrawing.anchorHeight(for: leaf)) * zoom
                        )), in: viewport, extent: extent)
                    }
                    if reduceMotion { turn() } else { withAnimation(.easeInOut(duration: 0.3), turn) }
                } label: {
                    VStack(spacing: 3) {
                        Text(destination.shortTitle).font(.custom("Baskerville-SemiBold", size: 14))
                        Text("\(count) \(count == 1 ? "name" : "names")")
                            .font(.custom("Baskerville-Italic", size: 11))
                    }
                    .foregroundStyle(AcademyMapDrawing.mapInk.opacity(destination == level ? 1 : 0.7))
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(destination == level ? AcademyMapDrawing.mapInk.opacity(0.08) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(destination.title), \(count) names")
                .accessibilityAddTraits(destination == level ? .isSelected : [])
            }
        }
        .background(AcademyMapDrawing.paper.opacity(0.97))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AcademyMapDrawing.mapInk.opacity(0.5), lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func roomDoors(_ id: String, chart: AcademyChart, viewport: CGSize) -> some View {
        let neighbours = chart.allPassages.filter { $0.touches(id) }.compactMap { $0.other(than: id) }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(neighbours, id: \.self) { next in
                if let room = chart.room(next) {
                    let destination = AcademyIllustratedAtlas.level(of: next, in: chart)
                    Button {
                        focus(next, chart: chart, viewport: viewport)
                    } label: {
                        HStack {
                            Image(systemName: destination == level ? "door.left.hand.open" : "stairs")
                            Text(room.room.mapLabel)
                            Spacer()
                            if destination != level { Text(destination.shortTitle).italic() }
                            Image(systemName: "chevron.right").font(.system(size: 9))
                        }
                        .font(.custom("Baskerville", size: 13))
                        .foregroundStyle(AcademyMapDrawing.mapInk)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to \(room.room.mapLabel), \(destination.title)")
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func placesMark(_ chart: AcademyChart, viewport: CGSize, extent: CGSize) -> some View {
        Menu {
            ForEach(Array(chart.anchorRooms.enumerated()), id: \.element.id) { index, room in
                Button(room.anchor.name) {
                    BookFeedback.play(.tap)
                    let box = AcademyAnchorExtension.box(at: index, rooms: chart.anchorRooms)
                    let zoom = Self.fitZoom(in: viewport) * 1.8
                    let move = {
                        level = .labyrinth
                        selectedCastID = nil; settled = nil
                        selectedID = room.id
                        camera = Self.clamped(Camera(zoom: zoom, origin: CGPoint(
                            x: viewport.width / 2 - box.midX * AcademyMapDrawing.anchorScale * zoom,
                            y: viewport.height * 0.30 - box.midY * AcademyMapDrawing.anchorScale * zoom
                        )), in: viewport, extent: AcademyMapDrawing.extent(for: AcademyIllustratedAtlas.chart(chart, on: .labyrinth)))
                    }
                    if reduceMotion { move() } else { withAnimation(.easeInOut(duration: 0.35), move) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "door.left.hand.open")
                Text("Your places")
            }
            .font(.system(size: 12, design: .serif))
            .foregroundStyle(AcademyMapDrawing.mapInk)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(AcademyMapDrawing.paper))
            .overlay(Capsule().stroke(AcademyMapDrawing.mapInk.opacity(0.4), lineWidth: 0.8))
        }
        .accessibilityLabel("\(chart.anchorRooms.count) doors to your places")
        .accessibilityHint("Choose a place to find its room")
    }

    /// Every current name has an address here, even at supper or in a
    /// crowded classroom. Finding a walker opens at their current footsteps.
    private func castMark(_ chart: AcademyChart, viewport: CGSize, extent: CGSize) -> some View {
        let people = chart.rooms.flatMap(\.people).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return Menu {
            ForEach(people, id: \.characterID) { person in
                let roomName = chart.room(person.roomID)?.room.mapLabel ?? "the Academy"
                let whereabouts = chart.arrivals[person.characterID]?.isUnderway(at: Date()) == true
                    ? "on the way to \(roomName)" : roomName
                Button("\(person.name) · \(whereabouts)") {
                    guard let room = chart.room(person.roomID) else { return }
                    focus(room.id, chart: chart, viewport: viewport, castID: person.characterID)
                }
            }
        } label: {
            Text("Find a name").font(.custom("Baskerville", size: 13))
                .foregroundStyle(AcademyMapDrawing.mapInk)
                .padding(.horizontal, 12).frame(height: 36)
                .background(Capsule().fill(AcademyMapDrawing.paper))
                .overlay(Capsule().stroke(AcademyMapDrawing.mapInk.opacity(0.4), lineWidth: 0.8))
        }
        .accessibilityLabel("Find any of the \(people.count) names on the map")
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

    static func opening(in viewport: CGSize, extent: CGSize = AcademyMapDrawing.size) -> Camera {
        let zoom = fitZoom(in: viewport) * openingZoom
        let hall = AcademyIllustratedAtlas.floors["location-great-hall"].map { CGPoint(x: AcademyMapDrawing.size.width * $0.center.x, y: AcademyMapDrawing.size.height * $0.center.y) }
            ?? CGPoint(x: AcademyMapDrawing.size.width / 2, y: AcademyMapDrawing.size.height / 2)
        return clamped(Camera(
            zoom: zoom,
            origin: CGPoint(x: viewport.width / 2 - hall.x * zoom,
                            y: viewport.height / 2 - (hall.y + extent.height - AcademyMapDrawing.size.height) * zoom)
        ), in: viewport, extent: extent)
    }

    /// Keep the paper on the screen: no dragging the whole map off into the
    /// dark, and a map smaller than the screen sits in the middle of it.
    static func clamped(_ camera: Camera, in viewport: CGSize, extent: CGSize = AcademyMapDrawing.size) -> Camera {
        var camera = camera
        let fit = fitZoom(in: viewport)
        camera.zoom = min(max(camera.zoom, fit * 0.9), fit * deepestZoom)
        let content = CGSize(
            width: extent.width * camera.zoom,
            height: extent.height * camera.zoom
        )
        func axis(_ origin: CGFloat, content: CGFloat, view: CGFloat) -> CGFloat {
            content <= view ? (view - content) / 2 : min(0, max(view - content, origin))
        }
        camera.origin.x = axis(camera.origin.x, content: content.width, view: viewport.width)
        camera.origin.y = axis(camera.origin.y, content: content.height, view: viewport.height)
        return camera
    }

    private func pan(viewport: CGSize, extent: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = settled ?? camera ?? Self.opening(in: viewport, extent: extent)
                if settled == nil { settled = start }
                var moved = start
                moved.origin.x += value.translation.width
                moved.origin.y += value.translation.height
                camera = Self.clamped(moved, in: viewport, extent: extent)
            }
            .onEnded { _ in settled = nil }
    }

    private func pinch(viewport: CGSize, extent: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = settled ?? camera ?? Self.opening(in: viewport, extent: extent)
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
                ), in: viewport, extent: extent)
            }
            .onEnded { _ in settled = nil }
    }

    /// Double tap: in closer where the finger is, or back out if it's
    /// already close.
    private func zoomToggle(at location: CGPoint, viewport: CGSize, extent: CGSize) {
        let current = camera ?? Self.opening(in: viewport, extent: extent)
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
            ), in: viewport, extent: extent)
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
    var onDiscoverAnchor: (String) -> Void = { _ in }
    var selectedCastID: String? = nil
    var level: AcademyMapLevel = .ground
    var doors: [AcademyAtlasDoor] = []
    var roomNames: [String: String] = [:]
    var onTakeDoor: (String) -> Void = { _ in }

    @State private var planCache = PlanCache()

    /// Gesture updates move the glass, not the school's floor. Keep the
    /// passage survey until a new chart actually changes it.
    private final class PlanCache {
        private var chart: AcademyChart?
        private var plan: Plan?
        private var cachedLevel: AcademyMapLevel?

        func resolve(_ current: AcademyChart, level: AcademyMapLevel) -> Plan {
            if chart == current, cachedLevel == level, let plan { return plan }
            let next = Plan(size: AcademyMapDrawing.size, chart: current, level: level)
            chart = current; cachedLevel = level; plan = next
            return next
        }
    }

    static let size = CGSize(width: 920, height: 1380)
    static let anchorScale: CGFloat = size.width / 520
    static func anchorHeight(for chart: AcademyChart) -> CGFloat {
        AcademyAnchorExtension.height(for: chart.anchorRooms.count) * anchorScale
    }
    /// Rooms out of other books are drawn in someone else's ink.
    static let borrowedInk = Color(red: 0.55, green: 0.22, blue: 0.14)
    static let paper = Color(red: 0.92, green: 0.82, blue: 0.65)
    private var ink: Color { Self.mapInk }
    static let mapInk = Color(red: 0.29, green: 0.20, blue: 0.13)

    /// A point on the chart, in drawing points.
    static func point(_ p: AcademyMapPoint) -> CGPoint {
        CGPoint(x: size.width * (0.04 + CGFloat(p.x) * 0.92), y: size.height * (0.03 + CGFloat(p.y) * 0.88))
    }

    static func extent(for chart: AcademyChart) -> CGSize {
        CGSize(width: size.width, height: paperHeight(for: chart) + anchorHeight(for: chart))
    }

    static func paperHeight(for chart: AcademyChart) -> CGFloat {
        let bottom = chart.rooms.map { Plan.box(of: $0, in: size).maxY }.max() ?? size.height
        return max(size.height, bottom + 44)
    }

    var body: some View {
        let plan = planCache.resolve(chart, level: level)
        let extent = Self.extent(for: chart)
        ZStack(alignment: .topLeading) {
            Self.paper
            Image("ParchmentTexture")
                .resizable()
                .frame(width: extent.width, height: extent.height)
                .opacity(0.48)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                if !chart.anchorRooms.isEmpty {
                    AcademyAnchorExtension(rooms: chart.anchorRooms, selectedID: $selectedID,
                                           isInteractive: isInteractive, animates: animates,
                                           onDiscover: onDiscoverAnchor)
                        .scaleEffect(Self.anchorScale, anchor: .topLeading)
                        .frame(width: Self.size.width, height: Self.anchorHeight(for: chart), alignment: .topLeading)
                }
                academyPaper(plan: plan)
            }
        }
        .frame(width: extent.width, height: extent.height)
        .allowsHitTesting(isInteractive)
    }

    private func academyPaper(plan: Plan) -> some View {
        ZStack(alignment: .topLeading) {
            Image(level.assetName)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.size.width, height: Self.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Canvas { context, _ in
                // Only new rooms and actual changing marks need fresh ink.
                // Permanent architecture belongs to the illustrator's plate.
                drawLivingInk(in: &context, plan: plan)
            }
            ForEach(chart.rooms.filter(\.isDrawn)) { room in
                roomTarget(room, plan: plan)
            }
            AcademyFootprintLayer(
                walkers: plan.walkers,
                animates: animates,
                clock: clock,
                isInteractive: isInteractive,
                onOpenCastMember: onOpenCastMember,
                selectedCastID: selectedCastID,
                paperHeight: Self.paperHeight(for: chart)
            )
            stairTargets(plan: plan)
            titleCartouche(plan: plan)
        }
        .frame(width: Self.size.width, height: Self.paperHeight(for: chart))
        .allowsHitTesting(isInteractive)
    }

    // MARK: - Layout

    /// Everything the drawing and the touch targets agree on, worked out once
    /// per size.
    struct Plan {
        let size: CGSize
        let rooms: [String: AcademyChartRoom]
        let level: AcademyMapLevel
        /// One floor plan for the walls and the feet. These are drawing
        /// routes only; the story still chooses rooms through AcademyRoute.
        private(set) var passagePoints: [String: [CGPoint]] = [:]
        private var passageStarts: [String: String] = [:]
        private(set) var walkers: [Walker] = []

        init(size: CGSize, chart: AcademyChart, level: AcademyMapLevel = .ground) {
            self.size = size
            self.level = level
            self.rooms = Dictionary(uniqueKeysWithValues: chart.rooms.map { ($0.id, $0) })
            for passage in chart.allPassages {
                guard let a = rooms[passage.from], let b = rooms[passage.to] else { continue }
                let aBox = box(of: a), bBox = box(of: b)
                var start = CGPoint(x: aBox.midX, y: aBox.midY)
                var end = CGPoint(x: bBox.midX, y: bBox.midY)
                if a.room.form == .ring { start = ringLanding(from: end, ring: aBox) }
                if b.room.form == .ring { end = ringLanding(from: start, ring: bBox) }
                let obstacles = chart.rooms.filter {
                    $0.isDrawn && $0.room.form != .ring && $0.id != a.id && $0.id != b.id
                }.map { box(of: $0).insetBy(dx: -10, dy: -10) }
                var illustrated = AcademyIllustratedAtlas.walk(from: a.id, to: b.id)?.map {
                    CGPoint(x: size.width * $0.x, y: size.height * $0.y)
                }
                if a.id == "location-shelf-misfiled-days" || b.id == "location-shelf-misfiled-days" {
                    illustrated = AcademyIllustratedAtlas.walk(from: "location-stacks", to: "location-shelf-misfiled-days")?.map {
                        CGPoint(x: size.width * $0.x, y: size.height * $0.y)
                    }
                    let shelf = a.id == "location-shelf-misfiled-days" ? aBox : bBox
                    if shelf.midX > size.width * 0.6 {
                        illustrated = [(0.55,0.48),(0.7,0.35),(0.75,0.25),(0.8,0.24)].map {
                            CGPoint(x: size.width * $0.0, y: size.height * $0.1)
                        }
                    } else if shelf.midY < size.height * 0.23 {
                        illustrated = [(0.55,0.48),(0.54,0.40),(0.5,0.315),(0.44,0.28),(0.39,0.23),(0.25,0.17)].map {
                            CGPoint(x: size.width * $0.0, y: size.height * $0.1)
                        }
                    }
                    if a.id == "location-shelf-misfiled-days", let route = illustrated { illustrated = Array(route.reversed()) }
                }
                passagePoints[Self.key(a.id, b.id)] = illustrated
                    ?? Self.floorRoute(from: start, to: end, avoiding: obstacles)
                passageStarts[Self.key(a.id, b.id)] = a.id
            }
            var walkers: [Walker] = []
            for room in chart.rooms where room.isDrawn && !room.people.isEmpty {
                let box = Plan.box(of: room, in: size)
                let isRing = room.room.form == .ring
                let columns = isRing ? max(1, Int(box.width / 72)) : max(1, Int((box.width - 12) / 64))
                let rows = Int(ceil(Double(room.people.count) / Double(columns)))
                let usable = isRing
                    ? CGRect(x: box.minX + 16, y: box.minY + 12, width: box.width - 32, height: max(24, CGFloat(rows) * 26))
                    : box.insetBy(dx: 8, dy: 0)
                let stepX = usable.width / CGFloat(columns)
                let top = room.room.form == .corridor || room.room.form == .stair ? CGFloat(12) : CGFloat(27)
                let stepY = isRing ? CGFloat(26) : max(7, (box.height - top - 8) / CGFloat(max(1, rows)))
                let compact = !isRing && stepY < 28
                for (index, person) in room.people.enumerated() {
                    let row = index / columns, column = index % columns
                    let inRow = min(columns, room.people.count - row * columns)
                    let slot = CGPoint(x: isRing ? usable.minX + 20 + CGFloat(column) * stepX
                                          : usable.midX + (CGFloat(column) - CGFloat(inRow - 1) / 2) * stepX,
                                       y: isRing ? usable.minY + CGFloat(row) * stepY
                                          : box.minY + top + (CGFloat(row) + 0.25) * stepY)
                    walkers.append(Walker(
                        person: person, at: slot,
                        heading: Angle.degrees(Double(UInt64(truncatingIfNeeded: person.characterID.stableHash) % 70) - 35),
                        motion: AcademyMotion.of(person),
                        pacingReach: person.why == .sleeping || compact ? 0 : min(min(stepX * 0.17, stepY * 0.25), 10),
                        compact: compact, ribbonDrop: 0, isShownAtRest: true,
                        walk: chart.arrivals[person.characterID].flatMap {
                            walk(from: $0, to: room.id, endingAt: slot, chart: chart)
                        }
                    ))
                }
            }
            // Departure and pass-through fragments share the resident's
            // clock. Only one fragment of a name is visible at any moment.
            for person in chart.unseen {
                guard let arrival = chart.arrivals[person.characterID] else { continue }
                for segment in AcademyIllustratedAtlas.journey(from: arrival.fromRoomID, to: person.roomID, in: chart, on: level) where segment.leaves {
                    guard let walk = walk(segment, from: arrival, endingAt: nil) else { continue }
                    walkers.append(Walker(
                        person: person, at: walk.points.last ?? .zero, heading: .zero, motion: .stationary,
                        pacingReach: 0, compact: false, ribbonDrop: 0, isShownAtRest: false, walk: walk
                    ))
                }
            }
            self.walkers = walkers
        }

        /// The visible destination stretch of a journey. Other stretches
        /// are departure ghosts and disappear when their stair is reached.
        func walk(from arrival: AcademyArrival, to goal: String, endingAt slot: CGPoint?, chart: AcademyChart) -> Walk? {
            guard let segment = AcademyIllustratedAtlas.journey(from: arrival.fromRoomID, to: goal, in: chart, on: level)
                .last(where: { !$0.leaves }) else { return nil }
            return walk(segment, from: arrival, endingAt: slot)
        }

        private func walk(_ segment: AcademyAtlasJourneySegment, from arrival: AcademyArrival, endingAt slot: CGPoint?) -> Walk? {
            guard let first = segment.rooms.first, let last = segment.rooms.last,
                  let entrance = rooms[first], let exit = rooms[last] else { return nil }
            var points: [CGPoint] = []
            if segment.enters {
                let box = box(of: entrance)
                points = [CGPoint(x: box.midX, y: box.maxY + 8), CGPoint(x: box.midX, y: box.midY)]
            }
            for (a, b) in zip(segment.rooms, segment.rooms.dropFirst()) {
                let way = route(from: a, to: b)
                points += points.last == way.first ? Array(way.dropFirst()) : way
            }
            if segment.leaves {
                let box = box(of: exit)
                let center = CGPoint(x: box.midX, y: box.midY)
                if points.last != center { points.append(center) }
                points.append(CGPoint(x: box.midX, y: box.maxY + 8))
            } else if let slot { points.append(slot) }
            guard points.count > 1 else { return nil }
            return Walk(points: points,
                        startedAt: arrival.startedAt.addingTimeInterval(segment.starts * arrival.duration),
                        duration: max(0.01, (segment.finishes - segment.starts) * arrival.duration))
        }

        private static func key(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }

        func route(from a: String, to b: String) -> [CGPoint] {
            let key = Self.key(a, b)
            guard let points = passagePoints[key] else { return [] }
            return passageStarts[key] == a ? points : Array(points.reversed())
        }

        /// The first wall crossed by this route, including a bend inside a
        /// chamber. A door's direction follows that segment, not a diagonal
        /// from the room's centre to the next room.
        func portal(of room: AcademyChartRoom, along points: [CGPoint]) -> (CGPoint, Angle)? {
            let box = box(of: room)
            let outline = AcademyMapDrawing.outline(of: room, in: box)
            for (a, b) in zip(points, points.dropFirst()) where outline.contains(a) && !outline.contains(b) {
                let dx = b.x - a.x, dy = b.y - a.y
                var low: CGFloat = 0, high: CGFloat = 1
                for _ in 0..<16 {
                    let middle = (low + high) / 2
                    if outline.contains(CGPoint(x: a.x + dx * middle, y: a.y + dy * middle)) { low = middle }
                    else { high = middle }
                }
                let t = (low + high) / 2
                return (CGPoint(x: a.x + dx * t, y: a.y + dy * t), .radians(Double(atan2(dy, dx))))
            }
            return nil
        }

        /// Trim by distance, including bends, so the unfinished ink and the
        /// disappearing feet stop at exactly the same place.
        static func prefix(_ points: [CGPoint], fraction: CGFloat) -> [CGPoint] {
            guard let first = points.first else { return [] }
            var remaining = zip(points, points.dropFirst()).reduce(CGFloat.zero) {
                $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y)
            } * fraction
            var result = [first]
            for (a, b) in zip(points, points.dropFirst()) {
                let distance = hypot(b.x - a.x, b.y - a.y)
                if remaining < distance {
                    let t = distance > 0 ? remaining / distance : 0
                    result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                    break
                }
                result.append(b)
                remaining -= distance
            }
            return result
        }

        /// An orthogonal visibility grid: passages turn at masonry corners
        /// instead of drawing diagonal wires through somebody else's room.
        /// Only discovered rooms are obstacles. Nothing outlines the blank.
        static func floorRoute(from start: CGPoint, to end: CGPoint, avoiding obstacles: [CGRect]) -> [CGPoint] {
            if start == end { return [start] }
            let xs = Array(Set([start.x, end.x] + obstacles.flatMap { [$0.minX, $0.maxX] })).sorted()
            let ys = Array(Set([start.y, end.y] + obstacles.flatMap { [$0.minY, $0.maxY] })).sorted()
            let width = xs.count
            func index(_ p: CGPoint) -> Int { ys.firstIndex(of: p.y)! * width + xs.firstIndex(of: p.x)! }
            func point(_ id: Int) -> CGPoint { CGPoint(x: xs[id % width], y: ys[id / width]) }
            func clear(_ a: CGPoint, _ b: CGPoint) -> Bool {
                !obstacles.contains { box in
                    if a.x == b.x {
                        return a.x > box.minX && a.x < box.maxX
                            && max(a.y, b.y) > box.minY && min(a.y, b.y) < box.maxY
                    }
                    return a.y > box.minY && a.y < box.maxY
                        && max(a.x, b.x) > box.minX && min(a.x, b.x) < box.maxX
                }
            }
            let source = index(start), goal = index(end)
            var open: Set<Int> = [source]
            var costs: [Int: CGFloat] = [source: 0]
            var previous: [Int: Int] = [:]
            func score(_ id: Int) -> CGFloat {
                let p = point(id)
                return (costs[id] ?? .infinity) + abs(p.x - end.x) + abs(p.y - end.y)
            }
            while let current = open.min(by: { score($0) == score($1) ? $0 < $1 : score($0) < score($1) }) {
                if current == goal {
                    var ids = [goal]
                    while let parent = previous[ids.last!] { ids.append(parent) }
                    let raw = ids.reversed().map(point)
                    var result: [CGPoint] = []
                    for p in raw {
                        if result.count >= 2 {
                            let a = result[result.count - 2], b = result[result.count - 1]
                            if (a.x == b.x && b.x == p.x) || (a.y == b.y && b.y == p.y) { result.removeLast() }
                        }
                        result.append(p)
                    }
                    return result
                }
                open.remove(current)
                let x = current % width, y = current / width
                let neighbours = [x > 0 ? current - 1 : nil, x + 1 < width ? current + 1 : nil,
                                  y > 0 ? current - width : nil, y + 1 < ys.count ? current + width : nil].compactMap { $0 }
                for next in neighbours {
                    let a = point(current), b = point(next)
                    guard clear(a, b) else { continue }
                    let cost = (costs[current] ?? 0) + abs(a.x - b.x) + abs(a.y - b.y)
                    if cost < (costs[next] ?? .infinity) {
                        costs[next] = cost
                        previous[next] = current
                        open.insert(next)
                    }
                }
            }
            // A borrowed room may overlap another room. Keep its connection
            // legible even when no clear corridor can be fitted between them.
            return [start, CGPoint(x: start.x, y: end.y), end]
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
        /// Names sit alongside the feet when the room needs closer rows.
        let compact: Bool
        /// How far below the usual line their name sits, so it doesn't sit
        /// on top of a neighbour's.
        let ribbonDrop: CGFloat
        /// False only while departing toward an unavailable temporary room.
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

    static let ringBand: CGFloat = 13

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
        let outside = [.corridor, .stair, .tower].contains(room.room.form)
        let fits = !isRing && box.height >= 26 && !outside
        return ZStack {
            if !isRing {
                Text(room.room.mapLabel.uppercased())
                    .font(.custom("Baskerville-SemiBold", size: 12))
                    .tracking(0.6)
                    .italic(room.room.zone == .labyrinth)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? LeafInk.gold : ink.opacity(0.84))
                    .frame(width: max(box.width - 6, 84))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    .background(Self.paper.opacity(fits ? 0.52 : 0.85))
                    .position(
                        x: box.midX,
                        // Inside when it fits. A corridor wears its name above
                        // it, and anything else too small wears it underneath.
                        y: fits ? box.minY + min(13, box.height * 0.34)
                            : outside ? box.minY - 10 : box.maxY + 10
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
        VStack(spacing: 2) {
            Text("THE ACADEMY")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .tracking(2.4)
            Text(level.title.uppercased())
                .font(.system(size: 7, design: .serif))
                .tracking(2)
            Text(level.note)
                .font(.system(size: 8, design: .serif))
                .italic()
        }
        .foregroundStyle(ink.opacity(0.78))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(RibbonShape().fill(Self.paper.opacity(0.75)))
        .overlay(RibbonShape().stroke(ink.opacity(0.65), lineWidth: 0.8))
        .position(x: plan.size.width / 2, y: plan.size.height * 0.975)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Ink

    /// Fresh ink belongs only to changing facts. The illustrator owns the
    /// walls; the Book still owns closures, private doors and borrowed rooms.
    private func drawLivingInk(in context: inout GraphicsContext, plan: Plan) {
        let borrowed = chart.rooms.filter { $0.room.isBorrowed }
        drawRooms(in: &context, plan: plan, rooms: borrowed)
        for room in chart.rooms where chart.closedRoomIDs.contains(room.id) || room.id == selectedID {
            let box = plan.box(of: room).insetBy(dx: -4, dy: -4)
            if room.id == selectedID {
                context.stroke(Path(roundedRect: box, cornerRadius: 12), with: .color(LeafInk.gold.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
            }
            if chart.closedRoomIDs.contains(room.id) {
                var cross = Path()
                cross.move(to: CGPoint(x: box.minX, y: box.minY))
                cross.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
                cross.move(to: CGPoint(x: box.maxX, y: box.minY))
                cross.addLine(to: CGPoint(x: box.minX, y: box.maxY))
                context.stroke(cross, with: .color(Self.borrowedInk.opacity(0.65)), lineWidth: 1.2)
            }
        }
        if let home = plan.rooms[AcademyGeography.dormID] {
            let box = plan.box(of: home)
            context.stroke(Path(ellipseIn: CGRect(x: box.maxX - 8, y: box.maxY - 8, width: 5, height: 5)),
                           with: .color(ink.opacity(0.8)), lineWidth: 1)
        }
        if !borrowed.isEmpty {
            let caption = Text("ROOMS OUT OF OTHER BOOKS")
                .font(.custom("Baskerville-Italic", size: 11)).foregroundStyle(Self.borrowedInk)
            context.draw(caption, at: CGPoint(x: Self.size.width / 2, y: Self.size.height + 18))
        }
        if !chart.anchorRooms.isEmpty {
            var threshold = Path()
            threshold.move(to: CGPoint(x: Self.size.width / 2, y: 0))
            threshold.addQuadCurve(to: CGPoint(x: Self.size.width * 0.64, y: Self.size.height * 0.07),
                                   control: CGPoint(x: Self.size.width * 0.64, y: 12))
            context.stroke(threshold, with: .color(ink.opacity(0.65)),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 3]))
        }
    }

    private func stairTargets(plan: Plan) -> some View {
        let groups = Dictionary(grouping: doors, by: \.from)
        return ForEach(groups.keys.sorted(), id: \.self) { id in
            if let room = plan.rooms[id] {
                let box = plan.box(of: room)
                Menu {
                    ForEach(groups[id] ?? []) { door in
                        Button("\(roomNames[door.to] ?? door.to) · \(door.level.title)") { onTakeDoor(door.to) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "stairs")
                        Text("\(Set((groups[id] ?? []).map(\.level)).map(\.shortTitle).sorted().joined(separator: " · "))")
                    }
                    .font(.custom("Baskerville-Italic", size: 9))
                    .foregroundStyle(ink.opacity(0.85))
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(Self.paper.opacity(0.92))
                    .contentShape(Rectangle())
                }
                .position(x: box.midX, y: box.maxY + 8)
                .accessibilityLabel("Passages from \(room.room.mapLabel) to other leaves")
            }
        }
    }

    private func roomOutline(_ room: AcademyChartRoom, box: CGRect) -> Path {
        Self.outline(of: room, in: box)
    }

    static func outline(of room: AcademyChartRoom, in box: CGRect) -> Path {
        if room.room.form == .tower {
            let r = min(box.width, box.height) / 2
            return Path(ellipseIn: CGRect(x: box.midX - r, y: box.midY - r, width: r * 2, height: r * 2))
        }
        if room.room.form == .garden { return Path(roundedRect: box, cornerRadius: 6) }
        guard room.room.form == .room || room.room.form == .doors else { return Path(box) }
        if room.id == "location-common-tidecrest" { return Path(ellipseIn: box) }
        if room.id == "location-book-burrow" || room.id == "location-common-mossbloom" {
            return Path(roundedRect: box, cornerRadius: min(12, box.height / 2))
        }
        if room.id == "location-inkworks" || room.id == "location-common-emberheart" {
            // A cruciform workshop: four deep writing bays around the floor.
            let dx = box.width * 0.19, dy = box.height * 0.23
            let corners = [CGPoint(x: box.minX + dx, y: box.minY), CGPoint(x: box.maxX - dx, y: box.minY),
                           CGPoint(x: box.maxX - dx, y: box.minY + dy), CGPoint(x: box.maxX, y: box.minY + dy),
                           CGPoint(x: box.maxX, y: box.maxY - dy), CGPoint(x: box.maxX - dx, y: box.maxY - dy),
                           CGPoint(x: box.maxX - dx, y: box.maxY), CGPoint(x: box.minX + dx, y: box.maxY),
                           CGPoint(x: box.minX + dx, y: box.maxY - dy), CGPoint(x: box.minX, y: box.maxY - dy),
                           CGPoint(x: box.minX, y: box.minY + dy), CGPoint(x: box.minX + dx, y: box.minY + dy)]
            var path = Path()
            path.move(to: corners[0])
            for p in corners.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
            return path
        }
        let ceremonial = ["location-great-hall", "location-binding-hall", "location-resonance-chamber", "location-still-room", "location-common-riddlewind", "location-common-duskthorn"].contains(room.id)
        let cut = min(box.height * (ceremonial ? 0.32 : 0.18), ceremonial ? 14 : 4)
        var path = Path()
        path.move(to: CGPoint(x: box.minX + cut, y: box.minY))
        for p in [CGPoint(x: box.maxX - cut, y: box.minY), CGPoint(x: box.maxX, y: box.minY + cut),
                  CGPoint(x: box.maxX, y: box.maxY - cut), CGPoint(x: box.maxX - cut, y: box.maxY),
                  CGPoint(x: box.minX + cut, y: box.maxY), CGPoint(x: box.minX, y: box.maxY - cut),
                  CGPoint(x: box.minX, y: box.minY + cut)] { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    private func drawRooms(in context: inout GraphicsContext, plan: Plan, rooms: [AcademyChartRoom]? = nil) {
        for room in rooms ?? chart.rooms where room.isDrawn && room.room.form != .ring {
            let box = plan.box(of: room)
            let colour = room.id == selectedID ? LeafInk.gold : room.room.isBorrowed ? Self.borrowedInk : ink
            switch room.room.form {
            case .ring:
                break
            case .room:
                walls(roomOutline(room, box: box), inner: roomOutline(room, box: box.insetBy(dx: 3, dy: 3)), colour: colour, in: &context)
            case .doors:
                walls(roomOutline(room, box: box), inner: roomOutline(room, box: box.insetBy(dx: 3, dy: 3)), colour: colour, in: &context)
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
            drawRoomInterior(room, box: box, colour: colour, in: &context)
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
                // The Reader's private door, never a real-world position.
                let dot = CGRect(x: box.maxX - 9, y: box.maxY - 9, width: 5, height: 5)
                context.fill(Path(ellipseIn: dot), with: .color(colour))
                context.stroke(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)), with: .color(colour.opacity(0.6)), lineWidth: 0.5)
            }
        }
    }

    private func walls(_ outer: Path, inner: Path?, colour: Color, in context: inout GraphicsContext) {
        context.fill(outer, with: .color(Self.paper.opacity(0.2)))
        context.fill(outer, with: .color(colour.opacity(0.035)))
        context.stroke(outer, with: .color(colour.opacity(0.12)), lineWidth: 5)
        context.stroke(outer, with: .color(colour.opacity(0.85)), lineWidth: 1.5)
        if let inner {
            context.stroke(inner, with: .color(colour.opacity(0.5)), lineWidth: 0.5)
        }
    }

    /// Small surveyed things, mostly against the walls. The middle stays
    /// clear for the room's name and the living feet. The Dorm stays private.
    private func drawRoomInterior(_ room: AcademyChartRoom, box: CGRect, colour: Color, in context: inout GraphicsContext) {
        guard room.id != AcademyGeography.dormID else { return }
        var detail = context
        detail.clip(to: roomOutline(room, box: box.insetBy(dx: 4, dy: 4)))
        var fittings = Path()
        func table(_ rect: CGRect) {
            fittings.addRoundedRect(in: rect, cornerSize: CGSize(width: 1, height: 1))
            var x = rect.minX + 3
            while x < rect.maxX - 1 {
                fittings.addRect(CGRect(x: x, y: rect.minY - 2.5, width: 2, height: 1.5))
                fittings.addRect(CGRect(x: x, y: rect.maxY + 1, width: 2, height: 1.5))
                x += 7
            }
        }
        if room.id.hasPrefix("location-dorms-") || room.id == AcademyGeography.facultyID || room.id == AcademyGeography.guestID {
            for i in 0..<4 {
                let x = box.minX + 9 + CGFloat(i) * (box.width - 18) / 4
                let bed = CGRect(x: x, y: box.maxY - 15, width: 17, height: 10)
                fittings.addRect(bed)
                fittings.addRect(CGRect(x: bed.minX + 1, y: bed.minY + 1, width: 4, height: 8))
                fittings.move(to: CGPoint(x: bed.maxX + 4, y: box.maxY))
                fittings.addLine(to: CGPoint(x: bed.maxX + 4, y: box.maxY - 19))
            }
        }
        if room.id.hasPrefix("location-common-") {
            let chapterID = String(room.id.dropFirst("location-common-".count))
            switch chapterID {
            case "emberheart":
                fittings.addRect(CGRect(x: box.midX - 15, y: box.maxY - 16, width: 30, height: 11))
                for r in [CGFloat(3), CGFloat(6)] {
                    fittings.addEllipse(in: CGRect(x: box.midX - r, y: box.maxY - 10 - r, width: 2 * r, height: 2 * r))
                }
            case "mossbloom":
                for side in [box.minX + 9, box.maxX - 18] {
                    fittings.addRoundedRect(in: CGRect(x: side, y: box.midY + 1, width: 10, height: 21),
                                            cornerSize: CGSize(width: 3, height: 3))
                    for i in 0..<3 { fittings.addEllipse(in: CGRect(x: side + 2, y: box.midY + 3 + CGFloat(i) * 6, width: 6, height: 5)) }
                }
            case "tidecrest":
                for x in [box.minX + 24, box.maxX - 24] {
                    for r in [CGFloat(3), CGFloat(6)] {
                        fittings.addEllipse(in: CGRect(x: x - r, y: box.midY - r, width: r * 2, height: r * 2))
                    }
                }
            case "riddlewind":
                table(CGRect(x: box.minX + 14, y: box.maxY - 14, width: box.width - 28, height: 6))
            default:
                for x in [box.minX + 13, box.maxX - 13] {
                    fittings.move(to: CGPoint(x: x, y: box.maxY - 5))
                    fittings.addLine(to: CGPoint(x: x, y: box.midY))
                    fittings.addLine(to: CGPoint(x: x + 5, y: box.midY - 4))
                    fittings.move(to: CGPoint(x: x, y: box.midY + 6))
                    fittings.addLine(to: CGPoint(x: x - 4, y: box.midY + 2))
                }
            }
        }
        switch room.id {
        case "location-great-hall", "location-binding-hall":
            table(CGRect(x: box.minX + 12, y: box.maxY - 10, width: box.width - 24, height: 3))
            // Pillars holding the long roof, six along either side.
            for i in 0..<6 {
                let x = box.minX + 9 + CGFloat(i) * (box.width - 18) / 5
                for y in [box.minY + 5, box.maxY - 4] {
                    fittings.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                }
            }
        case "location-kitchens":
            // The hearth, stove rings and the long work surface.
            fittings.addRect(CGRect(x: box.minX + 7, y: box.maxY - 10, width: 21, height: 6))
            for i in 0..<3 {
                fittings.addEllipse(in: CGRect(x: box.minX + 9 + CGFloat(i) * 6, y: box.maxY - 9, width: 4, height: 4))
            }
            table(CGRect(x: box.midX + 4, y: box.maxY - 9, width: box.width * 0.32, height: 3))
        case "location-pantry", "location-old-reading-room", "location-inkworks":
            for y in [box.minY + 5, box.maxY - 6] {
                fittings.addRect(CGRect(x: box.minX + 6, y: y, width: box.width - 12, height: 2))
                var x = box.minX + 8
                while x < box.maxX - 7 {
                    fittings.move(to: CGPoint(x: x, y: y)); fittings.addLine(to: CGPoint(x: x, y: y + 2))
                    x += 3.5
                }
            }
        case "location-book-burrow":
            for x in [box.minX + 11, box.maxX - 11] {
                for y in [box.minY + 7, box.maxY - 7] {
                    fittings.addRoundedRect(in: CGRect(x: x - 3, y: y - 2, width: 6, height: 4),
                                            cornerSize: CGSize(width: 1.5, height: 1.5))
                    fittings.move(to: CGPoint(x: x - 4, y: y + 3))
                    fittings.addLine(to: CGPoint(x: x - 4, y: y - 3))
                    fittings.addLine(to: CGPoint(x: x + 4, y: y - 3))
                    fittings.addLine(to: CGPoint(x: x + 4, y: y + 3))
                }
            }
        case "location-glint-hall", "location-spark-annex":
            for x in [box.minX + 9, box.maxX - 9] {
                let y = box.maxY - 8
                fittings.move(to: CGPoint(x: x - 3, y: y)); fittings.addLine(to: CGPoint(x: x + 3, y: y))
                fittings.move(to: CGPoint(x: x, y: y - 3)); fittings.addLine(to: CGPoint(x: x, y: y + 3))
                fittings.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
            }
        case "location-resonance-chamber", "location-still-room":
            for x in [box.minX + 10, box.maxX - 10] {
                for r in [CGFloat(2), CGFloat(4), CGFloat(6)] {
                    fittings.addEllipse(in: CGRect(x: x - r, y: box.midY - r, width: r * 2, height: r * 2))
                }
            }
        default:
            break
        }
        // Architectural marks stay faint under name ribbons. Their geometry
        // makes the room recognisable even when its label is out of view.
        var floorMarks = Path()
        let floor = box.insetBy(dx: 9, dy: 9)
        if room.room.form == .room && box.height > 65 {
            var y = floor.minY + 20
            while y < floor.maxY {
                floorMarks.move(to: CGPoint(x: floor.minX, y: y))
                floorMarks.addLine(to: CGPoint(x: floor.maxX, y: y))
                var x = floor.minX + (Int(y) % 2 == 0 ? 0 : 11)
                while x < floor.maxX {
                    floorMarks.move(to: CGPoint(x: x, y: y))
                    floorMarks.addLine(to: CGPoint(x: x, y: min(y + 15, floor.maxY)))
                    x += 22
                }
                y += 15
            }
        }
        detail.stroke(floorMarks, with: .color(colour.opacity(0.075)), lineWidth: 0.45)
        switch room.id {
        case "location-great-hall":
            // Three long supper tables, with a processional aisle between.
            for i in 0..<3 {
                let y = box.minY + 41 + CGFloat(i) * (box.height - 68) / 3
                table(CGRect(x: box.minX + 26, y: y, width: box.width - 52, height: 9))
            }
        case "location-inkworks":
            for side in [box.minX + 12, box.maxX - 28] {
                for i in 0..<3 {
                    let bench = CGRect(x: side, y: box.minY + 40 + CGFloat(i) * 25, width: 16, height: 12)
                    fittings.addRect(bench)
                    fittings.addEllipse(in: CGRect(x: bench.midX - 1.5, y: bench.midY - 1.5, width: 3, height: 3))
                    fittings.move(to: CGPoint(x: bench.midX + 3, y: bench.midY))
                    fittings.addLine(to: CGPoint(x: bench.midX + 6, y: bench.midY - 5))
                }
            }
        case "location-bibliophonic-hall", "location-old-reading-room":
            for side in [box.minX + 8, box.maxX - 14] {
                var y = box.minY + 30
                while y < box.maxY - 10 {
                    fittings.addRect(CGRect(x: side, y: y, width: 6, height: 16))
                    for i in 0..<4 {
                        fittings.move(to: CGPoint(x: side, y: y + 3 + CGFloat(i) * 3))
                        fittings.addLine(to: CGPoint(x: side + 6, y: y + 3 + CGFloat(i) * 3))
                    }
                    y += 23
                }
            }
            fittings.addEllipse(in: CGRect(x: box.midX - 10, y: box.midY - 4, width: 20, height: 20))
        case "location-glint-hall":
            let centre = CGPoint(x: box.midX, y: box.midY + 6)
            for radius in [CGFloat(13), CGFloat(27), CGFloat(37)] {
                fittings.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                              width: radius * 2, height: radius * 2))
            }
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                let at = CGPoint(x: centre.x + CGFloat(cos(angle)) * 44, y: centre.y + CGFloat(sin(angle)) * 34)
                fittings.addRect(CGRect(x: at.x - 4, y: at.y - 2, width: 8, height: 4))
            }
        case "location-momentum-yard":
            for inset in [CGFloat(10), CGFloat(18), CGFloat(26)] {
                fittings.addRoundedRect(in: box.insetBy(dx: inset, dy: inset + 8),
                                        cornerSize: CGSize(width: 22, height: 22))
            }
        case "location-resonance-chamber":
            let centre = CGPoint(x: box.midX, y: box.midY + 5)
            for radius in [CGFloat(12), CGFloat(25), CGFloat(37)] {
                fittings.addArc(center: centre, radius: radius, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            }
            for i in 0..<5 {
                let x = box.minX + 17 + CGFloat(i) * (box.width - 34) / 4
                fittings.addEllipse(in: CGRect(x: x - 2, y: box.maxY - 12, width: 4, height: 4))
            }
        case "location-headmistress-tower", "location-quillquarium":
            let centre = CGPoint(x: box.midX, y: box.midY)
            let radius = min(box.width, box.height) * 0.37
            for i in 0..<14 {
                let angle = Double(i) * .pi / 7
                fittings.move(to: CGPoint(x: centre.x + CGFloat(cos(angle)) * radius * 0.66,
                                         y: centre.y + CGFloat(sin(angle)) * radius * 0.66))
                fittings.addLine(to: CGPoint(x: centre.x + CGFloat(cos(angle)) * radius,
                                            y: centre.y + CGFloat(sin(angle)) * radius))
            }
        case "location-kitchens":
            for side in [box.minX + 9, box.maxX - 22] {
                fittings.addRect(CGRect(x: side, y: box.minY + 27, width: 13, height: box.height - 43))
                for i in 0..<3 {
                    fittings.addEllipse(in: CGRect(x: side + 3, y: box.minY + 34 + CGFloat(i) * 14, width: 6, height: 6))
                }
            }
        default: break
        }
        detail.stroke(fittings, with: .color(colour.opacity(0.48)), lineWidth: 0.55)
        // Window slits cross the masonry rather than the clipped interior.
        if room.room.form == .room {
            var windows = Path()
            for x in [box.minX + box.width * 0.3, box.minX + box.width * 0.7] {
                windows.move(to: CGPoint(x: x - 3, y: box.minY + 1.5))
                windows.addLine(to: CGPoint(x: x + 3, y: box.minY + 1.5))
            }
            context.stroke(windows, with: .color(colour.opacity(0.65)), lineWidth: 0.8)
        }
        // Mason's diagonal hatching outside the surveyed walls.
        var masonry = context
        masonry.clip(to: roomOutline(room, box: box), options: .inverse)
        var hatch = Path()
        if room.room.form == .room || room.room.form == .doors {
            var x = box.minX + 3
            while x < box.maxX - 3 {
                hatch.move(to: CGPoint(x: x, y: box.maxY + 1))
                hatch.addLine(to: CGPoint(x: x + 2.5, y: box.maxY + 4))
                x += 4
            }
            var y = box.minY + 3
            while y < box.maxY - 3 {
                hatch.move(to: CGPoint(x: box.maxX + 1, y: y))
                hatch.addLine(to: CGPoint(x: box.maxX + 4, y: y + 2.5))
                y += 4
            }
        }
        masonry.stroke(hatch, with: .color(colour.opacity(0.27)), lineWidth: 0.5)
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


}

// MARK: - Doors beyond the Outer Stacks

/// New parchment grows north. Each bay has a crooked aisle, room for a
/// legible name, and a doorway whose place stays fixed when another is kept.
private struct AcademyAnchorExtension: View {
    let rooms: [AcademyAnchorRoom]
    @Binding var selectedID: String?
    var isInteractive: Bool
    var animates: Bool
    var onDiscover: (String) -> Void

    static let rowPitch: CGFloat = 180
    static let chamberHeight: CGFloat = 86

    static func height(for count: Int) -> CGFloat {
        count > 0 ? CGFloat((count + 1) / 2) * rowPitch + 80 : 0
    }

    static func box(at index: Int, rooms: [AcademyAnchorRoom]) -> CGRect {
        let seed = UInt64(truncatingIfNeeded: rooms[index].anchor.id.stableHash)
        let left = index % 2 == 0
        let x = (left ? CGFloat(132) : 388) + CGFloat(seed % 13) - 6
        let y = height(for: rooms.count) - 94 - CGFloat(index / 2) * rowPitch
            + (left ? -10 : 10) + CGFloat((seed / 13) % 13) - 6
        let width = CGFloat(188 + (seed / 169) % 9)
        return CGRect(x: x - width / 2, y: y - 64, width: width, height: 128)
    }

    private func spineX(at row: Int) -> CGFloat {
        let seed = UInt64(truncatingIfNeeded: rooms.first?.anchor.id.stableHash ?? 0)
        return 260 + CGFloat((seed % 29 + UInt64(row % 29) * 11) % 29) - 14
    }

    var body: some View {
        let height = Self.height(for: rooms.count)
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<Int(ceil(height / 512)), id: \.self) { tile in
                    let top = CGFloat(tile) * 512
                    Canvas { context, _ in
                        context.translateBy(x: 0, y: -top)
                        drawPassage(in: &context, height: height, top: top)
                    }
                    .frame(height: min(512, height - top))
                }
            }
            .allowsHitTesting(false)
            VStack(spacing: 3) {
                Text("BEYOND THE OUTER STACKS")
                    .font(.custom("Baskerville-SemiBold", size: 11)).tracking(1.6)
                Text(rooms.contains(where: { $0.foldedWords != nil })
                     ? "Hold a room. I've tucked your words inside." : "The shelves made room.")
                    .font(.custom("Baskerville-Italic", size: 10))
            }
            .foregroundStyle(AcademyMapDrawing.mapInk.opacity(0.85))
            .frame(width: 440).position(x: 260, y: 40)
            .allowsHitTesting(false)
            ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                let box = Self.box(at: index, rooms: rooms)
                AcademyAnchorChamber(room: room, isSelected: selectedID == room.id,
                                     doorOnRight: index % 2 == 0, animates: animates,
                                     onSelect: {
                    BookFeedback.play(.tap)
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedID = selectedID == room.id ? nil : room.id
                    }
                }, onDiscover: { onDiscover(room.id) })
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)
                .allowsHitTesting(isInteractive)
            }
        }
        .frame(width: 520, height: height).clipped()
    }

    /// The growing gallery is painted in short strips, so a long ledger
    /// never asks Canvas for one enormous backing texture.
    private func drawPassage(in context: inout GraphicsContext, height: CGFloat, top: CGFloat) {
        let ink = AcademyMapDrawing.mapInk
        for inset in [CGFloat(10), CGFloat(13.5)] {
            var frame = Path()
            frame.move(to: CGPoint(x: inset, y: height))
            frame.addLine(to: CGPoint(x: inset, y: inset))
            frame.addLine(to: CGPoint(x: 520 - inset, y: inset))
            frame.addLine(to: CGPoint(x: 520 - inset, y: height))
            context.stroke(frame, with: .color(ink.opacity(inset == 10 ? 0.42 : 0.24)), lineWidth: 0.6)
        }
        var aisle = Path()
        let rows = (rooms.count + 1) / 2
        let firstRow = max(0, Int(floor((height - top - 512 - 24) / Self.rowPitch)))
        let lastRow = min(rows - 1, Int(ceil((height - top + 24) / Self.rowPitch)))
        for row in firstRow...lastRow {
            let bend = height - 94 - CGFloat(row) * Self.rowPitch + 70
            if row == firstRow {
                aisle.move(to: CGPoint(x: row == 0 ? 260 : spineX(at: row - 1),
                                       y: row == 0 ? height : bend))
            }
            aisle.addLine(to: CGPoint(x: row == 0 ? 260 : spineX(at: row - 1), y: bend))
            aisle.addLine(to: CGPoint(x: spineX(at: row), y: bend))
            aisle.addLine(to: CGPoint(x: spineX(at: row), y: bend - Self.rowPitch))
        }
        for index in rooms.indices where (firstRow...lastRow).contains(index / 2) {
            let box = Self.box(at: index, rooms: rooms)
            let y = box.minY + Self.chamberHeight / 2
            aisle.move(to: CGPoint(x: spineX(at: index / 2), y: y))
            aisle.addLine(to: CGPoint(x: index % 2 == 0 ? box.maxX : box.minX, y: y))
        }
        context.stroke(aisle, with: .color(ink.opacity(0.12)),
                       style: StrokeStyle(lineWidth: 13, lineJoin: .round))
        context.stroke(aisle, with: .color(ink.opacity(0.65)),
                       style: StrokeStyle(lineWidth: 10.5, lineJoin: .round))
        context.stroke(aisle, with: .color(AcademyMapDrawing.paper),
                       style: StrokeStyle(lineWidth: 8, lineJoin: .round))
        for x in [CGFloat(520) / 3, CGFloat(520) * 2 / 3] {
            let fold = CGRect(x: x - 2, y: 0, width: 4, height: height)
            context.fill(Path(fold), with: .linearGradient(
                Gradient(colors: [ink.opacity(0), ink.opacity(0.06), .white.opacity(0.18), ink.opacity(0)]),
                startPoint: CGPoint(x: fold.minX, y: 0), endPoint: CGPoint(x: fold.maxX, y: 0)))
        }
    }
}

/// Fictional chambers, never inferred floor plans of somebody's real home.
private struct AcademyAnchorShape: Shape {
    let kind: AnchorKind
    let seed: Int

    func path(in rect: CGRect) -> Path {
        if kind == .sense || kind == .rest {
            return Path(roundedRect: rect, cornerRadius: kind == .rest ? 24 : 12)
        }
        let variation = CGFloat(UInt64(truncatingIfNeeded: seed) % 4)
        let cut: CGFloat = kind == .embark ? rect.height / 2 : 9 + variation
        let corners: [CGPoint]
        if kind == .write {
            let dx: CGFloat = 18 + variation, dy: CGFloat = 14
            corners = [CGPoint(x: rect.minX + dx, y: rect.minY), CGPoint(x: rect.maxX - dx, y: rect.minY),
                       CGPoint(x: rect.maxX - dx, y: rect.minY + dy), CGPoint(x: rect.maxX, y: rect.minY + dy),
                       CGPoint(x: rect.maxX, y: rect.maxY - dy), CGPoint(x: rect.maxX - dx, y: rect.maxY - dy),
                       CGPoint(x: rect.maxX - dx, y: rect.maxY), CGPoint(x: rect.minX + dx, y: rect.maxY),
                       CGPoint(x: rect.minX + dx, y: rect.maxY - dy), CGPoint(x: rect.minX, y: rect.maxY - dy),
                       CGPoint(x: rect.minX, y: rect.minY + dy), CGPoint(x: rect.minX + dx, y: rect.minY + dy)]
        } else {
            corners = [CGPoint(x: rect.minX + cut, y: rect.minY), CGPoint(x: rect.maxX - cut, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.minY + cut), CGPoint(x: rect.maxX, y: rect.maxY - cut),
                       CGPoint(x: rect.maxX - cut, y: rect.maxY), CGPoint(x: rect.minX + cut, y: rect.maxY),
                       CGPoint(x: rect.minX, y: rect.maxY - cut), CGPoint(x: rect.minX, y: rect.minY + cut)]
        }
        var path = Path()
        path.move(to: corners[0])
        for p in corners.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

/// Tiny floor-plan drawings. Only this little ink breathes; the Academy's
/// routes and the Reader's words are not recomputed for an animation frame.
private struct AcademyAnchorIllustration: View {
    let motif: AcademyAnchorImprint.Motif
    let seed: Int
    let quiet: Bool
    let animates: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var moving: Bool { animates && !reduceMotion && [.water, .hearth, .lantern].contains(motif) }
    private var wash: Color {
        switch motif {
        case .water: return Color(red: 0.27, green: 0.46, blue: 0.48)
        case .grove: return Color(red: 0.34, green: 0.43, blue: 0.26)
        case .hearth, .lantern: return Color(red: 0.65, green: 0.36, blue: 0.16)
        default: return AcademyMapDrawing.mapInk
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !moving)) { timeline in
            Canvas { context, size in
                context.scaleBy(x: size.width / 192, y: size.height / 86)
                let time = moving ? timeline.date.timeIntervalSinceReferenceDate : 0
                let phase = moving ? sin(time * 0.65 + Double(UInt64(truncatingIfNeeded: seed) % 37)) : 0
                draw(in: &context, phase: phase)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, phase: Double) {
        let ink = AcademyMapDrawing.mapInk
        let offset = CGFloat(UInt64(truncatingIfNeeded: seed) % 7) - 3
        func stroke(_ path: Path, _ alpha: Double = 0.65, _ width: CGFloat = 0.8) {
            context.stroke(path, with: .color(ink.opacity(alpha)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func line(_ points: [CGPoint], _ alpha: Double = 0.65, _ width: CGFloat = 0.8) {
            var path = Path()
            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
            }
            stroke(path, alpha, width)
        }
        func oval(_ rect: CGRect, _ alpha: Double = 0.6) { stroke(Path(ellipseIn: rect), alpha) }
        func block(_ rect: CGRect) {
            context.fill(Path(rect), with: .color(wash.opacity(0.10)))
            stroke(Path(rect), 0.55)
        }
        switch motif {
        case .water:
            for i in 0..<5 {
                let y = 25 + CGFloat(i) * 8
                var ripple = Path()
                ripple.move(to: CGPoint(x: 43, y: y))
                ripple.addCurve(to: CGPoint(x: 151, y: y + 1),
                                control1: CGPoint(x: 72, y: y - 9 + CGFloat(phase)),
                                control2: CGPoint(x: 121, y: y + 10 - CGFloat(phase)))
                context.stroke(ripple, with: .color(wash.opacity(0.4)), lineWidth: 0.85)
            }
            for i in 0..<4 { oval(CGRect(x: 77 + CGFloat(i) * 11, y: 24 + CGFloat(i) * 9, width: 7, height: 4), 0.65) }
            line([CGPoint(x: 118, y: 35), CGPoint(x: 142, y: 35), CGPoint(x: 135, y: 41), CGPoint(x: 124, y: 41), CGPoint(x: 118, y: 35)])
            line([CGPoint(x: 128, y: 35), CGPoint(x: 128, y: 19), CGPoint(x: 139, y: 32), CGPoint(x: 128, y: 32)])
        case .grove:
            for i in 0..<3 {
                let x = 48 + CGFloat(i) * 43
                block(CGRect(x: x, y: 46, width: 25, height: 18))
                for j in 0..<4 { line([CGPoint(x: x + 5 + CGFloat(j) * 5, y: 60), CGPoint(x: x + 6 + CGFloat(j) * 5, y: 50)], 0.28) }
                let centre = CGPoint(x: x + 12 + offset, y: 28)
                oval(CGRect(x: centre.x - 12, y: centre.y - 12, width: 24, height: 24), 0.45)
                oval(CGRect(x: centre.x - 9, y: centre.y - 8, width: 17, height: 16), 0.3)
                line([CGPoint(x: centre.x, y: 41), centre, CGPoint(x: centre.x - 5, y: centre.y - 5)], 0.55)
                line([centre, CGPoint(x: centre.x + 5, y: centre.y - 6)], 0.5)
            }
            line([CGPoint(x: 39, y: 70), CGPoint(x: 152, y: 70)], 0.25)
        case .hearth:
            block(CGRect(x: 57, y: 36, width: 35, height: 26))
            oval(CGRect(x: 65, y: 43, width: 18, height: 12))
            line([CGPoint(x: 67, y: 48), CGPoint(x: 73, y: 41), CGPoint(x: 78, y: 49), CGPoint(x: 73, y: 54)], 0.7)
            oval(CGRect(x: 109, y: 42, width: 19, height: 13))
            oval(CGRect(x: 125, y: 45, width: 8, height: 7))
            line([CGPoint(x: 110, y: 45), CGPoint(x: 104, y: 40), CGPoint(x: 110, y: 52)])
            line([CGPoint(x: 117, y: 42), CGPoint(x: 117, y: 38), CGPoint(x: 122, y: 38)])
            for i in 0..<3 {
                var curl = Path()
                let x = 111 + CGFloat(i) * 7
                curl.move(to: CGPoint(x: x, y: 34))
                curl.addCurve(to: CGPoint(x: x + CGFloat(phase) * 2, y: 17),
                              control1: CGPoint(x: x - 6, y: 29), control2: CGPoint(x: x + 7, y: 23))
                stroke(curl, 0.3, 0.65)
            }
            line([CGPoint(x: 102, y: 60), CGPoint(x: 140, y: 60)], 0.4)
        case .library:
            for x in [CGFloat(42), CGFloat(136)] {
                block(CGRect(x: x, y: 24, width: 15, height: 38))
                for i in 0..<9 { line([CGPoint(x: x + 2, y: 27 + CGFloat(i) * 3.7), CGPoint(x: x + 12, y: 28 + CGFloat(i) * 3.7)], 0.5, 0.6) }
            }
            block(CGRect(x: 75, y: 31, width: 43, height: 25))
            line([CGPoint(x: 80, y: 35), CGPoint(x: 94, y: 38), CGPoint(x: 108, y: 35), CGPoint(x: 108, y: 48), CGPoint(x: 94, y: 51), CGPoint(x: 80, y: 48), CGPoint(x: 80, y: 35)], 0.75)
            line([CGPoint(x: 94, y: 38), CGPoint(x: 94, y: 51)], 0.6)
            oval(CGRect(x: 87, y: 61, width: 18, height: 6), 0.5)
        case .way:
            var walk = Path()
            walk.move(to: CGPoint(x: 49, y: 64))
            walk.addCurve(to: CGPoint(x: 143, y: 20), control1: CGPoint(x: 128, y: 75), control2: CGPoint(x: 65, y: 15))
            context.stroke(walk, with: .color(wash.opacity(0.2)), lineWidth: 8)
            stroke(walk, 0.4, 0.6)
            line([CGPoint(x: 78, y: 28), CGPoint(x: 113, y: 58)], 0.8)
            line([CGPoint(x: 85, y: 23), CGPoint(x: 120, y: 53)], 0.8)
            for i in 0..<6 {
                let t = CGFloat(i) / 5
                line([CGPoint(x: 78 + 35 * t, y: 28 + 30 * t), CGPoint(x: 85 + 35 * t, y: 23 + 30 * t)], 0.5)
            }
            oval(CGRect(x: 48, y: 25, width: 15, height: 12), 0.3)
            oval(CGRect(x: 135, y: 56, width: 13, height: 10), 0.3)
        case .lantern:
            context.fill(Path(ellipseIn: CGRect(x: 65, y: 13, width: 64, height: 59)),
                         with: .radialGradient(Gradient(colors: [wash.opacity(0.13 + phase * 0.025), wash.opacity(0)]),
                                               center: CGPoint(x: 97, y: 43), startRadius: 4, endRadius: 35))
            oval(CGRect(x: 72, y: 20, width: 49, height: 47), 0.24)
            oval(CGRect(x: 78, y: 26, width: 37, height: 35), 0.22)
            block(CGRect(x: 88, y: 31, width: 18, height: 24))
            line([CGPoint(x: 87, y: 31), CGPoint(x: 97, y: 24), CGPoint(x: 107, y: 31)])
            oval(CGRect(x: 93, y: 19, width: 8, height: 6), 0.6)
            line([CGPoint(x: 97, y: 37), CGPoint(x: 97, y: 49)], 0.8)
            for p in [CGPoint(x: 52, y: 28), CGPoint(x: 137, y: 27), CGPoint(x: 144, y: 59), CGPoint(x: 52, y: 59)] {
                line([CGPoint(x: p.x - 3, y: p.y), CGPoint(x: p.x + 3, y: p.y)], 0.5)
                line([CGPoint(x: p.x, y: p.y - 3), CGPoint(x: p.x, y: p.y + 3)], 0.5)
            }
        case .threshold:
            block(CGRect(x: 70, y: 20, width: 32, height: 44))
            block(CGRect(x: 74, y: 24, width: 24, height: 36))
            oval(CGRect(x: 91, y: 43, width: 2, height: 2), 0.8)
            oval(CGRect(x: 122, y: 34, width: 10, height: 10), 0.8)
            line([CGPoint(x: 127, y: 44), CGPoint(x: 127, y: 60), CGPoint(x: 133, y: 60), CGPoint(x: 133, y: 56)], 0.8)
        }
        if quiet {
            // Dust belongs to the Book's last kept check-in, never a claim
            // that the Reader has stopped going to their real place.
            for i in 0..<13 {
                let x = 37 + CGFloat((i * 37 + Int(UInt64(truncatingIfNeeded: seed) % 101)) % 117)
                let y = 16 + CGFloat((i * 17) % 51)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.9, height: 0.9)), with: .color(ink.opacity(0.32)))
            }
        }
    }
}

private struct AcademyAnchorChamber: View {
    let room: AcademyAnchorRoom
    var isSelected: Bool
    var doorOnRight: Bool
    var animates: Bool
    var onSelect: () -> Void
    var onDiscover: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inked = false

    private var ink: Color { isSelected ? LeafInk.gold : AcademyMapDrawing.mapInk }
    private var shape: AcademyAnchorShape {
        let kind: AnchorKind
        switch room.imprint.motif {
        case .water: kind = .rest
        case .grove: kind = .sense
        case .library: kind = .write
        case .way: kind = .embark
        default: kind = room.anchor.kind
        }
        return AcademyAnchorShape(kind: kind, seed: room.anchor.id.stableHash)
    }
    private var tally: String {
        let returns = max(0, room.anchor.visitCount - 1)
        let visits = returns == 0 ? "a door kept" : returns == 1 ? "one return" : "\(returns) returns"
        return room.entry.keptCount == 0 ? visits : visits + " · \(room.entry.keptCount) \(room.entry.keptCount == 1 ? "Page" : "Pages")"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                VStack(spacing: 3) {
                    ZStack {
                        shape.fill(AcademyMapDrawing.paper.opacity(0.65))
                        shape.stroke(ink.opacity(0.12), lineWidth: 4.5)
                        shape.trim(from: 0, to: inked ? 1 : 0)
                            .stroke(ink.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                        shape.stroke(ink.opacity(0.35), lineWidth: 0.55).padding(3)
                        AcademyAnchorIllustration(motif: room.imprint.motif, seed: room.anchor.id.stableHash,
                                                  quiet: room.quietDays != nil, animates: animates && isSelected)
                            .clipShape(shape).opacity(inked ? 1 : 0)
                        Canvas { context, size in
                            var shelves = Path()
                            let volumes = min(18, 6 + max(0, room.anchor.visitCount))
                            for i in 0..<volumes {
                                shelves.addRect(CGRect(x: 42 + CGFloat(i) * 6, y: size.height - 5, width: 2.5, height: 3))
                            }
                            var shelfInk = context
                            shelfInk.clip(to: shape.path(in: CGRect(origin: .zero, size: size)))
                            shelfInk.stroke(shelves, with: .color(ink.opacity(0.45)), lineWidth: 0.5)
                            let doorX = doorOnRight ? size.width : 0
                            context.fill(Path(CGRect(x: doorX - 4, y: size.height / 2 - 4, width: 8, height: 8)),
                                         with: .color(AcademyMapDrawing.paper))
                            var swing = Path()
                            let hinge = CGPoint(x: doorX, y: size.height / 2 - 4)
                            swing.move(to: hinge)
                            swing.addLine(to: CGPoint(x: doorX + (doorOnRight ? -7 : 7), y: hinge.y))
                            swing.addArc(center: hinge, radius: 7, startAngle: .degrees(doorOnRight ? 180 : 0),
                                         endAngle: .degrees(90), clockwise: doorOnRight)
                            context.stroke(swing, with: .color(ink.opacity(0.55)), lineWidth: 0.6)
                        }
                    }
                    .frame(height: AcademyAnchorExtension.chamberHeight)
                    Text(room.anchor.name)
                        .font(.custom("Baskerville-SemiBold", size: 12.5))
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 27)
                    Text(tally).font(.custom("Baskerville-Italic", size: 8.5)).lineLimit(1)
                }
                .foregroundStyle(ink.opacity(0.9))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                if room.foldedWords != nil { onDiscover() }
                else { onSelect() }
            })
            .accessibilityLabel(room.anchor.name)
            .accessibilityValue(tally)
            .accessibilityHint("Opens its room and Pages kept here")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            if room.foldedWords != nil {
                Button(action: onDiscover) {
                    Canvas { context, size in
                        let ink = AcademyMapDrawing.mapInk
                        let x = size.width / 2, y = size.height / 2
                        var fold = Path()
                        fold.move(to: CGPoint(x: x - 8, y: y - 7))
                        fold.addLine(to: CGPoint(x: x + 8, y: y - 7))
                        fold.addLine(to: CGPoint(x: x + 8, y: y + 7))
                        fold.addLine(to: CGPoint(x: x - 8, y: y + 7))
                        fold.closeSubpath()
                        context.fill(fold, with: .color(AcademyMapDrawing.paper))
                        context.stroke(fold, with: .color(ink.opacity(0.7)), lineWidth: 0.8)
                        var seam = Path()
                        seam.move(to: CGPoint(x: x - 8, y: y - 7))
                        seam.addLine(to: CGPoint(x: x, y: y + 1))
                        seam.addLine(to: CGPoint(x: x + 8, y: y - 7))
                        context.stroke(seam, with: .color(ink.opacity(0.55)), lineWidth: 0.7)
                    }
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unfold your words from \(room.anchor.name)")
                .offset(x: -2, y: 0)
            }
        }
        .opacity(inked ? 1 : 0.35)
        .onAppear {
            if animates && !reduceMotion { withAnimation(.easeInOut(duration: 0.85)) { inked = true } }
            else { inked = true }
        }
    }
}

private struct AcademyAnchorNote: View {
    let room: AcademyAnchorRoom
    var showsFoldedWords: Bool
    var onUnfold: () -> Void
    var onOpenPage: (BookPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(room.anchor.name)
                .font(.system(size: 17, weight: .semibold, design: .serif))
            Text("A door in the Outer Stacks.")
                .font(.system(size: 12, design: .serif)).italic()
            if let line = room.entry.returnsLine { Text(line).font(.system(size: 12, design: .serif)) }
            if let folded = room.foldedWords {
                if showsFoldedWords {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(folded.page == nil ? "You gave me this when you made the door:" : "You kept this here:")
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                        Text(folded.text).font(.system(size: 15, design: .serif)).italic()
                            .textSelection(.enabled)
                        if let page = folded.page {
                            Button {
                                BookFeedback.play(.tap)
                                onOpenPage(page)
                            } label: {
                                Text("Open this Page").font(.system(size: 13, design: .serif))
                                    .underline().padding(.vertical, 7)
                            }
                            .buttonStyle(.plain).foregroundStyle(LeafInk.gold)
                        }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AcademyMapDrawing.mapInk.opacity(0.045))
                    .transition(.opacity)
                } else {
                    Button(action: onUnfold) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope").font(.system(size: 13))
                            Text("Something's folded here. Open it?")
                                .font(.system(size: 14, design: .serif)).italic()
                        }
                        .padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(LeafInk.gold)
                    .accessibilityLabel("Unfold your words")
                }
            }
            // The original words remain available even when a later sentence
            // is tucked into this room. Don't print the fallback twice.
            if room.foldedWords?.page != nil, let words = room.anchor.playerWords.nonEmpty {
                Text("What you gave me:").font(.system(size: 12, weight: .semibold, design: .serif))
                Text(words).font(.system(size: 14, design: .serif)).italic()
                    .textSelection(.enabled)
            }
            if let days = room.quietDays {
                Text("I haven't kept a return here for \(days) days. The door still works.")
                    .font(.system(size: 12, design: .serif)).italic()
            }
            if let description = room.anchor.outerStacksRoom.nonEmpty {
                Text("The room beyond the door:").font(.system(size: 12, weight: .semibold, design: .serif))
                Text(description).font(.system(size: 13, design: .serif))
            }
            if let keeper = room.anchor.fae.nonEmpty {
                Text("\(keeper) keeps this room.").font(.system(size: 12, design: .serif)).italic()
            }
            if let rule = room.anchor.localRule.nonEmpty {
                Text(rule).font(.system(size: 13, design: .serif))
            }
            if !room.pages.isEmpty {
                Text("Pages kept here:").font(.system(size: 12, weight: .semibold, design: .serif))
                ForEach(room.pages) { page in
                    Button {
                        BookFeedback.play(.tap)
                        onOpenPage(page)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "bookmark").font(.system(size: 11))
                            Text("\(page.type.title), \(page.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 13, design: .serif)).underline()
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(LeafInk.gold)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            // The Gazetteer already chooses what Maps may reveal for this
            // Anchor. Reuse its plate and wording, including veiled places.
            if let plate = room.entry.plate {
                MapPlateView(spec: plate, title: room.entry.name)
            }
            if let line = room.entry.kindLine { Text(line).font(.system(size: 12, design: .serif)) }
        }
        .foregroundStyle(AcademyMapDrawing.mapInk.opacity(0.9))
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var selectedCastID: String? = nil
    var paperHeight: CGFloat = AcademyMapDrawing.size.height

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stride: CGFloat = 6
    private static let trail = 7
    private var ink: Color { AcademyMapDrawing.mapInk }

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
                    ribbon(pose.walker, at: pose.ribbonAt, drop: pose.isWalking ? 0 : pose.walker.ribbonDrop,
                           compact: !pose.isWalking && pose.walker.compact)
                }
            }
        }
        .frame(width: AcademyMapDrawing.size.width, height: paperHeight)
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
        if let walk = walker.walk, now < walk.startedAt { return nil }
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
        // Arrived. Every name stays on the paper, including a crowded room.
        guard walker.isShownAtRest else { return nil }

        let phase = Double(UInt64(truncatingIfNeeded: walker.id.stableHash) % 1000) / 1000
        let feet = CGPoint(x: walker.at.x - (walker.compact ? 22 : 0), y: walker.at.y)
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
            let shifting = moving && walker.person.why != .sleeping && beat < 0.1
            return Pose(walker: walker, prints: [
                Print(at: CGPoint(x: feet.x - 2.2, y: feet.y - 1.8), facing: walker.heading, isLeft: true, alpha: 1),
                Print(at: CGPoint(x: feet.x + 2.2 + (shifting ? 0.9 : 0), y: feet.y + 1.8 - (shifting ? 0.8 : 0)),
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
    private func ribbon(_ walker: AcademyMapDrawing.Walker, at point: CGPoint, drop: CGFloat, compact: Bool) -> some View {
        let colour = selectedCastID == walker.id ? LeafInk.gold
            : walker.person.isVisitor ? AcademyMapDrawing.borrowedInk : ink.opacity(0.9)
        let label = Text(walker.person.mapName)
            .font(.custom("Baskerville-Italic", size: compact ? 9.2 : 10))
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: compact ? 43 : 58)
            .foregroundStyle(colour)
            .opacity(selectedCastID == nil || selectedCastID == walker.id ? 1 : 0.6)
            .padding(.horizontal, compact ? 1 : 4)
            .padding(.vertical, 1)
            .background(RibbonShape().fill(AcademyMapDrawing.paper))
            .overlay(RibbonShape().stroke(ink.opacity(0.6), lineWidth: 0.6))
            .padding(.top, compact ? 0 : 12)
        let centre = CGPoint(x: point.x + (compact ? 7 : 0), y: point.y + (compact ? 0 : 5) + drop)
        if walker.person.isVisitor || !isInteractive {
            // A visitor out of another book has no page here to open.
            label
                .position(centre)
                .allowsHitTesting(false)
                .accessibilityLabel("\(walker.person.name), \(walker.person.why == .sleeping ? "asleep" : "here right now")")
        } else {
            Button {
                BookFeedback.play(.tap)
                onOpenCastMember(walker.person.characterID)
            } label: {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(centre)
            .accessibilityLabel("\(walker.person.name), \(walker.person.why == .sleeping ? "asleep" : "here right now")")
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
