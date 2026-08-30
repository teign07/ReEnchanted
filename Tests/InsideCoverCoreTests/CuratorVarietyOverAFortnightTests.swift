import XCTest
@testable import InsideCoverCore

/// The measurement that started the loop work, kept as a regression.
///
/// Fourteen days, three sessions a day, recording served history exactly as the
/// app does. What it found the first time it was run:
///
///   - 273 distinct Pages were offered on the bench; only 88 ever reached a
///     desk, and **14 Pages took 52 of the 126 slots**.
///   - The tarot invitation took **14 desks in 14 days, the identical card face
///     every time**, because a daily recurrence slot bypassed the content
///     cooldown and a desk injection bypassed eligibility altogether.
///   - Anything that sends the reader outdoors reached the desk **6 times in
///     42 sessions**.
///
/// The thresholds below are deliberately looser than the numbers the loop work
/// achieved, so ordinary content changes do not fail the build — but a return
/// to any of the three faults above will.
final class CuratorVarietyOverAFortnightTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private struct Run {
        var desks = 0
        var slots = 0
        var desksWithAWayOut = 0
        var daysRead = 0
        var daysWithAWayOut = 0
        var daysWithoutAWayOut: [Int] = []
        var byPage: [String: Int] = [:]
        var byType: [BookPageType: Int] = [:]
        var answerGaps: [Int] = []
        /// Pages whose whole design is to arrive on a schedule — the nightly
        /// braid, the morning edition. The repetition test is about the Book
        /// repeating itself by accident, not about a ritual keeping its word.
        var ritualKeys: Set<String> = []
    }

    /// Two readers, because one is not a measurement.
    ///
    /// `steady` opens the Book three times a day at the same hours. `bursty`
    /// goes quiet for days and then reads twice in one late evening, which is
    /// what most reading actually looks like — and it is the case the rest
    /// ladders were never checked against, since `recentShowCount` resets
    /// itself after a week of quiet.
    private enum Reader: CaseIterable {
        case steady
        case bursty

        /// The hours this reader opens the Book on a given day, if at all.
        func sessions(onDay day: Int) -> [Int] {
            switch self {
            case .steady:
                return [8, 13, 20]
            case .bursty:
                switch day % 4 {
                case 0: return [22, 23]
                case 2: return [21]
                default: return []
                }
            }
        }
    }

    /// The reader's own ink, so the archive has a vocabulary rather than one
    /// sentence repeated fourteen times. The Book draws maps out of this.
    private static let lines = [
        "The kettle clicked off before the frost left the window.",
        "Frost on the window again, and the kettle going in the dark.",
        "Down at the harbour a lantern kept swinging over the jetty.",
        "The harbour, the jetty, and a lantern nobody was tending.",
        "A kestrel over the reservoir, holding still against the wind.",
        "The reservoir again, and the same kestrel, or its brother.",
        "Bread going stale on the counter beside the kettle.",
        "The lantern in the kitchen, and frost coming back to the window."
    ]

    private static var runs: [Reader: Run] = [:]

    private func fortnight(as reader: Reader) -> Run {
        if let cached = Self.runs[reader] { return cached }
        let run = compute(as: reader)
        Self.runs[reader] = run
        return run
    }

    private func compute(as reader: Reader) -> Run {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8, minute: 10))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: start.addingTimeInterval(-30 * 86_400))
        inputs.localBrainIsReady = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 46
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)

        var history: [BookDay] = []
        var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
        var run = Run()
        var sessionsSinceKeep: Int?
        var keptCount = 0

        for dayOffset in 0..<14 {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            var today = BookDay(
                id: BookDay.id(for: dayStart, calendar: calendar),
                date: calendar.startOfDay(for: dayStart),
                pages: []
            )
            let hours = reader.sessions(onDay: dayOffset)
            if !hours.isEmpty { run.daysRead += 1 }
            var wayOutToday = false
            for sessionHour in hours {
                let now = calendar.date(bySettingHour: sessionHour, minute: 15, second: 0, of: dayStart)!
                inputs.days = history + [today]
                inputs.resurfacingCandidates = (history + [today]).flatMap(\.pages)
                inputs.surfaceHistory = surfaceHistory

                // The folio publishes a block of nine turnable leaves, so the
                // block — not the opening trio — is what the reader actually
                // meets, and what this has to measure.
                let full = BookCurator.surfacedPages(
                    for: today, inputs: inputs, now: now,
                    limit: BookDeskRound.candidateBenchCapacity
                )
                let desk = Array(full.prefix(BookDeskRound.reserveCapacity))
                run.desks += 1
                run.slots += desk.count
                if desk.contains(where: { $0.deskJob == .errand }) {
                    run.desksWithAWayOut += 1
                    wayOutToday = true
                }
                if let pending = sessionsSinceKeep {
                    if desk.contains(where: { $0.deskJob == .reprise }) {
                        run.answerGaps.append(pending)
                        sessionsSinceKeep = nil
                    } else {
                        sessionsSinceKeep = pending + 1
                    }
                }
                for page in desk {
                    run.byPage[page.varietyKey, default: 0] += 1
                    run.byType[page.type, default: 0] += 1
                    if page.curatorAutomaticRecurrenceHistoryKey != nil || page.type == .bookOfYou {
                        run.ritualKeys.insert(page.varietyKey)
                    }
                }
                surfaceHistory = CuratorVarietyGovernor.recordingServed(
                    keys: desk.flatMap(\.curatorServedHistoryKeys), into: surfaceHistory, now: now
                )
                // The reader keeps something on their first visit of the day.
                if sessionHour == hours.first, let kept = desk.first {
                    sessionsSinceKeep = 0
                    let line = Self.lines[keptCount % Self.lines.count]
                    keptCount += 1
                    today.pages.append(BookPage(
                        id: "kept-\(dayOffset)-\(sessionHour)",
                        type: kept.type,
                        createdAt: now,
                        promptText: kept.prompt,
                        userInput: line,
                        origin: .userAuthored,
                        context: BookPageContextSnapshot(
                            at: now,
                            calendar: calendar,
                            weatherTags: dayOffset % 3 == 0 ? ["rain"] : ["clear"],
                            locationLabel: dayOffset % 5 == 0 ? "Home" : "Portland"
                        )
                    ))
                }
            }
            if wayOutToday {
                run.daysWithAWayOut += 1
            } else if !hours.isEmpty {
                run.daysWithoutAWayOut.append(dayOffset)
            }
            history.append(today)
        }
        return run
    }

    func testNoHandfulOfPagesOwnsTheFortnight() {
        for reader in Reader.allCases {
            let run = fortnight(as: reader)
            let worst = run.byPage
                .filter { !run.ritualKeys.contains($0.key) }
                .max { $0.value < $1.value }

            XCTAssertGreaterThan(run.slots, 40, "\(reader): the simulation composed almost nothing")
            // Scaled to how much of the Book this reader actually opened: a
            // fortnight of three-a-day and a fortnight of six visits cannot be
            // held to the same absolute count.
            XCTAssertGreaterThan(
                run.byPage.count * 2, run.slots,
                "\(reader): only \(run.byPage.count) distinct Pages across \(run.slots) leaves"
            )
            XCTAssertLessThanOrEqual(
                (worst?.value ?? 0) * 12, run.slots,
                "\(reader): one Page took \(worst?.value ?? 0) of \(run.slots) leaves: \(worst?.key ?? "")"
            )
        }
    }

    /// The loop's first beat. A desk that never sends the reader anywhere is
    /// not a turn of the loop however balanced it looks.
    /// Counted per reading day, not per session, and deliberately so. A reader
    /// who opens the Book twice in one evening will find the errand they just
    /// answered resting the second time, which is the rest rules working rather
    /// than the loop failing.
    ///
    /// Not every reading day, either. Three chairs cannot hold four things, and
    /// on a night when the braid is due *and* the Book owes an earned reading,
    /// two promises it already made outrank a beat it merely prefers. The way
    /// out yields on those days and comes back on the next one, which is the
    /// right order of priority — a promise kept beats a loop turned.
    func testTheLoopTurnsOnAlmostEveryDayTheReaderOpensTheBook() {
        for reader in Reader.allCases {
            let run = fortnight(as: reader)
            XCTAssertGreaterThan(run.daysRead, 5, "\(reader): barely read")
            XCTAssertGreaterThanOrEqual(
                run.daysWithAWayOut * 7, run.daysRead * 6,
                "\(reader): \(run.daysWithAWayOut) of \(run.daysRead) reading days offered a way out; missed \(run.daysWithoutAWayOut)"
            )
        }
    }

    /// The loop's last beat. A sentence the reader wrote on Tuesday, answered on
    /// Sunday, reads as the archive talking rather than as the loop closing.
    func testWhatTheReaderWritesIsAnsweredWhileItIsStillWarm() {
        for reader in Reader.allCases {
            let run = fortnight(as: reader)
            XCTAssertGreaterThan(run.answerGaps.count, 2, "\(reader): kept almost nothing")
            XCTAssertTrue(
                run.answerGaps.allSatisfy { $0 <= 4 },
                "\(reader): a keep waited \(run.answerGaps.max() ?? 0) sessions: \(run.answerGaps)"
            )
        }
    }

    /// Recurrence belongs to the job, rest belongs to the Page: the errand kind
    /// may lead the fortnight, but no single Page kind may own it.
    func testNoSinglePageKindOwnsTheFortnight() {
        for reader in Reader.allCases {
            let run = fortnight(as: reader)
            let worst = run.byType.max { $0.value < $1.value }
            XCTAssertLessThan(
                (worst?.value ?? 0) * 4, run.slots,
                "\(reader): \(worst?.key.rawValue ?? "") took \(worst?.value ?? 0) of \(run.slots) leaves"
            )
        }
    }
}
