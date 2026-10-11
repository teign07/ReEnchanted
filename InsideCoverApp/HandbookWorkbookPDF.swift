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
        hbText("Every word here is yours: a word that ran through your \(periodNoun), someone from your Cast, a place you've been. They run forwards, backwards and slantwise. Circle them.",
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
        hbText("The Labyrinth rearranges itself every month. This is how it lay in \(handbookTermSpan == nil ? "yours" : "your last one"). In at the top, out at the bottom, and no cheating by tearing the page.",
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
        // Puzzles one and two are the word search and the maze; the rest are numbered as they come,
        // because which of them a week carries changes from issue to issue.
        let numbers = ["three", "four", "five", "six", "seven", "eight", "nine"]
        var made = 0
        func heading(_ name: String) -> String {
            defer { made += 1 }
            return "Puzzle \(numbers[min(made, numbers.count - 1)]): \(name)"
        }

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
            let introH = FieldText.height("This is a sentence you wrote \(thisPeriod). The Book has scrambled it, one letter for another, always the same swap. Decode it.",
                                         font: .fbSerifItalic(ofSize: 10), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = 22 + introH + 10 + CGFloat(lines.count) * lineH + 20
            let title = heading("the Scrambled Line")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(
                    at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                FieldText.flow("This is a sentence you wrote \(thisPeriod). The Book has scrambled it, one letter for another, always the same swap. Decode it.",
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
            let title = heading("Who Said It")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(
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
            let title = heading("Put the \(periodNoun.capitalized) in Order")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(
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
        if let cloze = workbook.cloze {
            let intro = "Each sentence is one you wrote, with a word taken out. The words are in the box below, and not all of them belong."
            let introH = FieldText.height(intro, font: .fbSerifItalic(ofSize: 10), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let sentenceFont = UIFont.fbSerif(ofSize: 10.8, weight: .regular)
            let heights = cloze.sentences.enumerated().map {
                FieldText.height("\($0.offset + 1).  \($0.element)", font: sentenceFont, width: width, lineSpacing: 2.4, paragraphSpacing: 0, justified: false)
            }
            let bankText = cloze.bank.joined(separator: "     ")
            let bankH = FieldText.height(bankText, font: .fbSerifItalic(ofSize: 11), width: width - 16, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = 22 + introH + 8 + heights.reduce(0) { $0 + $1 + 10 } + bankH + 16
            let title = heading("the Missing Words")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                FieldText.flow(intro, font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78),
                               in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: introH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                var y = rect.minY + 22 + introH + 8
                for (index, sentence) in cloze.sentences.enumerated() {
                    FieldText.flow("\(index + 1).  \(sentence)", font: sentenceFont, color: ink.withAlphaComponent(0.9),
                                   in: CGRect(x: rect.minX, y: y, width: width, height: heights[index] + 2),
                                   lineSpacing: 2.4, paragraphSpacing: 0, justified: false)
                    y += heights[index] + 10
                }
                let box = CGRect(x: rect.minX, y: y, width: width, height: bankH + 12)
                ink.withAlphaComponent(0.45).setStroke()
                let frame = UIBezierPath(roundedRect: box, cornerRadius: 3)
                frame.lineWidth = 0.6; frame.stroke()
                FieldText.flow(bankText, font: .fbSerifItalic(ofSize: 11), color: style.palette.accent,
                               in: CGRect(x: box.minX + 8, y: box.minY + 6, width: width - 16, height: bankH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
            })
        }

        if let anagrams = workbook.anagrams {
            let rowH: CGFloat = 30
            let total = 22 + 30 + CGFloat(anagrams.items.count) * rowH
            let title = heading("the Scrambled Cast")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                ("Each is a word of yours, shaken in a bag. The clue says whose." as NSString).draw(
                    in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: 14),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10), .foregroundColor: ink.withAlphaComponent(0.78)])
                var y = rect.minY + 46
                for item in anagrams.items {
                    let tiles = item.scrambled.map(String.init).joined(separator: " ")
                    drawTracked(tiles, at: CGPoint(x: rect.minX, y: y), font: UIFont.fbSerif(ofSize: 12.5, weight: .bold), color: ink.withAlphaComponent(0.92), tracking: 1.6)
                    (item.clue as NSString).draw(at: CGPoint(x: rect.minX, y: y + 15),
                        withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.8), .foregroundColor: style.palette.accent])
                    ink.withAlphaComponent(0.4).setStroke()
                    let rule = UIBezierPath()
                    rule.move(to: CGPoint(x: rect.minX + width * 0.52, y: y + 14))
                    rule.addLine(to: CGPoint(x: rect.maxX, y: y + 14))
                    rule.lineWidth = 0.5; rule.stroke()
                    y += rowH
                }
            })
        }

        if let vowels = workbook.vowels {
            let rowH: CGFloat = 36
            let total = 22 + 30 + CGFloat(vowels.items.count) * rowH
            let title = heading("Vowels Fled")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                ("The A, E, I, O and U have gone out for the evening. Put them back." as NSString).draw(
                    in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: 14),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10), .foregroundColor: ink.withAlphaComponent(0.78)])
                var y = rect.minY + 46
                for item in vowels.items {
                    (item.stripped as NSString).draw(at: CGPoint(x: rect.minX, y: y),
                        withAttributes: [.font: UIFont.fbSerif(ofSize: 11.5, weight: .semibold), .foregroundColor: ink.withAlphaComponent(0.92), .kern: 1.2])
                    (item.clue as NSString).draw(at: CGPoint(x: rect.minX, y: y + 17),
                        withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.8), .foregroundColor: style.palette.accent])
                    ink.withAlphaComponent(0.4).setStroke()
                    let rule = UIBezierPath()
                    rule.move(to: CGPoint(x: rect.minX + width * 0.40, y: y + 28))
                    rule.addLine(to: CGPoint(x: rect.maxX, y: y + 28))
                    rule.lineWidth = 0.5; rule.stroke()
                    y += rowH
                }
            })
        }

        if let sudoku = workbook.sudoku {
            let cell: CGFloat = 42
            let side = cell * CGFloat(sudoku.size)
            let intro = "Fill the grid so every row, every column and every box of \(sudoku.boxRows) by \(sudoku.boxCols) holds \(sudoku.symbols.joined(separator: ", ")) exactly once."
            let introH = FieldText.height(intro, font: .fbSerifItalic(ofSize: 10), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = 22 + introH + 10 + side + 4
            let title = heading("the Chairs")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                FieldText.flow(intro, font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.78),
                               in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: introH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                let origin = CGPoint(x: rect.minX + (width - side) / 2, y: rect.minY + 22 + introH + 10)
                guard let cg = UIGraphicsGetCurrentContext() else { return }
                cg.setStrokeColor(ink.withAlphaComponent(0.3).cgColor)
                cg.setLineWidth(0.5)
                for i in 0...sudoku.size {
                    cg.move(to: CGPoint(x: origin.x + CGFloat(i) * cell, y: origin.y))
                    cg.addLine(to: CGPoint(x: origin.x + CGFloat(i) * cell, y: origin.y + side))
                    cg.move(to: CGPoint(x: origin.x, y: origin.y + CGFloat(i) * cell))
                    cg.addLine(to: CGPoint(x: origin.x + side, y: origin.y + CGFloat(i) * cell))
                }
                cg.strokePath()
                cg.setStrokeColor(ink.withAlphaComponent(0.85).cgColor)
                cg.setLineWidth(1.4)
                for i in stride(from: 0, through: sudoku.size, by: sudoku.boxCols) {
                    cg.move(to: CGPoint(x: origin.x + CGFloat(i) * cell, y: origin.y))
                    cg.addLine(to: CGPoint(x: origin.x + CGFloat(i) * cell, y: origin.y + side))
                }
                for i in stride(from: 0, through: sudoku.size, by: sudoku.boxRows) {
                    cg.move(to: CGPoint(x: origin.x, y: origin.y + CGFloat(i) * cell))
                    cg.addLine(to: CGPoint(x: origin.x + side, y: origin.y + CGFloat(i) * cell))
                }
                cg.strokePath()
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerif(ofSize: 22, weight: .bold), .foregroundColor: ink.withAlphaComponent(0.92)]
                for (index, value) in sudoku.given.enumerated() where value >= 0 {
                    let text = sudoku.symbols[value] as NSString
                    let size = text.size(withAttributes: attrs)
                    text.draw(at: CGPoint(x: origin.x + CGFloat(index % sudoku.size) * cell + (cell - size.width) / 2,
                                          y: origin.y + CGFloat(index / sudoku.size) * cell + (cell - size.height) / 2), withAttributes: attrs)
                }
            })
        }

        if let odd = workbook.oddOne {
            let rowH: CGFloat = 40
            let total = 22 + 24 + CGFloat(odd.rounds.count) * rowH
            let title = heading("Odd One Out")
            items.append(StackItem(height: total) { rect in
                (title as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                ("Three of each four belong together. Ring the one that does not." as NSString).draw(
                    in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: 14),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 10), .foregroundColor: ink.withAlphaComponent(0.78)])
                var y = rect.minY + 44
                let letters = Array("ABCD")
                for (index, round) in odd.rounds.enumerated() {
                    ("\(index + 1)" as NSString).draw(at: CGPoint(x: rect.minX, y: y),
                        withAttributes: [.font: UIFont.fbSerif(ofSize: 12, weight: .bold), .foregroundColor: style.palette.accent])
                    for (slot, option) in round.options.enumerated() {
                        let col = slot % 2, row = slot / 2
                        ("\(letters[slot]).  \(option)" as NSString).draw(
                            at: CGPoint(x: rect.minX + 18 + CGFloat(col) * ((width - 18) / 2), y: y + CGFloat(row) * 16),
                            withAttributes: [.font: UIFont.fbSerif(ofSize: 10.5, weight: .medium), .foregroundColor: ink.withAlphaComponent(0.9)])
                    }
                    y += rowH
                }
            })
        }

        // A light month earns fewer puzzles of its own. The rest of the leaf is the reader's turn at
        // making one, which is a puzzle too, rather than a leaf with one cipher and a lot of paper.
        if items.count < 3 {
            let promptFont = UIFont.fbSerifItalic(ofSize: 10.4)
            let prompt = "Scramble a sentence you wrote this week, or hide one of your words in a grid of letters, and leave it for someone to solve. Write your key at the foot, folded under."
            let promptH = FieldText.height(prompt, font: promptFont, width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            items.append(StackItem(height: 22 + promptH + 10 + 22 * 6) { rect in
                ("Puzzle: your turn" as NSString).draw(
                    at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                FieldText.flow(prompt, font: promptFont, color: ink.withAlphaComponent(0.8),
                               in: CGRect(x: rect.minX, y: rect.minY + 22, width: width, height: promptH + 4),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                hbRules(from: rect.minY + 22 + promptH + 14, to: rect.maxY, left: rect.minX, right: rect.maxX, spacing: 22, style: style)
            })
        }
        drawStack(items, head: "Workbook", kicker: "More puzzles", headRight: "Puzzles", style: style,
                  context: context, cursor: &cursor, gap: 26,
                  fill: { rect in
                      if let prompt = NotePromptDealer.next(.puzzle, seed: "puzzle-\(items.count)") {
                          drawNotesBlock(prompt, in: rect, style: style)
                      }
                  })
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
            let total = promptH + 8 + CGFloat(question.options.count) * 15
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
                    y += 15
                }
            })
        }
        for prompt in exam.shortAnswers {
            let promptH = FieldText.height(prompt, font: .fbSerif(ofSize: 11.5, weight: .semibold), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            items.append(StackItem(height: promptH + 6 + 22 * 3) { rect in
                FieldText.flow(prompt, font: .fbSerif(ofSize: 11.5, weight: .semibold), color: ink,
                               in: CGRect(x: rect.minX, y: rect.minY, width: width, height: promptH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                hbRules(from: rect.minY + promptH + 4, to: rect.maxY, left: rect.minX, right: rect.maxX, spacing: 22, style: style)
            })
        }
        // Tight enough that the examination is one leaf, not a leaf and a single question.
        drawStack(items, head: "Examination", kicker: "The Examination", headRight: "Handbook", style: style,
                  context: context, cursor: &cursor, gap: 9)
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
            let markAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.fbSerif(ofSize: 9, weight: .semibold),
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

        // A subject still open carries a note: one real thing waiting there.
        // Three at most, the most curious first, so the card stays a card.
        let order = ["curiosity", "initiative", "fieldwork", "deeds", "noticing"]
        let open = card.subjects.filter { $0.invitation != nil }
            .sorted { (order.firstIndex(of: $0.id) ?? 9) < (order.firstIndex(of: $1.id) ?? 9) }
            .prefix(3)
        for subject in open {
            guard let invitation = subject.invitation else { continue }
            let font = UIFont.fbSerifItalic(ofSize: 9.6)
            let text = "\(subject.name): \(invitation)"
            let h = FieldText.height(text, font: font, width: width - 14, lineSpacing: 1.8, paragraphSpacing: 0, justified: false)
            guard inner.y + h < frame.maxY - 96 else { break }
            ("✦" as NSString).draw(at: CGPoint(x: x, y: inner.y), withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: style.palette.gold])
            FieldText.flow(text, font: font, color: style.palette.accent,
                           in: CGRect(x: x + 14, y: inner.y, width: width - 14, height: h + 2),
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
        if let cloze = workbook.cloze {
            let key = cloze.answers.enumerated().map { "\($0.offset + 1) \($0.element)" }.joined(separator: ",  ")
            hbText("Missing words: \(key)", font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let anagrams = workbook.anagrams {
            hbText("Scrambled cast: " + anagrams.items.map { $0.answer.capitalized }.joined(separator: ", ") + ".",
                   font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let vowels = workbook.vowels {
            hbText("Vowels fled: " + vowels.items.map(\.answer).joined(separator: "; ") + ".",
                   font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let odd = workbook.oddOne {
            let key = odd.rounds.enumerated().map { "\($0.offset + 1)\(letters[$0.element.answer % letters.count])" }.joined(separator: "  ")
            hbText("Odd one out: \(key)", font: .fbSerif(ofSize: 10.4, weight: .medium), color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
        }
        if let sudoku = workbook.sudoku {
            let rows = stride(from: 0, to: sudoku.solution.count, by: sudoku.size).map { start in
                sudoku.solution[start..<(start + sudoku.size)].map { sudoku.symbols[$0] }.joined()
            }
            hbText("The chairs, row by row: " + rows.joined(separator: "  "), font: .fbSerif(ofSize: 10.4, weight: .medium),
                   color: ink.withAlphaComponent(0.9), leaf: &leaf, justified: false, gap: 5)
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
