import Foundation
import PDFKit
import UIKit

// MARK: - Keepsakes, on paper
//
// The month given back: pixels, a found poem, a passport, questions, eight words, a time capsule,
// and a leaf of bookmarks to cut out. See `HandbookKeepsakes`.

extension MonthlyEditionPDFWriter {

    // MARK: Entry points

    /// The month at a glance: what the reader kept, said and collected, before the coursework.
    static func drawKeepsakesFront(
        _ keepsakes: HandbookKeepsakes, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) {
        if let pixels = keepsakes.pixels { drawPixelsLeaf(pixels, style: style, context: context, cursor: &cursor) }
        if let photos = keepsakes.photos { drawPhotoLeaves(photos, style: style, context: context, cursor: &cursor) }
        if let superlatives = keepsakes.superlatives { drawSuperlativesLeaf(superlatives, style: style, context: context, cursor: &cursor) }
        if let poem = keepsakes.poem { drawPoemLeaf(poem, style: style, context: context, cursor: &cursor, monthNumber: monthNumber) }
        if let passport = keepsakes.passport {
            drawPassportLeaf(passport, style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        }
    }

    /// The part of the book to write in and cut out, last so scissors cost nothing.
    static func drawKeepsakesBack(
        _ keepsakes: HandbookKeepsakes, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) {
        if let index = keepsakes.index { drawIndexLeaf(index, style: style, context: context, cursor: &cursor) }
        if let questions = keepsakes.questions { drawQuestionsLeaf(questions, style: style, context: context, cursor: &cursor) }
        if let words = keepsakes.eightWords { drawEightWordsLeaf(words, style: style, context: context, cursor: &cursor) }
        if let capsule = keepsakes.capsule { drawCapsuleLeaf(capsule, style: style, context: context, cursor: &cursor) }
        if let cut = keepsakes.cutouts {
            drawCutouts(cut, year: keepsakes.pixels?.year ?? keepsakes.capsule.map { $0.openYear - 1 } ?? 0,
                        style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        }
    }

    // MARK: Small drawing helpers

    private static func kText(_ text: String, font: UIFont, color: UIColor, in rect: CGRect, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 2) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph], context: nil)
    }

    private static func kHeight(_ text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat = 2) -> CGFloat {
        FieldText.height(text, font: font, width: width, lineSpacing: lineSpacing, paragraphSpacing: 0, justified: false)
    }

    private static func drawFittedImage(_ image: UIImage, in rect: CGRect, rotation: CGFloat = 0) {
        guard let cg = UIGraphicsGetCurrentContext(), rect.width > 4, rect.height > 4 else { return }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let ready = PrintImage.fitted(image, drawnPoints: size)
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: rotation)
        ready.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        cg.restoreGState()
    }

    private static func dashed(_ path: UIBezierPath, color: UIColor, width: CGFloat = 0.6) {
        color.setStroke()
        path.lineWidth = width
        path.setLineDash([3.5, 3], count: 2, phase: 0)
        path.stroke()
    }

    private static func tint(_ style: EditionStyle, level: Int) -> UIColor {
        let alpha: [CGFloat] = [0, 0.2, 0.4, 0.65, 0.95]
        return style.palette.accent.withAlphaComponent(alpha[min(max(level, 0), 4)])
    }

    /// A moon, lit by `lit` (0...1), waxing on the right or waning on the left.
    static func drawMoon(center: CGPoint, radius: CGFloat, lit: Double, waning: Bool, ink: UIColor, light: UIColor) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        if waning {
            cg.translateBy(x: center.x * 2, y: 0)
            cg.scaleBy(x: -1, y: 1)
        }
        let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ink.setFill()
        UIBezierPath(ovalIn: disc).fill()
        let f = CGFloat(min(max(lit, 0), 1))
        light.setFill()
        let half = UIBezierPath()
        half.move(to: CGPoint(x: center.x, y: center.y - radius))
        half.addArc(withCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        half.close()
        half.fill()
        let rx = radius * abs(1 - 2 * f)
        if rx > 0.3 {
            (f >= 0.5 ? light : ink).setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - rx, y: center.y - radius, width: rx * 2, height: radius * 2)).fill()
        }
        cg.restoreGState()
        ink.setStroke()
        let ring = UIBezierPath(ovalIn: disc)
        ring.lineWidth = 0.6
        ring.stroke()
    }

    // MARK: Month in pixels

    private static func drawPixelsLeaf(
        _ p: HandbookKeepsakes.Pixels, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month at a glance", headRight: "In pixels")
        drawEyebrow("Every day, one circle", style: style, leaf: &leaf)
        hbText("\(p.monthName) in Pixels", font: .fbSerif(ofSize: 24, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 4)
        hbText("The more you kept on a day, the darker the ink. A circle left bare is a day you kept for yourself, which is allowed.",
               font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78), leaf: &leaf, justified: false, gap: 10)

        let cell = leaf.contentWidth / 7
        // The two grids and their words have to share one leaf; the rows give a little to fit.
        let wanted: CGFloat = 5 * cell * 0.74 + 6 * 26 + 190
        let room = leaf.bottom - leaf.y
        let squeeze = min(1, max(0.62, room / wanted))
        let rows = (p.leadingBlanks + p.levels.count + 6) / 7
        let rowH = cell * 0.74 * squeeze

        for (i, letter) in p.weekdayLetters.enumerated() {
            kText(letter, font: smallCaps(6.6), color: ink.withAlphaComponent(0.5),
                  in: CGRect(x: leaf.left + CGFloat(i) * cell, y: leaf.y, width: cell, height: 9), alignment: .center)
        }
        leaf.y += 12
        let radius = min(cell, rowH) * 0.4
        for index in 0..<p.levels.count {
            let slot = p.leadingBlanks + index
            let center = CGPoint(x: leaf.left + (CGFloat(slot % 7) + 0.5) * cell, y: leaf.y + (CGFloat(slot / 7) + 0.5) * rowH)
            let level = p.levels[index]
            let circle = UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            if level > 0 {
                tint(style, level: level).setFill()
                circle.fill()
            } else {
                dashed(circle, color: ink.withAlphaComponent(0.3))
            }
            kText("\(index + 1)", font: .fbSerif(ofSize: 7, weight: .semibold),
                  color: level >= 3 ? UIColor.white.withAlphaComponent(0.92) : ink.withAlphaComponent(0.6),
                  in: CGRect(x: center.x - radius, y: center.y - 4.5, width: radius * 2, height: 10), alignment: .center)
            // The moon that night, a pin-prick under the day.
            style.palette.gold.withAlphaComponent(0.25 + 0.75 * p.moon[index]).setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - 1.4, y: center.y + radius + 1.6, width: 2.8, height: 2.8)).fill()
        }
        leaf.y += CGFloat(rows) * rowH + 6

        var facts = ["Kept on \(p.keptDays) of \(p.levels.count) days"]
        if p.longestRun > 1 { facts.append("longest run \(p.longestRun) days") }
        if let busiest = p.busiestDay, p.busiestCount > 1 { facts.append("busiest: the \(busiest)\(ordinalSuffix(busiest)), \(p.busiestCount) things") }
        hbText(facts.joined(separator: "  ·  "), font: .fbSerifItalic(ofSize: 9.6), color: style.palette.accent, leaf: &leaf, justified: false, gap: 4)
        var x = leaf.left
        for level in 0...4 {
            let dot = UIBezierPath(ovalIn: CGRect(x: x, y: leaf.y + 1, width: 8, height: 8))
            if level == 0 { dashed(dot, color: ink.withAlphaComponent(0.4)) } else { tint(style, level: level).setFill(); dot.fill() }
            x += 12
        }
        kText("nothing   ·   a little   ·   a lot", font: .fbSerifItalic(ofSize: 8), color: ink.withAlphaComponent(0.55),
              in: CGRect(x: x + 4, y: leaf.y, width: 200, height: 10))
        leaf.y += 18

        // Next month: the reader's turn.
        guard leaf.bottom - leaf.y > 120 else { return }
        UIBezierPath(rect: CGRect(x: leaf.left + leaf.contentWidth * 0.35, y: leaf.y, width: leaf.contentWidth * 0.3, height: 0.5)).stroke()
        leaf.y += 8
        drawEyebrow("Next month, colour it yourself", style: style, leaf: &leaf)
        let smallCell = leaf.contentWidth / 7
        let blankRowH = min(smallCell * 0.6, (leaf.bottom - leaf.y - 34) / 5)
        let smallRadius = min(smallCell, blankRowH) * 0.36
        for index in 0..<31 {
            let slot = index
            let center = CGPoint(x: leaf.left + (CGFloat(slot % 7) + 0.5) * smallCell, y: leaf.y + (CGFloat(slot / 7) + 0.5) * blankRowH)
            let circle = UIBezierPath(ovalIn: CGRect(x: center.x - smallRadius, y: center.y - smallRadius, width: smallRadius * 2, height: smallRadius * 2))
            dashed(circle, color: ink.withAlphaComponent(0.34))
            kText("\(index + 1)", font: .fbSerif(ofSize: 6.4, weight: .medium), color: ink.withAlphaComponent(0.4),
                  in: CGRect(x: center.x - smallRadius, y: center.y - 4, width: smallRadius * 2, height: 9), alignment: .center)
        }
        leaf.y += 5 * blankRowH + 6
        if leaf.bottom - leaf.y > 14 {
            kText("Choose what each shade will mean to you, and write it here:", font: .fbSerifItalic(ofSize: 8.8),
                  color: ink.withAlphaComponent(0.6), in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 12))
            hbRules(from: leaf.y + 8, to: leaf.bottom, left: leaf.left, right: leaf.right, spacing: 15, style: style)
        }
    }

    private static func ordinalSuffix(_ n: Int) -> String {
        switch (n % 100, n % 10) {
        case (11...13, _): return "th"
        case (_, 1): return "st"
        case (_, 2): return "nd"
        case (_, 3): return "rd"
        default: return "th"
        }
    }

    // MARK: Photographs

    private static func drawFilledImage(_ image: UIImage, in rect: CGRect, corner: CGFloat = 3) {
        guard let cg = UIGraphicsGetCurrentContext(), image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let ready = PrintImage.fitted(image, drawnPoints: size)
        cg.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: corner).addClip()
        ready.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
        cg.restoreGState()
    }

    private static func drawPhotoLeaves(
        _ photos: HandbookKeepsakes.Photos, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let loaded: [(shot: HandbookKeepsakes.Photos.Shot, image: UIImage)] = photos.shots.compactMap { shot in
            firstImage(from: shot.assets).map { (shot, $0) }
        }
        guard loaded.count >= 3 else { return }
        let featuredShot = photos.shots.indices.contains(photos.featuredIndex) ? photos.shots[photos.featuredIndex] : loaded[0].shot
        let featured = loaded.first { $0.shot == featuredShot } ?? loaded[0]
        let rest = loaded.filter { $0.shot != featured.shot }

        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month at a glance", headRight: "Photographs")
        drawEyebrow("Everything you photographed", style: style, leaf: &leaf)
        hbText("\(photos.monthName) in Photographs", font: .fbSerif(ofSize: 22, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 10)

        // The one the Book would frame.
        let maxH = min(300, (leaf.bottom - leaf.y) * 0.56)
        let aspect = featured.image.size.width / max(1, featured.image.size.height)
        var frameW = min(leaf.contentWidth, maxH * aspect)
        var frameH = frameW / max(0.2, aspect)
        if frameH > maxH { frameH = maxH; frameW = frameH * aspect }
        let matte = CGRect(x: leaf.left + (leaf.contentWidth - frameW) / 2 - 7, y: leaf.y, width: frameW + 14, height: frameH + 14)
        UIColor.white.withAlphaComponent(0.92).setFill()
        UIBezierPath(rect: matte).fill()
        ink.withAlphaComponent(0.25).setStroke()
        let edge = UIBezierPath(rect: matte); edge.lineWidth = 0.5; edge.stroke()
        drawFilledImage(featured.image, in: CGRect(x: matte.minX + 7, y: matte.minY + 7, width: frameW, height: frameH), corner: 0)
        leaf.y = matte.maxY + 6
        kText("\(featured.shot.dateLabel)  ·  \(featured.shot.title)", font: .fbSerifItalic(ofSize: 9.8), color: style.palette.accent,
              in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 14), alignment: .center)
        leaf.y += 22

        func grid(_ items: ArraySlice<(shot: HandbookKeepsakes.Photos.Shot, image: UIImage)>, in leaf: inout PDFCursor) -> Int {
            // A few photographs are set larger; a crowd goes in a tight grid.
            let columns = min(4, max(2, items.count))
            let gap: CGFloat = 8
            let side = min(150, (leaf.contentWidth - gap * CGFloat(columns - 1)) / CGFloat(columns))
            let rowH = side + 15
            var drawn = 0
            for (index, item) in items.enumerated() {
                let row = index / columns
                let y = leaf.y + CGFloat(row) * rowH
                guard y + rowH <= leaf.bottom + 2 else { break }
                let rect = CGRect(x: leaf.left + CGFloat(index % columns) * (side + gap), y: y, width: side, height: side)
                UIColor.white.withAlphaComponent(0.85).setFill()
                UIBezierPath(rect: rect.insetBy(dx: -2.5, dy: -2.5)).fill()
                drawFilledImage(item.image, in: rect, corner: 0)
                kText(item.shot.dateLabel.uppercased(), font: smallCaps(5.6, weight: .semibold), color: ink.withAlphaComponent(0.55),
                      in: CGRect(x: rect.minX, y: rect.maxY + 4, width: rect.width, height: 8), alignment: .center)
                drawn += 1
            }
            return drawn
        }

        let shown = grid(rest[...], in: &leaf)
        if shown < rest.count {
            var more = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month at a glance", headRight: "Photographs")
            drawEyebrow("The rest of them", style: style, leaf: &more)
            _ = grid(rest[shown...], in: &more)
        }
    }

    // MARK: Superlatives

    private static func drawSuperlativesLeaf(
        _ s: HandbookKeepsakes.Superlatives, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month at a glance", headRight: "Superlatives")
        drawEyebrow("Voted on by one person", style: style, leaf: &leaf)
        hbText("\(s.monthName) Superlatives", font: .fbSerif(ofSize: 23, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 4)
        hbText("The yearbook committee has gone through your month and awarded what it earned. Nothing here was made up.",
               font: .fbSerifItalic(ofSize: 9.8), color: ink.withAlphaComponent(0.72), leaf: &leaf, justified: false, gap: 12)
        let columns = 2
        let gap: CGFloat = 10
        let width = (leaf.contentWidth - gap) / 2
        let rows = (s.awards.count + 1) / 2
        let height = min(118, (leaf.bottom - leaf.y - gap * CGFloat(rows - 1)) / CGFloat(rows))
        for (index, award) in s.awards.enumerated() {
            let rect = CGRect(x: leaf.left + CGFloat(index % columns) * (width + gap), y: leaf.y + CGFloat(index / columns) * (height + gap), width: width, height: height)
            drawCardFrame(rect, style: style, double: true)
            kText(award.title.uppercased(), font: smallCaps(5.8, weight: .semibold), color: style.palette.accent,
                  in: CGRect(x: rect.minX + 10, y: rect.minY + 12, width: rect.width - 20, height: 16), alignment: .center)
            let headlineFont: UIFont = .fbSerif(ofSize: award.headline.count > 14 ? 12 : 17, weight: .bold)
            kText(award.headline, font: headlineFont, color: ink, in: CGRect(x: rect.minX + 10, y: rect.minY + 34, width: rect.width - 20, height: 44), alignment: .center, lineSpacing: 1.5)
            kText(award.detail, font: .fbSerifItalic(ofSize: 8.2), color: ink.withAlphaComponent(0.7),
                  in: CGRect(x: rect.minX + 12, y: rect.minY + 34 + (award.headline.count > 14 ? 40 : 28), width: rect.width - 24, height: rect.height - 74), alignment: .center, lineSpacing: 1.6)
        }
    }

    // MARK: Found poem

    private static func drawPoemLeaf(
        _ poem: HandbookKeepsakes.Poem, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month at a glance", headRight: "Found in your pages")
        drawEyebrow("A poem you wrote without knowing", style: style, leaf: &leaf)
        hbText(poem.title, font: .fbSerifItalic(ofSize: 25), color: ink, leaf: &leaf, justified: false, gap: 6)
        hbText("Nothing here was written for this page. Every line is yours, set down in the order you said it.",
               font: .fbSerifItalic(ofSize: 9.6), color: ink.withAlphaComponent(0.65), leaf: &leaf, justified: false, gap: 16)

        let lineFont = UIFont.fbSerifItalic(ofSize: 12.4)
        let textWidth = leaf.contentWidth - 54
        let lineCount = poem.stanzas.flatMap { $0 }.count
        let totalHeight = poem.stanzas.flatMap { $0 }.reduce(CGFloat(0)) { $0 + kHeight($1.text, font: lineFont, width: textWidth, lineSpacing: 2) + 5 }
            + CGFloat(max(0, poem.stanzas.count - 1)) * 15
        // The poem sits a little below the middle of the room it has.
        let room = leaf.bottom - leaf.y - 60
        if totalHeight < room { leaf.y += min(24, (room - totalHeight) / 3) }
        for stanza in poem.stanzas {
            for line in stanza {
                let height = kHeight(line.text, font: lineFont, width: textWidth, lineSpacing: 2)
                guard leaf.y + height < leaf.bottom - 40 else { break }
                kText(line.text, font: lineFont, color: ink.withAlphaComponent(0.92),
                      in: CGRect(x: leaf.left + 8, y: leaf.y, width: textWidth, height: height + 2), lineSpacing: 2)
                kText(line.dateLabel, font: smallCaps(6.2, weight: .semibold), color: style.palette.accent.withAlphaComponent(0.8),
                      in: CGRect(x: leaf.right - 44, y: leaf.y + 3, width: 44, height: 9), alignment: .right)
                leaf.y += height + 5
            }
            leaf.y += 15
        }
        _ = lineCount
        drawOrnamentRow(style, centerY: min(leaf.y + 6, leaf.bottom - 20), in: leaf.bounds, color: style.palette.accent.withAlphaComponent(0.5))
        if let art = MarginaliaDealer.next(month: monthNumber) {
            drawFittedImage(art, in: CGRect(x: leaf.right - 88, y: leaf.bottom - 82, width: 80, height: 76), rotation: 0.06)
        }
    }

    // MARK: Passport

    private static func drawPassportLeaf(
        _ passport: HandbookKeepsakes.Passport, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The month at a glance", headRight: "Passport")
        let frame = CGRect(x: leaf.left, y: leaf.y - 2, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 6)
        drawCardFrame(frame, style: style, double: true)
        var inner = PDFCursor(bounds: leaf.bounds, margins: UIEdgeInsets(top: frame.minY + 14, left: frame.minX + 14, bottom: leaf.bounds.height - frame.maxY + 12, right: leaf.bounds.width - frame.maxX + 14))
        inner.y = frame.minY + 16
        drawEyebrow("The Book of You  ·  Passport", style: style, leaf: &inner)
        hbText("\(passport.monthName) \(passport.year)", font: .fbSerif(ofSize: 22, weight: .bold), color: ink, leaf: &inner, justified: false, gap: 3)
        hbText("One stamp for every day you kept something. A bare ring is a day you spent elsewhere.",
               font: .fbSerifItalic(ofSize: 9.4), color: ink.withAlphaComponent(0.68), leaf: &inner, justified: false, gap: 12)

        let columns = 6
        let gridWidth = inner.contentWidth
        let cell = gridWidth / CGFloat(columns)
        let rows = (passport.daysInMonth + columns - 1) / columns
        let rowH = min(cell * 1.3, (inner.bottom - inner.y - 50) / CGFloat(rows))
        let kept = Set(passport.keptDays)
        for day in 1...passport.daysInMonth {
            let slot = day - 1
            let center = CGPoint(x: inner.left + (CGFloat(slot % columns) + 0.5) * cell, y: inner.y + (CGFloat(slot / columns) + 0.5) * rowH)
            let radius = min(cell, rowH) * 0.41
            let ring = UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            if kept.contains(day) {
                let tilt = (CGFloat(HandbookBuilder.stableHash("stamp-\(day)") % 100) / 100 - 0.5) * 0.3
                if let art = MarginaliaDealer.next(month: monthNumber) {
                    drawFittedImage(art, in: CGRect(x: center.x - radius * 0.95, y: center.y - radius * 0.95, width: radius * 1.9, height: radius * 1.9 * 0.94), rotation: tilt)
                }
                style.palette.accent.withAlphaComponent(0.6).setStroke()
                ring.lineWidth = 0.9
                ring.stroke()
            } else {
                dashed(ring, color: ink.withAlphaComponent(0.25))
            }
            kText("\(day)", font: smallCaps(6, weight: .semibold), color: ink.withAlphaComponent(kept.contains(day) ? 0.7 : 0.35),
                  in: CGRect(x: center.x - radius, y: center.y + radius + 1, width: radius * 2, height: 8), alignment: .center)
        }
        inner.y += CGFloat(rows) * rowH + 8
        kText("\(passport.keptDays.count) stamps of \(passport.daysInMonth) days", font: .fbSerifItalic(ofSize: 10.4), color: style.palette.accent,
              in: CGRect(x: inner.left, y: min(inner.y, frame.maxY - 26), width: inner.contentWidth, height: 14), alignment: .center)
    }

    // MARK: Index

    private static func drawIndexLeaf(
        _ index: HandbookKeepsakes.Index, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Keepsakes", headRight: "Index")
        drawEyebrow("Like any real book", style: style, leaf: &leaf)
        hbText("An Index of \(index.monthName)", font: .fbSerif(ofSize: 22, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 4)
        hbText("The words you kept coming back to, and the days of the month they came up. Look up a word, then find the day.",
               font: .fbSerifItalic(ofSize: 9.4), color: ink.withAlphaComponent(0.72), leaf: &leaf, justified: false, gap: 10)

        // Rows: letter headings for the words, then the Cast and the rooms.
        enum Row { case letter(String), entry(String, String), heading(String) }
        var rows: [Row] = []
        var lastLetter = ""
        for entry in index.words {
            let letter = String(entry.term.prefix(1)).uppercased()
            if letter != lastLetter { rows.append(.letter(letter)); lastLetter = letter }
            rows.append(.entry(entry.term, entry.locator))
        }
        if !index.cast.isEmpty {
            rows.append(.heading("The Cast, by the days they spoke"))
            rows += index.cast.map { .entry($0.term, $0.locator) }
        }
        if !index.rooms.isEmpty {
            rows.append(.heading("Rooms of the Labyrinth"))
            rows += index.rooms.map { .entry($0.term, $0.locator) }
        }

        let columns = 2
        let gutter: CGFloat = 18
        let colWidth = (leaf.contentWidth - gutter) / 2
        let lineH: CGFloat = 12.4
        let capacity = max(1, Int((leaf.bottom - leaf.y - 6) / lineH))
        // Two even columns, like a real index, whenever the whole of it fits.
        let perColumn = rows.count <= capacity * 2 ? max(1, (rows.count + 1) / 2) : capacity
        var column = 0, row = 0
        for item in rows {
            if row >= perColumn { column += 1; row = 0 }
            guard column < columns else { break }
            let x = leaf.left + CGFloat(column) * (colWidth + gutter)
            let y = leaf.y + CGFloat(row) * lineH
            switch item {
            case .letter(let l):
                kText(l, font: .fbSerif(ofSize: 10.4, weight: .bold), color: style.palette.accent, in: CGRect(x: x, y: y + 1, width: colWidth, height: 13))
            case .heading(let h):
                kText(h.uppercased(), font: smallCaps(5.8, weight: .semibold), color: style.palette.accent, in: CGRect(x: x, y: y + 4, width: colWidth, height: 9))
            case .entry(let term, let locator):
                kText(term, font: .fbSerif(ofSize: 8.6, weight: .regular), color: ink.withAlphaComponent(0.9), in: CGRect(x: x + 6, y: y + 1, width: colWidth * 0.64, height: 12))
                kText(locator, font: .fbSerifItalic(ofSize: 8), color: ink.withAlphaComponent(0.62), in: CGRect(x: x + colWidth * 0.56, y: y + 1.4, width: colWidth * 0.44, height: 12), alignment: .right)
                let dots = UIBezierPath()
                dots.move(to: CGPoint(x: x + 6 + min(colWidth * 0.48, CGFloat(term.count) * 4.6 + 6), y: y + 9.4))
                dots.addLine(to: CGPoint(x: x + colWidth - min(colWidth * 0.5, CGFloat(locator.count) * 4.2 + 8), y: y + 9.4))
                dashed(dots, color: ink.withAlphaComponent(0.2), width: 0.5)
            }
            row += 1
        }
    }

    // MARK: Questions

    private static func drawQuestionsLeaf(
        _ q: HandbookKeepsakes.Questions, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Keepsakes", headRight: "For someone you love")
        drawEyebrow("To ask out loud", style: style, leaf: &leaf)
        hbText("Questions for Someone You Love", font: .fbSerif(ofSize: 21, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 4)
        hbText("Pick a person and a quiet half hour. Ask these, and write down what they say in their own words.",
               font: .fbSerifItalic(ofSize: 9.8), color: ink.withAlphaComponent(0.72), leaf: &leaf, justified: false, gap: 4)
        kText("Asked of:", font: smallCaps(6.8, weight: .semibold), color: style.palette.accent, in: CGRect(x: leaf.left, y: leaf.y + 2, width: 60, height: 10))
        hbRules(from: leaf.y - 6, to: leaf.y + 12, left: leaf.left + 48, right: leaf.right, spacing: 18, style: style)
        leaf.y += 22

        let font = UIFont.fbSerif(ofSize: 10.6, weight: .medium)
        let heights = q.items.map { kHeight("\($0)", font: font, width: leaf.contentWidth - 20, lineSpacing: 1.8) }
        let fixed = heights.reduce(0, +) + CGFloat(q.items.count) * 8
        let lines = max(1, min(3, Int((leaf.bottom - leaf.y - fixed) / CGFloat(q.items.count) / 17)))
        for (index, text) in q.items.enumerated() {
            kText("\(index + 1)", font: .fbSerif(ofSize: 12, weight: .bold), color: style.palette.accent, in: CGRect(x: leaf.left, y: leaf.y - 1, width: 16, height: 14))
            kText(text, font: font, color: ink.withAlphaComponent(0.92), in: CGRect(x: leaf.left + 20, y: leaf.y, width: leaf.contentWidth - 20, height: heights[index] + 2), lineSpacing: 1.8)
            leaf.y += heights[index] + 3
            hbRules(from: leaf.y - 14, to: leaf.y + CGFloat(lines) * 17, left: leaf.left + 20, right: leaf.right, spacing: 17, style: style)
            leaf.y += CGFloat(lines) * 17 + 5
        }
    }

    // MARK: Eight words

    private static func drawEightWordsLeaf(
        _ e: HandbookKeepsakes.EightWords, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Keepsakes", headRight: "Eight words")
        drawEyebrow("A story only you can write", style: style, leaf: &leaf)
        hbText("Your Eight Words", font: .fbSerif(ofSize: 23, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 4)
        hbText(e.frame, font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78), leaf: &leaf, justified: false, gap: 14)

        let columns = 4
        let gap: CGFloat = 8
        let width = (leaf.contentWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let height: CGFloat = 30
        for (index, word) in e.words.enumerated() {
            let rect = CGRect(x: leaf.left + CGFloat(index % columns) * (width + gap), y: leaf.y + CGFloat(index / columns) * (height + gap), width: width, height: height)
            style.palette.accent.withAlphaComponent(0.08).setFill()
            let pill = UIBezierPath(roundedRect: rect, cornerRadius: height / 2)
            pill.fill()
            style.palette.accent.withAlphaComponent(0.55).setStroke()
            pill.lineWidth = 0.7
            pill.stroke()
            kText(word, font: .fbSerif(ofSize: 11.4, weight: .semibold), color: ink.withAlphaComponent(0.9),
                  in: CGRect(x: rect.minX + 4, y: rect.minY + 8.5, width: rect.width - 8, height: 14), alignment: .center)
        }
        leaf.y += CGFloat((e.words.count + columns - 1) / columns) * (height + gap) + 8
        kText("Once there was a month in which…", font: .fbSerifItalic(ofSize: 13), color: style.palette.accent,
              in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: 16))
        leaf.y += 18
        hbRules(from: leaf.y, to: leaf.bottom, left: leaf.left, right: leaf.right, spacing: 23, style: style)
    }

    // MARK: Time capsule

    private static func drawCapsuleLeaf(
        _ c: HandbookKeepsakes.Capsule, style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Keepsakes", headRight: "Time capsule")
        let frame = CGRect(x: leaf.left, y: leaf.y - 2, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 6)
        drawCardFrame(frame, style: style, double: true)
        var inner = PDFCursor(bounds: leaf.bounds, margins: UIEdgeInsets(top: frame.minY + 16, left: frame.minX + 18, bottom: leaf.bounds.height - frame.maxY + 14, right: leaf.bounds.width - frame.maxX + 18))
        inner.y = frame.minY + 18
        kText("DO NOT OPEN UNTIL", font: smallCaps(7.2), color: style.palette.accent, in: CGRect(x: inner.left, y: inner.y, width: inner.contentWidth, height: 10), alignment: .center)
        inner.y += 14
        kText("\(c.monthName) \(c.openYear)", font: .fbSerifItalic(ofSize: 27), color: ink, in: CGRect(x: inner.left, y: inner.y, width: inner.contentWidth, height: 32), alignment: .center)
        inner.y += 38
        hbText("Write this now, and leave it alone. When this day comes round again, turn to this leaf and find out who you were.",
               font: .fbSerifItalic(ofSize: 9.8), color: ink.withAlphaComponent(0.72), leaf: &inner, justified: false, gap: 12)
        let promptFont = UIFont.fbSerif(ofSize: 10.8, weight: .medium)
        let each = (inner.bottom - inner.y - 44) / CGFloat(max(1, c.prompts.count))
        for (index, prompt) in c.prompts.enumerated() {
            kText("\(index + 1).  \(prompt)", font: promptFont, color: ink.withAlphaComponent(0.9), in: CGRect(x: inner.left, y: inner.y, width: inner.contentWidth, height: 28))
            hbRules(from: inner.y + 10, to: inner.y + each - 6, left: inner.left, right: inner.right, spacing: 20, style: style)
            inner.y += each
        }
        kText("Written on", font: smallCaps(6.6, weight: .semibold), color: style.palette.accent, in: CGRect(x: inner.left, y: frame.maxY - 26, width: 60, height: 10))
        hbRules(from: frame.maxY - 36, to: frame.maxY - 14, left: inner.left + 52, right: inner.left + inner.contentWidth * 0.48, spacing: 20, style: style)
        kText("Signed", font: smallCaps(6.6, weight: .semibold), color: style.palette.accent, in: CGRect(x: inner.left + inner.contentWidth * 0.55, y: frame.maxY - 26, width: 40, height: 10))
        hbRules(from: frame.maxY - 36, to: frame.maxY - 14, left: inner.left + inner.contentWidth * 0.55 + 38, right: inner.right, spacing: 20, style: style)
    }

    // MARK: Bookmarks

    private static func mirrored(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(x: bounds.width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
    }

    private static func cutLine(_ rect: CGRect, style: EditionStyle, radius: CGFloat = 4) {
        dashed(UIBezierPath(roundedRect: rect, cornerRadius: radius), color: style.palette.ink.withAlphaComponent(0.45), width: 0.7)
    }

    /// One leaf, both faces: three tall bookmarks on the front, and the moon behind each on the
    /// reverse (mirrored so each sits exactly behind its front). The leaf opens on a right-hand page.
    private static func drawCutouts(
        _ cut: HandbookKeepsakes.Cutouts, year: Int, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) {
        if (cursor.pageIndex + 1) % 2 == 0 {
            drawNotesLeafWithPrompt(style: style, context: context, cursor: &cursor, head: "Keepsakes")
        }
        let bounds = cursor.bounds
        let ink = style.palette.ink
        let monthLabel = "\(cut.monthName) \(year)".uppercased()

        var front = fieldLeaf(&cursor, style: style, context: context, headLeft: "Keepsakes", headRight: "Cut here")
        drawEyebrow("Three bookmarks. Cut along the dashes", style: style, leaf: &front)
        let count = cut.bookmarks.count
        let gap: CGFloat = 12
        let areaW = min(front.contentWidth, 330)
        let width = (areaW - gap * CGFloat(count - 1)) / CGFloat(count)
        let height = min(width * 4.1, front.bottom - front.y - 14)
        let originX = bounds.midX - areaW / 2
        let rects = (0..<count).map { CGRect(x: originX + CGFloat($0) * (width + gap), y: front.y + 6, width: width, height: height) }

        for (index, rect) in rects.enumerated() {
            let mark = cut.bookmarks[index]
            cutLine(rect, style: style, radius: 6)
            drawCardFrame(rect.insetBy(dx: 4, dy: 4), style: style, double: true)
            dashed(UIBezierPath(ovalIn: CGRect(x: rect.midX - 3.5, y: rect.minY + 12, width: 7, height: 7)), color: ink.withAlphaComponent(0.5))
            if let art = MarginaliaDealer.next(month: monthNumber) {
                drawFittedImage(art, in: CGRect(x: rect.minX + 10, y: rect.minY + 28, width: rect.width - 20, height: rect.width - 8), rotation: [-0.05, 0.04, -0.03][index % 3])
            }
            let quote = "“\(mark.line)”"
            let quoteFont = UIFont.fbSerifItalic(ofSize: 10.4)
            let room = rect.height - rect.width - 70
            let quoteH = min(room, kHeight(quote, font: quoteFont, width: rect.width - 22, lineSpacing: 2.2))
            kText(quote, font: quoteFont, color: ink.withAlphaComponent(0.9),
                  in: CGRect(x: rect.minX + 11, y: rect.minY + rect.width + 34 + max(0, (room - quoteH) / 2), width: rect.width - 22, height: quoteH + 2),
                  alignment: .center, lineSpacing: 2.2)
            drawOrnamentRow(style, centerY: rect.maxY - 34, in: rect, color: style.palette.accent.withAlphaComponent(0.5))
            kText(monthLabel, font: smallCaps(5.6, weight: .semibold), color: style.palette.accent,
                  in: CGRect(x: rect.minX, y: rect.maxY - 20, width: rect.width, height: 8), alignment: .center)
        }

        _ = fieldLeaf(&cursor, style: style, context: context, headLeft: "Keepsakes", headRight: "The reverse")
        for (index, rect) in rects.enumerated() {
            let m = mirrored(rect, in: bounds)
            let mark = cut.bookmarks[index]
            cutLine(m, style: style, radius: 6)
            drawCardFrame(m.insetBy(dx: 4, dy: 4), style: style, double: true)
            drawMoon(center: CGPoint(x: m.midX, y: m.minY + 62), radius: min(24, m.width * 0.3), lit: mark.moonLit,
                     waning: mark.moonName.contains("Waning") || mark.moonName.contains("Last"),
                     ink: ink.withAlphaComponent(0.85), light: UIColor(white: 0.97, alpha: 1))
            kText(mark.moonName.uppercased(), font: smallCaps(5.4, weight: .semibold), color: style.palette.accent,
                  in: CGRect(x: m.minX + 2, y: m.minY + 96, width: m.width - 4, height: 18), alignment: .center)
            kText("Kept in \(cut.monthName).", font: .fbSerifItalic(ofSize: 8.2), color: ink.withAlphaComponent(0.7),
                  in: CGRect(x: m.minX + 8, y: m.minY + 126, width: m.width - 16, height: 50), alignment: .center, lineSpacing: 2)
            drawOrnamentRow(style, centerY: m.midY + 20, in: m, color: style.palette.accent.withAlphaComponent(0.5))
            kText("THE BOOK\nOF YOU", font: smallCaps(5.4, weight: .semibold), color: ink.withAlphaComponent(0.5),
                  in: CGRect(x: m.minX, y: m.maxY - 26, width: m.width, height: 16), alignment: .center)
        }
    }

    /// A leaf of lined space with an invitation, used when a cut-out must open on a right-hand page.
    private static func drawNotesLeafWithPrompt(
        style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor, head: String
    ) {
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: head, headRight: "Notes")
        let prompt = NotePromptDealer.next(.any, seed: "keepsake-pad-\(cursor.pageIndex)") ?? "A page for whatever comes to mind."
        drawNotesBlock(prompt, in: CGRect(x: leaf.left, y: leaf.y + 6, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 12), style: style)
        leaf.y = leaf.bottom
    }
}
