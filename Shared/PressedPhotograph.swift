import Foundation
import ImageIO
import CoreGraphics
#if canImport(MobileCoreServices)
import MobileCoreServices
#endif
import UniformTypeIdentifiers

/// A photograph pressed between the pages of an ordinary kept page. Downscales
/// and re-encodes to JPEG so the archive (and every sealed copy that carries
/// it) stays light. Uses ImageIO, so the math and the encode both run on the
/// macOS test host as well as on device.
enum PressedPhotograph {
    /// Longest edge, in pixels, a pressed photograph is scaled down to.
    static let defaultMaxLongSide = 2048
    static let defaultQuality: CGFloat = 0.8

    /// Target pixel size for a source of the given dimensions: scaled down so
    /// the longest side is at most `maxLongSide`, preserving aspect ratio.
    /// Images already within bounds pass through unchanged. Pure.
    static func targetSize(width: Int, height: Int, maxLongSide: Int = defaultMaxLongSide) -> (width: Int, height: Int) {
        let longSide = max(width, height)
        guard longSide > maxLongSide, longSide > 0 else { return (width, height) }
        let scale = Double(maxLongSide) / Double(longSide)
        let w = max(1, Int((Double(width) * scale).rounded()))
        let h = max(1, Int((Double(height) * scale).rounded()))
        return (w, h)
    }

    /// Downscale image `data` so its longest side is at most `maxLongSide` and
    /// re-encode as JPEG. Returns nil if the data isn't a decodable image.
    static func downscaledJPEG(
        from data: Data,
        maxLongSide: Int = defaultMaxLongSide,
        quality: CGFloat = defaultQuality
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongSide,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let type: CFString
        if #available(iOS 14.0, macOS 11.0, *) {
            type = UTType.jpeg.identifier as CFString
        } else {
            type = "public.jpeg" as CFString
        }
        let outData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outData, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return outData as Data
    }
}
