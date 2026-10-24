import XCTest
@testable import InsideCoverCore

/// The Gazetteer's Outer Stacks half, the Anchors the archive can stand back
/// up, and the vault that must never be overwritten because it couldn't be
/// read.
final class OuterStacksGazetteerTests: XCTestCase {

    private func anchor(
        _ id: String,
        name: String,
        room: String = "",
        fae: String = "",
        miniStory: String = "",
        rule: String = ""
    ) -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 10, created: "2026-10-20", weather: "Clear",
            moon: "waxing", season: "Stick Season", playerWords: "the good aisle", academyEcho: "",
            outerStacksRoom: room, fae: fae, miniStory: miniStory, localRule: rule,
            visitCount: 1, lastVisited: "2026-10-20"
        )
    }

    private func visit(
        _ id: String,
        anchorID: String,
        name: String,
        at seconds: TimeInterval,
        room: String = "Receipts hang from the rafters like bunting.",
        latitude: Double? = 44.1,
        longitude: Double? = -69.2
    ) -> BookDay {
        let created = Date(timeIntervalSince1970: seconds)
        let page = BookPage(
            id: id, type: .anchor, createdAt: created, promptText: name,
            context: BookPageContextSnapshot(at: created, latitude: latitude, longitude: longitude),
            metadata: [
                "anchorID": anchorID, "anchorName": name, "anchorKind": "SENSE",
                "radiusMeters": "200", "seasonShift": "Stick Season",
                "room": room, "fae": "Ledger-Moth is counting change that isn't there",
                "localRule": "Say the price out loud before you touch anything.",
                "entityMemories": "The till has started refusing pennies.",
                "anchorEmotionalRegister": "bustling, bright"
            ]
        )
        return BookDay(id: id, date: created, pages: [page])
    }

    // MARK: The door on the shelf

    func testAPlaceShowsTheRoomItGrew() {
        let entries = Gazetteer.entries(
            anchors: [anchor("a1", name: "Cigaret Shopper",
                             room: "The aisles have rearranged themselves by smell.",
                             fae: "A Sense Fae is weighing the lottery tickets",
                             miniStory: "Somebody keeps paying in buttons.",
                             rule: "Leave one coin on the counter.")],
            days: []
        )
        let door = entries.first?.door
        XCTAssertEqual(door?.room, "The aisles have rearranged themselves by smell.")
        XCTAssertEqual(door?.keeper, "A Sense Fae is weighing the lottery tickets.",
                       "the Fae line is printed as its own sentence")
        XCTAssertEqual(door?.underway, "Somebody keeps paying in buttons.")
        XCTAssertEqual(door?.rule, "Leave one coin on the counter.")
    }

    func testAPlaceWithNothingWrittenHasNoDoor() {
        let entries = Gazetteer.entries(anchors: [anchor("a1", name: "Bare")], days: [])
        XCTAssertNil(entries.first?.door)
    }

    func testAnUnwrittenRoomStillShowsItsKeeper() {
        let door = Gazetteer.door(for: anchor("a1", name: "Half", fae: "Moss-Wick is busy."))
        XCTAssertNil(door?.room)
        XCTAssertEqual(door?.keeper, "Moss-Wick is busy.")
    }

    func testASentenceIsNotPunctuatedTwice() {
        XCTAssertEqual(Gazetteer.sentence("  a Fae is busy  "), "A Fae is busy.")
        XCTAssertEqual(Gazetteer.sentence("Who's there?"), "Who's there?")
        XCTAssertEqual(Gazetteer.sentence("It said “stay.”"), "It said “stay.”")
        XCTAssertNil(Gazetteer.sentence("   "))
    }

    // MARK: Anchors the archive remembers

    func testALostAnchorComesBackFromItsKeptVisits() {
        let days = [
            visit("v1", anchorID: "user-anchor-cigaret", name: "Cigaret Shopper", at: 1_792_000_000),
            visit("v2", anchorID: "user-anchor-cigaret", name: "Cigaret Shopper", at: 1_792_090_000,
                  room: "The aisles have moved again.")
        ]
        let recovered = AnchorRecovery.recovered(from: days, missingFrom: [])
        XCTAssertEqual(recovered.count, 1)
        let anchor = recovered[0]
        XCTAssertEqual(anchor.id, "user-anchor-cigaret", "the id has to match so the kept Pages find it again")
        XCTAssertEqual(anchor.name, "Cigaret Shopper")
        XCTAssertEqual(anchor.kind, .sense)
        XCTAssertEqual(anchor.latitude, 44.1)
        XCTAssertEqual(anchor.visitCount, 2)
        XCTAssertEqual(anchor.outerStacksRoom, "The aisles have moved again.", "the newest visit knows the room")
        XCTAssertEqual(anchor.localRule, "Say the price out loud before you touch anything.")
        XCTAssertEqual(anchor.emotionalRegister, "bustling, bright")
        XCTAssertEqual(anchor.playerWords, "", "words that were never on a Page aren't invented")
    }

    func testAnAnchorStillInTheLedgerIsLeftAlone() {
        let days = [visit("v1", anchorID: "a1", name: "Kept", at: 1_792_000_000)]
        XCTAssertTrue(AnchorRecovery.recovered(from: days, missingFrom: [anchor("a1", name: "Kept")]).isEmpty)
    }

    func testAnAnchorWithNowhereToStandIsNotRebuilt() {
        let days = [visit("v1", anchorID: "a1", name: "Nowhere", at: 1_792_000_000, latitude: nil, longitude: nil)]
        XCTAssertTrue(AnchorRecovery.recovered(from: days, missingFrom: []).isEmpty)
    }

    func testAPageKeptNearbyLendsItsCoordinates() {
        var days = [visit("v1", anchorID: "a1", name: "Shop", at: 1_792_000_000, latitude: nil, longitude: nil)]
        let near = BookPage(
            id: "n1", type: .diary, createdAt: Date(timeIntervalSince1970: 1_792_100_000), promptText: "",
            context: BookPageContextSnapshot(nearbyAnchorID: "a1", latitude: 40.5, longitude: -70.5)
        )
        days.append(BookDay(id: "n1", date: near.createdAt, pages: [near]))
        XCTAssertEqual(AnchorRecovery.recovered(from: days, missingFrom: []).first?.latitude, 40.5)
    }

    func testAnUnwrittenRoomPlaceholderIsNotKeptAsTheRoom() {
        let days = [visit("v1", anchorID: "a1", name: "Shop", at: 1_792_000_000, room: AnchorRecovery.placeholderRoom)]
        XCTAssertEqual(AnchorRecovery.recovered(from: days, missingFrom: []).first?.outerStacksRoom, "")
    }

    // MARK: The vault on disk

    private func scratch() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder.appendingPathComponent("PlayerVault.json")
    }

    func testNoFileIsANewBook() throws {
        guard case .absent = PlayerVaultDisk.open(try scratch()) else { return XCTFail("expected a new Book") }
    }

    func testAGoodVaultOpens() throws {
        let url = try scratch()
        var vault = PlayerVaultData()
        vault.anchors = [anchor("a1", name: "Cigaret Shopper")]
        try JSONEncoder().encode(vault).write(to: url)
        guard case .opened(let opened) = PlayerVaultDisk.open(url) else { return XCTFail("a good vault didn't open") }
        XCTAssertEqual(opened.anchors.map(\.name), ["Cigaret Shopper"])
    }

    /// A field written by a newer build (here, an enum case this build has
    /// never heard of) used to fail the whole decode, and the blank vault that
    /// followed was saved over the reader's Anchors.
    func testOneDamagedFieldDoesNotTakeTheAnchorsWithIt() throws {
        let url = try scratch()
        var vault = PlayerVaultData()
        vault.anchors = [anchor("a1", name: "Cigaret Shopper")]
        vault.tutorSeen = ["one"]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(vault)) as? [String: Any])
        object["chosenQuill"] = ["kind": "a-quill-from-the-future", "nonsense": true]
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        guard case .salvaged(let opened, let damaged) = PlayerVaultDisk.open(url) else {
            return XCTFail("a vault with one bad field should be salvaged")
        }
        XCTAssertEqual(opened.anchors.map(\.name), ["Cigaret Shopper"])
        XCTAssertEqual(opened.tutorSeen, ["one"])
        XCTAssertNil(opened.chosenQuill)
        XCTAssertEqual(damaged, ["chosenQuill"])
    }

    func testOneStrangeAnchorDoesNotTakeTheOthers() throws {
        let url = try scratch()
        var vault = PlayerVaultData()
        vault.anchors = [anchor("a1", name: "Cigaret Shopper"), anchor("a2", name: "The Waiting Tree")]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(vault)) as? [String: Any])
        var anchors = try XCTUnwrap(object["anchors"] as? [[String: Any]])
        anchors[1]["kind"] = "TELEPORT"
        object["anchors"] = anchors
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        guard case .salvaged(let opened, _) = PlayerVaultDisk.open(url) else { return XCTFail("expected a salvage") }
        XCTAssertEqual(opened.anchors.map(\.name), ["Cigaret Shopper"])
    }

    func testNonsenseIsUndecodableNotNew() throws {
        let url = try scratch()
        try Data("not a vault".utf8).write(to: url)
        guard case .undecodable = PlayerVaultDisk.open(url) else { return XCTFail("garbage must not read as no file") }
    }

    func testSettingAsideKeepsTheOriginal() throws {
        let url = try scratch()
        try Data("original".utf8).write(to: url)
        let aside = try XCTUnwrap(PlayerVaultDisk.setAside(url, now: Date(timeIntervalSince1970: 1_792_000_000)))
        XCTAssertEqual(aside.lastPathComponent, "PlayerVault.set-aside-1792000000.json")
        XCTAssertEqual(try Data(contentsOf: aside), Data("original".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "a readable original is copied, not moved")
    }
}
