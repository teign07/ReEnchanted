import Foundation
import UIKit
import PDFKit
import Photos

// MARK: - Edition style
//
// Every month gets its own visual identity, chosen deterministically from
// the month key and theme so a given edition always binds the same way -
// but no two months look alike. A palette, a cover motif, and an ornament
// style together make the month's "binding".

struct EditionStyle {
    struct Palette {
        let name: String
        let paperTop: UIColor
        let paperBottom: UIColor
        let coverText: UIColor
        let ink: UIColor
        let accent: UIColor
        let accentSoft: UIColor
        let gold: UIColor
    }

    enum CoverMotif: CaseIterable {
        case constellation
        case moonAndWaves
        case lamp
        case sprig
        case keyAndDoor
    }

    enum Ornament: CaseIterable {
        case diamonds
        case stars
        case waves
        case leaves
    }

    let palette: Palette
    let coverMotif: CoverMotif
    let ornament: Ornament

    static let palettes: [Palette] = [
        Palette(
            name: "Harbor",
            paperTop: UIColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1),
            paperBottom: UIColor(red: 0.05, green: 0.09, blue: 0.15, alpha: 1),
            coverText: UIColor(red: 0.92, green: 0.90, blue: 0.82, alpha: 1),
            ink: UIColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1),
            accent: UIColor(red: 0.16, green: 0.34, blue: 0.45, alpha: 1),
            accentSoft: UIColor(red: 0.16, green: 0.34, blue: 0.45, alpha: 0.16),
            gold: UIColor(red: 0.78, green: 0.62, blue: 0.33, alpha: 1)
        ),
        Palette(
            name: "Lamplight",
            paperTop: UIColor(red: 0.24, green: 0.16, blue: 0.08, alpha: 1),
            paperBottom: UIColor(red: 0.14, green: 0.09, blue: 0.05, alpha: 1),
            coverText: UIColor(red: 0.96, green: 0.89, blue: 0.74, alpha: 1),
            ink: UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1),
            accent: UIColor(red: 0.62, green: 0.42, blue: 0.16, alpha: 1),
            accentSoft: UIColor(red: 0.62, green: 0.42, blue: 0.16, alpha: 0.15),
            gold: UIColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 1)
        ),
        Palette(
            name: "Violet Dusk",
            paperTop: UIColor(red: 0.16, green: 0.11, blue: 0.24, alpha: 1),
            paperBottom: UIColor(red: 0.09, green: 0.06, blue: 0.15, alpha: 1),
            coverText: UIColor(red: 0.92, green: 0.88, blue: 0.95, alpha: 1),
            ink: UIColor(red: 0.16, green: 0.12, blue: 0.20, alpha: 1),
            accent: UIColor(red: 0.38, green: 0.27, blue: 0.52, alpha: 1),
            accentSoft: UIColor(red: 0.38, green: 0.27, blue: 0.52, alpha: 0.15),
            gold: UIColor(red: 0.80, green: 0.64, blue: 0.38, alpha: 1)
        ),
        Palette(
            name: "Forest Margin",
            paperTop: UIColor(red: 0.09, green: 0.18, blue: 0.13, alpha: 1),
            paperBottom: UIColor(red: 0.05, green: 0.11, blue: 0.08, alpha: 1),
            coverText: UIColor(red: 0.90, green: 0.92, blue: 0.84, alpha: 1),
            ink: UIColor(red: 0.12, green: 0.16, blue: 0.13, alpha: 1),
            accent: UIColor(red: 0.20, green: 0.40, blue: 0.28, alpha: 1),
            accentSoft: UIColor(red: 0.20, green: 0.40, blue: 0.28, alpha: 0.15),
            gold: UIColor(red: 0.74, green: 0.60, blue: 0.30, alpha: 1)
        ),
        Palette(
            name: "Rose Vellum",
            paperTop: UIColor(red: 0.27, green: 0.13, blue: 0.16, alpha: 1),
            paperBottom: UIColor(red: 0.17, green: 0.07, blue: 0.10, alpha: 1),
            coverText: UIColor(red: 0.96, green: 0.89, blue: 0.86, alpha: 1),
            ink: UIColor(red: 0.20, green: 0.13, blue: 0.14, alpha: 1),
            accent: UIColor(red: 0.55, green: 0.27, blue: 0.32, alpha: 1),
            accentSoft: UIColor(red: 0.55, green: 0.27, blue: 0.32, alpha: 0.14),
            gold: UIColor(red: 0.80, green: 0.62, blue: 0.36, alpha: 1)
        ),
        Palette(
            name: "Slate Nocturne",
            paperTop: UIColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 1),
            paperBottom: UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1),
            coverText: UIColor(red: 0.91, green: 0.91, blue: 0.88, alpha: 1),
            ink: UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1),
            accent: UIColor(red: 0.30, green: 0.36, blue: 0.46, alpha: 1),
            accentSoft: UIColor(red: 0.30, green: 0.36, blue: 0.46, alpha: 0.15),
            gold: UIColor(red: 0.76, green: 0.64, blue: 0.40, alpha: 1)
        )
    ]

    /// Deterministic per edition: the same month + theme always binds the
    /// same way, and the theme's motifs can pull the cover toward water,
    /// light, or growth.
    static func style(for edition: MonthlyEdition) -> EditionStyle {
        let seed = "\(BookThemeEngine.monthKey(for: edition.startDate))-\(edition.theme?.name ?? "untitled")"
        let palette = palettes[ConstellationKeeper.stableIndex(for: "\(seed)-palette", count: palettes.count)]

        var motif = CoverMotif.allCases[ConstellationKeeper.stableIndex(for: "\(seed)-motif", count: CoverMotif.allCases.count)]
        let motifWords = (edition.theme?.motifs ?? []).joined(separator: " ")
        if motifWords.contains("harbor") || motifWords.contains("rain") || motifWords.contains("sea") || motifWords.contains("shore") {
            motif = .moonAndWaves
        } else if motifWords.contains("lamp") || motifWords.contains("light") || motifWords.contains("candle") {
            motif = .lamp
        } else if motifWords.contains("garden") || motifWords.contains("tree") || motifWords.contains("leaf") || motifWords.contains("forest") {
            motif = .sprig
        } else if !edition.constellations.filter(\.isAlive).isEmpty, ConstellationKeeper.stableIndex(for: "\(seed)-starpull", count: 3) == 0 {
            motif = .constellation
        }

        let ornament = Ornament.allCases[ConstellationKeeper.stableIndex(for: "\(seed)-ornament", count: Ornament.allCases.count)]
        return EditionStyle(palette: palette, coverMotif: motif, ornament: ornament)
    }
}

// MARK: - PDF writer

enum MonthlyEditionPDFWriter {
    private static let mediaPresentationKey = "monthlyEditionPresentation"
    private static let fullPageMediaPresentation = "fullPage"

    static func write(_ edition: MonthlyEdition, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let style = EditionStyle.style(for: edition)
        let margins = UIEdgeInsets(top: 60, left: 120, bottom: 64, right: 58)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            renderInterior(
                edition,
                into: context,
                style: style,
                pageBounds: pageBounds,
                margins: margins,
                designSize: pageBounds.size
            )
        }
    }

    /// The shared body of every edition: cover, foreword, theme, star chart,
    /// contents, sections, closing, colophon. The screen export renders it at US
    /// Letter; the print export renders it at a full-bleed trim with print
    /// margins. The flowing pages adapt to `pageBounds`/`margins` on their own;
    /// the two full-bleed art pages are drawn in a fixed 612×792 design space and
    /// scaled into whatever trim is asked for, so they survive any page size.
    private static func renderInterior(
        _ edition: MonthlyEdition,
        into context: UIGraphicsPDFRendererContext,
        style: EditionStyle,
        pageBounds: CGRect,
        margins: UIEdgeInsets,
        designSize: CGSize
    ) {
        var cursor = PDFCursor(bounds: pageBounds, margins: margins)
        cursor.seed = "\(BookThemeEngine.monthKey(for: edition.startDate))-\(edition.theme?.name ?? "untitled")"
        var marginaliaIndex = 0
        let marginalia = marginaliaLines(for: edition)
        let designRect = CGRect(origin: .zero, size: designSize)

        context.beginPage()
        withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
            drawCover(edition, style: style, bounds: designRect)
        }

        if !edition.foreword.isEmpty {
            beginComposedPage(context, style: style, cursor: &cursor)
            drawForeword(edition, style: style, context: context, cursor: &cursor)
        }

        if let bindingStory = edition.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            beginComposedPage(context, style: style, cursor: &cursor)
            drawBindingStory(bindingStory, edition: edition, style: style, context: context, cursor: &cursor)
        }

        if let theme = edition.theme {
            beginComposedPage(context, style: style, cursor: &cursor)
            drawThemePage(theme, edition: edition, style: style, bounds: pageBounds, cursor: &cursor)
        }

        let aliveConstellations = edition.constellations.filter(\.isAlive)
        if !aliveConstellations.isEmpty {
            context.beginPage()
            withDesignSpace(designSize: designSize, pageBounds: pageBounds) {
                drawStarChart(aliveConstellations, edition: edition, style: style, bounds: designRect)
            }
        }

        beginComposedPage(context, style: style, cursor: &cursor)
        drawContents(edition, style: style, cursor: &cursor)

        for section in edition.sections where section.id != "the-months-theme" {
            drawSection(
                section,
                style: style,
                marginalia: marginalia,
                marginaliaIndex: &marginaliaIndex,
                context: context,
                cursor: &cursor
            )
        }
        if let receipt = edition.howYouSee {
            drawHowYouSee(receipt, edition: edition, style: style, context: context, cursor: &cursor)
        }

        // The month's conclusion, on its own composted leaf.
        let closing = edition.closing ?? BookForewordWriter.closing(
            monthTitle: edition.monthName,
            pages: [],
            dayCount: edition.dayCount,
            continuity: edition.continuity,
            constellations: edition.constellations,
            theme: edition.theme
        )
        drawClosing(closing, edition: edition, style: style, context: context, cursor: &cursor)

        drawColophon(edition, style: style, context: context, cursor: &cursor)
    }

    // MARK: Physical print (interior + cover wrap for a print-on-demand house)

    /// Renders the edition as a print-ready **interior** PDF at the spec's trim
    /// plus bleed, padded to an even page count at or above the binding minimum.
    /// Returns the final bound page count (needed to size the cover spine).
    @discardableResult
    static func writePrintInterior(
        _ edition: MonthlyEdition,
        spec: PrintSpec = .hardcover6x9,
        to url: URL
    ) throws -> Int {
        let fb = PrintGeometry.fullBleedTrimInches(spec: spec)
        let pageBounds = CGRect(x: 0, y: 0, width: fb.width * PrintSpec.pointsPerInch, height: fb.height * PrintSpec.pointsPerInch)
        let style = EditionStyle.style(for: edition)
        let m = spec.interiorMarginsPoints
        let margins = UIEdgeInsets(top: m.top, left: m.left, bottom: m.bottom, right: m.right)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let data = renderer.pdfData { context in
            renderInterior(
                edition,
                into: context,
                style: style,
                pageBounds: pageBounds,
                margins: margins,
                designSize: CGSize(width: 612, height: 792)
            )
        }

        guard let document = PDFDocument(data: data) else {
            throw NSError(domain: "Bindery", code: 1, userInfo: [NSLocalizedDescriptionKey: "The interior would not render."])
        }
        let rawCount = document.pageCount
        let target = PrintGeometry.boundPageCount(rawPages: rawCount, spec: spec)
        if target > rawCount {
            for _ in 0..<(target - rawCount) {
                if let blank = blankEndpaper(size: pageBounds.size, style: style) {
                    document.insert(blank, at: document.pageCount)
                }
            }
        }
        guard document.write(to: url) else {
            throw NSError(domain: "Bindery", code: 2, userInfo: [NSLocalizedDescriptionKey: "The interior would not save."])
        }
        return target
    }

    /// Renders the **cover wrap**: one canvas holding back panel, spine, and
    /// front panel, sized from the final page count. A faithful draft — the
    /// authoritative dimensions come from the print partner's template for this
    /// exact page count at order time.
    static func writeCoverWrap(
        _ edition: MonthlyEdition,
        spec: PrintSpec = .hardcover6x9,
        pageCount: Int,
        to url: URL
    ) throws {
        let wrap = PrintGeometry.coverWrapSizeInches(pageCount: pageCount, spec: spec)
        let pageBounds = CGRect(x: 0, y: 0, width: wrap.width * PrintSpec.pointsPerInch, height: wrap.height * PrintSpec.pointsPerInch)
        let style = EditionStyle.style(for: edition)
        let panels = PrintGeometry.coverPanelsInches(pageCount: pageCount, spec: spec)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let ppi = PrintSpec.pointsPerInch

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            guard let cg = UIGraphicsGetCurrentContext() else { return }
            drawVerticalWash(in: pageBounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

            let topY = panels.panelTopY * ppi
            let tw = spec.trimWidthPoints, th = spec.trimHeightPoints
            let backRect = CGRect(x: panels.backX * ppi, y: topY, width: tw, height: th)
            let spineRect = CGRect(x: panels.spineX * ppi, y: topY, width: panels.spineWidth * ppi, height: th)
            let frontRect = CGRect(x: panels.frontX * ppi, y: topY, width: tw, height: th)

            drawPhysicalCoverPanels(edition, spec: spec, style: style, backRect: backRect, spineRect: spineRect, frontRect: frontRect)
        }
    }

    /// Small raster preview of the physical cover treatment: back, spine, front.
    /// This deliberately uses the same panel drawing as the PDF cover wrap.
    static func physicalCoverPreviewImage(
        _ edition: MonthlyEdition,
        spec: PrintSpec,
        pageCount: Int,
        size: CGSize = CGSize(width: 760, height: 420)
    ) -> UIImage {
        let style = EditionStyle.style(for: edition)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

            let pageAspect = spec.trimWidthInches / spec.trimHeightInches
            let panelHeight = size.height * 0.78
            let panelWidth = panelHeight * pageAspect
            let spineWidth = max(10, panelWidth * PrintGeometry.spineWidthInches(pageCount: pageCount, spec: spec) / spec.trimWidthInches)
            let totalWidth = panelWidth * 2 + spineWidth
            let startX = (size.width - totalWidth) / 2
            let topY = (size.height - panelHeight) / 2
            let backRect = CGRect(x: startX, y: topY, width: panelWidth, height: panelHeight)
            let spineRect = CGRect(x: backRect.maxX, y: topY, width: spineWidth, height: panelHeight)
            let frontRect = CGRect(x: spineRect.maxX, y: topY, width: panelWidth, height: panelHeight)

            cg.setShadow(offset: CGSize(width: 0, height: 10), blur: 18, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            drawPhysicalCoverPanels(edition, spec: spec, style: style, backRect: backRect, spineRect: spineRect, frontRect: frontRect)
            cg.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.black.withAlphaComponent(0.22).setStroke()
            UIBezierPath(rect: CGRect(x: backRect.minX, y: backRect.minY, width: totalWidth, height: panelHeight)).stroke()
        }
    }

    private static func drawPhysicalCoverPanels(
        _ edition: MonthlyEdition,
        spec: PrintSpec,
        style: EditionStyle,
        backRect: CGRect,
        spineRect: CGRect,
        frontRect: CGRect
    ) {
        switch spec.coverTreatment {
        case .caseWrap:
            withDesignSpaceMapped(designSize: CGSize(width: 612, height: 792), into: frontRect) {
                drawCover(edition, style: style, bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
            }
            drawCoverBackPanel(edition, style: style, rect: backRect)
            if spineRect.width >= 10 {
                drawSpineTitle(edition, style: style, rect: spineRect)
            }
        case .linenWrap:
            drawLinenPanel(in: backRect)
            drawLinenPanel(in: spineRect)
            drawLinenPanel(in: frontRect)
            drawFoilFrontStamp(edition, rect: frontRect)
            drawFoilBackStamp(edition, rect: backRect)
            if spineRect.width >= 10 {
                drawSpineTitle(edition, style: linenFoilStyle(), rect: spineRect)
            }
        }
    }

    /// Maps a fixed design space (612×792) onto the whole page, scaling to fill.
    /// Identity when the page already is the design size (the screen export), so
    /// the screen path is byte-for-byte unchanged.
    private static func withDesignSpace(designSize: CGSize, pageBounds: CGRect, _ body: () -> Void) {
        if abs(designSize.width - pageBounds.width) < 0.5, abs(designSize.height - pageBounds.height) < 0.5 {
            body()
            return
        }
        withDesignSpaceMapped(designSize: designSize, into: pageBounds, body)
    }

    /// Scales and centers a design-space drawing to fill an arbitrary rect.
    private static func withDesignSpaceMapped(designSize: CGSize, into rect: CGRect, _ body: () -> Void) {
        guard let cg = UIGraphicsGetCurrentContext() else { body(); return }
        cg.saveGState()
        cg.clip(to: rect)
        let scale = max(rect.width / designSize.width, rect.height / designSize.height)
        let scaledWidth = designSize.width * scale
        let scaledHeight = designSize.height * scale
        cg.translateBy(x: rect.minX + (rect.width - scaledWidth) / 2, y: rect.minY + (rect.height - scaledHeight) / 2)
        cg.scaleBy(x: scale, y: scale)
        body()
        cg.restoreGState()
    }

    /// A blank leaf in the edition's paper, used to pad the block to an even,
    /// at-or-above-minimum page count so the spine math holds and the binding
    /// has endpapers.
    private static func blankEndpaper(size: CGSize, style: EditionStyle) -> PDFPage? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        let data = renderer.pdfData { context in
            context.beginPage()
            if let cg = UIGraphicsGetCurrentContext() {
                drawVerticalWash(in: CGRect(origin: .zero, size: size), top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)
            }
        }
        return PDFDocument(data: data)?.page(at: 0)
    }

    private static func linenFoilStyle() -> EditionStyle {
        let palette = EditionStyle.Palette(
            name: "navy linen",
            paperTop: UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1),
            paperBottom: UIColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1),
            coverText: UIColor(red: 0.86, green: 0.70, blue: 0.34, alpha: 1),
            ink: UIColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1),
            accent: UIColor(red: 0.07, green: 0.13, blue: 0.25, alpha: 1),
            accentSoft: UIColor(red: 0.07, green: 0.13, blue: 0.25, alpha: 0.18),
            gold: UIColor(red: 0.86, green: 0.70, blue: 0.34, alpha: 1)
        )
        return EditionStyle(palette: palette, coverMotif: .constellation, ornament: .stars)
    }

    private static func drawLinenPanel(in rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let top = UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1)
        let bottom = UIColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1)
        drawVerticalWash(in: rect, top: top, bottom: bottom, cg: cg)

        cg.saveGState()
        cg.clip(to: rect)
        UIColor.white.withAlphaComponent(0.045).setStroke()
        for offset in stride(from: rect.minX - rect.height, through: rect.maxX, by: 8) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: offset, y: rect.minY))
            path.addLine(to: CGPoint(x: offset + rect.height, y: rect.maxY))
            path.lineWidth = 0.7
            path.stroke()
        }
        UIColor.black.withAlphaComponent(0.10).setStroke()
        for x in stride(from: rect.minX, through: rect.maxX, by: 5) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.lineWidth = 0.5
            path.stroke()
        }
        cg.restoreGState()
    }

    private static func drawFoilFrontStamp(_ edition: MonthlyEdition, rect: CGRect) {
        let gold = UIColor(red: 0.86, green: 0.70, blue: 0.34, alpha: 1)
        drawCentered("T H E   B O O K   O F   Y O U", font: .systemFont(ofSize: rect.height * 0.032, weight: .semibold), color: gold.withAlphaComponent(0.86), y: rect.minY + rect.height * 0.34, in: rect)
        drawCentered(edition.readerName, font: .serifFont(ofSize: rect.height * 0.060, weight: .regular), color: gold, y: rect.minY + rect.height * 0.43, in: rect)
        drawCentered("Chapter \(edition.chapterNumber)", font: .serifFont(ofSize: rect.height * 0.088, weight: .bold), color: gold, y: rect.minY + rect.height * 0.54, in: rect)
        drawCentered(edition.monthName, font: .serifItalicFont(ofSize: rect.height * 0.044), color: gold.withAlphaComponent(0.88), y: rect.minY + rect.height * 0.64, in: rect)
    }

    private static func drawFoilBackStamp(_ edition: MonthlyEdition, rect: CGRect) {
        let gold = UIColor(red: 0.86, green: 0.70, blue: 0.34, alpha: 1)
        drawCentered("\(edition.dayCount) days bound", font: .serifItalicFont(ofSize: rect.height * 0.034), color: gold.withAlphaComponent(0.74), y: rect.minY + rect.height * 0.46, in: rect)
        drawCentered("\(edition.pageCount) kept pages", font: .systemFont(ofSize: rect.height * 0.030, weight: .medium), color: gold.withAlphaComponent(0.64), y: rect.minY + rect.height * 0.53, in: rect)
    }

    /// The back of the jacket: a quiet echo of the cover, lower on the panel.
    private static func drawCoverBackPanel(_ edition: MonthlyEdition, style: EditionStyle, rect: CGRect) {
        let text = style.palette.coverText
        drawCentered("T H E   B O O K   O F   Y O U", font: .systemFont(ofSize: 11, weight: .semibold), color: text.withAlphaComponent(0.8), y: rect.minY + rect.height * 0.34, in: rect)
        drawCentered("\(edition.readerName) \u{00B7} Chapter \(edition.chapterNumber)", font: .serifFont(ofSize: 16, weight: .regular), color: text, y: rect.minY + rect.height * 0.40, in: rect)
        drawCentered(edition.monthName, font: .serifItalicFont(ofSize: 13), color: style.palette.gold, y: rect.minY + rect.height * 0.46, in: rect)
        drawCentered("\(edition.dayCount) days bound \u{00B7} \(edition.pageCount) kept pages", font: .systemFont(ofSize: 9, weight: .medium), color: text.withAlphaComponent(0.6), y: rect.minY + rect.height * 0.62, in: rect)
    }

    /// The foil-stamped spine, reading top-to-bottom up the standing book.
    private static func drawSpineTitle(_ edition: MonthlyEdition, style: EditionStyle, rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let title = "THE BOOK OF YOU   \u{00B7}   \(edition.readerName)   \u{00B7}   Chapter \(edition.chapterNumber)   \u{00B7}   \(edition.monthName)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.serifFont(ofSize: min(rect.width * 0.42, 13), weight: .semibold),
            .foregroundColor: style.palette.gold,
            .kern: 1.5
        ]
        let attributed = NSAttributedString(string: title, attributes: attributes)
        let textSize = attributed.size()
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: .pi / 2)  // reads top-to-bottom on a shelved book
        attributed.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2))
        cg.restoreGState()
    }

    // MARK: Annual (the whole year, bound as a book of chapters)

    static func writeAnnual(_ annual: AnnualEdition, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margins = UIEdgeInsets(top: 60, left: 120, bottom: 64, right: 58)
        let annualStyle = annualStyle(for: annual)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            var cursor = PDFCursor(bounds: pageBounds, margins: margins)
            cursor.seed = "annual-\(annual.year)"

            // Grand cover.
            context.beginPage()
            drawAnnualCover(annual, style: annualStyle, bounds: pageBounds)

            // The year's foreword, in the Book's voice.
            if !annual.foreword.isEmpty {
                beginComposedPage(context, style: annualStyle, cursor: &cursor)
                drawAnnualForeword(annual, style: annualStyle, context: context, cursor: &cursor)
            }

            // The table of the year: every chapter and its theme.
            beginComposedPage(context, style: annualStyle, cursor: &cursor)
            drawAnnualContents(annual, style: annualStyle, cursor: &cursor)

            // Each month-chapter, bound in its own style.
            for chapter in annual.chapters {
                let chapterStyle = EditionStyle.style(for: chapter)
                let marginalia = marginaliaLines(for: chapter)
                var marginaliaIndex = 0
                cursor.seed = "annual-\(annual.year)-\(chapter.monthName)"

                context.beginPage()
                drawChapterDivider(chapter, style: chapterStyle, bounds: pageBounds)

                if !chapter.foreword.isEmpty {
                    beginComposedPage(context, style: chapterStyle, cursor: &cursor)
                    drawForeword(chapter, style: chapterStyle, context: context, cursor: &cursor)
                }

                if let bindingStory = chapter.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                    beginComposedPage(context, style: chapterStyle, cursor: &cursor)
                    drawBindingStory(bindingStory, edition: chapter, style: chapterStyle, context: context, cursor: &cursor)
                }

                let alive = chapter.constellations.filter(\.isAlive)
                if !alive.isEmpty {
                    context.beginPage()
                    drawStarChart(alive, edition: chapter, style: chapterStyle, bounds: pageBounds)
                }

                for section in chapter.sections where section.id != "the-months-theme" {
                    drawSection(
                        section,
                        style: chapterStyle,
                        marginalia: marginalia,
                        marginaliaIndex: &marginaliaIndex,
                        context: context,
                        cursor: &cursor
                    )
                }
            }

            // Back matter: the threads named across the whole year.
            let named = annual.namedConstellations
            if !named.isEmpty {
                context.beginPage()
                drawAnnualStarChart(named, annual: annual, style: annualStyle, bounds: pageBounds)
            }

            // Back matter: the Book's memory spine for the year.
            if let memorySpine = annual.memorySpine, !memorySpine.isEmpty {
                drawAnnualMemorySpine(memorySpine, annual: annual, style: annualStyle, context: context, cursor: &cursor)
            }

            // The closing.
            drawAnnualColophon(annual, style: annualStyle, context: context, cursor: &cursor)
        }
    }

    private static func annualStyle(for annual: AnnualEdition) -> EditionStyle {
        let seed = "annual-\(annual.year)"
        let palette = EditionStyle.palettes[ConstellationKeeper.stableIndex(for: "\(seed)-palette", count: EditionStyle.palettes.count)]
        let ornament = EditionStyle.Ornament.allCases[ConstellationKeeper.stableIndex(for: "\(seed)-ornament", count: EditionStyle.Ornament.allCases.count)]
        // The annual always wears its stars on the cover.
        return EditionStyle(palette: palette, coverMotif: .constellation, ornament: ornament)
    }

    private static func drawAnnualCover(_ annual: AnnualEdition, style: EditionStyle, bounds: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

        let illustrationFrame = CGRect(x: bounds.midX - 140, y: 96, width: 280, height: 200)
        drawConstellationMotif(
            in: illustrationFrame,
            constellations: annual.constellations.filter(\.isAlive),
            seed: "annual-\(annual.year)",
            stroke: style.palette.gold,
            glow: style.palette.coverText,
            labeled: false
        )

        drawOrnamentRow(style, centerY: 320, in: bounds, color: style.palette.gold)

        let text = style.palette.coverText
        drawCentered("T H E   B O O K   O F   Y O U", font: .systemFont(ofSize: 13, weight: .semibold), color: text.withAlphaComponent(0.85), y: 348, in: bounds)
        drawCentered(annual.readerName, font: .serifFont(ofSize: 24, weight: .regular), color: text, y: 374, in: bounds)
        drawCentered("The \(annual.year) Annual", font: .serifFont(ofSize: 40, weight: .bold), color: text, y: 416, in: bounds)
        let chapterWord = annual.chapters.count == 1 ? "in one chapter" : "in \(annual.chapters.count) chapters"
        drawCentered("a year, bound \(chapterWord)", font: .serifItalicFont(ofSize: 18), color: style.palette.gold, y: 474, in: bounds)

        drawOrnamentRow(style, centerY: 524, in: bounds, color: style.palette.gold)

        drawCentered("\(annual.dayCount) days bound \u{00B7} \(annual.pageCount) kept pages", font: .systemFont(ofSize: 11, weight: .medium), color: text.withAlphaComponent(0.7), y: 700, in: bounds)
        drawCentered("bound in the \(style.palette.name.lowercased()) style", font: .serifItalicFont(ofSize: 10), color: text.withAlphaComponent(0.5), y: 718, in: bounds)
        drawCentered("Made with ReEnchanted \u{00B7} reenchanted.app", font: .systemFont(ofSize: 8.5, weight: .semibold), color: text.withAlphaComponent(0.48), y: 738, in: bounds)
    }

    private static func drawAnnualForeword(
        _ annual: AnnualEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let head = "THE BOOK OF YOU \u{00B7} \(annual.readerName) \u{00B7} THE \(annual.year) ANNUAL"
        let headAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: style.palette.ink.withAlphaComponent(0.45)
        ]
        (head as NSString).draw(at: CGPoint(x: cursor.left, y: 30), withAttributes: headAttributes)

        drawText("Foreword to the Year", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 10)
        drawAccentRule(style, cursor: &cursor)

        let paragraphs = annual.foreword.components(separatedBy: "\n\n")
        for (index, paragraph) in paragraphs.enumerated() {
            ensureSpace(90, style: style, context: context, cursor: &cursor)
            if index == 0, let first = paragraph.first {
                let capital = String(first)
                let capAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.serifFont(ofSize: 44, weight: .bold),
                    .foregroundColor: style.palette.accent
                ]
                let capSize = (capital as NSString).size(withAttributes: capAttributes)
                (capital as NSString).draw(at: CGPoint(x: cursor.left, y: cursor.y - 4), withAttributes: capAttributes)
                drawText(
                    String(paragraph.dropFirst()),
                    font: .serifFont(ofSize: 12, weight: .regular),
                    color: style.palette.ink,
                    cursor: &cursor,
                    spacingAfter: 14,
                    leftInset: capSize.width + 6,
                    firstLineOnlyInsetHeight: capSize.height
                )
            } else {
                drawText(paragraph, font: .serifFont(ofSize: 12, weight: .regular), color: style.palette.ink, cursor: &cursor, spacingAfter: 14)
            }
        }
        drawOrnamentRow(style, centerY: cursor.y + 14, in: cursor.bounds, color: style.palette.accent)
        cursor.y += 36
    }

    private static func drawAnnualContents(_ annual: AnnualEdition, style: EditionStyle, cursor: inout PDFCursor) {
        drawText("The Year in \(annual.chapters.count == 1 ? "One Chapter" : "\(spelledOut(annual.chapters.count)) Chapters")",
                 font: .serifFont(ofSize: 22, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 6)
        drawAccentRule(style, cursor: &cursor)
        for chapter in annual.chapters {
            let title = "Chapter \(chapter.chapterNumber) \u{00B7} \(chapter.monthName)"
            drawText(title, font: .systemFont(ofSize: 13, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
            let note = (chapter.theme?.name).map { "\u{201C}\($0)\u{201D} \u{00B7} \(chapter.pageCount) pages" } ?? "\(chapter.pageCount) pages"
            drawText(note, font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 10)
        }
    }

    private static func drawChapterDivider(_ chapter: MonthlyEdition, style: EditionStyle, bounds: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)
        let text = style.palette.coverText

        drawCentered("CHAPTER \(chapter.chapterNumber)", font: .systemFont(ofSize: 13, weight: .semibold), color: text.withAlphaComponent(0.8), y: bounds.midY - 110, in: bounds)
        drawOrnamentRow(style, centerY: bounds.midY - 78, in: bounds, color: style.palette.gold)
        drawCentered(chapter.monthName, font: .serifFont(ofSize: 38, weight: .bold), color: text, y: bounds.midY - 56, in: bounds)
        if let theme = chapter.theme {
            drawCentered("\u{201C}\(theme.name)\u{201D}", font: .serifItalicFont(ofSize: 18), color: style.palette.gold, y: bounds.midY + 2, in: bounds)
            drawCentered(theme.line, font: .serifItalicFont(ofSize: 12), color: text.withAlphaComponent(0.8), y: bounds.midY + 34, in: bounds)
        }
        drawOrnamentRow(style, centerY: bounds.midY + 84, in: bounds, color: style.palette.gold)
        drawCentered("\(chapter.dayCount) days \u{00B7} \(chapter.pageCount) kept pages", font: .systemFont(ofSize: 11, weight: .medium), color: text.withAlphaComponent(0.65), y: bounds.midY + 110, in: bounds)
    }

    private static func drawAnnualStarChart(_ constellations: [Constellation], annual: AnnualEdition, style: EditionStyle, bounds: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

        drawCentered("The Year's Constellations", font: .serifFont(ofSize: 26, weight: .bold), color: style.palette.coverText, y: 64, in: bounds)
        drawCentered("Threads the Book named across all twelve windows of \(annual.year).", font: .serifItalicFont(ofSize: 12), color: style.palette.coverText.withAlphaComponent(0.75), y: 98, in: bounds)

        let chartFrame = CGRect(x: 70, y: 130, width: bounds.width - 140, height: 430)
        style.palette.coverText.withAlphaComponent(0.25).setStroke()
        let border = UIBezierPath(roundedRect: chartFrame, cornerRadius: 10)
        border.lineWidth = 1
        border.stroke()
        drawConstellationMotif(
            in: chartFrame.insetBy(dx: 18, dy: 18),
            constellations: constellations,
            seed: "annual-\(annual.year)",
            stroke: style.palette.gold,
            glow: style.palette.coverText,
            labeled: true
        )

        var y: CGFloat = chartFrame.maxY + 26
        for constellation in constellations.prefix(6) {
            let line = "\(constellation.displayName) \u{00B7} a recurring shape the Book has begun to recognize"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.serifFont(ofSize: 11, weight: .regular),
                .foregroundColor: style.palette.coverText.withAlphaComponent(0.85)
            ]
            drawStar(at: CGPoint(x: 86, y: y + 5), radius: constellation.isNamed ? 3 : 2.2, color: style.palette.gold)
            (line as NSString).draw(at: CGPoint(x: 100, y: y - 2), withAttributes: attributes)
            y += 22
        }
    }

    private static func drawAnnualMemorySpine(
        _ memorySpine: AnnualMemorySpine,
        annual: AnnualEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        let head = "THE BOOK OF YOU \u{00B7} \(annual.readerName) \u{00B7} THE \(annual.year) ANNUAL"
        let headAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: style.palette.ink.withAlphaComponent(0.45)
        ]
        (head as NSString).draw(at: CGPoint(x: cursor.left, y: 30), withAttributes: headAttributes)

        drawText("Book Memory Spine", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 6)
        drawText(
            "The nightly Book of You pages, read again as a year of callbacks, refrains, cover stories, and questions still warm.",
            font: .serifItalicFont(ofSize: 10.5),
            color: style.palette.ink.withAlphaComponent(0.65),
            cursor: &cursor,
            spacingAfter: 12
        )
        drawAccentRule(style, cursor: &cursor)

        drawAnnualMemoryList(
            title: "What Kept Returning",
            lines: memorySpine.motifs,
            style: style,
            context: context,
            cursor: &cursor
        )
        drawAnnualMemoryList(
            title: "Cover Stories",
            lines: memorySpine.coverStories,
            style: style,
            context: context,
            cursor: &cursor
        )
        drawAnnualMemoryList(
            title: "Pages That Answered Back",
            lines: memorySpine.callbacks,
            style: style,
            context: context,
            cursor: &cursor
        )
        drawAnnualMemoryList(
            title: "Questions Still Warm",
            lines: memorySpine.openQuestions,
            style: style,
            context: context,
            cursor: &cursor
        )

        drawOrnamentRow(style, centerY: cursor.y + 18, in: cursor.bounds, color: style.palette.accent)
    }

    private static func drawAnnualMemoryList(
        title: String,
        lines: [String],
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !lines.isEmpty else { return }
        ensureSpace(70, style: style, context: context, cursor: &cursor)
        drawText(title, font: .systemFont(ofSize: 12, weight: .bold), color: style.palette.accent, cursor: &cursor, spacingAfter: 7)
        for line in lines.prefix(8) {
            ensureSpace(42, style: style, context: context, cursor: &cursor)
            drawText(
                line,
                font: .serifFont(ofSize: 10.5, weight: .regular),
                color: style.palette.ink.withAlphaComponent(0.90),
                cursor: &cursor,
                spacingAfter: 7
            )
        }
        cursor.y += 8
    }

    private static func drawAnnualColophon(
        _ annual: AnnualEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        cursor.y = 96
        drawText(annual.closing, font: .serifItalicFont(ofSize: 13), color: style.palette.ink.withAlphaComponent(0.85), cursor: &cursor, spacingAfter: 30)

        cursor.y = cursor.bounds.midY + 40
        drawOrnamentRow(style, centerY: cursor.y, in: cursor.bounds, color: style.palette.accent)
        cursor.y += 26
        drawCentered("The Book of You \u{00B7} \(annual.readerName) \u{00B7} The \(annual.year) Annual", font: .serifItalicFont(ofSize: 12), color: style.palette.ink.withAlphaComponent(0.8), y: cursor.y, in: cursor.bounds)
        cursor.y += 22
        drawCentered("Bound by the Book itself, which read every page twice, and the year once more.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.55), y: cursor.y, in: cursor.bounds)
        cursor.y += 20
        drawCentered("Made with ReEnchanted \u{00B7} reenchanted.app", font: .systemFont(ofSize: 8.5, weight: .semibold), color: style.palette.ink.withAlphaComponent(0.48), y: cursor.y, in: cursor.bounds)
    }

    private static func spelledOut(_ n: Int) -> String {
        let words = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]
        return (0...12).contains(n) ? words[n] : "\(n)"
    }

    // MARK: Cover

    private static func drawCover(_ edition: MonthlyEdition, style: EditionStyle, bounds: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

        // Header illustration: the month's motif, drawn fresh each binding.
        let illustrationFrame = CGRect(x: bounds.midX - 130, y: 92, width: 260, height: 190)
        drawCoverMotif(style.coverMotif, in: illustrationFrame, edition: edition, style: style, cg: cg)

        drawOrnamentRow(style, centerY: 312, in: bounds, color: style.palette.gold)

        let text = style.palette.coverText
        drawCentered(
            "T H E   B O O K   O F   Y O U",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: text.withAlphaComponent(0.85),
            y: 340,
            in: bounds
        )
        drawCentered(
            edition.readerName,
            font: .serifFont(ofSize: 24, weight: .regular),
            color: text,
            y: 366,
            in: bounds
        )
        drawCentered(
            "Chapter \(edition.chapterNumber)",
            font: .serifFont(ofSize: 40, weight: .bold),
            color: text,
            y: 410,
            in: bounds
        )
        drawCentered(
            edition.monthName,
            font: .serifFont(ofSize: 20, weight: .regular),
            color: text.withAlphaComponent(0.9),
            y: 462,
            in: bounds
        )
        if edition.isThinBinding {
            drawCentered(
                "A First Binding",
                font: .serifItalicFont(ofSize: 15),
                color: text.withAlphaComponent(0.78),
                y: 486,
                in: bounds
            )
        }
        if let theme = edition.theme {
            drawCentered(
                "\u{201C}\(theme.name)\u{201D}",
                font: .serifItalicFont(ofSize: 18),
                color: style.palette.gold,
                y: edition.isThinBinding ? 516 : 498,
                in: bounds
            )
        }

        drawOrnamentRow(style, centerY: 548, in: bounds, color: style.palette.gold)

        drawCentered(
            "\(edition.dayCount) days bound \u{00B7} \(edition.pageCount) kept pages",
            font: .systemFont(ofSize: 11, weight: .medium),
            color: text.withAlphaComponent(0.7),
            y: 700,
            in: bounds
        )
        drawCentered(
            "bound in the \(style.palette.name.lowercased()) style",
            font: .serifItalicFont(ofSize: 10),
            color: text.withAlphaComponent(0.5),
            y: 718,
            in: bounds
        )
        drawCentered(
            "Made with ReEnchanted \u{00B7} reenchanted.app",
            font: .systemFont(ofSize: 8.5, weight: .semibold),
            color: text.withAlphaComponent(0.48),
            y: 738,
            in: bounds
        )
    }

    private static func drawCoverMotif(
        _ motif: EditionStyle.CoverMotif,
        in frame: CGRect,
        edition: MonthlyEdition,
        style: EditionStyle,
        cg: CGContext
    ) {
        let stroke = style.palette.gold
        let glow = style.palette.coverText
        let seed = BookThemeEngine.monthKey(for: edition.startDate)

        switch motif {
        case .constellation:
            drawConstellationMotif(in: frame, constellations: edition.constellations.filter(\.isAlive), seed: seed, stroke: stroke, glow: glow, labeled: false)
        case .moonAndWaves:
            // Moon
            let moon = CGRect(x: frame.midX - 36, y: frame.minY + 8, width: 72, height: 72)
            glow.withAlphaComponent(0.92).setFill()
            UIBezierPath(ovalIn: moon).fill()
            style.palette.paperTop.withAlphaComponent(0.35).setFill()
            UIBezierPath(ovalIn: moon.offsetBy(dx: -14, dy: -6).insetBy(dx: 6, dy: 6)).fill()
            // Waves
            stroke.setStroke()
            for row in 0..<4 {
                let y = frame.minY + 110 + CGFloat(row) * 18
                let path = UIBezierPath()
                path.lineWidth = 1.4
                var x = frame.minX + CGFloat((row % 2) * 9)
                path.move(to: CGPoint(x: x, y: y))
                while x < frame.maxX - 16 {
                    path.addQuadCurve(to: CGPoint(x: x + 18, y: y), controlPoint: CGPoint(x: x + 9, y: y - 8))
                    x += 18
                }
                path.stroke()
            }
        case .lamp:
            stroke.setStroke()
            glow.withAlphaComponent(0.16).setFill()
            UIBezierPath(ovalIn: CGRect(x: frame.midX - 56, y: frame.minY + 18, width: 112, height: 112)).fill()
            glow.withAlphaComponent(0.92).setFill()
            // flame
            let flame = UIBezierPath()
            flame.move(to: CGPoint(x: frame.midX, y: frame.minY + 44))
            flame.addQuadCurve(to: CGPoint(x: frame.midX + 11, y: frame.minY + 76), controlPoint: CGPoint(x: frame.midX + 15, y: frame.minY + 56))
            flame.addQuadCurve(to: CGPoint(x: frame.midX, y: frame.minY + 88), controlPoint: CGPoint(x: frame.midX + 4, y: frame.minY + 88))
            flame.addQuadCurve(to: CGPoint(x: frame.midX - 11, y: frame.minY + 76), controlPoint: CGPoint(x: frame.midX - 4, y: frame.minY + 88))
            flame.addQuadCurve(to: CGPoint(x: frame.midX, y: frame.minY + 44), controlPoint: CGPoint(x: frame.midX - 15, y: frame.minY + 56))
            flame.fill()
            // lamp body
            let body = UIBezierPath(roundedRect: CGRect(x: frame.midX - 26, y: frame.minY + 96, width: 52, height: 14), cornerRadius: 4)
            body.lineWidth = 1.6
            body.stroke()
            let base = UIBezierPath()
            base.move(to: CGPoint(x: frame.midX - 36, y: frame.minY + 132))
            base.addLine(to: CGPoint(x: frame.midX + 36, y: frame.minY + 132))
            base.lineWidth = 1.6
            base.stroke()
            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: frame.midX, y: frame.minY + 110))
            stem.addLine(to: CGPoint(x: frame.midX, y: frame.minY + 132))
            stem.lineWidth = 1.6
            stem.stroke()
        case .sprig:
            stroke.setStroke()
            let stem = UIBezierPath()
            stem.move(to: CGPoint(x: frame.midX, y: frame.maxY - 24))
            stem.addQuadCurve(to: CGPoint(x: frame.midX + 8, y: frame.minY + 20), controlPoint: CGPoint(x: frame.midX - 22, y: frame.midY))
            stem.lineWidth = 1.8
            stem.stroke()
            for index in 0..<7 {
                let t = CGFloat(index + 1) / 8
                let y = frame.maxY - 24 - t * (frame.height - 44)
                let x = frame.midX - 22 * sin(t * .pi) + 8 * t
                let direction: CGFloat = index % 2 == 0 ? 1 : -1
                let leaf = UIBezierPath()
                leaf.move(to: CGPoint(x: x, y: y))
                leaf.addQuadCurve(
                    to: CGPoint(x: x + 30 * direction, y: y - 12),
                    controlPoint: CGPoint(x: x + 14 * direction, y: y - 18)
                )
                leaf.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    controlPoint: CGPoint(x: x + 14 * direction, y: y + 2)
                )
                leaf.lineWidth = 1.3
                leaf.stroke()
            }
        case .keyAndDoor:
            stroke.setStroke()
            // Door arch
            let doorWidth: CGFloat = 92
            let door = UIBezierPath()
            let doorLeft = frame.midX - doorWidth / 2
            door.move(to: CGPoint(x: doorLeft, y: frame.maxY - 20))
            door.addLine(to: CGPoint(x: doorLeft, y: frame.minY + 70))
            door.addArc(
                withCenter: CGPoint(x: frame.midX, y: frame.minY + 70),
                radius: doorWidth / 2,
                startAngle: .pi,
                endAngle: 0,
                clockwise: true
            )
            door.addLine(to: CGPoint(x: doorLeft + doorWidth, y: frame.maxY - 20))
            door.lineWidth = 1.8
            door.stroke()
            // Keyhole glow
            glow.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: frame.midX - 7, y: frame.midY - 4, width: 14, height: 14)).fill()
            let slot = UIBezierPath()
            slot.move(to: CGPoint(x: frame.midX - 5, y: frame.midY + 26))
            slot.addLine(to: CGPoint(x: frame.midX, y: frame.midY + 8))
            slot.addLine(to: CGPoint(x: frame.midX + 5, y: frame.midY + 26))
            slot.close()
            slot.fill()
        }
        _ = cg
    }

    private static func drawConstellationMotif(
        in frame: CGRect,
        constellations: [Constellation],
        seed: String,
        stroke: UIColor,
        glow: UIColor,
        labeled: Bool
    ) {
        let shown = Array(constellations.prefix(4))
        guard !shown.isEmpty else {
            // Scattered stars fallback
            for index in 0..<14 {
                let x = frame.minX + CGFloat(ConstellationKeeper.stableIndex(for: "\(seed)-sx\(index)", count: Int(frame.width)))
                let y = frame.minY + CGFloat(ConstellationKeeper.stableIndex(for: "\(seed)-sy\(index)", count: Int(frame.height)))
                drawStar(at: CGPoint(x: x, y: y), radius: 2.2, color: glow)
            }
            return
        }
        for (groupIndex, constellation) in shown.enumerated() {
            let starCount = min(6, max(3, constellation.sightingCount / 2 + 2))
            var points: [CGPoint] = []
            for starIndex in 0..<starCount {
                let key = "\(constellation.id)-star\(starIndex)"
                let x = frame.minX + 12 + CGFloat(ConstellationKeeper.stableIndex(for: "\(key)-x", count: max(1, Int(frame.width) - 24)))
                let y = frame.minY + 12 + CGFloat(ConstellationKeeper.stableIndex(for: "\(key)-y", count: max(1, Int(frame.height) - 24)))
                points.append(CGPoint(x: x, y: y))
            }
            // Connect in seeded order
            let path = UIBezierPath()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            stroke.withAlphaComponent(0.55).setStroke()
            path.lineWidth = 0.8
            path.stroke()
            for point in points {
                drawStar(at: point, radius: constellation.isNamed ? 3.0 : 2.2, color: glow)
            }
            if labeled, let anchor = points.first {
                let label = constellation.displayName
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.serifItalicFont(ofSize: 9),
                    .foregroundColor: glow.withAlphaComponent(0.85)
                ]
                let size = (label as NSString).size(withAttributes: attributes)
                var origin = CGPoint(x: anchor.x + 6, y: anchor.y - size.height - 2)
                origin.x = min(origin.x, frame.maxX - size.width - 2)
                origin.y = max(origin.y, frame.minY + 2)
                (label as NSString).draw(at: origin, withAttributes: attributes)
            }
            _ = groupIndex
        }
    }

    private static func drawStar(at point: CGPoint, radius: CGFloat, color: UIColor) {
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)).fill()
        color.withAlphaComponent(0.35).setFill()
        UIBezierPath(ovalIn: CGRect(x: point.x - radius * 2, y: point.y - radius * 2, width: radius * 4, height: radius * 4)).fill()
    }

    // MARK: Star chart page

    private static func drawStarChart(
        _ constellations: [Constellation],
        edition: MonthlyEdition,
        style: EditionStyle,
        bounds: CGRect
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        drawVerticalWash(in: bounds, top: style.palette.paperTop, bottom: style.palette.paperBottom, cg: cg)

        drawCentered(
            "The Reader's Sky",
            font: .serifFont(ofSize: 26, weight: .bold),
            color: style.palette.coverText,
            y: 64,
            in: bounds
        )
        drawCentered(
            "Constellations the Book keeps about you, as they stood this month.",
            font: .serifItalicFont(ofSize: 12),
            color: style.palette.coverText.withAlphaComponent(0.75),
            y: 98,
            in: bounds
        )

        let chartFrame = CGRect(x: 70, y: 130, width: bounds.width - 140, height: 430)
        style.palette.coverText.withAlphaComponent(0.25).setStroke()
        let border = UIBezierPath(roundedRect: chartFrame, cornerRadius: 10)
        border.lineWidth = 1
        border.stroke()
        drawConstellationMotif(
            in: chartFrame.insetBy(dx: 18, dy: 18),
            constellations: constellations,
            seed: BookThemeEngine.monthKey(for: edition.startDate),
            stroke: style.palette.gold,
            glow: style.palette.coverText,
            labeled: true
        )

        // Legend
        var y: CGFloat = chartFrame.maxY + 26
        for constellation in constellations.prefix(6) {
            let line = "\(constellation.displayName) \u{00B7} a recurring shape the Book has begun to recognize"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.serifFont(ofSize: 11, weight: .regular),
                .foregroundColor: style.palette.coverText.withAlphaComponent(0.85)
            ]
            drawStar(at: CGPoint(x: 86, y: y + 5), radius: constellation.isNamed ? 3 : 2.2, color: style.palette.gold)
            (line as NSString).draw(at: CGPoint(x: 100, y: y - 2), withAttributes: attributes)
            y += 22
        }
    }

    // MARK: Foreword

    private static func drawForeword(
        _ edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        drawRunningHead(edition, style: style, cursor: cursor)
        drawText("Foreword", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 10)
        drawAccentRule(style, cursor: &cursor)

        let paragraphs = edition.foreword.components(separatedBy: "\n\n")
        for (index, paragraph) in paragraphs.enumerated() {
            ensureSpace(90, style: style, context: context, cursor: &cursor)
            if index == 0, let first = paragraph.first {
                // Drop cap on the opening paragraph.
                let capital = String(first)
                let capAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.serifFont(ofSize: 44, weight: .bold),
                    .foregroundColor: style.palette.accent
                ]
                let capSize = (capital as NSString).size(withAttributes: capAttributes)
                (capital as NSString).draw(at: CGPoint(x: cursor.left, y: cursor.y - 4), withAttributes: capAttributes)
                let rest = String(paragraph.dropFirst())
                drawText(
                    rest,
                    font: .serifFont(ofSize: 12, weight: .regular),
                    color: style.palette.ink,
                    cursor: &cursor,
                    spacingAfter: 14,
                    leftInset: capSize.width + 6,
                    firstLineOnlyInsetHeight: capSize.height
                )
            } else {
                drawText(
                    paragraph,
                    font: .serifFont(ofSize: 12, weight: .regular),
                    color: style.palette.ink,
                    cursor: &cursor,
                    spacingAfter: 14
                )
            }
        }
        drawOrnamentRow(style, centerY: cursor.y + 14, in: cursor.bounds, color: style.palette.accent)
        cursor.y += 36
    }

    /// The binding of bindings: Gemma reads the nightly Book of You pages in
    /// sequence and gives the month a single narrative leaf distinct from the
    /// foreword, source braids, and closing.
    private static func drawBindingStory(
        _ story: String,
        edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        drawRunningHead(edition, style: style, cursor: cursor)
        drawText("The Month, Bound", font: .serifFont(ofSize: 24, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 4)
        drawText("A binding of the month's nightly bindings", font: .serifItalicFont(ofSize: 10.5), color: style.palette.ink.withAlphaComponent(0.62), cursor: &cursor, spacingAfter: 10)
        drawAccentRule(style, cursor: &cursor)

        let paragraphs = story
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for (index, paragraph) in paragraphs.enumerated() {
            ensureSpace(90, style: style, context: context, cursor: &cursor)
            if index == 0, let first = paragraph.first {
                let capital = String(first)
                let capAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.serifFont(ofSize: 44, weight: .bold),
                    .foregroundColor: style.palette.accent
                ]
                let capSize = (capital as NSString).size(withAttributes: capAttributes)
                (capital as NSString).draw(at: CGPoint(x: cursor.left, y: cursor.y - 4), withAttributes: capAttributes)
                drawText(
                    String(paragraph.dropFirst()),
                    font: .serifFont(ofSize: 12.5, weight: .regular),
                    color: style.palette.ink,
                    cursor: &cursor,
                    spacingAfter: 16,
                    leftInset: capSize.width + 6,
                    firstLineOnlyInsetHeight: capSize.height
                )
            } else {
                drawText(paragraph, font: .serifFont(ofSize: 12.5, weight: .regular), color: style.palette.ink, cursor: &cursor, spacingAfter: 16)
            }
        }
        drawOrnamentRow(style, centerY: cursor.y + 14, in: cursor.bounds, color: style.palette.gold)
        cursor.y += 36
    }

    // MARK: Theme page

    private static func drawThemePage(
        _ theme: BookTheme,
        edition: MonthlyEdition,
        style: EditionStyle,
        bounds: CGRect,
        cursor: inout PDFCursor
    ) {
        drawRunningHead(edition, style: style, cursor: cursor)
        cursor.y = 130

        drawCentered(
            "The Month's Theme",
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: style.palette.accent,
            y: cursor.y,
            in: bounds
        )
        cursor.y += 30
        drawCentered(
            theme.name,
            font: .serifFont(ofSize: 32, weight: .bold),
            color: style.palette.ink,
            y: cursor.y,
            in: bounds
        )
        cursor.y += 56
        drawOrnamentRow(style, centerY: cursor.y, in: bounds, color: style.palette.gold)
        cursor.y += 30

        drawText(
            theme.line,
            font: .serifItalicFont(ofSize: 14),
            color: style.palette.ink.withAlphaComponent(0.9),
            cursor: &cursor,
            spacingAfter: 26
        )

        for excerpt in theme.excerptLines {
            // Hanging quote bar
            style.palette.accent.setFill()
            UIBezierPath(rect: CGRect(x: cursor.left - 14, y: cursor.y + 2, width: 3, height: 34)).fill()
            drawText(
                "\u{201C}\(excerpt)\u{201D}",
                font: .serifItalicFont(ofSize: 12),
                color: style.palette.ink.withAlphaComponent(0.8),
                cursor: &cursor,
                spacingAfter: 18
            )
        }

        cursor.y += 8
        // Motif chips
        var x = cursor.left
        for motif in theme.motifs {
            let label = motif.capitalized
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: style.palette.accent
            ]
            let size = (label as NSString).size(withAttributes: attributes)
            let chip = CGRect(x: x, y: cursor.y, width: size.width + 18, height: 20)
            style.palette.accentSoft.setFill()
            UIBezierPath(roundedRect: chip, cornerRadius: 10).fill()
            (label as NSString).draw(at: CGPoint(x: x + 9, y: cursor.y + 4), withAttributes: attributes)
            x += chip.width + 8
        }
        cursor.y += 40
    }

    // MARK: Contents and sections

    private static func drawContents(_ edition: MonthlyEdition, style: EditionStyle, cursor: inout PDFCursor) {
        drawRunningHead(edition, style: style, cursor: cursor)
        drawText("Contents", font: .serifFont(ofSize: 22, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 6)
        drawAccentRule(style, cursor: &cursor)
        if edition.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil {
            drawText("The Month, Bound", font: .systemFont(ofSize: 13, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
            drawText("The nightly bindings read as one story.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 10)
        }
        for section in edition.sections {
            drawText(section.title, font: .systemFont(ofSize: 13, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
            drawText(section.note, font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 10)
        }
    }

    private static func drawSection(
        _ section: MonthlyEditionSection,
        style: EditionStyle,
        marginalia: [String],
        marginaliaIndex: inout Int,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)

        // Section opener: the title torn from paper and taped across the leaf.
        let labelTop = cursor.y - 14
        let labelRect = CGRect(x: cursor.left - 16, y: labelTop, width: cursor.contentWidth + 22, height: 66)
        drawTornScrap(
            in: labelRect,
            rotation: -0.012,
            fill: blend(parchment(for: style).top, style.palette.accent, 0.10),
            seed: "\(cursor.pageSeed)-label"
        )
        drawTapeStrip(center: CGPoint(x: labelRect.minX + 26, y: labelRect.minY + 4), length: 54, angle: -0.7, tint: style.palette.gold)
        drawTapeStrip(center: CGPoint(x: labelRect.maxX - 26, y: labelRect.minY + 4), length: 54, angle: 0.7, tint: style.palette.gold)
        style.palette.accent.setFill()
        UIBezierPath(rect: CGRect(x: cursor.left, y: cursor.y - 4, width: 6, height: 48)).fill()
        drawText(section.title, font: .serifFont(ofSize: 22, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
        drawText(section.note, font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.65), cursor: &cursor, spacingAfter: 26)

        for (index, item) in section.items.enumerated() {
            drawItem(
                item,
                style: style,
                showMarginNote: shouldShowMarginalia(in: section, itemIndex: index),
                marginalia: marginalia,
                marginaliaIndex: &marginaliaIndex,
                context: context,
                cursor: &cursor
            )
            if let asset = fullPageMediaAsset(from: item.mediaAssets),
               let image = image(from: asset) {
                drawFullPageMediaLeaf(
                    image,
                    item: item,
                    asset: asset,
                    style: style,
                    context: context,
                    cursor: &cursor
                )
                if index < section.items.count - 1 {
                    beginComposedPage(context, style: style, cursor: &cursor)
                }
            }
        }
    }

    private static func drawHowYouSee(
        _ receipt: HowYouSee.SeeingReceipt,
        edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        drawRunningHead(edition, style: style, cursor: cursor)
        drawText("How You See", font: .serifFont(ofSize: 22, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 6)
        drawAccentRule(style, cursor: &cursor)
        drawText(receipt.earlierMonthName, font: .systemFont(ofSize: 9, weight: .bold), color: style.palette.accent, cursor: &cursor, spacingAfter: 4)
        drawText("“\(receipt.earlierQuote)”", font: .serifItalicFont(ofSize: 14), color: style.palette.ink, cursor: &cursor, spacingAfter: 22)
        drawText("Now", font: .systemFont(ofSize: 9, weight: .bold), color: style.palette.accent, cursor: &cursor, spacingAfter: 4)
        drawText("“\(receipt.recentQuote)”", font: .serifItalicFont(ofSize: 14), color: style.palette.ink, cursor: &cursor, spacingAfter: 24)
        drawText("Same reader. Closer eyes.", font: .serifFont(ofSize: 12, weight: .regular), color: style.palette.ink, cursor: &cursor, spacingAfter: 8)
    }

    private static func shouldShowMarginalia(in section: MonthlyEditionSection, itemIndex: Int) -> Bool {
        switch section.id {
        case "the-book-notices", "letters", "other-kept-pages":
            return false
        default:
            return itemIndex % 4 == 2
        }
    }

    private static func drawItem(
        _ item: MonthlyEditionItem,
        style: EditionStyle,
        showMarginNote: Bool,
        marginalia: [String],
        marginaliaIndex: inout Int,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let pageCapacity = cursor.bottom - cursor.margins.top
        ensureSpace(min(estimatedItemHeight(item, cursor: cursor), pageCapacity), style: style, context: context, cursor: &cursor)
        let itemTop = cursor.y

        // Date chip in the margin column.
        if let date = item.date {
            let chip = shortDate(date)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: style.palette.accent
            ]
            (chip as NSString).draw(at: CGPoint(x: 36, y: cursor.y + 1), withAttributes: attributes)
        }

        drawText(item.title, font: .systemFont(ofSize: 12, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 4)
        let inlineAssets = inlineMediaAssets(from: item.mediaAssets)
        if item.kind == .image, let image = firstImage(from: inlineAssets) {
            drawFramedImage(image, style: style, context: context, cursor: &cursor)
            if let caption = inlineAssets.first?.caption, !caption.isEmpty {
                drawText(caption, font: .serifItalicFont(ofSize: 9), color: style.palette.ink.withAlphaComponent(0.6), cursor: &cursor, spacingAfter: 6)
            }
        }
        drawText(
            item.body,
            font: .serifFont(ofSize: 11, weight: .regular),
            color: style.palette.ink.withAlphaComponent(0.92),
            cursor: &cursor,
            spacingAfter: 6
        )

        // Marginalia: the Book annotating its own binding.
        if showMarginNote, !marginalia.isEmpty {
            let note = marginalia[marginaliaIndex % marginalia.count]
            let noteSeed = "\(cursor.pageSeed)-margin\(marginaliaIndex)"
            marginaliaIndex += 1
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 1
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.serifItalicFont(ofSize: 8),
                .foregroundColor: style.palette.ink.withAlphaComponent(0.82),
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(x: 30, y: itemTop + 20, width: 72, height: 120)
            let measured = (note as NSString).boundingRect(
                with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: attributes, context: nil
            )
            // A torn scrap of note paper, taped into the gutter at a slight tilt.
            let scrap = CGRect(x: 22, y: itemTop + 12, width: 88, height: min(120, measured.height + 18))
            drawTornScrap(
                in: scrap,
                rotation: (frac("\(noteSeed)-rot") - 0.5) * 0.18,
                fill: blend(parchment(for: style).top, style.palette.gold, 0.12),
                seed: noteSeed
            )
            drawTapeStrip(center: CGPoint(x: scrap.midX, y: scrap.minY + 2), length: 40, angle: (frac("\(noteSeed)-tape") - 0.5) * 0.5, tint: style.palette.gold)
            (note as NSString).draw(in: textRect, withAttributes: attributes)
        }

        // Hairline between items
        style.palette.ink.withAlphaComponent(0.12).setStroke()
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: cursor.left, y: cursor.y + 2))
        rule.addLine(to: CGPoint(x: cursor.left + 120, y: cursor.y + 2))
        rule.lineWidth = 0.5
        rule.stroke()
        cursor.y += 14
    }

    private static func estimatedItemHeight(_ item: MonthlyEditionItem, cursor: PDFCursor) -> CGFloat {
        var height: CGFloat = 0
        height += measuredTextHeight(
            item.title,
            font: .systemFont(ofSize: 12, weight: .bold),
            width: cursor.contentWidth
        ) + 4
        let inlineAssets = inlineMediaAssets(from: item.mediaAssets)
        if item.kind == .image, !inlineAssets.isEmpty {
            height += 246
            if let caption = inlineAssets.first?.caption, !caption.isEmpty {
                height += measuredTextHeight(caption, font: .serifItalicFont(ofSize: 9), width: cursor.contentWidth) + 6
            }
        }
        height += measuredTextHeight(
            item.body,
            font: .serifFont(ofSize: 11, weight: .regular),
            width: cursor.contentWidth
        ) + 6
        return height + 22
    }

    /// The month's conclusion - the Book's last word, set on a composted leaf
    /// with a torn-paper headpiece taped above the prose.
    private static func drawClosing(
        _ closing: String,
        edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        drawRunningHead(edition, style: style, cursor: cursor)
        cursor.y = 96

        // A torn label that reads "In Closing", taped at a tilt.
        let labelRect = CGRect(x: cursor.left - 8, y: cursor.y, width: 188, height: 40)
        drawTornScrap(
            in: labelRect,
            rotation: -0.03,
            fill: blend(parchment(for: style).top, style.palette.accent, 0.12),
            seed: "\(cursor.pageSeed)-closinglabel"
        )
        drawTapeStrip(center: CGPoint(x: labelRect.minX + 24, y: labelRect.minY + 2), length: 48, angle: -0.6, tint: style.palette.gold)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.serifFont(ofSize: 20, weight: .bold),
            .foregroundColor: style.palette.ink
        ]
        ("In Closing" as NSString).draw(at: CGPoint(x: cursor.left + 8, y: cursor.y + 8), withAttributes: labelAttrs)
        cursor.y += 56
        drawAccentRule(style, cursor: &cursor)

        let paragraphs = closing.components(separatedBy: "\n\n")
        for (index, paragraph) in paragraphs.enumerated() {
            ensureSpace(80, style: style, context: context, cursor: &cursor)
            // The signed last line ("- The Book") sits apart, in italic.
            if index == paragraphs.count - 1, paragraph.contains("- The Book") {
                let body = paragraph.replacingOccurrences(of: " - The Book", with: "")
                drawText(body, font: .serifFont(ofSize: 12, weight: .regular), color: style.palette.ink, cursor: &cursor, spacingAfter: 18)
                drawText("\u{2014} The Book", font: .serifItalicFont(ofSize: 13), color: style.palette.accent, cursor: &cursor, spacingAfter: 8)
            } else {
                drawText(paragraph, font: .serifFont(ofSize: 12, weight: .regular), color: style.palette.ink, cursor: &cursor, spacingAfter: 14)
            }
        }
        drawOrnamentRow(style, centerY: cursor.y + 16, in: cursor.bounds, color: style.palette.accent)
    }

    private static func drawColophon(
        _ edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        beginComposedPage(context, style: style, cursor: &cursor)
        cursor.y = cursor.bounds.midY - 60
        drawOrnamentRow(style, centerY: cursor.y, in: cursor.bounds, color: style.palette.accent)
        cursor.y += 26
        drawCentered(
            edition.chapterHeading,
            font: .serifItalicFont(ofSize: 12),
            color: style.palette.ink.withAlphaComponent(0.8),
            y: cursor.y,
            in: cursor.bounds
        )
        cursor.y += 22
        drawCentered(
            "Bound by the Book itself, which read every page twice.",
            font: .serifItalicFont(ofSize: 10),
            color: style.palette.ink.withAlphaComponent(0.55),
            y: cursor.y,
            in: cursor.bounds
        )
        cursor.y += 20
        drawCentered(
            "Made with ReEnchanted \u{00B7} reenchanted.app",
            font: .systemFont(ofSize: 8.5, weight: .semibold),
            color: style.palette.ink.withAlphaComponent(0.48),
            y: cursor.y,
            in: cursor.bounds
        )
    }

    // MARK: Marginalia material

    private static func marginaliaLines(for edition: MonthlyEdition) -> [String] {
        var lines: [String] = []
        for signal in edition.continuity.strongestSignals.prefix(8) {
            lines.append(signal.line)
        }
        for constellation in edition.constellations.filter(\.isNamed).prefix(4) {
            lines.append("\(constellation.displayName) was watching this part of the month.")
        }
        if let theme = edition.theme {
            for motif in theme.motifs {
                lines.append("\(motif.capitalized) again. The theme insists.")
            }
        }
        return lines
    }

    // MARK: - Composted parchment (the ReEnchanted visual refresh)
    //
    // Every reading page is laid down as a composted leaf: a tinted parchment
    // base, paper grain and a stain or two, then a few torn fragments held with
    // strips of tape in the margins. It is all deterministic - the same edition
    // composts the same way each binding - and stays clear of the text column so
    // the page still reads cleanly.

    /// A stable fraction in 0...1 for a seed - the building block of the
    /// deterministic compost (positions, rotations, sizes).
    fileprivate static func frac(_ seed: String) -> CGFloat {
        CGFloat(ConstellationKeeper.stableIndex(for: seed, count: 1000)) / 1000.0
    }

    /// Linear blend between two colors, used to tint the cream parchment toward
    /// the month's palette so the paper itself carries the binding.
    fileprivate static func blend(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            alpha: aa + (ba - aa) * t
        )
    }

    /// The warm paper the reading pages are composted onto, tinted a touch
    /// toward the month's accent so no two bindings sit on identical stock.
    fileprivate static func parchment(for style: EditionStyle) -> (top: UIColor, bottom: UIColor, fiber: UIColor, stain: UIColor) {
        let creamTop = UIColor(red: 0.965, green: 0.945, blue: 0.890, alpha: 1)
        let creamBottom = UIColor(red: 0.930, green: 0.900, blue: 0.832, alpha: 1)
        return (
            top: blend(creamTop, style.palette.accent, 0.05),
            bottom: blend(creamBottom, style.palette.accent, 0.08),
            fiber: blend(UIColor(red: 0.62, green: 0.55, blue: 0.42, alpha: 1), style.palette.accent, 0.2),
            stain: blend(UIColor(red: 0.55, green: 0.42, blue: 0.26, alpha: 1), style.palette.accent, 0.3)
        )
    }

    /// Begins a fresh reading page and composts it. Use for every interior text
    /// page; the dark cover/star-chart/divider plates keep their own wash.
    private static func beginComposedPage(
        _ context: UIGraphicsPDFRendererContext,
        style: EditionStyle,
        cursor: inout PDFCursor
    ) {
        context.beginPage()
        cursor.reset()
        cursor.pageIndex += 1
        drawComposedBackground(style: style, seed: cursor.pageSeed, in: cursor.bounds)
    }

    fileprivate static func drawComposedBackground(style: EditionStyle, seed: String, in bounds: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let paper = parchment(for: style)

        // Parchment base wash.
        drawVerticalWash(in: bounds, top: paper.top, bottom: paper.bottom, cg: cg)

        // Foxing: a couple of broad, very faint stains drifting in from the edges.
        for index in 0..<3 {
            let cx = frac("\(seed)-stainx\(index)") * bounds.width
            let cy = frac("\(seed)-stainy\(index)") * bounds.height
            let r = 60 + frac("\(seed)-stainr\(index)") * 90
            let blot = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            paper.stain.withAlphaComponent(0.035).setFill()
            UIBezierPath(ovalIn: blot).fill()
        }

        // Paper grain: fine fibres scattered across the leaf.
        for index in 0..<150 {
            let x = frac("\(seed)-fx\(index)") * bounds.width
            let y = frac("\(seed)-fy\(index)") * bounds.height
            let len = 1 + frac("\(seed)-fl\(index)") * 3
            paper.fiber.withAlphaComponent(0.05 + frac("\(seed)-fa\(index)") * 0.05).setStroke()
            let fibre = UIBezierPath()
            fibre.move(to: CGPoint(x: x, y: y))
            fibre.addLine(to: CGPoint(x: x + len, y: y + (frac("\(seed)-fd\(index)") - 0.5) * 2))
            fibre.lineWidth = 0.4
            fibre.stroke()
        }

        // Edge vignette: darken the four borders a hair so the leaf has depth.
        let vignette = blend(paper.bottom, UIColor.black, 0.10)
        for edge in 0..<4 {
            let strip: CGRect
            switch edge {
            case 0: strip = CGRect(x: 0, y: 0, width: bounds.width, height: 28)
            case 1: strip = CGRect(x: 0, y: bounds.height - 28, width: bounds.width, height: 28)
            case 2: strip = CGRect(x: 0, y: 0, width: 28, height: bounds.height)
            default: strip = CGRect(x: bounds.width - 28, y: 0, width: 28, height: bounds.height)
            }
            vignette.withAlphaComponent(0.06).setFill()
            UIBezierPath(rect: strip).fill()
        }

        // Composted fragments in the left gutter and corners - never in the text
        // column (x >= 120). One or two scraps of tape and torn paper per page.
        let fragmentCount = 1 + ConstellationKeeper.stableIndex(for: "\(seed)-fragcount", count: 2)
        for index in 0..<fragmentCount {
            let corner = ConstellationKeeper.stableIndex(for: "\(seed)-corner\(index)", count: 4)
            let gx = 14 + frac("\(seed)-gx\(index)") * 70           // gutter band 14...84
            let gy: CGFloat = corner < 2
                ? 70 + frac("\(seed)-gy\(index)") * 120              // upper gutter
                : bounds.height - 230 + frac("\(seed)-gy\(index)") * 150 // lower gutter
            let w = 46 + frac("\(seed)-gw\(index)") * 26
            let h = 30 + frac("\(seed)-gh\(index)") * 22
            let rot = (frac("\(seed)-grot\(index)") - 0.5) * 0.5     // +- ~14 degrees
            let scrap = CGRect(x: gx, y: gy, width: w, height: h)
            drawTornScrap(
                in: scrap,
                rotation: rot,
                fill: blend(paper.top, style.palette.gold, 0.06),
                seed: "\(seed)-scrap\(index)"
            )
            // A faint ruled line or two, as if torn from a notebook.
            style.palette.ink.withAlphaComponent(0.12).setStroke()
            for line in 0..<2 {
                let ly = gy + 12 + CGFloat(line) * 9
                let ruled = UIBezierPath()
                ruled.move(to: CGPoint(x: gx + 6, y: ly))
                ruled.addLine(to: CGPoint(x: gx + w - 6, y: ly))
                ruled.lineWidth = 0.5
                ruled.stroke()
            }
            // Hold it down with a strip of tape across one corner.
            let tapeAtTop = corner % 2 == 0
            drawTapeStrip(
                center: CGPoint(x: scrap.midX, y: tapeAtTop ? scrap.minY : scrap.maxY),
                length: w * 0.7,
                angle: rot + (tapeAtTop ? -0.5 : 0.5),
                tint: style.palette.gold
            )
        }
    }

    /// A torn paper fragment: a deckled rounded rect with a soft drop shadow,
    /// rotated about its center. Used for gutter scraps, section labels, and the
    /// conclusion card.
    fileprivate static func drawTornScrap(
        in rect: CGRect,
        rotation: CGFloat,
        fill: UIColor,
        seed: String,
        shadow: Bool = true
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: rotation)
        cg.translateBy(x: -rect.width / 2, y: -rect.height / 2)
        let local = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)

        // Build a jittered (torn) outline.
        let path = UIBezierPath()
        let perSide = 6
        var points: [CGPoint] = []
        func edgePoints(from a: CGPoint, to b: CGPoint, key: String) {
            for step in 0..<perSide {
                let t = CGFloat(step) / CGFloat(perSide)
                let jitter = (frac("\(seed)-\(key)\(step)") - 0.5) * 4
                let nx = -(b.y - a.y)
                let ny = (b.x - a.x)
                let nlen = max(1, sqrt(nx * nx + ny * ny))
                points.append(CGPoint(
                    x: a.x + (b.x - a.x) * t + nx / nlen * jitter,
                    y: a.y + (b.y - a.y) * t + ny / nlen * jitter
                ))
            }
        }
        let tl = CGPoint(x: 0, y: 0)
        let tr = CGPoint(x: local.width, y: 0)
        let br = CGPoint(x: local.width, y: local.height)
        let bl = CGPoint(x: 0, y: local.height)
        edgePoints(from: tl, to: tr, key: "t")
        edgePoints(from: tr, to: br, key: "r")
        edgePoints(from: br, to: bl, key: "b")
        edgePoints(from: bl, to: tl, key: "l")
        guard let first = points.first else { cg.restoreGState(); return }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.close()

        if shadow {
            cg.setShadow(offset: CGSize(width: 1.5, height: 2.5), blur: 4, color: UIColor.black.withAlphaComponent(0.28).cgColor)
        }
        fill.setFill()
        path.fill()
        cg.setShadow(offset: .zero, blur: 0, color: nil)
        // A soft inner edge so the tear reads as a thin paper lip.
        blend(fill, UIColor.black, 0.12).withAlphaComponent(0.5).setStroke()
        path.lineWidth = 0.6
        path.stroke()
        cg.restoreGState()
    }

    /// A strip of translucent tape, slightly tinted, with darker edges and a
    /// dab of shine - drawn rotated about its center.
    fileprivate static func drawTapeStrip(center: CGPoint, length: CGFloat, angle: CGFloat, tint: UIColor) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let height: CGFloat = 13
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: angle)
        let body = CGRect(x: -length / 2, y: -height / 2, width: length, height: height)
        // Translucent tape body.
        blend(tint, UIColor.white, 0.55).withAlphaComponent(0.42).setFill()
        UIBezierPath(rect: body).fill()
        // Darker torn ends.
        tint.withAlphaComponent(0.22).setFill()
        UIBezierPath(rect: CGRect(x: body.minX, y: body.minY, width: 3, height: height)).fill()
        UIBezierPath(rect: CGRect(x: body.maxX - 3, y: body.minY, width: 3, height: height)).fill()
        // A line of shine down the middle.
        UIColor.white.withAlphaComponent(0.30).setFill()
        UIBezierPath(rect: CGRect(x: body.minX + 3, y: -1.5, width: length - 6, height: 2)).fill()
        cg.restoreGState()
    }

    // MARK: Drawing primitives

    private static func drawVerticalWash(in bounds: CGRect, top: UIColor, bottom: UIColor, cg: CGContext) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else {
            top.setFill()
            UIBezierPath(rect: bounds).fill()
            return
        }
        cg.saveGState()
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.midX, y: bounds.minY),
            end: CGPoint(x: bounds.midX, y: bounds.maxY),
            options: []
        )
        cg.restoreGState()
    }

    fileprivate static func drawOrnamentRow(_ style: EditionStyle, centerY: CGFloat, in bounds: CGRect, color: UIColor) {
        let center = CGPoint(x: bounds.midX, y: centerY)
        color.setFill()
        color.setStroke()

        func diamond(at point: CGPoint, size: CGFloat) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: point.x, y: point.y - size))
            path.addLine(to: CGPoint(x: point.x + size, y: point.y))
            path.addLine(to: CGPoint(x: point.x, y: point.y + size))
            path.addLine(to: CGPoint(x: point.x - size, y: point.y))
            path.close()
            path.fill()
        }

        let line = UIBezierPath()
        line.move(to: CGPoint(x: center.x - 110, y: centerY))
        line.addLine(to: CGPoint(x: center.x - 18, y: centerY))
        line.move(to: CGPoint(x: center.x + 18, y: centerY))
        line.addLine(to: CGPoint(x: center.x + 110, y: centerY))
        line.lineWidth = 0.8
        line.stroke()

        switch style.ornament {
        case .diamonds:
            diamond(at: center, size: 5)
            diamond(at: CGPoint(x: center.x - 14, y: centerY), size: 2.5)
            diamond(at: CGPoint(x: center.x + 14, y: centerY), size: 2.5)
        case .stars:
            drawStar(at: center, radius: 3.4, color: color)
            drawStar(at: CGPoint(x: center.x - 13, y: centerY), radius: 1.8, color: color)
            drawStar(at: CGPoint(x: center.x + 13, y: centerY), radius: 1.8, color: color)
        case .waves:
            let wave = UIBezierPath()
            wave.move(to: CGPoint(x: center.x - 14, y: centerY))
            wave.addQuadCurve(to: CGPoint(x: center.x, y: centerY), controlPoint: CGPoint(x: center.x - 7, y: centerY - 6))
            wave.addQuadCurve(to: CGPoint(x: center.x + 14, y: centerY), controlPoint: CGPoint(x: center.x + 7, y: centerY + 6))
            wave.lineWidth = 1.2
            wave.stroke()
        case .leaves:
            let leaf = UIBezierPath()
            leaf.move(to: CGPoint(x: center.x - 12, y: centerY))
            leaf.addQuadCurve(to: CGPoint(x: center.x + 12, y: centerY), controlPoint: CGPoint(x: center.x, y: centerY - 10))
            leaf.addQuadCurve(to: CGPoint(x: center.x - 12, y: centerY), controlPoint: CGPoint(x: center.x, y: centerY + 10))
            leaf.lineWidth = 1.1
            leaf.stroke()
        }
    }

    private static func drawRunningHead(_ edition: MonthlyEdition, style: EditionStyle, cursor: PDFCursor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: style.palette.ink.withAlphaComponent(0.45)
        ]
        let head = edition.chapterHeading.uppercased()
        (head as NSString).draw(at: CGPoint(x: cursor.left, y: 30), withAttributes: attributes)
    }

    private static func drawAccentRule(_ style: EditionStyle, cursor: inout PDFCursor) {
        style.palette.accent.setFill()
        UIBezierPath(rect: CGRect(x: cursor.left, y: cursor.y, width: 64, height: 2.5)).fill()
        cursor.y += 18
    }

    private static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    fileprivate static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor = .black,
        cursor: inout PDFCursor,
        spacingAfter: CGFloat,
        leftInset: CGFloat = 0,
        firstLineOnlyInsetHeight: CGFloat = 0
    ) {
        let width = cursor.contentWidth - leftInset
        let rectHeight = measuredTextHeight(text, font: font, width: width)
        drawMeasuredText(
            text,
            font: font,
            color: color,
            cursor: &cursor,
            spacingAfter: spacingAfter,
            width: width,
            rectHeight: rectHeight,
            leftInset: leftInset,
            firstLineOnlyInsetHeight: firstLineOnlyInsetHeight
        )
    }

    private static func measuredTextHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        return rect.height + 4
    }

    private static func drawMeasuredText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        cursor: inout PDFCursor,
        spacingAfter: CGFloat,
        width: CGFloat,
        rectHeight: CGFloat,
        leftInset: CGFloat,
        firstLineOnlyInsetHeight: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(in: CGRect(x: cursor.left + leftInset, y: cursor.y, width: width, height: rectHeight))
        cursor.y += max(rectHeight, firstLineOnlyInsetHeight) + spacingAfter
    }

    fileprivate static func drawFramedImage(_ image: UIImage, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        let maxHeight: CGFloat = 210
        let scale = min(cursor.contentWidth / image.size.width, maxHeight / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        ensureSpace(size.height + 36, style: style, context: context, cursor: &cursor)
        let rect = CGRect(x: cursor.left, y: cursor.y, width: size.width, height: size.height)

        // Plate frame: soft mat + accent hairline.
        let mat = rect.insetBy(dx: -7, dy: -7)
        style.palette.accentSoft.setFill()
        UIBezierPath(rect: mat).fill()
        image.draw(in: rect)
        style.palette.accent.withAlphaComponent(0.7).setStroke()
        let frame = UIBezierPath(rect: mat)
        frame.lineWidth = 1
        frame.stroke()

        cursor.y += size.height + 18
    }

    private static func drawFullPageMediaLeaf(
        _ image: UIImage,
        item: MonthlyEditionItem,
        asset: BookPageMediaAsset,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        context.beginPage()
        cursor.reset()
        cursor.pageIndex += 1
        drawComposedBackground(style: style, seed: "\(cursor.pageSeed)-fullmedia", in: cursor.bounds)

        let maxRect = cursor.bounds.inset(by: UIEdgeInsets(top: 44, left: 42, bottom: 72, right: 42))
        let scale = min(maxRect.width / image.size.width, maxRect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = CGRect(
            x: maxRect.midX - size.width / 2,
            y: maxRect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let mat = rect.insetBy(dx: -10, dy: -10)
        style.palette.accentSoft.setFill()
        UIBezierPath(roundedRect: mat, cornerRadius: 5).fill()
        image.draw(in: rect)
        style.palette.accent.withAlphaComponent(0.72).setStroke()
        let frame = UIBezierPath(roundedRect: mat, cornerRadius: 5)
        frame.lineWidth = 1.1
        frame.stroke()

        let caption = asset.caption.nonEmpty ?? item.title
        drawCentered(
            caption,
            font: .serifItalicFont(ofSize: 10),
            color: style.palette.ink.withAlphaComponent(0.62),
            y: cursor.bounds.maxY - 48,
            in: cursor.bounds.insetBy(dx: 70, dy: 0)
        )
        cursor.y = cursor.bottom
    }

    private static func ensureSpace(_ needed: CGFloat, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        if cursor.y + needed > cursor.bottom {
            beginComposedPage(context, style: style, cursor: &cursor)
        }
    }

    // MARK: Image resolution

    private static func fullPageMediaAsset(from assets: [BookPageMediaAsset]) -> BookPageMediaAsset? {
        assets.first(where: isFullPageMediaAsset)
    }

    private static func inlineMediaAssets(from assets: [BookPageMediaAsset]) -> [BookPageMediaAsset] {
        assets.filter { !isFullPageMediaAsset($0) }
    }

    private static func isFullPageMediaAsset(_ asset: BookPageMediaAsset) -> Bool {
        asset.metadata[mediaPresentationKey] == fullPageMediaPresentation
    }

    fileprivate static func firstImage(from assets: [BookPageMediaAsset]) -> UIImage? {
        for asset in assets {
            if let image = image(from: asset) { return image }
        }
        return nil
    }

    private static func image(from asset: BookPageMediaAsset) -> UIImage? {
        switch asset.kind {
        case .renderedImageFile:
            return UIImage(contentsOfFile: asset.reference)
        case .bundledImage:
            return UIImage(named: asset.reference)
        case .photoLibraryAsset:
            return photoLibraryImage(localIdentifier: asset.reference)
        case .audioFile:
            return nil
        }
    }

    /// Resolves a Photos-library asset synchronously at binding time. Only
    /// runs when the reader already granted photo access; otherwise the page
    /// binds without its plate.
    private static func photoLibraryImage(localIdentifier: String) -> UIImage? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetched.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        var result: UIImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            result = image
        }
        return result
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

private struct PDFCursor {
    let bounds: CGRect
    let margins: UIEdgeInsets
    var y: CGFloat
    /// Seeds the deterministic composting (paper grain, scrap and tape
    /// placement) so a given edition always composts the same way.
    var seed: String = "edition"
    /// Increments on every fresh page so each composted page draws its own
    /// arrangement of fragments rather than repeating one.
    var pageIndex: Int = 0

    init(bounds: CGRect, margins: UIEdgeInsets) {
        self.bounds = bounds
        self.margins = margins
        self.y = margins.top
    }

    var left: CGFloat { margins.left }
    var right: CGFloat { bounds.width - margins.right }
    var bottom: CGFloat { bounds.height - margins.bottom }
    var contentWidth: CGFloat { bounds.width - margins.left - margins.right }

    /// A stable per-page seed for the compost layer.
    var pageSeed: String { "\(seed)-page\(pageIndex)" }

    mutating func reset() {
        y = margins.top
    }
}

private extension UIFont {
    static func serifFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size, weight: weight)
    }

    static func serifItalicFont(ofSize size: CGFloat) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .withSymbolicTraits(.traitItalic)
        return descriptor.map { UIFont(descriptor: $0, size: size) } ?? .italicSystemFont(ofSize: size)
    }
}

// MARK: - The Bleed broadsheet PDF

enum BleedPDFWriter {
    private struct BleedArticle {
        let title: String
        let byline: String
        let body: String
    }

    private struct BleedIssue {
        let masthead: String
        let issueLine: String
        let tagline: String
        let articles: [BleedArticle]
        let colophon: String?
    }

    private struct ColumnState {
        let pageBounds: CGRect
        let columns: [CGRect]
        let bottom: CGFloat
        var columnIndex: Int = 0
        var y: CGFloat

        init(pageBounds: CGRect, columns: [CGRect], bottom: CGFloat) {
            self.pageBounds = pageBounds
            self.columns = columns
            self.bottom = bottom
            self.y = columns.first?.minY ?? 0
        }

        var rect: CGRect { columns[columnIndex] }
        var remaining: CGFloat { bottom - y }

        mutating func advanceColumn() -> Bool {
            guard columnIndex < columns.count - 1 else { return false }
            columnIndex += 1
            y = columns[columnIndex].minY
            return true
        }
    }

    static func write(
        headline: String,
        body: String,
        mediaAssets: [BookPageMediaAsset] = [],
        to url: URL
    ) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let issue = parseIssue(headline: headline, body: body)
        let printablePlates = mediaAssets.prefix(2).compactMap { asset -> (BookPageMediaAsset, UIImage)? in
            let image: UIImage?
            switch asset.kind {
            case .bundledImage:
                image = UIImage(named: asset.reference)
            case .renderedImageFile:
                image = UIImage(contentsOfFile: asset.reference)
            case .photoLibraryAsset, .audioFile:
                image = nil
            }
            return image.map { (asset, $0) }
        }
        let ink = UIColor(red: 0.13, green: 0.105, blue: 0.075, alpha: 1)
        let brown = UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1)
        let redInk = UIColor(red: 0.52, green: 0.12, blue: 0.10, alpha: 1)
        let contentLeft: CGFloat = 82
        let contentRight: CGFloat = 530
        let gutter: CGFloat = 14
        let columnWidth = (contentRight - contentLeft - gutter * 2) / 3
        let columns = (0..<3).map { index in
            CGRect(
                x: contentLeft + CGFloat(index) * (columnWidth + gutter),
                y: 214,
                width: columnWidth,
                height: 520
            )
        }

        try renderer.writePDF(to: url) { context in
            var pageNumber = 1

            func beginPage(front: Bool) -> ColumnState {
                let topY: CGFloat = front
                    ? (printablePlates.isEmpty ? 222 : 366)
                    : 72
                let pageColumns = columns.map {
                    CGRect(x: $0.minX, y: topY, width: $0.width, height: 734 - topY)
                }
                context.beginPage()
                drawParchmentPage(
                    bounds: pageBounds,
                    pageNumber: pageNumber,
                    issue: issue,
                    ink: ink,
                    accent: brown,
                    redInk: redInk
                )
                if front {
                    drawBleedBanner(issue: issue, fallbackHeadline: headline, bounds: pageBounds, ink: ink, accent: brown, redInk: redInk)
                    drawBleedPlates(
                        printablePlates,
                        bounds: pageBounds,
                        ink: ink,
                        accent: brown
                    )
                } else {
                    drawContinuedHeader(issue: issue, pageNumber: pageNumber, bounds: pageBounds, ink: ink, accent: brown)
                }
                drawColumnRules(pageColumns, color: ink.withAlphaComponent(0.18), bottom: 734)
                return ColumnState(pageBounds: pageBounds, columns: pageColumns, bottom: 734)
            }

            var state = beginPage(front: true)

            // Takes the column state as an explicit inout parameter instead of
            // capturing the local var: the draw helpers below already hold
            // exclusive (inout) access to `state` when they ask for the next
            // column, and a capturing closure would violate exclusivity and
            // abort at runtime.
            func nextColumnOrPage(_ state: inout ColumnState) {
                if !state.advanceColumn() {
                    pageNumber += 1
                    context.beginPage()
                    drawParchmentPage(
                        bounds: pageBounds,
                        pageNumber: pageNumber,
                        issue: issue,
                        ink: ink,
                        accent: brown,
                        redInk: redInk
                    )
                    drawContinuedHeader(issue: issue, pageNumber: pageNumber, bounds: pageBounds, ink: ink, accent: brown)
                    let pageColumns = columns.map {
                        CGRect(x: $0.minX, y: 72, width: $0.width, height: 662)
                    }
                    drawColumnRules(pageColumns, color: ink.withAlphaComponent(0.18), bottom: 734)
                    state = ColumnState(pageBounds: pageBounds, columns: pageColumns, bottom: 734)
                }
            }

            if let lead = issue.articles.first {
                drawLeadArticle(lead, state: &state, ink: ink, accent: brown, redInk: redInk, nextColumnOrPage: nextColumnOrPage)
                drawInkwellAd(state: &state, ink: ink, accent: brown, nextColumnOrPage: nextColumnOrPage)
                for article in issue.articles.dropFirst() {
                    drawArticle(article, state: &state, ink: ink, accent: brown, nextColumnOrPage: nextColumnOrPage)
                }
            } else {
                let fallback = BleedArticle(title: issue.masthead, byline: issue.issueLine, body: body)
                drawLeadArticle(fallback, state: &state, ink: ink, accent: brown, redInk: redInk, nextColumnOrPage: nextColumnOrPage)
            }

            if let colophon = issue.colophon {
                drawColophon(colophon, state: &state, ink: ink, accent: brown, nextColumnOrPage: nextColumnOrPage)
            }
        }
    }

    private static func drawBleedPlates(
        _ plates: [(BookPageMediaAsset, UIImage)],
        bounds: CGRect,
        ink: UIColor,
        accent: UIColor
    ) {
        guard !plates.isEmpty else { return }
        let gutter: CGFloat = 14
        let availableWidth: CGFloat = 448
        let width = plates.count == 1
            ? min(250, availableWidth)
            : (availableWidth - gutter) / 2
        let totalWidth = CGFloat(plates.count) * width + CGFloat(max(0, plates.count - 1)) * gutter
        let startX = bounds.midX - totalWidth / 2

        for (index, plate) in plates.enumerated() {
            let x = startX + CGFloat(index) * (width + gutter)
            let frame = CGRect(x: x, y: 218, width: width, height: 106)
            guard let cg = UIGraphicsGetCurrentContext() else { continue }
            cg.saveGState()
            UIBezierPath(roundedRect: frame, cornerRadius: 3).addClip()
            let image = plate.1
            let scale = max(frame.width / image.size.width, frame.height / image.size.height)
            let drawn = CGRect(
                x: frame.midX - image.size.width * scale / 2,
                y: frame.midY - image.size.height * scale / 2,
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            image.draw(in: drawn)
            cg.restoreGState()

            accent.withAlphaComponent(0.46).setStroke()
            let border = UIBezierPath(roundedRect: frame, cornerRadius: 3)
            border.lineWidth = 0.8
            border.stroke()
            drawBlock(
                plate.0.caption.nonEmpty ?? "Plate from the reader's file.",
                font: .serifItalicFont(ofSize: 7.8),
                color: ink.withAlphaComponent(0.72),
                frame: CGRect(x: x, y: frame.maxY + 4, width: width, height: 30),
                lineSpacing: 1.4,
                alignment: .left
            )
        }
    }

    private static func parseIssue(headline: String, body: String) -> BleedIssue {
        let lines = body.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
        let firstArticleIndex = lines.firstIndex(where: isArticleHeading) ?? lines.endIndex
        let headerLines = lines[..<firstArticleIndex]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let masthead = headerLines.first ?? headline
        let issueLine = headerLines.dropFirst().first ?? "A ReEnchanted broadsheet"
        let tagline = headerLines.dropFirst(2).first ?? "Where the Labyrinth meets the page. Where the page bleeds into the world."

        var articles: [BleedArticle] = []
        var colophon: String?

        var title: String?
        var articleLines: [String] = []

        func flushArticle() {
            guard let title else { return }
            let bylineIndex = articleLines.firstIndex { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let byline = bylineIndex.map { articleLines[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
                ?? "P. Blackletter"
            let bodyStart = bylineIndex.map { articleLines.index(after: $0) } ?? articleLines.startIndex
            let articleBody = articleLines[bodyStart...]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            articles.append(BleedArticle(title: title, byline: byline, body: articleBody))
        }

        for line in lines[firstArticleIndex...] {
            if isArticleHeading(line) {
                flushArticle()
                title = line.trimmingCharacters(in: CharacterSet(charactersIn: "\u{2014} ")).capitalized
                articleLines = []
            } else if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Set in type by") {
                flushArticle()
                title = nil
                articleLines = []
                colophon = line.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if title != nil {
                articleLines.append(line)
            } else if colophon != nil, !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                colophon = [colophon, line.trimmingCharacters(in: .whitespacesAndNewlines)]
                    .compactMap(\.self)
                    .joined(separator: "\n")
            }
        }
        flushArticle()
        return BleedIssue(masthead: masthead, issueLine: issueLine, tagline: tagline, articles: articles, colophon: colophon)
    }

    private static func isArticleHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("\u{2014}") && trimmed.hasSuffix("\u{2014}") && trimmed.count > 2
    }

    private static func drawParchmentPage(
        bounds: CGRect,
        pageNumber: Int,
        issue: BleedIssue,
        ink: UIColor,
        accent: UIColor,
        redInk: UIColor
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let top = UIColor(red: 0.96, green: 0.88, blue: 0.67, alpha: 1)
        let bottom = UIColor(red: 0.80, green: 0.64, blue: 0.40, alpha: 1)
        drawVerticalWash(in: bounds, top: top, bottom: bottom, cg: cg)

        cg.saveGState()
        cg.setBlendMode(.multiply)
        for index in 0..<52 {
            let seed = stableUnit("\(issue.masthead)-fiber-\(pageNumber)-\(index)")
            let y = bounds.minY + 18 + seed * (bounds.height - 36)
            let alpha = 0.035 + stableUnit("fiber-alpha-\(index)-\(pageNumber)") * 0.045
            UIColor(red: 0.36, green: 0.22, blue: 0.10, alpha: alpha).setStroke()
            let path = UIBezierPath()
            path.lineWidth = 0.45
            path.move(to: CGPoint(x: 24, y: y))
            path.addCurve(
                to: CGPoint(x: bounds.maxX - 24, y: y + stableSignedUnit("fiber-drift-\(index)") * 8),
                controlPoint1: CGPoint(x: 190, y: y - 6),
                controlPoint2: CGPoint(x: 410, y: y + 7)
            )
            path.stroke()
        }
        for index in 0..<5 {
            let x = 70 + stableUnit("stain-x-\(pageNumber)-\(index)") * 470
            let y = 100 + stableUnit("stain-y-\(issue.issueLine)-\(index)") * 570
            let radius = 22 + stableUnit("stain-r-\(index)") * 48
            UIColor(red: 0.42, green: 0.25, blue: 0.12, alpha: 0.055).setFill()
            UIBezierPath(ovalIn: CGRect(x: x, y: y, width: radius, height: radius * 0.72)).fill()
        }
        cg.restoreGState()

        drawDeckledBorder(bounds: bounds, color: accent.withAlphaComponent(0.42))
        drawFoldLines(bounds: bounds, color: ink.withAlphaComponent(0.13))
        drawMarginalia(bounds: bounds, pageNumber: pageNumber, issue: issue, ink: ink, redInk: redInk)
        drawCentered(
            "ReEnchanted \u{00B7} reenchanted.app \u{00B7} Page \(pageNumber)",
            font: .systemFont(ofSize: 7.5, weight: .semibold),
            color: ink.withAlphaComponent(0.42),
            y: bounds.height - 32,
            in: bounds
        )
    }

    private static func drawNameplate(
        issue: BleedIssue,
        fallbackHeadline: String,
        bounds: CGRect,
        ink: UIColor,
        accent: UIColor,
        redInk: UIColor
    ) {
        let content = CGRect(x: 58, y: 44, width: 496, height: 154)
        accent.withAlphaComponent(0.55).setStroke()
        UIBezierPath(rect: content.insetBy(dx: -4, dy: -4)).stroke()
        drawSmallCaps(issue.issueLine, fontSize: 8.5, color: ink.withAlphaComponent(0.66), y: content.minY + 6, in: content)
        drawCentered("THE BLEED", font: .serifFont(ofSize: 54, weight: .black), color: ink, y: content.minY + 24, in: content)
        drawCentered(issue.tagline, font: .serifItalicFont(ofSize: 10.5), color: ink.withAlphaComponent(0.74), y: content.minY + 86, in: content)

        redInk.withAlphaComponent(0.72).setStroke()
        let slash = UIBezierPath()
        slash.lineWidth = 1.1
        slash.move(to: CGPoint(x: content.minX + 24, y: content.minY + 114))
        slash.addLine(to: CGPoint(x: content.maxX - 24, y: content.minY + 104))
        slash.stroke()

        drawCentered(
            "VISUAL EDITION: \(fallbackHeadline.uppercased())",
            font: .systemFont(ofSize: 9, weight: .heavy),
            color: redInk.withAlphaComponent(0.82),
            y: content.minY + 124,
            in: content
        )

        drawSeal(center: CGPoint(x: content.maxX - 32, y: content.minY + 34), color: redInk)
        drawSeal(center: CGPoint(x: content.minX + 32, y: content.minY + 112), color: accent)
    }

    private static func drawBleedBanner(
        issue: BleedIssue,
        fallbackHeadline: String,
        bounds: CGRect,
        ink: UIColor,
        accent: UIColor,
        redInk: UIColor
    ) {
        guard let image = UIImage(named: "TheBleedBanner") else {
            drawNameplate(
                issue: issue,
                fallbackHeadline: fallbackHeadline,
                bounds: bounds,
                ink: ink,
                accent: accent,
                redInk: redInk
            )
            return
        }

        let banner = CGRect(x: 58, y: 34, width: 496, height: 150)
        image.draw(in: banner)
        accent.withAlphaComponent(0.65).setStroke()
        let border = UIBezierPath(rect: banner.insetBy(dx: -2, dy: -2))
        border.lineWidth = 1.2
        border.stroke()
        drawSmallCaps(
            issue.issueLine,
            fontSize: 8.5,
            color: ink.withAlphaComponent(0.68),
            y: 194,
            in: CGRect(x: 58, y: 0, width: 496, height: 210)
        )
        drawCentered(
            "VISUAL EDITION: \(fallbackHeadline.uppercased())",
            font: .systemFont(ofSize: 8.5, weight: .heavy),
            color: redInk.withAlphaComponent(0.82),
            y: 205,
            in: CGRect(x: 58, y: 0, width: 496, height: 216)
        )
    }

    private static func drawContinuedHeader(issue: BleedIssue, pageNumber: Int, bounds: CGRect, ink: UIColor, accent: UIColor) {
        drawSmallCaps("THE BLEED CONTINUES \u{00B7} \(issue.issueLine) \u{00B7} PAGE \(pageNumber)", fontSize: 8, color: ink.withAlphaComponent(0.62), y: 34, in: CGRect(x: 72, y: 0, width: 468, height: 40))
        accent.withAlphaComponent(0.45).setFill()
        UIBezierPath(rect: CGRect(x: 82, y: 56, width: 448, height: 1.2)).fill()
    }

    private static func drawLeadArticle(
        _ article: BleedArticle,
        state: inout ColumnState,
        ink: UIColor,
        accent: UIColor,
        redInk: UIColor,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        drawArticleHeader(article, state: &state, ink: ink, accent: redInk, large: true, nextColumnOrPage: nextColumnOrPage)
        drawPullQuote(from: article.body, state: &state, ink: ink, accent: accent, nextColumnOrPage: nextColumnOrPage)
        drawFlowing(article.body, font: .serifFont(ofSize: 8.6, weight: .regular), color: ink.withAlphaComponent(0.93), state: &state, lineSpacing: 2.2, spacingAfter: 7, nextColumnOrPage: nextColumnOrPage)
    }

    private static func drawArticle(
        _ article: BleedArticle,
        state: inout ColumnState,
        ink: UIColor,
        accent: UIColor,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        drawArticleHeader(article, state: &state, ink: ink, accent: accent, large: false, nextColumnOrPage: nextColumnOrPage)
        drawFlowing(article.body, font: .serifFont(ofSize: 8.3, weight: .regular), color: ink.withAlphaComponent(0.91), state: &state, lineSpacing: 2.1, spacingAfter: 8, nextColumnOrPage: nextColumnOrPage)
    }

    private static func drawArticleHeader(
        _ article: BleedArticle,
        state: inout ColumnState,
        ink: UIColor,
        accent: UIColor,
        large: Bool,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        let titleFont = UIFont.serifFont(ofSize: large ? 14.5 : 11.5, weight: .bold)
        let bylineFont = UIFont.serifItalicFont(ofSize: 7.8)
        let titleHeight = measured(article.title.uppercased(), font: titleFont, width: state.rect.width, lineSpacing: 1.5)
        let bylineHeight = measured(article.byline, font: bylineFont, width: state.rect.width, lineSpacing: 1)
        if state.remaining < titleHeight + bylineHeight + 28 {
            nextColumnOrPage(&state)
        }
        accent.withAlphaComponent(0.72).setFill()
        UIBezierPath(rect: CGRect(x: state.rect.minX, y: state.y, width: min(42, state.rect.width), height: 2)).fill()
        state.y += 7
        drawBlock(article.title.uppercased(), font: titleFont, color: ink, frame: CGRect(x: state.rect.minX, y: state.y, width: state.rect.width, height: titleHeight + 3), lineSpacing: 1.5, alignment: .left)
        state.y += titleHeight + 1
        drawBlock(article.byline, font: bylineFont, color: ink.withAlphaComponent(0.60), frame: CGRect(x: state.rect.minX, y: state.y, width: state.rect.width, height: bylineHeight + 3), lineSpacing: 1, alignment: .left)
        state.y += bylineHeight + 8
    }

    private static func drawPullQuote(
        from body: String,
        state: inout ColumnState,
        ink: UIColor,
        accent: UIColor,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        guard let sentence = firstSentence(in: body), sentence.count > 42 else { return }
        let quote = "\u{201C}\(sentence)\u{201D}"
        let font = UIFont.serifItalicFont(ofSize: 10.5)
        let height = measured(quote, font: font, width: state.rect.width - 16, lineSpacing: 2.2) + 22
        if state.remaining < height + 12 {
            nextColumnOrPage(&state)
        }
        let frame = CGRect(x: state.rect.minX, y: state.y, width: state.rect.width, height: height)
        accent.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 3).fill()
        accent.withAlphaComponent(0.65).setStroke()
        let path = UIBezierPath()
        path.lineWidth = 1.2
        path.move(to: CGPoint(x: frame.minX + 7, y: frame.minY + 8))
        path.addLine(to: CGPoint(x: frame.minX + 7, y: frame.maxY - 8))
        path.stroke()
        drawBlock(quote, font: font, color: ink.withAlphaComponent(0.82), frame: frame.insetBy(dx: 13, dy: 9), lineSpacing: 2.2, alignment: .left)
        state.y += height + 10
    }

    private static func drawInkwellAd(
        state: inout ColumnState,
        ink: UIColor,
        accent: UIColor,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        let height: CGFloat = 70
        if state.remaining < height + 18 {
            nextColumnOrPage(&state)
        }
        let frame = CGRect(x: state.rect.minX, y: state.y, width: state.rect.width, height: height)
        accent.withAlphaComponent(0.16).setFill()
        UIBezierPath(rect: frame).fill()
        accent.withAlphaComponent(0.46).setStroke()
        UIBezierPath(rect: frame.insetBy(dx: 2, dy: 2)).stroke()
        drawCentered("NOTICE FROM THE PRESS ROOM", font: .systemFont(ofSize: 6.8, weight: .black), color: ink.withAlphaComponent(0.72), y: frame.minY + 9, in: frame)
        drawCentered("Ink may transfer.", font: .serifFont(ofSize: 12.5, weight: .bold), color: ink, y: frame.minY + 25, in: frame)
        drawCentered("Read near candlelight. Trust only fresh margins.", font: .serifItalicFont(ofSize: 7.2), color: ink.withAlphaComponent(0.66), y: frame.minY + 46, in: frame)
        state.y += height + 13
    }

    private static func drawColophon(
        _ text: String,
        state: inout ColumnState,
        ink: UIColor,
        accent: UIColor,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        if state.remaining < 62 {
            nextColumnOrPage(&state)
        }
        accent.withAlphaComponent(0.48).setFill()
        UIBezierPath(rect: CGRect(x: state.rect.minX, y: state.y, width: state.rect.width, height: 1)).fill()
        state.y += 8
        drawFlowing(text, font: .serifItalicFont(ofSize: 8), color: ink.withAlphaComponent(0.64), state: &state, lineSpacing: 1.8, spacingAfter: 4, nextColumnOrPage: nextColumnOrPage)
    }

    private static func drawFlowing(
        _ text: String,
        font: UIFont,
        color: UIColor,
        state: inout ColumnState,
        lineSpacing: CGFloat,
        spacingAfter: CGFloat,
        nextColumnOrPage: (inout ColumnState) -> Void
    ) {
        let paragraphs = text.components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for paragraph in paragraphs {
            var remaining = paragraph
            while !remaining.isEmpty {
                if state.remaining < 34 {
                    nextColumnOrPage(&state)
                }
                let available = max(24, state.remaining - spacingAfter)
                let chunk = chunkThatFits(remaining, font: font, width: state.rect.width, maxHeight: available, lineSpacing: lineSpacing)
                if chunk.isEmpty {
                    nextColumnOrPage(&state)
                    continue
                }
                let height = measured(chunk, font: font, width: state.rect.width, lineSpacing: lineSpacing)
                drawBlock(chunk, font: font, color: color, frame: CGRect(x: state.rect.minX, y: state.y, width: state.rect.width, height: height + 4), lineSpacing: lineSpacing, alignment: .justified)
                state.y += height + spacingAfter
                remaining = String(remaining.dropFirst(chunk.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private static func chunkThatFits(_ text: String, font: UIFont, width: CGFloat, maxHeight: CGFloat, lineSpacing: CGFloat) -> String {
        if measured(text, font: font, width: width, lineSpacing: lineSpacing) <= maxHeight {
            return text
        }
        let words = text.split(separator: " ").map(String.init)
        var low = 0
        var high = words.count
        var best = ""
        while low <= high {
            let mid = (low + high) / 2
            let candidate = words.prefix(mid).joined(separator: " ")
            if candidate.isEmpty {
                low = mid + 1
                continue
            }
            if measured(candidate, font: font, width: width, lineSpacing: lineSpacing) <= maxHeight {
                best = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best.isEmpty ? (words.first ?? "") : best
    }

    private static func measured(_ text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph
        ])
        return attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral.height + 3
    }

    private static func drawBlock(
        _ text: String,
        font: UIFont,
        color: UIColor,
        frame: CGRect,
        lineSpacing: CGFloat,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = alignment
        paragraph.hyphenationFactor = 0.8
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        attributed.draw(in: frame)
    }

    private static func drawColumnRules(_ columns: [CGRect], color: UIColor, bottom: CGFloat) {
        guard columns.count > 1 else { return }
        color.setStroke()
        for index in 0..<(columns.count - 1) {
            let x = (columns[index].maxX + columns[index + 1].minX) / 2
            let path = UIBezierPath()
            path.lineWidth = 0.6
            path.move(to: CGPoint(x: x, y: columns[index].minY))
            path.addLine(to: CGPoint(x: x, y: bottom))
            path.stroke()
        }
    }

    private static func drawDeckledBorder(bounds: CGRect, color: UIColor) {
        color.setStroke()
        for inset in [18.0, 24.0] {
            let path = UIBezierPath()
            path.lineWidth = inset == 18 ? 1.2 : 0.6
            let rect = bounds.insetBy(dx: inset, dy: inset)
            path.move(to: CGPoint(x: rect.minX + 7, y: rect.minY))
            for step in 0...18 {
                let t = CGFloat(step) / 18
                path.addLine(to: CGPoint(x: rect.minX + rect.width * t, y: rect.minY + stableSignedUnit("top-\(inset)-\(step)") * 2.8))
            }
            for step in 0...24 {
                let t = CGFloat(step) / 24
                path.addLine(to: CGPoint(x: rect.maxX + stableSignedUnit("right-\(inset)-\(step)") * 2.8, y: rect.minY + rect.height * t))
            }
            for step in stride(from: 18, through: 0, by: -1) {
                let t = CGFloat(step) / 18
                path.addLine(to: CGPoint(x: rect.minX + rect.width * t, y: rect.maxY + stableSignedUnit("bottom-\(inset)-\(step)") * 2.8))
            }
            for step in stride(from: 24, through: 0, by: -1) {
                let t = CGFloat(step) / 24
                path.addLine(to: CGPoint(x: rect.minX + stableSignedUnit("left-\(inset)-\(step)") * 2.8, y: rect.minY + rect.height * t))
            }
            path.close()
            path.stroke()
        }
    }

    private static func drawFoldLines(bounds: CGRect, color: UIColor) {
        color.setStroke()
        let vertical = UIBezierPath()
        vertical.lineWidth = 0.8
        vertical.move(to: CGPoint(x: bounds.midX, y: 26))
        vertical.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY - 26))
        vertical.stroke()
        let horizontal = UIBezierPath()
        horizontal.lineWidth = 0.55
        horizontal.move(to: CGPoint(x: 28, y: bounds.midY + 6))
        horizontal.addLine(to: CGPoint(x: bounds.maxX - 28, y: bounds.midY - 5))
        horizontal.stroke()
    }

    private static func drawMarginalia(bounds: CGRect, pageNumber: Int, issue: BleedIssue, ink: UIColor, redInk: UIColor) {
        let notes = marginaliaNotes(for: issue)
        guard !notes.isEmpty else { return }
        let leftNote = notes[(pageNumber - 1) % notes.count]
        let rightNote = notes[pageNumber % notes.count]
        drawMarginNote(leftNote, at: CGPoint(x: 41, y: 260 + stableUnit("left-note-\(pageNumber)") * 210), angle: -0.12, color: ink.withAlphaComponent(0.58), width: 82)
        drawMarginNote(rightNote, at: CGPoint(x: bounds.maxX - 42, y: 210 + stableUnit("right-note-\(pageNumber)") * 260), angle: 0.10, color: redInk.withAlphaComponent(0.62), width: 86, rightAligned: true)

        redInk.withAlphaComponent(0.42).setStroke()
        let circle = UIBezierPath(ovalIn: CGRect(x: bounds.maxX - 73, y: 124, width: 32, height: 22))
        circle.lineWidth = 1.1
        circle.stroke()
        let arrow = UIBezierPath()
        arrow.lineWidth = 0.9
        arrow.move(to: CGPoint(x: bounds.maxX - 58, y: 150))
        arrow.addQuadCurve(to: CGPoint(x: bounds.maxX - 91, y: 192), controlPoint: CGPoint(x: bounds.maxX - 86, y: 158))
        arrow.stroke()
    }

    private static func drawMarginNote(
        _ text: String,
        at point: CGPoint,
        angle: CGFloat,
        color: UIColor,
        width: CGFloat,
        rightAligned: Bool = false
    ) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.translateBy(x: point.x, y: point.y)
        cg.rotate(by: angle)
        let frame = CGRect(x: rightAligned ? -width : 0, y: 0, width: width, height: 80)
        drawBlock(text, font: .serifItalicFont(ofSize: 8.6), color: color, frame: frame, lineSpacing: 2.2, alignment: rightAligned ? .right : .left)
        cg.restoreGState()
    }

    private static func marginaliaNotes(for issue: BleedIssue) -> [String] {
        let titles = issue.articles.map(\.title).filter { !$0.isEmpty }
        let lead = titles.first ?? "front page"
        return [
            "check this against the \(lead.lowercased()) desk",
            "ink still wet",
            "P.B. says keep the receipt",
            "too loud to ignore",
            "circle back after moonrise",
            titles.dropFirst().first.map { "ask \($0.lowercased()) why" } ?? "ask the margin why"
        ]
    }

    private static func firstSentence(in text: String) -> String? {
        let trimmed = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stops = CharacterSet(charactersIn: ".!?")
        if let range = trimmed.rangeOfCharacter(from: stops) {
            return String(trimmed[...range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed.count > 120 ? String(trimmed.prefix(120)) : trimmed
    }

    private static func drawSeal(center: CGPoint, color: UIColor) {
        color.withAlphaComponent(0.16).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)).fill()
        color.withAlphaComponent(0.58).setStroke()
        let path = UIBezierPath(ovalIn: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28))
        path.lineWidth = 1.2
        path.stroke()
        drawCentered("B", font: .serifFont(ofSize: 12, weight: .bold), color: color.withAlphaComponent(0.70), y: center.y - 8, in: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28))
    }

    private static func drawSmallCaps(_ text: String, fontSize: CGFloat, color: UIColor, y: CGFloat, in bounds: CGRect) {
        drawCentered(text.uppercased(), font: .systemFont(ofSize: fontSize, weight: .black), color: color, y: y, in: bounds)
    }

    private static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    private static func drawVerticalWash(in bounds: CGRect, top: UIColor, bottom: UIColor, cg: CGContext) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else {
            top.setFill()
            UIBezierPath(rect: bounds).fill()
            return
        }
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.midX, y: bounds.minY),
            end: CGPoint(x: bounds.midX, y: bounds.maxY),
            options: []
        )
    }

    private static func stableUnit(_ key: String) -> CGFloat {
        CGFloat(positiveHash(key) % 10_000) / 10_000
    }

    private static func stableSignedUnit(_ key: String) -> CGFloat {
        stableUnit(key) * 2 - 1
    }

    private static func positiveHash(_ key: String) -> Int {
        var hash = 5381
        for scalar in key.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }
}

// MARK: - Weekly Issue PDF

enum WeeklyIssueShareCardRenderer {
    static let defaultSize = CGSize(width: 1080, height: 1350)

    static func write(_ card: WeeklyIssueShareCard, to url: URL, size: CGSize = defaultSize) throws {
        let image = image(for: card, size: size)
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    static func image(for card: WeeklyIssueShareCard, size: CGSize = defaultSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(card, in: CGRect(origin: .zero, size: size), cg: context.cgContext)
        }
    }

    private static func draw(_ card: WeeklyIssueShareCard, in bounds: CGRect, cg: CGContext) {
        let ink = UIColor(red: 0.12, green: 0.09, blue: 0.07, alpha: 1)
        let paperTop = UIColor(red: 0.98, green: 0.92, blue: 0.76, alpha: 1)
        let paperBottom = UIColor(red: 0.72, green: 0.58, blue: 0.39, alpha: 1)
        let teal = UIColor(red: 0.05, green: 0.42, blue: 0.45, alpha: 1)
        let gold = UIColor(red: 0.78, green: 0.52, blue: 0.18, alpha: 1)
        let red = UIColor(red: 0.54, green: 0.12, blue: 0.13, alpha: 1)

        drawVerticalWash(in: bounds, top: paperTop, bottom: paperBottom, cg: cg)
        drawStarField(in: bounds, color: gold)

        let cardRect = bounds.insetBy(dx: 72, dy: 78)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 42)
        UIColor.white.withAlphaComponent(0.28).setFill()
        cardPath.fill()
        gold.withAlphaComponent(0.46).setStroke()
        cardPath.lineWidth = 3
        cardPath.stroke()

        drawCornerMarks(in: cardRect, color: red.withAlphaComponent(0.72))
        drawCentered("THE BOOK OF YOU", font: .systemFont(ofSize: 28, weight: .bold), color: ink.withAlphaComponent(0.58), y: cardRect.minY + 58, in: bounds)
        drawCentered("WEEKLY ISSUE", font: .systemFont(ofSize: 23, weight: .semibold), color: teal.withAlphaComponent(0.82), y: cardRect.minY + 96, in: bounds)

        drawCentered("Issue No. \(card.issueNumber)", font: .serifFont(ofSize: 82, weight: .bold), color: ink, y: cardRect.minY + 178, in: bounds)
        drawCentered(card.dateRange.uppercased(), font: .systemFont(ofSize: 27, weight: .heavy), color: red, y: cardRect.minY + 282, in: bounds)

        let titleRect = CGRect(x: cardRect.minX + 86, y: cardRect.minY + 365, width: cardRect.width - 172, height: 174)
        drawWrappedCentered(card.title, font: .serifFont(ofSize: 68, weight: .bold), color: ink, rect: titleRect)
        let subtitleRect = CGRect(x: cardRect.minX + 112, y: titleRect.maxY + 18, width: cardRect.width - 224, height: 112)
        drawWrappedCentered(card.subtitle, font: .serifItalicFont(ofSize: 30), color: ink.withAlphaComponent(0.76), rect: subtitleRect)

        let statY = cardRect.minY + 730
        drawStatPills(card.stats, y: statY, in: cardRect, ink: ink, fill: teal, accent: gold)

        let motifRect = CGRect(x: cardRect.minX + 86, y: statY + 160, width: cardRect.width - 172, height: 128)
        drawWrappedCentered(card.motifLine, font: .systemFont(ofSize: 32, weight: .semibold), color: ink.withAlphaComponent(0.82), rect: motifRect)

        let closeRect = CGRect(x: cardRect.minX + 120, y: cardRect.maxY - 230, width: cardRect.width - 240, height: 92)
        drawWrappedCentered(card.closingLine, font: .serifItalicFont(ofSize: 36), color: red.withAlphaComponent(0.90), rect: closeRect)
        drawCentered("Made with ReEnchanted", font: .systemFont(ofSize: 24, weight: .bold), color: ink.withAlphaComponent(0.62), y: cardRect.maxY - 78, in: bounds)
        drawCentered("reenchanted.app", font: .systemFont(ofSize: 21, weight: .semibold), color: ink.withAlphaComponent(0.46), y: cardRect.maxY - 43, in: bounds)
    }

    private static func drawStatPills(_ stats: [String], y: CGFloat, in cardRect: CGRect, ink: UIColor, fill: UIColor, accent: UIColor) {
        let shown = Array(stats.prefix(3))
        guard !shown.isEmpty else { return }
        let gap: CGFloat = 18
        let totalGap = gap * CGFloat(max(0, shown.count - 1))
        let pillWidth = (cardRect.width - 150 - totalGap) / CGFloat(shown.count)
        for (index, stat) in shown.enumerated() {
            let rect = CGRect(
                x: cardRect.minX + 75 + CGFloat(index) * (pillWidth + gap),
                y: y,
                width: pillWidth,
                height: 106
            )
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 26)
            fill.withAlphaComponent(index == 0 ? 0.24 : 0.16).setFill()
            path.fill()
            accent.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 2
            path.stroke()
            drawWrappedCentered(stat.uppercased(), font: .systemFont(ofSize: 24, weight: .heavy), color: ink.withAlphaComponent(0.82), rect: rect.insetBy(dx: 14, dy: 18))
        }
    }

    private static func drawStarField(in bounds: CGRect, color: UIColor) {
        color.withAlphaComponent(0.16).setFill()
        for index in 0..<72 {
            let x = CGFloat((index * 139) % 1013) + 28
            let y = CGFloat((index * 197) % 1279) + 31
            let radius = CGFloat((index % 4) + 2)
            UIBezierPath(ovalIn: CGRect(x: x, y: y, width: radius, height: radius)).fill()
        }
    }

    private static func drawVerticalWash(in bounds: CGRect, top: UIColor, bottom: UIColor, cg: CGContext) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else {
            top.setFill()
            UIBezierPath(rect: bounds).fill()
            return
        }
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.midX, y: bounds.minY),
            end: CGPoint(x: bounds.midX, y: bounds.maxY),
            options: []
        )
    }

    private static func drawCornerMarks(in rect: CGRect, color: UIColor) {
        color.setStroke()
        for corner in 0..<4 {
            let path = UIBezierPath()
            let x = corner == 0 || corner == 2 ? rect.minX + 34 : rect.maxX - 34
            let y = corner < 2 ? rect.minY + 34 : rect.maxY - 34
            let xSign: CGFloat = corner == 0 || corner == 2 ? 1 : -1
            let ySign: CGFloat = corner < 2 ? 1 : -1
            path.move(to: CGPoint(x: x, y: y + ySign * 54))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + xSign * 54, y: y))
            path.lineWidth = 4
            path.stroke()
        }
    }

    private static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    private static func drawWrappedCentered(_ text: String, font: UIFont, color: UIColor, rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 4
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let measured = attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let y = rect.minY + max(0, (rect.height - measured.height) / 2)
        attributed.draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: min(rect.height, measured.height + 12)))
    }
}

enum WeeklyIssuePDFWriter {
    private typealias Monthly = MonthlyEditionPDFWriter

    /// Each issue gets its own deterministic binding — palette and ornament
    /// seeded by the issue number, so Issue No. 4 composts differently from
    /// Issue No. 5 while a rebind of either always looks the same.
    static func style(for issue: WeeklyIssue) -> EditionStyle {
        let seed = "weekly-issue-\(issue.number)"
        let palette = EditionStyle.palettes[ConstellationKeeper.stableIndex(for: "\(seed)-palette", count: EditionStyle.palettes.count)]
        let ornament = EditionStyle.Ornament.allCases[ConstellationKeeper.stableIndex(for: "\(seed)-ornament", count: EditionStyle.Ornament.allCases.count)]
        return EditionStyle(palette: palette, coverMotif: .lamp, ornament: ornament)
    }

    static func write(
        _ issue: WeeklyIssue,
        readerName: String,
        shareCard: WeeklyIssueShareCard? = nil,
        editorialNote: String? = nil,
        closingNote: String? = nil,
        to url: URL
    ) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let frontMargins = UIEdgeInsets(top: 58, left: 64, bottom: 66, right: 64)
        // Reading pages keep a wide left gutter so the taped marginalia scraps
        // have somewhere to live, mirroring the monthly binding.
        let readingMargins = UIEdgeInsets(top: 58, left: 116, bottom: 66, right: 58)
        let style = style(for: issue)
        let ink = style.palette.ink
        let accent = style.palette.accent
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let card = shareCard ?? WeeklyIssueShareCard.make(issue: issue)
        let calendar = Calendar.current

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateFormat = "EEEE, MMM d"

        // Scrapbook pages become plates; their scaffold text reads poorly as
        // prose, so they stay out of the day-by-day chronology and the
        // centerfold pick.
        let prosePages = issue.pages.filter { !EditionCurator.isScrapbookPage($0) }
        let plates: [(page: BookPage, image: UIImage)] = Array(
            issue.pages
                .filter(EditionCurator.isScrapbookPage)
                .compactMap { page in Monthly.firstImage(from: page.mediaAssets).map { (page, $0) } }
                .prefix(4)
        )
        // The single strongest page of the week — the issue's centerfold.
        let bestPage = prosePages
            .filter { ($0.userInput.nonEmpty ?? $0.promptText).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count >= 3 }
            .max { StorySpark.score($0.userInput.nonEmpty ?? $0.promptText) < StorySpark.score($1.userInput.nonEmpty ?? $1.promptText) }

        try renderer.writePDF(to: url) { context in
            var pageIndex = 0

            func beginPage(margins: UIEdgeInsets) -> PDFCursor {
                context.beginPage()
                var cursor = PDFCursor(bounds: pageBounds, margins: margins)
                cursor.seed = "weekly-issue-\(issue.number)"
                cursor.pageIndex = pageIndex
                pageIndex += 1
                Monthly.drawComposedBackground(style: style, seed: cursor.pageSeed, in: pageBounds)
                drawCentered("The Book of You \u{00B7} Weekly Issue No. \(issue.number)", font: .systemFont(ofSize: 8, weight: .semibold), color: ink.withAlphaComponent(0.42), y: 30, in: pageBounds)
                drawCentered("Made with ReEnchanted \u{00B7} reenchanted.app", font: .systemFont(ofSize: 8.5, weight: .semibold), color: ink.withAlphaComponent(0.48), y: pageBounds.height - 42, in: pageBounds)
                return cursor
            }

            func ensureSpace(_ needed: CGFloat, cursor: inout PDFCursor, margins: UIEdgeInsets) {
                if cursor.y + needed > cursor.bottom {
                    cursor = beginPage(margins: margins)
                }
            }

            /// A torn label taped across the leaf — the issue's section headers.
            func drawTornLabel(_ text: String, cursor: inout PDFCursor) {
                let font = UIFont.serifFont(ofSize: 15, weight: .bold)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink.withAlphaComponent(0.88)]
                let size = (text as NSString).size(withAttributes: attributes)
                let scrap = CGRect(x: cursor.left - 8, y: cursor.y - 6, width: size.width + 44, height: size.height + 16)
                Monthly.drawTornScrap(
                    in: scrap,
                    rotation: (Monthly.frac("\(cursor.pageSeed)-label-\(text)") - 0.5) * 0.06,
                    fill: Monthly.blend(Monthly.parchment(for: style).top, accent, 0.10),
                    seed: "\(cursor.pageSeed)-label-\(text)"
                )
                (text as NSString).draw(at: CGPoint(x: cursor.left + 12, y: cursor.y + 2), withAttributes: attributes)
                Monthly.drawTapeStrip(
                    center: CGPoint(x: scrap.midX, y: scrap.minY + 2),
                    length: 46,
                    angle: (Monthly.frac("\(cursor.pageSeed)-tape-\(text)") - 0.5) * 0.4,
                    tint: style.palette.gold
                )
                cursor.y += scrap.height + 16
            }

            /// Body prose with an illuminated drop capital on the first paragraph.
            func drawDropCapProse(_ text: String, fontSize: CGFloat, cursor: inout PDFCursor) {
                let paragraphs = text
                    .components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                for (index, paragraph) in paragraphs.enumerated() {
                    if index == 0, let first = paragraph.first {
                        let capital = String(first)
                        let capAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.serifFont(ofSize: fontSize * 3.4, weight: .bold),
                            .foregroundColor: accent
                        ]
                        let capSize = (capital as NSString).size(withAttributes: capAttributes)
                        (capital as NSString).draw(at: CGPoint(x: cursor.left, y: cursor.y - 4), withAttributes: capAttributes)
                        Monthly.drawText(
                            String(paragraph.dropFirst()),
                            font: .serifFont(ofSize: fontSize, weight: .regular),
                            color: ink.withAlphaComponent(0.90),
                            cursor: &cursor,
                            spacingAfter: 14,
                            leftInset: capSize.width + 6,
                            firstLineOnlyInsetHeight: capSize.height
                        )
                    } else {
                        Monthly.drawText(
                            paragraph,
                            font: .serifFont(ofSize: fontSize, weight: .regular),
                            color: ink.withAlphaComponent(0.90),
                            cursor: &cursor,
                            spacingAfter: 14
                        )
                    }
                }
            }

            /// A torn note taped into the left gutter, in the monthly's hand.
            func drawMarginNote(_ note: String, top: CGFloat, cursor: PDFCursor) {
                guard top + 140 < pageBounds.height - 60 else { return }
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 1.5
                let attributed = NSAttributedString(string: note, attributes: [
                    .font: UIFont.serifItalicFont(ofSize: 8),
                    .foregroundColor: ink.withAlphaComponent(0.62),
                    .paragraphStyle: paragraph
                ])
                let measured = attributed.boundingRect(
                    with: CGSize(width: 70, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let seed = "\(cursor.pageSeed)-margin-\(note.prefix(12))"
                let scrap = CGRect(x: 16, y: top + 8, width: 86, height: min(118, measured.height + 18))
                Monthly.drawTornScrap(
                    in: scrap,
                    rotation: (Monthly.frac("\(seed)-rot") - 0.5) * 0.14,
                    fill: Monthly.blend(Monthly.parchment(for: style).top, style.palette.gold, 0.12),
                    seed: seed
                )
                attributed.draw(in: CGRect(x: scrap.minX + 8, y: scrap.minY + 9, width: 70, height: measured.height))
                Monthly.drawTapeStrip(
                    center: CGPoint(x: scrap.midX, y: scrap.minY + 2),
                    length: 40,
                    angle: (Monthly.frac("\(seed)-tape") - 0.5) * 0.5,
                    tint: style.palette.gold
                )
            }

            // ---- Front page: masthead, editor's note, pull quote, contents ----

            var cursor = beginPage(margins: frontMargins)
            drawCentered("T H E   B O O K   O F   Y O U", font: .systemFont(ofSize: 10, weight: .bold), color: ink.withAlphaComponent(0.64), y: cursor.y, in: pageBounds)
            cursor.y += 30
            drawCentered("Issue No. \(issue.number)", font: .serifFont(ofSize: 42, weight: .bold), color: ink, y: cursor.y, in: pageBounds)
            cursor.y += 54
            drawCentered(readerName, font: .serifItalicFont(ofSize: 15), color: ink.withAlphaComponent(0.70), y: cursor.y, in: pageBounds)
            cursor.y += 26
            drawCentered(issue.dateRange.uppercased(), font: .systemFont(ofSize: 10, weight: .semibold), color: accent, y: cursor.y, in: pageBounds)
            cursor.y += 28
            thickRule(accent.withAlphaComponent(0.48), cursor: &cursor)
            cursor.y += 16

            let lead = editorialNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? (issue.isFirstIssue
                    ? "Your first week, bound. Seven days after the Book opened, \(issue.keptCount) \(issue.keptCount == 1 ? "page" : "pages") had enough ink to become an issue."
                    : "Your week became an issue. Another seven days closed, and \(issue.keptCount) \(issue.keptCount == 1 ? "page" : "pages") had enough ink to hold together.")
            drawDropCapProse(lead, fontSize: 12.5, cursor: &cursor)

            if let bright = issue.highlights.first {
                cursor.y += 4
                Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
                cursor.y += 18
                draw("\u{201C}\(bright).\u{201D}", font: .serifItalicFont(ofSize: 15), color: ink.withAlphaComponent(0.84), centered: true, cursor: &cursor, bounds: pageBounds, after: 24)
            } else {
                cursor.y += 12
            }

            drawTornLabel("In This Issue", cursor: &cursor)
            var contents: [(String, String)] = []
            if issue.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil {
                contents.append(("The Week, Bound", "the daily bindings become one story"))
            }
            contents.append(("The Seven Days", "the week, day by day"))
            if bestPage != nil {
                contents.append(("The Week's Page", "one page, set full"))
            }
            if !plates.isEmpty {
                contents.append(("Plates", "\(plates.count) scrapbook \(plates.count == 1 ? "page" : "pages")"))
            }
            contents.append(("The Wrapped Week", "refrain, tallies & next week"))
            for (title, note) in contents {
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.serifFont(ofSize: 12.5, weight: .semibold),
                    .foregroundColor: ink.withAlphaComponent(0.88)
                ]
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.serifItalicFont(ofSize: 10.5),
                    .foregroundColor: ink.withAlphaComponent(0.58)
                ]
                let titleSize = (title as NSString).size(withAttributes: titleAttributes)
                let noteSize = (note as NSString).size(withAttributes: noteAttributes)
                (title as NSString).draw(at: CGPoint(x: cursor.left + 6, y: cursor.y), withAttributes: titleAttributes)
                (note as NSString).draw(at: CGPoint(x: cursor.right - noteSize.width, y: cursor.y + 2), withAttributes: noteAttributes)
                let dotsStart = cursor.left + 6 + titleSize.width + 10
                let dotsEnd = cursor.right - noteSize.width - 10
                if dotsEnd > dotsStart {
                    accent.withAlphaComponent(0.45).setFill()
                    var x = dotsStart
                    while x < dotsEnd {
                        UIBezierPath(ovalIn: CGRect(x: x, y: cursor.y + 9, width: 1.6, height: 1.6)).fill()
                        x += 6
                    }
                }
                cursor.y += 24
            }

            // ---- The Week, Bound: daily Book of You bindings as one story ----

            if let bindingStory = issue.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                cursor = beginPage(margins: readingMargins)
                drawTornLabel("The Week, Bound", cursor: &cursor)
                Monthly.drawText(
                    "A binding of the week's nightly bindings",
                    font: .serifItalicFont(ofSize: 10.5),
                    color: ink.withAlphaComponent(0.58),
                    cursor: &cursor,
                    spacingAfter: 18
                )
                drawDropCapProse(bindingStory, fontSize: 12.5, cursor: &cursor)
                cursor.y += 4
                Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
                cursor.y += 22
            }

            // ---- The Seven Days: the week, day by day, in the reader's ink ----

            cursor = beginPage(margins: readingMargins)
            drawTornLabel("The Seven Days", cursor: &cursor)

            let weekStart = calendar.startOfDay(for: issue.startDate)
            let pagesByDay = Dictionary(grouping: prosePages) { calendar.startOfDay(for: $0.createdAt) }
            let marginalia = marginaliaLines(issue: issue, card: card)
            var marginaliaIndex = 0

            for dayOffset in 0..<WeeklyIssue.weekDays {
                guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let dayPages = (pagesByDay[dayDate] ?? []).sorted { $0.createdAt < $1.createdAt }
                let weekday = weekdayFormatter.string(from: dayDate)
                ensureSpace(dayPages.isEmpty ? 64 : 120, cursor: &cursor, margins: readingMargins)

                accent.setFill()
                UIBezierPath(rect: CGRect(x: cursor.left, y: cursor.y + 4, width: 30, height: 1.6)).fill()
                Monthly.drawText(
                    "\(weekday.uppercased()) \u{00B7} \(dayFormatter.string(from: dayDate))",
                    font: .systemFont(ofSize: 9, weight: .heavy),
                    color: accent,
                    cursor: &cursor,
                    spacingAfter: 6,
                    leftInset: 38
                )

                if dayPages.isEmpty {
                    let quiet = quietLines[ConstellationKeeper.stableIndex(for: "weekly-\(issue.number)-quiet-\(dayOffset)", count: quietLines.count)]
                    Monthly.drawText("\(weekday) \(quiet)", font: .serifItalicFont(ofSize: 11), color: ink.withAlphaComponent(0.55), cursor: &cursor, spacingAfter: 18)
                    continue
                }
                for page in dayPages.prefix(2) {
                    ensureSpace(64, cursor: &cursor, margins: readingMargins)
                    let itemTop = cursor.y
                    Monthly.drawText(
                        "\(page.type.title) \u{00B7} \(timeFormatter.string(from: page.createdAt).lowercased())",
                        font: .systemFont(ofSize: 8, weight: .semibold),
                        color: ink.withAlphaComponent(0.50),
                        cursor: &cursor,
                        spacingAfter: 4
                    )
                    Monthly.drawText(
                        clamp(page.userInput.nonEmpty ?? page.promptText, limit: 340),
                        font: .serifFont(ofSize: 11.5, weight: .regular),
                        color: ink.withAlphaComponent(0.88),
                        cursor: &cursor,
                        spacingAfter: 14
                    )
                    if marginaliaIndex < marginalia.count,
                       ConstellationKeeper.stableIndex(for: "weekly-\(issue.number)-margin-\(dayOffset)-\(page.id)", count: 3) == 0 {
                        drawMarginNote(marginalia[marginaliaIndex], top: itemTop, cursor: cursor)
                        marginaliaIndex += 1
                    }
                }
                if dayPages.count > 2 {
                    Monthly.drawText(
                        "\u{2026}and \(dayPages.count - 2) more kept that day.",
                        font: .serifItalicFont(ofSize: 9.5),
                        color: ink.withAlphaComponent(0.50),
                        cursor: &cursor,
                        spacingAfter: 16
                    )
                }
            }

            // ---- The Week's Page: the strongest page, set full ----

            if let best = bestPage {
                cursor = beginPage(margins: readingMargins)
                drawTornLabel("The Week's Page", cursor: &cursor)
                Monthly.drawText(
                    "\(fullDateFormatter.string(from: best.createdAt)) \u{00B7} \(best.type.title)",
                    font: .systemFont(ofSize: 9, weight: .heavy),
                    color: accent,
                    cursor: &cursor,
                    spacingAfter: 14
                )
                drawDropCapProse(clamp(best.userInput.nonEmpty ?? best.promptText, limit: 1400), fontSize: 13, cursor: &cursor)
                cursor.y += 6
                Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
                cursor.y += 22
                if let image = Monthly.firstImage(from: best.mediaAssets) {
                    ensureSpace(260, cursor: &cursor, margins: readingMargins)
                    Monthly.drawFramedImage(image, style: style, context: context, cursor: &cursor)
                }
            }

            // ---- Plates: the week's scrapbook pages, matted and taped ----

            let plateNumerals = ["I", "II", "III", "IV"]
            for (index, plate) in plates.enumerated() {
                cursor = beginPage(margins: frontMargins)
                let title = plate.page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Scrapbook Page"
                drawCentered("P L A T E   \(plateNumerals[min(index, plateNumerals.count - 1)])", font: .systemFont(ofSize: 9, weight: .heavy), color: ink.withAlphaComponent(0.55), y: cursor.y, in: pageBounds)
                cursor.y += 24
                drawCentered(title, font: .serifFont(ofSize: 20, weight: .bold), color: ink, y: cursor.y, in: pageBounds)
                cursor.y += 34
                drawCentered(dayFormatter.string(from: plate.page.createdAt), font: .systemFont(ofSize: 9, weight: .semibold), color: accent, y: cursor.y, in: pageBounds)
                cursor.y += 28

                let image = plate.image
                let maxRect = CGRect(x: 74, y: cursor.y, width: pageBounds.width - 148, height: pageBounds.height - cursor.y - 118)
                let scale = min(maxRect.width / image.size.width, maxRect.height / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let rect = CGRect(
                    x: maxRect.midX - size.width / 2,
                    y: maxRect.minY + (maxRect.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
                let mat = rect.insetBy(dx: -10, dy: -10)
                style.palette.accentSoft.setFill()
                UIBezierPath(roundedRect: mat, cornerRadius: 5).fill()
                image.draw(in: rect)
                accent.withAlphaComponent(0.72).setStroke()
                let frame = UIBezierPath(roundedRect: mat, cornerRadius: 5)
                frame.lineWidth = 1.1
                frame.stroke()
                Monthly.drawTapeStrip(center: CGPoint(x: mat.minX + 14, y: mat.minY + 4), length: 44, angle: -0.6, tint: style.palette.gold)
                Monthly.drawTapeStrip(center: CGPoint(x: mat.maxX - 14, y: mat.minY + 4), length: 44, angle: 0.6, tint: style.palette.gold)

                if let caption = plate.page.mediaAssets.first?.caption.nonEmpty, caption != title {
                    drawCentered(caption, font: .serifItalicFont(ofSize: 10), color: ink.withAlphaComponent(0.62), y: pageBounds.height - 74, in: pageBounds.insetBy(dx: 70, dy: 0))
                }
            }

            // ---- The Wrapped Week: refrain, tallies, closing, next week ----

            cursor = beginPage(margins: frontMargins)
            drawTornLabel("The Wrapped Week", cursor: &cursor)
            cursor.y += 4
            drawCentered(card.title, font: .serifFont(ofSize: 30, weight: .bold), color: ink, y: cursor.y, in: pageBounds)
            cursor.y += 46
            draw(card.subtitle, font: .serifItalicFont(ofSize: 12.5), color: ink.withAlphaComponent(0.76), centered: true, cursor: &cursor, bounds: pageBounds, after: 18)
            drawStatGrid(card.stats, cursor: &cursor, bounds: pageBounds, ink: ink, accent: accent)
            cursor.y += 14
            drawWrappedPanel(title: "The week's refrain", body: card.motifLine, color: accent, ink: ink, cursor: &cursor, bounds: pageBounds)
            if issue.scrapbookCount > 0, plates.isEmpty {
                let titles = issue.scrapbookTitles.joined(separator: ", ")
                drawWrappedPanel(
                    title: "Scrapbook plates",
                    body: titles.isEmpty ? "\(issue.scrapbookCount) composed page\(issue.scrapbookCount == 1 ? "" : "s") joined the issue." : titles,
                    color: style.palette.gold,
                    ink: ink,
                    cursor: &cursor,
                    bounds: pageBounds
                )
            }
            if let setAsideLine = issue.setAsideLine {
                draw(setAsideLine, font: .serifItalicFont(ofSize: 10), color: ink.withAlphaComponent(0.58), centered: false, cursor: &cursor, bounds: pageBounds, after: 10)
            }

            let closing = closingNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? "The month and the year are still gathering. This week is already whole."
            cursor.y = max(cursor.y + 16, pageBounds.height - 264)
            Monthly.drawOrnamentRow(style, centerY: cursor.y, in: pageBounds, color: accent)
            cursor.y += 18
            draw(closing, font: .serifItalicFont(ofSize: 11.5), color: ink.withAlphaComponent(0.72), centered: true, cursor: &cursor, bounds: pageBounds, after: 0)

            // Next week: a torn tease taped near the foot of the back page.
            let tease = card.nextIssueTease.nonEmpty ?? "Issue No. \(issue.number + 1) is already gathering."
            let teaseParagraph = NSMutableParagraphStyle()
            teaseParagraph.alignment = .center
            teaseParagraph.lineSpacing = 2
            let teaseAttributed = NSAttributedString(string: tease, attributes: [
                .font: UIFont.serifItalicFont(ofSize: 11),
                .foregroundColor: ink.withAlphaComponent(0.80),
                .paragraphStyle: teaseParagraph
            ])
            let teaseMeasured = teaseAttributed.boundingRect(
                with: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let scrapWidth = min(356, teaseMeasured.width + 64)
            let scrapHeight = teaseMeasured.height + 44
            let teaseScrap = CGRect(x: pageBounds.midX - scrapWidth / 2, y: pageBounds.height - 92 - scrapHeight, width: scrapWidth, height: scrapHeight)
            Monthly.drawTornScrap(
                in: teaseScrap,
                rotation: (Monthly.frac("weekly-\(issue.number)-tease-rot") - 0.5) * 0.08,
                fill: Monthly.blend(Monthly.parchment(for: style).top, style.palette.gold, 0.10),
                seed: "weekly-\(issue.number)-tease"
            )
            drawCentered("NEXT WEEK", font: .systemFont(ofSize: 7.5, weight: .heavy), color: accent, y: teaseScrap.minY + 10, in: pageBounds)
            teaseAttributed.draw(in: CGRect(x: teaseScrap.minX + 16, y: teaseScrap.minY + 24, width: scrapWidth - 32, height: teaseMeasured.height + 4))
            Monthly.drawTapeStrip(
                center: CGPoint(x: teaseScrap.midX, y: teaseScrap.minY + 2),
                length: 48,
                angle: (Monthly.frac("weekly-\(issue.number)-tease-tape") - 0.5) * 0.4,
                tint: style.palette.gold
            )
        }
    }

    // MARK: - Issue material

    /// What the gutter whispers on the Seven Days pages: the week's refrain
    /// first, then the Book's own small asides.
    private static func marginaliaLines(issue: WeeklyIssue, card: WeeklyIssueShareCard) -> [String] {
        var lines: [String] = []
        let refrainPrefix = "Refrain: "
        if card.motifLine.hasPrefix(refrainPrefix) {
            let motifs = card.motifLine.dropFirst(refrainPrefix.count).components(separatedBy: ", ")
            for motif in motifs.prefix(3) where !motif.isEmpty {
                lines.append("\(motif.capitalized) again. The week insists.")
            }
        }
        lines.append(contentsOf: [
            "Kept, so it cannot blur.",
            "The week noticed you noticing.",
            "Same ink, new week.",
            "Read it twice; it settles."
        ])
        return lines
    }

    /// How a day with no kept pages is set — honest, never scolding.
    /// Completed with the weekday name: "Tuesday kept its own counsel."
    private static let quietLines = [
        "kept its own counsel.",
        "passed without ink \u{2014} not every day asks to be written down.",
        "left no pages, only weather.",
        "went unrecorded, the way some days prefer.",
        "held still and offered nothing it wanted kept."
    ]

    /// Trims a page's ink to a bindable length at a word boundary.
    private static func clamp(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let cut = trimmed.prefix(limit)
        let atWord = cut.lastIndex(where: { $0 == " " || $0 == "\n" }).map { cut[..<$0] } ?? cut
        return String(atWord).trimmingCharacters(in: .whitespacesAndNewlines) + "\u{2026}"
    }

    // MARK: - Local drawing helpers

    private static func thickRule(_ color: UIColor, cursor: inout PDFCursor) {
        color.setFill()
        UIBezierPath(rect: CGRect(x: cursor.left, y: cursor.y, width: cursor.contentWidth, height: 1.4)).fill()
        cursor.y += 7
    }

    private static func drawStatGrid(_ stats: [String], cursor: inout PDFCursor, bounds: CGRect, ink: UIColor, accent: UIColor) {
        let shown = Array(stats.prefix(4))
        guard !shown.isEmpty else { return }
        let gap: CGFloat = 12
        let columnWidth = (cursor.contentWidth - gap) / 2
        let startY = cursor.y
        for (index, stat) in shown.enumerated() {
            let column = index % 2
            let row = index / 2
            let rect = CGRect(
                x: cursor.left + CGFloat(column) * (columnWidth + gap),
                y: startY + CGFloat(row) * 74,
                width: columnWidth,
                height: 58
            )
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
            accent.withAlphaComponent(0.14).setFill()
            path.fill()
            accent.withAlphaComponent(0.34).setStroke()
            path.lineWidth = 1
            path.stroke()
            drawCentered(stat.uppercased(), font: .systemFont(ofSize: 9, weight: .heavy), color: ink.withAlphaComponent(0.75), y: rect.minY + 22, in: rect)
        }
        cursor.y += CGFloat((shown.count + 1) / 2) * 74
    }

    private static func drawWrappedPanel(title: String, body: String, color: UIColor, ink: UIColor, cursor: inout PDFCursor, bounds: CGRect) {
        let rect = CGRect(x: cursor.left, y: cursor.y, width: cursor.contentWidth, height: 116)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
        color.withAlphaComponent(0.11).setFill()
        path.fill()
        color.withAlphaComponent(0.34).setStroke()
        path.lineWidth = 1
        path.stroke()
        var inner = PDFCursor(bounds: bounds, margins: UIEdgeInsets(top: rect.minY + 16, left: rect.minX + 18, bottom: bounds.height - rect.maxY + 16, right: bounds.width - rect.maxX + 18))
        draw(title.uppercased(), font: .systemFont(ofSize: 8.5, weight: .heavy), color: color, centered: false, cursor: &inner, bounds: bounds, after: 8)
        draw(body, font: .serifFont(ofSize: 11.5, weight: .regular), color: ink.withAlphaComponent(0.86), centered: false, cursor: &inner, bounds: bounds, after: 0)
        cursor.y += rect.height + 18
    }

    private static func drawCentered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, in bounds: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    private static func draw(
        _ text: String,
        font: UIFont,
        color: UIColor,
        centered: Bool,
        cursor: inout PDFCursor,
        bounds: CGRect,
        after: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.alignment = centered ? .center : .natural
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let rect = attributed.boundingRect(
            with: CGSize(width: cursor.contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        attributed.draw(in: CGRect(x: cursor.left, y: cursor.y, width: cursor.contentWidth, height: rect.height + 4))
        cursor.y += rect.height + 4 + after
    }
}
