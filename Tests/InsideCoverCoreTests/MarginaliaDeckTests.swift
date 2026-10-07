import XCTest
@testable import InsideCoverCore

final class MarginaliaDeckTests: XCTestCase {
  private let items: [(id: String, weight: Double)] = [
    ("cat", 3), ("lantern", 3), ("key", 3), ("holly", 2), ("ivy", 2), ("violet", 0.35), ("daisy", 0.35), ("lavender", 0.35)
  ]

  func testEveryDrawingIsDealtOnceBeforeAnyIsDealtTwice() {
    let order = MarginaliaDeck.order(items, seed: "weekly-6")
    XCTAssertEqual(order.count, items.count)
    XCTAssertEqual(Set(order), Set(items.map(\.id)))
  }

  func testTheSameBindingAlwaysDealsTheSameDeck() {
    XCTAssertEqual(MarginaliaDeck.order(items, seed: "a"), MarginaliaDeck.order(items, seed: "a"))
    XCTAssertNotEqual(MarginaliaDeck.order(items, seed: "a"), MarginaliaDeck.order(items, seed: "b"))
  }

  func testTheMonthsOwnDrawingsLeadButTheRestStillTurnUp() {
    var heavyInFirstThree = 0
    var lightFirst = 0
    var lightInFirstFour = 0
    for n in 0..<400 {
      let order = MarginaliaDeck.order(items, seed: "book-\(n)")
      heavyInFirstThree += order.prefix(3).filter { ["cat", "lantern", "key"].contains($0) }.count
      if ["violet", "daisy", "lavender"].contains(order[0]) { lightFirst += 1 }
      lightInFirstFour += order.prefix(4).filter { ["violet", "daisy", "lavender"].contains($0) }.count
    }
    XCTAssertGreaterThan(Double(heavyInFirstThree) / 400, 1.8, "the month leads: most of the first three are its own")
    XCTAssertGreaterThan(lightInFirstFour, 0, "not only the month: the herbarium still turns up")
    XCTAssertLessThan(Double(lightFirst) / 400, 0.2)
  }

  func testEveryRegularMarginaliaNameHasArtInTheAssetCatalog() {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let catalog = root.appendingPathComponent("InsideCoverApp/Assets.xcassets")
    XCTAssertEqual(Set(MarginaliaDeck.regular).count, MarginaliaDeck.regular.count, "no name twice")
    for name in MarginaliaDeck.regular {
      XCTAssertTrue(FileManager.default.fileExists(atPath: catalog.appendingPathComponent("\(name).imageset").path), "\(name) has no art")
    }
    for part in ["Ear", "Nose", "Face", "Hand", "Foot", "Boot", "BareFoot"] {
      XCTAssertFalse(MarginaliaDeck.regular.contains { $0.contains("Goblin\(part)") }, "the goblin's \(part.lowercased()) is a part, not a corner drawing")
    }
  }
}
