import UIKit
import PDFKit

// MARK: - The Field Book
//
// A month, kept the way a naturalist keeps a field journal: the date, the moon
// and the sky first; then what the world did that day; then what the reader
// did. Every mark on every leaf comes from something the Book actually holds:
// receipts for scenes the reader opened, pages they kept, photographs they
// took, the Academy's own timetable. A day with nothing earns no leaf, and no
// leaf is ever added to reach a page count.

extension UIFont {
    /// The Field Book's own serif faces: the same design as the rest of the
    /// edition, under names no other file claims.
    static func fbSerif(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size, weight: weight)
    }

    static func fbSerifItalic(ofSize size: CGFloat) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .withSymbolicTraits(.traitItalic)
        return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .italicSystemFont(ofSize: size)
    }
}

// MARK: Text flow

/// Text with `*italic*` runs, held as plain text plus italic ranges so that a
/// flow can stop mid-paragraph and the remainder keeps its emphasis.
struct FieldMarked: Equatable {
    var text: String
    var italics: [Range<Int>]   // character offsets into `text`

    init(text: String, italics: [Range<Int>] = []) {
        self.text = text
        self.italics = italics
    }

    /// Parses `*italic*` runs and drops the other bits of markup the authored
    /// scenes carry: `{placeholder}` tokens and a leading `> ` on a notice.
    init(parsing raw: String) {
        var cleaned = raw.replacingOccurrences(of: "\r", with: "")
        cleaned = cleaned.replacingOccurrences(
            of: "\\{[A-Za-z0-9_.\\-]+\\}", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\n> ", with: "\n").replacingOccurrences(of: "^> ", with: "", options: .regularExpression)
        // Single newlines are a paragraph break here; runs of them are one.
        cleaned = cleaned.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        var plain = ""
        var italics: [Range<Int>] = []
        var openAt: Int?
        var count = 0
        for character in cleaned {
            if character == "*" {
                if let start = openAt {
                    if count > start { italics.append(start..<count) }
                    openAt = nil
                } else {
                    openAt = count
                }
                continue
            }
            plain.append(character)
            count += 1
        }
        self.init(text: plain.trimmingCharacters(in: .whitespacesAndNewlines), italics: italics)
    }

    var isEmpty: Bool { text.isEmpty }

    /// Drops the first `n` characters, shifting the italics with them.
    func dropping(_ n: Int) -> FieldMarked {
        guard n > 0 else { return self }
        let chars = Array(text)
        let kept = String(chars.dropFirst(n))
        let shifted = italics.compactMap { range -> Range<Int>? in
            let lower = max(0, range.lowerBound - n), upper = range.upperBound - n
            return upper > lower ? lower..<upper : nil
        }
        // Leading whitespace is trimmed after the cut; keep the offsets true.
        let trimmedLead = kept.prefix { $0.isWhitespace }.count
        let final = String(kept.dropFirst(trimmedLead)).trimmingCharacters(in: .whitespacesAndNewlines)
        let adjusted = shifted.compactMap { range -> Range<Int>? in
            let lower = max(0, range.lowerBound - trimmedLead), upper = range.upperBound - trimmedLead
            return upper > lower ? lower..<upper : nil
        }
        return FieldMarked(text: final, italics: adjusted)
    }
}

/// TextKit flow with a finite container, so a long braid or scene can run on
/// to the next leaf without being clipped, and a drop cap can sit in the
/// margin of the first paragraph.
enum FieldText {
    struct Flow {
        var usedHeight: CGFloat
        var rest: FieldMarked
    }

    static func attributes(
        font: UIFont,
        color: UIColor,
        lineSpacing: CGFloat = 2.4,
        paragraphSpacing: CGFloat = 6,
        justified: Bool = true
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = paragraphSpacing
        paragraph.alignment = justified ? .justified : .natural
        paragraph.hyphenationFactor = 0.9
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }

    private static func italic(_ font: UIFont) -> UIFont {
        font.fontDescriptor.withSymbolicTraits(.traitItalic).map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
    }

    private static func attributed(_ marked: FieldMarked, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: marked.text, attributes: attributes)
        if let base = attributes[.font] as? UIFont {
            let slanted = italic(base)
            let length = (marked.text as NSString).length
            for range in marked.italics {
                // Offsets are in Characters; map to UTF-16 for NSRange.
                let chars = Array(marked.text)
                guard range.upperBound <= chars.count else { continue }
                let lower = String(chars[0..<range.lowerBound]).utf16.count
                let upper = String(chars[0..<range.upperBound]).utf16.count
                if upper <= length, upper > lower {
                    result.addAttribute(.font, value: slanted, range: NSRange(location: lower, length: upper - lower))
                }
            }
        }
        return result
    }

    private static func layout(
        _ marked: FieldMarked,
        attributes: [NSAttributedString.Key: Any],
        size: CGSize,
        exclusion: CGRect?
    ) -> (NSLayoutManager, NSTextContainer, NSTextStorage) {
        let storage = NSTextStorage(attributedString: attributed(marked, attributes: attributes))
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: size)
        container.lineFragmentPadding = 0
        if let exclusion { container.exclusionPaths = [UIBezierPath(rect: exclusion)] }
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        return (manager, container, storage)
    }

    /// The height `text` needs at `width`, uncapped.
    static func height(
        _ text: String,
        font: UIFont,
        width: CGFloat,
        lineSpacing: CGFloat = 2.4,
        paragraphSpacing: CGFloat = 6,
        justified: Bool = true
    ) -> CGFloat {
        height(FieldMarked(parsing: text), font: font, width: width, lineSpacing: lineSpacing,
               paragraphSpacing: paragraphSpacing, justified: justified)
    }

    static func height(
        _ marked: FieldMarked,
        font: UIFont,
        width: CGFloat,
        lineSpacing: CGFloat = 2.4,
        paragraphSpacing: CGFloat = 6,
        justified: Bool = true
    ) -> CGFloat {
        guard !marked.isEmpty else { return 0 }
        let attrs = attributes(font: font, color: .black, lineSpacing: lineSpacing,
                               paragraphSpacing: paragraphSpacing, justified: justified)
        let (manager, container, storage) = layout(marked, attributes: attrs,
                                                  size: CGSize(width: width, height: 100_000), exclusion: nil)
        // The layout manager holds its storage weakly: keep it alive.
        return withExtendedLifetime(storage) { ceil(manager.usedRect(for: container).height) }
    }

    @discardableResult
    static func flow(
        _ text: String,
        font: UIFont,
        color: UIColor,
        in rect: CGRect,
        dropCap: UIColor? = nil,
        lineSpacing: CGFloat = 2.4,
        paragraphSpacing: CGFloat = 6,
        justified: Bool = true
    ) -> Flow {
        flow(FieldMarked(parsing: text), font: font, color: color, in: rect, dropCap: dropCap,
             lineSpacing: lineSpacing, paragraphSpacing: paragraphSpacing, justified: justified)
    }

    /// Draws as much as fits in `rect` and returns what is left.
    @discardableResult
    static func flow(
        _ marked: FieldMarked,
        font: UIFont,
        color: UIColor,
        in rect: CGRect,
        dropCap: UIColor? = nil,
        lineSpacing: CGFloat = 2.4,
        paragraphSpacing: CGFloat = 6,
        justified: Bool = true
    ) -> Flow {
        guard !marked.isEmpty, rect.height > font.lineHeight else { return Flow(usedHeight: 0, rest: marked) }
        var body = marked
        var exclusion: CGRect?
        var dropped = 0
        if let capColor = dropCap, let first = body.text.first, first.isLetter {
            let capSize = font.pointSize * 3.35
            let capFont = UIFont.fbSerif(ofSize: capSize, weight: .bold)
            let letter = String(first)
            let glyph = (letter as NSString).size(withAttributes: [.font: capFont])
            let capWidth = ceil(glyph.width) + 5
            let capHeight = font.lineHeight * 3 + lineSpacing * 2
            (letter as NSString).draw(
                at: CGPoint(x: rect.minX, y: rect.minY - capSize * 0.14),
                withAttributes: [.font: capFont, .foregroundColor: capColor]
            )
            exclusion = CGRect(x: 0, y: 0, width: capWidth, height: capHeight)
            body = body.dropping(1)
            dropped = 1
        }
        _ = dropped
        let attrs = attributes(font: font, color: color, lineSpacing: lineSpacing,
                               paragraphSpacing: paragraphSpacing, justified: justified)
        let (manager, container, storage) = layout(body, attributes: attrs, size: rect.size, exclusion: exclusion)
        return withExtendedLifetime(storage) {
            let glyphs = manager.glyphRange(for: container)
            guard glyphs.length > 0 else { return Flow(usedHeight: 0, rest: marked) }
            manager.drawGlyphs(forGlyphRange: glyphs, at: rect.origin)
            let chars = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            // `chars` is UTF-16; convert to a Character offset before cutting.
            let nsText = body.text as NSString
            let consumedText = nsText.substring(to: min(nsText.length, chars.upperBound))
            let rest = body.dropping(consumedText.count)
            var used = ceil(manager.usedRect(for: container).height)
            if dropCap != nil { used = max(used, font.lineHeight * 3 + lineSpacing * 2) }
            return Flow(usedHeight: used, rest: rest)
        }
    }
}

// MARK: The moon

enum FieldMoon {
    /// A moon drawn from its illuminated fraction, lit on the right while it
    /// waxes and on the left while it wanes.
    static func draw(center: CGPoint, radius r: CGFloat, illuminated: Double, waxing: Bool, ink: UIColor) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        let disc = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ink.withAlphaComponent(0.14).setFill()
        UIBezierPath(ovalIn: disc).fill()
        let f = min(1, max(0, illuminated))
        if f > 0.985 {
            ink.withAlphaComponent(0.9).setFill()
            UIBezierPath(ovalIn: disc).fill()
        } else if f > 0.015 {
            let sign: CGFloat = waxing ? 1 : -1
            let a = r * CGFloat(abs(1 - 2 * f))
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x, y: center.y - r))
            // The limb: the lit half-circle.
            path.addArc(withCenter: center, radius: r,
                        startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: waxing)
            // The terminator: a half-ellipse back to the top.
            let steps = 28
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps) * .pi
                // t = 0 at the bottom, pi at the top.
                let y = center.y + r * cos(t)
                let bulge = f < 0.5 ? sign : -sign
                let x = center.x + bulge * a * sin(t)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.close()
            ink.withAlphaComponent(0.9).setFill()
            path.fill()
        }
        ink.withAlphaComponent(0.55).setStroke()
        let ring = UIBezierPath(ovalIn: disc)
        ring.lineWidth = 0.6
        ring.stroke()
        cg.restoreGState()
    }
}

/// Small, cropped portraits of the Cast, made once. A page draws five of them,
/// and a PDF stores every drawing of an image again, so a full-size plate per
/// portrait would make a book ten times the weight it needs to be.
enum FieldImageCache {
    private static let lock = NSLock()
    private static var portraits: [String: UIImage] = [:]

    static func portrait(_ asset: String, pixels: CGFloat = 170) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        if let cached = portraits[asset] { return cached }
        guard let source = UIImage(named: asset) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: pixels, height: pixels)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = max(pixels / source.size.width, pixels / source.size.height)
            let drawn = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (pixels - drawn.width) / 2, y: -drawn.height * 0.04, width: drawn.width, height: drawn.height))
        }
        portraits[asset] = image
        return image
    }
}

// MARK: Botanicals

enum FieldBotanicals {
    private static let byMonth: [Int: [String]] = [
        1: ["BotanicalHellebore", "BotanicalSnowdrop", "BotanicalHolly"],
        2: ["BotanicalSnowdrop", "BotanicalViolet", "BotanicalHellebore"],
        3: ["BotanicalWoodAnemone", "BotanicalViolet", "BotanicalDaisies"],
        4: ["BotanicalLilyOfTheValley", "BotanicalWhiteBells", "BotanicalWoodAnemone"],
        5: ["BotanicalWhiteBells", "BotanicalBorage", "BotanicalDandelion"],
        6: ["BotanicalFoxglove", "BotanicalDaisies", "BotanicalLavender", "BotanicalPoppy"],
        7: ["BotanicalLavender", "BotanicalPoppy", "BotanicalBorage"],
        8: ["BotanicalHeather", "BotanicalBlackberry", "BotanicalFoxglove"],
        9: ["BotanicalBlackberry", "BotanicalOakAcorns", "BotanicalFlyAgaric"],
        10: ["BotanicalFlyAgaric", "BotanicalOakAcorns", "BotanicalChineseLantern", "BotanicalSycamoreKeys", "BotanicalIvy"],
        11: ["BotanicalIvy", "BotanicalHolly", "BotanicalSycamoreKeys", "BotanicalRosemary"],
        12: ["BotanicalHolly", "BotanicalRosemary", "BotanicalIvy"]
    ]

    static func names(month: Int) -> [String] { byMonth[month] ?? [] }

    /// The next margin drawing for this book: dealt from the book's deck (the month's own marginalia
    /// first, the regular marginalia and the herbarium after, nothing twice until the deck runs out).
    /// Every margin in a book asks here, so the handbook's dossiers and the pad leaves share the deck.
    static func image(month: Int, seed: String) -> UIImage? {
        MarginaliaDealer.next(month: month) ?? hashed(month: month, seed: seed)
    }

    /// A drawing for this month, chosen by the seed so a given leaf always wears the same one.
    /// The fallback when the deck has nothing to give.
    private static func hashed(month: Int, seed: String) -> UIImage? {
        let names = byMonth[month] ?? byMonth[10] ?? []
        guard !names.isEmpty else { return nil }
        let index = ConstellationKeeper.stableIndex(for: "botanical-\(seed)", count: names.count)
        return UIImage(named: names[index]) ?? names.lazy.compactMap { UIImage(named: $0) }.first
    }
}

/// Images at the resolution the page can use.
///
/// A printed drawing 130 points across has no use for 1,254 pixels: at 300 dpi it needs about 540.
/// The October pack's twenty drawings are 2.4 MB each as delivered, and a weekly that draws a dozen of
/// them was a 16 MB file. Resampling when a drawing is placed leaves the art and the download alone
/// and costs the printed page nothing.
enum PrintImage {
    /// The image resampled to `dpi` for the size it will be drawn at, or the image itself when it is
    /// already close to that.
    static func fitted(_ image: UIImage, drawnPoints size: CGSize, dpi: CGFloat = 300) -> UIImage {
        let wantW = size.width * dpi / 72, wantH = size.height * dpi / 72
        let haveW = image.size.width * image.scale, haveH = image.size.height * image.scale
        guard haveW > wantW * 1.2 || haveH > wantH * 1.2, haveW > 0, haveH > 0 else { return image }
        let factor = min(wantW / haveW, wantH / haveH)
        let target = CGSize(width: max(1, (haveW * factor).rounded()), height: max(1, (haveH * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Line art on white, embedded as one grey channel instead of three colour ones plus alpha: a
    /// full-page colouring leaf drops from 2.3 MB to a few hundred kilobytes.
    static func greyscale(_ image: UIImage) -> UIImage {
        guard let source = image.cgImage else { return image }
        let width = source.width, height = source.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let flat = context.makeImage() else { return image }
        return UIImage(cgImage: flat, scale: 1, orientation: .up)
    }
}

/// Deals the drawings that fill one book's margins.
///
/// The month's own art leads: the drawings its pack delivered (October's cat, lantern, key,
/// moth) and that month's botanicals. Its neighbours' botanicals come next and the whole
/// herbarium after, so a book is never only the month and never only flowers. Every drawing
/// is dealt once before any is dealt twice, and the deck is shuffled by the book's own
/// seed so the same binding always looks the same.
/// Deals the lined-space prompts for one book: a monthly pack's own first, then the bundled ones,
/// and the same prompt is not asked twice in a book. Reset with the marginalia deck.
enum NotePromptDealer {
    private static var used = Set<String>()
    private static var delivered: [NotePrompts.Delivered]?
    private static var retiring = Set<String>()

    static func reset() {
        used = []
        delivered = nil
        retiring = []
    }

    static func next(_ kind: NotePrompts.Kind, seed: String) -> String? {
        if delivered == nil {
            let packs = WorldEventRegistry.enabledPacks()
            delivered = packs.flatMap { $0.notePrompts ?? [] }
            retiring = Set(packs.flatMap { $0.retiredNotePromptIDs ?? [] })
        }
        guard let row = NotePrompts.pick(kind: kind, seed: seed, avoiding: used, delivered: delivered ?? [], retiring: retiring) else { return nil }
        used.insert(row.id)
        return row.text
    }
}

final class MarginaliaDealer {
    private struct Drawing {
        let id: String
        let weight: Double
        let load: () -> UIImage?
    }

    private static var current: MarginaliaDealer?

    /// A new book starts a new deck. Called at the top of every interior render.
    static func reset() {
        current = nil
        NotePromptDealer.reset()
    }

    #if DEBUG
    /// A proof can ask to see another month's margins (the October art on a September week).
    static var forcedMonth: Int?
    #endif

    static func next(month requested: Int) -> UIImage? {
        var month = requested
        #if DEBUG
        month = forcedMonth ?? requested
        #endif
        if current?.month != month { current = MarginaliaDealer(month: month) }
        return current?.deal()
    }

    private let month: Int
    private let pool: [Drawing]
    private var deck: [Drawing] = []
    private var round = 0

    private init(month: Int) {
        self.month = month
        self.pool = Self.pool(month: month)
    }

    private func deal() -> UIImage? {
        guard !pool.isEmpty else { return nil }
        for _ in 0...pool.count {
            if deck.isEmpty { refill() }
            if let image = deck.removeFirst().load() { return image }
        }
        return nil
    }

    private func refill() {
        round += 1
        let byID = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
        deck = MarginaliaDeck.order(pool.map { ($0.id, $0.weight) }, seed: "margins-\(month)-\(round)").compactMap { byID[$0] }
    }

    private static func pool(month: Int) -> [Drawing] {
        var drawings: [Drawing] = []
        var seen = Set<String>()
        func add(_ id: String, _ weight: Double, _ load: @escaping () -> UIImage?) {
            if seen.insert(id).inserted { drawings.append(Drawing(id: id, weight: weight, load: load)) }
        }
        // The month's own marginalia lead: the drawings its pack delivered (October's cat, lantern,
        // key, moth), and the month's botanicals.
        let packArt = installedSeasonalArt()
        for art in packArt where art.month == month {
            add("pack:\(art.month ?? 0):\(art.name)", 3.0) { UIImage(contentsOfFile: art.path) }
        }
        // The app's regular marginalia: the goblins, the compass, the quill.
        for name in MarginaliaDeck.regular { add("margin:\(name)", 2.2) { UIImage(named: name) } }
        for name in FieldBotanicals.names(month: month) { add("botanical:\(name)", 2.0) { UIImage(named: name) } }
        // Not only this month: another month's pack art that is still installed, a neighbour's
        // botanicals, and the rest of the herbarium, each lightly.
        for art in packArt where art.month != month {
            add("pack:\(art.month ?? 0):\(art.name)", 0.8) { UIImage(contentsOfFile: art.path) }
        }
        for neighbour in [month == 1 ? 12 : month - 1, month == 12 ? 1 : month + 1] {
            for name in FieldBotanicals.names(month: neighbour) { add("botanical:\(name)", 1.0) { UIImage(named: name) } }
        }
        for other in 1...12 {
            for name in FieldBotanicals.names(month: other) { add("botanical:\(name)", 0.35) { UIImage(named: name) } }
        }
        return drawings
    }

    /// Every seasonal drawing a monthly pack delivered that is still installed on this device, with
    /// the month it was made for. A reissued drawing (`seasonal.v2.`) replaces the first of its name.
    private static func installedSeasonalArt() -> [(name: String, path: String, month: Int?)] {
        guard let directory = MonthlyIssueDeliveryPolicy.managedContentDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var found: [String: (path: String, month: Int?, name: String, reissued: Bool)] = [:]
        for url in files where url.pathExtension.lowercased() == "png" {
            let file = url.lastPathComponent
            guard file.hasPrefix(MonthlyIssueDeliveryPolicy.managedFilePrefix),
                  let marker = file.range(of: ".seasonal.") else { continue }
            let before = String(file[..<marker.lowerBound])
            var month: Int?
            if let range = before.range(of: "-\\d{4}-\\d{2}-", options: .regularExpression) {
                month = Int(before[range].dropLast().suffix(2))
            }
            var name = String(file[marker.upperBound...]).replacingOccurrences(of: ".png", with: "")
            let reissued = name.hasPrefix("v2.")
            if reissued { name = String(name.dropFirst(3)) }
            let key = "\(month ?? 0):\(name)"
            if found[key] == nil || (reissued && found[key]?.reissued == false) { found[key] = (url.path, month, name, reissued) }
        }
        return found.keys.sorted().compactMap { found[$0].map { ($0.name, $0.path, $0.month) } }
    }
}

// MARK: Layout

extension MonthlyEditionPDFWriter {
    static let handwriting: String = "BradleyHandITCTT-Bold"

    static func handFont(_ size: CGFloat) -> UIFont {
        UIFont(name: handwriting, size: size)
            ?? UIFont(name: "Noteworthy-Light", size: size)
            ?? .fbSerifItalic(ofSize: size)
    }

    static func smallCaps(_ size: CGFloat = 7.2, weight: UIFont.Weight = .heavy) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }

    static func drawTracked(
        _ text: String,
        at origin: CGPoint,
        font: UIFont,
        color: UIColor,
        tracking: CGFloat = 1.5,
        width: CGFloat? = nil,
        alignment: NSTextAlignment = .left
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: tracking]
        let string = NSAttributedString(string: text.uppercased(), attributes: attrs)
        let size = string.size()
        var x = origin.x
        if let width {
            switch alignment {
            case .right: x = origin.x + width - size.width
            case .center: x = origin.x + (width - size.width) / 2
            default: break
            }
        }
        string.draw(at: CGPoint(x: x, y: origin.y))
    }

    // MARK: Leaves

    /// A new leaf for the Field Book. In the print trim the gutter alternates so
    /// that the inner margin always sits at the spine; in the screen copy the
    /// reading margins are left as they were.
    static func fieldLeaf(
        _ base: inout PDFCursor,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        headLeft: String,
        headRight: String,
        folio: Bool = true,
        folioNumber: Int? = nil
    ) -> PDFCursor {
        let number = base.pageIndex + 1
        var margins = base.margins
        if margins.left < 100, number % 2 == 0 {
            margins = UIEdgeInsets(top: margins.top, left: margins.right, bottom: margins.bottom, right: margins.left)
        }
        var leaf = PDFCursor(bounds: base.bounds, margins: margins)
        leaf.seed = base.seed
        leaf.addressSeed = base.addressSeed
        leaf.pageIndex = base.pageIndex
        beginComposedPage(context, style: style, cursor: &leaf)
        base.pageIndex = leaf.pageIndex
        let ink = style.palette.ink.withAlphaComponent(0.5)
        drawTracked(headLeft, at: CGPoint(x: leaf.left, y: leaf.y - 8), font: smallCaps(6.8, weight: .semibold), color: ink, tracking: 1.3)
        drawTracked(headRight, at: CGPoint(x: leaf.left, y: leaf.y - 8), font: smallCaps(6.8, weight: .semibold), color: ink,
                    tracking: 1.3, width: leaf.contentWidth, alignment: .right)
        if folio {
            // The folio carries the page's address, so a photograph of it can be read back.
            let shown = folioNumber ?? leaf.pageIndex
            let label = "— \(PageAddress.label(seed: leaf.addressSeed ?? leaf.seed, page: shown)) —" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.fbSerifItalic(ofSize: 8.5),
                .foregroundColor: style.palette.ink.withAlphaComponent(0.5)
            ]
            let size = label.size(withAttributes: attrs)
            let x = shown % 2 == 0 ? leaf.left : leaf.right - size.width
            label.draw(at: CGPoint(x: x, y: leaf.bounds.height - leaf.margins.bottom + 12), withAttributes: attrs)
        }
        leaf.y += 14
        return leaf
    }

    private static var monthFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }
    private static var weekdayFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }
    private static var shortMonthDay: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }

    // MARK: The date strip

    private static func drawDateStrip(_ day: BoundDay, calendar: Calendar, style: EditionStyle, leaf: inout PDFCursor) {
        let ink = style.palette.ink
        let accent = style.palette.accent
        let top = leaf.y
        ink.withAlphaComponent(0.4).setFill()
        UIRectFill(CGRect(x: leaf.left, y: top, width: leaf.contentWidth, height: 0.6))

        let dayNumber = "\(calendar.component(.day, from: day.date))"
        let numeralFont = UIFont.fbSerif(ofSize: 46, weight: .bold)
        (dayNumber as NSString).draw(at: CGPoint(x: leaf.left, y: top + 5),
                                     withAttributes: [.font: numeralFont, .foregroundColor: accent])
        let numeralWidth = (dayNumber as NSString).size(withAttributes: [.font: numeralFont]).width
        let textX = leaf.left + numeralWidth + 12
        let textWidth = leaf.right - textX

        var ty = top + 9
        drawTracked("\(weekdayFormatter.string(from: day.date)) · \(monthFormatter.string(from: day.date)) \(calendar.component(.year, from: day.date))",
                    at: CGPoint(x: textX, y: ty), font: smallCaps(7.4), color: ink, tracking: 1.3)
        ty += 15
        let waxing = day.almanac.moonAgeDays < MoonPhaseCalendar.synodicMonthDays / 2
        FieldMoon.draw(center: CGPoint(x: textX + 5.5, y: ty + 5.5), radius: 5.5,
                       illuminated: day.almanac.moonIlluminated, waxing: waxing, ink: ink)
        var skyLine = day.almanac.moonName
        if !day.almanac.skyWords.isEmpty { skyLine += " · sky " + day.almanac.skyWords.joined(separator: ", ") }
        (skyLine as NSString).draw(
            in: CGRect(x: textX + 16, y: ty, width: textWidth - 16, height: 13),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 9.6, weight: .regular), .foregroundColor: ink.withAlphaComponent(0.85)]
        )
        ty += 14
        if let feast = day.almanac.feast {
            (feast as NSString).draw(
                in: CGRect(x: textX, y: ty, width: textWidth, height: 13),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9), .foregroundColor: ink.withAlphaComponent(0.7)]
            )
        }
        let bottom = top + 62
        ink.withAlphaComponent(0.4).setFill()
        UIRectFill(CGRect(x: leaf.left, y: bottom, width: leaf.contentWidth, height: 0.6))
        leaf.y = bottom + 12
    }

    // MARK: Pieces

    static func drawEyebrow(_ text: String, style: EditionStyle, leaf: inout PDFCursor) {
        drawTracked(text, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7.2), color: style.palette.accent, tracking: 1.6)
        leaf.y += 13
    }

    /// A torn paper label with one handwritten line, taped on at a slant.
    static func drawHandSlip(
        _ text: String,
        style: EditionStyle,
        in rect: CGRect,
        rotation: CGFloat,
        seed: String,
        fontSize: CGFloat = 11.5,
        color: UIColor? = nil
    ) {
        let fill = blend(parchment(for: style).top, UIColor(white: 1, alpha: 1), 0.45)
        drawTornScrap(in: rect, rotation: rotation, fill: fill, seed: seed)
        drawTapeStrip(center: CGPoint(x: rect.midX + (frac("\(seed)-tx") - 0.5) * rect.width * 0.5, y: rect.minY + 1),
                      length: 38, angle: (frac("\(seed)-ta") - 0.5) * 0.6, tint: style.palette.gold)
        let inset = rect.insetBy(dx: 11, dy: 7)
        _ = FieldText.flow(text, font: handFont(fontSize), color: color ?? style.palette.ink.withAlphaComponent(0.85),
                           in: inset, lineSpacing: 1.6, paragraphSpacing: 2, justified: false)
    }

    static func slipHeight(_ text: String, width: CGFloat, fontSize: CGFloat = 11.5) -> CGFloat {
        FieldText.height(text, font: handFont(fontSize), width: width - 22, lineSpacing: 1.6, paragraphSpacing: 2, justified: false) + 20
    }

    private static func drawCastStrip(
        _ names: [(name: String, asset: String?)],
        style: EditionStyle,
        leaf: inout PDFCursor
    ) {
        let people = names.prefix(5)
        guard !people.isEmpty else { return }
        drawEyebrow("In the room", style: style, leaf: &leaf)
        let size: CGFloat = 38
        let gap: CGFloat = 10
        var x = leaf.left
        for person in people {
            let rect = CGRect(x: x, y: leaf.y, width: size, height: size)
            if let asset = person.asset, let image = FieldImageCache.portrait(asset), let cg = UIGraphicsGetCurrentContext() {
                cg.saveGState()
                UIBezierPath(ovalIn: rect).addClip()
                image.draw(in: rect)
                cg.restoreGState()
            } else {
                style.palette.accentSoft.setFill()
                UIBezierPath(ovalIn: rect).fill()
            }
            style.palette.gold.setStroke()
            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 1.2
            ring.stroke()
            let first = person.name.split(separator: " ").first.map(String.init) ?? person.name
            drawTracked(first, at: CGPoint(x: x - 6, y: rect.maxY + 3), font: smallCaps(5.6, weight: .semibold),
                        color: style.palette.ink.withAlphaComponent(0.7), tracking: 0.6, width: size + 12, alignment: .center)
            x += size + gap
        }
        leaf.y += size + 20
    }

    /// The Bleed clipping: set as a paper cutting taped on.
    private static func clippingHeight(_ item: MonthlyEditionItem, width: CGFloat) -> CGFloat {
        let headline = FieldText.height(item.title, font: .fbSerif(ofSize: 14, weight: .bold), width: width - 28, justified: false)
        let body = FieldText.height(item.body, font: .fbSerif(ofSize: 9.4, weight: .regular), width: width - 28)
        return 34 + headline + body + 14
    }

    private static func drawClipping(_ item: MonthlyEditionItem, style: EditionStyle, leaf: inout PDFCursor, maxHeight: CGFloat) {
        let width = leaf.contentWidth - 10
        let height = min(maxHeight, clippingHeight(item, width: width))
        let rect = CGRect(x: leaf.left + 5, y: leaf.y, width: width, height: height)
        drawTornScrap(in: rect, rotation: 0.01 * (frac("clip-\(item.id)") > 0.5 ? 1 : -1),
                      fill: UIColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1), seed: "clip-\(item.id)")
        drawTapeStrip(center: CGPoint(x: rect.minX + 28, y: rect.minY + 3), length: 44, angle: -0.5, tint: style.palette.gold)
        drawTapeStrip(center: CGPoint(x: rect.maxX - 28, y: rect.minY + 3), length: 44, angle: 0.5, tint: style.palette.gold)
        let ink = style.palette.ink
        drawTracked("The Riddlewind Bleed", at: CGPoint(x: rect.minX + 14, y: rect.minY + 12), font: smallCaps(6.6),
                    color: ink.withAlphaComponent(0.75), tracking: 1.6, width: rect.width - 28, alignment: .center)
        ink.withAlphaComponent(0.55).setFill()
        UIRectFill(CGRect(x: rect.minX + 14, y: rect.minY + 24, width: rect.width - 28, height: 0.6))
        var y = rect.minY + 30
        let headRect = CGRect(x: rect.minX + 14, y: y, width: rect.width - 28, height: height)
        let head = FieldText.flow(item.title, font: .fbSerif(ofSize: 14, weight: .bold),
                                  color: ink, in: headRect, lineSpacing: 1, paragraphSpacing: 0, justified: false)
        y += head.usedHeight + 4
        _ = FieldText.flow(item.body, font: .fbSerif(ofSize: 9.4, weight: .regular),
                           color: ink.withAlphaComponent(0.9),
                           in: CGRect(x: rect.minX + 14, y: y, width: rect.width - 28, height: max(0, rect.maxY - y - 8)))
        leaf.y = rect.maxY + 12
    }

    // MARK: Photographs

    private static func drawPressedPhoto(
        _ image: UIImage,
        caption: String?,
        style: EditionStyle,
        in box: CGRect,
        rotation: CGFloat
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let mat: CGFloat = 6
        let foot: CGFloat = caption == nil ? 6 : 20
        let scale = min((box.width - mat * 2) / image.size.width, (box.height - mat - foot) / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let frame = CGRect(x: box.midX - (size.width + mat * 2) / 2, y: box.minY,
                           width: size.width + mat * 2, height: size.height + mat + foot)
        cg.saveGState()
        cg.translateBy(x: frame.midX, y: frame.midY)
        cg.rotate(by: rotation)
        cg.translateBy(x: -frame.midX, y: -frame.midY)
        cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.32).cgColor)
        UIColor(white: 0.985, alpha: 1).setFill()
        UIRectFill(frame)
        cg.setShadow(offset: .zero, blur: 0, color: nil)
        image.draw(in: CGRect(x: frame.minX + mat, y: frame.minY + mat, width: size.width, height: size.height))
        // Photo corners.
        let corner: CGFloat = 13
        UIColor(red: 0.30, green: 0.22, blue: 0.14, alpha: 0.78).setFill()
        for (cx, cy, sx, sy) in [(frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: cx, y: cy))
            p.addLine(to: CGPoint(x: cx + corner * sx, y: cy))
            p.addLine(to: CGPoint(x: cx, y: cy + corner * sy))
            p.close()
            p.fill()
        }
        if let caption {
            (caption as NSString).draw(
                in: CGRect(x: frame.minX + mat + 2, y: frame.maxY - foot + 3, width: frame.width - mat * 2, height: 14),
                withAttributes: [.font: handFont(9.6), .foregroundColor: style.palette.ink.withAlphaComponent(0.78)]
            )
        }
        cg.restoreGState()
    }

    private static func firstPhoto(_ items: [MonthlyEditionItem]) -> (UIImage, MonthlyEditionItem)? {
        for item in items {
            if let image = firstImage(from: item.mediaAssets) { return (image, item) }
        }
        return nil
    }

    // MARK: Specimens

    private static func specimensHeight(_ specimens: [BoundDaySpecimen]) -> CGFloat {
        specimens.isEmpty ? 0 : 20 + CGFloat(specimens.count) * 13
    }

    private static func drawSpecimens(_ specimens: [BoundDaySpecimen], style: EditionStyle, in rect: CGRect) {
        guard !specimens.isEmpty else { return }
        drawTracked("Specimens collected", at: CGPoint(x: rect.minX, y: rect.minY), font: smallCaps(6.8), color: style.palette.accent, tracking: 1.4)
        var y = rect.minY + 14
        let font = UIFont.fbSerif(ofSize: 9.2, weight: .regular)
        let ink = style.palette.ink.withAlphaComponent(0.85)
        for specimen in specimens {
            var title = specimen.title
            let clock = specimen.clock ?? ""
            let clockWidth = (clock as NSString).size(withAttributes: [.font: font]).width
            let available = rect.width - clockWidth - 10
            while (title as NSString).size(withAttributes: [.font: font]).width > available, title.count > 4 {
                title = String(title.dropLast(2))
                if (title as NSString).size(withAttributes: [.font: font]).width <= available { title += "…"; break }
            }
            let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
            (title as NSString).draw(at: CGPoint(x: rect.minX, y: y), withAttributes: [.font: font, .foregroundColor: ink])
            (clock as NSString).draw(at: CGPoint(x: rect.maxX - clockWidth, y: y), withAttributes: [.font: font, .foregroundColor: ink])
            // The dotted leader.
            if let cg = UIGraphicsGetCurrentContext() {
                cg.saveGState()
                cg.setStrokeColor(style.palette.ink.withAlphaComponent(0.4).cgColor)
                cg.setLineWidth(0.6)
                cg.setLineDash(phase: 0, lengths: [1, 2.2])
                cg.move(to: CGPoint(x: rect.minX + titleWidth + 4, y: y + 9))
                cg.addLine(to: CGPoint(x: rect.maxX - clockWidth - 4, y: y + 9))
                cg.strokePath()
                cg.restoreGState()
            }
            y += 13
        }
    }

    // MARK: Decoration

    /// The botanical drawings are small files, so they are set small: about
    /// 150 pixels to the inch is the most they will honestly carry.
    private static func drawBotanical(
        month: Int,
        seed: String,
        in rect: CGRect,
        alignRight: Bool,
        rotation: CGFloat = 0
    ) {
        guard rect.width > 40, rect.height > 40, let image = FieldBotanicals.image(month: month, seed: seed) else { return }
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let honest = image.size.width * image.scale / 150 * 72
        let scale = min(rect.width / image.size.width, rect.height / image.size.height, honest / image.size.width)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: alignRight ? rect.maxX - size.width : rect.minX, y: rect.maxY - size.height)
        let ready = PrintImage.fitted(image, drawnPoints: size)
        cg.saveGState()
        cg.translateBy(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        cg.rotate(by: rotation)
        ready.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        cg.restoreGState()
    }

    // MARK: The world's day

    static func drawWorldSide(
        _ day: BoundDay,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        marginalia: [BoundMarginNote],
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let headLeft = "\(monthFormatter.string(from: day.date))"
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "The Days")
        drawDateStrip(day, calendar: calendar, style: style, leaf: &leaf)

        func newContinuation() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft,
                             headRight: "\(shortMonthDay.string(from: day.date)) · continued")
        }
        func room(_ needed: CGFloat) {
            if leaf.y + needed > leaf.bottom { newContinuation() }
        }

        let ink = style.palette.ink

        // Who was in the room, first: the day opens on its company.
        var names: [(name: String, asset: String?)] = []
        var seenCast = Set<String>()
        for slug in day.scenes.flatMap(\.castIDs) where seenCast.insert(slug).inserted {
            names.append((KeepMarginalia.voice(forSlug: slug)?.name ?? slug.split(separator: "-").map { $0.capitalized }.joined(separator: " "),
                          CastMarginalia.plateAssetName(forSlug: slug)))
        }
        if !names.isEmpty { drawCastStrip(names, style: style, leaf: &leaf) }

        let bodyFont = UIFont.fbSerif(ofSize: 10.4, weight: .regular)
        var firstProse = true
        var lastContentID: String?
        for scene in day.scenes {
            room(120)
            let sameScene = scene.contentID == lastContentID
            lastContentID = scene.contentID
            if !sameScene {
                let place: String
                if scene.isReport {
                    place = scene.roomName.map { "The Academy's record · \($0)" } ?? "The Academy's record"
                } else {
                    place = scene.roomName.map { "In the Labyrinth · \($0)" } ?? "From the month's story"
                }
                drawEyebrow(place, style: style, leaf: &leaf)
            }
            let titleFont = scene.isReport
                ? UIFont.fbSerif(ofSize: sameScene ? 13 : 17, weight: .semibold)
                : UIFont.fbSerifItalic(ofSize: sameScene ? 14 : 20)
            let titleHeight = FieldText.height(scene.title, font: titleFont, width: leaf.contentWidth, justified: false)
            _ = FieldText.flow(scene.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: titleHeight + 4),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += titleHeight + 6
            if let choice = scene.choiceLabel, !scene.isReport {
                let slip = CGRect(x: leaf.left, y: leaf.y, width: min(leaf.contentWidth, 210), height: 30)
                drawHandSlip("you chose · \(choice)", style: style, in: slip, rotation: -0.03, seed: "choice-\(scene.id)",
                             fontSize: 11, color: style.palette.accent)
                leaf.y += 38
            }
            var rest = FieldMarked(parsing: scene.body)
            var capped = firstProse && !sameScene && !scene.isReport
            var guardPasses = 0
            while !rest.isEmpty, guardPasses < 24 {
                guardPasses += 1
                if leaf.bottom - leaf.y < 60 { newContinuation() }
                let rect = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y)
                let flow = FieldText.flow(rest, font: bodyFont, color: ink.withAlphaComponent(0.92), in: rect,
                                          dropCap: capped ? style.palette.accent : nil)
                capped = false
                guard flow.usedHeight > 0 else { newContinuation(); continue }
                leaf.y += flow.usedHeight + 8
                rest = flow.rest
                if !rest.isEmpty { newContinuation() }
            }
            firstProse = false
            leaf.y += 4
        }

        // What the dial said that day.
        for line in day.radio.prefix(3) {
            let text = "\(line.station): “\(line.line)”"
            let width = min(leaf.contentWidth, 280)
            let height = slipHeight(text, width: width, fontSize: 10.6)
            room(height + 12)
            drawHandSlip(text, style: style, in: CGRect(x: leaf.left + 2, y: leaf.y, width: width, height: height),
                         rotation: frac("radio-\(line.id)") > 0.5 ? 0.02 : -0.02, seed: "radio-\(line.id)", fontSize: 10.6)
            leaf.y += height + 12
        }

        for item in day.clippings {
            let width = leaf.contentWidth - 10
            let needed = min(clippingHeight(item, width: width), 300)
            room(needed + 14)
            drawClipping(item, style: style, leaf: &leaf, maxHeight: 300)
        }

        for line in day.castLines {
            let text = "\(line.speakerName): “\(line.line)”"
            let width = min(leaf.contentWidth, 250)
            let height = slipHeight(text, width: width, fontSize: 10.8)
            room(height + 10)
            drawHandSlip(text, style: style, in: CGRect(x: leaf.left + 4, y: leaf.y, width: width, height: height),
                         rotation: frac("line-\(line.id)") > 0.5 ? 0.025 : -0.025, seed: "line-\(line.id)", fontSize: 10.8)
            leaf.y += height + 12
        }

        // What is left of the leaf is given to a margin note when one is
        // waiting, and the month's own drawing: never left blank.
        let remaining = leaf.bottom - leaf.y
        if remaining > 70 {
            if let note = marginalia.isEmpty ? nil : marginalia[abs(day.id.stableHash) % marginalia.count], remaining > 100 {
                let width = min(leaf.contentWidth * 0.62, 200)
                let height = slipHeight(note.text, width: width, fontSize: 10.5)
                drawHandSlip(note.text, style: style,
                             in: CGRect(x: leaf.left, y: leaf.bottom - height - 6, width: width, height: height),
                             rotation: -0.035, seed: "margin-\(day.id)", fontSize: 10.5,
                             color: note.accentHex.map { castInk($0) })
            }
            drawBotanical(month: monthNumber, seed: day.id,
                          in: CGRect(x: leaf.right - 110, y: leaf.bottom - min(remaining + 18, 130), width: 110, height: min(remaining + 18, 130)),
                          alignRight: true, rotation: -0.1)
        }
    }

    // MARK: The reader's day

    static func drawYourSide(
        _ day: BoundDay,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        bookMargin: String? = nil,
        meanwhile: String? = nil,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let headLeft = "Your day"
        let dateLine = "\(weekdayFormatter.string(from: day.date)) \(calendar.component(.day, from: day.date)) \(monthFormatter.string(from: day.date))"
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: dateLine)
        func newContinuation() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
        }
        let ink = style.palette.ink
        let bodyFont = UIFont.fbSerif(ofSize: 10.8, weight: .regular)
        var firstProse = true

        for braid in day.braids {
            if leaf.bottom - leaf.y < 130 { newContinuation() }
            var eyebrow = "Night braid"
            if let date = braid.date {
                eyebrow += " · kept at \(clockString(date, calendar: calendar))"
            }
            drawEyebrow(eyebrow, style: style, leaf: &leaf)
            let titleFont = UIFont.fbSerif(ofSize: 17, weight: .bold)
            let titleHeight = FieldText.height(braid.title, font: titleFont, width: leaf.contentWidth, justified: false)
            _ = FieldText.flow(braid.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: titleHeight + 4),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += titleHeight + 8
            var rest = FieldMarked(parsing: braid.body)
            var capped = firstProse
            var guardPasses = 0
            while !rest.isEmpty, guardPasses < 24 {
                guardPasses += 1
                if leaf.bottom - leaf.y < 60 { newContinuation() }
                let rect = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y)
                let flow = FieldText.flow(rest, font: bodyFont, color: ink.withAlphaComponent(0.92), in: rect,
                                          dropCap: capped ? style.palette.accent : nil)
                capped = false
                guard flow.usedHeight > 0 else { newContinuation(); continue }
                leaf.y += flow.usedHeight + 8
                rest = flow.rest
                if !rest.isEmpty { newContinuation() }
            }
            firstProse = false
        }

        // Everything else they kept that day, each dressed for what it is.
        if !day.keeps.isEmpty {
            drawKeeps(day.keeps, day: day, style: style, leaf: &leaf, cursor: &cursor, context: context,
                      headLeft: headLeft, dateLine: dateLine)
        }

        // The photograph, the specimens that fed the night, the reader's words.
        let photo = firstPhoto(day.photos)
        let specimens = day.specimens
        let words = day.words
        let columnGap: CGFloat = 14
        let photoWidth = photo == nil ? 0 : min(leaf.contentWidth * 0.52, 190)
        let sideWidth = photo == nil ? leaf.contentWidth : leaf.contentWidth - photoWidth - columnGap

        let wordsText = words.joined(separator: "\n")
        let wordsHeight = words.isEmpty ? 0 : slipHeight("your own words\n" + wordsText, width: sideWidth, fontSize: 11.2)
        let sideHeight = specimensHeight(specimens) + (words.isEmpty ? 0 : wordsHeight + 14)
        let photoHeight: CGFloat = photo.map {
            min(170, (photoWidth - 12) * $0.0.size.height / max(1, $0.0.size.width) + 30)
        } ?? 0
        let blockHeight = max(photoHeight, sideHeight)

        if blockHeight > 0 {
            if leaf.y + blockHeight > leaf.bottom { newContinuation() }
            let top = leaf.y + 4
            if let (image, item) = photo {
                var caption: String? = nil
                if let date = item.date { caption = "kept at \(clockString(date, calendar: calendar))" }
                if let asset = item.mediaAssets.first(where: { $0.sourceID != "authored-marginalia" }), let c = asset.caption.nonEmpty { caption = c }
                drawPressedPhoto(image, caption: caption, style: style,
                                 in: CGRect(x: leaf.left, y: top, width: photoWidth, height: min(photoHeight, leaf.bottom - top)),
                                 rotation: -0.028)
            }
            let sideX = photo == nil ? leaf.left : leaf.left + photoWidth + columnGap
            var sy = top
            if !specimens.isEmpty {
                drawSpecimens(specimens, style: style, in: CGRect(x: sideX, y: sy, width: sideWidth, height: specimensHeight(specimens)))
                sy += specimensHeight(specimens) + 14
            }
            if !words.isEmpty {
                let rect = CGRect(x: sideX, y: sy, width: sideWidth, height: wordsHeight)
                drawHandSlip("your own words\n" + wordsText, style: style, in: rect, rotation: 0.025, seed: "words-\(day.id)", fontSize: 11.2)
            }
            leaf.y = top + blockHeight + 10
        }

        // Drawings the reader kept, tucked in beside their words.
        if !day.marks.isEmpty, leaf.bottom - leaf.y > 80 {
            var x = leaf.left
            for asset in day.marks {
                guard let image = image(from: asset) else { continue }
                let scale = min(120 / image.size.width, 62 / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                if leaf.y + size.height + 6 > leaf.bottom { break }
                image.draw(in: CGRect(x: x, y: leaf.y, width: size.width, height: size.height))
                x += size.width + 16
            }
            leaf.y += 72
        }

        // More photographs, small, along the foot.
        let extras = day.photos.filter { $0.id != photo?.1.id }.compactMap { item -> UIImage? in firstImage(from: item.mediaAssets) }
        if !extras.isEmpty, leaf.bottom - leaf.y > 90 {
            var x = leaf.left
            let shown = Array(extras.prefix(3))
            // As large as the room allows: a second photograph is not a postage stamp beside the first.
            let roomy = leaf.bottom - leaf.y > (bookMargin == nil ? 190 : 250)
            let w: CGFloat = min(roomy ? 150 : 96, (leaf.contentWidth - 12 * CGFloat(shown.count - 1)) / CGFloat(shown.count))
            let h: CGFloat = roomy ? 118 : 84
            for image in shown {
                drawPressedPhoto(image, caption: nil, style: style,
                                 in: CGRect(x: x, y: leaf.y, width: w, height: min(h, leaf.bottom - leaf.y)),
                                 rotation: frac("extra-\(day.id)-\(x)") > 0.5 ? 0.03 : -0.03)
                x += w + 12
            }
            leaf.y += h + 8
        }

        // The Book's own margin: one line it wrote for something the reader kept.
        if let bookMargin, leaf.bottom - leaf.y > 96 {
            let text = "in the Book's margin\n" + bookMargin
            let height = slipHeight(text, width: leaf.contentWidth * 0.78, fontSize: 10.6)
            if leaf.y + height + 6 < leaf.bottom {
                drawHandSlip(text, style: style,
                             in: CGRect(x: leaf.left + leaf.contentWidth * 0.2, y: leaf.y + 4, width: leaf.contentWidth * 0.78, height: height),
                             rotation: -0.02, seed: "book-margin-\(day.id)", fontSize: 10.6)
                leaf.y += height + 14
            }
        }

        // A leaf with room left is given what the day held that the reader did not write: what the
        // Labyrinth was doing that night (the authored beat the braid carried) and the sky.
        if leaf.bottom - leaf.y > 150 {
            let bodyFont = UIFont.fbSerif(ofSize: 10.4, weight: .regular)
            if let meanwhile {
                let height = FieldText.height(meanwhile, font: UIFont.fbSerifItalic(ofSize: 10.4), width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
                if leaf.y + height + 40 < leaf.bottom {
                    leaf.y += 8
                    drawEyebrow("Meanwhile, in the Labyrinth", style: style, leaf: &leaf)
                    _ = FieldText.flow(meanwhile, font: UIFont.fbSerifItalic(ofSize: 10.4), color: style.palette.ink.withAlphaComponent(0.82),
                                       in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: height + 4),
                                       lineSpacing: 2, paragraphSpacing: 0, justified: false)
                    leaf.y += height + 14
                }
            }
            var sky: [String] = [day.almanac.moonName]
            sky += day.almanac.skyWords.prefix(3)
            if let feast = day.almanac.feast?.trimmingCharacters(in: .whitespaces), !feast.isEmpty { sky.append(feast) }
            let line = sky.filter { !$0.isEmpty }.joined(separator: " · ")
            if !line.isEmpty, leaf.bottom - leaf.y > 90 {
                leaf.y += 4
                drawEyebrow("The sky that day", style: style, leaf: &leaf)
                let height = FieldText.height(line, font: bodyFont, width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
                _ = FieldText.flow(line, font: bodyFont, color: style.palette.ink.withAlphaComponent(0.78),
                                   in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: height + 4),
                                   lineSpacing: 2, paragraphSpacing: 0, justified: false)
                leaf.y += height + 12
            }
        }

        let remaining = leaf.bottom - leaf.y
        if remaining > 100, let prompt = NotePromptDealer.next(.day, seed: day.id) {
            drawNotesBlock(prompt, in: CGRect(x: leaf.left, y: leaf.y + 2, width: leaf.contentWidth, height: min(remaining - 6, 190)), style: style)
        } else if remaining > 80 {
            drawBotanical(month: monthNumber, seed: day.id + "-yours",
                          in: CGRect(x: leaf.left, y: leaf.bottom - min(remaining + 18, 130), width: 110, height: min(remaining + 18, 130)),
                          alignRight: false, rotation: 0.08)
        }
    }

    /// A small invitation and lined space under it, filling `rect`: somewhere for the reader to write.
    static func drawNotesBlock(_ prompt: String, in rect: CGRect, style: EditionStyle) {
        let ink = style.palette.ink
        let title = "WRITE HERE" as NSString
        title.draw(at: CGPoint(x: rect.minX, y: rect.minY),
                   withAttributes: [.font: smallCaps(7), .foregroundColor: style.palette.accent, .kern: 1.4])
        let promptFont = UIFont.fbSerifItalic(ofSize: 10.4)
        let height = FieldText.height(prompt, font: promptFont, width: rect.width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        _ = FieldText.flow(prompt, font: promptFont, color: ink.withAlphaComponent(0.72),
                           in: CGRect(x: rect.minX, y: rect.minY + 13, width: rect.width, height: height + 4),
                           lineSpacing: 2, paragraphSpacing: 0, justified: false)
        hbRules(from: rect.minY + 13 + height + 6, to: rect.maxY, left: rect.minX, right: rect.maxX, spacing: 23, style: style)
    }

    private static func clockString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelve, parts.minute ?? 0, hour < 12 ? "a.m." : "p.m.")
    }

    // MARK: The Labyrinth, this week

    /// What the world was doing on the nights the Book braided: the authored beat each
    /// braid carried. Set on the rest of the leaf the bound story left, or a leaf of its own.
    static func drawLabyrinthNotes(
        _ notes: [WeeklyCuration.LabyrinthNote],
        calendar: Calendar,
        style: EditionStyle,
        after leaf: PDFCursor?,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard notes.count >= 2 else { return }
        let ink = style.palette.ink
        var current: PDFCursor
        if let leaf, leaf.bottom - leaf.y > 190 {
            current = leaf
            current.y += 10
        } else {
            current = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Labyrinth", headRight: "this week")
        }
        drawEyebrow("What the world was doing on the nights I braided", style: style, leaf: &current)
        current.y += 4
        let font = UIFont.fbSerif(ofSize: 10.8, weight: .regular)
        for note in notes {
            let height = FieldText.height(note.text, font: font, width: current.contentWidth, lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
            if current.y + height + 34 > current.bottom {
                current = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Labyrinth", headRight: "this week, continued")
            }
            drawTracked("\(weekdayFormatter.string(from: note.date)) · \(note.title)".uppercased(),
                        at: CGPoint(x: current.left, y: current.y), font: smallCaps(6.8, weight: .semibold),
                        color: style.palette.accent, tracking: 1.2)
            current.y += 13
            _ = FieldText.flow(note.text, font: font, color: ink.withAlphaComponent(0.9),
                               in: CGRect(x: current.left, y: current.y, width: current.contentWidth, height: height + 4),
                               lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
            current.y += height + 16
        }
    }

    // MARK: A week opens

    static func drawWeekLeaf(
        _ week: BoundWeek,
        book: BoundDayBook,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        window: (start: Date, end: Date)? = nil,
        eyebrow: String? = nil,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        // A weekly issue is exactly seven days from its own first day, not from the first
        // day anything was kept: the range, the moons and the index all say so.
        let weekStart = window?.start ?? week.start
        let weekEnd = window?.end ?? week.end
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: monthFormatter.string(from: weekStart), headRight: "A week opens")
        leaf.y += 14
        drawEyebrow(eyebrow ?? "Week \(week.index + 1)", style: style, leaf: &leaf)
        let title = "\(shortMonthDay.string(from: weekStart)) – \(shortMonthDay.string(from: weekEnd))"
        (title as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                 withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 30), .foregroundColor: style.palette.ink])
        leaf.y += 44

        // Seven small moons: the week at a glance.
        let cell = leaf.contentWidth / 7
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: weekStart)) else { continue }
            let moon = MoonPhaseCalendar.phase(on: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
            let cx = leaf.left + cell * (CGFloat(offset) + 0.5)
            FieldMoon.draw(center: CGPoint(x: cx, y: leaf.y + 8), radius: 6.5, illuminated: moon.illuminatedFraction,
                           waxing: moon.ageDays < MoonPhaseCalendar.synodicMonthDays / 2, ink: style.palette.ink)
            let hasNight = book.day(on: date, calendar: calendar)?.braids.isEmpty == false
            let hasScene = book.day(on: date, calendar: calendar)?.scenes.isEmpty == false
            if hasNight {
                style.palette.accent.setFill()
                UIBezierPath(ovalIn: CGRect(x: cx - 2.2, y: leaf.y + 20, width: 4.4, height: 4.4)).fill()
            } else if hasScene {
                style.palette.accent.setStroke()
                let ring = UIBezierPath(ovalIn: CGRect(x: cx - 2.2, y: leaf.y + 20, width: 4.4, height: 4.4))
                ring.lineWidth = 0.8
                ring.stroke()
            }
            drawTracked(weekdayFormatter.string(from: date).prefix(3).description, at: CGPoint(x: cx - 12, y: leaf.y + 28),
                        font: smallCaps(5.8, weight: .semibold), color: style.palette.ink.withAlphaComponent(0.6),
                        tracking: 0.8, width: 24, alignment: .center)
        }
        leaf.y += 52

        if let night = week.strongestNight {
            drawEyebrow("The week's strongest night", style: style, leaf: &leaf)
            let nightFont = UIFont.fbSerif(ofSize: 15, weight: .bold)
            let h = FieldText.height(night, font: nightFont, width: leaf.contentWidth, justified: false)
            _ = FieldText.flow(night, font: nightFont, color: style.palette.ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: h + 4),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += h + 16
        }

        // The week, day by day: what each date holds, in a line.
        let members = book.days.filter {
            let offset = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: book.days.first?.date ?? week.start), to: $0.date).day ?? 0)
            return $0.date >= calendar.startOfDay(for: weekStart) && $0.date <= weekEnd.addingTimeInterval(86_399) && offset >= 0
        }
        if !members.isEmpty {
            drawEyebrow("The week, day by day", style: style, leaf: &leaf)
            for day in members {
                if leaf.bottom - leaf.y < 40 { break }
                var held: [String] = []
                if let braid = day.braids.first { held.append(braid.title) }
                for scene in day.scenes.prefix(2) where !held.contains(scene.title) { held.append(scene.title) }
                // What else the day held, by name: a Cast turn, a Tale, a quotation. "Kept 0 small
                // things" was printed on a day that held a Cast turn and a Tale.
                for keep in day.keeps.prefix(2) where !held.contains(keep.title) { held.append(keep.title) }
                if !day.photos.isEmpty { held.append(day.photos.count == 1 ? "a photograph" : "\(day.photos.count) photographs") }
                if held.isEmpty, !day.castLines.isEmpty { held.append("the Cast, in the margins") }
                if held.isEmpty, day.specimens.count > 0 { held.append("kept \(day.specimens.count) small \(day.specimens.count == 1 ? "thing" : "things")") }
                if held.isEmpty { held.append("the Labyrinth kept its own counsel") }
                let label = "\(weekdayFormatter.string(from: day.date).prefix(3)) \(calendar.component(.day, from: day.date))"
                drawTracked(label, at: CGPoint(x: leaf.left, y: leaf.y + 2), font: smallCaps(6.8), color: style.palette.accent, tracking: 1)
                let line = held.joined(separator: " · ")
                let font = UIFont.fbSerif(ofSize: 10.2, weight: .regular)
                let width = leaf.contentWidth - 46
                let h = FieldText.height(line, font: font, width: width, lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
                _ = FieldText.flow(line, font: font, color: style.palette.ink.withAlphaComponent(0.88),
                                   in: CGRect(x: leaf.left + 46, y: leaf.y, width: width, height: h + 2),
                                   lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
                leaf.y += max(16, h + 6)
            }
            leaf.y += 6
        }
        let tally = "\(week.nightCount) \(week.nightCount == 1 ? "night" : "nights") braided"
        drawTracked(tally, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7), color: style.palette.ink.withAlphaComponent(0.6), tracking: 1.2)
        leaf.y += 18

        // Where the week's scenes happened, on the Book's own chart.
        var visits: [String: Int] = [:]
        var route: [String] = []
        for scene in members.flatMap(\.scenes) {
            guard let room = scene.roomID, AcademyGeography.room(id: room) != nil else { continue }
            visits[room, default: 0] += 1
            if route.last != room { route.append(room) }
        }
        if !visits.isEmpty, leaf.bottom - leaf.y > 190 {
            drawEyebrow("Where it happened", style: style, leaf: &leaf)
            let w = min(leaf.contentWidth, leaf.bottom - leaf.y - 14, 270)
            let rect = CGRect(x: leaf.left, y: leaf.y, width: w, height: w * 0.92)
            drawLabyrinthChart(LabyrinthMonthChart(roomVisits: visits, route: route, cast: [], timetableOnly: false),
                               on: week.start, style: style, in: rect)
            leaf.y = rect.maxY + 8
        }
        let remaining = leaf.bottom - leaf.y - 20
        if remaining > 90 {
            drawBotanical(month: monthNumber, seed: "week-\(week.index)",
                          in: CGRect(x: leaf.left, y: leaf.bottom - min(remaining, 130), width: leaf.contentWidth, height: min(remaining, 130)),
                          alignRight: week.index % 2 == 0, rotation: week.index % 2 == 0 ? -0.06 : 0.06)
        }
    }

    // MARK: The small things

    /// Days whose own side holds a sentence and a few specimens, gathered on
    /// one leaf in date order, like a commonplace book's quieter pages.
    static func drawCommonplace(
        _ days: [BoundDay],
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !days.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Between the nights", headRight: "The small things")
        func fresh() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Between the nights", headRight: "continued")
        }
        for day in days {
            var spoken: [String] = day.words.map { "“\($0)”" }
            for keep in day.keeps {
                switch keep.kind {
                case .quotation: spoken.append("“" + keep.body.trimmingCharacters(in: .whitespacesAndNewlines) + "”")
                case .castNote, .lore:
                    spoken.append((keep.speakerName.map { "\($0): " } ?? "") + "“" + keep.body.trimmingCharacters(in: .whitespacesAndNewlines) + "”")
                default: break
                }
            }
            let wordsText = spoken.joined(separator: " ")
            let specimenLine = day.specimens.map(\.title).joined(separator: " · ")
            let wordFont = handFont(11.4)
            let wordHeight = wordsText.isEmpty ? 0 : FieldText.height(wordsText, font: wordFont, width: leaf.contentWidth - 4, lineSpacing: 1.6, paragraphSpacing: 2, justified: false)
            let specFont = UIFont.fbSerifItalic(ofSize: 8.8)
            let specHeight = specimenLine.isEmpty ? 0 : FieldText.height(specimenLine, font: specFont, width: leaf.contentWidth, lineSpacing: 1, paragraphSpacing: 0, justified: false)
            let needed = 22 + wordHeight + specHeight + 10
            if leaf.y + needed > leaf.bottom { fresh() }
            let label = "\(weekdayFormatter.string(from: day.date)) \(calendar.component(.day, from: day.date)) \(monthFormatter.string(from: day.date))"
            drawTracked(label, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7), color: style.palette.accent, tracking: 1.3)
            let moon = day.almanac
            FieldMoon.draw(center: CGPoint(x: leaf.right - 6, y: leaf.y + 4), radius: 4.5, illuminated: moon.moonIlluminated,
                           waxing: moon.moonAgeDays < MoonPhaseCalendar.synodicMonthDays / 2, ink: ink)
            leaf.y += 16
            if wordHeight > 0 {
                _ = FieldText.flow(wordsText, font: wordFont, color: ink.withAlphaComponent(0.86),
                                   in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth - 4, height: wordHeight + 2),
                                   lineSpacing: 1.6, paragraphSpacing: 2, justified: false)
                leaf.y += wordHeight + 3
            }
            if specHeight > 0 {
                _ = FieldText.flow(specimenLine, font: specFont, color: ink.withAlphaComponent(0.6),
                                   in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: specHeight + 2),
                                   lineSpacing: 1, paragraphSpacing: 0, justified: false)
                leaf.y += specHeight + 3
            }
            ink.withAlphaComponent(0.16).setFill()
            UIRectFill(CGRect(x: leaf.left, y: leaf.y + 3, width: leaf.contentWidth, height: 0.5))
            leaf.y += 14
        }
        let remaining = leaf.bottom - leaf.y
        if remaining > 90 {
            drawBotanical(month: monthNumber, seed: "commonplace-\(days.first?.id ?? "")",
                          in: CGRect(x: leaf.right - 110, y: leaf.bottom - min(remaining, 130), width: 110, height: min(remaining, 130)),
                          alignRight: true, rotation: -0.08)
        }
    }

    // MARK: The almanac of the month

    static func drawAlmanacSpread(
        _ edition: MonthlyEdition,
        book: BoundDayBook,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        facing: Bool = true,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Almanac", headRight: edition.monthName)
        let ink = style.palette.ink
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: edition.startDate)) ?? edition.startDate
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        ("\(monthFormatter.string(from: monthStart))" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 34), .foregroundColor: ink]
        )
        let year = "\(calendar.component(.year, from: monthStart))"
        drawTracked(year, at: CGPoint(x: leaf.left, y: leaf.y + 12), font: smallCaps(8), color: style.palette.accent, tracking: 2, width: leaf.contentWidth, alignment: .right)
        leaf.y += 52

        let cell = leaf.contentWidth / 7
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        for (i, label) in weekdays.enumerated() {
            drawTracked(label, at: CGPoint(x: leaf.left + cell * CGFloat(i), y: leaf.y), font: smallCaps(6.6, weight: .semibold),
                        color: ink.withAlphaComponent(0.55), tracking: 1, width: cell, alignment: .center)
        }
        leaf.y += 14
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        let rows = Int(ceil(Double(firstWeekday + dayCount) / 7.0))
        let rowHeight: CGFloat = 50
        let gridTop = leaf.y
        ink.withAlphaComponent(0.25).setFill()
        UIRectFill(CGRect(x: leaf.left, y: gridTop - 3, width: leaf.contentWidth, height: 0.5))
        for index in 0..<(rows * 7) {
            let dayNumber = index - firstWeekday + 1
            let col = index % 7, row = index / 7
            let x = leaf.left + cell * CGFloat(col)
            let y = gridTop + rowHeight * CGFloat(row)
            if row > 0 && col == 0 {
                ink.withAlphaComponent(0.14).setFill()
                UIRectFill(CGRect(x: leaf.left, y: y - 2, width: leaf.contentWidth, height: 0.4))
            }
            guard dayNumber >= 1, dayNumber <= dayCount,
                  let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) else { continue }
            let inSpan = date >= calendar.startOfDay(for: edition.startDate) && date <= edition.endDate
            ("\(dayNumber)" as NSString).draw(at: CGPoint(x: x + 4, y: y),
                                              withAttributes: [.font: UIFont.fbSerif(ofSize: 8.4, weight: .semibold),
                                                               .foregroundColor: ink.withAlphaComponent(inSpan ? 0.8 : 0.3)])
            let moon = MoonPhaseCalendar.phase(on: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
            FieldMoon.draw(center: CGPoint(x: x + cell / 2, y: y + 22), radius: 6, illuminated: moon.illuminatedFraction,
                           waxing: moon.ageDays < MoonPhaseCalendar.synodicMonthDays / 2, ink: ink)
            guard let kept = book.day(on: date, calendar: calendar) else { continue }
            var markX = x + cell / 2 - 8
            if !kept.braids.isEmpty {
                style.palette.accent.setFill()
                UIBezierPath(ovalIn: CGRect(x: markX, y: y + 36, width: 4.4, height: 4.4)).fill()
                markX += 7
            }
            if !kept.scenes.isEmpty {
                style.palette.accent.setStroke()
                let ring = UIBezierPath(ovalIn: CGRect(x: markX, y: y + 36, width: 4.4, height: 4.4))
                ring.lineWidth = 0.8
                ring.stroke()
                markX += 7
            }
            if !kept.photos.isEmpty {
                style.palette.gold.setFill()
                UIRectFill(CGRect(x: markX, y: y + 36, width: 4, height: 4))
            }
        }
        leaf.y = gridTop + rowHeight * CGFloat(rows) + 6
        let nights = book.braidCount
        let scenes = book.scenes.count
        let photos = book.days.reduce(0) { $0 + $1.photos.count }
        let legend = "● a night braided   ○ a scene read   ▪ a photograph kept"
        (legend as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                  withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.6), .foregroundColor: ink.withAlphaComponent(0.65)])
        leaf.y += 18
        let tally = "\(nights) \(nights == 1 ? "night" : "nights") braided · \(scenes) \(scenes == 1 ? "scene" : "scenes") read · \(photos) \(photos == 1 ? "photograph" : "photographs") kept"
        drawTracked(tally, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.8), color: style.palette.accent, tracking: 1)
        leaf.y += 24
        for item in (edition.publicationMatter?.almanacItems ?? []).prefix(2) {
            let text = item.body
            let font = UIFont.fbSerif(ofSize: 9.6, weight: .regular)
            let height = FieldText.height(text, font: font, width: leaf.contentWidth, lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
            if leaf.y + height + 30 > leaf.bottom - 40 { break }
            drawEyebrow(item.title, style: style, leaf: &leaf)
            _ = FieldText.flow(text, font: font, color: ink.withAlphaComponent(0.85),
                               in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: height + 4),
                               lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
            leaf.y += height + 14
        }
        let remaining = leaf.bottom - leaf.y
        if remaining > 80 {
            drawBotanical(month: monthNumber, seed: "almanac", in: CGRect(x: leaf.right - min(220, leaf.contentWidth), y: leaf.bottom - min(remaining, 150),
                                                                           width: min(220, leaf.contentWidth), height: min(remaining, 150)),
                          alignRight: true, rotation: 0)
        }

        guard facing else { return }
        // The facing page: the weeks, and the story in the order it was met.
        var right = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month, in order", headRight: edition.monthName)
        right.y += 6
        drawEyebrow("The weeks", style: style, leaf: &right)
        for week in book.weeks {
            let heading = "Week \(week.index + 1) · \(shortMonthDay.string(from: week.start)) – \(shortMonthDay.string(from: week.end))"
            (heading as NSString).draw(at: CGPoint(x: right.left, y: right.y),
                                       withAttributes: [.font: UIFont.fbSerif(ofSize: 11.5, weight: .semibold), .foregroundColor: ink])
            right.y += 16
            if let night = week.strongestNight {
                let line = "Strongest night: \(night)"
                let h = FieldText.height(line, font: .fbSerifItalic(ofSize: 9.6), width: right.contentWidth, justified: false)
                _ = FieldText.flow(line, font: .fbSerifItalic(ofSize: 9.6), color: ink.withAlphaComponent(0.78),
                                   in: CGRect(x: right.left, y: right.y, width: right.contentWidth, height: h + 3), lineSpacing: 1, paragraphSpacing: 0, justified: false)
                right.y += h + 6
            }
            right.y += 6
            if right.bottom - right.y < 110 { break }
        }
        let scenesMet = book.scenes
        if !scenesMet.isEmpty, right.bottom - right.y > 80 {
            right.y += 6
            drawEyebrow("The story, in the order you met it", style: style, leaf: &right)
            var seen = Set<String>()
            for scene in scenesMet where seen.insert(scene.title).inserted {
                if right.bottom - right.y < 24 { break }
                let line = "\(shortMonthDay.string(from: scene.readAt))  ·  \(scene.title)"
                (line as NSString).draw(at: CGPoint(x: right.left, y: right.y),
                                        withAttributes: [.font: UIFont.fbSerif(ofSize: 9.6, weight: .regular), .foregroundColor: ink.withAlphaComponent(0.85)])
                right.y += 14
            }
        }
        let rest = right.bottom - right.y
        if rest > 90 {
            drawBotanical(month: monthNumber, seed: "almanac-right", in: CGRect(x: right.left, y: right.bottom - min(rest, 170), width: right.contentWidth, height: min(rest, 170)),
                          alignRight: false, rotation: 0.05)
        }
    }

    // MARK: The days themselves

    static func drawDays(
        _ edition: MonthlyEdition,
        book: BoundDayBook,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        marginalia: [BoundMarginNote],
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        drawDays(start: edition.startDate, book: book, monthNumber: monthNumber, calendar: calendar,
                 style: style, marginalia: marginalia, context: context, cursor: &cursor)
    }

    static func drawDays(
        start: Date,
        book: BoundDayBook,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        marginalia: [BoundMarginNote],
        weekWindow: (start: Date, end: Date)? = nil,
        weekEyebrow: String? = nil,
        dayNotes: [Date: String] = [:],
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        var usedWonder = Set<String>()
        var openedWeeks = Set<Int>()
        let weekByIndex = Dictionary(uniqueKeysWithValues: book.weeks.map { ($0.index, $0) })
        let first = calendar.startOfDay(for: start)
        var pendingThin: [BoundDay] = []
        var currentWeek = -1
        func weekIndex(of day: BoundDay) -> Int {
            max(0, calendar.dateComponents([.day], from: first, to: day.date).day ?? 0) / 7
        }
        func flushThin() {
            drawCommonplace(pendingThin, monthNumber: monthNumber, calendar: calendar, style: style, context: context, cursor: &cursor)
            pendingThin = []
        }
        _ = currentWeek
        for day in book.days {
            let index = weekIndex(of: day)
            currentWeek = index
            if openedWeeks.insert(index).inserted, let week = weekByIndex[index] {
                drawWeekLeaf(week, book: book, monthNumber: monthNumber, calendar: calendar, style: style,
                             window: weekWindow, eyebrow: weekEyebrow, context: context, cursor: &cursor)
            }
            if day.hasWorldSide {
                drawWorldSide(day, monthNumber: monthNumber, calendar: calendar, style: style, marginalia: marginalia, context: context, cursor: &cursor)
            }
            if day.isThinYourSide {
                pendingThin.append(day)
            } else if day.hasYourSide {
                // A weekly issue's margins carry a line the Book wrote for the thing the reader
                // kept (the kettle that was mid-sentence), once, never the same line twice.
                var bookMargin: String?
                if weekWindow != nil, !day.words.isEmpty {
                    let parts = calendar.dateComponents([.year, .month, .day], from: day.date)
                    let key = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
                    if let line = WonderBraid.pick(text: day.words.joined(separator: " "), dateKey: key, excluding: usedWonder) {
                        usedWonder.insert(line.id)
                        bookMargin = line.text
                    }
                }
                drawYourSide(day, monthNumber: monthNumber, calendar: calendar, style: style, bookMargin: bookMargin,
                             meanwhile: dayNotes[calendar.startOfDay(for: day.date)], context: context, cursor: &cursor)
            }
        }
        flushThin()
    }
}

// MARK: - The Labyrinth, this month


extension MonthlyEditionPDFWriter {
    private static let castInks: [UIColor] = [
        UIColor(red: 0.18, green: 0.34, blue: 0.39, alpha: 1),
        UIColor(red: 0.64, green: 0.33, blue: 0.16, alpha: 1),
        UIColor(red: 0.17, green: 0.14, blue: 0.12, alpha: 1),
        UIColor(red: 0.36, green: 0.23, blue: 0.36, alpha: 1),
        UIColor(red: 0.36, green: 0.48, blue: 0.23, alpha: 1),
        UIColor(red: 0.55, green: 0.20, blue: 0.25, alpha: 1)
    ]

    /// Where the story and the timetable put people, drawn on the Book's own
    /// chart. A room is solid only once the story has been there; every other
    /// room stays as faint as the Book left it.
    static func drawLabyrinthChart(
        _ chart: LabyrinthMonthChart,
        on date: Date,
        style: EditionStyle,
        in rect: CGRect
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let ink = style.palette.ink
        let drawn = chart.drawnRoomIDs
        func point(_ p: AcademyMapPoint) -> CGPoint { CGPoint(x: rect.minX + CGFloat(p.x) * rect.width, y: rect.minY + CGFloat(p.y) * rect.height) }

        cg.saveGState()
        UIColor(red: 0.93, green: 0.88, blue: 0.76, alpha: 0.55).setFill()
        UIRectFill(rect)
        ink.withAlphaComponent(0.45).setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.7
        border.stroke()

        // The Stacks: the ring of shelving the whole school sits inside.
        if let ring = AcademyGeography.rooms.first(where: { $0.form == .ring }) {
            let c = point(ring.point)
            let r = CGRect(x: c.x - CGFloat(ring.size.x) * rect.width / 2, y: c.y - CGFloat(ring.size.y) * rect.height / 2,
                           width: CGFloat(ring.size.x) * rect.width, height: CGFloat(ring.size.y) * rect.height)
            cg.setStrokeColor(ink.withAlphaComponent(0.28).cgColor)
            cg.setLineWidth(0.7)
            cg.setLineDash(phase: 0, lengths: [3, 3])
            cg.strokeEllipse(in: r)
            cg.setLineDash(phase: 0, lengths: [])
        }

        var centers: [String: CGPoint] = [:]
        for room in AcademyGeography.rooms where room.form != .ring {
            let c = point(AcademyGeography.point(of: room, on: date))
            centers[room.id] = c
            let w = max(20, CGFloat(room.size.x) * rect.width)
            let h = max(11, CGFloat(room.size.y) * rect.height)
            let frame = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
            if drawn.contains(room.id) {
                style.palette.gold.withAlphaComponent(0.22).setFill()
                UIBezierPath(roundedRect: frame, cornerRadius: 2).fill()
                ink.withAlphaComponent(0.6).setStroke()
                let outline = UIBezierPath(roundedRect: frame, cornerRadius: 2)
                outline.lineWidth = 0.8
                outline.stroke()
            } else {
                cg.setStrokeColor(ink.withAlphaComponent(0.2).cgColor)
                cg.setLineWidth(0.5)
                cg.setLineDash(phase: 0, lengths: [2, 2])
                cg.addPath(UIBezierPath(roundedRect: frame, cornerRadius: 2).cgPath)
                cg.strokePath()
                cg.setLineDash(phase: 0, lengths: [])
            }
        }

        // Where the story went, in the order it went.
        if chart.route.count > 1 {
            cg.setStrokeColor(style.palette.accent.withAlphaComponent(0.8).cgColor)
            cg.setLineWidth(0.9)
            cg.setLineDash(phase: 0, lengths: [4, 3])
            cg.setLineJoin(.round)
            var started = false
            for id in chart.route {
                guard let c = centers[id] else { continue }
                if started { cg.addLine(to: c) } else { cg.move(to: c); started = true }
            }
            cg.strokePath()
            cg.setLineDash(phase: 0, lengths: [])
        }

        // Names, for the rooms that are solid.
        for room in AcademyGeography.rooms where drawn.contains(room.id) {
            guard let c = centers[room.id] else { continue }
            let h = max(11, CGFloat(room.size.y) * rect.height)
            let label = room.mapLabel as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerifItalic(ofSize: 6.8), .foregroundColor: ink.withAlphaComponent(0.85)]
            let size = label.size(withAttributes: attrs)
            let x = min(max(rect.minX + 2, c.x - size.width / 2), rect.maxX - size.width - 2)
            label.draw(at: CGPoint(x: x, y: min(rect.maxY - size.height - 1, c.y + h / 2 + 1)), withAttributes: attrs)
        }

        // The Cast, as dots around the rooms they spent the month in.
        for (index, person) in chart.cast.enumerated() {
            let color = castInks[index % castInks.count]
            for (rank, room) in person.rooms.prefix(3).enumerated() {
                guard let c = centers[room.roomID] else { continue }
                let angle = (CGFloat(index) * 62 + CGFloat(rank) * 23) * .pi / 180
                let radius = 8 + CGFloat(rank) * 2
                let center = CGPoint(x: c.x + cos(angle) * (radius + 6), y: c.y + sin(angle) * radius)
                let dot = 2.2 + min(2.8, CGFloat(room.count) / 14)
                color.withAlphaComponent(0.88).setFill()
                UIBezierPath(ovalIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)).fill()
                UIColor(red: 0.96, green: 0.93, blue: 0.84, alpha: 1).setStroke()
                let ring = UIBezierPath(ovalIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2))
                ring.lineWidth = 0.5
                ring.stroke()
            }
        }

        // A compass in the corner.
        let compass = CGPoint(x: rect.maxX - 18, y: rect.maxY - 18)
        ink.withAlphaComponent(0.55).setStroke()
        let rose = UIBezierPath(ovalIn: CGRect(x: compass.x - 9, y: compass.y - 9, width: 18, height: 18))
        rose.lineWidth = 0.5
        rose.stroke()
        style.palette.accent.setFill()
        let needle = UIBezierPath()
        needle.move(to: CGPoint(x: compass.x, y: compass.y - 10))
        needle.addLine(to: CGPoint(x: compass.x + 2.4, y: compass.y))
        needle.addLine(to: CGPoint(x: compass.x - 2.4, y: compass.y))
        needle.close()
        needle.fill()
        cg.restoreGState()
    }

    static func drawLabyrinthSpread(
        _ edition: MonthlyEdition,
        book: BoundDayBook,
        mapPlates: [RenderedMapPlate],
        monthNumber: Int,
        style: EditionStyle,
        facing: Bool = true,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Labyrinth", headRight: edition.monthName)
        ("Where everyone was" as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                                 withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 24), .foregroundColor: ink])
        leaf.y += 34
        let caption = book.chart.timetableOnly
            ? "No scene of this month's story was read, so this is the Academy's own timetable: where the hours put people."
            : "Drawn from the scenes you read and the Academy's timetable. A room stays blank until the story has been there."
        let captionHeight = FieldText.height(caption, font: .fbSerifItalic(ofSize: 9.2), width: leaf.contentWidth, justified: false)
        _ = FieldText.flow(caption, font: .fbSerifItalic(ofSize: 9.2), color: ink.withAlphaComponent(0.7),
                           in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: captionHeight + 3),
                           lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
        leaf.y += captionHeight + 8

        let legendRows = max(1, (book.chart.cast.count + 1) / 2)
        let legendHeight = CGFloat(legendRows) * 14 + 6
        let chartHeight = max(120, min(leaf.contentWidth * 1.12, leaf.bottom - leaf.y - legendHeight - 8))
        let chartRect = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: chartHeight)
        drawLabyrinthChart(book.chart, on: edition.startDate, style: style, in: chartRect)
        leaf.y = chartRect.maxY + 10
        let columnWidth = leaf.contentWidth / 2
        for (index, person) in book.chart.cast.enumerated() {
            let col = index % 2, row = index / 2
            let x = leaf.left + CGFloat(col) * columnWidth
            let y = leaf.y + CGFloat(row) * 14
            castInks[index % castInks.count].setFill()
            UIBezierPath(ovalIn: CGRect(x: x, y: y + 3, width: 7, height: 7)).fill()
            let days = person.sceneCount > 0
                ? (person.sceneCount == 1 ? "1 scene" : "\(person.sceneCount) scenes")
                : "on the timetable"
            ("\(person.name) · \(days)" as NSString).draw(
                at: CGPoint(x: x + 12, y: y),
                withAttributes: [.font: UIFont.fbSerif(ofSize: 8.8, weight: .regular), .foregroundColor: ink.withAlphaComponent(0.85)]
            )
        }

        guard facing else { return }
        // The facing leaf: the reader's own ground when a chart of it exists,
        // otherwise the Cast, room by room.
        var right = fieldLeaf(&cursor, style: style, context: context, headLeft: "Where you were", headRight: edition.monthName)
        if let plate = mapPlates.first {
            ("Where you were" as NSString).draw(at: CGPoint(x: right.left, y: right.y),
                                                 withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 24), .foregroundColor: ink])
            right.y += 34
            let note = "A district, not an address. Every chart of your own ground is loosened before it is printed."
            _ = FieldText.flow(note, font: .fbSerifItalic(ofSize: 9.2), color: ink.withAlphaComponent(0.7),
                               in: CGRect(x: right.left, y: right.y, width: right.contentWidth, height: 28), lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
            right.y += 24
            let available = CGRect(x: right.left, y: right.y, width: right.contentWidth, height: right.bottom - right.y - 40)
            let scale = min(available.width / plate.image.size.width, available.height / plate.image.size.height)
            let size = CGSize(width: plate.image.size.width * scale, height: plate.image.size.height * scale)
            let frame = CGRect(x: available.midX - size.width / 2, y: available.minY, width: size.width, height: size.height)
            plate.image.draw(in: frame)
            ink.withAlphaComponent(0.5).setStroke()
            let outline = UIBezierPath(rect: frame.insetBy(dx: -3, dy: -3))
            outline.lineWidth = 0.7
            outline.stroke()
            (plate.caption as NSString).draw(
                in: CGRect(x: right.left, y: frame.maxY + 10, width: right.contentWidth, height: 28),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9), .foregroundColor: ink.withAlphaComponent(0.68)]
            )
        } else {
            ("Room by room" as NSString).draw(at: CGPoint(x: right.left, y: right.y),
                                               withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 24), .foregroundColor: ink])
            right.y += 36
            for person in book.chart.cast {
                guard right.bottom - right.y > 60 else { break }
                (person.name as NSString).draw(at: CGPoint(x: right.left, y: right.y),
                                               withAttributes: [.font: UIFont.fbSerif(ofSize: 12, weight: .semibold), .foregroundColor: ink])
                right.y += 17
                let rooms = person.rooms.prefix(4).compactMap { tally -> String? in
                    AcademyGeography.room(id: tally.roomID)?.mapLabel
                }.joined(separator: " · ")
                if !rooms.isEmpty {
                    _ = FieldText.flow(rooms, font: .fbSerifItalic(ofSize: 9.6), color: ink.withAlphaComponent(0.75),
                                       in: CGRect(x: right.left, y: right.y, width: right.contentWidth, height: 28), lineSpacing: 1, paragraphSpacing: 0, justified: false)
                    right.y += 18
                }
                right.y += 8
            }
            let remaining = right.bottom - right.y
            if remaining > 100 {
                drawBotanical(month: monthNumber, seed: "labyrinth-right", in: CGRect(x: right.left, y: right.bottom - min(remaining, 200), width: right.contentWidth, height: min(remaining, 200)),
                              alignRight: true, rotation: -0.05)
            }
        }
    }

    // MARK: The Cast sketchbook

    static func drawCastSketchbook(
        _ book: BoundDayBook,
        edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor,
        limit: Int = 4
    ) {
        let ink = style.palette.ink
        for person in book.chart.cast.prefix(limit) {
            guard let asset = person.plateAssetName, let plate = UIImage(named: asset) else { continue }
            var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Cast", headRight: person.name)
            let bounds = leaf.bounds
            let available = CGRect(x: leaf.left, y: leaf.y + 4, width: leaf.contentWidth, height: bounds.height - leaf.y - leaf.margins.bottom - 70)
            let scale = min(available.width / plate.size.width, available.height / plate.size.height)
            let size = CGSize(width: plate.size.width * scale, height: plate.size.height * scale)
            let frame = CGRect(x: available.midX - size.width / 2, y: available.minY, width: size.width, height: size.height)
            if let cg = UIGraphicsGetCurrentContext() {
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                plate.draw(in: frame)
                cg.restoreGState()
            }
            style.palette.gold.setStroke()
            let outline = UIBezierPath(rect: frame.insetBy(dx: -3, dy: -3))
            outline.lineWidth = 1
            outline.stroke()
            leaf.y = frame.maxY + 14
            (person.name as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                           withAttributes: [.font: UIFont.fbSerif(ofSize: 14, weight: .semibold), .foregroundColor: ink])
            leaf.y += 20
            var facts: [String] = []
            if person.sceneCount > 0 { facts.append("in \(person.sceneCount) \(person.sceneCount == 1 ? "scene" : "scenes") you read") }
            if person.actCount > 0 { facts.append("\(person.actCount) \(person.actCount == 1 ? "act" : "acts") on the record") }
            let rooms = person.rooms.prefix(2).compactMap { AcademyGeography.room(id: $0.roomID)?.mapLabel }
            if !rooms.isEmpty { facts.append("most often in " + rooms.joined(separator: " and ")) }
            if !facts.isEmpty {
                let line = facts.joined(separator: " · ")
                _ = FieldText.flow(line, font: .fbSerifItalic(ofSize: 9.8), color: ink.withAlphaComponent(0.7),
                                   in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 30), lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
            }
        }
    }

    // MARK: Entry point

    /// Everything the Field Book adds to a month, in reading order: the
    /// almanac, the charts, the Cast, and then the days themselves.
    static func drawFieldBook(
        _ edition: MonthlyEdition,
        book: BoundDayBook,
        mapPlates: [RenderedMapPlate],
        marginalia: [BoundMarginNote],
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let calendar = Calendar.current
        let monthNumber = calendar.component(.month, from: edition.startDate)
        drawAlmanacSpread(edition, book: book, monthNumber: monthNumber, calendar: calendar, style: style, context: context, cursor: &cursor)
        drawLabyrinthSpread(edition, book: book, mapPlates: mapPlates, monthNumber: monthNumber, style: style, context: context, cursor: &cursor)
        drawCastSketchbook(book, edition: edition, style: style, context: context, cursor: &cursor)
        drawDays(edition, book: book, monthNumber: monthNumber, calendar: calendar, style: style, marginalia: marginalia, context: context, cursor: &cursor)
    }
}

// MARK: - The folio mark

extension MonthlyEditionPDFWriter {
    /// A small address at the foot of a leaf that has none of its own: the
    /// worksheet faces and spacer plates. The same mark as every other folio.
    static func drawFolioMark(number: Int, seed: String, bounds: CGRect, ink: UIColor) {
        let label = "— \(PageAddress.label(seed: seed, page: number)) —" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.fbSerifItalic(ofSize: 8.5),
            .foregroundColor: ink.withAlphaComponent(0.5)
        ]
        let width = label.size(withAttributes: attrs).width
        let inset = bounds.width * 0.1
        let x = number % 2 == 0 ? inset : bounds.width - inset - width
        label.draw(at: CGPoint(x: x, y: bounds.height - 30), withAttributes: attrs)
    }
}

// MARK: - Leaves added to reach the press minimum

extension MonthlyEditionPDFWriter {
    private static let plateAsides = [
        "Pressed here, for later.",
        "Kept in the margin, in case.",
        "Nothing is wasted. It is only resting.",
        "A page for whatever comes next.",
        "Left for the weather."
    ]

    /// A leaf added only because the press insists on a page count. It is never
    /// an empty sheet: the first two are Field Notes with a prompt, a real
    /// place to write; any further one is a plate with a line from the Book.
    static func fieldPadLeaf(
        size: CGSize,
        style: EditionStyle,
        index: Int,
        monthNumber: Int,
        seed: String,
        folio: (number: Int, seed: String)? = nil
    ) -> PDFPage? {
        let bounds = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let ink = style.palette.ink
        let data = renderer.pdfData { context in
            context.beginPage()
            drawComposedBackground(style: style, seed: "\(seed)-pad-\(index)", in: bounds)
            let inset = size.width * 0.16
            if index < 2 {
                let prompts = ["For what happened after the Book closed.", "For whatever you want to remember next."]
                ("Field notes" as NSString).draw(at: CGPoint(x: inset, y: size.height * 0.13),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 20), .foregroundColor: ink.withAlphaComponent(0.8)])
                (prompts[index] as NSString).draw(at: CGPoint(x: inset, y: size.height * 0.13 + 28),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9.5), .foregroundColor: ink.withAlphaComponent(0.55)])
                guard let cg = UIGraphicsGetCurrentContext() else { return }
                cg.setStrokeColor(ink.withAlphaComponent(0.16).cgColor)
                cg.setLineWidth(0.5)
                var y = size.height * 0.13 + 62
                while y < size.height * 0.84 {
                    cg.move(to: CGPoint(x: inset, y: y)); cg.addLine(to: CGPoint(x: size.width - inset, y: y)); y += 24
                }
                cg.strokePath()
                if let plant = FieldBotanicals.image(month: monthNumber, seed: "\(seed)-pad-\(index)") {
                    let w = min(80, plant.size.width * plant.scale / 150 * 72)
                    let h = w * plant.size.height / plant.size.width
                    plant.draw(in: CGRect(x: size.width - inset - w, y: size.height * 0.88 - h * 0.5, width: w, height: h))
                }
            } else {
                if let plant = FieldBotanicals.image(month: monthNumber, seed: "\(seed)-pad-\(index)") {
                    let w = min(130, plant.size.width * plant.scale / 150 * 72)
                    let h = w * plant.size.height / plant.size.width
                    plant.draw(in: CGRect(x: size.width / 2 - w / 2, y: size.height * 0.40 - h / 2, width: w, height: h))
                }
                let aside = plateAsides[index % plateAsides.count] as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerifItalic(ofSize: 11), .foregroundColor: ink.withAlphaComponent(0.6)]
                let width = aside.size(withAttributes: attrs).width
                aside.draw(at: CGPoint(x: size.width / 2 - width / 2, y: size.height * 0.40 + 96), withAttributes: attrs)
                drawOrnamentRow(style, centerY: size.height * 0.40 + 126, in: bounds, color: style.palette.accent.withAlphaComponent(0.5))
            }
            // A leaf the reader will write on must still be findable again.
            if let folio {
                let label = "— \(PageAddress.label(seed: folio.seed, page: folio.number)) —" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.fbSerifItalic(ofSize: 8.5),
                    .foregroundColor: ink.withAlphaComponent(0.5)
                ]
                let width = label.size(withAttributes: attrs).width
                let x = folio.number % 2 == 0 ? size.width * 0.16 : size.width * 0.84 - width
                label.draw(at: CGPoint(x: x, y: size.height * 0.92), withAttributes: attrs)
            }
        }
        return PDFDocument(data: data)?.page(at: 0)
    }
}

// MARK: - The Field Book inside a season or a year

enum FieldBookDepth { case seasonal, annual }

extension MonthlyEditionPDFWriter {
    /// One chapter of a volume: the almanac, and what the story did.
    /// A season prints the chart, the weeks and the scenes as the reader read
    /// them. A year prints the almanac and a line for every scene, because
    /// its pages are spoken for.
    static func drawChapterFieldBook(
        _ chapter: MonthlyEdition,
        book: BoundDayBook,
        depth: FieldBookDepth,
        marginalia: [BoundMarginNote],
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let calendar = Calendar.current
        let monthNumber = calendar.component(.month, from: chapter.startDate)
        drawAlmanacSpread(chapter, book: book, monthNumber: monthNumber, calendar: calendar, style: style,
                          facing: false, context: context, cursor: &cursor)
        switch depth {
        case .seasonal:
            // A month with no scene read has only the timetable to chart:
            // that is a fact worth one line in a month book, not a leaf here.
            if !book.chart.timetableOnly {
                drawLabyrinthSpread(chapter, book: book, mapPlates: [], monthNumber: monthNumber, style: style,
                                    facing: false, context: context, cursor: &cursor)
            }
            let first = calendar.startOfDay(for: chapter.startDate)
            var opened = Set<Int>()
            let weekByIndex = Dictionary(uniqueKeysWithValues: book.weeks.map { ($0.index, $0) })
            for day in book.days where day.hasWorldSide {
                let index = max(0, calendar.dateComponents([.day], from: first, to: day.date).day ?? 0) / 7
                if opened.insert(index).inserted, let week = weekByIndex[index] {
                    drawWeekLeaf(week, book: book, monthNumber: monthNumber, calendar: calendar, style: style, context: context, cursor: &cursor)
                }
                drawWorldSide(day, monthNumber: monthNumber, calendar: calendar, style: style, marginalia: marginalia,
                              context: context, cursor: &cursor)
            }
        case .annual:
            drawStoryDigest(chapter, book: book, monthNumber: monthNumber, calendar: calendar, style: style,
                            context: context, cursor: &cursor)
        }
    }

    /// A line for every scene the reader met this month, and what they chose.
    static func drawStoryDigest(
        _ chapter: MonthlyEdition,
        book: BoundDayBook,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        var rows: [(Date, String, String?)] = []
        var seen = Set<String>()
        for scene in book.scenes where seen.insert(scene.contentID).inserted {
            let choices = book.scenes.filter { $0.contentID == scene.contentID }.compactMap(\.choiceLabel)
            rows.append((scene.readAt, scene.title, choices.isEmpty ? nil : choices.joined(separator: " → ")))
        }
        guard !rows.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The story", headRight: chapter.monthName)
        ("The story, as you met it" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 22), .foregroundColor: ink])
        leaf.y += 38
        for row in rows {
            if leaf.bottom - leaf.y < 48 { break }
            drawTracked(shortMonthDay.string(from: row.0), at: CGPoint(x: leaf.left, y: leaf.y + 2), font: smallCaps(6.8),
                        color: style.palette.accent, tracking: 1)
            let font = UIFont.fbSerif(ofSize: 11, weight: .semibold)
            let width = leaf.contentWidth - 50
            let h = FieldText.height(row.1, font: font, width: width, lineSpacing: 1, paragraphSpacing: 0, justified: false)
            _ = FieldText.flow(row.1, font: font, color: ink, in: CGRect(x: leaf.left + 50, y: leaf.y, width: width, height: h + 2),
                               lineSpacing: 1, paragraphSpacing: 0, justified: false)
            leaf.y += h + 2
            if let choice = row.2 {
                let cfont = UIFont.fbSerifItalic(ofSize: 9.2)
                let ch = FieldText.height("you chose · \(choice)", font: cfont, width: width, lineSpacing: 1, paragraphSpacing: 0, justified: false)
                _ = FieldText.flow("you chose · \(choice)", font: cfont, color: ink.withAlphaComponent(0.65),
                                   in: CGRect(x: leaf.left + 50, y: leaf.y, width: width, height: ch + 2),
                                   lineSpacing: 1, paragraphSpacing: 0, justified: false)
                leaf.y += ch + 2
            }
            leaf.y += 10
        }
        let remaining = leaf.bottom - leaf.y
        if remaining > 90 {
            drawBotanical(month: monthNumber, seed: "digest-\(chapter.monthName)",
                          in: CGRect(x: leaf.right - 110, y: leaf.bottom - min(remaining, 130), width: 110, height: min(remaining, 130)),
                          alignRight: true, rotation: -0.08)
        }
    }

    /// The Cast of a whole volume: the same plates, ranked across every chapter.
    static func drawVolumeCast(
        _ chapters: [MonthlyEdition],
        title: String,
        style: EditionStyle,
        limit: Int,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        var merged: [String: BoundCastPresence] = [:]
        for person in chapters.compactMap({ $0.dayBook?.chart.cast }).flatMap({ $0 }) {
            if var existing = merged[person.slug] {
                existing.sceneCount += person.sceneCount
                existing.actCount += person.actCount
                existing.daysPresent += person.daysPresent
                var rooms: [String: Int] = [:]
                for tally in existing.rooms + person.rooms { rooms[tally.roomID, default: 0] += tally.count }
                existing.rooms = rooms.map { BoundRoomTally(roomID: $0.key, count: $0.value) }
                    .sorted { ($1.count, $0.roomID) < ($0.count, $1.roomID) }
                merged[person.slug] = existing
            } else {
                merged[person.slug] = person
            }
        }
        let ranked = merged.values.sorted {
            ($1.sceneCount * 4 + $1.actCount * 2, $0.slug) < ($0.sceneCount * 4 + $0.actCount * 2, $1.slug)
        }
        guard !ranked.isEmpty, let any = chapters.first(where: { $0.dayBook != nil }) else { return }
        let chart = LabyrinthMonthChart(roomVisits: [:], route: [], cast: ranked, timetableOnly: false)
        let pseudo = BoundDayBook(days: [], weeks: [], chart: chart, quietDates: [])
        drawCastSketchbook(pseudo, edition: any, style: style, context: context, cursor: &cursor, limit: limit)
    }
}

// MARK: - The leaf before a worksheet

extension MonthlyEditionPDFWriter {
    /// A worksheet has to open on a particular side of the paper. The leaf that
    /// makes that happen is a plate, not an empty sheet: a pressed plant and a
    /// line from the Book, on the same paper as everything else. (The reverse of
    /// a worksheet stays plain white on purpose, so marker never ghosts through.)
    static func drawSpacerPlate(style: EditionStyle, bounds: CGRect, seed: String) {
        drawComposedBackground(style: style, seed: seed, in: bounds)
        let asides = [
            "Pressed here, for later.",
            "Kept in the margin, in case.",
            "A page for whatever comes next.",
            "Left for the weather."
        ]
        let index = ConstellationKeeper.stableIndex(for: "spacer-\(seed)", count: asides.count)
        let month = 1 + ConstellationKeeper.stableIndex(for: "spacer-month-\(seed)", count: 12)
        if let plant = FieldBotanicals.image(month: month, seed: seed) {
            let w = min(150, plant.size.width * plant.scale / 150 * 72)
            let h = w * plant.size.height / plant.size.width
            plant.draw(in: CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2 - 20, width: w, height: h))
        }
        let aside = asides[index] as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.fbSerifItalic(ofSize: 11), .foregroundColor: style.palette.ink.withAlphaComponent(0.6)
        ]
        let width = aside.size(withAttributes: attrs).width
        aside.draw(at: CGPoint(x: bounds.midX - width / 2, y: bounds.midY + 70), withAttributes: attrs)
    }
}

// MARK: - The weekly, told by the day

extension MonthlyEditionPDFWriter {
    /// A saddle-stitched week: title leaf, the week's own leaf, seven days laid
    /// out as the monthly lays out its days, the worksheet, and a closing leaf.
    /// Returns 0 when the week would not fit the press's 48 pages, so the
    /// caller can fall back to the earlier form.
    static func writeWeeklyFieldBookInterior(
        _ matter: WeeklyPublicationMatter,
        book: BoundDayBook,
        dedication: BoundDedication?,
        spec: PrintSpec,
        style: EditionStyle,
        to url: URL
    ) throws -> Int {
        let target = PrintGeometry.boundPageCount(rawPages: matter.preferredPhysicalPageCount, spec: spec)
        var level = Handbook.weeklyStartLevel(forPages: target)
        var best: (level: Int, count: Int)?
        var lastRendered = -1
        // Find the thickest Handbook slice that still fits the chosen magazine.
        for _ in 0..<12 {
            let slice = matter.handbook?.weeklySlice(issueNumber: matter.issue.number, level: level)
            let count = try weeklyFieldBookPass(matter, book: book, dedication: dedication, spec: spec,
                                                style: style, handbook: slice, to: url)
            lastRendered = level
            if count == 0 { return 0 }
            if count <= target {
                best = (level, count)
                // Close enough: the pad leaves absorb a few, never a dozen.
                if count >= target - 3 || level >= Handbook.weeklyLevelRange.upperBound || matter.handbook == nil { break }
                level += 1
            } else {
                if best != nil || level <= Handbook.weeklyLevelRange.lowerBound { break }
                level -= 1
            }
        }
        if let best, best.level != lastRendered {
            let slice = matter.handbook?.weeklySlice(issueNumber: matter.issue.number, level: best.level)
            _ = try weeklyFieldBookPass(matter, book: book, dedication: dedication, spec: spec,
                                        style: style, handbook: slice, to: url)
        }
        guard let document = PDFDocument(url: url) else { return 0 }
        guard document.pageCount <= WeeklyPrintEditorialPolicy.technicalMaximumPages else { return 0 }
        let issue = matter.issue
        let monthNumber = Calendar.current.component(.month, from: issue.startDate)
        let padTo = PrintGeometry.boundPageCount(rawPages: max(document.pageCount, target), spec: spec)
        if padTo > document.pageCount {
            let unpadded = document.pageCount
            // The closing leaf will land on the last page; its folio must say so.
            let slice = matter.handbook?.weeklySlice(issueNumber: issue.number, level: best?.level ?? lastRendered)
            _ = try weeklyFieldBookPass(matter, book: book, dedication: dedication, spec: spec,
                                        style: style, handbook: slice, closingFolio: padTo, to: url)
            guard let restamped = PDFDocument(url: url), restamped.pageCount == unpadded else { return 0 }
            let bounds = restamped.page(at: 0)?.bounds(for: .mediaBox) ?? .zero
            for index in 0..<(padTo - unpadded) {
                if let leaf = fieldPadLeaf(size: bounds.size, style: style, index: index, monthNumber: monthNumber,
                                           seed: "weekly-\(issue.number)",
                                           folio: (unpadded + index, matter.bindingID ?? "weekly-fb-\(issue.number)")) {
                    // Kept before the closing leaf, so the issue still ends where it means to.
                    restamped.insert(leaf, at: max(0, restamped.pageCount - 1))
                }
            }
            guard restamped.write(to: url) else {
                throw NSError(domain: "Bindery", code: 8, userInfo: [NSLocalizedDescriptionKey: "The weekly interior would not save."])
            }
            return restamped.pageCount
        }
        guard document.write(to: url) else {
            throw NSError(domain: "Bindery", code: 8, userInfo: [NSLocalizedDescriptionKey: "The weekly interior would not save."])
        }
        return document.pageCount
    }

    /// One render of the weekly Field Book at a given Handbook slice, unpadded.
    private static func weeklyFieldBookPass(
        _ matter: WeeklyPublicationMatter,
        book: BoundDayBook,
        dedication: BoundDedication?,
        spec: PrintSpec,
        style: EditionStyle,
        handbook: Handbook?,
        closingFolio: Int? = nil,
        to url: URL
    ) throws -> Int {
        let issue = matter.issue
        // Each pass of the fit loop deals the same deck from the top, so a rebind looks the same.
        // The deck is not reset when the pass ends: the pad leaves made after it carry on from
        // where the book left off instead of dealing the cover's drawing a second time.
        MarginaliaDealer.reset()
        let fullBleed = PrintGeometry.fullBleedTrimInches(spec: spec)
        let pageBounds = CGRect(x: 0, y: 0, width: fullBleed.width * PrintSpec.pointsPerInch, height: fullBleed.height * PrintSpec.pointsPerInch)
        let m = spec.interiorMarginsPoints
        let margins = UIEdgeInsets(top: m.top, left: max(m.left, 50), bottom: m.bottom, right: max(m.right, 50))
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let calendar = Calendar.current
        let monthNumber = calendar.component(.month, from: issue.startDate)
        let ink = style.palette.ink
        let marginalia = issue.marginalia ?? []

        try renderer.writePDF(to: url) { context in
            var cursor = PDFCursor(bounds: pageBounds, margins: margins)
            cursor.seed = "weekly-fb-\(issue.number)"
            cursor.addressSeed = matter.bindingID

            // The title leaf.
            beginComposedPage(context, style: style, cursor: &cursor)
            let b = cursor.bounds
            drawTracked("The Book of You", at: CGPoint(x: 0, y: b.height * 0.15), font: smallCaps(8), color: ink.withAlphaComponent(0.6),
                        tracking: 3, width: b.width, alignment: .center)
            drawTracked("Issue No. \(issue.number)", at: CGPoint(x: 0, y: b.height * 0.15 + 18), font: smallCaps(8),
                        color: style.palette.accent, tracking: 2.4, width: b.width, alignment: .center)
            let titleFont = UIFont.fbSerif(ofSize: 30, weight: .bold)
            let titleWidth = b.width - 110
            let titleHeight = FieldText.height(issue.resolvedEditorialTitle, font: titleFont, width: titleWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineSpacing = 2
            (issue.resolvedEditorialTitle as NSString).draw(
                in: CGRect(x: 55, y: b.height * 0.28, width: titleWidth, height: titleHeight + 6),
                withAttributes: [.font: titleFont, .foregroundColor: ink, .paragraphStyle: paragraph]
            )
            var y = b.height * 0.28 + titleHeight + 20
            drawOrnamentRow(style, centerY: y, in: b, color: style.palette.gold)
            y += 24
            drawTracked(matter.coverReaderName, at: CGPoint(x: 0, y: y), font: smallCaps(8.4), color: ink.withAlphaComponent(0.8),
                        tracking: 2, width: b.width, alignment: .center)
            drawTracked(issue.dateRange, at: CGPoint(x: 0, y: y + 16), font: smallCaps(7.4, weight: .semibold), color: ink.withAlphaComponent(0.55),
                        tracking: 1.8, width: b.width, alignment: .center)
            if let lead = issue.highlights.first?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                let leadFont = UIFont.fbSerifItalic(ofSize: 11)
                let leadHeight = FieldText.height(lead, font: leadFont, width: titleWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
                paragraph.lineSpacing = 2
                (lead as NSString).draw(
                    in: CGRect(x: 55, y: y + 46, width: titleWidth, height: min(120, leadHeight + 6)),
                    withAttributes: [.font: leadFont, .foregroundColor: ink.withAlphaComponent(0.7), .paragraphStyle: paragraph]
                )
            }
            drawBotanical(month: monthNumber, seed: "weekly-title-\(issue.number)",
                          in: CGRect(x: b.width / 2 - 70, y: b.height - 190, width: 140, height: 150), alignRight: false, rotation: 0)

            if dedication != nil {
                drawDedication(dedication, style: style, context: context, cursor: &cursor)
            }

            // The week, bound: the binding story, when the Book wrote one.
            var storyLeaf: PDFCursor?
            if let story = issue.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                var rest = FieldMarked(parsing: story)
                var passes = 0
                var first = true
                var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The week, bound", headRight: "Issue No. \(issue.number)")
                while !rest.isEmpty, passes < 4 {
                    passes += 1
                    if first {
                        drawEyebrow("A binding of the week's nights", style: style, leaf: &leaf)
                    }
                    let flow = FieldText.flow(rest, font: .fbSerif(ofSize: 11.2, weight: .regular), color: ink.withAlphaComponent(0.92),
                                              in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y),
                                              dropCap: first ? style.palette.accent : nil)
                    first = false
                    guard flow.usedHeight > 0 else { break }
                    leaf.y += flow.usedHeight + 10
                    rest = flow.rest
                    if !rest.isEmpty {
                        leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The week, bound", headRight: "continued")
                    }
                }
                storyLeaf = leaf
            }

            // The reader's own best lines of the week, then what the world did on the nights the Book
            // braided, under the bound story so a light week's first leaf is never mostly paper.
            let labyrinthNotes = WeeklyCuration.labyrinthNotes(from: issue.pages)
            if let leaf = storyLeaf, issue.highlights.count > 0, leaf.bottom - leaf.y > 150 {
                var shelf = leaf
                shelf.y += 8
                drawEyebrow("Lines I kept from your week", style: style, leaf: &shelf)
                let lineFont = UIFont.fbSerifItalic(ofSize: 11.2)
                for line in issue.highlights.prefix(3) {
                    let quoted = "\u{201C}\(line.trimmingCharacters(in: CharacterSet(charactersIn: ".")))\u{201D}"
                    let height = FieldText.height(quoted, font: lineFont, width: shelf.contentWidth - 14, lineSpacing: 2, paragraphSpacing: 0, justified: false)
                    guard shelf.y + height + 70 < shelf.bottom else { break }
                    _ = FieldText.flow(quoted, font: lineFont, color: ink.withAlphaComponent(0.88),
                                       in: CGRect(x: shelf.left + 14, y: shelf.y, width: shelf.contentWidth - 14, height: height + 4),
                                       lineSpacing: 2, paragraphSpacing: 0, justified: false)
                    shelf.y += height + 10
                }
                storyLeaf = shelf
            }
            drawLabyrinthNotes(labyrinthNotes, calendar: calendar, style: style,
                               after: storyLeaf, context: context, cursor: &cursor)
            var notesByDay: [Date: String] = [:]
            for note in labyrinthNotes where notesByDay[calendar.startOfDay(for: note.date)] == nil {
                notesByDay[calendar.startOfDay(for: note.date)] = note.text
            }

            let lastDay = calendar.date(byAdding: .day, value: -1, to: issue.endDate) ?? issue.endDate
            drawDays(start: issue.startDate, book: book, monthNumber: monthNumber, calendar: calendar,
                     style: style, marginalia: marginalia, weekWindow: (issue.startDate, lastDay),
                     weekEyebrow: "Issue No. \(issue.number)", dayNotes: notesByDay, context: context, cursor: &cursor)

            if let handbook, !handbook.isEmpty {
                drawHandbook(handbook, readerName: matter.coverReaderName,
                             termLabel: "Issue No. \(issue.number) \u{00B7} \(issue.dateRange)",
                             monthNumber: monthNumber, showsContents: false,
                             style: style, context: context, cursor: &cursor)
            }

            drawEditionPlayLeaves(issue.playLeaves ?? [], style: style, context: context, cursor: &cursor)

            // The week closes.
            var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The week closes", headRight: "Issue No. \(issue.number)", folioNumber: closingFolio)
            leaf.y += 30
            let closing = matter.closingNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? "The week is kept. The next one is already gathering."
            let closeFont = UIFont.fbSerifItalic(ofSize: 15)
            let closeHeight = FieldText.height(closing, font: closeFont, width: leaf.contentWidth, lineSpacing: 3, paragraphSpacing: 0, justified: false)
            _ = FieldText.flow(closing, font: closeFont, color: ink.withAlphaComponent(0.9), in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: closeHeight + 8),
                               lineSpacing: 3, paragraphSpacing: 0, justified: false)
            leaf.y += closeHeight + 28
            let nights = book.braidCount, scenes = book.scenes.count
            let photos = book.days.reduce(0) { $0 + $1.photos.count }
            let tally = "\(nights) \(nights == 1 ? "night" : "nights") braided · \(scenes) \(scenes == 1 ? "scene" : "scenes") read · \(photos) \(photos == 1 ? "photograph" : "photographs") kept"
            drawTracked(tally, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.8), color: style.palette.accent, tracking: 1,
                        width: leaf.contentWidth, alignment: .center)
            drawBotanical(month: monthNumber, seed: "weekly-close-\(issue.number)",
                          in: CGRect(x: leaf.left, y: leaf.y + 30, width: leaf.contentWidth, height: min(160, leaf.bottom - leaf.y - 90)),
                          alignRight: false, rotation: 0.04)
            let colophon = "The Book of You · Issue No. \(issue.number) · Bound on device · Made with ReEnchanted" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerifItalic(ofSize: 8), .foregroundColor: ink.withAlphaComponent(0.5)]
            let cw = colophon.size(withAttributes: attrs).width
            colophon.draw(at: CGPoint(x: cursor.bounds.midX - cw / 2, y: leaf.bottom - 10), withAttributes: attrs)
        }

        guard let document = PDFDocument(url: url) else { return 0 }
        return document.pageCount
    }
}

// MARK: - The Ledger of Nights

extension MonthlyEditionPDFWriter {
    /// Every night of the year in a line. The nights printed in full are a
    /// sampling; this is the whole year, named.
    static func drawNightsLedger(
        _ lines: [BoundNightLine],
        year: Int,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !lines.isEmpty else { return }
        let calendar = Calendar.current
        let ink = style.palette.ink
        let rowFont = UIFont.fbSerif(ofSize: 8.8, weight: .semibold)
        let lineFont = UIFont.fbSerifItalic(ofSize: 8.4)
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Ledger of Nights", headRight: "\(year)")
        ("The Ledger of Nights" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 24), .foregroundColor: ink])
        leaf.y += 36
        let intro = "Every night of the year, in a line. The nights in this book are a sampling; the rest are named here, and every one is whole in your archive."
        let introHeight = FieldText.height(intro, font: .fbSerifItalic(ofSize: 9.4), width: leaf.contentWidth, lineSpacing: 1.4, paragraphSpacing: 0, justified: false)
        _ = FieldText.flow(intro, font: .fbSerifItalic(ofSize: 9.4), color: ink.withAlphaComponent(0.7),
                           in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: introHeight + 4),
                           lineSpacing: 1.4, paragraphSpacing: 0, justified: false)
        leaf.y += introHeight + 16

        var currentMonth = -1
        for line in lines {
            let month = calendar.component(.month, from: line.date)
            let headingNeeded: CGFloat = month != currentMonth ? 26 : 0
            if leaf.y + headingNeeded + 14 > leaf.bottom {
                leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Ledger of Nights", headRight: "continued")
                currentMonth = -1
            }
            if month != currentMonth || currentMonth == -1 {
                currentMonth = month
                leaf.y += 6
                drawTracked(monthFormatter.string(from: line.date), at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7.2),
                            color: style.palette.accent, tracking: 1.8)
                ink.withAlphaComponent(0.25).setFill()
                UIRectFill(CGRect(x: leaf.left, y: leaf.y + 12, width: leaf.contentWidth, height: 0.5))
                leaf.y += 18
            }
            let day = "\(calendar.component(.day, from: line.date))" as NSString
            day.draw(at: CGPoint(x: leaf.left, y: leaf.y),
                     withAttributes: [.font: UIFont.fbSerif(ofSize: 8.4, weight: .regular), .foregroundColor: style.palette.accent])
            let textX = leaf.left + 18
            let available = leaf.contentWidth - 18
            let title = line.title as NSString
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: ink.withAlphaComponent(0.92)]
            let titleWidth = min(available * 0.6, title.size(withAttributes: titleAttrs).width)
            var shownTitle = line.title
            while (shownTitle as NSString).size(withAttributes: titleAttrs).width > titleWidth, shownTitle.count > 4 {
                shownTitle = String(shownTitle.dropLast())
            }
            if shownTitle != line.title { shownTitle += "…" }
            (shownTitle as NSString).draw(at: CGPoint(x: textX, y: leaf.y), withAttributes: titleAttrs)
            let usedTitle = (shownTitle as NSString).size(withAttributes: titleAttrs).width
            var rest = line.line
            let restAttrs: [NSAttributedString.Key: Any] = [.font: lineFont, .foregroundColor: ink.withAlphaComponent(0.6)]
            let restWidth = available - usedTitle - 8
            if restWidth > 30, !rest.isEmpty {
                while (rest as NSString).size(withAttributes: restAttrs).width > restWidth, rest.count > 4 {
                    rest = String(rest.dropLast())
                }
                if rest != line.line { rest = rest.trimmingCharacters(in: .whitespaces) + "…" }
                (rest as NSString).draw(at: CGPoint(x: textX + usedTitle + 8, y: leaf.y + 0.4), withAttributes: restAttrs)
            }
            leaf.y += 12.4
        }
        let remaining = leaf.bottom - leaf.y
        if remaining > 90 {
            drawBotanical(month: 12, seed: "ledger-end-\(year)",
                          in: CGRect(x: leaf.right - 110, y: leaf.bottom - min(remaining, 130), width: 110, height: min(remaining, 130)),
                          alignRight: true, rotation: -0.06)
        }
    }
}

// MARK: - The reader's typed keeps

extension MonthlyEditionPDFWriter {
    /// Cuts at the last sentence that fits, so a card never ends mid-word.
    private static func excerpt(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let head = String(trimmed.prefix(limit))
        if let end = head.lastIndex(where: { ".!?”\"".contains($0) }), head.distance(from: head.startIndex, to: end) > limit / 2 {
            return String(head[...end])
        }
        return head.trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func keepEyebrow(_ keep: BoundDayKeep) -> String {
        switch keep.kind {
        case .letter: return keep.speakerName.map { "A letter from \($0)" } ?? "A letter"
        case .castNote: return keep.speakerName.map { "A note from \($0)" } ?? "In the margin"
        case .enchantment: return "An enchantment"
        case .story: return "A story the Book told"
        case .classSession: return "Class"
        case .club: return "Club"
        case .plate: return "Illuminated"
        case .lore: return "From the library"
        case .quotation: return "Kept"
        }
    }

    /// Draws a box around a card's content: a hairline frame and a faint wash.
    static func drawCardFrame(_ rect: CGRect, style: EditionStyle, double: Bool = false) {
        UIColor.white.withAlphaComponent(0.34).setFill()
        UIBezierPath(rect: rect).fill()
        style.palette.ink.withAlphaComponent(0.45).setStroke()
        let outline = UIBezierPath(rect: rect)
        outline.lineWidth = 0.6
        outline.stroke()
        if double {
            style.palette.gold.setStroke()
            let inner = UIBezierPath(rect: rect.insetBy(dx: 3, dy: 3))
            inner.lineWidth = 0.7
            inner.stroke()
        }
    }

    static func drawKeeps(
        _ keeps: [BoundDayKeep],
        day: BoundDay,
        style: EditionStyle,
        leaf: inout PDFCursor,
        cursor: inout PDFCursor,
        context: UIGraphicsPDFRendererContext,
        headLeft: String,
        dateLine: String
    ) {
        let ink = style.palette.ink
        func fresh() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
        }
        func room(_ needed: CGFloat) { if leaf.y + needed > leaf.bottom { fresh() } }

        for keep in keeps {
            let font = UIFont.fbSerif(ofSize: 10, weight: .regular)
            switch keep.kind {
            case .plate:
                guard let image = firstImage(from: keep.mediaAssets) else { continue }
                let maxHeight: CGFloat = 230
                let scale = min((leaf.contentWidth - 16) / image.size.width, maxHeight / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                room(size.height + 54)
                drawTracked(keepEyebrow(keep), at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7), color: style.palette.accent, tracking: 1.6)
                leaf.y += 14
                let frame = CGRect(x: leaf.left + (leaf.contentWidth - size.width) / 2, y: leaf.y + 6, width: size.width, height: size.height)
                style.palette.gold.setStroke()
                let outer = UIBezierPath(rect: frame.insetBy(dx: -6, dy: -6)); outer.lineWidth = 1.2; outer.stroke()
                let innerFrame = UIBezierPath(rect: frame.insetBy(dx: -3, dy: -3)); innerFrame.lineWidth = 0.5; innerFrame.stroke()
                image.draw(in: frame)
                leaf.y = frame.maxY + 14
                let caption = excerpt(keep.body.isEmpty ? keep.title : keep.body, limit: 140)
                let h = FieldText.height(caption, font: .fbSerifItalic(ofSize: 9.4), width: leaf.contentWidth, lineSpacing: 1, paragraphSpacing: 0, justified: false)
                _ = FieldText.flow(caption, font: .fbSerifItalic(ofSize: 9.4), color: ink.withAlphaComponent(0.7),
                                   in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: h + 3), lineSpacing: 1, paragraphSpacing: 0, justified: false)
                leaf.y += h + 12

            case .letter, .story:
                // Long forms: set as prose that may run on to further leaves.
                room(110)
                drawEyebrow(keepEyebrow(keep), style: style, leaf: &leaf)
                let titleFont = UIFont.fbSerifItalic(ofSize: keep.kind == .story ? 17 : 13)
                let th = FieldText.height(keep.title, font: titleFont, width: leaf.contentWidth, justified: false)
                _ = FieldText.flow(keep.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: th + 4),
                                   lineSpacing: 0, paragraphSpacing: 0, justified: false)
                leaf.y += th + 8
                var rest = FieldMarked(parsing: keep.body)
                var capped = keep.kind == .story
                var passes = 0
                while !rest.isEmpty, passes < 12 {
                    passes += 1
                    if leaf.bottom - leaf.y < 60 { fresh() }
                    let flow = FieldText.flow(rest, font: UIFont.fbSerif(ofSize: 10.4, weight: .regular),
                                              color: ink.withAlphaComponent(0.9),
                                              in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y),
                                              dropCap: capped ? style.palette.accent : nil)
                    capped = false
                    guard flow.usedHeight > 0 else { fresh(); continue }
                    leaf.y += flow.usedHeight + 6
                    rest = flow.rest
                    if !rest.isEmpty { fresh() }
                }
                if keep.kind == .letter, let name = keep.speakerName {
                    room(24)
                    let sig = "— \(name)" as NSString
                    let attrs: [NSAttributedString.Key: Any] = [.font: handFont(13), .foregroundColor: keep.accentHex.map { castInk($0) } ?? style.palette.accent]
                    let w = sig.size(withAttributes: attrs).width
                    sig.draw(at: CGPoint(x: leaf.right - w, y: leaf.y), withAttributes: attrs)
                    leaf.y += 24
                }
                leaf.y += 8

            case .castNote, .lore:
                let who = keep.speakerName.map { "\($0): " } ?? ""
                let text = who + "“" + excerpt(keep.body, limit: 320) + "”"
                let width = min(leaf.contentWidth, 270)
                let height = slipHeight(text, width: width, fontSize: 10.6)
                room(height + 22)
                drawTracked(keepEyebrow(keep), at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.6), color: style.palette.accent, tracking: 1.4)
                leaf.y += 12
                drawHandSlip(text, style: style, in: CGRect(x: leaf.left + 2, y: leaf.y, width: width, height: height),
                             rotation: frac("keep-\(keep.id)") > 0.5 ? 0.022 : -0.022, seed: "keep-\(keep.id)", fontSize: 10.6,
                             color: keep.accentHex.map { castInk($0) })
                leaf.y += height + 14

            case .quotation:
                let text = "“" + excerpt(keep.body, limit: 260) + "”"
                let h = FieldText.height(text, font: .fbSerifItalic(ofSize: 11.5), width: leaf.contentWidth - 40, lineSpacing: 2, paragraphSpacing: 0, justified: false)
                room(h + 26)
                _ = FieldText.flow(text, font: .fbSerifItalic(ofSize: 11.5), color: ink.withAlphaComponent(0.82),
                                   in: CGRect(x: leaf.left + 20, y: leaf.y, width: leaf.contentWidth - 40, height: h + 4),
                                   lineSpacing: 2, paragraphSpacing: 0, justified: false)
                leaf.y += h + 16

            case .classSession, .club, .enchantment:
                let body = excerpt(keep.body, limit: keep.kind == .enchantment ? 520 : 460)
                let inner = leaf.contentWidth - 28
                let image = keep.kind == .enchantment ? firstImage(from: keep.mediaAssets) : nil
                let imageSide: CGFloat = image == nil ? 0 : 74
                let textWidth = inner - (image == nil ? 0 : imageSide + 12)
                let bodyHeight = FieldText.height(body, font: font, width: textWidth, lineSpacing: 1.8, paragraphSpacing: 3, justified: false)
                let titleHeight = FieldText.height(keep.title, font: .fbSerif(ofSize: 13, weight: .bold), width: inner, lineSpacing: 1, paragraphSpacing: 0, justified: false)
                let metaLine = [keep.room, keep.professor, keep.clock].compactMap { $0 }.joined(separator: " · ")
                let height = 14 + 12 + titleHeight + (metaLine.isEmpty ? 0 : 14) + max(bodyHeight, imageSide) + 14
                room(height + 10)
                let card = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: height)
                drawCardFrame(card, style: style, double: keep.kind != .classSession)
                var y = card.minY + 12
                drawTracked(keepEyebrow(keep), at: CGPoint(x: card.minX + 14, y: y), font: smallCaps(6.6), color: style.palette.accent, tracking: 1.6)
                if keep.kind == .club || keep.kind == .enchantment {
                    // A small seal.
                    let seal = CGRect(x: card.maxX - 30, y: card.minY + 8, width: 18, height: 18)
                    style.palette.gold.withAlphaComponent(0.85).setFill()
                    UIBezierPath(ovalIn: seal).fill()
                    ("✦" as NSString).draw(at: CGPoint(x: seal.minX + 4.2, y: seal.minY + 2.2),
                                           withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.white])
                }
                y += 14
                _ = FieldText.flow(keep.title, font: .fbSerif(ofSize: 13, weight: .bold), color: ink,
                                   in: CGRect(x: card.minX + 14, y: y, width: inner, height: titleHeight + 3),
                                   lineSpacing: 1, paragraphSpacing: 0, justified: false)
                y += titleHeight + 4
                if !metaLine.isEmpty {
                    (metaLine as NSString).draw(at: CGPoint(x: card.minX + 14, y: y),
                                                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.8), .foregroundColor: ink.withAlphaComponent(0.6)])
                    y += 14
                }
                _ = FieldText.flow(body, font: font, color: ink.withAlphaComponent(0.9),
                                   in: CGRect(x: card.minX + 14, y: y, width: textWidth, height: bodyHeight + 4),
                                   lineSpacing: 1.8, paragraphSpacing: 3, justified: false)
                if let image {
                    let scale = min(imageSide / image.size.width, imageSide / image.size.height)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(in: CGRect(x: card.maxX - 14 - size.width, y: y, width: size.width, height: size.height))
                }
                leaf.y = card.maxY + 12
            }
        }
    }
}
