import Foundation

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
    /// The atom the page is about. Nil on a night with nothing to be about,
    /// which is a real night and not a failure.
    var anchorEvidenceID: String?
    var form: String
    var motion: String
    var pressure: String
    var scale: String
    var transformation: SceneTransformation
    var worldBeat: SceneWorldBeat?
    var carriedReturn: SceneReturn?
    /// Atoms that must not be given an ending. The shadow laws in one field.
    var mustRemainUnresolved: [String]
    var earnedWords: ClosedRange<Int>
    var shape: SceneShapeMemory
    var intendedResidue: SceneResidueIntent

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
        shape: SceneShapeMemory = .empty
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

        return BraidScenePlan(
            dayID: day.id,
            evidence: evidence,
            placements: placements,
            anchorEvidenceID: anchorID,
            form: reading.storyForm.rawValue,
            motion: reading.motion.rawValue,
            pressure: reading.pressure.rawValue,
            scale: reading.scale.rawValue,
            transformation: transformation(for: reading, score: score),
            // Phase 4 adapters.
            worldBeat: nil,
            carriedReturn: nil,
            mustRemainUnresolved: selected.filter(\.isUnclearedShadow).map(\.id).sorted(),
            earnedWords: reading.scale.targetWordBand,
            shape: shape,
            intendedResidue: .empty
        )
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
            let text = page.userInput.nonEmpty
                ?? page.promptText.nonEmpty
                ?? ""
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
            let text = contribution.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? mediaText(for: contribution, in: page)
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
