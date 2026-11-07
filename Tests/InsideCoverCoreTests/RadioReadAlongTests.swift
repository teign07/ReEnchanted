import XCTest
@testable import InsideCoverCore

final class RadioReadAlongTests: XCTestCase {
    func testCueBoundariesAndSilentGaps() {
        let sheet = RadioReadAlong(text: "Hello. Come in.", cues: [
            .init(start: 1, end: 2, text: "Hello."),
            .init(start: 3, end: 4, text: "Come in.")
        ])
        XCTAssertNil(sheet.activeCueIndex(at: 0))
        XCTAssertEqual(sheet.activeCueIndex(at: 1), 0)
        XCTAssertNil(sheet.activeCueIndex(at: 2))
        XCTAssertEqual(sheet.activeCueIndex(at: 3.5), 1)
        XCTAssertNil(sheet.activeCueIndex(at: 4))
        XCTAssertNil(sheet.activeCueIndex(at: .nan))
    }

    func testPartialOrOverlappingAlignmentKeepsTheCompleteTranscript() {
        let partial = RadioReadAlong(text: "First line.\nLast line.", cues: [
            .init(start: 0, end: 1, text: "First line.")
        ])
        XCTAssertFalse(partial.hasValidTiming)
        XCTAssertEqual(partial.readableLines, ["First line.", "Last line."])
        XCTAssertNil(partial.activeCueIndex(at: 0.5))

        let overlap = RadioReadAlong(text: "One. Two.", cues: [
            .init(start: 0, end: 2, text: "One."),
            .init(start: 1, end: 3, text: "Two.")
        ])
        XCTAssertFalse(overlap.hasValidTiming)
        XCTAssertEqual(overlap.readableLines, ["One. Two."])
    }

    func testUntimedLyricsAndLegacyCatalogDecode() throws {
        let sheet = try JSONDecoder().decode(RadioReadAlong.self, from: Data(#"{"text":"A light in the window."}"#.utf8))
        XCTAssertFalse(sheet.hasValidTiming)
        XCTAssertEqual(sheet.readableLines, ["A light in the window."])
        let track = try JSONDecoder().decode(RadioTrack.self, from: Data(#"{"id":"old","title":"Old song","artist":"Academy","moodTags":[]}"#.utf8))
        XCTAssertNil(track.lyrics)
        let banter = try JSONDecoder().decode(RadioBanter.self, from: Data(#"{"id":"old","category":"news","caption":"Hello."}"#.utf8))
        XCTAssertEqual(banter.readerFacingCaption, "Hello.")
    }

    func testBundledDJRecordingsAllHaveCompleteReadableCueSheets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let audio = root.appendingPathComponent("InsideCoverApp/RadioAudio")
        let sheets = try JSONDecoder().decode([String: RadioReadAlong].self,
            from: Data(contentsOf: audio.appendingPathComponent("RadioReadAlong.json")))
        let recordings = try FileManager.default.contentsOfDirectory(at: audio, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("DJ_") && ["m4a", "mp3", "wav", "aac", "caf", "aiff"].contains($0.pathExtension.lowercased()) }
        XCTAssertFalse(recordings.isEmpty)
        for recording in recordings {
            let name = recording.deletingPathExtension().lastPathComponent
            let sheet = try XCTUnwrap(sheets[name], name)
            XCTAssertFalse(sheet.text.isEmpty, name)
            XCTAssertTrue(sheet.hasValidTiming, name)
            XCTAssertFalse(sheet.text.contains("Audio-backed clip"), name)
        }
    }
}
