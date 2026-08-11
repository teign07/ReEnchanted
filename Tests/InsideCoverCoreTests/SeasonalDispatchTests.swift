import XCTest
@testable import InsideCoverCore

/// The shipping window for a Bound Year seasonal volume.
///
/// The membership is prepaid, so the window is not a permission slip. These
/// tests exist to stop a future refactor turning it into one: the load-bearing
/// rule is that **silence ships the book**, and the only thing that stops the
/// clock is a hold, which defers and never forfeits.
final class SeasonalDispatchTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var boundAt: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)) ?? Date()
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour)) ?? boundAt
    }

    private func volume(seasonName: String? = nil) -> AnnualEdition {
        let seasonStart = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 9)) ?? boundAt
        let days = (0..<90).compactMap { offset -> BookDay? in
            guard offset % 3 == 0,
                  let d = calendar.date(byAdding: .day, value: offset, to: seasonStart) else { return nil }
            let dayID = BookDay.id(for: d, calendar: calendar)
            return BookDay(
                id: dayID,
                date: calendar.startOfDay(for: d),
                pages: [
                    BookPage(id: "s-\(dayID)", type: .souvenir, createdAt: d,
                             promptText: "One true sentence", userInput: "The harbour kept \(dayID).")
                ]
            )
        }
        return MonthlyEditionBuilder.seasonal(
            from: days,
            startingMonth: seasonStart,
            readerName: "Reader",
            seasonName: seasonName,
            now: boundAt,
            calendar: calendar
        )
    }

    private func dispatch(seasonName: String? = nil) -> SeasonalDispatch {
        SeasonalDispatchWindow.open(
            seasonKey: "2026-Q2",
            volume: volume(seasonName: seasonName),
            boundAt: boundAt,
            calendar: calendar
        )
    }

    // MARK: Opening

    func testAWindowOpensForSevenDaysAndDefaultsToThePerfectBoundVolume() {
        let d = dispatch()
        XCTAssertEqual(d.seasonKey, "2026-Q2")
        XCTAssertEqual(d.variantID, "perfect-bound-softcover-6x9")
        XCTAssertEqual(d.daysRemaining(now: boundAt, calendar: calendar), SeasonalDispatchWindow.windowDays)
        XCTAssertTrue(d.isOpen(now: boundAt))
        XCTAssertFalse(d.hasPosted)
    }

    func testTheWindowCarriesTheBooksProposedTitle() {
        XCTAssertEqual(dispatch().coverLine, "March 2026 – May 2026")
    }

    // MARK: The load-bearing rule

    /// A prepaid volume the reader never opened still posts. The window was an
    /// offer to steer, not a gate to pass.
    func testDoingNothingShipsTheBook() {
        let d = dispatch()
        XCTAssertFalse(SeasonalDispatchWindow.shouldPost(d, now: date(3)))
        XCTAssertTrue(
            SeasonalDispatchWindow.shouldPost(d, now: date(8)),
            "Silence is consent here: they already paid for this volume."
        )
    }

    func testAPostedVolumeNeverPostsTwice() {
        let posted = SeasonalDispatchWindow.markPosted(dispatch(), at: date(8))
        XCTAssertFalse(SeasonalDispatchWindow.shouldPost(posted, now: date(30)))
        XCTAssertFalse(posted.isOpen(now: date(9)))
    }

    // MARK: Naming

    func testDedicationBelongsToThisDispatchAndCanBeCleared() throws {
        let words = try XCTUnwrap(BoundDedication(text: "For M., who noticed first."))
        let dedicated = SeasonalDispatchWindow.dedicate(dispatch(), with: words)
        XCTAssertEqual(dedicated.dedication, words)
        XCTAssertNil(SeasonalDispatchWindow.dedicate(dedicated, with: nil).dedication)
    }

    func testRenamingReplacesTheTitleAndStopsTheBookArguing() {
        let renamed = SeasonalDispatchWindow.rename(dispatch(), to: "The Long Thaw")
        XCTAssertEqual(renamed.coverLine, "The Long Thaw")
        XCTAssertEqual(renamed.readerNamedSeason, "The Long Thaw")
        XCTAssertNil(renamed.titleProposal, "The Book does not keep offering after it has been overruled.")
    }

    func testABlankRenameChangesNothing() {
        let original = dispatch()
        XCTAssertEqual(SeasonalDispatchWindow.rename(original, to: "   "), original)
    }

    // MARK: Hold, never skip

    /// The whole point: a hold defers and never forfeits. Nothing expires while
    /// it waits, so there is never a volume the reader paid for and lost.
    func testAHoldStopsTheClockWithoutLosingTheVolume() {
        let held = SeasonalDispatchWindow.hold(dispatch(), at: date(3))
        XCTAssertTrue(held.isHeld)
        XCTAssertNil(held.shipsAt)
        XCTAssertFalse(held.hasPosted)
        XCTAssertFalse(
            SeasonalDispatchWindow.shouldPost(held, now: date(400)),
            "A held volume waits indefinitely rather than expiring."
        )
        XCTAssertTrue(held.isOpen(now: date(400)), "It can still be named and released a year later.")
    }

    func testReleasingAHoldGivesAFreshWindowRatherThanShippingAtOnce() {
        let held = SeasonalDispatchWindow.hold(dispatch(), at: date(3))
        let released = SeasonalDispatchWindow.release(held, at: date(20), calendar: calendar)
        XCTAssertFalse(released.isHeld)
        XCTAssertFalse(
            SeasonalDispatchWindow.shouldPost(released, now: date(21)),
            "Coming back to a volume set aside months ago deserves the same chance to name it."
        )
        XCTAssertTrue(SeasonalDispatchWindow.shouldPost(released, now: date(28)))
    }

    func testHoldingAPostedVolumeIsMeaningless() {
        let posted = SeasonalDispatchWindow.markPosted(dispatch(), at: date(8))
        XCTAssertFalse(SeasonalDispatchWindow.hold(posted, at: date(9)).isHeld)
    }

    // MARK: Address and upsells

    func testAddressStartsUnconfirmedAndTheWindowIsWhereThatGetsFixed() {
        XCTAssertTrue(dispatch().needsAddressConfirmation)
        let confirmed = SeasonalDispatchWindow.confirmAddress(dispatch(), at: date(2))
        XCTAssertFalse(confirmed.needsAddressConfirmation)
    }

    /// The same choices must always price the same, or the Worker's amount
    /// check will reject an order that only differs by tap order.
    func testChosenOptionsAreDeduplicatedAndOrdered() {
        let chosen = SeasonalDispatchWindow.choose(
            dispatch(),
            optionIDs: ["foil-spine", "photo-cover", "foil-spine"]
        )
        XCTAssertEqual(chosen.selectedOptionIDs, ["foil-spine", "photo-cover"])
        let reordered = SeasonalDispatchWindow.choose(
            dispatch(),
            optionIDs: ["photo-cover", "foil-spine"]
        )
        XCTAssertEqual(chosen.selectedOptionIDs, reordered.selectedOptionIDs)
    }

    func testCoverAuthorshipIsIncludedAndStoredOnTheDispatch() {
        let plated = SeasonalDispatchWindow.chooseCover(
            dispatch(),
            choice: .binderyPlate,
            plateID: "moth"
        )
        XCTAssertEqual(plated.resolvedCoverChoice, .binderyPlate)
        XCTAssertEqual(plated.coverPlateID, "moth")
        XCTAssertNil(plated.coverPhotoFilename)

        let photographed = SeasonalDispatchWindow.chooseCover(
            plated,
            choice: .readerPhoto,
            photoFilename: "season.jpg",
            photoFocus: PublicationCoverFocus(x: 0.23, y: 0.41)
        )
        XCTAssertEqual(photographed.resolvedCoverChoice, .readerPhoto)
        XCTAssertNil(photographed.coverPlateID)
        XCTAssertEqual(photographed.coverPhotoFilename, "season.jpg")
        XCTAssertEqual(photographed.coverPhotoFocus, PublicationCoverFocus(x: 0.23, y: 0.41))

        let reset = SeasonalDispatchWindow.chooseCover(photographed, choice: .bookChooses)
        XCTAssertNil(reset.coverPhotoFilename)
        XCTAssertNil(reset.coverPhotoFocus)
    }

    func testPublicationCoverFocusClampsAuthoredCoordinates() {
        XCTAssertEqual(PublicationCoverFocus(x: -4, y: 9), PublicationCoverFocus(x: 0, y: 1))
    }

    func testAnnualUsesIncludedCasewrapWhenItsCoverMustPrintAnImage() {
        var annual = dispatch()
        annual.chapterCount = 12
        annual.variantID = PhysicalBookVariant.id(for: .linenWrap)

        let photographed = SeasonalDispatchWindow.chooseCover(
            annual,
            choice: .readerPhoto,
            photoFilename: "annual.jpg"
        )
        XCTAssertEqual(photographed.variantID, PhysicalBookVariant.id(for: .caseWrap))

        let bookChooses = SeasonalDispatchWindow.chooseCover(photographed, choice: .bookChooses)
        XCTAssertEqual(bookChooses.variantID, PhysicalBookVariant.id(for: .linenWrap))
    }

    func testDaysRemainingNeverGoesNegative() {
        XCTAssertEqual(dispatch().daysRemaining(now: date(30), calendar: calendar), 0)
    }

    // MARK: The Book's voice

    /// `BookVoice.animismLine` is explicit: never "announce that something is
    /// optional, allowed, pressure-free, or waiting until the reader is ready."
    /// The first draft of the dispatch Page said "You do not have to do any of
    /// that", which is exactly that, in exactly those words. There is already a
    /// commit in this repo called "the Book had gone formal"; this is the guard
    /// so it does not happen a third time.
    func testTheDoorsNeverAnnounceThatSomethingIsOptional() {
        let banned = ["you don't have to", "you do not have to", "no pressure",
                      "if you're ready", "when you're ready", "feel free", "optional"]
        for action in SeasonalDispatchAction.allCases {
            let copy = "\(action.label) \(action.aside)".lowercased()
            for phrase in banned {
                XCTAssertFalse(copy.contains(phrase), "\(action.rawValue) reassures: \(copy)")
            }
        }
    }

    /// Labels are the Book's, not an interface's.
    func testDoorsAreNotNamedLikeASettingsScreen() {
        let interfaceWords = ["manage", "options", "settings", "configure", "edit", "preferences"]
        for action in SeasonalDispatchAction.allCases {
            let label = action.label.lowercased()
            for word in interfaceWords {
                XCTAssertFalse(label.contains(word), "\(action.rawValue) sounds like a form: \(label)")
            }
        }
    }

    /// The three authorship choices belong with the volume itself; address,
    /// holds, paid rebinding, and extra copies still open elsewhere.
    func testOnlyEditorialAuthorshipIsAnsweredOnThePageItself() {
        let inline = SeasonalDispatchAction.allCases.filter(\.isInline)
        XCTAssertEqual(inline, [.rename, .cover, .dedication])
    }

    func testAHeldSeasonOffersToGoAndNotToWaitAgain() {
        let held = SeasonalDispatchWindow.hold(dispatch(), at: date(3))
        let doors = SeasonalDispatchWindow.actions(for: held)
        XCTAssertTrue(doors.contains(.release))
        XCTAssertFalse(doors.contains(.hold), "It is already waiting; offering to wait again is noise.")
        XCTAssertFalse(doors.contains(.rebind), "A paid binding change needs a checkout before it can be offered.")
        XCTAssertFalse(doors.contains(.giftCopy), "An extra copy is not part of the prepaid parcel.")
    }

    func testAPostedSeasonOffersNothing() {
        let posted = SeasonalDispatchWindow.markPosted(dispatch(), at: date(8))
        XCTAssertTrue(SeasonalDispatchWindow.actions(for: posted).isEmpty)
    }

    // MARK: The Pressing

    /// The stages exist so the ceremony can animate against real work. Every
    /// working stage needs something to say, or the reader is watching stitches
    /// with no idea what is happening.
    func testEveryWorkingStageSpeaks() {
        for stage in PhysicalBookPressStage.allCases where stage != .idle {
            XCTAssertFalse(stage.line.isEmpty, "\(stage.rawValue) is mute")
        }
        XCTAssertTrue(PhysicalBookPressStage.idle.line.isEmpty)
    }

    func testOnlyTheMiddleStagesAreWork() {
        XCTAssertEqual(
            PhysicalBookPressStage.allCases.filter(\.isWorking),
            [.sewing, .sending]
        )
    }

    /// The money is already taken by the time the press runs, so a jam must
    /// never imply the pages are gone. It says they are kept.
    func testAStallPromisesNothingIsLost() {
        let stalled = PhysicalBookPressStage.stalled.line.lowercased()
        XCTAssertTrue(stalled.contains("nothing's lost") || stalled.contains("kept"))
    }

    /// Same voice rules as the dispatch doors: the Book narrating its own work,
    /// not a progress bar with a vocabulary.
    func testThePressNeverTalksLikeAProgressBar() {
        let machineWords = ["uploading", "submitting", "processing", "please wait",
                            "in progress", "step 1", "loading"]
        for stage in PhysicalBookPressStage.allCases {
            let line = stage.line.lowercased()
            for word in machineWords {
                XCTAssertFalse(line.contains(word), "\(stage.rawValue) sounds like a spinner: \(line)")
            }
        }
    }

    // MARK: The keepsake

    private func keepsake(copies: Int, region: String? = "ME, US") -> PressedVolumeKeepsake {
        PressedVolumeKeepsake(
            id: "2026-06-perfect-bound-softcover-6x9",
            coverLine: "June 2026",
            bindingName: "6 × 9 Softcover, perfect bound",
            pressedAt: boundAt,
            destinationRegion: region,
            copies: copies
        )
    }

    /// A purchase the Book remembers is a going-away, not a receipt.
    func testTheKeepsakeReadsAsAPageNotAReceipt() {
        let line = keepsake(copies: 1).line().lowercased()
        for word in ["order", "receipt", "purchase", "total", "payment", "confirmed", "tracking"] {
            XCTAssertFalse(line.contains(word), "keepsake sounds like a receipt: \(line)")
        }
        XCTAssertTrue(line.contains("i sent"))
    }

    func testTheKeepsakeCountsCopiesInWords() {
        XCTAssertTrue(keepsake(copies: 1).line().contains("It went alone."))
        XCTAssertTrue(keepsake(copies: 2).line().contains("Two of them went"))
        XCTAssertTrue(keepsake(copies: 4).line().contains("4 of them went"))
    }

    /// The archive has no business holding a street address.
    func testAKeepsakeWithNoRegionSaysNothingAboutWhereItWent() {
        let line = keepsake(copies: 1, region: nil).line()
        XCTAssertFalse(line.contains("Bound for"))
        XCTAssertTrue(line.contains("June 2026"))
    }

    // MARK: The ceremony cannot lie

    /// A stall must not finish the spine. The stitches stop where the work did.
    func testAStalledPressNeverCompletesTheStitching() {
        XCTAssertLessThan(PhysicalBookPressStage.stalled.progress, 1.0)
        XCTAssertEqual(PhysicalBookPressStage.gone.progress, 1.0)
    }

    func testProgressOnlyEverMovesForward() {
        let order: [PhysicalBookPressStage] = [.idle, .sewing, .sending, .gone]
        let values = order.map(\.progress)
        XCTAssertEqual(values, values.sorted())
    }
}
