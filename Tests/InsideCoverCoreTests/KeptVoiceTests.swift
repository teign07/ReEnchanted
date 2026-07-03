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
}
