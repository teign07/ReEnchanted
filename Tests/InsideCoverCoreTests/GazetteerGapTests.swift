import XCTest
@testable import InsideCoverCore

/// The holes in the reader's map, and the rules that stop the Book turning one
/// into a verdict on somebody's life.
final class GazetteerGapTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    /// 2026-08-29.
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func when(daysAgo: Int, hour: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// One located page. Latitude and longitude are given as metres offset from
    /// a fixed origin so the fixtures read as geometry rather than as numbers.
    private func page(
        _ id: String,
        northMetres: Double = 0,
        eastMetres: Double = 0,
        daysAgo: Int = 5,
        hour: Int = 14,
        accuracy: Double? = 50,
        placeKind: String? = nil,
        tags: [String] = []
    ) -> BookPage {
        let origin = 51.5
        let at = when(daysAgo: daysAgo, hour: hour)
        let latitude = origin + northMetres / 111_320
        let longitude = 0 + eastMetres / (111_320 * cos(origin * .pi / 180))
        return BookPage(
            id: id, type: .diary, createdAt: at, promptText: "", userInput: "",
            tags: tags,
            context: BookPageContextSnapshot(
                at: at, calendar: calendar,
                latitude: latitude, longitude: longitude,
                horizontalAccuracyMeters: accuracy,
                placeKind: placeKind
            )
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        pages.map { BookDay(id: "d-\($0.id)", date: $0.createdAt, pages: [$0]) }
    }

    /// A believable world: a dense home, and spokes going three of the four
    /// ways out of it. The home cluster is what pins the median centre, which
    /// is the whole reason the centre is a median — a life has a middle, and
    /// scattering fifteen points evenly around a field does not model one.
    private func ordinaryWorld(radius: Double, accuracy: Double = 50) -> [BookPage] {
        var pages: [BookPage] = []
        for index in 0..<10 {
            pages.append(page(
                "home\(index)",
                northMetres: Double(index % 3) * 12 - 12,
                eastMetres: Double(index % 4) * 9 - 13,
                daysAgo: 45 - index, accuracy: accuracy
            ))
        }
        let spokes: [(Double, Double)] = [
            (radius, 0), (radius * 0.8, 0),          // north
            (-radius * 0.9, 0), (-radius * 0.7, 0),  // south
            (0, -radius * 0.85)                      // west
        ]
        for (index, spoke) in spokes.enumerated() {
            pages.append(page(
                "spoke\(index)", northMetres: spoke.0, eastMetres: spoke.1,
                daysAgo: 30 - index, accuracy: accuracy
            ))
        }
        return pages
    }

    // MARK: Nothing to say

    func testAMapWithNoPointsSaysNothing() {
        XCTAssertNil(GazetteerGapNoticing.notice(days: [], now: now, calendar: calendar))
    }

    // MARK: The honesty gate

    /// A three-kilometre fix cannot tell anybody which way they walked down a
    /// five-hundred-metre street. The Book must not invent geography, and a
    /// reader whose whole world fits inside one fix must still be offered the
    /// two errands that ask for no distance at all.
    func testACoarseFixOverASmallWorldOffersNoGeometryAndStillOffersTheRest() {
        let world = ReaderWorld.measured(from: days(ordinaryWorld(radius: 400, accuracy: 3_000)))
        XCTAssertFalse(world.carriesHonestGeometry)
        let gaps = GazetteerGaps.open(in: world, days: [])
        XCTAssertTrue(gaps.contains(.afterDark))
        XCTAssertTrue(gaps.contains(.water))
        XCTAssertFalse(gaps.contains(.pastTheUsualEdge))
        XCTAssertFalse(gaps.contains { if case .theEmptyQuarter = $0 { return true }; return false })
    }

    func testAHandfulOfDotsIsNotALife() {
        let world = ReaderWorld.measured(from: days([
            page("a", northMetres: 2_000), page("b", eastMetres: 2_000)
        ]))
        XCTAssertFalse(world.carriesHonestGeometry)
    }

    func testAGoodFixOverARealWorldCarriesGeometry() {
        let world = ReaderWorld.measured(from: days(ordinaryWorld(radius: 4_000)))
        XCTAssertTrue(world.carriesHonestGeometry)
    }

    // MARK: The edge is a habit, not a record

    func testTheEdgeIsWhereTheyUsuallyStopRatherThanTheirBestDayOut() {
        var pages = ordinaryWorld(radius: 2_000)
        // One holiday, a very long way off, which must not become the edge.
        pages.append(page("holiday", northMetres: 400_000, daysAgo: 3))
        let world = ReaderWorld.measured(from: days(pages))
        XCTAssertLessThan(world.usualEdgeMeters, 10_000)
    }

    func testTheCentreIgnoresOneJourney() {
        var pages = ordinaryWorld(radius: 1_000)
        pages.append(page("holiday", northMetres: 500_000, daysAgo: 2))
        let world = ReaderWorld.measured(from: days(pages))
        let centre = try? XCTUnwrap(world.centre)
        XCTAssertNotNil(centre)
        XCTAssertLessThan(abs((centre?.latitude ?? 0) - 51.5), 0.05)
    }

    // MARK: Which gap, and in what order

    /// The night errand asks for no distance and changes the most, so it goes
    /// first. Asking somebody to travel is the largest request this Book makes.
    func testTheCheapestErrandIsOfferedFirst() {
        let notice = GazetteerGapNoticing.notice(
            days: days(ordinaryWorld(radius: 4_000)), now: now, calendar: calendar
        )
        XCTAssertEqual(notice?.kind, .errand)
        XCTAssertEqual(notice?.gap, .afterDark)
    }

    func testANightAlreadyOnTheMapClosesTheDarkGap() {
        var pages = ordinaryWorld(radius: 4_000)
        pages.append(page("night", northMetres: 500, daysAgo: 9, hour: 23))
        let world = ReaderWorld.measured(from: days(pages))
        XCTAssertFalse(GazetteerGaps.open(in: world, days: []).contains(.afterDark))
    }

    func testWaterOnTheMapClosesTheWaterGap() {
        var pages = ordinaryWorld(radius: 4_000)
        pages.append(page("shore", northMetres: 800, daysAgo: 8, placeKind: "beach"))
        let world = ReaderWorld.measured(from: days(pages))
        XCTAssertFalse(GazetteerGaps.open(in: world, days: []).contains(.water))
    }

    func testAnEmptyQuarterIsFoundOnlyWhenItIsGenuinelyEmpty() {
        let world = ReaderWorld.measured(from: days(ordinaryWorld(radius: 4_000)))
        // The fixture deliberately leaves one corner of the compass unused.
        XCTAssertFalse(world.emptyQuarters.isEmpty)
        var withEast = ordinaryWorld(radius: 4_000)
        withEast.append(page("east", eastMetres: 3_000, daysAgo: 4))
        let filled = ReaderWorld.measured(from: days(withEast))
        XCTAssertFalse(filled.emptyQuarters.contains(.east))
    }

    /// Points inside the fix's own error are the reader standing still, not
    /// evidence of a direction.
    func testStandingStillIsNotADirection() {
        var pages = ordinaryWorld(radius: 4_000)
        pages.append(page("shuffle", eastMetres: 20, daysAgo: 4, accuracy: 3_000))
        let world = ReaderWorld.measured(from: days(pages))
        XCTAssertTrue(world.emptyQuarters.contains(.east) || !world.carriesHonestGeometry)
    }

    // MARK: One errand at a time

    private func errandPage(_ gap: GazetteerGap, edge: Double, daysAgo ago: Int) -> BookPage {
        BookPage(
            id: "ask-\(gap.id)", type: .bookNotices, createdAt: when(daysAgo: ago, hour: 20),
            promptText: "", userInput: "",
            tags: ["the-map-gaps", "errand",
                   GazetteerGapNoticing.restTag(for: .errand, gap: gap),
                   "gazetteer-edge:\(Int(edge))"],
            sourceID: GazetteerGapPageSourceAdapter.sourceID
        )
    }

    func testTheBookOnlyEverHasOneErrandOut() {
        var pages: [BookPage] = ordinaryWorld(radius: 4_000)
        pages.append(errandPage(.afterDark, edge: 4_000, daysAgo: 3))
        XCTAssertNil(GazetteerGapNoticing.notice(days: days(pages), now: now, calendar: calendar))
    }

    // MARK: Going

    func testTheBookNoticesTheReaderWentWithoutBeingTold() throws {
        var pages: [BookPage] = ordinaryWorld(radius: 4_000)
        pages.append(errandPage(.afterDark, edge: 4_000, daysAgo: 6))
        pages.append(page("out-at-night", northMetres: 900, daysAgo: 2, hour: 22))
        let notice = try XCTUnwrap(
            GazetteerGapNoticing.notice(days: days(pages), now: now, calendar: calendar)
        )
        XCTAssertEqual(notice.kind, .went)
        XCTAssertEqual(notice.gap, .afterDark)
        XCTAssertEqual(notice.evidencePageIDs, ["out-at-night"])
    }

    /// The errand was written about a habit. Answering it has to beat that
    /// habit by more than the fix could be wrong by, or the Book congratulates
    /// somebody for standing exactly where they already were.
    func testStandingStillDoesNotCloseTheEdgeErrand() {
        var pages: [BookPage] = ordinaryWorld(radius: 4_000)
        pages.append(errandPage(.pastTheUsualEdge, edge: 4_000, daysAgo: 6))
        pages.append(page("same-old", northMetres: 4_020, daysAgo: 2))
        // 4,020 m out against an edge of 4,000 m and a 50 m fix: inside the
        // slack, so the Book must not call it a journey.
        let notice = GazetteerGapNoticing.notice(days: days(pages), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .went)
    }

    func testGoingRealyPastTheEdgeClosesIt() throws {
        var pages: [BookPage] = ordinaryWorld(radius: 4_000)
        pages.append(errandPage(.pastTheUsualEdge, edge: 4_000, daysAgo: 6))
        pages.append(page("over-the-line", northMetres: 12_000, daysAgo: 2))
        let notice = try XCTUnwrap(
            GazetteerGapNoticing.notice(days: days(pages), now: now, calendar: calendar)
        )
        XCTAssertEqual(notice.kind, .went)
    }

    func testSomewhereVisitedBeforeTheAskDoesNotCount() {
        var pages: [BookPage] = ordinaryWorld(radius: 4_000)
        pages.append(page("old-night", northMetres: 900, daysAgo: 20, hour: 23))
        pages.append(errandPage(.afterDark, edge: 4_000, daysAgo: 6))
        // The night already on the map closes the gap, so nothing is asked and
        // nothing is congratulated: the point is that the old page is never
        // read as an answer to an errand issued after it.
        let notice = GazetteerGapNoticing.notice(days: days(pages), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .went)
    }

    func testTheBookThanksSomebodyOnlyOnce() {
        var pages: [BookPage] = ordinaryWorld(radius: 4_000)
        pages.append(errandPage(.afterDark, edge: 4_000, daysAgo: 6))
        pages.append(page("out-at-night", northMetres: 900, daysAgo: 2, hour: 22))
        pages.append(BookPage(
            id: "thanks", type: .bookNotices, createdAt: when(daysAgo: 1, hour: 20),
            promptText: "", userInput: "",
            tags: [GazetteerGapNoticing.restTag(for: .went, gap: .afterDark)],
            sourceID: GazetteerGapPageSourceAdapter.sourceID
        ))
        let notice = GazetteerGapNoticing.notice(days: days(pages), now: now, calendar: calendar)
        XCTAssertNotEqual(notice?.kind, .went)
    }

    // MARK: The Page

    func testTheErrandCarriesTheEdgeItWasWrittenAbout() throws {
        var inputs = BookSourceInputs()
        inputs.days = days(ordinaryWorld(radius: 4_000))
        let day = BookDay(id: "today", date: now, pages: [])
        let page = try XCTUnwrap(GazetteerGapPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ).first)
        XCTAssertEqual(page.type, .bookNotices)
        XCTAssertEqual(page.intent, .capture)
        let tags = try XCTUnwrap(page.payload.metadata["tags"])
        XCTAssertTrue(tags.contains("gazetteer-errand:dark"))
        XCTAssertTrue(tags.contains("gazetteer-edge:"))
        // An errand is a thing to go and do, not a reading to argue with.
        XCTAssertEqual(page.payload.metadata["adaptiveActions"], "")
    }

    func testAShutBoundaryStopsTheErrandComingBack() {
        var inputs = BookSourceInputs()
        inputs.days = days(ordinaryWorld(radius: 4_000))
        inputs.bookReadingBoundaries = [
            BookReadingBoundary(id: "gazetteer-gap:gazetteer-errand:dark", createdAt: now)
        ]
        let day = BookDay(id: "today", date: now, pages: [])
        XCTAssertTrue(GazetteerGapPageSourceAdapter().candidates(
            for: day, context: CuratorContext.make(for: day), inputs: inputs, now: now
        ).isEmpty)
    }

    func testTheSourceIsRegisteredUnderItsOwnID() {
        let source = BookPageSourceRegistry.source(
            id: GazetteerGapPageSourceAdapter.sourceID, fallbackType: .bookNotices
        )
        XCTAssertEqual(source.id, GazetteerGapPageSourceAdapter.sourceID)
    }

    // MARK: Voice

    func testEveryErrandAndEveryThanksSurvivesTheCharacterLint() {
        let surfaces = everySurface()
        XCTAssertFalse(surfaces.isEmpty)
        let errors = BookCharacterLint.inspect(surfaces).filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, BookCharacterLint.report(surfaces))
    }

    /// The Rut is never the reader's fault and hardship is not evidence of it.
    /// Somebody with every reason to stay where they are has to be able to read
    /// this and find an invitation rather than a verdict.
    func testNoErrandJudgesTheReaderOrQuotesADistance() {
        for surface in everySurface() {
            let text = [surface.prompt, surface.detail, surface.payload.body]
                .joined(separator: " ").lowercased()
            for verdict in [
                "you should", "you never", "you only ever", "you rarely",
                "small life", "too far", "most people", "you failed", "you ought"
            ] {
                XCTAssertFalse(text.contains(verdict), "\(verdict) in \(surface.id)")
            }
            // Every gap is measured against the reader's own map, so no errand
            // may name a distance in anybody's units.
            XCTAssertNil(
                text.range(of: #"\b\d+\s?(km|kilometre|kilometer|mile|metre|meter|m)\b"#,
                           options: .regularExpression),
                surface.id
            )
        }
    }

    /// One surface for every errand and every thanks the Book can produce.
    private func everySurface() -> [SurfacePage] {
        let adapter = GazetteerGapPageSourceAdapter()
        let day = BookDay(id: "today", date: now, pages: [])
        let context = CuratorContext.make(for: day)
        var surfaces: [SurfacePage] = []
        let gaps: [GazetteerGap] = [
            .afterDark, .water, .pastTheUsualEdge,
            .theEmptyQuarter(.north), .theEmptyQuarter(.east),
            .theEmptyQuarter(.south), .theEmptyQuarter(.west)
        ]
        for gap in gaps {
            // The ask, forced by shutting every gap the Book would rather have
            // raised first.
            var asked = ordinaryWorld(radius: 4_000)
            var alreadySaid: [String] = []
            for other in gaps where other != gap {
                alreadySaid.append(GazetteerGapNoticing.restTag(for: .errand, gap: other))
            }
            asked.append(BookPage(
                id: "said-\(gap.id)", type: .bookNotices, createdAt: when(daysAgo: 30, hour: 20),
                promptText: "", userInput: "", tags: alreadySaid,
                sourceID: GazetteerGapPageSourceAdapter.sourceID
            ))
            var inputs = BookSourceInputs()
            inputs.days = days(asked)
            surfaces += adapter.candidates(for: day, context: context, inputs: inputs, now: now)

            // And the thanks.
            var answered = ordinaryWorld(radius: 4_000)
            answered.append(errandPage(gap, edge: 4_000, daysAgo: 6))
            answered.append(page(
                "answer-\(gap.id)", northMetres: 40_000, eastMetres: 40_000,
                daysAgo: 2, hour: 23, placeKind: "beach"
            ))
            var answeredInputs = BookSourceInputs()
            answeredInputs.days = days(answered)
            surfaces += adapter.candidates(
                for: day, context: context, inputs: answeredInputs, now: now
            )
        }
        return surfaces
    }
}
