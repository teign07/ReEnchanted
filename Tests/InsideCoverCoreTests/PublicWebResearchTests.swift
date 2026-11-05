import XCTest

@testable import InsideCoverCore

/// What may leave the phone as a web search. The task still needs a subject
/// and, when the reader allows it, the town; it never needs their Pages,
/// their home answers, their names, or anything a person could be found by.
final class PublicWebResearchTests: XCTestCase {
  private func fact(_ questionID: String, _ answer: String, tags: [String]) -> SelfFact {
    SelfFact(id: questionID, questionID: questionID, question: questionID, answer: answer, bookTranslation: answer,
             sensitivity: .story, usePermission: .storyOnly, tags: tags, createdAt: Date(), updatedAt: Date())
  }

  private func inputs(allowed: Bool = true) -> BookSourceInputs {
    var inputs = BookSourceInputs.empty
    inputs.allowsPersonalizedWebResearch = allowed
    inputs.selfFacts = [
      fact("name", "Rowan", tags: ["name"]),
      fact("home", "A blue house at 14 Larch Lane with my mum and the cat", tags: ["home"])
    ]
    inputs.nearbyPlaces = [
      LocalPlaceSignal(id: "books", name: "Rowan's Corner Shop", category: "shop", distanceLabel: "nearby", locality: "Belfast")
    ]
    return inputs
  }

  // MARK: - What a query may carry

  func testAPlainSubjectGoesOut() {
    XCTAssertEqual(PublicWebResearch.query("tide pools and their snails"), "tide pools and their snails")
    XCTAssertEqual(PublicWebResearch.topic("I really love beekeeping"), "beekeeping")
    XCTAssertEqual(PublicWebResearch.topic("old maps, sea charts; anything nautical"), "old maps")
  }

  func testAnythingAPersonCouldBeFoundByStaysBehind() {
    for private_ in [
      "write to rowan@example.com",
      "see https://example.com/me",
      "call 028 9024 5133",
      "54.5973, -5.9301",
      "the house on 14 Larch Lane",
      "my sister's wedding",
      "what I was diagnosed with"
    ] {
      XCTAssertNil(PublicWebResearch.query(private_), private_)
    }
    XCTAssertNil(PublicWebResearch.query("Rowan and the bees", excluding: ["Rowan"]), "a reader's name never goes out")
    XCTAssertNotNil(PublicWebResearch.query("rowan trees", excluding: ["Row"]), "a name blocks the word, not a word containing it")
  }

  /// bj: "still passing information needed to the web to complete tasks."
  /// Dates are what a history search is made of; they are not a phone number.
  func testYearsAreASubjectNotAPhoneNumber() {
    XCTAssertEqual(PublicWebResearch.topic("Victorian ghost stories 1850-1900"), "Victorian ghost stories 1850-1900")
    XCTAssertEqual(PublicWebResearch.query("harbour floods 1907 1953 2014"), "harbour floods 1907 1953 2014")
    XCTAssertNil(PublicWebResearch.query("ring 0289 0245 133"), "loose digits are still a number to ring")
  }

  func testOnlyATownGoesOutAsAPlace() {
    XCTAssertEqual(PublicWebResearch.locality("Belfast"), "Belfast")
    XCTAssertEqual(PublicWebResearch.locality("Saint-Jean-de-Luz"), "Saint-Jean-de-Luz")
    XCTAssertNil(PublicWebResearch.locality("14 Larch Lane"))
    XCTAssertNil(PublicWebResearch.locality("Flat 2, the old mill by the river behind the church"))
  }

  // MARK: - A letter's research

  func testALettersSearchesCarryTheSubjectAndTownAndNothingElse() {
    let queries = PublicWebResearch.letterQueries(interest: "I love lighthouses", inputs: inputs())
    XCTAssertEqual(queries, [
      "lighthouses Belfast",
      "lighthouses local history ecology culture",
      "Belfast local history folklore nature"
    ])
    let sent = queries.joined(separator: " ").lowercased()
    for kept in ["rowan", "larch", "blue house", "mum", "corner shop"] {
      XCTAssertFalse(sent.contains(kept), kept)
    }
  }

  func testAPrivateInterestFallsBackToAPublicSubject() {
    let queries = PublicWebResearch.letterQueries(interest: "Rowan's garden", inputs: inputs())
    XCTAssertEqual(queries.first, "ordinary wonder Belfast")
  }

  func testNothingGoesOutWhenResearchIsOff() {
    XCTAssertEqual(PublicWebResearch.letterQueries(interest: "lighthouses", inputs: inputs(allowed: false)), [])
  }
}
