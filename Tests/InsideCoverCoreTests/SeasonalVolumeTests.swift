import XCTest
@testable import InsideCoverCore

/// Phase 5 of the bound-volumes plan: the seasonal volume: the object the
/// Bound Year membership actually posts, three times a year, with the annual
/// hardcover as the fourth.
///
/// The rule these tests exist to protect: **the reader names their own seasons,
/// and only backwards.** The Book will title a season by its months, but it
/// will not invent a word for a stretch of life the reader has not finished
/// having.
final class SeasonalVolumeTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var seasonStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 9)) ?? Date()
    }
    private var boundAt: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 20)) ?? Date()
    }

    /// Three months of kept pages, a few each week.
    private func days() -> [BookDay] {
        (0..<90).compactMap { offset -> BookDay? in
            guard offset % 3 == 0,
                  let date = calendar.date(byAdding: .day, value: offset, to: seasonStart) else { return nil }
            let dayID = BookDay.id(for: date, calendar: calendar)
            return BookDay(
                id: dayID,
                date: calendar.startOfDay(for: date),
                pages: [
                    BookPage(id: "s-\(dayID)", type: .souvenir, createdAt: date,
                             promptText: "One true sentence",
                             userInput: "The harbour kept its minutes on \(dayID)."),
                    BookPage(id: "b-\(dayID)", type: .bookOfYou, createdAt: date,
                             promptText: "Tonight", userInput: "The night gathered itself on \(dayID).")
                ]
            )
        }
    }

    private func season(named name: String?) -> AnnualEdition {
        MonthlyEditionBuilder.seasonal(
            from: days(),
            startingMonth: seasonStart,
            readerName: "Reader",
            readerRole: BoundReaderRole(
                fullName: "The Magpie of the Blue Hour",
                signature: "The Magpie of the Blue Hour, with Quiet Hands",
                gloss: "You come alive when something catches the light.",
                compassLine: "Take one bright thing off the street today."
            ),
            seasonName: name,
            now: boundAt,
            calendar: calendar
        )
    }

    // MARK: Shape

    func testASeasonBindsThreeMonthChapters() {
        let volume = season(named: nil)
        XCTAssertEqual(volume.chapters.count, 3)
        XCTAssertFalse(volume.isEmpty)
        XCTAssertGreaterThan(volume.pageCount, 0)
    }

    func testChaptersRunForwards() {
        let starts = season(named: nil).chapters.map(\.startDate)
        XCTAssertEqual(starts, starts.sorted())
    }

    func testEveryChapterCarriesTheReadersName() {
        XCTAssertTrue(
            season(named: nil).chapters.allSatisfy {
                $0.readerRole?.fullName == "The Magpie of the Blue Hour"
            }
        )
    }

    func testASeasonCarriesExplicitPublicationIdentityAndDoesNotEndTheYear() {
        let volume = season(named: nil)
        XCTAssertEqual(volume.publicationKind, .seasonal)
        XCTAssertFalse(volume.closing.contains("Here 2026 ends"))
        XCTAssertTrue(volume.closing.contains("season is kept"))
    }

    func testTheVolumeEarnsFrontMatterAcrossMonths() {
        let volume = season(named: nil)
        XCTAssertNotNil(volume.publicationMatter)
        XCTAssertFalse(volume.publicationMatter?.proofLine.isEmpty ?? true)
    }

    func testPrivateChartsOnlyEnterTheAlmanacAfterTheExistingOptIn() {
        let fuel = FacultyEntry(
            kind: .fuel,
            dayID: BookDay.id(for: seasonStart, calendar: calendar),
            createdAt: seasonStart,
            windowID: "breakfast",
            windowName: "Breakfast",
            rawText: "coffee, toast, two eggs"
        )
        let inner = FacultyEntry(
            kind: .innerWeather,
            dayID: BookDay.id(for: seasonStart, calendar: calendar),
            createdAt: seasonStart,
            windowID: "morning",
            windowName: "Morning",
            rawText: "A little rain behind the ribs."
        )
        let privateVolume = MonthlyEditionBuilder.seasonal(
            from: days(),
            startingMonth: seasonStart,
            facultyEntries: [fuel, inner],
            readerName: "Reader",
            includePrivateLifeAlmanac: true,
            now: boundAt,
            calendar: calendar
        )
        let privateIDs = Set(privateVolume.publicationMatter?.almanacItems.map(\.id) ?? [])
        XCTAssertTrue(privateIDs.contains("volume-returning-cup"))
        XCTAssertTrue(privateIDs.contains("volume-returning-plate"))
        XCTAssertTrue(privateIDs.contains("volume-inner-weather"))

        let closedVolume = MonthlyEditionBuilder.seasonal(
            from: days(),
            startingMonth: seasonStart,
            facultyEntries: [fuel, inner],
            readerName: "Reader",
            includePrivateLifeAlmanac: false,
            now: boundAt,
            calendar: calendar
        )
        let closedIDs = Set(closedVolume.publicationMatter?.almanacItems.map(\.id) ?? [])
        XCTAssertFalse(closedIDs.contains("volume-returning-cup"))
        XCTAssertFalse(closedIDs.contains("volume-returning-plate"))
        XCTAssertFalse(closedIDs.contains("volume-inner-weather"))
    }

    func testAMonthEarnsItsOwnLivedAlmanacWithoutWaitingForASeason() {
        let fuel = FacultyEntry(
            kind: .fuel,
            dayID: BookDay.id(for: seasonStart, calendar: calendar),
            createdAt: seasonStart,
            windowID: "breakfast",
            windowName: "Breakfast",
            rawText: "coffee, toast, two eggs"
        )
        let inner = FacultyEntry(
            kind: .innerWeather,
            dayID: BookDay.id(for: seasonStart, calendar: calendar),
            createdAt: seasonStart,
            windowID: "morning",
            windowName: "Morning",
            rawText: "A little rain behind the ribs."
        )
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: seasonStart) ?? boundAt
        let month = MonthlyEditionBuilder.edition(
            from: days(),
            facultyEntries: [fuel, inner],
            readerName: "Reader",
            startDate: seasonStart,
            endDate: end,
            generatedAt: boundAt,
            calendar: calendar,
            includePrivateWeatherSummary: true
        )

        XCTAssertEqual(month.publicationKind, .monthly)
        let ids = Set(month.publicationMatter?.almanacItems.map(\.id) ?? [])
        XCTAssertTrue(ids.contains("volume-returning-cup"))
        XCTAssertTrue(ids.contains("volume-returning-plate"))
        XCTAssertTrue(ids.contains("volume-inner-weather"))
        XCTAssertFalse(month.publicationMatter?.proofLine.isEmpty ?? true)
    }

    // MARK: The naming rule

    func testAnUnnamedSeasonIsTitledByItsMonthsAndInventsNothing() {
        let volume = season(named: nil)
        XCTAssertEqual(volume.resolvedCoverLine(), "March 2026 – May 2026")
        XCTAssertEqual(volume.resolvedCoverSubline(), "3 months, bound")
    }

    func testAReadersOwnNameForTheSeasonWinsTheCover() {
        let volume = season(named: "The Long Thaw")
        XCTAssertEqual(volume.resolvedCoverLine(), "The Long Thaw")
        XCTAssertTrue(volume.resolvedCoverSubline().contains("the season you named"))
        XCTAssertEqual(volume.title, "Book of You: The Long Thaw")
    }

    func testABlankSeasonNameIsNotAName() {
        XCTAssertEqual(season(named: "   ").resolvedCoverLine(), "March 2026 – May 2026")
    }

    /// An annual bound before seasons existed must read exactly as it did.
    func testAnAnnualStillCallsItselfAnAnnual() {
        let annual = MonthlyEditionBuilder.annual(
            2026,
            from: days(),
            readerName: "Reader",
            now: boundAt,
            calendar: calendar
        )
        XCTAssertEqual(annual.resolvedCoverLine(), "The 2026 Annual")
        XCTAssertTrue(annual.resolvedCoverSubline().hasPrefix("a year, bound"))
    }

    // MARK: The printed object

    func testTheSeasonalVariantIsPerfectBoundAndDistinctlyIdentified() {
        let spec = PrintSpec.perfectBoundSoftcover6x9
        XCTAssertEqual(spec.coverTreatment, .perfectBound)
        XCTAssertEqual(spec.luluPackageID, "0600X0900.FC.STD.PB.060UW444.MXX")
        XCTAssertEqual(
            PhysicalBookVariant.from(spec).id,
            "perfect-bound-softcover-6x9",
            "The Worker checks this id against its allowlist; a mislabel is a rejected order."
        )
    }

    /// The bug this replaced: a binary `coverTreatment == .linenWrap` check that
    /// labelled every non-linen spec as the illustrated hardcover.
    func testEveryPrintableVariantGetsItsOwnIdentity() {
        let ids = PrintSpec.allPrintableVariants.map { PhysicalBookVariant.from($0).id }
        XCTAssertEqual(Set(ids).count, ids.count, "Two bindings sharing an id would order the wrong book.")
    }

    /// A paperback is trimmed flush with the block; a case-wrap allowance here
    /// would push the cover artwork a full inch off register.
    func testAPaperbackCoverNeedsBleedOnlyNotACaseWrapAllowance() {
        XCTAssertFalse(PrintSpec.perfectBoundSoftcover6x9.coverTreatment.wrapsAroundBoard)
        XCTAssertEqual(PrintSpec.perfectBoundSoftcover6x9.coverWrapMarginInches, 0.125, accuracy: 0.0001)
        XCTAssertTrue(PrintSpec.clothFoilHardcover6x9.coverTreatment.wrapsAroundBoard)
    }

    func testASeasonSitsInsidePerfectBindingsPageRange() {
        let pages = PrintGeometry.boundPageCount(
            rawPages: season(named: nil).pageCount,
            spec: .perfectBoundSoftcover6x9
        )
        XCTAssertGreaterThanOrEqual(pages, PrintSpec.perfectBoundSoftcover6x9.minimumPages)
        XCTAssertLessThanOrEqual(pages, 800, "Perfect binding tops out at 800 pages.")
    }

    func testEveryAuthoredCoverOwnsANonPhotoTitleSafeRegion() {
        XCTAssertEqual(PublicationCoverCatalogue.rotating.count, 4)
        XCTAssertTrue(PublicationCoverCatalogue.rotating.allSatisfy {
            $0.titleLayout != .photographFooter
                && $0.titleLayout.titleRect.width >= 0.5
                && $0.titleLayout.titleRect.height >= 0.4
        })
        XCTAssertEqual(
            PublicationCoverCatalogue.plate(id: "weather-cabinet")?.titleLayout,
            .weatherCabinet,
            "The pale central sheet needs dark ink, not the photograph footer treatment."
        )
    }

    func testTheDispatchProofSublineChangesWhenTheReaderNamesTheSeason() {
        let opened = SeasonalDispatchWindow.open(
            seasonKey: "2026-S03",
            volume: seasonWithThread(),
            boundAt: boundAt,
            calendar: calendar
        )
        XCTAssertTrue(opened.resolvedCoverSubline.contains("a season I would call this"))
        let renamed = SeasonalDispatchWindow.rename(opened, to: "The Door in the Rain")
        XCTAssertTrue(renamed.resolvedCoverSubline.contains("the season you named"))
    }

    func testAReaderWrittenCoverNameCannotOutgrowTheThreeLineTitleClearing() {
        let opened = SeasonalDispatchWindow.open(
            seasonKey: "2026-S03",
            volume: season(named: nil),
            boundAt: boundAt,
            calendar: calendar
        )
        let tooLong = String(repeating: "bramble ", count: 20)
        XCTAssertEqual(SeasonalDispatchWindow.rename(opened, to: tooLong), opened)
    }

    // MARK: The Book proposes, the reader disposes

    private func namedThread() -> Constellation {
        Constellation(
            id: "c-thaw",
            signalID: "c-thaw",
            kind: .pattern,
            subjectID: "c-thaw",
            subjectName: "thaw",
            name: "The Long Thaw",
            phase: .named,
            firstNoticedAt: seasonStart,
            lastSeenAt: boundAt,
            namedAt: seasonStart,
            wovenAt: nil,
            fadedAt: nil,
            sightingDayIDs: [BookDay.id(for: seasonStart, calendar: calendar)],
            strengthPeak: 8,
            latestLine: "It kept coming back.",
            evidencePageIDs: [],
            relatedEntityIDs: [],
            tags: []
        )
    }

    private func seasonWithThread() -> AnnualEdition {
        MonthlyEditionBuilder.seasonal(
            from: days(),
            startingMonth: seasonStart,
            constellations: [namedThread()],
            readerName: "Reader",
            now: boundAt,
            calendar: calendar
        )
    }

    func testTheBookProposesATitleFromANamedThread() {
        let volume = seasonWithThread()
        XCTAssertEqual(volume.seasonTitleProposal?.title, "The Long Thaw")
        XCTAssertEqual(volume.resolvedCoverLine(), "The Long Thaw")
    }

    /// A proposal is an argument, not an assertion: the reason travels with it
    /// so the reader can disagree with the claim rather than just the word.
    func testAProposalAlwaysCarriesItsReason() {
        XCTAssertFalse(seasonWithThread().seasonTitleProposal?.because.isEmpty ?? true)
    }

    func testTheReadersOwnNameOverrulesTheBooksProposal() {
        let volume = MonthlyEditionBuilder.seasonal(
            from: days(),
            startingMonth: seasonStart,
            constellations: [namedThread()],
            readerName: "Reader",
            seasonName: "My Own Word For It",
            now: boundAt,
            calendar: calendar
        )
        XCTAssertEqual(volume.resolvedCoverLine(), "My Own Word For It")
        XCTAssertEqual(volume.readerNamedSeason, "My Own Word For It")
        XCTAssertNil(volume.seasonTitleProposal, "The Book does not argue with a reader who has already named it.")
    }

    /// A quiet season should not be flattered with a grand title.
    func testASeasonWithNothingToGoOnStaysTitledByItsMonths() {
        let volume = season(named: nil)
        XCTAssertNil(volume.seasonTitleProposal)
        XCTAssertEqual(volume.resolvedCoverLine(), "March 2026 – May 2026")
    }

    // MARK: Softcover is the default

    /// The cheapest binding that is still a real book leads. Cloth, foil and
    /// board are the upsell, not the price of entry: about $3.20 of cover
    /// against $10.26 or $14.41 for a case.
    func testTheDefaultBindingIsTheSoftcover() {
        XCTAssertEqual(PrintSpec.allPrintableVariants.first?.coverTreatment, .perfectBound)
    }

    func testEveryBindingDescribesItselfDistinctly() {
        let moods = PrintSpec.CoverTreatment.allCases.map(\.mood)
        XCTAssertEqual(Set(moods).count, moods.count, "A binding describing itself as another one lies mid-purchase.")
        let notes = PrintSpec.CoverTreatment.allCases.map(\.coverPreviewNote)
        XCTAssertEqual(Set(notes).count, notes.count)
    }

    func testTheSoftcoverIsTheCheapestToMake() {
        let base = PrintSpec.allPrintableVariants.map(\.basePriceUSD)
        XCTAssertEqual(base.min(), PrintSpec.perfectBoundSoftcover6x9.basePriceUSD)
    }
}
