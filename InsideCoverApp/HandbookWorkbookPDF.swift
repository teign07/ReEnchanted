import Foundation
import PDFKit
import UIKit

// MARK: - The Workbook, on paper
//
// Puzzles made of this reader's own month, the Examination, the Report Card,
// and the answers, printed upside-down at the back so that looking costs a
// small effort.

extension MonthlyEditionPDFWriter {

    static func drawWorkbook(
        _ workbook: HandbookWorkbook,
        readerName: String,
        termLabel: String,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        if let search = workbook.wordSearch {
            drawWordSearchLeaf(search, style: style, context: context, cursor: &cursor)
        }
        drawMazeLeaf(workbook.maze, style: style, context: context, cursor: &cursor)
        drawPuzzleStack(workbook, style: style, context: context, cursor: &cursor)
        if let exam = workbook.exam {
            drawExam(exam, proctor: workbook.reportCard?.proctorName ?? "the Headmistress",
                     style: style, context: context, cursor: &cursor)
        }
        if let card = workbook.reportCard {
            drawReportCard(card, exam: workbook.exam, readerName: readerName, termLabel: termLabel, style: style, context: context, cursor: &cursor)
        }
        drawSolutions(workbook, style: style, context: context, cursor: &cursor)
    }

    // MARK: Word search

    private static func drawWordSearchLeaf(
        _ search: HandbookWordSearch, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Workbook", headRight: "Puzzles")
        drawEyebrow("Puzzle one", style: style, leaf: &leaf)
        hbText("The Hidden Words", font: .fbSerif(ofSize: 22, weight: .bold), color: ink, leaf: &leaf,
               justified: false, gap: 4)
        hbText("Every word here is yours: a word that ran through your month, someone from your Cast, a place you've been. They run forwards, backwards and slantwise. Circle them.",
               font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78), leaf: &leaf, justified: false, gap: 12)

        let cell = leaf.contentWidth / CGFloat(search.size)
        let origin = CGPoint(x: leaf.left, y: leaf.y)
        let letterFont = UIFont.fbSerif(ofSize: cell * 0.56, weight: .semibold)
        if let cg = UIGraphicsGetCurrentContext() {
            cg.setStrokeColor(ink.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(0.7)
            cg.stroke(CGRect(x: origin.x, y: origin.y, width: cell * CGFloat(search.size), height: cell * CGFloat(search.size)))
        }
        for (r, row) in search.rows.enumerated() {
            for (c, ch) in row.enumerated() {
                let text = String(ch) as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: letterFont, .foregroundColor: ink.withAlphaComponent(0.88)]
                let size = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: origin.x + CGFloat(c) * cell + (cell - size.width) / 2,
                                      y: origin.y + CGFloat(r) * cell + (cell - size.height) / 2), withAttributes: attrs)
            }
        }
        leaf.y = origin.y + cell * CGFloat(search.size) + 16

        drawEyebrow("Find these", style: style, leaf: &leaf)
        let columns = 3
        let columnWidth = leaf.contentWidth / CGFloat(columns)
        for (index, placed) in search.words.enumerated() {
            let col = index % columns, row = index / columns
            let x = leaf.left + CGFloat(col) * columnWidth
            let y = leaf.y + CGFloat(row) * 18
            guard y + 14 < leaf.bottom else { break }
            style.palette.ink.withAlphaComponent(0.5).setStroke()
            let box = UIBezierPath(rect: CGRect(x: x, y: y + 2, width: 8, height: 8))
            box.lineWidth = 0.6
            box.stroke()
            (placed.word.capitalized as NSString).draw(
                at: CGPoint(x: x + 14, y: y),
                withAttributes: [.font: UIFont.fbSerif(ofSize: 10.5, weight: .medium), .foregroundColor: ink.withAlphaComponent(0.9)])
        }
    }

    // MARK: Maze

    private static func drawMazeLeaf(
        _ maze: HandbookMaze, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Workbook", headRight: "Puzzles")
        drawEyebrow("Puzzle two", style: style, leaf: &leaf)
        hbText("The Way Through", font: .fbSerif(ofSize: 22, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 4)
        hbText("The Labyrinth rearranges itself every month. This is how it lay in yours. In at the top, out at the bottom, and no cheating by tearing the page.",
               font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78), leaf: &leaf, justified: false, gap: 14)
        let availableH = leaf.bottom - leaf.y - 16
        let cell = min(leaf.contentWidth / CGFloat(maze.width), availableH / CGFloat(maze.height))
        let width = cell * CGFloat(maze.width)
        let origin = CGPoint(x: leaf.left + (leaf.contentWidth - width) / 2, y: leaf.y)
        drawMaze(maze, origin: origin, cell: cell, color: ink.withAlphaComponent(0.85), showSolution: false, accent: style.palette.accent)
        drawTracked("in", at: CGPoint(x: origin.x - 2, y: origin.y - 12), font: smallCaps(6.6), color: style.palette.accent, tracking: 1.2)
        drawTracked("out", at: CGPoint(x: origin.x + width - 18, y: origin.y + cell * CGFloat(maze.height) + 3),
                    font: smallCaps(6.6), color: style.palette.accent, tracking: 1.2)
    }

    static func drawMaze(_ maze: HandbookMaze, origin: CGPoint, cell: CGFloat, color: UIColor, showSolution: Bool, accent: UIColor) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        if showSolution {
            cg.setStrokeColor(accent.withAlphaComponent(0.8).cgColor)
            cg.setLineWidth(max(1, cell * 0.2))
            cg.setLineCap(.round); cg.setLineJoin(.round)
            for (index, cellIndex) in maze.solution.enumerated() {
                let p = CGPoint(x: origin.x + (CGFloat(cellIndex % maze.width) + 0.5) * cell,
                                y: origin.y + (CGFloat(cellIndex / maze.width) + 0.5) * cell)
                index == 0 ? cg.move(to: p) : cg.addLine(to: p)
            }
            cg.strokePath()
        }
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(1.1)
        cg.setLineCap(.round)
        for y in 0..<maze.height {
            for x in 0..<maze.width {
                let index = y * maze.width + x
                let open = maze.open[index]
                let x0 = origin.x + CGFloat(x) * cell, y0 = origin.y + CGFloat(y) * cell
                if open & HandbookMaze.north == 0, index != 0 {
                    cg.move(to: CGPoint(x: x0, y: y0)); cg.addLine(to: CGPoint(x: x0 + cell, y: y0))
                }
                if open & HandbookMaze.west == 0 {
                    cg.move(to: CGPoint(x: x0, y: y0)); cg.addLine(to: CGPoint(x: x0, y: y0 + cell))
                }
                if y == maze.height - 1, index != maze.width * maze.height - 1 {
                    cg.move(to: CGPoint(x: x0, y: y0 + cell)); cg.addLine(to: CGPoint(x: x0 + cell, y: y0 + cell))
                }
                if x == maze.width - 1 {
                    cg.move(to: CGPoint(x: x0 + cell, y: y0)); cg.addLine(to: CGPoint(x: x0 + cell, y: y0 + cell))
                }
            }
        }
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: Cipher, matching, ordering

    private static func drawPuzzleStack(
        _ workbook: HandbookWorkbook, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let width = max(220, cursor.contentWidth)
        var items: [StackItem] = []

        if let cipher = workbook.cipher {
            let cellW: CGFloat = 12.5
            let perLine = max(8, Int(width / cellW))
            // Break on word boundaries so no word is split across lines.
            var lines: [String] = []
            var current = ""
            for word in cipher.cipher.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = current.isEmpty ? String(word) : current + " " + word
                if candidate.count > perLine { lines.append(current); current = String(word) } else { current = candidate }
            }
            if !current.isEmpty { lines.append(current) }
            let lineH: CGFloat = 34
            let introH = FieldText.height("This is a sentence you wrote this month. The Book has scrambled it, one letter for another, always the same swap. Decode it.",
                                         font: .fbSerifItalic(ofSize: 10), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = 22 + introH + 10 + CGFloat(lines.count) * lineH + 20
            items.append(StackItem(height: total) { rect in
                ("Puzzle three: the Scrambled Line" as NSString).draw(
                    at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                FieldText.flow("This is a sentence you wrote this month. The Book has scrambled it, one letter for another, always the same swap. Decode it.",
                               font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78),
                               in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: introH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                var y = rect.minY + 22 + introH + 10
                for line in lines {
                    var x = rect.minX
                    for ch in line {
                        let isLetter = ch.isLetter
                        (String(ch) as NSString).draw(
                            at: CGPoint(x: x + 2, y: y),
                            withAttributes: [.font: UIFont.fbSerif(ofSize: 11.5, weight: .semibold), .foregroundColor: ink.withAlphaComponent(0.9)])
                        if isLetter {
                            ink.withAlphaComponent(0.4).setStroke()
                            let rule = UIBezierPath()
                            rule.move(to: CGPoint(x: x + 1, y: y + 28)); rule.addLine(to: CGPoint(x: x + cellW - 1, y: y + 28))
                            rule.lineWidth = 0.5; rule.stroke()
                        }
                        x += cellW
                    }
                    y += lineH
                }
                ("Given: " + cipher.hints.joined(separator: "   ") as NSString).draw(
                    at: CGPoint(x: rect.minX, y: y - 4),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9.4), .foregroundColor: style.palette.accent])
            })
        }

        if let matching = workbook.matching {
            let rowH: CGFloat = 38
            let total = 22 + CGFloat(matching.lines.count) * rowH + 20 + CGFloat((matching.speakers.count + 1) / 2) * 16
            items.append(StackItem(height: total) { rect in
                ("Puzzle four: Who Said It" as NSString).draw(
                    at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                var y = rect.minY + 24
                for (index, line) in matching.lines.enumerated() {
                    ("\(index + 1)" as NSString).draw(
                        at: CGPoint(x: rect.minX, y: y),
                        withAttributes: [.font: UIFont.fbSerif(ofSize: 12, weight: .bold), .foregroundColor: style.palette.accent])
                    FieldText.flow("“\(line)”", font: .fbSerifItalic(ofSize: 9.6), color: ink.withAlphaComponent(0.9),
                                   in: CGRect(x: rect.minX + 16, y: y, width: width - 56, height: rowH - 4),
                                   lineSpacing: 1.6, paragraphSpacing: 0, justified: false)
                    ink.withAlphaComponent(0.4).setStroke()
                    let blank = UIBezierPath()
                    blank.move(to: CGPoint(x: rect.maxX - 30, y: y + 14)); blank.addLine(to: CGPoint(x: rect.maxX, y: y + 14))
                    blank.lineWidth = 0.5; blank.stroke()
                    y += rowH
                }
                y += 4
                let letters = Array("ABCDEFGH")
                for (index, name) in matching.speakers.enumerated() {
                    let col = index % 2, row = index / 2
                    ("\(letters[index % letters.count]).  \(name)" as NSString).draw(
                        at: CGPoint(x: rect.minX + CGFloat(col) * (width / 2), y: y + CGFloat(row) * 16),
                        withAttributes: [.font: UIFont.fbSerif(ofSize: 10.5, weight: .medium), .foregroundColor: ink.withAlphaComponent(0.9)])
                }
            })
        }

        if let order = workbook.ordering {
            let rowH: CGFloat = 22
            let total = 22 + 30 + CGFloat(order.events.count) * rowH
            items.append(StackItem(height: total) { rect in
                ("Puzzle five: Put the Month in Order" as NSString).draw(
                    at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                ("Number them 1 to \(order.events.count), earliest first. Dates are the one thing the Book won't tell you." as NSString).draw(
                    in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: 14),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10), .foregroundColor: ink.withAlphaComponent(0.78)])
                var y = rect.minY + 46
                for event in order.events {
                    ink.withAlphaComponent(0.5).setStroke()
                    let box = UIBezierPath(rect: CGRect(x: rect.minX, y: y, width: 16, height: 16))
                    box.lineWidth = 0.6; box.stroke()
                    (event as NSString).draw(
                        at: CGPoint(x: rect.minX + 26, y: y + 1),
                        withAttributes: [.font: UIFont.fbSerif(ofSize: 11, weight: .medium), .foregroundColor: ink.withAlphaComponent(0.9)])
                    y += rowH
                }
            })
        }
        drawStack(items, head: "Workbook", kicker: "More puzzles", headRight: "Puzzles", style: style,
                  context: context, cursor: &cursor, gap: 26)
    }

    // MARK: Examination

    private static func drawExam(
        _ exam: HandbookExam, proctor: String, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let width = max(220, cursor.contentWidth)
        var items: [StackItem] = []
        let intro = "Pencil only. No looking back through the Book: the Academy would like to know what you actually noticed. Mark yourself honestly against the key on the last leaf of this section. \(proctor) will know."
        let introH = FieldText.height(intro, font: .fbSerifItalic(ofSize: 10.4), width: width, lineSpacing: 2.2, paragraphSpacing: 0, justified: false)
        items.append(StackItem(height: introH) { rect in
            FieldText.flow(intro, font: .fbSerifItalic(ofSize: 10.4), color: ink.withAlphaComponent(0.82),
                           in: CGRect(x: rect.minX, y: rect.minY, width: width, height: introH + 2),
                           lineSpacing: 2.2, paragraphSpacing: 0, justified: false)
        })
        let letters = Array("ABCDEFGH")
        for (index, question) in exam.questions.enumerated() {
            let promptH = FieldText.height("\(index + 1).  \(question.prompt)", font: .fbSerif(ofSize: 11.5, weight: .semibold), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = promptH + 8 + CGFloat(question.options.count) * 17
            items.append(StackItem(height: total) { rect in
                FieldText.flow("\(index + 1).  \(question.prompt)", font: .fbSerif(ofSize: 11.5, weight: .semibold), color: ink,
                               in: CGRect(x: rect.minX, y: rect.minY, width: width, height: promptH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                var y = rect.minY + promptH + 8
                for (i, option) in question.options.enumerated() {
                    ink.withAlphaComponent(0.55).setStroke()
                    let circle = UIBezierPath(ovalIn: CGRect(x: rect.minX + 14, y: y + 1, width: 10, height: 10))
                    circle.lineWidth = 0.6; circle.stroke()
                    ("\(letters[i % letters.count]).  \(option)" as NSString).draw(
                        in: CGRect(x: rect.minX + 32, y: y, width: width - 36, height: 15),
                        withAttributes: [.font: UIFont.fbSerif(ofSize: 10.4, weight: .regular), .foregroundColor: ink.withAlphaComponent(0.9)])
                    y += 17
                }
            })
        }
        for prompt in exam.shortAnswers {
            let promptH = FieldText.height(prompt, font: .fbSerif(ofSize: 11.5, weight: .semibold), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            items.append(StackItem(height: promptH + 6 + 24 * 3) { rect in
                FieldText.flow(prompt, font: .fbSerif(ofSize: 11.5, weight: .semibold), color: ink,
                               in: CGRect(x: rect.minX, y: rect.minY, width: width, height: promptH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                hbRules(from: rect.minY + promptH + 4, to: rect.maxY, left: rect.minX, right: rect.maxX, spacing: 24, style: style)
            })
        }
        drawStack(items, head: "Examination", kicker: "The Examination", headRight: "Handbook", style: style,
                  context: context, cursor: &cursor, gap: 14)
    }

    // MARK: Report card

    private static func markColor(_ mark: HandbookReportCard.Mark, style: EditionStyle) -> UIColor {
        switch mark {
        case .distinction: return style.palette.gold
        case .merit: return style.palette.accent
        case .pass: return style.palette.ink.withAlphaComponent(0.8)
        case .resit: return UIColor(red: 0.62, green: 0.18, blue: 0.16, alpha: 1)
        case .incomplete: return style.palette.ink.withAlphaComponent(0.4)
        }
    }

    private static func drawReportCard(
        _ card: HandbookReportCard, exam: HandbookExam?, readerName: String, termLabel: String, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Report Card", headRight: readerName)
        let frame = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y - 2)
        drawCardFrame(frame, style: style, double: true)
        var inner = leaf
        inner.y = frame.minY + 18
        let pad: CGFloat = 16
        let x = frame.minX + pad
        let width = frame.width - pad * 2

        drawTracked("The Academy of the Labyrinth", at: CGPoint(x: x, y: inner.y), font: smallCaps(7), color: style.palette.accent,
                    tracking: 1.8, width: width, alignment: .center)
        inner.y += 16
        let title = "Report Card" as NSString
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerif(ofSize: 25, weight: .bold), .foregroundColor: ink]
        title.draw(at: CGPoint(x: x + (width - title.size(withAttributes: titleAttrs).width) / 2, y: inner.y), withAttributes: titleAttrs)
        inner.y += 34
        let term = "\(readerName) · \(termLabel)" as NSString
        let termAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerifItalic(ofSize: 10.5), .foregroundColor: ink.withAlphaComponent(0.7)]
        term.draw(at: CGPoint(x: x + (width - term.size(withAttributes: termAttrs).width) / 2, y: inner.y), withAttributes: termAttrs)
        inner.y += 26

        if card.onLeave {
            let text = card.verdict
            let h = FieldText.height(text, font: .fbSerifItalic(ofSize: 15), width: width - 20, lineSpacing: 4, paragraphSpacing: 0, justified: false)
            FieldText.flow(text, font: .fbSerifItalic(ofSize: 15), color: ink.withAlphaComponent(0.88),
                           in: CGRect(x: x + 10, y: inner.y + 30, width: width - 20, height: h + 4),
                           lineSpacing: 4, paragraphSpacing: 0, justified: false)
            drawSignature(card, x: x, y: frame.maxY - 56, width: width, style: style)
            return
        }

        for subject in card.subjects {
            (subject.name as NSString).draw(at: CGPoint(x: x, y: inner.y),
                withAttributes: [.font: UIFont.fbSerif(ofSize: 13, weight: .semibold), .foregroundColor: ink])
            (subject.receipt as NSString).draw(at: CGPoint(x: x, y: inner.y + 17),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9), .foregroundColor: ink.withAlphaComponent(0.6)])
            let mark = subject.mark.title.uppercased() as NSString
            let markAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .heavy),
                                                           .foregroundColor: markColor(subject.mark, style: style), .kern: 1.6]
            let markSize = mark.size(withAttributes: markAttrs)
            let badge = CGRect(x: x + width - markSize.width - 14, y: inner.y + 2, width: markSize.width + 14, height: 20)
            markColor(subject.mark, style: style).setStroke()
            let outline = UIBezierPath(roundedRect: badge, cornerRadius: 3)
            outline.lineWidth = subject.mark == .incomplete ? 0.5 : 1.1
            if subject.mark == .incomplete { outline.setLineDash([2, 2], count: 2, phase: 0) }
            outline.stroke()
            mark.draw(at: CGPoint(x: badge.minX + 7, y: badge.minY + 5.5), withAttributes: markAttrs)
            ink.withAlphaComponent(0.15).setStroke()
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: x, y: inner.y + 33)); rule.addLine(to: CGPoint(x: x + width, y: inner.y + 33))
            rule.lineWidth = 0.5; rule.stroke()
            inner.y += 36
        }

        if let exam, exam.outOf > 0 {
            ("Examination" as NSString).draw(at: CGPoint(x: x, y: inner.y),
                withAttributes: [.font: UIFont.fbSerif(ofSize: 13, weight: .semibold), .foregroundColor: ink])
            ("marked by you, against the key" as NSString).draw(at: CGPoint(x: x, y: inner.y + 17),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9), .foregroundColor: ink.withAlphaComponent(0.6)])
            let scoreText = "____ / \(exam.outOf)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerif(ofSize: 13, weight: .semibold), .foregroundColor: ink]
            scoreText.draw(at: CGPoint(x: x + width - scoreText.size(withAttributes: attrs).width, y: inner.y + 3), withAttributes: attrs)
            inner.y += 40
        }

        let verdictH = FieldText.height(card.verdict, font: .fbSerifItalic(ofSize: 11.5), width: width, lineSpacing: 3, paragraphSpacing: 0, justified: false)
        FieldText.flow(card.verdict, font: .fbSerifItalic(ofSize: 11.5), color: ink.withAlphaComponent(0.88),
                       in: CGRect(x: x, y: inner.y + 4, width: width, height: verdictH + 4),
                       lineSpacing: 3, paragraphSpacing: 0, justified: false)
        inner.y += verdictH + 22

        // Resits come with the errand that clears them, printed where the mark is.
        for subject in card.subjects {
            guard let errand = subject.resitErrand else { continue }
            let text = "Resit, \(subject.name). \(errand)"
            let font = UIFont.fbSerifItalic(ofSize: 9.6)
            let h = FieldText.height(text, font: font, width: width, lineSpacing: 1.8, paragraphSpacing: 0, justified: false)
            FieldText.flow(text, font: font, color: markColor(.resit, style: style),
                           in: CGRect(x: x, y: inner.y, width: width, height: h + 2),
                           lineSpacing: 1.8, paragraphSpacing: 0, justified: false)
            inner.y += h + 8
        }

        // The right to contest: a mark is a claim, and a claim can be answered.
        let contestTop = max(inner.y + 6, frame.maxY - 140)
        ("To contest a mark" as NSString).draw(at: CGPoint(x: x, y: contestTop),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 11, weight: .semibold), .foregroundColor: ink])
        ("Say which, and why. \(card.proctorName) reads every one." as NSString).draw(
            at: CGPoint(x: x, y: contestTop + 15),
            withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9), .foregroundColor: ink.withAlphaComponent(0.6)])
        hbRules(from: contestTop + 28, to: frame.maxY - 64, left: x, right: x + width, spacing: 20, style: style)
        drawSignature(card, x: x, y: frame.maxY - 50, width: width, style: style)
    }

    private static func drawSignature(_ card: HandbookReportCard, x: CGFloat, y: CGFloat, width: CGFloat, style: EditionStyle) {
        style.palette.ink.withAlphaComponent(0.5).setStroke()
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: x + width * 0.45, y: y + 18)); rule.addLine(to: CGPoint(x: x + width, y: y + 18))
        rule.lineWidth = 0.5; rule.stroke()
        (card.proctorName as NSString).draw(at: CGPoint(x: x + width * 0.45, y: y - 4),
            withAttributes: [.font: handFont(15), .foregroundColor: style.palette.ink.withAlphaComponent(0.85)])
        drawTracked("Proctor", at: CGPoint(x: x + width * 0.45, y: y + 22), font: smallCaps(6.4),
                    color: style.palette.ink.withAlphaComponent(0.5), tracking: 1.2)
    }

    // MARK: Solutions

    private static func drawSolutions(
        _ workbook: HandbookWorkbook, style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Answers", headRight: "Turn the book round")
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        // Everything below is set upside-down, so that peeking takes effort.
        cg.saveGState()
        cg.translateBy(x: leaf.bounds.midX, y: leaf.bounds.midY)
        cg.rotate(by: .pi)
        cg.translateBy(x: -leaf.bounds.midX, y: -leaf.bounds.midY)

        drawEyebrow("The key", style: style, leaf: &leaf)
        hbText("Answers", font: .fbSerif(ofSize: 20, weight: .bold), color: ink, leaf: &leaf, justified: false, gap: 8)
        let letters = Array("ABCDEFGH")

        if let exam = workbook.exam {
            let key = exam.questions.enumerated().map { "\($0.offset + 1)\(letters[$0.element.answer % letters.count])" }.joined(separator: "  ")
            hbText("Examination: \(key)", font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let match = workbook.matching {
            let key = match.answer.enumerated().map { "\($0.offset + 1)\(letters[$0.element % letters.count])" }.joined(separator: "  ")
            hbText("Who said it: \(key)", font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let order = workbook.ordering {
            let key = order.rank.enumerated().map { "\(letters[$0.offset % letters.count])\($0.element)" }.joined(separator: "  ")
            hbText("In order (event letter → place): \(key)", font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let cipher = workbook.cipher {
            hbText("The scrambled line: “\(cipher.plain)”", font: .fbSerifItalic(ofSize: 10.4), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let search = workbook.wordSearch {
            let directions = [[0, 1]: "across", [1, 0]: "down", [1, 1]: "down-right", [-1, 1]: "up-right", [0, -1]: "backwards", [1, -1]: "down-left"]
            let lines = search.words.map { "\($0.word.capitalized): row \($0.row + 1), col \($0.col + 1), \(directions[[$0.dRow, $0.dCol]] ?? "slantwise")" }
            hbText("Hidden words, from the top-left square: " + lines.joined(separator: "; ") + ".",
                   font: .fbSerif(ofSize: 9.4, weight: .regular), color: ink.withAlphaComponent(0.85), leaf: &leaf, justified: false, gap: 10)
        }
        let cell = min(leaf.contentWidth * 0.62 / CGFloat(workbook.maze.width), (leaf.bottom - leaf.y - 6) / CGFloat(workbook.maze.height))
        if cell > 6 {
            drawMaze(workbook.maze, origin: CGPoint(x: leaf.left, y: leaf.y), cell: cell,
                     color: ink.withAlphaComponent(0.7), showSolution: true, accent: style.palette.accent)
        }
        cg.restoreGState()
    }
}
