import XCTest
@testable import InsideCoverCore

/// The Book is allowed to be a character. It is not allowed to be the only
/// subject on the shelf.
///
/// Pages about the Book itself sit in all three lanes — an aside is fiction,
/// the inventory is other, the pocket is other — so lane balance never counted
/// them together, and a `.livingContinuity` session actively prefers one for
/// the Door and then boosts two more for the Echo. The result was desks where
/// the Book noticed, remembered, and then remarked on itself, one after
/// another.
final class CuratorBookSelfTalkTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)

    /// Pages about the Book with no memory gate or staged debut of their own,
    /// so anything excluded here is excluded by the cap and not by eligibility.
    private let selfTalkTypes: [BookPageType] = [.bookAside, .bookPocket, .inventory]
    private let plainTypes: [BookPageType] = [.souvenir, .diary, .note, .quotes]

    private func candidate(_ type: BookPageType, score: Int) -> SurfacePage {
        SurfacePage(
            id: "c-\(type.rawValue)", type: type,
            sourceID: "src-\(type.rawValue)", score: score,
            prompt: type.title, detail: "d",
            payload: BookPagePayload(headline: type.title, body: "b", metadata: [:])
        )
    }

    private func settledMood() -> CuratorMood {
        var mood = CuratorMood.neutral
        mood.keptPageCount = 40
        mood.isFirstHours = false
        mood.hour = 10
        return mood
    }

    /// The naming is the contract: every group the reader named belongs.
    func testTheFamilyCoversNoticingVoiceAndHousekeeping() {
        for type in [BookPageType.bookNotices, .bookRemembered, .bookConnections, .marginsAtlas, .bookPocket,
                     .bookAside, .bookOfYou, .bookJump, .bookFae,
                     .frontMatter, .helpTips, .bindery, .inventory] {
            XCTAssertTrue(type.speaksOfItself, "\(type.rawValue) is about the Book and should be counted")
        }
        // The first-run opening must never be crowded out of the first run,
        // and the reader's own day is not the Book talking about itself.
        for type in [BookPageType.welcome, .diary, .souvenir, .letter, .twoReadings] {
            XCTAssertFalse(type.speaksOfItself, "\(type.rawValue) should not be counted")
        }
    }

    /// Even when they outrank everything else, only one reaches the shelf.
    func testOnlyOnePageAboutTheBookReachesTheVisibleDesk() {
        let candidates = selfTalkTypes.enumerated().map { candidate($1, score: 95 - $0) }
            + plainTypes.enumerated().map { candidate($1, score: 40 - $0) }

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3, "the desk should still be furnished")
        XCTAssertEqual(
            pages.filter(\.type.speaksOfItself).count, 1,
            "desk was \(pages.map { $0.type.rawValue })"
        )
    }

    /// The cap is a preference, and preferences yield rather than hand back a
    /// one-card desk. When the Book is all there is, the Book fills the shelf.
    func testTheCapYieldsRatherThanStarveTheDesk() {
        let candidates = selfTalkTypes.enumerated().map { candidate($1, score: 90 - $0) }

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, 3, "a preference cap must not shorten the desk")
    }

    /// The folio publishes a block the reader turns through, so the ration is
    /// per three leaves rather than per shelf: one in the opening trio, no more
    /// than three across the whole published block.
    func testThePublishedBlockIsRationedThreeLeavesAtATime() {
        let bookTypes: [BookPageType] = [
            .bookAside, .bookPocket, .inventory, .helpTips, .bindery, .frontMatter, .bookOfYou
        ]
        let otherTypes: [BookPageType] = [.souvenir, .diary, .note, .quotes, .body, .fuel, .rest, .mood]
        let candidates = bookTypes.enumerated().map { candidate($1, score: 95 - $0) }
            + otherTypes.enumerated().map { candidate($1, score: 40 - $0) }

        let pages = BookCurator.rankedPages(
            from: candidates, limit: BookDeskRound.reserveCapacity, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(pages.count, BookDeskRound.reserveCapacity, "the block should still be furnished")
        XCTAssertEqual(pages.prefix(3).filter(\.type.speaksOfItself).count, 1)
        XCTAssertLessThanOrEqual(
            pages.filter(\.type.speaksOfItself).count, 3,
            "block was \(pages.map { $0.type.rawValue })"
        )
    }

    /// Past the published block the ranking is a reserve, not a shelf. Rationing
    /// it would leave later refills with nothing to draw on, and anything it
    /// sends forward meets the cap again on the desk it lands on.
    func testTheReserveBehindTheBlockIsNotRationed() {
        let bookTypes: [BookPageType] = [
            .bookAside, .bookPocket, .inventory, .helpTips, .bindery, .frontMatter, .bookOfYou
        ]
        let otherTypes: [BookPageType] = [.souvenir, .diary, .note, .quotes, .body, .fuel, .rest, .mood]
        let candidates = bookTypes.enumerated().map { candidate($1, score: 95 - $0) }
            + otherTypes.enumerated().map { candidate($1, score: 40 - $0) }

        let pages = BookCurator.rankedPages(
            from: candidates, limit: BookDeskRound.candidateBenchCapacity, mood: settledMood(), now: now
        ).map(\.page)

        XCTAssertEqual(
            pages.filter(\.type.speaksOfItself).count, bookTypes.count,
            "the reserve dropped material it may need for a later refill"
        )
    }

    /// Every mirror is a Page about the Book, so the ration and the floor under
    /// being seen aim at the same slot. A self-surfacing milestone must not be
    /// able to spend the day's single ration and leave a week-old debt unpaid.
    func testTheMirrorFloorOutranksTheRation() {
        let milestone = SurfacePage(
            id: "c-milestone", type: .bindery, sourceID: "src-bindery", score: 99,
            prompt: BookPageType.bindery.title, detail: "d",
            payload: BookPagePayload(
                headline: BookPageType.bindery.title, body: "b",
                metadata: ["milestone": "true"]
            )
        )
        let candidates = [
            milestone,
            candidate(.bookNotices, score: 98)
        ] + plainTypes.enumerated().map { candidate($1, score: 40 - $0) }

        // An empty surface history is the strongest possible case for the
        // floor: nothing reflective has ever surfaced.
        var mood = settledMood()
        mood.surfaceHistory = [:]
        XCTAssertTrue(CuratorMirrorFloor.isOwed(history: mood.surfaceHistory, now: now))

        let pages = BookCurator.rankedPages(
            from: candidates, limit: 3, mood: mood, now: now
        ).map(\.page.type)

        XCTAssertTrue(pages.contains(.bindery), "desk was \(pages.map(\.rawValue))")
        XCTAssertTrue(pages.contains(.bookNotices), "desk was \(pages.map(\.rawValue))")
    }

    // MARK: - Turning through the block

    private func page(_ id: String, _ type: BookPageType) -> SurfacePage {
        SurfacePage(
            id: id, type: type, sourceID: id, score: 50,
            prompt: id, detail: id, payload: BookPagePayload(headline: id, body: id)
        )
    }

    /// `.bookAside` is fiction and `.bookPocket` is other, so lane spacing was
    /// perfectly happy to seat them together.
    func testTwoPagesAboutTheBookNeverSitNextToEachOther() {
        let block = [
            page("aside", .bookAside), page("pocket", .bookPocket),
            page("inventory", .inventory), page("diary", .diary),
            page("letter", .letter), page("quotes", .quotes)
        ]

        let sequenced = BookCurator.readingSequence(block)

        XCTAssertEqual(Set(sequenced.map(\.id)), Set(block.map(\.id)), "spacing must not drop or invent Pages")
        for (left, right) in zip(sequenced, sequenced.dropFirst()) {
            XCTAssertFalse(
                left.type.speaksOfItself && right.type.speaksOfItself,
                "\(left.id) then \(right.id) in \(sequenced.map(\.id))"
            )
        }
    }

    /// When there is no relief to be had, rank wins rather than the rule
    /// dropping anything.
    func testABlockOfNothingButTheBookIsReturnedIntact() {
        let block = [
            page("a", .bookAside), page("b", .bookPocket),
            page("c", .inventory), page("d", .bookNotices)
        ]
        XCTAssertEqual(BookCurator.readingSequence(block).map(\.id), ["a", "b", "c", "d"])
    }

    /// Rank chose the opening leaf; spacing reorders what follows it.
    func testTheOpeningPageIsStillNeverMoved() {
        let block = [
            page("aside", .bookAside), page("pocket", .bookPocket),
            page("diary", .diary), page("letter", .letter)
        ]
        XCTAssertEqual(BookCurator.readingSequence(block).first?.id, "aside")
    }
}
