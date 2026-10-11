import UIKit
import ImageIO
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
    /// Runs the reader wrote themselves, set in their hand and ink.
    var hands: [Range<Int>] = []
    /// A lead-in set in small capitals, the way a book opens a section
    /// without a drop cap.
    var smallCaps: Range<Int>? = nil

    init(text: String, italics: [Range<Int>] = [], hands: [Range<Int>] = []) {
        self.text = text
        self.italics = italics
        self.hands = hands
    }

    /// Marks every place one of `phrases` appears verbatim, so a sentence of
    /// the reader's own set into a scene prints in their hand.
    func markingHands(_ phrases: [String]) -> FieldMarked {
        guard !phrases.isEmpty else { return self }
        let chars = Array(text)
        let haystack = String(chars)
        var found = hands
        for raw in Set(phrases) {
            // A telling may lower a sentence's first letter or drop its full stop.
            let phrase = raw.trimmingCharacters(in: CharacterSet(charactersIn: " .!?\n"))
            guard phrase.count >= 16 else { continue }
            var searchStart = haystack.startIndex
            while let range = haystack.range(of: phrase, options: .caseInsensitive, range: searchStart..<haystack.endIndex) {
                let lower = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
                let length = haystack.distance(from: range.lowerBound, to: range.upperBound)
                found.append(lower..<(lower + length))
                searchStart = range.upperBound
            }
        }
        var copy = self
        copy.hands = found
        return copy
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
        // Leading whitespace is trimmed after the cut; keep the offsets true.
        let trimmedLead = kept.prefix { $0.isWhitespace }.count
        let final = String(kept.dropFirst(trimmedLead)).trimmingCharacters(in: .whitespacesAndNewlines)
        func shift(_ ranges: [Range<Int>]) -> [Range<Int>] {
            ranges.compactMap { range -> Range<Int>? in
                let lower = max(0, range.lowerBound - n - trimmedLead), upper = range.upperBound - n - trimmedLead
                return upper > lower ? lower..<upper : nil
            }
        }
        var dropped = FieldMarked(text: final, italics: shift(italics), hands: shift(hands))
        dropped.smallCaps = smallCaps.flatMap { shift([$0]).first }
        return dropped
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
        // Body text hyphenates to keep its justified lines even; a heading never breaks a word.
        paragraph.hyphenationFactor = font.pointSize >= 14 ? 0 : 0.9
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
            if let caps = marked.smallCaps {
                let chars = Array(marked.text)
                if caps.upperBound <= chars.count {
                    let lower = String(chars[0..<caps.lowerBound]).utf16.count
                    let upper = String(chars[0..<caps.upperBound]).utf16.count
                    let features: [[UIFontDescriptor.FeatureKey: Int]] = [
                        [.type: kLowerCaseType, .selector: kLowerCaseSmallCapsSelector],
                        [.type: kUpperCaseType, .selector: kUpperCaseSmallCapsSelector]
                    ]
                    let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: features])
                    if upper <= length, upper > lower {
                        let range = NSRange(location: lower, length: upper - lower)
                        result.addAttribute(.font, value: UIFont(descriptor: descriptor, size: base.pointSize), range: range)
                        result.addAttribute(.kern, value: 0.6, range: range)
                    }
                }
            }
            if !marked.hands.isEmpty {
                let chars = Array(marked.text)
                let hand = MonthlyEditionPDFWriter.handFont(base.pointSize * 1.12)
                for range in marked.hands where range.upperBound <= chars.count {
                    let lower = String(chars[0..<range.lowerBound]).utf16.count
                    let upper = String(chars[0..<range.upperBound]).utf16.count
                    guard upper <= length, upper > lower else { continue }
                    let nsRange = NSRange(location: lower, length: upper - lower)
                    result.addAttribute(.font, value: hand, range: nsRange)
                    result.addAttribute(.foregroundColor, value: MonthlyEditionPDFWriter.readerInk, range: nsRange)
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
        /// A monthly pack's own drawings appear once in a book, never twice.
        var oncePerBook: Bool { id.hasPrefix("pack:") }
    }

    private static var current: MarginaliaDealer?
    /// Everything this book has drawn so far, across every month's deck: a season or a year
    /// changes deck at each chapter, and the pack's drawings must still only appear once.
    private static var usedInBook = Set<String>()
    /// The story's margin notes this book has printed, by name.
    private static var storyMarksUsed = Set<String>()
    private static var storyMarkCache: [Int: [(name: String, path: String)]] = [:]

    /// A new book starts a new deck. Called at the top of every interior render.
    static func reset() {
        current = nil
        usedInBook = []
        storyMarksUsed = []
        storyMarkCache = [:]
        NotePromptDealer.reset()
        #if DEBUG
        dealtLog = []
        #endif
    }

    #if DEBUG
    /// A proof can ask to see another month's margins (the October art on a September week).
    static var forcedMonth: Int?
    /// Every drawing dealt since the last reset, by id, for the proof harness's tally.
    static var dealtLog: [String] = []
    #endif

    static func next(month requested: Int) -> UIImage? {
        var month = requested
        #if DEBUG
        month = forcedMonth ?? requested
        #endif
        if current?.month != month { current = MarginaliaDealer(month: month) }
        return current?.deal()
    }

    // MARK: The story's margin notes

    /// The next of the month's story margin notes (the handwritten lines a monthly pack ties to its
    /// story: "Some doors have started listening back."), each at most once a book, in the pack's
    /// order. Nil when the month's pack has none, or every one is already in the book.
    static func nextStoryMark(month requested: Int) -> UIImage? {
        var month = requested
        #if DEBUG
        month = forcedMonth ?? requested
        #endif
        if storyMarkCache[month] == nil {
            storyMarkCache[month] = installedArt(marker: ".mark.").filter { $0.month == month }.map { ($0.name, $0.path) }
        }
        for mark in storyMarkCache[month] ?? [] where !storyMarksUsed.contains(mark.name) {
            guard let image = UIImage(contentsOfFile: mark.path) else { continue }
            storyMarksUsed.insert(mark.name)
            #if DEBUG
            dealtLog.append("story:\(month):\(mark.name)")
            #endif
            return image
        }
        return nil
    }

    /// A story note a kept page already carried, printed on its day: the dealer won't print it again.
    /// Returns false when this book has already printed it.
    static func claimStoryMark(reference: String) -> Bool {
        let file = URL(fileURLWithPath: reference).lastPathComponent
        guard let marker = file.range(of: ".mark.") else { return true }
        let name = String(file[marker.upperBound...]).replacingOccurrences(of: ".png", with: "")
        let bare = name.hasPrefix("v2.") ? String(name.dropFirst(3)) : name
        guard storyMarksUsed.insert(bare).inserted else { return false }
        #if DEBUG
        dealtLog.append("story:page:\(bare)")
        #endif
        return true
    }

    // MARK: The deck

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
        for _ in 0...(pool.count * 2) {
            if deck.isEmpty {
                refill()
                if deck.isEmpty { return nil }
            }
            let drawing = deck.removeFirst()
            if drawing.oncePerBook, Self.usedInBook.contains(drawing.id) { continue }
            if let image = drawing.load() {
                Self.usedInBook.insert(drawing.id)
                #if DEBUG
                Self.dealtLog.append(drawing.id)
                #endif
                return image
            }
        }
        return nil
    }

    /// The next round, in its weighted order: drawings this book hasn't used yet come first, so
    /// nothing is drawn twice until everything has been drawn once, and the pack's own drawings
    /// are never dealt again at all.
    private func refill() {
        round += 1
        let open = pool.filter { !($0.oncePerBook && Self.usedInBook.contains($0.id)) }
        let byID = Dictionary(uniqueKeysWithValues: open.map { ($0.id, $0) })
        let ordered = MarginaliaDeck.order(open.map { ($0.id, $0.weight) }, seed: "margins-\(month)-\(round)").compactMap { byID[$0] }
        deck = ordered.filter { !Self.usedInBook.contains($0.id) } + ordered.filter { Self.usedInBook.contains($0.id) }
    }

    private static func pool(month: Int) -> [Drawing] {
        var drawings: [Drawing] = []
        var seen = Set<String>()
        func add(_ id: String, _ weight: Double, _ load: @escaping () -> UIImage?) {
            if seen.insert(id).inserted { drawings.append(Drawing(id: id, weight: weight, load: load)) }
        }
        // The month's own marginalia lead: the drawings its pack delivered (October's cat, lantern,
        // key, moth), and the month's botanicals.
        let packArt = installedArt(marker: ".seasonal.")
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

    /// Every drawing of one kind a monthly pack delivered that is still installed on this device,
    /// with the month it was made for: `.seasonal.` for the month's own drawings, `.mark.` for its
    /// story's margin notes. Any month's pack works the same way, by the delivered file names
    /// (`reenchanted-managed-<pack>-2026-11-<pack>.seasonal.<name>.png`). A reissued drawing
    /// (`.v2.`) replaces the first of its name.
    private static func installedArt(marker: String) -> [(name: String, path: String, month: Int?)] {
        guard let directory = MonthlyIssueDeliveryPolicy.managedContentDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var found: [String: (path: String, month: Int?, name: String, reissued: Bool)] = [:]
        for url in files where url.pathExtension.lowercased() == "png" {
            let file = url.lastPathComponent
            guard file.hasPrefix(MonthlyIssueDeliveryPolicy.managedFilePrefix),
                  let range = file.range(of: marker) else { continue }
            let before = String(file[..<range.lowerBound])
            var month: Int?
            if let dated = before.range(of: "-\\d{4}-\\d{2}-", options: .regularExpression) {
                month = Int(before[dated].dropLast().suffix(2))
            }
            var name = String(file[range.upperBound...]).replacingOccurrences(of: ".png", with: "")
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

    /// Labels and running heads: a tracked serif, the way a printed book
    /// sets them, never an interface's heavy sans.
    static func smallCaps(_ size: CGFloat = 7.2, weight: UIFont.Weight = .heavy) -> UIFont {
        .fbSerif(ofSize: size * 1.1, weight: weight == .heavy || weight == .bold ? .semibold : weight)
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

    /// A torn paper label, taped on at a slant. The caller owns its measured height.
    @discardableResult
    static func drawHandSlip(
        _ text: String,
        style: EditionStyle,
        in rect: CGRect,
        rotation: CGFloat,
        seed: String,
        fontSize: CGFloat = 11.5,
        color: UIColor? = nil
    ) -> FieldText.Flow {
        let fill = blend(parchment(for: style).top, UIColor(white: 1, alpha: 1), 0.45)
        drawTornScrap(in: rect, rotation: rotation, fill: fill, seed: seed)
        drawTapeStrip(center: CGPoint(x: rect.midX + (frac("\(seed)-tx") - 0.5) * rect.width * 0.5, y: rect.minY + 1),
                      length: 38, angle: (frac("\(seed)-ta") - 0.5) * 0.6, tint: style.palette.gold)
        let inset = rect.insetBy(dx: 11, dy: 7)
        return FieldText.flow(text, font: handFont(fontSize), color: color ?? style.palette.ink.withAlphaComponent(0.85),
                           in: inset, lineSpacing: 1.6, paragraphSpacing: 2, justified: false)
    }

    static func slipHeight(_ text: String, width: CGFloat, fontSize: CGFloat = 11.5) -> CGFloat {
        FieldText.height(text, font: handFont(fontSize), width: width - 22, lineSpacing: 1.6, paragraphSpacing: 2, justified: false) + 20
    }

    /// A choice is a complete Reader mark, not a one-line caption. Measure it
    /// in the same hand as the drawing, and carry any remainder onto fresh paper.
    private static func drawChoiceSlip(
        _ choice: String, style: EditionStyle, leaf: inout PDFCursor, fresh: () -> PDFCursor,
        seed: String, fontSize: CGFloat = 10.8, widthFraction: CGFloat = 0.7,
        alignedRight: Bool = true, rotation: CGFloat = 0.025, color: UIColor? = nil
    ) {
        let text = "you chose · \(choice)"
        let width = min(leaf.contentWidth * widthFraction,
                        max(120, (text as NSString).size(withAttributes: [.font: handFont(fontSize)]).width + 32))
        var rest = FieldMarked(parsing: text)
        let needed = slipHeight(text, width: width, fontSize: fontSize) + 8
        if leaf.y + needed > leaf.bottom { leaf = fresh() }
        var part = 0
        while !rest.isEmpty {
            if leaf.bottom - leaf.y < handFont(fontSize).lineHeight + 26 { leaf = fresh() }
            let height = min(slipHeight(rest.text, width: width, fontSize: fontSize), leaf.bottom - leaf.y - 8)
            let rect = CGRect(x: alignedRight ? leaf.right - width : leaf.left, y: leaf.y, width: width, height: height)
            let flow = drawHandSlip(rest.text, style: style, in: rect, rotation: rotation,
                                    seed: "\(seed)-\(part)", fontSize: fontSize, color: color ?? style.palette.accent)
            leaf.y += height + 8
            rest = flow.rest
            part += 1
            if !rest.isEmpty { leaf = fresh() }
        }
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
        specimens.isEmpty ? 0 : 18 + CGFloat(specimens.count) * 24
    }

    /// The day's small kept things as paper tags, each with its hole, its
    /// name and the hour, pinned one under another.
    private static func drawSpecimens(_ specimens: [BoundDaySpecimen], style: EditionStyle, in rect: CGRect) {
        guard !specimens.isEmpty else { return }
        drawTracked("Pinned to the day", at: CGPoint(x: rect.minX, y: rect.minY), font: smallCaps(6.8), color: style.palette.accent, tracking: 1.4)
        var y = rect.minY + 15
        let font = handFont(9.8)
        for (index, specimen) in specimens.enumerated() {
            var label = [specimen.title, specimen.clock].compactMap { $0 }.joined(separator: " · ")
            while (label as NSString).size(withAttributes: [.font: font]).width > rect.width - 34, label.count > 6 {
                label = String(label.dropLast(3)) + "…"
            }
            let w = min(rect.width - 4, (label as NSString).size(withAttributes: [.font: font]).width + 30)
            let frame = CGRect(x: rect.minX + (index % 2 == 0 ? 0 : 6), y: y, width: w, height: 19)
            let notch: CGFloat = 6
            let tag = UIBezierPath()
            tag.move(to: CGPoint(x: frame.minX + notch, y: frame.minY))
            tag.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
            tag.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
            tag.addLine(to: CGPoint(x: frame.minX + notch, y: frame.maxY))
            tag.addLine(to: CGPoint(x: frame.minX, y: frame.midY))
            tag.close()
            if let cg = UIGraphicsGetCurrentContext() {
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0.5, height: 1), blur: 1.5, color: UIColor.black.withAlphaComponent(0.15).cgColor)
                blend(parchment(for: style).top, UIColor(red: 0.93, green: 0.86, blue: 0.70, alpha: 1), 0.55).setFill()
                tag.fill()
                cg.restoreGState()
            }
            style.palette.ink.withAlphaComponent(0.3).setStroke()
            tag.lineWidth = 0.4
            tag.stroke()
            let hole = CGRect(x: frame.minX + notch + 1, y: frame.midY - 1.8, width: 3.6, height: 3.6)
            parchment(for: style).top.setFill(); UIBezierPath(ovalIn: hole).fill()
            style.palette.ink.withAlphaComponent(0.35).setStroke(); UIBezierPath(ovalIn: hole).stroke()
            (label as NSString).draw(at: CGPoint(x: frame.minX + notch + 9, y: frame.minY + 2.5),
                                     withAttributes: [.font: font, .foregroundColor: style.palette.ink.withAlphaComponent(0.85)])
            y += 24
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

    /// With `tale`, the day carries only the opening of each scene and points
    /// to its chapter of the Month's Tale, and the leaf is handed back so the
    /// reader's own day can continue on it: each day complete in itself.
    @discardableResult
    static func drawWorldSide(
        _ day: BoundDay,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        marginalia: [BoundMarginNote],
        tale: [String: Int]? = nil,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) -> PDFCursor? {
        let headLeft = "\(monthFormatter.string(from: day.date))"
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "The Days")
        drawDateStrip(day, calendar: calendar, style: style, leaf: &leaf)

        func continuationLeaf() -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft,
                      headRight: "\(shortMonthDay.string(from: day.date)) · continued")
        }
        func newContinuation() { leaf = continuationLeaf() }
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
        if let tale {
            drawSceneOpenings(day, tale: tale, style: style, leaf: &leaf, fresh: continuationLeaf)
        }
        for scene in day.scenes where tale == nil {
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
                drawChoiceSlip(choice, style: style, leaf: &leaf, fresh: continuationLeaf,
                               seed: "choice-\(scene.id)", fontSize: 11, alignedRight: false, rotation: -0.03)
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

        // In a tale-bound book the reader's day continues on this leaf.
        if tale != nil { return leaf }

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
        return nil
    }

    /// Each scene the reader met that day, as its opening lines, the choice
    /// they made, and where the whole of it is bound.
    private static func drawSceneOpenings(
        _ day: BoundDay,
        tale: [String: Int],
        style: EditionStyle,
        leaf: inout PDFCursor,
        fresh: () -> PDFCursor
    ) {
        let ink = style.palette.ink
        var seen = Set<String>()
        for scene in day.scenes where seen.insert(scene.contentID).inserted {
            let parts = day.scenes.filter { $0.contentID == scene.contentID }
            if leaf.y + 150 > leaf.bottom { leaf = fresh() }
            let place: String
            if scene.isReport {
                place = scene.roomName.map { "The Academy's record · \($0)" } ?? "The Academy's record"
            } else {
                place = scene.roomName.map { "In the Labyrinth · \($0)" } ?? "In the Labyrinth"
            }
            drawEyebrow(place, style: style, leaf: &leaf)
            let titleFont = UIFont.fbSerifItalic(ofSize: 19)
            let titleHeight = FieldText.height(scene.title, font: titleFont, width: leaf.contentWidth, justified: false)
            _ = FieldText.flow(scene.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: titleHeight + 4),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += titleHeight + 5
            let opening = BoundDayBook.opening(of: scene.body, words: 58)
            let openingFont = UIFont.fbSerif(ofSize: 10.2, weight: .regular)
            let oh = FieldText.height(opening, font: openingFont, width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: true)
            _ = FieldText.flow(FieldMarked(text: opening), font: openingFont, color: ink.withAlphaComponent(0.86),
                               in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: oh + 4),
                               dropCap: style.palette.accent, lineSpacing: 2, paragraphSpacing: 0, justified: true)
            leaf.y += max(oh, openingFont.lineHeight * 3 + 4) + 6
            let choices = parts.compactMap { $0.isReport ? nil : $0.choiceLabel }
            for (index, choice) in choices.prefix(3).enumerated() {
                drawChoiceSlip(choice, style: style, leaf: &leaf, fresh: fresh,
                               seed: "choice-\(scene.id)-\(index)", fontSize: 10.6, widthFraction: 0.62,
                               alignedRight: false, rotation: index % 2 == 0 ? -0.03 : 0.025)
            }
            if let number = tale[scene.contentID] {
                let pointer = scenesPointToSeasonPlates
                    ? "Its plate is no. \(RomanNumeral.of(number)) in \(picturesTitle)."
                    : scene.isReport
                    ? "The Academy's record of it is chapter \(RomanNumeral.of(number)) of the Month's Tale."
                    : "The whole scene, as you read it, is chapter \(RomanNumeral.of(number)) of the Month's Tale."
                let font = UIFont.fbSerifItalic(ofSize: 8.8)
                ("→ " + pointer as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                                   withAttributes: [.font: font, .foregroundColor: style.palette.accent])
                leaf.y += 18
            }
            // The Book's own note in the margin of its story, where there's room for it.
            if !scene.isReport {
                drawStoryMark(month: Calendar.current.component(.month, from: scene.readAt), style: style, leaf: &leaf)
            }
            leaf.y += 6
        }
    }

    /// One of the month's story margin notes, set across the leaf under a scene: the handwritten
    /// line and its little drawing, a touch askew. Only when it fits; a story note never forces a leaf.
    @discardableResult
    static func drawStoryMark(month: Int, style: EditionStyle, leaf: inout PDFCursor, maxWidth: CGFloat = 250) -> Bool {
        guard leaf.bottom - leaf.y > 90, let mark = MarginaliaDealer.nextStoryMark(month: month),
              let cg = UIGraphicsGetCurrentContext() else { return false }
        let honest = mark.size.width * mark.scale / 150 * 72
        let width = min(maxWidth, leaf.contentWidth * 0.8, honest)
        let height = width * mark.size.height / mark.size.width
        guard leaf.y + height + 8 < leaf.bottom else { return false }
        let ready = PrintImage.fitted(mark, drawnPoints: CGSize(width: width, height: height))
        let x = leaf.right - width - 4
        cg.saveGState()
        cg.translateBy(x: x + width / 2, y: leaf.y + 4 + height / 2)
        cg.rotate(by: -0.025)
        ready.draw(in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        cg.restoreGState()
        leaf.y += height + 10
        return true
    }

    // MARK: The reader's day

    static func drawYourSide(
        _ day: BoundDay,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        bookMargin: String? = nil,
        meanwhile: String? = nil,
        continuing: PDFCursor? = nil,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let headLeft = "Your day"
        let dateLine = "\(weekdayFormatter.string(from: day.date)) \(calendar.component(.day, from: day.date)) \(monthFormatter.string(from: day.date))"
        var leaf: PDFCursor
        if var open = continuing, open.bottom - open.y > 120 {
            // The world's side of the day is above: a rule, then the reader's.
            open.y += 4
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: open.left, y: open.y))
            rule.addLine(to: CGPoint(x: open.right, y: open.y))
            style.palette.gold.withAlphaComponent(0.55).setStroke()
            rule.lineWidth = 0.6
            rule.stroke()
            open.y += 12
            leaf = open
        } else {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: dateLine)
        }
        func newContinuation() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
        }
        let ink = style.palette.ink
        let bodyFont = UIFont.fbSerif(ofSize: 10.8, weight: .regular)
        var firstProse = true

        // What the reader wrote comes first: it is their journal. The Book's
        // telling of the night follows it.
        func continuationLeaf() -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
        }
        // An entry the night's telling quotes whole is printed there, in their hand.
        let tellings = day.braids.map(\.body).joined(separator: "\n")
        drawEntries(entriesNotCarried(day.entries, by: tellings), style: style, leaf: &leaf, fresh: continuationLeaf)

        for braid in day.braids {
            if leaf.bottom - leaf.y < 130 { newContinuation() }
            var eyebrow = "Night braid"
            if let date = braid.date {
                eyebrow += " · kept at \(clockString(date, calendar: calendar))"
            }
            drawEyebrow(eyebrow, style: style, leaf: &leaf)
            // The phone names a night with a fragment; a weak one ("A people")
            // is left off, and the eyebrow carries the night alone.
            if !isWeakBraidTitle(braid.title) {
                let titleFont = UIFont.fbSerifItalic(ofSize: 16)
                let titleHeight = FieldText.height(braid.title, font: titleFont, width: leaf.contentWidth, justified: false)
                _ = FieldText.flow(braid.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: titleHeight + 4),
                                   lineSpacing: 0, paragraphSpacing: 0, justified: false)
                leaf.y += titleHeight + 6
            } else {
                leaf.y += 2
            }
            let parts = braidParts(braid.body)
            var rest = FieldMarked(parsing: parts.telling).markingHands(entrySentences(day.entries))
            // A drop cap opens a week, or a night that begins on a new letter;
            // otherwise the first words open in small capitals. Twenty-one Y's
            // down a month read like a stamp.
            let firstLetter = rest.text.first.map { Character($0.uppercased()) }
            var capped = firstProse && firstLetter != lastDropCapLetter
            if capped { lastDropCapLetter = firstLetter } else if firstProse {
                let words = rest.text.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                let lead = words.prefix(3).joined(separator: " ")
                rest.smallCaps = 0..<min(lead.count, rest.text.count)
            }
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
            // The Book's own thread, carried night to night (the biscuit bet, the
            // dragon in the margin): set apart, so a reader can follow it.
            if let thread = parts.thread {
                let font = UIFont.fbSerifItalic(ofSize: 10)
                let text = "✦  " + thread
                let h = FieldText.height(text, font: font, width: leaf.contentWidth - 30, lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
                if leaf.bottom - leaf.y < h + 12 { newContinuation() }
                _ = FieldText.flow(text, font: font, color: style.palette.accent.withAlphaComponent(0.9),
                                   in: CGRect(x: leaf.left + 15, y: leaf.y, width: leaf.contentWidth - 30, height: h + 3),
                                   lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
                leaf.y += h + 10
            }
            if let kept = parts.kept {
                let font = UIFont.fbSerifItalic(ofSize: 10.2)
                let h = FieldText.height(kept, font: font, width: leaf.contentWidth - 40, lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
                if leaf.bottom - leaf.y < h + 12 { newContinuation() }
                let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 1.5
                (kept as NSString).draw(in: CGRect(x: leaf.left + 20, y: leaf.y, width: leaf.contentWidth - 40, height: h + 4),
                                        withAttributes: [.font: font, .foregroundColor: style.palette.accent, .paragraphStyle: para])
                leaf.y += h + 12
            }
        }

        // Everything else they kept that day, each dressed for what it is.
        let shownKeeps = keepsNotCarried(day.keeps, by: day.braids.map(\.body).joined(separator: "\n"))
        if !shownKeeps.isEmpty {
            drawKeeps(shownKeeps, day: day, style: style, leaf: &leaf, cursor: &cursor, context: context,
                      headLeft: headLeft, dateLine: dateLine)
        }

        // The photograph, the specimens that fed the night, the reader's words.
        let photo = firstPhoto(day.photos)
        let specimens = day.specimens
        // The day's entries are printed whole above; keep replies sit with their keeps.
        let words: [String] = day.entries.isEmpty
            ? day.words.filter { word in !day.keeps.contains { $0.readerReply == word } }
            : []
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
                // A story note the book has already printed (under a scene, say) isn't printed again.
                guard MarginaliaDealer.claimStoryMark(reference: asset.reference), let image = image(from: asset) else { continue }
                let scale = min(120 / image.size.width, 62 / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                if leaf.y + size.height + 6 > leaf.bottom { break }
                image.draw(in: CGRect(x: x, y: leaf.y, width: size.width, height: size.height))
                x += size.width + 16
            }
            leaf.y += 72
        }

        // Scrapbook pages that don't print full size: small, mounted, on their day.
        let smallScrapbook = day.scrapbook.filter { !$0.fullPage }
        if !smallScrapbook.isEmpty {
            let printWidth: CGFloat = min(118, (leaf.contentWidth - 16 * CGFloat(min(3, smallScrapbook.count) - 1)) / CGFloat(min(3, smallScrapbook.count)))
            let printHeight = printWidth * 1.5 + 22
            if leaf.bottom - leaf.y < printHeight + 24 {
                leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
            }
            drawEyebrow(smallScrapbook.count == 1 ? "From your scrapbook" : "From your scrapbook · \(smallScrapbook.count) pages", style: style, leaf: &leaf)
            // Three to a row, as many rows as the day needs: none is left out.
            for row in stride(from: 0, to: smallScrapbook.count, by: 3) {
                if row > 0 {
                    if leaf.bottom - leaf.y < printHeight + 10 {
                        leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
                    }
                }
                var x = leaf.left
                for (index, page) in smallScrapbook[row..<min(smallScrapbook.count, row + 3)].enumerated() {
                    guard let picture = scrapbookPicture(page) else { continue }
                    drawPressedPhoto(picture, caption: page.title, style: style,
                                     in: CGRect(x: x, y: leaf.y + 4, width: printWidth, height: printHeight),
                                     rotation: index % 2 == 0 ? -0.025 : 0.02)
                    x += printWidth + 16
                }
                leaf.y += printHeight + 14
            }
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
            // The date strip above already gives a day with a world side its sky.
            if !day.hasWorldSide, !line.isEmpty, leaf.bottom - leaf.y > 90 {
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
        // The foot of a day turns through three things, so a month of days
        // doesn't end the same way thirty times: a place to write, the moon that
        // night drawn as a field note, and a drawing pressed into the page.
        let foot = dayFootCount
        if remaining > 100 { dayFootCount += 1 }
        if remaining > 100, foot % 3 == 1 {
            drawMoonCard(day, calendar: calendar, style: style,
                         in: CGRect(x: leaf.left, y: leaf.y + 4, width: leaf.contentWidth, height: min(remaining - 8, 160)))
        } else if remaining > 140, foot % 3 == 2, let drawing = MarginaliaDealer.next(month: monthNumber) {
            drawPressedDrawing(drawing, day: day, style: style,
                               in: CGRect(x: leaf.left, y: leaf.y + 6, width: leaf.contentWidth, height: min(remaining - 10, 210)))
        } else if remaining > 100, let prompt = NotePromptDealer.next(.day, seed: day.id) {
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
        headLeft: String = "Between the nights",
        headRight: String = "The small things",
        perDay: Int? = nil,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !days.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: headRight)
        func fresh() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "continued")
        }
        for day in days {
            var spoken: [String] = day.words.map { "“\($0)”" }
            for keep in day.keeps {
                switch keep.kind {
                case .quotation: spoken.append("“" + keep.body.trimmingCharacters(in: .whitespacesAndNewlines) + "”" + (keep.speakerName.map { " — \($0)" } ?? ""))
                case .castNote, .lore:
                    spoken.append((keep.speakerName.map { "\($0): " } ?? "") + "“" + keep.body.trimmingCharacters(in: .whitespacesAndNewlines) + "”")
                default: break
                }
            }
            let wordsText = (perDay.map { Array(spoken.prefix($0)) } ?? spoken).joined(separator: " ")
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
        leaf.y += 6
        if drawStoryMark(month: monthNumber, style: style, leaf: &leaf) { return }
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
        tale: [String: Int]? = nil,
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
            // A stub of two days or fewer at the month's end, with no night in it, rides on the
            // week before rather than taking a leaf of its own.
            if openedWeeks.insert(index).inserted, let week = weekByIndex[index],
               index == 0 || week.nightCount > 0
                || (calendar.dateComponents([.day], from: week.start, to: week.end).day ?? 7) >= 2 {
                lastDropCapLetter = nil
                drawWeekLeaf(week, book: book, monthNumber: monthNumber, calendar: calendar, style: style,
                             window: weekWindow, eyebrow: weekEyebrow, context: context, cursor: &cursor)
            }
            var open: PDFCursor?
            if day.hasWorldSide {
                open = drawWorldSide(day, monthNumber: monthNumber, calendar: calendar, style: style, marginalia: marginalia,
                                     tale: tale, context: context, cursor: &cursor)
            }
            if day.isThinYourSide && open == nil {
                pendingThin.append(day)
            } else if day.hasYourSide || open != nil {
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
                             meanwhile: dayNotes[calendar.startOfDay(for: day.date)], continuing: open,
                             context: context, cursor: &cursor)
                for page in day.scrapbook where page.fullPage {
                    drawScrapbookLeaf(page, headLeft: "Your day",
                                      dateLine: "\(weekdayFormatter.string(from: day.date)) \(calendar.component(.day, from: day.date)) \(monthFormatter.string(from: day.date))",
                                      style: style, context: context, cursor: &cursor)
                }
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
        let month = Calendar.current.component(.month, from: edition.startDate)
        for person in book.chart.cast.prefix(limit) {
            drawCastPlateLeaf(person, headLeft: "The Cast", month: month, style: style, context: context, cursor: &cursor)
        }
    }

    /// One of the Cast, full page: their plate, their name, what they did in the span.
    @discardableResult
    static func drawCastPlateLeaf(
        _ person: BoundCastPresence,
        headLeft: String,
        caption: String? = nil,
        month: Int? = nil,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) -> Bool {
        let ink = style.palette.ink
        do {
            // This month's portrait of them, when the pack drew one; else their standing plate.
            guard let plate = EditionPlates.cast(person.slug, month: month)
                    ?? person.plateAssetName.flatMap({ UIImage(named: $0) }) else { return false }
            var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: person.name)
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
            if let caption { facts.insert(caption, at: 0) }
            if !facts.isEmpty {
                let line = facts.joined(separator: " · ")
                _ = FieldText.flow(line, font: .fbSerifItalic(ofSize: 9.8), color: ink.withAlphaComponent(0.7),
                                   in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 44), lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
            }
            return true
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
        askedInThisBook = []
        lastDropCapLetter = nil
        dayFootCount = 0
        if let frontispiece = EditionPlates.frontispiece(month: monthNumber) {
            var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Frontispiece", headRight: monthFormatter.string(from: edition.startDate))
            let box = CGRect(x: leaf.left, y: leaf.y + 10, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 60)
            let scale = min(box.width / frontispiece.size.width, box.height / frontispiece.size.height)
            let size = CGSize(width: frontispiece.size.width * scale, height: frontispiece.size.height * scale)
            let frame = CGRect(x: box.midX - size.width / 2, y: box.minY, width: size.width, height: size.height)
            style.palette.gold.setStroke()
            let outer = UIBezierPath(rect: frame.insetBy(dx: -8, dy: -8)); outer.lineWidth = 1.1; outer.stroke()
            let inner = UIBezierPath(rect: frame.insetBy(dx: -4, dy: -4)); inner.lineWidth = 0.5; inner.stroke()
            frontispiece.draw(in: frame)
            leaf.y = frame.maxY + 18
            let caption = edition.monthName
            drawTracked(caption, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7.4), color: style.palette.accent, tracking: 2,
                        width: leaf.contentWidth, alignment: .center)
        }
        drawAlmanacSpread(edition, book: book, monthNumber: monthNumber, calendar: calendar, style: style, context: context, cursor: &cursor)
        drawLabyrinthSpread(edition, book: book, mapPlates: mapPlates, monthNumber: monthNumber, style: style, context: context, cursor: &cursor)
        drawCastSketchbook(book, edition: edition, style: style, context: context, cursor: &cursor)
        let chapters = book.taleChapters
        let tale = Dictionary(uniqueKeysWithValues: chapters.map { ($0.contentID, $0.number) })
        drawDays(start: edition.startDate, book: book, monthNumber: monthNumber, calendar: calendar,
                 style: style, marginalia: marginalia, tale: chapters.isEmpty ? nil : tale, context: context, cursor: &cursor)
        drawMonthsTale(chapters, readerSentences: book.readerSentences, monthNumber: monthNumber, calendar: calendar,
                       style: style, context: context, cursor: &cursor)
    }

    // MARK: The Month's Tale

    /// The month's story bound whole, after the Days: one chapter per scene,
    /// set continuously like a book, with the reader's choices in their hand
    /// where they made them and any sentence of theirs the story quotes.
    static func drawMonthsTale(
        _ chapters: [BoundTaleChapter],
        readerSentences: [String],
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !chapters.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Month's Tale", headRight: monthFormatter.string(from: chapters[0].readAt))
        func nextTaleLeaf() -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: "The Month's Tale", headRight: monthFormatter.string(from: chapters[0].readAt))
        }
        func fresh() { leaf = nextTaleLeaf() }
        // The part's own title, on its first leaf.
        leaf.y += 10
        drawTracked("Part Two", at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7.4), color: style.palette.accent, tracking: 2.2)
        leaf.y += 16
        let partTitle = "The Month’s Tale"
        let partFont = UIFont.fbSerif(ofSize: 28, weight: .bold)
        (partTitle as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y), withAttributes: [.font: partFont, .foregroundColor: ink])
        leaf.y += partFont.lineHeight + 4
        let dek = "The story you read this month, bound whole. Where you chose, your choice is written in; where the story borrowed a sentence of yours, it is in your hand."
        let dekFont = UIFont.fbSerifItalic(ofSize: 10.4)
        let dh = FieldText.height(dek, font: dekFont, width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        _ = FieldText.flow(dek, font: dekFont, color: ink.withAlphaComponent(0.7), in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: dh + 4),
                           lineSpacing: 2, paragraphSpacing: 0, justified: false)
        leaf.y += dh + 22

        let bodyFont = UIFont.fbSerif(ofSize: 10.1, weight: .regular)
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        for chapter in chapters {
            let scenePlate = EditionPlates.scene(chapter.contentID, month: monthNumber)
            // A chapter with a plate keeps its title and its plate together.
            if leaf.bottom - leaf.y < 170 + (scenePlate.map { plateHeight($0, width: leaf.contentWidth, maxHeight: 230) } ?? 0) { fresh() }
            // The chapter head: numeral, title, when and where it was read, and who was there.
            let headTop = leaf.y
            var headWidth = leaf.contentWidth
            if scenePlate == nil, chapter.number % 2 == 1, let vignette = MarginaliaDealer.next(month: monthNumber) {
                let side: CGFloat = 66
                let scale = min(side / vignette.size.width, side / vignette.size.height)
                let size = CGSize(width: vignette.size.width * scale, height: vignette.size.height * scale)
                vignette.draw(in: CGRect(x: leaf.right - size.width, y: headTop - 2, width: size.width, height: size.height))
                headWidth -= side + 10
            }
            drawTracked("Chapter \(RomanNumeral.of(chapter.number))", at: CGPoint(x: leaf.left, y: leaf.y),
                        font: smallCaps(7.2), color: style.palette.accent, tracking: 2)
            leaf.y += 13
            let titleFont = UIFont.fbSerifItalic(ofSize: 18)
            let th = FieldText.height(chapter.title, font: titleFont, width: headWidth, justified: false)
            _ = FieldText.flow(chapter.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: headWidth, height: th + 4),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += th + 3
            var where_ = (chapter.isReport ? "The Academy's record, read " : "Read ") + dateFormatter.string(from: chapter.readAt)
            if let room = chapter.roomName { where_ += " · \(room)" }
            let names = chapter.castIDs.prefix(5).map { KeepMarginalia.voice(forSlug: $0)?.name ?? $0.split(separator: "-").map { $0.capitalized }.joined(separator: " ") }
            if !names.isEmpty { where_ += " · with " + ListFormatter.localizedString(byJoining: Array(names)) }
            let metaFont = UIFont.fbSerifItalic(ofSize: 8.6)
            let mh = FieldText.height(where_, font: metaFont, width: headWidth, lineSpacing: 0.5, paragraphSpacing: 0, justified: false)
            _ = FieldText.flow(where_, font: metaFont, color: ink.withAlphaComponent(0.58), in: CGRect(x: leaf.left, y: leaf.y, width: headWidth, height: mh + 3),
                               lineSpacing: 0.5, paragraphSpacing: 0, justified: false)
            leaf.y = max(leaf.y + mh + 10, headWidth < leaf.contentWidth ? headTop + 70 : 0)
            // The month's own illustration for this scene, when the pack drew one.
            if let scenePlate { drawInlinePlate(scenePlate, style: style, leaf: &leaf, maxHeight: 230, fresh: nextTaleLeaf) }

            var capped = true
            var lastTitle = chapter.title
            for part in chapter.parts {
                if part.title != lastTitle, !part.title.isEmpty {
                    // A scene's later part keeps its own small heading.
                    if leaf.bottom - leaf.y < 70 { fresh() }
                    let partFont = UIFont.fbSerifItalic(ofSize: 12)
                    (part.title as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y), withAttributes: [.font: partFont, .foregroundColor: ink.withAlphaComponent(0.85)])
                    leaf.y += partFont.lineHeight + 4
                    lastTitle = part.title
                }
                var rest = FieldMarked(parsing: part.body).markingHands(readerSentences)
                var passes = 0
                while !rest.isEmpty, passes < 40 {
                    passes += 1
                    if leaf.bottom - leaf.y < 50 { fresh() }
                    let flow = FieldText.flow(rest, font: bodyFont, color: ink.withAlphaComponent(0.92),
                                              in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y),
                                              dropCap: capped ? style.palette.accent : nil, lineSpacing: 2.2, paragraphSpacing: 5)
                    capped = false
                    guard flow.usedHeight > 0 else { fresh(); continue }
                    leaf.y += flow.usedHeight + 6
                    rest = flow.rest
                    if !rest.isEmpty { fresh() }
                }
                if let choice = part.choiceLabel, !part.isReport {
                    drawChoiceSlip(choice, style: style, leaf: &leaf, fresh: nextTaleLeaf,
                                   seed: "tale-choice-\(part.id)", color: readerInk)
                }
            }
            // Between chapters, a small ornament rather than a new leaf.
            if leaf.bottom - leaf.y > 60 {
                let mid = CGPoint(x: leaf.left + leaf.contentWidth / 2, y: leaf.y + 8)
                ("⁂" as NSString).draw(at: CGPoint(x: mid.x - 6, y: mid.y - 6),
                                       withAttributes: [.font: UIFont.fbSerif(ofSize: 11, weight: .regular), .foregroundColor: style.palette.gold])
                leaf.y += 30
            }
        }
        let remaining = leaf.bottom - leaf.y
        if remaining > 90 {
            drawBotanical(month: monthNumber, seed: "tale-end",
                          in: CGRect(x: leaf.left + (leaf.contentWidth - 120) / 2, y: leaf.bottom - min(remaining, 150), width: 120, height: min(remaining, 150)),
                          alignRight: false, rotation: 0.04)
        }
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
    /// The Tale of Your Week: a saddle-stitched storybook of one week. A title
    /// leaf, the chapters listed, a chapter for each day that held anything
    /// (the night's telling, the reader's own entries in their hand, the scene
    /// they read, the Cast, then the day's field notes), and The End. The page
    /// count is the week's own, rounded up to the signature of four with
    /// warranted leaves (a page to write the next chapter, one of the Cast, the
    /// week's map), never ruled filler. Returns 0 when the week will not fit
    /// the press's 48 pages, so the caller can fall back to the earlier form.
    static func writeWeeklyFieldBookInterior(
        _ matter: WeeklyPublicationMatter,
        book: BoundDayBook,
        dedication: BoundDedication?,
        spec: PrintSpec,
        style: EditionStyle,
        to url: URL
    ) throws -> Int {
        // A leaf added can move a run-on or a recto-only leaf, so the count is
        // found by trying: the fewest warranted leaves that land on the signature.
        let maximum = WeeklyPrintEditorialPolicy.technicalMaximumPages
        for extras in 0...weeklyExtraLeafLimit {
            let count = try weeklyTalePass(matter, book: book, dedication: dedication, spec: spec, style: style, extras: extras, to: url)
            guard count > 0, count <= maximum else { return 0 }
            if count == PrintGeometry.boundPageCount(rawPages: count, spec: spec) { return count }
        }
        return 0
    }

    /// The most warranted leaves a week may add: the next chapter, two of the
    /// Cast, the week's map, and room for a recto-only leaf to settle.
    static let weeklyExtraLeafLimit = 6

    /// One render of the Tale. `extras` is how many warranted leaves to add
    /// before The End, so the issue lands on its signature of four.
    private static func weeklyTalePass(
        _ matter: WeeklyPublicationMatter,
        book: BoundDayBook,
        dedication: BoundDedication?,
        spec: PrintSpec,
        style: EditionStyle,
        extras: Int,
        to url: URL
    ) throws -> Int {
        let issue = matter.issue
        MarginaliaDealer.reset()
        NotePromptDealer.reset()
        askedInThisBook = []
        dayFootCount = 0
        lastDropCapLetter = nil
        let fullBleed = PrintGeometry.fullBleedTrimInches(spec: spec)
        let pageBounds = CGRect(x: 0, y: 0, width: fullBleed.width * PrintSpec.pointsPerInch, height: fullBleed.height * PrintSpec.pointsPerInch)
        let m = spec.interiorMarginsPoints
        let margins = UIEdgeInsets(top: m.top, left: max(m.left, 50), bottom: m.bottom, right: max(m.right, 50))
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let calendar = Calendar.current
        let monthNumber = calendar.component(.month, from: issue.startDate)
        let ink = style.palette.ink
        let lastDay = calendar.date(byAdding: .day, value: -1, to: issue.endDate) ?? issue.endDate
        let chapters = WeeklyTaleBuilder.chapters(of: book, from: issue.startDate, to: issue.endDate.addingTimeInterval(-1), calendar: calendar)
        guard !chapters.isEmpty else { return 0 }
        let reader = matter.coverReaderName
        let headLeft = "The Tale of Your Week"
        let reading = WeeklyTaleReading(issue: issue, calendar: calendar)

        try renderer.writePDF(to: url) { context in
            var cursor = PDFCursor(bounds: pageBounds, margins: margins)
            cursor.seed = "weekly-tale-\(issue.number)"
            cursor.addressSeed = matter.bindingID

            // The title leaf.
            beginComposedPage(context, style: style, cursor: &cursor)
            let b = cursor.bounds
            drawTracked("The Tale of Your Week", at: CGPoint(x: 0, y: b.height * 0.14), font: smallCaps(8), color: ink.withAlphaComponent(0.6),
                        tracking: 3, width: b.width, alignment: .center)
            drawTracked("Issue No. \(issue.number)", at: CGPoint(x: 0, y: b.height * 0.14 + 18), font: smallCaps(7.4),
                        color: style.palette.accent, tracking: 2.4, width: b.width, alignment: .center)
            let titleFont = UIFont.fbSerif(ofSize: 30, weight: .bold)
            let titleWidth = b.width - 110
            let title = issue.resolvedEditorialTitle
            let titleHeight = FieldText.height(title, font: titleFont, width: titleWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineSpacing = 2
            (title as NSString).draw(in: CGRect(x: 55, y: b.height * 0.26, width: titleWidth, height: titleHeight + 6),
                                     withAttributes: [.font: titleFont, .foregroundColor: ink, .paragraphStyle: paragraph])
            var y = b.height * 0.26 + titleHeight + 18
            drawOrnamentRow(style, centerY: y, in: b, color: style.palette.gold)
            y += 22
            let subtitle = "Being a true account of \(reader)’s week, \(issue.dateRange), as it was kept by the Book, in \(chapters.count) \(chapters.count == 1 ? "chapter" : "chapters")."
            let subFont = UIFont.fbSerifItalic(ofSize: 11.4)
            let subHeight = FieldText.height(subtitle, font: subFont, width: titleWidth - 20, lineSpacing: 3, paragraphSpacing: 0, justified: false)
            paragraph.lineSpacing = 3
            (subtitle as NSString).draw(in: CGRect(x: 65, y: y, width: titleWidth - 20, height: subHeight + 6),
                                        withAttributes: [.font: subFont, .foregroundColor: ink.withAlphaComponent(0.75), .paragraphStyle: paragraph])
            drawBotanical(month: monthNumber, seed: "weekly-title-\(issue.number)",
                          in: CGRect(x: b.width / 2 - 75, y: b.height - 210, width: 150, height: 165), alignRight: false, rotation: 0)

            if dedication != nil {
                drawDedication(dedication, style: style, context: context, cursor: &cursor)
            }

            // The chapters, listed, and who was about.
            var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: issue.dateRange)
            leaf.y += 6
            // The week's seven moons, each marked where the week held a chapter.
            let cell = leaf.contentWidth / 7
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: issue.startDate)) else { continue }
                let moon = MoonPhaseCalendar.phase(on: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
                let cx = leaf.left + cell * (CGFloat(offset) + 0.5)
                FieldMoon.draw(center: CGPoint(x: cx, y: leaf.y + 9), radius: 7.5, illuminated: moon.illuminatedFraction,
                               waxing: moon.ageDays < MoonPhaseCalendar.synodicMonthDays / 2, ink: ink)
                if chapters.contains(where: { calendar.isDate($0.day.date, inSameDayAs: date) }) {
                    style.palette.accent.setFill()
                    UIBezierPath(ovalIn: CGRect(x: cx - 2.2, y: leaf.y + 22, width: 4.4, height: 4.4)).fill()
                }
                drawTracked(weekdayFormatter.string(from: date).prefix(3).description, at: CGPoint(x: cx - 12, y: leaf.y + 30),
                            font: smallCaps(5.8, weight: .semibold), color: ink.withAlphaComponent(0.6),
                            tracking: 0.8, width: 24, alignment: .center)
            }
            leaf.y += 50
            // The Book's opening, set at the head of the chapters rather than on
            // a page of its own: one short note, then the way in.
            let openingText = matter.editorialNote?.nonEmpty ?? reading.note(at: .opening)
            let openingFont = UIFont.fbSerifItalic(ofSize: 11.2)
            var opening = FieldMarked(parsing: openingText)
            var openingPasses = 0
            while !opening.isEmpty, openingPasses < 4 {
                openingPasses += 1
                let flow = FieldText.flow(opening, font: openingFont, color: ink.withAlphaComponent(0.85),
                                          in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 40),
                                          lineSpacing: 2.6, paragraphSpacing: 7, justified: false)
                guard flow.usedHeight > 0 else { break }
                leaf.y += flow.usedHeight
                opening = flow.rest
                if !opening.isEmpty {
                    leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: issue.dateRange)
                }
            }
            leaf.y += 14
            let openingRule = UIBezierPath()
            openingRule.move(to: CGPoint(x: leaf.left, y: leaf.y)); openingRule.addLine(to: CGPoint(x: leaf.left + 60, y: leaf.y))
            style.palette.gold.setStroke(); openingRule.lineWidth = 0.8; openingRule.stroke()
            leaf.y += 14
            drawEyebrow("The chapters", style: style, leaf: &leaf)
            leaf.y += 4
            let dayFormatter = DateFormatter()
            dayFormatter.calendar = calendar
            dayFormatter.setLocalizedDateFormatFromTemplate("EEEE d")
            for chapter in chapters {
                let label = "Chapter \(WeeklyTaleBuilder.ordinal(chapter.number).capitalized) · \(dayFormatter.string(from: chapter.day.date))"
                let font = UIFont.fbSerifItalic(ofSize: 12.4)
                let h = FieldText.height(chapter.heading, font: font, width: leaf.contentWidth, lineSpacing: 1, paragraphSpacing: 0, justified: false)
                if leaf.y + 11 + h + 15 > leaf.bottom {
                    leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: issue.dateRange)
                    drawEyebrow("The chapters, continued", style: style, leaf: &leaf)
                    leaf.y += 4
                }
                drawTracked(label, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.6), color: style.palette.accent, tracking: 1.2)
                leaf.y += 11
                _ = FieldText.flow(chapter.heading, font: font, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: h + 3),
                                   lineSpacing: 1, paragraphSpacing: 0, justified: false)
                leaf.y += h + 12
            }
            var names: [(name: String, asset: String?)] = []
            var seenCast = Set<String>()
            for slug in chapters.flatMap({ $0.day.scenes.flatMap(\.castIDs) + $0.day.castLines.map(\.speakerID) }) where seenCast.insert(slug).inserted {
                names.append((KeepMarginalia.voice(forSlug: slug)?.name ?? slug.split(separator: "-").map { $0.capitalized }.joined(separator: " "),
                              CastMarginalia.plateAssetName(forSlug: slug)))
            }
            if !names.isEmpty, leaf.bottom - leaf.y > 90 {
                leaf.y += 6
                drawCastStrip(Array(names.prefix(6)), style: style, leaf: &leaf)
            }
            let left = leaf.bottom - leaf.y
            if left > 100 {
                drawBotanical(month: monthNumber, seed: "weekly-contents-\(issue.number)",
                              in: CGRect(x: leaf.right - 130, y: leaf.bottom - min(left, 170), width: 130, height: min(left, 170)),
                              alignRight: true, rotation: -0.05)
            }

            // Who was about this week, most first: the Cast plates a short week may carry.
            var castOfWeek: [BoundCastPresence] = []
            var counted: [String: Int] = [:]
            for slug in chapters.flatMap({ $0.day.scenes.flatMap(\.castIDs) }) { counted[slug, default: 0] += 1 }
            for (slug, scenes) in counted.sorted(by: { ($0.value, $1.key) > ($1.value, $0.key) }) {
                guard let asset = CastMarginalia.plateAssetName(forSlug: slug), UIImage(named: asset) != nil else { continue }
                let pretty = slug.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
                castOfWeek.append(BoundCastPresence(slug: slug, name: KeepMarginalia.voice(forSlug: slug)?.name ?? pretty,
                                                    plateAssetName: asset, daysPresent: 0, sceneCount: scenes, actCount: 0, rooms: []))
            }
            // Warranted leaves, in this order: the next chapter to write, the Cast
            // who were about, then a plate facing a chapter's opening, the way a
            // storybook has, then the week's map, a page of notes, a margin plate.
            let castLeaves = min(2, castOfWeek.count)
            let connectionLeaves = (matter.connections ?? []).isEmpty ? 0 : 1
            let chapterPlates = min(chapters.count, max(0, extras - 1 - connectionLeaves - castLeaves))

            // The chapters themselves. The week's game slips in after the first
            // chapter that ends on a left-hand page, so it opens on a right-hand
            // page with no spacer leaf; only if none does is it set at the end.
            var playLeaves = issue.playLeaves ?? []
            for chapter in chapters {
                if chapter.number <= chapterPlates {
                    drawChapterPlate(chapter, monthNumber: monthNumber, style: style, context: context, cursor: &cursor)
                }
                drawTaleChapter(chapter, monthNumber: monthNumber, calendar: calendar, style: style, context: context, cursor: &cursor)
                // Next page is right-hand when the count so far is even.
                let nextIsRecto = cursor.pageIndex % 2 == 0
                let fits = playLeaves.first.map { leaf -> Bool in
                    let footprint = leaf.definition.footprint
                    if footprint.hasBlankReverse { return nextIsRecto }
                    if footprint.isFacingSpread { return !nextIsRecto }
                    return true
                } ?? false
                if fits, chapter.number < chapters.count {
                    drawEditionPlayLeaves(playLeaves, style: style, context: context, cursor: &cursor)
                    playLeaves = []
                }
            }

            drawEditionPlayLeaves(playLeaves, style: style, context: context, cursor: &cursor)

            // Each warranted leaf at most once, in this order.
            enum TaleExtra { case nextChapter, connections, cast(BoundCastPresence, String), weekMap, fieldNotes, plate(Int) }
            var plan: [TaleExtra] = [.nextChapter]
            if !(matter.connections ?? []).isEmpty { plan.append(.connections) }
            for (index, person) in castOfWeek.prefix(2).enumerated() {
                plan.append(.cast(person, index == 0 ? "Who was about most this week" : "And who else"))
            }
            plan += [.weekMap, .fieldNotes] + (0..<weeklyExtraLeafLimit).map { TaleExtra.plate($0) }
            // The chapter plates were set facing their chapters; the rest go here.
            let atEnd = Array(plan.prefix(1 + connectionLeaves + castLeaves)) + Array(plan.dropFirst(1 + connectionLeaves + castLeaves))
            for extra in atEnd.prefix(max(0, extras - chapterPlates)) {
                switch extra {
                case .nextChapter:
                    drawNextChapterLeaf(number: chapters.count + 1, issue: issue, style: style, context: context, cursor: &cursor)
                case .connections:
                    drawConnections(matter.connections ?? [], span: "the week", style: style, singleLeaf: true,
                                    context: context, cursor: &cursor)
                case .cast(let person, let caption):
                    drawCastPlateLeaf(person, headLeft: headLeft, caption: caption, style: style, context: context, cursor: &cursor)
                case .weekMap:
                    let week = book.weeks.first ?? BoundWeek(index: 0, start: issue.startDate, end: lastDay, nightCount: book.braidCount, sceneTitles: [], strongestNight: nil)
                    drawWeekLeaf(week, book: book, monthNumber: monthNumber, calendar: calendar, style: style,
                                 window: (issue.startDate, lastDay), eyebrow: "Where the week went", context: context, cursor: &cursor)
                case .fieldNotes:
                    let notesLeaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "Field notes")
                    drawNotesBlock("For whatever happened after the Book closed.",
                                   in: CGRect(x: notesLeaf.left, y: notesLeaf.y + 10, width: notesLeaf.contentWidth, height: notesLeaf.bottom - notesLeaf.y - 14),
                                   style: style)
                case .plate(let index):
                    context.beginPage()
                    cursor.reset()
                    cursor.pageIndex += 1
                    drawSpacerPlate(style: style, bounds: cursor.bounds, seed: "\(cursor.pageSeed)-tale-\(index)")
                    drawFolioMark(number: cursor.pageIndex, seed: cursor.addressSeed ?? cursor.seed, bounds: cursor.bounds, ink: style.palette.ink)
                }
            }

            // The End.
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "The End")
            leaf.y += 40
            let closing = matter.closingNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? reading.note(at: .closing)
            var ending = FieldMarked(parsing: closing)
            while !ending.isEmpty {
                if leaf.bottom - leaf.y < 45 {
                    leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "The End · continued")
                }
                let flow = FieldText.flow(ending, font: .fbSerifItalic(ofSize: 12), color: ink.withAlphaComponent(0.9),
                                          in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 24),
                                          lineSpacing: 3, paragraphSpacing: 10, justified: false)
                guard flow.usedHeight > 0 else { break }
                leaf.y += flow.usedHeight
                ending = flow.rest
                if !ending.isEmpty {
                    leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "The End · continued")
                }
            }
            leaf.y += 24
            if leaf.bottom - leaf.y < 150 {
                leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "The End")
                leaf.y += 20
            }
            let endFont = UIFont.fbSerifItalic(ofSize: 34)
            let end = "The End" as NSString
            let endWidth = end.size(withAttributes: [.font: endFont]).width
            end.draw(at: CGPoint(x: leaf.left + (leaf.contentWidth - endWidth) / 2, y: leaf.y), withAttributes: [.font: endFont, .foregroundColor: ink])
            leaf.y += endFont.lineHeight + 2
            drawTracked("of this week", at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7), color: style.palette.accent, tracking: 2,
                        width: leaf.contentWidth, alignment: .center)
            leaf.y += 26
            let nights = book.braidCount, scenes = book.scenes.count
            let words = book.days.reduce(0) { $0 + $1.readerWordCount }
            var tally: [String] = []
            if nights > 0 { tally.append("\(nights) \(nights == 1 ? "night" : "nights") braided") }
            if scenes > 0 { tally.append("\(scenes) \(scenes == 1 ? "scene" : "scenes") read") }
            if words > 0 { tally.append("\(words) of your own words") }
            let tallyText = tally.joined(separator: " · ")
            let tallyFont = smallCaps(6.6)
            let tallyParagraph = NSMutableParagraphStyle(); tallyParagraph.alignment = .center
            let tallyHeight = FieldText.height(tallyText, font: tallyFont, width: leaf.contentWidth, justified: false)
            (tallyText as NSString).draw(in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: tallyHeight + 4),
                                      withAttributes: [.font: tallyFont, .foregroundColor: ink.withAlphaComponent(0.6), .paragraphStyle: tallyParagraph])
            leaf.y += tallyHeight + 4
            drawBotanical(month: monthNumber, seed: "weekly-close-\(issue.number)",
                          in: CGRect(x: leaf.left, y: leaf.y + 24, width: leaf.contentWidth, height: max(0, min(170, leaf.bottom - leaf.y - 65))),
                          alignRight: false, rotation: 0.04)
            let monthName = monthFormatter.string(from: issue.startDate)
            let colophon = "The Tale of Your Week · Issue No. \(issue.number) · Every week of \(monthName) is gathered in \(monthName)’s book · Made with ReEnchanted" as NSString
            let colophonFont = UIFont.fbSerifItalic(ofSize: 7.6)
            let attrs: [NSAttributedString.Key: Any] = [.font: colophonFont, .foregroundColor: ink.withAlphaComponent(0.5), .paragraphStyle: tallyParagraph]
            let colophonHeight = FieldText.height(colophon as String, font: colophonFont, width: leaf.contentWidth, justified: false)
            colophon.draw(in: CGRect(x: leaf.left, y: leaf.bottom - colophonHeight, width: leaf.contentWidth, height: colophonHeight + 2), withAttributes: attrs)
        }

        guard let document = PDFDocument(url: url) else { return 0 }
        return document.pageCount
    }

    /// A day as a chapter: its heading, the storybook first line, the night's
    /// telling, what the reader wrote in their own hand, the Labyrinth that
    /// day, the Cast, and the field notes (photographs, keeps, the sky).
    private static func drawTaleChapter(
        _ chapter: WeeklyTaleChapter,
        monthNumber: Int,
        calendar: Calendar,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let day = chapter.day
        let headLeft = "The Tale of Your Week"
        let dateLine = "\(weekdayFormatter.string(from: day.date)) \(calendar.component(.day, from: day.date)) \(monthFormatter.string(from: day.date))"
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: dateLine)
        func continuationLeaf() -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
        }

        leaf.y += 6
        // A small drawing at the chapter's head, as a storybook has.
        let headTop = leaf.y
        var headWidth = leaf.contentWidth
        if let vignette = MarginaliaDealer.next(month: monthNumber) {
            let side: CGFloat = 78
            let scale = min(side / vignette.size.width, side / vignette.size.height)
            let size = CGSize(width: vignette.size.width * scale, height: vignette.size.height * scale)
            vignette.draw(in: CGRect(x: leaf.right - size.width, y: headTop - 4, width: size.width, height: size.height))
            headWidth -= side + 10
        }
        drawTracked("Chapter \(WeeklyTaleBuilder.ordinal(chapter.number))", at: CGPoint(x: leaf.left, y: leaf.y),
                    font: smallCaps(7.4), color: style.palette.accent, tracking: 2.2)
        leaf.y += 15
        let headFont = UIFont.fbSerifItalic(ofSize: 18)
        let hh = FieldText.height(chapter.heading, font: headFont, width: headWidth, lineSpacing: 1, paragraphSpacing: 0, justified: false)
        _ = FieldText.flow(chapter.heading, font: headFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: headWidth, height: hh + 4),
                           lineSpacing: 1, paragraphSpacing: 0, justified: false)
        leaf.y = max(leaf.y + hh + 8, headTop + 74)
        let ruleY = leaf.y
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: leaf.left, y: ruleY)); rule.addLine(to: CGPoint(x: leaf.left + 60, y: ruleY))
        style.palette.gold.setStroke(); rule.lineWidth = 0.8; rule.stroke()
        leaf.y += 12

        if let note = chapter.returnNote {
            let font = UIFont.fbSerifItalic(ofSize: 10.4)
            let height = FieldText.height(note, font: font, width: leaf.contentWidth, justified: false)
            _ = FieldText.flow(note, font: font, color: style.palette.accent,
                               in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: height + 4),
                               justified: false)
            leaf.y += height + 12
        }

        // The storybook first line, then the night as the Book told it.
        let openerFont = UIFont.fbSerifItalic(ofSize: 11.6)
        let opened = FieldText.flow(FieldMarked(text: chapter.opener), font: openerFont, color: ink.withAlphaComponent(0.9),
                                    in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y),
                                    dropCap: style.palette.accent, lineSpacing: 2.6, paragraphSpacing: 0, justified: false)
        leaf.y += opened.usedHeight + 10
        var bookThread: String?
        if let fullTelling = chapter.telling {
            let parts = braidParts(fullTelling)
            bookThread = parts.thread
            let telling = parts.telling
            // Where the telling quotes the reader, their words are in their hand.
            var rest = FieldMarked(parsing: telling).markingHands(entrySentences(day.entries))
            var passes = 0
            while !rest.isEmpty, passes < 12 {
                passes += 1
                if leaf.bottom - leaf.y < 60 { leaf = continuationLeaf() }
                let flow = FieldText.flow(rest, font: .fbSerif(ofSize: 11, weight: .regular), color: ink.withAlphaComponent(0.92),
                                          in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y),
                                          lineSpacing: 2.6, paragraphSpacing: 6)
                guard flow.usedHeight > 0 else { leaf = continuationLeaf(); continue }
                leaf.y += flow.usedHeight + 8
                rest = flow.rest
                if !rest.isEmpty { leaf = continuationLeaf() }
            }
        }

        // The Book's own thread, night to night, set apart.
        if let thread = bookThread {
            let font = UIFont.fbSerifItalic(ofSize: 10)
            let text = "✦  " + thread
            let h = FieldText.height(text, font: font, width: leaf.contentWidth - 30, lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
            if leaf.bottom - leaf.y < h + 12 { leaf = continuationLeaf() }
            _ = FieldText.flow(text, font: font, color: style.palette.accent.withAlphaComponent(0.9),
                               in: CGRect(x: leaf.left + 15, y: leaf.y, width: leaf.contentWidth - 30, height: h + 3),
                               lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
            leaf.y += h + 12
        }

        // What the reader wrote that day, in their own hand: whatever the
        // telling above didn't already carry.
        let uncarried = entriesNotCarried(day.entries, by: chapter.telling)
        if !uncarried.isEmpty {
            if leaf.bottom - leaf.y < 90 { leaf = continuationLeaf() }
            // The same join every chapter reads like a form; the Book says it differently each day.
            let intros = day.braids.isEmpty
                ? ["You wrote it down yourself:", "This is in your own hand:", "You kept this one yourself:", "Here's what you wrote:"]
                : ["And you wrote, in your own hand:", "And this is what you put down:", "You wrote some of it yourself:", "And in your own words:"]
            let intro = intros[(chapter.number - 1) % intros.count]
            (intro as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y), withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10.6), .foregroundColor: ink.withAlphaComponent(0.8)])
            leaf.y += 18
            for entry in uncarried {
                drawOwnHand(entry.text, note: [entry.clock, askedOnce(entry.asked).map { "the Page asked, “\($0)”" }].compactMap { $0 }.joined(separator: " · "),
                            style: style, leaf: &leaf, indent: 8, fresh: continuationLeaf)
                leaf.y += 6
            }
        }

        // Meanwhile, the Labyrinth: the scene, whole, and the choice they made there.
        if let firstScene = day.scenes.first {
            // "Meanwhile" stays with the scene it opens, and with that scene's plate.
            let plate = EditionPlates.scene(firstScene.contentID, month: Calendar.current.component(.month, from: firstScene.readAt))
            if leaf.bottom - leaf.y < 160 + (plate.map { plateHeight($0, width: leaf.contentWidth, maxHeight: 200) } ?? 0) { leaf = continuationLeaf() }
            ("Meanwhile, in the Labyrinth…" as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y + 2),
                                                             withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10.6), .foregroundColor: ink.withAlphaComponent(0.8)])
            leaf.y += 20
            // A week has no Tale at the back: the scene is told whole, here, where it was read.
            drawScenesWhole(day.scenes, readerSentences: day.entries.map(\.text), style: style, leaf: &leaf, fresh: continuationLeaf)
        }

        // The Cast, in the margins.
        for line in day.castLines {
            let text = "\(line.speakerName): “\(line.line)”"
            let width = min(leaf.contentWidth, 260)
            let height = slipHeight(text, width: width, fontSize: 10.8)
            if leaf.y + height + 10 > leaf.bottom { leaf = continuationLeaf() }
            drawHandSlip(text, style: style, in: CGRect(x: leaf.left + 4, y: leaf.y, width: width, height: height),
                         rotation: frac("tale-line-\(line.id)") > 0.5 ? 0.025 : -0.025, seed: "tale-line-\(line.id)", fontSize: 10.8)
            leaf.y += height + 12
        }

        // The colophon of the night closes the chapter.
        if let kept = chapter.keptLine {
            if leaf.bottom - leaf.y < 40 { leaf = continuationLeaf() }
            let font = UIFont.fbSerifItalic(ofSize: 10.4)
            let h = FieldText.height(kept, font: font, width: leaf.contentWidth - 40, lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
            let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 1.5
            (kept as NSString).draw(in: CGRect(x: leaf.left + 20, y: leaf.y + 2, width: leaf.contentWidth - 40, height: h + 4),
                                    withAttributes: [.font: font, .foregroundColor: style.palette.accent, .paragraphStyle: para])
            leaf.y += h + 16
        }

        // The day's field notes: everything else it kept, on the same leaf.
        var notes = day
        notes.braids = []
        notes.entries = []
        notes.scenes = []
        notes.castLines = []
        notes.words = []
        notes.keeps = keepsNotCarried(day.keeps, by: chapter.telling)
        // Only what the day kept turns a leaf. The sky and a place to write
        // sit in the room the chapter leaves, never on a leaf of their own.
        notes.scrapbook = day.scrapbook.filter { !$0.fullPage }
        let hasKeeps = !notes.keeps.isEmpty || !notes.photos.isEmpty || !notes.marks.isEmpty || !notes.specimens.isEmpty || !notes.scrapbook.isEmpty
        if hasKeeps || leaf.bottom - leaf.y > 150 {
            drawYourSide(notes, monthNumber: monthNumber, calendar: calendar, style: style,
                         continuing: leaf, context: context, cursor: &cursor)
        } else if leaf.bottom - leaf.y > 90 {
            drawBotanical(month: monthNumber, seed: day.id + "-tale",
                          in: CGRect(x: leaf.right - 120, y: leaf.bottom - min(leaf.bottom - leaf.y, 140), width: 120, height: min(leaf.bottom - leaf.y, 140)),
                          alignRight: true, rotation: -0.06)
        }
        // The page the reader made that day, whole, closing the chapter.
        for page in day.scrapbook where page.fullPage {
            drawScrapbookLeaf(page, headLeft: headLeft, dateLine: dateLine, style: style, context: context, cursor: &cursor)
        }
    }

    /// Scenes set whole on the running leaf: the place, the title, the text as
    /// read with a drop cap, and the reader's choice where they made it.
    static func drawScenesWhole(
        _ scenes: [BoundDayScene],
        readerSentences: [String],
        style: EditionStyle,
        leaf: inout PDFCursor,
        fresh: () -> PDFCursor
    ) {
        let ink = style.palette.ink
        let bodyFont = UIFont.fbSerif(ofSize: 10.4, weight: .regular)
        var lastContentID: String?
        for scene in scenes {
            let continuing = scene.contentID == lastContentID
            lastContentID = scene.contentID
            let plate = continuing ? nil : EditionPlates.scene(scene.contentID, month: Calendar.current.component(.month, from: scene.readAt))
            if leaf.bottom - leaf.y < 110 + (plate.map { plateHeight($0, width: leaf.contentWidth, maxHeight: 200) } ?? 0) { leaf = fresh() }
            if !continuing {
                let place = scene.isReport
                    ? (scene.roomName.map { "The Academy's record · \($0)" } ?? "The Academy's record")
                    : (scene.roomName.map { "In the Labyrinth · \($0)" } ?? "In the Labyrinth")
                drawEyebrow(place, style: style, leaf: &leaf)
            }
            let titleFont = continuing ? UIFont.fbSerifItalic(ofSize: 13) : UIFont.fbSerifItalic(ofSize: 17)
            if !continuing || !scene.title.isEmpty {
                let th = FieldText.height(scene.title, font: titleFont, width: leaf.contentWidth, justified: false)
                _ = FieldText.flow(scene.title, font: titleFont, color: ink, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: th + 4),
                                   lineSpacing: 0, paragraphSpacing: 0, justified: false)
                leaf.y += th + 6
            }
            if let plate {
                drawInlinePlate(plate, style: style, leaf: &leaf, maxHeight: 200, fresh: fresh)
            }
            var rest = FieldMarked(parsing: scene.body).markingHands(readerSentences)
            var capped = !continuing
            var passes = 0
            while !rest.isEmpty, passes < 30 {
                passes += 1
                if leaf.bottom - leaf.y < 50 { leaf = fresh() }
                let flow = FieldText.flow(rest, font: bodyFont, color: ink.withAlphaComponent(0.92),
                                          in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y),
                                          dropCap: capped ? style.palette.accent : nil, lineSpacing: 2.2, paragraphSpacing: 5)
                capped = false
                guard flow.usedHeight > 0 else { leaf = fresh(); continue }
                leaf.y += flow.usedHeight + 6
                rest = flow.rest
                if !rest.isEmpty { leaf = fresh() }
            }
            if let choice = scene.choiceLabel, !scene.isReport {
                drawChoiceSlip(choice, style: style, leaf: &leaf, fresh: fresh,
                               seed: "scene-choice-\(scene.id)", color: readerInk)
            }
            if !scene.isReport {
                drawStoryMark(month: Calendar.current.component(.month, from: scene.readAt), style: style, leaf: &leaf)
            }
        }
    }

    /// A storybook plate facing a chapter's opening: one of the month's
    /// drawings, large, in a gold frame, captioned with the chapter's title.
    private static func drawChapterPlate(_ chapter: WeeklyTaleChapter, monthNumber: Int, style: EditionStyle,
                                         context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Tale of Your Week", headRight: "A plate")
        let ink = style.palette.ink
        // The month's own illustration first: the scene read that day, then one
        // of the month's plates; the Book's marginalia only when it has none.
        let general = EditionPlates.general(month: monthNumber)
        let monthPlate = chapter.day.scenes.first.flatMap { EditionPlates.scene($0.contentID, month: monthNumber) }
            ?? (general.isEmpty ? nil : general[(chapter.number - 1) % general.count])
        guard let art = monthPlate ?? MarginaliaDealer.next(month: monthNumber) else { return }
        let box = CGRect(x: leaf.left + 18, y: leaf.y + 30, width: leaf.contentWidth - 36, height: (leaf.bottom - leaf.y) * 0.62)
        let scale = min(box.width / art.size.width, box.height / art.size.height)
        let size = CGSize(width: art.size.width * scale, height: art.size.height * scale)
        let frame = CGRect(x: box.midX - size.width / 2, y: box.minY + (box.height - size.height) / 2, width: size.width, height: size.height)
        let mat = frame.insetBy(dx: -22, dy: -22)
        UIColor(red: 0.995, green: 0.985, blue: 0.955, alpha: 0.6).setFill()
        UIBezierPath(rect: mat).fill()
        style.palette.gold.setStroke()
        let outer = UIBezierPath(rect: mat); outer.lineWidth = 1.1; outer.stroke()
        let inner = UIBezierPath(rect: mat.insetBy(dx: 4, dy: 4)); inner.lineWidth = 0.5; inner.stroke()
        art.draw(in: frame)
        leaf.y = mat.maxY + 22
        drawTracked("Chapter \(WeeklyTaleBuilder.ordinal(chapter.number))", at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7), color: style.palette.accent,
                    tracking: 2, width: leaf.contentWidth, alignment: .center)
        leaf.y += 14
        let font = UIFont.fbSerifItalic(ofSize: 13)
        let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 2
        let h = FieldText.height(chapter.heading, font: font, width: leaf.contentWidth - 40, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        (chapter.heading as NSString).draw(in: CGRect(x: leaf.left + 20, y: leaf.y, width: leaf.contentWidth - 40, height: h + 6),
                                           withAttributes: [.font: font, .foregroundColor: ink.withAlphaComponent(0.85), .paragraphStyle: para])
    }

    /// A warranted leaf: the next chapter, for the reader to write.
    private static func drawNextChapterLeaf(number: Int, issue: WeeklyIssue, style: EditionStyle,
                                            context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Tale of Your Week", headRight: "To be continued")
        leaf.y += 6
        drawTracked("Chapter \(WeeklyTaleBuilder.ordinal(number))", at: CGPoint(x: leaf.left, y: leaf.y),
                    font: smallCaps(7.4), color: style.palette.accent, tracking: 2.2)
        leaf.y += 15
        ("In which" as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y), withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 18), .foregroundColor: style.palette.ink])
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: leaf.left + 74, y: leaf.y + 19)); rule.addLine(to: CGPoint(x: leaf.right, y: leaf.y + 19))
        style.palette.ink.withAlphaComponent(0.35).setStroke(); rule.lineWidth = 0.6; rule.stroke()
        leaf.y += 32
        let ask = "This one is yours to write. Put down the next thing that happens, in your own hand, and show me when you're done. I want to read it."
        let font = UIFont.fbSerifItalic(ofSize: 10.6)
        let h = FieldText.height(ask, font: font, width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        _ = FieldText.flow(ask, font: font, color: style.palette.ink.withAlphaComponent(0.72), in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: h + 4),
                           lineSpacing: 2, paragraphSpacing: 0, justified: false)
        leaf.y += h + 14
        hbRules(from: leaf.y, to: leaf.bottom - 8, left: leaf.left, right: leaf.right, spacing: ownHandPitch + 4, style: style)
    }
}

// MARK: - The Ledger of Nights

extension MonthlyEditionPDFWriter {
    /// Every night of the year in a line. The nights printed in full are a
    /// sampling; this is the whole year, named.
    static func drawNightsLedger(
        _ lines: [BoundNightLine],
        year: Int,
        term: Bool = false,
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
        let intro = term
            ? "Every night of the term, in a line. Find the one you want here, then turn to its day in Part One."
            : "Every night of the year, in a line. The nights in this book are a sampling; the rest are named here, and every one is whole in your archive."
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
    /// A ruled index card, pinned to the page: cream stock, a red head rule,
    /// faint blue lines, a soft shadow. Clubs and enchantments add a gold frame.
    static func drawCardFrame(_ rect: CGRect, style: EditionStyle, double: Bool = false) {
        if let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0.6, height: 1.4), blur: 3, color: UIColor.black.withAlphaComponent(0.16).cgColor)
            UIColor(red: 0.995, green: 0.985, blue: 0.955, alpha: 0.92).setFill()
            UIBezierPath(rect: rect).fill()
            cg.restoreGState()
        }
        let lines = UIBezierPath()
        var y = rect.minY + 34
        while y < rect.maxY - 6 {
            lines.move(to: CGPoint(x: rect.minX + 6, y: y)); lines.addLine(to: CGPoint(x: rect.maxX - 6, y: y))
            y += 13
        }
        UIColor(red: 0.45, green: 0.6, blue: 0.8, alpha: 0.16).setStroke()
        lines.lineWidth = 0.4
        lines.stroke()
        let head = UIBezierPath()
        head.move(to: CGPoint(x: rect.minX, y: rect.minY + 24)); head.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 24))
        UIColor(red: 0.78, green: 0.32, blue: 0.3, alpha: 0.45).setStroke()
        head.lineWidth = 0.6
        head.stroke()
        style.palette.ink.withAlphaComponent(0.22).setStroke()
        let outline = UIBezierPath(rect: rect)
        outline.lineWidth = 0.4
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
        func freshLeaf() -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
        }

        for keep in keeps {
            defer {
                if let reply = keep.readerReply {
                    let lead: String
                    switch keep.kind {
                    case .letter: lead = "You wrote back"
                    case .castNote: lead = "Your answer"
                    case .classSession, .club: lead = "What you made of it"
                    case .quotation, .lore: lead = "Why you kept it"
                    case .enchantment: lead = "What you saw"
                    case .story, .plate: lead = "Your note in its margin"
                    }
                    drawOwnHand(reply, note: lead, style: style, leaf: &leaf, indent: 14, fresh: freshLeaf)
                    leaf.y += 10
                }
            }
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
                let text = "“" + excerpt(keep.body, limit: 260) + "”" + (keep.speakerName.map { "\n— \($0)" } ?? "")
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

// MARK: - The reader's own hand

extension MonthlyEditionPDFWriter {
    static let ownHandSize: CGFloat = 12.4
    static let ownHandLineSpacing: CGFloat = 5.2

    /// The height one line of the reader's hand takes, rule to rule.
    static var ownHandPitch: CGFloat { handFont(ownHandSize).lineHeight + ownHandLineSpacing }

    /// The reader's writing, set in a hand on ruled lines and allowed to run
    /// on to further leaves: it is the one thing on a page nobody else wrote.
    /// `note` is a small line above it saying where it was written.
    static func drawOwnHand(
        _ text: String,
        note: String?,
        style: EditionStyle,
        leaf: inout PDFCursor,
        indent: CGFloat = 0,
        fresh: () -> PDFCursor
    ) {
        let font = handFont(ownHandSize)
        let ink = style.palette.ink
        let left = leaf.left + indent
        let width = leaf.contentWidth - indent
        if let note, !note.isEmpty {
            if leaf.bottom - leaf.y < 60 { leaf = fresh() }
            let noteFont = UIFont.fbSerifItalic(ofSize: 8.6)
            let h = FieldText.height(note, font: noteFont, width: width, lineSpacing: 0.5, paragraphSpacing: 0, justified: false)
            _ = FieldText.flow(note, font: noteFont, color: ink.withAlphaComponent(0.58),
                               in: CGRect(x: left, y: leaf.y, width: width, height: h + 3),
                               lineSpacing: 0.5, paragraphSpacing: 0, justified: false)
            leaf.y += h + 3
        }
        // The reader's own words are never parsed for markup: an asterisk is theirs.
        var rest = FieldMarked(text: text.replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines))
        var passes = 0
        while !rest.isEmpty, passes < 40 {
            passes += 1
            if leaf.bottom - leaf.y < ownHandPitch * 2 { leaf = fresh() }
            let rect = CGRect(x: left, y: leaf.y, width: width, height: leaf.bottom - leaf.y)
            let flow = FieldText.flow(rest, font: font, color: ownInk(style),
                                      in: rect, lineSpacing: ownHandLineSpacing, paragraphSpacing: 2, justified: false)
            guard flow.usedHeight > 0 else { leaf = fresh(); continue }
            drawRules(from: leaf.y, height: flow.usedHeight, left: left, width: width, font: font, style: style)
            leaf.y += flow.usedHeight + 6
            rest = flow.rest
            if !rest.isEmpty { leaf = fresh() }
        }
    }

    /// The ink the reader writes in: darker and bluer than the type, so their
    /// hand reads as ink on the page and not as more print.
    static let readerInk = UIColor(red: 0.13, green: 0.20, blue: 0.36, alpha: 0.94)
    static func ownInk(_ style: EditionStyle) -> UIColor { readerInk }

    /// Faint ruled lines under handwritten text, one per line of it.
    static func drawRules(from top: CGFloat, height: CGFloat, left: CGFloat, width: CGFloat, font: UIFont, style: EditionStyle) {
        let pitch = font.lineHeight + ownHandLineSpacing
        let rules = max(1, Int((height + ownHandLineSpacing) / pitch + 0.5))
        let path = UIBezierPath()
        for index in 0..<rules {
            let y = top + font.ascender + 3 + CGFloat(index) * pitch
            path.move(to: CGPoint(x: left - 2, y: y))
            path.addLine(to: CGPoint(x: left + width, y: y))
        }
        style.palette.ink.withAlphaComponent(0.13).setStroke()
        path.lineWidth = 0.45
        path.stroke()
    }

    /// The sentences of the reader's entries, for finding them in a telling.
    static func entrySentences(_ entries: [BoundDayEntry]) -> [String] {
        entries.flatMap { WonderBraid.sentences($0.text) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " .!?\n")) }
            .filter { $0.count >= 16 }
    }

    /// The entries a telling has not already carried word for word. One the
    /// night's telling quoted whole is printed there, in the reader's hand,
    /// and not a second time beneath it.
    static func entriesNotCarried(_ entries: [BoundDayEntry], by telling: String?) -> [BoundDayEntry] {
        guard let telling = telling?.lowercased(), !telling.isEmpty else { return entries }
        func carried(_ sentence: String) -> Bool {
            // The telling may say it back facing the reader: "I" became "you".
            let plain = sentence.trimmingCharacters(in: CharacterSet(charactersIn: " .!?\n")).lowercased()
            let faced = BraidSceneWriter.secondPerson(sentence).trimmingCharacters(in: CharacterSet(charactersIn: " .!?\n")).lowercased()
            return telling.contains(plain) || telling.contains(faced)
        }
        return entries.filter { entry in
            let long = WonderBraid.sentences(entry.text).filter { $0.trimmingCharacters(in: .whitespaces).count >= 16 }
            // Carried when every sentence of real length is in the telling.
            return long.isEmpty || !long.allSatisfy(carried)
        }
    }

    /// Keeps whose words the telling already says: a class card that repeats
    /// the night's sentence word for word is left out beneath it.
    static func keepsNotCarried(_ keeps: [BoundDayKeep], by telling: String?) -> [BoundDayKeep] {
        guard let telling = telling?.lowercased(), !telling.isEmpty else { return keeps }
        return keeps.filter { keep in
            guard keep.readerReply == nil, [.classSession, .club, .castNote, .lore].contains(keep.kind),
                  let first = WonderBraid.sentences(keep.body).first?
                    .trimmingCharacters(in: CharacterSet(charactersIn: " .!?\n")).lowercased(),
                  first.count >= 20 else { return true }
            return !telling.contains(first)
        }
    }

    /// The questions already printed above an answer in this book. A Page's
    /// question is printed the first time; after that the answer stands alone.
    static var askedInThisBook = Set<String>()

    static func askedOnce(_ asked: String?) -> String? {
        guard let asked else { return nil }
        return askedInThisBook.insert(asked.lowercased()).inserted ? asked : nil
    }

    /// The day's entries, each with a small note of where it was written and
    /// what the Page asked.
    static func drawEntries(_ entries: [BoundDayEntry], style: EditionStyle, leaf: inout PDFCursor, fresh: () -> PDFCursor) {
        guard !entries.isEmpty else { return }
        if leaf.bottom - leaf.y < 90 { leaf = fresh() }
        drawEyebrow(entries.count == 1 ? "In your own hand" : "In your own hand · \(entries.count) entries", style: style, leaf: &leaf)
        leaf.y += 2
        for entry in entries {
            var note = [entry.label, entry.clock].compactMap { $0?.nonEmpty }.joined(separator: " · ")
            if let asked = askedOnce(entry.asked) { note += note.isEmpty ? asked : " — the Page asked, “\(asked)”" }
            drawOwnHand(entry.text, note: note, style: style, leaf: &leaf, fresh: fresh)
            leaf.y += 6
        }
        leaf.y += 6
    }
}

// MARK: - Your account, written before binding

extension MonthlyEditionPDFWriter {
    static func drawBindingAccount(
        _ account: BindingAccount,
        edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let monthName = monthFormatter.string(from: edition.startDate)
        let answered = account.answered(monthName: monthName)
        guard !answered.isEmpty else { return }
        let ink = style.palette.ink
        let headLeft = "Your Account"
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: monthName)
        func continuationLeaf() -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(monthName) · continued")
        }
        leaf.y += 8
        let title = "Your Account of \(monthName)"
        let titleFont = UIFont.fbSerif(ofSize: 24, weight: .bold)
        (title as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y), withAttributes: [.font: titleFont, .foregroundColor: ink])
        leaf.y += titleFont.lineHeight + 4
        let dek = "Written at the press, before the Book bound the month. The questions are the Book's; the answers are yours."
        let dekFont = UIFont.fbSerifItalic(ofSize: 10.2)
        let dh = FieldText.height(dek, font: dekFont, width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        _ = FieldText.flow(dek, font: dekFont, color: ink.withAlphaComponent(0.68), in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: dh + 4),
                           lineSpacing: 2, paragraphSpacing: 0, justified: false)
        leaf.y += dh + 18
        for item in answered {
            if leaf.bottom - leaf.y < 90 { leaf = continuationLeaf() }
            let qFont = UIFont.fbSerifItalic(ofSize: 11.4)
            let qh = FieldText.height(item.question, font: qFont, width: leaf.contentWidth, lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
            _ = FieldText.flow(item.question, font: qFont, color: style.palette.accent, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: qh + 4),
                               lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
            leaf.y += qh + 6
            drawOwnHand(item.answer, note: nil, style: style, leaf: &leaf, indent: 10, fresh: continuationLeaf)
            leaf.y += 14
        }
        let remaining = leaf.bottom - leaf.y
        if remaining > 100 {
            drawBotanical(month: Calendar.current.component(.month, from: edition.startDate), seed: "account",
                          in: CGRect(x: leaf.right - 120, y: leaf.bottom - min(remaining, 150), width: 120, height: min(remaining, 150)),
                          alignRight: true, rotation: -0.05)
        }
    }
}

// MARK: - The reader's scrapbook pages

extension MonthlyEditionPDFWriter {
    /// A page the reader made in the Pagewright, tipped into the book whole:
    /// their layout at full size with photo corners at its four tips, its
    /// title, and their own note beneath it in their hand. Drawn from the kept
    /// PDF when there is one, so it prints as sharp as they made it.
    static func drawScrapbookLeaf(
        _ page: BoundScrapbookPage,
        headLeft: String,
        dateLine: String,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: dateLine)
        let ink = style.palette.ink
        let pdfPage: CGPDFPage? = page.pdf.flatMap { asset in
            CGPDFDocument(URL(fileURLWithPath: asset.reference) as CFURL)?.page(at: 1)
        }
        let picture = page.image.flatMap { UIImage(contentsOfFile: $0.reference) }
        let natural: CGSize
        if let pdfPage {
            natural = pdfPage.getBoxRect(.cropBox).size
        } else if let picture {
            natural = picture.size
        } else {
            return
        }
        let noteHeight: CGFloat = page.note.map { FieldText.height($0, font: handFont(ownHandSize), width: leaf.contentWidth - 20, lineSpacing: ownHandLineSpacing, paragraphSpacing: 2, justified: false) + 26 } ?? 0
        drawEyebrow("From your scrapbook", style: style, leaf: &leaf)
        let box = CGRect(x: leaf.left + 8, y: leaf.y + 10, width: leaf.contentWidth - 16,
                         height: max(160, leaf.bottom - leaf.y - 52 - min(noteHeight, 120)))
        let scale = min(box.width / natural.width, box.height / natural.height)
        let size = CGSize(width: natural.width * scale, height: natural.height * scale)
        let frame = CGRect(x: box.midX - size.width / 2, y: box.minY, width: size.width, height: size.height)
        if let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 1, height: 2.5), blur: 6, color: UIColor.black.withAlphaComponent(0.28).cgColor)
            UIColor.white.setFill()
            UIBezierPath(rect: frame).fill()
            cg.restoreGState()
            if let pdfPage {
                cg.saveGState()
                cg.translateBy(x: frame.minX, y: frame.maxY)
                cg.scaleBy(x: scale, y: -scale)
                let crop = pdfPage.getBoxRect(.cropBox)
                cg.translateBy(x: -crop.minX, y: -crop.minY)
                cg.drawPDFPage(pdfPage)
                cg.restoreGState()
            } else {
                picture?.draw(in: frame)
            }
            // Photo corners at the four tips: it was mounted, not printed over.
            let corner: CGFloat = 16
            UIColor(red: 0.22, green: 0.17, blue: 0.13, alpha: 0.85).setFill()
            for (x, y, dx, dy) in [(frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0),
                                   (frame.minX, frame.maxY, 1.0, -1.0), (frame.maxX, frame.maxY, -1.0, -1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x - 3 * dx, y: y - 3 * dy))
                path.addLine(to: CGPoint(x: x + corner * dx, y: y - 3 * dy))
                path.addLine(to: CGPoint(x: x - 3 * dx, y: y + corner * dy))
                path.close()
                path.fill()
            }
        }
        leaf.y = frame.maxY + 12
        let caption = [page.title, page.clock.map { "made at \($0)" }].compactMap { $0 }.joined(separator: " · ")
        let para = NSMutableParagraphStyle(); para.alignment = .center
        (caption as NSString).draw(in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 16),
                                   withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10), .foregroundColor: ink.withAlphaComponent(0.72), .paragraphStyle: para])
        leaf.y += 20
        if let note = page.note {
            drawOwnHand(note, note: nil, style: style, leaf: &leaf, indent: 10) {
                fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft, headRight: "\(dateLine) · continued")
            }
        }
    }
}

extension MonthlyEditionPDFWriter {
    /// Every scrapbook page that didn't print full size, smaller, six to a
    /// leaf, each with its title and day: nothing the reader made is left out.
    static func drawScrapbookGallery(
        _ pages: [(date: Date, page: BoundScrapbookPage)],
        headLeft: String,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !pages.isEmpty else { return }
        let ink = style.palette.ink
        let perLeaf = 6
        let dayFormatter = DateFormatter()
        dayFormatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        for start in stride(from: 0, to: pages.count, by: perLeaf) {
            var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: headLeft,
                                 headRight: start == 0 ? "More from your scrapbook" : "More from your scrapbook · continued")
            if start == 0 {
                drawEyebrow("More from your scrapbook", style: style, leaf: &leaf)
                let lead = "The pages you made in the Pagewright that didn't get a page to themselves. Every one is here."
                let font = UIFont.fbSerifItalic(ofSize: 10)
                let h = FieldText.height(lead, font: font, width: leaf.contentWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
                _ = FieldText.flow(lead, font: font, color: ink.withAlphaComponent(0.7), in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: h + 4),
                                   lineSpacing: 2, paragraphSpacing: 0, justified: false)
                leaf.y += h + 12
            }
            let slice = Array(pages[start..<min(pages.count, start + perLeaf)])
            let gap: CGFloat = 14
            let cellWidth = (leaf.contentWidth - gap) / 2
            let cellHeight = (leaf.bottom - leaf.y - gap * 2) / 3
            for (index, item) in slice.enumerated() {
                let cell = CGRect(x: leaf.left + CGFloat(index % 2) * (cellWidth + gap), y: leaf.y + CGFloat(index / 2) * (cellHeight + gap),
                                  width: cellWidth, height: cellHeight)
                let box = CGRect(x: cell.minX + 6, y: cell.minY + 4, width: cell.width - 12, height: cell.height - 30)
                let pdfPage = item.page.pdf.flatMap { CGPDFDocument(URL(fileURLWithPath: $0.reference) as CFURL)?.page(at: 1) }
                let picture = item.page.image.flatMap { UIImage(contentsOfFile: $0.reference) }
                let natural = pdfPage?.getBoxRect(.cropBox).size ?? picture?.size ?? .zero
                guard natural.width > 0, let cg = UIGraphicsGetCurrentContext() else { continue }
                let scale = min(box.width / natural.width, box.height / natural.height)
                let size = CGSize(width: natural.width * scale, height: natural.height * scale)
                let frame = CGRect(x: box.midX - size.width / 2, y: box.minY + (box.height - size.height) / 2, width: size.width, height: size.height)
                cg.saveGState()
                cg.translateBy(x: frame.midX, y: frame.midY)
                cg.rotate(by: (index % 3 == 1 ? 0.018 : -0.014))
                cg.translateBy(x: -frame.midX, y: -frame.midY)
                cg.setShadow(offset: CGSize(width: 0.8, height: 1.6), blur: 4, color: UIColor.black.withAlphaComponent(0.25).cgColor)
                UIColor.white.setFill(); UIBezierPath(rect: frame).fill()
                cg.setShadow(offset: .zero, blur: 0, color: nil)
                if let pdfPage {
                    cg.saveGState()
                    cg.translateBy(x: frame.minX, y: frame.maxY)
                    cg.scaleBy(x: scale, y: -scale)
                    let crop = pdfPage.getBoxRect(.cropBox)
                    cg.translateBy(x: -crop.minX, y: -crop.minY)
                    cg.drawPDFPage(pdfPage)
                    cg.restoreGState()
                } else {
                    picture?.draw(in: frame)
                }
                cg.restoreGState()
                let caption = "\(item.page.title) · \(dayFormatter.string(from: item.date))"
                let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineBreakMode = .byTruncatingTail
                (caption as NSString).draw(in: CGRect(x: cell.minX, y: cell.maxY - 22, width: cell.width, height: 14),
                                           withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.6), .foregroundColor: ink.withAlphaComponent(0.7), .paragraphStyle: para])
            }
        }
    }
}

extension MonthlyEditionPDFWriter {
    /// A scrapbook page as a picture: its kept image, or its PDF drawn small.
    static func scrapbookPicture(_ page: BoundScrapbookPage) -> UIImage? {
        if let image = page.image.flatMap({ UIImage(contentsOfFile: $0.reference) }) { return image }
        guard let asset = page.pdf, let document = PDFDocument(url: URL(fileURLWithPath: asset.reference)),
              let first = document.page(at: 0) else { return nil }
        let box = first.bounds(for: .cropBox)
        return first.thumbnail(of: CGSize(width: 600, height: 600 * box.height / max(1, box.width)), for: .cropBox)
    }
}

// MARK: - The month's own plates

/// Illustrations a monthly pack commissions for print, shipped as files named
/// by what they're for: `<pack>.plate.frontispiece`, `<pack>.plate.scene.<scene
/// id>`, `<pack>.plate.cast.<cast slug>`, or any other `<pack>.plate.<name>`
/// for the month at large. Named files, not pack fields, so an older app never
/// fails to install a month for not knowing them. A month without plates
/// prints with the Book's standing art.
enum EditionPlates {
    struct Plate {
        var slot: String
        var path: String
        var month: Int?
    }

    /// A folder of plates for proofs, read beside the installed ones.
    static var proofDirectory: URL?
    /// Set while the bindery measures what the plates add to a book (see `writePrintInterior`).
    static var suppressed = false

    static func all() -> [Plate] {
        guard !suppressed else { return [] }
        var found: [Plate] = []
        func scan(_ directory: URL?, requirePrefix: Bool) {
            guard let directory,
                  let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
            for url in files where ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) {
                let file = url.lastPathComponent
                if requirePrefix && !file.hasPrefix(MonthlyIssueDeliveryPolicy.managedFilePrefix) { continue }
                guard let marker = file.range(of: ".plate.") else { continue }
                let before = String(file[..<marker.lowerBound])
                var month: Int?
                if let range = before.range(of: "-\\d{4}-\\d{2}-", options: .regularExpression) {
                    month = Int(before[range].dropLast().suffix(2))
                }
                let slot = String(file[marker.upperBound...]).replacingOccurrences(of: "." + url.pathExtension, with: "")
                found.append(Plate(slot: slot, path: url.path, month: month))
            }
        }
        scan(MonthlyIssueDeliveryPolicy.managedContentDirectory(), requirePrefix: true)
        scan(proofDirectory, requirePrefix: false)
        return found
    }

    /// The best plate for a slot: this month's first, then any month's.
    private static func image(slot: String, month: Int?) -> UIImage? {
        let matches = all().filter { $0.slot == slot }
        let chosen = matches.first { $0.month == month } ?? matches.first { $0.month == nil } ?? matches.first
        return chosen.flatMap { load($0.path) }
    }

    /// Plates arrive at up to 2400 px; a page never needs more than 300 dpi across its widest plate.
    static let printPixels = 1800
    private static let loaded: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    /// A plate as JPEG bytes at print size, read once per book. Kept as JPEG on purpose: the PDF
    /// embeds those bytes as they are, where a decoded bitmap went in raw and tripled the file and
    /// the memory it took to write it.
    static func load(_ path: String) -> UIImage? {
        if let hit = loaded.object(forKey: path as NSString) { return hit }
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let longest = max(properties?[kCGImagePropertyPixelWidth] as? Int ?? 0, properties?[kCGImagePropertyPixelHeight] as? Int ?? 0)
        var data: Data?
        if longest > printPixels {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: printPixels
            ]
            if let smaller = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                let out = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(out as CFMutableData, "public.jpeg" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, smaller, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
                    if CGImageDestinationFinalize(destination) { data = out as Data }
                }
            }
        }
        guard let bytes = data ?? (try? Data(contentsOf: url)), let image = UIImage(data: bytes) else { return nil }
        loaded.setObject(image, forKey: path as NSString, cost: bytes.count)
        return image
    }

    static func scene(_ contentID: String, month: Int?) -> UIImage? { image(slot: "scene.\(contentID)", month: month) }
    static func cast(_ slug: String, month: Int?) -> UIImage? { image(slot: "cast.\(slug)", month: month) }
    static func frontispiece(month: Int?) -> UIImage? { image(slot: "frontispiece", month: month) }

    /// The month's general plates, for chapter plates and the margins.
    static func general(month: Int?) -> [UIImage] {
        all().filter { plate in
            !plate.slot.hasPrefix("scene.") && !plate.slot.hasPrefix("cast.") && plate.slot != "frontispiece"
                && (plate.month == month || plate.month == nil)
        }
        .sorted { $0.slot < $1.slot }
        .compactMap { load($0.path) }
    }
}

extension MonthlyEditionPDFWriter {
    /// The room an inline plate takes, frame and spacing included.
    static func plateHeight(_ image: UIImage, width: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let scale = min((width - 24) / image.size.width, maxHeight / image.size.height)
        return image.size.height * scale + 28
    }

    /// A plate set across the running leaf, framed, at most `maxHeight` tall.
    @discardableResult
    static func drawInlinePlate(_ image: UIImage, style: EditionStyle, leaf: inout PDFCursor, maxHeight: CGFloat,
                                fresh: () -> PDFCursor) -> Bool {
        let width = leaf.contentWidth - 24
        let scale = min(width / image.size.width, maxHeight / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        if leaf.y + size.height + 28 > leaf.bottom { leaf = fresh() }
        let frame = CGRect(x: leaf.left + (leaf.contentWidth - size.width) / 2, y: leaf.y + 8, width: size.width, height: size.height)
        if let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0.6, height: 1.6), blur: 4, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            UIColor.white.setFill()
            UIBezierPath(rect: frame.insetBy(dx: -6, dy: -6)).fill()
            cg.restoreGState()
        }
        style.palette.gold.setStroke()
        let rule = UIBezierPath(rect: frame.insetBy(dx: -3, dy: -3)); rule.lineWidth = 0.6; rule.stroke()
        image.draw(in: frame)
        leaf.y = frame.maxY + 18
        return true
    }
}

// MARK: - A night's braid, set for print

extension MonthlyEditionPDFWriter {
    /// The letter the last drop cap in this book opened on. Reset at each week.
    static var lastDropCapLetter: Character?
    /// Set while a season is drawn: a scene on its day points at its plate in the season's
    /// gallery, since a season doesn't bind the month's whole tale.
    static var scenesPointToSeasonPlates = false
    /// "term" while a season is drawn, "year" while the annual is.
    static var volumeNoun = "term"
    static var picturesTitle: String { volumeNoun == "year" ? "The Year in Pictures" : "The Season in Pictures" }

    /// A title the phone gave a night that reads poorly on a page: one word,
    /// an article and one word ("A people"), or a stock word.
    static func isWeakBraidTitle(_ title: String) -> Bool {
        let words = title.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        let lower = title.lowercased()
        if words.count <= 1 { return true }
        if words.count == 2, ["a", "an"].contains(words[0].lowercased()) { return true }
        return ["the month", "the day", "the night", "the table", "purest form", "book of you", "the night's braid", "a story"].contains(lower)
    }

    /// A braid split for print: the telling; the Book's own thread, its last
    /// short line about itself ("I've bet the Index a biscuit…"); and the
    /// colophon ("The Book kept the page: …"), each set as itself.
    static func braidParts(_ body: String) -> (telling: String, thread: String?, kept: String?) {
        let (telling, kept) = WeeklyTaleBuilder.split(braid: body)
        var paragraphs = (telling ?? "").components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var thread: String?
        if paragraphs.count > 1, let last = paragraphs.last {
            let opens = ["I'm ", "I've ", "I ", "Tonight I", "My ", "I’m ", "I’ve "]
            if opens.contains(where: last.hasPrefix), last.split(separator: " ").count <= 45 {
                thread = last
                paragraphs.removeLast()
            }
        }
        return (paragraphs.joined(separator: "\n\n"), thread, kept)
    }
}

// MARK: - The foot of a day

extension MonthlyEditionPDFWriter {
    /// Which treatment the next day's foot gets. Reset at each book.
    static var dayFootCount = 0

    /// The moon that night as a naturalist would note it: drawn large, with
    /// its name, how much of it was lit and how old it was.
    static func drawMoonCard(_ day: BoundDay, calendar: Calendar, style: EditionStyle, in rect: CGRect) {
        let ink = style.palette.ink
        drawTracked("The moon that night", at: CGPoint(x: rect.minX, y: rect.minY), font: smallCaps(6.8), color: style.palette.accent, tracking: 1.4)
        let radius = min(34, (rect.height - 30) / 2)
        let center = CGPoint(x: rect.minX + radius + 10, y: rect.minY + 22 + radius)
        let age = day.almanac.moonAgeDays
        FieldMoon.draw(center: center, radius: radius, illuminated: day.almanac.moonIlluminated,
                       waxing: age < MoonPhaseCalendar.synodicMonthDays / 2, ink: ink)
        let x = center.x + radius + 18
        let width = rect.maxX - x
        var y = center.y - radius + 2
        (day.almanac.moonName as NSString).draw(at: CGPoint(x: x, y: y),
            withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 15), .foregroundColor: ink])
        y += 22
        let lit = Int((day.almanac.moonIlluminated * 100).rounded())
        let days = Int(age.rounded())
        let facts = "\(lit)% lit · \(days) \(days == 1 ? "day" : "days") old" + (day.almanac.skyWords.first.map { " · sky \($0)" } ?? "")
        (facts as NSString).draw(at: CGPoint(x: x, y: y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 9.6, weight: .regular), .foregroundColor: ink.withAlphaComponent(0.72)])
        y += 16
        let note: String
        switch days {
        case 0...1: note = "Too new to see. It was there anyway."
        case 13...16: note = "Full, or near enough to be argued about."
        case 2...6: note = "A thin one, low after sunset."
        case 7...12: note = "Fattening. Up in the afternoon, if anyone looked."
        case 17...22: note = "Late to rise and lit on its other side."
        default: note = "Thin again, up before dawn for the early ones."
        }
        _ = FieldText.flow(note, font: .fbSerifItalic(ofSize: 9.6), color: ink.withAlphaComponent(0.66),
                           in: CGRect(x: x, y: y, width: width, height: 30), lineSpacing: 1, paragraphSpacing: 0, justified: false)
    }

    /// A drawing from the month's art pressed between the pages: taped in, a
    /// little crooked, with a pencilled line saying when.
    static func drawPressedDrawing(_ image: UIImage, day: BoundDay, style: EditionStyle, in rect: CGRect) {
        let box = CGRect(x: rect.midX - 90, y: rect.minY + 8, width: 180, height: rect.height - 36)
        let scale = min(box.width / image.size.width, box.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let frame = CGRect(x: box.midX - size.width / 2, y: box.minY + (box.height - size.height) / 2, width: size.width, height: size.height)
        let tilt = (frac("pressed-\(day.id)") - 0.5) * 0.12
        if let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            cg.translateBy(x: frame.midX, y: frame.midY); cg.rotate(by: tilt); cg.translateBy(x: -frame.midX, y: -frame.midY)
            image.draw(in: frame)
            cg.restoreGState()
        }
        drawTapeStrip(center: CGPoint(x: frame.midX - frame.width * 0.3, y: frame.minY + 2), length: 34, angle: -0.5 + tilt, tint: style.palette.gold)
        drawTapeStrip(center: CGPoint(x: frame.midX + frame.width * 0.3, y: frame.maxY - 2), length: 34, angle: -0.5 + tilt, tint: style.palette.gold)
        let formatter = DateFormatter(); formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        let caption = "pressed here, \(formatter.string(from: day.date))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: handFont(10), .foregroundColor: style.palette.ink.withAlphaComponent(0.6)]
        let w = caption.size(withAttributes: attrs).width
        caption.draw(at: CGPoint(x: rect.midX - w / 2, y: frame.maxY + 10), withAttributes: attrs)
    }
}


// MARK: - The Season: a term, bound as one book

extension MonthlyEditionPDFWriter {
    /// One scene's plate in the season's gallery, and what the reader did there.
    struct SeasonPlate {
        var number: Int
        var chapter: MonthlyEdition
        var scene: BoundTaleChapter
        var image: UIImage
    }

    /// Every scene of the season that has a plate, in the order the reader met them.
    /// A year keeps the first and last plate of each month; a season keeps every one.
    static func seasonPlates(_ annual: AnnualEdition, calendar: Calendar) -> [SeasonPlate] {
        var plates: [SeasonPlate] = []
        for chapter in annual.chapters {
            guard let book = chapter.dayBook else { continue }
            let month = calendar.component(.month, from: chapter.startDate)
            var scenes = book.taleChapters.filter { EditionPlates.scene($0.contentID, month: month) != nil }
            if annual.publicationKind == .annual, scenes.count > 2 { scenes = [scenes.first!, scenes.last!] }
            for scene in scenes {
                guard let image = EditionPlates.scene(scene.contentID, month: month) else { continue }
                plates.append(SeasonPlate(number: plates.count + 1, chapter: chapter, scene: scene, image: image))
            }
        }
        return plates
    }

    /// A part of the book opening on its own leaf: the number, the name, a line under it.
    static func drawPartOpener(_ part: String, title: String, dek: String, monthNumber: Int,
                               style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: part, headRight: title)
        let ink = style.palette.ink
        leaf.y = leaf.margins.top + (leaf.bottom - leaf.margins.top) * 0.3
        drawTracked(part, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(8), color: style.palette.accent,
                    tracking: 2.4, width: leaf.contentWidth, alignment: .center)
        leaf.y += 22
        var titleFont = UIFont.fbSerif(ofSize: 30, weight: .bold)
        while titleFont.pointSize > 18,
              (title as NSString).size(withAttributes: [.font: titleFont]).width > leaf.contentWidth - 8 {
            titleFont = .fbSerif(ofSize: titleFont.pointSize - 1, weight: .bold)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (title as NSString).draw(in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 44),
                                 withAttributes: [.font: titleFont, .foregroundColor: ink, .paragraphStyle: paragraph])
        leaf.y += 52
        let dekFont = UIFont.fbSerifItalic(ofSize: 11)
        let width = leaf.contentWidth * 0.78
        let h = FieldText.height(dek, font: dekFont, width: width, lineSpacing: 3, paragraphSpacing: 0, justified: false)
        let dekStyle = NSMutableParagraphStyle()
        dekStyle.alignment = .center
        dekStyle.lineSpacing = 3
        (dek as NSString).draw(in: CGRect(x: leaf.left + (leaf.contentWidth - width) / 2, y: leaf.y, width: width, height: h + 6),
                               withAttributes: [.font: dekFont, .foregroundColor: ink.withAlphaComponent(0.72), .paragraphStyle: dekStyle])
        if let plant = FieldBotanicals.image(month: monthNumber, seed: "part-\(title)") {
            let w = min(90, plant.size.width * plant.scale / 150 * 72)
            let h = w * plant.size.height / plant.size.width
            plant.draw(in: CGRect(x: leaf.left + (leaf.contentWidth - w) / 2, y: leaf.bottom - h - 20, width: w, height: h))
        }
    }

    /// The season's contents: three parts and what's in each, set like the monthly's.
    static func drawSeasonContents(
        _ annual: AnnualEdition, plateCount: Int, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Contents", headRight: annual.title)
        drawEyebrow("What's in this book", style: style, leaf: &leaf)
        ((volumeNoun == "year" ? "This Year" : "This Term") as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                       withAttributes: [.font: UIFont.fbSerif(ofSize: 26, weight: .bold), .foregroundColor: ink])
        leaf.y += 44
        func entry(_ part: String?, _ title: String, _ note: String, size: CGFloat = 14) {
            if let part {
                drawTracked(part, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7), color: style.palette.accent, tracking: 1.8)
                leaf.y += 12
            }
            (title as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                     withAttributes: [.font: UIFont.fbSerif(ofSize: size, weight: .semibold), .foregroundColor: ink])
            leaf.y += size + 6
            hbText(note, font: .fbSerifItalic(ofSize: 9.6), color: ink.withAlphaComponent(0.66), leaf: &leaf, justified: false, gap: 12)
        }
        let days = annual.chapters.reduce(0) { $0 + ($1.dayBook?.days.count ?? $1.dayCount) }
        entry("Part One", volumeNoun == "year" ? "Your Year" : "Your Days", volumeNoun == "year"
              ? "Twelve months, each opening on its almanac: the fullest of its days, whole, and a line or two from every other day you wrote."
              : "\(days) days in your own words, a month at a time, each opening on its almanac.")
        for chapter in annual.chapters {
            let theme = chapter.theme.map { " \u{00B7} \u{201C}\($0.name)\u{201D}" } ?? ""
            let count = chapter.dayBook?.days.count ?? chapter.dayCount
            ("\(chapter.monthName)\(theme)" as NSString).draw(
                at: CGPoint(x: leaf.left + 14, y: leaf.y),
                withAttributes: [.font: UIFont.fbSerif(ofSize: 10.6, weight: .regular), .foregroundColor: ink])
            drawTracked("\(count) days", at: CGPoint(x: leaf.left, y: leaf.y + 2), font: smallCaps(6.6),
                        color: ink.withAlphaComponent(0.45), tracking: 1.1, width: leaf.contentWidth, alignment: .right)
            leaf.y += 17
        }
        leaf.y += 10
        if plateCount > 0 {
            entry("Part Two", picturesTitle,
                  "\(plateCount) \(plateCount == 1 ? "plate" : "plates") from the story you read, with the choices you made.")
        }
        if let handbook = annual.handbook, !handbook.isEmpty {
            var inside = ["the coursework"]
            if !(handbook.transcript ?? []).isEmpty { inside.append("the Register") }
            if !handbook.dossiers.isEmpty { inside.append("the Faculty files") }
            if !handbook.lore.isEmpty { inside.append("the Lore Shelf") }
            if handbook.workbook != nil { inside.append("the puzzles and your Report Card") }
            let list = inside.count > 1 ? inside.dropLast().joined(separator: ", ") + " and " + inside.last! : inside[0]
            entry(plateCount > 0 ? "Part Three" : "Part Two", volumeNoun == "year" ? "The Academy Year" : "The Term",
                  list.prefix(1).uppercased() + list.dropFirst() + ".")
        }
        var after: [String] = (annual.playLeaves ?? []).map(\.definition.contentsListing)
        if !(annual.nightsLedger ?? []).isEmpty { after.append("The Ledger of Nights") }
        if !(annual.memorySpine?.isEmpty ?? true) { after.append("What Stayed With Me") }
        if !after.isEmpty {
            drawEyebrow("At the back", style: style, leaf: &leaf)
            for line in after where leaf.y + 16 < leaf.bottom {
                (line as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
                                        withAttributes: [.font: UIFont.fbSerif(ofSize: 10.6, weight: .regular), .foregroundColor: ink])
                leaf.y += 16
            }
        }
    }

    /// The words that wouldn't leave the term alone, counted, and the questions still open. The
    /// nights themselves are all in Part One, so this leaf doesn't list them again.
    static func drawSeasonKeptComingBack(
        _ spine: AnnualMemorySpine, annual: AnnualEdition, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let motifs: [(word: String, count: Int)] = spine.motifs.compactMap { line in
            guard let open = line.lastIndex(of: "("), let count = Int(line[line.index(after: open)...].dropLast()) else { return nil }
            return (line[..<open].trimmingCharacters(in: .whitespaces), count)
        }
        guard !motifs.isEmpty || !spine.openQuestions.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "What stayed with me", headRight: "The \(volumeNoun)")
        drawEyebrow("What stayed with me", style: style, leaf: &leaf)
        ("What Kept Coming Back" as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 24, weight: .bold), .foregroundColor: ink])
        leaf.y += 38
        if !motifs.isEmpty {
            hbText("Some words wouldn't leave this \(volumeNoun) alone. They kept turning up in your nights, so I counted them. The bigger the word, the more often it came back.",
                   font: .fbSerifItalic(ofSize: 10.6), color: ink.withAlphaComponent(0.8), leaf: &leaf, justified: false, gap: 18)
            let top = Double(motifs.map(\.count).max() ?? 1)
            var x = leaf.left
            var lineHeight: CGFloat = 0
            for (index, motif) in motifs.prefix(12).enumerated() {
                let size = 13 + CGFloat(Double(motif.count) / top) * 17
                let font = index % 3 == 1 ? UIFont.fbSerifItalic(ofSize: size) : UIFont.fbSerif(ofSize: size, weight: .regular)
                let word = NSAttributedString(string: motif.word, attributes: [
                    .font: font, .foregroundColor: index % 4 == 0 ? style.palette.accent : ink])
                let tally = NSAttributedString(string: " \(motif.count)", attributes: [
                    .font: smallCaps(6.6), .foregroundColor: ink.withAlphaComponent(0.45)])
                let width = word.size().width + tally.size().width + 18
                if x + width > leaf.right, x > leaf.left {
                    x = leaf.left
                    leaf.y += lineHeight + 8
                    lineHeight = 0
                }
                let baseline = leaf.y
                word.draw(at: CGPoint(x: x, y: baseline))
                tally.draw(at: CGPoint(x: x + word.size().width + 2, y: baseline + font.ascender - 8))
                x += width
                lineHeight = max(lineHeight, font.lineHeight)
            }
            leaf.y += lineHeight + 26
        }
        drawTermCounted(annual, style: style, leaf: &leaf)
        if !spine.openQuestions.isEmpty, leaf.y + 60 < leaf.bottom {
            drawEyebrow("Questions still warm", style: style, leaf: &leaf)
            for question in spine.openQuestions.prefix(5) where leaf.y + 30 < leaf.bottom {
                hbText(question, font: .fbSerif(ofSize: 10.6, weight: .regular), color: ink.withAlphaComponent(0.88),
                       leaf: &leaf, justified: false, gap: 8)
            }
        }
        fillLeafFoot(month: Calendar.current.component(.month, from: annual.endDate), seed: "kept-coming-back", leaf: leaf, alignRight: false)
    }

    /// The term in numbers, the way a child counts things they're proud of: days, nights, words,
    /// the longest run, and who was there most.
    static func drawTermCounted(_ annual: AnnualEdition, style: EditionStyle, leaf: inout PDFCursor) {
        let calendar = Calendar.current
        let days = annual.chapters.compactMap(\.dayBook).flatMap(\.days).sorted { $0.date < $1.date }
        guard !days.isEmpty else { return }
        let written = days.filter { !$0.words.isEmpty }
        let words = written.reduce(0) { $0 + $1.words.reduce(0) { $0 + $1.split(separator: " ").count } }
        let nights = days.reduce(0) { $0 + $1.braids.count }
        let photos = days.reduce(0) { $0 + $1.photos.count }
        let scenes = Set(days.flatMap(\.scenes).map(\.contentID)).count
        var longest = 0, run = 0
        var previous: Date?
        for day in written {
            if let previous, calendar.dateComponents([.day], from: previous, to: day.date).day == 1 { run += 1 } else { run = 1 }
            longest = max(longest, run)
            previous = day.date
        }
        // Everybody on the timetable is "about" every day; who was in the reader's scenes is the real count.
        var presence: [String: (name: String, scenes: Int)] = [:]
        for person in annual.chapters.compactMap(\.dayBook).flatMap(\.chart.cast) {
            presence[person.slug, default: (person.name, 0)].scenes += person.sceneCount
        }
        let most = presence.values.max { ($0.scenes, $1.name) < ($1.scenes, $0.name) }
        let grouped = NumberFormatter()
        grouped.numberStyle = .decimal

        var rows: [(String, String)] = []
        rows.append(("\(written.count)", written.count == 1 ? "day you wrote in" : "days you wrote in"))
        if words > 0 { rows.append((grouped.string(from: NSNumber(value: words)) ?? "\(words)", "words, all yours")) }
        if nights > 0 { rows.append(("\(nights)", nights == 1 ? "night I braided" : "nights I braided")) }
        if longest > 1 { rows.append(("\(longest)", "days in a row, your longest run")) }
        if scenes > 0 { rows.append(("\(scenes)", scenes == 1 ? "scene you read" : "scenes you read")) }
        if photos > 0 { rows.append(("\(photos)", photos == 1 ? "photograph" : "photographs")) }
        if let most, most.scenes > 1 { rows.append(("\(most.scenes)", "scenes with \(most.name) in. Nobody was in more.")) }
        guard leaf.y + CGFloat(rows.count) * 22 + 40 < leaf.bottom else { return }
        let ink = style.palette.ink
        drawEyebrow("The \(volumeNoun), counted", style: style, leaf: &leaf)
        let numberFont = UIFont.fbSerif(ofSize: 17, weight: .semibold)
        for (number, label) in rows {
            let n = number as NSString
            let nw = n.size(withAttributes: [.font: numberFont]).width
            n.draw(at: CGPoint(x: leaf.left + 54 - nw, y: leaf.y), withAttributes: [.font: numberFont, .foregroundColor: style.palette.accent])
            (label as NSString).draw(at: CGPoint(x: leaf.left + 64, y: leaf.y + 5),
                                     withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10.6), .foregroundColor: ink.withAlphaComponent(0.82)])
            leaf.y += 22
        }
        leaf.y += 16
    }

    /// A month for the year's book: its richest days, whole, in date order, and no week leaves.
    /// A day earns its place by what's on it: a letter or a Cast note, a quote or a believing,
    /// a story, a night, a photograph or a sheet, a scene, and how much the reader wrote.
    static func yearbookBook(_ book: BoundDayBook, days limit: Int) -> BoundDayBook {
        func score(_ day: BoundDay) -> Int {
            var points = day.braids.count * 3 + day.photos.count * 3 + day.scrapbook.count * 5
            points += Set(day.scenes.map(\.contentID)).count * 2
            points += min(6, day.entries.reduce(0) { $0 + $1.wordCount } / 15)
            for keep in day.keeps {
                switch keep.kind {
                case .letter, .castNote, .story, .enchantment, .plate: points += 4
                case .quotation, .lore: points += 3
                case .classSession, .club: points += 2
                }
                if keep.readerReply != nil { points += 2 }
            }
            return points
        }
        let candidates: [BoundDay] = book.days.filter { $0.hasYourSide || $0.hasWorldSide }
        let scored: [(day: BoundDay, points: Int)] = candidates.map { (day: $0, points: score($0)) }
        let ranked = scored.sorted { a, b in
            a.points != b.points ? a.points > b.points : a.day.date < b.day.date
        }
        let chosen: [BoundDay] = ranked.prefix(limit).map(\.day).sorted { $0.date < $1.date }
        var curated = book
        curated.days = chosen
        curated.weeks = []
        return curated
    }

    /// What the Book worked out about the reader: each connection with its name, the Book's reading
    /// (hits and base rate both), and the reader's own lines it was read from, in their hand.
    static func drawConnections(
        _ connections: [EditionConnection], span: String, style: EditionStyle, singleLeaf: Bool = false,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        guard !connections.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "What I worked out", headRight: "Connections")
        func fresh() {
            leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "What I worked out", headRight: "continued")
        }
        drawEyebrow("Connections", style: style, leaf: &leaf)
        ("What I Worked Out About You" as NSString).draw(at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 22, weight: .bold), .foregroundColor: ink])
        leaf.y += 34
        hbText("I held \(span) still and looked for the threads you can't see from inside it. I only write one down if I can count it both ways: when it happened, and when it didn't. Here's what held.",
               font: .fbSerifItalic(ofSize: 10.6), color: ink.withAlphaComponent(0.8), leaf: &leaf, justified: false, gap: 16)
        let dates = DateFormatter()
        dates.dateFormat = "MMM d"
        let titleFont = UIFont.fbSerif(ofSize: 13.5, weight: .semibold)
        let readingFont = UIFont.fbSerif(ofSize: 10.4, weight: .regular)
        let handAttributes: [NSAttributedString.Key: Any] = [.font: handFont(10.4), .foregroundColor: readerInk]
        for (index, connection) in connections.enumerated() {
            let readingH = FieldText.height(connection.reading, font: readingFont, width: leaf.contentWidth - 22,
                                            lineSpacing: 2.2, paragraphSpacing: 4, justified: false)
            if leaf.y + 40 + readingH + 30 > leaf.bottom {
                // A weekly's leaf count is fixed by its signature: what doesn't fit waits for the month.
                if singleLeaf { break }
                fresh()
            }
            drawTracked(RomanNumeral.of(index + 1), at: CGPoint(x: leaf.left, y: leaf.y + 3), font: smallCaps(7.4),
                        color: style.palette.accent, tracking: 1.2)
            let titleH = FieldText.height(connection.title, font: titleFont, width: leaf.contentWidth - 22, justified: false)
            _ = FieldText.flow(connection.title, font: titleFont, color: ink,
                               in: CGRect(x: leaf.left + 22, y: leaf.y, width: leaf.contentWidth - 22, height: titleH + 2),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += titleH + 4
            hbText(connection.reading, font: readingFont, color: ink.withAlphaComponent(0.86), leaf: &leaf,
                   x: leaf.left + 22, lineSpacing: 2.2, paragraphSpacing: 4, justified: false, gap: 6)
            for item in connection.evidence.prefix(3) {
                let quote = "\u{201C}\(item.excerpt)\u{201D}" as NSString
                let width = leaf.contentWidth - 22 - 50
                let h = min(handFont(10.4).lineHeight * 3 + 2, ceil(quote.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin],
                    attributes: handAttributes, context: nil).height))
                if leaf.y + h + 6 > leaf.bottom { break }
                drawTracked(dates.string(from: item.date), at: CGPoint(x: leaf.left + 22, y: leaf.y + 3), font: smallCaps(6.4),
                            color: ink.withAlphaComponent(0.5), tracking: 1)
                quote.draw(with: CGRect(x: leaf.left + 72, y: leaf.y, width: width, height: h),
                           options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: handAttributes, context: nil)
                leaf.y += h + 4
            }
            leaf.y += 6
            ink.withAlphaComponent(0.14).setFill()
            UIRectFill(CGRect(x: leaf.left + 22, y: leaf.y, width: leaf.contentWidth - 22, height: 0.5))
            leaf.y += 14
        }
        fillLeafFoot(month: Calendar.current.component(.month, from: connections.first?.evidence.first?.date ?? Date()),
                     seed: "connections-\(span)", leaf: leaf)
    }

    /// One month of the season's Part One: its almanac, its map, then every day in full.
    static func drawSeasonMonth(
        _ chapter: MonthlyEdition,
        plates: [SeasonPlate],
        marginalia: [BoundMarginNote],
        curated: Int? = nil,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard let whole = chapter.dayBook else { return }
        let book = curated.map { yearbookBook(whole, days: $0) } ?? whole
        let calendar = Calendar.current
        let style = EditionStyle.style(for: chapter)
        let month = calendar.component(.month, from: chapter.startDate)
        scenesPointToSeasonPlates = true
        defer { scenesPointToSeasonPlates = false }
        lastDropCapLetter = nil
        dayFootCount = 0
        drawAlmanacSpread(chapter, book: whole, monthNumber: month, calendar: calendar, style: style,
                          facing: false, context: context, cursor: &cursor)
        if !book.chart.timetableOnly {
            drawLabyrinthSpread(chapter, book: whole, mapPlates: [], monthNumber: month, style: style,
                                facing: false, context: context, cursor: &cursor)
        }
        let pointers = Dictionary(plates.filter { $0.chapter.startDate == chapter.startDate }
            .map { ($0.scene.contentID, $0.number) }, uniquingKeysWith: { first, _ in first })
        drawDays(start: chapter.startDate, book: book, monthNumber: month, calendar: calendar, style: style,
                 marginalia: marginalia, tale: pointers, context: context, cursor: &cursor)
        // The year's book prints every day the reader wrote: the rest of the month, a line or two each.
        if curated != nil {
            let shown = Set(book.days.map(\.id))
            let rest = whole.days.filter { !shown.contains($0.id) && !$0.words.isEmpty }
            let monthName = monthFormatter.string(from: chapter.startDate)
            drawCommonplace(rest, monthNumber: month, calendar: calendar, style: style,
                            headLeft: "The rest of \(monthName)", headRight: "A line or two a day", perDay: 2,
                            context: context, cursor: &cursor)
        }
    }

    /// Part Two: the season's story in its plates. One scene to a leaf: the plate, where and when,
    /// the first lines as the reader read them, and what they chose.
    static func drawSeasonPictures(
        _ plates: [SeasonPlate],
        annual: AnnualEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !plates.isEmpty else { return }
        let calendar = Calendar.current
        let firstMonth = calendar.component(.month, from: annual.startDate)
        drawPartOpener("Part Two", title: picturesTitle,
                       dek: volumeNoun == "year"
                           ? "The story you read this year, a plate or two from every month it ran, with the choices you made written in."
                           : "The story you read this season, a plate to a scene, with the choices you made written in.",
                       monthNumber: firstMonth, style: style, context: context, cursor: &cursor)
        let ink = style.palette.ink
        let dates = DateFormatter()
        dates.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        for plate in plates {
            let chapterStyle = EditionStyle.style(for: plate.chapter)
            var leaf = fieldLeaf(&cursor, style: chapterStyle, context: context, headLeft: picturesTitle,
                                 headRight: plate.chapter.monthName)
            drawTracked("Plate \(RomanNumeral.of(plate.number))", at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(7.2),
                        color: chapterStyle.palette.accent, tracking: 2)
            leaf.y += 14
            let titleFont = UIFont.fbSerifItalic(ofSize: 21)
            let th = FieldText.height(plate.scene.title, font: titleFont, width: leaf.contentWidth, justified: false)
            _ = FieldText.flow(plate.scene.title, font: titleFont, color: ink,
                               in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: th + 4),
                               lineSpacing: 0, paragraphSpacing: 0, justified: false)
            leaf.y += th + 4
            var whereWhen = "Read \(dates.string(from: plate.scene.readAt))"
            if let room = plate.scene.roomName { whereWhen += " · \(room)" }
            hbText(whereWhen, font: .fbSerifItalic(ofSize: 9.2), color: ink.withAlphaComponent(0.62), leaf: &leaf,
                   justified: false, gap: 8)
            func fresh() -> PDFCursor {
                fieldLeaf(&cursor, style: chapterStyle, context: context, headLeft: picturesTitle,
                          headRight: "\(plate.chapter.monthName) · continued")
            }
            _ = drawInlinePlate(plate.image, style: chapterStyle, leaf: &leaf, maxHeight: 320, fresh: fresh)
            let read = plate.scene.parts.first(where: { !$0.isReport }) ?? plate.scene.parts.first
            // As much of the opening as the leaf holds after the choices and the reader's own line.
            let sameDay = plate.chapter.dayBook?.day(on: plate.scene.readAt)?.words.first { $0.count > 12 }
            let reserve: CGFloat = (plate.scene.parts.contains { $0.choiceLabel != nil } ? 46 : 0) + (sameDay == nil ? 0 : 58)
            let bodyFont = UIFont.fbSerif(ofSize: 10.2, weight: .regular)
            for words in [150, 110, 80, 50] {
                let opening = BoundDayBook.opening(of: read?.body ?? "", words: words, gathering: words - 20)
                guard !opening.isEmpty else { break }
                let h = FieldText.height(opening, font: bodyFont, width: leaf.contentWidth, lineSpacing: 2.4, paragraphSpacing: 5, justified: true)
                if leaf.y + h + reserve + 10 < leaf.bottom {
                    hbText(opening, font: bodyFont, color: ink.withAlphaComponent(0.86), leaf: &leaf, lineSpacing: 2.4, justified: true, gap: 10)
                    break
                }
            }
            let choices = plate.scene.parts.compactMap(\.choiceLabel)
            for (index, choice) in choices.prefix(2).enumerated() where leaf.y + 40 < leaf.bottom {
                drawChoiceSlip(choice, style: chapterStyle, leaf: &leaf, fresh: fresh,
                               seed: "season-plate-\(plate.number)-\(index)", fontSize: 10.6, widthFraction: 0.62,
                               alignedRight: index % 2 == 1, rotation: index % 2 == 0 ? -0.03 : 0.025)
            }
            // What the reader's own day was, beside the story's.
            if let line = sameDay, leaf.y + 56 < leaf.bottom {
                leaf.y += 4
                drawEyebrow("That same day, you wrote", style: chapterStyle, leaf: &leaf)
                let quote = "\u{201C}\(line)\u{201D}"
                let attributes: [NSAttributedString.Key: Any] = [.font: handFont(11), .foregroundColor: readerInk]
                let h = min(handFont(11).lineHeight * 2 + 4, leaf.bottom - leaf.y)
                (quote as NSString).draw(with: CGRect(x: leaf.left + 8, y: leaf.y, width: leaf.contentWidth - 16, height: h),
                                         options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
                leaf.y += h + 8
            }
            // The story's own margin note under its plate, or a drawing in the room that's left.
            let month = Calendar.current.component(.month, from: plate.scene.readAt)
            if !drawStoryMark(month: month, style: chapterStyle, leaf: &leaf) {
                fillLeafFoot(month: month, seed: "picture-\(plate.number)", leaf: leaf)
            }
        }
    }

    /// A drawing from the book's deck in whatever is left at the foot of a leaf, when there's
    /// enough of it to be worth one. The volumes' own leaves (pictures, connections, what came
    /// back) would otherwise end in bare paper.
    static func fillLeafFoot(month: Int, seed: String, leaf: PDFCursor, alignRight: Bool = true) {
        let remaining = leaf.bottom - leaf.y
        guard remaining > 110 else { return }
        let height = min(remaining - 12, 150)
        drawBotanical(month: month, seed: seed,
                      in: CGRect(x: alignRight ? leaf.right - 130 : leaf.left, y: leaf.bottom - height, width: 130, height: height),
                      alignRight: alignRight, rotation: alignRight ? -0.06 : 0.06)
    }
}
