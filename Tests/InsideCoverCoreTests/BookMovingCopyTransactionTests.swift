import XCTest

@testable import InsideCoverCore

/// The moving copy replaces a whole Book on disk. Nothing here may leave the
/// reader with less than the Book they had: a bad copy is refused before an
/// original moves, and a failure or an interruption puts the original back.
final class BookMovingCopyTransactionTests: XCTestCase {
  private var root: URL!
  private let files = FileManager.default

  override func setUpWithError() throws {
    root = files.temporaryDirectory.appendingPathComponent("moving-copy-\(UUID().uuidString)", isDirectory: true)
    try files.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? files.removeItem(at: root)
  }

  // MARK: - Helpers

  private func folder(_ name: String, _ tree: [String: String]) throws -> URL {
    let url = root.appendingPathComponent(name, isDirectory: true)
    try files.createDirectory(at: url, withIntermediateDirectories: true)
    for (path, text) in tree {
      let file = url.appendingPathComponent(path)
      try files.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(text.utf8).write(to: file)
    }
    return url
  }

  private func tree(_ url: URL) throws -> [String: String] {
    var result: [String: String] = [:]
    guard let walker = files.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { return result }
    let base = url.resolvingSymlinksInPath().path
    for case let item as URL in walker where (try item.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
      let path = String(item.resolvingSymlinksInPath().path.dropFirst(base.count + 1))
      result[path] = try String(contentsOf: item, encoding: .utf8)
    }
    return result
  }

  private var recovery: URL { root.appendingPathComponent("Recovery", isDirectory: true) }

  private let book = [
    "Book.sqlite": "my pages",
    "Photos/rain.jpg": "rain",
    "Library/Preferences/app.plist": "this phone's settings",
    "Models/gemma.bin": "weights"
  ]

  private let copy = [
    "Book.sqlite": "moved pages",
    "Photos/heron.jpg": "heron",
    "Library/Preferences/app.plist": "the old phone's settings",
    "Library/Caches/old.bin": "cache"
  ]

  private struct Stop: Error {}

  // MARK: - A good copy

  func testACopyReplacesTheBookAndLeavesWhatThisPhoneOwns() throws {
    let destination = try folder("Book", book)
    let source = try folder("Copy", copy)
    var committed = false
    try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination, keeping: ["Library/Preferences", "Models"])],
      recoveryURL: recovery, context: Data("old".utf8),
      commit: { committed = true }, restoreContext: { _ in XCTFail("nothing to roll back") })

    XCTAssertTrue(committed)
    XCTAssertEqual(try tree(destination), [
      "Book.sqlite": "moved pages",
      "Photos/heron.jpg": "heron",
      "Library/Preferences/app.plist": "this phone's settings",
      "Library/Caches/old.bin": "cache",
      "Models/gemma.bin": "weights"
    ], "the old Book's own files go; the phone's preferences and model stay")
    XCTAssertFalse(files.fileExists(atPath: recovery.path), "a finished move leaves no recovery behind")
  }

  // MARK: - A bad copy is refused before anything moves

  func testAMissingFolderIsRefusedBeforeTheBookIsTouched() throws {
    let destination = try folder("Book", book)
    let missing = root.appendingPathComponent("Copy/documents", isDirectory: true)
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: missing, destination: destination)], recoveryURL: recovery, context: Data(),
      commit: { XCTFail("must not commit") }, restoreContext: { _ in }))
    XCTAssertEqual(try tree(destination), book)
    XCTAssertFalse(files.fileExists(atPath: recovery.path))
  }

  func testALinkInTheCopyIsRefusedBeforeTheBookIsTouched() throws {
    let destination = try folder("Book", book)
    let source = try folder("Copy", copy)
    try files.createSymbolicLink(at: source.appendingPathComponent("Photos/elsewhere"), withDestinationURL: URL(fileURLWithPath: "/etc"))
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination)], recoveryURL: recovery, context: Data(),
      commit: { XCTFail("must not commit") }, restoreContext: { _ in }))
    XCTAssertEqual(try tree(destination), book)
  }

  func testAnUnfinishedRecoveryBlocksANewMove() throws {
    let destination = try folder("Book", book)
    let source = try folder("Copy", copy)
    try files.createDirectory(at: recovery, withIntermediateDirectories: true)
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination)], recoveryURL: recovery, context: Data(),
      commit: {}, restoreContext: { _ in }))
    XCTAssertEqual(try tree(destination), book)
  }

  // MARK: - A failure puts the Book back

  func testAFailureHalfwayPutsTheBookBack() throws {
    let destination = try folder("Book", book)
    let documents = try folder("Documents", ["Notes/today.txt": "today"])
    let source = try folder("Copy", copy)
    let sourceDocuments = try folder("CopyDocuments", ["Notes/old.txt": "old"])
    var restored: Data?
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination, keeping: ["Models"]),
       .init(source: sourceDocuments, destination: documents)],
      recoveryURL: recovery, context: Data("old settings".utf8),
      commit: { XCTFail("must not commit") }, restoreContext: { restored = $0 },
      afterReplacement: { index in if index == 3 { throw Stop() } })) { XCTAssertTrue($0 is Stop) }
    XCTAssertEqual(try tree(destination), book)
    XCTAssertEqual(try tree(documents), ["Notes/today.txt": "today"])
    XCTAssertEqual(restored, Data("old settings".utf8), "the old settings go back too")
    XCTAssertFalse(files.fileExists(atPath: recovery.path))
  }

  func testSettingsThatWontSavePutTheBookBack() throws {
    let destination = try folder("Book", book)
    let source = try folder("Copy", copy)
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination, keeping: ["Models"])],
      recoveryURL: recovery, context: Data(), commit: { throw Stop() }, restoreContext: { _ in }))
    XCTAssertEqual(try tree(destination), book)
  }

  /// The phone stopped mid-move (killed, out of battery). The disk is left
  /// exactly as it was at that moment; the next launch's recovery puts the
  /// original Book back.
  func testAnInterruptedMoveIsPutBackOnTheNextLaunch() throws {
    let destination = try folder("Book", book)
    let source = try folder("Copy", copy)
    let frozenBook = root.appendingPathComponent("frozen-book", isDirectory: true)
    let frozenRecovery = root.appendingPathComponent("frozen-recovery", isDirectory: true)
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination, keeping: ["Models"])],
      recoveryURL: recovery, context: Data("old settings".utf8),
      commit: {}, restoreContext: { _ in },
      afterReplacement: { index in
        guard index == 2 else { return }
        // What the disk held when the power went.
        try self.files.copyItem(at: destination, to: frozenBook)
        try self.files.copyItem(at: self.recovery, to: frozenRecovery)
        throw Stop()
      }))
    try files.removeItem(at: destination)
    try files.moveItem(at: frozenBook, to: destination)
    try files.moveItem(at: frozenRecovery, to: recovery)
    XCTAssertNotEqual(try tree(destination), book, "the crash left a half-moved Book")

    var restored: Data?
    try BookMovingCopyTransaction.recover(at: recovery, restoreContext: { restored = $0 })
    XCTAssertEqual(try tree(destination), book)
    XCTAssertEqual(restored, Data("old settings".utf8))
    XCTAssertFalse(files.fileExists(atPath: recovery.path))
  }

  /// Interrupted again, this time while the original was going back: the
  /// next launch still finds a whole original to restore.
  func testARollbackInterruptedPartwayStillFinishes() throws {
    let destination = try folder("Book", book)
    let source = try folder("Copy", copy)
    let frozenBook = root.appendingPathComponent("frozen-book", isDirectory: true)
    let frozenRecovery = root.appendingPathComponent("frozen-recovery", isDirectory: true)
    XCTAssertThrowsError(try BookMovingCopyTransaction.perform(
      [.init(source: source, destination: destination, keeping: ["Models"])],
      recoveryURL: recovery, context: Data(), commit: {}, restoreContext: { _ in },
      afterReplacement: { index in
        guard index == 2 else { return }
        try self.files.copyItem(at: destination, to: frozenBook)
        try self.files.copyItem(at: self.recovery, to: frozenRecovery)
        throw Stop()
      }))
    try files.removeItem(at: destination)
    try files.moveItem(at: frozenBook, to: destination)
    try files.moveItem(at: frozenRecovery, to: recovery)
    // The first rollback got as far as taking the moved-in database away and
    // stopped before its original went back.
    try files.removeItem(at: destination.appendingPathComponent("Book.sqlite"))

    try BookMovingCopyTransaction.recover(at: recovery, restoreContext: { _ in })
    XCTAssertEqual(try tree(destination), book)
  }

  func testRecoveryWithNothingPendingDoesNothing() throws {
    let destination = try folder("Book", book)
    try BookMovingCopyTransaction.recover(at: recovery, restoreContext: { _ in XCTFail("nothing pending") })
    XCTAssertEqual(try tree(destination), book)
  }
}
