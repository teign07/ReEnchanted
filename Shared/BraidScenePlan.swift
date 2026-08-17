import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// The braid's decision, made before a single sentence is written.
//
// The old engine decided and wrote in one motion: every template took the
// night's anchor noun and returned a finished sentence. That is why the braid
// could not braid - a template takes one argument, so a page could only ever be
// independently-authored sentences sharing a noun. Measured on 2026-08-16: 5%
// of sentences related to more than one of the reader's facts, and 80 of 81
// world strings interpolated the reader's noun.
//
// So deciding is separated from writing. This file is the decision. It holds
// what the page is about, which of the reader's own atoms are on it and what
// job each one does, what the world is doing tonight, what returned from an
// earlier night, how long the night has earned to be, and what it should leave
// behind. Two renderers consume it: the house writer, instantly and offline,
// and the local model, when it is available and its provenance can be checked.
//
// **The law about strings.** The plan carries evidence - the reader's exact
// words, a canonical world fact, the concrete detail that returned - and those
// are strings, with source ids. It must never carry a *rendered sentence*. The
// moment a field holds "the company arrived" or "the debt noticed", the
// template bank has been rebuilt one level up and given a new name.

/// One atom of material, at the grain a claim can actually be checked against.
///
/// A page is too coarse. "I did not call Sam, but I did water the plants" is
/// one page and two facts, and a rewrite that recombines them into "you called
/// Sam about the plants" preserves every word of the page while inventing the
/// evening. Claims are checked per contribution, never per page.
struct SceneEvidence: Equatable, Codable, Identifiable {
    enum Kind: String, Codable, Equatable {
        /// A line the reader wrote.
        case writtenLine
        /// A path the reader chose inside a fiction page.
        case fictionChoice
        /// A photograph they kept, carrying their own caption.
        case photograph
        /// A recording they kept, carrying their own transcript.
        case voiceRecording
        /// A scene the Book wrote and the reader kept. Evidence of the shared
        /// fictional world, and never evidence about the reader's life.
        case keptFiction
    }

    /// `page-market#0`. Stable because a page's contributions are derived in a
    /// fixed order from its own content.
    var id: String
    var pageID: String
    var kind: Kind
    /// The reader's words, or the world's own record. Evidence, not prose.
    var text: String
    var occurredAt: Date
    /// Whether a claim about this atom is a claim about the reader's life.
    var isAboutTheReadersLife: Bool { kind != .keptFiction }
    /// Hard material the reader has not given permission to make a tale of.
    var isUnclearedShadow: Bool
}

/// What an atom is doing on the page. Most nights most atoms are witnesses;
/// a night where everything is dramatic is a night that is lying.
enum SceneJob: String, Codable, Equatable, CaseIterable {
    /// What the page is truly about.
    case anchor
    /// What enters and unsettles.
    case disturbance
    /// What makes the situation difficult.
    case pressure
    /// What changes the terms.
    case turn
    /// What remains afterward.
    case residue
    /// An important fact that belongs on the page and should not be forced
    /// into a dramatic role it does not have.
    case witness
}

struct ScenePlacement: Equatable, Codable {
    var evidenceID: String
    var job: SceneJob
}

/// A licensed relation between two of the reader's own facts.
///
/// This is where an honest page gets its length. Measured across the corpus,
/// only 5% of sentences related to more than one fact - the braid listed rather
/// than braided - and every attempt to lengthen a page by other means bought
/// sentences about the Book instead. Four facts have six possible pairings, and
/// a sentence whose content comes from a *pairing* cannot be generic filler,
/// because no two pairings are alike.
///
/// Detection is mechanical. `sharedNoun` is checkable; "these both feel like
/// endings" is a horoscope, and the moment this starts detecting meaning it has
/// become the thing the whole design exists to prevent.
struct SceneRelation: Equatable, Codable {
    enum Kind: String, Codable, Equatable {
        /// The same thing turns up in both.
        case sharedThing
        /// The same person is in both.
        case sharedPerson
        /// The day's first thing and its last.
        case acrossTheDay
    }

    var kind: Kind
    var evidenceIDs: [String]
    /// The word the relation rests on, so the renderer can be specific and the
    /// reader can check it.
    var pivot: String?
    /// The line rests on something the night refused to resolve, so it may name
    /// what is true of the pair and may not give it an ending.
    ///
    /// This started as a rule that grief days got no lines at all, which made the
    /// Book quietest on the nights it could do the most good. Naming a connection
    /// is not closing one: what a hard page must never do is explain, resolve or
    /// brighten, and none of those is the same as paying attention.
    var holdsOpen: Bool = false

    init(kind: Kind, evidenceIDs: [String], pivot: String? = nil, holdsOpen: Bool = false) {
        self.kind = kind
        self.evidenceIDs = evidenceIDs
        self.pivot = pivot
        self.holdsOpen = holdsOpen
    }
}

/// What the page is permitted to *do* with its material. Not what it means.
enum SceneTransformation: String, Codable, Equatable, CaseIterable {
    /// Two things set beside each other, with the relation left to the reader.
    case juxtaposition
    /// Something is recognised as having happened before.
    case recognition
    /// The situation is made harder, not resolved.
    case complication
    /// A return to something earlier, changed.
    case ret
    /// Something is declined, and the declining is the event.
    case refusal
    /// The page reports and does not transform. A legitimate night.
    case none
}

/// How the fictional world relates to the reader's day tonight.
///
/// `independent` exists because the world had no life of its own: 80 of 81
/// world strings took the reader's noun as an argument, so the Academy could
/// never do anything until a coffee mug authorised it. A world that only ever
/// mirrors the reader is not a world beyond them; it is a flattering surface.
enum WorldBeatMode: String, Codable, Equatable, CaseIterable {
    /// Something happens in the world whether or not the reader supplied a
    /// matching noun.
    case independent
    /// The reader's detail genuinely crosses its path.
    case intersecting
    /// The two worlds do different things beside each other.
    case counterpoint
    /// They resemble one another, with no claim of cause.
    case echoing
}

/// A canonical piece of the world's own business.
///
/// `fact` is world material the renderer may develop - it is never reader
/// biography, and it is never a sentence to print verbatim.
struct SceneWorldBeat: Equatable, Codable {
    var id: String
    var mode: WorldBeatMode
    var fact: String
    /// The continuity thread this belongs to, when it belongs to one.
    var threadID: String?
    /// Which kept fiction this crosses, when the mode is `intersecting`. Without
    /// it "the reader's detail genuinely crosses its path" was an instruction
    /// with no path named, and a renderer had to guess which one.
    var crossesEvidenceID: String?
}

/// Something the reader came back to.
///
/// This is the record of the transformation. In a real month the reader walked
/// back past a chair to see if it was still there, bought the recorder they had
/// seen in a window, and began taking a rerouted street on purpose. The engine
/// noticed none of it and invented frost on a window instead. A return is the
/// reader's own evidence that they have started living differently, and it
/// outranks anything the Book can invent.
struct SceneReturn: Equatable, Codable {
    var evidenceID: String
    var priorPageID: String
    var priorText: String
    var daysSince: Int
    /// Whether this return is the night's spine rather than a passing echo.
    var isSpine: Bool
}

/// What the last few nights looked like, so this one can differ on purpose.
///
/// The engine already carried recent-move ages and prose memory, but only ever
/// to *avoid repeating* — never to deliberately vary. Across thirty nights that
/// produced 17 titles in one mould, 22 pages with the same paragraph count, and
/// five blank days rendering the same page byte for byte. In a printed volume
/// that is five identical pages.
struct SceneShapeMemory: Equatable, Codable {
    var recentTitleShapes: [String]
    var recentParagraphCounts: [Int]
    var recentClosingShapes: [String]
    var recentOpeningPostures: [String]

    static let empty = SceneShapeMemory(
        recentTitleShapes: [],
        recentParagraphCounts: [],
        recentClosingShapes: [],
        recentOpeningPostures: []
    )
}

/// What the page should leave behind for tomorrow to answer.
///
/// Persisted only from what survives into the winning verified page, so the
/// Book never promises itself something it did not actually say.
struct SceneResidueIntent: Equatable, Codable {
    var openedRelationship: String?
    var advancedWorldThread: String?
    var salientDetail: String?
    var leftUnresolved: [String]

    static let empty = SceneResidueIntent(
        openedRelationship: nil,
        advancedWorldThread: nil,
        salientDetail: nil,
        leftUnresolved: []
    )
}

/// The whole decision.
struct BraidScenePlan: Equatable, Codable {
    var dayID: String
    var evidence: [SceneEvidence]
    var placements: [ScenePlacement]
    /// Pairings the page may draw a line between. Never more than a few: a page
    /// that relates everything to everything is a conspiracy board.
    var relations: [SceneRelation] = []
    /// The atom the page is about. Nil on a night with nothing to be about,
    /// which is a real night and not a failure.
    var anchorEvidenceID: String?
    var form: String
    var motion: String
    var pressure: String
    var scale: String
    var transformation: SceneTransformation
    var worldBeat: SceneWorldBeat?
    /// Further world business, on a night the reader kept nothing.
    ///
    /// A day nobody opened the Book is still a day the Book had. Flipping back
    /// to one should find the Academy carrying on: the reader is not the only
    /// thing happening. On a night with receipts these stay empty, because the
    /// world is a counterweight and not the subject.
    var quietDayBeats: [SceneWorldBeat] = []
    /// Something of the reader's own from weeks ago, on a night they kept
    /// nothing. The Book rereads itself when it has nothing new to read.
    var rememberedEvidenceID: String?
    /// Whether the reader kept nothing today.
    ///
    /// Decided before anything is remembered, because the remembered line is
    /// the reader's own material and would otherwise make a closed day look
    /// like an open one - which is exactly what happened, and the Book quietly
    /// went back to writing an ordinary page about a day that never occurred.
    var isQuietDay: Bool = false
    var carriedReturn: SceneReturn?
    /// Atoms that must not be given an ending. The shadow laws in one field.
    var mustRemainUnresolved: [String]
    var earnedWords: ClosedRange<Int>
    var shape: SceneShapeMemory
    var intendedResidue: SceneResidueIntent
    /// What last night actually left behind, read from the page that won rather
    /// than from what its plan hoped for. This is the half of the loop that
    /// makes the braid part of the transformation instead of a record of it:
    /// tonight can answer yesterday, or decline to.
    var answering: SceneResidueIntent?

    func evidence(for id: String) -> SceneEvidence? {
        evidence.first { $0.id == id }
    }

    func placement(of id: String) -> SceneJob? {
        placements.first { $0.evidenceID == id }?.job
    }

    var anchor: SceneEvidence? {
        anchorEvidenceID.flatMap(evidence(for:))
    }

    /// Atoms a claim about the reader's life may be made from.
    var livedEvidence: [SceneEvidence] {
        evidence.filter(\.isAboutTheReadersLife)
    }

    /// The residue tags for the claims that actually survived onto the page.
    ///
    /// A plan can intend a relation the renderer never wrote, so the intent is
    /// filtered by what the verifier accepted. Tomorrow answers the page, not
    /// the plan.
    func residueTags(surviving claims: [BraidClaim]) -> [String] {
        var tags: [String] = []
        if let relation = intendedResidue.openedRelationship,
           claims.contains(where: { $0.realm == .book }) {
            tags.append("braid-residue-relation:\(relation)")
        }
        if !intendedResidue.leftUnresolved.isEmpty {
            // A marker, not the material. Tomorrow needs to know the Book held
            // something open; it does not need the sentence back.
            tags.append("braid-residue-open")
        }
        if let salient = intendedResidue.salientDetail,
           let anchorEvidenceID,
           claims.contains(where: { $0.sourceIDs.contains(anchorEvidenceID) }) {
            // Clipped: a tag is an index entry, not a paragraph.
            tags.append("braid-residue-salient:\(String(salient.prefix(120)))")
        }
        return tags
    }

    /// A stable, prose-free rendering, so the *decision* can be golden-tested
    /// without golden-testing any sentence. This is the artifact the bench
    /// should be arguing about.
    var summary: String {
        var lines: [String] = [
            "day \(dayID)",
            "form \(form) · motion \(motion) · pressure \(pressure) · scale \(scale)",
            "transformation \(transformation.rawValue)",
            "earned \(earnedWords.lowerBound)-\(earnedWords.upperBound) words"
        ]
        if let anchorEvidenceID { lines.append("anchor \(anchorEvidenceID)") }
        for placement in placements.sorted(by: { $0.evidenceID < $1.evidenceID }) {
            let atom = evidence(for: placement.evidenceID)
            lines.append(
                "  \(placement.job.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0))"
                    + "\(placement.evidenceID)  [\(atom?.kind.rawValue ?? "?")]"
            )
        }
        for relation in relations {
            lines.append(
                "  line        \(relation.evidenceIDs.joined(separator: "+"))  [\(relation.kind.rawValue)"
                    + (relation.pivot.map { ": \($0)" } ?? "") + "]"
            )
        }
        if let worldBeat {
            lines.append("world \(worldBeat.mode.rawValue) · \(worldBeat.id)")
        } else {
            lines.append("world none")
        }
        if let carriedReturn {
            lines.append(
                "return \(carriedReturn.evidenceID) after \(carriedReturn.daysSince)d"
                    + (carriedReturn.isSpine ? " · spine" : "")
            )
        }
        if !mustRemainUnresolved.isEmpty {
            lines.append("unresolved \(mustRemainUnresolved.sorted().joined(separator: " "))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Building the plan

/// Derives tonight's decision from the machinery that already makes it.
///
/// Deliberately a refactor rather than a second brain. `nightlyStoryScore`
/// already chooses which receipts are on the page, the form, the motion, the
/// pressure and the scale; `taleReading` already sizes the night. Those
/// decisions were simply never written down anywhere a renderer other than the
/// house writer could read them. This writes them down.
///
/// Fields whose adapters arrive later - the world beat, the cross-night return,
/// the residue - exist in the schema now and are populated as those adapters
/// land. Leaving them out until then would mean redesigning the plan three
/// times.
enum BraidScenePlanBuilder {
    static func plan(
        for day: BookDay,
        context: BraidPromptBuilder.Context = .empty,
        archive: [BookDay] = [],
        shape: SceneShapeMemory? = nil,
        calendar: Calendar = .current
    ) -> BraidScenePlan {
        let prepared = DeterministicBraidwright.preparedContext(for: day, context: context)
        let reading = prepared.taleReading
            ?? prepared.storyScore?.taleReading
            ?? BraidPromptBuilder.taleReading(for: day, context: context)
        let score = prepared.storyScore

        let pages = BraidPromptBuilder.braidEligiblePages(in: day)
        let byID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })

        var evidence: [SceneEvidence] = []
        for page in pages {
            evidence += atoms(in: page, context: context, now: day.date)
        }

        // Which atoms the score actually selected, and what job each is doing.
        // A receipt the score did not select is not on the page at all: it is
        // material the night did not have room for, not a witness.
        let livedPageIDs = score.map { Set($0.livedBeats.map(\.pageID)) } ?? []
        let fictionPageIDs = Set(
            ([score?.fictionBeat].compactMap { $0 } + (score?.additionalFictionBeats ?? []))
                .map(\.pageID)
        )
        let selected = evidence.filter {
            livedPageIDs.contains($0.pageID) || fictionPageIDs.contains($0.pageID)
        }

        let anchorID = anchorEvidenceID(from: selected, score: score, pages: byID)
        let placements = placements(for: selected, anchorID: anchorID, reading: reading)
        let transformationChoice = transformation(for: reading, score: score)

        var plan = BraidScenePlan(
            dayID: day.id,
            evidence: evidence,
            placements: placements,
            relations: relations(among: selected, leaveOpen: Set(selected.filter(\.isUnclearedShadow).map(\.id))),
            anchorEvidenceID: anchorID,
            form: reading.storyForm.rawValue,
            motion: reading.motion.rawValue,
            pressure: reading.pressure.rawValue,
            scale: reading.scale.rawValue,
            transformation: transformationChoice,
            worldBeat: nil,
            // Defaults to the archive the context is already carrying, so a
            // caller cannot silently disable cross-night reading by forgetting
            // an argument. That is not hypothetical: the first version of this
            // took the archive as a parameter, nothing passed it, and the whole
            // feature was inert in production while its tests passed.
            carriedReturn: carriedReturn(
                tonight: selected,
                archive: archive.isEmpty ? context.recentDays : archive,
                context: context,
                now: day.date,
                calendar: calendar
            ),
            mustRemainUnresolved: selected.filter(\.isUnclearedShadow).map(\.id).sorted(),
            earnedWords: earnedWords(
                for: selected, reading: reading,
                relations: relations(among: selected, leaveOpen: Set(selected.filter(\.isUnclearedShadow).map(\.id)))),
            shape: shape ?? shapeMemory(
                from: archive.isEmpty ? context.recentDays : archive,
                before: day.date
            ),
            intendedResidue: intendedResidue(
                anchor: anchorID,
                evidence: evidence,
                transformation: transformationChoice,
                unresolved: selected.filter(\.isUnclearedShadow).map(\.id).sorted()
            ),
            answering: residue(
                leftBy: archive.isEmpty ? context.recentDays : archive,
                before: day.date
            )
        )
        // Assigned after construction because the mode is read off the night the
        // plan describes: a page holding hard material gets the world beside it
        // and never about it.
        // A closed day is not an empty one.
        plan.isQuietDay = selected.isEmpty
        if plan.isQuietDay {
            if let remembered = remembered(
                from: archive.isEmpty ? context.recentDays : archive,
                context: context,
                before: day.date,
                calendar: calendar
            ) {
                plan.evidence.append(remembered)
                plan.rememberedEvidenceID = remembered.id
            }
            plan.quietDayBeats = SceneWorldCanon.quietDay(
                on: day.date,
                recentDays: archive.isEmpty ? context.recentDays : archive,
                live: SceneWorldCanon.liveFacts(
                    undertakings: context.castUndertakings,
                    worldEvents: context.activeWorldEvents
                )
            )
        }
        plan.worldBeat = SceneWorldCanon.beat(
            for: plan,
            recentDays: archive.isEmpty ? context.recentDays : archive,
            on: day.date,
            live: SceneWorldCanon.liveFacts(
                undertakings: context.castUndertakings,
                worldEvents: context.activeWorldEvents
            ),
            continuedElsewhere: plan.answering?.advancedWorldThread
        )
        return plan
    }




    /// What the last few nights looked like.
    ///
    /// Read from the kept braids themselves rather than from intent, because the
    /// question is what the reader *saw*, not what was planned. Over thirty
    /// consecutive nights the old engine produced seventeen titles in one mould,
    /// twenty-two pages with the same paragraph count, and five blank days that
    /// rendered byte for byte identically - which in a printed volume is five
    /// identical pages. None of that was repetition the engine could see,
    /// because it only ever asked "have I used this move recently", never "does
    /// this page look like the last one".
    static func shapeMemory(from archive: [BookDay], before now: Date, limit: Int = 5)
        -> SceneShapeMemory {
        let braids = archive
            .filter { $0.date < now }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .flatMap { $0.pages }
            .filter { $0.type == .bookOfYou }

        var titles: [String] = []
        var paragraphs: [Int] = []
        var closings: [String] = []
        var openings: [String] = []

        for braid in braids {
            let blocks = braid.userInput
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard let title = blocks.first else { continue }
            titles.append(titleShape(of: title))
            paragraphs.append(max(0, blocks.count - 1))
            if let last = blocks.last, last != title {
                closings.append(closingShape(of: last))
            }
            if blocks.count > 1 { openings.append(openingPosture(of: blocks[1])) }
        }
        return SceneShapeMemory(
            recentTitleShapes: titles,
            recentParagraphCounts: paragraphs,
            recentClosingShapes: closings,
            recentOpeningPostures: openings
        )
    }

    /// A mould rather than a title: "The Bakery Saw the Fox" and "The Mug Saw
    /// It" are the same shape, and that is the thing a reader notices by night
    /// four.
    private static func titleShape(of title: String) -> String {
        let words = title.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first?.lowercased() else { return "empty" }
        let verbs = ["saw", "kept", "answered", "crossed", "charged", "wanted", "made", "would"]
        let verb = words.first { verbs.contains($0.lowercased()) }?.lowercased() ?? "none"
        return "\(first)-\(verb)-\(words.count)"
    }

    private static func closingShape(of paragraph: String) -> String {
        paragraph.hasPrefix("The Book kept the page:") ? "ritual" : "open"
    }

    private static func openingPosture(of paragraph: String) -> String {
        let first = paragraph.split(whereSeparator: \.isWhitespace).first?.lowercased() ?? ""
        switch first {
        case "you", "your": return "reader"
        case "i", "my": return "book"
        default: return "world"
        }
    }

    /// The length the night earned, from what it actually has to say.
    ///
    /// The band used to be a fixed aspiration per scale, and the writer padded
    /// to reach it. Measured on a nine-page night, raising the floor from 280 to
    /// 380 words added ninety-eight words of which **every one was authored and
    /// none was the reader's** - so a longer page was not a fuller one, it was
    /// the same page with more of the Book in it.
    ///
    /// So the floor is derived from substantial material and the ceiling from
    /// the floor. A thin night is allowed to be short, and a night carrying
    /// something hard is allowed to stop early: nothing here pads.
    static func earnedWords(
        for selected: [SceneEvidence],
        reading: BraidPromptBuilder.TaleReading,
        relations: [SceneRelation] = []
    ) -> ClosedRange<Int> {
        // A fragment is not a beat. "Two coffees and a muffin" is real and it is
        // not twenty-five words of anything.
        let substantial = selected.filter { $0.text.split(whereSeparator: \.isWhitespace).count >= 5 }
        // Two different kinds of short, and they were sharing a band.
        //
        // A night the reader never opened the Book has no material at all, and
        // the closed-day writer was already producing about 110 words against a
        // band that stopped at 90 - there, the band was wrong, not the page.
        //
        // A night that kept one four-word fragment is a different thing. It has
        // material, the material is thin, and it is allowed to be short: padding
        // it out is exactly the filler this whole band exists to refuse.
        if selected.isEmpty { return 90...150 }
        guard !substantial.isEmpty else { return 40...90 }

        // A page is as long as what the reader gave it.
        //
        // This was a flat 26 words per entry, so a night where somebody wrote two
        // hundred words about their father earned exactly what a night of two
        // shopping lists earned. The reader's own supply is the one allowance
        // that cannot become filler: it is already their material, and the page
        // is carrying more of it rather than talking around it. Capped, because
        // one enormous entry is still one evening.
        let fromTheReader = substantial.reduce(0) { total, atom in
            let words = atom.text.split(whereSeparator: \.isWhitespace).count
            return total + 20 + min(words, 70) * 3 / 5
        }
        // A drawn line rests on two facts, so it can be elaborated without
        // inventing anything. This is the only other allowance that buys
        // sentences *about the reader* rather than sentences about the Book,
        // which is why length is licensed per relation and not per hundred words.
        let perRelation = 30
        let bookVoice = 34
        let earned = fromTheReader + relations.count * perRelation + bookVoice
        let ceilingRoom = 60 + relations.count * 25
        // The scale's own ceiling is a judgement about the night's weight, so it
        // still caps - but it is raised by what the reader supplied, because a
        // glimpse they wrote three paragraphs about is not a glimpse.
        let room = relations.count * perRelation + max(0, fromTheReader - substantial.count * 26)
        let floor = min(reading.scale.targetWordBand.upperBound + room, earned)
        let ceiling = min(
            reading.scale.targetWordBand.upperBound + ceilingRoom, Int(Double(floor) * 1.7))
        return max(40, floor)...max(90, ceiling)
    }


    /// What tonight should leave behind.
    ///
    /// Only ever what the page decided, never a promise about what it means. The
    /// residue is the Book's own side of the loop - what it opened, which world
    /// thread it moved, which detail it made salient - and tomorrow may answer it
    /// or leave it.
    private static func intendedResidue(
        anchor: String?,
        evidence: [SceneEvidence],
        transformation: SceneTransformation,
        unresolved: [String]
    ) -> SceneResidueIntent {
        SceneResidueIntent(
            openedRelationship: transformation == .none ? nil : transformation.rawValue,
            advancedWorldThread: nil,
            salientDetail: anchor.flatMap { id in
                evidence.first { $0.id == id }?.text
            },
            leftUnresolved: unresolved
        )
    }

    /// What last night left, read from the page that won.
    ///
    /// Deliberately from the stamps rather than from a stored plan: a page can
    /// lose, be rewritten, or be refused, and a residue built from intent would
    /// have the Book answering something it never said. `braid-claim:world:` and
    /// `braid-residue-salient:` are records of what actually reached the reader.
    static func residue(leftBy archive: [BookDay], before now: Date) -> SceneResidueIntent? {
        guard let braid = archive
            .filter({ $0.date < now })
            .sorted(by: { $0.date > $1.date })
            .flatMap({ $0.pages })
            .first(where: { $0.type == .bookOfYou })
        else { return nil }

        func value(_ prefix: String) -> String? {
            braid.tags.first { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        let world = value("braid-claim:world:")
        let salient = value("braid-residue-salient:")
        let relation = value("braid-residue-relation:")
        // What was left open, so tomorrow knows the Book has already sat with
        // something and did not resolve it. Carried as a count rather than as
        // the material: the sentences themselves belong to the page they were
        // written on, and hauling grief forward as a quotable string is how a
        // Book starts reminding somebody of their worst week.
        let open = braid.tags
            .filter { $0.hasPrefix("braid-residue-open") }
            .map { _ in "open" }
        guard world != nil || salient != nil || relation != nil || !open.isEmpty else {
            return nil
        }
        return SceneResidueIntent(
            openedRelationship: relation,
            advancedWorldThread: world,
            salientDetail: salient,
            leftUnresolved: open
        )
    }

    /// What the reader came back to.
    ///
    /// This is the measurement that reframed the whole project. A simulated
    /// month held five through-lines in the reader's own material - a chair with
    /// a sign on it that they walked back to see, a recorder they noticed in a
    /// window and later bought, a coin lost through a hole in a pocket, apples
    /// cooked down and finished, a rerouted street they began taking on purpose
    /// - and the Book connected **none** of them. It invented frost on a window
    /// instead, and repeated it four nights running.
    ///
    /// Detection is mechanical on purpose. A shared *distinctive* word between
    /// tonight and an earlier night is checkable; "these both feel like
    /// endings" is a horoscope. If this ever starts detecting meaning, it has
    /// become the thing the whole design exists to avoid.
    static func carriedReturn(
        tonight: [SceneEvidence],
        archive: [BookDay],
        context: BraidPromptBuilder.Context,
        now: Date,
        calendar: Calendar
    ) -> SceneReturn? {
        guard !archive.isEmpty, !tonight.isEmpty else { return nil }

        // Two days is the floor. A thing mentioned again tomorrow is a
        // continuation; a thing that comes back after a week is a return, and
        // the reader is the one who brought it back.
        var earlier: [(atom: SceneEvidence, days: Int)] = []
        for archived in archive {
            let days = calendar.dateComponents([.day], from: archived.date, to: now).day ?? 0
            guard days >= 2, days <= 30 else { continue }
            for page in BraidPromptBuilder.braidEligiblePages(in: archived) {
                for atom in atoms(in: page, context: context, now: archived.date)
                where atom.isAboutTheReadersLife {
                    earlier.append((atom, days))
                }
            }
        }
        guard !earlier.isEmpty else { return nil }

        // How many separate earlier days each word turns up on. A word the
        // reader uses constantly is not a return; it is their vocabulary.
        var daysPerWord: [String: Set<Int>] = [:]
        for (atom, days) in earlier {
            for word in distinctiveWords(in: atom.text) {
                daysPerWord[word, default: []].insert(days)
            }
        }

        var best: (SceneReturn, rarity: Int)?
        for atom in tonight where atom.isAboutTheReadersLife {
            let words = distinctiveWords(in: atom.text)
            guard !words.isEmpty else { continue }
            for (prior, days) in earlier {
                let shared = words.intersection(distinctiveWords(in: prior.text))
                    .filter { (daysPerWord[$0]?.count ?? 0) <= 2 }
                guard !shared.isEmpty else { continue }
                let rarity = shared.map { daysPerWord[$0]?.count ?? 9 }.min() ?? 9
                let candidate = SceneReturn(
                    evidenceID: atom.id,
                    priorPageID: prior.pageID,
                    priorText: prior.text,
                    daysSince: days,
                    // A gap the reader had to cross deliberately. Coming back to
                    // something after a week is the page's business; after two
                    // days it is an echo.
                    isSpine: days >= 5
                )
                if best == nil || rarity < best!.rarity
                    || (rarity == best!.rarity && days > best!.0.daysSince) {
                    best = (candidate, rarity)
                }
            }
        }
        return best?.0
    }

    /// The *things* in a sentence.
    ///
    /// Nouns only, and that restriction is the difference between a return and a
    /// coincidence of vocabulary. Matching on any content word found "I have
    /// never been to" beside "I have never seen" and called it a return; it also
    /// paired "I bought the recorder" with "Bought apples" on the strength of
    /// "bought", and "the pocket had a hole" with "apples that turned out" on
    /// "turned". None of those is a thing coming back. A recorder is.
    private static func distinctiveWords(in text: String) -> Set<String> {
        let content = BraidRevisionVerifier.contentWords(in: text)
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns = Set<String>()
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            guard tag == .noun else { return true }
            let word = String(text[range])
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()
            if word.count > 3 { nouns.insert(word) }
            return true
        }
        return nouns.intersection(content).subtracting(returnStopwords)
        #else
        return content.filter { $0.count > 3 }.subtracting(returnStopwords)
        #endif
    }

    private static let returnStopwords: Set<String> = [
        "again", "back", "because", "before", "could", "still", "then", "there",
        "this", "that", "today", "tonight", "went", "gone", "came", "come",
        "made", "make", "kept", "keep", "just", "like", "much", "very", "when",
        "with", "while", "after", "about", "into", "onto", "over", "under",
        "would", "should", "might", "were", "wasn", "didn", "doesn", "have",
        "having", "thing", "things", "something", "anything", "nothing",
        "morning", "evening", "night", "week", "weeks", "days", "hours"
    ]


    /// Pairings worth a sentence.
    ///
    /// Capped hard. A page that draws a line between every pair of facts is not
    /// a braid, it is a conspiracy board, and the reader will feel the Book
    /// straining.
    static func relations(
        among selected: [SceneEvidence],
        leaveOpen: Set<String> = [],
        limit: Int = 3
    ) -> [SceneRelation] {
        let lived = selected.filter(\.isAboutTheReadersLife)
        guard lived.count >= 2 else { return [] }

        var specific: [SceneRelation] = []
        var used = Set<String>()

        for (index, left) in lived.enumerated() {
            for right in lived.dropFirst(index + 1) {
                guard !used.contains(left.id), !used.contains(right.id) else { continue }
                let pair = [left.id, right.id]

                if let noun = sharedThing(left.text, right.text) {
                    specific.append(SceneRelation(
                            kind: .sharedThing, evidenceIDs: pair, pivot: noun,
                            holdsOpen: !leaveOpen.isDisjoint(with: pair)))
                    used.insert(left.id)
                    used.insert(right.id)
                    continue
                }
                if let name = sharedPerson(left.text, right.text) {
                    specific.append(SceneRelation(
                            kind: .sharedPerson, evidenceIDs: pair, pivot: name,
                            holdsOpen: !leaveOpen.isDisjoint(with: pair)))
                    used.insert(left.id)
                    used.insert(right.id)
                    continue
                }
            }
        }

        var found = Array(specific.prefix(limit))

        // At most one span of the day, and only ever between the day's first and
        // last thing.
        //
        // This nearly shipped as a filler engine. Any two entries six hours apart
        // qualify, so on the bench it fired for twelve of fifteen pairings and
        // brought a word allowance with it - a machine for making pages longer by
        // observing that mornings precede evenings. Held to the ends of the day
        // it says something a reader can feel, and only once.
        if found.count < limit,
           let first = lived.min(by: { $0.occurredAt < $1.occurredAt }),
           let last = lived.max(by: { $0.occurredAt < $1.occurredAt }),
           first.id != last.id,
           abs(last.occurredAt.timeIntervalSince(first.occurredAt)) / 3_600 >= 6,
           // If either end is already drawn into a more specific line, the span
           // adds nothing but a second sentence about the same entry.
           !used.contains(first.id), !used.contains(last.id) {
            found.append(
                SceneRelation(
                    kind: .acrossTheDay, evidenceIDs: [first.id, last.id], pivot: nil,
                    holdsOpen: !leaveOpen.isDisjoint(with: [first.id, last.id])))
        }
        return found
    }

    /// The same thing in two entries, allowing for one plum and several plums.
    ///
    /// An exact match found one echo in twenty-five bench nights, and a reader
    /// who buys plums in the morning and cooks the plums down at night is not
    /// obliged to use the same number both times.
    private static func sharedThing(_ left: String, _ right: String) -> String? {
        let rightKeys = Set(distinctiveWords(in: right).map(singular))
        return distinctiveWords(in: left)
            .filter { rightKeys.contains(singular($0)) }
            .sorted()
            .first
    }

    private static func singular(_ word: String) -> String {
        guard word.count >= 5 else { return word }
        if word.hasSuffix("sses") || word.hasSuffix("xes") || word.hasSuffix("ches")
            || word.hasSuffix("shes") {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") {
            return String(word.dropLast())
        }
        return word
    }

    private static func sharedPerson(_ left: String, _ right: String) -> String? {
        #if canImport(NaturalLanguage)
        func names(_ text: String) -> Set<String> {
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            var found = Set<String>()
            tagger.enumerateTags(
                in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                options: [.omitWhitespace, .omitPunctuation, .joinNames]
            ) { tag, range in
                if tag == .personalName { found.insert(String(text[range])) }
                return true
            }
            return found
        }
        return names(left).intersection(names(right)).sorted().first
        #else
        return nil
        #endif
    }

    /// Something the reader wrote a while ago, for a day they wrote nothing.
    ///
    /// A Book with nothing new to read rereads. This is the difference between a
    /// closed day that is only the Academy's weather and one that is the Book
    /// keeping somebody company - and because the old line joins the evidence
    /// properly, a claim about it is checked like any other rather than being
    /// quoted on trust.
    ///
    /// Far enough back that it is a memory rather than a continuation, and
    /// never hard material: a day nobody opened the Book is not the day to hand
    /// somebody their worst week back.
    static func remembered(
        from archive: [BookDay],
        context: BraidPromptBuilder.Context,
        before now: Date,
        calendar: Calendar
    ) -> SceneEvidence? {
        var candidates: [(SceneEvidence, Int)] = []
        for archived in archive {
            let days = calendar.dateComponents([.day], from: archived.date, to: now).day ?? 0
            guard days >= 14, days <= 120 else { continue }
            for page in BraidPromptBuilder.braidEligiblePages(in: archived) {
                for atom in atoms(in: page, context: context, now: archived.date)
                where atom.isAboutTheReadersLife
                    && !atom.isUnclearedShadow
                    && atom.text.split(whereSeparator: \.isWhitespace).count >= 6 {
                    candidates.append((atom, days))
                }
            }
        }
        guard !candidates.isEmpty else { return nil }
        // Deterministic, and stepped by the day so a run of closed days does not
        // reread the same sentence.
        let dayNumber = Int(now.timeIntervalSince1970 / 86_400)
        return candidates[((dayNumber % candidates.count) + candidates.count) % candidates.count].0
    }

    /// One atom per reader contribution, plus one for a kept fiction scene.
    ///
    /// The index is the position within the page's own contributions, which is
    /// derived deterministically from the page's content, so `page-market#0`
    /// means the same atom every time it is read.
    private static func atoms(
        in page: BookPage,
        context: BraidPromptBuilder.Context,
        now: Date
    ) -> [SceneEvidence] {
        let shelf = ReaderShelf.of(page)
        let uncleared = shelf == .shadow
            && context.readerStory.shadowPermission != .knowButNeverWrite
            && !context.readerStory.shadowMayTakeTaleForm(keptAt: page.createdAt, now: now)

        if BraidPromptBuilder.isLabyrinthReceipt(page) {
            let text = DeterministicBraidwright.strippedScaffolding(
                page.userInput.nonEmpty ?? page.promptText.nonEmpty ?? ""
            )
            guard !text.isEmpty else { return [] }
            // Same grain and same id rule as lived material, so an id can be
            // parsed by one rule wherever it came from, and a world claim is
            // checkable per sentence too.
            return sentences(in: text).enumerated().map { offset, sentence in
                SceneEvidence(
                    id: "\(page.id)#0.\(offset)",
                    pageID: page.id,
                    kind: .keptFiction,
                    text: sentence,
                    occurredAt: page.createdAt,
                    isUnclearedShadow: false
                )
            }
        }

        return page.readerContributions.enumerated().flatMap { index, contribution -> [SceneEvidence] in
            let kind: SceneEvidence.Kind
            switch contribution.kind {
            case .sentence: kind = .writtenLine
            case .fictionChoice: kind = .fictionChoice
            case .photograph: kind = .photograph
            case .audioRecording: kind = .voiceRecording
            }
            let raw = contribution.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? mediaText(for: contribution, in: page)
            // Composed page bodies carry field separators, turn markers and
            // upstream mid-sentence clips. Handing those to a renderer as a
            // *locked fact* is worse than printing them: "--- They fronted you
            // the." would be a thing the reader is told they did.
            let text = raw.map(DeterministicBraidwright.strippedScaffolding)
            guard let text, !text.isEmpty else { return [] }
            // A contribution is not fine enough to check a claim against.
            // `readerContributions` appends a whole typed entry as one
            // `.sentence`, so "I did not call Sam. I watered the plants
            // instead." is a single contribution holding two facts - and a
            // rewrite that recombines them into "you called Sam about the
            // plants" would preserve every word of it while inventing the
            // evening. One atom per sentence is the grain a claim can be
            // audited at.
            return sentences(in: text).enumerated().map { offset, sentence in
                SceneEvidence(
                    id: "\(page.id)#\(index).\(offset)",
                    pageID: page.id,
                    kind: kind,
                    text: sentence,
                    occurredAt: page.createdAt,
                    isUnclearedShadow: uncleared
                )
            }
        }
    }

    /// Deterministic sentence split. Keeps the terminator, because losing a
    /// question mark loses whether the reader was asking.
    private static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 1 { result.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if tail.count > 1 { result.append(tail) }
        return result.isEmpty ? [text] : result
    }

    /// A photograph's caption or a recording's transcript is the reader's own
    /// words about it, and is the whole of what some evenings contain.
    private static func mediaText(
        for contribution: BookPage.ReaderContribution,
        in page: BookPage
    ) -> String? {
        guard let assetID = contribution.mediaAssetID,
              let asset = page.mediaAssets.first(where: { $0.id == assetID }) else {
            return BraidPromptBuilder.mediaEvidence(for: page)
        }
        return asset.metadata[BookPageMediaAsset.voiceTranscriptMetadataKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? asset.caption.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// The anchor is an atom, not a noun.
    ///
    /// The old engine's anchor was a *word* pulled out of a sentence, which is
    /// how a calorie log anchored a night on "the beers" and a photograph of a
    /// heron produced "the standing". An atom cannot be a participle.
    private static func anchorEvidenceID(
        from selected: [SceneEvidence],
        score: BraidPromptBuilder.NightlyStoryScore?,
        pages: [String: BookPage]
    ) -> String? {
        // A One-Sentence Souvenir is the reader stopping to choose one true
        // line out of a whole day. If they chose one, it owns the page.
        // Hard material the reader has not cleared can never be what the page
        // is *about*: anchoring is a dramatic job, and the shadow laws say the
        // Book may witness such a thing and may not make a tale of it.
        let eligible = selected.filter { !$0.isUnclearedShadow }
        if let souvenir = eligible.first(where: {
            pages[$0.pageID]?.type == .souvenir && $0.kind == .writtenLine
        }) {
            return souvenir.id
        }
        if let leadPageID = score?.livedBeats.first?.pageID,
           let lead = eligible.first(where: { $0.pageID == leadPageID }) {
            return lead.id
        }
        return eligible.first(where: \.isAboutTheReadersLife)?.id ?? eligible.first?.id
    }

    /// Most atoms are witnesses. A night where everything is dramatic is a
    /// night that is lying about itself.
    private static func placements(
        for selected: [SceneEvidence],
        anchorID: String?,
        reading: BraidPromptBuilder.TaleReading
    ) -> [ScenePlacement] {
        selected.map { atom in
            if atom.id == anchorID { return ScenePlacement(evidenceID: atom.id, job: .anchor) }
            // Kept fiction is what enters from the Book's world; that is its
            // job by construction rather than by guesswork.
            if atom.kind == .keptFiction {
                return ScenePlacement(evidenceID: atom.id, job: .disturbance)
            }
            // Hard material is never given a dramatic role. It is witnessed.
            if atom.isUnclearedShadow {
                return ScenePlacement(evidenceID: atom.id, job: .witness)
            }
            return ScenePlacement(evidenceID: atom.id, job: .witness)
        }
        .sorted { $0.evidenceID < $1.evidenceID }
    }

    /// What the page may do with its material tonight.
    ///
    /// Read off the motion the night already carries rather than invented, and
    /// deliberately conservative: `none` is a legitimate and common answer.
    private static func transformation(
        for reading: BraidPromptBuilder.TaleReading,
        score: BraidPromptBuilder.NightlyStoryScore?
    ) -> SceneTransformation {
        if score?.arc?.movement == .returned { return .ret }
        switch reading.motion {
        case .returnOfSomething, .recurrence: return .ret
        case .repair: return .recognition
        case .refusal: return .refusal
        case .bargain, .crossing: return .complication
        case .encounter: return .juxtaposition
        // A vigil watches. Watching is not a transformation, and pretending
        // otherwise is how a quiet night gets a plot it did not have.
        case .vigil: return .none
        }
    }
}

// MARK: - What a renderer must hand back

/// One sentence, and the claim it is making.
///
/// A wall of prose cannot be checked. Free-form drafts entered selection as
/// plain text, filtered only for register failures, and not one of the audit's
/// nineteen issues asked what a draft had *added* - so a page keeping "plums",
/// "landlord" and "lido" could invent an afternoon and win the night. A
/// renderer that wants that freedom has to say what each sentence is claiming
/// and where the claim comes from.
struct BraidClaim: Equatable {
    enum Realm: String, Equatable, CaseIterable {
        /// A claim about the reader's life. The strictest law.
        case lived
        /// The Book's own reaction. May invent, within the plan's licence, and
        /// may never assert something happened to the reader.
        case book
        /// The fictional world's own business. May develop supplied continuity
        /// and may never become reader biography.
        case world
        /// The ritual closing line. Locked.
        case colophon
    }

    var realm: Realm
    /// Evidence ids this sentence claims to rest on. Exactly one for `lived`.
    var sourceIDs: [String]
    var text: String
}

/// Why a draft was refused. A rejected draft costs nothing: the house page is
/// still standing underneath it, so every one of these fails closed.
enum BraidDraftRejection: String, Error, Equatable, CaseIterable {
    case emptyDraft
    /// A sentence with no marker at all. The draft is refused rather than the
    /// sentence being guessed at - an unmarked line whose vocabulary happens to
    /// overlap a receipt would otherwise pass as lived.
    case missingMarker
    case malformedMarker
    case unknownEvidenceID
    /// A lived claim on fiction, or a world claim on the reader's life.
    case wrongRealm
    /// Two sentences claiming the same atom, which is how one fact becomes two
    /// events.
    case duplicateClaim
    /// A lived sentence saying something its atom does not say.
    case inventedContent
    /// A lived sentence that changed whether the thing happened.
    case changedPolarity
    /// A Book or world sentence asserting the reader did something.
    case claimedTheReadersLife
    case missingColophon
}

/// Parses and verifies a rendered draft against the plan it was written from.
///
/// The format is the simplest thing a small local model can hold: one sentence
/// per line, each line beginning with its marker, blank lines preserved as
/// paragraph breaks. Ids contain no spaces, so "first token is the marker, the
/// rest of the line is the sentence" is unambiguous.
///
///     LIVED:bakery#0.0 You walked past the bakery that shut last winter.
///     BOOK:bakery The crow left one instruction beside it.
///     WORLD:academy-toll-strike The eastern stair refused every toll tonight.
///     COLOPHON The Book kept the page: the bakery kept the price.
enum BraidDraftVerifier {
    struct Verified: Equatable {
        var claims: [BraidClaim]
        /// The draft with markers removed, which is what a reader would see.
        var text: String
    }

    /// What a draft cost to make safe.
    struct Salvage: Equatable {
        var verified: Verified
        /// Sentences dropped, and why. A page that lost a line is still a page;
        /// this is what the log should count.
        var dropped: [BraidDraftRejection]
    }

    /// Verify, dropping what cannot be trusted and keeping what can.
    ///
    /// Whole-draft rejection made sense while nothing downstream knew which
    /// sentence was a fact and which was invention. Marked claims mean we know,
    /// so one bad line should not cost a night: a simulated week lost three
    /// pages of seven to a missing marker, an invented feeling, and one invented
    /// participant, and in each case the rest of the draft was true.
    ///
    /// The whole draft still goes if what survives is not a page - no anchor
    /// left, or no closing line.
    static func salvage(
        _ raw: String,
        against plan: BraidScenePlan
    ) -> Result<Salvage, BraidDraftRejection> {
        let lines = raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.contains(where: { !$0.isEmpty }) else { return .failure(.emptyDraft) }

        var claims: [BraidClaim] = []
        var display: [String] = []
        var claimedAtoms = Set<String>()
        var dropped: [BraidDraftRejection] = []

        for line in lines {
            guard !line.isEmpty else {
                display.append("")
                continue
            }
            guard let claim = claim(from: line) else {
                dropped.append(.missingMarker)
                continue
            }
            if let rejection = reject(claim, plan: plan, alreadyClaimed: &claimedAtoms) {
                dropped.append(rejection)
                continue
            }
            claims.append(claim)
            display.append(claim.text)
        }

        guard claims.contains(where: { $0.realm == .colophon }) else {
            return .failure(.missingColophon)
        }
        // A page has to still be about something. If every claim resting on the
        // night's anchor was dropped, what is left is a mood piece with the
        // reader's evening cut out of it, and the floor is the better page.
        if let anchorID = plan.anchorEvidenceID,
           plan.evidence(for: anchorID) != nil,
           !claims.contains(where: { $0.sourceIDs.contains(anchorID) }) {
            return .failure(.inventedContent)
        }
        return .success(
            Salvage(
                verified: Verified(
                    claims: claims,
                    text: display.joined(separator: "\n")
                        .replacingOccurrences(of: "\n\n\n", with: "\n\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                dropped: dropped
            )
        )
    }

    static func verify(
        _ raw: String,
        against plan: BraidScenePlan
    ) -> Result<Verified, BraidDraftRejection> {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.contains(where: { !$0.isEmpty }) else { return .failure(.emptyDraft) }

        var claims: [BraidClaim] = []
        var display: [String] = []
        var claimedAtoms = Set<String>()

        for line in lines {
            guard !line.isEmpty else {
                display.append("")
                continue
            }
            guard let claim = claim(from: line) else { return .failure(.missingMarker) }
            if let rejection = reject(claim, plan: plan, alreadyClaimed: &claimedAtoms) {
                return .failure(rejection)
            }
            claims.append(claim)
            display.append(claim.text)
        }

        guard claims.contains(where: { $0.realm == .colophon }) else {
            return .failure(.missingColophon)
        }
        return .success(
            Verified(
                claims: claims,
                text: display.joined(separator: "\n")
                    .replacingOccurrences(of: "\n\n\n", with: "\n\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    private static func claim(from line: String) -> BraidClaim? {
        guard let split = line.firstIndex(of: " ") else {
            // A marker with no sentence after it is still a marker; the colophon
            // is the only line allowed to be short, and it is not this short.
            return line == "COLOPHON" ? BraidClaim(realm: .colophon, sourceIDs: [], text: "") : nil
        }
        let marker = String(line[line.startIndex..<split])
        let text = String(line[line.index(after: split)...]).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        if marker == "COLOPHON" {
            return BraidClaim(realm: .colophon, sourceIDs: [], text: text)
        }
        let parts = marker.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let realm = BraidClaim.Realm(rawValue: parts[0].lowercased()),
              realm != .colophon else { return nil }
        let ids = parts[1]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return BraidClaim(realm: realm, sourceIDs: ids, text: text)
    }

    private static func reject(
        _ claim: BraidClaim,
        plan: BraidScenePlan,
        alreadyClaimed: inout Set<String>
    ) -> BraidDraftRejection? {
        switch claim.realm {
        case .colophon:
            return nil

        case .lived:
            // One sentence claims one atom. Two atoms in one claim is how "I did
            // not call Sam" and "I watered the plants" become "you called Sam
            // about the plants".
            guard claim.sourceIDs.count == 1 else { return .malformedMarker }
            let id = claim.sourceIDs[0]
            guard let atom = plan.evidence(for: id) else { return .unknownEvidenceID }
            guard atom.isAboutTheReadersLife else { return .wrongRealm }
            guard alreadyClaimed.insert(id).inserted else { return .duplicateClaim }
            guard BraidRevisionVerifier.preservesPolarity(claim.text, of: atom.text) else {
                return .changedPolarity
            }
            guard BraidRevisionVerifier.preservesFacts(claim.text, of: atom.text) else {
                return .inventedContent
            }
            return nil

        case .world:
            guard !claim.sourceIDs.isEmpty else { return .malformedMarker }
            for id in claim.sourceIDs {
                // A world claim may rest on the plan's world beat or on kept
                // fiction. It may never rest on the reader's own life.
                if let atom = plan.evidence(for: id) {
                    if atom.isAboutTheReadersLife { return .wrongRealm }
                } else if plan.worldBeat?.id != id,
                          !plan.quietDayBeats.contains(where: { $0.id == id }) {
                    return .unknownEvidenceID
                }
            }
            return assertsSomethingHappenedToTheReader(claim.text) ? .claimedTheReadersLife : nil

        case .book:
            // A Book sentence may rest on nothing - the Book is allowed its own
            // asides - but any id it does name has to be a real atom. Loose
            // labels would be untraceable decoration that looked like sourcing.
            for id in claim.sourceIDs where plan.evidence(for: id) == nil {
                return .unknownEvidenceID
            }
            return assertsSomethingHappenedToTheReader(claim.text) ? .claimedTheReadersLife : nil
        }
    }

    /// Whether a sentence says the reader did something.
    ///
    /// This is the specific hole: a draft could preserve every supplied noun and
    /// still add "you cried beside the pool". Only a `lived` claim, checked
    /// against its own atom, may say what the reader did — so any Book or world
    /// sentence that puts the reader in the past tense is refused.
    ///
    /// Deliberately strict. A refused draft costs nothing, because the house
    /// page is still there; a missed invention is a lie about somebody's day.
    /// The Book may still address the reader in the present ("which tells you
    /// what I expect") because that reports on the Book, not on their evening.
    static func assertsSomethingHappenedToTheReader(_ text: String) -> Bool {
        let words = text
            .lowercased()
            .split { !$0.isLetter && $0 != "'" && $0 != "’" }
            .map(String.init)
        for (index, word) in words.enumerated() where word == "you" || word == "your" {
            for candidate in words.dropFirst(index + 1).prefix(2) {
                if isPastTenseAction(candidate) { return true }
            }
        }
        return false
    }

    private static func isPastTenseAction(_ word: String) -> Bool {
        if irregularPastActions.contains(word) { return true }
        guard word.count > 3, word.hasSuffix("ed") else { return false }
        // "red", "bed", "shed" are not verbs; the length guard covers the short
        // ones and the suffix does the rest.
        return true
    }

    private static let irregularPastActions: Set<String> = [
        "ate", "began", "bought", "broke", "brought", "built", "came", "caught",
        "chose", "cried", "did", "drank", "drove", "fell", "felt", "forgot",
        "found", "gave", "went", "grew", "had", "heard", "held", "kept", "knew",
        "laid", "left", "let", "lost", "made", "met", "paid", "put", "ran",
        "read", "rang", "rode", "said", "sang", "sat", "saw", "sent", "shook",
        "slept", "sold", "spoke", "spent", "stood", "swam", "took", "taught",
        "thought", "threw", "told", "understood", "woke", "wore", "wrote"
    ]
}

// MARK: - The brief

extension BraidScenePlan {
    /// The scene, decided, as a task a small local model can perform.
    ///
    /// The old braid prompt handed Gemma the whole archive and a rulebook:
    /// fifteen evidence lines, provenance gravity, shelf laws, the memory spine,
    /// semantic echoes, radio, world events, the reader's lexicon, their role,
    /// standing tale laws, shadow rules, continuity and style memory. Measured
    /// on a heavy night it came to 20,320 characters against a 21,090 allowance
    /// — 96% full, and full of undigested ingredients. Then we were surprised
    /// the house writer kept winning.
    ///
    /// This hands over a decision instead. Everything the model must not do is
    /// enforced afterwards by `BraidDraftVerifier` rather than argued for here,
    /// which is why this can be short: a refused draft costs nothing, so the
    /// brief does not need to pre-empt every failure in prose.
    /// The form's own prompt line, not its case name. `SHAPE: returnForm` put a
    /// programmer's identifier in front of the model, which is the same slug-in-
    /// prose bug the Book keeps being caught in.
    static func formLine(_ raw: String) -> String {
        guard let form = BraidPromptBuilder.StoryForm(rawValue: raw) else { return raw + "." }
        return form.promptLine
    }

    /// What the pairing is, in words the model can write from - and never what
    /// it means. "Both of these end something" is a horoscope; "the bowl is in
    /// both" is a fact the reader can check.
    static func relationLine(_ relation: SceneRelation) -> String {
        switch relation.kind {
        case .sharedThing:
            return "the same thing is in both: \(relation.pivot ?? "one detail")"
        case .sharedPerson:
            return "\(relation.pivot ?? "the same person") is in both"
        case .acrossTheDay:
            return "one is early and one is late in the same day"
        }
    }

    func brief() -> String {
        var lines: [String] = []

        lines.append("Write tonight's page.")
        lines.append("")
        lines.append("SHAPE: \(Self.formLine(form)) \(motion) under \(pressure) pressure.")
        if let anchor {
            lines.append("ABOUT: \(anchor.text)")
        } else {
            lines.append("ABOUT: nothing in particular. Say so; do not invent a subject.")
        }
        lines.append("DO: \(transformationInstruction)")
        if !relations.isEmpty {
            lines.append("")
            lines.append(
                "DRAW A LINE between each of these pairs. One or two sentences each, marked BOOK with both ids, present tense, saying what is true of the pair and not what it means. This is where the page's length comes from; do not make it up elsewhere.")
            for relation in relations {
                let texts = relation.evidenceIDs.compactMap { evidence(for: $0)?.text }
                guard texts.count == relation.evidenceIDs.count else { continue }
                lines.append("  \(relation.evidenceIDs.joined(separator: ",")) [\(Self.relationLine(relation))]"
                    + (relation.holdsOpen
                        ? "  - notice it and give it no ending; no comfort, no conclusion"
                        : ""))
                for text in texts { lines.append("      \(text)") }
            }
        }
        lines.append("LENGTH: \(earnedWords.lowerBound)-\(earnedWords.upperBound) words.")

        if let worldBeat {
            lines.append("")
            lines.append("THE WORLD, TONIGHT (\(worldBeat.mode.rawValue)): \(worldBeat.fact)")
            lines.append(worldModeInstruction(worldBeat.mode))
        }

        if let carriedReturn, let atom = evidence(for: carriedReturn.evidenceID) {
            lines.append("")
            lines.append(
                "THIS CAME BACK after \(carriedReturn.daysSince) days: \(atom.text)")
            lines.append("Earlier it was: \(carriedReturn.priorText)")
            if carriedReturn.isSpine {
                lines.append("Let the return be what the page is about.")
            }
        }

        if !mustRemainUnresolved.isEmpty {
            lines.append("")
            lines.append(
                "LEAVE OPEN: quote these as they came and give them no ending, no comfort, and no meaning.")
            for id in mustRemainUnresolved.sorted() {
                if let atom = evidence(for: id) { lines.append("  \(id)  \(atom.text)") }
            }
        }

        lines.append("")
        lines.append("FACTS. Each is locked. Rewrite the wording freely; change nothing that happened.")
        for placement in placements.sorted(by: { $0.evidenceID < $1.evidenceID }) {
            guard let atom = evidence(for: placement.evidenceID) else { continue }
            lines.append("  \(atom.id)  [\(placement.job.rawValue)]  \(atom.text)")
        }

        if let answering, let thread = answering.advancedWorldThread {
            lines.append("")
            lines.append(
                "LAST NIGHT the world's \(thread) was already moving. You may carry it on or leave it alone; do not explain it.")
            if let salient = answering.salientDetail {
                lines.append("Last night's page was about: \(salient)")
            }
        }

        if let answering, !answering.leftUnresolved.isEmpty {
            lines.append("")
            lines.append(
                "LAST NIGHT held something open and did not close it. Do not reach back for it, and do not brighten tonight to compensate.")
        }

        if let variation = shapeInstruction {
            lines.append("")
            lines.append(variation)
        }

        lines.append("")
        lines.append(Self.markerContract)
        return lines.joined(separator: "\n")
    }


    /// What not to do again.
    ///
    /// Thirty consecutive nights of the old engine produced seventeen titles in
    /// one mould and twenty-two pages with the same paragraph count. Read one
    /// and it is good; read thirty bound into a volume and the reader learns the
    /// shape by night four and then watches the nouns change inside it. A book
    /// of days has to vary on purpose, not merely avoid repeating a phrase.
    private var shapeInstruction: String? {
        var notes: [String] = []

        if let mould = shape.recentTitleShapes.first,
           shape.recentTitleShapes.prefix(3).allSatisfy({ $0 == mould }) {
            notes.append("The last few titles were built the same way. Build this one differently.")
        }
        let counts = shape.recentParagraphCounts.prefix(3)
        if counts.count == 3, Set(counts).count == 1, let same = counts.first {
            notes.append(
                "The last few pages were \(same) paragraphs each. Do not make this one \(same).")
        }
        if shape.recentOpeningPostures.prefix(3).allSatisfy({ $0 == "reader" }),
           shape.recentOpeningPostures.count >= 3 {
            notes.append("The last few pages all opened on the reader. Open somewhere else.")
        }
        guard !notes.isEmpty else { return nil }
        return (["VARY:"] + notes.map { "  \($0)" }).joined(separator: "\n")
    }

    private var transformationInstruction: String {
        switch transformation {
        case .juxtaposition:
            return "set two of these beside each other and leave the relation to the reader."
        case .recognition:
            return "let something be recognised as having happened before."
        case .complication:
            return "make the situation harder. Do not resolve it."
        case .ret:
            return "return to something earlier and let it have changed."
        case .refusal:
            return "let the refusing be the event."
        case .none:
            return "report the night. No turn is required and none should be invented."
        }
    }

    private func worldModeInstruction(_ mode: WorldBeatMode) -> String {
        switch mode {
        case .independent:
            return "This is the world's own business. Do not connect it to the reader's day."
        case .intersecting:
            return "This genuinely crosses the reader's day. One crossing only."
        case .counterpoint:
            return "Put this beside the reader's day. They are doing different things."
        case .echoing:
            return "This resembles the reader's day. Never say it caused anything."
        }
    }

    /// What the renderer must hand back. Enforced by `BraidDraftVerifier`; this
    /// only has to describe the format, not defend it.
    static let markerContract = """
        FORMAT. One sentence per line. Begin every line with its marker. \
        Blank lines separate paragraphs.
          LIVED:<fact id>   a sentence about the reader's life. Exactly one fact id. \
        Say only what that fact says.
          BOOK:<fact id>    your own reaction. May be impossible. May not say the reader did anything.
          WORLD:<world id>  the world's own business. May not say the reader did anything.
          COLOPHON          one closing line, beginning "The Book kept the page:".
        A line without a marker means the whole page is discarded.
        """
}

// MARK: - The floor

/// The instant, offline renderer.
///
/// It does four things and stops: preserve the facts, realise the primary
/// relation once, carry the world beat, land the form. It does not need
/// hundreds of sentence moulds, and it will not keep them.
///
/// It emits the same marked claims a model has to emit, so the floor is held to
/// exactly the laws the ceiling is held to. That is not tidiness: the reason the
/// old writer could be trusted was that it assembled the page itself, and the
/// reason it could not be *checked* was that nothing downstream knew which
/// sentence was a fact and which was invention. Now everything does.
///
/// Note what is missing: any sentence that interpolates the night's noun. The
/// Book comments on the page rather than on a subject, which is what stops the
/// world orbiting a coffee mug. It is also why this writer needs so little
/// vocabulary - it never has to conjugate anything.
enum BraidSceneWriter {
    static func write(_ plan: BraidScenePlan) -> [BraidClaim] {
        var claims: [BraidClaim] = []

        let ordered = plan.placements
            .compactMap { placement -> (SceneJob, SceneEvidence)? in
                plan.evidence(for: placement.evidenceID).map { (placement.job, $0) }
            }
            .sorted { left, right in
                if left.0 == .anchor { return true }
                if right.0 == .anchor { return false }
                return left.1.occurredAt < right.1.occurredAt
            }

        for (_, atom) in ordered {
            claims.append(
                BraidClaim(
                    realm: atom.isAboutTheReadersLife ? .lived : .world,
                    sourceIDs: [atom.id],
                    text: atom.isAboutTheReadersLife ? secondPerson(atom.text) : atom.text
                )
            )
        }

        // A day the reader kept nothing. The Book had one anyway.
        //
        // Never a reproach, and never a count of days missed. The reader is not
        // in debt to a notebook, and a Book that keeps score is a Book somebody
        // eventually stops opening. It stayed shut, the Academy carried on, and
        // that is worth a page - so a reader flipping back to a week they did
        // not write in finds the world was busy without them.
        if plan.isQuietDay, !plan.quietDayBeats.isEmpty {
            claims.append(
                BraidClaim(realm: .book, sourceIDs: [], text: closedDayLine(on: plan.dayID))
            )
            if let id = plan.rememberedEvidenceID, let atom = plan.evidence(for: id) {
                claims.append(
                    BraidClaim(
                        realm: .book, sourceIDs: [],
                        text: "With nothing new to read I went back a way and read you again."
                    )
                )
                claims.append(
                    BraidClaim(realm: .lived, sourceIDs: [id], text: secondPerson(atom.text))
                )
            }
            for beat in plan.quietDayBeats {
                claims.append(
                    BraidClaim(realm: .world, sourceIDs: [beat.id], text: beat.fact)
                )
            }
            claims.append(
                BraidClaim(realm: .colophon, sourceIDs: [], text: closedDayColophon(on: plan.dayID))
            )
            return claims
        }

        // The pairings the plan found, named concretely and never explained.
        // The floor ships on every night the model's draft cannot be salvaged,
        // so it has to be worth reading on its own; a page that lists four facts
        // and stops is the listing the whole design exists to end.
        //
        // Hard material is witnessed and gets no commentary at all.
        do {
            for relation in plan.relations {
                guard let text = drawnLine(relation, in: plan) else { continue }
                claims.append(
                    BraidClaim(realm: .book, sourceIDs: relation.evidenceIDs, text: text)
                )
            }
            if plan.relations.isEmpty, ordered.count >= 2 {
                claims.append(
                    BraidClaim(
                        realm: .book,
                        sourceIDs: plan.anchorEvidenceID.map { [$0] } ?? [],
                        text: relation(for: plan.transformation)
                    )
                )
            }
        }

        if let beat = plan.worldBeat {
            claims.append(
                BraidClaim(realm: .world, sourceIDs: [beat.id], text: beat.fact)
            )
        }

        claims.append(BraidClaim(realm: .colophon, sourceIDs: [], text: colophon(for: plan)))
        return claims
    }


    /// What the Book says about its own shut day. Rotated by the date so a run
    /// of closed days does not repeat, and phrased so none of them asks where
    /// anybody was.
    private static func closedDayLine(on dayID: String) -> String {
        let lines = [
            "I stayed shut all day and the building did not care for that at all.",
            "Nothing came in today, so I went and had a look at what the rest of the place was doing.",
            "A whole day with my covers together. I filled it. I always fill it.",
            "No hands on me today. The Academy took that as an invitation.",
            "I was closed, which the Stacks treat as permission rather than as an absence.",
            "Quiet day in here. Loud everywhere else, as it turns out."
        ]
        return lines[stableIndex(of: dayID, count: lines.count)]
    }

    private static func closedDayColophon(on dayID: String) -> String {
        let lines = [
            "The Book kept the page: the day happened without either of us, and I wrote it down anyway.",
            "The Book kept the page: nothing of yours today, so here is what the place got up to.",
            "The Book kept the page: I was shut, and the world was not."
        ]
        return "\(lines[stableIndex(of: dayID, count: lines.count)])"
    }

    private static func stableIndex(of value: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    /// The reader's own sentence, turned to face them. Only pronouns move, so a
    /// lived claim still says exactly what its atom says.
    static func secondPerson(_ text: String) -> String {
        var result = ""
        var word = ""
        func flush() {
            guard !word.isEmpty else { return }
            result += swap(word)
            word = ""
        }
        for character in text {
            if character.isLetter || character == "'" || character == "’" {
                word.append(character)
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return capitalisingSentences(in: result)
    }

    /// "I" is capitalised wherever it stands, so its own case cannot tell us
    /// whether it began a sentence. Replacements are therefore always lowercase
    /// and sentence openings are restored afterwards - otherwise "My mother said
    /// I never write" became "Your mother said You never write".
    private static func capitalisingSentences(in text: String) -> String {
        var result = ""
        var atOpening = true
        for character in text {
            if atOpening, character.isLetter {
                result += String(character).uppercased()
                atOpening = false
            } else {
                result.append(character)
                if character == "." || character == "!" || character == "?" { atOpening = true }
            }
        }
        return result
    }

    private static func swap(_ word: String) -> String {
        let lower = word.lowercased()
        let replacement: String?
        switch lower {
        case "i": replacement = "you"
        case "my": replacement = "your"
        case "me": replacement = "you"
        case "mine": replacement = "yours"
        case "myself": replacement = "yourself"
        case "i'm", "i’m": replacement = "you're"
        case "i've", "i’ve": replacement = "you've"
        case "i'd", "i’d": replacement = "you'd"
        case "i'll", "i’ll": replacement = "you'll"
        default: replacement = nil
        }
        return replacement ?? word
    }

    /// Noun-free on purpose. A sentence that interpolates the night's subject is
    /// how the world ended up orbiting the reader's mug.
    /// The floor's version of a drawn line.
    ///
    /// Present tense throughout, because a Book sentence that puts the reader in
    /// the past tense is claiming their life, and only a lived claim checked
    /// against its own atom may do that.
    static func drawnLine(_ relation: SceneRelation, in plan: BraidScenePlan) -> String? {
        // A page holding something open still gets to notice. It does not get to
        // explain, resolve, or brighten, so these say what is true of the pair
        // and stop - no "which is how you know", no ending offered.
        if relation.holdsOpen {
            switch relation.kind {
            case .sharedThing, .sharedPerson:
                guard let pivot = relation.pivot else { return nil }
                let lines = [
                    "\(pivot.prefix(1).uppercased() + pivot.dropFirst()) is in both of these. I am not going to say anything clever about that.",
                    "Twice, \(pivot). I noticed. That is all I am doing with it.",
                    "\(pivot.prefix(1).uppercased() + pivot.dropFirst()) at both ends of the day, and no conclusion from me."
                ]
                return lines[stableIndex(of: plan.dayID + pivot, count: lines.count)]
            case .acrossTheDay:
                let lines = [
                    "The day started and the day ended and I am keeping both without tidying either.",
                    "One early and one late, and nothing in me wants to make them into a lesson.",
                    "Both ends of today are here. I am leaving them the length they are."
                ]
                return lines[stableIndex(of: plan.dayID + "held", count: lines.count)]
            }
        }
        switch relation.kind {
        case .sharedThing:
            guard let pivot = relation.pivot else { return nil }
            let lines = [
                "The \(pivot) is in both halves of today, and I do not think you noticed it twice.",
                "Twice the \(pivot), hours apart. I am keeping that.",
                "Whatever else today was, it was a day with the \(pivot) in it more than once."
            ]
            return lines[stableIndex(of: plan.dayID + pivot, count: lines.count)]
        case .sharedPerson:
            guard let pivot = relation.pivot else { return nil }
            let lines = [
                "\(pivot) is at both ends of this page.",
                "Two entries, one \(pivot). The page arranged itself around that.",
                "\(pivot) turns up twice here, which is more than most of today managed."
            ]
            return lines[stableIndex(of: plan.dayID + pivot, count: lines.count)]
        case .acrossTheDay:
            let lines = [
                "Morning and evening, and something between them that neither of them mentions.",
                "These two are hours apart. I have shelved them together anyway.",
                "One early, one late. The day is the only thing holding them."
            ]
            return lines[stableIndex(of: plan.dayID + "across", count: lines.count)]
        }
    }

    private static func relation(for transformation: SceneTransformation) -> String {
        switch transformation {
        case .juxtaposition: return "Two of these are leaning together. I have not said which two."
        case .recognition: return "I have seen one of these before, and I did not expect to."
        case .complication: return "None of it got easier while I was writing it down."
        case .ret: return "Something here has come back, and it is not the same size."
        case .refusal: return "One of these was declined. The declining is the part I kept."
        case .none: return "I wrote it down as it came and improved nothing."
        }
    }

    private static func colophon(for plan: BraidScenePlan) -> String {
        if !plan.mustRemainUnresolved.isEmpty {
            return "The Book kept the page: the words stayed in the order they came."
        }
        switch plan.transformation {
        case .juxtaposition: return "The Book kept the page: two things, side by side, unexplained."
        case .recognition: return "The Book kept the page: something was recognised and not named."
        case .complication: return "The Book kept the page: nothing here was resolved."
        case .ret: return "The Book kept the page: what came back came back changed."
        case .refusal: return "The Book kept the page: the refusal is the part that held."
        case .none: return "The Book kept the page: it happened, and I wrote it down."
        }
    }
}

// MARK: - The world's own business

/// Canonical world facts, with no slot for the reader's noun.
///
/// These are yesterday's world threads with the argument taken out. The old
/// versions interpolated the night's subject - "a paper moth ate a careful hole
/// around \(subject)" - and 80 of 81 of them did, which is why the Academy could
/// never do anything until a coffee mug authorised it. A world that only ever
/// mirrors the reader is not a world beyond them; it is a flattering surface.
///
/// Each is something happening in the Book's world tonight, sayable on its own.
/// A renderer may develop one. It may never make one into reader biography, and
/// the verifier refuses any world sentence that tries.
enum SceneWorldCanon {
    struct Fact: Equatable {
        var id: String
        var threadID: String
        var text: String
    }

    static let facts: [Fact] = [
        Fact(id: "moth-borders", threadID: "moth",
             text: "A paper moth has been eating careful holes in the third shelf and leaving the important parts. Show-off."),
        Fact(id: "sideways-step", threadID: "stairs",
             text: "One step halfway up the Academy stairs has been shifting sideways when it overhears something. Everyone has learned to climb around its opinion."),
        Fact(id: "back-cover-pocket", threadID: "pocket",
             text: "A new pocket has grown under my back cover. I object to the secrecy, not the pocket."),
        Fact(id: "bell-under-floor", threadID: "bell",
             text: "A bell has been ringing under the floor of the reading room. There is not meant to be a bell there."),
        Fact(id: "biting-dust", threadID: "dust",
             text: "Dust has fled one neat circle in the east corridor. I put a finger in it and something bit back."),
        Fact(id: "roof-runner", threadID: "roof",
             text: "Something has been running across the roof above the Stacks all week, carrying news in its teeth."),
        Fact(id: "straight-frost", threadID: "frost",
             text: "Frost crossed the long window and stopped in a straight line. Frost has never once done a straight line."),
        Fact(id: "other-room", threadID: "echo",
             text: "Someone in another room has been finishing my sentences a moment before I write them. There is no other room."),
        Fact(id: "moved-ribbon", threadID: "ribbon",
             text: "My ribbon has been moving on its own and lying across pages I had not chosen."),
        Fact(id: "roof-birds", threadID: "birds",
             text: "Birds got into the Academy roof and will not settle. They stop the moment anyone looks up."),
        Fact(id: "indoor-rain", threadID: "rain",
             text: "It rained inside the Stacks last night and nowhere else. The floor is still dark there."),
        Fact(id: "index-off-shelf", threadID: "index",
             text: "The Index has climbed out of its own alphabet and has not gone back all week."),
        Fact(id: "turned-shelves", threadID: "stacks",
             text: "Three shelves have turned to face the door. Shelves are not built with a front."),
        Fact(id: "lying-doors", threadID: "doors",
             text: "None of the doors will say which of them was open last night, which usually means all of them are lying."),
        Fact(id: "thinking-lamps", threadID: "lamps",
             text: "The lamps have been going down and coming back up in pairs. The building does that when it is thinking."),
        Fact(id: "corridor-door", threadID: "door",
             text: "A door past the reading room has been opening onto nothing and waiting a little longer each time.")
    ]



    /// A handful of the world's business, for a day the reader kept nothing.
    ///
    /// Three, from different threads, so a closed day reads as the Academy
    /// carrying on rather than as one fact stretched thin. Stepping by the day
    /// means consecutive closed days are different pages - which is the whole
    /// point of being able to flip back to a week you did not write in.
    static func quietDay(
        on date: Date,
        recentDays: [BookDay],
        live: [Fact],
        count: Int = 3
    ) -> [SceneWorldBeat] {
        let pool = live + facts
        guard !pool.isEmpty else { return [] }
        // Stepping by one meant consecutive closed days shared two of their
        // three facts. A week off should read as a week, not as one day with
        // the order shuffled.
        let dayNumber = Int(date.timeIntervalSince1970 / 86_400) * count
        var chosen: [SceneWorldBeat] = []
        var usedThreads = Set<String>()
        var offset = 0
        while chosen.count < count, offset < pool.count {
            let fact = pool[((dayNumber + offset) % pool.count + pool.count) % pool.count]
            offset += 1
            guard usedThreads.insert(fact.threadID).inserted else { continue }
            chosen.append(
                SceneWorldBeat(
                    id: fact.id, mode: .independent, fact: fact.text,
                    threadID: fact.threadID, crossesEvidenceID: nil
                )
            )
        }
        return chosen
    }

    /// Tonight's world business, if the world has any to offer.
    ///
    /// Mode is read off the night rather than chosen for effect. A night holding
    /// hard material gets `counterpoint` and never `intersecting`: the world may
    /// be beside somebody's grief, and may not be about it.
    /// Business the world is genuinely conducting tonight.
    ///
    /// The house canon is sixteen good facts about the Book's own building, and
    /// on its own that is a small world: the same shelves and stairs, rotating.
    /// A Cast member is halfway through something they started for their own
    /// reasons, and a world event is running on the world's clock whether or not
    /// the reader looked - both are the world moving without reference to
    /// anybody's evening, which is exactly what `independent` is for.
    ///
    /// These are preferred over the canon when they exist, because a thing
    /// actually in progress beats a thing that is merely true.
    static func liveFacts(
        undertakings: [CastUndertaking],
        worldEvents: [ResolvedWorldEvent]
    ) -> [Fact] {
        var facts: [Fact] = []

        // Active and stalled both count. A thing somebody has got stuck halfway
        // through is world business too, and often better business.
        for undertaking in undertakings
        where undertaking.status == .active || undertaking.status == .stalled {
            guard undertaking.stageIndex >= 0,
                  undertaking.stageIndex < undertaking.stages.count else { continue }
            let stage = undertaking.stages[undertaking.stageIndex]
            let text = stage.scene?.nonEmpty ?? stage.line.nonEmpty
            guard let text else { continue }
            facts.append(
                Fact(
                    id: "undertaking:\(undertaking.id):\(stage.id)",
                    threadID: "undertaking:\(undertaking.id)",
                    text: text
                )
            )
        }

        for event in worldEvents {
            let text = event.subtitle.nonEmpty ?? event.title.nonEmpty
            guard let text else { continue }
            facts.append(
                Fact(id: "world-event:\(event.id)", threadID: "world-event:\(event.packID)", text: text)
            )
        }
        return facts
    }

    static func beat(
        for plan: BraidScenePlan,
        recentDays: [BookDay],
        on date: Date,
        live: [Fact] = [],
        /// The fact the previous night's page actually carried, so tonight does
        /// not repeat it even when the rest window has not caught it yet.
        continuedElsewhere: String? = nil
    ) -> SceneWorldBeat? {
        let mode: WorldBeatMode
        if !plan.mustRemainUnresolved.isEmpty {
            mode = .counterpoint
        } else if plan.evidence.contains(where: { $0.kind == .keptFiction }) {
            mode = .intersecting
        } else {
            mode = .independent
        }

        // Rest what the reader has recently seen. Stamped world claims are the
        // record of what actually reached a page, which is better evidence than
        // what was planned.
        let spent = Set(
            recentDays
                .sorted { $0.date > $1.date }
                .prefix(8)
                .flatMap(\.pages)
                .filter { $0.type == .bookOfYou }
                .flatMap(\.tags)
                .compactMap { tag -> String? in
                    let prefix = "braid-claim:world:"
                    return tag.hasPrefix(prefix) ? String(tag.dropFirst(prefix.count)) : nil
                }
        )
        // A thing in progress beats a thing that is merely true, so live
        // business is offered first and the house canon catches the nights when
        // the world happens to be quiet.
        let candidates = live.isEmpty ? facts : live

        // Whatever the world was doing last night is set aside tonight.
        //
        // A first attempt here preferred *continuing* last night's thread, and
        // it could not have worked: the residue stamp records a fact id while
        // threads are matched by thread, and the canon carries one fact per
        // thread anyway, so there was nothing to continue to. Preferring the
        // opposite is honest and does real work - across a month the world stops
        // returning to the same corridor two nights running.
        let fresh = candidates.filter { !spent.contains($0.id) && $0.id != continuedElsewhere }
        let pool = fresh.isEmpty
            ? (candidates.isEmpty ? facts : candidates)
            : fresh
        guard !pool.isEmpty else { return nil }

        // A genuine rotation rather than a hash. Hashing the day id was
        // deterministic but collided: five blank nights in one month drew four
        // distinct facts, so two of them printed the same page - which is the
        // exact defect this was written to fix. Stepping by the day itself
        // cannot repeat until the pool is exhausted.
        let dayNumber = Int(date.timeIntervalSince1970 / 86_400)
        let chosen = pool[((dayNumber % pool.count) + pool.count) % pool.count]
        return SceneWorldBeat(
            id: chosen.id,
            mode: mode,
            fact: chosen.text,
            threadID: chosen.threadID,
            crossesEvidenceID: mode == .intersecting
                ? plan.evidence.first(where: { $0.kind == .keptFiction })?.id
                : nil
        )
    }
}

// MARK: - Which renderer writes tonight

/// Which writer produces the page that ships when no model page wins.
///
/// The plan-driven floor is provably honest — every sentence names its claim and
/// the verifier reads it under the same laws a model is held to — and it reads
/// thinner than the sentence-bank writer it would replace: 46 words against 115
/// on a plain day, 151 against 307 on a rich one. Most of that gap is padding
/// that was measured and meant to go. But "thinner and honest" against "fuller
/// and padded" is a judgement about the product rather than a refactor, and it
/// has not been tried on a device.
///
/// So the switch exists and is off. Flip it, braid a week, and read them.
/// `docs/attic/LiteraryContinuity.pre-scene-plan.swift` holds the prose to bring
/// back if the floor turns out to be too thin.
enum BraidFloor {
    case houseWriter
    case scenePlan

    /// Switched to the scene plan 2026-08-17. The sentence-bank writer is kept
    /// in `docs/attic/LiteraryContinuity.pre-scene-plan.swift` and can be
    /// brought back; the judgement was that a thinner honest page beats a fuller
    /// padded one, and that the padding was most of the difference.
    static var preferred: BraidFloor = .scenePlan
}

extension BraidSceneWriter {
    /// The floor's page, marked and stamped like any other candidate, so the
    /// audit and the tasting room judge it on the same terms as the rest.
    static func page(for plan: BraidScenePlan, title: String) -> BookPage? {
        let claims = write(plan)
        guard claims.contains(where: { $0.realm != .colophon }) else { return nil }
        let body = paragraphs(from: claims)
        guard !body.isEmpty else { return nil }
        return BookPage(
            type: .bookOfYou,
            promptText: "Book of You: \(title)",
            userInput: "\(title)\n\n\(body)",
            tags: ["braid", "braid-plan-floor"]
                + claims.compactMap { claim in
                    claim.sourceIDs.first.map { "braid-claim:\(claim.realm.rawValue):\($0)" }
                }
                + plan.residueTags(surviving: claims),
            usedInBookOfYou: true
        )
    }

    /// One paragraph per claim family, so a page of facts does not arrive as one
    /// undifferentiated block. Deliberately simple: the plan says how long the
    /// night earned to be, and the renderer that can shape it properly is the
    /// model.
    private static func paragraphs(from claims: [BraidClaim]) -> String {
        var blocks: [String] = []
        var current: [String] = []
        var lastRealm: BraidClaim.Realm?
        for claim in claims where claim.realm != .colophon {
            if let lastRealm, lastRealm != claim.realm, !current.isEmpty {
                blocks.append(current.joined(separator: " "))
                current = []
            }
            current.append(claim.text)
            lastRealm = claim.realm
        }
        if !current.isEmpty { blocks.append(current.joined(separator: " ")) }
        if let colophon = claims.last(where: { $0.realm == .colophon }) {
            blocks.append(colophon.text)
        }
        return blocks.joined(separator: "\n\n")
    }
}

// MARK: - The title

extension BraidScenePlan {
    /// A title made of the reader's own words.
    ///
    /// The old titles were built from a noun and a verb out of a small bank -
    /// "The Mug Saw It", "The Bakery Saw the Fox" - and across thirty
    /// consecutive nights seventeen of them shared one mould. That is the table
    /// of contents of a book somebody paid for.
    ///
    /// A fragment of the reader's own sentence cannot be a mould, because their
    /// sentences are not. It is also the most honest thing a title can be: the
    /// page is about their evening, so the page is named in their language.
    ///
    /// Where the fragment is taken from varies against the shape memory, so a
    /// run of nights does not all open on the first four words.
    func title() -> String {
        guard let source = anchor?.text.nonEmpty ?? livedEvidence.first?.text.nonEmpty else {
            // A night the reader wrote nothing on is the world's, and the world
            // is allowed to name it.
            return worldBeat.map { Self.fragment(of: $0.fact, fromEnd: false) } ?? "A Quiet Night"
        }
        // Alternate the cut so consecutive nights are not all built the same way.
        let fromEnd = shape.recentTitleShapes.count.isMultiple(of: 2)
        return Self.fragment(of: source, fromEnd: fromEnd)
    }

    /// The reader's own noun phrase, with the determiner they wrote.
    ///
    /// Three attempts, recorded because each failure taught the next. A plain
    /// word-count slice gave fragments: "And forgot the silver spoon". A clause
    /// cut at its last noun gave good English that *duplicated the first
    /// sentence of the page* - a title and an opening line reading identically.
    /// A noun-phrase search gave single words - "Swam", "Degrees", "Dad" - but
    /// only because it picked the last phrase rather than the longest.
    ///
    /// The longest noun phrase is the title: "The chipped yellow bowl", "Tomato
    /// soup", "Cold tea", "The brass lamp". Their nouns vary, so it cannot become
    /// the mould that "The X Saw It" became seventeen times in thirty nights, and
    /// it does not repeat the sentence underneath it.
    static func fragment(of source: String, fromEnd: Bool) -> String {
        // Turned to face the reader first, or the Book titles a page "My mother".
        let text = BraidSceneWriter.secondPerson(source)
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var runs: [[String]] = []
        var current: [String] = []
        var pendingDeterminer: String?

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            let word = String(text[range]).trimmingCharacters(in: .punctuationCharacters)
            guard !word.isEmpty else { return true }
            switch tag {
            case .determiner:
                if !current.isEmpty { runs.append(current) }
                current = []
                pendingDeterminer = word
            case .adjective, .noun:
                if current.isEmpty, let determiner = pendingDeterminer {
                    current.append(determiner)
                }
                current.append(word)
                pendingDeterminer = nil
            default:
                if !current.isEmpty { runs.append(current) }
                current = []
                pendingDeterminer = nil
            }
            // A phrase cannot span a full stop. Punctuation is omitted from the
            // token stream, so "face the door. Shelves are not built" put "door"
            // and "Shelves" side by side and titled a page "The door Shelves".
            let after = text[range.upperBound...].prefix(2)
            if after.contains(".") || after.contains("!") || after.contains("?") {
                if !current.isEmpty { runs.append(current) }
                current = []
                pendingDeterminer = nil
            }
            return true
        }
        if !current.isEmpty { runs.append(current) }

        // A run whose only noun names nothing in particular is not a title.
        let usable = runs.filter { run in
            run.contains { word in
                let lower = word.lowercased()
                return lower.count > 2
                    && !danglingTitleWords.contains(lower)
                    && !emptyTitleNouns.contains(lower)
            }
        }
        // Longest, always. Selecting by position is what produced "Dad".
        if let phrase = usable.max(by: { left, right in
            left.count != right.count
                ? left.count < right.count
                : left.joined().count < right.joined().count
        }) {
            let joined = phrase.prefix(5).joined(separator: " ")
            return joined.prefix(1).uppercased() + joined.dropFirst()
        }
        #endif
        let words = text
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'")) }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return "A Quiet Night" }
        let joined = words.prefix(4).joined(separator: " ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    /// Nouns that name nothing in particular, so a phrase built on one is not a
    /// title even when the tagger is happy with it.
    private static let emptyTitleNouns: Set<String> = [
        "thing", "things", "day", "days", "time", "times", "way", "ways",
        "morning", "evening", "night", "today", "sort", "kind", "bit", "lot"
    ]

    private static let danglingTitleWords: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "in", "into",
        "of", "on", "or", "the", "to", "with", "that", "which", "was", "were",
        "is", "are", "had", "has", "have", "it", "its", "my", "your"
    ]
}
