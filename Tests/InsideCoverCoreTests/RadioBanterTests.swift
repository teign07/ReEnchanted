import XCTest
@testable import InsideCoverCore

final class RadioBanterTests: XCTestCase {
    func testThornwaveCatalogIncludesMossyNight() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let track = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-mossy-night" })

        XCTAssertEqual(track.title, "Mossy Night")
        XCTAssertEqual(track.assetName, "RadioThornwaveMossyNight")
        XCTAssertEqual(track.durationSeconds, 193)
    }

    func testAliveSelectionVariesAndAvoidsImmediateRepeats() {
        var state = RadioPlaybackState(activeStationID: "thornwave", startedAt: Date())
        let night = RadioWorldContext(timeOfDay: "night", grey: 60, listeningDays: 3)
        var t = Date()
        var ids: [String] = []
        for _ in 0..<6 {
            guard let b = RadioStationRegistry.nextBanter(state: state, context: night, now: t) else { continue }
            state.recordBanter(b.id)
            ids.append(b.id)
            t = t.addingTimeInterval(950)
        }
        XCTAssertGreaterThan(Set(ids).count, 1, "should vary, not repeat one clip")
        for i in 1..<ids.count { XCTAssertNotEqual(ids[i], ids[i-1], "no back-to-back repeat") }
    }

    func testAliveTrackCurationExcludesRecentSongsInsteadOfWalkingCatalogOrder() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi"))
        let recent = Array(station.tracks.prefix(2).map(\.id))
        let chosen = try XCTUnwrap(RadioStationRegistry.curatedTrack(
            station: station,
            previousTrackID: recent.last,
            recentTrackIDs: recent,
            playTurn: 4,
            context: RadioWorldContext(timeOfDay: "day"),
            sessionSeed: "alive-curation-test",
            now: Date(timeIntervalSince1970: 1_750_000_000)
        ))

        XCTAssertFalse(recent.contains(chosen.id))
    }

    func testAliveBanterCurationCoolsTheMostRecentCategory() throws {
        var state = RadioPlaybackState(
            activeStationID: "thornwave",
            startedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        state.recordBanter("thornwave-sponsor-bramblewine")
        state.recordBanter("thornwave-sponsor-goblin-market")

        let chosen = try XCTUnwrap(RadioStationRegistry.nextBanter(
            state: state,
            context: RadioWorldContext(timeOfDay: "night", grey: 60),
            now: Date(timeIntervalSince1970: 1_750_000_950)
        ))

        XCTAssertNotEqual(chosen.category, .sponsor)
    }

    func testAliveBanterCadenceIsVariableButNeverLeavesThreeSongsSilent() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let state = RadioPlaybackState(activeStationID: "thornwave", startedAt: start)
        let context = RadioWorldContext(timeOfDay: "night", grey: 60)
        let firstSongDecisions = (0..<24).map { offset in
            RadioStationRegistry.shouldBanter(
                songsSinceLastBanter: 1,
                state: state,
                context: context,
                justFinishedTrackID: nil,
                upcomingTrackID: nil,
                now: start.addingTimeInterval(Double(offset * 300))
            )
        }

        XCTAssertTrue(firstSongDecisions.contains(true))
        XCTAssertTrue(firstSongDecisions.contains(false))
        XCTAssertTrue(RadioStationRegistry.shouldBanter(
            songsSinceLastBanter: 2,
            state: state,
            context: context,
            justFinishedTrackID: nil,
            upcomingTrackID: nil,
            now: start
        ))
    }

    func testConditionsGateByWorldState() {
        var state = RadioPlaybackState(activeStationID: "thornwave", startedAt: Date())
        let bright = RadioWorldContext(timeOfDay: "day", grey: 10, listeningDays: 0)
        var t = Date()
        var seen = Set<String>()
        for _ in 0..<30 {
            if let b = RadioStationRegistry.nextBanter(state: state, context: bright, now: t) {
                seen.insert(b.id); state.recordBanter(b.id)
            }
            t = t.addingTimeInterval(950)
        }
        XCTAssertFalse(seen.contains("thornwave-id-01"), "night-only callsign must not play in day")
        XCTAssertFalse(seen.contains("thornwave-gossip-pact"), "minGrey 40 gossip must not play at grey 10")
    }

    func testLegacyInterludesStillProduceBanter() {
        let state = RadioPlaybackState(activeStationID: "fae-fi", startedAt: Date())
        let ctx = RadioWorldContext(timeOfDay: "day")
        XCTAssertNotNil(RadioStationRegistry.nextBanter(state: state, context: ctx),
                        "stations without authored banters fall back to interludeTitles")
    }

    func testBoundTransitionsRespectPlacement() {
        let intro = RadioBanter(id: "i", category: .transition, assetName: nil,
                                caption: "before", conditions: nil, weight: nil,
                                trackID: "song-b", placement: .intro)
        let outro = RadioBanter(id: "o", category: .transition, assetName: nil,
                                caption: "after", conditions: nil, weight: nil,
                                trackID: "song-a", placement: .outro)
        XCTAssertTrue(outro.placementFits(justFinishedTrackID: "song-a", upcomingTrackID: "song-b"))
        XCTAssertFalse(outro.placementFits(justFinishedTrackID: "song-x", upcomingTrackID: "song-b"))
        XCTAssertTrue(intro.placementFits(justFinishedTrackID: "song-a", upcomingTrackID: "song-b"))
        XCTAssertFalse(intro.placementFits(justFinishedTrackID: "song-a", upcomingTrackID: "song-x"))

        // Through the selector: the Mossy-Footsteps outro is reachable only when
        // that song just finished; the Folktronica intro must not appear when a
        // different song is queued next.
        let state = RadioPlaybackState(activeStationID: "fae-fi", startedAt: Date())
        let ctx = RadioWorldContext(timeOfDay: "day")
        var sawOutro = false, sawWrongIntro = false
        var t = Date()
        for _ in 0..<60 {
            if let b = RadioStationRegistry.nextBanter(
                state: state, context: ctx,
                justFinishedTrackID: "fae-fi-mossy-footsteps",
                upcomingTrackID: "fae-fi-mossy-groove", now: t) {
                if b.id == "faefi-outro-mossyfootsteps" { sawOutro = true }
                if b.id == "faefi-intro-folktronica" { sawWrongIntro = true }
            }
            t = t.addingTimeInterval(950)
        }
        XCTAssertTrue(sawOutro, "outro should be reachable after its bound song")
        XCTAssertFalse(sawWrongIntro, "intro must not play unless its song is next")
    }

    func testThornwaveTrackIDsBindToTheCorrectSide() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let transitions = Dictionary(uniqueKeysWithValues: station.resolvedBanters
            .filter { $0.category == .transition }
            .map { ($0.id, $0) })

        let brambleOutro = try XCTUnwrap(transitions["thornwave-outro-bramble-bass"])
        XCTAssertEqual(brambleOutro.trackID, "thornwave-bramble-bass")
        XCTAssertEqual(brambleOutro.placement, .outro)

        let loungeOutro = try XCTUnwrap(transitions["thornwave-outro-nocturnal-faerie-lounge"])
        XCTAssertEqual(loungeOutro.trackID, "thornwave-nocturnal-faerie-lounge")
        XCTAssertEqual(loungeOutro.placement, .outro)

        let brambleIntro = try XCTUnwrap(transitions["thornwave-intro-bramble-bass"])
        XCTAssertEqual(brambleIntro.trackID, "thornwave-bramble-bass")
        XCTAssertEqual(brambleIntro.placement, .intro)

        let sponsors = Dictionary(uniqueKeysWithValues: station.resolvedBanters
            .filter { $0.category == .sponsor }
            .map { ($0.id, $0) })
        XCTAssertEqual(sponsors["thornwave-sponsor-bramblewine"]?.assetName,
                       "DJ_thornwave_sponsor_01")
        XCTAssertEqual(sponsors["thornwave-sponsor-goblin-market"]?.assetName,
                       "DJ_thornwave_sponsor_02")

        let gossip = Dictionary(uniqueKeysWithValues: station.resolvedBanters
            .filter { $0.category == .gossip }
            .map { ($0.id, $0) })
        XCTAssertEqual(gossip["thornwave-gossip-pact"]?.assetName,
                       "DJ_thornwave_gossip_01")
        XCTAssertEqual(gossip["thornwave-gossip-unwritten"]?.assetName,
                       "DJ_thornwave_gossip_02")

        let news = Dictionary(uniqueKeysWithValues: station.resolvedBanters
            .filter { $0.category == .news }
            .map { ($0.id, $0) })
        let greyNews = try XCTUnwrap(news["thornwave-news-nothing"])
        XCTAssertEqual(greyNews.assetName, "DJ_thornwave_news_01")
        XCTAssertEqual(greyNews.conditions?.timeOfDay, ["dusk", "night"])
        XCTAssertEqual(greyNews.conditions?.minGrey, 35)

        let pactNews = try XCTUnwrap(news["thornwave-news-pact-dispatch"])
        XCTAssertEqual(pactNews.assetName, "DJ_thornwave_news_02")
        XCTAssertEqual(pactNews.conditions?.timeOfDay, ["dusk", "night"])
    }
}
