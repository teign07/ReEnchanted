import Foundation
import CoreGraphics

/// Decides which marks a bound leaf carries, and where.
///
/// A printed edition is the one artifact a reader can hold, and until now it
/// was the only surface that could not reach the cabinet: the folio, Pagewright
/// and illuminated photos all read `IlluminationPackRegistry`, while the PDF
/// drew its scraps, tape, ornaments and wear as bezier paths. Every shelf was
/// invisible to the thing a reader keeps in a drawer.
///
/// This is the decision half only. It picks marks and earns rectangles for
/// them; it draws nothing. The renderer takes the plan and puts ink down, the
/// same decide-then-render split the braid uses, which is what makes the
/// interesting half testable without a graphics context.
///
/// It follows the folio's rules rather than inventing new ones: a strict budget
/// per leaf, placement rejected when it collides with measured ink, and the
/// mark omitted rather than allowed to cover prose. A faint watermark is the
/// only intentional overlap.
enum EditionMarginalia {

    // MARK: - What kind of leaf is being decorated

    /// Kind decides the budget and which slots are eligible at all.
    ///
    /// A reading leaf is quiet on purpose. The expressive leaves are the ones a
    /// reader already stops on: an opener, a divider, the last page.
    enum LeafKind: String, Equatable, CaseIterable {
        /// The month's name and weather, before the story starts.
        case opening
        /// A section title, torn and taped across the leaf.
        case sectionOpener
        /// Ordinary reading matter. Most leaves are these.
        case reading
        /// A bound photograph or plate. The image is the subject; marks stay out.
        case plate
        /// A chapter break between months in a volume.
        case divider
        /// The Book's last word.
        case closing
        /// Printer's matter at the very back.
        case colophon

        /// How many foreground marks this leaf may carry.
        ///
        /// The folio's rule, kept verbatim: most leaves receive zero to two,
        /// and only the deliberately expressive ones may reach three.
        var foregroundBudget: Int {
            switch self {
            case .plate: return 0
            case .reading: return 1
            case .colophon, .divider: return 2
            case .opening, .sectionOpener, .closing: return 3
            }
        }

        /// Whether a faint mark may lie under the prose on this leaf.
        var allowsWatermark: Bool {
            switch self {
            case .opening, .sectionOpener, .closing, .divider: return true
            case .reading, .plate, .colophon: return false
            }
        }

        /// The slots this leaf offers, in the order they are tried.
        var slots: [Slot] {
            switch self {
            case .plate: return []
            case .reading: return [.gutterMiddle, .gutterLower, .lowerField]
            case .sectionOpener: return [.gutterUpper, .lowerField, .gutterLower, .footCorner]
            case .opening: return [.gutterUpper, .lowerField, .headMargin, .gutterMiddle]
            case .closing: return [.lowerField, .gutterMiddle, .footCorner, .gutterUpper]
            case .divider: return [.lowerField, .headMargin, .gutterMiddle]
            case .colophon: return [.footCorner, .gutterLower]
            }
        }

        /// The roles this leaf actually wants, strongest first.
        ///
        /// This is the difference between "the edition can reach the cabinet"
        /// and "the edition uses the cabinet well". A colophon wants a seal, a
        /// divider wants a flourish, and a section opener wants a specimen —
        /// asking for whatever scored highest would give all three the same
        /// drawer.
        var preferredRoles: [LeafAssetSemanticRole] {
            switch self {
            case .plate: return []
            case .reading: return [.botanical, .scribble, .watercolor, .fieldNote]
            case .sectionOpener: return [.botanical, .ornament, .fieldNote, .watercolor]
            case .opening: return [.ornament, .botanical, .sigil, .watercolor]
            case .closing: return [.watercolor, .botanical, .ornament, .scribble]
            case .divider: return [.ornament, .sigil, .botanical]
            case .colophon: return [.sigil, .ornament, .fieldNote]
            }
        }
    }

    // MARK: - Where a mark may sit

    /// A region of the bound leaf. These are the same places a hand would put
    /// something: the wide outer gutter, the open paper under the last line,
    /// the head margin, a corner.
    enum Slot: String, Equatable, CaseIterable {
        /// The outer corner above the gutter. Deliberately *not* the space
        /// directly above the text column: that is where the running head is
        /// printed on nearly every leaf.
        case headMargin
        /// The whole outer column, undivided. For callers that have already
        /// bounded the gutter to the part of the leaf they own — a section
        /// opener owns the band beside its title and nothing below it.
        case gutterBand
        case gutterUpper
        case gutterMiddle
        case gutterLower
        case lowerField
        case footCorner
        case watermark

        /// A mark in the gutter is small; a mark in the open lower field can
        /// afford to be a real illustration.
        var maximumSize: CGSize {
            switch self {
            case .headMargin: return CGSize(width: 72, height: 38)
            case .gutterBand: return CGSize(width: 76, height: 104)
            case .gutterUpper, .gutterMiddle, .gutterLower: return CGSize(width: 74, height: 88)
            case .lowerField: return CGSize(width: 190, height: 150)
            case .footCorner: return CGSize(width: 76, height: 62)
            case .watermark: return CGSize(width: 300, height: 300)
            }
        }

        /// The anchors a mark must claim to be eligible here. A mark that only
        /// ever wants to sit low should not be dropped into the head margin
        /// because the leaf happened to have room there.
        var acceptedAnchors: [LeafAssetAnchor] {
            switch self {
            case .headMargin: return [.upperLeading, .upperTrailing]
            case .gutterBand:
                return [.upperLeading, .middleLeading, .lowerLeading, .middleTrailing, .lowerTrailing]
            case .gutterUpper: return [.upperLeading, .middleLeading, .upperTrailing]
            case .gutterMiddle: return [.middleLeading, .middleTrailing]
            case .gutterLower: return [.lowerLeading, .middleLeading, .lowerTrailing]
            case .lowerField: return [.lowerField, .lowerLeading, .lowerTrailing]
            case .footCorner: return [.lowerTrailing, .lowerLeading, .lowerField]
            case .watermark: return [.watermark]
            }
        }
    }

    // MARK: - The paper being composed onto

    /// The measured leaf: its paper, its text column, and how far the ink got.
    struct LeafGeometry: Equatable {
        var bounds: CGRect
        /// The reading column. The gutter is whatever lies outside it.
        var contentLeft: CGFloat
        var contentRight: CGFloat
        var contentTop: CGFloat
        var contentBottom: CGFloat
        /// The y the cursor reached. Everything below this is open paper.
        var inkBottom: CGFloat

        init(
            bounds: CGRect,
            contentLeft: CGFloat,
            contentRight: CGFloat,
            contentTop: CGFloat,
            contentBottom: CGFloat,
            inkBottom: CGFloat
        ) {
            self.bounds = bounds
            self.contentLeft = contentLeft
            self.contentRight = contentRight
            self.contentTop = contentTop
            self.contentBottom = contentBottom
            self.inkBottom = inkBottom
        }

        /// The outer gutter, inset a little from the trimmed edge so nothing
        /// printed runs off a physical page.
        var gutter: CGRect {
            let safeEdge: CGFloat = 24
            let width = max(0, contentLeft - safeEdge - 6)
            return CGRect(x: safeEdge, y: contentTop, width: width, height: contentBottom - contentTop)
        }

        /// The open paper below the last line of prose.
        var lowerField: CGRect {
            let top = min(inkBottom + 14, contentBottom)
            return CGRect(x: contentLeft, y: top, width: contentRight - contentLeft, height: max(0, contentBottom - top))
        }

        func rect(for slot: Slot) -> CGRect {
            let column = gutter
            switch slot {
            case .headMargin:
                return CGRect(
                    x: column.minX,
                    y: max(2, contentTop - 46),
                    width: column.width,
                    height: 40
                )
            case .gutterBand:
                return column
            case .gutterUpper:
                return CGRect(x: column.minX, y: column.minY, width: column.width, height: column.height / 3)
            case .gutterMiddle:
                return CGRect(x: column.minX, y: column.minY + column.height / 3, width: column.width, height: column.height / 3)
            case .gutterLower:
                return CGRect(x: column.minX, y: column.minY + 2 * column.height / 3, width: column.width, height: column.height / 3)
            case .lowerField:
                return lowerField
            case .footCorner:
                return CGRect(x: contentRight - 80, y: contentBottom - 66, width: 80, height: 66)
            case .watermark:
                let inset: CGFloat = 60
                return bounds.insetBy(dx: inset, dy: inset * 1.6)
            }
        }
    }

    // MARK: - The plan

    /// One mark, and the rectangle it earned on this leaf.
    struct PlacedMark: Equatable {
        var assetName: String
        var assetID: String
        var slot: Slot
        var rect: CGRect
        var rotation: Double
        var opacity: Double
        var blend: LeafAssetBlend
        var tintStrength: Double
        /// A scrap pinned down wants tape over it; a pressed sprig usually does
        /// too. Line art and seals do not.
        var fasteningAssetName: String?
    }

    /// Everything decided for one leaf.
    struct LeafPlan: Equatable {
        var marks: [PlacedMark]

        static let empty = LeafPlan(marks: [])
    }

    // MARK: - Motifs

    /// The vocabulary this leaf's own content offers the cabinet.
    ///
    /// This reuses `LeafDecorationLibrary.semanticMotifs`, the same reader the
    /// folio uses on Page prose, so a harbour in a bound month reaches the same
    /// marks a harbour on a nightly Page does. A second vocabulary would drift.
    static func motifs(
        title: String,
        prose: String,
        tags: [String],
        pageTypes: [BookPageType],
        month: Int?
    ) -> [String] {
        var motifs: [String] = ["book", "margin"]
        motifs += tags.map { $0.lowercased() }
        motifs += pageTypes.map { $0.rawValue }
        motifs += LeafDecorationLibrary.semanticMotifs(in: title)
        motifs += LeafDecorationLibrary.semanticMotifs(in: prose)
        if let month { motifs += seasonalMotifs(forMonth: month) }
        var seen = Set<String>()
        return motifs.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// What is actually out, that month, in the world the reader is standing in.
    ///
    /// A bound edition is dated in a way a screen is not — it is read in a
    /// season, and often long afterward — so the season is a real motif here
    /// rather than decoration.
    static func seasonalMotifs(forMonth month: Int) -> [String] {
        switch month {
        case 1: return ["winter", "snowdrop", "evergreen", "holly", "ivy", "quiet"]
        case 2: return ["snowdrop", "imbolc", "thaw", "first", "hellebore", "winter"]
        case 3: return ["spring", "violet", "unfurling", "fern", "fiddlehead"]
        case 4: return ["spring", "lily-of-the-valley", "woodland", "anemone", "bell"]
        case 5: return ["spring", "bell", "borage", "meadow", "blue"]
        case 6: return ["summer", "foxglove", "daisy", "poppy", "meadow"]
        case 7: return ["summer", "lavender", "poppy", "daisy", "bindweed"]
        case 8: return ["late-summer", "heather", "blackberry", "bramble", "harvest"]
        case 9: return ["autumn", "blackberry", "harvest", "oak", "acorn"]
        case 10: return ["autumn", "physalis", "lantern", "mushroom", "toadstool", "sycamore"]
        case 11: return ["autumn", "oak", "acorn", "sycamore", "seed", "remembrance"]
        default: return ["winter", "holly", "berry", "yule", "evergreen", "ivy"]
        }
    }

    // MARK: - Composing

    /// Chooses the marks for one leaf and earns each of them a rectangle.
    ///
    /// `reservedInk` is every rectangle the renderer has already committed to —
    /// measured prose, the date chip, a taped margin note, a bound photograph.
    /// A candidate that touches any of them is dropped rather than nudged: the
    /// folio learned that nudging is how decoration ends up on top of a
    /// sentence, and a printed page cannot be scrolled away from.
    /// `slots` restricts the composer to a subset of the leaf's regions.
    ///
    /// The renderer needs this because a printed leaf is decorated in two
    /// moments. At the top of the page only the regions outside the text
    /// column are provably free, so those are composed then; the open paper
    /// below the last line cannot be known until the prose has actually been
    /// set, so a leaf that ends asks for `.lowerField` separately. Drawing both
    /// at the moment they are safe is what keeps a mark from ever landing on a
    /// page it was not composed for.
    static func compose(
        kind: LeafKind,
        motifs: [String],
        placementContext: IlluminationPlacementContext,
        geometry: LeafGeometry,
        reservedInk: [CGRect],
        seed: String,
        slots: [Slot]? = nil,
        includeWatermark: Bool = true,
        budget: Int? = nil
    ) -> LeafPlan {
        guard kind.foregroundBudget > 0 || kind.allowsWatermark else { return .empty }

        let cabinet = IlluminationPackRegistry.shelvedMarks(context: placementContext)
        guard !cabinet.isEmpty else { return .empty }

        let wanted = Set(motifs.map { $0.lowercased() })
        var accepted: [PlacedMark] = []
        var claimed: [CGRect] = reservedInk
        var usedAssets: Set<String> = []

        // The faint layer first: a watermark is the only mark allowed to cross
        // the ink, so it is decided before the foreground competes for paper.
        if kind.allowsWatermark,
           includeWatermark,
           bucket(seed, salt: 2) < 34,
           let mark = choose(
               from: cabinet,
               roles: [.texture],
               requiringOverlap: true,
               wanted: wanted,
               excluding: usedAssets,
               seed: seed,
               salt: 3
           ) {
            let rect = fitted(
                aspectRatio: mark.asset.leafTraits?.aspectRatio ?? 1,
                within: geometry.rect(for: .watermark),
                maximum: Slot.watermark.maximumSize,
                visualWeight: mark.asset.leafTraits?.visualWeight ?? 1
            )
            if !rect.isEmpty {
                usedAssets.insert(mark.asset.assetName)
                accepted.append(
                    PlacedMark(
                        assetName: mark.asset.assetName,
                        assetID: mark.asset.id,
                        slot: .watermark,
                        rect: rect,
                        rotation: 0,
                        // Faint enough to read a sentence through, and no fainter
                        // than the stain layer the compost already lays down.
                        opacity: min(mark.asset.defaultOpacity, 0.16),
                        blend: mark.asset.leafTraits?.blend ?? .multiply,
                        tintStrength: mark.asset.leafTraits?.tintStrength ?? 0,
                        fasteningAssetName: nil
                    )
                )
            }
        }

        var remaining = budget ?? kind.foregroundBudget
        var roleQueue = kind.preferredRoles

        let eligible = slots ?? kind.slots
        for (index, slot) in eligible.enumerated() {
            guard remaining > 0, !roleQueue.isEmpty else { break }

            let field = geometry.rect(for: slot)
            guard field.width > 24, field.height > 24 else { continue }

            // A quieter leaf should not fill every slot it happens to have.
            let appetite = slot == .lowerField ? 78 : 58
            guard bucket(seed, salt: 11 + index * 3) < appetite else { continue }

            let roles = Array(roleQueue.prefix(3))
            guard let mark = choose(
                from: cabinet,
                roles: roles,
                anchors: slot.acceptedAnchors,
                requiringOverlap: false,
                wanted: wanted,
                excluding: usedAssets,
                seed: seed,
                salt: 17 + index * 5
            ) else { continue }

            let traits = mark.asset.leafTraits
            var rect = fitted(
                aspectRatio: traits?.aspectRatio ?? 1,
                within: field,
                maximum: slot.maximumSize,
                visualWeight: traits?.visualWeight ?? 1
            )
            guard !rect.isEmpty else { continue }

            // Marks sit a little off square, the way a pressed thing does.
            let rotation = (unit(seed, salt: 23 + index) - 0.5) * 0.16

            // Collision is checked against a padded rectangle: a mark that only
            // just clears a line of prose still reads as touching it.
            let breathing = rect.insetBy(dx: -6, dy: -6)
            guard !claimed.contains(where: { $0.intersects(breathing) }) else { continue }
            guard geometry.bounds.contains(rect.insetBy(dx: -2, dy: -2)) else { continue }

            rect = rect.integral
            claimed.append(rect)
            usedAssets.insert(mark.asset.assetName)
            remaining -= 1
            if let role = traits?.semanticRole, let position = roleQueue.firstIndex(of: role) {
                roleQueue.remove(at: position)
            }

            // Something laid onto paper gets held down. Line art and seals are
            // printed, not pinned, so they are left alone.
            let wantsTape = [.botanical, .fieldNote, .watercolor, .portrait]
                .contains(traits?.semanticRole ?? .ornament)
            // Real tape from the Fastenings shelf, varied per mark rather than
            // reaching for the same strip every time.
            let tapes = cabinet.filter { $0.asset.kind == .tape }
            let fastening = wantsTape && !tapes.isEmpty && bucket(seed, salt: 29 + index) < 62
                ? tapes[abs((seed + "|tape\(index)").stableHash) % tapes.count].asset.assetName
                : nil

            accepted.append(
                PlacedMark(
                    assetName: mark.asset.assetName,
                    assetID: mark.asset.id,
                    slot: slot,
                    rect: rect,
                    rotation: rotation,
                    opacity: mark.asset.defaultOpacity,
                    blend: traits?.blend ?? .normal,
                    tintStrength: traits?.tintStrength ?? 0,
                    fasteningAssetName: fastening
                )
            )
        }

        return LeafPlan(marks: accepted)
    }

    // MARK: - Choosing one mark

    /// Picks the mark whose subject best agrees with this leaf, from the roles
    /// the leaf asked for.
    ///
    /// Scoring mirrors `IlluminationAssetResolver`: motif agreement decides,
    /// and a mark with no agreement at all is still reachable so that marks
    /// which suit any page — a flourish, a corner ornament — do not become
    /// unplaceable on every page that matched anything.
    private static func choose(
        from cabinet: [IlluminationPackRegistry.ShelvedMark],
        roles: [LeafAssetSemanticRole],
        anchors: [LeafAssetAnchor]? = nil,
        requiringOverlap: Bool,
        wanted: Set<String>,
        excluding: Set<String>,
        seed: String,
        salt: Int
    ) -> IlluminationPackRegistry.ShelvedMark? {
        let roleSet = Set(roles)
        let anchorSet = anchors.map(Set.init)

        let candidates = cabinet.filter { mark in
            guard !excluding.contains(mark.asset.assetName) else { return false }
            // The character shelves ship construction pieces as well as whole
            // marks: ears, noses, hands, feet, drawn so a goblin can be built
            // out of them. A whole goblin in a margin is the joke; a single
            // detached ear pinned beside a section title is not, and on paper
            // there is no tapping it away.
            guard !mark.asset.tags.contains("anatomy") else { return false }
            let traits = mark.asset.leafTraits
            guard let role = traits?.semanticRole, roleSet.contains(role) else { return false }
            // Only a mark that says it may lie under prose ever does.
            guard (traits?.allowsTextOverlap ?? false) == requiringOverlap else { return false }
            guard traits?.aspectRatio != nil else { return false }
            if let anchorSet {
                let claimed = Set(traits?.preferredAnchors ?? [])
                guard !claimed.isEmpty, !claimed.isDisjoint(with: anchorSet) else { return false }
            }
            return true
        }
        guard !candidates.isEmpty else { return nil }

        let scored = candidates.map { mark -> (mark: IlluminationPackRegistry.ShelvedMark, score: Int) in
            let tags = mark.asset.tags + (mark.asset.leafTraits?.subjectTags ?? [])
            return (mark, wanted.intersection(Set(tags.map { $0.lowercased() })).count)
        }
        let best = scored.map(\.score).max() ?? 0
        // Keep a little variety around the best match without letting a
        // one-word coincidence tie with a mark whose whole subject agrees.
        let floor = max(1, best - 1)
        var pool = scored.filter { $0.score >= floor }.map(\.mark)

        // Rank order inside the pool still follows the roles the leaf asked
        // for, so a colophon that wanted a sigil does not settle for the
        // ornament that happened to share a word with it.
        if !pool.isEmpty, roles.count > 1 {
            pool.sort { lhs, rhs in
                let l = roles.firstIndex(of: lhs.asset.leafTraits?.semanticRole ?? .ornament) ?? roles.count
                let r = roles.firstIndex(of: rhs.asset.leafTraits?.semanticRole ?? .ornament) ?? roles.count
                return l == r ? lhs.asset.id < rhs.asset.id : l < r
            }
            pool = Array(pool.prefix(max(4, pool.count / 3)))
        }
        if pool.isEmpty { pool = candidates }

        let index = abs((seed + "|\(salt)").stableHash) % pool.count
        return pool[index]
    }

    // MARK: - Geometry

    /// Sizes a mark to its own proportions inside the slot it was offered.
    ///
    /// `visualWeight` is ink presence, not selection odds: a heavier mark is
    /// physically larger on the paper. The result is centred in the field.
    static func fitted(
        aspectRatio: Double,
        within field: CGRect,
        maximum: CGSize,
        visualWeight: Double
    ) -> CGRect {
        guard aspectRatio > 0, field.width > 0, field.height > 0 else { return .zero }
        let weight = min(max(visualWeight, 0.5), 1.8)
        let ceilingWidth = min(field.width, maximum.width * weight)
        let ceilingHeight = min(field.height, maximum.height * weight)
        guard ceilingWidth > 8, ceilingHeight > 8 else { return .zero }

        var width = ceilingWidth
        var height = width / aspectRatio
        if height > ceilingHeight {
            height = ceilingHeight
            width = height * aspectRatio
        }
        guard width > 8, height > 8 else { return .zero }

        return CGRect(
            x: field.midX - width / 2,
            y: field.midY - height / 2,
            width: width,
            height: height
        )
    }

    // MARK: - Deterministic dice

    private static func bucket(_ seed: String, salt: Int) -> Int {
        abs((seed + "|b\(salt)").stableHash) % 100
    }

    private static func unit(_ seed: String, salt: Int) -> Double {
        Double(abs((seed + "|u\(salt)").stableHash) % 1000) / 1000
    }
}
