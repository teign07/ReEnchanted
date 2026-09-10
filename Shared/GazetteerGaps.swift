import Foundation

/// The shape of the reader's world, and where its edges are.
///
/// The Gazetteer has always been able to say what is in it. This is the other
/// half: what the map has never once contained. The Bestiary already proved the
/// shape — find a hole in a file, ask the reader to go and fill it, then watch
/// for the answer without being told — and a map has better holes than a file
/// of animals, because the holes in a map are the walls of the Rut drawn to
/// scale.
///
/// Three rules keep it from becoming an accusation.
///
/// **Every gap is measured against the reader's own map.** Never a distance in
/// kilometres, never a comparison with anybody. The edge is where *this* reader
/// usually stops, so the same errand reaches somebody who walks to the end of
/// their garden and somebody who drives across a county, and asks each of them
/// for one step.
///
/// **The usual edge, not the record.** The furthest the reader has ever been is
/// an achievement and beating it is a project. The radius they stop inside most
/// of the time is a habit, and a habit is the thing this app argues with.
///
/// **The Book asks for itself.** It wants a direction it has never been given.
/// It is greedy about the world, not disappointed in anybody, and a reader with
/// every reason to stay exactly where they are can let the card go and owes it
/// nothing.

// MARK: - The reader's world

/// One place the archive actually recorded, as a point.
struct WorldPoint: Equatable {
    var pageID: String
    var at: Date
    var latitude: Double
    var longitude: Double
    /// What the fix was worth. The Book asks Core Location for coarse accuracy,
    /// so this is usually a neighbourhood, and every geometric claim below has
    /// to survive being wrong by that much.
    var accuracyMeters: Double?
    var dayPart: String
    var placeKind: String?

    static func points(in days: [BookDay]) -> [WorldPoint] {
        days.flatMap(\.pages).compactMap { page in
            guard let context = page.context,
                  let latitude = context.latitude,
                  let longitude = context.longitude else { return nil }
            return WorldPoint(
                pageID: page.id,
                at: page.createdAt,
                latitude: latitude,
                longitude: longitude,
                accuracyMeters: context.horizontalAccuracyMeters,
                dayPart: context.dayPart,
                placeKind: context.placeKind
            )
        }
    }
}

/// A quarter of the compass, as a ninety-degree sector centred on its cardinal.
enum CompassQuarter: String, CaseIterable, Equatable, Sendable {
    case north, east, south, west

    static func containing(bearingDegrees bearing: Double) -> CompassQuarter {
        let normalised = (bearing.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        switch normalised {
        case 45..<135: return .east
        case 135..<225: return .south
        case 225..<315: return .west
        default: return .north
        }
    }

    var plainName: String { rawValue }

    /// What going that way is like, said as the Book would say it. Deliberately
    /// not a fact about anybody's actual geography — the Book has no idea what
    /// is east of this reader, and saying so is the honest version of wanting
    /// to find out.
    var appetite: String {
        switch self {
        case .north: return "north"
        case .east: return "east"
        case .south: return "south"
        case .west: return "west"
        }
    }
}

/// The reader's map, measured.
struct ReaderWorld: Equatable {
    var points: [WorldPoint]
    /// The middle of the reader's life, taken as the median rather than the
    /// mean: one holiday should not move the centre of somebody's world.
    var centre: (latitude: Double, longitude: Double)?
    /// The radius the reader stops inside nine times out of ten. Their habit,
    /// in metres, and the only distance this file ever reasons about.
    var usualEdgeMeters: Double
    /// The coarsest fix the geometry is standing on.
    var resolutionMeters: Double

    static func == (left: ReaderWorld, right: ReaderWorld) -> Bool {
        left.points == right.points
            && left.centre?.latitude == right.centre?.latitude
            && left.centre?.longitude == right.centre?.longitude
            && left.usualEdgeMeters == right.usualEdgeMeters
            && left.resolutionMeters == right.resolutionMeters
    }

    /// Fixes needed before the shape of a map means anything. Under this the
    /// Book is looking at a handful of dots and calling it a life.
    static let pointFloor = 12

    /// How much bigger than the fix the reader's world has to be before a
    /// direction or an edge can honestly be claimed. A three-kilometre fix
    /// cannot tell anybody which way they walked down a five-hundred-metre
    /// street, and a Book that said otherwise would be inventing geography.
    static let resolutionMultiple: Double = 3

    static func measured(from days: [BookDay]) -> ReaderWorld {
        let points = WorldPoint.points(in: days)
        guard !points.isEmpty else {
            return ReaderWorld(points: [], centre: nil, usualEdgeMeters: 0, resolutionMeters: .infinity)
        }
        let centre = (
            latitude: median(points.map(\.latitude)),
            longitude: median(points.map(\.longitude))
        )
        let distances = points
            .map { metres(from: centre, to: ($0.latitude, $0.longitude)) }
            .sorted()
        // The ninetieth percentile: where they stop, rather than the one time
        // they did not.
        let index = min(distances.count - 1, Int(Double(distances.count - 1) * 0.9))
        let accuracies = points.compactMap(\.accuracyMeters)
        return ReaderWorld(
            points: points,
            centre: centre,
            usualEdgeMeters: distances[index],
            // No accuracy recorded at all is not permission to assume a good
            // one. It is the coarse setting the Book actually asks for.
            resolutionMeters: accuracies.max() ?? 3_000
        )
    }

    /// Whether the map is solid enough to say which way anything is.
    var carriesHonestGeometry: Bool {
        points.count >= Self.pointFloor
            && usualEdgeMeters >= resolutionMeters * Self.resolutionMultiple
    }

    func quarter(of point: WorldPoint) -> CompassQuarter? {
        guard let centre else { return nil }
        return CompassQuarter.containing(
            bearingDegrees: Self.bearing(from: centre, to: (point.latitude, point.longitude))
        )
    }

    func distanceFromCentre(_ point: WorldPoint) -> Double? {
        guard let centre else { return nil }
        return Self.metres(from: centre, to: (point.latitude, point.longitude))
    }

    /// Quarters with nothing in them at all.
    var emptyQuarters: [CompassQuarter] {
        // Points sitting inside the fix's own error are not evidence of a
        // direction; they are the reader standing still.
        let meaningful = points.filter {
            (distanceFromCentre($0) ?? 0) >= resolutionMeters
        }
        let occupied = Set(meaningful.compactMap { quarter(of: $0) })
        return CompassQuarter.allCases.filter { !occupied.contains($0) }
    }

    // MARK: Arithmetic

    /// Equirectangular, which is exact enough for anything inside one reader's
    /// life and keeps the shared core free of CoreLocation so the whole thing
    /// still builds and tests on a Mac.
    static func metres(
        from origin: (latitude: Double, longitude: Double),
        to point: (latitude: Double, longitude: Double)
    ) -> Double {
        let earth = 6_371_000.0
        let latitudeRadians = origin.latitude * .pi / 180
        let dLat = (point.latitude - origin.latitude) * .pi / 180
        let dLon = (point.longitude - origin.longitude) * .pi / 180 * cos(latitudeRadians)
        return earth * (dLat * dLat + dLon * dLon).squareRoot()
    }

    static func bearing(
        from origin: (latitude: Double, longitude: Double),
        to point: (latitude: Double, longitude: Double)
    ) -> Double {
        let latitudeRadians = origin.latitude * .pi / 180
        let east = (point.longitude - origin.longitude) * cos(latitudeRadians)
        let north = point.latitude - origin.latitude
        return atan2(east, north) * 180 / .pi
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}

// MARK: - The gaps

enum GazetteerGap: Equatable, Sendable {
    /// A whole direction the reader has never taken the Book.
    case theEmptyQuarter(CompassQuarter)
    /// One step past the radius they stop inside.
    case pastTheUsualEdge
    /// Nowhere in the map has ever been beside water.
    case water
    /// Nowhere in the map has ever been dark. The one errand that asks for no
    /// distance at all: the same street at night is a different street, which
    /// is the whole argument this Book exists to make.
    case afterDark

    var id: String {
        switch self {
        case let .theEmptyQuarter(quarter): return "quarter-\(quarter.rawValue)"
        case .pastTheUsualEdge: return "edge"
        case .water: return "water"
        case .afterDark: return "dark"
        }
    }

    /// Ordered by how little the errand asks and how much it changes. Dark is
    /// first because it costs nobody a journey and it is the strongest of the
    /// four; a direction is last because it is the biggest ask in the set.
    static let askingOrder: [GazetteerGap] = [.afterDark, .water, .pastTheUsualEdge]

    /// Whether a page the reader made after the ask closes it.
    func isClosed(by point: WorldPoint, in world: ReaderWorld, edgeAtAsk: Double) -> Bool {
        switch self {
        case .afterDark:
            return point.dayPart == "night"
        case .water:
            return point.placeKind.map { GazetteerGaps.waterKeys.contains($0) } ?? false
        case .pastTheUsualEdge:
            guard let distance = world.distanceFromCentre(point) else { return false }
            // Past the habit, and past it by more than the fix could be wrong
            // by, or the Book congratulates somebody for standing still.
            return distance > edgeAtAsk + world.resolutionMeters
        case let .theEmptyQuarter(quarter):
            guard let actual = world.quarter(of: point),
                  let distance = world.distanceFromCentre(point) else { return false }
            return actual == quarter && distance >= world.resolutionMeters
        }
    }
}

enum GazetteerGaps {
    /// Categories that genuinely put somebody beside water, borrowed from the
    /// constant the projectors already use so the two can never disagree about
    /// what water is.
    static var waterKeys: Set<String> { PlaceKind.waterKinds }

    /// Fixes with a night on them before the Book stops asking for one. A
    /// reader who has kept one page after dark has answered.
    static let darkFloor = 1

    /// The gap the Book would most like closed, or none.
    ///
    /// Geometry is only offered when the map can carry it. That is not a
    /// fallback — a reader whose whole world fits inside one coarse fix still
    /// gets the two errands that ask for no distance, which is the right
    /// outcome and not a lesser one.
    static func open(in world: ReaderWorld, days: [BookDay]) -> [GazetteerGap] {
        guard !world.points.isEmpty else { return [] }
        var gaps: [GazetteerGap] = []

        let nights = world.points.filter { $0.dayPart == "night" }.count
        if nights < darkFloor { gaps.append(.afterDark) }

        let hasWater = world.points.contains {
            $0.placeKind.map { waterKeys.contains($0) } ?? false
        }
        if !hasWater { gaps.append(.water) }

        guard world.carriesHonestGeometry else { return gaps }
        gaps.append(.pastTheUsualEdge)
        gaps.append(contentsOf: world.emptyQuarters.map { GazetteerGap.theEmptyQuarter($0) })
        return gaps
    }

    /// The errand currently out, if the reader kept the card offering it.
    ///
    /// Keeping is how an errand is taken on and letting the card go costs
    /// nothing, which is the Fae Bargain's rule and the Bestiary's, and matters
    /// more here than in either: somebody may have every reason in the world to
    /// stay exactly where they are, and must be able to decline without ever
    /// having to say why.
    static func outstanding(in days: [BookDay]) -> (gap: GazetteerGap, askedAt: Date, edge: Double)? {
        let asks = days.flatMap(\.pages).compactMap { page -> (GazetteerGap, Date, Double)? in
            guard let tag = page.tags.first(where: { $0.hasPrefix("gazetteer-errand:") }),
                  let gap = gap(fromID: String(tag.dropFirst("gazetteer-errand:".count)))
            else { return nil }
            let edge = page.tags
                .first { $0.hasPrefix("gazetteer-edge:") }
                .flatMap { Double($0.dropFirst("gazetteer-edge:".count)) } ?? 0
            return (gap, page.createdAt, edge)
        }
        guard let latest = asks.max(by: { $0.1 < $1.1 }) else { return nil }
        // An errand the Book already thanked them for is finished.
        let answered = days.flatMap(\.pages).contains {
            $0.tags.contains("gazetteer-went:\(latest.0.id)")
        }
        guard !answered else { return nil }
        return (latest.0, latest.1, latest.2)
    }

    static func gap(fromID id: String) -> GazetteerGap? {
        switch id {
        case "edge": return .pastTheUsualEdge
        case "water": return .water
        case "dark": return .afterDark
        default:
            guard id.hasPrefix("quarter-"),
                  let quarter = CompassQuarter(rawValue: String(id.dropFirst("quarter-".count)))
            else { return nil }
            return .theEmptyQuarter(quarter)
        }
    }
}
