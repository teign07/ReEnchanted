import Foundation

/// The Academy's own year, bound into the reader's book.
///
/// This is not a status report and must never read as one. It is literary
/// matter — notices, clippings, withdrawn rumours, crossed-out records — and its
/// job is to let the reader realise that time passed for everybody, not only for
/// them.
///
/// The last entry is the most important one. An edition that explains everything
/// is a report; an edition with one admitted mystery is a chapter.
enum AcademySeasonEdition {
    static let sectionID = "academy-season"

    struct Inputs: Equatable {
        var movements: [CastAgencyMovement]
        var undertakings: [CastUndertaking]
        var pressures: [WorldPressure]
        var placeStates: [String: PlaceState]
        var castName: [String: String]

        init(
            movements: [CastAgencyMovement] = [],
            undertakings: [CastUndertaking] = [],
            pressures: [WorldPressure] = [],
            placeStates: [String: PlaceState] = [:],
            castName: [String: String] = [:]
        ) {
            self.movements = movements
            self.undertakings = undertakings
            self.pressures = pressures
            self.placeStates = placeStates
            self.castName = castName
        }
    }

    static func section(
        for inputs: Inputs,
        start: Date,
        end: Date,
        now: Date = Date()
    ) -> MonthlyEditionSection? {
        var items: [MonthlyEditionItem] = []
        func name(_ id: String) -> String { inputs.castName[id] ?? id }

        let movements = inputs.movements
            .filter { $0.createdAt >= start && $0.createdAt <= end }
            .sorted { $0.createdAt < $1.createdAt }

        // Projects that continued without witnesses.
        let unwitnessed = movements.filter { !$0.witnessed }
        if !unwitnessed.isEmpty {
            items.append(item(
                id: "\(sectionID)-unwitnessed",
                title: "Carried on without an audience",
                body: unwitnessed.prefix(4).map { "— \($0.line)" }.joined(separator: "\n"),
                tags: ["academy", "unwitnessed"]
            ))
        }

        // Who changed their mind, and what stayed unresolved.
        let concluded = inputs.undertakings.filter { $0.status == .concluded }
        if !concluded.isEmpty {
            items.append(item(
                id: "\(sectionID)-concluded",
                title: "Concluded, for a given value of concluded",
                body: concluded.prefix(4).map { "\(name($0.actorID)) — \($0.title). \($0.currentStage?.line ?? $0.pursuit)" }
                    .joined(separator: "\n\n"),
                tags: ["academy", "concluded"]
            ))
        }

        let unfinished = inputs.undertakings.filter { $0.isRunning }
        if !unfinished.isEmpty {
            items.append(item(
                id: "\(sectionID)-unresolved",
                title: "Still going on",
                body: unfinished.prefix(5).map { undertaking in
                    let stalled = undertaking.status == .stalled ? " (the trail has gone cold)" : ""
                    return "\(name(undertaking.actorID)) is still at it: \(undertaking.pursuit)\(stalled)"
                }.joined(separator: "\n"),
                tags: ["academy", "unresolved"]
            ))
        }

        // Alliances formed, and disputes that inconvenienced the uninvolved.
        let seasonPressures = inputs.pressures.filter { $0.beganAt >= start && $0.beganAt <= end }
        if !seasonPressures.isEmpty {
            items.append(item(
                id: "\(sectionID)-pressures",
                title: "Who stopped speaking, and who started",
                body: seasonPressures.prefix(4).map { "— \($0.summary)" }.joined(separator: "\n"),
                tags: ["academy", "relationships"]
            ))
        }

        // Where everyone was last seen.
        let rooms = inputs.placeStates.values
            .filter { $0.refusal != nil }
            .sorted { $0.id < $1.id }
        if !rooms.isEmpty {
            items.append(item(
                id: "\(sectionID)-rooms",
                title: "The rooms, and what they have started doing",
                body: rooms.prefix(4).map { room in
                    "\(room.id.replacingOccurrences(of: "location-", with: "").replacingOccurrences(of: "-", with: " ").capitalized) \(room.refusal ?? "")."
                }.joined(separator: "\n"),
                tags: ["academy", "places"]
            ))
        }

        guard !items.isEmpty else { return nil }

        // Always last, and always present when there is a season at all.
        items.append(item(
            id: "\(sectionID)-unexplained",
            title: "One thing the Book cannot account for",
            body: unexplained(movements: movements, inputs: inputs, name: name),
            tags: ["academy", "unexplained"]
        ))

        return MonthlyEditionSection(
            id: sectionID,
            title: "The Academy's Own Season",
            note: "Time passed here too. This is what was going on while you were living your life.",
            items: items
        )
    }

    /// The admitted mystery. Deliberately never resolved, and never dressed up
    /// as foreshadowing — it is simply a thing that does not add up.
    static func unexplained(
        movements: [CastAgencyMovement],
        inputs: Inputs,
        name: (String) -> String
    ) -> String {
        let seedSource = movements.last?.id ?? inputs.undertakings.first?.id ?? "quiet-season"
        var options: [String] = [
            "A door on the second floor was locked all season. It has no lock.",
            "The kitchens ran out of nothing at all, which has never once happened before.",
            "Somebody has been returning books that were never borrowed, in a hand nobody recognises.",
            "The lamp on the unofficial detour was replaced. Nobody has admitted to owning a ladder.",
            "A set of footprints crosses the Great Hall every Tuesday and stops in the middle."
        ]
        if let stalled = inputs.undertakings.first(where: { $0.status == .stalled }) {
            options.append("\(name(stalled.actorID)) stopped, mid-sentence, and has not said why. The work is still laid out on the desk.")
        }
        return options[abs(seedSource.stableHash) % options.count]
    }

    private static func item(id: String, title: String, body: String, tags: [String]) -> MonthlyEditionItem {
        MonthlyEditionItem(
            id: id,
            kind: .continuity,
            title: title,
            body: body,
            date: nil,
            pageType: nil,
            sourceID: nil,
            mediaAssets: [],
            tags: tags
        )
    }
}
