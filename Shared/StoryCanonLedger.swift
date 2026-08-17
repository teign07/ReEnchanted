import Foundation

/// What a vignette has established, carried forward as facts.
///
/// Story Pages had a continuity problem with a stated cause. Prior turns reach
/// the writer compressed - four sentences of the last scene, three of its
/// result, one each for anything older - and the code says why:
///
/// > Prior turns arrive COMPRESSED: the model never sees full earlier prose,
/// > because whatever it sees, it echoes.
///
/// That is true, and it is a trap. Show prose and the model parrots it; clip
/// prose and the story loses its own history. Both branches lose because prose
/// is the wrong currency. A fact cannot be echoed as prose, so a ledger of facts
/// can be shown in full without teaching the model to repeat sentences.
///
/// The material already existed and was simply never accumulated: every
/// resolved turn precommits a `StoryDramaticChoiceEffect` whose `changedFact` is
/// described to the model as *"the changed fact that becomes canon"* - and then
/// the dramatic contract, which belongs to the draft, is replaced when a
/// continuation builds a fresh one. Canon was not canon.
struct StoryCanonLedger: Equatable, Codable {
    /// One resolved turn, as the next beat needs to know it.
    struct Entry: Equatable, Codable {
        var turnNumber: Int
        /// The reader's chosen path, by its button title.
        var chosenTitle: String
        /// Who visibly moved.
        var reactorName: String
        /// What they visibly did.
        var reaction: String
        /// What the reader's choice changed.
        var readerChoiceEffect: String
        /// The fact that is now true and may not be contradicted.
        var changedFact: String
        var memorySummary: String
    }

    var entries: [Entry] = []
    var warmth: Int = 0
    var tension: Int = 0
    var familiarity: Int = 0
    /// Concrete nouns already spent on the page, so the anti-echo contract can
    /// be stated from data instead of by starving the writer of context.
    var spentImages: [String] = []

    var isEmpty: Bool { entries.isEmpty }

    /// Facts that may not be contradicted, oldest first.
    var establishedFacts: [String] {
        entries.compactMap { $0.changedFact.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
    }

    /// The people this vignette has already put on the page.
    var namedReactors: [String] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            let name = entry.reactorName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            return name
        }
    }

    // MARK: - Accumulating

    /// Fold one resolved turn into the ledger.
    ///
    /// A turn contributes only when the reader actually resolved it. A beat
    /// nobody chose established nothing, and recording it would let the page
    /// claim canon the reader never saw.
    mutating func record(
        turnNumber: Int,
        chosenTitle: String,
        effect: StoryDramaticChoiceEffect,
        prose: String
    ) {
        guard !entries.contains(where: { $0.turnNumber == turnNumber }) else { return }
        entries.append(
            Entry(
                turnNumber: turnNumber,
                chosenTitle: chosenTitle,
                reactorName: effect.requiredReactorName,
                reaction: effect.requiredReaction,
                readerChoiceEffect: effect.readerChoiceEffect,
                changedFact: effect.changedFact,
                memorySummary: effect.memorySummary))
        warmth += effect.warmthDelta
        tension += effect.tensionDelta
        familiarity += effect.familiarityDelta
        spend(images: Self.images(in: prose))
    }

    mutating func spend(images: [String]) {
        for image in images where !spentImages.contains(image) {
            spentImages.append(image)
        }
        // A long tail is noise: the contract only needs what a next beat is
        // actually likely to reach for.
        if spentImages.count > 14 { spentImages = Array(spentImages.suffix(14)) }
    }

    /// Concrete nouns worth forbidding a second time.
    ///
    /// Deliberately shallow. This is here to stop a beat re-describing the same
    /// window and the same mug, not to build a semantic model of the scene, and
    /// anything cleverer would start refusing a legitimate return to an object
    /// the story is about.
    static func images(in prose: String) -> [String] {
        let words = prose.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 4 && !stopwords.contains($0) }
        var counts: [String: Int] = [:]
        for word in words { counts[word, default: 0] += 1 }
        return counts
            .filter { $0.value >= 2 }
            .keys
            .sorted()
    }

    private static let stopwords: Set<String> = [
        "that", "this", "with", "from", "into", "then", "than", "them", "they",
        "were", "have", "been", "about", "after", "before", "again", "still",
        "there", "where", "which", "would", "could", "should", "your", "yours",
        "said", "says", "like", "just", "over", "back", "down", "when", "what",
        "come", "came", "goes", "went", "does", "done", "made", "make", "look",
        "looked", "turn", "turned", "hand", "hands", "something", "nothing"
    ]

    // MARK: - Telling the writer

    /// The ledger as a prompt section.
    ///
    /// Facts rather than sentences, and stated as constraints rather than as
    /// material: the writer is told what is already true so it does not
    /// re-establish it, and told what has been spent so it does not repeat it.
    func promptSection() -> String {
        guard !isEmpty else { return "" }
        var lines = ["ALREADY TRUE IN THIS VIGNETTE. Do not re-establish, re-explain, or contradict any of it:"]
        for entry in entries.sorted(by: { $0.turnNumber < $1.turnNumber }) {
            var line = "- Turn \(entry.turnNumber): the reader chose \"\(entry.chosenTitle)\"."
            if let fact = entry.changedFact.nonEmpty { line += " Now true: \(fact)" }
            if let reactor = entry.reactorName.nonEmpty, let reaction = entry.reaction.nonEmpty {
                line += " \(reactor) \(reaction)"
            }
            if let effect = entry.readerChoiceEffect.nonEmpty {
                line += " The reader's choice changed: \(effect)"
            }
            lines.append(line)
        }
        if !namedReactors.isEmpty {
            lines.append(
                "Already on the page: \(namedReactors.joined(separator: ", ")). They remember all of the above.")
        }
        if !spentImages.isEmpty {
            lines.append(
                "Already used, do not reach for these again: \(spentImages.joined(separator: ", ")).")
        }
        lines.append(standingLine)
        return lines.joined(separator: "\n")
    }

    /// Where the relationship stands, in words rather than numbers. The reader
    /// never sees a stat, and neither should the prose.
    private var standingLine: String {
        var notes: [String] = []
        if tension >= 2 { notes.append("something between them is unresolved and both know it") }
        else if tension <= -2 { notes.append("the pressure between them has eased") }
        if warmth >= 2 { notes.append("they are closer than when this began") }
        else if warmth <= -2 { notes.append("they are more guarded than when this began") }
        if familiarity >= 2 { notes.append("they no longer explain themselves to each other") }
        guard !notes.isEmpty else {
            return "Where they stand has not measurably moved yet. Do not assert that it has."
        }
        return "Where they stand now: \(notes.joined(separator: "; ")). Show it; never state it."
    }

    // MARK: - Outliving the vignette

    /// The vignette's canon, as memories the people in it will carry.
    ///
    /// Deliberately not a new store. The Book already keeps per-character
    /// memory - written through `persistEntityMemories`, consolidated, and read
    /// back by story selection, deep-bond gating and letter prose - so a
    /// vignette's canon belongs *there*, attached to the person it happened to,
    /// rather than in a second ledger sitting beside it. A later Story Page that
    /// features Mara then inherits what Mara did here without anything new
    /// having to look it up.
    ///
    /// Each write is that character's own frame on the event, which is the
    /// existing contract: two people in the same room get two different
    /// sentences.
    func memoryWrites() -> [NarrativeEntityMemoryWrite] {
        entries.compactMap { entry -> NarrativeEntityMemoryWrite? in
            let entityID = entry.reactorName
                .lowercased()
                .split { !$0.isLetter }
                .joined(separator: "-")
            guard !entityID.isEmpty else { return nil }
            guard let summary = (entry.memorySummary.nonEmpty ?? entry.changedFact.nonEmpty)
            else { return nil }
            return NarrativeEntityMemoryWrite(
                entityID: entityID,
                summary: summary,
                tags: ["story-page", "story-canon"],
                // A vignette the reader played through is worth more than
                // ambient world chatter and less than a Cast act they lived.
                narrativeWeight: 5)
        }
    }

    /// The canon as page tags, so it survives the sheet that made it.
    ///
    /// One definition for both ends: the sheet stamps these when the reader
    /// keeps the page, and the keep path reads them back to persist the
    /// memories. Story canon is fiction, so unlike a braid's held-open thread it
    /// may be quoted - the rule about carrying ids rather than words exists to
    /// protect the reader's own life, not the Book's inventions.
    static let canonTagPrefix = "story-canon:"

    func canonTags() -> [String] {
        memoryWrites().map { write in
            "\(Self.canonTagPrefix)\(write.entityID)|\(String(write.summary.prefix(160)))"
        }
    }

    static func memoryWrites(fromTags tags: [String]) -> [NarrativeEntityMemoryWrite] {
        tags.compactMap { tag in
            guard tag.hasPrefix(canonTagPrefix) else { return nil }
            let body = String(tag.dropFirst(canonTagPrefix.count))
            let parts = body.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let entityID = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let summary = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !entityID.isEmpty, !summary.isEmpty else { return nil }
            return NarrativeEntityMemoryWrite(
                entityID: entityID,
                summary: summary,
                tags: ["story-page", "story-canon"],
                narrativeWeight: 5)
        }
    }

    // MARK: - Holding a beat to it

    /// A beat that contradicts something the reader has already been shown.
    ///
    /// Deliberately narrow, and it only ever reports a *reversed* fact - a
    /// negation flipped one way or the other - because that is the contradiction
    /// a reader actually notices and the only one checkable without a model of
    /// the scene. A Story Page may invent freely inside its fiction; what it may
    /// not do is un-happen something.
    func contradiction(in prose: String) -> String? {
        for fact in establishedFacts {
            guard sharesSubject(prose, fact) else { continue }
            if !BraidRevisionVerifier.preservesPolarity(prose, of: fact) {
                return fact
            }
        }
        return nil
    }

    private func sharesSubject(_ prose: String, _ fact: String) -> Bool {
        let factWords = BraidRevisionVerifier.contentWords(in: fact).filter { $0.count > 3 }
        guard factWords.count >= 2 else { return false }
        let proseWords = BraidRevisionVerifier.contentWords(in: prose)
        return factWords.filter { word in
            proseWords.contains { BraidRevisionVerifier.matches($0, word) }
        }.count >= 2
    }
}
