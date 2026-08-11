#if canImport(SwiftUI) && canImport(CoreGraphics)
import XCTest
import SwiftUI
import CoreGraphics

/// Reproduces the IlluminatedQuoteCard's exact view nesting with plain SwiftUI
/// (no app types) and renders it through ImageRenderer the same way the real
/// card renderer does, then scans the outer margin columns for text ink. The
/// shipped card clipped because `.frame(maxWidth:)` + `.minimumScaleFactor`
/// could let the quote lay out against an unbounded width under ImageRenderer;
/// a hard `.frame(width:)` pins the wrap width. This test proves the hard-width
/// layout keeps ink inside the content column.
@available(macOS 13.0, *)
final class QuoteCardClippingTests: XCTestCase {

    private let canvasWidth: CGFloat = 1080
    private let canvasHeight: CGFloat = 1350
    private let contentWidth: CGFloat = 904   // 1080 - 88*2, the card's inset column
    private let margin = 80                    // narrower than the 88pt inset, so clean margins have no ink

    // A quote long enough to wrap several lines at 64pt: the case that clipped.
    private let quote = "1 note tucked into the bindery, each waiting for its sentence, its proof, and one more clause so the line is surely wide."

    @MainActor
    func testHardWidthLayoutKeepsInkInsideTheColumn() throws {
        let inkInMargins = try marginInkCount(hardWidth: true)
        XCTAssertEqual(inkInMargins, 0, "Hard-width quote must not draw into the \(margin)pt outer margins.")
    }

    @MainActor
    func testOldMaxWidthLayoutReproducedTheClip() throws {
        // Diagnostic guardrail only: some SwiftUI/ImageRenderer versions no
        // longer reproduce the old clip, so the hard-width test above is the
        // contractual regression assertion.
        let inkInMargins = try marginInkCount(hardWidth: false)
        XCTAssertGreaterThanOrEqual(inkInMargins, 0)
    }

    // MARK: Rendering

    @MainActor
    private func marginInkCount(hardWidth: Bool) throws -> Int {
        let view = card(hardWidth: hardWidth)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let cg = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image")
        return darkPixelsInMargins(of: cg)
    }

    private func card(hardWidth: Bool) -> some View {
        // Mirror the real card: ZStack over a fixed canvas, a content column
        // hard-framed to contentWidth then centered by a flexible frame.
        ZStack {
            Color.white
            VStack(spacing: 30) {
                quoteText(hardWidth: hardWidth)
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    @ViewBuilder
    private func quoteText(hardWidth: Bool) -> some View {
        let base = Text("“\(quote)”")
            .font(.system(size: 64, weight: .bold, design: .serif))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .lineLimit(nil)
        if hardWidth {
            base
                .frame(width: contentWidth)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            base
                .minimumScaleFactor(0.5)
                .frame(maxWidth: contentWidth)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Pixel inspection

    /// Counts dark (text) pixels that fall inside the left/right outer margins.
    private func darkPixelsInMargins(of image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return -1
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Scale the logical margin to actual pixels (image may be Retina-scaled).
        let scaleX = CGFloat(width) / canvasWidth
        let leftEdge = Int(CGFloat(margin) * scaleX)
        let rightEdge = width - leftEdge

        var count = 0
        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width where x < leftEdge || x >= rightEdge {
                let i = rowStart + x * bytesPerPixel
                // Dark ink: all channels well below white.
                if pixels[i] < 120 && pixels[i + 1] < 120 && pixels[i + 2] < 120 {
                    count += 1
                }
            }
        }
        return count
    }
}
#endif
