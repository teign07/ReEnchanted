import Foundation
import PDFKit
import UIKit

// MARK: - The Handbook, on paper
//
// The Academy's side of the volume: the term's coursework (a lecture leaf and
// a workbook leaf for every room), the Faculty files, the lore matched to this
// reader's own words, the creatures they filed, and the spell sheets. The
// workbook leaves are meant to be written in; the ruled lines are the point,
// not padding, and a lesson the reader sat prints their own entry first.

extension MonthlyEditionPDFWriter {

    static let bodyFont = UIFont.fbSerif(ofSize: 10.2, weight: .regular)

    static func hbRules(
        from startY: CGFloat, to endY: CGFloat, left: CGFloat, right: CGFloat,
        spacing: CGFloat = 23, style: EditionStyle
    ) {
        guard let cg = UIGraphicsGetCurrentContext(), endY - startY >= spacing else { return }
        // A writing area is a lighter sheet pasted onto the page, deckled at
        // the edges with a red margin line: less ink under the pen on coated
        // stock, and it reads as paper someone tipped in, not a form field.
        if endY - startY >= spacing * 2.5 {
            let sheet = CGRect(x: left - 6, y: startY + 2, width: right - left + 12, height: endY - startY + 2)
            drawTornScrap(in: sheet, rotation: 0, fill: UIColor(red: 0.995, green: 0.99, blue: 0.97, alpha: 0.55),
                          seed: "sheet-\(Int(startY))-\(Int(left))")
            let margin = UIBezierPath()
            margin.move(to: CGPoint(x: left + 16, y: sheet.minY + 4)); margin.addLine(to: CGPoint(x: left + 16, y: sheet.maxY - 4))
            UIColor(red: 0.78, green: 0.32, blue: 0.3, alpha: 0.32).setStroke()
            margin.lineWidth = 0.5
            margin.stroke()
        }
        cg.saveGState()
        cg.setStrokeColor(style.palette.ink.withAlphaComponent(0.17).cgColor)
        cg.setLineWidth(0.5)
        var y = startY + spacing
        while y <= endY {
            cg.move(to: CGPoint(x: left, y: y)); cg.addLine(to: CGPoint(x: right, y: y)); y += spacing
        }
        cg.strokePath()
        cg.restoreGState()
    }

    /// A line of text with a known height, measured before it is drawn.
    static func hbText(
        _ text: String, font: UIFont, color: UIColor, leaf: inout PDFCursor,
        x: CGFloat? = nil, width: CGFloat? = nil, lineSpacing: CGFloat = 2.6,
        paragraphSpacing: CGFloat = 5, justified: Bool = true, gap: CGFloat = 8
    ) {
        let left = x ?? leaf.left
        let w = width ?? (leaf.right - left)
        let h = FieldText.height(text, font: font, width: w, lineSpacing: lineSpacing,
                                 paragraphSpacing: paragraphSpacing, justified: justified)
        guard h > 0 else { return }
        FieldText.flow(text, font: font, color: color, in: CGRect(x: left, y: leaf.y, width: w, height: h + 2),
                       lineSpacing: lineSpacing, paragraphSpacing: paragraphSpacing, justified: justified)
        leaf.y += h + gap
    }

    static func hbPortrait(slug: String?, in box: CGRect, style: EditionStyle) {
        guard let slug, let asset = CastMarginalia.plateAssetName(forSlug: slug),
              let image = FieldImageCache.portrait(asset) else { return }
        let scale = min(box.width / image.size.width, box.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let frame = CGRect(x: box.maxX - size.width, y: box.minY, width: size.width, height: size.height)
        if let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: UIColor.black.withAlphaComponent(0.28).cgColor)
            image.draw(in: frame)
            cg.restoreGState()
        }
        style.palette.gold.setStroke()
        let outline = UIBezierPath(rect: frame.insetBy(dx: -2.5, dy: -2.5))
        outline.lineWidth = 0.9
        outline.stroke()
    }

    // MARK: Entry point

    /// Set while a season's Handbook is drawn: the span of its months ("September to November"),
    /// so the coursework talks about a term instead of a month.
    static var handbookTermSpan: String?
    /// "term" for a season, "year" for the annual; read only while `handbookTermSpan` is set.
    static var handbookPeriod = "term"
    static var periodNoun: String { handbookTermSpan == nil ? "month" : handbookPeriod }
    static var thisPeriod: String { "this \(periodNoun)" }

    static func drawHandbook(
        _ handbook: Handbook,
        readerName: String,
        termLabel: String,
        monthNumber: Int,
        showsContents: Bool = true,
        style: EditionStyle,
        context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        PrintPageMap.reset()
        // The month given back comes first: what the reader kept, said and collected.
        if let keepsakes = handbook.keepsakes {
            drawKeepsakesFront(keepsakes, style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        }
        if showsContents {
            drawCourseContents(handbook, style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        }
        drawTranscript(handbook.transcript ?? [], style: style, context: context, cursor: &cursor)
        for lesson in handbook.lessons {
            // A lesson whose lecture leaves room carries its practice on the same leaf; only a long one
            // needs a leaf of its own for the worksheet.
            if !drawLectureLeaf(lesson, style: style, context: context, cursor: &cursor, monthNumber: monthNumber) {
                drawWorkbookLeaf(lesson, style: style, context: context, cursor: &cursor)
            }
        }
        drawOpenSeats(handbook.openSeats ?? [], style: style, context: context, cursor: &cursor)
        drawDossiers(handbook.dossiers, style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        // The Wonder Compass is a guide in another voice ("You've been grinding
        // for six months"); its chapters stay in the app, not in the Book's lore.
        drawLoreShelf(handbook.lore, head: "The Lore Shelf", kicker: "Set down for you",
                      style: style, context: context, cursor: &cursor)
        drawBestiary(handbook.bestiary, style: style, context: context, cursor: &cursor)
        drawSpellSheets(handbook.spells, style: style, context: context, cursor: &cursor)
        if let count = handbook.ruinCount, count > 0 {
            let leaves = RuinPlan.leaves(
                count: count, seed: cursor.addressSeed ?? cursor.seed,
                from: RuinLibrary.available(month: monthNumber)
            )
            drawRuinLeaves(leaves, style: style, context: context, cursor: &cursor)
        }
        if let workbook = handbook.workbook {
            drawWorkbook(workbook, readerName: readerName, termLabel: termLabel, style: style, context: context, cursor: &cursor)
        }
        // Questions, a time capsule and a leaf to cut up go last, so nothing else is lost to scissors.
        if let keepsakes = handbook.keepsakes {
            drawKeepsakesBack(keepsakes, style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        }
    }

    // MARK: Contents of the term

    private static func drawCourseContents(
        _ handbook: Handbook, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) {
        let rooms = handbook.rooms
        guard !rooms.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Handbook", headRight: "Coursework")
        drawEyebrow("The term's coursework", style: style, leaf: &leaf)
        ("Rooms you may sit" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 24, weight: .bold), .foregroundColor: ink])
        leaf.y += 36
        // Every room the reader sat, written up or not.
        let sat = rooms.filter(\.attended).count
        let month = monthName(monthNumber)
        let course = "Every room teaches a new lesson each month, and everybody in the Academy gets the same one. Stay a whole year and you've had the lot. "
            + (handbookTermSpan.map { "This \(handbookPeriod) ran \($0). Where you sat a room more than once, here's the last lesson you had." } ?? "These are \(month)'s.")
        let intro: String
        if sat == 0 {
            intro = course + " You didn't get to any of them \(thisPeriod), so I sat in one for you and wrote it all down. The others saved your seat."
        } else {
            let words = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
            let count = sat <= words.count ? words[sat - 1] : "\(sat)"
            let also = handbook.alsoSat ?? []
            if also.isEmpty {
                intro = course + " You went to \(count). I've written \(sat == 1 ? "it" : "them") up properly and copied in what you brought back, in your own words. The others saved your seat."
            } else {
                let brought = also.contains { !($0.readerEntry ?? "").isEmpty }
                let fullCount = handbook.lessons.filter(\.attended).count
                let full = fullCount == 1 ? "the one" : "the \(fullCount <= words.count ? words[fullCount - 1] : "\(fullCount)")"
                intro = course + " You went to \(count)!"
                    + (fullCount > 0 ? " I've written up \(full) you put the most into." : " They're all marked below.")
                    + (brought ? " What you brought back from the others is copied in below them, in your own hand." : " The others you went to are marked below.")
                    + " The rest saved your seat."
            }
        }
        hbText(intro, font: .fbSerifItalic(ofSize: 10.6), color: ink.withAlphaComponent(0.82), leaf: &leaf, justified: false, gap: 14)

        let written = Set(handbook.lessons.map(\.id))
        let briefly = Set((handbook.alsoSat ?? []).map(\.id))
        let truncating = NSMutableParagraphStyle()
        truncating.lineBreakMode = .byTruncatingTail
        for group in [("Classes", rooms.filter { !$0.isClub }), ("Societies", rooms.filter(\.isClub))] where !group.1.isEmpty {
            drawEyebrow(group.0, style: style, leaf: &leaf)
            for lesson in group.1 {
                guard leaf.y + 34 < leaf.bottom else { break }
                (lesson.name as NSString).draw(
                    at: CGPoint(x: leaf.left, y: leaf.y),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 11.5, weight: .semibold), .foregroundColor: ink])
                let mark = lesson.attended
                    ? (lesson.attendedCount > 1 ? "sat ×\(lesson.attendedCount)" : "sat")
                    : (written.contains(lesson.id) ? "my notes" : "seat open")
                drawTracked(mark, at: CGPoint(x: leaf.left, y: leaf.y + 2), font: smallCaps(6.8),
                            color: lesson.attended ? style.palette.accent : ink.withAlphaComponent(0.4),
                            tracking: 1.2, width: leaf.contentWidth, alignment: .right)
                let sub = "\(lessonLabel(lesson).map { "\($0): " } ?? "")\(lesson.title) · \(lesson.leader)"
                (sub as NSString).draw(
                    in: CGRect(x: leaf.left, y: leaf.y + 15, width: leaf.contentWidth, height: 13),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.8), .foregroundColor: ink.withAlphaComponent(0.6),
                                     .paragraphStyle: truncating])
                leaf.y += 33
                // A room sat but not written up: one line of what the reader brought back, in their hand.
                if briefly.contains(lesson.id), let entry = lesson.readerEntry?.nonEmpty {
                    let line = entry.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    let quote = "\u{201C}\(line)\u{201D}" as NSString
                    let quoteAttributes: [NSAttributedString.Key: Any] = [.font: handFont(10), .foregroundColor: readerInk]
                    let twoLines = handFont(10).lineHeight * 2 + 2
                    let height = min(twoLines, ceil(quote.boundingRect(with: CGSize(width: leaf.contentWidth - 10, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin], attributes: quoteAttributes, context: nil).height))
                    quote.draw(with: CGRect(x: leaf.left + 10, y: leaf.y - 4, width: leaf.contentWidth - 10, height: height),
                               options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: quoteAttributes, context: nil)
                    leaf.y += height + 2
                }
            }
            leaf.y += 6
        }
        if let plant = FieldBotanicals.image(month: monthNumber, seed: "handbook-contents") {
            let w = min(70, plant.size.width * plant.scale / 150 * 72)
            let h = w * plant.size.height / plant.size.width
            // Only where it clears the last room listed.
            if leaf.y + h + 8 < leaf.bottom {
                plant.draw(in: CGRect(x: leaf.right - w, y: leaf.bottom - h, width: w, height: h))
            }
        }
    }

    // MARK: The term's register

    /// Every class the reader sat this term, in order: the date, the room, the lesson it was, and
    /// what they wrote, in their hand. It reads like a register because it is one.
    private static func drawTranscript(
        _ sittings: [HandbookSitting], style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        guard !sittings.isEmpty else { return }
        let ink = style.palette.ink
        func freshLeaf(_ continued: Bool) -> PDFCursor {
            fieldLeaf(&cursor, style: style, context: context, headLeft: "The Handbook",
                      headRight: continued ? "The Register, continued" : "The Register")
        }
        var leaf = freshLeaf(false)
        drawEyebrow("Every room you sat", style: style, leaf: &leaf)
        ("The Register" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 24, weight: .bold), .foregroundColor: ink])
        leaf.y += 36
        let rooms = Set(sittings.map(\.sessionID)).count
        let written = sittings.filter { $0.answer != nil }.count
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        func say(_ n: Int) -> String { n < words.count ? words[n] : "\(n)" }
        var intro = "You sat \(say(sittings.count)) \(sittings.count == 1 ? "class" : "classes") \(thisPeriod)"
        intro += rooms > 1 ? ", in \(say(rooms)) different rooms." : "."
        intro += written > 0
            ? " You brought \(written == sittings.count ? "every one" : say(written)) back with something written on \(written == 1 ? "it" : "them"). It's copied in here, in your hand."
            : " Next \(periodNoun), bring one back with something written on it. I'll copy it in."
        hbText(intro, font: .fbSerifItalic(ofSize: 10.6), color: ink.withAlphaComponent(0.82), leaf: &leaf, justified: false, gap: 14)

        let monthTitle = DateFormatter(); monthTitle.dateFormat = "MMMM"
        let dayFormat = DateFormatter(); dayFormat.dateFormat = "EEE d"
        let calendar = Calendar.current
        var shownMonth = -1
        let truncating = NSMutableParagraphStyle()
        truncating.lineBreakMode = .byTruncatingTail
        let handAttributes: [NSAttributedString.Key: Any] = [.font: handFont(10), .foregroundColor: readerInk]
        let indent: CGFloat = 46
        for sitting in sittings {
            var answerHeight: CGFloat = 0
            let quote = sitting.answer.map { "\u{201C}\($0)\u{201D}" as NSString }
            if let quote {
                answerHeight = min(handFont(10).lineHeight * 3 + 2, ceil(quote.boundingRect(
                    with: CGSize(width: leaf.contentWidth - indent, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin], attributes: handAttributes, context: nil).height)) + 4
            }
            let month = calendar.component(.month, from: sitting.date)
            let needed = 34 + answerHeight + (month != shownMonth ? 20 : 0)
            if leaf.y + needed > leaf.bottom { leaf = freshLeaf(true); shownMonth = -1 }
            if month != shownMonth {
                drawEyebrow(monthTitle.string(from: sitting.date), style: style, leaf: &leaf)
                shownMonth = month
            }
            drawTracked(dayFormat.string(from: sitting.date), at: CGPoint(x: leaf.left, y: leaf.y + 3), font: smallCaps(6.8),
                        color: ink.withAlphaComponent(0.5), tracking: 1)
            (sitting.room as NSString).draw(
                at: CGPoint(x: leaf.left + indent, y: leaf.y),
                withAttributes: [.font: UIFont.fbSerif(ofSize: 11.5, weight: .semibold), .foregroundColor: ink])
            let number = sitting.lessonNumber.map { "Lesson \(RomanNumeral.of($0)): " } ?? ""
            ("\(number)\(sitting.lessonTitle) · \(sitting.leader)" as NSString).draw(
                in: CGRect(x: leaf.left + indent, y: leaf.y + 15, width: leaf.contentWidth - indent, height: 13),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.8), .foregroundColor: ink.withAlphaComponent(0.6),
                                 .paragraphStyle: truncating])
            leaf.y += 32
            if let quote {
                quote.draw(with: CGRect(x: leaf.left + indent, y: leaf.y - 3, width: leaf.contentWidth - indent, height: answerHeight - 4),
                           options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: handAttributes, context: nil)
                leaf.y += answerHeight
            }
            leaf.y += 4
        }
        fillLeafFoot(month: Calendar.current.component(.month, from: sittings.last?.date ?? Date()), seed: "register", leaf: leaf)
    }

    // MARK: Lecture leaf

    /// Returns whether the lesson's practice was set on this same leaf.
    @discardableResult
    private static func drawLectureLeaf(
        _ lesson: HandbookLesson, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor, monthNumber: Int
    ) -> Bool {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context,
                             headLeft: lesson.isClub ? "Society" : "Class", headRight: lesson.name)
        drawEyebrow("\(lesson.isClub ? "Society" : "Class") · \(lesson.room)", style: style, leaf: &leaf)

        let portraitBox = CGRect(x: leaf.right - 70, y: leaf.y, width: 70, height: 88)
        hbPortrait(slug: lesson.leaderSlug, in: portraitBox, style: style)
        let hasPortrait = lesson.leaderSlug.flatMap { CastMarginalia.plateAssetName(forSlug: $0) }
            .flatMap { FieldImageCache.portrait($0) } != nil
        let headWidth = hasPortrait ? leaf.contentWidth - 84 : leaf.contentWidth

        let titleFont = UIFont.fbSerif(ofSize: 21, weight: .bold)
        let titleHeight = FieldText.height(lesson.title, font: titleFont, width: headWidth, lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
        FieldText.flow(lesson.title, font: titleFont, color: ink,
                       in: CGRect(x: leaf.left, y: leaf.y, width: headWidth, height: titleHeight + 2),
                       lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
        leaf.y += titleHeight + 6
        var taught = "Taught by \(lesson.leader)."
        if let label = lessonLabel(lesson) {
            let mode = lesson.mode.map { String($0.prefix(1)).lowercased() + String($0.dropFirst()) }
            taught += " \(label)" + (mode.map { ": \($0)." } ?? ".")
        }
        hbText(taught, font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.7),
               leaf: &leaf, width: headWidth, justified: false, gap: 4)
        let presence = lesson.attended
            ? "You were in the room\(lesson.attendedCount > 1 ? " \(lesson.attendedCount) times" : "") \(thisPeriod)."
            : "You weren't there \(thisPeriod), so I sat in your seat and wrote it down for you."
        hbText(presence, font: .fbSerifItalic(ofSize: 9.2), color: style.palette.accent, leaf: &leaf,
               width: headWidth, justified: false, gap: 4)
        leaf.y = max(leaf.y, portraitBox.minY + 92)

        hbText("The real subject: \(lesson.realSubject).", font: .fbSerifItalic(ofSize: 9.2),
               color: ink.withAlphaComponent(0.6), leaf: &leaf, justified: false, gap: 12)

        // The concept, set as the thing to remember.
        let conceptWidth = leaf.contentWidth - 16
        let conceptFont = UIFont.fbSerifItalic(ofSize: 13.2)
        let conceptHeight = FieldText.height(lesson.concept, font: conceptFont, width: conceptWidth, lineSpacing: 2.8, paragraphSpacing: 0, justified: false)
        style.palette.gold.setFill()
        UIBezierPath(rect: CGRect(x: leaf.left, y: leaf.y, width: 2.2, height: conceptHeight + 2)).fill()
        FieldText.flow(lesson.concept, font: conceptFont, color: ink.withAlphaComponent(0.92),
                       in: CGRect(x: leaf.left + 14, y: leaf.y, width: conceptWidth, height: conceptHeight + 2),
                       lineSpacing: 2.8, paragraphSpacing: 0, justified: false)
        leaf.y += conceptHeight + 16

        // The leader's own words do the teaching; what the room covered follows only where it fits.
        if let lecture = lesson.lecture, !lecture.isEmpty {
            drawEyebrow("\(surname(of: lesson.leader)) at the board", style: style, leaf: &leaf)
            hbText(lecture, font: bodyFont, color: ink.withAlphaComponent(0.92), leaf: &leaf, gap: 10)
        }
        let demoNeed = lesson.demonstration.isEmpty ? 0
            : 18 + FieldText.height(lesson.demonstration, font: bodyFont, width: leaf.contentWidth, lineSpacing: 2.6, paragraphSpacing: 5, justified: true) + 10
        let readingNeed: CGFloat = lesson.reading == nil ? 0 : 20
        let beatsNeed = lesson.beats.reduce(CGFloat(24)) {
            $0 + FieldText.height($1, font: bodyFont, width: leaf.contentWidth - 20, lineSpacing: 2.6, paragraphSpacing: 5, justified: true) + 5
        }
        let showBeats = !lesson.beats.isEmpty
            && (lesson.lecture == nil || leaf.y + beatsNeed + demoNeed + readingNeed < leaf.bottom - 8)

        if showBeats {
            drawEyebrow("What the room covered", style: style, leaf: &leaf)
            for (index, beat) in lesson.beats.enumerated() {
                ("\(index + 1)" as NSString).draw(
                    at: CGPoint(x: leaf.left, y: leaf.y - 1),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 13, weight: .bold), .foregroundColor: style.palette.accent.withAlphaComponent(0.8)])
                hbText(beat, font: bodyFont, color: ink.withAlphaComponent(0.92), leaf: &leaf,
                       x: leaf.left + 20, width: leaf.contentWidth - 20, gap: 5)
            }
            leaf.y += 6
        }

        if !lesson.demonstration.isEmpty, leaf.y + demoNeed < leaf.bottom - 4 {
            drawEyebrow("In the room", style: style, leaf: &leaf)
            hbText(lesson.demonstration, font: bodyFont, color: ink.withAlphaComponent(0.92), leaf: &leaf, gap: 10)
        }
        if let reading = lesson.reading, leaf.y + readingNeed < leaf.bottom {
            hbText("Course reading: \(reading).", font: .fbSerifItalic(ofSize: 8.6), color: ink.withAlphaComponent(0.58),
                   leaf: &leaf, justified: false, gap: 12)
        }

        if !lesson.interaction.isEmpty {
            let slipH = slipHeight(lesson.interaction, width: leaf.contentWidth - 30, fontSize: 11.5)
            if leaf.y + slipH + 70 < leaf.bottom {
                drawHandSlip(lesson.interaction, style: style,
                             in: CGRect(x: leaf.left + 8, y: leaf.y, width: leaf.contentWidth - 30, height: slipH),
                             rotation: (frac("hb-\(lesson.id)-rot") - 0.5) * 0.04, seed: "hb-\(lesson.id)")
                leaf.y += slipH + 16
            }
        }

        // The practice, on this leaf if it fits: as many of its fields as the room allows.
        let room = leaf.bottom - leaf.y
        for fieldCount in [min(2, lesson.fields.count), min(1, lesson.fields.count), 0]
            where practiceInlineNeed(lesson, width: leaf.contentWidth, fields: fieldCount) <= room {
            drawPracticeInline(lesson, fields: fieldCount, style: style, leaf: &leaf)
            return true
        }

        // No room for it: the margin is for your own notes, and the worksheet gets its own leaf.
        if leaf.y + 60 < leaf.bottom {
            if let prompt = NotePromptDealer.next(.margin, seed: "lecture-\(lesson.id)") {
                drawNotesBlock(prompt, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y), style: style)
            } else {
                drawEyebrow("Your margin", style: style, leaf: &leaf)
                hbRules(from: leaf.y, to: leaf.bottom, left: leaf.left, right: leaf.right, style: style)
            }
        }
        return false
    }

    /// "Lesson II of XII", for a room that teaches a course.
    static func lessonLabel(_ lesson: HandbookLesson) -> String? {
        guard let number = lesson.number, let count = lesson.lessonCount, count > 1 else { return nil }
        return "Lesson \(RomanNumeral.of(number)) of \(RomanNumeral.of(count))"
    }

    /// "Professor Lydia Boggle" is Boggle at the board; "Zara Finch (de facto anchor)" is Finch.
    static func surname(of leader: String) -> String {
        let name = leader.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? leader
        return name.split(separator: " ").last.map(String.init) ?? name
    }

    static func monthName(_ number: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let symbols = calendar.monthSymbols
        return symbols[((number - 1) % 12 + 12) % 12]
    }

    // MARK: Open seats

    /// The rooms that met without the reader: each one's lesson this month, its one idea, and a way
    /// in that takes two minutes, with two lines to answer on. As many as the leaf holds whole.
    private static func drawOpenSeats(
        _ seats: [HandbookLesson], style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        guard !seats.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Handbook", headRight: "Open seats")
        drawEyebrow("Kept for you", style: style, leaf: &leaf)
        ("Your seat is open" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 24, weight: .bold), .foregroundColor: ink])
        leaf.y += 36
        hbText("These rooms met \(thisPeriod) without you. I've saved you the best bit of each. It takes two minutes, and you can do it anywhere.",
               font: .fbSerifItalic(ofSize: 10.6), color: ink.withAlphaComponent(0.82), leaf: &leaf, justified: false, gap: 16)

        let width = leaf.contentWidth
        let titleFont = UIFont.fbSerif(ofSize: 14, weight: .bold)
        let ideaFont = UIFont.fbSerifItalic(ofSize: 10)
        for (index, seat) in seats.enumerated() {
            let tryIt = seat.twoMinutes ?? seat.realWorldPractice
            let need = (index > 0 ? 14 : 0) + 13
                + FieldText.height(seat.title, font: titleFont, width: width, lineSpacing: 1.5, paragraphSpacing: 0, justified: false) + 3
                + FieldText.height(seat.concept, font: ideaFont, width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false) + 7
                + 11 + FieldText.height(tryIt, font: bodyFont, width: width, lineSpacing: 2.6, paragraphSpacing: 5, justified: false) + 2
                + 52
            guard leaf.y + need <= leaf.bottom else { break }
            if index > 0 {
                style.palette.gold.withAlphaComponent(0.6).setFill()
                UIBezierPath(rect: CGRect(x: leaf.left + width * 0.35, y: leaf.y + 4, width: width * 0.3, height: 0.5)).fill()
                leaf.y += 14
            }
            drawTracked("\(seat.name) · \(surname(of: seat.leader))", at: CGPoint(x: leaf.left, y: leaf.y),
                        font: smallCaps(6.8), color: style.palette.accent, tracking: 1.2)
            if let label = lessonLabel(seat) {
                drawTracked(label, at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.4),
                            color: ink.withAlphaComponent(0.45), tracking: 1.1, width: width, alignment: .right)
            }
            leaf.y += 13
            hbText(seat.title, font: titleFont, color: ink, leaf: &leaf, lineSpacing: 1.5, paragraphSpacing: 0, justified: false, gap: 3)
            hbText(seat.concept, font: ideaFont, color: ink.withAlphaComponent(0.8), leaf: &leaf, lineSpacing: 2, paragraphSpacing: 0, justified: false, gap: 7)
            drawTracked("Two minutes", at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.4),
                        color: ink.withAlphaComponent(0.7), tracking: 1.2)
            leaf.y += 11
            hbText(tryIt, font: bodyFont, color: ink.withAlphaComponent(0.92), leaf: &leaf, justified: false, gap: 2)
            hbRules(from: leaf.y, to: leaf.y + 46, left: leaf.left, right: leaf.right, spacing: 22, style: style)
            leaf.y += 52
        }
    }

    // MARK: The practice, on the lecture leaf

    private static func practiceInlineNeed(_ lesson: HandbookLesson, width: CGFloat, fields: Int) -> CGFloat {
        let titleH = FieldText.height(lesson.practiceTitle, font: .fbSerif(ofSize: 15, weight: .bold), width: width, lineSpacing: 1.5, paragraphSpacing: 0, justified: false)
        let inviteH = FieldText.height(lesson.invitation, font: .fbSerifItalic(ofSize: 10.2), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        let footTextH = FieldText.height(lesson.realWorldPractice, font: .fbSerifItalic(ofSize: 10), width: width - 24, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        var total: CGFloat = 13 + titleH + 5 + inviteH + 12 + footTextH + 34 + 12
        if let entry = lesson.readerEntry {
            let shown = entry.count > 360 ? String(entry.prefix(360)) + "…" : entry
            total += 14 + slipHeight(shown, width: width - 20) + 10
        }
        return total + CGFloat(fields) * 60
    }

    private static func drawPracticeInline(
        _ lesson: HandbookLesson, fields: Int, style: EditionStyle, leaf: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let rule = UIBezierPath(rect: CGRect(x: leaf.left + leaf.contentWidth * 0.3, y: leaf.y + 2, width: leaf.contentWidth * 0.4, height: 0.5))
        style.palette.gold.withAlphaComponent(0.6).setFill(); rule.fill()
        leaf.y += 10
        drawEyebrow("The practice", style: style, leaf: &leaf)
        hbText(lesson.practiceTitle, font: .fbSerif(ofSize: 15, weight: .bold), color: ink, leaf: &leaf, lineSpacing: 1.5, paragraphSpacing: 0, justified: false, gap: 5)
        hbText(lesson.invitation, font: .fbSerifItalic(ofSize: 10.2), color: ink.withAlphaComponent(0.82), leaf: &leaf, lineSpacing: 2, justified: false, gap: 8)
        if let entry = lesson.readerEntry {
            drawTracked("What you brought back from the room", at: CGPoint(x: leaf.left, y: leaf.y), font: smallCaps(6.6), color: style.palette.accent, tracking: 1.2)
            leaf.y += 12
            let shown = entry.count > 360 ? String(entry.prefix(360)).trimmingCharacters(in: .whitespaces) + "…" : entry
            let slipH = slipHeight(shown, width: leaf.contentWidth - 20)
            drawHandSlip(shown, style: style, in: CGRect(x: leaf.left + 4, y: leaf.y, width: leaf.contentWidth - 20, height: slipH),
                         rotation: (frac("hb-entry-\(lesson.id)") - 0.5) * 0.035, seed: "hb-entry-\(lesson.id)")
            leaf.y += slipH + 10
        }
        // The foot box is anchored to the foot of the leaf; the fields take what is between.
        let footWidth = leaf.contentWidth - 24
        let footTextH = FieldText.height(lesson.realWorldPractice, font: .fbSerifItalic(ofSize: 10), width: footWidth, lineSpacing: 2, paragraphSpacing: 0, justified: false)
        let footH = footTextH + 34
        let footTop = leaf.bottom - footH
        let each = fields > 0 ? max(52, min(78, (footTop - 10 - leaf.y) / CGFloat(fields))) : 0
        for field in lesson.fields.prefix(fields) {
            let top = leaf.y
            drawTracked(field.label, at: CGPoint(x: leaf.left, y: top), font: smallCaps(7), color: ink.withAlphaComponent(0.85), tracking: 1.1)
            (field.placeholder as NSString).draw(in: CGRect(x: leaf.left, y: top + 11, width: leaf.contentWidth, height: 12),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.4), .foregroundColor: ink.withAlphaComponent(0.5)])
            hbRules(from: top + 20, to: top + each - 4, left: leaf.left, right: leaf.right, spacing: 17, style: style)
            leaf.y = top + each
        }
        let frame = CGRect(x: leaf.left, y: footTop, width: leaf.contentWidth, height: footH)
        drawCardFrame(frame, style: style, double: true)
        drawTracked("To try in the real world", at: CGPoint(x: frame.minX + 12, y: frame.minY + 8), font: smallCaps(6.6), color: style.palette.accent, tracking: 1.2)
        FieldText.flow(lesson.realWorldPractice, font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.9),
                       in: CGRect(x: frame.minX + 12, y: frame.minY + 22, width: footWidth, height: footTextH + 4),
                       lineSpacing: 2, paragraphSpacing: 0, justified: false)
    }

    // MARK: Workbook leaf

    private static func drawWorkbookLeaf(
        _ lesson: HandbookLesson, style: EditionStyle, context: UIGraphicsPDFRendererContext,
        cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "Workbook", headRight: lesson.name)
        drawEyebrow("The practice", style: style, leaf: &leaf)
        hbText(lesson.practiceTitle, font: .fbSerif(ofSize: 19, weight: .bold), color: ink, leaf: &leaf,
               lineSpacing: 1.5, paragraphSpacing: 0, justified: false, gap: 6)
        hbText(lesson.invitation, font: .fbSerifItalic(ofSize: 10.8), color: ink.withAlphaComponent(0.82),
               leaf: &leaf, justified: false, gap: 12)

        if let entry = lesson.readerEntry {
            drawTracked("What you brought back from the room", at: CGPoint(x: leaf.left, y: leaf.y),
                        font: smallCaps(6.8), color: style.palette.accent, tracking: 1.2)
            leaf.y += 14
            let width = leaf.contentWidth - 20
            let shown = entry.count > 520 ? String(entry.prefix(520)).trimmingCharacters(in: .whitespaces) + "…" : entry
            let slipH = slipHeight(shown, width: width)
            drawHandSlip(shown, style: style,
                         in: CGRect(x: leaf.left + 4, y: leaf.y, width: width, height: slipH),
                         rotation: (frac("hb-entry-\(lesson.id)") - 0.5) * 0.035, seed: "hb-entry-\(lesson.id)")
            leaf.y += slipH + 14
        }

        // The foot box is measured first so the writing lines stop above it.
        let practice = lesson.realWorldPractice
        let footWidth = leaf.contentWidth - 24
        let footTextH = FieldText.height(practice, font: .fbSerifItalic(ofSize: 10.4), width: footWidth, lineSpacing: 2.2, paragraphSpacing: 0, justified: false)
        let footH = footTextH + 38
        let footTop = leaf.bottom - footH

        let fields = lesson.fields
        if !fields.isEmpty {
            let again = lesson.readerEntry != nil
            if again { drawEyebrow("Once more, on paper", style: style, leaf: &leaf) }
            let available = footTop - 16 - leaf.y
            let perField = available / CGFloat(fields.count)
            for field in fields {
                guard perField > 56 else { break }
                let top = leaf.y
                drawTracked(field.label, at: CGPoint(x: leaf.left, y: top), font: smallCaps(7.4),
                            color: ink.withAlphaComponent(0.85), tracking: 1.1)
                (field.placeholder as NSString).draw(
                    in: CGRect(x: leaf.left, y: top + 12, width: leaf.contentWidth, height: 12),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.6), .foregroundColor: ink.withAlphaComponent(0.5)])
                hbRules(from: top + 22, to: top + perField - 8, left: leaf.left, right: leaf.right, style: style)
                leaf.y = top + perField
            }
        } else {
            if let prompt = NotePromptDealer.next(.margin, seed: "worksheet-\(lesson.id)") {
                drawNotesBlock(prompt, in: CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: footTop - 12 - leaf.y), style: style)
            } else {
                drawEyebrow("Your notes", style: style, leaf: &leaf)
                hbRules(from: leaf.y, to: footTop - 12, left: leaf.left, right: leaf.right, style: style)
            }
        }

        let frame = CGRect(x: leaf.left, y: footTop, width: leaf.contentWidth, height: footH)
        drawCardFrame(frame, style: style, double: true)
        drawTracked("To try in the real world", at: CGPoint(x: frame.minX + 12, y: frame.minY + 9),
                    font: smallCaps(6.8), color: style.palette.accent, tracking: 1.2)
        FieldText.flow(practice, font: .fbSerifItalic(ofSize: 10.4), color: ink.withAlphaComponent(0.9),
                       in: CGRect(x: frame.minX + 12, y: frame.minY + 24, width: footWidth, height: footTextH + 4),
                       lineSpacing: 2.2, paragraphSpacing: 0, justified: false)
    }

    // MARK: Faculty & Cast files

    private static func drawDossiers(
        _ dossiers: [HandbookDossier], style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor, monthNumber: Int
    ) {
        let ink = style.palette.ink
        for (index, person) in dossiers.enumerated() {
            var leaf = fieldLeaf(&cursor, style: style, context: context,
                                 headLeft: index == 0 ? "The Faculty & the Cast" : "The Cast", headRight: person.name)
            drawEyebrow("A file kept by the Book", style: style, leaf: &leaf)
            let portraitBox = CGRect(x: leaf.right - 84, y: leaf.y, width: 84, height: 108)
            hbPortrait(slug: person.slug, in: portraitBox, style: style)
            let hasPortrait = person.plateAssetName.flatMap { FieldImageCache.portrait($0) } != nil
            let headWidth = hasPortrait ? leaf.contentWidth - 100 : leaf.contentWidth
            hbText(person.name, font: .fbSerif(ofSize: 22, weight: .bold), color: ink, leaf: &leaf,
                   width: headWidth, lineSpacing: 1.5, paragraphSpacing: 0, justified: false, gap: 6)
            var facts: [String] = []
            if person.daysPresent > 0 { facts.append("\(person.daysPresent) \(person.daysPresent == 1 ? "day" : "days") in the Labyrinth with you") }
            if person.sceneCount > 0 { facts.append("in \(person.sceneCount) \(person.sceneCount == 1 ? "scene" : "scenes") you read") }
            if !facts.isEmpty {
                hbText(facts.joined(separator: " · ") + ".", font: .fbSerifItalic(ofSize: 9.4),
                       color: style.palette.accent, leaf: &leaf, width: headWidth, justified: false)
            }
            leaf.y = max(leaf.y, portraitBox.minY + 116)

            // This month first: where the reader met them, and what they said.
            if !person.scenesThisMonth.isEmpty || !person.saidThisMonth.isEmpty {
                drawEyebrow(handbookTermSpan == nil ? "In \(person.monthName ?? "this month")" : "This \(handbookPeriod)", style: style, leaf: &leaf)
                if !person.scenesThisMonth.isEmpty {
                    // "3 more" is a count, not a title: it isn't set in italics.
                    let list = ListFormatter.localizedString(byJoining: person.scenesThisMonth.map {
                        $0.hasSuffix(" more") && $0.first?.isNumber == true ? $0 : "*\($0)*"
                    })
                    let text = "In the scenes you read: \(list)."
                    hbText(text, font: bodyFont, color: ink.withAlphaComponent(0.9), leaf: &leaf,
                           width: leaf.contentWidth, justified: false, gap: 8)
                }
                let accent = KeepMarginalia.voice(forSlug: person.slug).map { castInk($0.accentHex) }
                for (index, line) in person.saidThisMonth.enumerated() {
                    let width = min(leaf.contentWidth - 10, 300)
                    let height = slipHeight(line, width: width, fontSize: 10.6)
                    guard leaf.y + height + 10 < leaf.bottom - 60 else { break }
                    drawHandSlip(line, style: style, in: CGRect(x: leaf.left + (index % 2 == 0 ? 2 : 18), y: leaf.y, width: width, height: height),
                                 rotation: index % 2 == 0 ? -0.02 : 0.018, seed: "said-\(person.slug)-\(index)", fontSize: 10.6, color: accent)
                    leaf.y += height + 10
                }
                leaf.y += 4
                drawEyebrow("From the Book's file", style: style, leaf: &leaf)
            }

            var rest = FieldMarked(parsing: person.paragraphs.joined(separator: "\n"))
            var first = true
            var guardPasses = 0
            while !rest.isEmpty, guardPasses < 6 {
                guardPasses += 1
                let rect = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: leaf.bottom - leaf.y)
                let flow = FieldText.flow(rest, font: bodyFont, color: ink.withAlphaComponent(0.92), in: rect,
                                          dropCap: first ? style.palette.accent : nil)
                first = false
                if flow.rest == rest || flow.usedHeight <= 0 { break }
                rest = flow.rest
                if !rest.isEmpty {
                    leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Cast", headRight: "\(person.name), continued")
                } else {
                    leaf.y += flow.usedHeight + 10
                }
            }
            // A short last leaf gets a pressed plant rather than bare paper.
            if leaf.bottom - leaf.y > 130,
               let plant = FieldBotanicals.image(month: monthNumber, seed: "hb-dossier-\(person.slug)") {
                let w = min(96, plant.size.width * plant.scale / 150 * 72)
                let h = w * plant.size.height / plant.size.width
                plant.draw(in: CGRect(x: leaf.right - w, y: leaf.bottom - h, width: w, height: h))
            }
        }
    }

    // MARK: Lore shelf

    struct StackItem {
        var height: CGFloat
        var draw: (CGRect) -> Void
    }

    /// Stacks measured entries down leaves, never splitting one across a page.
    static func drawStack(
        _ items: [StackItem], head: String, kicker: String, headRight: String,
        style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor,
        gap: CGFloat = 16,
        fill: ((CGRect) -> Void)? = nil
    ) {
        guard !items.isEmpty else { return }
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: head, headRight: headRight)
        drawEyebrow(kicker, style: style, leaf: &leaf)
        var onLeaf = 0
        for item in items {
            if onLeaf > 0, leaf.y + item.height > leaf.bottom {
                leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: head, headRight: headRight)
                onLeaf = 0
            }
            item.draw(CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: item.height))
            leaf.y += item.height + gap
            onLeaf += 1
            if let cg = UIGraphicsGetCurrentContext(), leaf.y < leaf.bottom - 20 {
                cg.setStrokeColor(style.palette.gold.withAlphaComponent(0.5).cgColor)
                cg.setLineWidth(0.5)
                cg.move(to: CGPoint(x: leaf.left + leaf.contentWidth * 0.38, y: leaf.y - gap / 2))
                cg.addLine(to: CGPoint(x: leaf.left + leaf.contentWidth * 0.62, y: leaf.y - gap / 2))
                cg.strokePath()
            }
        }
        // Whatever room the last leaf has left is offered to the reader, if there is enough to write in.
        if let fill, leaf.bottom - leaf.y >= 110 {
            fill(CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: min(leaf.bottom - leaf.y, 260)))
        }
    }

    private static func drawLoreShelf(
        _ entries: [HandbookLoreEntry], head: String, kicker: String,
        style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let width: CGFloat = max(220, cursor.contentWidth)
        let items = entries.map { entry -> StackItem in
            let titleFont = UIFont.fbSerif(ofSize: 13.2, weight: .bold)
            let titleH = FieldText.height(entry.title, font: titleFont, width: width, lineSpacing: 1.4, paragraphSpacing: 0, justified: false)
            let whyH = entry.why.map { FieldText.height($0, font: .fbSerifItalic(ofSize: 8.8), width: width, lineSpacing: 1.2, paragraphSpacing: 0, justified: false) + 4 } ?? 0
            let bodyH = FieldText.height(entry.body, font: bodyFont, width: width, lineSpacing: 2.5, paragraphSpacing: 4)
            let practiceH = entry.practice.map { slipHeight("Try: " + $0, width: width - 30) + 8 } ?? 0
            let total = titleH + 4 + whyH + bodyH + 6 + practiceH
            return StackItem(height: total) { rect in
                var y = rect.minY
                FieldText.flow(entry.title, font: titleFont, color: ink, in: CGRect(x: rect.minX, y: y, width: width, height: titleH + 2),
                               lineSpacing: 1.4, paragraphSpacing: 0, justified: false)
                y += titleH + 4
                if let why = entry.why {
                    FieldText.flow(why, font: .fbSerifItalic(ofSize: 8.8), color: style.palette.accent,
                                   in: CGRect(x: rect.minX, y: y, width: width, height: whyH), lineSpacing: 1.2, paragraphSpacing: 0, justified: false)
                    y += whyH
                }
                FieldText.flow(entry.body, font: bodyFont, color: ink.withAlphaComponent(0.92),
                               in: CGRect(x: rect.minX, y: y, width: width, height: bodyH + 2), lineSpacing: 2.5, paragraphSpacing: 4)
                y += bodyH + 6
                if let practice = entry.practice {
                    let h = slipHeight("Try: " + practice, width: width - 30)
                    drawHandSlip("Try: " + practice, style: style,
                                 in: CGRect(x: rect.minX + 10, y: y, width: width - 30, height: h),
                                 rotation: (frac("hb-lore-\(entry.id)") - 0.5) * 0.04, seed: "hb-lore-\(entry.id)", fontSize: 10.8)
                }
            }
        }
        drawStack(items, head: head, kicker: kicker, headRight: "Handbook", style: style, context: context, cursor: &cursor)
    }

    // MARK: Bestiary

    private static func drawBestiary(
        _ creatures: [HandbookCreature], style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let width: CGFloat = max(220, cursor.contentWidth) - 24
        let items = creatures.map { creature -> StackItem in
            let loreH = FieldText.height(creature.lore, font: bodyFont, width: width, lineSpacing: 2.5, paragraphSpacing: 4)
            let senseH = FieldText.height(creature.sense, font: .fbSerifItalic(ofSize: 10.4), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = 22 + senseH + 8 + loreH + 22
            return StackItem(height: total + 12) { rect in
                let frame = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: total + 12)
                drawCardFrame(frame, style: style)
                var y = rect.minY + 10
                (creature.creature.capitalized as NSString).draw(
                    at: CGPoint(x: rect.minX + 12, y: y),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 15, weight: .bold), .foregroundColor: ink])
                drawTracked(creature.timesFiled > 1 ? "filed \(creature.timesFiled) times" : "filed once",
                            at: CGPoint(x: rect.minX + 12, y: y + 3), font: smallCaps(6.6),
                            color: style.palette.accent, tracking: 1.1, width: width, alignment: .right)
                y += 22
                FieldText.flow(creature.sense, font: .fbSerifItalic(ofSize: 10.4), color: ink.withAlphaComponent(0.8),
                               in: CGRect(x: rect.minX + 12, y: y, width: width, height: senseH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                y += senseH + 8
                FieldText.flow(creature.lore, font: bodyFont, color: ink.withAlphaComponent(0.92),
                               in: CGRect(x: rect.minX + 12, y: y, width: width, height: loreH + 2), lineSpacing: 2.5, paragraphSpacing: 4)
                y += loreH + 6
                drawTracked(creature.tradition, at: CGPoint(x: rect.minX + 12, y: y), font: smallCaps(6.4),
                            color: ink.withAlphaComponent(0.5), tracking: 1.0)
            }
        }
        drawStack(items, head: "The Bestiary", kicker: "Creatures you filed \(thisPeriod)", headRight: "Handbook",
                  style: style, context: context, cursor: &cursor, gap: 14)
    }

    // MARK: Spell sheets

    private static func drawSpellSheets(
        _ spells: [HandbookSpell], style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let width: CGFloat = max(220, cursor.contentWidth)
        // A spell the reader cast keeps its lines, for the next time. The ones
        // still waiting are named together in a short list, not given a ruled
        // block each: three pages of "not yet cast" is paper with nothing on it.
        let cast = spells.filter { $0.timesCast > 0 }
        let waiting = spells.filter { $0.timesCast == 0 }
        var items = cast.map { spell -> StackItem in
            let detailH = FieldText.height(spell.detail, font: .fbSerifItalic(ofSize: 10), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            let total = 20 + detailH + 8 + 46
            return StackItem(height: total) { rect in
                (spell.title as NSString).draw(
                    at: CGPoint(x: rect.minX, y: rect.minY),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 13, weight: .bold), .foregroundColor: ink])
                let cast = spell.timesCast == 0 ? "not yet cast" : (spell.timesCast == 1 ? "cast once" : "cast \(spell.timesCast) times")
                drawTracked(cast, at: CGPoint(x: rect.minX, y: rect.minY + 3), font: smallCaps(6.6),
                            color: spell.timesCast == 0 ? ink.withAlphaComponent(0.4) : style.palette.accent,
                            tracking: 1.1, width: rect.width, alignment: .right)
                FieldText.flow(spell.detail, font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.8),
                               in: CGRect(x: rect.minX, y: rect.minY + 20, width: width, height: detailH + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                hbRules(from: rect.minY + 22 + detailH, to: rect.maxY, left: rect.minX, right: rect.maxX, spacing: 22, style: style)
            }
        }
        if !waiting.isEmpty {
            let columnGap: CGFloat = 16
            let column = (width - columnGap) / 2
            let titleFont = UIFont.fbSerif(ofSize: 11, weight: .semibold)
            let detailFont = UIFont.fbSerifItalic(ofSize: 9)
            func entryHeight(_ spell: HandbookSpell) -> CGFloat {
                16 + FieldText.height(spell.detail, font: detailFont, width: column, lineSpacing: 1, paragraphSpacing: 0, justified: false) + 8
            }
            let rows = stride(from: 0, to: waiting.count, by: 2).map { index in
                max(entryHeight(waiting[index]), index + 1 < waiting.count ? entryHeight(waiting[index + 1]) : 0)
            }
            let lead = cast.isEmpty ? "None cast yet. They're all here, waiting for the day something ordinary needs one." : "Still waiting to be cast:"
            let leadHeight = FieldText.height(lead, font: .fbSerifItalic(ofSize: 10.4), width: width, lineSpacing: 2, paragraphSpacing: 0, justified: false)
            items.append(StackItem(height: leadHeight + 10 + rows.reduce(0, +)) { rect in
                FieldText.flow(lead, font: .fbSerifItalic(ofSize: 10.4), color: ink.withAlphaComponent(0.75),
                               in: CGRect(x: rect.minX, y: rect.minY, width: width, height: leadHeight + 2),
                               lineSpacing: 2, paragraphSpacing: 0, justified: false)
                var y = rect.minY + leadHeight + 10
                for (row, height) in rows.enumerated() {
                    for side in 0..<2 {
                        let index = row * 2 + side
                        guard index < waiting.count else { continue }
                        let x = rect.minX + CGFloat(side) * (column + columnGap)
                        (waiting[index].title as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: titleFont, .foregroundColor: ink])
                        FieldText.flow(waiting[index].detail, font: detailFont, color: ink.withAlphaComponent(0.7),
                                       in: CGRect(x: x, y: y + 15, width: column, height: height - 15),
                                       lineSpacing: 1, paragraphSpacing: 0, justified: false)
                    }
                    y += height
                }
            })
        }
        drawStack(items, head: "The Spellbook", kicker: "Fourteen enchantments, and a line for each you cast", headRight: "Handbook",
                  style: style, context: context, cursor: &cursor, gap: 12)
    }
}
