import XCTest
@testable import InsideCoverCore

/// An editorial play simulation, not a claim about real reader impact.
///
/// The existing simulations prove distribution, pressure, and evidence
/// contracts. This one walks a plausible target reader through thirty calendar
/// days so a human can read the actual desks at day one, week one, and month
/// one. It deliberately uses production adapters and `BookCurator`; the only
/// invented part is Maya's behavior and the ordinary-life evidence she brings
/// back.
final class ReaderJourneyPlaySimulationTests: XCTestCase {
    private struct Visit {
        var day: Int
        var keptLine: String?
        var tags: [String]
        var delayedOutcomeScore: Int?
        var delayedOutcomeLine: String?

        var crossesIntoLife: Bool {
            delayedOutcomeScore.map { $0 >= 6 } ?? false
        }
    }

    private struct DeskSnapshot {
        var day: Int
        var pages: [SurfacePage]
    }

    private struct MaturityDelta {
        var mature: [SurfacePage]
        var fresh: [SurfacePage]

        var sharedContentKeys: Set<String> {
            Set(mature.map(\.curatorContentNoveltyKey))
                .intersection(fresh.map(\.curatorContentNoveltyKey))
        }
    }

    private enum CohortBehavior: Equatable {
        case keepPrompted
        case dismiss
        case keepOnlyIfSpecific
    }

    private struct CohortVisit {
        var day: Int
        var behavior: CohortBehavior
        var responseLine: String?
        var spontaneousLine: String?
        var tags: [String]
        var delayedOutcomeScore: Int?
    }

    private struct CohortScenario {
        var id: String
        var name: String
        var summary: String
        var wonderEntry: String
        var leavingHome: String
        var comfort: String
        var favoriteWeather: String
        var preferredPlaces: String
        var socialEnergy: String
        var specificTerms: [String]
        var visits: [CohortVisit]
        var lowCapacityDays: Set<Int>
    }

    private struct CohortReport {
        var scenario: CohortScenario
        var horizonDays: Int
        var visitSnapshots: [DeskSnapshot]
        var allServed: [SurfacePage]
        var returnPages: [SurfacePage]
        var readerSpecificPages: [SurfacePage]
        var repeatedPrompts: [String: [SurfacePage]]
        var actionHeavyDeskCount: Int
        var guiltPages: [SurfacePage]
        var maturityDelta: MaturityDelta
        var reading: ReaderReenchantmentMetrics

        var finalMatureDesk: [SurfacePage] {
            visitSnapshots.last(where: { $0.day == horizonDays })?.pages ?? []
        }

        var matureLooksLearned: Bool {
            finalMatureDesk.contains { page in
                returnPages.contains(where: { $0.id == page.id })
                    || readerSpecificPages.contains(where: { $0.id == page.id })
            }
        }
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private var start: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 1,
            hour: 8,
            minute: 10
        ))!
    }

    func testTargetReaderDayWeekMonthTranscript() {
        let visits = Dictionary(uniqueKeysWithValues: targetVisits.map { ($0.day, $0) })
        var inputs = targetInputs()
        var history: [BookDay] = []
        var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
        var learning = ReaderLearningModel()
        var aliveness = ReaderAlivenessModel.unwritten
        var pulses = ReaderStatePulseLedger.empty
        var snapshots: [DeskSnapshot] = []
        var visitSnapshots: [DeskSnapshot] = []
        var servedDayByID: [String: Int] = [:]
        var allServed: [SurfacePage] = []
        var selectedPages: [SurfacePage] = []

        for dayOffset in 0..<30 {
            guard let visit = visits[dayOffset] else { continue }
            let now = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            var today = BookDay(
                id: BookDay.id(for: now, calendar: calendar),
                date: calendar.startOfDay(for: now),
                pages: []
            )

            inputs.days = history
            inputs.resurfacingCandidates = history.flatMap(\.pages)
            inputs.surfaceHistory = surfaceHistory
            inputs.readerLearning = learning
            inputs.readerAliveness = aliveness
            inputs.readerStatePulses = pulses
            inputs.weather = weather(on: dayOffset)
            inputs.body = body(on: dayOffset)
            inputs.calendarEvents = calendarEvents(on: dayOffset, now: now)
            inputs.currentLocationLabel = "Portland, Maine"
            inputs.bookInterior = BookInteriorEngine.reconciled(
                inputs.bookInterior,
                inputs: inputs,
                now: now,
                calendar: calendar
            )

            let desk = BookCurator.surfacedPages(
                for: today,
                context: CuratorContext.make(for: today),
                inputs: inputs,
                now: now,
                limit: 3
            )

            XCTAssertFalse(desk.isEmpty, "Maya opened the Book on day \(dayOffset + 1), but the desk was empty.")
            XCTAssertLessThanOrEqual(desk.count, 3)
            XCTAssertEqual(Set(desk.map(\.sourceID)).count, desk.count)
            XCTAssertEqual(Set(desk.map(\.type)).count, desk.count)
            XCTAssertLessThanOrEqual(desk.filter(\.isReaderActionCommission).count, 1)

            allServed.append(contentsOf: desk)
            visitSnapshots.append(DeskSnapshot(day: dayOffset + 1, pages: desk))
            for page in desk {
                servedDayByID[page.id] = dayOffset + 1
            }
            if [0, 6, 29].contains(dayOffset) {
                snapshots.append(DeskSnapshot(day: dayOffset + 1, pages: desk))
            }

            for surface in desk {
                let event = learningEvent(
                    for: surface,
                    action: .surfaced,
                    now: now,
                    evidence: nil
                )
                learning.record(event)
                aliveness.ingest(event)
            }
            surfaceHistory = CuratorVarietyGovernor.recordingServed(
                keys: desk.flatMap(\.curatorServedHistoryKeys),
                into: surfaceHistory,
                now: now
            )

            guard let chosen = choosePage(from: desk, on: dayOffset) else {
                history.append(today)
                continue
            }
            selectedPages.append(chosen)

            if let keptLine = visit.keptLine {
                let opened = learningEvent(
                    for: chosen,
                    action: .opened,
                    now: now.addingTimeInterval(90),
                    evidence: nil
                )
                learning.record(opened)
                aliveness.ingest(opened)

                let action: ReaderLearningAction = visit.crossesIntoLife
                    ? .keepsakeEarned
                    : .kept
                let evidence = visit.crossesIntoLife ? keptLine : nil
                let kept = learningEvent(
                    for: chosen,
                    action: action,
                    now: now.addingTimeInterval(8 * 3600),
                    evidence: evidence
                )
                learning.record(kept)
                aliveness.ingest(kept)

                today.pages.append(BookPage(
                    id: "maya-day-\(dayOffset + 1)",
                    type: .souvenir,
                    createdAt: now.addingTimeInterval(8 * 3600),
                    promptText: chosen.prompt,
                    userInput: keptLine,
                    tags: Array(Set(
                        visit.tags
                            + chosen.readerLearningTags
                            + (visit.crossesIntoLife ? ["lived-evidence", "keepsake-earned"] : [])
                    )).sorted(),
                    usedInBookOfYou: true,
                    sourceID: chosen.sourceID,
                    origin: .userAuthored
                ))
            } else {
                let dismissed = learningEvent(
                    for: chosen,
                    action: .dismissed,
                    now: now.addingTimeInterval(120),
                    evidence: nil
                )
                learning.record(dismissed)
                aliveness.ingest(dismissed)
            }

            if let score = visit.delayedOutcomeScore {
                pulses.record(delayedPulse(
                    for: chosen,
                    score: score,
                    line: visit.delayedOutcomeLine ?? "The Page stayed inside the Book.",
                    now: now.addingTimeInterval(12 * 3600)
                ))
            }
            history.append(today)
        }

        let finalNow = calendar.date(byAdding: .day, value: 29, to: start)!
            .addingTimeInterval(13 * 3600)
        let reading = ReaderReenchantmentMeasure.reading(
            pulses: pulses,
            aliveness: aliveness,
            longGame: inputs.bookInterior.longGame,
            learning: learning,
            days: history,
            now: finalNow,
            calendar: calendar
        )

        let distinctTypes = Set(allServed.map(\.type))
        let distinctSources = Set(allServed.map(\.sourceID))
        let repeatedPrompts = Dictionary(grouping: allServed, by: \.prompt)
            .filter { $0.value.count > 1 }
        let returnTypes: Set<BookPageType> = [
            .bookRemembered,
            .bookNotices,
            .bookConnections,
            .bookOfYou
        ]
        let returnPages = allServed.filter {
            returnTypes.contains($0.type) || $0.sourceID == "weekly-issue"
        }
        let readerSpecificPages = allServed.filter(isReaderSpecific)
        let maturityDelta = dayThirtyDelta(mature: snapshots.last?.pages ?? [])

        XCTAssertEqual(snapshots.map(\.day), [1, 7, 30])
        XCTAssertGreaterThanOrEqual(distinctTypes.count, 8)
        XCTAssertGreaterThanOrEqual(distinctSources.count, 10)
        XCTAssertFalse(returnPages.isEmpty, "A month of lived evidence produced no perceptible return Page.")
        XCTAssertGreaterThanOrEqual(readerSpecificPages.count, 2)
        XCTAssertGreaterThanOrEqual(reading.livedProofCount, 2)

        if ProcessInfo.processInfo.environment["REENCHANTED_PLAY_TRANSCRIPT"] == "1" {
            printTranscript(
                snapshots: snapshots,
                visitSnapshots: visitSnapshots,
                servedDayByID: servedDayByID,
                allServed: allServed,
                selectedPages: selectedPages,
                returnPages: returnPages,
                readerSpecificPages: readerSpecificPages,
                repeatedPrompts: repeatedPrompts,
                maturityDelta: maturityDelta,
                reading: reading
            )
        }
    }

    /// Opt-in because it deliberately runs three production-adapter months.
    /// The ordinary suite still compiles this harness but does not pay its
    /// roughly thirty-second runtime unless a play transcript was requested.
    func testTargetReaderCohortTranscript() {
        guard ProcessInfo.processInfo.environment["REENCHANTED_COHORT_TRANSCRIPT"] == "1" else {
            return
        }

        let reports = cohortScenarios.map { runCohortScenario($0) }
        XCTAssertEqual(reports.count, 3)

        for report in reports {
            XCTAssertFalse(report.visitSnapshots.isEmpty)
            XCTAssertEqual(report.visitSnapshots.last?.day, 30)
            if report.scenario.id == "lapsed" {
                XCTAssertTrue(
                    report.guiltPages.isEmpty,
                    "A returning reader should never be scolded for their absence."
                )
            }
            XCTAssertTrue(report.allServed.allSatisfy { !$0.prompt.isEmpty })
            XCTAssertTrue(report.visitSnapshots.allSatisfy { snapshot in
                snapshot.pages.count <= 3
                    && Set(snapshot.pages.map(\.sourceID)).count == snapshot.pages.count
                    && Set(snapshot.pages.map(\.type)).count == snapshot.pages.count
                    && snapshot.pages.filter(\.isReaderActionCommission).count <= 1
            })
            XCTAssertEqual(
                report.actionHeavyDeskCount,
                0,
                "\(report.scenario.name)'s visible desk stacked more than one felt ask."
            )
            XCTAssertTrue(
                report.finalMatureDesk.contains(where: \.carriesEarnedReaderTrace),
                "\(report.scenario.name)'s mature Book failed to spend reader-authored evidence."
            )
            XCTAssertFalse(
                report.maturityDelta.fresh.contains(where: \.carriesEarnedReaderTrace),
                "A fresh Book manufactured an earned trace."
            )
            let ownSpecificity = report.finalMatureDesk.filter {
                isReaderSpecific($0, terms: report.scenario.specificTerms)
            }.count
            let strongestOtherSpecificity = reports
                .filter { $0.scenario.id != report.scenario.id }
                .map { other in
                    report.finalMatureDesk.filter {
                        isReaderSpecific($0, terms: other.scenario.specificTerms)
                    }.count
                }
                .max() ?? 0
            XCTAssertGreaterThan(
                ownSpecificity,
                strongestOtherSpecificity,
                "The mature desk could not be matched blindly to \(report.scenario.name)."
            )
        }

        printCohortTranscript(reports)
    }

    /// Opt-in long-horizon editorial bench. Unlike the month transcript, this
    /// keeps each reader living with the production curator for a full season
    /// and then half a year, continuing to bring new evidence into the Book.
    func testTargetReaderThreeAndSixMonthCohortTranscript() {
        guard ProcessInfo.processInfo.environment["REENCHANTED_LONG_COHORT_TRANSCRIPT"] == "1" else {
            return
        }

        for horizonDays in [90, 180] {
            let scenarios = extendedCohortScenarios(horizonDays: horizonDays)
            let reports = scenarios.map { runCohortScenario($0, horizonDays: horizonDays) }
            XCTAssertEqual(reports.count, 3)

            for report in reports {
                XCTAssertEqual(report.visitSnapshots.last?.day, horizonDays)
                XCTAssertTrue(report.guiltPages.isEmpty)
                XCTAssertEqual(
                    report.actionHeavyDeskCount,
                    0,
                    "\(report.scenario.name)'s \(horizonDays)-day desk stacked felt asks."
                )
                XCTAssertTrue(
                    report.finalMatureDesk.contains(where: \.carriesEarnedReaderTrace),
                    "\(report.scenario.name)'s day-\(horizonDays) Book did not spend its newest evidence."
                )
                XCTAssertFalse(report.maturityDelta.fresh.contains(where: \.carriesEarnedReaderTrace))
                let repeatedSurfaceCount = report.repeatedPrompts.values.reduce(0) {
                    $0 + max(0, $1.count - 1)
                }
                let repeatShare = report.allServed.isEmpty
                    ? 0
                    : Double(repeatedSurfaceCount) / Double(report.allServed.count)
                XCTAssertLessThan(
                    repeatShare,
                    0.5,
                    "Exact prompt repetition consumed half of \(report.scenario.name)'s long-horizon desk."
                )
                let quillCeremonyCount = report.allServed.filter {
                    $0.sourceID == "quillquarium-choosing"
                }.count
                XCTAssertLessThanOrEqual(
                    quillCeremonyCount,
                    2,
                    "The once-ever quill choosing became recurring desk furniture."
                )
                XCTAssertFalse(report.allServed.contains {
                    $0.payload.metadata["personName"]?.caseInsensitiveCompare("Harbor") == .orderedSame
                }, "A place was inferred as a person thread.")
                if report.scenario.id != "lapsed" {
                    XCTAssertNotEqual(
                        report.reading.direction,
                        .dimming,
                        "Sustained positive lived proof was mistaken for dimming."
                    )
                }
                XCTAssertTrue(report.visitSnapshots.allSatisfy { snapshot in
                    snapshot.pages.count <= 3
                        && Set(snapshot.pages.map(\.sourceID)).count == snapshot.pages.count
                        && Set(snapshot.pages.map(\.type)).count == snapshot.pages.count
                        && snapshot.pages.filter(\.isReaderFacingAsk).count <= 1
                })

                let ownSpecificity = report.finalMatureDesk.filter {
                    isReaderSpecific($0, terms: report.scenario.specificTerms)
                }.count
                XCTAssertGreaterThan(
                    ownSpecificity,
                    0,
                    "The day-\(horizonDays) desk carried no visible evidence unique to \(report.scenario.name)."
                )
            }

            printCohortTranscript(reports)
        }
    }

    private var cohortScenarios: [CohortScenario] {
        [
            CohortScenario(
                id: "responsive",
                name: "Maya",
                summary: "Responsive but not compulsive; weather, place, and odd-detail affinity.",
                wonderEntry: "Odd details",
                leavingHome: "Ask gently",
                comfort: "gentle",
                favoriteWeather: "Rain against a window",
                preferredPlaces: "Old libraries, harbors, and laundromats at night",
                socialEnergy: "Usually alone, sometimes one person",
                specificTerms: mayaSpecificTerms,
                visits: targetVisits.map {
                    CohortVisit(
                        day: $0.day,
                        behavior: $0.keptLine == nil ? .dismiss : .keepPrompted,
                        responseLine: $0.keptLine,
                        spontaneousLine: nil,
                        tags: $0.tags,
                        delayedOutcomeScore: $0.delayedOutcomeScore
                    )
                },
                lowCapacityDays: [2, 17]
            ),
            CohortScenario(
                id: "lapsed",
                name: "Eli",
                summary: "Tired, low-capacity reader who disappears for long stretches and owes the Book nothing.",
                wonderEntry: "Quiet",
                leavingHome: "Keep wonder indoors",
                comfort: "very gentle",
                favoriteWeather: "A cold clear morning",
                preferredPlaces: "The kitchen, the parked car, and one bench near home",
                socialEnergy: "Usually alone",
                specificTerms: [
                    "eli", "radiator", "orange peel", "parking garage",
                    "paper moon", "blue bowl", "cold window"
                ],
                visits: [
                    CohortVisit(
                        day: 0,
                        behavior: .keepPrompted,
                        responseLine: "The radiator knocked three times, waited, then knocked once like it had corrected itself.",
                        spontaneousLine: nil,
                        tags: ["radiator", "home", "sound", "low-energy"],
                        delayedOutcomeScore: 6
                    ),
                    CohortVisit(
                        day: 1,
                        behavior: .dismiss,
                        responseLine: nil,
                        spontaneousLine: nil,
                        tags: [],
                        delayedOutcomeScore: nil
                    ),
                    CohortVisit(
                        day: 10,
                        behavior: .dismiss,
                        responseLine: nil,
                        spontaneousLine: "An orange peel on the blue bowl looked like a paper moon.",
                        tags: ["orange-peel", "blue-bowl", "paper-moon", "home"],
                        delayedOutcomeScore: nil
                    ),
                    CohortVisit(
                        day: 11,
                        behavior: .keepPrompted,
                        responseLine: "The parking garage held one square of cold sky at the very top.",
                        spontaneousLine: nil,
                        tags: ["parking-garage", "cold-sky", "outside", "low-energy"],
                        delayedOutcomeScore: 6
                    ),
                    CohortVisit(
                        day: 24,
                        behavior: .dismiss,
                        responseLine: nil,
                        spontaneousLine: "The cold window made the room's lamplight look warmer than it was.",
                        tags: ["cold-window", "lamplight", "home", "contrast"],
                        delayedOutcomeScore: nil
                    ),
                    CohortVisit(
                        day: 29,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "That was the right detail to bring back.",
                        spontaneousLine: nil,
                        tags: ["recognition", "return"],
                        delayedOutcomeScore: 7
                    )
                ],
                lowCapacityDays: [0, 1, 10, 11, 24, 29]
            ),
            CohortScenario(
                id: "skeptical",
                name: "Rowan",
                summary: "Skeptical reader who dismisses generic invitations and only rewards earned specificity.",
                wonderEntry: "Odd details",
                leavingHome: "Usually welcome",
                comfort: "sharp when earned",
                favoriteWeather: "Hard rain under shop lights",
                preferredPlaces: "Markets, ferry terminals, and working streets",
                socialEnergy: "One person",
                specificTerms: [
                    "rowan", "green cart", "harbor market", "squealed",
                    "gull", "receipt paper", "copper bell", "shop lights"
                ],
                visits: [
                    CohortVisit(
                        day: 0,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "That was exact enough to trust.",
                        spontaneousLine: "The green cart at Harbor Market squealed like a gate each time it turned left.",
                        tags: ["green-cart", "harbor-market", "sound", "exact-detail"],
                        delayedOutcomeScore: 7
                    ),
                    CohortVisit(
                        day: 3,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "That one knew which detail mattered.",
                        spontaneousLine: nil,
                        tags: ["recognition"],
                        delayedOutcomeScore: 7
                    ),
                    CohortVisit(
                        day: 7,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "The return earned another look.",
                        spontaneousLine: "The same green cart was silent in the rain, but a gull shouted from its handle.",
                        tags: ["green-cart", "rain", "gull", "harbor-market", "contrast"],
                        delayedOutcomeScore: 8
                    ),
                    CohortVisit(
                        day: 12,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "Yes. That was the exact corner of the day.",
                        spontaneousLine: "Receipt paper skittered under the shop lights and stopped beneath a copper bell.",
                        tags: ["receipt-paper", "shop-lights", "copper-bell", "movement"],
                        delayedOutcomeScore: 8
                    ),
                    CohortVisit(
                        day: 18,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "The Book finally made a claim instead of an invitation.",
                        spontaneousLine: "The Harbor Market clerk tied the copper bell still because the wind would not stop ringing it.",
                        tags: ["harbor-market", "copper-bell", "wind", "person"],
                        delayedOutcomeScore: 8
                    ),
                    CohortVisit(
                        day: 25,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "That connection was specific enough to argue with.",
                        spontaneousLine: "The green cart had been replaced; the new one turned perfectly and felt less alive.",
                        tags: ["green-cart", "replacement", "absence", "contrast"],
                        delayedOutcomeScore: 9
                    ),
                    CohortVisit(
                        day: 29,
                        behavior: .keepOnlyIfSpecific,
                        responseLine: "The Book noticed the absence, not merely the object.",
                        spontaneousLine: nil,
                        tags: ["recognition", "absence", "return"],
                        delayedOutcomeScore: 9
                    )
                ],
                lowCapacityDays: []
            )
        ]
    }

    private func extendedCohortScenarios(horizonDays: Int) -> [CohortScenario] {
        precondition(horizonDays >= 30)
        return cohortScenarios.map { original in
            var scenario = original
            let cadence: Int
            switch scenario.id {
            case "responsive": cadence = 5
            case "lapsed": cadence = 13
            default: cadence = 8
            }

            let evidence = longHorizonEvidence[scenario.id] ?? []
            var added: [CohortVisit] = []
            var day = 34
            var index = 0
            while day < horizonDays - 6 {
                let line = evidence[index % max(evidence.count, 1)]
                switch scenario.id {
                case "responsive":
                    let rests = index % 5 == 4
                    added.append(CohortVisit(
                        day: day,
                        behavior: rests ? .dismiss : .keepPrompted,
                        responseLine: rests ? nil : line,
                        spontaneousLine: nil,
                        tags: ["long-horizon", "ordinary-life", "maya"],
                        delayedOutcomeScore: rests ? nil : 7 + (index % 3)
                    ))
                case "lapsed":
                    added.append(CohortVisit(
                        day: day,
                        behavior: .dismiss,
                        responseLine: nil,
                        spontaneousLine: index.isMultiple(of: 2) ? line : nil,
                        tags: ["long-horizon", "low-capacity", "eli"],
                        delayedOutcomeScore: nil
                    ))
                    scenario.lowCapacityDays.insert(day)
                default:
                    let bringsWithoutReward = index.isMultiple(of: 2)
                    added.append(CohortVisit(
                        day: day,
                        behavior: bringsWithoutReward ? .dismiss : .keepOnlyIfSpecific,
                        responseLine: bringsWithoutReward ? nil : line,
                        spontaneousLine: bringsWithoutReward ? line : nil,
                        tags: ["long-horizon", "earned-specificity", "rowan"],
                        delayedOutcomeScore: bringsWithoutReward ? nil : 8
                    ))
                }
                day += cadence
                index += 1
            }

            // Leave a fresh, exact observation behind, give the Book its
            // three-day rest, then open once more at the horizon boundary.
            let evidenceDay = horizonDays - 5
            let finalDay = horizonDays - 1
            added.removeAll { $0.day == evidenceDay || $0.day == finalDay }
            let finalEvidence = evidence[(horizonDays / 30) % max(evidence.count, 1)]
            added.append(CohortVisit(
                day: evidenceDay,
                behavior: .dismiss,
                responseLine: nil,
                spontaneousLine: finalEvidence,
                tags: ["long-horizon", "final-evidence", scenario.id],
                delayedOutcomeScore: nil
            ))
            added.append(CohortVisit(
                day: finalDay,
                behavior: scenario.id == "responsive" ? .keepPrompted : .keepOnlyIfSpecific,
                responseLine: "The Book returned the exact thing that changed.",
                spontaneousLine: nil,
                tags: ["long-horizon", "recognition", scenario.id],
                delayedOutcomeScore: 8
            ))
            scenario.visits.append(contentsOf: added)
            scenario.visits.sort { $0.day < $1.day }
            return scenario
        }
    }

    private var longHorizonEvidence: [String: [String]] {
        [
            "responsive": [
                "Mara found the brass key again in her coat and left it beside the blue mug without explanation.",
                "Rain made the harbor ropes shine copper while the ferry windows stayed dark.",
                "The laundromat door breathed warm air onto the wet street each time someone entered.",
                "At blue hour, three porches lit in order as if the block were remembering a tune.",
                "Silver ladders crossed the kitchen window, but this time the rain climbed sideways.",
                "A bus-stop puddle kept one strip of copper sunset after the sky had lost it.",
                "Mara called the harbor fog a curtain and waited for the ferry to take a bow.",
                "The brass key left a green mark on the chipped blue mug's saucer.",
                "The wet street reflected the porches so clearly that the houses seemed underground.",
                "A laundromat sheet ballooned once, then folded itself around a square of blue hour."
            ],
            "lapsed": [
                "The radiator clicked once; the orange peel in the blue bowl had dried into a small paper moon.",
                "From the parking garage, one cold window held the last square of daylight.",
                "The blue bowl caught a stripe of sun and made the tired kitchen briefly look underwater.",
                "An orange peel curled beside the radiator like a question nobody needed to answer.",
                "The paper moon was still on the shelf when the cold window turned silver.",
                "At the parking garage exit, rain made the concrete smell almost green.",
                "The radiator warmed one side of the blue bowl and left the orange peel cold.",
                "A cold window reflected the kitchen lamp twice, one light for the room and one for outside."
            ],
            "skeptical": [
                "The green cart returned to Harbor Market with one wheel painted red and still did not squeal.",
                "Receipt paper caught beneath the copper bell and silenced it under the shop lights.",
                "A gull stood in the green cart as if it had been hired to inspect Harbor Market.",
                "The copper bell rang once after the shop lights went out, though the street was still.",
                "Someone wrote SOLD OUT on receipt paper and tucked it into the green cart's handle.",
                "Under hard rain, the Harbor Market gull drank from the groove where the old wheel squealed.",
                "The new green cart acquired a dent shaped like the copper bell it kept passing.",
                "Shop lights made the wet receipt paper transparent enough to show yesterday's ink."
            ]
        ]
    }

    private func runCohortScenario(
        _ scenario: CohortScenario,
        horizonDays: Int = 30
    ) -> CohortReport {
        var inputs = cohortInputs(for: scenario)
        var history: [BookDay] = []
        var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
        var learning = ReaderLearningModel()
        var aliveness = ReaderAlivenessModel.unwritten
        var pulses = ReaderStatePulseLedger.empty
        var visitSnapshots: [DeskSnapshot] = []
        var allServed: [SurfacePage] = []

        for visit in scenario.visits.sorted(by: { $0.day < $1.day }) {
            let now = calendar.date(byAdding: .day, value: visit.day, to: start)!
            var today = BookDay(
                id: BookDay.id(for: now, calendar: calendar),
                date: calendar.startOfDay(for: now),
                pages: []
            )

            inputs.days = history
            inputs.resurfacingCandidates = history.flatMap(\.pages)
            inputs.surfaceHistory = surfaceHistory
            inputs.readerLearning = learning
            inputs.readerAliveness = aliveness
            inputs.readerStatePulses = pulses
            inputs.weather = weather(on: visit.day)
            inputs.body = cohortBody(for: scenario, on: visit.day)
            inputs.calendarEvents = calendarEvents(on: visit.day, now: now)
            inputs.bookInterior = BookInteriorEngine.reconciled(
                inputs.bookInterior,
                inputs: inputs,
                now: now,
                calendar: calendar
            )

            if visit.day == horizonDays - 1,
               ProcessInfo.processInfo.environment["REENCHANTED_COHORT_TRANSCRIPT"] == "1" {
                let owed = EarnedReaderTracePolicy.owedEvidencePage(
                    day: today,
                    inputs: inputs,
                    distressActive: false,
                    now: now
                )
                let remembered = BookRememberedPageSourceAdapter().candidates(
                    for: today,
                    context: CuratorContext.make(for: today),
                    inputs: inputs,
                    now: now
                )
                let debugMood = CuratorMood.make(inputs: inputs, distressActive: false, now: now)
                let rememberedEligibility = remembered.map { page in
                    [
                        "trace=\(page.carriesEarnedReaderTrace)",
                        "mood=\(debugMood.allows(page))",
                        "memory=\(!BookMemoryGate.locks(page.type, keptPageCount: debugMood.keptPageCount))",
                        "novelty=\(CuratorNoveltyPolicy.allowsAutomaticSurface(page, history: debugMood.surfaceHistory, preferences: .none, now: now))",
                        "new=\(CuratorNoveltyPolicy.isNewContent(page, history: debugMood.surfaceHistory))"
                    ].joined(separator: ",")
                }.joined(separator: " // ")
                print(
                    "COHORT|DEBT|id=\(scenario.id)"
                    + "|owed=\(owed?.id ?? "none")"
                    + "|captured=\(history.flatMap(\.capturedPages).count)"
                    + "|last-trace=\(surfaceHistory[SurfacePage.earnedReaderTraceHistoryKey]?.lastShownAt.description ?? "none")"
                    + "|remembered-candidates=\(remembered.count)"
                    + "|remembered=\(remembered.map { singleLine($0.payload.metadata["rememberedText"] ?? "") }.joined(separator: " // "))"
                    + "|eligibility=\(rememberedEligibility)"
                )
            }

            let desk = BookCurator.surfacedPages(
                for: today,
                context: CuratorContext.make(for: today),
                inputs: inputs,
                now: now,
                limit: 3
            )
            visitSnapshots.append(DeskSnapshot(day: visit.day + 1, pages: desk))
            allServed.append(contentsOf: desk)

            for page in desk {
                let surfaced = learningEvent(
                    for: page,
                    action: .surfaced,
                    now: now,
                    evidence: nil
                )
                learning.record(surfaced)
                aliveness.ingest(surfaced)
            }
            surfaceHistory = CuratorVarietyGovernor.recordingServed(
                keys: desk.flatMap(\.curatorServedHistoryKeys),
                into: surfaceHistory,
                now: now
            )

            let chosen: SurfacePage?
            switch visit.behavior {
            case .keepPrompted, .dismiss:
                chosen = choosePage(from: desk, on: visit.day)
            case .keepOnlyIfSpecific:
                chosen = desk.first {
                    isReaderSpecific($0, terms: scenario.specificTerms)
                }
            }

            if let chosen, visit.behavior != .dismiss {
                let isCrossing = (visit.delayedOutcomeScore ?? 0) >= 6
                let action: ReaderLearningAction = isCrossing ? .keepsakeEarned : .kept
                let response = visit.responseLine ?? "This Page earned another look."
                let kept = learningEvent(
                    for: chosen,
                    action: action,
                    now: now.addingTimeInterval(8 * 3600),
                    evidence: isCrossing ? response : nil
                )
                learning.record(kept)
                aliveness.ingest(kept)
                today.pages.append(BookPage(
                    id: "\(scenario.id)-prompted-\(visit.day)",
                    type: .souvenir,
                    createdAt: now.addingTimeInterval(8 * 3600),
                    promptText: chosen.prompt,
                    userInput: response,
                    tags: Array(Set(visit.tags + chosen.readerLearningTags)).sorted(),
                    usedInBookOfYou: true,
                    sourceID: chosen.sourceID,
                    origin: .userAuthored
                ))
                if let score = visit.delayedOutcomeScore {
                    pulses.record(delayedPulse(
                        for: chosen,
                        score: score,
                        line: response,
                        now: now.addingTimeInterval(12 * 3600)
                    ))
                }
            } else if let dismissed = chosen ?? desk.first {
                let event = learningEvent(
                    for: dismissed,
                    action: .dismissed,
                    now: now.addingTimeInterval(120),
                    evidence: nil
                )
                learning.record(event)
                aliveness.ingest(event)
            }

            if let spontaneousLine = visit.spontaneousLine {
                let capture = externalCaptureSurface(
                    scenario: scenario,
                    day: visit.day,
                    line: spontaneousLine
                )
                let brought = learningEvent(
                    for: capture,
                    action: .broughtFromElsewhere,
                    now: now.addingTimeInterval(10 * 3600),
                    evidence: spontaneousLine
                )
                learning.record(brought)
                aliveness.ingest(brought)
                today.pages.append(BookPage(
                    id: "\(scenario.id)-spontaneous-\(visit.day)",
                    type: .souvenir,
                    createdAt: now.addingTimeInterval(10 * 3600),
                    promptText: "Brought from elsewhere",
                    userInput: spontaneousLine,
                    tags: Array(Set(visit.tags + ["brought-from-elsewhere", "spontaneous-evidence"])).sorted(),
                    usedInBookOfYou: true,
                    sourceID: capture.sourceID,
                    origin: .userAuthored
                ))
            }
            history.append(today)
        }

        let finalNow = calendar.date(byAdding: .day, value: horizonDays - 1, to: start)!
            .addingTimeInterval(13 * 3600)
        let returnPages = allServed.filter(isReturnPage)
        let specificPages = allServed.filter {
            isReaderSpecific($0, terms: scenario.specificTerms)
        }
        let repeatedPrompts = Dictionary(grouping: allServed, by: \.prompt)
            .filter { $0.value.count > 1 }
        let actionHeavyDesks = visitSnapshots.filter {
            perceivedActionCount(in: $0.pages) >= 2
        }.count
        let guiltPages = allServed.filter(usesGuiltLanguage)
        let reading = ReaderReenchantmentMeasure.reading(
            pulses: pulses,
            aliveness: aliveness,
            longGame: inputs.bookInterior.longGame,
            learning: learning,
            days: history,
            now: finalNow,
            calendar: calendar
        )
        let mature = visitSnapshots.last(where: { $0.day == horizonDays })?.pages ?? []
        let delta = cohortMaturityDelta(
            scenario: scenario,
            mature: mature,
            horizonDays: horizonDays
        )

        return CohortReport(
            scenario: scenario,
            horizonDays: horizonDays,
            visitSnapshots: visitSnapshots,
            allServed: allServed,
            returnPages: returnPages,
            readerSpecificPages: specificPages,
            repeatedPrompts: repeatedPrompts,
            actionHeavyDeskCount: actionHeavyDesks,
            guiltPages: guiltPages,
            maturityDelta: delta,
            reading: reading
        )
    }

    private func cohortInputs(for scenario: CohortScenario) -> BookSourceInputs {
        var inputs = targetInputs()
        let replacements: [String: String] = [
            "onboarding-name": scenario.name,
            "wonder-entry": scenario.wonderEntry,
            "leaving-home": scenario.leavingHome,
            "onboarding-comfort-boundary": scenario.comfort,
            "favorite-weather": scenario.favoriteWeather,
            "favorite-kind-of-place": scenario.preferredPlaces,
            "social-energy": scenario.socialEnergy
        ]
        inputs.selfFacts = inputs.selfFacts.map { fact in
            guard let replacement = replacements[fact.questionID] else { return fact }
            var updated = fact
            updated.answer = replacement
            updated.bookTranslation = replacement
            return updated
        }
        return inputs
    }

    private func cohortBody(for scenario: CohortScenario, on day: Int) -> BodySourceSignal {
        guard scenario.lowCapacityDays.contains(day) else {
            return body(on: day)
        }
        return BodySourceSignal(
            status: "low",
            score: 24,
            phrase: "Energy is narrow; seated and indoor options only."
        )
    }

    private func externalCaptureSurface(
        scenario: CohortScenario,
        day: Int,
        line: String
    ) -> SurfacePage {
        SurfacePage(
            id: "\(scenario.id)-external-capture-\(day)",
            type: .souvenir,
            sourceID: "external-capture",
            intent: .capture,
            renderStyle: .promptCard,
            score: 0,
            reason: "The reader brought this from ordinary life without being asked.",
            prompt: "Brought from elsewhere",
            detail: line,
            payload: BookPagePayload(
                headline: "Brought from elsewhere",
                body: line,
                metadata: [
                    "source": "external-capture",
                    "tags": "brought-from-elsewhere,spontaneous-evidence"
                ]
            )
        )
    }

    private func cohortMaturityDelta(
        scenario: CohortScenario,
        mature: [SurfacePage],
        horizonDays: Int
    ) -> MaturityDelta {
        let finalDay = horizonDays - 1
        let now = calendar.date(byAdding: .day, value: finalDay, to: start)!
        let day = BookDay(
            id: BookDay.id(for: now, calendar: calendar),
            date: calendar.startOfDay(for: now),
            pages: []
        )
        var freshInputs = cohortInputs(for: scenario)
        freshInputs.weather = weather(on: finalDay)
        freshInputs.body = cohortBody(for: scenario, on: finalDay)
        freshInputs.calendarEvents = calendarEvents(on: finalDay, now: now)
        freshInputs.bookInterior = BookInteriorEngine.reconciled(
            freshInputs.bookInterior,
            inputs: freshInputs,
            now: now,
            calendar: calendar
        )
        let fresh = BookCurator.surfacedPages(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: freshInputs,
            now: now,
            limit: 3
        )
        return MaturityDelta(mature: mature, fresh: fresh)
    }

    private func isReturnPage(_ page: SurfacePage) -> Bool {
        let returnTypes: Set<BookPageType> = [
            .bookRemembered,
            .bookNotices,
            .bookConnections,
            .bookOfYou
        ]
        return returnTypes.contains(page.type) || page.sourceID == "weekly-issue"
    }

    private func perceivedActionCount(in desk: [SurfacePage]) -> Int {
        let imperativeOpenings = [
            "keep ", "write ", "find ", "choose ", "name ", "give ",
            "replace ", "use ", "move ", "notice ", "open ", "take ",
            "ask ", "spend ", "visit ", "let ", "look ", "pick ",
            "stand ", "answer ", "log ", "bring ", "turn "
        ]
        let questionTypes: Set<BookPageType> = [
            .mood,
            .diary,
            .souvenir,
            .body,
            .fuel,
            .aboutYou
        ]
        return desk.filter { page in
            if page.isReaderActionCommission { return true }
            let prompt = page.prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let detail = page.detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if imperativeOpenings.contains(where: prompt.hasPrefix)
                || imperativeOpenings.contains(where: detail.hasPrefix) {
                return true
            }
            return prompt.contains("?") && questionTypes.contains(page.type)
        }.count
    }

    private func usesGuiltLanguage(_ page: SurfacePage) -> Bool {
        let text = [
            page.prompt,
            page.detail,
            page.reason,
            page.payload.body
        ].joined(separator: " ").lowercased()
        let guiltPhrases = [
            "you have been away",
            "you've been away",
            "where have you been",
            "come back to the book",
            "return to the book",
            "still waiting for you",
            "you missed",
            "do not fall behind",
            "don't fall behind",
            "owe the book",
            "the book missed you"
        ]
        return guiltPhrases.contains(where: text.contains)
    }

    private func printCohortTranscript(_ reports: [CohortReport]) {
        for report in reports {
            let matureSignature = report.maturityDelta.mature.map {
                "\($0.type.rawValue):\(singleLine($0.prompt))"
            }.joined(separator: " // ")
            let freshSignature = report.maturityDelta.fresh.map {
                "\($0.type.rawValue):\(singleLine($0.prompt))"
            }.joined(separator: " // ")
            let finalSpecific = report.finalMatureDesk.filter {
                isReaderSpecific($0, terms: report.scenario.specificTerms)
            }.count
            let finalReturns = report.finalMatureDesk.filter(isReturnPage).count
            let freshSpecific = report.maturityDelta.fresh.filter {
                isReaderSpecific($0, terms: report.scenario.specificTerms)
            }.count
            let identifiable = finalSpecific > freshSpecific
                && report.finalMatureDesk.contains(where: \.carriesEarnedReaderTrace)
            let traceVisits = report.visitSnapshots.filter { snapshot in
                snapshot.pages.contains(where: \.carriesEarnedReaderTrace)
            }.count
            let repeatedSurfaceCount = report.repeatedPrompts.values.reduce(0) {
                $0 + max(0, $1.count - 1)
            }
            let repeatShare = report.allServed.isEmpty
                ? 0
                : Double(repeatedSurfaceCount) / Double(report.allServed.count)
            let maximumPromptUses = report.repeatedPrompts.values.map(\.count).max() ?? 1
            let topRepeatedPrompt = report.repeatedPrompts.max { lhs, rhs in
                lhs.value.count < rhs.value.count
            }?.key ?? "none"

            print(
                "COHORT|PERSONA|horizon=\(report.horizonDays)|id=\(report.scenario.id)|name=\(report.scenario.name)"
                + "|visits=\(report.visitSnapshots.count)|served=\(report.allServed.count)"
                + "|returns=\(report.returnPages.count)|visible-specific=\(report.readerSpecificPages.count)"
                + "|repeated-prompts=\(report.repeatedPrompts.count)"
                + "|repeat-share=\(String(format: "%.3f", repeatShare))"
                + "|max-prompt-uses=\(maximumPromptUses)|trace-visits=\(traceVisits)"
                + "|top-repeat=\(singleLine(topRepeatedPrompt))"
                + "|action-heavy-desks=\(report.actionHeavyDeskCount)"
                + "|guilt-pages=\(report.guiltPages.count)"
            )
            for snapshot in report.visitSnapshots {
                let signature = snapshot.pages.map {
                    "\($0.type.rawValue):\(singleLine($0.prompt))"
                }.joined(separator: " // ")
                print("COHORT|VISIT|horizon=\(report.horizonDays)|id=\(report.scenario.id)|day=\(snapshot.day)|\(signature)")
            }
            print(
                "COHORT|BLIND|horizon=\(report.horizonDays)|id=\(report.scenario.id)|identifiable-mature=\(identifiable)"
                + "|shared=\(report.maturityDelta.sharedContentKeys.count)"
                + "|final-specific=\(finalSpecific)|final-returns=\(finalReturns)"
                + "|fresh-specific=\(freshSpecific)"
            )
            print("COHORT|MATURE|horizon=\(report.horizonDays)|id=\(report.scenario.id)|\(matureSignature)")
            printCohortCards(
                report.maturityDelta.mature,
                scenarioID: report.scenario.id,
                side: "mature"
            )
            print("COHORT|FRESH|horizon=\(report.horizonDays)|id=\(report.scenario.id)|\(freshSignature)")
            printCohortCards(
                report.maturityDelta.fresh,
                scenarioID: report.scenario.id,
                side: "fresh"
            )
            print(
                "COHORT|MEASURE|id=\(report.scenario.id)"
                + "|direction=\(report.reading.direction.rawValue)"
                + "|lived-proofs=\(report.reading.livedProofCount)"
                + "|confidence=\(report.reading.confidence)"
            )
        }
    }

    private func printCohortCards(
        _ pages: [SurfacePage],
        scenarioID: String,
        side: String
    ) {
        for (position, page) in pages.enumerated() {
            print(
                "COHORT|CARD|id=\(scenarioID)|side=\(side)|position=\(position + 1)"
                + "|type=\(page.type.rawValue)"
                + "|prompt=\(singleLine(page.prompt))"
                + "|detail=\(singleLine(page.detail))"
                + "|body=\(singleLine(page.payload.body))"
            )
        }
    }

    private var targetVisits: [Visit] {
        [
            Visit(
                day: 0,
                keptLine: "At 6:40 the kitchen window turned the rain copper, and the chipped blue mug looked briefly ceremonial.",
                tags: ["rain", "window", "copper-light", "blue-mug", "home"],
                delayedOutcomeScore: 7,
                delayedOutcomeLine: "I kept looking for copper light after I closed the Book."
            ),
            Visit(
                day: 1,
                keptLine: "The bus-stop puddle held the entire pharmacy sign upside down.",
                tags: ["rain", "reflection", "bus-stop", "odd-detail", "outside"],
                delayedOutcomeScore: 8,
                delayedOutcomeLine: "The errand felt less like dead time because I was looking."
            ),
            Visit(
                day: 2,
                keptLine: nil,
                tags: [],
                delayedOutcomeScore: nil,
                delayedOutcomeLine: nil
            ),
            Visit(
                day: 4,
                keptLine: "Mara sent a photograph of the harbor fog swallowing the ferry one careful inch at a time.",
                tags: ["mara", "harbor", "fog", "ferry", "person"],
                delayedOutcomeScore: 6,
                delayedOutcomeLine: "I sent Mara one strange thing back instead of a thumbs-up."
            ),
            Visit(
                day: 6,
                keptLine: "The laundromat dryers turned every shirt into a weather system.",
                tags: ["laundromat", "weather", "ordinary-place", "motion"],
                delayedOutcomeScore: 7,
                delayedOutcomeLine: "The laundry was still laundry, but it did not feel blank."
            ),
            Visit(
                day: 8,
                keptLine: "I took the longer wet street home; three porches had left their lights on for nobody.",
                tags: ["rain", "long-way", "porch-light", "outside", "lived-return"],
                delayedOutcomeScore: 9,
                delayedOutcomeLine: "I chose the longer street without needing another prompt."
            ),
            Visit(
                day: 11,
                keptLine: "The blue hour stayed in the kitchen after the windows had already gone black.",
                tags: ["blue-hour", "kitchen", "window", "light", "home"],
                delayedOutcomeScore: 7,
                delayedOutcomeLine: "I noticed the hour before I remembered the Book."
            ),
            Visit(
                day: 14,
                keptLine: "Mara and I found a brass key on the harbor wall and invented three doors it had refused.",
                tags: ["mara", "harbor", "brass-key", "play", "shared-wonder"],
                delayedOutcomeScore: 9,
                delayedOutcomeLine: "The little game escaped the phone and became ours."
            ),
            Visit(
                day: 17,
                keptLine: nil,
                tags: [],
                delayedOutcomeScore: 2,
                delayedOutcomeLine: "Nothing crossed the glass that day; I was too tired."
            ),
            Visit(
                day: 21,
                keptLine: "Rain wrote silver ladders down the same kitchen window, but tonight I heard it before I saw it.",
                tags: ["rain", "window", "silver", "sound", "home"],
                delayedOutcomeScore: 8,
                delayedOutcomeLine: "The old window felt newly audible."
            ),
            Visit(
                day: 25,
                keptLine: "The harbor was clear. Without the fog, the cranes looked less mysterious and more like patient red animals.",
                tags: ["harbor", "clear-weather", "cranes", "animals", "contrast"],
                delayedOutcomeScore: 8,
                delayedOutcomeLine: "The place changed because the weather changed, and I caught the difference."
            ),
            Visit(
                day: 29,
                keptLine: "Mara called the blue hour 'the day keeping one lamp for itself.' I wish I had written it first.",
                tags: ["mara", "blue-hour", "lamp", "exact-language", "person"],
                delayedOutcomeScore: 9,
                delayedOutcomeLine: "A phrase from real life became the thing I wanted to keep."
            )
        ]
    }

    private func targetInputs() -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(
            awakenedAt: start.addingTimeInterval(-14 * 86_400)
        )
        inputs.localBrainIsReady = true
        inputs.calendarIntegrationEnabled = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 46
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)
        inputs.selfFacts = [
            fact("onboarding-name", answer: "Maya", tags: ["name", "identity", "onboarding"]),
            fact("onboarding-snack", answer: "salted toast", tags: ["snack", "comfort", "onboarding"]),
            fact("onboarding-belief", answer: "Ordinary things are stranger when I slow down.", tags: ["belief", "values", "onboarding"]),
            fact("onboarding-first-souvenir", answer: "The kettle clicked off before dawn.", tags: ["souvenir", "first-run-souvenir", "onboarding"]),
            fact("onboarding-taste", answer: "weather-place", tags: ["taste", "curation", "onboarding"]),
            fact("onboarding-drawn-chapter", answer: "Mossbloom", tags: ["chapter", "onboarding"]),
            fact("onboarding-comfort-boundary", answer: "gentle", tags: ["comfort", "onboarding"]),
            fact("wonder-entry", answer: "Odd details", tags: ["wonder", "wonder-entry", "curation"]),
            fact("favorite-weather", answer: "Rain against a window", tags: ["weather", "delight"]),
            fact("sensory-door", answer: "Color first, then sound", tags: ["sense", "wonder-affinity", "curation"]),
            fact("favorite-kind-of-place", answer: "Old libraries, harbors, and laundromats at night", tags: ["place", "wonder-affinity", "curation"]),
            fact("leaving-home", answer: "Ask gently", tags: ["boundary", "home", "curation"]),
            fact("social-energy", answer: "Usually alone, sometimes one person", tags: ["people", "social", "curation"]),
            fact("money-boundary", answer: "Free by default", tags: ["boundary", "budget", "curation"]),
            fact("desired-surprise", answer: "A strange fact or an overlooked detail", tags: ["surprise", "wonder-affinity", "curation"])
        ]
        return inputs
    }

    private func fact(_ questionID: String, answer: String, tags: [String]) -> SelfFact {
        let createdAt = start.addingTimeInterval(-86_400)
        return SelfFact(
            id: "maya-\(questionID)",
            questionID: questionID,
            question: questionID,
            answer: answer,
            bookTranslation: answer,
            sensitivity: .delight,
            usePermission: .privateContext,
            tags: tags,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func weather(on day: Int) -> WeatherSourceSignal {
        switch day {
        case 0, 1, 8, 21:
            return WeatherSourceSignal(
                phrase: "Steady rain against the glass, 57F",
                source: "play-simulation",
                forecast: "rain through evening",
                conditionSymbolName: "cloud.rain"
            )
        case 4:
            return WeatherSourceSignal(
                phrase: "Harbor fog, 54F",
                source: "play-simulation",
                forecast: "fog lifting late",
                conditionSymbolName: "cloud.fog"
            )
        case 25:
            return WeatherSourceSignal(
                phrase: "Clear and cold near the harbor, 49F",
                source: "play-simulation",
                forecast: "clear through evening",
                conditionSymbolName: "sun.max"
            )
        default:
            return WeatherSourceSignal(
                phrase: "Thin autumn cloud, 61F",
                source: "play-simulation",
                forecast: "dry with late light",
                conditionSymbolName: "cloud.sun"
            )
        }
    }

    private func body(on day: Int) -> BodySourceSignal {
        let isTired = [2, 17].contains(day)
        return BodySourceSignal(
            status: isTired ? "low" : "steady",
            score: isTired ? 32 : 64,
            phrase: isTired
                ? "Sleep was short; energy is narrow."
                : "Enough energy for one small outward thing."
        )
    }

    private func calendarEvents(on day: Int, now: Date) -> [CalendarEventSignal] {
        guard [4, 14, 25].contains(day) else { return [] }
        return [CalendarEventSignal(
            id: "maya-calendar-\(day)",
            title: day == 14 ? "Meet Mara by the harbor" : "Evening errand",
            startsAt: now.addingTimeInterval(9 * 3600),
            endsAt: now.addingTimeInterval(10 * 3600),
            isAllDay: false
        )]
    }

    private func choosePage(from desk: [SurfacePage], on day: Int) -> SurfacePage? {
        if [2, 17].contains(day) {
            return desk.first
        }
        let preferred: [BookPageType] = [
            .bookRemembered,
            .bookNotices,
            .bookConnections,
            .wonderCompass,
            .weather,
            .souvenir,
            .quip,
            .letter
        ]
        for type in preferred {
            if let page = desk.first(where: { $0.type == type }) {
                return page
            }
        }
        return desk.first
    }

    private func learningEvent(
        for surface: SurfacePage,
        action: ReaderLearningAction,
        now: Date,
        evidence: String?
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            dayID: BookDay.id(for: now, calendar: calendar),
            occurredAt: now,
            action: action,
            surfaceID: surface.id,
            sourceID: surface.sourceID,
            type: surface.type,
            varietyKey: surface.varietyKey,
            contentKey: surface.curatorContentNoveltyKey,
            hour: calendar.component(.hour, from: now),
            tags: surface.readerLearningTags,
            evidence: evidence,
            causalReceipt: CausalCurationReceipt.read(from: surface),
            causalMovementReceipt: BookSessionIntention.read(from: surface)?.causalMovementReceipt
        )
    }

    private func delayedPulse(
        for surface: SurfacePage,
        score: Int,
        line: String,
        now: Date
    ) -> ReaderStatePulseRecord {
        let intention = BookSessionIntention.read(from: surface)
        let receipt = CausalCurationReceipt.read(from: surface)
        let role = surface.payload.metadata[BookSessionIntention.metadataRole]
            .flatMap(BookSessionRole.init(rawValue:))
        return ReaderStatePulseRecord(
            id: "maya-pulse-\(BookDay.id(for: now, calendar: calendar))-\(surface.id)",
            dimension: .delayedOutcome,
            score: score,
            answerCode: score >= 6 ? "yes" : "no",
            answerLine: line,
            note: line,
            askedAt: now.addingTimeInterval(-3600),
            answeredAt: now,
            dayID: BookDay.id(for: now, calendar: calendar),
            context: nil,
            facets: [
                "time:evening",
                weather(on: calendar.dateComponents([.day], from: start, to: now).day ?? 0)
                    .conditionSymbolName
            ],
            target: ReaderStatePulseTarget(
                sessionID: intention?.id ?? "maya-session-\(surface.id)",
                movement: intention?.movement ?? .freshSight,
                role: role,
                sourceID: surface.sourceID,
                pageID: surface.id,
                causalOpportunityID: receipt?.id,
                causalMovementOpportunityID: intention?.causalMovementReceipt?.id,
                happenedAt: now.addingTimeInterval(-8 * 3600)
            )
        )
    }

    private func dayThirtyDelta(mature: [SurfacePage]) -> MaturityDelta {
        let now = calendar.date(byAdding: .day, value: 29, to: start)!
        let day = BookDay(
            id: BookDay.id(for: now, calendar: calendar),
            date: calendar.startOfDay(for: now),
            pages: []
        )
        var freshInputs = targetInputs()
        freshInputs.weather = weather(on: 29)
        freshInputs.body = body(on: 29)
        freshInputs.calendarEvents = calendarEvents(on: 29, now: now)
        freshInputs.bookInterior = BookInteriorEngine.reconciled(
            freshInputs.bookInterior,
            inputs: freshInputs,
            now: now,
            calendar: calendar
        )
        let fresh = BookCurator.surfacedPages(
            for: day,
            context: CuratorContext.make(for: day),
            inputs: freshInputs,
            now: now,
            limit: 3
        )
        return MaturityDelta(mature: mature, fresh: fresh)
    }

    private var mayaSpecificTerms: [String] {
        [
            "maya",
            "mara",
            "harbor",
            "copper",
            "blue hour",
            "bus-stop",
            "laundromat",
            "wet street",
            "porches",
            "silver ladders",
            "brass key"
        ]
    }

    private func isReaderSpecific(_ page: SurfacePage) -> Bool {
        isReaderSpecific(page, terms: mayaSpecificTerms)
    }

    private func isReaderSpecific(
        _ page: SurfacePage,
        terms: [String]
    ) -> Bool {
        var visibleText = [
            page.prompt,
            page.detail,
            page.reason,
            page.payload.metadata["bookActedMargin"] ?? ""
        ]
        let previewsBody: Set<BookPageType> = [
            .wonderCompass,
            .patreon,
            .illustration,
            .illuminatedPhoto,
            .quip,
            .narrativeOS,
            .marginsAtlas,
            .bookConnections,
            .bookRemembered,
            .bookNotices,
            .theBleed,
            .radio,
            .facultyResearch,
            .supportGuild
        ]
        if previewsBody.contains(page.type) || page.renderStyle == .quoteCard {
            visibleText.append(page.payload.body)
        }
        let text = visibleText.joined(separator: " ").lowercased()
        let textTokens = text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        return terms.contains { term in
            let termTokens = term
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
            guard !termTokens.isEmpty else { return false }
            if termTokens.count == 1 {
                return textTokens.contains(termTokens[0])
            }
            guard textTokens.count >= termTokens.count else { return false }
            return (0...(textTokens.count - termTokens.count)).contains { start in
                Array(textTokens[start..<(start + termTokens.count)]) == termTokens
            }
        }
    }

    private func printTranscript(
        snapshots: [DeskSnapshot],
        visitSnapshots: [DeskSnapshot],
        servedDayByID: [String: Int],
        allServed: [SurfacePage],
        selectedPages: [SurfacePage],
        returnPages: [SurfacePage],
        readerSpecificPages: [SurfacePage],
        repeatedPrompts: [String: [SurfacePage]],
        maturityDelta: MaturityDelta,
        reading: ReaderReenchantmentMetrics
    ) {
        print("PLAY|PERSONA|Maya, busy adult, odd-details/weather/place affinity, gentle boundaries")
        for snapshot in snapshots {
            print("PLAY|HORIZON|day=\(snapshot.day)|cards=\(snapshot.pages.count)")
            for (index, page) in snapshot.pages.enumerated() {
                let role = page.payload.metadata[BookSessionIntention.metadataRole] ?? "unassigned"
                let acted = page.payload.metadata["bookActedMargin"] ?? ""
                print(
                    "PLAY|PAGE|day=\(snapshot.day)|slot=\(index + 1)|role=\(role)|type=\(page.type.rawValue)"
                    + "|prompt=\(singleLine(page.prompt))|detail=\(singleLine(page.detail))"
                    + (acted.isEmpty ? "" : "|book-trace=\(singleLine(acted))")
                )
            }
        }
        for snapshot in visitSnapshots {
            let signature = snapshot.pages.map {
                "\($0.type.rawValue):\(singleLine($0.prompt))"
            }.joined(separator: " // ")
            print("PLAY|VISIT|day=\(snapshot.day)|\(signature)")
        }
        print(
            "PLAY|MONTH|visits=\(targetVisits.count)|served=\(allServed.count)"
            + "|selected=\(selectedPages.count)|types=\(Set(allServed.map(\.type)).count)"
            + "|sources=\(Set(allServed.map(\.sourceID)).count)|returns=\(returnPages.count)"
            + "|reader-specific=\(readerSpecificPages.count)|repeated-prompts=\(repeatedPrompts.count)"
        )
        print(
            "PLAY|MEASURE|direction=\(reading.direction.rawValue)|lived-proofs=\(reading.livedProofCount)"
            + "|supporting=\(reading.supportingSignalCount)|confidence=\(reading.confidence)"
        )
        for page in returnPages.prefix(8) {
            print(
                "PLAY|RETURN|day=\(servedDayByID[page.id] ?? 0)|type=\(page.type.rawValue)|prompt=\(singleLine(page.prompt))"
                + "|detail=\(singleLine(page.detail))"
            )
        }
        let matureSignature = maturityDelta.mature.map {
            "\($0.type.rawValue):\(singleLine($0.prompt))"
        }.joined(separator: " // ")
        let freshSignature = maturityDelta.fresh.map {
            "\($0.type.rawValue):\(singleLine($0.prompt))"
        }.joined(separator: " // ")
        print(
            "PLAY|MATURITY-DELTA|shared=\(maturityDelta.sharedContentKeys.count)"
            + "|mature=\(matureSignature)|fresh=\(freshSignature)"
        )
        for page in readerSpecificPages.prefix(8) {
            print(
                "PLAY|SPECIFIC|day=\(servedDayByID[page.id] ?? 0)|type=\(page.type.rawValue)"
                + "|prompt=\(singleLine(page.prompt))|detail=\(singleLine(page.detail))"
            )
        }
        for (prompt, pages) in repeatedPrompts.sorted(by: { $0.key < $1.key }).prefix(8) {
            print("PLAY|REPEAT|count=\(pages.count)|prompt=\(singleLine(prompt))")
        }
    }

    private func singleLine(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "|", with: "/")
    }
}
