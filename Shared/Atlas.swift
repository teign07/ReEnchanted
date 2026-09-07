import Foundation

// MARK: - The Atlas

/// Which layer a mark belongs to.
///
/// Deliberately a string wrapper rather than an enum. A closed enum would mean
/// every later feature that wants to put something on the map — local lore, an
/// errand, a correspondence about a place — has to edit this file. Layers are
/// meant to arrive from outside.
struct AtlasLayerID: RawRepresentable, Hashable, Codable, Sendable {
    var rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    /// The reader's own Anchors.
    static let places = AtlasLayerID("places")
    /// Pages kept somewhere, by their own coordinates.
    static let kept = AtlasLayerID("kept")
}

/// One thing on the map.
///
/// A mark is deliberately dumb: coordinates, something to show, and some lines
/// to read when it is opened. Whatever put it there decides what those say, so
/// a lore mark and an Anchor mark travel through the same pipe.
struct AtlasMark: Identifiable, Equatable {
    var id: String
    var layer: AtlasLayerID
    var latitude: Double
    var longitude: Double
    var title: String
    var subtitle: String?
    /// SF Symbol.
    var glyph: String
    /// Lines shown when the reader opens the mark. The Book's voice, or the
    /// reader's own words — whatever the layer knows.
    var detail: [String]
    /// Sort weight within a layer. Heavier marks survive thinning first.
    var weight: Int

    var isPlaceable: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

/// A named set of marks the reader can turn on and off.
struct AtlasLayer: Identifiable, Equatable {
    var id: AtlasLayerID
    var title: String
    /// The Book saying what this layer is. Not a caption written by somebody
    /// outside the Book.
    var note: String
    var glyph: String
    var isOnByDefault: Bool
    var marks: [AtlasMark]
}

/// Everything a layer is allowed to read.
///
/// Grows a field when a layer needs something new, so a layer never reaches
/// past this into app state.
struct AtlasSources {
    var anchors: [AnchorRecord] = []
    var days: [BookDay] = []
    var now: Date = Date()
    var calendar: Calendar = .current
}

/// One source of marks.
///
/// Adding a layer is one type conforming to this and one line in
/// `AtlasProjection.registered`. No enum case, no switch, no change to the map
/// itself — the same shape `LoomProjector` uses, for the same reason.
protocol AtlasLayerSource {
    static var layer: AtlasLayerID { get }
    static var title: String { get }
    static var note: String { get }
    static var glyph: String { get }
    static var isOnByDefault: Bool { get }
    static func marks(from sources: AtlasSources) -> [AtlasMark]
}

enum AtlasProjection {
    /// The layers that exist. Add to this list, not to the map.
    static let registered: [any AtlasLayerSource.Type] = [
        PlacesAtlasLayer.self,
        KeptPagesAtlasLayer.self
    ]

    static func layers(from sources: AtlasSources) -> [AtlasLayer] {
        // An explicit closure rather than `.map(\.layer)`: a key-path map over
        // an array of existentials crashes SILGen on this toolchain.
        var built: [AtlasLayer] = []
        for source in registered {
            let marks = source.marks(from: sources).filter { $0.isPlaceable }
            guard !marks.isEmpty else { continue }
            built.append(AtlasLayer(
                id: source.layer,
                title: source.title,
                note: source.note,
                glyph: source.glyph,
                isOnByDefault: source.isOnByDefault,
                marks: marks.sorted { $0.weight == $1.weight ? $0.id < $1.id : $0.weight > $1.weight }
            ))
        }
        return built
    }

    /// Every mark from the layers currently switched on.
    static func marks(in layers: [AtlasLayer], showing on: Set<AtlasLayerID>) -> [AtlasMark] {
        layers.filter { on.contains($0.id) }.flatMap(\.marks)
    }

    /// What the map should frame when it opens: everything, or nothing.
    static func span(of marks: [AtlasMark]) -> (latitude: Double, longitude: Double, latitudeSpan: Double, longitudeSpan: Double)? {
        guard !marks.isEmpty else { return nil }
        let latitudes = marks.map(\.latitude)
        let longitudes = marks.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else { return nil }
        // A single mark has no span, and a map framed to a zero span shows the
        // inside of a pin. Give it a few streets.
        let latitudeSpan = max((maxLatitude - minLatitude) * 1.4, 0.01)
        let longitudeSpan = max((maxLongitude - minLongitude) * 1.4, 0.01)
        return (
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2,
            latitudeSpan: latitudeSpan,
            longitudeSpan: longitudeSpan
        )
    }
}

// MARK: - The layers that ship

/// The reader's own Anchors.
enum PlacesAtlasLayer: AtlasLayerSource {
    static let layer = AtlasLayerID.places
    static let title = "Places you named"
    static let note = "Everywhere you stopped and told me what to call it."
    static let glyph = "mappin.and.ellipse"
    static let isOnByDefault = true

    static func marks(from sources: AtlasSources) -> [AtlasMark] {
        let entries = Gazetteer.entries(anchors: sources.anchors, days: sources.days)
        var byID: [String: GazetteerEntry] = [:]
        for entry in entries { byID[entry.id] = entry }

        return sources.anchors.map { anchor in
            let entry = byID[anchor.id]
            var detail: [String] = []
            // Veiling is the Gazetteer's decision and is not re-made here.
            if let kind = entry?.kindLine { detail.append(kind) }
            if let made = entry?.madeLine { detail.append(made) }
            if let returns = entry?.returnsLine { detail.append(returns) }
            detail.append(contentsOf: entry?.happenings ?? [])
            return AtlasMark(
                id: "places:\(anchor.id)",
                layer: layer,
                latitude: anchor.latitude,
                longitude: anchor.longitude,
                title: anchor.name,
                subtitle: entry?.kindLine,
                glyph: "mappin.circle.fill",
                detail: detail,
                weight: 100 + (entry?.keptCount ?? 0)
            )
        }
    }
}

/// Pages kept somewhere, by their own coordinates.
///
/// These only exist for Pages kept after the archive was allowed to remember
/// where it was, so an old archive draws nothing here and that is correct.
enum KeptPagesAtlasLayer: AtlasLayerSource {
    static let layer = AtlasLayerID.kept
    static let title = "What you wrote, where"
    static let note = "Pages that remember the ground they were kept on."
    static let glyph = "text.viewfinder"
    static let isOnByDefault = false

    static func marks(from sources: AtlasSources) -> [AtlasMark] {
        var marks: [AtlasMark] = []
        for day in sources.days {
            for page in day.pages {
                guard let latitude = page.context?.latitude,
                      let longitude = page.context?.longitude else { continue }
                let written = Gazetteer.happening(page)
                marks.append(AtlasMark(
                    id: "kept:\(page.id)",
                    layer: layer,
                    latitude: latitude,
                    longitude: longitude,
                    title: page.type.shortTitle,
                    subtitle: page.context?.placeKind.map(SpellCastMemory.humanisedPlace),
                    glyph: "circle.fill",
                    detail: [written].compactMap { $0 },
                    weight: 10
                ))
            }
        }
        return marks
    }
}

// MARK: - Plates

/// Where a plate is going to end up.
///
/// This is a privacy decision, not a layout one. A chart on the reader's own
/// screen may be as precise as they made it. The same chart bound into a
/// monthly edition goes through this app's backend and then to a printer, and a
/// plate centred on somebody's front door at street zoom is a doxxing vector
/// however carefully the rest of the Page was written.
enum MapPlateDestination: Equatable {
    case screen
    case print
}

/// One mark drawn on a plate.
struct MapPlateMark: Equatable {
    var latitude: Double
    var longitude: Double
    var glyph: String
    var isPrimary: Bool
}

/// Everything needed to draw a place's chart, decided before any tile is
/// fetched so the decision is testable without a network.
struct MapPlateSpec: Equatable {
    /// Stable across redraws, so a rendered plate can be cached against it.
    var id: String
    var latitude: Double
    var longitude: Double
    var latitudeSpan: Double
    var longitudeSpan: Double
    var marks: [MapPlateMark]
    /// Street names and place labels. Off whenever the plate is loosened.
    var showsLabels: Bool
    /// True when the plate has been deliberately blurred out from the place it
    /// is nominally of.
    var isLoosened: Bool
}

enum MapPlate {

    /// How much wider a loosened plate is than a precise one. Six times a few
    /// streets is a district: enough to be recognisably somewhere, not enough
    /// to be an address.
    static let looseningFactor: Double = 6
    static let tightSpan: Double = 0.006

    /// A plate is loosened when the reader veiled the place, and *always* for
    /// print regardless of what they chose for the screen.
    static func isLoosened(anchor: AnchorRecord, destination: MapPlateDestination) -> Bool {
        if destination == .print { return true }
        guard let place = anchor.place else { return false }
        return !place.usesRealNameInStory
    }

    /// A deterministic nudge off the true centre, so a loosened plate is not
    /// simply a wider chart with the house still in the middle of it. Stable
    /// per place, so the plate does not wander between redraws.
    static func offset(for id: String, span: Double) -> (latitude: Double, longitude: Double) {
        let seed = abs(id.stableHash)
        let latitudeStep = Double((seed % 200)) / 200.0 - 0.5
        let longitudeStep = Double(((seed / 200) % 200)) / 200.0 - 0.5
        return (latitude: latitudeStep * span * 0.5, longitude: longitudeStep * span * 0.5)
    }

    /// The chart for one of the reader's places.
    ///
    /// A plate is not wallpaper: it carries the place's own marks, so it is
    /// showing something rather than decorating something.
    static func spec(
        for anchor: AnchorRecord,
        kept: [AtlasMark] = [],
        destination: MapPlateDestination = .screen
    ) -> MapPlateSpec? {
        guard (-90...90).contains(anchor.latitude), (-180...180).contains(anchor.longitude) else {
            return nil
        }
        let loosened = isLoosened(anchor: anchor, destination: destination)
        let span = loosened ? tightSpan * looseningFactor : tightSpan
        let nudge = loosened ? offset(for: anchor.id, span: span) : (latitude: 0.0, longitude: 0.0)

        var marks = [MapPlateMark(
            latitude: anchor.latitude, longitude: anchor.longitude,
            glyph: "mappin.circle.fill", isPrimary: true
        )]
        // A loosened plate carries only the place itself. Scattering the
        // reader's kept Pages across a district is exactly the pattern the
        // loosening exists to break up.
        if !loosened {
            for mark in kept where mark.isPlaceable {
                marks.append(MapPlateMark(
                    latitude: mark.latitude, longitude: mark.longitude,
                    glyph: "circle.fill", isPrimary: false
                ))
            }
        }

        return MapPlateSpec(
            id: "plate-\(anchor.id)-\(destination == .print ? "print" : "screen")",
            latitude: anchor.latitude + nudge.latitude,
            longitude: anchor.longitude + nudge.longitude,
            latitudeSpan: span,
            longitudeSpan: span,
            marks: marks,
            showsLabels: !loosened,
            isLoosened: loosened
        )
    }
}

// MARK: - A place on a quiet leaf

/// A place the Book puts on the paper between two Pages.
///
/// The quiet leaf is binding-space: a turn of paper the reader either stops at
/// or does not. It is the right home for a chart, because a plate is something
/// to come across rather than something to go and look up.
struct GazetteerLeaf: Equatable {
    var anchorID: String
    var title: String
    /// Why this one, said plainly. The Book is not allowed to put a place on
    /// the paper without having a reason it can say out loud.
    var line: String
    var plate: MapPlateSpec
}

extension Gazetteer {

    /// How long a place has to go unvisited before the Book counts it as gone
    /// quiet. Long enough that an ordinary busy month does not trigger it.
    static let goneQuietDays = 45

    static func daysSinceVisit(
        _ anchor: AnchorRecord,
        now: Date,
        calendar: Calendar = .current
    ) -> Int? {
        guard let visited = AnchorRegistry.visitDateFormatter.date(from: anchor.lastVisited) else {
            return nil
        }
        let days = calendar.dateComponents([.day], from: visited, to: now).day
        guard let days, days >= 0 else { return nil }
        return days
    }

    /// One place, and the Book's reason for raising it.
    ///
    /// Deterministic for the day so a leaf does not change under a thumb
    /// mid-turn. Prefers a place that has gone quiet: somewhere that dropped out
    /// of the reader's week is exactly the shape of the thing this app exists to
    /// argue with.
    static func quietLeaf(
        anchors: [AnchorRecord],
        days: [BookDay],
        now: Date = Date(),
        dayID: String = "",
        calendar: Calendar = .current
    ) -> GazetteerLeaf? {
        let entries = entries(anchors: anchors, days: days)
        guard !entries.isEmpty else { return nil }
        var byID: [String: AnchorRecord] = [:]
        for anchor in anchors { byID[anchor.id] = anchor }

        var best: (leaf: GazetteerLeaf, score: Int)?
        for entry in entries {
            guard let anchor = byID[entry.id], let plate = entry.plate else { continue }
            let quietFor = daysSinceVisit(anchor, now: now, calendar: calendar)
            var score = abs("\(dayID)-leaf-\(anchor.id)".stableHash) % 100
            var line: String?

            if let quietFor, quietFor >= goneQuietDays, entry.keptCount > 0 {
                // The strongest reason there is, so it outranks everything.
                score += 1_000
                line = "You haven't been back here in \(months(quietFor)). It's still on the chart."
            } else if entry.keptCount >= 3 {
                score += 300
                line = "\(entry.keptCount) things have happened here that you kept."
            } else if let made = entry.madeLine {
                line = made
            }

            guard let line else { continue }
            let leaf = GazetteerLeaf(anchorID: anchor.id, title: entry.name, line: line, plate: plate)
            if best == nil || score > best!.score { best = (leaf, score) }
        }
        return best?.leaf
    }

    /// Months, because "forty-seven days" is a stopwatch and the Book is not
    /// one. Nothing under a month reaches this.
    ///
    /// Floored rather than rounded. Rounding put forty-six days — one day past
    /// the threshold — at "2 months", so the very first thing the Book ever said
    /// about a place going quiet overstated it.
    static func months(_ days: Int) -> String {
        let months = max(1, Int(Double(days) / 30.44))
        return months == 1 ? "a month" : "\(months) months"
    }
}
