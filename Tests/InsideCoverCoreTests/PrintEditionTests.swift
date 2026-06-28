import XCTest
@testable import InsideCoverCore

/// The print geometry is the load-bearing math of the physical-book feature:
/// the spine width, the cover-wrap size, and the padded page count all have to
/// be exactly right or the bindery rejects the file. These pin the arithmetic.
final class PrintEditionTests: XCTestCase {
    private let spec = PrintSpec.hardcover6x9

    func testBoundPageCountIsAlwaysEven() {
        XCTAssertEqual(PrintGeometry.boundPageCount(rawPages: 41, spec: spec), 42)
        XCTAssertEqual(PrintGeometry.boundPageCount(rawPages: 42, spec: spec), 42)
    }

    func testBoundPageCountRespectsBindingMinimum() {
        // A thin month is padded up to the binding's minimum (which is itself even).
        XCTAssertEqual(PrintGeometry.boundPageCount(rawPages: 6, spec: spec), spec.minimumPages)
        XCTAssertEqual(spec.minimumPages % 2, 0, "the minimum must already be even")
    }

    func testSpineWidthScalesWithPages() {
        XCTAssertEqual(PrintGeometry.spineWidthInches(pageCount: 100, spec: spec),
                       100 * spec.caliperPerPageInches, accuracy: 1e-9)
        // More pages, thicker spine.
        XCTAssertGreaterThan(PrintGeometry.spineWidthInches(pageCount: 200, spec: spec),
                             PrintGeometry.spineWidthInches(pageCount: 100, spec: spec))
    }

    func testFullBleedTrimAddsBleedToEveryEdge() {
        let fb = PrintGeometry.fullBleedTrimInches(spec: spec)
        XCTAssertEqual(fb.width, 6.0 + 0.25, accuracy: 1e-9)   // 0.125 each side
        XCTAssertEqual(fb.height, 9.0 + 0.25, accuracy: 1e-9)
    }

    func testCoverWrapSpansBothPanelsPlusSpineAndMargins() {
        let pages = 120
        let spine = PrintGeometry.spineWidthInches(pageCount: pages, spec: spec)
        let wrap = PrintGeometry.coverWrapSizeInches(pageCount: pages, spec: spec)
        XCTAssertEqual(wrap.width, spec.coverWrapMarginInches * 2 + spec.trimWidthInches * 2 + spine, accuracy: 1e-9)
        XCTAssertEqual(wrap.height, spec.coverWrapMarginInches * 2 + spec.trimHeightInches, accuracy: 1e-9)
    }

    func testPanelsTileLeftToRightWithoutGaps() {
        let pages = 120
        let panels = PrintGeometry.coverPanelsInches(pageCount: pages, spec: spec)
        let wrap = PrintGeometry.coverWrapSizeInches(pageCount: pages, spec: spec)
        // back | spine | front, each abutting the next.
        XCTAssertEqual(panels.backX, spec.coverWrapMarginInches, accuracy: 1e-9)
        XCTAssertEqual(panels.spineX, panels.backX + spec.trimWidthInches, accuracy: 1e-9)
        XCTAssertEqual(panels.frontX, panels.spineX + panels.spineWidth, accuracy: 1e-9)
        // the front panel ends exactly one wrap-margin shy of the canvas edge.
        XCTAssertEqual(panels.frontX + spec.trimWidthInches + spec.coverWrapMarginInches,
                       wrap.width, accuracy: 1e-9)
    }

    func testDefaultSpecIsPrintSane() {
        XCTAssertGreaterThan(spec.bleedInches, 0)
        XCTAssertGreaterThan(spec.interiorMarginsPoints.left, spec.interiorMarginsPoints.right,
                             "the binding side needs the extra gutter")
        XCTAssertFalse(spec.luluPackageID.isEmpty)
    }
}
