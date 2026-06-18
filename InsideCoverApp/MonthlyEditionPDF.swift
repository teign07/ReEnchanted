import Foundation
import UIKit
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
    static func write(_ edition: MonthlyEdition, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let style = EditionStyle.style(for: edition)
        let margins = UIEdgeInsets(top: 60, left: 120, bottom: 64, right: 58)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let marginalia = marginaliaLines(for: edition)

        try renderer.writePDF(to: url) { context in
            var cursor = PDFCursor(bounds: pageBounds, margins: margins)
            var marginaliaIndex = 0

            context.beginPage()
            drawCover(edition, style: style, bounds: pageBounds)

            if !edition.foreword.isEmpty {
                context.beginPage()
                cursor.reset()
                drawForeword(edition, style: style, context: context, cursor: &cursor)
            }

            if let theme = edition.theme {
                context.beginPage()
                cursor.reset()
                drawThemePage(theme, edition: edition, style: style, bounds: pageBounds, cursor: &cursor)
            }

            let aliveConstellations = edition.constellations.filter(\.isAlive)
            if !aliveConstellations.isEmpty {
                context.beginPage()
                drawStarChart(aliveConstellations, edition: edition, style: style, bounds: pageBounds)
            }

            context.beginPage()
            cursor.reset()
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

            drawColophon(edition, style: style, context: context, cursor: &cursor)
        }
    }

    // MARK: Annual (the whole year, bound as a book of chapters)

    static func writeAnnual(_ annual: AnnualEdition, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margins = UIEdgeInsets(top: 60, left: 120, bottom: 64, right: 58)
        let annualStyle = annualStyle(for: annual)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: url) { context in
            var cursor = PDFCursor(bounds: pageBounds, margins: margins)

            // Grand cover.
            context.beginPage()
            drawAnnualCover(annual, style: annualStyle, bounds: pageBounds)

            // The year's foreword, in the Book's voice.
            if !annual.foreword.isEmpty {
                context.beginPage()
                cursor.reset()
                drawAnnualForeword(annual, style: annualStyle, context: context, cursor: &cursor)
            }

            // The table of the year: every chapter and its theme.
            context.beginPage()
            cursor.reset()
            drawAnnualContents(annual, style: annualStyle, cursor: &cursor)

            // Each month-chapter, bound in its own style.
            for chapter in annual.chapters {
                let chapterStyle = EditionStyle.style(for: chapter)
                let marginalia = marginaliaLines(for: chapter)
                var marginaliaIndex = 0

                context.beginPage()
                drawChapterDivider(chapter, style: chapterStyle, bounds: pageBounds)

                if !chapter.foreword.isEmpty {
                    context.beginPage()
                    cursor.reset()
                    drawForeword(chapter, style: chapterStyle, context: context, cursor: &cursor)
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
            ensureSpace(90, context: context, cursor: &cursor)
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
            let line = "\(constellation.displayName) \u{00B7} \(constellation.phase.title.lowercased()) \u{00B7} \(constellation.sightingCount) sightings"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.serifFont(ofSize: 11, weight: .regular),
                .foregroundColor: style.palette.coverText.withAlphaComponent(0.85)
            ]
            drawStar(at: CGPoint(x: 86, y: y + 5), radius: constellation.isNamed ? 3 : 2.2, color: style.palette.gold)
            (line as NSString).draw(at: CGPoint(x: 100, y: y - 2), withAttributes: attributes)
            y += 22
        }
    }

    private static func drawAnnualColophon(
        _ annual: AnnualEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        context.beginPage()
        cursor.reset()
        cursor.y = 96
        drawText(annual.closing, font: .serifItalicFont(ofSize: 13), color: style.palette.ink.withAlphaComponent(0.85), cursor: &cursor, spacingAfter: 30)

        cursor.y = cursor.bounds.midY + 40
        drawOrnamentRow(style, centerY: cursor.y, in: cursor.bounds, color: style.palette.accent)
        cursor.y += 26
        drawCentered("The Book of You \u{00B7} \(annual.readerName) \u{00B7} The \(annual.year) Annual", font: .serifItalicFont(ofSize: 12), color: style.palette.ink.withAlphaComponent(0.8), y: cursor.y, in: cursor.bounds)
        cursor.y += 22
        drawCentered("Bound by the Book itself, which read every page twice, and the year once more.", font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.55), y: cursor.y, in: cursor.bounds)
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
        if let theme = edition.theme {
            drawCentered(
                "\u{201C}\(theme.name)\u{201D}",
                font: .serifItalicFont(ofSize: 18),
                color: style.palette.gold,
                y: 498,
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
            let phase = constellation.phase.title.lowercased()
            let line = "\(constellation.displayName) \u{00B7} \(phase) \u{00B7} \(constellation.sightingCount) sightings"
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
            ensureSpace(90, context: context, cursor: &cursor)
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
        context.beginPage()
        cursor.reset()

        // Section opener band
        style.palette.accentSoft.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: cursor.y - 12, width: cursor.bounds.width, height: 64)).fill()
        style.palette.accent.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: cursor.y - 12, width: 6, height: 64)).fill()
        drawText(section.title, font: .serifFont(ofSize: 22, weight: .bold), color: style.palette.ink, cursor: &cursor, spacingAfter: 2)
        drawText(section.note, font: .serifItalicFont(ofSize: 10), color: style.palette.ink.withAlphaComponent(0.65), cursor: &cursor, spacingAfter: 22)

        for (index, item) in section.items.enumerated() {
            drawItem(
                item,
                style: style,
                showMarginNote: index % 3 == 1,
                marginalia: marginalia,
                marginaliaIndex: &marginaliaIndex,
                context: context,
                cursor: &cursor
            )
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
        ensureSpace(110, context: context, cursor: &cursor)
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
        if item.kind == .image, let image = firstImage(from: item.mediaAssets) {
            drawFramedImage(image, style: style, context: context, cursor: &cursor)
            if let caption = item.mediaAssets.first?.caption, !caption.isEmpty {
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
            marginaliaIndex += 1
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 1
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.serifItalicFont(ofSize: 8),
                .foregroundColor: style.palette.accent.withAlphaComponent(0.85),
                .paragraphStyle: paragraph
            ]
            let rect = CGRect(x: 30, y: itemTop + 18, width: 76, height: 120)
            (note as NSString).draw(in: rect, withAttributes: attributes)
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

    private static func drawColophon(
        _ edition: MonthlyEdition,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        context.beginPage()
        cursor.reset()
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

    private static func drawOrnamentRow(_ style: EditionStyle, centerY: CGFloat, in bounds: CGRect, color: UIColor) {
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

    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor = .black,
        cursor: inout PDFCursor,
        spacingAfter: CGFloat,
        leftInset: CGFloat = 0,
        firstLineOnlyInsetHeight: CGFloat = 0
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let width = cursor.contentWidth - leftInset
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        attributed.draw(in: CGRect(x: cursor.left + leftInset, y: cursor.y, width: width, height: rect.height + 4))
        cursor.y += max(rect.height + 4, firstLineOnlyInsetHeight) + spacingAfter
    }

    private static func drawFramedImage(_ image: UIImage, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        let maxHeight: CGFloat = 210
        let scale = min(cursor.contentWidth / image.size.width, maxHeight / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        ensureSpace(size.height + 36, context: context, cursor: &cursor)
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

    private static func ensureSpace(_ needed: CGFloat, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor) {
        if cursor.y + needed > cursor.bottom {
            context.beginPage()
            cursor.reset()
        }
    }

    // MARK: Image resolution

    private static func firstImage(from assets: [BookPageMediaAsset]) -> UIImage? {
        for asset in assets {
            switch asset.kind {
            case .renderedImageFile:
                if let image = UIImage(contentsOfFile: asset.reference) { return image }
            case .bundledImage:
                if let image = UIImage(named: asset.reference) { return image }
            case .photoLibraryAsset:
                if let image = photoLibraryImage(localIdentifier: asset.reference) { return image }
            }
        }
        return nil
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

    init(bounds: CGRect, margins: UIEdgeInsets) {
        self.bounds = bounds
        self.margins = margins
        self.y = margins.top
    }

    var left: CGFloat { margins.left }
    var right: CGFloat { bounds.width - margins.right }
    var bottom: CGFloat { bounds.height - margins.bottom }
    var contentWidth: CGFloat { bounds.width - margins.left - margins.right }

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
    static func write(headline: String, body: String, to url: URL) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margins = UIEdgeInsets(top: 50, left: 56, bottom: 56, right: 56)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let ink = UIColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
        let rule = UIColor(red: 0.30, green: 0.26, blue: 0.22, alpha: 1)

        try renderer.writePDF(to: url) { context in
            var cursor = PDFCursor(bounds: pageBounds, margins: margins)
            context.beginPage()

            // Nameplate
            draw("The Bleed", font: .serifFont(ofSize: 44, weight: .black), color: ink, centered: true, cursor: &cursor, bounds: pageBounds, after: 4)
            draw("Where the Labyrinth meets the page. Where the page bleeds into the world.", font: .serifItalicFont(ofSize: 10), color: ink.withAlphaComponent(0.7), centered: true, cursor: &cursor, bounds: pageBounds, after: 8)
            thickRule(rule, cursor: &cursor)
            draw(headline, font: .systemFont(ofSize: 10, weight: .bold), color: ink.withAlphaComponent(0.8), centered: true, cursor: &cursor, bounds: pageBounds, after: 6)
            thickRule(rule, cursor: &cursor)
            cursor.y += 8

            for block in body.components(separatedBy: "\n\n") {
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if cursor.y > cursor.bottom - 90 {
                    context.beginPage()
                    cursor.reset()
                }
                if trimmed.hasPrefix("\u{2014}"), trimmed.contains("\u{2014}") {
                    // Column header block: "— TITLE —" plus byline line(s).
                    let lines = trimmed.components(separatedBy: "\n")
                    cursor.y += 6
                    draw(lines[0].trimmingCharacters(in: CharacterSet(charactersIn: "\u{2014} ")), font: .serifFont(ofSize: 16, weight: .bold), color: ink, centered: false, cursor: &cursor, bounds: pageBounds, after: 1)
                    for extra in lines.dropFirst() {
                        draw(extra, font: .serifItalicFont(ofSize: 9), color: ink.withAlphaComponent(0.6), centered: false, cursor: &cursor, bounds: pageBounds, after: 1)
                    }
                    cursor.y += 6
                } else {
                    draw(trimmed, font: .serifFont(ofSize: 10.5, weight: .regular), color: ink.withAlphaComponent(0.92), centered: false, cursor: &cursor, bounds: pageBounds, after: 10)
                }
            }
        }
    }

    private static func thickRule(_ color: UIColor, cursor: inout PDFCursor) {
        color.setFill()
        UIBezierPath(rect: CGRect(x: cursor.left, y: cursor.y, width: cursor.contentWidth, height: 1.6)).fill()
        cursor.y += 7
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
        paragraph.lineSpacing = 2.5
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
