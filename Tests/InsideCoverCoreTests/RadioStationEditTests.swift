import XCTest
@testable import InsideCoverCore

final class RadioStationEditTests: XCTestCase {
    private let editOnlyPack = """
    {
      "id": "november-radio",
      "displayName": "November on the dial",
      "stationEdits": [
        {
          "stationID": "fae-fi",
          "removeTrackIDs": ["fae-fi-mossy-footsteps"],
          "addTracks": [
            {
              "id": "fae-fi-november-kettle",
              "title": "Kettle Weather",
              "artist": "Fae-Fi",
              "assetName": "{{asset-path:november.song.kettle-weather}}",
              "durationSeconds": 140,
              "moodTags": ["warm"],
              "conditions": {"months": [11]}
            }
          ]
        }
      ]
    }
    """

    private var faeFi: RadioStation {
        RadioStationRegistry.coreStations.first { $0.id == "fae-fi" }!
    }

    private func track(_ id: String) -> RadioTrack {
        RadioTrack(id: id, title: id, artist: "Test", moodTags: [])
    }

    func testAPackCanShipOnlyEdits() throws {
        let pack = try JSONDecoder().decode(RadioStationPack.self, from: Data(editOnlyPack.utf8))
        XCTAssertTrue(pack.stations.isEmpty)
        XCTAssertEqual(pack.stationEdits?.first?.stationID, "fae-fi")
        XCTAssertEqual(pack.stationEdits?.first?.addTracks?.first?.conditions?.months, [11])
    }

    func testOlderPacksStillDecode() throws {
        let pack = try JSONDecoder().decode(RadioStationPack.self, from: Data("""
        {"id": "old", "displayName": "Old", "stations": []}
        """.utf8))
        XCTAssertNil(pack.stationEdits)
    }

    func testEditRemovesAndAddsSongsOnAnExistingStation() throws {
        let edit = try XCTUnwrap(
            JSONDecoder().decode(RadioStationPack.self, from: Data(editOnlyPack.utf8)).stationEdits?.first
        )
        let edited = edit.applied(to: faeFi)
        let ids = edited.tracks.map(\.id)
        XCTAssertFalse(ids.contains("fae-fi-mossy-footsteps"))
        XCTAssertEqual(ids.last, "fae-fi-november-kettle")
        XCTAssertEqual(edited.tracks.count, faeFi.tracks.count)
        XCTAssertEqual(edited.title, faeFi.title)
    }

    func testAnAddedSongWithAnExistingIDReplacesIt() {
        let station = faeFi
        var louder = station.tracks[0]
        louder.weight = 9
        let edited = RadioStationEdit(stationID: station.id, addTracks: [louder]).applied(to: station)
        XCTAssertEqual(edited.tracks.count, station.tracks.count)
        XCTAssertEqual(edited.tracks[0].weight, 9)
    }

    func testAnEditLeavesOtherStationsAlone() {
        let other = RadioStationRegistry.coreStations.first { $0.id != "fae-fi" }!
        let edit = RadioStationEdit(stationID: "fae-fi", addTracks: [track("x")], removeTrackIDs: other.tracks.map(\.id))
        XCTAssertEqual(edit.applied(to: other), other)
    }

    func testRemovingEverySongKeepsTheStationOnTheAir() {
        let station = faeFi
        let silent = RadioStationEdit(stationID: station.id, removeTrackIDs: station.tracks.map(\.id))
        XCTAssertEqual(silent.applied(to: station).tracks, station.tracks)

        let replaced = RadioStationEdit(
            stationID: station.id, addTracks: [track("only")], removeTrackIDs: station.tracks.map(\.id)
        ).applied(to: station)
        XCTAssertEqual(replaced.tracks.map(\.id), ["only"])
    }

    func testTheInstallerAcceptsAnEditOnlyPack() {
        let data = Data(editOnlyPack.utf8)
        let asset = MonthlyIssueDeliveryAsset(
            id: "november.radio.v1", kind: .radioStationPack, scope: .runtime,
            remoteURL: URL(string: "https://example.invalid/november.radio.v1")!,
            fileName: "november.reenchantedradio.json", sha256: "", byteCount: data.count
        )
        XCTAssertNoThrow(try MonthlyIssueAssetInstaller.validateMaterializedAsset(data, asset: asset))
    }
}
