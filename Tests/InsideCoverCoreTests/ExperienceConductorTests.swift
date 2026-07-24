import XCTest
@testable import InsideCoverCore

final class ExperienceConductorTests: XCTestCase {
    func testProgramUsesTheExistingSessionIntentionAndDeskRoles() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intention = makeIntention(now: now)
        let door = intention.applying(to: makePage(id: "door", tags: "rain,threshold"), role: .door)
        let echo = intention.applying(to: makePage(id: "echo", type: .narrativeOS, tags: "memory,echo"), role: .echo)
        let horizon = intention.applying(to: makePage(id: "horizon", type: .wonderCompass, tags: "wander,light"), role: .horizon)

        let program = BookExperienceProgram.composing(
            pages: [door, echo, horizon],
            intention: intention,
            previous: nil,
            now: now
        )

        XCTAssertEqual(program.intentionID, intention.id)
        XCTAssertEqual(program.movement, intention.movement)
        XCTAssertEqual(program.pageCues.map(\.role), [.door, .echo, .horizon])
        XCTAssertEqual(program.focusSurfaceID, door.id)
        XCTAssertFalse(program.radioAffinityTerms.contains("private"))
    }

    func testLongGameDirectorPageJoinsTheExistingSessionScore() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let campaign = BookReenchantmentCampaign(
            id: "campaign-one",
            hypothesisID: "hypothesis-one",
            capacity: .spontaneousAttention,
            tactic: .prolongAttention,
            pressure: .notice,
            permission: .gentle,
            beat: .seed,
            status: .active,
            presentation: .looseMargin,
            intendedRealWorldEffect: "Notice one ordinary thing for longer.",
            readerNamedEdge: nil,
            edgeEvidencePageIDs: [],
            startingEvidenceIDs: [],
            outcomeEvidenceIDs: [],
            outcomeEvidencePageIDs: [],
            startedAt: now,
            lastChangedAt: now,
            nextEligibleAt: now,
            rejectionCount: 0
        )
        let campaignPage = try XCTUnwrap(BookReenchantmentDirector.surface(
            for: campaign,
            day: BookDay.day(containing: now),
            inputs: .empty
        ))
        let intention = makeIntention(now: now)
        let castPage = intention.applying(to: campaignPage, role: .horizon)

        let program = BookExperienceProgram.composing(
            pages: [castPage],
            intention: intention,
            previous: nil,
            now: now
        )

        XCTAssertEqual(program.intentionID, intention.id)
        XCTAssertEqual(program.focusCue?.sourceID, "book-reenchantment-director")
        XCTAssertEqual(program.focusCue?.role, .horizon)
        XCTAssertTrue(program.radioAffinityTerms.contains("campaign"))
        XCTAssertTrue(program.radioAffinityTerms.contains("attention"))
    }

    func testReaderAttentionAdvancesTheScoreAndDeskRebuildCannotDemoteIt() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intention = makeIntention(now: now)
        let door = intention.applying(to: makePage(id: "door", tags: "rain,memory"), role: .door)
        var program = BookExperienceProgram.composing(
            pages: [door],
            intention: intention,
            previous: nil,
            now: now
        )

        XCTAssertEqual(program.nextBroadcastFunction, .establish)
        program.record(page: door, stage: .opened, at: now.addingTimeInterval(30))
        XCTAssertEqual(program.focusCue?.stage, .opened)
        XCTAssertEqual(program.nextBroadcastFunction, .resonate)

        let rebuilt = BookExperienceProgram.composing(
            pages: [door],
            intention: intention,
            previous: program,
            now: now.addingTimeInterval(60)
        )
        XCTAssertEqual(rebuilt.focusCue?.stage, .opened)
        XCTAssertEqual(rebuilt.nextBroadcastFunction, .resonate)
    }

    func testEveryFourthBroadcastBelongsToTheStationRatherThanTheReader() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var program = makeOpenedProgram(now: now)
        for index in 0..<3 {
            XCTAssertFalse(program.nextBroadcastIsAutonomous)
            program.recordBroadcast(
                stationID: "test",
                kind: .track,
                itemID: "track-\(index)",
                candidateIDs: ["track-\(index)", "other"],
                at: now.addingTimeInterval(Double(index))
            )
        }

        XCTAssertTrue(program.nextBroadcastIsAutonomous)
        XCTAssertEqual(program.nextBroadcastFunction, .stationNative)
        XCTAssertTrue(program.radioAffinityTerms.isEmpty)

        program.recordBroadcast(
            stationID: "test",
            kind: .banter,
            itemID: "world-news",
            candidateIDs: ["world-news"],
            at: now.addingTimeInterval(4)
        )
        XCTAssertTrue(program.broadcastReceipts.last?.autonomous == true)
        XCTAssertEqual(program.broadcastReceipts.last?.function, .stationNative)
        for index in 4..<32 {
            XCTAssertEqual(program.nextBroadcastIsAutonomous, (index + 1).isMultiple(of: 4))
            program.recordBroadcast(
                stationID: "test",
                kind: .track,
                itemID: "long-run-\(index)",
                candidateIDs: ["long-run-\(index)"],
                at: now.addingTimeInterval(Double(index))
            )
        }
        XCTAssertEqual(program.broadcastItemCount, 32)
        XCTAssertEqual(program.broadcastReceipts.count, BookExperienceProgram.maximumBroadcastReceipts)
    }

    func testTracksResonateWithAnOpenedPageWithoutBecomingDeterministic() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let program = makeOpenedProgram(now: now)
        let station = makeStation(
            tracks: [
                RadioTrack(
                    id: "resonant",
                    title: "Rain Memory",
                    artist: "The Echoes",
                    moodTags: ["rain", "memory", "echo"],
                    meaning: RadioTrackMeaning(
                        themeTags: ["return", "living continuity"],
                        imageTags: ["rain"],
                        ordinaryLifeCue: "Notice what returns."
                    )
                ),
                RadioTrack(
                    id: "ordinary",
                    title: "Traffic Ledger",
                    artist: "The Clerks",
                    moodTags: ["metal", "traffic"]
                )
            ]
        )
        let context = RadioWorldContext(experienceProgram: program)
        var selected: [String: Int] = [:]
        for index in 0..<80 {
            let chosen = RadioStationRegistry.curatedTrack(
                station: station,
                previousTrackID: nil,
                playTurn: index,
                context: context,
                sessionSeed: "session-\(index % 7)",
                now: now.addingTimeInterval(Double(index * 1_801))
            )
            selected[chosen?.id ?? "none", default: 0] += 1
        }

        XCTAssertGreaterThan(selected["resonant", default: 0], selected["ordinary", default: 0])
        XCTAssertGreaterThan(selected["ordinary", default: 0], 0)
    }

    func testDismissalAsksRadioToReleaseRatherThanChaseTheSameMotif() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intention = makeIntention(now: now)
        let page = intention.applying(to: makePage(id: "door", tags: "rain,memory,echo"), role: .door)
        var program = BookExperienceProgram.composing(
            pages: [page],
            intention: intention,
            previous: nil,
            now: now
        )
        program.record(page: page, stage: .dismissed, at: now.addingTimeInterval(10))
        XCTAssertEqual(program.nextBroadcastFunction, .release)

        let station = makeStation(
            tracks: [
                RadioTrack(
                    id: "same-motif",
                    title: "More Rain",
                    artist: "Echo",
                    moodTags: ["rain", "memory", "echo"]
                ),
                RadioTrack(
                    id: "release",
                    title: "Open Air",
                    artist: "Quiet",
                    moodTags: ["quiet", "air", "rest", "instrumental"]
                )
            ]
        )
        let context = RadioWorldContext(experienceProgram: program)
        var releaseCount = 0
        for index in 0..<60 {
            let chosen = RadioStationRegistry.curatedTrack(
                station: station,
                previousTrackID: nil,
                playTurn: index,
                context: context,
                sessionSeed: "release-\(index % 5)",
                now: now.addingTimeInterval(Double(index * 1_801))
            )
            if chosen?.id == "release" { releaseCount += 1 }
        }
        XCTAssertGreaterThan(releaseCount, 35)
    }

    func testBanterCanAnswerThePageWhileTheCatalogStillVaries() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let program = makeOpenedProgram(now: now)
        let banters = [
            RadioBanter(
                id: "echo",
                category: .transition,
                assetName: nil,
                caption: "Some rain returns as an echo.",
                conditions: nil,
                weight: 1
            ),
            RadioBanter(
                id: "ledger",
                category: .transition,
                assetName: nil,
                caption: "The station tax ledger remains correctly alphabetized.",
                conditions: nil,
                weight: 1
            )
        ]
        let station = makeStation(tracks: [], banters: banters)
        let state = RadioPlaybackState(activeStationID: station.id, startedAt: now)
        let context = RadioWorldContext(experienceProgram: program)
        var counts: [String: Int] = [:]
        for index in 0..<60 {
            let selected = RadioStationRegistry.nextBanter(
                station: station,
                state: state,
                context: context,
                now: now.addingTimeInterval(Double(index * 901))
            )
            counts[selected?.id ?? "none", default: 0] += 1
        }
        XCTAssertGreaterThan(counts["echo", default: 0], counts["ledger", default: 0])
        XCTAssertGreaterThan(counts["ledger", default: 0], 0)
    }

    func testImpossibleTrackGateFallsBackOnlyToOrdinaryStationMusic() {
        let station = makeStation(
            tracks: [
                RadioTrack(
                    id: "future",
                    title: "Future Festival",
                    artist: "Tomorrow",
                    moodTags: [],
                    conditions: RadioBanter.Conditions(festivalOnly: true)
                ),
                RadioTrack(
                    id: "ordinary",
                    title: "Ordinary Air",
                    artist: "Today",
                    moodTags: []
                )
            ]
        )

        let selected = RadioStationRegistry.curatedTrack(
            station: station,
            previousTrackID: nil,
            playTurn: 0,
            context: RadioWorldContext(festivalActive: false),
            sessionSeed: "gate",
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        XCTAssertEqual(selected?.id, "ordinary")
    }

    func testOlderVaultsDecodeWithNoInventedExperienceProgram() throws {
        let encoded = try JSONEncoder().encode(PlayerVaultData())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "activeExperienceProgram")
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PlayerVaultData.self, from: legacy)
        XCTAssertNil(decoded.activeExperienceProgram)
    }

    private func makeOpenedProgram(now: Date) -> BookExperienceProgram {
        let intention = makeIntention(now: now)
        let page = intention.applying(
            to: makePage(id: "door", tags: "rain,memory,echo,return"),
            role: .door
        )
        var program = BookExperienceProgram.composing(
            pages: [page],
            intention: intention,
            previous: nil,
            now: now
        )
        program.record(page: page, stage: .opened, at: now.addingTimeInterval(10))
        return program
    }

    private func makeIntention(now: Date) -> BookSessionIntention {
        BookSessionIntention(
            id: "session-one",
            dayID: "2027-01-15",
            movement: .livingContinuity,
            ambition: .connection,
            evidencePageIDs: ["earlier-page"],
            evidenceReason: "An earlier ordinary detail can return.",
            createdAt: now,
            expiresAt: now.addingTimeInterval(6 * 3600),
            seed: "session-seed"
        )
    }

    private func makePage(
        id: String,
        type: BookPageType = .weather,
        tags: String
    ) -> SurfacePage {
        SurfacePage(
            id: id,
            type: type,
            sourceID: "source-\(id)",
            intent: .capture,
            renderStyle: .promptCard,
            score: 50,
            reason: "test",
            prompt: "Reader-visible copy that must not enter the program.",
            detail: "Private detail.",
            payload: BookPagePayload(
                headline: "Test",
                body: "Private body.",
                metadata: ["tags": tags]
            )
        )
    }

    private func makeStation(
        tracks: [RadioTrack],
        banters: [RadioBanter]? = nil
    ) -> RadioStation {
        RadioStation(
            id: "experience-test",
            title: "Experience Test",
            frequency: 99.9,
            subtitle: "test",
            hostEntityID: nil,
            packID: nil,
            unlockRule: "test",
            moodTags: [],
            signalLine: "test",
            tracks: tracks,
            interludeTitles: [],
            effects: [],
            banters: banters
        )
    }
}
