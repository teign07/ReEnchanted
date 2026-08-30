import Foundation

// MARK: - The Reader's Sheet
//
// Who the reader is *in the story*, assembled in one place for the first time.
//
// Every line of this already existed: the role, the vows, the scars a finished
// tale left behind, the quill, the bonds, the threads. They existed as six or
// seven unrelated fields on `BookSourceInputs` that no single thing ever read
// together, so nothing in the Book could answer the question "who am I writing
// to?" without re-deriving it from scratch each time.
//
// This is deliberately NOT stored. Its inputs are already sources of truth, and
// a stored copy would be a second one that drifts. Only the assembly is new.
//
// It is also not a personality profile, and the distinction is the whole design:
// every line here was *earned by something that happened*. Cinderella is not
// agreeable: she has a curfew, a bargain, and a shoe. A trait would have no
// falsifier and could never be paid off as a receipt; a vow, a scar, and a debt
// can all be pointed at.

struct ReadersSheet: Equatable {
    /// A cast bond, carrying the entity it belongs to. `relationshipField` is a
    /// dictionary of bare numbers, so the id has to travel alongside.
    struct Bond: Equatable {
        var entityID: String
        var tie: RelationshipTie
    }

    // MARK: Name and standing

    /// The reader's role, epithet and hands, as the Book names them.
    var role: ComposedRole?
    /// The second half a finished tale earned them, if one has.
    var transformationClause: String?
    /// The season the reader named themselves. Never the Book's invention.
    var seasonName: String?
    var tenureDays: Int
    var beliefScore: Int

    // MARK: Vows and debts: the things that bind

    var openBargainCount: Int
    var outstandingWagers: [BookWager]
    /// Laws left standing by tales that finished. These cannot be undone by the
    /// reader, which is the point of them.
    var activeScars: [TaleScar]

    // MARK: Company

    var quill: ChosenQuill?
    /// Strongest cast bonds first.
    var closestBonds: [Bond]
    /// People the reader has written into the story, by name.
    var namedPeople: [String]

    // MARK: Marks

    var pocketKeepsakeCount: Int
    var constellationCount: Int

    // MARK: Weather: explicitly state, never identity

    /// Today's reader-answered reading, where one exists.
    var currentState: ReaderCurrentState
    /// The Rut's working band. Internal; present here so a prompt can be gentle
    /// without being told why.
    var rutBand: Int?

    // MARK: What the Book is watching, and might be wrong about

    var openThreads: [OpenThread]
    /// The reader's standing rule about heavy material. Outranks everything.
    var shadowPermission: ReaderStory.ShadowPermission

    static let unwritten = ReadersSheet(
        role: nil,
        transformationClause: nil,
        seasonName: nil,
        tenureDays: 0,
        beliefScore: 0,
        openBargainCount: 0,
        outstandingWagers: [],
        activeScars: [],
        quill: nil,
        closestBonds: [],
        namedPeople: [],
        pocketKeepsakeCount: 0,
        constellationCount: 0,
        currentState: ReaderCurrentState(
            aliveness: nil,
            wonder: nil,
            hiddenMagic: nil,
            capacity: nil,
            freshestAnswerAt: nil
        ),
        rutBand: nil,
        openThreads: [],
        shadowPermission: .onlyWhenOld
    )
}

// MARK: - Assembling it

enum ReadersSheetBuilder {
    static let maximumBonds = 4
    static let maximumNamedPeople = 6

    static func build(
        inputs: BookSourceInputs,
        now: Date = Date()
    ) -> ReadersSheet {
        let story = inputs.readerStory
        let ledger = inputs.standingLedger

        // `relationshipField` is keyed by entity id, and the tie itself holds
        // only the numbers, so the pairs are carried through together.
        let bonds = inputs.relationshipField
            .sorted { left, right in
                if left.value.warmth == right.value.warmth { return left.key < right.key }
                return left.value.warmth > right.value.warmth
            }
            .prefix(maximumBonds)
            .map { ReadersSheet.Bond(entityID: $0.key, tie: $0.value) }

        return ReadersSheet(
            role: ReaderRoleRegistry.currentRole(from: inputs.selfFacts),
            transformationClause: inputs.roleTransformationClause,
            seasonName: story.seasons.last?.name,
            tenureDays: ledger.tenureDays,
            beliefScore: inputs.readerBeliefScore,
            openBargainCount: inputs.faeState.bargains.filter { $0.status == .owed }.count,
            outstandingWagers: inputs.wagers.filter(\.isSealed),
            activeScars: inputs.taleScars.scars.filter { $0.isActive(at: now) },
            quill: inputs.chosenQuill,
            closestBonds: Array(bonds),
            // Only people the reader actually wrote into the story, and never
            // a thread they have pressed to rest.
            namedPeople: Array(
                inputs.people.threads
                    .filter { $0.castMemberID != nil && !$0.resting }
                    .map(\.name)
                    .prefix(maximumNamedPeople)
            ),
            pocketKeepsakeCount: inputs.pocket.keepsakes.count,
            constellationCount: inputs.constellations.count,
            currentState: inputs.readerStatePulses.currentState(now: now),
            rutBand: ledger.rut.currentPressure,
            openThreads: story.openThreads.filter(\.isOpen),
            shadowPermission: story.shadowPermission
        )
    }
}

// MARK: - The Sheet as prompt context

extension ReadersSheet {
    struct FrontMatterSection: Equatable {
        var id: String
        var title: String
        var text: String
    }

    /// A compact rendering for the local brain, so a generated page knows who it
    /// is writing to instead of re-deriving a reader from whatever happened to
    /// be in scope.
    ///
    /// Two rules govern what appears here. Nothing numeric from the twin crosses
    /// over (no scores, no bands, no trends) because those are gates and not
    /// material. And the reader's standing rule about heavy material leads,
    /// because it is a ceiling on everything that follows it.
    var promptSection: String {
        var lines: [String] = []

        lines.append(shadowPermission.promptLine)

        if let role {
            var naming = "The reader is \(role.signature)."
            if let transformationClause {
                naming += " A finished tale earned them this: \(transformationClause)"
            }
            lines.append(naming)
            lines.append("This reader \(role.role.verb). Do not explain the role to them; it is simply who they are.")
        }

        if let seasonName {
            lines.append("They have named the season they are in: \(seasonName). It is their word, not yours.")
        }

        if let quill {
            lines.append("Their quill is \(quill.displayName). It has opinions and is not a tool.")
        }

        if !activeScars.isEmpty {
            let laws = activeScars.prefix(3).map(\.law).joined(separator: " ")
            lines.append("Laws left by tales that finished, still standing: \(laws)")
        }

        if !closestBonds.isEmpty {
            let names = closestBonds.map(\.entityID).joined(separator: ", ")
            lines.append("Closest in the Labyrinth: \(names).")
        }

        if !namedPeople.isEmpty {
            lines.append(
                "People the reader has written in: \(namedPeople.joined(separator: ", ")). "
                    + "Never voice them, never invent what they said or did."
            )
        }

        if !openThreads.isEmpty {
            let threads = openThreads.prefix(3).map(\.line).joined(separator: " ")
            lines.append("Threads left open, carried as question and not as material: \(threads)")
        }

        if !outstandingWagers.isEmpty {
            lines.append("\(outstandingWagers.count) wager(s) outstanding. You owe them an answer, not a reminder.")
        }

        return lines.joined(separator: "\n")
    }

    /// Whether there is enough of a reader here to be worth handing over. A
    /// nearly-empty sheet is noise in a prompt.
    var isWorthSpeakingTo: Bool {
        role != nil || !activeScars.isEmpty || !openThreads.isEmpty || quill != nil
    }

    /// The visible Front Matter, already divided into the few questions a
    /// reader actually needs answered. The renderer uses these same sections,
    /// and `readerFacingBody` keeps a plain-text copy for the archive.
    var readerFacingSections: [FrontMatterSection] {
        var sections: [FrontMatterSection] = []
        var you: [String] = []
        if let role {
            var naming = "In this Book, you are \(role.signature)."
            if let transformationClause {
                naming += " A finished tale added this: \(transformationClause)"
            }
            you.append(naming)
        }
        if let seasonName {
            you.append("You named this season \(seasonName).")
        }
        if tenureDays > 0 {
            you.append("We have kept Pages together for \(tenureDays) days.")
        }
        if let quill {
            you.append("Your quill is \(quill.displayName). It has opinions.")
        }
        if !you.isEmpty {
            sections.append(FrontMatterSection(
                id: "you",
                title: "You in this Book",
                text: you.joined(separator: "\n")
            ))
        }

        var standing: [String] = []
        if !activeScars.isEmpty {
            let laws = activeScars.prefix(3).map { "\u{2022} \($0.law)" }.joined(separator: "\n")
            standing.append("These rules came out of finished tales. They still stand:\n\(laws)")
        }
        if openBargainCount > 0 {
            standing.append("\(openBargainCount) bargain\(openBargainCount == 1 ? " is" : "s are") still open. You still owe the noticing.")
        }
        if !outstandingWagers.isEmpty {
            standing.append("I have \(outstandingWagers.count) sealed wager\(outstandingWagers.count == 1 ? "" : "s"). I still owe you the answer\(outstandingWagers.count == 1 ? "" : "s").")
        }
        if !standing.isEmpty {
            sections.append(FrontMatterSection(
                id: "standing",
                title: "Still standing",
                text: standing.joined(separator: "\n\n")
            ))
        }

        var company: [String] = []
        if !namedPeople.isEmpty {
            company.append("People you brought into the Book: \(namedPeople.joined(separator: ", ")).")
        }
        if !closestBonds.isEmpty {
            company.append("The Labyrinth keeps pulling you toward: \(closestBonds.map(\.entityID).joined(separator: ", ")).")
        }
        if !company.isEmpty {
            sections.append(FrontMatterSection(
                id: "company",
                title: "Your company",
                text: company.joined(separator: "\n")
            ))
        }

        var kept: [String] = []
        if pocketKeepsakeCount > 0 {
            kept.append("I kept \(pocketKeepsakeCount) small thing\(pocketKeepsakeCount == 1 ? "" : "s") from Pages you let go.")
        }
        if constellationCount > 0 {
            kept.append("I found \(constellationCount) constellation\(constellationCount == 1 ? "" : "s") in your Pages.")
        }
        if !kept.isEmpty {
            sections.append(FrontMatterSection(
                id: "kept",
                title: "What I kept",
                text: kept.joined(separator: "\n")
            ))
        }

        if !openThreads.isEmpty {
            let threads = openThreads.prefix(3).map { "\u{2022} \($0.line)" }.joined(separator: "\n")
            sections.append(FrontMatterSection(
                id: "open",
                title: "Still open",
                text: "I am still watching these questions:\n\(threads)"
            ))
        }

        return sections
    }

    /// What the Book will show the reader about what it holds.
    /// No hidden scores appear here. Every statement comes from an event the
    /// reader can inspect, and the final word remains theirs.
    var readerFacingBody: String {
        let opening = "This is what I know about you. I learned it from things you did here. I did not guess."
        let sections = readerFacingSections.map { section in
            "\(section.title.uppercased())\n\(section.text)"
        }
        let correction = "WRONG?\nWrite the correction below. I will keep it with these front pages."

        return ([opening] + sections + [correction]).joined(separator: "\n\n")
    }
}
