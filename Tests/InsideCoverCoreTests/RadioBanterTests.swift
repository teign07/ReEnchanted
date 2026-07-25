import XCTest
@testable import InsideCoverCore

final class RadioBanterTests: XCTestCase {
    func testCoreStationsResolveTheirDJNames() throws {
        XCTAssertEqual(try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi")).hostDisplayName, "Penny Blackletter")
        XCTAssertEqual(try XCTUnwrap(RadioStationRegistry.station(id: "mothlight-beats")).hostDisplayName, "Professor Eleanor Euphony")
        XCTAssertEqual(try XCTUnwrap(RadioStationRegistry.station(id: "thornwave")).hostDisplayName, "Wicker Eddies")
    }

    func testFaeFiCatalogIncludesInkHands() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi"))
        let inkHands = try XCTUnwrap(station.tracks.first { $0.id == "fae-fi-ink-hands" })

        XCTAssertEqual(inkHands.title, "Ink Hands")
        XCTAssertEqual(inkHands.assetName, "RadioFaeFiInkHands")
        XCTAssertEqual(inkHands.durationSeconds, 117)

        let artOfTheGlint = try XCTUnwrap(station.tracks.first { $0.id == "fae-fi-art-of-the-glint" })
        XCTAssertEqual(artOfTheGlint.title, "Art of the Glint")
        XCTAssertEqual(artOfTheGlint.assetName, "RadioFaeFiArtOfTheGlint")
        XCTAssertEqual(artOfTheGlint.durationSeconds, 96)

        let crushedPixies = try XCTUnwrap(station.tracks.first { $0.id == "fae-fi-crushed-pixies" })
        XCTAssertEqual(crushedPixies.title, "Crushed Pixies")
        XCTAssertEqual(crushedPixies.assetName, "RadioFaeFiCrushedPixies")
        XCTAssertEqual(crushedPixies.durationSeconds, 134)

        let faeFi = try XCTUnwrap(station.tracks.first { $0.id == "fae-fi-fae-fi" })
        XCTAssertEqual(faeFi.title, "Fae Fi")
        XCTAssertEqual(faeFi.assetName, "RadioFaeFiFaeFi")
        XCTAssertEqual(faeFi.durationSeconds, 185)

        let lookTwice = try XCTUnwrap(station.tracks.first { $0.id == "fae-fi-look-twice" })
        XCTAssertEqual(lookTwice.title, "Look Twice")
        XCTAssertEqual(lookTwice.assetName, "RadioFaeFiLookTwice")
        XCTAssertEqual(lookTwice.durationSeconds, 249)

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioFaeFiInkHands.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioFaeFiArtOfTheGlint.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioFaeFiCrushedPixies.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioFaeFiFaeFi.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioFaeFiLookTwice.m4a").path))
    }

    func testFaeFiIncludesImportedPennyBanterBatch() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi"))
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)

        for index in 1...22 {
            let suffix = String(format: "%02d", index)
            let banter = try XCTUnwrap(station.banters?.first { $0.id == "faefi-penny-banter-\(suffix)" })

            XCTAssertNil(banter.conditions)
            XCTAssertEqual(banter.assetName, "DJ_faefi_penny_banter_\(suffix)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_penny_banter_\(suffix).m4a").path))
        }
    }

    func testMothlightCatalogIncludesInTheStory() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "mothlight-beats"))
        let track = try XCTUnwrap(station.tracks.first { $0.id == "mothlight-in-the-story" })
        let noticingTextFlowers = try XCTUnwrap(station.tracks.first { $0.id == "mothlight-noticing-text-flowers" })
        let talesEnd = try XCTUnwrap(station.tracks.first { $0.id == "mothlight-tales-end" })
        let bookJumping = try XCTUnwrap(station.tracks.first { $0.id == "mothlight-book-jumping" })
        let porchlightFading = try XCTUnwrap(station.tracks.first { $0.id == "mothlight-porchlight-fading" })

        XCTAssertEqual(track.title, "In the Story")
        XCTAssertEqual(track.assetName, "RadioMothlightInTheStory")
        XCTAssertEqual(track.durationSeconds, 136)
        XCTAssertEqual(noticingTextFlowers.title, "Noticing Text Flowers")
        XCTAssertEqual(noticingTextFlowers.assetName, "RadioMothlightNoticingTextFlowers")
        XCTAssertEqual(noticingTextFlowers.durationSeconds, 132)
        XCTAssertEqual(talesEnd.title, "Tale's End")
        XCTAssertEqual(talesEnd.assetName, "RadioMothlightTalesEnd")
        XCTAssertEqual(talesEnd.durationSeconds, 144)
        XCTAssertEqual(bookJumping.title, "Book Jumping")
        XCTAssertEqual(bookJumping.assetName, "RadioMothlightBookJumping")
        XCTAssertEqual(bookJumping.durationSeconds, 130)
        XCTAssertEqual(porchlightFading.title, "Porchlight, Fading")
        XCTAssertEqual(porchlightFading.assetName, "RadioMothlightPorchlightFading")
        XCTAssertEqual(porchlightFading.durationSeconds, 120)

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioMothlightInTheStory.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioMothlightNoticingTextFlowers.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioMothlightTalesEnd.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioMothlightBookJumping.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioMothlightPorchlightFading.m4a").path))
    }

    func testMothlightIncludesImportedEuphonyBanterBatch() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "mothlight-beats"))
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)

        for index in 1...30 {
            let suffix = String(format: "%02d", index)
            let banter = try XCTUnwrap(station.banters?.first { $0.id == "mothlight-euphony-banter-\(suffix)" })

            XCTAssertNil(banter.conditions)
            XCTAssertEqual(banter.assetName, "DJ_mothlight_euphony_banter_\(suffix)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_euphony_banter_\(suffix).m4a").path))
        }
    }

    func testThornwaveCatalogIncludesNewestTracks() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let mossyNight = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-mossy-night" })

        XCTAssertEqual(mossyNight.title, "Mossy Night")
        XCTAssertEqual(mossyNight.assetName, "RadioThornwaveMossyNight")
        XCTAssertEqual(mossyNight.durationSeconds, 193)

        let longTitles = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-long-titles-in-the-dark" })
        XCTAssertEqual(longTitles.title, "Long Titles in the Dark")
        XCTAssertEqual(longTitles.assetName, "RadioThornwaveLongTitlesInTheDark")
        XCTAssertEqual(longTitles.durationSeconds, 212)

        let duskthorn = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-duskthorn-rising" })
        XCTAssertEqual(duskthorn.title, "Duskthorn Rising")
        XCTAssertEqual(duskthorn.assetName, "RadioThornwaveDuskthornRising")
        XCTAssertEqual(duskthorn.durationSeconds, 240)

        let noConflict = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-no-conflict-no-story" })
        XCTAssertEqual(noConflict.title, "No Conflict, No Story")
        XCTAssertEqual(noConflict.assetName, "RadioThornwaveNoConflictNoStory")
        XCTAssertEqual(noConflict.durationSeconds, 245)

        let magicMargins = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-magic-margins" })
        XCTAssertEqual(magicMargins.title, "Magic Margins")
        XCTAssertEqual(magicMargins.assetName, "RadioThornwaveMagicMargins")
        XCTAssertEqual(magicMargins.durationSeconds, 264)

        let velvetArrears = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-velvet-arrears" })
        XCTAssertEqual(velvetArrears.title, "Velvet Arrears")
        XCTAssertEqual(velvetArrears.assetName, "RadioThornwaveVelvetArrears")
        XCTAssertEqual(velvetArrears.durationSeconds, 233)

        let goblinMarket = try XCTUnwrap(station.tracks.first { $0.id == "thornwave-goblin-market" })
        XCTAssertEqual(goblinMarket.title, "Goblin Market")
        XCTAssertEqual(goblinMarket.assetName, "RadioThornwaveGoblinMarket")
        XCTAssertEqual(goblinMarket.durationSeconds, 158)

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioThornwaveLongTitlesInTheDark.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioThornwaveDuskthornRising.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioThornwaveNoConflictNoStory.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioThornwaveMagicMargins.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioThornwaveVelvetArrears.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioThornwaveGoblinMarket.m4a").path))
    }

    func testThornwaveIncludesImportedWickerBanterBatch() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)

        for index in 1...37 {
            let suffix = String(format: "%02d", index)
            let banter = try XCTUnwrap(station.banters?.first { $0.id == "thornwave-wicker-banter-\(suffix)" })

            XCTAssertNil(banter.conditions)
            XCTAssertEqual(banter.assetName, "DJ_thornwave_wicker_banter_\(suffix)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_wicker_banter_\(suffix).m4a").path))
        }
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

    func testTrackCurationFinishesAFullRunBeforeRepeatingSongs() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "mothlight-beats"))
        let allTrackIDs = Set(station.tracks.map(\.id))
        var state = RadioPlaybackState(
            activeStationID: station.id,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let context = RadioWorldContext(timeOfDay: "dusk")
        let seed = "full-run-curation-test"
        var heardThisRun: [String] = []
        var now = Date(timeIntervalSince1970: 1_750_000_000)

        for turn in 0..<station.tracks.count {
            let track = try XCTUnwrap(RadioStationRegistry.curatedTrack(
                station: station,
                previousTrackID: state.lastTrackID,
                recentTrackIDs: state.recentTrackIDs ?? [],
                playTurn: turn,
                context: context,
                sessionSeed: seed,
                now: now
            ))

            XCTAssertFalse(heardThisRun.contains(track.id), "song repeated before the station run finished")
            heardThisRun.append(track.id)
            state.recordTrack(track.id, stationTrackIDs: station.tracks.map(\.id))
            now = now.addingTimeInterval(240)
        }

        XCTAssertEqual(Set(heardThisRun), allTrackIDs)
        XCTAssertEqual(Set(state.recentTrackIDs ?? []), allTrackIDs)

        let nextRunFirst = try XCTUnwrap(RadioStationRegistry.curatedTrack(
            station: station,
            previousTrackID: state.lastTrackID,
            recentTrackIDs: state.recentTrackIDs ?? [],
            playTurn: station.tracks.count,
            context: context,
            sessionSeed: seed,
            now: now
        ))
        XCTAssertNotEqual(nextRunFirst.id, heardThisRun.last, "new run should still avoid an immediate repeat")

        state.recordTrack(nextRunFirst.id, stationTrackIDs: station.tracks.map(\.id))
        XCTAssertEqual(state.recentTrackIDs, [nextRunFirst.id])

        let nextRunSecond = try XCTUnwrap(RadioStationRegistry.curatedTrack(
            station: station,
            previousTrackID: state.lastTrackID,
            recentTrackIDs: state.recentTrackIDs ?? [],
            playTurn: station.tracks.count + 1,
            context: context,
            sessionSeed: seed,
            now: now.addingTimeInterval(240)
        ))
        XCTAssertNotEqual(nextRunSecond.id, nextRunFirst.id)
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

    func testUngatedBanterRunsDeepIntoCatalogBeforeRepeating() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let freelyEligible = station.resolvedBanters.filter { $0.conditions == nil && !$0.isBound }
        var state = RadioPlaybackState(
            activeStationID: station.id,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let context = RadioWorldContext(timeOfDay: "day", grey: 0)
        let eligible = station.resolvedBanters.filter {
            context.satisfies($0.conditions)
                && $0.placementFits(justFinishedTrackID: nil, upcomingTrackID: nil)
        }
        var heard = Set<String>()
        var now = Date(timeIntervalSince1970: 1_750_000_000)

        for _ in 0..<eligible.count {
            let banter = try XCTUnwrap(RadioStationRegistry.nextBanter(
                state: state,
                context: context,
                now: now
            ))
            XCTAssertTrue(heard.insert(banter.id).inserted, "banter repeated before the ungated bag was exhausted")
            state.recordBanter(banter.id)
            now = now.addingTimeInterval(901)
        }

        XCTAssertTrue(Set(freelyEligible.map(\.id)).isSubset(of: heard))
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
        // Pinned like the rest of this file: the banter slot is
        // Int(now.timeIntervalSince(seedDate) / 900), so a wall-clock seed made
        // which banters were reachable depend on when the suite happened to run.
        let state = RadioPlaybackState(activeStationID: "fae-fi", startedAt: Date(timeIntervalSince1970: 1_750_000_000))
        let ctx = RadioWorldContext(timeOfDay: "day")
        var sawOutro = false, sawWrongIntro = false
        var t = Date(timeIntervalSince1970: 1_750_000_000)
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

    func testEveryCoreSponsorReadPointsToAMarketWare() throws {
        let stations = try ["fae-fi", "mothlight-beats", "thornwave"].map {
            try XCTUnwrap(RadioStationRegistry.station(id: $0))
        }
        let sponsorIDs = Set(stations.flatMap { station in
            station.resolvedBanters
                .filter { $0.category == .sponsor }
                .map(\.id)
        })
        let mappedSponsorIDs = Set(GoblinMarketEngine.radioSponsorWareIDsByBanterID.keys)
        let marketWareIDs = Set(GoblinMarketEngine.inWorldWares.map(\.id))

        XCTAssertEqual(sponsorIDs, mappedSponsorIDs)
        for (sponsorID, wareID) in GoblinMarketEngine.radioSponsorWareIDsByBanterID {
            XCTAssertTrue(marketWareIDs.contains(wareID), "\(sponsorID) points at missing ware \(wareID)")
        }
    }

    func testPageContextConditionsMatchRecentKeptPages() {
        let context = RadioWorldContext(
            timeOfDay: "dusk",
            pageContext: RadioPageContext(
                keptToday: 4,
                recentPageTypeCounts: [.bookRemembered: 2, .diary: 1, .mood: 1],
                recentSourceIDs: ["bookRemembered"],
                recentTags: ["memory", "lamp"],
                lastKeptPageType: .mood,
                weatherTags: ["rain"]
            )
        )

        XCTAssertTrue(context.satisfies(RadioBanter.Conditions(
            pageTypes: [.bookRemembered, .diary, .mood],
            minRecentPagesOfType: 3,
            sourceTags: ["memory"],
            minKeptToday: 4,
            weatherTags: ["rain"],
            lastKeptPageTypes: [.mood]
        )))
        XCTAssertFalse(context.satisfies(RadioBanter.Conditions(
            pageTypes: [.narrativeOS],
            minRecentPagesOfType: 1
        )))
        XCTAssertFalse(context.satisfies(RadioBanter.Conditions(weatherTags: ["bright"])))
    }

    func testMothlightCanReactToRecentMemoryPages() throws {
        var state = RadioPlaybackState(
            activeStationID: "mothlight-beats",
            startedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let context = RadioWorldContext(
            timeOfDay: "dusk",
            pageContext: RadioPageContext(
                keptToday: 3,
                recentPageTypeCounts: [.bookRemembered: 2, .diary: 1],
                recentTags: ["memory"]
            )
        )

        var sawReactiveClip = false
        var now = Date(timeIntervalSince1970: 1_750_000_000)
        for _ in 0..<80 {
            if let banter = RadioStationRegistry.nextBanter(state: state, context: context, now: now) {
                if banter.id == "mothlight-pages-memory-cluster" {
                    sawReactiveClip = true
                    break
                }
                state.recordBanter(banter.id)
            }
            now = now.addingTimeInterval(901)
        }

        XCTAssertTrue(sawReactiveClip)
    }

    func testMothlightBatchReactiveTriggersAreRegistered() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "mothlight-beats"))
        let clips = Dictionary(uniqueKeysWithValues: station.resolvedBanters.map { ($0.id, $0) })

        let rainDusk = RadioWorldContext(
            timeOfDay: "dusk",
            pageContext: RadioPageContext(weatherTags: ["rain"])
        )
        XCTAssertTrue(rainDusk.satisfies(clips["mothlight-weather-rain-dusk"]?.conditions))

        let memoryChord = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.bookRemembered: 1, .diary: 1, .mood: 1])
        )
        XCTAssertTrue(memoryChord.satisfies(clips["mothlight-pages-memory-chord"]?.conditions))

        let lastMood = RadioWorldContext(
            timeOfDay: "night",
            pageContext: RadioPageContext(lastKeptPageType: .mood)
        )
        XCTAssertTrue(lastMood.satisfies(clips["mothlight-pages-last-mood-warm"]?.conditions))

        let fog = RadioWorldContext(
            timeOfDay: "night",
            pageContext: RadioPageContext(weatherTags: ["fog"])
        )
        XCTAssertTrue(fog.satisfies(clips["mothlight-weather-fog-listen"]?.conditions))

        let letters = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.letter: 1, .illustration: 1])
        )
        XCTAssertTrue(letters.satisfies(clips["mothlight-pages-letter-duet"]?.conditions))

        let busy = RadioWorldContext(pageContext: RadioPageContext(keptToday: 4))
        XCTAssertTrue(busy.satisfies(clips["mothlight-pages-kept-today-hum"]?.conditions))

        let grey = RadioWorldContext(timeOfDay: "dusk", grey: 45)
        XCTAssertTrue(grey.satisfies(clips["mothlight-grey-keep-the-lamp"]?.conditions))

        let classPage = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.academyClass: 1])
        )
        XCTAssertTrue(classPage.satisfies(clips["mothlight-class-resonance"]?.conditions))

        let dusk = RadioWorldContext(timeOfDay: "dusk")
        XCTAssertTrue(dusk.satisfies(clips["mothlight-class-quiet-hours"]?.conditions))

        let day = RadioWorldContext(timeOfDay: "day")
        XCTAssertFalse(day.satisfies(clips["mothlight-class-quiet-hours"]?.conditions))

        let inkrest = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.inkrestOfficeHours: 1])
        )
        XCTAssertTrue(inkrest.satisfies(clips["mothlight-cast-inkrest"]?.conditions))

        let remembered = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.bookRemembered: 1])
        )
        XCTAssertTrue(remembered.satisfies(clips["mothlight-lore-book-remembered"]?.conditions))

        XCTAssertNotNil(clips["mothlight-talisman-tide-glass"])
        XCTAssertNotNil(clips["mothlight-talisman-moss-clasp"])
        XCTAssertNotNil(clips["mothlight-cast-serenity"])
        XCTAssertNotNil(clips["mothlight-psa-samhain"])
        XCTAssertNotNil(clips["mothlight-psa-yule-newmoon"])
        XCTAssertNotNil(clips["mothlight-psa-resonance-class"])
        XCTAssertNotNil(clips["mothlight-psa-quiet-hours"])
    }

    func testFaeFiBatchReactiveTriggersAreRegistered() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi"))
        let clips = Dictionary(uniqueKeysWithValues: station.resolvedBanters.map { ($0.id, $0) })

        let souvenirContext = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.souvenir: 3])
        )
        XCTAssertTrue(souvenirContext.satisfies(clips["faefi-pages-souvenir-collector"]?.conditions))

        let brightContext = RadioWorldContext(
            timeOfDay: "day",
            pageContext: RadioPageContext(weatherTags: ["bright"])
        )
        XCTAssertTrue(brightContext.satisfies(clips["faefi-weather-bright-morning"]?.conditions))

        let wonderContext = RadioWorldContext(
            timeOfDay: "dawn",
            pageContext: RadioPageContext(recentSourceIDs: ["Wonder-Compass"])
        )
        XCTAssertTrue(wonderContext.satisfies(clips["faefi-source-wonder-compass-morning"]?.conditions))

        let busyContext = RadioWorldContext(
            pageContext: RadioPageContext(keptToday: 4)
        )
        XCTAssertTrue(busyContext.satisfies(clips["faefi-pages-kept-today-busy"]?.conditions))

        let festivalContext = RadioWorldContext(festivalActive: true)
        XCTAssertTrue(festivalContext.satisfies(clips["faefi-festival-mandatory-brightness"]?.conditions))

        let careContext = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.body: 1, .fuel: 1])
        )
        XCTAssertTrue(careContext.satisfies(clips["faefi-pages-body-fuel-care"]?.conditions))

        let loyaltyContext = RadioWorldContext(listeningDays: 4)
        XCTAssertTrue(loyaltyContext.satisfies(clips["faefi-listening-streak-loyal"]?.conditions))

        let photoContext = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.illuminatedPhoto: 1])
        )
        XCTAssertTrue(photoContext.satisfies(clips["faefi-pages-illuminated-photo"]?.conditions))

        let classContext = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.academyClass: 1])
        )
        XCTAssertTrue(classContext.satisfies(clips["faefi-class-glint"]?.conditions))

        XCTAssertNotNil(clips["faefi-club-marginalia"])
        XCTAssertNotNil(clips["faefi-talisman-wind-cipher"])
        XCTAssertNotNil(clips["faefi-cast-soren"])
        XCTAssertNotNil(clips["faefi-cast-wispwood"])
        XCTAssertNotNil(clips["faefi-lore-compass-run"])

        let letterContext = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.letter: 1])
        )
        XCTAssertTrue(letterContext.satisfies(clips["faefi-cast-gwendolyn"]?.conditions))

        let greyContext = RadioWorldContext(grey: 30)
        XCTAssertTrue(greyContext.satisfies(clips["faefi-tip-belief"]?.conditions))

        let compassSocietyContext = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.souvenir: 1])
        )
        XCTAssertTrue(compassSocietyContext.satisfies(clips["faefi-club-compass-society"]?.conditions))

        XCTAssertNotNil(clips["faefi-psa-timetable"])
        XCTAssertNotNil(clips["faefi-psa-curriculum"])
        XCTAssertNotNil(clips["faefi-psa-week-grid"])
        XCTAssertNotNil(clips["faefi-psa-bleed-editions"])
        XCTAssertNotNil(clips["faefi-psa-office-hours"])
        XCTAssertNotNil(clips["faefi-psa-todays-sky"])
        XCTAssertNotNil(clips["faefi-psa-festivals-wheel"])
        XCTAssertNotNil(clips["faefi-psa-moons-showers"])
        XCTAssertNotNil(clips["faefi-network-band"])

        let clubsNightContext = RadioWorldContext(timeOfDay: "night")
        XCTAssertTrue(clubsNightContext.satisfies(clips["faefi-psa-clubs"]?.conditions))

        let clubsDayContext = RadioWorldContext(timeOfDay: "day")
        XCTAssertFalse(clubsDayContext.satisfies(clips["faefi-psa-clubs"]?.conditions))
    }

    func testThornwaveCanReactToStoryPagesAtNightInWeather() throws {
        var state = RadioPlaybackState(
            activeStationID: "thornwave",
            startedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let context = RadioWorldContext(
            timeOfDay: "night",
            grey: 55,
            pageContext: RadioPageContext(
                keptToday: 2,
                recentPageTypeCounts: [.narrativeOS: 2],
                lastKeptPageType: .narrativeOS,
                weatherTags: ["storm", "rain"]
            )
        )

        var seen = Set<String>()
        var now = Date(timeIntervalSince1970: 1_750_000_000)
        for _ in 0..<80 {
            if let banter = RadioStationRegistry.nextBanter(state: state, context: context, now: now) {
                seen.insert(banter.id)
                state.recordBanter(banter.id)
            }
            now = now.addingTimeInterval(901)
        }

        XCTAssertTrue(seen.contains("thornwave-pages-story-night"))
        XCTAssertTrue(seen.contains("thornwave-weather-storm-grey"))
    }

    func testThornwaveBatchReactiveTriggersAreRegistered() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let clips = Dictionary(uniqueKeysWithValues: station.resolvedBanters.map { ($0.id, $0) })

        let bargain = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.faeBargain: 1])
        )
        XCTAssertTrue(bargain.satisfies(clips["thornwave-pages-fae-bargain-fineprint"]?.conditions))

        let stormGrey = RadioWorldContext(
            timeOfDay: "night",
            grey: 40,
            pageContext: RadioPageContext(weatherTags: ["storm"])
        )
        XCTAssertTrue(stormGrey.satisfies(clips["thornwave-weather-storm-grey-pressure"]?.conditions))

        let storyNight = RadioWorldContext(
            timeOfDay: "dusk",
            pageContext: RadioPageContext(recentPageTypeCounts: [.narrativeOS: 1, .bookJump: 1])
        )
        XCTAssertTrue(storyNight.satisfies(clips["thornwave-pages-story-night-choice"]?.conditions))

        let leverage = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.gossip: 1, .castBond: 1])
        )
        XCTAssertTrue(leverage.satisfies(clips["thornwave-pages-gossip-leverage"]?.conditions))

        let moonwrite = RadioWorldContext(
            timeOfDay: "night",
            pageContext: RadioPageContext(recentPageTypeCounts: [.souvenir: 1])
        )
        XCTAssertTrue(moonwrite.satisfies(clips["thornwave-pages-moonwrite"]?.conditions))

        let afterMidnight = RadioWorldContext(timeOfDay: "night")
        XCTAssertTrue(afterMidnight.satisfies(clips["thornwave-time-after-midnight"]?.conditions))

        let greyHigh = RadioWorldContext(grey: 60)
        XCTAssertTrue(greyHigh.satisfies(clips["thornwave-grey-high-keep-the-door"]?.conditions))

        let anchor = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.anchor: 1])
        )
        XCTAssertTrue(anchor.satisfies(clips["thornwave-pages-anchor-impressed"]?.conditions))

        let dusk = RadioWorldContext(timeOfDay: "dusk")
        XCTAssertTrue(dusk.satisfies(clips["thornwave-talisman-dusk-thorn"]?.conditions))
        XCTAssertTrue(dusk.satisfies(clips["thornwave-cast-thorne"]?.conditions))
        XCTAssertTrue(dusk.satisfies(clips["thornwave-network-grey"]?.conditions))
        XCTAssertTrue(dusk.satisfies(clips["thornwave-psa-clubs-night"]?.conditions))
        XCTAssertTrue(dusk.satisfies(clips["thornwave-psa-fullmoon"]?.conditions))

        let day = RadioWorldContext(timeOfDay: "day")
        XCTAssertFalse(day.satisfies(clips["thornwave-talisman-dusk-thorn"]?.conditions))
        XCTAssertFalse(day.satisfies(clips["thornwave-psa-clubs-night"]?.conditions))

        let night = RadioWorldContext(timeOfDay: "night")
        XCTAssertTrue(night.satisfies(clips["thornwave-cast-damien"]?.conditions))

        let bookJump = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.bookJump: 1])
        )
        XCTAssertTrue(bookJump.satisfies(clips["thornwave-class-book-jumping"]?.conditions))

        XCTAssertNotNil(clips["thornwave-talisman-ember-seal"])
        XCTAssertNotNil(clips["thornwave-cast-finn"])
        XCTAssertNotNil(clips["thornwave-club-inkwright"])
        XCTAssertNotNil(clips["thornwave-psa-beltane"])
    }

    func testHiddenBleedCanReactToGossipClustersAndNight() throws {
        let station = try XCTUnwrap(RadioStationRegistry.station(id: "the-bleed"))
        XCTAssertEqual(station.interstitialAssetName, "RadioFreeMarginStatic")
        XCTAssertEqual(station.interstitialTitle, "Radio Free Margin Static")
        let clips = Dictionary(uniqueKeysWithValues: station.resolvedBanters.map { ($0.id, $0) })

        XCTAssertNotNil(clips["bleed-rant-02"])
        XCTAssertNotNil(clips["bleed-lore-unwritten"])

        let crew = RadioWorldContext(
            pageContext: RadioPageContext(recentPageTypeCounts: [.illustration: 1, .gossip: 1])
        )
        XCTAssertTrue(crew.satisfies(clips["bleed-cast-crew"]?.conditions))

        let grey = RadioWorldContext(grey: 35)
        XCTAssertTrue(grey.satisfies(clips["bleed-talisman-contraband"]?.conditions))

        let day = RadioWorldContext(timeOfDay: "day")
        XCTAssertFalse(day.satisfies(clips["bleed-cast-thorne"]?.conditions))

        var state = RadioPlaybackState(
            activeStationID: "the-bleed",
            startedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let context = RadioWorldContext(
            timeOfDay: "night",
            pageContext: RadioPageContext(
                keptToday: 2,
                recentPageTypeCounts: [.gossip: 1, .theBleed: 1]
            )
        )

        var seen = Set<String>()
        var now = Date(timeIntervalSince1970: 1_750_000_000)
        for _ in 0..<20 {
            if let banter = RadioStationRegistry.nextBanter(state: state, context: context, now: now) {
                seen.insert(banter.id)
                state.recordBanter(banter.id)
            }
            now = now.addingTimeInterval(901)
        }

        XCTAssertTrue(seen.contains("bleed-pages-gossip-cluster"))
        XCTAssertTrue(seen.contains("bleed-time-after-midnight"))
        XCTAssertTrue(seen.contains("bleed-cast-thorne"))
    }

    func testOldBanterConditionJSONStillDecodes() throws {
        let data = """
        {
          "timeOfDay": ["night"],
          "minGrey": 35
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(RadioBanter.Conditions.self, from: data)

        XCTAssertEqual(decoded.timeOfDay, ["night"])
        XCTAssertEqual(decoded.minGrey, 35)
        XCTAssertNil(decoded.pageTypes)
        XCTAssertNil(decoded.weatherTags)
    }

    func testNewReactiveDJAssetsAreBundled() throws {
        let faeFi = try XCTUnwrap(RadioStationRegistry.station(id: "fae-fi"))
        let faeClips = Dictionary(uniqueKeysWithValues: faeFi.resolvedBanters.map { ($0.id, $0.assetName) })
        XCTAssertEqual(faeClips["faefi-pages-souvenir-cluster"], "DJ_faefi_pages_souvenir_01")
        XCTAssertEqual(faeClips["faefi-pages-wonder-morning"], "DJ_faefi_pages_wonder_morning_01")
        XCTAssertEqual(faeClips["faefi-weather-bright"], "DJ_faefi_weather_bright_01")
        XCTAssertEqual(faeClips["faefi-pages-souvenir-collector"], "DJ_faefi_pages_souvenir_02")
        XCTAssertEqual(faeClips["faefi-weather-bright-morning"], "DJ_faefi_weather_bright_morning_02")
        XCTAssertEqual(faeClips["faefi-source-wonder-compass-morning"], "DJ_faefi_source_wonder_compass_02")
        XCTAssertEqual(faeClips["faefi-pages-kept-today-busy"], "DJ_faefi_pages_kept_today_busy_01")
        XCTAssertEqual(faeClips["faefi-festival-mandatory-brightness"], "DJ_faefi_festival_window_01")
        XCTAssertEqual(faeClips["faefi-pages-body-fuel-care"], "DJ_faefi_pages_body_fuel_care_01")
        XCTAssertEqual(faeClips["faefi-listening-streak-loyal"], "DJ_faefi_listening_streak_01")
        XCTAssertEqual(faeClips["faefi-pages-illuminated-photo"], "DJ_faefi_pages_illuminated_photo_01")
        XCTAssertEqual(faeClips["faefi-class-glint"], "DJ_faefi_class_glint_01")
        XCTAssertEqual(faeClips["faefi-club-marginalia"], "DJ_faefi_club_marginalia_01")
        XCTAssertEqual(faeClips["faefi-talisman-wind-cipher"], "DJ_faefi_talisman_wind_cipher_01")
        XCTAssertEqual(faeClips["faefi-cast-soren"], "DJ_faefi_cast_soren_01")
        XCTAssertEqual(faeClips["faefi-cast-wispwood"], "DJ_faefi_cast_wispwood_01")
        XCTAssertEqual(faeClips["faefi-cast-gwendolyn"], "DJ_faefi_cast_gwendolyn_01")
        XCTAssertEqual(faeClips["faefi-lore-compass-run"], "DJ_faefi_lore_compass_run_01")
        XCTAssertEqual(faeClips["faefi-tip-belief"], "DJ_faefi_tip_belief_01")
        XCTAssertEqual(faeClips["faefi-club-compass-society"], "DJ_faefi_club_compass_society_01")
        XCTAssertEqual(faeClips["faefi-psa-timetable"], "DJ_faefi_psa_timetable_01")
        XCTAssertEqual(faeClips["faefi-psa-curriculum"], "DJ_faefi_psa_curriculum_01")
        XCTAssertEqual(faeClips["faefi-psa-week-grid"], "DJ_faefi_psa_week_grid_01")
        XCTAssertEqual(faeClips["faefi-psa-clubs"], "DJ_faefi_psa_clubs_01")
        XCTAssertEqual(faeClips["faefi-psa-bleed-editions"], "DJ_faefi_psa_bleed_editions_01")
        XCTAssertEqual(faeClips["faefi-psa-office-hours"], "DJ_faefi_psa_office_hours_01")
        XCTAssertEqual(faeClips["faefi-psa-todays-sky"], "DJ_faefi_psa_todays_sky_01")
        XCTAssertEqual(faeClips["faefi-psa-festivals-wheel"], "DJ_faefi_psa_festivals_wheel_01")
        XCTAssertEqual(faeClips["faefi-psa-moons-showers"], "DJ_faefi_psa_moons_showers_01")
        XCTAssertEqual(faeClips["faefi-network-band"], "DJ_faefi_network_band_01")

        let mothlight = try XCTUnwrap(RadioStationRegistry.station(id: "mothlight-beats"))
        let mothlightClips = Dictionary(uniqueKeysWithValues: mothlight.resolvedBanters.map { ($0.id, $0.assetName) })
        XCTAssertEqual(mothlightClips["mothlight-pages-memory-cluster"], "DJ_mothlight_pages_memory_01")
        XCTAssertEqual(mothlightClips["mothlight-pages-last-mood-night"], "DJ_mothlight_pages_mood_night_01")
        XCTAssertEqual(mothlightClips["mothlight-weather-rain"], "DJ_mothlight_weather_rain_01")
        XCTAssertEqual(mothlightClips["mothlight-pages-kept-today"], "DJ_mothlight_pages_kept_today_01")
        XCTAssertEqual(mothlightClips["mothlight-weather-rain-dusk"], "DJ_mothlight_weather_rain_dusk_02")
        XCTAssertEqual(mothlightClips["mothlight-pages-memory-chord"], "DJ_mothlight_pages_memory_cluster_02")
        XCTAssertEqual(mothlightClips["mothlight-pages-last-mood-warm"], "DJ_mothlight_pages_last_mood_night_02")
        XCTAssertEqual(mothlightClips["mothlight-weather-fog-listen"], "DJ_mothlight_weather_fog_01")
        XCTAssertEqual(mothlightClips["mothlight-pages-letter-duet"], "DJ_mothlight_pages_letter_01")
        XCTAssertEqual(mothlightClips["mothlight-pages-kept-today-hum"], "DJ_mothlight_pages_kept_today_gentle_01")
        XCTAssertEqual(mothlightClips["mothlight-grey-keep-the-lamp"], "DJ_mothlight_grey_gentle_01")
        XCTAssertEqual(mothlightClips["mothlight-class-resonance"], "DJ_mothlight_class_resonance_01")
        XCTAssertEqual(mothlightClips["mothlight-class-quiet-hours"], "DJ_mothlight_class_quiet_hours_01")
        XCTAssertEqual(mothlightClips["mothlight-talisman-tide-glass"], "DJ_mothlight_talisman_tide_glass_01")
        XCTAssertEqual(mothlightClips["mothlight-talisman-moss-clasp"], "DJ_mothlight_talisman_moss_clasp_01")
        XCTAssertEqual(mothlightClips["mothlight-cast-inkrest"], "DJ_mothlight_cast_inkrest_01")
        XCTAssertEqual(mothlightClips["mothlight-cast-serenity"], "DJ_mothlight_cast_serenity_01")
        XCTAssertEqual(mothlightClips["mothlight-lore-book-remembered"], "DJ_mothlight_lore_book_remembered_01")
        XCTAssertEqual(mothlightClips["mothlight-psa-samhain"], "DJ_mothlight_psa_samhain_01")
        XCTAssertEqual(mothlightClips["mothlight-psa-yule-newmoon"], "DJ_mothlight_psa_yule_newmoon_01")
        XCTAssertEqual(mothlightClips["mothlight-psa-resonance-class"], "DJ_mothlight_psa_resonance_class_01")
        XCTAssertEqual(mothlightClips["mothlight-psa-quiet-hours"], "DJ_mothlight_psa_quiet_hours_01")

        let thornwave = try XCTUnwrap(RadioStationRegistry.station(id: "thornwave"))
        let thornClips = Dictionary(uniqueKeysWithValues: thornwave.resolvedBanters.map { ($0.id, $0.assetName) })
        XCTAssertEqual(thornClips["thornwave-pages-story-night"], "DJ_thornwave_pages_story_night_01")
        XCTAssertEqual(thornClips["thornwave-pages-fae-bargain"], "DJ_thornwave_pages_bargain_01")
        XCTAssertEqual(thornClips["thornwave-weather-storm-grey"], "DJ_thornwave_weather_storm_grey_01")
        XCTAssertEqual(thornClips["thornwave-pages-gossip"], "DJ_thornwave_pages_gossip_01")
        XCTAssertEqual(thornClips["thornwave-pages-fae-bargain-fineprint"], "DJ_thornwave_pages_bargain_02")
        XCTAssertEqual(thornClips["thornwave-weather-storm-grey-pressure"], "DJ_thornwave_weather_storm_grey_02")
        XCTAssertEqual(thornClips["thornwave-pages-story-night-choice"], "DJ_thornwave_pages_story_night_02")
        XCTAssertEqual(thornClips["thornwave-pages-gossip-leverage"], "DJ_thornwave_pages_gossip_02")
        XCTAssertNil(thornClips["thornwave-pages-moonwrite"] ?? nil)
        XCTAssertEqual(thornClips["thornwave-time-after-midnight"], "DJ_thornwave_time_after_midnight_01")
        XCTAssertEqual(thornClips["thornwave-grey-high-keep-the-door"], "DJ_thornwave_grey_high_pressure_01")
        XCTAssertEqual(thornClips["thornwave-pages-anchor-impressed"], "DJ_thornwave_pages_anchor_resist_01")
        XCTAssertEqual(thornClips["thornwave-talisman-dusk-thorn"], "DJ_thornwave_talisman_dusk_thorn_01")
        XCTAssertEqual(thornClips["thornwave-talisman-ember-seal"], "DJ_thornwave_talisman_ember_seal_01")
        XCTAssertEqual(thornClips["thornwave-class-book-jumping"], "DJ_thornwave_class_book_jumping_01")
        XCTAssertEqual(thornClips["thornwave-cast-finn"], "DJ_thornwave_cast_finn_01")
        XCTAssertEqual(thornClips["thornwave-cast-damien"], "DJ_thornwave_cast_damien_01")
        XCTAssertEqual(thornClips["thornwave-cast-thorne"], "DJ_thornwave_cast_thorne_01")
        XCTAssertEqual(thornClips["thornwave-club-inkwright"], "DJ_thornwave_club_inkwright_01")
        XCTAssertEqual(thornClips["thornwave-network-grey"], "DJ_thornwave_network_grey_01")
        XCTAssertEqual(thornClips["thornwave-psa-clubs-night"], "DJ_thornwave_psa_clubs_night_01")
        XCTAssertEqual(thornClips["thornwave-psa-beltane"], "DJ_thornwave_psa_beltane_01")
        XCTAssertEqual(thornClips["thornwave-psa-fullmoon"], "DJ_thornwave_psa_fullmoon_01")

        let bleed = try XCTUnwrap(RadioStationRegistry.station(id: "the-bleed"))
        let bleedClips = Dictionary(uniqueKeysWithValues: bleed.resolvedBanters.map { ($0.id, $0.assetName) })
        XCTAssertEqual(bleed.interstitialAssetName, "RadioFreeMarginStatic")
        XCTAssertEqual(bleedClips["bleed-rant-02"], "DJ_bleed_rant_02")
        XCTAssertEqual(bleedClips["bleed-cast-crew"], "DJ_bleed_cast_crew_01")
        XCTAssertEqual(bleedClips["bleed-talisman-contraband"], "DJ_bleed_talisman_contraband_01")
        XCTAssertEqual(bleedClips["bleed-lore-unwritten"], "DJ_bleed_lore_unwritten_01")
        XCTAssertEqual(bleedClips["bleed-cast-thorne"], "DJ_bleed_cast_thorne_01")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let radioAudio = root.appendingPathComponent("InsideCoverApp/RadioAudio", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_pages_souvenir_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_pages_wonder_morning_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_weather_bright_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_pages_souvenir_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_weather_bright_morning_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_source_wonder_compass_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_pages_kept_today_busy_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_festival_window_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_pages_body_fuel_care_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_listening_streak_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_pages_illuminated_photo_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_class_glint_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_club_marginalia_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_talisman_wind_cipher_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_cast_soren_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_cast_wispwood_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_cast_gwendolyn_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_lore_compass_run_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_tip_belief_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_club_compass_society_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_timetable_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_curriculum_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_week_grid_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_clubs_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_bleed_editions_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_office_hours_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_todays_sky_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_festivals_wheel_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_psa_moons_showers_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_faefi_network_band_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_memory_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_mood_night_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_weather_rain_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_kept_today_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_weather_rain_dusk_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_memory_cluster_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_last_mood_night_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_weather_fog_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_letter_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_pages_kept_today_gentle_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_grey_gentle_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_class_resonance_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_class_quiet_hours_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_talisman_tide_glass_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_talisman_moss_clasp_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_cast_inkrest_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_cast_serenity_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_lore_book_remembered_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_psa_samhain_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_psa_yule_newmoon_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_psa_resonance_class_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_mothlight_psa_quiet_hours_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_story_night_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_bargain_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_weather_storm_grey_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_gossip_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_bargain_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_weather_storm_grey_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_story_night_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_gossip_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_time_after_midnight_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_grey_high_pressure_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_pages_anchor_resist_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_talisman_dusk_thorn_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_talisman_ember_seal_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_class_book_jumping_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_cast_finn_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_cast_damien_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_cast_thorne_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_club_inkwright_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_network_grey_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_psa_clubs_night_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_psa_beltane_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_thornwave_psa_fullmoon_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("RadioFreeMarginStatic.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_bleed_rant_02.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_bleed_cast_crew_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_bleed_talisman_contraband_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_bleed_lore_unwritten_01.m4a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: radioAudio.appendingPathComponent("DJ_bleed_cast_thorne_01.m4a").path))
    }
}
