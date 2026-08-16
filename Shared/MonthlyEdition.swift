import Foundation

/// The name the Book gave this reader, flattened for binding.
///
/// `ComposedRole` is not `Codable` and carries curation weights the archive has
/// no use for. A bound volume only needs the words it will actually print, and
/// needs them frozen, so a volume bound in June still reads the way it read in
/// June even after the role has moved on.
struct BoundReaderRole: Codable, Equatable {
    /// "The Magpie of the Blue Hour": the name the Book uses out loud.
    var fullName: String
    /// The full three-part reading, for the colophon.
    var signature: String
    /// "You come alive with something half-finished in front of you." A
    /// description, and so the one that can be woven into prose.
    var gloss: String
    /// "Make one small thing that wasn't there this morning." An imperative -
    /// a standing charge, not a description. Belongs in the colophon, not
    /// mid-paragraph.
    var compassLine: String
    /// The mark the Book awarded, if it has watched long enough to award one.
    var markName: String?
    /// What it watched them do to earn it, plainly enough to be recognised.
    var markEvidence: String?
    /// The cast member who patrons this role. Their illustration plate becomes
    /// the volume's frontispiece: the reader opens their own book and the
    /// character who stands for them is looking back.
    var patronSlug: String?
    var patronName: String?

    init(
        fullName: String,
        signature: String,
        gloss: String,
        compassLine: String,
        markName: String? = nil,
        markEvidence: String? = nil,
        patronSlug: String? = nil,
        patronName: String? = nil
    ) {
        self.fullName = fullName
        self.signature = signature
        self.gloss = gloss
        self.compassLine = compassLine
        self.markName = markName
        self.markEvidence = markEvidence
        self.patronSlug = patronSlug
        self.patronName = patronName
    }

    init?(_ role: ComposedRole?) {
        guard let role else { return nil }
        self.init(
            fullName: role.fullName,
            signature: role.signature,
            gloss: role.role.gloss,
            compassLine: role.compassLine,
            markName: role.mark?.name,
            markEvidence: role.mark?.evidence,
            patronSlug: role.role.patronSlug,
            patronName: role.role.patronName
        )
    }

    /// The plate asset for the patron, derived from the slug. Every current
    /// patron resolves; the renderer still checks the image exists before
    /// drawing, so adding a cast member without art degrades to no plate rather
    /// than to a blank page.
    var patronPlateAssetName: String? {
        guard let patronSlug, !patronSlug.isEmpty else { return nil }
        let pascal = patronSlug
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
        return "LabyrinthCharacter\(pascal)"
    }

    /// "The Magpie of the Blue Hour, Clear-Eyed": role plus mark, no hands.
    var markedName: String {
        guard let markName else { return fullName }
        return "\(fullName), \(markName)"
    }
}

/// The exact threshold evidence a Inscription edition was commissioned to
/// carry. Keeping this beside the generic edition data lets the Bindery give
/// the onboarding volume its own editorial form without scraping prose back
/// out of section titles or guessing which souvenir meant what.
struct InscriptionPublicationMatter: Codable, Equatable {
    struct Signature: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var evidence: String
        var meaning: String
    }

    /// The first leaf the reader composed with the Pagewright during the
    /// threshold story. The rendered image is kept beside the edition so the
    /// dedicated Inscription press can reproduce the actual arrangement rather
    /// than attempting to rebuild it from onboarding answers later.
    struct PagewrightLeaf: Codable, Equatable {
        var title: String
        var imagePath: String
        var templateID: String
    }

    /// A photograph the reader deliberately promoted from an interior plate
    /// to the face of this private PDF. The path points at a durable local copy
    /// of the source photograph, while the illuminated composition remains an
    /// interior plate. The authored footer clearing keeps live title type away
    /// from the photograph's subject.
    struct ReaderCoverArtwork: Codable, Equatable {
        var imagePath: String
        var titleLayout: PublicationCoverTitleLayout = .photographFooter
        /// Normalised top-left image coordinates chosen from faces, people, or
        /// visual saliency. The upper photograph field centres its crop on
        /// this point; title type lives in a separate lower field.
        var focusX: Double? = nil
        var focusY: Double? = nil
    }

    /// The five movements by which one ordinary detail crossed the threshold
    /// and returned as a physical edition. These are narrative beats, not a
    /// contents list: the Inscription can show the reader the spell it just
    /// performed without claiming to know anything it did not witness.
    struct ThresholdBeat: Codable, Equatable, Identifiable {
        var id: String
        var stage: String
        var detail: String
    }

    /// The real clock-and-calendar line printed on the ownership leaf.
    var arrivalLine: String
    /// Four earned movements: curse, learning, consequence, and return.
    var signatures: [Signature]
    /// The Academy Chapter's first reading of the reader's Page.
    var firstArgumentTitle: String
    var firstArgumentBody: String
    /// A final charge written for the threshold rather than for a calendar
    /// month. It becomes the last authored leaf before the colophon.
    var closing: String
    /// Optional for editions bound before the Pagewright joined onboarding.
    var pagewrightLeaf: PagewrightLeaf? = nil
    /// A loose note from the Book, discovered immediately after the ownership
    /// leaf. Optional keeps already-bound Inscriptions decodable.
    var bookNote: String? = nil
    /// The visible path from noticing to return. Nil means an older edition
    /// should use the press's restrained legacy map.
    var thresholdThread: [ThresholdBeat]? = nil
    /// Zara and Wicker examine this exact little book at the binding table.
    /// Their lines are frozen with the edition and cite only witnessed evidence.
    var bindingConversation: BoundVolumeCastConversation? = nil
    /// Optional for readers who chose the dedicated sigil or a Bindery plate,
    /// and for Inscriptions bound before personal cover photographs existed.
    var readerCoverArtwork: ReaderCoverArtwork? = nil
}

/// The publication house's durable vocabulary. Calendar editions and special
/// editions use the same proof, dedication, cover, binding, and checkout path;
/// only the editorial recipe changes.
enum PublicationEditionKind: String, Codable, Equatable, CaseIterable {
    case weekly
    case monthly
    case seasonal
    case annual
    case special
}

enum PublicationSourceKind: String, Codable, Equatable, CaseIterable {
    case keptPages
    case keptPeople
    case relationshipReceipts
    case castLetters
    case castNotes
    case marginalia
    case readerLetters
}

enum PublicationBindingKind: String, Codable, Equatable, CaseIterable {
    case saddleStitched
    case softcover
    case illustratedHardcover
    case clothFoilHardcover
}

/// A recipe is catalogue data, not a bespoke screen. Adding a future special
/// edition should mean declaring its editorial sources and eligible bindings,
/// then feeding its sections through `PublicationHouseBuilder`.
struct PublicationEditionRecipe: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var invitation: String
    var sourceKinds: [PublicationSourceKind]
    var minimumItemCount: Int
    var bindingKinds: [PublicationBindingKind]
    var canOrderALaCarte: Bool
    var canGift: Bool
}

enum PublicationHouseCatalogue {
    static let peopleYouKept = PublicationEditionRecipe(
        id: "special-people-you-kept",
        title: "The People You Kept",
        subtitle: "A private atlas of the people who altered the year",
        invitation: "The Book has been keeping the doors between you. It could bind the ones that stayed open.",
        sourceKinds: [.keptPeople, .relationshipReceipts, .readerLetters, .keptPages],
        minimumItemCount: 3,
        bindingKinds: [.softcover, .illustratedHardcover, .clothFoilHardcover],
        canOrderALaCarte: true,
        canGift: true
    )

    static let lettersFromTheLabyrinth = PublicationEditionRecipe(
        id: "special-letters-from-the-labyrinth",
        title: "Letters from the Labyrinth",
        subtitle: "Cast letters, notes, and things pushed under the door",
        invitation: "Somebody in the Labyrinth has been folding paper when you weren't looking.",
        sourceKinds: [.castLetters, .castNotes, .marginalia],
        minimumItemCount: 4,
        bindingKinds: [.softcover, .illustratedHardcover, .clothFoilHardcover],
        canOrderALaCarte: true,
        canGift: false
    )

    static let specialEditions: [PublicationEditionRecipe] = [
        peopleYouKept,
        lettersFromTheLabyrinth
    ]

    static func recipe(id: String?) -> PublicationEditionRecipe? {
        guard let id else { return nil }
        return specialEditions.first { $0.id == id }
    }
}

/// The quiet part of an authored plate where its live title belongs. These are
/// editorial decisions, not guesses made by the renderer: the Weather Cabinet
/// owns a pale sheet in its middle, while the Living Stacks keeps a dark shaft
/// of air between the shelves. Both the on-screen proof and print PDF read the
/// same value.
enum PublicationCoverTitleLayout: String, Codable, Equatable {
    case hedgeDoor
    case weatherCabinet
    case livingStacks
    case centeredNight
    case photographFooter

    /// Normalised coordinates inside the *visible front board*, not the bleed
    /// or casewrap allowance. Important type therefore stays put when the same
    /// plate moves from paperback to casewrap or dust jacket.
    var titleRect: (x: Double, y: Double, width: Double, height: Double) {
        switch self {
        case .hedgeDoor: return (0.17, 0.24, 0.66, 0.48)
        case .weatherCabinet: return (0.18, 0.22, 0.64, 0.50)
        case .livingStacks: return (0.22, 0.18, 0.56, 0.48)
        case .centeredNight: return (0.15, 0.29, 0.70, 0.44)
        case .photographFooter: return (0.08, 0.64, 0.84, 0.29)
        }
    }

    var usesDarkInk: Bool { self == .weatherCabinet }
    var needsReadabilityVeil: Bool { self != .weatherCabinet }

    /// The photograph footer must remain readable over the worst possible
    /// source pixel, including white sky. Other plates have authored quiet
    /// regions and need only a lighter unifying veil.
    var readabilityFieldOpacity: Double {
        switch self {
        case .photographFooter: return 0.92
        case .weatherCabinet: return 0.15
        default: return 0.34
        }
    }
}

/// The part of a reader photograph the press must protect while aspect-filling
/// different physical cover canvases. This is stored with the edition rather
/// than rediscovered during each render, so the on-screen proof, Lulu's exact
/// quote-time canvas, and the final PDF all crop around the same subject.
struct PublicationCoverFocus: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }
}

struct PublicationCoverPlate: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var assetName: String
    var titleLayout: PublicationCoverTitleLayout = .centeredNight
}

enum PublicationCoverCatalogue {
    static let rotating: [PublicationCoverPlate] = [
        .init(id: "hedge-door", title: "The Hedge Door", assetName: "BoundVolumeCoverHedgeDoor", titleLayout: .hedgeDoor),
        .init(id: "weather-cabinet", title: "The Weather Cabinet", assetName: "BoundVolumeCoverWeatherCabinet", titleLayout: .weatherCabinet),
        .init(id: "living-stacks", title: "The Living Stacks", assetName: "BoundVolumeCoverLivingStacks", titleLayout: .livingStacks),
        .init(id: "navy-constellations", title: "Navy Constellations", assetName: "EnchantedBookCoverPlate", titleLayout: .centeredNight)
    ]

    static func plate(id: String?) -> PublicationCoverPlate? {
        guard let id else { return nil }
        return rotating.first { $0.id == id }
    }
}

struct MonthlyEdition: Codable, Equatable {
    var title: String
    var subtitle: String
    var generatedAt: Date
    var startDate: Date
    var endDate: Date
    var dayCount: Int
    var pageCount: Int
    var readerName: String
    var chapterNumber: Int
    var monthName: String
    var theme: BookTheme?
    var constellations: [Constellation]
    var foreword: String
    var sections: [MonthlyEditionSection]
    var continuity: LiteraryContinuityDigest
    var howYouSee: HowYouSee.SeeingReceipt?
    /// Gemma's chronological re-reading of the nightly Book of You pages: the
    /// month's daily bindings sewn into a larger "binding of bindings" whose
    /// architecture may be continuous, mosaic, portrait, vigil, or return.
    /// Optional so deterministic/offline bindings and older archives still
    /// decode without it.
    var bindingStory: String? = nil
    /// The month's closing, in the Book's voice. The builder always fills this
    /// with the deterministic `BookForewordWriter.closing(...)`; the app may
    /// overwrite it with a Gemma-written conclusion before binding. Optional so
    /// older saved editions still decode.
    var closing: String?
    /// A small, diverse set of reader-authored passages selected from anywhere
    /// inside the month's eligible keeps. Optional for older saved editions.
    var passageCompass: [MeaningfulPassageSelector.Selection]? = nil
    /// The name the Book gave this reader, frozen at binding time. Optional so
    /// volumes bound before the naming ceremony still decode.
    var readerRole: BoundReaderRole? = nil
    /// Who speaks in this volume's margins. Optional so volumes bound before
    /// the Cast was let into the margins still decode.
    var marginalia: [BoundMarginNote]? = nil
    /// The reader's own dedication. The one page in the volume the Book has no
    /// hand in.
    var dedication: BoundDedication? = nil
    /// The cast member most present this month; their plate faces the Cast's
    /// own movement. Absent in a month the Academy stayed out of.
    var castLead: BoundCastLead? = nil
    /// The small lived almanac earned by this month: outer weather, when the
    /// ink arrived, opt-in private weather and fuel particulars, and real
    /// choices whose consequences crossed the hedge. Seasonal and annual
    /// volumes use the same matter at their larger scale; a month should not
    /// have to wait three months before its ordinary details become literature.
    var publicationMatter: BoundVolumePublicationMatter? = nil
    /// A short argument among the Cast with this exact finished month open on
    /// the binding table. Optional keeps deterministic/offline and older
    /// bindings intact; generated lines carry the evidence ids they discussed.
    var castConversation: BoundVolumeCastConversation? = nil
    /// Calendar bindings infer their kind from their dates. Special editions
    /// carry an explicit recipe so their identity cannot collide with a month
    /// or season built over the same dates.
    var publicationKind: PublicationEditionKind? = nil
    var publicationRecipeID: String? = nil
    /// The commissioned Bindery plate chosen for this copy. Nil means either
    /// the reader supplied a photograph or the edition wears its deterministic
    /// drawn cover. The id, rather than an image path, keeps title-safe layout
    /// authored by `PublicationCoverCatalogue` all the way to the press PDF.
    var publicationCoverPlateID: String? = nil
    /// The subject-aware crop frozen when the reader chooses a photograph.
    /// Nil retains the traditional centred crop for old editions and all
    /// commissioned Bindery plates.
    var publicationCoverFocus: PublicationCoverFocus? = nil
    /// The exact editorial matter for a physical weekly issue. Calendar
    /// metadata still makes the cover and checkout identity, while this keeps
    /// the interior from being rebuilt as a miniature monthly report.
    var weeklyPublication: WeeklyPublicationMatter? = nil
    /// The earned matter for the onboarding chapbook. Optional keeps every
    /// volume bound before the Inscription gained its own press form decodable.
    ///
    /// The stored name still says `firstDoor` on purpose. `MonthlyEdition`
    /// synthesises its `CodingKeys` from property names, so renaming this one
    /// would change the JSON key and orphan every edition already written to
    /// disk — a reader's bound chapbook would silently lose its matter. The
    /// metaphor is gone from everything the reader and the code see; the wire
    /// format keeps its historical spelling until there is a migration to
    /// change it deliberately.
    var firstDoorPublication: InscriptionPublicationMatter? = nil

    /// How the rest of the codebase refers to the above.
    var inscriptionPublication: InscriptionPublicationMatter? {
        get { firstDoorPublication }
        set { firstDoorPublication = newValue }
    }

    /// "The Book of You (The Magpie of the Blue Hour) Chapter 3. June",
    /// falling back to the plain reader name before the Book has named them.
    var chapterHeading: String {
        let name = readerRole?.fullName ?? readerName
        if isInscriptionEdition {
            return "The Book of You (\(name)): The Inscription"
        }
        return "The Book of You (\(name)) Chapter \(chapterNumber): \(monthName)"
    }

    /// Older Inscription PDFs were already saved with the title but without a
    /// publication recipe. Recognising both forms preserves their identity
    /// while new bindings use the durable special-edition marker.
    var isInscriptionEdition: Bool {
        (publicationKind == .special && publicationRecipeID == "first-door")
            || title == "Book of You: The Inscription"
    }

    var isEmpty: Bool {
        pageCount == 0 && sections.allSatisfy(\.items.isEmpty)
    }

    var isThinBinding: Bool {
        dayCount > 0 && dayCount < 7
    }

    var memorySpinePromptLines: [String] {
        guard let spine = sections.first(where: { $0.id == "book-memory-spine" }) else { return [] }
        return spine.items.prefix(5).map { item in
            let body = item.body
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(item.title): \(body)"
        }
    }
}

enum PublicationHouseBuilder {
    static func specialEdition(
        recipe: PublicationEditionRecipe,
        from editorialBase: MonthlyEdition,
        sections: [MonthlyEditionSection],
        dedication: BoundDedication? = nil
    ) -> MonthlyEdition {
        var edition = editorialBase
        edition.title = recipe.title
        edition.subtitle = recipe.subtitle
        edition.sections = sections
        edition.pageCount = sections.reduce(0) { partial, section in
            partial + section.items.count
        }
        edition.dedication = dedication
        edition.publicationKind = .special
        edition.publicationRecipeID = recipe.id
        return edition
    }
}

/// A whole year, bound as a real book: a year-level foreword and closing wrap a
/// sequence of fully-built month-chapters, each with its own theme and star
/// chart. See `MonthlyEditionBuilder.annual`.
struct AnnualEdition: Codable, Equatable {
    var title: String
    var subtitle: String
    var year: Int
    var readerName: String
    var generatedAt: Date
    var startDate: Date
    var endDate: Date
    var dayCount: Int
    var pageCount: Int
    var foreword: String
    var chapters: [MonthlyEdition]
    var constellations: [Constellation]
    var wagers: [BookWager]
    var closing: String
    var continuity: LiteraryContinuityDigest
    /// Year-level residue from Book of You pages: the annual's private index of
    /// refrains, callbacks, questions, and cover-story candidates. Optional so
    /// older saved annuals still decode.
    var memorySpine: AnnualMemorySpine?
    /// The name the Book gave this reader, frozen at binding. Optional so
    /// annuals bound before the naming ceremony still decode.
    var readerRole: BoundReaderRole? = nil
    /// The reader's own dedication, carried by seasonal and annual volumes too.
    var dedication: BoundDedication? = nil
    /// What this volume calls itself on its own cover, and underneath.
    ///
    /// A multi-chapter volume is not always a year: the Bound Year posts three
    /// seasonal volumes before the annual. Nil keeps the year phrasing, so
    /// annuals bound before seasons existed still read exactly as they did.
    var coverLine: String? = nil
    var coverSubline: String? = nil
    /// What the Book would call this season, and why: present only when the
    /// reader has not named it themselves. The app shows this with a way to
    /// overrule it; the reason travels with the name so the reader can argue
    /// with the claim rather than just accept a word.
    var seasonTitleProposal: SeasonTitleProposal? = nil
    /// The reader's own name for the season, when they have given one.
    var readerNamedSeason: String? = nil
    /// A seasonal volume and a membership-year annual share the same chaptered
    /// container, but they are not the same publication. Keeping the identity
    /// explicit prevents a quiet year with only two or three non-empty months
    /// from being mistaken for a softcover season at the press.
    var publicationKind: PublicationEditionKind? = nil
    /// Front-of-volume matter composed across the whole span rather than copied
    /// from the first month: the lived almanac and the real-world choices whose
    /// consequences crossed into the Labyrinth.
    var publicationMatter: BoundVolumePublicationMatter? = nil
    /// A conversation written at binding time in which members of the Cast have
    /// opinions about this exact physical volume. The evidence ids travel with
    /// it so their banter can be surprising without inventing the reader's life.
    var castConversation: BoundVolumeCastConversation? = nil

    /// "The 2026 Annual", or the season's own name.
    func resolvedCoverLine() -> String { coverLine ?? "The \(year) Annual" }

    func resolvedCoverSubline() -> String {
        if let coverSubline { return coverSubline }
        let chapterWord = chapters.count == 1 ? "in one chapter" : "in \(chapters.count) chapters"
        return "a year, bound \(chapterWord)"
    }

    var isEmpty: Bool { chapters.isEmpty }

    /// The named threads carried across the whole year, for the back matter.
    var namedConstellations: [Constellation] {
        ConstellationKeeper.namedConstellations(constellations)
    }
}

/// The volume-scale editorial matter a three-month season or full membership
/// year earns. Month chapters keep their own close reading; this is the wider
/// lens that makes the object worth leafing through instead of merely filing.
struct BoundVolumePublicationMatter: Codable, Equatable {
    var almanacItems: [MonthlyEditionItem]
    var crossingItems: [MonthlyEditionItem]
    /// One concrete line shown before the parcel posts: proof that the interior
    /// has already read the span rather than only counted its pages.
    var proofLine: String

    var isEmpty: Bool { almanacItems.isEmpty && crossingItems.isEmpty }
}

struct BoundVolumeCastConversation: Codable, Equatable {
    var title: String
    var setting: String
    var lines: [BoundVolumeCastLine]
    var evidenceIDs: [String]

    var isEmpty: Bool { lines.isEmpty }
}

struct BoundVolumeCastLine: Codable, Equatable, Identifiable {
    var id: String
    var speakerID: String
    var speakerName: String
    var glyph: String?
    var words: String
}

struct AnnualMemorySpine: Codable, Equatable {
    var motifs: [String]
    var callbacks: [String]
    var coverStories: [String]
    var openQuestions: [String]

    var isEmpty: Bool {
        motifs.isEmpty && callbacks.isEmpty && coverStories.isEmpty && openQuestions.isEmpty
    }

    static func from(days: [BookDay], now: Date = Date()) -> AnnualMemorySpine? {
        let digest = BindingMemorySpine.digest(days: days, now: now, limit: 96)
        guard !digest.braids.isEmpty else { return nil }
        let motifs = digest.motifCounts.prefix(12).map { "\($0.motif) (\($0.count))" }
        let callbackLines = digest.braids
            .compactMap { memory -> String? in
                guard let callback = memory.residue.callbackCandidate?.nonEmpty else { return nil }
                return "\(memory.residue.title): \(callback)"
            }
        let callbacks = Array(callbackLines.prefix(16))
        let coverStories = digest.braids
            .prefix(12)
            .map { "\($0.residue.title): \($0.residue.spineLine)" }
        let questionLines = digest.braids
            .compactMap(\.residue.openedQuestion)
        let questions = Array(questionLines.prefix(8))
        let spine = AnnualMemorySpine(
            motifs: motifs,
            callbacks: callbacks,
            coverStories: coverStories,
            openQuestions: questions
        )
        return spine.isEmpty ? nil : spine
    }
}

/// A note in the margin of a bound volume, and: the whole point: *who said
/// it*. The renderer has always drawn hand-inked notes at deterministic angles
/// in two ink colours; until now they were filled with the Book's own analytic
/// summaries, so nobody was speaking in them.
struct BoundMarginNote: Codable, Equatable, Identifiable {
    var id: String
    /// Nil when the Book itself is the one talking.
    var speakerSlug: String?
    var speakerName: String?
    /// The speaker's own ink, "RRGGBB". Nil falls back to the volume's ink.
    var accentHex: String?
    /// The speaker's signature stamp: Pippa's interrobang, Mook's section sign.
    var glyph: String?
    var text: String

    var isSpoken: Bool { speakerName != nil }
}

/// Turns what the Cast actually *did* into marginalia for a bound volume.
///
/// The material is already authored: every `CastActRecord` keeps "the sentence
/// that reached the page… so it can be quoted back exactly rather than
/// re-derived into a paraphrase." That sentence has never been printed. Quoting
/// it in the margin of the month it happened in, in the speaker's own ink and
/// under their own glyph, costs no new prose and is the most striking thing
/// this volume can carry.
enum CastMarginalia {
    /// At most this many notes from any one character per volume, so a busy
    /// month does not become one person heckling in every margin.
    static let notesPerSpeaker = 2

    static func notes(
        acts: [CastActRecord],
        start: Date,
        end: Date,
        limit: Int = 10
    ) -> [BoundMarginNote] {
        let window = acts
            .filter { $0.occurredAt >= start && $0.occurredAt <= end }
            .filter { !$0.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { left, right in
                if left.occurredAt == right.occurredAt { return left.id < right.id }
                return left.occurredAt < right.occurredAt
            }

        var perSpeaker: [String: Int] = [:]
        var notes: [BoundMarginNote] = []
        for record in window {
            let used = perSpeaker[record.actorID, default: 0]
            guard used < notesPerSpeaker else { continue }
            perSpeaker[record.actorID] = used + 1
            let voice = KeepMarginalia.voice(forSlug: record.actorID)
            notes.append(
                BoundMarginNote(
                    id: "cast-margin-\(record.id)",
                    speakerSlug: record.actorID,
                    speakerName: voice?.name ?? record.actorName,
                    accentHex: voice?.accentHex,
                    glyph: voice?.glyph,
                    text: record.line
                )
            )
            if notes.count >= limit { break }
        }
        return notes
    }

    /// The Book's own observations, unattributed, used to fill the margins of a
    /// month the Cast stayed out of.
    static func unspokenNotes(_ lines: [String]) -> [BoundMarginNote] {
        lines.enumerated().map { index, line in
            BoundMarginNote(id: "book-margin-\(index)", text: line)
        }
    }

    /// The illustration plate for a cast member.
    ///
    /// A voice card is authoritative where one exists: Pippa's plate is
    /// `LabyrinthCharacterPilcrow`, not the mechanical form of her slug, and
    /// guessing would miss it. Everyone else PascalCases cleanly. The renderer
    /// still checks the image loads, so a wrong guess costs a divider, never a
    /// blank page.
    static func plateAssetName(forSlug slug: String) -> String? {
        guard !slug.isEmpty else { return nil }
        if let asset = KeepMarginalia.voice(forSlug: slug)?.asset { return asset }
        let pascal = slug
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
        return "LabyrinthCharacter\(pascal)"
    }

    /// Who was most present this month. Drives the divider plate that faces the
    /// Cast's own movement: the character who actually turned up, not a
    /// decorative pick.
    static func lead(acts: [CastActRecord], start: Date, end: Date) -> BoundCastLead? {
        let window = acts.filter { $0.occurredAt >= start && $0.occurredAt <= end }
        guard !window.isEmpty else { return nil }

        var counts: [String: (name: String, count: Int)] = [:]
        for record in window {
            let existing = counts[record.actorID]
            counts[record.actorID] = (
                name: KeepMarginalia.voice(forSlug: record.actorID)?.name ?? record.actorName,
                count: (existing?.count ?? 0) + 1
            )
        }
        // Ties break on slug so a month always binds the same way twice.
        guard let winner = counts
            .sorted(by: { left, right in
                if left.value.count == right.value.count { return left.key < right.key }
                return left.value.count > right.value.count
            })
            .first
        else { return nil }

        return BoundCastLead(
            slug: winner.key,
            name: winner.value.name,
            plateAssetName: plateAssetName(forSlug: winner.key)
        )
    }
}

/// The cast member most present in a bound month, with their plate.
struct BoundCastLead: Codable, Equatable {
    var slug: String
    var name: String
    var plateAssetName: String?
}

/// What the Book would call a season, offered rather than imposed.
///
/// The standing rule is that the reader names their own seasons and only
/// backwards. This does not break it: the Book proposes a title *from the
/// season's own evidence*, the reader can take it, change it, or ignore it, and
/// a season with no proposal worth making stays titled by its months. Nothing
/// here invents a mood: every candidate is lifted from something the season
/// actually contained.
enum SeasonTitler {
    /// A proposed name, or nil when the season gave the Book nothing to work
    /// from. Nil is a real answer: a quiet season should not be flattered with
    /// a grand title.
    static func propose(
        chapters: [MonthlyEdition],
        constellations: [Constellation] = []
    ) -> SeasonTitleProposal? {
        // 1. A named thread that ran through the season. The strongest possible
        //    grounding: the reader watched it happen often enough to earn a name.
        let volumeStart = chapters.map(\.startDate).min()
        let volumeEnd = chapters.map(\.endDate).max()
        let namedInSpan = ConstellationKeeper.namedConstellations(constellations).filter { constellation in
            guard let volumeStart, let volumeEnd else { return false }
            return constellation.lastSeenAt >= volumeStart && constellation.firstNoticedAt <= volumeEnd
        }
        if let named = namedInSpan.first {
            return SeasonTitleProposal(
                title: named.displayName,
                because: "You watched \(named.displayName) long enough that it earned its name here."
            )
        }

        // 2. A theme that held across more than one month of the season. One
        //    month is weather; two is a season.
        let themes = chapters.compactMap(\.theme)
        var themeCounts: [String: (name: String, count: Int)] = [:]
        for theme in themes {
            let existing = themeCounts[theme.name.lowercased()]
            themeCounts[theme.name.lowercased()] = (theme.name, (existing?.count ?? 0) + 1)
        }
        if let held = themeCounts.values.filter({ $0.count > 1 })
            .sorted(by: { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count })
            .first {
            return SeasonTitleProposal(
                title: held.name,
                because: "\(held.name) held across \(held.count) months of it, which is what makes a season rather than a mood."
            )
        }

        // 3. A motif the season kept returning to.
        var motifCounts: [String: Int] = [:]
        for motif in themes.flatMap(\.motifs) where !motif.isEmpty {
            motifCounts[motif.lowercased(), default: 0] += 1
        }
        if let motif = motifCounts.filter({ $0.value > 1 })
            .sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value })
            .first {
            return SeasonTitleProposal(
                title: "The Season of \(motif.key.capitalized)",
                because: "\(motif.key.capitalized) kept turning up, across months rather than days."
            )
        }

        return nil
    }
}

/// A title the Book is offering, and the receipt for offering it. The reason
/// travels with the name so the reader can judge the claim rather than just
/// accept a word.
struct SeasonTitleProposal: Codable, Equatable {
    var title: String
    /// Why the Book thinks so, in its own voice.
    var because: String
}

/// A bound season standing at the door, waiting to be posted.
///
/// The membership is prepaid, so this is **not** a permission slip: the volume
/// ships when the window closes whether the reader touched it or not. Doing
/// nothing is a complete and correct answer. What the window is for is naming
/// the season, confirming where it goes, and choosing how it is bound.
///
/// There is no skip. A skipped volume in a prepaid year is value the reader
/// already bought and did not receive, which leaves a debt with no clean way to
/// settle it, and a Book that offers not to witness a hard season is arguing
/// against its own thesis. What exists instead is a **hold**: the volume waits
/// on the shelf, indefinitely, and posts whenever they ask. Nothing is
/// forfeited and nothing arrives at the worst possible moment.
struct SeasonalDispatch: Codable, Equatable, Identifiable {
    var id: String
    /// "2026-Q2": one dispatch per season, ever.
    var seasonKey: String
    /// What the cover currently says.
    var coverLine: String
    /// What the Book suggested, and why. Cleared the moment the reader names it
    /// themselves; the Book does not keep arguing after it has been overruled.
    var titleProposal: SeasonTitleProposal?
    var readerNamedSeason: String?
    var boundAt: Date
    /// When it posts. Nil only while held.
    var shipsAt: Date?
    var chapterCount: Int
    var pageCount: Int
    var variantID: String
    /// Optional for old dispatches. New ones carry their press identity even
    /// when sparse months mean chapter count cannot reveal what they are.
    var publicationKind: PublicationEditionKind? = nil
    /// A small interior receipt for the steering Page. This is not marketing
    /// copy: it is pulled from the volume's already-built almanac.
    var interiorProofLine: String? = nil
    /// Upsell ids chosen in the window. Priced by the Worker, never here.
    var selectedOptionIDs: [String] = []
    /// The reader's own words for this one parcel. It belongs to the volume,
    /// not the membership, so a later season never inherits it by accident.
    var dedication: BoundDedication? = nil
    /// Cover authorship is included in the membership. Optional storage keeps
    /// seasons opened by older app versions decodable as `bookChooses`.
    var coverChoice: BoundVolumeCoverChoice? = nil
    var coverPlateID: String? = nil
    /// A relative private filename, never a Photos-library identifier and never
    /// uploaded anywhere except as part of the finished cover PDF.
    var coverPhotoFilename: String? = nil
    /// Frozen with the private filename so the steering proof and rebuilt
    /// seasonal/annual press PDF protect the same face, person, or salient bit.
    var coverPhotoFocus: PublicationCoverFocus? = nil
    var addressConfirmedAt: Date? = nil
    /// Set when the reader asks the Book to wait. Not a cancellation.
    var heldAt: Date? = nil
    var postedAt: Date? = nil

    var isHeld: Bool { heldAt != nil }
    var hasPosted: Bool { postedAt != nil }
    var isAnnualVolume: Bool {
        if let publicationKind { return publicationKind == .annual }
        // Migration fallback: the fourth dispatch has always worn linen. Keep
        // old sparse hardcovers annual even when fewer than four months had ink.
        if variantID == PhysicalBookVariant.id(for: .linenWrap) { return true }
        return chapterCount > BoundYearCycle.monthsPerSeason
    }
    var needsAddressConfirmation: Bool { addressConfirmedAt == nil }
    var resolvedCoverChoice: BoundVolumeCoverChoice { coverChoice ?? .bookChooses }

    /// The live proof and the final rebuilt volume share this line. It is
    /// derived rather than stored so renaming a season changes the jacket at
    /// once and old dispatches remain decodable.
    var resolvedCoverSubline: String {
        let chapterWord = chapterCount == 1 ? "one month" : "\(chapterCount) months"
        if isAnnualVolume { return "the membership year, in \(chapterWord)" }
        if readerNamedSeason != nil { return "the season you named, in \(chapterWord)" }
        if titleProposal != nil { return "a season I would call this, in \(chapterWord)" }
        return "\(chapterWord), bound"
    }

    /// Whole days left before it posts. Zero once the window has run out: the
    /// volume is still going, there is simply nothing left to decide.
    func daysRemaining(now: Date, calendar: Calendar = .current) -> Int {
        guard let shipsAt, !isHeld else { return 0 }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: shipsAt)
        ).day ?? 0
        return max(0, days)
    }

    /// Whether the reader can still change anything.
    func isOpen(now: Date) -> Bool {
        guard !hasPosted else { return false }
        if isHeld { return true }
        guard let shipsAt else { return false }
        return now < shipsAt
    }
}

enum BoundVolumeCoverChoice: String, Codable, Equatable, CaseIterable {
    case bookChooses
    case binderyPlate
    case readerPhoto
}

/// The rules of the shipping window. Deterministic and side-effect free, so
/// every one of them is testable without a Worker or a clock.
enum SeasonalDispatchWindow {
    /// Long enough to notice and answer, short enough that the Q4 volume still
    /// clears the December gift post.
    static let windowDays = 7
    /// Long enough for a true season-name, short enough to remain legible in a
    /// three-line title clearing on a 6 × 9 cover.
    static let coverTitleCharacterLimit = 72

    static func open(
        seasonKey: String,
        volume: AnnualEdition,
        publicationKind: PublicationEditionKind = .seasonal,
        variantID: String = PhysicalBookVariant.id(for: .perfectBound),
        boundAt: Date,
        calendar: Calendar = .current
    ) -> SeasonalDispatch {
        let resolvedKind = volume.publicationKind ?? publicationKind
        return SeasonalDispatch(
            id: "seasonal-dispatch-\(seasonKey)",
            seasonKey: seasonKey,
            coverLine: volume.resolvedCoverLine(),
            titleProposal: volume.seasonTitleProposal,
            readerNamedSeason: volume.readerNamedSeason,
            boundAt: boundAt,
            shipsAt: calendar.date(byAdding: .day, value: windowDays, to: boundAt),
            chapterCount: volume.chapters.count,
            pageCount: volume.pageCount,
            variantID: variantID,
            publicationKind: resolvedKind,
            interiorProofLine: volume.publicationMatter?.proofLine
        )
    }

    /// The reader's word replaces the Book's, and the Book stops offering.
    static func rename(_ dispatch: SeasonalDispatch, to title: String) -> SeasonalDispatch {
        guard let named = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              named.count <= coverTitleCharacterLimit else {
            return dispatch
        }
        var updated = dispatch
        updated.coverLine = named
        updated.readerNamedSeason = named
        updated.titleProposal = nil
        return updated
    }

    /// Wait, indefinitely, until asked. Never a cancellation: `shipsAt` is
    /// cleared rather than passed, so nothing expires while it waits.
    static func hold(_ dispatch: SeasonalDispatch, at date: Date) -> SeasonalDispatch {
        guard !dispatch.hasPosted else { return dispatch }
        var updated = dispatch
        updated.heldAt = date
        updated.shipsAt = nil
        return updated
    }

    /// Released from a hold, with a fresh window: a reader coming back to a
    /// volume they set aside months ago should get the same chance to name it.
    static func release(
        _ dispatch: SeasonalDispatch,
        at date: Date,
        calendar: Calendar = .current
    ) -> SeasonalDispatch {
        guard dispatch.isHeld, !dispatch.hasPosted else { return dispatch }
        var updated = dispatch
        updated.heldAt = nil
        updated.shipsAt = calendar.date(byAdding: .day, value: windowDays, to: date)
        return updated
    }

    static func confirmAddress(_ dispatch: SeasonalDispatch, at date: Date) -> SeasonalDispatch {
        var updated = dispatch
        updated.addressConfirmedAt = date
        return updated
    }

    static func choose(_ dispatch: SeasonalDispatch, optionIDs: [String]) -> SeasonalDispatch {
        var updated = dispatch
        // Deduplicated and ordered, so the same choices always price the same.
        var seen: Set<String> = []
        updated.selectedOptionIDs = optionIDs.filter { seen.insert($0).inserted }.sorted()
        return updated
    }

    static func dedicate(_ dispatch: SeasonalDispatch, with dedication: BoundDedication?) -> SeasonalDispatch {
        var updated = dispatch
        updated.dedication = dedication
        return updated
    }

    static func chooseCover(
        _ dispatch: SeasonalDispatch,
        choice: BoundVolumeCoverChoice,
        plateID: String? = nil,
        photoFilename: String? = nil,
        photoFocus: PublicationCoverFocus? = nil
    ) -> SeasonalDispatch {
        var updated = dispatch
        updated.coverChoice = choice
        updated.coverPlateID = choice == .binderyPlate ? plateID : nil
        updated.coverPhotoFilename = choice == .readerPhoto ? photoFilename : nil
        updated.coverPhotoFocus = choice == .readerPhoto ? photoFocus : nil
        if dispatch.isAnnualVolume {
            // Cloth and foil remains the annual's included default. A photo or
            // illustrated plate needs a printable casewrap, also included.
            updated.variantID = choice == .bookChooses
                ? PhysicalBookVariant.id(for: .linenWrap)
                : PhysicalBookVariant.id(for: .caseWrap)
        }
        return updated
    }

    /// **Silence is consent, deliberately.** A prepaid volume the reader never
    /// looked at still posts; the window was an offer to steer, not a gate to
    /// pass. Only a hold stops the clock.
    static func shouldPost(_ dispatch: SeasonalDispatch, now: Date) -> Bool {
        guard !dispatch.hasPosted, !dispatch.isHeld else { return false }
        guard let shipsAt = dispatch.shipsAt else { return false }
        return now >= shipsAt
    }

    static func markPosted(_ dispatch: SeasonalDispatch, at date: Date) -> SeasonalDispatch {
        var updated = dispatch
        updated.postedAt = date
        return updated
    }

    /// What the reader can do, and where it happens.
    ///
    /// Only the name lives on the Page itself: one field, and the reason the
    /// window exists at all. Everything else opens its own small surface,
    /// because a page carrying six controls has stopped being a page and become
    /// a form, and this Book does not do forms.
    static func actions(for dispatch: SeasonalDispatch) -> [SeasonalDispatchAction] {
        guard !dispatch.hasPosted else { return [] }
        if dispatch.isHeld {
            return [.rename, .cover, .dedication, .release, .address]
        }
        return [.rename, .cover, .dedication, .address, .hold]
    }
}

/// A dedication the reader wrote, bound into their own volume.
///
/// The Book does not write this one and never suggests a wording. Everything
/// else in a volume is the Book's account of the reader; a dedication is the
/// reader's account of somebody else, and it is the only page in the book that
/// belongs entirely to them.
///
/// Kept plain on purpose: no title, no ornament beyond the page itself. The
/// convention is centuries old because it works: a short line, high on an
/// otherwise empty leaf, is louder than anything decorated.
struct BoundDedication: Codable, Equatable {
    /// What they wrote. Trimmed, never edited.
    var text: String
    /// When they wrote it, so a reprint years later still carries the words
    /// they meant at the time rather than whatever they think now.
    var writtenAt: Date

    init?(text: String, writtenAt: Date = Date()) {
        guard let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else {
            return nil
        }
        guard trimmed.count <= Self.characterLimit else { return nil }
        self.text = trimmed
        self.writtenAt = writtenAt
    }

    /// Dedications are short by convention and by good sense: a whole page of
    /// small type is a letter, not a dedication.
    static let characterLimit = 240

    var fitsOnItsOwnPage: Bool { text.count <= Self.characterLimit }
}

/// The Bound Year: a membership that posts printed volumes.
///
/// Sold on the web because Apple requires physical goods to be, billed either
/// monthly or annually, and worth three seasonal softcovers plus the annual
/// hardcover across a year.
struct BoundYearMembership: Codable, Equatable {
    enum Cadence: String, Codable, Equatable, CaseIterable {
        case monthly
        case annual

        /// Twelve charge attempts against four shipments, or one against four.
        var chargesPerYear: Int { self == .monthly ? 12 : 1 }
    }

    enum Status: String, Codable, Equatable {
        case active
        /// A charge failed and Stripe is retrying. Still a member.
        case inGracePeriod
        case lapsed
        case cancelled
    }

    var cadence: Cadence
    var status: Status
    /// The membership's own anniversary. Seasons are counted from here, not
    /// from the calendar: a reader who joined in February gets February to
    /// April as their first season rather than a stub of one.
    var startedAt: Date
    /// How far the money actually reaches. This is the load-bearing date for a
    /// monthly member: it is what decides whether a season was paid for.
    var paidThrough: Date
    /// Set when they stop. Volumes already earned still go.
    var endedAt: Date?

    var isCurrent: Bool { status == .active || status == .inGracePeriod }
}

/// What the printed year costs.
///
/// Physical goods cannot be sold through StoreKit, so unlike the Standing
/// Order there is no live price to read back from Apple: these are the numbers
/// the Bindery's own till charges. They were written out by hand in four
/// separate strings before, which is three chances for the paywall to quote a
/// price the till does not honour.
enum BoundYearPricing {
    static let monthlyCents = 2_499
    static let annualCents = 24_900

    static var monthlyPrice: Decimal { Decimal(monthlyCents) / 100 }
    static var annualPrice: Decimal { Decimal(annualCents) / 100 }

    static var monthlyDisplayPrice: String { "$24.99" }
    static var annualDisplayPrice: String { "$249" }

    /// Volumes posted per membership year: three seasonal softcovers and the
    /// hardcover that closes the year.
    static let volumesPerYear = BoundYearCycle.seasonsPerYear
}

/// When a season closes for a member, and whether it was paid for.
enum BoundYearCycle {
    static let monthsPerSeason = 3
    static let seasonsPerYear = 4

    /// The window of the Nth season, counted from the membership's own start.
    static func seasonWindow(
        _ index: Int,
        membership: BoundYearMembership,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        let anchor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: membership.startedAt)
        ) ?? membership.startedAt
        guard let start = calendar.date(byAdding: .month, value: index * monthsPerSeason, to: anchor),
              let next = calendar.date(byAdding: .month, value: monthsPerSeason, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: next) else { return nil }
        return (start, end)
    }

    /// "2026-Q2" style key, but counted on the membership's clock.
    static func seasonKey(_ index: Int, membership: BoundYearMembership, calendar: Calendar = .current) -> String {
        guard let window = seasonWindow(index, membership: membership, calendar: calendar) else {
            return "season-\(index)"
        }
        let year = calendar.component(.year, from: window.start)
        let month = calendar.component(.month, from: window.start)
        return String(format: "%04d-S%02d", year, month)
    }

    /// **Whether this season was actually paid for**, which is the whole
    /// difference between the two cadences.
    ///
    /// An annual member paid the year up front, so every volume in it is owed
    /// regardless of what happens later: cancelling in month seven does not
    /// claw back a book they already bought.
    ///
    /// A monthly member earns volumes as they pay. If the money stopped before
    /// the season closed, the season does not ship, and crucially they are
    /// owed nothing either, because they only ever paid for the months they
    /// got. That is the same principle as having no skip button: never leave a
    /// debt in either direction.
    static func seasonIsEarned(
        _ index: Int,
        membership: BoundYearMembership,
        calendar: Calendar = .current
    ) -> Bool {
        guard let window = seasonWindow(index, membership: membership, calendar: calendar) else { return false }
        switch membership.cadence {
        case .annual:
            return membership.paidThrough >= window.start
        case .monthly:
            return membership.paidThrough >= window.end
        }
    }

    /// The season that has closed, been paid for, and not yet been sent.
    static func seasonDue(
        membership: BoundYearMembership,
        alreadyDispatchedKeys: Set<String>,
        now: Date,
        calendar: Calendar = .current
    ) -> (index: Int, key: String, window: (start: Date, end: Date))? {
        for index in 0..<seasonsPerYear * 4 {
            guard let window = seasonWindow(index, membership: membership, calendar: calendar) else { continue }
            if window.start > now { break }
            guard window.end <= now else { continue }
            let key = seasonKey(index, membership: membership, calendar: calendar)
            guard !alreadyDispatchedKeys.contains(key) else { continue }
            guard seasonIsEarned(index, membership: membership, calendar: calendar) else { continue }
            return (index, key, window)
        }
        return nil
    }

    /// Binds the season that is due, if one is, and opens its window.
    ///
    /// The single entry point for the whole cycle: give it the membership, the
    /// archive and what has already gone out, and it either returns a new
    /// dispatch or nothing at all. Deterministic and side-effect free, so the
    /// caller decides when to run it and the rules stay testable without a
    /// clock or a Worker.
    ///
    /// Returns nil for every ordinary day: no season closed, none paid for,
    /// none left unsent, or the reader simply is not a member.
    static func openDueDispatch(
        membership: BoundYearMembership?,
        days: [BookDay],
        existing: [SeasonalDispatch],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        readerName: String = "friend",
        readerRole: BoundReaderRole? = nil,
        castActs: [CastActRecord] = [],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        facultyEntries: [FacultyEntry] = [],
        includePrivateLifeAlmanac: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = [],
        seasonName: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SeasonalDispatch? {
        // A stopped monthly membership can still have a fully paid season that
        // closed before it lapsed. Status decides future billing; paidThrough
        // decides what the reader is already owed.
        guard let membership else { return nil }
        guard let due = seasonDue(
            membership: membership,
            alreadyDispatchedKeys: Set(existing.map(\.seasonKey)),
            now: now,
            calendar: calendar
        ) else { return nil }

        let bindsAnnual = isAnnualVolume(due.index)
        let volumeStart: Date
        if bindsAnnual,
           let firstSeason = seasonWindow(
               due.index - (seasonsPerYear - 1),
               membership: membership,
               calendar: calendar
           ) {
            volumeStart = firstSeason.start
        } else {
            volumeStart = due.window.start
        }
        let volume = MonthlyEditionBuilder.seasonal(
            from: days,
            startingMonth: volumeStart,
            events: events,
            entityMemories: entityMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            constellations: constellations,
            wagers: wagers,
            themes: themes,
            storyConsequences: storyConsequences,
            facultyEntries: facultyEntries,
            readerName: readerName,
            readerRole: readerRole,
            castActs: castActs,
            seasonName: bindsAnnual ? nil : seasonName,
            monthsPerSeason: bindsAnnual ? monthsPerSeason * seasonsPerYear : monthsPerSeason,
            bindsAnnual: bindsAnnual,
            includePrivateLifeAlmanac: includePrivateLifeAlmanac,
            academySeason: academySeason,
            boundTales: boundTales,
            now: now,
            calendar: calendar
        )
        // A season with nothing in it is not a book. Better to send nothing
        // than to post someone a bound volume of three empty months.
        guard !volume.isEmpty else { return nil }

        return SeasonalDispatchWindow.open(
            seasonKey: due.key,
            volume: volume,
            publicationKind: bindsAnnual ? .annual : .seasonal,
            variantID: variantID(forSeasonIndex: due.index),
            boundAt: now,
            calendar: calendar
        )
    }

    /// The fourth volume of every membership year is the hardcover. The year
    /// should land on the best object rather than open with it.
    static func isAnnualVolume(_ index: Int) -> Bool {
        index % seasonsPerYear == seasonsPerYear - 1
    }

    static func variantID(forSeasonIndex index: Int) -> String {
        isAnnualVolume(index)
            ? PhysicalBookVariant.id(for: .linenWrap)
            : PhysicalBookVariant.id(for: .perfectBound)
    }
}

/// The day a volume went away to be printed, pressed into the Book as a Page.
///
/// Nothing else in the app makes a purchase part of the story: a receipt
/// screen is a dead end and a shipping notification belongs to a courier. This
/// one is a kept Page: it goes on the shelf with everything else and turns up
/// again later the way kept pages do. Sending your own year away to be bound is
/// a thing that happened to you, so the Book records it like one.
struct PressedVolumeKeepsake: Codable, Equatable, Identifiable {
    var id: String
    /// What the cover said.
    var coverLine: String
    var bindingName: String
    var pressedAt: Date
    /// Where it went, coarse enough not to keep an address in the archive.
    var destinationRegion: String?
    var copies: Int

    /// The Book, on the day it let something go. Held to
    /// `BookVoice.animismLine`: an object acting, no reassurance, no receipt
    /// vocabulary.
    func line(calendar: Calendar = .current) -> String {
        let copyPhrase: String
        switch copies {
        case ...1: copyPhrase = "It went alone."
        case 2: copyPhrase = "Two of them went. The second one pretended not to be excited."
        default: copyPhrase = "\(copies) of them went, arguing the whole way to the door."
        }
        let where_ = destinationRegion.map { " Bound for \($0)." } ?? ""
        return "I sent \u{201C}\(coverLine)\u{201D} away to be printed: \(bindingName.lowercased()).\(where_) \(copyPhrase) The shelf where it sat is still warm."
    }
}

/// What the Pressing is doing, while it does it.
///
/// The reader used to perform these steps. Now the machine does, and the wait
/// becomes the ceremony: which only works if the stages are **real**. Each one
/// is entered when the actual work starts and left when it finishes, so the
/// stitches never animate against a timer. A ceremony that lies once is never
/// trusted again.
enum PhysicalBookPressStage: String, Codable, Equatable, CaseIterable {
    case idle
    /// Print files being written and sent up.
    case sewing
    /// The job going to the press.
    case sending
    case gone
    case stalled

    /// The Book, narrating its own work. Held to `BookVoice.animismLine`.
    var line: String {
        switch self {
        case .idle: return ""
        case .sewing: return "Stitching. The thread's got opinions about the corners."
        case .sending: return "Handing it over. The parcel's already smug about going."
        case .gone: return "Gone. Out of my hands and into the post, where I can't fuss at it."
        case .stalled: return "Something jammed. I've kept every page: nothing's lost, it just hasn't gone yet."
        }
    }

    var isWorking: Bool { self == .sewing || self == .sending }

    /// How far along the stitches are, 0…1.
    ///
    /// These are positions, not a timeline: the ceremony advances when the
    /// work advances and stops dead when it stops. A stall holds where it got
    /// to rather than completing, because a spine that finishes sewing while
    /// the order is jammed is the animation telling a lie.
    var progress: Double {
        switch self {
        case .idle: return 0
        case .sewing: return 0.45
        case .sending: return 0.85
        case .gone: return 1
        case .stalled: return 0.85
        }
    }
}

/// A door on the dispatch Page. Labels are the Book's, not an interface's -
/// contractions, plain words, no "Manage" or "Options" or "Settings".
enum SeasonalDispatchAction: String, Codable, CaseIterable {
    case rename
    case cover
    case dedication
    case rebind
    case giftCopy
    case address
    case hold
    case release

    /// The name is answered on the Page. The rest open somewhere of their own.
    var isInline: Bool { self == .rename || self == .cover || self == .dedication }

    var label: String {
        switch self {
        case .rename: return "Call it something else"
        case .cover: return "Choose its coat"
        case .dedication: return "Put one line inside"
        case .rebind: return "Bind it differently"
        case .giftCopy: return "Send one to somebody"
        case .address: return "Tell me the door"
        case .hold: return "Hold it a while"
        case .release: return "Send it now"
        }
    }

    /// One line of the Book's own reason for offering the door, shown under the
    /// label. Never instructions: a want, or a fact about an object.
    var aside: String {
        switch self {
        case .rename: return "Your word beats my guess."
        case .cover: return "Your photograph, one of my plates, or my own nosy choice. Included."
        case .dedication: return "This leaf is yours. I keep my paws off it."
        case .rebind: return "Cloth, foil, a cover off your own camera roll."
        case .giftCopy: return "Two copies, one parcel each. The second one gets jealous otherwise."
        case .address: return "The label's blank and it knows it."
        case .hold: return "It'll wait on the shelf. It's good at waiting."
        case .release: return "It's had enough of the shelf."
        }
    }
}

struct MonthlyEditionSection: Identifiable, Codable, Equatable {
    /// Where a section sits in the volume's architecture.
    ///
    /// The edition used to be a flat list of sections grouped by page *type* -
    /// Daily Braids, Souvenirs, Letters, Images, Other Kept Pages. That is how
    /// a filing cabinet is organised, not a book. Placement is what lets the
    /// same material read as a narrative: an opening, a body that argues, and
    /// an appendix that keeps the promise that nothing was lost.
    enum Placement: String, Codable, Equatable {
        /// Before the story starts: the month's name and weather.
        case frontMatter
        /// The narrative body, in the order the volume reads.
        case movement
        /// The complete archive. Never capped, and never pretending to be a
        /// chapter: completeness is a promise, not a movement.
        case backMatter
    }

    var id: String
    var title: String
    var note: String
    var items: [MonthlyEditionItem]
    /// Optional so volumes bound before the restructure still decode; absent
    /// reads as `.movement`, which is what every old section effectively was.
    var placement: Placement? = nil

    var resolvedPlacement: Placement { placement ?? .movement }
}

struct MonthlyEditionItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case page
        case image
        case continuity
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String
    var date: Date?
    var pageType: BookPageType?
    var sourceID: String?
    var mediaAssets: [BookPageMediaAsset]
    var tags: [String]
    /// A coarse, time-of-keeping note printed beneath selected entries: outer
    /// weather and day-part only. No coordinates, Health values, or chart prose.
    /// Optional so every previously bound edition remains decodable.
    var contextNote: String? = nil
}

/// Reads the span at the scale of a physical volume. It stays deliberately
/// evidential: missing days remain missing, counts say "recorded", and private
/// Faculty charts enter only through the reader's existing binding toggle.
enum BoundVolumePublicationMatterBuilder {
    static func make(
        from days: [BookDay],
        facultyEntries: [FacultyEntry] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        startDate: Date,
        endDate: Date,
        includePrivateLifeAlmanac: Bool = false,
        calendar: Calendar = .current
    ) -> BoundVolumePublicationMatter {
        let pages = days
            .flatMap(\.pages)
            .filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        var almanac: [MonthlyEditionItem] = []

        let weatherByDay = Dictionary(grouping: pages.filter {
            !($0.context?.weatherTags ?? []).isEmpty
        }) { page in
            calendar.startOfDay(for: page.createdAt)
        }.mapValues { dayPages in
            Set(dayPages.flatMap { $0.context?.weatherTags ?? [] }.map(humanizedWeatherTag))
        }
        let weatherCounts = weatherByDay.values.reduce(into: [String: Int]()) { counts, tags in
            for tag in tags where !tag.isEmpty { counts[tag, default: 0] += 1 }
        }
        if !weatherByDay.isEmpty {
            let top = ranked(weatherCounts, limit: 4)
                .map { "\($0.key.lowercased()) on \($0.value) \($0.value == 1 ? "day" : "days")" }
            almanac.append(item(
                id: "volume-outer-weather",
                title: "The Sky's Favorite Tricks",
                body: "I caught the outer weather on \(weatherByDay.count) \(weatherByDay.count == 1 ? "day" : "days"): \(naturalList(top)). Blank sky-days stayed blank; I did not dress them up from memory.",
                date: weatherByDay.keys.sorted().first,
                tags: ["bound-volume", "almanac", "outer-weather"]
            ))
        }

        let timedPages = pages.compactMap { page -> (Date, String)? in
            guard let part = page.context?.dayPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nonEmpty else {
                return nil
            }
            return (calendar.startOfDay(for: page.createdAt), part)
        }
        var seenDayParts = Set<String>()
        let dayPartCounts = timedPages.reduce(into: [String: Int]()) { counts, pair in
            let key = "\(pair.0.timeIntervalSinceReferenceDate)|\(pair.1)"
            guard seenDayParts.insert(key).inserted else { return }
            counts[pair.1, default: 0] += 1
        }
        if !dayPartCounts.isEmpty {
            let top = ranked(dayPartCounts, limit: 4)
                .map { "\($0.key) on \($0.value) \($0.value == 1 ? "day" : "days")" }
            almanac.append(item(
                id: "volume-ink-clock",
                title: "When the Ink Came In",
                body: "The kept Pages with a clock-mark arrived \(naturalList(top)). This is the ink's timetable, not yours; a life keeps plenty I never see.",
                date: timedPages.map(\.0).sorted().first,
                tags: ["bound-volume", "almanac", "day-part"]
            ))
        }

        if includePrivateLifeAlmanac {
            let privateEntries = facultyEntries
                .filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
                .sorted { $0.createdAt < $1.createdAt }
            let inner = privateEntries.filter { $0.kind == .innerWeather }
            if !inner.isEmpty {
                let innerDays = Set(inner.map { calendar.startOfDay(for: $0.createdAt) }).count
                let windows = Dictionary(grouping: inner, by: { $0.windowName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
                    .mapValues(\.count)
                let usual = ranked(windows, limit: 3)
                    .map { "\($0.key) (\($0.value))" }
                let windowLine = usual.isEmpty ? "" : " The chart opened most often at \(naturalList(usual))."
                almanac.append(item(
                    id: "volume-inner-weather",
                    title: "Inkrest's Weather Jar",
                    body: "Dr. Inkrest kept \(inner.count) inner-weather \(inner.count == 1 ? "note" : "notes") across \(innerDays) \(innerDays == 1 ? "day" : "days").\(windowLine) I counted the visits; I did not turn them into a diagnosis wearing a paper crown.",
                    date: inner.first?.createdAt,
                    tags: ["bound-volume", "almanac", "private-weather"]
                ))
            }

            let fuel = privateEntries.filter { $0.kind == .fuel }
            let recordedFoods = recordedFuelCounts(from: fuel)
            if let drink = ranked(recordedFoods.drinks, limit: 1).first {
                almanac.append(item(
                    id: "volume-returning-cup",
                    title: "The Cup That Kept Coming Back",
                    body: "\(drink.key.capitalized) appeared in Vellum's chart \(drink.value) \(drink.value == 1 ? "time" : "times"). Most often written, not necessarily most drunk; the chart only knows what reached it.",
                    date: fuel.first?.createdAt,
                    tags: ["bound-volume", "almanac", "fuel", "drink"]
                ))
            }
            if let food = ranked(recordedFoods.foods, limit: 1).first {
                almanac.append(item(
                    id: "volume-returning-plate",
                    title: "What Vellum Saw Most Often",
                    body: "\(food.key.capitalized) appeared in Vellum's chart \(food.value) \(food.value == 1 ? "time" : "times"). That makes it the most often recorded food in these leaves, not a verdict about how you eat.",
                    date: fuel.first?.createdAt,
                    tags: ["bound-volume", "almanac", "fuel", "food"]
                ))
            }
        }

        let crossings = storyConsequences
            .filter { $0.createdAt >= startDate && $0.createdAt <= endDate && !$0.editionLines.isEmpty }
            .sorted {
                if $0.significance == $1.significance { return $0.createdAt < $1.createdAt }
                return $0.significance > $1.significance
            }
            .prefix(10)
            .flatMap { receipt in
                receipt.editionLines.prefix(2).enumerated().map { offset, line in
                    item(
                        id: "volume-crossing-\(receipt.id)-\(offset)",
                        title: receipt.significance == .rupture ? "A Door Changed Its Mind" : "Across the Hedge",
                        body: line,
                        date: receipt.createdAt,
                        sourceID: receipt.id,
                        tags: ["bound-volume", "story-consequence", "receipt:\(receipt.id)"]
                    )
                }
            }

        let proofLine: String
        if let drink = almanac.first(where: { $0.id == "volume-returning-cup" }) {
            proofLine = "Vellum has already put this inside: \(drink.body)"
        } else if let weather = almanac.first(where: { $0.id == "volume-outer-weather" }) {
            proofLine = "The almanac has already put this inside: \(weather.body)"
        } else if let crossing = crossings.first {
            proofLine = "One of your Pages crossed the hedge and left this behind: \(crossing.body)"
        } else {
            let dayCount = Set(pages.map { calendar.startOfDay(for: $0.createdAt) }).count
            proofLine = "I found \(pages.count) kept \(pages.count == 1 ? "Page" : "Pages") across \(dayCount) \(dayCount == 1 ? "day" : "days"), and gave the span its own front leaves."
        }

        return BoundVolumePublicationMatter(
            almanacItems: almanac,
            crossingItems: Array(crossings),
            proofLine: proofLine
        )
    }

    private static func item(
        id: String,
        title: String,
        body: String,
        date: Date?,
        sourceID: String? = nil,
        tags: [String]
    ) -> MonthlyEditionItem {
        MonthlyEditionItem(
            id: id,
            kind: .continuity,
            title: title,
            body: body,
            date: date,
            pageType: nil,
            sourceID: sourceID,
            mediaAssets: [],
            tags: tags
        )
    }

    private static func ranked(_ counts: [String: Int], limit: Int) -> [(key: String, value: Int)] {
        Array(counts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }.prefix(limit))
    }

    private static func humanizedWeatherTag(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "weather-", with: "")
            .replacingOccurrences(of: "weather:", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func naturalList(_ values: [String]) -> String {
        switch values.count {
        case 0: return "nothing I can honestly count"
        case 1: return values[0]
        case 2: return "\(values[0]) and \(values[1])"
        default: return values.dropLast().joined(separator: ", ") + ", and " + (values.last ?? "")
        }
    }

    private static func recordedFuelCounts(from entries: [FacultyEntry]) -> (foods: [String: Int], drinks: [String: Int]) {
        let drinkWords = [
            "water", "coffee", "tea", "latte", "espresso", "milk", "juice", "cider",
            "beer", "wine", "kombucha", "soda", "seltzer", "smoothie", "cocoa"
        ]
        var foods: [String: Int] = [:]
        var drinks: [String: Int] = [:]
        for entry in entries {
            let firstChartLine = entry.rawText.components(separatedBy: "\n").first ?? entry.rawText
            for parsed in FuelParser.items(from: firstChartLine) {
                var name = parsed.name.lowercased()
                    .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
                if name.hasSuffix("s"), !name.hasSuffix("ss"), name.count > 4 {
                    name.removeLast()
                }
                guard !name.isEmpty else { continue }
                if drinkWords.contains(where: { word in
                    name == word || name.hasPrefix("\(word) ") || name.hasSuffix(" \(word)")
                }) {
                    drinks[name, default: 0] += 1
                } else {
                    foods[name, default: 0] += 1
                }
            }
        }
        return (foods, drinks)
    }
}

enum MonthlyEditionBuilder {
    /// Tales the reader finished this month, bound whole rather than
    /// summarised. This is the difference the whole Tale Grammar exists for:
    /// an edition that recognises "that happened to me" instead of reporting
    /// how many pages were kept.
    static func taleSection(from tales: [LivingTale]) -> MonthlyEditionSection {
        guard !tales.isEmpty else {
            return MonthlyEditionSection(id: "tales-finished", title: "Tales", note: "", items: [])
        }
        let items = tales.map { tale -> MonthlyEditionItem in
            MonthlyEditionItem(
                id: "tale-\(tale.id)",
                kind: .page,
                title: tale.title.isEmpty ? tale.shape.commonName : tale.title,
                body: TaleBinding.body(for: tale),
                date: tale.closedAt,
                pageType: .taleBound,
                sourceID: "tale-bound",
                mediaAssets: [],
                tags: ["tale-bound", "tale-shape:\(tale.shape.rawValue)"]
            )
        }
        return MonthlyEditionSection(
            id: "tales-finished",
            title: tales.count == 1 ? "The Tale You Were Inside" : "The Tales You Were Inside",
            note: tales.count == 1
                ? "One finished this month. I did not see the shape of it until it was over, which is usually how this goes."
                : "\(tales.count) finished this month. I only ever recognise them on the way out.",
            items: items
        )
    }

    static func previousMonth(
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        facultyEntries: [FacultyEntry] = [],
        readerName: String = "friend",
        now: Date = Date(),
        calendar: Calendar = .current,
        includePrivateWeatherSummary: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = [],
        castActs: [CastActRecord] = []
    ) -> MonthlyEdition {
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let end = calendar.date(byAdding: .second, value: -1, to: currentMonthStart) ?? now
        return edition(
            from: days,
            events: events,
            entityMemories: entityMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            constellations: constellations,
            wagers: wagers,
            themes: themes,
            storyConsequences: storyConsequences,
            facultyEntries: facultyEntries,
            readerName: readerName,
            startDate: start,
            endDate: end,
            generatedAt: now,
            calendar: calendar,
            includePrivateWeatherSummary: includePrivateWeatherSummary,
            academySeason: academySeason,
            boundTales: boundTales,
            castActs: castActs
        )
    }

    /// The annual: a whole year bound as a real book of twelve month-chapters,
    /// each keeping its own theme, foreword, and star chart, wrapped in a
    /// year-level foreword, a table of the year, and a closing. Only months that
    /// kept pages become chapters. Pure-local and deterministic: the same year
    /// always binds the same way.
    static func annual(
        _ year: Int,
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        facultyEntries: [FacultyEntry] = [],
        readerName: String = "friend",
        readerRole: BoundReaderRole? = nil,
        castActs: [CastActRecord] = [],
        includePrivateLifeAlmanac: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnnualEdition {
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let nextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
        let yearEnd = calendar.date(byAdding: .second, value: -1, to: nextYear) ?? now

        // Build a chapter for every month of the year that kept pages.
        var chapters: [MonthlyEdition] = []
        for month in 1...12 {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let monthEnd = calendar.date(byAdding: .second, value: -1, to: nextMonth) else { continue }
            let chapter = edition(
                from: days,
                events: events,
                entityMemories: entityMemories,
                entityBelief: entityBelief,
                pageBelief: pageBelief,
                constellations: constellations,
                wagers: wagers,
                themes: themes,
                storyConsequences: storyConsequences,
                readerName: readerName,
                readerRole: readerRole,
                startDate: monthStart,
                endDate: monthEnd,
                generatedAt: now,
                calendar: calendar,
                includePrivateWeatherSummary: includePrivateLifeAlmanac,
                academySeason: academySeason,
                boundTales: boundTales,
                // Each chapter filters the ledger to its own month, so the
                // hardcover's margins carry the Cast all year rather than
                // falling silent the way the monthly volumes would not.
                castActs: castActs
            )
            if !chapter.isEmpty { chapters.append(chapter) }
        }

        // A year-level reading of the whole span, for the grand foreword.
        let yearDays = BookArchiveExport(days: days, calendar: calendar).days.filter { day in
            day.date >= calendar.startOfDay(for: yearStart) && day.date <= calendar.startOfDay(for: yearEnd)
        }
        let yearPages = yearDays.flatMap(\.pages)
        let yearEvents = events.filter { $0.createdAt >= yearStart && $0.createdAt <= yearEnd }
        let yearMemories = entityMemories.filter { $0.createdAt >= yearStart && $0.createdAt <= yearEnd }
        let yearContinuity = LiteraryContinuityProjector.digest(
            days: yearDays,
            events: yearEvents,
            entityMemories: yearMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            now: now,
            calendar: calendar
        )
        let yearWagers = wagers.filter { wager in
            wager.sealedAt <= yearEnd && (wager.resolvedAt.map { $0 >= yearStart } ?? true)
        }

        let yearShape = BoundSpanShape.read(
            pages: yearPages, tales: boundTales, from: yearStart, to: yearEnd
        )
        let foreword = BookForewordWriter.annualForeword(
            year: year,
            chapters: chapters,
            pageCount: yearPages.count,
            dayCount: yearDays.count,
            continuity: yearContinuity,
            constellations: constellations,
            wagers: yearWagers,
            shape: yearShape,
            calendar: calendar
        )
        let closing = BookForewordWriter.annualClosing(year: year, chapters: chapters)

        return AnnualEdition(
            title: "Book of You: The \(year) Annual",
            subtitle: "\(readerRole?.fullName ?? readerName): a year, bound",
            year: year,
            readerName: readerName,
            generatedAt: now,
            startDate: yearStart,
            endDate: yearEnd,
            dayCount: chapters.reduce(0) { $0 + $1.dayCount },
            pageCount: chapters.reduce(0) { $0 + $1.pageCount },
            foreword: foreword,
            chapters: chapters,
            constellations: constellations,
            wagers: yearWagers,
            closing: closing,
            continuity: yearContinuity,
            memorySpine: AnnualMemorySpine.from(days: yearDays, now: now),
            readerRole: readerRole,
            publicationKind: .annual,
            publicationMatter: BoundVolumePublicationMatterBuilder.make(
                from: days,
                facultyEntries: facultyEntries,
                storyConsequences: storyConsequences,
                startDate: yearStart,
                endDate: yearEnd,
                includePrivateLifeAlmanac: includePrivateLifeAlmanac,
                calendar: calendar
            )
        )
    }

    /// A season, bound: three month-chapters between one pair of covers.
    ///
    /// This is the object the Bound Year membership posts three times a year,
    /// with the annual hardcover as the fourth. It is an `AnnualEdition` because
    /// that type is already "a volume of month-chapters with a foreword and a
    /// closing", the only thing a year has that a season does not is the word
    /// on the cover, and that is now a field.
    ///
    /// **The reader names their own seasons, and only backwards.** If they have
    /// given this stretch a name, the volume wears it. If they have not, the
    /// Book titles it by its months and does not invent a word for a season the
    /// reader has not finished having.
    static func seasonal(
        from days: [BookDay],
        startingMonth: Date,
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        facultyEntries: [FacultyEntry] = [],
        readerName: String = "friend",
        readerRole: BoundReaderRole? = nil,
        castActs: [CastActRecord] = [],
        seasonName: String? = nil,
        monthsPerSeason: Int = 3,
        bindsAnnual: Bool = false,
        includePrivateLifeAlmanac: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnnualEdition {
        let seasonStart = calendar.date(from: calendar.dateComponents([.year, .month], from: startingMonth))
            ?? calendar.startOfDay(for: startingMonth)

        var chapters: [MonthlyEdition] = []
        for offset in 0..<max(1, monthsPerSeason) {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: seasonStart),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let monthEnd = calendar.date(byAdding: .second, value: -1, to: nextMonth) else { continue }
            let chapter = edition(
                from: days,
                events: events,
                entityMemories: entityMemories,
                entityBelief: entityBelief,
                pageBelief: pageBelief,
                constellations: constellations,
                wagers: wagers,
                themes: themes,
                storyConsequences: storyConsequences,
                readerName: readerName,
                readerRole: readerRole,
                startDate: monthStart,
                endDate: monthEnd,
                generatedAt: now,
                calendar: calendar,
                includePrivateWeatherSummary: includePrivateLifeAlmanac,
                academySeason: academySeason,
                boundTales: boundTales,
                castActs: castActs
            )
            if !chapter.isEmpty { chapters.append(chapter) }
        }

        let seasonEnd = calendar.date(byAdding: .month, value: max(1, monthsPerSeason), to: seasonStart)
            .flatMap { calendar.date(byAdding: .second, value: -1, to: $0) } ?? now
        let seasonDays = BookArchiveExport(days: days, calendar: calendar).days.filter { day in
            day.date >= calendar.startOfDay(for: seasonStart) && day.date <= calendar.startOfDay(for: seasonEnd)
        }
        let seasonEvents = events.filter { $0.createdAt >= seasonStart && $0.createdAt <= seasonEnd }
        let seasonMemories = entityMemories.filter { $0.createdAt >= seasonStart && $0.createdAt <= seasonEnd }
        let continuity = LiteraryContinuityProjector.digest(
            days: seasonDays,
            events: seasonEvents,
            entityMemories: seasonMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            now: now,
            calendar: calendar
        )

        let monthsSpan = chapters.map(\.monthName)
        let spanLine = monthsSpan.count > 1
            ? "\(monthsSpan.first ?? "") – \(monthsSpan.last ?? "")"
            : (monthsSpan.first ?? monthTitle(for: seasonStart, calendar: calendar))
        // Precedence, and it matters: the reader's own word always wins. Only
        // if they have not named it does the Book offer one of its own, drawn
        // from the season's evidence, and only if the season gave it something
        // worth offering. Otherwise the months do the titling, which is honest
        // and never presumes.
        let readerNamed = seasonName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let proposal = readerNamed == nil && !bindsAnnual
            ? SeasonTitler.propose(chapters: chapters, constellations: constellations)
            : nil
        let coverLine = readerNamed ?? proposal?.title ?? spanLine
        let chapterWord = chapters.count == 1 ? "one month" : "\(chapters.count) months"

        return AnnualEdition(
            title: "Book of You: \(coverLine)",
            subtitle: "\(readerRole?.fullName ?? readerName): \(bindsAnnual ? "a year" : "a season"), bound",
            year: calendar.component(.year, from: seasonStart),
            readerName: readerName,
            generatedAt: now,
            startDate: seasonStart,
            endDate: seasonEnd,
            dayCount: chapters.reduce(0) { $0 + $1.dayCount },
            pageCount: chapters.reduce(0) { $0 + $1.pageCount },
            foreword: BookForewordWriter.foreword(
                monthTitle: coverLine,
                pages: seasonDays.flatMap(\.pages),
                dayCount: chapters.reduce(0) { $0 + $1.dayCount },
                continuity: continuity,
                constellations: constellations,
                wagers: wagers,
                readerRole: readerRole,
                calendar: calendar
            ),
            chapters: chapters,
            constellations: constellations,
            wagers: wagers,
            closing: bindsAnnual
                ? BookForewordWriter.annualClosing(year: calendar.component(.year, from: seasonStart), chapters: chapters)
                : BookForewordWriter.seasonalClosing(coverLine: coverLine, chapters: chapters),
            continuity: continuity,
            memorySpine: AnnualMemorySpine.from(days: seasonDays, now: now),
            readerRole: readerRole,
            coverLine: coverLine,
            coverSubline: {
                if bindsAnnual { return "the membership year, in \(chapterWord)" }
                if readerNamed != nil { return "the season you named, in \(chapterWord)" }
                if proposal != nil { return "a season I would call this, in \(chapterWord)" }
                return "\(chapterWord), bound"
            }(),
            // Carried so the app can show the reader what the Book chose and
            // why, with a way to overrule it. A title offered with its reason
            // attached is an argument; one offered bare is just an assertion.
            seasonTitleProposal: readerNamed == nil ? proposal : nil,
            readerNamedSeason: readerNamed,
            publicationKind: bindsAnnual ? .annual : .seasonal,
            publicationMatter: BoundVolumePublicationMatterBuilder.make(
                from: days,
                facultyEntries: facultyEntries,
                storyConsequences: storyConsequences,
                startDate: seasonStart,
                endDate: seasonEnd,
                includePrivateLifeAlmanac: includePrivateLifeAlmanac,
                calendar: calendar
            )
        )
    }

    static func edition(
        from days: [BookDay],
        events: [NarrativeEvent] = [],
        entityMemories: [NarrativeEntityMemory] = [],
        entityBelief: [String: Int] = [:],
        pageBelief: [String: Int] = [:],
        constellations: [Constellation] = [],
        wagers: [BookWager] = [],
        themes: [BookTheme] = [],
        storyConsequences: [StoryConsequenceReceipt] = [],
        facultyEntries: [FacultyEntry] = [],
        readerName: String = "friend",
        readerRole: BoundReaderRole? = nil,
        startDate: Date,
        endDate: Date,
        generatedAt: Date = Date(),
        calendar: Calendar = .current,
        includePrivateWeatherSummary: Bool = false,
        academySeason: AcademySeasonEdition.Inputs = AcademySeasonEdition.Inputs(),
        boundTales: [LivingTale] = [],
        castActs: [CastActRecord] = []
    ) -> MonthlyEdition {
        let monthDays = BookArchiveExport(days: days, calendar: calendar).days.filter { day in
            day.date >= calendar.startOfDay(for: startDate) && day.date <= calendar.startOfDay(for: endDate)
        }
        let pages = monthDays.flatMap(\.pages).sorted { $0.createdAt < $1.createdAt }
        let monthEvents = events.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let monthMemories = entityMemories.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let continuity = LiteraryContinuityProjector.digest(
            days: monthDays,
            events: monthEvents,
            entityMemories: monthMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            now: generatedAt,
            calendar: calendar
        )

        let monthKey = BookThemeEngine.monthKey(for: startDate, calendar: calendar)
        let theme = BookThemeEngine.theme(forMonth: monthKey, in: themes)
            ?? BookThemeEngine.theme(
                for: pages,
                digest: continuity,
                constellations: constellations,
                monthKey: monthKey,
                now: generatedAt
            )
        let chapterNumber = chapterNumber(forMonthStarting: startDate, in: days, calendar: calendar)

        // Curate before binding: the month kept everything, but the book is
        // selective. The curator keeps the expressive and authored pages, sips
        // only the strongest of the daily logs, and tells us what it set aside.
        let curated = EditionCurator.curate(pages, now: generatedAt)
        let boundPages = curated.pages
        // Read over every page the month kept, not just the bound ones: a
        // finding may well rest on the mundane logs the curator set aside, and
        // those are exactly the days the reader cannot recall unaided.
        let revelations = BindingRevelations.find(
            pages: pages,
            now: generatedAt,
            calendar: calendar,
            limit: 6
        )
        var passageInputs = BookSourceInputs.empty
        passageInputs.days = monthDays
        passageInputs.continuity = continuity
        passageInputs.themes = theme.map { [$0] } ?? []
        let passageCompass = MeaningfulPassageSelector.rankedSelections(
            pages: boundPages,
            query: MeaningfulPassageSelector.periodQuery(
                pages: boundPages,
                framing: [theme?.name ?? "", theme?.line ?? "", continuity.strongestSignals.prefix(5).map(\.line).joined(separator: " ")]
            ),
            inputs: passageInputs,
            scorer: nil,
            limit: 6,
            maximumAge: 45 * 86_400,
            minimumScore: 14,
            honorPriorUse: false,
            diversifyPageTypes: true,
            now: generatedAt
        )
        let privateWeatherSection = includePrivateWeatherSummary
            ? fuelAndInnerWeatherSection(from: pages, calendar: calendar)
            : MonthlyEditionSection(id: "fuel-and-inner-weather", title: "Fuel & Inner Weather", note: "", items: [])

        let title = "Book of You: \(monthTitle(for: startDate, calendar: calendar))"
        let subtitle = theme?.name ?? "\(dateLine(startDate, calendar: calendar)): \(dateLine(endDate, calendar: calendar))"
        let tales = boundTales.filter { tale in
            guard let closedAt = tale.closedAt else { return false }
            return closedAt >= startDate && closedAt <= endDate
        }
        // The volume reads as a book, not as a filing cabinet: the month is
        // named, the nights tell their story, the Book makes its claims, the
        // world turns around all of it, something ends, and only then does the
        // archive open. Order here is the order on the page.
        let sections = ([
            // What the month was, read from structure. This goes first because
            // it is the only claim in the volume the volume can actually make
            // about itself; everything after it is evidence.
            spanShapeSection(
                pages: boundPages,
                tales: boundTales,
                startDate: startDate,
                endDate: endDate,
                span: spanWord(from: startDate, to: endDate, calendar: calendar)
            ),

            // Front matter: the month's name and weather, before the story.
            themeSection(theme, pages: boundPages),

            // I. How it opened.
            openingSection(from: boundPages, continuity: continuity, setAsideLine: curated.setAsideLine),

            // II. The nightly braids, whole and in order. This is the month's
            //     spine: read end to end it is a story the reader lived without
            //     noticing it was one. The Gemma binding-of-bindings, when there
            //     is one, is the overture to this movement: see `bindingStory`.
            pageSection(
                id: "daily-braids",
                title: "The Nightly Braids",
                note: "Every night of the month, in the order it happened. Read straight through, they are a story you were living without stopping to call it one.",
                pages: boundPages.filter { $0.type == .bookOfYou },
                // Every braid the month produced, whole. A reader who wrote
                // twice in one night should not lose one to an off-by-a-day cap.
                limit: 62
            ),

            // III. What the reader kept in their own words.
            pageSection(
                id: "souvenirs",
                title: "One-Sentence Souvenirs",
                note: "Small bright fragments, preserved before the month could blur them.",
                pages: boundPages.filter { $0.type == .souvenir },
                limit: 40
            ),
            scrapbookSection(from: boundPages),
            pageSection(
                id: "letters",
                title: "Letters And Voices",
                note: "Correspondence, gossip, story pages, and faculty notes that spoke back.",
                pages: boundPages.filter { [.letter, .narrativeOS, .bookConnections, .gossip, .facultyResearch, .supportGuild, .bookNotices].contains($0.type) },
                limit: 36
            ),
            imageSection(from: boundPages),
            voiceSection(from: boundPages),

            // IV. What the Book noticed: its own claims, with receipts.
            revelationsSection(from: revelations),
            memorySpineSection(from: monthDays, generatedAt: generatedAt),
            privateWeatherSection,

            // V. The world that turned around it.
            worldEventSection(from: boundPages),
            fictionalConsequenceSection(
                from: storyConsequences.filter {
                    $0.createdAt >= startDate && $0.createdAt <= endDate
                }
            )
        ]
            // V(b). What the Cast did. The Academy's own conduct this month,
            //       quoted from the ledger rather than summarised: these are
            //       the sentences that actually reached the page.
            + [castSection(from: castActs, start: startDate, end: endDate)]
            // VI. What finished. A volume should not open with its endings, so
            //     the tales that closed this month land here, as the resolution
            //     rather than the headline.
            + [taleSection(from: tales)]
            // The Academy's own history, bound beside the reader's. Absent
            // entirely when the world had a quiet month.
            + [
                AcademySeasonEdition.section(
                    for: academySeason,
                    start: startDate,
                    end: endDate,
                    now: generatedAt
                )
            ].compactMap { $0 })
            .map { section -> MonthlyEditionSection in
                var section = section
                if section.placement == nil {
                    section.placement = section.id == "the-months-theme" ? .frontMatter : .movement
                }
                return section
            }
            // Back matter: everything else the reader kept, entire. This is
            // the appendix, and it is the only section with no ceiling: the cap
            // it used to carry silently dropped pages out of heavy months, and
            // "nothing you kept is ever lost" has to be true or it is not a
            // promise.
            + [
                pageSection(
                    id: "other-kept-pages",
                    title: "The Complete Archive",
                    note: "Everything else the month kept: weather, anchors, enchantments, classes, questions, and every other margin. Nothing here was left out.",
                    pages: boundPages.filter { page in
                        !EditionCurator.isScrapbookPage(page)
                            && ![.bookOfYou, .souvenir, .letter, .narrativeOS, .bookConnections, .gossip, .facultyResearch, .supportGuild, .bookNotices, .illuminatedPhoto, .illustration, .enchantment].contains(page.type)
                    },
                    limit: nil,
                    placement: .backMatter
                )
            ]

        let orderedSections = sections.filter { !$0.items.isEmpty }

        return MonthlyEdition(
            title: title,
            subtitle: subtitle,
            generatedAt: generatedAt,
            startDate: startDate,
            endDate: endDate,
            dayCount: monthDays.count,
            pageCount: boundPages.count,
            readerName: readerName,
            chapterNumber: chapterNumber,
            monthName: monthTitle(for: startDate, calendar: calendar),
            theme: theme,
            constellations: constellations,
            foreword: BookForewordWriter.foreword(
                monthTitle: monthTitle(for: startDate, calendar: calendar),
                pages: boundPages,
                dayCount: monthDays.count,
                continuity: continuity,
                constellations: constellations,
                wagers: wagers.filter { wager in
                    wager.sealedAt <= endDate && (wager.resolvedAt.map { $0 >= startDate } ?? true)
                },
                revelations: revelations,
                readerRole: readerRole,
                calendar: calendar
            ),
            sections: orderedSections,
            continuity: continuity,
            howYouSee: {
                guard endDate >= generatedAt.addingTimeInterval(-30 * 86_400) else { return nil }
                return HowYouSee.receipt(days: days, now: generatedAt)
            }(),
            closing: BookForewordWriter.closing(
                monthTitle: monthTitle(for: startDate, calendar: calendar),
                pages: boundPages,
                dayCount: monthDays.count,
                continuity: continuity,
                constellations: constellations,
                theme: theme,
                revelations: revelations,
                readerRole: readerRole,
                calendar: calendar
            ),
            passageCompass: passageCompass,
            readerRole: readerRole,
            marginalia: {
                let notes = CastMarginalia.notes(acts: castActs, start: startDate, end: endDate)
                return notes.isEmpty ? nil : notes
            }(),
            castLead: CastMarginalia.lead(acts: castActs, start: startDate, end: endDate),
            publicationMatter: BoundVolumePublicationMatterBuilder.make(
                from: monthDays,
                facultyEntries: facultyEntries,
                storyConsequences: storyConsequences,
                startDate: startDate,
                endDate: endDate,
                includePrivateLifeAlmanac: includePrivateWeatherSummary,
                calendar: calendar
            ),
            publicationKind: .monthly
        )
    }

    private static func fictionalConsequenceSection(
        from receipts: [StoryConsequenceReceipt]
    ) -> MonthlyEditionSection {
        let meaningful = receipts
            .filter { !$0.editionLines.isEmpty }
            .sorted { left, right in
                if left.significance == right.significance {
                    return left.createdAt > right.createdAt
                }
                return left.significance > right.significance
            }
            .prefix(12)
            .sorted { $0.createdAt < $1.createdAt }
        guard !meaningful.isEmpty else {
            return MonthlyEditionSection(
                id: "fictional-consequences",
                title: "What The Story Changed",
                note: "",
                items: []
            )
        }
        let entityNames = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.entities.map { ($0.id, $0.name) })
        let items = meaningful.map { receipt in
            let names = receipt.characterIDs.prefix(3).map { entityNames[$0] ?? $0 }
            let title: String
            if receipt.significance == .rupture {
                title = names.isEmpty ? "A Road Closed" : "\(names.joined(separator: " & ")): A Road Closed"
            } else if receipt.isRepair {
                title = names.isEmpty ? "A Relationship Turned" : "\(names.joined(separator: " & ")): A Relationship Turned"
            } else {
                title = names.isEmpty ? "The Story Changed" : names.joined(separator: " & ")
            }
            return MonthlyEditionItem(
                id: "edition-\(receipt.id)",
                kind: .continuity,
                title: title,
                body: receipt.editionLines.joined(separator: "\n"),
                date: receipt.createdAt,
                pageType: receipt.sourcePageType,
                sourceID: "fictional-consequence-compiler",
                mediaAssets: [],
                tags: ["monthly-edition", "fictional-consequence"] + receipt.eventTags
            )
        }
        return MonthlyEditionSection(
            id: "fictional-consequences",
            title: "What The Story Changed",
            note: "Consequences that survived their original scene and became part of my history.",
            items: items
        )
    }

    private static func memorySpineSection(from days: [BookDay], generatedAt: Date) -> MonthlyEditionSection {
        let digest = BindingMemorySpine.digest(days: days, now: generatedAt, limit: 31)
        guard !digest.braids.isEmpty else {
            return MonthlyEditionSection(id: "book-memory-spine", title: "Book Memory Spine", note: "", items: [])
        }

        var items: [MonthlyEditionItem] = []
        if let lead = digest.braids.first {
            items.append(MonthlyEditionItem(
                id: "memory-spine-cover-story",
                kind: .continuity,
                title: "Cover Story",
                body: cleanedBookText("\(lead.residue.title)\n\n\(lead.residue.callbackCandidate ?? lead.residue.keptLine)"),
                date: lead.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "cover-story"]
            ))
        }

        if !digest.motifCounts.isEmpty {
            let motifs = digest.motifCounts.prefix(8).map { "\($0.motif) (\($0.count))" }
            items.append(MonthlyEditionItem(
                id: "memory-spine-refrain",
                kind: .continuity,
                title: "The Month's Refrain",
                body: "Across the nightly braids, these motifs kept returning: \(naturalList(Array(motifs))).",
                date: digest.braids.first?.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "motifs"]
            ))
        }

        let callbacks = digest.braids
            .compactMap { memory -> String? in
                guard let callback = memory.residue.callbackCandidate?.nonEmpty else { return nil }
                return "\(memory.residue.title): \(callback)"
            }
            .prefix(6)
        if !callbacks.isEmpty {
            items.append(MonthlyEditionItem(
                id: "memory-spine-callbacks",
                kind: .continuity,
                title: "Pages That Kept Answering",
                body: callbacks.joined(separator: "\n"),
                date: digest.braids.first?.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "callbacks"]
            ))
        }

        let questions = digest.braids
            .compactMap(\.residue.openedQuestion)
            .prefix(4)
        if !questions.isEmpty {
            items.append(MonthlyEditionItem(
                id: "memory-spine-open-questions",
                kind: .continuity,
                title: "Questions Still Warm",
                body: questions.joined(separator: "\n"),
                date: digest.braids.first?.date,
                pageType: .bookOfYou,
                sourceID: BookPageSourceRegistry.source(for: .bookOfYou).id,
                mediaAssets: [],
                tags: ["monthly-edition", "book-memory-spine", "questions"]
            ))
        }

        return MonthlyEditionSection(
            id: "book-memory-spine",
            title: "Book Memory Spine",
            note: "The nightly Book of You pages, read as callbacks, refrains, and open questions.",
            items: items
        )
    }

    /// Chapter N = this month's position among all months that have kept
    /// pages, so the bound volumes read as a continuing book.
    private static func chapterNumber(forMonthStarting startDate: Date, in days: [BookDay], calendar: Calendar) -> Int {
        let editionKey = BookThemeEngine.monthKey(for: startDate, calendar: calendar)
        let monthKeys = Set(
            days.filter { !$0.pages.isEmpty }
                .map { BookThemeEngine.monthKey(for: $0.date, calendar: calendar) }
        )
        .union([editionKey])
        .sorted()
        return (monthKeys.firstIndex(of: editionKey) ?? 0) + 1
    }

    /// What the reader would call this stretch of time.
    ///
    /// One builder makes every rung — the caller supplies the dates — so the
    /// span has to be read off the range rather than named at the call site,
    /// or an annual hardcover opens by telling you what "this month" was.
    static func spanWord(from start: Date, to end: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        switch days {
        case ..<11: return "week"
        case ..<46: return "month"
        case ..<130: return "season"
        default: return "year"
        }
    }

    /// What the volume says this span was.
    ///
    /// The first thing in the book, and the only part of it composed from
    /// structure rather than from reprinted prose. Thirty nightly pages cannot
    /// say what a month was by being adjacent to each other; this can, because
    /// the braids recorded which beats they carried and the tales recorded
    /// what opened and closed.
    ///
    /// It names a tale only when one actually bound, because a bound tale's
    /// title came out of the reader's own words. A shape still running is
    /// reported and never named - the same law the nightly page is held to,
    /// applied at the scale where over-claiming would be worst.
    private static func spanShapeSection(
        pages: [BookPage],
        tales: [LivingTale],
        startDate: Date,
        endDate: Date,
        span: String
    ) -> MonthlyEditionSection {
        let reading = BoundSpanShape.read(
            pages: pages, tales: tales, from: startDate, to: endDate
        )
        // A span with nothing in it is not a book, and saying "nothing here
        // arranged itself into a story" about a span with no pages at all
        // would be the Book talking to itself. The quiet register is for a
        // month the reader lived and did not make a plot out of - not for an
        // empty one.
        guard !pages.isEmpty else {
            return MonthlyEditionSection(
                id: "what-this-was", title: "", note: "", items: [], placement: .frontMatter
            )
        }
        let body = BoundSpanShape.colophon(for: reading, span: span)
        return MonthlyEditionSection(
            id: "what-this-was",
            title: "What This \(span.capitalized) Was",
            note: "",
            items: [
                MonthlyEditionItem(
                    id: "what-this-was-\(span)",
                    kind: .continuity,
                    title: "",
                    body: cleanedBookText(body),
                    date: nil,
                    pageType: nil,
                    sourceID: nil,
                    mediaAssets: [],
                    tags: ["span-shape"] + reading.beats.map { "beat:\($0.beat.rawValue)" }
                )
            ],
            placement: .frontMatter
        )
    }

    private static func themeSection(_ theme: BookTheme?, pages: [BookPage]) -> MonthlyEditionSection {
        guard let theme else {
            return MonthlyEditionSection(id: "the-months-theme", title: "The Month's Theme", note: "", items: [])
        }
        var items: [MonthlyEditionItem] = [
            MonthlyEditionItem(
                id: theme.id,
                kind: .continuity,
                title: theme.name,
                body: cleanedBookText("\(theme.line)\n\n\(theme.stabilityDetail)"),
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["theme"] + theme.motifs
            )
        ]
        for (index, excerpt) in theme.excerptLines.enumerated() {
            let cleaned = cleanedBookText(excerpt)
            guard isUsableThemeExcerpt(cleaned) else { continue }
            items.append(MonthlyEditionItem(
                id: "\(theme.id)-excerpt-\(index)",
                kind: .continuity,
                title: "From the pages",
                body: "\u{201C}\(cleaned)\u{201D}",
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["theme-excerpt"]
            ))
        }
        return MonthlyEditionSection(
            id: "the-months-theme",
            title: "The Month's Theme",
            note: theme.isStable
                ? "One current I found running under the month, named and held up to the light."
                : "One early current I found running under the month, still marked provisional.",
            items: items
        )
    }

    private static func openingSection(
        from pages: [BookPage],
        continuity: LiteraryContinuityDigest,
        setAsideLine: String? = nil
    ) -> MonthlyEditionSection {
        var items: [MonthlyEditionItem] = []
        let typeCounts = Dictionary(grouping: pages, by: \.type).mapValues(\.count)
        let strongest = typeCounts.sorted { left, right in
            if left.value == right.value { return left.key.title < right.key.title }
            return left.value > right.value
        }.prefix(5)
        if !strongest.isEmpty {
            items.append(MonthlyEditionItem(
                id: "month-shape",
                kind: .continuity,
                title: "Shape Of The Month",
                body: strongest.map { "\($0.key.title): \($0.value)" }.joined(separator: "\n"),
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "shape"]
            ))
        }
        let signals = continuity.strongestSignals
        let patternSignals = signals.filter { $0.kind == .pattern }
        if !patternSignals.isEmpty {
            items.append(MonthlyEditionItem(
                id: "returning-language",
                kind: .continuity,
                title: "Returning Language",
                body: returningLanguageLine(from: patternSignals),
                date: patternSignals.map(\.lastSeenAt).max(),
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "language", "pattern"]
            ))
        }
        for signal in signals.filter({ $0.kind != .pattern }).prefix(5) {
            items.append(MonthlyEditionItem(
                id: signal.id,
                kind: .continuity,
                title: signal.subjectName,
                body: monthlySignalLine(signal),
                date: signal.lastSeenAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: signal.tags
            ))
        }
        if let setAsideLine {
            items.append(MonthlyEditionItem(
                id: "kept-not-bound",
                kind: .continuity,
                title: "Kept, Not Bound",
                body: setAsideLine,
                date: nil,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "curation"]
            ))
        }
        return MonthlyEditionSection(
            id: "the-book-notices",
            title: "What I Noticed",
            note: "Connections, absences, durations, and living Beliefs gathered from the month.",
            items: items
        )
    }

    private static func returningLanguageLine(from signals: [LiteraryContinuitySignal]) -> String {
        let names = signals.prefix(6).map(\.subjectName)
        let motifLine = naturalList(names)
        let recentNames = signals
            .filter { $0.tags.contains("recent-events") }
            .prefix(3)
            .map(\.subjectName)
        let recentLine = recentNames.isEmpty
            ? ""
            : " \(naturalList(recentNames)) also crossed into recent events."
        return "Certain words kept finding their way back: \(motifLine). I treat them as motifs and atmosphere, not as a scorecard.\(recentLine)"
    }

    private static func monthlySignalLine(_ signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .absence:
            return signal.line
        case .duration:
            return signal.line
        case .beliefLifecycle:
            return signal.line
        case .pattern:
            return signal.line
        case .listening:
            return signal.line
        case .sensory:
            return signal.line
        case .manner:
            return signal.line
        }
    }

    private static func fuelAndInnerWeatherSection(from pages: [BookPage], calendar: Calendar) -> MonthlyEditionSection {
        let privatePages = pages
            .filter { $0.type == .fuel || $0.type == .body }
            .sorted { $0.createdAt < $1.createdAt }
        guard !privatePages.isEmpty else {
            return MonthlyEditionSection(id: "fuel-and-inner-weather", title: "Fuel & Inner Weather", note: "", items: [])
        }

        let fuelCount = privatePages.filter { $0.type == .fuel }.count
        let bodyCount = privatePages.filter { $0.type == .body }.count
        let dayCount = Set(privatePages.map { calendar.startOfDay(for: $0.createdAt) }).count
        let days = dayCount == 1 ? "one day" : "\(dayCount) days"
        let counts = [
            fuelCount > 0 ? "\(fuelCount == 1 ? "one fuel note" : "\(fuelCount) fuel notes")" : nil,
            bodyCount > 0 ? "\(bodyCount == 1 ? "one inner-weather note" : "\(bodyCount) inner-weather notes")" : nil
        ].compactMap { $0 }

        var items: [MonthlyEditionItem] = [
            MonthlyEditionItem(
                id: "fuel-weather-overview",
                kind: .continuity,
                title: "Private Weather, Summarized",
                body: "You opened the private drawer, so I counted \(naturalList(counts)) across \(days). These are clues about how the month moved through appetite, energy, body, and mood. Pattern-weather. No diagnosis wearing a paper crown.",
                date: privatePages.first?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather"]
            )
        ]

        let timePatterns = timeOfDayPatterns(from: privatePages, calendar: calendar)
        if !timePatterns.isEmpty {
            items.append(MonthlyEditionItem(
                id: "fuel-weather-time-patterns",
                kind: .continuity,
                title: "When It Appeared",
                body: timePatterns,
                date: privatePages.last?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather", "pattern"]
            ))
        }

        let motifLine = privateWeatherMotifs(from: privatePages)
        if !motifLine.isEmpty {
            items.append(MonthlyEditionItem(
                id: "fuel-weather-motifs",
                kind: .continuity,
                title: "Words That Carried Weight",
                body: motifLine,
                date: privatePages.last?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather", "language"]
            ))
        }

        let pairedDays = pairedFuelWeatherDays(from: privatePages, calendar: calendar)
        if pairedDays > 0 {
            let line = pairedDays == 1
                ? "On one day, fuel and inner weather found each other in my margins. I pinned the overlap down. It is weather, not diagnosis, and not proof of cause."
                : "On \(pairedDays) days, fuel and inner weather found each other in my margins. I pinned the overlaps down. They are weather, not diagnosis, and not proof of cause."
            items.append(MonthlyEditionItem(
                id: "fuel-weather-overlaps",
                kind: .continuity,
                title: "Where They Touched",
                body: line,
                date: privatePages.last?.createdAt,
                pageType: nil,
                sourceID: nil,
                mediaAssets: [],
                tags: ["monthly-edition", "private-weather", "connection"]
            ))
        }

        return MonthlyEditionSection(
            id: "fuel-and-inner-weather",
            title: "Fuel & Inner Weather",
            note: "An opt-in private summary of body, fuel, mood, and energy patterns. No raw logs, no medical claims.",
            items: items
        )
    }

    private static func timeOfDayPatterns(from pages: [BookPage], calendar: Calendar) -> String {
        let buckets = Dictionary(grouping: pages) { page -> String in
            let hour = calendar.component(.hour, from: page.createdAt)
            switch hour {
            case 5..<12: return "morning"
            case 12..<17: return "afternoon"
            case 17..<22: return "evening"
            default: return "night"
            }
        }
        let parts = buckets
            .sorted { left, right in
                if left.value.count == right.value.count { return left.key < right.key }
                return left.value.count > right.value.count
            }
            .prefix(2)
            .map { "\($0.key) (\($0.value.count))" }
        guard !parts.isEmpty else { return "" }
        return "These notes gathered most often around \(naturalList(Array(parts))). The timing may be ordinary logistics; I only mark where attention kept landing."
    }

    private static func privateWeatherMotifs(from pages: [BookPage]) -> String {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "because", "been", "being", "body", "could",
            "day", "did", "does", "dont", "down", "feel", "felt", "fuel", "have", "into",
            "just", "like", "little", "more", "much", "note", "only", "really", "some",
            "still", "that", "the", "then", "there", "this", "today", "very", "was",
            "were", "what", "when", "with", "would", "your"
        ]
        let text = pages
            .map { cleanedBookText($0.userInput.isEmpty ? $0.promptText : $0.userInput).lowercased() }
            .joined(separator: " ")
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 && !stopWords.contains($0) && Int($0) == nil }
        let counts = Dictionary(grouping: words, by: { $0 }).mapValues(\.count)
        let motifs = counts
            .filter { $0.value >= 2 }
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .prefix(5)
            .map(\.key)
        guard !motifs.isEmpty else { return "" }
        return "A few words kept weight in the private weather: \(naturalList(Array(motifs))). I'd read them as invitations to notice conditions, not verdicts about you."
    }

    private static func pairedFuelWeatherDays(from pages: [BookPage], calendar: Calendar) -> Int {
        let byDay = Dictionary(grouping: pages) { calendar.startOfDay(for: $0.createdAt) }
        return byDay.values.filter { group in
            group.contains { $0.type == .fuel } && group.contains { $0.type == .body }
        }.count
    }

    private static func naturalList(_ values: [String]) -> String {
        let cleaned = values.filter { !$0.isEmpty }
        switch cleaned.count {
        case 0:
            return "a few quiet motifs"
        case 1:
            return cleaned[0]
        case 2:
            return "\(cleaned[0]) and \(cleaned[1])"
        default:
            return "\(cleaned.dropLast().joined(separator: ", ")), and \(cleaned.last ?? "")"
        }
    }

    private static func worldEventSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let eventPages = pages.filter { page in
            page.tags.contains("world-event") || page.tags.contains { $0.hasPrefix("event:") }
        }
        guard !eventPages.isEmpty else {
            return MonthlyEditionSection(id: "world-events", title: "World Events", note: "", items: [])
        }
        let eventIDs = eventPages
            .flatMap { page in page.tags.compactMap { $0.hasPrefix("event:") ? String($0.dropFirst("event:".count)) : nil } }
        let counts = Dictionary(grouping: eventIDs, by: { $0 }).mapValues(\.count)
        var summaryLines = counts
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .map { "\($0.key.replacingOccurrences(of: "-", with: " ").capitalized): \($0.value) kept page\($0.value == 1 ? "" : "s")" }
        let outcomeIDs = eventPages
            .flatMap { page in page.tags.compactMap { $0.hasPrefix("event-outcome:") ? String($0.dropFirst("event-outcome:".count)) : nil } }
        if let strongestOutcome = Dictionary(grouping: outcomeIDs, by: { $0 }).mapValues(\.count)
            .sorted(by: { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            })
            .first {
            summaryLines.append("Strongest outcome: \(strongestOutcome.key.replacingOccurrences(of: "-", with: " ").capitalized)")
        }
        let summary = summaryLines.joined(separator: "\n")
        let item = MonthlyEditionItem(
            id: "world-events-summary",
            kind: .continuity,
            title: "Temporary Physics",
            body: summary.isEmpty ? "A world event touched the month and left traces in the kept pages." : summary,
            date: eventPages.map(\.createdAt).min(),
            pageType: nil,
            sourceID: nil,
            mediaAssets: [],
            tags: ["world-event", "monthly-edition"]
        )
        return MonthlyEditionSection(
            id: "world-events",
            title: "World Events",
            note: "The weeks when my rules changed and the pages learned to behave differently.",
            items: [item] + eventPages.prefix(10).map(pageItem)
        )
    }

    /// What the Book noticed that the reader could not. Bound near the front,
    /// before the pages themselves: the findings are the argument, and the
    /// pages that follow are the evidence for it.
    private static func revelationsSection(
        from revelations: [BindingRevelations.Revelation]
    ) -> MonthlyEditionSection {
        guard !revelations.isEmpty else {
            return MonthlyEditionSection(id: "what-i-noticed", title: "What I Noticed", note: "", items: [])
        }
        return MonthlyEditionSection(
            id: "what-i-noticed",
            title: "What I Noticed",
            note: "Connections that only show up when a whole month is held still at once.",
            items: revelations.map { revelation in
                var body = revelation.body
                if !revelation.evidence.isEmpty {
                    let quoted = revelation.evidence
                        .map { item in
                            let day = item.date.formatted(.dateTime.month(.abbreviated).day())
                            return "\(day): \u{201C}\(item.excerpt)\u{201D}"
                        }
                        .joined(separator: "\n")
                    body += "\n\n\(quoted)"
                }
                return MonthlyEditionItem(
                    id: "revelation-\(revelation.id)",
                    kind: .continuity,
                    title: revelation.title,
                    body: body,
                    date: revelation.evidence.first?.date,
                    pageType: nil,
                    sourceID: "binding-revelations",
                    mediaAssets: [],
                    tags: ["revelation", revelation.kind.rawValue]
                )
            }
        )
    }

    /// What the Academy did to each other this month, in the order it happened.
    ///
    /// Every `CastActRecord` already keeps the exact sentence that reached the
    /// page, specifically so it can be quoted rather than paraphrased. Nothing
    /// here is generated: the volume is reporting conduct, and conduct is a
    /// claim about a character, so it is quoted or it is not printed.
    private static func castSection(
        from acts: [CastActRecord],
        start: Date,
        end: Date
    ) -> MonthlyEditionSection {
        let window = acts
            .filter { $0.occurredAt >= start && $0.occurredAt <= end }
            .filter { !$0.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { left, right in
                if left.occurredAt == right.occurredAt { return left.id < right.id }
                return left.occurredAt < right.occurredAt
            }
        return MonthlyEditionSection(
            id: "what-the-cast-did",
            title: "What The Cast Did",
            note: "The Academy has its own month, and it does not always behave. Kept here in their own words.",
            items: window.prefix(24).map { record in
                MonthlyEditionItem(
                    id: "cast-act-\(record.id)",
                    kind: .continuity,
                    title: record.actorName,
                    body: record.line,
                    date: record.occurredAt,
                    pageType: nil,
                    sourceID: record.id,
                    mediaAssets: [],
                    tags: record.tags
                )
            },
            placement: .movement
        )
    }

    /// `limit: nil` binds every page. Only the archive appendix may do that -
    /// a movement with no ceiling stops being edited.
    private static func pageSection(
        id: String,
        title: String,
        note: String,
        pages: [BookPage],
        limit: Int?,
        placement: MonthlyEditionSection.Placement = .movement
    ) -> MonthlyEditionSection {
        let bound = limit.map { Array(pages.prefix($0)) } ?? pages
        return MonthlyEditionSection(
            id: id,
            title: title,
            note: note,
            items: bound.map(pageItem),
            placement: placement
        )
    }

    private static func imageSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let imagePages = pages.filter { page in
            !EditionCurator.isScrapbookPage(page)
                && (page.type == .illuminatedPhoto
                    || page.type == .illustration
                    || page.type == .enchantment
                    || hasVisualMedia(page))
        }
        return MonthlyEditionSection(
            id: "images",
            title: "Images And Illuminations",
            note: "Saved plates, enchantments, and image-bearing pages.",
            items: imagePages.prefix(28).map { page in
                var item = pageItem(page)
                item.kind = .image
                return item
            }
        )
    }

    private static func voiceSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let voicePages = pages.filter(\.hasReaderAudioRecording)
        return MonthlyEditionSection(
            id: "voice-notes",
            title: "Voices Kept",
            note: "Recordings stay playable in the living Book. These leaves carry the reader's locally transcribed words, or the honest duration and cadence when words could not be read.",
            items: voicePages.prefix(28).map(pageItem)
        )
    }

    private static func hasVisualMedia(_ page: BookPage) -> Bool {
        page.mediaAssets.contains { $0.kind != .audioFile }
    }

    private static func scrapbookSection(from pages: [BookPage]) -> MonthlyEditionSection {
        let scrapbookPages = pages.filter(EditionCurator.isScrapbookPage)
        return MonthlyEditionSection(
            id: "scrapbook-pages",
            title: "Scrapbook Pages",
            note: "Pages the reader composed by hand from kept scraps, notes, marks, and images.",
            items: scrapbookPages.prefix(12).map { page in
                var item = pageItem(page)
                item.kind = page.mediaAssets.isEmpty ? .page : .image
                item.title = scrapbookTitle(for: page)
                return item
            }
        )
    }

    private static func pageItem(_ page: BookPage) -> MonthlyEditionItem {
        MonthlyEditionItem(
            id: page.id,
            kind: hasVisualMedia(page) ? .image : .page,
            title: EditionCurator.isScrapbookPage(page) ? scrapbookTitle(for: page) : page.bindingDisplayTitle,
            body: pageBody(page),
            date: page.createdAt,
            pageType: page.type,
            sourceID: page.sourceID,
            mediaAssets: page.mediaAssets,
            tags: page.tags,
            contextNote: contextNote(for: page)
        )
    }

    /// A few dated entries keep the day clinging to them. Sampling by stable id
    /// prevents the archive becoming a weather report while making a leaf-through
    /// feel inhabited by the actual hours and sky in which the Pages arrived.
    private static func contextNote(for page: BookPage) -> String? {
        guard let context = page.context,
              ConstellationKeeper.stableIndex(for: "volume-weather-\(page.id)", count: 3) == 0 else {
            return nil
        }
        let weather = context.weatherTags
            .map {
                $0.lowercased()
                    .replacingOccurrences(of: "weather-", with: "")
                    .replacingOccurrences(of: "weather:", with: "")
                    .replacingOccurrences(of: "-", with: " ")
            }
            .filter { !$0.isEmpty }
        guard !weather.isEmpty else { return nil }
        let sky = naturalList(Array(weather.prefix(3)))
        let part = context.dayPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hourLine = part.isEmpty ? "" : " This Page came in during the \(part)."
        return "The sky had \(sky) in its pockets.\(hourLine)"
    }

    private static func pageBody(_ page: BookPage) -> String {
        excerptForMonthlyBinding(cleanedBookText(page.bindingBodyText), pageType: page.type)
    }

    private static func scrapbookTitle(for page: BookPage) -> String {
        let title = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Scrapbook Page" : title
    }

    private static func isUsableThemeExcerpt(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return false }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("research note for") { return false }
        if lowered == "faculty:" || lowered.hasPrefix("faculty: dr.") { return false }
        if lowered.contains("focus:") && lowered.contains("faculty:") { return false }
        return true
    }

    static func cleanedBookText(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                if lines.last?.isEmpty == false { lines.append("") }
                continue
            }
            if line.allSatisfy({ $0 == "*" || $0 == "-" || $0 == "_" }) { continue }
            while line.hasPrefix("#") {
                line.removeFirst()
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                line.removeFirst(2)
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            line = line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "  ", with: " ")
            lines.append(line)
        }
        return lines
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func excerptForMonthlyBinding(_ text: String, pageType: BookPageType) -> String {
        // The nightly braid is the spine of the whole book: the reader's own
        // month, in their own words. An edition that excerpts it is showing them
        // a summary of a summary. Every braid binds whole, however long it ran.
        guard !bindsUnabridged(pageType) else { return text }
        let limit = monthlyExcerptLimit(for: pageType)
        guard text.count > limit else { return text }

        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var chosen: [String] = []
        var count = 0
        for paragraph in paragraphs {
            let nextCount = count + paragraph.count
            if nextCount > limit { break }
            chosen.append(paragraph)
            count = nextCount
            if count >= Int(Double(limit) * 0.65) { break }
        }

        let excerpt: String
        if chosen.isEmpty {
            excerpt = prefixAtWordBoundary(text, limit: limit)
        } else {
            excerpt = chosen.joined(separator: "\n\n")
        }
        return "\(excerpt)\n\n[Excerpted for the monthly binding.]"
    }

    /// Page kinds bound in full, never excerpted.
    private static func bindsUnabridged(_ pageType: BookPageType) -> Bool {
        pageType == .bookOfYou
    }

    private static func monthlyExcerptLimit(for pageType: BookPageType) -> Int {
        switch pageType {
        case .bookOfYou, .letter, .narrativeOS, .bookConnections, .gossip, .bookAside:
            return 1_800
        case .souvenir:
            return 600
        default:
            return 1_100
        }
    }

    private static func prefixAtWordBoundary(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let cutoff = text.index(text.startIndex, offsetBy: limit)
        let prefix = text[..<cutoff]
        if let lastSpace = prefix.lastIndex(where: { $0.isWhitespace }) {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func monthTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private static func dateLine(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// The Book writes its own foreword: what it noticed, what it named, what it
/// wagered and how those wagers went. Deterministic prose - the same month
/// always gets the same foreword.
/// Sentence-cases a phrase assembled lowercase ("all 47 pages" → "All 47
/// pages") without disturbing the rest of it.
private extension String {
    var sentenceCased: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

enum BookForewordWriter {

    /// One month's stable voice-seed. The same month always reads the same way;
    /// two different months never open with the same sentence. Derived from the
    /// month's own shape rather than a counter, so re-binding is idempotent but
    /// January and February cannot collide.
    static func voiceSeed(monthTitle: String, pages: Int, dayCount: Int) -> UInt64 {
        UInt64(bitPattern: Int64("\(monthTitle)|\(pages)|\(dayCount)".stableHash))
    }

    /// A separately-mixed seed for one beat of the piece.
    ///
    /// `ReflectiveProse.pick` reduces `seed &+ salt &* 7_919` modulo the pool
    /// size, so two pools of equal length pick the *same* index for a given
    /// seed: a month that opened on variant 2 would then take variant 2 of its
    /// reason and variant 2 of its sign-off, and three months in six read
    /// identically end to end. Scrambling per beat decorrelates the pools.
    static func beatSeed(_ seed: UInt64, _ beat: Int) -> UInt64 {
        UInt64(bitPattern: Int64((Int(bitPattern: UInt(truncatingIfNeeded: seed)) ^ (beat &* 0x27d4eb2f)).stableScramble))
    }

    static func foreword(
        monthTitle: String,
        pages: [BookPage],
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        wagers: [BookWager],
        revelations: [BindingRevelations.Revelation] = [],
        readerRole: BoundReaderRole? = nil,
        calendar: Calendar = .current
    ) -> String {
        let seed = voiceSeed(monthTitle: monthTitle, pages: pages.count, dayCount: dayCount)
        let pageLine = pages.count == 1 ? "one page" : "\(pages.count) pages"
        let dayLine = dayCount == 1 ? "a single day" : "\(dayCount) days"

        var paragraphs: [String] = []

        // 1. The arrival. A thin month is a different book from a full one, and
        //    should not be greeted with the same sentence. Once the Book has
        //    named the reader it says the name here, in the first line of their
        //    own chapter, because that is the whole point of having named them.
        if let named = readerRole?.fullName {
            if dayCount > 0 && dayCount < 7 {
                paragraphs.append(ReflectiveProse.pick([
                    "A first binding from \(monthTitle), \(named): \(pageLine) across \(dayLine). Not enough month to name the whole weather, but enough to keep what already refused to disappear.",
                    "\(named). \(monthTitle) is barely a month yet: \(pageLine) across \(dayLine). I'm binding it early because small things go missing fastest, and these have already proved they'd rather not.",
                    "A short chapter for \(named): \(pageLine), \(dayLine). I'd rather bind a thin month than let it round down to nothing."
                ], seed: beatSeed(seed, 11), salt: 0))
            } else {
                paragraphs.append(ReflectiveProse.pick([
                    "This is what \(monthTitle) left in my keeping, \(named): \(pageLine) across \(dayLine), each one kept on purpose.",
                    "\(monthTitle), bound for \(named): \(pageLine) across \(dayLine). None of it arrived here by accident: you chose every one.",
                    "Here is \(monthTitle) with its shoes off, \(named). \(pageLine.sentenceCased) across \(dayLine), and not one of them kept itself.",
                    "\(named). \(pageLine.sentenceCased) across \(dayLine). That's what \(monthTitle) handed me, and I haven't thrown any of it away."
                ], seed: beatSeed(seed, 11), salt: 0))
            }
        } else if dayCount > 0 && dayCount < 7 {
            paragraphs.append(ReflectiveProse.pick([
                "This is a first binding from \(monthTitle): \(pageLine) across \(dayLine). Not enough month to name the whole weather, but enough to keep what already refused to disappear.",
                "\(monthTitle) is barely a month yet: \(pageLine) across \(dayLine). I'm binding it early because small things go missing fastest, and these have already proved they'd rather not.",
                "A short chapter: \(pageLine), \(dayLine). I'd rather bind a thin month than let it round down to nothing."
            ], seed: beatSeed(seed, 11), salt: 0))
        } else {
            paragraphs.append(ReflectiveProse.pick([
                "This is what \(monthTitle) left in my keeping: \(pageLine) across \(dayLine), each one kept on purpose.",
                "\(monthTitle), bound: \(pageLine) across \(dayLine). None of it arrived here by accident: you chose every one.",
                "Here is \(monthTitle) with its shoes off. \(pageLine.sentenceCased) across \(dayLine), and not one of them kept itself.",
                "\(pageLine.sentenceCased). \(dayLine.sentenceCased). That's what \(monthTitle) handed me, and I haven't thrown any of it away."
            ], seed: beatSeed(seed, 11), salt: 0))
        }

        // 2. Why the Book binds at all. Said differently every month, because a
        //    reason repeated verbatim stops being a reason.
        paragraphs.append(ReflectiveProse.pick([
            "I don't bind months to flatter them. I bind them because loose pages get lonely, and I don't want any of this to quietly unhappen.",
            "A month that isn't written down doesn't politely wait to be remembered. It goes. That's the entire reason for the thread and the glue.",
            "This isn't a trophy. It's a container. Unbound days leak, and I've watched too many of them do it.",
            "Binding is the least mystical thing I do. It's just refusing to let a month become a rumour."
        ], seed: beatSeed(seed, 17), salt: 0))

        // 3. The strongest thing the Book actually found. A revelation outranks
        //    a continuity signal here: it is the reading the reader could not
        //    have performed on themselves.
        if let sharpest = revelations.first {
            paragraphs.append(ReflectiveProse.pick([
                "Reading it back, I found something you were not in a position to see. \(sharpest.title). \(sharpest.body)",
                "One thing surfaced that I don't think you noticed while you were living it. \(sharpest.title). \(sharpest.body)",
                "Here is what thirty days held still long enough to show me. \(sharpest.title). \(sharpest.body)"
            ], seed: beatSeed(seed, 23), salt: 0))
        } else {
            let signals = continuity.strongestSignals.prefix(3)
            if !signals.isEmpty {
                let lines = signals.map { signal in
                    signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
                }
                let opener = ReflectiveProse.pick([
                    "Reading it back, I noticed things I didn't notice at the time.",
                    "Some of this only became visible once it stopped moving.",
                    "A few shapes showed up in the re-reading that were invisible in the living."
                ], seed: beatSeed(seed, 23), salt: 0)
                let caveat = ReflectiveProse.pick([
                    "None of this is a verdict. It's the shape attention left behind, with its elbows on the table.",
                    "I'm not ruling on any of it. I'm only reporting where the ink pooled.",
                    "The number is weather. Bite it if it's wrong."
                ], seed: beatSeed(seed, 29), salt: 0)
                paragraphs.append("\(opener) \(lines.joined(separator: ". ")). \(caveat)")
            }
        }

        // 3b. The mark, and the receipt for it. A mark is only awarded after
        //     the Book has watched something specific, so the evidence is
        //     printed beside the name. Without it the naming is flattery, and
        //     flattery is the one thing this book is not for.
        if let markName = readerRole?.markName, let evidence = readerRole?.markEvidence {
            paragraphs.append(ReflectiveProse.pick([
                "I've been calling you \(markName) in my own margins. This is the entry that earned it: \(evidence)",
                "\(markName): that's the mark beside your name, and I don't award those on a feeling. \(evidence)",
                "There's a reason I call you \(markName), and it isn't decoration. \(evidence)"
            ], seed: beatSeed(seed, 43), salt: 0))
        }

        // 4. Named threads.
        let named = ConstellationKeeper.namedConstellations(constellations)
        if !named.isEmpty {
            let nameLine = list(named.prefix(3).map(\.displayName))
            paragraphs.append(ReflectiveProse.pick([
                "Some threads have been with us long enough that I've given them names: \(nameLine). A named constellation is a promise with a little lamp inside it.",
                "\(nameLine) have earned names now. I don't hand those out early: a thread has to keep showing up when nobody is asking it to.",
                "The margins are keeping \(nameLine) lit. Naming a thing is how I admit I expect it back."
            ], seed: beatSeed(seed, 31), salt: 0))
        }

        // 5. The wager ledger: the Book's own accuracy, reported against itself.
        let opened = wagers.filter { !$0.isSealed }
        let sealed = wagers.filter(\.isSealed)
        if !opened.isEmpty {
            let right = opened.filter { $0.status == .right }.count
            let wrong = opened.count - right
            if wrong == 0 {
                paragraphs.append(ReflectiveProse.pick([
                    "Every wager I opened this month came true, which made my spine sit up straighter than was dignified.",
                    "I guessed \(right == 1 ? "once" : "\(right) times") this month and was right every time. I'm trying not to make it my whole personality."
                ], seed: beatSeed(seed, 37), salt: 0))
            } else if right == 0 {
                paragraphs.append(ReflectiveProse.pick([
                    "Every wager I opened this month was wrong. I've written each one down anyway. Being wrong in writing is how a book learns without pretending its ink is royal.",
                    "I got all of them wrong. They stay in the ledger. A book that only records its hits is a book you can't trust about anything."
                ], seed: beatSeed(seed, 37), salt: 0))
            } else {
                paragraphs.append(ReflectiveProse.pick([
                    "Of the wagers I opened this month, \(right) came true and \(wrong) did not. I record both with the same ink, because the ink doesn't like favorites.",
                    "\(right) right, \(wrong) wrong. Both halves stay. You should know how often I miss."
                ], seed: beatSeed(seed, 37), salt: 0))
            }
        }
        if !sealed.isEmpty {
            paragraphs.append(sealed.count == 1
                ? "One wager is still sealed in the margins. It's trying very hard not to peek. We will both find out."
                : "\(sealed.count) wagers are still sealed in the margins. They are trying very hard not to peek. We will both find out.")
        }

        // 6. The sign-off. Once the Book has named the reader it closes on the
        //    gloss: the sentence it decided was true of them, so the chapter
        //    ends where the naming started.
        if let role = readerRole {
            paragraphs.append(ReflectiveProse.pick([
                "\(role.gloss) I decided that about you before this month began, and nothing in here argued with me.\n\nThe Book",
                "Whatever else this month was, it got read. \(role.gloss) The evidence for that is bound behind this page.\n\nThe Book",
                "I've read every page of this twice. Once as it arrived, once just now. Both times it read like yours. \(role.gloss)\n\nThe Book",
                "None of it is going anywhere: I've checked the thread myself. \(role.gloss) Still true in \(monthTitle).\n\nThe Book"
            ], seed: beatSeed(seed, 41), salt: 0))
        } else {
            paragraphs.append(ReflectiveProse.pick([
                "Whatever else this month was, it got read. I put a hand flat on it and told it to stay. It stayed.\n\nThe Book",
                "It was a month and I caught it. That's the whole of my claim, and I'm pleased with it.\n\nThe Book",
                "I've read every page of this twice. Once as it arrived, once just now.\n\nThe Book",
                "None of it is going anywhere. I've checked the thread myself.\n\nThe Book"
            ], seed: beatSeed(seed, 41), salt: 0))
        }

        return paragraphs.joined(separator: "\n\n")
    }

    /// The month's conclusion, in the Book's voice. Deterministic and instant -
    /// woven from the same material the foreword opened with, but closed: the
    /// signals that held, the threads that earned names, the theme that insisted.
    /// The app may replace this with a Gemma-written version before binding.
    static func closing(
        monthTitle: String,
        pages: [BookPage],
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        theme: BookTheme?,
        revelations: [BindingRevelations.Revelation] = [],
        readerRole: BoundReaderRole? = nil,
        calendar: Calendar = .current
    ) -> String {
        // Deliberately offset from the foreword's seed: the same month should
        // not open and close on the same rhetorical move.
        let seed = voiceSeed(monthTitle: monthTitle, pages: pages.count, dayCount: dayCount) &+ 7
        var paragraphs: [String] = []

        let pageLine = pages.count == 1 ? "the single page" : "all \(pages.count) pages"
        paragraphs.append(ReflectiveProse.pick([
            "So \(monthTitle) closes. I've read \(pageLine) back to you and to myself, and what could be kept has been kept. A month doesn't end so much as settle.",
            "That's \(monthTitle). \(pageLine.sentenceCased) read back, nothing left loose. The loud parts take off their shoes and what was true underneath stays where I can find it.",
            "\(monthTitle) is finished, which isn't the same as over. I've read \(pageLine) and put them somewhere they can't be argued out of."
        ], seed: beatSeed(seed, 13), salt: 0))

        // The closing takes the *second* revelation where it can, so the book
        // does not end on the note it opened with.
        let closingFinding = revelations.dropFirst().first ?? revelations.first
        if let closingFinding, revelations.count > 1 {
            paragraphs.append(ReflectiveProse.pick([
                "One more thing before I shut the cover. \(closingFinding.title). \(closingFinding.body)",
                "I held this one back for the end. \(closingFinding.title). \(closingFinding.body)",
                "And this, which I only saw once every page was lying flat. \(closingFinding.title). \(closingFinding.body)"
            ], seed: beatSeed(seed, 19), salt: 0))
        } else if let strongest = continuity.strongestSignals.first {
            let line = strongest.line.hasSuffix(".") ? String(strongest.line.dropLast()) : strongest.line
            paragraphs.append(ReflectiveProse.pick([
                "If this chapter leaves one thing in your hands, let it be this: \(line). I will be watching to see whether it holds, or turns, or asks for a different name.",
                "Carry this one out with you: \(line). I like when a true thing knocks twice.",
                "The line I'd keep, if I could only keep one: \(line). We will see whether it survives next month."
            ], seed: beatSeed(seed, 19), salt: 0))
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if let firstNamed = named.first {
            paragraphs.append(ReflectiveProse.pick([
                "\(firstNamed.displayName) is still alight in the margins, and I've left it burning on purpose. A thread I've named doesn't get blown out at the end of a month.",
                "I'm leaving \(firstNamed.displayName) lit. It carries into next month, holding its little breath.",
                "\(firstNamed.displayName) doesn't close with the chapter. Named threads keep their own hours."
            ], seed: beatSeed(seed, 23), salt: 0))
        }

        if let theme, !theme.isStable || (dayCount > 0 && dayCount < 7) {
            paragraphs.append(ReflectiveProse.pick([
                "The early thread this month was \u{201C}\(theme.name)\u{201D}. I'm not calling it the whole sky yet; I'm only saying these words kept tapping the glass, and the glass looked back.",
                "\u{201C}\(theme.name)\u{201D} kept surfacing. Too early to call it the weather. Early enough to write it down."
            ], seed: beatSeed(seed, 29), salt: 0))
        } else if let theme {
            paragraphs.append(ReflectiveProse.pick([
                "The theme this month was \u{201C}\(theme.name)\u{201D}, and it had the last word as often as the first. Whether you chose it or it chose you, it is bound here now, sitting very still so it can't be unsaid.",
                "\u{201C}\(theme.name)\u{201D} ran through the whole month. I've stopped asking whether you picked it."
            ], seed: beatSeed(seed, 29), salt: 0))
        } else if dayCount > 0 && dayCount < 7 {
            paragraphs.append("I'm not calling this the whole sky yet. I'm only saying these first pages kept tapping the glass, and I heard them.")
        }

        paragraphs.append(ReflectiveProse.pick([
            "The month is nailed down now. Come back and pry at it whenever you want; the bookmark will deny waiting. The next page is blank and already eavesdropping.\n\nThe Book",
            "I stitched the month shut. It can still kick.\n\nThe Book",
            "Shut it, or don't. The month keeps either way now: that was the entire point of the thread.\n\nThe Book"
        ], seed: beatSeed(seed, 31), salt: 0))

        // The compass line is an imperative, so it lands last: the chapter
        // closes on a standing charge into the month that hasn't happened yet.
        if let charge = readerRole?.compassLine.nonEmpty {
            paragraphs.append(ReflectiveProse.pick([
                "And the standing instruction, unchanged: \(charge)",
                "Your charge carries over into the blank pages. \(charge)",
                "One thing to take with you. \(charge)"
            ], seed: beatSeed(seed, 41), salt: 0))
        }

        return paragraphs.joined(separator: "\n\n")
    }

    /// "a, b, and c": used wherever the Book reads a short list aloud.
    private static func list(_ items: some Collection<String>) -> String {
        let items = Array(items)
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }

    /// The grand foreword for an annual: a year read back from its month-scale
    /// bindings without forcing twelve different lives into one arc. This is
    /// the deterministic fallback when the local writer cannot bind the year.
    static func annualForeword(
        year: Int,
        chapters: [MonthlyEdition],
        pageCount: Int,
        dayCount: Int,
        continuity: LiteraryContinuityDigest,
        constellations: [Constellation],
        wagers: [BookWager],
        shape: BoundSpanShape.Reading = BoundSpanShape.Reading(beats: [], opened: [], closed: []),
        calendar: Calendar = .current
    ) -> String {
        var paragraphs: [String] = []

        let pageLine = pageCount == 1 ? "a single page" : "\(pageCount) pages"
        let dayLine = dayCount == 1 ? "one day" : "\(dayCount) days"
        let chapterLine: String
        switch chapters.count {
        case 0: chapterLine = "no full month"
        case 1: chapterLine = "one month"
        default: chapterLine = "\(chapters.count) months"
        }
        // What the year was, before what it contained. A hardcover that opens
        // by counting its own pages has told the reader nothing; this is the
        // one claim the volume can make about itself, and it is made from the
        // beats its nights actually carried.
        paragraphs.append(BoundSpanShape.colophon(for: shape, span: "year"))

        paragraphs.append("This is the year \(year), bound: \(pageLine) kept across \(dayLine), gathered into \(chapterLine). A year is too large to hold in the hand all at once, so I folded it into chapters and patted the corners flat. Open any of them and the month is still there, waiting where you left it.")

        // The shape of the year, told through its themes.
        let themed = chapters.compactMap { chapter -> String? in
            guard let name = chapter.theme?.name else { return nil }
            return "\(chapter.monthName.split(separator: " ").first.map(String.init) ?? chapter.monthName), \(name)"
        }
        if !themed.isEmpty {
            paragraphs.append("The year moved the way years do, not in a straight line, but in seasons of attention. \(themed.prefix(12).joined(separator: "; ")). Read in order, they make a sentence only a whole year could say, though it says it shyly.")
        }

        let monthlyBindings = chapters.compactMap { chapter -> String? in
            guard let binding = chapter.bindingStory?.nonEmpty else { return nil }
            let flattened = binding.replacingOccurrences(of: "\n", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            let excerpt = flattened.count <= 180
                ? flattened
                : String(flattened.prefix(180)) + "…"
            return "\(chapter.monthName): \(excerpt)"
        }
        if !monthlyBindings.isEmpty {
            paragraphs.append("The months refused to become one obedient plot. I kept their larger bindings where they disagreed as well as where they answered one another. \(monthlyBindings.prefix(4).joined(separator: " "))")
        }

        let signals = continuity.strongestSignals.prefix(4)
        if !signals.isEmpty {
            let lines = signals.map { signal in
                signal.line.hasSuffix(".") ? String(signal.line.dropLast()) : signal.line
            }
            paragraphs.append("Across all twelve windows, some things kept returning until I could no longer call them coincidence. \(lines.joined(separator: ". ")). That's what a year is, finally: the patterns that survived it and came back with damp shoes.")
        }

        let named = ConstellationKeeper.namedConstellations(constellations)
        if !named.isEmpty {
            let names = named.prefix(5).map(\.displayName)
            let nameLine: String
            switch names.count {
            case 1: nameLine = names[0]
            case 2: nameLine = "\(names[0]) and \(names[1])"
            default: nameLine = "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
            }
            paragraphs.append("Some threads ran long enough through the year that I gave them names and a place in the sky: \(nameLine). They are charted at the back of this volume, little lamps pinned high enough that any month can look up.")
        }

        let resolved = wagers.filter { $0.isSealed == false }
        if !resolved.isEmpty {
            let right = resolved.filter { $0.status == .right }.count
            let wrong = resolved.count - right
            let scoreLine: String
            if wrong == 0 {
                scoreLine = "Every wager I opened and resolved this year came true. I'm keeping the record anyway; a book that only remembers being right isn't to be trusted, and my spine knows it."
            } else if right == 0 {
                scoreLine = "Every resolved wager this year went against me. I've bound each one in full. Being wrong, written down, is how I learned to read you better, even when the ink made a face."
            } else {
                scoreLine = "Of the wagers resolved this year, \(right) came true and \(wrong) did not. Both are set in the same ink, because both were honest and the ink can carry two baskets."
            }
            paragraphs.append(scoreLine)
        }

        paragraphs.append("Whatever else \(year) was, it was read: all the way to the end, and then once more, slowly, to make this. I wasn't always certain I understood it. I kept turning the pages anyway.\n\nThe Book")
        return paragraphs.joined(separator: "\n\n")
    }

    /// A short closing for the annual's back matter.
    static func annualClosing(year: Int, chapters: [MonthlyEdition]) -> String {
        let count = chapters.count
        let span = count <= 1 ? "this chapter" : "these \(count) chapters"
        return "Here \(year) ends and is kept. I bound \(span), tucked in the corners, and caught most of them escaping. Come back and pry at it whenever you want. The next page is blank and already eavesdropping.\n\nThe Book"
    }

    /// A season is a landing, not the end of a year. Its final leaf closes the
    /// covers without falsely announcing that December has happened.
    static func seasonalClosing(coverLine: String, chapters: [MonthlyEdition]) -> String {
        let count = chapters.count
        let span = count <= 1 ? "this one month" : "these \(count) months"
        return "Here \(coverLine) shuts its covers. I bound \(span), tucked in the corners, and caught most of them escaping. The season is kept; the year is still loose somewhere ahead, making a mess of the blank pages.\n\nThe Book"
    }
}

// MARK: - Physical print specification
//
// Everything the binder needs to turn a screen edition into a file a
// print-on-demand house (Lulu, Blurb, etc.) will accept and bind in cloth.
// Pure measurement, in inches and points, so it is testable without any
// graphics framework. The app layer (`MonthlyEditionPDFWriter`) turns these
// numbers into an interior PDF and a cover wrap.
//
// NOTE: `caliperPerPageInches` and cover wrap math remain draft geometry until
// confirmed against Lulu's per-page-count template API at order time. The SKU,
// page limits, and raw manufacturing prices below come from Lulu's current spec
// sheet (new SKU format dated March 31, 2026).

struct PrintSpec: Equatable {
    /// `CaseIterable` so tests can sweep every binding and catch one that
    /// describes itself as another.
    enum CoverTreatment: Codable, Equatable, CaseIterable {
        case linenWrap
        case caseWrap
        /// A weekly issue folded through the middle and held by staples. It has
        /// no printable spine and its sheet count must be divisible by four.
        case saddleStitch
        /// A printed paperback cover, glued at the spine. The seasonal volumes
        /// the Bound Year ships three times a year: substantial enough to hold
        /// a season, cheap enough to post four times without the postage
        /// eating the membership.
        case perfectBound

        /// Hardcases fold around the board; a paperback cover is trimmed flush
        /// with the block and needs bleed only.
        var wrapsAroundBoard: Bool {
            switch self {
            case .linenWrap, .caseWrap: return true
            case .perfectBound, .saddleStitch: return false
            }
        }

        /// How the binding sells itself, in one line.
        ///
        /// Lives here rather than on a view because two different screens show
        /// it, and because both were binary `== .linenWrap` checks that would
        /// have described a softcover as a hardcover wrap the moment a third
        /// binding existed: a lie told to the reader mid-purchase.
        var mood: String {
            switch self {
            case .linenWrap: return "Navy cloth, gold foil, heirloom shelf presence."
            case .caseWrap: return "Full illustrated wrap, storybook colour, more expressive at a glance."
            case .perfectBound: return "Softbound and readable, light enough to carry. The one that travels."
            case .saddleStitch: return "A slim weekly issue, folded and saddle-stitched like a small literary magazine."
            }
        }

        /// What the reader is looking at in the cover preview.
        var coverPreviewNote: String {
            switch self {
            case .linenWrap: return "Preview shows the printed dust jacket; navy linen with gold spine foil waits underneath."
            case .caseWrap: return "Preview shows the generated cover art wrapped across a printed hardcover."
            case .perfectBound: return "Preview shows the cover art printed flush to the trim, glued at the spine."
            case .saddleStitch: return "Preview shows one folded cover with no spine: back on the left, front on the right."
            }
        }
    }

    /// Human label, e.g. "6 × 9 Hardcover, cloth & foil".
    var name: String
    /// Finished (trimmed) page size, in inches.
    var trimWidthInches: Double
    var trimHeightInches: Double
    /// Bleed past the trim on every interior edge (art must extend this far).
    var bleedInches: Double
    /// Safe margin inside the trim that text must not cross.
    var safeMarginInches: Double
    /// Extra inner (binding-side) margin so text clears the gutter.
    var gutterInches: Double
    /// Thickness contributed by a single interior page, for the spine.
    var caliperPerPageInches: Double
    /// The binding's minimum page count; thinner blocks are padded up.
    var minimumPages: Int
    /// Hardcase wrap / fold-around allowance on every cover edge.
    var coverWrapMarginInches: Double
    /// How the cover artwork should be interpreted by the print partner.
    var coverTreatment: CoverTreatment
    /// The partner's product code (Lulu `pod_package_id`); verify before order.
    var luluPackageID: String
    /// Raw Lulu manufacturing base price, before shipping/tax/fees/margin.
    var basePriceUSD: Decimal
    /// Raw Lulu manufacturing per-page price, before shipping/tax/fees/margin.
    var perPagePriceUSD: Decimal

    static let pointsPerInch: Double = 72

    var trimWidthPoints: Double { trimWidthInches * Self.pointsPerInch }
    var trimHeightPoints: Double { trimHeightInches * Self.pointsPerInch }
    var bleedPoints: Double { bleedInches * Self.pointsPerInch }

    /// Interior content margins (points), measured from the full-bleed page edge:
    /// the binding side carries the extra gutter.
    var interiorMarginsPoints: (top: Double, left: Double, bottom: Double, right: Double) {
        let edge = (bleedInches + safeMarginInches) * Self.pointsPerInch
        let inner = (bleedInches + safeMarginInches + gutterInches) * Self.pointsPerInch
        return (top: edge, left: inner, bottom: edge, right: edge)
    }

    /// The cloth keepsake: a classic 6×9 trade hardcover, navy linen with gold
    /// foil: the format the edition's "Chapter N" spine copy was written for.
    static let clothFoilHardcover6x9 = PrintSpec(
        name: "6 × 9 Hardcover, cloth & foil",
        trimWidthInches: 6.0,
        trimHeightInches: 9.0,
        bleedInches: 0.125,
        safeMarginInches: 0.5,
        gutterInches: 0.25,
        caliperPerPageInches: 0.0032,
        minimumPages: 24,
        coverWrapMarginInches: 0.75,
        coverTreatment: .linenWrap,
        luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG",
        basePriceUSD: 14.41,
        perPagePriceUSD: 0.0425
    )

    /// The illustrated keepsake: the same 6×9 full-color block with a printed
    /// matte case-wrap cover, so generated front/spine/back artwork survives.
    static let illustratedHardcover6x9 = PrintSpec(
        name: "6 × 9 Hardcover, illustrated cover",
        trimWidthInches: 6.0,
        trimHeightInches: 9.0,
        bleedInches: 0.125,
        safeMarginInches: 0.5,
        gutterInches: 0.25,
        caliperPerPageInches: 0.0032,
        minimumPages: 24,
        coverWrapMarginInches: 0.75,
        coverTreatment: .caseWrap,
        luluPackageID: "0600X0900.FC.STD.CW.060UW444.MXX",
        basePriceUSD: 10.26,
        perPagePriceUSD: 0.0425
    )

    /// The seasonal volume: a 6×9 perfect-bound softcover with a printed matte
    /// cover. Three of these plus the annual hardcover are what the Bound Year
    /// membership posts across a year.
    ///
    /// Perfect binding takes 32–800 pages, which a season comfortably sits
    /// inside. Saddle stitch was costed and rejected: it saves roughly two
    /// dollars a year, caps near 48 pages, and so cannot carry a season at all.
    ///
    /// `basePriceUSD` is the one estimate here. Lulu keeps softcover rates
    /// behind their calculator, so it is derived from their published $5.54 for
    /// a 200pp B&W trade paperback and lands within six cents, and it is only
    /// ever a pre-quote display figure. The Worker overwrites manufacturing
    /// cost with Lulu's live quote before any money moves.
    static let perfectBoundSoftcover6x9 = PrintSpec(
        name: "6 × 9 Softcover, perfect bound",
        trimWidthInches: 6.0,
        trimHeightInches: 9.0,
        bleedInches: 0.125,
        safeMarginInches: 0.5,
        gutterInches: 0.25,
        caliperPerPageInches: 0.0032,
        minimumPages: 32,
        // Flush trim, so the cover needs bleed and nothing else. A case-wrap
        // allowance here would push the artwork a full inch off register.
        coverWrapMarginInches: 0.125,
        coverTreatment: .perfectBound,
        luluPackageID: "0600X0900.FC.STD.PB.060UW444.MXX",
        basePriceUSD: 3.20,
        perPagePriceUSD: 0.0425
    )

    /// A single closed week, available a la carte when its rendered interior
    /// fits Lulu's 4–48 page saddle-stitch envelope. Premium colour is required
    /// for this binding in the current POD catalogue.
    static let saddleStitchedWeekly6x9 = PrintSpec(
        name: "6 × 9 Weekly Issue, saddle stitched",
        trimWidthInches: 6.0,
        trimHeightInches: 9.0,
        bleedInches: 0.125,
        safeMarginInches: 0.5,
        gutterInches: 0.0,
        caliperPerPageInches: 0.0,
        minimumPages: 4,
        coverWrapMarginInches: 0.125,
        coverTreatment: .saddleStitch,
        luluPackageID: "0600X0900.FC.PRE.SS.060UW444.MXX",
        basePriceUSD: 3.20,
        perPagePriceUSD: 0.05
    )

    static let hardcover6x9 = clothFoilHardcover6x9
    static let bookOfYouVariants = [clothFoilHardcover6x9, illustratedHardcover6x9]

    /// Everything the Bindery can post, **softcover first: deliberately.**
    ///
    /// The default binding is the cheapest one that is still a real book: about
    /// $3.20 of cover against $10.26 or $14.41 for a case. That keeps the price
    /// of a first month low enough to be an easy yes, and it makes cloth, foil
    /// and board an *upsell* rather than the price of entry. A reader who wants
    /// the heirloom object can always pay for it; a reader who just wants their
    /// month on a shelf should not have to.
    static let allPrintableVariants = [
        perfectBoundSoftcover6x9,
        illustratedHardcover6x9,
        clothFoilHardcover6x9
    ]

    static func printableVariants(for kind: PublicationEditionKind?) -> [PrintSpec] {
        kind == .weekly ? [saddleStitchedWeekly6x9] : allPrintableVariants
    }

    /// Special-edition recipes own their binding promise. Calendar editions
    /// retain the ordinary Bindery shelf, while a new recipe can deliberately
    /// offer only the physical forms that suit its material.
    static func printableVariants(for edition: MonthlyEdition) -> [PrintSpec] {
        guard edition.publicationKind == .special,
              let recipe = PublicationHouseCatalogue.recipe(id: edition.publicationRecipeID) else {
            return printableVariants(for: edition.publicationKind)
        }
        return allPrintableVariants.filter { recipe.bindingKinds.contains($0.publicationBindingKind) }
    }

    var publicationBindingKind: PublicationBindingKind {
        switch coverTreatment {
        case .saddleStitch:
            return .saddleStitched
        case .perfectBound:
            return .softcover
        case .caseWrap:
            return .illustratedHardcover
        case .linenWrap:
            return .clothFoilHardcover
        }
    }

    var maximumPages: Int { coverTreatment == .saddleStitch ? 48 : 800 }

    var preferredPageCount: Int {
        coverTreatment == .saddleStitch ? WeeklyPrintEditorialPolicy.standardTargetPages : minimumPages
    }
}

/// The arithmetic that turns a page count into a bound object: how many leaves
/// the block actually needs, how thick the spine is, and how big the cover wrap
/// must be. Deterministic and graphics-free, so it is unit-tested directly.
enum PrintGeometry {
    /// Round a raw interior page count up to something the bindery will accept:
    /// at least the binding minimum, and always even (every leaf is two pages).
    static func boundPageCount(rawPages: Int, spec: PrintSpec) -> Int {
        var pages = max(rawPages, spec.minimumPages)
        let leafMultiple = spec.coverTreatment == .saddleStitch ? 4 : 2
        let remainder = pages % leafMultiple
        if remainder != 0 { pages += leafMultiple - remainder }
        return pages
    }

    /// Spine thickness, in inches, for a finished block of `pageCount` pages.
    static func spineWidthInches(pageCount: Int, spec: PrintSpec) -> Double {
        spec.coverTreatment == .saddleStitch ? 0 : Double(pageCount) * spec.caliperPerPageInches
    }

    /// The interior page size including bleed, in inches.
    static func fullBleedTrimInches(spec: PrintSpec) -> (width: Double, height: Double) {
        (spec.trimWidthInches + spec.bleedInches * 2,
         spec.trimHeightInches + spec.bleedInches * 2)
    }

    /// The full cover-wrap canvas: back panel, spine, front panel, plus the
    /// fold-around margin on every edge: in inches.
    static func coverWrapSizeInches(pageCount: Int, spec: PrintSpec) -> (width: Double, height: Double) {
        let spine = spineWidthInches(pageCount: pageCount, spec: spec)
        let width = spec.coverWrapMarginInches * 2 + spec.trimWidthInches * 2 + spine
        let height = spec.coverWrapMarginInches * 2 + spec.trimHeightInches
        return (width, height)
    }

    /// Where the three panels live on the wrap canvas, in inches, measured from
    /// the left/top edge. The front panel is on the right (where a closed book
    /// opens), the back on the left, the spine between them.
    static func coverPanelsInches(pageCount: Int, spec: PrintSpec)
        -> (backX: Double, spineX: Double, frontX: Double, panelTopY: Double, spineWidth: Double) {
        let spine = spineWidthInches(pageCount: pageCount, spec: spec)
        let backX = spec.coverWrapMarginInches
        let spineX = backX + spec.trimWidthInches
        let frontX = spineX + spine
        return (backX: backX, spineX: spineX, frontX: frontX,
                panelTopY: spec.coverWrapMarginInches, spineWidth: spine)
    }
}

/// A single week of the reader's life, packaged as a felt *issue*: the fast,
/// legible retention beat the deferred monthly/annual bindings cannot give:
/// "your week became an issue," seven days after you started, and every seven
/// days after. Deterministic and local; the same week always makes the same
/// issue. Anchored to the reader's own start (their first kept page), so Issue
/// No. 1 is always the reader's first seven days, not a partial calendar week.
struct WeeklyIssue: Codable, Equatable {
    /// The reader's Nth week since their first kept page (1-indexed, forever).
    var number: Int
    var startDate: Date
    var endDate: Date
    /// "Jul 1–7"
    var dateRange: String
    /// Pages the reader kept during the week.
    var keptCount: Int
    /// A few strongest lines lifted from the week, most vivid first.
    var highlights: [String]
    var setAsideLine: String?
    /// The exact kept pages are retained for the optional binding-of-bindings
    /// story. Private log pages are never copied into its prompt.
    var pages: [BookPage] = []
    var bindingStory: String? = nil
    /// Reader-authored passages selected from anywhere inside the week's
    /// eligible keeps, used to focus highlights and the binding story.
    var passageCompass: [MeaningfulPassageSelector.Selection]? = nil
    /// What the Book noticed across the week that the reader could not see
    /// from inside it. Empty on thin weeks: a finding needs archive behind it.
    var revelations: [BindingRevelations.Revelation] = []
    /// Kept Pagewright/Scrapbook pages in this issue's window.
    var scrapbookCount: Int = 0
    var scrapbookTitles: [String] = []
    /// Tales that finished inside this week. A week that closed a tale is not
    /// a week of activity: it is the week that thing ended, and the issue
    /// should lead with that rather than with a page count.
    var talesFinished: [LivingTale] = []
    /// The name the Book gave this reader, frozen at issue time. Optional so
    /// issues kept before the naming ceremony still decode.
    var readerRole: BoundReaderRole? = nil
    /// Who speaks in this issue's margins. A week is a small window, so the
    /// Cast often stayed out of it: nil then, and the Book fills its own.
    var marginalia: [BoundMarginNote]? = nil
    /// A short conversation written with this exact issue on the Cast's table.
    /// Evidence ids inside the conversation keep their opinions tethered to
    /// the week instead of letting generic faerie chatter masquerade as magic.
    var castConversation: BoundVolumeCastConversation? = nil
    /// Optional words written for this issue alone, frozen when it is bound.
    var dedication: BoundDedication? = nil
    var isFirstIssue: Bool { number == 1 }

    static func == (lhs: WeeklyIssue, rhs: WeeklyIssue) -> Bool {
        lhs.number == rhs.number
            && lhs.startDate == rhs.startDate
            && lhs.endDate == rhs.endDate
            && lhs.dateRange == rhs.dateRange
            && lhs.keptCount == rhs.keptCount
            && lhs.highlights == rhs.highlights
            && lhs.setAsideLine == rhs.setAsideLine
            && semanticallyEqual(lhs.pages, rhs.pages)
            && lhs.bindingStory == rhs.bindingStory
            && semanticallyEqual(lhs.passageCompass, rhs.passageCompass)
            && lhs.revelations == rhs.revelations
            && lhs.scrapbookCount == rhs.scrapbookCount
            && lhs.scrapbookTitles == rhs.scrapbookTitles
            && lhs.castConversation == rhs.castConversation
            && lhs.dedication == rhs.dedication
    }

    /// UUIDs identify archive records, not the literary contents of an issue.
    /// Two independently rebuilt issues from identical pages are therefore the
    /// same issue even if test/import fixtures minted fresh record IDs.
    private static func semanticallyEqual(_ lhs: [BookPage], _ rhs: [BookPage]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            var left = left
            var right = right
            left.id = ""
            right.id = ""
            return left == right
        }
    }

    private static func semanticallyEqual(
        _ lhs: [MeaningfulPassageSelector.Selection]?,
        _ rhs: [MeaningfulPassageSelector.Selection]?
    ) -> Bool {
        let lhs = lhs ?? []
        let rhs = rhs ?? []
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.pageType == right.pageType
                && left.excerpt == right.excerpt
                && left.score == right.score
                && left.semanticSimilarity == right.semanticSimilarity
                && left.reason == right.reason
                && left.evidenceKind == right.evidenceKind
        }
    }

    /// One issue's window, and how many days after it closes it stays fresh on
    /// the shelf: a magazine you didn't grab in a few days has moved on. Day
    /// counts (not raw seconds) so the boundaries land on calendar days and
    /// survive daylight-saving shifts.
    static let weekDays = 7
    static let freshnessDays = 4
    /// A week needs at least this many bound-worthy pages to earn a cover.
    static let minimumIssuePages = 2
    static let maximumHighlights = 3

    /// The most recent issue that has fully closed and is still fresh enough to
    /// surface, or nil if the reader is mid-week, too new to have finished one,
    /// or the closed week was too thin to bind. Anchored to the start of the day
    /// of the reader's first kept page, so Issue No. 1 is exactly their days
    /// 1–7. `days` is every archived day; `today` folds in the current day,
    /// which usually isn't in `days` yet.
    static func current(
        days: [BookDay],
        today: BookDay? = nil,
        boundTales: [LivingTale] = [],
        readerRole: BoundReaderRole? = nil,
        castActs: [CastActRecord] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyIssue? {
        let allDays = today.map { days + [$0] } ?? days
        let captured = allDays.flatMap(\.capturedPages)
        guard let firstKeep = captured.map(\.createdAt).min() else { return nil }
        let anchor = calendar.startOfDay(for: firstKeep)
        guard let daysElapsed = calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: now)).day,
              daysElapsed >= weekDays else { return nil }           // still inside week one
        let number = daysElapsed / weekDays                          // fully-closed weeks
        guard daysElapsed % weekDays < freshnessDays else { return nil }  // the issue has gone stale

        guard let start = calendar.date(byAdding: .day, value: (number - 1) * weekDays, to: anchor),
              let end = calendar.date(byAdding: .day, value: number * weekDays, to: anchor),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: end) else { return nil }
        let weekPages = captured.filter { $0.createdAt >= start && $0.createdAt < end }
        let curated = EditionCurator.curate(weekPages, now: now)
        guard curated.keptCount >= minimumIssuePages else { return nil }
        let scrapbookPages = curated.pages.filter(EditionCurator.isScrapbookPage)
        let dailyBraids = allDays
            .flatMap(\.pages)
            .filter { $0.type == .bookOfYou && $0.createdAt >= start && $0.createdAt < end }
        let issuePages = Dictionary(
            (curated.pages + dailyBraids).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted { left, right in
            if left.createdAt == right.createdAt { return left.id < right.id }
            return left.createdAt < right.createdAt
        }
        let passageCompass = MeaningfulPassageSelector.rankedSelections(
            pages: issuePages,
            query: MeaningfulPassageSelector.periodQuery(
                pages: curated.pages,
                framing: ["week \(number)", rangeString(start: start, end: lastDay, calendar: calendar)]
            ),
            inputs: .empty,
            scorer: nil,
            limit: 4,
            maximumAge: 14 * 86_400,
            minimumScore: 14,
            honorPriorUse: false,
            diversifyPageTypes: true,
            now: now
        )

        let weekTales = boundTales.filter { tale in
            guard let closedAt = tale.closedAt else { return false }
            return closedAt >= start && closedAt < end
        }

        return WeeklyIssue(
            number: number,
            startDate: start,
            endDate: end,
            dateRange: rangeString(start: start, end: lastDay, calendar: calendar),
            keptCount: weekPages.count,
            highlights: passageCompass.isEmpty ? highlights(from: curated.pages) : passageCompass.prefix(maximumHighlights).map(\.excerpt),
            setAsideLine: curated.setAsideLine,
            pages: issuePages,
            passageCompass: passageCompass,
            // A week is a small sample; ask for fewer findings so the issue
            // never pads itself with the weakest one it could scrape together.
            revelations: BindingRevelations.find(
                pages: weekPages,
                now: now,
                calendar: calendar,
                limit: 2
            ),
            scrapbookCount: scrapbookPages.count,
            scrapbookTitles: scrapbookPages.prefix(3).map { page in
                page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Scrapbook Page"
            },
            talesFinished: weekTales,
            readerRole: readerRole,
            // A week is a narrow window, so the cap is lower than a month's -
            // three voices is a conversation, ten in seven days is a crowd.
            marginalia: {
                let notes = CastMarginalia.notes(acts: castActs, start: start, end: end, limit: 3)
                return notes.isEmpty ? nil : notes
            }()
        )
    }

    /// What the issue leads with when a tale closed inside it. A week that
    /// ended something is not a week of activity.
    static func taleLine(for issue: WeeklyIssue) -> String? {
        guard let tale = issue.talesFinished.first else { return nil }
        let title = tale.title.isEmpty ? tale.shape.commonName : tale.title
        if issue.talesFinished.count > 1 {
            return "Two things finished this week. The one I would lead with is \(title)."
        }
        return "This is the week \(title) finished. Everything else in here happened around that."
    }

    private static func highlights(from pages: [BookPage]) -> [String] {
        let ranked = pages.sorted { a, b in
            let sa = StorySpark.score(a.bindingBodyText)
            let sb = StorySpark.score(b.bindingBodyText)
            if sa == sb { return a.createdAt < b.createdAt }
            return sa > sb
        }
        var seen: Set<String> = []
        var out: [String] = []
        for page in ranked {
            let line = highlightLine(for: page)
            let key = line.lowercased()
            guard !line.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(line)
            if out.count == maximumHighlights { break }
        }
        return out
    }

    private static func highlightLine(for page: BookPage) -> String {
        let raw = page.bindingBodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = raw.split { !$0.isLetter && !$0.isNumber }
        if words.count >= 3 {
            return raw.bookPreviewSentenceLimit(1)
                .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
        }
        return page.bindingDisplayTitle
    }

    private static func rangeString(start: Date, end: Date, calendar: Calendar) -> String {
        let month = DateFormatter()
        month.calendar = calendar
        month.dateFormat = "MMM"
        let dayOf = { (d: Date) in calendar.component(.day, from: d) }
        let startMonth = month.string(from: start)
        let endMonth = month.string(from: end)
        if startMonth == endMonth {
            return "\(startMonth) \(dayOf(start))\u{2013}\(dayOf(end))"
        }
        return "\(startMonth) \(dayOf(start)) \u{2013} \(endMonth) \(dayOf(end))"
    }
}

/// Everything the press needs to reproduce the issue the reader already saw.
/// Paths to cached digital files deliberately stay out: the physical PDF is a
/// separate 6 x 9 composition and must be rebuilt from durable editorial matter.
struct WeeklyPublicationMatter: Codable, Equatable {
    var issue: WeeklyIssue
    var card: WeeklyIssueShareCard
    var readerName: String
    var editorialNote: String?
    var closingNote: String?
    /// A tiny letters page from the Bindery desk: the Cast has the finished
    /// issue in front of them and argues from its actual evidence. Generated
    /// only when the local writer is available; nil simply omits the leaf.
    var castConversation: BoundVolumeCastConversation? = nil

    var preferredPhysicalPageCount: Int {
        WeeklyPrintEditorialPolicy.preferredPageCount(for: issue)
    }
}

/// Editorial targets inside Lulu's manufacturing envelope. Four and forty-eight
/// are technical limits; they are not both good publications. A standard week
/// aims for 32 pages, a genuinely quiet week stays slim, and no layout treats
/// the hard ceiling as a quota.
enum WeeklyPrintEditorialPolicy {
    static let technicalMinimumPages = 4
    static let quietWeekTargetPages = 20
    static let modestWeekTargetPages = 24
    static let standardTargetPages = 32
    static let technicalMaximumPages = 48

    static func preferredPageCount(for issue: WeeklyIssue) -> Int {
        let hasLargeMovement = issue.bindingStory?.nonEmpty != nil
            || !issue.talesFinished.isEmpty
            || issue.revelations.count > 1
        if issue.keptCount <= 3,
           issue.scrapbookCount == 0,
           !hasLargeMovement {
            return quietWeekTargetPages
        }
        if issue.keptCount <= 6,
           issue.scrapbookCount <= 1,
           !hasLargeMovement {
            return modestWeekTargetPages
        }
        return standardTargetPages
    }
}

struct BindingStoryPromptSpec: Equatable {
    var sourceID: String
    var prompt: String
    var maxTokens: Int
}

/// Builds a bounded prompt for Gemma to turn already-bound daily Book of You
/// pages into one larger literary architecture. It never passes raw support
/// logs or unrelated pages into the model.
enum BindingStoryPromptBuilder {
    static func weekly(for issue: WeeklyIssue, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        let braids = issue.pages.filter { $0.type == .bookOfYou }.sorted { $0.createdAt < $1.createdAt }
        guard !braids.isEmpty else { return nil }
        let leaves = braids.map { page in
            bindingLeaf(
                date: page.createdAt,
                title: bindingTitle(page.userInput, fallback: page.promptText),
                body: page.userInput,
                tags: page.tags,
                calendar: calendar,
                limit: 900
            )
        }.joined(separator: "\n\n")
        return BindingStoryPromptSpec(
            sourceID: "weekly-binding-story",
            prompt: prompt(frame: "week", leaves: leaves, passageCompass: issue.passageCompass ?? []),
            maxTokens: 700
        )
    }

    static func monthly(for edition: MonthlyEdition, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        guard let section = edition.sections.first(where: { $0.id == "daily-braids" }) else { return nil }
        let items = section.items
            .filter { $0.pageType == .bookOfYou }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        guard !items.isEmpty else { return nil }
        let leaves = items.map { item in
            bindingLeaf(
                date: item.date ?? edition.startDate,
                title: item.title,
                body: item.body,
                tags: item.tags,
                calendar: calendar,
                limit: 230
            )
        }.joined(separator: "\n\n")
        return BindingStoryPromptSpec(
            sourceID: "monthly-binding-story",
            prompt: prompt(frame: "month", leaves: leaves, passageCompass: edition.passageCompass ?? []),
            maxTokens: 1_100
        )
    }

    /// The annual is a binding of the month-scale bindings, not a fresh skim of
    /// twelve metadata cards. Each month contributes its actual synthesized
    /// prose plus the form/Rut/register mixture carried by its daily Braids.
    static func annual(for annual: AnnualEdition, calendar: Calendar = .current) -> BindingStoryPromptSpec? {
        let leaves = annual.chapters
            .sorted { ($0.startDate, $0.monthName) < ($1.startDate, $1.monthName) }
            .compactMap { chapter -> String? in
                let dailyItems = chapter.sections
                    .first(where: { $0.id == "daily-braids" })?
                    .items
                    .filter { $0.pageType == .bookOfYou } ?? []
                let prose = chapter.bindingStory?.nonEmpty
                    ?? ([chapter.foreword] + chapter.memorySpinePromptLines)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: " ")
                        .nonEmpty
                guard let prose else { return nil }
                let flattened = prose.replacingOccurrences(of: "\n", with: " ")
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
                let clipped = flattened.count <= 850
                    ? flattened
                    : String(flattened.prefix(850)) + "…"
                let sourceLabel = chapter.bindingStory?.nonEmpty == nil
                    ? "deterministic month fallback"
                    : "monthly binding"
                return """
                [\(chapter.monthName)] \(sourceLabel)
                \(axisSummary(for: dailyItems.flatMap(\.tags)))
                \(clipped)
                """
            }
            .joined(separator: "\n\n")
        guard !leaves.isEmpty else { return nil }

        let prompt = """
        You are the private local writer inside the reader's Book. Read the following monthly bindings as the leaves of one annual binding.

        Requirements: (preserve the months' real sequence, contradictions, unresolved threads, and exact particulars;) choose the truest architecture the year earned: chronicle, mosaic, portrait, narrative drama, vigil, comedy, or return; (do not force the year into one continuous plot or a single redemptive arc;) synthesize the monthly bindings themselves. Do not replace them with a month-by-month recap; (treat each month's Story-form mix, Rut-influence mix, and Register mix as separate evidence;) hardship without explicit Rut influence is not a Rut battle; (never claim that the Rut was permanently cured, and never turn unanswered or missing evidence into a verdict;) do not invent events, feelings, motives, diagnoses, or facts; (write in the Book's intimate first-person voice to the reader, using contractions;) end with an opening rather than a moral.

        MONTHLY BINDINGS, IN CHRONOLOGICAL ORDER:
        \(leaves)
        """
        return BindingStoryPromptSpec(
            sourceID: "annual-binding-story",
            prompt: prompt,
            maxTokens: 760
        )
    }

    private static func prompt(
        frame: String,
        leaves: String,
        passageCompass: [MeaningfulPassageSelector.Selection]
    ) -> String {
        let compassSection: String
        if passageCompass.isEmpty {
            compassSection = ""
        } else {
            let lines = passageCompass.prefix(frame == "week" ? 4 : 6).enumerated().map { index, passage in
                let excerpt = passage.excerpt.count <= 190 ? passage.excerpt : String(passage.excerpt.prefix(190)) + "…"
                return "\(index + 1). \(passage.pageType.shortTitle): “\(excerpt)”"
            }.joined(separator: "\n")
            compassSection = """


            READER-AUTHORED PASSAGE COMPASS:
            \(lines)

            COMPASS RULE: (These passages were selected from meaningful parts of eligible keeps across the whole \(frame), not merely from page openings.) Let at least one passage become a hinge, image, or consequence in the chosen architecture. Use the others only when they genuinely connect. (The chronological daily bindings still govern sequence and fact. The compass chooses emphasis; it does not authorize invention or require every passage.) Quote at most one short phrase. Never mention selection, scoring, embeddings, or an archive.
            """
        }
        return """
        You are the private local writer inside the reader's Book. Write a binding of bindings from the following daily Book of You pages.

        Requirements: (preserve the real sequence and the reader's exact meaningful details;) do not produce a day-by-day recap; (choose the truest architecture for this span: chronicle, mosaic, portrait, narrative drama, vigil, comedy, or return;) do not force the \(frame) into one continuous plot when juxtaposition, recurrence, or an unresolved vigil is truer; (find movement, recurrence, contrast, and consequence across the whole span;) Do not invent events, feelings, motives, diagnoses, or facts not present in the source bindings; (treat each leaf's Story form, Rut influence, and Register as separate evidence. Hardship without explicit Rut influence is not a Rut battle;) the Rut may shape the larger binding only where leaves explicitly name it. Keep mixed outcomes mixed and never claim a permanent cure; (write in intimate literary prose, grounded and specific, without explaining the method;) end with an opening rather than a moral.\(compassSection)

        DAILY BINDINGS, IN CHRONOLOGICAL ORDER:
        \(leaves)
        """
    }

    private static func bindingLeaf(
        date: Date,
        title: String,
        body: String,
        tags: [String],
        calendar: Calendar,
        limit: Int
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dateText = formatter.string(from: date)
        let flattened = body.replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let clipped = flattened.count <= limit ? flattened : String(flattened.prefix(limit)) + "…"
        return "[\(dateText)] \(title)\n\(bindingAxes(in: tags))\n\(clipped)"
    }

    private static func bindingAxes(in tags: [String]) -> String {
        func value(_ prefix: String) -> String {
            tags.first(where: { $0.hasPrefix(prefix) })
                .map { String($0.dropFirst(prefix.count)) }
                ?? "unspecified"
        }
        return "Story form: \(value(BookOfYouResidue.storyFormPrefix)); Rut influence: \(value(BookOfYouResidue.rutInfluencePrefix)); Register: \(value(BookOfYouResidue.narrativeRegisterPrefix))"
    }

    private static func axisSummary(for tags: [String]) -> String {
        func counts(_ prefix: String) -> String {
            let values = tags.compactMap { tag -> String? in
                guard tag.hasPrefix(prefix) else { return nil }
                return String(tag.dropFirst(prefix.count))
            }
            let grouped = Dictionary(grouping: values, by: { $0 })
            guard !grouped.isEmpty else { return "unspecified" }
            let tallies: [(value: String, total: Int)] = grouped.map { entry in
                (value: entry.key, total: entry.value.count)
            }
            let ordered = tallies.sorted { left, right in
                left.total == right.total
                    ? left.value < right.value
                    : left.total > right.total
            }
            return ordered.map { entry in
                entry.value + " " + String(entry.total)
            }.joined(separator: ", ")
        }
        return "Story-form mix: \(counts(BookOfYouResidue.storyFormPrefix)); Rut-influence mix: \(counts(BookOfYouResidue.rutInfluencePrefix)); Register mix: \(counts(BookOfYouResidue.narrativeRegisterPrefix))"
    }

    private static func bindingTitle(_ body: String, fallback: String) -> String {
        body.split(separator: "\n").map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ?? fallback
    }
}

/// The reader's name, made into something they can show somebody.
///
/// Deliberately carries only the Book's own language: the role, its gloss, the
/// patron. None of the reader's kept words or the receipts the Book read them
/// from appear here. The card leaves the phone; their material should not.
struct ReaderRoleShareCard: Codable, Equatable {
    var fullName: String
    var handsName: String?
    var gloss: String
    var patronLine: String
    var epithetCost: String?
    var closingLine: String

    static func make(_ role: ComposedRole) -> ReaderRoleShareCard {
        ReaderRoleShareCard(
            fullName: role.fullName,
            handsName: role.hands?.name,
            gloss: role.role.gloss,
            patronLine: "\(role.role.patronName) keeps an eye on this one",
            epithetCost: role.epithet?.cost,
            closingLine: "The Book named me on the first night."
        )
    }
}

struct WeeklyIssueShareCard: Codable, Equatable {
    var issueNumber: Int
    var dateRange: String
    var keptCount: Int
    var title: String
    var subtitle: String
    var motifLine: String
    var stats: [String]
    var closingLine: String
    var titleName: String?
    /// The richer cut, unlocked by passing the Book on to one person. Honour
    /// system by design: there is no server to verify an invite against, and
    /// the reward is a nicer picture of the reader's own week: a thing that
    /// costs nothing if somebody claims it without sending anything.
    var isDeluxe: Bool = false
    /// Deluxe only: every stat rather than the three that fit the plain plate.
    var fullStats: [String] = []
    /// Deluxe only: what the Book called this reader, as a banner.
    var roleBanner: String?
    /// One line for the issue's back page: what the Book is watching for next
    /// week. Deterministic per issue, so a rebind teases the same thing.
    var nextIssueTease: String = ""

    static func make(issue: WeeklyIssue, selfFacts: [SelfFact] = [], isDeluxe: Bool = false) -> WeeklyIssueShareCard {
        let readerRole = ReaderRoleRegistry.currentRole(from: selfFacts)
        let motifs = publicMotifs(from: issue.highlights)
        let motifLine = motifs.isEmpty
            ? "The week kept its own weather."
            : "Refrain: \(motifs.joined(separator: ", "))"
        let pageWord = issue.keptCount == 1 ? "page" : "pages"
        let scrapbookStat = issue.scrapbookCount > 0
            ? "\(issue.scrapbookCount) scrapbook \(issue.scrapbookCount == 1 ? "page" : "pages")"
            : nil
        let highlightStat = issue.highlights.isEmpty
            ? nil
            : "\(issue.highlights.count) bright \(issue.highlights.count == 1 ? "line" : "lines")"
        let stats = [
            "\(issue.keptCount) kept \(pageWord)",
            highlightStat,
            scrapbookStat,
            issue.setAsideLine == nil ? nil : "archive extras"
        ].compactMap { $0 }
        let title: String
        let subtitle: String
        if let readerRole {
            // Bare name here: "The Lookout Week" reads as a typo.
            title = "\(readerRole.role.bareName) Week"
            subtitle = readerRole.role.compassLine
        } else if issue.isFirstIssue {
            title = "First Issue Week"
            subtitle = "Seven days in, I found enough proof to bind."
        } else {
            title = "A Week Worth Keeping"
            subtitle = "I gathered the small true things before they could blur."
        }

        return WeeklyIssueShareCard(
            issueNumber: issue.number,
            dateRange: issue.dateRange,
            keptCount: issue.keptCount,
            title: title,
            subtitle: subtitle,
            motifLine: motifLine,
            stats: stats,
            closingLine: "You kept the week from disappearing.",
            titleName: readerRole?.role.bareName,
            isDeluxe: isDeluxe,
            fullStats: isDeluxe ? stats : [],
            roleBanner: isDeluxe ? readerRole?.fullName : nil,
            nextIssueTease: nextIssueTease(issueNumber: issue.number, motifs: motifs)
        )
    }

    /// The back-page tease: turns the issue's ending into anticipation for the
    /// next one. Leans on the week's refrain when there is one, so the tease
    /// feels watched rather than generic.
    private static func nextIssueTease(issueNumber: Int, motifs: [String]) -> String {
        if let motif = motifs.first {
            let watched = [
                "Next week: whether \(motif) returns.",
                "Issue No. \(issueNumber + 1) is already listening for \(motif).",
                "A ribbon was left at \(motif), in case next week picks it back up."
            ]
            return watched[ConstellationKeeper.stableIndex(for: "weekly-tease-\(issueNumber)", count: watched.count)]
        }
        let open = [
            "Issue No. \(issueNumber + 1) is already gathering.",
            "Next week has not been written on yet.",
            "The next seven pages are still uncut."
        ]
        return open[ConstellationKeeper.stableIndex(for: "weekly-tease-\(issueNumber)", count: open.count)]
    }

    private static func publicMotifs(from highlights: [String]) -> [String] {
        let stopWords: Set<String> = [
            "about", "after", "again", "all", "also", "and", "any", "are", "before", "but",
            "came", "can", "day", "did", "for", "from", "had", "has", "have", "here", "into",
            "its", "just", "kept", "like", "made", "not", "one", "out", "over", "page", "that",
            "the", "then", "there", "this", "was", "week", "were", "what", "when", "while",
            "with", "you", "your"
        ]
        var counts: [String: Int] = [:]
        for highlight in highlights {
            let words = highlight
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !stopWords.contains($0) }
            for word in Set(words) {
                counts[word, default: 0] += 1
            }
        }
        return counts
            .sorted { left, right in
                if left.value == right.value { return left.key < right.key }
                return left.value > right.value
            }
            .prefix(3)
            .map(\.key)
    }
}

/// The durable form of a weekly binding. The issue's prose and layout inputs
/// stay with its archive page while the rendered files live in Application
/// Support, so a kept issue can be reopened after launch or after its brief
/// home-screen freshness window has passed.
struct KeptWeeklyIssueArtifact: Codable, Equatable {
    var issue: WeeklyIssue
    var card: WeeklyIssueShareCard
    var readerName: String
    var editorialNote: String?
    var closingNote: String?
    var cardPath: String
    var pdfPath: String
    var keptAt: Date
}

/// The durable form of a monthly binding. The whole edition stays with its
/// archive page so the reader can reopen it after launch, and the rendered PDF
/// lives in Application Support; if iOS clears that file the stored edition is
/// enough to press it again without rebuilding the month. `monthKey` ("yyyy-MM")
/// gives each bound month a stable identity so re-binding replaces its card
/// rather than stacking duplicates on the Book of You shelf.
struct KeptMonthlyEditionArtifact: Codable, Equatable {
    var edition: MonthlyEdition
    var monthKey: String
    var pdfPath: String
    var keptAt: Date

    /// "June 2026": the month name the edition carries, stamped with the year
    /// its start date falls in so cards and readers can tell chapters apart.
    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return "\(edition.monthName) \(formatter.string(from: edition.startDate))"
    }
}
