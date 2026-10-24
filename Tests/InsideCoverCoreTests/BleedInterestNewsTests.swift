import XCTest
@testable import InsideCoverCore

final class BleedInterestNewsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_080_000)
    private let url = URL(string: "https://publisher.example/news/ai-field-test")!
    private let detail = "The research group released a small AI model for inspecting damaged bridge surfaces. Its field test compared the system with the group's earlier instrument under the same lighting and camera position. The report names the test conditions and makes the measurements available. The team says that the limited field result does not establish performance on other materials or in rain. The next test will use a different site."

    private var candidate: BleedNewsCandidate {
        BleedNewsCandidate(headline: "Researchers released a small AI model for bridge inspections", url: url, sourceName: "Field Notes")
    }

    private func article(age: TimeInterval = 3600, headline: String? = nil, url: URL? = nil) -> BleedNewsArticle {
        BleedNewsArticle(headline: headline ?? candidate.headline, url: url ?? self.url,
                         sourceName: "Field Notes", publishedAt: now.addingTimeInterval(-age), text: detail)
    }

    private var brief: BleedColumnBrief {
        BleedColumnBrief(id: "interest-desk", title: "Worth a look: artificial intelligence", byline: "Penny",
                         composedBody: "", packet: "Research pending", maxTokens: 260,
                         storyID: "interest:artificial intelligence", researchQuery: "artificial intelligence")
    }

    func testSearchUsesNewsAndSevenDayFilterRatherThanInstantAnswers() throws {
        let query = try XCTUnwrap(BleedInterestNewsDesk.searchURL(for: "artificial intelligence & art"))
        let components = try XCTUnwrap(URLComponents(url: query, resolvingAgainstBaseURL: false))
        XCTAssertEqual(query.path, "/news/search")
        XCTAssertEqual(components.queryItems?.first { $0.name == "q" }?.value, "artificial intelligence & art")
        XCTAssertEqual(components.queryItems?.first { $0.name == "qft" }?.value, "interval=\"7\"")
    }

    func testCandidateParserKeepsPublisherLinksAndRejectsDefinitions() {
        let html = """
        <div class="news-card newsitem" data-title="Researchers released a small AI model" data-url="https://publisher.example/launch?utm_source=search" data-author="Field &amp; Notes"></div>
        <div data-title="What is artificial intelligence?" class="news-card" data-url="https://encyclopedia.example/ai"></div>
        <div class="news-card" data-title="Researchers released a small AI model" data-url="https://publisher.example/launch?utm_source=other"></div>
        <div class="news-card" data-title="New AI discussion" data-url="https://www.reddit.com/r/ai/comments/one"></div>
        """
        let candidates = BleedInterestNewsDesk.candidates(from: html, interest: "artificial intelligence")
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].sourceName, "Field & Notes")
        XCTAssertEqual(candidates[0].url.host, "publisher.example")
    }

    func testReadsPublicationDateAndActualArticleParagraphs() throws {
        let html = """
        <meta content="2026-10-14T10:00:00Z" property="article:published_time">
        <meta property="og:title" content="Researchers released a small AI model">
        <meta property="og:site_name" content="Field Notes">
        <article><p>\(detail)</p></article>
        """
        let found = try XCTUnwrap(BleedInterestNewsDesk.article(from: html, candidate: candidate, resolvedURL: url))
        XCTAssertEqual(found.headline, "Researchers released a small AI model")
        XCTAssertEqual(found.text, detail)
        XCTAssertEqual(found.publishedAt, BleedInterestNewsDesk.publicationDate("2026-10-14T10:00:00Z"))
    }

    func testReadsStructuredArticleBodyWithoutDependingOnPageMarkup() throws {
        let data = try JSONSerialization.data(withJSONObject: ["@graph": [[
            "@type": "NewsArticle", "headline": candidate.headline,
            "datePublished": "2026-10-14T10:00:00.000Z", "articleBody": detail
        ]]])
        let html = "<script type='application/ld+json'>\(String(data: data, encoding: .utf8)!)</script>"
        let found = try XCTUnwrap(BleedInterestNewsDesk.article(from: html, candidate: candidate, resolvedURL: url))
        XCTAssertEqual(found.text, detail)
        XCTAssertEqual(found.headline, candidate.headline)
    }

    func testLastModifiedDateCannotMakeAnOldDefinitionNews() {
        let html = """
        <meta property="og:title" content="Artificial intelligence: a definition">
        <script type="application/ld+json">{"@type":"NewsArticle","dateModified":"2026-10-14T10:00:00Z"}</script>
        <article><p>\(detail)</p></article>
        """
        XCTAssertNil(BleedInterestNewsDesk.article(from: html, candidate: candidate, resolvedURL: url))
    }

    func testHeadlineAndSearchSnippetCannotSubstituteForArticleEvidence() {
        let html = """
        <meta property="article:published_time" content="2026-10-14T10:00:00Z">
        <meta name="description" content="A new model launched. Subscribe to read the full article.">
        """
        XCTAssertNil(BleedInterestNewsDesk.article(from: html, candidate: candidate, resolvedURL: url))
    }

    func testUndatedArticleIsRejectedEvenWhenSearchSaysRecent() {
        XCTAssertNil(BleedInterestNewsDesk.article(from: "<article><p>\(detail)</p></article>", candidate: candidate, resolvedURL: url))
    }

    func testSelectionRejectsOldFutureUnrelatedAndAlreadyPrintedArticles() {
        let repeated = article(url: URL(string: url.absoluteString + "?utm_source=new#part")!)
        var unrelated = article()
        unrelated.headline = "A new pie won the village contest"
        unrelated.text = String(repeating: "The pastry contest had three judges and a table of pies. ", count: 10)
        let chosen = BleedInterestNewsDesk.choose(
            from: [article(age: 8 * 86_400), article(age: -3600), unrelated, repeated],
            interest: "artificial intelligence", previouslyPrintedURLs: [url.absoluteString], now: now)
        XCTAssertNil(chosen)
    }

    func testAIAbbreviationCanMatchTheFullInterest() {
        XCTAssertNotNil(BleedInterestNewsDesk.choose(from: [article()], interest: "artificial intelligence",
                                                    previouslyPrintedURLs: [], now: now))
    }

    func testCurrentDefinitionStillCannotBecomeAColumn() {
        XCTAssertNil(BleedInterestNewsDesk.choose(from: [article(headline: "What is artificial intelligence?")],
            interest: "artificial intelligence", previouslyPrintedURLs: [], now: now))
    }

    func testStockTipsDoNotCrowdOutActualInterestNews() {
        let tip = article(headline: "Better Artificial Intelligence Stock for 2026: Company A vs Company B")
        XCTAssertNil(BleedInterestNewsDesk.choose(from: [tip], interest: "artificial intelligence",
                                                 previouslyPrintedURLs: [], now: now))
        var finance = tip
        finance.text += " These investing stocks have different risks."
        XCTAssertNotNil(BleedInterestNewsDesk.choose(from: [finance], interest: "investing",
                                                    previouslyPrintedURLs: [], now: now))
    }

    func testSelectedArticleOwnsHeadlinePacketSourceAndRevision() {
        let selected = BleedInterestNewsDesk.setting(brief, with: article())
        XCTAssertEqual(selected.title, candidate.headline)
        XCTAssertEqual(selected.newsURL, url.absoluteString)
        XCTAssertTrue(selected.packet.contains(detail))
        XCTAssertTrue(selected.packet.contains("ONE SELECTED NEWS ARTICLE"))
        XCTAssertFalse(selected.packet.contains("{{CLIPPINGS}}"))
        XCTAssertTrue(selected.byline.contains("Field Notes"))
    }

    func testCopyDeskRejectsAnAccurateDefinitionInsteadOfTheSelectedNews() {
        let selected = BleedInterestNewsDesk.setting(brief, with: article())
        let generic = "Artificial intelligence is the ability of machines to learn and solve problems. It has applications in many fields and continues to evolve. Researchers are exploring its possibilities and limitations."
        XCTAssertFalse(BleedCopyDesk.feedback(prose: generic, brief: selected).isEmpty)
        let specific = "Researchers released a small AI model for inspecting damaged bridge surfaces, Field Notes reports. The test kept the lighting and camera position fixed.\n\nThe useful detail is the boundary of the finding: the team has not established performance on other materials or in rain. Its next test moves to another site."
        XCTAssertTrue(BleedCopyDesk.feedback(prose: specific, brief: selected).isEmpty)
    }

    func testNewsURLSurvivesThePrintedRecordForRepeatPrevention() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pressTime = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 8))!
        let day = BookDay(id: "2026-10-15", date: pressTime, pages: [])
        let announcement = try XCTUnwrap(TheBleedEditionBuilder.announcementSurface(
            for: day, inputs: .empty, now: pressTime, calendar: calendar))
        let selected = BleedInterestNewsDesk.setting(brief, with: article())
        let paper = TheBleedEditionBuilder.preparedCopy(of: announcement, body: "The column", interestSources: url.absoluteString,
            columns: [(selected, "The column")], printedAt: pressTime)
        let record = try XCTUnwrap(BleedPrintRecord.decode(paper.payload.metadata[BleedPrintRecord.metadataKey]))
        XCTAssertEqual(record.items.first?.newsURL, url.absoluteString)
        XCTAssertEqual(record.pressMemory.items.first?.newsURL, url.absoluteString)
    }

    func testLegacyRecordsDecodeWithoutNewsURLs() throws {
        let record = BleedPrintRecord.decode(#"{"slotID":"old","printedAt":0,"items":[{"storyID":"interest:ai","revision":"old","title":"AI","body":"Old column","sourcePageIDs":[]}]}"#)
        XCTAssertEqual(record?.items.count, 1)
        XCTAssertNil(record?.items.first?.newsURL)
    }

    func testNewsFeedResolvesPublisherLinksWithoutHTMLCardAttributes() throws {
        let html = """
        <rss><channel><item>
          <title><![CDATA[Researchers released an AI model &amp; field results]]></title>
          <link><![CDATA[https://www.bing.com/news/apiclick.aspx?ref=feed&amp;url=https%3A%2F%2Fpublisher.example%2Ffield-results%3Futm_source%3Dfeed]]></link>
          <source>Field Notes</source>
        </item><item>
          <title>What is artificial intelligence?</title><link>https://publisher.example/definition</link>
        </item></channel></rss>
        """
        let found = BleedInterestNewsDesk.candidates(from: html, interest: "artificial intelligence")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.headline, "Researchers released an AI model & field results")
        XCTAssertEqual(found.first?.url.host, "publisher.example")
        XCTAssertEqual(found.first?.sourceName, "Field Notes")
        XCTAssertEqual(found.first.map { BleedInterestNewsDesk.canonicalURL($0.url) }, "https://publisher.example/field-results")
        let feedURL = try XCTUnwrap(BleedInterestNewsDesk.feedURL(for: "sailing"))
        XCTAssertTrue(feedURL.absoluteString.contains("format=rss"))
    }

    func testExplicitPublicationTimeAndArticleBodyMarkupAreReadable() throws {
        let html = """
        <meta property="og:title" content="Researchers released a small AI model">
        <time datetime="2026-10-14T10:00:00Z" itemprop="datePublished"></time>
        <div class="story" itemprop="articleBody"><p>\(detail)</p></div>
        """
        let found = try XCTUnwrap(BleedInterestNewsDesk.article(from: html, candidate: candidate, resolvedURL: url))
        XCTAssertEqual(found.text, detail)
        XCTAssertEqual(found.publishedAt, BleedInterestNewsDesk.publicationDate("2026-10-14T10:00:00Z"))
    }

    func testResearchedArticleHasAnAttributedFallbackIfTheWriterFails() throws {
        let selected = BleedInterestNewsDesk.setting(brief, with: article())
        let fallback = try XCTUnwrap(selected.fallbackBody)
        let excerpt = detail.split(whereSeparator: \.isWhitespace).prefix(25).joined(separator: " ")
        XCTAssertTrue(fallback.contains("Field Notes"))
        XCTAssertTrue(fallback.contains(excerpt))
        XCTAssertFalse(fallback.contains("{{CLIPPINGS}}"))
        XCTAssertEqual(selected.newsURL, url.absoluteString)
    }

    func testResearchedArticleRetainsItsSeatWhenCanonicalNewsFillsThePaper() {
        let authored = (0..<10).map { index in
            BleedColumnBrief(id: "authored-\(index)", title: "Academy \(index)", byline: "A witness",
                composedBody: "An authored incident.", packet: "", maxTokens: 0, storyID: "academy:\(index)")
        }
        let selected = BleedIssueCurator.select(from: authored + [BleedInterestNewsDesk.setting(brief, with: article())],
                                               kind: .morning, history: [])
        XCTAssertEqual(selected.filter { $0.id == "interest-desk" }.count, 1)
        XCTAssertEqual(selected.filter { $0.id.hasPrefix("authored-") }.count, authored.count)
    }

    func testOnlyOneResearchedInterestArticleFitsThePaper() {
        var second = BleedInterestNewsDesk.setting(brief, with: article())
        second.storyID = "interest:second"
        let selected = BleedIssueCurator.select(from: [BleedInterestNewsDesk.setting(brief, with: article()), second],
                                               kind: .morning, history: [])
        XCTAssertEqual(selected.filter { $0.id == "interest-desk" }.count, 1)
    }

    func testInterestRetryKeepsEveryPrintedColumnAndAddsOnlyTheArticle() {
        let printed = [
            BleedColumnBrief(id: "front-page", title: "Yesterday", byline: "Penny", composedBody: "The original front page.", packet: "", maxTokens: 0),
            BleedColumnBrief(id: "assignment", title: "Your Assignment", byline: "Penny", composedBody: "The original dare.", packet: "", maxTokens: 0),
            BleedColumnBrief(id: "diversion", title: "Puzzle", byline: "Penny", composedBody: "The original puzzle.", packet: "", maxTokens: 0)
        ]
        let added = TheBleedEditionBuilder.addingInterestBrief(BleedInterestNewsDesk.setting(brief, with: article()), to: printed)
        XCTAssertEqual(added.filter { $0.id != "interest-desk" }, printed)
        XCTAssertEqual(added.map(\.id), ["front-page", "assignment", "interest-desk", "diversion"])
        XCTAssertEqual(TheBleedEditionBuilder.addingInterestBrief(nil, to: printed), printed)
        XCTAssertEqual(TheBleedEditionBuilder.addingInterestBrief(BleedInterestNewsDesk.setting(brief, with: article()), to: added), added)
    }

    func testInterestPlanIncludesTaggedFactsAndSkipsForbiddenAndNonInterestFacts() {
        func fact(_ id: String, _ answer: String, tags: [String], permission: SelfFactUsePermission = .quoteAllowed) -> SelfFact {
            SelfFact(id: id, questionID: id, question: "An interest?", answer: answer, bookTranslation: "", sensitivity: .delight,
                     usePermission: permission, tags: tags, createdAt: now, updatedAt: now)
        }
        let facts = [fact("interest-01", "Sailing; Botany", tags: []), fact("custom-interest", "pottery", tags: ["interest"]),
                     fact("interest-hidden", "secret hobby", tags: ["interest"], permission: .doNotUse),
                     fact("home", "Private Town", tags: ["home"]), fact("interest-copy", "sailing", tags: [])]
        let plan = TheBleedEditionBuilder.researchInterests(from: facts, dayID: "2026-10-15", kind: .morning)
        XCTAssertEqual(Set(plan.map { $0.lowercased() }), ["sailing", "botany", "pottery"])
        XCTAssertEqual(plan.count, 3)
        XCTAssertEqual(TheBleedEditionBuilder.selectedInterest(from: facts, dayID: "2026-10-15", kind: .morning), plan.first)
    }

    func testUnvisitedInterestsGetTheirTurnBeforeRecentOnes() {
        let facts = [SelfFact(id: "interest", questionID: "interest-01", question: "Interests?", answer: "sailing, botany, pottery",
            bookTranslation: "", sensitivity: .delight, usePermission: .quoteAllowed, tags: [], createdAt: now, updatedAt: now)]
        let history = [BleedPrintRecord(slotID: "last-paper", printedAt: now, items: [
            .init(storyID: "interest:sailing", revision: "one", title: "Sailing", body: "A report", sourcePageIDs: [])])]
        let plan = TheBleedEditionBuilder.researchInterests(from: facts, dayID: "2026-10-15", kind: .morning, history: history)
        XCTAssertEqual(plan.last, "sailing")
        XCTAssertEqual(Set(plan.prefix(2)), ["botany", "pottery"])
    }

    // MARK: The repair stage

    func testAReviewerApprovalIsAnApprovalHoweverItIsPunctuated() {
        for raw in ["PASS", "PASS.", "**PASS**", "Pass", "`PASS`", "pass!", "  PASS.\n"] {
            XCTAssertEqual(EditorVerdict.parse(raw), .pass, raw)
        }
        XCTAssertEqual(EditorVerdict.parse("REPAIR: remove the rain claim"), .repair("remove the rain claim"))
        XCTAssertEqual(EditorVerdict.parse("**Repair:** remove the rain claim"), .repair("remove the rain claim"))
        // Unlabelled objections, and an approval with a condition, are still objections.
        XCTAssertEqual(EditorVerdict.parse("The column invents a second site."), .repair("The column invents a second site."))
        XCTAssertEqual(EditorVerdict.parse("PASS, but remove the date"), .repair("PASS, but remove the date"))
        XCTAssertEqual(EditorVerdict.parse(nil), .unavailable)
        XCTAssertEqual(EditorVerdict.parse("  "), .unavailable)
    }

    func testAnOverlongButCleanDraftCanStillPrint() {
        let selected = BleedInterestNewsDesk.setting(brief, with: article())
        let long = "Researchers released a small AI model for bridge inspections. " + Array(repeating: detail, count: 2).joined(separator: " ")
        XCTAssertFalse(BleedCopyDesk.feedback(prose: long, brief: selected).isEmpty, "Length is still sent back for a rewrite.")
        XCTAssertTrue(BleedCopyDesk.printable(prose: long, brief: selected), "Length alone never costs the paper its column.")
        XCTAssertFalse(BleedCopyDesk.printable(prose: long + " {{CLIPPINGS}}", brief: selected))
        XCTAssertFalse(BleedCopyDesk.printable(prose: "OMIT", brief: selected))
    }
}
