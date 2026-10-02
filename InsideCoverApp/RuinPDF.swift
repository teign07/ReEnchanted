import Foundation
import UIKit

// MARK: - Which page asked for what

/// A record of the pages built to be handled, filled while a volume renders and
/// written beside the PDF, so the volume's registry can say what each such page
/// asked of the reader. A sidecar travels with the file it describes.
enum PrintPageMap {
    /// The whole prompt, not its id: a book printed this month must still be
    /// readable when the pack that carried the prompt has long rotated out.
    private(set) static var entries: [String: RuinPrompt] = [:]

    static func reset() { entries = [:] }
    static func record(page: Int, prompt: RuinPrompt) { entries[String(page)] = prompt }

    static func sidecarURL(for interior: URL) -> URL {
        interior.deletingPathExtension().appendingPathExtension("pagemap.json")
    }

    static func writeSidecar(for interior: URL) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: sidecarURL(for: interior), options: .atomic)
    }

    static func read(for interior: URL) -> [String: RuinPrompt]? {
        guard let data = try? Data(contentsOf: sidecarURL(for: interior)),
              let map = try? JSONDecoder().decode([String: RuinPrompt].self, from: data), !map.isEmpty else { return nil }
        return map
    }
}

// MARK: - Ruin leaves, on paper

extension MonthlyEditionPDFWriter {
    private static func ruinLabel(_ kind: RuinKind) -> String {
        switch kind {
        case .scribble: return "Scribble"
        case .draw: return "Draw"
        case .trace: return "Trace"
        case .write: return "Write"
        case .tearOut: return "Tear out"
        case .stain: return "Stain"
        case .rubbing: return "Rubbing"
        case .press: return "Press"
        case .fold: return "Fold"
        case .tape: return "Tape"
        case .collage: return "Stick"
        }
    }

    /// Two faces of one sheet, always opening on a recto so a torn page never
    /// takes something else's reverse with it.
    static func drawRuinLeaves(
        _ leaves: [RuinLeaf], style: EditionStyle,
        context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        for leaf in leaves {
            if (cursor.pageIndex + 1).isMultiple(of: 2) {
                context.beginPage()
                cursor.reset()
                cursor.pageIndex += 1
                drawSpacerPlate(style: style, bounds: cursor.bounds, seed: cursor.pageSeed)
                drawFolioMark(number: cursor.pageIndex, seed: cursor.addressSeed ?? cursor.seed,
                              bounds: cursor.bounds, ink: style.palette.ink)
            }
            drawRuinFace(leaf.front, isBack: false, companionOfTear: false, style: style, context: context, cursor: &cursor)
            drawRuinFace(leaf.back, isBack: true, companionOfTear: leaf.front.kind.leavesTheBook,
                         style: style, context: context, cursor: &cursor)
        }
    }

    private static func drawRuinFace(
        _ prompt: RuinPrompt, isBack: Bool, companionOfTear: Bool,
        style: EditionStyle, context: UIGraphicsPDFRendererContext, cursor: inout PDFCursor
    ) {
        let ink = style.palette.ink
        var leaf = fieldLeaf(&cursor, style: style, context: context,
                             headLeft: isBack ? "The back" : "Ruin page", headRight: ruinLabel(prompt.kind))
        PrintPageMap.record(page: cursor.pageIndex, prompt: prompt)
        let eyebrow = isBack
            ? (companionOfTear ? "The back \u{00B7} it goes with the page" : "The back")
            : "Ruin page \u{00B7} \(ruinLabel(prompt.kind))"
        drawEyebrow(eyebrow, style: style, leaf: &leaf)
        // A small pressed plant at the head of the page, the same hand as the rest of the book.
        let month = 1 + ConstellationKeeper.stableIndex(for: "ruin-month-\(prompt.id)", count: 12)
        if let plant = FieldBotanicals.image(month: month, seed: "ruin-\(prompt.id)") {
            let w = min(46, plant.size.width * plant.scale / 150 * 72)
            let h = w * plant.size.height / plant.size.width
            plant.draw(in: CGRect(x: leaf.right - w, y: leaf.y - 6, width: w, height: min(h, 70)))
        }
        hbText(prompt.title, font: .fbSerif(ofSize: 24, weight: .bold), color: ink, leaf: &leaf,
               width: leaf.contentWidth - 60, justified: false, gap: 8)
        hbText(prompt.instruction, font: .fbSerifItalic(ofSize: 12), color: ink.withAlphaComponent(0.84), leaf: &leaf,
               lineSpacing: 3.4, justified: false, gap: 16)

        // The page is the reader's. A faint frame says where it starts.
        let frame = CGRect(x: leaf.left, y: leaf.y, width: leaf.contentWidth, height: max(40, leaf.bottom - leaf.y - 34))
        if let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            cg.setStrokeColor(ink.withAlphaComponent(0.18).cgColor)
            cg.setLineWidth(0.6)
            cg.setLineDash(phase: 0, lengths: [3, 4])
            cg.stroke(frame)
            cg.restoreGState()
        }
        // A sheet that will leave the book says where to tear.
        if prompt.kind.leavesTheBook, !isBack {
            let x = leaf.left - 10
            if let cg = UIGraphicsGetCurrentContext() {
                cg.saveGState()
                cg.setStrokeColor(style.palette.accent.withAlphaComponent(0.7).cgColor)
                cg.setLineWidth(0.9)
                cg.setLineDash(phase: 0, lengths: [5, 4])
                cg.move(to: CGPoint(x: x, y: leaf.y - 20)); cg.addLine(to: CGPoint(x: x, y: leaf.bottom))
                cg.strokePath()
                cg.restoreGState()
            }
        }
        if !isBack {
            ("Show me when you're done. I want to see." as NSString).draw(
                at: CGPoint(x: leaf.left, y: leaf.bottom - 20),
                withAttributes: [.font: UIFont.fbSerifItalic(ofSize: 9.2), .foregroundColor: ink.withAlphaComponent(0.55)])
        }
    }
}
