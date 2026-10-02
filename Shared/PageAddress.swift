import Foundation

// MARK: - Page addresses
//
// Every printed leaf carries a small address in its folio, `41 · 7K3Q`: the
// page number and four characters derived from the volume's seed. A reader who
// photographs a page they have handled lets the app read the folio, find the
// volume, and know which page it is looking at. The alphabet leaves out the
// characters a camera confuses (0/O, 1/I/L, 5/S, 8/B, 2/Z), so a misread is a
// rejection, never a different page.

enum PageAddress {
    static let alphabet = Array("34679ACDEFGHJKMNPRTUVWXY")
    static let codeLength = 4

    /// The four characters printed beside page `page` of the volume `seed`.
    static func code(seed: String, page: Int) -> String {
        var hash = HandbookBuilder.stableHash("\(seed)|\(page)")
        var out = ""
        for _ in 0..<codeLength {
            out.append(alphabet[Int(hash % UInt64(alphabet.count))])
            hash /= UInt64(alphabet.count)
        }
        return out
    }

    /// What the folio prints: "41 · 7K3Q".
    static func label(seed: String, page: Int) -> String {
        "\(page) \u{00B7} \(code(seed: seed, page: page))"
    }

    struct Reading: Equatable {
        var page: Int
        var code: String
    }

    /// Every address-shaped thing in text a camera read off a page. A page of
    /// prose holds plenty of lookalikes ("3 Every" is a number and four letters
    /// in the alphabet), so the caller checks each against its registry rather
    /// than trusting the first. Tolerant of the dot, the spacing and the case;
    /// strict about the alphabet.
    static func parseAll(_ text: String) -> [Reading] {
        let scalars = Array(text.uppercased())
        let allowed = Set(alphabet)
        var found: [Reading] = []
        var index = 0
        while index < scalars.count {
            guard scalars[index].isNumber else { index += 1; continue }
            var end = index
            while end < scalars.count, scalars[end].isNumber { end += 1 }
            let number = String(scalars[index..<end])
            var cursor = end
            while cursor < scalars.count, " .\u{00B7}\u{2022}-\u{2013}\u{2014}\u{2212}*:".contains(scalars[cursor]) { cursor += 1 }
            let codeEnd = min(scalars.count, cursor + codeLength)
            if codeEnd - cursor == codeLength {
                let candidate = scalars[cursor..<codeEnd]
                if candidate.allSatisfy({ allowed.contains($0) }), let page = Int(number), page > 0 {
                    found.append(Reading(page: page, code: String(candidate)))
                }
            }
            index = end
        }
        return found
    }

    static func parse(_ text: String) -> Reading? { parseAll(text).first }
}

// MARK: - The volume registry

/// What the app remembers about a volume it sent to the press, so it can
/// recognise a page of it later.
struct BoundVolumeRegistry: Codable, Equatable, Identifiable {
    var id: String { seed }
    var seed: String
    var editionID: String
    var title: String
    var boundAt: Date
    var pageCount: Int
    /// Which pages were built to be handled, by page number: the ruin prompt
    /// each carries. Nil for volumes bound before ruin pages existed.
    var pageMap: [String: RuinPrompt]? = nil

    /// The ruin prompt printed on `page`, if it was one. A snapshot, so it
    /// reads the same however the prompt library has changed since.
    func ruinPrompt(onPage page: Int) -> RuinPrompt? { pageMap?[String(page)] }

    enum Identification: Equatable {
        case page(Int)
        case wrongVolume
        case unreadable
    }

    /// Whether `text`, read off a photograph, names a page of this volume.
    func identify(_ text: String) -> Identification {
        let readings = PageAddress.parseAll(text)
        guard !readings.isEmpty else { return .unreadable }
        for reading in readings where (1...max(1, pageCount)).contains(reading.page)
            && reading.code == PageAddress.code(seed: seed, page: reading.page) {
            return .page(reading.page)
        }
        return .wrongVolume
    }
}

extension Array where Element == BoundVolumeRegistry {
    /// The volume a photographed page belongs to, if any.
    func volume(for text: String) -> (volume: BoundVolumeRegistry, page: Int)? {
        for volume in self {
            if case .page(let page) = volume.identify(text) { return (volume, page) }
        }
        return nil
    }
}
