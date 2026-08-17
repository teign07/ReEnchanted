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

        var plan = BraidScenePlan(
            dayID: day.id,
            evidence: evidence,
            placements: placements,
            anchorEvidenceID: anchorID,
            form: reading.storyForm.rawValue,
            motion: reading.motion.rawValue,
            pressure: reading.pressure.rawValue,
            scale: reading.scale.rawValue,
            transformation: transformation(for: reading, score: score),
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
            earnedWords: earnedWords(for: selected, reading: reading),
            shape: shape ?? shapeMemory(
                from: archive.isEmpty ? context.recentDays : archive,
                before: day.date
            ),
            intendedResidue: .empty
        )
        // Assigned after construction because the mode is read off the night the
        // plan describes: a page holding hard material gets the world beside it
        // and never about it.
        plan.worldBeat = SceneWorldCanon.beat(
            for: plan,
            recentDays: archive.isEmpty ? context.recentDays : archive,
            dayID: day.id
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
        reading: BraidPromptBuilder.TaleReading
    ) -> ClosedRange<Int> {
        // A fragment is not a beat. "Two coffees and a muffin" is real and it is
        // not twenty-five words of anything.
        let substantial = selected.filter { $0.text.split(whereSeparator: \.isWhitespace).count >= 5 }
        guard !substantial.isEmpty else { return 40...90 }

        let perAtom = 26
        let bookVoice = 34
        let floor = min(reading.scale.targetWordBand.upperBound, substantial.count * perAtom + bookVoice)
        let ceiling = min(reading.scale.targetWordBand.upperBound + 60, Int(Double(floor) * 1.7))
        return max(40, floor)...max(90, ceiling)
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
                } else if plan.worldBeat?.id != id {
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
    func brief() -> String {
        var lines: [String] = []

        lines.append("Write tonight's page.")
        lines.append("")
        lines.append("SHAPE: \(form). \(motion) under \(pressure) pressure.")
        if let anchor {
            lines.append("ABOUT: \(anchor.text)")
        } else {
            lines.append("ABOUT: nothing in particular. Say so; do not invent a subject.")
        }
        lines.append("DO: \(transformationInstruction)")
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

        // One relation, named once, and never explained. Hard material is
        // witnessed and gets no commentary at all.
        if ordered.count >= 2, plan.mustRemainUnresolved.isEmpty {
            claims.append(
                BraidClaim(
                    realm: .book,
                    sourceIDs: plan.anchorEvidenceID.map { [$0] } ?? [],
                    text: relation(for: plan.transformation)
                )
            )
        }

        if let beat = plan.worldBeat {
            claims.append(
                BraidClaim(realm: .world, sourceIDs: [beat.id], text: beat.fact)
            )
        }

        claims.append(BraidClaim(realm: .colophon, sourceIDs: [], text: colophon(for: plan)))
        return claims
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

    /// Tonight's world business, if the world has any to offer.
    ///
    /// Mode is read off the night rather than chosen for effect. A night holding
    /// hard material gets `counterpoint` and never `intersecting`: the world may
    /// be beside somebody's grief, and may not be about it.
    static func beat(
        for plan: BraidScenePlan,
        recentDays: [BookDay],
        dayID: String
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
        let fresh = facts.filter { !spent.contains($0.id) }
        let pool = fresh.isEmpty ? facts : fresh
        guard !pool.isEmpty else { return nil }

        // Deterministic rotation, so the same night always tells the same story
        // and consecutive nights do not.
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in dayID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        let chosen = pool[Int(hash % UInt64(pool.count))]
        return SceneWorldBeat(
            id: chosen.id, mode: mode, fact: chosen.text, threadID: chosen.threadID
        )
    }
}
