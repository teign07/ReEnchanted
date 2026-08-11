import XCTest
@testable import InsideCoverCore

/// The Book always speaks; the size of what it says scales with the evidence.
/// These lock in the ladder itself and the removal of the keep-count gate that
/// used to hold three whole page families back until the fiftieth kept page.
final class BookClaimTierTests: XCTestCase {

    // MARK: - The ladder

    func testThinEvidenceIsAGlimmerRatherThanSilence() {
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 1, distinctDays: 1), .glimmer)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 3, distinctDays: 2), .glimmer)
    }

    func testWeightAloneCannotBuyTheHigherTiers() {
        // A single long session can pile up weight; it cannot manufacture days.
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 40, distinctDays: 1), .glimmer)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 40, distinctDays: 3), .gathering)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 40, distinctDays: 5), .established)
    }

    func testDaysAloneCannotBuyTheHigherTiersEither() {
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 2, distinctDays: 30), .glimmer)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 4, distinctDays: 30), .gathering)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 8, distinctDays: 30), .established)
    }

    func testUnknownDaySpreadJudgesOnWeightAlone() {
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 9), .established)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 5), .gathering)
        XCTAssertEqual(BookClaimTier.tier(evidenceWeight: 2), .glimmer)
    }

    func testTiersAreOrdered() {
        XCTAssertLessThan(BookClaimTier.glimmer, BookClaimTier.gathering)
        XCTAssertLessThan(BookClaimTier.gathering, BookClaimTier.established)
    }

    func testLoomBridgeKeepsOneLadder() {
        XCTAssertEqual(BookClaimTier(loom: .glimmer), .glimmer)
        XCTAssertEqual(BookClaimTier(loom: .gathering), .gathering)
        XCTAssertEqual(BookClaimTier(loom: .established), .established)
        // Same wording either way: a reader who meets both hears one Book.
        XCTAssertEqual(BookClaimTier.glimmer.opening, RelationalLoomConnection.EvidenceTier.glimmer.opening)
        XCTAssertEqual(BookClaimTier.established.closing, RelationalLoomConnection.EvidenceTier.established.closing)
    }

    func testClaimLadderSoundsLikeTheFeralBookRatherThanAnAnalyst() {
        for tier in BookClaimTier.allCases {
            let line = "\(tier.opening) \(tier.closing)"
            XCTAssertFalse(line.contains("The Book"))
            XCTAssertFalse(line.localizedCaseInsensitiveContains("held lightly"))
            XCTAssertFalse(line.localizedCaseInsensitiveContains("revisable"))
            XCTAssertTrue(line.localizedCaseInsensitiveContains("repeat") || line.localizedCaseInsensitiveContains("Page"))
        }
    }

    func testConnectedPageTitlesBelongToTheBookSpeakingInFirstPerson() {
        XCTAssertEqual(BookPageType.bookConnections.title, "What Keeps Finding What")
        XCTAssertEqual(BookPageType.bookRemembered.title, "I Remembered")
        XCTAssertEqual(BookPageSourceRegistry.source(for: .bookConnections).title, "What Keeps Finding What")
        XCTAssertEqual(BookPageSourceRegistry.source(for: .bookRemembered).title, "I Remembered")
    }

    // MARK: - Hedging attaches to the evidence, not the address

    func testEvidenceQualifierIsLiteralRatherThanVague() {
        let line = BookClaimTier.glimmer.evidenceQualifier(weight: 2, distinctDays: 2)
        XCTAssertEqual(line, "on 2 threads across 2 days")
        XCTAssertEqual(
            BookClaimTier.glimmer.evidenceQualifier(weight: 1, distinctDays: 1),
            "on one thread across one day"
        )
        XCTAssertEqual(BookClaimTier.gathering.evidenceQualifier(weight: 6), "on 6 threads")
        for tier in BookClaimTier.allCases {
            XCTAssertFalse(tier.evidenceQualifier(weight: 3, distinctDays: 3).contains("perhaps"))
            XCTAssertFalse(tier.evidenceQualifier(weight: 3, distinctDays: 3).contains("maybe"))
        }
    }

    func testProseIsTierSpecificAndDeterministic() {
        let pools = (
            glimmer: ["small"],
            gathering: ["medium"],
            established: ["large"]
        )
        for (tier, expected) in [
            (BookClaimTier.glimmer, "small"),
            (BookClaimTier.gathering, "medium"),
            (BookClaimTier.established, "large")
        ] {
            XCTAssertEqual(
                BookClaimTier.prose(
                    glimmer: pools.glimmer,
                    gathering: pools.gathering,
                    established: pools.established,
                    tier: tier,
                    seed: 42,
                    salt: 7
                ),
                expected
            )
        }
    }

    func testHigherTiersEarnMoreOfTheDeskButAGlimmerStillEarnsASlot() {
        XCTAssertGreaterThan(BookClaimTier.established.surfaceScoreBase, BookClaimTier.gathering.surfaceScoreBase)
        XCTAssertGreaterThan(BookClaimTier.gathering.surfaceScoreBase, BookClaimTier.glimmer.surfaceScoreBase)
        XCTAssertGreaterThan(BookClaimTier.glimmer.surfaceScoreBase, 0)
    }

    // MARK: - The keep-count gate is gone

    func testMemoryTrioNoLongerWaitsOnAKeepCount() {
        for type in [BookPageType.bookRemembered, .bookConnections, .marginsAtlas] {
            XCTAssertFalse(
                BookMemoryGate.locks(type, keptPageCount: 0),
                "\(type) must be free to speak from the first day, sized to what it knows"
            )
        }
    }

    func testTheGateStillGovernsAskingAStrangerForMoney() {
        XCTAssertTrue(BookMemoryGate.locks(.patreon, keptPageCount: 0))
        XCTAssertTrue(BookMemoryGate.locks(.quip, keptPageCount: 29))
        XCTAssertFalse(BookMemoryGate.locks(.patreon, keptPageCount: 30))
        XCTAssertFalse(BookMemoryGate.locks(.quip, keptPageCount: 30))
    }

    func testOrdinaryPagesWereNeverGated() {
        XCTAssertFalse(BookMemoryGate.locks(.souvenir, keptPageCount: 0))
        XCTAssertFalse(BookMemoryGate.locks(.diary, keptPageCount: 0))
    }

    // MARK: - The real gate is material, not a counter

    private let calendar = Calendar(identifier: .gregorian)

    private func date(daysAgo: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
    }

    /// A kept page carrying a semantic echo: the cheapest honest unit of
    /// evidence Book Connections counts (weight 3 apiece).
    private func echoDay(daysAgo: Int, from now: Date, id: String) -> BookDay {
        let created = date(daysAgo: daysAgo, from: now)
        let page = BookPage(
            id: id,
            type: .souvenir,
            createdAt: created,
            promptText: "Catch one bright particular.",
            userInput: "Something small waited all evening for my attention.",
            tags: SemanticKeepEcho.tags(for: SemanticKeepEcho.Echo(
                sourcePageID: "kettle-\(id)",
                excerpt: "The kettle sang twice",
                monthLine: "back in May",
                similarity: 0.83,
                line: "An older page answers this one."
            ))
        )
        return BookDay(id: BookDay.id(for: created), date: calendar.startOfDay(for: created), pages: [page])
    }

    private func connectionsPage(days: [BookDay], now: Date) -> SurfacePage? {
        var inputs = BookSourceInputs.empty
        inputs.days = days
        let today = BookDay(id: BookDay.id(for: now), date: calendar.startOfDay(for: now), pages: [])
        return BookConnectionsPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        ).first
    }

    func testAnEmptyArchiveStillGetsNoConnectionsPage() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10))!
        XCTAssertNil(
            connectionsPage(days: [], now: now),
            "the adapter must refuse to draw a map with no crossings on it"
        )
    }

    func testDayOneEvidenceSpeaksAsAGlimmerInsteadOfWaitingFiftyPages() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10))!
        let page = connectionsPage(days: [echoDay(daysAgo: 1, from: now, id: "a")], now: now)

        let surface = try? XCTUnwrap(page)
        XCTAssertNotNil(surface, "one real echo is enough to say something small")
        XCTAssertEqual(surface?.payload.metadata["claimTier"], BookClaimTier.glimmer.rawValue)
        XCTAssertEqual(surface?.payload.metadata["connectionWeight"], "3")
        // The claim is sized down, not hedged with a vague qualifier.
        let body = surface?.payload.body ?? ""
        XCTAssertTrue(
            body.contains(BookClaimTier.glimmer.closing) || body.localizedCaseInsensitiveContains("small map"),
            "glimmer body should own its smallness: \(body)"
        )
        let readerCopy = [surface?.reason, surface?.prompt, surface?.detail, surface?.payload.headline, body]
            .compactMap { $0 }
            .joined(separator: " ")
        XCTAssertFalse(BookVoice.containsDrainedRegister(readerCopy), readerCopy)
        XCTAssertFalse(readerCopy.localizedCaseInsensitiveContains("The Book"), readerCopy)
        XCTAssertTrue(
            readerCopy.localizedCaseInsensitiveContains("connection finding")
                || readerCopy.localizedCaseInsensitiveContains("map"),
            readerCopy
        )
    }

    func testEvidenceAcrossManyDaysEarnsTheLargerClaim() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 10))!
        let days = (1...5).map { echoDay(daysAgo: $0, from: now, id: "day\($0)") }
        let page = connectionsPage(days: days, now: now)

        XCTAssertEqual(page?.payload.metadata["claimTier"], BookClaimTier.established.rawValue)
        XCTAssertEqual(page?.payload.metadata["connectionWeight"], "15")
    }

    func testSameEvidencePiledIntoOneDayStaysAGlimmer() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 10))!
        // Five echoes, one calendar day: plenty of weight, no day spread. A
        // single long session must not be able to buy the bigger sentence.
        let created = date(daysAgo: 1, from: now)
        let pages = (1...5).map { index in
            BookPage(
                id: "burst-\(index)",
                type: .souvenir,
                createdAt: created.addingTimeInterval(Double(index) * 600),
                promptText: "Catch one bright particular.",
                userInput: "Another one, all at once.",
                tags: SemanticKeepEcho.tags(for: SemanticKeepEcho.Echo(
                    sourcePageID: "kettle-burst-\(index)",
                    excerpt: "The kettle sang twice",
                    monthLine: "back in May",
                    similarity: 0.83,
                    line: "An older page answers this one."
                ))
            )
        }
        let burst = BookDay(id: BookDay.id(for: created), date: calendar.startOfDay(for: created), pages: pages)

        let page = connectionsPage(days: [burst], now: now)

        XCTAssertEqual(page?.payload.metadata["connectionWeight"], "15")
        XCTAssertEqual(
            page?.payload.metadata["claimTier"],
            BookClaimTier.glimmer.rawValue,
            "weight without distinct days must not buy a larger claim"
        )
    }

    func testUnrelatedArchiveDaysCannotEnlargeAOneDayClaim() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 10))!
        let evidenceDay = echoDay(daysAgo: 1, from: now, id: "only-evidence")
        let unrelatedDays = (2...8).map { daysAgo in
            let created = date(daysAgo: daysAgo, from: now)
            return BookDay(
                id: BookDay.id(for: created),
                date: calendar.startOfDay(for: created),
                pages: [BookPage(
                    id: "unrelated-\(daysAgo)",
                    type: .diary,
                    createdAt: created,
                    promptText: "An unrelated page.",
                    userInput: "It does not support the connection.",
                    tags: ["unrelated"]
                )]
            )
        }

        let page = connectionsPage(days: unrelatedDays + [evidenceDay], now: now)

        XCTAssertEqual(page?.payload.metadata["connectionEvidenceDays"], "1")
        XCTAssertEqual(page?.payload.metadata["claimTier"], BookClaimTier.glimmer.rawValue)
    }
}
