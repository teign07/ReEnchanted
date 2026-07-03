import XCTest
import CoreGraphics
import ImageIO
@testable import InsideCoverCore

final class PressedPhotographTests: XCTestCase {

    // MARK: targetSize (pure math)

    func testOversizedLandscapeScalesLongSideToMax() {
        let size = PressedPhotograph.targetSize(width: 4000, height: 3000, maxLongSide: 2048)
        XCTAssertEqual(size.width, 2048)
        XCTAssertEqual(size.height, 1536)
    }

    func testOversizedPortraitScalesLongSideToMax() {
        let size = PressedPhotograph.targetSize(width: 3000, height: 4000, maxLongSide: 2048)
        XCTAssertEqual(size.height, 2048)
        XCTAssertEqual(size.width, 1536)
    }

    func testSmallImagePassesThroughUnscaled() {
        let size = PressedPhotograph.targetSize(width: 800, height: 600, maxLongSide: 2048)
        XCTAssertEqual(size.width, 800)
        XCTAssertEqual(size.height, 600)
    }

    func testSquareOversizedClampsBothSides() {
        let size = PressedPhotograph.targetSize(width: 3000, height: 3000, maxLongSide: 2048)
        XCTAssertEqual(size.width, 2048)
        XCTAssertEqual(size.height, 2048)
    }

    // MARK: downscaledJPEG (round trip through ImageIO)

    func testDownscaleShrinksLongSideAndStaysDecodable() throws {
        let source = try makeJPEG(width: 4000, height: 2000)
        let out = try XCTUnwrap(PressedPhotograph.downscaledJPEG(from: source, maxLongSide: 2048))
        let dims = try pixelSize(of: out)
        XCTAssertLessThanOrEqual(max(dims.width, dims.height), 2048)
        // Aspect ratio preserved: 2:1 source stays ~2:1.
        XCTAssertEqual(Double(dims.width) / Double(dims.height), 2.0, accuracy: 0.05)
    }

    func testDownscaleRejectsNonImageData() {
        XCTAssertNil(PressedPhotograph.downscaledJPEG(from: Data([0x00, 0x01, 0x02])))
    }

    // MARK: helpers

    private func makeJPEG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try XCTUnwrap(context.makeImage())
        let out = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, cgImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let w = try XCTUnwrap(props[kCGImagePropertyPixelWidth] as? Int)
        let h = try XCTUnwrap(props[kCGImagePropertyPixelHeight] as? Int)
        return (w, h)
    }
}
