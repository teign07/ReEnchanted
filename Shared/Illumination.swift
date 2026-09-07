import Foundation


enum IlluminatedTemplateID: String, Codable, CaseIterable, Hashable {
    case harborFieldNote = "harbor_field_note"
    case creatureComfort = "creature_comfort"
    case homeVessel = "home_vessel"
    case goodCompany = "good_company"
    case academyFieldStudy = "academy_field_study"
    case restAndQuiet = "rest_and_quiet"
}

enum IlluminatedPageStatus: String, Codable, Equatable {
    case proposed
    case kept
    case dismissed
    case skipped
}

struct IlluminatedPhotoHistory: Codable, Equatable {
    var keptAssetIdentifiers: Set<String> = []
    var dismissedAssetIdentifiers: Set<String> = []
    var proposedAssetIdentifiers: Set<String> = []
    var lastSuggestedAtByAsset: [String: Date] = [:]
}

struct PhotoAnalysis: Codable, Equatable {
    var scene: String
    var motifs: [String]
    var mood: String
    var suggestedTemplate: IlluminatedTemplateID
    var marginalia: PhotoMarginalia
    var souvenirCandidates: [String]
    /// Vision's best subject/focal region, kept separate from the literary
    /// reading so the compositor can protect the photograph without teaching
    /// Penny to speak more confidently than the detector did.
    var subjectRegion: VisualRegion? = nil
}

enum IlluminationAssetKind: String, Codable, Equatable {
    case background
    case paperScrap
    case stamp
    case doodle
    case tape
    case overlay
}

enum LeafAssetSemanticRole: String, Codable, Equatable {
    case ornament
    case scribble
    case watercolor
    case botanical
    case portrait
    case fieldNote
    case map
    case sigil
    case texture
    case fastener
}

enum LeafAssetAnchor: String, Codable, Equatable {
    case upperLeading
    case upperTrailing
    case middleLeading
    case middleTrailing
    case lowerLeading
    case lowerTrailing
    case lowerField
    case watermark
}

enum LeafAssetBlend: String, Codable, Equatable {
    case normal
    case multiply
    case screen
    case overlay
}

enum LeafAssetCrop: String, Codable, Equatable {
    case contain
    case fill
}

/// Where a reader goes looking for a mark.
///
/// This is deliberately a second axis, independent of `IlluminationAssetKind`.
/// Kind says how a mark composites — the folio needs that. Shelf says what a
/// mark *is to a person holding scissors*, which is a different question and
/// was never asked before. Pagewright browsed by kind because kind was the only
/// grouping that existed, and at forty marks that was survivable. It is not
/// survivable at two hundred and fifty: four kinds hold a handful each and
/// `.doodle` holds everything else.
///
/// Three cases are never returned by `MarkShelf.shelf(for:)`. `thisMonth` and
/// `pastMonths` are *current locations*, decided at query time from a mark's
/// `placementTrigger`, and `theDrawer` is a shuffled handful rather than a
/// category. Every mark still has a permanent shelf underneath, so an event
/// mark has somewhere to settle when its month is over.
enum MarkShelf: String, Codable, CaseIterable, Identifiable {
    case thisMonth
    case theDrawer
    case academyDesk
    case handwriting
    case marginFolk
    case inklings
    case pressedAndGrown
    case skyAndNight
    case shore
    case wayfinding
    case creaturesAndCompany
    case sealsAndLabels
    case paper
    case fastenings
    case flourishes
    case wear
    case pastMonths

    var id: String { rawValue }

    /// The shelves a mark can permanently belong to. Ordered as they are shown:
    /// the ones with a voice first, materials and texture last.
    static let permanentShelves: [MarkShelf] = [
        .academyDesk, .handwriting, .marginFolk, .inklings, .pressedAndGrown, .skyAndNight, .shore,
        .wayfinding, .creaturesAndCompany, .sealsAndLabels, .paper,
        .fastenings, .flourishes, .wear
    ]

    /// Full display order for the tray, including the three shelves that are
    /// locations rather than categories.
    static let displayOrder: [MarkShelf] =
        [.thisMonth, .theDrawer] + permanentShelves + [.pastMonths]

    var title: String {
        switch self {
        case .thisMonth: return "This Month"
        case .theDrawer: return "The Drawer"
        case .academyDesk: return "Academy Desk"
        case .handwriting: return "Handwriting"
        case .marginFolk: return "Margin Folk"
        case .inklings: return "Inklings"
        case .pressedAndGrown: return "Pressed & Grown"
        case .skyAndNight: return "Sky & Night"
        case .shore: return "Shore & Weather"
        case .wayfinding: return "Wayfinding"
        case .creaturesAndCompany: return "Creatures & Company"
        case .sealsAndLabels: return "Seals & Labels"
        case .paper: return "Paper"
        case .fastenings: return "Fastenings"
        case .flourishes: return "Flourishes"
        case .wear: return "Wear"
        case .pastMonths: return "Past Months"
        }
    }

    /// One line in the Book's voice, for the shelf header and its empty state.
    var subtitle: String {
        switch self {
        case .thisMonth: return "What's loose in the world right now."
        case .theDrawer: return "I tipped a drawer out. It's different tomorrow."
        case .academyDesk: return "Class scraps. The bell bit some of them."
        case .handwriting: return "Somebody wrote these by hand. Not always me."
        case .marginFolk: return "The little people who live in my margins. Not shy."
        case .inklings: return "Small inked thoughts. They tend to have opinions."
        case .pressedAndGrown: return "Things that grew, then got flattened."
        case .skyAndNight: return "Moons, moths, and whatever's up there."
        case .shore: return "Water, weather, and the edge of the map."
        case .wayfinding: return "For pages that went somewhere."
        case .creaturesAndCompany: return "Whoever was in the room with you."
        case .sealsAndLabels: return "Make it official. Or pretend to."
        case .paper: return "Blank stock. Torn, mostly."
        case .fastenings: return "Tape. It holds."
        case .flourishes: return "Pure decoration. No apology."
        case .wear: return "Stains, grain, and honest damage."
        case .pastMonths: return "Months that already happened. They stay."
        }
    }

    var symbolName: String {
        switch self {
        case .thisMonth: return "sparkles"
        case .theDrawer: return "shippingbox"
        case .academyDesk: return "graduationcap"
        case .handwriting: return "hand.write"
        case .marginFolk: return "theatermasks"
        case .inklings: return "drop"
        case .pressedAndGrown: return "leaf"
        case .skyAndNight: return "moon.stars"
        case .shore: return "water.waves"
        case .wayfinding: return "location.north.line"
        case .creaturesAndCompany: return "pawprint"
        case .sealsAndLabels: return "seal"
        case .paper: return "doc.on.doc"
        case .fastenings: return "paperclip"
        case .flourishes: return "scribble.variable"
        case .wear: return "square.dashed"
        case .pastMonths: return "archivebox"
        }
    }
}

/// Optional art direction for the shared physical-mark cabinet. Old packs are
/// still complete without it; richer packs can tell every consumer what an
/// image is good at instead of baking coordinates into one screen.
struct LeafAssetTraits: Codable, Equatable {
    var semanticRole: LeafAssetSemanticRole? = nil
    var aspectRatio: Double? = nil
    var preferredAnchors: [LeafAssetAnchor]? = nil
    var supportedDialects: [LeafVisualDialectID]? = nil
    var crop: LeafAssetCrop? = nil
    var blend: LeafAssetBlend? = nil
    var visualWeight: Double? = nil
    var allowsTextOverlap: Bool? = nil
    var tintStrength: Double? = nil
    var subjectTags: [String]? = nil
    /// Where this mark is filed for browsing. Almost always absent: tags
    /// already describe what a mark is, and `MarkShelf.shelf(for:)` reads them.
    /// Set it only when a pack's mark would be filed wrongly by its own tags.
    var shelf: MarkShelf? = nil
}

extension LeafAssetTraits {
    /// Fill in art direction for a mark that never declared any.
    ///
    /// The folio reads `leafTraits` in six places — saturation, blend, size,
    /// which dialects a mark may appear on, where it prefers to sit, and whether
    /// prose may run over it. Every one of those was reading `nil`: the cabinet
    /// declared the contract and no asset filled it, so all 79 marks rendered
    /// identically and landed wherever the collision checker allowed.
    ///
    /// `kind` and `tags` are already the authored description of what each mark
    /// *is*, so derive from those rather than hand-writing 79 entries. A pack
    /// that states its own traits still wins; this only speaks for the silent.
    static func derived(kind: IlluminationAssetKind, tags: [String]) -> LeafAssetTraits {
        let tags = Set(tags)

        // Subject beats medium: a botanical stamp is a botanical first.
        let role: LeafAssetSemanticRole = {
            if tags.contains("botanical") { return .botanical }
            if tags.contains("map") { return .map }
            switch kind {
            case .background, .overlay: return .texture
            case .paperScrap: return .fieldNote
            case .stamp: return .sigil
            case .tape: return .fastener
            case .doodle: return .scribble
            }
        }()

        // Where a real object of this kind would end up on a page. Tape lands on
        // corners because that is what tape is for; a seal sits low and to the
        // outside; pencilled marginalia live in the outer margin beside the
        // text; a paper scrap is laid onto the lower field.
        let anchors: [LeafAssetAnchor] = {
            switch role {
            case .fastener: return [.upperTrailing, .upperLeading, .lowerTrailing]
            case .sigil: return [.lowerTrailing, .upperTrailing]
            case .botanical: return [.middleLeading, .lowerLeading, .middleTrailing]
            case .scribble: return [.middleTrailing, .middleLeading, .lowerTrailing]
            case .fieldNote, .map: return [.lowerField, .middleLeading]
            case .texture: return [.watermark]
            case .ornament, .watercolor, .portrait: return [.upperTrailing, .lowerLeading]
            }
        }()

        // Only a watermark may sit under prose. Everything else is an object on
        // the page, and text running through it reads as a mistake.
        let allowsOverlap = role == .texture

        // A stamp or a scrap is a deliberate object and can hold its size; a
        // pencilled note in the margin should stay small enough to read as an
        // aside rather than an illustration.
        let weight: Double = {
            switch role {
            case .texture: return 1.35
            case .fieldNote, .map: return 1.15
            case .sigil: return 0.95
            case .fastener: return 0.80
            case .scribble: return 0.72
            default: return 1
            }
        }()

        return LeafAssetTraits(
            semanticRole: role,
            preferredAnchors: anchors,
            // Deliberately unrestricted: the dialect filter treats nil as "any",
            // and narrowing 79 marks on guesswork would starve leaves of
            // decoration long before it improved a single one.
            supportedDialects: nil,
            blend: role == .texture ? .multiply : nil,
            visualWeight: weight,
            allowsTextOverlap: allowsOverlap
        )
    }
}

struct IlluminationAsset: Identifiable, Codable, Equatable {
    var id: String
    var assetName: String
    var kind: IlluminationAssetKind
    var tags: [String]
    var supportedTemplates: [IlluminatedTemplateID]
    var defaultOpacity: Double
    var canTint: Bool
    var leafTraits: LeafAssetTraits? = nil
    /// Optional conditions for when this physical mark is allowed to enter a
    /// composition. Tags still describe what the mark *is* and help rank it;
    /// this trigger is the hard gate that keeps September ink, or one event
    /// phase's private symbols, from leaking into unrelated Pages.
    var placementTrigger: IlluminationPlacementTrigger? = nil
}

extension IlluminationAsset {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        assetName = MonthlyIssueMediaPath.resolving(try values.decode(String.self, forKey: .assetName))
        kind = try values.decode(IlluminationAssetKind.self, forKey: .kind)
        tags = try values.decode([String].self, forKey: .tags)
        supportedTemplates = try values.decode([IlluminatedTemplateID].self, forKey: .supportedTemplates)
        defaultOpacity = try values.decode(Double.self, forKey: .defaultOpacity)
        canTint = try values.decode(Bool.self, forKey: .canTint)
        leafTraits = try values.decodeIfPresent(LeafAssetTraits.self, forKey: .leafTraits)
        placementTrigger = try values.decodeIfPresent(IlluminationPlacementTrigger.self, forKey: .placementTrigger)
    }
}

private extension Set where Element == String {
    func overlaps(_ other: Set<String>) -> Bool { !isDisjoint(with: other) }
}

extension MarkShelf {
    /// The permanent shelf a mark belongs on.
    ///
    /// Derived rather than authored, for the same reason `LeafAssetTraits`
    /// derives its art direction: `tags` is already the authored description of
    /// what each mark is, and two hundred and fifty hand-written filings would
    /// rot the first time a pack shipped. The cascade below is deliberately the
    /// same shape as `PagewrightMarginaliaAchievement.quest(for:)`, which has
    /// been sorting these exact assets into these exact families for the lock
    /// system all along. One classifier, two consumers.
    ///
    /// Never returns `.thisMonth`, `.pastMonths`, or `.theDrawer` — those are
    /// locations decided at query time, not properties of the image.
    static func shelf(for asset: IlluminationAsset) -> MarkShelf {
        if let authored = asset.leafTraits?.shelf,
           permanentShelves.contains(authored) {
            return authored
        }

        let tags = Set(
            (asset.tags + (asset.leafTraits?.subjectTags ?? []))
                .map { $0.lowercased() }
        )

        // Curriculum scraps get their own small desk rather than swelling the
        // general hand to sixty-five marks. Their subject tags still route
        // them through the photo and folio compositors.
        if tags.contains("academy-tip") { return .academyDesk }

        // Handwriting outranks subject. An Academy note about the moon is
        // somebody's handwriting first and the moon second — the hand is the
        // reason a reader reaches for it.
        if tags.contains("handwritten") { return .handwriting }

        // Then the people. The goblin scribes and the Punctuation Pixie arrived
        // as whole families — faces, ears, hands, quills, their own punctuation
        // — and a reader who wants goblins wants all of it together, including
        // the goblin comma. Family beats medium here in a way it does not
        // anywhere else in this cascade, and that is the point of the shelf.
        if tags.overlaps(Self.marginFolkTags) { return .marginFolk }

        // Function outranks subject for the three kinds that are not pictures.
        // Botanical tape is still tape: a reader hunting tape wants all four
        // pieces in one place, not three here and one filed under ferns.
        switch asset.kind {
        case .tape: return .fastenings
        case .background, .overlay: return .wear
        case .paperScrap, .stamp, .doodle: break
        }

        // Subject beats medium, the same rule `LeafAssetTraits.derived` uses
        // when it decides a botanical stamp is a botanical.
        if tags.overlaps(Self.botanicalTags) { return .pressedAndGrown }
        if tags.overlaps(Self.skyTags) { return .skyAndNight }
        if tags.overlaps(Self.shoreAndWeatherTags) { return .shore }
        if tags.overlaps(Self.wayfindingTags) { return .wayfinding }
        if tags.overlaps(Self.creaturesTags) { return .creaturesAndCompany }

        // Medium, for the marks whose subject is nothing in particular.
        switch asset.kind {
        case .stamp: return .sealsAndLabels
        case .paperScrap: return .paper
        case .tape, .background, .overlay: return .wear  // handled above
        case .doodle:
            if tags.overlaps(Self.wearMarksTags) { return .wear }
            if tags.overlaps(Self.ornamentalTags) { return .flourishes }
            if tags.overlaps(Self.labelsTags) { return .sealsAndLabels }
            // What is left is the largest family nobody had a name for: small
            // inked asides with a thought in them.
            return .inklings
        }
    }

    private static let marginFolkTags: Set<String> = [
        "goblin", "pixie", "fae", "sprite", "imp", "scribe",
        "character", "portrait", "anatomy"
    ]
    private static let botanicalTags: Set<String> = [
        "botanical", "flower", "fern", "lavender", "clover", "thyme", "moss",
        "green", "leaf", "petal", "pressed", "seed"
    ]
    private static let skyTags: Set<String> = [
        "moon", "moth", "star", "constellation", "night", "dream", "dreams",
        "full-moon", "new-moon", "starlight", "sky", "dusk", "moonlight"
    ]
    private static let shoreAndWeatherTags: Set<String> = [
        "harbor", "tide", "lighthouse", "shell", "rain", "weather", "water",
        "anchor", "sailboat", "pond", "frog", "wind", "storm"
    ]
    private static let wayfindingTags: Set<String> = [
        "compass", "map", "walk", "west", "wander", "ticket", "passage",
        "arrival", "door", "threshold", "trail", "path", "key"
    ]
    private static let creaturesTags: Set<String> = [
        "paw", "bee", "creature", "teacup", "home", "heart", "company", "fox",
        "familiar", "feather", "companion"
    ]
    private static let wearMarksTags: Set<String> = [
        "stain", "grain", "speckle", "speckles", "edge", "vignette", "pale",
        "foxing", "texture", "parchment", "smudge", "ring"
    ]
    private static let ornamentalTags: Set<String> = [
        "flourish", "ornament", "rule", "curl", "corner", "divider"
    ]
    private static let labelsTags: Set<String> = [
        "tag", "label", "stamp", "observer", "banner", "postage", "card",
        "round", "seal"
    ]
}

extension IlluminationAsset {
    /// The permanent shelf this mark is filed on.
    var markShelf: MarkShelf { MarkShelf.shelf(for: self) }

    /// True when a mark is gated to a month, a world event, or an event phase.
    /// Such marks are shown on `This Month` while their gate is open and on
    /// `Past Months` once it has closed, rather than sitting quietly on a
    /// permanent shelf where nobody would connect them to what is happening.
    var isOccasional: Bool {
        guard let trigger = placementTrigger else { return false }
        let months = trigger.months?.isEmpty == false
        let events = trigger.activeWorldEventIDs?.isEmpty == false
        let phases = trigger.worldEventPhases?.isEmpty == false
        return months || events || phases
    }
}

/// The small piece of story/time state a decoration is allowed to inspect.
/// It is deliberately narrower than `PageTriggerContext`: marginalia may
/// answer the Page, season, or current event, but it does not get a second
/// curation engine of its own.
struct IlluminationPlacementContext: Equatable {
    var semanticTags: [String]
    var month: Int?
    var activeWorldEventIDs: [String]
    var worldEventPhases: [String]

    static let empty = IlluminationPlacementContext(
        semanticTags: [],
        month: nil,
        activeWorldEventIDs: [],
        worldEventPhases: []
    )
}

/// All declared conditions must pass. Omitted fields are open, which keeps old
/// packs compatible and lets a mark be merely thematic, purely seasonal, or
/// tied as tightly as `dictionary-rebellion` + `assembly`.
struct IlluminationPlacementTrigger: Codable, Equatable {
    var semanticTagsAny: [String]? = nil
    var months: [Int]? = nil
    var activeWorldEventIDs: [String]? = nil
    var worldEventPhases: [String]? = nil

    func allows(_ context: IlluminationPlacementContext) -> Bool {
        if let semanticTagsAny, !semanticTagsAny.isEmpty,
           !Self.overlaps(semanticTagsAny, context.semanticTags) {
            return false
        }
        if let months, !months.isEmpty {
            guard let month = context.month, months.contains(month) else {
                return false
            }
        }
        if let activeWorldEventIDs, !activeWorldEventIDs.isEmpty,
           !Self.overlaps(activeWorldEventIDs, context.activeWorldEventIDs) {
            return false
        }
        if let worldEventPhases, !worldEventPhases.isEmpty,
           !Self.overlaps(worldEventPhases, context.worldEventPhases) {
            return false
        }
        return true
    }

    /// The time half of the gate, without the subject half.
    ///
    /// `allows` answers "may this mark enter *this page*", so it also weighs
    /// `semanticTagsAny`. Browsing asks a narrower question — "does this mark
    /// exist right now" — and a mark gated to both September and the word
    /// "harbor" must not read as expired merely because nobody named a harbour.
    func allowsOccasion(_ context: IlluminationPlacementContext) -> Bool {
        if let months, !months.isEmpty {
            guard let month = context.month, months.contains(month) else {
                return false
            }
        }
        if let activeWorldEventIDs, !activeWorldEventIDs.isEmpty,
           !Self.overlaps(activeWorldEventIDs, context.activeWorldEventIDs) {
            return false
        }
        if let worldEventPhases, !worldEventPhases.isEmpty,
           !Self.overlaps(worldEventPhases, context.worldEventPhases) {
            return false
        }
        return true
    }

    private static func overlaps(_ wanted: [String], _ present: [String]) -> Bool {
        let normalizedPresent = Set(present.map(normalized))
        return wanted.map(normalized).contains(where: normalizedPresent.contains)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct IlluminationAssetPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: PackAvailability
    var supportedTemplates: [IlluminatedTemplateID]
    var backgrounds: [IlluminationAsset]
    var paperScraps: [IlluminationAsset]
    var stamps: [IlluminationAsset]
    var doodles: [IlluminationAsset]
    var tape: [IlluminationAsset]
    var overlays: [IlluminationAsset]
    var fallbackPhrases: [IlluminatedTemplateID: TemplateFallbackPhrases]

    var allAssets: [IlluminationAsset] {
        backgrounds + paperScraps + stamps + doodles + tape + overlays
    }
}

enum MarginaliaContentKey: String, Codable, Equatable {
    case fieldNote
    case stampLabel
    case observationList
    case closingLine
    case souvenirCandidate
    case fixedCompassReminder
    case fixedFrameLine
}

enum IlluminatedFontStyle: String, Codable, Equatable {
    case serifTitle
    case serifBody
    case handwritten
    case stamp
}

struct IlluminationTemplate: Identifiable, Codable, Equatable {
    var id: IlluminatedTemplateID
    var displayName: String
    var preferredCanvas: CanvasPreference
    var supportedPhotoOrientations: [PhotoOrientation]
    var defaultPhotoTreatment: PhotoTreatment
    var requiredSlots: [TemplateTextSlotSpec]
    var optionalSlots: [TemplateTextSlotSpec]
    var decorationSlots: [TemplateDecorationSlotSpec]
    var backgroundTags: [String]
}

struct IlluminatedTextSlot: Identifiable, Codable, Equatable {
    var id: UUID
    var slotId: String
    var paperAssetName: String
    var title: String?
    var body: String
    var position: CodablePoint
    var size: CodableSize
    var rotationDegrees: Double
    var fontStyle: IlluminatedFontStyle
}

struct IlluminatedCompositionPlan: Codable, Equatable {
    var templateId: IlluminatedTemplateID
    var assetPackId: String
    var randomSeed: Int
    var canvasSize: CodableSize
    var photoFrame: PhotoFrameSpec
    var photoTreatment: PhotoTreatment
    var textSlots: [IlluminatedTextSlot]
    var decorations: [DecorationPlacement]
    var backgroundAssetName: String
    var textureOverlayNames: [String]
    /// A canvas-space region that scraps and marks may approach but not cover.
    /// Old saved plans decode with no guard and retain their original layout.
    var marginaliaExclusionRect: CodableRect? = nil
}

struct IlluminatedPhotoDraft: Identifiable, Codable, Equatable {
    var id: UUID
    var assetLocalIdentifier: String
    var sourceAssetName: String
    var analysis: PhotoAnalysis
    var compositionPlan: IlluminatedCompositionPlan
    var renderedPreviewPath: String
    var status: IlluminatedPageStatus
    var createdAt: Date
    var updatedAt: Date
}

enum FakePhotoIlluminationAnalyzer {
    static func analyze(assetName: String) -> PhotoAnalysis {
        PhotoAnalysis.academyFallback
    }

    static func analyze(illustration plate: LabyrinthIllustrationPlate) -> PhotoAnalysis {
        let loweredTags = plate.tags.map { $0.lowercased() }
        let profile = BookReferenceCatalog.characterIllustrationProfile(id: plate.characterID)
        let template: IlluminatedTemplateID
        if profile != nil {
            template = .academyFieldStudy
        } else if loweredTags.contains("weather") || loweredTags.contains("harbor") {
            template = .harborFieldNote
        } else if loweredTags.contains("watch") || loweredTags.contains("witness") || loweredTags.contains("page-light") {
            template = .restAndQuiet
        } else {
            template = .academyFieldStudy
        }

        let motifs = Array((["illustration"] + (profile == nil ? [] : ["character"]) + loweredTags).prefix(6))
        let titleWords = plate.title
            .split(separator: " ")
            .prefix(3)
            .joined(separator: " ")
        let fieldNote = profile.map { "The Labyrinth filed \($0.characterName) as a living dossier." } ?? "The Labyrinth filed a witness."
        let closingLine = profile == nil
            ? "The Book kept the page: image listened."
            : "The Book kept the page: portrait, note, and name braided together."
        let souvenir = profile.map { "A character portrait of \($0.characterName) became reusable evidence for the Book of You." }
            ?? "A bundled illustration became evidence from the story side."

        return PhotoAnalysisValidator.validate(
            PhotoAnalysis(
                scene: plate.caption,
                motifs: motifs,
                mood: profile == nil
                    ? (loweredTags.contains("weather") ? "watchful weather" : "ink and quiet")
                    : "academy dossier",
                suggestedTemplate: template,
                marginalia: PhotoMarginalia(
                    fieldNote: fieldNote,
                    stampLabel: titleWords.isEmpty ? "Field Plate" : titleWords,
                    observationList: [
                        "Ink kept its post",
                        "Color held the doorway",
                        "Margins stayed awake",
                        "The plate watched back",
                        "Story light lingered"
                    ],
                    closingLine: closingLine
                ),
                souvenirCandidates: [
                    "The Labyrinth left a picture where the day could find it.",
                    souvenir
                ]
            ),
            fallback: .academyFallback
        )
    }
}

extension PhotoAnalysis {
    static func fromSurfaceMetadata(_ metadata: [String: String], fallback: PhotoAnalysis) -> PhotoAnalysis {
        let observations = metadata["observations"]?
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let souvenirs = metadata["souvenirs"]?
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let motifs = metadata["motifs"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let template = metadata["template"].flatMap(IlluminatedTemplateID.init(rawValue:)) ?? fallback.suggestedTemplate

        return PhotoAnalysisValidator.validate(
            PhotoAnalysis(
                scene: metadata["scene"] ?? fallback.scene,
                motifs: motifs ?? fallback.motifs,
                mood: metadata["mood"] ?? fallback.mood,
                suggestedTemplate: template,
                marginalia: PhotoMarginalia(
                    fieldNote: metadata["fieldNote"] ?? fallback.marginalia.fieldNote,
                    stampLabel: metadata["stampLabel"] ?? metadata["headline"] ?? fallback.marginalia.stampLabel,
                    observationList: observations ?? fallback.marginalia.observationList,
                    closingLine: metadata["closingLine"] ?? fallback.marginalia.closingLine
                ),
                souvenirCandidates: souvenirs ?? fallback.souvenirCandidates
            ),
            fallback: fallback
        )
    }

    static let academyFallback = PhotoAnalysis(
        scene: "An ordinary scene waits to be catalogued.",
        motifs: ["ordinary", "detail", "field", "study"],
        mood: "curious and kept",
        suggestedTemplate: .academyFieldStudy,
        marginalia: PhotoMarginalia(
            fieldNote: "The ordinary requested documentation.",
            stampLabel: "Field Study",
            observationList: [
                "One detail, clearly volunteering",
                "Light making its argument",
                "Color holding its ground",
                "Texture refusing to vanish",
                "The scene, still available"
            ],
            closingLine: "The Book kept the page: detail spoke."
        ),
        souvenirCandidates: [
            "One ordinary detail stood up and became evidence.",
            "The scene waited patiently to be noticed."
        ]
    )

    static let goodCompanyFallback = PhotoAnalysis(
        scene: "Good company appears close to the camera.",
        motifs: ["company", "smile", "day", "kept"],
        mood: "warm and bright",
        suggestedTemplate: .goodCompany,
        marginalia: PhotoMarginalia(
            fieldNote: "Good company, plainly glowing.",
            stampLabel: "Joy Census",
            observationList: [
                "Two smiles, fully present",
                "Light doing friendly work",
                "Glasses catching the day",
                "Jackets keeping their post",
                "Background politely blurred"
            ],
            closingLine: "The Book kept the page: company stayed."
        ),
        souvenirCandidates: [
            "The day held still long enough for good company.",
            "Two smiles made the background less important."
        ]
    )

    static let harborFallback = PhotoAnalysis(
        scene: "A harbor scene sits under open sky.",
        motifs: ["harbor", "water", "sky", "dock"],
        mood: "salt and light",
        suggestedTemplate: .harborFieldNote,
        marginalia: PhotoMarginalia(
            fieldNote: "The harbor kept its minutes.",
            stampLabel: "Dockside Census",
            observationList: [
                "Water holding small weather",
                "Masts writing thin lines",
                "Dock boards keeping watch",
                "Sky spread wide open",
                "Boats waiting without complaint"
            ],
            closingLine: "The Book kept the page: tide waited."
        ),
        souvenirCandidates: [
            "The harbor arranged its small evidence in plain sight.",
            "The water held the day without asking why."
        ]
    )
}

enum CoreMarginsPack {
    static let id = "core-margins"

    static let pack = IlluminationAssetPack(
        id: id,
        displayName: "Core Margins Pack",
        version: "1.0",
        author: "The Book",
        availability: .bundledFree,
        supportedTemplates: IlluminatedTemplateID.allCases,
        backgrounds: [
            asset("parchment_portrait_01", "ParchmentTexture", .background, ["parchment", "portrait", "generic"]),
            asset("parchment_landscape_01", "ParchmentTexture", .background, ["parchment", "landscape", "generic"])
        ],
        paperScraps: [
            asset("illumination_paper_fern", "IlluminationPaperFern", .paperScrap, ["scrap", "wide", "narrow", "torn", "blank", "botanical", "field", "generic"]),
            asset("illumination_paper_compass", "IlluminationPaperCompass", .paperScrap, ["scrap", "wide", "narrow", "torn", "blank", "compass", "map", "generic"]),
            asset("illumination_paper_moth", "IlluminationPaperMoth", .paperScrap, ["scrap", "wide", "narrow", "torn", "blank", "moth", "night", "generic"]),
            asset("illumination_paper_moon", "IlluminationPaperMoon", .paperScrap, ["scrap", "wide", "narrow", "torn", "blank", "moon", "night", "generic"]),
            asset("illumination_paper_deckled", "IlluminationPaperDeckled", .paperScrap, ["scrap", "wide", "narrow", "torn", "blank", "plain", "generic"]),
            asset("illumination_paper_violet", "IlluminationPaperViolet", .paperScrap, ["scrap", "wide", "narrow", "torn", "blank", "flower", "botanical", "generic"]),
            asset("illumination_blank_summary", "IlluminationScrapS02_06", .paperScrap, ["scrap", "wide", "blank", "generic"]),
            asset("illumination_blank_date", "IlluminationScrapS02_08", .paperScrap, ["scrap", "wide", "blank", "field"]),
            asset("illumination_blank_field", "IlluminationScrapS03_04", .paperScrap, ["scrap", "wide", "blank", "field"]),
            asset("illumination_blank_torn", "IlluminationScrapS03_11", .paperScrap, ["scrap", "torn", "blank", "map"]),
            asset("illumination_blank_label", "IlluminationScrapS03_25", .paperScrap, ["label", "blank", "ticket"]),
            asset("scrap_note_torn_01", "ParchmentFiber", .paperScrap, ["scrap", "torn", "generic"]),
            asset("scrap_note_torn_02", "ParchmentTexture", .paperScrap, ["scrap", "torn", "generic"]),
            asset("scrap_note_wide_01", "ParchmentFiber", .paperScrap, ["scrap", "wide", "generic"]),
            asset("scrap_note_narrow_01", "ParchmentTexture", .paperScrap, ["scrap", "narrow", "generic"]),
            asset("scrap_label_01", "ParchmentFiber", .paperScrap, ["label", "generic"]),
            asset("scrap_label_pink_01", "MarginaliaSeal", .paperScrap, ["label", "pink", "stamp"])
        ],
        stamps: [
            themedAsset("marginalia_goblin_comma", "MarginaliaGoblinComma", .stamp, ["marginalia-goblin", "goblin", "marginalia", "academy", "punctuation", "comma", "warning", "sigil"], 60, 88, .sigil, [.lowerTrailing, .upperTrailing], 0.70),
            themedAsset("marginalia_goblin_question", "MarginaliaGoblinQuestion", .stamp, ["marginalia-goblin", "goblin", "marginalia", "academy", "punctuation", "question-mark", "curiosity", "sigil"], 94, 167, .sigil, [.lowerTrailing, .upperTrailing], 0.74),
            themedAsset("marginalia_goblin_exclamation", "MarginaliaGoblinExclamation", .stamp, ["marginalia-goblin", "goblin", "marginalia", "academy", "punctuation", "exclamation-mark", "warning", "sigil"], 55, 174, .sigil, [.lowerTrailing, .upperTrailing], 0.74),
            themedAsset("punctuation_charm_comma", "PunctuationCharmComma", .stamp, ["punctuation", "comma", "charm", "sigil", "academy", "writing"], 70, 143, .sigil, [.lowerTrailing, .upperTrailing], 0.68),
            themedAsset("punctuation_charm_semicolon", "PunctuationCharmSemicolon", .stamp, ["punctuation", "semicolon", "charm", "sigil", "academy", "writing"], 49, 149, .sigil, [.lowerTrailing, .upperTrailing], 0.68),
            themedAsset("punctuation_charm_question", "PunctuationCharmQuestion", .stamp, ["punctuation", "question-mark", "curiosity", "charm", "sigil", "academy", "writing"], 67, 152, .sigil, [.lowerTrailing, .upperTrailing], 0.72),
            themedAsset("punctuation_charm_exclamation", "PunctuationCharmExclamation", .stamp, ["punctuation", "exclamation-mark", "warning", "charm", "sigil", "academy", "writing"], 48, 175, .sigil, [.lowerTrailing, .upperTrailing], 0.72),
            themedAsset("punctuation_charm_amethyst", "PunctuationCharmAmethyst", .stamp, ["punctuation", "exclamation-mark", "amethyst", "charm", "sigil", "academy", "writing"], 45, 136, .sigil, [.lowerTrailing, .upperTrailing], 0.68),
            themedAsset("punctuation_charm_quotation_medallion", "PunctuationCharmQuotationMedallion", .stamp, ["punctuation", "quotation", "quote", "charm", "sigil", "academy", "writing"], 81, 130, .sigil, [.lowerTrailing, .upperTrailing], 0.72),
            themedAsset("punctuation_charm_note_scroll", "PunctuationCharmNoteScroll", .stamp, ["punctuation", "note", "scroll", "charm", "academy", "writing"], 71, 180, .fieldNote, [.middleLeading, .middleTrailing], 0.78),
            themedAsset("punctuation_charm_quotation_book", "PunctuationCharmQuotationBook", .stamp, ["punctuation", "quotation", "quote", "book", "charm", "academy", "writing"], 91, 149, .sigil, [.lowerTrailing, .upperTrailing], 0.76),
            themedAsset("punctuation_charm_feather", "PunctuationCharmFeather", .stamp, ["punctuation", "feather", "quill", "charm", "academy", "writing"], 59, 148, .sigil, [.middleLeading, .middleTrailing], 0.70),
            asset("illumination_wonder_observatory", "IlluminationScrapS01_17", .stamp, ["bee", "wonder", "stamp", "round"]),
            asset("illumination_library_possibilities", "IlluminationScrapS01_24", .stamp, ["book", "library", "stamp", "round"]),
            asset("illumination_witness_ordinary", "IlluminationScrapS02_15", .stamp, ["bee", "ordinary", "stamp", "round"]),
            asset("illumination_library_acquired", "IlluminationScrapS02_18", .stamp, ["library", "archive", "stamp", "label"]),
            asset("illumination_keep_moment", "IlluminationScrapS02_24", .stamp, ["memory", "moment", "stamp", "label"]),
            asset("illumination_luna_moth", "IlluminationScrapS03_18", .stamp, ["moth", "night", "stamp", "postage"]),
            asset("illumination_passage_ticket", "IlluminationScrapS03_23", .stamp, ["ticket", "wonder", "stamp", "label"]),
            asset("illumination_astrolabe_stamp", "IlluminationScrapS03_24", .stamp, ["compass", "star", "stamp", "round"]),
            asset("stamp_academy_bee", "MarginaliaStamp", .stamp, ["bee", "academy", "generic"]),
            asset("stamp_margin_glass", "MarginaliaSeal", .stamp, ["margin", "glass", "generic"]),
            asset("stamp_field_note", "MarginaliaScrap", .stamp, ["field", "note", "generic"]),
            asset("stamp_pawlogy", "MarginaliaStamp", .stamp, ["paw", "creature"]),
            asset("stamp_west_write", "MarginaliaCompass", .stamp, ["compass", "west"])
        ],
        doodles: academyWarningAssets + academyNoteAssets + academyTipAssets + botanicalAssets + [
            themedAsset("marginalia_goblin_quill_standing", "MarginaliaGoblinQuillStanding", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "quill", "ink", "writing", "standing"], 343, 345, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.02),
            themedAsset("marginalia_goblin_writing_crouched", "MarginaliaGoblinWritingCrouched", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "note", "ink", "writing", "crouched"], 289, 262, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.00),
            themedAsset("marginalia_goblin_shushing", "MarginaliaGoblinShushing", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "quiet", "secret", "warning"], 285, 340, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.00),
            themedAsset("marginalia_goblin_questioning", "MarginaliaGoblinQuestioning", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "question-mark", "curiosity", "warning"], 358, 315, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.06),
            themedAsset("marginalia_goblin_page_hiding", "MarginaliaGoblinPageHiding", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "page", "hiding", "secret"], 255, 336, .portrait, [.lowerField, .middleLeading, .middleTrailing], 0.98),
            themedAsset("marginalia_goblin_ink_carrier", "MarginaliaGoblinInkCarrier", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "ink", "bottle", "writing"], 272, 293, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.00),
            themedAsset("marginalia_goblin_reading", "MarginaliaGoblinReading", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "reading", "book", "study"], 259, 303, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.00),
            themedAsset("marginalia_goblin_sleeping", "MarginaliaGoblinSleeping", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "sleep", "rest", "notes", "ink"], 341, 280, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.04),
            themedAsset("marginalia_goblin_face_grinning", "MarginaliaGoblinFaceGrinning", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "portrait", "expression", "grin", "play"], 271, 179, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.74),
            themedAsset("marginalia_goblin_face_cross", "MarginaliaGoblinFaceCross", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "portrait", "expression", "cross", "warning"], 244, 172, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.74),
            themedAsset("marginalia_goblin_face_skeptical", "MarginaliaGoblinFaceSkeptical", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "portrait", "expression", "skeptical", "warning"], 205, 176, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("marginalia_goblin_face_laughing", "MarginaliaGoblinFaceLaughing", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "portrait", "expression", "laugh", "play"], 212, 155, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("marginalia_goblin_face_sleepy", "MarginaliaGoblinFaceSleepy", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "character", "portrait", "expression", "sleepy", "rest"], 177, 206, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("marginalia_goblin_hand", "MarginaliaGoblinHand", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "hand", "anatomy", "ink"], 197, 147, .ornament, [.middleLeading, .middleTrailing, .lowerField], 0.76),
            themedAsset("marginalia_goblin_nose_round", "MarginaliaGoblinNoseRound", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "nose", "anatomy", "round"], 105, 116, .ornament, [.middleLeading, .middleTrailing], 0.64),
            themedAsset("marginalia_goblin_nose_long", "MarginaliaGoblinNoseLong", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "nose", "anatomy", "long"], 109, 139, .ornament, [.middleLeading, .middleTrailing], 0.64),
            themedAsset("marginalia_goblin_nose_snub", "MarginaliaGoblinNoseSnub", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "nose", "anatomy", "snub"], 101, 123, .ornament, [.middleLeading, .middleTrailing], 0.64),
            themedAsset("marginalia_goblin_ear_narrow", "MarginaliaGoblinEarNarrow", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "ear", "anatomy", "narrow"], 139, 135, .ornament, [.middleLeading, .middleTrailing], 0.66),
            themedAsset("marginalia_goblin_ear_wide", "MarginaliaGoblinEarWide", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "ear", "anatomy", "wide"], 142, 117, .ornament, [.middleLeading, .middleTrailing], 0.66),
            themedAsset("marginalia_goblin_ear_hooped", "MarginaliaGoblinEarHooped", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "ear", "anatomy", "hoop", "jewelry"], 159, 132, .ornament, [.middleLeading, .middleTrailing], 0.68),
            themedAsset("marginalia_goblin_bare_foot", "MarginaliaGoblinBareFoot", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "foot", "anatomy", "bare"], 162, 145, .ornament, [.lowerField, .lowerLeading, .lowerTrailing], 0.70),
            themedAsset("marginalia_goblin_brown_boot", "MarginaliaGoblinBrownBoot", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "foot", "boot", "brown"], 146, 159, .ornament, [.lowerField, .lowerLeading, .lowerTrailing], 0.70),
            themedAsset("marginalia_goblin_blue_foot", "MarginaliaGoblinBlueFoot", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "foot", "boot", "blue"], 121, 141, .ornament, [.lowerField, .lowerLeading, .lowerTrailing], 0.70),
            themedAsset("marginalia_goblin_quill", "MarginaliaGoblinQuill", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "quill", "ink", "writing"], 211, 265, .ornament, [.middleLeading, .middleTrailing, .lowerField], 0.82),
            themedAsset("marginalia_goblin_blue_ink", "MarginaliaGoblinBlueInk", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "ink", "bottle", "blue", "writing"], 167, 153, .ornament, [.lowerField, .middleLeading, .middleTrailing], 0.78),
            themedAsset("marginalia_goblin_green_ink", "MarginaliaGoblinGreenInk", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "ink", "bottle", "green", "writing"], 103, 138, .ornament, [.lowerField, .middleLeading, .middleTrailing], 0.74),
            themedAsset("marginalia_goblin_sealed_note", "MarginaliaGoblinSealedNote", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "note", "seal", "warning", "writing"], 122, 131, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.78),
            themedAsset("marginalia_goblin_crowned_note", "MarginaliaGoblinCrownedNote", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "note", "crown", "warning", "writing"], 96, 126, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.76),
            themedAsset("marginalia_goblin_crumpled_note", "MarginaliaGoblinCrumpledNote", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "note", "crumpled", "discarded", "writing"], 102, 97, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.72),
            themedAsset("marginalia_goblin_tied_scroll", "MarginaliaGoblinTiedScroll", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "scroll", "note", "tied", "writing"], 103, 147, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.76),
            themedAsset("marginalia_goblin_royal_wax_seal", "MarginaliaGoblinRoyalWaxSeal", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "wax-seal", "crown", "warning", "sigil"], 115, 151, .sigil, [.lowerTrailing, .upperTrailing], 0.78),
            themedAsset("marginalia_goblin_red_ribbon", "MarginaliaGoblinRedRibbon", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "ribbon", "red", "ornament"], 254, 118, .ornament, [.upperTrailing, .lowerLeading, .middleTrailing], 0.76),
            themedAsset("marginalia_goblin_satchel", "MarginaliaGoblinSatchel", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "satchel", "notes", "quill", "writing"], 247, 295, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.92),
            themedAsset("marginalia_goblin_open_book", "MarginaliaGoblinOpenBook", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "book", "open", "reading", "writing"], 289, 161, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.90),
            themedAsset("marginalia_goblin_illuminated_scroll", "MarginaliaGoblinIlluminatedScroll", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "scroll", "illuminated", "blue", "writing"], 264, 165, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.88),
            themedAsset("marginalia_goblin_corner_flourish", "MarginaliaGoblinCornerFlourish", .doodle, ["marginalia-goblin", "goblin", "marginalia", "academy", "corner", "flourish", "illuminated", "ornament"], 239, 173, .ornament, [.upperLeading, .upperTrailing, .lowerTrailing], 0.82),
            themedAsset("punctuation_pixie_front", "PunctuationPixieFront", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "words", "writing", "character", "front"], 357, 492, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.04),
            themedAsset("punctuation_pixie_profile", "PunctuationPixieProfile", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "words", "writing", "character", "profile"], 261, 494, .portrait, [.lowerField, .middleLeading, .middleTrailing], 0.96),
            themedAsset("punctuation_pixie_back", "PunctuationPixieBack", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "words", "writing", "character", "back"], 400, 491, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.04),
            themedAsset("punctuation_pixie_in_flight", "PunctuationPixieInFlight", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "words", "writing", "character", "flying", "quill"], 480, 519, .portrait, [.lowerField, .middleLeading, .middleTrailing], 1.10),
            themedAsset("punctuation_pixie_face_bright", "PunctuationPixieFaceBright", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "character", "portrait", "expression", "bright"], 203, 197, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("punctuation_pixie_face_wink", "PunctuationPixieFaceWink", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "character", "portrait", "expression", "wink", "play"], 194, 207, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("punctuation_pixie_face_surprised", "PunctuationPixieFaceSurprised", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "character", "portrait", "expression", "surprise"], 199, 204, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("punctuation_pixie_face_laughing", "PunctuationPixieFaceLaughing", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "character", "portrait", "expression", "laugh", "play"], 198, 200, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("punctuation_pixie_face_cross", "PunctuationPixieFaceCross", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "character", "portrait", "expression", "cross", "warning"], 196, 201, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("punctuation_pixie_face_thinking", "PunctuationPixieFaceThinking", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "character", "portrait", "expression", "thinking", "curiosity"], 203, 217, .portrait, [.upperTrailing, .middleLeading, .middleTrailing], 0.72),
            themedAsset("punctuation_pixie_wings_open", "PunctuationPixieWingsOpen", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "wings", "open", "ornament"], 322, 322, .ornament, [.middleLeading, .middleTrailing, .lowerField], 0.90),
            themedAsset("punctuation_pixie_wing_profile", "PunctuationPixieWingProfile", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "wing", "profile", "ornament"], 112, 289, .ornament, [.middleLeading, .middleTrailing], 0.78),
            themedAsset("punctuation_pixie_wings_folded", "PunctuationPixieWingsFolded", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "wings", "folded", "ornament"], 101, 227, .ornament, [.middleLeading, .middleTrailing], 0.78),
            themedAsset("punctuation_pixie_quill_hand", "PunctuationPixieQuillHand", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "quill", "ink", "writing", "hand"], 172, 342, .ornament, [.middleLeading, .middleTrailing, .lowerField], 0.84),
            themedAsset("punctuation_pixie_notes_boot", "PunctuationPixieNotesBoot", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "boot", "notes", "writing"], 159, 237, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.84),
            themedAsset("punctuation_pixie_satchel", "PunctuationPixieSatchel", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "satchel", "notes", "ink", "writing"], 227, 274, .fieldNote, [.lowerField, .middleLeading, .middleTrailing], 0.94),
            themedAsset("punctuation_pixie_wings_small_open", "PunctuationPixieWingsSmallOpen", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "wings", "open", "small", "ornament"], 138, 136, .ornament, [.upperTrailing, .lowerLeading, .middleTrailing], 0.70),
            themedAsset("punctuation_pixie_wings_small_folded", "PunctuationPixieWingsSmallFolded", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "wings", "folded", "small", "ornament"], 54, 127, .ornament, [.upperTrailing, .lowerLeading, .middleTrailing], 0.66),
            themedAsset("punctuation_pixie_ink_bottle", "PunctuationPixieInkBottle", .doodle, ["punctuation-pixie", "pixie", "punctuation", "academy", "ink", "bottle", "writing"], 121, 180, .ornament, [.lowerField, .middleLeading, .middleTrailing], 0.78),
            asset("illumination_lighthouse_01", "IlluminationScrapS01_01", .doodle, ["lighthouse", "harbor", "light"]),
            asset("illumination_living_story", "IlluminationScrapS01_02", .doodle, ["story", "book", "marginalia"]),
            asset("illumination_field_note_harbor", "IlluminationScrapS01_03", .doodle, ["field", "harbor", "marginalia"]),
            asset("illumination_map_unseen", "IlluminationScrapS01_04", .doodle, ["map", "compass", "marginalia"]),
            asset("illumination_noticing_magic", "IlluminationScrapS01_05", .doodle, ["wonder", "notice", "botanical", "marginalia"]),
            asset("illumination_handle_curiosity", "IlluminationScrapS01_06", .doodle, ["tag", "curiosity", "marginalia"]),
            asset("illumination_field_tag", "IlluminationScrapS01_07", .doodle, ["tag", "botanical", "marginalia"]),
            asset("illumination_belief_margin", "IlluminationScrapS01_08", .doodle, ["belief", "feather", "marginalia"]),
            asset("illumination_observation_small", "IlluminationScrapS01_09", .doodle, ["observation", "water", "harbor", "marginalia"]),
            asset("illumination_inkwell", "IlluminationScrapS01_10", .doodle, ["ink", "write", "marginalia"]),
            asset("illumination_kept_tide", "IlluminationScrapS01_11", .doodle, ["book", "tide", "marginalia"]),
            asset("illumination_reported_small", "IlluminationScrapS01_12", .doodle, ["notice", "small", "marginalia"]),
            asset("illumination_memory_ink", "IlluminationScrapS01_13", .doodle, ["ink", "memory", "marginalia"]),
            asset("illumination_found_margins", "IlluminationScrapS01_14", .doodle, ["found", "margin", "marginalia"]),
            asset("illumination_letters_margins", "IlluminationScrapS01_15", .doodle, ["letter", "margin", "marginalia"]),
            asset("illumination_waiting_page", "IlluminationScrapS01_16", .doodle, ["page", "patient", "marginalia"]),
            asset("illumination_gathering_meaning", "IlluminationScrapS01_18", .doodle, ["quiet", "meaning", "marginalia"]),
            asset("illumination_lanterns_lit", "IlluminationScrapS01_19", .doodle, ["light", "story", "marginalia"]),
            asset("illumination_frame_attention", "IlluminationScrapS01_20", .doodle, ["photo", "attention", "marginalia"]),
            asset("illumination_lavender_stamp", "IlluminationScrapS01_21", .doodle, ["lavender", "botanical", "rest"]),
            asset("illumination_compass_reminder", "IlluminationScrapS01_22", .doodle, ["compass", "walk", "marginalia"]),
            asset("illumination_thyme_stamp", "IlluminationScrapS01_23", .doodle, ["botanical", "home"]),
            asset("illumination_map_fragment", "IlluminationScrapS01_25", .doodle, ["map", "compass"]),
            asset("illumination_moth_ticket", "IlluminationScrapS01_26", .doodle, ["moth", "ticket", "night"]),
            asset("illumination_interrupt_usual", "IlluminationScrapS01_27", .doodle, ["wonder", "ordinary", "marginalia"]),
            asset("illumination_quiet_pages", "IlluminationScrapS01_28", .doodle, ["quiet", "book", "marginalia"]),
            asset("illumination_lighthouse_02", "IlluminationScrapS02_01", .doodle, ["lighthouse", "harbor", "light"]),
            asset("illumination_pressed_fern", "IlluminationScrapS02_02", .doodle, ["botanical", "green", "tag"]),
            asset("illumination_small_astonishments", "IlluminationScrapS02_04", .doodle, ["small", "wonder", "marginalia"]),
            asset("illumination_lamp_remembered", "IlluminationScrapS02_05", .doodle, ["lamp", "light", "memory"]),
            asset("illumination_world_light", "IlluminationScrapS02_07", .doodle, ["light", "world", "marginalia"]),
            asset("illumination_observer_desk", "IlluminationScrapS02_09", .doodle, ["observer", "label", "marginalia"]),
            asset("illumination_curiosity_ticket", "IlluminationScrapS02_10", .doodle, ["ticket", "curiosity"]),
            asset("illumination_patient_day", "IlluminationScrapS02_11", .doodle, ["map", "day", "marginalia"]),
            asset("illumination_brown_feather", "IlluminationScrapS02_12", .doodle, ["feather", "brown"]),
            asset("illumination_ordinary_wonder", "IlluminationScrapS02_13", .doodle, ["ordinary", "wonder", "botanical"]),
            asset("illumination_moss_return", "IlluminationScrapS02_14", .doodle, ["moss", "green", "home"]),
            asset("illumination_daylight_missed", "IlluminationScrapS02_16", .doodle, ["light", "margin", "marginalia"]),
            asset("illumination_moon_strip", "IlluminationScrapS02_17", .doodle, ["moon", "night"]),
            asset("illumination_dreams_ticket", "IlluminationScrapS02_20", .doodle, ["dreams", "ticket"]),
            asset("illumination_weather_cabinet", "IlluminationScrapS02_26", .doodle, ["weather", "cabinet", "marginalia"]),
            asset("illumination_unannounced", "IlluminationScrapS02_27", .doodle, ["surprise", "arrival", "marginalia"]),
            asset("illumination_moon_row", "IlluminationScrapS03_01", .doodle, ["moon", "night"]),
            asset("illumination_clover_tag", "IlluminationScrapS03_02", .doodle, ["clover", "botanical", "tag"]),
            asset("illumination_library_card", "IlluminationScrapS03_03", .doodle, ["library", "book", "card"]),
            asset("illumination_pale_feather", "IlluminationScrapS03_05", .doodle, ["feather", "soft"]),
            asset("illumination_moon_marker", "IlluminationScrapS03_06", .doodle, ["moon", "night"]),
            asset("illumination_archive_quiet", "IlluminationScrapS03_07", .doodle, ["archive", "quiet", "marginalia"]),
            asset("illumination_flower_card", "IlluminationScrapS03_08", .doodle, ["flower", "botanical"]),
            asset("illumination_study_tag", "IlluminationScrapS03_09", .doodle, ["tag", "study", "moss"]),
            asset("illumination_moth_strip", "IlluminationScrapS03_10", .doodle, ["moth", "strip"]),
            asset("illumination_borrowed_hush", "IlluminationScrapS03_12", .doodle, ["quiet", "hush", "marginalia"]),
            asset("illumination_windy_tag", "IlluminationScrapS03_13", .doodle, ["wind", "tag"]),
            asset("illumination_observed_eye", "IlluminationScrapS03_14", .doodle, ["eye", "observed", "marginalia"]),
            asset("illumination_ink_proof", "IlluminationScrapS03_15", .doodle, ["ink", "attention", "marginalia"]),
            asset("illumination_script_strip", "IlluminationScrapS03_16", .doodle, ["script", "letter"]),
            asset("illumination_constellation", "IlluminationScrapS03_17", .doodle, ["star", "constellation"]),
            asset("illumination_wander_record", "IlluminationScrapS03_19", .doodle, ["wander", "record", "banner"]),
            asset("illumination_edge_remembers", "IlluminationScrapS03_20", .doodle, ["edge", "memory", "marginalia"]),
            asset("illumination_rain_collected", "IlluminationScrapS03_21", .doodle, ["rain", "weather", "botanical"]),
            asset("illumination_margins_speak", "IlluminationScrapS03_22", .doodle, ["margin", "speak", "marginalia"]),
            asset("illumination_field_note_dry", "IlluminationScrapS03_26", .doodle, ["field", "note", "label"]),
            asset("illumination_starlight", "IlluminationScrapS03_27", .doodle, ["star", "light", "marginalia"]),
            asset("illumination_spell_progress", "IlluminationScrapS03_28", .doodle, ["spell", "magic", "marginalia"]),
            asset("doodle_compass_01", "MarginaliaCompass", .doodle, ["compass", "generic"]),
            asset("doodle_feather_01", "MarginaliaFeather", .doodle, ["feather", "generic"]),
            asset("doodle_lavender_01", "MarginaliaLavender", .doodle, ["lavender", "rest"]),
            asset("doodle_shell_01", "MarginaliaShell", .doodle, ["shell", "harbor"]),
            asset("doodle_anchor_01", "MarginaliaCompass", .doodle, ["anchor", "harbor"]),
            asset("doodle_sailboat_01", "MarginaliaCompass", .doodle, ["sailboat", "harbor"]),
            asset("doodle_teacup_01", "MarginaliaScrap", .doodle, ["teacup", "home"]),
            asset("doodle_paw_01", "MarginaliaStar", .doodle, ["paw", "creature"]),
            asset("doodle_star_01", "MarginaliaStar", .doodle, ["star", "generic"]),
            asset("doodle_heart_01", "MarginaliaShell", .doodle, ["heart", "company"]),

            // Cut from two hand-painted sheets. Every one states its own art
            // direction rather than leaning on `derived`, because these were
            // classified by looking at them: a stain pale enough to read
            // through may lie under prose as a watermark, ink may not.
            asset("illuminationstain01", "IlluminationStain01", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 0.88,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain02", "IlluminationStain02", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 0.94,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain03", "IlluminationStain03", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.19,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain04", "IlluminationStain04", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.01,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain05", "IlluminationStain05", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.11,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain06", "IlluminationStain06", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 2.02,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain07", "IlluminationStain07", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.36,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain08", "IlluminationStain08", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.11,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain09", "IlluminationStain09", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.09,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain10", "IlluminationStain10", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.56,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain11", "IlluminationStain11", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 2.31,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain12", "IlluminationStain12", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 2.78,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain13", "IlluminationStain13", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.04,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain14", "IlluminationStain14", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.77,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain15", "IlluminationStain15", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.38,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain16", "IlluminationStain16", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 2.12,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain17", "IlluminationStain17", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.24,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain18", "IlluminationStain18", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.29,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain19", "IlluminationStain19", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.78,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain20", "IlluminationStain20", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.73,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain21", "IlluminationStain21", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.91,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain22", "IlluminationStain22", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.62,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain23", "IlluminationStain23", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.22,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain24", "IlluminationStain24", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.16,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain25", "IlluminationStain25", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.67,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain26", "IlluminationStain26", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.24,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain27", "IlluminationStain27", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.78,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain28", "IlluminationStain28", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 2.75,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain29", "IlluminationStain29", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.22,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain30", "IlluminationStain30", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.76,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain31", "IlluminationStain31", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 2.14,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain32", "IlluminationStain32", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.09,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain33", "IlluminationStain33", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.11,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain34", "IlluminationStain34", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.48,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain35", "IlluminationStain35", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.42,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain36", "IlluminationStain36", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.39,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain37", "IlluminationStain37", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 2.73,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain38", "IlluminationStain38", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 2.64,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain39", "IlluminationStain39", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.71,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain40", "IlluminationStain40", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.77,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain41", "IlluminationStain41", .doodle, ["stain", "generic", "pale"], opacity: 0.62, traits: LeafAssetTraits(
                semanticRole: .texture,
                aspectRatio: 1.90,
                preferredAnchors: [.watermark],
                blend: .multiply,
                visualWeight: 1.30,
                allowsTextOverlap: true
            )),
            asset("illuminationstain42", "IlluminationStain42", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.27,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationstain43", "IlluminationStain43", .doodle, ["stain", "generic", "ink"], opacity: 0.78, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 2.19,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish01", "IlluminationFlourish01", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.69,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish02", "IlluminationFlourish02", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.37,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish03", "IlluminationFlourish03", .doodle, ["flourish", "ornament", "corner"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.94,
                preferredAnchors: [.upperLeading, .upperTrailing, .lowerTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish04", "IlluminationFlourish04", .doodle, ["flourish", "botanical", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .botanical,
                aspectRatio: 1.41,
                preferredAnchors: [.middleLeading, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish05", "IlluminationFlourish05", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.34,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish06", "IlluminationFlourish06", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.33,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish07", "IlluminationFlourish07", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.17,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish08", "IlluminationFlourish08", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.61,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish09", "IlluminationFlourish09", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.09,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish10", "IlluminationFlourish10", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.94,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish11", "IlluminationFlourish11", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.46,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish12", "IlluminationFlourish12", .doodle, ["flourish", "botanical", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .botanical,
                aspectRatio: 1.14,
                preferredAnchors: [.middleLeading, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish13", "IlluminationFlourish13", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 2.74,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish14", "IlluminationFlourish14", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 2.29,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish15", "IlluminationFlourish15", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.49,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish16", "IlluminationFlourish16", .doodle, ["flourish", "ornament", "corner"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.14,
                preferredAnchors: [.upperLeading, .upperTrailing, .lowerTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish17", "IlluminationFlourish17", .doodle, ["flourish", "sigil", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .sigil,
                aspectRatio: 0.88,
                preferredAnchors: [.lowerTrailing, .upperTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish18", "IlluminationFlourish18", .doodle, ["flourish", "sigil", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .sigil,
                aspectRatio: 0.96,
                preferredAnchors: [.lowerTrailing, .upperTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish19", "IlluminationFlourish19", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 2.10,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish20", "IlluminationFlourish20", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 3.27,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish21", "IlluminationFlourish21", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 3.68,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish22", "IlluminationFlourish22", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.00,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish23", "IlluminationFlourish23", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.07,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish24", "IlluminationFlourish24", .doodle, ["flourish", "botanical", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .botanical,
                aspectRatio: 1.33,
                preferredAnchors: [.middleLeading, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish25", "IlluminationFlourish25", .doodle, ["flourish", "sigil", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .sigil,
                aspectRatio: 1.01,
                preferredAnchors: [.lowerTrailing, .upperTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish26", "IlluminationFlourish26", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.37,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish27", "IlluminationFlourish27", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.52,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish28", "IlluminationFlourish28", .doodle, ["flourish", "sigil", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .sigil,
                aspectRatio: 1.69,
                preferredAnchors: [.lowerTrailing, .upperTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish29", "IlluminationFlourish29", .doodle, ["flourish", "botanical", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .botanical,
                aspectRatio: 1.75,
                preferredAnchors: [.middleLeading, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish30", "IlluminationFlourish30", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.45,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish31", "IlluminationFlourish31", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.58,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish32", "IlluminationFlourish32", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.33,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish33", "IlluminationFlourish33", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.62,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish34", "IlluminationFlourish34", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.43,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish35", "IlluminationFlourish35", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 3.31,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish36", "IlluminationFlourish36", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.22,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish37", "IlluminationFlourish37", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.40,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish38", "IlluminationFlourish38", .doodle, ["flourish", "botanical", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .botanical,
                aspectRatio: 1.33,
                preferredAnchors: [.middleLeading, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish39", "IlluminationFlourish39", .doodle, ["flourish", "botanical", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .botanical,
                aspectRatio: 1.12,
                preferredAnchors: [.middleLeading, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish40", "IlluminationFlourish40", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.45,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish41", "IlluminationFlourish41", .doodle, ["flourish", "sigil", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .sigil,
                aspectRatio: 1.93,
                preferredAnchors: [.lowerTrailing, .upperTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish42", "IlluminationFlourish42", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 3.10,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish43", "IlluminationFlourish43", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 0.50,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish44", "IlluminationFlourish44", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.50,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish45", "IlluminationFlourish45", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.09,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish46", "IlluminationFlourish46", .doodle, ["flourish", "watercolor", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .watercolor,
                aspectRatio: 1.35,
                preferredAnchors: [.lowerField, .middleLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 1.00,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish47", "IlluminationFlourish47", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.18,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish48", "IlluminationFlourish48", .doodle, ["flourish", "ornament", "corner"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.38,
                preferredAnchors: [.upperLeading, .upperTrailing, .lowerTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            )),
            asset("illuminationflourish49", "IlluminationFlourish49", .doodle, ["flourish", "ornament", "generic"], opacity: 0.82, traits: LeafAssetTraits(
                semanticRole: .ornament,
                aspectRatio: 1.77,
                preferredAnchors: [.upperTrailing, .lowerLeading, .middleTrailing],
                blend: .multiply,
                visualWeight: 0.86,
                allowsTextOverlap: false
            ))
        ],
        tape: [
            asset("illumination_botanical_tape", "IlluminationScrapS02_03", .tape, ["tape", "botanical", "green"]),
            asset("illumination_fabric_tape", "IlluminationScrapS02_28", .tape, ["tape", "fabric", "generic"]),
            asset("tape_01", "ParchmentFiber", .tape, ["tape", "generic"]),
            asset("tape_02", "ParchmentTexture", .tape, ["tape", "generic"])
        ],
        overlays: [
            asset("overlay_paper_grain_01", "ParchmentFiber", .overlay, ["grain", "generic"], opacity: 0.18),
            asset("overlay_speckles_01", "ParchmentTexture", .overlay, ["speckles", "generic"], opacity: 0.12),
            asset("overlay_edge_vignette_01", "ParchmentTexture", .overlay, ["edge", "vignette", "generic"], opacity: 0.16)
        ],
        fallbackPhrases: [
            .academyFieldStudy: TemplateFallbackPhrases(
                fieldNotes: [PhotoAnalysis.academyFallback.marginalia.fieldNote],
                stampLabels: [PhotoAnalysis.academyFallback.marginalia.stampLabel],
                observations: PhotoAnalysis.academyFallback.marginalia.observationList,
                closingLines: [PhotoAnalysis.academyFallback.marginalia.closingLine]
            )
        ]
    )

    private static func asset(
        _ id: String,
        _ assetName: String,
        _ kind: IlluminationAssetKind,
        _ tags: [String],
        opacity: Double = 0.82,
        traits: LeafAssetTraits? = nil
    ) -> IlluminationAsset {
        IlluminationAsset(
            id: id,
            assetName: assetName,
            kind: kind,
            tags: tags,
            supportedTemplates: IlluminatedTemplateID.allCases,
            defaultOpacity: opacity,
            canTint: false,
            leafTraits: traits ?? .derived(kind: kind, tags: tags)
        )
    }


    /// A hand-painted herbarium sheet, cut into single studies.
    ///
    /// These are pictures of things that grew, so they say so: every one is
    /// `.botanical` and carries its own plant name as a subject tag, which is
    /// what files the whole family onto Pressed & Grown without a `shelf`.
    /// The proportions are the real cut sizes — a foxglove is tall, and the
    /// folio must be allowed to keep it tall rather than square it off.
    private static let botanicalAssets: [IlluminationAsset] = [
        themedAsset("botanical_violet", "BotanicalViolet", .doodle, ["botanical", "pressed", "plant", "herbarium", "violet", "purple", "spring", "woodland", "shy", "small"], 246, 285, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 1.00),
        themedAsset("botanical_lily_of_the_valley", "BotanicalLilyOfTheValley", .doodle, ["botanical", "pressed", "plant", "herbarium", "lily-of-the-valley", "bell", "white", "spring", "woodland", "fragrance"], 197, 286, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 1.02),
        themedAsset("botanical_blue_star", "BotanicalBlueStar", .doodle, ["botanical", "pressed", "plant", "herbarium", "blue", "star", "flax", "meadow", "spring"], 189, 264, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 0.98),
        themedAsset("botanical_heather", "BotanicalHeather", .doodle, ["botanical", "pressed", "plant", "herbarium", "heather", "moor", "purple", "sprig", "highland", "late-summer"], 199, 295, .botanical, [.middleTrailing, .lowerTrailing, .middleLeading], 0.94),
        themedAsset("botanical_wood_anemone", "BotanicalWoodAnemone", .doodle, ["botanical", "pressed", "plant", "herbarium", "anemone", "white", "woodland", "spring", "windflower"], 254, 279, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 1.00),
        themedAsset("botanical_fly_agaric", "BotanicalFlyAgaric", .doodle, ["botanical", "pressed", "plant", "herbarium", "mushroom", "fungus", "toadstool", "fly-agaric", "autumn", "woodland", "fairy-ring", "red"], 200, 282, .botanical, [.lowerField, .lowerLeading, .lowerTrailing], 1.10),
        themedAsset("botanical_foxglove", "BotanicalFoxglove", .doodle, ["botanical", "pressed", "plant", "herbarium", "foxglove", "pink", "bell", "poison", "hedgerow", "summer", "folklore"], 205, 302, .botanical, [.middleLeading, .middleTrailing, .lowerLeading], 1.06),
        themedAsset("botanical_daisies", "BotanicalDaisies", .doodle, ["botanical", "pressed", "plant", "herbarium", "daisy", "white", "meadow", "summer", "ordinary", "cheerful"], 224, 259, .botanical, [.lowerField, .middleLeading, .lowerLeading], 1.00),
        themedAsset("botanical_rosemary", "BotanicalRosemary", .doodle, ["botanical", "pressed", "plant", "herbarium", "rosemary", "herb", "remembrance", "kitchen", "evergreen", "blue"], 203, 268, .botanical, [.middleTrailing, .lowerTrailing, .middleLeading], 0.96),
        themedAsset("botanical_oak_acorns", "BotanicalOakAcorns", .doodle, ["botanical", "pressed", "plant", "herbarium", "oak", "acorn", "leaf", "autumn", "woodland", "strength"], 223, 241, .botanical, [.lowerField, .lowerLeading, .lowerTrailing], 1.04),
        themedAsset("botanical_blackberry", "BotanicalBlackberry", .doodle, ["botanical", "pressed", "plant", "herbarium", "blackberry", "bramble", "berry", "hedgerow", "late-summer", "harvest", "fruit"], 222, 250, .botanical, [.lowerField, .middleTrailing, .lowerTrailing], 1.06),
        themedAsset("botanical_bindweed", "BotanicalBindweed", .doodle, ["botanical", "pressed", "plant", "herbarium", "bindweed", "trumpet", "white", "vine", "tendril", "hedgerow", "summer"], 215, 281, .botanical, [.middleTrailing, .upperTrailing, .middleLeading], 1.00),
        themedAsset("botanical_snowdrop", "BotanicalSnowdrop", .doodle, ["botanical", "pressed", "plant", "herbarium", "snowdrop", "white", "winter", "first", "thaw", "imbolc", "hope"], 222, 263, .botanical, [.lowerField, .lowerLeading, .middleLeading], 0.94),
        themedAsset("botanical_dandelion", "BotanicalDandelion", .doodle, ["botanical", "pressed", "plant", "herbarium", "dandelion", "clock", "wish", "seed", "yellow", "ordinary", "weed", "wind"], 258, 257, .botanical, [.lowerField, .middleLeading, .lowerLeading], 1.08),
        themedAsset("botanical_chinese_lantern", "BotanicalChineseLantern", .doodle, ["botanical", "pressed", "plant", "herbarium", "physalis", "lantern", "orange", "autumn", "husk", "papery"], 202, 267, .botanical, [.upperTrailing, .middleTrailing, .lowerTrailing], 1.04),
        themedAsset("botanical_lavender", "BotanicalLavender", .doodle, ["botanical", "pressed", "plant", "herbarium", "lavender", "purple", "rest", "calm", "fragrance", "summer", "herb"], 207, 283, .botanical, [.lowerField, .middleLeading, .lowerLeading], 1.00),
        themedAsset("botanical_poppy", "BotanicalPoppy", .doodle, ["botanical", "pressed", "plant", "herbarium", "poppy", "red", "remembrance", "field", "summer", "sleep", "seed-head"], 212, 256, .botanical, [.lowerField, .middleTrailing, .lowerLeading], 1.06),
        themedAsset("botanical_ivy", "BotanicalIvy", .doodle, ["botanical", "pressed", "plant", "herbarium", "ivy", "vine", "leaf", "evergreen", "tendril", "winter", "climbing"], 206, 261, .botanical, [.upperTrailing, .middleTrailing, .upperLeading], 1.00),
        themedAsset("botanical_white_bells", "BotanicalWhiteBells", .doodle, ["botanical", "pressed", "plant", "herbarium", "bell", "white", "spring", "woodland", "nodding", "quiet"], 232, 279, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 0.98),
        themedAsset("botanical_borage", "BotanicalBorage", .doodle, ["botanical", "pressed", "plant", "herbarium", "borage", "blue", "star", "bud", "herb", "courage", "summer"], 185, 274, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 0.98),
        themedAsset("botanical_hellebore", "BotanicalHellebore", .doodle, ["botanical", "pressed", "plant", "herbarium", "hellebore", "christmas-rose", "white", "winter", "woodland", "quiet"], 229, 295, .botanical, [.middleLeading, .lowerLeading, .middleTrailing], 1.02),
        themedAsset("botanical_fern_fiddlehead", "BotanicalFernFiddlehead", .doodle, ["botanical", "pressed", "plant", "herbarium", "fern", "fiddlehead", "spiral", "green", "unfurling", "spring", "moss"], 190, 267, .botanical, [.lowerField, .lowerLeading, .middleLeading], 1.00),
        themedAsset("botanical_sycamore_keys", "BotanicalSycamoreKeys", .doodle, ["botanical", "pressed", "plant", "herbarium", "sycamore", "maple", "samara", "seed", "wing", "autumn", "spin", "wind"], 233, 243, .botanical, [.upperTrailing, .middleTrailing, .lowerTrailing], 0.92),
        themedAsset("botanical_holly", "BotanicalHolly", .doodle, ["botanical", "pressed", "plant", "herbarium", "holly", "berry", "red", "winter", "evergreen", "yule", "prickle"], 213, 285, .botanical, [.lowerField, .middleTrailing, .lowerTrailing], 1.04)
    ]

    private static let academyNoteAssets: [IlluminationAsset] = [
        academyNoteAsset("academy_note_turn_page_backward", "AcademyNoteTurnPageBackward", 197, 168, ["page", "backwards", "answer", "secret"]),
        academyNoteAsset("academy_note_book_notices_first", "AcademyNoteBookNoticesFirst", 189, 153, ["book", "notice", "attention"]),
        academyNoteAsset("academy_note_goblin_market_new_moon", "AcademyNoteGoblinMarketNewMoon", 257, 144, ["goblin", "market", "new-moon", "moon", "event"]),
        academyNoteAsset("academy_note_shake_the_book", "AcademyNoteShakeTheBook", 199, 156, ["book", "shake", "surprise", "interaction"]),
        academyNoteAsset("academy_note_double_tap_illustration", "AcademyNoteDoubleTapIllustration", 215, 153, ["illustration", "double-tap", "movement", "interaction"]),
        academyNoteAsset("academy_note_glow_is_belief", "AcademyNoteGlowIsBelief", 162, 172, ["glow", "belief", "wonder"]),
        academyNoteAsset("academy_note_lost_page", "AcademyNoteLostPage", 210, 165, ["lost-page", "search", "memory", "looking"]),
        academyNoteAsset("academy_note_write_to_character", "AcademyNoteWriteToCharacter", 252, 147, ["character", "letter", "correspondence", "writing"]),
        academyNoteAsset("academy_note_margins_alive", "AcademyNoteMarginsAlive", 235, 156, ["margins", "alive", "magic", "look-closer"]),
        academyNoteAsset("academy_note_momort_laughter", "AcademyNoteMomortLaughter", 242, 151, ["momort", "laughter", "recording", "audio"]),
        academyNoteAsset("academy_note_frogs_know_weather", "AcademyNoteFrogsKnowWeather", 227, 166, ["frog", "weather", "pond", "outside"]),
        academyNoteAsset("academy_note_hold_your_words", "AcademyNoteHoldYourWords", 212, 143, ["reader-words", "memory", "hold", "writing"]),
        academyNoteAsset("academy_note_leaf_grows_things", "AcademyNoteLeafGrowsThings", 247, 160, ["leaf", "growth", "keep", "collection"]),
        academyNoteAsset("academy_note_say_no", "AcademyNoteSayNo", 180, 147, ["say-no", "boundary", "agency", "warning"]),
        academyNoteAsset("academy_note_pages_change_at_night", "AcademyNotePagesChangeAtNight", 217, 150, ["page", "night", "change", "return"]),
        academyNoteAsset("academy_note_secret_in_photo", "AcademyNoteSecretInPhoto", 208, 173, ["photo", "secret", "book", "finding"]),
        academyNoteAsset("academy_note_bind_day_differently", "AcademyNoteBindDayDifferently", 207, 172, ["bindery", "day", "choice", "truth"]),
        academyNoteAsset("academy_note_book_misbehaves", "AcademyNoteBookMisbehaves", 163, 231, ["book", "mischief", "apology", "warning"]),
        academyNoteAsset("academy_note_book_can_be_wrong", "AcademyNoteBookCanBeWrong", 147, 143, ["book", "wrong", "humility", "warning"]),
        academyNoteAsset("academy_note_map_changes_walking", "AcademyNoteMapChangesWalking", 203, 166, ["map", "walk", "real-world", "place"]),
        academyNoteAsset("academy_note_ask_bad_question", "AcademyNoteAskBadQuestion", 307, 175, ["book", "question", "truth", "curiosity"]),
        academyNoteAsset("academy_note_press_important_things", "AcademyNotePressImportantThings", 224, 154, ["press", "important", "interaction", "attention"]),
        academyNoteAsset("academy_note_full_moon_dream_pages", "AcademyNoteFullMoonDreamPages", 248, 143, ["full-moon", "moon", "dream", "morning", "page"]),
        academyNoteAsset("academy_note_goblin_warning", "AcademyNoteGoblinWarning", 181, 172, ["goblin", "risk", "warning", "feeding"]),
        academyNoteAsset("academy_note_lessons_in_strange_places", "AcademyNoteLessonsInStrangePlaces", 193, 160, ["academy", "lesson", "place", "look-closer"]),
        academyNoteAsset("academy_note_say_the_unsaid_thing", "AcademyNoteSayTheUnsaidThing", 220, 166, ["courage", "unsaid", "secret", "keep"]),
        academyNoteAsset("academy_note_for_future_self", "AcademyNoteForFutureSelf", 194, 172, ["future-self", "page", "memory", "care"]),
        academyNoteAsset("academy_note_rut_color_draining", "AcademyNoteRutColorDraining", 194, 199, ["rut", "routine", "color-draining", "warning", "fight"]),
        academyNoteAsset("academy_note_change_your_mind", "AcademyNoteChangeYourMind", 179, 177, ["change", "mind", "story", "agency"]),
        academyNoteAsset("academy_note_hard_places", "AcademyNoteHardPlaces", 197, 173, ["hard-place", "look-again", "attention", "wonder"]),
        academyNoteAsset("academy_note_leave_note_for_yourself", "AcademyNoteLeaveNoteForYourself", 189, 152, ["self-note", "future-self", "memory", "care"]),
        academyNoteAsset("academy_note_library_door", "AcademyNoteLibraryDoor", 232, 145, ["library", "door", "place", "secret"]),
        academyNoteAsset("academy_note_follow_the_fox", "AcademyNoteFollowTheFox", 196, 112, ["fox", "guidance", "trail", "wonder"]),
        academyNoteAsset("academy_note_not_all_stay_in_ink", "AcademyNoteNotAllStayInInk", 163, 135, ["ink", "visitor", "arrival", "magic"]),
        academyNoteAsset("academy_note_fluttering_page", "AcademyNoteFlutteringPage", 180, 128, ["page", "flutter", "read-twice", "secret"]),
        academyNoteAsset("academy_note_keep_camera_handy", "AcademyNoteKeepCameraHandy", 227, 139, ["camera", "photo", "real-world", "story"]),
        academyNoteAsset("academy_note_trust_wonder", "AcademyNoteTrustWonder", 177, 144, ["wonder", "fear", "guidance", "trust"]),
    ]

    /// Student-scrawled curriculum tips. Their semantic tags do the routing:
    /// one shared cabinet supplies illuminated photos, composed leaves,
    /// Pagewright, and editions without any surface-specific registration.
    private static let academyTipAssets: [IlluminationAsset] = [
        academyNoteAsset("academy_tip_bells", "AcademyTipBells", 432, 224, ["academy-tip", "schedule", "bells", "class", "club", "morning", "afternoon", "evening"]),
        academyNoteAsset("academy_tip_saturday_compass", "AcademyTipSaturdayCompass", 502, 242, ["academy-tip", "schedule", "saturday", "compass-running", "compass", "outside", "field", "embark"]),
        academyNoteAsset("academy_tip_glint", "AcademyTipGlint", 407, 228, ["academy-tip", "art-of-the-glint", "glint", "lydia-boggle", "boggle", "notice", "north", "attention", "odd", "class"]),
        academyNoteAsset("academy_tip_momort", "AcademyTipMomort", 446, 212, ["academy-tip", "wayfinding-kineticism", "momort", "kyle-momort", "door", "exit", "threshold", "embark", "east", "class"]),
        academyNoteAsset("academy_tip_euphony", "AcademyTipEuphony", 453, 211, ["academy-tip", "synesthetic-resonance", "euphony", "eleanor-euphony", "sense", "south", "listen", "sound", "room", "class"]),
        academyNoteAsset("academy_tip_ink_binding", "AcademyTipInkBinding", 435, 236, ["academy-tip", "ink-binding", "vivian-villanelle", "villanelle", "write", "west", "sentence", "souvenir", "memory", "class"]),
        academyNoteAsset("academy_tip_quiet_hours", "AcademyTipQuietHours", 440, 206, ["academy-tip", "quiet-hours", "cedric-stonebrook", "stonebrook", "rest", "center", "permission-to-stop", "class"]),
        academyNoteAsset("academy_tip_object_answers", "AcademyTipObjectAnswers", 453, 213, ["academy-tip", "basic-enchantments", "luna-wispwood", "wispwood", "ordinary", "object", "answer", "enchantment", "attention", "class"]),
        academyNoteAsset("academy_tip_bookmark", "AcademyTipBookmark", 412, 244, ["academy-tip", "book-jumping", "permancer", "bookmark", "safety", "story", "door", "exit", "class"]),
        academyNoteAsset("academy_tip_compass_sequence", "AcademyTipCompassSequence", 451, 239, ["academy-tip", "compass", "compass-running", "notice", "embark", "sense", "write", "north", "east", "south", "west", "field"]),
        academyNoteAsset("academy_tip_souvenir_sentence", "AcademyTipSouvenirSentence", 452, 219, ["academy-tip", "compass-society", "club", "souvenir", "sentence", "share", "secret-garden-of-prose", "zara-finch"]),
        academyNoteAsset("academy_tip_permancer_exit", "AcademyTipPermancerExit", 416, 223, ["academy-tip", "book-jumping", "book-jumpers", "club", "permancer", "exit", "safety", "door", "vault-of-doors"]),
    ]

    private static let academyWarningAssets: [IlluminationAsset] = [
        academyWarningAsset("academy_warning_beware_the_goblins", "AcademyWarningBewareTheGoblins", 320, 301, ["goblin", "danger", "beware"]),
        academyWarningAsset("academy_warning_dont_trust_momort", "AcademyWarningDontTrustMomort", 313, 223, ["momort", "trust", "danger"]),
        academyWarningAsset("academy_warning_book_remembers", "AcademyWarningBookRemembers", 352, 253, ["book", "memory", "remember"]),
        academyWarningAsset("academy_warning_follow_blue_thread", "AcademyWarningFollowBlueThread", 324, 215, ["blue-thread", "thread", "follow", "guidance"]),
        academyWarningAsset("academy_warning_turn_page_at_dusk", "AcademyWarningTurnPageAtDusk", 315, 186, ["page", "dusk", "night", "turn"]),
        academyWarningAsset("academy_warning_keep_belief_close", "AcademyWarningKeepBeliefClose", 342, 233, ["belief", "keep", "care"]),
        academyWarningAsset("academy_warning_leave_truth_behind", "AcademyWarningLeaveTruthBehind", 336, 198, ["truth", "leave-behind", "secret"]),
        academyWarningAsset("academy_warning_doors_open_when_noticed", "AcademyWarningDoorsOpenWhenNoticed", 304, 234, ["door", "threshold", "notice", "attention"]),
        academyWarningAsset("academy_warning_margins_listening", "AcademyWarningMarginsListening", 324, 205, ["margins", "listening", "secret"]),
        academyWarningAsset("academy_warning_safer_by_moonlight", "AcademyWarningSaferByMoonlight", 323, 244, ["path", "moonlight", "moon", "safety", "night"]),
        academyWarningAsset("academy_warning_wicker_was_here", "AcademyWarningWickerWasHere", 301, 228, ["wicker-eddies", "wicker", "character", "trace"]),
        academyWarningAsset("academy_warning_you_were_expected", "AcademyWarningYouWereExpected", 277, 200, ["expected", "arrival", "threshold"]),
        academyWarningAsset("academy_warning_not_every_guide_is_kind", "AcademyWarningNotEveryGuideIsKind", 329, 233, ["guide", "kindness", "danger", "trust"]),
        academyWarningAsset("academy_warning_look_twice_at_ordinary", "AcademyWarningLookTwiceAtOrdinary", 332, 233, ["ordinary", "look-again", "attention", "wonder"]),
        academyWarningAsset("academy_warning_come_back_to_this", "AcademyWarningComeBackToThis", 285, 250, ["return", "come-back", "memory"]),
        academyWarningAsset("academy_warning_questions_are_keys", "AcademyWarningQuestionsAreKeys", 319, 248, ["question", "key", "door", "curiosity"]),
    ]

    private static func academyWarningAsset(
        _ id: String,
        _ assetName: String,
        _ pixelWidth: Double,
        _ pixelHeight: Double,
        _ semanticTags: [String]
    ) -> IlluminationAsset {
        themedAsset(
            id,
            assetName,
            .doodle,
            ["academy", "handwritten", "warning", "marginalia", "ink"] + semanticTags,
            pixelWidth,
            pixelHeight,
            .scribble,
            [.middleLeading, .middleTrailing, .lowerField],
            0.86
        )
    }

    private static func academyNoteAsset(
        _ id: String,
        _ assetName: String,
        _ pixelWidth: Double,
        _ pixelHeight: Double,
        _ semanticTags: [String]
    ) -> IlluminationAsset {
        themedAsset(
            id,
            assetName,
            .doodle,
            ["academy", "handwritten", "note", "marginalia", "ink"] + semanticTags,
            pixelWidth,
            pixelHeight,
            .scribble,
            [.middleLeading, .middleTrailing, .lowerField],
            0.76
        )
    }

    /// Base-content art with explicit subject and physical-placement meaning.
    /// The pixel dimensions preserve each cut's authored proportions, while
    /// tags let every compositor find the same mark semantically.
    private static func themedAsset(
        _ id: String,
        _ assetName: String,
        _ kind: IlluminationAssetKind,
        _ tags: [String],
        _ pixelWidth: Double,
        _ pixelHeight: Double,
        _ role: LeafAssetSemanticRole,
        _ anchors: [LeafAssetAnchor],
        _ visualWeight: Double
    ) -> IlluminationAsset {
        asset(
            id,
            assetName,
            kind,
            tags,
            opacity: 1.0,
            traits: LeafAssetTraits(
                semanticRole: role,
                aspectRatio: pixelWidth / pixelHeight,
                preferredAnchors: anchors,
                blend: .normal,
                visualWeight: visualWeight,
                allowsTextOverlap: false,
                subjectTags: tags
            )
        )
    }
}

struct IlluminationAssetResolver {
    func resolveAsset(
        kind: IlluminationAssetKind,
        tags: [String],
        template: IlluminatedTemplateID?,
        installedPacks: [IlluminationAssetPack],
        placementContext: IlluminationPlacementContext? = nil,
        seed: Int? = nil,
        salt: Int = 0,
        excludingAssetNames: Set<String> = []
    ) -> IlluminationAsset? {
        let normalizedTags = Set(tags.map { $0.lowercased() })
        let effectiveContext = placementContext ?? IlluminationPlacementContext(
            semanticTags: tags,
            month: nil,
            activeWorldEventIDs: [],
            worldEventPhases: []
        )
        let candidates = installedPacks
            .flatMap(\.allAssets)
            .filter { asset in
                guard asset.kind == kind else { return false }
                guard template.map({ asset.supportedTemplates.contains($0) }) ?? true else { return false }
                return asset.placementTrigger?.allows(effectiveContext) ?? true
            }

        let scored = candidates.compactMap { asset -> (asset: IlluminationAsset, score: Int)? in
            let searchableTags = asset.tags + (asset.leafTraits?.subjectTags ?? [])
            let score = normalizedTags.intersection(
                Set(searchableTags.map { $0.lowercased() })
            ).count
            return score > 0 ? (asset, score) : nil
        }
        let strongestScore = scored.map { $0.score }.max() ?? 0
        // Keep a little visual variety around the best match, but do not let a
        // one-word coincidence compete evenly with a mark whose whole subject
        // agrees with the Page. "Blue thread" should reach the blue-thread
        // warning, not merely any drawing that also happens to say "book".
        let semanticFloor = max(1, strongestScore - 1)
        let tagged = scored
            .filter { $0.score >= semanticFloor }
            .map { $0.asset }
        let generic = candidates.filter { asset in
            asset.tags.contains("generic")
        }
        // A motif-matched mark is usually the better answer, but "generic" meant
        // *last resort* here: whenever any tag matched, the generic pool was
        // never consulted at all. Marks that suit any page — a coffee ring, a
        // pen flourish — were therefore unreachable on every page that matched
        // anything, which is nearly all of them. Let both pools stay live, with
        // the motif keeping the better odds.
        let preferred: [IlluminationAsset]
        if tagged.isEmpty {
            preferred = generic.isEmpty ? candidates : generic
        } else if generic.isEmpty {
            preferred = tagged
        } else {
            let favoursMotif = seed.map {
                abs(($0 &+ salt &* 104_729).stableScramble) % 100 < 62
            } ?? true
            preferred = favoursMotif ? tagged : generic
        }
        let unused = preferred.filter { !excludingAssetNames.contains($0.assetName) }
        let pool = unused.isEmpty ? preferred : unused

        guard !pool.isEmpty else { return nil }
        guard let seed else { return pool.first }
        let index = abs((seed &+ salt * 7919).stableScramble) % pool.count
        return pool[index]
    }
}

enum IlluminationPackRegistry {
    /// One shared shelf of physical marks. Page content packs may contribute a
    /// cabinet to it, which makes those marks available to the folio,
    /// Pagewright, and illuminated photos without bespoke registration code.
    static var installedPacks: [IlluminationAssetPack] {
        var seen = Set<String>()
        let contentPackMargins = PageArchetypePackRegistry.enabledPacks().compactMap { contentPack -> IlluminationAssetPack? in
            guard var margins = contentPack.marginaliaPack else { return nil }
            // Reaching this collection already means the parent content pack
            // passed its entitlement gate. Do not make its paper pay twice.
            margins.availability = contentPack.availability == "userImported" ? .userImported : .bundledFree
            return margins
        }
        return ([CoreMarginsPack.pack] + contentPackMargins).filter { seen.insert($0.id).inserted }
    }

    static var unlockedPacks: [IlluminationAssetPack] {
        installedPacks.filter(isUnlocked)
    }

    static func pack(for id: String) -> IlluminationAssetPack? {
        unlockedPacks.first { $0.id == id }
    }

    static func packsSupporting(_ template: IlluminatedTemplateID) -> [IlluminationAssetPack] {
        unlockedPacks.filter { $0.supportedTemplates.contains(template) }
    }

    static func preferredPack(for template: IlluminatedTemplateID, motifs: [String]) -> IlluminationAssetPack {
        let wanted = Set(motifs.map { $0.lowercased() })
        return packsSupporting(template)
            .enumerated()
            .max { lhs, rhs in
                let left = motifScore(for: lhs.element, template: template, wanted: wanted)
                let right = motifScore(for: rhs.element, template: template, wanted: wanted)
                return left == right ? lhs.offset > rhs.offset : left < right
            }?
            .element ?? CoreMarginsPack.pack
    }

    private static func motifScore(
        for pack: IlluminationAssetPack,
        template: IlluminatedTemplateID,
        wanted: Set<String>
    ) -> Int {
        guard !wanted.isEmpty else { return pack.id == CoreMarginsPack.id ? 1 : 0 }
        let intersections = pack.allAssets
            .filter { $0.supportedTemplates.contains(template) }
            .map { asset in
                let searchableTags = asset.tags + (asset.leafTraits?.subjectTags ?? [])
                return wanted.intersection(Set(searchableTags.map { $0.lowercased() })).count
            }
        return (intersections.max() ?? 0) * 100 + intersections.filter { $0 > 0 }.count
    }

    // MARK: - Browsing the cabinet by shelf

    /// One mark, with the pack it came from and where it is filed today.
    ///
    /// Pagewright needs provenance on the tile — two packs may both ship a moth
    /// — but it must not need to *switch packs* to see one. The whole cabinet
    /// is one cabinet.
    struct ShelvedMark: Identifiable, Equatable {
        var asset: IlluminationAsset
        var packID: String
        var packName: String
        var shelf: MarkShelf

        var id: String { "\(packID)§\(asset.id)" }
    }

    /// Every unlocked mark, filed. Stable order, no cap.
    ///
    /// The cap is the point. `Pagewright` used to ask for a kind and take the
    /// first eighty, which meant a hundred and thirty-nine marks shipped,
    /// carried achievements, and could never be placed by hand. Shelves are
    /// small enough that nothing needs hiding.
    static func shelvedMarks(context: IlluminationPlacementContext = .empty) -> [ShelvedMark] {
        var marks: [ShelvedMark] = []
        for pack in unlockedPacks {
            for asset in pack.allAssets {
                let shelf = currentShelf(for: asset, context: context)
                marks.append(
                    ShelvedMark(
                        asset: asset,
                        packID: pack.id,
                        packName: pack.displayName,
                        shelf: shelf
                    )
                )
            }
        }
        marks.sort { lhs, rhs in
            if lhs.asset.id != rhs.asset.id { return lhs.asset.id < rhs.asset.id }
            return lhs.packID < rhs.packID
        }
        return marks
    }

    /// The marks on one shelf, in stable order.
    static func marks(
        on shelf: MarkShelf,
        context: IlluminationPlacementContext = .empty
    ) -> [ShelvedMark] {
        shelvedMarks(context: context).filter { $0.shelf == shelf }
    }

    /// Shelves that currently hold at least one mark, in display order. An
    /// empty shelf should not be offered — a reader who opens `Shore` and finds
    /// nothing learns only that the Book wastes their time.
    static func populatedShelves(context: IlluminationPlacementContext = .empty) -> [MarkShelf] {
        let occupied = Set(shelvedMarks(context: context).map(\.shelf))
        return MarkShelf.displayOrder.filter { occupied.contains($0) || $0 == .theDrawer }
    }

    /// A shuffled handful from anywhere in the cabinet, redrawn each day.
    ///
    /// Rummaging is only fun when the pile is small and it changes. Two hundred
    /// and fifty marks in a scroll is not a rummage, it is a spreadsheet — so
    /// the drawer is deliberately tiny and deliberately arbitrary, and tomorrow
    /// it holds different things. Seeded by the day so it does not reshuffle
    /// under the reader's hand mid-page.
    /// `isUsable` lets the caller prefer marks the reader has already earned.
    /// A drawer that deals twelve padlocks is not a rummage, it is a shop
    /// window — so open marks are dealt first and locked ones only top up the
    /// handful. The shuffle is still the day's, not a ranking.
    static func drawerMarks(
        on day: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 12,
        context: IlluminationPlacementContext = .empty,
        isUsable: ((IlluminationAsset) -> Bool)? = nil
    ) -> [ShelvedMark] {
        // Past months stay out of the drawer: a mark from a closed event
        // turning up at random reads as the Book losing track of the calendar.
        let pool = shelvedMarks(context: context).filter { $0.shelf != .pastMonths }
        guard !pool.isEmpty else { return [] }

        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let seed = (components.year ?? 0) &* 10_000
            &+ (components.month ?? 0) &* 100
            &+ (components.day ?? 0)

        var ranked: [(mark: ShelvedMark, rank: Int)] = []
        for mark in pool {
            let key: String = "\(seed)|\(mark.id)"
            let rank: Int = abs(key.stableHash.stableScramble)
            ranked.append((mark, rank))
        }
        ranked.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.mark.id < rhs.mark.id
        }
        let shuffled = ranked.map(\.mark)
        guard let isUsable else { return Array(shuffled.prefix(max(1, limit))) }

        let open = shuffled.filter { isUsable($0.asset) }
        let shut = shuffled.filter { !isUsable($0.asset) }
        return Array((open + shut).prefix(max(1, limit)))
    }

    /// Where a mark sits *today*, which is not always where it lives.
    ///
    /// An occasional mark — one gated to a month, an event, or an event phase —
    /// is pulled forward onto `This Month` while its gate is open, and settles
    /// onto `Past Months` once it closes. It never disappears. A scrapbook that
    /// deletes the reader's materials the moment a season turns is a scrapbook
    /// nobody trusts with anything.
    private static func currentShelf(
        for asset: IlluminationAsset,
        context: IlluminationPlacementContext
    ) -> MarkShelf {
        guard asset.isOccasional else { return asset.markShelf }
        guard let trigger = asset.placementTrigger else { return asset.markShelf }
        return trigger.allowsOccasion(context) ? .thisMonth : .pastMonths
    }

    private static func isUnlocked(_ pack: IlluminationAssetPack) -> Bool {
        switch pack.availability {
        case .bundledFree, .userImported:
            return true
        case .patron, .paid, .locked:
            return PackEntitlements.isUnlocked(pack.id)
        }
    }
}

enum LeafMarginaliaPlacement: String, Equatable {
    case upperOuterMargin
    case middleOuterMargin
    case lowerOuterCorner
    case faintWatermark
}

/// The physical stock beneath a Page's tint, ink, and marginalia. These assets
/// are deliberately neutral material maps: `PageVisualStyle` still owns the
/// paper colour, so most leaves remain warm parchment while special Page types
/// keep their slate, violet, green, or moonlit cast.
///
/// A stock is chosen from the Page identity rather than the individual leaf.
/// Every leaf in one Page therefore came from the same bundle of paper, while
/// the renderer may crop and turn that stock a little differently per leaf.
enum LeafPaperStock: String, CaseIterable, Hashable {
    case laidCotton
    case ragHandmade
    case vellum
    case archiveFlecked
    case rebelWeathered

    var assetName: String {
        switch self {
        case .laidCotton: return "PaperTextureLaidCotton"
        case .ragHandmade: return "PaperTextureRagHandmade"
        case .vellum: return "PaperTextureVellum"
        case .archiveFlecked: return "PaperTextureArchiveFlecked"
        case .rebelWeathered: return "PaperTextureRebelWeathered"
        }
    }

    var baseOpacity: Double {
        switch self {
        case .vellum: return 0.19
        case .archiveFlecked: return 0.23
        case .laidCotton: return 0.25
        case .ragHandmade: return 0.27
        case .rebelWeathered: return 0.29
        }
    }

    static func resolve(pageType: BookPageType, documentID: String) -> LeafPaperStock {
        // Repeated entries are intentional weights. A Page family has a usual
        // stock, not a uniform: the shelves should surprise without looking as
        // though each leaf was selected independently from a sample book.
        let candidates: [LeafPaperStock]
        switch pageType {
        case .academyClass, .facultyResearch, .inkrestOfficeHours,
             .calendar, .inventory, .bindery, .frontMatter, .taleBound,
             .marginsAtlas, .bookConnections, .bookRemembered, .bookNotices,
             .bookPocket, .helpTips:
            candidates = [.archiveFlecked, .archiveFlecked, .laidCotton, .ragHandmade]

        case .diary, .note, .letter, .plainPage, .aboutYou, .affirmations,
             .askTheBook, .supportGuild, .pactDispatch, .pactVerdict,
             .pactErrand, .twoReadings, .castBond:
            candidates = [.laidCotton, .laidCotton, .ragHandmade, .vellum]

        case .souvenir, .tarot, .illustration, .illuminatedPhoto, .todaysSky,
             .wonderCompass, .festival, .glowInvitation, .bookOfYou:
            candidates = [.vellum, .vellum, .laidCotton, .ragHandmade]

        case .bookFae, .faeBargain, .wickerDare, .wordNegotiation, .gamePage,
             .bookJump, .enchantment, .theBleed, .packPage:
            candidates = [.rebelWeathered, .rebelWeathered, .ragHandmade, .laidCotton]

        default:
            candidates = [.ragHandmade, .ragHandmade, .laidCotton, .archiveFlecked, .vellum]
        }

        let hash = "\(documentID)|paper-stock-v1".stableHash
        let index = Int(UInt(bitPattern: hash) % UInt(candidates.count))
        return candidates[index]
    }
}

struct LeafDecorationRecipe: Equatable {
    var seed: Int
    var motifs: [String]
    var paperStock: LeafPaperStock
    var primaryAsset: IlluminationAsset?
    var secondaryAsset: IlluminationAsset?
    var supportAsset: IlluminationAsset?
    var fasteningAsset: IlluminationAsset?
    var textureOverlay: IlluminationAsset?
    var handwrittenSnippet: IlluminationMarginaliaSnippet?
    var primaryPlacement: LeafMarginaliaPlacement
    var wearLevel: Double
    var hasFoxing: Bool
    var hasWaterRing: Bool
    var hasInkSpatter: Bool
    var hasSoftCrease: Bool
    var hasWornCorner: Bool
}

/// Gives every physical leaf a stable material history. It is intentionally
/// restrained: grain and edge wear are common; loud marks and handwriting are
/// not. The same Page gets the same marks after relaunching or repagination.
enum LeafDecorationLibrary {
    static func recipe(
        pageType: BookPageType,
        metadata: [String: String],
        semanticText: String = "",
        documentID: String,
        leafIndex: Int,
        decorationPlate: Bool = false
    ) -> LeafDecorationRecipe {
        let seed = "\(documentID)|\(leafIndex)|leaf-material-v1|\(decorationPlate)".stableHash
        let motifs = resolvedMotifs(
            pageType: pageType,
            metadata: metadata,
            semanticText: semanticText
        )
        let placementContext = resolvedPlacementContext(motifs: motifs, metadata: metadata)
        let resolver = IlluminationAssetResolver()
        let allPacks = IlluminationPackRegistry.unlockedPacks
        let preferredPacks: [IlluminationAssetPack]
        if let requestedID = metadata["marginaliaPackID"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let requested = allPacks.first(where: { $0.id == requestedID }) {
            preferredPacks = [requested]
        } else {
            preferredPacks = allPacks
        }

        let retainedPrimary = metadata["tags"]?.split(separator: ",")
            .first(where: { $0.hasPrefix("authored-mark:") })
            .flatMap { Data(base64Encoded: String($0.dropFirst("authored-mark:".count))) }
            .flatMap { try? JSONDecoder().decode(IlluminationAsset.self, from: $0) }
        let directedPrimary: IlluminationAsset? = retainedPrimary ?? metadata["authoredMarginaliaAssetID"]
            .flatMap { wantedID in
                preferredPacks.flatMap(\.allAssets).first { asset in
                    (asset.id == wantedID || asset.assetName == wantedID)
                        && (asset.placementTrigger?.allows(placementContext) ?? true)
                }
            }
        let primaryKind: IlluminationAssetKind = directedPrimary?.kind
            ?? (bucket(seed, salt: 3) < 27 ? .stamp : .doodle)
        // Most expressive leaves should contain one discoverable physical
        // mark. The folio compositor still owns a strict per-leaf budget and
        // may omit this asset when no collision-free region exists.
        let primary = directedPrimary ?? (bucket(seed, salt: 5) < (decorationPlate ? 100 : 82)
            ? resolve(
                resolver: resolver,
                kind: primaryKind,
                motifs: motifs,
                placementContext: placementContext,
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 7
            )
            : nil)
        let secondary = bucket(seed, salt: 11) < (decorationPlate ? 78 : 32)
            ? resolve(
                resolver: resolver,
                kind: primaryKind == .stamp ? .doodle : .stamp,
                motifs: motifs,
                placementContext: placementContext,
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 13,
                excluding: Set([primary?.assetName].compactMap { $0 })
            )
            : nil
        let support = bucket(seed, salt: 14) < (decorationPlate ? 58 : 24)
            ? resolve(
                resolver: resolver,
                kind: .paperScrap,
                motifs: motifs + ["paper", "field-note"],
                placementContext: placementContext,
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 15
            )
            : nil
        let fastening = support != nil && bucket(seed, salt: 16) < 52
            ? resolve(
                resolver: resolver,
                kind: .tape,
                motifs: motifs + ["tape", "fastener"],
                placementContext: placementContext,
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 18
            )
            : nil
        let overlay = bucket(seed, salt: 17) < 72
            ? resolve(
                resolver: resolver,
                kind: .overlay,
                motifs: motifs + ["grain", "edge"],
                placementContext: placementContext,
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 19
            )
            : nil
        let snippet = bucket(seed, salt: 23) < (decorationPlate ? 58 : 36)
            ? IlluminationMarginaliaLibrary.select(
                motifs: motifs,
                placementContext: placementContext,
                seed: seed,
                count: 1
            ).first
            : nil
        let placement = [
            LeafMarginaliaPlacement.upperOuterMargin,
            .middleOuterMargin,
            .lowerOuterCorner,
            .faintWatermark
        ][bucket(seed, salt: 29) % 4]

        return LeafDecorationRecipe(
            seed: seed,
            motifs: motifs,
            paperStock: LeafPaperStock.resolve(pageType: pageType, documentID: documentID),
            primaryAsset: primary,
            secondaryAsset: secondary,
            supportAsset: support,
            fasteningAsset: fastening,
            textureOverlay: overlay,
            handwrittenSnippet: snippet,
            primaryPlacement: placement,
            wearLevel: 0.24 + Double(bucket(seed, salt: 31)) / 100 * 0.30,
            hasFoxing: bucket(seed, salt: 37) < 76,
            hasWaterRing: bucket(seed, salt: 41) < 14,
            hasInkSpatter: bucket(seed, salt: 43) < 18,
            hasSoftCrease: bucket(seed, salt: 47) < 34,
            hasWornCorner: bucket(seed, salt: 53) < 28
        )
    }

    private static func resolve(
        resolver: IlluminationAssetResolver,
        kind: IlluminationAssetKind,
        motifs: [String],
        placementContext: IlluminationPlacementContext,
        packs: [IlluminationAssetPack],
        fallbackPacks: [IlluminationAssetPack],
        seed: Int,
        salt: Int,
        excluding: Set<String> = []
    ) -> IlluminationAsset? {
        resolver.resolveAsset(
            kind: kind,
            tags: motifs,
            template: nil,
            installedPacks: packs,
            placementContext: placementContext,
            seed: seed,
            salt: salt,
            excludingAssetNames: excluding
        ) ?? resolver.resolveAsset(
            kind: kind,
            tags: motifs,
            template: nil,
            installedPacks: fallbackPacks,
            placementContext: placementContext,
            seed: seed,
            salt: salt,
            excludingAssetNames: excluding
        )
    }

    private static func resolvedMotifs(
        pageType: BookPageType,
        metadata: [String: String],
        semanticText: String
    ) -> [String] {
        var motifs = [pageType.rawValue, "book", "margin"]
        for key in ["tags", "marginaliaTags", "motifs"] {
            guard let raw = metadata[key] else { continue }
            motifs += raw
                .components(separatedBy: CharacterSet(charactersIn: ",|;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        }
        for key in [
            "senderID", "senderName", "castID", "characterID",
            "facultyID", "speaker", "locationID", "locationName"
        ] {
            guard let raw = metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            motifs += [raw.lowercased(), raw.lowercased().replacingOccurrences(of: " ", with: "-")]
        }
        switch pageType {
        case .weather, .todaysSky:
            motifs += ["weather", "sky", "water"]
        case .location, .anchor, .wonderCompass:
            motifs += ["map", "compass", "field"]
        case .letter, .pactDispatch:
            motifs += ["letter", "postage", "stamp"]
        case .bookOfYou, .bookConnections, .bookRemembered, .narrativeOS:
            motifs += ["memory", "thread", "archive"]
        case .wickerDare, .gamePage:
            motifs += ["play", "field", "ordinary", "curiosity"]
        case .quotes, .affirmations, .rest:
            motifs += ["quiet", "botanical", "soft"]
        case .illuminatedPhoto:
            motifs += ["photo", "frame", "memory"]
        default:
            break
        }
        motifs += semanticMotifs(in: semanticText)
        var seen = Set<String>()
        return motifs.filter { seen.insert($0).inserted }
    }

    /// Turns literal subjects in the ink on this leaf into the same small
    /// vocabulary used by marginalia. This stays local and deterministic: it
    /// does not infer a reader's mood, send prose elsewhere, or add another
    /// model call. Phrase boundaries also keep fragments such as "notebook"
    /// from accidentally summoning a Book mark.
    static func semanticMotifs(in text: String) -> [String] {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let words = folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        let searchable = " \(words.joined(separator: " ")) "

        typealias SemanticEntry = (phrases: [String], motifs: [String])
        let lexicon: [SemanticEntry] = [
            (["punctuation pixie", "punctuation pixies", "pixie", "pixies"], ["punctuation-pixie", "pixie", "punctuation"]),
            (["marginalia goblin", "marginalia goblins", "goblin", "goblins"], ["marginalia-goblin", "goblin"]),
            (["question mark", "question marks"], ["question-mark", "question", "punctuation", "curiosity"]),
            (["exclamation mark", "exclamation marks"], ["exclamation-mark", "punctuation", "warning"]),
            (["semicolon", "semicolons"], ["semicolon", "punctuation"]),
            (["comma", "commas"], ["comma", "punctuation"]),
            (["quotation mark", "quotation marks", "quote marks"], ["quotation-mark", "punctuation", "writing"]),
            (["punctuation"], ["punctuation", "punctuation-pixie"]),
            (["quill", "quills"], ["quill", "writing", "ink"]),
            (["ink bottle", "ink bottles"], ["bottle", "ink", "writing"]),
            (["wax seal", "wax seals"], ["wax-seal", "seal", "sigil"]),
            (["scroll", "scrolls"], ["scroll", "writing"]),
            (["satchel", "satchels"], ["satchel", "notes"]),
            (["blue thread"], ["blue-thread", "thread", "guidance"]),
            (["momort"], ["momort", "character"]),
            (["wicker"], ["wicker", "wicker-eddies", "character"]),
            (["new moon"], ["new-moon", "moon", "event"]),
            (["full moon"], ["full-moon", "moon", "dream"]),
            (["moonlight"], ["moonlight", "moon", "night", "path"]),
            (["dusk"], ["dusk", "night"]),
            (["frog", "frogs"], ["frog", "weather", "pond"]),
            (["pond", "ponds"], ["pond", "outside"]),
            (["camera", "cameras", "photograph", "photographs", "photo", "photos"], ["camera", "photo", "real-world"]),
            (["library", "libraries"], ["library", "place", "secret"]),
            (["door", "doors", "doorway", "doorways"], ["door", "threshold"]),
            (["fox", "foxes"], ["fox", "trail", "wonder"]),
            (["map", "maps"], ["map", "walk", "place"]),
            (["walk", "walks", "walking"], ["walk", "real-world"]),
            (["dream", "dreams", "dreaming"], ["dream", "night"]),
            (["rut", "ruts", "routine", "routines"], ["rut", "routine", "color-draining"]),
            (["margin", "margins", "marginalia"], ["margins", "marginalia"]),
            (["belief"], ["belief", "wonder"]),
            (["wonder"], ["wonder", "look-again"]),
            (["secret", "secrets"], ["secret", "look-closer"]),
            (["laughter", "laugh", "laughing"], ["laughter", "laugh", "play"]),
            (["question", "questions"], ["question", "curiosity"]),
            (["warning", "warnings", "beware"], ["warning", "danger"])
        ]

        var motifs: [String] = []
        var seen = Set<String>()
        for entry in lexicon where entry.phrases.contains(where: {
            searchable.contains(" \($0) ")
        }) {
            for motif in entry.motifs where seen.insert(motif).inserted {
                motifs.append(motif)
                if motifs.count == 24 { return motifs }
            }
        }
        return motifs
    }

    private static func resolvedPlacementContext(
        motifs: [String],
        metadata: [String: String]
    ) -> IlluminationPlacementContext {
        let tags = split(metadata["tags"])
        let taggedPhases = tags.compactMap { tag -> String? in
            let prefix = "event-phase:"
            guard tag.lowercased().hasPrefix(prefix) else { return nil }
            return String(tag.dropFirst(prefix.count))
        }
        let eventIDs = metadata["decorationWorldEventIDs"].map { split($0) }
            ?? (split(metadata["worldEventIDs"]) + split(metadata["triggerWorldEventIDs"]))
        let eventPhases = metadata["decorationWorldEventPhases"].map { split($0) }
            ?? (split(metadata["worldEventPhase"])
                + split(metadata["worldEventPhases"])
                + taggedPhases)
        return IlluminationPlacementContext(
            semanticTags: motifs,
            month: metadata["decorationMonth"].flatMap(Int.init),
            activeWorldEventIDs: eventIDs,
            worldEventPhases: eventPhases
        )
    }

    private static func split(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .components(separatedBy: CharacterSet(charactersIn: ",|;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func bucket(_ seed: Int, salt: Int) -> Int {
        Int(UInt(bitPattern: (seed &+ salt &* 7_919).stableScramble) % 100)
    }
}

enum IlluminationTemplateLibrary {
    static let academyFieldStudy = IlluminationTemplate(
        id: .academyFieldStudy,
        displayName: "Academy Field Study",
        preferredCanvas: .portrait,
        supportedPhotoOrientations: [.portrait, .landscape, .square],
        defaultPhotoTreatment: .softArchive,
        requiredSlots: [
            TemplateTextSlotSpec(
                id: "field-note",
                contentKey: .fieldNote,
                title: "Field Note",
                position: CodablePoint(x: 120, y: 210),
                size: CodableSize(width: 390, height: 185),
                rotationRange: ClosedDoubleRange(lowerBound: -4, upperBound: 3),
                paperTags: ["scrap", "torn"],
                fontStyle: .handwritten,
                maxLines: 3
            ),
            TemplateTextSlotSpec(
                id: "observation-list",
                contentKey: .observationList,
                title: "Today's Observation",
                position: CodablePoint(x: 330, y: 1165),
                size: CodableSize(width: 520, height: 230),
                rotationRange: ClosedDoubleRange(lowerBound: -2, upperBound: 2),
                paperTags: ["scrap", "wide"],
                fontStyle: .handwritten,
                maxLines: 6
            ),
            TemplateTextSlotSpec(
                id: "closing-line",
                contentKey: .closingLine,
                title: nil,
                position: CodablePoint(x: 890, y: 1088),
                size: CodableSize(width: 280, height: 260),
                rotationRange: ClosedDoubleRange(lowerBound: -3, upperBound: 4),
                paperTags: ["scrap", "narrow"],
                fontStyle: .handwritten,
                maxLines: 5
            )
        ],
        optionalSlots: [
            TemplateTextSlotSpec(
                id: "frame-line",
                contentKey: .fixedFrameLine,
                title: nil,
                position: CodablePoint(x: 390, y: 178),
                size: CodableSize(width: 520, height: 150),
                rotationRange: ClosedDoubleRange(lowerBound: -2, upperBound: 2),
                paperTags: ["scrap", "wide"],
                fontStyle: .handwritten,
                maxLines: 2
            ),
            TemplateTextSlotSpec(
                id: "compass-reminder",
                contentKey: .fixedCompassReminder,
                title: "Compass Reminder",
                position: CodablePoint(x: 900, y: 700),
                size: CodableSize(width: 250, height: 250),
                rotationRange: ClosedDoubleRange(lowerBound: -3, upperBound: 4),
                paperTags: ["scrap", "narrow"],
                fontStyle: .handwritten,
                maxLines: 5
            ),
            TemplateTextSlotSpec(
                id: "souvenir-line",
                contentKey: .souvenirCandidate,
                title: nil,
                position: CodablePoint(x: 110, y: 1010),
                size: CodableSize(width: 310, height: 230),
                rotationRange: ClosedDoubleRange(lowerBound: -5, upperBound: 2),
                paperTags: ["scrap", "torn"],
                fontStyle: .handwritten,
                maxLines: 5
            )
        ],
        decorationSlots: [
            TemplateDecorationSlotSpec(id: "bee-stamp", kind: .stamp, tags: ["bee", "academy"], position: CodablePoint(x: 880, y: 210), size: CodableSize(width: 190, height: 190), rotationRange: ClosedDoubleRange(lowerBound: -5, upperBound: 5), opacityRange: ClosedDoubleRange(lowerBound: 0.24, upperBound: 0.34), required: true),
            TemplateDecorationSlotSpec(id: "compass", kind: .doodle, tags: ["compass"], position: CodablePoint(x: 910, y: 615), size: CodableSize(width: 155, height: 155), rotationRange: ClosedDoubleRange(lowerBound: -8, upperBound: 8), opacityRange: ClosedDoubleRange(lowerBound: 0.42, upperBound: 0.58), required: false),
            TemplateDecorationSlotSpec(id: "feather", kind: .doodle, tags: ["feather"], position: CodablePoint(x: 135, y: 570), size: CodableSize(width: 145, height: 360), rotationRange: ClosedDoubleRange(lowerBound: -10, upperBound: -4), opacityRange: ClosedDoubleRange(lowerBound: 0.34, upperBound: 0.46), required: false),
            TemplateDecorationSlotSpec(id: "star", kind: .doodle, tags: ["star"], position: CodablePoint(x: 1020, y: 1200), size: CodableSize(width: 90, height: 90), rotationRange: ClosedDoubleRange(lowerBound: -12, upperBound: 12), opacityRange: ClosedDoubleRange(lowerBound: 0.26, upperBound: 0.38), required: false),
            TemplateDecorationSlotSpec(id: "lower-stamp", kind: .stamp, tags: ["margin", "glass"], position: CodablePoint(x: 120, y: 1250), size: CodableSize(width: 230, height: 230), rotationRange: ClosedDoubleRange(lowerBound: -4, upperBound: 4), opacityRange: ClosedDoubleRange(lowerBound: 0.32, upperBound: 0.48), required: false),
            TemplateDecorationSlotSpec(id: "botanical", kind: .doodle, tags: ["lavender", "rest"], position: CodablePoint(x: 96, y: 360), size: CodableSize(width: 160, height: 360), rotationRange: ClosedDoubleRange(lowerBound: -4, upperBound: 3), opacityRange: ClosedDoubleRange(lowerBound: 0.28, upperBound: 0.42), required: false)
        ],
        backgroundTags: ["parchment", "portrait"]
    )

    static func template(for id: IlluminatedTemplateID) -> IlluminationTemplate {
        switch id {
        case .academyFieldStudy, .goodCompany, .creatureComfort, .harborFieldNote, .homeVessel, .restAndQuiet:
            return academyFieldStudy
        }
    }
}

struct IlluminationMarginaliaSnippet: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var title: String?
    var tags: [String]
    var packID: String
    var weight: Double
    var placementTrigger: IlluminationPlacementTrigger? = nil
}

enum IlluminationMarginaliaLibrary {
    static let corePackID = CoreMarginsPack.id

    static let snippets: [IlluminationMarginaliaSnippet] = [
        snippet("living-story", "A living fantasy story woven with your days.", tags: ["story", "book", "ordinary"]),
        snippet("lanterns-lit", "Keep the lanterns lit.\nKeep the story alive.", tags: ["light", "story", "night"]),
        snippet("letters-margins", "Letters travel through the Margins.", tags: ["letter", "margin", "book"]),
        snippet("quiet-pages", "Some pages are quiet.\nThey are listening.", tags: ["quiet", "rest", "book"]),
        snippet("noticing-magic", "Noticed on purpose.", tags: ["wonder", "notice", "ordinary"]),
        snippet("field-small", "Filed under small astonishments.", tags: ["field", "small", "wonder"]),
        snippet("observe-first", "Observe first.\nName later.", tags: ["field", "study", "notice"]),
        snippet("daylight-missed", "Margins hold what daylight missed.", tags: ["light", "margin", "memory"]),
        snippet("ordinary-wonder", "Specimen:\nordinary wonder.", tags: ["ordinary", "study", "wonder"]),
        snippet("small-page-returned", "A small page returned.", tags: ["book", "small", "memory"]),
        snippet("handle-curiosity", "Handle with curiosity.", tags: ["curiosity", "field", "wonder"]),
        snippet("silence-annotate", "Let silence annotate.", tags: ["quiet", "rest", "soft"]),
        snippet("moss-return", "Return to where the moss grows.", tags: ["home", "green", "rest"]),
        snippet("not-all-tracks", "Not all who wander leave tracks.", tags: ["walk", "wild", "story"]),
        snippet("found-margins", "Found in the Margins.", tags: ["margin", "found", "book"]),
        snippet("usual-interrupt", "Let wonder interrupt the usual.", tags: ["wonder", "ordinary", "play"]),
        snippet("waiting-page", "This page waited. It wants that noted.", tags: ["book", "patient", "memory"]),
        snippet("small-things-story", "Small things become story.", tags: ["small", "story", "ordinary"]),
        snippet("ink-memory", "Ink keeps what memory would forget.", tags: ["ink", "memory", "book"]),
        snippet("weather-cabinet", "For the cabinet of weather.", tags: ["weather", "sky", "soft"]),
        snippet("lamp-remembered", "The lamp remembered for you.", tags: ["light", "night", "home"]),
        snippet("future-note", "A note for future me.", tags: ["memory", "future", "book"]),
        snippet("page-arrived", "Some things arrive unannounced.", tags: ["surprise", "wonder", "story"]),
        snippet("edge-remembers", "This edge remembers.", tags: ["edge", "photo", "memory"]),
        snippet("starlight-noted", "Noted by starlight.", tags: ["night", "light", "quiet"]),
        snippet("paying-attention", "Ink stains are proof of paying attention.", tags: ["ink", "attention", "field"]),
        snippet("north-star", "Follow the north star.", tags: ["compass", "walk", "star"]),
        snippet("gentle-magic", "Handle gently.\nMagic inside.", tags: ["magic", "soft", "care"]),
        snippet("archive-quiet", "Archive of quiet things.", tags: ["quiet", "archive", "rest"]),
        snippet("kept-lantern", "Keep near the lantern.", tags: ["light", "lantern", "night"]),
        snippet("harbor-minutes", "The harbor kept its minutes.", tags: ["harbor", "water", "boat"]),
        snippet("water-weather", "Water holding small weather.", title: "Observation", tags: ["water", "weather", "harbor"]),
        snippet("masts-lines", "Masts writing thin lines.", title: "Observation", tags: ["boat", "harbor", "line"]),
        snippet("dock-watch", "Dock boards keeping watch.", title: "Observation", tags: ["dock", "harbor", "wood"]),
        snippet("soft-authority", "Soft things have authority.", tags: ["creature", "soft", "rest"]),
        snippet("pawlogy", "Pawlogy: rest demonstrated.", tags: ["paw", "creature", "rest"]),
        snippet("good-company", "Good company, plainly glowing.", tags: ["company", "smile", "warm"]),
        snippet("room-museum", "Home made a museum of ordinary things.", tags: ["home", "room", "ordinary"]),
        snippet("quiet-office", "Quiet arrived and took notes.", tags: ["quiet", "rest", "soft"])
    ]

    static var availableSnippets: [IlluminationMarginaliaSnippet] {
        var seen = Set<String>()
        let contentPackSnippets = PageArchetypePackRegistry.enabledPacks()
            .flatMap { $0.marginaliaSnippets ?? [] }
        return (snippets + contentPackSnippets).filter {
            seen.insert("\($0.packID)|\($0.id)").inserted
        }
    }

    static func select(
        motifs: [String],
        placementContext: IlluminationPlacementContext? = nil,
        seed: Int,
        count: Int
    ) -> [IlluminationMarginaliaSnippet] {
        let wantedTags = Set(motifs.map { $0.lowercased() })
        let effectiveContext = placementContext ?? IlluminationPlacementContext(
            semanticTags: motifs,
            month: nil,
            activeWorldEventIDs: [],
            worldEventPhases: []
        )
        let ranked = availableSnippets
            .filter { $0.placementTrigger?.allows(effectiveContext) ?? true }
            .enumerated()
            .map { index, snippet in
                let snippetTags = Set(snippet.tags.map { $0.lowercased() })
                let tagScore = wantedTags.intersection(snippetTags).count
                let jitter = abs((seed &+ index * 7919).stableScramble % 1000)
                return (snippet, Double(tagScore) * 10 + snippet.weight + Double(jitter) / 10000)
            }
        return ranked
            .sorted { $0.1 > $1.1 }
            .prefix(count)
            .map(\.0)
    }

    private static func snippet(
        _ id: String,
        _ text: String,
        title: String? = nil,
        tags: [String],
        packID: String = corePackID,
        weight: Double = 1
    ) -> IlluminationMarginaliaSnippet {
        IlluminationMarginaliaSnippet(id: id, text: text, title: title, tags: tags, packID: packID, weight: weight)
    }
}

enum IlluminatedPageComposer {
    private static let canvasSize = CodableSize(width: 1290, height: 1800)

    private struct TextLayoutVariant {
        var position: CodablePoint
        var size: CodableSize
        var rotationRange: ClosedDoubleRange
    }

    private struct AdaptedTextLayout {
        var position: CodablePoint
        var size: CodableSize
    }

    static func compose(
        analysis: PhotoAnalysis,
        sourceAssetName: String,
        seed: Int,
        assetLocalIdentifier: String? = nil,
        sourceImageSize: CodableSize? = nil
    ) -> IlluminatedPhotoDraft {
        let template = IlluminationTemplateLibrary.template(for: analysis.suggestedTemplate)
        let pack = IlluminationPackRegistry.preferredPack(for: template.id, motifs: analysis.motifs)
        let resolver = IlluminationAssetResolver()
        let background = resolver.resolveAsset(kind: .background, tags: template.backgroundTags, template: template.id, installedPacks: [pack])
        let overlays = pack.overlays.map(\.assetName)
        let photoFrame = PhotoFrameSpec(
            position: jittered(CodablePoint(x: 210, y: 280), seed: seed, salt: 99, x: 26, y: 30),
            size: CodableSize(width: 870, height: 1010),
            rotationDegrees: ClosedDoubleRange(lowerBound: -2.0, upperBound: 2.0).value(seed: seed, salt: 99),
            cornerRadius: 18
        )
        let exclusionRect = marginaliaExclusionRect(
            photoFrame: photoFrame,
            subjectRegion: analysis.subjectRegion,
            sourceImageSize: sourceImageSize
        )
        var usedPaperAssetNames = Set<String>()
        var textSlots = (template.requiredSlots + template.optionalSlots).enumerated().map { offset, spec in
            let body = body(for: spec.contentKey, analysis: analysis)
            let scrap = resolver.resolveAsset(
                kind: .paperScrap,
                tags: spec.paperTags,
                template: template.id,
                installedPacks: [pack],
                seed: seed,
                salt: 101 + offset * 37,
                excludingAssetNames: usedPaperAssetNames
            )
            if let scrap {
                usedPaperAssetNames.insert(scrap.assetName)
            }
            let layout = textLayout(for: spec, seed: seed, salt: offset)
            let adaptedLayout = adaptiveTextLayout(
                position: jittered(layout.position, seed: seed, salt: offset, x: 46, y: 38),
                proposedSize: layout.size,
                body: body,
                paperAsset: scrap,
                seed: seed,
                salt: 211 + offset * 31
            )
            return IlluminatedTextSlot(
                id: UUID(),
                slotId: spec.id,
                paperAssetName: scrap?.assetName ?? "ParchmentFiber",
                title: spec.title,
                body: body,
                position: adaptedLayout.position,
                size: adaptedLayout.size,
                rotationDegrees: layout.rotationRange.value(seed: seed, salt: offset),
                fontStyle: spec.fontStyle
            )
        }
        textSlots.append(contentsOf: extraMarginaliaSlots(
            analysis: analysis,
            seed: seed,
            resolver: resolver,
            template: template.id,
            pack: pack,
            excludingPaperAssetNames: usedPaperAssetNames
        ))
        var decorations = template.decorationSlots.enumerated().compactMap { offset, slot -> DecorationPlacement? in
            guard let asset = resolver.resolveAsset(kind: slot.kind, tags: slot.tags + analysis.motifs, template: template.id, installedPacks: [pack]) else {
                return slot.required ? DecorationPlacement(id: UUID(), assetName: "MarginaliaStar", kind: slot.kind, position: slot.position, size: slot.size, rotationDegrees: 0, opacity: 0.24) : nil
            }
            return DecorationPlacement(
                id: UUID(),
                assetName: asset.assetName,
                kind: slot.kind,
                position: jittered(slot.position, seed: seed, salt: offset + 41),
                size: slot.size,
                rotationDegrees: slot.rotationRange.value(seed: seed, salt: offset + 41),
                opacity: slot.opacityRange.value(seed: seed, salt: offset + 71)
            )
        }
        decorations.append(contentsOf: extraDecorationSlots(
            analysis: analysis,
            seed: seed,
            resolver: resolver,
            template: template.id,
            pack: pack
        ))
        let plan = IlluminatedCompositionPlan(
            templateId: template.id,
            assetPackId: pack.id,
            randomSeed: seed,
            canvasSize: canvasSize,
            photoFrame: photoFrame,
            photoTreatment: template.defaultPhotoTreatment,
            textSlots: textSlots,
            decorations: decorations,
            backgroundAssetName: background?.assetName ?? "ParchmentTexture",
            textureOverlayNames: overlays,
            marginaliaExclusionRect: exclusionRect
        )
        let now = Date()
        return IlluminatedPhotoDraft(
            id: UUID(),
            assetLocalIdentifier: assetLocalIdentifier ?? "bundled:\(sourceAssetName)",
            sourceAssetName: sourceAssetName,
            analysis: analysis,
            compositionPlan: plan,
            renderedPreviewPath: "",
            status: .proposed,
            createdAt: now,
            updatedAt: now
        )
    }

    private static func body(for key: MarginaliaContentKey, analysis: PhotoAnalysis) -> String {
        switch key {
        case .fieldNote:
            return analysis.marginalia.fieldNote
        case .stampLabel:
            return analysis.marginalia.stampLabel
        case .observationList:
            return analysis.marginalia.observationList.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .closingLine:
            return analysis.marginalia.closingLine
        case .souvenirCandidate:
            return analysis.souvenirCandidates.first ?? ""
        case .fixedCompassReminder:
            return "Walk. Notice. Record. Return. Repeat."
        case .fixedFrameLine:
            return "The frame is fictional.\nThe attention is real."
        }
    }

    /// Maps Vision's bottom-left normalized subject box through the same
    /// scaled-to-fill crop used by the photo view, then grows it enough to keep
    /// paper scraps off faces and bodies rather than merely off their centres.
    /// When there is no honest detection, the middle of the photograph stays
    /// clear — the conventional place a photographer is most likely to put the
    /// subject.
    private static func marginaliaExclusionRect(
        photoFrame: PhotoFrameSpec,
        subjectRegion: VisualRegion?,
        sourceImageSize: CodableSize?
    ) -> CodableRect {
        let frameX = photoFrame.position.x
        let frameY = photoFrame.position.y
        let frameWidth = photoFrame.size.width
        let frameHeight = photoFrame.size.height

        guard let subjectRegion else {
            return CodableRect(
                x: frameX + frameWidth * 0.24,
                y: frameY + frameHeight * 0.18,
                width: frameWidth * 0.52,
                height: frameHeight * 0.64
            )
        }

        let mapped: CodableRect
        if let sourceImageSize,
           sourceImageSize.width > 0,
           sourceImageSize.height > 0 {
            let fillScale = max(
                frameWidth / sourceImageSize.width,
                frameHeight / sourceImageSize.height
            )
            let displayedWidth = sourceImageSize.width * fillScale
            let displayedHeight = sourceImageSize.height * fillScale
            let croppedX = (displayedWidth - frameWidth) / 2
            let croppedY = (displayedHeight - frameHeight) / 2
            mapped = CodableRect(
                x: frameX - croppedX + subjectRegion.x * sourceImageSize.width * fillScale,
                y: frameY - croppedY + (1 - subjectRegion.y - subjectRegion.height) * sourceImageSize.height * fillScale,
                width: subjectRegion.width * sourceImageSize.width * fillScale,
                height: subjectRegion.height * sourceImageSize.height * fillScale
            )
        } else {
            mapped = CodableRect(
                x: frameX + subjectRegion.x * frameWidth,
                y: frameY + (1 - subjectRegion.y - subjectRegion.height) * frameHeight,
                width: subjectRegion.width * frameWidth,
                height: subjectRegion.height * frameHeight
            )
        }

        let mappedLeft = max(frameX, mapped.x)
        let mappedTop = max(frameY, mapped.y)
        let mappedRight = min(frameX + frameWidth, mapped.x + mapped.width)
        let mappedBottom = min(frameY + frameHeight, mapped.y + mapped.height)
        guard mappedRight > mappedLeft, mappedBottom > mappedTop else {
            return CodableRect(
                x: frameX + frameWidth * 0.24,
                y: frameY + frameHeight * 0.18,
                width: frameWidth * 0.52,
                height: frameHeight * 0.64
            )
        }

        let centreX = (mappedLeft + mappedRight) / 2
        let centreY = (mappedTop + mappedBottom) / 2
        let protectedWidth = max(mappedRight - mappedLeft + 128, frameWidth * 0.34)
        let protectedHeight = max(mappedBottom - mappedTop + 128, frameHeight * 0.38)
        let left = max(frameX, centreX - protectedWidth / 2)
        let top = max(frameY, centreY - protectedHeight / 2)
        let right = min(frameX + frameWidth, centreX + protectedWidth / 2)
        let bottom = min(frameY + frameHeight, centreY + protectedHeight / 2)
        return CodableRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private static func jittered(_ point: CodablePoint, seed: Int, salt: Int) -> CodablePoint {
        let dx = ClosedDoubleRange(lowerBound: -26, upperBound: 26).value(seed: seed, salt: salt)
        let dy = ClosedDoubleRange(lowerBound: -22, upperBound: 22).value(seed: seed, salt: salt + 13)
        return CodablePoint(x: point.x + dx, y: point.y + dy)
    }

    private static func textLayout(for spec: TemplateTextSlotSpec, seed: Int, salt: Int) -> TextLayoutVariant {
        let variants: [TextLayoutVariant]
        switch spec.contentKey {
        case .fieldNote:
            variants = [
                textVariant(x: 92, y: 190, width: 390, height: 185, rotationLower: -7, rotationUpper: 4),
                textVariant(x: 105, y: 650, width: 335, height: 210, rotationLower: -8, rotationUpper: 3),
                textVariant(x: 780, y: 470, width: 330, height: 210, rotationLower: -4, rotationUpper: 6),
                textVariant(x: 135, y: 930, width: 330, height: 230, rotationLower: -6, rotationUpper: 4),
                textVariant(x: 810, y: 1030, width: 310, height: 240, rotationLower: -3, rotationUpper: 7)
            ]
        case .observationList:
            variants = [
                textVariant(x: 330, y: 1165, width: 520, height: 230, rotationLower: -3, rotationUpper: 3),
                textVariant(x: 235, y: 1250, width: 560, height: 225, rotationLower: -4, rotationUpper: 2),
                textVariant(x: 455, y: 1085, width: 540, height: 225, rotationLower: -2, rotationUpper: 4),
                textVariant(x: 265, y: 1015, width: 530, height: 230, rotationLower: -5, rotationUpper: 2)
            ]
        case .closingLine:
            variants = [
                textVariant(x: 890, y: 1088, width: 280, height: 260, rotationLower: -4, rotationUpper: 5),
                textVariant(x: 105, y: 1060, width: 310, height: 250, rotationLower: -7, rotationUpper: 2),
                textVariant(x: 840, y: 760, width: 305, height: 255, rotationLower: -2, rotationUpper: 7),
                textVariant(x: 760, y: 1340, width: 320, height: 215, rotationLower: 1, rotationUpper: 8)
            ]
        case .fixedFrameLine:
            variants = [
                textVariant(x: 390, y: 178, width: 520, height: 150, rotationLower: -3, rotationUpper: 3),
                textVariant(x: 310, y: 110, width: 540, height: 155, rotationLower: -5, rotationUpper: 2),
                textVariant(x: 485, y: 245, width: 500, height: 145, rotationLower: -2, rotationUpper: 5),
                textVariant(x: 160, y: 135, width: 430, height: 160, rotationLower: -6, rotationUpper: 2)
            ]
        case .fixedCompassReminder:
            variants = [
                textVariant(x: 900, y: 700, width: 250, height: 250, rotationLower: -4, rotationUpper: 5),
                textVariant(x: 885, y: 520, width: 265, height: 250, rotationLower: -3, rotationUpper: 7),
                textVariant(x: 110, y: 1180, width: 285, height: 250, rotationLower: -7, rotationUpper: 2),
                textVariant(x: 835, y: 980, width: 270, height: 250, rotationLower: -2, rotationUpper: 6)
            ]
        case .souvenirCandidate:
            variants = [
                textVariant(x: 110, y: 1010, width: 310, height: 230, rotationLower: -6, rotationUpper: 3),
                textVariant(x: 120, y: 1320, width: 325, height: 215, rotationLower: -6, rotationUpper: 2),
                textVariant(x: 790, y: 1160, width: 330, height: 220, rotationLower: -2, rotationUpper: 7),
                textVariant(x: 90, y: 720, width: 305, height: 220, rotationLower: -8, rotationUpper: 2)
            ]
        case .stampLabel:
            variants = [
                TextLayoutVariant(position: spec.position, size: spec.size, rotationRange: spec.rotationRange)
            ]
        }
        let index = abs((seed &+ salt * 6151).stableScramble) % variants.count
        return variants[index]
    }

    private static func textVariant(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        rotationLower: Double,
        rotationUpper: Double
    ) -> TextLayoutVariant {
        TextLayoutVariant(
            position: CodablePoint(x: x, y: y),
            size: CodableSize(width: width, height: height),
            rotationRange: ClosedDoubleRange(lowerBound: rotationLower, upperBound: rotationUpper)
        )
    }

    private static func extraMarginaliaSlots(
        analysis: PhotoAnalysis,
        seed: Int,
        resolver: IlluminationAssetResolver,
        template: IlluminatedTemplateID,
        pack: IlluminationAssetPack,
        excludingPaperAssetNames: Set<String>
    ) -> [IlluminatedTextSlot] {
        let anchors = [
            (CodablePoint(x: 95, y: 785), CodableSize(width: 280, height: 190), ClosedDoubleRange(lowerBound: -7, upperBound: -2)),
            (CodablePoint(x: 780, y: 130), CodableSize(width: 340, height: 150), ClosedDoubleRange(lowerBound: 1, upperBound: 5)),
            (CodablePoint(x: 940, y: 470), CodableSize(width: 230, height: 230), ClosedDoubleRange(lowerBound: -4, upperBound: 4)),
            (CodablePoint(x: 140, y: 1340), CodableSize(width: 300, height: 190), ClosedDoubleRange(lowerBound: -5, upperBound: 2)),
            (CodablePoint(x: 810, y: 1375), CodableSize(width: 310, height: 190), ClosedDoubleRange(lowerBound: 2, upperBound: 7)),
            (CodablePoint(x: 500, y: 1020), CodableSize(width: 320, height: 150), ClosedDoubleRange(lowerBound: -3, upperBound: 3)),
            (CodablePoint(x: 735, y: 620), CodableSize(width: 285, height: 185), ClosedDoubleRange(lowerBound: -2, upperBound: 6)),
            (CodablePoint(x: 120, y: 430), CodableSize(width: 300, height: 170), ClosedDoubleRange(lowerBound: -6, upperBound: 1)),
            (CodablePoint(x: 705, y: 250), CodableSize(width: 330, height: 165), ClosedDoubleRange(lowerBound: -3, upperBound: 5))
        ]
        let snippets = IlluminationMarginaliaLibrary.select(motifs: analysis.motifs, seed: seed, count: 3)
        var usedPaperAssetNames = excludingPaperAssetNames
        return snippets.enumerated().map { offset, snippet in
            let anchor = anchors[abs((seed &+ offset * 4049).stableScramble) % anchors.count]
            let scrap = resolver.resolveAsset(
                kind: .paperScrap,
                tags: ["scrap", offset.isMultiple(of: 2) ? "torn" : "wide"],
                template: template,
                installedPacks: [pack],
                seed: seed,
                salt: 601 + offset * 43,
                excludingAssetNames: usedPaperAssetNames
            )
            if let scrap {
                usedPaperAssetNames.insert(scrap.assetName)
            }
            let position = jittered(anchor.0, seed: seed, salt: 401 + offset * 29, x: 58, y: 52)
            let adaptedLayout = adaptiveTextLayout(
                position: position,
                proposedSize: anchor.1,
                body: snippet.text,
                paperAsset: scrap,
                seed: seed,
                salt: 617 + offset * 47
            )
            return IlluminatedTextSlot(
                id: UUID(),
                slotId: "marginalia-\(snippet.id)",
                paperAssetName: scrap?.assetName ?? "ParchmentFiber",
                title: snippet.title,
                body: snippet.text,
                position: adaptedLayout.position,
                size: adaptedLayout.size,
                rotationDegrees: anchor.2.value(seed: seed, salt: 511 + offset),
                fontStyle: .handwritten
            )
        }
    }

    private static func adaptiveTextLayout(
        position: CodablePoint,
        proposedSize: CodableSize,
        body: String,
        paperAsset: IlluminationAsset?,
        seed: Int,
        salt: Int
    ) -> AdaptedTextLayout {
        let proposedWidth = max(1, proposedSize.width)
        let proposedHeight = max(1, proposedSize.height)
        let proposedRatio = proposedWidth / proposedHeight
        let paperRatio = min(2.8, max(0.72, paperAsset?.leafTraits?.aspectRatio ?? proposedRatio))
        // Text still owns most of the shape. The paper's authored proportions
        // can tug a scrap wider or taller without turning readable copy into a
        // decorative sliver.
        let aspectRatio = proposedRatio * 0.68 + paperRatio * 0.32
        let visualWeight = min(1.45, max(0.72, paperAsset?.leafTraits?.visualWeight ?? 1))
        let organicScale = ClosedDoubleRange(lowerBound: 0.88, upperBound: 1.14)
            .value(seed: seed, salt: salt)
        let contentExpansion = 1 + min(0.26, Double(max(0, body.count - 72)) / 520)
        let targetArea = proposedWidth
            * proposedHeight
            * visualWeight
            * organicScale
            * organicScale
            * contentExpansion
        var height = sqrt(targetArea / aspectRatio)
        var width = height * aspectRatio

        width = max(proposedWidth * 0.82, width)
        height = max(proposedHeight * 0.84, height)
        let canvasInset = 28.0
        let availableWidth = max(1, canvasSize.width - canvasInset * 2)
        let availableHeight = max(1, canvasSize.height - canvasInset * 2)
        let fitScale = min(1, min(availableWidth / width, availableHeight / height))
        width *= fitScale
        height *= fitScale

        let maximumX = max(canvasInset, canvasSize.width - canvasInset - width)
        let maximumY = max(canvasInset, canvasSize.height - canvasInset - height)
        return AdaptedTextLayout(
            position: CodablePoint(
                x: min(max(canvasInset, position.x), maximumX),
                y: min(max(canvasInset, position.y), maximumY)
            ),
            size: CodableSize(width: width, height: height)
        )
    }

    private static func extraDecorationSlots(
        analysis: PhotoAnalysis,
        seed: Int,
        resolver: IlluminationAssetResolver,
        template: IlluminatedTemplateID,
        pack: IlluminationAssetPack
    ) -> [DecorationPlacement] {
        let slots = [
            (["tape"], IlluminationAssetKind.tape, CodablePoint(x: 235, y: 184), CodableSize(width: 150, height: 48), 0.32),
            (["tape"], IlluminationAssetKind.tape, CodablePoint(x: 940, y: 1230), CodableSize(width: 130, height: 44), 0.30),
            (["shell", "harbor"], IlluminationAssetKind.doodle, CodablePoint(x: 1000, y: 1415), CodableSize(width: 118, height: 118), 0.42),
            (["heart", "company"], IlluminationAssetKind.doodle, CodablePoint(x: 1040, y: 1040), CodableSize(width: 80, height: 80), 0.34),
            (["marginalia"], IlluminationAssetKind.doodle, CodablePoint(x: 95, y: 420), CodableSize(width: 245, height: 170), 0.76),
            (["marginalia"], IlluminationAssetKind.doodle, CodablePoint(x: 850, y: 330), CodableSize(width: 260, height: 175), 0.70),
            (["stamp"], IlluminationAssetKind.stamp, CodablePoint(x: 930, y: 150), CodableSize(width: 170, height: 170), 0.40),
            (["botanical"], IlluminationAssetKind.doodle, CodablePoint(x: 95, y: 1160), CodableSize(width: 130, height: 300), 0.48),
            (["tag"], IlluminationAssetKind.doodle, CodablePoint(x: 1010, y: 765), CodableSize(width: 150, height: 230), 0.66),
            (["book", "library"], IlluminationAssetKind.stamp, CodablePoint(x: 145, y: 1370), CodableSize(width: 155, height: 155), 0.36),
            (["wonder", "ordinary"], IlluminationAssetKind.doodle, CodablePoint(x: 650, y: 1450), CodableSize(width: 165, height: 120), 0.50),
            (["light"], IlluminationAssetKind.doodle, CodablePoint(x: 210, y: 285), CodableSize(width: 135, height: 210), 0.46)
        ]
        return slots.enumerated().compactMap { offset, slot in
            guard let asset = pickAsset(
                kind: slot.1,
                tags: slot.0 + analysis.motifs,
                template: template,
                pack: pack,
                seed: seed,
                salt: 811 + offset * 37
            ) ?? resolver.resolveAsset(kind: slot.1, tags: slot.0 + analysis.motifs, template: template, installedPacks: [pack]) else {
                return nil
            }
            return DecorationPlacement(
                id: UUID(),
                assetName: asset.assetName,
                kind: slot.1,
                position: jittered(slot.2, seed: seed, salt: 701 + offset * 31, x: 52, y: 44),
                size: slot.3,
                rotationDegrees: ClosedDoubleRange(lowerBound: -12, upperBound: 12).value(seed: seed, salt: 733 + offset),
                opacity: slot.4
            )
        }
    }

    private static func pickAsset(
        kind: IlluminationAssetKind,
        tags: [String],
        template: IlluminatedTemplateID,
        pack: IlluminationAssetPack,
        seed: Int,
        salt: Int
    ) -> IlluminationAsset? {
        let normalizedTags = Set(tags.map { $0.lowercased() })
        let matches = pack.allAssets.filter { asset in
            asset.kind == kind
                && asset.supportedTemplates.contains(template)
                && !normalizedTags.isDisjoint(with: Set(asset.tags.map { $0.lowercased() }))
        }
        guard !matches.isEmpty else {
            return nil
        }
        let index = abs((seed &+ salt * 7919).stableScramble) % matches.count
        return matches[index]
    }

    private static func jittered(_ point: CodablePoint, seed: Int, salt: Int, x: Double, y: Double) -> CodablePoint {
        let dx = ClosedDoubleRange(lowerBound: -x, upperBound: x).value(seed: seed, salt: salt)
        let dy = ClosedDoubleRange(lowerBound: -y, upperBound: y).value(seed: seed, salt: salt + 13)
        return CodablePoint(x: point.x + dx, y: point.y + dy)
    }
}

struct IlluminatedPhotoQueue {
    var candidates: [PhotoCandidate] = []
    var history = IlluminatedPhotoHistory()

    mutating func nextCandidate() -> PhotoCandidate? {
        candidates.first {
            !history.keptAssetIdentifiers.contains($0.assetLocalIdentifier)
                && !history.dismissedAssetIdentifiers.contains($0.assetLocalIdentifier)
        }
    }

    mutating func markProposed(_ candidate: PhotoCandidate, at date: Date = Date()) {
        history.proposedAssetIdentifiers.insert(candidate.assetLocalIdentifier)
        history.lastSuggestedAtByAsset[candidate.assetLocalIdentifier] = date
    }

    mutating func markKept(assetLocalIdentifier: String) {
        history.keptAssetIdentifiers.insert(assetLocalIdentifier)
    }

    mutating func markDismissed(assetLocalIdentifier: String) {
        history.dismissedAssetIdentifiers.insert(assetLocalIdentifier)
    }
}

struct IlluminatedPhotoPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .illuminatedPhoto)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        if let prepared = inputs.preparedIlluminatedPhotoSurface {
            return prepared
        }

        let plate = BookReferenceCatalog.labyrinthIllustration(for: day, now: now)
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let analysis = FakePhotoIlluminationAnalyzer.analyze(illustration: plate)
        let draft = IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: plate.assetName,
            seed: abs("\(day.id)-\(plate.assetName)-manual-illuminated-\(slot)".stableHash),
            assetLocalIdentifier: "manual-starter:\(plate.id)"
        )

        return SurfacePage.illuminatedPhotoSurface(
            draft: draft,
            renderedURL: nil,
            idSuffix: "manual-\(slot)"
        ) ?? .handOpened(
            source: source,
            day: day,
            now: now,
            intent: .resurface,
            renderStyle: .illuminatedPhoto,
            score: 70,
            metadata: [
                "sourceAssetName": plate.assetName,
                "assetLocalIdentifier": "manual-starter:\(plate.id)",
                "placeholder": "Choose a photo, let Penny choose, or try another illuminated plate."
            ],
            tags: ["illuminated-photo"]
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !context.distress.isActive else { return [] }
        if let prepared = inputs.preparedIlluminatedPhotoSurface,
           prepared.payload.metadata["renderedPreviewPath"]?.isEmpty == false {
            return [prepared]
        }
        guard inputs.userPhotoIlluminationFallbackAllowed else { return [] }
        let plate = BookReferenceCatalog.labyrinthIllustration(for: day, now: now)
        guard !plate.assetName.isEmpty else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let analysis = FakePhotoIlluminationAnalyzer.analyze(illustration: plate)
        let draft = IlluminatedPageComposer.compose(
            analysis: analysis,
            sourceAssetName: plate.assetName,
            seed: abs("\(day.id)-\(plate.assetName)-illuminated-\(slot)".stableHash),
            assetLocalIdentifier: "bundled-illustration:\(plate.id)"
        )
        return [
            SurfacePage(
                id: "\(source.id)-illustration-\(plate.id)-\(slot)",
                type: .illuminatedPhoto,
                sourceID: source.id,
                intent: .resurface,
                renderStyle: .illuminatedPhoto,
                score: 70,
                reason: "The Labyrinth left a little illustration with ink still on it.",
                prompt: "Illuminated from the Labyrinth",
                detail: "A little illustration that took a trip through Penny's press.",
                payload: BookPagePayload(
                    headline: draft.analysis.marginalia.stampLabel,
                    body: "\(plate.caption)\n\n\(draft.analysis.marginalia.closingLine)",
                    metadata: [
                        "source": source.id,
                        "sourceAssetName": draft.sourceAssetName,
                        "template": draft.compositionPlan.templateId.rawValue,
                        "assetPack": draft.compositionPlan.assetPackId,
                        "status": draft.status.rawValue,
                        "privacy": "bundled local illustration",
                        "fieldNote": draft.analysis.marginalia.fieldNote,
                        "observations": draft.analysis.marginalia.observationList.joined(separator: " | "),
                        "closingLine": draft.analysis.marginalia.closingLine,
                        "scene": draft.analysis.scene,
                        "motifs": draft.analysis.motifs.joined(separator: ","),
                        "souvenirs": draft.analysis.souvenirCandidates.joined(separator: " | "),
                        "plateID": plate.id,
                        "tags": plate.tags.joined(separator: ",")
                    ]
                )
            )
        ]
    }
}
