import XCTest
@testable import InsideCoverCore

final class RadioNarrativeEchoTests: XCTestCase {
    func testLegacyTrackDecodesWithoutMeaning() throws {
        let track = try JSONDecoder().decode(RadioTrack.self, from: Data("""
        {"id":"old","title":"Old","artist":"A","moodTags":[]}
        """.utf8))
        XCTAssertNil(track.meaning)

        let authored = try JSONDecoder().decode(RadioTrack.self, from: Data("""
        {
          "id":"new",
          "title":"New",
          "artist":"A",
          "moodTags":[],
          "meaning":{
            "themeTags":["ordinary wonder"],
            "imageTags":["steam lifting from a cup"],
            "ordinaryLifeCue":"Notice what the air is carrying."
          }
        }
        """.utf8))
        XCTAssertEqual(authored.meaning?.themeTags, ["ordinary wonder"])
    }

    func testMeaningSanitizesAndBoundsUserHooks() {
        let raw = RadioTrackMeaning(
            themeTags: [" one\n two ", "b", "c", "d", "e"],
            imageTags: Array(repeating: String(repeating: "x", count: 70), count: 5),
            ordinaryLifeCue: "line one\nline two\u{0000}"
        ).sanitized()
        XCTAssertEqual(raw.themeTags?.count, 4)
        XCTAssertEqual(raw.imageTags?.count, 4)
        XCTAssertTrue(raw.imageTags!.allSatisfy { $0.count <= 48 })
        XCTAssertFalse(raw.ordinaryLifeCue!.contains("\n"))
    }

    func testRecentReceiptResolvesAndExpiredOrMissingFailsClosed() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let receipt = RadioTrackPlayReceipt(stationID: "fae-fi", trackID: "fae-fi-mossy-footsteps", startedAt: now)
        XCTAssertNotNil(RadioStationRegistry.narrativeEcho(receipt: receipt, now: now))
        XCTAssertNil(RadioStationRegistry.narrativeEcho(receipt: receipt, now: now.addingTimeInterval(86_401)))
        XCTAssertNil(RadioStationRegistry.narrativeEcho(receipt: RadioTrackPlayReceipt(stationID: "fae-fi", trackID: "gone", startedAt: now), now: now))
        XCTAssertNil(RadioStationRegistry.narrativeEcho(
            receipt: RadioTrackPlayReceipt(
                stationID: "midnight-bindery",
                trackID: "midnight-bindery-thread",
                startedAt: now
            ),
            unlockedPackIDs: [],
            now: now
        ))
    }

    func testBundledTracksCarryBoundedMeaningAndPromptIsGuarded() {
        let tracks = RadioStationRegistry.bundledPacks.flatMap(\.stations).flatMap(\.tracks)
        XCTAssertFalse(tracks.isEmpty)
        XCTAssertTrue(tracks.allSatisfy { $0.meaning?.sanitized().ordinaryLifeCue != nil })
        XCTAssertTrue(tracks.allSatisfy {
            $0.meaning?.sanitized().imageTags?.contains($0.title) != true
        })
        XCTAssertGreaterThan(
            Set(tracks.compactMap { $0.meaning?.sanitized().ordinaryLifeCue }).count,
            tracks.count / 2
        )
        let echo = RadioStationRegistry.narrativeEcho(receipt: RadioTrackPlayReceipt(stationID: "fae-fi", trackID: "fae-fi-mossy-footsteps", startedAt: Date()), now: Date())!
        let section = RadioNarrativeEchoPrompt.section(echo)
        XCTAssertTrue(section.contains("AUTHORED NON-LYRIC ATMOSPHERE, NOT EVIDENCE"))
        XCTAssertTrue(section.contains("Never quote or reconstruct lyrics"))
        XCTAssertTrue(section.contains("never infer what the reader liked"))
    }

    func testVaultRoundTripsOptionalReceipt() throws {
        var data = PlayerVaultData()
        data.lastRadioTrackPlay = RadioTrackPlayReceipt(stationID: "fae-fi", trackID: "fae-fi-mossy-footsteps", startedAt: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(data)), data)
        XCTAssertNil(try JSONDecoder().decode(PlayerVaultData.self, from: JSONEncoder().encode(PlayerVaultData())).lastRadioTrackPlay)
    }
}
