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
        doodles: [
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
}

struct IlluminationAssetResolver {
    func resolveAsset(
        kind: IlluminationAssetKind,
        tags: [String],
        template: IlluminatedTemplateID?,
        installedPacks: [IlluminationAssetPack],
        seed: Int? = nil,
        salt: Int = 0,
        excludingAssetNames: Set<String> = []
    ) -> IlluminationAsset? {
        let normalizedTags = Set(tags.map { $0.lowercased() })
        let candidates = installedPacks
            .flatMap(\.allAssets)
            .filter { asset in
                guard asset.kind == kind else { return false }
                return template.map { asset.supportedTemplates.contains($0) } ?? true
            }

        let tagged = candidates.filter { asset in
            let searchableTags = asset.tags + (asset.leafTraits?.subjectTags ?? [])
            return !normalizedTags.isDisjoint(with: Set(searchableTags.map { $0.lowercased() }))
        }
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

struct LeafDecorationRecipe: Equatable {
    var seed: Int
    var motifs: [String]
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
        documentID: String,
        leafIndex: Int,
        decorationPlate: Bool = false
    ) -> LeafDecorationRecipe {
        let seed = "\(documentID)|\(leafIndex)|leaf-material-v1|\(decorationPlate)".stableHash
        let motifs = resolvedMotifs(pageType: pageType, metadata: metadata)
        let resolver = IlluminationAssetResolver()
        let allPacks = IlluminationPackRegistry.unlockedPacks
        let preferredPacks: [IlluminationAssetPack]
        if let requestedID = metadata["marginaliaPackID"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let requested = allPacks.first(where: { $0.id == requestedID }) {
            preferredPacks = [requested]
        } else {
            preferredPacks = allPacks
        }

        let primaryKind: IlluminationAssetKind = bucket(seed, salt: 3) < 27 ? .stamp : .doodle
        // Most expressive leaves should contain one discoverable physical
        // mark. The folio compositor still owns a strict per-leaf budget and
        // may omit this asset when no collision-free region exists.
        let primary = bucket(seed, salt: 5) < (decorationPlate ? 100 : 82)
            ? resolve(
                resolver: resolver,
                kind: primaryKind,
                motifs: motifs,
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 7
            )
            : nil
        let secondary = bucket(seed, salt: 11) < (decorationPlate ? 78 : 32)
            ? resolve(
                resolver: resolver,
                kind: primaryKind == .stamp ? .doodle : .stamp,
                motifs: motifs,
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
                packs: preferredPacks,
                fallbackPacks: allPacks,
                seed: seed,
                salt: 19
            )
            : nil
        let snippet = bucket(seed, salt: 23) < (decorationPlate ? 58 : 36)
            ? IlluminationMarginaliaLibrary.select(motifs: motifs, seed: seed, count: 1).first
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
            seed: seed,
            salt: salt,
            excludingAssetNames: excluding
        ) ?? resolver.resolveAsset(
            kind: kind,
            tags: motifs,
            template: nil,
            installedPacks: fallbackPacks,
            seed: seed,
            salt: salt,
            excludingAssetNames: excluding
        )
    }

    private static func resolvedMotifs(pageType: BookPageType, metadata: [String: String]) -> [String] {
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
        var seen = Set<String>()
        return motifs.filter { seen.insert($0).inserted }
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

    static func select(motifs: [String], seed: Int, count: Int) -> [IlluminationMarginaliaSnippet] {
        let wantedTags = Set(motifs.map { $0.lowercased() })
        let ranked = availableSnippets.enumerated().map { index, snippet in
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
    private struct TextLayoutVariant {
        var position: CodablePoint
        var size: CodableSize
        var rotationRange: ClosedDoubleRange
    }

    static func compose(
        analysis: PhotoAnalysis,
        sourceAssetName: String,
        seed: Int,
        assetLocalIdentifier: String? = nil
    ) -> IlluminatedPhotoDraft {
        let template = IlluminationTemplateLibrary.template(for: analysis.suggestedTemplate)
        let pack = IlluminationPackRegistry.preferredPack(for: template.id, motifs: analysis.motifs)
        let resolver = IlluminationAssetResolver()
        let background = resolver.resolveAsset(kind: .background, tags: template.backgroundTags, template: template.id, installedPacks: [pack])
        let overlays = pack.overlays.map(\.assetName)
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
            return IlluminatedTextSlot(
                id: UUID(),
                slotId: spec.id,
                paperAssetName: scrap?.assetName ?? "ParchmentFiber",
                title: spec.title,
                body: body,
                position: jittered(layout.position, seed: seed, salt: offset, x: 46, y: 38),
                size: layout.size,
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
            canvasSize: CodableSize(width: 1290, height: 1800),
            photoFrame: PhotoFrameSpec(
                position: jittered(CodablePoint(x: 210, y: 280), seed: seed, salt: 99, x: 26, y: 30),
                size: CodableSize(width: 870, height: 1010),
                rotationDegrees: ClosedDoubleRange(lowerBound: -2.0, upperBound: 2.0).value(seed: seed, salt: 99),
                cornerRadius: 18
            ),
            photoTreatment: template.defaultPhotoTreatment,
            textSlots: textSlots,
            decorations: decorations,
            backgroundAssetName: background?.assetName ?? "ParchmentTexture",
            textureOverlayNames: overlays
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
            return IlluminatedTextSlot(
                id: UUID(),
                slotId: "marginalia-\(snippet.id)",
                paperAssetName: scrap?.assetName ?? "ParchmentFiber",
                title: snippet.title,
                body: snippet.text,
                position: jittered(anchor.0, seed: seed, salt: 401 + offset * 29, x: 58, y: 52),
                size: anchor.1,
                rotationDegrees: anchor.2.value(seed: seed, salt: 511 + offset),
                fontStyle: .handwritten
            )
        }
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
        ) ?? SurfacePage(
            id: "manual-\(source.type.rawValue)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: source.type,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .illuminatedPhoto,
            score: 70,
            reason: "Opened directly from the Glow menu.",
            prompt: source.title,
            detail: source.note,
            payload: BookPagePayload(
                headline: source.title,
                body: source.note,
                metadata: [
                    "source": source.id,
                    "sourceAssetName": plate.assetName,
                    "assetLocalIdentifier": "manual-starter:\(plate.id)",
                    "placeholder": "Choose a photo, let Penny choose, or try another illuminated plate.",
                    "tags": "manual-page,\(source.type.rawValue),illuminated-photo"
                ]
            )
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
