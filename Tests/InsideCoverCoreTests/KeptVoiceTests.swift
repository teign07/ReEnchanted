import XCTest
@testable import InsideCoverCore

final class KeptVoiceTests: XCTestCase {

    func testAudioFileKindDecodes() throws {
        let json = #"{"id":"v1","kind":"audioFile","reference":"/c/kept-voice.m4a","caption":"","sourceID":"diary","metadata":{}}"#
        let asset = try JSONDecoder().decode(BookPageMediaAsset.self, from: Data(json.utf8))
        XCTAssertEqual(asset.kind, .audioFile)
        XCTAssertEqual(asset.reference, "/c/kept-voice.m4a")
    }

    func testIsFileBackedCoversImageAndAudioOnly() {
        XCTAssertTrue(BookPageMediaAsset.Kind.renderedImageFile.isFileBacked)
        XCTAssertTrue(BookPageMediaAsset.Kind.audioFile.isFileBacked)
        XCTAssertFalse(BookPageMediaAsset.Kind.bundledImage.isFileBacked)
        XCTAssertFalse(BookPageMediaAsset.Kind.photoLibraryAsset.isFileBacked)
    }

    func testSealCarriesAudioAssetReferences() {
        let page = BookPage(
            id: "p1", type: .diary, promptText: "",
            mediaAssets: [
                BookPageMediaAsset(kind: .audioFile, reference: "/old/kept-voice.m4a"),
                BookPageMediaAsset(kind: .renderedImageFile, reference: "/old/photo.jpg"),
                BookPageMediaAsset(kind: .bundledImage, reference: "bundled"),
            ]
        )
        let days = [BookDay(id: "2027-03-03", date: Date(timeIntervalSince1970: 0), pages: [page])]
        let refs = ReEnchantedSaveFile.fileBackedReferences(in: days)
        XCTAssertEqual(Set(refs), ["/old/kept-voice.m4a", "/old/photo.jpg"])

        // Rehoming moves the audio file's reference onto the new container too.
        let rehomed = ReEnchantedSaveFile.rehomedDays(days, toContainer: URL(fileURLWithPath: "/new"))
        let audio = rehomed[0].pages[0].mediaAssets.first { $0.kind == .audioFile }
        XCTAssertEqual(audio?.reference, "/new/kept-voice.m4a")
    }

    func testCadenceReceiptDistinguishesBurstsFromContinuousFlow() throws {
        let bursts = try XCTUnwrap(VoiceCadenceReceipt.analyze(
            decibels: [-60, -14, -12, -60, -60, -16, -13, -60, -60, -15, -11, -60],
            sampleInterval: 0.5,
            duration: 6
        ))
        let flow = try XCTUnwrap(VoiceCadenceReceipt.analyze(
            decibels: [-22, -21, -20, -19, -21, -20, -18, -20],
            sampleInterval: 0.5,
            duration: 4
        ))

        XCTAssertEqual(bursts.cadenceLabel, "short bursts")
        XCTAssertEqual(bursts.pauseLabel, "clear pauses")
        XCTAssertEqual(flow.cadenceLabel, "continuous flow")
        XCTAssertEqual(flow.pauseLabel, "nearly continuous")
        XCTAssertGreaterThan(flow.activeRatio, bursts.activeRatio)
    }

    func testCadenceReceiptBecomesInspectableAcousticVector() throws {
        let receipt = try XCTUnwrap(VoiceCadenceReceipt.analyze(
            decibels: [-60, -18, -16, -60, -60, -17, -15, -60],
            sampleInterval: 0.5,
            duration: 4
        ))
        let page = BookPage(
            id: "voice-folio",
            type: .diary,
            promptText: "",
            origin: .userAuthored,
            mediaAssets: [
                BookPageMediaAsset(
                    kind: .audioFile,
                    reference: "/tmp/voice.m4a",
                    metadata: receipt.metadata.merging(["keptVoice": "true"]) { measured, _ in measured }
                )
            ]
        )

        let folio = SensoryFolioProjector.make(from: page, encoder: nil)

        XCTAssertEqual(folio.values(for: .voiceCadence), [receipt.cadenceLabel])
        XCTAssertEqual(folio.values(for: .voicePause), [receipt.pauseLabel])
        XCTAssertEqual(folio.values(for: .voiceEnergy), [receipt.energyLabel])
        XCTAssertEqual(folio.vector(.acousticProsody)?.modelID, VoiceCadenceReceipt.modelID)
        XCTAssertEqual(folio.vector(.acousticProsody)?.values.count, 6)
    }
}
