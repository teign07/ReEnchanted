import XCTest
@testable import InsideCoverCore

/// The question every rule added to this Curator has to answer.
///
/// The loop work added floors, caps, rations and densities — and every one of
/// them decides a slot by rule rather than by what the Book has learned makes
/// this reader feel alive. That machinery is a safety net. The moment most of
/// the block arrives through it, the Curator has stopped curating and become
/// something that fills slots correctly.
///
/// Measured when this was written: 23 of 377 leaves across a simulated
/// fortnight were placed by a floor. The other 354 were composed by the
/// aliveness-weighted draw. That is the shape to keep.
final class CuratorStillCuratesTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private struct Run {
        var leaves = 0
        var placedByFloor = 0
        var readerMapsSeen = 0
        var distinctPages: Set<String> = []
    }

    private static var cached: Run?

    private func fortnight() -> Run {
        if let cached = Self.cached { return cached }
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8, minute: 10))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: start.addingTimeInterval(-30 * 86_400))
        inputs.localBrainIsReady = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 46
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)

        // Real ink, so the Book has a vocabulary to draw the reader's maps from.
        let lines = [
            "The kettle clicked off before the frost left the window.",
            "Frost on the window again, and the kettle going in the dark.",
            "Down at the harbour a lantern kept swinging over the jetty.",
            "The harbour, the jetty, and a lantern nobody was tending.",
            "A kestrel over the reservoir, holding still against the wind.",
            "The reservoir again, and the same kestrel, or its brother."
        ]
        var history: [BookDay] = []
        var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
        var run = Run()
        var kept = 0

        for dayOffset in 0..<14 {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            var today = BookDay(
                id: BookDay.id(for: dayStart, calendar: calendar),
                date: calendar.startOfDay(for: dayStart),
                pages: []
            )
            for hour in [8, 13, 20] {
                let now = calendar.date(bySettingHour: hour, minute: 15, second: 0, of: dayStart)!
                inputs.days = history + [today]
                inputs.resurfacingCandidates = (history + [today]).flatMap(\.pages)
                inputs.surfaceHistory = surfaceHistory

                let full = BookCurator.surfacedPages(
                    for: today, inputs: inputs, now: now,
                    limit: BookDeskRound.candidateBenchCapacity
                )
                let block = Array(full.prefix(BookDeskRound.reserveCapacity))
                run.leaves += block.count
                for page in block {
                    run.distinctPages.insert(page.varietyKey)
                    if page.payload.metadata[BookCurator.loopFloorMetadataKey] != nil {
                        run.placedByFloor += 1
                    }
                    if page.type == .marginsAtlas,
                       let variant = page.payload.metadata["graphVariant"],
                       ["hours", "skies", "places", "lexicon"].contains(variant) {
                        run.readerMapsSeen += 1
                    }
                }
                surfaceHistory = CuratorVarietyGovernor.recordingServed(
                    keys: block.flatMap(\.curatorServedHistoryKeys), into: surfaceHistory, now: now
                )
                if hour == 8, let first = block.first {
                    today.pages.append(BookPage(
                        id: "kept-\(dayOffset)", type: first.type, createdAt: now,
                        promptText: first.prompt, userInput: lines[kept % lines.count],
                        origin: .userAuthored,
                        context: BookPageContextSnapshot(
                            at: now, calendar: calendar,
                            weatherTags: dayOffset % 3 == 0 ? ["rain"] : ["clear"],
                            locationLabel: dayOffset % 5 == 0 ? "Home" : "Portland"
                        )
                    ))
                    kept += 1
                }
            }
            history.append(today)
        }
        Self.cached = run
        return run
    }

    /// The line: the rules may catch the desk, they may not compose it.
    func testTheBlockIsComposedByLearningRatherThanByRules() {
        let run = fortnight()

        XCTAssertGreaterThan(run.leaves, 200, "the simulation did not compose blocks")
        XCTAssertLessThan(
            run.placedByFloor * 5, run.leaves,
            "\(run.placedByFloor) of \(run.leaves) leaves were placed by a floor: the safety net has become the composer"
        )
    }

    /// A floor that never fires is not a floor. The other half of the same
    /// invariant: the net has to be there when the composition misses a beat.
    func testTheFloorsStillCatchWhatCompositionMisses() {
        let run = fortnight()

        XCTAssertGreaterThan(
            run.placedByFloor, 0,
            "no leaf in a fortnight needed a floor, so the floors are not doing anything"
        )
    }

    /// The maps of the reader have to actually reach a desk, not merely pass
    /// their own unit tests. `ReaderAtlas` exists to widen the thinnest deck in
    /// the Book from three cards to seven.
    func testTheMapsOfTheReaderReachTheDesk() {
        let run = fortnight()

        XCTAssertGreaterThan(
            run.readerMapsSeen, 0,
            "the Book never drew a map out of the reader's own pages in a fortnight"
        )
    }
}
