import XCTest
@testable import InsideCoverCore

/// Where the desk build's time actually goes.
///
/// Guessing from reading has been wrong every time this was tried, so this
/// harness builds a realistic archive once and times the pass the way the app
/// runs it: candidate gathering per adapter, then ranking. Gated so a normal
/// `swift test` never pays for it:
///
///   DESK_BENCH=1 swift test -c release --filter DeskBuildBench
final class DeskBuildBench: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private struct Corpus {
        var days: [BookDay]
        var today: BookDay
        var inputs: BookSourceInputs
        var now: Date
    }

    private func corpus(dayCount: Int = 90) -> Corpus {
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 8, minute: 10))!
        var inputs = BookSourceInputs.empty
        inputs.bookInterior = BookInteriorState(awakenedAt: start.addingTimeInterval(-30 * 86_400))
        inputs.localBrainIsReady = true
        inputs.currentLocationLabel = "Portland, Maine"
        inputs.readerBeliefScore = 62
        inputs.firstRunEngagedKeys = Set(FirstRunPageSequence.stepEngagementKeys)

        let lines = [
            "The kettle clicked off before the frost left the window.",
            "Frost on the window again, and the kettle going in the dark.",
            "Down at the harbour a lantern kept swinging over the jetty.",
            "The harbour, the jetty, and a lantern nobody was tending.",
            "A kestrel over the reservoir, holding still against the wind.",
            "The reservoir again, and the same kestrel, or its brother.",
            "Rain all afternoon; I read by the window and forgot the time.",
            "A long walk to the lighthouse, and the gulls arguing over nothing."
        ]
        var days: [BookDay] = []
        for dayOffset in 0..<dayCount {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            var day = BookDay(
                id: BookDay.id(for: dayStart, calendar: calendar),
                date: calendar.startOfDay(for: dayStart),
                pages: []
            )
            for (slot, hour) in [9, 14, 21].enumerated() {
                let at = calendar.date(bySettingHour: hour, minute: 15, second: 0, of: dayStart)!
                day.pages.append(BookPage(
                    id: "bench-\(dayOffset)-\(slot)",
                    type: [.diary, .mood, .weather, .souvenir][(dayOffset + slot) % 4],
                    createdAt: at,
                    promptText: "What stayed with you?",
                    userInput: lines[(dayOffset * 3 + slot) % lines.count],
                    origin: .userAuthored,
                    context: BookPageContextSnapshot(
                        at: at,
                        calendar: calendar,
                        weatherTags: dayOffset % 3 == 0 ? ["rain"] : ["clear"],
                        locationLabel: dayOffset % 5 == 0 ? "Home" : "Portland"
                    )
                ))
            }
            days.append(day)
        }
        let today = days.removeLast()
        inputs.days = days + [today]
        inputs.resurfacingCandidates = (days + [today]).flatMap(\.pages)
        let now = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: today.date)!
        return Corpus(days: days, today: today, inputs: inputs, now: now)
    }

    private func time(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    func testDeskBuildProfile() throws {
        guard ProcessInfo.processInfo.environment["DESK_BENCH"] != nil else {
            throw XCTSkip("Set DESK_BENCH=1 to run the desk build profile.")
        }
        let corpus = corpus()
        let context = CuratorContext.make(for: corpus.today, recentDays: corpus.days.suffix(14) + [corpus.today])
        let inputs = corpus.inputs
        let now = corpus.now
        let day = corpus.today

        // The launch number: the first build of a session pays for everything
        // cold, because every memo in the app is empty when the Book opens.
        // Measured before anything else touches the archive.
        let coldFullMS = time {
            _ = BookCurator.surfacedPages(
                for: day, context: context, inputs: inputs, now: now,
                limit: BookDeskRound.candidateBenchCapacity
            )
        }

        // Warm whatever is lazily built once, so the numbers below are steady
        // state: what every rebuild after the first one costs.
        _ = BookCurator.candidatePool(for: day, context: context, inputs: inputs, now: now)

        let rounds = 3
        var poolMS = 0.0
        var fullMS = 0.0
        var poolCount = 0
        for _ in 0..<rounds {
            poolMS += time { poolCount = BookCurator.candidatePool(for: day, context: context, inputs: inputs, now: now).count }
            fullMS += time {
                _ = BookCurator.surfacedPages(
                    for: day, context: context, inputs: inputs, now: now,
                    limit: BookDeskRound.candidateBenchCapacity
                )
            }
        }

        // Ranking on its own, so the tail of `surfacedPages` — the injections,
        // the editorial debt, the loop floors — is a number rather than a
        // guess.
        let pool = BookCurator.candidatePool(for: day, context: context, inputs: inputs, now: now)
        let resolved = inputs.resolvingWorldEvents(for: day, now: now)
        let mood = CuratorMood.make(inputs: resolved, distressActive: context.distress.isActive, now: now)
        let facets = ReaderAlivenessCurationContext.facets(inputs: resolved, now: now)
        let intention = BookSessionDirector.intention(
            for: day,
            inputs: resolved,
            candidates: pool,
            preferences: .none,
            distressActive: context.distress.isActive,
            now: now
        )
        var rankingMS = 0.0
        for _ in 0..<rounds {
            rankingMS += time {
                _ = BookCurator.rankedPages(
                    from: pool,
                    limit: BookDeskRound.candidateBenchCapacity,
                    preferences: .none,
                    mood: mood,
                    now: now,
                    intention: intention,
                    selectionSeed: intention.seed,
                    readerAliveness: resolved.readerAliveness,
                    alivenessFacets: facets
                )
            }
        }

        // The preamble the composition tail is measured against: the mood, the
        // relationship snapshot and the session intention are all read once per
        // build before a single Page is ranked.
        var moodMS = 0.0
        var relationshipMS = 0.0
        var intentionMS = 0.0
        for _ in 0..<rounds {
            moodMS += time { _ = CuratorMood.make(inputs: resolved, distressActive: context.distress.isActive, now: now) }
            relationshipMS += time { _ = BookRelationshipLedger.snapshot(inputs: resolved, now: now) }
            intentionMS += time {
                _ = BookSessionDirector.intention(
                    for: day,
                    inputs: resolved,
                    candidates: pool,
                    preferences: .none,
                    distressActive: context.distress.isActive,
                    now: now
                )
            }
        }

        var perAdapter: [(String, Double, Int)] = []
        for adapter in BookPageSourceAdapters.active {
            var produced = 0
            var ms = 0.0
            for _ in 0..<rounds {
                ms += time { produced = adapter.candidates(for: day, context: context, inputs: inputs, now: now).count }
            }
            perAdapter.append((String(describing: type(of: adapter)), ms / Double(rounds), produced))
        }
        var interiorMS = 0.0
        for _ in 0..<rounds {
            interiorMS += time { _ = BookInteriorSurfaces.candidates(for: day, inputs: inputs, now: now) }
        }

        // What one Keep costs on the main actor before any desk is rebuilt.
        // These all run inside `savePage`/`persist`/`rebuildSurfaceCache` while
        // the keep is supposed to be animating.
        var rutMS = 0.0
        var reflectableMS = 0.0
        var fingerprintMS = 0.0
        var folioMS = 0.0
        var interiorReconcileMS = 0.0
        let keptPage = day.pages.first!
        for _ in 0..<rounds {
            rutMS += time {
                _ = NothingTide.rutAssessment(inputs: resolved, distressActive: false, now: now)
            }
            reflectableMS += time { _ = FirstReading.reflectablePages(in: inputs.days).count }
            fingerprintMS += time { _ = AttentionFingerprint.make(from: keptPage) }
            folioMS += time { _ = SensoryFolioProjector.structuredFolio(from: keptPage) }
            interiorReconcileMS += time {
                _ = BookInteriorEngine.reconciled(inputs.bookInterior, inputs: resolved, now: now)
            }
        }

        print("\n================ DESK BUILD PROFILE ================")
        print("---- one keep, on the main actor ----")
        print(String(format: "rutAssessment      %8.2f ms", rutMS / Double(rounds)))
        print(String(format: "reflectablePages   %8.2f ms", reflectableMS / Double(rounds)))
        print(String(format: "attentionPrint     %8.2f ms", fingerprintMS / Double(rounds)))
        print(String(format: "sensoryFolio       %8.2f ms", folioMS / Double(rounds)))
        print(String(format: "interiorReconcile  %8.2f ms", interiorReconcileMS / Double(rounds)))
        print(String(format: "COLD (launch) %8.2f ms  the first build of a session", coldFullMS))
        print(String(format: "candidatePool  %8.2f ms  (%d candidates)", poolMS / Double(rounds), poolCount))
        print(String(format: "surfacedPages  %8.2f ms  (pool + ranking + composition tail)", fullMS / Double(rounds)))
        print(String(format: "  rankedPages  %8.2f ms", rankingMS / Double(rounds)))
        print(String(format: "  tail         %8.2f ms  (preamble, injections, debts, floors)", (fullMS - poolMS - rankingMS) / Double(rounds)))
        print(String(format: "    mood       %8.2f ms", moodMS / Double(rounds)))
        print(String(format: "    relation   %8.2f ms", relationshipMS / Double(rounds)))
        print(String(format: "    intention  %8.2f ms", intentionMS / Double(rounds)))
        print(String(format: "  adapters sum %8.2f ms", perAdapter.reduce(0) { $0 + $1.1 }))
        print(String(format: "  interior     %8.2f ms", interiorMS / Double(rounds)))
        print("---- slowest adapters ----")
        for (name, ms, produced) in perAdapter.sorted(by: { $0.1 > $1.1 }).prefix(25) {
            print(String(format: "%8.2f ms  %-52@ %d pages", ms, name as NSString, produced))
        }
        print("====================================================\n")
    }
}
