import XCTest
@testable import InsideCoverCore

/// The weekly cover a braid showed came up broken: it had been saved by absolute path, and iOS moves
/// the app's folder. A saved path that no longer exists is looked for in today's folder.
final class MediaPathRelocationTests: XCTestCase {
    private var support: URL!

    override func setUpWithError() throws {
        support = FileManager.default.temporaryDirectory.appendingPathComponent("relocate-\(UUID().uuidString)", isDirectory: true)
        let weekly = support.appendingPathComponent("com.example.app/WeeklyIssues", isDirectory: true)
        try FileManager.default.createDirectory(at: weekly, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: weekly.appendingPathComponent("Weekly-Issue-6-Card.png"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: support)
    }

    func testAWeeklyCoverSavedBeforeTheFolderMovedIsFoundWhereItIsNow() {
        let stale = "/var/mobile/Containers/Data/Application/OLD-UUID/Library/Application Support/com.example.app/WeeklyIssues/Weekly-Issue-6-Card.png"
        let found = MonthlyIssueMediaPath.relocatingMissing(stale, supportDirectory: support)
        XCTAssertTrue(found.hasSuffix("com.example.app/WeeklyIssues/Weekly-Issue-6-Card.png"), found)
        XCTAssertTrue(FileManager.default.fileExists(atPath: found))
        XCTAssertNotEqual(found, stale)
    }

    func testThroughTheDecodeSeamToo() {
        let stale = "/var/mobile/Containers/Data/Application/OLD-UUID/Library/Application Support/com.example.app/WeeklyIssues/Weekly-Issue-6-Card.png"
        XCTAssertNotEqual(MonthlyIssueMediaPath.resolving(stale, supportDirectory: support), stale)
    }

    /// A Book moved into the renamed app keeps photo paths that name the old
    /// bundle ID's folder; the moving copy puts the files under the new one.
    func testAPhotoUnderTheOldBundleFolderIsFoundUnderTheRenamedApp() throws {
        let renamed = support.appendingPathComponent("app.reenchanted.book/CameraFirstPhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: renamed, withIntermediateDirectories: true)
        try Data([4]).write(to: renamed.appendingPathComponent("first.jpg"))
        let stale = "/var/mobile/Containers/Data/Application/OLD-UUID/Library/Application Support/com.openclaw.enchantify.insidecover/CameraFirstPhotos/first.jpg"
        let found = MonthlyIssueMediaPath.relocatingMissing(stale, supportDirectory: support, bundleID: "app.reenchanted.book")
        XCTAssertEqual(found, renamed.appendingPathComponent("first.jpg").resolvingSymlinksInPath().standardizedFileURL.path)
        let unknown = "/old/Library/Application Support/com.someone.else/CameraFirstPhotos/first.jpg"
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing(unknown, supportDirectory: support, bundleID: "app.reenchanted.book"), unknown,
                       "only the app's own former bundle IDs are mapped")
    }

    func testAFileInTheOldSharedContainerIsFoundInTodaysContainer() throws {
        let group = support.appendingPathComponent("group-container", isDirectory: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try Data([5]).write(to: group.appendingPathComponent("kept-voice.m4a"))
        let stale = "/private/var/mobile/Containers/Shared/AppGroup/12345678-1234-1234-1234-123456789ABC/kept-voice.m4a"
        let found = MonthlyIssueMediaPath.relocatingMissing(stale, supportDirectory: support, groupContainer: group)
        XCTAssertEqual(found, group.appendingPathComponent("kept-voice.m4a").resolvingSymlinksInPath().standardizedFileURL.path)
        let escape = "/private/var/mobile/Containers/Shared/AppGroup/12345678-1234-1234-1234-123456789ABC/../../secret"
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing(escape, supportDirectory: support, groupContainer: group), escape)
    }

    func testAPathThatStillExistsIsLeftAlone() {
        let real = support.appendingPathComponent("com.example.app/WeeklyIssues/Weekly-Issue-6-Card.png").path
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing(real, supportDirectory: support), real)
    }

    func testAFileThatIsNotThereAnywhereStaysMissingRatherThanInventingOne() {
        let gone = "/old/Library/Application Support/com.example.app/WeeklyIssues/Weekly-Issue-99-Card.png"
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing(gone, supportDirectory: support), gone)
    }

    func testNothingCanEscapeTheFolderItIsLookedUpIn() {
        let escape = "/old/Library/Application Support/../../etc/passwd"
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing(escape, supportDirectory: support), escape)
        let dotted = "/old/Library/Application Support/com.example.app/WeeklyIssues/../../../secret.png"
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing(dotted, supportDirectory: support), dotted)
    }

    func testARelativeOrBundledReferenceIsNotTouched() {
        XCTAssertEqual(MonthlyIssueMediaPath.relocatingMissing("MarginaliaRaven", supportDirectory: support), "MarginaliaRaven")
    }
}

final class BraidDisplayableMediaTests: XCTestCase {
    private func asset(_ kind: BookPageMediaAsset.Kind, _ ref: String) -> BookPageMediaAsset {
        BookPageMediaAsset(kind: kind, reference: ref, caption: "c", sourceID: "s", metadata: [:])
    }

    func testAMissingFileIsLeftOutSoNothingShowsBroken() {
        let shown = BookPageMediaAsset.displayable(
            [asset(.renderedImageFile, "/old/Library/Application Support/x/WeeklyIssues/gone.png"),
             asset(.renderedImageFile, "/here/ok.png"),
             asset(.bundledImage, "MarginaliaRaven")],
            fileExists: { $0 == "/here/ok.png" || $0 == "MarginaliaRaven" })
        XCTAssertEqual(shown.map(\.reference), ["/here/ok.png", "MarginaliaRaven"])
    }

    func testTheSameImageIsShownOnceAndTheDayCapsItsPictures() {
        let many = (1...12).map { asset(.photoLibraryAsset, "photo-\($0)") } + [asset(.photoLibraryAsset, "photo-1")]
        let shown = BookPageMediaAsset.displayable(many, limit: 8)
        XCTAssertEqual(shown.count, 8)
        XCTAssertEqual(Set(shown.map(\.reference)).count, 8)
        XCTAssertEqual(BookPageMediaAsset.displayable([asset(.photoLibraryAsset, "a"), asset(.photoLibraryAsset, "a")]).count, 1)
    }

    func testSoundIsNotAPicture() {
        XCTAssertTrue(BookPageMediaAsset.displayable([asset(.audioFile, "/a.m4a")], fileExists: { _ in true }).isEmpty)
    }
}
