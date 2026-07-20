import XCTest
@testable import InsideCoverCore

final class PublicMarginsTests: XCTestCase {
    func testBothDoorsAreClosedByDefaultAndIndependent() {
        var preferences = PublicMarginsPreferences()

        XCTAssertFalse(preferences.acceptsIncomingPages)
        XCTAssertFalse(preferences.offersOutgoingContributions)

        preferences.acceptsIncomingPages = true
        XCTAssertTrue(preferences.acceptsIncomingPages)
        XCTAssertFalse(preferences.offersOutgoingContributions)

        preferences = PublicMarginsPreferences()
        preferences.offersOutgoingContributions = true
        XCTAssertFalse(preferences.acceptsIncomingPages)
        XCTAssertTrue(preferences.offersOutgoingContributions)
    }

    func testPublicSentenceIsExactCollapsedText() {
        XCTAssertEqual(
            PublicMarginsText.preparedSentence(from: "  I noticed\nthat the rain had a silver edge.  "),
            "I noticed that the rain had a silver edge."
        )
    }

    func testPublicSentenceRejectsURLsAndOversizedText() {
        XCTAssertNil(PublicMarginsText.preparedSentence(from: "See https://example.com"))
        XCTAssertNil(PublicMarginsText.preparedSentence(from: String(repeating: "x", count: 221)))
    }

    func testContributionEnvelopeContainsOnlyExplicitPublicFields() throws {
        let request = PublicMarginsContributionRequest(
            requestID: "random-request",
            eventID: "daily-souvenir",
            kind: .souvenir,
            text: "A one-sentence souvenir.",
            category: nil,
            choiceID: nil,
            confirmedAt: "2026-07-18T20:00:00Z",
            consent: .init(publicDisplay: true, moderation: true)
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), ["requestID", "eventID", "kind", "text", "confirmedAt", "consent"])
        XCTAssertNil(object["pageID"])
        XCTAssertNil(object["userID"])
        XCTAssertNil(object["archive"])
        XCTAssertNil(object["belief"])
    }

    func testSnapshotCarriesOneControlledQuietChoicePoll() throws {
        let data = Data("""
        {
          "generatedAt": "2026-07-19T12:00:00Z",
          "contributionCount": 2,
          "broadcasts": [],
          "creatorPosts": [],
          "souvenirs": [],
          "tallies": [{"choiceID":"look-again","label":"Look again","count":2}],
          "choicePoll": {
            "id": "what-the-page-awakened",
            "question": "What did a Page leave you wanting to do?",
            "options": [{"id":"look-again","label":"Look again","count":2}]
          }
        }
        """.utf8)

        let snapshot = try JSONDecoder().decode(PublicMarginsSnapshot.self, from: data)
        XCTAssertEqual(snapshot.choicePoll?.question, "What did a Page leave you wanting to do?")
        XCTAssertEqual(snapshot.choicePoll?.options.first?.label, "Look again")
        XCTAssertEqual(snapshot.choicePoll?.options.first?.count, 2)
    }

    func testCreatorPageRequiresIncomingSnapshot() {
        let now = Date(timeIntervalSince1970: 1_768_780_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        let pages = PublicMarginsCreatorPageSourceAdapter().candidates(
            for: day,
            context: .make(for: day),
            inputs: BookSourceInputs(),
            now: now
        )

        XCTAssertTrue(pages.isEmpty)
    }

    func testCreatorPageStaysDormantEvenWhenLegacySnapshotContainsAPost() {
        let now = Date(timeIntervalSince1970: 1_768_780_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs()
        inputs.publicMargins = PublicMarginsSnapshot(
            generatedAt: "2026-01-18T12:00:00Z",
            contributionCount: 0,
            broadcasts: [],
            creatorPosts: [
                PublicMarginsBroadcast(
                    id: "post-1",
                    text: "Look twice at the ordinary thing.",
                    authorName: "A Noticer",
                    authorUsername: "noticer",
                    authorAvatarURL: nil,
                    permalink: "https://x.com/noticer/status/post-1",
                    createdAt: "2026-01-18T11:30:00Z"
                )
            ],
            souvenirs: [],
            tallies: []
        )

        let pages = PublicMarginsCreatorPageSourceAdapter().candidates(
            for: day,
            context: .make(for: day),
            inputs: inputs,
            now: now
        )

        XCTAssertTrue(pages.isEmpty)
    }

    func testCommunityPageIgnoresLegacyBroadcasts() {
        let now = Date(timeIntervalSince1970: 1_768_780_800)
        let day = BookDay(id: BookDay.id(for: now), date: now, pages: [])
        var inputs = BookSourceInputs()
        inputs.publicMargins = PublicMarginsSnapshot(
            generatedAt: "2026-01-18T12:00:00Z",
            contributionCount: 0,
            broadcasts: [
                PublicMarginsBroadcast(
                    id: "legacy-broadcast",
                    text: "A social post that must not enter the Book.",
                    authorName: "Legacy",
                    authorUsername: "legacy",
                    authorAvatarURL: nil,
                    permalink: "https://x.com/legacy/status/legacy-broadcast",
                    createdAt: "2026-01-18T11:30:00Z"
                )
            ],
            creatorPosts: [],
            souvenirs: [],
            tallies: []
        )

        XCTAssertTrue(PublicMarginsCommunityPageSourceAdapter().candidates(
            for: day,
            context: .make(for: day),
            inputs: inputs,
            now: now
        ).isEmpty)
    }
}
