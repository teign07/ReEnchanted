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
