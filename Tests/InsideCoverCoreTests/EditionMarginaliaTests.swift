import XCTest
@testable import InsideCoverCore

/// The bound edition composes from the one shared cabinet.
///
/// These guard the half that decides. A printed page cannot be scrolled away
/// from, so the rules that matter here are the ones about restraint: nothing on
/// top of a sentence, nothing off the trimmed edge, and the same month bound
/// twice producing the same paper.
final class EditionMarginaliaTests: XCTestCase {

    /// A US Letter reading leaf with the edition's real margins.
    private func geometry(inkBottom: CGFloat = 400) -> EditionMarginalia.LeafGeometry {
        EditionMarginalia.LeafGeometry(
            bounds: CGRect(x: 0, y: 0, width: 612, height: 792),
            contentLeft: 120,
            contentRight: 554,
            contentTop: 60,
            contentBottom: 728,
            inkBottom: inkBottom
        )
    }

    private func plan(
        kind: EditionMarginalia.LeafKind,
        motifs: [String] = ["harbor", "quiet", "book"],
        reserved: [CGRect] = [],
        seed: String = "edition-2026-08|page3",
        inkBottom: CGFloat = 400
    ) -> EditionMarginalia.LeafPlan {
        EditionMarginalia.compose(
            kind: kind,
            motifs: motifs,
            placementContext: .empty,
            geometry: geometry(inkBottom: inkBottom),
            reservedInk: reserved,
            seed: seed
        )
    }

    // MARK: - Restraint

    /// A bound photograph is the subject of its own leaf.
    func testAPlateLeafCarriesNoMarks() {
        XCTAssertTrue(plan(kind: .plate).marks.isEmpty)
    }

    func testNoLeafExceedsItsForegroundBudget() {
        for kind in EditionMarginalia.LeafKind.allCases {
            for page in 0..<40 {
                let marks = plan(kind: kind, seed: "budget-\(kind.rawValue)-\(page)").marks
                let foreground = marks.filter { $0.slot != .watermark }
                XCTAssertLessThanOrEqual(
                    foreground.count, kind.foregroundBudget,
                    "\(kind.rawValue) spent \(foreground.count) of \(kind.foregroundBudget)"
                )
                XCTAssertLessThanOrEqual(
                    marks.filter { $0.slot == .watermark }.count, 1,
                    "\(kind.rawValue) laid down more than one watermark"
                )
            }
        }
    }

    /// The whole point of the collision map: a printed mark that lands on a
    /// sentence cannot be moved by the reader.
    func testAMarkNeverLandsOnMeasuredInk() {
        let column = CGRect(x: 120, y: 60, width: 434, height: 340)
        let gutterNote = CGRect(x: 30, y: 200, width: 72, height: 140)

        for kind in EditionMarginalia.LeafKind.allCases {
            for page in 0..<60 {
                let marks = plan(
                    kind: kind,
                    reserved: [column, gutterNote],
                    seed: "collide-\(kind.rawValue)-\(page)"
                ).marks
                for mark in marks where mark.slot != .watermark {
                    XCTAssertFalse(
                        mark.rect.intersects(column),
                        "\(mark.assetName) landed on the text column on a \(kind.rawValue) leaf"
                    )
                    XCTAssertFalse(
                        mark.rect.intersects(gutterNote),
                        "\(mark.assetName) landed on a taped margin note"
                    )
                }
            }
        }
    }

    /// Two marks on one leaf must not overlap each other either.
    func testAcceptedMarksDoNotOverlapEachOther() {
        for page in 0..<60 {
            let marks = plan(kind: .closing, seed: "stack-\(page)").marks
                .filter { $0.slot != .watermark }
            for (index, mark) in marks.enumerated() {
                for other in marks.dropFirst(index + 1) {
                    XCTAssertFalse(
                        mark.rect.intersects(other.rect),
                        "\(mark.assetName) and \(other.assetName) were both accepted on the same paper"
                    )
                }
            }
        }
    }

    func testEveryMarkStaysOnTheTrimmedPage() {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        for kind in EditionMarginalia.LeafKind.allCases {
            for index in 0..<40 {
                for mark in plan(kind: kind, seed: "trim-\(kind.rawValue)-\(index)").marks {
                    XCTAssertTrue(
                        page.contains(mark.rect),
                        "\(mark.assetName) ran off the trimmed edge at \(mark.rect)"
                    )
                }
            }
        }
    }

    // MARK: - The one intentional overlap

    /// A watermark is the only mark allowed under prose, and only if the mark
    /// itself says it may lie there.
    func testOnlyMarksThatClaimOverlapEverBecomeWatermarks() {
        var seenWatermark = false
        for kind in EditionMarginalia.LeafKind.allCases {
            for index in 0..<80 {
                let marks = plan(kind: kind, seed: "wm-\(kind.rawValue)-\(index)").marks
                for mark in marks where mark.slot == .watermark {
                    seenWatermark = true
                    XCTAssertTrue(
                        kind.allowsWatermark,
                        "\(kind.rawValue) is not supposed to carry a watermark"
                    )
                    XCTAssertLessThanOrEqual(
                        mark.opacity, 0.16,
                        "\(mark.assetName) is too strong to read a sentence through"
                    )
                }
                // Nothing else may claim overlap.
                for mark in marks where mark.slot != .watermark {
                    XCTAssertNotEqual(mark.slot, .watermark)
                }
            }
        }
        XCTAssertTrue(seenWatermark, "The faint layer never fired; the rule is untested.")
    }

    func testAReadingLeafNeverLiesUnderItsOwnProse() {
        for index in 0..<80 {
            let marks = plan(kind: .reading, seed: "reading-\(index)").marks
            XCTAssertTrue(
                marks.allSatisfy { $0.slot != .watermark },
                "An ordinary reading leaf should stay clean under the text"
            )
        }
    }

    // MARK: - The same month binds the same way

    func testCompositionIsDeterministic() {
        for kind in EditionMarginalia.LeafKind.allCases {
            let first = plan(kind: kind, seed: "stable-\(kind.rawValue)")
            let second = plan(kind: kind, seed: "stable-\(kind.rawValue)")
            XCTAssertEqual(first, second, "\(kind.rawValue) did not bind the same way twice")
        }
    }

    func testDifferentLeavesGetDifferentPaper() {
        let plans = (0..<40).map { plan(kind: .sectionOpener, seed: "vary-\($0)") }
        let signatures = Set(plans.map { $0.marks.map(\.assetName).joined(separator: "+") })
        XCTAssertGreaterThan(
            signatures.count, 5,
            "Every section opener composed identically; the seed is not reaching the choice."
        )
    }

    // MARK: - Using the cabinet well, not just reaching it

    /// The regression this guards is the first version of this feature: one
    /// shelf, one slot, every edition the same sprig.
    func testTheEditionReachesMoreThanOneShelf() {
        var shelves: Set<MarkShelf> = []
        // Several marks legitimately share one image name, so keep the first.
        let byName = Dictionary(
            IlluminationPackRegistry.shelvedMarks().map { ($0.asset.assetName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for kind in EditionMarginalia.LeafKind.allCases {
            for index in 0..<60 {
                for mark in plan(
                    kind: kind,
                    motifs: ["harbor", "moon", "letter", "quiet", "oak", "compass"],
                    seed: "shelf-\(kind.rawValue)-\(index)"
                ).marks {
                    if let shelved = byName[mark.assetName] { shelves.insert(shelved.shelf) }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(
            shelves.count, 3,
            "The bound edition only ever reached \(shelves.map(\.rawValue).sorted())"
        )
    }

    /// A leaf asks for the roles it actually wants. A colophon wanting a seal
    /// should not be handed the same specimen a section opener gets.
    func testLeavesPreferTheRolesTheyAskedFor() {
        // Several marks legitimately share one image name, so keep the first.
        let byName = Dictionary(
            IlluminationPackRegistry.shelvedMarks().map { ($0.asset.assetName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for kind in EditionMarginalia.LeafKind.allCases where !kind.preferredRoles.isEmpty {
            let wanted = Set(kind.preferredRoles)
            for index in 0..<40 {
                for mark in plan(kind: kind, seed: "role-\(kind.rawValue)-\(index)").marks
                where mark.slot != .watermark {
                    guard let role = byName[mark.assetName]?.asset.leafTraits?.semanticRole else { continue }
                    XCTAssertTrue(
                        wanted.contains(role),
                        "\(kind.rawValue) accepted a \(role.rawValue); it asked for \(kind.preferredRoles.map(\.rawValue))"
                    )
                }
            }
        }
    }

    /// Season is a real motif for a printed artifact: it is read in a month,
    /// and often long after.
    func testTheSeasonReachesTheChoice() {
        let december = EditionMarginalia.motifs(
            title: "December", prose: "", tags: [], pageTypes: [], month: 12
        )
        let may = EditionMarginalia.motifs(
            title: "May", prose: "", tags: [], pageTypes: [], month: 5
        )
        XCTAssertTrue(december.contains("holly"))
        XCTAssertTrue(may.contains("borage"))
        XCTAssertNotEqual(Set(december), Set(may))
    }

    /// Motifs come from three places — the leaf's own tags, its page types, and
    /// the Book-world vocabulary the folio reads out of prose. The third is the
    /// one worth guarding: a second lexicon here would drift from the folio's.
    func testMotifsReuseTheFolioVocabulary() {
        let prose = "We followed the fox past the library door under a full moon."
        let motifs = EditionMarginalia.motifs(
            title: "The month we kept walking",
            prose: prose,
            tags: ["kept"],
            pageTypes: [.weather],
            month: nil
        )
        XCTAssertTrue(motifs.contains("kept"))
        XCTAssertTrue(motifs.contains(BookPageType.weather.rawValue))

        let folio = LeafDecorationLibrary.semanticMotifs(in: prose)
        XCTAssertFalse(folio.isEmpty, "The folio lexicon should recognise this prose.")
        for motif in folio {
            XCTAssertTrue(
                motifs.contains(motif),
                "\(motif) reached the folio but not the bound edition"
            )
        }
        // The title is read with the same reader as the body.
        XCTAssertTrue(motifs.contains("walk"))
    }

    // MARK: - Geometry

    /// A tall specimen must stay tall. Squaring a foxglove off is the failure
    /// the trait exists to prevent.
    func testAMarkKeepsItsOwnProportions() {
        let field = CGRect(x: 0, y: 0, width: 200, height: 200)
        let tall = EditionMarginalia.fitted(
            aspectRatio: 0.5, within: field, maximum: CGSize(width: 100, height: 100), visualWeight: 1
        )
        XCTAssertEqual(tall.width / tall.height, 0.5, accuracy: 0.01)

        let wide = EditionMarginalia.fitted(
            aspectRatio: 2.0, within: field, maximum: CGSize(width: 100, height: 100), visualWeight: 1
        )
        XCTAssertEqual(wide.width / wide.height, 2.0, accuracy: 0.01)
    }

    func testAMarkNeverOutgrowsItsSlot() {
        let field = CGRect(x: 0, y: 0, width: 40, height: 40)
        let fit = EditionMarginalia.fitted(
            aspectRatio: 1, within: field, maximum: CGSize(width: 400, height: 400), visualWeight: 1.8
        )
        XCTAssertLessThanOrEqual(fit.width, field.width)
        XCTAssertLessThanOrEqual(fit.height, field.height)
    }

    /// The lower field only exists below the last line of prose. A leaf whose
    /// ink runs to the foot has no open paper to offer.
    func testAFullLeafOffersNoLowerField() {
        let full = geometry(inkBottom: 726)
        XCTAssertLessThan(full.lowerField.height, 20)

        let marks = EditionMarginalia.compose(
            kind: .closing,
            motifs: ["quiet"],
            placementContext: .empty,
            geometry: full,
            reservedInk: [CGRect(x: 120, y: 60, width: 434, height: 666)],
            seed: "full-leaf"
        ).marks
        XCTAssertTrue(marks.allSatisfy { $0.slot != .lowerField })
    }

    /// The renderer composes the outer regions before the prose is set, so it
    /// must be able to ask for exactly those.
    func testTheRendererCanRestrictCompositionToSafeRegions() {
        let outer: [EditionMarginalia.Slot] = [.gutterUpper, .headMargin, .footCorner]
        for index in 0..<40 {
            let marks = EditionMarginalia.compose(
                kind: .sectionOpener,
                motifs: ["oak", "quiet"],
                placementContext: .empty,
                geometry: geometry(),
                reservedInk: [],
                seed: "outer-\(index)",
                slots: outer,
                includeWatermark: false
            ).marks
            XCTAssertTrue(
                marks.allSatisfy { outer.contains($0.slot) },
                "Composition escaped the regions the renderer said were safe"
            )
        }
    }

    /// Gutter and head-corner marks live outside the reading column by
    /// construction. That is what lets the renderer place them before the prose
    /// exists — and what keeps them off the running head, which is printed at
    /// the top of the column on nearly every leaf.
    func testGutterMarksStayOutOfTheReadingColumn() {
        let page = geometry()
        for index in 0..<60 {
            let marks = EditionMarginalia.compose(
                kind: .sectionOpener,
                motifs: ["oak"],
                placementContext: .empty,
                geometry: page,
                reservedInk: [],
                seed: "gutter-\(index)",
                slots: [.gutterBand, .gutterUpper, .gutterMiddle, .gutterLower, .headMargin],
                includeWatermark: false
            ).marks
            for mark in marks {
                XCTAssertLessThanOrEqual(
                    mark.rect.maxX, page.contentLeft,
                    "\(mark.assetName) crossed into the reading column"
                )
                XCTAssertGreaterThanOrEqual(mark.rect.minX, 20, "\(mark.assetName) ran toward the trim")
            }
        }
    }

    /// The character shelves ship parts as well as whole marks. A goblin belongs
    /// in a margin; a detached goblin ear pinned beside a section title does
    /// not, and the first version of this composer printed one.
    func testConstructionPartsNeverReachAPrintedPage() {
        let byName = Dictionary(
            IlluminationPackRegistry.shelvedMarks().map { ($0.asset.assetName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for kind in EditionMarginalia.LeafKind.allCases {
            for index in 0..<80 {
                for mark in plan(
                    kind: kind,
                    motifs: ["goblin", "pixie", "academy", "ink"],
                    seed: "anatomy-\(kind.rawValue)-\(index)"
                ).marks {
                    let tags = byName[mark.assetName]?.asset.tags ?? []
                    XCTAssertFalse(
                        tags.contains("anatomy"),
                        "\(mark.assetName) is a construction piece, not a mark"
                    )
                }
            }
        }
    }

    /// Tape should vary with the mark it holds down.
    func testFasteningsAreNotAlwaysTheSameStrip() {
        var strips: Set<String> = []
        for kind in EditionMarginalia.LeafKind.allCases {
            for index in 0..<120 {
                for mark in plan(kind: kind, seed: "tape-\(kind.rawValue)-\(index)").marks {
                    if let tape = mark.fasteningAssetName { strips.insert(tape) }
                }
            }
        }
        XCTAssertGreaterThan(strips.count, 1, "Every mark was taped down with \(strips)")
    }
}
