import XCTest
@testable import InsideCoverCore

final class AuthoredContentTests: XCTestCase {
    func testUntilResolvedSurvivesOpeningButKeepTrashAndCompletionRetireOnlyThisRun() throws {
        let now = date(2026, 10, 12)
        let scope = AuthoredContentScope(scopeID: "october", runID: "2026", phaseID: "setup")
        let policy = AuthoredContentOccurrencePolicy(kind: .untilResolved)
        XCTAssertEqual(try JSONDecoder().decode(AuthoredContentOccurrencePolicy.self,
            from: JSONEncoder().encode(policy)), policy)
        for state in AuthoredContentReceiptState.allCases {
            let ledger = AuthoredContentReceiptLedger.empty.recording(AuthoredContentReceipt(
                contentID: "scene", occurrenceID: "scene:2026", channel: .storyScene,
                scope: scope, state: state, recordedAt: now
            ))
            let isTerminal = [AuthoredContentReceiptState.kept, .dismissed, .completed].contains(state)
            XCTAssertEqual(policy.allows(contentID: "scene", scope: scope, ledger: ledger, now: now), !isTerminal)
            XCTAssertTrue(policy.allows(contentID: "scene",
                scope: AuthoredContentScope(scopeID: "october", runID: "2027", phaseID: "setup"),
                ledger: ledger, now: now))
        }
    }

    func testTrashRetiresUntilOpenedAndUntilActedWithoutInventingParticipation() {
        let now = date(2026, 10, 12)
        let scope = AuthoredContentScope(scopeID: "october", runID: "2026", phaseID: "setup")
        let ledger = AuthoredContentReceiptLedger.empty.recording(AuthoredContentReceipt(
            contentID: "mission", occurrenceID: "mission:2026", channel: .page,
            scope: scope, state: .dismissed, recordedAt: now
        ))
        for kind in [AuthoredContentOccurrenceKind.untilOpened, .untilActed] {
            XCTAssertFalse(AuthoredContentOccurrencePolicy(kind: kind)
                .allows(contentID: "mission", scope: scope, ledger: ledger, now: now))
        }
        XCTAssertFalse(AuthoredContentDependency(contentID: "mission", requiredState: .acted)
            .isSatisfied(in: ledger, currentScope: scope, now: now))
    }

    func testGateComposesAllAnyAndNoneWithoutInventingMissingSignals() {
        let now = date(2026, 10, 12, hour: 22)
        let context = AuthoredContentGateContext(
            now: now,
            timeBand: "night",
            month: 10,
            weekday: 2,
            weekOfYear: 42,
            moonPhase: "Full Moon",
            weatherTags: ["rain"],
            raritySeed: "2026-10-12"
        )
        let gate = AuthoredContentGate(
            allOf: [.timeBands(["night"]), .months([10])],
            anyOf: [.moonPhases(["new moon"]), .weatherTagsAny(["rain"])],
            noneOf: [.weekdays([1])]
        )

        XCTAssertTrue(gate.allows(in: context, contentID: "count-rain-window"))
        XCTAssertFalse(
            AuthoredContentGate(allOf: [.standingBand(field: .sleepHours, bands: [.above])])
                .allows(in: context, contentID: "sleep-gated-bonus")
        )
    }

    func testWorldEventPredicateRequiresIDAndPhaseOnTheSameEvent() {
        let context = AuthoredContentGateContext(
            now: date(2026, 10, 12),
            worldEvents: [
                eventContext(id: "count-unbound", phase: "school-hours", role: .setup),
                eventContext(id: "dictionary-rebellion", phase: "assembly", role: .climax)
            ]
        )
        let crossed = AuthoredContentWorldEventQuery(
            eventIDs: ["count-unbound"],
            phaseIDs: ["assembly"]
        )
        let correct = AuthoredContentWorldEventQuery(
            eventIDs: ["count-unbound"],
            phaseIDs: ["school-hours"],
            phaseRoles: [.setup]
        )

        XCTAssertFalse(AuthoredContentGate(allOf: [.worldEvent(crossed)]).allows(in: context, contentID: "wrong"))
        XCTAssertTrue(AuthoredContentGate(allOf: [.worldEvent(correct)]).allows(in: context, contentID: "right"))
    }

    func testReceiptRecordingIsIdempotentAndDependenciesDistinguishRuns() {
        let now = date(2026, 10, 12)
        let scope = AuthoredContentScope(
            scopeID: "count-unbound",
            runID: "count-unbound:2026",
            phaseID: "uninvited"
        )
        let delivered = AuthoredContentReceipt(
            contentID: "east-stacks",
            occurrenceID: "page:east-stacks:2026",
            channel: .storyScene,
            scope: scope,
            state: .delivered,
            recordedAt: now
        )
        let ledger = AuthoredContentReceiptLedger.empty
            .recording(delivered)
            .recording(delivered)

        XCTAssertEqual(ledger.receipts, [delivered])
        XCTAssertTrue(
            AuthoredContentDependency(contentID: "east-stacks")
                .isSatisfied(in: ledger, currentScope: scope, now: now)
        )
        XCTAssertFalse(
            AuthoredContentDependency(contentID: "east-stacks")
                .isSatisfied(
                    in: ledger,
                    currentScope: AuthoredContentScope(
                        scopeID: "count-unbound",
                        runID: "count-unbound:2027",
                        phaseID: "uninvited"
                    ),
                    now: now
                )
        )
    }

    func testOccurrencePoliciesUseStableOccurrenceReceipts() {
        let deliveredAt = date(2026, 10, 12, hour: 8)
        let scope = AuthoredContentScope(
            scopeID: "count-unbound",
            runID: "count-unbound:2026",
            phaseID: "uninvited"
        )
        let ledger = AuthoredContentReceiptLedger.empty.recording(
            AuthoredContentReceipt(
                contentID: "radio-east-stacks",
                occurrenceID: "radio-play:1",
                channel: .radioBanter,
                scope: scope,
                state: .played,
                recordedAt: deliveredAt
            )
        )

        XCTAssertFalse(
            AuthoredContentOccurrencePolicy(kind: .oncePerRun)
                .allows(contentID: "radio-east-stacks", scope: scope, ledger: ledger, now: deliveredAt)
        )
        XCTAssertTrue(
            AuthoredContentOccurrencePolicy(kind: .repeatable, cooldownHours: 12, maxPerRun: 2)
                .allows(
                    contentID: "radio-east-stacks",
                    scope: scope,
                    ledger: ledger,
                    now: deliveredAt.addingTimeInterval(13 * 3_600)
                )
        )
        XCTAssertFalse(
            AuthoredContentOccurrencePolicy(kind: .repeatable, cooldownHours: 12, maxPerRun: 2)
                .allows(
                    contentID: "radio-east-stacks",
                    scope: scope,
                    ledger: ledger,
                    now: deliveredAt.addingTimeInterval(2 * 3_600)
                )
        )
    }

    func testExistingPageAndRadioConditionsCanEnterTheSharedGateWithoutSemanticDrift() throws {
        let now = date(2026, 10, 12, hour: 22)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = BookDay.day(containing: now, calendar: calendar)
        let pageContext = PageTriggerContext(
            day: day,
            inputs: .empty,
            now: now,
            calendar: calendar
        )
        let pageTrigger = PageTrigger(timeBands: ["night"], months: [10])
        let pageGate = AuthoredContentGate(pageTrigger: pageTrigger)

        XCTAssertEqual(
            pageGate.allows(in: .page(pageContext), contentID: "legacy-page"),
            pageTrigger.allows(context: pageContext, archetypeID: "legacy-page")
        )

        let radioContext = RadioWorldContext(
            timeOfDay: "night",
            weekday: 2,
            month: 10,
            weekOfYear: 42,
            now: now
        )
        let conditions = RadioBanter.Conditions(
            timeOfDay: ["night"],
            months: [10]
        )
        let radioGate = AuthoredContentGate(radioConditions: conditions)

        XCTAssertEqual(
            radioGate.allows(in: .radio(radioContext), contentID: "legacy-banter"),
            radioContext.satisfies(conditions)
        )

        let roundTrip = try JSONDecoder().decode(
            AuthoredContentGate.self,
            from: JSONEncoder().encode(
                AuthoredContentGate(
                    allOf: [
                        .dateWindow(startsAt: now, endsAt: now.addingTimeInterval(3_600)),
                        .worldEvent(AuthoredContentWorldEventQuery(eventIDs: ["count-unbound"]))
                    ]
                )
            )
        )
        XCTAssertEqual(roundTrip.allOf.count, 2)
    }

    private func eventContext(
        id: String,
        phase: String,
        role: WorldEventPhaseRole
    ) -> AuthoredContentWorldEventContext {
        AuthoredContentWorldEventContext(
            eventID: id,
            packID: id,
            runID: "\(id):2026",
            phaseID: phase,
            phaseTitle: phase,
            phaseRole: role,
            lifecycleStage: .live,
            activationMode: .liveCalendar,
            liveDay: 11,
            touchCount: 0
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
