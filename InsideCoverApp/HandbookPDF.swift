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
        // A writing area sits on a soft paper-white panel: less ink under the pen on coated stock.
        if endY - startY >= spacing * 2.5 {
            UIColor.white.withAlphaComponent(0.3).setFill()
            UIBezierPath(roundedRect: CGRect(x: left - 4, y: startY + 3, width: right - left + 8, height: endY - startY - 1), cornerRadius: 3).fill()
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
        for lesson in handbook.lessons {
            // A lesson whose lecture leaves room carries its practice on the same leaf; only a long one
            // needs a leaf of its own for the worksheet.
            if !drawLectureLeaf(lesson, style: style, context: context, cursor: &cursor, monthNumber: monthNumber) {
                drawWorkbookLeaf(lesson, style: style, context: context, cursor: &cursor)
            }
        }
        drawDossiers(handbook.dossiers, style: style, context: context, cursor: &cursor, monthNumber: monthNumber)
        drawLoreShelf(handbook.lore + handbook.compass, head: "The Lore Shelf", kicker: "Set down for you",
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
        guard !handbook.lessons.isEmpty else { return }
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context, headLeft: "The Handbook", headRight: "Coursework")
        drawEyebrow("The term's coursework", style: style, leaf: &leaf)
        ("Rooms you may sit" as NSString).draw(
            at: CGPoint(x: leaf.left, y: leaf.y),
            withAttributes: [.font: UIFont.fbSerif(ofSize: 24, weight: .bold), .foregroundColor: ink])
        leaf.y += 36
        let sat = handbook.attendedCount
        let intro: String
        if sat == 0 {
            intro = "\(handbook.lessons.count) rooms, one subject: the world is stranger than it looks, and you are allowed to look. You haven't sat any of them yet this month, so the seats are kept, and every worksheet below is still blank and still yours."
        } else {
            intro = "\(handbook.lessons.count) rooms, one subject: the world is stranger than it looks, and you are allowed to look. You sat \(sat) of them this month. Those are marked, and where you brought something back from the room, it's copied onto the worksheet in your own words."
        }
        hbText(intro, font: .fbSerifItalic(ofSize: 10.6), color: ink.withAlphaComponent(0.82), leaf: &leaf, justified: false, gap: 14)

        for group in [("Classes", handbook.classes), ("Societies", handbook.societies)] where !group.1.isEmpty {
            drawEyebrow(group.0, style: style, leaf: &leaf)
            for lesson in group.1 {
                guard leaf.y + 34 < leaf.bottom else { break }
                (lesson.name as NSString).draw(
                    at: CGPoint(x: leaf.left, y: leaf.y),
                    withAttributes: [.font: UIFont.fbSerif(ofSize: 11.5, weight: .semibold), .foregroundColor: ink])
                let mark = lesson.attended
                    ? (lesson.attendedCount > 1 ? "sat ×\(lesson.attendedCount)" : "sat")
                    : "kept for you"
                drawTracked(mark, at: CGPoint(x: leaf.left, y: leaf.y + 2), font: smallCaps(6.8),
                            color: lesson.attended ? style.palette.accent : ink.withAlphaComponent(0.4),
                            tracking: 1.2, width: leaf.contentWidth, alignment: .right)
                let sub = "\(lesson.leader) · \(lesson.room)"
                (sub as NSString).draw(
                    at: CGPoint(x: leaf.left, y: leaf.y + 15),
                    withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 8.8), .foregroundColor: ink.withAlphaComponent(0.6)])
                leaf.y += 33
            }
            leaf.y += 6
        }
        if let plant = FieldBotanicals.image(month: monthNumber, seed: "handbook-contents"), leaf.y + 70 < leaf.bottom {
            let w = min(70, plant.size.width * plant.scale / 150 * 72)
            let h = w * plant.size.height / plant.size.width
            plant.draw(in: CGRect(x: leaf.right - w, y: leaf.bottom - h, width: w, height: h))
        }
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
        hbText("Taught by \(lesson.leader).", font: .fbSerifItalic(ofSize: 10), color: ink.withAlphaComponent(0.7),
               leaf: &leaf, width: headWidth, justified: false, gap: 4)
        // Said once, on the contents leaf. A room the reader did sit is the
        // one that earns a line of its own.
        if lesson.attended {
            let presence = "You were in the room\(lesson.attendedCount > 1 ? " \(lesson.attendedCount) times" : "") this month."
            hbText(presence, font: .fbSerifItalic(ofSize: 9.2), color: style.palette.accent, leaf: &leaf,
                   width: headWidth, justified: false, gap: 4)
        }
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

        if !lesson.beats.isEmpty {
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

        if !lesson.demonstration.isEmpty {
            drawEyebrow("In the room", style: style, leaf: &leaf)
            hbText(lesson.demonstration, font: bodyFont, color: ink.withAlphaComponent(0.92), leaf: &leaf, gap: 10)
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
        drawStack(items, head: "The Bestiary", kicker: "Creatures you filed this month", headRight: "Handbook",
                  style: style, context: context, cursor: &cursor, gap: 14)
    }

    // MARK: Spell sheets

    private static func drawSpellSheets(
        _ spells: [HandbookSpell], style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        let width: CGFloat = max(220, cursor.contentWidth)
        let items = spells.map { spell -> StackItem in
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
        drawStack(items, head: "The Spellbook", kicker: "Fourteen enchantments, and a line for each of yours", headRight: "Handbook",
                  style: style, context: context, cursor: &cursor, gap: 12)
    }
}
