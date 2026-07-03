import XCTest
@testable import InsideCoverCore

final class SealedCopyTests: XCTestCase {

    // MARK: Helpers

    private func page(_ id: String, assets: [BookPageMediaAsset]) -> BookPage {
        BookPage(id: id, type: .diary, promptText: "", mediaAssets: assets)
    }

    private func day(_ id: String, pages: [BookPage]) -> BookDay {
        BookDay(id: id, date: Date(timeIntervalSince1970: 0), pages: pages)
    }

    private func fileAsset(_ path: String) -> BookPageMediaAsset {
        BookPageMediaAsset(kind: .renderedImageFile, reference: path)
    }

    /// A minimal-but-valid save file. All the world ledgers are empty; only the
    /// bits Phase 1 touches (days, mediaFiles) carry meaning here.
    private func makeSaveFile(days: [BookDay], mediaFiles: [String: Data]?) -> ReEnchantedSaveFile {
        ReEnchantedSaveFile(
            exportedAt: Date(timeIntervalSince1970: 0),
            days: days,
            selfFacts: [],
            narrativeEvents: [],
            entityMemories: [],
            facultyEntries: [],
            customCastMembers: [],
            anchors: [],
            compassKnownPlaces: nil,
            electives: [],
            beliefScore: 0,
            entityBeliefLedger: [:],
            pageBeliefLedger: [:],
            marginTutorSeen: [],
            didCompleteStoryOnboarding: false,
            sourcePreferences: [:],
            constellations: nil,
            wagers: nil,
            themes: nil,
            clusters: nil,
            readerLexicon: nil,
            continuity: nil,
            mediaFiles: mediaFiles
        )
    }

    // MARK: isFileBacked

    func testIsFileBackedOnlyForRenderedImageFile() {
        XCTAssertTrue(BookPageMediaAsset.Kind.renderedImageFile.isFileBacked)
        XCTAssertFalse(BookPageMediaAsset.Kind.bundledImage.isFileBacked)
        XCTAssertFalse(BookPageMediaAsset.Kind.photoLibraryAsset.isFileBacked)
    }

    // MARK: fileBackedReferences

    func testFileBackedReferencesCollectsAndDeduplicates() {
        let days = [
            day("d1", pages: [
                page("p1", assets: [
                    fileAsset("/old/a.jpg"),
                    BookPageMediaAsset(kind: .bundledImage, reference: "bundled-name"),
                ]),
                page("p2", assets: [fileAsset("/old/a.jpg")]), // duplicate path
            ]),
            day("d2", pages: [page("p3", assets: [fileAsset("/old/b.jpg")])]),
        ]
        let refs = ReEnchantedSaveFile.fileBackedReferences(in: days)
        XCTAssertEqual(refs, ["/old/a.jpg", "/old/b.jpg"])
    }

    func testFileBackedReferencesIgnoresBundledAndPhotoLibrary() {
        let days = [day("d1", pages: [page("p1", assets: [
            BookPageMediaAsset(kind: .bundledImage, reference: "name"),
            BookPageMediaAsset(kind: .photoLibraryAsset, reference: "local-id"),
        ])])]
        XCTAssertTrue(ReEnchantedSaveFile.fileBackedReferences(in: days).isEmpty)
    }

    // MARK: rehomedDays

    func testRehomedDaysRewritesFileBackedPathsToContainer() {
        let container = URL(fileURLWithPath: "/new/container")
        let days = [day("d1", pages: [page("p1", assets: [
            fileAsset("/old/container/img.jpg"),
            BookPageMediaAsset(kind: .bundledImage, reference: "keep-me"),
        ])])]
        let rehomed = ReEnchantedSaveFile.rehomedDays(days, toContainer: container)
        let assets = rehomed[0].pages[0].mediaAssets
        XCTAssertEqual(assets[0].reference, "/new/container/img.jpg")
        // Non-file-backed assets are untouched.
        XCTAssertEqual(assets[1].reference, "keep-me")
    }

    // MARK: version + round trip

    func testCurrentVersionIsTwo() {
        XCTAssertEqual(ReEnchantedSaveFile.currentVersion, 2)
    }

    func testV2RoundTripPreservesMediaFiles() throws {
        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let save = makeSaveFile(
            days: [day("d1", pages: [page("p1", assets: [fileAsset("/old/img.jpg")])])],
            mediaFiles: ["img.jpg": bytes]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReEnchantedSaveFile.self, from: encoder.encode(save))
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.mediaFiles?["img.jpg"], bytes)
    }

    func testNilMediaFilesOmittedAndDecodesAsNil() throws {
        // A version-1 file simply lacks the mediaFiles key; encoding a nil
        // optional omits the key, so this doubles as v1-compatibility coverage.
        let save = makeSaveFile(days: [], mediaFiles: nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(save)
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("mediaFiles"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReEnchantedSaveFile.self, from: data)
        XCTAssertNil(decoded.mediaFiles)
    }
}
