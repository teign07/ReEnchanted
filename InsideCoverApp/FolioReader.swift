import CoreImage
import Foundation
import UIKit
import Vision

/// Reads the address off a photograph of a printed page.
///
/// A reader who has scribbled on, torn, stained or taped a page photographs it;
/// the folio at its foot names the book and the page. Vision reads the whole
/// frame, because a handheld photo is never cropped to the folio, and the
/// registry sorts the lookalikes from the real thing (see
/// `PageAddress.parseAll`).
enum FolioReader {
    struct Result: Equatable {
        var volume: BoundVolumeRegistry
        var page: Int
    }

    /// Every line of text Vision can find in the image, in reading order.
    static func recognisedText(in image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // The folio is small and set in italic; do not let the language model
        // "correct" a code into a word.
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.004
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return "" }
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// The foot of the frame, magnified: the folio is small type, and a whole-
    /// frame pass can spend its attention on the page's prose instead.
    private static func footStrip(of image: CGImage, fraction: CGFloat) -> CGImage? {
        let height = Int(CGFloat(image.height) * fraction)
        guard height > 8,
              let strip = image.cropping(to: CGRect(x: 0, y: image.height - height, width: image.width, height: height)) else { return nil }
        let scale = 2
        guard let context = CGContext(
            data: nil, width: strip.width * scale, height: strip.height * scale, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(strip, in: CGRect(x: 0, y: 0, width: strip.width * scale, height: strip.height * scale))
        return context.makeImage()
    }

    /// The page this photograph shows, if it is a page of a volume the reader
    /// sent to the press. A whole-frame read first, then the foot of the frame
    /// at two heights, because a handheld photo tilts the folio out of any one
    /// crop. A wrong answer is far worse than none: nothing here guesses.
    static func identify(_ image: CGImage, among registries: [BoundVolumeRegistry]) -> Result? {
        var attempts: [CGImage] = [image]
        for fraction: CGFloat in [0.2, 0.34] {
            if let strip = footStrip(of: image, fraction: fraction) { attempts.append(strip) }
        }
        for attempt in attempts {
            let text = recognisedText(in: attempt)
            if let found = registries.volume(for: text) {
                return Result(volume: found.volume, page: found.page)
            }
        }
        return nil
    }
}
