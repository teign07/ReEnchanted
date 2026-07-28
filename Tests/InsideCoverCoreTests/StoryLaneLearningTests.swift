import XCTest
@testable import InsideCoverCore

/// A Story Page reaches the desk as one of four recipe variants, so choosing
/// between them is a decision the Curator already makes every time it seats
/// one. It used to make that decision blind: only genre and form were
/// learnable, so "does this reader go further into their life after the
/// Labyrinth's own errand, or after a scene built from their own words?" was
/// unanswerable — not for want of data, but because the lane never became a
/// tag. These pin the three axes open.
final class StoryLaneLearningTests: XCTestCase {

    private func storyPage(
        id: String = "story-1",
        recipe: String? = "dorm-room-visit",
        grounding: String? = StoryGroundingKind.keptPage.rawValue,
        lane: String? = "grounded",
        genre: String? = "cozy-mystery",
        form: String? = "visitation"
    ) -> SurfacePage {
        var metadata: [String: String] = [:]
        metadata["storyRecipeID"] = recipe ?? ""
        metadata["storyRecipeGroundingKind"] = grounding ?? ""
        metadata["storyLane"] = lane ?? ""
        metadata["storyGenreID"] = genre ?? ""
        metadata["storyFormID"] = form ?? ""
        return SurfacePage(
            id: id,
            type: .narrativeOS,
            sourceID: "narrative-os",
            intent: .simulate,
            renderStyle: .loreLetter,
            score: 50,
            reason: "r",
            prompt: "p",
            detail: "d",
            payload: BookPagePayload(headline: "h", body: "b", metadata: metadata)
        )
    }

    // MARK: - The axes are visible

    func testTheThreeDecidingAxesReachTheCurator() {
        let tags = storyPage().readerLearningTags
        XCTAssertTrue(tags.contains("recipe:dorm-room-visit"), tags.description)
        XCTAssertTrue(tags.contains("grounding:keptpage"), tags.description)
        XCTAssertTrue(tags.contains("lane:grounded"), tags.description)
    }

    func testGenreAndFormStillReachTheCurator() {
        let tags = storyPage().readerLearningTags
        XCTAssertTrue(tags.contains("genre:cozy-mystery"))
        XCTAssertTrue(tags.contains("form:visitation"))
    }

    func testWorldLedPagesAreDistinguishableFromGroundedOnes() {
        let worldLed = storyPage(lane: "world-led", genre: nil, form: nil).readerLearningTags
        XCTAssertTrue(worldLed.contains("lane:world-led"))
        XCTAssertFalse(worldLed.contains("lane:grounded"))
    }

    /// Every one of these metadata keys is written as `?? ""` on the story
    /// packet, so an absent blueprint used to emit bare "lane:" / "genre:"
    /// prefixes straight into the tag affinities.
    func testEmptyMetadataEmitsNoJunkTags() {
        let bare = storyPage(recipe: nil, grounding: nil, lane: nil, genre: nil, form: nil)
        for junk in ["recipe:", "grounding:", "lane:", "genre:", "form:"] {
            XCTAssertFalse(
                bare.readerLearningTags.contains(junk),
                "empty metadata leaked a bare \(junk) tag"
            )
        }
    }

    func testTheNewTagsSurviveThePerEventTagCap() {
        // Affinities only record the first eight sorted tags per event; the
        // deciding axes must not be crowded out by a page's prose tags.
        var page = storyPage()
        var metadata = page.payload.metadata
        metadata["tags"] = "story-grounding-used,meaningful-source-use:story,souvenir-door,story-spark,threshold,wonder,objects"
        page = SurfacePage(
            id: page.id,
            type: page.type,
            sourceID: page.sourceID,
            intent: page.intent,
            renderStyle: page.renderStyle,
            score: page.score,
            reason: page.reason,
            prompt: page.prompt,
            detail: page.detail,
            payload: BookPagePayload(headline: "h", body: "b", metadata: metadata)
        )
        let recorded = Set(page.readerLearningTags.prefix(8))
        XCTAssertTrue(recorded.contains("lane:grounded"), recorded.sorted().description)
        XCTAssertTrue(recorded.contains("recipe:dorm-room-visit"), recorded.sorted().description)
        XCTAssertTrue(recorded.contains("grounding:keptpage"), recorded.sorted().description)
    }

    // MARK: - The question becomes answerable

    private func event(
        _ action: ReaderLearningAction,
        page: SurfacePage,
        at date: Date
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            id: "\(action.rawValue)-\(page.id)-\(date.timeIntervalSince1970)",
            dayID: BookDay.id(for: date),
            occurredAt: date,
            action: action,
            surfaceID: page.id,
            sourceID: page.sourceID,
            type: page.type,
            varietyKey: "narrative-os",
            hour: 10,
            tags: page.readerLearningTags
        )
    }

    /// The payoff: a reader who physically crosses into life after world-led
    /// pages, and merely admires grounded ones, should tilt the desk toward
    /// world-led. Before the lane was a tag both variants scored identically.
    func testTheDeskLearnsWhichLaneSendsTheReaderOutside() {
        var model = ReaderLearningModel()
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        // World-led scenes take the day's air, never its ink, so their
        // grounding kind genuinely differs from a grounded scene's.
        func worldLed(_ id: String) -> SurfacePage {
            storyPage(
                id: id,
                recipe: "night-errand",
                grounding: StoryGroundingKind.realSignal.rawValue,
                lane: "world-led",
                genre: nil,
                form: nil
            )
        }
        func grounded(_ id: String) -> SurfacePage {
            storyPage(
                id: id,
                recipe: "dorm-room-visit",
                grounding: StoryGroundingKind.keptPage.rawValue,
                lane: "grounded",
                genre: nil,
                form: nil
            )
        }

        for index in 0..<4 {
            let at = start.addingTimeInterval(Double(index) * 86_400)
            model.record(event(.followedThread, page: worldLed("w\(index)"), at: at))
            model.record(event(.loved, page: grounded("g\(index)"), at: at.addingTimeInterval(3600)))
        }

        let nextWorldLed = worldLed("w-next")
        let nextGrounded = grounded("g-next")

        XCTAssertGreaterThan(
            model.scoreAdjustment(for: nextWorldLed),
            model.scoreAdjustment(for: nextGrounded),
            "crossings on one lane must outrank admiration on the other"
        )
    }

    func testALaneTheReaderKeepsSendingAwayCools() {
        var model = ReaderLearningModel()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<4 {
            let at = start.addingTimeInterval(Double(index) * 86_400)
            let page = storyPage(id: "d\(index)", recipe: "tiny-heist", lane: "world-led", genre: nil, form: nil)
            model.record(event(.dismissed, page: page, at: at))
        }
        let next = storyPage(id: "d-next", recipe: "tiny-heist", lane: "world-led", genre: nil, form: nil)
        XCTAssertLessThan(model.scoreAdjustment(for: next), 0)
    }
}
